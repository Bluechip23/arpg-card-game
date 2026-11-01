extends SceneTree

## The Mini Bear's attack (the designer's attack board, 2026-11-01;
## tools/cut_pose_boards.py "actions"): Attack.png is the swipe and the
## pratfall — raise, swipe, follow-through, settle, flat, roll, rise — in
## the four facing rows, in the Idle sheet's cells, at 8 fps (designer: a
## cute little bear that goes over trying). The Mini Bear's Attack plays it.
## Run: godot --headless --path . --script tests/test_mini_bear_attack.gd

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
	print("=== Mini Bear attack test ===")
	_test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


## Rows from the top of the cell down through the lowest opaque row of a
## frame of `anim`: where its feet stand.
func _feet(fig: SpriteEnemyFigure, anim: String, row: int, col: int) -> float:
	var cell: int = fig._cp_cell
	fig._sprite.texture = fig._cp_sheets[anim]
	fig._sprite.region_rect = Rect2(col * cell, row * cell, cell, cell)
	return fig._measure_ground_rows()


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("mini_bear")
	_check(fig._cp_mode and fig._cp_sheets.has("Attack"), "the mini bear has an Attack sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Attack"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	var tex: Texture2D = fig._cp_sheets["Attack"]
	_check(fig._cp_frame_count("Attack") == 7, "Attack: raise, swipe, follow-through, settle, flat, roll, rise (%d frames)" % fig._cp_frame_count("Attack"))
	_check(tex.get_height() == 4 * cell, "Attack holds the four facing rows in the Idle sheet's %d-px cells (%dx%d)" % [cell, tex.get_width(), tex.get_height()])
	_check(fig._cp_fps.get("Attack", 0.0) == 8.0, "the pratfall plays at 8 fps")
	# The feet of every attack frame stand on the Idle ground row of its facing.
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(7):
			worst = maxf(worst, absf(_feet(fig, "Attack", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "the attack frames' feet sit on the idle ground row (off by at most %.0f texels)" % worst)
	# Every frame is drawn solid.
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var thin := 0
	for row in range(4):
		for col in range(7):
			var used := img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect()
			var solid := 0
			var any := 0
			var frame := img.get_region(Rect2i(col * cell + used.position.x, row * cell + used.position.y, used.size.x, used.size.y))
			for y in range(frame.get_height()):
				for x in range(frame.get_width()):
					var a := frame.get_pixel(x, y).a
					if a > 0.05:
						any += 1
						if a > 0.95:
							solid += 1
			if any == 0 or solid < any * 0.6:
				thin += 1
	_check(thin == 0, "every attack frame is mostly solid (%d thin frames)" % thin)
	# Attack plays the sheet; each facing its row.
	fig.set_facing(CharacterAnimator.Direction.SOUTH)
	fig.play_action("mini_bear_attack")
	_check(fig._cp_anim == "Attack" and int(fig._sprite.region_rect.position.y / cell) == 0, "Attack facing south: Attack, the front row")
	fig.set_facing(CharacterAnimator.Direction.EAST)
	_check(int(fig._sprite.region_rect.position.y / cell) == 3, "turned east mid-swipe: the right-facing row")
	fig._cp_step(2.5 / 8.0)
	_check(fig._cp_anim == "Attack" and fig._cp_frame == 2, "two and a half frames in, the paw comes down (frame %d)" % fig._cp_frame)
	fig._cp_step(3.0 / 8.0)
	_check(fig._cp_anim == "Attack" and fig._cp_frame == 5, "five and a half frames in, the bear is on its back (frame %d)" % fig._cp_frame)
	fig._cp_step(1.0)
	_check(fig._cp_anim == "Idle", "back on its feet, the bear stands idle")
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
	main.player.get_stats().current_health = 500
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var r: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.MINI_BEAR, main._ground_pos(cell + Vector2i(1, 0)))
	r.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = r._enemy_figure
	_check(fig != null and fig._cp_sheets.has("Attack"), "the mini bear enemy wears the attack sheet")
	var st = main.player.get_stats()
	var before: int = int(st.current_health) + int(st.current_armor)
	r._execute_action("mini_bear_attack", main.player)
	_check(fig != null and fig._cp_anim == "Attack", "the Mini Bear's attack plays the swipe and the pratfall (%s)" % (fig._cp_anim if fig else "no figure"))
	_check(before - (int(st.current_health) + int(st.current_armor)) > 0, "and it struck")
	main.enemy_spawner.despawn_enemy(r)
