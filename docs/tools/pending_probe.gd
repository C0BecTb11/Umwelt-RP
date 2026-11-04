extends SceneTree
## Проверка в CI (BF-043): с одного адреса без входа держится не больше MAX_PENDING_IP подключений.
## Открывает 6 зашифрованных подключений и «привета» не шлёт; через 2 с считает, сколько ещё подключены.
## Запуск: godot --headless --path . --script docs/tools/pending_probe.gd -- порт
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var port: int = int(a[0]) if a.size() > 0 else 7790
	var peers: Array[ENetMultiplayerPeer] = []
	for i in 6:
		var p := ENetMultiplayerPeer.new()
		p.create_client("127.0.0.1", port, 2)
		p.host.dtls_client_setup(Net.TLS_NAME, Net.client_tls("127.0.0.1"))
		peers.append(p)
		for k in 20:                         # подключаемся по очереди, как настоящий наплыв
			p.poll()
			OS.delay_msec(10)
	var up := 0
	for k in 200:                            # 2 с — меньше HELLO_WAIT, честные «молчуны» ещё не отключены
		up = 0
		for p in peers:
			p.poll()
			if p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				up += 1
		OS.delay_msec(10)
	print("подключений без входа с одного адреса держится: %d из 6" % up)
	for p in peers:
		p.close()
	quit(0)
