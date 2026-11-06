extends SceneTree

## The Demon's attack and cuff boards (the designer's, 2026-11-06;
## tools/cut_pose_boards.py "demon_attack" / "demon_cuff"): Attack.png is the
## trident gripped, drawn back and thrust, for its Attack; Cast.png the
## trident raised high, its head lit with red power, for its Cuff. Four
## facing rows each, in its Idle's cells.
## Run: godot --headless --path . --script tests/test_demon_attacks.gd

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
	print("=== Demon attacks test ===")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("demon")
	await process_frame
	var cell: int = fig._cp_cell
	for pair in [["Attack", "demon_attack"], ["Cast", "demon_cuff"]]:
		var sheet: String = pair[0]
		_check(fig._cp_sheets.has(sheet) and fig._cp_frame_count(sheet) == 4, "a four-frame %s sheet (%s)" % [sheet, "smooth" if fig.smooth else "pixel"])
		if not fig._cp_sheets.has(sheet):
			continue
		_check(fig._cp_sheets[sheet].get_height() == 4 * cell, "%s in the four facing rows, the Idle sheet's cells" % sheet)
		_check(is_equal_approx(fig._cp_fps.get(sheet, 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "%s at its drawn 10 fps, slowed" % sheet)
		var img: Image = fig._cp_sheets[sheet].get_image()
		if img.is_compressed():
			img.decompress()
		var drawn := true
		for row in range(4):
			for col in range(4):
				if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.4:
					drawn = false
		_check(drawn, "every %s frame of the four rows holds the demon" % sheet)
		for d in [CharacterAnimator.Direction.SOUTH, CharacterAnimator.Direction.NORTH,
				CharacterAnimator.Direction.WEST, CharacterAnimator.Direction.EAST]:
			fig.set_facing(d)
			fig.play_action(pair[1])
			_check(fig._cp_anim == sheet and int(fig._sprite.region_rect.position.y / cell) == fig._cp_row(d),
					"its %s plays %s facing %s" % [pair[1], sheet, CharacterAnimator.Direction.keys()[d]])
	fig.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
