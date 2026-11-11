class_name MediaFurniture
extends RefCounted
## Мебель СМИ (клетки GameWorld.REPORTERDESK … CUTTER): редакция газеты, фотолаборатория, радиостудия, телестудия,
## аппаратная, типография.
## Устроена как остальные наборы: начало координат — центр клетки на полу, +z — лицо, -z — к стене.
## У столов и пультов +z — рабочая сторона (там кресло); у стола ведущих -z — сторона камер.
## BACK — на сколько модель уходит назад от центра. Меняешь модель — поправь BACK здесь и GameWorld.FURN_FRONT
## (проверка test_furniture_collision сверяет их с самой моделью).

const W = preload("res://scripts/world.gd")

const BACK := {W.REPORTERDESK: 0.44, W.LAYOUTTABLE: 0.41, W.TELETYPE: 0.33, W.NEWSRACK: 0.25, W.PAGEBOARD: 0.03, W.WORLDCLOCKS: 0.02,
	W.MEDIASIGN: 0.03, W.NEWSBOX: 0.20, W.PAPERBUNDLES: 0.37, W.ENLARGER: 0.32, W.DEVSINK: 0.32, W.DRYLINE: 0.02,
	W.PHOTOBACK: 0.14, W.RADIOCONSOLE: 0.44, W.TURNTABLES: 0.35, W.REELDECK: 0.29, W.RECORDSHELF: 0.23, W.ONAIR: 0.05,
	W.GUESTTABLE: 0.47, W.FOAMPANEL: 0.04, W.STUDIOWALL: 0.10, W.SPEAKERS: 0.17, W.ANCHORDESK: 0.43, W.BACKDROP: 0.17,
	W.WEATHERMAP: 0.17, W.BLUESCREEN: 0.17, W.PROMPTER: 0.32, W.STUDIOLIGHT: 0.19, W.BOOMMIC: 0.36, W.MAKEUP: 0.28,
	W.COSTUMERACK: 0.24, W.SWITCHER: 0.44, W.TVWALL: 0.27, W.EDITBAY: 0.44, W.TAPESHELF: 0.21, W.VTRRACK: 0.30,
	W.AUDIOMIX: 0.43, W.TRANSMITTER: 0.34, W.MEDIAGEAR: 0.23, W.CAMCASES: 0.40, W.PRINTPRESS: 0.39, W.PAPERROLLS: 0.38,
	W.CUTTER: 0.39}

const LAM := 0xCFCBBE         # светлый пластик столов
const WOOD := 0x9A7A52        # «под дерево»
const WOOD_D := 0x6A5236
const GREY := 0x70787E        # стальная мебель редакции
const GREY_L := 0x9AA0A6
const STEEL := 0x8A9096
const STEEL_D := 0x5E646A
const CHROME := 0xCDD1D4
const BLACK := 0x1B1C1F
const DARK := 0x2A2D31
const BEIGE := 0xD5CFBD       # корпуса техники
const BEIGE_D := 0xB5AE9A
const CREAM := 0xECE6D4
const PAPER := 0xF2F0E8
const NEWSPRINT := 0xD8D4C4   # газетная бумага
const MANILA := 0xD9C58A
const RED := 0xC0392B
const BLUE := 0x2F5FA8
const BLUE_D := 0x1F3F78
const GREEN := 0x2F7A4E
const YELLOW := 0xE8C84A
const BRASS := 0xC9A24A
const BRASS_D := 0x9A7A30
const MAHOG := 0x6B3A2A

static func c(hex: int, k: float = 1.0) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255, int(round(k * 255.0)))

## Нарисовать мебель t. wide — длинный вариант на две клетки; link — есть ли такая же мебель слева (1) и справа (2)
## от клетки, если смотреть с лица: по нему ряд (сушка снимков, фон, перегородка) рисует стойки только на концах
static func draw(m: Mesher, t: int, hv: int, wide: bool = false, link: int = 0) -> void:
	match t:
		W.REPORTERDESK: _reporterdesk(m, hv)
		W.LAYOUTTABLE: _layouttable(m, hv, wide)
		W.TELETYPE: _teletype(m, hv)
		W.NEWSRACK: _newsrack(m, hv)
		W.PAGEBOARD: _pageboard(m, hv)
		W.WORLDCLOCKS: _worldclocks(m, hv)
		W.MEDIASIGN: _mediasign(m, hv)
		W.NEWSBOX: _newsbox(m)
		W.PAPERBUNDLES: _paperbundles(m, hv)
		W.ENLARGER: _enlarger(m)
		W.DEVSINK: _devsink(m)
		W.DRYLINE: _dryline(m, hv, link)
		W.PHOTOBACK: _photoback(m, hv, link)
		W.RADIOCONSOLE: _radioconsole(m, hv)
		W.TURNTABLES: _turntables(m, hv)
		W.REELDECK: _reeldeck(m, hv)
		W.RECORDSHELF: _recordshelf(m, hv)
		W.ONAIR: _onair(m, hv)
		W.GUESTTABLE: _guesttable(m, hv)
		W.FOAMPANEL: _foampanel(m, hv)
		W.STUDIOWALL: _studiowall(m, link)
		W.SPEAKERS: _speakers(m, hv)
		W.ANCHORDESK: _anchordesk(m, hv, wide)
		W.BACKDROP: _backdrop(m, hv)
		W.WEATHERMAP: _weathermap(m, hv)
		W.BLUESCREEN: _bluescreen(m, link)
		W.PROMPTER: _prompter(m)
		W.STUDIOLIGHT: _studiolight(m, hv)
		W.BOOMMIC: _boommic(m)
		W.MAKEUP: _makeup(m, hv)
		W.COSTUMERACK: _costumerack(m, hv)
		W.SWITCHER: _switcher(m, hv)
		W.TVWALL: _tvwall(m, hv)
		W.EDITBAY: _editbay(m, hv)
		W.TAPESHELF: _tapeshelf(m, hv)
		W.VTRRACK: _vtrrack(m, hv)
		W.AUDIOMIX: _audiomix(m, hv)
		W.TRANSMITTER: _transmitter(m, hv)
		W.MEDIAGEAR: _mediagear(m, hv)
		W.CAMCASES: _camcases(m, hv)
		W.PRINTPRESS: _printpress(m, hv, wide)
		W.PAPERROLLS: _paperrolls(m, hv)
		W.CUTTER: _cutter(m)

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

# ================== редакция ==================
## Стол репортёра: компьютер, телефон, газеты, блокнот
static func _reporterdesk(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.76, -0.01), Vector3(0.98, 0.04, 0.86), c(LAM))
	m.box(Vector3(0, 0.735, -0.01), Vector3(0.96, 0.015, 0.84), c(STEEL_D))
	m.box(Vector3(0.29, 0.37, -0.01), Vector3(0.36, 0.72, 0.8), c(GREY))            # тумба
	for d in 3:
		m.box(Vector3(0.29, 0.14 + d * 0.22, 0.393), Vector3(0.32, 0.19, 0.012), c(GREY_L))
		m.box(Vector3(0.29, 0.2 + d * 0.22, 0.404), Vector3(0.12, 0.02, 0.014), c(CHROME))
	m.box(Vector3(-0.46, 0.37, -0.01), Vector3(0.04, 0.72, 0.8), c(GREY))
	m.box(Vector3(-0.09, 0.45, -0.42), Vector3(0.74, 0.5, 0.02), c(GREY))
	var top := 0.78
	_crt(m, Vector3(-0.12, top, -0.14))
	_phone(m, Vector3(0.34, top, 0.22), BEIGE)
	for k in 3:                                                                    # стопка газет
		m.box(Vector3(0.33 - k * 0.008, top + 0.012 + k * 0.024, -0.2), Vector3(0.26, 0.022, 0.34), c(NEWSPRINT if k != 1 else 0xCFCAB8))
	m.box(Vector3(0.31, top + 0.085, -0.31), Vector3(0.2, 0.002, 0.045), c(BLACK))
	m.box(Vector3(0.36, top + 0.085, -0.19), Vector3(0.1, 0.002, 0.1), c(0x8A8F96))
	for k in 3:
		m.box(Vector3(0.25, top + 0.085, -0.22 + k * 0.035), Vector3(0.08, 0.002, 0.01), c(0x5A5F66))
	m.box(Vector3(-0.38, top + 0.008, 0.27), Vector3(0.13, 0.016, 0.2), c(PAPER))   # блокнот
	m.box(Vector3(-0.38, top + 0.018, 0.175), Vector3(0.13, 0.008, 0.014), c(STEEL_D))
	for k in 4:
		m.box(Vector3(-0.38, top + 0.017, 0.22 + k * 0.035), Vector3(0.1, 0.002, 0.008), c(0x4A5A9A))
	m.box(Vector3(-0.28, top + 0.01, 0.3), Vector3(0.012, 0.012, 0.13), c(BLUE))
	match hv % 3:
		0:                                                                         # кассетный диктофон
			m.box(Vector3(0.08, top + 0.02, 0.32), Vector3(0.19, 0.04, 0.11), c(DARK))
			m.box(Vector3(0.06, top + 0.042, 0.32), Vector3(0.1, 0.004, 0.055), c(0x5A6A76))
			m.box(Vector3(0.15, top + 0.043, 0.35), Vector3(0.02, 0.006, 0.02), c(RED))
		1:                                                                         # фотоаппарат
			m.box(Vector3(0.08, top + 0.045, 0.3), Vector3(0.15, 0.09, 0.07), c(BLACK))
			_cyl_z(m, Vector3(0.08, top + 0.045, 0.335), 0.08, 0.04, c(DARK), 8)
			m.box(Vector3(0.08, top + 0.1, 0.3), Vector3(0.06, 0.03, 0.05), c(CHROME))
		2:                                                                         # радиосканер
			m.box(Vector3(0.08, top + 0.04, 0.3), Vector3(0.2, 0.08, 0.14), c(DARK))
			m.box(Vector3(0.05, top + 0.05, 0.372), Vector3(0.09, 0.03, 0.004), c(0xE0483A, 0.5))
			m.box(Vector3(0.16, top + 0.18, 0.26), Vector3(0.008, 0.2, 0.008), c(CHROME))
	_mug(m, Vector3(-0.42, top, 0.02), [0xECEBE5, RED, BLUE][hv % 3])
	_cyl(m, Vector3(-0.42, top, -0.28), 0.02, 0.05, 0.055, c(0x7A8A92), 8)          # пепельница

## Световой стол вёрстки: полосы газеты на светящемся стекле
static func _layouttable(m: Mesher, hv: int, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	m.box(Vector3(cx, 0.43, -0.02), Vector3(L - 0.06, 0.78, 0.7), c(GREY))
	m.box(Vector3(cx, 0.03, -0.02), Vector3(L - 0.1, 0.06, 0.66), c(BLACK))
	var nd := 4 if wide else 2
	for k in nd:
		var dw := (L - 0.12) / nd
		for r in 5:
			m.box(Vector3(x0 + 0.06 + dw * (k + 0.5), 0.16 + r * 0.14, 0.332), Vector3(dw - 0.03, 0.12, 0.008), c(GREY_L))
			m.box(Vector3(x0 + 0.06 + dw * (k + 0.5), 0.17 + r * 0.14, 0.34), Vector3(0.1, 0.02, 0.008), c(CHROME))
	m.box(Vector3(cx, 0.85, -0.02), Vector3(L, 0.08, 0.78), c(DARK))                # рама
	m.push()
	m.translate(Vector3(cx, 0.9, -0.02))
	m.rot_x(6)
	m.box(Vector3.ZERO, Vector3(L - 0.06, 0.02, 0.72), c(0xF2F4E2, 0.5))            # светящееся стекло
	var np := 3 if wide else 2
	for k in np:                                                                   # полосы
		var px := -(L - 0.3) * 0.5 + (L - 0.3) * (k + 0.5) / np
		m.box(Vector3(px, 0.013, -0.02), Vector3(0.36, 0.004, 0.52), c(PAPER))
		m.box(Vector3(px, 0.016, -0.24), Vector3(0.32, 0.002, 0.05), c(BLACK))      # шапка
		var ph := (hv + k) % 3
		m.box(Vector3(px - 0.08 + ph * 0.07, 0.016, -0.1), Vector3(0.14, 0.002, 0.14), c(0x8A8F96))    # фото
		for col in 3:
			for ln in 7:
				if absf(-0.1 + col * 0.1 - (-0.08 + ph * 0.07)) < 0.09 and ln < 3:
					continue
				m.box(Vector3(px - 0.11 + col * 0.11, 0.016, -0.17 + ln * 0.055), Vector3(0.09, 0.002, 0.02), c(0x6A6F76))
	m.box(Vector3(-(L - 0.3) * 0.5 - 0.02, 0.02, 0.3), Vector3(0.3, 0.008, 0.035), c(0xD9B45A))    # линейка
	m.box(Vector3((L - 0.3) * 0.5 - 0.1, 0.02, 0.3), Vector3(0.012, 0.012, 0.12), c(RED))          # красный карандаш
	m.box(Vector3((L - 0.3) * 0.5 + 0.02, 0.025, 0.28), Vector3(0.1, 0.03, 0.06), c(STEEL))        # нож и клей
	m.pop()

## Телетайп новостных лент: печатает сам, лента уходит в корзину
static func _teletype(m: Mesher, hv: int) -> void:
	var ax := -0.19
	m.box(Vector3(ax, 0.32, -0.02), Vector3(0.52, 0.64, 0.44), c(BEIGE_D))
	m.box(Vector3(ax, 0.03, -0.02), Vector3(0.56, 0.06, 0.48), c(BLACK))
	for v in 4:
		m.box(Vector3(ax, 0.18 + v * 0.05, 0.202), Vector3(0.36, 0.02, 0.004), c(0x6A6458))
	m.box(Vector3(ax, 0.76, -0.04), Vector3(0.58, 0.24, 0.48), c(BEIGE))            # аппарат
	m.box(Vector3(ax, 0.9, -0.1), Vector3(0.5, 0.06, 0.3), c(DARK))                 # окно печати
	_cyl_x(m, Vector3(ax - 0.22, 0.93, -0.12), 0.44, 0.045, c(BLACK), 8)
	m.push()                                                                       # клавиатура
	m.translate(Vector3(ax, 0.7, 0.24))
	m.rot_x(18)
	m.box(Vector3.ZERO, Vector3(0.5, 0.04, 0.16), c(BEIGE_D))
	for k in 24:
		m.box(Vector3(-0.2 + (k % 8) * 0.057, 0.025, -0.045 + (k / 8) * 0.045), Vector3(0.04, 0.012, 0.03), c(DARK))
	m.pop()
	m.push()                                                                       # лента выходит вверх и падает назад
	m.translate(Vector3(ax, 0.95, -0.14))
	m.rot_x(-14)
	m.box(Vector3(0, 0.14, 0), Vector3(0.3, 0.3, 0.004), c(PAPER))
	for ln in 6:
		m.box(Vector3(-0.02 + (ln % 2) * 0.02, 0.04 + ln * 0.04, 0.003), Vector3(0.22 - (ln % 3) * 0.03, 0.012, 0.002), c(0x4A4F58))
	m.pop()
	m.box(Vector3(ax + 0.24, 0.8, 0.2), Vector3(0.04, 0.04, 0.012), c(0xE8A83A, 0.5) if hv % 2 == 0 else c(0x58D878, 0.5))
	_cyl_x(m, Vector3(ax - 0.2, 1.0, -0.26), 0.4, 0.07, c(PAPER), 10)               # рулон бумаги
	# корзина с оторванными сводками
	var bx := 0.31
	for sx: float in [-0.12, 0.12]:
		for sz: float in [-0.12, 0.12]:
			m.box(Vector3(bx + sx, 0.25, sz), Vector3(0.015, 0.5, 0.015), c(STEEL_D))
	_ring_h(m, Vector3(bx, 0.5, 0), 0.14, 0.015, 0.015, c(STEEL_D), 4)
	m.box(Vector3(bx, 0.06, 0), Vector3(0.26, 0.02, 0.26), c(STEEL_D))
	for k in 5:
		m.push()
		m.translate(Vector3(bx - 0.05 + (k % 3) * 0.04, 0.14 + k * 0.07, -0.04 + (k % 2) * 0.06))
		m.rot_y(25.0 * k + float(hv % 40))
		m.rot_x(20.0 - k * 9.0)
		m.box(Vector3.ZERO, Vector3(0.16, 0.004, 0.2), c(PAPER))
		m.box(Vector3(0, 0.003, -0.05), Vector3(0.12, 0.002, 0.012), c(0x4A4F58))
		m.box(Vector3(0, 0.003, 0.0), Vector3(0.1, 0.002, 0.012), c(0x4A4F58))
		m.pop()

## Газета лицом к зрителю на наклонной полке (ось y — вверх по полке)
static func _paper(m: Mesher, p: Vector3, hv: int, w: float = 0.3, h: float = 0.4) -> void:
	m.box(p, Vector3(w, h, 0.01), c(NEWSPRINT))
	m.box(p + Vector3(0, h * 0.38, 0.006), Vector3(w * 0.86, h * 0.13, 0.003), c(BLACK))
	var left := hv % 2 == 0
	m.box(p + Vector3(w * (-0.2 if left else 0.2), h * 0.08, 0.006), Vector3(w * 0.44, h * 0.3, 0.003), c([0x8A8F96, 0x6E7C8A, 0x9A8A7A][hv % 3]))
	for ln in 4:
		m.box(p + Vector3(w * (0.24 if left else -0.24), h * (0.2 - ln * 0.08), 0.006), Vector3(w * 0.36, h * 0.03, 0.003), c(0x5A5F66))
	for ln in 3:
		m.box(p + Vector3(0, h * (-0.2 - ln * 0.09), 0.006), Vector3(w * 0.84, h * 0.03, 0.003), c(0x5A5F66))

## Стойка со свежими газетами
static func _newsrack(m: Mesher, hv: int) -> void:
	for sx: float in [-0.46, 0.46]:
		m.box(Vector3(sx, 0.75, -0.04), Vector3(0.04, 1.5, 0.4), c(WOOD_D))
	m.box(Vector3(0, 0.75, -0.23), Vector3(0.9, 1.5, 0.02), c(WOOD))
	m.box(Vector3(0, 1.52, -0.04), Vector3(0.96, 0.04, 0.42), c(WOOD_D))
	for r in 3:
		var y := 0.16 + r * 0.46
		m.box(Vector3(0, y, 0.0), Vector3(0.9, 0.03, 0.3), c(WOOD_D))               # полка с бортиком
		m.box(Vector3(0, y + 0.03, 0.14), Vector3(0.9, 0.05, 0.02), c(WOOD_D))
		for k in 2:
			m.push()
			m.translate(Vector3(-0.22 + k * 0.44, y + 0.02, 0.1))
			m.rot_x(-22)
			_paper(m, Vector3(0, 0.2, 0), hv + r * 2 + k, 0.36, 0.4)
			m.pop()
	m.box(Vector3(0, 1.47, 0.172), Vector3(0.5, 0.05, 0.006), c(CREAM))             # табличка

## Доска с полосами номера: что на какой странице
static func _pageboard(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 1.5, 0), Vector3(0.94, 1.14, 0.05), c(WOOD_D))
	m.box(Vector3(0, 1.5, 0.026), Vector3(0.88, 1.08, 0.006), c(0xB58A5A))          # пробка
	m.box(Vector3(0, 1.98, 0.03), Vector3(0.5, 0.06, 0.004), c(CREAM))
	for k in 8:
		var px := -0.315 + (k % 4) * 0.21
		var py := 1.72 - (k / 4) * 0.46
		m.box(Vector3(px, py, 0.031), Vector3(0.18, 0.38, 0.004), c(PAPER))
		m.box(Vector3(px, py + 0.15, 0.034), Vector3(0.15, 0.04, 0.003), c(BLACK))
		var kind := (hv >> k) % 3
		if kind != 0:
			m.box(Vector3(px + (0.03 if kind == 1 else -0.03), py + 0.04, 0.034), Vector3(0.08, 0.1, 0.003), c(0x8A8F96))
		for ln in 4:
			m.box(Vector3(px, py - 0.05 - ln * 0.035, 0.034), Vector3(0.14, 0.012, 0.003), c(0x6A6F76))
		if (hv >> (k + 3)) % 4 == 0:                                               # правка красным
			_line(m, Vector2(px - 0.06, py - 0.02), Vector2(px + 0.06, py - 0.1), 0.037, c(RED), 0.012)
		m.box(Vector3(px, py + 0.2, 0.034), Vector3(0.02, 0.02, 0.006), c([RED, YELLOW, BLUE][k % 3]))    # кнопка

