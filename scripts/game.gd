class_name GameState
extends RefCounted

const PLAYER_R := 0.3
const MAX_WEIGHT := 15.0
const MINUTES_PER_SEC := 1.0   # скорость времени, если часы не реальные (демо-снимки)
const MSK_OFFSET := 3 * 3600   # время в игре — московское (UTC+3, без перехода на летнее)
const VIEW_R := 40.0            # радиус, в котором приходят выстрелы и эффекты (клеток)
const SEE_R := 20.0             # радиус, в котором приходят другие игроки: экран телефона (до ~17 клеток) с запасом
const START_MONEY := 500        # стартовые наличные нового персонажа, $
const RESPAWN_TIME := 20.0      # секунд без сознания
# PayDay и уровни (с 0.52, решение владельца 2026-11-07): раз в час по серверу (в 00 минут по МСК) каждому
# в игре — PayDay. Отыграл за час не меньше 20 минут (без АФК) — зарплата на банковский счёт и 1 очко опыта,
# иначе ничего и плашка «не отыграли 20 минут». Уровень 1→2 — 4 очка, дальше на 2 больше за уровень (4, 6, 8…)
const PAYDAY_MIN_PLAY := 20 * 60.0   # секунд игры за час для PayDay
const AFK_AFTER := 120.0             # секунд без движения, действий и чата — дальше время идёт в АФК
# Чат (с 0.52): обычная речь — слышат те, кто ближе CHAT_R (как в SAMP)
const CHAT_R := 20.0                 # м
const CHAT_MAX := 120                # символов в сообщении
const CHAT_GAP := 1.0                # с между сообщениями одного игрока

## Карточка игрока. ВСЁ, что принадлежит игроку (деньги, счёт, вещи, одежда, позиция, а дальше — права,
## фракция, работа, ключи от домов и машин), — поля этой карточки и сохраняются в player_data().
## Отдельных словарей «игрок → что-то» вне карточки не заводим. Мир (дома, машины) ссылается на игрока по id.
class Player:
	var id := 0                # постоянный ID игрока (= characters.id в Supabase), виден в скобках у ника
	var pos := Vector2.ZERO
	var face := Vector2(1, 0)
	var hp := 100.0
	var hunger := 10.0
	var thirst := 10.0
	var stamina := 100.0
	var dead := false
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
	var rpos := Vector2.ZERO   # позиция для отрисовки
	var name := ""
	var remote := false        # движение считает телефон друга (хост только принимает)
	var force_seq := 0         # хост сдвинул игрока сам — клиент должен принять позицию
	var move_budget := 1.0     # сколько клеток друг может пройти до следующего пакета
	var last_in_ms := 0
	# бег по сети считается по пройденному пути за полсекунды, а не по словам клиента (С2); не сохраняется
	var win_d := 0.0
	var win_t := 0.0
	var net_running := false
	var net_mag := 0.0
	var atk_seq := 0           # номер удара: по нему второй телефон запускает анимацию ровно один раз
	var atk_kind := 0          # 0 — оружие/кулак, 1 — добивание ногой
	var respawn_t := 0.0       # без сознания: через сколько секунд очнётся в больнице
	var money := 0             # наличные, $
	var bank := 0              # банковский счёт, $
	var wear := {}             # слот → id надетой вещи (в inv её нет)
	var look := {}             # внешность: g — пол "m"/"f", h — причёска (часть модели), sk — тон кожи 0..3
	var snaps: Array = []      # снимки [время, x, y, fx, fy] для плавной отрисовки чужого игрока
	var level := 1             # уровень (открывает работы — позже)
	var exp := 0               # очки опыта к следующему уровню: 1 за засчитанный PayDay
	var hour_play := 0.0       # с: отыграно (без АФК) с прошлого PayDay
	var day := -1              # номер суток по МСК, к которым относятся day_play/day_afk
	var day_play := 0.0        # с: отыграно сегодня (без АФК)
	var day_afk := 0.0         # с: сегодня в игре, но без движения и действий дольше AFK_AFTER
	var reg := ""              # дата регистрации аккаунта «ГГГГ-ММ-ДД» (МСК): из Supabase characters.created_at
	var idle := 0.0            # с без движения/действий/чата (не сохраняется)
	var chat_cd := 0.0         # с до следующего сообщения в чат (не сохраняется)
	var rface := Vector2(1, 0)
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
	## Сколько можно нести без замедления
	func max_weight() -> float:
		return MAX_WEIGHT
	func gender() -> String: return str(look.get("g", "m"))
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
var fx: Array = []             # [тип, x, y, параметр] — 3 ранен игрок, 4 выстрел
var fx_net: Array = []
var uids := {}                 # постоянный ID телефона друга → номер персонажа
var real_clock := true         # время = реальное московское; false — идёт само (демо-снимки)
var chat := {}                 # pid → Array[String] — строки чата для этого игрока (уходят в ev "c")
var payday_hour := -1          # номер часа (минуты МСК / 60) последнего PayDay; -1 — ещё не считали

func _init(s: int = 0) -> void:
	seed = s
	rnd.seed = s ^ Time.get_ticks_usec()

## Новый мир: карта из файла maps/city.json (s — только номер мира, город от него не зависит)
static func new_game(s: int) -> GameState:
	var g := GameState.new(s)
	g.load_official_map()
	var start := g.spawn
	var p := Player.new(0)
	p.pos = start
	p.rpos = start
	p.inv = [{"id": "water", "n": 1}, {"id": "chips", "n": 1}]
	p.wear = Items.START_WEAR.duplicate()
	p.look = default_look(0, "m")
	p.money = START_MONEY
	g.players.append(p)
	return g

