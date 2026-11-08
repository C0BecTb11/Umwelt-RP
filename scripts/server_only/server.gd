extends Node
## НЕ попадает в APK (папка scripts/server_only/ исключена из экспорта Android). Загружается в main.gd через load().
## Выделенный сервер (запуск: godot --headless -- --server [--port=7777] [--max=64]).
## Вся игровая логика считается здесь; телефоны только присылают ввод и действия.

const SAVE_PATH := "user://server_world.json"
const SAVE_BAK := "user://server_world.bak.json"
const SAVE_HOURLY := "user://server_world.h%02d.json"   # копия раз в час, 24 штуки по кругу (BF-028)
## Запрос остановки (BF-029): systemd при остановке службы создаёт этот файл (ExecStop в setup.sh) и ждёт, пока
## сервер сохранит мир и выйдет сам. Сигнал остановки Godot не ловит — без файла мир терялся бы за последние 15 с
const STOP_FILE := "user://stop.request"
const WORLD_SEED := 1990
## Резервные копии мира в Supabase (0.54): раз в час сжатый файл мира уходит в базу (world_backups, хранится 7 дней).
## Ключ сервер создаёт сам (BACKUP_KEY_FILE, как ключ DTLS) и при первом запуске регистрирует его отпечаток —
## только если в базе ещё нет ключа. Работает только на боевом порту (Net.DEFAULT_PORT) с аккаунтами:
## тесты (--noauth, другие порты, --nobackup) ключ не регистрируют и копии не шлют
const BACKUP_KEY_FILE := "user://backup.key"
const BACKUP_EVERY := 3600.0   # сек. между копиями (база сама не примет чаще раза в 50 минут)
const BACKUP_FIRST := 300.0    # первая копия — через 5 минут после запуска
## Журнал действий игроков и лог-чекер администратора (0.55): журнал пишет любой сервер (в свою папку данных),
## сайт https://<сервер>:8443 — боевой сервер (как копии) или с ключом --admin=ПОРТ (проверки)
const GameLog = preload("res://scripts/server_only/game_log.gd")
const AdminSite = preload("res://scripts/server_only/admin_site.gd")

var game: GameState
var port := Net.DEFAULT_PORT
var max_clients := 64
var by_peer := {}            # id подключения → Client
const AUTOSAVE := 15.0       # сек. Остановка службы (systemctl stop при обновлении) не даёт сохраниться — теряется
                            # не больше этого времени (BF-029)
var autosave_t := AUTOSAVE
var stat_t := 10.0
var stat_every := 60.0         # сек. между строками статистики в журнале (--stat=N — для нагрузочного теста)
var stat_frames := 0           # за промежуток: кадров, сумма и худшее время кадра (с), сколько времени прошло
var stat_sum := 0.0
var stat_max := 0.0
var stat_time := 0.0
var started_ms := 0
var noauth := false
var deleted_t := 2.0           # проверка удалённых аккаунтов (BF-044): через 2 с после запуска, потом раз в DELETED_EVERY
var deleted_state := ""        # последний итог проверки удалённых аккаунтов — в журнал только при смене
var backup_on := false         # копии в Supabase включены (боевой сервер)
var backup_key := ""           # 64 hex-символа; в базе — только sha256 от него
var backup_t := BACKUP_FIRST
var no_backup := false         # --nobackup
var log_store                  # game_log.gd
var admin: Node                # admin_site.gd
var admin_port := 0            # --admin=ПОРТ
var refused_ip := 0            # отказано подключениям сверх MAX_PENDING_IP (в журнал раз в минуту)
var stop_t := 0.0
var sig_t := 0.0
var map_z := PackedByteArray() # карта для входящих, сжатая (BF-051); пустая — пересобрать
var map_n := 0

const MAX_MSG := 8192          # байт: больше честный клиент не шлёт (токен в «привете» — до ~2 КБ)
const HELLO_WAIT := 5.0        # сек. ждём «привет» от нового подключения (пока идёт проверка в Supabase — 25)
const DELETED_EVERY := 300.0   # сек.: как часто сервер спрашивает Supabase об удалённых аккаунтах (BF-044)
const MAX_PENDING_IP := 3      # подключений без входа с одного адреса: больше — сразу отключаем (С4, BF-043)
static var _token_re: RegEx

