class_name GameState
extends RefCounted

const PLAYER_R := 0.3
const MAX_WEIGHT := 15.0
const MINUTES_PER_SEC := 1.0
const VIEW_R := 40.0            # радиус, в котором видны другие игроки (клеток)
const START_MONEY := 500        # стартовые наличные нового персонажа, $
const RESPAWN_TIME := 20.0      # секунд без сознания

class Player:
	var id := 0
	var pos := Vector2.ZERO
	var face := Vector2(1, 0)
	var hp := 100.0
	var hunger := 10.0
	var thirst := 10.0
	var stamina := 100.0
	var dead := false
	var kills := 0
	var eq := ""
	var inv: Array = []
	var move := Vector2.ZERO
	var run := false
	var cooldown := 0.0
	var connected := true
	var attack_anim := 0.0
	var sneaking := false
	var ta_act = null          # действие со временем (Dictionary) или null
	var ta_name := ""
	var ta_time := 0.0
	var ta_dur := 0.0
	var climb := -1.0
	var cl_from := Vector2.ZERO
	var cl_to := Vector2.ZERO
	var rpos := Vector2.ZERO   # позиция для отрисовки
	var name := ""
	var remote := false        # движение считает телефон друга (хост только принимает)
	var force_seq := 0         # хост сдвинул игрока сам — клиент должен принять позицию
	var move_budget := 1.0     # сколько клеток друг может пройти до следующего пакета
	var last_in_ms := 0
	var atk_seq := 0           # номер удара: по нему второй телефон запускает анимацию ровно один раз
	var atk_kind := 0          # 0 — оружие/кулак, 1 — добивание ногой
	var respawn_t := 0.0       # без сознания: через сколько секунд очнётся в больнице
	var money := 0             # наличные (РП-экономика)
	var wear := {}             # слот → id надетой вещи (в inv её нет)
	var snaps: Array = []      # снимки [время, x, y, fx, fy, climb] для плавной отрисовки чужого игрока
	var rface := Vector2(1, 0)
	var rclimb := -1.0
	func _init(pid: int = 0) -> void:
		id = pid
	func weapon() -> Dictionary: return Items.def(eq if eq != "" else "fists")
	func weapon_id() -> String: return eq if eq != "" else "fists"
	## Надетое весит втрое меньше (как в PZ): одежда на теле не тянет руки
	func weight() -> float:
		var w := Items.weight(inv)
		for sl in wear:
			w += Items.def(wear[sl])["w"] * 0.3
		return w
	## Сколько можно нести без замедления: рюкзак добавляет
	func max_weight() -> float:
		return MAX_WEIGHT + (Items.def(wear["back"])["cap"] if wear.has("back") else 0.0)
	func count(item: String) -> int: return Items.count(inv, item)
	func take(item: String, n: int = 1) -> bool:
		var ok := Items.take(inv, item, n)
		if ok and Items.count(inv, item) == 0 and eq == item:
			eq = ""
		return ok
	func ta_progress() -> float: return clampf(ta_time / ta_dur, 0.0, 1.0) if ta_dur > 0.0 else 0.0

## Часы отправителя: какое мгновение его мира показывать сейчас, чтобы всегда было два снимка для плавного перехода
class NetClock:
	var off := INF        # (наше время − время отправителя) для самого быстрого пакета
	var jit := 25.0       # разброс прихода пакетов, мс
	var gap := 50.0       # как часто отправитель шлёт снимки (на слабом телефоне — реже)
	var last_ts := -1.0
	func sample(ts: float, now: float) -> void:
		if last_ts >= 0.0 and ts > last_ts:
			var g := ts - last_ts
			gap = lerpf(gap, g, 0.3 if g > gap else 0.05)
		last_ts = maxf(last_ts, ts)
		var s := now - ts
		if off == INF or s < off:
			off = s
		else:
			off += (s - off) * 0.003       # медленно следуем за уходом часов
		var dev := s - off
		jit = lerpf(jit, dev, 0.15 if dev > jit else 0.01)
	func delay() -> float:
		return clampf(maxf(60.0, gap * 1.3) + jit * 1.6, 75.0, 450.0)
	func render_time(now: float) -> float:
		return 0.0 if off == INF else now - off - delay()

var seed := 0
var spawn := Vector2(50, 50)   # точка появления и «больница»
var world := GameWorld.new()
var players: Array = []
var time := 8 * 60.0
var rnd := RandomNumberGenerator.new()
var is_replica := false
var freeze := false
var actions: Array = []        # [pid, action Dictionary]
var messages := {}             # pid → Array[String]
var shots: Array = []          # [x1, y1, x2, y2, жизнь]
var fx: Array = []             # [тип, x, y, параметр] — 1 кровь, 2 смерть зомби, 3 ранен игрок, 4 выстрел
var fx_net: Array = []
var uids := {}                 # постоянный ID телефона друга → номер персонажа

func _init(s: int = 0) -> void:
	seed = s
	rnd.seed = s ^ Time.get_ticks_usec()

static func new_game(s: int) -> GameState:
	var g := GameState.new(s)
	var start := g.world.generate(s)
	var p := Player.new(0)
	p.pos = start
	p.rpos = start
	p.inv = [{"id": "water", "n": 1}, {"id": "chips", "n": 1}]
	p.wear = {"legs": "jeans"}
	p.money = START_MONEY
	g.spawn = start
	g.players.append(p)
	g.world.compute_buildings()
	return g

func day() -> int: return int(time / 1440.0) + 1
func hour_f() -> float: return fmod(time, 1440.0) / 60.0
func clock() -> String:
	var m := int(fmod(time, 1440.0))
	return "%02d:%02d" % [m / 60, m % 60]

