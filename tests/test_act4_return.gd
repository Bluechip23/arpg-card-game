extends SceneTree

## Act 4 — the Earth returned to (designer, 2026-11-09: "go ahead and build
## Act 4"; places & enemies only — the story, quests, dialogue and the FINAL
## BOSS stay [TBD]):
##  - World 4 is the corrupted Earth, "The Blighted Frontier": World 1's
##    Earth through EARTH_RETURN_ART's stand-ins, with tears of Hell (lava,
##    the blight) and Heaven (crystal, pale stone) in it; the Amber Wastes'
##    desert is worn by no world now.
##  - Its host: the Earth's own creatures (the Act 1 roster) with the
##    Underworld's and Heaven's among them, all at Act 4's band (above
##    Act 3's).
##  - Four places, each with a sealed room held by guardians of all three
##    planes (GUARDIAN_ROOMS): the Forsaken Hamlet (the Blighted Green), the
##    Smouldering Vale (the Hellmouth), the Shattered Basilica (the Fallen
##    Reliquary) and, at the far edge, the Riven Heights (the Confluence —
##    the final chamber: its boss slot empty, [TBD], a guard gauntlet for now).
##  - The hero arrives from the Rent by the way back up to it.
## Run: godot --headless --path . --script tests/test_act4_return.gd

var failures: int = 0

## The planes Act 4 draws from (STORY.md 5.4): the Earth habitats' built
## creatures, the Underworld's, Heaven's.
const EARTH := [Enemy.EnemyType.WOLF, Enemy.EnemyType.BUGBEAR, Enemy.EnemyType.MINI_BEAR, Enemy.EnemyType.GIANT_HAWK,
	Enemy.EnemyType.SKELETON, Enemy.EnemyType.ZOMBIE, Enemy.EnemyType.CRYPT_CRAWLER, Enemy.EnemyType.WEREWOLF,
	Enemy.EnemyType.VAMPIRE, Enemy.EnemyType.INFECTED_HUNTER, Enemy.EnemyType.GIANT_BEAVER, Enemy.EnemyType.LARGE_BEAR,
	Enemy.EnemyType.TREANT, Enemy.EnemyType.GRAVE_TITAN, Enemy.EnemyType.WEREGOAT, Enemy.EnemyType.SABERTOOTH,
	Enemy.EnemyType.SNOW_WRAITH, Enemy.EnemyType.ICE_TROLL, Enemy.EnemyType.ROC, Enemy.EnemyType.WYVERN,
	Enemy.EnemyType.WHITE_MANTICORE, Enemy.EnemyType.FIRE_MAGE, Enemy.EnemyType.FIRE_GOBLIN_SOLDIER,
	Enemy.EnemyType.FIRE_GOBLIN_MAGE, Enemy.EnemyType.FIRE_GOBLIN_SHAMAN, Enemy.EnemyType.ARMORED_TROLL]
const HELL := [Enemy.EnemyType.SPECTER, Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.MAGMA_SPIDER, Enemy.EnemyType.MIND_EATER,
	Enemy.EnemyType.DEMON, Enemy.EnemyType.ASH_HARPY, Enemy.EnemyType.IFRIT]
const HEAVEN := [Enemy.EnemyType.CHERUB, Enemy.EnemyType.DJINN]
const PLACES := {"hamlet_0": ["hamlet", "The Forsaken Hamlet", "green"],
	"vale_0": ["vale", "The Smouldering Vale", "hellmouth"],
	"basilica_0": ["basilica", "The Shattered Basilica", "reliquary"],
	"riven_0": ["riven", "The Riven Heights", "confluence"]}

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
	_test_amber_wastes_shelved()
	_test_hamlet()
	_test_vale()
	_test_basilica()
	_test_riven()
	_test_sealed_rooms()
	_test_confluence()
	_test_levels()
	await _test_band_in_game()
	await _test_rent_to_earth_and_back()
	await _test_hamlet_round_trip()
	await _test_confluence_fight()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _build(interior: String, level: int = 4, cleared: Array = []) -> DungeonManager:
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

