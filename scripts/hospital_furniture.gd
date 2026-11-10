class_name HospitalFurniture
extends RefCounted
## Мебель больницы (клетки GameWorld.RECEPTION … MORGUE): холл, палаты, хирургия и операционная, процедурная,
## склад медикаментов, кабинет главного врача, зал собраний, комната персонала, лаборатория, морг.
## Устроена как остальные наборы: начало координат — центр клетки на полу, +z — лицо, -z — к стене.
## BACK — на сколько модель уходит назад от центра. Меняешь модель — поправь BACK здесь и GameWorld.FURN_FRONT
## (проверка test_furniture_collision сверяет их с самой моделью).

const W = preload("res://scripts/world.gd")

const BACK := {W.RECEPTION: 0.45, W.WHEELCHAIR: 0.38, W.DIRECTORY: 0.15, W.MAGTABLE: 0.28, W.VENDING: 0.38, W.GURNEY: 0.37,
	W.HOSPBED: 0.46, W.BEDSIDE: 0.24, W.IVSTAND: 0.22, W.SCREEN: 0.06, W.PATMONITOR: 0.20, W.OPTABLE: 0.29,
	W.SURGLIGHT: 0.26, W.ANESTHESIA: 0.37, W.INSTRTABLE: 0.27, W.SCRUBSINK: 0.32, W.XRAYVIEW: 0.08, W.STERILIZER: 0.32,
	W.DEFIB: 0.25, W.OXYGEN: 0.18, W.BIOBINS: 0.19, W.SURGCAB: 0.23, W.EXAMTABLE: 0.32, W.SCALE: 0.25,
	W.MEDCART: 0.23, W.MEDSHELF: 0.26, W.MEDFRIDGE: 0.35, W.SUPPLYBOXES: 0.28, W.NARCSAFE: 0.29, W.BOOKCASE: 0.21,
	W.DIPLOMAS: 0.08, W.SKELETON: 0.22, W.CONFTABLE: 0.45, W.PROJSCREEN: 0.17, W.OHPROJECTOR: 0.23, W.WHITEBOARD: 0.08,
	W.COATRACK: 0.20, W.TVSTAND: 0.28, W.CHARTRACK: 0.23, W.LABBENCH: 0.36, W.MORGUE: 0.40}

const WHITE := 0xECEBE5
const OFFW := 0xDDDCD4        # эмаль
const TEAL := 0x4E9A94        # больничный бирюзовый
const TEAL_D := 0x3A7A75
const MINT := 0xCFE3DC
const SURG := 0x4F8F7A        # хирургическое бельё
const INOX := 0xB9BEC1
const INOX_D := 0x858B90
const CHROME := 0xCDD1D4
const RED := 0xC0392B
const BLACK := 0x1B1C1F
const PAD := 0x3E4A58         # тёмный винил
const BEIGE := 0xD5CFBD       # корпуса приборов
const BEIGE_D := 0xB5AE9A
const WOOD := 0xA98862
const WALNUT := 0x7A5434
const WALNUT_D := 0x5A3B22
const GLASS := 0xC6DDE4
const BLUE := 0x3A6FC0
const YELLOW := 0xE8C84A
const O2 := 0x3F8F5A
const PAPER := 0xF2F0E8
const BONE := 0xE8E2CC
const AMBER := 0x7A4A22       # тёмное стекло флаконов

static func c(hex: int, k: float = 1.0) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255, int(round(k * 255.0)))

## Нарисовать мебель t. wide — длинный вариант на две клетки; deep — койка изголовьем к стене (тянется вперёд)
static func draw(m: Mesher, t: int, hv: int, wide: bool = false, deep: bool = false) -> void:
	match t:
		W.RECEPTION: _reception(m, hv)
		W.WHEELCHAIR: _wheelchair(m)
		W.DIRECTORY: _directory(m)
		W.MAGTABLE: _magtable(m, hv)
		W.VENDING: _vending(m, hv)
		W.GURNEY: _gurney(m, hv, wide)
		W.HOSPBED:
			if deep:
				_hospbed(m, hv, 2.2, 0.23)
			else:
				_hospbed(m, hv, 1.9 if wide else 0.94, 0.5 if wide else 0.0)
		W.BEDSIDE: _bedside(m, hv)
		W.IVSTAND: _ivstand(m, hv)
		W.SCREEN: _screen(m)
		W.PATMONITOR: _patmonitor(m)
		W.OPTABLE: _optable(m, hv, wide)
		W.SURGLIGHT: _surglight(m)
		W.ANESTHESIA: _anesthesia(m)
		W.INSTRTABLE: _instrtable(m)
		W.SCRUBSINK: _scrubsink(m)
		W.XRAYVIEW: _xrayview(m, hv)
		W.STERILIZER: _sterilizer(m)
		W.DEFIB: _defib(m)
		W.OXYGEN: _oxygen(m)
		W.BIOBINS: _biobins(m)
		W.SURGCAB: _surgcab(m, hv)
		W.EXAMTABLE: _examtable(m, wide)
		W.SCALE: _scale(m)
		W.MEDCART: _medcart(m)
		W.MEDSHELF: _medshelf(m, hv)
		W.MEDFRIDGE: _medfridge(m, hv)
		W.SUPPLYBOXES: _supplyboxes(m, hv)
		W.NARCSAFE: _narcsafe(m)
		W.BOOKCASE: _bookcase(m, hv)
		W.DIPLOMAS: _diplomas(m)
		W.SKELETON: _skeleton(m)
		W.CONFTABLE: _conftable(m, hv, wide)
		W.PROJSCREEN: _projscreen(m)
		W.OHPROJECTOR: _ohprojector(m)
		W.WHITEBOARD: _whiteboard(m, hv)
		W.COATRACK: _coatrack(m, hv)
		W.TVSTAND: _tvstand(m)
		W.CHARTRACK: _chartrack(m, hv)
		W.LABBENCH: _labbench(m, hv)
		W.MORGUE: _morgue(m, hv)

# ================== общие детали ==================
static func _cyl(m: Mesher, p: Vector3, h: float, r0: float, r1: float, col: Color, segs: int = 8) -> void:
	m.push()
	m.translate(p)
	m.tube(0.0, h, r0, r1, col, segs)
	m.pop()

## Цилиндр, лежащий вдоль x: от p вправо на длину len
static func _cyl_x(m: Mesher, p: Vector3, length: float, r: float, col: Color, segs: int = 8) -> void:
	m.push()
	m.translate(p)
	m.rot_z(-90)
	m.tube(0.0, length, r, r, col, segs)
	m.pop()

## Цилиндр вдоль z: от p вперёд на длину len
static func _cyl_z(m: Mesher, p: Vector3, length: float, r: float, col: Color, segs: int = 8) -> void:
	m.push()
	m.translate(p)
	m.rot_x(90)
	m.tube(0.0, length, r, r, col, segs)
	m.pop()

## Колёсико на вилке; p — точка на полу
static func _caster(m: Mesher, p: Vector3) -> void:
	m.box(p + Vector3(0, 0.07, 0), Vector3(0.03, 0.05, 0.03), c(CHROME))
	_cyl_x(m, p + Vector3(-0.014, 0.035, 0), 0.028, 0.035, c(BLACK), 8)

## Пятилучевое основание на колёсиках
static func _star_base(m: Mesher, r: float, col: int) -> void:
	for k in 5:
		m.push()
		m.rot_y(k * 72.0 + 18.0)
		m.box(Vector3(0, 0.07, r * 0.5), Vector3(0.035, 0.03, r), c(col))
		m.box(Vector3(0, 0.03, r - 0.02), Vector3(0.04, 0.05, 0.045), c(BLACK))
		m.pop()

## Тонкая линия на вертикальной плоскости (экраны, доски)
static func _line(m: Mesher, a: Vector2, b: Vector2, z: float, col: Color, th: float = 0.008) -> void:
	var d := b - a
	m.push()
	m.translate(Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z))
	m.rot_z(rad_to_deg(atan2(d.y, d.x)))
	m.box(Vector3.ZERO, Vector3(d.length(), th, 0.003), col)
	m.pop()

## Кривая пульса на экране: p — левый край, w — ширина
static func _ecg(m: Mesher, p: Vector3, w: float, col: Color) -> void:
	var pts := [Vector2(0, 0), Vector2(0.28, 0), Vector2(0.36, 0.03), Vector2(0.44, -0.02), Vector2(0.52, 0.09), Vector2(0.6, -0.04), Vector2(0.68, 0), Vector2(1.0, 0)]
	for i in pts.size() - 1:
		_line(m, Vector2(p.x + pts[i].x * w, p.y + pts[i].y), Vector2(p.x + pts[i + 1].x * w, p.y + pts[i + 1].y), p.z, col, 0.008)

## Красный крест на вертикальной плоскости (лицом на +z; sgn = -1 — на -z)
static func _cross(m: Mesher, p: Vector3, s: float) -> void:
	m.box(p, Vector3(s, s * 0.32, 0.006), c(RED))
	m.box(p, Vector3(s * 0.32, s, 0.006), c(RED))

## Монитор 90-х с клавиатурой: экран смотрит на +z
static func _crt(m: Mesher, p: Vector3) -> void:
	m.box(p + Vector3(0, 0.02, 0), Vector3(0.24, 0.04, 0.24), c(BEIGE_D))
	m.box(p + Vector3(0, 0.2, -0.02), Vector3(0.38, 0.32, 0.36), c(BEIGE))
	m.box(p + Vector3(0, 0.21, 0.162), Vector3(0.3, 0.23, 0.006), c(0x16261E))
	for k in 4:
		m.box(p + Vector3(-0.05 + (k % 2) * 0.02, 0.29 - k * 0.045, 0.166), Vector3(0.16 - (k % 3) * 0.03, 0.012, 0.003), c(0x58D878, 0.5))
	m.box(p + Vector3(0, 0.015, 0.3), Vector3(0.4, 0.03, 0.15), c(BEIGE))
	m.box(p + Vector3(0, 0.032, 0.3), Vector3(0.36, 0.006, 0.11), c(BEIGE_D))

static func _phone(m: Mesher, p: Vector3) -> void:
	m.box(p + Vector3(0, 0.03, 0), Vector3(0.2, 0.06, 0.2), c(OFFW))
	m.box(p + Vector3(-0.065, 0.075, 0), Vector3(0.055, 0.035, 0.21), c(WHITE))
	m.box(p + Vector3(0.035, 0.062, 0.02), Vector3(0.09, 0.006, 0.11), c(0x9A9EA2))

## Флакон тёмного стекла с этикеткой
static func _bottle(m: Mesher, p: Vector3, h: float, col: int = AMBER) -> void:
	_cyl(m, p, h, 0.03, 0.03, c(col), 6)
	_cyl(m, p + Vector3(0, h, 0), 0.025, 0.014, 0.014, c(WHITE), 6)
	m.box(p + Vector3(0, h * 0.5, 0.027), Vector3(0.035, h * 0.4, 0.008), c(PAPER))

## Рамка доски на стойках; возвращает z лицевой плоскости
static func _board(m: Mesher, frame: int, face: int) -> float:
	var z := -0.03
	for sx in [-0.46, 0.46]:
		m.box(Vector3(sx, 0.96, z), Vector3(0.035, 1.92, 0.035), c(frame))
		m.box(Vector3(sx, 0.015, z + 0.02), Vector3(0.05, 0.03, 0.14), c(frame))
	m.box(Vector3(0, 1.42, z), Vector3(0.96, 0.92, 0.04), c(frame))
	m.box(Vector3(0, 1.42, z + 0.021), Vector3(0.88, 0.84, 0.006), c(face))
	return z + 0.027

# ================== холл ==================
## Стойка регистратуры: со стороны посетителей (-z) — высокая панель с полкой, с рабочей (+z) — стол
static func _reception(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.56, -0.37), Vector3(1.0, 1.12, 0.08), c(WHITE))
	m.box(Vector3(0, 0.78, -0.412), Vector3(1.0, 0.14, 0.006), c(TEAL))            # бирюзовая полоса
	m.box(Vector3(0, 0.05, -0.412), Vector3(1.0, 0.1, 0.006), c(INOX_D))
	m.box(Vector3(0, 1.14, -0.33), Vector3(1.0, 0.04, 0.24), c(0xC9B48E))          # полка для посетителей
	m.box(Vector3(0, 0.76, 0.06), Vector3(1.0, 0.04, 0.78), c(0xDAD6CB))           # рабочая столешница
	m.box(Vector3(0, 0.735, 0.06), Vector3(1.0, 0.015, 0.76), c(INOX_D))
	for sx in [-0.48, 0.48]:
		m.box(Vector3(sx, 0.37, 0.02), Vector3(0.04, 0.74, 0.7), c(OFFW))
	m.box(Vector3(0, 0.4, -0.2), Vector3(0.92, 0.03, 0.24), c(INOX_D))             # полка с картами пациентов
	for k in 6:
		m.box(Vector3(-0.34 + k * 0.08, 0.54, -0.2), Vector3(0.06, 0.26, 0.2), c([TEAL, 0xD9C58A, BLUE, RED, 0xD9C58A, O2][(hv + k) % 6]))
	if hv % 2 == 0:
		_cross(m, Vector3(0, 0.42, -0.414), 0.22)
	var top := 0.78
	match hv % 3:
		0:
			_crt(m, Vector3(-0.08, top, -0.1))
		1:
			_phone(m, Vector3(-0.28, top, 0.0))
			m.box(Vector3(0.14, top + 0.01, 0.04), Vector3(0.44, 0.02, 0.3), c(TEAL_D))         # журнал записи
			m.box(Vector3(0.14, top + 0.022, 0.04), Vector3(0.4, 0.006, 0.27), c(PAPER))
			m.box(Vector3(0.14, top + 0.026, 0.04), Vector3(0.006, 0.004, 0.27), c(INOX_D))
			for k in 5:
				m.box(Vector3(0.04, top + 0.027, -0.06 + k * 0.045), Vector3(0.15, 0.002, 0.008), c(0x5A5F70))
		2:
			for k in 2:                                                           # лотки с бумагами
				m.box(Vector3(-0.3, top + 0.01 + k * 0.075, -0.05), Vector3(0.24, 0.02, 0.32), c(TEAL_D))
				m.box(Vector3(-0.3, top + 0.03 + k * 0.075, -0.05), Vector3(0.21, 0.02, 0.29), c(PAPER))
			m.box(Vector3(0.14, top + 0.03, 0.04), Vector3(0.22, 0.06, 0.16), c(0xD9C58A))      # стопка карт
			_cyl(m, Vector3(0.36, top, 0.14), 0.07, 0.025, 0.02, c(WALNUT_D), 6)                # печать
	if hv % 2 == 1:                                                               # на полке: планшет и антисептик
		m.box(Vector3(0.12, 1.168, -0.33), Vector3(0.22, 0.012, 0.16), c(TEAL_D))
		m.box(Vector3(0.12, 1.176, -0.33), Vector3(0.19, 0.006, 0.13), c(PAPER))
		_cyl(m, Vector3(-0.28, 1.16, -0.33), 0.13, 0.035, 0.03, c(0x9CCBEA), 8)
		m.box(Vector3(-0.28, 1.31, -0.31), Vector3(0.02, 0.03, 0.06), c(WHITE))
	else:                                                                         # буклеты в держателе
		m.box(Vector3(-0.2, 1.24, -0.36), Vector3(0.26, 0.16, 0.05), c(GLASS))
		for k in 3:
			m.box(Vector3(-0.28 + k * 0.08, 1.27, -0.345), Vector3(0.07, 0.16, 0.02), c([TEAL, YELLOW, 0xF0C4C0][k]))

