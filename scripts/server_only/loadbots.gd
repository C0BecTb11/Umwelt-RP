extends Node
## Нагрузочный тест: много лёгких ботов в одном процессе. Каждый бот — своё зашифрованное подключение со своим
## SceneMultiplayer и своим экземпляром Net (тот же протокол, что у телефона: hello → init → in раз в 50 мс),
## но без графики и без своей копии мира — поэтому сотни ботов помещаются на одной машине.
## Боты ходят по улице, сервер проверяет их ходы как обычно. В конце — сводка и «ИТОГ: OK/ОШИБКА».
## Запуск: godot --headless --path . -- --no-update --loadbots=число,порт,секунд   (сервер — с --noauth;
## --no-update нужен, чтобы лаунчер сразу открыл игру — сам лаунчер о --loadbots не знает, менять его = новый APK)

var role := ""
var main: Node

const MAX_CONNECTING := 2      # одновременно входящих: на сервере лимит 3 подключения без входа с одного адреса
const WALK := 2.0              # клеток в секунду (шаг; бег не нужен)

class Bot:
	var root: Node
	var net: Net
	var nick := ""
	var uid := ""
	var pid := -1
	var state := 0             # 0 ждёт очереди, 1 подключается, 2 в игре, 3 отключён
	var pos := Vector2.ZERO
	var dir := Vector2.RIGHT
	var fs := 0
	var in_t := 0.0
	var join_ms := 0
	var enter_ms := 0
	var st := 0                # быстрых снимков получено (за окно замера)
	var rollbacks := 0
	var why := ""

var bots: Array[Bot] = []
var ref: GameState            # мир для проверки стен (своя копия карты, только чтение)
var n := 40
var port := 7790
var dur := 60.0
var t := 0.0
var measure_t := -1.0         # с какого момента считаем (все вошли)
var bytes_in := 0.0
var done := false

func _ready() -> void:
	var parts := role.split(",")
	n = int(parts[0]) if parts.size() > 0 else 40
	port = int(parts[1]) if parts.size() > 1 else 7790
	dur = float(parts[2]) if parts.size() > 2 else 60.0
	ref = GameState.new_game(1)
	var keep := Net.I
	for i in n:
		var b := Bot.new()
		b.nick = "Нагрузка%d" % (i + 1)
		b.uid = "loadbot-%04d-%s" % [i + 1, "x".repeat(12)]
		b.root = Node.new()
		b.root.name = "Bot%d" % (i + 1)
		add_child(b.root)
		get_tree().set_multiplayer(SceneMultiplayer.new(), b.root.get_path())
		b.net = Net.new()
		b.net.name = "Net"        # путь для RPC — «Net», как у сервера
		b.root.add_child(b.net)
		bots.append(b)
	Net.I = keep                  # Net.new() в _ready переписывает Net.I — возвращаем настоящий
	print("[нагрузка] ботов %d, порт %d, замер %d с" % [n, port, int(dur)])

func _process(dt: float) -> void:
	if done:
		return
	t += dt
	var connecting := 0
	for b in bots:
		if b.state == 1:
			connecting += 1
	for b in bots:
		if b.state == 0 and connecting < MAX_CONNECTING:
			b.state = 1
			b.join_ms = Time.get_ticks_msec()
			b.net.join("127.0.0.1", port)
			connecting += 1
		_tick(b, dt)
	var mp_bytes := 0.0
	for b in bots:
		var mp := b.root.multiplayer.multiplayer_peer
		if mp is ENetMultiplayerPeer and (mp as ENetMultiplayerPeer).host != null:
			mp_bytes += (mp as ENetMultiplayerPeer).host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	var inside := 0
	for b in bots:
		if b.state == 2:
			inside += 1
	if measure_t < 0.0:
		if inside == n:
			measure_t = t
			for b in bots:
				b.st = 0
				b.rollbacks = 0
			print("[нагрузка] все %d вошли за %.1f с — начинаю замер" % [n, t])
		elif t > 30.0 + n * 0.5:
			_finish("вошли не все: %d из %d за %.0f с" % [inside, n, t])
		return
	bytes_in += mp_bytes
	if t - measure_t >= dur:
		_finish("")

