extends Node
## Автотесты механик для аудита: каждая проверка печатает OK или ОШИБКА с подробностями.
## Запуск: godot --headless --path . -- --audit

const W = preload("res://scripts/world.gd")

var fails := 0
var passes := 0

func check(name: String, ok: bool, details: String = "") -> void:
	if ok:
		passes += 1
		print("OK      ", name)
	else:
		fails += 1
		print("ОШИБКА  ", name, "  —  ", details)

const SEED := 20261104     # случайные маршруты в тестах — одни и те же при каждом запуске

func _ready() -> void:
	seed(SEED)
	print("зерно случайности тестов: %d" % SEED)
	test_walls()
	test_corner()
	test_stuck_escape()
	test_remote_teleport()
	test_bad_input()
	test_remote_wall()
	test_remote_actions()
	test_saves()
	test_world_gen()
	test_map()
	test_editor()
	test_remote_door()
	test_bullet_window()
	test_remote_no_false_rollback()
	test_remote_through()
	test_smooth_remote()
	test_attack_sync()
	test_house_layout()
	test_wear()
	test_look()
	test_clock()
	test_old_world()
	test_rp_rules()
	test_events_all()
	test_stamina_net()
	test_server_guards()
	test_player_card()
	print("\nИТОГО: %d прошло, %d ошибок" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

func _game() -> GameState:
	return GameState.new_game(777)

## Открытое место: круг радиусом 2 клетки без препятствий (для проверок, где стены мешают)
func _open_spot(g: GameState) -> Vector2:
	for y in range(5, 95):
		for x in range(5, 95):
			var ok := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if g.world.solid(x + dx, y + dy):
						ok = false
			if ok:
				return Vector2(x + 0.5, y + 0.5)
	return g.spawn

## Клетка стены с полом по одну сторону и улицей по другую
func _find_wall(g: GameState) -> Vector2i:
	var w := g.world
	for y in range(2, w.h - 2):
		for x in range(2, w.w - 2):
			if w.t(x, y) == W.WALL and w.t(x, y + 1) == W.WOOD and not w.solid(x, y - 1) and w.t(x - 1, y) == W.WALL and w.t(x + 1, y) == W.WALL:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func test_walls() -> void:
	var g := _game()
	var wc := _find_wall(g)
	var p: GameState.Player = g.players[0]
	p.pos = Vector2(wc.x + 0.5, wc.y - 0.4)
	p.move = Vector2(0, 1)
	var crossed := false
	for i in 300:
		g.update(1.0 / 60.0)
		if p.pos.y > wc.y + 1.0:
			crossed = true
	check("Движение: нельзя пройти сквозь стену", not crossed, "игрок оказался в %s за стеной %s" % [p.pos, wc])
	p.move = Vector2(0, 1)
	p.run = true
	for i in 300:
		g.update(1.0 / 60.0)
	check("Движение: бегом тоже нельзя", p.pos.y < wc.y + 0.5, "pos %s" % p.pos)

func test_corner() -> void:
	var g := _game()
	var p: GameState.Player = g.players[0]
	var w := g.world
	var bad := 0
	for k in 200:
		p.pos = Vector2(randf_range(2, 98), randf_range(2, 98))
		if w.circle_blocked(p.pos.x, p.pos.y, GameState.PLAYER_R):
			continue
		p.move = Vector2.from_angle(randf() * TAU)
		for i in 120:
			g.update(1.0 / 60.0)
			if w.circle_blocked(p.pos.x, p.pos.y, GameState.PLAYER_R - 0.02):
				bad += 1
				break
	check("Движение по диагонали: персонаж не входит в стены/мебель (200 случайных маршрутов)", bad == 0, "%d раз игрок оказался внутри препятствия" % bad)
	p.pos = Vector2(0.5, 0.5)
	p.move = Vector2(-1, -1)
	for i in 120:
		g.update(1.0 / 60.0)
	check("Движение: нельзя выйти за край карты", p.pos.x >= 0.0 and p.pos.y >= 0.0, "pos %s" % p.pos)

## Если персонаж оказался внутри препятствия, режим «застрял» не должен позволять проходить сквозь стены
func test_stuck_escape() -> void:
	var g := _game()
	var wc := _find_wall(g)
	var p: GameState.Player = g.players[0]
	p.pos = Vector2(wc.x + 0.5, wc.y + 0.5)   # прямо внутри стены
	p.move = Vector2(1, 0)                       # вдоль стены
	var max_inside := 0
	var inside := 0
	for i in 180:
		g.update(1.0 / 60.0)
		if g.world.circle_blocked(p.pos.x, p.pos.y, GameState.PLAYER_R - 0.02):
			inside += 1
			max_inside = maxi(max_inside, inside)
		else:
			inside = 0
	check("Застревание: из стены выталкивает, а не даёт идти внутри неё", max_inside < 20, "игрок шёл внутри стен %d кадров подряд, до %s" % [max_inside, p.pos])

func test_remote_teleport() -> void:
	var g := _game()
	var f := g.join_player("t1", "Друг")
	var start := f.pos
	var fs := f.force_seq
	var o := {"mx": 0.0, "my": 0.0, "run": false, "fs": fs, "fx": 1.0, "fy": 0.0}
	for k in 10:
		o["x"] = f.pos.x + 3.9
		o["y"] = f.pos.y
		g.remote_input(f, o)
	check("Сеть: игрок не может телепортироваться (10 пакетов по 3.9 клетки)", f.pos.distance_to(start) < 3.0, "сдвинулся на %.1f клеток мгновенно" % f.pos.distance_to(start))

## Некорректные числа и типы в пакете движения: сервер их отбрасывает, мир и сохранение остаются целыми (BF-028)
func test_bad_input() -> void:
	var g := _game()
	var f := g.join_player("bad-input", "Друг")
	var spot := _open_spot(g)
	var bads := [NAN, INF, -INF, 1e30, -1e30, "12", null, [1.0], {}]
	var broken := 0
	var jumped := 0
	var cases := 0
	for k in ["x", "y", "mx", "my", "fx", "fy"]:
		for v in bads:
			cases += 1
			g.push_player(f, spot)
			f.last_in_ms = Time.get_ticks_msec() - 50
			f.move_budget = 2.5
			var o := {"mx": 0.0, "my": 0.0, "run": false, "fs": f.force_seq, "fx": 1.0, "fy": 0.0, "x": spot.x + 0.1, "y": spot.y}
			o[k] = v
			g.remote_input(f, o)
			if not (is_finite(f.pos.x) and is_finite(f.pos.y) and is_finite(f.face.x) and is_finite(f.face.y) and is_finite(f.move.x) and is_finite(f.move.y)):
				broken += 1
			# следующий пакет с дальней точкой не должен пройти, что бы ни было до него
			f.last_in_ms = Time.get_ticks_msec() - 50
			g.remote_input(f, {"mx": 0.0, "my": 0.0, "run": false, "fs": f.force_seq, "fx": 1.0, "fy": 0.0, "x": spot.x + 30.0, "y": spot.y})
			if is_finite(f.pos.x) and f.pos.distance_to(spot) > 3.0:
				jumped += 1
	check("Сеть: некорректные числа в пакете движения отбрасываются (%d случаев)" % cases, broken == 0 and jumped == 0,
		"испорчено %d, прыжков после этого %d" % [broken, jumped])
	f.last_in_ms = Time.get_ticks_msec() - 50
	g.remote_input(f, {"mx": NAN, "my": 0.0, "run": false, "fs": f.force_seq, "fx": NAN, "fy": 0.0, "x": NAN, "y": NAN})
	g.actions.append([f.id, {"a": "interact", "c": NAN}])
	g.actions.append([f.id, {"a": "interact", "c": INF}])
	g.update(0.016)
	var back = JSON.parse_string(JSON.stringify(g.to_data()))
	check("Сохранение: после плохих пакетов мир сохраняется и читается обратно", back is Dictionary and GameState.valid_save(back))
	# даже если позиция всё же испортилась — нечитаемый мир не записывается поверх рабочего файла
	Saves.delete()
	Saves.save(g)
	var good := GameState.save_text(g.to_data())
	var keep := f.pos
	f.pos = Vector2(NAN, NAN)
	var bad_text := GameState.save_text(g.to_data())
	Saves.save(g)
	f.pos = keep
	var loaded := Saves.load_game()
	check("Сохранение: испорченный мир не затирает рабочий файл", good != "" and bad_text == "" and loaded != null and loaded.player(f.id) != null and loaded.player(f.id).pos.is_finite())
	Saves.delete()

func test_remote_wall() -> void:
	var g := _game()
	var wc := _find_wall(g)
	var f := g.join_player("t2", "Друг")
	f.pos = Vector2(wc.x + 0.5, wc.y - 0.4)
	var o2 := {"mx": 0.0, "my": 0.0, "run": false, "fs": f.force_seq, "fx": 0.0, "fy": 1.0, "x": f.pos.x, "y": wc.y + 0.5}
	g.remote_input(f, o2)
	check("Сеть: игрок не может прислать позицию внутри стены", not g.world.circle_blocked(f.pos.x, f.pos.y, 0.25), "позиция %s внутри стены принята" % f.pos)

## Позиция за стеной или закрытой дверью (в пределах запаса хода) — сервер не принимает (BF-024)
func test_remote_through() -> void:
	var g := _game()
	var w := g.world
	var f := g.join_player("t3", "Друг")
	var tried := {"стена": 0, "дверь": 0}
	var passed := 0
	for y in range(2, w.h - 2):
		for x in range(2, w.w - 2):
			var tt := w.t(x, y)
			if tt != GameWorld.WALL and tt != GameWorld.DOOR:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if w.solid(x - d.x, y - d.y) or w.solid(x + d.x, y + d.y):
					continue
				var a := Vector2(x + 0.5, y + 0.5) - Vector2(d) * 1.0
				var b := Vector2(x + 0.5, y + 0.5) + Vector2(d) * 1.0
				if w.circle_blocked(a.x, a.y, GameState.PLAYER_R) or w.circle_blocked(b.x, b.y, GameState.PLAYER_R):
					continue
				tried["стена" if tt == GameWorld.WALL else "дверь"] += 1
				g.push_player(f, a)
				f.move_budget = 2.5
				g.remote_input(f, {"mx": 0.0, "my": 0.0, "run": true, "fs": f.force_seq, "fx": 1.0, "fy": 0.0, "x": b.x, "y": b.y})
				if f.pos.distance_to(b) < 0.01:
					passed += 1
	check("Сеть: нельзя прислать позицию за стеной или закрытой дверью (%d стен, %d дверей)" % [tried["стена"], tried["дверь"]],
		passed == 0 and tried["стена"] > 0 and tried["дверь"] > 0, "прошёл насквозь %d раз" % passed)

func test_remote_actions() -> void:
	var g := _game()
	var f := g.join_player("t3", "Друг")
	f.inv = []
	g.actions.append([f.id, {"a": "use", "id": "water"}])
	g.actions.append([f.id, {"a": "drop", "id": "pistol"}])
	g.actions.append([f.id, {"a": "put", "c": 0, "id": "ammo"}])
	g.actions.append([f.id, {"a": "treat", "part": 2, "w": "bandage"}])    # такого действия больше нет — должно игнорироваться
	g.actions.append([f.id, {"a": "interact", "c": 999999}])
	g.actions.append([f.id, {"a": "take", "c": -5, "id": "x"}])
	g.actions.append([f.id, {"a": "unknown"}])
	g.actions.append([f.id, {}])
	g.update(0.016)
	check("Сеть: действия с несуществующими предметами/клетками не ломают сервер и ничего не создают", f.inv.is_empty(), "инвентарь: %s" % str(f.inv))
	# механики Zomboid убраны: шкаф не обыскивается, окно не разбивается, даже если попросить вплотную
	var fr := -1
	var win := -1
	for i in g.world.tiles.size():
		if fr < 0 and g.world.t_at(i) == W.FRIDGE:
			fr = i
		if win < 0 and g.world.t_at(i) == W.WINDOW:
			win = i
	for c in [fr, win]:
		var cc := Vector2(c % 100 + 0.5, c / 100 + 0.5)
		for k in 4:
			var n := cc + Vector2(GameWorld.DX4[k], GameWorld.DY4[k])
			if not g.world.circle_blocked(n.x, n.y, 0.3):
				f.pos = n
				break
		g.actions.append([f.id, {"a": "interact", "c": c}])
		for i in 100:
			g.update(0.02)
	check("РП: шкафы не обыскиваются, окна не разбиваются (механики Zomboid убраны)", g.world.t_at(fr) == W.FRIDGE and g.world.t_at(win) == W.WINDOW and f.inv.is_empty(),
		"шкаф: %d, окно: %d, инв %s" % [g.world.t_at(fr), g.world.t_at(win), f.inv])

func test_saves() -> void:
	var g := _game()
	var d := g.to_data()
	var g2 := GameState.new(0)
	g2.load_data(JSON.parse_string(JSON.stringify(d)))
	var same := g2.players.size() == g.players.size()
	for p: GameState.Player in g.players:
		var q := g2.player(p.id)
		if q == null or JSON.stringify(g2.player_data(q)) != JSON.stringify(g.player_data(p)):
			same = false
	check("Сохранение: мир и игроки восстанавливаются (все поля карточки)", same and g2.world.tiles == g.world.tiles)
	var partial := d.duplicate(true)
	partial.erase("time")
	var g3 := GameState.new(0)
	g3.load_data(partial)
	var pp: Dictionary = partial["p"][0]
	pp.erase("hp")
	pp.erase("inf")
	var g4 := GameState.new(0)
	g4.load_data(partial)
	check("Сохранение: файл без части полей загружается со значениями по умолчанию", g4.players.size() == 1 and g4.players[0].hp == 100.0, "загрузка упала")
	var path := "user://save.json"
	Saves.delete()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"v\": 2, \"time\": 5, \"tiles\": \"AAAA\", \"p\": [")   # обрезанный файл
	f.close()
	var broken := Saves.load_game()
	check("Сохранение: повреждённый файл без резервной копии не загружается и не роняет игру", broken == null)
	Saves.save(g)
	Saves.save(g)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("мусор")
	f.close()
	var restored := Saves.load_game()
	check("Сохранение: при порче основного файла берётся резервная копия", restored != null, "резервной копии нет — прогресс потерян")

