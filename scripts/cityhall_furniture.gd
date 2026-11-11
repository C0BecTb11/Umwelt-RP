class_name CityHallFurniture
extends RefCounted
## Мебель мэрии (клетки GameWorld.INFODESK … MAINFRAME): холл и пост охраны, зал приёма граждан, архив и земельный
## отдел, кабинет мэра, зал совета, пресс-зал, зал регистрации, казна, службы (почта, уборка, вычислительный центр).
## Устроена как остальные наборы: начало координат — центр клетки на полу, +z — лицо, -z — к стене.
## У стоек и столов +z — рабочая сторона (там кресло), -z — сторона посетителей.
## BACK — на сколько модель уходит назад от центра. Меняешь модель — поправь BACK здесь и GameWorld.FURN_FRONT
## (проверка test_furniture_collision сверяет их с самой моделью).

const W = preload("res://scripts/world.gd")

const BACK := {W.INFODESK: 0.46, W.ROPEPOST: 0.17, W.SECDESK: 0.44, W.METALDET: 0.36, W.XRAYBELT: 0.39, W.CITYSEAL: 0.03,
	W.DIRBOARD: 0.04, W.FOUNTAIN: 0.05, W.ASHBIN: 0.21, W.CLERKWIN: 0.46, W.CASHIER: 0.46, W.TICKETER: 0.20,
	W.FORMDESK: 0.28, W.WAITCHAIRS: 0.32, W.TYPEDESK: 0.43, W.PHOTOBOOTH: 0.39, W.ARCHSHELF: 0.22, W.CARDCAT: 0.23,
	W.PLANCAB: 0.37, W.CITYMODEL: 0.40, W.DRAFTTABLE: 0.39, W.MICROFILM: 0.30, W.MAYORDESK: 0.48, W.EXECCHAIR: 0.40,
	W.PORTRAIT: 0.04, W.GLOBE: 0.35, W.GRANDCLOCK: 0.17, W.FIREPLACE: 0.22, W.TROPHYCASE: 0.22, W.CITYFLAG: 0.17,
	W.DAIS: 0.50, W.PEW: 0.36, W.LECTERN: 0.24, W.BALLOTBOX: 0.28, W.VOTEBOOTH: 0.26, W.PRESSWALL: 0.19,
	W.TVCAMERA: 0.44, W.WEDARCH: 0.11, W.REGTABLE: 0.36, W.VAULT: 0.26, W.MONEYTABLE: 0.34, W.MAILSORT: 0.33,
	W.MAILCART: 0.26, W.JANITOR: 0.36, W.MAINFRAME: 0.32}
const FRONT := {W.EXECCHAIR: 0.25}
const TUCK := {W.EXECCHAIR: 0.14}

const MAHOG := 0x6B3A2A       # красное дерево
const MAHOG_D := 0x4A2619
const MAHOG_L := 0x8A5238
const OAK := 0xA98862
const OAK_D := 0x86683F
const OAK_L := 0xC2A27A
const BRASS := 0xC9A24A
const BRASS_D := 0x9A7A30
const MARBLE := 0xE4E0D6
const MARBLE_D := 0xC4BFB2
const GRANITE := 0x3E4A46     # тёмный камень столешниц
const LEATHER := 0x1F4A36     # зелёная кожа
const OXBLOOD := 0x6A1F22     # бордовая кожа
const OXBLOOD_D := 0x4A1518
const VELVET := 0x7A1E2C
const NAVY := 0x1F2F4A
const NAVY_L := 0x2E4468
const CREAM := 0xECE6D4
const PAPER := 0xF2F0E8
const MANILA := 0xD9C58A
const STEEL := 0x8A9096
const STEEL_D := 0x5E646A
const CHROME := 0xCDD1D4
const BLACK := 0x1B1C1F
const DARK := 0x2A2D31
const BEIGE := 0xD5CFBD       # корпуса техники
const BEIGE_D := 0xB5AE9A
const RED := 0xB22234
const GREEN := 0x2F7A4E
const BLUE := 0x3A6FC0
const YELLOW := 0xE8C84A
const GLASS := 0xC6DDE4
const MONEY := 0x6E9A62       # пачки купюр
const CANVAS := 0xC9BDA0

static func c(hex: int, k: float = 1.0) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255, int(round(k * 255.0)))

## Нарисовать мебель t. wide — длинный вариант на две клетки; link — есть ли такая же мебель слева (1) и справа (2)
## от клетки, если смотреть с лица: по нему ряд (канаты, скамьи, окна) рисует торцы только на концах
static func draw(m: Mesher, t: int, hv: int, wide: bool = false, link: int = 0) -> void:
	match t:
		W.INFODESK: _infodesk(m, hv)
		W.ROPEPOST: _ropepost(m, hv, link)
		W.SECDESK: _secdesk(m, hv)
		W.METALDET: _metaldet(m)
		W.XRAYBELT: _xraybelt(m, wide)
		W.CITYSEAL: _cityseal(m)
		W.DIRBOARD: _dirboard(m, hv)
		W.FOUNTAIN: _fountain(m)
		W.ASHBIN: _ashbin(m, hv)
		W.CLERKWIN: _clerkwin(m, hv, link)
		W.CASHIER: _cashier(m, hv, link)
		W.TICKETER: _ticketer(m, hv)
		W.FORMDESK: _formdesk(m, hv)
		W.WAITCHAIRS: _waitchairs(m, hv, link)
		W.TYPEDESK: _typedesk(m, hv)
		W.PHOTOBOOTH: _photobooth(m)
		W.ARCHSHELF: _archshelf(m, hv)
		W.CARDCAT: _cardcat(m, hv)
		W.PLANCAB: _plancab(m, hv)
		W.CITYMODEL: _citymodel(m, hv)
		W.DRAFTTABLE: _drafttable(m)
		W.MICROFILM: _microfilm(m)
		W.MAYORDESK: _mayordesk(m, wide)
		W.EXECCHAIR: _execchair(m)
		W.PORTRAIT: _portrait(m, hv)
		W.GLOBE: _globe(m)
		W.GRANDCLOCK: _grandclock(m, hv)
		W.FIREPLACE: _fireplace(m)
		W.TROPHYCASE: _trophycase(m, hv)
		W.CITYFLAG: _cityflag(m, hv)
		W.DAIS: _dais(m, hv)
		W.PEW: _pew(m, link)
		W.LECTERN: _lectern(m)
		W.BALLOTBOX: _ballotbox(m)
		W.VOTEBOOTH: _votebooth(m)
		W.PRESSWALL: _presswall(m)
		W.TVCAMERA: _tvcamera(m, hv)
		W.WEDARCH: _wedarch(m, hv)
		W.REGTABLE: _regtable(m)
		W.VAULT: _vault(m)
		W.MONEYTABLE: _moneytable(m, hv)
		W.MAILSORT: _mailsort(m, hv)
		W.MAILCART: _mailcart(m, hv)
		W.JANITOR: _janitor(m)
		W.MAINFRAME: _mainframe(m, hv)

# ================== общие детали ==================
static func _cyl(m: Mesher, p: Vector3, h: float, r0: float, r1: float, col: Color, segs: int = 8) -> void:
	m.push()
	m.translate(p)
	m.tube(0.0, h, r0, r1, col, segs)
	m.pop()

## Цилиндр, лежащий вдоль x: от p вправо на длину length
static func _cyl_x(m: Mesher, p: Vector3, length: float, r: float, col: Color, segs: int = 8) -> void:
	m.push()
	m.translate(p)
	m.rot_z(-90)
	m.tube(0.0, length, r, r, col, segs)
	m.pop()

## Цилиндр вдоль z: от p вперёд на длину length
static func _cyl_z(m: Mesher, p: Vector3, length: float, r: float, col: Color, segs: int = 8) -> void:
	m.push()
	m.translate(p)
	m.rot_x(90)
	m.tube(0.0, length, r, r, col, segs)
	m.pop()

## Диск на вертикальной плоскости: лицом на +z (back — на -z), p — центр тыльной стороны
static func _disc(m: Mesher, p: Vector3, r: float, th: float, col: Color, segs: int = 12, back: bool = false) -> void:
	m.push()
	m.translate(p)
	m.rot_x(-90.0 if back else 90.0)
	m.tube(0.0, th, r, r, col, segs)
	m.pop()

## Тонкая линия на вертикальной плоскости (циферблаты, чертежи)
static func _line(m: Mesher, a: Vector2, b: Vector2, z: float, col: Color, th: float = 0.008) -> void:
	var d := b - a
	m.push()
	m.translate(Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z))
	m.rot_z(rad_to_deg(atan2(d.y, d.x)))
	m.box(Vector3.ZERO, Vector3(d.length(), th, 0.004), col)
	m.pop()

## Кольцо (или дуга от a0 до a1 градусов) на вертикальной плоскости, из отрезков
static func _ring(m: Mesher, p: Vector3, r: float, th: float, col: Color, n: int = 14, a0: float = 0.0, a1: float = 360.0, depth: float = 0.012) -> void:
	var seg := deg_to_rad(a1 - a0) * r / n * 1.1
	for i in n:
		var a := deg_to_rad(a0 + (a1 - a0) * (i + 0.5) / n)
		m.push()
		m.translate(p + Vector3(cos(a) * r, sin(a) * r, 0))
		m.rot_z(rad_to_deg(a) + 90.0)
		m.box(Vector3.ZERO, Vector3(seg, th, depth), col)
		m.pop()

## Кольцо, лежащее горизонтально
static func _ring_h(m: Mesher, p: Vector3, r: float, w: float, h: float, col: Color, n: int = 14) -> void:
	var seg := TAU * r / n * 1.1
	for i in n:
		var a := TAU * (i + 0.5) / n
		m.push()
		m.translate(p + Vector3(cos(a) * r, 0, sin(a) * r))
		m.rot_y(-rad_to_deg(a) - 90.0)
		m.box(Vector3.ZERO, Vector3(seg, h, w), col)
		m.pop()

## Цифра светящегося табло; flip — смотрит на -z
static func _seg7(m: Mesher, p: Vector3, d: int, s: float, col: Color, flip: bool = false) -> void:
	var bits: int = [63, 6, 91, 79, 102, 109, 125, 7, 127, 111][d % 10]
	var w := s * 0.5
	var fx := -1.0 if flip else 1.0
	var segs := [Vector3(0, s * 0.5, 0), Vector3(w * 0.5, s * 0.25, 1), Vector3(w * 0.5, -s * 0.25, 1), Vector3(0, -s * 0.5, 0),
		Vector3(-w * 0.5, -s * 0.25, 1), Vector3(-w * 0.5, s * 0.25, 1), Vector3(0, 0, 0)]
	for k in 7:
		if ((bits >> k) & 1) == 0:
			continue
		var q: Vector3 = segs[k]
		var sz := Vector3(s * 0.1, s * 0.42, 0.004) if q.z > 0.5 else Vector3(w * 0.72, s * 0.1, 0.004)
		m.box(p + Vector3(q.x * fx, q.y, 0), sz, col)

## Герб города: золотой круг, синее поле, здание с куполом и звёзды. face: 1 — лицом на +z, -1 — на -z
static func _seal(m: Mesher, p: Vector3, r: float, face: float = 1.0) -> void:
	var back := face < 0.0
	_disc(m, p, r, 0.012, c(BRASS), 16, back)
	_disc(m, p + Vector3(0, 0, face * 0.012), r * 0.86, 0.006, c(NAVY), 16, back)
	_disc(m, p + Vector3(0, 0, face * 0.018), r * 0.56, 0.005, c(CREAM), 14, back)
	var z := face * 0.026
	m.box(p + Vector3(0, -r * 0.22, z), Vector3(r * 0.62, r * 0.1, 0.006), c(BRASS_D))      # ступени
	m.box(p + Vector3(0, -r * 0.04, z), Vector3(r * 0.5, r * 0.26, 0.006), c(BRASS))        # здание
	for k in 4:
		m.box(p + Vector3(r * (-0.18 + k * 0.12), -r * 0.04, z + face * 0.003), Vector3(r * 0.035, r * 0.22, 0.004), c(CREAM))
	m.box(p + Vector3(0, r * 0.13, z), Vector3(r * 0.56, r * 0.07, 0.006), c(BRASS_D))      # карниз
	m.box(p + Vector3(0, r * 0.23, z), Vector3(r * 0.2, r * 0.14, 0.006), c(BRASS))         # купол
	m.box(p + Vector3(0, r * 0.34, z), Vector3(r * 0.1, r * 0.1, 0.006), c(BRASS))
	for k in 8:                                                                             # звёзды по кругу
		var a := TAU * k / 8.0 + 0.39
		m.box(p + Vector3(cos(a) * r * 0.71, sin(a) * r * 0.71, face * 0.021), Vector3(r * 0.07, r * 0.07, 0.004), c(CREAM))

## Монитор 90-х с клавиатурой: экран смотрит на +z
static func _crt(m: Mesher, p: Vector3) -> void:
	m.box(p + Vector3(0, 0.02, 0), Vector3(0.24, 0.04, 0.24), c(BEIGE_D))
	m.box(p + Vector3(0, 0.2, -0.02), Vector3(0.38, 0.32, 0.36), c(BEIGE))
	m.box(p + Vector3(0, 0.21, 0.162), Vector3(0.3, 0.23, 0.006), c(0x16261E))
	for k in 4:
		m.box(p + Vector3(-0.05 + (k % 2) * 0.02, 0.29 - k * 0.045, 0.166), Vector3(0.16 - (k % 3) * 0.03, 0.012, 0.003), c(0x58D878, 0.5))
	m.box(p + Vector3(0, 0.015, 0.3), Vector3(0.4, 0.03, 0.15), c(BEIGE))
	m.box(p + Vector3(0, 0.032, 0.3), Vector3(0.36, 0.006, 0.11), c(BEIGE_D))

static func _phone(m: Mesher, p: Vector3, col: int = BLACK) -> void:
	m.box(p + Vector3(0, 0.03, 0), Vector3(0.2, 0.06, 0.2), c(col))
	m.box(p + Vector3(-0.065, 0.075, 0), Vector3(0.055, 0.035, 0.21), c(DARK if col == BLACK else CREAM))
	m.box(p + Vector3(0.035, 0.062, 0.02), Vector3(0.09, 0.006, 0.11), c(0x9A9EA2))

## Настольная лампа с зелёным плафоном
static func _lamp(m: Mesher, p: Vector3) -> void:
	m.box(p + Vector3(0, 0.012, 0), Vector3(0.16, 0.024, 0.1), c(BRASS))
	_cyl(m, p + Vector3(0, 0.024, 0), 0.24, 0.012, 0.012, c(BRASS), 6)
	m.box(p + Vector3(0, 0.29, 0.02), Vector3(0.28, 0.07, 0.12), c(GREEN))
	m.box(p + Vector3(0, 0.252, 0.02), Vector3(0.24, 0.008, 0.09), c(0xFFF0B0, 0.5))

## Микрофон на гибкой ножке; lean — в какую сторону по z наклонён (к говорящему)
static func _mic(m: Mesher, p: Vector3, lean: float) -> void:
	m.box(p + Vector3(0, 0.01, 0), Vector3(0.08, 0.02, 0.08), c(BLACK))
	m.push()
	m.translate(p + Vector3(0, 0.02, 0))
	m.rot_x(28.0 * lean)
	m.box(Vector3(0, 0.13, 0), Vector3(0.012, 0.26, 0.012), c(STEEL_D))
	m.ellipsoid(Vector3(0, 0.28, 0), Vector3(0.022, 0.035, 0.022), c(BLACK), 4, 6)
	m.pop()

static func _mug(m: Mesher, p: Vector3, col: int) -> void:
	_cyl(m, p, 0.09, 0.035, 0.038, c(col), 8)
	m.box(p + Vector3(0.05, 0.045, 0), Vector3(0.025, 0.05, 0.012), c(col))

## Лотки с бумагами
static func _trays(m: Mesher, p: Vector3, col: int = BLACK) -> void:
	for k in 2:
		m.box(p + Vector3(0, 0.01 + k * 0.075, 0), Vector3(0.24, 0.02, 0.32), c(col))
		m.box(p + Vector3(0, 0.03 + k * 0.075, 0), Vector3(0.21, 0.02, 0.29), c(PAPER))
		for sx in [-0.115, 0.115]:
			m.box(p + Vector3(sx, 0.04 + k * 0.075, -0.1), Vector3(0.01, 0.075, 0.1), c(col))

## Раскрытая книга записей
static func _ledger(m: Mesher, p: Vector3, cover: int) -> void:
	m.box(p + Vector3(0, 0.01, 0), Vector3(0.44, 0.02, 0.3), c(cover))
	m.box(p + Vector3(0, 0.022, 0), Vector3(0.4, 0.008, 0.27), c(PAPER))
	m.box(p + Vector3(0, 0.027, 0), Vector3(0.006, 0.004, 0.27), c(STEEL_D))
	for k in 5:
		m.box(p + Vector3(-0.1, 0.028, -0.09 + k * 0.045), Vector3(0.15, 0.002, 0.008), c(0x5A5F70))
		if k % 2 == 0:
			m.box(p + Vector3(0.1, 0.028, -0.09 + k * 0.045), Vector3(0.13, 0.002, 0.008), c(0x5A5F70))

## Пишущая машинка с листом: клавиши к +z
static func _typewriter(m: Mesher, p: Vector3, col: int) -> void:
	m.box(p + Vector3(0, 0.05, 0.02), Vector3(0.38, 0.1, 0.34), c(col))
	for k in 3:
		m.box(p + Vector3(0, 0.105 - k * 0.012, 0.1 + k * 0.035), Vector3(0.3, 0.012, 0.028), c(BLACK))
	_cyl_x(m, p + Vector3(-0.2, 0.13, -0.12), 0.4, 0.03, c(BLACK), 8)
	m.push()
	m.translate(p + Vector3(0, 0.13, -0.14))
	m.rot_x(-12)
	m.box(Vector3(0, 0.11, 0), Vector3(0.22, 0.22, 0.004), c(PAPER))
	for ln in 3:
		m.box(Vector3(-0.01, 0.06 + ln * 0.03, 0.003), Vector3(0.16, 0.006, 0.002), c(0x5A5F70))
	m.pop()

## Общая основа стоек: со стороны посетителей (-z) — высокая панель с филёнками и полка, с рабочей (+z) — стол
static func _counter(m: Mesher, h: float, body: int, panel: int, top: int, np: int = 2) -> void:
	m.box(Vector3(0, h * 0.5, -0.37), Vector3(1.0, h, 0.08), c(body))
	m.box(Vector3(0, 0.06, -0.414), Vector3(1.0, 0.12, 0.012), c(MAHOG_D))         # плинтус
	var pw := 0.92 / np
	for k in np:
		var px := -0.46 + pw * (k + 0.5)
		m.box(Vector3(px, h * 0.5 + 0.04, -0.413), Vector3(pw - 0.07, h - 0.36, 0.008), c(panel))
		m.box(Vector3(px, h * 0.5 + 0.04, -0.418), Vector3(pw - 0.16, h - 0.45, 0.006), c(body))
	m.box(Vector3(0, h + 0.02, -0.33), Vector3(1.0, 0.04, 0.26), c(top))           # полка для посетителей
	m.box(Vector3(0, 0.76, 0.07), Vector3(1.0, 0.04, 0.76), c(OAK))                # рабочая столешница
	m.box(Vector3(0, 0.735, 0.07), Vector3(1.0, 0.015, 0.74), c(OAK_D))
	for sx in [-0.48, 0.48]:
		m.box(Vector3(sx, 0.37, 0.03), Vector3(0.04, 0.74, 0.7), c(body))

