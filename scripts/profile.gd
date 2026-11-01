class_name Profile
extends RefCounted
## Настройки этого телефона: постоянный ID (он же «аккаунт» до появления базы), ник, графика.
## Хранится в user://settings.cfg и переживает обновления игры.

const PATH := "user://settings.cfg"

static var uid := ""
static var nick := ""
static var low_gfx := false
static var _loaded := false

static func load_profile() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	uid = str(cfg.get_value("profile", "uid", ""))
	nick = str(cfg.get_value("profile", "nick", ""))
	low_gfx = bool(cfg.get_value("gfx", "low", false))
	if uid == "":
		uid = Crypto.new().generate_random_bytes(12).hex_encode()
	if nick == "":
		nick = "Гражданин-%s" % uid.substr(0, 4).to_upper()
	save_profile()

static func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("profile", "uid", uid)
	cfg.set_value("profile", "nick", nick)
	cfg.set_value("gfx", "low", low_gfx)
	cfg.save(PATH)
