class_name Net
extends Node
## Сеть через ENet. Один и тот же узел работает либо сервером (много игроков), либо клиентом.
## Не автозагрузка: создаётся в main.gd и доступен как Net.I — так его можно обновлять пакетом лаунчера.
##
## Канал 0 — надёжный: вход, действия, события мира (RPC _recv_rel).
## Канал 1 — надёжный, только позиции/ввод 20 раз в секунду (сырые байты send_bytes).
##   «Ненадёжный» режим ENet при задержках сам выкидывает пакеты сериями по секунде —
##   проверено замерами в Zomboid, поэтому для позиций тоже надёжный, но отдельный канал.

const DEFAULT_PORT := 7777
## Шифрование канала (DTLS, BF-038): сервер — своим ключом, созданным при первом запуске; телефон шифрует
## и с 0.27 сверяет сертификат сервера с вшитым SERVER_CERT — подменить сервер посередине (свой Wi-Fi) нельзя.
const TLS_NAME := "umwelt-rp"
## Сертификат игрового сервера на Hetzner — публичный (`dtls/dtls.crt` в папке данных сервера), прислан владельцем
## 2026-11-04, SHA-256 19:E2:A7:FF…A9:88:D7:E3. Если ключ сервера пересоздан (удалён `dtls.key`), телефоны перестанут
## подключаться, пока здесь не будет новый сертификат (руководство, раздел 8)
const SERVER_CERT := """-----BEGIN CERTIFICATE-----
MIIDDzCCAfegAwIBAgIVAOaH+E4BdQNDVRvze5/1fSkbES+PMA0GCSqGSIb3DQEB
CwUAMDUxEjAQBgNVBAMMCXVtd2VsdC1ycDESMBAGA1UECgwJVW13ZWx0IFJQMQsw
CQYDVQQGEwJQTDAeFw0yNjAxMDEwMDAwMDBaFw00NjAxMDEwMDAwMDBaMDUxEjAQ
BgNVBAMMCXVtd2VsdC1ycDESMBAGA1UECgwJVW13ZWx0IFJQMQswCQYDVQQGEwJQ
TDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALIzjckKFjSEeFElpF87
drQC4YnixhV6jL40R8TIlVPVxwvl6TEN1sOVQTWlPVrQR3CXExmY/P4pkCS0DjPF
yOKlRvTYnrSzjenAqAW06U5wXnEHc8mHHK48oZK2iWcKwRWdOu8L2k9YXNtRdC27
MZrDhJtK4lnubKf4FEtX8KquXs9sA3smBjVaOYvTE2oWPqjPpwhpl3801a+IS5WK
MKieAzwKXuE/QBG/CtiUKNE7VklUG/LFEh685kBqxIHWukSKd2ULwSpSEeBNkssi
tGmnuirRNjfXATAmzAKjOrtrw+bX2UaAvKIumI8vyNbQKo8E+1NBY62sREFfjqmm
2e8CAwEAAaMWMBQwEgYDVR0TAQH/BAgwBgEB/wIBADANBgkqhkiG9w0BAQsFAAOC
AQEAFFsDSKGDJ+KEs8ZgXUbWrpk5odM+i0PSchrhtM7gQXnPZ162ZIt7WNS5K3Ae
i62Lxspz/LwA8s0ult4K42w8GHbER4zM6pzCl9PCQnmHSaUyk/g6wtmRpbJ6CNnE
1LhQ6im+hpSxIt1KH53zvKlpRuM1mGs9bEDu+M4N8jNBL69j/XIjDDFqkpYL2LwP
kScbqnC4gSRMdc654imBKp6NX8HBiFB+T6bMTxdq3EEJZ9TJY2c4fZDuL5ff980m
bi8Z35jkrNX0OrOOLExgmM9xTuBOU0T6Uejqp5LOM5PLBLJRN43mnu8HmAx74REu
uy3Itjsx3bfMK2KdDhX7E9l1Cg==
-----END CERTIFICATE-----"""

static var I: Net

## Входящие сообщения: словари с полем "_from" — id отправителя (на клиенте всегда 1)
var inbox: Array = []
var connected := false
var status := ""
var is_server := false
var peers := {}                  # сервер: id подключения → true
var max_clients := 64

var n_fast_out := 0
var n_fast_in := 0

func _enter_tree() -> void:
	I = self

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): status = "Не удалось подключиться к серверу"; _lost())
	multiplayer.server_disconnected.connect(func(): status = "Соединение с сервером потеряно"; _lost())
	(multiplayer as SceneMultiplayer).peer_packet.connect(_on_bytes)
	# сервер не пересылает пакеты клиента другим клиентам и не сообщает им о чужих подключениях (Н5)
	(multiplayer as SceneMultiplayer).server_relay = false

