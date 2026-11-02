class_name EmulatorLauncher
extends Node
## Запускает эмулятор и считает время, пока его процесс работает.

signal finished(game: Dictionary, seconds: float)

const SAVE_EVERY := 30.0
const POLL := 1.0

var library: LibraryStore
var _pid := -1
var _game := {}
var _started := 0.0
var _last_saved := 0.0
var _poll_timer := 0.0


static func build_args(template: Array, game_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for a in template:
		out.append(String(a).replace("{path}", game_path))
	return out


func is_running() -> bool:
	return _pid != -1


func launch(config: AppConfig, game: Dictionary) -> int:
	var args := build_args(config.launch_args(game["console"]), game["path"])
	var pid := OS.create_process(config.emulator(game["console"]), args)
	if pid <= 0:
		return ERR_CANT_CREATE
	_pid = pid
	_game = game
	_started = Time.get_unix_time_from_system()
	_last_saved = _started
	return OK


func _process(delta: float) -> void:
	if _pid == -1:
		return
	_poll_timer += delta
	if _poll_timer < POLL:
		return
	_poll_timer = 0.0
	var now := Time.get_unix_time_from_system()
	if OS.is_process_running(_pid):
		# Сохраняем понемногу, чтобы не потерять время при сбое.
		if now - _last_saved >= SAVE_EVERY:
			_flush(now)
		return
	_flush(now)
	var total := now - _started
	var g := _game
	_pid = -1
	_game = {}
	finished.emit(g, total)


func _flush(now: float) -> void:
	if library:
		library.add_seconds(_game["id"], now - _last_saved)
		library.save()
	_last_saved = now
