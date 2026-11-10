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
const WATER := 22              # вода (с 0.40): не пройти, кроме моста-линии над ней
# мебель военной части (модели — scripts/mil_furniture.gd)
const BUNK := 23               # двухъярусная койка: две клетки подряд вдоль стены — одна длинная койка
const FOOTLOCKER := 24         # армейский сундук
const GUNRACK := 25            # оружейная пирамида
const GUNSAFE := 26            # оружейный шкаф
const AMMO := 27               # ящики с боеприпасами
const MILLOCKER := 28          # армейский шкаф
const RADIO := 29              # стол связи с радиостанцией
const MAPTABLE := 30           # штабной стол с картой: две клетки подряд — один длинный стол
const FILECAB := 31            # картотечные шкафы
const MILDESK := 32            # стол дежурного
const GEARSHELF := 33          # стеллаж со снаряжением
const MAPBOARD := 34           # стенд с тактической картой
# мебель столовой — нейтральная: годится и для полиции, и для больницы (модели — scripts/canteen_furniture.gd)
const DINETABLE := 35          # обеденный стол: две клетки подряд — один длинный; может стоять посреди комнаты
const CHAIR := 36              # пара стульев: у стола сами поворачиваются к нему, у стены — спинкой к стене
const BENCH := 37              # скамья: у стола встаёт вдоль него, клетки подряд — одна длинная
const SERVELINE := 38          # линия раздачи: клетки подряд — одна длинная
const TRAYSTAND := 39          # стойка с подносами и приборами
const WATERCOOLER := 40        # кулер с водой и урна
const STEELTABLE := 41         # стол из нержавейки (кухня)
const SINK := 42               # двойная мойка
const DISHRACK := 43           # стеллаж-тележка для грязной посуды
const KITCHENETTE := 44        # тумба с микроволновкой, чайником и кофеваркой
const PLANT := 45              # растение в кадке
const NOTICEBOARD := 46        # доска объявлений
# мебель полицейского участка (модели — scripts/police_furniture.gd)
const FRONTDESK := 47          # стойка дежурного: клетки подряд — одна длинная; кресло ставится с рабочей стороны
const WANTEDBOARD := 48        # доска «Разыскиваются»
const PDESK := 49              # рабочий стол с компьютером или пишущей машинкой
const OFFICECHAIR := 50        # офисное кресло: у стола само поворачивается к нему
const COPIER := 51             # копировальный аппарат
const FAXSTAND := 52           # тумба с факсом и принтером
const EVIDENCESHELF := 53      # стеллаж с вещдоками
const CASEBOARD := 54          # доска расследования
const INTERROTABLE := 55       # стол для допросной: две клетки подряд — один длинный
const CELLBARS := 56           # решётка камеры: встаёт вдоль ряда решёток и стен, клетка непроходима
const CELLDOOR := 57           # дверь камеры (решётчатая, закрыта; не открывается)
const CELLBUNK := 58           # нары: две клетки подряд вдоль стены
const CELLTOILET := 59         # унитаз с раковиной из нержавейки
const RIOTRACK := 60           # стойка со спецснаряжением
const MUGSHOT := 61            # ростомер
const BOOKING := 62            # стойка оформления задержанных
const DISPATCH := 63           # пульт диспетчера
const FLAGSTAND := 64          # флаг на стойке
const CHIEFDESK := 65          # стол начальника: две клетки подряд — один большой
const SOFA := 66               # диван: две клетки подряд; одна — кресло
const PAYPHONE := 67           # телефон-автомат
const BRIEFBOARD := 68         # доска для инструктажа
const PODIUM := 69             # трибуна: эмблемой — туда, где больше свободного пола
# мебель больницы (модели — scripts/hospital_furniture.gd)
const RECEPTION := 70          # стойка регистратуры: клетки подряд — одна длинная; кресло — с рабочей стороны
const WHEELCHAIR := 71         # кресло-каталка
const DIRECTORY := 72          # указатель отделений
const MAGTABLE := 73           # журнальный столик
const VENDING := 74            # автомат с закусками
const GURNEY := 75             # каталка: две клетки подряд — одна длинная
const HOSPBED := 76            # больничная койка: две клетки вдоль стены или изголовьем к стене (вторая клетка — перед первой)
const BEDSIDE := 77            # прикроватная тумба
const IVSTAND := 78            # стойка капельницы
const SCREEN := 79             # ширма: клетки подряд — одна длинная; клетка непроходима, взгляд закрывает
const PATMONITOR := 80         # монитор пациента
const OPTABLE := 81            # операционный стол: две клетки подряд
const SURGLIGHT := 82          # операционный светильник: плафоном к столу рядом; клетка занята целиком
const ANESTHESIA := 83         # наркозный аппарат
const INSTRTABLE := 84         # инструментальный столик
const SCRUBSINK := 85          # хирургическая мойка
const XRAYVIEW := 86           # негатоскоп со снимками
const STERILIZER := 87         # стерилизатор
const DEFIB := 88              # тележка с дефибриллятором
const OXYGEN := 89             # баллоны с кислородом
const BIOBINS := 90            # контейнеры для медицинских отходов
const SURGCAB := 91            # шкаф с инструментами
const EXAMTABLE := 92          # смотровая кушетка: две клетки подряд
const SCALE := 93              # весы с ростомером
const MEDCART := 94            # процедурная тележка
const MEDSHELF := 95           # стеллаж с медикаментами
const MEDFRIDGE := 96          # холодильник для лекарств
const SUPPLYBOXES := 97        # коробки с расходниками
const NARCSAFE := 98           # сейф для сильнодействующих препаратов
const BOOKCASE := 99           # книжный шкаф
const DIPLOMAS := 100          # дипломы в рамках
const SKELETON := 101          # анатомический скелет
const CONFTABLE := 102         # стол для совещаний: клетки подряд — один длинный
const PROJSCREEN := 103        # экран для проектора
const OHPROJECTOR := 104       # кодоскоп на тележке
const WHITEBOARD := 105        # маркерная доска
const COATRACK := 106          # вешалка с халатами
const TVSTAND := 107           # телевизор на тумбе
const CHARTRACK := 108         # стойка с историями болезни
const LABBENCH := 109          # лабораторный стол
const MORGUE := 110            # холодильные камеры морга

