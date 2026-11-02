class_name UpdateInstaller
extends Node
## Скачивает новую версию и заменяет PlayBox.exe.
## Работающий exe в Windows нельзя перезаписать, но можно переименовать.

signal progress(fraction: float)

const MIN_EXE_SIZE := 1024 * 1024

var _http: HTTPRequest
var _expected := 0


static func old_path(exe: String) -> String:
	return exe.get_basename() + ".old.exe"


static func new_path(exe: String) -> String:
	return exe.get_basename() + ".new.exe"


## Убирает файл прошлой версии. Ошибка не важна: удалим при следующем запуске.
static func cleanup(exe: String) -> void:
	if FileAccess.file_exists(old_path(exe)):
		DirAccess.remove_absolute(old_path(exe))


## Меняет файлы местами, а при ошибке возвращает всё обратно.
static func swap(exe: String) -> int:
	var old := old_path(exe)
	if FileAccess.file_exists(old) and DirAccess.remove_absolute(old) != OK:
		return ERR_FILE_CANT_WRITE
	var err := DirAccess.rename_absolute(exe, old)
	if err != OK:
		return err
	err = DirAccess.rename_absolute(new_path(exe), exe)
	if err != OK:
		DirAccess.rename_absolute(old, exe)
	return err


## Достаёт exe из архива и проверяет, что это похоже на программу.
static func extract(zip_path: String, dest: String, min_size := MIN_EXE_SIZE) -> int:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return ERR_FILE_CORRUPT
	var name := ""
	for f in zip.get_files():
		if f.get_file().to_lower() == "playbox.exe":
			name = f
	if name == "":
		zip.close()
		return ERR_FILE_NOT_FOUND
	var bytes := zip.read_file(name)
	zip.close()
	if bytes.size() < min_size or bytes[0] != 0x4D or bytes[1] != 0x5A:
		return ERR_FILE_CORRUPT
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		return ERR_FILE_CANT_WRITE
	f.store_buffer(bytes)
	f.close()
	return OK


func _process(_delta: float) -> void:
	if _http and _expected > 0:
		progress.emit(clampf(float(_http.get_downloaded_bytes()) / _expected, 0.0, 1.0))


## Возвращает текст ошибки или пустую строку.
func install(url: String, expected_size: int, exe: String, zip_path := "user://update.zip") -> String:
	_expected = expected_size
	_http = HTTPRequest.new()
	_http.download_file = zip_path
	_http.max_redirects = 10
	add_child(_http)
	var req_err := _http.request(url, ["User-Agent: PlayBox"])
	if req_err != OK:
		return _finish("Не удалось начать скачивание.", zip_path)
	var res: Array = await _http.request_completed
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return _finish("Не удалось скачать обновление. Проверьте интернет.", zip_path)
	var local := ProjectSettings.globalize_path(zip_path)
	if expected_size > 0 and FileAccess.open(zip_path, FileAccess.READ).get_length() != expected_size:
		return _finish("Файл обновления скачался не полностью.", zip_path)
	if extract(local, new_path(exe)) != OK:
		return _finish("Не удалось прочитать файл обновления.", zip_path)
	if swap(exe) != OK:
		DirAccess.remove_absolute(new_path(exe))
		return _finish("Не удалось заменить файл. Возможно, папка защищена от записи.", zip_path)
	return _finish("", zip_path)


func _finish(message: String, zip_path: String) -> String:
	_expected = 0
	if _http:
		_http.queue_free()
		_http = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))
	return message
