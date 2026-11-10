class_name WorldMesh
extends RefCounted
## Строит статическую 3D-геометрию по карте. X — x карты, Z — y карты, Y — вверх.

const WH := 2.4
const HALF := 0.11
const CHUNK := 10
const W = preload("res://scripts/world.gd")

const WALL_COLS := [0xDCD2C2, 0xCDB99C, 0xB9C1C6, 0xD8BEA6, 0xC9C3B0, 0xB8C4B0]
const BRICK_TINTS := [0xFFFFFF, 0xF2DCCC, 0xE0CCC4, 0xFFE8D0]
const INNER_WALL := 0xDDD6CA      # штукатурка внутри кирпичного дома
const ROOF_COLS := [0x8A4236, 0x4E5A66, 0x6E5C46, 0x46604E, 0x6A4440]
const CAR_COLS := [0x8E2E2A, 0x2C4C7C, 0xD6D6CC, 0x35373B, 0x55744A, 0xC89A3C, 0x6A6E74]

var w: GameWorld
var chunks_x := 0
var chunks_y := 0
var lamps: Array = []     # [x, z основания, x, z головы] — фонари из объектов карты (для света ночью)
const Props = preload("res://scripts/props.gd")

static func hash2(x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 0x7FFFFFFF

static func c(hex: int, k: float = 1.0) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255, int(round(k * 255.0)))

static func dk(col: Color, k: float) -> Color:
	return Color(col.r * k, col.g * k, col.b * k, col.a)

static func jit(col: Color, h: int, amt: float) -> Color:
	var k := 1.0 + ((((h >> 4) % 21) - 10) / 10.0) * amt
	return Color(clampf(col.r * k, 0, 1), clampf(col.g * k, 0, 1), clampf(col.b * k, 0, 1), col.a)

func _init(world: GameWorld) -> void:
	w = world
	chunks_x = (w.w + CHUNK - 1) / CHUNK
	chunks_y = (w.h + CHUNK - 1) / CHUNK
	refresh_lamps()

## Фонари берутся из объектов карты (после правок в редакторе — вызвать заново)
func refresh_lamps() -> void:
	lamps.clear()
	for e in w.props:
		if e[0] == "lamp":
			var hd := Props.lamp_head(e)
			lamps.append([e[1], e[2], hd.x, hd.y])

func building_at_cell(x: int, y: int) -> int:
	return w.building_of[w.idx(clampi(x, 0, w.w - 1), clampi(y, 0, w.h - 1))]

## Ключ вида дома — по его левому верхнему углу, а не по номеру: номера домов меняются, когда выше на карте
## появляется или пропадает дом, и тогда перекрашивался бы весь город (BF-055); угол меняется, только если
## перестроили сам дом
func _bkey(bi: int) -> int:
	if bi < 0 or bi >= w.buildings.size():
		return 0
	var b: Array = w.buildings[bi]
	return hash2(b[0], b[1])

## Стены дома снаружи: кирпич или штукатурка (пока — по дому, выбор в редакторе — позже)
func wall_mat(bi: int) -> int:
	return Mesher.M_BRICK if hash2(_bkey(bi), 7) % 10 < 4 else Mesher.M_CONCRETE

## Цвет стены снаружи: у кирпича — оттенок поверх текстуры, у штукатурки — сам цвет
func wall_tint(bi: int) -> Color:
	if wall_mat(bi) == Mesher.M_BRICK:
		return c(BRICK_TINTS[hash2(_bkey(bi), 11) % BRICK_TINTS.size()], 0.0)
	return c(WALL_COLS[hash2(_bkey(bi), 13) % WALL_COLS.size()], 0.0)

func wall_color(x: int, y: int) -> Color:
	return _style(building_at_cell(x, y))[1]

## Вид дома [материал, цвет] — с запоминанием на время постройки куска (у стены дома спрашивают много раз)
var _style_cache := {}
func _style(bi: int) -> Array:
	var st = _style_cache.get(bi)
	if st == null:
		st = [wall_mat(bi), wall_tint(bi)]
		_style_cache[bi] = st
	return st

func _inside(x: int, y: int) -> bool:
	var t := w.t(x, y)
	return W.is_floor(t) or W.is_furniture(t)

static func ground_h(t: int) -> float:
	if t == W.SIDEWALK:
		return 0.12
	if W.is_floor(t) or W.is_furniture(t):
		return 0.1
	return 0.0

# ================== ЧАНК ==================
func build_chunk(m: Mesher, cx: int, cy: int) -> void:
	m.clear()
	_style_cache.clear()
	for y in range(cy * CHUNK, mini(w.h, (cy + 1) * CHUNK)):
		for x in range(cx * CHUNK, mini(w.w, (cx + 1) * CHUNK)):
			_tile(m, x, y)
	for e in w.props_chunk.get(Vector2i(cx, cy), []):
		m.identity()
		m.translate(Vector3(e[1], ground_h(w.t(int(e[1]), int(e[2]))), e[2]))
		m.rot_y(e[3])
		Props.build(m, e[0])
	m.identity()
	for r in w.lines_chunk.get(Vector2i(cx, cy), []):
		_line_seg(m, r)
	for jn in w.lines_junc.get(Vector2i(cx, cy), []):
		_junction(m, jn)
	m.mat = Mesher.M_NONE

func _tile(m: Mesher, x: int, y: int) -> void:
	m.mat = Mesher.M_NONE
	var t := w.t(x, y)
	# берег и вода: по полю воды (то же поле решает, где не пройти — GameWorld.water_at)
	var wf := w.water_corners(x, y) if w.has_water else PackedFloat32Array()
	if not wf.is_empty():
		var mx_f := maxf(maxf(wf[0], wf[1]), maxf(wf[2], wf[3]))
		var mn_f := minf(minf(wf[0], wf[1]), minf(wf[2], wf[3]))
		if mn_f > 0.5:
			var dc := w.water_depth_corners(x, y)
			var cl := [_depth_col(dc[0]), _depth_col(dc[1]), _depth_col(dc[2]), _depth_col(dc[3])]
			var P := [Vector3(x, WATER_Y, y), Vector3(x + 1, WATER_Y, y), Vector3(x + 1, WATER_Y, y + 1), Vector3(x, WATER_Y, y + 1)]
			m.mat = Mesher.M_WATER
			m.tri3(P[0], P[3], P[2], cl[0], cl[3], cl[2])
			m.tri3(P[0], P[2], P[1], cl[0], cl[2], cl[1])
			m.mat = Mesher.M_NONE
			return
		if mx_f > 0.5:
			_shore(m, x, y, wf)
			if t == W.TREE:
				_tree(m, x, y)
			return
	if t == W.WATER:
		_ground(m, W.GRASS, x, y, x, y, x + 1, y + 1)     # одинокая клетка воды (уже меньше 2 клеток) — трава
		return
	var hv := hash2(x, y)
	var fx := float(x)
	var fz := float(y)
	if W.wall_like(t):
		_ground_under_wall(m, x, y)
		_walls(m, x, y, t)
	elif W.is_furniture(t):
		_floor_top(m, _floor_near(x, y), x, y, fx, fz, fx + 1, fz + 1)
		_furniture(m, x, y, t)
	else:
		_ground(m, W.ROAD if W.is_car(t) else t, x, y, fx, fz, fx + 1, fz + 1)
		var h := ground_h(t)
		if h > 0.0:
			for k in 4:
				var n := w.t(x + W.DX4[k], y + W.DY4[k])
				var hn := h if W.wall_like(n) else ground_h(n)
				if hn >= h:
					continue
				var side := jit(c(0x7C7C76), hv, 0.05)
				m.mat = Mesher.M_CONCRETE
				match k:
					0: m.quad(Vector3(fx + 1, hn, fz + 1), Vector3(fx + 1, hn, fz), Vector3(fx + 1, h, fz), Vector3(fx + 1, h, fz + 1), side)
					1: m.quad(Vector3(fx, hn, fz), Vector3(fx, hn, fz + 1), Vector3(fx, h, fz + 1), Vector3(fx, h, fz), side)
					2: m.quad(Vector3(fx, hn, fz + 1), Vector3(fx + 1, hn, fz + 1), Vector3(fx + 1, h, fz + 1), Vector3(fx, h, fz + 1), side)
					_: m.quad(Vector3(fx + 1, hn, fz), Vector3(fx, hn, fz), Vector3(fx, h, fz), Vector3(fx + 1, h, fz), side)
				m.mat = Mesher.M_NONE
		match t:
			W.TREE: _tree(m, x, y)
			W.CAR: _car(m, x, y, true)
			W.CAR_V: _car(m, x, y, false)

## Пол под мебелью — как у ближайшего пола комнаты: рядом, а если мебель стоит плотно (койка изголовьем
## к стене, тумбы по бокам) — через клетку-две мебели. Раньше такая клетка всегда была деревянной
func _floor_near(x: int, y: int) -> int:
	for r in range(1, 4):
		for k in 4:
			var ok := true
			for q in range(1, r):
				if not W.is_furniture(w.t(x + W.DX4[k] * q, y + W.DY4[k] * q)):
					ok = false
					break
			var n := w.t(x + W.DX4[k] * r, y + W.DY4[k] * r)
			if ok and W.is_floor(n):
				return n
	return W.WOOD

