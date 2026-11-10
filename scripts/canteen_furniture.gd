class_name CanteenFurniture
extends RefCounted
## Мебель столовой (клетки GameWorld.DINETABLE … NOTICEBOARD) — в нейтральном стиле: светлый пластик, нержавейка,
## серо-голубые сиденья. Годится и для столовой части, и для полиции, и для больницы.
## Устроена как MilFurniture: начало координат — центр клетки на полу, +z — лицо (в комнату), -z — к стене.
## BACK — на сколько модель уходит назад от центра; FRONT (только сиденья) — на сколько вперёд: сиденье у стола
## разворачивается к нему лицом и задвигается под край на TUCK. Меняешь модель — поправь числа здесь и
## GameWorld.FURN_FRONT / SEAT_FRONT (проверка test_furniture_collision сверяет их с самой моделью).

const W = preload("res://scripts/world.gd")

const BACK := {W.DINETABLE: 0.44, W.CHAIR: 0.22, W.BENCH: 0.17, W.SERVELINE: 0.39, W.TRAYSTAND: 0.27, W.WATERCOOLER: 0.21,
	W.STEELTABLE: 0.35, W.SINK: 0.34, W.DISHRACK: 0.29, W.KITCHENETTE: 0.33, W.PLANT: 0.30, W.NOTICEBOARD: 0.07}
const FRONT := {W.CHAIR: 0.21, W.BENCH: 0.17}
const TUCK := {W.CHAIR: 0.10, W.BENCH: 0.02}

# нейтральная палитра
const TOP := 0xCFCBBE         # светлый пластик столешниц
const TOP_E := 0xA9A598       # кромка
const INOX := 0xB9BEC1        # нержавейка
const INOX_D := 0x858B90
const CHROME := 0xCDD1D4
const SEAT := 0x5F7F92        # серо-голубой пластик сидений
const SEAT_D := 0x4A6676
const WHITE := 0xECEBE5
const TRAY := 0x8F8478        # подносы
const DARK := 0x2B2D30
const BIRCH := 0xC9AE7C       # светлое дерево

static func c(hex: int, k: float = 1.0) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255, int(round(k * 255.0)))

## Нарисовать мебель t. hv — «случайность» клетки; wide — длинный вариант на две клетки (стол)
static func draw(m: Mesher, t: int, hv: int, wide: bool = false) -> void:
	match t:
		W.DINETABLE: _table(m, hv, wide)
		W.CHAIR: _chairs(m)
		W.BENCH: _bench(m)
		W.SERVELINE: _serveline(m, hv)
		W.TRAYSTAND: _traystand(m, hv)
		W.WATERCOOLER: _cooler(m)
		W.STEELTABLE: _steeltable(m, hv)
		W.SINK: _sink(m)
		W.DISHRACK: _dishrack(m, hv)
		W.KITCHENETTE: _kitchenette(m)
		W.PLANT: _plant(m, hv)
		W.NOTICEBOARD: _noticeboard(m, hv)

## Цилиндр (или усечённый конус) с низом в точке p
static func _cyl(m: Mesher, p: Vector3, h: float, r0: float, r1: float, col: Color, segs: int = 8) -> void:
	m.push()
	m.translate(p)
	m.tube(0.0, h, r0, r1, col, segs)
	m.pop()

## Поднос с едой: тарелка, кружка, прибор. p — центр подноса на столе
static func _meal(m: Mesher, p: Vector3, hv: int) -> void:
	m.box(p + Vector3(0, 0.008, 0), Vector3(0.4, 0.016, 0.28), c(TRAY))
	m.box(p + Vector3(0, 0.018, 0), Vector3(0.36, 0.006, 0.24), c(0xA59A8C))
	_cyl(m, p + Vector3(-0.06, 0.02, 0), 0.014, 0.1, 0.105, c(WHITE), 10)
	var food: int = [0xD9B24A, 0xB5523A, 0x86A455, 0xE3DCC4][hv % 4]
	m.ellipsoid(p + Vector3(-0.06, 0.034, 0), Vector3(0.07, 0.03, 0.07), c(food), 3, 8, 0.0, 0.5)
	_cyl(m, p + Vector3(0.13, 0.02, -0.07), 0.07, 0.032, 0.036, c(WHITE), 8)
	m.box(p + Vector3(0.13, 0.027, 0.06), Vector3(0.016, 0.006, 0.14), c(CHROME))

