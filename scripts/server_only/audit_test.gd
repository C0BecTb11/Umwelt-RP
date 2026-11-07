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
	# карта игры с 0.45 чистая — тесты идут на тестовом городе (дома, двери, окна, фонари)
	GameWorld.map_path = GameWorld.TEST_MAP_PATH
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
	test_overview()
	test_stale_draft()
	test_roofs()
	test_city_map()
	test_furniture_collision()
	test_attack_walk()
	test_payday()
	test_chat()
	test_editor()
	test_editor_resize()
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
	test_visibility()
	test_spawn_spot()
	test_grid()
	test_pub_cache()
	test_map_pack()
	test_world_textures()
	test_road_lines()
	test_water()
	test_editor_speed_roads()
	await test_big_map()
	test_stamina_net()
	test_server_guards()
	test_dtls()
	test_update_signature()
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
	var game_map = JSON.parse_string(FileAccess.get_file_as_string(GameWorld.MAP_PATH))
	var gw := GameWorld.new()
	var gerr: String = gw.load_map(game_map) if game_map is Dictionary else "не JSON"
	check("Карта игры (maps/city.json) читается без ошибок, точка появления свободна", gerr == ""
		and not gw.circle_blocked(gw.spawn.x, gw.spawn.y, GameState.PLAYER_R), gerr)
	var d := GameWorld.read_map_file()
	var w := GameWorld.new()
	var err := w.load_map(d)
	var lamps := 0
	for e in w.props:
		if e[0] == "lamp":
			lamps += 1
	check("Карта: тестовый город читается без ошибок, на нём есть фонари", err == "" and lamps > 0, err)
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
## Размер карты в редакторе (BF-053): только больше, город остаётся на месте (левый верхний угол), новое — трава
func test_editor_resize() -> void:
	var ed = load("res://scripts/map_editor.gd").new()
	ed.headless = true
	ed.use_draft = false
	add_child(ed)
	var w: GameWorld = ed.w
	var ow := w.w
	var oh := w.h
	var old_tiles := w.tiles.duplicate()
	var old_props := JSON.stringify(w.props)
	var old_spawn := w.spawn
	var no_shrink: String = ed.resize_map(ow - 10, oh)
	var no_huge: String = ed.resize_map(GameWorld.MAX_SIDE + 1, GameWorld.MAX_SIDE + 1)
	var err: String = ed.resize_map(300, 250)
	var w2: GameWorld = ed.w
	var same := true
	for y in oh:
		for x in ow:
			if w2.t(x, y) != old_tiles[y * ow + x]:
				same = false
	var grass := w2.t(299, 249) == W.GRASS and w2.t(ow + 5, 3) == W.GRASS and w2.t(3, oh + 5) == W.GRASS
	check("Редактор: размер карты — только больше, до %d; город на месте, новое место — трава (BF-053)" % GameWorld.MAX_SIDE,
		no_shrink != "" and no_huge != "" and err == "" and w2.w == 300 and w2.h == 250 and same and grass
		and JSON.stringify(w2.props) == old_props and w2.spawn == old_spawn,
		"«%s» / «%s» / «%s», %d×%d, город на месте: %s, трава: %s" % [no_shrink, no_huge, err, w2.w, w2.h, same, grass])
	var back := GameWorld.new()
	check("Редактор: увеличенная карта проходит формат файла (map_text → load_map)", back.load_map(JSON.parse_string(_map_json(w2))) == "" and back.w == 300)
	ed.queue_free()

func _map_json(w: GameWorld) -> String:
	return JSON.stringify(w.map_data())

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

func _ids(a: Array) -> Array:
	var r := []
	for p in a:
		r.append(p.id)
	r.sort()
	return r

func _ids_st(o: Dictionary) -> Array:
	var r := []
	var ps: PackedFloat32Array = o["p"]
	var i := 0
	while i + 9 < ps.size():
		r.append(int(ps[i]))
		i += 10
	r.sort()
	return r

func _ids_list(a: Array) -> Array:
	var r := []
	for e in a:
		r.append(int(e["id"]))
	r.sort()
	return r

## BF-049: сетка по районам даёт ровно тех же видимых, что и перебор всех со всеми
func test_grid() -> void:
	var g := GameState.new_game(1)
	g.players.clear()
	var w := g.world
	var all: Array = []
	for i in 400:
		var p := g.join_player("uid-grid-%05d-xxxxxxxx" % i, "G%d" % i)
		# по всей карте, гуще у точки появления; часть — в домах, часть вне сети
		var c := g.spawn + Vector2(randf_range(-30, 30), randf_range(-30, 30)) if i % 2 == 0 else Vector2(randf_range(1, w.w - 1), randf_range(1, w.h - 1))
		p.pos = c
		if i % 9 == 0:
			g.leave_player(p.id)
		all.append(p)
	var bad := 0
	var checked := 0
	var bad_msg := ""
	for p in all:
		if not p.connected:
			continue
		g.grid_on = false
		var plain := _ids(g.visible_to(p.id))
		var st_plain := _ids_st(g.state_for(p.id))
		var ev_plain := _ids_list(g.events_for(p.id, true, true).get("p", []))
		var in_plain := _ids_list(g.to_data_for(p.id)["p"])
		g.index_players()
		var grid := _ids(g.visible_to(p.id))
		var st_grid := _ids_st(g.state_for(p.id))
		var ev_grid := _ids_list(g.events_for(p.id, true, true).get("p", []))
		var in_grid := _ids_list(g.to_data_for(p.id)["p"])
		g.grid_on = false
		checked += 1
		if plain != grid or st_plain != st_grid or ev_plain != ev_grid or in_plain != in_grid:
			bad += 1
			if bad_msg == "":
				bad_msg = "игрок %d: перебор %s, сетка %s" % [p.id, plain, grid]
	check("Видимость: сетка по районам = перебор всех (400 игроков, все пакеты, BF-049)", bad == 0 and checked > 300,
		"не совпало у %d из %d; %s" % [bad, checked, bad_msg])
	# на краях районов: игрок ровно на границе клеток сетки и в 19.9 клетки от соседа
	var h := GameState.new_game(1)
	h.players.clear()
	var a := h.join_player("uid-edge-aaaaaaaaaaaa", "EA")
	var b := h.join_player("uid-edge-bbbbbbbbbbbb", "EB")
	a.pos = Vector2(GameState.SEE_R * 2.0 - 0.05, 60.5)
	b.pos = a.pos + Vector2(19.9, 0.0)
	var vis_plain := _ids(h.visible_to(a.id))
	h.index_players()
	var vis_grid := _ids(h.visible_to(a.id))
	h.grid_on = false
	check("Видимость: на границе районов сетки сосед в 19.9 клетки виден так же", vis_plain == vis_grid,
		"перебор %s, сетка %s (в домах: %d, %d)" % [vis_plain, vis_grid, h.building_at(a.pos), h.building_at(b.pos)])

## BF-050: внешность и одежду других сервер шлёт только новым в поле зрения или изменившимся
func test_pub_cache() -> void:
	var g := GameState.new_game(1)
	g.players.clear()
	var a := g.join_player("uid-pub-aaaaaaaaaaaa", "PA")
	var b := g.join_player("uid-pub-bbbbbbbbbbbb", "PB")
	var c := g.join_player("uid-pub-cccccccccccc", "PC")
	for p: GameState.Player in [a, b, c]:
		p.pos = g.spawn + Vector2(randf_range(-1, 1), randf_range(-1, 1))
	g.forget_sent(a.id)
	var first := _ids_list(g.events_for(a.id, true).get("p", []))
	var second := _ids_list(g.events_for(a.id, true).get("p", []))
	b.wear["head"] = "hard_hat"
	var third := _ids_list(g.events_for(a.id, true).get("p", []))
	b.pos += Vector2(0.5, 0)      # движение — не повод слать внешность (оно идёт снимками)
	var fourth := _ids_list(g.events_for(a.id, true).get("p", []))
	g.forget_sent(a.id)            # вход заново — всё снова
	var fifth := _ids_list(g.events_for(a.id, true).get("p", []))
	check("Трафик: чужая внешность — при первом показе и при изменении, своё — всегда (BF-050)",
		first == [a.id, b.id, c.id] and second == [a.id] and third == [a.id, b.id] and fourth == [a.id] and fifth == [a.id, b.id, c.id],
		"1: %s, 2: %s, 3: %s, 4: %s, 5: %s" % [first, second, third, fourth, fifth])
	# телефон: игрок, о котором в этот раз ничего не пришло, не теряет внешность
	var r := GameState.new_game(1)
	r.is_replica = true
	r.players.clear()
	r.apply_events({"t": "ev", "p": [g.player_public(b)]}, a.id)
	r.apply_events({"t": "ev", "p": []}, a.id)
	check("Трафик: на телефоне внешность игрока сохраняется, пока не пришла новая", r.player(b.id) != null and r.player(b.id).wear.get("head", "") == "hard_hat")

## BF-051: карта при входе — сжатая и только из кэша; большая карта проходит туда-обратно без потерь
func test_map_pack() -> void:
	var g := GameState.new_game(1)
	var md := g.world.map_data()
	var pk: Array = GameState.pack_map(md)
	var back = GameState.unpack_map(pk[0], pk[1])
	check("Карта при входе: сжатие и распаковка дают ту же карту", back is Dictionary and JSON.stringify(back) == JSON.stringify(md),
		"сжато %d байт из %d" % [(pk[0] as PackedByteArray).size(), pk[1]])
	# карта 400×400 (предел размера) с объектами — размер сообщения и время
	var big := {"v": 1, "w": 400, "h": 400, "spawn": [200.5, 200.5], "rows": [], "props": []}
	var chars := ".=-wt#Dd"
	for y in 400:
		var row := ""
		for x in 400:
			row += chars[(x / 7 + y / 5 + (x * y) % 3) % chars.length()] if (x % 20 < 14) else "="
		big["rows"].append(row)
	for i in 2000:
		big["props"].append(["lamp", 1.0 + i % 390, 1.0 + i / 6 % 390, 0])
	var t0 := Time.get_ticks_usec()
	var bp: Array = GameState.pack_map(big)
	var t1 := Time.get_ticks_usec()
	var bb = GameState.unpack_map(bp[0], bp[1])
	var t2 := Time.get_ticks_usec()
	var ww := GameWorld.new()
	var err: String = ww.load_map(bb) if bb is Dictionary else "не распаковалась"
	check("Карта при входе: 400×400 и 2000 объектов — без потерь, сжато, быстро",
		err == "" and (bp[0] as PackedByteArray).size() < bp[1] / 3 and (t1 - t0) < 500000 and (t2 - t1) < 500000,
		"ошибка «%s»; %d КБ из %d КБ; сжатие %d мс, распаковка %d мс" % [err, (bp[0] as PackedByteArray).size() / 1024, int(bp[1]) / 1024, (t1 - t0) / 1000, (t2 - t1) / 1000])
	check("Карта при входе: испорченные данные не роняют игру", GameState.unpack_map(PackedByteArray([1, 2, 3]), 100) == null and GameState.unpack_map(PackedByteArray(), 999999999) == null)

