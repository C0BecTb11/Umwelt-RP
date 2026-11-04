extends RefCounted
## Объекты карты (фонари, скамейки, гидранты…): каталог, столкновения и простые модели.
## Без class_name — подключается через preload (новый class_name потребовал бы нового APK).
## Объект на карте — [id, x, y, поворот в градусах]. Модель строится в локальных координатах:
## центр объекта в (0, 0, 0), «перёд» — по +Z; поворот на угол a переводит (lx, lz) в мир через Basis(UP, a).
## col — круги столкновений [dx, dz, радиус] в тех же координатах (пусто — сквозь объект можно пройти).
## Модель художника потом: поле "scene" с путём к .glb/.scn — тогда вместо build() ставится сцена.

const DEFS := {
	"lamp": {"name": "Фонарь", "col": [[0, 0, 0.1]]},
	"bench": {"name": "Скамейка", "col": [[-0.45, 0, 0.18], [0, 0, 0.18], [0.45, 0, 0.18]]},
	"bin": {"name": "Урна", "col": [[0, 0, 0.18]]},
	"hydrant": {"name": "Гидрант", "col": [[0, 0, 0.13]]},
	"mailbox": {"name": "Почтовый ящик", "col": [[0, 0, 0.24]]},
	"newsbox": {"name": "Газетный автомат", "col": [[0, 0, 0.22]]},
	"phone": {"name": "Телефон-автомат", "col": [[0, 0, 0.36]]},
	"busstop": {"name": "Остановка", "col": [[-0.9, -0.3, 0.12], [0.9, -0.3, 0.12], [-0.45, -0.3, 0.12], [0, -0.3, 0.12], [0.45, -0.3, 0.12]]},
	"stop": {"name": "Знак STOP", "col": [[0, 0, 0.06]]},
	"light": {"name": "Светофор", "col": [[0, 0, 0.1]]},
	"dumpster": {"name": "Мусорный контейнер", "col": [[-0.5, 0, 0.38], [0, 0, 0.38], [0.5, 0, 0.38]]},
	"fence": {"name": "Забор-сетка", "col": [[-0.375, 0, 0.07], [-0.125, 0, 0.07], [0.125, 0, 0.07], [0.375, 0, 0.07]]},
	"fence_wood": {"name": "Деревянный забор", "col": [[-0.375, 0, 0.07], [-0.125, 0, 0.07], [0.125, 0, 0.07], [0.375, 0, 0.07]]},
	"cone": {"name": "Конус", "col": [[0, 0, 0.12]]},
	"barrier": {"name": "Ограждение", "col": [[-0.45, 0, 0.12], [0, 0, 0.12], [0.45, 0, 0.12]]},
	"bush": {"name": "Куст", "col": [[0, 0, 0.32]]},
	"tree": {"name": "Дерево", "col": [[0, 0, 0.2]]},
	"palm": {"name": "Пальма", "col": [[0, 0, 0.16]]},
	"crate": {"name": "Ящики", "col": [[0, 0, 0.36]]},
	"sign": {"name": "Вывеска", "col": [[-0.6, 0, 0.06], [0.6, 0, 0.06]]},
}

## Порядок в палитре редактора
const ORDER := ["lamp", "light", "stop", "hydrant", "bench", "bin", "mailbox", "newsbox", "phone", "busstop",
	"dumpster", "fence", "fence_wood", "barrier", "cone", "crate", "sign", "bush", "tree", "palm"]

static func basis_of(e: Array) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(float(e[3])))

## Круги столкновений объекта в координатах карты: Vector3(x, y, радиус)
static func colliders(e: Array) -> Array:
	var out := []
	var b := basis_of(e)
	for c in DEFS[e[0]]["col"]:
		var v := b * Vector3(float(c[0]), 0, float(c[1]))
		out.append(Vector3(float(e[1]) + v.x, float(e[2]) + v.z, float(c[2])))
	return out

## Где у фонаря светит лампа (координаты карты)
static func lamp_head(e: Array) -> Vector2:
	var v := basis_of(e) * Vector3(0, 0, 0.8)
	return Vector2(float(e[1]) + v.x, float(e[2]) + v.z)

static func c(hex: int, glow: bool = false) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255, 128 if glow else 255)

