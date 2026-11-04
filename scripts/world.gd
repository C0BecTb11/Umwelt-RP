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
	var x0 := floori(cx - r)
	var x1 := floori(cx + r)
	var y0 := floori(cy - r)
	var y1 := floori(cy + r)
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

func compute_buildings() -> void:
	buildings.clear()
	building_of.fill(-1)
	var q := PackedInt32Array()
	q.resize(w * h)
	for start in range(w * h):
		if building_of[start] >= 0 or not _is_building_tile(tiles[start]):
			continue
		var id := buildings.size()
		var x0 := w
		var y0 := h
		var x1 := 0
		var y1 := 0
		var head := 0
		var tail := 0
		q[tail] = start
		tail += 1
		building_of[start] = id
		while head < tail:
			var i: int = q[head]
			head += 1
			var x := i % w
			var y := i / w
			x0 = mini(x0, x)
			y0 = mini(y0, y)
			x1 = maxi(x1, x)
			y1 = maxi(y1, y)
			for k in 4:
				var nx: int = x + DX4[k]
				var ny: int = y + DY4[k]
				if not inside(nx, ny):
					continue
				var ni := idx(nx, ny)
				if building_of[ni] < 0 and _is_building_tile(tiles[ni]):
					building_of[ni] = id
					q[tail] = ni
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
const MAP_CHARS := ".=-wt#DdO?T!FCWSMLRcvx"   # символ = номер клетки (9 и 11 — старые, на карте недопустимы)
const MAX_SIDE := 400
const MAX_PROPS := 20000
const Props = preload("res://scripts/props.gd")

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
	spawn = spv
	compute_buildings()
	index_props()
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
	return {"v": 1, "w": w, "h": h, "spawn": [snappedf(spawn.x, 0.01), snappedf(spawn.y, 0.01)], "rows": rows, "props": pr}

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
	return out + "]}\n"

## Круги столкновений объектов разложить по клеткам (после загрузки карты и правок в редакторе)
func index_props() -> void:
	prop_cols.clear()
	for e in props:
		for c: Vector3 in Props.colliders(e):
			for y in range(floori(c.y - c.z), floori(c.y + c.z) + 1):
				for x in range(floori(c.x - c.z), floori(c.x + c.z) + 1):
					if inside(x, y):
						var i := y * w + x
						if not prop_cols.has(i):
							prop_cols[i] = []
						prop_cols[i].append(c)