func _try_load(g: GameState, d: Dictionary) -> bool:
	# GDScript не ловит исключения, поэтому проверяем сами ключи, к которым загрузка обращается напрямую
	for k in ["time", "tiles"]:
		if not d.has(k):
			return false
	g.load_data(d)
	return true

func test_world_gen() -> void:
	var a := GameState.new_game(4242)
	var w := a.world
	var unreachable := 0
	# все двери домов доступны с улицы: поиск в ширину от точки старта
	var seen := PackedByteArray()
	seen.resize(w.w * w.h)
	var q := [a.world.idx(floori(a.players[0].pos.x), floori(a.players[0].pos.y))]
	seen[q[0]] = 1
	while q.size() > 0:
		var i: int = q.pop_back()
		for k in 4:
			var nx: int = i % w.w + GameWorld.DX4[k]
			var ny: int = i / w.w + GameWorld.DY4[k]
			if not w.inside(nx, ny):
				continue
			var ni := w.idx(nx, ny)
			var tt := w.t_at(ni)
			var passable := not (tt == W.WALL or tt == W.TREE or W.is_furniture(tt) or W.is_car(tt) or tt == W.WINDOW)
			if passable and seen[ni] == 0:
				seen[ni] = 1
				q.append(ni)
	for i in w.tiles.size():
		if W.is_floor(w.t_at(i)) and seen[i] == 0:
			unreachable += 1
	check("Мир: все комнаты достижимы через двери", unreachable == 0, "%d клеток пола недостижимы" % unreachable)
	var blocked_furn := 0
	for i in w.tiles.size():
		if W.is_furniture(w.t_at(i)):
			var any := false
			for k in 4:
				var nx: int = i % w.w + GameWorld.DX4[k]
				var ny: int = i / w.w + GameWorld.DY4[k]
				if seen[w.idx(nx, ny)] == 1:
					any = true
			if not any:
				blocked_furn += 1
	check("Мир: к каждой мебели можно подойти", blocked_furn == 0, "%d предметов мебели недоступны" % blocked_furn)