## Модель объекта в Mesher (m.xf уже стоит в точке объекта и повёрнут). y = 0 — земля под объектом
static func build(m: Mesher, id: String) -> void:
	var dark := c(0x2E3236)
	match id:
		"lamp":
			m.box(Vector3(0, 1.45, 0), Vector3(0.1, 2.9, 0.1), dark)
			m.box(Vector3(0, 2.95, 0.4), Vector3(0.06, 0.06, 0.86), dark)
			m.box(Vector3(0, 2.92, 0.8), Vector3(0.32, 0.12, 0.32), c(0x3A3E42))
			m.box(Vector3(0, 2.84, 0.8), Vector3(0.24, 0.04, 0.24), c(0xFFE6A0, true))
		"light":
			m.box(Vector3(0, 1.3, 0), Vector3(0.1, 2.6, 0.1), c(0x3A3C30))
			m.box(Vector3(0, 2.75, 0.06), Vector3(0.3, 0.8, 0.24), c(0x2A2C22))
			m.box(Vector3(0, 3.0, 0.19), Vector3(0.16, 0.16, 0.02), c(0xE03020, true))
			m.box(Vector3(0, 2.75, 0.19), Vector3(0.16, 0.16, 0.02), c(0x5A4A1A))
			m.box(Vector3(0, 2.5, 0.19), Vector3(0.16, 0.16, 0.02), c(0x1A4A2A))
		"stop":
			m.box(Vector3(0, 1.0, 0), Vector3(0.06, 2.0, 0.06), c(0x8A8E92))
			m.push()
			m.translate(Vector3(0, 2.15, 0.04))
			for k in 4:
				m.box(Vector3.ZERO, Vector3(0.5, 0.21, 0.03), c(0xC0201C))
				m.rot_z(45)
			m.pop()
			m.box(Vector3(0, 2.15, 0.06), Vector3(0.34, 0.07, 0.01), c(0xF0F0F0))
		"hydrant":
			m.box(Vector3(0, 0.3, 0), Vector3(0.22, 0.6, 0.22), c(0xC8261E))
			m.box(Vector3(0, 0.64, 0), Vector3(0.16, 0.1, 0.16), c(0xC8261E))
			m.box(Vector3(0, 0.4, 0), Vector3(0.38, 0.09, 0.09), c(0xA81E18))
			m.box(Vector3(0, 0.08, 0), Vector3(0.3, 0.08, 0.3), c(0xA81E18))
		"bench":
			for sx in [-0.55, 0.55]:
				m.box(Vector3(sx, 0.2, 0), Vector3(0.06, 0.4, 0.36), dark)
			m.box(Vector3(0, 0.42, 0.02), Vector3(1.3, 0.05, 0.36), c(0x8A5A32))
			m.box(Vector3(0, 0.72, -0.17), Vector3(1.3, 0.24, 0.05), c(0x8A5A32))
			m.box(Vector3(0, 0.56, -0.17), Vector3(0.06, 0.3, 0.05), dark)
		"bin":
			m.box(Vector3(0, 0.38, 0), Vector3(0.34, 0.76, 0.34), c(0x3E5A3A))
			m.box(Vector3(0, 0.8, 0), Vector3(0.38, 0.06, 0.38), c(0x2E4430))
		"mailbox":
			m.box(Vector3(0, 0.3, 0), Vector3(0.42, 0.6, 0.42), c(0x1E3A7A))
			m.box(Vector3(0, 0.8, 0), Vector3(0.42, 0.4, 0.42), c(0x1E3A7A))
			m.box(Vector3(0, 1.0, 0), Vector3(0.36, 0.06, 0.36), c(0x183066))
			m.box(Vector3(0, 0.82, 0.22), Vector3(0.26, 0.05, 0.02), c(0x101820))
			for sx in [-0.17, 0.17]:
				for sz in [-0.17, 0.17]:
					m.box(Vector3(sx, 0.05, sz), Vector3(0.06, 0.1, 0.06), dark)
		"newsbox":
			m.box(Vector3(0, 0.45, 0), Vector3(0.4, 0.9, 0.36), c(0xD8B020))
			m.box(Vector3(0, 0.62, 0.185), Vector3(0.3, 0.26, 0.01), c(0x9AA6AE))
			m.box(Vector3(0, 0.62, 0.19), Vector3(0.22, 0.16, 0.01), c(0xE8E4D8))
		"phone":
			m.box(Vector3(0, 1.1, -0.28), Vector3(0.7, 2.2, 0.06), c(0x8C9094))
			for sx in [-0.33, 0.33]:
				m.box(Vector3(sx, 1.1, 0), Vector3(0.05, 2.2, 0.6), c(0x8C9094))
			m.box(Vector3(0, 2.25, 0), Vector3(0.78, 0.12, 0.66), c(0x1E3E7A))
			m.box(Vector3(0, 2.25, 0.335), Vector3(0.5, 0.08, 0.01), c(0xF0F0F0, true))
			m.box(Vector3(0, 1.3, -0.22), Vector3(0.26, 0.4, 0.08), c(0x2A2C30))
		"busstop":
			for sx in [-0.95, 0.95]:
				m.box(Vector3(sx, 1.15, -0.3), Vector3(0.07, 2.3, 0.07), dark)
				m.box(Vector3(sx, 1.15, 0.3), Vector3(0.07, 2.3, 0.07), dark)
			m.box(Vector3(0, 1.2, -0.32), Vector3(1.9, 1.6, 0.03), c(0x9CC0CC))
			m.box(Vector3(0, 2.33, 0), Vector3(2.1, 0.08, 0.8), c(0x404448))
			m.box(Vector3(0, 0.45, -0.18), Vector3(1.4, 0.05, 0.25), c(0x8A5A32))
			m.box(Vector3(1.0, 2.0, 0.38), Vector3(0.05, 0.4, 0.4), c(0x2060A0))
		"dumpster":
			m.box(Vector3(0, 0.55, 0), Vector3(1.6, 0.9, 0.9), c(0x2E5A3A))
			m.box(Vector3(0, 1.03, -0.05), Vector3(1.64, 0.06, 0.96), c(0x24482E))
			for sx in [-0.65, 0.65]:
				for sz in [-0.35, 0.35]:
					m.box(Vector3(sx, 0.05, sz), Vector3(0.1, 0.1, 0.1), dark)
		"fence":
			for sx in [-0.5, 0.5]:
				m.box(Vector3(sx, 0.75, 0), Vector3(0.05, 1.5, 0.05), c(0x8A8E92))
			m.box(Vector3(0, 1.48, 0), Vector3(1.0, 0.03, 0.03), c(0x8A8E92))
			m.box(Vector3(0, 0.75, 0), Vector3(1.0, 1.4, 0.01), Color(0.55, 0.58, 0.6))
		"fence_wood":
			for k in 6:
				m.box(Vector3(-0.42 + k * 0.168, 0.65, 0), Vector3(0.14, 1.3, 0.03), c([0x9A7A52, 0x8E6E48][k % 2]))
			m.box(Vector3(0, 0.95, -0.03), Vector3(1.0, 0.08, 0.03), c(0x7A5C3A))
			m.box(Vector3(0, 0.35, -0.03), Vector3(1.0, 0.08, 0.03), c(0x7A5C3A))
		"cone":
			m.box(Vector3(0, 0.02, 0), Vector3(0.3, 0.04, 0.3), c(0xD85A18))
			m.tube(0.04, 0.6, 0.12, 0.03, c(0xE86A20), 8)
			m.box(Vector3(0, 0.35, 0), Vector3(0.16, 0.06, 0.16), c(0xF0F0F0))
		"barrier":
			for sx in [-0.5, 0.5]:
				m.box(Vector3(sx, 0.4, 0), Vector3(0.06, 0.8, 0.3), c(0xE0E0DC))
			for k in 5:
				m.box(Vector3(-0.4 + k * 0.2, 0.7, 0), Vector3(0.2, 0.18, 0.04), c(0xD02818 if k % 2 == 0 else 0xF0F0F0))
		"bush":
			m.blob(m.xf * Vector3(0, 0.4, 0), Vector3(0.45, 0.42, 0.45), c(0x3E6A32), 7)
			m.blob(m.xf * Vector3(0.15, 0.6, -0.1), Vector3(0.3, 0.3, 0.3), c(0x4A7A3C), 9)
		"tree":
			m.box(Vector3(0, 0.75, 0), Vector3(0.2, 1.5, 0.2), c(0x5A4030))
			m.blob(m.xf * Vector3(0, 1.85, 0), Vector3(0.95, 0.75, 0.95), c(0x46723A), 3)
			m.blob(m.xf * Vector3(0.25, 2.4, -0.15), Vector3(0.62, 0.55, 0.62), c(0x52823F), 4)
			m.blob(m.xf * Vector3(-0.3, 2.25, 0.25), Vector3(0.55, 0.5, 0.55), c(0x3E6A32), 5)
		"palm":
			m.tube(0.0, 3.4, 0.13, 0.09, c(0x8A7050), 8)
			m.push()
			m.translate(Vector3(0, 3.4, 0))
			for k in 7:
				m.rot_y(360.0 / 7.0)
				m.push()
				m.rot_x(28)
				m.box(Vector3(0, 0, 0.42), Vector3(0.2, 0.03, 0.85), c(0x4A7A30))
				m.translate(Vector3(0, 0, 0.8))
				m.rot_x(30)
				m.box(Vector3(0, 0, 0.2), Vector3(0.14, 0.03, 0.42), c(0x5A8A38))
				m.pop()
			m.box(Vector3(0, -0.05, 0), Vector3(0.3, 0.25, 0.3), c(0x6A5A3A))
			m.pop()
		"crate":
			m.box(Vector3(-0.15, 0.25, 0), Vector3(0.5, 0.5, 0.5), c(0x9A7A4A))
			m.box(Vector3(0.28, 0.2, 0.1), Vector3(0.4, 0.4, 0.4), c(0x8A6A3E))
			m.box(Vector3(-0.1, 0.7, 0.02), Vector3(0.4, 0.4, 0.4), c(0xA4844E))
		"sign":
			for sx in [-0.6, 0.6]:
				m.box(Vector3(sx, 1.2, 0), Vector3(0.08, 2.4, 0.08), dark)
			m.box(Vector3(0, 2.3, 0), Vector3(1.6, 0.6, 0.08), c(0xE8D8A8))
			m.box(Vector3(0, 2.3, 0.045), Vector3(1.3, 0.3, 0.01), c(0xB02818, true))
