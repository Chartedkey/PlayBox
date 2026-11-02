class_name CoverService
extends Node
## Скачивает обложки по одной и кэширует их у пользователя.

signal cover_ready(game_id: String, file_path: String)

const LOG := "user://covers.log"
const CACHE_DIR := "user://covers"
const SGDB := "https://www.steamgriddb.com/api/v2"

var sgdb_key := ""

var _queue: Array[Dictionary] = []
var _busy := false
var _indexes := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)


static func cache_path(game_id: String) -> String:
	return CACHE_DIR.path_join(game_id + ".png")


func request_cover(game: Dictionary) -> void:
	if FileAccess.file_exists(cache_path(game["id"])):
		return
	_queue.append(game)
	_next()


func _next() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var game: Dictionary = _queue.pop_front()
	var console: String = game["console"]
	if not _indexes.has(console):
		_indexes[console] = CoverMatcher.load_index(console)
	var name := CoverMatcher.best_match(game["raw_name"], game["title"], game["region"], _indexes[console])
	var bytes := PackedByteArray()
	if name != "":
		for url in urls_for(console, name):
			bytes = await _fetch(url)
			_log("%s -> %d байт: %s" % [game["title"], bytes.size(), url])
			if CoverMatcher.is_png(bytes):
				break
			bytes = PackedByteArray()
	else:
		_log("%s: нет в списке обложек" % game["title"])
	if bytes.is_empty() and sgdb_key != "":
		bytes = await _fetch_sgdb(game["title"])
		_log("%s: SteamGridDB -> %d байт" % [game["title"], bytes.size()])
	if bytes.size() > 0:
		var f := FileAccess.open(cache_path(game["id"]), FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
			f.close()
			cover_ready.emit(game["id"], cache_path(game["id"]))
	_busy = false
	_next()


static func urls_for(console: String, name: String) -> PackedStringArray:
	var info := Consoles.info(console)
	var file := name.uri_encode() + ".png"
	var system: String = info["libretro"]
	var repo := system.replace(" ", "_")
	return PackedStringArray([
		"https://raw.githubusercontent.com/libretro-thumbnails/%s/master/Named_Boxarts/%s" % [repo, file],
		"https://thumbnails.libretro.com/%s/Named_Boxarts/%s" % [system.uri_encode(), file],
	])


func _log(line: String) -> void:
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(LOG) else FileAccess.WRITE
	var f := FileAccess.open(LOG, mode)
	if f:
		f.seek_end()
		f.store_line(line)


## Запасной вариант: вертикальная обложка из SteamGridDB по названию игры.
func _fetch_sgdb(title: String) -> PackedByteArray:
	var auth := PackedStringArray(["Authorization: Bearer " + sgdb_key])
	var found = JSON.parse_string((await _fetch(SGDB + "/search/autocomplete/" + title.uri_encode(), auth)).get_string_from_utf8())
	if not (found is Dictionary) or found.get("data", []).is_empty():
		return PackedByteArray()
	var game_id := int(found["data"][0]["id"])
	var grids = JSON.parse_string((await _fetch(SGDB + "/grids/game/%d?dimensions=600x900&types=static&nsfw=false&humor=false" % game_id, auth)).get_string_from_utf8())
	if not (grids is Dictionary) or grids.get("data", []).is_empty():
		return PackedByteArray()
	var url: String = grids["data"][0]["url"]
	if not url.to_lower().ends_with(".png"):
		return await _fetch_converted(url)
	return await _fetch(url)


## Кэш обложек хранится в PNG, поэтому JPG и WEBP перекодируем.
func _fetch_converted(url: String) -> PackedByteArray:
	var bytes := await _fetch(url)
	var img := Image.new()
	var ext := url.get_extension().to_lower()
	var err := img.load_webp_from_buffer(bytes) if ext == "webp" else img.load_jpg_from_buffer(bytes)
	return img.save_png_to_buffer() if err == OK else PackedByteArray()


func _fetch(url: String, headers := PackedStringArray()) -> PackedByteArray:
	var http := HTTPRequest.new()
	http.timeout = 25.0
	http.max_redirects = 8
	add_child(http)
	headers.append("User-Agent: PlayBox")
	if http.request(url, headers) != OK:
		http.queue_free()
		return PackedByteArray()
	var res: Array = await http.request_completed
	http.queue_free()
	return res[3] if res[1] == 200 else PackedByteArray()
