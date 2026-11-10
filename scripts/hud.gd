class_name Hud
extends Control
## Интерфейс поверх 3D: мудлы, кнопки, джойстик, панели (вещи, одежда, пауза).

enum Pnl { NONE, INV, PAUSE, GEAR, MENU, STATS }

var screen: GameScreen
var font: Font
var sb := StyleBoxFlat.new()

# ввод
var joy_id := -1
var joy_base := Vector2.ZERO
var joy_pos := Vector2.ZERO
var attack_id := -1
var attack_repeat := 0.0
var cam_id := -1
var cam_last := 0.0
var run_toggle := false

var panel := Pnl.NONE
var selected := ""
var scroll := [0.0, 0.0]
var panel_id := -1
var panel_down := Vector2.ZERO
var panel_last_y := 0.0
var panel_drag := false
var update_note := ""     # постоянное напоминание: вышла новая версия
var msgs: Array = []      # [текст, время]
# чат (с 0.52): строки [текст, когда пришла (мс), вид (0.56)]; поле ввода — LineEdit (клавиатура телефона)
var chat_lines: Array = []
var chat_open := false
var chat_edit: LineEdit
var chat_send := Rect2()
var chat_chips: Array = []     # [Rect2, "/me "] — кнопки ролевых команд под полем ввода (0.56)
const RP_COL := Color(0.80, 0.68, 0.92)      # ролевые команды — сиреневым, как в SAMP
const TRY_OK := Color(0.45, 0.88, 0.45)
const TRY_BAD := Color(0.98, 0.42, 0.40)
const CHAT_KEEP := 40          # строк в истории
const CHAT_SHOW := 6           # строк на экране, пока чат закрыт
const CHAT_LIFE := 30.0        # с: строка видна, потом гаснет (в открытом чате — вся история)
# облачко над головой говорящего (с 0.53): id игрока → [текст, когда сказал (мс), сколько висит (с), вид (0.56)]
var bubbles := {}
const BUBBLE_W := 210.0        # ширина текста облачка
var bubble_hold := false       # демо-снимки: облачка не гаснут (под виртуальным экраном кадры идут медленно)

# кнопки: центр и радиус
var b_attack := [Vector2.ZERO, 50.0]
var b_interact := [Vector2.ZERO, 36.0]
var b_run := [Vector2.ZERO, 32.0]
var b_inv := [Vector2.ZERO, 24.0]
var b_pause := [Vector2.ZERO, 24.0]
var b_gear := [Vector2.ZERO, 24.0]
var b_menu := [Vector2.ZERO, 24.0]   # меню игрока (статистика и дальше) — с 0.52
var b_chat := [Vector2.ZERO, 24.0]   # написать в чат — с 0.52
var gear_slot := ""           # выбранный слот в «Снаряжении»
var gear_rects: Array = []     # [Rect2, слот]
var gear_rows: Array = []      # [Rect2, id] вещи, которые можно надеть
var btn_a := Rect2()
var btn_b := Rect2()
var btn_c := Rect2()
var btn_d := Rect2()          # пауза: «Редактор карты» (только владелец, офлайн) или «Вернуться в редактор»
var btn_close := Rect2()
var panel_rect := Rect2()
const ROW_H := 40.0

var vignette: GradientTexture2D
var hurt_tex: GradientTexture2D

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette = _radial(Color(0, 0, 0, 0), Color(0, 0, 0, 0.45), 0.55)
	hurt_tex = _radial(Color(0.6, 0, 0, 0), Color(0.65, 0, 0, 0.75), 0.35)
	chat_edit = LineEdit.new()
	chat_edit.visible = false
	chat_edit.max_length = GameState.CHAT_MAX
	chat_edit.placeholder_text = "Сообщение или /me, /do, /todo, /try"
	chat_edit.add_theme_font_size_override("font_size", 18)
	chat_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_edit.text_submitted.connect(func(_t: String) -> void: _send_chat())
	add_child(chat_edit)

static func _radial(inner: Color, outer: Color, start: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, inner)
	g.set_offset(1, 1.0)
	g.set_color(1, outer)
	g.add_point(start, inner)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 1.0)
	t.width = 128
	t.height = 128
	return t

func paused() -> bool: return panel == Pnl.PAUSE

func add_msg(s: String) -> void:
	# длинную плашку (PayDay) успеть прочитать; пришедшие в одном кадре (две строки PayDay) гаснут вместе
	var life := clampf(2.0 + s.length() * 0.07, 4.0, 9.0)
	var fr := Engine.get_process_frames()
	for m in msgs:
		if int(m[2]) == fr:
			life = maxf(life, m[1])
			m[1] = life
	msgs.append([s, life, fr])
	if msgs.size() > 4:
		msgs.pop_front()

## Запись чата от сервера: [id сказавшего, текст, строка чата, вид] — строка в чат, текст — облачком над головой.
## Вид (с 0.56): say — речь, me/do/todo — ролевые (сиреневым), try1/try0 — /try «Удачно»/«Неудачно»
func on_chat(e) -> void:
	if not (e is Array) or e.size() < 3:
		return
	var k := str(e[3]) if e.size() > 3 else "say"
	add_chat(str(e[2]), k)
	var t := str(e[1])
	bubbles[int(e[0])] = [t, Time.get_ticks_msec(), clampf(3.0 + t.length() * 0.07, 4.0, 10.0), k]

func add_chat(s: String, k: String = "say") -> void:
	chat_lines.append([s, Time.get_ticks_msec(), k])
	if chat_lines.size() > CHAT_KEEP:
		chat_lines.pop_front()

func open_chat() -> void:
	chat_open = true
	_release()
	var s := _safe()
	var w := minf(s.size.x * 0.55, 620.0)
	chat_edit.position = Vector2(s.position.x + 14, 60)
	chat_edit.size = Vector2(w - 120, 44)
	chat_send = Rect2(s.position.x + 14 + w - 112, 60, 112, 44)
	chat_chips.clear()
	var cx := s.position.x + 14
	for c in ["/me", "/do", "/todo", "/try"]:
		var cw := _tw(c, 15) + 26
		chat_chips.append([Rect2(cx, 110, cw, 32), c + " "])
		cx += cw + 8
	chat_edit.text = ""
	chat_edit.visible = true
	chat_edit.grab_focus()

