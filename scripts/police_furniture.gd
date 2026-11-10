class_name PoliceFurniture
extends RefCounted
## Мебель полицейского участка (клетки GameWorld.FRONTDESK … PODIUM). Америка 1990-х: стальные столы, бежевые
## компьютеры с пузатыми мониторами, тёмно-синий цвет управления.
## Устроена как MilFurniture и CanteenFurniture: начало координат — центр клетки на полу, +z — лицо, -z — к стене.
## У столов «лицо» — сторона хозяина (где ящики и кресло). BACK — на сколько модель уходит назад от центра;
## FRONT и TUCK — для кресла (см. CanteenFurniture). Меняешь модель — поправь числа здесь и GameWorld.FURN_FRONT /
## SEAT_FRONT (проверка test_furniture_collision сверяет их с самой моделью).

const W = preload("res://scripts/world.gd")

const BACK := {W.FRONTDESK: 0.44, W.WANTEDBOARD: 0.07, W.PDESK: 0.44, W.OFFICECHAIR: 0.31, W.COPIER: 0.33, W.FAXSTAND: 0.29,
	W.EVIDENCESHELF: 0.27, W.CASEBOARD: 0.07, W.INTERROTABLE: 0.40, W.CELLBARS: 0.03, W.CELLDOOR: 0.05, W.CELLBUNK: 0.44,
	W.CELLTOILET: 0.35, W.RIOTRACK: 0.24, W.MUGSHOT: 0.03, W.BOOKING: 0.29, W.DISPATCH: 0.44, W.FLAGSTAND: 0.18,
	W.CHIEFDESK: 0.44, W.SOFA: 0.42, W.PAYPHONE: 0.15, W.BRIEFBOARD: 0.07, W.PODIUM: 0.25}
const FRONT := {W.OFFICECHAIR: 0.23}
const TUCK := {W.OFFICECHAIR: 0.14}

const NAVY := 0x1F2F4A        # тёмно-синий управления
const NAVY_L := 0x2E4468
const PUTTY := 0xD5CFBD       # бежевый пластик техники
const PUTTY_D := 0xB5AE9A
const STEEL := 0x8A9096
const STEEL_D := 0x5E646A
const CHROME := 0xCDD1D4
const INOX := 0xB9BEC1
const LAM := 0xB9A888         # светлая столешница
const WALNUT := 0x5A3B22
const WALNUT_D := 0x40291A
const GOLD := 0xC9A227
const BLACK := 0x1B1C1F
const PAPER := 0xECE8DA
const MANILA := 0xD9C58A
const CORK := 0xA98862
const RED := 0xB5302A
const FABRIC := 0x3A3F47
const LEATHER := 0x6A4836
const LEATHER_D := 0x4E3426
const BAR := 0x4A5058         # решётки

static func c(hex: int, k: float = 1.0) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255, int(round(k * 255.0)))

## Нарисовать мебель t. hv — «случайность» клетки; wide — длинный вариант на две клетки
static func draw(m: Mesher, t: int, hv: int, wide: bool = false) -> void:
	match t:
		W.FRONTDESK: _frontdesk(m, hv)
		W.WANTEDBOARD: _wanted(m, hv)
		W.PDESK: _pdesk(m, hv)
		W.OFFICECHAIR: _officechair(m)
		W.COPIER: _copier(m)
		W.FAXSTAND: _faxstand(m)
		W.EVIDENCESHELF: _evidence(m, hv)
		W.CASEBOARD: _caseboard(m, hv)
		W.INTERROTABLE: _interro(m, wide)
		W.CELLBARS: _bars(m)
		W.CELLDOOR: _celldoor(m)
		W.CELLBUNK: _cellbunk(m, hv, wide)
		W.CELLTOILET: _celltoilet(m)
		W.RIOTRACK: _riotrack(m)
		W.MUGSHOT: _mugshot(m)
		W.BOOKING: _booking(m)
		W.DISPATCH: _dispatch(m, hv)
		W.FLAGSTAND: _flag(m)
		W.CHIEFDESK: _chiefdesk(m, wide)
		W.SOFA: _sofa(m, wide)
		W.PAYPHONE: _payphone(m)
		W.BRIEFBOARD: _briefboard(m, hv)
		W.PODIUM: _podium(m)

# ================== общие детали ==================
static func _cyl(m: Mesher, p: Vector3, h: float, r0: float, r1: float, col: Color, segs: int = 8) -> void:
	m.push()
	m.translate(p)
	m.tube(0.0, h, r0, r1, col, segs)
	m.pop()

## Тонкая линия на вертикальной плоскости (доски): от a до b, z — глубина
static func _line(m: Mesher, a: Vector2, b: Vector2, z: float, col: Color, th: float = 0.008) -> void:
	var d := b - a
	m.push()
	m.translate(Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z))
	m.rot_z(rad_to_deg(atan2(d.y, d.x)))
	m.box(Vector3.ZERO, Vector3(d.length(), th, 0.003), col)
	m.pop()

## Монитор 90-х с клавиатурой. p — центр подставки на столе; экран смотрит на +z
static func _crt(m: Mesher, p: Vector3) -> void:
	m.box(p + Vector3(0, 0.02, 0), Vector3(0.24, 0.04, 0.24), c(PUTTY_D))
	m.box(p + Vector3(0, 0.2, -0.02), Vector3(0.38, 0.32, 0.36), c(PUTTY))
	m.box(p + Vector3(0, 0.2, -0.21), Vector3(0.28, 0.24, 0.04), c(PUTTY_D))       # «горб» кинескопа сзади
	m.box(p + Vector3(0, 0.21, 0.162), Vector3(0.3, 0.23, 0.006), c(0x16261E))     # экран
	for k in 4:
		m.box(p + Vector3(-0.05 + (k % 2) * 0.02, 0.29 - k * 0.045, 0.166), Vector3(0.16 - (k % 3) * 0.03, 0.012, 0.003), c(0x58D878, 0.5))
	m.box(p + Vector3(0.15, 0.065, 0.162), Vector3(0.02, 0.015, 0.006), c(0x50D060, 0.5))
	m.box(p + Vector3(0, 0.015, 0.3), Vector3(0.4, 0.03, 0.15), c(PUTTY))          # клавиатура
	m.box(p + Vector3(0, 0.032, 0.3), Vector3(0.36, 0.006, 0.11), c(PUTTY_D))

## Телефон с трубкой и кнопками. p — центр на столе
static func _phone(m: Mesher, p: Vector3) -> void:
	m.box(p + Vector3(0, 0.03, 0), Vector3(0.2, 0.06, 0.2), c(BLACK))
	m.box(p + Vector3(-0.065, 0.075, 0), Vector3(0.055, 0.035, 0.21), c(0x26282C))  # трубка
	m.box(p + Vector3(0.035, 0.062, 0.02), Vector3(0.09, 0.006, 0.11), c(0x9A9EA2)) # кнопки
	m.box(p + Vector3(0.035, 0.062, -0.065), Vector3(0.09, 0.006, 0.03), c(0xC03A30, 0.5))

## Лоток с бумагами в два яруса
static func _trays(m: Mesher, p: Vector3) -> void:
	for k in 2:
		m.box(p + Vector3(0, 0.01 + k * 0.075, 0), Vector3(0.24, 0.02, 0.32), c(BLACK))
		m.box(p + Vector3(0, 0.03 + k * 0.075, 0), Vector3(0.21, 0.02 + k * 0.01, 0.29), c(PAPER))
	for sx in [-0.115, 0.115]:
		m.box(p + Vector3(sx, 0.05, -0.12), Vector3(0.01, 0.1, 0.02), c(BLACK))

static func _mug(m: Mesher, p: Vector3, col: int) -> void:
	_cyl(m, p, 0.085, 0.034, 0.036, c(col), 8)
	_cyl(m, p + Vector3(0, 0.08, 0), 0.006, 0.028, 0.028, c(0x3A2414), 8)