## Карта игры (0.49, город из docs/tools/build_city.py): не меньше 150 домов, у каждого крыша, к каждой наружной
## двери можно дойти пешком от точки появления (двери открываются; вода — только по мосту)
func test_city_map() -> void:
	var w := GameWorld.new()
	var err := w.load_map(JSON.parse_string(FileAccess.get_file_as_string(GameWorld.MAP_PATH)))
	var wm := WorldMesh.new(w)
	var m := Mesher.new()
	var noroof := 0
	for bi in w.buildings.size():
		wm.build_roof(m, bi)
		if m.verts.size() == 0:
			noroof += 1
	var n := w.w * w.h
	var ok := PackedByteArray()
	ok.resize(n)
	for y in w.h:
		for x in w.w:
			if w.t(x, y) == W.DOOR or not w.circle_blocked(x + 0.5, y + 0.5, 0.3):
				ok[y * w.w + x] = 1
	var seen := PackedByteArray()
	seen.resize(n)
	var s0 := int(w.spawn.y) * w.w + int(w.spawn.x)
	var q := PackedInt32Array([s0])
	seen[s0] = 1
	var head := 0
	while head < q.size():
		var i := q[head]
		head += 1
		var x := i % w.w
		for nb in [i - 1 if x > 0 else -1, i + 1 if x < w.w - 1 else -1, i - w.w, i + w.w]:
			if nb >= 0 and nb < n and seen[nb] == 0 and ok[nb] == 1:
				seen[nb] = 1
				q.append(nb)
	var doors := 0
	var lost := []
	for i in n:
		if w.tiles[i] == W.DOOR:
			doors += 1
			if seen[i] == 0:
				lost.append(Vector2i(i % w.w, i / w.w))
	check("Карта игры: город — не меньше 150 домов, у всех крыша, ко всем наружным дверям можно дойти от точки появления",
		err == "" and w.buildings.size() >= 150 and noroof == 0 and doors >= w.buildings.size() and lost.is_empty(),
		"ошибка «%s», домов %d, без крыши %d, дверей %d, недостижимы %s" % [err, w.buildings.size(), noroof, doors, lost.slice(0, 5)])
	# дорожки (BF-063): у каждого дома хотя бы от одной наружной двери плитка идёт прямо до тротуара дороги
	var walked := {}
	for i in n:
		if w.tiles[i] != W.DOOR or w.building_of[i] < 0:
			continue
		var dx0 := i % w.w
		var dy0 := i / w.w
		for k in 4:
			var cx: int = dx0 + W.DX4[k]
			var cy: int = dy0 + W.DY4[k]
			var reach := false
			for step in 26:
				if not w.inside(cx, cy):
					break
				if w.on_line_road(Vector2(cx + 0.5, cy + 0.5), -1, true, 0.5):
					reach = step > 0 or w.t(cx, cy) == W.SIDEWALK
					break
				if w.t(cx, cy) != W.SIDEWALK:
					break
				cx += W.DX4[k]
				cy += W.DY4[k]
			if reach:
				walked[w.building_of[i]] = true
	var nowalk := []
	for bi in w.buildings.size():
		if not walked.has(bi):
			nowalk.append(w.buildings[bi].slice(0, 2))
	var on_road := []
	for e in w.props:
		if w.on_line_road(Vector2(float(e[1]), float(e[2])), -1):
			on_road.append(e)
	# BF-065: газетный автомат и урна стояли посреди перекрёстка (клетки под дорогой-линией — трава)
	check("Карта игры: объекты не стоят на проезжей части (фонарь, автомат, урна — только на тротуаре)",
		on_road.is_empty(), "на дороге: %d %s" % [on_road.size(), on_road.slice(0, 5)])
	check("Карта игры: от каждого дома дорожка доходит до тротуара улицы",
		nowalk.is_empty(), "без дорожки: %d %s" % [nowalk.size(), nowalk.slice(0, 6)])

## PayDay и уровни (0.52): 20 минут за час — опыт и зарплата; меньше — ничего и плашка; АФК не считается;
## уровень 1→2 за 4 PayDay, 2→3 — ещё 6; сутки сбрасывают «отыграно сегодня»; час МСК сменился — PayDay один раз;
## уровень, опыт и дата регистрации переживают сохранение
func test_payday() -> void:
	var bad := []
	var g := GameState.new_game(5)
	g.real_clock = false
	var a := g.join_player("t-a", "Alex_Brown", 501, "m", "2026-11-04")
	var b := g.join_player("t-b", "Bill_Stone", 502, "m")
	var today := floori(g.time / 1440.0)
	# A играет 21 минуту, B — 10 минут, потом стоит без дела
	for i in 21 * 60:
		a.idle = 0.0
		g._account_time(a, 1.0, today)
	for i in 30 * 60:
		if i < 10 * 60:
			b.idle = 0.0
		g._account_time(b, 1.0, today)
	if absf(b.hour_play - (10 * 60 + GameState.AFK_AFTER)) > 2.0 or b.day_afk < 17 * 60:
		bad.append("АФК: в часу %d с, АФК %d с" % [b.hour_play, b.day_afk])
	g.pop_messages(a.id)
	g.pop_messages(b.id)
	g.payday()
	var ma := " ".join(g.pop_messages(a.id))
	var mb := " ".join(g.pop_messages(b.id))
	if a.exp != 1 or a.level != 1 or not ma.contains("PayDay") or not ma.contains("1/4"):
		bad.append("A: уровень %d опыт %d «%s»" % [a.level, a.exp, ma])
	if b.exp != 0 or not mb.contains("не отыграли минимум 20 минут"):
		bad.append("B: опыт %d «%s»" % [b.exp, mb])
	if a.hour_play != 0.0 or b.hour_play != 0.0:
		bad.append("отыгранное за час не обнулилось")
	# уровни: 4 очка до 2-го, потом 6 до 3-го
	for k in 3:
		a.hour_play = GameState.PAYDAY_MIN_PLAY
		g.payday()
	if a.level != 2 or a.exp != 0 or GameState.exp_need(2) != 6 or GameState.exp_need(3) != 8:
		bad.append("уровень после 4 PayDay: %d (%d)" % [a.level, a.exp])
	for k in 6:
		a.hour_play = GameState.PAYDAY_MIN_PLAY
		g.payday()
	if a.level != 3:
		bad.append("уровень после 10 PayDay: %d" % a.level)
	# вышедшему PayDay не приходит
	b.connected = false
	b.hour_play = 3000.0
	g.pop_messages(b.id)
	g.payday()
	if b.exp != 0 or not g.pop_messages(b.id).is_empty():
		bad.append("вышедшему пришёл PayDay")
	b.connected = true
	# новые сутки
	g._account_time(a, 1.0, today + 1)
	if a.day_play > 2.0 or a.day != today + 1:
		bad.append("сутки не сбросились: %d" % a.day_play)
	# смена часа: PayDay ровно один раз
	g.payday_hour = -1
	g.time = 14 * 60 + 59.5
	g.update(0.1)
	var x0 := a.exp
	a.hour_play = GameState.PAYDAY_MIN_PLAY
	g.update(0.3)                 # 14:59.8
	g.update(0.3)                 # 15:00.1 — PayDay
	g.update(0.3)
	if a.exp != x0 + 1:
		bad.append("смена часа: опыт %d → %d" % [x0, a.exp])
	# сохранение
	var g2 := GameState.new_game(5)
	g2.load_data(JSON.parse_string(JSON.stringify(g.to_data())))
	var a2 := g2.player(a.id)
	if a2 == null or a2.level != a.level or a2.exp != a.exp or a2.reg != "2026-11-04" or g2.payday_hour != g.payday_hour:
		bad.append("после сохранения: %s" % [[a2.level, a2.exp, a2.reg] if a2 != null else "нет игрока"])
	if GameState.reg_from_iso("2026-11-04T22:30:00.123+00:00") != "2026-11-05" or GameState.date_ru("2026-11-07") != "7 ноября 2026":
		bad.append("даты: %s / %s" % [GameState.reg_from_iso("2026-11-04T22:30:00.123+00:00"), GameState.date_ru("2026-11-07")])
	if b.reg != g.today_str():
		bad.append("без даты из базы — дата первого входа")
	check("PayDay: 20 минут за час — опыт и зарплата, меньше — плашка; АФК не в счёт; уровни 4, 6, 8…; сохраняется",
		bad.is_empty(), str(bad))

## Чат (0.52): слышат ближе 20 м и сам говорящий; дальше — нет; текст чистится и обрезается; чаще раза в секунду — нет;
## действие «say» проходит по сети (valid_action), строка уходит в событиях «c»
func test_chat() -> void:
	var bad := []
	var g := GameState.new_game(6)
	g.real_clock = false
	var a := g.join_player("c-a", "Anna_Gray", 601, "f")
	var b := g.join_player("c-b", "Ben_Cole", 602, "m")
	var c := g.join_player("c-c", "Carl_Reed", 603, "m")
	a.pos = Vector2(100, 100)
	b.pos = Vector2(112, 100)
	c.pos = Vector2(125, 100)
	a.idle = 500.0
	if not GameState.valid_action({"a": "say", "text": "привет"}) or GameState.valid_action({"a": "say", "text": 5}):
		bad.append("valid_action")
	g._do_action(a, {"a": "say", "text": "  Привет,\n\tкак   дела?  "})
	var la := g.pop_chat(a.id)
	var lb := g.pop_chat(b.id)
	var lc := g.pop_chat(c.id)
	if la.size() != 1 or lb.size() != 1 or lc.size() != 0:
		bad.append("кто слышит: %d %d %d" % [la.size(), lb.size(), lc.size()])
	elif lb[0] != "Anna_Gray (601) говорит: Привет, как дела?":
		bad.append("строка: «%s»" % lb[0])
	if a.idle != 0.0:
		bad.append("чат не сбрасывает АФК")
	g._do_action(a, {"a": "say", "text": "второе сразу"})
	if not g.pop_chat(b.id).is_empty() or not " ".join(g.pop_messages(a.id)).contains("Не так быстро"):
		bad.append("нет ограничения частоты")
	g._account_time(a, 1.1, floori(g.time / 1440.0))
	g._do_action(a, {"a": "say", "text": "x".repeat(300)})
	var lb2 := g.pop_chat(b.id)
	if lb2.size() != 1 or lb2[0].length() != "Anna_Gray (601) говорит: ".length() + GameState.CHAT_MAX:
		bad.append("длинное не обрезано")
	g._account_time(a, 1.1, floori(g.time / 1440.0))
	g._do_action(a, {"a": "say", "text": " \n "})
	if not g.pop_chat(b.id).is_empty():
		bad.append("пустое ушло")
	g._account_time(a, 1.1, floori(g.time / 1440.0))
	g._do_action(a, {"a": "say", "text": "в сеть"})
	var ev := g.events_for(b.id, false)
	if not (ev.get("c", []) as Array).has("Anna_Gray (601) говорит: в сеть"):
		bad.append("нет в событиях: %s" % [ev])
	check("Чат: слышат ближе 20 м; текст чистится и обрезается; не чаще раза в секунду; уходит в событиях", bad.is_empty(), str(bad))

