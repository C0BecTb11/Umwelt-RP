extends RefCounted
## Журнал действий игроков для лог-чекера администратора (с 0.55). Только сервер (scripts/server_only — в APK нет).
## Файлы: user://actlog/ГГГГ-ММ-ДД.jsonl — по суткам МСК, одна строка — одно событие (JSON). Текущие сутки — обычный
## файл (дописывается), прошлые — сжатые .jsonl.gz. Старше KEEP_DAYS — удаляются.
## Категории — CATS; новая система (деньги, SMS, имущество) = новая категория + запись game.glog(...) в её коде.

const DIR := "user://actlog"            # не user://logs — там журналы самого Godot
const KEEP_DAYS := 90              # три месяца (решение владельца 2026-11-08)
const MAX_RANGE_DAYS := 31         # за один запрос — не больше месяца (чтобы не грузить сервер)
const MAX_LIMIT := 300
const MSK := 3 * 3600
## Категории: код → название в лог-чекере. «soon» — систем ещё нет, вкладка видна, но пуста
const CATS := {
	"conn": "Входы и выходы", "chat": "Чат", "payday": "PayDay", "fight": "Драки", "item": "Предметы",
	"acc": "Аккаунты", "admin": "Лог-чекер",
	"money": "Передача денег", "sms": "SMS", "property": "Имущество"}
const SOON := ["money", "sms", "property"]

var day := ""                      # сутки открытого файла
var f: FileAccess
var flush_t := 0.0

static func day_of(unix: float) -> String:
	return Time.get_date_string_from_unix_time(int(unix) + MSK)

static func path_plain(d: String) -> String:
	return "%s/%s.jsonl" % [DIR, d]

static func path_gz(d: String) -> String:
	return "%s/%s.jsonl.gz" % [DIR, d]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	housekeeping(Time.get_unix_time_from_system())

## Записать события (с сервера каждый кадр). Возвращает, сколько записано
func write(events: Array, now: float) -> int:
	if events.is_empty():
		return 0
	var d := day_of(now)
	if d != day or f == null:
		_open(d, now)
	if f == null:
		return 0
	for e in events:
		f.store_line(JSON.stringify(e))
	return events.size()

## Сбросить на диск (раз в секунду и при остановке)
func tick(dt: float) -> void:
	flush_t -= dt
	if flush_t <= 0.0 and f != null:
		flush_t = 1.0
		f.flush()

func close() -> void:
	if f != null:
		f.flush()
		f.close()
		f = null

func _open(d: String, now: float) -> void:
	close()
	var changed := day != "" and day != d
	day = d
	var p := path_plain(d)
	f = FileAccess.open(p, FileAccess.READ_WRITE) if FileAccess.file_exists(p) else FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.seek_end()
	if changed:
		housekeeping(now)             # сутки сменились: вчерашний файл — сжать, старые — удалить

## Сжать прошлые сутки, удалить старше KEEP_DAYS
static func housekeeping(now: float) -> void:
	var today := day_of(now)
	var oldest := day_of(now - KEEP_DAYS * 86400.0)
	var da := DirAccess.open(DIR)
	if da == null:
		return
	for fn in da.get_files():
		var d := fn.get_slice(".", 0)
		if d.length() != 10:
			continue
		if d < oldest:
			da.remove(fn)
		elif fn.ends_with(".jsonl") and d < today:
			var text := read_day(d)             # если сжатый уже есть (сжатие прерывалось) — вместе с ним
			var tmp := path_gz(d) + ".tmp"
			var z := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
			if z == null:
				continue
			z.store_string(text)
			z.close()
			var chk := FileAccess.open_compressed(tmp, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
			var ok := chk != null and chk.get_as_text().length() == text.length()
			if chk != null:
				chk.close()
			if ok:
				da.rename(tmp.get_file(), path_gz(d).get_file())
				da.remove(fn)
			else:
				da.remove(tmp.get_file())

## Текст суток (сжатый или обычный); "" — нет
static func read_day(d: String) -> String:
	if FileAccess.file_exists(path_gz(d)):
		var z := FileAccess.open_compressed(path_gz(d), FileAccess.READ, FileAccess.COMPRESSION_GZIP)
		if z != null:
			var t := z.get_as_text()
			z.close()
			if FileAccess.file_exists(path_plain(d)):
				t += FileAccess.get_file_as_string(path_plain(d))   # сжатие прервалось — остаток в обычном
			return t
	if FileAccess.file_exists(path_plain(d)):
		return FileAccess.get_file_as_string(path_plain(d))
	return ""

## Поиск (идёт в отдельном потоке). q: cats (Array кодов, пусто — все), from, to («ГГГГ-ММ-ДД» МСК),
## player (id или часть имени), text (часть текста, без учёта регистра), before (мс: только старше), limit.
## Новые первыми. Возвращает {"items": [...], "more": bool, "days": n}
static func query(q: Dictionary) -> Dictionary:
	var cats: Array = q.get("cats", [])
	var to_u := Time.get_unix_time_from_datetime_string(str(q.get("to", "")) + "T00:00:00")
	var from_u := Time.get_unix_time_from_datetime_string(str(q.get("from", "")) + "T00:00:00")
	if to_u <= 0 or from_u <= 0 or from_u > to_u:
		return {"error": "Неверные даты"}
	if (to_u - from_u) / 86400 + 1 > MAX_RANGE_DAYS:
		return {"error": "Не больше %d дней за раз" % MAX_RANGE_DAYS}
	var pl := str(q.get("player", "")).strip_edges().to_lower()
	var pid := int(pl) if pl.is_valid_int() else -1
	var txt := str(q.get("text", "")).strip_edges().to_lower()
	var before := int(q.get("before", 0))
	var limit := clampi(int(q.get("limit", 100)), 1, MAX_LIMIT)
	var out := []
	var more := false
	var u := to_u
	var days := 0
	while u >= from_u and not more:
		var d := Time.get_date_string_from_unix_time(u)
		days += 1
		var lines := read_day(d).split("\n", false)
		for i in range(lines.size() - 1, -1, -1):
			var line: String = lines[i]
			if txt != "" and not line.to_lower().contains(txt):
				continue
			var e = JSON.parse_string(line)
			if not (e is Dictionary):
				continue                      # недописанная строка (сервер пишет прямо сейчас)
			if before > 0 and int(e.get("t", 0)) >= before:
				continue
			if not cats.is_empty() and not cats.has(str(e.get("c", ""))):
				continue
			if pl != "":
				var hit := false
				if pid >= 0:
					hit = int(e.get("p", -1)) == pid or int(e.get("v", -1)) == pid
				else:
					hit = str(e.get("n", "")).to_lower().contains(pl) or str(e.get("vn", "")).to_lower().contains(pl)
				if not hit:
					continue
			if out.size() >= limit:
				more = true
				break
			out.append(e)
		u -= 86400
	return {"items": out, "more": more, "days": days}

## Сколько места занимает журнал (байт) и за сколько суток
static func usage() -> Array:
	var da := DirAccess.open(DIR)
	if da == null:
		return [0, 0]
	var n := 0
	var sz := 0
	for fn in da.get_files():
		if fn.begins_with("20"):
			n += 1
			var fa := FileAccess.open("%s/%s" % [DIR, fn], FileAccess.READ)
			if fa != null:
				sz += fa.get_length()
				fa.close()
	return [sz, n]