# ---------- обеденный стол ----------
static func _table(m: Mesher, hv: int, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	m.box(Vector3(cx, 0.755, 0), Vector3(L, 0.035, 0.86), c(TOP))                  # столешница
	m.box(Vector3(cx, 0.73, 0), Vector3(L - 0.02, 0.02, 0.84), c(TOP_E))           # кромка
	m.box(Vector3(cx, 0.69, 0), Vector3(L - 0.24, 0.06, 0.6), c(INOX_D))           # царга
	for lx in [x0 + 0.1, x0 + L - 0.1]:
		for lz in [-0.33, 0.33]:
			m.box(Vector3(lx, 0.345, lz), Vector3(0.04, 0.69, 0.04), c(INOX))
			m.box(Vector3(lx, 0.015, lz), Vector3(0.055, 0.03, 0.055), c(DARK))
	# посреди стола: салфетница, соль и перец
	var top := 0.7725
	m.box(Vector3(cx, top + 0.045, 0), Vector3(0.12, 0.09, 0.05), c(INOX))
	m.box(Vector3(cx, top + 0.1, 0), Vector3(0.1, 0.03, 0.02), c(WHITE))
	_cyl(m, Vector3(cx + 0.12, top, 0.03), 0.07, 0.02, 0.016, c(WHITE), 6)
	_cyl(m, Vector3(cx + 0.12, top, -0.04), 0.07, 0.02, 0.016, c(0x4A4038), 6)
	# подносы с едой — не у всех мест
	var seats: Array = [Vector3(cx - 0.47, top, 0.24), Vector3(cx + 0.47, top, -0.24), Vector3(cx + 0.47, top, 0.24), Vector3(cx - 0.47, top, -0.24)] if wide \
		else [Vector3(cx, top, 0.25), Vector3(cx, top, -0.25)]
	for k in seats.size():
		if (hv >> k) & 1 == 1 or (k == 0 and hv % 16 == 0):
			_meal(m, seats[k], hv + k)

# ---------- один стул: спинка со стороны -z ----------
static func _chair(m: Mesher, dx: float) -> void:
	for sx in [-0.17, 0.17]:
		m.box(Vector3(dx + sx, 0.22, 0.17), Vector3(0.025, 0.44, 0.025), c(CHROME))
		m.box(Vector3(dx + sx, 0.44, -0.185), Vector3(0.025, 0.88, 0.025), c(CHROME))    # задняя ножка — она же стойка спинки
	m.box(Vector3(dx, 0.3, 0.17), Vector3(0.34, 0.02, 0.02), c(CHROME))
	m.box(Vector3(dx, 0.46, 0), Vector3(0.4, 0.04, 0.4), c(SEAT))                   # сиденье
	m.box(Vector3(dx, 0.435, 0), Vector3(0.36, 0.02, 0.36), c(SEAT_D))
	m.box(Vector3(dx, 0.76, -0.2), Vector3(0.4, 0.24, 0.03), c(SEAT))               # спинка
	m.box(Vector3(dx, 0.76, -0.184), Vector3(0.3, 0.14, 0.004), c(SEAT_D))

static func _chairs(m: Mesher) -> void:
	_chair(m, -0.245)
	_chair(m, 0.245)

# ---------- скамья ----------
static func _bench(m: Mesher) -> void:
	for k in 3:
		m.box(Vector3(0, 0.45, -0.115 + k * 0.115), Vector3(1.0, 0.035, 0.1), c(BIRCH))
	m.box(Vector3(0, 0.41, 0), Vector3(0.94, 0.04, 0.05), c(INOX_D))
	for sx in [-0.36, 0.36]:
		m.box(Vector3(sx, 0.41, 0), Vector3(0.04, 0.04, 0.32), c(INOX_D))
		for sz in [-0.14, 0.14]:
			m.box(Vector3(sx, 0.2, sz), Vector3(0.035, 0.4, 0.035), c(INOX))
		m.box(Vector3(sx, 0.015, 0), Vector3(0.05, 0.03, 0.34), c(DARK))

# ---------- линия раздачи ----------
static func _serveline(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.05, -0.07), Vector3(1.0, 0.1, 0.54), c(DARK))                # цоколь
	m.box(Vector3(0, 0.47, -0.07), Vector3(1.0, 0.74, 0.6), c(INOX))
	m.box(Vector3(0, 0.5, 0.232), Vector3(1.0, 0.34, 0.008), c(SEAT))               # цветная полоса по лицу
	m.box(Vector3(0, 0.86, -0.07), Vector3(1.0, 0.04, 0.64), c(CHROME))             # верх
	# мармиты с едой
	var foods := [0xD9B24A, 0xB5523A, 0x86A455, 0xE3DCC4, 0x8A5A32]
	for k in 2:
		var px := -0.24 + k * 0.48
		m.box(Vector3(px, 0.883, -0.02), Vector3(0.42, 0.012, 0.34), c(INOX_D))
		m.box(Vector3(px, 0.89, -0.02), Vector3(0.37, 0.012, 0.29), c(foods[(hv + k * 3) % 5]))
		m.push()
		m.translate(Vector3(px + 0.1, 0.9, 0.02))
		m.rot_x(-35)
		m.rot_z(-20)
		m.box(Vector3(0, 0.09, 0), Vector3(0.016, 0.2, 0.016), c(DARK))             # ручка половника
		m.pop()
	# направляющие для подносов
	for k in 3:
		m.box(Vector3(0, 0.8, 0.29 + k * 0.07), Vector3(1.0, 0.022, 0.026), c(CHROME))
	for sx in [-0.4, 0.4]:
		m.box(Vector3(sx, 0.782, 0.335), Vector3(0.03, 0.03, 0.2), c(INOX_D))
	# защитное стекло на стойках и полка сверху
	for sx in [-0.487, 0.487]:
		m.box(Vector3(sx, 1.08, -0.25), Vector3(0.025, 0.42, 0.025), c(INOX_D))
	m.box(Vector3(0, 1.29, -0.22), Vector3(1.0, 0.02, 0.24), c(INOX))
	m.box(Vector3(0, 1.22, -0.1), Vector3(0.97, 0.14, 0.012), c(0xC6DDE4))        # стеклянный козырёк
	if hv % 2 == 0:                                                                # стопка тарелок на полке
		_cyl(m, Vector3(0.26, 1.3, -0.2), 0.1, 0.09, 0.09, c(WHITE), 10)
	else:
		for k in 3:
			_cyl(m, Vector3(-0.3 + k * 0.09, 1.3, -0.2), 0.08, 0.03, 0.034, c(WHITE), 8)

