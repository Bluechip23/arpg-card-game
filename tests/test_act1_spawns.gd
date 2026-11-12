extends SceneTree

## Act 1's roster placed (2026-11-09; docs/ENEMY_AUDIT.md §1 "built, unplaced",
## STORY.md §5.4): every built Act 1 creature now lives somewhere in World 1.
##  - The Mountain Pass meets all seven of the Mountains roster (Weregoat,
##    Sabertooth, Snow Wraith, Ice Troll, Wyvern, White Manticore, Roc); the
##    Granite Colossus (no moves yet) stays out everywhere.
##  - The Old Graveyard: a Grave Titan in its last crypt short of the
##    Necromancer's, the Consumed and the Crypt Crawlers among the dead.
##  - The Ruined Library: the Spirit Collectors, the Consumed, Crypt Crawlers.
##  - The Greenwood: the Hydra holds its widest clearing, each of the five
##    Elemental Mages leads a clearing of its own.
##  - Every zone's table on every Act 1 map uses only types that exist and
##    are built (no mock-ups), each map's types sit in its level band, and the
##    placed creatures really spawn when the game wakes their zones.
## The layouts are seeded by world and interior (DungeonManager._layout_seed),
## so these are the tables the game makes.
## Run: godot --headless --path . --script tests/test_act1_spawns.gd

var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

const T := Enemy.EnemyType

## Act 1's maps, with the level band their tables keep (0 = any).
const MAPS := {
	"": [1, 12], "sewer_0": [1, 5], "cave_0": [8, 15], "cave_1": [8, 15], "building_0": [1, 12],
	"forest_0": [12, 20], "mountains_0": [20, 25], "icecave_0": [20, 25], "trolllair_0": [20, 25],
	"graveyard_0": [6, 12], "library_0": [6, 12],
}

func _initialize() -> void:
	_run()

func _run() -> void:
	_test_tables()
	_test_placed()
	await _test_in_game("forest_0", [T.HYDRA, T.SPARK_MAGE, T.AIR_MAGE, T.FIRE_MAGE, T.ICE_MAGE, T.EARTH_MAGE])
	await _test_in_game("graveyard_0", [T.GRAVE_TITAN, T.CONSUMED, T.CRYPT_CRAWLER, T.NECROMANCER])
	await _test_in_game("mountains_0", [T.WEREGOAT, T.SABERTOOTH, T.SNOW_WRAITH, T.ICE_TROLL, T.WYVERN,
		T.WHITE_MANTICORE, T.ROC])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _build(interior: String, level: int = 1) -> DungeonManager:
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

func _label(iid: String) -> String:
	return iid if iid != "" else "overworld"

func _types(dm: DungeonManager) -> Dictionary:
	var out := {}
	for z in dm.spawn_zones:
		for t in z["enemy_types"]:
			out[t] = out.get(t, 0) + 1
	return out

func _names(types: Dictionary) -> String:
	var parts: Array = []
	for t in types:
		parts.append("%s×%d" % [T.keys()[t], types[t]])
	return ", ".join(parts)

func _test_tables() -> void:
	print("-- every Act 1 table uses real, built enemies --")
	for iid in MAPS:
		var dm := _build(iid)
		var types := _types(dm)
		print("    %s: %s" % [_label(iid), _names(types)])
		var exist := true
		var built := true
		var band_ok := true
		var band: Array = MAPS[iid]
		for t in types:
			if t < 0 or t >= T.size():
				exist = false
				continue
			var key: String = T.keys()[t]
			var def: Dictionary = EnemyDefs.DEFS.get(key, {})
			if def.is_empty() or def.get("mockup", false) or t == T.GRANITE_COLOSSUS:
				built = false
			var e := Enemy.new()
			e.initialize(t)
			if e.actions.is_empty():
				built = false
			e.free()
			var lvl := int(def.get("intended_level", 0))
			if iid != "" and iid != "building_0" and (lvl < band[0] or lvl > band[1]):
				band_ok = false
				print("      out of band: %s (%d)" % [key, lvl])
		_check(exist and not types.is_empty(), "%s: every type exists" % _label(iid))
		_check(built, "%s: every type is built (actions, no mock-up, no Granite Colossus)" % _label(iid))
		_check(band_ok, "%s: every type in its band %s" % [_label(iid), band])

