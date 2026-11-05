extends SceneTree

## The Mountain Pass (Act 1, Mountains habitat) and walking elevation
## (designer, 2026-11-05):
##  - Elevation is walked one level a step (DungeonManager.can_step): a drop
##    of more than MAX_STEP between neighbouring tiles is a cliff. Heroes,
##    enemies and summons route round it; fliers and climbers cross it.
##  - The Mountain Pass: terraces a cliff apart, south-facing drops as rock
##    faces (cliff_face_tiles), steps between terraces (step_tiles); every
##    ledge reachable on foot; the mountain roster, ranged and fliers up high.
##  - World 1's overworld has its entrance; every waypoint shrine (and the
##    town's) is a platform entered only from the front; the block-kind
##    sites' footprints are drawn as a raised block (no empty ground).
## Run: godot --headless --path . --script tests/test_mountains.gd

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
	for lvl in [1, 2]:
		_test_layout(lvl)
	_test_can_step()
	await _test_player_routes()
	_test_overworld()
	_test_town_shrine()
	await _test_in_game()
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

func _floor_cells(dm: DungeonManager) -> Array:
	var out: Array = []
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.grid[x][z] == DungeonManager.Tile.FLOOR:
				out.append(Vector2i(x, z))
	return out

func _test_layout(lvl: int) -> void:
	print("-- Mountain Pass layout (world %d) --" % lvl)
	var dm := _build("mountains_0", lvl)
	_check(dm.interior_kind == "mountains" and dm.get_location_name() == "Mountain Pass", "the Mountain Pass is its own interior kind")
	_check(dm.has_cliffs, "it has cliffs: walkers take the real route")
	var floors := _floor_cells(dm)
	var reach := dm._mountain_reach(dm.player_start)
	_check(reach.size() == floors.size(), "every floor tile is reachable on foot (%d of %d)" % [reach.size(), floors.size()])
	var levels := {}
	for c in floors:
		levels[dm.elevation[c.x][c.y]] = true
	_check(levels.has(0) and levels.has(DungeonManager.MOUNTAIN_TIER_STEP * 2), "it climbs from the valley floor to the high terraces (levels %s)" % [levels.keys()])
	_check(dm.elevation[dm.player_start.x][dm.player_start.y] == 0, "the trailhead is on the valley floor")
	_check(dm.cliff_face_tiles.size() >= 20 and dm.step_tiles.size() >= 4, "rock faces (%d) and steps (%d)" % [dm.cliff_face_tiles.size(), dm.step_tiles.size()])
	var faces_ok := true
	for c in dm.cliff_face_tiles:
		if dm.grid[c.x][c.y] != DungeonManager.Tile.WALL:
			faces_ok = false
	_check(faces_ok, "every rock face is a wall to walkers")
	var steps_ok := true
	for c in dm.step_tiles:
		var e: int = dm.elevation[c.x][c.y]
		var down := false
		var up := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if dm.is_floor(n):
				down = down or dm.elevation[n.x][n.y] == e - 1
				up = up or dm.elevation[n.x][n.y] == e + 1
		steps_ok = steps_ok and dm.is_floor(c) and up and down
	_check(steps_ok, "every step joins a terrace below to the one above")
	var cliffs := 0
	for c in floors:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if dm.is_floor(n) and not dm.can_step(c, n):
				cliffs += 1
	_check(cliffs > 0, "some ledges are a cliff above the ground beside them (%d edges)" % cliffs)
	var roster := [Enemy.EnemyType.WEREGOAT, Enemy.EnemyType.SABERTOOTH, Enemy.EnemyType.SNOW_WRAITH,
		Enemy.EnemyType.ICE_TROLL, Enemy.EnemyType.WYVERN, Enemy.EnemyType.WHITE_MANTICORE, Enemy.EnemyType.ROC]
	var all_mountain := true
	var high := 0
	var total := 0
	for z in dm.spawn_zones:
		for i in range(z["spawn_points"].size()):
			var p: Vector2i = z["spawn_points"][i]
			total += 1
			all_mountain = all_mountain and z["enemy_types"][i] in roster and dm.is_floor(p)
			if dm.elevation[p.x][p.y] >= DungeonManager.MOUNTAIN_TIER_STEP:
				high += 1
	_check(total > 0 and all_mountain, "the mountain roster on open ground (%d)" % total)
	_check(high >= 3, "enemies wait up on the ledges (%d of %d)" % [high, total])
	var deep := false
	for r in dm.rooms:
		deep = deep or r["kind"] == "deep"
	_check(deep and dm.get_site_by_id("exit") >= 0, "a summit, and the way back out")

