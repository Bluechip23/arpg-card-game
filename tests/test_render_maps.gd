extends SceneTree

## Renders top-down layout images of generated worlds/interiors to /tmp/maps.
## Run: godot --headless --path . --script test_render_maps.gd

func _initialize() -> void:
	var holder = Node3D.new()
	get_root().add_child(holder)

	DirAccess.make_dir_recursive_absolute("/tmp/maps")

	var configs = [
		{"level": 1, "interior": "", "file": "world1.png"},
		{"level": 3, "interior": "", "file": "world3.png"},
		{"level": 5, "interior": "", "file": "world5.png"},
		{"level": 1, "interior": "cave_0", "file": "cave.png"},
		{"level": 1, "interior": "building_0", "file": "building.png"},
	]

	for cfg in configs:
		var gm = GridManager.new()
		holder.add_child(gm)
		var parent = Node3D.new()
		holder.add_child(parent)
		var dm = DungeonManager.new()
		holder.add_child(dm)
		dm._opened_chests_ref = {}
		dm.initialize(gm, parent, cfg["level"], cfg["interior"])
		_render(dm, "/tmp/maps/" + cfg["file"])
		dm.clear()
		dm.queue_free()
		parent.queue_free()
		gm.queue_free()

	print("MAPS RENDERED")
	quit(0)

func _render(dm: DungeonManager, path: String) -> void:
	var s = 10
	var img = Image.create(dm.GRID_W * s, dm.GRID_H * s, false, Image.FORMAT_RGBA8)
	var pal = dm.get_palette()
	img.fill(pal["ground"])

	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			var col: Color
			if dm.grid[x][z] == dm.Tile.FLOOR:
				var n = dm._tile_noise(x, z, 11)
				col = pal["floor_a"].lerp(pal["floor_b"], n)
				if dm.elevation[x][z] == 1:
					col = col.lightened(0.18)
				elif dm.elevation[x][z] >= 2:
					col = col.lightened(0.36)
			else:
				if dm._has_adjacent_floor(x, z):
					col = pal["wall_a"].lerp(pal["wall_b"], dm._tile_noise(x, z, 31))
				else:
					col = pal["ground"]
			_px(img, x, z, s, col)

	for c in dm.chest_nodes:
		_px(img, c["grid_pos"].x, c["grid_pos"].y, s, Color(1.0, 0.85, 0.1))
	for wp in dm.waypoint_nodes:
		var wc = Color(0.3, 0.7, 1.0)
		if wp["target"] == "next_world":
			wc = Color(0.2, 1.0, 0.4)
		elif wp["target"] == "prev_world":
			wc = Color(1.0, 0.8, 0.3)
		_px(img, wp["grid_pos"].x, wp["grid_pos"].y, s, wc)
	for site in dm.site_nodes:
		for fp in site["footprint"]:
			_px(img, fp.x, fp.y, s, Color(0.55, 0.25, 0.1) if site["kind"] == "building" else Color(0.2, 0.18, 0.16))
		_px(img, site["grid_pos"].x, site["grid_pos"].y, s, Color(1.0, 0.55, 0.1))
	for zn in dm.spawn_zones:
		for p in zn["spawn_points"]:
			_px(img, p.x, p.y, s, Color(0.9, 0.15, 0.15))
	_px(img, dm.player_start.x, dm.player_start.y, s, Color(0.1, 1.0, 0.3))

	img.save_png(path)
	print("Saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])

func _px(img: Image, x: int, z: int, s: int, col: Color) -> void:
	for px in range(s):
		for pz in range(s):
			var ix = x * s + px
			var iz = z * s + pz
			if ix < img.get_width() and iz < img.get_height():
				img.set_pixel(ix, iz, col)
