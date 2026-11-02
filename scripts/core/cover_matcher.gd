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


static func parse_listing(html: String) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("href=\"([^\"]+)\\.png\"")
	for m in re.search_all(html):
		out.append(m.get_string(1).uri_decode())
	return out
