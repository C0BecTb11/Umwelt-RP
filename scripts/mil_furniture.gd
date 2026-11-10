class_name MilFurniture
extends RefCounted
## Мебель военной части (клетки GameWorld.BUNK … MAPBOARD). Модели — из ящиков и простых тел, как остальная
## мебель (world_mesh._furniture): начало координат — центр клетки на полу, +z — лицо (в комнату), -z — к стене.
## BACK — на сколько модель уходит назад от центра (её спинка встаёт вплотную к стене); FRONT — где её лицо.
## От них считаются сдвиг к стене и столкновение (GameWorld.FURN_FRONT = FRONT + BACK - 0.88) — меняешь модель,
## поправь числа здесь и в world.gd (проверка test_furniture_collision сверяет их с самой моделью).

const W = preload("res://scripts/world.gd")

const BACK := {W.BUNK: 0.46, W.FOOTLOCKER: 0.24, W.GUNRACK: 0.20, W.GUNSAFE: 0.27, W.AMMO: 0.34, W.MILLOCKER: 0.26,
	W.RADIO: 0.32, W.MAPTABLE: 0.44, W.FILECAB: 0.31, W.MILDESK: 0.36, W.GEARSHELF: 0.27, W.MAPBOARD: 0.07}

# армейская палитра
const OD := 0x4F5A34          # оливковый (краска)
const OD_D := 0x3B4428        # тёмный оливковый
const OD_L := 0x66713F        # светлый оливковый
const STEEL := 0x5E6660       # серая сталь
const STEEL_D := 0x3A403C
const BLACK := 0x18191B
const WOODC := 0x6B4A2A
const WOOD_D := 0x4A3320
const CANVAS := 0x7C7B52      # брезент
const STENCIL := 0xD8C860     # жёлтая маркировка
const PAPER := 0xE4DFC8

static func c(hex: int, k: float = 1.0) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255, int(round(k * 255.0)))

## Нарисовать мебель t. hv — «случайность» клетки; wide — модель на две клетки (койка, стол с картой): центр
## сдвинут на полклетки вправо, длина 1.9; иначе — короткая, в одну клетку
static func draw(m: Mesher, t: int, hv: int, wide: bool = false) -> void:
	match t:
		W.BUNK: _bunk(m, hv, wide)
		W.FOOTLOCKER: _footlocker(m, hv)
		W.GUNRACK: _gunrack(m, hv)
		W.GUNSAFE: _gunsafe(m)
		W.AMMO: _ammo(m, hv)
		W.MILLOCKER: _locker(m, hv)
		W.RADIO: _radio(m)
		W.MAPTABLE: _maptable(m, hv, wide)
		W.FILECAB: _filecab(m, hv)
		W.MILDESK: _desk(m, hv)
		W.GEARSHELF: _gearshelf(m, hv)
		W.MAPBOARD: _mapboard(m)

# ---------- двухъярусная койка ----------
static func _bunk(m: Mesher, hv: int, wide: bool) -> void:
	var L := 1.9 if wide else 0.92
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	var x1 := cx + L * 0.5
	var fr := c(OD_D)
	# четыре стойки и поперечины спинок
	for sx in [x0 + 0.025, x1 - 0.025]:
		for sz in [-0.43, 0.43]:
			m.box(Vector3(sx, 0.86, sz), Vector3(0.05, 1.72, 0.05), fr)
		for hy in [0.62, 0.78, 1.42, 1.58]:
			m.box(Vector3(sx, hy, 0), Vector3(0.03, 0.03, 0.82), fr)
	var blankets := [0x5C6440, 0x6A6C5E, 0x55603C]
	for tier in 2:
		var by := 0.34 + tier * 0.82
		# рама и сетка
		m.box(Vector3(cx, by, -0.43), Vector3(L - 0.04, 0.05, 0.04), fr)
		m.box(Vector3(cx, by, 0.43), Vector3(L - 0.04, 0.05, 0.04), fr)
		m.box(Vector3(cx, by - 0.01, 0), Vector3(L - 0.08, 0.02, 0.82), c(STEEL_D))
		# матрас в полоску, одеяло с отворотом, подушка
		m.box(Vector3(cx, by + 0.08, 0), Vector3(L - 0.1, 0.12, 0.8), c(0xCFC8AE))
		for s in int(L / 0.24):
			m.box(Vector3(x0 + 0.17 + s * 0.24, by + 0.081, 0), Vector3(0.03, 0.122, 0.802), c(0x8E97A6))
		var bl := c(blankets[(hv + tier * 2) % 3])
		var bx0 := x0 + L * 0.3
		m.box(Vector3((bx0 + x1 - 0.06) * 0.5, by + 0.155, 0), Vector3(x1 - 0.06 - bx0, 0.04, 0.84), bl)
		m.box(Vector3(bx0 + 0.07, by + 0.165, 0), Vector3(0.14, 0.045, 0.84), c(0xE8E6DC))
		var pl := minf(0.28, L * 0.2)                 # подушка — под головой, плечи лежат на матрасе (место лежащего — RestSpots)
		m.box(Vector3(x0 + 0.08 + pl * 0.5, by + 0.19, 0), Vector3(pl, 0.1, 0.5), c(0xF0EFE8))
	# лесенка на верхний ярус — у ног, с лица
	var lx := x1 - 0.2
	for dx in [-0.13, 0.13]:
		m.box(Vector3(lx + dx, 0.62, 0.455), Vector3(0.03, 1.2, 0.03), c(STEEL))
	for k in 3:
		m.box(Vector3(lx, 0.3 + k * 0.34, 0.455), Vector3(0.26, 0.03, 0.03), c(STEEL))

