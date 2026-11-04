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
		var s: Node = load("res://scripts/server_only/server.gd").new()     # серверный код — только в сборке сервера
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
		var at: GDScript = load("res://scripts/server_only/audit_test.gd")
		if at == null or not at.can_instantiate():
			# ошибка разбора в тестах: сразу выходим с ошибкой, а не висим до таймаута CI (BF-025)
			printerr("ОШИБКА: audit_test.gd не загрузился (ошибка в коде тестов)")
			get_tree().quit(1)
			return
		add_child(at.new())
		return
	for a in args:
		if a.begins_with("--authtest="):
			var at = load("res://scripts/server_only/authtest.gd").new()
			at.role = a.substr(11)
			at.main = self
			add_child(at)
			return
		if a.begins_with("--nettest="):
			var nt = load("res://scripts/server_only/nettest.gd").new()
			nt.role = a.substr(10)
			nt.main = self
			add_child(nt)
			return
	if demo == "editor":
		_open_editor(Vector2(-1, -1))       # для снимков и проверок: --demo=editor
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
		elif editor != null:
			editor.back()
		elif screen == null:
			get_tree().quit()

# ================== ЗАПУСК ==================
## Режим выбирает лаунчер (кнопки «Играть» / «Офлайн-тест»), меню в самой игре нет
func _start_from_launcher() -> void:
	var mode := str(Engine.get_meta("start_mode", "solo"))
	Engine.remove_meta("start_mode")
	if mode == "server":
		_play_server()
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

## Выход из игры — обратно в лаунчер (или в редактор карты, если пришли оттуда / выбрали его в паузе)
func _on_exit(_delete_save: bool) -> void:
	if screen != null and screen.next == "account":
		screen.queue_free()
		screen = null
		if Net.I != null:
			Net.I.close()
		_show_account("")
		return
	if screen != null and screen.next == "editor":
		var p := screen.me()
		var f := p.pos if p != null and screen.demo == "editor" else Vector2(-1, -1)
		screen.queue_free()
		screen = null
		_open_editor(f)
		return
	if Net.I != null:
		Net.I.close()
	get_tree().change_scene_to_file.call_deferred("res://launcher/launcher.tscn")

# ================== РЕДАКТОР КАРТЫ ==================
var editor: Node

func _open_editor(focus: Vector2) -> void:
	editor = load("res://scripts/map_editor.gd").new()
	if focus.x >= 0.0:
		editor.focus = focus
	add_child(editor)
	editor.finished.connect(_on_editor_done)

func _on_editor_done(action: String, focus: Vector2) -> void:
	editor.queue_free()
	editor = null
	if action != "walk":
		get_tree().change_scene_to_file.call_deferred("res://launcher/launcher.tscn")
		return
	# «Пройтись»: офлайн-игра на черновике, без сохранения; из паузы — обратно в редактор
	var g := GameState.new_game(1)
	var err := g.world.load_map(load("res://scripts/map_editor.gd").load_draft())
	if err == "":
		g.spawn = g.world.spawn
	var p: GameState.Player = g.players[0]
	p.pos = g.unstick(focus, GameState.PLAYER_R)
	if g.world.circle_blocked(p.pos.x, p.pos.y, GameState.PLAYER_R):
		p.pos = g.unstick(g.spawn, GameState.PLAYER_R)
	p.rpos = p.pos
	_start(GameScreen.Mode.SOLO, g)
	screen.demo = "editor"
	screen.hud.add_msg("Проверка черновика. Пауза → «Вернуться в редактор»")

# ================== АККАУНТ ==================
const AccountApi := preload("res://scripts/account.gd")
var acc: Node
var form: Control
var form_status: Label

func _play_server() -> void:
	if acc == null:
		acc = AccountApi.new()
		acc.name = "Account"
		add_child(acc)
	if acc.has_session():
		_form_wait("Вход в аккаунт…")
		if await acc.refresh():
			await _after_login()
			return
		_show_login(acc.last_error if acc.last_error != "" else "")
		return
	_show_login("")

func _after_login() -> void:
	_form_wait("Загружаю персонажа…")
	var n = await acc.load_character()
	if n == null:
		_show_login(acc.last_error)
	elif n == "":
		_show_create_character("")
	else:
		await acc.check_admin()
		_connect_game()

func _connect_game() -> void:
	_clear_form()
	Net.I.join(Boot.host(), Boot.port())
	_start(GameScreen.Mode.CLIENT, null)
	screen.auth_token = acc.access_token

# ---------- формы ----------
func _clear_form() -> void:
	if form != null:
		form.queue_free()
		form = null