func close_chat() -> void:
	chat_open = false
	chat_edit.release_focus()
	chat_edit.visible = false
	DisplayServer.virtual_keyboard_hide()

## Кнопка команды: поставить её в начало строки (вместо другой команды, если была), текст оставить
func _chip(cmd: String) -> void:
	var t := chat_edit.text
	if t.begins_with("/"):
		t = t.substr(t.find(" ") + 1) if t.contains(" ") else ""
	chat_edit.text = cmd + t.strip_edges(true, false)
	chat_edit.caret_column = chat_edit.text.length()
	chat_edit.grab_focus()

func _send_chat() -> void:
	var t := GameState.clean_chat(chat_edit.text)
	if t != "":
		screen.act({"a": "say", "text": t})
	close_chat()

func joystick() -> Vector2:
	if joy_id < 0:
		return Vector2.ZERO
	var m := ((joy_pos - joy_base) / 60.0).limit_length(1.0)
	return Vector2.ZERO if m.length() < 0.15 else m

func tick(dt: float) -> void:
	if attack_id >= 0:
		attack_repeat -= dt
		if attack_repeat <= 0.0:
			attack_repeat = 0.12
			screen.act({"a": "attack"})
	var i := msgs.size() - 1
	while i >= 0:
		msgs[i][1] -= dt
		if msgs[i][1] <= 0.0:
			msgs.remove_at(i)
		i -= 1

func open_demo_panel(kind: String) -> void:
	if kind.begins_with("mil") or kind.begins_with("din"):
		visible = false                   # витрина мебели — без кнопок
		return
	match kind:
		"inv":
			panel = Pnl.INV
			selected = "medkit"
		"gear":
			panel = Pnl.GEAR
			gear_slot = "torso"
		"menu":
			panel = Pnl.MENU
		"stats":
			panel = Pnl.STATS
		"chat":
			open_chat()
		"rp":
			bubble_hold = true
		"rpopen":
			bubble_hold = true
			open_chat()
			chat_edit.text = "/todo Держи*протягивая зажигалку"

# ================== РАСКЛАДКА ==================
func _safe() -> Rect2:
	var r := get_viewport_rect()
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	if scr.x > 0 and safe.size.x > 0:
		var k := r.size.x / scr.x
		var l := safe.position.x * k
		var rr := (scr.x - safe.end.x) * k
		return Rect2(r.position + Vector2(l, 0), r.size - Vector2(l + rr, 0))
	return r

func _layout() -> void:
	var s := _safe()
	var W := s.end.x
	var H := s.size.y
	b_attack[0] = Vector2(W - 88, H - 84)
	b_interact[0] = Vector2(W - 196, H - 54)
	b_run[0] = Vector2(W - 186, H - 150)
	b_pause[0] = Vector2(W - 38, 38)
	b_inv[0] = Vector2(W - 96, 38)
	b_gear[0] = Vector2(W - 154, 38)
	b_menu[0] = Vector2(W - 212, 38)
	b_chat[0] = Vector2(W - 270, 38)

func _hit(b: Array, p: Vector2) -> bool:
	return p.distance_to(b[0]) < b[1] * 1.15

func _release() -> void:
	joy_id = -1
	attack_id = -1
	cam_id = -1

# ================== КАСАНИЯ ==================
func _input(e: InputEvent) -> void:
	if screen == null:
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		_touch(0 if t.pressed else 2, t.index, t.position)
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		_touch(1, d.index, d.position)

var _down := {}          # пальцы, нажатые уже на этом экране
var cancel_btn := Rect2()

func _touch(type: int, id: int, p: Vector2) -> void:
	# отпускание пальца, нажатого ещё в меню (например, на кнопке сервера), игнорируем
	if type == 0:
		_down[id] = true
	elif not _down.has(id):
		return
	if type == 2:
		_down.erase(id)
	var g := screen.game
	if screen.lost or g == null:
		if type == 2 and (screen.lost or cancel_btn.has_point(p)):
			screen.request_exit(false)
		return
	var me := screen.me()
	if me == null:
		return
	if chat_open:
		# пока пишешь — игра не управляется; тап мимо поля закрывает чат, поле ввода само ловит свои касания
		if type == 0:
			if chat_send.has_point(p):
				_send_chat()
				return
			for c in chat_chips:
				if (c[0] as Rect2).has_point(p):
					_chip(c[1])
					return
			if not Rect2(chat_edit.position, chat_edit.size).has_point(p):
				close_chat()
		return
	if me.dead:
		return      # без сознания: ждём, пока персонаж очнётся
	if panel != Pnl.NONE:
		_panel_touch(g, me, type, id, p)
		return
	_layout()
	match type:
		0:
			if _hit(b_pause, p):
				panel = Pnl.PAUSE
				_release()
			elif _hit(b_menu, p):
				panel = Pnl.MENU
				_release()
			elif _hit(b_chat, p):
				open_chat()
			elif _hit(b_inv, p):
				panel = Pnl.INV
				scroll[0] = 0.0
				_release()
			elif _hit(b_gear, p):
				panel = Pnl.GEAR
				gear_slot = ""
				_release()
			elif _hit(b_run, p):
				run_toggle = not run_toggle
			elif _hit(b_interact, p) and screen.view.target >= 0:
				screen.act({"a": "interact", "c": screen.view.target})
			elif _hit(b_attack, p):
				attack_id = id
				attack_repeat = 0.0
			elif p.x < get_viewport_rect().size.x * 0.55 and joy_id < 0:
				joy_id = id
				joy_base = p
				joy_pos = p
			elif cam_id < 0:
				cam_id = id
				cam_last = p.x
		1:
			if id == joy_id:
				joy_pos = p
			if id == cam_id:
				screen.view.cam_yaw = fmod(screen.view.cam_yaw - (p.x - cam_last) * 0.3, 360.0)
				cam_last = p.x
		2:
			if id == joy_id:
				joy_id = -1
			if id == attack_id:
				attack_id = -1
			if id == cam_id:
				cam_id = -1

func _panel_touch(g: GameState, me: GameState.Player, type: int, id: int, p: Vector2) -> void:
	_layout_panel()
	match type:
		0:
			if panel_id < 0:
				panel_id = id
				panel_down = p
				panel_last_y = p.y
				panel_drag = false
		1:
			if id == panel_id:
				if p.distance_to(panel_down) > 10.0:
					panel_drag = true
				if panel_drag:
					var col := 0
					scroll[col] = maxf(0.0, scroll[col] - (p.y - panel_last_y))
				panel_last_y = p.y
		2:
			if id == panel_id:
				panel_id = -1
				if not panel_drag:
					_panel_tap(g, me, p)