# ================== холл и охрана ==================
## Справочная стойка
static func _infodesk(m: Mesher, hv: int) -> void:
	_counter(m, 1.08, MAHOG, MAHOG_L, MARBLE)
	if hv % 2 == 0:                                                               # знак «i» — к посетителям
		m.box(Vector3(0, 0.62, -0.424), Vector3(0.2, 0.2, 0.006), c(NAVY))
		m.box(Vector3(0, 0.6, -0.428), Vector3(0.035, 0.09, 0.004), c(CREAM))
		m.box(Vector3(0, 0.675, -0.428), Vector3(0.035, 0.03, 0.004), c(CREAM))
		m.ellipsoid(Vector3(0.3, 1.12, -0.33), Vector3(0.05, 0.045, 0.05), c(BRASS), 3, 8, 0.0, 0.5)    # звонок
		m.box(Vector3(0.3, 1.17, -0.33), Vector3(0.014, 0.014, 0.014), c(BRASS_D))
	else:                                                                         # буклеты в держателе
		m.box(Vector3(-0.2, 1.2, -0.36), Vector3(0.28, 0.16, 0.05), c(GLASS))
		for k in 3:
			m.box(Vector3(-0.29 + k * 0.09, 1.23, -0.345), Vector3(0.075, 0.17, 0.02), c([NAVY_L, YELLOW, RED][k]))
	var top := 0.78
	match hv % 3:
		0:
			_crt(m, Vector3(-0.08, top, 0.0))
		1:
			_phone(m, Vector3(-0.3, top, 0.1), CREAM)
			_ledger(m, Vector3(0.14, top, 0.12), NAVY)
		2:
			_trays(m, Vector3(-0.3, top, 0.05))
			m.box(Vector3(0.14, top + 0.025, 0.1), Vector3(0.26, 0.05, 0.2), c(CREAM))       # стопка карт города
			m.box(Vector3(0.14, top + 0.052, 0.1), Vector3(0.26, 0.004, 0.2), c(0x9CC0A0))
			_mug(m, Vector3(0.38, top, 0.26), NAVY)

## Отрезок каната между точками a и b (x, y) на плоскости z = 0: грани стыкуются без зубцов
static func _rope_seg(m: Mesher, a: Vector2, b: Vector2, h: float, col: Color) -> void:
	if a.x > b.x:
		var sw := a
		a = b
		b = sw
	var t := m.xf
	m.quad(t * Vector3(a.x, a.y + h, -h), t * Vector3(a.x, a.y + h, h), t * Vector3(b.x, b.y + h, h), t * Vector3(b.x, b.y + h, -h), col)
	m.quad(t * Vector3(a.x, a.y - h, h), t * Vector3(b.x, b.y - h, h), t * Vector3(b.x, b.y + h, h), t * Vector3(a.x, a.y + h, h), col)
	m.quad(t * Vector3(b.x, b.y - h, -h), t * Vector3(a.x, a.y - h, -h), t * Vector3(a.x, a.y + h, -h), t * Vector3(b.x, b.y + h, -h), col)
	m.quad(t * Vector3(a.x, a.y - h, -h), t * Vector3(b.x, b.y - h, -h), t * Vector3(b.x, b.y - h, h), t * Vector3(a.x, a.y - h, h), col)

## Столбик с канатом. В ряду канат провисает к соседям; одиночный — с табличкой
static func _ropepost(m: Mesher, hv: int, link: int) -> void:
	_cyl(m, Vector3.ZERO, 0.03, 0.17, 0.16, c(BRASS_D), 12)
	_cyl(m, Vector3(0, 0.03, 0), 0.04, 0.09, 0.03, c(BRASS), 10)
	_cyl(m, Vector3(0, 0.07, 0), 0.82, 0.025, 0.025, c(BRASS), 8)
	_cyl(m, Vector3(0, 0.87, 0), 0.03, 0.04, 0.04, c(BRASS_D), 8)
	m.ellipsoid(Vector3(0, 0.94, 0), Vector3(0.045, 0.045, 0.045), c(BRASS), 5, 8)
	for sg: float in [-1.0, 1.0]:
		if (link & (1 if sg < 0.0 else 2)) == 0:
			continue
		m.box(Vector3(sg * 0.045, 0.86, 0), Vector3(0.04, 0.03, 0.03), c(BRASS_D))  # крючок
		var n := 9
		for i in n:                                                               # канат: низшая точка — на стыке клеток
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var a := Vector2(sg * (0.06 + 0.44 * u0), 0.7 + 0.16 * (1.0 - u0) * (1.0 - u0))
			var b := Vector2(sg * (0.06 + 0.44 * u1), 0.7 + 0.16 * (1.0 - u1) * (1.0 - u1))
			_rope_seg(m, a, b, 0.02, c(VELVET))
	if link == 0:                                                                 # табличка на стойке
		m.box(Vector3(0, 1.16, 0), Vector3(0.3, 0.38, 0.02), c(BRASS_D))
		for sg: float in [-1.0, 1.0]:
			m.box(Vector3(0, 1.16, sg * 0.011), Vector3(0.26, 0.34, 0.004), c(CREAM))
			m.box(Vector3(0, 1.27, sg * 0.014), Vector3(0.2, 0.04, 0.003), c(RED if hv % 2 == 0 else NAVY))
			for k in 3:
				m.box(Vector3(0, 1.19 - k * 0.055, sg * 0.014), Vector3(0.18 - k * 0.03, 0.016, 0.003), c(0x4A4F58))

## Пост охраны: стол с мониторами наблюдения, к посетителям — высокая панель с эмблемой
static func _secdesk(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.76, 0.0), Vector3(0.98, 0.04, 0.84), c(0x3A3F45))
	m.box(Vector3(0, 0.735, 0.0), Vector3(0.96, 0.015, 0.82), c(STEEL_D))
	for sx in [-0.47, 0.47]:
		m.box(Vector3(sx, 0.37, 0.0), Vector3(0.04, 0.74, 0.8), c(0x34507A))
	m.box(Vector3(0, 0.56, -0.4), Vector3(0.98, 1.12, 0.05), c(0x34507A))
	m.box(Vector3(0, 1.13, -0.36), Vector3(0.98, 0.03, 0.14), c(STEEL))
	m.box(Vector3(0, 0.92, -0.427), Vector3(0.98, 0.05, 0.006), c(BRASS))
	m.box(Vector3(0, 0.62, -0.428), Vector3(0.3, 0.14, 0.006), c(BRASS))            # щит охраны
	m.box(Vector3(0, 0.5, -0.428), Vector3(0.26, 0.12, 0.006), c(BRASS))
	m.box(Vector3(0, 0.4, -0.428), Vector3(0.18, 0.09, 0.006), c(BRASS))
	m.box(Vector3(0, 0.33, -0.428), Vector3(0.09, 0.06, 0.006), c(BRASS))
	m.box(Vector3(0, 0.54, -0.432), Vector3(0.2, 0.2, 0.004), c(NAVY))
	m.box(Vector3(0, 0.54, -0.435), Vector3(0.12, 0.035, 0.004), c(CREAM))          # звезда
	m.box(Vector3(0, 0.54, -0.435), Vector3(0.035, 0.12, 0.004), c(CREAM))
	m.box(Vector3(0, 0.78, -0.428), Vector3(0.46, 0.05, 0.006), c(CREAM))           # надпись
	for k in 8:
		m.box(Vector3(-0.175 + k * 0.05, 0.78, -0.432), Vector3(0.03, 0.03, 0.004), c(NAVY))
	var top := 0.78
	for k in 2:                                                                    # мониторы наблюдения
		var mx := -0.24 + k * 0.48
		m.box(Vector3(mx, top + 0.16, -0.2), Vector3(0.38, 0.32, 0.3), c(DARK))
		m.box(Vector3(mx, top + 0.17, -0.047), Vector3(0.3, 0.23, 0.006), c(0xA4B6B2, 0.5))
		if k == 0:                                                                 # коридор с фигурой
			m.box(Vector3(mx, top + 0.1, -0.043), Vector3(0.3, 0.004, 0.003), c(0x4A5A58))
			m.box(Vector3(mx - 0.08, top + 0.17, -0.043), Vector3(0.004, 0.14, 0.003), c(0x4A5A58))
			m.box(Vector3(mx + 0.06, top + 0.15, -0.043), Vector3(0.03, 0.09, 0.003), c(0x2E3A38))
			m.box(Vector3(mx + 0.06, top + 0.21, -0.043), Vector3(0.022, 0.022, 0.003), c(0x2E3A38))
		else:                                                                      # четыре камеры на одном экране
			m.box(Vector3(mx, top + 0.17, -0.043), Vector3(0.3, 0.006, 0.003), c(DARK))
			m.box(Vector3(mx, top + 0.17, -0.043), Vector3(0.006, 0.23, 0.003), c(DARK))
			for q in 4:
				m.box(Vector3(mx - 0.075 + (q % 2) * 0.15, top + 0.1 + (q / 2) * 0.115, -0.043), Vector3(0.08, 0.004, 0.003), c(0x4A5A58))
		m.box(Vector3(mx + 0.15, top + 0.035, -0.047), Vector3(0.02, 0.012, 0.006), c(0x58D878, 0.5))
	m.box(Vector3(0.02, top + 0.02, 0.1), Vector3(0.42, 0.04, 0.16), c(DARK))       # пульт
	for k in 10:
		m.box(Vector3(-0.14 + (k % 5) * 0.07, top + 0.043, 0.07 + (k / 5) * 0.06), Vector3(0.035, 0.008, 0.03),
			c(0xE0483A, 0.5) if k == (hv % 10) else c(0x8A9096))
	_cyl(m, Vector3(0.19, top + 0.04, 0.1), 0.05, 0.012, 0.012, c(BLACK), 6)
	_phone(m, Vector3(0.36, top, 0.26))
	m.box(Vector3(-0.3, top + 0.01, 0.24), Vector3(0.3, 0.02, 0.24), c(GREEN))      # журнал посетителей
	m.box(Vector3(-0.3, top + 0.022, 0.24), Vector3(0.27, 0.006, 0.21), c(PAPER))
	for k in 4:
		m.box(Vector3(-0.3, top + 0.026, 0.17 + k * 0.045), Vector3(0.2, 0.002, 0.008), c(0x5A5F70))
	m.box(Vector3(-0.44, top + 0.08, 0.02), Vector3(0.05, 0.16, 0.035), c(BLACK))   # рация
	m.box(Vector3(-0.455, top + 0.21, 0.02), Vector3(0.012, 0.1, 0.012), c(BLACK))
	_cyl_x(m, Vector3(-0.02, top + 0.025, 0.33), 0.2, 0.022, c(BLACK), 8)           # фонарь
	_mug(m, Vector3(0.42, top, 0.02), 0xECEBE5)

## Рамка металлоискателя: проход по оси z
static func _metaldet(m: Mesher) -> void:
	m.box(Vector3(0, 0.012, 0), Vector3(0.78, 0.024, 0.7), c(DARK))                # резиновый коврик
	for sz in [-0.33, 0.33]:
		m.box(Vector3(0, 0.026, sz), Vector3(0.78, 0.004, 0.05), c(YELLOW))
	for sx: float in [-0.44, 0.44]:
		m.box(Vector3(sx, 1.0, 0), Vector3(0.1, 2.0, 0.34), c(BEIGE))
		m.box(Vector3(sx, 0.04, 0), Vector3(0.14, 0.08, 0.4), c(DARK))
		for sz2: float in [-1.0, 1.0]:
			m.box(Vector3(sx, 1.02, sz2 * 0.172), Vector3(0.04, 1.8, 0.004), c(STEEL_D))
	m.box(Vector3(0, 2.07, 0), Vector3(0.98, 0.16, 0.36), c(BEIGE))
	for sz3: float in [-1.0, 1.0]:
		m.box(Vector3(0, 2.07, sz3 * 0.182), Vector3(0.6, 0.09, 0.004), c(DARK))
		m.box(Vector3(-0.2, 2.07, sz3 * 0.185), Vector3(0.1, 0.05, 0.004), c(0x58D878, 0.5))
		m.box(Vector3(0.0, 2.07, sz3 * 0.185), Vector3(0.1, 0.05, 0.004), c(0x7A2A22))
		for k in 4:
			m.box(Vector3(0.14 + k * 0.04, 2.07, sz3 * 0.185), Vector3(0.02, 0.05, 0.004), c(0xE8A83A, 0.5) if k < 2 else c(0x5A4A2A))
	m.box(Vector3(0.44, 1.35, 0.185), Vector3(0.09, 0.2, 0.03), c(DARK))            # пульт на стойке
	m.box(Vector3(0.44, 1.39, 0.202), Vector3(0.06, 0.04, 0.004), c(0xE0483A, 0.5))

## Лента досмотра вещей (на две клетки)
static func _xraybelt(m: Mesher, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	var x1 := x0 + L
	var tl := 0.8 if wide else 0.5                 # длина камеры просвечивания
	m.box(Vector3(cx, 0.36, -0.02), Vector3(L - 0.24, 0.6, 0.6), c(STEEL))
	m.box(Vector3(cx, 0.03, -0.02), Vector3(L - 0.2, 0.06, 0.64), c(BLACK))
	for k in 6:                                                                    # предупреждающая полоса
		var sw := (L - 0.3) / 6.0
		m.box(Vector3(x0 + 0.15 + sw * (k + 0.5), 0.12, 0.282), Vector3(sw, 0.06, 0.006), c(YELLOW if k % 2 == 0 else BLACK))
	m.box(Vector3(cx, 0.7, -0.02), Vector3(L, 0.05, 0.54), c(BLACK))                # лента
	for ex: float in [x0, x1]:
		_cyl_z(m, Vector3(ex, 0.7, -0.29), 0.54, 0.035, c(STEEL_D), 8)
	for sz: float in [-0.31, 0.27]:
		m.box(Vector3(cx, 0.72, sz), Vector3(L, 0.09, 0.03), c(STEEL_D))            # борта
	m.box(Vector3(cx, 1.04, -0.02), Vector3(tl, 0.6, 0.7), c(BEIGE))                # камера
	m.box(Vector3(cx, 1.36, -0.02), Vector3(tl + 0.04, 0.04, 0.74), c(BEIGE_D))
	for ex2: float in [cx - tl * 0.5, cx + tl * 0.5]:
		var sg := -1.0 if ex2 < cx else 1.0
		m.box(Vector3(ex2 + sg * 0.004, 0.94, -0.02), Vector3(0.006, 0.38, 0.5), c(BLACK))
		for k in 6:                                                                # свинцовые шторки
			m.box(Vector3(ex2 + sg * 0.01, 0.95, -0.23 + k * 0.084), Vector3(0.008, 0.36, 0.07), c(0x4A4F55 if k % 2 == 0 else 0x3A3F45))
	m.box(Vector3(cx, 1.12, 0.332), Vector3(tl * 0.6, 0.1, 0.006), c(YELLOW))       # знак излучения
	m.box(Vector3(cx, 1.12, 0.336), Vector3(0.05, 0.06, 0.004), c(BLACK))
	# монитор оператора и пульт
	var mx := cx + tl * 0.5 - 0.2
	m.box(Vector3(mx, 1.53, 0.0), Vector3(0.34, 0.3, 0.32), c(BEIGE_D))
	m.box(Vector3(mx, 1.54, 0.162), Vector3(0.27, 0.22, 0.006), c(0x18242E))
	m.box(Vector3(mx - 0.03, 1.52, 0.166), Vector3(0.14, 0.09, 0.003), c(0xE8943A, 0.5))    # сумка на просвет
	m.box(Vector3(mx - 0.03, 1.575, 0.166), Vector3(0.06, 0.02, 0.003), c(0xE8943A, 0.5))
	m.box(Vector3(mx - 0.05, 1.52, 0.169), Vector3(0.04, 0.05, 0.003), c(0x3A8FE0, 0.5))
	m.box(Vector3(mx + 0.01, 1.51, 0.169), Vector3(0.05, 0.02, 0.003), c(0x58D878, 0.5))
	m.box(Vector3(cx - tl * 0.5 + 0.16, 1.4, 0.2), Vector3(0.22, 0.04, 0.14), c(DARK))
	for k in 6:
		m.box(Vector3(cx - tl * 0.5 + 0.09 + (k % 3) * 0.07, 1.423, 0.17 + (k / 3) * 0.06), Vector3(0.04, 0.008, 0.035), c(0x8A9096))
	# лоток с вещами у входа и портфель на выходе
	m.box(Vector3(x0 + 0.24, 0.76, -0.02), Vector3(0.34, 0.08, 0.42), c(0x70787E))
	m.box(Vector3(x0 + 0.24, 0.79, -0.02), Vector3(0.3, 0.05, 0.38), c(0x8A9298))
	m.box(Vector3(x0 + 0.2, 0.83, -0.06), Vector3(0.12, 0.03, 0.08), c(BLACK))
	_ring_h(m, Vector3(x0 + 0.32, 0.822, 0.06), 0.03, 0.008, 0.008, c(BRASS), 8)
	if wide:
		m.box(Vector3(x1 - 0.26, 0.86, -0.02), Vector3(0.38, 0.26, 0.1), c(0x6A4A2C))
		m.box(Vector3(x1 - 0.26, 1.01, -0.02), Vector3(0.12, 0.04, 0.03), c(0x3A2A1C))
		for sx in [-0.1, 0.1]:
			m.box(Vector3(x1 - 0.26 + sx, 0.93, 0.032), Vector3(0.03, 0.04, 0.006), c(BRASS))

## Герб города на стене и памятная табличка под ним
static func _cityseal(m: Mesher) -> void:
	_seal(m, Vector3(0, 1.6, -0.03), 0.42)
	m.box(Vector3(0, 0.98, -0.02), Vector3(0.56, 0.2, 0.02), c(BRASS_D))
	m.box(Vector3(0, 0.98, -0.008), Vector3(0.52, 0.16, 0.006), c(BRASS))
	for k in 3:
		m.box(Vector3(0, 1.03 - k * 0.045, -0.004), Vector3(0.4 - k * 0.08, 0.016, 0.003), c(MAHOG_D))

## Указатель кабинетов: чёрная доска с наборными буквами под стеклом
static func _dirboard(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 1.45, 0), Vector3(0.92, 1.24, 0.07), c(BRASS_D))
	m.box(Vector3(0, 1.45, 0.036), Vector3(0.84, 1.16, 0.006), c(BLACK))
	m.box(Vector3(0, 1.95, 0.04), Vector3(0.5, 0.07, 0.004), c(BRASS))
	for k in 10:
		var y := 1.84 - k * 0.1
		var nl := 0.26 + ((hv >> k) % 4) * 0.05
		m.box(Vector3(-0.36 + nl * 0.5, y, 0.04), Vector3(nl, 0.03, 0.004), c(CREAM))
		m.box(Vector3(0.31, y, 0.04), Vector3(0.09, 0.03, 0.004), c(CREAM))
		for d in 4:
			m.box(Vector3(0.1 + d * 0.035, y - 0.008, 0.04), Vector3(0.012, 0.008, 0.004), c(0x8A8F96))

## Питьевые фонтанчики: высокий и низкий
static func _fountain(m: Mesher) -> void:
	for k in 2:
		var fx := -0.23 + k * 0.48
		var fy := 0.92 - k * 0.18
		m.box(Vector3(fx, fy - 0.1, -0.03), Vector3(0.42, 0.8, 0.04), c(STEEL))
		m.box(Vector3(fx, fy - 0.13, 0.13), Vector3(0.4, 0.3, 0.3), c(STEEL))
		m.box(Vector3(fx, fy + 0.03, 0.13), Vector3(0.42, 0.03, 0.32), c(CHROME))
		m.box(Vector3(fx, fy + 0.046, 0.14), Vector3(0.32, 0.004, 0.22), c(STEEL_D))
		m.box(Vector3(fx + 0.12, fy + 0.075, 0.06), Vector3(0.035, 0.06, 0.05), c(CHROME))     # носик
		m.box(Vector3(fx + 0.09, fy + 0.1, 0.07), Vector3(0.05, 0.016, 0.02), c(CHROME))
		m.box(Vector3(fx - 0.06, fy + 0.05, 0.16), Vector3(0.03, 0.006, 0.03), c(BLACK))       # слив
		m.box(Vector3(fx, fy - 0.08, 0.283), Vector3(0.3, 0.06, 0.012), c(STEEL_D))            # клавиша
		m.box(Vector3(fx, fy - 0.38, 0.06), Vector3(0.1, 0.24, 0.12), c(STEEL_D))              # труба в кожухе