## Ведро жетонов: не больше rate событий в секунду, с запасом cap. Лишнее отбрасывается (защита от спама, С4/Н8)
class Bucket:
	var rate := 1.0
	var cap := 1.0
	var tokens := 1.0
	var last := -1.0
	func _init(r: float, c: float) -> void:
		rate = r
		cap = c
		tokens = c
	func take(now: float) -> bool:
		if last >= 0.0:
			tokens = minf(cap, tokens + maxf(0.0, now - last) * rate)
		last = now
		if tokens < 1.0:
			return false
		tokens -= 1.0
		return true

class Client:
	var peer := 0
	var pid := -1
	var clock := GameState.NetClock.new()
	var state_t := 0.0
	var full_t := 0.0
	var acts := Bucket.new(10.0, 15.0)    # действия: 10 в секунду, разом до 15
	var ins := Bucket.new(40.0, 40.0)     # пакеты движения: телефон шлёт 20 в секунду, запас на пачки после задержки
	var hello_t := 0.0           # сколько ждём «привет» после подключения
	var checking := false        # идёт проверка аккаунта в Supabase
	var ip := ""                 # адрес подключения

## Сколько подключений с адреса ip ещё не вошли в мир (ждут «привет» или проверку аккаунта).
## Вошедших не считаем: за одним адресом может быть много честных игроков (общий Wi-Fi, мобильный оператор)
static func pending_from(clients: Array, ip: String) -> int:
	var n := 0
	for c: Client in clients:
		if c.pid < 0 and c.ip == ip and ip != "":
			n += 1
	return n

## Сообщение крупнее, чем бывает у честного клиента
static func too_big(o: Dictionary) -> bool:
	return var_to_bytes(o).size() > MAX_MSG

## Токен Supabase: только символы JWT, разумная длина — до запроса в Supabase и подстановки в заголовок (Н6)
static func valid_token(t: String) -> bool:
	if _token_re == null:
		_token_re = RegEx.create_from_string("[^A-Za-z0-9._-]")     # любой посторонний символ, включая перевод строки
	return t.length() >= 20 and t.length() <= 4096 and _token_re.search(t) == null

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = int(a.substr(7))
		elif a.begins_with("--max="):
			max_clients = clampi(int(a.substr(6)), 1, 4000)
		elif a.begins_with("--stat="):
			stat_every = clampf(float(a.substr(7)), 1.0, 3600.0)
			stat_t = stat_every
		elif a == "--noauth":
			noauth = true          # только для локальных тестов: вход по uid телефона без аккаунта
		elif a.begins_with("--admin="):
			admin_port = int(a.substr(8))
		elif a == "--nobackup":
			no_backup = true       # тестовый сервер с аккаунтами (CI auth-test): копий в Supabase не слать
	started_ms = Time.get_ticks_msec()
	if FileAccess.file_exists(STOP_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STOP_FILE))   # старый запрос от прошлой остановки
	game = _load_world()
	backup_on = not noauth and not no_backup and port == Net.DEFAULT_PORT
	if backup_on:
		set_process(false)                 # пока говорим с базой, мир ещё не готов
		backup_key = load_backup_key(BACKUP_KEY_FILE)
		var reg: Array = await _rpc("register_backup_key", {"key_hash": backup_key.sha256_text()})
		var accepted: bool = reg[1] == true
		_log("резервные копии в Supabase: %s" % ("ключ сервера принят" if accepted else ("ОШИБКА — в базе другой ключ сервера (переустановка? раздел 6 руководства)" if reg[0] == 200 else "база недоступна (код %d), попробую при отправке" % reg[0])))
		if game == null and accepted:
			game = await _restore_backup()
		set_process(true)
	if game == null:
		game = GameState.new_game(WORLD_SEED)
		game.players.clear()        # на сервере нет «своего» игрока
		_log("создан новый мир, seed %d" % WORLD_SEED)
	for p in game.players:
		p.connected = false
		p.remote = true
	if not noauth:
		var gone := drop_phone_chars(game)
		if gone > 0:
			_log("удалены персонажи без аккаунта (по id телефона): %d" % gone)
	game.log_on = true
	log_store = GameLog.new()
	if admin_port == 0 and backup_on:
		admin_port = AdminSite.DEFAULT_PORT
	if admin_port > 0:
		admin = AdminSite.new()
		admin.game = game
		admin.store = log_store
		admin.log_fn = _log
		add_child(admin)
		var ok: bool = admin.start(admin_port)
		_log("лог-чекер: %s" % ("https://<адрес сервера>:%d" % admin_port if ok else ("порт %d пока занят — пробую раз в 10 с" % admin_port if admin.tls_opts != null else "ОШИБКА — нет ключа сайта")))
	if not Net.I.serve(port, max_clients, Net.server_tls("user://dtls")):
		_log("ОШИБКА: " + Net.I.status)
		get_tree().quit(1)
		return
	_log("сборка %s, порт %d, мест %d, персонажей в базе %d, канал зашифрован (DTLS)" % [Version.BUILD, port, max_clients, game.players.size()])

