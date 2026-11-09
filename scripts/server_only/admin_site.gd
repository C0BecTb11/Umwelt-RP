extends Node
## Лог-чекер администратора (с 0.55): маленький HTTPS-сервер внутри игрового сервера, порт 8443.
## Сертификат — свой, самоподписанный (user://admin_tls/): браузер один раз предупредит, это ожидаемо.
## Вход — почта и пароль игрового аккаунта: сервер спрашивает Supabase (вход + is_log_viewer()) и пускает только
## тех, кто вписан в public.log_viewers. Пароль нигде не хранится; после входа — cookie сессии на 12 часов.
## Данные журнала читаются в отдельном потоке (game_log.gd query), чтобы игра не подтормаживала.

const PAGE = preload("res://scripts/server_only/admin_page.gd")
const GL = preload("res://scripts/server_only/game_log.gd")
const DEFAULT_PORT := 8443
const TLS_DIR := "user://admin_tls"
const SESSION_TTL := 12 * 3600.0
const MAX_CONN := 8                 # одновременных подключений
const REQ_MAX := 16384              # байт запроса
const CONN_TIMEOUT := 20.0          # сек. на подключение
const FAIL_WINDOW := 600.0          # неудачные входы считаем за 10 минут…
const FAIL_MAX_IP := 5              # …с одного адреса больше — вход с него закрыт до конца окна (против перебора паролей)
const FAIL_MAX := 30                # …со всех адресов вместе больше — закрыт для всех (перебор с многих адресов)
# Против забивания сайта и нагрузки на игру рукопожатиями TLS (аудит 2026-11-09, А1): лишнее подключение
# закрывается сразу, до TLS. Адреса — только в памяти, на время окна; в журнал не пишутся
const PER_IP := 3                   # одновременных подключений с одного адреса
const NEW_WINDOW := 60.0
const NEW_PER_IP := 30              # новых подключений с одного адреса за минуту
const NEW_MAX := 120                # новых подключений со всех адресов за минуту

var game: GameState
var store                           # game_log.gd
var log_fn: Callable                # журнал сервера
var tcp := TCPServer.new()
var tls_opts: TLSOptions
var conns: Array = []
var sessions := {}                  # sid → {"exp": unix, "who": "Имя (id)"}
var fails: Array = []               # [время, адрес] неудачных входов
var opened: Array = []              # [время, адрес] принятых подключений за NEW_WINDOW
var job: Thread
var job_conn: Conn
var port := DEFAULT_PORT
var retry_t := 0.0                  # порт ещё занят (после перезапуска) — пробуем снова раз в 10 с

class Conn:
	var tcp: StreamPeerTCP
	var ip := ""
	var tls: StreamPeerTLS
	var buf := PackedByteArray()
	var t := 0.0
	var busy := false
	var close_in := -1.0

func start(p: int) -> bool:
	port = p
	var keys := load_or_make_tls(TLS_DIR)
	if keys.is_empty():
		return false
	tls_opts = TLSOptions.server(keys[0], keys[1])
	return tcp.listen(port, "*") == OK

func listening() -> bool:
	return tcp.is_listening()

## Ключ и сертификат сайта: из папки или новые (RSA 2048, на 10 лет)
static func load_or_make_tls(dir: String) -> Array:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var kp := dir + "/admin.key"
	var cp := dir + "/admin.crt"
	var key := CryptoKey.new()
	var cert := X509Certificate.new()
	if FileAccess.file_exists(kp) and FileAccess.file_exists(cp) and key.load(kp) == OK and cert.load(cp) == OK:
		return [key, cert]
	var cr := Crypto.new()
	key = cr.generate_rsa(2048)
	cert = cr.generate_self_signed_certificate(key, "CN=umwelt-admin,O=Umwelt RP,C=PL", "20260101000000", "20360101000000")
	if key.save(kp) != OK or cert.save(cp) != OK:
		return []
	return [key, cert]

func stop() -> void:
	tcp.stop()
	for c in conns:
		c.tcp.disconnect_from_host()
	conns.clear()
	if job != null:
		job.wait_to_finish()
		job = null