## 0 — светло, 1 — ночь
func darkness() -> float:
	var hh := hour_f()
	if hh < 5.0: return 1.0
	if hh < 7.0: return 1.0 - (hh - 5.0) / 2.0
	if hh < 19.0: return 0.0
	if hh < 21.5: return (hh - 19.0) / 2.5
	return 1.0

func player(pid: int) -> Player:
	for p: Player in players:
		if p.id == pid:
			return p
	return null

func msg(pid: int, text: String) -> void:
	if not messages.has(pid):
		messages[pid] = []
	messages[pid].append(text)

func add_fx(tp: int, x: float, y: float, a: float) -> void:
	var f := [tp, x, y, a]
	fx.append(f)
	fx_net.append(f)
	if fx_net.size() > 60:
		fx_net.pop_front()

## Игрок подключился: тот же телефон (uid) получает своего прежнего персонажа — это и есть «аккаунт»
func join_player(uid: String, pname: String) -> Player:
	var pid := -1
	if uids.has(uid):
		pid = int(uids[uid])
	else:
		pid = 1
		for p in players:
			pid = maxi(pid, p.id + 1)
		uids[uid] = pid
	var p := player(pid)
	if p == null:
		p = _spawn_player(pid)
	p.connected = true
	p.remote = true
	p.name = pname
	p.move = Vector2.ZERO
	p.force_seq += 1
	p.snaps.clear()
	return p

func _spawn_player(pid: int) -> Player:
	var p := Player.new(pid)
	p.pos = unstick(spawn + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)), PLAYER_R)
	p.rpos = p.pos
	p.inv = [{"id": "water", "n": 1}]
	p.wear = {"legs": "jeans"}
	p.money = START_MONEY
	players.append(p)
	return p

func leave_player(pid: int) -> void:
	var p := player(pid)
	if p == null:
		return
	p.connected = false
	p.move = Vector2.ZERO
	p.ta_act = null
	if p.climb >= 0.0:
		p.pos = p.cl_to
		p.climb = -1.0
		_release_climb(p)

# ================== СИМУЛЯЦИЯ ==================
func update(dt: float) -> void:
	if is_replica or freeze:
		return
	while actions.size() > 0:
		var a: Array = actions.pop_front()
		var p := player(a[0])
		if p != null and not p.dead:
			_do_action(p, a[1])
	time += dt * MINUTES_PER_SEC
	for p: Player in players:
		_update_player(p, dt)
	_age_shots(dt)

func _age_shots(dt: float) -> void:
	var i := shots.size() - 1
	while i >= 0:
		shots[i][4] -= dt
		if shots[i][4] <= 0.0:
			shots.remove_at(i)
		i -= 1

func tick_replica(dt: float) -> void:
	_age_shots(dt)
	for p in players:
		p.attack_anim = maxf(0.0, p.attack_anim - dt * anim_rate(p))
		p.cooldown -= dt

## Скорость анимации удара: добивание ногой дольше взмаха
static func anim_rate(p: Player) -> float:
	return 2.2 if p.atk_kind == 1 else 4.0

## Телефон друга: анимация своего удара сразу, не дожидаясь хоста
func predict_attack(p: Player) -> void:
	if p.dead or p.climb >= 0.0 or p.cooldown > 0.0:
		return
	p.cooldown = p.weapon()["cd"]
	p.atk_kind = 0
	p.attack_anim = 1.0

## Снимок для плавной отрисовки (время отправителя, мс)
static func push_snap(e, ts: float, pos: Vector2, face: Vector2, climb: float) -> void:
	var sn: Array = e.snaps
	if sn.size() > 0 and ts <= sn[sn.size() - 1][0]:
		return
	sn.append([ts, pos.x, pos.y, face.x, face.y, climb])
	if sn.size() > 30:
		sn.pop_front()

## Положение на момент t (время отправителя): между двумя снимками, без забегания вперёд
static func sample_snaps(e, t: float) -> void:
	var sn: Array = e.snaps
	if sn.is_empty():
		e.rpos = e.pos
		e.rface = e.face
		e.rclimb = e.climb
		return
	var last: Array = sn[sn.size() - 1]
	if t >= last[0]:
		e.rpos = Vector2(last[1], last[2])
		e.rface = Vector2(last[3], last[4])
		e.rclimb = last[5]
		return
	var i := sn.size() - 2
	while i > 0 and sn[i][0] > t:
		i -= 1
	var a: Array = sn[i]
	var b: Array = sn[i + 1]
	var f := clampf((t - a[0]) / maxf(1.0, b[0] - a[0]), 0.0, 1.0)
	var pa := Vector2(a[1], a[2])
	var pb := Vector2(b[1], b[2])
	e.rpos = pb if pa.distance_to(pb) > 3.0 else pa.lerp(pb, f)
	var fa := Vector2(a[3], a[4])
	var fb := Vector2(b[3], b[4])
	e.rface = Vector2.from_angle(lerp_angle(fa.angle(), fb.angle(), f)) if fa.length() > 0.01 and fb.length() > 0.01 else fb
	if a[5] >= 0.0 and b[5] >= 0.0:
		e.rclimb = lerpf(a[5], b[5], f)
	else:
		e.rclimb = b[5] if f > 0.5 else a[5]

func _cell_at(p: Vector2) -> int:
	return world.idx(clampi(floori(p.x), 0, world.w - 1), clampi(floori(p.y), 0, world.h - 1))

func move_speed(p: Player, mag: float) -> Array:
	var heavy := p.weight() > p.max_weight()
	var running := p.run and p.stamina > 1.0 and mag > 0.1
	p.sneaking = not running and mag >= 0.1 and mag <= 0.6
	var speed := 1.25 if p.sneaking else 2.3
	if running:
		speed = 3.9
	if heavy:
		speed *= 0.6
		running = false
	if p.stamina < 10.0:
		speed *= 0.8
	return [speed, running]

