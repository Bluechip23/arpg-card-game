extends SceneTree

## Act 3 — the corrupted Heaven (designer, 2026-11-09: "Make World 3 the
## Heaven"; "places & enemies only", the story round them stays [TBD]):
##  - World 3 is Heaven: its own palette and HEAVEN_ART's stand-ins, no caves
##    (the snowy mountains and their Ice Caves stay on World 1's Mountain
##    Pass), Heaven's host and the Underworld's invaders on its surface.
##  - Four places on it, each with a sealed room held by guardians
##    (GUARDIAN_ROOMS): the Defiled Sanctum (the Desecrated Altar), the
##    Gilded Garden (the Sickened Font), the Silent Spire (the Belfry) and,
##    at the far edge, the Sundered Causeway (the Rent) — whose wardens'
##    fall opens the way down to the next world, as the Breach opens the
##    way up to this one.
##  - The hero arrives from the Breach by the way back down to it.
##  - Every creature: the Heavens roster in code (Cherub 33, Djinn 35) and
##    the Underworld's invaders (26-28); never the Corrupted Archangel.
## Run: godot --headless --path . --script tests/test_act3_heaven.gd

var failures: int = 0

const ROSTER := [Enemy.EnemyType.CHERUB, Enemy.EnemyType.DJINN, Enemy.EnemyType.DEMON, Enemy.EnemyType.SUCCUBUS,
	Enemy.EnemyType.SPECTER, Enemy.EnemyType.ASH_HARPY, Enemy.EnemyType.MIND_EATER]
const PLACES := {"sanctum_0": ["sanctum", "The Defiled Sanctum", "altar"],
	"garden_0": ["garden", "The Gilded Garden", "font"],
	"spire_0": ["spire", "The Silent Spire", "belfry"],
	"causeway_0": ["causeway", "The Sundered Causeway", "rent"]}

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	_test_surface()
	_test_mountains_keep_the_snow()
	_test_sanctum()
	_test_garden()
	_test_spire()
	_test_causeway()
	_test_sealed_rooms()
	_test_levels()
	await _test_sanctum_round_trip()
	await _test_font_fight()
	await _test_rent_fight()
	await _test_breach_to_heaven_and_back()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _build(interior: String, level: int = 3, cleared: Array = []) -> DungeonManager:
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