func poll(dt: float) -> void:
	if not tcp.is_listening() and tls_opts != null:
		retry_t -= dt
		if retry_t <= 0.0:
			retry_t = 10.0
			if tcp.listen(port, "*") == OK and log_fn.is_valid():
				log_fn.call("лог-чекер: порт %d открыт" % port)
		return
	var now_c := Time.get_unix_time_from_system()
	while opened.size() > 0 and opened[0][0] < now_c - NEW_WINDOW:
		opened.pop_front()
	while tcp.is_connection_available():
		var s := tcp.take_connection()
		var ip := s.get_connected_host()
		if not may_open(conns, opened, ip):
			s.disconnect_from_host()
			continue
		opened.append([now_c, ip])
		var c := Conn.new()
		c.tcp = s
		c.ip = ip
		c.tls = StreamPeerTLS.new()
		if c.tls.accept_stream(s, tls_opts) != OK:
			s.disconnect_from_host()
			continue
		conns.append(c)
	for c: Conn in conns.duplicate():
		c.t += dt
		c.tls.poll()
		var st := c.tls.get_status()
		if c.close_in >= 0.0:
			c.close_in -= dt
			if c.close_in < 0.0 or st != StreamPeerTLS.STATUS_CONNECTED:
				c.tls.disconnect_from_stream()
				conns.erase(c)
			continue
		if st == StreamPeerTLS.STATUS_ERROR or st == StreamPeerTLS.STATUS_ERROR_HOSTNAME_MISMATCH or st == StreamPeerTLS.STATUS_DISCONNECTED or c.t > CONN_TIMEOUT:
			c.tls.disconnect_from_stream()
			conns.erase(c)
			continue
		if st != StreamPeerTLS.STATUS_CONNECTED or c.busy:
			continue
		var n := c.tls.get_available_bytes()
		if n > 0:
			var r := c.tls.get_partial_data(n)
			if r[0] == OK:
				c.buf.append_array(r[1])
		if c.buf.size() > REQ_MAX:
			_send(c, 413, {"error": "Слишком большой запрос"})
			continue
		var req := parse_request(c.buf)
		if req.is_empty():
			continue
		c.busy = true
		_route(c, req)
	# поиск в потоке закончился — ответ
	if job != null and not job.is_alive():
		var res: Dictionary = job.wait_to_finish()
		job = null
		if job_conn != null and conns.has(job_conn):
			_send(job_conn, 400 if res.has("error") else 200, res)
		job_conn = null
	var now := Time.get_unix_time_from_system()
	for sid in sessions.keys():
		if sessions[sid]["exp"] < now:
			sessions.erase(sid)

## Можно ли принять ещё одно подключение с адреса ip (conns — открытые Conn, opened — [время, адрес] за окно)
static func may_open(open_conns: Array, recent: Array, ip: String) -> bool:
	if open_conns.size() >= MAX_CONN or recent.size() >= NEW_MAX:
		return false
	var same := 0
	for c in open_conns:
		if c.ip == ip:
			same += 1
	if same >= PER_IP:
		return false
	var fresh := 0
	for r in recent:
		if r[1] == ip:
			fresh += 1
	return fresh < NEW_PER_IP

## Закрыт ли вход: с этого адреса или со всех вместе слишком много неудач за окно
static func login_locked(fail_list: Array, ip: String) -> bool:
	if fail_list.size() >= FAIL_MAX:
		return true
	var n := 0
	for f in fail_list:
		if f[1] == ip:
			n += 1
	return n >= FAIL_MAX_IP