func _blight_count(dm: DungeonManager) -> int:
	var n := 0
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_floor(Vector2i(x, z)) and dm.is_trail(Vector2i(x, z)):
				n += 1
	return n

func _types(dm: DungeonManager) -> Array:
	var out: Array = []
	for z in dm.spawn_zones:
		out.append_array(z["enemy_types"])
	return out

func _roster_ok(types: Array) -> bool:
	for t in types:
		if not (t in EARTH or t in HELL or t in HEAVEN):
			return false
	return true

## At least one of each plane among `types`.
func _three_planes(types: Array) -> bool:
	var e := false
	var h := false
	var v := false
	for t in types:
		e = e or t in EARTH
		h = h or t in HELL
		v = v or t in HEAVEN
	return e and h and v

func _site_in_room(dm: DungeonManager, id: String, kind: String) -> bool:
	var i := dm.get_site_by_id(id)
	if i < 0:
		return false
	for room in dm.rooms:
		if room["kind"] == kind and (room["rect"] as Rect2i).grow(1).has_point(dm.site_nodes[i]["grid_pos"]):
			return true
	return false

## Spawn points on open floor the start can walk to (never lava or a bridge).
func _spawns_ok(dm: DungeonManager, reach: Dictionary) -> bool:
	for z in dm.spawn_zones:
		for p in z["spawn_points"]:
			if not reach.has(p) or dm.bridge_cells.has(p) or dm.is_water(p):
				return false
	return true

## Act 4's look: every slot read from EARTH_RETURN_ART (the stand-ins).
func _earth_art(dm: DungeonManager) -> bool:
	var floor_slot := "floor"
	var trail_slot := "blight"
	match dm.interior_kind:
		"basilica", "reliquary":
			floor_slot = "heaven_floor"
			trail_slot = "heaven_trail"
		"hellmouth":
			floor_slot = "hell_floor"
	return dm.earth_return_land() and dm.get_palette()["name"] == "The Blighted Frontier" \
		and dm.floor_texture_path() == dm.earth_art(floor_slot) and dm.trail_texture_path() == dm.earth_art(trail_slot) \
		and dm.wall_texture_path() == dm.earth_art("wall") and dm.cliff_strip_path() == dm.earth_art("cliff") \
		and dm.water_texture_path() == dm.earth_art("lava") and dm.ground_atlas_path() == "" \
		and dm._prop_biome() in ["field", "cursed", "heaven"]

func _place_basics(dm: DungeonManager, id: String) -> Dictionary:
	var spec: Array = PLACES[id]
	_check(dm.interior_kind == spec[0] and dm.get_location_name() == spec[1], "its own kind and name (%s)" % spec[1])
	_check(dm.act4_place() and not DungeonManager.is_boss_room(id), "an Act 4 place to cross, not a sealed room")
	_check(_earth_art(dm), "it wears Act 4's (stand-in) art")
	var reach := _reach(dm)
	_check(reach.size() == _floor_count(dm), "every tile of it can be walked to (%d)" % reach.size())
	_check(dm.get_site_by_id("exit") >= 0, "a way back out")
	var types := _types(dm)
	_check(types.size() >= 8 and _roster_ok(types), "the Earth's, Hell's and Heaven's creatures only (%d)" % types.size())
	_check(_three_planes(types), "all three planes among them")
	_check(_spawns_ok(dm, reach), "every creature stands where the hero can reach")
	_check(dm.fountain_nodes.size() == 1 and dm.chest_nodes.size() >= 2, "a fountain and chests (%d)" % dm.chest_nodes.size())
	var tears := {}
	for t in dm.blight_tears:
		tears[t["plane"]] = true
	_check(not dm.blight_tears.is_empty() or not dm._hell_ground.is_empty(), "reality torn in it (%s)" % [tears.keys()])
	return reach

# ---- the surface ----