## Карта игры из файла. Ошибка здесь — значит, в выпуск попал битый файл: проверяет автотест
func load_official_map() -> void:
	var err := world.load_map(GameWorld.read_map_file())
	if err != "":
		push_error("Карта maps/city.json не загрузилась: " + err)
	spawn = world.spawn

## Московское время в минутах от 1970 года: остаток от деления на 1440 — минуты текущих суток по МСК
static func msk_time() -> float:
	return (Time.get_unix_time_from_system() + MSK_OFFSET) / 60.0

const MONTHS := ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]

## Дата в игре («2 ноября») — по московскому календарю; у демо-снимков (своё время) даты нет
func date_str() -> String:
	if time < 1440.0 * 365.0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(int(time * 60.0))
	return "%d %s" % [d["day"], MONTHS[int(d["month"]) - 1]]

func hour_f() -> float: return fmod(time, 1440.0) / 60.0
func clock() -> String:
	var m := int(fmod(time, 1440.0))
	return "%02d:%02d" % [m / 60, m % 60]

## 0 — светло, 1 — ночь
func darkness() -> float:
	var hh := hour_f()
	# темно только ночью: светло 06:00–21:00, сумерки до 22:30, ночь до 04:30, рассвет до 06:00
	if hh < 4.5: return 1.0
	if hh < 6.0: return 1.0 - (hh - 4.5) / 1.5
	if hh < 21.0: return 0.0
	if hh < 22.5: return (hh - 21.0) / 1.5
	return 1.0

func player(pid: int) -> Player:
	for p: Player in players:
		if p.id == pid:
			return p
	return null

## Очков опыта до следующего уровня: 1→2 — 4, 2→3 — 6, 3→4 — 8 … (владелец, 2026-11-07)
static func exp_need(level: int) -> int:
	return 2 * maxi(level, 1) + 2

## Зарплата в PayDay. Её платит организация (фракция, работа); организаций пока нет — 0 (владелец, 2026-11-07)
func payday_salary(_p: Player) -> int:
	return 0

## Дата «ГГГГ-ММ-ДД» по МСК из времени игры (минуты от 1970 по МСК)
func today_str() -> String:
	return Time.get_date_string_from_unix_time(int(time * 60.0))

## Дата регистрации из Supabase (created_at, UTC, «2026-11-04T12:34:56.1+00:00») → «ГГГГ-ММ-ДД» по МСК
static func reg_from_iso(s: String) -> String:
	if s.length() < 19:
		return ""
	var u := Time.get_unix_time_from_datetime_string(s.left(19))
	if u <= 0:
		return ""
	return Time.get_date_string_from_unix_time(u + MSK_OFFSET)

## «7 ноября 2026» из «2026-11-07»
static func date_ru(d: String) -> String:
	var a := d.split("-")
	if a.size() != 3 or not a[1].is_valid_int() or int(a[1]) < 1 or int(a[1]) > 12:
		return "—"
	return "%d %s %s" % [int(a[2]), MONTHS[int(a[1]) - 1], a[0]]

## «2 ч 33 мин» / «12 мин»
static func dur_ru(sec: float) -> String:
	var m := int(sec / 60.0)
	return "%d ч %02d мин" % [m / 60, m % 60] if m >= 60 else "%d мин" % m

## Время в игре и АФК; сутки — по МСК
func _account_time(p: Player, dt: float, today: int) -> void:
	if p.day != today:
		p.day = today
		p.day_play = 0.0
		p.day_afk = 0.0
	p.chat_cd = maxf(0.0, p.chat_cd - dt)
	if not p.connected:
		return
	p.idle += dt
	if p.idle < AFK_AFTER:
		p.hour_play += dt
		p.day_play += dt
	else:
		p.day_afk += dt

## PayDay: всем, кто в игре. Отыгранное за час обнуляется у всех (и у вышедших — часы не копятся)
func payday() -> void:
	for p: Player in players:
		if p.connected:
			if p.hour_play >= PAYDAY_MIN_PLAY:
				var pay := payday_salary(p)
				p.bank += pay
				p.exp += 1
				var up := false
				while p.exp >= exp_need(p.level):
					p.exp -= exp_need(p.level)
					p.level += 1
					up = true
				msg(p.id, "PayDay! Зарплата $%d зачислена на банковский счёт" % pay)
				msg(p.id, ("Новый уровень: %d! Опыт %d/%d" if up else "Уровень %d, опыт %d/%d") % [p.level, p.exp, exp_need(p.level)])
			else:
				msg(p.id, "PayDay: зарплата и опыт не начислены")
				msg(p.id, "Вы не отыграли минимум 20 минут за час (отыграно %s)" % dur_ru(p.hour_play))
		p.hour_play = 0.0

## Очистить текст чата: без управляющих символов и лишних пробелов, не длиннее CHAT_MAX
static func clean_chat(raw: String) -> String:
	var out := ""
	var sp := false
	for c0 in raw:
		var ch: String = c0
		var code := ch.unicode_at(0)
		if code < 32 or code == 127 or (code >= 0x200B and code <= 0x200F) or code == 0xFEFF:
			ch = " "
		if ch == " ":
			if sp or out == "":
				continue
			sp = true
		else:
			sp = false
		out += ch
	return out.strip_edges().left(CHAT_MAX).strip_edges()