## Разбор HTTP-запроса; {} — ещё не весь пришёл. {"m", "path", "query": {}, "h": {заголовки в нижнем регистре}, "body"}
static func parse_request(buf: PackedByteArray) -> Dictionary:
	var text := buf.get_string_from_utf8()
	var he := text.find("\r\n\r\n")
	if he < 0:
		return {}
	var lines := text.substr(0, he).split("\r\n")
	var first := lines[0].split(" ")
	if first.size() < 3:
		return {"m": "BAD", "path": "", "query": {}, "h": {}, "body": ""}
	var h := {}
	for i in range(1, lines.size()):
		var k := lines[i].find(":")
		if k > 0:
			h[lines[i].substr(0, k).strip_edges().to_lower()] = lines[i].substr(k + 1).strip_edges()
	var body := text.substr(he + 4)
	var need := int(h.get("content-length", "0"))
	if body.to_utf8_buffer().size() < need:
		return {}
	var target := first[1]
	var path := target.get_slice("?", 0)
	var query := {}
	if target.contains("?"):
		for kv in target.get_slice("?", 1).split("&", false):
			query[kv.get_slice("=", 0).uri_decode()] = kv.get_slice("=", 1).replace("+", " ").uri_decode() if kv.contains("=") else ""
	return {"m": first[0], "path": path, "query": query, "h": h, "body": body}

static func cookie_sid(h: Dictionary) -> String:
	for part in str(h.get("cookie", "")).split(";"):
		var kv := part.strip_edges()
		if kv.begins_with("sid="):
			return kv.substr(4)
	return ""

func _session(req: Dictionary) -> Dictionary:
	var sid := cookie_sid(req["h"])
	if sid != "" and sessions.has(sid) and sessions[sid]["exp"] > Time.get_unix_time_from_system():
		return sessions[sid]
	return {}

func _route(c: Conn, req: Dictionary) -> void:
	var m: String = req["m"]
	var path: String = req["path"]
	if m == "GET" and path == "/":
		_send_raw(c, 200, "text/html; charset=utf-8", PAGE.HTML.to_utf8_buffer())
		return
	if m == "GET" and path == "/app.js":
		_send_raw(c, 200, "application/javascript; charset=utf-8", PAGE.JS.to_utf8_buffer())
		return
	if not path.begins_with("/api/"):
		_send(c, 404, {"error": "Нет такой страницы"})
		return
	# API — только со своей страницы: заголовок X-Umwelt чужой сайт без спроса браузера не поставит
	if str(req["h"].get("x-umwelt", "")) != "1":
		_send(c, 403, {"error": "Запрос не со страницы лог-чекера"})
		return
	if m == "POST" and path == "/api/login":
		_login(c, req)
		return
	var s := _session(req)
	if s.is_empty():
		_send(c, 401, {"error": "Нужно войти"})
		return
	match [m, path]:
		["POST", "/api/logout"]:
			sessions.erase(cookie_sid(req["h"]))
			_send(c, 200, {"ok": true}, ["Set-Cookie: sid=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Strict"])
		["GET", "/api/meta"]:
			var u: Array = GL.usage()
			var names := {}
			for id in Items.DEFS:
				names[id] = Items.def(id)["name"]
			names["fists"] = "кулаки"
			_send(c, 200, {"who": s["who"], "cats": GL.CATS, "order": GL.CATS.keys(), "soon": GL.SOON, "today": GL.day_of(Time.get_unix_time_from_system()),
				"keep": GL.KEEP_DAYS, "range": GL.MAX_RANGE_DAYS, "bytes": u[0], "days": u[1], "items": names})
		["GET", "/api/logs"]:
			if job != null:
				_send(c, 503, {"error": "Идёт другой поиск — повтори через пару секунд"})
				return
			var q: Dictionary = req["query"]
			var cats := []
			for k in str(q.get("cats", "")).split(",", false):
				if GL.CATS.has(k):
					cats.append(k)
			if store != null and store.f != null:
				store.f.flush()
			job = Thread.new()
			job_conn = c
			job.start(Callable(GL, "query").bind({"cats": cats, "from": str(q.get("from", "")), "to": str(q.get("to", "")),
				"player": str(q.get("player", "")).left(40), "text": str(q.get("text", "")).left(100),
				"before": int(str(q.get("before", "0"))) if str(q.get("before", "")).is_valid_int() else 0,
				"limit": int(str(q.get("limit", "100"))) if str(q.get("limit", "")).is_valid_int() else 100}))
		_:
			_send(c, 404, {"error": "Нет такого запроса"})

