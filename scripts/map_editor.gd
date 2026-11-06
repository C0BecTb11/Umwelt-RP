extends Node
## Редактор карты — только для владельца, только офлайн, на копии карты в телефоне.
## Готовый черновик кнопкой «Отправить» уходит в Supabase (таблица map_drafts: принимает только админов),
## оттуда Claude берёт его, проверяет и выпускает новой версией (maps/city.json). Игроки карту не меняют:
## сервер берёт её только из своего файла. Без class_name — подключается через load()/preload.
## Логика правок (paint, rect, place_prop…) отделена от касаний — её проверяют автотесты.

signal finished(action: String, focus: Vector2)   # "exit" — в лаунчер, "walk" — пройтись по черновику

const DRAFT := "user://map_draft.json"
const Props = preload("res://scripts/props.gd")
const AccountApi = preload("res://scripts/account.gd")
const W = preload("res://scripts/world.gd")

enum Tool { HAND, BRUSH, RECT, FRAME, PROP, SELECT, SPAWN, ROAD }
const TOOL_NAMES := ["Рука", "Кисть", "Прямоуг.", "Рамка", "Объект", "Выбор", "Спавн", "Дорога"]
const ROAD_KINDS := [["street", "Улица"], ["highway", "Трасса"]]
const CAR_H := 100     # «машина вдоль», занимает 2 клетки
const CAR_V2 := 101    # «машина поперёк»
## Палитра клеток: [номер, название, цвет кнопки]
const TILES := [
	[W.GRASS, "Трава", Color(0.3, 0.5, 0.26)], [W.ROAD, "Асфальт", Color(0.22, 0.22, 0.24)],
	[W.SIDEWALK, "Тротуар", Color(0.6, 0.6, 0.58)], [W.WOOD, "Пол: доски", Color(0.6, 0.42, 0.26)],
	[W.TILEFLOOR, "Пол: плитка", Color(0.75, 0.75, 0.72)], [W.WALL, "Стена", Color(0.85, 0.8, 0.7)],
	[W.DOOR, "Дверь", Color(0.55, 0.32, 0.18)], [W.WINDOW, "Окно", Color(0.5, 0.7, 0.85)],
	[W.TREE, "Дерево", Color(0.2, 0.42, 0.18)], [W.FRIDGE, "Холодильник", Color(0.9, 0.9, 0.9)],
	[W.COUNTER, "Стойка", Color(0.55, 0.45, 0.35)], [W.WARDROBE, "Шкаф", Color(0.45, 0.32, 0.2)],
	[W.SHELF, "Полка", Color(0.5, 0.4, 0.3)], [W.MEDCAB, "Аптечка", Color(0.85, 0.85, 0.8)],
	[W.LOCKER, "Шкафчик", Color(0.45, 0.5, 0.55)], [W.STORESHELF, "Стеллаж", Color(0.6, 0.55, 0.45)],
	[CAR_H, "Машина ↔", Color(0.55, 0.2, 0.18)], [CAR_V2, "Машина ↕", Color(0.2, 0.3, 0.5)],
]

var g: GameState
var w: GameWorld
var view: WorldView
var me: GameState.Player
var tool := Tool.HAND
var tile := W.WALL
var prop_id := "bench"
var prop_rot := 0.0
var sel := -1                  # выбранный объект (номер в w.props)
var focus := Vector2(50, 50)   # куда смотрит камера
var zoom := 24.0
var undo_stack: Array = []
var act = null                 # текущая правка: {"t": {клетка: было}, "props": копия или null, "spawn": было или null, "lines": копия или null}
var road_kind := "street"      # вид новой дороги-линии
var road_line := -1            # номер дороги в w.lines, которую сейчас рисуют (-1 — следующее касание начнёт новую)
var road_del := false          # следующее касание удаляет дорогу под пальцем
var road_marks: Array = []     # метки точек рисуемой дороги
var unsaved := false
var reset_t := 0.0
var size_t := 0.0              # окно подтверждения «Размер»
var size_btn: Button
var autosave_t := 30.0
var touches := {}              # палец → позиция
var one_id := -1
var one_start := Vector2.ZERO
var one_moved := false
var last_cell := Vector2i(-1, -1)
var rect_a := Vector2i(-1, -1)
var rect_b := Vector2i(-1, -1)
var pinch_d := 0.0
var pinch_mid := Vector2.ZERO
var headless := false          # автотесты: без 3D и интерфейса
var use_draft := true          # автотесты: начинать с карты из игры, а не с черновика

