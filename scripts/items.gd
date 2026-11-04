class_name Items
extends RefCounted

enum Kind { FOOD, DRINK, MED, MELEE, GUN, AMMO, WEAR }

## Слоты одежды. Каждая вещь — часть модели персонажа (assets/chars, Quaternius CC0) для мужчины "m" и/или женщины "f"
const SLOTS := ["head", "torso", "legs", "feet"]
const SLOT_NAMES := {"head": "Голова", "torso": "Верх", "legs": "Низ", "feet": "Обувь"}
## Что видно, если слот пустой
const BARE := {
	"m": {"torso": "Beach_Body", "legs": "Beach_Legs", "feet": "Beach_Feet"},
	"f": {"torso": "Casual_Body", "legs": "Casual_Legs", "feet": "Casual_Feet"},
}
## Причёски (часть «голова»): первые — обычные, их раздаём по умолчанию
const HEADS := {
	"m": ["Casual2_Head", "Suit_Head", "Casual_Head", "Adventurer_Head", "Beach_Head", "Punk_Head"],
	"f": ["Casual_Head", "Formad_Head", "Suit_Head", "Adventurer_Head", "Soldier_Head", "Punk_Head"],
}
## Цветные варианты вещей из набора: [суффикс id, прилагательное, цвет]. tint у вещи — какой материал перекрашивать
const COLORS := {
	"tshirt": [["black", "чёрная", "#202024"], ["red", "красная", "#a8262a"], ["navy", "синяя", "#24366e"], ["yellow", "жёлтая", "#d8a828"], ["green", "зелёная", "#2e6a3a"]],
	"hoodie": [["black", "чёрная", "#1e1e22"], ["grey", "серая", "#6a6c70"], ["red", "красная", "#8a1c22"], ["navy", "синяя", "#1e2c5a"], ["green", "зелёная", "#24502e"]],
	"dress": [["red", "красное", "#9a1c24"], ["black", "чёрное", "#1c1c20"], ["blue", "синее", "#24407e"], ["yellow", "жёлтое", "#d0a020"]],
}
const START_WEAR := {"torso": "tshirt", "legs": "jeans", "feet": "sneakers"}

static var DEFS: Dictionary = _build()

static func _d(name: String, kind: int, w: float, color: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"name": name, "kind": kind, "w": w, "color": Color(color),
		"hunger": 0.0, "thirst": 0.0, "heal": 0.0, "dmg": 0.0, "range": 0.0, "cd": 0.0, "slot": ""}
	for k in extra:
		d[k] = extra[k]
	return d

static func _build() -> Dictionary:
	var d := _base()
	# цветные варианты: та же модель, другой цвет главного материала
	for base in COLORS:
		for v in COLORS[base]:
			var nd: Dictionary = d[base].duplicate(true)
			nd["name"] = "%s (%s)" % [d[base]["name"], v[1]]
			nd["color"] = Color(v[2])
			nd["tint_color"] = v[2]
			d[base + "_" + v[0]] = nd
	return d

