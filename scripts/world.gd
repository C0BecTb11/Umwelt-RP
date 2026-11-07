class_name GameWorld
extends RefCounted

const GRASS := 0
const ROAD := 1
const SIDEWALK := 2
const WOOD := 3
const TILEFLOOR := 4
const WALL := 5
const DOOR := 6
const DOOR_OPEN := 7
const WINDOW := 8
const OLD_WINDOW_BROKEN := 9   # больше не используется: в старых сохранениях заменяется на WINDOW (migrate v3)
const TREE := 10
const OLD_DOOR_BROKEN := 11    # больше не используется: в старых сохранениях заменяется на DOOR_OPEN (migrate v3)
const FRIDGE := 12
const COUNTER := 13
const WARDROBE := 14
const SHELF := 15
const MEDCAB := 16
const LOCKER := 17
const STORESHELF := 18
const CAR := 19
const CAR_V := 20
const CAR_TAIL := 21
const WATER := 22              # вода (с 0.40): не пройти, кроме моста-линии над ней

const DX4 := [1, -1, 0, 0]
const DY4 := [0, 0, 1, -1]

static func is_furniture(t: int) -> bool: return t >= FRIDGE and t <= STORESHELF
static func is_door_like(t: int) -> bool: return t == DOOR or t == DOOR_OPEN
static func is_window_like(t: int) -> bool: return t == WINDOW
static func is_floor(t: int) -> bool: return t == WOOD or t == TILEFLOOR
static func is_car(t: int) -> bool: return t >= CAR and t <= CAR_TAIL
static func wall_like(t: int) -> bool: return t == WALL or is_window_like(t) or is_door_like(t)

var w := 100
var h := 100
var tiles := PackedByteArray()
var dirty_tiles := {}      # для сети
var vis_dirty := {}        # для перестройки 3D
var events: Array = []     # [клетка, было, стало] — для анимаций
var buildings: Array = []  # [x0, y0, x1, y1]
var building_of := PackedInt32Array()
var spawn := Vector2(50, 50)   # точка появления из файла карты
var props: Array = []      # объекты карты: [id, x, y, поворот в градусах] (каталог — scripts/props.gd)
var prop_cols := {}        # клетка → [Vector3(x, y, радиус)] — круги столкновений объектов
var lines: Array = []      # дороги-линии: [вид, x0, y0, x1, y1, …] — точки, игра сглаживает их в кривую (с 0.38)

func _init(width: int = 100, height: int = 100) -> void:
	w = width
	h = height
	tiles.resize(w * h)
	building_of.resize(w * h)

func idx(x: int, y: int) -> int: return y * w + x
func inside(x: int, y: int) -> bool: return x >= 0 and x < w and y >= 0 and y < h
func t(x: int, y: int) -> int: return tiles[y * w + x] if inside(x, y) else WALL
func t_at(i: int) -> int: return tiles[i]
func set_t(x: int, y: int, v: int) -> void:
	if inside(x, y):
		tiles[y * w + x] = v

func set_idx(i: int, v: int) -> void:
	events.append([i, tiles[i], v])
	tiles[i] = v
	dirty_tiles[i] = true
	vis_dirty[i] = true

func solid(x: int, y: int) -> bool:
	if not inside(x, y):
		return true
	var tt: int = tiles[y * w + x]
	if tt == WALL or tt == DOOR or tt == WINDOW or tt == TREE:
		return true
	return is_furniture(tt) or is_car(tt)

func opaque(x: int, y: int) -> bool:
	var tt := t(x, y)
	return tt == WALL or tt == DOOR or (is_furniture(tt) and tt != COUNTER)

