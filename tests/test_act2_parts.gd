extends SceneTree

## Act 2, parts 2-4 — the Underworld's later places (designer, 2026-11-09:
## "places & enemies only"; the story round them stays [TBD]):
##  - The Underworld's surface (World 2) has three more ways in: the Brimstone
##    Rift, the Citadel of Dis and, at its far (east) edge, the Ashen Stair.
##  - The Brimstone Rift: a canyon in the hell art split by lava no one
##    wades, its banks and islands joined by the cursed land pack's vein
##    bridges; ash harpies, magma spiders on the islands; its far landing the
##    door to the Crucible (two ifrits, sealed until both fall).
##  - The Citadel of Dis: courts and a pillared, paved great hall; its inner
##    court the door to the Throne of Dis (the court of Dis, sealed).
##  - The Ashen Stair: the Mountain Pass's terraces (one level a step) in the
##    hell art; at the top the Breach, held by its wardens; when the last
##    falls the way up opens to the next world, as Hell's Door leads down.
##  - Every creature is the Underworld's own, at its level band (26-28).
## Run: godot --headless --path . --script tests/test_act2_parts.gd

var failures: int = 0

const ROSTER := [Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.DEMON, Enemy.EnemyType.IFRIT,
	Enemy.EnemyType.MIND_EATER, Enemy.EnemyType.SPECTER, Enemy.EnemyType.MAGMA_SPIDER, Enemy.EnemyType.ASH_HARPY]

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
	_test_rift()
	_test_crucible()
	_test_citadel()
	_test_throne()
	_test_ascent()
	_test_breach()
	_test_levels()
	await _test_rift_round_trip()
	await _test_throne_fight()
	await _test_breach_fight()
	await _test_stair_in_game()
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

func _lava_count(dm: DungeonManager) -> int:
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

func _site_in_room(dm: DungeonManager, id: String, kind: String) -> bool:
	var i := dm.get_site_by_id(id)
	if i < 0:
		return false
	for room in dm.rooms:
		if room["kind"] == kind and (room["rect"] as Rect2i).grow(1).has_point(dm.site_nodes[i]["grid_pos"]):
			return true
	return false

## Spawn points on open floor the start can walk to.
func _spawns_ok(dm: DungeonManager, reach: Dictionary) -> bool:
	for z in dm.spawn_zones:
		for p in z["spawn_points"]:
			if not reach.has(p) or dm.bridge_cells.has(p):
				return false
	return true

func _hell_art(dm: DungeonManager) -> bool:
	return dm.act2_place() and dm.floor_texture_path().ends_with("cursed_floor.png") \
		and dm.water_texture_path().ends_with("water_lava.png") and dm.cliff_strip_path().ends_with("cursed_cliff.png") \
		and dm._prop_biome() == "cursed" and not dm._natural_boundary() and dm.get_palette()["name"] == "The Underworld"

func _test_surface() -> void:
	print("-- the Underworld's surface: three more ways in --")
	var dm := _build("", 2)
	var names := {"rift_0": "Brimstone Rift", "citadel_0": "Citadel of Dis", "ascent_0": "The Ashen Stair"}
	for id in names:
		var i := dm.get_site_by_id(id)
		_check(i >= 0, "World 2 has the way into %s" % names[id])
		if i >= 0:
			var site: Dictionary = dm.site_nodes[i]
			_check(dm.is_floor(site["grid_pos"]) and site["display_name"] == names[id] and site["kind"] == id.get_slice("_", 0)
				and site["footprint"].size() == 9, "  its door is walkable, named, on a raised block")
	_check(dm.get_site_by_id("closet_0") >= 0, "Thanatos Closet keeps its way down")
	var stair := dm.get_site_by_id("ascent_0")
	var eastmost := true
	for s in dm.site_nodes:
		if s["id"] != "ascent_0" and s["kind"] != "exit" and stair >= 0:
			eastmost = eastmost and s["grid_pos"].x <= dm.site_nodes[stair]["grid_pos"].x
	_check(stair >= 0 and eastmost, "the Stair is the farthest east, at the Underworld's edge")
	_check(_reach(dm).size() == _floor_count(dm), "the surface is still all one piece")
	_check(dm._visuals_root.get_node_or_null("SiteBlocks") != null, "the footprints are drawn as raised blocks")
	for lvl in [1, 3]:
		var other := _build("", lvl)
		_check(other.get_site_by_id("rift_0") < 0 and other.get_site_by_id("citadel_0") < 0 and other.get_site_by_id("ascent_0") < 0,
			"World %d has none of them" % lvl)

