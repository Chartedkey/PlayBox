extends SceneTree
## Проверяет настоящую загрузку обложек из обоих источников.

func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	var svc := CoverService.new()
	root.add_child(svc)
	var failed := 0
	for url in CoverService.urls_for("ps2", "God of War (USA)"):
		var b: PackedByteArray = await svc._fetch(url)
		var ok := CoverMatcher.is_png(b)
		print("%s %d байт %s" % ["OK" if ok else "FAIL", b.size(), url])
		if not ok:
			failed += 1
	quit(1 if failed > 0 else 0)
