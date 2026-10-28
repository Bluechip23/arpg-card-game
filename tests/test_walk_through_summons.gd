extends SceneTree

## Heroes walk through their summons (designer, 2026-10-28): a route may pass
## over a summon's tile, but never end on it.
## Run: godot --headless --path . --script tests/test_walk_through_summons.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _walk(main, to: Vector2i, spaces: int) -> Vector2i:
	var gm = main.grid_manager
	main.player.move_to_grid(gm.grid_to_world(to), spaces)
	for _i in range(400):
		await physics_frame
		if not main.player.is_moving:
			break
	return gm.world_to_grid(main.player.position)

func _run() -> void:
	print("=== Walking through summons ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_jeremy())
	main.set("sandbox_mode", true)
	get_root().add_child(main)
	for _i in range(8):
		await process_frame
	if main.olorin and main.olorin.is_busy():
		main.olorin._close()
	for e in main.enemy_spawner.get_living_enemies():
		e.queue_free()
	await process_frame
	var gm = main.grid_manager
	var p: Vector2i = gm.world_to_grid(main.player.position)

	# A summon held in place (Rooted) on the way: the hero walks over it.
	main._summon_from_card("summon_battle_turtle", gm.grid_to_world(p + Vector2i(1, 0)))
	var t = main._skeletons.back()
	t.get_debuff_manager().apply_debuff(Debuff.create(Debuff.DebuffType.ROOTED, 0, 50))
	var route: Array = main.player.preview_path_cells(gm.grid_to_world(p + Vector2i(3, 0)), 3)
	_check(route.size() == 3 and route[0] == p + Vector2i(1, 0), "the route runs straight over the summon's tile (%s)" % [route])
	var end: Vector2i = await _walk(main, p + Vector2i(3, 0), 3)
	_check(end == p + Vector2i(3, 0), "the hero walks through it to the far side (%s)" % [end - p])
	_check(t.get_destination_cell() == p + Vector2i(1, 0), "the summon stays where it was")

	# Aiming at the summon's own tile: the hero stops beside it, never on it.
	var here: Vector2i = gm.world_to_grid(main.player.position)
	var at_summon: Vector2i = t.get_destination_cell()
	route = main.player.preview_path_cells(gm.grid_to_world(at_summon), 10)
	_check(not route.is_empty() and route.back() != at_summon, "a move aimed at the summon's tile ends beside it (%s)" % [route.back() if not route.is_empty() else null])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