# ---------- армейский сундук ----------
static func _footlocker(m: Mesher, hv: int) -> void:
	var body := c(OD)
	m.box(Vector3(0, 0.17, 0), Vector3(0.84, 0.3, 0.44), body)
	m.box(Vector3(0, 0.36, 0), Vector3(0.86, 0.1, 0.46), c(OD_D))                  # крышка
	m.box(Vector3(0, 0.305, 0.232), Vector3(0.86, 0.02, 0.012), c(BLACK))          # щель под крышкой
	for sx in [-0.4, 0.4]:                                                        # стальные уголки
		m.box(Vector3(sx, 0.2, 0.2), Vector3(0.06, 0.4, 0.07), c(STEEL_D))
		m.box(Vector3(sx, 0.2, -0.2), Vector3(0.06, 0.4, 0.07), c(STEEL_D))
	for sx in [-0.22, 0.22]:                                                      # замки-защёлки
		m.box(Vector3(sx, 0.31, 0.236), Vector3(0.07, 0.1, 0.02), c(0xA8A690))
	for sx in [-0.435, 0.435]:                                                    # ручки по бокам
		m.box(Vector3(sx, 0.2, 0), Vector3(0.02, 0.04, 0.16), c(BLACK))
	# белая маркировка — «фамилия» владельца
	m.box(Vector3(0, 0.17, 0.222), Vector3(0.26 + (hv % 3) * 0.04, 0.05, 0.004), c(0xD8D8CC))
	m.box(Vector3(0, 0.09, 0.222), Vector3(0.14, 0.025, 0.004), c(0xD8D8CC))

# ---------- винтовка (для пирамиды): приклад внизу, ствол вверх ----------
static func _rifle(m: Mesher, wooden: bool) -> void:
	var st := c(WOODC if wooden else BLACK)
	m.box(Vector3(0, 0.14, 0), Vector3(0.045, 0.28, 0.09), st)                     # приклад
	m.box(Vector3(0, 0.4, 0.005), Vector3(0.05, 0.26, 0.08), c(BLACK))             # ствольная коробка
	m.box(Vector3(0, 0.37, 0.07), Vector3(0.035, 0.16, 0.05), c(0x242528))         # магазин
	m.box(Vector3(0, 0.34, -0.055), Vector3(0.03, 0.09, 0.04), c(BLACK))           # рукоятка
	m.box(Vector3(0, 0.66, 0), Vector3(0.05, 0.28, 0.055), st if wooden else c(0x2A2B2E))   # цевьё
	m.box(Vector3(0, 0.93, 0), Vector3(0.022, 0.28, 0.022), c(0x101112))           # ствол
	m.box(Vector3(0, 0.56, -0.045), Vector3(0.02, 0.1, 0.03), c(BLACK))            # ручка для переноски / прицел
	m.box(Vector3(0, 1.0, -0.02), Vector3(0.012, 0.05, 0.02), c(BLACK))            # мушка