## Удар на ходу (0.51, BF-067): ноги идут анимацией ходьбы, удар — только верхом тела; стоя — удар целиком;
## пошёл посреди удара — удар доигрывает верхом, ноги шагают; добивание ногой — всегда целиком
func test_attack_walk() -> void:
	var bad := []
	var dt := 1.0 / 30.0
	var step := func(cm: CharModel, moving: float, attack: float) -> void:
		cm.pose_dt(dt, moving, attack, "fists", false, false)
		cm.ap.advance(dt)
	# идёт и бьёт
	var cm := CharModel.new()
	cm.setup(GameState.default_look(1, "m"))
	add_child(cm)
	cm.speed = 1.6
	for i in 10:
		step.call(cm, 1.0, 0.0)
	var leg := cm.skel.find_bone("UpperLeg.L")
	var arm := cm.skel.find_bone("UpperArm.R")
	var legs := []
	for i in 9:
		step.call(cm, 1.0, 5.0)
		legs.append(cm.skel.get_bone_pose_rotation(leg))
	if cm.layer_anim == "" or cm.ap.current_animation != "Walk":
		bad.append("на ходу: удар «%s», ноги «%s»" % [cm.layer_anim, cm.ap.current_animation])
	elif (legs[0] as Quaternion).angle_to(legs[8]) < 0.05:
		bad.append("ноги не двигаются во время удара")
	else:
		var anim := cm.ap.get_animation(cm.layer_anim)
		var tr := anim.find_track(NodePath("CharacterArmature/Skeleton3D:UpperArm.R"), Animation.TYPE_ROTATION_3D)
		var want := anim.rotation_track_interpolate(tr, cm.layer_t)
		if cm.skel.get_bone_pose_rotation(arm).angle_to(want) > 0.05:
			bad.append("рука не по удару")
	for i in 40:
		step.call(cm, 1.0, 5.0)
	if cm.layer_anim != "":
		bad.append("удар поверх ходьбы не закончился")
	cm.queue_free()
	# стоит и бьёт — анимация целиком; пошёл посреди удара — удар верхом, ноги — шаг
	var c2 := CharModel.new()
	c2.setup(GameState.default_look(2, "f"))
	add_child(c2)
	c2.speed = 0.0
	step.call(c2, 0.0, 0.0)
	step.call(c2, 0.0, 5.0)
	step.call(c2, 0.0, 5.0)
	if not c2.ap.current_animation.begins_with("Punch") or c2.layer_anim != "":
		bad.append("стоя: «%s» / «%s»" % [c2.ap.current_animation, c2.layer_anim])
	c2.speed = 1.5
	step.call(c2, 1.0, 5.0)
	if c2.layer_anim == "" or c2.ap.current_animation != "Walk":
		bad.append("пошла посреди удара: «%s» / «%s»" % [c2.ap.current_animation, c2.layer_anim])
	# добивание ногой на ходу — целиком
	c2.atk_kind = 1
	for i in 40:
		step.call(c2, 1.0, 5.0)
	step.call(c2, 1.0, 9.0)
	if c2.ap.current_animation != "Kick_Right" or c2.layer_anim != "":
		bad.append("пинок: «%s» / «%s»" % [c2.ap.current_animation, c2.layer_anim])
	c2.queue_free()
	check("Удар на ходу: ноги шагают, удар — верхом тела; стоя — целиком; пинок — целиком", bad.is_empty(), str(bad))

## Мебель у стены (BF-066): столкновение — до её лицевой стороны, а не вся клетка; лицо в 3D совпадает с FURN_FRONT;
## мебель посреди комнаты занимает всю клетку
func test_furniture_collision() -> void:
	var w := GameWorld.new()
	var rows := []
	for y in 30:
		rows.append(("#" + "w".repeat(10) + "#" if y > 0 and y < 8 else "#".repeat(12)) + ".".repeat(18) if y < 9 else ".".repeat(30))
	var err := w.load_map({"v": 1, "w": 30, "h": 30, "spawn": [5.5, 4.5], "rows": rows, "props": []})
	var types := [W.FRIDGE, W.COUNTER, W.WARDROBE, W.SHELF, W.MEDCAB, W.LOCKER, W.STORESHELF]
	var bad := []
	var wm := WorldMesh.new(w)
	for i in types.size():
		var tt: int = types[i]
		var y := 1 + i
		w.set_t(1, y, tt)              # у западной стены — лицом на восток (+x)
		var front: float = 1.5 + float(W.FURN_FRONT[tt])
		if w.circle_blocked(front + 0.32, y + 0.5, 0.3) or not w.circle_blocked(front + 0.27, y + 0.5, 0.3):
			bad.append("столкновение %d" % tt)
		var m := Mesher.new()
		wm._furniture(m, 1, y, tt)
		var mx := -100.0
		for v in m.verts:
			mx = maxf(mx, v.x)
		if absf(mx - front) > 0.04:
			bad.append("лицо %d: 3D %.2f, FURN_FRONT %.2f" % [tt, mx, front])
		w.set_t(1, y, W.WOOD)
	w.set_t(6, 4, W.COUNTER)           # посреди комнаты
	if not w.circle_blocked(7.28, 4.5, 0.3) or w.circle_blocked(7.32, 4.5, 0.3):
		bad.append("посреди комнаты")
	check("Мебель у стены: упираешься в её лицо, а не в невидимую стену; посреди комнаты — вся клетка", err == "" and bad.is_empty(), err + str(bad))

## Крыши (0.47, BF-060): над недостроенным домом (стены не замкнуты) крыши нет; над закрытым — в пределах стен
## со свесом; у дома буквой Г пустой угол рядом не накрыт
func test_roofs() -> void:
	var w := GameWorld.new()
	var rows := []
	for y in 30:
		rows.append(".".repeat(30))
	w.load_map({"v": 1, "w": 30, "h": 30, "spawn": [0.5, 0.5], "rows": rows, "props": []})
	var outline := func(cells: Dictionary) -> void:
		for k: Vector2i in cells:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				if not cells.has(k + d):
					w.set_t(k.x, k.y, W.WALL)
	# недостроенный: две стены углом
	for x in range(2, 11):
		w.set_t(x, 2, W.WALL)
	for y in range(2, 9):
		w.set_t(2, y, W.WALL)
	# закрытый прямоугольник 3..8 × 12..17 с дверью
	var box := {}
	for y in range(12, 18):
		for x in range(3, 9):
			box[Vector2i(x, y)] = true
	outline.call(box)
	w.set_t(5, 17, W.DOOR)
	# буква Г: 12..24 × 2..8 и 12..17 × 9..16
	var ell := {}
	for y in range(2, 9):
		for x in range(12, 25):
			ell[Vector2i(x, y)] = true
	for y in range(9, 17):
		for x in range(12, 18):
			ell[Vector2i(x, y)] = true
	outline.call(ell)
	w.compute_buildings()
	var wm := WorldMesh.new(w)
	var m := Mesher.new()
	var res := {}
	for bi in w.buildings.size():
		var b: Array = w.buildings[bi]
		wm.build_roof(m, bi)
		var vs := m.verts.duplicate()
		res[Vector2i(b[0], b[1])] = vs
	var open_v: int = res.get(Vector2i(2, 2), PackedVector3Array()).size()
	var box_v: PackedVector3Array = res.get(Vector2i(3, 12), PackedVector3Array())
	var box_in := box_v.size() > 0
	for v in box_v:
		if v.x < 3.0 or v.x > 9.0 or v.z < 12.0 or v.z > 18.0:
			box_in = false
	var ell_v: PackedVector3Array = res.get(Vector2i(12, 2), PackedVector3Array())
	var corner := 0
	for v in ell_v:
		if v.x > 18.2 and v.z > 9.2:
			corner += 1
	var arm := 0
	for v in ell_v:
		if v.z > 12.0:
			arm += 1
	check("Крыши: над недостроенным домом нет, над закрытым — в пределах стен, у дома буквой Г пустой угол не накрыт",
		open_v == 0 and box_in and ell_v.size() > 0 and corner == 0 and arm > 0,
		"недостроенный %d вершин, прямоугольник в стенах %s, Г: %d вершин, в пустом углу %d, над крылом %d" % [open_v, box_in, ell_v.size(), corner, arm])

## Черновик редактора, начатый со старой карты игры (0.46, BF-059): редактор начинает с нынешней карты игры,
## прежний черновик — в копии; черновик с верным отпечатком открывается как есть
func test_stale_draft() -> void:
	var ME = load("res://scripts/map_editor.gd")
	var md := GameWorld.read_map_file()
	md["spawn"] = [3.5, 3.5]
	var old_text := GameWorld.map_text(md)
	for f in [ME.DRAFT, ME.DRAFT_BASE, ME.DRAFT_OLD]:
		DirAccess.remove_absolute(f)
	var fd := FileAccess.open(ME.DRAFT, FileAccess.WRITE)
	fd.store_string(old_text)
	fd.close()
	var stale_nobase: bool = ME.draft_stale()
	var ed = ME.new()
	ed.headless = true
	add_child(ed)
	var official := GameWorld.new()
	official.load_map(GameWorld.read_map_file())
	var from_game: bool = ed.w.spawn == official.spawn
	var backup_ok := FileAccess.get_file_as_string(ME.DRAFT_OLD) == old_text
	var fresh: bool = not ME.draft_stale()
	ed.queue_free()
	# черновик с верным отпечатком — открывается как есть
	fd = FileAccess.open(ME.DRAFT, FileAccess.WRITE)
	fd.store_string(old_text)
	fd.close()
	var ed2 = ME.new()
	ed2.headless = true
	add_child(ed2)
	var kept: bool = ed2.w.spawn == Vector2(3.5, 3.5)
	ed2.queue_free()
	for f in [ME.DRAFT, ME.DRAFT_BASE, ME.DRAFT_OLD]:
		DirAccess.remove_absolute(f)
	check("Редактор: черновик со старой карты игры — начинается с нынешней, прежний в копии; свежий черновик — как есть",
		stale_nobase and from_game and backup_ok and fresh and kept,
		"без отпечатка устарел %s, взята карта игры %s, копия %s, отпечаток обновлён %s, свежий открыт %s" % [stale_nobase, from_game, backup_ok, fresh, kept])