func circle_blocked(cx: float, cy: float, r: float) -> bool:
	if not (is_finite(cx) and is_finite(cy)):
		return true          # нечисловая точка — «занято»: иначе все сравнения ниже ложны и пропускают (BF-028)
	var x0 := floori(cx - r)
	var x1 := floori(cx + r)
	var y0 := floori(cy - r)
	var y1 := floori(cy + r)
	if has_water and _water_blocks(cx, cy, r):
		return true
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not solid(x, y):
				var pc: Array = prop_cols.get(y * w + x, []) if inside(x, y) else []
				for c: Vector3 in pc:
					if Vector2(cx - c.x, cy - c.y).length_squared() < (r + c.z) * (r + c.z):
						return true
				continue
			var nx := clampf(cx, x, x + 1.0)
			var ny := clampf(cy, y, y + 1.0)
			var dx := cx - nx
			var dy := cy - ny
			if dx * dx + dy * dy < r * r:
				return true
	return false

## shot=true — для пули: окно тоже останавливает
func los(ax: float, ay: float, bx: float, by: float, shot: bool = false) -> bool:
	var dx := bx - ax
	var dy := by - ay
	var steps := int(maxf(absf(dx), absf(dy)) * 2.5) + 1
	var tx := floori(bx)
	var ty := floori(by)
	var sx := floori(ax)
	var sy := floori(ay)
	var lx := -99999
	var ly := -99999
	for s in range(1, steps):
		var f := float(s) / steps
		var x := floori(ax + dx * f)
		var y := floori(ay + dy * f)
		if x == lx and y == ly:
			continue
		lx = x
		ly = y
		if (x == tx and y == ty) or (x == sx and y == sy):
			continue
		if opaque(x, y):
			return false
		if shot and t(x, y) == WINDOW:
			return false
	return true

func _is_building_tile(tt: int) -> bool:
	return tt == WALL or is_floor(tt) or is_door_like(tt) or is_window_like(tt) or is_furniture(tt)

var buildings_runs := 0          # сколько раз пересчитаны дома (проверка: кисть по земле их не пересчитывает)

func compute_buildings() -> void:
	buildings_runs += 1
	# быстро: таблица «клетка дома» вместо вызова функции на каждую клетку, соседи — по номеру клетки
	# (на 500×500 в редакторе это считается после каждой правки стен; BF-055)
	var bt := PackedByteArray()
	bt.resize(256)
	for k in 256:
		bt[k] = 1 if _is_building_tile(k) else 0
	buildings.clear()
	building_of.fill(-1)
	var q := PackedInt32Array()
	q.resize(w * h)
	var n := w * h
	for start in n:
		if bt[tiles[start]] == 0 or building_of[start] >= 0:
			continue
		var id := buildings.size()
		var x0 := w
		var y0 := h
		var x1 := 0
		var y1 := 0
		var head := 0
		var tail := 1
		q[0] = start
		building_of[start] = id
		while head < tail:
			var i: int = q[head]
			head += 1
			var x := i % w
			var y := i / w
			if x < x0: x0 = x
			if x > x1: x1 = x
			if y < y0: y0 = y
			if y > y1: y1 = y
			if x + 1 < w and building_of[i + 1] < 0 and bt[tiles[i + 1]] == 1:
				building_of[i + 1] = id
				q[tail] = i + 1
				tail += 1
			if x > 0 and building_of[i - 1] < 0 and bt[tiles[i - 1]] == 1:
				building_of[i - 1] = id
				q[tail] = i - 1
				tail += 1
			if y + 1 < h and building_of[i + w] < 0 and bt[tiles[i + w]] == 1:
				building_of[i + w] = id
				q[tail] = i + w
				tail += 1
			if y > 0 and building_of[i - w] < 0 and bt[tiles[i - w]] == 1:
				building_of[i - w] = id
				q[tail] = i - w
				tail += 1
		buildings.append([x0, y0, x1, y1])

## Проём в горизонтальной стене (дверь открывается и проходится по оси Y)
func along_y(x: int, y: int) -> bool:
	var l := wall_like(t(x - 1, y))
	var r := wall_like(t(x + 1, y))
	if l and r:
		return true
	if wall_like(t(x, y - 1)) and wall_like(t(x, y + 1)):
		return false
	return l or r