func _test_surface() -> void:
	print("-- World 4 is the Earth returned to --")
	var dm := _build("", 4)
	_check(_earth_art(dm) and dm.art_world() == 1 and dm._natural_boundary(),
		"Earth's palette and stand-in art (World 1's grass), its fields ending in trees")
	_check(dm.get_location_name() == "World 4 — The Blighted Frontier", "its name (%s)" % dm.get_location_name())
	_check(_pool_count(dm) > 0 and dm.lava_pool_centres.size() > 0, "Hell's lava welling up through it (%d tiles)" % _pool_count(dm))
	var hell := 0
	var heaven := 0
	for t in dm.blight_tears:
		if t["plane"] == "hell":
			hell += 1
		elif t["plane"] == "heaven":
			heaven += 1
	_check(hell >= 3 and heaven >= 2, "tears of Hell (%d) and of Heaven (%d)" % [hell, heaven])
	var blighted := true
	for t in dm.blight_tears:
		if t["plane"] != "hell":
			continue
		var c: Vector2i = t["c"]
		var near := false
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				var q := c + Vector2i(dx, dz)
				near = near or (dm.is_floor(q) and dm.is_trail(q))
		blighted = blighted and near
	_check(blighted, "the blight on the ground round every hell tear")
	_check(dm._plane_at(dm.player_start.x, dm.player_start.y) == "earth", "the start field is the Earth's own")
	var caves := 0
	var halls := 0
	for s in dm.site_nodes:
		if s["kind"] == "cave":
			caves += 1
		elif s["kind"] == "building":
			halls += 1
	_check(caves + halls == 3, "lean: two caves and a ruined hall besides its places (%d, %d)" % [caves, halls])
	for id in PLACES:
		var i := dm.get_site_by_id(id)
		_check(i >= 0, "the way into %s" % PLACES[id][1])
		if i >= 0:
			var site: Dictionary = dm.site_nodes[i]
			_check(dm.is_floor(site["grid_pos"]) and site["display_name"] == PLACES[id][1] and site["kind"] == PLACES[id][0]
				and site["footprint"].size() == 9, "  walkable, named, on a raised block")
	var far := dm.get_site_by_id("riven_0")
	var eastmost := far >= 0
	for s in dm.site_nodes:
		if far >= 0 and s["footprint"].size() > 0:
			eastmost = eastmost and s["grid_pos"].x <= dm.site_nodes[far]["grid_pos"].x
	_check(eastmost, "the Riven Heights are the farthest east: the approach to the final battle")
	var hamlet := dm.get_site_by_id("hamlet_0")
	_check(hamlet >= 0 and dm.site_nodes[hamlet]["grid_pos"].x < dm.GRID_W / 3, "the Hamlet near the arrival, in the west")
	var arrive := dm.get_site_by_id(DungeonManager.EARTH_ARRIVAL_ID)
	_check(arrive >= 0 and dm.site_nodes[arrive]["kind"] == DungeonManager.EARTH_ARRIVAL_ID
		and (dm.site_nodes[arrive]["grid_pos"] - dm.player_start).length() < 5.0,
		"the way back up to the Rent stands in the start field, where the hero arrives")
	_check(_reach(dm).size() == _floor_count(dm), "the surface is all one piece")
	var reach := _reach(dm)
	_check(_spawns_ok(dm, reach), "every creature on it stands where the hero can reach")
	var types := _types(dm)
	_check(types.size() >= 20 and _roster_ok(types), "the Earth's creatures and the invaders on its surface (%d)" % types.size())
	_check(_three_planes(types), "all three planes on the surface")
	_check(Enemy.EnemyType.IFRIT in types and Enemy.EnemyType.DJINN in types and Enemy.EnemyType.LARGE_BEAR in types,
		"its arena: an elite of each plane")
	for lvl in [1, 2, 3]:
		var other := _build("", lvl)
		var none := other.get_site_by_id(DungeonManager.EARTH_ARRIVAL_ID) < 0 and not other.earth_return_land()
		for id in PLACES:
			none = none and other.get_site_by_id(id) < 0
		_check(none and other.spawn_band_floor() == 0, "World %d has none of Act 4's places, nor its band" % lvl)
	var again := _build("", 4)
	_check(again.blight_tears == dm.blight_tears and _types(again) == types, "the same Earth every visit")

