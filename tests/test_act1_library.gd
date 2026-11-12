extends SceneTree

## The Ruined Library (Act 1, Part 2 "Cemetery / Library"; 2026-11-09):
##  - World 1's overworld has its door, near the Old Graveyard; only World 1.
##  - The library: a nave from the door, wings of stacks (rows of cases,
##    two-tile aisles) and reading rooms (desks), the archive at the east end
##    (the deepest room: pillars, the dais, two Spirit Collectors).
##  - Everything walkable is one building; chests, the fountain and every
##    spawn point can be reached; the door out is where the hero comes in.
##  - Its dwellers are the Graveyard roster in the graveyard's level band.
##  - In the game: dim, the hero carries a torch, the zones wake their
##    creatures, and leaving puts the hero back at the library's door.
## Run: godot --headless --path . --script tests/test_act1_library.gd

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
	_test_layout()
	_test_reach()
	_test_roster()
	await _test_in_game()
	await _test_way_back()
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

## Every tile a walker can reach from the start (walls and desks block).
func _walk(dm: DungeonManager) -> Dictionary:
	var seen := {dm.player_start: true}
	var q: Array = [dm.player_start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and dm.is_floor(n) and not dm.is_obstacle(n):
				seen[n] = true
				q.append(n)
	return seen

func _test_entrance() -> void:
	print("-- the door on World 1 --")
	var dm := _build("", 1)
	var i := dm.get_site_by_id("library_0")
	_check(i >= 0, "World 1 has the Ruined Library's door")
	if i < 0:
		return
	var site: Dictionary = dm.site_nodes[i]
	_check(site["kind"] == "library" and site["display_name"] == "Ruined Library", "a library site, named")
	_check(dm.is_floor(site["grid_pos"]) and _walk(dm).has(site["grid_pos"]), "its door can be walked to")
	var gy := dm.get_site_by_id("graveyard_0")
	_check(gy >= 0, "the Old Graveyard is there too")
	if gy >= 0:
		var a: Vector2i = site["grid_pos"]
		var b: Vector2i = dm.site_nodes[gy]["grid_pos"]
		var to_gy := absi(a.x - b.x) + absi(a.y - b.y)
		var nearest := true
		for s in dm.site_nodes:
			if s["id"] in ["library_0", "graveyard_0"]:
				continue
			var c: Vector2i = s["grid_pos"]
			if absi(c.x - b.x) + absi(c.y - b.y) < to_gy:
				nearest = false
		_check(nearest, "it is the Old Graveyard's nearest neighbour (%d tiles)" % to_gy)
	_check(dm._floor_fully_connected(), "the world stays one walkable piece around it")
	_check(dm._visuals_root.get_node_or_null("SiteBlocks") != null, "its footprint is drawn as a raised block, the ruin on it")
	for lvl in [2, 3]:
		_check(_build("", lvl).get_site_by_id("library_0") < 0, "World %d has none" % lvl)

func _test_layout() -> void:
	print("-- the library --")
	var dm := _build("library_0")
	_check(dm.interior_kind == "library" and dm.get_location_name() == "Ruined Library", "its own kind and name")
	_check(not DungeonManager.is_boss_room("library_0"), "a place to explore, not a sealed boss room")
	_check(dm.floor_texture_path().ends_with("floor_undead.png") and dm.wall_texture_path().ends_with("wall_undead.png"),
		"the undead pack's flagstones and stone, as buildings")
	_check(dm._prop_biome() == "library" and CraftpixProps.has("town_scroll_case") and CraftpixProps.has("town_contract_desk"),
		"its cases and desks are the designer's painted pieces")
	var flat := true
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			flat = flat and dm.get_elevation(Vector2i(x, z)) == 0
	_check(flat, "flat inside")
	var stacks: Array = []
	var reading: Array = []
	var archive: Dictionary = {}
	var nave: Dictionary = {}
	for r in dm.rooms:
		match r.get("lib", ""):
			"stacks":
				stacks.append(r)
			"reading":
				reading.append(r)
			"archive":
				archive = r
			"nave":
				nave = r
	_check(stacks.size() >= 3 and reading.size() >= 2, "wings of stacks (%d) and reading rooms (%d)" % [stacks.size(), reading.size()])
	_check(not nave.is_empty() and (nave["rect"] as Rect2i).size.x >= 25, "a long nave from the door")
	# The stacks: rows of cases (walls) with two-tile aisles between them.
	var rows_ok := true
	var aisles_ok := true
	for r in stacks:
		var bay: Rect2i = r["rect"]
		var rows: Array = []
		for z in range(bay.position.y, bay.end.y):
			var n := 0
			for x in range(bay.position.x, bay.end.x):
				if dm.library_shelf_tiles.has(Vector2i(x, z)):
					n += 1
			if n > 0:
				rows.append(z)
		rows_ok = rows_ok and rows.size() >= 2
		for k in range(rows.size() - 1):
			aisles_ok = aisles_ok and rows[k + 1] - rows[k] == 3
	_check(rows_ok, "every stack bay has rows of cases")
	_check(aisles_ok, "with narrow aisles, two tiles, between them")
	var cases_are_walls := true
	for c in dm.library_shelf_tiles:
		cases_are_walls = cases_are_walls and dm.is_wall(c)
	_check(dm.library_shelf_tiles.size() >= 60 and cases_are_walls, "the cases stand as walls (%d)" % dm.library_shelf_tiles.size())
	var desks_ok := dm.library_desks.size() >= 6
	for c in dm.library_desks:
		desks_ok = desks_ok and dm.is_obstacle(c) and dm.is_floor(c)
	_check(desks_ok, "the reading desks stand in the way (%d)" % dm.library_desks.size())
	_check(not archive.is_empty() and archive["kind"] == "deep", "the archive is the deepest room")
	if not archive.is_empty():
		var ar: Rect2i = archive["rect"]
		_check(ar.position.x > dm.GRID_W * 0.7 and ar.has_point(dm.library_dais), "at the east end, its dais inside")
		_check(dm.library_pillars.size() == 4, "on four ruined pillars")
		_check(ar.size.x * ar.size.y >= 200, "one of the larger rooms (%d tiles)" % (ar.size.x * ar.size.y))
	_check(dm.get_site_by_id("exit") >= 0 and dm.site_nodes[dm.get_site_by_id("exit")]["grid_pos"] == dm.player_start,
		"the way out is the door the hero came in by")

func _test_reach() -> void:
	print("-- everything in reach --")
	var dm := _build("library_0")
	var walk := _walk(dm)
	var floors := 0
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			var c := Vector2i(x, z)
			if dm.is_floor(c) and not dm.is_obstacle(c):
				floors += 1
	_check(walk.size() == floors, "every open tile is one walk from the door (%d of %d)" % [walk.size(), floors])
	_check(walk.has(dm.library_dais), "the dais can be reached")
	var chests_ok := dm.chest_nodes.size() >= 2
	for ch in dm.chest_nodes:
		chests_ok = chests_ok and walk.has(ch["grid_pos"])
	_check(chests_ok, "chests (%d), all in reach" % dm.chest_nodes.size())
	var fountain_ok := dm.fountain_nodes.size() == 1 and walk.has(dm.fountain_nodes[0]["grid_pos"])
	_check(fountain_ok, "a healing fountain, in reach")
	var spawns_ok := true
	var n := 0
	for z in dm.spawn_zones:
		for p in z["spawn_points"]:
			spawns_ok = spawns_ok and walk.has(p)
			n += 1
	_check(n >= 12 and spawns_ok, "every spawn point stands on open floor in reach (%d)" % n)

func _test_roster() -> void:
	print("-- its dwellers --")
	var dm := _build("library_0")
	var allowed := [Enemy.EnemyType.SCREECHER, Enemy.EnemyType.CRYPT_CRAWLER, Enemy.EnemyType.ZOMBIE,
		Enemy.EnemyType.CONSUMED, Enemy.EnemyType.SPIRIT_COLLECTOR]
	var seen := {}
	var ok := true
	for z in dm.spawn_zones:
		for t in z["enemy_types"]:
			ok = ok and t in allowed
			seen[t] = true
	_check(ok, "only the graveyard's screechers, crawlers, zombies, consumed and spirit collectors")
	_check(seen.has(Enemy.EnemyType.SPIRIT_COLLECTOR) and seen.has(Enemy.EnemyType.CONSUMED)
		and seen.has(Enemy.EnemyType.CRYPT_CRAWLER) and seen.has(Enemy.EnemyType.SCREECHER), "all of them met here")
	var band_ok := true
	for t in seen:
		var lvl := int(EnemyDefs.DEFS[Enemy.EnemyType.keys()[t]].get("intended_level", 0))
		band_ok = band_ok and lvl >= 6 and lvl <= 12
	_check(band_ok, "all in the graveyard's level band (6–12)")
	var archive_zone: Dictionary = {}
	for z in dm.spawn_zones:
		for r in dm.rooms:
			if r.get("lib", "") == "archive" and (r["rect"] as Rect2i).grow(1) == z["trigger_rect"]:
				archive_zone = z
	_check(not archive_zone.is_empty(), "the archive wakes as one room")
	if not archive_zone.is_empty():
		_check(archive_zone["enemy_types"].count(Enemy.EnemyType.SPIRIT_COLLECTOR) == 2,
			"two Spirit Collectors hold the archive")

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _boot(level: int, interior: String, back_from: String = "") -> Node:
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_world_level", level)
	main.set("current_interior_id", interior)
	if back_from != "":
		main.set("return_from_interior_id", back_from)
	get_root().add_child(main)
	await _settle(20)
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	return main

func _test_in_game() -> void:
	print("-- Booting main.tscn in the Ruined Library --")
	var main = await _boot(1, "library_0")
	var dm: DungeonManager = main.dungeon_manager
	var gm = main.grid_manager
	_check(dm.interior_kind == "library", "the scene is the library")
	_check(gm.world_to_grid(main.player.position) == dm.player_start, "the hero starts at the door")
	_check(main.player.get_node_or_null("PlayerTorch") != null, "dim inside: the hero carries a torch")
	var blocked := {}
	for c in main._player_blocked_tiles():
		blocked[c] = true
	var desks_block := true
	for c in dm.library_desks:
		desks_block = desks_block and blocked.has(c)
	_check(desks_block, "the desks block the hero's path")
	var stats = main.player.get_stats()
	stats.max_health = 5000
	stats.current_health = 5000
	var want := {}
	for i in range(dm.spawn_zones.size()):
		for t in dm.spawn_zones[i]["enemy_types"]:
			want[t] = true
		main._spawn_dungeon_zone(i)
		await _settle(2)
	var got := {}
	var figures := true
	for e in main.enemy_spawner.get_living_enemies():
		got[e.enemy_type] = true
		figures = figures and not e.actions.is_empty()
	var all := true
	for t in want:
		all = all and got.has(t)
	_check(all and got.size() >= 4, "every zone wakes its creatures (%d kinds)" % got.size())
	_check(figures, "each with its actions (no mock-ups)")
	for _t in range(20):
		main.tempo_manager.add_tempo(1)
		await _settle(2)
	var on_wall := 0
	for e in main.enemy_spawner.get_living_enemies():
		var c: Vector2i = gm.world_to_grid(e.position)
		if not dm.is_floor(c) or dm.is_obstacle(c):
			on_wall += 1
	_check(on_wall == 0, "after 20 tempo nobody stands in a case or a desk")
	main.queue_free()
	await _settle(4)

func _test_way_back() -> void:
	print("-- Back out to World 1 --")
	var main = await _boot(1, "", "library_0")
	var dm: DungeonManager = main.dungeon_manager
	var i := dm.get_site_by_id("library_0")
	_check(i >= 0 and main.grid_manager.world_to_grid(main.player.position) == dm.site_nodes[i]["grid_pos"],
		"leaving puts the hero back at the library's door")
	main.queue_free()
	await _settle(4)
