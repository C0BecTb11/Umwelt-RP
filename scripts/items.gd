class_name Items
extends RefCounted

enum Kind { FOOD, DRINK, MED, MELEE, GUN, AMMO, MATERIAL, WEAR }

## Слоты одежды. Каждая вещь — часть модели персонажа (assets/chars, Quaternius CC0) для мужчины "m" и/или женщины "f"
const SLOTS := ["torso", "legs", "feet"]
const SLOT_NAMES := {"torso": "Верх", "legs": "Низ", "feet": "Обувь"}
## Что видно, если слот пустой
const BARE := {
	"m": {"torso": "Beach_Body", "legs": "Beach_Legs", "feet": "Beach_Feet"},
	"f": {"torso": "Casual_Body", "legs": "Casual_Legs", "feet": "Casual_Feet"},
}
## Причёски (часть «голова»): первые — обычные, их раздаём по умолчанию
const HEADS := {
	"m": ["Casual2_Head", "Suit_Head", "Casual_Head", "Adventurer_Head", "Beach_Head", "Punk_Head"],
	"f": ["Casual_Head", "Formad_Head", "Suit_Head", "Adventurer_Head", "Punk_Head"],
}
const START_WEAR := {"torso": "tshirt", "legs": "jeans", "feet": "sneakers"}

static var DEFS: Dictionary = _build()

static func _d(name: String, kind: int, w: float, color: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"name": name, "kind": kind, "w": w, "color": Color(color),
		"hunger": 0.0, "thirst": 0.0, "heal": 0.0, "dmg": 0.0, "range": 0.0, "cd": 0.0, "noise": 0.0, "slot": "", "prot": 0.0, "cap": 0.0}
	for k in extra:
		d[k] = extra[k]
	return d

static func _build() -> Dictionary:
	var K := Kind
	return {
		"fists": _d("Кулаки", K.MELEE, 0.0, "#e0b090", {"dmg": 8.0, "range": 0.9, "cd": 0.55, "noise": 2.0}),
		"canned": _d("Консервы", K.FOOD, 0.6, "#b0b8c0", {"hunger": 35.0}),
		"chips": _d("Чипсы", K.FOOD, 0.2, "#e8c040", {"hunger": 15.0, "thirst": -5.0}),
		"bread": _d("Хлеб", K.FOOD, 0.3, "#c89048", {"hunger": 25.0}),
		"apple": _d("Яблоко", K.FOOD, 0.2, "#d03030", {"hunger": 10.0, "thirst": 5.0}),
		"water": _d("Бутылка воды", K.DRINK, 0.6, "#60a8e8", {"thirst": 45.0}),
		"soda": _d("Газировка", K.DRINK, 0.4, "#e04848", {"thirst": 25.0, "hunger": 5.0}),
		"medkit": _d("Аптечка", K.MED, 0.4, "#e8e8e8", {"heal": 50.0}),
		"knife": _d("Кухонный нож", K.MELEE, 0.4, "#c0c0c8", {"dmg": 22.0, "range": 1.0, "cd": 0.4, "noise": 2.0}),
		"bat": _d("Бейсбольная бита", K.MELEE, 1.5, "#b07840", {"dmg": 38.0, "range": 1.3, "cd": 0.7, "noise": 4.0}),
		"crowbar": _d("Лом", K.MELEE, 2.0, "#707078", {"dmg": 48.0, "range": 1.3, "cd": 0.85, "noise": 5.0}),
		"hammer": _d("Молоток", K.MELEE, 1.0, "#905030", {"dmg": 20.0, "range": 1.0, "cd": 0.55, "noise": 3.0}),
		"pistol": _d("Пистолет", K.GUN, 1.0, "#303034", {"dmg": 70.0, "range": 10.0, "cd": 0.45, "noise": 24.0}),
		"ammo": _d("Патроны 9мм", K.AMMO, 0.02, "#d0b040"),
		# ---------- одежда: parts — часть модели для мужчины/женщины; also — что ещё закрывает (платье — и низ) ----------
		"tshirt": _d("Футболка", K.WEAR, 0.2, "#e6e2da", {"slot": "torso", "parts": {"m": "Casual2_Body", "f": "Casual_Body"}}),
		"hoodie": _d("Толстовка", K.WEAR, 0.6, "#5b3f86", {"slot": "torso", "parts": {"m": "Casual_Body"}}),
		"shirt": _d("Рубашка", K.WEAR, 0.3, "#6f6a3a", {"slot": "torso", "parts": {"m": "Adventurer_Body", "f": "Adventurer_Body"}}),
		"suit_jacket": _d("Пиджак", K.WEAR, 0.9, "#2a2c33", {"slot": "torso", "parts": {"m": "Suit_Body", "f": "Suit_Body"}}),
		"biker_vest": _d("Байкерская жилетка", K.WEAR, 0.8, "#222226", {"slot": "torso", "parts": {"m": "Punk_Body", "f": "Punk_Body"}}),
		"work_vest": _d("Рабочий жилет", K.WEAR, 0.5, "#e8a020", {"slot": "torso", "parts": {"m": "Worker_Body", "f": "Worker_Body"}}),
		"dress": _d("Платье", K.WEAR, 0.4, "#5aa040", {"slot": "torso", "parts": {"f": "Formal_Body"}, "also": {"legs": {"f": "Formal_Legs"}}}),
		"jeans": _d("Джинсы", K.WEAR, 0.7, "#34507a", {"slot": "legs", "parts": {"m": "Casual2_Legs", "f": "Punk_Legs"}}),
		"pants": _d("Брюки", K.WEAR, 0.5, "#2a2c33", {"slot": "legs", "parts": {"m": "Suit_Legs", "f": "Suit_Legs"}}),
		"shorts": _d("Шорты", K.WEAR, 0.3, "#4a5a7a", {"slot": "legs", "parts": {"m": "Casual_Legs", "f": "Adventurer_Legs"}}),
		"work_pants": _d("Рабочие штаны", K.WEAR, 0.8, "#8a7448", {"slot": "legs", "parts": {"m": "Worker_Legs", "f": "Worker_Legs"}}),
		"sneakers": _d("Кеды", K.WEAR, 0.5, "#c83a3a", {"slot": "feet", "parts": {"m": "Casual2_Feet", "f": "Casual_Feet"}}),
		"shoes": _d("Туфли", K.WEAR, 0.6, "#1e1e22", {"slot": "feet", "parts": {"m": "Suit_Feet", "f": "Formal_Feet"}}),
		"boots": _d("Ботинки", K.WEAR, 1.0, "#5a4028", {"slot": "feet", "parts": {"m": "Worker_Feet", "f": "Worker_Feet"}}),
	}

