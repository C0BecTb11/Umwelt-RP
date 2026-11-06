class_name GameScreen
extends Node
## Игровой экран на телефоне: подключение к серверу (CLIENT) или офлайн-проверка (SOLO).
## Логика в SOLO считается тут же, в CLIENT — на сервере (scripts/server_only/server.gd). 3D — WorldView, интерфейс — Hud.

enum Mode { SOLO, CLIENT }

signal exited(delete_save: bool)

var mode := Mode.SOLO
var game: GameState
var view: WorldView
var hud: Hud
var local_pid := 0
var snap_t := 0.0
var input_t := 0.0
var autosave_t := 60.0
var lost := false
var can_retry := false            # связь оборвалась сама (не «до свидания» от сервера) — main.gd переподключит
var retry_note := ""              # что показать, пока ждём переподключения
var last_st_ms := 0               # когда пришёл последний снимок: 6 с тишины — связь считаем потерянной
const SILENCE_MS := 6000
var demo := ""
var debug_move := Vector2.ZERO   # для автотестов
var next := ""                   # куда после выхода: "editor" — в редактор карты (main.gd)
var _exiting := false

func start(m: int, g: GameState) -> void:
	mode = m
	game = g
	local_pid = -1 if m == Mode.CLIENT else 0
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.screen = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	if game != null:
		_make_view()

# ---------- напоминание об обновлении ----------
const MANIFEST_URL := "https://github.com/C0BecTb11/Umwelt-RP/releases/download/latest/manifest.json"
var upd_http: HTTPRequest
var upd_t := 5.0

func _check_update(dt: float) -> void:
	if demo != "":
		return
	if hud.update_note == "" and Engine.has_meta("latest_build") and str(Engine.get_meta("latest_build")) != Version.BUILD:
		_note_update(str(Engine.get_meta("latest_build")))
	upd_t -= dt
	if upd_t > 0.0:
		return
	upd_t = 180.0          # раз в 3 минуты
	if upd_http == null:
		upd_http = HTTPRequest.new()
		upd_http.timeout = 20.0
		upd_http.max_redirects = 8
		add_child(upd_http)
		upd_http.request_completed.connect(func(res, code, _h, body):
			if res != HTTPRequest.RESULT_SUCCESS or code != 200:
				return
			var m = JSON.parse_string(body.get_string_from_utf8())
			if m is Dictionary and m.has("build") and str(m["build"]) != Version.BUILD:
				_note_update(str(m["build"])))
	if upd_http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		upd_http.request(MANIFEST_URL + "?t=%d" % Time.get_unix_time_from_system())

func _note_update(b: String) -> void:
	if b.is_valid_int() and Version.BUILD.is_valid_int() and int(b) <= int(Version.BUILD):
		return
	if hud.update_note == "":
		hud.add_msg("Вышло обновление 0.%s" % b)
	hud.update_note = "Доступно обновление 0.%s — закрой и открой игру, чтобы установить" % b

func _make_view() -> void:
	view = WorldView.new()
	add_child(view)
	move_child(view, 0)
	view.setup(game.world)

func me() -> GameState.Player:
	return game.player(local_pid) if game != null else null

func act(a: Dictionary) -> void:
	if mode == Mode.CLIENT:
		if a.get("a") == "attack" and game != null and me() != null:
			game.predict_attack(me())
		var m := a.duplicate()
		m["t"] = "act"
		Net.I.send(m)
	elif game != null:
		game.actions.append([local_pid, a])

func save_now() -> void:
	if game == null or mode == Mode.CLIENT or demo != "" or _exiting:
		return
	Saves.save(game)

func request_exit(delete_save: bool) -> void:
	if _exiting:
		return
	if not delete_save:
		save_now()
	_exiting = true
	Net.I.close()
	exited.emit(delete_save)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_now()