func _test_can_step() -> void:
	print("-- can_step --")
	var dm := _build("forest_0")
	var a := Vector2i(-1, -1)
	for c in _floor_cells(dm):
		if dm.is_floor(c + Vector2i(1, 0)) and dm.elevation[c.x][c.y] == 0 and dm.elevation[c.x + 1][c.y] == 0:
			a = c
			break
	var b := a + Vector2i(1, 0)
	_check(dm.can_step(a, b), "level ground is a step")
	dm.elevation[b.x][b.y] = 1
	_check(dm.can_step(a, b) and dm.can_step(b, a), "one level up or down is a step")
	dm.elevation[b.x][b.y] = 2
	_check(not dm.can_step(a, b) and not dm.can_step(b, a), "two levels is a cliff, up or down")
	dm.elevation[b.x][b.y] = 0

func _test_player_routes() -> void:
	print("-- walking the cliffs --")
	var dm := _build("mountains_0")
	var gm: GridManager = dm.grid_manager
	var holder := Node3D.new()
	get_root().add_child(holder)
	var player: Player = load("res://scenes/character/player.tscn").instantiate()
	holder.add_child(player)
	await process_frame
	player.set_grid_manager(gm)
	var blocked: Array[Vector2i] = dm.get_wall_tiles()
	player.blocked_tiles = blocked
	player.step_check = Callable(dm, "can_step")
	# A floor-to-floor cliff: the route goes round, by the steps.
	var low := Vector2i(-1, -1)
	var high := Vector2i(-1, -1)
	for c in _floor_cells(dm):
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
			var n: Vector2i = c + d
			if dm.is_floor(n) and dm.elevation[n.x][n.y] - dm.elevation[c.x][c.y] == DungeonManager.MOUNTAIN_TIER_STEP:
				low = c
				high = n
				break
		if low.x >= 0:
			break
	_check(low.x >= 0, "found a ledge a cliff above the ground beside it (%s up to %s)" % [low, high])
	player.position = gm.grid_to_world(low)
	var path := player.calculate_path_to(gm.grid_to_world(high))
	var cells: Array = [low]
	for wp in path:
		cells.append(gm.world_to_grid(wp))
	var stepped := true
	for i in range(1, cells.size()):
		stepped = stepped and dm.can_step(cells[i - 1], cells[i])
	_check(path.size() > 1 and stepped, "the walk round goes up one level at a time (%d tiles)" % path.size())
	var via_step := false
	for c in cells:
		via_step = via_step or dm.step_tiles.has(c)
	_check(via_step, "...over a step")
	player.get_stats().climbs_cliffs = true
	var climb := player.calculate_path_to(gm.grid_to_world(high))
	_check(climb.size() == 1, "a climber goes straight up the cliff")
	player.get_stats().climbs_cliffs = false
	# Enemies: a walker routes round, a flier crosses.
	var enemy: Enemy = load("res://scenes/battle/enemy.tscn").instantiate()
	holder.add_child(enemy)
	enemy.grid_manager = gm
	enemy.dungeon_manager = dm
	enemy.blocked_tiles = blocked
	_check(not enemy._can_step(low, high), "an enemy on foot cannot walk the cliff")
	enemy.immune_to_high_ground = true
	_check(enemy._can_step(low, high), "a flier crosses it")
	holder.queue_free()

