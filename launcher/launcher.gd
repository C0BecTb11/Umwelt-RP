extends Control
## Лаунчер — стартовый экран игры (первая сцена APK). На экране только название, версия и две кнопки.
## В фоне: берёт манифест последней сборки с GitHub Releases (HTTPS), проверяет его подпись (BF-039),
## докачивает изменившиеся пакеты, проверяет SHA-256, подключает их и запускает игру в выбранном режиме.
##
## ВАЖНО: этот файл обновляется только вместе с APK. Он НЕ должен использовать классы игры
## (Boot, Version, Net и т.д.) — они остались бы в памяти старыми после подключения пакета.
## Данные в игру — только через Engine.set_meta.

const APK_CODE := 1                       # подставляет CI; сравнивается с min_apk из манифеста
const UPDATE_URL := "https://github.com/C0BecTb11/Umwelt-RP/releases/download/latest/"
const PCK_DIR := "user://pck/"
const STATE := "user://pck/state.json"    # что скачано и проверено: имя файла → sha256, "build" → номер
## Открытый ключ подписи обновлений (PEM в base64). Подставляет CI из ключа подписи APK; закрытый ключ есть только
## в секретах GitHub. Манифест без верной подписи не используется: ни пакеты, ни адрес сервера, ни ссылка на APK
const UPDATE_KEY_B64 := "@UPDATE_PUBLIC_KEY@"

var ver_label: Label
var status: Label
var bar: ProgressBar
var play_btn: Button
var solo_btn: Button
var apk_btn: Button

var manifest := {}
var local := {}
var http: HTTPRequest
var queue: Array = []
var cur := {}
var total_bytes := 0
var done_bytes := 0
var busy := true
var bad_sig := false

func _ready() -> void:
	_build_ui()
	DirAccess.make_dir_recursive_absolute(PCK_DIR)
	var t = JSON.parse_string(FileAccess.get_file_as_string(STATE)) if FileAccess.file_exists(STATE) else null
	local = t if t is Dictionary else {}
	# новое приложение уже содержит игру новее скачанного пакета — старый пакет не подключаем
	if int(str(local.get("build", "0"))) < APK_CODE:
		for n in local.keys():
			if str(n).ends_with(".pck"):
				DirAccess.remove_absolute(PCK_DIR + str(n))
		local = {}
	http = HTTPRequest.new()
	http.timeout = 30.0
	http.max_redirects = 8          # файлы релизов GitHub отдаёт через перенаправление
	add_child(http)
	# сервер, автотесты и снимки — сразу в игру, без обновлений
	for a in OS.get_cmdline_user_args():
		if a in ["--no-update", "--server", "--audit"] or a.begins_with("--demo=") or a.begins_with("--nettest="):
			get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
			return
	_show_version()
	if Engine.has_meta("pack_build"):
		# вернулись из игры: пакеты уже в памяти, новое обновление встанет только после перезапуска
		_set_busy(false)
		_check_only()
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
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(360, 0)
	center.add_child(col)
	col.add_child(_lbl("UMWELT RP", 44, Color(0.98, 0.45, 0.62)))
	col.add_child(_gap(10))
	play_btn = _btn("Играть", Color(0.18, 0.42, 0.23), _launch.bind("server"))
	col.add_child(play_btn)
	solo_btn = _btn("Офлайн-тест", Color(0.23, 0.29, 0.35), _launch.bind("solo"))
	col.add_child(solo_btn)
	apk_btn = _btn("Скачать новую версию", Color(0.55, 0.38, 0.12), func(): OS.shell_open(str(manifest.get("apk_url", UPDATE_URL + "umwelt.apk"))))
	apk_btn.visible = false
	col.add_child(apk_btn)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(360, 8)
	bar.show_percentage = false
	bar.visible = false
	col.add_child(bar)
	status = _lbl("", 13, Color(0.95, 0.8, 0.45))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	# версия — в углу, мелко
	ver_label = Label.new()
	ver_label.add_theme_font_size_override("font_size", 12)
	ver_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	ver_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver_label.position -= Vector2(16, 12)
	add_child(ver_label)