var connect_t := 0.0

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	_check_update(dt)
	_handle_net()
	if game == null and mode == Mode.CLIENT and not lost:
		connect_t += dt
		if connect_t > 15.0:
			if Net.I.status == "" or Net.I.status.begins_with("Подключ"):
				Net.I.status = "Сервер не отвечает. Проверь интернет"
			Net.I.close()
			lost = true
			can_retry = true
	if game != null and mode == Mode.CLIENT and not lost and last_st_ms > 0 and Time.get_ticks_msec() - last_st_ms > SILENCE_MS:
		# ENet замечает обрыв только через 5–30 с; снимки идут 20 раз в секунду — 6 с без них значит, связи нет
		Net.I.status = "Нет связи с сервером"
		Net.I.close()
		lost = true
		can_retry = true
	if game == null:
		hud.queue_redraw()
		return
	var p := me()
	var mv := hud.joystick()
	if mv.length() > 0.0:
		mv = view.screen_to_world(mv)
	if debug_move != Vector2.ZERO:
		mv = debug_move
	var run := hud.run_toggle
	hud.tick(dt)
	if mode == Mode.CLIENT:
		# свой персонаж двигается сразу на этом телефоне, хосту уходит готовая позиция
		if p != null and not p.dead:
			p.move = mv
			p.run = run
			game.move_player(p, dt, false)
			p.rpos = p.pos
		input_t -= dt
		if input_t <= 0.0 and p != null:
			input_t = 0.05
			var o := {"t": "in", "ts": Time.get_ticks_msec(), "mx": mv.x, "my": mv.y, "run": run, "x": p.pos.x, "y": p.pos.y,
				"fx": p.face.x, "fy": p.face.y, "fs": p.force_seq}
			Net.I.send_fast(o)
		game.tick_replica(dt)
		# всё чужое рисуем чуть в прошлом, между двумя пришедшими снимками — плавно и без забегания
		var rt := render_time()
		for pl in game.players:
			if pl.id == local_pid:
				pl.rface = pl.face
				continue
			GameState.sample_snaps(pl, rt)
	else:
		if p != null:
			p.move = mv
			p.run = run
		var paused := mode == Mode.SOLO and hud.paused()
		if not paused:
			game.update(dt)
		for pl in game.players:
			pl.rpos = pl.pos
			pl.rface = pl.face
		for m in game.pop_messages(local_pid):
			hud.add_msg(m)
		game.world.dirty_tiles.clear()
		game.fx_net.clear()
		if not paused:
			autosave_t -= dt
			if autosave_t <= 0.0:
				autosave_t = 60.0
				save_now()
	if p != null:
		view.target = game.find_interact(p)
		view.update(dt, game, p, local_pid)
		if view.vibrate > 0:
			Input.vibrate_handheld(view.vibrate)
			view.vibrate = 0
	hud.queue_redraw()

# часы сервера: задержка отрисовки подстраивается под качество связи
var clock := GameState.NetClock.new()

func clock_sample(ts: float) -> void:
	clock.sample(ts, Time.get_ticks_msec())

func render_time() -> float:
	return clock.render_time(Time.get_ticks_msec())

## Клиент: «привет» серверу сразу после соединения
var auth_token := ""          # токен аккаунта Supabase; сервер сам узнаёт по нему, кто это

func _on_connected() -> void:
	# id телефона нужен только тестовому серверу без аккаунтов (--noauth); с аккаунтом его не отправляем
	Net.I.send({"t": "hello", "token": auth_token, "uid": Profile.uid if auth_token == "" else "", "nick": Profile.nick, "build": Version.BUILD})

var _hello_sent := false

func _handle_net() -> void:
	if mode != Mode.CLIENT:
		Net.I.inbox.clear()
		return
	if Net.I.connected and not _hello_sent:
		_hello_sent = true
		_on_connected()
	while Net.I.inbox.size() > 0:
		var o: Dictionary = Net.I.inbox.pop_front()
		match str(o.get("t", "")):
			"init":
				if game != null:
					continue
				var g := GameState.new(int(o["seed"]))
				g.is_replica = true
				g.load_data(o["world"])
				local_pid = int(o["pid"])
				for pl in g.players:
					pl.connected = pl.id == local_pid or pl.connected
				game = g
				if view == null:
					_make_view()
			"st":
				last_st_ms = Time.get_ticks_msec()
				if game != null:
					clock_sample(float(o.get("ts", 0)))
					game.apply_state(o, local_pid)
			"ev":
				if game != null:
					game.apply_events(o, local_pid)
					for m in o.get("m", []):
						hud.add_msg(m)
			"bye":
				Net.I.status = str(o.get("why", "Сервер закрыл соединение"))
				Net.I.close()
				lost = true
				# «до свидания» с причиной не повторяем (аккаунт удалён, вход с другого устройства, нужна новая
				# версия); перезапуск сервера — повторяем: через несколько секунд он снова примет
				can_retry = Net.I.status.begins_with("Сервер перезапускается")
			"disconnect":
				if not lost:
					can_retry = true
				lost = true
