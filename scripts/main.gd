extends Node
## Точка входа игры: её запускает лаунчер (режим в Engine meta "start_mode") или сервер с ключом --server.

var screen: GameScreen
var shot := ""
var shot_frames := 0
var shot_list: Array = []      # несколько кадров подряд: --shots=40,44,48
var demo_yaw := NAN
var demo_zoom := NAN

func _ready() -> void:
	Profile.load_profile()
	if Net.I == null or not is_instance_valid(Net.I):
		var n := Net.new()
		n.name = "Net"
		get_tree().root.add_child.call_deferred(n)
		await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var s := GameServer.new()
		s.name = "GameServer"
		add_child(s)
		return
	var demo := ""
	for a in args:
		if a.begins_with("--demo="):
			demo = a.substr(7)
		elif a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--zoom="):
			demo_zoom = float(a.substr(7))
		elif a.begins_with("--yaw="):
			demo_yaw = float(a.substr(6))
		elif a.begins_with("--shots="):
			for f in a.substr(8).split(","):
				shot_list.append(int(f))
	get_tree().set_auto_accept_quit(false)
	if "--audit" in args:
		add_child(load("res://scripts/audit_test.gd").new())
		return
	for a in args:
		if a.begins_with("--nettest="):
			var nt = load("res://scripts/nettest.gd").new()
			nt.role = a.substr(10)
			nt.main = self
			add_child(nt)
			return
	if demo != "":
		_start(GameScreen.Mode.SOLO, Demo.create(demo))
		screen.demo = demo
		screen.hud.open_demo_panel(demo)
	else:
		_start_from_launcher()

func _process(_dt: float) -> void:
	if shot != "":
		shot_frames += 1
		if not is_nan(demo_yaw) and screen != null and screen.view != null:
			screen.view.cam_yaw = demo_yaw
		if not is_nan(demo_zoom) and screen != null and screen.view != null:
			screen.view.cam_d = demo_zoom
		if shot_list.size() > 0:
			if shot_frames in shot_list:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(shot.replace(".png", "_%03d.png" % shot_frames))
			if shot_frames > shot_list.max():
				get_tree().quit()
		elif shot_frames == 45:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot)
			get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if screen != null:
			screen.save_now()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen != null and screen.hud != null:
			var h: Hud = screen.hud
			h._release()          # пальцы, зажатые до паузы, больше не двигают персонажа
			h.panel_id = -1
			if screen.game == null:
				screen.request_exit(false)      # ещё подключаемся — «Назад» = отмена
			else:
				h.panel = Hud.Pnl.PAUSE if h.panel == Hud.Pnl.NONE else Hud.Pnl.NONE
		elif screen == null:
			get_tree().quit()

# ================== ЗАПУСК ==================
## Режим выбирает лаунчер (кнопки «Играть» / «Офлайн-тест»), меню в самой игре нет
func _start_from_launcher() -> void:
	var mode := str(Engine.get_meta("start_mode", "solo"))
	Engine.remove_meta("start_mode")
	if mode == "server":
		Net.I.join(Boot.host(), Boot.port())
		_start(GameScreen.Mode.CLIENT, null)
	else:
		_start(GameScreen.Mode.SOLO, _solo_world())

func _solo_world() -> GameState:
	var g := Saves.load_game()
	if g == null:
		g = GameState.new_game(1990)
	return g

func _start(mode: int, g: GameState) -> void:
	screen = GameScreen.new()
	add_child(screen)
	screen.start(mode, g)
	screen.exited.connect(_on_exit)

## Выход из игры — обратно в лаунчер
func _on_exit(_delete_save: bool) -> void:
	if Net.I != null:
		Net.I.close()
	get_tree().change_scene_to_file.call_deferred("res://launcher/launcher.tscn")