func _ground(m: Mesher, t: int, x: int, y: int, x0: float, z0: float, x1: float, z1: float) -> void:
	var hv := hash2(x, y)
	if t == W.GRASS or t == W.TREE:
		var base := c([0x4C6A38, 0x50703C, 0x4A6636, 0x527039][hv % 4])
		var mx := (x0 + x1) / 2
		var mz := (z0 + z1) / 2
		m.mat = Mesher.M_DIRT
		m.flat(x0, z0, mx, mz, 0, jit(base, hv, 0.02))
		m.flat(mx, z0, x1, mz, 0, jit(base, hv * 3, 0.02))
		m.flat(x0, mz, mx, z1, 0, jit(base, hv * 5, 0.02))
		m.flat(mx, mz, x1, z1, 0, jit(base, hv * 7, 0.02))
		m.mat = Mesher.M_NONE
		# камешки и травинки — только не под дорогой-линией (с запасом на их размер)
		var bare := (hv % 37 == 0 or hv % 23 == 1) and not w.lines_chunk.is_empty() and w.on_line_road(Vector2(mx, mz), -1, true, 0.6)
		if x1 - x0 > 0.9 and hv % 37 == 0 and not bare:
			var ox := x0 + 0.3 + (hv % 5) * 0.08
			var oz := z0 + 0.3 + (hv % 7) * 0.06
			m.aabb(ox, 0, oz, ox + 0.22, 0.12, oz + 0.16, c(0x7E7E78))
		if x1 - x0 > 0.9 and hv % 23 == 1 and not bare:
			m.identity()
			m.translate(Vector3(x0 + 0.5, 0, z0 + 0.5))
			m.rot_y(hv % 90)
			m.box(Vector3(0, 0.1, 0), Vector3(0.05, 0.2, 0.25), c(0x6A8A44))
			m.box(Vector3(0, 0.1, 0), Vector3(0.25, 0.2, 0.05), c(0x6A8A44))
			m.identity()
	elif t == W.ROAD:
		m.mat = Mesher.M_ASPHALT
		m.flat(x0, z0, x1, z1, 0, jit(c(0x3C3D40), hv, 0.02))
		m.mat = Mesher.M_NONE
		if x1 - x0 > 0.9:
			var cxr := x % 25
			var cyr := y % 25
			if cyr == 1 and cxr >= 4 and cxr <= 23 and x % 2 == 0:
				m.flat(x0 + 0.1, z0 + 0.46, x1 - 0.1, z0 + 0.54, 0.006, c(0xC8A83A))
			if cxr == 1 and cyr >= 4 and cyr <= 23 and y % 2 == 0:
				m.flat(x0 + 0.46, z0 + 0.1, x0 + 0.54, z1 - 0.1, 0.006, c(0xC8A83A))
			if (cxr == 4 or cxr == 23) and cyr <= 2:
				for k in 3:
					m.flat(x0 + 0.15, z0 + k * 0.33 + 0.06, x1 - 0.15, z0 + k * 0.33 + 0.22, 0.006, c(0xD8D8D0))
			if (cyr == 4 or cyr == 23) and cxr <= 2:
				for k in 3:
					m.flat(x0 + k * 0.33 + 0.06, z0 + 0.15, x0 + k * 0.33 + 0.22, z1 - 0.15, 0.006, c(0xD8D8D0))
			if hv % 19 == 0:
				m.flat(x0 + 0.2, z0 + 0.3, x0 + 0.7, z0 + 0.6, 0.004, c(0x2E2F31))
	elif t == W.SIDEWALK:
		var h := 0.12
		var mx2 := (x0 + x1) / 2
		var mz2 := (z0 + z1) / 2
		var g := 0.02
		m.flat(x0, z0, x1, z1, h - 0.005, c(0x6E6E68))
		var base2 := c(0x9C9C96)
		m.mat = Mesher.M_CONCRETE
		m.flat(x0 + g, z0 + g, mx2 - g, mz2 - g, h, jit(base2, hv, 0.03))
		m.flat(mx2 + g, z0 + g, x1 - g, mz2 - g, h, jit(base2, hv * 3, 0.03))
		m.flat(x0 + g, mz2 + g, mx2 - g, z1 - g, h, jit(base2, hv * 5, 0.03))
		m.flat(mx2 + g, mz2 + g, x1 - g, z1 - g, h, jit(base2, hv * 7, 0.03))
		m.mat = Mesher.M_NONE
	elif W.is_floor(t):
		_floor_top(m, t, x, y, x0, z0, x1, z1)
	else:
		m.flat(x0, z0, x1, z1, 0, c(0x4C6A38))

func _floor_top(m: Mesher, t: int, x: int, y: int, x0: float, z0: float, x1: float, z1: float) -> void:
	var hv := hash2(x, y)
	var h := 0.1
	if t == W.TILEFLOOR:
		m.mat = Mesher.M_MARBLE
		var mx := x + 0.5
		var mz := y + 0.5
		var a := c(0xD8D0C0)
		var b := c(0xB8AE9C)
		for q in 4:
			var qx0 := float(x) if q % 2 == 0 else mx
			var qz0 := float(y) if q < 2 else mz
			var cx0 := maxf(qx0, x0)
			var cz0 := maxf(qz0, z0)
			var cx1 := minf(qx0 + 0.5, x1)
			var cz1 := minf(qz0 + 0.5, z1)
			if cx1 > cx0 and cz1 > cz0:
				m.flat(cx0, cz0, cx1, cz1, h, a if (q + (q >> 1)) % 2 == 0 else b)
		m.mat = Mesher.M_NONE
	else:
		for k in 4:
			var pz0 := y + k * 0.25
			var pz1 := pz0 + 0.25
			var cz0 := maxf(pz0, z0)
			var cz1 := minf(pz1, z1)
			if cz1 <= cz0:
				continue
			m.flat(x0, cz0, x1, cz1 - 0.01, h, jit(c(0x8E6842), hv * (k + 3), 0.08))
			m.flat(x0, cz1 - 0.01, x1, cz1, h, c(0x5E4428))
		# до 0.50 тут был случайный «коврик» в каждой ~53-й клетке — на полу выглядел цветным квадратом (BF-062)

func _ground_under_wall(m: Mesher, x: int, y: int) -> void:
	var out := W.GRASS
	for k in 4:
		var n := w.t(x + W.DX4[k], y + W.DY4[k])
		if not W.wall_like(n) and not W.is_floor(n) and not W.is_furniture(n) and not W.is_car(n):
			out = W.GRASS if n == W.TREE or n == W.WATER else n
			break
	for q in 4:
		var dx := -1 if q % 2 == 0 else 1
		var dy := -1 if q < 2 else 1
		var fl := -1
		for nb in [[x + dx, y], [x, y + dy], [x + dx, y + dy]]:
			var n := w.t(nb[0], nb[1])
			if W.is_floor(n):
				fl = n
				break
			if W.is_furniture(n) and fl < 0:
				fl = _floor_near(nb[0], nb[1])     # за мебелью у стены — тот же пол, что в комнате
		var x0 := x + (0.0 if dx < 0 else 0.5)
		var z0 := y + (0.0 if dy < 0 else 0.5)
		if fl >= 0:
			_floor_top(m, fl, x, y, x0, z0, x0 + 0.5, z0 + 0.5)
		else:
			_ground(m, out, x, y, x0, z0, x0 + 0.5, z0 + 0.5)

# ================== СТЕНЫ ==================
func _walls(m: Mesher, x: int, y: int, t: int) -> void:
	var col := wall_color(x, y)
	var cap := dk(col, 0.72)
	var cx := x + 0.5
	var cz := y + 0.5
	var h := HALF
	var l := W.wall_like(w.t(x - 1, y))
	var r := W.wall_like(w.t(x + 1, y))
	var u := W.wall_like(w.t(x, y - 1))
	var d := W.wall_like(w.t(x, y + 1))
	var horiz := w.along_y(x, y)
	# грани стены: в сторону комнаты — штукатурка, наружу — материал дома
	var outm: int = _style(building_at_cell(x, y))[0]
	var inner := c(INNER_WALL, 0.0) if outm == Mesher.M_BRICK else col
	var ins := [_inside(x, y + 1), _inside(x, y - 1), _inside(x + 1, y), _inside(x - 1, y)]
	var fm := PackedInt32Array([Mesher.M_NONE])
	var fc: Array = [null]
	for k in 4:
		fm.append(Mesher.M_CONCRETE if ins[k] else outm)
		fc.append(inner if ins[k] else null)
	m.face_mat = fm
	m.face_col = fc
	match t:
		W.WALL:
			m.aabb(cx - h, 0, cz - h, cx + h, WH, cz + h, col, cap)
			if r: m.aabb(cx, 0, cz - h, x + 1.0, WH, cz + h, col, cap)
			if l: m.aabb(x, 0, cz - h, cx, WH, cz + h, col, cap)
			if d: m.aabb(cx - h, 0, cz, cx + h, WH, y + 1.0, col, cap)
			if u: m.aabb(cx - h, 0, y, cx + h, WH, cz, col, cap)
			_faces_off(m)
			var base := dk(col, 0.6) if outm != Mesher.M_BRICK else c(0x8A8680, 0.0)
			m.mat = Mesher.M_CONCRETE
			if r or l:
				m.aabb(x if l else cx - h, 0, cz - h - 0.01, x + 1.0 if r else cx + h, 0.18, cz + h + 0.01, base)
			if u or d:
				m.aabb(cx - h - 0.01, 0, y if u else cz - h, cx + h + 0.01, 0.18, y + 1.0 if d else cz + h, base)
			m.mat = Mesher.M_NONE
		W.WINDOW:
			_seg(m, x, y, horiz, 0, 0.95, col, cap)
			_seg(m, x, y, horiz, 1.85, WH, col, cap)
			_faces_off(m)
			_room_behind(m, x, y, horiz, ins)
			var frame := c(0xEDE6DA, 0)
			if horiz:
				m.aabb(x + 0.04, 0.95, cz - h - 0.05, x + 0.96, 1.0, cz + h + 0.05, frame)
				m.aabb(x, 1.0, cz - h, x + 0.06, 1.85, cz + h, frame)
				m.aabb(x + 0.94, 1.0, cz - h, x + 1.0, 1.85, cz + h, frame)
			else:
				m.aabb(cx - h - 0.05, 0.95, y + 0.04, cx + h + 0.05, 1.0, y + 0.96, frame)
				m.aabb(cx - h, 1.0, y, cx + h, 1.85, y + 0.06, frame)
				m.aabb(cx - h, 1.0, y + 0.94, cx + h, 1.85, y + 1.0, frame)
			var glass := c(0x7FA6BA, 0)
			if horiz:
				m.aabb(x + 0.06, 1.0, cz - 0.02, x + 0.94, 1.85, cz + 0.02, glass)
				m.aabb(cx - 0.02, 1.0, cz - 0.03, cx + 0.02, 1.85, cz + 0.03, frame)
			else:
				m.aabb(cx - 0.02, 1.0, y + 0.06, cx + 0.02, 1.85, y + 0.94, glass)
				m.aabb(cx - 0.03, 1.0, cz - 0.02, cx + 0.03, 1.85, cz + 0.02, frame)
		_:
			_seg(m, x, y, horiz, 2.05, WH, col, cap)
			_faces_off(m)
			var jamb := dk(col, 0.8) if outm != Mesher.M_BRICK else c(0xCFC6B6, 0.0)
			if horiz:
				m.aabb(x, 0, cz - h - 0.02, x + 0.07, 2.05, cz + h + 0.02, jamb)
				m.aabb(x + 0.93, 0, cz - h - 0.02, x + 1.0, 2.05, cz + h + 0.02, jamb)
			else:
				m.aabb(cx - h - 0.02, 0, y, cx + h + 0.02, 2.05, y + 0.07, jamb)
				m.aabb(cx - h - 0.02, 0, y + 0.93, cx + h + 0.02, 2.05, y + 1.0, jamb)

