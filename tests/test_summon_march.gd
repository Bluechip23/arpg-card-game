extends SceneTree

## How summons move (designer, 2026-10-28): on their own, their move rate
## every tempo (a skeleton 1 space, a shadow hound 2), always the way the
## player who summoned them is going — unless engaged with an enemy beside
## them, which they fight instead. They stop at walls and never step onto
## another unit.
## Run: godot --headless --path . --script tests/test_summon_march.gd

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

func _clear(main) -> void:
	for s in main._skeletons.duplicate():
		s.die()
	for e in main.enemy_spawner.get_living_enemies():
		e.queue_free()
	await process_frame
	await process_frame

func _one(main, card: String, cell: Vector2i):
	main._summon_from_card(card, main.grid_manager.grid_to_world(cell))
	return main._skeletons.back()

func _run() -> void:
	print("=== Summons march with their summoner ===")
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
	var p = main.player
	var here: Vector2i = gm.world_to_grid(p.position)
	var at: Vector2i = here + Vector2i(-3, -3)

	# The player's heading is their last step.
	p.heading = Vector2i(1, 0)
	_check(p.get_heading() == Vector2i(1, 0), "the player's heading is the way they last stepped")

	# No enemy anywhere: the skeleton walks 1 space a tempo, the player's way.
	var sk = _one(main, "summon_skeleton", at)
	at = sk.get_destination_cell()   # where it landed
	_check(sk.summoner == p, "a summon knows who summoned it")
	main._update_skeletons(1)
	_check(sk.get_destination_cell() == at + Vector2i(1, 0), "skeleton: 1 space east in 1 tempo, no enemy needed (%s)" % [sk.get_destination_cell() - at])
	main._update_skeletons(3)
	_check(sk.get_destination_cell() == at + Vector2i(4, 0), "and 3 more over 3 tempo (%s)" % [sk.get_destination_cell() - at])
	# The player turns: so do their summons.
	p.heading = Vector2i(0, 1)
	var before: Vector2i = sk.get_destination_cell()
	main._update_skeletons(2)
	_check(sk.get_destination_cell() == before + Vector2i(0, 2), "the player turns south: it follows that way (%s)" % [sk.get_destination_cell() - before])
	await _clear(main)

	# The hound: 2 spaces a tempo.
	p.heading = Vector2i(0, -1)
	var hd = _one(main, "summon_shadow_hound", at + Vector2i(0, 3))
	var h0: Vector2i = hd.get_destination_cell()
	main._update_skeletons(1)
	_check(hd.get_destination_cell() == h0 + Vector2i(0, -2), "shadow hound: 2 spaces in 1 tempo (%s)" % [hd.get_destination_cell() - h0])
	await _clear(main)

	# Engaged: an enemy beside it — it stays and fights.
	p.heading = Vector2i(1, 0)
	sk = _one(main, "summon_skeleton", at)
	_check(sk.get_destination_cell() == at, "(lands on its tile)")
	var rat: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WERERAT, gm.grid_to_world(at + Vector2i(0, 1)))
	await process_frame
	var hp0: int = rat.current_health
	main._update_skeletons(5)
	_check(sk.get_destination_cell() == at, "an enemy beside it: it holds its ground")
	_check(rat.current_health == hp0 - 6, "and hits it for 6 after 5 tempo (%d -> %d)" % [hp0, rat.current_health])
	# Walking into a fight: it stops beside the enemy.
	await _clear(main)
	sk = _one(main, "summon_skeleton", at)
	_check(sk.get_destination_cell() == at, "(lands on its tile)")
	rat = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WERERAT, gm.grid_to_world(at + Vector2i(4, 1)))
	await process_frame
	main._update_skeletons(10)
	_check(sk.get_destination_cell() == at + Vector2i(4, 0), "marching, it stops on the tile beside the enemy it meets (%s)" % [sk.get_destination_cell() - at])
	await _clear(main)

	# The turtle holds beside an enemy; with none it walks 1 a tempo.
	main.player.get_stats().base_intelligence = 20
	var tt = _one(main, "summon_battle_turtle", at)
	var t0: Vector2i = tt.get_destination_cell()
	main._update_skeletons(2)
	_check(tt.get_destination_cell() == t0 + Vector2i(2, 0), "Battle Turtle: 1 space a tempo (%s)" % [tt.get_destination_cell() - t0])
	await _clear(main)

	# Never onto another unit: two skeletons in a line, the front one blocked.
	p.heading = Vector2i(-1, 0)
	var edge := Vector2i(0, at.y)
	var a = _one(main, "summon_skeleton", edge + Vector2i(1, 0))
	var b = _one(main, "summon_skeleton", edge + Vector2i(2, 0))
	main._update_skeletons(5)
	_check(a.get_destination_cell() == edge and b.get_destination_cell() == edge + Vector2i(1, 0),
		"at the map's edge it stops, and the one behind stops behind it (%s, %s)" % [a.get_destination_cell(), b.get_destination_cell()])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