## Перемещение игрока. authoritative=false — предсказание на телефоне друга (без ран и шума)
func move_player(p: Player, dt: float, authoritative: bool) -> Array:
	var mag := p.move.length()
	var ms := move_speed(p, mag)
	var speed: float = ms[0]
	var running: bool = ms[1]
	if p.climb >= 0.0:
		p.climb += dt / 1.3
		p.pos = p.cl_from.lerp(p.cl_to, minf(p.climb, 1.0))
		if p.climb >= 1.0:
			p.climb = -1.0
			_release_climb(p)
		return [false, 0.0]
	if mag > 0.1:
		var n := p.move / maxf(1.0, mag)
		p.face = p.move / mag
		var before := p.pos
		p.pos = _move_circle(p.pos, n * speed * dt, PLAYER_R)
		if p.pos.distance_to(before) < speed * dt * 0.5:
			_try_climb(p, n, authoritative)
	return [running, mag]

func _release_climb(p: Player) -> void:
	for k in world.climb_occ.keys():
		if world.climb_occ[k] == -1 - p.id:
			world.climb_occ.erase(k)

func _update_player(p: Player, dt: float) -> void:
	if not p.connected:
		return
	if p.dead:
		# РП: не смерть, а потеря сознания — через время игрок приходит в себя у больницы
		p.respawn_t -= dt
		if p.respawn_t <= 0.0:
			_respawn(p)
		return
	p.cooldown -= dt
	p.attack_anim = maxf(0.0, p.attack_anim - dt * anim_rate(p))
	var running := false
	var mag := 0.0
	if p.remote and p.climb >= 0.0:
		# перелезание друга хост ведёт сам: нельзя «зависнуть» в окне неуязвимым
		p.climb += dt / 1.3
		p.pos = p.cl_from.lerp(p.cl_to, minf(p.climb, 1.0))
		if p.climb >= 1.0:
			p.climb = -1.0
			_release_climb(p)
			push_player(p, p.cl_to)
	elif p.remote:
		# позицию прислал телефон друга; здесь только последствия движения
		mag = p.move.length() if p.climb < 0.0 else 0.0
		running = move_speed(p, mag)[1] if mag > 0.1 else false
	else:
		var r := move_player(p, dt, true)
		running = r[0]
		mag = r[1]
	if p.climb >= 0.0:
		_finish_player(p, dt, false, 0.0)
		return
	if mag > 0.1:
		if running:
			p.stamina -= dt * 12.0
		if p.ta_act != null:
			p.ta_act = null
			msg(p.id, "Прервано")
	if p.ta_act != null:
		p.ta_time += dt
		if p.ta_time >= p.ta_dur:
			var a = p.ta_act
			p.ta_act = null
			_perform(p, a)
	_finish_player(p, dt, running, mag)

## Ввод с телефона друга: позиция, взгляд, перелезание. Всё проверяется — подделку хост откатывает
func remote_input(p: Player, o: Dictionary) -> void:
	p.move = Vector2(float(o.get("mx", 0.0)), float(o.get("my", 0.0))).limit_length(1.0)
	p.run = bool(o.get("run", false))
	if p.dead:
		return
	var now := Time.get_ticks_msec()
	var dt_in := 0.1 if p.last_in_ms == 0 else clampf((now - p.last_in_ms) / 1000.0, 0.0, 1.0)
	p.last_in_ms = now
	p.move_budget = minf(p.move_budget + dt_in * 3.9 * 1.25, 2.5)
	if int(o.get("fs", -1)) != p.force_seq:
		return    # друг ещё не получил наш принудительный сдвиг
	var np := Vector2(float(o.get("x", p.pos.x)), float(o.get("y", p.pos.y)))
	var fc := Vector2(float(o.get("fx", p.face.x)), float(o.get("fy", p.face.y)))
	if fc.length() > 0.01:
		p.face = fc.normalized()
	var cl := float(o.get("cl", -1.0))
	if p.climb >= 0.0:
		# лезет в окно: позиция только на отрезке перелезания
		if cl < 0.0:
			p.climb = -1.0
			_release_climb(p)
			if np.distance_to(p.cl_to) < 0.4 and not world.circle_blocked(np.x, np.y, PLAYER_R - 0.05):
				p.pos = np
			else:
				push_player(p, p.cl_to)
			p.move_budget = 1.0
			return
		return      # ход перелезания ведёт хост сам (см. _update_player)
	if cl >= 0.0:
		_remote_start_climb(p, o)
		return
	var d := np.distance_to(p.pos)
	if d > p.move_budget + 0.25 or world.circle_blocked(np.x, np.y, PLAYER_R - 0.05) or not _path_free(p.pos, np):
		push_player(p, p.pos)       # подделка или рассинхрон — вернуть друга туда, где он был
		return
	p.move_budget -= d
	p.pos = np

