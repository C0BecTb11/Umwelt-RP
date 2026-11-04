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

# ---------- генерация города ----------
func generate(seed: int) -> Vector2:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed
	tiles.fill(GRASS)
	var step := 25
	for k in range(w / step + 1):
		var r0 := k * step
		for a in w:
			for o in 3:
				set_t(a, r0 + o, ROAD)
				set_t(r0 + o, a, ROAD)
	for k in range(w / step + 1):
		var r0 := k * step
		for a in w:
			for o in [-1, 3]:
				if t(a, r0 + o) == GRASS:
					set_t(a, r0 + o, SIDEWALK)
				if t(r0 + o, a) == GRASS:
					set_t(r0 + o, a, SIDEWALK)
	var blocks: Array = []
	var by := 0
	while by + step <= h:
		var bx := 0
		while bx + step <= w:
			blocks.append(Vector2i(bx, by))
			bx += step
		by += step
	var police_block := rnd.randi() % blocks.size()
	for bi in blocks.size():
		var b: Vector2i = blocks[bi]
		var ox := b.x + 4
		var oy := b.y + 4
		for ly in 2:
			for lx in 2:
				var lot_x := ox + lx * 10
				var lot_y := oy + ly * 10
				var roll := rnd.randf()
				var kind := 0
				if bi == police_block and lx == 0 and ly == 0:
					kind = 2
				elif roll < 0.12:
					kind = 1
				elif roll < 0.85:
					kind = 0
				else:
					kind = -1
				if kind < 0:
					_scatter_trees(rnd, lot_x, lot_y)
				else:
					_build_house(rnd, lot_x, lot_y, ly == 0, kind)
	# брошенные машины
	var nroads := w / step
	for k in range(nroads + 1):
		var r0 := k * step
		for b in nroads:
			var s0 := b * step
			if rnd.randf() < 0.6:
				var x := s0 + 5 + rnd.randi() % 15
				var y := r0 + (0 if rnd.randi() % 2 == 0 else 2)
				if t(x, y) == ROAD and t(x + 1, y) == ROAD and y < h:
					set_t(x, y, CAR)
					set_t(x + 1, y, CAR_TAIL)
			if rnd.randf() < 0.6:
				var y2 := s0 + 5 + rnd.randi() % 15
				var x2 := r0 + (0 if rnd.randi() % 2 == 0 else 2)
				if t(x2, y2) == ROAD and t(x2, y2 + 1) == ROAD and x2 < w:
					set_t(x2, y2, CAR_V)
					set_t(x2, y2 + 1, CAR_TAIL)
	for _i in range(w * h / 120):
		var x := rnd.randi() % w
		var y := rnd.randi() % h
		if t(x, y) == GRASS and t(x + 1, y) == GRASS and t(x, y + 1) == GRASS and t(x - 1, y) == GRASS and t(x, y - 1) == GRASS:
			set_t(x, y, TREE)
	var c := (w / step / 2) * step
	return Vector2(c + 4.5, c + 3.5)

func _scatter_trees(rnd: RandomNumberGenerator, x0: int, y0: int) -> void:
	for _i in range(4 + rnd.randi() % 4):
		set_t(x0 + 1 + rnd.randi() % 8, y0 + 1 + rnd.randi() % 8, TREE)

func _build_house(rnd: RandomNumberGenerator, lot_x: int, lot_y: int, door_top: bool, kind: int) -> void:
	var hw := 7 + rnd.randi() % 3 if kind == 0 else 9
	var hh := 7 + rnd.randi() % 3 if kind == 0 else 9
	var x0 := lot_x + (10 - hw) / 2
	var y0 := lot_y + (0 if door_top else 10 - hh)
	var x1 := x0 + hw - 1
	var y1 := y0 + hh - 1
	var floor_t := WOOD if kind == 0 else TILEFLOOR
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			set_t(x, y, WALL if (x == x0 or x == x1 or y == y0 or y == y1) else floor_t)
	var dx := x0 + hw / 2
	var dy := y0 if door_top else y1
	set_t(dx, dy, DOOR)
	if kind == 1:
		set_t(dx - 1, dy, DOOR)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var edge := x == x0 or x == x1 or y == y0 or y == y1
			var corner := (x == x0 or x == x1) and (y == y0 or y == y1)
			if not edge or corner or t(x, y) != WALL:
				continue
			if absi(x - dx) <= 1 and y == dy:
				continue
			if rnd.randf() < (0.45 if kind == 1 else 0.22):
				set_t(x, y, WINDOW)
	match kind:
		1:
			var sx := x0 + 2
			while sx <= x1 - 2:
				for y in range(y0 + 2, y1 - 1):
					if y != (y0 + 1 if door_top else y1 - 1):
						set_t(sx, y, STORESHELF)
				sx += 2
			set_t(x1 - 1, y1 - 1 if door_top else y0 + 1, FRIDGE)
		2:
			var fy := y1 - 1 if door_top else y0 + 1
			set_t(x0 + 1, fy, LOCKER)
			set_t(x0 + 2, fy, LOCKER)
			set_t(x1 - 1, fy, MEDCAB)
			set_t(x1 - 1, y0 + 1 if door_top else y1 - 1, COUNTER)
		_:
			_house_rooms(rnd, x0, y0, x1, y1, door_top, dx)
	_fix_openings(x0, y0, x1, y1)