## Кресло-каталка
static func _wheelchair(m: Mesher) -> void:
	for sx in [-0.3, 0.3]:
		_cyl_x(m, Vector3(sx - 0.015, 0.3, -0.06), 0.03, 0.3, c(BLACK), 14)        # большое колесо
		_cyl_x(m, Vector3(sx - 0.018, 0.3, -0.06), 0.036, 0.26, c(0x9AA0A6), 14)
		_cyl_x(m, Vector3(sx - 0.03, 0.3, -0.06), 0.06, 0.05, c(CHROME), 8)
		_cyl_x(m, Vector3(sx * 0.8 - 0.012, 0.07, 0.34), 0.024, 0.07, c(BLACK), 8) # переднее
		m.box(Vector3(sx * 0.8, 0.26, 0.3), Vector3(0.025, 0.36, 0.025), c(CHROME))
		m.box(Vector3(sx * 0.77, 0.72, -0.21), Vector3(0.025, 0.56, 0.025), c(CHROME))          # стойка спинки
		m.box(Vector3(sx * 0.77, 0.99, -0.27), Vector3(0.025, 0.025, 0.14), c(CHROME))          # ручка
		m.box(Vector3(sx * 0.77, 0.99, -0.34), Vector3(0.035, 0.035, 0.08), c(BLACK))
		m.box(Vector3(sx * 0.83, 0.62, 0.16), Vector3(0.025, 0.2, 0.025), c(CHROME))            # подлокотник
		m.box(Vector3(sx * 0.83, 0.62, -0.12), Vector3(0.025, 0.2, 0.025), c(CHROME))
		m.box(Vector3(sx * 0.83, 0.73, 0.02), Vector3(0.045, 0.03, 0.34), c(BLACK))
		m.box(Vector3(sx * 0.42, 0.13, 0.42), Vector3(0.14, 0.02, 0.12), c(INOX_D))             # подножка
		m.push()
		m.translate(Vector3(sx * 0.6, 0.5, 0.24))
		m.rot_x(-22)
		m.box(Vector3(0, -0.18, 0), Vector3(0.025, 0.4, 0.025), c(CHROME))
		m.pop()
	m.box(Vector3(0, 0.5, 0.02), Vector3(0.46, 0.03, 0.42), c(0x2E3F5A))           # сиденье
	m.box(Vector3(0, 0.76, -0.2), Vector3(0.46, 0.42, 0.03), c(0x2E3F5A))          # спинка
	m.box(Vector3(0, 0.44, 0.02), Vector3(0.5, 0.025, 0.025), c(CHROME))

## Указатель отделений
static func _directory(m: Mesher) -> void:
	m.box(Vector3(0, 0.03, 0), Vector3(0.7, 0.06, 0.3), c(INOX_D))
	m.box(Vector3(0, 1.0, 0), Vector3(0.74, 1.9, 0.07), c(WHITE))
	m.box(Vector3(0, 1.83, 0.037), Vector3(0.74, 0.24, 0.006), c(TEAL))
	m.box(Vector3(-0.24, 1.83, 0.042), Vector3(0.17, 0.17, 0.004), c(BLUE))        # знак больницы
	m.box(Vector3(-0.285, 1.83, 0.046), Vector3(0.03, 0.12, 0.003), c(WHITE))
	m.box(Vector3(-0.195, 1.83, 0.046), Vector3(0.03, 0.12, 0.003), c(WHITE))
	m.box(Vector3(-0.24, 1.83, 0.046), Vector3(0.09, 0.03, 0.003), c(WHITE))
	m.box(Vector3(0.1, 1.83, 0.042), Vector3(0.36, 0.05, 0.004), c(WHITE))
	var cols := [RED, BLUE, O2, YELLOW, 0x8A5AA8, TEAL_D, 0xD07A30]
	for k in 7:
		var y := 1.6 - k * 0.19
		m.box(Vector3(-0.27, y, 0.038), Vector3(0.1, 0.1, 0.006), c(cols[k]))
		m.box(Vector3(-0.02 - (k % 3) * 0.02, y + 0.02, 0.038), Vector3(0.3 - (k % 3) * 0.04, 0.03, 0.004), c(0x3A4048))
		m.box(Vector3(-0.07, y - 0.03, 0.038), Vector3(0.2, 0.016, 0.004), c(0x9AA0A6))
		var ax := 0.27
		m.box(Vector3(ax, y, 0.038), Vector3(0.1, 0.025, 0.004), c(0x3A4048))      # стрелка
		for s in [-1, 1]:
			m.push()
			m.translate(Vector3(ax + (0.04 if k % 2 == 0 else -0.04), y, 0.04))
			m.rot_z((45.0 if k % 2 == 0 else 135.0) * s)
			m.box(Vector3(-0.025, 0, 0), Vector3(0.06, 0.022, 0.004), c(0x3A4048))
			m.pop()

## Журнальный столик
static func _magtable(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.42, 0), Vector3(0.92, 0.04, 0.56), c(WOOD))
	m.box(Vector3(0, 0.16, 0), Vector3(0.82, 0.025, 0.46), c(0x96784F))
	for sx in [-0.42, 0.42]:
		for sz in [-0.24, 0.24]:
			m.box(Vector3(sx, 0.2, sz), Vector3(0.045, 0.4, 0.045), c(0x8A6C46))
	var mags := [RED, BLUE, 0xD07A30, TEAL, YELLOW]
	for k in 3:                                                                   # журналы веером
		m.push()
		m.translate(Vector3(-0.2 + k * 0.07, 0.445 + k * 0.012, 0.02 + k * 0.02))
		m.rot_y(-18.0 + k * 14.0)
		m.box(Vector3.ZERO, Vector3(0.22, 0.012, 0.3), c(mags[(hv + k) % 5]))
		m.box(Vector3(0, 0.007, -0.08), Vector3(0.16, 0.002, 0.06), c(PAPER))
		m.pop()
	m.box(Vector3(0.26, 0.45, -0.06), Vector3(0.24, 0.02, 0.32), c(0xD8D4C4))      # газета
	for k in 4:
		m.box(Vector3(0.26, 0.461, -0.16 + k * 0.06), Vector3(0.19, 0.002, 0.012), c(0x6A6A66))
	m.box(Vector3(0.3, 0.49, 0.2), Vector3(0.2, 0.08, 0.1), c(MINT))               # салфетки
	m.box(Vector3(0.3, 0.535, 0.2), Vector3(0.06, 0.02, 0.03), c(WHITE))
	m.box(Vector3(-0.1, 0.19, 0), Vector3(0.3, 0.04, 0.3), c(mags[(hv + 3) % 5]))  # стопка на нижней полке

## Автомат с закусками
static func _vending(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.04, -0.02), Vector3(0.84, 0.08, 0.68), c(BLACK))
	m.box(Vector3(0, 0.97, -0.02), Vector3(0.88, 1.78, 0.72), c(0x2E3F5A))
	m.box(Vector3(0, 1.74, 0.342), Vector3(0.84, 0.2, 0.008), c(0xE8F0F4, 0.5))    # светящаяся вывеска
	m.box(Vector3(0, 1.74, 0.348), Vector3(0.5, 0.07, 0.004), c(RED))
	m.box(Vector3(-0.13, 1.03, 0.342), Vector3(0.56, 1.14, 0.008), c(0xDCE8EC))    # витрина
	var snacks := [RED, YELLOW, BLUE, 0xD07A30, O2, 0x8A5AA8, WHITE, 0x7A4A22]
	for r in 5:
		m.box(Vector3(-0.13, 0.56 + r * 0.22, 0.347), Vector3(0.56, 0.015, 0.006), c(0x70787E))
		for k in 5:
			if (hv >> (r + k)) % 7 == 0:
				continue
			m.box(Vector3(-0.35 + k * 0.11, 0.64 + r * 0.22, 0.348), Vector3(0.08, 0.13, 0.006), c(snacks[(hv + r * 3 + k) % 8]))
	m.box(Vector3(0.3, 1.2, 0.342), Vector3(0.2, 0.5, 0.008), c(0x1E2A3A))         # панель оплаты
	m.box(Vector3(0.3, 1.38, 0.348), Vector3(0.14, 0.05, 0.004), c(0x58D878, 0.5))
	for k in 9:
		m.box(Vector3(0.26 + (k % 3) * 0.04, 1.28 - (k / 3) * 0.04, 0.348), Vector3(0.028, 0.028, 0.006), c(0xC8CCD0))
	m.box(Vector3(0.3, 1.08, 0.348), Vector3(0.04, 0.012, 0.004), c(BLACK))        # щель для монет
	m.box(Vector3(0.3, 1.01, 0.348), Vector3(0.1, 0.03, 0.004), c(0x70787E))
	m.box(Vector3(-0.13, 0.28, 0.342), Vector3(0.56, 0.2, 0.008), c(BLACK))        # лоток выдачи
	m.box(Vector3(-0.13, 0.33, 0.35), Vector3(0.5, 0.06, 0.008), c(0x4A5058))

## Каталка (на две клетки)
static func _gurney(m: Mesher, hv: int, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	var x1 := x0 + L
	for lx in [x0 + 0.14, x1 - 0.14]:
		for lz in [-0.26, 0.26]:
			_caster(m, Vector3(lx, 0, lz))
			m.box(Vector3(lx, 0.42, lz), Vector3(0.03, 0.62, 0.03), c(CHROME))
	m.box(Vector3(cx, 0.26, 0), Vector3(L - 0.26, 0.03, 0.54), c(INOX_D))          # нижняя рама
	m.box(Vector3(cx, 0.73, 0), Vector3(L, 0.04, 0.68), c(INOX))                   # ложе
	m.box(Vector3(cx, 0.8, 0), Vector3(L - 0.06, 0.1, 0.62), c(PAD))               # матрас
	m.box(Vector3(cx + L * 0.14, 0.86, 0), Vector3(L * 0.66, 0.02, 0.64), c(WHITE))             # простыня
	m.box(Vector3(cx + L * 0.14 - L * 0.33 + 0.06, 0.875, 0), Vector3(0.12, 0.012, 0.64), c(MINT))
	m.box(Vector3(x0 + 0.2, 0.89, 0), Vector3(0.28, 0.07, 0.42), c(WHITE))         # подушка
	for sz in [-0.35, 0.35]:                                                      # боковые поручни
		m.box(Vector3(cx, 0.98, sz), Vector3(L * 0.5, 0.025, 0.025), c(CHROME))
		for k in 3:
			m.box(Vector3(cx - L * 0.24 + k * L * 0.24, 0.86, sz), Vector3(0.02, 0.24, 0.02), c(CHROME))
	m.box(Vector3(x0 - 0.0, 0.95, 0), Vector3(0.025, 0.025, 0.6), c(CHROME))       # ручка у изголовья
	for sz in [-0.3, 0.3]:
		m.box(Vector3(x0, 0.85, sz), Vector3(0.025, 0.22, 0.025), c(CHROME))
	_cyl_x(m, Vector3(cx - 0.3, 0.33, 0.1), 0.6, 0.06, c(O2), 8)                   # баллон кислорода под ложем
	_cyl_x(m, Vector3(cx + 0.3, 0.33, 0.1), 0.06, 0.025, c(CHROME), 6)
	if wide and hv % 2 == 0:                                                      # стойка с капельницей
		m.box(Vector3(x0 + 0.06, 1.3, -0.3), Vector3(0.02, 1.1, 0.02), c(CHROME))
		m.box(Vector3(x0 + 0.06, 1.85, -0.24), Vector3(0.02, 0.02, 0.14), c(CHROME))
		m.box(Vector3(x0 + 0.06, 1.7, -0.19), Vector3(0.11, 0.2, 0.03), c(0xD8E8EE))
		m.box(Vector3(x0 + 0.06, 1.72, -0.173), Vector3(0.07, 0.07, 0.004), c(BLUE))

# ================== палаты ==================
## Больничная койка: длина L, центр cx (вдоль x); изголовье — у меньшего x
static func _hospbed(m: Mesher, hv: int, L: float, cx: float) -> void:
	var x0 := cx - L * 0.5
	var x1 := x0 + L
	var hl := minf(0.72, L * 0.36)                                                # длина поднятой секции
	for lx in [x0 + 0.16, x1 - 0.16]:
		for lz in [-0.36, 0.36]:
			_caster(m, Vector3(lx, 0, lz))
	m.box(Vector3(cx, 0.14, 0), Vector3(L - 0.2, 0.06, 0.76), c(0x9AA0A6))         # рама
	for lx in [x0 + 0.4, x1 - 0.4] if L > 1.2 else [cx]:
		m.box(Vector3(lx, 0.33, 0), Vector3(0.12, 0.34, 0.34), c(INOX_D))          # подъёмные опоры
	m.box(Vector3(cx, 0.53, 0), Vector3(L - 0.08, 0.05, 0.86), c(OFFW))            # ложе
	m.box(Vector3(x0 + 0.025, 0.8, 0), Vector3(0.05, 0.66, 0.9), c(0xD9D4C4))      # изголовье
	m.box(Vector3(x0 + 0.025, 1.14, 0), Vector3(0.06, 0.05, 0.92), c(TEAL))
	m.box(Vector3(x1 - 0.025, 0.7, 0), Vector3(0.05, 0.46, 0.9), c(0xD9D4C4))      # изножье
	m.box(Vector3(x1 - 0.025, 0.94, 0), Vector3(0.06, 0.04, 0.92), c(TEAL))
	var fx0 := x0 + 0.06 + hl                                                     # где кончается поднятая секция
	m.box(Vector3((fx0 + x1 - 0.06) * 0.5, 0.62, 0), Vector3(x1 - 0.06 - fx0, 0.13, 0.82), c(0xE8E6DC))   # матрас
	m.push()                                                                      # поднятое изголовье с подушкой
	m.translate(Vector3(fx0, 0.56, 0))
	m.rot_z(-24)
	m.box(Vector3(-hl * 0.5, 0.065, 0), Vector3(hl, 0.13, 0.82), c(0xE8E6DC))
	m.box(Vector3(-hl * 0.55, 0.17, 0), Vector3(hl * 0.5, 0.08, 0.52), c(WHITE))
	m.pop()
	var bl: int = [0x6E9E97, 0x7F95B5, 0xA9B88A][hv % 3]
	var bx0 := fx0 + 0.12
	m.box(Vector3((bx0 + x1 - 0.07) * 0.5, 0.7, 0), Vector3(x1 - 0.07 - bx0, 0.04, 0.86), c(bl))          # одеяло
	m.box(Vector3(bx0 + 0.07, 0.715, 0), Vector3(0.16, 0.035, 0.86), c(WHITE))    # отворот простыни
	var rl := minf(0.5, hl - 0.06)                                                # ограждения — у изголовья: с середины на койку садятся и ложатся
	for sz in [-0.44, 0.44]:
		for y in [0.86, 0.99]:
			m.box(Vector3(x0 + 0.1 + rl * 0.5, y, sz), Vector3(rl, 0.025, 0.025), c(CHROME))
		for k in 3:
			m.box(Vector3(x0 + 0.1 + k * rl * 0.5, 0.8, sz), Vector3(0.02, 0.4, 0.02), c(CHROME))
	m.box(Vector3(x1 + 0.008, 0.72, 0.1), Vector3(0.014, 0.24, 0.2), c(0x6A4A2C)) # планшет с историей болезни
	m.box(Vector3(x1 + 0.017, 0.71, 0.1), Vector3(0.004, 0.2, 0.17), c(PAPER))

## Прикроватная тумба
static func _bedside(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.03, 0), Vector3(0.44, 0.06, 0.4), c(INOX_D))
	m.box(Vector3(0, 0.36, 0), Vector3(0.48, 0.6, 0.44), c(OFFW))
	m.box(Vector3(0, 0.56, 0.223), Vector3(0.42, 0.14, 0.01), c(WHITE))            # ящик
	m.box(Vector3(0, 0.56, 0.232), Vector3(0.14, 0.022, 0.012), c(TEAL))
	m.box(Vector3(0, 0.27, 0.223), Vector3(0.42, 0.38, 0.01), c(WHITE))            # дверца
	m.box(Vector3(0.15, 0.36, 0.232), Vector3(0.02, 0.1, 0.012), c(TEAL))
	m.box(Vector3(0, 0.675, 0), Vector3(0.52, 0.03, 0.48), c(0xDAD6CB))
	var top := 0.69
	_cyl(m, Vector3(-0.14, top, 0.1), 0.1, 0.03, 0.034, c(0xBFD8E8), 8)            # стакан воды
	_cyl(m, Vector3(-0.02, top, 0.14), 0.07, 0.022, 0.022, c(0xD07A30), 6)         # пузырёк с таблетками
	_cyl(m, Vector3(-0.02, top + 0.07, 0.14), 0.015, 0.024, 0.024, c(WHITE), 6)
	if hv % 2 == 0:                                                               # ваза с цветами
		_cyl(m, Vector3(0.12, top, -0.08), 0.16, 0.04, 0.05, c(0x9CCBEA), 8)
		var fl := [0xE86A8A, YELLOW, 0xF2F0E8, 0xE86A8A]
		for k in 4:
			m.box(Vector3(0.09 + (k % 2) * 0.06, top + 0.25, -0.11 + (k / 2) * 0.06), Vector3(0.008, 0.2, 0.008), c(O2))
			m.ellipsoid(Vector3(0.09 + (k % 2) * 0.06, top + 0.37 + (k % 3) * 0.02, -0.11 + (k / 2) * 0.06), Vector3(0.035, 0.03, 0.035), c(fl[k]), 3, 6)
	else:                                                                         # открытка и книга
		m.push()
		m.translate(Vector3(0.12, top, -0.1))
		m.rot_y(20)
		m.box(Vector3(0, 0.08, 0), Vector3(0.14, 0.16, 0.008), c(0xF2E9A8))
		m.box(Vector3(0, 0.09, 0.006), Vector3(0.05, 0.05, 0.004), c(RED))
		m.pop()
		m.box(Vector3(0.1, top + 0.015, 0.12), Vector3(0.14, 0.03, 0.2), c(0x7A2A22))
	m.box(Vector3(-0.2, top + 0.02, -0.14), Vector3(0.06, 0.04, 0.1), c(BEIGE))    # кнопка вызова медсестры
	m.box(Vector3(-0.2, top + 0.042, -0.14), Vector3(0.03, 0.006, 0.03), c(RED))

