extends SceneTree

## The Bugbear's Strike (the designer's strike board, 2026-11-06;
## tools/cut_pose_boards.py "bugbear" actions): Attack.png is the quick jab
## with its free fist, the shift, the mace wound up, the heavy swing, the
## follow-through and the recovery, four facing rows in its Idle's cells.
## Run: godot --headless --path . --script tests/test_bugbear_strike.gd

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
	print("=== Bugbear strike test ===")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("bugbear")
	await process_frame
	_check(fig._cp_sheets.has("Attack") and fig._cp_frame_count("Attack") == 6, "a six-frame Attack sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if fig._cp_sheets.has("Attack"):
		var cell: int = fig._cp_cell
		_check(fig._cp_sheets["Attack"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
		_check(is_equal_approx(fig._cp_fps.get("Attack", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
		var img: Image = fig._cp_sheets["Attack"].get_image()
		if img.is_compressed():
			img.decompress()
		var drawn := true
		for row in range(4):
			for col in range(6):
				if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.4:
					drawn = false
		_check(drawn, "every frame of the four rows holds the bugbear")
		for d in [CharacterAnimator.Direction.SOUTH, CharacterAnimator.Direction.NORTH,
				CharacterAnimator.Direction.WEST, CharacterAnimator.Direction.EAST]:
			fig.set_facing(d)
			fig.play_action("bugbear_strike")
			_check(fig._cp_anim == "Attack" and int(fig._sprite.region_rect.position.y / cell) == fig._cp_row(d), "its Strike plays the strike board facing %s" % CharacterAnimator.Direction.keys()[d])
	fig.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
