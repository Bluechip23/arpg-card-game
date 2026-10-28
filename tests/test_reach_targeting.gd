extends SceneTree

## Targeting on foot (designer, 2026-10-28): enemies go for whoever is
## closest to walk to, and never for a unit behind a wall they cannot get
## round; summons likewise never pick an enemy they cannot reach.
## Run: godot --headless --path . --script tests/test_reach_targeting.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(n := 6) -> void:
	for _i in range(n):
		await process_frame

func _set_walls(main, enemies: Array, walls: Array) -> void:
	var typed: Array[Vector2i] = []
	for c in walls:
		typed.append(c)
	main.player.blocked_tiles = typed.duplicate()
	for e in enemies:
		e.blocked_tiles = typed.duplicate()

func _run() -> void:
	print("=== Targeting only what can be reached ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_jeremy())
	main.set("sandbox_mode", true)
	get_root().add_child(main)
	await _settle()
	if main.olorin and main.olorin.is_busy():
		main.olorin._close()
	for e in main.enemy_spawner.get_living_enemies():
		e.queue_free()
	await process_frame
	var gm = main.grid_manager
	var p: Vector2i = gm.world_to_grid(main.player.position)
	var base := p + Vector2i(5, 0)   # the enemy's square
	main.player.position = gm.grid_to_world(base + Vector2i(-6, 0))
	var wall_x := base.x + 1
	var wall: Array = []
	for y in range(gm.grid_height):
		wall.append(Vector2i(wall_x, y))

	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WERERAT, gm.grid_to_world(base))
	await process_frame
	main._spawn_wolf()   # placed beside the player; moved behind the wall below
	var wolf = main._wolves.back()
	wolf.position = gm.grid_to_world(base + Vector2i(2, 0))
	wolf._target_position = wolf.position
	main.enemy_spawner.summons = [wolf]

	# No wall: the wolf (2 squares) is closer than the player (6).
	_set_walls(main, [e], [])
	_check(main.enemy_spawner._target_for(e) == wolf, "no wall: the enemy goes for the closer wolf")
	# A wall with no way round between them: the player it can walk to.
	_set_walls(main, [e], wall)
	_check(main.enemy_spawner._target_for(e) == main.player, "a wall between: it goes for the player it can reach, not the wolf behind it")
	# Solo: the hero counts too — closer than the wolf, the hero is the target.
	_set_walls(main, [e], [])
	main.player.position = gm.grid_to_world(base + Vector2i(-1, 0))
	_check(main.enemy_spawner._target_for(e) == main.player, "solo, the hero beside it is closer than the wolf: it goes for the hero")
	main.player.position = gm.grid_to_world(base + Vector2i(-6, 0))
	# A wall with a doorway: the wolf is reachable, but only the long way round.
	var dm = main.dungeon_manager
	var door_y := base.y
	for dy in [2, -2, 3, -3, 1, -1]:
		var ok := true
		for dx in [-1, 0, 1]:
			if dm and not dm.is_floor(Vector2i(wall_x + dx, base.y + dy)):
				ok = false
		if ok:
			door_y = base.y + dy
			break
	var door: Array = wall.filter(func(c): return c.y != door_y)
	_set_walls(main, [e], door)
	var steps_wolf: int = Enemy.steps_to(e.walk_map(), base + Vector2i(2, 0))
	_check(door_y != base.y and steps_wolf == 2 + 2 * absi(door_y - base.y), "through a doorway %d squares off, the wolf is %d steps away on foot (2 in a straight line)" % [absi(door_y - base.y), steps_wolf])
	main.player.position = gm.grid_to_world(base + Vector2i(-(steps_wolf - 1), 0))
	_check(main.enemy_spawner._target_for(e) == main.player, "so the hero, %d steps off in the open, is the closer one to walk to" % (steps_wolf - 1))
	main.player.position = gm.grid_to_world(base + Vector2i(-6, 0))
	# Nobody reachable: no target.
	main.player.position = gm.grid_to_world(base + Vector2i(4, 0))
	_set_walls(main, [e], wall)
	_check(main.enemy_spawner._target_for(e) == null, "everyone behind the wall: it has no one to go for")
	main.player.position = gm.grid_to_world(base + Vector2i(-6, 0))

	# The summon's side: the walled-off rat is closer, a second rat is reachable.
	var e2: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WERERAT, gm.grid_to_world(base + Vector2i(7, 0)))
	await process_frame
	_set_walls(main, [e, e2], [])
	var enemies: Array = main.enemy_spawner.get_living_enemies()
	_check(main._nearest_reachable_enemy_to(wolf.position, enemies) == e, "no wall: the wolf picks the closer rat")
	_set_walls(main, [e, e2], wall)
	_check(main._nearest_reachable_enemy_to(wolf.position, enemies) == e2, "a wall between: the wolf picks the rat it can reach")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
