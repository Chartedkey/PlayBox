class_name AppConfig
extends RefCounted
## Локальные настройки: пути к эмуляторам, папки с играми и ключи.
## Файл лежит в папке пользователя и не попадает в репозиторий.

var path: String
var _cfg := ConfigFile.new()


func _init(config_path := "user://config.cfg") -> void:
	path = config_path
	_cfg.load(path)


func save() -> void:
	_cfg.save(path)


func emulator(console: String) -> String:
	return _cfg.get_value(console, "emulator", "")


func set_emulator(console: String, value: String) -> void:
	_cfg.set_value(console, "emulator", value)


func games_folder(console: String) -> String:
	return _cfg.get_value(console, "folder", "")


func set_games_folder(console: String, value: String) -> void:
	_cfg.set_value(console, "folder", value)


func launch_args(console: String) -> Array:
	return _cfg.get_value(console, "args", Consoles.info(console)["args"])


func secret(name: String) -> String:
	return _cfg.get_value("keys", name, "")


func set_secret(name: String, value: String) -> void:
	_cfg.set_value("keys", name, value)


func is_console_ready(console: String) -> bool:
	return emulator(console) != "" and FileAccess.file_exists(emulator(console))


func any_console_ready() -> bool:
	for id in Consoles.IDS:
		if is_console_ready(id):
			return true
	return false