## Персонажи «по id телефона» (до аккаунтов) на сервере с аккаунтами больше не нужны: перенос к аккаунту по id
## телефона убран (закрытый аудит, Н1; BF-042), а войти в них можно только в --noauth. Убираем их ключи и карточки,
## если на карточку не ссылается ни один аккаунт. Возвращает, сколько карточек удалено
static func drop_phone_chars(g: GameState) -> int:
	var keep := {}
	for k in g.uids:
		if str(k).begins_with("sb:"):
			keep[int(g.uids[k])] = true
	var drop := {}
	for k in g.uids.keys():
		if not str(k).begins_with("sb:"):
			if not keep.has(int(g.uids[k])):
				drop[int(g.uids[k])] = true
			g.uids.erase(k)
	var n := 0
	for i in range(g.players.size() - 1, -1, -1):
		var p: GameState.Player = g.players[i]
		if drop.has(p.id) and not p.connected:
			g.players.remove_at(i)
			n += 1
	return n

## Удалённые аккаунты (BF-044): у кого sha256(id) есть в hashes — ключ «sb:id» и карточка персонажа убираются из
## мира. Возвращает id удалённых карточек (сервер отключает тех, кто в игре)
static func drop_deleted(g: GameState, hashes: Array) -> Array:
	var wanted := {}
	for h in hashes:
		wanted[str(h).to_lower()] = true
	var gone := []
	for k in g.uids.keys():
		var key := str(k)
		if key.begins_with("sb:") and wanted.has(key.substr(3).sha256_text()):
			gone.append(int(g.uids[k]))
			g.uids.erase(k)
	for i in range(g.players.size() - 1, -1, -1):
		if gone.has(g.players[i].id):
			g.players.remove_at(i)
	return gone

## Спросить Supabase об удалённых аккаунтах (publishable-ключ, функция deleted_accounts: только отпечатки id)
func _sync_deleted() -> void:
	var h := HTTPRequest.new()
	h.timeout = 15.0
	add_child(h)
	var err := h.request(Boot.SUPABASE_URL + "/rest/v1/rpc/deleted_accounts", PackedStringArray(["apikey: " + Boot.SUPABASE_KEY, "Content-Type: application/json"]), HTTPClient.METHOD_POST, "{}")
	if err != OK:
		h.queue_free()
		return
	var r: Array = await h.request_completed
	h.queue_free()
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8()) if r[0] == HTTPRequest.RESULT_SUCCESS and int(r[1]) == 200 else null
	var st := "доступен" if d is Array else "недоступен (связь %d, код %d)" % [r[0], int(r[1])]
	if st != deleted_state:
		deleted_state = st
		_log("журнал удалённых аккаунтов: %s" % (st + (" (записей %d)" % d.size() if d is Array else "")))
	if not (d is Array):
		return
	var hashes := []
	for e in d:
		if e is Dictionary and e.has("h"):
			hashes.append(str(e["h"]))
	var names := {}
	for p0: GameState.Player in game.players:
		names[p0.id] = p0.name
	var gone := drop_deleted(game, hashes)
	if gone.is_empty():
		return
	for gid in gone:
		game.glog("acc", null, {"e": "deleted", "p": gid, "n": names.get(gid, "")})
	# кто сейчас в игре под удалённым аккаунтом (например, со второго телефона) — отключаем
	for c: Client in by_peer.values():
		if gone.has(c.pid):
			Net.I.send({"t": "bye", "why": "Аккаунт удалён"}, c.peer)
			Net.I.kick(c.peer)
			c.pid = -1
	_log("удалены персонажи удалённых аккаунтов: %d" % gone.size())
	save_world()