## Стойка капельницы
static func _ivstand(m: Mesher, hv: int) -> void:
	_star_base(m, 0.22, 0x9AA0A6)
	_cyl(m, Vector3(0, 0.07, 0), 1.85, 0.013, 0.013, c(CHROME), 6)
	m.box(Vector3(0, 1.92, 0), Vector3(0.32, 0.014, 0.014), c(CHROME))
	m.box(Vector3(0, 1.92, 0), Vector3(0.014, 0.014, 0.2), c(CHROME))
	for k in 2:
		var bx := -0.13 + k * 0.26
		m.box(Vector3(bx, 1.86, 0), Vector3(0.012, 0.1, 0.012), c(CHROME))
		m.box(Vector3(bx, 1.7, 0), Vector3(0.12, 0.22, 0.035), c(0xD8E8EE if k == 0 else 0xE8DDB0))   # пакет с раствором
		m.box(Vector3(bx, 1.71, 0.02), Vector3(0.08, 0.08, 0.004), c(BLUE if k == 0 else RED))
		_cyl(m, Vector3(bx, 1.5, 0), 0.09, 0.014, 0.014, c(0xE8F0F4), 6)           # капельная камера
		m.box(Vector3(bx, 1.22, 0), Vector3(0.007, 0.56, 0.007), c(0xE8F0F4))       # трубка
		m.box(Vector3(bx, 1.2, 0), Vector3(0.03, 0.04, 0.02), c(BLUE))
	if hv % 2 == 0:                                                               # инфузионный насос
		m.box(Vector3(0, 1.05, 0.06), Vector3(0.18, 0.16, 0.1), c(BEIGE))
		m.box(Vector3(-0.02, 1.08, 0.112), Vector3(0.1, 0.05, 0.004), c(0x58D878, 0.5))
		for k in 3:
			m.box(Vector3(-0.05 + k * 0.04, 1.01, 0.112), Vector3(0.025, 0.025, 0.004), c(0x9AA0A6))

## Ширма на колёсиках: клетки подряд — одна длинная
static func _screen(m: Mesher) -> void:
	for k in 4:
		var px := -0.495 + k * 0.33
		var pz := 0.03 if k % 2 == 0 else -0.03
		m.box(Vector3(px, 0.9, pz), Vector3(0.025, 1.7, 0.025), c(CHROME))
		m.box(Vector3(px, 0.03, pz), Vector3(0.03, 0.03, 0.2), c(CHROME))
		_cyl_x(m, Vector3(px - 0.012, 0.03, pz + 0.09), 0.024, 0.03, c(BLACK), 6)
		_cyl_x(m, Vector3(px - 0.012, 0.03, pz - 0.09), 0.024, 0.03, c(BLACK), 6)
	for k in 3:
		m.push()
		m.translate(Vector3(-0.33 + k * 0.33, 0, 0))
		m.rot_y(10.4 if k % 2 == 0 else -10.4)
		m.box(Vector3(0, 0.98, 0), Vector3(0.31, 1.36, 0.012), c(MINT))
		m.box(Vector3(0, 1.7, 0), Vector3(0.33, 0.02, 0.02), c(CHROME))
		m.box(Vector3(0, 0.26, 0), Vector3(0.33, 0.02, 0.02), c(CHROME))
		m.box(Vector3(0, 1.3, 0.008), Vector3(0.31, 0.012, 0.004), c(0xB8D0C8))
		m.pop()

## Монитор пациента на стойке
static func _patmonitor(m: Mesher) -> void:
	_star_base(m, 0.2, 0x9AA0A6)
	_cyl(m, Vector3(0, 0.07, 0), 1.03, 0.02, 0.02, c(CHROME), 8)
	m.box(Vector3(0, 0.7, 0.02), Vector3(0.26, 0.12, 0.2), c(INOX_D))              # корзина с датчиками
	m.box(Vector3(0, 0.77, 0.02), Vector3(0.2, 0.04, 0.14), c(0x3A4048))
	m.box(Vector3(0, 1.11, 0), Vector3(0.3, 0.02, 0.26), c(INOX_D))
	m.box(Vector3(0, 1.27, -0.02), Vector3(0.38, 0.3, 0.3), c(BEIGE))              # корпус
	m.box(Vector3(-0.04, 1.28, 0.132), Vector3(0.27, 0.23, 0.006), c(0x101A16))    # экран
	_ecg(m, Vector3(-0.165, 1.35, 0.137), 0.25, c(0x58D878, 0.5))
	_ecg(m, Vector3(-0.165, 1.27, 0.137), 0.25, c(0x58B8F0, 0.5))
	m.box(Vector3(-0.1, 1.2, 0.137), Vector3(0.1, 0.012, 0.003), c(YELLOW, 0.5))
	m.box(Vector3(0.05, 1.2, 0.137), Vector3(0.05, 0.035, 0.003), c(0x58D878, 0.5))
	for k in 4:
		m.box(Vector3(0.14, 1.36 - k * 0.055, 0.132), Vector3(0.035, 0.035, 0.008), c([0x9AA0A6, 0x9AA0A6, YELLOW, RED][k]))
	m.box(Vector3(0, 1.44, -0.02), Vector3(0.2, 0.03, 0.04), c(BEIGE_D))           # ручка
	m.box(Vector3(0.2, 1.0, 0.0), Vector3(0.014, 0.4, 0.014), c(0x9AA0A6))         # кабель

# ================== хирургия и операционная ==================
## Операционный стол (на две клетки)
static func _optable(m: Mesher, hv: int, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	m.box(Vector3(cx, 0.04, 0), Vector3(0.72, 0.08, 0.5), c(INOX_D))               # основание
	m.box(Vector3(cx, 0.3, 0), Vector3(0.24, 0.46, 0.28), c(INOX))                 # колонна
	m.box(Vector3(cx, 0.6, 0), Vector3(0.3, 0.16, 0.34), c(0x3A4048))
	m.box(Vector3(cx + 0.2, 0.12, 0.2), Vector3(0.12, 0.05, 0.08), c(BLACK))       # педаль
	m.box(Vector3(cx, 0.71, 0), Vector3(L - 0.12, 0.05, 0.5), c(INOX))             # рама ложа
	for sz in [-0.27, 0.27]:
		m.box(Vector3(cx, 0.71, sz), Vector3(L - 0.5, 0.025, 0.02), c(CHROME))     # боковые рейки
	var hl := L * 0.17
	var tl := L * 0.46
	var ll := L - hl - tl - 0.1
	m.push()                                                                      # подголовник чуть поднят
	m.translate(Vector3(x0 + 0.05 + hl, 0.74, 0))
	m.rot_z(-10)
	m.box(Vector3(-hl * 0.5, 0.035, 0), Vector3(hl - 0.02, 0.07, 0.3), c(PAD))
	m.pop()
	m.box(Vector3(x0 + 0.06 + hl + tl * 0.5, 0.775, 0), Vector3(tl - 0.02, 0.07, 0.52), c(PAD))
	m.box(Vector3(x0 + 0.07 + hl + tl + ll * 0.5, 0.775, 0), Vector3(ll - 0.02, 0.07, 0.52), c(PAD))
	m.box(Vector3(x0 + 0.06 + hl + 0.2, 0.765, 0.36), Vector3(0.14, 0.04, 0.22), c(PAD))        # подлокотник
	if hv % 3 != 0:                                                               # стерильная простыня
		var dx := x0 + 0.06 + hl + tl * 0.55 + ll * 0.5
		var dl := tl * 0.5 + ll
		m.box(Vector3(dx, 0.818, 0), Vector3(dl, 0.016, 0.56), c(SURG))
		for sz in [-0.283, 0.283]:
			m.box(Vector3(dx, 0.72, sz), Vector3(dl, 0.2, 0.012), c(SURG))
	m.box(Vector3(cx - 0.3, 0.6, 0.29), Vector3(0.06, 0.12, 0.03), c(BEIGE))       # пульт

## Операционный светильник на стойке: плафон вынесен вперёд, над столом
static func _surglight(m: Mesher) -> void:
	m.box(Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.5), c(0x9AA0A6))
	for sx in [-0.2, 0.2]:
		for sz in [-0.2, 0.2]:
			_cyl_x(m, Vector3(sx - 0.012, 0.03, sz), 0.024, 0.03, c(BLACK), 6)
	_cyl(m, Vector3(0, 0.1, 0), 2.0, 0.035, 0.03, c(OFFW), 8)
	m.box(Vector3(0, 2.08, 0.41), Vector3(0.06, 0.06, 0.88), c(OFFW))              # плечо
	m.box(Vector3(0, 1.2, -0.06), Vector3(0.12, 0.2, 0.08), c(BEIGE))              # блок питания
	m.box(Vector3(0, 1.24, -0.018), Vector3(0.03, 0.03, 0.006), c(0x58D878, 0.5))
	_cyl(m, Vector3(0, 1.98, 0.84), 0.1, 0.03, 0.03, c(OFFW), 8)
	m.push()
	m.translate(Vector3(0, 1.88, 0.84))
	m.rot_x(-8)
	m.tube(0.0, 0.1, 0.3, 0.22, c(OFFW), 14)                                       # плафон
	m.tube(0.0, 0.03, 0.31, 0.31, c(INOX_D), 14)                                   # обод
	m.tube(0.1, 0.13, 0.12, 0.1, c(INOX), 10)                                      # шарнир сверху
	for k in 3:
		m.push()
		m.rot_y(k * 120.0)
		m.box(Vector3(0, 0.075, 0.2), Vector3(0.03, 0.06, 0.16), c(INOX_D))        # рёбра охлаждения
		m.pop()
	m.tube(-0.012, 0.0, 0.27, 0.27, c(0xFFF6D8, 0.5), 14)                          # свет
	m.tube(-0.1, -0.012, 0.025, 0.02, c(CHROME), 6)                                # стерильная ручка
	for k in 6:
		m.push()
		m.rot_y(k * 60.0)
		m.box(Vector3(0, -0.014, 0.17), Vector3(0.09, 0.006, 0.09), c(0xFFFFFF, 0.5))
		m.pop()
	m.pop()

