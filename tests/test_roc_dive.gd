extends SceneTree

## The Roc's Dive Bomb and Eye Scrape (the designer's boards, 2026-11-24;
## tools/cut_pose_boards.py "roc" and "roc_scrape"): Dive.png is the wings
## spread and raised, the lift-off, the swoop, the dive and the landing;
## Attack.png the hunch, the ruff bristling, rearing up, leaning in, the
## strike with its beak agape and drawing back — four facing rows each,
## packed beside its Idle. Its Dive Bomb plays Dive facing its prey, lands
## at once on the board, and the figure is carried there through the
## airborne frames (leap_from). Rooted, the dive is called off.
## Run: godot --headless --path . --script tests/test_roc_dive.gd

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
	print("=== Roc dive test ===")
	await _test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _all_drawn(fig: SpriteEnemyFigure, sheet: String, cols: int) -> bool:
	var cell: int = fig._cp_cell
	var img: Image = fig._cp_sheets[sheet].get_image()
	if img.is_compressed():
		img.decompress()
	for row in range(4):
		for col in range(cols):
			if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.3:
				return false
	return true


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("roc")
	await process_frame
	_check(fig._cp_sheets.has("Dive") and fig._cp_frame_count("Dive") == 6, "a six-frame Dive sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	_check(fig._cp_sheets.has("Attack") and fig._cp_frame_count("Attack") == 6, "a six-frame Eye Scrape sheet")
	if not fig._cp_sheets.has("Dive") or not fig._cp_sheets.has("Attack"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Dive"].get_height() == 4 * cell and fig._cp_sheets["Attack"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Dive", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "the dive at its drawn 10 fps, slowed as every enemy swing is")
	_check(_all_drawn(fig, "Dive", 6), "every dive frame of the four rows holds the bird")
	_check(_all_drawn(fig, "Attack", 6), "every scrape frame of the four rows holds the bird")
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("dive_bomb")
	_check(fig._cp_anim == "Dive" and int(fig._sprite.region_rect.position.y / cell) == 2, "Dive facing west: the left-facing row")
	_check(fig._fx_tween == null or not fig._fx_tween.is_valid(), "no lunge: the dive carries it")
	fig.cancel_swing()
	_check(fig._cp_anim == "Idle" and fig.attack_time_left() == 0.0, "a called-off dive goes back to the idle")
	fig.play_action("eye_scrape")
	_check(fig._cp_anim == "Attack", "its Eye Scrape plays the scrape board")
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
	var r: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.ROC, main._ground_pos(cell + Vector2i(4, 0)))
	r.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = r._enemy_figure
	var take_off: Vector3 = r.global_position
	var st = main.player.get_stats()
	var hp_before: int = st.current_health + st.current_armor
	r._execute_action("dive_bomb", main.player)
	var landing: Vector3 = r.global_position
	_check(fig != null and fig._cp_anim == "Dive", "its Dive Bomb plays the board (%s)" % (fig._cp_anim if fig else "no figure"))
	_check(landing.distance_to(take_off) > 1.5 and r._cells_between(r, main.player) == 1, "on the board it has landed beside the player")
	_check(st.current_health + st.current_armor < hp_before, "the player is hit (%d -> %d)" % [hp_before, st.current_health + st.current_armor])
	_check(fig.global_position.distance_to(Vector3(take_off.x, fig.global_position.y, take_off.z)) < 0.05, "but it is drawn at its take-off square")
	_check(fig._cp_row(fig._cp_dir) == 2, "facing its dive (west, at the player)")
	var fps: float = fig._cp_fps["Dive"]
	await create_timer(1.5 / fps).timeout
	_check(fig.global_position.distance_to(Vector3(take_off.x, fig.global_position.y, take_off.z)) < 0.05, "still spreading its wings on its take-off square")
	await create_timer(4.0 / fps).timeout
	_check(fig.global_position.distance_to(Vector3(landing.x, fig.global_position.y, landing.z)) < 0.05, "down on its landing square by the landing frame")
	main.enemy_spawner.despawn_enemy(r)
	# Rooted, it cannot fly: the wings it began to spread are folded again.
	var rr: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.ROC, main._ground_pos(cell + Vector2i(0, 4)))
	rr.chosen_action = {}
	await _settle(2)
	rr.rooted_tempo = 5
	rr._execute_action("dive_bomb", main.player)
	_check(rr._enemy_figure._cp_anim != "Dive", "rooted, it does not mime the dive (%s)" % rr._enemy_figure._cp_anim)
	main.enemy_spawner.despawn_enemy(rr)
