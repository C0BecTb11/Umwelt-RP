class_name RestSpots
extends RefCounted
## Где на мебели сидят и лежат: точки в осях самой модели (как в наборах мебели: +z — лицо, клетка 1×1).
## Нужны, чтобы человек садился точно на сиденье и ложился головой на подушку, а не «примерно в клетку».
## "k": 1 — сидеть, 2 — лежать. "p": x и z — куда приходит таз, y — высота сиденья или постели над полом.
## Для «лежать»: голова — в сторону −x модели; "sides" — с какой стороны подходят (1 — с лица, −1 — сзади);
## "deep" — на сколько середина постели дальше места, где человек стоял; "up" — подъём изголовья, градусы.
## Меняешь модель мебели — поправь её точки здесь (проверка test_rest_poses сверяет высоты с моделью).

const W = preload("res://scripts/world.gd")

## mode — как стоит мебель: 1 — одна клетка, 2 — длинная на две клетки, 3 — койка изголовьем к стене
static func local(t: int, mode: int) -> Array:
	var wide := mode == 2
	match t:
		W.CHAIR:
			return [{"k": 1, "p": Vector3(-0.245, 0.48, -0.07)}, {"k": 1, "p": Vector3(0.245, 0.48, -0.07)}]
		W.BENCH:
			return [{"k": 1, "p": Vector3(-0.25, 0.4675, -0.02)}, {"k": 1, "p": Vector3(0.25, 0.4675, -0.02)}]
		W.OFFICECHAIR:
			return [{"k": 1, "p": Vector3(0, 0.545, -0.06)}]
		W.SOFA:
			if wide:
				return [{"k": 1, "p": Vector3(0.12, 0.46, -0.02)}, {"k": 1, "p": Vector3(0.88, 0.46, -0.02)}]
			return [{"k": 1, "p": Vector3(0, 0.46, -0.02)}]
		W.WHEELCHAIR:
			return [{"k": 1, "p": Vector3(0, 0.515, -0.07)}]
		W.CELLBUNK:
			if wide:
				return [{"k": 2, "p": Vector3(0.39, 0.545, -0.08), "sides": [1], "deep": 0.62, "up": 0.0}]
			return [{"k": 1, "p": Vector3(0, 0.545, 0.05)}]
		W.HOSPBED:
			if mode == 3:
				return [{"k": 2, "p": Vector3(-0.03, 0.72, 0), "sides": [1, -1], "deep": 0.72, "up": 22.0}]
			if wide:
				return [{"k": 2, "p": Vector3(0.35, 0.72, 0), "sides": [1], "deep": 0.72, "up": 22.0}]
			return [{"k": 1, "p": Vector3(0.15, 0.72, 0.22)}]
		W.GURNEY:
			if wide:
				return [{"k": 2, "p": Vector3(0.37, 0.87, 0), "sides": [1, -1], "deep": 0.62, "up": 0.0}]
		W.EXAMTABLE:
			if wide:
				return [{"k": 2, "p": Vector3(0.4, 0.705, 0), "sides": [1, -1], "deep": 0.6, "up": 5.0}]
			return [{"k": 1, "p": Vector3(0, 0.705, 0.1)}]
		W.OPTABLE:
			if wide:
				return [{"k": 2, "p": Vector3(0.4, 0.82, 0), "sides": [-1, 1], "deep": 0.56, "up": 0.0}]
	return []
