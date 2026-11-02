class_name CoverMatcher
## Подбирает файл обложки libretro-thumbnails по имени игры.

const REGION_ORDER := ["USA", "Europe", "World", "Japan"]


static func sanitize(file_name: String) -> String:
	var out := file_name
	for c in ["&", "*", "/", ":", "`", "<", ">", "?", "\\", "|"]:
		out = out.replace(c, "_")
	return out


static func normalize(text: String) -> String:
	var t := GameScanner.clean_title(text).to_lower().replace("&", "and")
	if t.begins_with("the "):
		t = t.substr(4)
	var re := RegEx.create_from_string("[^\\p{L}\\p{N}]")
	return re.sub(t, "", true)


## listing: имена файлов без расширения.
static func best_match(raw_name: String, title: String, region: String, listing: PackedStringArray) -> String:
	var keys := [normalize(raw_name), normalize(title)]
	var candidates: Array[String] = []
	for item in listing:
		if keys.has(normalize(item)):
			candidates.append(item)
	if candidates.is_empty():
		return ""
	var order: Array = [region] + REGION_ORDER
	for r in order:
		if r == "":
			continue
		for c in candidates:
			if c.findn("(" + r) != -1 or c.findn(", " + r) != -1:
				return c
	return candidates[0]


## Список известных обложек лежит внутри программы, поэтому поиск не зависит от сети.
static func load_index(console: String) -> PackedStringArray:
	var p := "res://data/covers_%s.txt" % console
	if not FileAccess.file_exists(p):
		return PackedStringArray()
	return FileAccess.get_file_as_string(p).split("\n", false)


static func is_png(bytes: PackedByteArray) -> bool:
	return bytes.size() > 8 and bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47