## Урна-пепельница с песком и урна для мусора
static func _ashbin(m: Mesher, hv: int) -> void:
	var ax := -0.24
	_cyl(m, Vector3(ax, 0, -0.04), 0.04, 0.17, 0.17, c(BRASS_D), 12)
	_cyl(m, Vector3(ax, 0.04, -0.04), 0.56, 0.15, 0.15, c(GRANITE), 12)
	_cyl(m, Vector3(ax, 0.6, -0.04), 0.04, 0.17, 0.17, c(BRASS), 12)
	_cyl(m, Vector3(ax, 0.64, -0.04), 0.006, 0.14, 0.14, c(0xD9CFB0), 12)          # песок
	for k in 3:
		m.push()
		m.translate(Vector3(ax - 0.05 + k * 0.05, 0.655, -0.06 + (k % 2) * 0.05))
		m.rot_y(40.0 * k + float(hv % 60))
		m.rot_x(-50)
		m.box(Vector3.ZERO, Vector3(0.012, 0.05, 0.012), c(PAPER))
		m.pop()
	var bx := 0.22
	m.box(Vector3(bx, 0.36, -0.04), Vector3(0.32, 0.72, 0.32), c(GRANITE))
	m.box(Vector3(bx, 0.04, -0.04), Vector3(0.34, 0.08, 0.34), c(BRASS_D))
	m.box(Vector3(bx, 0.74, -0.04), Vector3(0.34, 0.04, 0.34), c(BRASS))
	m.box(Vector3(bx, 0.83, -0.04), Vector3(0.3, 0.14, 0.3), c(BRASS_D))
	m.box(Vector3(bx, 0.83, 0.112), Vector3(0.2, 0.08, 0.006), c(BLACK))            # откидная створка
	m.box(Vector3(bx, 0.91, -0.04), Vector3(0.26, 0.02, 0.26), c(BRASS))

# ================== зал приёма граждан ==================
## Стойки рамы над стойкой: левая — всегда, правая — только на конце ряда
static func _win_frame(m: Mesher, link: int, col: int, top: float) -> void:
	var posts := [-0.48] if (link & 2) != 0 else [-0.48, 0.48]
	for sx: float in posts:
		m.box(Vector3(sx, (1.08 + top) * 0.5, -0.33), Vector3(0.04, top - 1.08, 0.05), c(col))

## Окно приёма граждан: стойка, рама с номером окна, низкое стекло
static func _clerkwin(m: Mesher, hv: int, link: int) -> void:
	_counter(m, 1.06, OAK_D, OAK, GRANITE)
	_win_frame(m, link, OAK_D, 1.97)
	m.box(Vector3(0, 2.04, -0.33), Vector3(1.0, 0.14, 0.07), c(OAK_D))
	m.box(Vector3(0, 2.04, -0.367), Vector3(0.26, 0.1, 0.006), c(BLACK))            # табло с номером окна
	_seg7(m, Vector3(0, 2.04, -0.372), 1 + hv % 9, 0.07, c(0xFF6A3A, 0.5), true)
	var open := hv % 4 != 3
	m.box(Vector3(0.3, 2.04, -0.367), Vector3(0.06, 0.06, 0.006), c(0x58D878, 0.5) if open else c(0xE0483A, 0.5))
	m.box(Vector3(0, 1.21, -0.33), Vector3(0.92, 0.26, 0.012), c(GLASS))            # низкое стекло
	m.box(Vector3(0, 1.345, -0.33), Vector3(0.92, 0.014, 0.022), c(BRASS))
	m.box(Vector3(0, 1.086, -0.32), Vector3(0.3, 0.012, 0.2), c(STEEL))             # лоток для документов
	m.box(Vector3(-0.3, 1.09, -0.4), Vector3(0.08, 0.02, 0.05), c(BLACK))           # ручка на цепочке
	m.box(Vector3(-0.3, 1.105, -0.4), Vector3(0.012, 0.012, 0.1), c(NAVY_L))
	if not open:                                                                   # табличка «закрыто»
		m.box(Vector3(0.28, 1.15, -0.4), Vector3(0.2, 0.14, 0.02), c(CREAM))
		m.box(Vector3(0.28, 1.16, -0.411), Vector3(0.16, 0.04, 0.003), c(RED))
	var top := 0.78
	if hv % 2 == 0:
		_crt(m, Vector3(0.14, top, 0.0))
	else:
		_typewriter(m, Vector3(0.12, top, 0.12), 0x4A5A6A)
	m.box(Vector3(-0.3, top + 0.03, 0.02), Vector3(0.22, 0.06, 0.3), c(PAPER))      # бланки
	m.box(Vector3(-0.3, top + 0.062, 0.02), Vector3(0.22, 0.004, 0.3), c([0xF0C4C0, 0xC4E0C8, 0xF2E6A8][hv % 3]))
	_cyl(m, Vector3(-0.32, top, 0.3), 0.02, 0.06, 0.06, c(BLACK), 8)                # карусель штампов
	_cyl(m, Vector3(-0.32, top + 0.02, 0.3), 0.12, 0.01, 0.01, c(STEEL_D), 6)
	for k in 4:
		var a := TAU * k / 4.0
		m.box(Vector3(-0.32 + cos(a) * 0.045, top + 0.09, 0.3 + sin(a) * 0.045), Vector3(0.025, 0.07, 0.025), c(MAHOG))

## Касса: стойка с латунной решёткой и окошком
static func _cashier(m: Mesher, hv: int, link: int) -> void:
	_counter(m, 1.06, MAHOG, MAHOG_L, MARBLE)
	_win_frame(m, link, MAHOG_D, 1.92)
	m.box(Vector3(0, 2.0, -0.33), Vector3(1.0, 0.2, 0.07), c(MAHOG_D))
	m.box(Vector3(0, 2.0, -0.367), Vector3(0.52, 0.12, 0.006), c(0xF4D58A, 0.5))    # светящаяся вывеска
	for k in 5:
		m.box(Vector3(-0.16 + k * 0.08, 2.0, -0.371), Vector3(0.05, 0.07, 0.004), c(MAHOG_D))
	for k in 11:                                                                   # решётка с окошком посередине
		var bx := -0.4 + k * 0.08
		var y0 := 1.46 if absf(bx) < 0.17 else 1.08
		m.box(Vector3(bx, (y0 + 1.9) * 0.5, -0.33), Vector3(0.014, 1.9 - y0, 0.014), c(BRASS))
	m.box(Vector3(0, 1.46, -0.33), Vector3(0.92, 0.022, 0.022), c(BRASS))
	m.box(Vector3(0, 1.68, -0.33), Vector3(0.92, 0.016, 0.016), c(BRASS_D))
	for sx in [-0.3, 0.3]:
		m.box(Vector3(sx, 1.09, -0.33), Vector3(0.28, 0.02, 0.022), c(BRASS))
	m.box(Vector3(0, 1.086, -0.32), Vector3(0.3, 0.012, 0.22), c(BRASS_D))          # лоток для денег
	m.box(Vector3(0, 1.094, -0.32), Vector3(0.24, 0.006, 0.16), c(BRASS))
	var top := 0.78
	# кассовый аппарат
	var kx := -0.2
	m.box(Vector3(kx, top + 0.07, 0.02), Vector3(0.36, 0.14, 0.38), c(BEIGE_D))
	m.box(Vector3(kx, top + 0.19, -0.1), Vector3(0.36, 0.1, 0.14), c(BEIGE))
	m.box(Vector3(kx, top + 0.2, -0.028), Vector3(0.24, 0.05, 0.006), c(0x16261E))
	_seg7(m, Vector3(kx + 0.05, top + 0.2, -0.024), hv % 10, 0.035, c(0x58D878, 0.5))
	_seg7(m, Vector3(kx + 0.085, top + 0.2, -0.024), (hv / 7) % 10, 0.035, c(0x58D878, 0.5))
	for k in 12:
		m.box(Vector3(kx - 0.1 + (k % 4) * 0.055, top + 0.146, 0.03 + (k / 4) * 0.055), Vector3(0.04, 0.012, 0.04), c(DARK if k % 4 != 3 else RED))
	m.box(Vector3(kx, top + 0.03, 0.27), Vector3(0.34, 0.05, 0.14), c(DARK))        # выдвинутый ящик
	for k in 4:
		m.box(Vector3(kx - 0.12 + k * 0.08, top + 0.058, 0.27), Vector3(0.06, 0.006, 0.1), c(MONEY if k < 3 else CHROME))
	for k in 3:                                                                    # пачки купюр
		m.box(Vector3(0.22, top + 0.02 + k * 0.04, 0.06), Vector3(0.16, 0.04, 0.08), c(MONEY))
		m.box(Vector3(0.22, top + 0.02 + k * 0.04, 0.06), Vector3(0.03, 0.042, 0.082), c(PAPER))
	for k in 3:                                                                    # столбики монет
		_cyl(m, Vector3(0.34 + (k % 2) * 0.05, top, 0.24 + (k / 2) * 0.05), 0.03 + k * 0.012, 0.018, 0.018, c(CHROME if k != 1 else BRASS), 8)
	_cyl(m, Vector3(0.38, top, -0.12), 0.012, 0.04, 0.04, c(BLACK), 8)              # наколка для чеков
	m.box(Vector3(0.38, top + 0.07, -0.12), Vector3(0.004, 0.12, 0.004), c(STEEL_D))
	m.box(Vector3(0.38, top + 0.05, -0.12), Vector3(0.06, 0.03, 0.05), c(PAPER))

## Автомат с номерками очереди и табло «сейчас обслуживается»
static func _ticketer(m: Mesher, hv: int) -> void:
	var ax := -0.2
	_cyl(m, Vector3(ax, 0, 0), 0.03, 0.18, 0.17, c(DARK), 12)
	_cyl(m, Vector3(ax, 0.03, 0), 1.0, 0.025, 0.025, c(CHROME), 8)
	m.box(Vector3(ax, 1.14, 0), Vector3(0.22, 0.24, 0.16), c(RED))                  # автомат
	_disc(m, Vector3(ax, 1.14, 0.08), 0.085, 0.012, c(0x8A1A28), 12)
	m.box(Vector3(ax, 1.03, 0.085), Vector3(0.06, 0.07, 0.006), c(PAPER))           # номерок
	m.box(Vector3(ax, 1.42, 0), Vector3(0.3, 0.2, 0.02), c(CREAM))                  # табличка «возьмите номер»
	m.box(Vector3(ax, 1.46, 0.011), Vector3(0.24, 0.04, 0.003), c(RED))
	for k in 2:
		m.box(Vector3(ax, 1.4 - k * 0.04, 0.011), Vector3(0.2 - k * 0.05, 0.016, 0.003), c(0x4A4F58))
	m.box(Vector3(ax, 1.29, 0), Vector3(0.02, 0.1, 0.02), c(CHROME))
	var dx := 0.22
	_cyl(m, Vector3(dx, 0, -0.04), 0.03, 0.16, 0.15, c(DARK), 12)
	_cyl(m, Vector3(dx, 0.03, -0.04), 1.7, 0.022, 0.022, c(CHROME), 8)
	m.box(Vector3(dx, 1.86, -0.04), Vector3(0.46, 0.3, 0.1), c(DARK))               # табло
	m.box(Vector3(dx, 1.96, 0.012), Vector3(0.36, 0.035, 0.004), c(CREAM))
	var num := 10 + hv % 89
	_seg7(m, Vector3(dx - 0.07, 1.83, 0.012), num / 10, 0.13, c(0xFF4A30, 0.5))
	_seg7(m, Vector3(dx + 0.07, 1.83, 0.012), num % 10, 0.13, c(0xFF4A30, 0.5))

## Стойка для заполнения бланков: наклонная доска, ячейки с бланками
static func _formdesk(m: Mesher, hv: int) -> void:
	for sx in [-0.45, 0.45]:
		m.box(Vector3(sx, 0.5, -0.02), Vector3(0.05, 1.0, 0.5), c(OAK_D))
	m.box(Vector3(0, 0.55, -0.26), Vector3(0.9, 1.1, 0.03), c(OAK_D))
	m.box(Vector3(0, 0.3, -0.02), Vector3(0.86, 0.03, 0.46), c(OAK))                # полка
	m.box(Vector3(0, 0.36, -0.05), Vector3(0.5, 0.09, 0.3), c(PAPER))               # запас бланков
	m.push()
	m.translate(Vector3(0, 1.04, 0.0))
	m.rot_x(12)
	m.box(Vector3.ZERO, Vector3(0.96, 0.04, 0.56), c(OAK))
	m.box(Vector3(0, 0.03, 0.265), Vector3(0.96, 0.03, 0.025), c(OAK_D))            # бортик
	for k in 2:
		m.box(Vector3(-0.22 + k * 0.44, 0.023, 0.02), Vector3(0.24, 0.006, 0.32), c([0xF0C4C0, 0xC4E0C8, 0xF2E6A8][(hv + k) % 3]))
		for ln in 5:
			m.box(Vector3(-0.22 + k * 0.44, 0.027, -0.09 + ln * 0.05), Vector3(0.18, 0.002, 0.008), c(0x6A6F7A))
		m.box(Vector3(-0.06 + k * 0.44, 0.03, 0.18), Vector3(0.012, 0.012, 0.11), c(BLACK))    # ручка
	m.pop()
	m.box(Vector3(0, 1.42, -0.2), Vector3(0.94, 0.52, 0.16), c(OAK_D))              # ячейки с бланками
	for k in 8:
		var px := -0.345 + (k % 4) * 0.23
		var py := 1.31 + (k / 4) * 0.24
		m.box(Vector3(px, py, -0.117), Vector3(0.2, 0.2, 0.006), c(0x3A2A1C))
		m.box(Vector3(px, py - 0.03, -0.11), Vector3(0.17, 0.13, 0.012), c([PAPER, 0xF0C4C0, 0xC4E0C8, 0xF2E6A8, 0xC8D4EC][(hv + k) % 5]))
	m.box(Vector3(0, 1.73, -0.2), Vector3(0.94, 0.1, 0.16), c(GREEN))               # вывеска
	m.box(Vector3(0, 1.73, -0.118), Vector3(0.5, 0.04, 0.004), c(CREAM))

## Кресла ожидания на общей балке (два места в клетке)
static func _waitchairs(m: Mesher, hv: int, link: int) -> void:
	var col: int = [0x2F6E78, 0xB5562A, 0x2E4468][hv % 3]
	var col_d: int = [0x245860, 0x94441E, 0x1F2F4A][hv % 3]
	m.box(Vector3(0, 0.36, -0.04), Vector3(1.0, 0.05, 0.07), c(STEEL_D))            # балка
	for sx in [-0.3, 0.3]:
		m.box(Vector3(sx, 0.18, -0.04), Vector3(0.05, 0.34, 0.06), c(STEEL_D))
		m.box(Vector3(sx, 0.015, -0.02), Vector3(0.06, 0.03, 0.5), c(BLACK))
	for sx: float in [-0.245, 0.245]:
		m.box(Vector3(sx, 0.43, 0.0), Vector3(0.43, 0.05, 0.44), c(col))
		m.box(Vector3(sx, 0.4, 0.0), Vector3(0.39, 0.04, 0.4), c(BLACK))
		m.push()
		m.translate(Vector3(sx, 0.47, -0.22))
		m.rot_x(-10)
		m.box(Vector3(0, 0.2, 0), Vector3(0.43, 0.42, 0.045), c(col))
		m.box(Vector3(0, 0.2, 0.024), Vector3(0.35, 0.3, 0.004), c(col_d))
		m.pop()
	var arms := [0.0]
	if (link & 1) == 0:
		arms.append(-0.485)
	if (link & 2) == 0:
		arms.append(0.485)
	for ax: float in arms:                                                         # подлокотники: между местами и на концах ряда
		m.box(Vector3(ax, 0.54, 0.16), Vector3(0.025, 0.2, 0.025), c(STEEL_D))
		m.box(Vector3(ax, 0.54, -0.16), Vector3(0.025, 0.2, 0.025), c(STEEL_D))
		m.box(Vector3(ax, 0.65, 0.0), Vector3(0.045, 0.03, 0.38), c(BLACK))

## Стол секретаря: пишущая машинка, лотки, картотека-вертушка
static func _typedesk(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.76, -0.02), Vector3(0.98, 0.04, 0.82), c(OAK))
	m.box(Vector3(0, 0.735, -0.02), Vector3(0.96, 0.015, 0.8), c(OAK_D))
	m.box(Vector3(0.29, 0.37, -0.02), Vector3(0.36, 0.72, 0.76), c(OAK_D))          # тумба
	for d in 3:
		m.box(Vector3(0.29, 0.14 + d * 0.22, 0.363), Vector3(0.32, 0.19, 0.012), c(OAK))
		m.box(Vector3(0.29, 0.14 + d * 0.22, 0.372), Vector3(0.1, 0.02, 0.012), c(BRASS))
	m.box(Vector3(-0.46, 0.37, -0.02), Vector3(0.04, 0.72, 0.76), c(OAK_D))
	m.box(Vector3(-0.09, 0.45, -0.41), Vector3(0.74, 0.5, 0.02), c(OAK_D))
	var top := 0.78
	_typewriter(m, Vector3(-0.12, top, 0.02), [0x4A5A6A, 0xB5AE9A, 0x3F5A5A][hv % 3])
	_trays(m, Vector3(0.33, top, -0.22), MAHOG)
	# картотека-вертушка
	m.box(Vector3(0.3, top + 0.015, 0.2), Vector3(0.14, 0.03, 0.12), c(BLACK))
	_cyl_x(m, Vector3(0.24, top + 0.08, 0.2), 0.12, 0.055, c(CREAM), 10)
	for sx in [0.235, 0.365]:
		_cyl_x(m, Vector3(sx - 0.005, top + 0.08, 0.2), 0.01, 0.062, c(BLACK), 10)
	# лампа на гибкой ножке
	_cyl(m, Vector3(-0.4, top, -0.32), 0.02, 0.06, 0.05, c(BLACK), 8)
	_cyl(m, Vector3(-0.4, top + 0.02, -0.32), 0.3, 0.01, 0.01, c(BRASS), 6)
	m.box(Vector3(-0.35, top + 0.33, -0.3), Vector3(0.2, 0.04, 0.1), c(BLACK))
	m.box(Vector3(-0.35, top + 0.307, -0.3), Vector3(0.16, 0.008, 0.07), c(0xFFF0B0, 0.5))
	m.box(Vector3(-0.4, top + 0.008, 0.24), Vector3(0.14, 0.016, 0.2), c(YELLOW))   # блокнот
	m.box(Vector3(-0.4, top + 0.018, 0.15), Vector3(0.14, 0.008, 0.02), c(MAHOG_D))
	if hv % 2 == 0:                                                                # ваза с цветами
		_cyl(m, Vector3(0.42, top, 0.02), 0.12, 0.03, 0.04, c(0x9CCBEA), 8)
		for k in 3:
			m.ellipsoid(Vector3(0.4 + k * 0.025, top + 0.2 + (k % 2) * 0.03, 0.02 + (k - 1) * 0.02), Vector3(0.03, 0.03, 0.03), c([RED, YELLOW, 0xF0C4C0][k]), 3, 6)
			m.box(Vector3(0.41 + k * 0.012, top + 0.15, 0.02), Vector3(0.006, 0.1, 0.006), c(GREEN))
	else:
		_mug(m, Vector3(0.42, top, 0.02), 0xECEBE5)