## Наркозный аппарат
static func _anesthesia(m: Mesher) -> void:
	for sx in [-0.24, 0.24]:
		for sz in [-0.2, 0.2]:
			_caster(m, Vector3(sx, 0, sz))
	m.box(Vector3(0, 0.46, 0), Vector3(0.58, 0.7, 0.5), c(0xC9CFD2))               # тумба с ящиками
	for d in 3:
		m.box(Vector3(0, 0.24 + d * 0.2, 0.253), Vector3(0.52, 0.17, 0.01), c(0xD8DDE0))
		m.box(Vector3(0, 0.27 + d * 0.2, 0.262), Vector3(0.16, 0.02, 0.012), c(0x70787E))
	m.box(Vector3(0, 0.83, 0.02), Vector3(0.62, 0.03, 0.56), c(INOX))              # рабочая полка
	m.box(Vector3(0, 1.2, -0.21), Vector3(0.58, 0.72, 0.08), c(0xC9CFD2))          # стойка приборов
	for k in 3:                                                                   # ротаметры
		m.box(Vector3(-0.18 + k * 0.06, 1.24, -0.165), Vector3(0.022, 0.26, 0.012), c(0xE8F0F4))
		m.box(Vector3(-0.18 + k * 0.06, 1.18 + k * 0.04, -0.158), Vector3(0.016, 0.02, 0.006), c([BLUE, O2, 0x9AA0A6][k]))
		_cyl_z(m, Vector3(-0.18 + k * 0.06, 1.06, -0.17), 0.03, 0.018, c([BLUE, O2, 0x9AA0A6][k]), 6)
	for k in 2:                                                                   # испарители
		m.box(Vector3(0.06 + k * 0.13, 1.0, -0.12), Vector3(0.11, 0.16, 0.12), c([0x8A5AA8, YELLOW][k]))
		_cyl(m, Vector3(0.06 + k * 0.13, 1.08, -0.12), 0.03, 0.04, 0.04, c(BLACK), 8)
	_cyl(m, Vector3(0.16, 1.18, -0.12), 0.24, 0.07, 0.07, c(0xE8F0F4), 10)         # мех в колбе
	_cyl(m, Vector3(0.16, 1.18, -0.12), 0.14, 0.055, 0.055, c(BLACK), 10)
	m.box(Vector3(0, 1.58, -0.21), Vector3(0.62, 0.03, 0.26), c(INOX))             # верхняя полка с монитором
	m.box(Vector3(-0.08, 1.74, -0.21), Vector3(0.36, 0.28, 0.24), c(BEIGE))
	m.box(Vector3(-0.1, 1.75, -0.088), Vector3(0.26, 0.2, 0.006), c(0x101A16))
	_ecg(m, Vector3(-0.22, 1.8, -0.083), 0.24, c(0x58D878, 0.5))
	_ecg(m, Vector3(-0.22, 1.72, -0.083), 0.24, c(YELLOW, 0.5))
	for k in 2:                                                                   # гофрированные шланги
		m.push()
		m.translate(Vector3(-0.2 + k * 0.08, 0.9, 0.1))
		m.rot_x(40)
		m.tube(0.0, 0.34, 0.022, 0.022, c(0x9AA0A6), 6)
		m.pop()
	m.ellipsoid(Vector3(-0.16, 0.86, 0.34), Vector3(0.05, 0.035, 0.06), c(0xBFD8E0), 3, 8)       # маска
	m.ellipsoid(Vector3(0.36, 0.7, 0.1), Vector3(0.07, 0.12, 0.07), c(O2), 4, 8)                 # дыхательный мешок
	for k in 2:                                                                   # баллоны сзади
		_cyl(m, Vector3(-0.14 + k * 0.28, 0.1, -0.31), 0.62, 0.06, 0.06, c([O2, BLUE][k]), 8)
		_cyl(m, Vector3(-0.14 + k * 0.28, 0.72, -0.31), 0.06, 0.03, 0.02, c(CHROME), 6)

## Инструментальный столик
static func _instrtable(m: Mesher) -> void:
	for sx in [-0.36, 0.36]:
		for sz in [-0.21, 0.21]:
			_caster(m, Vector3(sx, 0, sz))
			m.box(Vector3(sx, 0.48, sz), Vector3(0.025, 0.78, 0.025), c(CHROME))
	m.box(Vector3(0, 0.3, 0), Vector3(0.76, 0.02, 0.46), c(INOX))
	m.box(Vector3(0, 0.88, 0), Vector3(0.82, 0.025, 0.52), c(INOX))                # верхний лоток
	for sz in [-0.26, 0.26]:
		m.box(Vector3(0, 0.905, sz), Vector3(0.82, 0.03, 0.012), c(CHROME))
	m.box(Vector3(-0.1, 0.897, 0), Vector3(0.58, 0.008, 0.5), c(SURG))             # стерильная салфетка
	m.box(Vector3(-0.1, 0.83, 0.262), Vector3(0.58, 0.14, 0.008), c(SURG))
	var lens := [0.16, 0.14, 0.18, 0.13, 0.17, 0.15, 0.12]
	for k in 7:                                                                   # инструменты в ряд
		m.push()
		m.translate(Vector3(-0.33 + k * 0.07, 0.905, 0.04))
		m.rot_y((k % 3 - 1) * 5.0)
		m.box(Vector3.ZERO, Vector3(0.014, 0.008, lens[k]), c(CHROME))
		if k % 2 == 0:
			m.box(Vector3(0, 0, lens[k] * 0.5), Vector3(0.04, 0.008, 0.03), c(CHROME))          # кольца ножниц и зажимов
		m.pop()
	m.ellipsoid(Vector3(0.3, 0.95, -0.1), Vector3(0.1, 0.05, 0.06), c(INOX), 3, 8, 0.5, 1.0)     # почкообразный лоток
	m.box(Vector3(0.28, 0.915, 0.12), Vector3(0.12, 0.05, 0.12), c(WHITE))        # салфетки
	_cyl(m, Vector3(-0.3, 0.9, -0.16), 0.06, 0.06, 0.07, c(INOX), 10)              # чаша
	m.box(Vector3(-0.15, 0.36, 0), Vector3(0.34, 0.1, 0.3), c(SURG))               # бельё на нижней полке
	_cyl(m, Vector3(0.2, 0.31, 0), 0.1, 0.12, 0.14, c(INOX), 10)

## Хирургическая мойка: два локтевых смесителя
static func _scrubsink(m: Mesher) -> void:
	for sx in [-0.45, 0.45]:
		m.box(Vector3(sx, 0.28, -0.04), Vector3(0.05, 0.56, 0.44), c(INOX_D))
	m.box(Vector3(0, 0.72, -0.04), Vector3(0.98, 0.36, 0.5), c(INOX))              # корыто
	m.box(Vector3(0, 0.902, -0.04), Vector3(0.9, 0.006, 0.42), c(0x6F767B))
	m.box(Vector3(0, 1.22, -0.3), Vector3(0.98, 0.64, 0.03), c(INOX))              # стенка
	for k in 2:
		var fx := -0.24 + k * 0.48
		m.box(Vector3(fx, 1.26, -0.2), Vector3(0.028, 0.028, 0.2), c(CHROME))      # излив
		m.box(Vector3(fx, 1.2, -0.1), Vector3(0.028, 0.12, 0.028), c(CHROME))
		m.box(Vector3(fx + 0.1, 1.12, -0.24), Vector3(0.16, 0.02, 0.025), c(CHROME))            # локтевой рычаг
		m.box(Vector3(fx, 1.42, -0.27), Vector3(0.08, 0.16, 0.06), c(WHITE))       # дозатор мыла
		m.box(Vector3(fx, 1.37, -0.235), Vector3(0.05, 0.04, 0.012), c(BLUE))
		m.box(Vector3(fx, 0.03, 0.16), Vector3(0.16, 0.03, 0.1), c(0x3A4048))      # педаль
	_cyl_z(m, Vector3(0, 1.42, -0.285), 0.02, 0.08, c(WHITE), 12)                  # таймер-часы
	m.box(Vector3(0, 1.44, -0.262), Vector3(0.008, 0.06, 0.004), c(BLACK))
	m.box(Vector3(0.02, 1.42, -0.262), Vector3(0.05, 0.008, 0.004), c(RED))
	m.box(Vector3(0, 1.1, -0.27), Vector3(0.16, 0.08, 0.04), c(INOX_D))            # щётки

## Негатоскоп с рентгеновскими снимками
static func _xrayview(m: Mesher, hv: int) -> void:
	var z := -0.03
	for sx in [-0.46, 0.46]:
		m.box(Vector3(sx, 0.9, z), Vector3(0.035, 1.8, 0.035), c(INOX))
		m.box(Vector3(sx, 0.015, z + 0.02), Vector3(0.05, 0.03, 0.14), c(INOX))
	m.box(Vector3(0, 1.5, z), Vector3(0.96, 0.6, 0.08), c(OFFW))
	m.box(Vector3(0, 1.5, z + 0.042), Vector3(0.9, 0.52, 0.006), c(0xEAF6FA, 0.5)) # светящееся стекло
	var zf := z + 0.048
	for k in 2:
		var fx := -0.23 + k * 0.46
		if k == 1 and hv % 3 == 0:
			continue
		m.box(Vector3(fx, 1.5, zf), Vector3(0.36, 0.46, 0.004), c(0x1A2632))       # плёнка
		m.box(Vector3(fx, 1.74, zf + 0.004), Vector3(0.08, 0.03, 0.006), c(CHROME))
		if (hv + k) % 2 == 0:                                                     # грудная клетка
			m.box(Vector3(fx, 1.5, zf + 0.004), Vector3(0.03, 0.36, 0.003), c(0xB8D0DC))
			for r in 5:
				for s in [-1, 1]:
					_line(m, Vector2(fx + s * 0.02, 1.62 - r * 0.055), Vector2(fx + s * 0.14, 1.59 - r * 0.055), zf + 0.005, c(0xB8D0DC), 0.014)
		else:                                                                     # кость с переломом
			_line(m, Vector2(fx - 0.03, 1.7), Vector2(fx + 0.0, 1.52), zf + 0.005, c(0xB8D0DC), 0.045)
			_line(m, Vector2(fx + 0.03, 1.49), Vector2(fx - 0.02, 1.3), zf + 0.005, c(0xB8D0DC), 0.045)
			m.box(Vector3(fx - 0.03, 1.71, zf + 0.005), Vector3(0.09, 0.05, 0.003), c(0xB8D0DC))
	m.box(Vector3(0.4, 1.17, z + 0.03), Vector3(0.04, 0.03, 0.02), c(RED, 0.5))    # выключатель
	m.box(Vector3(0, 1.0, z + 0.04), Vector3(0.7, 0.03, 0.1), c(INOX))             # полка с конвертами
	m.box(Vector3(-0.1, 1.07, z + 0.04), Vector3(0.36, 0.12, 0.04), c(0xD9C58A))

## Стерилизатор (автоклав) на тумбе
static func _sterilizer(m: Mesher) -> void:
	m.box(Vector3(0, 0.04, -0.02), Vector3(0.8, 0.08, 0.5), c(BLACK))
	m.box(Vector3(0, 0.46, -0.02), Vector3(0.84, 0.76, 0.56), c(INOX))
	m.box(Vector3(0, 0.46, 0.262), Vector3(0.78, 0.68, 0.008), c(0xC8CCD0))
	m.box(Vector3(0.3, 0.5, 0.272), Vector3(0.02, 0.2, 0.014), c(INOX_D))
	m.box(Vector3(0, 0.86, -0.02), Vector3(0.88, 0.04, 0.6), c(CHROME))
	var top := 0.88
	_cyl_z(m, Vector3(-0.14, top + 0.25, -0.26), 0.5, 0.24, c(INOX), 14)           # камера
	_cyl_z(m, Vector3(-0.14, top + 0.25, 0.24), 0.035, 0.25, c(INOX_D), 14)        # дверца
	_cyl_z(m, Vector3(-0.14, top + 0.25, 0.275), 0.03, 0.05, c(BLACK), 8)
	for k in 2:
		m.push()
		m.translate(Vector3(-0.14, top + 0.25, 0.295))
		m.rot_z(45.0 + k * 90.0)
		m.box(Vector3.ZERO, Vector3(0.36, 0.03, 0.02), c(CHROME))                  # штурвал
		m.pop()
	m.box(Vector3(0.28, top + 0.2, -0.05), Vector3(0.22, 0.4, 0.36), c(0xC9CFD2))  # блок управления
	for k in 2:
		_cyl_z(m, Vector3(0.28, top + 0.3 - k * 0.13, 0.13), 0.012, 0.05, c(WHITE), 10)         # манометры
		m.box(Vector3(0.29, top + 0.31 - k * 0.13, 0.145), Vector3(0.006, 0.04, 0.003), c(RED))
	m.box(Vector3(0.24, top + 0.06, 0.132), Vector3(0.03, 0.03, 0.006), c(0x58D878, 0.5))
	m.box(Vector3(0.32, top + 0.06, 0.132), Vector3(0.03, 0.03, 0.006), c(RED, 0.5))
	m.box(Vector3(0.28, top + 0.44, -0.05), Vector3(0.2, 0.08, 0.26), c(SURG))     # свёртки с инструментами