## Сказать вслух: слышат все в игре ближе CHAT_R (и сам говорящий)
func _say(p: Player, raw: String) -> void:
	var t := clean_chat(raw)
	if t == "":
		return
	if p.chat_cd > 0.0:
		msg(p.id, "Не так быстро — сообщение не отправлено")
		return
	p.chat_cd = CHAT_GAP
	var line := "%s говорит: %s" % [tag(p), t]
	for q: Player in players:
		if q.connected and q.pos.distance_to(p.pos) <= CHAT_R:
			if not chat.has(q.id):
				chat[q.id] = []
			chat[q.id].append(line)

func pop_chat(pid: int) -> Array:
	var c: Array = chat.get(pid, [])
	chat.erase(pid)
	return c

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

## Игрок подключился: ключ аккаунта (uid) получает своего прежнего персонажа.
## static_id — постоянный ID из базы; если задан, карточка игрока живёт под этим номером
## Внешность по умолчанию: причёска и тон кожи зависят от ID (у всех разные, у одного игрока — всегда одинаковые)
static func default_look(pid: int, gender: String) -> Dictionary:
	var g := gender if Items.HEADS.has(gender) else "m"
	var h := absi(pid * 7 + 3)
	return {"g": g, "h": Items.HEADS[g][h % 4], "sk": absi(pid) % 4}

## Внешность из сохранения/сети с проверкой: мусор не ломает модель
static func look_from(o, pid: int) -> Dictionary:
	if not (o is Dictionary):
		return default_look(pid, "m")
	var g := str(o.get("g", "m"))
	if not Items.HEADS.has(g):
		g = "m"
	var lk := default_look(pid, g)
	if str(o.get("h", "")) in Items.HEADS[g]:
		lk["h"] = str(o["h"])
	lk["sk"] = clampi(int(o.get("sk", lk["sk"])), 0, 3)
	return lk

## Сменить пол персонажа (из базы): новая причёска, неподходящая одежда — в инвентарь
func set_gender(p: Player, gender: String) -> void:
	if not Items.HEADS.has(gender) or p.gender() == gender and not p.look.is_empty():
		return
	p.look = default_look(p.id, gender)
	for sl in p.wear.keys():
		if not Items.fits(p.wear[sl], gender):
			Items.add_to(p.inv, p.wear[sl], 1)
			p.wear.erase(sl)

func join_player(uid: String, pname: String, static_id: int = -1, gender: String = "", reg_date: String = "") -> Player:
	var pid := -1
	if static_id > 0:
		if uids.has(uid) and int(uids[uid]) != static_id:
			_rekey(int(uids[uid]), static_id)      # карточка, заведённая до постоянных ID, переезжает на свой номер
		else:
			var blocker := player(static_id)
			if blocker != null and _owner_of(static_id) != uid:
				_move_id(blocker, _free_id())       # номер занят чужой старой карточкой — отодвигаем её
		uids[uid] = static_id
		pid = static_id
	elif uids.has(uid):
		pid = int(uids[uid])
	else:
		pid = _free_id()       # без аккаунта (офлайн, тесты): номера от миллиона, чтобы не пересекаться с ID из базы
		uids[uid] = pid
	var p := player(pid)
	if p == null:
		p = _spawn_player(pid)
	p.connected = true
	p.remote = true
	p.name = pname
	if gender != "":
		set_gender(p, gender)
	if reg_date != "":
		p.reg = reg_date                       # из Supabase — главный источник
	elif p.reg == "":
		p.reg = today_str()                    # без аккаунта (тесты) или старая карточка — дата первого входа сюда
	p.idle = 0.0
	p.move = Vector2.ZERO
	p.force_seq += 1
	p.snaps.clear()
	return p

## Как игрок подписан везде в игре: John_Miller (5)
static func tag(p: Player) -> String:
	if p == null:
		return "?"
	return "%s (%d)" % [p.name if p.name != "" else "Игрок", p.id]

func _free_id() -> int:
	var free := 999999
	for q in players:
		free = maxi(free, q.id)
	return free + 1

func _owner_of(pid: int) -> String:
	for k in uids:
		if int(uids[k]) == pid:
			return str(k)
	return ""

## Перенести карточку игрока на другой номер. Если номер занят чужой старой карточкой — её отодвигаем на свободный
func _rekey(old_pid: int, new_pid: int) -> void:
	var blocker := player(new_pid)
	if blocker != null:
		_move_id(blocker, _free_id())
	var p := player(old_pid)
	if p != null:
		_move_id(p, new_pid)

func _move_id(p: Player, to: int) -> void:
	var from := p.id
	p.id = to
	for k in uids.keys():
		if int(uids[k]) == from:
			uids[k] = to
	if messages.has(from):
		messages[to] = messages[from]
		messages.erase(from)
	if chat.has(from):
		chat[to] = chat[from]
		chat.erase(from)

func _spawn_player(pid: int) -> Player:
	var p := Player.new(pid)
	p.pos = spawn_spot(1.5)
	p.rpos = p.pos
	p.inv = [{"id": "water", "n": 1}]
	p.wear = Items.START_WEAR.duplicate()
	p.look = default_look(pid, "m")
	p.money = START_MONEY
	p.reg = today_str()
	players.append(p)
	return p

func leave_player(pid: int) -> void:
	var p := player(pid)
	if p == null:
		return
	p.connected = false
	p.move = Vector2.ZERO
	p.ta_act = null
	sent_pub.erase(pid)

