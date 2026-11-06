extends Node
## Сетевой автотест: несколько копий игры подключаются к выделенному серверу.
## Запуск сервера:  godot --headless -- --server --port=7790
## Запуск клиента:  godot --headless -- --nettest=имя,порт,ожидаемо_других
## Клиент входит, 2 с идёт, стоит, проверяет, что видит остальных и что сервер принял его позицию.

var role := ""
var main: Node
var t := 0.0
var step := 0
var nick := ""
var port := 7790
var expect := 0
var start_pos := Vector2.ZERO
var start_fs := 0
var move_rollbacks := 0
var saw_max := 0
var frozen := 0
var frames := 0
var last_other := {}
var free_len := 0.0            # сколько клеток свободно в выбранном направлении (до стены, не больше 6)

func _ready() -> void:
	var parts := role.split(",")
	nick = parts[0]
	if parts.size() > 1:
		port = int(parts[1])
	if parts.size() > 2:
		expect = int(parts[2])
	reconnect = parts.size() > 3 and parts[3] == "reconnect"
	Profile.load_profile()
	Profile.nick = nick
	Profile.uid = ("test-" + nick + "-0000000000").left(24)

var reconnect := false         # 4-й параметр «reconnect»: после проверки ждём обрыва и переподключения (BF-047)
var first_screen: GameScreen
var saw_lost := false

func L(s: String) -> void:
	print("[%s %.1f] %s" % [nick, t, s])

func _process(dt: float) -> void:
	t += dt
	var scr: GameScreen = main.screen
	match step:
		0:
			Net.I.join(OS.get_environment("NT_HOST") if OS.get_environment("NT_HOST") != "" else "127.0.0.1", port)
			main._start(GameScreen.Mode.CLIENT, null)
			step = 1
		1:
			scr = main.screen
			if scr != null and scr.game != null and scr.me() != null:
				start_pos = scr.me().pos
				start_fs = scr.me().force_seq
				L("вошёл, персонаж %d на %s" % [scr.local_pid, start_pos.snapped(Vector2(0.01, 0.01))])
				scr.debug_move = _free_dir(scr)
				step = 2
				t = 0.0
			elif t > 15.0:
				L("ИТОГ: ОШИБКА — не вошёл (%s)" % Net.I.status)
				get_tree().quit(1)
		2:
			_watch(scr)
			if t > 2.0:
				scr.debug_move = Vector2.ZERO
				move_rollbacks = scr.me().force_seq - start_fs
				step = 3
				t = 0.0
		3:
			_watch(scr)
			if t > 4.0:
				var me := scr.me()
				var moved := me.pos.distance_to(start_pos)
				var rollbacks := move_rollbacks
				# шагом 2 с — около 4.6 клетки, если путь свободен; замирания чужих бегущих — не больше 5% кадров
				var need := minf(free_len, 4.6) * 0.6
				var ok := saw_max >= expect and rollbacks == 0 and not scr.lost and moved >= need and frozen <= frames * 0.05
				L("прошёл %.2f клетки (нужно ≥ %.2f), откатов %d, видел других: %d (ожидалось %d), кадров с другими %d, из них без движения у бегущих %d" % [moved, need, rollbacks, saw_max, expect, frames, frozen])
				if reconnect and ok:
					L("жду обрыва связи и переподключения")
					first_screen = scr
					step = 4
					t = 0.0
					return
				L("ИТОГ: %s" % ("OK" if ok else "ОШИБКА"))
				get_tree().quit(0 if ok else 1)
		4:
			if is_instance_valid(first_screen) and first_screen.lost and not saw_lost:
				saw_lost = true
				L("связь потеряна (%s), %s" % [Net.I.status, first_screen.retry_note])
			if scr != null and scr != first_screen and scr.game != null and scr.me() != null:
				var same := scr.me().pos.distance_to(start_pos) < 30.0
				L("переподключился сам: персонаж %d на %s" % [scr.local_pid, scr.me().pos.snapped(Vector2(0.01, 0.01))])
				L("ИТОГ: %s" % ("OK" if saw_lost and same else "ОШИБКА"))
				get_tree().quit(0 if saw_lost and same else 1)
			elif t > 75.0:
				L("ИТОГ: ОШИБКА — не переподключился за 75 с (%s)" % Net.I.status)
				get_tree().quit(1)

## Направление, где дальше всего свободно по улице (из четырёх), чтобы бот не упёрся в стену сразу и не зашёл в дом
func _free_dir(scr: GameScreen) -> Vector2:
	var best := Vector2(1, 0)
	free_len = 0.0
	var me := scr.me()
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var l := 0.0
		# только по улице: игрока под чужой крышей другие не получают (0.26, BF-040) — бот, зашедший в дом, «пропал» бы
		while l < 6.0 and not scr.game.world.circle_blocked(me.pos.x + d.x * (l + 0.1), me.pos.y + d.y * (l + 0.1), GameState.PLAYER_R) \
				and scr.game.building_at(me.pos + d * (l + 0.1 + GameState.PLAYER_R)) < 0:
			l += 0.1
		if l > free_len:
			free_len = l
			best = d
	return best

func _watch(scr: GameScreen) -> void:
	var n := 0
	for p in scr.game.players:
		if p.id == scr.local_pid or not p.connected:
			continue
		n += 1
		frames += 1
		var prev: Vector2 = last_other.get(p.id, p.rpos)
		if p.snaps.size() >= 3:
			var sn: Array = p.snaps
			var moving: bool = absf(sn[sn.size() - 1][1] - sn[sn.size() - 3][1]) + absf(sn[sn.size() - 1][2] - sn[sn.size() - 3][2]) > 0.05
			if moving and p.rpos.distance_to(prev) < 0.0001:
				frozen += 1
		last_other[p.id] = p.rpos
	saw_max = maxi(saw_max, n)
