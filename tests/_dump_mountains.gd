extends SceneTree

## Dev helper: build the Mountain Pass headless and print it as ASCII —
## '#' rock, '^' rock face (cliff_face_tiles), digits the floor's level,
## '/' a step, 'S' the start, 'E' a spawn point. Arg: world level (1).
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var lvl := int(a[0]) if a.size() > 0 else 1
	var root := Node3D.new()
	get_root().add_child(root)
	var gm := GridManager.new()
	root.add_child(gm)
	var dm := DungeonManager.new()
	root.add_child(dm)
	dm.initialize(gm, root, lvl, "mountains_0")
	var spawns := {}
	for z in dm.spawn_zones:
		for i in range(z["spawn_points"].size()):
			spawns[z["spawn_points"][i]] = Enemy.EnemyType.keys()[z["enemy_types"][i]].substr(0, 1)
	for zz in range(dm.GRID_H):
		var line := ""
		for xx in range(dm.GRID_W):
			var c := Vector2i(xx, zz)
			if c == dm.player_start:
				line += "S"
			elif spawns.has(c):
				line += spawns[c].to_lower()
			elif dm.cliff_face_tiles.has(c) and dm.grid[xx][zz] == DungeonManager.Tile.WALL:
				line += "^"
			elif dm.grid[xx][zz] == DungeonManager.Tile.WALL:
				line += "#"
			elif dm.step_tiles.has(c):
				line += "/"
			else:
				line += str(dm.elevation[xx][zz])
		print(line)
	var reach := dm._mountain_reach(dm.player_start)
	var floor_n := 0
	for xx in range(dm.GRID_W):
		for zz in range(dm.GRID_H):
			if dm.grid[xx][zz] == DungeonManager.Tile.FLOOR:
				floor_n += 1
	print("floor %d reachable %d steps %d faces %d zones %d has_cliffs %s" % [floor_n, reach.size(), dm.step_tiles.size(), dm.cliff_face_tiles.size(), dm.spawn_zones.size(), dm.has_cliffs])
	quit()