# ================== СИМУЛЯЦИЯ ==================
func update(dt: float) -> void:
	if is_replica or freeze:
		return
	while actions.size() > 0:
		var a: Array = actions.pop_front()
		var p := player(a[0])
		if p != null and not p.dead:
			_do_action(p, a[1])
	time = msk_time() if real_clock else time + dt * MINUTES_PER_SEC
	var today := floori(time / 1440.0)
	for p: Player in players:
		_account_time(p, dt, today)
	# PayDay — в начале каждого часа по МСК; после перезапуска сервера пропущенный час просто засчитывается заново
	var hr := floori(time / 60.0)
	if payday_hour < 0:
		payday_hour = hr
	elif hr != payday_hour:
		payday_hour = hr
		payday()
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
	if p.dead or p.cooldown > 0.0:
		return
	p.cooldown = p.weapon()["cd"]
	p.atk_kind = 0
	p.attack_anim = 1.0

## Снимок для плавной отрисовки (время отправителя, мс)
static func push_snap(e, ts: float, pos: Vector2, face: Vector2) -> void:
	var sn: Array = e.snaps
	if sn.size() > 0 and ts <= sn[sn.size() - 1][0]:
		return
	sn.append([ts, pos.x, pos.y, face.x, face.y])
	if sn.size() > 30:
		sn.pop_front()

## Положение на момент t (время отправителя): между двумя снимками, без забегания вперёд
static func sample_snaps(e, t: float) -> void:
	var sn: Array = e.snaps
	if sn.is_empty():
		e.rpos = e.pos
		e.rface = e.face
		return
	var last: Array = sn[sn.size() - 1]
	if t >= last[0]:
		e.rpos = Vector2(last[1], last[2])
		e.rface = Vector2(last[3], last[4])
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

## Перемещение игрока. _authoritative=false — предсказание на телефоне (сейчас поведение одинаковое)
func move_player(p: Player, dt: float, _authoritative: bool) -> Array:
	var mag := p.move.length()
	var ms := move_speed(p, mag)
	var speed: float = ms[0]
	var running: bool = ms[1]
	if mag > 0.1:
		var n := p.move / maxf(1.0, mag)
		p.face = p.move / mag
		p.pos = _move_circle(p.pos, n * speed * dt, PLAYER_R)
	return [running, mag]

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
	if p.remote:
		# позицию прислал телефон друга; бежит ли он — решаем по пройденному пути за полсекунды:
		# флагам «бегу/стою» из пакета не верим, иначе бег не тратит выносливость
		move_speed(p, p.move.length())          # только присед для анимации
		p.win_t += dt
		if p.win_t >= 0.5:
			var v := p.win_d / p.win_t
			p.net_running = v > 2.3 * 1.1
			p.net_mag = 1.0 if v > 0.3 else 0.0
			p.win_d = 0.0
			p.win_t = 0.0
		mag = p.net_mag
		running = p.net_running
	else:
		var r := move_player(p, dt, true)
		running = r[0]
		mag = r[1]
	if mag > 0.1:
		p.idle = 0.0
		if running:
			p.stamina = maxf(0.0, p.stamina - dt * 12.0)
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

## Ввод с телефона друга: позиция и взгляд. Всё проверяется — подделку хост откатывает
## Число из сетевого пакета: только int/float, иначе NAN — такой пакет отбрасывается целиком (BF-028)
static func net_num(o: Dictionary, k: String, def: float) -> float:
	var v = o.get(k, def)
	if not (v is float or v is int):
		return NAN
	return float(v)

func remote_input(p: Player, o: Dictionary) -> void:
	var mx := net_num(o, "mx", 0.0)
	var my := net_num(o, "my", 0.0)
	var nx := net_num(o, "x", p.pos.x)
	var ny := net_num(o, "y", p.pos.y)
	var fx := net_num(o, "fx", p.face.x)
	var fy := net_num(o, "fy", p.face.y)
	for v in [mx, my, nx, ny, fx, fy]:
		if not is_finite(v):
			return    # NaN, бесконечность, строка, null — пакет целиком не принимаем
	p.move = Vector2(mx, my).limit_length(1.0)
	p.run = o.get("run", false) == true
	if p.dead:
		return
	var now := Time.get_ticks_msec()
	var dt_in := 0.1 if p.last_in_ms == 0 else clampf((now - p.last_in_ms) / 1000.0, 0.0, 1.0)
	p.last_in_ms = now
	p.move_budget = minf(p.move_budget + dt_in * max_speed(p) * 1.25, 2.5)
	if int(o.get("fs", -1)) != p.force_seq:
		return    # друг ещё не получил наш принудительный сдвиг
	var np := Vector2(nx, ny)
	var fc := Vector2(fx, fy)
	if fc.length() > 0.01:
		p.face = fc.normalized()
	var d := np.distance_to(p.pos)
	if d > p.move_budget + 0.25 or world.circle_blocked(np.x, np.y, PLAYER_R - 0.05) or not _path_free(p.pos, np):
		push_player(p, p.pos)       # подделка или рассинхрон — вернуть друга туда, где он был
		return
	p.move_budget -= d
	p.win_d += d
	p.pos = np

## Самая большая скорость, которую персонаж может себе позволить сейчас (как move_speed с бегом):
## без выносливости — шаг, усталость и перегруз замедляют. По ней сервер даёт запас хода (С2)
func max_speed(p: Player) -> float:
	var sp := 3.9 if p.stamina > 1.0 else 2.3
	if p.weight() > p.max_weight():
		sp *= 0.6
	if p.stamina < 10.0:
		sp *= 0.8
	return sp

