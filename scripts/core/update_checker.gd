class_name UpdateChecker
extends Node
## Узнаёт о новой версии из релизов GitHub.

signal update_available(version: String, asset_url: String, asset_size: int)

const API := "https://api.github.com/repos/Chartedkey/PlayBox/releases/latest"
const ASSET := "PlayBox-windows.zip"


static func is_newer(latest: String, current: String) -> bool:
	var a := latest.trim_prefix("v").split(".")
	var b := current.trim_prefix("v").split(".")
	for i in max(a.size(), b.size()):
		var x := a[i].to_int() if i < a.size() else 0
		var y := b[i].to_int() if i < b.size() else 0
		if x != y:
			return x > y
	return false


static func find_asset(release: Dictionary) -> Dictionary:
	for a in release.get("assets", []):
		if a.get("name", "") == ASSET:
			return a
	return {}


func check() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(API, ["User-Agent: PlayBox"])
	var res: Array = await http.request_completed
	http.queue_free()
	if res[1] != 200:
		return
	var parsed = JSON.parse_string(res[3].get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var current: String = ProjectSettings.get_setting("application/config/version")
	if is_newer(parsed.get("tag_name", "0"), current):
		var asset := find_asset(parsed)
		if not asset.is_empty():
			update_available.emit(parsed["tag_name"], asset["browser_download_url"], int(asset.get("size", 0)))