func _test_rift() -> void:
	print("-- the Brimstone Rift --")
	var dm := _build("rift_0")
	_check(dm.interior_kind == "rift" and dm.get_location_name() == "Brimstone Rift", "its own kind and name")
	_check(not DungeonManager.is_boss_room("rift_0"), "a place to cross, not a sealed room")
	_check(_hell_art(dm), "it wears the Underworld's art, with the cave pack's lava")
	var reach := _reach(dm)
	_check(reach.size() == _floor_count(dm), "every bank and island can be walked to (%d tiles)" % reach.size())
	_check(_lava_count(dm) >= 120, "a river of lava no one wades (%d tiles)" % _lava_count(dm))
	_check(dm.rift_bridges.size() >= 2, "vein bridges over it (%d)" % dm.rift_bridges.size())
	var bridges_ok := true
	for c in dm.bridge_cells:
		bridges_ok = bridges_ok and dm.is_floor(c) and dm.is_water(c)
	_check(bridges_ok, "a bridge is floor laid over the lava")
	var without := _reach(dm, dm.bridge_cells)
	_check(without.size() < reach.size() - dm.bridge_cells.size(), "and the bridges are the only way over (%d of %d without them)" % [without.size(), reach.size()])
	var isles := 0
	for room in dm.rooms:
		if room.get("isle", false):
			isles += 1
	_check(isles >= 1, "islands in the lava (%d)" % isles)
	_check(dm.get_site_by_id("exit") >= 0 and _site_in_room(dm, "crucible", "deep"), "a way out, and the Crucible's door on the far landing")
	var types := _types(dm)
	var ok := true
	for t in types:
		ok = ok and t in ROSTER and t != Enemy.EnemyType.IFRIT
	_check(types.size() >= 8 and ok, "the Underworld's host (%d)" % types.size())
	_check(Enemy.EnemyType.MAGMA_SPIDER in types and Enemy.EnemyType.ASH_HARPY in types, "magma spiders and ash harpies")
	var nests := true
	for z in dm.spawn_zones:
		for i in range(z["spawn_points"].size()):
			if z["enemy_types"][i] != Enemy.EnemyType.MAGMA_SPIDER:
				continue
			var on_isle := false
			for room in dm.rooms:
				if room.get("isle", false) and z["spawn_points"][i] in room["cells"]:
					on_isle = true
				if room["kind"] == "deep" and (room["rect"] as Rect2i).has_point(z["spawn_points"][i]):
					on_isle = true
			nests = nests and on_isle
	_check(nests, "the spiders nest on the islands (and one at the far landing)")
	_check(_spawns_ok(dm, reach), "no creature waits on lava, a bridge or out of reach")
	_check(dm.fountain_nodes.size() == 1 and dm.chest_nodes.size() >= 2, "a fountain and chests (%d)" % dm.chest_nodes.size())
	var again := _build("rift_0")
	_check(again.rift_bridges.size() == dm.rift_bridges.size() and again.bridge_cells.keys() == dm.bridge_cells.keys(),
		"the same canyon every visit")

func _test_crucible() -> void:
	print("-- the Crucible --")
	var dm := _build("crucible")
	_check(DungeonManager.is_boss_room("crucible") and DungeonManager.is_guardian_room("crucible")
		and DungeonManager.boss_room_key("crucible") == "crucible", "a sealed room held by guardians")
	_check(_hell_art(dm) and dm.get_location_name() == "The Crucible", "in the hell art")
	_check(dm.get_site_by_id("exit") < 0, "sealed while they stand")
	var ifrits := 0
	var placed := true
	var reach := _reach(dm)
	for g in dm.guardian_placements:
		placed = placed and reach.has(g["cell"])
		if g["type"] == Enemy.EnemyType.IFRIT:
			ifrits += 1
	_check(dm.guardian_placements.size() == 2 and ifrits == 2 and placed, "two ifrits, on open floor")
	_check(reach.size() == _floor_count(dm) and _lava_count(dm) > 20, "a lava lake to fight round, and all the floor in reach")
	_check(dm.rift_bridges.size() == 2 and reach.has(dm.crucible_isle), "two vein bridges onto the island at its heart")
	_check(dm.spawn_zones.is_empty() and dm.fountain_nodes.is_empty() and dm.chest_nodes.is_empty(), "nothing else: a fight")
	var cleared := _build("crucible", 2, ["crucible"])
	_check(cleared.get_site_by_id("exit") >= 0, "once they have fallen, the way out stands open")