## Фотокабина: слева вход за шторкой, справа автомат
static func _photobooth(m: Mesher) -> void:
	m.box(Vector3(0, 0.03, 0), Vector3(0.94, 0.06, 0.76), c(BLACK))
	m.box(Vector3(0, 1.0, -0.36), Vector3(0.94, 1.9, 0.05), c(0x2F6E78))
	m.box(Vector3(-0.45, 1.0, 0), Vector3(0.04, 1.9, 0.76), c(0x2F6E78))
	m.box(Vector3(0.27, 1.0, 0), Vector3(0.4, 1.9, 0.76), c(0x2F6E78))             # автомат
	m.box(Vector3(0, 1.98, 0), Vector3(0.96, 0.08, 0.78), c(0x245860))
	m.box(Vector3(0, 1.84, 0.385), Vector3(0.94, 0.22, 0.03), c(0xF4EAC8, 0.5))     # светящаяся вывеска
	for k in 4:
		m.box(Vector3(-0.21 + k * 0.14, 1.84, 0.402), Vector3(0.09, 0.12, 0.004), c(RED))
	for k in 6:                                                                    # шторка складками
		m.box(Vector3(-0.4 + k * 0.058, 1.12, 0.36 + (k % 2) * 0.016), Vector3(0.062, 1.22, 0.02), c(VELVET if k % 2 == 0 else 0x641824))
	m.box(Vector3(-0.2, 1.74, 0.37), Vector3(0.48, 0.02, 0.02), c(CHROME))
	_cyl(m, Vector3(-0.22, 0.06, -0.02), 0.4, 0.03, 0.03, c(CHROME), 8)             # табурет
	_cyl(m, Vector3(-0.22, 0.46, -0.02), 0.05, 0.15, 0.15, c(BLACK), 12)
	# лицевая панель автомата
	m.box(Vector3(0.27, 1.38, 0.382), Vector3(0.3, 0.36, 0.006), c(0xDCE8EC))       # зеркало
	m.box(Vector3(0.27, 1.38, 0.386), Vector3(0.32, 0.38, 0.003), c(CHROME))
	m.box(Vector3(0.27, 1.38, 0.389), Vector3(0.28, 0.34, 0.003), c(0xDCE8EC))
	for k in 2:                                                                    # образцы снимков
		m.box(Vector3(0.19 + k * 0.16, 0.92, 0.382), Vector3(0.1, 0.4, 0.006), c(PAPER))
		for q in 4:
			m.box(Vector3(0.19 + k * 0.16, 1.07 - q * 0.095, 0.387), Vector3(0.08, 0.075, 0.003), c([0x6E7C8A, 0x8A6E5A, 0x5A7A6A, 0x7A6E8A][(q + k) % 4]))
			m.box(Vector3(0.19 + k * 0.16, 1.075 - q * 0.095, 0.39), Vector3(0.03, 0.035, 0.003), c(0xD9B08C))
	m.box(Vector3(0.27, 0.6, 0.382), Vector3(0.14, 0.04, 0.008), c(CHROME))         # щель выдачи
	m.box(Vector3(0.38, 1.12, 0.382), Vector3(0.05, 0.1, 0.008), c(CHROME))         # монетоприёмник
	m.box(Vector3(0.38, 1.14, 0.388), Vector3(0.006, 0.03, 0.004), c(BLACK))
	for k in 3:                                                                    # полосы
		m.box(Vector3(0.27, 0.2 + k * 0.07, 0.382), Vector3(0.4, 0.04, 0.004), c([RED, YELLOW, CREAM][k]))

# ================== архив и земельный отдел ==================
## Архивный стеллаж: коробки с делами, переплетённые книги, рулоны карт
static func _archshelf(m: Mesher, hv: int) -> void:
	for sx in [-0.46, 0.46]:
		for sz in [-0.19, 0.19]:
			m.box(Vector3(sx, 1.0, sz), Vector3(0.035, 2.0, 0.035), c(STEEL_D))
	m.box(Vector3(0, 1.0, -0.21), Vector3(0.92, 2.0, 0.01), c(0x6E747A))
	for s in 5:
		var sy := 0.1 + s * 0.44
		m.box(Vector3(0, sy, 0), Vector3(0.94, 0.03, 0.42), c(STEEL))
		if s == 4:                                                                 # наверху — рулоны карт и коробка
			for k in 4:
				_cyl_z(m, Vector3(-0.34 + k * 0.1, sy + 0.055 + (k % 2) * 0.004, -0.18), 0.36, 0.04, c([PAPER, 0xC8D4EC, MANILA, PAPER][k]), 8)
			m.box(Vector3(0.26, sy + 0.1, 0), Vector3(0.3, 0.17, 0.34), c(0x9A7A52))
			continue
		if (s + hv) % 2 == 0:                                                      # архивные коробки
			for k in 3:
				var bx := -0.3 + k * 0.3
				m.box(Vector3(bx, sy + 0.17, 0), Vector3(0.27, 0.31, 0.36), c(0x9A7A52 if (k + s + hv) % 3 != 0 else 0x7E8088))
				m.box(Vector3(bx, sy + 0.325, 0), Vector3(0.28, 0.03, 0.37), c(0x86683F if (k + s + hv) % 3 != 0 else 0x6A6C74))
				m.box(Vector3(bx, sy + 0.2, 0.182), Vector3(0.16, 0.09, 0.004), c(PAPER))
				m.box(Vector3(bx, sy + 0.2, 0.185), Vector3(0.1, 0.012, 0.003), c(0x4A4F58))
				m.box(Vector3(bx, sy + 0.09, 0.182), Vector3(0.08, 0.03, 0.004), c(BLACK))
		else:                                                                      # переплетённые книги записей
			var x := -0.43
			var k2 := 0
			while x < 0.36:
				var bw := 0.055 + ((hv >> (k2 + s)) % 3) * 0.015
				var bh := 0.3 + ((hv >> (k2 * 2 + s)) % 3) * 0.03
				var col: int = [0x2A4A36, 0x6A1F22, 0x1F2F4A, 0x3A2A1C][(hv + k2 + s) % 4]
				m.box(Vector3(x + bw * 0.5, sy + 0.015 + bh * 0.5, 0.0), Vector3(bw - 0.006, bh, 0.3), c(col))
				m.box(Vector3(x + bw * 0.5, sy + 0.015 + bh * 0.8, 0.152), Vector3(bw - 0.006, 0.02, 0.003), c(BRASS))
				m.box(Vector3(x + bw * 0.5, sy + 0.015 + bh * 0.3, 0.152), Vector3(bw - 0.02, 0.05, 0.003), c(CREAM))
				x += bw
				k2 += 1

## Картотека с ящичками
static func _cardcat(m: Mesher, hv: int) -> void:
	for sx in [-0.4, 0.4]:
		for sz in [-0.17, 0.17]:
			m.box(Vector3(sx, 0.2, sz), Vector3(0.05, 0.4, 0.05), c(OAK_D))
	m.box(Vector3(0, 0.14, 0), Vector3(0.8, 0.03, 0.34), c(OAK_D))
	m.box(Vector3(0, 0.88, 0), Vector3(0.92, 0.98, 0.44), c(OAK))
	m.box(Vector3(0, 1.39, 0), Vector3(0.96, 0.04, 0.46), c(OAK_D))
	m.box(Vector3(0, 0.4, 0), Vector3(0.96, 0.04, 0.46), c(OAK_D))
	var pull := hv % 30
	for k in 30:
		var dx := -0.36 + (k % 6) * 0.144
		var dy := 0.5 + (k / 6) * 0.185
		var out := 0.16 if k == pull else 0.0
		m.box(Vector3(dx, dy, 0.222 + out), Vector3(0.128, 0.165, 0.012), c(OAK_L))
		m.box(Vector3(dx, dy + 0.03, 0.23 + out), Vector3(0.07, 0.04, 0.006), c(BRASS_D))      # рамка ярлыка
		m.box(Vector3(dx, dy + 0.03, 0.234 + out), Vector3(0.055, 0.026, 0.003), c(PAPER))
		m.box(Vector3(dx, dy - 0.04, 0.235 + out), Vector3(0.03, 0.02, 0.016), c(BRASS))       # ручка
		if out > 0.0:                                                              # выдвинутый ящик с карточками
			m.box(Vector3(dx, dy - 0.02, 0.22 + out * 0.5), Vector3(0.12, 0.12, out), c(OAK_D))
			m.box(Vector3(dx, dy + 0.05, 0.22 + out * 0.5), Vector3(0.1, 0.03, out - 0.02), c(PAPER))
	m.box(Vector3(-0.22, 1.44, 0), Vector3(0.3, 0.06, 0.22), c(0x6A1F22))           # каталог сверху
	m.box(Vector3(-0.22, 1.475, 0), Vector3(0.28, 0.008, 0.2), c(PAPER))
	m.box(Vector3(0.24, 1.45, -0.02), Vector3(0.2, 0.08, 0.14), c(STEEL))           # ящичек с карточками
	m.box(Vector3(0.24, 1.5, -0.02), Vector3(0.17, 0.04, 0.11), c(PAPER))

## Шкаф для чертежей: широкие плоские ящики, сверху рулоны и развёрнутый план
static func _plancab(m: Mesher, hv: int) -> void:
	var body := 0x7E8A84
	m.box(Vector3(0, 0.04, -0.01), Vector3(0.92, 0.08, 0.66), c(BLACK))
	m.box(Vector3(0, 0.5, -0.01), Vector3(0.96, 0.84, 0.7), c(body))
	m.box(Vector3(0, 0.935, -0.01), Vector3(0.98, 0.03, 0.72), c(0x66726C))
	for d in 7:
		var dy := 0.15 + d * 0.115
		m.box(Vector3(0, dy, 0.342), Vector3(0.9, 0.1, 0.008), c(0x8E9A94))
		m.box(Vector3(0, dy + 0.012, 0.348), Vector3(0.12, 0.035, 0.006), c(CHROME))
		m.box(Vector3(0, dy + 0.012, 0.352), Vector3(0.1, 0.022, 0.003), c(PAPER))
		for sx in [-0.3, 0.3]:
			m.box(Vector3(sx, dy - 0.01, 0.35), Vector3(0.1, 0.018, 0.012), c(CHROME))
	var top := 0.95
	m.push()                                                                       # развёрнутый план
	m.translate(Vector3(-0.08, top + 0.004, 0.04))
	m.rot_y(-6.0 + float(hv % 12))
	m.box(Vector3.ZERO, Vector3(0.62, 0.006, 0.44), c(0x2F5FA8))
	m.box(Vector3(0, 0.004, 0), Vector3(0.5, 0.002, 0.008), c(PAPER))
	m.box(Vector3(0, 0.004, 0.12), Vector3(0.5, 0.002, 0.008), c(PAPER))
	m.box(Vector3(0, 0.004, -0.12), Vector3(0.5, 0.002, 0.008), c(PAPER))
	for k in 4:
		m.box(Vector3(-0.25 + k * 0.166, 0.004, 0), Vector3(0.008, 0.002, 0.25), c(PAPER))
	m.box(Vector3(0.1, 0.004, 0.06), Vector3(0.14, 0.002, 0.1), c(0x9CB8E8))
	m.pop()
	for k in 3:                                                                    # рулоны
		_cyl_x(m, Vector3(-0.42 + k * 0.03, top + 0.04 + (k % 2) * 0.06, -0.26 + (k / 2) * 0.07), 0.62, 0.035, c([PAPER, 0xC8D4EC, 0x2F5FA8][k]), 8)
	m.box(Vector3(0.36, top + 0.03, 0.2), Vector3(0.1, 0.06, 0.1), c(BRASS))        # грузик
	m.push()                                                                       # линейка
	m.translate(Vector3(0.3, top + 0.012, -0.06))
	m.rot_y(70)
	m.box(Vector3.ZERO, Vector3(0.36, 0.012, 0.035), c(0xD9B45A))
	m.pop()

## Макет города на подиуме
static func _citymodel(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.36, 0), Vector3(0.84, 0.72, 0.7), c(MAHOG_D))
	for k in 2:
		m.box(Vector3(-0.2 + k * 0.4, 0.38, 0.352), Vector3(0.32, 0.5, 0.006), c(MAHOG))
	m.box(Vector3(0, 0.03, 0), Vector3(0.88, 0.06, 0.74), c(MAHOG))
	m.box(Vector3(0, 0.75, 0), Vector3(0.96, 0.06, 0.8), c(MAHOG))
	var top := 0.78
	m.box(Vector3(0, top + 0.004, 0), Vector3(0.9, 0.008, 0.74), c(0x7FA66A))       # земля
	m.box(Vector3(0, top + 0.01, 0.02), Vector3(0.9, 0.004, 0.06), c(0x5A5F66))     # улицы
	m.box(Vector3(-0.08, top + 0.01, 0), Vector3(0.06, 0.004, 0.74), c(0x5A5F66))
	m.box(Vector3(0.24, top + 0.01, 0), Vector3(0.045, 0.004, 0.74), c(0x5A5F66))
	m.push()                                                                       # река
	m.translate(Vector3(-0.32, top + 0.011, 0))
	m.rot_y(14)
	m.box(Vector3.ZERO, Vector3(0.09, 0.004, 0.8), c(0x4A8AD0))
	m.pop()
	m.box(Vector3(-0.31, top + 0.02, 0.02), Vector3(0.14, 0.012, 0.05), c(0x9A9EA2))        # мост
	# мэрия с куполом на площади
	m.box(Vector3(0.08, top + 0.012, -0.16), Vector3(0.22, 0.004, 0.22), c(0xD9D4C4))
	m.box(Vector3(0.08, top + 0.05, -0.18), Vector3(0.16, 0.08, 0.12), c(CREAM))
	m.box(Vector3(0.08, top + 0.04, -0.11), Vector3(0.1, 0.06, 0.02), c(MARBLE_D))
	m.ellipsoid(Vector3(0.08, top + 0.09, -0.18), Vector3(0.04, 0.045, 0.04), c(BRASS), 3, 8, 0.0, 0.5)
	var cols := [0xB5562A, CREAM, 0x8A9096, 0xC9BDA0, 0x7A4A3A, 0xD9D4C4]
	var spots := [Vector2(0.36, -0.26), Vector2(0.36, -0.1), Vector2(0.38, 0.18), Vector2(0.36, 0.3), Vector2(0.08, 0.16), Vector2(0.1, 0.3),
		Vector2(-0.2, 0.16), Vector2(-0.19, 0.29), Vector2(-0.2, -0.12), Vector2(-0.19, -0.28), Vector2(0.14, 0.1), Vector2(-0.42, -0.2), Vector2(-0.42, 0.24)]
	for k in spots.size():
		var q: Vector2 = spots[k]
		var bh := 0.04 + ((hv >> k) % 5) * 0.03
		var bw := 0.07 + ((hv >> (k + 3)) % 3) * 0.02
		m.box(Vector3(q.x, top + 0.008 + bh * 0.5, q.y), Vector3(bw, bh, 0.08 + ((hv >> (k + 5)) % 2) * 0.03), c(cols[(hv + k) % 6]))
		m.box(Vector3(q.x, top + 0.01 + bh, q.y), Vector3(bw - 0.02, 0.006, 0.06), c(0x4A4F55))
	for k in 8:                                                                    # деревья парка
		var tp := Vector3(0.0 + (k % 4) * 0.045, top + 0.03, -0.3 + (k / 4) * 0.05)
		m.ellipsoid(tp, Vector3(0.02, 0.025, 0.02), c(0x3F7A3A), 3, 5)
	for sx in [-0.465, 0.465]:                                                     # прозрачный колпак: стойки и рама
		for sz in [-0.385, 0.385]:
			m.box(Vector3(sx, top + 0.15, sz), Vector3(0.014, 0.3, 0.014), c(BRASS))
	for sz2 in [-0.385, 0.385]:
		m.box(Vector3(0, top + 0.3, sz2), Vector3(0.944, 0.014, 0.014), c(BRASS))
	for sx2 in [-0.465, 0.465]:
		m.box(Vector3(sx2, top + 0.3, 0), Vector3(0.014, 0.014, 0.784), c(BRASS))
	m.box(Vector3(0, 0.74, 0.402), Vector3(0.3, 0.05, 0.006), c(BRASS))             # табличка

## Чертёжный стол с наклонной доской
static func _drafttable(m: Mesher) -> void:
	for sx in [-0.4, 0.4]:
		m.box(Vector3(sx, 0.02, 0), Vector3(0.05, 0.04, 0.6), c(BLACK))
		m.box(Vector3(sx, 0.48, -0.06), Vector3(0.045, 0.9, 0.06), c(STEEL_D))
		m.push()
		m.translate(Vector3(sx, 0.48, 0.1))
		m.rot_x(24)
		m.box(Vector3.ZERO, Vector3(0.04, 0.9, 0.04), c(STEEL_D))
		m.pop()
	m.box(Vector3(0, 0.3, -0.06), Vector3(0.8, 0.04, 0.04), c(STEEL_D))
	m.push()
	m.translate(Vector3(0, 1.0, -0.02))
	m.rot_x(26)
	m.box(Vector3(0, 0.0, 0.0), Vector3(1.0, 0.03, 0.74), c(OAK_D))                 # доска
	m.box(Vector3(0, 0.002, 0.0), Vector3(0.96, 0.036, 0.7), c(0xB8C8B0))
	m.box(Vector3(0.02, 0.022, -0.02), Vector3(0.7, 0.004, 0.5), c(0x2F5FA8))       # чертёж
	m.box(Vector3(0.02, 0.026, -0.02), Vector3(0.5, 0.002, 0.3), c(PAPER))
	m.box(Vector3(0.02, 0.028, -0.02), Vector3(0.48, 0.002, 0.28), c(0x2F5FA8))
	m.box(Vector3(-0.06, 0.03, -0.02), Vector3(0.008, 0.002, 0.28), c(PAPER))
	m.box(Vector3(0.1, 0.03, 0.04), Vector3(0.3, 0.002, 0.008), c(PAPER))
	m.box(Vector3(0.16, 0.03, -0.08), Vector3(0.008, 0.002, 0.16), c(PAPER))
	m.box(Vector3(0, 0.032, 0.14), Vector3(0.96, 0.012, 0.045), c(0xD9B45A))        # рейсшина
	m.push()                                                                       # угольник
	m.translate(Vector3(-0.3, 0.03, -0.14))
	m.rot_y(20)
	m.box(Vector3.ZERO, Vector3(0.2, 0.006, 0.12), c(0xE8943A))
	m.pop()
	m.box(Vector3(0, 0.035, 0.345), Vector3(0.9, 0.04, 0.03), c(OAK_D))             # полочка для карандашей
	for k in 4:
		m.box(Vector3(-0.2 + k * 0.05, 0.035, 0.315), Vector3(0.14, 0.012, 0.012), c([YELLOW, RED, BLUE, YELLOW][k]))
	m.pop()
	# лампа на кронштейне у верхнего угла
	m.box(Vector3(-0.44, 1.2, -0.3), Vector3(0.04, 0.1, 0.04), c(BLACK))
	m.push()
	m.translate(Vector3(-0.44, 1.24, -0.3))
	m.rot_z(-20)
	m.box(Vector3(0, 0.2, 0), Vector3(0.02, 0.4, 0.02), c(BLACK))
	m.translate(Vector3(0, 0.4, 0))
	m.rot_z(-75)
	m.box(Vector3(0, 0.15, 0), Vector3(0.02, 0.3, 0.02), c(BLACK))
	m.pop()
	_cyl(m, Vector3(-0.02, 1.58, -0.3), 0.1, 0.09, 0.04, c(BLACK), 8)
	_cyl(m, Vector3(-0.02, 1.575, -0.3), 0.006, 0.075, 0.075, c(0xFFF0B0, 0.5), 8)

