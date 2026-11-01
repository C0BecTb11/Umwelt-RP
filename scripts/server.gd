class_name GameServer
extends Node
## Выделенный сервер (запуск: godot --headless -- --server [--port=7777] [--max=64]).
## Вся игровая логика считается здесь; телефоны только присылают ввод и действия.

const SAVE_PATH := "user://server_world.json"
const SAVE_BAK := "user://server_world.bak.json"
const WORLD_SEED := 1990

var game: GameState
var port := Net.DEFAULT_PORT
var max_clients := 64
var by_peer := {}            # id подключения → Client
var autosave_t := 60.0
var stat_t := 10.0
var started_ms := 0

class Client:
	var peer := 0
	var pid := -1
	var clock := GameState.NetClock.new()
	var state_t := 0.0
	var full_t := 0.0
	var acts := 0
	var hello_t := 0.0           # сколько ждём «привет» после подключения

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = int(a.substr(7))
		elif a.begins_with("--max="):
			max_clients = clampi(int(a.substr(6)), 1, 4000)
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
	for c: Client in by_peer.values():
		c.acts = 0
	_handle_net(dt)
	game.update(dt)
	for c: Client in by_peer.values():
		if c.pid >= 0:
			_send_to(c, dt)
	game.world.dirty_tiles.clear()
	game.world.dirty_cont.clear()
	game.fx_net.clear()
	# сообщения тем, кого нет, не копим
	for pid in game.messages.keys():
		var p := game.player(pid)
		if p == null or not p.connected:
			game.messages.erase(pid)
	autosave_t -= dt
	if autosave_t <= 0.0:
		autosave_t = 60.0
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
			if c.hello_t > 10.0:
				Net.I.kick(c.peer)
	while Net.I.inbox.size() > 0:
		var o: Dictionary = Net.I.inbox.pop_front()
		var from := int(o.get("_from", 0))
		var t := str(o.get("t", ""))
		var c: Client = by_peer.get(from)
		match t:
			"hello":
				if c == null or c.pid >= 0:
					continue                      # второй «привет» с того же подключения не принимаем
				var build := str(o.get("build", ""))
				if build != Version.BUILD:
					# сервер подтягивает новую сборку раз в пару минут — клиент может успеть раньше
					var newer := build.is_valid_int() and Version.BUILD.is_valid_int() and int(build) > int(Version.BUILD)
					var why := "Сервер обновляется до новой версии — зайди через пару минут" if newer else "Вышло обновление — перезапусти игру, лаунчер его скачает"
					Net.I.send({"t": "bye", "why": why}, from)
					continue
				var uid := str(o.get("uid", "")).left(64)
				if uid.length() < 8:
					Net.I.kick(from)
					continue
				# тот же аккаунт уже в игре с другого подключения — старое закрываем
				for other: Client in by_peer.values():
					if other != c and other.pid >= 0 and game.uids.get(uid, -1) == other.pid:
						Net.I.kick(other.peer)
						other.pid = -1
				var nick := str(o.get("nick", "Гражданин")).strip_edges().left(24)
				var p := game.join_player(uid, nick if nick != "" else "Гражданин")
				c.pid = p.id
				c.full_t = 0.0
				Net.I.send({"t": "init", "pid": p.id, "seed": game.seed, "world": game.to_data_for(p.id)}, from)
				_log("вошёл %s (персонаж %d, подключение %d), онлайн %d" % [p.name, p.id, from, _online()])
				for other: Client in by_peer.values():
					if other.pid >= 0 and other.pid != p.id:
						game.msg(other.pid, "%s в городе" % p.name)
			"in":
				if c == null or c.pid < 0:
					continue
				var pl := game.player(c.pid)
				if pl != null:
					game.remote_input(pl, o)
					if o.has("ts"):
						var ts := float(o["ts"])
						c.clock.sample(ts, Time.get_ticks_msec())
						GameState.push_snap(pl, ts, pl.pos, pl.face, pl.climb)
			"act":
				if c == null or c.pid < 0 or c.acts >= 30:
					continue
				c.acts += 1
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

# ================== сохранение мира ==================
func save_world() -> void:
	var text := JSON.stringify(game.to_data())
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
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(SAVE_BAK))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))

func _load_world() -> GameState:
	for path in [SAVE_PATH, SAVE_BAK]:
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