# интерфейс
var ui: Control
var status: Label
var top: HBoxContainer
var bottom: VBoxContainer
var tools_box: HBoxContainer
var palette: HBoxContainer
var tool_btns: Array = []
var roofs_btn: Button
var send_btn: Button
var marker_rect: MeshInstance3D
var marker_sel: MeshInstance3D
var marker_spawn: MeshInstance3D

# ================== ЗАПУСК ==================
func _ready() -> void:
	g = GameState.new(1)
	g.real_clock = false
	g.time = 13 * 60.0
	var d := load_draft() if use_draft else {}
	var err := g.world.load_map(d) if not d.is_empty() else "нет черновика"
	if err != "":
		g.load_official_map()
	w = g.world
	g.spawn = w.spawn
	if focus == Vector2(50, 50):
		focus = w.spawn
	me = GameState.Player.new(0)
	me.dead = true             # стены не прорезаются, сам «игрок» не рисуется
	me.connected = false
	if headless:
		return
	view = WorldView.new()
	add_child(view)
	view.setup(w)
	view.cam_pitch = 62.0
	view.hide_roofs = true
	view.env.fog_enabled = false
	_make_markers()
	_make_ui()
	_set_tool(Tool.HAND)
	_say("Редактор карты. Два пальца — двигать и приближать. Внизу — инструменты")

## Черновик из телефона (пустой словарь — черновика нет)
static func load_draft() -> Dictionary:
	if not FileAccess.file_exists(DRAFT):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(DRAFT))
	return d if d is Dictionary else {}

func save_draft() -> void:
	var f := FileAccess.open(DRAFT, FileAccess.WRITE)
	if f == null:
		_say("Не удалось сохранить черновик")
		return
	f.store_string(GameWorld.map_text(w.map_data()))
	f.close()
	unsaved = false

# ================== ПРАВКИ (их же проверяют автотесты) ==================
func begin() -> void:
	act = {"t": {}, "props": null, "spawn": null, "lines": null}

func _remember_props() -> void:
	if act != null and act["props"] == null:
		act["props"] = w.props.duplicate(true)

func _remember_lines() -> void:
	if act != null and act["lines"] == null:
		act["lines"] = w.lines.duplicate(true)

## Закончить правку; true — что-то поменялось (правка легла в «Отменить»)
func end() -> bool:
	if act == null:
		return false
	var changed: bool = act["t"].size() > 0 or act["props"] != null or act["spawn"] != null or act["lines"] != null
	if changed:
		undo_stack.append(act)
		if undo_stack.size() > 60:
			undo_stack.pop_front()
		unsaved = true
		if act["t"].size() > 0:
			w.compute_buildings()
			if view != null:
				view.rebuild_static()
		if act["props"] != null:
			w.index_props()
			if view != null:
				view.wm.refresh_lamps()
		if act["lines"] != null:
			w.index_lines()
	act = null
	return changed

func _set_cell(x: int, y: int, v: int) -> void:
	if not w.inside(x, y):
		return
	var i := w.idx(x, y)
	var old := w.t_at(i)
	if old == v:
		return
	# машина занимает 2 клетки: стираем одну половину — убираем и вторую
	if W.is_car(old):
		var other := -1
		if old == W.CAR:
			other = i + 1
		elif old == W.CAR_V:
			other = i + w.w
		elif x > 0 and w.t(x - 1, y) == W.CAR:
			other = i - 1
		elif y > 0 and w.t(x, y - 1) == W.CAR_V:
			other = i - w.w
		if other >= 0 and other < w.tiles.size() and W.is_car(w.t_at(other)):
			_raw(other, W.ROAD)
	_raw(i, v)

func _raw(i: int, v: int) -> void:
	if not act["t"].has(i):
		act["t"][i] = w.t_at(i)
	w.tiles[i] = v
	w.vis_dirty[i] = true

## Кисть: одна клетка (машина — две)
func paint(c: Vector2i, v: int) -> void:
	if not w.inside(c.x, c.y):
		return
	if v == CAR_H:
		if c.x + 1 < w.w:
			_set_cell(c.x, c.y, W.ROAD)
			_set_cell(c.x + 1, c.y, W.ROAD)
			_raw(w.idx(c.x, c.y), W.CAR)
			_raw(w.idx(c.x + 1, c.y), W.CAR_TAIL)
	elif v == CAR_V2:
		if c.y + 1 < w.h:
			_set_cell(c.x, c.y, W.ROAD)
			_set_cell(c.x, c.y + 1, W.ROAD)
			_raw(w.idx(c.x, c.y), W.CAR_V)
			_raw(w.idx(c.x, c.y + 1), W.CAR_TAIL)
	else:
		_set_cell(c.x, c.y, v)