func _test_amber_wastes_shelved() -> void:
	print("-- the Amber Wastes' desert is worn by no world --")
	var worn := false
	for lvl in [1, 2, 3, 4, 5]:
		var dm := _build("", lvl)
		worn = worn or dm.get_palette()["name"] == "Amber Wastes" or dm.art_world() == 2 or dm._prop_biome() == "desert"
	_check(not worn, "no world's surface wears the desert")
	var heaven := _build("", 3)
	_check(heaven.heaven_art("site_sanctum")[0] == "desert_door" and heaven.heaven_art("trail").ends_with("desert_sand.png"),
		"its door and sand still stand in for Heaven's (HEAVEN_ART)")

# ---- the places ----

func _test_hamlet() -> void:
	print("-- the Forsaken Hamlet --")
	var dm := _build("hamlet_0")
	_place_basics(dm, "hamlet_0")
	_check(dm._natural_boundary(), "its edges and hedges are the Earth's trees, rocks and bushes")
	var beds := 0
	for room in dm.rooms:
		if room.get("part", "") == "bed":
			beds += 1
	_check(beds >= 8, "hedged crofts (%d)" % beds)
	var cottages := dm.hamlet_cottages.size() >= 6
	for h in dm.hamlet_cottages:
		var at: Vector2i = h["cell"]
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			cottages = cottages and not dm.is_floor(at + d) and dm.hamlet_cottage_tiles.has(at + d)
	_check(cottages, "a ruined cottage in the crofts (%d)" % dm.hamlet_cottages.size())
	_check(dm.is_water(dm.garden_basin) and not dm.is_floor(dm.garden_basin), "the green's pond welled up as lava")
	_check(dm._plane_at(dm.garden_basin.x, dm.garden_basin.y + 4) == "hell" and _blight_count(dm) >= 20,
		"the blight round it (%d tiles)" % _blight_count(dm))
	var heaven := false
	for t in dm.blight_tears:
		heaven = heaven or t["plane"] == "heaven"
	_check(heaven, "Heaven fallen in a croft")
	_check(_site_in_room(dm, "green", "deep"), "the Blighted Green's gate in the far croft")

func _test_vale() -> void:
	print("-- the Smouldering Vale --")
	var dm := _build("vale_0")
	var reach := _place_basics(dm, "vale_0")
	_check(_pool_count(dm) >= 120, "a river of lava through the valley (%d tiles)" % _pool_count(dm))
	_check(dm.rift_bridges.size() >= 2, "vein bridges over it (%d)" % dm.rift_bridges.size())
	var without := _reach(dm, dm.bridge_cells)
	_check(without.size() < reach.size() - dm.bridge_cells.size(), "and the bridges are the only ways over")
	_check(dm._hell_ground.size() >= 100 and _blight_count(dm) >= 60, "Hell's ground and the blight along the lava")
	var earth := 0
	for c in reach:
		if dm._plane_at(c.x, c.y) == "earth":
			earth += 1
	_check(earth >= 100, "the Earth's own grass beyond it (%d tiles)" % earth)
	var isle_types := true
	for z in dm.spawn_zones:
		for k in range(z["spawn_points"].size()):
			for room in dm.rooms:
				if room.get("isle", false) and z["spawn_points"][k] in room["cells"]:
					isle_types = isle_types and z["enemy_types"][k] in [Enemy.EnemyType.MAGMA_SPIDER, Enemy.EnemyType.CHERUB, Enemy.EnemyType.ASH_HARPY]
	_check(isle_types, "spiders nesting on the islands, winged things over them")
	_check(_site_in_room(dm, "hellmouth", "deep"), "the Hellmouth's door on the far landing")