# ---------- оружейная пирамида ----------
static func _gunrack(m: Mesher, hv: int) -> void:
	var wd := c(WOOD_D)
	m.box(Vector3(0, 0.06, 0), Vector3(0.94, 0.12, 0.38), wd)                      # основание с гнёздами
	m.box(Vector3(0, 0.125, 0.04), Vector3(0.86, 0.012, 0.2), c(BLACK))
	m.box(Vector3(0, 0.7, -0.18), Vector3(0.94, 1.4, 0.035), c(0x8C8F6A))          # задняя стенка — светлая, оружие на ней видно
	for sx in [-0.455, 0.455]:
		m.box(Vector3(sx, 0.7, -0.05), Vector3(0.03, 1.4, 0.28), wd)
	m.box(Vector3(0, 0.98, -0.08), Vector3(0.94, 0.06, 0.2), wd)                   # верхняя планка с вырезами
	m.box(Vector3(0, 1.385, -0.05), Vector3(0.94, 0.03, 0.28), wd)
	# запорная штанга с замком
	m.box(Vector3(0, 0.8, 0.045), Vector3(0.92, 0.025, 0.025), c(STEEL))
	m.box(Vector3(0.4, 0.78, 0.065), Vector3(0.06, 0.08, 0.03), c(0xB09A40))
	for k in 5:
		if k == (hv % 7):                                                         # одно гнездо бывает пустым
			continue
		m.push()
		m.translate(Vector3(-0.34 + k * 0.17, 0.13, 0.07))
		m.rot_x(-5)
		m.rot_y(90)                       # боком к комнате — виден силуэт
		_rifle(m, (hv >> (k + 3)) & 3 == 0)
		m.pop()

# ---------- оружейный шкаф (сейф) ----------
static func _gunsafe(m: Mesher) -> void:
	var body := c(0x566058)
	m.box(Vector3(0, 0.03, 0), Vector3(0.9, 0.06, 0.5), c(BLACK))                  # цоколь
	m.box(Vector3(0, 0.96, -0.01), Vector3(0.9, 1.8, 0.5), body)
	for sx in [-0.225, 0.225]:                                                    # две двери-панели
		m.box(Vector3(sx, 0.96, 0.245), Vector3(0.41, 1.68, 0.02), c(0x687468))
		m.box(Vector3(sx, 1.55, 0.257), Vector3(0.3, 0.012, 0.006), c(0x2C332C))
		m.box(Vector3(sx, 0.4, 0.257), Vector3(0.3, 0.012, 0.006), c(0x2C332C))
	for sy in [0.35, 0.96, 1.6]:                                                  # петли по краям
		m.box(Vector3(-0.44, sy, 0.25), Vector3(0.03, 0.12, 0.03), c(STEEL_D))
		m.box(Vector3(0.44, sy, 0.25), Vector3(0.03, 0.12, 0.03), c(STEEL_D))
	# штурвал-ручка и кодовый замок
	m.push()
	m.translate(Vector3(0.1, 1.0, 0.255))
	m.rot_x(90)
	m.tube(0.0, 0.025, 0.07, 0.07, c(0xB8B8B0), 10)
	m.pop()
	m.box(Vector3(0.1, 1.0, 0.285), Vector3(0.2, 0.025, 0.02), c(0xD0D0C8))
	m.box(Vector3(0.1, 1.0, 0.285), Vector3(0.025, 0.2, 0.02), c(0xD0D0C8))
	m.push()
	m.translate(Vector3(-0.1, 1.05, 0.255))
	m.rot_x(90)
	m.tube(0.0, 0.03, 0.045, 0.04, c(BLACK), 10)
	m.pop()
	# табличка «оружие» и жёлто-чёрная полоса
	m.box(Vector3(-0.225, 1.38, 0.257), Vector3(0.22, 0.09, 0.006), c(0xC02A22))
	m.box(Vector3(-0.225, 1.38, 0.259), Vector3(0.16, 0.02, 0.006), c(0xF0EEE4))
	for k in 8:
		m.box(Vector3(-0.385 + k * 0.11, 0.12, 0.242), Vector3(0.055, 0.05, 0.006), c(STENCIL if k % 2 == 0 else BLACK))

# ---------- деревянный ящик боеприпасов ----------
static func _crate(m: Mesher, sx: float, sy: float, sz: float, stripe: int) -> void:
	m.box(Vector3(0, sy * 0.5, 0), Vector3(sx, sy, sz), c(OD))
	m.box(Vector3(0, sy - 0.035, 0), Vector3(sx + 0.012, 0.02, sz + 0.012), c(OD_D))         # стык крышки
	for dx in [-sx * 0.32, sx * 0.32]:                                                      # планки-рёбра
		m.box(Vector3(dx, sy * 0.5, 0), Vector3(0.05, sy + 0.012, sz + 0.02), c(OD_L))
	for dz in [-sz * 0.5 - 0.012, sz * 0.5 + 0.012]:                                        # верёвочные ручки
		m.box(Vector3(0, sy * 0.55, dz), Vector3(0.16, 0.03, 0.02), c(0xB8A878))
	m.box(Vector3(0, sy * 0.52, sz * 0.5 + 0.003), Vector3(sx * 0.38, 0.045, 0.004), c(stripe))   # маркировка
	m.box(Vector3(0, sy * 0.3, sz * 0.5 + 0.003), Vector3(sx * 0.24, 0.025, 0.004), c(stripe))