## Вход: почта и пароль → Supabase → допущен ли (is_log_viewer) → сессия
func _login(c: Conn, req: Dictionary) -> void:
	var now := Time.get_unix_time_from_system()
	while fails.size() > 0 and fails[0][0] < now - FAIL_WINDOW:
		fails.pop_front()
	if login_locked(fails, c.ip):
		_send(c, 429, {"error": "Слишком много неудачных попыток — подожди 10 минут"})
		return
	var d = JSON.parse_string(str(req["body"]))
	if not (d is Dictionary) or str(d.get("email", "")) == "" or str(d.get("password", "")) == "":
		_send(c, 400, {"error": "Введи почту и пароль"})
		return
	var r: Array = await _sb("POST", "/auth/v1/token?grant_type=password", "", {"email": str(d["email"]).left(200), "password": str(d["password"]).left(200)})
	if r[0] != 200 or not (r[1] is Dictionary) or str(r[1].get("access_token", "")) == "":
		_fail(c, "Неверная почта или пароль" if r[0] == 400 else "Сервер аккаунтов недоступен (код %d)" % r[0])
		return
	var token := str(r[1]["access_token"])
	var uid := str(r[1].get("user", {}).get("id", ""))
	var ok: Array = await _sb("POST", "/rest/v1/rpc/is_log_viewer", token, {})
	if ok[0] != 200 or ok[1] != true:
		_fail(c, "Этому аккаунту лог-чекер не открыт")
		return
	var who := "Администратор"
	var ch: Array = await _sb("GET", "/rest/v1/characters?select=id,name&user_id=eq." + uid.uri_encode(), token, null)
	if ch[0] == 200 and ch[1] is Array and not ch[1].is_empty():
		who = "%s (%d)" % [str(ch[1][0]["name"]), int(ch[1][0]["id"])]
	var sid := Crypto.new().generate_random_bytes(32).hex_encode()
	sessions[sid] = {"exp": now + SESSION_TTL, "who": who}
	if game != null:
		game.glog("admin", null, {"e": "login", "n": who})
	if log_fn.is_valid():
		log_fn.call("лог-чекер: вход %s" % who)
	_send(c, 200, {"ok": true, "who": who}, ["Set-Cookie: sid=%s; Path=/; Max-Age=%d; HttpOnly; Secure; SameSite=Strict" % [sid, int(SESSION_TTL)]])

func _fail(c: Conn, why: String) -> void:
	fails.append([Time.get_unix_time_from_system(), c.ip])
	if game != null:
		game.glog("admin", null, {"e": "fail", "n": "Неизвестный"})
	if log_fn.is_valid():
		log_fn.call("лог-чекер: отказ во входе (%s)" % why)
	_send(c, 403, {"error": why})

func _sb(method: String, path: String, token: String, body) -> Array:
	var h := HTTPRequest.new()
	h.timeout = 15.0
	add_child(h)
	var hdr := PackedStringArray(["apikey: " + Boot.SUPABASE_KEY, "Content-Type: application/json"])
	if token != "":
		hdr.append("Authorization: Bearer " + token)
	var err := h.request(Boot.SUPABASE_URL + path, hdr, HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET,
		JSON.stringify(body) if body != null else "")
	if err != OK:
		h.queue_free()
		return [0, null]
	var r: Array = await h.request_completed
	h.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return [0, null]
	return [int(r[1]), JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())]

func _send(c: Conn, code: int, data, extra: Array = []) -> void:
	_send_raw(c, code, "application/json; charset=utf-8", JSON.stringify(data).to_utf8_buffer(), extra)

const REASON := {200: "OK", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 413: "Payload Too Large", 429: "Too Many Requests", 503: "Service Unavailable"}

func _send_raw(c: Conn, code: int, ctype: String, body: PackedByteArray, extra: Array = []) -> void:
	if not conns.has(c):
		return
	var head := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\n" % [code, REASON.get(code, "OK"), ctype, body.size()]
	head += "X-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nReferrer-Policy: no-referrer\r\n"
	head += "Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'\r\n"
	for e in extra:
		head += str(e) + "\r\n"
	head += "\r\n"
	var out := head.to_utf8_buffer()
	out.append_array(body)
	c.tls.put_data(out)
	c.close_in = 2.0