## Часы с поясным временем
static func _worldclocks(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 1.72, 0), Vector3(0.96, 0.46, 0.04), c(DARK))
	m.box(Vector3(0, 1.72, 0.021), Vector3(0.94, 0.02, 0.003), c(CHROME))
	for k in 3:
		var cxk := -0.31 + k * 0.31
		_disc(m, Vector3(cxk, 1.78, 0.02), 0.125, 0.012, c(CHROME), 14)
		_disc(m, Vector3(cxk, 1.78, 0.032), 0.108, 0.004, c(CREAM), 14)
		for q in 4:
			var a := TAU * q / 4.0
			m.box(Vector3(cxk + sin(a) * 0.09, 1.78 + cos(a) * 0.09, 0.037), Vector3(0.014, 0.014, 0.003), c(BLACK))
		var hh := float((hv + k * 5) % 12)
		var mm := float((hv / 12) % 12)
		var ha := TAU * (hh + mm / 12.0) / 12.0
		var ma := TAU * mm / 12.0
		_line(m, Vector2(cxk, 1.78), Vector2(cxk + sin(ha) * 0.055, 1.78 + cos(ha) * 0.055), 0.039, c(BLACK), 0.012)
		_line(m, Vector2(cxk, 1.78), Vector2(cxk + sin(ma) * 0.085, 1.78 + cos(ma) * 0.085), 0.041, c(BLACK), 0.008)
		m.box(Vector3(cxk, 1.565, 0.022), Vector3(0.2, 0.05, 0.004), c(CREAM))      # табличка с городом
		m.box(Vector3(cxk, 1.565, 0.025), Vector3(0.12 + k * 0.02, 0.016, 0.003), c(BLACK))

## Вывеска редакции: светящиеся буквы и земной шар
static func _mediasign(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 1.72, 0), Vector3(0.96, 0.56, 0.05), c(BLUE_D))
	m.box(Vector3(0, 1.72, 0.026), Vector3(0.92, 0.52, 0.004), c(0x16233F))
	_disc(m, Vector3(-0.3, 1.74, 0.028), 0.14, 0.008, c(0x4A8AD0), 14)              # земной шар
	_ring(m, Vector3(-0.3, 1.74, 0.04), 0.07, 0.008, c(CREAM), 10, 0.0, 360.0, 0.004)
	m.box(Vector3(-0.3, 1.74, 0.04), Vector3(0.28, 0.008, 0.004), c(CREAM))
	m.box(Vector3(-0.3, 1.74, 0.04), Vector3(0.008, 0.28, 0.004), c(CREAM))
	m.box(Vector3(-0.3, 1.81, 0.04), Vector3(0.24, 0.006, 0.004), c(CREAM))
	m.box(Vector3(-0.3, 1.67, 0.04), Vector3(0.24, 0.006, 0.004), c(CREAM))
	for k in 4:                                                                    # буквы
		m.box(Vector3(-0.05 + k * 0.125, 1.78, 0.03), Vector3(0.095, 0.2, 0.012), c(0xF4F6FA, 0.5))
		m.box(Vector3(-0.05 + k * 0.125, 1.78 + ((k + hv) % 2) * 0.03 - 0.015, 0.037), Vector3(0.04, 0.07, 0.004), c(0x16233F))
	m.box(Vector3(0.14, 1.59, 0.03), Vector3(0.5, 0.06, 0.008), c(RED))             # красная полоса
	m.box(Vector3(0.14, 1.59, 0.035), Vector3(0.34, 0.02, 0.004), c(CREAM))

## Газетные автоматы
static func _newsbox(m: Mesher) -> void:
	for k in 2:
		var bx := -0.24 + k * 0.48
		var col: int = BLUE if k == 0 else RED
		m.box(Vector3(bx, 0.02, 0), Vector3(0.34, 0.04, 0.34), c(DARK))
		m.box(Vector3(bx, 0.3, 0), Vector3(0.1, 0.52, 0.1), c(DARK))
		m.box(Vector3(bx, 0.86, 0), Vector3(0.42, 0.62, 0.38), c(col))
		m.box(Vector3(bx, 1.2, -0.02), Vector3(0.44, 0.06, 0.36), c(col))
		m.box(Vector3(bx, 0.84, 0.192), Vector3(0.34, 0.44, 0.006), c(0xBFD0D8))    # окошко
		m.push()
		m.translate(Vector3(bx, 0.84, 0.196))
		_paper(m, Vector3.ZERO, k, 0.3, 0.4)
		m.pop()
		m.box(Vector3(bx, 0.6, 0.2), Vector3(0.26, 0.03, 0.03), c(CHROME))          # ручка
		m.box(Vector3(bx + 0.1, 1.2, 0.165), Vector3(0.12, 0.1, 0.03), c(CHROME))   # монетник
		m.box(Vector3(bx + 0.1, 1.21, 0.182), Vector3(0.008, 0.04, 0.004), c(BLACK))
		m.box(Vector3(bx - 0.08, 1.2, 0.165), Vector3(0.2, 0.05, 0.004), c(CREAM))

## Пачка газет, перевязанная лентой: p — центр низа
static func _bundle(m: Mesher, p: Vector3, h: float, hv: int) -> void:
	m.box(p + Vector3(0, h * 0.5, 0), Vector3(0.34, h, 0.42), c(NEWSPRINT if hv % 2 == 0 else 0xCFCAB8))
	for k in 3:
		m.box(p + Vector3(0, h * (0.25 + k * 0.25), 0.211), Vector3(0.34, 0.004, 0.002), c(0xA8A494))
	m.box(p + Vector3(0, h * 0.5, 0), Vector3(0.03, h + 0.006, 0.426), c(YELLOW))   # лента
	m.box(p + Vector3(0, h * 0.5, 0), Vector3(0.346, h + 0.006, 0.03), c(YELLOW))
	m.box(p + Vector3(-0.08, h + 0.002, -0.12), Vector3(0.13, 0.002, 0.07), c(BLACK))
	m.box(p + Vector3(0.09, h + 0.002, 0.08), Vector3(0.1, 0.002, 0.12), c(0x8A8F96))

## Пачки газет на поддоне
static func _paperbundles(m: Mesher, hv: int) -> void:
	for k in 3:                                                                    # поддон
		m.box(Vector3(0, 0.03, -0.26 + k * 0.26), Vector3(0.9, 0.06, 0.08), c(0x9A7A52))
	for k in 5:
		m.box(Vector3(-0.38 + k * 0.19, 0.075, 0), Vector3(0.14, 0.03, 0.74), c(0xB5946A))
	for k in 4:
		var n := 1 + ((hv >> (k * 2)) % 3)
		for j in n:
			_bundle(m, Vector3(-0.2 + (k % 2) * 0.4, 0.09 + j * 0.2, -0.14 + (k / 2) * 0.3), 0.19, hv + k + j)

# ================== фотолаборатория ==================
## Фотоувеличитель на столе
static func _enlarger(m: Mesher) -> void:
	m.box(Vector3(0, 0.74, -0.02), Vector3(0.94, 0.04, 0.6), c(DARK))
	m.box(Vector3(0, 0.36, -0.02), Vector3(0.9, 0.72, 0.56), c(0x3A3F45))
	for k in 2:
		m.box(Vector3(-0.22 + k * 0.44, 0.38, 0.262), Vector3(0.4, 0.6, 0.006), c(0x4A4F55))
		m.box(Vector3(-0.06 + k * 0.12, 0.42, 0.268), Vector3(0.02, 0.08, 0.01), c(CHROME))
	var top := 0.76
	var ax := -0.14
	m.box(Vector3(ax, top + 0.015, 0.0), Vector3(0.5, 0.03, 0.46), c(CREAM))        # основание
	m.box(Vector3(ax, top + 0.5, -0.2), Vector3(0.045, 0.94, 0.045), c(CHROME))     # колонна
	m.box(Vector3(ax, top + 0.62, -0.1), Vector3(0.12, 0.08, 0.2), c(DARK))         # кронштейн
	m.box(Vector3(ax, top + 0.66, 0.02), Vector3(0.2, 0.26, 0.2), c(BLACK))         # головка
	_cyl(m, Vector3(ax, top + 0.79, 0.02), 0.14, 0.09, 0.07, c(DARK), 10)           # фонарь
	_cyl(m, Vector3(ax, top + 0.43, 0.02), 0.1, 0.035, 0.05, c(CHROME), 8)          # объектив
	m.box(Vector3(ax + 0.12, top + 0.62, -0.2), Vector3(0.05, 0.05, 0.05), c(BLACK))
	m.box(Vector3(ax, top + 0.04, 0.02), Vector3(0.36, 0.014, 0.3), c(BLACK))       # кадрирующая рамка
	m.box(Vector3(ax, top + 0.048, 0.02), Vector3(0.28, 0.006, 0.22), c(PAPER))
	m.box(Vector3(ax, top + 0.052, 0.02), Vector3(0.2, 0.002, 0.15), c(0xB8B4AC))   # проекция кадра
	m.box(Vector3(ax - 0.03, top + 0.054, 0.0), Vector3(0.06, 0.002, 0.08), c(0x7A7670))
	m.box(Vector3(0.3, top + 0.05, 0.14), Vector3(0.16, 0.1, 0.14), c(BLACK))       # реле времени
	_disc(m, Vector3(0.3, top + 0.06, 0.21), 0.045, 0.01, c(CREAM), 10)
	_line(m, Vector2(0.3, top + 0.06), Vector2(0.325, top + 0.085), 0.222, c(RED), 0.008)
	m.box(Vector3(0.3, top + 0.03, -0.14), Vector3(0.24, 0.06, 0.3), c(0x2F5FA8))   # пачка фотобумаги
	m.box(Vector3(0.3, top + 0.062, -0.14), Vector3(0.16, 0.004, 0.1), c(CREAM))
	m.box(Vector3(0.36, top + 0.01, 0.28), Vector3(0.012, 0.012, 0.16), c(CHROME))  # пинцет