## Рамка доски на стойках; возвращает z лицевой плоскости
static func _board(m: Mesher, frame: int, face: int) -> float:
	var z := -0.03
	for sx in [-0.46, 0.46]:
		m.box(Vector3(sx, 0.96, z), Vector3(0.035, 1.92, 0.035), c(frame))
		m.box(Vector3(sx, 0.015, z + 0.02), Vector3(0.05, 0.03, 0.14), c(frame))
	m.box(Vector3(0, 1.42, z), Vector3(0.96, 0.92, 0.04), c(frame))
	m.box(Vector3(0, 1.42, z + 0.021), Vector3(0.88, 0.84, 0.006), c(face))
	return z + 0.027

# ================== приёмная ==================
## Стойка дежурного: со стороны посетителей (-z) — высокая панель с полкой, с рабочей (+z) — стол
static func _frontdesk(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.575, -0.37), Vector3(1.0, 1.15, 0.08), c(NAVY))
	m.box(Vector3(0, 0.3, -0.412), Vector3(1.0, 0.06, 0.006), c(0xC9B36A))         # полоса понизу
	m.box(Vector3(0, 1.17, -0.33), Vector3(1.0, 0.04, 0.22), c(0x8A6A40))          # полка для посетителей
	m.box(Vector3(0, 0.76, 0.0), Vector3(1.0, 0.04, 0.62), c(LAM))                 # рабочая столешница
	m.box(Vector3(0, 0.735, 0.0), Vector3(1.0, 0.015, 0.6), c(STEEL_D))
	for sx in [-0.48, 0.48]:
		m.box(Vector3(sx, 0.37, -0.03), Vector3(0.04, 0.74, 0.6), c(NAVY))
	m.box(Vector3(0, 0.4, -0.2), Vector3(0.92, 0.03, 0.24), c(STEEL_D))            # полка под столом с папками
	for k in 4:
		m.box(Vector3(-0.3 + k * 0.09, 0.54, -0.2), Vector3(0.07, 0.26, 0.2), c([NAVY_L, 0x7A2A22, 0x2F5A3A, BLACK][(hv + k) % 4]))
	if hv % 2 == 0:                                                                # значок управления на панели
		m.box(Vector3(0, 0.78, -0.413), Vector3(0.18, 0.2, 0.006), c(GOLD))
		m.box(Vector3(0, 0.79, -0.417), Vector3(0.1, 0.1, 0.004), c(NAVY_L))
		m.box(Vector3(0, 0.67, -0.413), Vector3(0.1, 0.06, 0.006), c(GOLD))
	var top := 0.78
	match hv % 3:
		0:
			_phone(m, Vector3(-0.28, top, 0.0))
			m.box(Vector3(0.14, top + 0.01, 0.04), Vector3(0.44, 0.02, 0.3), c(0x2A3A5A))       # журнал посетителей
			m.box(Vector3(0.14, top + 0.022, 0.04), Vector3(0.4, 0.006, 0.27), c(PAPER))
			m.box(Vector3(0.14, top + 0.026, 0.04), Vector3(0.006, 0.004, 0.27), c(STEEL_D))
			for k in 5:
				m.box(Vector3(0.04, top + 0.027, -0.06 + k * 0.045), Vector3(0.15, 0.002, 0.008), c(0x5A5F70))
		1:
			_crt(m, Vector3(-0.08, top, -0.1))
			_mug(m, Vector3(0.36, top, 0.12), 0xECEBE5)
		2:
			_trays(m, Vector3(-0.3, top, -0.05))
			m.box(Vector3(0.16, top + 0.012, 0.04), Vector3(0.24, 0.024, 0.32), c(PAPER))       # стопка бланков
			m.box(Vector3(0.36, top + 0.01, 0.05), Vector3(0.012, 0.012, 0.15), c(NAVY))
	# на полке для посетителей — планшет с листом записи или звонок
	if hv % 2 == 1:
		m.box(Vector3(0.1, 1.2, -0.33), Vector3(0.22, 0.012, 0.16), c(0x6A4A2C))
		m.box(Vector3(0.1, 1.208, -0.33), Vector3(0.19, 0.006, 0.13), c(PAPER))
		m.box(Vector3(0.1, 1.214, -0.27), Vector3(0.08, 0.012, 0.02), c(CHROME))
	else:
		m.ellipsoid(Vector3(-0.2, 1.19, -0.33), Vector3(0.045, 0.04, 0.045), c(GOLD), 3, 8, 0.0, 0.5)
		_cyl(m, Vector3(-0.2, 1.225, -0.33), 0.015, 0.008, 0.008, c(BLACK), 6)

## Доска «Разыскиваются»
static func _wanted(m: Mesher, hv: int) -> void:
	var zf := _board(m, NAVY, 0xC8BFA4)
	m.box(Vector3(0, 1.79, zf), Vector3(0.88, 0.1, 0.004), c(RED))                 # шапка
	m.box(Vector3(0, 1.79, zf + 0.003), Vector3(0.5, 0.04, 0.003), c(PAPER))
	for k in 6:
		var px := -0.29 + (k % 3) * 0.29
		var py := 1.55 - (k / 3) * 0.37
		m.push()
		m.translate(Vector3(px, py, zf + 0.002))
		m.rot_z(((hv >> k) % 5 - 2) * 1.5)
		m.box(Vector3.ZERO, Vector3(0.24, 0.33, 0.004), c(0xEFE9D4))               # листовка
		m.box(Vector3(0, 0.125, 0.003), Vector3(0.19, 0.04, 0.002), c(BLACK))      # «WANTED»
		m.box(Vector3(0, 0.02, 0.003), Vector3(0.15, 0.15, 0.002), c(0x9A9A92))    # фото
		m.box(Vector3(0, 0.035, 0.005), Vector3(0.06, 0.07, 0.002), c(0x3A3632))   # голова
		m.box(Vector3(0, -0.035, 0.005), Vector3(0.12, 0.04, 0.002), c(0x3A3632))  # плечи
		for ln in 2:
			m.box(Vector3(0, -0.09 - ln * 0.03, 0.003), Vector3(0.18 - ln * 0.05, 0.012, 0.002), c(0x5A5650))
		m.box(Vector3(0, 0.155, 0.006), Vector3(0.02, 0.02, 0.008), c([RED, NAVY_L, GOLD][k % 3]))
		m.pop()

## Телефон-автомат на стойке
static func _payphone(m: Mesher) -> void:
	m.box(Vector3(0, 0.01, -0.02), Vector3(0.3, 0.02, 0.24), c(BLACK))
	m.box(Vector3(0, 0.52, -0.07), Vector3(0.07, 1.02, 0.07), c(0x3A3F45))
	m.box(Vector3(0, 1.4, -0.13), Vector3(0.44, 0.72, 0.02), c(0x3E5F8A))          # задняя стенка будки
	for sx in [-0.21, 0.21]:
		m.box(Vector3(sx, 1.4, -0.03), Vector3(0.02, 0.72, 0.2), c(0x3E5F8A))
	m.box(Vector3(0, 1.77, -0.03), Vector3(0.46, 0.03, 0.24), c(0x2E4A6E))
	m.box(Vector3(0, 1.7, 0.075), Vector3(0.4, 0.09, 0.01), c(0x2E4A6E))           # вывеска
	m.box(Vector3(0, 1.7, 0.082), Vector3(0.24, 0.035, 0.004), c(PAPER))
	m.box(Vector3(0.03, 1.36, -0.07), Vector3(0.24, 0.44, 0.1), c(0x26282C))       # аппарат
	m.box(Vector3(0.03, 1.48, -0.018), Vector3(0.2, 0.14, 0.006), c(CHROME))
	m.box(Vector3(0.09, 1.52, -0.013), Vector3(0.04, 0.012, 0.004), c(BLACK))      # щель для монет
	for k in 12:
		m.box(Vector3(-0.015 + (k % 3) * 0.045, 1.39 - (k / 3) * 0.04, -0.017), Vector3(0.03, 0.025, 0.006), c(0xC8CCD0))
	m.box(Vector3(0.09, 1.2, -0.017), Vector3(0.07, 0.05, 0.008), c(CHROME))       # возврат монет
	m.box(Vector3(-0.14, 1.38, -0.03), Vector3(0.05, 0.24, 0.05), c(BLACK))        # трубка на рычаге
	m.box(Vector3(-0.14, 1.48, -0.02), Vector3(0.06, 0.06, 0.07), c(BLACK))
	m.box(Vector3(-0.14, 1.28, -0.02), Vector3(0.06, 0.06, 0.07), c(BLACK))
	m.box(Vector3(-0.14, 1.12, -0.03), Vector3(0.012, 0.26, 0.012), c(CHROME))     # шнур
	m.box(Vector3(0, 1.06, -0.03), Vector3(0.42, 0.02, 0.2), c(0x3A3F45))          # полочка
	m.box(Vector3(0.05, 1.02, -0.03), Vector3(0.22, 0.05, 0.15), c(0xD8C050))      # телефонная книга

