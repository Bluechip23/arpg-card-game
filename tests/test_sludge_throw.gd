extends SceneTree

## The Sludge Being's Spit (the designer's throw board, 2026-11-04;
## tools/cut_pose_boards.py "sludge" actions and "sludge_ball"): Throw.png is
## the ball of slime drawn back, coiled, swung and hurled, the arm lowered
## and at rest — four facing rows, at its drawn 10 fps slowed as every enemy
## swing is. Its Spit plays it, and the ball (Ball.png) flies to its prey.
## Its melee plays Attack.png (the designer's hammer board).
## Run: godot --headless --path . --script tests/test_sludge_throw.gd

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
	print("=== Sludge throw test ===")
	await _test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _feet(fig: SpriteEnemyFigure, anim: String, row: int, col: int) -> float:
	var cell: int = fig._cp_cell
	fig._sprite.texture = fig._cp_sheets[anim]
	fig._sprite.region_rect = Rect2(col * cell, row * cell, cell, cell)
	return fig._measure_ground_rows()


func _thrown(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is ThrownSprite:
			out.append(c)
	return out


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("sludge")
	await process_frame
	_check(fig._cp_sheets.has("Throw") and fig._cp_frame_count("Throw") == 7, "a seven-frame Throw sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Throw"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Throw"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Throw", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(7):
			worst = maxf(worst, absf(_feet(fig, "Throw", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "its puddle stays on the idle ground row (off by at most %.0f texels)" % worst)
	# Its melee (sludge_hammer_board.webp): Attack.png, the ball morphing
	# into a hammer of slime, raised, swung and smashed down.
	_check(fig._cp_sheets.has("Attack") and fig._cp_frame_count("Attack") == 7, "a seven-frame hammer Attack sheet")
	_check(fig._cp_sheets["Attack"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Attack", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
	var hworst := 0.0
	for row in range(4):
		var hfeet: float = _feet(fig, "Idle", row, 0)
		for col in range(7):
			hworst = maxf(hworst, absf(_feet(fig, "Attack", row, col) - hfeet))
	_check(hworst <= 3.0 * (2.0 if fig.smooth else 1.0), "its puddle stays on the ground row through the smash (off by at most %.0f texels)" % hworst)
	fig.play_action("sludge_melee")
	_check(fig._cp_anim == "Attack", "its melee plays the hammer (%s)" % fig._cp_anim)
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("sludge_spit")
	_check(fig._cp_anim == "Throw" and int(fig._sprite.region_rect.position.y / cell) == 2, "Spit facing west: the throw, the left-facing row")
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
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.SLUDGE, main._ground_pos(cell + Vector2i(4, 0)))
	e.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = e._enemy_figure
	var holds: Array = []
	e.swing_started.connect(func(_x, s): holds.append(s))
	var st = main.player.get_stats()
	var before: int = int(st.current_health) + int(st.current_armor)
	e._execute_action("sludge_spit", main.player)
	_check(fig._cp_anim == "Throw", "its Spit plays the throw (%s)" % fig._cp_anim)
	_check(before - (int(st.current_health) + int(st.current_armor)) > 0, "and it struck")
	var balls := _thrown(e.get_parent())
	_check(balls.size() == 1, "a ball of slime flies at the player")
	var release: float = 3.0 / fig._cp_fps["Throw"]
	_check(balls.size() == 1 and is_equal_approx(balls[0]._delay, release), "it leaves its hand on the throw (%.2f s)" % (balls[0]._delay if balls.size() else -1.0))
	_check(balls.size() == 1 and balls[0]._sprite.flip_h, "flying left, mirrored")
	_check(holds.size() >= 2 and holds.max() > release, "the clock waits for it (%s s)" % str(holds))
	e.position = main._ground_pos(cell + Vector2i(1, 0))
	await _settle(2)
	var hp1: int = int(st.current_health) + int(st.current_armor)
	e._execute_action("sludge_melee", main.player)
	_check(fig._cp_anim == "Attack", "its melee swings the hammer (%s)" % fig._cp_anim)
	_check(hp1 - (int(st.current_health) + int(st.current_armor)) > 0, "and it struck")
	main.enemy_spawner.despawn_enemy(e)