# ================== резервные копии в Supabase (0.54) ==================
## Ключ сервера для копий: читаем из файла или создаём случайный (32 байта → 64 hex). Не меняется, пока жив файл
static func load_backup_key(path: String) -> String:
	if FileAccess.file_exists(path):
		var k := FileAccess.get_file_as_string(path).strip_edges()
		if k.length() == 64 and k.is_valid_hex_number():
			return k
	var key := Crypto.new().generate_random_bytes(32).hex_encode()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(key)
		f.close()
	return key

## Копия мира для базы: JSON мира → gzip → base64. {} — мир не превращается в читаемый файл
static func backup_payload(g: GameState) -> Dictionary:
	var text := GameState.save_text(g.to_data())
	if text == "":
		return {}
	var raw := text.to_utf8_buffer()
	return {"data": Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP)), "players": g.players.size(), "raw_bytes": raw.size()}

## Обратно: base64 → gzip → JSON мира; null — испорчено
static func backup_unpack(b64: String):
	var z := Marshalls.base64_to_raw(b64)
	if z.is_empty():
		return null
	var raw := z.decompress_dynamic(64 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	var d = JSON.parse_string(raw.get_string_from_utf8()) if raw.size() > 0 else null
	return d if GameState.valid_save(d) else null

## Вызов функции базы publishable-ключом (роль anon): [код ответа, разобранный ответ]
func _rpc(fn: String, body: Dictionary) -> Array:
	var h := HTTPRequest.new()
	h.timeout = 30.0
	add_child(h)
	var err := h.request(Boot.SUPABASE_URL + "/rest/v1/rpc/" + fn, PackedStringArray(["apikey: " + Boot.SUPABASE_KEY, "Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		h.queue_free()
		return [0, null]
	var r: Array = await h.request_completed
	h.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return [0, null]
	return [int(r[1]), JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())]

func _send_backup() -> void:
	var pl := backup_payload(game)
	if pl.is_empty():
		_log("резервная копия в Supabase: мир не прошёл проверку — не отправлена")
		return
	pl["token"] = backup_key
	var r: Array = await _rpc("put_world_backup", pl)
	var res := str(r[1]) if r[0] == 200 else "код %d" % r[0]
	match res:
		"ok": _log("резервная копия в Supabase: отправлена (%d КБ, персонажей %d)" % [str(pl["data"]).length() / 1024, int(pl["players"])])
		"too_soon": pass                   # перезапуск сервера: копия этого часа уже есть
		"denied": _log("резервная копия в Supabase: ОШИБКА — ключ сервера не принят (раздел 6 руководства)")
		_: _log("резервная копия в Supabase: не отправлена (%s)" % res)

## Своего файла мира нет (новый сервер или все файлы испорчены) — берём последнюю копию из базы
func _restore_backup() -> GameState:
	var r: Array = await _rpc("get_latest_world_backup", {"token": backup_key})
	if r[0] != 200 or not (r[1] is Dictionary):
		_log("своего мира нет, копии в Supabase нет (код %d)" % r[0])
		return null
	var d = backup_unpack(str(r[1].get("data", "")))
	if d == null:
		_log("ОШИБКА: копия мира из Supabase испорчена")
		return null
	var g := GameState.new(int(d.get("seed", WORLD_SEED)))
	g.load_data(d)
	_log("мир восстановлен из копии в Supabase от %s (персонажей %d)" % [str(r[1].get("created_at", "?")), g.players.size()])
	return g

func _log(s: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(), s])

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	_handle_net(dt)
	game.update(dt)
	sig_t -= dt
	game.index_players(sig_t <= 0.0)   # сетка по районам на время рассылки (BF-049); подписи внешности — раз в 0.2 с
	if sig_t <= 0.0:
		sig_t = 0.2
	for c: Client in by_peer.values():
		if c.pid >= 0:
			_send_to(c, dt)
	game.grid_on = false
	if not game.world.dirty_tiles.is_empty():
		map_z.clear()              # двери изменились — карту для входящих пересобрать
	game.world.dirty_tiles.clear()
	game.fx_net.clear()
	# сообщения тем, кого нет, не копим
	for pid in game.messages.keys():
		var p := game.player(pid)
		if p == null or not p.connected:
			game.messages.erase(pid)
	for pid in game.chat.keys():
		var p3 := game.player(pid)
		if p3 == null or not p3.connected:
			game.chat.erase(pid)
	autosave_t -= dt
	if autosave_t <= 0.0:
		autosave_t = AUTOSAVE
		save_world()
	var ft := Performance.get_monitor(Performance.TIME_PROCESS)
	stat_frames += 1
	stat_sum += ft
	stat_max = maxf(stat_max, ft)
	stat_time += dt
	stat_t -= dt
	if stat_t <= 0.0:
		stat_t = stat_every
		_log(stat_line())
		stat_frames = 0
		stat_sum = 0.0
		stat_max = 0.0
		stat_time = 0.0
		if refused_ip > 0:
			_log("отклонено лишних подключений без входа с одного адреса: %d" % refused_ip)
			refused_ip = 0
	if not noauth:
		deleted_t -= dt
		if deleted_t <= 0.0:
			deleted_t = DELETED_EVERY
			_sync_deleted()
	if log_store != null:
		log_store.write(game.log_buf, Time.get_unix_time_from_system())
		game.log_buf.clear()
		log_store.tick(dt)
	if admin != null:
		admin.poll(dt)
	if backup_on:
		backup_t -= dt
		if backup_t <= 0.0:
			backup_t = BACKUP_EVERY
			_send_backup()
	stop_t -= dt
	if stop_t <= 0.0:
		stop_t = 0.25
		if FileAccess.file_exists(STOP_FILE):
			_stop()

## Строка статистики за промежуток: онлайн, кадр (средний и худший), кадров в секунду, исходящий трафик, память
func stat_line() -> String:
	var sent := 0.0
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer and (mp as ENetMultiplayerPeer).host != null:
		sent = (mp as ENetMultiplayerPeer).host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
	var span := maxf(stat_time, 0.001)
	return "онлайн %d, кадр %.1f мс (худший %.1f), %d кадров/с, отправлено %.1f КБ/с, память %d МБ" % [_online(),
		stat_sum / maxi(stat_frames, 1) * 1000.0, stat_max * 1000.0, roundi(stat_frames / span), sent / 1024.0 / span,
		roundi(OS.get_static_memory_usage() / 1048576.0)]

## Остановка по запросу службы: всем «до встречи», мир — на диск, файл-запрос убираем, выходим сами
func _stop() -> void:
	for c: Client in by_peer.values():
		Net.I.send({"t": "bye", "why": "Сервер перезапускается — зайди через минуту"}, c.peer)
	save_world()
	_close_logs()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STOP_FILE))
	_log("остановка по запросу службы: мир сохранён, онлайн был %d" % _online())
	set_process(false)
	get_tree().quit(0)