static func _base() -> Dictionary:
	var K := Kind
	return {
		"fists": _d("Кулаки", K.MELEE, 0.0, "#e0b090", {"dmg": 8.0, "range": 0.9, "cd": 0.55}),
		"canned": _d("Консервы", K.FOOD, 0.6, "#b0b8c0", {"hunger": 35.0}),
		"chips": _d("Чипсы", K.FOOD, 0.2, "#e8c040", {"hunger": 15.0, "thirst": -5.0}),
		"bread": _d("Хлеб", K.FOOD, 0.3, "#c89048", {"hunger": 25.0}),
		"apple": _d("Яблоко", K.FOOD, 0.2, "#d03030", {"hunger": 10.0, "thirst": 5.0}),
		"water": _d("Бутылка воды", K.DRINK, 0.6, "#60a8e8", {"thirst": 45.0}),
		"soda": _d("Газировка", K.DRINK, 0.4, "#e04848", {"thirst": 25.0, "hunger": 5.0}),
		"medkit": _d("Аптечка", K.MED, 0.4, "#e8e8e8", {"heal": 50.0}),
		"knife": _d("Кухонный нож", K.MELEE, 0.4, "#c0c0c8", {"dmg": 22.0, "range": 1.0, "cd": 0.4}),
		"bat": _d("Бейсбольная бита", K.MELEE, 1.5, "#b07840", {"dmg": 38.0, "range": 1.3, "cd": 0.7}),
		"crowbar": _d("Лом", K.MELEE, 2.0, "#707078", {"dmg": 48.0, "range": 1.3, "cd": 0.85}),
		"hammer": _d("Молоток", K.MELEE, 1.0, "#905030", {"dmg": 20.0, "range": 1.0, "cd": 0.55}),
		"pistol": _d("Пистолет", K.GUN, 1.0, "#303034", {"dmg": 70.0, "range": 10.0, "cd": 0.45}),
		"ammo": _d("Патроны 9мм", K.AMMO, 0.02, "#d0b040"),
		# ---------- одежда: parts — часть модели для мужчины/женщины; also — что ещё закрывает (платье — и низ) ----------
		"hard_hat": _d("Строительная каска", K.WEAR, 0.4, "#e8c020", {"slot": "head", "parts": {"m": "Worker_Head", "f": "Worker_Head"}}),
		"swat_helmet": _d("Шлем спецназа", K.WEAR, 1.2, "#25272b", {"slot": "head", "parts": {"m": "Swat_Head"}}),
		"farmer_hat": _d("Шляпа фермера", K.WEAR, 0.2, "#c8b070", {"slot": "head", "parts": {"m": "Farmer_Head"}}),
		"tshirt": _d("Футболка", K.WEAR, 0.2, "#e6e2da", {"slot": "torso", "parts": {"m": "Casual2_Body", "f": "Casual_Body"}, "tint": {"m": "LightBrown", "f": "White"}}),
		"hoodie": _d("Толстовка", K.WEAR, 0.6, "#5b3f86", {"slot": "torso", "parts": {"m": "Casual_Body"}, "tint": {"m": "Purple"}}),
		"overalls": _d("Джинсовый комбинезон", K.WEAR, 1.0, "#3a5a8a", {"slot": "torso", "parts": {"m": "Farmer_Body"}, "also": {"legs": {"m": "Farmer_Pants"}}}),
		"tactical": _d("Тактическая форма", K.WEAR, 1.5, "#2a2e34", {"slot": "torso", "parts": {"m": "Swat_Body", "f": "Soldier_Body"}}),
		"shirt": _d("Рубашка", K.WEAR, 0.3, "#6f6a3a", {"slot": "torso", "parts": {"m": "Adventurer_Body", "f": "Adventurer_Body"}}),
		"suit_jacket": _d("Пиджак", K.WEAR, 0.9, "#2a2c33", {"slot": "torso", "parts": {"m": "Suit_Body", "f": "Suit_Body"}}),
		"biker_vest": _d("Байкерская жилетка", K.WEAR, 0.8, "#222226", {"slot": "torso", "parts": {"m": "Punk_Body", "f": "Punk_Body"}}),
		"work_vest": _d("Рабочий жилет", K.WEAR, 0.5, "#e8a020", {"slot": "torso", "parts": {"m": "Worker_Body", "f": "Worker_Body"}}),
		"dress": _d("Платье", K.WEAR, 0.4, "#5aa040", {"slot": "torso", "parts": {"f": "Formal_Body"}, "also": {"legs": {"f": "Formal_Legs"}}, "tint": {"f": "LimeGreen"}}),
		"jeans": _d("Джинсы", K.WEAR, 0.7, "#34507a", {"slot": "legs", "parts": {"m": "Casual2_Legs", "f": "Punk_Legs"}}),
		"pants": _d("Брюки", K.WEAR, 0.5, "#2a2c33", {"slot": "legs", "parts": {"m": "Suit_Legs", "f": "Suit_Legs"}}),
		"shorts": _d("Шорты", K.WEAR, 0.3, "#4a5a7a", {"slot": "legs", "parts": {"m": "Casual_Legs", "f": "Adventurer_Legs"}}),
		"work_pants": _d("Рабочие штаны", K.WEAR, 0.8, "#8a7448", {"slot": "legs", "parts": {"m": "Worker_Legs", "f": "Worker_Legs"}}),
		"ripped_jeans": _d("Рваные джинсы", K.WEAR, 0.7, "#3a5684", {"slot": "legs", "parts": {"m": "Punk_Legs"}}),
		"cargo": _d("Карго-штаны", K.WEAR, 0.8, "#6b5a3a", {"slot": "legs", "parts": {"m": "Adventurer_Legs"}}),
		"tactical_pants": _d("Тактические штаны", K.WEAR, 0.9, "#2a2e34", {"slot": "legs", "parts": {"m": "Swat_Legs", "f": "Soldier_Legs"}}),
		"sneakers": _d("Кеды", K.WEAR, 0.5, "#c83a3a", {"slot": "feet", "parts": {"m": "Casual2_Feet", "f": "Casual_Feet"}}),
		"shoes": _d("Туфли", K.WEAR, 0.6, "#1e1e22", {"slot": "feet", "parts": {"m": "Suit_Feet", "f": "Formal_Feet"}}),
		"boots": _d("Ботинки", K.WEAR, 1.0, "#5a4028", {"slot": "feet", "parts": {"m": "Worker_Feet", "f": "Worker_Feet"}}),
		"combat_boots": _d("Берцы", K.WEAR, 1.2, "#1e1e20", {"slot": "feet", "parts": {"m": "Swat_Feet", "f": "Soldier_Feet"}}),
		"high_boots": _d("Высокие ботинки", K.WEAR, 1.0, "#18181a", {"slot": "feet", "parts": {"m": "Punk_Feet", "f": "Punk_Feet"}}),
		"hiking_boots": _d("Походные ботинки", K.WEAR, 1.0, "#6a5034", {"slot": "feet", "parts": {"m": "Adventurer_Feet", "f": "Adventurer_Feet"}}),
		"rubber_boots": _d("Резиновые сапоги", K.WEAR, 1.1, "#4a3a20", {"slot": "feet", "parts": {"m": "Farmer_Feet"}}),
	}

