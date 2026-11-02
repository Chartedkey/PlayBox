extends Node3D
## Переходы между экранами: коробки приставок → полка → запуск игры.

enum State { BOOT, SETUP, CONSOLES, OPENING, SHELF, LAUNCHING, RUNNING }

const BOX_SPACING := 1.75
const CASE_SPACING := 1.05

var state := State.BOOT
var config: AppConfig
var library: LibraryStore
var studio: Studio
var launcher: EmulatorLauncher
var covers: CoverService
var updater: UpdateChecker

var boxes: Array[ConsoleBox] = []
var selected_box := 0
var active_box: ConsoleBox
var shelf := Node3D.new()
var cases: Array[GameCase] = []
var selected_case := 0
var _shelf_tween: Tween

var ui: CanvasLayer
var fade: ColorRect
var title_label: Label
var info_label: Label
var hint_label: Label
var notice_label: Label
var setup_screen: SetupScreen
var image_dialog: FileDialog
var _image_kind := ""


func _ready() -> void:
	config = AppConfig.new()
	library = LibraryStore.new()
	DirAccess.make_dir_recursive_absolute("user://custom_art")
	studio = Studio.new()
	add_child(studio)
	add_child(shelf)
	launcher = EmulatorLauncher.new()
	launcher.library = library
	launcher.finished.connect(_on_game_finished)
	add_child(launcher)
	covers = CoverService.new()
	covers.cover_ready.connect(_on_cover_ready)
	add_child(covers)
	updater = UpdateChecker.new()
	updater.update_available.connect(_on_update)
	add_child(updater)
	_build_ui()
	_build_boxes()
	updater.check()
	if config.any_console_ready():
		_enter_consoles()
	else:
		open_setup()


# --- Интерфейс ---

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	title_label = _label(54, Vector2(80, 60))
	info_label = _label(28, Vector2(82, 135))
	info_label.modulate = Color(0.78, 0.79, 0.84)
	hint_label = _label(22, Vector2(80, 1000))
	hint_label.modulate = Color(0.6, 0.61, 0.66)
	notice_label = _label(22, Vector2(80, 960))
	notice_label.modulate = Color(0.95, 0.8, 0.35)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.modulate.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_dialog = FileDialog.new()
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.use_native_dialog = true
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Изображения"])
	image_dialog.file_selected.connect(_on_image_chosen)
	add_child(image_dialog)