## Вид сверху в редакторе (0.45): схема покрывает всю карту ровно один раз, цвет клетки верный,
## правка клетки перестраивает одну полосу рядов
func test_overview() -> void:
	var w := GameWorld.new()
	var md := GameWorld.read_map_file()
	md["lines"] = [["street", 10.0, 10.0, 60.0, 10.0]]
	w.load_map(md)
	var ov := MapOverview.new()
	ov.setup(w)
	ov.refresh()
	var area := 0.0
	var wall := Vector2i(-1, -1)
	for i in w.tiles.size():
		if w.tiles[i] == W.WALL:
			wall = Vector2i(i % w.w, i / w.w)
			break
	var wall_ok := false
	for b in ov.bands:
		var mesh: ArrayMesh = b.mesh
		if mesh == null:
			continue
		var arr := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cl: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		for i in range(0, v.size(), 3):
			area += absf((v[i + 1] - v[i]).cross(v[i + 2] - v[i]).y) * 0.5
			var p := Vector2(wall.x + 0.5, wall.y + 0.5)
			if Geometry2D.point_is_inside_triangle(p, Vector2(v[i].x, v[i].z), Vector2(v[i + 1].x, v[i + 1].z), Vector2(v[i + 2].x, v[i + 2].z)):
				wall_ok = cl[i] == MapOverview.tile_col(W.WALL)
	w.set_t(5, 25, W.WATER)
	ov.mark_row(25)
	var dirty := ov.band_dirty.count(1)
	ov.refresh()
	check("Вид сверху: схема покрывает всю карту один раз, цвет клетки верный, дорога есть; правка — одна полоса",
		absf(area - w.w * w.h) < 0.5 and wall.x >= 0 and wall_ok and ov.lines_node.mesh != null and dirty == 1 and ov.ready_all(),
		"площадь %.1f из %d, стена %s %s, дорога %s, полос к перестройке %d" % [area, w.w * w.h, wall, wall_ok, ov.lines_node.mesh != null, dirty])
	ov.free()

## Город 500×500 из нынешнего 100×100, уложенного 5×5 (реальная плотность домов и объектов)
func _big_city(k: int) -> Dictionary:
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameWorld.map_path))
	var sw: int = src["w"]
	var sh: int = src["h"]
	var rows := []
	var props := []
	for ty in k:
		for y in sh:
			rows.append(str(src["rows"][y]).repeat(k))
	for ty in k:
		for tx in k:
			for e in src["props"]:
				props.append([e[0], float(e[1]) + tx * sw, float(e[2]) + ty * sh, e[3]])
	return {"v": 1, "w": sw * k, "h": sh * k, "spawn": [sw * k / 2.0, sh * k / 2.0], "rows": rows, "props": props}

## BF-052: карта 500×500 — грузится, а телефон держит построенной только округу игрока (иначе ~19 млн вершин)
## Текстуры мира (0.37): материал каждой грани уходит в UV.x, кирпич — только наружу, картинка комнаты —
## только с улицы, число слоёв текстуры = числу слоёв в шейдере = последнему материалу Mesher
func test_world_textures() -> void:
	var tex: TextureLayered = load("res://assets/tex/world_albedo.png")
	var code := (load("res://shaders/world.gdshader") as Shader).code
	var rx := RegEx.create_from_string("SCALE\\[(\\d+)\\]")
	var mm := rx.search(code)
	var n_sh := int(mm.get_string(1)) if mm != null else -1
	check("Текстуры: слоёв в массиве = в шейдере = материалов", tex != null and tex.get_layers() == n_sh and n_sh == Mesher.M_DIRT,
		"массив %d, шейдер %d, материалов %d" % [tex.get_layers() if tex != null else -1, n_sh, Mesher.M_DIRT])
	var g := _game()
	var w := g.world
	var wm := WorldMesh.new(w)
	var m := Mesher.new()
	# асфальт на дороге
	var road := Vector2i(-1, -1)
	for y in w.h:
		for x in w.w:
			if road.x < 0 and w.t(x, y) == W.ROAD:
				road = Vector2i(x, y)
	m.clear()
	wm._tile(m, road.x, road.y)
	check("Текстуры: дорога — асфальт", road.x >= 0 and m.uvs.size() > 0 and int(m.uvs[0].x) == Mesher.M_ASPHALT)
	# стены: кирпич/штукатурка снаружи, внутрь — штукатурка; окно — комната только снаружи
	var walls := 0
	var bad := []
	var brick := 0
	var rooms := 0
	for y in range(1, w.h - 1):
		for x in range(1, w.w - 1):
			var t := w.t(x, y)
			if t != W.WALL and t != W.WINDOW:
				continue
			walls += 1
			m.clear()
			wm._walls(m, x, y, t)
			for i in m.verts.size():
				var mat := int(m.uvs[i].x)
				var n: Vector3 = m.norms[i]
				if absf(n.y) > 0.5 or m.verts[i].y < 0.2:
					continue
				var inn := wm._inside(x + int(roundf(n.x)), y + int(roundf(n.z)))
				if mat == Mesher.M_BRICK:
					brick += 1
					if inn:
						bad.append("кирпич в комнату %d,%d" % [x, y])
				elif mat == Mesher.M_ROOM_LIT or mat == Mesher.M_ROOM_DARK:
					rooms += 1
					if inn:
						bad.append("комната за окном видна изнутри %d,%d" % [x, y])
			if bad.size() > 5:
				break
	check("Текстуры: кирпич и картинка комнаты — только наружу", walls > 0 and brick > 0 and rooms > 0 and bad.is_empty(),
		"стен %d, кирпичных граней %d, окон с комнатой %d; %s" % [walls, brick, rooms, bad.slice(0, 3)])
	# в чанке после стен материал сброшен: мебель и объекты — без текстуры
	m.clear()
	wm.build_chunk(m, 5, 5)
	check("Текстуры: после чанка материал и грани сброшены", m.mat == Mesher.M_NONE and m.face_mat.is_empty())

## Дороги-линии (0.38): формат карты, сглаживание, перекрёсток, редактор, по дороге можно ходить
func _road_world() -> GameWorld:
	var md: Dictionary = GameWorld.read_map_file()
	var rows: Array = []
	for r in md["rows"]:
		rows.append(r + ".".repeat(80))
	md["rows"] = rows
	md["w"] = int(md["w"]) + 80
	md["lines"] = [["street", 110.0, 20.0, 130.0, 20.0, 150.0, 30.0, 160.0, 50.0], ["highway", 140.0, 5.0, 142.0, 60.0, 150.0, 95.0],
		# крутые повороты и петля через саму себя (BF-057: вывернутые треугольники, щели, тротуар поверх асфальта)
		["street", 110.0, 70.0, 128.0, 70.0, 131.0, 75.0, 116.0, 80.0, 121.0, 62.0],
		["highway", 160.0, 70.0, 172.0, 72.0, 166.0, 80.0, 158.0, 74.0, 170.0, 64.0]]
	var w := GameWorld.new()
	var err := w.load_map(md)
	return w if err == "" else null

