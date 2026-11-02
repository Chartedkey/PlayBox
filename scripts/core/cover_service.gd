class_name CoverService
extends Node
## Скачивает обложки по одной и кэширует их у пользователя.

signal cover_ready(game_id: String, file_path: String)

const BASE := "https://thumbnails.libretro.com/%s/Named_Boxarts/"
const CACHE_DIR := "user://covers"

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
	if name != "":
		var url := _base_url(system) + CoverMatcher.sanitize(name).uri_encode() + ".png"
		var bytes := await _fetch(url)
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


func _fetch(url: String) -> PackedByteArray:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	if http.request(url) != OK:
		http.queue_free()
		return PackedByteArray()
	var res: Array = await http.request_completed
	http.queue_free()
	return res[3] if res[1] == 200 else PackedByteArray()