func _test_basilica() -> void:
	print("-- the Shattered Basilica --")
	var dm := _build("basilica_0")
	_place_basics(dm, "basilica_0")
	var sanctum := _build("sanctum_0", 4)
	_check(dm.sanctum_pillars.size() < sanctum.sanctum_pillars.size() and dm.sanctum_pillars.size() >= 6,
		"the Sanctum's cross, a third of its columns fallen (%d of %d)" % [dm.sanctum_pillars.size(), sanctum.sanctum_pillars.size()])
	var pillars := true
	for c in dm.sanctum_pillars:
		pillars = pillars and not dm.is_floor(c)
	_check(pillars, "the standing columns stand in the way")
	var earth := false
	var hell := false
	for t in dm.blight_tears:
		earth = earth or t["plane"] == "earth"
		hell = hell or t["plane"] == "hell"
	_check(dm._plane_at(-99, -99) == "heaven" and earth and hell, "Heaven's floor, the Earth growing through, Hell at the crossing")
	_check(_pool_count(dm) >= 12, "its fonts welling lava")
	_check(dm.is_trail(Vector2i(10, dm.GRID_H / 2)), "Heaven's gold runner down the nave")
	_check(_site_in_room(dm, "reliquary", "deep"), "the Reliquary's door in the apse")

func _test_riven() -> void:
	print("-- the Riven Heights --")
	var dm := _build("riven_0")
	_place_basics(dm, "riven_0")
	_check(dm.has_cliffs and dm.cliff_face_tiles.size() >= 20 and dm.step_tiles.size() >= 4,
		"terraces: rock faces (%d) and steps (%d)" % [dm.cliff_face_tiles.size(), dm.step_tiles.size()])
	var reach := _reach(dm)
	var top := 0
	for c in reach:
		top = maxi(top, dm.get_elevation(c))
	_check(dm.get_elevation(dm.player_start) == 0 and top >= DungeonManager.MOUNTAIN_TIER_STEP * 2, "it climbs (level %d)" % top)
	_check(_pool_count(dm) > 0, "lava on its ledges")
	var i := dm.get_site_by_id("confluence")
	_check(i >= 0 and dm.confluence_door_cell == (dm.site_nodes[i]["grid_pos"] if i >= 0 else Vector2i(-2, -2)), "the Confluence's door at the top")
	if i >= 0:
		var door: Vector2i = dm.site_nodes[i]["grid_pos"]
		_check(reach.has(door) and dm.get_elevation(door) >= DungeonManager.MOUNTAIN_TIER_STEP * 2 and dm.is_wall(door + Vector2i(0, -1)),
			"high up, set in the rock")
	var types := _types(dm)
	_check(Enemy.EnemyType.ICE_TROLL in types and Enemy.EnemyType.ROC in types, "an ice troll and a roc at the top")
	_check(Enemy.EnemyType.CHERUB in types and Enemy.EnemyType.ASH_HARPY in types and Enemy.EnemyType.WEREGOAT in types,
		"fliers over the heights, the mountains' own below")

func _test_sealed_rooms() -> void:
	print("-- the sealed rooms --")
	var want := {
		"green": {Enemy.EnemyType.LARGE_BEAR: 1, Enemy.EnemyType.WEREWOLF: 1, Enemy.EnemyType.VAMPIRE: 1,
			Enemy.EnemyType.DEMON: 1, Enemy.EnemyType.SUCCUBUS: 1, Enemy.EnemyType.CHERUB: 2},
		"hellmouth": {Enemy.EnemyType.IFRIT: 2, Enemy.EnemyType.FIRE_MAGE: 1, Enemy.EnemyType.DEMON: 2, Enemy.EnemyType.CHERUB: 2},
		"reliquary": {Enemy.EnemyType.DJINN: 2, Enemy.EnemyType.CHERUB: 2, Enemy.EnemyType.WYVERN: 1,
			Enemy.EnemyType.WHITE_MANTICORE: 1, Enemy.EnemyType.MIND_EATER: 1},
		"confluence": {Enemy.EnemyType.LARGE_BEAR: 1, Enemy.EnemyType.ICE_TROLL: 1, Enemy.EnemyType.WEREWOLF: 1,
			Enemy.EnemyType.IFRIT: 1, Enemy.EnemyType.DEMON: 2, Enemy.EnemyType.DJINN: 2, Enemy.EnemyType.CHERUB: 1},
	}
	for key in want:
		var dm := _build(key)
		_check(DungeonManager.is_boss_room(key) and DungeonManager.is_guardian_room(key) and DungeonManager.boss_room_key(key) == key,
			"%s: a sealed room held by guardians" % dm.get_location_name())
		_check(_earth_art(dm) and dm.get_site_by_id("exit") < 0, "  in Act 4's art, sealed while they stand")
		var reach := _reach(dm)
		var count := {}
		var placed := true
		var types: Array = []
		for g in dm.guardian_placements:
			count[g["type"]] = int(count.get(g["type"], 0)) + 1
			placed = placed and reach.has(g["cell"])
			types.append(g["type"])
		_check(count == want[key] and placed, "  its guardians, all on open floor (%s)" % [count])
		_check(_three_planes(types), "  of all three planes")
		_check(reach.size() == _floor_count(dm), "  all its floor in reach")
		_check(dm.spawn_zones.is_empty() and dm.fountain_nodes.is_empty() and dm.chest_nodes.is_empty(), "  nothing else: a fight")
		var cleared := _build(key, 4, [key])
		_check(cleared.get_site_by_id("exit") >= 0, "  once they have fallen, the way out stands open")
	var mouth := _build("hellmouth")
	_check(mouth.floor_texture_path() == mouth.earth_art("hell_floor") and mouth.rift_bridges.size() == 2,
		"the Hellmouth: Hell's earth, a lava lake and two bridges")
	var rel := _build("reliquary")
	_check(rel.obstacle_tiles.has(rel.altar_cell + Vector2i(1, 0)), "the Reliquary: its relic stands in the way")

