extends SceneTree
## Проверка в CI: лаунчер (тот самый код, что в APK) принимает подпись манифеста, сделанную сборкой.
## Запуск: godot --headless --path . --script docs/tools/verify_manifest.gd -- manifest.json manifest.sig
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var launcher = load("res://launcher/launcher.gd")
	var key: String = launcher.UPDATE_KEY_B64
	if key.begins_with("@"):
		print("ОШИБКА: в лаунчер не подставлен ключ подписи обновлений")
		quit(1)
		return
	var body := FileAccess.get_file_as_bytes(a[0])
	var sig := FileAccess.get_file_as_string(a[1])
	var ok: bool = launcher.signature_ok(body, sig, key)
	var bad := body.duplicate()
	bad[bad.size() / 2] = (bad[bad.size() / 2] + 1) % 256
	var bad_ok: bool = launcher.signature_ok(bad, sig, key)
	print("лаунчер: подпись манифеста %s, подменённый манифест %s" % ["принята" if ok else "НЕ принята", "принят (ОШИБКА)" if bad_ok else "отклонён"])
	quit(0 if ok and not bad_ok else 1)