## Радиус окружности через три точки (INF — на одной прямой)
static func _circ_r(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ar := absf((b - a).cross(c - a))
	if ar < 1e-6:
		return INF
	return a.distance_to(b) * b.distance_to(c) * a.distance_to(c) / (2.0 * ar)

func test_road_lines() -> void:
	var w := _road_world()
	check("Дороги: карта с дорогами-линиями грузится", w != null and w.lines.size() == 4)
	if w == null:
		return
	# туда-обратно через текст файла
	var back := GameWorld.new()
	var txt := GameWorld.map_text(w.map_data())
	var err := back.load_map(JSON.parse_string(txt))
	check("Дороги: туда-обратно через файл без потерь", err == "" and JSON.stringify(back.lines) == JSON.stringify(w.lines), err)
	var city := GameWorld.new()
	city.load_map(GameWorld.read_map_file())
	check("Дороги: карта без дорог пишется как раньше (без поля lines)", not GameWorld.map_text(city.map_data()).contains("lines"))
	# плохие дороги — отказ, мир не меняется
	var bad := [[["river", 1, 1, 5, 5]], [["street", 1, 1]], [["street", 1, 1, 5]], [["street", 1, 1, 9999, 5]],
		[["street", 1, 1, NAN, 5]], [["street", -1, 1, 5, 5]], ["street"], "x"]
	var long := ["street"]
	for k in GameWorld.MAX_LINE_PTS + 1:
		long.append(1.0 + k)
		long.append(1.0)
	bad.append([long])
	var rejected := 0
	for b in bad:
		var md := w.map_data()
		md["lines"] = b
		var t := GameWorld.new()
		if t.load_map(md) != "":
			rejected += 1
	check("Дороги: неверные дороги в файле — отказ (%d видов)" % bad.size(), rejected == bad.size(), "отказано %d" % rejected)
	# кривая (с 0.44, BF-058): от первой точки до последней, углы — дуги (радиус по точкам пути не меньше
	# радиуса дуги угла), мелкие шаги; угол 90° с длинными отрезками — дуга желаемого радиуса
	var path := GameWorld.line_path(w.lines[0])
	var e0: Array = w.lines[0]
	var ends_ok := path[0].distance_to(Vector2(e0[1], e0[2])) < 0.01 \
		and path[path.size() - 1].distance_to(Vector2(e0[e0.size() - 2], e0[e0.size() - 1])) < 0.01
	var max_step := 0.0
	for i in path.size() - 1:
		max_step = maxf(max_step, path[i].distance_to(path[i + 1]))
	var rmin := INF
	for r in GameWorld.line_corner_radii(e0):
		rmin = minf(rmin, r)
	var rpath := INF
	for i in range(1, path.size() - 1):
		rpath = minf(rpath, _circ_r(path[i - 1], path[i], path[i + 1]))
	var sq := ["street", 0.0, 0.0, 60.0, 0.0, 60.0, 60.0]
	var sq_r := GameWorld.line_corner_radii(sq)
	check("Дороги: кривая — от первой точки до последней, углы скруглены дугой, шаг не больше %.1f м" % GameWorld.LINE_STEP,
		ends_ok and max_step <= GameWorld.LINE_STEP + 0.05 and rpath >= rmin * 0.95 and sq_r.size() == 1
		and absf(sq_r[0] - GameWorld.LINE_TURN_R["street"]) < 0.01,
		"концы %s, шаг %.2f, радиус по пути %.1f, дуги %.1f, угол 90° — %s" % [ends_ok, max_step, rpath, rmin, sq_r])
	check("Дороги: асфальт и обочина находятся по точке", w.on_line_road(Vector2(120, 20), -1) and not w.on_line_road(Vector2(120, 24), -1)
		and w.on_line_road(Vector2(120, 24), -1, true) and not w.on_line_road(Vector2(120, 30), -1, true))
	check("Дороги: по дороге-линии можно ходить (она не стена)", not w.circle_blocked(120.0, 20.0, GameState.PLAYER_R))
	# что видно сверху (BF-057): на асфальте любой линии сверху — асфальт или разметка (не тротуар и не обочина),
	# асфальт без дыр, все поверхности дорог смотрят вверх — на перекрёстке, крутых поворотах и петле
	var wm := WorldMesh.new(w)
	var m := Mesher.new()
	var holes := 0
	var side_on_top := 0
	var down := 0
	var asphalt := 0
	var probes := 0
	var bins := {}             # треугольники дорог всех кусков по клеткам 1×1 (кусок дороги лежит в куске графики по середине)
	# концы дорог (плоский срез) — у них точки «рядом с отрезком» за срезом не проверяем
	var ends := []
	var last := {}
	for ck in w.lines_chunk:
		for r in w.lines_chunk[ck]:
			if float(r[5]) == 0.0:
				ends.append(r[1])
			if not last.has(r[7]) or float(r[6]) > float(last[r[7]][6]):
				last[r[7]] = r
	for li in last:
		ends.append(last[li][2])
	for ck in w.lines_chunk:
		m.clear()
		wm.build_chunk(m, ck.x, ck.y)
		for i in range(0, m.verts.size(), 3):
			var c3: Vector3 = (m.verts[i] + m.verts[i + 1] + m.verts[i + 2]) / 3.0
			if c3.y < 0.025 or c3.y > 0.06:
				continue
			var nrm3: Vector3 = (m.verts[i + 1] - m.verts[i]).cross(m.verts[i + 2] - m.verts[i])
			# порядок вершин в Mesher обратный: «лицом вверх» — нормаль по обходу вниз
			if nrm3.y > 0.0:
				down += 1
			var mt := int(m.uvs[i].x)
			if mt == Mesher.M_ASPHALT:
				asphalt += 1
			var t2 := [Vector2(m.verts[i].x, m.verts[i].z), Vector2(m.verts[i + 1].x, m.verts[i + 1].z), Vector2(m.verts[i + 2].x, m.verts[i + 2].z), c3.y, mt]
			var lo := Vector2(minf(minf(t2[0].x, t2[1].x), t2[2].x), minf(minf(t2[0].y, t2[1].y), t2[2].y))
			var hi := Vector2(maxf(maxf(t2[0].x, t2[1].x), t2[2].x), maxf(maxf(t2[0].y, t2[1].y), t2[2].y))
			for by in range(floori(lo.y), floori(hi.y) + 1):
				for bx in range(floori(lo.x), floori(hi.x) + 1):
					var bk := Vector2i(bx, by)
					if bins.has(bk):
						bins[bk].append(t2)
					else:
						bins[bk] = [t2]
	for ck in w.lines_chunk:
		for py in range(ck.y * WorldMesh.CHUNK, (ck.y + 1) * WorldMesh.CHUNK):
			for px in range(ck.x * WorldMesh.CHUNK, (ck.x + 1) * WorldMesh.CHUNK):
				for o in [Vector2(0.25, 0.25), Vector2(0.75, 0.75)]:
					var p: Vector2 = Vector2(px, py) + o
					# точка на асфальте какой-то линии (с запасом 0.1 м от края асфальта)
					var on := false
					for r in w.lines_chunk.get(ck, []) + w.lines_chunk.get(ck + Vector2i(1, 0), []) + w.lines_chunk.get(ck + Vector2i(-1, 0), []) + w.lines_chunk.get(ck + Vector2i(0, 1), []) + w.lines_chunk.get(ck + Vector2i(0, -1), []):
						var hw: float = GameWorld.LINE_ROAD_HW[r[0]] - 0.1
						if Geometry2D.get_closest_point_to_segment(p, r[1], r[2]).distance_squared_to(p) < hw * hw:
							on = true
					for ep in ends:
						if p.distance_to(ep) < 7.0:
							on = false
					if not on:
						continue
					probes += 1
					var top_y := -1.0
					var top_m := -1
					for t2 in bins.get(Vector2i(px, py), []):
						# точка ровно на общей стороне двух треугольников не «внутри» ни одного — сдвиги на ~1 см
						var inside := false
						for q in [p, p + Vector2(0.007, 0.011), p + Vector2(-0.009, 0.006)]:
							if Geometry2D.point_is_inside_triangle(q, t2[0], t2[1], t2[2]):
								inside = true
						if inside and t2[3] > top_y:
							top_y = t2[3]
							top_m = t2[4]
					if top_m < 0:
						holes += 1
					elif top_m != Mesher.M_ASPHALT and top_m != Mesher.M_NONE:
						side_on_top += 1
	check("Дороги: на асфальте сверху — асфальт (не тротуар), без дыр, всё лицом вверх — перекрёсток, крутые повороты, петля",
		asphalt > 100 and probes > 500 and holes == 0 and side_on_top == 0 and down == 0,
		"точек %d: дыр %d, тротуар/обочина сверху %d; вывернутых треугольников %d" % [probes, holes, side_on_top, down])
	# камешки и травинки клеток под дорогой не торчат из асфальта и тротуара (были в первой сборке 0.38)
	var poke := 0
	for ck in w.lines_chunk:
		m.clear()
		wm.build_chunk(m, ck.x, ck.y)
		for i in range(0, m.verts.size(), 3):
			var c3: Vector3 = (m.verts[i] + m.verts[i + 1] + m.verts[i + 2]) / 3.0
			# поверхности дорог — не выше 0.06 и лицом вверх; камешки и травинки — выше или стенками
			var up := absf(((m.verts[i + 1] - m.verts[i]).cross(m.verts[i + 2] - m.verts[i])).normalized().y) > 0.99
			if int(m.uvs[i].x) == Mesher.M_NONE and c3.y > 0.025 and c3.y < 0.4 and (c3.y > 0.06 or not up) and w.on_line_road(Vector2(c3.x, c3.z), -1, true):
				poke += 1
	check("Дороги: камешки и травинки не торчат из дороги", poke == 0, "треугольников на дороге: %d" % poke)
	# перекрёсток (0.44, BF-058): улица пересекает трассу — найден один раз; на подъездах «зебра» и стоп-линии;
	# внутри перекрёстка нет осевой разметки; кромка трассы рвётся только с той стороны, где примыкает дорога
	var jx := []
	for ck2 in w.lines_junc:
		for jn in w.lines_junc[ck2]:
			if (jn[1] == 0 and jn[4] == 1) or (jn[1] == 1 and jn[4] == 0):
				jx.append(jn)
	var zebra := 0
	var yel_in := 0
	if jx.size() == 1:
		var jp: Vector2 = jx[0][0]
		var jck := Vector2i(floori(jp.x) / GameWorld.PROP_CHUNK, floori(jp.y) / GameWorld.PROP_CHUNK)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var mj := Mesher.new()
				wm.build_chunk(mj, jck.x + dx, jck.y + dy)
				for i in range(0, mj.verts.size(), 3):
					var c3: Vector3 = (mj.verts[i] + mj.verts[i + 1] + mj.verts[i + 2]) / 3.0
					if absf(c3.y - WorldMesh.LINE_MARK_Y) > 0.001:
						continue
					var col: Color = mj.cols[i]
					var d2 := Vector2(c3.x, c3.z).distance_to(jp)
					if col.r > 0.8 and col.b > 0.8 and d2 > 3.0 and d2 < 12.0:
						zebra += 1
					if col.r > 0.7 and col.b < 0.4 and d2 < 4.0:
						yel_in += 1
	# Т-перекрёсток: улица упирается в трассу слева — кромка справа целая
	var tw := GameWorld.new()
	var tmd := w.map_data()
	tmd["lines"] = [["highway", 140.0, 5.0, 140.0, 60.0], ["street", 100.0, 30.0, 140.5, 30.0]]
	tw.load_map(tmd)
	var twm := WorldMesh.new(tw)
	var t_far := 0
	var t_near := 0
	for dy in range(-1, 2):
		var mt := Mesher.new()
		twm.build_chunk(mt, 14, 3 + dy)
		for i in range(0, mt.verts.size(), 3):
			var c3: Vector3 = (mt.verts[i] + mt.verts[i + 1] + mt.verts[i + 2]) / 3.0
			if absf(c3.y - WorldMesh.LINE_MARK_Y) > 0.001 or absf(c3.z - 30.0) > 2.5:
				continue
			if absf(c3.x - (140.0 + 5.625)) < 0.1:
				t_far += 1
			if absf(c3.x - (140.0 - 5.625)) < 0.1:
				t_near += 1
	# угол «трасса кончается — улица начинается» (разные виды, не сливаются): круглые концы, без выреза (0.48, BF-061)
	var cw := GameWorld.new()
	var cmd := w.map_data()
	cmd["lines"] = [["highway", 10.0, 10.0, 40.0, 10.0], ["street", 40.0, 10.0, 40.0, 40.0]]
	cw.load_map(cmd)
	var cwm := WorldMesh.new(cw)
	var notch_pts := [Vector2(42.5, 8.0), Vector2(43.5, 6.5), Vector2(41.0, 5.0)]
	var covered := 0
	for cy2 in range(0, 2):
		for cx2 in range(3, 5):
			var mc := Mesher.new()
			cwm.build_chunk(mc, cx2, cy2)
			for i in range(0, mc.verts.size(), 3):
				if absf(mc.verts[i].y - WorldMesh.LINE_ROAD_Y) > 0.001:
					continue
				for np2: Vector2 in notch_pts:
					if Geometry2D.point_is_inside_triangle(np2, Vector2(mc.verts[i].x, mc.verts[i].z), Vector2(mc.verts[i + 1].x, mc.verts[i + 1].z), Vector2(mc.verts[i + 2].x, mc.verts[i + 2].z)):
						covered += 1
	check("Дороги: угол трассы и улицы конец в конец — асфальт без выреза (круглые концы)", covered >= notch_pts.size(),
		"точек угла под асфальтом: %d из %d" % [covered, notch_pts.size()])
	check("Дороги: перекрёсток — «зебры» и стоп-линии на подъездах, внутри без осевой; на Т — кромка рвётся только со стороны примыкания",
		jx.size() == 1 and zebra >= 40 and yel_in == 0 and t_far > 0 and t_near == 0 and tw.lines_junc.size() == 1,
		"перекрёстков %d, «зебра» %d, осевая внутри %d, Т: кромка справа %d, слева %d" % [jx.size(), zebra, yel_in, t_far, t_near])
	# редактор: точки, вид, отмена, удаление
	var ed = load("res://scripts/map_editor.gd").new()
	ed.headless = true
	ed.use_draft = false
	add_child(ed)
	var ew: GameWorld = ed.w
	var n0 := ew.lines.size()
	for p in [Vector2(10, 95), Vector2(30, 92), Vector2(50, 96)]:
		ed.begin()
		ed.road_point(p)
		ed.end()
	var made: bool = ew.lines.size() == n0 + 1 and ew.lines[n0].size() == 7
	ed.set_road_kind("highway")
	var kind_ok: bool = ew.lines[n0][0] == "highway"
	ed.undo()
	var undo_kind: bool = ew.lines[n0][0] == "street"
	ed.undo()
	var undo_pt: bool = ew.lines[n0].size() == 5
	ed.road_line = -1
	ed.begin()
	ed.road_point(Vector2(5, 5))
	ed.end()
	var one_skipped: bool = ew.map_data()["lines"].size() == n0 + 1
	ed.begin()
	ed.delete_road(ed.road_at(Vector2(20, 93.5)))
	ed.end()
	check("Редактор: дорога по точкам, смена вида, отмена по шагу, удаление; дорога из одной точки не идёт в файл",
		made and kind_ok and undo_kind and undo_pt and one_skipped and ew.lines.size() == n0 + 1 and ew.lines[n0].size() == 3,
		"%s %s %s %s %s, дорог %d" % [made, kind_ok, undo_kind, undo_pt, one_skipped, ew.lines.size()])
	ed.queue_free()

## Вода и мост (0.40): где вода по полю — там и не пройти; одинокая клетка — не вода; на дорогу вода не заходит;
## по мосту над водой пройти можно, за перила — нет
func _water_world() -> GameWorld:
	var md: Dictionary = GameWorld.read_map_file()
	var rows: Array = []
	for y in md["rows"].size():
		var r: String = md["rows"][y] + ".".repeat(80)
		var chars := r.split("")
		for x in range(100, 180):
			var lake := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(128, 40)) < 11.0
			var river := absf(x + 0.5 - (157.0 + 6.0 * sin(y / 14.0))) < 4.2
			if lake or river:
				chars[x] = "~"
		chars[115] = "~" if y == 90 else chars[115]       # одинокая клетка воды
		if y == 30:
			for x in range(110, 146):
				chars[x] = "="                            # дорога через озеро: вода на неё не заходит
		rows.append("".join(chars))
	md["rows"] = rows
	md["w"] = int(md["w"]) + 80
	md["lines"] = [["bridge", 146.0, 74.0, 158.0, 72.0, 170.0, 70.0]]
	var w := GameWorld.new()
	return w if w.load_map(md) == "" else null