## Прямоугольник (заливка) или рамка (только края — так быстро ставятся стены дома)
func rect(a: Vector2i, b: Vector2i, v: int, outline: bool) -> void:
	if v == CAR_H or v == CAR_V2:
		paint(a, v)
		return
	var x0 := clampi(mini(a.x, b.x), 0, w.w - 1)
	var x1 := clampi(maxi(a.x, b.x), 0, w.w - 1)
	var y0 := clampi(mini(a.y, b.y), 0, w.h - 1)
	var y1 := clampi(maxi(a.y, b.y), 0, w.h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not outline or x == x0 or x == x1 or y == y0 or y == y1:
				_set_cell(x, y, v)

func place_prop(at: Vector2, id: String, rot: float) -> int:
	if not Props.DEFS.has(id) or at.x < 0.0 or at.y < 0.0 or at.x >= w.w or at.y >= w.h:
		return -1
	_remember_props()
	w.props.append([id, snappedf(at.x, 0.25), snappedf(at.y, 0.25), fposmod(rot, 360.0)])
	_mark(w.props.size() - 1)
	return w.props.size() - 1

## Ближайший объект к точке (не дальше 0.8 клетки), -1 — нет
func prop_at(at: Vector2) -> int:
	var best := -1
	var bd := 0.8
	for i in w.props.size():
		var e: Array = w.props[i]
		var d := at.distance_to(Vector2(e[1], e[2]))
		if d < bd:
			bd = d
			best = i
	return best

func move_prop(i: int, to: Vector2) -> void:
	if i < 0 or i >= w.props.size():
		return
	_remember_props()
	_mark(i)
	w.props[i][1] = clampf(snappedf(to.x, 0.25), 0.0, w.w - 0.01)
	w.props[i][2] = clampf(snappedf(to.y, 0.25), 0.0, w.h - 0.01)
	_mark(i)

func rotate_prop(i: int, by: float) -> void:
	if i < 0 or i >= w.props.size():
		return
	_remember_props()
	w.props[i][3] = fposmod(float(w.props[i][3]) + by, 360.0)
	_mark(i)

func delete_prop(i: int) -> void:
	if i < 0 or i >= w.props.size():
		return
	_remember_props()
	_mark(i)
	w.props.remove_at(i)

# ---------- дороги-линии ----------
## Добавить точку к рисуемой дороге (или начать новую). Номер дороги или -1
func road_point(at: Vector2) -> int:
	if at.x < 0.0 or at.y < 0.0 or at.x > w.w or at.y > w.h:
		return -1
	_remember_lines()
	if road_line >= 0 and road_line < w.lines.size():
		var e: Array = w.lines[road_line]
		if (e.size() - 1) / 2 >= GameWorld.MAX_LINE_PTS:
			return -1
		_mark_line(e)
		e.append(snappedf(at.x, 0.5))
		e.append(snappedf(at.y, 0.5))
	else:
		if w.lines.size() >= GameWorld.MAX_LINES:
			return -1
		w.lines.append([road_kind, snappedf(at.x, 0.5), snappedf(at.y, 0.5)])
		road_line = w.lines.size() - 1
	_mark_line(w.lines[road_line])
	return road_line

## Ближайшая дорога к точке (в пределах её ширины), -1 — нет
func road_at(at: Vector2) -> int:
	var best := -1
	var bd := INF
	for i in w.lines.size():
		var path := GameWorld.line_path(w.lines[i])
		var hw: float = GameWorld.LINE_OUTER_HW[w.lines[i][0]]
		for k in path.size() - 1:
			var d := Geometry2D.get_closest_point_to_segment(at, path[k], path[k + 1]).distance_to(at)
			if d < hw and d < bd:
				bd = d
				best = i
	return best

func delete_road(i: int) -> void:
	if i < 0 or i >= w.lines.size():
		return
	_remember_lines()
	_mark_line(w.lines[i])
	w.lines.remove_at(i)
	if road_line == i:
		road_line = -1
	elif road_line > i:
		road_line -= 1

func set_road_kind(k: String) -> void:
	road_kind = k
	if road_line >= 0 and road_line < w.lines.size() and w.lines[road_line][0] != k:
		begin()
		_remember_lines()
		w.lines[road_line][0] = k
		_mark_line(w.lines[road_line])
		end()

## Куски графики вдоль дороги (и соседние: у соседей меняются перекрёстки и камешки на траве)
func _mark_line(e: Array) -> void:
	if view == null:
		return
	var pts := GameWorld.line_path(e)
	if pts.is_empty() and e.size() >= 3:
		pts.append(Vector2(e[1], e[2]))
	for p in pts:
		for o in [Vector2.ZERO, Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)]:
			view.mark_point(p.x + o.x, p.y + o.y)