func _test_placed() -> void:
	print("-- the unplaced Act 1 roster, placed --")
	var mtn := _types(_build("mountains_0"))
	for t in [T.WEREGOAT, T.SABERTOOTH, T.SNOW_WRAITH, T.ICE_TROLL, T.WYVERN, T.WHITE_MANTICORE, T.ROC]:
		_check(mtn.has(t), "the Mountain Pass has the %s" % T.keys()[t])
	var gy_dm := _build("graveyard_0")
	var gy := _types(gy_dm)
	for t in [T.GRAVE_TITAN, T.CONSUMED, T.CRYPT_CRAWLER, T.NECROMANCER]:
		_check(gy.has(t), "the Old Graveyard has the %s" % T.keys()[t])
	_check(gy.get(T.GRAVE_TITAN, 0) == 1, "one Grave Titan")
	# The titan's crypt is the deepest chamber short of the Necromancer's.
	var titan_x := -1
	var necro_x := -1
	for z in gy_dm.spawn_zones:
		if z["enemy_types"][0] == T.GRAVE_TITAN:
			titan_x = (z["trigger_rect"] as Rect2i).get_center().x
		if z["enemy_types"][0] == T.NECROMANCER:
			necro_x = (z["trigger_rect"] as Rect2i).get_center().x
	_check(titan_x > gy_dm.GRID_W / 2 and titan_x <= necro_x, "the Grave Titan's crypt is deep, short of the Necromancer's")
	var lib := _types(_build("library_0"))
	for t in [T.SPIRIT_COLLECTOR, T.CONSUMED, T.CRYPT_CRAWLER]:
		_check(lib.has(t), "the Ruined Library has the %s" % T.keys()[t])
	var fdm := _build("forest_0")
	var forest := _types(fdm)
	for t in [T.HYDRA] + DungeonManager.FOREST_MAGES:
		_check(forest.get(t, 0) == 1, "the Greenwood has one %s" % T.keys()[t])
	# Each leads a clearing of its own (the first in its zone), the Hydra the widest.
	var led := {}
	var hydra_r := -1
	var widest := -1
	for r in fdm.rooms:
		if r["kind"] == "clearing":
			widest = maxi(widest, int(r["radius"]))
	for z in fdm.spawn_zones:
		var head = z["enemy_types"][0]
		if head == T.HYDRA or head in DungeonManager.FOREST_MAGES:
			led[head] = true
		if head == T.HYDRA:
			for r in fdm.rooms:
				if (r["rect"] as Rect2i).grow(1) == z["trigger_rect"]:
					hydra_r = int(r["radius"])
	_check(led.size() == 6, "the Hydra and the five mages each lead a clearing (%d)" % led.size())
	_check(hydra_r == widest, "the Hydra's is the widest clearing (radius %d)" % hydra_r)
	for iid in MAPS:
		_check(not _types(_build(iid)).has(T.GRANITE_COLOSSUS), "no Granite Colossus in %s" % _label(iid))

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _test_in_game(interior: String, want: Array) -> void:
	print("-- Booting main.tscn in %s and waking every zone --" % interior)
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_world_level", 1)
	main.set("current_interior_id", interior)
	get_root().add_child(main)
	await _settle(20)
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var stats = main.player.get_stats()
	stats.max_health = 50000
	stats.current_health = 50000
	var dm: DungeonManager = main.dungeon_manager
	for i in range(dm.spawn_zones.size()):
		main._spawn_dungeon_zone(i)
		await _settle(1)
	await _settle(4)
	var got := {}
	var on_open := true
	for e in main.enemy_spawner.get_living_enemies():
		got[e.enemy_type] = true
		var c: Vector2i = main.grid_manager.world_to_grid(e.position)
		if not e.is_structure and not e.immune_to_high_ground and not dm.is_floor(c):
			on_open = false
	for t in want:
		_check(got.has(t), "%s: the %s spawns" % [interior, T.keys()[t]])
	_check(on_open, "%s: every walker spawned on open floor" % interior)
	main.queue_free()
	await _settle(4)
