extends SceneTree
## Engine tests run in CI with ASH_TESTING=1; no player saves are touched.

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("TEST FAILED: " + message)

func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	check(main.level.structures.size() == 10, "ten stable destructible groups")
	check(main.level.cores.size() == 3, "three cores")
	check(main.level.thread_nodes.size() == 3, "three restorative thread nodes")
	check(not main.running, "title screen is paused")
	main._start_run(false)
	await physics_frame
	check(main.running and not main.alarm, "preparation has no countdown")
	var container := Node3D.new()
	root.add_child(container)
	var grid := VoxelStructure.new()
	container.add_child(grid)
	grid.build("test", Vector3i(1, 3, 1), Color.WHITE, 1)
	var count := grid.damage(Vector3(0, VoxelStructure.CELL * 0.5, 0), 0.2, 1)
	check(count == 1, "one directly struck block")
	check(grid.cells.is_empty(), "unsupported upper blocks collapse")
	check(grid.snapshot().size() == 3, "collapse is included in saved state")
	var restored := VoxelStructure.new()
	container.add_child(restored)
	restored.build("test", Vector3i(1, 3, 1), Color.WHITE, 1, grid.snapshot())
	check(restored.cells.is_empty(), "removed blocks do not respawn on load")
	var metal := VoxelStructure.new()
	container.add_child(metal)
	metal.build("metal", Vector3i.ONE, Color.GRAY, 2)
	metal.damage(Vector3(0, VoxelStructure.CELL * 0.5, 0), 0.2, 1)
	check(metal.cells.size() == 1, "metal survives first hammer strike")
	metal.damage(Vector3(0, VoxelStructure.CELL * 0.5, 0), 0.2, 1)
	check(metal.cells.is_empty(), "metal breaks on second strike")
	# Verify core occlusion before breaking the front of the west room.
	var original_core_position: Vector3 = main.level.cores[0].position
	main.level.cores[0].position.z = -1.0
	main.player.position = Vector3(-8, 0.1, 0.8)
	main.player.restore_view(0, 0)
	await physics_frame
	check(main.player.camera.global_position.distance_to(main.level.cores[0].global_position) < 2.6, "occlusion test is inside interaction range")
	check(main._near_core() == -1, "a core cannot be collected through a wall")
	main.level.cores[0].position = original_core_position
	for i in range(3):
		var core: Node3D = main.level.cores[i]
		main.player.position = core.global_position + Vector3(0, -1.1, 1.1)
		main.player.restore_view(0, 0)
		await physics_frame
		main._interact()
		check(main.collected.has(i), "core %d is collectible inside its room" % i)
	check(main.alarm, "first stolen core starts the alarm")
	main.charges = 1
	main.health = 50.0
	main.player.position = main.level.thread_nodes[0].global_position + Vector3(0, -0.5, 1.1)
	main.player.restore_view(0, 0)
	await physics_frame
	main._interact()
	check(main.used_threads.has(0), "thread node can be woven")
	check(main.charges == 3 and main.health == 75.0, "thread node restores resources")
	main._save_now()
	check(main._saved["session"]["collected"].size() == 3, "save has all collected cores")
	check(main._saved["session"]["used_threads"].size() == 1, "save has woven thread nodes")
	main._pause()
	check(not main.running and paused, "pause stops the scene tree")
	main._start_run(false, true)
	check(main.collected.size() == 3 and main.alarm, "resume restores cores and alarm")
	check(main.used_threads.size() == 1 and not main.level.thread_nodes[0].visible, "resume restores woven thread nodes")
	main.player.position = main.level.exit_at + Vector3(0, 0.2, 0)
	main._interact()
	check(main._menu_mode == "win", "all three cores at exit wins")
	check(main._saved["session"].is_empty(), "finished run cannot resume")
	main._start_run(true)
	check(main.sandbox and not main.alarm, "sandbox has no alarm")
	main._start_run(false)
	main.alarm = true
	main.seconds = 0.01
	main._process(0.1)
	check(main._menu_mode == "lose", "countdown expiration loses")
	paused = false
	main._stop_audio()
	# Let the audio mixer release stopped WAV playbacks before destroying nodes.
	await create_timer(0.2).timeout
	main.queue_free()
	container.queue_free()
	await process_frame
	await process_frame
	# Release this coroutine's locals before shutting down the SceneTree.
	call_deferred("_exit_test")

func _exit_test() -> void:
	print("GODOT SMOKE: " + ("FAILED" if failed else "PASSED"))
	quit(1 if failed else 0)
