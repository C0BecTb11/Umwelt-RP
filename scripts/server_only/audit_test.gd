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

func _ready() -> void:
	test_walls()
	test_corner()
	test_stuck_escape()
	test_remote_teleport()
	test_remote_climb_anywhere()
	test_remote_actions()
	test_saves()
	test_world_gen()
	test_remote_door()
	test_remote_climb_host_driven()
	test_save_mid_climb()
	test_death_mid_climb()
	test_bullet_window()
	test_remote_no_false_rollback()
	test_smooth_remote()
	test_attack_sync()
	test_house_layout()
	test_wear()
	test_look()
	test_clock()
	test_rp_rules()
	test_player_card()
	print("\nИТОГО: %d прошло, %d ошибок" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

func _game() -> GameState:
	return GameState.new_game(777)

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
	var o := {"mx": 0.0, "my": 0.0, "run": false, "fs": fs, "cl": -1.0, "fx": 1.0, "fy": 0.0}
	for k in 10:
		o["x"] = f.pos.x + 3.9
		o["y"] = f.pos.y
		g.remote_input(f, o)
	check("Сеть: игрок не может телепортироваться (10 пакетов по 3.9 клетки)", f.pos.distance_to(start) < 3.0, "сдвинулся на %.1f клеток мгновенно" % f.pos.distance_to(start))

func test_remote_climb_anywhere() -> void:
	var g := _game()
	var wc := _find_wall(g)
	var f := g.join_player("t2", "Друг")
	f.pos = Vector2(wc.x + 0.5, wc.y - 0.4)
	var o := {"mx": 0.0, "my": 0.0, "run": false, "fs": f.force_seq, "cl": 0.0, "fx": 0.0, "fy": 1.0,
		"x": f.pos.x, "y": f.pos.y, "ctx": f.pos.x, "cty": wc.y + 1.5}
	g.remote_input(f, o)
	check("Сеть: игрок не может «перелезть» через глухую стену", f.climb < 0.0, "хост принял перелезание через стену %s" % wc)
	var o2 := o.duplicate()
	o2["cl"] = -1.0
	o2["y"] = wc.y + 0.5
	g.remote_input(f, o2)
	check("Сеть: игрок не может прислать позицию внутри стены", not g.world.circle_blocked(f.pos.x, f.pos.y, 0.25), "позиция %s внутри стены принята" % f.pos)

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
	check("РП: шкафы не обыскиваются, окна не разбиваются (механики Zomboid убраны)", not g.world.containers.has(fr) and g.world.t_at(win) == W.WINDOW and f.inv.is_empty(),
		"шкаф открыт: %s, окно: %d" % [g.world.containers.has(fr), g.world.t_at(win)])

func test_saves() -> void:
	var g := _game()
	var d := g.to_data()
	var g2 := GameState.new(0)
	g2.load_data(JSON.parse_string(JSON.stringify(d)))
	check("Сохранение: мир и игроки восстанавливаются", g2.players.size() == g.players.size() and g2.world.tiles == g.world.tiles)
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
	var loaded := Saves.load_game()
	check("Сохранение: повреждённый файл не роняет игру", loaded == null or loaded is GameState)
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
	var b := GameState.new_game(4242)
	check("Мир: один seed — одинаковый город", a.world.tiles == b.world.tiles)
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
			var passable := not (tt == W.WALL or tt == W.TREE or W.is_furniture(tt) or W.is_car(tt) or tt == W.WINDOW or tt == W.WINDOW_BROKEN)
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

func _start_remote_climb(g: GameState, f: GameState.Player) -> Vector2i:
	var wc := _find_opening(g, W.WINDOW)
	if wc.x < 0:
		return wc
	var i := g.world.idx(wc.x, wc.y)
	g.world.tiles[i] = W.WINDOW_BROKEN
	f.pos = Vector2(wc.x + 0.5, wc.y - 0.5)
	var tg := g.world.climb_target(i, f.pos.x, f.pos.y)
	g.remote_input(f, {"mx": 0.0, "my": 1.0, "run": false, "fs": f.force_seq, "cl": 0.0, "fx": 0.0, "fy": 1.0,
		"x": f.pos.x, "y": f.pos.y, "ctx": tg.x, "cty": tg.y})
	return wc

func test_remote_door() -> void:
	var g := _game()
	var dc := _find_opening(g, W.DOOR)
	var f := g.join_player("d1", "Друг")
	f.pos = Vector2(dc.x + 0.5, dc.y - 0.35)
	var o := {"mx": 0.0, "my": 1.0, "run": false, "fs": f.force_seq, "cl": -1.0, "fx": 0.0, "fy": 1.0,
		"x": dc.x + 0.5, "y": dc.y + 1.35}
	g.remote_input(f, o)
	check("Сеть: игрок не может пройти сквозь закрытую дверь одним пакетом", f.pos.y < dc.y, "дверь %s, друг принят на %s" % [dc, f.pos])

func test_remote_climb_host_driven() -> void:
	var g := _game()
	var f := g.join_player("c1", "Друг")
	var wc := _start_remote_climb(g, f)
	var started := f.climb >= 0.0
	# телефон друга «завис» и больше ничего не шлёт
	for k in 40:
		g.update(0.05)
	check("Сеть: перелезание игрока заканчивает сервер — нельзя зависнуть в окне неуязвимым", started and f.climb < 0.0 and g.world.climb_occ.is_empty() and f.pos.y > wc.y + 0.5,
		"окно %s, старт %s, climb %.2f, pos %s, занято %s" % [wc, started, f.climb, f.pos, g.world.climb_occ])

func test_save_mid_climb() -> void:
	var g := _game()
	var f := g.join_player("c2", "Друг")
	var wc := _start_remote_climb(g, f)
	for k in 8:
		g.update(0.05)
	var mid := f.climb
	var g2 := GameState.new(g.seed)
	g2.load_data(JSON.parse_string(JSON.stringify(g.to_data())))
	var f2 := g2.player(f.id)
	check("Сохранение посреди окна: персонаж не телепортируется в угол карты", mid > 0.0 and f2 != null and f2.climb < 0.0 and f2.pos.distance_to(f.cl_to) < 0.05,
		"climb %.2f, после загрузки %s, ожидалось %s" % [mid, f2.pos if f2 else Vector2.ZERO, f.cl_to])

func test_death_mid_climb() -> void:
	var g := _game()
	var f := g.join_player("c3", "Друг")
	_start_remote_climb(g, f)
	f.hp = -5.0
	g.update(0.05)
	check("Потеря сознания в окне освобождает окно", f.dead and g.world.climb_occ.is_empty(), "занято: %s" % g.world.climb_occ)

func test_bullet_window() -> void:
	var g := _game()
	var wc := _find_opening(g, W.WINDOW)
	var a := Vector2(wc.x + 0.5, wc.y - 1.5)
	var b := Vector2(wc.x + 0.5, wc.y + 1.5)
	var through_glass := g.world.los(a.x, a.y, b.x, b.y, true)
	var see := g.world.los(a.x, a.y, b.x, b.y)
	g.world.tiles[g.world.idx(wc.x, wc.y)] = W.WINDOW_BROKEN
	var through_hole := g.world.los(a.x, a.y, b.x, b.y, true)
	check("Бой: пуля не проходит сквозь целое стекло, но проходит в разбитое окно", see and not through_glass and through_hole,
		"видно %s, сквозь стекло %s, сквозь проём %s" % [see, through_glass, through_hole])


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
		cf.climb = -1.0
		cf.move = Vector2.from_angle(randf() * TAU)
		cf.run = randf() < 0.5
		routes += 1
		for i in 120:
			c.move_player(cf, 1.0 / 60.0, false)
			if cf.climb >= 0.0:
				break
			if i % 3 == 2:
				f.last_in_ms = Time.get_ticks_msec() - 50
				var fs := f.force_seq
				g.remote_input(f, {"mx": cf.move.x, "my": cf.move.y, "run": cf.run, "fs": cf.force_seq, "cl": -1.0,
					"fx": cf.face.x, "fy": cf.face.y, "x": cf.pos.x, "y": cf.pos.y})
				if f.force_seq != fs:
					rollbacks += 1
					cf.pos = f.pos
					cf.force_seq = f.force_seq
	check("Сеть: честного игрока не откатывает у стен и углов (%d маршрутов)" % routes, rollbacks == 0, "%d ложных откатов" % rollbacks)


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
				GameState.push_snap(e, q[1], q[2], Vector2(1, 0), -1.0)
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
	for sd in [777, 12345, 4242, 99]:
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
	# драка: b стоит перед a
	b.pos = g.unstick(a.pos + a.face * 0.8, GameState.PLAYER_R)
	a.face = (b.pos - a.pos).normalized()
	var hp0 := b.hp
	for k in 40:
		a.cooldown = 0.0
		g.actions.append([a.id, {"a": "attack"}])
		g.update(0.02)
		b.pos = g.unstick(a.pos + a.face * 0.8, GameState.PLAYER_R)
	check("Драка: удары по другому игроку отнимают здоровье и могут отправить в нокаут", b.hp < hp0 and b.dead, "хп %.0f, без сознания %s" % [b.hp, b.dead])
	for k in int(GameState.RESPAWN_TIME / 0.1) + 5:
		g.update(0.1)
	check("Нокаут: через время игрок очнулся у больницы с вещами", not b.dead and b.hp > 0.0 and b.pos.distance_to(g.spawn) < 3.0, "без сознания %s, позиция %s" % [b.dead, b.pos])

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