func _faces_off(m: Mesher) -> void:
	m.face_mat = PackedInt32Array()
	m.face_col = []

## Снаружи окна — картинка комнаты (свет/темно); изнутри дома остаётся простое стекло
func _room_behind(m: Mesher, x: int, y: int, horiz: bool, ins: Array) -> void:
	var o := -1     # наружная сторона: 0 +z, 1 -z, 2 +x, 3 -x
	if horiz:
		if ins[1] and not ins[0]: o = 0
		elif ins[0] and not ins[1]: o = 1
	else:
		if ins[3] and not ins[2]: o = 2
		elif ins[2] and not ins[3]: o = 3
	if o < 0:
		return
	var room := c(0xFFFFFF, 0.0)
	m.mat = Mesher.M_ROOM_LIT if hash2(x, y) % 3 == 0 else Mesher.M_ROOM_DARK
	var cx := x + 0.5
	var cz := y + 0.5
	var a := 0.06
	var y0 := 1.0
	var y1 := 1.85
	match o:
		0: m.quad(Vector3(x + a, y0, cz + 0.025), Vector3(x + 1 - a, y0, cz + 0.025), Vector3(x + 1 - a, y1, cz + 0.025), Vector3(x + a, y1, cz + 0.025), room)
		1: m.quad(Vector3(x + 1 - a, y0, cz - 0.025), Vector3(x + a, y0, cz - 0.025), Vector3(x + a, y1, cz - 0.025), Vector3(x + 1 - a, y1, cz - 0.025), room)
		2: m.quad(Vector3(cx + 0.025, y0, y + 1 - a), Vector3(cx + 0.025, y0, y + a), Vector3(cx + 0.025, y1, y + a), Vector3(cx + 0.025, y1, y + 1 - a), room)
		_: m.quad(Vector3(cx - 0.025, y0, y + a), Vector3(cx - 0.025, y0, y + 1 - a), Vector3(cx - 0.025, y1, y + 1 - a), Vector3(cx - 0.025, y1, y + a), room)
	m.mat = Mesher.M_NONE

func _seg(m: Mesher, x: int, y: int, horiz: bool, y0: float, y1: float, col: Color, cap: Color) -> void:
	var cx := x + 0.5
	var cz := y + 0.5
	if horiz:
		m.aabb(x, y0, cz - HALF, x + 1.0, y1, cz + HALF, col, cap)
	else:
		m.aabb(cx - HALF, y0, y, cx + HALF, y1, y + 1.0, col, cap)

## Мебель из отдельных наборов (военная часть, столовая, полиция, больница): 1, 2, 3, 4; 0 — старая, нарисована ниже
static func furn_set(t: int) -> int:
	if MilFurniture.BACK.has(t):
		return 1
	if CanteenFurniture.BACK.has(t):
		return 2
	if PoliceFurniture.BACK.has(t):
		return 3
	return 4 if HospitalFurniture.BACK.has(t) else 0

## Число из описания набора (BACK, FRONT, TUCK) для мебели t
static func furn_num(t: int, what: String, def: float = 0.0) -> float:
	for cls in [MilFurniture, CanteenFurniture, PoliceFurniture, HospitalFurniture]:
		var d = cls.get(what)
		if d is Dictionary and d.has(t):
			return float(d[t])
	return def

## Вес сиденья в клетке при выборе стороны стола: офисное кресло — место хозяина
func _seat_w(x: int, y: int) -> int:
	var tt := w.t(x, y)
	return 10 if tt == W.OFFICECHAIR else (1 if W.is_seat(tt) else 0)

## Куда повернуть лицом стол, стоящий посреди комнаты: к креслу хозяина. Стойка дежурного — вся линия
## в одну сторону (туда, где у линии кресла; без кресел — на юг или восток). -1 — сидений рядом нет
func table_face(x: int, y: int, t: int) -> int:
	if W.is_counter(t):
		for a in [[1, 0], [0, 1]]:
			var ax: int = a[0]
			var ay: int = a[1]
			if w.t(x + ax, y + ay) != t and w.t(x - ax, y - ay) != t:
				continue
			var sides := [2, 3] if ax == 1 else [0, 1]       # стороны линии: юг/север или восток/запад
			var sw := [0, 0]
			for sgn in [1, -1]:
				var n := 0 if sgn == 1 else 1
				while n < 12 and w.t(x + ax * n * sgn, y + ay * n * sgn) == t:
					for si in 2:
						sw[si] += _seat_w(x + ax * n * sgn + W.DX4[sides[si]], y + ay * n * sgn + W.DY4[sides[si]])
					n += 1
			return sides[1] if sw[1] > sw[0] else sides[0]
	var bw := 0
	var bk := -1
	for k in 4:
		var sw2 := _seat_w(x + W.DX4[k], y + W.DY4[k])
		if sw2 > bw:
			bw = sw2
			bk = k
	return bk

## Куда от клетки дальше всего тянется свободный пол (для трибуны: лицом к залу)
func open_dir(x: int, y: int) -> int:
	var best := 0
	var bn := -1
	for k in 4:
		var n := 0
		while n < 8:
			var tt := w.t(x + W.DX4[k] * (n + 1), y + W.DY4[k] * (n + 1))
			if not (W.is_floor(tt) or W.is_seat(tt)):
				break
			n += 1
		if n > bn:
			bn = n
			best = k
	return best

func _bar_like(x: int, y: int) -> bool:
	var tt := w.t(x, y)
	return W.wall_like(tt) or W.is_bars(tt)

## Ширма: вдоль ряда ширм; одиночная — от стены в комнату (как перегородка между койками)
func _screen_vertical(x: int, y: int) -> bool:
	var hz := W.is_screen(w.t(x - 1, y)) or W.is_screen(w.t(x + 1, y))
	var vt := W.is_screen(w.t(x, y - 1)) or W.is_screen(w.t(x, y + 1))
	if hz != vt:
		return vt
	hz = W.wall_like(w.t(x - 1, y)) or W.wall_like(w.t(x + 1, y))
	vt = W.wall_like(w.t(x, y - 1)) or W.wall_like(w.t(x, y + 1))
	return vt and not hz

## С какой стороны от клетки лежит пациент (койка, каталка, операционный стол, кушетка); -1 — рядом нет
func patient_dir(x: int, y: int) -> int:
	for k in 4:
		if W.is_patient_bed(w.t(x + W.DX4[k], y + W.DY4[k])):
			return k
	return -1

## Где на мебели в клетке можно сесть или лечь — в координатах мира (точки модели — RestSpots). Каждое место:
## "k" 1 сидеть / 2 лежать; "h" — высота сиденья или постели над полом; "face" — куда человек смотрит, пока стоит
## перед мебелью (сидя — туда же); "o" — остальное описание места для позы (CharPoses.sit и lie).
## Сидеть: "pos" — куда приходит таз (x, y карты). Лежать: "pos" — опорная точка постели (изгиб изголовья или
## подушка), "axis" — от головы к ногам. Лечь можно только с той стороны, где перед постелью свободный пол.
## Верхний ярус: "from" — где человек стоит перед лесенкой (лицом к ней, "face" — в сторону койки)
func rest_spots(x: int, y: int) -> Array:
	var out := []
	var t := w.t(x, y)
	if not W.is_furniture(t):
		return out
	var m := Mesher.new()
	var how := _furniture(m, x, y, t, true)
	if how == 0:
		return out                             # вторая половина длинной мебели: места — у первой
	for sp: Dictionary in RestSpots.local(t, how, hash2(x, y)):
		var lp: Vector3 = sp["p"]
		var wp: Vector3 = m.xf * Vector3(lp.x, 0, lp.z)
		var o := {}
		for key: String in sp:
			if key != "p" and key != "k" and key != "sides":
				o[key] = sp[key]
		if int(sp["k"]) == 1:
			var f: Vector3 = m.xf.basis * Vector3.BACK
			out.append({"k": 1, "pos": Vector2(wp.x, wp.z), "h": lp.y, "face": Vector2(f.x, f.z).normalized(), "o": o})
			continue
		var ax: Vector3 = m.xf.basis * Vector3.RIGHT
		for sg: int in sp["sides"]:
			var n: Vector3 = m.xf.basis * Vector3(0, 0, sg)
			var stand := Vector2(wp.x + ax.x * 0.4 + n.x * float(sp["deep"]), wp.z + ax.z * 0.4 + n.z * float(sp["deep"]))
			if sp.has("climb"):
				var lad: Vector3 = sp["climb"]
				var lw: Vector3 = m.xf * Vector3(lad.x, 0, lad.z + sg * CharPoses.LADDER_GAP)
				stand = Vector2(lw.x, lw.z)
			if w.circle_blocked(stand.x, stand.y, 0.05):
				continue                           # с этой стороны стена или другая мебель
			var e := {"k": 2, "pos": Vector2(wp.x, wp.z), "h": lp.y, "face": Vector2(n.x, n.z).normalized(),
				"axis": Vector2(ax.x, ax.z).normalized(), "o": o}
			if sp.has("climb"):
				e["from"] = stand
				e["face"] = -(e["face"] as Vector2)
				o["lad"] = CharPoses.LADDER_GAP
				o.erase("climb")
			out.append(e)
			break
	return out

