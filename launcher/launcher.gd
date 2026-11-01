extends Control
## Лаунчер: первая сцена APK. Берёт манифест последней сборки с GitHub Releases (HTTPS),
## докачивает изменившиеся пакеты игры, проверяет их SHA-256, подключает и запускает игру.
##
## ВАЖНО: этот файл обновляется только вместе с APK. Он НЕ должен использовать классы игры
## (Boot, Version, Net и т.д.) — они остались бы в памяти старыми после подключения пакета.
## Данные в игру — только через Engine.set_meta.

const APK_CODE := 1                       # подставляет CI; сравнивается с min_apk из манифеста
const UPDATE_URL := "https://github.com/C0BecTb11/Umwelt-RP/releases/download/latest/"
const PCK_DIR := "user://pck/"
const STATE := "user://pck/state.json"    # что уже скачано и проверено: имя → sha256

var status: Label
var detail: Label
var bar: ProgressBar
var play_btn: Button
var retry_btn: Button
var apk_btn: Button
var news: Label

var manifest := {}
var local := {}
var http: HTTPRequest
var queue: Array = []
var cur := {}
var total_bytes := 0
var done_bytes := 0
var ready_to_play := false
var offline := false

func _ready() -> void:
	_build_ui()
	DirAccess.make_dir_recursive_absolute(PCK_DIR)
	var t = JSON.parse_string(FileAccess.get_file_as_string(STATE)) if FileAccess.file_exists(STATE) else null
	local = t if t is Dictionary else {}
	http = HTTPRequest.new()
	http.timeout = 30.0
	http.max_redirects = 8          # файлы релизов GitHub отдаёт через перенаправление
	add_child(http)
	# сервер, автотесты и снимки — сразу в игру, без обновлений
	for a in OS.get_cmdline_user_args():
		if a in ["--no-update", "--server", "--audit"] or a.begins_with("--demo=") or a.begins_with("--nettest="):
			get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
			return
	_check()

# ---------- интерфейс ----------
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(420, 0)
	center.add_child(col)
	col.add_child(_lbl("UMWELT RP", 40, Color(0.98, 0.45, 0.62)))
	col.add_child(_lbl("Америка, девяностые", 16, Color(0.45, 0.85, 0.85)))
	news = _lbl("", 13, Color(0.75, 0.75, 0.75))
	news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(news)
	status = _lbl("Проверяю обновления…", 16, Color.WHITE)
	col.add_child(status)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(420, 18)
	bar.show_percentage = false
	col.add_child(bar)
	detail = _lbl("", 12, Color(0.55, 0.55, 0.55))
	col.add_child(detail)
	play_btn = _btn("Играть", Color(0.18, 0.42, 0.23), _launch)
	play_btn.disabled = true
	col.add_child(play_btn)
	retry_btn = _btn("Повторить", Color(0.3, 0.3, 0.34), _check)
	retry_btn.visible = false
	col.add_child(retry_btn)
	apk_btn = _btn("Скачать новую версию приложения", Color(0.55, 0.38, 0.12), func(): OS.shell_open(str(manifest.get("apk_url", UPDATE_URL + "umwelt.apk"))))
	apk_btn.visible = false
	col.add_child(apk_btn)