func _test_overworld() -> void:
	print("-- World 1: the way up, the portals, the sites --")
	var dm := _build("")
	var idx := dm.get_site_by_id("mountains_0")
	_check(idx >= 0, "World 1 has the Mountain Pass entrance")
	if idx >= 0:
		var site: Dictionary = dm.site_nodes[idx]
		_check(dm.is_floor(site["grid_pos"]), "its entrance is walkable")
	_check(dm._visuals_root.get_node_or_null("SiteBlocks") != null, "the sites' footprints are drawn as raised blocks")
	for wp in dm.waypoint_nodes:
		var c: Vector2i = wp["grid_pos"]
		var walls := true
		for b in DungeonManager.shrine_block_cells(c):
			if b.x >= 0 and b.y >= 0 and b.x < dm.GRID_W and b.y < dm.GRID_H:
				walls = walls and not dm.is_floor(b)
		_check(dm.is_floor(c) and dm.is_floor(c + Vector2i(0, 1)) and walls,
			"%s: a platform walked onto only from the front" % wp["display_name"])
	var transport := dm.waypoint_nodes[0]["grid_pos"] as Vector2i
	_check(dm.player_start == transport + Vector2i(0, 1), "the hero arrives on the Transport Portal's front step")

func _test_town_shrine() -> void:
	print("-- the town's Transport Portal --")
	var cells := DungeonManager.shrine_block_cells(Vector2i(2, 13))
	_check(cells.size() == 8 and not (Vector2i(2, 13) in cells) and not (Vector2i(2, 14) in cells)
			and Vector2i(1, 13) in cells and Vector2i(3, 13) in cells and Vector2i(2, 12) in cells,
		"its sides and back are blocked, its front open")

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _test_in_game() -> void:
	print("-- Booting main.tscn in the Mountain Pass --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "mountains_0")
	get_root().add_child(main)
	await _settle(20)
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var dm: DungeonManager = main.dungeon_manager
	var gm = main.grid_manager
	_check(dm.interior_kind == "mountains", "the scene is the Mountain Pass")
	_check(gm.world_to_grid(main.player.position) == dm.player_start, "the hero starts at the trailhead")
	_check(main.player.step_check.is_valid(), "the hero walks by the terrain's step rule")
	var stats = main.player.get_stats()
	stats.max_health = 5000
	stats.current_health = 5000
	# Wake a few zones, low and high.
	var woken := 0
	for z in dm.spawn_zones:
		if woken >= 4:
			break
		var p: Vector2i = z["spawn_points"][0]
		main.player.position = main._ground_pos(p)
		main.player.target_position = main.player.position
		main._check_dungeon_zones()
		await _settle(2)
		woken += 1
	main.player.position = main._ground_pos(dm.player_start)
	main.player.target_position = main.player.position
	var enemies: Array = main.enemy_spawner.get_living_enemies()
	_check(enemies.size() >= 4, "the woken zones spawn their creatures (%d)" % enemies.size())
	var fliers_ok := true
	for e in enemies:
		if e.enemy_type in [Enemy.EnemyType.WYVERN, Enemy.EnemyType.WHITE_MANTICORE, Enemy.EnemyType.ROC]:
			fliers_ok = fliers_ok and e.immune_to_high_ground
	_check(fliers_ok, "wyverns, manticores and rocs fly (cross the cliffs)")
	for _t in range(30):
		main.tempo_manager.add_tempo(1)
		await _settle(3)
	var on_rock := 0
	for e in main.enemy_spawner.get_living_enemies():
		var c: Vector2i = gm.world_to_grid(e.position)
		if not e.immune_to_high_ground and not dm.is_floor(c):
			on_rock += 1
	_check(on_rock == 0, "after 30 tempo no walker stands on rock")
	main.queue_free()
	await _settle(2)