func _tick(b: Bot, dt: float) -> void:
	if b.state == 0 or b.state == 3:
		return
	var net := b.net
	if b.state == 1 and net.connected and b.join_ms > 0:
		net.send({"t": "hello", "token": "", "uid": b.uid, "nick": b.nick, "build": Version.BUILD})
		b.join_ms = 0
	while not net.inbox.is_empty():
		var o: Dictionary = net.inbox.pop_front()
		match str(o.get("t", "")):
			"init":
				b.pid = int(o["pid"])
				for e in o["world"]["p"]:
					if int(e["id"]) == b.pid:
						b.pos = Vector2(float(e["x"]), float(e["y"]))
						b.fs = int(e.get("fs", 0))
				b.state = 2
				b.enter_ms = Time.get_ticks_msec()
				b.dir = Vector2.RIGHT.rotated(randi_range(0, 7) * PI / 4.0)
			"st":
				b.st += 1
				var ps: PackedFloat32Array = o["p"]
				var i := 0
				while i + 9 < ps.size():
					if int(ps[i]) == b.pid and int(ps[i + 7]) != b.fs:
						# сервер поправил позицию (откат) — принимаем, как телефон
						b.fs = int(ps[i + 7])
						b.pos = Vector2(ps[i + 1], ps[i + 2])
						b.rollbacks += 1
					i += 10
			"bye", "disconnect":
				b.state = 3
				b.why = str(o.get("why", "связь потеряна"))
	if b.state != 2:
		return
	# шаг по улице: упёрся в стену или в дверь дома — новое направление
	var nxt := b.pos + b.dir * WALK * dt
	if ref.world.circle_blocked(nxt.x, nxt.y, GameState.PLAYER_R) or ref.building_at(nxt) >= 0:
		b.dir = Vector2.RIGHT.rotated(randi_range(0, 7) * PI / 4.0)
	else:
		b.pos = nxt
	b.in_t -= dt
	if b.in_t <= 0.0:
		b.in_t = 0.05
		net.send_fast({"t": "in", "ts": Time.get_ticks_msec(), "mx": b.dir.x, "my": b.dir.y, "run": false,
			"x": b.pos.x, "y": b.pos.y, "fx": b.dir.x, "fy": b.dir.y, "fs": b.fs})

func _finish(err: String) -> void:
	done = true
	var span := maxf(t - measure_t, 0.001) if measure_t >= 0.0 else 0.0
	var alive := 0
	var st_min := 1e9
	var st_sum := 0.0
	var rb := 0
	var whys := {}
	for b in bots:
		if b.state == 2:
			alive += 1
		elif b.why != "":
			whys[b.why] = int(whys.get(b.why, 0)) + 1
		st_sum += b.st
		st_min = minf(st_min, b.st)
		rb += b.rollbacks
	if span <= 0.0:
		# замер не начался (вошли не все) — снимки и трафик не считаем
		span = 1.0
		st_sum = 0.0
		st_min = 0.0
		bytes_in = 0.0
	var st_avg := st_sum / maxi(n, 1) / span
	print("[нагрузка] в игре до конца: %d из %d%s" % [alive, n, ("; отключены: %s" % whys) if not whys.is_empty() else ""])
	print("[нагрузка] снимков на бота: в среднем %.1f/с, у худшего %.1f/с (сервер шлёт 20/с)" % [st_avg, st_min / span])
	print("[нагрузка] входящий трафик на бота: %.1f КБ/с; откатов позиции: %d на всех за %.0f с" % [bytes_in / 1024.0 / maxi(n, 1) / span, rb, span])
	var ok := err == "" and alive == n and st_avg >= 15.0
	if err != "":
		print("[нагрузка] ", err)
	print("[нагрузка] ИТОГ: ", "OK" if ok else "ОШИБКА")
	for b in bots:
		b.net.close()
	get_tree().quit(0 if ok else 1)