func _panel_tap(g: GameState, me: GameState.Player, p: Vector2) -> void:
	if btn_close.has_point(p):
		panel = Pnl.NONE
		return
	match panel:
		Pnl.MENU:
			if btn_a.has_point(p):
				panel = Pnl.STATS
		Pnl.STATS:
			if btn_b.has_point(p):
				panel = Pnl.MENU
		Pnl.PAUSE:
			if btn_a.has_point(p):
				panel = Pnl.NONE
			elif btn_b.has_point(p):
				screen.request_exit(false)
			elif btn_c.has_point(p):
				Profile.low_gfx = not Profile.low_gfx
				Profile.save_profile()
			elif btn_d.has_point(p) and _editor_btn() != "":
				screen.next = "editor"
				screen.request_exit(false)
			elif btn_d.has_point(p) and screen.mode == GameScreen.Mode.CLIENT:
				screen.next = "account"            # экран аккаунта: выйти из аккаунта, удалить аккаунт (BF-044)
				screen.request_exit(false)
		Pnl.INV:
			var col := _col_rect(0, 1)
			if col.has_point(p):
				var i := _row_at(col, scroll[0], p.y, me.inv.size())
				if i >= 0:
					selected = me.inv[i]["id"]
			if selected != "" and me.count(selected) > 0:
				if btn_a.has_point(p):
					screen.act({"a": "use", "id": selected})
				elif btn_b.has_point(p):
					screen.act({"a": "drop", "id": selected})
					selected = ""
		Pnl.GEAR:
			for gr in gear_rects:
				if gr[0].has_point(p):
					gear_slot = gr[1]
					return
			for row in gear_rows:
				if row[0].has_point(p):
					screen.act({"a": "wear", "id": row[1]})
					return
			if gear_slot != "" and btn_a.has_point(p):
				if gear_slot == "hand":
					if me.eq != "":
						screen.act({"a": "use", "id": me.eq})
				elif me.wear.has(gear_slot):
					screen.act({"a": "unwear", "slot": gear_slot})
func _rr(r: Rect2, rad: float, col: Color) -> void:
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.border_width_left = 0
	sb.border_width_right = 0
	sb.border_width_top = 0
	sb.border_width_bottom = 0
	sb.draw(get_canvas_item(), r)

