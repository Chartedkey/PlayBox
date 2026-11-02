class_name Achievements
extends Node
## Прогресс достижений: RetroAchievements для PS1 и PS2, локальные трофеи для PS3.

const BASE := "https://retroachievements.org/API/"
const LIST_TTL := 7 * 24 * 3600

var config: AppConfig
var _cache := {}


static func match_game(title: String, list: Array) -> int:
	var key := CoverMatcher.normalize(title)
	for g in list:
		var t: String = g.get("Title", "")
		if t.begins_with("~"):
			continue
		for part in t.split("|"):
			if CoverMatcher.normalize(part) == key:
				return int(g.get("ID", 0))
	return 0


static func console_id(list: Array, console_name: String) -> int:
	for c in list:
		if c.get("Name", "") == console_name:
			return int(c.get("ID", 0))
	return 0


## Возвращает {"earned": n, "total": m} или пустой словарь.
func progress(game: Dictionary) -> Dictionary:
	if game["console"] == "ps3":
		return TrophyReader.read_for_game(config.emulator("ps3"), game["path"])
	var user := config.secret("ra_user")
	var key := config.secret("ra_key")
	if user == "" or key == "":
		return {}
	var console_name: String = Consoles.info(game["console"])["name"]
	var consoles = await _list("consoles", "API_GetConsoleIDs.php?y=%s" % key.uri_encode())
	if not (consoles is Array):
		return {}
	var cid := console_id(consoles, console_name)
	if cid == 0:
		return {}
	var games = await _list("games_%d" % cid, "API_GetGameList.php?y=%s&i=%d&f=1" % [key.uri_encode(), cid])
	if not (games is Array):
		return {}
	var gid := match_game(game["title"], games)
	if gid == 0:
		return {}
	var url := "API_GetGameInfoAndUserProgress.php?y=%s&u=%s&g=%d" % [key.uri_encode(), user.uri_encode(), gid]
	var info = JSON.parse_string((await _fetch(url)))
	if not (info is Dictionary):
		return {}
	return {"earned": int(info.get("NumAwardedToUser", 0)), "total": int(info.get("NumAchievements", 0))}


func _list(name: String, url: String):
	if _cache.has(name):
		return _cache[name]
	var path := "user://ra_%s.json" % name
	var now := int(Time.get_unix_time_from_system())
	if FileAccess.file_exists(path) and now - FileAccess.get_modified_time(path) < LIST_TTL:
		var cached = JSON.parse_string(FileAccess.get_file_as_string(path))
		if cached is Array:
			_cache[name] = cached
			return cached
	var text := await _fetch(url)
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		_cache[name] = parsed
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(text)
	return parsed


func _fetch(url: String) -> String:
	var http := HTTPRequest.new()
	http.timeout = 30.0
	add_child(http)
	if http.request(BASE + url, ["User-Agent: PlayBox"]) != OK:
		http.queue_free()
		return ""
	var res: Array = await http.request_completed
	http.queue_free()
	return res[3].get_string_from_utf8() if res[1] == 200 else ""