const DX4 := [1, -1, 0, 0]
const DY4 := [0, 0, 1, -1]

static func is_furniture(t: int) -> bool: return (t >= FRIDGE and t <= STORESHELF) or (t >= BUNK and t <= MORGUE)
## Низкая мебель: поверх неё видно (как стойка)
static func is_low_furniture(t: int) -> bool:
	return t == COUNTER or t == FOOTLOCKER or t == AMMO or t == RADIO or t == MAPTABLE or t == MILDESK \
		or (t >= DINETABLE and t <= NOTICEBOARD and t != DISHRACK) \
		or (t >= FRONTDESK and t <= PODIUM and t != EVIDENCESHELF and t != RIOTRACK) \
		or (t >= RECEPTION and t <= MORGUE and t != VENDING and t != SCREEN and t != SURGCAB and t != MEDSHELF \
			and t != MEDFRIDGE and t != BOOKCASE and t != MORGUE)
## Мебель на две клетки: соседние клетки одного вида вдоль стены сливаются в один длинный предмет
static func is_wide_furniture(t: int) -> bool:
	return t == BUNK or t == MAPTABLE or t == DINETABLE or t == INTERROTABLE or t == CELLBUNK or t == CHIEFDESK or t == SOFA \
		or t == GURNEY or t == HOSPBED or t == OPTABLE or t == EXAMTABLE or t == CONFTABLE
## Сиденья: рядом со столом встают к нему (а не к стене)
static func is_seat(t: int) -> bool: return t == CHAIR or t == BENCH or t == OFFICECHAIR
static func is_table(t: int) -> bool:
	return t == DINETABLE or t == MAPTABLE or t == PDESK or t == INTERROTABLE or t == CHIEFDESK or t == FRONTDESK or t == DISPATCH \
		or t == RECEPTION or t == CONFTABLE
## Стойки (дежурного, регистратуры): вся линия смотрит рабочей стороной в одну сторону
static func is_counter(t: int) -> bool: return t == FRONTDESK or t == RECEPTION
## Ширмы: стоят по линии, как решётки
static func is_screen(t: int) -> bool: return t == SCREEN
## То, у чего лежит пациент: приборы посреди комнаты поворачиваются к нему лицом
static func is_patient_bed(t: int) -> bool: return t == HOSPBED or t == GURNEY or t == OPTABLE or t == EXAMTABLE
## Решётки камер: стоят по линии, а не у стены
static func is_bars(t: int) -> bool: return t == CELLBARS or t == CELLDOOR
## Мебель, которая к стене не прижимается и занимает всю клетку
static func is_freestanding(t: int) -> bool: return t == CELLBARS or t == CELLDOOR or t == PODIUM or t == SCREEN or t == SURGLIGHT
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
var lines: Array = []      # дороги-линии: [вид, x0, y0, x1, y1, …] — точки; игра строит по ним кривую с дугами на углах (с 0.38, дуги — 0.44)

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

static func opaque_tile(tt: int) -> bool:
	return tt == WALL or tt == DOOR or (is_furniture(tt) and not is_low_furniture(tt))

func opaque(x: int, y: int) -> bool:
	return opaque_tile(t(x, y))