func _lbl(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l

func _btn(t: String, c: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(320, 48)
	b.add_theme_font_size_override("font_size", 17)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = c.darkened(0.5) if st == "disabled" else (c.lightened(0.12) if st == "pressed" else c)
		s.set_corner_radius_all(12)
		b.add_theme_stylebox_override(st, s)
	b.pressed.connect(cb)
	return b

func _fail(msg: String) -> void:
	status.text = msg
	retry_btn.visible = true
	# уже скачанная и проверенная версия есть — можно играть с ней
	if not local.is_empty():
		offline = true
		play_btn.disabled = false
		detail.text = "Можно играть с уже скачанной версией"

# ---------- проверка обновлений ----------
func _fetch(url: String) -> PackedByteArray:
	var err := http.request(url + "?t=%d" % Time.get_unix_time_from_system())   # без кэша
	if err != OK:
		return PackedByteArray()
	var r: Array = await http.request_completed
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return PackedByteArray()
	return r[3]

func _check() -> void:
	retry_btn.visible = false
	apk_btn.visible = false
	status.text = "Проверяю обновления…"
	bar.value = 0
	var body := await _fetch(UPDATE_URL + "manifest.json")
	if body.is_empty():
		_fail("Сервер обновлений недоступен")
		return
	var m = JSON.parse_string(body.get_string_from_utf8())
	if not (m is Dictionary) or not (m.get("files") is Array):
		_fail("Неверный формат обновления")
		return
	manifest = m
	news.text = str(manifest.get("news", ""))
	if APK_CODE < int(manifest.get("min_apk", 0)):
		status.text = "Нужна новая версия приложения"
		detail.text = "Скачай и установи её поверх этой — персонаж сохранится"
		apk_btn.visible = true
		return
	queue.clear()
	total_bytes = 0
	done_bytes = 0
	for f in manifest["files"]:
		var name := str(f.get("name", ""))
		if not name.is_valid_filename() or not name.ends_with(".pck"):
			continue
		if local.get(name, "") == str(f.get("sha256", "")) and FileAccess.file_exists(PCK_DIR + name):
			continue
		queue.append(f)
		total_bytes += int(f.get("size", 0))
	_next()

func _next() -> void:
	if queue.is_empty():
		_save_state()
		status.text = "Готово — версия %s" % str(manifest.get("build", "?"))
		bar.value = 100
		detail.text = ""
		play_btn.disabled = false
		ready_to_play = true
		return
	cur = queue.pop_front()
	var name := str(cur["name"])
	status.text = "Загружаю обновление…"
	http.download_file = PCK_DIR + name + ".part"
	var err := http.request(UPDATE_URL + name)
	if err != OK:
		_fail("Не удалось начать загрузку")
		return
	var r: Array = await http.request_completed
	http.download_file = ""
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		_fail("Загрузка прервалась — проверь интернет")
		return
	var part := PCK_DIR + name + ".part"
	if _sha256(part) != str(cur.get("sha256", "")):
		DirAccess.remove_absolute(part)
		_fail("Файл скачался с ошибкой — попробуй ещё раз")
		return
	var dst := PCK_DIR + name
	if FileAccess.file_exists(dst):
		DirAccess.remove_absolute(dst)
	DirAccess.rename_absolute(part, dst)
	local[name] = str(cur["sha256"])
	_save_state()
	done_bytes += int(cur.get("size", 0))
	_next()

func _process(_dt: float) -> void:
	if http != null and http.download_file != "" and total_bytes > 0:
		var got := done_bytes + http.get_downloaded_bytes()
		bar.value = 100.0 * got / total_bytes
		detail.text = "%.1f из %.1f МБ" % [got / 1048576.0, total_bytes / 1048576.0]

func _sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		hc.update(f.get_buffer(1 << 20))
	return hc.finish().hex_encode()

func _save_state() -> void:
	var f := FileAccess.open(STATE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(local))

# ---------- запуск ----------
func _launch() -> void:
	var files: Array = manifest.get("files", []) if not offline else []
	if offline or files.is_empty():
		for n in local:
			files.append({"name": n})
	for f in files:
		var p := PCK_DIR + str(f["name"])
		if FileAccess.file_exists(p) and local.has(str(f["name"])):
			if not ProjectSettings.load_resource_pack(p, true):
				status.text = "Пакет игры повреждён — удаляю, перезапусти"
				local.erase(str(f["name"]))
				_save_state()
				return
	var srv: Dictionary = manifest.get("server", {}) if manifest.get("server") is Dictionary else {}
	if srv.has("host"):
		Engine.set_meta("server_host", str(srv["host"]))
	if srv.has("port"):
		Engine.set_meta("server_port", int(srv["port"]))
	get_tree().change_scene_to_file("res://scenes/main.tscn")