func set_spawn(at: Vector2) -> bool:
	if w.circle_blocked(at.x, at.y, GameState.PLAYER_R):
		return false
	if act["spawn"] == null:
		act["spawn"] = w.spawn
	w.spawn = at
	return true

func undo() -> bool:
	if undo_stack.is_empty():
		return false
	var a: Dictionary = undo_stack.pop_back()
	for i in a["t"]:
		w.tiles[i] = a["t"][i]
		w.vis_dirty[i] = true
	if a["props"] != null:
		for e in w.props:
			_mark_e(e)
		w.props = a["props"]
		for e in w.props:
			_mark_e(e)
		w.index_props()
	if a["spawn"] != null:
		w.spawn = a["spawn"]
	if a.get("lines") != null:
		for e in w.lines:
			_mark_line(e)
		w.lines = a["lines"]
		for e in w.lines:
			_mark_line(e)
		w.index_lines()
		if road_line >= w.lines.size():
			road_line = -1
	if a["t"].size() > 0:
		w.compute_buildings()
		if view != null:
			view.rebuild_static()
	if view != null:
		view.wm.refresh_lamps()
	sel = -1
	unsaved = true
	return true

func _mark(i: int) -> void:
	_mark_e(w.props[i])

func _mark_e(e: Array) -> void:
	if view != null:
		view.mark_point(e[1], e[2])

## Увеличить карту до nw×nh (BF-053). Нынешний город остаётся в левом верхнем углу — координаты, двери, объекты
## и точка появления не сдвигаются (сохранения игроков остаются верными); новое место — трава. Только больше:
## уменьшение срезало бы построенное. Отмена до этого шага больше не действует. "" — получилось, иначе причина
func resize_map(nw: int, nh: int) -> String:
	if nw < w.w or nh < w.h:
		return "Уменьшать карту нельзя — пропадёт построенное"
	if nw > GameWorld.MAX_SIDE or nh > GameWorld.MAX_SIDE:
		return "Больше %d×%d нельзя" % [GameWorld.MAX_SIDE, GameWorld.MAX_SIDE]
	if nw == w.w and nh == w.h:
		return "Карта уже такого размера"
	var md := w.map_data()
	var rows: Array = md["rows"]
	var out := []
	for y in nh:
		out.append((str(rows[y]) + ".".repeat(nw - w.w)) if y < rows.size() else ".".repeat(nw))
	md["w"] = nw
	md["h"] = nh
	md["rows"] = out
	var err := w.load_map(md)
	if err != "":
		return err
	undo_stack.clear()
	sel = -1
	_remake_view()
	unsaved = true
	return ""

func _remake_view() -> void:
	if view == null:
		return
	view.queue_free()
	view = WorldView.new()
	add_child(view)
	move_child(view, 0)
	view.setup(w)
	view.cam_pitch = 62.0
	view.hide_roofs = roofs_btn == null or not roofs_btn.button_pressed
	view.env.fog_enabled = false
	_make_markers()

## Вернуть карту из игры (черновик пропадает)
func reset_to_official() -> void:
	g.load_official_map()
	undo_stack.clear()
	sel = -1
	_remake_view()
	unsaved = true

# ================== КАСАНИЯ ==================
func _in_ui(p: Vector2) -> bool:
	if ui == null:
		return false
	for c in [top, bottom]:
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false

func _cell(p: Vector2) -> Vector2i:
	var gp := view.ground_point(p)
	return Vector2i(floori(gp.x), floori(gp.y))

