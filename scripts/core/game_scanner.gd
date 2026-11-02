class_name GameScanner
## Находит игры в папках. Логика не зависит от графики и покрыта тестами.

const MAX_DEPTH := 5
const REGION_WORDS := ["USA", "Europe", "Japan", "World", "Germany", "France", "Spain", "Italy", "Russia", "Korea", "Asia", "Australia"]
const SKIP_PS3_CATEGORIES := ["GD", "GP", "AT", "AV", "IP", "CB", "SD"]


static func scan(console: String, folder: String) -> Array[Dictionary]:
	if folder == "" or not DirAccess.dir_exists_absolute(folder):
		return []
	if console == "ps3":
		return _scan_ps3(folder)
	return _scan_files(console, folder)


static func make_game(console: String, file_path: String, raw_name: String, title := "") -> Dictionary:
	return {
		"id": file_path.md5_text(),
		"console": console,
		"path": file_path,
		"raw_name": raw_name,
		"title": title if title != "" else clean_title(raw_name),
		"region": detect_region(raw_name),
	}


## «God_of_War (USA) [SLUS-20778]» → «God of War»
static func clean_title(raw: String) -> String:
	var re := RegEx.create_from_string("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]")
	var t := re.sub(raw, "", true).replace("_", " ").strip_edges()
	return t if t != "" else raw


static func detect_region(raw: String) -> String:
	for w in REGION_WORDS:
		if raw.findn("(" + w) != -1 or raw.findn(", " + w) != -1:
			return w
	return ""


static func _scan_files(console: String, folder: String) -> Array[Dictionary]:
	var exts: Array = Consoles.info(console)["extensions"]
	var found: Array[String] = []
	_collect(folder, exts, found, 0)
	# Файлы, на которые ссылаются .m3u и .cue, отдельными играми не считаем.
	var referenced := {}
	for f in found:
		var ext := f.get_extension().to_lower()
		if ext == "m3u" or ext == "cue":
			for r in _references(f):
				referenced[r.simplify_path().to_lower()] = true
	var games: Array[Dictionary] = []
	for f in found:
		if referenced.has(f.simplify_path().to_lower()):
			continue
		games.append(make_game(console, f, f.get_file().get_basename()))
	games.sort_custom(func(a, b): return a["title"].naturalnocasecmp_to(b["title"]) < 0)
	return games


static func _collect(dir_path: String, exts: Array, out: Array[String], depth: int) -> void:
	var d := DirAccess.open(dir_path)
	if d == null or depth > MAX_DEPTH:
		return
	for f in d.get_files():
		if exts.has(f.get_extension().to_lower()):
			out.append(dir_path.path_join(f))
	for sub in d.get_directories():
		_collect(dir_path.path_join(sub), exts, out, depth + 1)


static func _references(list_file: String) -> Array[String]:
	var out: Array[String] = []
	var text := FileAccess.get_file_as_string(list_file)
	var base := list_file.get_base_dir()
	var is_cue := list_file.get_extension().to_lower() == "cue"
	for line in text.split("\n"):
		var l := line.strip_edges()
		if is_cue:
			if not l.to_upper().begins_with("FILE"):
				continue
			var parts := l.split("\"")
			if parts.size() >= 2:
				out.append(base.path_join(parts[1]))
		elif l != "" and not l.begins_with("#"):
			out.append(base.path_join(l))
	return out


static func _scan_ps3(folder: String) -> Array[Dictionary]:
	var games: Array[Dictionary] = []
	_scan_ps3_dir(folder, games, 0)
	games.sort_custom(func(a, b): return a["title"].naturalnocasecmp_to(b["title"]) < 0)
	return games


static func _scan_ps3_dir(dir_path: String, out: Array[Dictionary], depth: int) -> void:
	if depth > MAX_DEPTH:
		return
	var disc_eboot := dir_path.path_join("PS3_GAME/USRDIR/EBOOT.BIN")
	var digital_eboot := dir_path.path_join("USRDIR/EBOOT.BIN")
	if FileAccess.file_exists(disc_eboot):
		var sfo := SfoParser.parse_file(dir_path.path_join("PS3_GAME/PARAM.SFO"))
		out.append(make_game("ps3", disc_eboot, dir_path.get_file(), sfo.get("TITLE", "")))
		return
	if FileAccess.file_exists(digital_eboot):
		var sfo := SfoParser.parse_file(dir_path.path_join("PARAM.SFO"))
		if not SKIP_PS3_CATEGORIES.has(sfo.get("CATEGORY", "")):
			out.append(make_game("ps3", digital_eboot, dir_path.get_file(), sfo.get("TITLE", "")))
		return
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		_scan_ps3_dir(dir_path.path_join(sub), out, depth + 1)
