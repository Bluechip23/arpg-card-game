extends SceneTree

## Iron Will (the STR-sector constellation): once its five nodes are lit,
## every kill gives 3 armor and heals 2. Through the real Main scene: the
## nodes are bought the way the grid panel buys them, then the bear dies.
## Run: godot --headless --path . --script tests/test_iron_will.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=== Iron Will test ===")
	var runner := SimRunner.new(self)
	var sc := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "bruiser", "level": 1, "enemy": "LARGE_BEAR", "sphere": "none"}))
	await runner.boot_only(sc, 1)
	var main = runner.main
	var stats = main.player.get_stats()
	var grid = main.sphere_grid_ui.sphere_grid
	var c = grid.get_constellation("iron_will")
	_check(c != null and not c.completed, "Iron Will starts incomplete (%s)" % str(c.node_ids if c else []))
	main.sphere_inventory.add_sphere(SphereInventory.SphereType.SPHERE, 40)
	for nid in [1, 7, 8, 19, 20]:
		grid.unlock_node(nid)  # some may be lit already by the build
	var lit: Array = c.node_ids.filter(func(nid): return grid.get_node_by_id(nid).unlocked)
	_check(lit.size() == 5, "its five nodes are lit (%s)" % str(lit))
	var done: Array = grid.check_constellation_completion()
	_check(done.has("iron_will") and c.completed, "the grid reports the constellation complete (%s)" % str(done))
	var on_kill: Array = stats.get_sphere_grid_passives_for_trigger("on_kill")
	_check(on_kill.any(func(p): return p.get("effect") == "iron_will"), "the on-kill passive is registered (%d on-kill passive(s))" % on_kill.size())

	var bear = main.enemy_spawner.get_living_enemies()[0]
	stats.current_health = stats.max_health - 10
	var hp0: int = stats.current_health
	var armor0: int = stats.get_total_armor()
	bear.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	await process_frame
	await process_frame
	_check(bear.is_dead, "the bear dies")
	_check(stats.get_total_armor() == armor0 + 3, "the kill gives 3 armor (%d -> %d)" % [armor0, stats.get_total_armor()])
	_check(stats.current_health >= hp0 + 2, "and heals at least 2 (%d -> %d)" % [hp0, stats.current_health])

	# Accepted in town (no listener registers the passive there) or loaded
	# from disk: the grid says complete, the carried stats know nothing. The
	# scene's post-restore pass registers it, once, without touching stats.
	stats.sphere_grid_passives = stats.sphere_grid_passives.filter(func(p): return p.get("effect") != "iron_will")
	_check(stats.get_sphere_grid_passives_for_trigger("on_kill").filter(func(p): return p.get("effect") == "iron_will").is_empty(),
		"(the passive is forgotten, as after a scene change)")
	var str0: int = stats.strength
	var armor1: int = stats.get_total_armor()
	main.progression_triggers.ensure_constellation_passives()
	main.progression_triggers.ensure_constellation_passives()
	var iron: Array = stats.sphere_grid_passives.filter(func(p): return p.get("effect") == "iron_will")
	_check(iron.size() == 1, "ensure_constellation_passives registers Iron Will exactly once (%d)" % iron.size())
	_check(stats.strength == str0 and stats.get_total_armor() == armor1, "and changes no stat")
	runner.teardown()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
