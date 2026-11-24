extends SceneTree

## The Fire Goblin Shaman's Fire Wall (the designer's boards, 2026-11-24;
## tools/cut_pose_boards.py "fire_goblin_shaman_fire_wall" and
## "fire_goblin_shaman_wall"): Cast.png is a hand reached out and raised,
## flames kindled at his feet, risen, a blaze about him, fallen and the last
## embers, four facing rows beside his Idle; Wall.png the wall he raises —
## each tile of his wall wears it (FireWallSprite): it rises, burns on its
## two full frames and dies out under smoke when the wall is spent. The
## other fire hazards keep the pack flame.
## Run: godot --headless --path . --script tests/test_shaman_fire_wall.gd

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
	print("=== Shaman fire wall test ===")
	await _test_figure()
	await _test_wall()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("fire_goblin_shaman")
	await process_frame
	_check(fig._cp_sheets.has("Cast") and fig._cp_frame_count("Cast") == 7, "a seven-frame Cast sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if fig._cp_sheets.has("Cast"):
		var cell: int = fig._cp_cell
		_check(fig._cp_sheets["Cast"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
		_check(is_equal_approx(fig._cp_fps.get("Cast", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
		var img: Image = fig._cp_sheets["Cast"].get_image()
		if img.is_compressed():
			img.decompress()
		var drawn := true
		for row in range(4):
			for col in range(7):
				if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.5:
					drawn = false
		_check(drawn, "every frame of the four rows holds the shaman")
		fig.set_facing(CharacterAnimator.Direction.WEST)
		fig.play_action("fire_wall")
		_check(fig._cp_anim == "Cast" and int(fig._sprite.region_rect.position.y / cell) == 2, "Fire Wall facing west: the cast, the left-facing row")
	fig.free()


func _test_wall() -> void:
	print("-- The wall --")
	_check(FireWallSprite.sheet_path() != "", "the wall strip is cut (%s)" % FireWallSprite.sheet_path())
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
	var s: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.FIRE_GOBLIN_SHAMAN, main._ground_pos(cell + Vector2i(3, 0)))
	s.chosen_action = {}
	await _settle(2)
	var before: int = main._fire_walls.size()
	s._execute_action("fire_wall", main.player)
	_check(s._enemy_figure._cp_anim == "Cast", "his Fire Wall plays the cast (%s)" % s._enemy_figure._cp_anim)
	_check(main._fire_walls.size() == before + 1, "and raises a wall")
	if main._fire_walls.size() <= before:
		return
	var wall: Dictionary = main._fire_walls.back()
	var vis: Array = wall["visuals"]
	var all_wall := vis.size() == 3
	for v in vis:
		if not (v is FireWallSprite):
			all_wall = false
	_check(all_wall, "three tiles of his own wall art")
	var first: FireWallSprite = vis[0]
	_check(int(first._sprite.region_rect.position.x / first._cell) == 0, "it starts from the kindling frame")
	await create_timer(6.0 / FireWallSprite.FPS).timeout
	var f: int = int(first._sprite.region_rect.position.x / first._cell)
	_check(f in FireWallSprite.BURN, "risen, it burns on its full frames (frame %d)" % f)
	# Spent: it dies out under its smoke, then is gone.
	wall["moves_left"] = 1
	main._check_fire_walls(Vector2i(-99, -99))
	_check(main._fire_walls.size() == before and is_instance_valid(first) and first._dying, "spent, the wall is off the board and its flames die out")
	await create_timer(float(FireWallSprite.DIE.size()) / FireWallSprite.FPS + FireWallSprite.FADE + 0.3).timeout
	_check(not is_instance_valid(first), "and then it is gone")
	# Another creature's fire keeps the pack flame.
	var other: Dictionary = main.register_fire_wall([cell + Vector2i(0, 3)], 5, 1)
	_check(not (other["visuals"][0] is FireWallSprite), "the other fire hazards keep the pack flame")
