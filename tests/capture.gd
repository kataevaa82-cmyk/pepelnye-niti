extends SceneTree
## Native Compatibility render captures from CI, kept separate from Web QA.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3.0).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + "build/qa"))
	await _capture("menu")
	game._open_help()
	await _capture("help")
	game._start_run(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(2.0).timeout
	await _capture("workshop")
	game.player.position = Vector3(-6.9, 0.15, 7.2)
	game.player.restore_view(0.9, -0.08)
	await _capture("loom")
	game.player.position = Vector3(0, 0.15, 9.0)
	game.player.restore_view(0, 0)
	game._pause()
	await _capture("pause")
	paused = false
	game._stop_audio()
	await create_timer(0.5).timeout
	game.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit")

func _capture(label: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + "build/qa/" + label + ".png"))
	if result != OK:
		push_error("Could not capture " + label)
		quit(1)
	print("RENDER CAPTURE: ", label, " / draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