# ---------- стойка с подносами и приборами ----------
static func _traystand(m: Mesher, hv: int) -> void:
	for sx in [-0.43, 0.43]:
		for sz in [-0.23, 0.23]:
			m.box(Vector3(sx, 0.42, sz), Vector3(0.035, 0.84, 0.035), c(INOX))
	m.box(Vector3(0, 0.3, 0), Vector3(0.9, 0.03, 0.5), c(INOX_D))
	m.box(Vector3(0, 0.84, 0), Vector3(0.94, 0.035, 0.54), c(CHROME))
	# стопка подносов
	m.box(Vector3(-0.22, 0.96, 0), Vector3(0.42, 0.2, 0.32), c(TRAY))
	for k in 5:
		m.box(Vector3(-0.22, 0.88 + k * 0.04, 0), Vector3(0.425, 0.008, 0.325), c(0x6E655B))
	# лоток с приборами и салфетки
	m.box(Vector3(0.24, 0.9, -0.04), Vector3(0.38, 0.09, 0.3), c(INOX_D))
	for k in 3:
		m.box(Vector3(0.12 + k * 0.12, 0.948, -0.04), Vector3(0.1, 0.006, 0.26), c(DARK))
		for j in 3:
			m.push()
			m.translate(Vector3(0.1 + k * 0.12 + j * 0.02, 0.95, -0.1 + j * 0.05))
			m.rot_x(25 + j * 6)
			m.box(Vector3(0, 0.05, 0), Vector3(0.012, 0.14, 0.012), c(CHROME))
			m.pop()
	m.box(Vector3(0.24, 0.9, 0.19), Vector3(0.2, 0.09, 0.1), c(WHITE))
	# снизу: стопки тарелок и стаканы
	for k in 3:
		_cyl(m, Vector3(-0.28 + k * 0.24, 0.315, -0.02), 0.12 + ((hv >> k) % 3) * 0.05, 0.1, 0.1, c(WHITE), 10)
	for k in 4:
		_cyl(m, Vector3(-0.2 + k * 0.1, 0.315, 0.17), 0.09, 0.03, 0.036, c(0xBFD8E0), 6)