func _test_confluence() -> void:
	print("-- the Confluence: the final chamber, its boss [TBD] --")
	var dm := _build("confluence")
	var boss := dm.confluence_boss_cell
	var reach := _reach(dm)
	_check(boss.x >= 0 and reach.has(boss), "the place where the final boss will stand: open floor, in reach")
	var clear := true
	for g in dm.guardian_placements:
		clear = clear and (g["cell"] - boss).length() > 2.5
	_check(clear, "the dais stands empty: no guardian on it (the boss is [TBD])")
	var types: Array = []
	for g in dm.guardian_placements:
		types.append(g["type"])
	_check(not Enemy.EnemyType.BOSS in types and not Enemy.EnemyType.CORRUPTED_ARCHANGEL in types
		and not Enemy.EnemyType.PIT_FIEND in types and not Enemy.EnemyType.GRANITE_COLOSSUS in types, "no boss invented, no mock-up")
	_check(dm.confluence_pillars.size() == 6, "a ring of columns round the dais")
	_check(dm.player_start.y > boss.y + 15, "entered from the stair below (the south), the dais at the far end")
	var r1 := 0
	var r3 := 0
	for g in dm.guardian_placements:
		if g["type"] in EARTH:
			r1 = maxi(r1, g["cell"].y)
		if g["type"] in HEAVEN:
			r3 = maxi(r3, g["cell"].y)
	_check(r1 > r3, "the gauntlet: the Earth's rank nearest the stair, Heaven's nearest the dais")
	var hell := false
	var heaven := false
	for t in dm.blight_tears:
		hell = hell or t["plane"] == "hell"
		heaven = heaven or t["plane"] == "heaven"
	_check(hell and heaven and _pool_count(dm) >= 10, "Hell's fire on one side, Heaven's fall on the other")
	var cleared := _build("confluence", 4, ["confluence"])
	if cleared.get_site_by_id("exit") >= 0:
		var exit_node: Node3D = cleared.site_nodes[cleared.get_site_by_id("exit")]["node"]
		_check(exit_node.position.z > cleared.grid_manager.grid_to_world(cleared.player_start).z, "its way back is behind the hero, to the south")

