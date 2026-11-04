extends Node
## НЕ попадает в APK (папка scripts/server_only/ исключена из экспорта Android). Загружается в main.gd через load().
## Выделенный сервер (запуск: godot --headless -- --server [--port=7777] [--max=64]).
## Вся игровая логика считается здесь; телефоны только присылают ввод и действия.

const SAVE_PATH := "user://server_world.json"
const SAVE_BAK := "user://server_world.bak.json"
const SAVE_HOURLY := "user://server_world.h%02d.json"   # копия раз в час, 24 штуки по кругу (BF-028)
const WORLD_SEED := 1990

var game: GameState
var port := Net.DEFAULT_PORT
var max_clients := 64
var by_peer := {}            # id подключения → Client
const AUTOSAVE := 15.0       # сек. Остановка службы (systemctl stop при обновлении) не даёт сохраниться — теряется
                            # не больше этого времени (BF-029)
var autosave_t := AUTOSAVE
var stat_t := 10.0
var started_ms := 0
var noauth := false

const MAX_MSG := 8192          # байт: больше честный клиент не шлёт (токен в «привете» — до ~2 КБ)
const HELLO_WAIT := 5.0        # сек. ждём «привет» от нового подключения (пока идёт проверка в Supabase — 25)
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
		elif a == "--noauth":
			noauth = true          # только для локальных тестов: вход по uid телефона без аккаунта
	started_ms = Time.get_ticks_msec()
	game = _load_world()
	if game == null:
		game = GameState.new_game(WORLD_SEED)
		game.players.clear()        # на сервере нет «своего» игрока
		_log("создан новый мир, seed %d" % WORLD_SEED)
	for p in game.players:
		p.connected = false
		p.remote = true
	if not Net.I.serve(port, max_clients):
		_log("ОШИБКА: " + Net.I.status)
		get_tree().quit(1)
		return
	_log("сборка %s, порт %d, мест %d, персонажей в базе %d" % [Version.BUILD, port, max_clients, game.players.size()])

func _log(s: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(), s])

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	_handle_net(dt)
	game.update(dt)
	for c: Client in by_peer.values():
		if c.pid >= 0:
			_send_to(c, dt)
	game.world.dirty_tiles.clear()
	game.fx_net.clear()
	# сообщения тем, кого нет, не копим
	for pid in game.messages.keys():
		var p := game.player(pid)
		if p == null or not p.connected:
			game.messages.erase(pid)
	autosave_t -= dt
	if autosave_t <= 0.0:
		autosave_t = AUTOSAVE
		save_world()
	stat_t -= dt
	if stat_t <= 0.0:
		stat_t = 60.0
		_log("онлайн %d, кадр %.1f мс" % [_online(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])

func _online() -> int:
	var n := 0
	for c: Client in by_peer.values():
		if c.pid >= 0:
			n += 1
	return n

## Каждому — свой снимок: позиции рядом с ним 20 раз в секунду, события по готовности
func _send_to(c: Client, dt: float) -> void:
	c.state_t -= dt
	if c.state_t <= 0.0:
		c.state_t = 0.05
		Net.I.send_fast(game.state_for(c.pid), c.peer)
	c.full_t -= dt
	var full := c.full_t <= 0.0
	if full:
		c.full_t = 0.25
	var ev := game.events_for(c.pid, full)
	if ev.size() > 1:
		Net.I.send(ev, c.peer)

func _handle_net(dt: float) -> void:
	# новые подключения и те, кто молчит
	for id in Net.I.peers:
		if not by_peer.has(id):
			var c := Client.new()
			c.peer = id
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
					_enter(c, uid, str(o.get("nick", "Гражданин")).strip_edges().left(24), "")
				else:
					c.checking = true
					_verify(c, str(o.get("token", "")), str(o.get("legacy", "")).left(64))
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
						_log("вышел %s, онлайн %d" % [p2.name if p2 != null else "?", _online() - 1])
					by_peer.erase(from)
					save_world()

# ================== вход по аккаунту ==================
## Проверка токена в Supabase: кто это и как зовут его персонажа. Секретные ключи серверу не нужны —
## запросы идут с токеном самого игрока, а правила базы отдают ему только его персонажа.
func _verify(c: Client, token: String, legacy: String) -> void:
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
	var ch: Array = await _sb("/rest/v1/characters?select=id,name,gender&user_id=eq." + user_id, token)
	if not by_peer.has(c.peer):
		return
	if ch[0] != 200 or not (ch[1] is Array) or ch[1].is_empty():
		_reject(c, "У аккаунта нет персонажа — создай его при входе")
		return
	_enter(c, "sb:" + user_id, str(ch[1][0]["name"]), legacy, int(ch[1][0].get("id", -1)), str(ch[1][0].get("gender", "m")))

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

## Впустить в мир. key — ключ аккаунта; legacy — старый uid телефона (персонаж до аккаунтов переходит к аккаунту)
func _enter(c: Client, key: String, pname: String, legacy: String, static_id: int = -1, gender: String = "") -> void:
	c.checking = false
	if not by_peer.has(c.peer):
		return
	if legacy != "" and not game.uids.has(key) and game.uids.has(legacy):
		game.uids[key] = game.uids[legacy]
		game.uids.erase(legacy)
		_log("персонаж телефона %s… привязан к аккаунту %s" % [legacy.left(6), pname])
	# тот же аккаунт уже в игре с другого подключения — старое закрываем
	for other: Client in by_peer.values():
		if other != c and other.pid >= 0 and game.uids.get(key, -1) == other.pid:
			Net.I.send({"t": "bye", "why": "В этот аккаунт вошли с другого устройства"}, other.peer)
			Net.I.kick(other.peer)
			other.pid = -1
	var p := game.join_player(key, pname if pname != "" else "Гражданин", static_id, gender)
	c.pid = p.id
	c.full_t = 0.0
	Net.I.send({"t": "init", "pid": p.id, "seed": game.seed, "world": game.to_data_for(p.id)}, c.peer)
	_log("вошёл %s (%d), подключение %d, онлайн %d" % [p.name, p.id, c.peer, _online()])
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
