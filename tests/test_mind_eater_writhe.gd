extends SceneTree

## The Mind Eater's attacks (the designer's tentacle board, 2026-11-04;
## tools/cut_pose_boards.py "mind_eater" actions): Writhe.png is its
## tentacles writhing, eight frames in four facing rows, at its drawn 10 fps
## slowed as every enemy swing is, played in place (no lunge) for its Mind
## Slow and its Manipulate Mind Space.
## Run: godot --headless --path . --script tests/test_mind_eater_writhe.gd

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
	print("=== Mind Eater writhe test ===")
	await _test_figure()
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
	fig.setup("mind_eater")
	await process_frame
	_check(fig._cp_sheets.has("Writhe") and fig._cp_frame_count("Writhe") == 8, "an eight-frame Writhe sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Writhe"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Writhe"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Writhe", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(8):
			worst = maxf(worst, absf(_feet(fig, "Writhe", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "its tentacle tips stay on the idle ground row (off by at most %.0f texels)" % worst)
	for act in ["mind_slow", "mind_cuff"]:
		fig.play_action(act)
		_check(fig._cp_anim == "Writhe" and (fig._fx_tween == null or not fig._fx_tween.is_valid()), "%s: it writhes in place" % act)
		_check(is_equal_approx(fig.last_swing_time, 8.0 / fig._cp_fps["Writhe"]), "%s: the clock waits for it (%.2f s)" % [act, fig.last_swing_time])
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
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.MIND_EATER, main._ground_pos(cell + Vector2i(3, 0)))
	e.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = e._enemy_figure
	e._execute_action("mind_slow", main.player)
	_check(fig._cp_anim == "Writhe", "its Mind Slow writhes (%s)" % fig._cp_anim)
	fig._cp_play("Idle", true)
	e._execute_action("mind_cuff", main.player)
	_check(fig._cp_anim == "Writhe", "its Manipulate Mind Space writhes (%s)" % fig._cp_anim)
	main.enemy_spawner.despawn_enemy(e)