func _online() -> int:
	var n := 0
	for c: Client in by_peer.values():
		if c.pid >= 0:
			n += 1
	return n

## Каждому — свой снимок: позиции рядом с ним 20 раз в секунду, события по готовности
func _send_to(c: Client, dt: float) -> void:
	c.state_t -= dt
	c.full_t -= dt
	var snap := c.state_t <= 0.0
	if snap:
		c.state_t = 0.05
		Net.I.send_fast(game.state_for(c.pid), c.peer)
	# полные данные — в том же кадре, что снимок: список видимых уже найден (vis_cache, BF-049)
	var full := snap and c.full_t <= 0.0
	if full:
		c.full_t = 0.25
	# между полными — только если есть что слать (эффекты, двери, сообщения); иначе не собираем пакет каждый кадр
	if not full and game.fx_net.is_empty() and game.world.dirty_tiles.is_empty() and not game.messages.has(c.pid) and not game.chat.has(c.pid):
		return
	var ev := game.events_for(c.pid, full)
	if ev.size() > 1:
		Net.I.send(ev, c.peer)

func _handle_net(dt: float) -> void:
	# новые подключения и те, кто молчит
	for id in Net.I.peers:
		if not by_peer.has(id):
			var c := Client.new()
			c.peer = id
			c.ip = Net.I.peer_ip(id)
			if pending_from(by_peer.values(), c.ip) >= MAX_PENDING_IP:
				# с этого адреса уже ждут входа несколько подключений — не даём занять все места (С4)
				refused_ip += 1
				Net.I.kick(id)
				continue
			by_peer[id] = c
	for c: Client in by_peer.values():
		if c.pid < 0:
			c.hello_t += dt
			if c.hello_t > (25.0 if c.checking else HELLO_WAIT):
				Net.I.kick(c.peer)
	while Net.I.inbox.size() > 0:
		var o: Dictionary = Net.I.inbox.pop_front()
		var from := int(o.get("_from", 0))
		var t := str(o.get("t", ""))
		var c: Client = by_peer.get(from)
		if c != null and too_big(o):
			_log("подключение %d: слишком большое сообщение «%s» — отключено" % [from, t.left(16)])
			Net.I.kick(from)
			continue
		var now := Time.get_ticks_msec() / 1000.0
		match t:
			"hello":
				if c == null or c.pid >= 0 or c.checking:
					continue                      # второй «привет» с того же подключения не принимаем
				var build := str(o.get("build", ""))
				if build != Version.BUILD:
					# сервер подтягивает новую сборку раз в пару минут — клиент может успеть раньше
					var newer := build.is_valid_int() and Version.BUILD.is_valid_int() and int(build) > int(Version.BUILD)
					var why := "Сервер обновляется до новой версии — зайди через пару минут" if newer else "Вышло обновление — перезапусти игру, лаунчер его скачает"
					Net.I.send({"t": "bye", "why": why}, from)
					continue
				if noauth:
					var uid := str(o.get("uid", "")).left(64)
					if uid.length() < 8:
						Net.I.kick(from)
						continue
					_enter(c, uid, str(o.get("nick", "Гражданин")).strip_edges().left(24))
				else:
					c.checking = true
					_verify(c, str(o.get("token", "")))
			"in":
				if c == null or c.pid < 0 or not c.ins.take(now):
					continue
				var pl := game.player(c.pid)
				if pl != null:
					game.remote_input(pl, o)
					var ts := GameState.net_num(o, "ts", NAN)
					if is_finite(ts):
						c.clock.sample(ts, Time.get_ticks_msec())
						GameState.push_snap(pl, ts, pl.pos, pl.face)
			"act":
				if c == null or c.pid < 0 or not c.acts.take(now):
					continue
				var a := o.duplicate()
				a.erase("t")
				a.erase("_from")
				game.actions.append([c.pid, a])
			"disconnect":
				if c != null:
					if c.pid >= 0:
						var p2 := game.player(c.pid)
						game.leave_player(c.pid)
						game.glog("conn", p2, {"e": "out", "on": _online() - 1})
						_log("вышел %s, онлайн %d" % [p2.name if p2 != null else "?", _online() - 1])
					by_peer.erase(from)
					save_world()