## Мебель у стены стоит к ней вплотную (world_mesh._furniture), её лицевая сторона — на столько метров
## от центра клетки в сторону комнаты. Столкновение — от задней кромки клетки до лица, а не вся клетка:
## иначе перед шкафом была невидимая стена до полуметра (BF-066). Меняешь модель или сдвиг — поправь и тут
const FURN_FRONT := {FRIDGE: -0.19, COUNTER: -0.12, WARDROBE: -0.30, SHELF: -0.47, MEDCAB: -0.51, LOCKER: -0.37, STORESHELF: -0.04,
	BUNK: 0.05, FOOTLOCKER: -0.39, GUNRACK: -0.49, GUNSAFE: -0.32, AMMO: -0.24, MILLOCKER: -0.34, RADIO: -0.26, MAPTABLE: -0.01,
	FILECAB: -0.24, MILDESK: -0.21, GEARSHELF: -0.37, MAPBOARD: -0.5,      # стенд целиком в зазоре у стены: клетка перед ним свободна
	DINETABLE: -0.01, CHAIR: -0.46, BENCH: -0.5, SERVELINE: -0.05, TRAYSTAND: -0.34, WATERCOOLER: -0.43, STEELTABLE: -0.22, SINK: -0.23,
	DISHRACK: -0.30, KITCHENETTE: -0.26, PLANT: -0.29, NOTICEBOARD: -0.5,      # скамья и доска у стены — целиком в зазоре
	# полиция: доски, ростомер, телефон и флаг у стены — в зазоре; решётки и трибуна занимают клетку целиком
	FRONTDESK: -0.13, WANTEDBOARD: -0.5, PDESK: -0.02, OFFICECHAIR: -0.3, COPIER: -0.24, FAXSTAND: -0.34,
	EVIDENCESHELF: -0.39, CASEBOARD: -0.5, INTERROTABLE: -0.09, CELLBARS: 0.5, CELLDOOR: 0.5, CELLBUNK: -0.16,
	CELLTOILET: -0.19, RIOTRACK: -0.42, MUGSHOT: -0.5, BOOKING: -0.34, DISPATCH: -0.02, FLAGSTAND: -0.5,
	CHIEFDESK: -0.02, SOFA: -0.08, PAYPHONE: -0.5, BRIEFBOARD: -0.5, PODIUM: 0.5,
	# больница: указатель, негатоскоп, доски, экран и баллоны у стены — в зазоре; ширма и светильник занимают клетку целиком
	RECEPTION: 0.02, WHEELCHAIR: -0.02, DIRECTORY: -0.5, MAGTABLE: -0.32, VENDING: -0.15, GURNEY: -0.15, HOSPBED: 0.04,
	BEDSIDE: -0.40, IVSTAND: -0.44, SCREEN: 0.5, PATMONITOR: -0.48, OPTABLE: -0.12, SURGLIGHT: 0.5, ANESTHESIA: -0.12,
	INSTRTABLE: -0.34, SCRUBSINK: -0.35, XRAYVIEW: -0.5, STERILIZER: -0.25, DEFIB: -0.38, OXYGEN: -0.5, BIOBINS: -0.46,
	SURGCAB: -0.42, EXAMTABLE: -0.24, SCALE: -0.34, MEDCART: -0.42, MEDSHELF: -0.40, MEDFRIDGE: -0.18, SUPPLYBOXES: -0.35,
	NARCSAFE: -0.34, BOOKCASE: -0.44, DIPLOMAS: -0.5, SKELETON: -0.48, CONFTABLE: 0.02, PROJSCREEN: -0.5, OHPROJECTOR: -0.42,
	WHITEBOARD: -0.5, COATRACK: -0.46, TVSTAND: -0.36, CHARTRACK: -0.42, LABBENCH: -0.22, MORGUE: -0.02}
## То же для сидений, придвинутых к столу: дальний от стола край сиденья (от центра клетки, в сторону от стола)
const SEAT_FRONT := {CHAIR: -0.175, BENCH: -0.18, OFFICECHAIR: -0.10}

## Сиденье в клетке придвинуто к столу (k — furniture_dir этой клетки)
func seat_at_table(x: int, y: int, k: int) -> bool:
	return k >= 0 and is_seat(t(x, y)) and is_table(t(x - DX4[k], y - DY4[k]))

## На сколько сиденье (в клетке x, y; k — его furniture_dir) задвигается за границу клетки стола. Стол посреди
## комнаты доходит до границы — 0; стол у стены прижат к ней, его лицо почти в середине клетки — кресло
## заезжает к нему (и стоит уже в клетке стола)
func seat_slide(x: int, y: int, k: int) -> float:
	var tx: int = x - DX4[k]
	var ty: int = y - DY4[k]
	if furniture_dir(tx, ty) != k:
		return 0.0
	return maxf(0.5 - float(FURN_FRONT.get(t(tx, ty), 0.5)), 0.0)

## Лицо мебели в клетке для столкновения (см. FURN_FRONT), k — её furniture_dir
func furniture_front(x: int, y: int, k: int) -> float:
	var tt := t(x, y)
	if seat_at_table(x, y, k):
		return float(SEAT_FRONT[tt]) - seat_slide(x, y, k)
	if k >= 0 and is_table(tt):
		# стол у стены, к которому придвинуто сиденье: оно стоит в его клетке — клетка занята целиком
		var sx: int = x + DX4[k]
		var sy: int = y + DY4[k]
		if is_seat(t(sx, sy)) and furniture_dir(sx, sy) == k:
			return 0.5
	if tt == HOSPBED and bed_deep(x, y)[0] == 1:
		return 0.5                     # койка изголовьем к стене занимает обе свои клетки целиком
	return float(FURN_FRONT.get(tt, 0.0))

## Койка изголовьем к стене (HOSPBED): за клеткой стена, а перед ней — ещё одна клетка койки. Тогда это одна
## койка на две клетки, вытянутая от стены в комнату. Куда тянется койка из клетки-изголовья; -1 — не изголовье
func _bed_head_k(x: int, y: int) -> int:
	if t(x, y) != HOSPBED:
		return -1
	for k in 4:
		if wall_like(t(x - DX4[k], y - DY4[k])) and t(x + DX4[k], y + DY4[k]) == HOSPBED:
			return k
	return -1

## Клетка — изножье такой койки: направление койки или -1. Спорные случаи (две клетки между двух стен)
## решаются порядком направлений, чтобы у клетки был один хозяин
func _bed_foot_k(x: int, y: int) -> int:
	if t(x, y) != HOSPBED:
		return -1
	var own := _bed_head_k(x, y)
	for k in 4:
		if _bed_head_k(x - DX4[k], y - DY4[k]) == k and (own < 0 or k < own):
			return k
	return -1