# ---------- штабель ящиков с боеприпасами ----------
static func _ammo(m: Mesher, hv: int) -> void:
	for k in 2:
		m.push()
		m.translate(Vector3(-0.235 + k * 0.47, 0, -0.02))
		_crate(m, 0.44, 0.3, 0.6, STENCIL)
		m.pop()
	m.push()
	m.translate(Vector3(-0.1 + (hv % 3) * 0.05, 0.3, -0.04))
	m.rot_y(((hv >> 2) % 5 - 2) * 3.0)
	_crate(m, 0.6, 0.26, 0.42, 0xE8E4D0 if hv % 2 == 0 else STENCIL)
	m.pop()
	# металлические цинки (патронные коробки) сверху и рядом
	var cans := [Vector3(0.33, 0.3, 0.12), Vector3(0.33, 0.3, -0.14), Vector3(-0.12, 0.56, 0.0)]
	for k in cans.size():
		if k == 2 and hv % 3 == 0:
			continue
		var p: Vector3 = cans[k]
		m.box(p + Vector3(0, 0.09, 0), Vector3(0.14, 0.18, 0.24), c(OD_D))
		m.box(p + Vector3(0, 0.19, 0), Vector3(0.15, 0.02, 0.25), c(0x2C331E))
		m.box(p + Vector3(0, 0.215, 0), Vector3(0.03, 0.03, 0.14), c(BLACK))
		m.box(p + Vector3(0.071, 0.1, 0), Vector3(0.004, 0.05, 0.14), c(STENCIL))

# ---------- армейский шкаф на двоих ----------
static func _locker(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.46), c(STEEL_D))                # ножки-цоколь
	m.box(Vector3(0, 1.0, -0.01), Vector3(0.92, 1.8, 0.5), c(OD))
	for k in 2:
		var dx := -0.23 + k * 0.46
		m.box(Vector3(dx, 1.0, 0.243), Vector3(0.43, 1.72, 0.02), c(OD_L))         # дверца
		for s in 4:                                                               # жалюзи сверху и снизу
			m.box(Vector3(dx, 1.68 - s * 0.045, 0.255), Vector3(0.28, 0.015, 0.006), c(OD_D))
			m.box(Vector3(dx, 0.34 - s * 0.045, 0.255), Vector3(0.28, 0.015, 0.006), c(OD_D))
		m.box(Vector3(dx + (0.15 if k == 0 else -0.15), 1.05, 0.262), Vector3(0.03, 0.14, 0.03), c(0xB8B8B0))   # ручка
		m.box(Vector3(dx, 1.42, 0.255), Vector3(0.16, 0.05, 0.006), c(PAPER))      # бирка с фамилией
	m.box(Vector3(0, 1.0, 0.25), Vector3(0.015, 1.76, 0.02), c(OD_D))
	# сверху — каска или вещмешок
	if hv % 3 != 0:
		_helmet(m, Vector3(-0.2, 1.9, -0.02))
	if hv % 2 == 0:
		m.box(Vector3(0.2, 1.98, -0.03), Vector3(0.34, 0.16, 0.3), c(CANVAS))
		m.box(Vector3(0.2, 2.065, -0.03), Vector3(0.36, 0.02, 0.1), c(0x5A5A3C))

## Каска (верхняя половина эллипсоида с полями), низ — на высоте p.y
static func _helmet(m: Mesher, p: Vector3) -> void:
	m.ellipsoid(p + Vector3(0, 0.0, 0), Vector3(0.14, 0.15, 0.16), c(OD), 4, 10, 0.0, 0.5)
	m.push()
	m.translate(p)
	m.tube(0.0, 0.02, 0.155, 0.14, c(OD_D), 10, 1.0, 1.12)
	m.pop()

# ---------- стол связи с радиостанцией ----------
static func _table_frame(m: Mesher, x0: float, x1: float, z0: float, z1: float, h: float, top: Color, leg: Color) -> void:
	m.box(Vector3((x0 + x1) * 0.5, h - 0.025, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.05, z1 - z0), top)
	m.box(Vector3((x0 + x1) * 0.5, h - 0.09, (z0 + z1) * 0.5), Vector3(x1 - x0 - 0.08, 0.08, z1 - z0 - 0.08), leg)
	for lx in [x0 + 0.05, x1 - 0.05]:
		for lz in [z0 + 0.05, z1 - 0.05]:
			m.box(Vector3(lx, (h - 0.13) * 0.5, lz), Vector3(0.05, h - 0.13, 0.05), leg)