func _text(pos: Vector2, s: String, size: int, col: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT, shadow: bool = false) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	if shadow:
		draw_string(font, Vector2(x + 1, pos.y + 1.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.8))
	draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _tw(s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# ================== РИСОВАНИЕ ==================
func _draw() -> void:
	if screen == null:
		return
	var g := screen.game
	var vr := get_viewport_rect()
	if g == null:
		draw_rect(vr, Color(0.06, 0.07, 0.08))
		var st := Net.I.status if Net.I.status != "" else "Загрузка…"
		if screen.lost:
			st = (Net.I.status if Net.I.status != "" else "Соединение потеряно") + " — коснись экрана"
		if screen.retry_note != "":
			st = screen.retry_note + " Коснись — выйти в меню"
		_text(vr.get_center(), st, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		if not screen.lost:
			cancel_btn = Rect2(vr.get_center() + Vector2(-90, 30), Vector2(180, 46))
			_rr(cancel_btn, 10, Color(0.31, 0.33, 0.35))
			_text(cancel_btn.get_center() + Vector2(0, 6), "Отмена", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var me := screen.me()
	if me == null:
		return
	_overlays(g, me, vr)
	_hud(g, me)
	match panel:
		Pnl.INV: _draw_inv(me)
		Pnl.PAUSE: _draw_pause()
		Pnl.GEAR: _draw_gear(me)
		Pnl.MENU: _draw_menu()
		Pnl.STATS: _draw_stats(g, me)
	if me.dead:
		_draw_dead(g, me, vr)
	if screen.lost:
		draw_rect(vr, Color(0, 0, 0, 0.8))
		_text(vr.get_center(), screen.retry_note if screen.retry_note != "" else "Соединение с сервером потеряно", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		_text(vr.get_center() + Vector2(0, 30), "Коснись, чтобы выйти в меню", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

func _overlays(g: GameState, me: GameState.Player, vr: Rect2) -> void:
	for p in g.players:
		if p.dead or not p.connected or p.ta_act == null:
			continue
		var s: Vector2 = screen.view.project(Vector3(p.rpos.x, 2.2, p.rpos.y))
		var r := 16.0
		draw_circle(s, r + 4, Color(0.06, 0.07, 0.08, 0.7))
		draw_arc(s, r, -PI / 2, -PI / 2 + TAU * p.ta_progress(), 32, Color(0.94, 0.88, 0.63), 4.0, true)
		_text(s + Vector2(0, -r - 9), p.ta_name, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	for p in g.players:
		if p.dead or not p.connected or p.id == me.id:
			continue
		var nm: String = GameState.tag(p)
		var sp: Vector2 = screen.view.project(Vector3(p.rpos.x, 2.05, p.rpos.y))
		_text(sp, nm, 12, Color(0.75, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, true)
	_bubbles(g, me)
	draw_texture_rect(vignette, vr, false)
	var low := 0.0
	if me.hp < 30.0 and not me.dead:
		low = (0.35 + 0.25 * sin(Time.get_ticks_msec() / 220.0)) * (1.0 - me.hp / 30.0)
	var hf := maxf(screen.view.hurt_flash, low)
	if hf > 0.01:
		draw_texture_rect(hurt_tex, vr, false, Color(1, 1, 1, hf))

class Moodle:
	var g := ""
	var lvl := 0
	var label := ""
	func _init(a: String, b: int, c: String) -> void:
		g = a
		lvl = b
		label = c

func _moodles(g: GameState, me: GameState.Player) -> Array:
	var m: Array = []
	var lv := func(v: float) -> int: return 3 if v >= 85.0 else (2 if v >= 65.0 else (1 if v >= 45.0 else 0))
	var hu: int = lv.call(me.hunger)
	if hu > 0: m.append(Moodle.new("hunger", hu, "Голод"))
	var th: int = lv.call(me.thirst)
	if th > 0: m.append(Moodle.new("drop", th, "Жажда"))
	if me.weight() > me.max_weight(): m.append(Moodle.new("weight", 2, "Тяжело"))
	if me.stamina < 25.0: m.append(Moodle.new("tired", 2 if me.stamina < 10.0 else 1, "Устал"))
	if me.sneaking: m.append(Moodle.new("eye", 0, "Тихо"))
	return m

func _hud(g: GameState, me: GameState.Player) -> void:
	_layout()
	var s := _safe()
	var x := s.position.x + 14.0
	var y := 12.0
	var cw := 190.0
	_rr(Rect2(x, y, cw, 44), 12, Color(0.055, 0.07, 0.085, 0.6))
	# сердце
	var hc := Vector2(x + 20, y + 18)
	draw_circle(hc + Vector2(-3.5, -2), 4.5, Color(0.88, 0.28, 0.28))
	draw_circle(hc + Vector2(3.5, -2), 4.5, Color(0.88, 0.28, 0.28))
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-8, -0.5), hc + Vector2(8, -0.5), hc + Vector2(0, 8)]), Color(0.88, 0.28, 0.28))
	var bx := x + 36
	var bw := cw - 48
	_rr(Rect2(bx, y + 12, bw, 10), 5, Color(1, 1, 1, 0.33))
	_rr(Rect2(bx, y + 12, bw * clampf(me.hp / 100.0, 0, 1), 10), 5, Color(0.88, 0.19, 0.19) if me.hp < 30.0 else Color(0.85, 0.35, 0.29))
	_rr(Rect2(bx, y + 29, bw, 4), 2, Color(1, 1, 1, 0.25))
	_rr(Rect2(bx, y + 29, bw * clampf(me.stamina / 100.0, 0, 1), 4), 2, Color(0.91, 0.78, 0.31))
	# наличные и своё имя с ID
	var money := "$%d" % me.money
	_rr(Rect2(x + cw + 8, y + 7, _tw(money, 16) + 22, 30), 12, Color(0.055, 0.07, 0.085, 0.6))
	_text(Vector2(x + cw + 19, y + 28), money, 16, Color(0.55, 0.9, 0.5))
	if screen.mode == GameScreen.Mode.CLIENT:
		_text(Vector2(x + cw + 8 + _tw(money, 16) + 32, y + 27), GameState.tag(me), 14, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_LEFT, true)
	# мудлы
	var mx := x + 4
	var my := y + 70
	var mds := _moodles(g, me)
	for m in mds:
		var ring: Color = [Color(0.54, 0.56, 0.59), Color(0.91, 0.78, 0.31), Color(0.91, 0.54, 0.19), Color(0.88, 0.23, 0.23)][m.lvl]
		draw_circle(Vector2(mx + 17, my), 17, Color(0.08, 0.09, 0.13, 0.75))
		draw_arc(Vector2(mx + 17, my), 16, 0, TAU, 32, ring, 2.5, true)
		Icons.glyph(self, m.g, Vector2(mx + 17, my), 12, Color.WHITE)
		_text(Vector2(mx + 17, my + 30), m.label, 10, Color(1, 1, 1, 0.87), HORIZONTAL_ALIGNMENT_CENTER, true)
		mx += 42
	# часы
	var W := get_viewport_rect().size.x
	var H := get_viewport_rect().size.y
	var night := g.darkness() > 0.5
	var date := g.date_str()
	var clock := ("%s  ·  %s" % [date, g.clock()]) if date != "" else g.clock()
	var tw := _tw(clock, 14) + 44
	_rr(Rect2(W / 2 - tw / 2, 12, tw, 30), 15, Color(0.055, 0.07, 0.085, 0.6))
	Icons.glyph(self, "moon" if night else "sun", Vector2(W / 2 - tw / 2 + 18, 27), 10, Color(0.72, 0.78, 0.94) if night else Color(0.94, 0.78, 0.31))
	_text(Vector2(W / 2 + 10, 32), clock, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# напоминание об обновлении — под часами, пока не перезапустят игру
	var ty := 66.0
	if update_note != "":
		var uw := _tw(update_note, 12) + 24
		_rr(Rect2(W / 2 - uw / 2, 48, uw, 22), 11, Color(0.55, 0.38, 0.12, 0.85))
		_text(Vector2(W / 2, 63), update_note, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		ty = 92.0
	# сообщения (плашки) — внизу по центру: сверху слева теперь чат (с 0.52), сверху по центру — часы
	ty = H - 44.0 - (msgs.size() - 1) * 26.0
	for msg in msgs:
		var a := minf(1.0, msg[1])
		var mw := _tw(msg[0], 13) + 28
		_rr(Rect2(W / 2 - mw / 2, ty - 16, mw, 22), 11, Color(0.055, 0.07, 0.085, 0.7 * a))
		_text(Vector2(W / 2, ty), msg[0], 13, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
		ty += 26
	# джойстик
	if joy_id >= 0:
		draw_circle(joy_base, 62, Color(1, 1, 1, 0.19))
		draw_arc(joy_base, 62, 0, TAU, 48, Color(1, 1, 1, 0.33), 2.0, true)
		draw_arc(joy_base, 37, 0, TAU, 40, Color(1, 1, 1, 0.19), 2.0, true)
		draw_circle(joy_base + (joy_pos - joy_base).limit_length(62), 24, Color(1, 1, 1, 0.7))
	else:
		_text(Vector2(x, H - 16), "Слева — ходьба (чуть сдвинь — красться). Свайп справа — поворот камеры", 11, Color(1, 1, 1, 0.47), HORIZONTAL_ALIGNMENT_LEFT, true)
	# кнопки
	var wid := me.weapon_id()
	var w := me.weapon()
	_btn(b_attack, Color(0.66, 0.19, 0.19, 0.7), "" if wid != "fists" else "fist", wid if wid != "fists" else "",
		str(me.count("ammo")) if w["kind"] == Items.Kind.GUN else "", "Толчок" if wid == "fists" else w["name"])
	var target := screen.view.target
	var tt := g.world.t_at(target) if target >= 0 else -1
	# кнопка действия видна только рядом с дверью
	if target >= 0 and (tt == GameWorld.DOOR or tt == GameWorld.DOOR_OPEN):
		_btn(b_interact, Color(0.16, 0.35, 0.53, 0.7), "door", "", "", "Открыть" if tt == GameWorld.DOOR else "Закрыть")
	_btn(b_run, Color(0.78, 0.6, 0.13, 0.82) if run_toggle else Color(0.19, 0.2, 0.22, 0.53), "run", "", "", "Бег" if run_toggle else "")
	_btn(b_inv, Color(0.19, 0.2, 0.22, 0.6), "bag", "", "", "")
	_btn(b_pause, Color(0.19, 0.2, 0.22, 0.6), "pause", "", "", "")
	_btn(b_gear, Color(0.19, 0.2, 0.22, 0.6), "gear", "", "", "")
	_btn(b_menu, Color(0.19, 0.2, 0.22, 0.6), "menu", "", "", "")
	_btn(b_chat, Color(0.19, 0.2, 0.22, 0.6), "chat", "", "", "")
	_draw_chat(x, 126.0 if not mds.is_empty() else 66.0)

## Чат слева сверху: закрыт — последние строки, гаснут через CHAT_LIFE; открыт — вся история на тёмной подложке
func _draw_chat(x: float, y: float) -> void:
	var W := get_viewport_rect().size.x
	var maxw := minf(W * 0.36, 540.0)
	var now := Time.get_ticks_msec()
	var lim := 12 if chat_open else CHAT_SHOW
	var rows: Array = []          # [строка, прозрачность, вид, последняя ли строка записи, сколько первых букв — белым]
	for i in range(chat_lines.size() - 1, -1, -1):
		var e: Array = chat_lines[i]
		var age := (now - int(e[1])) / 1000.0
		var a := 1.0 if chat_open else clampf((CHAT_LIFE - age) / 5.0, 0.0, 1.0)
		if a <= 0.0:
			break
		var wr := _wrap(e[0], 14, maxw)
		var kind := str(e[2]) if e.size() > 2 else "say"
		var wend := speech_len(e[0], kind)
		var starts := []                 # с какой буквы строки записи начинается каждый кусок (куски — через один пробел)
		var off := 0
		for piece in wr:
			starts.append(off)
			off += (piece as String).length() + 1
		for k in range(wr.size() - 1, -1, -1):
			rows.push_front([wr[k], a, kind, k == wr.size() - 1, clampi(wend - starts[k], 0, (wr[k] as String).length())])
		if rows.size() >= lim:
			break
	while rows.size() > lim:
		rows.pop_front()
	if chat_open:
		for c in chat_chips:
			_rr(c[0], 9, Color(0.30, 0.22, 0.38, 0.92))
			_text((c[0] as Rect2).get_center() + Vector2(0, 5), (c[1] as String).strip_edges(), 15, RP_COL.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
		y = 150.0
		lim = mini(lim, 11)
		while rows.size() > lim:
			rows.pop_front()
		_rr(Rect2(x - 6, y - 4, maxw + 12, maxf(rows.size(), 1) * 19 + 10), 8, Color(0.05, 0.06, 0.07, 0.75))
		if rows.is_empty():
			_text(Vector2(x, y + 15), "Сообщений пока нет", 14, Color(1, 1, 1, 0.5))
		_rr(chat_send, 10, Color(0.24, 0.42, 0.24))
		_text(chat_send.get_center() + Vector2(0, 6), "Отправить", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	for r in rows:
		var kind: String = r[2]
		var col := Color.WHITE if kind == "say" else RP_COL
		col.a = r[1]
		var s: String = r[0]
		# /try: «Удачно» зелёным, «Неудачно» красным — только у записи с видом try1/try0 от сервера
		var tail := ("Удачно" if kind == "try1" else "Неудачно") if kind.begins_with("try") and r[3] else ""
		if tail != "" and s.ends_with(tail):
			var head := s.left(s.length() - tail.length())
			_text(Vector2(x, y + 15), head, 14, col, HORIZONTAL_ALIGNMENT_LEFT, true)
			var tc := TRY_OK if kind == "try1" else TRY_BAD
			tc.a = r[1]
			_text(Vector2(x + _tw(head, 14), y + 15), tail, 14, tc, HORIZONTAL_ALIGNMENT_LEFT, true)
		elif r[4] > 0:
			# /todo: сказанное — белым, как речь, остальное — сиреневым (0.57)
			var said := s.left(r[4])
			_text(Vector2(x, y + 15), said, 14, Color(1, 1, 1, r[1]), HORIZONTAL_ALIGNMENT_LEFT, true)
			_text(Vector2(x + _tw(said, 14), y + 15), s.substr(r[4]), 14, col, HORIZONTAL_ALIGNMENT_LEFT, true)
		else:
			_text(Vector2(x, y + 15), s, 14, col, HORIZONTAL_ALIGNMENT_LEFT, true)
		y += 19

## /todo (0.57): сколько первых букв строки — сказанное вслух «…» (рисуется как речь). Строка чата —
## «„фраза“, — сказал…», облачко — «„фраза“, действие»; у остальных видов 0
static func speech_len(s: String, kind: String) -> int:
	if kind != "todo" or not s.begins_with("«"):
		return 0
	var i := s.find("», — сказал")       # строка чата
	if i < 0:
		i = s.find("», ")                # облачко
	return i + 1 if i > 0 else 0

## Облачка с речью над головами (с 0.53): над именем (у себя — над головой), до 3 строк, гаснут в конце
func _bubbles(g: GameState, me: GameState.Player) -> void:
	var now := Time.get_ticks_msec()
	for id in bubbles.keys():
		var b: Array = bubbles[id]
		var age := (now - int(b[1])) / 1000.0
		if bubble_hold:
			age = 1.0
		if age > b[2]:
			bubbles.erase(id)
			continue
		var p := g.player(int(id))
		if p == null or p.dead or not p.connected:
			continue
		var a := clampf((b[2] - age) / 0.6, 0.0, 1.0) * clampf(age / 0.15, 0.0, 1.0)
		var lines := _wrap(b[0], 13, BUBBLE_W)
		if lines.size() > 3:
			lines = lines.slice(0, 3)
			lines[2] = (lines[2] as String).left(maxi(0, (lines[2] as String).length() - 1)) + "…"
		var w := 0.0
		for l in lines:
			w = maxf(w, _tw(l, 13))
		var tip: Vector2 = screen.view.project(Vector3(p.rpos.x, 2.05, p.rpos.y)) + Vector2(0, -16 if p.id != me.id else 4)
		if p.ta_act != null:
			tip.y -= 34                  # над кольцом «Ем / Надеваю»
		var h := lines.size() * 17.0 + 10.0
		var r := Rect2(tip.x - w / 2 - 9, tip.y - 7 - h, w + 18, h)
		var rp: bool = b.size() > 3 and b[3] != "say"      # ролевые команды — сиреневое облачко (0.56)
		var bg := (Color(0.89, 0.83, 0.96) if rp else Color(0.96, 0.96, 0.94))
		bg.a = 0.92 * a
		_rr(r, 9, bg)
		draw_colored_polygon(PackedVector2Array([Vector2(tip.x - 6, r.end.y - 0.5), Vector2(tip.x + 6, r.end.y - 0.5), Vector2(tip.x, tip.y)]), bg)
		var y := r.position.y + 18
		var tc := Color(0.24, 0.12, 0.36, a) if rp else Color(0.08, 0.09, 0.1, a)
		var tail := ("Удачно" if b[3] == "try1" else "Неудачно") if rp and str(b[3]).begins_with("try") else ""
		var wend := speech_len(b[0], str(b[3])) if rp else 0     # /todo: фраза — цветом речи
		var off := 0
		for i in lines.size():
			var l: String = lines[i]
			var sw := clampi(wend - off, 0, l.length())
			off += l.length() + 1
			if tail != "" and i == lines.size() - 1 and l.ends_with(tail):
				# итог /try — зелёным или красным, как в чате
				var head := l.left(l.length() - tail.length())
				var x0 := tip.x - _tw(l, 13) / 2.0
				_text(Vector2(x0, y), head, 13, tc)
				_text(Vector2(x0 + _tw(head, 13), y), tail, 13, Color(0.10, 0.52, 0.16, a) if b[3] == "try1" else Color(0.75, 0.12, 0.10, a))
			elif sw > 0:
				var x1 := tip.x - _tw(l, 13) / 2.0
				var said := l.left(sw)
				_text(Vector2(x1, y), said, 13, Color(0.08, 0.09, 0.1, a))
				_text(Vector2(x1 + _tw(said, 13), y), l.substr(sw), 13, tc)
			else:
				_text(Vector2(tip.x, y), l, 13, tc, HORIZONTAL_ALIGNMENT_CENTER)
			y += 17

## Разбить строку по словам на куски не шире w
func _wrap(s: String, size: int, w: float) -> Array:
	var out: Array = []
	var cur := ""
	for word in s.split(" "):
		var t: String = word if cur == "" else cur + " " + word
		if _tw(t, size) <= w or cur == "":
			cur = t
		else:
			out.append(cur)
			cur = word
	if cur != "":
		out.append(cur)
	return out

func _btn(b: Array, col: Color, glyph: String, item: String, badge: String, label: String) -> void:
	var c: Vector2 = b[0]
	var r: float = b[1]
	draw_circle(c + Vector2(2, 3), r, Color(0, 0, 0, 0.25))
	draw_circle(c, r, col)
	draw_arc(c, r - 1, 0, TAU, 48, Color(1, 1, 1, 0.31), 1.5, true)
	if item != "":
		Icons.item(self, item, c, r * 1.35)
	elif glyph != "":
		Icons.glyph(self, glyph, c, r * (0.6 if glyph == "fist" else 0.55))
	if badge != "":
		var bw := _tw(badge, 11) + 10
		var br := Rect2(c.x + r * 0.4, c.y + r * 0.45, bw, 17)
		_rr(br, 8, Color(0.1, 0.12, 0.13))
		_text(Vector2(br.get_center().x, br.end.y - 4.5), badge, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if label != "":
		_text(Vector2(c.x, c.y - r - 6), label, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)

# ================== ПАНЕЛИ ==================
func _layout_panel() -> void:
	var vr := get_viewport_rect()
	var pw := minf(vr.size.x * 0.86, 720.0)
	var ph := vr.size.y * 0.86
	panel_rect = Rect2((vr.size.x - pw) / 2, (vr.size.y - ph) / 2, pw, ph)
	btn_close = Rect2(panel_rect.end.x - 48, panel_rect.position.y + 8, 40, 36)

func _col_rect(col: int, cols: int) -> Rect2:
	var top := panel_rect.position.y + 56
	var w := panel_rect.size.x * 0.55 if cols == 1 else panel_rect.size.x / 2
	var l := panel_rect.position.x + col * w
	return Rect2(l + 10, top, w - 20, panel_rect.end.y - 12 - top)

func _row_at(col: Rect2, scr: float, y: float, n: int) -> int:
	if y < col.position.y:
		return -1
	var i := int((y - col.position.y + scr) / ROW_H)
	return i if i >= 0 and i < n else -1

func _panel_bg(title: String) -> void:
	_layout_panel()
	draw_rect(get_viewport_rect(), Color(0, 0, 0, 0.6))
	_rr(panel_rect, 14, Color(0.125, 0.137, 0.15, 0.95))
	_text(panel_rect.position + Vector2(16, 32), title, 17)
	_rr(btn_close, 8, Color(0.31, 0.33, 0.35))
	_text(btn_close.get_center() + Vector2(0, 6), "✕", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

func _item_list(col: Rect2, items: Array, scr_i: int, highlight: String, empty: String) -> void:
	if items.is_empty():
		_text(col.position + Vector2(8, 24), empty, 14, Color(0.56, 0.56, 0.56))
	for i in items.size():
		var s: Dictionary = items[i]
		var top: float = col.position.y + i * ROW_H - scroll[scr_i]
		if top > col.end.y - ROW_H * 0.5 or top + ROW_H < col.position.y:
			continue
		var r := Rect2(col.position.x, top + 2, col.size.x, ROW_H - 4)
		_rr(r, 8, Color(0.24, 0.35, 0.47) if s["id"] == highlight else Color(0.18, 0.2, 0.21))
		Icons.item(self, s["id"], Vector2(col.position.x + 18, top + ROW_H / 2), 30)
		var nm: String = Items.def(s["id"])["name"] + (" ×%d" % s["n"] if s["n"] > 1 else "")
		_text(Vector2(col.position.x + 38, top + ROW_H / 2 + 5), nm, 14)

func _draw_inv(me: GameState.Player) -> void:
	_panel_bg("Вещи  —  вес %.1f / %d" % [me.weight(), int(me.max_weight())])
	var col := _col_rect(0, 1)
	scroll[0] = minf(scroll[0], maxf(0.0, me.inv.size() * ROW_H - col.size.y))
	_item_list(col, me.inv, 0, selected, "Пусто")
	var rx := col.end.x + 20
	var ry := col.position.y + 20
	var bw := panel_rect.end.x - rx - 16
	if selected == "" or me.count(selected) <= 0:
		_text(Vector2(rx, ry), "Выбери предмет", 13, Color(0.56, 0.56, 0.56))
		btn_a = Rect2()
		btn_b = Rect2()
		return
	var d := Items.def(selected)
	_text(Vector2(rx, ry), d["name"], 16)
	ry += 24
	var info := ""
	match d["kind"]:
		Items.Kind.FOOD, Items.Kind.DRINK: info = "Голод −%d  Жажда −%d" % [int(d["hunger"]), int(d["thirst"])]
		Items.Kind.MED: info = "+%d здоровья" % int(d["heal"])
		Items.Kind.MELEE: info = "Урон %d, дальность %.1f" % [int(d["dmg"]), d["range"]]
		Items.Kind.GUN: info = "Урон %d, громко! Нужны патроны" % int(d["dmg"])
		Items.Kind.AMMO: info = "Для пистолета"
		Items.Kind.WEAR: info = _wear_info(selected)
	_text(Vector2(rx, ry), info, 13, Color(0.69, 0.69, 0.69))
	ry += 18
	_text(Vector2(rx, ry), "Вес %.2f" % d["w"], 13, Color(0.69, 0.69, 0.69))
	ry += 26
	var use := ""
	match d["kind"]:
		Items.Kind.FOOD: use = "Съесть"
		Items.Kind.DRINK: use = "Выпить"
		Items.Kind.MED: use = "Применить"
		Items.Kind.MELEE, Items.Kind.GUN: use = "Убрать из рук" if me.eq == selected else "Взять в руки"
		Items.Kind.WEAR: use = "Надеть"
	if use != "":
		btn_a = Rect2(rx, ry, bw, 44)
		_rr(btn_a, 10, Color(0.24, 0.42, 0.24))
		_text(btn_a.get_center() + Vector2(0, 5), use, 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		ry += 54
	else:
		btn_a = Rect2()
	btn_b = Rect2(rx, ry, bw, 44)
	_rr(btn_b, 10, Color(0.42, 0.24, 0.24))
	_text(btn_b.get_center() + Vector2(0, 5), "Выбросить", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

## Кнопка редактора карты в паузе: офлайн и только у владельца (проверено по аккаунту при входе).
## Даже если её включить подменой файла — правки останутся в этом телефоне: сервер карту не принимает
func _editor_btn() -> String:
	if screen.mode != GameScreen.Mode.SOLO:
		return ""
	if screen.demo == "editor":
		return "Вернуться в редактор"
	if screen.demo == "" and AccountApi.admin_cached():
		return "Редактор карты"
	return ""

const AccountApi = preload("res://scripts/account.gd")

func _draw_pause() -> void:
	_panel_bg("Пауза" if screen.mode == GameScreen.Mode.SOLO else "Меню")
	var bw := minf(panel_rect.size.x * 0.6, 360.0)
	var cx := panel_rect.get_center().x
	var ed := _editor_btn()
	if ed == "" and screen.mode == GameScreen.Mode.CLIENT:
		ed = "Аккаунт"
	var sp := 56.0 if ed != "" else 66.0
	var bh := 44.0 if ed != "" else 50.0
	var y := panel_rect.position.y + (64 if ed != "" else 80)
	btn_a = Rect2(cx - bw / 2, y, bw, bh)
	btn_b = Rect2(cx - bw / 2, y + sp, bw, bh)
	_rr(btn_a, 10, Color(0.24, 0.42, 0.24))
	_rr(btn_b, 10, Color(0.42, 0.24, 0.24))
	_text(btn_a.get_center() + Vector2(0, 6), "Продолжить", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(btn_b.get_center() + Vector2(0, 6), "Отключиться" if screen.mode == GameScreen.Mode.CLIENT else ("Выйти без сохранения" if screen.demo == "editor" else "Сохранить и выйти"), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	btn_c = Rect2(cx - bw / 2, y + sp * 2, bw, bh)
	_rr(btn_c, 10, Color(0.26, 0.29, 0.34))
	_text(btn_c.get_center() + Vector2(0, 6), "Графика: низкая" if Profile.low_gfx else "Графика: высокая", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	btn_d = Rect2()
	if ed != "":
		btn_d = Rect2(cx - bw / 2, y + sp * 3, bw, bh)
		_rr(btn_d, 10, Color(0.42, 0.34, 0.14) if ed != "Аккаунт" else Color(0.3, 0.27, 0.36))
		_text(btn_d.get_center() + Vector2(0, 6), ed, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(cx, y + sp * (4 if ed != "" else 2) + (26 if ed != "" else 80)), "Umwelt RP · версия 0.%s" % Version.BUILD, 12, Color(0.56, 0.56, 0.56), HORIZONTAL_ALIGNMENT_CENTER)

# ---------- меню игрока (с 0.52) ----------
func _draw_menu() -> void:
	_panel_bg("Меню игрока")
	var bw := minf(panel_rect.size.x * 0.6, 360.0)
	var cx := panel_rect.get_center().x
	btn_a = Rect2(cx - bw / 2, panel_rect.position.y + 70, bw, 50)
	_rr(btn_a, 10, Color(0.24, 0.35, 0.47))
	_text(btn_a.get_center() + Vector2(0, 6), "Статистика", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_stats(_g: GameState, me: GameState.Player) -> void:
	_panel_bg("Статистика")
	var x := panel_rect.position.x + 28
	var vx := x + minf(panel_rect.size.x * 0.42, 280.0)
	var y := panel_rect.position.y + 78
	var rows := [
		["Уровень", "%d  (%d/%d)" % [me.level, me.exp, GameState.exp_need(me.level)]],
		["Лицензии", "нет"],
		["Статус VIP", "нет"],
		[],
		["Дата регистрации аккаунта", GameState.date_ru(me.reg)],
		["Статичный ID", str(me.id)],
		["Отыграно сегодня", "%s  (АФК: %s)" % [GameState.dur_ru(me.day_play), GameState.dur_ru(me.day_afk)]],
		["В этом часу", "%s из 20 мин для PayDay" % GameState.dur_ru(me.hour_play)],
	]
	for r in rows:
		if r.is_empty():
			y += 14
			continue
		_text(Vector2(x, y), r[0] + ":", 16, Color(0.7, 0.72, 0.76))
		_text(Vector2(vx, y), r[1], 16, Color.WHITE)
		y += 32
	btn_b = Rect2(x, panel_rect.end.y - 60, 140, 44)
	_rr(btn_b, 10, Color(0.31, 0.33, 0.35))
	_text(btn_b.get_center() + Vector2(0, 6), "‹ Назад", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)

# ---------- экран «Тело» ----------

func _draw_dead(g: GameState, me: GameState.Player, vr: Rect2) -> void:
	draw_rect(vr, Color(0.0, 0.0, 0.0, 0.62))
	var c := vr.get_center()
	_text(c + Vector2(0, -20), "Ты без сознания", 26, Color(0.9, 0.35, 0.35), HORIZONTAL_ALIGNMENT_CENTER, true)
	_text(c + Vector2(0, 18), "Очнёшься у больницы через %d с" % maxi(0, ceili(me.respawn_t)), 15, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, true)

# ---------- экран «Снаряжение» ----------
const GEAR_LAYOUT := {
	"head": Vector2(0.0, 0.0), "torso": Vector2(0.0, 0.34), "legs": Vector2(0.0, 0.68), "feet": Vector2(0.5, 1.0), "hand": Vector2(1.0, 0.34)}

static func _wear_info(id: String) -> String:
	var d := Items.def(id)
	return Items.SLOT_NAMES.get(d["slot"], "")

func _draw_gear(me: GameState.Player) -> void:
	_panel_bg("Одежда  —  вес %.1f / %d" % [me.weight(), int(me.max_weight())])
	var top := panel_rect.position.y + 56
	var bottom := panel_rect.end.y - 14
	var dollw := minf(panel_rect.size.x * 0.5, 360.0)
	var doll := Rect2(panel_rect.position.x + 16, top, dollw, bottom - top)
	# силуэт
	var cx := doll.get_center().x
	var sc := doll.size.y / 520.0
	var hy := doll.get_center().y - 175.0 * sc
	var sil := Color(0.27, 0.29, 0.31)
	draw_circle(Vector2(cx, hy + 16 * sc), 26 * sc, sil)
	_rr(Rect2(cx - 40 * sc, hy + 46 * sc, 80 * sc, 120 * sc), 18 * sc, sil)
	_rr(Rect2(cx - 62 * sc, hy + 52 * sc, 20 * sc, 110 * sc), 10 * sc, sil)
	_rr(Rect2(cx + 42 * sc, hy + 52 * sc, 20 * sc, 110 * sc), 10 * sc, sil)
	_rr(Rect2(cx - 36 * sc, hy + 170 * sc, 32 * sc, 140 * sc), 12 * sc, sil)
	_rr(Rect2(cx + 4 * sc, hy + 170 * sc, 32 * sc, 140 * sc), 12 * sc, sil)
	# слоты вокруг
	gear_rects.clear()
	var ss := clampf(doll.size.y * 0.15, 50.0, 68.0)
	for sl in GEAR_LAYOUT:
		var f: Vector2 = GEAR_LAYOUT[sl]
		var pos := Vector2(doll.position.x + f.x * (doll.size.x - ss), doll.position.y + f.y * (doll.size.y - ss - 20))
		var r := Rect2(pos, Vector2(ss, ss))
		var id: String = me.eq if sl == "hand" else me.wear.get(sl, "")
		_rr(r, 10, Color(0.24, 0.35, 0.47) if sl == gear_slot else Color(0.16, 0.18, 0.19, 0.95))
		draw_rect(r.grow(-1), Color(1, 1, 1, 0.18), false, 1.5)
		if id != "":
			Icons.item(self, id, r.get_center(), ss * 0.8)
		else:
			_text(r.get_center() + Vector2(0, 4), "пусто", 10, Color(0.45, 0.45, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(r.get_center().x, r.end.y + 13), "В руках" if sl == "hand" else Items.SLOT_NAMES[sl], 11, Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		gear_rects.append([r, sl])
	# справа: выбранный слот и что можно надеть
	var rx := doll.end.x + 20
	var rw := panel_rect.end.x - rx - 16
	var ry := top + 4
	btn_a = Rect2()
	if gear_slot != "":
		var gid: String = me.eq if gear_slot == "hand" else me.wear.get(gear_slot, "")
		if gid != "":
			_text(Vector2(rx, ry + 12), Items.def(gid)["name"], 16)
			ry += 32
			if gear_slot != "hand":
				_text(Vector2(rx, ry), _wear_info(gid), 12, Color(0.69, 0.69, 0.69))
				ry += 22
			btn_a = Rect2(rx, ry, minf(rw, 220.0), 42)
			_rr(btn_a, 10, Color(0.42, 0.24, 0.24))
			_text(btn_a.get_center() + Vector2(0, 5), "Убрать из рук" if gear_slot == "hand" else "Снять", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			ry += 56
	gear_rows.clear()
	var can := []
	for st in me.inv:
		var d := Items.def(st["id"])
		if d["kind"] == Items.Kind.WEAR and (gear_slot == "" or gear_slot == d["slot"]) and Items.fits(st["id"], me.gender()):
			can.append(st["id"])
	_text(Vector2(rx, ry + 10), "Можно надеть (нажми):" if can.size() > 0 else "Нечего надеть", 12, Color(0.75, 0.75, 0.75))
	ry += 22
	for id in can:
		if ry + ROW_H > bottom:
			break
		var rr := Rect2(rx, ry, rw, ROW_H - 4)
		_rr(rr, 8, Color(0.18, 0.2, 0.21))
		Icons.item(self, id, Vector2(rx + 18, ry + (ROW_H - 4) / 2), 30)
		_text(Vector2(rx + 40, ry + ROW_H / 2 + 1), Items.def(id)["name"], 14)
		_text(Vector2(rr.end.x - 8, ry + ROW_H / 2 + 1), Items.SLOT_NAMES[Items.def(id)["slot"]], 11, Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
		gear_rows.append([rr, id])
		ry += ROW_H
