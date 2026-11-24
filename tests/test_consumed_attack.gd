extends SceneTree

## The Consumed's Attack (the designer's attack board, 2026-11-24;
## tools/cut_pose_boards.py "consumed"): Attack.png is an arm lifted and
## reared back as its tongue lolls out, the claw raked down, the arm drawn
## in and the tongue reeled back — sixteen frames, drawn in one view, so the
## sheet holds the two side rows only (left its mirror) and the figure turns
## to a side to play it.
## Run: godot --headless --path . --script tests/test_consumed_attack.gd

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
	print("=== Consumed attack test ===")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("consumed")
	await process_frame
	_check(fig._cp_sheets.has("Attack") and fig._cp_frame_count("Attack") == 16, "a sixteen-frame Attack sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if fig._cp_sheets.has("Attack"):
		var cell: int = fig._cp_cell
		_check(fig._cp_sheets["Attack"].get_height() == 2 * cell and fig._cp_side_only("Attack"), "its two side rows, in the Idle sheet's cells")
		_check(is_equal_approx(fig._cp_fps.get("Attack", 0.0), 20.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 20 fps, slowed as every enemy swing is")
		var img: Image = fig._cp_sheets["Attack"].get_image()
		if img.is_compressed():
			img.decompress()
		var drawn := true
		for row in range(2):
			for col in range(16):
				if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.25:
					drawn = false
		_check(drawn, "every frame of both rows holds the crawler")
		fig.set_facing(CharacterAnimator.Direction.EAST)
		fig.play_action("attack")
		_check(fig._cp_anim == "Attack" and fig._cp_row_now() == 1, "its Attack facing east: the right-facing row")
		_check(fig.attack_time() > 1.0 and fig.attack_time() < 1.6, "the swing runs a little over a second (%.2f s)" % fig.attack_time())
		fig.set_facing(CharacterAnimator.Direction.WEST)
		_check(fig._cp_row_now() == 0, "facing west: the mirrored row")
	fig.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