## Можно ли пройти от a до b, не проходя сквозь стены и закрытые двери.
## Телефон двигает игрока по осям (сначала X, потом Y, кадр за кадром), поэтому у угла дома его путь — «лесенка»,
## а не прямая. Принимаем прямую или одну из двух «ступенек» (сначала X или сначала Y). Каждый путь проверяется
## точками через 0.05 клетки — сквозь целую клетку стены или двери так не пройти (см. BF-024).
func _path_free(a: Vector2, b: Vector2) -> bool:
	if not (a.is_finite() and b.is_finite()):
		return false
	var r := PLAYER_R - 0.05
	if _segment_free(a, b, r):
		return true
	var ex := Vector2(b.x, a.y)
	if _segment_free(a, ex, r) and _segment_free(ex, b, r):
		return true
	var ey := Vector2(a.x, b.y)
	return _segment_free(a, ey, r) and _segment_free(ey, b, r)

func _segment_free(a: Vector2, b: Vector2, r: float) -> bool:
	var steps := ceili(a.distance_to(b) / 0.05)
	for i in range(1, steps + 1):
		var c := a.lerp(b, float(i) / steps)
		if world.circle_blocked(c.x, c.y, r):
			return false
	return true

func push_player(p: Player, to: Vector2) -> void:
	p.pos = to
	p.force_seq += 1

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
	msg(p.id, "Ты без сознания…")

func _respawn(p: Player) -> void:
	p.dead = false
	p.hp = 60.0
	p.hunger = minf(p.hunger, 50.0)
	p.thirst = minf(p.thirst, 50.0)
	push_player(p, spawn_spot(1.0))
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
## Случайное место рядом с точкой появления (в пределах spread), свободное и там же, где сама точка (на улице —
## значит на улице). Иначе случайная точка рядом со стеной дома «проваливалась» сквозь стену внутрь (BF-046)
func spawn_spot(spread: float) -> Vector2:
	var sb := building_at(spawn)
	for i in 24:
		var c := unstick(spawn + Vector2(randf_range(-spread, spread), randf_range(-spread, spread)), PLAYER_R)
		if not world.circle_blocked(c.x, c.y, PLAYER_R) and building_at(c) == sb:
			return c
	return unstick(spawn, PLAYER_R)

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
			return [1.2 if Items.def(a["id"])["slot"] in ["torso", "legs"] else 0.6, "Надеваю"]
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
			return a.get("c") is int or (a.get("c") is float and is_finite(a["c"]))
		"use", "drop", "wear":
			return a.get("id") is String and Items.DEFS.has(a["id"])
		"unwear":
			return a.get("slot") in Items.SLOTS
		"say":
			return a.get("text") is String and (a["text"] as String).length() <= CHAT_MAX * 4
	return false

func _do_action(p: Player, a: Dictionary) -> void:
	if not valid_action(a):
		return
	for k in ["c"]:
		if a.has(k):
			a[k] = int(a[k])
	p.idle = 0.0
	if a["a"] == "attack":
		p.ta_act = null
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
		"say": _say(p, a["text"])
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
	msg(q.id, "Тебя ударил %s" % tag(from))
	if q.hp <= 0.0:
		knock_out(q)
		msg(from.id, "%s без сознания" % tag(q))

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
	if not Items.fits(id, p.gender()):
		msg(p.id, "Это тебе не подойдёт")
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
			# взаимодействовать можно только с дверями
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
		"dead": p.dead, "rt": snappedf(p.respawn_t, 0.1), "eq": p.eq, "mo": p.money, "bk": p.bank,
		"inv": Items.copy(p.inv), "aa": snappedf(p.attack_anim, 0.01), "con": p.connected, "sn": p.sneaking,
		"tn": p.ta_name if p.ta_act != null else "", "tp": snappedf(p.ta_progress(), 0.01),
		"nm": p.name, "fs": p.force_seq, "wr": p.wear.duplicate(), "lk": p.look.duplicate(),
		"lv": p.level, "xp": p.exp, "ph": roundf(p.hour_play), "dy": p.day, "dp": roundf(p.day_play), "da": roundf(p.day_afk), "rg": p.reg}

## Что видят другие игроки: без инвентаря, денег и здоровья (это личное)
func player_public(p: Player) -> Dictionary:
	return {"id": p.id, "x": snappedf(p.pos.x, 0.01), "y": snappedf(p.pos.y, 0.01), "pub": true,
		"dead": p.dead, "eq": p.eq, "nm": p.name, "wr": p.wear.duplicate(), "lk": p.look.duplicate(), "fs": p.force_seq}