## Тележка с дефибриллятором
static func _defib(m: Mesher) -> void:
	for sx in [-0.24, 0.24]:
		for sz in [-0.18, 0.18]:
			_caster(m, Vector3(sx, 0, sz))
	m.box(Vector3(0, 0.5, 0), Vector3(0.6, 0.78, 0.46), c(0xB5302A))               # красная тележка
	for d in 5:
		m.box(Vector3(0, 0.2 + d * 0.15, 0.233), Vector3(0.54, 0.12, 0.01), c(0xC8423A))
		m.box(Vector3(0, 0.22 + d * 0.15, 0.242), Vector3(0.2, 0.02, 0.012), c(0xD8DDE0))
		m.box(Vector3(-0.2, 0.19 + d * 0.15, 0.24), Vector3(0.08, 0.04, 0.004), c(PAPER))
	m.box(Vector3(0, 0.905, 0), Vector3(0.64, 0.03, 0.5), c(0xD8DDE0))
	m.box(Vector3(-0.34, 0.86, 0), Vector3(0.03, 0.03, 0.4), c(CHROME))            # ручка
	var top := 0.92
	m.box(Vector3(-0.04, top + 0.12, -0.04), Vector3(0.4, 0.24, 0.32), c(BEIGE))   # дефибриллятор
	m.box(Vector3(-0.1, top + 0.14, 0.122), Vector3(0.2, 0.14, 0.006), c(0x101A16))
	_ecg(m, Vector3(-0.19, top + 0.15, 0.127), 0.18, c(0x58D878, 0.5))
	m.box(Vector3(0.08, top + 0.18, 0.122), Vector3(0.06, 0.05, 0.008), c(RED))
	m.box(Vector3(0.08, top + 0.1, 0.122), Vector3(0.06, 0.05, 0.008), c(YELLOW))
	for k in 2:                                                                   # электроды
		m.box(Vector3(-0.14 + k * 0.2, top + 0.27, -0.04), Vector3(0.12, 0.05, 0.16), c(BLACK))
		m.box(Vector3(-0.14 + k * 0.2, top + 0.32, -0.04), Vector3(0.04, 0.05, 0.1), c(0x3A4048))
	m.box(Vector3(0.24, top + 0.04, 0.1), Vector3(0.12, 0.08, 0.14), c(YELLOW))    # контейнер для игл
	m.box(Vector3(0.24, top + 0.09, 0.1), Vector3(0.13, 0.02, 0.15), c(RED))
	_cyl(m, Vector3(0.38, 0.1, -0.05), 0.6, 0.065, 0.065, c(O2), 8)                # кислород сбоку
	_cyl(m, Vector3(0.38, 0.7, -0.05), 0.07, 0.03, 0.02, c(CHROME), 6)
	_cyl_z(m, Vector3(0.38, 0.8, -0.03), 0.02, 0.04, c(WHITE), 8)
	m.box(Vector3(0.28, 1.4, -0.2), Vector3(0.02, 0.96, 0.02), c(CHROME))          # стойка с раствором
	m.box(Vector3(0.28, 1.87, -0.14), Vector3(0.02, 0.02, 0.14), c(CHROME))
	m.box(Vector3(0.28, 1.72, -0.09), Vector3(0.11, 0.2, 0.03), c(0xD8E8EE))
	m.box(Vector3(0, 0.6, -0.236), Vector3(0.5, 0.6, 0.012), c(0x8A5A30))          # доска для массажа сердца

## Баллоны с кислородом в стойке
static func _oxygen(m: Mesher) -> void:
	m.box(Vector3(0, 0.03, 0), Vector3(0.86, 0.06, 0.36), c(0x3A4048))
	for sx in [-0.43, 0.43]:
		m.box(Vector3(sx, 0.55, -0.15), Vector3(0.03, 1.0, 0.03), c(0x3A4048))
	m.box(Vector3(0, 1.0, -0.15), Vector3(0.86, 0.04, 0.03), c(0x3A4048))
	m.box(Vector3(0, 0.95, 0.14), Vector3(0.86, 0.02, 0.012), c(CHROME))           # цепь
	var cols := [O2, O2, BLUE]
	for k in 3:
		var bx := -0.27 + k * 0.27
		_cyl(m, Vector3(bx, 0.06, 0), 1.2, 0.11, 0.11, c(cols[k]), 12)
		m.ellipsoid(Vector3(bx, 1.26, 0), Vector3(0.11, 0.09, 0.11), c(WHITE if k < 2 else cols[k]), 3, 12, 0.0, 0.5)
		_cyl(m, Vector3(bx, 1.33, 0), 0.08, 0.03, 0.025, c(CHROME), 6)
		m.box(Vector3(bx, 0.8, 0.106), Vector3(0.12, 0.14, 0.008), c(PAPER))
		m.box(Vector3(bx, 0.82, 0.111), Vector3(0.07, 0.03, 0.004), c(cols[k]))
		if k == 0:                                                                # редуктор с манометром
			m.box(Vector3(bx, 1.4, 0.04), Vector3(0.05, 0.05, 0.1), c(CHROME))
			_cyl_z(m, Vector3(bx, 1.42, 0.09), 0.02, 0.04, c(WHITE), 8)
		else:
			_cyl(m, Vector3(bx, 1.4, 0), 0.07, 0.045, 0.045, c(0x3A4048), 8)       # колпак

## Контейнеры для медицинских отходов
static func _biobins(m: Mesher) -> void:
	_cyl(m, Vector3(-0.24, 0.0, 0), 0.56, 0.16, 0.18, c(WHITE), 12)                # педальное ведро
	_cyl(m, Vector3(-0.24, 0.56, 0), 0.03, 0.19, 0.19, c(RED), 12)
	_cyl(m, Vector3(-0.24, 0.59, 0), 0.03, 0.185, 0.16, c(WHITE), 12)              # крышка
	m.box(Vector3(-0.24, 0.63, 0), Vector3(0.1, 0.02, 0.03), c(INOX_D))
	m.box(Vector3(-0.24, 0.02, 0.2), Vector3(0.1, 0.02, 0.06), c(BLACK))
	m.box(Vector3(-0.24, 0.3, 0.172), Vector3(0.12, 0.12, 0.006), c(YELLOW))
	m.box(Vector3(-0.24, 0.3, 0.176), Vector3(0.06, 0.06, 0.004), c(BLACK))
	m.box(Vector3(0.22, 0.24, 0), Vector3(0.3, 0.48, 0.3), c(YELLOW))              # контейнер для игл
	m.box(Vector3(0.22, 0.5, 0), Vector3(0.32, 0.05, 0.32), c(RED))
	m.box(Vector3(0.22, 0.53, 0), Vector3(0.14, 0.012, 0.08), c(BLACK))
	m.box(Vector3(0.22, 0.28, 0.152), Vector3(0.16, 0.16, 0.006), c(RED))
	m.box(Vector3(0.22, 0.28, 0.156), Vector3(0.08, 0.08, 0.004), c(BLACK))
	m.box(Vector3(0.22, 0.14, 0.152), Vector3(0.2, 0.03, 0.006), c(BLACK))

## Шкаф с инструментами за стеклом
static func _surgcab(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.04, -0.01), Vector3(0.86, 0.08, 0.4), c(INOX_D))
	m.box(Vector3(0, 0.42, -0.01), Vector3(0.9, 0.68, 0.44), c(OFFW))              # низ с дверцами
	for k in 2:
		m.box(Vector3(-0.22 + k * 0.44, 0.42, 0.213), Vector3(0.42, 0.62, 0.01), c(WHITE))
		m.box(Vector3(-0.05 + k * 0.1, 0.5, 0.222), Vector3(0.02, 0.12, 0.012), c(TEAL))
	m.box(Vector3(0, 1.3, -0.2), Vector3(0.9, 1.08, 0.04), c(0xC8D4D8))            # задняя стенка
	for sx in [-0.435, 0.435]:
		m.box(Vector3(sx, 1.3, -0.01), Vector3(0.03, 1.08, 0.44), c(OFFW))
	m.box(Vector3(0, 1.86, -0.01), Vector3(0.9, 0.04, 0.44), c(OFFW))
	m.box(Vector3(0, 0.78, -0.01), Vector3(0.9, 0.04, 0.44), c(OFFW))
	for s in 2:
		m.box(Vector3(0, 1.14 + s * 0.36, -0.02), Vector3(0.84, 0.015, 0.38), c(GLASS))         # стеклянные полки
	for s in 3:
		var sy := 0.8 + s * 0.36 + (0.007 if s > 0 else 0.0)
		match (hv + s) % 3:
			0:                                                                    # лотки с инструментами
				for k in 2:
					m.box(Vector3(-0.2 + k * 0.4, sy + 0.03, 0.0), Vector3(0.32, 0.05, 0.24), c(INOX))
					for j in 4:
						m.box(Vector3(-0.3 + k * 0.4 + j * 0.06, sy + 0.06, 0.0), Vector3(0.014, 0.008, 0.18), c(CHROME))
			1:                                                                    # банки и флаконы
				for k in 5:
					if k % 2 == 0:
						_bottle(m, Vector3(-0.32 + k * 0.16, sy, 0.02), 0.16)
					else:
						_cyl(m, Vector3(-0.32 + k * 0.16, sy, 0.02), 0.2, 0.05, 0.05, c(0xE8F0F4), 8)
						_cyl(m, Vector3(-0.32 + k * 0.16, sy + 0.2, 0.02), 0.02, 0.055, 0.055, c(INOX), 8)
			2:                                                                    # бинты и коробки перчаток
				for k in 4:
					_cyl_z(m, Vector3(-0.33 + k * 0.1, sy + 0.04, -0.06), 0.14, 0.04, c(WHITE), 8)
				m.box(Vector3(0.24, sy + 0.05, 0.0), Vector3(0.24, 0.1, 0.14), c(BLUE))
				m.box(Vector3(0.24, sy + 0.14, 0.0), Vector3(0.24, 0.08, 0.14), c(0x9DB4D0))
	m.box(Vector3(0, 1.3, 0.2), Vector3(0.03, 1.08, 0.02), c(OFFW))                # рамы стеклянных дверец
	for y in [0.82, 1.82]:
		m.box(Vector3(0, y, 0.2), Vector3(0.9, 0.04, 0.02), c(OFFW))
	for sx in [-0.07, 0.07]:
		m.box(Vector3(sx, 1.3, 0.214), Vector3(0.02, 0.14, 0.012), c(CHROME))