## Диван (на две клетки) или кресло (одна)
static func _sofa(m: Mesher, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	for lx in [x0 + 0.08, x0 + L - 0.08]:
		for lz in [-0.34, 0.3]:
			m.box(Vector3(lx, 0.04, lz), Vector3(0.06, 0.08, 0.06), c(BLACK))
	m.box(Vector3(cx, 0.2, -0.02), Vector3(L, 0.24, 0.8), c(LEATHER_D))
	m.box(Vector3(cx, 0.6, -0.32), Vector3(L - 0.3, 0.56, 0.18), c(LEATHER_D))     # спинка
	var n := 2 if wide else 1
	var cw := (L - 0.38) / n
	for k in n:
		var sx := x0 + 0.19 + cw * (k + 0.5)
		m.box(Vector3(sx, 0.39, 0.07), Vector3(cw - 0.02, 0.14, 0.6), c(LEATHER))               # подушка сиденья
		m.box(Vector3(sx, 0.68, -0.2), Vector3(cw - 0.03, 0.4, 0.1), c(LEATHER))                # подушка спинки
		for b in 3:
			m.box(Vector3(sx - cw * 0.28 + b * cw * 0.28, 0.72, -0.148), Vector3(0.025, 0.025, 0.006), c(LEATHER_D))
	for ax in [x0 + 0.09, x0 + L - 0.09]:
		m.box(Vector3(ax, 0.37, -0.02), Vector3(0.18, 0.5, 0.8), c(LEATHER_D))                  # подлокотник
		m.box(Vector3(ax, 0.64, -0.02), Vector3(0.2, 0.06, 0.8), c(LEATHER))

## Флаг США на стойке
static func _flag(m: Mesher) -> void:
	_cyl(m, Vector3.ZERO, 0.05, 0.17, 0.15, c(GOLD), 12)
	_cyl(m, Vector3(0, 0.05, 0), 0.06, 0.06, 0.035, c(GOLD), 10)
	_cyl(m, Vector3(0, 0.1, 0), 2.05, 0.016, 0.016, c(0x6A4A2C), 8)
	m.ellipsoid(Vector3(0, 2.19, 0), Vector3(0.04, 0.05, 0.04), c(GOLD), 4, 8)
	_cyl(m, Vector3(0, 2.23, 0), 0.09, 0.02, 0.002, c(GOLD), 6)
	# полотнище висит складками: полосы веером от древка
	for i in 7:
		m.push()
		m.translate(Vector3(0.025 + i * 0.03, 2.1, 0.02 + (i % 2) * 0.014))
		m.rot_z(2.0 + i * 1.6)
		var h := 1.0 - i * 0.035
		m.box(Vector3(0, -h * 0.5, 0), Vector3(0.045, h, 0.03), c(0xB22234 if i % 2 == 0 else 0xECEBE5))
		m.pop()
	m.push()                                                                      # синий крыж со звёздами
	m.translate(Vector3(0.02, 2.1, 0.05))
	m.rot_z(4.0)
	m.box(Vector3(0.07, -0.2, 0), Vector3(0.16, 0.4, 0.012), c(0x24386A))
	for k in 8:
		m.box(Vector3(0.035 + (k % 2) * 0.07 + ((k / 2) % 2) * 0.012, -0.05 - (k / 2) * 0.09, 0.008), Vector3(0.022, 0.022, 0.004), c(0xECEBE5))
	m.pop()
	m.box(Vector3(-0.03, 1.9, 0.03), Vector3(0.012, 0.36, 0.012), c(GOLD))         # шнур с кистью
	m.box(Vector3(-0.03, 1.69, 0.03), Vector3(0.03, 0.08, 0.03), c(GOLD))

# ================== кабинеты ==================
## Рабочий стол полицейского: стальной, с компьютером или пишущей машинкой
static func _pdesk(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.76, -0.01), Vector3(0.98, 0.04, 0.86), c(LAM))
	m.box(Vector3(0, 0.735, -0.01), Vector3(0.96, 0.015, 0.84), c(STEEL_D))
	m.box(Vector3(0.29, 0.37, -0.01), Vector3(0.36, 0.72, 0.8), c(STEEL))          # тумба
	for d in 3:
		m.box(Vector3(0.29, 0.14 + d * 0.22, 0.393), Vector3(0.32, 0.19, 0.012), c(0x9AA0A6))
		m.box(Vector3(0.29, 0.2 + d * 0.22, 0.404), Vector3(0.12, 0.02, 0.014), c(CHROME))
	m.box(Vector3(-0.46, 0.37, -0.01), Vector3(0.04, 0.72, 0.8), c(STEEL))
	m.box(Vector3(-0.09, 0.45, -0.42), Vector3(0.74, 0.5, 0.02), c(STEEL))         # задняя панель
	var top := 0.78
	if hv % 3 == 0:
		# пишущая машинка с листом
		m.box(Vector3(-0.08, top + 0.05, 0.02), Vector3(0.38, 0.1, 0.34), c(0x3F5A5A))
		for k in 3:
			m.box(Vector3(-0.08, top + 0.105 - k * 0.012, 0.1 + k * 0.035), Vector3(0.3, 0.012, 0.028), c(BLACK))
		m.push()
		m.translate(Vector3(-0.28, top + 0.13, -0.12))
		m.rot_z(-90)
		m.tube(0.0, 0.4, 0.03, 0.03, c(BLACK), 8)
		m.pop()
		m.push()
		m.translate(Vector3(-0.08, top + 0.13, -0.14))
		m.rot_x(-12)
		m.box(Vector3(0, 0.11, 0), Vector3(0.22, 0.22, 0.004), c(PAPER))
		for ln in 3:
			m.box(Vector3(-0.01, 0.06 + ln * 0.03, 0.003), Vector3(0.16, 0.006, 0.002), c(0x5A5F70))
		m.pop()
	else:
		_crt(m, Vector3(-0.08, top, -0.14))
	_trays(m, Vector3(0.33, top, -0.2))
	_phone(m, Vector3(0.33, top, 0.2))
	_mug(m, Vector3(-0.4, top, 0.22), [0xECEBE5, NAVY, 0x7A2A22][hv % 3])
	# настольная лампа
	_cyl(m, Vector3(-0.38, top, -0.32), 0.02, 0.06, 0.05, c(BLACK), 8)
	_cyl(m, Vector3(-0.38, top + 0.02, -0.32), 0.3, 0.01, 0.01, c(STEEL_D), 6)
	m.box(Vector3(-0.33, top + 0.33, -0.3), Vector3(0.2, 0.04, 0.1), c(BLACK))
	m.box(Vector3(-0.33, top + 0.307, -0.3), Vector3(0.16, 0.008, 0.07), c(0xFFF0B0, 0.5))

## Офисное кресло на колёсиках: спинка со стороны -z
static func _officechair(m: Mesher) -> void:
	for k in 5:
		m.push()
		m.rot_y(k * 72.0 + 18.0)
		m.box(Vector3(0, 0.065, 0.13), Vector3(0.04, 0.03, 0.26), c(BLACK))
		m.box(Vector3(0, 0.025, 0.25), Vector3(0.045, 0.05, 0.05), c(0x101012))
		m.pop()
	_cyl(m, Vector3(0, 0.06, 0), 0.36, 0.03, 0.024, c(CHROME), 8)
	m.box(Vector3(0, 0.44, 0), Vector3(0.3, 0.04, 0.3), c(BLACK))
	m.box(Vector3(0, 0.5, 0.01), Vector3(0.46, 0.09, 0.44), c(FABRIC))             # сиденье
	m.push()
	m.translate(Vector3(0, 0.56, -0.2))
	m.rot_x(-8)
	m.box(Vector3(0, 0.3, 0), Vector3(0.42, 0.5, 0.07), c(FABRIC))                 # спинка
	m.box(Vector3(0, 0.3, 0.037), Vector3(0.34, 0.4, 0.004), c(0x464C55))
	m.box(Vector3(0, 0.0, 0.0), Vector3(0.06, 0.14, 0.04), c(BLACK))
	m.pop()
	for sx in [-0.25, 0.25]:
		m.box(Vector3(sx, 0.6, 0.0), Vector3(0.03, 0.16, 0.03), c(BLACK))
		m.box(Vector3(sx, 0.69, 0.02), Vector3(0.05, 0.03, 0.26), c(BLACK))