static func _radio(m: Mesher) -> void:
	_table_frame(m, -0.47, 0.47, -0.32, 0.3, 0.78, c(0x4A5046), c(STEEL_D))
	# радиостанция: корпус, шкала, ручки, динамик
	m.box(Vector3(-0.12, 0.96, -0.1), Vector3(0.56, 0.36, 0.34), c(OD_D))
	m.box(Vector3(-0.12, 0.96, 0.072), Vector3(0.52, 0.32, 0.012), c(0x2A3020))
	m.box(Vector3(-0.2, 1.05, 0.08), Vector3(0.22, 0.07, 0.008), c(0xD8E0B0))      # шкала частот
	m.box(Vector3(-0.17, 1.05, 0.085), Vector3(0.008, 0.07, 0.004), c(0xC03020))
	for k in 4:
		m.push()
		m.translate(Vector3(-0.3 + k * 0.085, 0.9, 0.078))
		m.rot_x(90)
		m.tube(0.0, 0.03, 0.026, 0.022, c(BLACK), 8)
		m.pop()
	for k in 5:                                                                   # решётка динамика
		m.box(Vector3(0.07, 0.88 + k * 0.04, 0.08), Vector3(0.12, 0.014, 0.006), c(BLACK))
	m.box(Vector3(0.07, 1.085, 0.08), Vector3(0.03, 0.03, 0.01), c(0x50D060, 0.5))   # лампочка питания
	for sx in [-0.39, 0.15]:                                                      # ручки для переноски
		m.box(Vector3(sx, 1.15, -0.1), Vector3(0.03, 0.03, 0.2), c(STEEL))
	m.box(Vector3(-0.34, 1.6, -0.22), Vector3(0.014, 0.92, 0.014), c(BLACK))       # антенна
	# блок питания, тангента на шнуре, наушники, журнал связи
	m.box(Vector3(0.32, 0.87, -0.14), Vector3(0.22, 0.18, 0.26), c(STEEL))
	m.box(Vector3(0.32, 0.87, -0.005), Vector3(0.14, 0.05, 0.01), c(BLACK))
	m.box(Vector3(0.3, 0.805, 0.14), Vector3(0.07, 0.05, 0.12), c(BLACK))
	m.box(Vector3(0.2, 0.79, 0.1), Vector3(0.14, 0.012, 0.012), c(BLACK))
	m.box(Vector3(-0.3, 0.8, 0.2), Vector3(0.07, 0.04, 0.07), c(BLACK))
	m.box(Vector3(-0.14, 0.8, 0.2), Vector3(0.07, 0.04, 0.07), c(BLACK))
	m.box(Vector3(-0.22, 0.83, 0.2), Vector3(0.16, 0.014, 0.03), c(STEEL_D))
	m.box(Vector3(0.05, 0.785, 0.19), Vector3(0.2, 0.012, 0.15), c(PAPER))
	m.box(Vector3(0.05, 0.793, 0.19), Vector3(0.012, 0.012, 0.15), c(0x3A5A8A))