# ================== КАРТА ИЗ ФАЙЛА ==================
## Карта игры — файл maps/city.json (её правят в редакторе карты, в игру она попадает только с выпуском).
## Клетки хранятся строками символов: одна строка — один ряд карты, так изменения видны в истории коммитов.
const MAP_PATH := "res://maps/city.json"
const MAP_CHARS := ".=-wt#DdO?T!FCWSMLRcvx~"  # символ = номер клетки (9 и 11 — старые, на карте недопустимы; ~ вода — 0.40)
const MAX_SIDE := 500           # клеток по стороне (1 клетка ≈ 1 м); 500×500 проверено тестом test_big_map
const PROP_CHUNK := 10          # = WorldMesh.CHUNK: объекты разложены по кускам графики (props_chunk)
const MAX_PROPS := 20000
const Props = preload("res://scripts/props.gd")
## Дороги-линии. Ширина: асфальт (половина) и вся полоса с тротуарами/обочинами (половина), метры
const LINE_KINDS := ["street", "highway", "bridge"]
const LINE_ROAD_HW := {"street": 3.0, "highway": 6.0, "bridge": 3.0}
const LINE_OUTER_HW := {"street": 5.0, "highway": 7.5, "bridge": 4.0}
const BRIDGE_RAIL := 0.15       # перила моста: столько от края настила не пройти
const MAX_LINES := 2000
const MAX_LINE_PTS := 64
const LINE_STEP := 1.0          # шаг сглаженной кривой, м

static func read_map_file() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	return d if d is Dictionary else {}

## Загрузить карту; возвращает текст ошибки или "" если всё хорошо. При ошибке мир не меняется
func load_map(d: Dictionary) -> String:
	var nw := int(d.get("w", 0))
	var nh := int(d.get("h", 0))
	if nw < 10 or nh < 10 or nw > MAX_SIDE or nh > MAX_SIDE:
		return "неверный размер карты %dx%d" % [nw, nh]
	var rows = d.get("rows")
	if not (rows is Array) or rows.size() != nh:
		return "в карте должно быть %d рядов" % nh
	var nt := PackedByteArray()
	nt.resize(nw * nh)
	for y in nh:
		var row = rows[y]
		if not (row is String) or row.length() != nw:
			return "ряд %d: должно быть %d клеток" % [y, nw]
		for x in nw:
			var k := MAP_CHARS.find(row[x])
			if k < 0 or k == OLD_WINDOW_BROKEN or k == OLD_DOOR_BROKEN:
				return "ряд %d, клетка %d: неизвестный символ «%s»" % [y, x, row[x]]
			nt[y * nw + x] = k
	var np := []
	var pr = d.get("props", [])
	if not (pr is Array) or pr.size() > MAX_PROPS:
		return "неверный список объектов"
	for e in pr:
		if not (e is Array) or e.size() != 4 or not (e[0] is String) or not Props.DEFS.has(e[0]):
			return "неизвестный объект %s" % [e]
		var px := float(e[1])
		var py := float(e[2])
		if px < 0.0 or py < 0.0 or px >= nw or py >= nh:
			return "объект %s за краем карты" % [e]
		np.append([str(e[0]), px, py, fposmod(float(e[3]), 360.0)])
	var nl := []
	var ln = d.get("lines", [])
	if not (ln is Array) or ln.size() > MAX_LINES:
		return "неверный список дорог"
	for e in ln:
		if not (e is Array) or e.size() < 5 or e.size() % 2 == 0 or (e.size() - 1) / 2 > MAX_LINE_PTS \
				or not (e[0] is String) or not LINE_KINDS.has(e[0]):
			return "неверная дорога %s" % [e]
		var le := [str(e[0])]
		for k in range(1, e.size()):
			var v := float(e[k])
			if not is_finite(v) or v < 0.0 or v > (nw if k % 2 == 1 else nh):
				return "дорога %s за краем карты" % [e]
			le.append(v)
		nl.append(le)
	var sp = d.get("spawn")
	if not (sp is Array) or sp.size() != 2:
		return "нет точки появления"
	var spv := Vector2(float(sp[0]), float(sp[1]))
	if spv.x < 1.0 or spv.y < 1.0 or spv.x > nw - 1 or spv.y > nh - 1:
		return "точка появления за краем карты"
	w = nw
	h = nh
	tiles = nt
	building_of.resize(w * h)
	props = np
	lines = nl
	spawn = spv
	compute_buildings()
	index_props()
	index_lines()
	has_water = tiles.has(WATER)
	compute_water_depth()
	dirty_tiles.clear()
	vis_dirty.clear()
	events.clear()
	return ""

