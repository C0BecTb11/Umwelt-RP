class_name Demo
extends RefCounted
## Демо-сцены для автоматических скриншотов (--demo=имя --shot=файл.png).

static func create(kind: String) -> GameState:
	var g := GameState.new_game(1990)
	var p: GameState.Player = g.players[0]
	p.name = "Тест"
	g.real_clock = false          # у снимков своё время суток
	g.time = 11 * 60.0
	match kind:
		"inside", "inv":
			_into_house(g, p)
		"night":
			g.time = 23 * 60.0
		"evening":
			g.time = 19 * 60.0 + 50.0
		"gear", "outfit", "crowd", "knocked", "armed", "chat", "chatlog":
			_open_street(g, p)
			p.wear = {"torso": "suit_jacket", "legs": "pants", "feet": "shoes"}
			p.face = Vector2(0, 1)
			for id in ["hoodie", "jeans", "work_vest", "boots", "medkit"]:
				Items.add_to(p.inv, id, 1)
	if kind == "crowd" or kind == "knocked" or kind == "armed" or kind == "chat" or kind == "chatlog":
		var outfits := [{"torso": "hoodie", "legs": "shorts", "feet": "sneakers"}, {"torso": "work_vest", "legs": "work_pants", "feet": "boots"},
			{"torso": "dress", "feet": "shoes"}, {"torso": "biker_vest", "legs": "jeans", "feet": "boots"}]
		var genders := ["m", "m", "f", "f"]
		for k in 4:
			var q := GameState.Player.new(k + 1)
			q.pos = g.unstick(p.pos + Vector2.from_angle(k * 1.4 + 0.5) * 1.6, GameState.PLAYER_R)
			q.rpos = q.pos
			q.face = (p.pos - q.pos).normalized()
			q.wear = outfits[k]
			q.look = GameState.default_look(k + 1, genders[k])
			q.name = ["Джек", "Майк", "Сара", "Тони"][k]
			g.players.append(q)
		if kind == "knocked":
			g.knock_out(g.players[1])
		if kind == "armed":
			var arms := ["bat", "pistol", "knife", "crowbar", "hammer"]
			for k in 5:
				g.players[k].eq = arms[k]
	if kind == "catalog":
		_open_street(g, p)
		p.face = Vector2(0, 1)
		var looks := [
			["m", {"head": "hard_hat", "torso": "work_vest", "legs": "work_pants", "feet": "boots"}],
			["m", {"head": "swat_helmet", "torso": "tactical", "legs": "tactical_pants", "feet": "combat_boots"}],
			["m", {"head": "farmer_hat", "torso": "overalls", "feet": "rubber_boots"}],
			["m", {"torso": "biker_vest", "legs": "ripped_jeans", "feet": "high_boots"}],
			["m", {"torso": "shirt", "legs": "cargo", "feet": "hiking_boots"}],
			["m", {"torso": "hoodie_red", "legs": "jeans", "feet": "sneakers"}],
			["m", {"torso": "tshirt_yellow", "legs": "shorts", "feet": "sneakers"}],
			["f", {"torso": "tactical", "legs": "tactical_pants", "feet": "combat_boots"}],
			["f", {"head": "hard_hat", "torso": "work_vest", "legs": "work_pants", "feet": "boots"}],
			["f", {"torso": "dress_red", "feet": "shoes"}],
			["f", {"torso": "dress_black", "feet": "high_boots"}],
			["f", {"torso": "tshirt_navy", "legs": "jeans", "feet": "hiking_boots"}],
		]
		for k in looks.size():
			var q := GameState.Player.new(k + 1)
			q.pos = g.unstick(p.pos + Vector2((k % 6) * 1.1 - 2.75, 0.4 + floorf(k / 6.0) * 2.4), GameState.PLAYER_R)
			q.rpos = q.pos
			q.face = Vector2(0, 1)
			q.look = GameState.default_look(k + 1, looks[k][0])
			q.wear = looks[k][1]
			q.name = ""
			g.players.append(q)
	if kind == "menu" or kind == "stats":
		# пример статистики для снимка: 1 уровень, 1 из 4 очков, сегодня 2 ч 33 мин и 7 мин АФК
		p.level = 1
		p.exp = 1
		p.reg = "2026-11-04"
		p.day = floori(g.time / 1440.0)
		p.day_play = 2 * 3600 + 33 * 60
		p.day_afk = 7 * 60
		p.hour_play = 14 * 60
	if kind == "chat" or kind == "chatlog":
		var q1: GameState.Player = g.players[1]
		var q3: GameState.Player = g.players[3]
		g.chat[p.id] = ["%s говорит: Привет! Не подскажешь, где мэрия?" % GameState.tag(q1),
			"%s говорит: Прямо по Мейн-стрит, там площадь" % GameState.tag(p),
			"%s говорит: Спасибо, а автовокзал далеко?" % GameState.tag(q1),
			"%s говорит: Нет, к югу от центра, рядом с больницей. Пойдём, покажу" % GameState.tag(q3)]
	if kind == "chatlog":
		p.hour_play = 25 * 60      # настоящий PayDay — плашка, как в игре
		g.payday()
	if kind == "inv":
		for id in ["canned", "water", "pistol", "ammo", "apple", "chips", "medkit"]:
			Items.add_to(p.inv, id, 12 if id == "ammo" else 2)
	return g

static func _into_house(g: GameState, p: GameState.Player) -> void:
	var w := g.world
	var best := -1
	var bd := 1e9
	for y in range(1, w.h - 1):
		for x in range(1, w.w - 1):
			if w.t(x, y) != GameWorld.TILEFLOOR:
				continue
			var furn := false
			for k in 4:
				if GameWorld.is_furniture(w.t(x + GameWorld.DX4[k], y + GameWorld.DY4[k])):
					furn = true
			if not furn:
				continue
			var d := Vector2(x, y).distance_to(p.pos)
			if d < bd:
				bd = d
				best = w.idx(x, y)
	if best >= 0:
		p.pos = Vector2(best % w.w + 0.5, best / w.w + 0.5)
		p.rpos = p.pos

## Открытое место на улице, чтобы ничего не заслоняло
static func _open_street(g: GameState, p: GameState.Player) -> void:
	var w := g.world
	var best := Vector2.ZERO
	var bd := 1e9
	for y in range(6, w.h - 6):
		for x in range(6, w.w - 6):
			var free := true
			for yy in range(y - 3, y + 4):
				for xx in range(x - 3, x + 4):
					if w.solid(xx, yy) or w._is_building_tile(w.t(xx, yy)):
						free = false
						break
				if not free:
					break
			if free:
				var d := Vector2(x, y).distance_to(p.pos)
				if d < bd:
					bd = d
					best = Vector2(x + 0.5, y + 0.5)
	if bd < 1e9:
		p.pos = best
		p.rpos = best
