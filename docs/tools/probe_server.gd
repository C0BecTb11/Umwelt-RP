extends SceneTree
## Проверка в CI перед выпуском: боевой сервер предъявляет тот сертификат, что вшит в игру (Net.SERVER_CERT).
## Иначе выпуск остановится — телефоны с такой сборкой не смогли бы подключиться (BF-038).
## Если сервер недоступен даже без сверки (выключен, обновляется) — только предупреждение, выпуск идёт.
## Запуск: godot --headless --path . --script docs/tools/probe_server.gd [-- адрес порт]
func _connect(host: String, port: int, tls: TLSOptions) -> int:
	var p := ENetMultiplayerPeer.new()
	if p.create_client(host, port, 2) != OK or p.host.dtls_client_setup(Net.TLS_NAME, tls) != OK:
		return -1
	var st := MultiplayerPeer.CONNECTION_CONNECTING
	for i in 800:                   # до 8 с
		p.poll()
		st = p.get_connection_status()
		if st != MultiplayerPeer.CONNECTION_CONNECTING:
			break
		OS.delay_msec(10)
	p.close()
	return st

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var host: String = a[0] if a.size() > 0 else Boot.DEFAULT_HOST
	var port: int = int(a[1]) if a.size() > 1 else Boot.DEFAULT_PORT
	var pinned := Net.client_tls(host)
	if pinned == null:
		print("ОШИБКА: вшитый сертификат сервера не читается")
		quit(1)
		return
	var any := _connect(host, port, TLSOptions.client_unsafe())
	if any != MultiplayerPeer.CONNECTION_CONNECTED:
		print("ПРЕДУПРЕЖДЕНИЕ: сервер %s:%d не отвечает (выключен или обновляется) — сертификат не проверен" % [host, port])
		quit(0)
		return
	var st := _connect(host, port, pinned)
	if st == MultiplayerPeer.CONNECTION_CONNECTED:
		print("сервер %s:%d: сертификат совпадает с вшитым в игру" % [host, port])
		quit(0)
	else:
		print("ОШИБКА: сертификат сервера %s:%d НЕ СОВПАДАЕТ с вшитым в игру (Net.SERVER_CERT) — телефоны не подключатся" % [host, port])
		quit(1)