# ---------- кулер с водой и урна ----------
static func _cooler(m: Mesher) -> void:
	var bx := -0.2
	m.box(Vector3(bx, 0.48, 0), Vector3(0.34, 0.96, 0.34), c(WHITE))
	m.box(Vector3(bx, 0.03, 0), Vector3(0.36, 0.06, 0.36), c(0xB0B0AA))
	m.box(Vector3(bx, 0.7, 0.172), Vector3(0.24, 0.24, 0.008), c(0x8E9498))         # ниша с кранами
	m.box(Vector3(bx - 0.055, 0.76, 0.185), Vector3(0.035, 0.05, 0.03), c(0x3A6FC0))
	m.box(Vector3(bx + 0.055, 0.76, 0.185), Vector3(0.035, 0.05, 0.03), c(0xC0392B))
	m.box(Vector3(bx, 0.59, 0.2), Vector3(0.22, 0.02, 0.07), c(INOX_D))             # поддон
	_cyl(m, Vector3(bx, 0.96, 0), 0.05, 0.06, 0.13, c(0x9CCBEA), 10)                # бутыль горлом вниз
	_cyl(m, Vector3(bx, 1.01, 0), 0.26, 0.135, 0.135, c(0x9CCBEA), 10)
	m.ellipsoid(Vector3(bx, 1.27, 0), Vector3(0.135, 0.06, 0.135), c(0x8DBFE0), 3, 10, 0.0, 0.5)
	# держатель стаканчиков сбоку
	_cyl(m, Vector3(bx + 0.21, 0.6, 0.06), 0.32, 0.038, 0.038, c(0xD6E6EE), 8)
	m.box(Vector3(bx + 0.185, 0.76, 0.06), Vector3(0.03, 0.03, 0.03), c(INOX_D))
	# урна с педалью
	_cyl(m, Vector3(0.25, 0.0, 0.0), 0.5, 0.15, 0.17, c(0x8E9498), 12)
	_cyl(m, Vector3(0.25, 0.5, 0.0), 0.03, 0.178, 0.165, c(0x5A5F64), 12)
	m.box(Vector3(0.25, 0.02, 0.19), Vector3(0.1, 0.02, 0.06), c(DARK))

# ---------- стол из нержавейки ----------
static func _steeltable(m: Mesher, hv: int) -> void:
	for sx in [-0.45, 0.45]:
		for sz in [-0.3, 0.27]:
			m.box(Vector3(sx, 0.43, sz), Vector3(0.04, 0.86, 0.04), c(INOX))
	m.box(Vector3(0, 0.22, -0.015), Vector3(0.9, 0.03, 0.56), c(INOX_D))            # нижняя полка
	m.box(Vector3(0, 0.875, -0.015), Vector3(0.98, 0.04, 0.66), c(CHROME))          # столешница
	m.box(Vector3(0, 0.95, -0.335), Vector3(0.98, 0.14, 0.02), c(INOX))             # бортик
	# кастрюля с крышкой
	var px := -0.26
	_cyl(m, Vector3(px, 0.895, -0.08), 0.2, 0.14, 0.14, c(0x9AA0A4), 12)
	_cyl(m, Vector3(px, 1.095, -0.08), 0.02, 0.148, 0.12, c(INOX), 12)
	_cyl(m, Vector3(px, 1.115, -0.08), 0.03, 0.02, 0.02, c(DARK), 6)
	for sx in [-0.16, 0.16]:
		m.box(Vector3(px + sx, 1.04, -0.08), Vector3(0.05, 0.02, 0.07), c(DARK))
	# разделочная доска, нож, овощи
	m.box(Vector3(0.22, 0.908, 0.08), Vector3(0.36, 0.025, 0.26), c(BIRCH))
	m.box(Vector3(0.3, 0.925, 0.14), Vector3(0.16, 0.006, 0.03), c(CHROME))
	m.box(Vector3(0.17, 0.928, 0.14), Vector3(0.1, 0.016, 0.025), c(DARK))
	m.ellipsoid(Vector3(0.14, 0.955, 0.03), Vector3(0.04, 0.035, 0.04), c(0xC0392B), 3, 8)
	m.ellipsoid(Vector3(0.24, 0.95, 0.02), Vector3(0.035, 0.03, 0.035), c(0xC0392B), 3, 8)
	m.box(Vector3(0.33, 0.94, 0.04), Vector3(0.12, 0.035, 0.035), c(0x6E9A45))
	# на нижней полке — гастроёмкости и большая кастрюля
	m.box(Vector3(-0.2, 0.31, -0.02), Vector3(0.42, 0.15, 0.34), c(INOX))
	m.box(Vector3(-0.2, 0.39, -0.02), Vector3(0.44, 0.012, 0.36), c(CHROME))
	if hv % 3 != 0:
		_cyl(m, Vector3(0.24, 0.235, -0.02), 0.24, 0.15, 0.15, c(0x9AA0A4), 12)
		_cyl(m, Vector3(0.24, 0.475, -0.02), 0.012, 0.158, 0.158, c(INOX_D), 12)