func _unhandled_input(e: InputEvent) -> void:
	if view == null:
		return
	if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		zoom = clampf(zoom * (0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 8.0, 70.0)
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if _in_ui(e.position):
				return
			touches[e.index] = e.position
			if touches.size() == 1:
				_one_down(e.index, e.position)
			elif touches.size() == 2:
				_cancel_one()
				_pinch_reset()
		else:
			if not touches.has(e.index):
				return
			touches.erase(e.index)
			if e.index == one_id:
				_one_up(e.position)
			elif touches.size() == 1:
				_pinch_reset()
	elif e is InputEventScreenDrag:
		if not touches.has(e.index):
			return
		touches[e.index] = e.position
		if touches.size() >= 2:
			_pinch_move()
		elif e.index == one_id:
			_one_move(e.position)

func _pinch_reset() -> void:
	var ps: Array = touches.values()
	if ps.size() >= 2:
		pinch_d = (ps[0] as Vector2).distance_to(ps[1])
		pinch_mid = ((ps[0] as Vector2) + ps[1]) * 0.5

func _pinch_move() -> void:
	var ps: Array = touches.values()
	var d := (ps[0] as Vector2).distance_to(ps[1])
	var mid: Vector2 = ((ps[0] as Vector2) + ps[1]) * 0.5
	focus += view.ground_point(pinch_mid) - view.ground_point(mid)
	if pinch_d > 10.0 and d > 10.0:
		zoom = clampf(zoom * pinch_d / d, 8.0, 70.0)
	pinch_d = d
	pinch_mid = mid
	_clamp_focus()

func _clamp_focus() -> void:
	focus = Vector2(clampf(focus.x, 0.0, w.w), clampf(focus.y, 0.0, w.h))

func _one_down(id: int, p: Vector2) -> void:
	one_id = id
	one_start = p
	_prev_p = p
	one_moved = false
	var c := _cell(p)
	match tool:
		Tool.BRUSH:
			begin()
			paint(c, tile)
			last_cell = c
		Tool.RECT, Tool.FRAME:
			rect_a = c
			rect_b = c
		Tool.SELECT:
			var i := prop_at(view.ground_point(p))
			if i >= 0:
				sel = i
				begin()
			else:
				sel = -1
	_refresh_palette_if_select()

func _one_move(p: Vector2) -> void:
	if p.distance_to(one_start) > 12.0:
		one_moved = true
	var c := _cell(p)
	match tool:
		Tool.HAND, Tool.PROP, Tool.SPAWN, Tool.ROAD:
			if one_moved:
				focus += view.ground_point(_prev_p) - view.ground_point(p)
				_clamp_focus()
		Tool.BRUSH:
			if c != last_cell and act != null:
				# линия между клетками, чтобы быстрый палец не оставлял дыр
				var n := maxi(absi(c.x - last_cell.x), absi(c.y - last_cell.y))
				for k in range(1, n + 1):
					paint(Vector2i(roundi(lerpf(last_cell.x, c.x, float(k) / n)), roundi(lerpf(last_cell.y, c.y, float(k) / n))), tile)
				last_cell = c
		Tool.RECT, Tool.FRAME:
			rect_b = c
		Tool.SELECT:
			if sel >= 0 and act != null and one_moved:
				move_prop(sel, view.ground_point(p))
			elif sel < 0 and one_moved:
				focus += view.ground_point(_prev_p) - view.ground_point(p)
				_clamp_focus()
	_prev_p = p

var _prev_p := Vector2.ZERO

func _one_up(p: Vector2) -> void:
	one_id = -1
	match tool:
		Tool.BRUSH:
			end()
		Tool.RECT, Tool.FRAME:
			if rect_a.x >= 0:
				begin()
				rect(rect_a, rect_b, tile, tool == Tool.FRAME)
				end()
			rect_a = Vector2i(-1, -1)
		Tool.PROP:
			if not one_moved:
				begin()
				var i := place_prop(view.ground_point(p), prop_id, prop_rot)
				end()
				if i >= 0:
					_say("Поставлено: %s. «Выбор» — сдвинуть или повернуть" % Props.DEFS[prop_id]["name"])
		Tool.SELECT:
			end()
		Tool.ROAD:
			if not one_moved:
				var gp := view.ground_point(p)
				begin()
				if road_del:
					var ri := road_at(gp)
					delete_road(ri)
					road_del = false
					_say("Дорога удалена" if ri >= 0 else "Здесь нет дороги")
				elif road_point(gp) >= 0:
					var np: int = (w.lines[road_line].size() - 1) / 2
					_say("Точек: %d. Касайся дальше — дорога продолжится; «Новая дорога» — закончить" % np if np > 1 else "Начало дороги. Коснись следующей точки")
				else:
					_say("Дальше нельзя: край карты или в дороге уже %d точек" % GameWorld.MAX_LINE_PTS)
				end()
				_update_road_marks()
		Tool.SPAWN:
			if not one_moved:
				begin()
				if set_spawn(view.ground_point(p)):
					_say("Точка появления перенесена")
				else:
					_say("Здесь стена или объект — точку появления сюда нельзя")
				end()
	_refresh_palette_if_select()

## Второй палец — значит, это жест камеры: начатую кистью правку отменяем
func _cancel_one() -> void:
	if one_id < 0:
		return
	one_id = -1
	rect_a = Vector2i(-1, -1)
	if act != null and end():
		undo()

func _process(dt: float) -> void:
	if view == null:
		return
	reset_t = maxf(0.0, reset_t - dt)
	size_t = maxf(0.0, size_t - dt)
	autosave_t -= dt
	if autosave_t <= 0.0:
		autosave_t = 30.0
		if unsaved:
			save_draft()
	me.rpos = focus
	me.pos = focus
	me.face = Vector2.ZERO
	view.cam_d = zoom
	view.stream_r = clampi(ceili(zoom * 1.2 / 10.0) + 1, 4, 10)   # отдалился — держим построенным больше города
	view.cam_x = focus.x
	view.cam_z = focus.y
	view.update(dt, g, me, -1)
	_update_markers()

# ================== МЕТКИ В 3D ==================
func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	return m

func _make_markers() -> void:
	marker_rect = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 0.1, 1)
	marker_rect.mesh = bm
	marker_rect.material_override = _mat(Color(1.0, 0.85, 0.2, 0.45))
	marker_rect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(marker_rect)
	marker_sel = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.6
	cm.height = 0.06
	marker_sel.mesh = cm
	marker_sel.material_override = _mat(Color(0.2, 0.9, 1.0, 0.5))
	marker_sel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(marker_sel)
	marker_spawn = MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.25
	sm.bottom_radius = 0.25
	sm.height = 3.0
	marker_spawn.mesh = sm
	marker_spawn.material_override = _mat(Color(0.3, 1.0, 0.4, 0.55))
	marker_spawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(marker_spawn)

