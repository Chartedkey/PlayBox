class_name LibraryStore
extends RefCounted
## Время в игре, свои обложки и диски, игры, добавленные вручную.

var path: String
var _data := {"games": {}, "manual": []}


func _init(store_path := "user://library.json") -> void:
	path = store_path
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_data.merge(parsed, true)


func save() -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	DirAccess.rename_absolute(tmp, path)


func _entry(id: String) -> Dictionary:
	if not _data["games"].has(id):
		_data["games"][id] = {"seconds": 0.0, "last_played": ""}
	return _data["games"][id]


func seconds(id: String) -> float:
	return float(_data["games"].get(id, {}).get("seconds", 0.0))


func add_seconds(id: String, value: float) -> void:
	var e := _entry(id)
	e["seconds"] = float(e["seconds"]) + value
	e["last_played"] = Time.get_datetime_string_from_system()


func image_override(id: String, kind: String) -> String:
	return _data["games"].get(id, {}).get(kind, "")


func set_image_override(id: String, kind: String, value: String) -> void:
	var e := _entry(id)
	if value == "":
		e.erase(kind)
	else:
		e[kind] = value


func manual_games(console: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in _data["manual"]:
		if g["console"] == console:
			out.append(g)
	return out


func add_manual(game: Dictionary) -> void:
	for g in _data["manual"]:
		if g["id"] == game["id"]:
			return
	_data["manual"].append(game)


static func format_time(total_seconds: float) -> String:
	var mins := int(total_seconds) / 60
	if mins < 1:
		return "ещё не запускалась" if total_seconds <= 0 else "меньше минуты"
	if mins < 60:
		return "%d мин" % mins
	return "%d ч %02d мин" % [mins / 60, mins % 60]