# ---------- штабной стол с картой (на две клетки) ----------
static func _maptable(m: Mesher, hv: int, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	_table_frame(m, x0, x0 + L, -0.43, 0.43, 0.8, c(WOODC), c(WOOD_D))
	m.box(Vector3(cx, 0.2, 0), Vector3(L - 0.14, 0.04, 0.04), c(WOOD_D))           # проножка
	# карта: бумага, лес, река, дороги, квадраты
	var mw := L - 0.3
	var my := 0.803
	m.box(Vector3(cx, my, 0.0), Vector3(mw, 0.006, 0.7), c(0xD9D2AC))
	m.box(Vector3(cx - mw * 0.22, my + 0.004, -0.12), Vector3(mw * 0.3, 0.004, 0.3), c(0x9DB07A))
	m.box(Vector3(cx + mw * 0.28, my + 0.004, 0.16), Vector3(mw * 0.26, 0.004, 0.22), c(0x9DB07A))
	m.push()
	m.translate(Vector3(cx + mw * 0.05, my + 0.005, 0))
	m.rot_y(24)
	m.box(Vector3.ZERO, Vector3(0.05, 0.004, 0.74), c(0x6C9CC8))
	m.pop()
	m.push()
	m.translate(Vector3(cx, my + 0.006, 0.05))
	m.rot_y(-8)
	m.box(Vector3.ZERO, Vector3(mw * 0.96, 0.004, 0.018), c(0x8A6A4A))
	m.pop()
	for k in int(mw / 0.22):
		m.box(Vector3(cx - mw * 0.5 + 0.2 + k * 0.22, my + 0.0035, 0), Vector3(0.004, 0.003, 0.7), c(0xB0A888))
	# фишки подразделений: синие свои, красные — противник; стрелка удара
	var marks := [[-0.3, -0.18, 0x2A56A8], [-0.24, 0.06, 0x2A56A8], [-0.36, 0.2, 0x2A56A8], [0.22, -0.2, 0xB82A22], [0.32, 0.02, 0xB82A22]]
	for mk in marks:
		if absf(mk[0]) * 2.4 > mw * 0.5 and not wide:
			continue
		var mxp: float = cx + mk[0] * (2.4 if wide else 1.0)
		m.box(Vector3(mxp, my + 0.025, mk[1]), Vector3(0.07, 0.04, 0.045), c(mk[2]))
	m.push()
	m.translate(Vector3(cx - mw * 0.05, my + 0.008, -0.08))
	m.rot_y(-18)
	m.box(Vector3.ZERO, Vector3(mw * 0.32, 0.004, 0.03), c(0xC02A22))
	m.box(Vector3(mw * 0.16, 0, 0), Vector3(0.05, 0.004, 0.08), c(0xC02A22))
	m.pop()
	# по краям: линейка, карандаши, кружка, стопка папок, бинокль
	m.box(Vector3(x0 + 0.12, my + 0.005, 0.3), Vector3(0.05, 0.008, 0.2), c(0xE0C870))
	m.push()
	m.translate(Vector3(x0 + L - 0.12, 0.8, 0.3))
	m.tube(0.0, 0.09, 0.04, 0.04, c(0xE8E8E0), 8)
	m.pop()
	m.box(Vector3(x0 + L - 0.12, 0.89, 0.3), Vector3(0.05, 0.004, 0.05), c(0x3A2A1A))
	if wide:
		m.box(Vector3(x0 + L - 0.15, 0.825, -0.28), Vector3(0.2, 0.05, 0.26), c(0x8A7A4A))
		m.box(Vector3(x0 + L - 0.15, 0.86, -0.28), Vector3(0.19, 0.02, 0.25), c(0xB8A060))
		for dz in [-0.035, 0.035]:
			m.push()
			m.translate(Vector3(x0 + 0.14, 0.835, -0.3 + dz))
			m.rot_z(90)
			m.tube(-0.07, 0.07, 0.03, 0.024, c(BLACK), 8)
			m.pop()
	if hv % 2 == 0:
		m.box(Vector3(cx + 0.1, my + 0.012, 0.36), Vector3(0.16, 0.01, 0.012), c(0xC8A030))

# ---------- картотечные шкафы ----------
static func _filecab(m: Mesher, hv: int) -> void:
	for k in 2:
		var dx := -0.235 + k * 0.47
		var body := c(0x6C7468 if k == 0 else 0x626A5E)
		m.box(Vector3(dx, 0.66, -0.02), Vector3(0.45, 1.32, 0.58), body)
		for d in 4:
			var open := 0.06 if (hv >> (k * 2)) % 9 == d else 0.0                  # один ящик выдвинут
			var dy := 0.19 + d * 0.315
			m.box(Vector3(dx, dy, 0.275 + open * 0.5), Vector3(0.41, 0.28, 0.02 + open), c(0x7A8276))
			m.box(Vector3(dx, dy + 0.02, 0.295 + open), Vector3(0.14, 0.025, 0.02), c(0xC8C8C0))    # ручка
			m.box(Vector3(dx, dy + 0.085, 0.288 + open), Vector3(0.1, 0.045, 0.006), c(PAPER))      # ярлык
			if open > 0.0:
				m.box(Vector3(dx, dy + 0.13, 0.3), Vector3(0.36, 0.03, 0.07), c(0xC8B070))          # папки внутри
	# сверху: стопка папок и лоток с бумагами
	m.box(Vector3(-0.23, 1.36, -0.05), Vector3(0.3, 0.08, 0.36), c(0x8A7A4A))
	m.box(Vector3(-0.22, 1.42, -0.04), Vector3(0.3, 0.04, 0.36), c(0xB04030))
	m.box(Vector3(0.24, 1.34, -0.05), Vector3(0.32, 0.04, 0.4), c(STEEL_D))
	m.box(Vector3(0.24, 1.365, -0.05), Vector3(0.28, 0.02, 0.36), c(PAPER))

# ---------- стол дежурного ----------
static func _desk(m: Mesher, hv: int) -> void:
	var st := c(0x687064)
	m.box(Vector3(0, 0.765, -0.03), Vector3(0.94, 0.04, 0.66), c(0x3F4A3A))        # столешница — зелёный линолеум
	m.box(Vector3(0, 0.74, -0.03), Vector3(0.96, 0.02, 0.68), c(0xB8B8B0))         # стальная кромка
	m.box(Vector3(0.27, 0.37, -0.03), Vector3(0.38, 0.72, 0.62), st)               # тумба с ящиками
	for d in 3:
		m.box(Vector3(0.27, 0.16 + d * 0.23, 0.285), Vector3(0.34, 0.2, 0.012), c(0x788074))
		m.box(Vector3(0.27, 0.18 + d * 0.23, 0.298), Vector3(0.12, 0.022, 0.016), c(0xC8C8C0))
	m.box(Vector3(-0.44, 0.37, -0.03), Vector3(0.04, 0.72, 0.62), st)              # боковина
	m.box(Vector3(-0.08, 0.5, -0.33), Vector3(0.76, 0.44, 0.02), st)               # задняя панель
	# лампа на гибкой ножке
	m.push()
	m.translate(Vector3(-0.34, 0.785, -0.22))
	m.tube(0.0, 0.025, 0.07, 0.06, c(BLACK), 10)
	m.tube(0.025, 0.3, 0.012, 0.012, c(STEEL_D), 6)
	m.pop()
	m.push()
	m.translate(Vector3(-0.3, 1.1, -0.17))
	m.rot_x(38)
	m.rot_z(-20)
	m.tube(0.0, 0.13, 0.09, 0.035, c(0x2F5A3A), 10)
	m.pop()
	m.box(Vector3(-0.27, 1.085, -0.13), Vector3(0.07, 0.02, 0.07), c(0xFFF0B0, 0.5))
	# телефон с диском, журнал дежурств, планшет с бумагой, кружка
	m.box(Vector3(0.3, 0.82, -0.2), Vector3(0.2, 0.07, 0.16), c(BLACK))
	m.box(Vector3(0.3, 0.875, -0.2), Vector3(0.24, 0.04, 0.05), c(0x222326))
	m.push()
	m.translate(Vector3(0.3, 0.855, -0.14))
	m.tube(0.0, 0.008, 0.045, 0.045, c(0xD8D8D0), 10)
	m.pop()
	m.box(Vector3(-0.05, 0.795, 0.05), Vector3(0.3, 0.02, 0.22), c(0x7A2A22))
	m.box(Vector3(-0.05, 0.807, 0.05), Vector3(0.27, 0.006, 0.19), c(PAPER))
	for k in 4:
		m.box(Vector3(-0.05, 0.811, -0.01 + k * 0.04), Vector3(0.2, 0.002, 0.008), c(0x7A7A80))
	m.box(Vector3(0.14, 0.8, 0.2), Vector3(0.012, 0.012, 0.14), c(0xC8A030))
	if hv % 2 == 0:
		m.push()
		m.translate(Vector3(-0.3, 0.785, 0.16))
		m.tube(0.0, 0.085, 0.036, 0.036, c(OD), 8)
		m.pop()

# ---------- стеллаж со снаряжением ----------
static func _gearshelf(m: Mesher, hv: int) -> void:
	var fr := c(STEEL_D)
	for sx in [-0.45, 0.45]:
		for sz in [-0.24, 0.22]:
			m.box(Vector3(sx, 0.92, sz), Vector3(0.035, 1.84, 0.035), fr)
	for s in 4:
		m.box(Vector3(0, 0.1 + s * 0.52, -0.01), Vector3(0.9, 0.03, 0.48), c(STEEL))
	m.box(Vector3(0, 0.9, -0.255), Vector3(0.9, 0.02, 0.02), fr)
	# верхняя полка — каски в ряд
	for k in 3:
		if k == 1 and hv % 4 == 0:
			continue
		_helmet(m, Vector3(-0.28 + k * 0.28, 1.675, -0.01))
	# третья — вещмешки
	for k in 2:
		var px := -0.2 + k * 0.42
		m.box(Vector3(px, 1.31, -0.02), Vector3(0.34, 0.34, 0.34), c(CANVAS if k == 0 else 0x6E7048))
		m.box(Vector3(px, 1.4, 0.155), Vector3(0.3, 0.14, 0.02), c(0x5E6040))       # клапан
		for dx in [-0.08, 0.08]:
			m.box(Vector3(px + dx, 1.3, 0.158), Vector3(0.03, 0.3, 0.012), c(0x3E4028))   # ремни
	# вторая — свёрнутые одеяла и фляги
	for k in 2:
		m.push()
		m.translate(Vector3(-0.42, 0.72, -0.12 + k * 0.2))
		m.rot_z(-90)
		m.tube(0.0, 0.4, 0.085, 0.085, c(0x6A6C5E if k == 0 else 0x5C6440), 8)
		m.pop()
	for k in 3:
		m.push()
		m.translate(Vector3(0.12 + k * 0.13, 0.635, 0.02))
		m.tube(0.0, 0.16, 0.05, 0.05, c(OD), 8, 1.0, 0.7)
		m.tube(0.16, 0.2, 0.02, 0.02, c(BLACK), 6)
		m.pop()
	# нижняя — сапоги и ящик
	for k in 2:
		var bx := -0.33 + k * 0.2
		m.box(Vector3(bx, 0.26, -0.03), Vector3(0.1, 0.3, 0.12), c(BLACK))
		m.box(Vector3(bx, 0.15, 0.06), Vector3(0.1, 0.08, 0.28), c(BLACK))
	m.box(Vector3(0.2, 0.22, -0.02), Vector3(0.4, 0.2, 0.34), c(OD))
	m.box(Vector3(0.2, 0.22, 0.152), Vector3(0.18, 0.04, 0.004), c(STENCIL))

# ---------- стенд с тактической картой ----------
static func _mapboard(m: Mesher) -> void:
	var z := -0.03
	for sx in [-0.42, 0.42]:                                                      # ножки-стойки
		m.box(Vector3(sx, 0.45, z), Vector3(0.05, 0.9, 0.05), c(WOOD_D))
		m.box(Vector3(sx, 0.02, z + 0.03), Vector3(0.06, 0.04, 0.16), c(WOOD_D))
	m.box(Vector3(0, 1.38, z), Vector3(0.96, 1.02, 0.05), c(WOOD_D))               # рама
	m.box(Vector3(0, 1.38, z + 0.026), Vector3(0.88, 0.94, 0.006), c(0xD6CFA6))    # карта
	var zf := z + 0.031
	m.box(Vector3(-0.2, 1.52, zf), Vector3(0.36, 0.3, 0.004), c(0x9DB07A))         # лес
	m.box(Vector3(0.24, 1.14, zf), Vector3(0.3, 0.24, 0.004), c(0x9DB07A))
	m.push()
	m.translate(Vector3(0.06, 1.38, zf))
	m.rot_z(28)
	m.box(Vector3.ZERO, Vector3(0.05, 1.0, 0.004), c(0x6C9CC8))                    # река
	m.pop()
	for k in 3:                                                                   # сетка квадратов
		m.box(Vector3(-0.22 + k * 0.22, 1.38, zf - 0.001), Vector3(0.004, 0.94, 0.003), c(0xB0A888))
		m.box(Vector3(0, 1.14 + k * 0.24, zf - 0.001), Vector3(0.88, 0.004, 0.003), c(0xB0A888))
	# красные стрелки ударов и синие позиции
	for a in [[-0.16, 1.2, 35.0], [0.2, 1.5, -150.0]]:
		m.push()
		m.translate(Vector3(a[0], a[1], zf + 0.004))
		m.rot_z(a[2])
		m.box(Vector3.ZERO, Vector3(0.3, 0.03, 0.004), c(0xC02A22))
		m.box(Vector3(0.15, 0, 0), Vector3(0.05, 0.09, 0.004), c(0xC02A22))
		m.pop()
	for p in [[-0.3, 1.1], [-0.34, 1.3], [0.05, 1.05]]:
		m.box(Vector3(p[0], p[1], zf + 0.004), Vector3(0.09, 0.05, 0.004), c(0x2A56A8))
	for p in [[0.3, 1.66], [0.12, 1.72], [0.34, 1.42]]:
		m.box(Vector3(p[0], p[1], zf + 0.004), Vector3(0.09, 0.05, 0.004), c(0xB82A22))
	# приколотые листки и полка с указкой
	m.box(Vector3(-0.3, 1.74, zf + 0.004), Vector3(0.16, 0.12, 0.004), c(0xF0EEE4))
	m.box(Vector3(-0.3, 1.795, zf + 0.008), Vector3(0.02, 0.02, 0.008), c(0xC02A22))
	m.box(Vector3(0, 0.85, z + 0.05), Vector3(0.9, 0.025, 0.1), c(WOOD_D))
	m.box(Vector3(0.1, 0.875, z + 0.06), Vector3(0.5, 0.014, 0.014), c(0xE0C870))