func test_water() -> void:
	var w := _water_world()
	check("Вода: карта с водой и мостом грузится, «~» в файле туда-обратно", w != null and w.has_water
		and GameWorld.new().load_map(JSON.parse_string(GameWorld.map_text(w.map_data()))) == "")
	if w == null:
		return
	var deep := w.circle_blocked(128.0, 40.0, GameState.PLAYER_R)
	var dry := not w.circle_blocked(110.0, 70.0, GameState.PLAYER_R)
	var lone := not w.water_at(Vector2(115.5, 90.5)) and not w.circle_blocked(115.5, 90.5, GameState.PLAYER_R)
	check("Вода: в озере не пройти, на траве можно; одинокая клетка воды — не вода", deep and dry and lone, "%s %s %s" % [deep, dry, lone])
	# глубина (0.41): у берега 1, в середине озера — далеко до берега; цвет у берега светлее
	var dc := w.water_depth_corners(128, 40)
	var shore_cell := -1
	for x in range(100, 140):
		if shore_cell < 0 and w.t(x, 40) == W.WATER:
			shore_cell = w.water_dist[40 * w.w + x]
	var lum0 := WorldMesh._depth_col(0.5).get_luminance()
	var lum1 := WorldMesh._depth_col(6.0).get_luminance()
	check("Вода: глубина — у берега мелко (1), в середине озера глубже; цвет у берега светлее", shore_cell == 1 and dc[0] >= 5.0 and lum0 > lum1 + 0.1,
		"у берега %d, в середине %.1f, яркость %.2f / %.2f" % [shore_cell, dc[0], lum0, lum1])
	# на дорогу и в дома вода не заходит: у клеток не-травы поле не больше 0.5
	var intrude := 0
	for y in w.h:
		for x in w.w:
			var tt := w.t(x, y)
			if tt == W.WATER or tt == W.GRASS or tt == W.TREE:
				continue
			for k in 5:
				var p: Vector2 = Vector2(x + 0.5, y + 0.5) + ([Vector2.ZERO, Vector2(-0.45, -0.45), Vector2(0.45, -0.45), Vector2(0.45, 0.45), Vector2(-0.45, 0.45)][k])
				if w.water_at(p):
					intrude += 1
	check("Вода: на дорогу, тротуар и в дома не заходит", intrude == 0, "точек: %d" % intrude)
	# что нарисовано — то и не пройти: середины треугольников глади — в воде, травы у берега — на суше
	var wm := WorldMesh.new(w)
	var m := Mesher.new()
	var bad_w := 0
	var bad_l := 0
	var water_tris := 0
	for cy in range(0, 10):
		for cx in range(10, 18):
			m.clear()
			wm.build_chunk(m, cx, cy)
			for i in range(0, m.verts.size(), 3):
				var c3: Vector3 = (m.verts[i] + m.verts[i + 1] + m.verts[i + 2]) / 3.0
				var p2 := Vector2(c3.x, c3.z)
				var mt := int(m.uvs[i].x)
				if mt == Mesher.M_WATER and absf(c3.y - WorldMesh.WATER_Y) < 0.01:
					water_tris += 1
					if not w.water_at(p2):
						bad_w += 1
				elif mt == Mesher.M_DIRT and absf(c3.y) < 0.01 and w.water_corners(floori(p2.x), floori(p2.y)).size() > 0:
					if w.water_at(p2):
						bad_l += 1
	check("Вода: нарисованная гладь — там, где не пройти, трава у берега — где можно", water_tris > 500 and bad_w == 0 and bad_l == 0,
		"глади %d, гладь на суше %d, трава в воде %d" % [water_tris, bad_w, bad_l])
	# мост: по настилу над рекой — можно, за перилами — нет
	var path := GameWorld.line_path(w.lines[0])
	# точка пути над серединой реки (вода под настилом и по обе стороны)
	var mi := -1
	for i in range(1, path.size() - 1):
		var nn := (path[i + 1] - path[i - 1]).orthogonal().normalized()
		if mi < 0 and w.water_at(path[i]) and w.water_at(path[i] + nn * 5.0) and w.water_at(path[i] - nn * 5.0):
			mi = i
	var mid := path[maxi(mi, 1)]
	var nrm := (path[maxi(mi, 1) + 1] - path[maxi(mi, 1) - 1]).orthogonal().normalized()
	var on_deck := mi > 0 and not w.circle_blocked(mid.x, mid.y, GameState.PLAYER_R)
	var edge := mid + nrm * (GameWorld.LINE_OUTER_HW["bridge"] - 0.1)
	var past := mid + nrm * (GameWorld.LINE_OUTER_HW["bridge"] + 1.0)
	var cross := true
	for i in path.size():
		if w.circle_blocked(path[i].x, path[i].y, GameState.PLAYER_R):
			cross = false
	check("Мост: по всему мосту пройти можно (над водой тоже), у перил и за ними над водой — нет",
		on_deck and cross and w.circle_blocked(edge.x, edge.y, GameState.PLAYER_R) and w.circle_blocked(past.x, past.y, GameState.PLAYER_R),
		"настил %s, весь путь %s" % [on_deck, cross])
	# редактор: кисть воды и отмена
	var ed = load("res://scripts/map_editor.gd").new()
	ed.headless = true
	ed.use_draft = false
	add_child(ed)
	var ew: GameWorld = ed.w
	var had: bool = ew.has_water
	ed.begin()
	ed.paint(Vector2i(10, 95), W.WATER)
	ed.paint(Vector2i(11, 95), W.WATER)
	ed.end()
	var painted: bool = ew.has_water and ew.t(10, 95) == W.WATER
	ed.undo()
	check("Редактор: кисть «Вода» и отмена", not had and painted and not ew.has_water and ew.t(10, 95) != W.WATER)
	ed.queue_free()

