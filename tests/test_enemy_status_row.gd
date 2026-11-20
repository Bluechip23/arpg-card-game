extends SceneTree

## Enemy statuses sit on the health bar (designer, 2026-11-20): the buff /
## debuff badges ride directly on top of each enemy's health bar, centred on
## it; the hover text (health number, name) stacks above the badges while any
## are up and comes back down when they clear. A stack count stays on its
## badge (at ground height, so the crisp-text overlay doesn't lift it off).
## Run: godot --headless --path . --script tests/test_enemy_status_row.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Enemy status row on the health bar ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var foe = main.enemy_spawner.get_living_enemies()[0]

	var bar_z: float = foe._health_bar_bg.position.z
	var hp_z_clear: float = foe.health_label.position.z
	var name_z_clear: float = foe.name_label.position.z

	foe.vulnerable_stacks = 2
	foe.poison_stacks = 4
	foe._update_status_indicators()
	await process_frame

	var row: Node3D = foe._status_container
	_check(row != null and row.get_child_count() >= 2, "the badges are drawn")
	var gap: float = bar_z - row.position.z
	_check(gap > 0.0 and gap <= 0.2, "the badge row sits directly on top of the health bar (%.3f above it)" % gap)
	_check(is_equal_approx(row.position.x, foe._health_bar_bg.position.x), "the row is centred on the bar")
	var name_z: float = foe.name_label.position.z
	var hp_z: float = foe.health_label.position.z
	# The crisp-text overlay draws a label lifted by its height (y x
	# HEIGHT_ON_SCREEN tiles); the badges are meshes, drawn where they stand.
	var hp_screen_z: float = hp_z - foe.health_label.position.y * CameraView.HEIGHT_ON_SCREEN
	var hp_half: float = 0.11   # half the health number's 0.22-tile height
	_check(hp_screen_z + hp_half < row.position.z - Enemy.STATUS_BADGE_RADIUS,
		"the health number shows above the badges, clear of them")
	_check(name_z < hp_z, "the name sits above the health number")
	_check(hp_z < hp_z_clear and name_z < name_z_clear, "the hover text moved up to make room")

	# Stack counts are pinned to their badge.
	var counted := false
	for badge in row.get_children():
		for c in badge.get_children():
			if c is Label3D and c.text == "4":
				counted = true
				_check(is_equal_approx(c.global_position.y, 0.0), "the count sits at ground height (no overlay lift)")
				_check(absf(c.global_position.z - badge.global_position.z) < Enemy.STATUS_BADGE_RADIUS,
					"the count is on its badge")
	_check(counted, "Poison shows its stack count")

	foe.vulnerable_stacks = 0
	foe.poison_stacks = 0
	foe._update_status_indicators()
	await process_frame
	_check(is_equal_approx(foe.health_label.position.z, hp_z_clear)
		and is_equal_approx(foe.name_label.position.z, name_z_clear),
		"cleared: the hover text comes back down onto the bar")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
