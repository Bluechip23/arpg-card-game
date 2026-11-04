extends SceneTree

## The camera rides with the player every frame and keeps him where the
## player put him on screen (designer, 2026-10-31): a step never resets the
## scroll, so centred stays centred.
## Run: godot --headless --path . --script tests/test_camera_follow.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Camera follow ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(8):
		await process_frame
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var p = main.player
	main._pan_camera(Vector3(-2, 0, 1))   # the player scrolls the view
	var pan: Vector3 = main._camera_pan
	await process_frame
	var start: Vector3 = main._camera_focus
	p.position += Vector3(1.5, 0, 0)       # he walks
	p.target_position = p.position
	await process_frame
	await process_frame   # (process_frame fires before the nodes' _process)
	_check(main._camera_pan == pan, "a step keeps the player's scroll")
	_check(absf(main._camera_focus.x - start.x - 1.5) < 0.05 and (main._camera_focus - p.position).is_equal_approx(Vector3(2, 0, 0) + Vector3(0, main._camera_focus.y - p.position.y, 0)),
		"the view rides with him, every frame (%s)" % (main._camera_focus - start))
	main._on_player_tile_reached(p)
	await process_frame
	_check(main._camera_pan == pan, "...even once the step lands")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