## Редактор (0.42, BF-055): кисть по земле не пересчитывает дома; вид дома не зависит от номера; дороги соединяются
func test_editor_speed_roads() -> void:
	var ed = load("res://scripts/map_editor.gd").new()
	ed.headless = true
	ed.use_draft = false
	add_child(ed)
	var w: GameWorld = ed.w
	# 10 клеток травы подряд, не у дома
	var gp := Vector2i(-1, -1)
	for y in range(2, w.h - 2):
		for x in range(2, w.w - 12):
			if gp.x >= 0:
				break
			var ok := true
			for k in 10:
				for dy in range(-1, 2):
					if w.t(x + k, y + dy) != W.GRASS:
						ok = false
			if ok:
				gp = Vector2i(x, y)
	var runs := w.buildings_runs
	ed.begin()
	for k in 10:
		ed.paint(gp + Vector2i(k, 0), W.SIDEWALK)
	ed.end()
	var ground_fast := w.buildings_runs == runs
	ed.begin()
	ed.paint(gp + Vector2i(0, 1), W.WALL)
	ed.end()
	check("Редактор: кисть по земле не пересчитывает дома, стена — пересчитывает", gp.x >= 0 and ground_fast and w.buildings_runs == runs + 1,
		"пересчётов: %d → %d" % [runs, w.buildings_runs])
	# вид дома не меняется, когда выше на карте появился новый дом (номера домов сдвинулись)
	var wm := WorldMesh.new(w)
	var sample := []
	for bi in range(0, w.buildings.size(), 3):
		var b: Array = w.buildings[bi]
		sample.append([b[0], b[1], wm.wall_mat(bi), wm.wall_tint(bi)])
	ed.begin()
	ed.rect(Vector2i(1, 1), Vector2i(3, 3), W.WALL, true)
	ed.end()
	var same := true
	for e in sample:
		var bi2: int = w.building_of[w.idx(e[0], e[1])]
		if bi2 < 0 or wm.wall_mat(bi2) != e[2] or wm.wall_tint(bi2) != e[3]:
			same = false
	check("Редактор: новый дом не перекрашивает остальные (вид — по углу дома, не по номеру)", same and w.buildings[0][0] == 1)
	# дороги: продолжить от конца, присоединить к середине другой
	var n0 := w.lines.size()
	ed.road_line = -1
	for p in [Vector2(20, 96), Vector2(40, 96), Vector2(60, 96)]:
		ed.begin()
		ed.road_tap(p)
		ed.end()
	ed.road_line = -1                                   # «Готово»
	ed.begin()
	ed.road_tap(Vector2(61.5, 97))                      # у конца — продолжить ту же
	ed.end()
	var cont: bool = ed.road_line == n0
	ed.begin()
	ed.road_tap(Vector2(75, 96))
	ed.end()
	var longer: bool = w.lines.size() == n0 + 1 and (w.lines[n0].size() - 1) / 2 == 4
	ed.road_line = -1
	ed.begin()
	ed.road_tap(Vector2(19.0, 95.0))                    # у начала — дорога разворачивается и продолжается
	ed.end()
	var rev: bool = ed.road_line == n0 and Vector2(w.lines[n0][w.lines[n0].size() - 2], w.lines[n0][w.lines[n0].size() - 1]) == Vector2(20, 96)
	ed.road_line = -1
	for p in [Vector2(30, 80), Vector2(31, 94)]:        # новая дорога, вторая точка — на асфальте первой
		ed.begin()
		ed.road_tap(p)
		ed.end()
	var e2: Array = w.lines[w.lines.size() - 1]
	var joint := Vector2(e2[e2.size() - 2], e2[e2.size() - 1])
	var on_axis := absf(joint.y - 96.0) <= 0.5
	check("Редактор: дорога продолжается от конца (и от начала), присоединяется к другой и заканчивается сама",
		cont and longer and rev and on_axis and ed.road_line == -1 and w.lines.size() == n0 + 2,
		"%s %s %s, стык %s, дорог %d" % [cont, longer, rev, joint, w.lines.size() - n0])
	# крутой поворот (0.44, BF-058): трасса «шпилькой» — точка не ставится; поворот 90° с длинными отрезками — ставится
	ed.road_line = -1
	ed.road_kind = "highway"
	for p in [Vector2(20, 50), Vector2(50, 50)]:
		ed.begin()
		ed.road_tap(p)
		ed.end()
	var hl: int = ed.road_line
	ed.begin()
	var msg: String = ed.road_tap(Vector2(25, 53))
	ed.end()
	var refused: bool = (w.lines[hl].size() - 1) / 2 == 2 and msg.begins_with("Слишком крутой")
	ed.begin()
	ed.road_tap(Vector2(50, 80))
	ed.end()
	var ok90: bool = (w.lines[hl].size() - 1) / 2 == 3
	check("Редактор: слишком крутой поворот дороги не ставится, обычный — ставится", refused and ok90,
		"шпилька отказана %s («%s»), 90° принят %s" % [refused, msg, ok90])
	# слияние (0.48, BF-061): трасса к концу другой трассы — одна дорога с дугой на углу; касание на «торце»
	# широкой трассы (в 6 м от конца, не на оси) — тоже конец
	ed.road_line = -1
	ed.road_kind = "highway"
	var n_before: int = w.lines.size()
	for p in [Vector2(60, 10), Vector2(90, 10)]:
		ed.begin()
		ed.road_tap(p)
		ed.end()
	ed.road_line = -1
	for p in [Vector2(90, 50), Vector2(95, 14)]:
		ed.begin()
		ed.road_tap(p)
		ed.end()
	var merged: Array = w.lines[w.lines.size() - 1]
	var one: bool = w.lines.size() == n_before + 1 and (merged.size() - 1) / 2 == 3 and Vector2(merged[3], merged[4]) == Vector2(90, 10)
	var mr := GameWorld.line_corner_radii(merged)
	check("Редактор: трасса к концу трассы — сливаются в одну с дугой на углу; конец ловится по ширине дороги",
		one and mr.size() == 1 and mr[0] >= GameWorld.LINE_MIN_R["highway"],
		"дорог стало %d (ждали %d), точки %s, радиус угла %s" % [w.lines.size(), n_before + 1, merged, mr])
	ed.road_kind = "street"
	ed.queue_free()

func test_big_map() -> void:
	var md := _big_city(5)
	var g := GameState.new_game(1)
	var err := g.world.load_map(md)
	check("Большая карта: 500×500 (предел MAX_SIDE) грузится", err == "" and g.world.w == 500 and GameWorld.MAX_SIDE >= 500
		and GameWorld.PROP_CHUNK == WorldMesh.CHUNK, err)
	g.players.clear()
	var me := g.join_player("uid-big-xxxxxxxxxxxx", "Big_One")
	me.pos = Vector2(15.5, 15.5)
	me.rpos = me.pos
	var view := WorldView.new()
	add_child(view)
	view.setup(g.world)
	var built_max := 0
	var verts_max := 0
	for f in 120:
		view.update(1.0 / 60.0, g, me, me.id)
		built_max = maxi(built_max, view.built.size())
		if f % 20 == 0:
			await get_tree().process_frame
	var near_ok := view.chunk_nodes[1 * view.wm.chunks_x + 1].mesh != null
	var far_none := view.chunk_nodes[40 * view.wm.chunks_x + 40].mesh == null
	# идём в другой конец карты: позади всё освобождается, впереди строится
	var freed_ok := true
	for step in 90:
		me.pos = me.pos.move_toward(Vector2(480.5, 480.5), 8.0)
		me.rpos = me.pos
		for f in 6:
			view.update(1.0 / 60.0, g, me, me.id)
		built_max = maxi(built_max, view.built.size())
	var start_freed := view.chunk_nodes[1 * view.wm.chunks_x + 1].mesh == null
	var end_built := view.chunk_nodes[48 * view.wm.chunks_x + 48].mesh != null
	var r := view.stream_r
	check("Большая карта: построена только округа игрока — не больше %d кусков из %d (BF-052)" % [(2 * r + 3) * (2 * r + 3), view.chunk_nodes.size()],
		near_ok and far_none and built_max <= (2 * r + 3) * (2 * r + 3), "рядом построен: %s, далеко пусто: %s, максимум построенных %d" % [near_ok, far_none, built_max])
	check("Большая карта: ушёл в другой конец — позади освобождено, впереди построено", start_freed and end_built,
		"старт освобождён: %s, конец построен: %s" % [start_freed, end_built])
	view.queue_free()

## BF-046: место появления — рядом с точкой появления и не сквозь стену в соседний дом
func test_spawn_spot() -> void:
	var g := GameState.new_game(1)
	g.players.clear()
	var sb := g.building_at(g.spawn)
	var inside := 0
	var blocked := 0
	var far := 0.0
	for i in 2000:
		var p := g._spawn_player(5000 + i)
		if g.building_at(p.pos) != sb:
			inside += 1
		if g.world.circle_blocked(p.pos.x, p.pos.y, GameState.PLAYER_R):
			blocked += 1
		far = maxf(far, p.pos.distance_to(g.spawn))
	check("Появление: не внутри соседнего здания, не в стене, рядом с точкой появления (2000 раз, BF-046)",
		inside == 0 and blocked == 0 and far < 3.0, "в чужом здании %d, в стене %d, дальше всего %.2f" % [inside, blocked, far])

## Первая клетка (центр), подходящая под условие; (-1, -1) — нет такой
func _cell_where(g: GameState, ok: Callable) -> Vector2:
	for y in range(2, g.world.h - 2):
		for x in range(2, g.world.w - 2):
			var c := Vector2(x + 0.5, y + 0.5)
			if ok.call(c):
				return c
	return Vector2(-1, -1)

## Сколько игроков с этим id в пакетах для зрителя: быстрый снимок, полный снимок, первый пакет при входе
func _seen_in(g: GameState, viewer: int, target: int) -> Array:
	var r := [0, 0, 0]
	var ps: PackedFloat32Array = g.state_for(viewer)["p"]
	var i := 0
	while i + 9 < ps.size():
		if int(ps[i]) == target:
			r[0] += 1
		i += 10
	for e in g.events_for(viewer, true, true).get("p", []):   # все видимые, без учёта «уже отправлено» (BF-050)
		if int(e["id"]) == target:
			r[1] += 1
	for e in g.to_data_for(viewer)["p"]:
		if int(e["id"]) == target:
			r[2] += 1
	return r