## Мойка с кюветами: проявитель, стоп-ванна, закрепитель; красный фонарь
static func _devsink(m: Mesher) -> void:
	for sx: float in [-0.44, 0.44]:
		for sz: float in [-0.26, 0.24]:
			m.box(Vector3(sx, 0.38, sz), Vector3(0.04, 0.76, 0.04), c(STEEL_D))
	m.box(Vector3(0, 0.28, -0.01), Vector3(0.88, 0.02, 0.5), c(STEEL))              # полка с канистрами
	for k in 4:
		_cyl(m, Vector3(-0.3 + k * 0.2, 0.29, -0.02), 0.22, 0.07, 0.07, c([0x5A3A22, 0x3A3F45, 0x5A3A22, 0xD8D4C4][k]), 8)
		_cyl(m, Vector3(-0.3 + k * 0.2, 0.51, -0.02), 0.04, 0.03, 0.03, c(BLACK), 6)
		m.box(Vector3(-0.3 + k * 0.2, 0.4, 0.066), Vector3(0.08, 0.08, 0.004), c(CREAM))
	m.box(Vector3(0, 0.78, -0.01), Vector3(0.96, 0.16, 0.6), c(STEEL))              # мойка
	m.box(Vector3(0, 0.862, -0.01), Vector3(0.9, 0.004, 0.54), c(STEEL_D))
	m.box(Vector3(0, 1.05, -0.3), Vector3(0.96, 0.4, 0.03), c(STEEL))               # задняя стенка
	var liq := [0xB58A4A, 0xE8D88A, 0xBFD0D8]
	for k in 3:
		var tx := -0.3 + k * 0.3
		m.box(Vector3(tx, 0.89, 0.0), Vector3(0.27, 0.05, 0.36), c([RED, 0xE8E6E0, 0x9AA0A6][k]))    # кювета
		m.box(Vector3(tx, 0.917, 0.0), Vector3(0.23, 0.004, 0.32), c(liq[k]))
		m.push()
		m.translate(Vector3(tx, 0.921, 0.0))
		m.rot_y(-10.0 + k * 9.0)
		m.box(Vector3.ZERO, Vector3(0.15, 0.003, 0.2), c(PAPER))                    # снимок в растворе
		m.box(Vector3(0, 0.002, 0), Vector3(0.12, 0.002, 0.16), c([0xC8C4BC, 0x8A8680, 0x4A4844][k]))
		m.pop()
	m.box(Vector3(-0.14, 0.93, 0.2), Vector3(0.012, 0.012, 0.16), c(CHROME))        # пинцеты
	m.box(Vector3(0.16, 0.93, 0.2), Vector3(0.012, 0.012, 0.16), c(0x5A8AD0))
	_cyl(m, Vector3(0.38, 0.86, -0.22), 0.2, 0.014, 0.014, c(CHROME), 6)            # кран
	m.box(Vector3(0.38, 1.06, -0.15), Vector3(0.025, 0.025, 0.16), c(CHROME))
	m.box(Vector3(0, 1.36, -0.26), Vector3(0.3, 0.16, 0.12), c(DARK))               # красный фонарь
	m.box(Vector3(0, 1.36, -0.197), Vector3(0.26, 0.12, 0.006), c(0xE0281E, 0.5))
	m.box(Vector3(0, 1.26, -0.28), Vector3(0.03, 0.06, 0.03), c(DARK))
	m.box(Vector3(-0.36, 1.1, -0.28), Vector3(0.03, 0.22, 0.012), c(CREAM))         # термометр
	m.box(Vector3(-0.36, 1.06, -0.272), Vector3(0.008, 0.12, 0.004), c(RED))

## Сушка снимков: верёвка с прищепками вдоль стены
static func _dryline(m: Mesher, hv: int, link: int) -> void:
	m.box(Vector3(0, 1.74, 0.03), Vector3(1.0, 0.008, 0.008), c(0x3A3F45))
	if (link & 1) == 0:
		m.box(Vector3(-0.48, 1.74, 0.01), Vector3(0.03, 0.05, 0.06), c(CHROME))
	if (link & 2) == 0:
		m.box(Vector3(0.48, 1.74, 0.01), Vector3(0.03, 0.05, 0.06), c(CHROME))
	var tones := [0xC8C4BC, 0x8A8680, 0x6E6A64, 0xA8A49C]
	for k in 4:
		if (hv >> k) % 5 == 0:
			continue
		var px := -0.36 + k * 0.24
		var big := (hv >> (k + 4)) % 2 == 0
		var pw := 0.2 if big else 0.15
		var ph := 0.26 if big else 0.2
		m.push()
		m.translate(Vector3(px, 1.74, 0.03))
		m.rot_z(-5.0 + float((hv >> (k * 2)) % 11))
		m.box(Vector3(0, -0.005, 0), Vector3(0.025, 0.05, 0.02), c(0xD9B45A))       # прищепка
		m.box(Vector3(0, -0.03 - ph * 0.5, 0), Vector3(pw, ph, 0.004), c(PAPER))
		m.box(Vector3(0, -0.03 - ph * 0.5, 0.003), Vector3(pw - 0.03, ph - 0.03, 0.003), c(tones[(hv + k) % 4]))
		m.box(Vector3(pw * 0.1, -0.03 - ph * 0.42, 0.006), Vector3(pw * 0.3, ph * 0.36, 0.002), c(tones[(hv + k + 2) % 4]))
		m.pop()

## Бумажный фон для съёмки: рулон на стойках, бумага спускается на пол
static func _photoback(m: Mesher, hv: int, link: int) -> void:
	var col: int = [0xC9CCD0, 0x9CB8D8, 0xE8E0CC][hv % 3] if link == 0 else 0xC9CCD0
	for sg: float in [-1.0, 1.0]:
		if (link & (1 if sg < 0.0 else 2)) != 0:
			continue
		m.box(Vector3(sg * 0.47, 1.1, -0.06), Vector3(0.03, 2.2, 0.03), c(CHROME))
		m.box(Vector3(sg * 0.47, 0.02, 0.0), Vector3(0.04, 0.04, 0.28), c(BLACK))
	_cyl_x(m, Vector3(-0.5, 2.16, -0.06), 1.0, 0.05, c(col), 8)
	m.box(Vector3(0, 1.1, -0.085), Vector3(1.0, 2.14, 0.006), c(col))
	m.push()
	m.translate(Vector3(0, 0.03, -0.085))
	m.rot_x(60)
	m.box(Vector3(0, 0.0, 0.06), Vector3(1.0, 0.006, 0.14), c(col))                 # изгиб у пола
	m.pop()
	m.box(Vector3(0, 0.006, 0.07), Vector3(1.0, 0.006, 0.16), c(col))

# ================== радиостудия ==================
## Стрелочный индикатор уровня: p — центр, лицом на +z
static func _vu(m: Mesher, p: Vector3, w: float, lvl: float) -> void:
	m.box(p, Vector3(w, w * 0.62, 0.006), c(BLACK))
	m.box(p + Vector3(0, 0, 0.004), Vector3(w * 0.88, w * 0.5, 0.004), c(0xF4D58A, 0.5))
	m.box(p + Vector3(w * 0.28, w * 0.12, 0.007), Vector3(w * 0.24, w * 0.05, 0.003), c(0xC0392B))
	var a := deg_to_rad(-40.0 + 80.0 * lvl)
	_line(m, Vector2(p.x, p.y - w * 0.2), Vector2(p.x + sin(a) * w * 0.4, p.y - w * 0.2 + cos(a) * w * 0.4), p.z + 0.009, c(BLACK), w * 0.035)

## Наушники, лежащие на столе
static func _headphones(m: Mesher, p: Vector3, yaw: float) -> void:
	m.push()
	m.translate(p)
	m.rot_y(yaw)
	_ring(m, Vector3(0, 0.05, 0), 0.085, 0.016, c(BLACK), 8, 0.0, 180.0, 0.03)
	for sx: float in [-0.085, 0.085]:
		m.box(Vector3(sx, 0.04, 0), Vector3(0.045, 0.08, 0.08), c(DARK))
	m.pop()

## Студийный микрофон на «журавле»: от точки крепления p тянется к говорящему (к +z)
static func _armmic(m: Mesher, p: Vector3, col: int) -> void:
	m.box(p + Vector3(0, 0.02, 0), Vector3(0.05, 0.04, 0.05), c(BLACK))
	m.push()
	m.translate(p + Vector3(0, 0.04, 0))
	m.rot_x(18)
	m.box(Vector3(0, 0.2, 0), Vector3(0.016, 0.4, 0.016), c(STEEL_D))
	m.translate(Vector3(0, 0.4, 0))
	m.rot_x(84)
	m.box(Vector3(0, 0.17, 0), Vector3(0.016, 0.34, 0.016), c(STEEL_D))
	m.translate(Vector3(0, 0.34, 0))
	m.rot_x(-40)
	_cyl(m, Vector3(0, -0.02, 0), 0.12, 0.028, 0.028, c(DARK), 8)
	m.ellipsoid(Vector3(0, 0.13, 0), Vector3(0.045, 0.06, 0.045), c(col), 4, 8)
	m.pop()

## Пульт радиоведущего: микшер, кассетные плееры джинглов, микрофон
static func _radioconsole(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.76, 0.0), Vector3(0.98, 0.04, 0.88), c(WOOD))
	m.box(Vector3(0, 0.735, 0.0), Vector3(0.96, 0.015, 0.86), c(WOOD_D))
	for sx: float in [-0.47, 0.47]:
		m.box(Vector3(sx, 0.37, 0.0), Vector3(0.04, 0.74, 0.84), c(WOOD_D))
	m.box(Vector3(0, 0.45, -0.41), Vector3(0.9, 0.58, 0.03), c(WOOD_D))
	var top := 0.78
	m.box(Vector3(0, top + 0.13, -0.3), Vector3(0.98, 0.26, 0.24), c(DARK))         # надстройка с аппаратурой
	for k in 3:                                                                    # плееры джинглов
		var kx := -0.3 + k * 0.24
		m.box(Vector3(kx, top + 0.07, -0.178), Vector3(0.2, 0.1, 0.006), c(GREY_L))
		m.box(Vector3(kx, top + 0.085, -0.173), Vector3(0.14, 0.03, 0.004), c(BLACK))
		m.box(Vector3(kx - 0.05, top + 0.04, -0.173), Vector3(0.03, 0.02, 0.006), c(0x58D878, 0.5) if (hv + k) % 3 != 0 else c(0xE0483A, 0.5))
		m.box(Vector3(kx + 0.03, top + 0.04, -0.173), Vector3(0.05, 0.02, 0.006), c(CREAM))
	_vu(m, Vector3(-0.3, top + 0.19, -0.178), 0.14, 0.3 + float(hv % 5) * 0.12)
	_vu(m, Vector3(-0.12, top + 0.19, -0.178), 0.14, 0.2 + float((hv / 5) % 5) * 0.14)
	m.box(Vector3(0.2, top + 0.19, -0.178), Vector3(0.24, 0.08, 0.006), c(BLACK))   # часы
	_seg7(m, Vector3(0.12, top + 0.19, -0.173), 1, 0.05, c(0xFF4A30, 0.5))
	_seg7(m, Vector3(0.16, top + 0.19, -0.173), (hv / 3) % 10, 0.05, c(0xFF4A30, 0.5))
	_seg7(m, Vector3(0.23, top + 0.19, -0.173), (hv / 7) % 6, 0.05, c(0xFF4A30, 0.5))
	_seg7(m, Vector3(0.27, top + 0.19, -0.173), hv % 10, 0.05, c(0xFF4A30, 0.5))
	m.box(Vector3(0.42, top + 0.19, -0.178), Vector3(0.08, 0.06, 0.006), c(0xE0281E, 0.5))    # лампа «эфир»
	m.push()                                                                       # микшер
	m.translate(Vector3(-0.04, top + 0.035, 0.1))
	m.rot_x(10)
	m.box(Vector3.ZERO, Vector3(0.64, 0.05, 0.44), c(0x3A3F45))
	for ch in 8:
		var fx := -0.27 + ch * 0.077
		m.box(Vector3(fx, 0.027, 0.08), Vector3(0.012, 0.004, 0.2), c(BLACK))       # прорезь фейдера
		m.box(Vector3(fx, 0.034, 0.0 + float((hv >> ch) % 5) * 0.035), Vector3(0.04, 0.016, 0.03), c(CREAM if ch < 6 else RED))
		m.box(Vector3(fx, 0.03, -0.1), Vector3(0.04, 0.01, 0.03), c([0xE0483A, 0xE8C84A, 0x58D878][(hv + ch) % 3], 0.5))
		for kn in 2:
			_cyl(m, Vector3(fx, 0.025, -0.15 - kn * 0.04), 0.016, 0.013, 0.013, c([BLUE, 0x9AA0A6][kn]), 6)
	m.pop()
	_armmic(m, Vector3(-0.42, top + 0.26, -0.3), [RED, BLUE, 0x3A3F45][hv % 3])
	_headphones(m, Vector3(0.38, top, 0.2), 30.0)
	for k in 4:                                                                    # диски
		m.box(Vector3(0.39, top + 0.006 + k * 0.012, -0.06), Vector3(0.14, 0.012, 0.125), c([0xE8E6E0, 0x9CB8D8, 0xE8E6E0, 0xF0C4C0][k]))
	_mug(m, Vector3(-0.4, top, 0.34), 0xECEBE5)

## Тумба с двумя проигрывателями пластинок
static func _turntables(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.03, -0.02), Vector3(0.92, 0.06, 0.6), c(BLACK))
	m.box(Vector3(0, 0.45, -0.02), Vector3(0.96, 0.78, 0.64), c(WOOD_D))
	m.box(Vector3(0, 0.86, -0.02), Vector3(0.98, 0.04, 0.66), c(WOOD))
	m.box(Vector3(0, 0.42, 0.29), Vector3(0.88, 0.62, 0.02), c(0x2A2420))           # ниша с пластинками
	var x := -0.42
	var k := 0
	while x < 0.4:
		var bw := 0.012 + ((hv >> (k % 20)) % 3) * 0.006
		m.box(Vector3(x + bw * 0.5, 0.42, 0.296), Vector3(bw, 0.56, 0.012), c([0xC0392B, 0x2F5FA8, 0xE8C84A, 0xECE6D4, 0x2F7A4E, 0x1B1C1F, 0xD07A30][(hv + k * 3) % 7]))
		x += bw + 0.003
		k += 1
	var top := 0.88
	for t in 2:
		var tx := -0.24 + t * 0.48
		m.box(Vector3(tx, top + 0.035, -0.02), Vector3(0.44, 0.07, 0.4), c(GREY_L))  # корпус
		_cyl(m, Vector3(tx - 0.03, top + 0.07, -0.02), 0.016, 0.16, 0.16, c(CHROME), 16)
		_cyl(m, Vector3(tx - 0.03, top + 0.086, -0.02), 0.006, 0.15, 0.15, c(BLACK), 16)       # пластинка
		_cyl(m, Vector3(tx - 0.03, top + 0.092, -0.02), 0.003, 0.05, 0.05, c([RED, YELLOW, BLUE][(hv + t) % 3]), 12)
		_cyl(m, Vector3(tx + 0.17, top + 0.07, -0.16), 0.04, 0.022, 0.022, c(CHROME), 8)       # тонарм
		m.push()
		m.translate(Vector3(tx + 0.17, top + 0.11, -0.16))
		m.rot_y(-18.0 - t * 10.0)
		m.box(Vector3(0, 0, 0.12), Vector3(0.012, 0.012, 0.26), c(CHROME))
		m.box(Vector3(0, -0.008, 0.25), Vector3(0.025, 0.02, 0.04), c(BLACK))
		m.pop()
		m.box(Vector3(tx + 0.17, top + 0.075, 0.13), Vector3(0.04, 0.012, 0.07), c(DARK))      # пуск и скорость
		m.box(Vector3(tx - 0.17, top + 0.075, 0.15), Vector3(0.05, 0.012, 0.03), c(0xE0483A, 0.5))