# ================== вход по аккаунту ==================
## Проверка токена в Supabase: кто это и как зовут его персонажа. Секретные ключи серверу не нужны —
## запросы идут с токеном самого игрока, а правила базы отдают ему только его персонажа.
func _verify(c: Client, token: String) -> void:
	if not valid_token(token):
		_reject(c, "Войди в аккаунт заново")
		return
	var u: Array = await _sb("/auth/v1/user", token)
	if not by_peer.has(c.peer):
		return                                # ушёл, пока проверяли
	if u[0] != 200 or not (u[1] is Dictionary) or str(u[1].get("id", "")) == "":
		_reject(c, "Сессия устарела — войди в аккаунт заново" if u[0] == 401 or u[0] == 403 else "Сервер аккаунтов недоступен, попробуй позже")
		return
	var user_id := str(u[1]["id"])
	var ch: Array = await _sb("/rest/v1/characters?select=id,name,gender,created_at&user_id=eq." + user_id, token)
	if not by_peer.has(c.peer):
		return
	if ch[0] != 200 or not (ch[1] is Array) or ch[1].is_empty():
		_reject(c, "У аккаунта нет персонажа — создай его при входе")
		return
	_enter(c, "sb:" + user_id, str(ch[1][0]["name"]), int(ch[1][0].get("id", -1)), str(ch[1][0].get("gender", "m")),
		GameState.reg_from_iso(str(ch[1][0].get("created_at", ""))))

func _reject(c: Client, why: String) -> void:
	c.checking = false
	Net.I.send({"t": "bye", "why": why}, c.peer)
	_log("отказ во входе (подключение %d): %s" % [c.peer, why])