## Применить публичные данные чужого игрока, не трогая остальное
func player_from_public(o: Dictionary, p: Player) -> void:
	p.dead = bool(o.get("dead", false))
	p.eq = str(o.get("eq", ""))
	p.name = str(o.get("nm", ""))
	p.look = look_from(o.get("lk"), p.id)
	p.wear = wear_from(o.get("wr", {}))

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
	p.bank = int(o.get("bk", 0))
	p.eq = o.get("eq", "")
	p.inv.clear()
	for s in o.get("inv", []):
		p.inv.append({"id": s["id"], "n": int(s["n"])})
	p.attack_anim = o.get("aa", 0.0)
	p.connected = o.get("con", true)
	p.sneaking = o.get("sn", false)
	p.name = o.get("nm", "")
	p.look = look_from(o.get("lk"), p.id)
	p.wear = wear_from(o.get("wr", {}))
	p.force_seq = int(o.get("fs", 0))
	p.level = maxi(1, int(o.get("lv", 1)))
	p.exp = maxi(0, int(o.get("xp", 0)))
	p.hour_play = maxf(0.0, float(o.get("ph", 0.0)))
	p.day = int(o.get("dy", -1))
	p.day_play = maxf(0.0, float(o.get("dp", 0.0)))
	p.day_afk = maxf(0.0, float(o.get("da", 0.0)))
	p.reg = str(o.get("rg", ""))
	var tn: String = o.get("tn", "")
	if tn != "":
		p.ta_name = tn
		p.ta_dur = 1.0
		p.ta_time = o.get("tp", 0.0)
		if p.ta_act == null:
			p.ta_act = {"a": "remote"}
	else:
		p.ta_act = null

static func wear_from(wr) -> Dictionary:
	var out := {}
	if wr is Dictionary:
		for sl in wr:
			var wid := str(wr[sl])
			if sl in Items.SLOTS and Items.DEFS.has(wid) and Items.def(wid)["slot"] == sl:
				out[sl] = wid
	return out

func to_data() -> Dictionary:
	var ps := []
	for p: Player in players:
		ps.append(player_data(p))
	# карта берётся из файла; в сохранении клетки нужны только ради открытых и закрытых дверей
	return {"v": SAVE_VERSION, "seed": seed, "time": time, "uids": uids.duplicate(), "tiles": Marshalls.raw_to_base64(world.tiles),
		"w": world.w, "p": ps, "pdh": payday_hour}

## Здание, под крышей которого стоит точка, или -1 — улица. Так же решает телефон, чью крышу не рисовать
## (world_view.gd, inside_building): стена — снаружи, пол, дверь, окно, мебель — внутри
func building_at(pos: Vector2) -> int:
	if not pos.is_finite():
		return -1
	var x := floori(pos.x)
	var y := floori(pos.y)
	if not world.inside(x, y):
		return -1
	var b: int = world.building_of[world.idx(x, y)]
	return b if b >= 0 and world.t(x, y) != GameWorld.WALL else -1

## Сетка по районам (BF-049): подключённые игроки разложены по клеткам SEE_R×SEE_R — тому, кто в клетке k, видны
## только игроки из k и восьми соседних (дальше SEE_R всё равно не видно). Строит сервер перед рассылкой
## (index_players) и выключает после (grid_on = false): позиции между этим меняться не должны. Без сетки — перебор
## Запись сетки: [игрок, здание под ним (building_at), строка снимка st без здоровья] — считается раз за кадр,
## а не для каждого получателя заново
var grid := {}
var grid_on := false
var sig_cache := {}            # id → pub_sig на время сетки; чистится index_players(true) (сервер — раз в 0.2 с)

var vis_cache := {}            # pid → записи видимых в этом кадре рассылки (снимок и полные данные — один поиск)

func index_players(refresh_sigs := true) -> void:
	grid.clear()
	vis_cache.clear()
	if refresh_sigs:
		sig_cache.clear()
	for p: Player in players:
		if p.connected and p.pos.is_finite():
			var k := Vector2i(floori(p.pos.x / SEE_R), floori(p.pos.y / SEE_R))
			var e := [p, building_at(p.pos), _st_row(p, false)]
			if grid.has(k):
				grid[k].append(e)
			else:
				grid[k] = [e]
	grid_on = true

## Строка снимка st: id, x, y, взгляд, удар, крадётся, номер толчка, здоровье и выносливость (только себе)
func _st_row(p: Player, own: bool) -> PackedFloat32Array:
	return PackedFloat32Array([p.id, p.pos.x, p.pos.y, p.face.x, p.face.y, float(p.atk_seq * 2 + p.atk_kind),
		1.0 if p.sneaking else 0.0, p.force_seq, p.hp if own else 0.0, p.stamina if own else 0.0])

## Записи сетки тех, кого видит pid (без него самого); то же правило, что sees(): ближе SEE_R и не под чужой крышей
func _visible_entries(pid: int, c: Vector2, cb: int) -> Array:
	if vis_cache.has(pid):
		return vis_cache[pid]
	var out := []
	var k := Vector2i(floori(c.x / SEE_R), floori(c.y / SEE_R))
	var r2 := SEE_R * SEE_R
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for e in grid.get(k + Vector2i(dx, dy), []):
				var p: Player = e[0]
				if p.id != pid and p.pos.distance_squared_to(c) <= r2 and (e[1] < 0 or e[1] == cb):
					out.append(e)
	vis_cache[pid] = out
	return out

## Другие игроки (без него самого), которых видит pid — по сетке, если она построена, иначе перебором
func visible_to(pid: int) -> Array:
	var me := player(pid)
	var c: Vector2 = me.pos if me != null else spawn
	var cb := building_at(c)
	var out := []
	if grid_on and c.is_finite():
		for e in _visible_entries(pid, c, cb):
			out.append(e[0])
	else:
		for p: Player in players:
			if p.id != pid and p.connected and sees(c, cb, p):
				out.append(p)
	return out

## Подпись внешности: при сетке — одна на кадр рассылки (кэш), без сетки — заново
func sig_of(p: Player) -> int:
	if not grid_on:
		return pub_sig(p)
	if not sig_cache.has(p.id):
		sig_cache[p.id] = pub_sig(p)
	return sig_cache[p.id]