# ---------- двойная мойка ----------
static func _sink(m: Mesher) -> void:
	for sx in [-0.45, 0.45]:
		for sz in [-0.29, 0.27]:
			m.box(Vector3(sx, 0.42, sz), Vector3(0.04, 0.84, 0.04), c(INOX))
	m.box(Vector3(0, 0.18, -0.01), Vector3(0.9, 0.025, 0.04), c(INOX_D))
	m.box(Vector3(0, 0.87, -0.01), Vector3(0.98, 0.05, 0.64), c(CHROME))            # столешница с чашами
	m.box(Vector3(0, 0.96, -0.32), Vector3(0.98, 0.16, 0.02), c(INOX))              # бортик
	for k in 2:
		var bx := -0.235 + k * 0.47
		m.box(Vector3(bx, 0.72, 0.0), Vector3(0.42, 0.26, 0.46), c(INOX))           # чаша снизу
		m.box(Vector3(bx, 0.896, 0.0), Vector3(0.38, 0.004, 0.42), c(0x6F767B))      # её дно сверху — темнее
		m.box(Vector3(bx, 0.899, 0.0), Vector3(0.05, 0.004, 0.05), c(DARK))          # слив
		_cyl(m, Vector3(bx, 0.38, 0.0), 0.21, 0.03, 0.03, c(0x70767A), 6)            # сифон
	# смеситель-«гусак» и два вентиля
	_cyl(m, Vector3(0, 0.895, -0.24), 0.3, 0.018, 0.018, c(CHROME), 8)
	m.box(Vector3(0, 1.195, -0.15), Vector3(0.03, 0.03, 0.2), c(CHROME))
	m.box(Vector3(0, 1.165, -0.06), Vector3(0.03, 0.06, 0.03), c(CHROME))
	m.box(Vector3(-0.09, 0.93, -0.24), Vector3(0.05, 0.03, 0.03), c(0x3A6FC0))
	m.box(Vector3(0.09, 0.93, -0.24), Vector3(0.05, 0.03, 0.03), c(0xC0392B))
	# мыло и губка
	_cyl(m, Vector3(0.4, 0.895, -0.24), 0.13, 0.03, 0.026, c(0x8FCF9A), 8)
	_cyl(m, Vector3(0.4, 1.025, -0.24), 0.03, 0.012, 0.012, c(WHITE), 6)
	m.box(Vector3(-0.4, 0.91, -0.24), Vector3(0.09, 0.03, 0.06), c(0xE8C84A))

# ---------- стеллаж-тележка для грязной посуды ----------
static func _dishrack(m: Mesher, hv: int) -> void:
	for sx in [-0.44, 0.44]:
		for sz in [-0.24, 0.24]:
			m.box(Vector3(sx, 0.93, sz), Vector3(0.03, 1.66, 0.03), c(INOX))
			m.push()
			m.translate(Vector3(sx, 0.05, sz))
			m.rot_z(90)
			m.tube(-0.015, 0.015, 0.05, 0.05, c(DARK), 8)
			m.pop()
	m.box(Vector3(0, 0.11, 0), Vector3(0.9, 0.03, 0.5), c(INOX_D))
	m.box(Vector3(0, 1.76, 0), Vector3(0.91, 0.03, 0.51), c(INOX_D))
	m.box(Vector3(0, 1.2, -0.255), Vector3(0.9, 0.02, 0.02), c(INOX_D))
	for lv in 6:
		var ly := 0.3 + lv * 0.24
		for sx in [-0.42, 0.42]:
			m.box(Vector3(sx, ly, 0), Vector3(0.03, 0.02, 0.5), c(INOX_D))          # направляющие
		if (hv >> lv) & 3 == 0 and lv != 2:
			continue                                                              # пустой уровень
		m.box(Vector3(0, ly + 0.018, 0), Vector3(0.84, 0.016, 0.46), c(TRAY))       # поднос
		match (hv + lv) % 3:
			0:
				_cyl(m, Vector3(-0.2, ly + 0.026, 0), 0.06 + (hv % 2) * 0.03, 0.1, 0.1, c(WHITE), 10)
				_cyl(m, Vector3(0.18, ly + 0.026, 0.04), 0.08, 0.032, 0.036, c(WHITE), 8)
			1:
				for k in 3:
					_cyl(m, Vector3(-0.24 + k * 0.2, ly + 0.026, -0.02), 0.085, 0.032, 0.038, c(0xBFD8E0), 6)
			2:
				_cyl(m, Vector3(-0.15, ly + 0.026, 0), 0.02, 0.1, 0.105, c(WHITE), 10)
				m.ellipsoid(Vector3(0.2, ly + 0.07, 0), Vector3(0.09, 0.05, 0.09), c(WHITE), 3, 8, 0.5, 1.0)
				m.box(Vector3(0.0, ly + 0.03, 0.14), Vector3(0.14, 0.006, 0.016), c(CHROME))
	m.box(Vector3(0, 1.84, 0), Vector3(0.6, 0.13, 0.38), c(0x8E9498))               # бак сверху

