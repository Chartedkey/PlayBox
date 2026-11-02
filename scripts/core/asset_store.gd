class_name AssetStore
## Загружает локальные картинки. Если файла нет, вызывающий код рисует заглушку.

static var _cache := {}


static func roots() -> PackedStringArray:
	var out := PackedStringArray()
	var env := OS.get_environment("PLAYBOX_ASSETS")
	if env != "":
		out.append(env)
	if OS.has_feature("template"):
		out.append(OS.get_executable_path().get_base_dir().path_join("assets"))
	else:
		out.append(ProjectSettings.globalize_path("res://assets_local"))
	out.append(ProjectSettings.globalize_path("user://assets"))
	return out


static func texture(relative: String) -> Texture2D:
	if _cache.has(relative):
		return _cache[relative]
	var result: Texture2D = null
	for root in roots():
		var p := root.path_join(relative)
		if FileAccess.file_exists(p):
			result = load_file(p)
			break
	_cache[relative] = result
	return result


static func load_file(file_path: String) -> Texture2D:
	var img := Image.new()
	if img.load(file_path) != OK:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