## Что из внешности другого игрока надо знать телефону: подпись меняется, только когда меняется что-то из этого
## (не позиция — она идёт снимками). По ней сервер решает, слать ли player_public снова (BF-050)
func pub_sig(p: Player) -> int:
	return hash([p.dead, p.eq, p.name, p.wear, p.look])

## Кому что уже отправлено: получатель → {id игрока → подпись}. Сбрасывается при входе получателя (forget_sent)
var sent_pub := {}

func forget_sent(pid: int) -> void:
	sent_pub.erase(pid)

## Видит ли тот, кто стоит в c (в здании cb), игрока p: рядом (экран с запасом) и не под чужой крышей.
## Остальных телефон не получает вовсе — подсмотреть их положение нельзя (аудит, В3)
func sees(c: Vector2, cb: int, p: Player) -> bool:
	if p.pos.distance_squared_to(c) > SEE_R * SEE_R:
		return false
	var pb := building_at(p.pos)
	return pb < 0 or pb == cb

## Мир для нового клиента: карта, время; из игроков — он сам полностью, остальные только внешне.
## Карту аккаунтов (uids) не отдаём никогда: uid — это ключ от чужого персонажа
## with_map = false — без карты: сервер шлёт её отдельно, сжатой и из кэша (pack_map, BF-051)
func to_data_for(pid: int, with_map := true) -> Dictionary:
	var me := player(pid)
	var ps := []
	if me != null:
		ps.append(player_data(me))
	var known := {}
	for p: Player in visible_to(pid):
		var pub := player_public(p)
		pub["con"] = true
		ps.append(pub)
		known[p.id] = sig_of(p)
	sent_pub[pid] = known               # вход: телефон знает ровно тех, кто в этом пакете
	var o := {"v": SAVE_VERSION, "seed": seed, "time": time, "p": ps}
	if with_map:
		o["map"] = world.map_data()
	return o

## Карта для отправки: var_to_bytes + zstd. Возвращает [сжатые байты, размер до сжатия]
static func pack_map(md: Dictionary) -> Array:
	var raw := var_to_bytes(md)
	return [raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size()]

