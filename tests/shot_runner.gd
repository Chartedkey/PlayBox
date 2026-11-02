extends SceneTree
## Снимает ключевые экраны. Нужны переменные PLAYBOX_SHOT_DIR и PLAYBOX_FAKE.

var out: String
var fake: String
var main


func shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name_ + ".png"))
	print("shot ", name_)


func wait(sec: float) -> void:
	await create_timer(sec).timeout


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	out = OS.get_environment("PLAYBOX_SHOT_DIR")
	fake = OS.get_environment("PLAYBOX_FAKE")
	var cfg := AppConfig.new()
	for id in Consoles.IDS:
		cfg.set_emulator(id, fake.path_join("emu.sh"))
		cfg.set_games_folder(id, fake.path_join(id))
	cfg.save()
	DirAccess.make_dir_recursive_absolute("user://covers")
	var covers := {"ps2/God of War (USA).iso": "gow.png", "ps2/Kingdom Hearts II (Europe).iso": "kh.png", "ps2/Haunting Ground (Europe).iso": "hg.png"}
	for k in covers:
		var id: String = fake.path_join(k).md5_text()
		DirAccess.copy_absolute(fake.path_join(covers[k]), ProjectSettings.globalize_path(CoverService.cache_path(id)))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(1.0)
	await shot("1_consoles")
	main.selected_box = 1
	main._highlight_box()
	await wait(0.4)
	main._open_selected_box()
	await wait(1.25)
	await shot("2_opening")
	await wait(0.9)
	await shot("3_rising")
	await wait(2.2)
	await shot("4_shelf")
	main._move_case(1)
	await wait(0.5)
	await shot("5_shelf_next")
	main._launch_selected()
	await wait(1.3)
	await shot("6_disc")
	await wait(1.0)
	print("state ", main.state)
	await wait(4.5)
	print("after run: state ", main.state, " seconds ", main.library.seconds(main.cases[main.selected_case].game["id"]))
	await shot("7_back")
	main._open_advice()
	await wait(0.3)
	await shot("9_advice")
	main._close_panel()
	main.open_setup()
	await wait(0.4)
	await shot("8_setup")
	quit(0)
