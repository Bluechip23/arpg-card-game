extends SceneTree

## The Demon's Mimic (the designer's mimic board, 2026-11-06;
## tools/cut_pose_boards.py "demon_mimic"): Mimic.png is the demon raising
## its trident in red power and tearing in two. The copy steps onto the
## square beside it (east or west); both figures are hidden while the board
## plays midway between the two squares, then both stand.
## Half the time the real demon is the one that stepped out (designer).
## Run: godot --headless --path . --script tests/test_demon_mimic.gd

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
	print("=== Demon mimic test ===")
	var tex: Texture2D = load(SpriteEnemyFigure.SHEETS + "/demon/Mimic.png")
	_check(tex != null and tex.get_width() == 8 * tex.get_height(), "an eight-frame Mimic strip")
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
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var moved := 0
	var stayed := 0
	for i in range(24):
		var d: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DEMON, main._ground_pos(cell + Vector2i(0, 3)))
		await _settle(2)
		var here: Vector2i = main.grid_manager.world_to_grid(d.position)
		var ok := d._try_mimic(main.player)
		var m: Enemy = d._mimics[0] if d._mimics.size() > 0 else null
		if i == 0:
			_check(ok and m != null and m.is_mimic, "Mimic conjures a copy")
			var mc: Vector2i = main.grid_manager.world_to_grid(m.position)
			var dc: Vector2i = main.grid_manager.world_to_grid(d.position)
			_check(dc.y == here.y and mc.y == here.y and absi(dc.x - mc.x) == 1 and (dc == here or mc == here),
					"the two stand side by side, one on the demon's square, one beside it")
			var fx = d._enemy_figure.last_spot
			_check(fx is SpotEffect and is_instance_valid(fx), "the split plays as the board on the ground")
			var mid: Vector3 = (d.global_position + m.global_position) * 0.5
			_check(fx.global_position.distance_to(mid) < 0.05, "midway between the two squares")
			_check(not d._enemy_figure.visible and not m._enemy_figure.visible, "both figures hidden while it plays")
			await create_timer(fx.total_time() + 0.2).timeout
			_check(d._enemy_figure.visible and m._enemy_figure.visible, "then both demons stand")
			_check(not is_instance_valid(fx), "the board is gone")
		if main.grid_manager.world_to_grid(d.position) == here:
			stayed += 1
		else:
			moved += 1
		for e in d._mimics:
			main.enemy_spawner.despawn_enemy(e)
		main.enemy_spawner.despawn_enemy(d)
		await _settle(2)
	_check(moved > 0 and stayed > 0, "the real demon sometimes stays, sometimes steps out (%d stayed, %d moved of 24)" % [stayed, moved])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