## Другие игроки уходят телефону только в пределах экрана (с запасом) и не из-под чужой крыши (аудит, В3)
func test_visibility() -> void:
	var g := GameState.new_game(1)
	g.players.clear()
	var w := g.world
	var free := func(c: Vector2) -> bool: return not w.circle_blocked(c.x, c.y, GameState.PLAYER_R)
	var indoor := _cell_where(g, func(c: Vector2) -> bool: return free.call(c) and g.building_at(c) >= 0)
	var bi := g.building_at(indoor)
	var a := g.join_player("uid-vis-aaaa", "A")
	var near := g.join_player("uid-vis-near", "N")
	var mid := g.join_player("uid-vis-mid0", "M")
	var inn := g.join_player("uid-vis-in00", "I")
	# A на улице в 3–10 клетках от здания, N — на улице рядом с A, M — на улице в 25–35 клетках (раньше был виден)
	a.pos = _cell_where(g, func(c: Vector2) -> bool: return free.call(c) and g.building_at(c) < 0 and c.distance_to(indoor) >= 3.0 and c.distance_to(indoor) <= 10.0)
	near.pos = _cell_where(g, func(c: Vector2) -> bool: return free.call(c) and g.building_at(c) < 0 and c.distance_to(a.pos) >= 4.0 and c.distance_to(a.pos) <= 10.0)
	mid.pos = _cell_where(g, func(c: Vector2) -> bool: return free.call(c) and g.building_at(c) < 0 and c.distance_to(a.pos) >= 25.0 and c.distance_to(a.pos) <= 35.0)
	inn.pos = indoor
	var placed := bi >= 0 and a.pos.x > 0 and near.pos.x > 0 and mid.pos.x > 0
	check("Видимость: свой игрок всегда в пакетах", placed and _seen_in(g, a.id, a.id) == [1, 1, 1], "%s" % [_seen_in(g, a.id, a.id)])
	check("Видимость: игрок рядом на улице виден (быстрый, полный и первый пакет)", placed and _seen_in(g, a.id, near.id) == [1, 1, 1],
		"%s, расстояние %.1f" % [_seen_in(g, a.id, near.id), near.pos.distance_to(a.pos)])
	check("Видимость: игрок за пределами экрана (25+ клеток) не приходит", placed and _seen_in(g, a.id, mid.id) == [0, 0, 0],
		"%s, расстояние %.1f" % [_seen_in(g, a.id, mid.id), mid.pos.distance_to(a.pos)])
	check("Видимость: игрок под крышей чужого здания с улицы не виден", placed and _seen_in(g, a.id, inn.id) == [0, 0, 0],
		"%s, расстояние %.1f" % [_seen_in(g, a.id, inn.id), inn.pos.distance_to(a.pos)])
	check("Видимость: из здания видно улицу рядом", placed and _seen_in(g, inn.id, a.id) == [1, 1, 1], "%s" % [_seen_in(g, inn.id, a.id)])
	# A заходит в то же здание — видит того, кто внутри
	a.pos = _cell_where(g, func(c: Vector2) -> bool: return free.call(c) and g.building_at(c) == bi and c != indoor)
	check("Видимость: в том же здании игроки видят друг друга", a.pos.x > 0 and _seen_in(g, a.id, inn.id) == [1, 1, 1], "%s" % [_seen_in(g, a.id, inn.id)])
	# выстрелы и эффекты — как раньше, в радиусе VIEW_R
	check("Видимость: радиус игроков меньше радиуса выстрелов и эффектов", GameState.SEE_R < GameState.VIEW_R and GameState.SEE_R >= 17.0)
	# телефон: кто пропал из снимка, тот перестаёт рисоваться
	var c := GameState.new_game(1)
	c.is_replica = true
	c.players.clear()
	a.pos = near.pos + Vector2(1, 0)
	c.load_data(JSON.parse_string(JSON.stringify(g.to_data_for(a.id))))
	var had := c.player(near.id) != null and c.player(near.id).connected
	near.pos = a.pos + Vector2(GameState.SEE_R + 5.0, 0)
	c.apply_state(g.state_for(a.id), a.id)
	check("Видимость: ушедший из вида игрок на телефоне больше не рисуется", had and not c.player(near.id).connected, "был %s" % had)

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
	# BF-045: понятные ошибки пароля (ответы Supabase Auth при проверке утёкших и коротких паролей)
	var AA = load("res://scripts/account.gd")
	var pwned: String = AA.explain(422, {"code": 422, "error_code": "weak_password", "msg": "Password is known to be weak and easy to guess", "weak_password": {"reasons": ["pwned"]}})
	var short: String = AA.explain(422, {"code": 422, "error_code": "weak_password", "msg": "Password should be at least 8 characters.", "weak_password": {"reasons": ["length"]}})
	check("Аккаунт: утёкший и короткий пароль — понятные разные сообщения (BF-045)",
		"утёк" in pwned and "минимум 8" in short and AA.MIN_PASSWORD == 8, "%s / %s" % [pwned, short])
	# BF-044: удалённые аккаунты — карточка уходит из мира по отпечатку id (sha256, как считает база)
	var gd := GameState.new_game(1)
	gd.players.clear()
	var keep_p := gd.join_player("sb:11111111-2222-3333-4444-555555555555", "Keep_Me", 11)
	var del_p := gd.join_player("sb:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "Del_Me", 12)
	del_p.money = 999
	# отпечаток из Postgres: encode(sha256(convert_to('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee','UTF8')),'hex')
	var pg_hash := "9af645a8fef33e6d34085cc69e0937d41d8b18c67d5f10cc9ff198b137b6e76a"
	check("Удаление аккаунта: отпечаток id в игре совпадает с отпечатком базы", "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee".sha256_text() == pg_hash, pg_hash)
	var none: Array = S.drop_deleted(gd, [])
	var gone_d: Array = S.drop_deleted(gd, [pg_hash.to_upper(), "0".repeat(64)])
	check("Удаление аккаунта: карточка удалённого аккаунта уходит из мира, остальные остаются (BF-044)",
		none.is_empty() and gone_d == [12] and gd.player(12) == null and gd.player(11) == keep_p and not gd.uids.has("sb:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee") and gd.uids.has("sb:11111111-2222-3333-4444-555555555555"),
		"удалено %s, ключи %s" % [gone_d, gd.uids.keys()])
	check("Удаление аккаунта: удалённого нет и в сохранении мира", not JSON.stringify(gd.to_data()).contains("Del_Me"))
	# С4, BF-043: подключения без входа с одного адреса
	var cl := []
	for spec in [["1.2.3.4", -1], ["1.2.3.4", -1], ["1.2.3.4", 5], ["5.6.7.8", -1], ["", -1]]:
		var cc = S.Client.new()
		cc.ip = spec[0]
		cc.pid = spec[1]
		cl.append(cc)
	check("Сервер: подключения без входа считаются по адресу, вошедшие и чужие адреса — нет (BF-043)",
		S.pending_from(cl, "1.2.3.4") == 2 and S.pending_from(cl, "5.6.7.8") == 1 and S.pending_from(cl, "") == 0 and S.MAX_PENDING_IP == 3)
	# Н1, BF-042: персонажи «по id телефона» на сервере с аккаунтами убираются, аккаунтные — нет
	var g := GameState.new_game(1)
	g.players.clear()
	var acc := g.join_player("sb:user-1", "Acc_One", 7)
	var ph1 := g.join_player("phone-aaaaaaaaaaaa", "Гражданин-AAAA")
	var ph2 := g.join_player("phone-bbbbbbbbbbbb", "Гражданин-BBBB")
	var shared := g.join_player("phone-cccccccccccc", "Shared_One")
	g.uids["sb:user-2"] = shared.id         # на эту карточку ссылается и аккаунт — её не трогаем
	for p: GameState.Player in [acc, ph1, ph2, shared]:
		g.leave_player(p.id)
	var gone: int = S.drop_phone_chars(g)
	var left_keys := g.uids.keys()
	left_keys.sort()
	check("Сервер: персонажи по id телефона убираются, аккаунтные и общие с аккаунтом остаются (Н1)",
		gone == 2 and g.player(ph1.id) == null and g.player(ph2.id) == null and g.player(acc.id) == acc and g.player(shared.id) == shared
		and left_keys == ["sb:user-1", "sb:user-2"], "удалено %d, ключи %s" % [gone, left_keys])
	check("Сервер: повторная уборка ничего не удаляет", S.drop_phone_chars(g) == 0)
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
	var small := {"t": "hello", "token": tok, "uid": "a".repeat(24), "nick": "N", "build": "21", "_from": 5}
	var huge := {"t": "act", "a": "use", "id": "x".repeat(10000), "_from": 5}
	check("Сервер: слишком большое сообщение распознаётся, обычное — нет", not S.too_big(small) and S.too_big(huge))
	check("Сеть: сервер не пересылает пакеты между клиентами", (Net.I.multiplayer as SceneMultiplayer).server_relay == false)

## Шифрование канала (BF-038): ключ сервера создаётся один раз и потом тот же; шифрованный клиент подключается
## и передаёт данные, нешифрованный — не подключается
func test_dtls() -> void:
	var dir := "user://audit_dtls"
	for f in ["dtls.key", "dtls.crt"]:
		if FileAccess.file_exists(dir.path_join(f)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
	var t1 := Net.server_tls(dir)
	var c1 := FileAccess.get_file_as_string(dir.path_join("dtls.crt"))
	var t2 := Net.server_tls(dir)
	var c2 := FileAccess.get_file_as_string(dir.path_join("dtls.crt"))
	check("Сеть: ключ шифрования сервера создаётся один раз и потом не меняется", t1 != null and t2 != null and c1 != "" and c1 == c2)
	var srv := ENetMultiplayerPeer.new()
	srv.create_server(7893, 4, 2)
	srv.host.dtls_server_setup(t2)
	var enc := ENetMultiplayerPeer.new()
	enc.create_client("127.0.0.1", 7893, 2)
	enc.host.dtls_client_setup(Net.TLS_NAME, Net.client_tls("127.0.0.1"))
	var plain := ENetMultiplayerPeer.new()
	plain.create_client("127.0.0.1", 7893, 2)
	# сверка сертификата (BF-038): «боевой» адрес — телефон ждёт именно этот сертификат
	var pin_ok := ENetMultiplayerPeer.new()
	pin_ok.create_client("127.0.0.1", 7893, 2)
	pin_ok.host.dtls_client_setup(Net.TLS_NAME, Net.client_tls("2.31.45.237", c2))
	var pin_bad := ENetMultiplayerPeer.new()      # сервер с чужим ключом (как подменный в своём Wi-Fi)
	pin_bad.create_client("127.0.0.1", 7893, 2)
	pin_bad.host.dtls_client_setup(Net.TLS_NAME, Net.client_tls("2.31.45.237"))
	var got := ""
	var sent := false
	var got_pin := false
	var sent_pin := false
	for i in 400:
		srv.poll()
		for cl: ENetMultiplayerPeer in [enc, plain, pin_ok, pin_bad]:
			cl.poll()
		if not sent and enc.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			enc.set_target_peer(1)
			enc.put_packet("проверка".to_utf8_buffer())
			sent = true
		if not sent_pin and pin_ok.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			pin_ok.set_target_peer(1)
			pin_ok.put_packet("сверено".to_utf8_buffer())
			sent_pin = true
		while srv.get_available_packet_count() > 0:
			var m := srv.get_packet().get_string_from_utf8()
			if m == "сверено":
				got_pin = true
			else:
				got = m
		if got != "" and got_pin and i > 200:
			break
		OS.delay_msec(10)
	var plain_ok := plain.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	var bad_ok := pin_bad.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	check("Сеть: зашифрованный клиент подключается и передаёт данные, без шифрования — не подключается",
		got == "проверка" and not plain_ok, "получено «%s», нешифрованный подключён: %s" % [got, plain_ok])
	check("Сеть: телефон подключается к серверу со своим сертификатом и не подключается к серверу с чужим ключом",
		got_pin and not bad_ok, "со своим сертификатом данные дошли: %s; с чужим подключён: %s" % [got_pin, bad_ok])
	var x := X509Certificate.new()
	check("Сеть: вшитый сертификат сервера читается, для локального адреса сверки нет",
		x.load_from_string(Net.SERVER_CERT) == OK and Net.client_tls("2.31.45.237") != null and Net.client_tls("2.31.45.237", "мусор") == null)
	for cl: ENetMultiplayerPeer in [enc, plain, pin_ok, pin_bad]:
		cl.close()
	srv.close()

## Подпись обновлений (BF-039): лаунчер принимает манифест только с верной подписью
func test_update_signature() -> void:
	var L = load("res://launcher/launcher.gd")
	var c := Crypto.new()
	var key := c.generate_rsa(2048)
	var other := c.generate_rsa(2048)
	var pub := Marshalls.utf8_to_base64(key.save_to_string(true))
	var body := '{"build":"99","files":[],"server":{"host":"2.31.45.237","port":7777}}'.to_utf8_buffer()
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(body)
	var sig := Marshalls.raw_to_base64(c.sign(HashingContext.HASH_SHA256, h.finish(), key))
	h.start(HashingContext.HASH_SHA256)
	h.update(body)
	var foreign := Marshalls.raw_to_base64(c.sign(HashingContext.HASH_SHA256, h.finish(), other))
	var evil := '{"build":"99","files":[],"server":{"host":"6.6.6.6","port":7777}}'.to_utf8_buffer()
	var good_ok: bool = L.signature_ok(body, sig, pub)
	var evil_ok: bool = L.signature_ok(evil, sig, pub)
	var foreign_ok: bool = L.signature_ok(body, foreign, pub)
	var none_ok: bool = L.signature_ok(body, "", pub)
	var junk_ok: bool = L.signature_ok(body, "не подпись", pub)
	check("Обновления: лаунчер принимает манифест с верной подписью и отклоняет подменённый, чужой ключ, без подписи",
		good_ok and not evil_ok and not foreign_ok and not none_ok and not junk_ok,
		"верный %s, подменённый адрес сервера %s, чужой ключ %s, без подписи %s, мусор %s" % [good_ok, evil_ok, foreign_ok, none_ok, junk_ok])

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