## Можно ли пройти от a до b, не проходя сквозь стены и закрытые двери (шагами по 0.15)
func _path_free(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := ceili(d.length() / 0.15)
	if steps == 0:
		return true
	var st := d / steps
	var c := a
	for i in steps:
		var n := _move_circle(c, st, PLAYER_R - 0.05)
		if n.distance_to(c + st) > 0.1:
			return false
		c = n
	return true

func _remote_start_climb(p: Player, o: Dictionary) -> void:
	var to := Vector2(float(o.get("ctx", p.pos.x)), float(o.get("cty", p.pos.y)))
	var mid := (p.pos + to) * 0.5
	var wc := world.idx(clampi(floori(mid.x), 0, world.w - 1), clampi(floori(mid.y), 0, world.h - 1))
	var ok := world.t_at(wc) == GameWorld.WINDOW_BROKEN and world.barr_at(wc) == 0 and not world.climb_occ.has(wc)
	if ok:
		var c := Vector2(wc % world.w + 0.5, wc / world.w + 0.5)
		var tg := world.climb_target(wc, p.pos.x, p.pos.y)
		ok = c.distance_to(p.pos) < 1.15 and tg.distance_to(to) < 0.3 and not world.circle_blocked(tg.x, tg.y, PLAYER_R)
	if not ok:
		push_player(p, p.pos)
		return
	p.climb = 0.0
	p.cl_from = p.pos
	p.cl_to = to
	world.climb_occ[wc] = -1 - p.id
	p.ta_act = null
	if rnd.randf() < 0.25:
		p.hp -= 4.0
		msg(p.id, "Порезался о стекло")

func push_player(p: Player, to: Vector2) -> void:
	p.pos = to
	p.force_seq += 1

func _try_climb(p: Player, n: Vector2, authoritative: bool = true) -> void:
	var wx := floori(p.pos.x + n.x * 0.6)
	var wy := floori(p.pos.y + n.y * 0.6)
	if not world.inside(wx, wy):
		return
	var wc := world.idx(wx, wy)
	if world.t_at(wc) != GameWorld.WINDOW_BROKEN or world.barr_at(wc) != 0 or world.climb_occ.has(wc):
		return
	if Vector2(wx + 0.5, wy + 0.5).distance_to(p.pos) > 1.05:
		return
	var tg := world.climb_target(wc, p.pos.x, p.pos.y)
	if world.circle_blocked(tg.x, tg.y, PLAYER_R):
		return
	p.climb = 0.0
	p.cl_from = p.pos
	p.cl_to = tg
	p.face = (tg - p.pos).normalized()
	if not authoritative:
		return
	world.climb_occ[wc] = -1 - p.id
	p.ta_act = null
	if rnd.randf() < 0.25:
		p.hp -= 4.0
		msg(p.id, "Порезался о стекло")

func _finish_player(p: Player, dt: float, running: bool, mag: float) -> void:
	if not running:
		p.stamina = minf(100.0, p.stamina + dt * (6.0 if mag > 0.1 else 12.0))
	# РП: голод и жажда растут медленно (сутки в игре — около суток реальных минут)
	p.hunger = minf(100.0, p.hunger + dt * 0.012)
	p.thirst = minf(100.0, p.thirst + dt * 0.018)
	if p.hunger >= 95.0 or p.thirst >= 95.0:
		p.hp -= dt * 0.2
	elif p.hunger < 70.0 and p.thirst < 70.0:
		p.hp = minf(100.0, p.hp + dt * 0.1)
	if p.hp <= 0.0:
		knock_out(p)

## Без сознания: персонаж лежит, через 20 секунд очнётся у больницы. Вещи и деньги при нём
func knock_out(p: Player) -> void:
	p.hp = 0.0
	p.dead = true
	p.respawn_t = RESPAWN_TIME
	p.move = Vector2.ZERO
	p.ta_act = null
	if p.climb >= 0.0:
		p.climb = -1.0
		_release_climb(p)
	msg(p.id, "Ты без сознания…")

func _respawn(p: Player) -> void:
	p.dead = false
	p.hp = 60.0
	p.hunger = minf(p.hunger, 50.0)
	p.thirst = minf(p.thirst, 50.0)
	push_player(p, unstick(spawn + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)), PLAYER_R))
	p.snaps.clear()
	msg(p.id, "Ты очнулся у больницы")

func _move_circle(pos: Vector2, d: Vector2, r: float) -> Vector2:
	if world.circle_blocked(pos.x, pos.y, r):
		# оказался внутри препятствия — выталкиваем в ближайшее свободное место, сквозь стены не пускаем
		return unstick(pos, r)
	var n := pos
	if not world.circle_blocked(n.x + d.x, n.y, r):
		n.x += d.x
	if not world.circle_blocked(n.x, n.y + d.y, r):
		n.y += d.y
	return n

## Ближайшая свободная точка (кольцами до 1.5 клетки)
func unstick(pos: Vector2, r: float) -> Vector2:
	for ring in range(1, 16):
		var dist := ring * 0.1
		for k in 16:
			var c := pos + Vector2.from_angle(TAU * k / 16.0) * dist
			if not world.circle_blocked(c.x, c.y, r):
				return c
	return pos
func _timing(p: Player, a: Dictionary) -> Array:
	match a["a"]:
		"wear":
			return [1.2 if Items.def(a["id"])["slot"] in ["torso", "legs", "back"] else 0.6, "Надеваю"]
		"unwear":
			return [0.8, "Снимаю"]
		"use":
			var k: int = Items.def(a["id"])["kind"]
			if k == Items.Kind.FOOD: return [1.6, "Ем"]
			if k == Items.Kind.DRINK: return [1.2, "Пью"]
			if k == Items.Kind.MED: return [2.0, "Лечусь"]
	return [0.0, ""]

## Действие должно иметь правильные поля нужных типов, иначе отбрасывается
static func valid_action(a) -> bool:
	if not (a is Dictionary) or not (a.get("a") is String):
		return false
	match a["a"]:
		"attack":
			return true
		"interact":
			return a.get("c") is int or a.get("c") is float
		"use", "drop", "wear":
			return a.get("id") is String and Items.DEFS.has(a["id"])
		"unwear":
			return a.get("slot") in Items.SLOTS
	return false

func _do_action(p: Player, a: Dictionary) -> void:
	if not valid_action(a):
		return
	for k in ["c"]:
		if a.has(k):
			a[k] = int(a[k])
	if a["a"] == "attack":
		p.ta_act = null
	if p.climb >= 0.0:
		return
	var tm := _timing(p, a)
	if tm[0] > 0.0:
		if p.ta_act != null:
			return
		p.ta_act = a
		p.ta_dur = tm[0]
		p.ta_time = 0.0
		p.ta_name = tm[1]
		return
	_perform(p, a)