## [роль, направление]: 1 — изголовье (рисует всю койку), 2 — изножье (ничего не рисует), 0 — обычная клетка
func bed_deep(x: int, y: int) -> Array:
	var fk := _bed_foot_k(x, y)
	if fk >= 0:
		return [2, fk]
	var hk := _bed_head_k(x, y)
	if hk >= 0 and _bed_foot_k(x + DX4[hk], y + DY4[hk]) == hk:
		return [1, hk]
	return [0, -1]

## Клетка годится в пару длинной мебели вида tt с направлением k
func _wide_mate(x: int, y: int, tt: int, k: int) -> bool:
	return t(x, y) == tt and furniture_dir(x, y) == k and (tt != HOSPBED or bed_deep(x, y)[0] == 0)

## Длинная мебель (is_wide_furniture): [половина, шаг «вправо» по x, по y]. Половина: 0 — одиночная (пары нет),
## 1 — левая (рисует весь предмет на две клетки), 2 — правая (ничего не рисует). У стены пары считаются подряд
## вдоль неё, слева направо, если смотреть на мебель с лица (направление furniture_dir у пары общее). Посреди
## комнаты — подряд с запада на восток, а если соседей по этой оси нет — с севера на юг
func furniture_wide(x: int, y: int) -> Array:
	var tt := t(x, y)
	if not is_wide_furniture(tt) or (tt == HOSPBED and bed_deep(x, y)[0] != 0):
		return [0, 1, 0]
	var k := furniture_dir(x, y)
	var axes := [[DY4[k], -DX4[k]]] if k >= 0 else [[1, 0], [0, 1]]
	for a in axes:
		var ax: int = a[0]
		var ay: int = a[1]
		var n := 0                     # сколько таких же подряд слева
		while _wide_mate(x - ax * (n + 1), y - ay * (n + 1), tt, k):
			n += 1
		if n % 2 == 1:
			return [2, ax, ay]
		if _wide_mate(x + ax, y + ay, tt, k):
			return [1, ax, ay]
	return [0, 1, 0]

func furniture_half(x: int, y: int) -> int:
	return furniture_wide(x, y)[0]

## Куда смотрит мебель в клетке: индекс в DX4/DY4 (спиной к стене, лицом в комнату; из нескольких стен —
## та, напротив которой пол, и лучше глухая). -1 — у стены не стоит (тогда без сдвига, занимает всю клетку)
func furniture_dir(x: int, y: int) -> int:
	var best := -1
	var dir := -1
	if is_freestanding(t(x, y)):
		return -1
	if t(x, y) == HOSPBED:
		var bd := bed_deep(x, y)
		if bd[0] != 0:
			return bd[1] if bd[0] == 1 else -1     # изножье у стены не стоит — клетка занята целиком
	if is_seat(t(x, y)):               # сиденье у стола — спиной от стола (стол важнее стены)
		for k in 4:
			if is_table(t(x - DX4[k], y - DY4[k])):
				return k
	for k in 4:
		var bt := t(x - DX4[k], y - DY4[k])
		if wall_like(bt):
			var score := (2 if is_floor(t(x + DX4[k], y + DY4[k])) else 0) + (1 if bt == WALL else 0)
			if score > best:
				best = score
				dir = k
	return dir

func circle_blocked(cx: float, cy: float, r: float) -> bool:
	if not (is_finite(cx) and is_finite(cy)):
		return true          # нечисловая точка — «занято»: иначе все сравнения ниже ложны и пропускают (BF-028)
	var x0 := floori(cx - r)
	var x1 := floori(cx + r)
	var y0 := floori(cy - r)
	var y1 := floori(cy + r)
	if has_water and _water_blocks(cx, cy, r):
		return true
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if not solid(x, y):
				var pc: Array = prop_cols.get(y * w + x, []) if inside(x, y) else []
				for c: Vector3 in pc:
					if Vector2(cx - c.x, cy - c.y).length_squared() < (r + c.z) * (r + c.z):
						return true
				continue
			var rx0 := float(x)
			var rx1 := x + 1.0
			var ry0 := float(y)
			var ry1 := y + 1.0
			var tt: int = tiles[y * w + x] if inside(x, y) else WALL
			if is_furniture(tt):
				var k := furniture_dir(x, y)
				if k >= 0:
					var depth: float = maxf(0.5 + furniture_front(x, y, k), 0.0)
					match k:
						0: rx1 = x + depth
						1: rx0 = x + 1.0 - depth
						2: ry1 = y + depth
						3: ry0 = y + 1.0 - depth
			var nx := clampf(cx, rx0, rx1)
			var ny := clampf(cy, ry0, ry1)
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

var buildings_runs := 0          # сколько раз пересчитаны дома (проверка: кисть по земле их не пересчитывает)