## Карта в виде данных для файла (редактор сохраняет и отправляет её так же)
func map_data() -> Dictionary:
	var rows := []
	for y in h:
		var row := ""
		for x in w:
			row += MAP_CHARS[tiles[y * w + x]]
		rows.append(row)
	var pr := []
	for e in props:
		pr.append([e[0], snappedf(e[1], 0.01), snappedf(e[2], 0.01), roundi(e[3])])
	var ln := []
	for e in lines:
		if e.size() < 5:
			continue             # дорога из одной точки (её только начали рисовать в редакторе) — не в файл
		var le := [e[0]]
		for k in range(1, e.size()):
			le.append(snappedf(e[k], 0.01))
		ln.append(le)
	return {"v": 1, "w": w, "h": h, "spawn": [snappedf(spawn.x, 0.01), snappedf(spawn.y, 0.01)], "rows": rows, "props": pr, "lines": ln}

## Текст файла карты: ряды и объекты — по одному на строку
static func map_text(d: Dictionary) -> String:
	var out := "{\"v\": 1, \"w\": %d, \"h\": %d, \"spawn\": %s,\n\"rows\": [\n" % [d["w"], d["h"], JSON.stringify(d["spawn"])]
	var rows: Array = d["rows"]
	for i in rows.size():
		out += JSON.stringify(rows[i]) + ("," if i < rows.size() - 1 else "") + "\n"
	out += "],\n\"props\": [\n"
	var pr: Array = d["props"]
	for i in pr.size():
		out += JSON.stringify(pr[i]) + ("," if i < pr.size() - 1 else "") + "\n"
	var ln: Array = d.get("lines", [])
	if ln.is_empty():
		return out + "]}\n"         # карта без дорог-линий — тот же файл, что до 0.38
	out += "],\n\"lines\": [\n"
	for i in ln.size():
		out += JSON.stringify(ln[i]) + ("," if i < ln.size() - 1 else "") + "\n"
	return out + "]}\n"

## Круги столкновений объектов разложить по клеткам (после загрузки карты и правок в редакторе)
var props_chunk := {}          # Vector2i(кусок) → объекты в нём: кусок графики не перебирает все объекты карты (BF-052)

func index_props() -> void:
	prop_cols.clear()
	props_chunk.clear()
	for e in props:
		var ck := Vector2i(int(e[1]) / PROP_CHUNK, int(e[2]) / PROP_CHUNK)
		if props_chunk.has(ck):
			props_chunk[ck].append(e)
		else:
			props_chunk[ck] = [e]
		for c: Vector3 in Props.colliders(e):
			for y in range(floori(c.y - c.z), floori(c.y + c.z) + 1):
				for x in range(floori(c.x - c.z), floori(c.x + c.z) + 1):
					if inside(x, y):
						var i := y * w + x
						if not prop_cols.has(i):
							prop_cols[i] = []
						prop_cols[i].append(c)

# ================== ДОРОГИ-ЛИНИИ ==================
## Сглаженная кривая через точки линии (Катмулл-Ром), шаг ~LINE_STEP
static func line_path(e: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(1, e.size() - 1, 2):
		pts.append(Vector2(e[k], e[k + 1]))
	var out := PackedVector2Array()
	if pts.size() < 2:
		return out
	out.append(pts[0])
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		# длина куска кривой не больше ломаной через опорные точки Безье — по ней и число шагов
		var b1 := p1 + (p2 - p0) / 6.0
		var b2 := p2 - (p3 - p1) / 6.0
		# частые точки, из них берём такие, чтобы шаг был не больше LINE_STEP (по параметру шаги неравные)
		var n := maxi(1, ceili((p1.distance_to(b1) + b1.distance_to(b2) + b2.distance_to(p2)) / LINE_STEP * 4.0))
		var prev := p1
		for j in range(1, n + 1):
			var t := float(j) / n
			var t2 := t * t
			var t3 := t2 * t
			var q := 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)
			if j == n:
				if out[out.size() - 1].distance_to(p2) > LINE_STEP and prev != p1:
					out.append(prev)
				out.append(p2)
			elif out[out.size() - 1].distance_to(q) > LINE_STEP * 0.95:
				out.append(prev)
			prev = q
	return out