func _lbl(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _btn(t: String, c: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(360, 52)
	b.add_theme_font_size_override("font_size", 18)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = c.darkened(0.55) if st == "disabled" else (c.lightened(0.12) if st == "pressed" else c)
		s.set_corner_radius_all(12)
		b.add_theme_stylebox_override(st, s)
	b.pressed.connect(cb)
	return b

func _set_busy(v: bool) -> void:
	busy = v
	play_btn.disabled = v
	solo_btn.disabled = v

## Версия игры, которая запустится: скачанная сборка или встроенная в APK
func _show_version() -> void:
	var b := str(local.get("build", APK_CODE))
	ver_label.text = "версия 0.%s" % b

# ---------- проверка обновлений ----------
func _fetch(url: String) -> PackedByteArray:
	var err := http.request(url + "?t=%d" % Time.get_unix_time_from_system())   # без кэша
	if err != OK:
		return PackedByteArray()
	var r: Array = await http.request_completed
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return PackedByteArray()
	return r[3]

func _load_manifest() -> bool:
	bad_sig = false
	var body := await _fetch(UPDATE_URL + "manifest.json")
	if body.is_empty():
		return false
	var sig := await _fetch(UPDATE_URL + "manifest.sig")
	if not signature_ok(body, sig.get_string_from_utf8(), UPDATE_KEY_B64):
		bad_sig = true
		return false
	var m = JSON.parse_string(body.get_string_from_utf8())
	if not (m is Dictionary) or not (m.get("files") is Array):
		return false
	manifest = m
	return true

## Подпись манифеста: RSA, SHA-256 (как `openssl dgst -sha256 -sign`). Ключ-заглушка — сборка не из CI, без проверки
static func signature_ok(body: PackedByteArray, sig_b64: String, key_b64: String) -> bool:
	if key_b64.begins_with("@"):
		return true
	var key := CryptoKey.new()
	if key.load_from_string(Marshalls.base64_to_utf8(key_b64), true) != OK:
		return false
	var sig := Marshalls.base64_to_raw(sig_b64.strip_edges())
	if sig.is_empty():
		return false
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(body)
	return Crypto.new().verify(HashingContext.HASH_SHA256, h.finish(), sig, key)

func _check() -> void:
	_set_busy(true)
	status.text = ""
	if not await _load_manifest():
		# нет интернета, GitHub недоступен или подпись не сошлась — играем тем, что есть
		status.text = "Обновление не прошло проверку подлинности — запускаю версию, что уже есть" if bad_sig else "Не удалось проверить обновления"
		_set_busy(false)
		return
	if APK_CODE < int(manifest.get("min_apk", 0)):
		status.text = "Вышла новая версия приложения — установи её поверх этой, персонаж сохранится"
		apk_btn.visible = true
		play_btn.disabled = true          # со старым приложением сервер всё равно не пустит
		solo_btn.disabled = false
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
	if not queue.is_empty():
		bar.visible = true
	_next()

## Вернулись из игры: только узнать, не вышло ли что-то новее запущенного
func _check_only() -> void:
	if not await _load_manifest():
		return
	if str(manifest.get("build", "")) != str(Engine.get_meta("pack_build", "")):
		status.text = "Вышло обновление 0.%s — закрой и открой игру, чтобы установить" % str(manifest["build"])

func _next() -> void:
	if queue.is_empty():
		bar.visible = false
		local["build"] = str(manifest.get("build", local.get("build", "")))
		_save_state()
		_show_version()
		status.text = ""
		_set_busy(false)
		return
	cur = queue.pop_front()
	var name := str(cur["name"])
	status.text = "Загружаю обновление 0.%s…" % str(manifest.get("build", "?"))
	http.download_file = PCK_DIR + name + ".part"
	var err := http.request(UPDATE_URL + name)
	if err != OK:
		_fail_download()
		return
	var r: Array = await http.request_completed
	http.download_file = ""
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		_fail_download()
		return
	var part := PCK_DIR + name + ".part"
	if _sha256(part) != str(cur.get("sha256", "")):
		DirAccess.remove_absolute(part)
		_fail_download()
		return
	var dst := PCK_DIR + name
	if FileAccess.file_exists(dst):
		DirAccess.remove_absolute(dst)
	DirAccess.rename_absolute(part, dst)
	local[name] = str(cur["sha256"])
	_save_state()
	done_bytes += int(cur.get("size", 0))
	_next()

func _fail_download() -> void:
	bar.visible = false
	status.text = "Обновление не скачалось — проверь интернет и перезапусти игру"
	# с уже скачанной версией офлайн-тест работает; на сервер старая версия не пустит
	_set_busy(false)

func _process(_dt: float) -> void:
	if http != null and http.download_file != "" and total_bytes > 0:
		var got := done_bytes + http.get_downloaded_bytes()
		bar.value = 100.0 * got / total_bytes
		status.text = "Загружаю обновление 0.%s… %.1f из %.1f МБ" % [str(manifest.get("build", "?")), got / 1048576.0, total_bytes / 1048576.0]

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
func _launch(mode: String) -> void:
	if busy:
		return
	if not Engine.has_meta("pack_build"):
		for name in local:
			if not str(name).ends_with(".pck"):
				continue
			var p := PCK_DIR + str(name)
			if FileAccess.file_exists(p) and not ProjectSettings.load_resource_pack(p, true):
				status.text = "Пакет игры повреждён — перезапусти игру, он скачается заново"
				local.erase(name)
				_save_state()
				return
		Engine.set_meta("pack_build", str(local.get("build", APK_CODE)))
	var srv: Dictionary = manifest.get("server", {}) if manifest.get("server") is Dictionary else {}
	if srv.has("host"):
		Engine.set_meta("server_host", str(srv["host"]))
	if srv.has("port"):
		Engine.set_meta("server_port", int(srv["port"]))
	if manifest.has("build"):
		Engine.set_meta("latest_build", str(manifest["build"]))
	Engine.set_meta("start_mode", mode)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