## Нарисовать мебель клетки. place_only — только поставить (в m.xf останутся её место и поворот), не рисуя.
## Возвращает, как она стоит: 0 — эту клетку рисует соседняя (вторая половина длинной мебели, изножье койки),
## 1 — одна клетка, 2 — длинная на две клетки, 3 — койка изголовьем к стене
func _furniture(m: Mesher, x: int, y: int, t: int, place_only: bool = false) -> int:
	# спиной к стене, лицом в комнату (если стен несколько — к той, напротив которой свободно)
	# направление — то же, по которому считается столкновение (GameWorld.furniture_dir, FURN_FRONT)
	var yaw := 0.0
	var flip := false                              # длинный стол посреди комнаты развёрнут к креслу хозяина
	var best := w.furniture_dir(x, y)
	var wide: Array = w.furniture_wide(x, y)       # [половина, шаг «вправо»] — длинная мебель на две клетки
	var deep: Array = w.bed_deep(x, y) if t == W.HOSPBED else [0, -1]    # койка изголовьем к стене
	if deep[0] == 2:
		return 0                                   # изножье: всю койку рисует клетка-изголовье
	if best >= 0:
		yaw = rad_to_deg(atan2(W.DX4[best], W.DY4[best]))
	elif W.is_bars(t):
		# решётка — вдоль ряда решёток и стен
		var hz := _bar_like(x - 1, y) or _bar_like(x + 1, y)
		var vt := _bar_like(x, y - 1) or _bar_like(x, y + 1)
		yaw = 90.0 if vt and not hz else 0.0
	elif W.is_screen(t):
		yaw = 90.0 if _screen_vertical(x, y) else 0.0
	elif t == W.PODIUM or t == W.SURGLIGHT:
		var od := patient_dir(x, y) if t == W.SURGLIGHT else -1      # светильник — плафоном к столу
		if od < 0:
			od = open_dir(x, y)
		yaw = rad_to_deg(atan2(W.DX4[od], W.DY4[od]))
	elif wide[0] != 0:
		yaw = 0.0 if wide[1] == 1 else -90.0       # посреди комнаты длинная мебель встаёт вдоль своего ряда
		if W.is_table(t) and wide[0] == 1:
			var fx := 0 if wide[1] == 1 else -1    # куда смотрит лицо при таком повороте
			var fy := 1 if wide[1] == 1 else 0
			var x2: int = x + wide[1]
			var y2: int = y + wide[2]
			flip = _seat_w(x - fx, y - fy) + _seat_w(x2 - fx, y2 - fy) > _seat_w(x + fx, y + fy) + _seat_w(x2 + fx, y2 + fy)
	else:
		var tf := table_face(x, y, t) if W.is_table(t) else -1
		if tf < 0 and furn_set(t) == 4:
			tf = patient_dir(x, y)                 # больничные приборы посреди комнаты — лицом к пациенту
		if tf >= 0:
			yaw = rad_to_deg(atan2(W.DX4[tf], W.DY4[tf]))
		else:
			for k in 4:
				if W.is_floor(w.t(x + W.DX4[k], y + W.DY4[k])):
					yaw = rad_to_deg(atan2(W.DX4[k], W.DY4[k]))
					break
	var hv := hash2(x, y)
	m.identity()
	m.translate(Vector3(x + 0.5, 0.1, y + 0.5))
	m.rot_y(yaw)
	if flip:
		m.rot_y(180)
		m.translate(Vector3(-1, 0, 0))             # модель тянется на вторую клетку — после разворота вернуть её туда же
	if deep[0] == 1:
		m.rot_y(-90)                               # койка вытянута от стены: изголовье у стены, изножье в комнате
		if not place_only:
			HospitalFurniture.draw(m, t, hv, false, true)
			m.identity()
		return 3
	if w.seat_at_table(x, y, best):
		# сиденье у стола: лицом к столу, передний край — под столешницу
		m.rot_y(180)
		m.translate(Vector3(0, 0, 0.5 + furn_num(t, "TUCK") - furn_num(t, "FRONT") + w.seat_slide(x, y, best)))
	elif best >= 0:
		# вплотную к стене: стена стоит по центру своей клетки, без сдвига оставалась щель ~0.45
		var back: float = {W.FRIDGE: 0.38, W.COUNTER: 0.44, W.WARDROBE: 0.43, W.SHELF: 0.31, W.MEDCAB: 0.40, W.LOCKER: 0.40}.get(t, 0.42)
		back = furn_num(t, "BACK", back)
		m.translate(Vector3(0, 0, -(1.0 - HALF - 0.5 - 0.01) - (0.5 - back)))
	var fs := furn_set(t)
	var how := 0 if wide[0] == 2 else (2 if wide[0] == 1 else 1)
	if place_only:
		return how
	if fs != 0:
		if wide[0] != 2:
			match fs:
				1: MilFurniture.draw(m, t, hv, wide[0] == 1)
				2: CanteenFurniture.draw(m, t, hv, wide[0] == 1)
				3: PoliceFurniture.draw(m, t, hv, wide[0] == 1)
				4: HospitalFurniture.draw(m, t, hv, wide[0] == 1)
		m.identity()
		return how
	var wood := c(0x7A5434)
	match t:
		W.FRIDGE:
			m.box(Vector3(0, 0.85, -0.05), Vector3(0.76, 1.7, 0.66), c(0xE6E6E2))
			m.box(Vector3(0, 1.22, 0.285), Vector3(0.74, 0.02, 0.02), c(0xA8A8A8))
			m.box(Vector3(0.28, 1.45, 0.29), Vector3(0.04, 0.3, 0.04), c(0x8A8A8A))
			m.box(Vector3(0.28, 0.85, 0.29), Vector3(0.04, 0.3, 0.04), c(0x8A8A8A))
		W.COUNTER:
			var stove := hv % 3 == 0
			m.box(Vector3(0, 0.42, -0.06), Vector3(0.92, 0.84, 0.7), c(0x2E2E30 if stove else 0xD8D2C4))
			m.box(Vector3(0, 0.87, -0.06), Vector3(0.96, 0.06, 0.76), c(0x1E1E20 if stove else 0x5E6064))
			if stove:
				for k in 4:
					m.box(Vector3(-0.2 + (k % 2) * 0.4, 0.91, -0.2 + (k / 2) * 0.3), Vector3(0.2, 0.02, 0.2), c(0x101010))
			else:
				m.box(Vector3(-0.22, 0.45, 0.295), Vector3(0.02, 0.7, 0.02), c(0xA09888))
				m.box(Vector3(0.22, 0.45, 0.295), Vector3(0.02, 0.7, 0.02), c(0xA09888))
		W.WARDROBE:
			m.box(Vector3(0, 0.95, -0.15), Vector3(0.92, 1.9, 0.56), c(0x6A4628))
			m.box(Vector3(0, 0.95, 0.135), Vector3(0.02, 1.8, 0.02), c(0x3A2414))
			m.box(Vector3(-0.08, 1.0, 0.14), Vector3(0.04, 0.12, 0.03), c(0xC8A040))
			m.box(Vector3(0.08, 1.0, 0.14), Vector3(0.04, 0.12, 0.03), c(0xC8A040))
		W.SHELF:
			m.box(Vector3(0, 0.8, -0.28), Vector3(0.92, 1.6, 0.06), wood)
			m.box(Vector3(-0.44, 0.8, -0.1), Vector3(0.04, 1.6, 0.4), wood)
			m.box(Vector3(0.44, 0.8, -0.1), Vector3(0.04, 1.6, 0.4), wood)
			for s in 4:
				var sy := 0.05 + s * 0.5
				m.box(Vector3(0, sy, -0.1), Vector3(0.88, 0.04, 0.4), wood)
				if s < 3:
					for b in 6:
						if (hv >> (b + s * 3)) & 1 == 0:
							continue
						var bc := c([0xB03A30, 0x3A6AA0, 0xD0B040, 0x4A8A4A, 0xE0E0D8][(hv + b * 7 + s) % 5])
						m.box(Vector3(-0.33 + b * 0.13, sy + 0.17, -0.12), Vector3(0.1, 0.3, 0.28), bc)
		W.MEDCAB:
			m.box(Vector3(0, 0.9, -0.22), Vector3(0.7, 1.1, 0.36), c(0xF0F0EE))
			m.box(Vector3(0, 0.9, -0.035), Vector3(0.1, 0.42, 0.02), c(0xD03030))
			m.box(Vector3(0, 0.9, -0.035), Vector3(0.42, 0.1, 0.02), c(0xD03030))
		W.LOCKER:
			m.box(Vector3(0, 0.95, -0.15), Vector3(0.8, 1.9, 0.5), c(0x4E5E6E))
			for k in 3:
				m.box(Vector3(0, 1.55 + k * 0.08, 0.105), Vector3(0.5, 0.02, 0.02), c(0x2E3A46))
			m.box(Vector3(0, 0.95, 0.105), Vector3(0.02, 1.8, 0.02), c(0x2E3A46))
		_:
			m.box(Vector3(0, 0.65, 0), Vector3(0.92, 1.3, 0.06), c(0x8A8E94))
			for s in 3:
				var sy2 := 0.12 + s * 0.45
				m.box(Vector3(0, sy2, 0), Vector3(0.92, 0.04, 0.84), c(0xA8ACB2))
				for b in 8:
					if (hv >> (b + s)) & 3 == 0:
						continue
					var side := -1.0 if b < 4 else 1.0
					var bc2 := c([0xD04838, 0xE8C040, 0x4A8AD0, 0xE8E8E0, 0x5AA050][(hv + b + s * 3) % 5])
					m.box(Vector3(-0.33 + (b % 4) * 0.22, sy2 + 0.12, side * 0.22), Vector3(0.16, 0.2, 0.18), bc2)
	m.identity()
	return how