func _perform(p: Player, a: Dictionary) -> void:
	match a["a"]:
		"attack": _attack(p)
		"interact": _interact(p, a["c"])
		"use": _use(p, a["id"])
		"wear": _wear(p, a["id"])
		"unwear": _unwear(p, a["slot"])
		"drop":
			# РП: выброшенная вещь пропадает (кучек на земле и обыска больше нет)
			var n := p.count(a["id"])
			if n > 0:
				if p.eq == a["id"]:
					p.eq = ""
				p.take(a["id"], n)

func near_cell(p: Player, cell: int, dist: float) -> bool:
	if cell < 0 or cell >= world.tiles.size():
		return false
	var c := Vector2(cell % world.w + 0.5, cell / world.w + 0.5)
	var tt := world.t_at(cell)
	if tt == GameWorld.CAR:
		c.x += 0.5
	elif tt == GameWorld.CAR_V:
		c.y += 0.5
	if GameWorld.is_car(tt):
		return c.distance_to(p.pos) < dist + 0.9
	return c.distance_to(p.pos) < dist

## Удар или выстрел. Урон считает только сервер; цель — другой игрок впереди
func _attack(p: Player) -> void:
	if p.cooldown > 0.0:
		return
	var w := p.weapon()
	p.cooldown = w["cd"]
	p.attack_anim = 1.0
	p.atk_kind = 0
	p.atk_seq = (p.atk_seq + 1) % 100000
	if w["kind"] == Items.Kind.GUN:
		if not p.take("ammo", 1):
			msg(p.id, "Нет патронов")
			p.cooldown = 0.3
			return
		var target: Player = null
		var best := INF
		for q: Player in players:
			if q == p or q.dead or not q.connected:
				continue
			var d: float = q.pos.distance_to(p.pos)
			if d >= w["range"] or not world.los(p.pos.x, p.pos.y, q.pos.x, q.pos.y, true):
				continue
			var cosv := (q.pos - p.pos).dot(p.face) / maxf(d, 0.01)
			if cosv < 0.8:
				continue          # стреляем туда, куда смотрим
			if d < best:
				best = d
				target = q
		var e: Vector2 = p.pos + p.face * w["range"]
		if target != null:
			e = target.pos
			if rnd.randf() < 0.85 - best * 0.02:
				hit_player(p, target, w["dmg"] * (0.8 + rnd.randf() * 0.4))
		shots.append([p.pos.x + p.face.x * 0.4, p.pos.y + p.face.y * 0.4, e.x, e.y, 0.08])
		add_fx(4, p.pos.x + p.face.x * 0.55, p.pos.y + p.face.y * 0.55, p.id)
		return
	p.stamina = maxf(0.0, p.stamina - 4.0)
	var reach: float = w["range"] + PLAYER_R
	var tq: Player = null
	var bd := INF
	for q: Player in players:
		if q == p or q.dead or not q.connected:
			continue
		var d: float = q.pos.distance_to(p.pos)
		if d < reach and d < bd and _in_front(p, q.pos) and world.los(p.pos.x, p.pos.y, q.pos.x, q.pos.y):
			bd = d
			tq = q
	if tq != null:
		p.face = (tq.pos - p.pos).normalized()
		var weak := 0.6 if p.stamina < 10.0 else 1.0
		hit_player(p, tq, w["dmg"] * 0.5 * weak * (0.8 + rnd.randf() * 0.4))
		var np := _move_circle(tq.pos, p.face * 0.25, PLAYER_R)
		if np != tq.pos:
			push_player(tq, np)

func _in_front(p: Player, at: Vector2) -> bool:
	var d: float = at.distance_to(p.pos)
	return (at - p.pos).dot(p.face) / maxf(d, 0.01) > 0.35

func hit_player(from: Player, q: Player, dmg: float) -> void:
	q.hp -= dmg
	q.ta_act = null
	add_fx(3, q.pos.x, q.pos.y, q.id)
	msg(q.id, "Тебя ударил %s" % (from.name if from.name != "" else "кто-то"))
	if q.hp <= 0.0:
		knock_out(q)
		msg(from.id, "%s без сознания" % (q.name if q.name != "" else "Игрок"))

func _interact(p: Player, cell: int) -> void:
	if not near_cell(p, cell, 1.8):
		return
	var tt := world.t_at(cell)
	if tt == GameWorld.DOOR:
		world.set_idx(cell, GameWorld.DOOR_OPEN)
	elif tt == GameWorld.DOOR_OPEN:
		var c := Vector2(cell % world.w + 0.5, cell / world.w + 0.5)
		# стоишь в проёме — шаг назад на свою сторону
		if absf(p.pos.x - c.x) < 0.5 + PLAYER_R and absf(p.pos.y - c.y) < 0.5 + PLAYER_R:
			var ay := world.along_y(cell % world.w, cell / world.w)
			var np := p.pos
			if ay:
				np = Vector2(clampf(p.pos.x, c.x - 0.5 + PLAYER_R + 0.02, c.x + 0.5 - PLAYER_R - 0.02), c.y + (-0.82 if p.pos.y < c.y else 0.82))
			else:
				np = Vector2(c.x + (-0.82 if p.pos.x < c.x else 0.82), clampf(p.pos.y, c.y - 0.5 + PLAYER_R + 0.02, c.y + 0.5 - PLAYER_R - 0.02))
			if not world.circle_blocked(np.x, np.y, PLAYER_R):
				push_player(p, np)
		var blocked := false
		for o: Player in players:
			if not o.dead and absf(o.pos.x - c.x) < 0.6 and absf(o.pos.y - c.y) < 0.6:
				blocked = true
		if blocked:
			msg(p.id, "Что-то мешает закрыть")
		else:
			world.set_idx(cell, GameWorld.DOOR)