## Куски кривых по кускам графики: Vector2i → [[вид, A, B, нормаль куска, она же, путь до A, до B, номер линии,
## нормаль предыдущего куска или null]]
var lines_chunk := {}

func index_lines() -> void:
	lines_chunk.clear()
	for li in lines.size():
		var e: Array = lines[li]
		var path := line_path(e)
		if path.size() < 2:
			continue
		# концы чуть дальше точек (0.3 м): у двух дорог, сходящихся под углом, на стыке не видно щели с травой
		var t0 := (path[0] - path[1]).normalized()
		var t1 := (path[path.size() - 1] - path[path.size() - 2]).normalized()
		path.insert(0, path[0] + t0 * 0.3)
		path.append(path[path.size() - 1] + t1 * 0.3)
		var s := 0.0
		var prev_n = null
		for i in path.size() - 1:
			var a := path[i]
			var b := path[i + 1]
			var ds := a.distance_to(b)
			if ds < 1e-4:
				continue
			# нормаль самого куска (прямоугольник не выворачивается) и нормаль предыдущего — для клина на стыке
			var n := Vector2(a.y - b.y, b.x - a.x) / ds
			var mid := (a + b) * 0.5
			var ck := Vector2i(floori(mid.x) / PROP_CHUNK, floori(mid.y) / PROP_CHUNK)
			var rec := [e[0], a, b, n, n, s, s + ds, li, prev_n]
			prev_n = n
			if lines_chunk.has(ck):
				lines_chunk[ck].append(rec)
			else:
				lines_chunk[ck] = [rec]
			s += ds

## Точка на асфальте другой линии (кроме номера skip): там не рисуются тротуары и разметка — перекрёсток.
## outer — вместе с тротуарами/обочинами (там не рисуются камешки и травинки клетки под дорогой); pad — запас, м
func on_line_road(p: Vector2, skip: int, outer: bool = false, pad: float = 0.0, s_self: float = -1.0) -> bool:
	var ck := Vector2i(floori(p.x) / PROP_CHUNK, floori(p.y) / PROP_CHUNK)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for r in lines_chunk.get(ck + Vector2i(dx, dy), []):
				# своя дорога: пропустить, кроме кусков далеко по пути (петля, s_self >= 0)
				if r[7] == skip and (s_self < 0.0 or absf((float(r[5]) + float(r[6])) * 0.5 - s_self) < 25.0):
					continue
				var hw: float = (LINE_OUTER_HW[r[0]] if outer else LINE_ROAD_HW[r[0]]) + pad
				if Geometry2D.get_closest_point_to_segment(p, r[1], r[2]).distance_squared_to(p) < hw * hw:
					return true
	return false

## Точка (круг радиуса r) целиком на настиле моста — над водой здесь можно стоять
func on_bridge(p: Vector2, r: float) -> bool:
	var ck := Vector2i(floori(p.x) / PROP_CHUNK, floori(p.y) / PROP_CHUNK)
	var lim: float = LINE_OUTER_HW["bridge"] - BRIDGE_RAIL - r
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for rec in lines_chunk.get(ck + Vector2i(dx, dy), []):
				if rec[0] == "bridge" and Geometry2D.get_closest_point_to_segment(p, rec[1], rec[2]).distance_squared_to(p) <= lim * lim:
					return true
	return false