func _label(size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.position = pos
	ui.add_child(l)
	return l


func open_setup() -> void:
	state = State.SETUP
	_set_texts("", "", "")
	setup_screen = SetupScreen.new()
	setup_screen.config = config
	setup_screen.done.connect(_on_setup_done)
	ui.add_child(setup_screen)


func _on_setup_done() -> void:
	setup_screen.queue_free()
	setup_screen = null
	_clear_cases()
	_enter_consoles()


func _set_texts(title: String, info: String, hint: String) -> void:
	title_label.text = title
	info_label.text = info
	hint_label.text = hint


func _on_update(version: String, _url: String) -> void:
	notice_label.text = "Доступна новая версия %s" % version


# --- Экран приставок ---

func _build_boxes() -> void:
	for i in Consoles.IDS.size():
		var b := ConsoleBox.new()
		add_child(b)
		b.setup(Consoles.IDS[i])
		b.position = Vector3((i - 1) * BOX_SPACING, -0.2, 0)
		boxes.append(b)


func _enter_consoles() -> void:
	state = State.CONSOLES
	active_box = null
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in boxes.size():
		boxes[i].visible = true
		t.tween_property(boxes[i], "position", Vector3((i - 1) * BOX_SPACING, -0.2, 0), 0.6)
		boxes[i].set_open(0.0)
		boxes[i].set_rise(0.0)
	_highlight_box()


func _highlight_box() -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in boxes.size():
		var s := 1.12 if i == selected_box else 0.94
		t.tween_property(boxes[i], "scale", Vector3.ONE * s, 0.25)
	var id: String = Consoles.IDS[selected_box]
	var ready := config.is_console_ready(id)
	_set_texts(Consoles.info(id)["name"], "" if ready else "Эмулятор не указан", "← → выбор    Enter / A открыть    S настройки    Esc / B выход")


func _open_selected_box() -> void:
	var id: String = Consoles.IDS[selected_box]
	if not config.is_console_ready(id):
		open_setup()
		return
	state = State.OPENING
	active_box = boxes[selected_box]
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	for b in boxes:
		if b != active_box:
			t.tween_property(b, "position:y", -6.0, 0.5)
	t.tween_property(active_box, "position", Vector3(0, -0.2, 0), 0.5)
	t.tween_property(active_box, "scale", Vector3.ONE * 1.12, 0.5)
	await t.finished
	var o := create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	o.tween_method(active_box.set_open, 0.0, 1.0, 0.7)
	o.tween_method(active_box.set_rise, 0.0, 1.0, 1.1)
	await o.finished
	await get_tree().create_timer(0.25).timeout
	_enter_shelf()


func _close_box() -> void:
	_clear_cases()
	state = State.OPENING
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(active_box.set_rise, 1.0, 0.0, 0.5)
	t.tween_method(active_box.set_open, 1.0, 0.0, 0.4)
	await t.finished
	_enter_consoles()


# --- Полка ---

func games_for(console: String) -> Array[Dictionary]:
	var out := GameScanner.scan(console, config.games_folder(console))
	var known := {}
	for g in out:
		known[g["id"]] = true
	for g in library.manual_games(console):
		if not known.has(g["id"]):
			out.append(g)
	return out


func _enter_shelf() -> void:
	state = State.SHELF
	var console := active_box.console_id
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	# Коробка уезжает вниз, а приставка остаётся слева от полки.
	var box_target := Vector3(-1.9, -3.4, 0.0)
	var sprite := active_box.console_sprite()
	var console_spot := Vector3(-1.9, -0.05, 0.4)
	t.tween_property(active_box, "position", box_target, 0.8)
	t.tween_property(sprite, "position", (console_spot - box_target) / active_box.scale.x, 0.8)
	t.tween_property(sprite, "scale", Vector3.ONE * 0.8, 0.8)
	_clear_cases()
	selected_case = 0
	var games := games_for(console)
	for i in games.size():
		var c := GameCase.new()
		shelf.add_child(c)
		c.setup(games[i], _cover_for(games[i]), _disc_for(games[i]))
		cases.append(c)
		covers.request_cover(games[i])
	_layout_cases(0.0)
	_refresh_shelf_text()


func _clear_cases() -> void:
	for c in cases:
		c.queue_free()
	cases.clear()


func _case_transform(i: int) -> Dictionary:
	var d := i - selected_case
	var x := 0.45 + d * CASE_SPACING + signf(d) * 0.5
	if d == 0:
		return {"pos": Vector3(0.45, 0.2, 1.0), "rot": deg_to_rad(-6), "scale": 1.25}
	return {"pos": Vector3(x, -0.05, -0.1), "rot": deg_to_rad(-34 if d > 0 else 34), "scale": 1.0}


func _layout_cases(duration: float) -> void:
	if _shelf_tween:
		_shelf_tween.kill()
	if duration > 0.0:
		_shelf_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in cases.size():
		var tf := _case_transform(i)
		var c := cases[i]
		if duration > 0.0:
			_shelf_tween.tween_property(c, "position", tf["pos"], duration)
			_shelf_tween.tween_property(c, "rotation:y", tf["rot"], duration)
			_shelf_tween.tween_property(c, "scale", Vector3.ONE * tf["scale"], duration)
		else:
			c.position = tf["pos"]
			c.rotation.y = tf["rot"]
			c.scale = Vector3.ONE * tf["scale"]


func _refresh_shelf_text() -> void:
	var hint := "← → игра    Enter / A играть    Esc / B назад    C обложка    D диск    N добавить игру"
	if cases.is_empty():
		_set_texts("Игры не найдены", "Проверьте папку в настройках или добавьте игру вручную.", "N добавить игру    S настройки    Esc / B назад")
		return
	var g: Dictionary = cases[selected_case].game
	_set_texts(g["title"], "В игре: %s" % LibraryStore.format_time(library.seconds(g["id"])), hint)


func _cover_for(game: Dictionary) -> Texture2D:
	return _load_first([library.image_override(game["id"], "cover"), CoverService.cache_path(game["id"])])


func _disc_for(game: Dictionary) -> Texture2D:
	return _load_first([library.image_override(game["id"], "disc")])


func _load_first(paths: Array) -> Texture2D:
	for p in paths:
		if p != "" and FileAccess.file_exists(p):
			var t := AssetStore.load_file(p)
			if t:
				return t
	return null


func _on_cover_ready(game_id: String, _path: String) -> void:
	for c in cases:
		if c.game["id"] == game_id:
			c.set_images(_cover_for(c.game), _disc_for(c.game))


func _move_case(delta: int) -> void:
	if cases.is_empty():
		return
	selected_case = clampi(selected_case + delta, 0, cases.size() - 1)
	_layout_cases(0.3)
	_refresh_shelf_text()


func _choose_image(kind: String) -> void:
	if cases.is_empty():
		return
	_image_kind = kind
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Изображения"])
	image_dialog.popup_centered_ratio(0.7)


func _add_manual_game() -> void:
	_image_kind = "game"
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.filters = PackedStringArray(["* ; Все файлы"])
	image_dialog.popup_centered_ratio(0.7)


func _on_image_chosen(p: String) -> void:
	if _image_kind == "game":
		var g := GameScanner.make_game(active_box.console_id, p, p.get_file().get_basename())
		library.add_manual(g)
		library.save()
		_enter_shelf()
		return
	var g: Dictionary = cases[selected_case].game
	var dest := "user://custom_art/%s_%s.%s" % [g["id"], _image_kind, p.get_extension().to_lower()]
	# Копируем, чтобы картинка не пропала вместе с исходным файлом.
	if DirAccess.copy_absolute(p, ProjectSettings.globalize_path(dest)) != OK:
		return
	library.set_image_override(g["id"], _image_kind, dest)
	library.save()
	cases[selected_case].set_images(_cover_for(g), _disc_for(g))


# --- Запуск ---

func _launch_selected() -> void:
	if cases.is_empty():
		return
	state = State.LAUNCHING
	var c := cases[selected_case]
	_set_texts(c.game["title"], "", "")
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(c, "position", Vector3(0.1, 0.2, 1.0), 0.5)
	t.tween_method(c.set_disc_out, 0.0, 1.0, 1.3).set_delay(0.3)
	await t.finished
	# Диск подъезжает к приставке и уменьшается.
	var target := c.to_local(active_box.console_sprite().global_position)
	var m := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	m.tween_property(c.disc, "position", Vector3(target.x, target.y, c.disc.position.z), 0.6)
	m.tween_property(c.disc, "rotation:z", c.disc.rotation.z - TAU, 0.6)
	m.tween_property(c.disc, "scale", Vector3.ONE * 0.45, 0.6)
	await m.finished
	var f := create_tween()
	f.tween_property(fade, "modulate:a", 1.0, 0.45)
	await f.finished
	if launcher.launch(config, c.game) != OK:
		_show_launch_error()
		return
	state = State.RUNNING
	# Оболочка закрывает экран, пока эмулятор загружает игру.
	await get_tree().create_timer(5.0).timeout
	if state == State.RUNNING and launcher.is_running():
		get_window().mode = Window.MODE_MINIMIZED


func _show_launch_error() -> void:
	notice_label.text = "Не удалось запустить эмулятор. Проверьте путь в настройках."
	_return_from_game()


func _on_game_finished(_game: Dictionary, _seconds: float) -> void:
	get_window().mode = Window.MODE_FULLSCREEN
	_return_from_game()


func _return_from_game() -> void:
	state = State.SHELF
	if not cases.is_empty():
		cases[selected_case].reset_disc()
	_layout_cases(0.4)
	_refresh_shelf_text()
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.5)