func _test_citadel() -> void:
	print("-- the Citadel of Dis --")
	var dm := _build("citadel_0")
	_check(dm.interior_kind == "citadel" and dm.get_location_name() == "Citadel of Dis", "its own kind and name")
	_check(_hell_art(dm), "it wears the Underworld's art")
	var reach := _reach(dm)
	_check(reach.size() == _floor_count(dm), "its courts and halls are all one fortress")
	var pillars := true
	for c in dm.citadel_pillars:
		pillars = pillars and not dm.is_floor(c)
	_check(dm.citadel_pillars.size() >= 6 and pillars, "a pillared great hall (%d pillars)" % dm.citadel_pillars.size())
	var paved := 0
	var courts := 0
	for room in dm.rooms:
		if room.get("court", false):
			courts += 1
		elif room["kind"] == "room":
			var r: Rect2i = room["rect"]
			paved += 1 if dm.is_trail(r.get_center()) or dm.is_trail(r.get_center() + Vector2i(0, 1)) else 0
	_check(courts >= 3 and paved >= 2, "open courts (%d) and paved halls (%d)" % [courts, paved])
	_check(dm.get_site_by_id("exit") >= 0 and _site_in_room(dm, "throne", "deep"), "a way out, and the Throne's doors on the inner court")
	var types := _types(dm)
	var ok := true
	for t in types:
		ok = ok and t in ROSTER and t != Enemy.EnemyType.MAGMA_SPIDER
	_check(types.size() >= 10 and ok, "demons, succubi, specters, mind eaters, harpies (%d)" % types.size())
	var gate_keep := false
	for z in dm.spawn_zones:
		if Enemy.EnemyType.IFRIT in z["enemy_types"]:
			gate_keep = true
	_check(gate_keep, "an ifrit keeps the inner court")
	_check(_spawns_ok(dm, reach) and dm.fountain_nodes.size() == 1, "every creature in reach, and a fountain")

func _test_throne() -> void:
	print("-- the Throne of Dis --")
	var dm := _build("throne")
	_check(DungeonManager.is_guardian_room("throne") and dm.get_site_by_id("exit") < 0, "a sealed guardian room")
	var count := {}
	var reach := _reach(dm)
	var placed := true
	for g in dm.guardian_placements:
		count[g["type"]] = int(count.get(g["type"], 0)) + 1
		placed = placed and reach.has(g["cell"])
	_check(count.get(Enemy.EnemyType.IFRIT, 0) == 1 and count.get(Enemy.EnemyType.DEMON, 0) == 2
		and count.get(Enemy.EnemyType.SUCCUBUS, 0) == 2 and count.get(Enemy.EnemyType.MIND_EATER, 0) == 2 and placed,
		"the court of Dis: an ifrit enthroned, two demons, two succubi, two mind eaters")
	_check(dm.throne_cell.x > dm.player_start.x + 20, "the throne at the far end of the hall")
	_check(reach.size() == _floor_count(dm) and _lava_count(dm) > 40 and dm.throne_pillars.size() >= 8, "lava gutters, pillars, and room to fight")
	_check(_build("throne", 2, ["throne"]).get_site_by_id("exit") >= 0, "once the court has fallen, the way out stands open")

func _test_ascent() -> void:
	print("-- the Ashen Stair --")
	var dm := _build("ascent_0")
	_check(dm.interior_kind == "ascent" and dm.get_location_name() == "The Ashen Stair", "its own kind and name")
	_check(_hell_art(dm), "the Mountain Pass's shape in the Underworld's art")
	_check(dm.has_cliffs and dm.cliff_face_tiles.size() >= 20 and dm.step_tiles.size() >= 4, "terraces: rock faces (%d) and steps (%d)" % [dm.cliff_face_tiles.size(), dm.step_tiles.size()])
	var reach := _reach(dm)
	_check(reach.size() == _floor_count(dm), "every ledge is reached on foot, one level a step")
	var top := 0
	for c in reach:
		top = maxi(top, dm.get_elevation(c))
	_check(dm.get_elevation(dm.player_start) == 0 and top >= DungeonManager.MOUNTAIN_TIER_STEP * 2, "it climbs from the foot to the heights (level %d)" % top)
	_check(_lava_count(dm) > 0, "lava pools on its terraces")
	var i := dm.get_site_by_id("breach")
	_check(i >= 0, "the Breach's door at the top")
	if i >= 0:
		var door: Vector2i = dm.site_nodes[i]["grid_pos"]
		_check(reach.has(door) and dm.get_elevation(door) >= DungeonManager.MOUNTAIN_TIER_STEP * 2
			and dm.is_wall(door + Vector2i(0, -1)) and not dm.is_water(door + Vector2i(0, -1)), "high up, set in the rock")
	_check(dm.get_site_by_id("exit") >= 0, "and the way back down")
	var types := _types(dm)
	var ok := true
	for t in types:
		ok = ok and t in ROSTER
	_check(types.size() >= 10 and ok and Enemy.EnemyType.ASH_HARPY in types and Enemy.EnemyType.IFRIT in types, "the host on its ledges, harpies over them (%d)" % types.size())
	_check(_spawns_ok(dm, reach), "every creature stands where the climb reaches")