## Floor reachable from the start by the game's walking rule (one level a step).
func _reach(dm: DungeonManager, skip: Dictionary = {}) -> Dictionary:
	var seen := {dm.player_start: true}
	var q: Array = [dm.player_start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and dm.is_floor(n) and not skip.has(n) and dm.can_step(c, n):
				seen[n] = true
				q.append(n)
	return seen

func _floor_count(dm: DungeonManager) -> int:
	var total := 0
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_floor(Vector2i(x, z)):
				total += 1
	return total

func _pool_count(dm: DungeonManager) -> int:
	var n := 0
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_water(Vector2i(x, z)) and not dm.is_floor(Vector2i(x, z)):
				n += 1
	return n

func _types(dm: DungeonManager) -> Array:
	var out: Array = []
	for z in dm.spawn_zones:
		out.append_array(z["enemy_types"])
	return out

func _roster_ok(types: Array) -> bool:
	for t in types:
		if not t in ROSTER:
			return false
	return true

func _site_in_room(dm: DungeonManager, id: String, kind: String) -> bool:
	var i := dm.get_site_by_id(id)
	if i < 0:
		return false
	for room in dm.rooms:
		if room["kind"] == kind and (room["rect"] as Rect2i).grow(1).has_point(dm.site_nodes[i]["grid_pos"]):
			return true
	return false

## Spawn points on open floor the start can walk to (never water or a bridge).
func _spawns_ok(dm: DungeonManager, reach: Dictionary) -> bool:
	for z in dm.spawn_zones:
		for p in z["spawn_points"]:
			if not reach.has(p) or dm.bridge_cells.has(p) or dm.is_water(p):
				return false
	return true

## Heaven's look: every slot read from HEAVEN_ART (the stand-ins).
func _heaven_art(dm: DungeonManager) -> bool:
	return dm.heaven_land() and dm.get_palette()["name"] == "The Tarnished Heavens" \
		and dm.floor_texture_path() == dm.heaven_art("floor") and dm.trail_texture_path() == dm.heaven_art("trail") \
		and dm.wall_texture_path() == dm.heaven_art("wall") and dm.cliff_strip_path() == dm.heaven_art("cliff") \
		and dm._prop_biome() == "heaven"

func _place_basics(dm: DungeonManager, id: String) -> Dictionary:
	var spec: Array = PLACES[id]
	_check(dm.interior_kind == spec[0] and dm.get_location_name() == spec[1], "its own kind and name (%s)" % spec[1])
	_check(dm.act3_place() and not DungeonManager.is_boss_room(id), "an Act 3 place to cross, not a sealed room")
	_check(_heaven_art(dm), "it wears Heaven's (stand-in) art")
	var reach := _reach(dm)
	_check(reach.size() == _floor_count(dm), "every tile of it can be walked to (%d)" % reach.size())
	_check(dm.get_site_by_id("exit") >= 0, "a way back out")
	var types := _types(dm)
	_check(types.size() >= 8 and _roster_ok(types), "Heaven's host and the invaders (%d)" % types.size())
	_check(Enemy.EnemyType.CHERUB in types and Enemy.EnemyType.DJINN in types, "cherubs, and a djinn")
	_check(_spawns_ok(dm, reach), "every creature stands where the hero can reach")
	_check(dm.fountain_nodes.size() == 1 and dm.chest_nodes.size() >= 2, "a fountain and chests (%d)" % dm.chest_nodes.size())
	return reach

# ---- the surface ----

func _test_surface() -> void:
	print("-- World 3 is Heaven --")
	var dm := _build("", 3)
	_check(_heaven_art(dm) and not dm._natural_boundary(), "Heaven's palette and stand-in art, its pale ground walled by stone")
	_check(dm.get_location_name() == "World 3 — The Tarnished Heavens", "its name (%s)" % dm.get_location_name())
	_check(dm.water_texture_path() == dm.heaven_art("water") and _pool_count(dm) > 0, "its holy pools, sickened")
	var caves := 0
	for s in dm.site_nodes:
		if s["kind"] == "cave" or String(s["id"]).begins_with("icecave"):
			caves += 1
	_check(caves == 0, "no caves: Frostreach's Ice Caves are gone from World 3")
	for id in PLACES:
		var i := dm.get_site_by_id(id)
		_check(i >= 0, "the way into %s" % PLACES[id][1])
		if i >= 0:
			var site: Dictionary = dm.site_nodes[i]
			_check(dm.is_floor(site["grid_pos"]) and site["display_name"] == PLACES[id][1] and site["kind"] == PLACES[id][0]
				and site["footprint"].size() == 9, "  walkable, named, on a raised block")
	var far := dm.get_site_by_id("causeway_0")
	var eastmost := far >= 0
	for s in dm.site_nodes:
		if far >= 0 and s["footprint"].size() > 0:
			eastmost = eastmost and s["grid_pos"].x <= dm.site_nodes[far]["grid_pos"].x
	_check(eastmost, "the Causeway is the farthest east, at Heaven's edge")
	var sanctum := dm.get_site_by_id("sanctum_0")
	_check(sanctum >= 0 and dm.site_nodes[sanctum]["grid_pos"].x < dm.GRID_W / 3, "the Sanctum near the arrival, in the west")
	var arrive := dm.get_site_by_id(DungeonManager.HEAVEN_ARRIVAL_ID)
	_check(arrive >= 0 and dm.site_nodes[arrive]["kind"] == DungeonManager.HEAVEN_ARRIVAL_ID
		and (dm.site_nodes[arrive]["grid_pos"] - dm.player_start).length() < 5.0,
		"the way back down to the Breach stands in the start field, where the hero arrives")
	_check(_reach(dm).size() == _floor_count(dm), "the surface is all one piece")
	var types := _types(dm)
	_check(types.size() >= 20 and _roster_ok(types), "Heaven's host and the invaders on its surface (%d)" % types.size())
	_check(Enemy.EnemyType.CHERUB in types and Enemy.EnemyType.DJINN in types and Enemy.EnemyType.DEMON in types,
		"cherubs, demons, and a djinn in its arena")
	for lvl in [1, 2, 4]:
		var other := _build("", lvl)
		var none := other.get_site_by_id(DungeonManager.HEAVEN_ARRIVAL_ID) < 0
		for id in PLACES:
			none = none and other.get_site_by_id(id) < 0
		_check(none and not other.heaven_land(), "World %d has none of Heaven's places" % lvl)

func _test_mountains_keep_the_snow() -> void:
	print("-- the snow stays on World 1's Mountain Pass --")
	var mtn := _build("mountains_0", 1)
	_check(mtn.get_palette()["name"] == "Frostreach" and mtn.floor_texture_path().ends_with("floor_winter.png")
		and mtn._prop_biome() == "winter" and not mtn.heaven_land(), "the Pass wears the winter pack and its frost light")
	_check(mtn.get_site_by_id("icecave_0") >= 0 and mtn.get_site_by_id("trolllair_0") >= 0, "its Ice Cave and the Troll Lair")
	var ice := _build("icecave_0", 1)
	_check(ice.get_palette()["name"] == "Ice Cave" and ice._prop_biome() == "ice", "the Ice Cave is still frozen")

# ---- the places ----

func _test_sanctum() -> void:
	print("-- the Defiled Sanctum --")
	var dm := _build("sanctum_0")
	_place_basics(dm, "sanctum_0")
	var pillars := true
	for c in dm.sanctum_pillars:
		pillars = pillars and not dm.is_floor(c)
	_check(dm.sanctum_pillars.size() >= 12 and pillars, "a pillared nave and choir, a ring under the dome (%d columns)" % dm.sanctum_pillars.size())
	var parts := {}
	for room in dm.rooms:
		parts[room.get("part", "")] = int(parts.get(room.get("part", ""), 0)) + 1
	_check(parts.get("chapel", 0) >= 4 and parts.get("crossing", 0) == 1 and parts.get("transept", 0) == 2,
		"side chapels (%d), a domed crossing, two transepts" % parts.get("chapel", 0))
	_check(_pool_count(dm) >= 12, "its fonts gone to bog")
	_check(_site_in_room(dm, "altar", "deep"), "the Altar's door in the choir's apse")
	_check(dm.is_trail(Vector2i(10, dm.GRID_H / 2)), "a paved runner down the nave")
	var again := _build("sanctum_0")
	_check(again.sanctum_pillars == dm.sanctum_pillars and again.spawn_zones.size() == dm.spawn_zones.size(), "the same temple every visit")

func _test_garden() -> void:
	print("-- the Gilded Garden --")
	var dm := _build("garden_0")
	_place_basics(dm, "garden_0")
	_check(dm._natural_boundary(), "its edges and hedges are overgrowth")
	var beds := 0
	for room in dm.rooms:
		if room.get("part", "") == "bed":
			beds += 1
	_check(beds >= 8, "hedged beds (%d)" % beds)
	_check(dm.is_water(dm.garden_basin) and not dm.is_floor(dm.garden_basin), "the great fountain, sickened, at its heart")
	var walks := 0
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_floor(Vector2i(x, z)) and dm.is_trail(Vector2i(x, z)):
				walks += 1
	_check(walks >= 300, "gold walks between the beds (%d tiles)" % walks)
	_check(_site_in_room(dm, "font", "deep"), "the Font's door in the far grove")

func _test_spire() -> void:
	print("-- the Silent Spire --")
	var dm := _build("spire_0")
	_place_basics(dm, "spire_0")
	_check(dm.has_cliffs and dm.cliff_face_tiles.size() >= 20 and dm.step_tiles.size() >= 4,
		"terraces: rock faces (%d) and steps (%d)" % [dm.cliff_face_tiles.size(), dm.step_tiles.size()])
	var reach := _reach(dm)
	var top := 0
	for c in reach:
		top = maxi(top, dm.get_elevation(c))
	_check(dm.get_elevation(dm.player_start) == 0 and top >= DungeonManager.MOUNTAIN_TIER_STEP * 2, "it climbs (level %d)" % top)
	var i := dm.get_site_by_id("belfry")
	_check(i >= 0 and dm.belfry_door_cell == (dm.site_nodes[i]["grid_pos"] if i >= 0 else Vector2i(-2, -2)), "the Belfry's door at the top")
	if i >= 0:
		var door: Vector2i = dm.site_nodes[i]["grid_pos"]
		_check(reach.has(door) and dm.get_elevation(door) >= DungeonManager.MOUNTAIN_TIER_STEP * 2 and dm.is_wall(door + Vector2i(0, -1)),
			"high up, set in the rock")
	var types := _types(dm)
	_check(Enemy.EnemyType.ASH_HARPY in types and Enemy.EnemyType.MIND_EATER in types, "harpies over the heights, mind eaters on the ledges")

func _test_causeway() -> void:
	print("-- the Sundered Causeway --")
	var dm := _build("causeway_0")
	var reach := _place_basics(dm, "causeway_0")
	_check(dm.water_texture_path() == dm.heaven_art("abyss") and _pool_count(dm) >= 120, "a gulf no one crosses on foot (%d tiles)" % _pool_count(dm))
	_check(dm.rift_bridges.size() >= 2, "bridges over it (%d)" % dm.rift_bridges.size())
	var without := _reach(dm, dm.bridge_cells)
	_check(without.size() < reach.size() - dm.bridge_cells.size(), "and the bridges are the only ways over")
	var isle_types := true
	var isles := 0
	for room in dm.rooms:
		if room.get("isle", false):
			isles += 1
	for z in dm.spawn_zones:
		for k in range(z["spawn_points"].size()):
			for room in dm.rooms:
				if room.get("isle", false) and z["spawn_points"][k] in room["cells"]:
					isle_types = isle_types and z["enemy_types"][k] in [Enemy.EnemyType.CHERUB, Enemy.EnemyType.ASH_HARPY]
	_check(isles >= 1 and isle_types, "islands in the gulf, kept by winged things (%d)" % isles)
	_check(_site_in_room(dm, "rent", "deep"), "the Rent's door on the far landing")

func _test_sealed_rooms() -> void:
	print("-- the sealed rooms --")
	var want := {
		"altar": {Enemy.EnemyType.DJINN: 1, Enemy.EnemyType.CHERUB: 2, Enemy.EnemyType.SUCCUBUS: 2, Enemy.EnemyType.MIND_EATER: 1},
		"font": {Enemy.EnemyType.DJINN: 2, Enemy.EnemyType.CHERUB: 2, Enemy.EnemyType.SUCCUBUS: 1, Enemy.EnemyType.MIND_EATER: 1},
		"belfry": {Enemy.EnemyType.DJINN: 1, Enemy.EnemyType.DEMON: 1, Enemy.EnemyType.MIND_EATER: 1, Enemy.EnemyType.CHERUB: 2, Enemy.EnemyType.ASH_HARPY: 2},
		"rent": {Enemy.EnemyType.DJINN: 2, Enemy.EnemyType.DEMON: 2, Enemy.EnemyType.MIND_EATER: 1, Enemy.EnemyType.CHERUB: 2, Enemy.EnemyType.ASH_HARPY: 1},
	}
	for key in want:
		var dm := _build(key)
		_check(DungeonManager.is_boss_room(key) and DungeonManager.is_guardian_room(key) and DungeonManager.boss_room_key(key) == key,
			"%s: a sealed room held by guardians" % dm.get_location_name())
		_check(_heaven_art(dm) and dm.get_site_by_id("exit") < 0 and dm.get_site_by_id("descend") < 0, "  in Heaven's art, sealed while they stand")
		var reach := _reach(dm)
		var count := {}
		var placed := true
		for g in dm.guardian_placements:
			count[g["type"]] = int(count.get(g["type"], 0)) + 1
			placed = placed and reach.has(g["cell"])
		_check(count == want[key] and placed, "  its guardians, all on open floor (%s)" % [count])
		_check(reach.size() == _floor_count(dm), "  all its floor in reach")
		_check(dm.spawn_zones.is_empty() and dm.fountain_nodes.is_empty() and dm.chest_nodes.is_empty(), "  nothing else: a fight")
		var cleared := _build(key, 3, [key])
		_check(cleared.get_site_by_id("exit") >= 0, "  once they have fallen, the way out stands open")
	var belfry := _build("belfry")
	var ex := _build("belfry", 3, ["belfry"])
	_check(belfry.player_start.y > belfry.belfry_cell.y + 6, "the Belfry is entered from the stair below (the south)")
	if ex.get_site_by_id("exit") >= 0:
		var exit_node: Node3D = ex.site_nodes[ex.get_site_by_id("exit")]["node"]
		_check(exit_node.position.z > ex.grid_manager.grid_to_world(ex.player_start).z, "  and its way back is behind the hero, to the south")
	var rent := _build("rent", 3, ["rent"])
	var d := rent.get_site_by_id("descend")
	_check(d >= 0 and rent.site_nodes[d]["grid_pos"] == rent.rent_lip, "the Rent, once open, has its way down at the lip of the tear")
	var lip_by_tear := false
	for dd in [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, -1)]:
		lip_by_tear = lip_by_tear or rent.is_water(rent.rent_lip + dd)
	_check(lip_by_tear and rent.water_texture_path() == rent.heaven_art("abyss"), "  beside the tear in Heaven's floor")