## Надеть: вещь уходит из рук в слот, прежняя вещь этого слота — обратно в инвентарь
func _wear(p: Player, id: String) -> void:
	var d := Items.def(id)
	if d["kind"] != Items.Kind.WEAR or p.count(id) <= 0:
		return
	var sl: String = d["slot"]
	if not p.take(id):
		return
	if p.wear.has(sl):
		Items.add_to(p.inv, p.wear[sl], 1)
	p.wear[sl] = id
	msg(p.id, "Надето: " + d["name"].to_lower())

func _unwear(p: Player, sl: String) -> void:
	if not p.wear.has(sl):
		return
	var id: String = p.wear[sl]
	p.wear.erase(sl)
	Items.add_to(p.inv, id, 1)
	if sl == "back" and p.weight() > p.max_weight():
		msg(p.id, "Без рюкзака тяжело — ты замедлился")

func _use(p: Player, id: String) -> void:
	var d := Items.def(id)
	if p.count(id) <= 0:
		return
	match d["kind"]:
		Items.Kind.FOOD, Items.Kind.DRINK:
			p.take(id)
			p.hunger = clampf(p.hunger - d["hunger"], 0.0, 100.0)
			p.thirst = clampf(p.thirst - d["thirst"], 0.0, 100.0)
		Items.Kind.MED:
			if p.hp >= 100.0:
				msg(p.id, "Ты и так здоров")
				return
			p.take(id)
			p.hp = minf(100.0, p.hp + d["heal"])
			msg(p.id, "Стало легче")
		Items.Kind.MELEE, Items.Kind.GUN:
			p.eq = "" if p.eq == id else id
		Items.Kind.WEAR:
			_wear(p, id)

func find_interact(p: Player) -> int:
	var best := -1
	var bd := 9.0
	var px := floori(p.pos.x)
	var py := floori(p.pos.y)
	for y in range(py - 1, py + 2):
		for x in range(px - 1, px + 2):
			if not world.inside(x, y):
				continue
			var i := world.idx(x, y)
			var tt := world.t_at(i)
			if tt == GameWorld.CAR_TAIL:
				i = world.car_head(i)
				if i < 0:
					continue
				tt = world.t_at(i)
			# сейчас взаимодействовать можно только с дверями (обыск и разбивание окон из Zomboid убраны)
			var useful := tt == GameWorld.DOOR or tt == GameWorld.DOOR_OPEN
			if not useful:
				continue
			var c := Vector2(x + 0.5, y + 0.5)
			var d := c.distance_to(p.pos)
			if d > 1.6:
				continue
			d -= 0.4 * (c - p.pos).dot(p.face) / maxf(d, 0.01)
			if d < bd:
				bd = d
				best = i
	return best
func player_data(p: Player) -> Dictionary:
	return {"id": p.id, "x": snappedf(p.pos.x, 0.01), "y": snappedf(p.pos.y, 0.01), "fx": snappedf(p.face.x, 0.01), "fy": snappedf(p.face.y, 0.01),
		"hp": snappedf(p.hp, 0.01), "hu": snappedf(p.hunger, 0.01), "th": snappedf(p.thirst, 0.01), "st": snappedf(p.stamina, 0.01),
		"dead": p.dead, "rt": snappedf(p.respawn_t, 0.1), "k": p.kills, "eq": p.eq, "mo": p.money,
		"inv": Items.copy(p.inv), "aa": snappedf(p.attack_anim, 0.01), "con": p.connected, "sn": p.sneaking,
		"cl": snappedf(p.climb, 0.01), "tn": p.ta_name if p.ta_act != null else "", "tp": snappedf(p.ta_progress(), 0.01),
		"nm": p.name, "fs": p.force_seq, "wr": p.wear.duplicate(),
		"cfx": snappedf(p.cl_from.x, 0.01), "cfy": snappedf(p.cl_from.y, 0.01), "ctx": snappedf(p.cl_to.x, 0.01), "cty": snappedf(p.cl_to.y, 0.01)}

## Что видят другие игроки: без инвентаря, денег и здоровья (это личное)
func player_public(p: Player) -> Dictionary:
	return {"id": p.id, "x": snappedf(p.pos.x, 0.01), "y": snappedf(p.pos.y, 0.01), "pub": true,
		"dead": p.dead, "eq": p.eq, "nm": p.name, "wr": p.wear.duplicate(), "cl": snappedf(p.climb, 0.01), "fs": p.force_seq}

## Применить публичные данные чужого игрока, не трогая остальное
func player_from_public(o: Dictionary, p: Player) -> void:
	p.dead = bool(o.get("dead", false))
	p.eq = str(o.get("eq", ""))
	p.name = str(o.get("nm", ""))
	p.wear = {}
	var wr = o.get("wr", {})
	if wr is Dictionary:
		for sl in wr:
			var wid := str(wr[sl])
			if sl in Items.SLOTS and Items.DEFS.has(wid) and Items.def(wid)["slot"] == sl:
				p.wear[sl] = wid

