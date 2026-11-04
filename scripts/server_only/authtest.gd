extends Node
## Проверка входа по аккаунту целиком: Supabase → игровой сервер.
## Запуск: сервер `--server --port=7795` (без --noauth) и клиент `--authtest=почта,пароль,порт`.
## Нужен доступ в интернет к Supabase (в CI — .github/workflows/auth-test.yml).

var role := ""
var main: Node
var acc: Node
var t := 0.0
var step := 0

func L(s: String) -> void:
	print("[вход %.1f] %s" % [t, s])

func fail(s: String) -> void:
	L("ИТОГ: ОШИБКА — " + s)
	get_tree().quit(1)

func _ready() -> void:
	var a := role.split(",")
	acc = preload("res://scripts/account.gd").new()
	add_child(acc)
	acc.sign_out()
	# 1) неверный пароль — понятная ошибка
	var bad: bool = await acc.sign_in(a[0], a[1] + "x")
	if bad or acc.last_error != "Неверная почта или пароль":
		fail("неверный пароль: %s / %s" % [bad, acc.last_error])
		return
	L("неверный пароль: «%s» — верно" % acc.last_error)
	# 2) вход, персонаж
	if not await acc.sign_in(a[0], a[1]):
		fail("вход: " + acc.last_error)
		return
	L("вошёл, user_id %s…" % acc.user_id.left(8))
	var n = await acc.load_character()
	if n == null:
		fail("персонаж: " + acc.last_error)
		return
	if n == "":
		if not await acc.create_character("Test_Bot"):
			fail("создание персонажа: " + acc.last_error)
			return
		L("создан персонаж Test_Bot")
	else:
		L("персонаж уже есть: " + str(n))
	# 3) чужое занятое имя и неверный формат — отказ базы
	var other_ok: bool = await acc.create_character("test_bot")
	if other_ok:
		fail("база приняла второе имя для того же аккаунта")
		return
	L("повторное/кривое имя отклонено: «%s»" % acc.last_error)
	# 4) обновление сессии
	if not await acc.refresh():
		fail("обновление сессии: " + acc.last_error)
		return
	L("сессия обновлена")
	# 5) вход на игровой сервер по токену
	Net.I.join("127.0.0.1", int(a[2]))
	main._start(GameScreen.Mode.CLIENT, null)
	main.screen.auth_token = acc.access_token
	step = 1

func _process(dt: float) -> void:
	t += dt
	if step == 1:
		var scr: GameScreen = main.screen
		if scr.game != null and scr.me() != null:
			step = 2
			var ok: bool = scr.me().name == "Test_Bot"
			L("сервер впустил: персонаж %d «%s»" % [scr.local_pid, scr.me().name])
			await acc.logout()                # сессия бота не остаётся висеть в базе после каждой сборки
			L("сессия закрыта")
			L("ИТОГ: %s" % ("OK" if ok else "ОШИБКА — имя не из базы"))
			get_tree().quit(0 if ok else 1)
		elif scr.lost or t > 25.0:
			fail("сервер не впустил: " + Net.I.status)
