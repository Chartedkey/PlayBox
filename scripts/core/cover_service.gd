class_name CoverService
extends Node
## Скачивает обложки по одной и кэширует их у пользователя.

signal cover_ready(game_id: String, file_path: String)

const BASE := "https://thumbnails.libretro.com/%s/Named_Boxarts/"
const CACHE_DIR := "user://covers"
const SGDB := "https://www.steamgriddb.com/api/v2"

var sgdb_key := ""

var _queue: Array[Dictionary] = []
var _busy := false
var _listings := {}


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
	var system: String = Consoles.info(game["console"])["libretro"]
	if not _listings.has(system):
		var body := await _fetch(_base_url(system))
		_listings[system] = CoverMatcher.parse_listing(body.get_string_from_utf8())
	var name := CoverMatcher.best_match(game["raw_name"], game["title"], game["region"], _listings[system])
	# Если список не загрузился, пробуем точное имя файла.
	if name == "" and _listings[system].is_empty():
		name = game["raw_name"]
	var bytes := PackedByteArray()
	if name != "":
		bytes = await _fetch(_base_url(system) + CoverMatcher.sanitize(name).uri_encode() + ".png")
	if bytes.is_empty() and sgdb_key != "":
		bytes = await _fetch_sgdb(game["title"])
	if bytes.size() > 0:
		var f := FileAccess.open(cache_path(game["id"]), FileAccess.WRITE)
		if f:
			f.store_buffer(bytes)
			f.close()
			cover_ready.emit(game["id"], cache_path(game["id"]))
	_busy = false
	_next()


func _base_url(system: String) -> String:
	return BASE % system.uri_encode()


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
	http.timeout = 20.0
	add_child(http)
	if http.request(url, headers) != OK:
		http.queue_free()
		return PackedByteArray()
	var res: Array = await http.request_completed
	http.queue_free()
	return res[3] if res[1] == 200 else PackedByteArray()
