class_name Demo
extends RefCounted
## Демо-сцены для автоматических скриншотов (--demo=имя --shot=файл.png).

static func create(kind: String) -> GameState:
	var g := GameState.new_game(1990)
	var p: GameState.Player = g.players[0]
	p.name = "Тест"
	g.time = 11 * 60.0
	match kind:
		"inside", "loot", "inv":
			_into_house(g, p)
		"night":
			g.time = 23 * 60.0
		"evening":
			g.time = 19 * 60.0 + 50.0
		"gear", "outfit", "crowd", "knocked", "armed":
			_open_street(g, p)
			p.wear = {"torso": "suit_jacket", "legs": "pants", "feet": "shoes"}
			p.face = Vector2(0, 1)
			for id in ["hoodie", "jeans", "work_vest", "boots", "medkit"]:
				Items.add_to(p.inv, id, 1)
	if kind == "crowd" or kind == "knocked" or kind == "armed":
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