## Аппарат для чтения микрофильмов на столике
static func _microfilm(m: Mesher) -> void:
	for sx in [-0.42, 0.42]:
		for sz in [-0.26, 0.26]:
			m.box(Vector3(sx, 0.36, sz), Vector3(0.04, 0.72, 0.04), c(STEEL_D))
	m.box(Vector3(0, 0.74, 0), Vector3(0.92, 0.04, 0.6), c(0xCFCBBE))
	m.box(Vector3(0, 0.3, 0), Vector3(0.84, 0.02, 0.5), c(STEEL))
	var top := 0.76
	var ax := -0.12
	m.box(Vector3(ax, top + 0.05, 0.0), Vector3(0.52, 0.1, 0.5), c(BEIGE_D))        # основание с кареткой
	m.box(Vector3(ax, top + 0.105, 0.14), Vector3(0.34, 0.012, 0.16), c(GLASS))
	m.box(Vector3(ax, top + 0.42, -0.06), Vector3(0.52, 0.56, 0.36), c(BEIGE))      # кожух с экраном
	m.box(Vector3(ax, top + 0.45, 0.122), Vector3(0.44, 0.42, 0.006), c(DARK))
	m.box(Vector3(ax, top + 0.45, 0.126), Vector3(0.38, 0.36, 0.004), c(0xE6EAD0, 0.5))
	for k in 7:                                                                    # газетная полоса на экране
		m.box(Vector3(ax - 0.09, top + 0.58 - k * 0.04, 0.13), Vector3(0.16, 0.012, 0.003), c(0x4A4F48))
		if k > 1:
			m.box(Vector3(ax + 0.1, top + 0.58 - k * 0.04, 0.13), Vector3(0.14, 0.012, 0.003), c(0x4A4F48))
	m.box(Vector3(ax + 0.1, top + 0.56, 0.13), Vector3(0.14, 0.07, 0.003), c(0x8A8F88))
	for sx2: float in [-0.21, 0.21]:                                               # катушки с плёнкой
		_cyl_z(m, Vector3(ax + sx2, top + 0.17, 0.12), 0.03, 0.055, c(DARK), 10)
		_cyl_z(m, Vector3(ax + sx2, top + 0.17, 0.15), 0.008, 0.02, c(CHROME), 6)
	m.box(Vector3(ax + 0.29, top + 0.12, 0.1), Vector3(0.05, 0.03, 0.03), c(BLACK))  # ручка перемотки
	m.box(Vector3(ax + 0.32, top + 0.14, 0.1), Vector3(0.02, 0.06, 0.02), c(BLACK))
	for k in 5:                                                                    # коробочки с плёнками
		m.box(Vector3(0.32, top + 0.03 + (k / 2) * 0.06, -0.16 + (k % 2) * 0.12), Vector3(0.11, 0.055, 0.11), c([0xD9C58A, 0xC8D4EC, 0xD9C58A, 0xF0C4C0, 0xD9C58A][k]))
	m.box(Vector3(0.32, top + 0.006, 0.18), Vector3(0.18, 0.012, 0.16), c(PAPER))   # распечатка
	m.box(Vector3(0, 0.36, 0), Vector3(0.3, 0.1, 0.36), c(0x9A7A52))                # коробка на нижней полке
	m.box(Vector3(0, 0.33, 0.0), Vector3(0.31, 0.03, 0.37), c(0x86683F))

# ================== кабинет мэра ==================
## Стол мэра: массивный, с кожаной вставкой (на две клетки)
static func _mayordesk(m: Mesher, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	var x1 := x0 + L
	m.box(Vector3(cx, 0.78, -0.01), Vector3(L, 0.05, 0.88), c(MAHOG))
	m.box(Vector3(cx, 0.745, -0.01), Vector3(L - 0.03, 0.03, 0.85), c(MAHOG_D))
	var peds := [x0 + 0.24, x1 - 0.24] if wide else [x1 - 0.24]
	for px: float in peds:
		m.box(Vector3(px, 0.39, -0.01), Vector3(0.44, 0.68, 0.8), c(MAHOG_D))
		m.box(Vector3(px, 0.03, -0.01), Vector3(0.46, 0.06, 0.82), c(MAHOG))
		for d in 3:
			m.box(Vector3(px, 0.17 + d * 0.21, 0.393), Vector3(0.38, 0.18, 0.012), c(MAHOG))
			m.box(Vector3(px, 0.17 + d * 0.21, 0.402), Vector3(0.1, 0.02, 0.012), c(BRASS))
	if not wide:
		m.box(Vector3(x0 + 0.03, 0.365, -0.01), Vector3(0.06, 0.73, 0.8), c(MAHOG_D))
	m.box(Vector3(cx, 0.4, -0.415), Vector3(L - 0.04, 0.7, 0.03), c(MAHOG_D))       # лицевая панель с филёнками
	var pn := 4 if wide else 2
	var pw := (L - 0.16) / pn
	for k in pn:
		var px2 := x0 + 0.08 + pw * (k + 0.5)
		m.box(Vector3(px2, 0.42, -0.433), Vector3(pw - 0.06, 0.5, 0.008), c(MAHOG))
		m.box(Vector3(px2, 0.42, -0.438), Vector3(pw - 0.14, 0.4, 0.006), c(MAHOG_D))
	if wide:
		_seal(m, Vector3(cx, 0.42, -0.442), 0.17, -1.0)
	var top := 0.805
	var iw := 0.86 if wide else 0.5
	m.box(Vector3(cx, top + 0.003, 0.12), Vector3(iw + 0.03, 0.006, 0.5), c(BRASS))  # кожаная вставка с золотой каймой
	m.box(Vector3(cx, top + 0.005, 0.12), Vector3(iw, 0.006, 0.47), c(LEATHER))
	m.box(Vector3(cx - 0.04, top + 0.011, 0.14), Vector3(0.22, 0.004, 0.3), c(PAPER))
	for ln in 4:
		m.box(Vector3(cx - 0.04, top + 0.014, 0.05 + ln * 0.05), Vector3(0.17, 0.002, 0.008), c(0x5A5F70))
	m.box(Vector3(cx + 0.14, top + 0.016, 0.14), Vector3(0.012, 0.012, 0.15), c(BRASS))    # ручка
	m.box(Vector3(cx, top + 0.035, -0.37), Vector3(0.34, 0.07, 0.05), c(MAHOG_D))   # табличка — к посетителю
	m.box(Vector3(cx, top + 0.035, -0.397), Vector3(0.28, 0.04, 0.006), c(BRASS))
	_lamp(m, Vector3(x0 + 0.26, top, -0.2))
	if wide:
		# телефон с кнопками линий
		m.box(Vector3(x1 - 0.3, top + 0.03, -0.14), Vector3(0.26, 0.06, 0.22), c(BLACK))
		m.box(Vector3(x1 - 0.39, top + 0.075, -0.14), Vector3(0.055, 0.035, 0.22), c(DARK))
		for k in 6:
			m.box(Vector3(x1 - 0.28 + (k % 2) * 0.05, top + 0.063, -0.2 + (k / 2) * 0.05), Vector3(0.03, 0.006, 0.03),
				c(0xE0483A, 0.5) if k == 1 else c(0xC8CCD0))
		# письменный прибор из мрамора с двумя ручками
		m.box(Vector3(cx + 0.02, top + 0.015, -0.16), Vector3(0.26, 0.03, 0.1), c(GRANITE))
		for sg: float in [-1.0, 1.0]:
			m.push()
			m.translate(Vector3(cx + 0.02 + sg * 0.08, top + 0.03, -0.16))
			m.rot_z(-18.0 * sg)
			m.box(Vector3(0, 0.07, 0), Vector3(0.012, 0.14, 0.012), c(BLACK))
			m.box(Vector3(0, 0.005, 0), Vector3(0.026, 0.02, 0.026), c(BRASS))
			m.pop()
		# настольные флажки
		var fx := cx + 0.3
		m.box(Vector3(fx, top + 0.012, -0.28), Vector3(0.12, 0.024, 0.06), c(MAHOG_D))
		for sg2: float in [-1.0, 1.0]:
			m.box(Vector3(fx + sg2 * 0.035, top + 0.13, -0.28), Vector3(0.006, 0.22, 0.006), c(BRASS))
			m.box(Vector3(fx + sg2 * 0.035 + 0.04, top + 0.2, -0.278), Vector3(0.075, 0.055, 0.004), c(RED if sg2 < 0.0 else NAVY))
			m.box(Vector3(fx + sg2 * 0.035 + 0.04, top + 0.2, -0.275), Vector3(0.075, 0.012, 0.003), c(CREAM if sg2 < 0.0 else BRASS))
		m.box(Vector3(x1 - 0.3, top + 0.02, 0.2), Vector3(0.26, 0.04, 0.34), c(MANILA))        # папки на подпись
		m.box(Vector3(x1 - 0.29, top + 0.047, 0.21), Vector3(0.26, 0.014, 0.34), c(0x6A1F22))
		m.push()                                                                               # фото в рамке
		m.translate(Vector3(x0 + 0.26, top, 0.22))
		m.rot_y(25)
		m.rot_x(-12)
		m.box(Vector3(0, 0.09, 0), Vector3(0.14, 0.18, 0.015), c(BRASS))
		m.box(Vector3(0, 0.09, 0.009), Vector3(0.11, 0.15, 0.004), c(0x6E7C8A))
		m.pop()
		m.box(Vector3(x0 + 0.5, top + 0.035, -0.26), Vector3(0.2, 0.07, 0.13), c(MAHOG_L))     # шкатулка
		m.box(Vector3(x0 + 0.5, top + 0.04, -0.193), Vector3(0.03, 0.03, 0.006), c(BRASS))
	else:
		_phone(m, Vector3(x1 - 0.26, top, -0.14))
	_mug(m, Vector3(cx - 0.34 if wide else x0 + 0.14, top, 0.26), 0xECEBE5)

## Кресло руководителя: высокая стёганая спинка, спинка со стороны -z
static func _execchair(m: Mesher) -> void:
	for k in 5:
		m.push()
		m.rot_y(k * 72.0 + 18.0)
		m.box(Vector3(0, 0.065, 0.14), Vector3(0.045, 0.03, 0.28), c(BRASS_D))
		m.box(Vector3(0, 0.025, 0.27), Vector3(0.045, 0.05, 0.05), c(BLACK))
		m.pop()
	_cyl(m, Vector3(0, 0.06, 0), 0.34, 0.03, 0.026, c(BRASS), 8)
	m.box(Vector3(0, 0.42, 0), Vector3(0.34, 0.04, 0.34), c(BLACK))
	m.box(Vector3(0, 0.49, 0.0), Vector3(0.52, 0.11, 0.5), c(OXBLOOD))              # сиденье
	m.box(Vector3(0, 0.548, 0.0), Vector3(0.44, 0.006, 0.42), c(OXBLOOD_D))
	m.push()
	m.translate(Vector3(0, 0.54, -0.23))
	m.rot_x(-8)
	m.box(Vector3(0, 0.42, 0), Vector3(0.52, 0.84, 0.09), c(OXBLOOD))              # спинка
	m.box(Vector3(0, 0.86, 0.01), Vector3(0.46, 0.08, 0.11), c(OXBLOOD_D))          # валик подголовника
	for k in 9:                                                                    # пуговицы стёжки
		m.box(Vector3(-0.15 + (k % 3) * 0.15, 0.2 + (k / 3) * 0.2, 0.047), Vector3(0.022, 0.022, 0.006), c(OXBLOOD_D))
	for sx: float in [-0.262, 0.262]:
		m.box(Vector3(sx, 0.42, 0.02), Vector3(0.012, 0.8, 0.06), c(MAHOG_D))
	m.pop()
	for sx2: float in [-0.275, 0.275]:                                             # подлокотники
		m.box(Vector3(sx2, 0.6, -0.04), Vector3(0.04, 0.16, 0.04), c(MAHOG_D))
		m.box(Vector3(sx2, 0.6, 0.16), Vector3(0.04, 0.16, 0.04), c(MAHOG_D))
		m.box(Vector3(sx2, 0.7, 0.04), Vector3(0.06, 0.05, 0.34), c(OXBLOOD))

## Картина в золочёной раме: портрет основателя, пейзаж или вид мэрии
static func _portrait(m: Mesher, hv: int) -> void:
	var y := 1.62
	m.box(Vector3(0, y, 0), Vector3(0.76, 0.96, 0.07), c(BRASS_D))
	m.box(Vector3(0, y, 0.036), Vector3(0.68, 0.88, 0.008), c(BRASS))
	var z := 0.042
	match (hv / 29) % 3:
		0:                                                                         # портрет
			m.box(Vector3(0, y, z), Vector3(0.6, 0.8, 0.006), c(0x3A2A20))
			m.box(Vector3(0, y - 0.24, z + 0.004), Vector3(0.44, 0.32, 0.004), c(0x1E2430))        # плечи
			m.box(Vector3(0, y - 0.14, z + 0.007), Vector3(0.1, 0.14, 0.004), c(CREAM))            # сорочка
			m.box(Vector3(0, y - 0.17, z + 0.01), Vector3(0.035, 0.12, 0.004), c(RED))             # галстук
			m.ellipsoid(Vector3(0, y + 0.06, z + 0.006), Vector3(0.095, 0.125, 0.012), c(0xD9B08C), 4, 10)
			m.ellipsoid(Vector3(0, y + 0.13, z + 0.008), Vector3(0.1, 0.07, 0.012), c(0xB8B4AC), 3, 10, 0.0, 0.6)
		1:                                                                         # пейзаж
			m.box(Vector3(0, y + 0.14, z), Vector3(0.6, 0.52, 0.006), c(0xA8C8E0))
			m.box(Vector3(0, y - 0.26, z), Vector3(0.6, 0.28, 0.006), c(0x5F8A4A))
			m.ellipsoid(Vector3(-0.14, y - 0.12, z + 0.002), Vector3(0.2, 0.14, 0.008), c(0x4F7A44), 3, 10, 0.0, 0.5)
			m.ellipsoid(Vector3(0.16, y - 0.12, z + 0.004), Vector3(0.16, 0.2, 0.008), c(0x6A8A6A), 3, 10, 0.0, 0.5)
			_disc(m, Vector3(0.16, y + 0.24, z + 0.002), 0.05, 0.004, c(0xF4E2A0), 10)
			m.push()
			m.translate(Vector3(-0.04, y - 0.27, z + 0.006))
			m.rot_z(-20)
			m.box(Vector3.ZERO, Vector3(0.5, 0.05, 0.004), c(0x7FA8D0))
			m.pop()
		2:                                                                         # вид мэрии
			m.box(Vector3(0, y + 0.12, z), Vector3(0.6, 0.56, 0.006), c(0xB8D0E4))
			m.box(Vector3(0, y - 0.28, z), Vector3(0.6, 0.24, 0.006), c(0x6A9A5A))
			m.box(Vector3(0, y - 0.08, z + 0.004), Vector3(0.4, 0.22, 0.004), c(CREAM))
			for k in 5:
				m.box(Vector3(-0.16 + k * 0.08, y - 0.09, z + 0.007), Vector3(0.022, 0.18, 0.003), c(MARBLE_D))
			m.box(Vector3(0, y + 0.04, z + 0.006), Vector3(0.44, 0.03, 0.004), c(MARBLE_D))
			m.ellipsoid(Vector3(0, y + 0.06, z + 0.004), Vector3(0.08, 0.1, 0.008), c(0x7FA89A), 3, 10, 0.0, 0.5)
			m.box(Vector3(0, y - 0.2, z + 0.006), Vector3(0.12, 0.05, 0.004), c(MARBLE_D))
	m.box(Vector3(0, 1.08, 0.0), Vector3(0.22, 0.06, 0.02), c(BRASS_D))             # табличка
	m.box(Vector3(0, 1.08, 0.011), Vector3(0.18, 0.02, 0.003), c(MAHOG_D))
	_cyl_x(m, Vector3(-0.16, 2.16, 0.07), 0.32, 0.022, c(BRASS), 8)                 # подсветка картины
	m.box(Vector3(0, 2.13, 0.03), Vector3(0.02, 0.06, 0.08), c(BRASS_D))

## Напольный глобус в деревянной подставке
static func _globe(m: Mesher) -> void:
	var gc := Vector3(0, 0.96, 0)
	var r := 0.27
	for k in 4:
		m.push()
		m.rot_y(k * 90.0 + 45.0)
		m.translate(Vector3(0, 0, 0.3))
		m.rot_x(-7)
		m.box(Vector3(0, 0.48, 0), Vector3(0.045, 0.96, 0.045), c(MAHOG))
		m.pop()
	_ring_h(m, Vector3(0, 0.96, 0), 0.315, 0.05, 0.03, c(MAHOG_D), 16)              # кольцо горизонта
	_ring_h(m, Vector3(0, 0.3, 0), 0.2, 0.03, 0.03, c(MAHOG_D), 12)
	for k in 2:
		m.push()
		m.rot_y(k * 90.0 + 45.0)
		m.box(Vector3(0, 0.3, 0), Vector3(0.03, 0.03, 0.5), c(MAHOG_D))
		m.pop()
	_cyl(m, Vector3(0, 0.3, 0), 0.34, 0.02, 0.02, c(BRASS), 6)
	m.ellipsoid(gc, Vector3(r, r, r), c(0x3F6FA8), 8, 14)
	m.push()
	m.translate(gc)
	m.rot_z(20)
	_ring(m, Vector3.ZERO, r + 0.02, 0.014, c(BRASS), 16, -90.0, 90.0, 0.014)       # дуга меридиана
	_cyl(m, Vector3(0, r, 0), 0.05, 0.012, 0.012, c(BRASS), 6)
	var lands := [[-30.0, 40.0, 0.11, 0.1], [-20.0, -10.0, 0.07, 0.12], [60.0, 35.0, 0.13, 0.09], [75.0, -5.0, 0.08, 0.1],
		[140.0, 30.0, 0.14, 0.1], [165.0, -25.0, 0.07, 0.06], [-100.0, 45.0, 0.12, 0.08], [-110.0, 5.0, 0.07, 0.11], [0.0, 80.0, 0.1, 0.05]]
	for ld: Array in lands:
		m.push()
		m.rot_y(ld[0])
		m.rot_x(-float(ld[1]))
		m.translate(Vector3(0, 0, r - 0.004))
		m.ellipsoid(Vector3.ZERO, Vector3(ld[2], ld[3], 0.012), c(0x6E9A52 if int(ld[0]) % 40 != 0 else 0xB8A878), 3, 8)
		m.pop()
	m.pop()

## Напольные часы с маятником
static func _grandclock(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.03, 0), Vector3(0.54, 0.06, 0.34), c(MAHOG_D))
	m.box(Vector3(0, 0.3, 0), Vector3(0.5, 0.48, 0.3), c(MAHOG))
	m.box(Vector3(0, 0.3, 0.152), Vector3(0.36, 0.34, 0.006), c(MAHOG_L))
	m.box(Vector3(0, 0.56, 0), Vector3(0.54, 0.04, 0.34), c(MAHOG_D))
	m.box(Vector3(0, 1.0, 0), Vector3(0.38, 0.84, 0.24), c(MAHOG))                  # корпус
	m.box(Vector3(0, 1.0, 0.121), Vector3(0.26, 0.72, 0.006), c(0x1E1610))          # окно маятника
	var sw := -0.05 + float(hv % 5) * 0.025
	_line(m, Vector2(0, 1.34), Vector2(sw, 0.78), 0.127, c(BRASS), 0.012)
	_disc(m, Vector3(sw, 0.76, 0.125), 0.07, 0.008, c(BRASS), 12)
	for sx in [-0.08, 0.08]:                                                       # гири
		m.box(Vector3(sx, 1.22, 0.126), Vector3(0.004, 0.24, 0.003), c(BRASS_D))
		m.box(Vector3(sx, 1.04, 0.128), Vector3(0.04, 0.14, 0.008), c(BRASS))
	m.box(Vector3(0, 1.44, 0), Vector3(0.54, 0.04, 0.34), c(MAHOG_D))
	m.box(Vector3(0, 1.7, 0), Vector3(0.5, 0.5, 0.3), c(MAHOG))                     # голова с циферблатом
	_disc(m, Vector3(0, 1.7, 0.15), 0.2, 0.006, c(BRASS), 16)
	_disc(m, Vector3(0, 1.7, 0.156), 0.175, 0.004, c(CREAM), 16)
	for k in 12:
		var a := TAU * k / 12.0
		m.box(Vector3(sin(a) * 0.145, 1.7 + cos(a) * 0.145, 0.162), Vector3(0.016, 0.016, 0.003), c(BLACK))
	var hh := float(hv % 12) + 0.5
	var ha := TAU * hh / 12.0
	var ma := TAU * float((hv / 12) % 12) / 12.0
	_line(m, Vector2(0, 1.7), Vector2(sin(ha) * 0.085, 1.7 + cos(ha) * 0.085), 0.165, c(BLACK), 0.014)
	_line(m, Vector2(0, 1.7), Vector2(sin(ma) * 0.13, 1.7 + cos(ma) * 0.13), 0.168, c(BLACK), 0.009)
	_disc(m, Vector3(0, 1.7, 0.166), 0.014, 0.005, c(BRASS), 8)
	m.box(Vector3(0, 1.97, 0), Vector3(0.56, 0.05, 0.34), c(MAHOG_D))               # карниз и фронтон
	for sg: float in [-1.0, 1.0]:
		m.push()
		m.translate(Vector3(sg * 0.13, 2.06, 0.1))
		m.rot_z(24.0 * sg)
		m.box(Vector3.ZERO, Vector3(0.3, 0.05, 0.08), c(MAHOG))
		m.pop()
	m.ellipsoid(Vector3(0, 2.16, 0.1), Vector3(0.035, 0.045, 0.035), c(BRASS), 4, 8)
	m.box(Vector3(0, 2.07, 0.1), Vector3(0.04, 0.12, 0.04), c(MAHOG_D))

