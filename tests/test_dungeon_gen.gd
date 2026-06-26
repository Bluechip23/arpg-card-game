extends SceneTree

## Headless validation of dungeon generation across all worlds and interiors.
## Run: godot --headless --path . --script test_dungeon_gen.gd

var failures: int = 0

func _initialize() -> void:
	var holder = Node3D.new()
	get_root().add_child(holder)

	var configs = []
	for level in range(1, 6):
		configs.append({"level": level, "interior": ""})
	configs.append({"level": 1, "interior": "cave_0"})
	configs.append({"level": 3, "interior": "cave_1"})
	configs.append({"level": 5, "interior": "cave_2"})
	configs.append({"level": 1, "interior": "building_0"})
	configs.append({"level": 3, "interior": "building_0"})
	configs.append({"level": 5, "interior": "building_1"})
	configs.append({"level": 1, "interior": "sewer_0"})
	configs.append({"level": 1, "interior": "sewer_1"})
	configs.append({"level": 1, "interior": "forest_0"})
	configs.append({"level": 1, "interior": "forest_1"})

	for cfg in configs:
		var sig_a = _build_and_validate(holder, cfg)
		var sig_b = _build_and_validate(holder, cfg, false)
		if sig_a != sig_b:
			failures += 1
			print("FAIL %s: generation is not deterministic" % [cfg])

	if failures == 0:
		print("ALL DUNGEON TESTS PASSED")
	else:
		print("TOTAL FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func _build_and_validate(holder: Node3D, cfg: Dictionary, validate: bool = true) -> String:
	var gm = GridManager.new()
	holder.add_child(gm)
	var parent = Node3D.new()
	holder.add_child(parent)
	var dm = DungeonManager.new()
	holder.add_child(dm)
	dm._opened_chests_ref = {}
	dm.initialize(gm, parent, cfg["level"], cfg["interior"])

	if validate:
		_validate(dm, cfg)

	# Layout signature for determinism comparison
	var sig = "%dx%d|" % [dm.GRID_W, dm.GRID_H]
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			sig += "1" if dm.grid[x][z] == dm.Tile.FLOOR else "0"
			sig += str(dm.elevation[x][z])
			if dm.is_water(Vector2i(x, z)):
				sig += "w"
	for c in dm.chest_nodes:
		sig += "|c%s_g%d" % [c["grid_pos"], c["contents"]["gold"]]
	for s in dm.site_nodes:
		sig += "|s%s@%s" % [s["id"], s["grid_pos"]]
	for zn in dm.spawn_zones:
		sig += "|z%s" % [zn["spawn_points"]]
	for t in dm.tree_nodes:
		sig += "|t%s" % t["grid_pos"]
	for tr in dm.trap_defs:
		sig += "|x%s@%s" % [tr["kind"], tr["grid_pos"]]
	for p in dm.pit_tiles.keys():
		sig += "|pit%s" % p

	dm.clear()
	dm.queue_free()
	parent.queue_free()
	gm.queue_free()
	return sig.md5_text()

func _fail(cfg: Dictionary, msg: String) -> void:
	failures += 1
	print("FAIL %s: %s" % [cfg, msg])

func _validate(dm: DungeonManager, cfg: Dictionary) -> void:
	if not dm.is_floor(dm.player_start):
		_fail(cfg, "player_start is not a floor tile")
	if dm.get_elevation(dm.player_start) != 0:
		_fail(cfg, "player_start is elevated")

	# Full connectivity: every floor tile reachable from the start
	var total = dm.get_floor_tiles().size()
	var reached = _reachable_count(dm)
	if reached != total:
		_fail(cfg, "connectivity broken: %d/%d floor tiles reachable" % [reached, total])

	for c in dm.chest_nodes:
		if not dm.is_floor(c["grid_pos"]):
			_fail(cfg, "chest off-floor at %s" % c["grid_pos"])

	for wp in dm.waypoint_nodes:
		if not dm.is_floor(wp["grid_pos"]):
			_fail(cfg, "waypoint '%s' off-floor at %s" % [wp["target"], wp["grid_pos"]])

	for s in dm.site_nodes:
		if not dm.is_floor(s["grid_pos"]):
			_fail(cfg, "site %s entrance off-floor at %s" % [s["id"], s["grid_pos"]])
		for fp in s["footprint"]:
			if dm.is_floor(fp):
				_fail(cfg, "site %s footprint tile %s not blocked" % [s["id"], fp])

	for zn in dm.spawn_zones:
		for p in zn["spawn_points"]:
			if not dm.is_floor(p):
				_fail(cfg, "spawn point off-floor at %s" % p)
		if zn["spawn_points"].size() != zn["enemy_types"].size():
			_fail(cfg, "zone spawn point / type count mismatch")

	if cfg["interior"] == "":
		# Overworld expectations
		if dm.waypoint_nodes.size() == 0:
			_fail(cfg, "no waypoints in overworld")
		var caves = 0
		var buildings = 0
		var sewers = 0
		for s in dm.site_nodes:
			if s["kind"] == "cave":
				caves += 1
			elif s["kind"] == "building":
				buildings += 1
			elif s["kind"] == "sewer":
				sewers += 1
		if caves == 0 or buildings == 0:
			_fail(cfg, "expected at least 1 cave and 1 building, got %d/%d" % [caves, buildings])
		# World 1 opens by descending into the sewers — there must be a grate.
		if cfg["level"] == 1 and sewers == 0:
			_fail(cfg, "World 1 has no sewer entrance")
		print("INFO W%d: %dx%d, %d rooms, %d chests, %d zones, %d caves, %d buildings, %d sewers" % [
			cfg["level"], dm.GRID_W, dm.GRID_H, dm.rooms.size(), dm.chest_nodes.size(),
			dm.spawn_zones.size(), caves, buildings, sewers])
	elif cfg["interior"].begins_with("sewer"):
		_validate_sewer(dm, cfg)
	elif cfg["interior"].begins_with("forest"):
		_validate_forest(dm, cfg)
	else:
		if dm.get_site_by_id("exit") < 0:
			_fail(cfg, "interior has no exit site")
		if dm.waypoint_nodes.size() != 0:
			_fail(cfg, "interior should not have waypoints")
		if dm.chest_nodes.size() == 0:
			_fail(cfg, "interior has no chests")
		print("INFO %s (W%d): %dx%d, %d rooms, %d chests, %d zones" % [
			cfg["interior"], cfg["level"], dm.GRID_W, dm.GRID_H, dm.rooms.size(),
			dm.chest_nodes.size(), dm.spawn_zones.size()])

func _validate_sewer(dm: DungeonManager, cfg: Dictionary) -> void:
	if dm.get_site_by_id("exit") < 0:
		_fail(cfg, "sewer has no exit site")
	if dm.waypoint_nodes.size() != 0:
		_fail(cfg, "sewer should not have waypoints")
	# The sewers must actually have water channels.
	var water_tiles = 0
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_water(Vector2i(x, z)):
				water_tiles += 1
	if water_tiles == 0:
		_fail(cfg, "sewer has no water tiles")
	# All water tiles must be walkable floor.
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.is_water(Vector2i(x, z)) and not dm.is_floor(Vector2i(x, z)):
				_fail(cfg, "water tile %s is not floor" % Vector2i(x, z))
	# There must be a Rat King arena and the King himself must spawn.
	var has_arena = false
	for room in dm.rooms:
		if room["kind"] == "arena":
			has_arena = true
			break
	if not has_arena:
		_fail(cfg, "sewer has no Rat King arena")
	var has_rat_king = false
	var has_post_boss = false
	var post_boss_types = [Enemy.EnemyType.SEWER_CROC, Enemy.EnemyType.SWARM, Enemy.EnemyType.PIPE_CRAWLER]
	for zn in dm.spawn_zones:
		for t in zn["enemy_types"]:
			if t == Enemy.EnemyType.RAT_KING:
				has_rat_king = true
			if t in post_boss_types:
				has_post_boss = true
	if not has_rat_king:
		_fail(cfg, "Rat King never spawns in the sewer")
	if not has_post_boss:
		_fail(cfg, "no post-boss sewer enemies (croc/swarm/crawler) spawn")
	print("INFO %s (W%d): %dx%d, %d rooms, %d chests, %d zones, %d water tiles" % [
		cfg["interior"], cfg["level"], dm.GRID_W, dm.GRID_H, dm.rooms.size(),
		dm.chest_nodes.size(), dm.spawn_zones.size(), water_tiles])

func _validate_forest(dm: DungeonManager, cfg: Dictionary) -> void:
	if dm.get_site_by_id("exit") < 0:
		_fail(cfg, "forest has no exit site")
	if dm.waypoint_nodes.size() != 0:
		_fail(cfg, "forest should not have waypoints")
	# Climbable trees must exist and sit on walkable floor.
	if dm.tree_nodes.is_empty():
		_fail(cfg, "forest has no climbable trees")
	for t in dm.tree_nodes:
		if not dm.is_floor(t["grid_pos"]):
			_fail(cfg, "climbable tree off-floor at %s" % t["grid_pos"])
	# Traps: at least one bear trap and one dart trap, all on floor tiles.
	var bear = 0
	var dart = 0
	for tr in dm.trap_defs:
		if tr["kind"] == "bear":
			bear += 1
		elif tr["kind"] == "dart":
			dart += 1
		for tile in tr["tiles"]:
			if not dm.is_floor(tile):
				_fail(cfg, "trap tile %s is not floor" % tile)
	if bear == 0:
		_fail(cfg, "forest has no bear traps")
	if dart == 0:
		_fail(cfg, "forest has no dart traps")
	# Pits must be walkable floor cells (blocked at runtime, not carved to wall).
	for p in dm.pit_tiles.keys():
		if not dm.is_floor(p):
			_fail(cfg, "pit %s is not floor" % p)
	# At least one hill (high ground) somewhere in the woods.
	var hills = 0
	for room in dm.rooms:
		if room.get("hill", false) or room.get("elev", 0) > 0:
			hills += 1
	if hills == 0:
		_fail(cfg, "forest has no hills (high ground)")
	print("INFO %s (W%d): %dx%d, %d rooms, %d trees, %d bear / %d dart traps, %d pits, %d hills" % [
		cfg["interior"], cfg["level"], dm.GRID_W, dm.GRID_H, dm.rooms.size(),
		dm.tree_nodes.size(), bear, dart, dm.pit_tiles.size(), hills])

func _reachable_count(dm: DungeonManager) -> int:
	var visited: Dictionary = {}
	var frontier: Array = [dm.player_start]
	visited[dm.player_start] = true
	var count = 0
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		count += 1
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next = current + dir
			if visited.has(next):
				continue
			if not dm.is_floor(next):
				continue
			visited[next] = true
			frontier.append(next)
	return count