## Метки точек рисуемой дороги
func _update_road_marks() -> void:
	if view == null:
		return
	var pts := []
	if road_line >= 0 and road_line < w.lines.size():
		var e: Array = w.lines[road_line]
		for k in range(1, e.size() - 1, 2):
			pts.append(Vector3(e[k], 0.3, e[k + 1]))
	while road_marks.size() < pts.size():
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 0.1
		mi.mesh = cm
		mi.material_override = _mat(Color(1.0, 0.5, 0.1, 0.75))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.add_child(mi)
		road_marks.append(mi)
	for i in road_marks.size():
		road_marks[i].visible = i < pts.size()
		if i < pts.size():
			road_marks[i].position = pts[i]

func _update_markers() -> void:
	marker_rect.visible = rect_a.x >= 0
	if marker_rect.visible:
		var x0 := mini(rect_a.x, rect_b.x)
		var y0 := mini(rect_a.y, rect_b.y)
		var sx := absi(rect_a.x - rect_b.x) + 1
		var sy := absi(rect_a.y - rect_b.y) + 1
		marker_rect.position = Vector3(x0 + sx * 0.5, 0.2, y0 + sy * 0.5)
		marker_rect.scale = Vector3(sx, 1, sy)
	marker_sel.visible = sel >= 0 and sel < w.props.size()
	if marker_sel.visible:
		marker_sel.position = Vector3(w.props[sel][1], 0.18, w.props[sel][2])
	marker_spawn.position = Vector3(w.spawn.x, 1.5, w.spawn.y)

# ================== ИНТЕРФЕЙС ==================
func _say(t: String) -> void:
	if status != null:
		status.text = t