# ================== УЛИЦА ==================

func _tree(m: Mesher, x: int, y: int) -> void:
	var hv := hash2(x, y)
	var cx := x + 0.5
	var cz := y + 0.5
	m.aabb(cx - 0.1, 0, cz - 0.1, cx + 0.1, 1.5, cz + 0.1, c(0x5A4030))
	var autumn := hv % 7 == 0
	var c1 := c(0xB8682C, 0) if autumn else c([0x3E6A32, 0x46723A, 0x365E2C][hv % 3], 0)
	var c2 := c(0xD08A3A, 0) if autumn else Color(minf(c1.r * 1.18, 1), minf(c1.g * 1.18, 1), minf(c1.b * 1.18, 1), 0)
	var s := 0.9 + (hv % 5) * 0.08
	m.blob(Vector3(cx, 1.85 * s, cz), Vector3(0.95, 0.75, 0.95) * s, c1, hv)
	m.blob(Vector3(cx + 0.25, 2.4 * s, cz - 0.15), Vector3(0.62, 0.55, 0.62) * s, c2, hv + 1)
	m.blob(Vector3(cx - 0.3, 2.25 * s, cz + 0.25), Vector3(0.55, 0.5, 0.55) * s, c1, hv + 2)

func _car(m: Mesher, x: int, y: int, horiz: bool) -> void:
	var hv := hash2(x, y)
	var col := c(CAR_COLS[hv % CAR_COLS.size()])
	m.identity()
	if horiz:
		m.translate(Vector3(x + 1.0, 0, y + 0.5))
	else:
		m.translate(Vector3(x + 0.5, 0, y + 1.0))
		m.rot_y(90)
	if hv % 2 == 0:
		m.rot_y(180)
	m.rot_y((hv >> 5) % 9 - 4)
	var dark := c(0x161616)
	for sx in [-0.58, 0.58]:
		for sz in [-0.4, 0.4]:
			m.box(Vector3(sx, 0.17, sz), Vector3(0.34, 0.34, 0.12), dark)
	m.box(Vector3(0, 0.45, 0), Vector3(1.84, 0.42, 0.84), col)
	m.box(Vector3(0.86, 0.36, 0), Vector3(0.14, 0.18, 0.86), c(0x3A3A3C))
	m.box(Vector3(-0.86, 0.36, 0), Vector3(0.14, 0.18, 0.86), c(0x3A3A3C))
	var glass := c(0x1A2228 if hv % 5 == 0 else 0x34495A)
	m.box(Vector3(-0.12, 0.86, 0), Vector3(1.0, 0.42, 0.74), glass)
	m.box(Vector3(-0.12, 1.08, 0), Vector3(0.86, 0.04, 0.7), col)
	m.box(Vector3(-0.12, 0.86, 0), Vector3(0.08, 0.42, 0.76), col)
	m.box(Vector3(0.93, 0.52, 0.28), Vector3(0.03, 0.1, 0.16), c(0xF4ECC4, 0.5))
	m.box(Vector3(0.93, 0.52, -0.28), Vector3(0.03, 0.1, 0.16), c(0xF4ECC4, 0.5))
	m.box(Vector3(-0.93, 0.52, 0.3), Vector3(0.03, 0.1, 0.14), c(0xB02020, 0.5))
	m.box(Vector3(-0.93, 0.52, -0.3), Vector3(0.03, 0.1, 0.14), c(0xB02020, 0.5))
	if hv % 3 == 0:
		m.box(Vector3(0.4, 0.67, 0.1), Vector3(0.3, 0.01, 0.25), dk(col, 0.6))
	m.identity()

# ================== КРЫШИ ==================
## Крыша (с 0.47, BF-060) — только над закрытым домом и по его форме, не по охватывающему прямоугольнику:
## 1) «след» дома — стены/двери/окна этого дома и то, что ими закрыто (снаружи до клетки не дойти, не перелезая
##    стену); стена, не касающаяся комнаты (забор, начатая стена), в след не входит;
## 2) комнаты нет (стены не замкнуты — дом ещё строят) — крыши нет;
## 3) след режется на прямоугольники (сначала самый большой): шире 2 клеток — двускатная крыша, уже — плоская.
##    Где прямоугольник примыкает к другому куску следа, крыша заходит за край клетки — без щели между крышами

## След дома bi: [x0, y0, ширина, высота, маска (1 — под крышей)] или [] — комнаты нет
func roof_footprint(bi: int) -> Array:
	var b: Array = w.buildings[bi]
	var x0: int = b[0] - 1
	var y0: int = b[1] - 1
	var WW: int = b[2] - b[0] + 3
	var HH: int = b[3] - b[1] + 3
	var n := WW * HH
	var wallm := PackedByteArray()
	wallm.resize(n)
	for yy in HH:
		for xx in WW:
			var x := x0 + xx
			var y := y0 + yy
			if w.inside(x, y):
				var i := w.idx(x, y)
				if w.building_of[i] == bi and GameWorld.wall_like(w.tiles[i]):
					wallm[yy * WW + xx] = 1
	# снаружи — заливка от рамки (рамка на клетку шире дома — всегда снаружи) по клеткам без стен этого дома
	var out := PackedByteArray()
	out.resize(n)
	var q := PackedInt32Array()
	for xx in WW:
		q.append(xx)
		q.append((HH - 1) * WW + xx)
	for yy in range(1, HH - 1):
		q.append(yy * WW)
		q.append(yy * WW + WW - 1)
	for k in q:
		out[k] = 1
	var head := 0
	while head < q.size():
		var k: int = q[head]
		head += 1
		var xx := k % WW
		for nb in [k - 1 if xx > 0 else -1, k + 1 if xx < WW - 1 else -1, k - WW, k + WW]:
			if nb >= 0 and nb < n and out[nb] == 0 and wallm[nb] == 0:
				out[nb] = 1
				q.append(nb)
	var mask := PackedByteArray()
	mask.resize(n)
	var rooms := 0
	for k in n:
		if out[k] == 0 and wallm[k] == 0:
			mask[k] = 1
			rooms += 1
	if rooms == 0:
		return []
	# стены — только те, что касаются комнаты (и наискосок: углы)
	for k in n:
		if wallm[k] == 0 or out[k] == 1:
			continue
		var xx := k % WW
		var yy := k / WW
		var touch := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var ax := xx + dx
				var ay := yy + dy
				if ax >= 0 and ay >= 0 and ax < WW and ay < HH and out[ay * WW + ax] == 0 and wallm[ay * WW + ax] == 0:
					touch = true
		if touch:
			mask[k] = 1
	return [x0, y0, WW, HH, mask]

## Самый большой прямоугольник из единиц маски: [x, y, ширина, высота] (по столбикам высот, за один проход)
static func _max_rect(mask: PackedByteArray, WW: int, HH: int) -> Array:
	var hts := PackedInt32Array()
	hts.resize(WW)
	var best := [0, 0, 0, 0]
	var best_a := 0
	for y in HH:
		for x in WW:
			hts[x] = hts[x] + 1 if mask[y * WW + x] == 1 else 0
		var st := PackedInt32Array()
		for x in WW + 1:
			var hx: int = hts[x] if x < WW else 0
			while not st.is_empty() and hts[st[st.size() - 1]] >= hx:
				var top: int = st[st.size() - 1]
				st.resize(st.size() - 1)
				var hh: int = hts[top]
				var left: int = st[st.size() - 1] + 1 if not st.is_empty() else 0
				var a := hh * (x - left)
				if a > best_a:
					best_a = a
					best = [left, y - hh + 1, x - left, hh]
			st.append(x)
	return best

func build_roof(m: Mesher, bi: int) -> void:
	m.clear()
	var fp := roof_footprint(bi)
	if fp.is_empty():
		return
	var x0: int = fp[0]
	var y0: int = fp[1]
	var WW: int = fp[2]
	var HH: int = fp[3]
	var full: PackedByteArray = fp[4]
	var mask := full.duplicate()
	var col := c(ROOF_COLS[hash2(_bkey(bi), 17) % ROOF_COLS.size()])
	var first := true
	for it in 48:
		var r := _max_rect(mask, WW, HH)
		if r[2] == 0:
			break
		var rx: int = r[0]
		var ry: int = r[1]
		var rw: int = r[2]
		var rh: int = r[3]
		for yy in range(ry, ry + rh):
			for xx in range(rx, rx + rw):
				mask[yy * WW + xx] = 0
		# края: снаружи дома — от середины стены со свесом; к другому куску следа — до края клетки и чуть дальше
		var ov := 0.35
		var X0 := x0 + rx + 0.5 - (0.62 if _fp_side(full, WW, HH, rx - 1, ry, 0, rh) else ov)
		var X1 := x0 + rx + rw - 0.5 + (0.62 if _fp_side(full, WW, HH, rx + rw, ry, 0, rh) else ov)
		var Z0 := y0 + ry + 0.5 - (0.62 if _fp_side(full, WW, HH, rx, ry - 1, rw, 0) else ov)
		var Z1 := y0 + ry + rh - 0.5 + (0.62 if _fp_side(full, WW, HH, rx, ry + rh, rw, 0) else ov)
		if mini(rw, rh) >= 3:
			_gable(m, bi, X0, X1, Z0, Z1, col, first)
			first = false
		else:
			m.mat = Mesher.M_SLATE
			m.aabb(X0, WH - 0.02, Z0, X1, WH + 0.12, Z1, dk(col, 0.85))
			m.mat = Mesher.M_NONE

## Есть ли клетки следа на отрезке за краем куска (по x на rw клеток или по y на rh)
static func _fp_side(full: PackedByteArray, WW: int, HH: int, x: int, y: int, rw: int, rh: int) -> bool:
	for k in maxi(rw, rh):
		var xx := x + (k if rw > 0 else 0)
		var yy := y + (k if rh > 0 else 0)
		if xx >= 0 and yy >= 0 and xx < WW and yy < HH and full[yy * WW + xx] == 1:
			return true
	return false

