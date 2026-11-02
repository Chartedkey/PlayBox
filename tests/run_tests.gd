extends SceneTree
## Запуск: godot --headless --path . --script res://tests/run_tests.gd

var failures := 0
var checks := 0


func eq(actual, expected, label: String) -> void:
	checks += 1
	if actual != expected:
		failures += 1
		printerr("FAIL %s: ожидалось %s, получено %s" % [label, expected, actual])


func _touch(p: String, text := "") -> void:
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _sfo(pairs: Dictionary) -> PackedByteArray:
	var keys := PackedByteArray()
	var data := PackedByteArray()
	var entries := PackedByteArray()
	for k in pairs:
		var kb: PackedByteArray = String(k).to_utf8_buffer()
		var vb: PackedByteArray = String(pairs[k]).to_utf8_buffer()
		vb.append(0)
		var e := PackedByteArray()
		e.resize(16)
		e.encode_u16(0, keys.size())
		e.encode_u16(2, 0x0204)
		e.encode_u32(4, vb.size())
		e.encode_u32(8, vb.size())
		e.encode_u32(12, data.size())
		entries.append_array(e)
		keys.append_array(kb)
		keys.append(0)
		data.append_array(vb)
	var head := PackedByteArray([0, 0x50, 0x53, 0x46, 1, 1, 0, 0])
	head.resize(20)
	head.encode_u32(8, 20 + entries.size())
	head.encode_u32(12, 20 + entries.size() + keys.size())
	head.encode_u32(16, pairs.size())
	head.append_array(entries)
	head.append_array(keys)
	head.append_array(data)
	return head


func _init() -> void:
	var root := ProjectSettings.globalize_path("user://test_%d" % Time.get_ticks_usec())

	# Названия и регионы
	eq(GameScanner.clean_title("God_of_War (USA) [SLUS-20778]"), "God of War", "clean_title")
	eq(GameScanner.detect_region("Driver (Europe) (En,Fr)"), "Europe", "region")

	# PS1: .bin из .cue и .cue из .m3u не считаются отдельными играми
	var p1 := root.path_join("ps1")
	_touch(p1.path_join("Spider-Man (USA).cue"), "FILE \"Spider-Man (USA).bin\" BINARY\n")
	_touch(p1.path_join("Spider-Man (USA).bin"))
	_touch(p1.path_join("sub/Driver (Europe).chd"))
	_touch(p1.path_join("FF7/FF7.m3u"), "FF7 (Disc 1).cue\nFF7 (Disc 2).cue\n")
	_touch(p1.path_join("FF7/FF7 (Disc 1).cue"), "FILE \"FF7 (Disc 1).bin\" BINARY\n")
	_touch(p1.path_join("FF7/FF7 (Disc 1).bin"))
	_touch(p1.path_join("FF7/FF7 (Disc 2).cue"), "FILE \"FF7 (Disc 2).bin\" BINARY\n")
	_touch(p1.path_join("FF7/FF7 (Disc 2).bin"))
	_touch(p1.path_join("readme.txt"))
	var g1 := GameScanner.scan("ps1", p1)
	eq(g1.map(func(g): return g["title"]), ["Driver", "FF7", "Spider-Man"], "scan ps1")

	# PS2
	var p2 := root.path_join("ps2")
	_touch(p2.path_join("God of War (USA).iso"))
	_touch(p2.path_join("cover.png"))
	var g2 := GameScanner.scan("ps2", p2)
	eq(g2.size(), 1, "scan ps2 count")
	eq(g2[0]["region"], "USA", "scan ps2 region")

	# PS3: диск и цифровая версия с PARAM.SFO, обновления пропускаются
	var p3 := root.path_join("ps3")
	_touch(p3.path_join("Disc/PS3_GAME/USRDIR/EBOOT.BIN"))
	var f := FileAccess.open(p3.path_join("Disc/PS3_GAME/PARAM.SFO"), FileAccess.WRITE)
	f.store_buffer(_sfo({"CATEGORY": "DG", "TITLE": "The Last of Us", "TITLE_ID": "BCES01584"}))
	f.close()
	_touch(p3.path_join("game/NPEB1/USRDIR/EBOOT.BIN"))
	f = FileAccess.open(p3.path_join("game/NPEB1/PARAM.SFO"), FileAccess.WRITE)
	f.store_buffer(_sfo({"CATEGORY": "HG", "TITLE": "Journey"}))
	f.close()
	_touch(p3.path_join("game/BCES1/USRDIR/EBOOT.BIN"))
	f = FileAccess.open(p3.path_join("game/BCES1/PARAM.SFO"), FileAccess.WRITE)
	f.store_buffer(_sfo({"CATEGORY": "GP", "TITLE": "Update"}))
	f.close()
	var g3 := GameScanner.scan("ps3", p3)
	eq(g3.map(func(g): return g["title"]), ["Journey", "The Last of Us"], "scan ps3")
	eq(GameScanner.scan("ps1", root.path_join("нет")), [] as Array[Dictionary], "missing folder")

	# Настройки и аргументы запуска
	var cfg := AppConfig.new(root.path_join("c.cfg"))
	cfg.set_games_folder("ps2", "D:/Игры")
	cfg.save()
	eq(AppConfig.new(root.path_join("c.cfg")).games_folder("ps2"), "D:/Игры", "config persist")
	eq(EmulatorLauncher.build_args(["-batch", "--", "{path}"], "D:/My Game.iso"), PackedStringArray(["-batch", "--", "D:/My Game.iso"]), "args")
	eq(cfg.is_console_ready("ps1"), false, "no emulator")

	# Библиотека и время
	var lib := LibraryStore.new(root.path_join("l.json"))
	lib.add_seconds("a", 3700.0)
	lib.set_image_override("a", "cover", "x.png")
	lib.add_manual(g2[0])
	lib.add_manual(g2[0])
	lib.save()
	var lib2 := LibraryStore.new(root.path_join("l.json"))
	eq(lib2.seconds("a"), 3700.0, "seconds persist")
	eq(lib2.image_override("a", "cover"), "x.png", "override persist")
	eq(lib2.manual_games("ps2").size(), 1, "manual unique")
	eq(LibraryStore.format_time(3700.0), "1 ч 01 мин", "format hours")
	eq(LibraryStore.format_time(0.0), "ещё не запускалась", "format zero")

	# Обложки
	var listing := PackedStringArray(["God of War (Europe)", "God of War (USA)", "God of War II (USA)", "Q_bert (USA)"])
	eq(CoverMatcher.best_match("God_of_War", "God of War", "", listing), "God of War (USA)", "cover prefers USA")
	eq(CoverMatcher.best_match("God of War (Europe)", "God of War", "Europe", listing), "God of War (Europe)", "cover region")
	eq(CoverMatcher.best_match("Unknown", "Unknown", "", listing), "", "cover none")
	eq(CoverMatcher.sanitize("Q*bert: A/B"), "Q_bert_ A_B", "sanitize")
	eq(CoverMatcher.parse_listing('<a href="God%20of%20War%20(USA).png">x</a>'), PackedStringArray(["God of War (USA)"]), "listing")

	# Обновления
	eq(UpdateChecker.is_newer("v0.2.0", "0.1.0"), true, "newer")
	eq(UpdateChecker.is_newer("v0.1.0", "0.1.0"), false, "same")
	eq(UpdateChecker.is_newer("0.1.10", "0.1.9"), true, "numeric")

	print("Проверок: %d, ошибок: %d" % [checks, failures])
	quit(1 if failures > 0 else 0)