# ================== процедурная ==================
## Смотровая кушетка (на две клетки)
static func _examtable(m: Mesher, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	var x1 := x0 + L
	var hl := minf(0.5, L * 0.3)
	m.box(Vector3(cx, 0.03, 0), Vector3(L - 0.3, 0.06, 0.5), c(INOX_D))
	m.box(Vector3(cx, 0.31, 0), Vector3(L - 0.22, 0.5, 0.58), c(OFFW))             # тумба с ящиками
	var n := 3 if wide else 2
	var dw := (L - 0.26) / n
	for k in n:
		var dx := x0 + 0.13 + dw * (k + 0.5)
		m.box(Vector3(dx, 0.31, 0.293), Vector3(dw - 0.03, 0.42, 0.01), c(WHITE))
		m.box(Vector3(dx, 0.44, 0.302), Vector3(0.12, 0.022, 0.012), c(TEAL))
	m.box(Vector3(cx, 0.58, 0), Vector3(L, 0.04, 0.64), c(INOX_D))
	var fx0 := x0 + 0.03 + hl
	m.box(Vector3((fx0 + x1 - 0.02) * 0.5, 0.65, 0), Vector3(x1 - 0.02 - fx0, 0.1, 0.62), c(0x3F6B6A))    # подушка кушетки
	m.push()
	m.translate(Vector3(fx0, 0.6, 0))
	m.rot_z(-20)
	m.box(Vector3(-hl * 0.5, 0.05, 0), Vector3(hl, 0.1, 0.62), c(0x3F6B6A))        # подголовник
	m.box(Vector3(-hl * 0.5, 0.103, 0), Vector3(hl - 0.04, 0.006, 0.5), c(WHITE))
	m.pop()
	m.box(Vector3((fx0 + x1 - 0.1) * 0.5, 0.703, 0), Vector3(x1 - 0.1 - fx0, 0.006, 0.5), c(WHITE))        # бумажная простыня
	_cyl_z(m, Vector3(x0 + 0.02, 0.56, -0.26), 0.52, 0.06, c(WHITE), 8)            # рулон бумаги
	m.box(Vector3(x0 + 0.03 + hl * 0.45, 0.6 + hl * 0.36 + 0.08, 0), Vector3(0.2, 0.06, 0.34), c(WHITE))   # подушка

## Весы с ростомером
static func _scale(m: Mesher) -> void:
	m.box(Vector3(0, 0.04, 0.04), Vector3(0.42, 0.08, 0.5), c(0x9AA0A6))
	m.box(Vector3(0, 0.085, 0.06), Vector3(0.36, 0.01, 0.4), c(BLACK))             # резиновый коврик
	m.box(Vector3(0, 0.72, -0.2), Vector3(0.07, 1.36, 0.06), c(WHITE))             # стойка
	m.box(Vector3(0, 1.42, -0.17), Vector3(0.44, 0.07, 0.07), c(CHROME))           # коромысло
	m.box(Vector3(-0.08, 1.42, -0.13), Vector3(0.05, 0.09, 0.03), c(BLACK))        # гири
	m.box(Vector3(0.12, 1.445, -0.13), Vector3(0.03, 0.05, 0.03), c(BLACK))
	for k in 8:
		m.box(Vector3(-0.19 + k * 0.054, 1.42, -0.134), Vector3(0.004, 0.04, 0.003), c(BLACK))
	m.box(Vector3(0.04, 1.5, -0.24), Vector3(0.025, 1.0, 0.012), c(CHROME))        # ростомер
	for k in 9:
		m.box(Vector3(0.04, 1.1 + k * 0.1, -0.232), Vector3(0.025, 0.006, 0.003), c(BLACK))
	m.box(Vector3(0.04, 1.86, -0.12), Vector3(0.18, 0.015, 0.24), c(CHROME))       # планка на голову

## Процедурная тележка
static func _medcart(m: Mesher) -> void:
	for sx in [-0.36, 0.36]:
		for sz in [-0.19, 0.19]:
			_caster(m, Vector3(sx, 0, sz))
			m.box(Vector3(sx, 0.47, sz), Vector3(0.025, 0.76, 0.025), c(CHROME))
	m.box(Vector3(-0.42, 0.9, 0), Vector3(0.025, 0.025, 0.4), c(CHROME))
	for y in [0.3, 0.84]:
		m.box(Vector3(0, y, 0), Vector3(0.78, 0.02, 0.44), c(INOX))
		for sz in [-0.22, 0.22]:
			m.box(Vector3(0, y + 0.03, sz), Vector3(0.78, 0.04, 0.012), c(CHROME))
	var top := 0.85
	for k in 3:
		_bottle(m, Vector3(-0.3 + k * 0.09, top, -0.12), 0.14 + (k % 2) * 0.03)
	_cyl(m, Vector3(-0.02, top, -0.12), 0.14, 0.05, 0.05, c(0xE8F0F4), 8)          # банка с ватой
	_cyl(m, Vector3(-0.02, top + 0.01, -0.12), 0.1, 0.042, 0.042, c(WHITE), 8)
	_cyl(m, Vector3(-0.02, top + 0.14, -0.12), 0.02, 0.055, 0.055, c(INOX), 8)
	m.box(Vector3(0.2, top + 0.015, 0.06), Vector3(0.3, 0.03, 0.2), c(INOX))       # лоток со шприцами
	for k in 4:
		m.box(Vector3(0.1 + k * 0.065, top + 0.04, 0.06), Vector3(0.025, 0.02, 0.14), c(WHITE))
		m.box(Vector3(0.1 + k * 0.065, top + 0.04, 0.14), Vector3(0.008, 0.008, 0.05), c(BLUE))
	m.ellipsoid(Vector3(-0.22, top + 0.05, 0.1), Vector3(0.1, 0.05, 0.06), c(INOX), 3, 8, 0.5, 1.0)
	for k in 3:
		_cyl_z(m, Vector3(0.14 + k * 0.08, top + 0.04, -0.2), 0.1, 0.035, c(WHITE), 8)          # бинты
	m.box(Vector3(-0.2, 0.37, 0), Vector3(0.24, 0.1, 0.14), c(BLUE))               # перчатки
	m.box(Vector3(0.18, 0.35, -0.04), Vector3(0.26, 0.08, 0.2), c(0x70787E))       # тонометр
	_cyl_z(m, Vector3(0.18, 0.42, -0.04), 0.02, 0.05, c(WHITE), 10)
	m.box(Vector3(0.24, 0.36, 0.13), Vector3(0.12, 0.1, 0.1), c(YELLOW))

# ================== склад медикаментов ==================
## Стеллаж с медикаментами
static func _medshelf(m: Mesher, hv: int) -> void:
	for sx in [-0.45, 0.45]:
		for sz in [-0.24, 0.2]:
			m.box(Vector3(sx, 0.94, sz), Vector3(0.035, 1.88, 0.035), c(OFFW))
	for s in 5:
		var sy := 0.08 + s * 0.44
		m.box(Vector3(0, sy, -0.02), Vector3(0.92, 0.03, 0.48), c(WHITE))
		if s == 4:
			break
		var by := sy + 0.015
		var stripes := [RED, BLUE, O2, 0xD07A30, 0x8A5AA8, TEAL]
		match (hv + s) % 4:
			0:                                                                    # упаковки лекарств в два ряда
				for k in 7:
					for j in 2:
						var bh := 0.1 + ((hv >> (k + j)) % 3) * 0.02
						m.box(Vector3(-0.36 + k * 0.12, by + j * 0.13 + bh * 0.5, 0.08), Vector3(0.1, bh, 0.16), c(WHITE))
						m.box(Vector3(-0.36 + k * 0.12, by + j * 0.13 + bh * 0.5, 0.162), Vector3(0.1, bh * 0.4, 0.004), c(stripes[(hv + k + j * 2) % 6]))
			1:                                                                    # флаконы
				for k in 9:
					_bottle(m, Vector3(-0.38 + k * 0.095, by, 0.1), 0.15 + (k % 3) * 0.02, AMBER if k % 4 != 3 else 0xE8F0F4)
				for k in 6:
					_cyl(m, Vector3(-0.35 + k * 0.14, by, -0.06), 0.24, 0.05, 0.05, c(WHITE), 8)
					m.box(Vector3(-0.35 + k * 0.14, by + 0.12, -0.01), Vector3(0.06, 0.08, 0.006), c(stripes[k]))
			2:                                                                    # лотки-ячейки с мелочью
				for k in 4:
					var colr: int = [BLUE, YELLOW, RED, O2][(hv + k) % 4]
					m.box(Vector3(-0.33 + k * 0.22, by + 0.09, 0.0), Vector3(0.2, 0.18, 0.4), c(colr))
					m.box(Vector3(-0.33 + k * 0.22, by + 0.15, 0.19), Vector3(0.18, 0.06, 0.03), c(BLACK))
					m.box(Vector3(-0.33 + k * 0.22, by + 0.06, 0.202), Vector3(0.12, 0.05, 0.004), c(PAPER))
			3:                                                                    # коробки с растворами
				for k in 3:
					m.box(Vector3(-0.3 + k * 0.3, by + 0.14, 0.0), Vector3(0.27, 0.28, 0.38), c(0xD8CDB0))
					m.box(Vector3(-0.3 + k * 0.3, by + 0.14, 0.192), Vector3(0.27, 0.05, 0.004), c(BLUE))
					_cross(m, Vector3(-0.3 + k * 0.3, by + 0.21, 0.193), 0.08)
	m.box(Vector3(-0.2, 1.97, -0.02), Vector3(0.36, 0.2, 0.4), c(0xD8CDB0))        # наверху — коробки
	_cross(m, Vector3(-0.2, 1.97, 0.182), 0.1)
	if hv % 2 == 0:
		m.box(Vector3(0.24, 1.95, -0.02), Vector3(0.3, 0.16, 0.36), c(WHITE))
		m.box(Vector3(0.24, 1.95, 0.162), Vector3(0.3, 0.04, 0.004), c(TEAL))

## Холодильник для лекарств со стеклянной дверью
static func _medfridge(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.05, -0.02), Vector3(0.78, 0.1, 0.6), c(0x3A4048))
	m.box(Vector3(0, 0.98, -0.02), Vector3(0.82, 1.76, 0.66), c(WHITE))
	m.box(Vector3(0, 1.72, 0.312), Vector3(0.76, 0.22, 0.008), c(0xD8DDE0))        # панель с индикатором
	m.box(Vector3(-0.2, 1.72, 0.318), Vector3(0.2, 0.09, 0.004), c(0x101A26))
	m.box(Vector3(-0.2, 1.72, 0.321), Vector3(0.12, 0.05, 0.003), c(0x58B8F0, 0.5))
	m.box(Vector3(0.24, 1.72, 0.318), Vector3(0.04, 0.04, 0.006), c(0x58D878, 0.5))
	_cross(m, Vector3(0.06, 1.72, 0.318), 0.1)
	m.box(Vector3(0, 0.88, 0.312), Vector3(0.7, 1.4, 0.008), c(0xEAF6FA))          # освещённая камера за стеклом
	var caps := [RED, BLUE, YELLOW, O2, WHITE, 0x8A5AA8]
	for s in 5:
		var sy := 0.28 + s * 0.27
		m.box(Vector3(0, sy, 0.318), Vector3(0.7, 0.02, 0.006), c(0x9AA0A6))
		for k in 8:
			if (hv >> (s + k)) % 6 == 0:
				continue
			var vh := 0.1 + ((hv >> k) % 3) * 0.03
			m.box(Vector3(-0.3 + k * 0.086, sy + 0.01 + vh * 0.5, 0.319), Vector3(0.06, vh, 0.006), c(0xD8E8EE if (s + k) % 3 != 0 else 0xD8CDB0))
			m.box(Vector3(-0.3 + k * 0.086, sy + 0.01 + vh + 0.012, 0.319), Vector3(0.05, 0.024, 0.006), c(caps[(hv + s + k) % 6]))
	for sx in [-0.365, 0.365]:
		m.box(Vector3(sx, 0.88, 0.318), Vector3(0.03, 1.46, 0.016), c(INOX))       # рама двери
	for y in [0.16, 1.6]:
		m.box(Vector3(0, y, 0.318), Vector3(0.76, 0.03, 0.016), c(INOX))
	m.box(Vector3(0.31, 0.95, 0.34), Vector3(0.025, 0.4, 0.03), c(CHROME))         # ручка
	m.box(Vector3(0.3, 1.3, 0.33), Vector3(0.05, 0.05, 0.02), c(0x70787E))         # замок

## Коробки с расходниками
static func _supplyboxes(m: Mesher, hv: int) -> void:
	for k in 2:
		var bx := -0.24 + k * 0.48
		m.box(Vector3(bx, 0.19, -0.02), Vector3(0.46, 0.38, 0.52), c(0xD8CDB0))
		m.box(Vector3(bx, 0.375, -0.02), Vector3(0.08, 0.012, 0.52), c(0xC8B890))   # скотч
		m.box(Vector3(bx, 0.12, 0.242), Vector3(0.46, 0.05, 0.004), c(BLUE if k == 0 else TEAL))
		_cross(m, Vector3(bx, 0.24, 0.243), 0.12)
	m.push()
	m.translate(Vector3(-0.08 + (hv % 3) * 0.05, 0.38, -0.03))
	m.rot_y(((hv >> 2) % 5 - 2) * 3.0)
	m.box(Vector3(0, 0.16, 0), Vector3(0.5, 0.32, 0.44), c(WHITE))
	m.box(Vector3(0, 0.1, 0.222), Vector3(0.5, 0.05, 0.004), c(RED))
	m.box(Vector3(0, 0.2, 0.222), Vector3(0.24, 0.06, 0.004), c(0x3A4048))
	m.pop()
	if hv % 2 == 0:                                                               # открытая коробка с бинтами
		m.box(Vector3(0.3, 0.46, 0.05), Vector3(0.3, 0.16, 0.3), c(0xD8CDB0))
		for k in 3:
			_cyl_z(m, Vector3(0.22 + k * 0.08, 0.55, -0.06), 0.2, 0.035, c(WHITE), 6)
	else:
		for k in 2:
			m.box(Vector3(0.3, 0.42 + k * 0.08, 0.0), Vector3(0.24, 0.07, 0.3), c(BLUE if k == 0 else 0x9DB4D0))

## Сейф для сильнодействующих препаратов
static func _narcsafe(m: Mesher) -> void:
	m.box(Vector3(0, 0.04, -0.02), Vector3(0.74, 0.08, 0.46), c(BLACK))
	m.box(Vector3(0, 0.46, -0.02), Vector3(0.78, 0.76, 0.5), c(OFFW))              # тумба с запирающимися ящиками
	for d in 3:
		m.box(Vector3(0, 0.2 + d * 0.24, 0.233), Vector3(0.72, 0.2, 0.01), c(WHITE))
		m.box(Vector3(0, 0.24 + d * 0.24, 0.242), Vector3(0.16, 0.022, 0.012), c(TEAL))
		_cyl_z(m, Vector3(0.28, 0.22 + d * 0.24, 0.236), 0.01, 0.016, c(CHROME), 6)
	m.box(Vector3(0, 0.855, -0.02), Vector3(0.82, 0.03, 0.54), c(0xDAD6CB))
	m.box(Vector3(-0.04, 1.2, -0.03), Vector3(0.62, 0.66, 0.46), c(0x70787E))      # сейф
	m.box(Vector3(-0.04, 1.2, 0.203), Vector3(0.54, 0.58, 0.012), c(0x858D93))
	m.box(Vector3(0.1, 1.3, 0.212), Vector3(0.14, 0.18, 0.01), c(0x1E2A3A))        # кодовая панель
	for k in 9:
		m.box(Vector3(0.062 + (k % 3) * 0.038, 1.34 - (k / 3) * 0.04, 0.218), Vector3(0.026, 0.026, 0.006), c(0xC8CCD0))
	m.box(Vector3(0.1, 1.4, 0.218), Vector3(0.03, 0.02, 0.006), c(RED, 0.5))
	m.box(Vector3(-0.14, 1.2, 0.225), Vector3(0.16, 0.035, 0.03), c(CHROME))       # ручка
	_cyl_z(m, Vector3(-0.22, 1.2, 0.21), 0.03, 0.04, c(CHROME), 8)
	m.box(Vector3(-0.04, 0.96, 0.21), Vector3(0.4, 0.08, 0.006), c(YELLOW))        # предупреждающая табличка
	for k in 4:
		m.box(Vector3(-0.19 + k * 0.1, 0.96, 0.214), Vector3(0.04, 0.08, 0.004), c(BLACK))
	m.box(Vector3(0.3, 0.885, 0.1), Vector3(0.16, 0.03, 0.22), c(0x7A2A22))        # журнал учёта

# ================== кабинет главного врача ==================
## Книжный шкаф
static func _bookcase(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.04, 0), Vector3(0.94, 0.08, 0.38), c(WALNUT_D))
	for sx in [-0.46, 0.46]:
		m.box(Vector3(sx, 1.0, 0), Vector3(0.04, 1.92, 0.4), c(WALNUT))
	m.box(Vector3(0, 1.0, -0.19), Vector3(0.9, 1.92, 0.02), c(WALNUT_D))
	m.box(Vector3(0, 1.97, 0), Vector3(1.0, 0.05, 0.42), c(WALNUT))
	m.box(Vector3(0, 0.38, 0.19), Vector3(0.88, 0.58, 0.02), c(WALNUT))            # нижние дверцы
	m.box(Vector3(0, 0.38, 0.202), Vector3(0.012, 0.58, 0.006), c(WALNUT_D))
	for sx in [-0.06, 0.06]:
		_cyl_z(m, Vector3(sx, 0.42, 0.2), 0.025, 0.018, c(0xC9A227), 6)
	var cols := [0x94342C, 0x2F6144, 0x2F4C80, 0xA07A48, 0x644C7C, 0x4A4E54, 0xC8B080]
	for s in 4:
		var sy := 0.69 + s * 0.31
		m.box(Vector3(0, sy, 0), Vector3(0.9, 0.03, 0.38), c(WALNUT))
		var x := -0.42
		var i := 0
		while x < 0.4:
			var bw := 0.04 + ((hv >> ((i + s * 3) % 20)) % 4) * 0.012
			var bh := 0.2 + ((hv >> ((i * 2 + s) % 18)) % 4) * 0.02
			if s == 2 and x > 0.1:
				break
			m.box(Vector3(x + bw * 0.5, sy + 0.015 + bh * 0.5, 0.02), Vector3(bw - 0.006, bh, 0.26), c(cols[(hv + i * 3 + s) % 7]))
			if i % 2 == 0:
				m.box(Vector3(x + bw * 0.5, sy + 0.015 + bh * 0.32, 0.152), Vector3(bw - 0.014, 0.05, 0.004), c(0xD8C890))
			x += bw
			i += 1
		if s == 2:                                                                # стопка книг, часы и фото в рамке
			for k in 3:
				m.box(Vector3(0.2 + (k % 2) * 0.01, sy + 0.035 + k * 0.045, 0.02), Vector3(0.2 - k * 0.02, 0.04, 0.26), c(cols[(hv + k * 2) % 7]))
			m.box(Vector3(0.38, sy + 0.08, 0.04), Vector3(0.09, 0.13, 0.06), c(0xC9A227))
			_cyl_z(m, Vector3(0.38, sy + 0.09, 0.07), 0.006, 0.035, c(PAPER), 8)
			m.box(Vector3(0.2, sy + 0.22, 0.06), Vector3(0.12, 0.1, 0.012), c(WALNUT_D))
			m.box(Vector3(0.2, sy + 0.22, 0.068), Vector3(0.09, 0.07, 0.004), c(0xB8C8D8))

## Дипломы в рамках на стенде
static func _diplomas(m: Mesher) -> void:
	var zf := _board(m, WALNUT_D, 0x8A6A4A)
	var fr := [[-0.26, 1.62, 0.3, 0.24], [0.14, 1.64, 0.36, 0.28], [-0.24, 1.24, 0.34, 0.26], [0.2, 1.24, 0.28, 0.36]]
	for k in fr.size():
		var f: Array = fr[k]
		m.box(Vector3(f[0], f[1], zf + 0.004), Vector3(f[2], f[3], 0.012), c(0xC9A227 if k % 2 == 0 else BLACK))
		m.box(Vector3(f[0], f[1], zf + 0.011), Vector3(f[2] - 0.04, f[3] - 0.04, 0.004), c(0xF2EEDC))
		m.box(Vector3(f[0], f[1] + f[3] * 0.25, zf + 0.014), Vector3(f[2] * 0.5, 0.02, 0.002), c(0x2A2A2A))
		for ln in 3:
			m.box(Vector3(f[0], f[1] + f[3] * 0.08 - ln * 0.03, zf + 0.014), Vector3(f[2] * 0.62, 0.008, 0.002), c(0x8A8A82))
		m.box(Vector3(f[0] + f[2] * 0.28, f[1] - f[3] * 0.3, zf + 0.014), Vector3(0.035, 0.035, 0.003), c(RED if k % 2 == 0 else 0xC9A227))
	m.box(Vector3(0, 1.04, zf + 0.004), Vector3(0.4, 0.05, 0.008), c(0xC9A227))    # табличка с именем