## Камин с мраморным порталом
static func _fireplace(m: Mesher) -> void:
	m.box(Vector3(0, 0.02, 0.05), Vector3(1.0, 0.04, 0.5), c(GRANITE))              # плита перед топкой
	m.box(Vector3(0, 0.6, -0.19), Vector3(0.96, 1.2, 0.06), c(0x2A2420))            # задняя стенка
	for sx in [-0.4, 0.4]:
		m.box(Vector3(sx, 0.52, 0.0), Vector3(0.18, 1.04, 0.36), c(MARBLE))
		m.box(Vector3(sx, 0.06, 0.02), Vector3(0.22, 0.12, 0.4), c(MARBLE_D))
		m.box(Vector3(sx, 0.98, 0.02), Vector3(0.22, 0.08, 0.4), c(MARBLE_D))
		m.box(Vector3(sx, 0.52, 0.182), Vector3(0.1, 0.72, 0.006), c(MARBLE_D))
	m.box(Vector3(0, 0.93, 0.0), Vector3(0.62, 0.22, 0.36), c(MARBLE))              # перемычка
	m.box(Vector3(0, 0.93, 0.182), Vector3(0.5, 0.12, 0.006), c(MARBLE_D))
	_seal(m, Vector3(0, 0.93, 0.186), 0.08)
	m.box(Vector3(0, 1.12, 0.03), Vector3(1.0, 0.06, 0.46), c(MARBLE))              # полка
	m.box(Vector3(0, 1.075, 0.02), Vector3(0.96, 0.03, 0.42), c(MARBLE_D))
	m.box(Vector3(0, 0.44, -0.15), Vector3(0.62, 0.8, 0.02), c(0x1A1512))           # топка
	for sx2 in [-0.3, 0.3]:
		m.box(Vector3(sx2, 0.44, -0.02), Vector3(0.02, 0.8, 0.28), c(0x1A1512))
	for k in 3:                                                                    # поленья и огонь
		_cyl_x(m, Vector3(-0.22 + (k % 2) * 0.02, 0.1 + (k / 2) * 0.09, -0.08 + (k % 2) * 0.1 - (k / 2) * 0.05), 0.42, 0.05, c(0x4A3220), 6)
	m.box(Vector3(0, 0.06, -0.03), Vector3(0.4, 0.03, 0.2), c(0xE8642A, 0.5))
	for k in 5:
		m.push()
		m.translate(Vector3(-0.14 + k * 0.07, 0.2 + (k % 2) * 0.03, -0.04 + (k % 3) * 0.02))
		m.rot_z(-8.0 + k * 4.0)
		m.tube(0.0, 0.16 + (k % 3) * 0.05, 0.035, 0.004, c(0xFFB040 if k % 2 == 0 else 0xFF7A2A, 0.5), 5)
		m.pop()
	for sx3 in [-0.24, 0.24]:                                                      # подставки для дров
		m.box(Vector3(sx3, 0.14, 0.1), Vector3(0.025, 0.24, 0.025), c(BRASS))
		m.ellipsoid(Vector3(sx3, 0.29, 0.1), Vector3(0.03, 0.035, 0.03), c(BRASS), 4, 6)
	m.box(Vector3(0, 0.09, 0.26), Vector3(0.7, 0.1, 0.015), c(BRASS_D))             # решётка-экран
	m.box(Vector3(0, 0.145, 0.26), Vector3(0.72, 0.014, 0.02), c(BRASS))
	# на полке: часы, подсвечники, фотография
	m.box(Vector3(0, 1.24, 0.0), Vector3(0.2, 0.18, 0.1), c(MAHOG))
	m.box(Vector3(0, 1.34, 0.0), Vector3(0.14, 0.03, 0.08), c(MAHOG_D))
	_disc(m, Vector3(0, 1.24, 0.05), 0.065, 0.006, c(CREAM), 12)
	_line(m, Vector2(0, 1.24), Vector2(0.03, 1.27), 0.058, c(BLACK), 0.008)
	_line(m, Vector2(0, 1.24), Vector2(-0.01, 1.29), 0.058, c(BLACK), 0.006)
	for sx4 in [-0.36, 0.36]:
		_cyl(m, Vector3(sx4, 1.15, 0.0), 0.02, 0.045, 0.04, c(BRASS), 8)
		_cyl(m, Vector3(sx4, 1.17, 0.0), 0.16, 0.012, 0.012, c(BRASS), 6)
		_cyl(m, Vector3(sx4, 1.33, 0.0), 0.012, 0.03, 0.03, c(BRASS), 8)
		_cyl(m, Vector3(sx4, 1.342, 0.0), 0.12, 0.012, 0.012, c(CREAM), 6)
	m.push()
	m.translate(Vector3(0.2, 1.15, 0.04))
	m.rot_x(-10)
	m.box(Vector3(0, 0.07, 0), Vector3(0.11, 0.14, 0.012), c(BRASS))
	m.box(Vector3(0, 0.07, 0.008), Vector3(0.085, 0.11, 0.003), c(0x6E7C8A))
	m.pop()

## Кубок: p — точка на полке
static func _cup(m: Mesher, p: Vector3, s: float, col: int) -> void:
	m.box(p + Vector3(0, 0.02 * s, 0), Vector3(0.09 * s, 0.04 * s, 0.09 * s), c(MAHOG_D))
	_cyl(m, p + Vector3(0, 0.04 * s, 0), 0.07 * s, 0.035 * s, 0.012 * s, c(col), 8)
	_cyl(m, p + Vector3(0, 0.11 * s, 0), 0.14 * s, 0.02 * s, 0.06 * s, c(col), 10)
	for sx: float in [-1.0, 1.0]:
		m.box(p + Vector3(sx * 0.07 * s, 0.19 * s, 0), Vector3(0.012 * s, 0.07 * s, 0.012 * s), c(col))

## Витрина с наградами города
static func _trophycase(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.26, 0), Vector3(0.94, 0.52, 0.4), c(MAHOG))
	m.box(Vector3(0, 0.03, 0), Vector3(0.96, 0.06, 0.42), c(MAHOG_D))
	for k in 2:
		m.box(Vector3(-0.22 + k * 0.44, 0.28, 0.202), Vector3(0.38, 0.36, 0.006), c(MAHOG_L))
		m.box(Vector3(-0.06 + k * 0.12, 0.28, 0.207), Vector3(0.02, 0.05, 0.008), c(BRASS))
	m.box(Vector3(0, 0.535, 0), Vector3(0.96, 0.03, 0.42), c(MAHOG_D))
	for sx in [-0.45, 0.45]:
		for sz in [-0.18, 0.18]:
			m.box(Vector3(sx, 1.25, sz), Vector3(0.04, 1.4, 0.04), c(MAHOG))
	m.box(Vector3(0, 1.25, -0.19), Vector3(0.9, 1.4, 0.02), c(0x1F4A36))            # зелёное сукно
	m.box(Vector3(0, 1.98, 0), Vector3(0.96, 0.08, 0.42), c(MAHOG))
	m.box(Vector3(0, 2.04, 0), Vector3(1.0, 0.04, 0.44), c(MAHOG_D))
	m.box(Vector3(0, 1.93, 0.1), Vector3(0.8, 0.012, 0.06), c(0xFFF0B0, 0.5))       # подсветка
	for s in 2:
		m.box(Vector3(0, 1.0 + s * 0.46, 0), Vector3(0.88, 0.012, 0.36), c(GLASS))
	# нижняя полка: ключ от города на бархате и памятная доска
	m.box(Vector3(-0.18, 0.575, 0.0), Vector3(0.4, 0.05, 0.2), c(VELVET))
	_cyl_x(m, Vector3(-0.3, 0.615, 0.0), 0.24, 0.012, c(BRASS), 6)
	_ring_h(m, Vector3(-0.33, 0.615, 0.0), 0.04, 0.014, 0.012, c(BRASS), 8)
	for k in 2:
		m.box(Vector3(-0.1 + k * 0.03, 0.615, 0.02), Vector3(0.014, 0.012, 0.04), c(BRASS))
	m.push()
	m.translate(Vector3(0.24, 0.55, -0.08))
	m.rot_x(-14)
	m.box(Vector3(0, 0.14, 0), Vector3(0.24, 0.28, 0.02), c(MAHOG_D))
	m.box(Vector3(0, 0.14, 0.012), Vector3(0.18, 0.2, 0.004), c(BRASS))
	for k in 3:
		m.box(Vector3(0, 0.19 - k * 0.045, 0.016), Vector3(0.13 - k * 0.02, 0.014, 0.003), c(MAHOG_D))
	m.pop()
	# средняя полка: кубки
	var cols := [BRASS, CHROME, BRASS, 0xB87A4A]
	for k in 4:
		_cup(m, Vector3(-0.3 + k * 0.2, 1.006, -0.02 + (k % 2) * 0.05), 0.9 + ((hv >> k) % 3) * 0.25, cols[(hv + k) % 4])
	# верхняя полка: молоток председателя, медаль на ленте, большой кубок
	_cup(m, Vector3(0.0, 1.466, -0.03), 1.5, BRASS)
	m.box(Vector3(-0.3, 1.48, 0.0), Vector3(0.2, 0.03, 0.1), c(MAHOG_D))
	_cyl_x(m, Vector3(-0.35, 1.53, 0.0), 0.1, 0.03, c(MAHOG_L), 8)
	m.box(Vector3(-0.3, 1.53, 0.07), Vector3(0.016, 0.016, 0.16), c(MAHOG_L))
	m.push()
	m.translate(Vector3(0.3, 1.466, -0.1))
	m.rot_x(-10)
	m.box(Vector3(0, 0.12, 0), Vector3(0.16, 0.24, 0.015), c(NAVY))
	m.box(Vector3(0, 0.17, 0.01), Vector3(0.05, 0.1, 0.004), c(RED))
	_disc(m, Vector3(0, 0.09, 0.008), 0.04, 0.008, c(BRASS), 10)
	m.pop()

## Флаг города на стойке
static func _cityflag(m: Mesher, hv: int) -> void:
	_cyl(m, Vector3.ZERO, 0.05, 0.17, 0.15, c(BRASS), 12)
	_cyl(m, Vector3(0, 0.05, 0), 0.06, 0.06, 0.035, c(BRASS), 10)
	_cyl(m, Vector3(0, 0.1, 0), 2.05, 0.016, 0.016, c(0x6A4A2C), 8)
	m.ellipsoid(Vector3(0, 2.19, 0), Vector3(0.04, 0.05, 0.04), c(BRASS), 4, 8)
	_cyl(m, Vector3(0, 2.23, 0), 0.09, 0.02, 0.002, c(BRASS), 6)
	var field: int = NAVY if hv % 2 == 0 else 0x1F4A36
	for i in 7:                                                                    # полотнище висит складками
		m.push()
		m.translate(Vector3(0.025 + i * 0.03, 2.1, 0.02 + (i % 2) * 0.014))
		m.rot_z(2.0 + i * 1.6)
		var h := 1.0 - i * 0.035
		m.box(Vector3(0, -h * 0.5, 0), Vector3(0.045, h, 0.03), c(field if i != 3 else CREAM))
		m.box(Vector3(0, -h - 0.015, 0), Vector3(0.045, 0.03, 0.03), c(BRASS))      # бахрома
		m.pop()
	m.push()
	m.translate(Vector3(0.1, 1.62, 0.05))
	m.rot_z(5.0)
	_seal(m, Vector3.ZERO, 0.1)
	m.pop()
	m.box(Vector3(-0.03, 1.9, 0.03), Vector3(0.012, 0.36, 0.012), c(BRASS))         # шнур с кистью
	m.box(Vector3(-0.03, 1.69, 0.03), Vector3(0.03, 0.08, 0.03), c(BRASS))

# ================== зал совета ==================
## Стол совета: высокая панель к залу, у каждого места — табличка, микрофон, бумаги
static func _dais(m: Mesher, hv: int) -> void:
	var sealed := hv % 3 == 0
	_counter(m, 1.2, MAHOG_D, MAHOG, MAHOG_L, 1 if sealed else 2)
	m.box(Vector3(0, 0.07, -0.455), Vector3(1.0, 0.14, 0.09), c(MAHOG))             # ступень-цоколь
	m.box(Vector3(0, 1.165, -0.414), Vector3(1.0, 0.03, 0.012), c(BRASS_D))
	if sealed:
		_seal(m, Vector3(0, 0.64, -0.424), 0.2, -1.0)
	m.box(Vector3(0, 1.275, -0.4), Vector3(0.3, 0.07, 0.05), c(MAHOG))              # табличка с именем — к залу
	m.box(Vector3(0, 1.275, -0.427), Vector3(0.26, 0.045, 0.006), c(BRASS))
	m.box(Vector3(0, 1.275, -0.431), Vector3(0.18, 0.012, 0.003), c(MAHOG_D))
	var top := 0.78
	_mic(m, Vector3(0.0, top, -0.06), 1.0)
	m.box(Vector3(-0.02, top + 0.006, 0.2), Vector3(0.24, 0.012, 0.32), c(MANILA))  # повестка
	m.box(Vector3(-0.01, top + 0.014, 0.2), Vector3(0.21, 0.004, 0.29), c(PAPER))
	for ln in 5:
		m.box(Vector3(-0.01, top + 0.017, 0.09 + ln * 0.05), Vector3(0.16, 0.002, 0.008), c(0x5A5F70))
	m.box(Vector3(0.16, top + 0.012, 0.24), Vector3(0.012, 0.012, 0.14), c(BLACK))
	match hv % 3:
		0:                                                                         # молоток председателя на подставке
			_cyl(m, Vector3(0.32, top, 0.1), 0.03, 0.07, 0.07, c(MAHOG_L), 10)
			_cyl_x(m, Vector3(0.26, top + 0.065, 0.1), 0.12, 0.035, c(MAHOG_L), 8)
			m.box(Vector3(0.32, top + 0.065, 0.2), Vector3(0.018, 0.018, 0.2), c(MAHOG_L))
		1:                                                                         # графин и стакан
			_cyl(m, Vector3(-0.34, top, 0.06), 0.16, 0.05, 0.045, c(0xBFD8E4), 8)
			_cyl(m, Vector3(-0.34, top + 0.16, 0.06), 0.06, 0.02, 0.025, c(0xBFD8E4), 6)
			_cyl(m, Vector3(-0.26, top, 0.18), 0.09, 0.028, 0.032, c(0xD6E6EC), 8)
		2:                                                                         # стопка папок
			m.box(Vector3(0.32, top + 0.03, 0.14), Vector3(0.22, 0.06, 0.3), c(MANILA))
			m.box(Vector3(0.31, top + 0.068, 0.15), Vector3(0.22, 0.014, 0.3), c(NAVY_L))
			_cyl(m, Vector3(-0.34, top, 0.14), 0.09, 0.028, 0.032, c(0xD6E6EC), 8)

## Скамья для публики. Боковины — только на концах ряда
static func _pew(m: Mesher, link: int) -> void:
	m.box(Vector3(0, 0.435, -0.01), Vector3(1.0, 0.05, 0.42), c(OAK_D))             # сиденье
	m.box(Vector3(0, 0.39, 0.17), Vector3(1.0, 0.05, 0.03), c(MAHOG_D))
	m.box(Vector3(0, 0.2, -0.05), Vector3(0.05, 0.4, 0.34), c(MAHOG_D))             # опора
	m.push()
	m.translate(Vector3(0, 0.44, -0.24))
	m.rot_x(-8)
	m.box(Vector3(0, 0.26, 0), Vector3(1.0, 0.56, 0.04), c(OAK_D))                  # спинка
	m.box(Vector3(0, 0.55, 0), Vector3(1.0, 0.05, 0.07), c(MAHOG_D))
	for k in 2:
		m.box(Vector3(-0.25 + k * 0.5, 0.26, 0.022), Vector3(0.4, 0.4, 0.004), c(OAK))
	m.pop()
	for sg: float in [-1.0, 1.0]:
		if (link & (1 if sg < 0.0 else 2)) != 0:
			continue
		m.box(Vector3(sg * 0.475, 0.34, -0.04), Vector3(0.05, 0.68, 0.52), c(MAHOG_D))         # боковина
		m.box(Vector3(sg * 0.475, 0.7, -0.04), Vector3(0.07, 0.05, 0.54), c(MAHOG))
		m.box(Vector3(sg * 0.475, 0.86, -0.25), Vector3(0.05, 0.3, 0.1), c(MAHOG_D))
		m.ellipsoid(Vector3(sg * 0.475, 1.04, -0.27), Vector3(0.04, 0.045, 0.04), c(MAHOG), 4, 6)

## Кафедра выступающего: герб — к залу или к столу совета (+z), выступающий стоит с другой стороны
static func _lectern(m: Mesher) -> void:
	m.box(Vector3(0, 0.025, 0), Vector3(0.56, 0.05, 0.48), c(MAHOG_D))
	m.box(Vector3(0, 0.56, 0.02), Vector3(0.34, 1.04, 0.26), c(MAHOG))
	m.box(Vector3(0, 0.56, 0.152), Vector3(0.26, 0.9, 0.006), c(MAHOG_L))
	_seal(m, Vector3(0, 0.74, 0.156), 0.1)
	m.push()
	m.translate(Vector3(0, 1.12, 0.0))
	m.rot_x(-16)
	m.box(Vector3.ZERO, Vector3(0.6, 0.04, 0.46), c(MAHOG))
	m.box(Vector3(0, -0.03, 0.0), Vector3(0.52, 0.04, 0.38), c(MAHOG_D))
	m.box(Vector3(0, 0.035, -0.22), Vector3(0.6, 0.035, 0.025), c(MAHOG_D))         # бортик со стороны выступающего
	m.box(Vector3(-0.04, 0.024, -0.02), Vector3(0.24, 0.006, 0.32), c(PAPER))
	for ln in 5:
		m.box(Vector3(-0.04, 0.028, -0.13 + ln * 0.05), Vector3(0.18, 0.002, 0.008), c(0x5A5F70))
	m.pop()
	_mic(m, Vector3(0.16, 1.2, 0.16), -1.0)
	_cyl(m, Vector3(-0.22, 1.09, -0.14), 0.09, 0.028, 0.032, c(0xD6E6EC), 8)        # стакан воды