func _test_levels() -> void:
	print("-- level bands --")
	var seen := {}
	var ok := true
	for t in ROSTER:
		var k: String = Enemy.EnemyType.keys()[t]
		var lvl: int = EnemyDefs.DEFS[k]["intended_level"]
		seen[k] = lvl
		if t in [Enemy.EnemyType.CHERUB, Enemy.EnemyType.DJINN]:
			ok = ok and lvl >= 33 and lvl <= 35
		else:
			ok = ok and lvl >= 26 and lvl <= 28
	_check(ok, "Heaven's host at its band (33-35), the invaders at theirs (26-28): %s" % [seen])
	_check(EnemyDefs.DEFS["CORRUPTED_ARCHANGEL"].get("mockup", false), "the Corrupted Archangel is still a mock-up: placed nowhere")
	for id in ["", "sanctum_0", "garden_0", "spire_0", "causeway_0"]:
		_check(not Enemy.EnemyType.CORRUPTED_ARCHANGEL in _types(_build(id)), "  not in %s" % (id if id != "" else "World 3"))

# ---- in the game ----

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _dismiss(main) -> void:
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame

func _find_main() -> Node:
	for child in get_root().get_children():
		if child.get_script() and "current_interior_id" in child and not child.is_queued_for_deletion():
			return child
	return null