# ================== запуск ==================
func serve(port: int, max_c: int, tls: TLSOptions) -> bool:
	close()
	if tls == null:
		status = "Нет ключа шифрования — сервер без шифрования не запускается"
		return false
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, max_c, 2)
	if err != OK:
		status = "Порт %d занят или недоступен (%d)" % [port, err]
		return false
	err = p.host.dtls_server_setup(tls)
	if err != OK:
		p.close()
		status = "Не удалось включить шифрование (%d)" % err
		return false
	multiplayer.multiplayer_peer = p
	is_server = true
	max_clients = max_c
	status = "Сервер слушает порт %d" % port
	return true

func join(ip: String, port: int) -> void:
	close()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, port, 2)
	if err == OK:
		var tls := client_tls(ip)
		err = p.host.dtls_client_setup(TLS_NAME, tls) if tls != null else FAILED
	if err != OK:
		status = "Не удалось подключиться"
		_lost()
		return
	multiplayer.multiplayer_peer = p
	is_server = false
	status = "Подключение к %s…" % ip

## Настройки шифрования телефона: сервер должен предъявить сертификат pin (по умолчанию — вшитый SERVER_CERT).
## Только для своего компьютера (127.0.0.1 — тесты и CI, там сервер создаёт себе свой ключ) сертификат не сверяется
static func client_tls(host: String, pin: String = SERVER_CERT) -> TLSOptions:
	if host == "127.0.0.1" or host == "localhost" or host == "::1":
		return TLSOptions.client_unsafe()
	var cert := X509Certificate.new()
	if cert.load_from_string(pin) != OK:
		return null
	return TLSOptions.client(cert)

## Ключ и сертификат сервера: создаются один раз и лежат в dir (на Hetzner — папка данных сервера)
static func server_tls(dir: String) -> TLSOptions:
	var kp := dir.path_join("dtls.key")
	var cp := dir.path_join("dtls.crt")
	var key := CryptoKey.new()
	var cert := X509Certificate.new()
	if not (FileAccess.file_exists(kp) and FileAccess.file_exists(cp) and key.load(kp) == OK and cert.load(cp) == OK):
		DirAccess.make_dir_recursive_absolute(dir)
		var c := Crypto.new()
		key = c.generate_rsa(2048)
		cert = c.generate_self_signed_certificate(key, "CN=%s,O=Umwelt RP,C=PL" % TLS_NAME, "20260101000000", "20460101000000")
		if key.save(kp) != OK or cert.save(cp) != OK:
			return null
	return TLSOptions.server(key, cert)

func close() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
	is_server = false
	peers.clear()
	inbox.clear()

## Сервер: IP-адрес подключения ("" — неизвестен)
func peer_ip(id: int) -> String:
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var pp := (mp as ENetMultiplayerPeer).get_peer(id)
		if pp != null:
			return pp.get_remote_address()
	return ""

func kick(id: int) -> void:
	if is_server and peers.has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)

# ================== события ENet ==================
func _on_connected() -> void:
	connected = true
	status = "Подключено"

func _on_peer_connected(id: int) -> void:
	if is_server:
		peers[id] = true
		connected = true

func _on_peer_disconnected(id: int) -> void:
	if is_server and peers.has(id):
		peers.erase(id)
		inbox.append({"t": "disconnect", "_from": id})

func _lost() -> void:
	connected = false
	inbox.append({"t": "disconnect", "_from": 1})

# ================== отправка ==================
## Надёжно (канал 0). Клиент: to не нужен — всегда серверу
func send(msg: Dictionary, to: int = 1) -> void:
	if not connected:
		return
	if is_server and not peers.has(to):
		return
	_recv_rel.rpc_id(to, msg)

## Позиции и ввод (канал 1)
func send_fast(msg: Dictionary, to: int = 1) -> void:
	if not connected:
		return
	if is_server and not peers.has(to):
		return
	n_fast_out += 1
	(multiplayer as SceneMultiplayer).send_bytes(var_to_bytes(msg), to, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 1)

# ================== приём ==================
@rpc("any_peer", "call_remote", "reliable", 0)
func _recv_rel(msg: Dictionary) -> void:
	var from := multiplayer.get_remote_sender_id()
	if not is_server and from != 1:
		return
	msg["_from"] = from
	inbox.append(msg)

func _on_bytes(id: int, data: PackedByteArray) -> void:
	if not is_server and id != 1:
		return
	if is_server and data.size() > 4096:
		return                     # ввод игрока маленький — крупное от клиента не принимаем
	var m = bytes_to_var(data)     # без объектов — безопасно
	if m is Dictionary:
		n_fast_in += 1
		m["_from"] = id
		inbox.append(m)