## Основа формы: тёмный фон, колонка у верхнего края (снизу место для клавиатуры телефона)
func _form_base(title: String) -> VBoxContainer:
	_clear_form()
	form = Control.new()
	form.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(form)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	form.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	form.add_child(scroll)
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_top", 14)
	scroll.add_child(wrap)
	var center := CenterContainer.new()
	wrap.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(360, 0)
	center.add_child(col)
	col.add_child(_flabel(title, 24, Color(0.98, 0.45, 0.62)))
	form_status = _flabel("", 13, Color(0.95, 0.8, 0.45))
	form_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return col

func _flabel(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l

func _field(hint: String, secret: bool, kb: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = hint
	e.secret = secret
	e.virtual_keyboard_type = kb
	e.custom_minimum_size = Vector2(360, 42)
	e.add_theme_font_size_override("font_size", 16)
	return e

func _fbtn(t: String, c: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(360, 44)
	b.add_theme_font_size_override("font_size", 16)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c.darkened(0.5) if st == "disabled" else (c.lightened(0.12) if st == "pressed" else c)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b

func _form_wait(text: String) -> void:
	var col := _form_base("UMWELT RP")
	col.add_child(_flabel(text, 16, Color(0.8, 0.8, 0.8)))

func _back_to_launcher() -> void:
	_clear_form()
	get_tree().change_scene_to_file.call_deferred("res://launcher/launcher.tscn")

func _show_login(err: String, register := false) -> void:
	var col := _form_base("Регистрация" if register else "Вход в аккаунт")
	var mail := _field("Почта", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	mail.text = acc.email
	col.add_child(mail)
	var pw := _field("Пароль (минимум %d символов)" % AccountApi.MIN_PASSWORD if register else "Пароль", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	col.add_child(pw)
	var go := _fbtn("Создать аккаунт" if register else "Войти", Color(0.18, 0.42, 0.23), func(): pass)
	col.add_child(go)
	if register:
		var agree := _flabel("Создавая аккаунт, ты подтверждаешь, что тебе есть %d лет, и соглашаешься с политикой конфиденциальности." % AccountApi.MIN_AGE, 12, Color(0.65, 0.65, 0.7))
		agree.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		agree.custom_minimum_size = Vector2(360, 0)
		col.add_child(agree)
	col.add_child(form_status)
	form_status.text = err
	if register:
		col.add_child(_fbtn("Политика конфиденциальности", Color(0.2, 0.2, 0.24), func(): OS.shell_open(AccountApi.PRIVACY_URL)))
	col.add_child(_fbtn("Уже есть аккаунт — войти" if register else "Нет аккаунта — зарегистрироваться", Color(0.23, 0.29, 0.35), func(): _show_login("", not register)))
	col.add_child(_fbtn("Назад", Color(0.2, 0.2, 0.24), _back_to_launcher))
	go.pressed.connect(func():
		var m := mail.text.strip_edges()
		# при входе старый короткий пароль (до 8 символов) ещё действует — длину требуем только при регистрации
		if m == "" or pw.text == "" or (register and pw.text.length() < AccountApi.MIN_PASSWORD):
			form_status.text = "Введи почту и пароль (минимум %d символов)" % AccountApi.MIN_PASSWORD if register else "Введи почту и пароль"
			return
		go.disabled = true
		form_status.text = "Подожди…"
		if register:
			var res: String = await acc.sign_up(m, pw.text)
			if res == "ok":
				await _after_login()
			elif res == "confirm":
				_show_login("Готово! Мы отправили письмо на %s — открой его, нажми ссылку и потом войди здесь." % m)
			else:
				form_status.text = acc.last_error
				go.disabled = false
		else:
			if await acc.sign_in(m, pw.text):
				await _after_login()
			else:
				form_status.text = acc.last_error
				go.disabled = false)

## Аккаунт (из меню игры): вернуться в игру, выйти из аккаунта на этом телефоне, удалить аккаунт
func _show_account(err: String) -> void:
	var col := _form_base("Аккаунт")
	col.add_child(_flabel("%s\nПерсонаж: %s" % [acc.email, acc.char_name if acc.char_name != "" else "—"], 14, Color(0.8, 0.8, 0.8)))
	col.add_child(_fbtn("Вернуться в игру", Color(0.18, 0.42, 0.23), _play_server))
	col.add_child(_fbtn("Выйти из аккаунта на этом телефоне", Color(0.23, 0.29, 0.35), func():
		_form_wait("Выход…")
		await acc.logout()
		_back_to_launcher()))
	col.add_child(_fbtn("Удалить аккаунт…", Color(0.42, 0.18, 0.18), _show_delete_account))
	col.add_child(_fbtn("Политика конфиденциальности", Color(0.2, 0.2, 0.24), func(): OS.shell_open(AccountApi.PRIVACY_URL)))
	col.add_child(form_status)
	form_status.text = err
	col.add_child(_fbtn("В меню", Color(0.2, 0.2, 0.24), _back_to_launcher))

## Удаление аккаунта навсегда — только после слова «УДАЛИТЬ»
func _show_delete_account() -> void:
	var col := _form_base("Удаление аккаунта")
	var info := _flabel("Навсегда удалятся: аккаунт (%s), персонаж %s со всеми деньгами, вещами и одеждой. Вернуть нельзя. Чтобы подтвердить, напиши слово УДАЛИТЬ." % [acc.email, acc.char_name if acc.char_name != "" else ""], 13, Color(0.9, 0.75, 0.75))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(360, 0)
	col.add_child(info)
	var word := _field("УДАЛИТЬ", false, LineEdit.KEYBOARD_TYPE_DEFAULT)
	col.add_child(word)
	var go := _fbtn("Удалить навсегда", Color(0.55, 0.14, 0.14), func(): pass)
	col.add_child(go)
	col.add_child(form_status)
	col.add_child(_fbtn("Отмена", Color(0.2, 0.2, 0.24), func(): _show_account("")))
	go.pressed.connect(func():
		if word.text.strip_edges().to_upper() != "УДАЛИТЬ":
			form_status.text = "Напиши слово УДАЛИТЬ, чтобы подтвердить"
			return
		go.disabled = true
		form_status.text = "Удаляю…"
		if not await acc.refresh():
			form_status.text = acc.last_error if acc.last_error != "" else "Не получилось войти — попробуй ещё раз"
			go.disabled = false
			return
		if await acc.delete_account():
			var done := _form_base("Аккаунт удалён")
			var t := _flabel("Аккаунт и персонаж удалены. Из мира игры персонаж исчезнет в течение нескольких минут.", 14, Color(0.8, 0.8, 0.8))
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.custom_minimum_size = Vector2(360, 0)
			done.add_child(t)
			done.add_child(_fbtn("В меню", Color(0.2, 0.2, 0.24), _back_to_launcher))
		else:
			form_status.text = acc.last_error
			go.disabled = false)

func _show_create_character(err: String) -> void:
	var col := _form_base("Создание персонажа")
	col.add_child(_flabel("Имя и фамилия латиницей — как в Америке 90-х. Изменить потом нельзя.", 13, Color(0.7, 0.7, 0.7)))
	var first := _field("Имя (например, John)", false, LineEdit.KEYBOARD_TYPE_DEFAULT)
	col.add_child(first)
	var last := _field("Фамилия (например, Miller)", false, LineEdit.KEYBOARD_TYPE_DEFAULT)
	col.add_child(last)
	# пол: две кнопки, выбранная подсвечена
	var gender := ["m"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var bm := _fbtn("Мужчина", Color(0.23, 0.29, 0.35), func(): pass)
	var bf := _fbtn("Женщина", Color(0.23, 0.29, 0.35), func(): pass)
	for b in [bm, bf]:
		b.custom_minimum_size = Vector2(176, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		var on := StyleBoxFlat.new()
		on.bg_color = Color(0.62, 0.24, 0.4)
		on.set_corner_radius_all(12)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		row.add_child(b)
	bm.button_pressed = true
	var pick := func(g: String):
		gender[0] = g
		bm.set_pressed_no_signal(g == "m")
		bf.set_pressed_no_signal(g == "f")
	bm.pressed.connect(pick.bind("m"))
	bf.pressed.connect(pick.bind("f"))
	var go := _fbtn("Создать персонажа", Color(0.18, 0.42, 0.23), func(): pass)
	col.add_child(go)
	col.add_child(form_status)
	form_status.text = err
	col.add_child(_fbtn("Назад", Color(0.2, 0.2, 0.24), _back_to_launcher))
	go.pressed.connect(func():
		var f := first.text.strip_edges()
		var l := last.text.strip_edges()
		if f.length() > 0:
			f = f.left(1).to_upper() + f.substr(1).to_lower()
		if l.length() > 0:
			l = l.left(1).to_upper() + l.substr(1).to_lower()
		var bad := AccountApi.valid_name(f, l)
		if bad != "":
			form_status.text = bad
			return
		go.disabled = true
		form_status.text = "Подожди…"
		if await acc.create_character(f + "_" + l, gender[0]):
			_connect_game()
		else:
			form_status.text = acc.last_error
			go.disabled = false)