func _boot(interior: String, level: int = 3, ch: CharacterData = null) -> Node:
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", ch if ch else CharacterData.create_brad())
	main.set("current_world_level", level)
	main.set("current_interior_id", interior)
	get_root().add_child(main)
	await _settle()
	await _dismiss(main)
	return main

func _stand(main, cell: Vector2i) -> void:
	main.player.position = main._ground_pos(cell)
	main.player.target_position = main.player.position

func _living(main, type: int = -1) -> Array:
	var out: Array = []
	for e in main.enemy_spawner.get_living_enemies():
		if type < 0 or e.enemy_type == type:
			out.append(e)
	return out

func _kill(e: Enemy) -> void:
	e.take_damage(999999, true, DamageTypes.Type.PHYSICAL, true)

func _test_sanctum_round_trip() -> void:
	print("-- the surface -> the Sanctum -> the Altar -> back --")
	var main = await _boot("")
	var i: int = main.dungeon_manager.get_site_by_id("sanctum_0")
	_check(i >= 0, "the live surface has the Sanctum's door")
	if i < 0:
		main.queue_free()
		return
	var outside: Vector2i = main.dungeon_manager.site_nodes[i]["grid_pos"]
	_stand(main, outside)
	_check(main._try_interact_site(), "Shift at the door")
	await _settle()
	var san = _find_main()
	_check(san != null and san.current_interior_id == "sanctum_0" and san.current_world_level == 3, "enters the Sanctum")
	if san == null:
		return
	await _dismiss(san)
	var d: int = san.dungeon_manager.get_site_by_id("altar")
	var door: Vector2i = san.dungeon_manager.site_nodes[d]["grid_pos"]
	_stand(san, door)
	san._try_interact_site()
	await _settle()
	var alt = _find_main()
	_check(alt != null and alt.current_interior_id == "altar" and alt.parent_interior_id == "sanctum_0", "the Altar's door leads in, remembering the Sanctum")
	if alt == null:
		return
	await _dismiss(alt)
	_check(alt.boss_room_mode, "a sealed room")
	var keepers: Array = _living(alt)
	_check(keepers.size() == 6 and _living(alt, Enemy.EnemyType.DJINN).size() == 1, "its keepers wait, a djinn on the altar (%d)" % keepers.size())
	for k in range(keepers.size() - 1):
		_kill(keepers[k])
	await _settle(4)
	_check(alt.dungeon_manager.get_site_by_id("exit") < 0, "while one stands, the doors stay shut")
	for e in _living(alt):
		_kill(e)
	await _settle(4)
	_check(alt.dungeon_manager.get_site_by_id("exit") >= 0 and alt.current_character.has_defeated_boss("altar"), "the last falls: the way out opens, remembered")
	alt._exit_interior()
	await _settle()
	var back = _find_main()
	_check(back != null and back.current_interior_id == "sanctum_0", "leaving returns to the Sanctum")
	if back:
		await _dismiss(back)
		_check(back.grid_manager.world_to_grid(back.player.position) == door, "at the Altar's door")
		back._exit_interior()
		await _settle()
		var top = _find_main()
		_check(top != null and top.current_interior_id == "" and top.grid_manager.world_to_grid(top.player.position) == outside,
			"and the Sanctum's way out returns to its door on Heaven's surface")
		if top:
			top.queue_free()
	await _settle()

