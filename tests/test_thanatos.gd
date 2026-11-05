extends SceneTree

## Thanatos Closet (the Underworld; designer, 2026-11-05):
##  - World 2's surface has the way down to it.
##  - The Closet: crypt warrens in the undead land art, its dwellers the
##    Underworld's specters, mind eaters and demons, its deepest crypt the
##    door to Thanatos's Hall.
##  - Thanatos's Hall: a boss room, sealed until Thanatos falls; then open,
##    and remembered as cleared.
##  - Thanatos (first pass): a boss in his own figure (the designer's
##    black-winged reaper; he wore the Corrupted Archangel's until it came) —
##    Reap, Death Bolt, Raise the Dead, Move.
## Run: godot --headless --path . --script tests/test_thanatos.gd

var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	_test_entrance()
	_test_closet()
	_test_hall()
	_test_thanatos()
	await _test_fight()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _build(interior: String, level: int = 2, cleared: Array = []) -> DungeonManager:
	var holder = Node3D.new()
	get_root().add_child(holder)
	var gm = GridManager.new()
	holder.add_child(gm)
	var parent = Node3D.new()
	holder.add_child(parent)
	var dm = DungeonManager.new()
	holder.add_child(dm)
	dm._opened_chests_ref = {}
	dm.cleared_bosses = cleared
	dm.initialize(gm, parent, level, interior)
	return dm

func _reachable(dm: DungeonManager) -> bool:
	var total := 0
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_floor(Vector2i(x, z)):
				total += 1
	var seen := {dm.player_start: true}
	var q: Array = [dm.player_start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and dm.is_floor(n):
				seen[n] = true
				q.append(n)
	return seen.size() == total

func _test_entrance() -> void:
	print("-- the way down --")
	var dm := _build("", 2)
	var i := dm.get_site_by_id("closet_0")
	_check(i >= 0, "the Underworld has the way down to Thanatos Closet")
	if i >= 0:
		_check(dm.is_floor(dm.site_nodes[i]["grid_pos"]) and dm.site_nodes[i]["display_name"] == "Thanatos Closet",
			"its door is walkable and named")
	var w1 := _build("", 1)
	_check(w1.get_site_by_id("closet_0") < 0, "and only the Underworld")

func _test_closet() -> void:
	print("-- Thanatos Closet --")
	var dm := _build("closet_0")
	_check(dm.interior_kind == "closet" and dm.get_location_name() == "Thanatos Closet", "its own kind and name")
	_check(not DungeonManager.is_boss_room("closet_0"), "a place to adventure, not a boss room")
	_check(dm.floor_texture_path().ends_with("undead_floor.png") and dm.wall_texture_path().ends_with("undead_wall.png")
		and dm._prop_biome() == "undead", "it wears the undead land art")
	_check(_reachable(dm), "its crypts are all one warren")
	_check(dm.get_site_by_id("exit") >= 0 and dm.get_site_by_id("thanatoshall") >= 0, "a way out, and the door to Thanatos's Hall")
	var ok := true
	var n := 0
	for z in dm.spawn_zones:
		for t in z["enemy_types"]:
			ok = ok and t in [Enemy.EnemyType.SPECTER, Enemy.EnemyType.MIND_EATER, Enemy.EnemyType.DEMON]
			n += 1
	_check(n >= 6 and ok, "specters, mind eaters and demons dwell in it (%d)" % n)

func _test_hall() -> void:
	print("-- Thanatos's Hall --")
	var dm := _build("thanatoshall")
	_check(DungeonManager.is_boss_room("thanatoshall") and DungeonManager.boss_room_key("thanatoshall") == "thanatoshall", "a boss room")
	_check(dm.get_site_by_id("exit") < 0, "sealed while he lives")
	_check(dm.is_floor(dm.thanatos_cell) and dm.thanatos_cell.x > dm.player_start.x + 15, "he waits at the far end")
	var pillars := true
	for c in dm.thanatos_pillars:
		pillars = pillars and not dm.is_floor(c)
	_check(dm.thanatos_pillars.size() == 8 and pillars and _reachable(dm), "two rows of pillars, and room to fight round them")
	var cleared := _build("thanatoshall", 2, ["thanatoshall"])
	_check(cleared.get_site_by_id("exit") >= 0, "once he has fallen, the way out stands open")

func _test_thanatos() -> void:
	print("-- Thanatos --")
	var e := Enemy.new()
	e.initialize(Enemy.EnemyType.THANATOS)
	_check(e.enemy_name == "Thanatos" and e.max_health >= 400, "Thanatos, %d health" % e.max_health)
	var names: Array = []
	for a in e.actions:
		names.append(a["name"])
	_check(names == ["thanatos_reap", "death_bolt", "summon_skeleton", "move"], "reaps, bolts, raises the dead, moves (%s)" % [names])
	_check(EnemyDefs.DEFS["THANATOS"]["figure_kind"] == "thanatos" and EnemyDefs.DEFS["THANATOS"]["tier"] == "Boss",
		"a boss in his own figure (the designer's board, 2026-11-05)")
	e.free()

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _find_main() -> Node:
	for child in get_root().get_children():
		if child.get_script() and "current_interior_id" in child and not child.is_queued_for_deletion():
			return child
	return null

func _test_fight() -> void:
	print("-- Booting main.tscn as Thanatos's Hall --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_world_level", 2)
	main.set("current_interior_id", "thanatoshall")
	get_root().add_child(main)
	await _settle(20)
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.boss_room_mode, "the scene knows it is a boss room")
	var boss: Enemy = null
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.THANATOS:
			boss = e
	_check(boss != null, "Thanatos is waiting")
	if boss == null:
		main.queue_free()
		return
	_check(main.dungeon_manager.get_site_by_id("exit") < 0, "no way out yet")
	boss.take_damage(99999, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(6)
	_check(main.dungeon_manager.get_site_by_id("exit") >= 0, "he falls: the way out opens")
	_check(main.current_character.has_defeated_boss("thanatoshall"), "and the character remembers it")
	main.queue_free()
	await _settle(2)