## Анатомический скелет на стойке
static func _skeleton(m: Mesher) -> void:
	_cyl(m, Vector3(0, 0.0, -0.02), 0.04, 0.2, 0.18, c(0x3A4048), 12)
	_cyl(m, Vector3(0, 0.04, -0.12), 1.86, 0.014, 0.014, c(CHROME), 6)
	m.box(Vector3(0, 1.9, -0.06), Vector3(0.014, 0.014, 0.14), c(CHROME))
	m.box(Vector3(0, 1.84, 0.0), Vector3(0.01, 0.1, 0.01), c(CHROME))
	var b := c(BONE)
	m.ellipsoid(Vector3(0, 1.69, 0.0), Vector3(0.085, 0.1, 0.1), b, 4, 8)          # череп
	m.box(Vector3(0, 1.6, 0.03), Vector3(0.09, 0.06, 0.09), b)
	for e in [-0.035, 0.035]:
		m.box(Vector3(e, 1.69, 0.093), Vector3(0.035, 0.035, 0.012), c(0x2A2A2A))
	m.box(Vector3(0, 1.64, 0.098), Vector3(0.016, 0.03, 0.01), c(0x2A2A2A))
	m.box(Vector3(0, 1.585, 0.076), Vector3(0.06, 0.012, 0.006), c(0x2A2A2A))
	m.box(Vector3(0, 1.26, -0.03), Vector3(0.04, 0.6, 0.04), b)                    # позвоночник
	m.box(Vector3(0, 1.5, 0.0), Vector3(0.36, 0.022, 0.03), b)                     # ключицы
	m.box(Vector3(0, 1.33, 0.085), Vector3(0.04, 0.26, 0.02), b)                   # грудина
	for r in 6:
		var rw := 0.3 - absf(r - 2.0) * 0.016
		var ry := 1.44 - r * 0.05
		m.box(Vector3(0, ry, 0.08), Vector3(rw, 0.018, 0.018), b)
		for s in [-1, 1]:
			m.box(Vector3(s * rw * 0.5, ry, 0.02), Vector3(0.018, 0.018, 0.13), b)
	m.box(Vector3(0, 0.97, -0.01), Vector3(0.26, 0.09, 0.1), b)                    # таз
	for s in [-1, 1]:
		m.box(Vector3(s * 0.12, 1.02, -0.02), Vector3(0.07, 0.12, 0.08), b)
		m.box(Vector3(s * 0.2, 1.34, 0.0), Vector3(0.03, 0.3, 0.03), b)            # плечо
		m.box(Vector3(s * 0.21, 1.05, 0.02), Vector3(0.025, 0.28, 0.025), b)       # предплечье
		m.box(Vector3(s * 0.21, 0.86, 0.03), Vector3(0.04, 0.1, 0.02), b)          # кисть
		m.box(Vector3(s * 0.085, 0.71, 0.0), Vector3(0.038, 0.44, 0.038), b)       # бедро
		m.box(Vector3(s * 0.085, 0.48, 0.02), Vector3(0.05, 0.04, 0.05), b)        # колено
		m.box(Vector3(s * 0.085, 0.28, 0.0), Vector3(0.03, 0.38, 0.03), b)         # голень
		m.box(Vector3(s * 0.085, 0.08, 0.05), Vector3(0.05, 0.03, 0.16), b)        # стопа

# ================== зал собраний ==================
## Стол для совещаний: пары клеток подряд стыкуются в один длинный
static func _conftable(m: Mesher, hv: int, wide: bool) -> void:
	var L := 2.0 if wide else 1.0
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	m.box(Vector3(cx, 0.75, 0), Vector3(L, 0.05, 0.9), c(WALNUT))
	m.box(Vector3(cx, 0.777, 0), Vector3(L, 0.004, 0.5), c(0x8A6444))              # светлая вставка
	m.box(Vector3(cx, 0.71, 0), Vector3(L - 0.06, 0.03, 0.8), c(WALNUT_D))
	for px in [x0 + 0.4, x0 + L - 0.4] if wide else [cx]:
		m.box(Vector3(px, 0.37, 0), Vector3(0.1, 0.66, 0.56), c(WALNUT_D))         # опоры
		m.box(Vector3(px, 0.03, 0), Vector3(0.16, 0.06, 0.74), c(WALNUT_D))
	var top := 0.78
	var seats := [-0.5, 0.5] if wide else [0.0]
	for i in seats.size():
		for s in [-1, 1]:
			if (hv >> (i * 2 + (s + 1) / 2)) % 4 == 0:
				continue
			var px: float = cx + seats[i]
			m.box(Vector3(px, top + 0.003, s * 0.28), Vector3(0.22, 0.006, 0.3), c(PAPER))       # бумаги участника
			m.box(Vector3(px + 0.15, top + 0.008, s * 0.28), Vector3(0.012, 0.012, 0.14), c(BLUE))
			if (hv >> (i + 3)) % 2 == 0:
				_cyl(m, Vector3(px - 0.2, top, s * 0.3), 0.08, 0.034, 0.036, c(WHITE), 8)
	_cyl(m, Vector3(cx, top, 0), 0.012, 0.16, 0.16, c(INOX), 12)                   # поднос с графином и стаканами
	_cyl(m, Vector3(cx - 0.04, top + 0.012, 0), 0.18, 0.05, 0.035, c(0xBFD8E8), 8)
	for k in 3:
		_cyl(m, Vector3(cx + 0.07, top + 0.012, -0.07 + k * 0.07), 0.07, 0.025, 0.028, c(0xE8F0F4), 6)
	if wide:
		m.box(Vector3(cx + 0.72, top + 0.02, 0.02), Vector3(0.24, 0.04, 0.32), c(0xD9C58A))      # стопка историй болезни
		m.box(Vector3(cx - 0.76, top + 0.025, 0.0), Vector3(0.18, 0.05, 0.18), c(0x3A4048))      # телефон для селектора

## Экран для проектора на треноге
static func _projscreen(m: Mesher) -> void:
	_cyl(m, Vector3(0, 0.3, 0), 1.85, 0.016, 0.016, c(BLACK), 6)
	for k in 3:
		m.push()
		m.translate(Vector3(0, 0.34, 0))
		m.rot_y(k * 120.0 + 90.0)
		m.rot_x(152)
		m.box(Vector3(0, 0.18, 0), Vector3(0.02, 0.38, 0.02), c(BLACK))
		m.pop()
	m.box(Vector3(0, 1.0, 0.02), Vector3(1.0, 0.07, 0.07), c(BLACK))               # кожух рулона
	m.box(Vector3(0, 1.52, 0.02), Vector3(0.96, 0.98, 0.012), c(0xF4F4F0))
	m.box(Vector3(0, 2.02, 0.02), Vector3(0.98, 0.03, 0.03), c(BLACK))
	var zf := 0.028
	m.box(Vector3(0, 1.86, zf), Vector3(0.6, 0.06, 0.003), c(0x6E8FB8))            # слайд: заголовок, столбики, текст
	for k in 4:
		var bh: float = [0.2, 0.34, 0.26, 0.42][k]
		m.box(Vector3(-0.32 + k * 0.1, 1.2 + bh * 0.5, zf), Vector3(0.07, bh, 0.003), c([0x6E8FB8, 0x88B0A0, 0x6E8FB8, 0xD08A80][k]))
	m.box(Vector3(-0.17, 1.19, zf), Vector3(0.44, 0.008, 0.003), c(0x70787E))
	for k in 5:
		m.box(Vector3(0.26, 1.66 - k * 0.09, zf), Vector3(0.3 - (k % 2) * 0.06, 0.02, 0.003), c(0x9AA0A6))

## Кодоскоп (проектор для плёнок) на тележке
static func _ohprojector(m: Mesher) -> void:
	for sx in [-0.26, 0.26]:
		for sz in [-0.19, 0.19]:
			_caster(m, Vector3(sx, 0, sz))
			m.box(Vector3(sx, 0.47, sz), Vector3(0.025, 0.76, 0.025), c(0x3A4048))
	for y in [0.3, 0.84]:
		m.box(Vector3(0, y, 0), Vector3(0.6, 0.025, 0.46), c(0x70787E))
	var top := 0.855
	m.box(Vector3(0, top + 0.08, 0), Vector3(0.38, 0.16, 0.38), c(BEIGE))          # корпус
	m.box(Vector3(0, top + 0.162, 0), Vector3(0.28, 0.006, 0.28), c(0xF4FAFC, 0.5))            # светящееся стекло
	m.box(Vector3(0.02, top + 0.167, -0.02), Vector3(0.2, 0.003, 0.22), c(0xDCE8EC))           # плёнка с текстом
	for k in 4:
		m.box(Vector3(0.02, top + 0.17, -0.1 + k * 0.05), Vector3(0.15, 0.002, 0.012), c(0x3A4048))
	m.box(Vector3(-0.16, top + 0.38, -0.16), Vector3(0.03, 0.46, 0.03), c(0x3A4048))            # стойка головки
	m.box(Vector3(-0.08, top + 0.6, -0.08), Vector3(0.2, 0.03, 0.2), c(0x3A4048))
	m.box(Vector3(0, top + 0.6, 0), Vector3(0.12, 0.1, 0.12), c(BEIGE_D))          # головка с зеркалом
	m.push()
	m.translate(Vector3(0, top + 0.68, 0.02))
	m.rot_x(40)
	m.box(Vector3.ZERO, Vector3(0.12, 0.012, 0.14), c(0xDCE8EC))
	m.pop()
	m.box(Vector3(0.16, top + 0.05, 0.192), Vector3(0.03, 0.03, 0.006), c(RED, 0.5))
	m.box(Vector3(-0.08, 0.34, 0), Vector3(0.3, 0.05, 0.34), c(0xDCE8EC))          # стопка плёнок
	for k in 3:
		m.box(Vector3(0.18, 0.325, -0.08 + k * 0.05), Vector3(0.14, 0.02, 0.02), c([RED, BLUE, BLACK][k]))

## Маркерная доска
static func _whiteboard(m: Mesher, hv: int) -> void:
	var zf := _board(m, INOX, 0xF4F4F0)
	m.box(Vector3(-0.1, 1.76, zf), Vector3(0.5, 0.03, 0.003), c(BLUE))             # заголовок
	for k in 3:
		m.box(Vector3(-0.22 + k * 0.22, 1.38, zf), Vector3(0.006, 0.6, 0.003), c(BLUE))
	for k in 5:
		m.box(Vector3(0, 1.66 - k * 0.14, zf), Vector3(0.84, 0.006, 0.003), c(BLUE))
	for k in 16:
		if (hv >> (k % 11)) & 1 == 0 and k % 4 != 0:
			continue
		m.box(Vector3(-0.33 + (k % 4) * 0.22, 1.59 - (k / 4) * 0.14, zf), Vector3(0.12 + (k % 3) * 0.02, 0.02, 0.003), c([0x2A2A2A, RED, O2, 0x2A2A2A][k % 4]))
	for k in 3:
		m.box(Vector3(0.36, 1.74 - k * 0.07, zf + 0.004), Vector3(0.04, 0.04, 0.008), c([RED, YELLOW, O2][k]))   # магниты
	m.box(Vector3(0, 0.975, zf + 0.03), Vector3(0.86, 0.025, 0.07), c(INOX))       # полочка с маркерами
	for k in 4:
		m.box(Vector3(-0.3 + k * 0.1, 0.995, zf + 0.03), Vector3(0.08, 0.018, 0.018), c([RED, BLUE, BLACK, O2][k]))
	m.box(Vector3(0.24, 1.005, zf + 0.03), Vector3(0.12, 0.04, 0.05), c(0x3A4048))

# ================== комната персонала ==================
## Вешалка с халатами
static func _coatrack(m: Mesher, hv: int) -> void:
	for sx in [-0.45, 0.45]:
		m.box(Vector3(sx, 0.93, 0), Vector3(0.035, 1.86, 0.035), c(INOX))
		m.box(Vector3(sx, 0.02, 0), Vector3(0.05, 0.04, 0.4), c(INOX_D))
	m.box(Vector3(0, 1.78, 0), Vector3(0.9, 0.03, 0.03), c(CHROME))                # штанга
	m.box(Vector3(0, 1.88, 0), Vector3(0.94, 0.025, 0.36), c(INOX))                # полка
	m.box(Vector3(-0.22, 1.95, 0), Vector3(0.32, 0.12, 0.28), c(WHITE))            # стопка белья
	m.box(Vector3(0.24, 1.93, 0), Vector3(0.26, 0.08, 0.26), c(SURG))
	for k in 3:
		var hx := -0.28 + k * 0.28
		var scrubs := k == (hv % 3)
		var col := c(SURG if scrubs else WHITE)
		m.box(Vector3(hx, 1.74, 0), Vector3(0.012, 0.08, 0.012), c(CHROME))        # крючок плечиков
		m.box(Vector3(hx, 1.69, 0), Vector3(0.26, 0.03, 0.03), c(WALNUT))
		var h := 0.56 if scrubs else 0.86
		m.box(Vector3(hx, 1.68 - h * 0.5, 0), Vector3(0.25, h, 0.1), col)          # халат
		for s in [-1, 1]:
			m.box(Vector3(hx + s * 0.145, 1.44, 0), Vector3(0.05, 0.5, 0.08), col) # рукава
		m.box(Vector3(hx, 1.62, 0.052), Vector3(0.06, 0.12, 0.004), c(0x9AA0A6 if not scrubs else 0x3A7A66))   # вырез
		if not scrubs:
			m.box(Vector3(hx, 1.25, 0.052), Vector3(0.008, 0.72, 0.004), c(0xBDBCB4))           # застёжка
			m.box(Vector3(hx + 0.07, 1.08, 0.052), Vector3(0.08, 0.1, 0.004), c(0xD8D7CF))      # карман
			m.box(Vector3(hx - 0.07, 1.5, 0.052), Vector3(0.06, 0.02, 0.004), c(BLUE))          # бейдж
	m.box(Vector3(-0.2, 0.05, 0.1), Vector3(0.1, 0.06, 0.24), c(WHITE))            # сменная обувь
	m.box(Vector3(-0.06, 0.05, 0.1), Vector3(0.1, 0.06, 0.24), c(WHITE))
	m.box(Vector3(0.2, 0.05, 0.1), Vector3(0.1, 0.06, 0.24), c(SURG))
	m.box(Vector3(0.34, 0.05, 0.1), Vector3(0.1, 0.06, 0.24), c(SURG))

