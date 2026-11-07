class_name MapOverview
extends Node3D
## Редактор карты: вид сверху на всю карту (с 0.45). Когда редактор отдалён дальше 3D-вида, город целиком
## в 3D телефону не по силам (до 2500 кусков графики, BF-052) — вместо него плоская схема: клетки — цветные
## прямоугольники (подряд одинаковые в ряду — один), дороги-линии — полосы. Без света и теней.
## Схема строится полосами по BAND рядов: правка перестраивает только свою полосу; дороги — отдельным мешем.

const W = preload("res://scripts/world.gd")
const BAND := 10
const Y_TILES := 0.0
const Y_LINE_OUT := 0.05
const Y_LINE_ROAD := 0.1
const Y_LINE_MARK := 0.15

var w: GameWorld
var mat: StandardMaterial3D
var bands: Array = []              # MeshInstance3D на каждую полосу рядов
var band_dirty := PackedByteArray()
var lines_node: MeshInstance3D
var lines_dirty := true

## Цвет клетки на схеме
static func tile_col(t: int) -> Color:
	match t:
		W.GRASS: return Color8(86, 128, 62)
		W.ROAD: return Color8(60, 61, 64)
		W.SIDEWALK: return Color8(156, 156, 150)
		W.WOOD: return Color8(150, 112, 70)
		W.TILEFLOOR: return Color8(190, 184, 170)
		W.WALL: return Color8(120, 64, 52)
		W.DOOR, W.DOOR_OPEN: return Color8(200, 160, 90)
		W.WINDOW: return Color8(150, 190, 210)
		W.TREE: return Color8(40, 84, 40)
		W.CAR, W.CAR_V, W.CAR_TAIL: return Color8(170, 50, 50)
		W.WATER: return Color8(46, 88, 102)
	return Color8(120, 100, 80)        # мебель и прочее внутри домов

func setup(world: GameWorld) -> void:
	w = world
	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.disable_fog = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for b in ceili(float(w.h) / BAND):
		var n := MeshInstance3D.new()
		n.material_override = mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		bands.append(n)
	band_dirty.resize(bands.size())
	band_dirty.fill(1)
	lines_node = MeshInstance3D.new()
	lines_node.material_override = mat
	lines_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines_node)
	lines_dirty = true

## Клетки ряда y изменились
func mark_row(y: int) -> void:
	var b := y / BAND
	if b >= 0 and b < band_dirty.size():
		band_dirty[b] = 1

## Перестроить изменённое; за раз не больше max_bands полос (первый показ большой карты — за несколько кадров)
func refresh(max_bands: int = 1000) -> void:
	var n := 0
	for b in bands.size():
		if band_dirty[b] == 0:
			continue
		if n >= max_bands:
			break
		bands[b].mesh = _band_mesh(b)
		band_dirty[b] = 0
		n += 1
	if lines_dirty:
		lines_node.mesh = _lines_mesh()
		lines_dirty = false

## Всё перестроено
func ready_all() -> bool:
	return not lines_dirty and band_dirty.count(1) == 0

func _band_mesh(b: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for y in range(b * BAND, mini(w.h, (b + 1) * BAND)):
		var row := y * w.w
		var x0 := 0
		var t0 := w.tiles[row]
		for x in range(1, w.w + 1):
			var tx: int = w.tiles[row + x] if x < w.w else -1
			if tx == t0:
				continue
			_quad(v, c, Vector2(x0, y), Vector2(x, y), Vector2(x, y + 1), Vector2(x0, y + 1), Y_TILES, tile_col(t0))
			x0 = x
			t0 = tx
	return _commit(v, c)

func _lines_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	for e in w.lines:
		var path := GameWorld.line_path(e)
		if path.size() < 2:
			continue
		var kind: String = e[0]
		var hw: float = GameWorld.LINE_ROAD_HW[kind]
		var ow: float = GameWorld.LINE_OUTER_HW[kind]
		var out_c := Color8(94, 94, 88) if kind == "highway" else Color8(156, 156, 150)
		var road_c := Color8(110, 92, 70) if kind == "bridge" else Color8(60, 61, 64)
		_strip(v, c, path, ow, Y_LINE_OUT, out_c)
		_strip(v, c, path, hw, Y_LINE_ROAD, road_c)
		_strip(v, c, path, 0.25 if kind == "highway" else 0.12, Y_LINE_MARK, Color8(200, 168, 58))
	return _commit(v, c)

## Полоса шириной 2·hw вдоль пути; куски чуть заходят друг на друга — на изгибах без щелей
func _strip(v: PackedVector3Array, c: PackedColorArray, path: PackedVector2Array, hw: float, y: float, col: Color) -> void:
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var d := b - a
		var l := d.length()
		if l < 1e-4:
			continue
		var t := d / l
		var n := Vector2(-t.y, t.x) * hw
		var ext := t * minf(hw, 1.0) * 0.5
		_quad(v, c, a - ext + n, b + ext + n, b + ext - n, a - ext - n, y, col)

## Прямоугольник лицом вверх (точки по кругу, любой порядок обхода)
static func _quad(v: PackedVector3Array, c: PackedColorArray, a: Vector2, b: Vector2, cc: Vector2, d: Vector2, y: float, col: Color) -> void:
	var up := (b - a).cross(cc - a) < 0.0
	var A := Vector3(a.x, y, a.y)
	var B := Vector3(b.x, y, b.y)
	var C := Vector3(cc.x, y, cc.y)
	var D := Vector3(d.x, y, d.y)
	if up:
		v.append_array([A, B, C, A, C, D])
	else:
		v.append_array([A, C, B, A, D, C])
	for k in 6:
		c.append(col)

static func _commit(v: PackedVector3Array, c: PackedColorArray) -> ArrayMesh:
	if v.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