## Стойка с катушечным магнитофоном и аппаратурой
static func _reeldeck(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.03, -0.02), Vector3(0.66, 0.06, 0.52), c(BLACK))
	m.box(Vector3(0, 0.98, -0.02), Vector3(0.64, 1.84, 0.54), c(DARK))
	for sx: float in [-0.3, 0.3]:
		m.box(Vector3(sx, 0.98, 0.252), Vector3(0.03, 1.8, 0.006), c(STEEL_D))
		for k in 10:
			m.box(Vector3(sx, 0.2 + k * 0.17, 0.256), Vector3(0.012, 0.012, 0.004), c(CHROME))
	var z := 0.252
	m.box(Vector3(0, 1.56, z), Vector3(0.54, 0.6, 0.008), c(0xB8BCC0))              # магнитофон
	for r in 2:
		var rc := Vector3(-0.13 + r * 0.26, 1.68, z + 0.006)
		_disc(m, rc, 0.115, 0.012, c(CHROME), 14)
		_disc(m, rc + Vector3(0, 0, 0.012), 0.07 + r * 0.02, 0.004, c(0x6A4A2C), 14)
		_disc(m, rc + Vector3(0, 0, 0.016), 0.03, 0.006, c(DARK), 8)
		for s in 3:
			var a := TAU * s / 3.0 + float(hv % 9) * 0.25 + r * 0.6
			_disc(m, rc + Vector3(cos(a) * 0.075, sin(a) * 0.075, 0.013), 0.022, 0.004, c(DARK), 6)
	m.box(Vector3(0, 1.5, z + 0.008), Vector3(0.16, 0.07, 0.012), c(DARK))          # блок головок
	_vu(m, Vector3(-0.14, 1.36, z + 0.008), 0.13, 0.5)
	_vu(m, Vector3(0.02, 1.36, z + 0.008), 0.13, 0.35)
	for k in 4:
		_disc(m, Vector3(0.14 + (k % 2) * 0.07, 1.39 - (k / 2) * 0.06, z + 0.006), 0.02, 0.012, c(BLACK), 8)
	m.box(Vector3(0, 1.14, z), Vector3(0.54, 0.16, 0.008), c(0x3A3F45))             # кассетная дека
	m.box(Vector3(-0.1, 1.14, z + 0.006), Vector3(0.22, 0.1, 0.004), c(0x16261E))
	for k in 5:
		m.box(Vector3(0.08 + k * 0.035, 1.11, z + 0.006), Vector3(0.025, 0.03, 0.008), c(CHROME))
	m.box(Vector3(0.2, 1.18, z + 0.006), Vector3(0.1, 0.02, 0.004), c(0x58D878, 0.5))
	m.box(Vector3(0, 0.92, z), Vector3(0.54, 0.22, 0.008), c(0x3A3F45))             # эквалайзер
	for k in 12:
		m.box(Vector3(-0.22 + k * 0.04, 0.92, z + 0.006), Vector3(0.008, 0.16, 0.003), c(BLACK))
		m.box(Vector3(-0.22 + k * 0.04, 0.87 + float((hv >> k) % 5) * 0.025, z + 0.008), Vector3(0.022, 0.02, 0.006), c(CREAM))
	m.box(Vector3(0, 0.68, z), Vector3(0.54, 0.2, 0.008), c(0x9A9EA2))              # коммутация
	for k in 24:
		_disc(m, Vector3(-0.22 + (k % 12) * 0.04, 0.72 - (k / 12) * 0.08, z + 0.006), 0.012, 0.004, c(BLACK), 6)
	m.box(Vector3(0, 0.38, z), Vector3(0.54, 0.32, 0.008), c(BLACK))                # усилитель
	for sx2: float in [-0.23, 0.23]:
		m.box(Vector3(sx2, 0.38, z + 0.016), Vector3(0.02, 0.2, 0.03), c(CHROME))
	for k in 6:
		m.box(Vector3(0, 0.28 + k * 0.035, z + 0.006), Vector3(0.32, 0.012, 0.003), c(0x3A3F45))
	m.box(Vector3(0.16, 0.5, z + 0.006), Vector3(0.03, 0.02, 0.004), c(0x58D878, 0.5))

## Стеллаж с пластинками, кассетами и картриджами
static func _recordshelf(m: Mesher, hv: int) -> void:
	for sx: float in [-0.46, 0.46]:
		m.box(Vector3(sx, 1.0, -0.02), Vector3(0.04, 2.0, 0.4), c(WOOD_D))
	m.box(Vector3(0, 1.0, -0.21), Vector3(0.9, 2.0, 0.02), c(0x4A3826))
	m.box(Vector3(0, 2.0, -0.02), Vector3(0.96, 0.04, 0.42), c(WOOD_D))
	var cols := [0xC0392B, 0x2F5FA8, 0xE8C84A, 0xECE6D4, 0x2F7A4E, 0x1B1C1F, 0xD07A30, 0x7A4A8A]
	for s in 5:
		var sy := 0.06 + s * 0.39
		m.box(Vector3(0, sy, -0.02), Vector3(0.9, 0.03, 0.38), c(WOOD))
		if s == 4:                                                                 # кассеты и картриджи
			for k in 14:
				m.box(Vector3(-0.39 + k * 0.06, sy + 0.07, 0.04), Vector3(0.05, 0.11, 0.14), c(cols[(hv + k * 5) % 8] if k % 3 != 0 else 0xE8E6E0))
				m.box(Vector3(-0.39 + k * 0.06, sy + 0.08, 0.112), Vector3(0.04, 0.05, 0.003), c(CREAM))
			continue
		var x := -0.43
		var k2 := 0
		var face := (hv + s) % 4                # на одной из полок пластинка стоит обложкой к зрителю
		while x < 0.42:
			if s == face and k2 == 6 and x < 0.1:
				m.box(Vector3(x + 0.16, sy + 0.175, 0.13), Vector3(0.31, 0.31, 0.012), c(cols[(hv + s) % 8]))
				_disc(m, Vector3(x + 0.16, sy + 0.175, 0.136), 0.1, 0.004, c(cols[(hv + s + 3) % 8]), 12)
				_disc(m, Vector3(x + 0.16, sy + 0.175, 0.14), 0.03, 0.004, c(CREAM), 8)
				x += 0.33
			else:
				var bw := 0.012 + ((hv >> ((k2 + s * 5) % 24)) % 3) * 0.005
				m.box(Vector3(x + bw * 0.5, sy + 0.175, 0.0), Vector3(bw, 0.31, 0.31), c(cols[(hv + k2 * 3 + s) % 8]))
				x += bw + 0.002
			k2 += 1

## Табло «В эфире» и студийные часы
static func _onair(m: Mesher, hv: int) -> void:
	var on := hv % 3 != 0
	m.box(Vector3(0, 2.0, 0), Vector3(0.7, 0.26, 0.1), c(DARK))
	m.box(Vector3(0, 2.0, 0.052), Vector3(0.64, 0.2, 0.006), c(0xE0281E, 0.5) if on else c(0x5A1814))
	for k in 5:                                                                    # две буквы, пробел, три буквы
		var lx := -0.23 + k * 0.1 + (0.06 if k >= 2 else 0.0)
		m.box(Vector3(lx, 2.0, 0.057), Vector3(0.07, 0.11, 0.004), c(0xFFF4E8, 0.5) if on else c(0x8A4A44))
	m.box(Vector3(0, 1.58, 0), Vector3(0.5, 0.2, 0.06), c(BLACK))                   # часы
	var hh := 1 + hv % 12
	var mm := (hv / 12) % 60
	var col := c(0xFF4A30, 0.5)
	if hh >= 10:
		_seg7(m, Vector3(-0.16, 1.58, 0.032), 1, 0.11, col)
	_seg7(m, Vector3(-0.08, 1.58, 0.032), hh % 10, 0.11, col)
	m.box(Vector3(0, 1.61, 0.032), Vector3(0.016, 0.016, 0.004), col)
	m.box(Vector3(0, 1.55, 0.032), Vector3(0.016, 0.016, 0.004), col)
	_seg7(m, Vector3(0.08, 1.58, 0.032), mm / 10, 0.11, col)
	_seg7(m, Vector3(0.16, 1.58, 0.032), mm % 10, 0.11, col)

## Круглый стол для гостей эфира: три микрофона, наушники
static func _guesttable(m: Mesher, hv: int) -> void:
	_cyl(m, Vector3(0, 0, 0), 0.04, 0.3, 0.28, c(DARK), 14)
	_cyl(m, Vector3(0, 0.04, 0), 0.68, 0.06, 0.06, c(STEEL_D), 10)
	_cyl(m, Vector3(0, 0.72, 0), 0.04, 0.47, 0.47, c(WOOD), 20)
	_cyl(m, Vector3(0, 0.76, 0), 0.006, 0.36, 0.36, c(0x2F4A5A), 20)                # сукно
	_cyl(m, Vector3(0, 0.766, 0), 0.05, 0.09, 0.07, c(DARK), 10)                    # распределитель
	for k in 3:
		m.push()
		m.rot_y(k * 120.0 + 60.0)
		m.box(Vector3(0, 0.776, 0.2), Vector3(0.09, 0.02, 0.09), c(BLACK))          # микрофон на подставке
		m.push()
		m.translate(Vector3(0, 0.786, 0.2))
		m.rot_x(35)
		m.box(Vector3(0, 0.08, 0), Vector3(0.014, 0.16, 0.014), c(STEEL_D))
		_cyl(m, Vector3(0, 0.14, 0), 0.08, 0.024, 0.024, c(DARK), 8)
		m.ellipsoid(Vector3(0, 0.24, 0), Vector3(0.04, 0.05, 0.04), c([RED, BLUE, YELLOW][(hv + k) % 3]), 4, 8)
		m.pop()
		m.box(Vector3(0, 0.77, 0.1), Vector3(0.008, 0.008, 0.2), c(BLACK))          # кабель
		m.box(Vector3(0.14, 0.775, 0.34), Vector3(0.07, 0.02, 0.05), c(DARK))       # кнопка «кашель»
		m.box(Vector3(0.14, 0.787, 0.34), Vector3(0.03, 0.006, 0.03), c(0xE0483A, 0.5))
		_cyl(m, Vector3(-0.16, 0.766, 0.33), 0.09, 0.026, 0.03, c(0xD6E6EC), 8)     # стакан воды
		m.pop()
	_headphones(m, Vector3(0.24, 0.766, 0.0), 70.0)
	_headphones(m, Vector3(-0.12, 0.766, -0.22), -30.0)

## Звукопоглощающая панель из пирамидок
static func _foampanel(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 1.3, -0.02), Vector3(1.0, 1.8, 0.03), c(0x2A2D31))
	var n := 5
	var cs := 1.0 / n
	for r in 9:
		for k in n:
			var col: int = 0x3A3F45 if (r + k) % 2 == 0 else 0x4A5058
			m.push()
			m.translate(Vector3(-0.5 + cs * (k + 0.5), 0.4 + cs * (r + 0.5), -0.005))
			m.rot_x(90)
			m.rot_y(45)
			m.tube(0.0, 0.07, cs * 0.5 * 1.414, 0.012, c(col), 4)
			m.pop()

## Студийная перегородка с окном: низ глухой, выше — рама. Стойки — слева и на конце ряда
static func _studiowall(m: Mesher, link: int) -> void:
	m.box(Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 0.12), c(0x5A6A76))
	m.box(Vector3(0, 0.06, 0), Vector3(1.0, 0.12, 0.14), c(DARK))
	for sg: float in [-1.0, 1.0]:
		m.box(Vector3(0, 0.56, sg * 0.062), Vector3(0.9, 0.72, 0.004), c(0x6E7E8A))
	m.box(Vector3(0, 1.02, 0), Vector3(1.0, 0.05, 0.2), c(WOOD))                    # подоконник
	m.box(Vector3(0, 2.08, 0), Vector3(1.0, 0.12, 0.14), c(WOOD_D))
	var posts := [-0.47] if (link & 2) != 0 else [-0.47, 0.47]
	for sx: float in posts:
		m.box(Vector3(sx, 1.53, 0), Vector3(0.06, 1.0, 0.12), c(WOOD_D))
	m.box(Vector3(0, 1.075, 0), Vector3(0.94, 0.06, 0.012), c(0xC6DDE4))            # кромка стекла
	m.box(Vector3(0, 2.0, 0), Vector3(0.94, 0.04, 0.012), c(0xC6DDE4))

## Студийные колонки на стойках
static func _speakers(m: Mesher, hv: int) -> void:
	for k in 2:
		var sx := -0.25 + k * 0.5
		m.box(Vector3(sx, 0.015, -0.02), Vector3(0.3, 0.03, 0.3), c(BLACK))
		m.box(Vector3(sx, 0.5, -0.02), Vector3(0.05, 0.96, 0.05), c(DARK))
		m.box(Vector3(sx, 0.99, -0.02), Vector3(0.26, 0.02, 0.26), c(BLACK))
		m.box(Vector3(sx, 1.25, -0.02), Vector3(0.32, 0.5, 0.3), c(WOOD_D))
		m.box(Vector3(sx, 1.25, 0.132), Vector3(0.28, 0.46, 0.006), c(BLACK))
		_disc(m, Vector3(sx, 1.17, 0.135), 0.105, 0.012, c(0x3A3F45), 14)           # динамик
		_disc(m, Vector3(sx, 1.17, 0.147), 0.085, 0.004, c(0xE8E6E0 if hv % 2 == 0 else 0x70787E), 14)
		_disc(m, Vector3(sx, 1.17, 0.151), 0.03, 0.006, c(DARK), 8)
		_disc(m, Vector3(sx, 1.38, 0.135), 0.04, 0.01, c(0x3A3F45), 10)
		_disc(m, Vector3(sx, 1.38, 0.145), 0.02, 0.006, c(CHROME), 8)
		m.box(Vector3(sx + 0.09, 1.44, 0.136), Vector3(0.03, 0.02, 0.004), c(0x58D878, 0.5))