## Телевизор на тумбе с видеомагнитофоном
static func _tvstand(m: Mesher) -> void:
	m.box(Vector3(0, 0.03, -0.02), Vector3(0.82, 0.06, 0.44), c(BLACK))
	m.box(Vector3(0, 0.33, -0.02), Vector3(0.86, 0.54, 0.48), c(WOOD))
	m.box(Vector3(0, 0.36, 0.2), Vector3(0.78, 0.4, 0.06), c(0x3A2E20))            # ниша
	m.box(Vector3(0, 0.44, 0.2), Vector3(0.5, 0.1, 0.08), c(BLACK))                # видеомагнитофон
	m.box(Vector3(-0.1, 0.44, 0.242), Vector3(0.22, 0.03, 0.004), c(0x2A2A2A))
	m.box(Vector3(0.16, 0.44, 0.242), Vector3(0.1, 0.03, 0.004), c(0x58D878, 0.5))
	for k in 4:
		m.box(Vector3(-0.28 + k * 0.05, 0.25, 0.2), Vector3(0.04, 0.16, 0.08), c([BLACK, 0x2E3F5A, BLACK, 0x7A2A22][k]))   # кассеты
	m.box(Vector3(0, 0.615, -0.02), Vector3(0.9, 0.03, 0.52), c(0x96784F))
	var top := 0.63
	m.box(Vector3(0, top + 0.26, -0.02), Vector3(0.68, 0.52, 0.46), c(0x2E3033))   # телевизор
	m.box(Vector3(-0.06, top + 0.28, 0.212), Vector3(0.48, 0.38, 0.008), c(0x5A7E9A, 0.5))
	m.box(Vector3(-0.06, top + 0.2, 0.217), Vector3(0.48, 0.2, 0.004), c(0x6E9A6A, 0.5))
	m.box(Vector3(-0.14, top + 0.34, 0.219), Vector3(0.08, 0.12, 0.004), c(0xE8C8A8, 0.5))
	m.box(Vector3(-0.14, top + 0.24, 0.219), Vector3(0.14, 0.1, 0.004), c(0xF2F0E8, 0.5))
	m.box(Vector3(0.27, top + 0.26, 0.212), Vector3(0.1, 0.44, 0.008), c(0x1E2022))
	for k in 2:
		_cyl_z(m, Vector3(0.27, top + 0.4 - k * 0.09, 0.214), 0.02, 0.03, c(0x9AA0A6), 8)
	for k in 5:
		m.box(Vector3(0.27, top + 0.2 - k * 0.025, 0.218), Vector3(0.07, 0.01, 0.004), c(BLACK))
	for s in [-1, 1]:                                                             # антенна-«усы»
		m.push()
		m.translate(Vector3(0, top + 0.54, -0.05))
		m.rot_z(s * 28.0)
		m.box(Vector3(0, 0.22, 0), Vector3(0.012, 0.44, 0.012), c(CHROME))
		m.pop()
	m.box(Vector3(0, top + 0.54, -0.05), Vector3(0.1, 0.04, 0.08), c(BLACK))
	m.box(Vector3(0.36, top + 0.012, 0.16), Vector3(0.05, 0.024, 0.14), c(BLACK))  # пульт

## Стойка с историями болезни (пост медсестры)
static func _chartrack(m: Mesher, hv: int) -> void:
	for sx in [-0.38, 0.38]:
		for sz in [-0.17, 0.17]:
			_caster(m, Vector3(sx, 0, sz))
	m.box(Vector3(0, 0.56, -0.1), Vector3(0.84, 0.92, 0.22), c(OFFW))              # задняя часть
	for sx in [-0.41, 0.41]:
		m.box(Vector3(sx, 0.56, 0.0), Vector3(0.02, 0.92, 0.42), c(OFFW))
	for y in [0.115, 0.56]:
		m.box(Vector3(0, y, 0.0), Vector3(0.84, 0.03, 0.42), c(OFFW))              # полки
	m.box(Vector3(0, 1.035, 0), Vector3(0.88, 0.03, 0.46), c(0xDAD6CB))
	var cols := [BLUE, RED, O2, YELLOW, 0x8A5AA8, TEAL, 0xD07A30, BLUE]
	for r in 2:
		m.box(Vector3(0, 0.34 + r * 0.445, 0.013), Vector3(0.8, 0.4, 0.006), c(0x3A4048))       # тёмная глубина ниши
		for k in 8:
			if (hv >> (r * 3 + k)) % 9 == 0:
				continue
			m.push()
			m.translate(Vector3(-0.33 + k * 0.094, 0.135 + r * 0.445, 0.1))
			m.rot_x(-12)
			m.box(Vector3(0, 0.16, 0), Vector3(0.07, 0.32, 0.14), c(cols[(hv + k + r * 3) % 8]))
			m.box(Vector3(0, 0.22, 0.072), Vector3(0.05, 0.08, 0.004), c(PAPER))
			m.box(Vector3(0, 0.3, 0.072), Vector3(0.03, 0.03, 0.006), c(CHROME))
			m.pop()
	var top := 1.05
	m.box(Vector3(-0.2, top + 0.008, 0.02), Vector3(0.24, 0.016, 0.32), c(0x6A4A2C))            # планшет
	m.box(Vector3(-0.2, top + 0.018, 0.02), Vector3(0.21, 0.006, 0.28), c(PAPER))
	m.box(Vector3(-0.2, top + 0.026, -0.11), Vector3(0.1, 0.014, 0.03), c(CHROME))
	_cyl(m, Vector3(0.12, top, -0.08), 0.1, 0.04, 0.04, c(TEAL_D), 8)              # стакан с ручками
	for k in 3:
		m.box(Vector3(0.105 + k * 0.014, top + 0.13, -0.08), Vector3(0.008, 0.1, 0.008), c([BLUE, RED, BLACK][k]))
	m.box(Vector3(0.28, top + 0.01, 0.06), Vector3(0.16, 0.02, 0.02), c(BLACK))    # фонендоскоп
	m.box(Vector3(0.2, top + 0.01, 0.1), Vector3(0.02, 0.02, 0.1), c(BLACK))
	_cyl(m, Vector3(0.36, top, 0.06), 0.02, 0.03, 0.03, c(CHROME), 8)

# ================== лаборатория и морг ==================
## Лабораторный стол
static func _labbench(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.04, -0.02), Vector3(0.94, 0.08, 0.56), c(INOX_D))
	m.box(Vector3(0, 0.46, -0.02), Vector3(0.98, 0.76, 0.6), c(OFFW))
	for k in 2:
		var dx := -0.245 + k * 0.49
		m.box(Vector3(dx, 0.74, 0.283), Vector3(0.46, 0.14, 0.01), c(WHITE))
		m.box(Vector3(dx, 0.74, 0.292), Vector3(0.14, 0.022, 0.012), c(TEAL))
		m.box(Vector3(dx, 0.36, 0.283), Vector3(0.46, 0.56, 0.01), c(WHITE))
		m.box(Vector3(dx + (0.18 if k == 0 else -0.18), 0.5, 0.292), Vector3(0.02, 0.12, 0.012), c(TEAL))
	m.box(Vector3(0, 0.86, -0.02), Vector3(1.0, 0.04, 0.64), c(0x2B3038))          # чёрная столешница
	m.box(Vector3(0, 1.1, -0.29), Vector3(0.98, 0.03, 0.14), c(OFFW))              # полка с реактивами
	for sx in [-0.47, 0.47]:
		m.box(Vector3(sx, 0.99, -0.29), Vector3(0.03, 0.22, 0.14), c(OFFW))
	for k in 7:
		_bottle(m, Vector3(-0.38 + k * 0.125, 1.115, -0.29), 0.13 + (k % 2) * 0.03, AMBER if k % 3 != 1 else 0xE8F0F4)
	var top := 0.88
	if hv % 2 == 0:
		# микроскоп
		m.box(Vector3(-0.3, top + 0.015, 0.02), Vector3(0.16, 0.03, 0.22), c(BLACK))
		m.box(Vector3(-0.3, top + 0.15, -0.06), Vector3(0.04, 0.26, 0.05), c(0x3A4048))
		m.box(Vector3(-0.3, top + 0.1, 0.03), Vector3(0.12, 0.012, 0.12), c(0x3A4048))
		m.push()
		m.translate(Vector3(-0.3, top + 0.2, 0.0))
		m.rot_x(25)
		m.tube(0.0, 0.2, 0.025, 0.022, c(0xD8DDE0), 8)
		m.tube(-0.06, 0.0, 0.02, 0.016, c(CHROME), 6)
		m.pop()
		m.box(Vector3(0.3, top + 0.012, 0.06), Vector3(0.22, 0.024, 0.3), c(TEAL_D))               # лабораторный журнал
		m.box(Vector3(0.3, top + 0.027, 0.06), Vector3(0.19, 0.006, 0.26), c(PAPER))
		for k in 5:
			m.box(Vector3(0.3, top + 0.031, -0.03 + k * 0.045), Vector3(0.14, 0.002, 0.008), c(0x5A5F70))
		for k in 3:                                                               # чашки Петри
			_cyl(m, Vector3(0.24 + k * 0.07, top, -0.16), 0.015, 0.03, 0.03, c(0xE8F0F4), 8)
			_cyl(m, Vector3(0.24 + k * 0.07, top + 0.015, -0.16), 0.004, 0.022, 0.022, c([0xE8C8A8, RED, 0xC9D8A8][k]), 8)
	else:
		# центрифуга
		m.box(Vector3(0.28, top + 0.09, -0.04), Vector3(0.32, 0.18, 0.32), c(BEIGE))
		_cyl(m, Vector3(0.28, top + 0.18, -0.04), 0.03, 0.14, 0.13, c(0x70787E), 12)
		m.box(Vector3(0.28, top + 0.06, 0.122), Vector3(0.16, 0.05, 0.004), c(0x1E2A3A))
		_cyl_z(m, Vector3(0.36, top + 0.1, 0.12), 0.015, 0.025, c(BLACK), 8)
		# спиртовка и штатив с колбой
		_cyl(m, Vector3(-0.32, top, 0.06), 0.05, 0.05, 0.04, c(0xBFD8E8), 8)
		_cyl(m, Vector3(-0.32, top + 0.05, 0.06), 0.03, 0.015, 0.01, c(INOX), 6)
		m.box(Vector3(-0.32, top + 0.01, -0.12), Vector3(0.16, 0.02, 0.12), c(0x3A4048))
		m.box(Vector3(-0.32, top + 0.17, -0.16), Vector3(0.014, 0.32, 0.014), c(CHROME))
		m.box(Vector3(-0.32, top + 0.22, -0.11), Vector3(0.014, 0.014, 0.1), c(CHROME))
		_cyl(m, Vector3(-0.32, top + 0.1, -0.08), 0.09, 0.05, 0.015, c(0xD07A30), 8)
		_cyl(m, Vector3(-0.32, top + 0.19, -0.08), 0.05, 0.015, 0.015, c(0xE8F0F4), 6)
	# штатив с пробирками и колбы
	m.box(Vector3(-0.02, top + 0.04, 0.16), Vector3(0.26, 0.012, 0.07), c(BLUE))
	m.box(Vector3(-0.02, top + 0.09, 0.16), Vector3(0.26, 0.012, 0.07), c(BLUE))
	for k in 6:
		var liq: int = [RED, RED, YELLOW, RED, 0x8A5AA8, YELLOW][k]
		_cyl(m, Vector3(-0.12 + k * 0.04, top + 0.01, 0.16), 0.07, 0.011, 0.011, c(liq), 6)
		_cyl(m, Vector3(-0.12 + k * 0.04, top + 0.08, 0.16), 0.05, 0.012, 0.012, c(0xE8F0F4), 6)
	_cyl(m, Vector3(-0.04, top, -0.08), 0.1, 0.07, 0.02, c(0x58B8F0), 10)          # коническая колба
	_cyl(m, Vector3(-0.04, top + 0.1, -0.08), 0.06, 0.02, 0.02, c(0xE8F0F4), 8)
	_cyl(m, Vector3(0.08, top, -0.14), 0.07, 0.05, 0.016, c(O2), 10)
	_cyl(m, Vector3(0.08, top + 0.07, -0.14), 0.05, 0.016, 0.016, c(0xE8F0F4), 8)

## Холодильные камеры морга: клетки подряд — одна стена
static func _morgue(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.05, 0.0), Vector3(1.0, 0.1, 0.76), c(0x3A4048))
	m.box(Vector3(0, 0.98, 0.0), Vector3(1.0, 1.76, 0.8), c(INOX))
	m.box(Vector3(0, 1.93, 0.0), Vector3(1.0, 0.14, 0.8), c(INOX_D))               # блок охлаждения
	for k in 6:
		m.box(Vector3(-0.3 + k * 0.12, 1.93, 0.402), Vector3(0.06, 0.08, 0.004), c(BLACK))
	for r in 3:
		var dy := 0.4 + r * 0.56
		m.box(Vector3(0, dy, 0.405), Vector3(0.9, 0.5, 0.02), c(0xC8CCD0))         # дверца
		m.box(Vector3(0, dy, 0.418), Vector3(0.78, 0.38, 0.008), c(INOX))
		m.box(Vector3(0.34, dy, 0.43), Vector3(0.05, 0.22, 0.04), c(CHROME))       # ручка-рычаг
		m.box(Vector3(0.3, dy + 0.07, 0.45), Vector3(0.12, 0.035, 0.03), c(CHROME))
		for y in [-0.16, 0.16]:
			m.box(Vector3(-0.42, dy + y, 0.42), Vector3(0.05, 0.08, 0.03), c(INOX_D))           # петли
		m.box(Vector3(-0.1, dy + 0.12, 0.424), Vector3(0.18, 0.08, 0.006), c(INOX_D))            # рамка для бирки
		if (hv >> r) % 3 != 0:
			m.box(Vector3(-0.1, dy + 0.12, 0.428), Vector3(0.15, 0.06, 0.004), c(PAPER))
			m.box(Vector3(-0.12, dy + 0.125, 0.431), Vector3(0.08, 0.012, 0.003), c(0x3A4048))
	m.box(Vector3(0.38, 1.93, 0.404), Vector3(0.1, 0.06, 0.006), c(0x58B8F0, 0.5)) # индикатор температуры