func player_from(o: Dictionary, p: Player) -> void:
	p.pos = Vector2(float(o.get("x", p.pos.x)), float(o.get("y", p.pos.y)))
	p.face = Vector2(float(o.get("fx", 1.0)), float(o.get("fy", 0.0)))
	p.hp = float(o.get("hp", 100.0))
	p.hunger = float(o.get("hu", 10.0))
	p.thirst = float(o.get("th", 10.0))
	p.stamina = float(o.get("st", 100.0))
	p.dead = bool(o.get("dead", false))
	p.respawn_t = float(o.get("rt", 0.0))
	p.money = int(o.get("mo", START_MONEY))
	p.kills = int(o.get("k", 0))
	p.eq = o.get("eq", "")
	p.inv.clear()
	for s in o.get("inv", []):
		p.inv.append({"id": s["id"], "n": int(s["n"])})
	p.attack_anim = o.get("aa", 0.0)
	p.connected = o.get("con", true)
	p.sneaking = o.get("sn", false)
	p.climb = float(o.get("cl", -1.0))
	p.cl_from = Vector2(float(o.get("cfx", p.pos.x)), float(o.get("cfy", p.pos.y)))
	p.cl_to = Vector2(float(o.get("ctx", p.pos.x)), float(o.get("cty", p.pos.y)))
	p.name = o.get("nm", "")
	p.wear = {}
	var wr = o.get("wr", {})
	if wr is Dictionary:
		for sl in wr:
			var wid := str(wr[sl])
			if sl in Items.SLOTS and Items.DEFS.has(wid) and Items.def(wid)["slot"] == sl:
				p.wear[sl] = wid
	p.force_seq = int(o.get("fs", 0))
	var tn: String = o.get("tn", "")
	if tn != "":
		p.ta_name = tn
		p.ta_dur = 1.0
		p.ta_time = o.get("tp", 0.0)
		if p.ta_act == null:
			p.ta_act = {"a": "remote"}
	else:
		p.ta_act = null

