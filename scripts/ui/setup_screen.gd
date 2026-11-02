class_name SetupScreen
extends Control
## Экран настройки путей к эмуляторам и играм.

signal done

var config: AppConfig
var _fields := {}
var _dialog: FileDialog
var _pending := Callable()

const SECRETS := [
	["ra_user", "RetroAchievements: логин", false],
	["ra_key", "RetroAchievements: Web API", true],
	["sgdb_key", "SteamGridDB: ключ", true],
	["deepseek_key", "DeepSeek: ключ", true],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.055, 0.07, 0.97)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1100, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "Настройка PlayBox"
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Укажите эмулятор и папку с играми. Консоль без эмулятора можно пропустить."
	hint.add_theme_font_size_override("font_size", 22)
	hint.modulate = Color(0.75, 0.76, 0.8)
	box.add_child(hint)
	for id in Consoles.IDS:
		var info := Consoles.info(id)
		var head := Label.new()
		head.text = "%s (%s)" % [info["name"], info["emulator_hint"]]
		head.add_theme_font_size_override("font_size", 26)
		box.add_child(head)
		_fields[id + "_emu"] = _row(box, "Файл эмулятора", config.emulator(id), func(): _pick_file(id))
		_fields[id + "_dir"] = _row(box, "Папка с играми", config.games_folder(id), func(): _pick_dir(id))
	var keys_head := Label.new()
	keys_head.text = "Необязательно: ключи хранятся только на этом компьютере"
	keys_head.add_theme_font_size_override("font_size", 26)
	box.add_child(keys_head)
	for k in SECRETS:
		var e := _row(box, k[1], config.secret(k[0]), Callable())
		e.secret = k[2]
		_fields["key_" + k[0]] = e
	var save := Button.new()
	save.text = "Готово"
	save.custom_minimum_size = Vector2(240, 60)
	save.add_theme_font_size_override("font_size", 26)
	save.pressed.connect(_on_save)
	box.add_child(save)
	save.grab_focus()
	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.file_selected.connect(_on_chosen)
	_dialog.dir_selected.connect(_on_chosen)
	add_child(_dialog)


func _row(parent: Control, label: String, value: String, on_browse: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(330, 0)
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.add_theme_font_size_override("font_size", 20)
	row.add_child(e)
	if on_browse.is_valid():
		var b := Button.new()
		b.text = "Обзор"
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(on_browse)
		row.add_child(b)
	parent.add_child(row)
	return e


func _pick_file(id: String) -> void:
	_pending = func(p): _fields[id + "_emu"].text = p
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.filters = PackedStringArray(["*.exe ; Программы", "* ; Все файлы"])
	_dialog.popup_centered_ratio(0.7)


func _pick_dir(id: String) -> void:
	_pending = func(p): _fields[id + "_dir"].text = p
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dialog.popup_centered_ratio(0.7)


func _on_chosen(p: String) -> void:
	if _pending.is_valid():
		_pending.call(p)


func _on_save() -> void:
	for id in Consoles.IDS:
		config.set_emulator(id, _fields[id + "_emu"].text.strip_edges())
		config.set_games_folder(id, _fields[id + "_dir"].text.strip_edges())
	for k in SECRETS:
		config.set_secret(k[0], _fields["key_" + k[0]].text.strip_edges())
	config.save()
	done.emit()