# ================== телестудия ==================
## Стол ведущих новостей: к камерам — панель с логотипом и светящимися полосами
static func _anchordesk(m: Mesher, hv: int, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	var x1 := x0 + L
	m.box(Vector3(cx, 0.76, 0.02), Vector3(L, 0.05, 0.8), c(0x3A4A62))
	m.box(Vector3(cx, 0.79, 0.02), Vector3(L - 0.04, 0.012, 0.76), c(0x4A5E7C))
	m.box(Vector3(cx, 0.48, -0.36), Vector3(L, 0.96, 0.08), c(BLUE_D))              # панель к камерам
	m.box(Vector3(cx, 0.97, -0.34), Vector3(L, 0.03, 0.14), c(CHROME))
	for sx: float in [x0 + 0.03, x1 - 0.03]:
		m.box(Vector3(sx, 0.38, 0.02), Vector3(0.06, 0.76, 0.76), c(BLUE_D))
	for k in 3:                                                                    # светящиеся полосы
		m.box(Vector3(cx, 0.16 + k * 0.1, -0.402), Vector3(L - 0.04, 0.03, 0.006), c(0x7FD0FF, 0.5))
	m.box(Vector3(cx, 0.66, -0.402), Vector3(L - 0.04, 0.4, 0.006), c(0x16233F))
	m.box(Vector3(cx, 0.66, -0.408), Vector3(0.56 if wide else 0.5, 0.26, 0.008), c(RED))    # логотип
	_disc(m, Vector3(cx - 0.17, 0.66, -0.412), 0.1, 0.008, c(0x4A8AD0), 12, true)
	m.box(Vector3(cx - 0.17, 0.66, -0.422), Vector3(0.2, 0.008, 0.004), c(CREAM))
	m.box(Vector3(cx - 0.17, 0.66, -0.422), Vector3(0.008, 0.2, 0.004), c(CREAM))
	for k in 3:
		m.box(Vector3(cx + 0.02 + k * 0.09, 0.66, -0.414), Vector3(0.065, 0.13, 0.006), c(0xF4F6FA, 0.5))
	var top := 0.796
	var seats := [x0 + 0.48, x1 - 0.48] if wide else [cx]
	var si := 0
	for px: float in seats:
		m.box(Vector3(px, top + 0.004, 0.16), Vector3(0.24, 0.008, 0.32), c(PAPER))  # тексты
		m.box(Vector3(px + 0.03, top + 0.012, 0.18), Vector3(0.24, 0.006, 0.32), c(0xE8E6DC))
		for ln in 5:
			m.box(Vector3(px + 0.03, top + 0.016, 0.06 + ln * 0.055), Vector3(0.18, 0.002, 0.012), c(0x5A5F66))
		m.box(Vector3(px + 0.2, top + 0.01, 0.2), Vector3(0.012, 0.012, 0.14), c(BLACK))
		m.push()                                                                   # монитор, утопленный в стол
		m.translate(Vector3(px - 0.02, top + 0.07, -0.16))
		m.rot_x(-30)
		m.box(Vector3.ZERO, Vector3(0.3, 0.2, 0.06), c(DARK))
		m.box(Vector3(0, 0, 0.032), Vector3(0.25, 0.16, 0.004), c(0x3A6FC0, 0.5))
		m.box(Vector3(0, -0.05, 0.036), Vector3(0.25, 0.04, 0.003), c(RED))
		m.box(Vector3(-0.05, 0.02, 0.036), Vector3(0.08, 0.07, 0.003), c(0xD9B08C))
		m.pop()
		_mug(m, Vector3(px - 0.26, top, 0.26), [0xECEBE5, BLUE_D][(hv + si) % 2])
		si += 1
	if wide:
		m.box(Vector3(cx, top + 0.02, 0.1), Vector3(0.1, 0.04, 0.14), c(DARK))      # пульт связи с режиссёром
		m.box(Vector3(cx, top + 0.042, 0.1), Vector3(0.04, 0.006, 0.04), c(0x58D878, 0.5))

## Задник студии: ночной город, по рядам стыкуется
static func _backdrop(m: Mesher, hv: int) -> void:
	var z := -0.1
	m.box(Vector3(0, 0.55, z), Vector3(1.0, 1.0, 0.03), c(0x16233F))
	m.box(Vector3(0, 1.4, z), Vector3(1.0, 0.7, 0.03), c(0x24427A))
	m.box(Vector3(0, 2.0, z), Vector3(1.0, 0.5, 0.03), c(0x3A6FC0))
	m.box(Vector3(0, 0.28, z + 0.016), Vector3(1.0, 0.06, 0.004), c(RED))
	m.box(Vector3(0, 0.2, z + 0.016), Vector3(1.0, 0.04, 0.004), c(CREAM))
	var x := -0.5
	var k := 0
	while x < 0.49:                                                                # дома с огнями окон
		var bw := minf(0.12 + ((hv >> (k * 2)) % 3) * 0.05, 0.5 - x)
		var bh := 0.5 + ((hv >> (k * 3 + 1)) % 5) * 0.2
		m.box(Vector3(x + bw * 0.5, 0.36 + bh * 0.5, z + 0.017), Vector3(bw - 0.01, bh, 0.006), c(0x0E1626))
		var rows := int(bh / 0.11)
		for r in rows:
			for q in 2:
				if ((hv >> ((k * 5 + r * 2 + q) % 27)) % 3) != 0:
					m.box(Vector3(x + bw * (0.3 + q * 0.4), 0.42 + r * 0.11, z + 0.021), Vector3(0.025, 0.035, 0.003), c(0xF4D58A, 0.5))
		x += bw
		k += 1
	for sx: float in [-0.44, 0.44]:
		m.box(Vector3(sx, 0.015, -0.02), Vector3(0.04, 0.03, 0.3), c(DARK))

## Карта погоды на стойке
static func _weathermap(m: Mesher, hv: int) -> void:
	for sx: float in [-0.42, 0.42]:
		m.box(Vector3(sx, 0.015, -0.02), Vector3(0.05, 0.03, 0.3), c(DARK))
		m.box(Vector3(sx, 0.4, -0.1), Vector3(0.04, 0.8, 0.04), c(CHROME))
	var z := -0.1
	m.box(Vector3(0, 1.4, z), Vector3(0.98, 1.4, 0.04), c(DARK))
	m.box(Vector3(0, 1.44, z + 0.021), Vector3(0.92, 1.24, 0.004), c(0x3A7FC8))     # море
	var land := [Vector3(-0.1, 1.6, 0.5), Vector3(0.12, 1.5, 0.44), Vector3(-0.22, 1.42, 0.36), Vector3(0.02, 1.3, 0.5), Vector3(0.2, 1.24, 0.3),
		Vector3(-0.16, 1.16, 0.3), Vector3(0.06, 1.08, 0.26)]
	for q: Vector3 in land:                                                        # суша
		m.box(Vector3(q.x, q.y, z + 0.025), Vector3(q.z, 0.2, 0.004), c(0x6EAA5A))
	m.box(Vector3(0.02, 1.38, z + 0.028), Vector3(0.3, 0.16, 0.003), c(0x8FBF6A))
	_disc(m, Vector3(-0.24, 1.74, z + 0.03), 0.07, 0.006, c(0xFFD84A, 0.5), 10)     # солнце
	for k in 8:
		var a := TAU * k / 8.0
		m.box(Vector3(-0.24 + cos(a) * 0.105, 1.74 + sin(a) * 0.105, z + 0.032), Vector3(0.025, 0.025, 0.004), c(0xFFD84A, 0.5))
	for k in 2:                                                                    # тучи с дождём
		var cp := Vector3(0.2 - k * 0.3, 1.52 - k * 0.3, z + 0.032)
		m.ellipsoid(cp, Vector3(0.1, 0.05, 0.008), c(0xF4F6FA), 3, 8)
		m.ellipsoid(cp + Vector3(0.06, 0.03, 0), Vector3(0.07, 0.05, 0.008), c(0xF4F6FA), 3, 8)
		for r in 3:
			_line(m, Vector2(cp.x - 0.05 + r * 0.05, cp.y - 0.06), Vector2(cp.x - 0.07 + r * 0.05, cp.y - 0.12), cp.z, c(0xBFE0FF), 0.01)
	var temps := [[0.26, 1.72], [-0.3, 1.36], [0.24, 1.14]]
	for k in 3:                                                                    # температура
		var tv := 40 + (hv >> (k * 3)) % 50
		var tp: Array = temps[k]
		m.box(Vector3(tp[0], tp[1], z + 0.03), Vector3(0.16, 0.11, 0.004), c(0x16233F))
		_seg7(m, Vector3(float(tp[0]) - 0.035, tp[1], z + 0.034), tv / 10, 0.07, c(0xFFFFFF, 0.5))
		_seg7(m, Vector3(float(tp[0]) + 0.035, tp[1], z + 0.034), tv % 10, 0.07, c(0xFFFFFF, 0.5))
	m.box(Vector3(0, 0.88, z + 0.025), Vector3(0.92, 0.1, 0.004), c(RED))           # нижняя строка
	m.box(Vector3(-0.1, 0.88, z + 0.028), Vector3(0.5, 0.03, 0.003), c(CREAM))

## Синий экран для комбинированных съёмок
static func _bluescreen(m: Mesher, link: int) -> void:
	for sg: float in [-1.0, 1.0]:
		if (link & (1 if sg < 0.0 else 2)) != 0:
			continue
		m.box(Vector3(sg * 0.48, 1.18, -0.08), Vector3(0.03, 2.36, 0.03), c(CHROME))
		m.box(Vector3(sg * 0.48, 0.015, -0.02), Vector3(0.05, 0.03, 0.3), c(DARK))
	m.box(Vector3(0, 2.36, -0.08), Vector3(1.0, 0.03, 0.03), c(CHROME))
	m.box(Vector3(0, 1.18, -0.1), Vector3(1.0, 2.3, 0.008), c(0x2A52D8))
	m.box(Vector3(0, 0.006, 0.02), Vector3(1.0, 0.008, 0.24), c(0x2A52D8))
	for k in 3:
		m.box(Vector3(-0.35 + k * 0.35, 2.35, -0.07), Vector3(0.03, 0.06, 0.05), c(BLACK))    # зажимы

## Штатив на тележке (общий для суфлёра, света и микрофона): h — высота верха колонны
static func _stand(m: Mesher, h: float, r: float = 0.3) -> void:
	for k in 3:
		m.push()
		m.rot_y(k * 120.0)
		m.box(Vector3(0, 0.06, r * 0.5), Vector3(0.035, 0.03, r), c(DARK))
		m.box(Vector3(0, 0.03, r), Vector3(0.05, 0.06, 0.06), c(BLACK))
		m.pop()
	_cyl(m, Vector3(0, 0.05, 0), h * 0.5, 0.028, 0.028, c(DARK), 8)
	_cyl(m, Vector3(0, 0.05 + h * 0.5, 0), h * 0.5 - 0.05, 0.018, 0.018, c(CHROME), 8)
	m.box(Vector3(0, 0.05 + h * 0.5, 0), Vector3(0.05, 0.05, 0.05), c(BLACK))

## Телесуфлёр: экран с бегущим текстом смотрит на ведущего (+z)
static func _prompter(m: Mesher) -> void:
	_stand(m, 1.2, 0.32)
	m.box(Vector3(0, 1.26, 0), Vector3(0.14, 0.06, 0.18), c(BLACK))
	m.box(Vector3(0, 1.4, -0.14), Vector3(0.2, 0.22, 0.36), c(0x4A5058))            # камера за суфлёром
	m.box(Vector3(0, 1.56, -0.22), Vector3(0.12, 0.1, 0.16), c(DARK))
	m.box(Vector3(0, 1.42, 0.2), Vector3(0.44, 0.36, 0.3), c(BLACK))                # кожух
	m.box(Vector3(0, 1.42, 0.352), Vector3(0.38, 0.3, 0.004), c(0x0E1014))
	for ln in 6:                                                                   # строки текста
		m.box(Vector3(-0.01 + (ln % 2) * 0.02, 1.53 - ln * 0.044, 0.356), Vector3(0.3 - (ln % 3) * 0.05, 0.02, 0.003), c(0xFFFFFF, 0.5))
	m.box(Vector3(-0.2, 1.42, 0.356), Vector3(0.02, 0.03, 0.003), c(0xE0483A, 0.5))  # стрелка-указатель
	m.box(Vector3(0, 1.22, 0.24), Vector3(0.4, 0.04, 0.26), c(DARK))                # монитор под стеклом
	m.box(Vector3(0, 1.62, 0.3), Vector3(0.06, 0.04, 0.04), c(0xE0483A, 0.5))

## Студийный свет на стойке: прожектор со шторками, софтбокс или панель ламп
static func _studiolight(m: Mesher, hv: int) -> void:
	_stand(m, 1.8, 0.3)
	m.ellipsoid(Vector3(0.1, 0.1, 0.14), Vector3(0.12, 0.06, 0.09), c(0xD07A30), 3, 8)    # мешок-противовес
	m.box(Vector3(0, 1.86, 0), Vector3(0.3, 0.03, 0.03), c(BLACK))
	m.push()
	m.translate(Vector3(0, 1.86, 0.02))
	m.rot_x(22)
	match hv % 3:
		0:                                                                         # прожектор со шторками
			_cyl_z(m, Vector3(0, 0, -0.12), 0.26, 0.14, c(BLACK), 12)
			_disc(m, Vector3(0, 0, 0.14), 0.12, 0.006, c(0xFFF0B0, 0.5), 12)
			for k in 4:
				m.push()
				m.translate(Vector3(0, 0, 0.15))
				m.rot_z(k * 90.0)
				m.translate(Vector3(0, 0.14, 0))
				m.rot_x(-35)
				m.box(Vector3(0, 0.07, 0), Vector3(0.24, 0.14, 0.006), c(BLACK))
				m.pop()
			for sx: float in [-0.15, 0.15]:
				m.box(Vector3(sx, 0, 0), Vector3(0.012, 0.1, 0.03), c(CHROME))
		1:                                                                         # софтбокс
			m.push()
			m.translate(Vector3(0, 0, -0.1))
			m.rot_x(90)
			m.rot_y(45)
			m.tube(0.0, 0.26, 0.09, 0.3, c(BLACK), 4, 1.0, 1.0, false)
			m.pop()
			m.box(Vector3(0, 0, 0.16), Vector3(0.42, 0.42, 0.006), c(0xFFFBF0, 0.5))
			m.box(Vector3(0, 0, -0.12), Vector3(0.1, 0.1, 0.08), c(DARK))
		2:                                                                         # панель ламп
			m.box(Vector3(0, 0, 0), Vector3(0.52, 0.32, 0.08), c(BLACK))
			for k in 4:
				m.box(Vector3(0, -0.11 + k * 0.073, 0.042), Vector3(0.46, 0.04, 0.006), c(0xF4FBFF, 0.5))
			for sg: float in [-1.0, 1.0]:
				m.push()
				m.translate(Vector3(sg * 0.26, 0, 0.04))
				m.rot_y(-40.0 * sg)
				m.box(Vector3(sg * 0.07, 0, 0), Vector3(0.14, 0.32, 0.006), c(DARK))
				m.pop()
	m.pop()

## Микрофон-журавль: стрела тянется вперёд (+z)
static func _boommic(m: Mesher) -> void:
	_stand(m, 1.5, 0.32)
	m.box(Vector3(0, 1.56, 0), Vector3(0.08, 0.08, 0.08), c(BLACK))
	m.push()
	m.translate(Vector3(0, 1.58, 0))
	m.rot_x(-20)
	m.box(Vector3(0, 0, 0.0), Vector3(0.03, 0.03, 0.72), c(CHROME))
	m.box(Vector3(0, 0, -0.3), Vector3(0.09, 0.09, 0.12), c(DARK))                  # противовес
	m.translate(Vector3(0, 0, 0.35))
	m.rot_x(30)
	m.box(Vector3(0, -0.04, 0), Vector3(0.02, 0.08, 0.02), c(BLACK))
	m.push()
	m.translate(Vector3(0, -0.09, -0.14))
	m.rot_x(90)
	m.ellipsoid(Vector3(0, 0.1, 0), Vector3(0.045, 0.14, 0.045), c(0x70787E), 5, 8)    # ветрозащита
	m.pop()
	m.pop()
	_ring_h(m, Vector3(-0.14, 0.02, -0.12), 0.09, 0.025, 0.025, c(BLACK), 10)       # кабель

## Гримёрный стол: зеркало с лампами
static func _makeup(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.76, -0.02), Vector3(0.96, 0.04, 0.52), c(0xECEBE5))
	for sx: float in [-0.3, 0.3]:
		m.box(Vector3(sx, 0.37, -0.02), Vector3(0.32, 0.74, 0.48), c(0xDDDCD4))
		for d in 3:
			m.box(Vector3(sx, 0.16 + d * 0.21, 0.222), Vector3(0.28, 0.18, 0.008), c(0xECEBE5))
			m.box(Vector3(sx, 0.16 + d * 0.21, 0.23), Vector3(0.08, 0.02, 0.01), c(BRASS))
	m.box(Vector3(0, 1.4, -0.25), Vector3(0.96, 1.16, 0.04), c(0xDDDCD4))           # рама зеркала
	m.box(Vector3(0, 1.4, -0.228), Vector3(0.74, 0.92, 0.006), c(0xC6DDE4))
	m.box(Vector3(0.1, 1.5, -0.224), Vector3(0.1, 0.5, 0.003), c(0xE4F0F4))         # блик
	for k in 14:                                                                   # лампы вокруг зеркала
		var bp := Vector3.ZERO
		if k < 5:
			bp = Vector3(-0.36 + k * 0.18, 1.92, -0.22)
		elif k < 10:
			bp = Vector3(-0.43, 1.74 - (k - 5) * 0.2, -0.22)
		else:
			bp = Vector3(0.43, 1.74 - (k - 10) * 0.2, -0.22) if k < 14 else bp
		m.ellipsoid(bp, Vector3(0.035, 0.035, 0.03), c(0xFFF4C8, 0.5), 3, 6)
	var top := 0.78
	_cyl(m, Vector3(-0.36, top, -0.08), 0.1, 0.04, 0.045, c(0xF0C4C0), 8)           # кисти в стакане
	for k in 4:
		m.box(Vector3(-0.375 + k * 0.012, top + 0.15, -0.08 + (k % 2) * 0.012), Vector3(0.008, 0.12, 0.008), c([BLACK, WOOD, BLACK, 0xC0392B][k]))
	for k in 3:                                                                    # палетки
		m.box(Vector3(-0.1 + k * 0.14, top + 0.01, 0.08), Vector3(0.12, 0.02, 0.09), c(BLACK))
		for q in 4:
			m.box(Vector3(-0.135 + k * 0.14 + q * 0.024, top + 0.022, 0.08), Vector3(0.018, 0.004, 0.06), c([0xE8B8A0, 0xC88A7A, 0xB0486A, 0x7A4A8A, 0xD9B08C, 0xF0C4C0, 0xC0392B, 0x8A5A3A][(hv + k * 3 + q) % 8]))
	for k in 4:                                                                    # флаконы и помады
		_cyl(m, Vector3(0.2 + k * 0.055, top, -0.12), 0.07 + (k % 2) * 0.04, 0.02, 0.016, c([0xF0C4C0, 0x9CCBEA, 0xE8C84A, 0xECEBE5][k]), 6)
	m.ellipsoid(Vector3(0.36, top + 0.2, 0.02), Vector3(0.07, 0.09, 0.08), c(0xECE6D4), 4, 8)      # болванка для парика
	_cyl(m, Vector3(0.36, top, 0.02), 0.12, 0.03, 0.03, c(0xECE6D4), 6)
	m.ellipsoid(Vector3(0.36, top + 0.24, 0.0), Vector3(0.08, 0.07, 0.09), c([0x6A4A2C, 0xD9B45A, 0x8A2A22][hv % 3]), 3, 8, 0.0, 0.6)
	m.box(Vector3(-0.2, top + 0.035, -0.14), Vector3(0.18, 0.07, 0.1), c(0xC8E0D8)) # салфетки
	m.box(Vector3(-0.2, top + 0.075, -0.14), Vector3(0.05, 0.02, 0.03), c(PAPER))