func compute_buildings() -> void:
	buildings_runs += 1
	# быстро: таблица «клетка дома» вместо вызова функции на каждую клетку, соседи — по номеру клетки
	# (на 500×500 в редакторе это считается после каждой правки стен; BF-055)
	var bt := PackedByteArray()
	bt.resize(256)
	for k in 256:
		bt[k] = 1 if _is_building_tile(k) else 0
	buildings.clear()
	building_of.fill(-1)
	var q := PackedInt32Array()
	q.resize(w * h)
	var n := w * h
	for start in n:
		if bt[tiles[start]] == 0 or building_of[start] >= 0:
			continue
		var id := buildings.size()
		var x0 := w
		var y0 := h
		var x1 := 0
		var y1 := 0
		var head := 0
		var tail := 1
		q[0] = start
		building_of[start] = id
		while head < tail:
			var i: int = q[head]
			head += 1
			var x := i % w
			var y := i / w
			if x < x0: x0 = x
			if x > x1: x1 = x
			if y < y0: y0 = y
			if y > y1: y1 = y
			if x + 1 < w and building_of[i + 1] < 0 and bt[tiles[i + 1]] == 1:
				building_of[i + 1] = id
				q[tail] = i + 1
				tail += 1
			if x > 0 and building_of[i - 1] < 0 and bt[tiles[i - 1]] == 1:
				building_of[i - 1] = id
				q[tail] = i - 1
				tail += 1
			if y + 1 < h and building_of[i + w] < 0 and bt[tiles[i + w]] == 1:
				building_of[i + w] = id
				q[tail] = i + w
				tail += 1
			if y > 0 and building_of[i - w] < 0 and bt[tiles[i - w]] == 1:
				building_of[i - w] = id
				q[tail] = i - w
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
const MAP_CHARS := ".=-wt#DdO?T!FCWSMLRcvx~bkgGalrmfqeBnhjsyuzipoPN0123456789AEHIJKQUVXYZ+абвгдежзийклмнопрстуфхцчшщъыьэюяАБВГДЕЖЗИ"  # символ = номер клетки (9 и 11 — старые, на карте недопустимы; ~ вода — 0.40)
const MAX_SIDE := 500           # клеток по стороне (1 клетка ≈ 1 м); 500×500 проверено тестом test_big_map
const PROP_CHUNK := 10          # = WorldMesh.CHUNK: объекты разложены по кускам графики (props_chunk)
const MAX_PROPS := 20000
const Props = preload("res://scripts/props.gd")
## Дороги-линии. Ширина: асфальт (половина) и вся полоса с тротуарами/обочинами (половина), метры
const LINE_KINDS := ["street", "highway", "bridge"]
const LINE_ROAD_HW := {"street": 3.0, "highway": 6.0, "bridge": 3.0}
const LINE_OUTER_HW := {"street": 5.0, "highway": 7.5, "bridge": 4.0}
const BRIDGE_RAIL := 0.15       # перила моста: столько от края настила не пройти
const MAX_LINES := 2000
const MAX_LINE_PTS := 64
const LINE_STEP := 1.0          # шаг сглаженной кривой, м

## Откуда читать карту: игра — MAP_PATH; автотесты (--audit) подменяют на тестовый город TEST_MAP_PATH (с 0.45:
## карта игры — чистая, а тестам нужны дома, двери, окна, фонари)
const TEST_MAP_PATH := "res://scripts/server_only/test_city.json"
static var map_path := MAP_PATH

static func read_map_file() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(map_path))
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
	var nl := []
	var ln = d.get("lines", [])
	if not (ln is Array) or ln.size() > MAX_LINES:
		return "неверный список дорог"
	for e in ln:
		if not (e is Array) or e.size() < 5 or e.size() % 2 == 0 or (e.size() - 1) / 2 > MAX_LINE_PTS \
				or not (e[0] is String) or not LINE_KINDS.has(e[0]):
			return "неверная дорога %s" % [e]
		var le := [str(e[0])]
		for k in range(1, e.size()):
			var v := float(e[k])
			if not is_finite(v) or v < 0.0 or v > (nw if k % 2 == 1 else nh):
				return "дорога %s за краем карты" % [e]
			le.append(v)
		nl.append(le)
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
	lines = nl
	spawn = spv
	compute_buildings()
	index_props()
	index_lines()
	has_water = tiles.has(WATER)
	compute_water_depth()
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
	var ln := []
	for e in lines:
		if e.size() < 5:
			continue             # дорога из одной точки (её только начали рисовать в редакторе) — не в файл
		var le := [e[0]]
		for k in range(1, e.size()):
			le.append(snappedf(e[k], 0.01))
		ln.append(le)
	return {"v": 1, "w": w, "h": h, "spawn": [snappedf(spawn.x, 0.01), snappedf(spawn.y, 0.01)], "rows": rows, "props": pr, "lines": ln}

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
	var ln: Array = d.get("lines", [])
	if ln.is_empty():
		return out + "]}\n"         # карта без дорог-линий — тот же файл, что до 0.38
	out += "],\n\"lines\": [\n"
	for i in ln.size():
		out += JSON.stringify(ln[i]) + ("," if i < ln.size() - 1 else "") + "\n"
	return out + "]}\n"

## Круги столкновений объектов разложить по клеткам (после загрузки карты и правок в редакторе)
var props_chunk := {}          # Vector2i(кусок) → объекты в нём: кусок графики не перебирает все объекты карты (BF-052)

func index_props() -> void:
	prop_cols.clear()
	props_chunk.clear()
	for e in props:
		var ck := Vector2i(int(e[1]) / PROP_CHUNK, int(e[2]) / PROP_CHUNK)
		if props_chunk.has(ck):
			props_chunk[ck].append(e)
		else:
			props_chunk[ck] = [e]
		for c: Vector3 in Props.colliders(e):
			for y in range(floori(c.y - c.z), floori(c.y + c.z) + 1):
				for x in range(floori(c.x - c.z), floori(c.x + c.z) + 1):
					if inside(x, y):
						var i := y * w + x
						if not prop_cols.has(i):
							prop_cols[i] = []
						prop_cols[i].append(c)