func _test_breach() -> void:
	print("-- the Breach --")
	var dm := _build("breach")
	_check(DungeonManager.is_guardian_room("breach") and DungeonManager.boss_room_key("breach") == "breach", "a sealed guardian room")
	_check(dm.get_site_by_id("exit") < 0 and dm.get_site_by_id("ascend") < 0, "sealed: no way back down, no way up")
	_check(dm.breach_gate_cell.y < dm.player_start.y - 12 and dm.is_floor(dm.breach_gate_cell), "entered from the south, the gate in the north wall")
	var count := {}
	var reach := _reach(dm)
	var placed := true
	for g in dm.guardian_placements:
		count[g["type"]] = int(count.get(g["type"], 0)) + 1
		placed = placed and reach.has(g["cell"])
	_check(count.get(Enemy.EnemyType.IFRIT, 0) == 2 and count.get(Enemy.EnemyType.DEMON, 0) == 2 and count.get(Enemy.EnemyType.MIND_EATER, 0) == 1
		and count.get(Enemy.EnemyType.SUCCUBUS, 0) == 1 and count.get(Enemy.EnemyType.ASH_HARPY, 0) == 2 and placed,
		"its wardens: two ifrits, two demons, a mind eater, a succubus, two ash harpies")
	_check(reach.size() == _floor_count(dm) and reach.has(dm.breach_gate_cell), "the gate can be walked to")
	var opened := _build("breach", 2, ["breach"])
	_check(opened.get_site_by_id("exit") >= 0 and opened.get_site_by_id("ascend") >= 0, "once they fall it stands open both ways")
	if opened.get_site_by_id("exit") >= 0:
		var exit_node: Node3D = opened.site_nodes[opened.get_site_by_id("exit")]["node"]
		_check(exit_node.position.z > opened.grid_manager.grid_to_world(opened.player_start).z, "the way back is behind the hero, to the south")

func _test_levels() -> void:
	print("-- level bands --")
	var ok := true
	var seen := {}
	for t in ROSTER:
		var lvl: int = EnemyDefs.DEFS[Enemy.EnemyType.keys()[t]]["intended_level"]
		seen[Enemy.EnemyType.keys()[t]] = lvl
		ok = ok and lvl >= 26 and lvl <= 28
	_check(ok, "every creature placed is banded for the Underworld, 26-28 (%s)" % [seen])

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

func _boot(interior: String, ch: CharacterData = null) -> Node:
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", ch if ch else CharacterData.create_brad())
	main.set("current_world_level", 2)
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

func _test_rift_round_trip() -> void:
	print("-- the surface -> the Rift -> the Crucible -> back --")
	var main = await _boot("")
	var i: int = main.dungeon_manager.get_site_by_id("rift_0")
	_check(i >= 0, "the live surface has the Rift's door")
	if i < 0:
		main.queue_free()
		return
	var outside: Vector2i = main.dungeon_manager.site_nodes[i]["grid_pos"]
	_stand(main, outside)
	_check(main._try_interact_site(), "Shift at the door")
	await _settle()
	var rift = _find_main()
	_check(rift != null and rift.current_interior_id == "rift_0" and rift.parent_interior_id == "", "enters the Rift")
	if rift == null:
		return
	await _dismiss(rift)
	_check(rift.grid_manager.world_to_grid(rift.player.position) == rift.dungeon_manager.player_start, "at the way in")
	var d: int = rift.dungeon_manager.get_site_by_id("crucible")
	var door: Vector2i = rift.dungeon_manager.site_nodes[d]["grid_pos"]
	_stand(rift, door)
	rift._try_interact_site()
	await _settle()
	var cru = _find_main()
	_check(cru != null and cru.current_interior_id == "crucible" and cru.parent_interior_id == "rift_0", "the Crucible's door leads in, remembering the Rift")
	if cru == null:
		return
	await _dismiss(cru)
	_check(cru.boss_room_mode, "a sealed room")
	var ifrits: Array = _living(cru, Enemy.EnemyType.IFRIT)
	_check(ifrits.size() == 2, "two ifrits wait (%d)" % ifrits.size())
	if ifrits.size() == 2:
		_kill(ifrits[0])
		await _settle(4)
		_check(cru.dungeon_manager.get_site_by_id("exit") < 0, "one falls: still sealed")
		_kill(ifrits[1])
		await _settle(4)
		_check(cru.dungeon_manager.get_site_by_id("exit") >= 0, "both fall: the way out opens")
		_check(cru.current_character.has_defeated_boss("crucible"), "and the character remembers it")
	cru._exit_interior()
	await _settle()
	var back = _find_main()
	_check(back != null and back.current_interior_id == "rift_0", "leaving returns to the Rift")
	if back:
		await _dismiss(back)
		_check(back.grid_manager.world_to_grid(back.player.position) == door, "at the Crucible's door")
		_check(back.dungeon_manager.cleared_bosses.has("crucible"), "the Rift knows the Crucible is cleared")
		back._exit_interior()
		await _settle()
		var top = _find_main()
		_check(top != null and top.current_interior_id == "" and top.grid_manager.world_to_grid(top.player.position) == outside,
			"and the Rift's way out returns to its door on the surface")
		if top:
			top.queue_free()
	await _settle()