## Проём (дверь/окно) с проходимыми клетками по обе стороны по вертикали
func _find_opening(g: GameState, tile: int) -> Vector2i:
	var w := g.world
	for y in range(3, w.h - 3):
		for x in range(3, w.w - 3):
			if w.t(x, y) == tile and not w.solid(x, y - 1) and not w.solid(x, y + 1) and w.solid(x - 1, y) and w.solid(x + 1, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

## Карта из файла: читается, правильная, плохую не принимает; объекты мешают ходить; двери и игроки после смены карты
func test_map() -> void:
	var d := GameWorld.read_map_file()
	var w := GameWorld.new()
	var err := w.load_map(d)
	var lamps := 0
	for e in w.props:
		if e[0] == "lamp":
			lamps += 1
	check("Карта: maps/city.json читается без ошибок, на ней есть фонари", err == "" and lamps > 0, err)
	check("Карта: точка появления свободна", err == "" and not w.circle_blocked(w.spawn.x, w.spawn.y, GameState.PLAYER_R), "в %s стена или объект" % w.spawn)
	# туда-обратно через текст файла — то же самое
	var w2 := GameWorld.new()
	var err2 := w2.load_map(JSON.parse_string(GameWorld.map_text(w.map_data())))
	check("Карта: сохранение в текст и загрузка обратно ничего не меняют", err2 == "" and w2.tiles == w.tiles and w2.props == w.props and w2.spawn == w.spawn, err2)
	# испорченные карты не принимаются, мир при этом не меняется
	var bads := []
	var b1: Dictionary = d.duplicate(true)
	b1["rows"][3] = "?" + str(b1["rows"][3]).substr(1)
	bads.append(b1)
	var b2: Dictionary = d.duplicate(true)
	b2["rows"][5] = str(b2["rows"][5]).substr(1)
	bads.append(b2)
	var b3: Dictionary = d.duplicate(true)
	b3["props"].append(["нет_такого", 5.0, 5.0, 0])
	bads.append(b3)
	var b4: Dictionary = d.duplicate(true)
	b4["props"].append(["bench", -3.0, 5.0, 0])
	bads.append(b4)
	var b5: Dictionary = d.duplicate(true)
	b5.erase("spawn")
	bads.append(b5)
	var b6: Dictionary = d.duplicate(true)
	b6["w"] = 100000
	bads.append(b6)
	var accepted := 0
	for b in bads:
		if w2.load_map(b) == "":
			accepted += 1
	check("Карта: испорченный файл не принимается и не ломает мир (6 видов)", accepted == 0 and w2.tiles == w.tiles and w2.props == w.props, "принято %d" % accepted)
	# объект мешает ходить так же, как стена
	var g := _game()
	var spot := _open_spot(g)
	g.world.props.append(["hydrant", spot.x + 1.0, spot.y, 0])
	g.world.index_props()
	var p: GameState.Player = g.players[0]
	p.pos = spot
	p.move = Vector2(1, 0)
	for k in 120:
		g.move_player(p, 1.0 / 60.0, true)
	check("Объекты: сквозь гидрант не пройти", p.pos.x < spot.x + 1.0 - 0.3, "игрок дошёл до %s" % p.pos)
	var f := g.join_player("tp", "Друг")
	g.push_player(f, spot)
	f.move_budget = 2.5
	g.remote_input(f, {"mx": 0.0, "my": 0.0, "run": false, "fs": f.force_seq, "fx": 1.0, "fy": 0.0, "x": spot.x + 1.0, "y": spot.y})
	check("Объекты: игрок не может прислать позицию внутри объекта", f.pos.distance_to(Vector2(spot.x + 1.0, spot.y)) > 0.3, "позиция %s принята" % f.pos)
	# клиент получает карту с объектами от сервера
	var c := GameState.new(g.seed)
	c.is_replica = true
	c.load_data(JSON.parse_string(JSON.stringify(g.to_data_for(f.id))))
	check("Сеть: клиент получает карту и объекты от сервера", c.world.tiles == g.world.tiles and c.world.props.size() == g.world.props.size() and c.world.circle_blocked(spot.x + 1.0, spot.y, 0.2))
	# старое сохранение: двери берутся из него, игрок в стене новой карты переставляется
	var door := -1
	for i in g.world.tiles.size():
		if g.world.t_at(i) == GameWorld.DOOR:
			door = i
			break
	var sv := g.to_data()
	var tl := Marshalls.base64_to_raw(sv["tiles"])
	tl[door] = GameWorld.DOOR_OPEN
	tl[0] = GameWorld.GRASS            # прочие клетки сохранения не важны — карта из файла
	sv["tiles"] = Marshalls.raw_to_base64(tl)
	var wall := _find_wall(g)
	for pd in sv["p"]:
		if int(pd["id"]) == f.id:
			pd["x"] = wall.x + 0.5
			pd["y"] = wall.y + 0.5
	var g2 := GameState.new(1)
	g2.load_data(JSON.parse_string(JSON.stringify(sv)))
	var f2 := g2.player(f.id)
	check("Сохранение: открытые двери остаются открытыми, карта — из файла", g2.world.t_at(door) == GameWorld.DOOR_OPEN and g2.world.t_at(0) == g.world.t_at(0))
	check("Сохранение: игрока на месте новой стены переставляет на свободное место", f2 != null and not g2.world.circle_blocked(f2.pos.x, f2.pos.y, GameState.PLAYER_R), "позиция %s" % (f2.pos if f2 else Vector2.ZERO))

## Редактор карты: правки, отмена, машины в 2 клетки, объекты; результат всегда — правильная карта
func test_editor() -> void:
	var ed = load("res://scripts/map_editor.gd").new()
	ed.headless = true
	ed.use_draft = false
	add_child(ed)
	var w: GameWorld = ed.w
	var before := w.tiles.duplicate()
	var props_before: Array = w.props.duplicate(true)
	var spot := Vector2i(-1, -1)
	for y in range(5, w.h - 10):
		for x in range(5, w.w - 10):
			var ok := true
			for dy in 6:
				for dx in 6:
					if w.t(x + dx, y + dy) != W.GRASS:
						ok = false
			if ok:
				spot = Vector2i(x, y)
				break
		if spot.x >= 0:
			break
	ed.begin()
	ed.rect(spot, spot + Vector2i(5, 4), W.WALL, true)
	ed.end()
	var edge_ok := w.t(spot.x, spot.y) == W.WALL and w.t(spot.x + 5, spot.y + 4) == W.WALL and w.t(spot.x + 2, spot.y) == W.WALL
	var inner_ok := w.t(spot.x + 2, spot.y + 2) == W.GRASS
	check("Редактор: «Рамка» ставит стены только по краям", edge_ok and inner_ok and w.buildings.size() > 0)
	ed.begin()
	ed.paint(spot + Vector2i(2, 0), W.DOOR)
	ed.end()
	ed.begin()
	ed.paint(Vector2i(spot.x + 1, spot.y + 6), ed.CAR_H)
	ed.end()
	var car_ok := w.t(spot.x + 1, spot.y + 6) == W.CAR and w.t(spot.x + 2, spot.y + 6) == W.CAR_TAIL
	ed.begin()
	ed.paint(Vector2i(spot.x + 2, spot.y + 6), W.GRASS)
	ed.end()
	var car_gone := not W.is_car(w.t(spot.x + 1, spot.y + 6)) and w.t(spot.x + 2, spot.y + 6) == W.GRASS
	check("Редактор: машина ставится в 2 клетки и убирается целиком", car_ok and car_gone)
	ed.begin()
	var pi: int = ed.place_prop(Vector2(spot.x + 2.5, spot.y + 2.5), "hydrant", 0)
	ed.end()
	var blocked := w.circle_blocked(spot.x + 2.5, spot.y + 2.5, 0.2)
	ed.begin()
	ed.move_prop(pi, Vector2(spot.x + 3.6, spot.y + 2.6))
	ed.rotate_prop(pi, 90)
	ed.end()
	var moved: bool = absf(w.props[pi][1] - (spot.x + 3.5)) < 0.01 and int(w.props[pi][3]) == 90 and w.circle_blocked(spot.x + 3.5, spot.y + 2.5, 0.2) and not w.circle_blocked(spot.x + 2.5, spot.y + 2.5, 0.2)
	check("Редактор: объект ставится, мешает ходить, двигается по сетке 0.25 и поворачивается", pi >= 0 and blocked and moved)
	ed.begin()
	var bad_place: int = ed.place_prop(Vector2(-5, 3), "bench", 0)
	var bad_id: int = ed.place_prop(Vector2(5, 3), "нет_такого", 0)
	var spawn_wall: bool = ed.set_spawn(Vector2(spot.x + 0.5, spot.y + 0.5))
	ed.end()
	check("Редактор: нельзя поставить объект за край, неизвестный объект и спавн в стену", bad_place < 0 and bad_id < 0 and not spawn_wall)
	# всё, что сделал редактор, — правильная карта
	var w2 := GameWorld.new()
	var err := w2.load_map(JSON.parse_string(GameWorld.map_text(w.map_data())))
	check("Редактор: черновик — правильная карта (читается так же, как maps/city.json)", err == "" and w2.tiles == w.tiles and w2.props.size() == w.props.size(), err)
	var n := 0
	while ed.undo():
		n += 1
	check("Редактор: «Отменить» возвращает всё как было (%d шагов)" % n, w.tiles == before and w.props == props_before and w.buildings.size() > 0 and not w.circle_blocked(spot.x + 3.5, spot.y + 2.5, 0.2))
	ed.queue_free()

func test_remote_door() -> void:
	var g := _game()
	var dc := _find_opening(g, W.DOOR)
	var f := g.join_player("d1", "Друг")
	f.pos = Vector2(dc.x + 0.5, dc.y - 0.35)
	var o := {"mx": 0.0, "my": 1.0, "run": false, "fs": f.force_seq, "fx": 0.0, "fy": 1.0,
		"x": dc.x + 0.5, "y": dc.y + 1.35}
	g.remote_input(f, o)
	check("Сеть: игрок не может пройти сквозь закрытую дверь одним пакетом", f.pos.y < dc.y, "дверь %s, друг принят на %s" % [dc, f.pos])

func test_bullet_window() -> void:
	var g := _game()
	var wc := _find_opening(g, W.WINDOW)
	var a := Vector2(wc.x + 0.5, wc.y - 1.5)
	var b := Vector2(wc.x + 0.5, wc.y + 1.5)
	var through_glass := g.world.los(a.x, a.y, b.x, b.y, true)
	var see := g.world.los(a.x, a.y, b.x, b.y)
	check("Бой: через окно видно, но пуля сквозь стекло не проходит", see and not through_glass,
		"видно %s, сквозь стекло %s" % [see, through_glass])


## Честный друг бегает вдоль стен и углов — хост не должен его откатывать
func test_remote_no_false_rollback() -> void:
	var g := _game()
	var f := g.join_player("nr", "Друг")
	var c := GameState.new(g.seed)
	c.is_replica = true
	c.load_data(JSON.parse_string(JSON.stringify(g.to_data())))
	var cf := c.player(f.id)
	var w := g.world
	var routes := 0
	var rollbacks := 0
	for k in 300:
		var st := Vector2(randf_range(2, 98), randf_range(2, 98))
		if w.circle_blocked(st.x, st.y, GameState.PLAYER_R):
			continue
		g.push_player(f, st)
		cf.pos = st
		cf.force_seq = f.force_seq
		cf.move = Vector2.from_angle(randf() * TAU)
		cf.run = randf() < 0.5
		routes += 1
		for i in 120:
			c.move_player(cf, 1.0 / 60.0, false)
			if i % 3 == 2:
				f.last_in_ms = Time.get_ticks_msec() - 50
				var fs := f.force_seq
				g.remote_input(f, {"mx": cf.move.x, "my": cf.move.y, "run": cf.run, "fs": cf.force_seq,
					"fx": cf.face.x, "fy": cf.face.y, "x": cf.pos.x, "y": cf.pos.y})
				if f.force_seq != fs:
					rollbacks += 1
					cf.pos = f.pos
					cf.force_seq = f.force_seq
	check("Сеть: честного игрока не откатывает у стен и углов (%d маршрутов)" % routes, rollbacks == 0, "%d ложных откатов" % rollbacks)
	# BF-024: бег по диагонали в угол — телефон обходит угол «лесенкой», прямая его задевает.
	# Отдельная маленькая карта: три дерева с проходом между ними (место, где случай был пойман)
	var cg := GameState.new(1)
	cg.world = GameWorld.new(20, 20)
	for t in [Vector2i(8, 8), Vector2i(11, 8), Vector2i(8, 10)]:
		cg.world.set_t(t.x, t.y, GameWorld.TREE)
	var tried := 0
	var bad := 0
	# пойманный случай: (59.24, 34.21) → (59.13, 34.31) у деревьев (58,33), (61,33), (58,35), сдвинуто на (-50, -25)
	if not cg._path_free(Vector2(9.24063, 9.21245), Vector2(9.12773, 9.30911)):
		bad += 1
	# и бег к углам с разных сторон: каждые 3 кадра — проверка, как на сервере
	for k in 400:
		var cp := GameState.Player.new(0)
		cp.pos = Vector2(9.5, 9.5) + Vector2.from_angle(TAU * k / 400.0) * (1.4 + (k % 7) * 0.25)
		if cg.world.circle_blocked(cp.pos.x, cp.pos.y, GameState.PLAYER_R):
			continue
		cp.move = (Vector2(9.5, 9.5) - cp.pos).normalized().rotated((k % 9 - 4) * 0.12)
		cp.run = k % 3 != 0
		for f3 in 40:
			var a := cp.pos
			for _k in 3:
				cg.move_player(cp, 1.0 / 60.0, false)
			tried += 1
			if not cg._path_free(a, cp.pos):
				bad += 1
	check("Сеть: бег по диагонали в угол дома не откатывается (BF-024, %d случаев)" % tried, bad == 0, "%d ложных откатов" % bad)


## Друг бежит и останавливается; пакеты 20 раз в секунду приходят с разбросом 20–150 мс (плохой Wi‑Fi).
## Меряем, как его видит другой телефон: замирания посреди бега, рывки и «пробег» после остановки.
func _sim_remote(smooth: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var e := GameState.Player.new(1)
	var clk := GameState.NetClock.new()
	var queue := []                # [время прихода, время отправки, позиция]
	var true_pos := Vector2(10, 10)
	for k in 60:                   # 3 секунды бега, потом 2 секунды стоит
		var ts := k * 50.0
		if ts < 3000.0:
			true_pos = Vector2(10 + 3.9 * ts / 1000.0, 10)
		queue.append([ts + rng.randf_range(20.0, 150.0), ts, true_pos])
	for k in range(60, 100):
		queue.append([k * 50.0 + rng.randf_range(20.0, 150.0), k * 50.0, true_pos])
	queue.sort_custom(func(a, b): return a[0] < b[0])
	var frames := 0
	var frozen := 0
	var max_step := 0.0
	var prev := Vector2(10, 10)
	var stop_frame_pos := Vector2.ZERO
	var overshoot := 0.0
	var qi := 0
	var now := 0.0
	while now < 5000.0:
		now += 1000.0 / 60.0
		while qi < queue.size() and queue[qi][0] <= now:
			var q: Array = queue[qi]
			e.pos = q[2]
			if smooth:
				clk.sample(q[1], now)
				GameState.push_snap(e, q[1], q[2], Vector2(1, 0))
			qi += 1
		if smooth:
			GameState.sample_snaps(e, clk.render_time(now))
		else:
			e.rpos = e.pos              # как было: позиция ставится в момент прихода пакета
		var step := e.rpos.distance_to(prev)
		if now > 400.0 and now < 2900.0:
			frames += 1
			if step < 0.0001:
				frozen += 1
			max_step = maxf(max_step, step)
		overshoot = maxf(overshoot, e.rpos.x - true_pos.x)
		prev = e.rpos
	return [frozen * 100.0 / frames, max_step, overshoot, e.rpos.distance_to(true_pos)]

func test_smooth_remote() -> void:
	var old := _sim_remote(false)
	var neu := _sim_remote(true)
	print("        было: замирал в %.0f%% кадров бега, рывок до %.2f клетки; стало: %.0f%%, рывок до %.2f, пробег %.2f, итог в %.2f от места остановки" % [old[0], old[1], neu[0], neu[1], neu[2], neu[3]])
	check("Сеть: бегущий игрок не замирает и не дёргается на плохом Wi‑Fi", neu[0] < 2.0 and neu[1] < 0.12, "замирал %.0f%%, рывок %.2f" % [neu[0], neu[1]])
	check("Сеть: остановился — стоит на месте, без пробега вперёд", neu[2] < 0.01 and neu[3] < 0.01, "пробег %.2f" % neu[2])

## Удар хоста виден на втором телефоне ровно один раз и с начала, даже если пакеты теряются
func test_attack_sync() -> void:
	var g := _game()
	var p: GameState.Player = g.players[0]
	var c := GameState.new(g.seed)
	c.is_replica = true
	c.load_data(JSON.parse_string(JSON.stringify(g.to_data())))
	g.actions.append([0, {"a": "attack"}])
	g.update(0.016)
	g.update(0.016)
	g.update(0.016)                # первые пакеты потерялись — анимация на хосте уже идёт
	var st := g.state_for(1)
	c.apply_state(st, 1)
	var cp := c.player(0)
	var first := cp.attack_anim
	c.tick_replica(0.1)
	c.apply_state(g.state_for(1), 1)   # повтор того же удара не должен перезапускать анимацию
	check("Сеть: удар другого игрока проигрывается с начала и один раз", first == 1.0 and cp.attack_anim < 1.0, "в начале %.2f, после повтора %.2f" % [first, cp.attack_anim])
	var ev := g.events_for(1, true)
	cp.pos = Vector2(1, 1)
	c.player(0).snaps.append([0.0, 1.0, 1.0, 1.0, 0.0, -1.0])
	c.apply_events(JSON.parse_string(JSON.stringify(ev)), 1)
	check("Сеть: надёжный пакет не откатывает позицию и удар другого игрока", cp.pos == Vector2(1, 1), "позиция откатилась на %s" % cp.pos)


## Дома: окно не упирается во внутреннюю стену/мебель, окно повернуто вдоль стены дома
func test_house_layout() -> void:
	var bad_win := 0
	var bad_dir := 0
	var furn_win := 0
	for sd in [1990]:
		var g := GameState.new_game(sd)
		var w := g.world
		for b in w.buildings:
			var x0: int = b[0]
			var y0: int = b[1]
			var x1: int = b[2]
			var y1: int = b[3]
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					var tt := w.t(x, y)
					if W.is_window_like(tt):
						var top_bottom := (y == y0 or y == y1) and x > x0 and x < x1
						var sides := (x == x0 or x == x1) and y > y0 and y < y1
						if (top_bottom and not w.along_y(x, y)) or (sides and w.along_y(x, y)):
							bad_dir += 1
						var inn := Vector2i(x, y + 1) if y == y0 else (Vector2i(x, y - 1) if y == y1 else (Vector2i(x + 1, y) if x == x0 else Vector2i(x - 1, y)))
						var it := w.t(inn.x, inn.y)
						if it == W.WALL or W.is_door_like(it):
							bad_win += 1
						if W.is_furniture(it):
							furn_win += 1
	check("Дома: внутренняя стена не делит окно и не торчит наружу", bad_win == 0 and bad_dir == 0, "окон в стену: %d, повернуто поперёк: %d" % [bad_win, bad_dir])
	check("Дома: мебель не стоит вплотную к окну", furn_win == 0, "%d окон за мебелью" % furn_win)


## Одежда: надеть/снять без потерь и дублей, рюкзак добавляет вес, сохранение, защита
func test_wear() -> void:
	var g := _game()
	var p: GameState.Player = g.players[0]
	p.inv = [{"id": "hoodie", "n": 1}, {"id": "suit_jacket", "n": 1}, {"id": "dress", "n": 1}]
	p.wear = {"legs": "jeans"}
	g.actions.append([0, {"a": "wear", "id": "hoodie"}])
	for i in 120:
		g.update(0.016)
	g.actions.append([0, {"a": "wear", "id": "suit_jacket"}])
	for i in 120:
		g.update(0.016)
	var swapped: bool = p.wear.get("torso", "") == "suit_jacket" and p.count("hoodie") == 1 and p.count("suit_jacket") == 0
	g.actions.append([0, {"a": "wear", "id": "pistol"}])      # не одежда
	g.actions.append([0, {"a": "wear", "id": "boots"}])       # нет в инвентаре
	g.actions.append([0, {"a": "wear", "id": "dress"}])       # мужчине платье не подходит
	g.actions.append([0, {"a": "unwear", "slot": "nonsense"}])
	for i in 120:
		g.update(0.016)
	check("Одежда: надевается, смена вещи возвращает прежнюю, чужое и неподходящее не надевается",
		swapped and p.wear.get("torso", "") == "suit_jacket" and p.count("dress") == 1 and not p.wear.has("feet") and not p.wear.has("hand"),
		"слоты %s, инв %s" % [p.wear, p.inv])
	var d = JSON.parse_string(JSON.stringify(g.to_data()))
	var g2 := GameState.new(g.seed)
	g2.load_data(d)
	check("Одежда и внешность сохраняются и загружаются", g2.players[0].wear == p.wear and g2.players[0].look == p.look, "%s → %s" % [p.wear, g2.players[0].wear])
	g.actions.append([0, {"a": "unwear", "slot": "torso"}])
	for i in 120:
		g.update(0.016)
	var total := p.count("hoodie") + p.count("suit_jacket") + (1 if p.wear.has("torso") else 0)
	check("Одежда: снять — вещь возвращается в инвентарь, ничего не теряется и не множится", not p.wear.has("torso") and total == 2, "вещей %d" % total)
	# каждая вещь и каждая причёска — существующая часть модели
	var missing := []
	for id in Items.DEFS:
		var dd: Dictionary = Items.DEFS[id]
		if dd["kind"] != Items.Kind.WEAR:
			continue
		for gg in dd.get("parts", {}):
			if not ResourceLoader.exists("res://assets/chars/%s/%s.scn" % [gg, dd["parts"][gg]]):
				missing.append("%s/%s" % [gg, id])
	for gg in Items.HEADS:
		for h in Items.HEADS[gg]:
			if not ResourceLoader.exists("res://assets/chars/%s/%s.scn" % [gg, h]):
				missing.append(h)
		for sl in Items.BARE[gg]:
			if not ResourceLoader.exists("res://assets/chars/%s/%s.scn" % [gg, Items.BARE[gg][sl]]):
				missing.append(Items.BARE[gg][sl])
	check("Персонажи: у всех вещей и причёсок есть модели", missing.is_empty() and ResourceLoader.exists("res://assets/chars/m_base.scn") and ResourceLoader.exists("res://assets/chars/f_base.scn"), str(missing))
	# головной убор заменяет причёску; цветной вариант перекрашивает свой материал (платье — и низ)
	check("Персонажи: каска вместо причёски, цветные варианты перекрашивают нужный материал",
		Items.part_for({"head": "hard_hat"}, "m", "head") == "Worker_Head" and Items.part_for({}, "m", "head") == ""
		and Items.tint_for({"torso": "hoodie_red"}, "m", "torso")[0] == "Purple" and Items.tint_for({"torso": "hoodie"}, "m", "torso").is_empty()
		and Items.tint_for({"torso": "dress_black"}, "f", "legs").size() == 2 and Items.DEFS.has("tshirt_navy") and Items.fits("swat_helmet", "m") and not Items.fits("swat_helmet", "f"))
	# платье закрывает и низ; без одежды — «база»
	check("Персонажи: платье показывает и низ, пустой слот — без одежды",
		Items.part_for({"torso": "dress", "legs": "jeans"}, "f", "legs") == "Formal_Legs" and Items.part_for({}, "m", "torso") == "Beach_Body"
		and Items.part_for({"legs": "jeans"}, "m", "legs") == "Casual2_Legs")

## Пол из базы: внешность меняется, неподходящая одежда уходит в инвентарь; старые сохранения переходят на новую одежду
func test_look() -> void:
	var g := _game()
	var p := g.join_player("sb:girl", "Kate_Morris", 12, "f")
	check("Внешность: пол из базы, причёска женская", p.look.get("g") == "f" and str(p.look.get("h")) in Items.HEADS["f"], str(p.look))
	p.wear["torso"] = "hoodie"
	g.set_gender(p, "f")
	var p2 := g.join_player("sb:girl", "Kate_Morris", 12, "f")
	check("Внешность: повторный вход не меняет причёску", p2.look == p.look)
	var q := g.join_player("sb:guy", "Frank_Russo", 3, "m")
	q.wear = {"torso": "dress", "legs": "jeans"}
	g.set_gender(q, "f")
	g.set_gender(q, "m")
	check("Внешность: неподходящая вещь снимается в инвентарь", not q.wear.has("torso") and q.count("dress") == 1, "%s %s" % [q.wear, q.inv])
	var old := {"v": 1, "time": 100, "tiles": g.to_data()["tiles"], "uids": {}, "p": [
		{"id": 5, "x": 50, "y": 50, "wr": {"legs": "jeans", "back": "bp_hiking", "head": "cap"}, "inv": [{"id": "leather", "n": 1}, {"id": "water", "n": 2}]}]}
	var g3 := GameState.new(0)
	g3.load_data(JSON.parse_string(JSON.stringify(old)))
	var o: GameState.Player = g3.player(5)
	check("Сохранение v1: старая одежда убрана, выдана футболка и кеды, вода на месте",
		o != null and o.wear == {"legs": "jeans", "torso": "tshirt", "feet": "sneakers"} and o.count("water") == 2 and o.count("leather") == 0 and o.look.get("g") == "m",
		"%s %s" % [o.wear if o else "", o.inv if o else ""])

## РП-правила: аккаунт по uid, приватность, драка между игроками, потеря сознания и возвращение
func test_rp_rules() -> void:
	var g := GameState.new_game(1990)
	g.players.clear()            # как на сервере: своего игрока нет
	var a := g.join_player("uid-aaaaaaaa", "Джек")
	var b := g.join_player("uid-bbbbbbbb", "Майк")
	a.money = 1234
	Items.add_to(a.inv, "pistol", 1)
	g.leave_player(a.id)
	var a2 := g.join_player("uid-aaaaaaaa", "Джек")
	check("Аккаунт: тот же телефон возвращается к своему персонажу с деньгами и вещами", a2 == a and a2.money == 1234 and a2.count("pistol") == 1)
	var init := g.to_data_for(b.id)
	var leak := init.has("uids")
	for e in init["p"]:
		if int(e["id"]) == a.id and (e.has("inv") or e.has("mo") or e.has("hp")):
			leak = true
	var ev := g.events_for(b.id, true)
	for e in ev.get("p", []):
		if int(e["id"]) == a.id and (e.has("inv") or e.has("mo")):
			leak = true
	check("Приватность: чужие деньги, вещи и ключи аккаунтов не уходят другим игрокам", not leak, "в пакете для другого игрока есть личные данные")
	# драка: b стоит перед a на открытом месте (место появления случайное — у стены удары отталкивают криво)
	a.pos = _open_spot(g)
	a.face = Vector2(1, 0)
	b.pos = a.pos + Vector2(0.7, 0)
	var hp0 := b.hp
	for k in 60:
		a.cooldown = 0.0
		a.face = Vector2(1, 0)
		g.actions.append([a.id, {"a": "attack"}])
		g.update(0.02)
		b.pos = a.pos + Vector2(0.7, 0)
	check("Драка: удары по другому игроку отнимают здоровье и могут отправить в нокаут", b.hp < hp0 and b.dead, "хп %.0f, без сознания %s" % [b.hp, b.dead])
	for k in int(GameState.RESPAWN_TIME / 0.1) + 5:
		g.update(0.1)
	check("Нокаут: через время игрок очнулся у больницы с вещами", not b.dead and b.hp > 0.0 and b.pos.distance_to(g.spawn) < 3.0, "без сознания %s, позиция %s" % [b.dead, b.pos])

## Двери и эффекты — всем, кто рядом; выстрелы и эффекты — только тем, кто рядом (BF-027, утечка позиций)
func test_events_all() -> void:
	var g := GameState.new_game(1)
	g.players.clear()
	var a := g.join_player("uid-ev-aaaa", "A")
	var b := g.join_player("uid-ev-bbbb", "B")
	var far := g.join_player("uid-ev-far0", "F")
	var door := _find_opening(g, W.DOOR)
	var di := g.world.idx(door.x, door.y)
	a.pos = g.unstick(Vector2(door.x + 0.5, door.y - 1.0), GameState.PLAYER_R)
	b.pos = g.unstick(a.pos + Vector2(1.0, -0.5), GameState.PLAYER_R)
	var corner := Vector2(4.5, 4.5) if Vector2(door).distance_to(Vector2(4, 4)) > Vector2(door).distance_to(Vector2(95, 95)) else Vector2(95.5, 95.5)
	far.pos = g.unstick(corner, GameState.PLAYER_R)
	g.actions.append([a.id, {"a": "interact", "c": di}])
	g.update(0.016)
	var got := 0
	for p: GameState.Player in [a, b, far]:
		var ev := g.events_for(p.id, false)
		for e in ev.get("tc", []):
			if int(e[0]) == di:
				got += 1
	check("Сеть: открытую дверь видят все игроки, а не один (BF-027)", g.world.t_at(di) == W.DOOR_OPEN and got == 3, "получили %d из 3" % got)
	g.world.dirty_tiles.clear()
	g.add_fx(4, a.pos.x, a.pos.y, a.id)
	g.shots.append([a.pos.x, a.pos.y, a.pos.x + 3.0, a.pos.y, 0.08])
	var near_fx := g.events_for(a.id, false).has("fx") and g.events_for(b.id, false).has("fx")
	var far_fx := g.events_for(far.id, false).has("fx")
	var near_sh := g.state_for(b.id).has("sh")
	var far_sh := g.state_for(far.id).has("sh")
	check("Сеть: эффекты и выстрелы получают те, кто рядом, и только они", near_fx and near_sh and not far_fx and not far_sh,
		"рядом: эффект %s, выстрел %s; далеко (%.0f клеток): эффект %s, выстрел %s" % [near_fx, near_sh, far.pos.distance_to(a.pos), far_fx, far_sh])

## Скорость по сети зависит от выносливости; бег тратит выносливость по пройденному пути, а не по словам клиента
func _net_run(lie: bool, honest_client: bool, seconds: float) -> Array:
	var g := GameState.new_game(1)
	g.players.clear()
	var f := g.join_player("uid-run-%s%s" % [lie, honest_client], "R")
	f.pos = Vector2(2.5, 1.5)       # ряд 1 — асфальт через всю карту
	g.push_player(f, f.pos)
	var rb := 0
	var moved := 0.0
	var moved_last := 0.0          # за последние 5 секунд — когда выносливость уже кончилась
	var dir := 1.0
	var steps := int(seconds / 0.05)
	for k in steps:
		f.last_in_ms = Time.get_ticks_msec() - 50
		# честный телефон бежит со скоростью, которую ему разрешает его выносливость (её присылает сервер)
		var sp := 3.9
		if honest_client:
			sp = 3.9 if f.stamina > 1.0 else 2.3
			if f.stamina < 10.0:
				sp *= 0.8
		var np := f.pos + Vector2(sp * 0.05 * dir, 0)
		if np.x > 97.0 or np.x < 2.0:
			dir = -dir
			np = f.pos
		var fs := f.force_seq
		var old := f.pos
		g.remote_input(f, {"mx": 0.0 if lie else dir, "my": 0.0, "run": not lie, "fs": f.force_seq, "fx": dir, "fy": 0.0, "x": np.x, "y": np.y})
		if f.force_seq != fs:
			rb += 1
		moved += f.pos.distance_to(old)
		if k >= steps - 100:
			moved_last += f.pos.distance_to(old)
		g.update(0.05)
	return [moved, f.stamina, rb, moved_last]

func test_stamina_net() -> void:
	var cheat := _net_run(true, false, 20.0)
	# без выносливости разрешён шаг (2.3 × 0.8 при усталости) с запасом 1.25 — не больше ~2.9 клетки/с
	check("Сеть: «стою», а сам бегу — выносливость тратится, без неё скорость не выше шага (последние 5 с: %.1f клетки)" % cheat[3],
		cheat[1] < 30.0 and cheat[1] >= 0.0 and cheat[3] < 5.0 * 2.3 * 1.25 * 1.1, "выносливость %.0f, за последние 5 с %.1f клетки, откатов %d" % [cheat[1], cheat[3], cheat[2]])
	var honest := _net_run(false, true, 40.0)
	check("Сеть: честный бег до усталости и дальше — без откатов", honest[2] == 0, "откатов %d, выносливость %.0f" % [honest[2], honest[1]])

## Защита сервера: лимиты действий и пакетов, размер сообщений, формат токена, без пересылки между клиентами
func test_server_guards() -> void:
	var S = load("res://scripts/server_only/server.gd")
	var b = S.Bucket.new(10.0, 15.0)
	var burst := 0
	for i in 100:
		if b.take(100.0):
			burst += 1
	var next := 0
	for i in 100:
		if b.take(101.0):
			next += 1
	check("Сервер: действий не больше 15 разом и 10 в секунду (остальные отбрасываются)", burst == 15 and next == 10, "разом %d, через секунду %d" % [burst, next])
	var ins = S.Bucket.new(40.0, 40.0)
	var honest := 0
	for k in 200:                      # честный телефон: 20 пакетов в секунду, 10 секунд
		if ins.take(200.0 + k * 0.05):
			honest += 1
	check("Сервер: честные 20 пакетов движения в секунду проходят все", honest == 200, "%d из 200" % honest)
	var tok := "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
	var bad_tokens := ["", "short", tok + "\r\nX-Evil: 1", tok + " ", "x".repeat(5000), tok + "\t", tok + "\n"]
	var bad_ok := 0
	for t in bad_tokens:
		if S.valid_token(t):
			bad_ok += 1
	check("Сервер: токен неверного формата не идёт в Supabase", S.valid_token(tok) and bad_ok == 0, "принято плохих %d" % bad_ok)
	var small := {"t": "hello", "token": tok, "legacy": "a".repeat(24), "uid": "a".repeat(24), "nick": "N", "build": "21", "_from": 5}
	var huge := {"t": "act", "a": "use", "id": "x".repeat(10000), "_from": 5}
	check("Сервер: слишком большое сообщение распознаётся, обычное — нет", not S.too_big(small) and S.too_big(huge))
	check("Сеть: сервер не пересылает пакеты между клиентами", (Net.I.multiplayer as SceneMultiplayer).server_relay == false)

## Карточка игрока: постоянный ID из базы, деньги и вещи остаются за ним
func test_player_card() -> void:
	var g := _game()
	var p := g.join_player("legacy-uid", "Epson_Drowe")
	check("ID: игрок без аккаунта получает номер от миллиона", p.id >= 1000000, str(p.id))
	p.money = 777
	p.bank = 1234
	p.inv.append({"id": "medkit", "n": 1})
	var inv_n := p.inv.size()
	# тот же человек вошёл через аккаунт: старая карточка переезжает на ID из базы
	g.uids["sb:u2"] = g.uids["legacy-uid"]
	g.uids.erase("legacy-uid")
	var a := g.join_player("sb:u2", "Epson_Drowe", 2)
	check("ID: аккаунт получает ID из базы", a.id == 2 and g.player(2) == a, str(a.id))
	check("ID: деньги, счёт и вещи переехали вместе с карточкой", a.money == 777 and a.bank == 1234 and a.inv.size() == inv_n)
	check("ID: тег — «Имя (ID)»", GameState.tag(a) == "Epson_Drowe (2)", GameState.tag(a))
	# ID 5 занят кем-то без аккаунта — владелец номера из базы его забирает
	var guest := g.join_player("guest", "Guest_One")
	var gid := guest.id
	g._move_id(guest, 5)
	var b := g.join_player("sb:u5", "John_Miller", 5)
	check("ID: чужой номер освобождается для владельца", b.id == 5 and guest.id != 5 and g.player(guest.id) == guest and g.uids["guest"] == guest.id, "%d %d" % [b.id, gid])
	# повторный вход — та же карточка
	b.bank = 50
	var b2 := g.join_player("sb:u5", "John_Miller", 5)
	check("ID: повторный вход — та же карточка", b2 == b and b2.bank == 50)
	# счёт сохраняется в файл мира
	var g2 := GameState.new(0)
	g2.load_data(JSON.parse_string(JSON.stringify(g.to_data())))
	var a2 := g2.player(2)
	check("ID: счёт и наличные сохраняются в мире", a2 != null and a2.bank == 1234 and a2.money == 777 and int(g2.uids.get("sb:u2", -1)) == 2)

## Время — московское, темно только ночью
func test_clock() -> void:
	var g := _game()
	g.update(0.016)
	var utc := Time.get_datetime_dict_from_system(true)
	var want := fmod(utc["hour"] + 3 + utc["minute"] / 60.0, 24.0)
	var diff := absf(g.hour_f() - want)
	check("Время: в игре московское", minf(diff, 24.0 - diff) < 0.05, "%.2f, ждали %.2f" % [g.hour_f(), want])
	var msk := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + GameState.MSK_OFFSET)
	check("Время: дата по Москве", g.date_str() == "%d %s" % [msk["day"], GameState.MONTHS[msk["month"] - 1]], g.date_str())
	var dk := []
	for h in [3.0, 7.0, 13.0, 20.5, 23.0]:
		g.time = h * 60.0
		dk.append(g.darkness())
	check("Время: темно только ночью (07–21 светло, 23 и 3 — ночь)", dk[0] == 1.0 and dk[1] == 0.0 and dk[2] == 0.0 and dk[3] == 0.0 and dk[4] == 1.0, str(dk))

## Сохранение v2 с остатками Zomboid: разбитое окно и выбитая дверь превращаются в обычные, лишние поля не мешают
func test_old_world() -> void:
	var g := _game()
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_data()))
	var win := _find_opening(g, W.WINDOW)
	var door := _find_opening(g, W.DOOR)
	var t := Marshalls.base64_to_raw(d["tiles"])
	t[g.world.idx(win.x, win.y)] = W.OLD_WINDOW_BROKEN
	t[g.world.idx(door.x, door.y)] = W.OLD_DOOR_BROKEN
	d["tiles"] = Marshalls.raw_to_base64(t)
	d["v"] = 2
	d["thp"] = [[5, 40.0]]
	d["cont"] = {"7": [{"id": "water", "n": 1}]}
	(d["p"][0] as Dictionary)["cl"] = 0.5
	(d["p"][0] as Dictionary)["k"] = 3
	var g2 := GameState.new(0)
	g2.load_data(d)
	var bad := 0
	for i in g2.world.tiles.size():
		if g2.world.t_at(i) == W.OLD_WINDOW_BROKEN or g2.world.t_at(i) == W.OLD_DOOR_BROKEN:
			bad += 1
	var saved: Dictionary = g2.to_data()
	check("Сохранение v2: разбитые окна и выбитые двери стали целыми, старые поля Zomboid не сохраняются",
		bad == 0 and g2.world.t(win.x, win.y) == W.WINDOW and g2.world.t(door.x, door.y) == W.DOOR_OPEN and not saved.has("cont") and not saved.has("thp") and int(saved["v"]) == 3,
		"осталось сломанных %d, окно %d, дверь %d" % [bad, g2.world.t(win.x, win.y), g2.world.t(door.x, door.y)])