## Двускатная крыша над прямоугольником X0..X1 × Z0..Z1; chimney — с трубой (на самом большом куске)
func _gable(m: Mesher, bi: int, X0: float, X1: float, Z0: float, Z1: float, col: Color, chimney: bool) -> void:
	var wm := wall_mat(bi)
	var wall := dk(wall_tint(bi), 0.82)
	wall.a = 1.0
	var along_x := (X1 - X0) >= (Z1 - Z0)
	var span := (Z1 - Z0) if along_x else (X1 - X0)
	var e := WH
	var R := WH + minf(1.5, span * 0.32)
	var bands := 4
	m.mat = Mesher.M_SLATE
	if along_x:
		var Zm := (Z0 + Z1) / 2
		for i in bands:
			var t0 := float(i) / bands
			var t1 := float(i + 1) / bands
			var cc := col if i % 2 == 0 else dk(col, 0.9)
			var za := Z0 + (Zm - Z0) * t0
			var zb := Z0 + (Zm - Z0) * t1
			var ya := e + (R - e) * t0
			var yb := e + (R - e) * t1
			m.quad(Vector3(X0, ya, za), Vector3(X0, yb, zb), Vector3(X1, yb, zb), Vector3(X1, ya, za), cc)
			var zc := Z1 - (Z1 - Zm) * t0
			var zd := Z1 - (Z1 - Zm) * t1
			m.quad(Vector3(X0, yb, zd), Vector3(X0, ya, zc), Vector3(X1, ya, zc), Vector3(X1, yb, zd), dk(cc, 0.82))
		m.mat = wm
		m.tri(Vector3(X0, e, Z0), Vector3(X0, e, Z1), Vector3(X0, R, Zm), wall)
		m.tri(Vector3(X1, e, Z1), Vector3(X1, e, Z0), Vector3(X1, R, Zm), wall)
		m.mat = Mesher.M_NONE
		m.aabb(X0, R - 0.03, Zm - 0.06, X1, R + 0.05, Zm + 0.06, dk(col, 0.6))
	else:
		var Xm := (X0 + X1) / 2
		for i in bands:
			var t0 := float(i) / bands
			var t1 := float(i + 1) / bands
			var cc := col if i % 2 == 0 else dk(col, 0.9)
			var xa := X0 + (Xm - X0) * t0
			var xb := X0 + (Xm - X0) * t1
			var ya := e + (R - e) * t0
			var yb := e + (R - e) * t1
			m.quad(Vector3(xa, ya, Z1), Vector3(xb, yb, Z1), Vector3(xb, yb, Z0), Vector3(xa, ya, Z0), cc)
			var xc := X1 - (X1 - Xm) * t0
			var xd := X1 - (X1 - Xm) * t1
			m.quad(Vector3(xd, yb, Z1), Vector3(xc, ya, Z1), Vector3(xc, ya, Z0), Vector3(xd, yb, Z0), dk(cc, 0.82))
		m.mat = wm
		m.tri(Vector3(X1, e, Z0), Vector3(X0, e, Z0), Vector3(Xm, R, Z0), wall)
		m.tri(Vector3(X0, e, Z1), Vector3(X1, e, Z1), Vector3(Xm, R, Z1), wall)
		m.mat = Mesher.M_NONE
		m.aabb(Xm - 0.06, R - 0.03, Z0, Xm + 0.06, R + 0.05, Z1, dk(col, 0.6))
	if not chimney:
		return
	var b: Array = w.buildings[bi]
	var hv := hash2(b[0], b[1])
	var px := X0 + (X1 - X0) * (0.25 + (hv % 40) / 100.0)
	var pz := Z0 + (Z1 - Z0) * (0.3 + (hv % 30) / 100.0)
	m.mat = Mesher.M_BRICK
	m.aabb(px - 0.2, e, pz - 0.2, px + 0.2, R + 0.45, pz + 0.2, c(0xE8D4C8), c(0x2A1A14))
	m.mat = Mesher.M_NONE

## Дверь: меш вокруг петли, лицом вдоль X
static func build_door(m: Mesher) -> void:
	m.clear()
	var wood := c(0xA0703E, 0)
	var d := c(0x6E4A2A, 0)
	m.box(Vector3(0.42, 0.97, 0), Vector3(0.84, 1.94, 0.06), wood)
	for z in [0.032, -0.032]:
		m.box(Vector3(0.42, 1.42, z), Vector3(0.6, 0.62, 0.01), d)
		m.box(Vector3(0.42, 0.52, z), Vector3(0.6, 0.62, 0.01), d)
	m.box(Vector3(0.72, 1.0, 0.05), Vector3(0.05, 0.05, 0.06), c(0xE0C050, 0))
	m.box(Vector3(0.72, 1.0, -0.05), Vector3(0.05, 0.05, 0.06), c(0xE0C050, 0))

# ================== ДОРОГИ-ЛИНИИ ==================
## Дорога — стопка «мазков» одной кривой, каждый уже и выше предыдущего: тротуар/обочина → бордюр → асфальт
## (у трассы ещё белая кромка и асфальт поверх). Мазок = прямоугольник на каждый кусок + клин на стыке кусков,
## поэтому на крутом повороте нет ни щелей, ни вывернутых треугольников, а где дорога ложится на дорогу
## (перекрёсток, петля, крутой поворот) — верхний асфальт сам закрывает чужие и свои тротуары (BF-057)
const LINE_SIDE_Y := 0.03      # тротуар / обочина линии
const LINE_CURB_Y := 0.035     # полоса бордюра
const LINE_SHOULDER_Y := 0.0375  # обочина трассы: выше тротуара и бордюра улицы (на въезде улицы на трассу
                                 # не мерцают вперемешку), но ниже асфальта — асфальт улицы идёт через обочину
const LINE_ROAD_Y := 0.04      # асфальт
const LINE_MARK_Y := 0.056     # разметка
const LINE_SELF_WIN := 25.0    # своя же дорога дальше этого по пути — как чужая (петля): разметку на ней не рисуем
const WEDGE_STEP := 0.26       # шаг дуги клина на стыке, рад (~15°)
const JUNC_PAD := 1.0          # перекрёсток: разметка обрывается на столько дальше края чужой дороги (м), там стоп-линия
const LINE_OVERLAP := 0.05     # мазок заходит на соседние куски на столько (м): швов между кусками нет вовсе

## Плоский четырёхугольник лицом вверх (порядок точек любой, по кругу)
static func _up_quad(m: Mesher, a: Vector2, b: Vector2, c: Vector2, d: Vector2, y: float, col: Color) -> void:
	_up_tri_q(m, a, b, c, y, col)
	_up_tri_q(m, a, c, d, y, col)

static func _up_tri_q(m: Mesher, a: Vector2, b: Vector2, cc: Vector2, y: float, col: Color) -> void:
	var A := Vector3(a.x, y, a.y)
	var B := Vector3(b.x, y, b.y)
	var C := Vector3(cc.x, y, cc.y)
	var cr := (B - A).cross(C - A).y
	if absf(cr) < 1e-9:
		return
	if cr > 0.0:
		m.tri(A, B, C, col)
	else:
		m.tri(A, C, B, col)

## Полоса вдоль куска между смещениями o1..o2 от оси (м, со знаком) — по нормали самого куска
static func _band(m: Mesher, r: Array, o1: float, o2: float, y: float, col: Color, ext := 0.0) -> void:
	var a: Vector2 = r[1]
	var b: Vector2 = r[2]
	var n: Vector2 = r[3]
	if ext > 0.0:
		var t := Vector2(n.y, -n.x) * signf((b - a).dot(Vector2(n.y, -n.x))) * ext
		a -= t
		b += t
	_up_quad(m, a + n * o1, a + n * o2, b + n * o2, b + n * o1, y, col)

## Мазок шириной 2·hw: прямоугольник куска (чуть заходит на соседей — LINE_OVERLAP) + клинья на стыке
## с предыдущим куском (с обеих сторон). Без нахлёста стыки кусков давали щели в долю пикселя, и сквозь все слои
## трассы точками светился светлый тротуар улицы под ней
static func _stroke(m: Mesher, r: Array, hw: float, y: float, col: Color, cap: Array = []) -> void:
	_band(m, r, -hw, hw, y, col, LINE_OVERLAP)
	if not cap.is_empty():
		# полукруг радиусом hw наружу от конца
		var pc: Vector2 = cap[0]
		var dir: Vector2 = cap[1]
		var nn := Vector2(-dir.y, dir.x) * hw
		var prev := pc + nn
		for k in range(1, 13):
			var cur := pc + nn.rotated(-PI * k / 12.0)
			_up_tri_q(m, pc, prev, cur, y, col)
			prev = cur
	var np = r[8]
	if np == null:
		return
	var a: Vector2 = r[1]
	var n: Vector2 = r[3]
	var ang := (np as Vector2).angle_to(n)
	if absf(ang) < 0.002:
		return
	var steps := maxi(1, ceili(absf(ang) / WEDGE_STEP))
	for sd in [1.0, -1.0]:
		var o: float = sd * hw
		var prev: Vector2 = a + (np as Vector2) * o
		for k in range(1, steps + 1):
			var cur: Vector2 = a + n * o if k == steps else a + (np as Vector2).rotated(ang * k / steps) * o
			_up_tri_q(m, a, prev, cur, y, col)
			prev = cur

## Полоса разметки o1..o2 с клином на стыке с предыдущим куском (на повороте без щелей); joint = false — без клина
static func _band_j(m: Mesher, r: Array, o1: float, o2: float, y: float, col: Color, joint := true) -> void:
	_band(m, r, o1, o2, y, col, LINE_OVERLAP)
	var np = r[8]
	if not joint or np == null:
		return
	var a: Vector2 = r[1]
	var n: Vector2 = r[3]
	if absf((np as Vector2).angle_to(n)) < 0.002:
		return
	if o1 * o2 >= 0.0:
		_up_quad(m, a + np * o1, a + np * o2, a + n * o2, a + n * o1, y, col)
	else:
		_up_tri_q(m, a, a + np * o1, a + n * o1, y, col)
		_up_tri_q(m, a, a + np * o2, a + n * o2, y, col)