func _sb(path: String, token: String) -> Array:
	var h := HTTPRequest.new()
	h.timeout = 15.0
	add_child(h)
	var err := h.request(Boot.SUPABASE_URL + path, PackedStringArray(["apikey: " + Boot.SUPABASE_KEY, "Authorization: Bearer " + token]))
	if err != OK:
		h.queue_free()
		return [0, null]
	var r: Array = await h.request_completed
	h.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return [0, null]
	return [int(r[1]), JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())]

## Впустить в мир. key — ключ аккаунта («sb:…»; в --noauth — uid телефона).
## Перенос персонажа «по id телефона» к аккаунту убран (Н1, BF-042): чужой id телефона больше ничего не даёт
func _enter(c: Client, key: String, pname: String, static_id: int = -1, gender: String = "", reg_date: String = "") -> void:
	c.checking = false
	if not by_peer.has(c.peer):
		return
	# тот же аккаунт уже в игре с другого подключения — старое закрываем
	for other: Client in by_peer.values():
		if other != c and other.pid >= 0 and game.uids.get(key, -1) == other.pid:
			Net.I.send({"t": "bye", "why": "В этот аккаунт вошли с другого устройства"}, other.peer)
			Net.I.kick(other.peer)
			other.pid = -1
	var p := game.join_player(key, pname if pname != "" else "Гражданин", static_id, gender, reg_date)
	c.pid = p.id
	c.full_t = 0.0
	if map_z.is_empty():
		var pk: Array = GameState.pack_map(game.world.map_data())
		map_z = pk[0]
		map_n = pk[1]
	Net.I.send({"t": "init", "pid": p.id, "seed": game.seed, "world": game.to_data_for(p.id, false), "mapz": map_z, "mapn": map_n}, c.peer)
	_log("вошёл %s (%d), подключение %d, онлайн %d" % [p.name, p.id, c.peer, _online()])
	game.glog("conn", p, {"e": "in", "on": _online()})
	for other: Client in by_peer.values():
		if other.pid >= 0 and other.pid != p.id:
			game.msg(other.pid, "%s в городе" % GameState.tag(p))

# ================== сохранение мира ==================
func save_world() -> void:
	var text := GameState.save_text(game.to_data())
	if text == "":
		# мир в памяти не превращается в читаемый файл — старые файлы не трогаем, иначе потеряем и их
		_log("ОШИБКА: мир не прошёл проверку перед записью — файл и резервная копия не перезаписаны")
		return
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		_log("ОШИБКА: не удалось записать мир")
		return
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp).length() != text.length():
		_log("ОШИБКА: запись мира оборвалась")
		return
	# в резервную копию — только прежний файл, который сам читается (испорченный копией не становится)
	if FileAccess.file_exists(SAVE_PATH) and GameState.valid_save(JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(SAVE_BAK))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))
	# раз в час — отдельная копия на этот час суток: можно вернуться на несколько часов назад
	var hp := SAVE_HOURLY % int(Time.get_datetime_dict_from_system()["hour"])
	if not FileAccess.file_exists(hp) or Time.get_unix_time_from_system() - FileAccess.get_modified_time(hp) > 3000:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(hp))

## Мир: основной файл, резервная копия, затем часовые копии от свежей к старой
func _load_world() -> GameState:
	var hourly := []
	for h in 24:
		var hp := SAVE_HOURLY % h
		if FileAccess.file_exists(hp):
			hourly.append([FileAccess.get_modified_time(hp), hp])
	hourly.sort_custom(func(a, b): return a[0] > b[0])
	var paths := [SAVE_PATH, SAVE_BAK]
	for e in hourly:
		paths.append(e[1])
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not GameState.valid_save(d):
			_log("файл %s повреждён — пробую резервный" % path)
			continue
		var g := GameState.new(int(d.get("seed", WORLD_SEED)))
		g.load_data(d)
		_log("мир загружен из %s" % path)
		return g
	return null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if game != null:
			save_world()
		_close_logs()

func _close_logs() -> void:
	if game != null and log_store != null:
		log_store.write(game.log_buf, Time.get_unix_time_from_system())
		game.log_buf.clear()
		log_store.close()
	if admin != null:
		admin.stop()
