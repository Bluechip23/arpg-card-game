extends SceneTree

## Hell — the Underworld, World 2 (Act 2; designer, 2026-11-05: "build out
## Hell"):
##  - World 2 wears the hell art (cursed earth, lava pools, the volcanoes and
##    idols on its skyline: DungeonManager.art_world) and World 4 the desert
##    it gave up; its name is The Underworld.
##  - Its surface and caves are the demons': succubi, magma spiders, mind
##    eaters, specters, demons, ash harpies, ifrits; the deep rooms keep the
##    lords of the deep (the Ferryman's Toll); the arena an ifrit and demons.
##  - Its caves are Burning Caves: lava pools, lit, that cut no tunnel; each
##    keeps its Fire Goblin Shaman and the door to the Labyrinth.
## Run: godot --headless --path . --script tests/test_underworld.gd

var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_test_surface()
	_test_world4()
	_test_caves()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _build(interior: String, level: int) -> DungeonManager:
	var holder = Node3D.new()
	get_root().add_child(holder)
	var gm = GridManager.new()
	holder.add_child(gm)
	var parent = Node3D.new()
	holder.add_child(parent)
	var dm = DungeonManager.new()
	holder.add_child(dm)
	dm._opened_chests_ref = {}
	dm.initialize(gm, parent, level, interior)
	return dm

const HELL := [Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.MAGMA_SPIDER, Enemy.EnemyType.MIND_EATER,
	Enemy.EnemyType.SPECTER, Enemy.EnemyType.DEMON, Enemy.EnemyType.ASH_HARPY, Enemy.EnemyType.IFRIT,
	Enemy.EnemyType.INFLAMED_MINOTAUR, Enemy.EnemyType.DJINN]

func _types(dm: DungeonManager) -> Array:
	var out: Array = []
	for z in dm.spawn_zones:
		out.append_array(z["enemy_types"])
	return out

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

func _test_surface() -> void:
	print("-- the Underworld's surface (World 2) --")
	var dm := _build("", 2)
	_check(dm.art_world() == 4 and dm.get_palette()["name"] == "The Underworld", "World 2 is The Underworld")
	_check(dm.floor_texture_path().ends_with("cursed_floor.png") and not dm._natural_boundary(), "it wears the hell art: cursed earth, cliffs all round")
	var lava := 0
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_water(Vector2i(x, z)) and not dm.is_floor(Vector2i(x, z)):
				lava += 1
	_check(lava > 0, "molten pools no one wades (%d tiles)" % lava)
	_check(_reachable(dm), "and the ground is all one piece")
	var types := _types(dm)
	var all_hell := true
	for t in types:
		all_hell = all_hell and t in HELL
	_check(types.size() > 10 and all_hell, "only the Underworld's creatures (%d)" % types.size())
	var lords := 0
	for t in types:
		if t in [Enemy.EnemyType.IFRIT, Enemy.EnemyType.INFLAMED_MINOTAUR, Enemy.EnemyType.DJINN]:
			lords += 1
	_check(lords > 0, "the lords of the deep are there for the Ferryman (%d)" % lords)
	var seen := {}
	for t in types:
		seen[t] = true
	_check(seen.size() >= 5, "a mixed host (%d kinds)" % seen.size())

func _test_world4() -> void:
	print("-- World 4 took the desert --")
	var dm := _build("", 4)
	_check(dm.art_world() == 2 and dm.get_palette()["name"] == "Amber Wastes" and dm.floor_texture_path().ends_with("desert_floor.png"),
		"World 4 wears the Amber Wastes")

func _test_caves() -> void:
	print("-- the Burning Caves --")
	var dm := _build("cave_0", 2)
	_check(dm.hell_cave() and dm.get_location_name() == "Burning Cave 1", "a Burning Cave")
	var lava := 0
	var blocked := true
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_water(Vector2i(x, z)):
				lava += 1
				blocked = blocked and not dm.is_floor(Vector2i(x, z))
	_check(lava > 0 and blocked and dm.water_texture_path().ends_with("water_lava.png"), "lava pools, not puddles (%d tiles)" % lava)
	_check(_reachable(dm), "and they cut no tunnel")
	var types := _types(dm)
	var ok := true
	for t in types:
		ok = ok and (t in HELL or t == Enemy.EnemyType.FIRE_GOBLIN_SHAMAN)
	_check(types.size() > 0 and ok, "the demons live there too (%d)" % types.size())
	_check(Enemy.EnemyType.FIRE_GOBLIN_SHAMAN in types, "with a Fire Goblin Shaman (the Channel lesson)")
	_check(dm.get_site_by_id("labyrinth") >= 0, "and the way to the Labyrinth")
	var act1 := _build("cave_0", 1)
	_check(not act1.hell_cave() and act1.get_location_name() == "Cave 1", "Act 1's caves are untouched")