func _btn(t: String, cb: Callable, col: Color = Color(0.2, 0.22, 0.26)) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_size_override("font_size", 13)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.lightened(0.25) if st.begins_with("pressed") or st == "hover_pressed" else col
		if st == "pressed" or st == "hover_pressed":
			sb.border_color = Color(1.0, 0.85, 0.3)
			sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	return b

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	# верх: выход, отмена, вид; статус; сохранить, пройтись, отправить
	top = HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 6
	top.offset_right = -6
	top.offset_top = 4
	top.add_theme_constant_override("separation", 4)
	ui.add_child(top)
	top.add_child(_btn("Выйти", _on_exit, Color(0.42, 0.22, 0.22)))
	top.add_child(_btn("Отменить", _on_undo))
	top.add_child(_btn("Поворот", func(): view.cam_yaw = fposmod(view.cam_yaw + 90.0, 360.0)))
	roofs_btn = _btn("Крыши", func(): view.hide_roofs = not roofs_btn.button_pressed)
	roofs_btn.toggle_mode = true
	top.add_child(roofs_btn)
	top.add_child(_btn("Из игры", _on_reset))
	size_btn = _btn("%d×%d" % [w.w, w.h], _on_size)
	top.add_child(size_btn)
	status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	status.add_theme_constant_override("shadow_offset_x", 1)
	status.add_theme_constant_override("shadow_offset_y", 1)
	status.custom_minimum_size = Vector2(120, 0)
	status.max_lines_visible = 3     # длинная подсказка не раздувает верхнюю строку кнопок
	top.add_child(status)
	top.add_child(_btn("Сохранить", _on_save, Color(0.2, 0.36, 0.24)))
	top.add_child(_btn("Пройтись", _on_walk, Color(0.2, 0.3, 0.42)))
	send_btn = _btn("Отправить", _on_send, Color(0.42, 0.34, 0.14))
	top.add_child(send_btn)
	# низ: инструменты и палитра
	bottom = VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 6
	bottom.offset_right = -6
	bottom.offset_bottom = -4
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 4)
	ui.add_child(bottom)
	tools_box = HBoxContainer.new()
	tools_box.add_theme_constant_override("separation", 4)
	bottom.add_child(tools_box)
	var grp := ButtonGroup.new()
	for k in TOOL_NAMES.size():
		var b := _btn(TOOL_NAMES[k], _set_tool.bind(k), Color(0.18, 0.2, 0.24))
		b.toggle_mode = true
		b.button_group = grp
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools_box.add_child(b)
		tool_btns.append(b)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 44)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	bottom.add_child(sc)
	palette = HBoxContainer.new()
	palette.add_theme_constant_override("separation", 4)
	sc.add_child(palette)

func _set_tool(k: int) -> void:
	tool = k as Tool
	for i in tool_btns.size():
		tool_btns[i].set_pressed_no_signal(i == k)
	if tool != Tool.SELECT:
		sel = -1
	rect_a = Vector2i(-1, -1)
	_fill_palette()
	match tool:
		Tool.HAND: _say("Рука: двигай карту одним пальцем")
		Tool.BRUSH: _say("Кисть: веди пальцем — клетки красятся")
		Tool.RECT: _say("Прямоугольник: проведи от угла до угла — заливка")
		Tool.FRAME: _say("Рамка: проведи от угла до угла — только края (стены дома)")
		Tool.PROP: _say("Объект: выбери внизу и коснись места на карте")
		Tool.SELECT: _say("Выбор: коснись объекта, тяни — сдвинуть; кнопки внизу — повернуть, удалить")
		Tool.SPAWN: _say("Спавн: коснись места, где игроки появляются и приходят в себя")
		Tool.ROAD: _say("Дорога: касайся карты — точки дороги, игра сгладит их в кривую. Вид — внизу")
	if tool != Tool.ROAD:
		road_line = -1
		road_del = false
	_update_road_marks()

func _fill_palette() -> void:
	if palette == null:
		return
	for ch in palette.get_children():
		ch.queue_free()
	match tool:
		Tool.BRUSH, Tool.RECT, Tool.FRAME:
			var grp := ButtonGroup.new()
			for t in TILES:
				var b := _btn(t[1], func(): tile = t[0], t[2].darkened(0.35))
				b.toggle_mode = true
				b.button_group = grp
				b.set_pressed_no_signal(t[0] == tile)
				palette.add_child(b)
		Tool.PROP:
			palette.add_child(_btn("Поворот: %d°" % roundi(prop_rot), _rot_new, Color(0.3, 0.26, 0.4)))
			var grp2 := ButtonGroup.new()
			for id in Props.ORDER:
				var b2 := _btn(Props.DEFS[id]["name"], func(): prop_id = id)
				b2.toggle_mode = true
				b2.button_group = grp2
				b2.set_pressed_no_signal(id == prop_id)
				palette.add_child(b2)
		Tool.ROAD:
			var grp3 := ButtonGroup.new()
			for rk in ROAD_KINDS:
				var b3 := _btn(rk[1], func(): set_road_kind(rk[0]); _fill_palette())
				b3.toggle_mode = true
				b3.button_group = grp3
				b3.set_pressed_no_signal(rk[0] == road_kind)
				palette.add_child(b3)
			palette.add_child(_btn("Новая дорога", func():
				road_line = -1
				road_del = false
				_update_road_marks()
				_say("Следующее касание начнёт новую дорогу"), Color(0.22, 0.34, 0.26)))
			palette.add_child(_btn("Удалить дорогу", func():
				road_line = -1
				road_del = true
				_update_road_marks()
				_say("Коснись дороги, которую удалить"), Color(0.42, 0.22, 0.22)))
		Tool.SELECT:
			if sel >= 0 and sel < w.props.size():
				var nm: String = Props.DEFS[w.props[sel][0]]["name"]
				var l := Label.new()
				l.text = "%s  %d°" % [nm, roundi(w.props[sel][3])]
				l.add_theme_font_size_override("font_size", 13)
				palette.add_child(l)
				palette.add_child(_btn("Повернуть 45°", func(): _sel_do("rot45"), Color(0.3, 0.26, 0.4)))
				palette.add_child(_btn("Повернуть 90°", func(): _sel_do("rot90"), Color(0.3, 0.26, 0.4)))
				palette.add_child(_btn("Копия рядом", func(): _sel_do("copy")))
				palette.add_child(_btn("Удалить", func(): _sel_do("del"), Color(0.42, 0.22, 0.22)))
			else:
				var l2 := Label.new()
				l2.text = "Коснись объекта на карте"
				palette.add_child(l2)