func _test_levels() -> void:
	print("-- level bands --")
	var top3 := 0
	for t in HEAVEN + HELL:
		top3 = maxi(top3, int(EnemyDefs.DEFS[Enemy.EnemyType.keys()[t]]["intended_level"]))
	_check(DungeonManager.ACT4_BAND > top3, "Act 4's band (%d) is above Act 3's highest (%d)" % [DungeonManager.ACT4_BAND, top3])
	for id in ["", "hamlet_0", "vale_0", "basilica_0", "riven_0", "confluence"]:
		_check(_build(id).spawn_band_floor() == DungeonManager.ACT4_BAND, "  %s raises its host to it" % (id if id != "" else "World 4"))
	_check(_build("confluence", 1).spawn_band_floor() == DungeonManager.ACT4_BAND, "  an Act 4 room keeps it whichever world boots it")
	_check(_build("", 3).spawn_band_floor() == 0 and _build("causeway_0", 3).spawn_band_floor() == 0, "  Heaven keeps its own bands")
	var mock := true
	for id in ["", "hamlet_0", "vale_0", "basilica_0", "riven_0"]:
		for t in _types(_build(id)):
			mock = mock and not EnemyDefs.DEFS[Enemy.EnemyType.keys()[t]].get("mockup", false)
	_check(mock, "no design mock-up placed (the Pit Fiend, the Granite Colossus, the Corrupted Archangel stay out)")

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

func _boot(interior: String, level: int = 4, ch: CharacterData = null) -> Node:
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

func _test_band_in_game() -> void:
	print("-- the band, met in the game --")
	var main = await _boot("green")
	var bear: Array = _living(main, Enemy.EnemyType.LARGE_BEAR)
	var cherub: Array = _living(main, Enemy.EnemyType.CHERUB)
	_check(bear.size() == 1 and bear[0].get_intended_level() == DungeonManager.ACT4_BAND
		and cherub.size() == 2 and cherub[0].get_intended_level() == DungeonManager.ACT4_BAND,
		"the Green's Large Bear and cherubs stand at Act 4's band")
	var skel: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.SKELETON, main.player.position + Vector3(3, 0, 0))
	var scale: Dictionary = Enemy.passive_power_scale(DungeonManager.ACT4_BAND)
	_check(skel.get_intended_level() == DungeonManager.ACT4_BAND
		and skel.max_health == roundi(int(EnemyDefs.DEFS["SKELETON"]["health"]) * float(scale["hp"])),
		"a skeleton risen on the corrupted Earth: band %d, health %d" % [skel.get_intended_level(), skel.max_health])
	main.queue_free()
	await _settle()
	var w1 = await _boot("", 1)
	var skel1: Enemy = w1.enemy_spawner.spawn_enemy(Enemy.EnemyType.SKELETON, w1.player.position + Vector3(3, 0, 0))
	_check(skel1.get_intended_level() == int(EnemyDefs.DEFS["SKELETON"]["intended_level"]), "the Act 1 skeleton keeps its own band (%d)" % skel1.get_intended_level())
	w1.queue_free()
	await _settle()

func _test_rent_to_earth_and_back() -> void:
	print("-- down through the Rent, and back up --")
	var ch := CharacterData.create_brad()
	ch.mark_boss_defeated("rent")
	var rent = await _boot("rent", 3, ch)
	var down: int = rent.dungeon_manager.get_site_by_id("descend")
	_check(down >= 0, "the open Rent has its way down")
	if down < 0:
		rent.queue_free()
		return
	_stand(rent, rent.dungeon_manager.rent_lip)
	rent._try_interact_site()
	await _settle()
	var earth = _find_main()
	_check(earth != null and earth.current_world_level == 4 and earth.current_interior_id == "", "the way down arrives on the Earth")
	if earth == null:
		return
	await _dismiss(earth)
	var arrive: int = earth.dungeon_manager.get_site_by_id(DungeonManager.EARTH_ARRIVAL_ID)
	var at: Vector2i = earth.grid_manager.world_to_grid(earth.player.position)
	_check(arrive >= 0 and at == earth.dungeon_manager.site_nodes[arrive]["grid_pos"], "the hero stands at the way back up")
	_check(earth._try_interact_site(), "Shift there")
	await _settle()
	var up = _find_main()
	_check(up != null and up.current_world_level == 3 and up.current_interior_id == "rent" and up.parent_interior_id == "causeway_0",
		"goes back up into the Rent, the Sundered Causeway beyond it")
	if up:
		await _dismiss(up)
		_check(up.grid_manager.world_to_grid(up.player.position) == up.dungeon_manager.rent_lip, "at the lip of the tear")
		_check(_living(up).is_empty() and up.dungeon_manager.get_site_by_id("exit") >= 0, "the cleared Rent stays open")
		up.queue_free()
	await _settle()

