extends SceneTree

## The Weregoat's Charge (the designer's charge board, 2026-11-06;
## tools/cut_pose_boards.py "weregoat_charge"): Charge.png is three stamps of
## a hoof, the crouch and the run in a boil of dust, four facing rows, packed
## beside its walk-sheet Idle. Its Charge plays it facing its lane, lands at
## once on the board, and the figure is carried down the lane through the
## run frames (leap_from). Rooted, the charge is called off and it walks.
## Run: godot --headless --path . --script tests/test_weregoat_charge.gd

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
	print("=== Weregoat charge test ===")
	await _test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("weregoat")
	await process_frame
	_check(fig._cp_sheets.has("Charge") and fig._cp_frame_count("Charge") == 7, "a seven-frame Charge sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Charge"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Charge"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Charge", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
	# Every frame of every row is drawn (nothing lost to the split).
	var img: Image = fig._cp_sheets["Charge"].get_image()
	if img.is_compressed():
		img.decompress()
	var drawn := true
	for row in range(4):
		for col in range(7):
			if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.4:
				drawn = false
	_check(drawn, "every frame of the four rows holds the goat")
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("goat_charge")
	_check(fig._cp_anim == "Charge" and int(fig._sprite.region_rect.position.y / cell) == 2, "Charge facing west: the left-facing row")
	_check(fig._fx_tween == null or not fig._fx_tween.is_valid(), "no lunge: the run carries it")
	# Its Hoof Punch (the designer's punch board, 2026-11-06): Attack.png.
	_check(fig._cp_sheets.has("Attack") and fig._cp_frame_count("Attack") == 6, "a six-frame Hoof Punch sheet")
	_check(is_equal_approx(fig._cp_fps.get("Attack", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "the punch at its drawn 10 fps, slowed")
	var pimg: Image = fig._cp_sheets["Attack"].get_image()
	if pimg.is_compressed():
		pimg.decompress()
	var pdrawn := true
	for row in range(4):
		for col in range(6):
			if pimg.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.4:
				pdrawn = false
	_check(pdrawn, "every punch frame of the four rows holds the goat")
	fig.cancel_swing()
	_check(fig._cp_anim == "Idle" and fig.attack_time_left() == 0.0, "a called-off charge goes back to the idle")
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
	var g: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WEREGOAT, main._ground_pos(cell + Vector2i(4, 0)))
	g.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = g._enemy_figure
	var take_off: Vector3 = g.global_position
	var st = main.player.get_stats()
	var hp_before: int = st.current_health + st.current_armor
	g._execute_action("goat_charge", main.player)
	var landing: Vector3 = g.global_position
	_check(fig != null and fig._cp_anim == "Charge", "its Charge plays the board (%s)" % (fig._cp_anim if fig else "no figure"))
	_check(landing.distance_to(take_off) > 1.5, "on the board it has run down its lane")
	_check(st.current_health + st.current_armor < hp_before, "the player in its path is trampled (%d -> %d)" % [hp_before, st.current_health + st.current_armor])
	_check(fig.global_position.distance_to(Vector3(take_off.x, fig.global_position.y, take_off.z)) < 0.05, "but it is drawn at its take-off square")
	_check(fig._cp_row(fig._cp_dir) == 2, "facing its lane (west, at the player)")
	var fps: float = fig._cp_fps["Charge"]
	await create_timer(3.0 / fps).timeout
	_check(fig.global_position.distance_to(Vector3(take_off.x, fig.global_position.y, take_off.z)) < 0.05, "still stamping on its take-off square")
	await create_timer(2.0 / fps).timeout
	_check(fig._cp_row(fig._cp_dir) == 2, "mid-run it faces its lane, not turned back to the player it ran past")
	await create_timer(2.5 / fps).timeout
	_check(fig.global_position.distance_to(Vector3(landing.x, fig.global_position.y, landing.z)) < 0.05, "down the lane and pulled up on its landing square")
	main.enemy_spawner.despawn_enemy(g)
	# Beside its prey it throws the Hoof Punch: the punch board.
	var pg: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WEREGOAT, main._ground_pos(cell + Vector2i(1, 0)))
	pg.chosen_action = {}
	await _settle(2)
	pg._execute_action("hoof_punch", main.player)
	_check(pg._enemy_figure._cp_anim == "Attack", "its Hoof Punch plays the punch board (%s)" % pg._enemy_figure._cp_anim)
	main.enemy_spawner.despawn_enemy(pg)
	# Rooted, it cannot charge: the stamping it began gives way to a walk.
	var r: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WEREGOAT, main._ground_pos(cell + Vector2i(0, 4)))
	r.chosen_action = {}
	await _settle(2)
	r.rooted_tempo = 5
	r._execute_action("goat_charge", main.player)
	_check(r._enemy_figure._cp_anim != "Charge", "rooted, it does not mime the charge (%s)" % r._enemy_figure._cp_anim)
	main.enemy_spawner.despawn_enemy(r)