## Вешалка на колёсах с костюмами для эфира
static func _costumerack(m: Mesher, hv: int) -> void:
	for sx: float in [-0.44, 0.44]:
		m.box(Vector3(sx, 0.9, 0), Vector3(0.03, 1.72, 0.03), c(CHROME))
		m.box(Vector3(sx, 0.06, 0), Vector3(0.03, 0.03, 0.46), c(CHROME))
		for sz: float in [-0.21, 0.21]:
			_cyl_x(m, Vector3(sx - 0.014, 0.03, sz), 0.028, 0.03, c(BLACK), 6)
	_cyl_x(m, Vector3(-0.46, 1.76, 0), 0.92, 0.016, c(CHROME), 8)
	m.box(Vector3(0, 0.1, 0), Vector3(0.86, 0.02, 0.4), c(STEEL))                   # полка для обуви
	var cols := [0x1F2F4A, 0x70787E, 0xC0392B, 0xE8C84A, 0x2F7A4E, 0xECE6D4, 0x4A3826, 0x7A4A8A, 0x2F5FA8]
	for k in 8:
		var gx := -0.36 + k * 0.103
		var col: int = cols[(hv + k * 2) % 9]
		var long := (hv >> k) % 3 == 0
		var gh := 1.05 if long else 0.72
		m.box(Vector3(gx, 1.73, 0), Vector3(0.01, 0.06, 0.012), c(CHROME))          # крючок плечиков
		m.box(Vector3(gx, 1.69, 0), Vector3(0.016, 0.02, 0.4), c(WOOD))
		m.box(Vector3(gx, 1.68 - gh * 0.5, 0), Vector3(0.075, gh, 0.42 if not long else 0.36), c(col))
		if not long:                                                               # лацканы пиджака
			m.box(Vector3(gx, 1.56, 0.212), Vector3(0.04, 0.2, 0.004), c(0xECE6D4))
	for k in 3:                                                                    # обувь
		m.box(Vector3(-0.28 + k * 0.28, 0.15, 0.04), Vector3(0.2, 0.08, 0.26), c([BLACK, 0x6A4A2C, 0xC0392B][k]))
	m.ellipsoid(Vector3(0.3, 1.86, 0), Vector3(0.14, 0.03, 0.14), c(0x4A3826), 3, 10)    # шляпа на перекладине
	m.ellipsoid(Vector3(0.3, 1.9, 0), Vector3(0.08, 0.06, 0.08), c(0x4A3826), 3, 8, 0.0, 0.5)

# ================== аппаратная ==================
## Картинка на экране монитора: p — центр, w × h — размер. kind: 0 — цветные полосы, 1 — диктор, 2 — карта, 3 — помехи, 4 — город
static func _picture(m: Mesher, p: Vector3, w: float, h: float, kind: int) -> void:
	match kind % 5:
		0:
			var bars := [0xE8E8E8, 0xE8E84A, 0x4AE8E8, 0x4AE84A, 0xE84AE8, 0xE84A4A, 0x4A4AE8]
			for k in 7:
				m.box(p + Vector3(-w * 0.5 + w * (k + 0.5) / 7.0, h * 0.1, 0), Vector3(w / 7.0, h * 0.8, 0.004), c(bars[k], 0.5))
			m.box(p + Vector3(0, -h * 0.4, 0), Vector3(w, h * 0.2, 0.004), c(0x1A1A2A, 0.5))
		1:
			m.box(p, Vector3(w, h, 0.004), c(0x3A6FC0, 0.5))
			m.box(p + Vector3(-w * 0.1, -h * 0.22, 0.003), Vector3(w * 0.4, h * 0.4, 0.003), c(0x2A2D3A, 0.5))
			m.box(p + Vector3(-w * 0.1, h * 0.12, 0.003), Vector3(w * 0.2, h * 0.3, 0.003), c(0xE8B890, 0.5))
			m.box(p + Vector3(0, -h * 0.4, 0.005), Vector3(w, h * 0.16, 0.003), c(0xC0392B, 0.5))
		2:
			m.box(p, Vector3(w, h, 0.004), c(0x3A7FC8, 0.5))
			m.box(p + Vector3(-w * 0.06, h * 0.05, 0.003), Vector3(w * 0.5, h * 0.5, 0.003), c(0x6EAA5A, 0.5))
			m.box(p + Vector3(w * 0.18, -h * 0.18, 0.003), Vector3(w * 0.3, h * 0.3, 0.003), c(0x6EAA5A, 0.5))
			m.box(p + Vector3(-w * 0.26, h * 0.26, 0.005), Vector3(w * 0.16, w * 0.16, 0.003), c(0xFFD84A, 0.5))
		3:
			m.box(p, Vector3(w, h, 0.004), c(0x8A8F96, 0.5))
			for k in 5:
				m.box(p + Vector3(0, -h * 0.4 + k * h * 0.2, 0.003), Vector3(w, h * 0.06, 0.003), c(0x4A4F58 if k % 2 == 0 else 0xC8CCD0, 0.5))
		4:
			m.box(p, Vector3(w, h, 0.004), c(0xD88A4A, 0.5))
			m.box(p + Vector3(0, -h * 0.3, 0.003), Vector3(w, h * 0.4, 0.003), c(0x2A2D3A, 0.5))
			for k in 4:
				m.box(p + Vector3(-w * 0.36 + k * w * 0.24, -h * 0.02 + (k % 2) * h * 0.1, 0.003), Vector3(w * 0.16, h * 0.4 + (k % 2) * h * 0.2, 0.003), c(0x2A2D3A, 0.5))

## Режиссёрский пульт: ряды кнопок, рычаг перехода, три контрольных монитора
static func _switcher(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.74, 0.0), Vector3(0.98, 0.04, 0.88), c(GREY))
	for sx: float in [-0.47, 0.47]:
		m.box(Vector3(sx, 0.36, 0.0), Vector3(0.04, 0.72, 0.84), c(DARK))
	m.box(Vector3(0, 0.44, -0.41), Vector3(0.9, 0.58, 0.03), c(DARK))
	var top := 0.76
	for k in 3:                                                                    # контрольные мониторы
		var mx := -0.32 + k * 0.32
		m.box(Vector3(mx, top + 0.14, -0.28), Vector3(0.3, 0.28, 0.28), c(DARK))
		m.box(Vector3(mx, top + 0.15, -0.138), Vector3(0.25, 0.2, 0.004), c(BLACK))
		_picture(m, Vector3(mx, top + 0.15, -0.134), 0.23, 0.18, [0, 1, 4][k] + (hv % 2) * k)
		m.box(Vector3(mx, top + 0.275, -0.138), Vector3(0.06, 0.02, 0.006), c(0xE0483A, 0.5) if k == 1 else c(0x58D878, 0.5))
	m.push()
	m.translate(Vector3(0, top + 0.04, 0.16))
	m.rot_x(12)
	m.box(Vector3.ZERO, Vector3(0.94, 0.06, 0.46), c(0x3A3F45))
	var lit := [0xE0483A, 0x58D878, 0xE8C84A, 0xF4F6FA]
	for r in 4:                                                                    # шины камер
		for k in 10:
			var on := (k == (hv + r * 3) % 10)
			m.box(Vector3(-0.4 + k * 0.058, 0.034, -0.16 + r * 0.075), Vector3(0.042, 0.012, 0.042), c(lit[r], 0.5) if on else c(0x9AA0A6))
	m.box(Vector3(0.3, 0.032, 0.05), Vector3(0.05, 0.006, 0.24), c(BLACK))          # рычаг перехода
	m.push()
	m.translate(Vector3(0.3, 0.03, 0.05 + float(hv % 3) * 0.06 - 0.06))
	m.rot_x(-20)
	m.box(Vector3(0, 0.05, 0), Vector3(0.02, 0.1, 0.02), c(CHROME))
	m.box(Vector3(0, 0.1, 0), Vector3(0.1, 0.03, 0.03), c(BLACK))
	m.pop()
	for k in 4:
		_cyl(m, Vector3(0.38 + (k % 2) * 0.05, 0.03, -0.14 + (k / 2) * 0.07), 0.02, 0.016, 0.016, c(GREY_L), 6)
	_cyl(m, Vector3(0.4, 0.03, 0.12), 0.06, 0.012, 0.012, c(BLACK), 6)              # джойстик
	m.ellipsoid(Vector3(0.4, 0.1, 0.12), Vector3(0.02, 0.02, 0.02), c(RED), 3, 6)
	m.box(Vector3(-0.32, 0.034, 0.17), Vector3(0.22, 0.008, 0.08), c(BEIGE_D))      # клавиатура титров
	m.pop()
	m.box(Vector3(-0.44, top + 0.01, -0.06), Vector3(0.06, 0.02, 0.06), c(BLACK))   # микрофон связи
	m.push()
	m.translate(Vector3(-0.44, top + 0.02, -0.06))
	m.rot_x(25)
	m.box(Vector3(0, 0.12, 0), Vector3(0.01, 0.24, 0.01), c(STEEL_D))
	m.ellipsoid(Vector3(0, 0.25, 0), Vector3(0.02, 0.03, 0.02), c(BLACK), 3, 6)
	m.pop()

## Стена мониторов
static func _tvwall(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 1.05, -0.04), Vector3(0.98, 2.1, 0.44), c(DARK))
	m.box(Vector3(0, 0.03, -0.04), Vector3(1.0, 0.06, 0.46), c(BLACK))
	var z := 0.182
	for k in 9:
		var px := -0.32 + (k % 3) * 0.32
		var py := 1.82 - (k / 3) * 0.36
		m.box(Vector3(px, py, z), Vector3(0.3, 0.3, 0.008), c(0x3A3F45))
		m.box(Vector3(px, py + 0.015, z + 0.005), Vector3(0.26, 0.22, 0.004), c(BLACK))
		_picture(m, Vector3(px, py + 0.015, z + 0.009), 0.24, 0.2, (hv >> k) + k)
		m.box(Vector3(px - 0.1, py - 0.125, z + 0.006), Vector3(0.05, 0.016, 0.004), c(0xE0483A, 0.5) if k == hv % 9 else c(0x4A2A28))
		m.box(Vector3(px + 0.06, py - 0.125, z + 0.006), Vector3(0.12, 0.014, 0.004), c(CREAM))
	for k in 2:                                                                    # осциллографы сигнала
		var wx := -0.3 + k * 0.3
		m.box(Vector3(wx, 0.72, z), Vector3(0.28, 0.22, 0.008), c(BEIGE_D))
		m.box(Vector3(wx - 0.03, 0.72, z + 0.005), Vector3(0.18, 0.16, 0.004), c(0x10241A))
		for q in 6:
			_line(m, Vector2(wx - 0.11 + q * 0.03, 0.7 + ((q + hv) % 3) * 0.03), Vector2(wx - 0.08 + q * 0.03, 0.7 + ((q + hv + 1) % 3) * 0.03), z + 0.009, c(0x58E878, 0.5), 0.008)
		for q in 3:
			_disc(m, Vector3(wx + 0.1, 0.78 - q * 0.05, z + 0.004), 0.014, 0.01, c(BLACK), 6)
	m.box(Vector3(0.32, 0.72, z), Vector3(0.28, 0.14, 0.008), c(BLACK))             # часы эфира
	for k in 4:
		_seg7(m, Vector3(0.225 + k * 0.058 + (0.012 if k > 1 else 0.0), 0.72, z + 0.006), (hv >> (k * 2)) % (6 if k % 2 == 0 else 10), 0.07, c(0xFF4A30, 0.5))
	m.box(Vector3(0, 0.36, z), Vector3(0.92, 0.42, 0.008), c(0x3A3F45))             # решётка
	for k in 8:
		m.box(Vector3(0, 0.2 + k * 0.045, z + 0.005), Vector3(0.8, 0.018, 0.003), c(BLACK))

