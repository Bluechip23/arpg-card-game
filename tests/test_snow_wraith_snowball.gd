extends SceneTree

## The Snow Wraith's snowball (the designer's snowball board, 2026-11-03;
## tools/cut_pose_boards.py "actions"): Throw.png is the frost gathering at
## her hand, the snowball forming, raised, thrown and the follow-through —
## in the four facing rows, in the Idle sheet's cells, at her drawn 8 fps
## slowed as every enemy swing is. Her Snowball plays it; her Ice Blast
## keeps its lunge.
## Run: godot --headless --path . --script tests/test_snow_wraith_snowball.gd

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
	print("=== Snow Wraith snowball test ===")
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
	fig.setup("snow_wraith")
	_check(fig._cp_mode and fig._cp_sheets.has("Throw"), "the wraith has a Throw sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Throw"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_frame_count("Throw") == 5, "Throw: gather, form, raise, throw, follow-through (%d frames)" % fig._cp_frame_count("Throw"))
	_check(fig._cp_sheets["Throw"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Throw", 0.0), 8.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at her drawn 8 fps, slowed as every enemy swing is")
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(5):
			worst = maxf(worst, absf(_feet(fig, "Throw", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "the throw frames' smoke trails end on the idle ground row (off by at most %.0f texels)" % worst)
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("snowball")
	_check(fig._cp_anim == "Throw" and int(fig._sprite.region_rect.position.y / cell) == 2, "Snowball facing west: the throw, the left-facing row")
	_check(is_equal_approx(fig.last_swing_time, 5.0 / fig._cp_fps["Throw"]), "and the clock waits for the throw (%.2f s)" % fig.last_swing_time)
	fig._cp_step(3.5 / fig._cp_fps["Throw"])
	_check(fig._cp_anim == "Throw" and fig._cp_frame == 3, "three and a half frames in, the snowball leaves her hand (frame %d)" % fig._cp_frame)
	fig._cp_step(2.0)
	_check(fig._cp_anim == "Idle", "the throw done, she hovers idle")
	fig.play_action("ice_blast")
	_check(fig._cp_anim != "Throw" and fig.last_swing_time > 0.0, "her Ice Blast does not play the throw: it lunges")
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
	var w: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.SNOW_WRAITH, main._ground_pos(cell + Vector2i(2, 0)))
	w.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = w._enemy_figure
	_check(fig != null and fig._cp_sheets.has("Throw"), "the wraith enemy wears the throw sheet")
	w._execute_action("snowball", main.player)
	_check(fig != null and fig._cp_anim == "Throw", "the Wraith's Snowball plays the throw (%s)" % (fig._cp_anim if fig else "no figure"))
	main.enemy_spawner.despawn_enemy(w)
