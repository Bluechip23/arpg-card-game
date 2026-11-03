extends SceneTree

## The Sabertooth's Track (the designer's track board, 2026-11-03;
## tools/cut_pose_boards.py "sabertooth" actions, on its walk sheets):
## Track.png is a paw scraping the ground, scraping deeper, the crouch, the
## deepest ready crouch and the rise — in the four facing rows, in the Idle
## sheet's cells, at its drawn 8 fps slowed as every enemy swing is, played
## in place (no lunge) for its Track.
## Run: godot --headless --path . --script tests/test_sabertooth_track.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
	print("=== Sabertooth track test ===")
	_test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _feet(fig: SpriteEnemyFigure, anim: String, row: int, col: int) -> float:
	var cell: int = fig._cp_cell
	fig._sprite.texture = fig._cp_sheets[anim]
	fig._sprite.region_rect = Rect2(col * cell, row * cell, cell, cell)
	return fig._measure_ground_rows()


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("sabertooth")
	_check(fig._cp_mode and fig._cp_sheets.has("Track"), "the sabertooth has a Track sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Track"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_frame_count("Track") == 5, "Track: paw, scrape, crouch, ready, rise (%d frames)" % fig._cp_frame_count("Track"))
	_check(fig._cp_sheets["Track"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Track", 0.0), 8.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 8 fps, slowed as every enemy swing is")
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(5):
			worst = maxf(worst, absf(_feet(fig, "Track", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "its paws stay on the idle ground row (off by at most %.0f texels)" % worst)
	# The left row is the right one mirrored (the board's side rows both face right).
	var img: Image = fig._cp_sheets["Track"].get_image()
	if img.is_compressed():
		img.decompress()
	var l := img.get_region(Rect2i(0, 2 * cell, cell, cell))
	var r := img.get_region(Rect2i(0, 3 * cell, cell, cell))
	r.flip_x()
	var same := true
	for y in range(0, cell, 7):
		for x in range(0, cell, 7):
			if absf(l.get_pixel(x, y).a - r.get_pixel(x, y).a) > 0.2:
				same = false
	_check(same, "facing left, the right-facing frames mirrored")
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("track")
	_check(fig._cp_anim == "Track" and int(fig._sprite.region_rect.position.y / cell) == 2, "Track facing west: the stalk, the left-facing row")
	_check(is_equal_approx(fig.last_swing_time, 5.0 / fig._cp_fps["Track"]), "and the clock waits for it (%.2f s)" % fig.last_swing_time)
	_check(fig._fx_tween == null or not fig._fx_tween.is_valid(), "played in place: no lunge")
	fig._cp_step(3.5 / fig._cp_fps["Track"])
	_check(fig._cp_anim == "Track" and fig._cp_frame == 3 and fig._rig.position == Vector3.ZERO, "three and a half frames in, crouched lowest, still where it stood (frame %d)" % fig._cp_frame)
	fig._cp_step(2.0)
	_check(fig._cp_anim == "Idle", "risen, it stands idle")
	fig.play_action("bite_and_claw")
	_check(fig._cp_anim != "Track" and fig._fx_tween != null and fig._fx_tween.is_valid(), "its Bite and Claw does not stalk: it lunges")
	fig.free()


func _test_enemy() -> void:
	print("-- The enemy --")
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null and main.enemy_spawner != null, "the dojo is up")
	if main.player == null:
		return
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var t: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.SABERTOOTH, main._ground_pos(cell + Vector2i(3, 0)))
	t.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = t._enemy_figure
	_check(fig != null and fig._cp_sheets.has("Track"), "the sabertooth enemy wears the track sheet")
	var before: int = t.strengthen_stacks
	t._execute_action("track", main.player)
	_check(fig != null and fig._cp_anim == "Track", "its Track plays the stalk (%s)" % (fig._cp_anim if fig else "no figure"))
	_check(t.strengthen_stacks == before + 15, "and marks its prey (+15 Strengthen)")
	main.enemy_spawner.despawn_enemy(t)
