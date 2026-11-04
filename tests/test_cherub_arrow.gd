extends SceneTree

## The Cherub's Love's Arrow (the designer's arrow board, 2026-11-04;
## tools/cut_pose_boards.py "cherub_arrow"): Arrow.png is one arrow drawn
## four ways (east, west, north, south), each centred in its cell; its Love's
## Arrow sends it at its victim, showing the view nearest the way it flies.
## Run: godot --headless --path . --script tests/test_cherub_arrow.gd

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

func _thrown(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is ThrownSprite:
			out.append(c)
	return out

func _run() -> void:
	print("=== Cherub arrow test ===")
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
	main.player.get_stats().current_health = 500
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	# frame: 0 east, 1 west, 2 north, 3 south — the way the arrow flies.
	var cases := [[Vector2i(3, 0), 1, "from the east it flies west"],
		[Vector2i(-3, 0), 0, "from the west it flies east"],
		[Vector2i(0, 2), 2, "from the south it flies north"],
		[Vector2i(0, -3), 3, "from the north it flies south"],
		[Vector2i(3, 1), 1, "slightly off true, the nearest way (west)"]]
	for c in cases:
		var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.CHERUB, main._ground_pos(cell + c[0]))
		e.chosen_action = {}
		await _settle(2)
		var n0 := _thrown(e.get_parent()).size()
		var hp: int = int(main.player.get_stats().current_health) + int(main.player.get_stats().current_armor)
		e._execute_action("loves_arrow", main.player)
		var all := _thrown(e.get_parent())
		_check(all.size() == n0 + 1, "%s: an arrow is shot" % c[2])
		if all.size() == n0 + 1:
			var a: ThrownSprite = all.back()
			_check(a._facing_frame == c[1] and not a._sprite.flip_h, "%s (view %d)" % [c[2], a._facing_frame])
			a._process(0.05)
			_check(int(a._sprite.region_rect.position.x / a._cell) == c[1], "it shows that view")
			_check(a._frames == 4, "one of four views")
			_check(is_equal_approx(a._sprite.offset.y, -a._cell * 0.5), "centred on its flight line")
		_check(int(main.player.get_stats().current_health) + int(main.player.get_stats().current_armor) < hp, "and it struck")
		main.enemy_spawner.despawn_enemy(e)
		await _settle(2)
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