func _test_throne_fight() -> void:
	print("-- the Citadel -> the Throne of Dis --")
	var cit = await _boot("citadel_0")
	_check(cit.dungeon_manager.interior_kind == "citadel" and cit.grid_manager.world_to_grid(cit.player.position) == cit.dungeon_manager.player_start,
		"the Citadel boots, the hero at its gate")
	cit._enter_interior("throne", "Throne of Dis")
	await _settle()
	var main = _find_main()
	_check(main != null and main.current_interior_id == "throne" and main.parent_interior_id == "citadel_0", "the Throne's doors lead in")
	if main == null:
		return
	await _dismiss(main)
	var court: Array = _living(main)
	_check(court.size() == 7, "the court of Dis is there (%d)" % court.size())
	for k in range(court.size() - 1):
		_kill(court[k])
	await _settle(4)
	_check(main.dungeon_manager.get_site_by_id("exit") < 0, "while one stands, the doors stay shut")
	for e in _living(main):
		_kill(e)
	await _settle(4)
	_check(main.dungeon_manager.get_site_by_id("exit") >= 0 and main.current_character.has_defeated_boss("throne"), "the last falls: the way out opens, remembered")
	main.queue_free()
	await _settle()

func _test_breach_fight() -> void:
	print("-- the Breach: the way up --")
	var main = await _boot("breach")
	_check(main.boss_room_mode, "a sealed room")
	_check(main.dungeon_manager.get_site_by_id("ascend") < 0 and main.dungeon_manager.get_site_by_id("exit") < 0, "no way up, no way back")
	var wardens: Array = _living(main)
	_check(wardens.size() == 8, "its wardens wait (%d)" % wardens.size())
	for e in wardens:
		_kill(e)
	await _settle(4)
	_check(main.dungeon_manager.get_site_by_id("ascend") >= 0 and main.dungeon_manager.get_site_by_id("exit") >= 0,
		"the last falls: the way up opens, and the way back")
	_check(main.current_character.has_defeated_boss("breach"), "the Breach is remembered as open")
	_stand(main, main.dungeon_manager.breach_gate_cell)
	var went: bool = main._try_interact_site()
	await _settle()
	var next = _find_main()
	_check(went and next != null and next.current_world_level == 3 and next.current_interior_id == "", "Shift at the gate climbs to the next world")
	if next:
		next.queue_free()
	await _settle()

func _test_stair_in_game() -> void:
	print("-- the Ashen Stair in the game --")
	var main = await _boot("ascent_0")
	var dm = main.dungeon_manager
	_check(dm.interior_kind == "ascent" and main.grid_manager.world_to_grid(main.player.position) == dm.player_start, "the hero at the foot")
	_check(main.player.step_check.is_valid(), "the hero walks by the terrain's step rule")
	var i: int = dm.get_site_by_id("breach")
	if i >= 0:
		_stand(main, dm.site_nodes[i]["grid_pos"])
		main._try_interact_site()
		await _settle()
		var br = _find_main()
		_check(br != null and br.current_interior_id == "breach" and br.parent_interior_id == "ascent_0", "the door at the top leads into the Breach")
		if br:
			br.queue_free()
	else:
		main.queue_free()
	await _settle()
