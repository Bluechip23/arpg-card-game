extends SceneTree

## The Succubus's Mana Drain (the designer's drain board, 2026-11-04;
## tools/cut_pose_boards.py "succubus" actions and "succubus_orb"): Cast.png
## is her reaching out, curling her fingers, beckoning and catching the ball
## — four facing rows, at her drawn 10 fps slowed as every enemy swing is.
## The ball of mana (Orb.png) starts at her victim and is drawn back to her
## hand, arriving on the catch frame. Her Damaging Snap plays Attack.png
## (her finger snap) and sends a spinning scythe (Scythe.png) at her victim.
## Run: godot --headless --path . --script tests/test_succubus_drain.gd

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
	print("=== Succubus drain test ===")
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
	fig.setup("succubus")
	await process_frame
	_check(fig._cp_sheets.has("Cast") and fig._cp_frame_count("Cast") == 7, "a seven-frame Cast sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Cast"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Cast"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Cast", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at her drawn 10 fps, slowed as every enemy swing is")
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(7):
			worst = maxf(worst, absf(_feet(fig, "Cast", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "her heels stay on the idle ground row (off by at most %.0f texels)" % worst)
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("mana_drain")
	_check(fig._cp_anim == "Cast" and int(fig._sprite.region_rect.position.y / cell) == 2, "Mana Drain facing west: the drain, the left-facing row")
	fig.play_action("damaging_snap")
	_check(fig._cp_anim == "Attack" and fig._cp_frame_count("Attack") == 7, "her Damaging Snap plays the snap (succubus_snap_board.webp): seven frames")
	_check(fig._cp_sheets["Attack"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	var sworst := 0.0
	for row in range(4):
		var sfeet: float = _feet(fig, "Idle", row, 0)
		for col in range(7):
			sworst = maxf(sworst, absf(_feet(fig, "Attack", row, col) - sfeet))
	_check(sworst <= 3.0 * (2.0 if fig.smooth else 1.0), "her heels stay on the ground row through the snap (off by at most %.0f texels)" % sworst)
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
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.SUCCUBUS, main._ground_pos(cell + Vector2i(3, 0)))
	e.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = e._enemy_figure
	var st = main.player.get_stats()
	st.current_mana = 40.0
	var holds: Array = []
	e.swing_started.connect(func(_x, s): holds.append(s))
	e._execute_action("mana_drain", main.player)
	_check(fig._cp_anim == "Cast", "her Mana Drain plays the drain (%s)" % fig._cp_anim)
	_check(is_equal_approx(st.current_mana, 30.0), "and drains 10 mana (%.0f left)" % st.current_mana)
	var orbs := _thrown(e.get_parent())
	_check(orbs.size() == 1, "a ball of mana is drawn")
	if orbs.size() == 1:
		var o: ThrownSprite = orbs[0]
		var p: Vector3 = main.player.global_position
		_check(Vector2(o._from.x - p.x, o._from.z - p.z).length() < 0.01, "it starts at her victim")
		_check(Vector2(o._to.x - e.global_position.x, o._to.z - e.global_position.z).length() < 0.5, "and ends at her hand")
		var fps: float = fig._cp_fps["Cast"]
		_check(is_equal_approx(o._delay, 3.0 / fps), "it leaves her victim as she curls her fingers (%.2f s)" % o._delay)
		_check(is_equal_approx(o.total_time(), 6.0 / fps), "and reaches her hand on the catch frame (%.2f s)" % o.total_time())
	_check(holds.size() >= 2, "the clock waits for it (%s s)" % str(holds))
	# Her Damaging Snap: the snap, and a scythe spinning at her victim.
	var before := _thrown(e.get_parent()).size()
	e._execute_action("damaging_snap", main.player)
	_check(fig._cp_anim == "Attack", "her Damaging Snap plays the snap (%s)" % fig._cp_anim)
	var all := _thrown(e.get_parent())
	_check(all.size() == before + 1, "and sends a scythe")
	if all.size() == before + 1:
		var sc: ThrownSprite = all.back()
		_check(sc._frames == 7 and is_equal_approx(sc._delay, 6.0 / fig._cp_fps["Attack"]), "spinning through seven frames, leaving her fingers on the snap (%.2f s)" % sc._delay)
		_check(Vector2(sc._to.x - main.player.global_position.x, sc._to.z - main.player.global_position.z).length() < 0.01, "at her victim")
	main.enemy_spawner.despawn_enemy(e)
