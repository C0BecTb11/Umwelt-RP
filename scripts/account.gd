extends Node
## Аккаунт игрока через Supabase Auth (почта + пароль) и его персонаж (таблица characters).
## Подключается через preload, без class_name (новый class_name потребовал бы новый APK).
## Пароль уходит только в Supabase по HTTPS; игровому серверу передаётся токен доступа.

const CFG := "user://account.cfg"

var email := ""
var refresh_token := ""
var access_token := ""
var user_id := ""
var char_name := ""
var char_id := -1
var last_error := ""

func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(CFG) == OK:
		email = str(c.get_value("auth", "email", ""))
		refresh_token = str(c.get_value("auth", "refresh", ""))

func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("auth", "email", email)
	c.set_value("auth", "refresh", refresh_token)
	c.save(CFG)

func has_session() -> bool:
	return refresh_token != ""

func sign_out() -> void:
	refresh_token = ""
	access_token = ""
	user_id = ""
	char_name = ""
	_save()

# ---------- запросы ----------
## Возвращает [код HTTP, ответ (Dictionary/Array/null)]; код 0 — нет связи
func _req(method: int, path: String, body = null, token: String = "", extra: PackedStringArray = []) -> Array:
	var h := HTTPRequest.new()
	h.timeout = 20.0
	add_child(h)
	var headers := PackedStringArray(["apikey: " + Boot.SUPABASE_KEY, "Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	headers.append_array(extra)
	var err := h.request(Boot.SUPABASE_URL + path, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		h.queue_free()
		return [0, null]
	var r: Array = await h.request_completed
	h.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		return [0, null]
	var data = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8()) if (r[3] as PackedByteArray).size() > 0 else null
	return [int(r[1]), data]

func _take_session(d) -> bool:
	if not (d is Dictionary) or not d.has("access_token"):
		return false
	access_token = str(d["access_token"])
	refresh_token = str(d.get("refresh_token", ""))
	var u = d.get("user", {})
	user_id = str(u.get("id", "")) if u is Dictionary else ""
	if u is Dictionary and u.has("email"):
		email = str(u["email"])
	_save()
	return true

## Понятный игроку текст ошибки Supabase
static func explain(code: int, d) -> String:
	if code == 0:
		return "Нет связи с сервером аккаунтов — проверь интернет"
	var msg := ""
	if d is Dictionary:
		msg = str(d.get("msg", d.get("message", d.get("error_description", d.get("error", ""))))).to_lower()
		var ec := str(d.get("error_code", d.get("code", "")))
		if ec == "23505":
			return "Это имя уже занято"
		if ec == "23514":
			return "Имя должно быть в формате Имя_Фамилия латиницей"
	if "invalid login" in msg:
		return "Неверная почта или пароль"
	if "already registered" in msg or "already been registered" in msg:
		return "Эта почта уже зарегистрирована — нажми «Войти»"
	if "email not confirmed" in msg:
		return "Почта не подтверждена — открой письмо и нажми ссылку"
	if "password" in msg and ("6" in msg or "short" in msg or "weak" in msg):
		return "Пароль слишком простой: минимум 6 символов"
	if "email" in msg and ("invalid" in msg or "format" in msg):
		return "Похоже, почта написана с ошибкой"
	if "rate limit" in msg or code == 429:
		return "Слишком много попыток — подожди минуту"
	return "Ошибка аккаунта (%d)" % code

# ---------- вход / регистрация ----------
## Регистрация. Возвращает "ok" (сразу вошли), "confirm" (нужно подтвердить почту) или "" (ошибка в last_error)
func sign_up(mail: String, pw: String) -> String:
	var r: Array = await _req(HTTPClient.METHOD_POST, "/auth/v1/signup", {"email": mail, "password": pw})
	if r[0] >= 200 and r[0] < 300:
		email = mail
		if _take_session(r[1]):
			return "ok"
		_save()
		return "confirm"
	last_error = explain(r[0], r[1])
	return ""

func sign_in(mail: String, pw: String) -> bool:
	var r: Array = await _req(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": mail, "password": pw})
	if r[0] == 200 and _take_session(r[1]):
		return true
	last_error = explain(r[0], r[1])
	return false

## Свежий токен по сохранённой сессии (токен живёт час — берём новый перед каждым входом в игру)
func refresh() -> bool:
	if refresh_token == "":
		return false
	var r: Array = await _req(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token})
	if r[0] == 200 and _take_session(r[1]):
		return true
	last_error = explain(r[0], r[1])
	if r[0] >= 400 and r[0] < 500:
		sign_out()          # сессия больше не действует — войти заново
	return false

# ---------- редактор карты ----------
const EDITOR_CFG := "user://editor.cfg"

## Может ли аккаунт отправлять карты (правило базы: таблица admins). Ответ запоминается в телефоне —
## по нему в паузе офлайн-теста показывается кнопка редактора. Решает всё равно база при отправке
func check_admin() -> void:
	var r: Array = await _req(HTTPClient.METHOD_POST, "/rest/v1/rpc/is_admin", {}, access_token)
	if r[0] == 200:
		var c := ConfigFile.new()
		c.set_value("editor", "admin", r[1] == true)
		c.save(EDITOR_CFG)

static func admin_cached() -> bool:
	var c := ConfigFile.new()
	return c.load(EDITOR_CFG) == OK and c.get_value("editor", "admin", false) == true

# ---------- персонаж ----------
## Имя персонажа этого аккаунта ("" — ещё не создан). null — ошибка связи
func load_character():
	var r: Array = await _req(HTTPClient.METHOD_GET, "/rest/v1/characters?select=id,name&user_id=eq." + user_id, null, access_token)
	if r[0] == 200 and r[1] is Array:
		char_name = str(r[1][0]["name"]) if r[1].size() > 0 else ""
		char_id = int(r[1][0].get("id", -1)) if r[1].size() > 0 else -1
		return char_name
	last_error = explain(r[0], r[1])
	return null

static func valid_name(first: String, last: String) -> String:
	var re := RegEx.create_from_string("^[A-Z][a-z]{1,14}$")
	var re2 := RegEx.create_from_string("^[A-Z][a-z]{1,19}$")
	if re.search(first) == null or re2.search(last) == null:
		return "Имя и фамилия — латиницей, с заглавной буквы, без пробелов и цифр (например, John и Miller)"
	return ""

func create_character(n: String, gender: String = "m") -> bool:
	var r: Array = await _req(HTTPClient.METHOD_POST, "/rest/v1/characters", {"user_id": user_id, "name": n, "gender": gender}, access_token, PackedStringArray(["Prefer: return=minimal"]))
	if r[0] >= 200 and r[0] < 300:
		char_name = n
		return true
	last_error = explain(r[0], r[1])
	return false