## Монтажный стол: два видеомагнитофона, два монитора, пульт монтажа
static func _editbay(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.74, -0.01), Vector3(0.98, 0.04, 0.86), c(WOOD))
	m.box(Vector3(0, 0.715, -0.01), Vector3(0.96, 0.015, 0.84), c(WOOD_D))
	for sx: float in [-0.47, 0.47]:
		m.box(Vector3(sx, 0.36, -0.01), Vector3(0.04, 0.72, 0.82), c(WOOD_D))
	m.box(Vector3(0, 0.44, -0.41), Vector3(0.9, 0.56, 0.03), c(WOOD_D))
	var top := 0.76
	for k in 2:                                                                    # видеомагнитофоны
		var vy := top + 0.075 + k * 0.16
		m.box(Vector3(0.22, vy, -0.2), Vector3(0.48, 0.15, 0.42), c(BEIGE_D))
		m.box(Vector3(0.14, vy + 0.03, 0.012), Vector3(0.26, 0.05, 0.004), c(BLACK))                # приёмник кассеты
		m.box(Vector3(0.12, vy - 0.035, 0.012), Vector3(0.2, 0.035, 0.004), c(0x16261E))
		for q in 4:
			_seg7(m, Vector3(0.06 + q * 0.035, vy - 0.035, 0.016), (hv >> (q + k * 4)) % 10, 0.025, c(0x58D878, 0.5))
		_disc(m, Vector3(0.38, vy - 0.01, 0.01), 0.045, 0.012, c(DARK), 10)                         # колесо поиска
		m.box(Vector3(0.3, vy + 0.035, 0.014), Vector3(0.04, 0.02, 0.006), c(0xE0483A, 0.5) if k == 1 else c(0x58D878, 0.5))
	for k in 2:                                                                    # мониторы
		var mx := -0.32 + k * 0.0
		var my := top + 0.16 + k * 0.32
		m.box(Vector3(mx, my, -0.22), Vector3(0.32, 0.3, 0.34), c(DARK))
		m.box(Vector3(mx, my + 0.01, -0.048), Vector3(0.27, 0.22, 0.004), c(BLACK))
		_picture(m, Vector3(mx, my + 0.01, -0.044), 0.25, 0.2, 1 + k * 3 + hv % 2)
	# пульт монтажа
	m.push()
	m.translate(Vector3(0.12, top + 0.03, 0.22))
	m.rot_x(10)
	m.box(Vector3.ZERO, Vector3(0.5, 0.05, 0.26), c(BEIGE))
	_cyl(m, Vector3(0.15, 0.025, 0.02), 0.02, 0.06, 0.06, c(DARK), 12)              # колесо покадровой перемотки
	_cyl(m, Vector3(0.15, 0.045, 0.02), 0.008, 0.02, 0.02, c(CHROME), 8)
	for k in 15:
		m.box(Vector3(-0.2 + (k % 5) * 0.05, 0.03, -0.07 + (k / 5) * 0.05), Vector3(0.036, 0.01, 0.036),
			c([0xE0483A, 0xE8C84A, 0x58D878][k / 5], 0.5) if k % 5 == (hv + k / 5) % 5 else c(0x9AA0A6))
	m.box(Vector3(-0.08, 0.03, 0.09), Vector3(0.28, 0.008, 0.04), c(BEIGE_D))
	m.pop()
	for k in 4:                                                                    # кассеты
		m.box(Vector3(-0.3, top + 0.02 + k * 0.035, 0.24), Vector3(0.2, 0.033, 0.13), c(DARK if k % 2 == 0 else 0x2F3F5A))
		m.box(Vector3(-0.3, top + 0.02 + k * 0.035, 0.306), Vector3(0.14, 0.02, 0.003), c(PAPER))
	_headphones(m, Vector3(-0.3, top + 0.14, 0.24), 20.0)

## Стеллаж с видеокассетами
static func _tapeshelf(m: Mesher, hv: int) -> void:
	for sx: float in [-0.46, 0.46]:
		for sz: float in [-0.18, 0.18]:
			m.box(Vector3(sx, 1.0, sz), Vector3(0.035, 2.0, 0.035), c(STEEL_D))
	m.box(Vector3(0, 1.0, -0.2), Vector3(0.92, 2.0, 0.01), c(0x6E747A))
	var cols := [0x1B1C1F, 0x2F3F5A, 0x70787E, 0x1B1C1F, 0x4A2A28]
	for s in 6:
		var sy := 0.08 + s * 0.33
		m.box(Vector3(0, sy, 0), Vector3(0.94, 0.025, 0.4), c(STEEL))
		if s == 5:                                                                 # коробки с плёнкой
			for k in 3:
				_cyl(m, Vector3(-0.28 + k * 0.28, sy + 0.012, 0.0), 0.05 + (k % 2) * 0.05, 0.13, 0.13, c(CHROME), 12)
				m.box(Vector3(-0.28 + k * 0.28, sy + 0.07 + (k % 2) * 0.05, 0.0), Vector3(0.12, 0.004, 0.05), c(PAPER))
			continue
		var big := (s + hv) % 3 == 0             # ряд больших кассет
		var cw := 0.062 if big else 0.042
		var ch := 0.27 if big else 0.2
		var n := int(0.88 / cw)
		for k in n:
			if ((hv >> ((k + s * 7) % 27)) % 9) == 0:
				continue
			var x := -0.44 + cw * (k + 0.5)
			m.box(Vector3(x, sy + 0.013 + ch * 0.5, 0.02), Vector3(cw - 0.006, ch, 0.3), c(cols[(hv + k + s * 2) % 5]))
			m.box(Vector3(x, sy + 0.013 + ch * 0.55, 0.172), Vector3(cw - 0.016, ch * 0.6, 0.003), c(PAPER))
			m.box(Vector3(x, sy + 0.013 + ch * 0.78, 0.175), Vector3(cw - 0.022, 0.02, 0.003), c([RED, BLUE, YELLOW, GREEN][(hv + k * 3 + s) % 4]))

## Стойки с аппаратурой: видеомагнитофоны, коммутатор, контроль сигнала
static func _vtrrack(m: Mesher, hv: int) -> void:
	m.box(Vector3(0, 0.03, -0.02), Vector3(0.96, 0.06, 0.56), c(BLACK))
	for k in 2:
		var cx := -0.24 + k * 0.48
		var z := 0.262
		m.box(Vector3(cx, 0.98, -0.02), Vector3(0.47, 1.84, 0.56), c(DARK))
		for sx: float in [-0.215, 0.215]:
			m.box(Vector3(cx + sx, 0.98, z), Vector3(0.02, 1.8, 0.006), c(STEEL_D))
		var y := 1.84
		for u in 7:
			var kind := (hv + u * 2 + k * 3) % 5
			var uh := [0.2, 0.14, 0.26, 0.14, 0.2][kind] as float
			if y - uh < 0.14:
				break
			var uy := y - uh * 0.5
			match kind:
				0:                                                                 # видеомагнитофон
					m.box(Vector3(cx, uy, z), Vector3(0.4, uh - 0.01, 0.008), c(BEIGE_D))
					m.box(Vector3(cx - 0.05, uy + 0.04, z + 0.006), Vector3(0.24, 0.045, 0.004), c(BLACK))
					for q in 4:
						_seg7(m, Vector3(cx - 0.12 + q * 0.03, uy - 0.04, z + 0.008), (hv >> (q + u)) % 10, 0.022, c(0x58D878, 0.5))
					_disc(m, Vector3(cx + 0.13, uy - 0.02, z + 0.004), 0.035, 0.012, c(DARK), 10)
				1:                                                                 # коммутация
					m.box(Vector3(cx, uy, z), Vector3(0.4, uh - 0.01, 0.008), c(0x9AA0A6))
					for q in 20:
						_disc(m, Vector3(cx - 0.17 + (q % 10) * 0.038, uy + 0.03 - (q / 10) * 0.06, z + 0.004), 0.011, 0.006, c(BLACK), 6)
				2:                                                                 # монитор и осциллограф
					m.box(Vector3(cx, uy, z), Vector3(0.4, uh - 0.01, 0.008), c(0x3A3F45))
					m.box(Vector3(cx - 0.09, uy, z + 0.006), Vector3(0.19, 0.19, 0.004), c(BLACK))
					_picture(m, Vector3(cx - 0.09, uy, z + 0.01), 0.17, 0.16, hv + u)
					m.box(Vector3(cx + 0.11, uy, z + 0.006), Vector3(0.15, 0.19, 0.004), c(0x10241A))
					for q in 4:
						_line(m, Vector2(cx + 0.05 + q * 0.03, uy - 0.04 + ((q + hv) % 3) * 0.04), Vector2(cx + 0.08 + q * 0.03, uy - 0.04 + ((q + hv + 2) % 3) * 0.04), z + 0.011, c(0x58E878, 0.5), 0.008)
				3:                                                                 # матрица кнопок
					m.box(Vector3(cx, uy, z), Vector3(0.4, uh - 0.01, 0.008), c(0x3A3F45))
					for q in 16:
						var on := (q == (hv + u) % 16) or (q == (hv / 3 + u) % 16)
						m.box(Vector3(cx - 0.165 + (q % 8) * 0.047, uy + 0.03 - (q / 8) * 0.055, z + 0.006), Vector3(0.034, 0.034, 0.006),
							c(0xE8C84A, 0.5) if on else c(0x70787E))
				4:                                                                 # глухая панель с решёткой
					m.box(Vector3(cx, uy, z), Vector3(0.4, uh - 0.01, 0.008), c(BLACK))
					for q in 4:
						m.box(Vector3(cx, uy - 0.06 + q * 0.04, z + 0.006), Vector3(0.32, 0.014, 0.003), c(0x3A3F45))
					m.box(Vector3(cx + 0.17, uy + 0.07, z + 0.006), Vector3(0.02, 0.02, 0.004), c(0x58D878, 0.5))
			y -= uh
	m.box(Vector3(0, 1.92, -0.1), Vector3(0.7, 0.04, 0.2), c(0x70787E))             # кабельный лоток

## Звукорежиссёрский пульт: линейки каналов с фейдерами, стрелочные индикаторы
static func _audiomix(m: Mesher, hv: int) -> void:
	for sx: float in [-0.46, 0.46]:
		m.box(Vector3(sx, 0.36, 0.0), Vector3(0.05, 0.72, 0.8), c(WOOD_D))
	m.box(Vector3(0, 0.4, -0.38), Vector3(0.88, 0.5, 0.03), c(DARK))
	m.box(Vector3(0, 0.72, 0.0), Vector3(0.98, 0.04, 0.86), c(DARK))
	m.box(Vector3(0, 0.76, 0.4), Vector3(0.98, 0.06, 0.08), c(WOOD))                # деревянный подлокотник
	m.push()
	m.translate(Vector3(0, 0.8, -0.02))
	m.rot_x(9)
	m.box(Vector3.ZERO, Vector3(0.94, 0.08, 0.74), c(0x4A5058))
	var knob := [RED, BLUE, 0x58B878, YELLOW]
	for ch in 14:
		var fx := -0.42 + ch * 0.058
		m.box(Vector3(fx + 0.029, 0.041, 0), Vector3(0.003, 0.002, 0.72), c(0x2A2D31))     # граница канала
		for kn in 5:
			_cyl(m, Vector3(fx, 0.04, -0.32 + kn * 0.055), 0.016, 0.014, 0.014, c(knob[kn % 4] if ch < 12 else GREY_L), 6)
		m.box(Vector3(fx, 0.043, -0.03), Vector3(0.03, 0.008, 0.03), c(0xE0483A, 0.5) if (hv >> ch) % 4 == 0 else c(0x70787E))
		m.box(Vector3(fx, 0.042, 0.17), Vector3(0.01, 0.004, 0.3), c(BLACK))        # прорезь фейдера
		m.box(Vector3(fx, 0.05, 0.05 + float((hv >> (ch + 2)) % 6) * 0.045), Vector3(0.036, 0.018, 0.026), c(CREAM if ch < 12 else RED))
	m.pop()
	m.box(Vector3(0, 1.0, -0.36), Vector3(0.94, 0.16, 0.1), c(DARK))                # мост с индикаторами
	for k in 6:
		_vu(m, Vector3(-0.375 + k * 0.15, 1.0, -0.308), 0.13, 0.2 + float((hv >> (k * 2)) % 6) * 0.13)

## Шкаф передатчика: стрелочные приборы, предупреждающий знак
static func _transmitter(m: Mesher, hv: int) -> void:
	var body := 0x5A7086
	m.box(Vector3(0, 0.04, -0.02), Vector3(0.92, 0.08, 0.6), c(BLACK))
	m.box(Vector3(0, 1.04, -0.02), Vector3(0.94, 1.92, 0.62), c(body))
	m.box(Vector3(0, 2.01, -0.02), Vector3(0.96, 0.03, 0.64), c(0x46586A))
	var z := 0.292
	m.box(Vector3(0, 1.72, z), Vector3(0.84, 0.36, 0.008), c(0x46586A))             # панель приборов
	for k in 3:
		var mx := -0.27 + k * 0.27
		m.box(Vector3(mx, 1.72, z + 0.006), Vector3(0.22, 0.24, 0.006), c(BLACK))
		m.box(Vector3(mx, 1.73, z + 0.01), Vector3(0.19, 0.19, 0.004), c(CREAM))
		_ring(m, Vector3(mx, 1.67, z + 0.014), 0.11, 0.012, c(RED), 4, 30.0, 60.0, 0.003)
		_ring(m, Vector3(mx, 1.67, z + 0.014), 0.11, 0.008, c(BLACK), 8, 60.0, 150.0, 0.003)
		var a := deg_to_rad(-40.0 + float((hv >> (k * 3)) % 7) * 12.0)
		_line(m, Vector2(mx, 1.67), Vector2(mx + sin(a) * 0.12, 1.67 + cos(a) * 0.12), z + 0.017, c(BLACK), 0.008)
	for k in 6:                                                                    # лампы и ручки
		m.box(Vector3(-0.3 + k * 0.12, 1.44, z + 0.004), Vector3(0.045, 0.045, 0.01),
			c([0x58D878, 0x58D878, 0xE8C84A, 0x58D878, 0xE0483A, 0x58D878][k], 0.5 if (hv >> k) % 5 != 0 else 1.0))
	for k in 3:
		_disc(m, Vector3(-0.24 + k * 0.24, 1.3, z), 0.045, 0.03, c(BLACK), 10)
		m.box(Vector3(-0.24 + k * 0.24, 1.33, z + 0.031), Vector3(0.008, 0.03, 0.003), c(CREAM))
	m.box(Vector3(0, 0.68, z), Vector3(0.8, 0.96, 0.008), c(0x4E6278))              # дверца
	for k in 8:
		m.box(Vector3(0, 0.3 + k * 0.05, z + 0.006), Vector3(0.6, 0.02, 0.003), c(0x2A3642))
	m.box(Vector3(0.33, 0.8, z + 0.012), Vector3(0.03, 0.14, 0.02), c(CHROME))      # ручка
	m.box(Vector3(-0.1, 0.92, z + 0.006), Vector3(0.3, 0.26, 0.004), c(YELLOW))     # знак «высокое напряжение»
	m.box(Vector3(-0.1, 0.92, z + 0.009), Vector3(0.26, 0.22, 0.003), c(BLACK))
	m.box(Vector3(-0.1, 0.92, z + 0.012), Vector3(0.24, 0.2, 0.003), c(YELLOW))
	_line(m, Vector2(-0.07, 1.0), Vector2(-0.13, 0.92), z + 0.016, c(BLACK), 0.022)
	_line(m, Vector2(-0.13, 0.925), Vector2(-0.07, 0.925), z + 0.016, c(BLACK), 0.022)
	_line(m, Vector2(-0.07, 0.93), Vector2(-0.12, 0.84), z + 0.016, c(BLACK), 0.022)
	m.box(Vector3(0.3, 2.07, 0.1), Vector3(0.1, 0.1, 0.1), c(0xE0281E, 0.5))        # лампа «в эфире»
	_cyl(m, Vector3(-0.28, 2.02, -0.16), 0.3, 0.05, 0.05, c(0x70787E), 8)           # фидер к антенне