# --- Управление ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click(event.position)
		return
	if event is InputEventMouseButton and event.pressed and state == State.SHELF:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_case(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move_case(-1)
		return
	match state:
		State.CONSOLES:
			if event.is_action_pressed("ui_left"):
				selected_box = maxi(selected_box - 1, 0)
				_highlight_box()
			elif event.is_action_pressed("ui_right"):
				selected_box = mini(selected_box + 1, boxes.size() - 1)
				_highlight_box()
			elif event.is_action_pressed("ui_accept"):
				_open_selected_box()
			elif _key(event, KEY_S):
				open_setup()
			elif event.is_action_pressed("ui_cancel"):
				get_tree().quit()
		State.SHELF:
			if event.is_action_pressed("ui_left"):
				_move_case(-1)
			elif event.is_action_pressed("ui_right"):
				_move_case(1)
			elif event.is_action_pressed("ui_accept"):
				_launch_selected()
			elif event.is_action_pressed("ui_cancel"):
				_close_box()
			elif _key(event, KEY_C):
				_choose_image("cover")
			elif _key(event, KEY_D):
				_choose_image("disc")
			elif _key(event, KEY_N):
				_add_manual_game()
			elif _key(event, KEY_S):
				open_setup()


func _key(event: InputEvent, code: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == code


func _on_click(pos: Vector2) -> void:
	if state == State.CONSOLES:
		var hit := _nearest(boxes.map(func(b): return b.global_position), pos, 300.0)
		if hit == -1:
			return
		if hit == selected_box:
			_open_selected_box()
		else:
			selected_box = hit
			_highlight_box()
	elif state == State.SHELF:
		var hit := _nearest(cases.map(func(c): return c.global_position), pos, 260.0)
		if hit == -1:
			return
		if hit == selected_case:
			_launch_selected()
		else:
			selected_case = hit
			_layout_cases(0.3)
			_refresh_shelf_text()


func _nearest(points: Array, pos: Vector2, radius: float) -> int:
	var cam := studio.camera
	var best := -1
	var best_d := radius
	for i in points.size():
		var d := cam.unproject_position(points[i]).distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best