# ---------- тумба с микроволновкой, чайником и кофеваркой ----------
static func _kitchenette(m: Mesher) -> void:
	m.box(Vector3(0, 0.05, -0.04), Vector3(0.94, 0.1, 0.52), c(DARK))               # цоколь
	m.box(Vector3(0, 0.47, -0.04), Vector3(0.96, 0.74, 0.58), c(0xE2DFD5))
	for k in 2:
		var dx := -0.235 + k * 0.47
		m.box(Vector3(dx, 0.47, 0.254), Vector3(0.45, 0.68, 0.012), c(WHITE))       # дверца
		m.box(Vector3(dx + (0.17 if k == 0 else -0.17), 0.66, 0.266), Vector3(0.02, 0.14, 0.016), c(INOX_D))
	m.box(Vector3(0, 0.47, 0.257), Vector3(0.012, 0.68, 0.008), c(INOX_D))          # щель между дверцами
	m.box(Vector3(0, 0.86, -0.03), Vector3(1.0, 0.04, 0.64), c(0x55595C))           # столешница
	var top := 0.88
	# микроволновка
	m.box(Vector3(-0.22, top + 0.14, -0.1), Vector3(0.5, 0.28, 0.36), c(0xD6D6D0))
	m.box(Vector3(-0.27, top + 0.14, 0.083), Vector3(0.32, 0.2, 0.006), c(0x202326))
	m.box(Vector3(-0.045, top + 0.14, 0.083), Vector3(0.1, 0.22, 0.006), c(0xA4A8AA))
	m.box(Vector3(-0.045, top + 0.21, 0.087), Vector3(0.07, 0.04, 0.004), c(0x2C6E4A, 0.5))
	for k in 3:
		m.box(Vector3(-0.045, top + 0.14 - k * 0.04, 0.087), Vector3(0.06, 0.02, 0.004), c(0x5A5F64))
	m.box(Vector3(-0.11, top + 0.14, 0.092), Vector3(0.016, 0.2, 0.016), c(CHROME))
	# кофеварка с колбой
	m.box(Vector3(0.36, top + 0.16, -0.16), Vector3(0.2, 0.32, 0.2), c(DARK))
	m.box(Vector3(0.36, top + 0.015, -0.03), Vector3(0.2, 0.03, 0.18), c(DARK))
	_cyl(m, Vector3(0.36, top + 0.03, -0.02), 0.12, 0.07, 0.055, c(0x4A2E1C), 10)
	m.box(Vector3(0.44, top + 0.09, -0.02), Vector3(0.02, 0.08, 0.02), c(DARK))
	# чайник и кружки
	_cyl(m, Vector3(0.14, top, 0.12), 0.02, 0.085, 0.085, c(DARK), 10)
	_cyl(m, Vector3(0.14, top + 0.02, 0.12), 0.18, 0.075, 0.06, c(INOX), 10)
	_cyl(m, Vector3(0.14, top + 0.2, 0.12), 0.02, 0.045, 0.02, c(DARK), 8)
	m.box(Vector3(0.225, top + 0.12, 0.12), Vector3(0.025, 0.14, 0.03), c(DARK))
	for k in 2:
		_cyl(m, Vector3(0.34 + k * 0.09, top, 0.17), 0.085, 0.034, 0.036, c(WHITE if k == 0 else SEAT), 8)