## Стеллаж с репортёрской техникой
static func _mediagear(m: Mesher, hv: int) -> void:
	for sx: float in [-0.46, 0.46]:
		for sz: float in [-0.2, 0.2]:
			m.box(Vector3(sx, 1.0, sz), Vector3(0.035, 2.0, 0.035), c(STEEL_D))
	m.box(Vector3(0, 1.0, -0.22), Vector3(0.92, 2.0, 0.01), c(0x6E747A))
	for s in 5:
		m.box(Vector3(0, 0.1 + s * 0.44, 0), Vector3(0.94, 0.03, 0.44), c(STEEL))
	# верх: наплечные видеокамеры
	for k in 2:
		var cxk := -0.22 + k * 0.44
		var cy := 1.86 + 0.015
		m.box(Vector3(cxk, cy + 0.1, -0.02), Vector3(0.16, 0.2, 0.36), c([0x4A5058, 0x3A4F6A][(hv + k) % 2]))
		_cyl_z(m, Vector3(cxk, cy + 0.1, 0.16), 0.12, 0.06, c(BLACK), 8)
		m.box(Vector3(cxk, cy + 0.22, -0.02), Vector3(0.03, 0.04, 0.24), c(BLACK))
		m.box(Vector3(cxk + 0.1, cy + 0.14, 0.06), Vector3(0.05, 0.05, 0.12), c(BLACK))
		m.box(Vector3(cxk - 0.082, cy + 0.1, -0.02), Vector3(0.004, 0.08, 0.2), c([RED, BLUE][(hv + k) % 2]))
	# микрофоны с кубиками канала и зарядные устройства
	var y3 := 1.42 + 0.015
	for k in 5:
		_cyl(m, Vector3(-0.38 + k * 0.1, y3, 0.04), 0.2, 0.018, 0.022, c(DARK), 6)
		m.ellipsoid(Vector3(-0.38 + k * 0.1, y3 + 0.24, 0.04), Vector3(0.032, 0.045, 0.032), c(0x70787E), 3, 6)
		m.box(Vector3(-0.38 + k * 0.1, y3 + 0.16, 0.04), Vector3(0.06, 0.06, 0.06), c([RED, BLUE, YELLOW, RED, 0xF4F6FA][(hv + k) % 5]))
	m.box(Vector3(0.3, y3 + 0.05, 0.0), Vector3(0.26, 0.1, 0.3), c(DARK))
	for k in 4:
		m.box(Vector3(0.21 + k * 0.06, y3 + 0.13, 0.02), Vector3(0.045, 0.1, 0.12), c(BLACK))
		m.box(Vector3(0.21 + k * 0.06, y3 + 0.07, 0.152), Vector3(0.02, 0.02, 0.004), c(0x58D878, 0.5) if (hv >> k) % 3 != 0 else c(0xE0483A, 0.5))
	# фотоаппараты и объективы
	var y2 := 0.98 + 0.015
	for k in 3:
		var px := -0.3 + k * 0.24
		m.box(Vector3(px, y2 + 0.05, 0.0), Vector3(0.15, 0.1, 0.07), c(BLACK))
		m.box(Vector3(px, y2 + 0.11, 0.0), Vector3(0.06, 0.03, 0.05), c(CHROME))
		_cyl_z(m, Vector3(px, y2 + 0.05, 0.035), 0.08 + k * 0.05, 0.042, c(DARK), 8)
	_cyl(m, Vector3(0.36, y2, -0.02), 0.2, 0.05, 0.05, c(BLACK), 8)
	_cyl(m, Vector3(0.36, y2 + 0.2, -0.02), 0.02, 0.055, 0.055, c(CREAM), 8)
	# кабели и лента
	var y1 := 0.54 + 0.015
	for k in 3:
		_ring_h(m, Vector3(-0.28 + k * 0.2, y1 + 0.02 + k * 0.004, 0.0), 0.085, 0.03, 0.035, c([BLACK, 0xD07A30, BLACK][k]), 10)
	for k in 3:
		_cyl(m, Vector3(0.34, y1 + k * 0.05, 0.02), 0.05, 0.06, 0.06, c([0x9AA0A6, BLACK, YELLOW][k]), 10)
	# внизу сумки и сложенный штатив
	m.box(Vector3(-0.2, 0.25, 0.0), Vector3(0.4, 0.26, 0.3), c(0x2A2D31))
	m.box(Vector3(-0.2, 0.39, 0.0), Vector3(0.14, 0.03, 0.04), c(BLACK))
	m.box(Vector3(-0.2, 0.26, 0.152), Vector3(0.2, 0.1, 0.004), c(0x3A3F45))
	for k in 3:
		_cyl_x(m, Vector3(0.06, 0.17 + (k % 2) * 0.05, -0.05 + k * 0.05), 0.36, 0.022, c(BLACK), 6)

## Кофры с аппаратурой
static func _camcases(m: Mesher, hv: int) -> void:
	m.box(Vector3(-0.12, 0.22, -0.04), Vector3(0.6, 0.44, 0.44), c(0x3A3F45))       # большой кофр
	for sx: float in [-0.4, 0.16]:
		for sy: float in [0.03, 0.41]:
			m.box(Vector3(sx, sy, -0.04), Vector3(0.05, 0.06, 0.46), c(CHROME))
	for sz: float in [-0.25, 0.17]:
		for sy2: float in [0.012, 0.428]:
			m.box(Vector3(-0.12, sy2, sz), Vector3(0.62, 0.025, 0.025), c(CHROME))
	m.box(Vector3(-0.12, 0.3, 0.182), Vector3(0.6, 0.012, 0.004), c(CHROME))
	for sx2: float in [-0.3, 0.06]:
		m.box(Vector3(sx2, 0.3, 0.186), Vector3(0.06, 0.07, 0.012), c(CHROME))      # замки
	m.box(Vector3(-0.12, 0.2, 0.19), Vector3(0.14, 0.03, 0.03), c(BLACK))           # ручка
	m.box(Vector3(-0.3, 0.12, 0.182), Vector3(0.16, 0.07, 0.004), c(RED))           # наклейка
	m.box(Vector3(-0.3, 0.12, 0.185), Vector3(0.12, 0.02, 0.003), c(CREAM))
	m.push()                                                                       # малый кофр сверху
	m.translate(Vector3(-0.14, 0.44, -0.04))
	m.rot_y(-12.0 + float(hv % 20))
	m.box(Vector3(0, 0.11, 0), Vector3(0.4, 0.22, 0.3), c(0xB8BCC0))
	m.box(Vector3(0, 0.15, 0.152), Vector3(0.4, 0.01, 0.004), c(STEEL_D))
	for sx3: float in [-0.12, 0.12]:
		m.box(Vector3(sx3, 0.15, 0.156), Vector3(0.05, 0.05, 0.01), c(BLACK))
	m.box(Vector3(0, 0.235, 0), Vector3(0.12, 0.03, 0.03), c(BLACK))
	m.pop()
	m.box(Vector3(0.34, 0.16, 0.14), Vector3(0.24, 0.32, 0.2), c(0xD07A30))         # яркий ударопрочный кейс
	m.box(Vector3(0.34, 0.22, 0.242), Vector3(0.24, 0.01, 0.004), c(BLACK))
	m.box(Vector3(0.34, 0.33, 0.14), Vector3(0.1, 0.03, 0.03), c(BLACK))
	for k in 3:                                                                    # сложенный штатив у стены
		m.push()
		m.translate(Vector3(0.3 + k * 0.045, 0.0, -0.2))
		m.rot_x(-8)
		m.box(Vector3(0, 0.55, 0), Vector3(0.03, 1.1, 0.03), c(BLACK))
		m.pop()
	m.box(Vector3(0.345, 1.08, -0.35), Vector3(0.14, 0.08, 0.1), c(DARK))

# ================== типография ==================
## Печатный станок: рулон бумаги, печатные секции, приёмка готовых газет
static func _printpress(m: Mesher, hv: int, wide: bool) -> void:
	var L := 1.9 if wide else 0.94
	var cx := 0.5 if wide else 0.0
	var x0 := cx - L * 0.5
	var x1 := x0 + L
	var body := 0x4A6A8A
	m.box(Vector3(cx, 0.03, -0.02), Vector3(L, 0.06, 0.74), c(BLACK))
	m.box(Vector3(cx, 0.3, -0.02), Vector3(L - 0.04, 0.5, 0.7), c(0x3A566F))
	for k in 6:                                                                    # полоса безопасности
		var sw := (L - 0.1) / 6.0
		m.box(Vector3(x0 + 0.05 + sw * (k + 0.5), 0.1, 0.332), Vector3(sw, 0.06, 0.006), c(YELLOW if k % 2 == 0 else BLACK))
	# рулон на входе
	var rx := x0 + 0.24
	for sz: float in [-0.32, 0.28]:
		m.box(Vector3(rx, 0.75, sz), Vector3(0.1, 0.44, 0.04), c(body))
	_cyl_z(m, Vector3(rx, 0.86, -0.28), 0.52, 0.2, c(NEWSPRINT), 14)
	_cyl_z(m, Vector3(rx, 0.86, -0.3), 0.56, 0.035, c(STEEL_D), 8)
	var units := [x0 + 0.72, x0 + 1.24] if wide else [x0 + 0.68]
	var prev := Vector2(rx + 0.12, 1.02)
	var ui := 0
	for ux: float in units:                                                        # печатные секции
		m.box(Vector3(ux, 0.98, -0.02), Vector3(0.44, 0.86, 0.72), c(body))
		m.box(Vector3(ux, 1.43, -0.02), Vector3(0.46, 0.04, 0.74), c(0x3A566F))
		m.box(Vector3(ux, 1.0, 0.342), Vector3(0.36, 0.6, 0.006), c(0x5A7A9A))
		for r in 3:
			_cyl_z(m, Vector3(ux - 0.1 + r * 0.1, 1.18 - (r % 2) * 0.16, 0.345), 0.02, 0.07, c(CHROME if r != 1 else BLACK), 10)
		m.box(Vector3(ux + 0.1, 0.78, 0.346), Vector3(0.12, 0.1, 0.006), c(DARK))   # пульт секции
		m.box(Vector3(ux + 0.07, 0.79, 0.35), Vector3(0.03, 0.03, 0.006), c(0x58D878, 0.5))
		m.box(Vector3(ux + 0.13, 0.79, 0.35), Vector3(0.03, 0.03, 0.006), c(RED))
		m.box(Vector3(ux - 0.1, 1.36, 0.346), Vector3(0.1, 0.05, 0.006), c([0x2F5FA8, 0x1B1C1F][ui % 2]))    # цвет краски
		var nxt := Vector2(ux - 0.22, 1.1)
		_web(m, prev, nxt)
		prev = Vector2(ux + 0.22, 1.1)
		ui += 1
	# приёмка: стопка готовых газет
	var dx := x1 - 0.2
	_web(m, prev, Vector2(dx - 0.1, 0.84))
	m.box(Vector3(dx, 0.62, -0.02), Vector3(0.36, 0.14, 0.6), c(body))
	m.box(Vector3(dx, 0.7, -0.02), Vector3(0.38, 0.03, 0.62), c(STEEL))
	var n := 2 + hv % 3
	for k in n:
		m.box(Vector3(dx, 0.73 + k * 0.035, -0.02), Vector3(0.3, 0.034, 0.42), c(NEWSPRINT if k % 2 == 0 else 0xCFCAB8))
	m.box(Vector3(dx - 0.02, 0.716 + n * 0.035, -0.14), Vector3(0.22, 0.002, 0.06), c(BLACK))
	m.box(Vector3(dx + 0.04, 0.716 + n * 0.035, 0.04), Vector3(0.12, 0.002, 0.14), c(0x8A8F96))
	_disc(m, Vector3(x1 - 0.1, 1.0, 0.33), 0.04, 0.03, c(RED), 8)                    # аварийная кнопка

## Бумажное полотно между валами: от a до b (x, y), во всю ширину станка
static func _web(m: Mesher, a: Vector2, b: Vector2) -> void:
	var d := b - a
	m.push()
	m.translate(Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, -0.02))
	m.rot_z(rad_to_deg(atan2(d.y, d.x)))
	m.box(Vector3.ZERO, Vector3(d.length(), 0.006, 0.5), c(NEWSPRINT))
	m.pop()

## Рулоны газетной бумаги
static func _paperrolls(m: Mesher, hv: int) -> void:
	_cyl(m, Vector3(-0.2, 0, -0.06), 0.96, 0.27, 0.27, c(NEWSPRINT), 16)            # стоячий рулон
	_cyl(m, Vector3(-0.2, 0.96, -0.06), 0.004, 0.06, 0.06, c(0x6A5236), 10)
	_cyl(m, Vector3(-0.2, 0.3, -0.06), 0.3, 0.274, 0.274, c(0xB5946A), 16)          # упаковка
	m.box(Vector3(-0.2, 0.44, 0.215), Vector3(0.16, 0.12, 0.006), c(PAPER))
	m.box(Vector3(-0.2, 0.46, 0.219), Vector3(0.1, 0.02, 0.003), c(BLACK))
	_cyl_x(m, Vector3(0.1, 0.2, 0.16), 0.38, 0.2, c(NEWSPRINT if hv % 2 == 0 else 0xCFCAB8), 14)    # лежачий
	_cyl_x(m, Vector3(0.095, 0.2, 0.16), 0.39, 0.045, c(0x6A5236), 8)
	for sz: float in [-0.02, 0.34]:
		m.box(Vector3(0.29, 0.03, sz), Vector3(0.3, 0.06, 0.06), c(0x9A7A52))       # упоры
	_cyl(m, Vector3(0.3, 0, -0.24), 0.5, 0.14, 0.14, c(0xCFCAB8), 12)               # остаток рулона
	_cyl(m, Vector3(0.3, 0.5, -0.24), 0.004, 0.05, 0.05, c(0x6A5236), 8)

## Резак для бумаги
static func _cutter(m: Mesher) -> void:
	var body := 0x4F6A5A
	m.box(Vector3(0, 0.03, -0.02), Vector3(0.8, 0.06, 0.6), c(BLACK))
	m.box(Vector3(0, 0.42, -0.02), Vector3(0.76, 0.72, 0.56), c(body))
	m.box(Vector3(0, 0.42, 0.262), Vector3(0.5, 0.4, 0.006), c(0x3F564A))
	m.box(Vector3(0, 0.81, -0.02), Vector3(0.94, 0.06, 0.74), c(STEEL))             # стол
	for sx: float in [-0.4, 0.4]:
		m.box(Vector3(sx, 1.12, -0.06), Vector3(0.1, 0.56, 0.2), c(body))
	m.box(Vector3(0, 1.44, -0.06), Vector3(0.92, 0.14, 0.22), c(body))
	m.box(Vector3(0, 1.2, -0.02), Vector3(0.7, 0.22, 0.02), c(CHROME))              # нож
	m.box(Vector3(0, 1.08, -0.02), Vector3(0.7, 0.03, 0.012), c(0xE8EAEC))
	m.box(Vector3(0, 0.95, -0.1), Vector3(0.7, 0.06, 0.1), c(DARK))                 # прижим
	m.box(Vector3(0, 0.89, 0.02), Vector3(0.44, 0.1, 0.5), c(PAPER))                # стопа бумаги
	for k in 4:
		m.box(Vector3(0, 0.86 + k * 0.022, 0.271), Vector3(0.44, 0.003, 0.002), c(0xC8C4BC))
	m.box(Vector3(0.34, 0.85, 0.24), Vector3(0.1, 0.02, 0.2), c(PAPER))             # обрезки
	m.box(Vector3(0.36, 0.865, 0.2), Vector3(0.08, 0.01, 0.16), c(0xE8E6DC))
	m.box(Vector3(0, 0.86, -0.3), Vector3(0.6, 0.06, 0.03), c(STEEL_D))             # задний упор
	m.push()                                                                       # рычаг
	m.translate(Vector3(0.32, 1.5, -0.06))
	m.rot_z(-18)
	m.box(Vector3(0.0, 0.18, 0), Vector3(0.03, 0.4, 0.03), c(STEEL_D))
	m.ellipsoid(Vector3(0, 0.4, 0), Vector3(0.04, 0.04, 0.04), c(RED), 3, 6)
	m.pop()
	_disc(m, Vector3(-0.2, 0.5, 0.265), 0.1, 0.02, c(BLACK), 12)                    # маховик упора
	_disc(m, Vector3(-0.2, 0.5, 0.285), 0.03, 0.02, c(CHROME), 8)
	for k in 5:
		m.box(Vector3(-0.38 + k * 0.19, 0.775, 0.352), Vector3(0.095, 0.03, 0.004), c(YELLOW if k % 2 == 0 else BLACK))
	m.box(Vector3(0.28, 1.44, 0.052), Vector3(0.12, 0.06, 0.006), c(YELLOW))        # табличка «осторожно»