## Обратно; null — данные испорчены или размер вне разумного (карта 400×400 с объектами — меньше 1 МБ)
static func unpack_map(z: PackedByteArray, n: int):
	if z.is_empty() or n <= 0 or n > 16 * 1024 * 1024:
		return null
	var raw := z.decompress(n, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != n:
		return null
	var d = bytes_to_var(raw)
	return d if d is Dictionary else null

const SAVE_VERSION := 3

## Проверка формата: сохранение мира — словарь с клетками (по ним восстанавливаются двери)
static func valid_save(o) -> bool:
	return o is Dictionary and o.get("tiles") is String

## Текст сохранения, который точно читается обратно; "" — записывать нельзя, данные испорчены (BF-028).
## Так сервер и телефон не затирают рабочий файл и резервную копию нечитаемым.
static func save_text(o: Dictionary) -> String:
	var text := JSON.stringify(o)
	var back = JSON.parse_string(text)
	return text if valid_save(back) else ""

## Перевод старых сохранений на текущий формат. Новое поле — новая версия и шаг здесь
static func migrate(o: Dictionary) -> Dictionary:
	if not o.has("uids"):
		o["uids"] = {}
	if int(o.get("v", 1)) < 2 and o.get("p") is Array:
		# v2: одежда стала моделями Quaternius — старые вещи (кепки, рюкзаки, куртки) убраны.
		# Кто ходил в одних джинсах, получает футболку и кеды; неизвестные вещи из инвентаря исчезают.
		for pd in o["p"]:
			if not (pd is Dictionary) or pd.get("pub", false):
				continue
			var wr := wear_from(pd.get("wr", {}))
			for sl in Items.START_WEAR:
				if not wr.has(sl):
					wr[sl] = Items.START_WEAR[sl]
			pd["wr"] = wr
			var inv := []
			for st in pd.get("inv", []):
				if st is Dictionary and Items.DEFS.has(str(st.get("id", ""))):
					inv.append(st)
			pd["inv"] = inv
	if int(o.get("v", 1)) < 3 and o.get("tiles") is String:
		# v3: разбитых окон и выбитых дверей больше нет (механики Zomboid убраны) — окно снова целое, дверь открыта.
		# Прочность клеток («thp») и содержимое мебели («cont») больше не читаются.
		var t := Marshalls.base64_to_raw(o["tiles"])
		for i in t.size():
			if t[i] == GameWorld.OLD_WINDOW_BROKEN:
				t[i] = GameWorld.WINDOW
			elif t[i] == GameWorld.OLD_DOOR_BROKEN:
				t[i] = GameWorld.DOOR_OPEN
		o["tiles"] = Marshalls.raw_to_base64(t)
	o["v"] = SAVE_VERSION
	return o

func load_data(o: Dictionary) -> void:
	o = migrate(o)
	time = float(o.get("time", 8 * 60.0))
	payday_hour = int(o.get("pdh", -1))
	uids = o.get("uids", {}).duplicate() if o.get("uids") is Dictionary else {}
	if o.get("map") is Dictionary:
		# клиент: карту со всеми дверями прислал сервер
		var err := world.load_map(o["map"])
		if err != "":
			push_error("Карта от сервера не загрузилась: " + err)
		spawn = world.spawn
	else:
		# сервер и офлайн: карта — из файла игры, из сохранения — только какие двери открыты
		load_official_map()
		var t := Marshalls.base64_to_raw(str(o.get("tiles", "")))
		if t.size() == world.tiles.size() and int(o.get("w", 100)) == world.w:
			for i in t.size():
				if GameWorld.is_door_like(world.tiles[i]) and GameWorld.is_door_like(t[i]):
					world.tiles[i] = t[i]
	players.clear()
	for e in o.get("p", []):
		var p := Player.new(int(e["id"]))
		player_from(e, p)
		if not p.pos.is_finite():
			p.pos = unstick(spawn, PLAYER_R)      # испорченная позиция — к точке появления
		if not is_replica and not p.dead and world.circle_blocked(p.pos.x, p.pos.y, PLAYER_R):
			# карту поменяли, и на месте игрока теперь стена или объект — ставим рядом или к точке появления
			var np := unstick(p.pos, PLAYER_R)
			p.pos = np if not world.circle_blocked(np.x, np.y, PLAYER_R) else unstick(spawn, PLAYER_R)
		p.rpos = p.pos
		players.append(p)

# ================== СЕТЕВЫЕ СНИМКИ ==================
## Частый лёгкий снимок (ненадёжный канал): позиции рядом с другом
func state_for(pid: int) -> Dictionary:
	var me := player(pid)
	var c: Vector2 = me.pos if me != null else spawn
	var ps := PackedFloat32Array()
	if me != null and me.connected:
		ps.append_array(_st_row(me, true))
	# только те, кого видно: при сотнях игроков пакет не растёт, а чужие дома не просматриваются
	if grid_on and c.is_finite():
		for e in _visible_entries(pid, c, building_at(c)):
			ps.append_array(e[2])
	else:
		for p: Player in visible_to(pid):
			ps.append_array(_st_row(p, false))
	var o := {"t": "st", "time": time, "ts": Time.get_ticks_msec(), "p": ps}
	# выстрелы — только те, что рядом (начало или конец в радиусе видимости)
	var sh := []
	for s in shots:
		if (absf(s[0] - c.x) <= VIEW_R and absf(s[1] - c.y) <= VIEW_R) or (absf(s[2] - c.x) <= VIEW_R and absf(s[3] - c.y) <= VIEW_R):
			sh.append(s.duplicate())
	if sh.size() > 0:
		o["sh"] = sh
	return o

## Редкий надёжный снимок: изменения мира, полные данные игроков, сообщения, эффекты
func events_for(pid: int, full_players: bool, all_pub := false) -> Dictionary:
	var o := {"t": "ev"}
	if full_players:
		var me := player(pid)
		var ps := []
		if me != null:
			ps.append(player_data(me))             # себе — всё
		# другим — только внешность, и только если телефон её ещё не знает (BF-050); all_pub — всем (тесты)
		var known: Dictionary = sent_pub.get(pid, {})
		for p: Player in visible_to(pid):
			var sig := sig_of(p)
			if all_pub or int(known.get(p.id, 0)) != sig or not known.has(p.id):
				ps.append(player_public(p))
				known[p.id] = sig
		sent_pub[pid] = known
		o["p"] = ps
	# общие списки здесь НЕ очищаются: функцию вызывают для каждого игрока по очереди, а очищает их
	# сервер после рассылки всем (BF-027). Эффекты — только тем, кто рядом
	var cme := player(pid)
	var cc: Vector2 = cme.pos if cme != null else spawn
	var fxs := []
	for f in fx_net:
		if absf(f[1] - cc.x) <= VIEW_R and absf(f[2] - cc.y) <= VIEW_R:
			fxs.append(f.duplicate())
	if fxs.size() > 0:
		o["fx"] = fxs
	if world.dirty_tiles.size() > 0:
		var a := []
		for i in world.dirty_tiles:
			a.append([i, world.t_at(i)])
		o["tc"] = a
	var m := pop_messages(pid)
	if m.size() > 0:
		o["m"] = m
	var ch := pop_chat(pid)
	if ch.size() > 0:
		o["c"] = ch
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
	while i + 9 < ps.size():
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
			p.hp = ps[i + 8]
			p.stamina = ps[i + 9]
		var fs := int(ps[i + 7])
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
			push_snap(p, ts, p.pos, p.face)
		elif fs != p.force_seq:
			# хост сдвинул нас сам (дверь, откат)
			p.force_seq = fs
			p.pos = Vector2(ps[i + 1], ps[i + 2])
			p.face = Vector2(ps[i + 3], ps[i + 4])
			p.rpos = p.pos
		i += 10
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
		var keep_fs := p.force_seq
		var keep_aa := p.attack_anim
		var keep_sn := p.sneaking
		player_from(e, p)
		# движение и удары приходят быстрым каналом: надёжный пакет старше и не должен их откатывать
		p.attack_anim = keep_aa
		if not fresh and not (pid == local_pid and int(e.get("fs", 0)) != keep_fs):
			p.pos = keep_pos
			p.face = keep_face
			p.force_seq = keep_fs
			p.sneaking = keep_sn
	for e in o.get("tc", []):
		var i := int(e[0])
		var nt := int(e[1])
		if world.t_at(i) != nt:
			world.events.append([i, world.t_at(i), nt])
			world.tiles[i] = nt
		world.vis_dirty[i] = true
	for e in o.get("fx", []):
		fx.append(e)