## Урна для голосования на столике
static func _ballotbox(m: Mesher) -> void:
	m.box(Vector3(0, 0.36, 0), Vector3(0.72, 0.72, 0.52), c(0x2B3F60))               # столик под скатертью
	m.box(Vector3(0, 0.735, 0), Vector3(0.76, 0.03, 0.56), c(NAVY_L))
	for k in 7:                                                                    # кайма в полоску
		m.box(Vector3(-0.3 + k * 0.1, 0.62, 0.262), Vector3(0.1, 0.12, 0.004), c(RED if k % 2 == 0 else CREAM))
	for k in 5:
		m.box(Vector3(-0.26 + k * 0.13, 0.4, 0.262), Vector3(0.05, 0.05, 0.004), c(CREAM))
	var top := 0.75
	m.box(Vector3(-0.08, top + 0.17, -0.02), Vector3(0.44, 0.34, 0.36), c(0x9AA0A6))    # урна
	m.box(Vector3(-0.08, top + 0.35, -0.02), Vector3(0.47, 0.03, 0.39), c(STEEL_D))
	m.box(Vector3(-0.08, top + 0.367, -0.02), Vector3(0.22, 0.004, 0.025), c(BLACK))    # прорезь
	m.push()                                                                           # бюллетень в прорези
	m.translate(Vector3(-0.08, top + 0.37, -0.02))
	m.rot_x(-12)
	m.box(Vector3(0, 0.05, 0), Vector3(0.16, 0.12, 0.004), c(PAPER))
	m.pop()
	m.box(Vector3(-0.08, top + 0.27, 0.162), Vector3(0.05, 0.06, 0.02), c(BRASS))       # замок
	_ring(m, Vector3(-0.08, top + 0.31, 0.165), 0.022, 0.008, c(STEEL_D), 6, 0.0, 180.0, 0.008)
	m.box(Vector3(-0.08, top + 0.14, 0.162), Vector3(0.3, 0.1, 0.004), c(CREAM))        # наклейка
	m.box(Vector3(-0.08, top + 0.14, 0.165), Vector3(0.3, 0.03, 0.003), c(RED))
	m.push()                                                                           # табличка-домик
	m.translate(Vector3(0.26, top, 0.14))
	m.rot_x(-15)
	m.box(Vector3(0, 0.08, 0), Vector3(0.16, 0.16, 0.006), c(CREAM))
	m.box(Vector3(0, 0.13, 0.004), Vector3(0.16, 0.04, 0.003), c(NAVY))
	m.box(Vector3(0, 0.035, 0.004), Vector3(0.16, 0.04, 0.003), c(RED))
	m.pop()
	_cyl(m, Vector3(0.28, top, -0.12), 0.1, 0.035, 0.035, c(BLACK), 8)                  # стакан с ручками
	for k in 3:
		m.box(Vector3(0.27 + k * 0.012, top + 0.13, -0.12), Vector3(0.008, 0.1, 0.008), c([NAVY_L, RED, BLACK][k]))

## Кабинка для голосования: столик на ножках с ширмой в полоску
static func _votebooth(m: Mesher) -> void:
	for sx: float in [-0.4, 0.4]:
		for sz: float in [-0.22, 0.24]:
			m.push()
			m.translate(Vector3(sx, 1.0, sz))
			m.rot_z(-4.0 if sx < 0.0 else 4.0)
			m.box(Vector3(0, -0.5, 0), Vector3(0.025, 1.0, 0.025), c(CHROME))
			m.pop()
	m.box(Vector3(0, 0.45, -0.22), Vector3(0.84, 0.02, 0.02), c(CHROME))
	m.box(Vector3(0, 1.0, 0.01), Vector3(0.84, 0.04, 0.5), c(0xCFCBBE))             # столик
	for side in 3:                                                                 # ширма: бока и задняя стенка
		m.push()
		if side == 0:
			m.translate(Vector3(0, 0, -0.24))
		else:
			m.translate(Vector3(-0.42 if side == 1 else 0.42, 0, 0.01))
			m.rot_y(90)
		var pw := 0.84 if side == 0 else 0.5
		m.box(Vector3(0, 1.3, 0), Vector3(pw, 0.56, 0.012), c(CREAM))
		m.box(Vector3(0, 1.67, 0), Vector3(pw, 0.18, 0.014), c(NAVY))
		m.box(Vector3(0, 1.54, 0), Vector3(pw, 0.06, 0.014), c(RED))
		var ns := 5 if side == 0 else 3
		for k in ns:
			for sg: float in [-1.0, 1.0]:
				m.box(Vector3(-pw * 0.5 + pw * (k + 0.5) / ns, 1.67, sg * 0.009), Vector3(0.05, 0.05, 0.003), c(CREAM))
		m.pop()
	m.box(Vector3(-0.06, 1.024, 0.04), Vector3(0.24, 0.006, 0.32), c(PAPER))        # бюллетень
	for ln in 5:
		m.box(Vector3(-0.1, 1.028, -0.07 + ln * 0.055), Vector3(0.025, 0.002, 0.025), c(0x4A4F58))
		m.box(Vector3(-0.02, 1.028, -0.07 + ln * 0.055), Vector3(0.1, 0.002, 0.008), c(0x7A7F88))
	m.box(Vector3(0.2, 1.03, 0.1), Vector3(0.012, 0.012, 0.13), c(BLACK))           # ручка на шнурке
	m.box(Vector3(0.3, 1.024, -0.05), Vector3(0.004, 0.004, 0.32), c(STEEL_D))

# ================== пресс-зал ==================
## Пресс-стена с гербами города
static func _presswall(m: Mesher) -> void:
	for sx in [-0.42, 0.42]:
		m.box(Vector3(sx, 0.015, -0.02), Vector3(0.05, 0.03, 0.34), c(DARK))
		m.box(Vector3(sx, 1.03, -0.13), Vector3(0.03, 2.0, 0.03), c(CHROME))
	m.box(Vector3(0, 1.08, -0.1), Vector3(1.0, 1.96, 0.02), c(0x24385C))
	m.box(Vector3(0, 2.0, -0.088), Vector3(1.0, 0.1, 0.004), c(BRASS_D))
	m.box(Vector3(0, 0.16, -0.088), Vector3(1.0, 0.1, 0.004), c(BRASS_D))
	for k in 12:
		var px := -0.33 + (k % 3) * 0.33
		var py := 0.42 + (k / 3) * 0.42
		if (k % 3 + k / 3) % 2 == 0:
			_seal(m, Vector3(px, py, -0.09), 0.1)
		else:
			m.box(Vector3(px, py + 0.03, -0.088), Vector3(0.22, 0.05, 0.004), c(CREAM))
			m.box(Vector3(px, py - 0.04, -0.088), Vector3(0.16, 0.025, 0.004), c(BRASS))

## Телекамера на штативе: объектив — на +z
static func _tvcamera(m: Mesher, hv: int) -> void:
	for k in 3:                                                                    # штатив на тележке
		m.push()
		m.rot_y(k * 120.0)
		m.box(Vector3(0, 0.07, -0.17), Vector3(0.03, 0.03, 0.34), c(DARK))
		m.box(Vector3(0, 0.03, -0.33), Vector3(0.05, 0.06, 0.06), c(BLACK))
		m.translate(Vector3(0, 1.02, 0))
		m.rot_x(18.5)
		m.box(Vector3(0, -0.5, 0), Vector3(0.03, 1.0, 0.03), c(STEEL_D))
		m.box(Vector3(0, -0.7, 0), Vector3(0.04, 0.5, 0.04), c(DARK))
		m.pop()
	_cyl(m, Vector3(0, 0.98, 0), 0.12, 0.06, 0.07, c(DARK), 8)
	m.box(Vector3(0, 1.13, 0), Vector3(0.14, 0.06, 0.2), c(BLACK))                  # головка
	var body: int = [0x4A5058, 0x3A4F6A, 0x5A5046][hv % 3]
	m.box(Vector3(0, 1.3, -0.02), Vector3(0.24, 0.28, 0.52), c(body))
	m.box(Vector3(0.122, 1.32, -0.04), Vector3(0.004, 0.14, 0.3), c(CREAM))          # полоса телеканала
	m.box(Vector3(-0.122, 1.32, -0.04), Vector3(0.004, 0.14, 0.3), c(CREAM))
	for sg: float in [-1.0, 1.0]:
		m.box(Vector3(sg * 0.125, 1.32, -0.04), Vector3(0.004, 0.05, 0.2), c(RED))
	_cyl_z(m, Vector3(0, 1.3, 0.24), 0.14, 0.085, c(BLACK), 10)                     # объектив
	_cyl_z(m, Vector3(0, 1.3, 0.38), 0.05, 0.1, c(DARK), 10)
	_disc(m, Vector3(0, 1.3, 0.425), 0.075, 0.006, c(0x3A5A8A), 10)
	m.box(Vector3(0, 1.4, 0.44), Vector3(0.24, 0.02, 0.1), c(BLACK))                # бленда
	m.box(Vector3(0, 1.5, -0.14), Vector3(0.16, 0.12, 0.2), c(DARK))                # видоискатель
	m.box(Vector3(0, 1.5, -0.242), Vector3(0.12, 0.085, 0.006), c(0xA4B6B2, 0.5))
	m.box(Vector3(0, 1.46, 0.2), Vector3(0.04, 0.04, 0.04), c(0xE0483A, 0.5))       # лампа «в эфире»
	m.box(Vector3(0.0, 1.47, 0.02), Vector3(0.03, 0.06, 0.24), c(BLACK))            # ручка сверху
	m.push()                                                                       # рукоять поворота
	m.translate(Vector3(0.1, 1.13, -0.08))
	m.rot_x(35)
	m.rot_y(-12)
	m.box(Vector3(0, 0, -0.2), Vector3(0.02, 0.02, 0.4), c(STEEL_D))
	m.box(Vector3(0, 0, -0.38), Vector3(0.035, 0.035, 0.1), c(BLACK))
	m.pop()
	_ring_h(m, Vector3(0.16, 0.02, -0.14), 0.1, 0.03, 0.03, c(BLACK), 10)           # кабель на полу
	_ring_h(m, Vector3(0.16, 0.045, -0.14), 0.085, 0.03, 0.025, c(DARK), 10)

# ================== зал регистрации ==================
## Свадебная арка с цветами
static func _wedarch(m: Mesher, hv: int) -> void:
	var flowers := [0xF4C6CE, 0xFFFFFF, 0xE89AA8, 0xF8E6C0]
	for sz: float in [-0.06, 0.06]:
		for sx: float in [-0.42, 0.42]:
			m.box(Vector3(sx, 0.875, sz), Vector3(0.04, 1.75, 0.04), c(0xF4F2EC))
		_ring(m, Vector3(0, 1.75, sz), 0.42, 0.04, c(0xF4F2EC), 12, 0.0, 180.0, 0.04)
	for k in 7:                                                                    # перекладины между дугами
		var a := PI * (k + 0.5) / 7.0
		m.box(Vector3(cos(a) * 0.42, 1.75 + sin(a) * 0.42, 0), Vector3(0.025, 0.025, 0.12), c(0xF4F2EC))
	for sx2: float in [-0.42, 0.42]:
		m.box(Vector3(sx2, 0.03, 0), Vector3(0.12, 0.06, 0.2), c(0xE8E4DA))
		for k in 5:
			m.box(Vector3(sx2, 0.3 + k * 0.3, 0), Vector3(0.025, 0.025, 0.12), c(0xF4F2EC))
	# цветы и листья густо: по дуге и по стойкам
	for k in 46:
		var p := Vector3.ZERO
		if k < 22:
			var a2 := PI * (k + 0.5) / 22.0
			p = Vector3(cos(a2) * 0.435, 1.75 + sin(a2) * 0.435, 0.08 if k % 2 == 0 else 0.05)
		else:
			var q := k - 22
			var sd := -1.0 if q % 2 == 0 else 1.0
			p = Vector3(sd * (0.42 + ((q / 2) % 2) * 0.03 - 0.015), 1.7 - (q / 2) * 0.135, 0.08 if (q / 2) % 2 == 0 else 0.05)
		var r := 0.05 + ((hv >> (k % 20)) % 3) * 0.009
		if k % 3 == 2:
			m.ellipsoid(p + Vector3(0, 0.01, -0.02), Vector3(r * 1.4, r * 0.8, r * 0.7), c(0x4F8A4A), 3, 6)
		else:
			m.ellipsoid(p, Vector3(r, r, r * 0.8), c(flowers[(hv + k) % 4]), 3, 6)
			m.box(p + Vector3(0, 0, r * 0.75), Vector3(0.018, 0.018, 0.006), c(YELLOW))
	# букет с лентами наверху
	for k in 5:
		var a3 := TAU * k / 5.0
		m.ellipsoid(Vector3(cos(a3) * 0.07, 2.2 + sin(a3) * 0.06, 0.09), Vector3(0.06, 0.06, 0.05), c(flowers[(k + hv) % 4]), 3, 6)
	m.ellipsoid(Vector3(0, 2.2, 0.11), Vector3(0.05, 0.05, 0.04), c(0xC83A4A), 3, 6)
	for sg: float in [-1.0, 1.0]:
		m.push()
		m.translate(Vector3(sg * 0.03, 2.14, 0.09))
		m.rot_z(14.0 * sg)
		m.box(Vector3(0, -0.2, 0), Vector3(0.04, 0.4, 0.006), c(0xF4C6CE))
		m.pop()
	for sg2: float in [-1.0, 1.0]:                                                 # лёгкая ткань по бокам
		for k in 4:
			m.box(Vector3(sg2 * (0.36 - k * 0.04), 1.05 - k * 0.1, -0.085 - k * 0.004), Vector3(0.05, 1.5 - k * 0.22, 0.008), c(0xFAF6EE if k % 2 == 0 else 0xEFE8DC))

## Стол регистрации: скатерть до пола, книга записей, цветы, кольца на подушечке
static func _regtable(m: Mesher) -> void:
	m.box(Vector3(0, 0.37, 0), Vector3(0.96, 0.74, 0.7), c(CREAM))
	m.box(Vector3(0, 0.75, 0), Vector3(0.98, 0.02, 0.72), c(0xF6F2E6))
	m.box(Vector3(0, 0.4, 0), Vector3(0.36, 0.745, 0.71), c(VELVET))                # бордовая дорожка
	m.box(Vector3(0, 0.762, 0), Vector3(0.36, 0.006, 0.72), c(VELVET))
	for sg: float in [-1.0, 1.0]:
		m.box(Vector3(sg * 0.17, 0.4, 0), Vector3(0.012, 0.748, 0.714), c(BRASS))
	var top := 0.765
	_ledger(m, Vector3(0, top, 0.1), 0x6A1F22)
	m.box(Vector3(0.24, top + 0.012, 0.16), Vector3(0.1, 0.024, 0.06), c(GRANITE))  # подставка с ручкой
	m.push()
	m.translate(Vector3(0.24, top + 0.024, 0.16))
	m.rot_x(-30)
	m.box(Vector3(0, 0.08, 0), Vector3(0.012, 0.16, 0.012), c(BLACK))
	m.box(Vector3(0, 0.02, 0), Vector3(0.016, 0.03, 0.016), c(BRASS))
	m.pop()
	# ваза с розами
	_cyl(m, Vector3(-0.34, top, -0.16), 0.18, 0.04, 0.055, c(0xD6E6EC), 8)
	for k in 5:
		var a := TAU * k / 5.0
		m.box(Vector3(-0.34 + cos(a) * 0.03, top + 0.24, -0.16 + sin(a) * 0.03), Vector3(0.008, 0.16, 0.008), c(0x3F7A3A))
		m.ellipsoid(Vector3(-0.34 + cos(a) * 0.06, top + 0.34 + (k % 2) * 0.03, -0.16 + sin(a) * 0.06), Vector3(0.04, 0.04, 0.04), c(0xC83A4A if k % 2 == 0 else 0xF4C6CE), 3, 6)
	# подушечка с кольцами
	m.box(Vector3(0.34, top + 0.025, -0.14), Vector3(0.16, 0.05, 0.16), c(0xF4C6CE))
	m.box(Vector3(0.34, top + 0.052, -0.14), Vector3(0.12, 0.006, 0.12), c(0xFAF0F0))
	for k in 2:
		_ring_h(m, Vector3(0.315 + k * 0.05, top + 0.062, -0.14), 0.018, 0.006, 0.008, c(BRASS), 8)
	# свечи
	for sx in [-0.14, 0.14]:
		_cyl(m, Vector3(sx, top, -0.24), 0.03, 0.035, 0.03, c(BRASS), 8)
		_cyl(m, Vector3(sx, top + 0.03, -0.24), 0.16, 0.012, 0.012, c(0xFAF6EE), 6)
		m.push()
		m.translate(Vector3(sx, top + 0.19, -0.24))
		m.tube(0.0, 0.04, 0.012, 0.002, c(0xFFB040, 0.5), 5)
		m.pop()

# ================== казна ==================
## Дверь хранилища: круглая, с штурвалом; стоит в стене
static func _vault(m: Mesher) -> void:
	m.box(Vector3(0, 1.08, -0.2), Vector3(1.0, 2.16, 0.12), c(STEEL_D))
	for k in 4:
		m.box(Vector3(-0.45 + (k % 2) * 0.9, 0.12 + (k / 2) * 1.92, -0.136), Vector3(0.05, 0.05, 0.008), c(STEEL))
	var dc := Vector3(-0.02, 1.1, -0.14)
	_disc(m, dc, 0.46, 0.04, c(STEEL), 20)
	_disc(m, dc + Vector3(0, 0, 0.04), 0.4, 0.07, c(0xA4AAB0), 20)
	_disc(m, dc + Vector3(0, 0, 0.11), 0.3, 0.02, c(STEEL), 18)
	for k in 12:                                                                   # ригели по кругу
		var a := TAU * k / 12.0
		_disc(m, dc + Vector3(cos(a) * 0.35, sin(a) * 0.35, 0.11), 0.028, 0.02, c(CHROME), 8)
	# штурвал
	var wz := 0.17
	_disc(m, dc + Vector3(0, 0, 0.13), 0.06, 0.05, c(BRASS_D), 10)
	_ring(m, dc + Vector3(0, 0, wz), 0.2, 0.03, c(BRASS), 14, 0.0, 360.0, 0.03)
	for k in 5:
		var a2 := TAU * k / 5.0 + 0.3
		_line(m, Vector2(dc.x, dc.y), Vector2(dc.x + cos(a2) * 0.2, dc.y + sin(a2) * 0.2), dc.z + wz, c(BRASS), 0.025)
		m.ellipsoid(dc + Vector3(cos(a2) * 0.24, sin(a2) * 0.24, wz), Vector3(0.028, 0.028, 0.028), c(BRASS), 3, 6)
	# кодовый замок
	_disc(m, dc + Vector3(-0.2, 0.2, 0.13), 0.05, 0.02, c(BLACK), 10)
	_disc(m, dc + Vector3(-0.2, 0.2, 0.15), 0.03, 0.012, c(CHROME), 8)
	m.box(dc + Vector3(-0.2, 0.245, 0.152), Vector3(0.008, 0.02, 0.004), c(CREAM))
	# петли
	for sy: float in [-0.28, 0.28]:
		m.box(Vector3(0.44, 1.1 + sy, -0.08), Vector3(0.1, 0.18, 0.12), c(STEEL))
		_cyl(m, Vector3(0.46, 1.1 + sy - 0.1, -0.02), 0.2, 0.03, 0.03, c(CHROME), 8)
	m.box(Vector3(0, 2.1, -0.136), Vector3(0.36, 0.07, 0.008), c(BRASS))            # табличка
	m.box(Vector3(0, 0.02, -0.12), Vector3(1.0, 0.04, 0.2), c(STEEL))               # порог