# ================== ДОРОГИ-ЛИНИИ ==================
## Скругление углов (с 0.44, BF-058): желаемый радиус дуги на углу и наименьший допустимый, м (по оси дороги).
## Меньше наименьшего — дорога на повороте наезжает сама на себя; редактор такую точку не ставит
const LINE_TURN_R := {"street": 10.0, "highway": 25.0, "bridge": 15.0}
const LINE_MIN_R := {"street": 5.0, "highway": 10.0, "bridge": 6.0}

## Опорные точки линии без повторов подряд
static func line_points(e: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(1, e.size() - 1, 2):
		var p := Vector2(e[k], e[k + 1])
		if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.01:
			pts.append(p)
	return pts

## Углы ломаной: [[вершина, направление до, направление после, отступ дуги T, радиус дуги]] по каждой внутренней точке.
## Отступ T = радиус · tg(поворот/2), но не больше половины соседних отрезков (крайний отрезок — целиком):
## на коротких отрезках дуга меньше желаемой
static func line_corners(e: Array) -> Array:
	var pts := line_points(e)
	var out := []
	var n := pts.size()
	for i in range(1, n - 1):
		var l1 := pts[i].distance_to(pts[i - 1])
		var l2 := pts[i + 1].distance_to(pts[i])
		var d1 := (pts[i] - pts[i - 1]) / l1
		var d2 := (pts[i + 1] - pts[i]) / l2
		var th := absf(d1.angle_to(d2))
		if th < 0.01:
			out.append([pts[i], d1, d2, 0.0, INF])
			continue
		var tn := tan(minf(th, PI - 0.02) * 0.5)
		var lim := minf(l1 if i == 1 else l1 * 0.5, l2 if i == n - 2 else l2 * 0.5)
		var t := minf(float(LINE_TURN_R[e[0]]) * tn, lim)
		out.append([pts[i], d1, d2, t, t / tn])
	return out

## Радиусы дуг на углах (по порядку точек); INF — угла нет
static func line_corner_radii(e: Array) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	for c in line_corners(e):
		r.append(c[4])
	return r

## Кривая линии: прямые между точками, углы скруглены дугами (line_corners), шаг ≤ LINE_STEP.
## Проходит через первую и последнюю точку; внутренние точки — вершины углов (дорога срезает угол дугой)
static func line_path(e: Array) -> PackedVector2Array:
	var pts := line_points(e)
	var out := PackedVector2Array()
	if pts.size() < 2:
		return out
	out.append(pts[0])
	var cur := pts[0]
	for c in line_corners(e):
		var v: Vector2 = c[0]
		var d1: Vector2 = c[1]
		var d2: Vector2 = c[2]
		var t: float = c[3]
		var a := v - d1 * t
		_path_line(out, cur, a)
		if t > 0.0:
			var sd := signf(d1.cross(d2))
			var r: float = c[4]
			var ctr := a + Vector2(-d1.y, d1.x) * sd * r
			var a0 := (a - ctr).angle()
			var sweep := d1.angle_to(d2)
			var k := maxi(maxi(1, ceili(absf(sweep) * r / LINE_STEP)), ceili(absf(sweep) / 0.2))
			for j in range(1, k + 1):
				out.append(ctr + Vector2.from_angle(a0 + sweep * j / k) * r)
			cur = out[out.size() - 1]
		else:
			cur = a
	_path_line(out, cur, pts[pts.size() - 1])
	return out

## Прямая от a до b шагами ≤ LINE_STEP (a уже в пути)
static func _path_line(out: PackedVector2Array, a: Vector2, b: Vector2) -> void:
	var d := a.distance_to(b)
	if d < 0.01:
		return
	var k := maxi(1, ceili(d / LINE_STEP))
	for j in range(1, k + 1):
		out.append(a.lerp(b, float(j) / k))

## Куски кривых по кускам графики: Vector2i → [[вид, A, B, нормаль куска, она же, путь до A, до B, номер линии,
## нормаль предыдущего куска или null]]
var lines_chunk := {}
## Перекрёстки (с 0.44): кусок графики → [[точка, линия A, путь A, направление A, линия B, путь B, направление B]]
## — где оси двух дорог (или одной в петле) пересекаются под углом больше ~20°. Стык конец-в-конец — не перекрёсток
var lines_junc := {}
var line_len := PackedFloat32Array()   # длина каждой линии по пути (с продлёнными концами), м
var line_junc := {}                    # номер линии → её перекрёстки (те же записи, что в lines_junc)

func index_lines() -> void:
	lines_chunk.clear()
	lines_junc.clear()
	line_junc.clear()
	line_len.resize(lines.size())
	line_len.fill(0.0)
	for li in lines.size():
		var e: Array = lines[li]
		var path := line_path(e)
		if path.size() < 2:
			continue
		# концы чуть дальше точек (0.3 м): у двух дорог, сходящихся под углом, на стыке не видно щели с травой
		var t0 := (path[0] - path[1]).normalized()
		var t1 := (path[path.size() - 1] - path[path.size() - 2]).normalized()
		path.insert(0, path[0] + t0 * 0.3)
		path.append(path[path.size() - 1] + t1 * 0.3)
		var s := 0.0
		var prev_n = null
		for i in path.size() - 1:
			var a := path[i]
			var b := path[i + 1]
			var ds := a.distance_to(b)
			if ds < 1e-4:
				continue
			# нормаль самого куска (прямоугольник не выворачивается) и нормаль предыдущего — для клина на стыке
			var n := Vector2(a.y - b.y, b.x - a.x) / ds
			var mid := (a + b) * 0.5
			var ck := Vector2i(floori(mid.x) / PROP_CHUNK, floori(mid.y) / PROP_CHUNK)
			var rec := [e[0], a, b, n, n, s, s + ds, li, prev_n]
			prev_n = n
			if lines_chunk.has(ck):
				lines_chunk[ck].append(rec)
			else:
				lines_chunk[ck] = [rec]
			s += ds
		line_len[li] = s
	_find_junctions()

const JUNC_MIN_SIN := 0.34      # пересечение положе ~20° — не перекрёсток (разметки на нём не рисуем)

## Пересечения осей: куски разложены по сетке 2 м (кусок ≤ ~1 м — пересекающиеся куски в той же или соседней
## клетке); сравниваются клетка с собой и с половиной соседей — каждая пара один раз. 300 линий — десятки мс
const JUNC_CELL := 2.0

func _find_junctions() -> void:
	var grid := {}
	for ck in lines_chunk:
		for r in lines_chunk[ck]:
			var mid: Vector2 = ((r[1] as Vector2) + (r[2] as Vector2)) * 0.5
			var key := floori(mid.x / JUNC_CELL) * 4096 + floori(mid.y / JUNC_CELL)
			if grid.has(key):
				grid[key].append(r)
			else:
				grid[key] = [r]
	var offs := [0, 4096, 4096 + 1, 1, -4096 + 1]
	for key in grid:
		var A: Array = grid[key]
		for o: int in offs:
			if not grid.has(key + o):
				continue
			var B: Array = grid[key + o]
			for i in A.size():
				var r1: Array = A[i]
				for j in range(i + 1 if o == 0 else 0, B.size()):
					var r2: Array = B[j]
					if r1[7] == r2[7] and absf(float(r1[5]) - float(r2[5])) < 25.0:
						continue
					var x = Geometry2D.segment_intersects_segment(r1[1], r1[2], r2[1], r2[2])
					if x != null:
						_add_junction(x, r1, r2)

func _add_junction(x: Vector2, r1: Array, r2: Array) -> void:
	var t1 := ((r1[2] as Vector2) - (r1[1] as Vector2)).normalized()
	var t2 := ((r2[2] as Vector2) - (r2[1] as Vector2)).normalized()
	if absf(t1.cross(t2)) < JUNC_MIN_SIN:
		return
	var s1: float = float(r1[5]) + (r1[1] as Vector2).distance_to(x)
	var s2: float = float(r2[5]) + (r2[1] as Vector2).distance_to(x)
	# конец одной дороги в конце другой — это угол, не перекрёсток
	var end1 := s1 < 1.3 or s1 > line_len[r1[7]] - 1.3
	var end2 := s2 < 1.3 or s2 > line_len[r2[7]] - 1.3
	if end1 and end2:
		return
	# одно пересечение может найтись дважды (по точке на стыке кусков) — повтор ближе 2 м не берём
	var ck := Vector2i(floori(x.x) / PROP_CHUNK, floori(x.y) / PROP_CHUNK)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for f in lines_junc.get(ck + Vector2i(dx, dy), []):
				if (f[0] as Vector2).distance_to(x) < 2.0 and ((f[1] == r1[7] and f[4] == r2[7]) or (f[1] == r2[7] and f[4] == r1[7])):
					return
	var jn := [x, r1[7], s1, t1, r2[7], s2, t2]
	if lines_junc.has(ck):
		lines_junc[ck].append(jn)
	else:
		lines_junc[ck] = [jn]
	for li in [r1[7], r2[7]]:
		if not line_junc.has(li):
			line_junc[li] = []
		if line_junc[li].is_empty() or line_junc[li][line_junc[li].size() - 1] != jn:
			line_junc[li].append(jn)

## Точка на асфальте линии li (с запасом pad), м
func on_line(p: Vector2, li: int, pad: float = 0.0) -> bool:
	var ck := Vector2i(floori(p.x) / PROP_CHUNK, floori(p.y) / PROP_CHUNK)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for r in lines_chunk.get(ck + Vector2i(dx, dy), []):
				if r[7] != li:
					continue
				var hw: float = float(LINE_ROAD_HW[r[0]]) + pad
				if Geometry2D.get_closest_point_to_segment(p, r[1], r[2]).distance_squared_to(p) < hw * hw:
					return true
	return false

## Точка на асфальте другой линии (кроме номера skip): там не рисуются тротуары и разметка — перекрёсток.
## outer — вместе с тротуарами/обочинами (там не рисуются камешки и травинки клетки под дорогой); pad — запас, м
func on_line_road(p: Vector2, skip: int, outer: bool = false, pad: float = 0.0, s_self: float = -1.0) -> bool:
	var ck := Vector2i(floori(p.x) / PROP_CHUNK, floori(p.y) / PROP_CHUNK)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for r in lines_chunk.get(ck + Vector2i(dx, dy), []):
				# своя дорога: пропустить, кроме кусков далеко по пути (петля, s_self >= 0)
				if r[7] == skip and (s_self < 0.0 or absf((float(r[5]) + float(r[6])) * 0.5 - s_self) < 25.0):
					continue
				var hw: float = (LINE_OUTER_HW[r[0]] if outer else LINE_ROAD_HW[r[0]]) + pad
				if Geometry2D.get_closest_point_to_segment(p, r[1], r[2]).distance_squared_to(p) < hw * hw:
					return true
	return false

## Точка (круг радиуса r) целиком на настиле моста — над водой здесь можно стоять
func on_bridge(p: Vector2, r: float) -> bool:
	var ck := Vector2i(floori(p.x) / PROP_CHUNK, floori(p.y) / PROP_CHUNK)
	var lim: float = LINE_OUTER_HW["bridge"] - BRIDGE_RAIL - r
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for rec in lines_chunk.get(ck + Vector2i(dx, dy), []):
				if rec[0] == "bridge" and Geometry2D.get_closest_point_to_segment(p, rec[1], rec[2]).distance_squared_to(p) <= lim * lim:
					return true
	return false

# ================== ВОДА ==================
## Поле воды: в каждом углу сетки — доля воды в 4 клетках вокруг (0…1). Где вокруг угла есть не трава
## (дорога, тротуар, дом, край карты) — не больше 0.5: вода не заходит на них. Вода — там, где
## билинейное поле > 0.5: по нему и рисуется плавный берег, и решается, где не пройти. Клетка воды одна
## (или полоса в 1 клетку) так водой не становится — вода от 2 клеток в ширину
var has_water := false

func water_corner(px: int, py: int) -> float:
	var n := 0
	var hard := false
	for c in [Vector2i(px - 1, py - 1), Vector2i(px, py - 1), Vector2i(px - 1, py), Vector2i(px, py)]:
		var tt := t(c.x, c.y)
		if tt == WATER:
			n += 1
		elif tt != GRASS and tt != TREE:
			hard = true
	var f := n / 4.0
	return minf(f, 0.5) if hard else f

## Поле в 4 углах клетки [лв, пв, пн, лн] (по обходу) или пусто, если рядом нет воды
func water_corners(x: int, y: int) -> PackedFloat32Array:
	if not has_water:
		return PackedFloat32Array()
	var near := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if t(x + dx, y + dy) == WATER:
				near = true
	if not near:
		return PackedFloat32Array()
	return PackedFloat32Array([water_corner(x, y), water_corner(x + 1, y), water_corner(x + 1, y + 1), water_corner(x, y + 1)])

## Билинейное поле внутри клетки: u, v от 0 до 1; углы — [лв, пв, пн, лн]
static func bilerp(f: PackedFloat32Array, u: float, v: float) -> float:
	return lerpf(lerpf(f[0], f[1], u), lerpf(f[3], f[2], u), v)

## Точка в воде (по полю)
func water_at(p: Vector2) -> bool:
	if not has_water:
		return false
	var x := floori(p.x)
	var y := floori(p.y)
	var f := water_corners(x, y)
	return not f.is_empty() and bilerp(f, p.x - x, p.y - y) > 0.5

## Круг задевает воду (середина и 8 точек по краю); на мосту — нет
func _water_blocks(cx: float, cy: float, r: float) -> bool:
	# быстро: нет клетки воды рядом — нет и воды (поле > 0.5 только у клеток воды и их соседей)
	var near := false
	for y in range(floori(cy - r) - 1, floori(cy + r) + 2):
		for x in range(floori(cx - r) - 1, floori(cx + r) + 2):
			if inside(x, y) and tiles[y * w + x] == WATER:
				near = true
	if not near:
		return false
	var c := Vector2(cx, cy)
	var any := false
	for k in 9:
		var p := c if k == 0 else c + Vector2.from_angle(k * PI / 4.0) * r
		if water_at(p):
			any = true
			break
	return any and not on_bridge(c, r)

## Глубина воды (только для вида): у каждой клетки воды — сколько клеток до ближайшей суши (8 соседей, до 10).
## Цвет воды от неё: у берега светлее, вдали темнее
var water_dist := PackedByteArray()

func compute_water_depth() -> void:
	water_dist = PackedByteArray()
	if not has_water:
		return
	water_dist.resize(w * h)
	var q := PackedInt32Array()
	for i in w * h:
		if tiles[i] == WATER:
			water_dist[i] = 255
		else:
			water_dist[i] = 0
			q.append(i)
	var head := 0
	while head < q.size():
		var i: int = q[head]
		head += 1
		var d: int = water_dist[i]
		if d >= 10:
			continue
		var x := i % w
		var y := i / w
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if inside(nx, ny):
					var ni := ny * w + nx
					if water_dist[ni] > d + 1:
						water_dist[ni] = d + 1
						q.append(ni)
	for i in w * h:
		if water_dist[i] == 255:
			water_dist[i] = 10

## Глубина в углах клетки [лв, пв, пн, лн] — среднее по 4 клеткам у угла (суша — 0)
func water_depth_corners(x: int, y: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for c in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 1, y + 1), Vector2i(x, y + 1)]:
		var sum := 0.0
		for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
			var px: int = c.x + d.x
			var py: int = c.y + d.y
			if inside(px, py) and water_dist.size() == w * h:
				sum += water_dist[py * w + px]
		out.append(sum / 4.0)
	return out