func _test_font_fight() -> void:
	print("-- the Garden -> the Sickened Font --")
	var gar = await _boot("garden_0")
	_check(gar.dungeon_manager.interior_kind == "garden" and gar.grid_manager.world_to_grid(gar.player.position) == gar.dungeon_manager.player_start,
		"the Garden boots, the hero at its gate")
	gar._enter_interior("font", "The Sickened Font")
	await _settle()
	var main = _find_main()
	_check(main != null and main.current_interior_id == "font" and main.parent_interior_id == "garden_0", "the Font's door leads in")
	if main == null:
		return
	await _dismiss(main)
	_check(_living(main, Enemy.EnemyType.DJINN).size() == 2 and _living(main).size() == 6, "two djinn and their keepers")
	for e in _living(main):
		_kill(e)
	await _settle(4)
	_check(main.dungeon_manager.get_site_by_id("exit") >= 0 and main.current_character.has_defeated_boss("font"), "they fall: the way out opens, remembered")
	main.queue_free()
	await _settle()

func _test_rent_fight() -> void:
	print("-- the Rent: the way down --")
	var spire = await _boot("spire_0")
	var b: int = spire.dungeon_manager.get_site_by_id("belfry")
	if b >= 0:
		_stand(spire, spire.dungeon_manager.site_nodes[b]["grid_pos"])
		spire._try_interact_site()
		await _settle()
		var bel = _find_main()
		_check(bel != null and bel.current_interior_id == "belfry" and bel.parent_interior_id == "spire_0" and bel.boss_room_mode,
			"the door at the Spire's top leads into the Belfry, sealed")
		if bel:
			_check(_living(bel).size() == 7, "its keepers wait (%d)" % _living(bel).size())
			bel.queue_free()
	else:
		_check(false, "the Spire has the Belfry's door")
		spire.queue_free()
	await _settle()
	var main = await _boot("rent")
	_check(main.boss_room_mode and main.dungeon_manager.get_site_by_id("descend") < 0 and main.dungeon_manager.get_site_by_id("exit") < 0,
		"sealed: no way down, no way back")
	var wardens: Array = _living(main)
	_check(wardens.size() == 8, "its wardens wait (%d)" % wardens.size())
	for e in wardens:
		_kill(e)
	await _settle(4)
	_check(main.dungeon_manager.get_site_by_id("descend") >= 0 and main.dungeon_manager.get_site_by_id("exit") >= 0,
		"the last falls: the way down opens, and the way back")
	_check(main.current_character.has_defeated_boss("rent"), "the Rent is remembered as open")
	_stand(main, main.dungeon_manager.rent_lip)
	var went: bool = main._try_interact_site()
	await _settle()
	var next = _find_main()
	_check(went and next != null and next.current_world_level == 4 and next.current_interior_id == "", "Shift at the lip goes down to the next world")
	if next:
		next.queue_free()
	await _settle()