func _cont_data(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[str(k)] = Items.copy(d[k])
	return o

func to_data() -> Dictionary:
	var thp := []
	for k in world.tile_hp:
		thp.append([k, world.tile_hp[k]])
	var ps := []
	for p: Player in players:
		ps.append(player_data(p))
	return {"v": SAVE_VERSION, "seed": seed, "time": time, "uids": uids.duplicate(), "tiles": Marshalls.raw_to_base64(world.tiles),
		"thp": thp, "cont": _cont_data(world.containers), "p": ps, "spawn": [spawn.x, spawn.y]}

## Мир для нового клиента: карта, контейнеры, время; из игроков — он сам полностью, остальные только внешне.
## Карту аккаунтов (uids) не отдаём никогда: uid — это ключ от чужого персонажа
func to_data_for(pid: int) -> Dictionary:
	var thp := []
	for k in world.tile_hp:
		thp.append([k, world.tile_hp[k]])
	var me := player(pid)
	var c: Vector2 = me.pos if me != null else spawn
	var ps := []
	for p: Player in players:
		if p.id == pid:
			ps.append(player_data(p))
		elif p.connected and absf(p.pos.x - c.x) <= VIEW_R and absf(p.pos.y - c.y) <= VIEW_R:
			var pub := player_public(p)
			pub["con"] = true
			ps.append(pub)
	return {"v": SAVE_VERSION, "seed": seed, "time": time, "tiles": Marshalls.raw_to_base64(world.tiles),
		"thp": thp, "cont": _cont_data(world.containers), "p": ps, "spawn": [spawn.x, spawn.y]}

const SAVE_VERSION := 1

## Проверка формата: без карты мира загружать нечего
static func valid_save(o) -> bool:
	if not (o is Dictionary) or not (o.get("tiles") is String):
		return false
	return Marshalls.base64_to_raw(o["tiles"]).size() == 100 * 100

## Перевод старых сохранений на текущий формат. Новое поле — новая версия и шаг здесь
static func migrate(o: Dictionary) -> Dictionary:
	if not o.has("uids"):
		o["uids"] = {}
	o["v"] = SAVE_VERSION
	return o

func load_data(o: Dictionary) -> void:
	o = migrate(o)
	time = float(o.get("time", 8 * 60.0))
	uids = o.get("uids", {}).duplicate() if o.get("uids") is Dictionary else {}
	var t := Marshalls.base64_to_raw(str(o.get("tiles", "")))
	for i in mini(t.size(), world.tiles.size()):
		world.tiles[i] = t[i]
	world.compute_buildings()
	world.cost_dirty = true
	world.tile_hp.clear()
	for e in o.get("thp", []):
		world.tile_hp[int(e[0])] = float(e[1])
	world.barr.clear()
	world.containers.clear()
	var sp = o.get("spawn")
	if sp is Array and sp.size() == 2:
		spawn = Vector2(float(sp[0]), float(sp[1]))
	var co: Dictionary = o.get("cont", {})
	for k in co:
		var l := []
		for s in co[k]:
			l.append({"id": s["id"], "n": int(s["n"])})
		world.containers[int(k)] = l
	players.clear()
	for e in o.get("p", []):
		var p := Player.new(int(e["id"]))
		player_from(e, p)
		if p.climb >= 0.0 and not is_replica:
			# сохранились посреди окна — ставим туда, куда он лез
			if not world.circle_blocked(p.cl_to.x, p.cl_to.y, PLAYER_R):
				p.pos = p.cl_to
			elif world.circle_blocked(p.pos.x, p.pos.y, PLAYER_R):
				p.pos = unstick(p.cl_from, PLAYER_R)
			p.climb = -1.0
		p.rpos = p.pos
		players.append(p)

# ================== СЕТЕВЫЕ СНИМКИ ==================
## Частый лёгкий снимок (ненадёжный канал): позиции рядом с другом
func state_for(pid: int) -> Dictionary:
	var me := player(pid)
	var c: Vector2 = me.pos if me != null else spawn
	var ps := PackedFloat32Array()
	for p in players:
		if not p.connected:
			continue
		# только те, кто рядом: при сотнях игроков пакет не растёт
		if p.id != pid and (absf(p.pos.x - c.x) > VIEW_R or absf(p.pos.y - c.y) > VIEW_R):
			continue
		ps.append_array([p.id, p.pos.x, p.pos.y, p.face.x, p.face.y, float(p.atk_seq * 2 + p.atk_kind), 1.0 if p.sneaking else 0.0, p.climb, p.force_seq, p.hp if p.id == pid else 0.0, p.stamina if p.id == pid else 0.0])
	var o := {"t": "st", "time": time, "ts": Time.get_ticks_msec(), "p": ps}
	if shots.size() > 0:
		o["sh"] = shots.duplicate(true)
	return o

## Редкий надёжный снимок: изменения мира, полные данные игроков, сообщения, эффекты
func events_for(pid: int, full_players: bool) -> Dictionary:
	var o := {"t": "ev"}
	if full_players:
		var me := player(pid)
		var c: Vector2 = me.pos if me != null else spawn
		var ps := []
		for p in players:
			if p.id == pid:
				ps.append(player_data(p))          # себе — всё
			elif p.connected and absf(p.pos.x - c.x) <= VIEW_R and absf(p.pos.y - c.y) <= VIEW_R:
				ps.append(player_public(p))        # другим — только внешность
		o["p"] = ps
	if fx_net.size() > 0:
		o["fx"] = fx_net.duplicate(true)
		fx_net.clear()
	if world.dirty_tiles.size() > 0:
		var a := []
		for i in world.dirty_tiles:
			a.append([i, world.t_at(i)])
		o["tc"] = a
		world.dirty_tiles.clear()
	if world.dirty_cont.size() > 0:
		var co := {}
		for i in world.dirty_cont:
			co[str(i)] = Items.copy(world.containers.get(i, []))
		o["cc"] = co
		world.dirty_cont.clear()
	var m := pop_messages(pid)
	if m.size() > 0:
		o["m"] = m
	return o

func pop_messages(pid: int) -> Array:
	var m: Array = messages.get(pid, [])
	messages.erase(pid)
	return m

## Клиент: принять лёгкий снимок. Свою позицию не трогаем — её считает этот телефон
func apply_state(o: Dictionary, local_pid: int) -> void:
	time = o["time"]
	var ts := float(o.get("ts", 0))
	var ps: PackedFloat32Array = o["p"]
	var seen := {}
	var i := 0
	while i + 10 < ps.size():
		var pid := int(ps[i])
		var p := player(pid)
		if p == null:
			p = Player.new(pid)
			p.pos = Vector2(ps[i + 1], ps[i + 2])
			p.rpos = p.pos
			players.append(p)
		p.connected = true
		seen[pid] = true
		if pid == local_pid:
			p.hp = ps[i + 9]
			p.stamina = ps[i + 10]
		var fs := int(ps[i + 8])
		var ak := int(ps[i + 5])
		var seq := ak >> 1
		if seq != p.atk_seq:
			p.atk_seq = seq
			if pid != local_pid:
				# новый удар: анимация с начала, один раз
				p.atk_kind = ak & 1
				p.attack_anim = 1.0
		if pid != local_pid:
			p.force_seq = fs
			p.pos = Vector2(ps[i + 1], ps[i + 2])
			p.face = Vector2(ps[i + 3], ps[i + 4])
			p.sneaking = ps[i + 6] > 0.5
			p.climb = ps[i + 7]
			push_snap(p, ts, p.pos, p.face, p.climb)
		elif fs != p.force_seq:
			# хост сдвинул нас сам (дверь, откат)
			p.force_seq = fs
			p.pos = Vector2(ps[i + 1], ps[i + 2])
			p.face = Vector2(ps[i + 3], ps[i + 4])
			p.climb = ps[i + 7]
			p.rpos = p.pos
		i += 11
	# кто пропал из снимка — ушёл далеко или вышел из игры
	for p in players:
		if p.id != local_pid and not seen.has(p.id):
			p.connected = false
			p.snaps.clear()
	for s in o.get("sh", []):
		var dup := false
		for e in shots:
			if is_equal_approx(e[2], s[2]) and is_equal_approx(e[3], s[3]):
				dup = true
		if not dup:
			shots.append([s[0], s[1], s[2], s[3], 0.08])

## Клиент: принять события
func apply_events(o: Dictionary, local_pid: int) -> void:
	for e in o.get("p", []):
		var pid := int(e["id"])
		var p := player(pid)
		if p == null:
			p = Player.new(pid)
			p.pos = Vector2(e["x"], e["y"])
			p.rpos = p.pos
			players.append(p)
		if e.get("pub", false) and pid != local_pid:
			player_from_public(e, p)
			continue
		var fresh := p.snaps.is_empty() and pid != local_pid
		var keep_pos := p.pos
		var keep_face := p.face
		var keep_climb := p.climb
		var keep_fs := p.force_seq
		var keep_aa := p.attack_anim
		var keep_sn := p.sneaking
		var keep_from := p.cl_from
		var keep_to := p.cl_to
		player_from(e, p)
		# движение и удары приходят быстрым каналом: надёжный пакет старше и не должен их откатывать
		p.attack_anim = keep_aa
		if not fresh and not (pid == local_pid and int(e.get("fs", 0)) != keep_fs):
			p.pos = keep_pos
			p.face = keep_face
			p.climb = keep_climb
			p.force_seq = keep_fs
			p.sneaking = keep_sn
			if pid == local_pid:
				p.cl_from = keep_from
				p.cl_to = keep_to
	for e in o.get("tc", []):
		var i := int(e[0])
		var nt := int(e[1])
		if world.t_at(i) != nt:
			world.events.append([i, world.t_at(i), nt])
			world.tiles[i] = nt
			world.cost_dirty = true
		world.vis_dirty[i] = true
	var cc: Dictionary = o.get("cc", {})
	for k in cc:
		var l := []
		for s in cc[k]:
			l.append({"id": s["id"], "n": int(s["n"])})
		world.containers[int(k)] = l
		world.vis_dirty[int(k)] = true
	for e in o.get("fx", []):
		fx.append(e)