static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["fists"])

## Подходит ли вещь персонажу этого пола
static func fits(id: String, gender: String) -> bool:
	var d := def(id)
	return d["kind"] != Kind.WEAR or (d.get("parts", {}) as Dictionary).has(gender)

## Какую часть модели показать в слоте при такой одежде («» в слоте head — своя причёска)
static func part_for(wear: Dictionary, gender: String, slot: String) -> String:
	var g := gender if BARE.has(gender) else "m"
	if slot == "head":
		if wear.has("head"):
			return (def(wear["head"]).get("parts", {}) as Dictionary).get(g, "")
		return ""
	if slot == "legs" and wear.has("torso"):
		var also: Dictionary = def(wear["torso"]).get("also", {})
		if also.has("legs") and (also["legs"] as Dictionary).has(g):
			return also["legs"][g]
	if wear.has(slot):
		var parts: Dictionary = def(wear[slot]).get("parts", {})
		if parts.has(g):
			return parts[g]
	return BARE[g][slot]

## Перекраска части в слоте: [имя материала, цвет] или [] (цветной вариант вещи; платье красит и низ)
static func tint_for(wear: Dictionary, gender: String, slot: String) -> Array:
	var id := ""
	if wear.has(slot):
		id = wear[slot]
	if slot == "legs" and wear.has("torso") and (def(wear["torso"]).get("also", {}) as Dictionary).has("legs"):
		id = wear["torso"]
	if id == "":
		return []
	var d := def(id)
	if not d.has("tint_color") or not (d.get("tint", {}) as Dictionary).has(gender):
		return []
	return [d["tint"][gender], Color(d["tint_color"])]

# ---------- инвентарь: массив словарей {"id", "n"} ----------
static func add_to(list: Array, id: String, n: int) -> void:
	for s in list:
		if s["id"] == id:
			s["n"] += n
			return
	list.append({"id": id, "n": n})

static func count(list: Array, id: String) -> int:
	for s in list:
		if s["id"] == id:
			return s["n"]
	return 0

static func take(list: Array, id: String, n: int = 1) -> bool:
	for i in list.size():
		var s: Dictionary = list[i]
		if s["id"] == id:
			if s["n"] < n:
				return false
			s["n"] -= n
			if s["n"] <= 0:
				list.remove_at(i)
			return true
	return false

static func weight(list: Array) -> float:
	var w := 0.0
	for s in list:
		w += def(s["id"])["w"] * s["n"]
	return w

static func copy(list: Array) -> Array:
	var out := []
	for s in list:
		out.append({"id": s["id"], "n": int(s["n"])})
	return out