func _test_breach_to_heaven_and_back() -> void:
	print("-- up through the Breach, and back down --")
	var ch := CharacterData.create_brad()
	ch.mark_boss_defeated("breach")
	var br = await _boot("breach", 2, ch)
	var up: int = br.dungeon_manager.get_site_by_id("ascend")
	_check(up >= 0, "the open Breach has its way up")
	if up < 0:
		br.queue_free()
		return
	_stand(br, br.dungeon_manager.breach_gate_cell)
	br._try_interact_site()
	await _settle()
	var heaven = _find_main()
	_check(heaven != null and heaven.current_world_level == 3 and heaven.current_interior_id == "", "the way up arrives in Heaven")
	if heaven == null:
		return
	await _dismiss(heaven)
	var arrive: int = heaven.dungeon_manager.get_site_by_id(DungeonManager.HEAVEN_ARRIVAL_ID)
	var at: Vector2i = heaven.grid_manager.world_to_grid(heaven.player.position)
	_check(arrive >= 0 and at == heaven.dungeon_manager.site_nodes[arrive]["grid_pos"], "the hero stands at the way back down")
	_check(heaven._try_interact_site(), "Shift there")
	await _settle()
	var down = _find_main()
	_check(down != null and down.current_world_level == 2 and down.current_interior_id == "breach" and down.parent_interior_id == "ascent_0",
		"goes back down into the Breach, the Ashen Stair below it")
	if down:
		await _dismiss(down)
		_check(down.grid_manager.world_to_grid(down.player.position) == down.dungeon_manager.breach_gate_cell, "at its gate")
		_check(_living(down).is_empty() and down.dungeon_manager.get_site_by_id("exit") >= 0, "the cleared Breach stays open")
		down.queue_free()
	await _settle()