static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["fists"])

## Подходит ли вещь персонажу этого пола
static func fits(id: String, gender: String) -> bool:
	var d := def(id)
	return d["kind"] != Kind.WEAR or (d.get("parts", {}) as Dictionary).has(gender)

## Какую часть модели показать в слоте при такой одежде
static func part_for(wear: Dictionary, gender: String, slot: String) -> String:
	var g := gender if BARE.has(gender) else "m"
	if slot == "legs" and wear.has("torso"):
		var also: Dictionary = def(wear["torso"]).get("also", {})
		if also.has("legs") and (also["legs"] as Dictionary).has(g):
			return also["legs"][g]
	if wear.has(slot):
		var parts: Dictionary = def(wear[slot]).get("parts", {})
		if parts.has(g):
			return parts[g]
	return BARE[g][slot]

## Таблицы лута: [id, вес шанса, мин, макс]
static var LOOT: Dictionary = {
	"fridge": [["water", 5, 1, 2], ["soda", 5, 1, 2], ["apple", 4, 1, 3], ["bread", 3, 1, 1], ["canned", 2, 1, 1]],
	"counter": [["canned", 5, 1, 2], ["chips", 4, 1, 1], ["knife", 3, 1, 1], ["bread", 2, 1, 1], ["water", 2, 1, 1]],
	"wardrobe": [["bat", 2, 1, 1], ["hammer", 2, 1, 1], ["chips", 1, 1, 1],
		["hoodie", 3, 1, 1], ["shirt", 2, 1, 1], ["jeans", 3, 1, 1], ["shorts", 2, 1, 1], ["boots", 2, 1, 1], ["shoes", 1, 1, 1]],
	"shelf": [["chips", 4, 1, 1], ["canned", 3, 1, 1], ["hammer", 2, 1, 1], ["crowbar", 1, 1, 1]],
	"med": [["medkit", 3, 1, 1]],
	"store": [["canned", 6, 1, 3], ["chips", 6, 1, 3], ["water", 6, 1, 3], ["soda", 5, 1, 3], ["bread", 3, 1, 2]],
	"car": [["water", 4, 1, 1], ["chips", 3, 1, 1], ["crowbar", 2, 1, 1], ["ammo", 1, 3, 8], ["soda", 3, 1, 1]],
	"police": [["pistol", 3, 1, 1], ["ammo", 6, 6, 15], ["crowbar", 2, 1, 1], ["boots", 2, 1, 1]],
}

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