## Разметка этой линии в точке (путь s, смещение от оси o) скрыта: внутри перекрёстка — ближе края чужой
## дороги + JUNC_PAD (по прямой через точку перекрёстка: смещение вдоль чужой оси учтено)
func _junc_hide(li: int, s: float, o: float) -> bool:
	for jn in w.line_junc.get(li, []):
		for side in 2:
			if jn[1 + side * 3] != li:
				continue
			var k: int = jn[4 - side * 3]
			var tl: Vector2 = jn[3 + side * 3]
			var tk: Vector2 = jn[6 - side * 3]
			var nl := Vector2(-tl.y, tl.x)
			var nk := Vector2(-tk.y, tk.x)
			var ds := s - float(jn[2 + side * 3])
			var d := ds * tl.dot(nk) + o * nl.dot(nk)
			if absf(d) >= float(GameWorld.LINE_OUTER_HW[w.lines[k][0]]) + JUNC_PAD:
				continue
			# чужая дорога есть в этом месте (на Т-перекрёстке её нет по ту сторону — там кромка не рвётся)
			var u := float(jn[5 - side * 3]) + ds * tl.dot(tk) + o * nl.dot(tk)
			if u > 0.0 and u < float(w.line_len[k]):
				return true
	return false

## Один кусок (~1 м) дороги-линии
func _line_seg(m: Mesher, r: Array) -> void:
	var kind: String = r[0]
	var hw: float = GameWorld.LINE_ROAD_HW[kind]
	var ow: float = GameWorld.LINE_OUTER_HW[kind]
	var a: Vector2 = r[1]
	var b: Vector2 = r[2]
	var n: Vector2 = r[3]
	var mid := (a + b) * 0.5
	var li: int = r[7]
	var s_mid: float = (float(r[5]) + float(r[6])) * 0.5
	# конец дороги, упёртый в другую дорогу (стык конец в конец разных видов, отворот), — круглый: квадратные
	# торцы двух дорог под углом давали зазор-«вырез» и наплыв (BF-061). Свободный конец — прямой
	var cap := []
	var t := (b - a).normalized()
	if float(r[5]) <= 0.0:
		var pe := a + t * 0.3
		if w.on_line_road(pe, li, false, 0.0, 0.0):
			cap = [pe, -t]
	elif float(r[6]) >= float(w.line_len[li]) - 1e-3:
		var pe := b - t * 0.3
		if w.on_line_road(pe, li, false, 0.0, float(r[6])):
			cap = [pe, t]
	if kind == "highway":
		m.mat = Mesher.M_ASPHALT
		_stroke(m, r, ow, LINE_SHOULDER_Y, c(0x5E5E58), cap)
		_stroke(m, r, hw, LINE_ROAD_Y, c(0x3C3D40), cap)
	else:
		m.mat = Mesher.M_CONCRETE
		_stroke(m, r, ow, LINE_SIDE_Y, c(0x9C9C96), cap)
		_stroke(m, r, hw + 0.18, LINE_CURB_Y, c(0x7C7C76), cap)
		m.mat = Mesher.M_ASPHALT
		_stroke(m, r, hw, LINE_ROAD_Y, c(0x3C3D40), cap)
	m.mat = Mesher.M_NONE
	if kind == "bridge":
		for side in [-1.0, 1.0]:
			_bridge_side(m, r, side, ow)
		_bridge_pillar(m, r, hw)
	var white := c(0xD8D8D0)
	# сплошные белые по краям трассы — обрываются там, где к трассе примыкает другая дорога
	if kind == "highway":
		for sd in [-1.0, 1.0]:
			var o: float = sd * (hw - 0.375)
			if not _junc_hide(li, s_mid, o) and not w.on_line_road(mid + n * o, li, false, 0.0, s_mid):
				_band_j(m, r, sd * (hw - 0.45), sd * (hw - 0.3), LINE_MARK_Y, white)
	# разметка по оси и полосам — не внутри перекрёстка, не на чужом асфальте и не на своём,
	# если дорога сюда вернулась петлёй
	if _junc_hide(li, s_mid, 0.0) or w.on_line_road(mid, li, false, 0.0, s_mid):
		return
	var yel := c(0xC8A83A)
	if kind == "street" or kind == "bridge":
		if fmod(s_mid, 3.0) < 1.5:
			_band_j(m, r, -0.06, 0.06, LINE_MARK_Y, yel, fmod(s_mid - 0.6, 3.0) < 1.5)
	else:
		_band_j(m, r, -0.25, -0.12, LINE_MARK_Y, yel)
		_band_j(m, r, 0.12, 0.25, LINE_MARK_Y, yel)
		if fmod(s_mid, 9.0) < 3.0:
			var jt := fmod(s_mid - 0.6, 9.0) < 3.0
			for sd in [-1.0, 1.0]:
				if not _junc_hide(li, s_mid, sd * 3.0):
					_band_j(m, r, sd * 2.93, sd * 3.07, LINE_MARK_Y, white, jt)

## Перекрёсток: на каждом подъезде каждой из двух дорог — «зебра» поперёк этой дороги (вдоль края чужой)
## и стоп-линия на встречной к перекрёстку половине (движение правостороннее)
func _junction(m: Mesher, jn: Array) -> void:
	m.mat = Mesher.M_NONE
	for side in 2:
		_junc_marks(m, jn[0], jn[1 + side * 3], jn[2 + side * 3], jn[3 + side * 3], jn[4 - side * 3], jn[6 - side * 3])

func _junc_marks(m: Mesher, p: Vector2, li: int, s: float, tl: Vector2, k: int, tk: Vector2) -> void:
	var nl := Vector2(-tl.y, tl.x)
	var nk := Vector2(-tk.y, tk.x)
	var cc := tl.dot(nk)
	var e := nl.dot(nk)
	if absf(cc) < GameWorld.JUNC_MIN_SIN:
		return
	var hwl: float = GameWorld.LINE_ROAD_HW[w.lines[li][0]]
	var hwk: float = GameWorld.LINE_ROAD_HW[w.lines[k][0]]
	var owk: float = GameWorld.LINE_OUTER_HW[w.lines[k][0]]
	var d0 := hwk + 0.5              # «зебра»: от края чужого асфальта…
	var d1 := owk + 0.6              # …до края её тротуара/обочины
	var st0 := owk + JUNC_PAD        # стоп-линия — там, где снова начинается разметка
	var st1 := st0 + 0.45
	var white := c(0xD8D8D0)
	var ln: float = w.line_len[li]
	for sg in [1.0, -1.0]:
		# подъезд должен быть: дорога продолжается за стоп-линию
		var far := (st1 + hwl * absf(e)) / absf(cc) + 0.5
		if s + sg * far > ln - 0.3 or s + sg * far < 0.3:
			continue
		var g: float = sg * signf(cc)
		var bw := -(hwl - 0.3)
		while bw + 0.45 <= hwl - 0.3 + 0.001:
			_junc_quad(m, p, tl, nl, cc, e, g, li, bw, bw + 0.45, d0, d1, white)
			bw += 0.9
		# стоп-линия на половине, что едет к перекрёстку: справа по ходу — это -sg · нормаль
		_junc_quad(m, p, tl, nl, cc, e, g, li, 0.0, -sg * (hwl - 0.2), st0, st1, white)

## Четырёхугольник разметки: смещения от оси этой дороги w0..w1, расстояния от оси чужой d0..d1.
## Рисуется, только если все углы на асфальте этой дороги (на изогнутой дороге не уходит на траву)
func _junc_quad(m: Mesher, p: Vector2, tl: Vector2, nl: Vector2, cc: float, e: float, g: float, li: int,
		w0: float, w1: float, d0: float, d1: float, col: Color) -> void:
	var q := []
	for wd in [[w0, d0], [w1, d0], [w1, d1], [w0, d1]]:
		var t: float = (wd[1] * g - wd[0] * e) / cc
		var pt: Vector2 = p + tl * t + nl * wd[0]
		if not w.on_line(pt, li, 0.02):
			return
		q.append(pt)
	_up_quad(m, q[0], q[1], q[2], q[3], LINE_MARK_Y, col)

# ================== ВОДА ==================
const WATER_Y := -0.6           # гладь воды ниже земли: виден берег, мост над ней
const BANK_Y := -0.9            # низ берега (под гладью)
const WATER_COL := 0x2E5866
const SHALLOW_COL := 0x4E8A84     # вода у берега (мелко)
const DEEP_COL := 0x1A4254        # вода вдали от берега (глубоко)
const SAND_COL := 0x8C7D5C        # откос берега
const FOAM_COL := 0x9EC6C0
const SLOPE_W := 0.45             # откос берега: на столько уходит в воду (до гладь − 0.1)

## Цвет воды по глубине (клеток до берега)
static func _depth_col(d: float) -> Color:
	var t := clampf((d - 0.5) / 4.0, 0.0, 1.0)
	return c(SHALLOW_COL).lerp(c(DEEP_COL), t * t * (3.0 - 2.0 * t))
const BANK_COL := 0x5A4C3C
const SHORE_SUB := 4            # клетка у берега делится на 4×4 — берег плавный (поле воды билинейное)