## Стол казначея: пачки купюр, мешки, счётная машинка
static func _moneytable(m: Mesher, hv: int) -> void:
	for sx in [-0.43, 0.43]:
		for sz in [-0.29, 0.29]:
			m.box(Vector3(sx, 0.39, sz), Vector3(0.04, 0.78, 0.04), c(STEEL_D))
	m.box(Vector3(0, 0.8, 0), Vector3(0.94, 0.04, 0.68), c(STEEL))
	m.box(Vector3(0, 0.825, 0), Vector3(0.9, 0.01, 0.64), c(0x2F4A3E))              # сукно
	m.box(Vector3(0, 0.25, 0), Vector3(0.86, 0.02, 0.58), c(STEEL))
	var top := 0.83
	for k in 8:                                                                    # пачки купюр стопками
		var n := 1 + ((hv >> k) % 4)
		var px := -0.36 + (k % 4) * 0.13
		var pz := -0.2 + (k / 4) * 0.15
		for j in n:
			m.box(Vector3(px, top + 0.02 + j * 0.04, pz), Vector3(0.115, 0.038, 0.06), c(MONEY))
			m.box(Vector3(px, top + 0.02 + j * 0.04, pz), Vector3(0.025, 0.04, 0.062), c(PAPER))
	# счётная машинка
	m.box(Vector3(0.28, top + 0.07, -0.14), Vector3(0.26, 0.14, 0.26), c(BEIGE))
	m.box(Vector3(0.28, top + 0.16, -0.2), Vector3(0.26, 0.06, 0.12), c(BEIGE_D))
	m.box(Vector3(0.28, top + 0.165, -0.138), Vector3(0.14, 0.03, 0.006), c(0x16261E))
	_seg7(m, Vector3(0.26, top + 0.165, -0.134), hv % 10, 0.022, c(0xFF4A30, 0.5))
	_seg7(m, Vector3(0.285, top + 0.165, -0.134), (hv / 3) % 10, 0.022, c(0xFF4A30, 0.5))
	_seg7(m, Vector3(0.31, top + 0.165, -0.134), 0, 0.022, c(0xFF4A30, 0.5))
	m.box(Vector3(0.28, top + 0.15, -0.06), Vector3(0.16, 0.02, 0.08), c(MONEY))    # купюры в лотке
	# мешки с деньгами
	for k in 2:
		var bp := Vector3(0.2 + k * 0.17, top, 0.16 - k * 0.03)
		m.ellipsoid(bp + Vector3(0, 0.08, 0), Vector3(0.08, 0.09, 0.075), c(CANVAS), 4, 8)
		_cyl(m, bp + Vector3(0, 0.15, 0), 0.05, 0.025, 0.04, c(CANVAS), 6)
		m.box(bp + Vector3(0, 0.155, 0), Vector3(0.06, 0.012, 0.06), c(0x8A6C46))
		m.box(bp + Vector3(0, 0.08, 0.074), Vector3(0.05, 0.05, 0.004), c(GREEN))
	for k in 5:                                                                    # столбики монет
		_cyl(m, Vector3(-0.38 + k * 0.045, top, 0.2), 0.03 + ((hv >> (k + 2)) % 3) * 0.015, 0.018, 0.018, c(BRASS if k % 2 == 0 else CHROME), 8)
	m.box(Vector3(-0.14, top + 0.01, 0.22), Vector3(0.22, 0.02, 0.16), c(0x1F4A36))  # кассовая книга
	m.box(Vector3(-0.14, top + 0.022, 0.22), Vector3(0.19, 0.006, 0.13), c(PAPER))
	# внизу — инкассаторские сумки
	for k in 2:
		m.box(Vector3(-0.2 + k * 0.4, 0.34, 0), Vector3(0.32, 0.16, 0.26), c(0x4A5A6A if k == 0 else 0x5A4A3A))
		m.box(Vector3(-0.2 + k * 0.4, 0.43, 0), Vector3(0.12, 0.03, 0.03), c(BLACK))
		m.box(Vector3(-0.2 + k * 0.4, 0.36, 0.132), Vector3(0.05, 0.04, 0.006), c(BRASS))

# ================== службы ==================
## Стол сортировки почты с ячейками
static func _mailsort(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.43, 0.0), Vector3(0.94, 0.86, 0.62), c(OAK_D))
	m.box(Vector3(0, 0.03, 0.0), Vector3(0.96, 0.06, 0.64), c(MAHOG_D))
	for k in 2:
		m.box(Vector3(-0.23 + k * 0.46, 0.44, 0.312), Vector3(0.42, 0.68, 0.006), c(OAK))
		m.box(Vector3(-0.05 + k * 0.1, 0.5, 0.318), Vector3(0.02, 0.08, 0.01), c(BRASS))
	m.box(Vector3(0, 0.88, 0.0), Vector3(0.98, 0.04, 0.66), c(OAK))
	# ячейки
	var y0 := 0.9
	m.box(Vector3(0, y0 + 0.46, -0.31), Vector3(0.96, 0.92, 0.02), c(0x5A4630))
	for k in 6:
		m.box(Vector3(0, y0 + 0.01 + k * 0.182, -0.17), Vector3(0.96, 0.02, 0.28), c(OAK_D))
	for k in 7:
		m.box(Vector3(-0.47 + k * 0.1567, y0 + 0.46, -0.17), Vector3(0.02, 0.92, 0.28), c(OAK_D))
	for k in 30:
		var cxp := -0.392 + (k % 6) * 0.1567
		var cyp := y0 + 0.02 + (k / 6) * 0.182
		m.box(Vector3(cxp, cyp + 0.012, -0.027), Vector3(0.09, 0.02, 0.006), c(BRASS_D if (k / 6) % 2 == 0 else CREAM))    # ярлык
		var fill := (hv >> (k % 24)) % 4
		if fill == 0:
			continue
		for j in fill:
			m.push()
			m.translate(Vector3(cxp - 0.03 + j * 0.03, cyp + 0.03, -0.14))
			m.rot_z(-8.0 + j * 7.0)
			m.box(Vector3(0, 0.055, 0), Vector3(0.012, 0.11, 0.2), c([PAPER, MANILA, 0xC8D4EC][(k + j) % 3]))
			m.pop()
	var top := 0.9
	m.box(Vector3(-0.22, top + 0.07, 0.14), Vector3(0.38, 0.14, 0.28), c(0xE8E6E0))  # почтовый лоток
	m.box(Vector3(-0.22, top + 0.12, 0.14), Vector3(0.34, 0.06, 0.24), c(0x9A9EA2))
	for k in 6:
		m.push()
		m.translate(Vector3(-0.35 + k * 0.05, top + 0.1, 0.14))
		m.rot_z(-12)
		m.box(Vector3(0, 0.05, 0), Vector3(0.008, 0.12, 0.2), c([PAPER, MANILA, PAPER, 0xC8D4EC, PAPER, MANILA][k]))
		m.pop()
	m.box(Vector3(0.26, top + 0.025, 0.1), Vector3(0.18, 0.05, 0.16), c(DARK))      # почтовые весы
	m.box(Vector3(0.26, top + 0.07, 0.1), Vector3(0.03, 0.04, 0.03), c(STEEL_D))
	m.box(Vector3(0.26, top + 0.095, 0.1), Vector3(0.2, 0.012, 0.18), c(CHROME))
	m.box(Vector3(0.26, top + 0.12, 0.1), Vector3(0.14, 0.04, 0.1), c(0x9A7A52))    # посылка на весах
	m.box(Vector3(0.38, top + 0.02, 0.26), Vector3(0.1, 0.04, 0.07), c(RED))        # штемпельная подушка
	_cyl(m, Vector3(0.24, top, 0.27), 0.06, 0.02, 0.02, c(MAHOG), 6)                # штемпель
	m.ellipsoid(Vector3(0.24, top + 0.075, 0.27), Vector3(0.025, 0.025, 0.025), c(MAHOG), 3, 6)

## Почтовая тележка с брезентовым коробом
static func _mailcart(m: Mesher, hv: int) -> void:
	for sx: float in [-0.36, 0.36]:
		for sz: float in [-0.22, 0.22]:
			m.box(Vector3(sx, 0.5, sz), Vector3(0.025, 0.86, 0.025), c(CHROME))
			m.box(Vector3(sx, 0.045, sz), Vector3(0.03, 0.03, 0.03), c(CHROME))
			_cyl_x(m, Vector3(sx - 0.014, 0.035, sz), 0.028, 0.035, c(BLACK), 8)
	m.box(Vector3(0, 0.16, 0), Vector3(0.74, 0.025, 0.46), c(STEEL))                # нижняя полка
	m.box(Vector3(0, 0.62, 0), Vector3(0.72, 0.46, 0.44), c(CANVAS))                # короб
	m.box(Vector3(0, 0.85, 0), Vector3(0.75, 0.04, 0.47), c(0x2E4468))
	m.box(Vector3(0, 0.86, 0), Vector3(0.66, 0.03, 0.38), c(0xA89C80))              # тёмное нутро
	m.box(Vector3(0, 0.62, 0.222), Vector3(0.3, 0.14, 0.004), c(0x2E4468))          # нашивка
	m.box(Vector3(0, 0.62, 0.225), Vector3(0.2, 0.03, 0.003), c(CREAM))
	for k in 9:                                                                    # письма и пакеты торчат из короба
		m.push()
		m.translate(Vector3(-0.28 + k * 0.07, 0.84, -0.06 + ((hv >> k) % 3) * 0.06))
		m.rot_z(-14.0 + ((hv >> (k + 2)) % 5) * 7.0)
		m.box(Vector3(0, 0.07, 0), Vector3(0.012, 0.16 + (k % 3) * 0.03, 0.22), c([PAPER, MANILA, PAPER, 0xC8D4EC, MANILA][k % 5]))
		m.pop()
	m.box(Vector3(0.2, 0.93, 0.08), Vector3(0.2, 0.14, 0.16), c(0x9A7A52))          # посылка
	m.box(Vector3(0.2, 0.93, 0.08), Vector3(0.21, 0.012, 0.17), c(0x6A5236))
	m.box(Vector3(0.2, 0.93, 0.08), Vector3(0.012, 0.15, 0.17), c(0x6A5236))
	m.box(Vector3(-0.14, 0.24, 0), Vector3(0.34, 0.14, 0.3), c(0xE8E6E0))           # лоток внизу
	m.box(Vector3(-0.14, 0.3, 0), Vector3(0.3, 0.04, 0.26), c(PAPER))
	m.box(Vector3(0.2, 0.25, 0), Vector3(0.22, 0.16, 0.24), c(0x9A7A52))
	_cyl_z(m, Vector3(-0.4, 0.95, -0.22), 0.44, 0.016, c(CHROME), 8)                # ручка
	for sz2: float in [-0.22, 0.22]:
		m.box(Vector3(-0.38, 0.94, sz2), Vector3(0.05, 0.02, 0.02), c(CHROME))

## Тележка уборщика: мешок, ведро с отжимом, швабра, знак «мокрый пол»
static func _janitor(m: Mesher) -> void:
	var bx := -0.16
	m.box(Vector3(bx, 0.14, -0.04), Vector3(0.52, 0.05, 0.62), c(0x70787E))         # платформа
	for sx: float in [-0.22, 0.22]:
		for sz: float in [-0.3, 0.22]:
			_cyl_x(m, Vector3(bx + sx - 0.014, 0.045, sz), 0.028, 0.045, c(BLACK), 8)
	for sx2: float in [-0.24, 0.24]:
		m.box(Vector3(bx + sx2, 0.62, -0.32), Vector3(0.025, 0.94, 0.025), c(0x9A9EA2))
	m.box(Vector3(bx, 1.08, -0.32), Vector3(0.5, 0.025, 0.025), c(0x9A9EA2))        # ручка
	m.box(Vector3(bx, 0.62, -0.2), Vector3(0.46, 0.84, 0.22), c(YELLOW))            # мешок для мусора
	m.box(Vector3(bx, 1.05, -0.2), Vector3(0.48, 0.03, 0.24), c(0x70787E))
	m.box(Vector3(bx, 1.07, -0.2), Vector3(0.4, 0.02, 0.16), c(DARK))
	m.box(Vector3(bx, 0.52, 0.04), Vector3(0.46, 0.02, 0.26), c(0x70787E))          # полка с бутылками
	for k in 4:
		var col: int = [0x3A8FE0, 0x58B878, 0xE8E6E0, 0xE0683A][k]
		_cyl(m, Vector3(bx - 0.17 + k * 0.11, 0.53, 0.06), 0.14, 0.035, 0.03, c(col), 8)
		m.box(Vector3(bx - 0.17 + k * 0.11, 0.7, 0.07), Vector3(0.025, 0.06, 0.05), c(CREAM if k != 2 else RED))
	for k in 2:                                                                    # рулоны бумаги
		_cyl(m, Vector3(bx - 0.12 + k * 0.14, 0.165, 0.02), 0.12, 0.06, 0.06, c(PAPER), 10)
	# ведро с отжимом и шваброй
	var px := 0.24
	var pz := -0.1
	m.push()
	m.translate(Vector3(px, 0.05, pz))
	m.rot_y(45)
	m.tube(0.0, 0.34, 0.15, 0.19, c(YELLOW), 4)
	m.pop()
	for k in 4:
		_cyl_x(m, Vector3(px - 0.11 + (k % 2) * 0.2 - 0.012, 0.03, pz - 0.1 + (k / 2) * 0.2), 0.024, 0.03, c(BLACK), 6)
	m.box(Vector3(px, 0.38, pz), Vector3(0.22, 0.02, 0.22), c(0x3A8FE0))            # вода
	m.box(Vector3(px, 0.44, pz - 0.08), Vector3(0.22, 0.12, 0.1), c(0x70787E))      # отжим
	m.push()
	m.translate(Vector3(px + 0.12, 0.46, pz - 0.08))
	m.rot_z(-20)
	m.box(Vector3(0, 0.16, 0), Vector3(0.02, 0.32, 0.02), c(0x70787E))
	m.pop()
	m.push()                                                                       # швабра
	m.translate(Vector3(px - 0.02, 0.36, pz + 0.04))
	m.rot_z(8)
	m.rot_x(-10)
	m.box(Vector3(0, 0.6, 0), Vector3(0.022, 1.2, 0.022), c(OAK))
	m.box(Vector3(0, 0.0, 0), Vector3(0.14, 0.06, 0.05), c(0x70787E))
	m.ellipsoid(Vector3(0, -0.06, 0), Vector3(0.09, 0.07, 0.06), c(0xD8D4C4), 3, 6)
	m.pop()
	# знак «мокрый пол» — перед ведром
	for sg: float in [-1.0, 1.0]:
		m.push()
		m.translate(Vector3(0.32, 0.0, 0.16))
		m.rot_y(-20)
		m.rot_x(12.0 * sg)
		m.box(Vector3(0, 0.3, 0), Vector3(0.24, 0.6, 0.012), c(YELLOW))
		m.box(Vector3(0, 0.36, sg * 0.008), Vector3(0.12, 0.12, 0.003), c(RED))
		m.box(Vector3(0, 0.36, sg * 0.01), Vector3(0.02, 0.06, 0.003), c(BLACK))
		m.box(Vector3(0, 0.2, sg * 0.008), Vector3(0.16, 0.03, 0.003), c(BLACK))
		m.pop()

## Шкафы вычислительного центра: накопитель на магнитной ленте и процессорная стойка
static func _mainframe(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.04, -0.02), Vector3(0.94, 0.08, 0.56), c(BLACK))
	var tape_x := -0.24 if hv % 2 == 0 else 0.24
	for k in 2:
		var cx := -0.24 + k * 0.48
		m.box(Vector3(cx, 0.98, -0.02), Vector3(0.47, 1.8, 0.6), c(BEIGE))
		m.box(Vector3(cx, 1.89, -0.02), Vector3(0.47, 0.02, 0.6), c(BEIGE_D))
		for v in 5:                                                                # решётка вентиляции
			m.box(Vector3(cx, 0.2 + v * 0.045, 0.282), Vector3(0.36, 0.02, 0.004), c(0x6A6458))
		if absf(cx - tape_x) < 0.01:
			m.box(Vector3(cx, 1.34, 0.282), Vector3(0.4, 0.8, 0.006), c(0x1E2A3A))  # дверца накопителя
			for r in 2:
				var rc := Vector3(cx - 0.085 + r * 0.17, 1.52, 0.286)
				_disc(m, rc, 0.085, 0.01, c(CREAM), 12)
				_disc(m, rc + Vector3(0, 0, 0.01), 0.06, 0.004, c(0x6A4A2C), 12)    # лента на катушке
				_disc(m, rc + Vector3(0, 0, 0.014), 0.028, 0.006, c(DARK), 8)
				for s in 3:
					var a := TAU * s / 3.0 + float(hv % 7) * 0.3 + r * 0.5
					_line(m, Vector2(rc.x, rc.y), Vector2(rc.x + cos(a) * 0.075, rc.y + sin(a) * 0.075), 0.302, c(CREAM), 0.012)
			_line(m, Vector2(cx - 0.085, 1.435), Vector2(cx - 0.03, 1.2), 0.29, c(0x6A4A2C), 0.006)    # путь ленты
			_line(m, Vector2(cx + 0.085, 1.435), Vector2(cx + 0.03, 1.2), 0.29, c(0x6A4A2C), 0.006)
			m.box(Vector3(cx, 1.17, 0.288), Vector3(0.12, 0.07, 0.008), c(CHROME))  # головка
			m.box(Vector3(cx, 1.04, 0.288), Vector3(0.3, 0.08, 0.006), c(0x9A9EA2))
			m.box(Vector3(cx, 0.78, 0.282), Vector3(0.4, 0.24, 0.006), c(BEIGE_D))  # панель управления
			for b in 6:
				m.box(Vector3(cx - 0.14 + b * 0.056, 0.82, 0.288), Vector3(0.036, 0.036, 0.006),
					c([0xE0483A, 0xE8A83A, 0x58D878, 0xE8E6E0, 0xE8E6E0, 0x3A8FE0][b], 0.5 if b < 3 else 1.0))
			m.box(Vector3(cx, 0.73, 0.288), Vector3(0.3, 0.03, 0.004), c(0x4A4F58))
		else:
			m.box(Vector3(cx, 1.5, 0.282), Vector3(0.4, 0.5, 0.006), c(0x1E2A3A))   # панель с лампочками
			for b in 40:
				var on := ((hv >> (b % 23)) + b) % 3 != 0
				m.box(Vector3(cx - 0.158 + (b % 8) * 0.045, 1.68 - (b / 8) * 0.06, 0.288), Vector3(0.02, 0.02, 0.004),
					c([0xE8A83A, 0xE0483A, 0x58D878][(b / 8) % 3], 0.5) if on else c(0x3A3F45))
			for b in 8:                                                            # тумблеры
				m.box(Vector3(cx - 0.158 + b * 0.045, 1.34, 0.29), Vector3(0.014, 0.04, 0.012), c(CHROME))
			m.box(Vector3(cx, 1.84, 0.282), Vector3(0.4, 0.06, 0.006), c(BLUE))     # полоса с названием
			m.box(Vector3(cx - 0.1, 1.84, 0.286), Vector3(0.14, 0.03, 0.004), c(CREAM))
			m.box(Vector3(cx, 1.0, 0.282), Vector3(0.4, 0.36, 0.006), c(BEIGE_D))   # дисковые отсеки
			for d in 3:
				m.box(Vector3(cx, 0.9 + d * 0.11, 0.288), Vector3(0.34, 0.08, 0.006), c(0x9A9486))
				m.box(Vector3(cx + 0.12, 0.9 + d * 0.11, 0.292), Vector3(0.03, 0.02, 0.004), c(0x58D878, 0.5) if (hv >> d) % 2 == 0 else c(0x3A3F45))
			_disc(m, Vector3(cx + 0.14, 0.72, 0.282), 0.03, 0.02, c(RED), 8)         # аварийная кнопка
	m.box(Vector3(0, 1.92, -0.1), Vector3(0.7, 0.04, 0.2), c(0x70787E))             # кабельный лоток