func _test_hamlet_round_trip() -> void:
	print("-- the surface -> the Hamlet -> the Green -> back --")
	var main = await _boot("")
	var i: int = main.dungeon_manager.get_site_by_id("hamlet_0")
	_check(i >= 0, "the live surface has the Hamlet's way in")
	if i < 0:
		main.queue_free()
		return
	var outside: Vector2i = main.dungeon_manager.site_nodes[i]["grid_pos"]
	_stand(main, outside)
	_check(main._try_interact_site(), "Shift at it")
	await _settle()
	var ham = _find_main()
	_check(ham != null and ham.current_interior_id == "hamlet_0" and ham.current_world_level == 4, "enters the Hamlet")
	if ham == null:
		return
	await _dismiss(ham)
	var d: int = ham.dungeon_manager.get_site_by_id("green")
	var door: Vector2i = ham.dungeon_manager.site_nodes[d]["grid_pos"]
	_stand(ham, door)
	ham._try_interact_site()
	await _settle()
	var green = _find_main()
	_check(green != null and green.current_interior_id == "green" and green.parent_interior_id == "hamlet_0", "the Green's gate leads in, remembering the Hamlet")
	if green == null:
		return
	await _dismiss(green)
	_check(green.boss_room_mode, "a sealed room")
	var keepers: Array = _living(green)
	_check(keepers.size() == 7, "its keepers wait (%d)" % keepers.size())
	for k in range(keepers.size() - 1):
		_kill(keepers[k])
	await _settle(4)
	_check(green.dungeon_manager.get_site_by_id("exit") < 0, "while one stands, the hedges stay shut")
	for e in _living(green):
		_kill(e)
	await _settle(4)
	_check(green.dungeon_manager.get_site_by_id("exit") >= 0 and green.current_character.has_defeated_boss("green"), "the last falls: the way out opens, remembered")
	green._exit_interior()
	await _settle()
	var back = _find_main()
	_check(back != null and back.current_interior_id == "hamlet_0", "leaving returns to the Hamlet")
	if back:
		await _dismiss(back)
		_check(back.grid_manager.world_to_grid(back.player.position) == door, "at the Green's gate")
		back._exit_interior()
		await _settle()
		var top = _find_main()
		_check(top != null and top.current_interior_id == "" and top.grid_manager.world_to_grid(top.player.position) == outside,
			"and the Hamlet's way out returns to its door on the Earth's surface")
		if top:
			top.queue_free()
	await _settle()

func _test_confluence_fight() -> void:
	print("-- the Heights -> the Confluence --")
	var riven = await _boot("riven_0")
	var c: int = riven.dungeon_manager.get_site_by_id("confluence")
	_check(c >= 0, "the Heights have the Confluence's door")
	if c < 0:
		riven.queue_free()
		return
	_stand(riven, riven.dungeon_manager.site_nodes[c]["grid_pos"])
	riven._try_interact_site()
	await _settle()
	var main = _find_main()
	_check(main != null and main.current_interior_id == "confluence" and main.parent_interior_id == "riven_0" and main.boss_room_mode,
		"the door at the top leads into the Confluence, sealed")
	if main == null:
		return
	await _dismiss(main)
	var guard: Array = _living(main)
	_check(guard.size() == 9, "its guard gauntlet waits (%d)" % guard.size())
	var on_dais := false
	for e in guard:
		on_dais = on_dais or main.grid_manager.world_to_grid(e.position) == main.dungeon_manager.confluence_boss_cell
	_check(not on_dais, "no one on the dais: the final boss is [TBD]")
	for e in guard:
		_kill(e)
	await _settle(4)
	_check(main.dungeon_manager.get_site_by_id("exit") >= 0 and main.current_character.has_defeated_boss("confluence"),
		"the guard falls: the way out opens, remembered")
	_check(_living(main).is_empty(), "and the dais still stands empty")
	main.queue_free()
	await _settle()