## Стол начальника: большой, деревянный (на две клетки)
static func _chiefdesk(m: Mesher, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	var x1 := x0 + L
	m.box(Vector3(cx, 0.77, -0.01), Vector3(L, 0.05, 0.86), c(WALNUT))
	m.box(Vector3(cx, 0.74, -0.01), Vector3(L - 0.04, 0.02, 0.82), c(WALNUT_D))
	var peds := [x0 + 0.23, x1 - 0.23] if wide else [x1 - 0.23]
	for px in peds:
		m.box(Vector3(px, 0.365, -0.01), Vector3(0.42, 0.73, 0.8), c(WALNUT_D))
		for d in 3:
			m.box(Vector3(px, 0.14 + d * 0.22, 0.393), Vector3(0.37, 0.19, 0.012), c(WALNUT))
			m.box(Vector3(px, 0.14 + d * 0.22, 0.404), Vector3(0.04, 0.03, 0.014), c(GOLD))
	if not wide:
		m.box(Vector3(x0 + 0.03, 0.365, -0.01), Vector3(0.05, 0.73, 0.8), c(WALNUT_D))
	m.box(Vector3(cx, 0.43, -0.41), Vector3(L - 0.06, 0.62, 0.03), c(WALNUT_D))    # передняя панель (к посетителю)
	var pn := 3 if wide else 2
	for k in pn:
		var pw := (L - 0.2) / pn
		m.box(Vector3(x0 + 0.1 + pw * (k + 0.5), 0.43, -0.428), Vector3(pw - 0.06, 0.46, 0.008), c(WALNUT))
	var top := 0.795
	# кожаная подкладка с бумагой и ручкой
	m.box(Vector3(cx, top + 0.004, 0.14), Vector3(0.52, 0.008, 0.38), c(0x24402E))
	m.box(Vector3(cx - 0.04, top + 0.01, 0.14), Vector3(0.22, 0.004, 0.3), c(PAPER))
	m.box(Vector3(cx + 0.14, top + 0.014, 0.14), Vector3(0.012, 0.012, 0.15), c(GOLD))
	# табличка с именем — к посетителю
	m.box(Vector3(cx, top + 0.035, -0.36), Vector3(0.32, 0.07, 0.05), c(WALNUT_D))
	m.box(Vector3(cx, top + 0.035, -0.387), Vector3(0.26, 0.04, 0.006), c(GOLD))
	# лампа с зелёным плафоном
	var lx := x0 + 0.28
	m.box(Vector3(lx, top + 0.012, -0.2), Vector3(0.16, 0.024, 0.1), c(GOLD))
	_cyl(m, Vector3(lx, top + 0.024, -0.2), 0.24, 0.012, 0.012, c(GOLD), 6)
	m.box(Vector3(lx, top + 0.29, -0.18), Vector3(0.28, 0.07, 0.12), c(0x2F7A4E))
	m.box(Vector3(lx, top + 0.252, -0.18), Vector3(0.24, 0.008, 0.09), c(0xFFF0B0, 0.5))
	_phone(m, Vector3(x1 - 0.28, top, -0.12))
	if wide:
		m.box(Vector3(x1 - 0.3, top + 0.02, 0.2), Vector3(0.26, 0.04, 0.34), c(MANILA))          # стопка дел
		m.box(Vector3(x1 - 0.29, top + 0.047, 0.21), Vector3(0.26, 0.014, 0.34), c(0xC8B070))
		m.push()                                                                              # фото в рамке
		m.translate(Vector3(x0 + 0.3, top, 0.2))
		m.rot_y(25)
		m.rot_x(-12)
		m.box(Vector3(0, 0.09, 0), Vector3(0.14, 0.18, 0.015), c(GOLD))
		m.box(Vector3(0, 0.09, 0.009), Vector3(0.11, 0.15, 0.004), c(0x6E7C8A))
		m.pop()
		_cyl(m, Vector3(cx + 0.42, top, -0.05), 0.1, 0.035, 0.035, c(BLACK), 8)               # стакан с ручками
		for k in 3:
			m.box(Vector3(cx + 0.41 + k * 0.012, top + 0.13, -0.05), Vector3(0.008, 0.1, 0.008), c([NAVY_L, RED, BLACK][k]))
	_mug(m, Vector3(cx - 0.36, top, 0.18), 0xECEBE5)

## Копировальный аппарат
static func _copier(m: Mesher) -> void:
	m.box(Vector3(0.05, 0.03, -0.02), Vector3(0.74, 0.06, 0.56), c(BLACK))
	m.box(Vector3(0.05, 0.5, -0.02), Vector3(0.78, 0.88, 0.62), c(PUTTY))
	for d in 2:
		m.box(Vector3(0.05, 0.2 + d * 0.24, 0.292), Vector3(0.7, 0.2, 0.008), c(PUTTY_D))       # лотки с бумагой
		m.box(Vector3(0.05, 0.26 + d * 0.24, 0.3), Vector3(0.2, 0.025, 0.012), c(STEEL_D))
	m.box(Vector3(0.05, 0.945, -0.05), Vector3(0.76, 0.012, 0.52), c(STEEL_D))
	m.box(Vector3(0.05, 0.975, -0.05), Vector3(0.74, 0.05, 0.5), c(0xE4DFD0))      # крышка
	m.box(Vector3(0.05, 1.003, 0.19), Vector3(0.3, 0.01, 0.02), c(PUTTY_D))
	m.push()                                                                      # панель управления
	m.translate(Vector3(0.05, 0.955, 0.25))
	m.rot_x(25)
	m.box(Vector3.ZERO, Vector3(0.7, 0.02, 0.12), c(0x3A3F45))
	m.box(Vector3(0.24, 0.012, 0), Vector3(0.08, 0.008, 0.06), c(0x38C060, 0.5))
	m.box(Vector3(-0.14, 0.012, 0), Vector3(0.2, 0.006, 0.05), c(0x9FD8A0, 0.5))
	for k in 6:
		m.box(Vector3(0.04 + (k % 3) * 0.04, 0.012, -0.02 + (k / 3) * 0.04), Vector3(0.025, 0.006, 0.025), c(0xC8CCD0))
	m.pop()
	m.box(Vector3(-0.42, 0.62, -0.02), Vector3(0.16, 0.02, 0.4), c(PUTTY_D))       # лоток выдачи с копиями
	m.box(Vector3(-0.42, 0.64, -0.02), Vector3(0.13, 0.02, 0.3), c(PAPER))
	m.box(Vector3(0.25, 1.03, -0.12), Vector3(0.22, 0.06, 0.3), c(0xF0EEE6))       # пачка бумаги
	m.box(Vector3(0.25, 1.03, -0.12), Vector3(0.225, 0.02, 0.305), c(0x3A6FC0))

## Тумба с факсом и матричным принтером
static func _faxstand(m: Mesher) -> void:
	m.box(Vector3(0, 0.03, -0.02), Vector3(0.88, 0.06, 0.46), c(BLACK))
	m.box(Vector3(0, 0.34, -0.02), Vector3(0.92, 0.56, 0.5), c(0x9A8866))
	for k in 2:
		m.box(Vector3(-0.225 + k * 0.45, 0.34, 0.234), Vector3(0.43, 0.5, 0.012), c(0xA8956F))
		m.box(Vector3(-0.06 + k * 0.12, 0.42, 0.244), Vector3(0.02, 0.12, 0.014), c(STEEL_D))
	m.box(Vector3(0, 0.635, -0.02), Vector3(0.96, 0.03, 0.54), c(0x7E6E50))
	var top := 0.65
	# факс
	m.box(Vector3(-0.24, top + 0.06, 0.0), Vector3(0.36, 0.12, 0.3), c(PUTTY))
	m.box(Vector3(-0.39, top + 0.135, 0.0), Vector3(0.06, 0.04, 0.24), c(PUTTY_D))
	m.box(Vector3(-0.2, top + 0.123, 0.06), Vector3(0.16, 0.006, 0.1), c(0x3A3F45))
	m.box(Vector3(-0.1, top + 0.123, 0.06), Vector3(0.02, 0.008, 0.02), c(0x38C060, 0.5))
	m.push()
	m.translate(Vector3(-0.2, top + 0.11, -0.1))
	m.rot_x(-50)
	m.box(Vector3(0, 0.08, 0), Vector3(0.2, 0.16, 0.004), c(PAPER))
	m.pop()
	# матричный принтер с лентой бумаги
	m.box(Vector3(0.24, top + 0.07, -0.02), Vector3(0.42, 0.14, 0.34), c(PUTTY))
	m.box(Vector3(0.24, top + 0.145, -0.06), Vector3(0.36, 0.02, 0.1), c(PUTTY_D))
	m.box(Vector3(0.4, top + 0.143, 0.1), Vector3(0.06, 0.006, 0.08), c(0x3A3F45))
	m.push()
	m.translate(Vector3(0.24, top + 0.15, -0.08))
	m.rot_x(-18)
	m.box(Vector3(0, 0.13, 0), Vector3(0.3, 0.26, 0.004), c(PAPER))
	for ln in 4:
		m.box(Vector3(0, 0.05 + ln * 0.05, 0.003), Vector3(0.3, 0.02, 0.002), c(0xCFE4CF))
	m.pop()

## Стол для допросной: стальной, привинчен к полу (на две клетки)
static func _interro(m: Mesher, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	var k := 1.0 if wide else 0.55
	m.box(Vector3(cx, 0.75, 0), Vector3(L, 0.04, 0.78), c(0x8E949A))
	m.box(Vector3(cx, 0.72, 0), Vector3(L - 0.04, 0.03, 0.74), c(STEEL_D))
	for lx in [x0 + 0.12, x0 + L - 0.12]:
		for lz in [-0.28, 0.28]:
			m.box(Vector3(lx, 0.36, lz), Vector3(0.06, 0.72, 0.06), c(STEEL_D))
			m.box(Vector3(lx, 0.008, lz), Vector3(0.15, 0.016, 0.15), c(0x3A3F45))              # пластина с болтами
		m.box(Vector3(lx, 0.2, 0), Vector3(0.04, 0.04, 0.56), c(STEEL_D))
	var top := 0.77
	# скоба для наручников
	for sx in [-0.07, 0.07]:
		m.box(Vector3(cx + sx, top + 0.025, 0.12), Vector3(0.02, 0.05, 0.02), c(CHROME))
	m.box(Vector3(cx, top + 0.05, 0.12), Vector3(0.16, 0.02, 0.02), c(CHROME))
	# катушечный диктофон и микрофон
	var rx := cx - 0.52 * k
	m.box(Vector3(rx, top + 0.035, -0.14), Vector3(0.28, 0.07, 0.2), c(BLACK))
	for sx in [-0.07, 0.07]:
		_cyl(m, Vector3(rx + sx, top + 0.07, -0.16), 0.012, 0.05, 0.05, c(0x9A9EA2), 10)
		_cyl(m, Vector3(rx + sx, top + 0.082, -0.16), 0.006, 0.018, 0.018, c(BLACK), 6)
	m.box(Vector3(rx + 0.1, top + 0.072, -0.07), Vector3(0.03, 0.006, 0.02), c(0xC03A30, 0.5))
	_cyl(m, Vector3(rx + 0.24 * k + 0.08, top, -0.02), 0.012, 0.045, 0.045, c(BLACK), 8)
	_cyl(m, Vector3(rx + 0.24 * k + 0.08, top + 0.012, -0.02), 0.12, 0.008, 0.008, c(CHROME), 6)
	m.box(Vector3(rx + 0.24 * k + 0.08, top + 0.15, -0.01), Vector3(0.035, 0.05, 0.06), c(0x3A3F45))
	# дело с фотографиями, пепельница, стаканчик
	var fx := cx + 0.5 * k
	m.box(Vector3(fx, top + 0.006, -0.12), Vector3(0.26, 0.012, 0.34), c(MANILA))
	m.box(Vector3(fx + 0.02, top + 0.014, -0.1), Vector3(0.2, 0.004, 0.26), c(PAPER))
	m.box(Vector3(fx - 0.03, top + 0.018, -0.16), Vector3(0.1, 0.004, 0.12), c(0x4A4640))
	if wide:
		_cyl(m, Vector3(cx + 0.2, top, 0.22), 0.025, 0.06, 0.07, c(0x50565C), 10)
		m.box(Vector3(cx + 0.2, top + 0.03, 0.22), Vector3(0.07, 0.012, 0.012), c(PAPER))
		_cyl(m, Vector3(cx - 0.22, top, 0.24), 0.09, 0.03, 0.036, c(0xE8E4D4), 8)

# ================== расследования и вещдоки ==================
## Доска расследования: фото, карта, записки, красные нити
static func _caseboard(m: Mesher, hv: int) -> void:
	var zf := _board(m, WALNUT_D, CORK)
	var pins := [Vector2(-0.3, 1.66), Vector2(0.0, 1.7), Vector2(0.3, 1.62), Vector2(-0.26, 1.3), Vector2(0.05, 1.36), Vector2(0.3, 1.2), Vector2(-0.05, 1.12)]
	# карта района с отметками
	m.box(Vector3(0.05, 1.36, zf + 0.001), Vector3(0.3, 0.26, 0.004), c(0xD9D2AC))
	for k in 3:
		m.box(Vector3(-0.05 + k * 0.1, 1.36, zf + 0.004), Vector3(0.006, 0.26, 0.002), c(0x8A8A72))
		m.box(Vector3(0.05, 1.28 + k * 0.08, zf + 0.004), Vector3(0.3, 0.006, 0.002), c(0x8A8A72))
	m.box(Vector3(0.1, 1.4, zf + 0.005), Vector3(0.03, 0.03, 0.003), c(RED))
	# фотографии
	for k in [0, 1, 2, 3, 5]:
		var p: Vector2 = pins[k]
		m.push()
		m.translate(Vector3(p.x, p.y - 0.08, zf + 0.002))
		m.rot_z(((hv >> k) % 5 - 2) * 2.0)
		m.box(Vector3.ZERO, Vector3(0.17, 0.2, 0.004), c(0xF2F0E8))
		m.box(Vector3(0, 0.015, 0.003), Vector3(0.14, 0.14, 0.002), c([0x5A6470, 0x6A5A48, 0x4A5048][k % 3]))
		m.box(Vector3(0, 0.02, 0.005), Vector3(0.05, 0.06, 0.002), c(0x2A2A2A))
		m.box(Vector3(0, -0.035, 0.005), Vector3(0.1, 0.035, 0.002), c(0x2A2A2A))
		m.pop()
	# записки
	m.box(Vector3(-0.05, 1.08, zf + 0.002), Vector3(0.14, 0.12, 0.004), c(0xF2E9A8))
	m.box(Vector3(-0.3, 1.08, zf + 0.002), Vector3(0.12, 0.1, 0.004), c(0xF0C4C0))
	for k in 2:
		m.box(Vector3(-0.05, 1.1 - k * 0.035, zf + 0.005), Vector3(0.1, 0.008, 0.002), c(0x5A5F70))
	# нити между уликами и булавки
	var links := [[0, 1], [1, 2], [1, 4], [3, 4], [4, 5], [4, 6], [0, 3]]
	for l in links:
		if (hv >> (l[0] + l[1])) & 7 == 0:
			continue
		_line(m, pins[l[0]], pins[l[1]], zf + 0.009, c(RED), 0.008)
	for p in pins:
		m.box(Vector3(p.x, p.y, zf + 0.012), Vector3(0.024, 0.024, 0.008), c(RED))
	m.box(Vector3(0, 0.9, 0.02), Vector3(0.6, 0.025, 0.08), c(WALNUT_D))           # полочка с маркерами
	m.box(Vector3(-0.1, 0.92, 0.03), Vector3(0.12, 0.02, 0.02), c(RED))
	m.box(Vector3(0.08, 0.92, 0.03), Vector3(0.12, 0.02, 0.02), c(BLACK))

## Стеллаж с вещественными доказательствами
static func _evidence(m: Mesher, hv: int) -> void:
	for sx in [-0.45, 0.45]:
		for sz in [-0.24, 0.2]:
			m.box(Vector3(sx, 0.94, sz), Vector3(0.035, 1.88, 0.035), c(STEEL_D))
	m.box(Vector3(0, 1.0, -0.255), Vector3(0.9, 0.02, 0.02), c(STEEL_D))
	for s in 5:
		var sy := 0.08 + s * 0.44
		m.box(Vector3(0, sy, -0.02), Vector3(0.92, 0.03, 0.48), c(STEEL))
		if s == 4:
			break
		for k in 3:
			var px := -0.3 + k * 0.3
			var by := sy + 0.015
			match (hv >> (s * 2 + k)) % 5:
				0, 1:                                                             # коробка с делом
					m.box(Vector3(px, by + 0.13, -0.02), Vector3(0.26, 0.26, 0.38), c(0xB08D5E))
					m.box(Vector3(px, by + 0.25, -0.02), Vector3(0.275, 0.07, 0.395), c(0x96744A))
					m.box(Vector3(px, by + 0.1, 0.172), Vector3(0.15, 0.09, 0.004), c(PAPER))
					m.box(Vector3(px, by + 0.115, 0.175), Vector3(0.1, 0.012, 0.002), c(BLACK))
					m.box(Vector3(px, by + 0.2, 0.172), Vector3(0.26, 0.03, 0.004), c(RED))
				2:                                                                # бумажные пакеты с пломбой
					for j in 2:
						m.box(Vector3(px - 0.06 + j * 0.12, by + 0.14, -0.02 + j * 0.06), Vector3(0.11, 0.28, 0.2), c(0xC2A070))
						m.box(Vector3(px - 0.06 + j * 0.12, by + 0.24, 0.082 + j * 0.06), Vector3(0.11, 0.03, 0.004), c(RED))
				3:                                                                # пластиковый контейнер
					m.box(Vector3(px, by + 0.09, -0.02), Vector3(0.26, 0.18, 0.36), c(0x7C8894))
					m.box(Vector3(px, by + 0.19, -0.02), Vector3(0.275, 0.025, 0.375), c(NAVY_L))
					m.box(Vector3(px, by + 0.09, 0.162), Vector3(0.12, 0.06, 0.004), c(PAPER))
				_:
					pass
	m.box(Vector3(-0.2, 1.97, -0.02), Vector3(0.3, 0.2, 0.38), c(0xB08D5E))         # сверху — пара коробок
	m.box(Vector3(-0.2, 2.06, -0.02), Vector3(0.315, 0.06, 0.395), c(0x96744A))
	if hv % 2 == 0:
		m.box(Vector3(0.22, 1.95, -0.02), Vector3(0.28, 0.16, 0.36), c(0x7C8894))

# ================== камеры ==================
## Решётка камеры: клетки подряд — одна сплошная
static func _bars(m: Mesher) -> void:
	for k in 7:
		m.box(Vector3(-0.42857 + k * 0.142857, 1.12, 0), Vector3(0.035, 2.2, 0.035), c(BAR))
	for y in [0.06, 1.1, 2.2]:
		m.box(Vector3(0, y, 0), Vector3(1.0, 0.07, 0.055), c(0x3C4148))

## Дверь камеры: решётчатая, сдвижная, с замком (закрыта)
static func _celldoor(m: Mesher) -> void:
	for sx in [-0.465, 0.465]:
		m.box(Vector3(sx, 1.12, 0), Vector3(0.07, 2.24, 0.09), c(0x3C4148))
	m.box(Vector3(0, 2.2, 0.0), Vector3(1.0, 0.09, 0.1), c(0x3C4148))              # направляющая
	for k in 5:
		m.box(Vector3(-0.3 + k * 0.15, 1.08, 0.03), Vector3(0.032, 2.04, 0.032), c(0x5A6068))
	for y in [0.08, 0.98, 1.16, 2.08]:
		m.box(Vector3(0, y, 0.03), Vector3(0.84, 0.05, 0.04), c(0x4A5058))
	m.box(Vector3(-0.08, 1.07, 0.03), Vector3(0.44, 0.13, 0.02), c(0x70767C))      # окошко для подноса
	m.box(Vector3(0.34, 1.07, 0.04), Vector3(0.14, 0.26, 0.09), c(0x2B2F34))       # замок
	m.box(Vector3(0.34, 1.07, 0.087), Vector3(0.03, 0.06, 0.006), c(GOLD))

## Нары: стальная полка у стены с тонким матрасом (на две клетки)
static func _cellbunk(m: Mesher, hv: int, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	m.box(Vector3(cx, 0.44, -0.08), Vector3(L, 0.05, 0.72), c(0x7B8187))
	m.box(Vector3(cx, 0.4, 0.27), Vector3(L, 0.08, 0.02), c(STEEL_D))
	for lx in [x0 + 0.1, x0 + L - 0.1]:
		m.box(Vector3(lx, 0.21, 0.22), Vector3(0.05, 0.42, 0.05), c(STEEL_D))
		m.box(Vector3(lx, 0.008, 0.22), Vector3(0.13, 0.016, 0.13), c(0x3A3F45))
		m.box(Vector3(lx, 0.3, -0.4), Vector3(0.05, 0.26, 0.06), c(STEEL_D))        # кронштейн к стене
	m.box(Vector3(cx, 0.505, -0.08), Vector3(L - 0.08, 0.08, 0.64), c(0x8F9AA4))   # матрас
	for s in int(L / 0.24):
		m.box(Vector3(x0 + 0.17 + s * 0.24, 0.506, -0.08), Vector3(0.03, 0.082, 0.642), c(0x6E7A86))
	m.box(Vector3(x0 + 0.22, 0.57, -0.08), Vector3(0.3, 0.06, 0.42), c(0xD8D6CC))  # подушка
	if hv % 3 != 0:                                                               # сложенное одеяло
		m.box(Vector3(x0 + L - 0.24, 0.58, -0.08), Vector3(0.32, 0.07, 0.5), c(0x6B6558))
		m.box(Vector3(x0 + L - 0.24, 0.617, -0.08), Vector3(0.04, 0.004, 0.5), c(0x8A8474))

## Тюремный унитаз с раковиной — из нержавейки
static func _celltoilet(m: Mesher) -> void:
	m.box(Vector3(0, 0.5, -0.2), Vector3(0.56, 1.0, 0.3), c(INOX))                 # тумба
	m.box(Vector3(0, 1.1, -0.33), Vector3(0.56, 0.2, 0.04), c(INOX))               # бортик
	m.box(Vector3(0, 1.004, -0.18), Vector3(0.4, 0.008, 0.2), c(0x6F767B))         # раковина
	m.box(Vector3(0, 1.008, -0.18), Vector3(0.04, 0.006, 0.04), c(BLACK))
	m.box(Vector3(0, 1.1, -0.28), Vector3(0.03, 0.03, 0.08), c(CHROME))            # излив
	for sx in [-0.1, 0.1]:
		m.box(Vector3(sx, 1.12, -0.305), Vector3(0.04, 0.04, 0.02), c(CHROME))
	m.box(Vector3(-0.17, 0.8, -0.045), Vector3(0.05, 0.05, 0.02), c(CHROME))       # кнопка слива
	m.push()                                                                      # чаша
	m.translate(Vector3(0, 0, 0.1))
	m.tube(0.0, 0.4, 0.15, 0.2, c(INOX), 12, 0.9, 1.15)
	m.tube(0.4, 0.43, 0.21, 0.2, c(0x858B90), 12, 0.9, 1.15)
	m.tube(0.43, 0.436, 0.15, 0.15, c(0x30363A), 12, 0.9, 1.15)
	m.pop()
	m.push()                                                                      # рулон бумаги сбоку
	m.translate(Vector3(0.31, 0.72, -0.12))
	m.rot_x(90)
	m.tube(-0.05, 0.05, 0.05, 0.05, c(0xECEBE5), 8)
	m.pop()
	m.box(Vector3(0.29, 0.72, -0.12), Vector3(0.02, 0.03, 0.03), c(STEEL_D))

# ================== оформление задержанных ==================
## Ростомер для фотографирования задержанных
static func _mugshot(m: Mesher) -> void:
	m.box(Vector3(0, 1.02, 0), Vector3(0.94, 2.04, 0.03), c(0xE6E2D2))
	m.box(Vector3(0, 2.05, 0), Vector3(0.98, 0.04, 0.05), c(BLACK))
	m.box(Vector3(0, 0.02, 0), Vector3(0.98, 0.04, 0.05), c(BLACK))
	for i in 16:
		var y := 0.5 + i * 0.1
		var major := i % 5 == 0
		m.box(Vector3(0.1 if not major else 0.0, y, 0.017), Vector3(0.62 if not major else 0.9, 0.014 if major else 0.007, 0.004), c(BLACK))
		if major or i % 5 == 3:
			m.box(Vector3(-0.38, y + 0.045, 0.017), Vector3(0.07, 0.05, 0.004), c(BLACK))       # цифра
	# табличка с номером на крючке
	m.box(Vector3(0.22, 0.3, 0.02), Vector3(0.34, 0.14, 0.02), c(BLACK))
	m.box(Vector3(0.22, 0.33, 0.032), Vector3(0.26, 0.03, 0.004), c(PAPER))
	m.box(Vector3(0.18, 0.28, 0.032), Vector3(0.18, 0.025, 0.004), c(PAPER))

## Стойка оформления: дактилоскопия и изъятые вещи
static func _booking(m: Mesher) -> void:
	m.box(Vector3(0, 0.04, -0.02), Vector3(0.9, 0.08, 0.46), c(BLACK))
	m.box(Vector3(0, 0.53, -0.02), Vector3(0.94, 0.9, 0.5), c(0x6C7A88))
	for k in 2:
		var dx := -0.235 + k * 0.47
		m.box(Vector3(dx, 0.86, 0.234), Vector3(0.44, 0.16, 0.012), c(0x7C8A98))                # ящик
		m.box(Vector3(dx, 0.86, 0.246), Vector3(0.14, 0.022, 0.014), c(CHROME))
		m.box(Vector3(dx, 0.43, 0.234), Vector3(0.44, 0.62, 0.012), c(0x7C8A98))                # дверца
		m.box(Vector3(dx + (0.17 if k == 0 else -0.17), 0.6, 0.246), Vector3(0.02, 0.12, 0.014), c(CHROME))
	m.box(Vector3(0, 1.0, -0.02), Vector3(0.98, 0.04, 0.54), c(0x3A3F45))
	var top := 1.02
	# подушка с краской и валик
	m.box(Vector3(-0.3, top + 0.006, 0.06), Vector3(0.24, 0.012, 0.16), c(INOX))
	m.box(Vector3(-0.3, top + 0.016, 0.06), Vector3(0.2, 0.01, 0.12), c(BLACK))
	m.push()
	m.translate(Vector3(-0.36, top + 0.025, -0.14))
	m.rot_z(-90)
	m.tube(0.0, 0.12, 0.022, 0.022, c(BLACK), 8)
	m.pop()
	m.box(Vector3(-0.3, top + 0.025, -0.08), Vector3(0.016, 0.016, 0.12), c(0x6A4A2C))
	# дактилокарта с отпечатками и стопка чистых
	m.box(Vector3(0.0, top + 0.004, 0.05), Vector3(0.22, 0.006, 0.24), c(PAPER))
	for k in 10:
		m.box(Vector3(-0.076 + (k % 5) * 0.038, top + 0.008, 0.02 + (k / 5) * 0.07), Vector3(0.024, 0.002, 0.04), c(0x3A3632))
	m.box(Vector3(0.0, top + 0.008, -0.04), Vector3(0.18, 0.002, 0.02), c(0x5A5F70))
	m.box(Vector3(0.02, top + 0.015, -0.17), Vector3(0.22, 0.03, 0.14), c(PAPER))
	# лоток с изъятыми вещами: бумажник, ключи, часы
	m.box(Vector3(0.33, top + 0.025, 0.04), Vector3(0.26, 0.05, 0.22), c(0x8E9498))
	m.box(Vector3(0.33, top + 0.045, 0.04), Vector3(0.22, 0.012, 0.18), c(0x50565C))
	m.box(Vector3(0.29, top + 0.06, 0.06), Vector3(0.1, 0.02, 0.08), c(0x5A3A22))
	m.box(Vector3(0.39, top + 0.056, 0.0), Vector3(0.05, 0.01, 0.03), c(GOLD))
	m.box(Vector3(0.38, top + 0.056, 0.09), Vector3(0.04, 0.012, 0.04), c(CHROME))
	_cyl(m, Vector3(0.36, top, -0.17), 0.13, 0.05, 0.05, c(0xECEBE5), 8)           # салфетки

## Стойка со спецснаряжением: шлемы, щиты, дубинки
static func _riotrack(m: Mesher) -> void:
	for sx in [-0.45, 0.45]:
		for sz in [-0.2, 0.2]:
			m.box(Vector3(sx, 0.95, sz), Vector3(0.035, 1.9, 0.035), c(STEEL_D))
	m.box(Vector3(0, 0.9, -0.225), Vector3(0.9, 1.6, 0.02), c(0x50565C))           # задняя стенка
	m.box(Vector3(0, 0.1, 0), Vector3(0.92, 0.03, 0.42), c(STEEL))
	m.box(Vector3(0, 1.5, 0), Vector3(0.92, 0.03, 0.42), c(STEEL))
	for k in 3:                                                                   # шлемы с забралом
		var hx := -0.29 + k * 0.29
		m.ellipsoid(Vector3(hx, 1.515, -0.02), Vector3(0.13, 0.17, 0.15), c(NAVY), 4, 10, 0.0, 0.5)
		_cyl(m, Vector3(hx, 1.515, -0.02), 0.02, 0.135, 0.13, c(BLACK), 10)
		m.push()
		m.translate(Vector3(hx, 1.6, 0.12))
		m.rot_x(-20)
		m.box(Vector3.ZERO, Vector3(0.2, 0.1, 0.012), c(0xB8D0DC))
		m.pop()
	for k in 3:                                                                   # щиты
		m.push()
		m.translate(Vector3(-0.3 + k * 0.3, 0.115, 0.08))
		m.rot_x(-9)
		m.box(Vector3(0, 0.5, 0), Vector3(0.27, 1.0, 0.03), c(0xAFC4D0))
		m.box(Vector3(0, 0.62, 0.017), Vector3(0.27, 0.15, 0.004), c(NAVY))
		m.box(Vector3(0, 0.62, 0.02), Vector3(0.2, 0.05, 0.003), c(PAPER))
		m.box(Vector3(0, 0.98, 0.0), Vector3(0.28, 0.03, 0.035), c(BLACK))
		m.box(Vector3(0, 0.02, 0.0), Vector3(0.28, 0.03, 0.035), c(BLACK))
		m.pop()
	for k in 2:                                                                   # дубинки на держателе
		m.push()
		m.translate(Vector3(-0.3, 1.3 + k * 0.09, 0.13))
		m.rot_z(-90)
		m.tube(0.0, 0.6, 0.017, 0.017, c(BLACK), 6)
		m.tube(0.0, 0.14, 0.023, 0.023, c(0x2A2C30), 6)
		m.pop()
	for sx in [-0.34, 0.34]:
		m.box(Vector3(sx, 1.34, 0.11), Vector3(0.03, 0.16, 0.06), c(STEEL_D))

# ================== дежурная часть ==================
## Пульт диспетчера: консоль с лампами, микрофон, карта района
static func _dispatch(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.74, -0.01), Vector3(0.98, 0.04, 0.86), c(0x6E747A))
	for sx in [-0.47, 0.47]:
		m.box(Vector3(sx, 0.36, -0.01), Vector3(0.04, 0.72, 0.82), c(0x50565C))
	m.box(Vector3(0, 0.45, -0.42), Vector3(0.9, 0.54, 0.02), c(0x50565C))
	m.box(Vector3(0, 1.0, -0.31), Vector3(0.98, 0.48, 0.24), c(0x3C4248))          # консоль
	var zf := -0.188
	var lamp := [0x50D060, 0xE8B030, 0xD03A30, 0x2A2E33]
	for k in 16:
		var col: int = lamp[(hv >> (k % 12)) % 4]
		m.box(Vector3(-0.27 + (k % 8) * 0.077, 1.16 - (k / 8) * 0.07, zf), Vector3(0.035, 0.035, 0.008), c(col, 0.5 if col != 0x2A2E33 else 1.0))
	for k in 8:
		m.box(Vector3(-0.27 + k * 0.077, 1.02, zf), Vector3(0.05, 0.016, 0.004), c(PAPER))       # подписи
		m.box(Vector3(-0.27 + k * 0.077, 0.96, zf + 0.008), Vector3(0.014, 0.045, 0.016), c(CHROME))   # тумблеры
	for sx in [-0.41, 0.41]:                                                      # динамики
		m.push()
		m.translate(Vector3(sx, 1.1, zf))
		m.rot_x(90)
		m.tube(0.0, 0.01, 0.055, 0.055, c(0x1E2024), 10)
		m.pop()
	m.box(Vector3(0, 1.49, -0.4), Vector3(0.96, 0.46, 0.04), c(0x1E2A34))          # карта района с огоньками
	for k in 4:
		m.box(Vector3(-0.3 + k * 0.2, 1.49, -0.378), Vector3(0.012, 0.4, 0.003), c(0x6E8894))
	for k in 3:
		m.box(Vector3(0, 1.36 + k * 0.13, -0.378), Vector3(0.88, 0.012, 0.003), c(0x6E8894))
	var dots := [[-0.2, 1.42, 0xE8C84A], [0.1, 1.55, 0xE8C84A], [0.3, 1.4, 0xD03A30], [-0.36, 1.6, 0x50D060], [0.22, 1.63, 0xE8C84A]]
	for d in dots:
		m.box(Vector3(d[0], d[1], -0.376), Vector3(0.03, 0.03, 0.006), c(d[2], 0.5))
	var top := 0.76
	# радиостанция, микрофон на гибкой ножке, телефон, журнал, гарнитура
	m.box(Vector3(-0.3, top + 0.05, -0.04), Vector3(0.3, 0.1, 0.24), c(0x2A2E33))
	m.box(Vector3(-0.34, top + 0.06, 0.082), Vector3(0.14, 0.04, 0.004), c(0x58D878, 0.5))
	_cyl(m, Vector3(-0.2, top + 0.1, 0.02), 0.02, 0.025, 0.025, c(BLACK), 8)
	_cyl(m, Vector3(0.0, top, 0.02), 0.02, 0.055, 0.05, c(BLACK), 10)
	m.push()
	m.translate(Vector3(0.0, top + 0.02, 0.02))
	m.rot_x(22)
	m.box(Vector3(0, 0.15, 0), Vector3(0.012, 0.3, 0.012), c(CHROME))
	m.box(Vector3(0, 0.32, 0), Vector3(0.04, 0.07, 0.04), c(0x2A2E33))
	m.pop()
	_phone(m, Vector3(0.32, top, -0.02))
	m.box(Vector3(0.02, top + 0.008, 0.28), Vector3(0.4, 0.016, 0.22), c(NAVY))
	m.box(Vector3(0.02, top + 0.018, 0.28), Vector3(0.37, 0.006, 0.19), c(PAPER))
	m.box(Vector3(0.02, top + 0.022, 0.28), Vector3(0.006, 0.004, 0.19), c(STEEL_D))
	for k in 4:
		m.box(Vector3(-0.07, top + 0.023, 0.22 + k * 0.04), Vector3(0.14, 0.002, 0.008), c(0x5A5F70))
	for sx in [-0.4, -0.28]:
		m.box(Vector3(sx, top + 0.025, 0.28), Vector3(0.06, 0.05, 0.07), c(BLACK))
	m.box(Vector3(-0.34, top + 0.055, 0.28), Vector3(0.14, 0.014, 0.025), c(STEEL_D))
	_mug(m, Vector3(0.38, top, 0.26), NAVY)

## Доска для инструктажа: расписание смен мелом
static func _briefboard(m: Mesher, hv: int) -> void:
	var zf := _board(m, 0x8A6A40, 0x2F4A3A)
	m.box(Vector3(0, 1.76, zf), Vector3(0.6, 0.035, 0.003), c(0xE8E8E0))           # заголовок мелом
	for k in 4:
		m.box(Vector3(-0.26 + k * 0.2, 1.36, zf), Vector3(0.006, 0.66, 0.003), c(0xD0D4CC))
	for k in 6:
		m.box(Vector3(0, 1.69 - k * 0.13, zf), Vector3(0.84, 0.006, 0.003), c(0xD0D4CC))
	for k in 20:
		if (hv >> (k % 13)) & 1 == 0 and k % 4 != 0:
			continue
		var cxp := -0.36 + (k % 4) * 0.2 + (0.0 if k % 4 == 0 else 0.03)
		var cyp := 1.625 - (k / 4) * 0.13
		m.box(Vector3(cxp + 0.02, cyp, zf), Vector3(0.1 + (k % 3) * 0.02, 0.02, 0.003), c(0xE8E8E0 if k % 4 == 0 else [0xE8E8E0, 0xF2E080, 0xF0A8A0][k % 3]))
	m.box(Vector3(0, 0.975, zf + 0.03), Vector3(0.86, 0.025, 0.07), c(0x8A6A40))   # полочка: мел и губка
	m.box(Vector3(-0.2, 0.995, zf + 0.03), Vector3(0.07, 0.016, 0.016), c(0xECEBE5))
	m.box(Vector3(-0.08, 0.995, zf + 0.035), Vector3(0.05, 0.016, 0.016), c(0xF2E080))
	m.box(Vector3(0.2, 1.005, zf + 0.03), Vector3(0.14, 0.04, 0.05), c(0x3A3F45))

## Трибуна для инструктажа: эмблема — к залу (+z), наклонная крышка — к выступающему
static func _podium(m: Mesher) -> void:
	m.box(Vector3(0, 0.03, 0), Vector3(0.62, 0.06, 0.46), c(WALNUT_D))
	m.box(Vector3(0, 0.55, 0), Vector3(0.56, 1.0, 0.4), c(WALNUT))
	m.box(Vector3(0, 0.56, 0.202), Vector3(0.46, 0.8, 0.008), c(NAVY))
	m.push()
	m.translate(Vector3(0, 0.66, 0.206))
	m.rot_x(90)
	m.tube(0.0, 0.012, 0.13, 0.13, c(GOLD), 14)
	m.tube(0.012, 0.018, 0.09, 0.09, c(NAVY_L), 14)
	m.pop()
	for k in 2:
		m.push()
		m.translate(Vector3(0, 0.66, 0.226))
		m.rot_z(45.0 * k)
		m.box(Vector3.ZERO, Vector3(0.09, 0.09, 0.004), c(GOLD))
		m.pop()
	m.box(Vector3(0, 0.3, 0.208), Vector3(0.3, 0.05, 0.004), c(GOLD))
	m.push()
	m.translate(Vector3(0, 1.06, 0.0))
	m.rot_x(-16)
	m.box(Vector3.ZERO, Vector3(0.6, 0.03, 0.44), c(WALNUT_D))
	m.box(Vector3(0, 0.025, -0.2), Vector3(0.6, 0.03, 0.03), c(WALNUT_D))          # бортик, чтобы бумаги не сползали
	m.box(Vector3(-0.05, 0.02, -0.02), Vector3(0.24, 0.006, 0.3), c(PAPER))
	m.pop()
	m.push()                                                                      # микрофон
	m.translate(Vector3(0.22, 1.1, 0.12))
	m.rot_x(-30)
	m.box(Vector3(0, 0.11, 0), Vector3(0.012, 0.22, 0.012), c(CHROME))
	m.box(Vector3(0, 0.24, 0), Vector3(0.035, 0.06, 0.035), c(0x2A2E33))
	m.pop()