## Окно, в которое упирается внутренняя стена, и окно за мебелью становятся глухой стеной:
## иначе стена делит окно пополам и торчит наружу, а шкаф стоит вплотную к стеклу
func _fix_openings(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not is_window_like(t(x, y)):
				continue
			var bad := false
			for d in 4:
				var nx: int = x + DX4[d]
				var ny: int = y + DY4[d]
				if nx <= x0 or nx >= x1 or ny <= y0 or ny >= y1:
					continue        # соседи по периметру — обычная стена дома
				var nt := t(nx, ny)
				if nt == WALL or is_door_like(nt) or is_furniture(nt):
					bad = true
			if bad:
				set_t(x, y, WALL)

func _house_rooms(rnd: RandomNumberGenerator, x0: int, y0: int, x1: int, y1: int, door_top: bool, door_x: int) -> void:
	var mid := (x0 + x1) / 2 + (1 if rnd.randi() % 2 == 0 else 0)
	if mid == door_x:
		mid += 1 if mid + 1 < x1 - 1 else -1
	for y in range(y0 + 1, y1):
		set_t(mid, y, WALL)
	var hmid := (y0 + y1) / 2
	var gap := y0 + 2 + rnd.randi() % maxi(1, y1 - y0 - 3)
	if gap == hmid:
		gap = hmid + 1 if hmid + 1 < y1 else hmid - 1
	set_t(mid, gap, DOOR_OPEN)
	var entry_left := door_x < mid
	var sx0 := mid + 1 if entry_left else x0 + 1
	var sx1 := x1 - 1 if entry_left else mid - 1
	var split := false
	if sx1 - sx0 >= 1 and y1 - y0 >= 7:
		for x in range(sx0, sx1 + 1):
			set_t(x, hmid, WALL)
		var g := sx0 + rnd.randi() % (sx1 - sx0 + 1)
		if absi(g - mid) > 0:
			set_t(g, hmid, DOOR_OPEN)
			split = true
		else:
			for x in range(sx0, sx1 + 1):
				set_t(x, hmid, WOOD)
	var ex0 := x0 + 1 if entry_left else mid + 1
	var ex1 := mid - 1 if entry_left else x1 - 1
	var far := y1 - 1 if door_top else y0 + 1
	for y in range(y0 + 1, y1):
		for x in range(ex0, ex1 + 1):
			set_t(x, y, TILEFLOOR)
	_place(rnd, ex0, ex1, far, [FRIDGE, COUNTER, COUNTER])
	if split:
		_place(rnd, sx0, sx1, y0 + 1, [WARDROBE if rnd.randi() % 2 == 0 else SHELF])
		_place(rnd, sx0, sx1, y1 - 1, [MEDCAB if rnd.randf() < 0.5 else WARDROBE])
	else:
		_place(rnd, sx0, sx1, y0 + 1, [WARDROBE])
		_place(rnd, sx0, sx1, y1 - 1, [SHELF])

func _place(rnd: RandomNumberGenerator, xa: int, xb: int, y: int, items: Array) -> void:
	if xb < xa:
		return
	var cells: Array = []
	for x in range(xa, xb + 1):
		cells.append(x)
	for i in range(cells.size() - 1, 0, -1):
		var j := rnd.randi() % (i + 1)
		var tmp = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	var k := 0
	for x in cells:
		if k >= items.size():
			break
		if not is_floor(t(x, y)):
			continue
		var near_door := false
		for d in 4:
			var nt := t(x + DX4[d], y + DY4[d])
			if is_door_like(nt) or is_window_like(nt):
				near_door = true        # не у двери и не перед окном
		if near_door:
			continue
		set_t(x, y, items[k])
		k += 1

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