func _rot_new() -> void:
	prop_rot = fposmod(prop_rot + 45.0, 360.0)
	_fill_palette()

func _refresh_palette_if_select() -> void:
	if tool == Tool.SELECT:
		_fill_palette()

func _sel_do(what: String) -> void:
	if sel < 0 or sel >= w.props.size():
		return
	begin()
	match what:
		"rot45": rotate_prop(sel, 45.0)
		"rot90": rotate_prop(sel, 90.0)
		"copy":
			var e: Array = w.props[sel]
			sel = place_prop(Vector2(e[1] + 1.0, e[2]), e[0], e[3])
		"del":
			delete_prop(sel)
			sel = -1
	end()
	_fill_palette()

func _on_undo() -> void:
	_say("Отменено" if undo() else "Отменять нечего")
	_fill_palette()
	_update_road_marks()

func _on_save() -> void:
	save_draft()
	_say("Черновик сохранён в телефоне")

## Кнопка размера («100×100»): следующий шаг 200, 300, 400, 500 по большей стороне; двойное нажатие — подтверждение
func _on_size() -> void:
	var cur := maxi(w.w, w.h)
	var nxt := 0
	for s in [200, 300, 400, 500]:
		if s > cur and s <= GameWorld.MAX_SIDE:
			nxt = s
			break
	if nxt == 0:
		_say("Карта уже наибольшего размера: %d×%d" % [w.w, w.h])
		return
	if size_t <= 0.0:
		size_t = 3.0
		_say("Ещё раз — станет %d×%d. Новое место справа и снизу; не отменить" % [nxt, nxt])
		return
	size_t = 0.0
	var err := resize_map(nxt, nxt)
	if err != "":
		_say(err)
		return
	save_draft()
	size_btn.text = "%d×%d" % [w.w, w.h]
	_say("Карта %d×%d: новое место справа и снизу" % [w.w, w.h])

func _on_reset() -> void:
	if reset_t <= 0.0:
		reset_t = 3.0
		_say("Нажми «Из игры» ещё раз: черновик заменится картой, которая сейчас в игре")
		return
	reset_t = 0.0
	reset_to_official()
	save_draft()
	if size_btn != null:
		size_btn.text = "%d×%d" % [w.w, w.h]
	_say("Загружена карта из игры")

func _on_exit() -> void:
	save_draft()
	finished.emit("exit", focus)

func _on_walk() -> void:
	save_draft()
	finished.emit("walk", focus)

## Черновик — в Supabase. Принимает только аккаунт владельца (правило базы), остальным — отказ
func _on_send() -> void:
	save_draft()
	send_btn.disabled = true
	_say("Отправляю…")
	var acc: Node = AccountApi.new()
	add_child(acc)
	await get_tree().process_frame
	if not acc.has_session():
		_say("Сначала войди в аккаунт: «Играть» в лаунчере, потом вернись сюда")
	elif not await acc.refresh():
		_say(acc.last_error if acc.last_error != "" else "Не удалось войти в аккаунт")
	else:
		var note := "%s · объектов %d" % [Time.get_datetime_string_from_system(false, true), w.props.size()]
		var r: Array = await acc._req(HTTPClient.METHOD_POST, "/rest/v1/map_drafts", {"note": note, "data": w.map_data()},
			acc.access_token, PackedStringArray(["Prefer: return=minimal"]))
		if r[0] >= 200 and r[0] < 300:
			_say("Отправлено! Напиши Claude «выпусти карту» — он проверит и выпустит её")
		elif r[0] == 401 or r[0] == 403:
			_say("Отправлять карту может только владелец проекта")
		else:
			_say(AccountApi.explain(r[0], r[1]))
	acc.queue_free()
	send_btn.disabled = false

## Назад на телефоне
func back() -> void:
	_on_exit()