# ---------- растение в кадке ----------
static func _plant(m: Mesher, hv: int) -> void:
	_cyl(m, Vector3.ZERO, 0.38, 0.16, 0.21, c(0xB9B4A8), 12)
	_cyl(m, Vector3(0, 0.38, 0), 0.035, 0.225, 0.225, c(0xA39E92), 12)
	_cyl(m, Vector3(0, 0.39, 0), 0.03, 0.19, 0.19, c(0x4A3626), 12)
	m.box(Vector3(0, 0.68, 0), Vector3(0.04, 0.54, 0.04), c(0x6A4A2C))
	m.push()
	m.translate(Vector3(0, 0.7, 0))
	m.rot_z(28)
	m.box(Vector3(0, 0.14, 0), Vector3(0.025, 0.28, 0.025), c(0x6A4A2C))
	m.pop()
	var greens := [0x3E7A3C, 0x4C8A44, 0x356B34, 0x5B9A4E]
	var blobs := [[0.0, 1.08, 0.0, 0.29, 0.25], [0.13, 1.34, 0.06, 0.2, 0.19], [-0.14, 1.28, -0.07, 0.2, 0.18], [0.02, 1.52, -0.02, 0.15, 0.14], [-0.16, 0.98, 0.1, 0.13, 0.12]]
	for k in blobs.size():
		var b: Array = blobs[k]
		m.ellipsoid(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[3]), c(greens[(hv + k) % 4]), 4, 8)

# ---------- доска объявлений ----------
static func _noticeboard(m: Mesher, hv: int) -> void:
	var z := -0.03
	for sx in [-0.46, 0.46]:
		m.box(Vector3(sx, 0.96, z), Vector3(0.035, 1.92, 0.035), c(INOX))
		m.box(Vector3(sx, 0.015, z + 0.02), Vector3(0.05, 0.03, 0.14), c(INOX_D))
	m.box(Vector3(0, 1.42, z), Vector3(0.96, 0.92, 0.04), c(INOX))                  # рама
	m.box(Vector3(0, 1.42, z + 0.021), Vector3(0.88, 0.84, 0.006), c(0xA98862))     # пробка
	var zf := z + 0.027
	m.box(Vector3(0, 1.79, zf), Vector3(0.88, 0.1, 0.004), c(SEAT))                 # шапка
	m.box(Vector3(0, 1.79, zf + 0.003), Vector3(0.44, 0.03, 0.003), c(WHITE))
	# листки: [x, y, ширина, высота, цвет, наклон]
	var papers := [[-0.27, 1.56, 0.26, 0.3, 0xF2F0E8, 0.0], [0.03, 1.6, 0.2, 0.22, 0xF2E9A8, 3.0], [0.29, 1.55, 0.22, 0.3, 0xF2F0E8, -2.0],
		[-0.3, 1.2, 0.18, 0.2, 0xBFD8E8, -4.0], [-0.05, 1.22, 0.26, 0.26, 0xF2F0E8, 0.0], [0.27, 1.19, 0.2, 0.18, 0xF0C4C0, 5.0]]
	for k in papers.size():
		if k == hv % 7:
			continue
		var pp: Array = papers[k]
		m.push()
		m.translate(Vector3(pp[0], pp[1], zf + 0.002))
		m.rot_z(pp[5])
		m.box(Vector3.ZERO, Vector3(pp[2], pp[3], 0.004), c(pp[4]))
		for ln in int(pp[3] / 0.05) - 1:
			m.box(Vector3(0, pp[3] * 0.5 - 0.07 - ln * 0.045, 0.003), Vector3(pp[2] * (0.75 if ln % 3 != 2 else 0.5), 0.008, 0.002), c(0x8A8E92))
		m.box(Vector3(0, pp[3] * 0.5 - 0.02, 0.006), Vector3(0.022, 0.022, 0.008), c([0xC0392B, 0x3A6FC0, 0xE8C84A][k % 3]))
		m.pop()
	# лоток для листовок под доской
	m.box(Vector3(0, 0.9, z + 0.05), Vector3(0.6, 0.12, 0.08), c(INOX_D))
	m.box(Vector3(0, 0.95, z + 0.05), Vector3(0.54, 0.1, 0.05), c(WHITE))