## Клетка у берега: вода (гладь) и земля (трава) по полю воды, между ними — стенка берега
func _shore(m: Mesher, x: int, y: int, wf: PackedFloat32Array) -> void:
	var hv := hash2(x, y)
	var gcol := jit(c([0x4C6A38, 0x50703C, 0x4A6636, 0x527039][hv % 4]), hv, 0.02)
	var dc := w.water_depth_corners(x, y)
	# наклон поля в углах (по соседним углам) — внутри клетки билинейно: у соседних клеток на общей стороне
	# направление то же, откос и пена без щелей
	var gc := []
	for q in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 1, y + 1), Vector2i(x, y + 1)]:
		gc.append(Vector2(w.water_corner(q.x + 1, q.y) - w.water_corner(q.x - 1, q.y), w.water_corner(q.x, q.y + 1) - w.water_corner(q.x, q.y - 1)))
	var st := 1.0 / SHORE_SUB
	for j in SHORE_SUB:
		for i in SHORE_SUB:
			var u0 := i * st
			var v0 := j * st
			var pts := [Vector2(u0, v0), Vector2(u0 + st, v0), Vector2(u0 + st, v0 + st), Vector2(u0, v0 + st)]
			var val := []
			for q in pts:
				val.append(GameWorld.bilerp(wf, q.x, q.y))
			# обход квадрата: углы и точки пересечения с уровнем 0.5
			var wet := PackedVector2Array()
			var dry := PackedVector2Array()
			var cut := []          # номера вершин в wet, которые — точки берега
			for k in 4:
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[(k + 1) % 4]
				var fa: float = val[k]
				var fb: float = val[(k + 1) % 4]
				if fa > 0.5:
					wet.append(a)
				else:
					dry.append(a)
				if (fa > 0.5) != (fb > 0.5):
					var tt := clampf((0.5 - fa) / (fb - fa), 0.0, 1.0)
					var q := a.lerp(b, tt)
					cut.append(wet.size())
					wet.append(q)
					dry.append(q)
			var o := Vector2(x, y)
			m.mat = Mesher.M_WATER
			_fan_depth(m, wet, o, dc)
			m.mat = Mesher.M_DIRT
			_fan(m, dry, o, 0.0, gcol)
			m.mat = Mesher.M_NONE
			# стенка берега между соседними точками берега, лицом к воде
			if cut.size() >= 2 and wet.size() >= 3:
				var cen := Vector2.ZERO
				for q in wet:
					cen += q
				cen /= wet.size()
				for k in range(0, cut.size() - 1, 2):
					var p1: Vector2 = wet[cut[k]]
					var p2: Vector2 = wet[cut[k + 1]]
					if p1.distance_squared_to(p2) > 1e-8:
						_bank_seg(m, o + p1, o + p2, 0.0, o + cen)
						# откос к воде и пена по кромке; направление в воду — по наклону поля (общее у соседних кусков)
						var g1 := _water_dir(gc, p1, cen)
						var g2 := _water_dir(gc, p2, cen)
						_slope(m, o + p1, o + p2, g1, g2)

## Направление в воду в точке клетки: наклон поля (из углов [лв, пв, пн, лн], билинейно)
static func _water_dir(gc: Array, p: Vector2, toward: Vector2) -> Vector2:
	var g: Vector2 = (gc[0] as Vector2).lerp(gc[1], p.x).lerp((gc[3] as Vector2).lerp(gc[2], p.x), p.y)
	if g.length_squared() < 1e-6:
		g = toward - p
	return g.normalized()

## Откос берега: от кромки суши (y 0) вниз под воду + полоска пены там, где откос входит в воду
static func _slope(m: Mesher, a: Vector2, b: Vector2, ga: Vector2, gb: Vector2) -> void:
	var y1 := WATER_Y - 0.1
	var A0 := Vector3(a.x, 0.0, a.y)
	var B0 := Vector3(b.x, 0.0, b.y)
	var A1 := Vector3(a.x + ga.x * SLOPE_W, y1, a.y + ga.y * SLOPE_W)
	var B1 := Vector3(b.x + gb.x * SLOPE_W, y1, b.y + gb.y * SLOPE_W)
	m.mat = Mesher.M_DIRT
	var sand := c(SAND_COL)
	if (B0 - A0).cross(A1 - A0).y > 0.0:
		m.quad(A0, B0, B1, A1, sand)
	else:
		m.quad(B0, A0, A1, B1, sand)
	# пена: от линии, где откос уходит под воду, чуть дальше в воду
	var k0 := SLOPE_W * WATER_Y / y1 - 0.04
	var k1 := k0 + 0.12
	var fa := a + ga * k0
	var fb := b + gb * k0
	var fa2 := a + ga * k1
	var fb2 := b + gb * k1
	m.mat = Mesher.M_FOAM
	_up_quad(m, fa, fb, fb2, fa2, WATER_Y + 0.004, c(FOAM_COL))
	m.mat = Mesher.M_NONE

## Гладь у берега: цвет в каждой вершине — по глубине (билинейно)
func _fan_depth(m: Mesher, poly: PackedVector2Array, o: Vector2, dc: PackedFloat32Array) -> void:
	for k in range(1, poly.size() - 1):
		var a := poly[0]
		var b := poly[k]
		var cc := poly[k + 1]
		if (b - a).cross(cc - a) == 0.0:
			continue
		var A := Vector3(o.x + a.x, WATER_Y, o.y + a.y)
		var B := Vector3(o.x + b.x, WATER_Y, o.y + b.y)
		var C := Vector3(o.x + cc.x, WATER_Y, o.y + cc.y)
		var ca := _depth_col(GameWorld.bilerp(dc, a.x, a.y))
		var cb := _depth_col(GameWorld.bilerp(dc, b.x, b.y))
		var ccol := _depth_col(GameWorld.bilerp(dc, cc.x, cc.y))
		if (B - A).cross(C - A).y < 0.0:
			m.tri3(A, C, B, ca, ccol, cb)
		else:
			m.tri3(A, B, C, ca, cb, ccol)

## Веер треугольников многоугольника (выпуклого) лицом вверх
static func _fan(m: Mesher, poly: PackedVector2Array, o: Vector2, y: float, col: Color) -> void:
	for k in range(1, poly.size() - 1):
		if (poly[k] - poly[0]).cross(poly[k + 1] - poly[0]) != 0.0:
			_up_tri(m, o + poly[0], o + poly[k], o + poly[k + 1], y, col)

static func _up_tri(m: Mesher, a: Vector2, b: Vector2, cc: Vector2, y: float, col: Color) -> void:
	var A := Vector3(a.x, y, a.y)
	var B := Vector3(b.x, y, b.y)
	var C := Vector3(cc.x, y, cc.y)
	if (B - A).cross(C - A).y < 0.0:
		m.tri(A, C, B, col)
	else:
		m.tri(A, B, C, col)

## Стенка берега по отрезку a–b от y_top вниз, лицом к точке toward (к воде)
static func _bank_seg(m: Mesher, a: Vector2, b: Vector2, y_top: float, toward: Vector2) -> void:
	_vface(m, a, b, y_top, BANK_Y, toward, c(BANK_COL), Mesher.M_DIRT)

# ---------- мост ----------
## Над водой ли край моста (клетка чуть снаружи настила — вода)
func _over_water(p: Vector2) -> bool:
	return w.inside(floori(p.x), floori(p.y)) and w.t(floori(p.x), floori(p.y)) == W.WATER

## Сторона моста над водой: перила (стойка на каждом куске, поручень) и бетонный край настила вниз к воде
func _bridge_side(m: Mesher, r: Array, side: float, ow: float) -> void:
	var a: Vector2 = r[1]
	var b: Vector2 = r[2]
	var na: Vector2 = r[3]
	var nb: Vector2 = r[3]
	var nm := na
	if not _over_water((a + b) * 0.5 + nm * side * (ow + 0.3)):
		return
	var rail := c(0xB8B8B0)
	var post := c(0x8C8C86)
	# край настила: стенка снаружи от тротуара вниз
	var pa := a + na * side * ow
	var pb := b + nb * side * ow
	_vface(m, pa, pb, LINE_SIDE_Y, -0.45, pa + na * side, c(0x8A8680), Mesher.M_CONCRETE)
	# поручень: верх и внутренняя сторона
	m.mat = Mesher.M_NONE
	_band(m, r, side * (ow - 0.14), side * (ow - 0.02), 1.0, rail)
	var ia := a + na * side * (ow - 0.14)
	var ib := b + nb * side * (ow - 0.14)
	_vface(m, ia, ib, 1.0, 0.86, a, rail, Mesher.M_NONE)
	var oa := a + na * side * (ow - 0.02)
	var ob := b + nb * side * (ow - 0.02)
	_vface(m, oa, ob, 1.0, 0.86, oa + na * side, rail, Mesher.M_NONE)
	# стойка в начале куска
	var sp := a + na * side * (ow - 0.08)
	m.identity()
	m.translate(Vector3(sp.x, LINE_SIDE_Y, sp.y))
	m.box(Vector3(0, 0.45, 0), Vector3(0.07, 0.9, 0.07), post)
	m.identity()

## Опора под мостом над водой — раз в 8 м пути
func _bridge_pillar(m: Mesher, r: Array, hw: float) -> void:
	var a: Vector2 = r[1]
	var b: Vector2 = r[2]
	if floori(float(r[5]) / 8.0) == floori(float(r[6]) / 8.0) or not _over_water(a):
		return
	var t := (b - a).normalized()
	m.identity()
	m.translate(Vector3(a.x, WATER_Y - 0.2, a.y))
	m.rot_y(rad_to_deg(atan2(t.x, t.y)))
	m.mat = Mesher.M_CONCRETE
	m.box(Vector3(0, 0.2, 0), Vector3((hw + 0.6) * 2.0, 0.4 + (-0.45 - WATER_Y), 0.8), c(0x8A8680))
	m.identity()
	m.mat = Mesher.M_NONE

## Вертикальная стенка по отрезку a–b от y0 до y1, лицом к точке toward
static func _vface(m: Mesher, a: Vector2, b: Vector2, y0: float, y1: float, toward: Vector2, col: Color, mat: int) -> void:
	var A0 := Vector3(a.x, y1, a.y)
	var B0 := Vector3(b.x, y1, b.y)
	var A1 := Vector3(a.x, y0, a.y)
	var B1 := Vector3(b.x, y0, b.y)
	var face := (B0 - A0).cross(A1 - A0)
	var mid := (a + b) * 0.5
	m.mat = mat
	if face.dot(Vector3(toward.x - mid.x, 0.0, toward.y - mid.y)) >= 0.0:
		m.quad(A0, B0, B1, A1, col)
	else:
		m.quad(B0, A0, A1, B1, col)
	m.mat = Mesher.M_NONE