# ================== ВОДА ==================
## Поле воды: в каждом углу сетки — доля воды в 4 клетках вокруг (0…1). Где вокруг угла есть не трава
## (дорога, тротуар, дом, край карты) — не больше 0.5: вода не заходит на них. Вода — там, где
## билинейное поле > 0.5: по нему и рисуется плавный берег, и решается, где не пройти. Клетка воды одна
## (или полоса в 1 клетку) так водой не становится — вода от 2 клеток в ширину
var has_water := false

func water_corner(px: int, py: int) -> float:
	var n := 0
	var hard := false
	for c in [Vector2i(px - 1, py - 1), Vector2i(px, py - 1), Vector2i(px - 1, py), Vector2i(px, py)]:
		var tt := t(c.x, c.y)
		if tt == WATER:
			n += 1
		elif tt != GRASS and tt != TREE:
			hard = true
	var f := n / 4.0
	return minf(f, 0.5) if hard else f

## Поле в 4 углах клетки [лв, пв, пн, лн] (по обходу) или пусто, если рядом нет воды
func water_corners(x: int, y: int) -> PackedFloat32Array:
	if not has_water:
		return PackedFloat32Array()
	var near := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if t(x + dx, y + dy) == WATER:
				near = true
	if not near:
		return PackedFloat32Array()
	return PackedFloat32Array([water_corner(x, y), water_corner(x + 1, y), water_corner(x + 1, y + 1), water_corner(x, y + 1)])

## Билинейное поле внутри клетки: u, v от 0 до 1; углы — [лв, пв, пн, лн]
static func bilerp(f: PackedFloat32Array, u: float, v: float) -> float:
	return lerpf(lerpf(f[0], f[1], u), lerpf(f[3], f[2], u), v)

## Точка в воде (по полю)
func water_at(p: Vector2) -> bool:
	if not has_water:
		return false
	var x := floori(p.x)
	var y := floori(p.y)
	var f := water_corners(x, y)
	return not f.is_empty() and bilerp(f, p.x - x, p.y - y) > 0.5

## Круг задевает воду (середина и 8 точек по краю); на мосту — нет
func _water_blocks(cx: float, cy: float, r: float) -> bool:
	# быстро: нет клетки воды рядом — нет и воды (поле > 0.5 только у клеток воды и их соседей)
	var near := false
	for y in range(floori(cy - r) - 1, floori(cy + r) + 2):
		for x in range(floori(cx - r) - 1, floori(cx + r) + 2):
			if inside(x, y) and tiles[y * w + x] == WATER:
				near = true
	if not near:
		return false
	var c := Vector2(cx, cy)
	var any := false
	for k in 9:
		var p := c if k == 0 else c + Vector2.from_angle(k * PI / 4.0) * r
		if water_at(p):
			any = true
			break
	return any and not on_bridge(c, r)

## Глубина воды (только для вида): у каждой клетки воды — сколько клеток до ближайшей суши (8 соседей, до 10).
## Цвет воды от неё: у берега светлее, вдали темнее
var water_dist := PackedByteArray()

func compute_water_depth() -> void:
	water_dist = PackedByteArray()
	if not has_water:
		return
	water_dist.resize(w * h)
	var q := PackedInt32Array()
	for i in w * h:
		if tiles[i] == WATER:
			water_dist[i] = 255
		else:
			water_dist[i] = 0
			q.append(i)
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var d: int = water_dist[i]
		if d >= 10:
			continue
		var x := i % w
		var y := i / w
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if inside(nx, ny):
					var ni := ny * w + nx
					if water_dist[ni] > d + 1:
						water_dist[ni] = d + 1
						q.append(ni)
	for i in w * h:
		if water_dist[i] == 255:
			water_dist[i] = 10

## Глубина в углах клетки [лв, пв, пн, лн] — среднее по 4 клеткам у угла (суша — 0)
func water_depth_corners(x: int, y: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for c in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 1, y + 1), Vector2i(x, y + 1)]:
		var sum := 0.0
		for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
			var px: int = c.x + d.x
			var py: int = c.y + d.y
			if inside(px, py) and water_dist.size() == w * h:
				sum += water_dist[py * w + px]
		out.append(sum / 4.0)
	return out
