class_name DungeonManager
extends Node

## Generates and manages persistent world layouts: large outdoor regions made of
## rooms, corridors, terrain elevation (hills, cliff faces, stone steps), treasure
## chests, enemy zones, waypoints, and enterable sites (caves and buildings with
## their own interior maps).
##
## Layouts are DETERMINISTIC per world/interior (seeded by world level + interior
## id) so the world stays consistent across visits — this is a persistent RPG
## world, not a procedurally re-rolled roguelike.

signal chest_interacted(chest_data: Dictionary)
signal player_entered_zone(zone_index: int)

var GRID_W: int = 70
var GRID_H: int = 46
const FOG_REVEAL_RADIUS: int = 6   # Tiles revealed around the player
const ELEV_STEP: float = 0.5       # World units of height per elevation level
const FOG_HEIGHT: float = 2.2      # Height of fog-of-war volume tiles

# Tile types
enum Tile { FLOOR, WALL }

# ============================================
# WORLD PALETTES (generic themes — final per-world themes TBD)
# Each world gets a distinct but neutral look that is easy to re-theme later:
# just adjust the colors here.
# ============================================
const WORLD_PALETTES := {
	1: {
		"name": "Verdant Frontier",
		"ground": Color(0.11, 0.14, 0.08),
		"floor_a": Color(0.27, 0.31, 0.17),
		"floor_b": Color(0.20, 0.25, 0.13),
		"wall_a": Color(0.38, 0.35, 0.28),
		"wall_b": Color(0.27, 0.25, 0.21),
		"cliff": Color(0.36, 0.29, 0.21),
		"step": Color(0.47, 0.44, 0.39),
		"accent": Color(0.24, 0.40, 0.16),
		"ambient": Color(0.42, 0.47, 0.40),
		"sun": Color(1.0, 0.96, 0.86),
		"sun_energy": 1.25,
	},
	2: {
		"name": "Amber Wastes",
		"ground": Color(0.20, 0.16, 0.10),
		"floor_a": Color(0.52, 0.44, 0.27),
		"floor_b": Color(0.43, 0.36, 0.22),
		"wall_a": Color(0.47, 0.37, 0.25),
		"wall_b": Color(0.35, 0.28, 0.20),
		"cliff": Color(0.42, 0.31, 0.21),
		"step": Color(0.55, 0.48, 0.38),
		"accent": Color(0.40, 0.37, 0.15),
		"ambient": Color(0.50, 0.44, 0.35),
		"sun": Color(1.0, 0.92, 0.76),
		"sun_energy": 1.35,
	},
	3: {
		"name": "Frostreach",
		"ground": Color(0.16, 0.18, 0.21),
		"floor_a": Color(0.55, 0.58, 0.63),
		"floor_b": Color(0.44, 0.48, 0.55),
		"wall_a": Color(0.34, 0.38, 0.46),
		"wall_b": Color(0.25, 0.29, 0.37),
		"cliff": Color(0.30, 0.33, 0.41),
		"step": Color(0.50, 0.54, 0.61),
		"accent": Color(0.62, 0.70, 0.78),
		"ambient": Color(0.42, 0.46, 0.54),
		"sun": Color(0.88, 0.93, 1.0),
		"sun_energy": 1.1,
	},
	4: {
		"name": "Emberfall",
		"ground": Color(0.10, 0.08, 0.08),
		"floor_a": Color(0.26, 0.21, 0.20),
		"floor_b": Color(0.19, 0.16, 0.16),
		"wall_a": Color(0.31, 0.22, 0.19),
		"wall_b": Color(0.22, 0.16, 0.15),
		"cliff": Color(0.35, 0.21, 0.15),
		"step": Color(0.38, 0.31, 0.28),
		"accent": Color(0.58, 0.26, 0.10),
		"ambient": Color(0.38, 0.30, 0.27),
		"sun": Color(1.0, 0.82, 0.64),
		"sun_energy": 1.05,
	},
	5: {
		"name": "Umbral Expanse",
		"ground": Color(0.09, 0.08, 0.12),
		"floor_a": Color(0.23, 0.21, 0.30),
		"floor_b": Color(0.17, 0.16, 0.23),
		"wall_a": Color(0.30, 0.27, 0.39),
		"wall_b": Color(0.21, 0.19, 0.29),
		"cliff": Color(0.27, 0.22, 0.34),
		"step": Color(0.37, 0.34, 0.45),
		"accent": Color(0.45, 0.34, 0.60),
		"ambient": Color(0.33, 0.31, 0.42),
		"sun": Color(0.85, 0.83, 1.0),
		"sun_energy": 0.95,
	},
}

const CAVE_PALETTE := {
	"name": "Cave",
	"ground": Color(0.05, 0.05, 0.06),
	"floor_a": Color(0.24, 0.21, 0.18),
	"floor_b": Color(0.17, 0.15, 0.13),
	"wall_a": Color(0.28, 0.24, 0.21),
	"wall_b": Color(0.18, 0.16, 0.14),
	"cliff": Color(0.25, 0.21, 0.17),
	"step": Color(0.34, 0.31, 0.27),
	"accent": Color(0.36, 0.33, 0.28),
	"ambient": Color(0.26, 0.24, 0.23),
	"sun": Color(0.75, 0.72, 0.68),
	"sun_energy": 0.4,
}

const BUILDING_PALETTE := {
	"name": "Building",
	"ground": Color(0.10, 0.08, 0.06),
	"floor_a": Color(0.38, 0.29, 0.19),
	"floor_b": Color(0.31, 0.23, 0.15),
	"wall_a": Color(0.52, 0.48, 0.41),
	"wall_b": Color(0.43, 0.39, 0.33),
	"cliff": Color(0.35, 0.27, 0.19),
	"step": Color(0.45, 0.41, 0.35),
	"accent": Color(0.45, 0.33, 0.20),
	"ambient": Color(0.45, 0.41, 0.35),
	"sun": Color(1.0, 0.93, 0.80),
	"sun_energy": 0.8,
}

# ============================================
# STATE
# ============================================

var grid: Array = []        # 2D array [x][z] of Tile
var elevation: Array = []   # 2D array [x][z] of int (0 = ground, 1+ = elevated)
var rooms: Array = []       # [{rect: Rect2i, kind: String, elev: int}]

var chest_nodes: Array = []     # [{node, grid_pos, opened, looted, contents, body_mesh, lid_mesh}]
var spawn_zones: Array = []     # [{trigger_rect, spawn_points, enemy_types, spawned}]
var waypoint_nodes: Array = []  # [{node, grid_pos, target, display_name, label_node, discovered, pillar_mesh}]
var site_nodes: Array = []      # [{node, grid_pos (entrance), id, kind, display_name, label_node, footprint}]
var player_start: Vector2i = Vector2i(2, 23)

var grid_manager: GridManager
var _parent: Node3D

# World level (1-5) determines size, palette, and enemy difficulty
var world_level: int = 1
# Interior id ("" = overworld). e.g. "cave_0", "building_1"
var interior_id: String = ""
var interior_kind: String = ""  # "cave", "building", or ""

# Deterministic generation
var _rng := RandomNumberGenerator.new()
var _layout_seed: int = 0

# Reserved tiles (chests, waypoints, site entrances, spawn points) — kept clear
# of decorations so interactables stay visible and accessible
var _reserved: Dictionary = {}

# Visuals — everything generated lives under this root for easy cleanup
var _visuals_root: Node3D = null

# Fog of war
var _revealed: Array = []                       # 2D bool array [x][z]
var _fog_mm: MultiMesh = null                   # Fog volume instances
var _fog_initialized: bool = false

# Reference to global opened_chests dictionary (persists across transitions)
var _opened_chests_ref: Dictionary = {}

# ============================================
# INITIALIZATION
# ============================================

func initialize(gm: GridManager, parent: Node3D, level: int = 1, interior: String = "") -> void:
	grid_manager = gm
	_parent = parent
	world_level = level
	interior_id = interior
	interior_kind = ""
	if interior_id.begins_with("cave"):
		interior_kind = "cave"
	elif interior_id.begins_with("building"):
		interior_kind = "building"

	_layout_seed = hash("layout_w%d_%s" % [world_level, interior_id])
	_rng.seed = _layout_seed

	_set_world_size()
	# Update grid_manager dimensions to match
	grid_manager.grid_width = GRID_W
	grid_manager.grid_height = GRID_H
	if grid_manager.has_method("redraw_grid"):
		grid_manager.redraw_grid()

	# Visuals root — all generated nodes live under it
	_visuals_root = Node3D.new()
	_visuals_root.name = "DungeonVisuals"
	_parent.add_child(_visuals_root)

	# Layout + elevation
	match interior_kind:
		"cave":
			_generate_cave_layout()
		"building":
			_generate_building_layout()
		_:
			_generate_overworld_layout()
	_generate_elevation()

	# Interactables (placed before visuals so decorations avoid their tiles)
	_reserved.clear()
	_reserve_area(player_start, 1)
	if interior_kind == "":
		_place_waypoints()
		_place_sites()
	else:
		_place_exit_site()
	_place_chests()
	_define_spawn_zones()

	# Terrain visuals
	_build_floor_visuals()
	_build_walls()
	_build_elevation_visuals()
	_build_decorations()
	_build_fog()

	# Reveal the starting area
	reveal_around(player_start)
	if rooms.size() > 0 and interior_kind == "":
		var start_rect: Rect2i = rooms[0]["rect"]
		reveal_around(Vector2i(start_rect.position.x, start_rect.position.y))
		reveal_around(Vector2i(start_rect.end.x - 1, start_rect.end.y - 1))

	print("[DUNGEON] Generated %s (%dx%d): %d rooms, %d chests, %d zones, %d sites" % [
		get_location_name(), GRID_W, GRID_H, rooms.size(), chest_nodes.size(),
		spawn_zones.size(), site_nodes.size()])

func _set_world_size() -> void:
	if interior_kind == "cave":
		GRID_W = 36 + world_level * 2
		GRID_H = 26 + world_level
		player_start = Vector2i(3, GRID_H / 2)
		return
	if interior_kind == "building":
		GRID_W = 28 + world_level
		GRID_H = 18 + world_level / 2
		player_start = Vector2i(2, GRID_H / 2)
		return
	match world_level:
		1:
			GRID_W = 70
			GRID_H = 46
		2:
			GRID_W = 80
			GRID_H = 52
		3:
			GRID_W = 90
			GRID_H = 58
		4:
			GRID_W = 100
			GRID_H = 64
		5:
			GRID_W = 110
			GRID_H = 70
		_:
			GRID_W = 70
			GRID_H = 46
	player_start = Vector2i(2, GRID_H / 2)

func get_palette() -> Dictionary:
	if interior_kind == "cave":
		return CAVE_PALETTE
	if interior_kind == "building":
		return BUILDING_PALETTE
	return WORLD_PALETTES.get(world_level, WORLD_PALETTES[1])

func get_location_name() -> String:
	if interior_kind == "cave":
		return "Cave %d" % (int(interior_id.get_slice("_", 1)) + 1)
	if interior_kind == "building":
		return "Building %d" % (int(interior_id.get_slice("_", 1)) + 1)
	var pal = get_palette()
	return "World %d — %s" % [world_level, pal.get("name", "")]

# ============================================
# OVERWORLD LAYOUT
# A lattice of rooms spans the whole map, connected by 2-wide corridors.
# Fixed anchors: start room (west), pre-boss arena and exit room (east).
# ============================================

func _generate_overworld_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	var mid_z = GRID_H / 2

	# === Fixed anchor rooms ===
	var start_rect = Rect2i(0, mid_z - 4, 7, 9)
	_carve_rect(start_rect)
	rooms.append({"rect": start_rect, "kind": "start", "elev": 0})

	var arena_rect = Rect2i(GRID_W - 15, mid_z - 5, 9, 11)
	_carve_rect(arena_rect)
	rooms.append({"rect": arena_rect, "kind": "arena", "elev": 0})

	var exit_rect = Rect2i(GRID_W - 6, mid_z - 3, 6, 7)
	_carve_rect(exit_rect)
	rooms.append({"rect": exit_rect, "kind": "exit", "elev": 0})

	# Corridor from arena to exit room
	_carve_corridor_h(GRID_W - 8, GRID_W - 5, mid_z)
	_carve_corridor_h(GRID_W - 8, GRID_W - 5, mid_z + 1)

	# === Room lattice across the open middle of the map ===
	var x0 = 9
	var x1 = GRID_W - 17
	var z0 = 2
	var z1 = GRID_H - 2
	var cols = maxi(3, (x1 - x0) / 11)
	var lat_rows = clampi((z1 - z0) / 11, 3, 6)
	var cell_w = float(x1 - x0) / cols
	var cell_h = float(z1 - z0) / lat_rows

	var lattice: Array = []  # lattice[c][r] = index into rooms
	for c in range(cols):
		var col_rooms: Array = []
		for r in range(lat_rows):
			var cx0 = x0 + int(c * cell_w)
			var cz0 = z0 + int(r * cell_h)
			var max_w = int(cell_w) - 2
			var max_h = int(cell_h) - 2
			var rw = _rng.randi_range(mini(6, max_w), max_w)
			var rh = _rng.randi_range(mini(5, max_h), max_h)
			var rx = cx0 + 1 + _rng.randi_range(0, maxi(0, max_w - rw))
			var rz = cz0 + 1 + _rng.randi_range(0, maxi(0, max_h - rh))
			var rect = Rect2i(rx, rz, rw, rh)
			_carve_rect(rect)
			rooms.append({"rect": rect, "kind": "field", "elev": 0})
			col_rooms.append(rooms.size() - 1)
		lattice.append(col_rooms)

	# === Connect the lattice ===
	# Horizontal: every row is a fully connected west-east chain
	for r in range(lat_rows):
		for c in range(cols - 1):
			_connect_rooms(rooms[lattice[c][r]]["rect"], rooms[lattice[c + 1][r]]["rect"])
	# Vertical: several links between each pair of adjacent rows (creates loops)
	for r in range(lat_rows - 1):
		var link_count = 2 + cols / 3
		var link_cols: Array = []
		for _i in range(link_count):
			var c = _rng.randi_range(0, cols - 1)
			if c not in link_cols:
				link_cols.append(c)
		for c in link_cols:
			_connect_rooms(rooms[lattice[c][r]]["rect"], rooms[lattice[c][r + 1]]["rect"])

	# === Hook the anchors into the lattice ===
	var mid_row = lat_rows / 2
	_connect_rooms(start_rect, rooms[lattice[0][mid_row]]["rect"])
	_connect_rooms(rooms[lattice[cols - 1][mid_row]]["rect"], arena_rect)
	# A second route into the arena keeps the endgame area from being a single chokepoint
	if lat_rows > 1:
		_connect_rooms(rooms[lattice[cols - 1][mid_row - 1]]["rect"], arena_rect)

func _connect_rooms(a: Rect2i, b: Rect2i) -> void:
	## Carves a 2-wide L-shaped corridor between the centers of two rooms.
	var ac = a.get_center()
	var bc = b.get_center()
	_carve_corridor_h(ac.x, bc.x, ac.y)
	_carve_corridor_h(ac.x, bc.x, ac.y + 1)
	_carve_corridor_v(bc.x, ac.y, bc.y)
	_carve_corridor_v(bc.x + 1, ac.y, bc.y)

# ============================================
# CAVE INTERIOR LAYOUT
# Organic chambers connected by winding tunnels (drunkard walk + smoothing).
# ============================================

func _generate_cave_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	var mid_z = GRID_H / 2

	# Entry chamber around the player start / exit portal
	var entry_center = Vector2i(4, mid_z)
	_carve_circle(entry_center, 3)
	rooms.append({"rect": _circle_rect(entry_center, 3), "kind": "start", "elev": 0})

	# Chambers scattered through the cave, dug out one tunnel at a time
	var chamber_count = 5 + world_level
	var prev_center = entry_center
	var deepest_idx = -1
	var deepest_x = -1
	for _i in range(chamber_count):
		var center = Vector2i(
			_rng.randi_range(7, GRID_W - 4),
			_rng.randi_range(4, GRID_H - 5)
		)
		var radius = _rng.randi_range(2, 4)
		_carve_tunnel(prev_center, center)
		_carve_circle(center, radius)
		rooms.append({"rect": _circle_rect(center, radius), "kind": "chamber", "elev": 0})
		if center.x > deepest_x:
			deepest_x = center.x
			deepest_idx = rooms.size() - 1
		prev_center = center

	if deepest_idx >= 0:
		rooms[deepest_idx]["kind"] = "deep"

	# Smooth jagged single-tile walls so the cave reads as natural stone
	_smooth_cave_walls()
	_enforce_border_walls()

func _carve_tunnel(from: Vector2i, to: Vector2i) -> void:
	## Drunkard-walk tunnel: biased toward the target with random wandering.
	var current = from
	var steps = 0
	while current != to and steps < 1500:
		steps += 1
		var dir: Vector2i
		if _rng.randf() < 0.6:
			# Step toward target
			if absi(to.x - current.x) > absi(to.y - current.y):
				dir = Vector2i(signi(to.x - current.x), 0)
			else:
				dir = Vector2i(0, signi(to.y - current.y))
		else:
			var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			dir = dirs[_rng.randi_range(0, 3)]
		current += dir
		current.x = clampi(current.x, 1, GRID_W - 3)
		current.y = clampi(current.y, 1, GRID_H - 3)
		# Carve a 2x2 footprint for a comfortably wide tunnel
		for dx in range(2):
			for dz in range(2):
				grid[current.x + dx][current.y + dz] = Tile.FLOOR

func _carve_circle(center: Vector2i, radius: int) -> void:
	for x in range(maxi(1, center.x - radius), mini(GRID_W - 1, center.x + radius + 1)):
		for z in range(maxi(1, center.y - radius), mini(GRID_H - 1, center.y + radius + 1)):
			var dx = x - center.x
			var dz = z - center.y
			if dx * dx + dz * dz <= radius * radius:
				grid[x][z] = Tile.FLOOR

func _circle_rect(center: Vector2i, radius: int) -> Rect2i:
	var rx = clampi(center.x - radius, 1, GRID_W - 2)
	var rz = clampi(center.y - radius, 1, GRID_H - 2)
	var rex = clampi(center.x + radius, 1, GRID_W - 2)
	var rez = clampi(center.y + radius, 1, GRID_H - 2)
	return Rect2i(rx, rz, rex - rx + 1, rez - rz + 1)

func _smooth_cave_walls() -> void:
	## One pass: walls almost surrounded by floor become floor (rounds out nooks).
	var to_floor: Array = []
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] != Tile.WALL:
				continue
			var floor_neighbors = 0
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if dx == 0 and dz == 0:
						continue
					if grid[x + dx][z + dz] == Tile.FLOOR:
						floor_neighbors += 1
			if floor_neighbors >= 6:
				to_floor.append(Vector2i(x, z))
	for pos in to_floor:
		grid[pos.x][pos.y] = Tile.FLOOR

func _enforce_border_walls() -> void:
	for x in range(GRID_W):
		grid[x][0] = Tile.WALL
		grid[x][GRID_H - 1] = Tile.WALL
	for z in range(GRID_H):
		grid[0][z] = Tile.WALL
		grid[GRID_W - 1][z] = Tile.WALL

# ============================================
# BUILDING INTERIOR LAYOUT
# A central hall with rooms partitioned off either side, joined by doorways.
# ============================================

func _generate_building_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	var mid_z = GRID_H / 2

	# Open floor for the whole interior (outer ring stays wall)
	_carve_rect(Rect2i(1, 1, GRID_W - 2, GRID_H - 2))

	# Vertical partition walls dividing the interior into segments
	var partition_count = 2 + _rng.randi_range(0, 1)
	var xs: Array = []
	var seg_w = (GRID_W - 10) / (partition_count + 1)
	for i in range(partition_count):
		xs.append(6 + seg_w * (i + 1) + _rng.randi_range(-1, 1))

	for px in xs:
		for z in range(1, GRID_H - 1):
			# Keep the central hall (3 rows) open through every partition
			if z >= mid_z - 1 and z <= mid_z + 1:
				continue
			grid[px][z] = Tile.WALL

	# Horizontal walls separating the hall from the side rooms, with doorways
	var segments: Array = []  # [{x_from, x_to}] segments between partitions
	var seg_start = 1
	for px in xs:
		segments.append({"from": seg_start, "to": px - 1})
		seg_start = px + 1
	segments.append({"from": seg_start, "to": GRID_W - 2})

	for seg in segments:
		var fx = seg["from"]
		var tx = seg["to"]
		if tx - fx < 3:
			continue
		# Wall rows above and below the hall
		for x in range(fx, tx + 1):
			grid[x][mid_z - 2] = Tile.WALL
			grid[x][mid_z + 2] = Tile.WALL
		# Doorways (2-wide) into the top and bottom rooms of this segment
		var door_top = _rng.randi_range(fx + 1, tx - 2)
		grid[door_top][mid_z - 2] = Tile.FLOOR
		grid[door_top + 1][mid_z - 2] = Tile.FLOOR
		var door_bot = _rng.randi_range(fx + 1, tx - 2)
		grid[door_bot][mid_z + 2] = Tile.FLOOR
		grid[door_bot + 1][mid_z + 2] = Tile.FLOOR
		# Register the two side rooms of this segment
		rooms.append({"rect": Rect2i(fx, 1, tx - fx + 1, mid_z - 3), "kind": "room", "elev": 0})
		rooms.append({"rect": Rect2i(fx, mid_z + 3, tx - fx + 1, GRID_H - 4 - mid_z), "kind": "room", "elev": 0})

	# The far-right rooms hold the goods
	if rooms.size() >= 2:
		rooms[rooms.size() - 1]["kind"] = "treasure"
		rooms[rooms.size() - 2]["kind"] = "treasure"

	# Entry hall registered as the start room (no enemies at the door)
	rooms.insert(0, {"rect": Rect2i(1, mid_z - 1, 6, 3), "kind": "start", "elev": 0})

# ============================================
# SHARED CARVING HELPERS
# ============================================

func _init_grid_walls() -> void:
	grid.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(Tile.WALL)
		grid.append(col)

func _carve_rect(rect: Rect2i) -> void:
	for x in range(maxi(0, rect.position.x), mini(rect.end.x, GRID_W)):
		for z in range(maxi(0, rect.position.y), mini(rect.end.y, GRID_H)):
			grid[x][z] = Tile.FLOOR

func _carve_corridor_h(from_x: int, to_x: int, z: int) -> void:
	var min_x = mini(from_x, to_x)
	var max_x = maxi(from_x, to_x)
	for x in range(maxi(0, min_x), mini(max_x + 1, GRID_W)):
		if z >= 0 and z < GRID_H:
			grid[x][z] = Tile.FLOOR

func _carve_corridor_v(x: int, from_z: int, to_z: int) -> void:
	var min_z = mini(from_z, to_z)
	var max_z = maxi(from_z, to_z)
	for z in range(maxi(0, min_z), mini(max_z + 1, GRID_H)):
		if x >= 0 and x < GRID_W:
			grid[x][z] = Tile.FLOOR

# ============================================
# ELEVATION
# Some rooms become hills (elev 1) and plateaus (elev 2 with a terraced rim)
# so high ground reads as natural terrain rather than floating platforms.
# ============================================

func _generate_elevation() -> void:
	elevation.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(0)
		elevation.append(col)

	if interior_kind == "building":
		return  # Buildings are flat inside

	var elevated_count = 0
	for i in range(rooms.size()):
		var room = rooms[i]
		if room["kind"] in ["start", "exit"]:
			continue
		if room["kind"] == "arena":
			# Raised platform at the center of the arena
			var c = (room["rect"] as Rect2i).get_center()
			_set_elevation_rect(Rect2i(c.x - 2, c.y - 1, 4, 3), 1)
			continue
		var chance = 0.30 if interior_kind == "" else 0.22
		if _rng.randf() >= chance:
			continue
		var rect: Rect2i = room["rect"]
		var elev = 1
		if interior_kind == "" and _rng.randf() < 0.35 and rect.size.x >= 7 and rect.size.y >= 6:
			elev = 2
		if elev == 2:
			# Terraced plateau: 1-tile rim at elev 1, core at elev 2
			_set_elevation_rect(rect, 1)
			_set_elevation_rect(rect.grow(-1), 2)
		else:
			_set_elevation_rect(rect, 1)
		room["elev"] = elev
		elevated_count += 1

	print("[DUNGEON] Elevation generated (%d elevated rooms)" % elevated_count)

func _set_elevation_rect(rect: Rect2i, elev: int) -> void:
	for x in range(maxi(0, rect.position.x), mini(rect.end.x, GRID_W)):
		for z in range(maxi(0, rect.position.y), mini(rect.end.y, GRID_H)):
			if grid[x][z] == Tile.FLOOR:
				elevation[x][z] = elev

func get_elevation(grid_pos: Vector2i) -> int:
	if grid_pos.x < 0 or grid_pos.x >= GRID_W or grid_pos.y < 0 or grid_pos.y >= GRID_H:
		return 0
	return elevation[grid_pos.x][grid_pos.y]

func get_elevation_world_y(grid_pos: Vector2i) -> float:
	## Returns the world Y position for the given grid tile based on elevation.
	return get_elevation(grid_pos) * ELEV_STEP

func is_higher_elevation(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	## Returns true if to_pos is at a higher elevation than from_pos.
	return get_elevation(to_pos) > get_elevation(from_pos)

# ============================================
# TERRAIN VISUALS (MultiMesh — thousands of tiles stay cheap to render)
# ============================================

func _tile_noise(x: int, z: int, salt: int = 0) -> float:
	## Deterministic pseudo-noise in [0, 1): coarse patches blended with fine grain.
	var coarse = float(hash(Vector3i(x / 3, z / 3, salt + _layout_seed)) % 10000) / 10000.0
	var fine = float(hash(Vector3i(x, z, salt + _layout_seed + 7919)) % 10000) / 10000.0
	return coarse * 0.6 + fine * 0.4

func _add_multimesh(mesh: Mesh, items: Array, shaded: bool = true, rough: float = 0.95) -> void:
	## Creates a MultiMeshInstance3D under the visuals root from a list of
	## {xform: Transform3D, color: Color} entries.
	if items.is_empty():
		return
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in range(items.size()):
		mm.set_instance_transform(i, items[i]["xform"])
		mm.set_instance_color(i, items[i]["color"])
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = rough
	if not shaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmi.material_override = mat
	_visuals_root.add_child(mmi)

func _build_floor_visuals() -> void:
	## Per-tile ground at elevation 0 with subtle natural color variation.
	var pal = get_palette()
	var items: Array = []
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR or elevation[x][z] > 0:
				continue
			var n = _tile_noise(x, z, 11)
			var col: Color = pal["floor_a"].lerp(pal["floor_b"], n)
			var xform = Transform3D(
				Basis.from_scale(Vector3(1.0, 0.1, 1.0)),
				Vector3(x + 0.5, -0.05, z + 0.5)
			)
			items.append({"xform": xform, "color": col})
	_add_multimesh(BoxMesh.new(), items)
	print("[DUNGEON] Built %d floor tiles" % items.size())

func _build_walls() -> void:
	## Rock walls with varied heights and shades. Walls beside elevated terrain
	## grow taller so high ground stays properly enclosed.
	var pal = get_palette()
	var is_building = interior_kind == "building"
	var items: Array = []
	var site_tiles = _all_site_footprint_tiles()
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.WALL:
				continue
			if not _has_adjacent_floor(x, z):
				continue
			if site_tiles.has(Vector2i(x, z)):
				continue  # Site structures draw their own exteriors
			var n = _tile_noise(x, z, 23)
			var height: float
			if is_building:
				height = 2.3 + n * 0.15  # Interior walls are uniform and man-made
			else:
				height = 1.5 + n * 0.9 + _max_adjacent_floor_elevation(x, z) * ELEV_STEP
			var col: Color = pal["wall_a"].lerp(pal["wall_b"], _tile_noise(x, z, 31))
			var xform = Transform3D(
				Basis.from_scale(Vector3(1.0, height, 1.0)),
				Vector3(x + 0.5, height / 2.0, z + 0.5)
			)
			items.append({"xform": xform, "color": col})
	_add_multimesh(BoxMesh.new(), items)
	print("[DUNGEON] Built %d wall segments (%s %dx%d)" % [items.size(), get_location_name(), GRID_W, GRID_H])

func _has_adjacent_floor(x: int, z: int) -> bool:
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var nx = x + dx
			var nz = z + dz
			if nx >= 0 and nx < GRID_W and nz >= 0 and nz < GRID_H:
				if grid[nx][nz] == Tile.FLOOR:
					return true
	return false

func _max_adjacent_floor_elevation(x: int, z: int) -> int:
	var max_elev = 0
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var nx = x + dx
			var nz = z + dz
			if nx >= 0 and nx < GRID_W and nz >= 0 and nz < GRID_H:
				if grid[nx][nz] == Tile.FLOOR:
					max_elev = maxi(max_elev, elevation[nx][nz])
	return max_elev

func _build_elevation_visuals() -> void:
	## Elevated terrain rendered as rocky cliff faces with a soil top surface,
	## plus carved stone steps wherever a walkable 1-level transition exists.
	var pal = get_palette()
	var cliff_items: Array = []
	var top_items: Array = []
	var step_items: Array = []

	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR or elevation[x][z] <= 0:
				continue
			var h = elevation[x][z] * ELEV_STEP
			# Cliff body: ground up to just below the top surface
			var body_h = h - 0.06
			var n = _tile_noise(x, z, 41)
			var cliff_col: Color = pal["cliff"].lerp(pal["wall_b"], n * 0.5)
			cliff_items.append({
				"xform": Transform3D(
					Basis.from_scale(Vector3(1.0, body_h, 1.0)),
					Vector3(x + 0.5, body_h / 2.0, z + 0.5)
				),
				"color": cliff_col,
			})
			# Top surface: matches the floor palette but reads slightly sun-lit
			var top_col: Color = pal["floor_a"].lerp(pal["floor_b"], _tile_noise(x, z, 11)).lightened(0.12)
			top_items.append({
				"xform": Transform3D(
					Basis.from_scale(Vector3(1.0, 0.06, 1.0)),
					Vector3(x + 0.5, h - 0.03, z + 0.5)
				),
				"color": top_col,
			})

	# Stone steps on every walkable single-level transition
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR:
				continue
			var base_elev = elevation[x][z]
			for dir in dirs:
				var nx = x + dir.x
				var nz = z + dir.y
				if nx < 0 or nx >= GRID_W or nz < 0 or nz >= GRID_H:
					continue
				if grid[nx][nz] != Tile.FLOOR or elevation[nx][nz] != base_elev + 1:
					continue
				# Three steps climbing from this tile up to the neighbor's ledge
				var angle = atan2(-float(dir.y), float(dir.x)) + PI / 2.0
				var dir3 = Vector3(dir.x, 0, dir.y)
				var base_y = base_elev * ELEV_STEP
				for k in range(3):
					var step_h = ELEV_STEP * (k + 1) / 4.0
					var dist = 0.5 - 0.07 - (2 - k) * 0.14
					var center = Vector3(x + 0.5, 0, z + 0.5) + dir3 * dist
					var basis = Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(0.7, step_h, 0.13))
					step_items.append({
						"xform": Transform3D(basis, Vector3(center.x, base_y + step_h / 2.0, center.z)),
						"color": pal["step"],
					})

	_add_multimesh(BoxMesh.new(), cliff_items)
	_add_multimesh(BoxMesh.new(), top_items)
	_add_multimesh(BoxMesh.new(), step_items, true, 0.85)
	print("[DUNGEON] Built %d cliff tiles, %d stone steps" % [cliff_items.size(), step_items.size() / 3])

func _build_decorations() -> void:
	## Scatters small non-blocking props for natural variety: rocks and shrubs
	## outdoors, stalagmites in caves, crates inside buildings.
	var pal = get_palette()
	var rock_items: Array = []
	var bush_items: Array = []
	var cone_items: Array = []

	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR:
				continue
			var pos = Vector2i(x, z)
			if _reserved.has(pos):
				continue
			var near_wall = not _has_adjacent_floor_on_all_sides(x, z)
			var y_base = elevation[x][z] * ELEV_STEP
			var n = _tile_noise(x, z, 53)
			var jx = (_tile_noise(x, z, 61) - 0.5) * 0.5
			var jz = (_tile_noise(x, z, 67) - 0.5) * 0.5
			var rot = Basis(Vector3.UP, _tile_noise(x, z, 71) * TAU)

			if interior_kind == "cave":
				if near_wall and n < 0.14:
					# Stalagmite
					var s = 0.25 + _tile_noise(x, z, 73) * 0.45
					cone_items.append({
						"xform": Transform3D(rot * Basis.from_scale(Vector3(s * 0.7, s * 1.6, s * 0.7)),
							Vector3(x + 0.5 + jx, y_base + s * 0.8, z + 0.5 + jz)),
						"color": pal["wall_a"].lerp(pal["wall_b"], n * 3.0),
					})
				elif near_wall and n < 0.2:
					rock_items.append(_make_rock(x, z, jx, jz, y_base, rot, pal))
			elif interior_kind == "building":
				if near_wall and n < 0.10:
					# Crates and furniture
					var s = 0.4 + _tile_noise(x, z, 79) * 0.2
					rock_items.append({
						"xform": Transform3D(rot * Basis.from_scale(Vector3(s, s, s)),
							Vector3(x + 0.5 + jx * 0.5, y_base + s / 2.0, z + 0.5 + jz * 0.5)),
						"color": pal["accent"].lerp(pal["floor_b"], n * 2.0),
					})
			else:
				if near_wall and n < 0.11:
					rock_items.append(_make_rock(x, z, jx, jz, y_base, rot, pal))
				elif n > 0.96:
					# Open-field shrub
					var s = 0.5 + _tile_noise(x, z, 83) * 0.3
					bush_items.append({
						"xform": Transform3D(rot * Basis.from_scale(Vector3(s, s * 0.55, s)),
							Vector3(x + 0.5 + jx, y_base + s * 0.2, z + 0.5 + jz)),
						"color": pal["accent"].lerp(pal["floor_a"], _tile_noise(x, z, 89) * 0.6),
					})

	_add_multimesh(BoxMesh.new(), rock_items)
	if not bush_items.is_empty():
		var bush_mesh = SphereMesh.new()
		bush_mesh.radial_segments = 12
		bush_mesh.rings = 6
		_add_multimesh(bush_mesh, bush_items)
	if not cone_items.is_empty():
		var cone = CylinderMesh.new()
		cone.top_radius = 0.04
		cone.bottom_radius = 0.5
		cone.height = 1.0
		cone.radial_segments = 10
		_add_multimesh(cone, cone_items)
	print("[DUNGEON] Placed %d decorations" % (rock_items.size() + bush_items.size() + cone_items.size()))

func _make_rock(x: int, z: int, jx: float, jz: float, y_base: float, rot: Basis, pal: Dictionary) -> Dictionary:
	var sx = 0.2 + _tile_noise(x, z, 91) * 0.25
	var sy = 0.15 + _tile_noise(x, z, 97) * 0.2
	var sz = 0.2 + _tile_noise(x, z, 101) * 0.25
	return {
		"xform": Transform3D(rot * Basis.from_scale(Vector3(sx, sy, sz)),
			Vector3(x + 0.5 + jx, y_base + sy / 2.0, z + 0.5 + jz)),
		"color": pal["cliff"].lerp(pal["wall_b"], _tile_noise(x, z, 103)),
	}

func _has_adjacent_floor_on_all_sides(x: int, z: int) -> bool:
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx = x + dir.x
		var nz = z + dir.y
		if nx < 0 or nx >= GRID_W or nz < 0 or nz >= GRID_H:
			return false
		if grid[nx][nz] != Tile.FLOOR:
			return false
	return true

# ============================================
# FOG OF WAR (MultiMesh — one instance per tile)
# ============================================

func _build_fog() -> void:
	_revealed.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(false)
		_revealed.append(col)

	_fog_mm = MultiMesh.new()
	_fog_mm.transform_format = MultiMesh.TRANSFORM_3D
	_fog_mm.mesh = BoxMesh.new()
	_fog_mm.instance_count = GRID_W * GRID_H
	for x in range(GRID_W):
		for z in range(GRID_H):
			_fog_mm.set_instance_transform(x * GRID_H + z, _fog_shown_xform(x, z))

	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = _fog_mm
	var fog_mat = StandardMaterial3D.new()
	fog_mat.albedo_color = Color(0.012, 0.012, 0.022, 1.0)
	fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmi.material_override = fog_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals_root.add_child(mmi)

	_fog_initialized = true
	print("[DUNGEON] Fog of war initialized (%d tiles)" % (GRID_W * GRID_H))

func _fog_shown_xform(x: int, z: int) -> Transform3D:
	return Transform3D(
		Basis.from_scale(Vector3(1.05, FOG_HEIGHT, 1.05)),
		Vector3(x + 0.5, FOG_HEIGHT / 2.0 - 0.5, z + 0.5)
	)

func _fog_hidden_xform() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), Vector3(0, -100, 0))

func reveal_around(center: Vector2i) -> void:
	## Permanently reveals tiles within FOG_REVEAL_RADIUS of center.
	if not _fog_initialized:
		return
	for dx in range(-FOG_REVEAL_RADIUS, FOG_REVEAL_RADIUS + 1):
		for dz in range(-FOG_REVEAL_RADIUS, FOG_REVEAL_RADIUS + 1):
			# Circular reveal (Euclidean distance)
			if dx * dx + dz * dz > FOG_REVEAL_RADIUS * FOG_REVEAL_RADIUS:
				continue
			var nx = center.x + dx
			var nz = center.y + dz
			if nx >= 0 and nx < GRID_W and nz >= 0 and nz < GRID_H:
				if not _revealed[nx][nz]:
					_revealed[nx][nz] = true
					_fog_mm.set_instance_transform(nx * GRID_H + nz, _fog_hidden_xform())

func is_revealed(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= GRID_W or grid_pos.y < 0 or grid_pos.y >= GRID_H:
		return false
	return _revealed[grid_pos.x][grid_pos.y]

func update_enemy_fog_visibility(enemies: Array, gm: GridManager) -> void:
	## Hides enemies that are in unrevealed tiles.
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_grid = gm.world_to_grid(enemy.position)
		enemy.visible = is_revealed(enemy_grid)

# ============================================
# SITES — enterable caves & buildings in the overworld, exits inside interiors
# ============================================

func _place_sites() -> void:
	## Picks suitable field rooms and erects cave entrances / building exteriors.
	var site_total = 2 + (world_level - 1)
	var cave_count = 0
	var building_count = 0
	var candidates: Array = []
	for i in range(rooms.size()):
		var room = rooms[i]
		if room["kind"] != "field" or room["elev"] > 0:
			continue
		var rect: Rect2i = room["rect"]
		if rect.size.x >= 8 and rect.size.y >= 7:
			candidates.append(i)

	for s in range(site_total):
		if candidates.is_empty():
			break
		var pick = _rng.randi_range(0, candidates.size() - 1)
		var room_idx = candidates[pick]
		candidates.remove_at(pick)
		var rect: Rect2i = rooms[room_idx]["rect"]
		var kind = "cave" if s % 2 == 0 else "building"

		var fp_w = 3 if kind == "cave" else 4
		var fp_d = 3
		# Footprint sits in the upper part of the room, entrance opens south
		var fx = clampi(rect.get_center().x - fp_w / 2, rect.position.x + 1, rect.end.x - fp_w - 1)
		var fz = rect.position.y + 1
		var footprint: Array = []
		for x in range(fx, fx + fp_w):
			for z in range(fz, fz + fp_d):
				footprint.append(Vector2i(x, z))
		var entrance = Vector2i(fx + fp_w / 2, fz + fp_d)

		# Block the footprint, then verify the world is still fully walkable
		if not _try_block_footprint(footprint):
			continue
		rooms[room_idx]["kind"] = "site"

		var id: String
		var display_name: String
		if kind == "cave":
			id = "cave_%d" % cave_count
			display_name = "Cave"
			cave_count += 1
		else:
			id = "building_%d" % building_count
			display_name = "Building"
			building_count += 1

		_create_site(kind, id, display_name, footprint, entrance, fx, fz, fp_w, fp_d)

	print("[DUNGEON] Placed %d enterable sites" % site_nodes.size())

func _try_block_footprint(footprint: Array) -> bool:
	## Marks footprint tiles as walls; reverts if that would split the map.
	var changed: Array = []
	for pos in footprint:
		if grid[pos.x][pos.y] == Tile.FLOOR:
			grid[pos.x][pos.y] = Tile.WALL
			changed.append(pos)
	if _floor_fully_connected():
		return true
	for pos in changed:
		grid[pos.x][pos.y] = Tile.FLOOR
	return false

func _floor_fully_connected() -> bool:
	## BFS from player_start — true if every floor tile is reachable.
	var total = 0
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.FLOOR:
				total += 1
	if total == 0:
		return false
	var visited: Dictionary = {}
	var frontier: Array = [player_start]
	visited[player_start] = true
	var count = 0
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		count += 1
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next = current + dir
			if visited.has(next):
				continue
			if next.x < 0 or next.x >= GRID_W or next.y < 0 or next.y >= GRID_H:
				continue
			if grid[next.x][next.y] != Tile.FLOOR:
				continue
			visited[next] = true
			frontier.append(next)
	return count == total

func _create_site(kind: String, id: String, display_name: String, footprint: Array,
		entrance: Vector2i, fx: int, fz: int, fp_w: int, fp_d: int) -> void:
	var site_root = Node3D.new()
	site_root.name = "Site_%s" % id
	var center = Vector3(fx + fp_w / 2.0, 0, fz + fp_d / 2.0)
	site_root.position = center

	if kind == "building":
		_build_building_exterior(site_root, fp_w, fp_d)
	else:
		_build_cave_entrance(site_root, fp_w, fp_d)

	# Name label floating above the structure
	var label = Label3D.new()
	label.text = display_name
	label.font_size = 22
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.95, 0.75)
	label.position = Vector3(0, 3.2, 0)
	site_root.add_child(label)

	# Interact prompt (shown when the player is near the entrance)
	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Enter"
	interact_label.font_size = 16
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 2.6, 0)
	interact_label.visible = false
	site_root.add_child(interact_label)

	_visuals_root.add_child(site_root)

	site_nodes.append({
		"node": site_root,
		"grid_pos": entrance,
		"id": id,
		"kind": kind,
		"display_name": display_name,
		"label_node": interact_label,
		"footprint": footprint,
	})
	_reserve_area(entrance, 1)

func _build_building_exterior(root: Node3D, fp_w: int, fp_d: int) -> void:
	## Simple generic structure: stone walls, pitched roof, door, lit windows.
	var w = fp_w - 0.3
	var d = fp_d - 0.3
	var wall_h = 1.8

	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(w, wall_h, d)
	body.mesh = body_mesh
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.55, 0.50, 0.44)
	body_mat.roughness = 0.9
	body.material_override = body_mat
	body.position = Vector3(0, wall_h / 2.0, 0)
	root.add_child(body)

	var roof = MeshInstance3D.new()
	var roof_mesh = PrismMesh.new()
	roof_mesh.size = Vector3(d + 0.5, 0.9, w + 0.5)
	roof_mesh.left_to_right = 0.5
	roof.mesh = roof_mesh
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.42, 0.22, 0.16)
	roof_mat.roughness = 0.85
	roof.material_override = roof_mat
	roof.rotation_degrees.y = 90.0  # Ridge runs along the building's long axis
	roof.position = Vector3(0, wall_h + 0.45, 0)
	root.add_child(roof)

	# Door on the south face (toward the entrance tile)
	var door = MeshInstance3D.new()
	var door_mesh = BoxMesh.new()
	door_mesh.size = Vector3(0.7, 1.15, 0.08)
	door.mesh = door_mesh
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.25, 0.16, 0.10)
	door_mat.roughness = 0.7
	door.material_override = door_mat
	door.position = Vector3(0, 0.58, d / 2.0 + 0.02)
	root.add_child(door)

	# Two warm-lit windows flanking the door
	for side in [-1.0, 1.0]:
		var window = MeshInstance3D.new()
		var win_mesh = BoxMesh.new()
		win_mesh.size = Vector3(0.4, 0.4, 0.06)
		window.mesh = win_mesh
		var win_mat = StandardMaterial3D.new()
		win_mat.albedo_color = Color(1.0, 0.85, 0.5)
		win_mat.emission_enabled = true
		win_mat.emission = Color(1.0, 0.75, 0.35)
		win_mat.emission_energy_multiplier = 0.8
		window.material_override = win_mat
		window.position = Vector3(side * w * 0.3, 1.1, d / 2.0 + 0.02)
		root.add_child(window)

func _build_cave_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	## Rocky mound with a dark opening on the south face.
	var pal = get_palette()
	var mound = MeshInstance3D.new()
	var cone = CylinderMesh.new()
	cone.top_radius = 0.5
	cone.bottom_radius = fp_w * 0.72
	cone.height = 2.2
	cone.radial_segments = 12
	mound.mesh = cone
	var mound_mat = StandardMaterial3D.new()
	mound_mat.albedo_color = pal["cliff"]
	mound_mat.roughness = 1.0
	mound.material_override = mound_mat
	mound.position = Vector3(0, 1.1, -0.2)
	root.add_child(mound)

	# Flanking boulders
	for side in [-1.0, 1.0]:
		var boulder = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.45
		sphere.height = 0.8
		sphere.radial_segments = 10
		sphere.rings = 6
		boulder.mesh = sphere
		var b_mat = StandardMaterial3D.new()
		b_mat.albedo_color = pal["wall_b"]
		b_mat.roughness = 1.0
		boulder.material_override = b_mat
		boulder.position = Vector3(side * fp_w * 0.45, 0.3, fp_d / 2.0 - 0.4)
		root.add_child(boulder)

	# The dark opening itself
	var opening = MeshInstance3D.new()
	var open_mesh = BoxMesh.new()
	open_mesh.size = Vector3(0.95, 1.1, 0.5)
	opening.mesh = open_mesh
	var open_mat = StandardMaterial3D.new()
	open_mat.albedo_color = Color(0.01, 0.01, 0.015)
	open_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	opening.material_override = open_mat
	opening.position = Vector3(0, 0.55, fp_d / 2.0 - 0.15)
	root.add_child(opening)

func _place_exit_site() -> void:
	## Inside an interior: a glowing doorway back to the overworld at the entry.
	var site_root = Node3D.new()
	site_root.name = "Site_exit"
	var world_pos = grid_manager.grid_to_world(player_start)
	world_pos.x -= 1.0  # Sit just behind the entry tile so the player isn't on it
	site_root.position = world_pos

	var portal = MeshInstance3D.new()
	var portal_mesh = BoxMesh.new()
	portal_mesh.size = Vector3(0.2, 1.6, 1.0)
	portal.mesh = portal_mesh
	var portal_mat = StandardMaterial3D.new()
	portal_mat.albedo_color = Color(0.55, 0.75, 1.0, 0.7)
	portal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	portal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal.material_override = portal_mat
	portal.position = Vector3(0, 0.8, 0)
	site_root.add_child(portal)

	var label = Label3D.new()
	label.text = "Exit"
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.7, 0.85, 1.0)
	label.position = Vector3(0, 2.0, 0)
	site_root.add_child(label)

	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Leave"
	interact_label.font_size = 16
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 1.7, 0)
	interact_label.visible = false
	site_root.add_child(interact_label)

	_visuals_root.add_child(site_root)

	site_nodes.append({
		"node": site_root,
		"grid_pos": player_start,
		"id": "exit",
		"kind": "exit",
		"display_name": "Exit",
		"label_node": interact_label,
		"footprint": [],
	})

func _all_site_footprint_tiles() -> Dictionary:
	var tiles: Dictionary = {}
	for site in site_nodes:
		for pos in site["footprint"]:
			tiles[pos] = true
	return tiles

func get_nearby_site(player_grid: Vector2i) -> int:
	## Returns the index of a site entrance within 1 tile of the player, or -1.
	for i in range(site_nodes.size()):
		var site_pos: Vector2i = site_nodes[i]["grid_pos"]
		var dist = absi(player_grid.x - site_pos.x) + absi(player_grid.y - site_pos.y)
		if dist <= 1:
			return i
	return -1

func get_site_by_id(id: String) -> int:
	for i in range(site_nodes.size()):
		if site_nodes[i]["id"] == id:
			return i
	return -1

func update_site_prompts(player_grid: Vector2i) -> void:
	for site in site_nodes:
		var entrance: Vector2i = site["grid_pos"]
		var revealed = is_revealed(entrance) or site["kind"] == "exit"
		if site["node"] and is_instance_valid(site["node"]):
			site["node"].visible = revealed
		var lbl = site["label_node"]
		if lbl:
			var dist = absi(player_grid.x - entrance.x) + absi(player_grid.y - entrance.y)
			lbl.visible = revealed and dist <= 2

# ============================================
# CHESTS
# ============================================

func _place_chests() -> void:
	var placed: Array[Vector2i] = []
	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		var want = false
		match kind:
			"start":
				want = interior_kind == ""  # A starter chest only in the overworld
			"arena", "deep", "treasure":
				want = true
			"exit":
				want = world_level >= 2
			"field", "chamber", "room":
				want = _rng.randf() < 0.55
			"site":
				want = false
		if not want:
			continue
		var cell = _pick_free_cell(rect, placed)
		if cell.x < 0:
			continue
		placed.append(cell)
		_create_chest(cell)

	# Restore previously opened chests from prior visits
	_restore_opened_chests()

func _pick_free_cell(rect: Rect2i, also_avoid: Array) -> Vector2i:
	## Deterministically picks a walkable, unreserved cell inside the rect.
	for _attempt in range(24):
		var x = _rng.randi_range(rect.position.x, rect.end.x - 1)
		var z = _rng.randi_range(rect.position.y, rect.end.y - 1)
		var pos = Vector2i(clampi(x, 0, GRID_W - 1), clampi(z, 0, GRID_H - 1))
		if grid[pos.x][pos.y] != Tile.FLOOR:
			continue
		if _reserved.has(pos) or pos in also_avoid:
			continue
		return pos
	return Vector2i(-1, -1)

func _reserve_area(center: Vector2i, radius: int) -> void:
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			_reserved[center + Vector2i(dx, dz)] = true

func _chest_key(index: int) -> String:
	if interior_id == "":
		return "world_%d_chest_%d" % [world_level, index]
	return "world_%d_%s_chest_%d" % [world_level, interior_id, index]

func _restore_opened_chests() -> void:
	## Restores chest state from prior visits. Handles both fully looted and
	## partially opened chests (gold claimed but item/card left behind).
	for i in range(chest_nodes.size()):
		var key = _chest_key(i)
		if not _opened_chests_ref.has(key):
			continue

		var state = _opened_chests_ref[key]

		# Visually open the chest
		chest_nodes[i]["opened"] = true
		var body_mesh: MeshInstance3D = chest_nodes[i]["body_mesh"]
		var lid_mesh: MeshInstance3D = chest_nodes[i]["lid_mesh"]
		if body_mesh:
			var mat = body_mesh.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(0.35, 0.3, 0.15)
		if lid_mesh:
			lid_mesh.rotation_degrees.x = -110
			lid_mesh.position = Vector3(0, 0.55, -0.15)

		if state is Dictionary:
			# Partially opened: gold was claimed, apply item/card claim flags
			chest_nodes[i]["contents"]["_gold_claimed"] = true
			if state.get("item_taken", false):
				chest_nodes[i]["contents"]["item"] = null
			if state.get("card_taken", false):
				chest_nodes[i]["contents"]["card"] = null
			# Check if now fully looted
			var contents = chest_nodes[i]["contents"]
			if contents.get("item") == null and contents.get("card") == null:
				mark_chest_looted(i)
		else:
			# Legacy true value or fully looted
			mark_chest_looted(i)

func _create_chest(grid_pos: Vector2i) -> void:
	var chest_root = Node3D.new()
	chest_root.name = "TreasureChest_%d" % chest_nodes.size()

	# Chest body (box)
	var body = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.7, 0.5, 0.5)
	body.mesh = box
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.6, 0.45, 0.15)  # Gold/brown
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	body.material_override = body_mat
	body.position = Vector3(0, 0.25, 0)
	chest_root.add_child(body)

	# Chest lid (slightly smaller box on top)
	var lid = MeshInstance3D.new()
	var lid_box = BoxMesh.new()
	lid_box.size = Vector3(0.72, 0.2, 0.52)
	lid.mesh = lid_box
	var lid_mat = StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.7, 0.55, 0.2)
	lid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	lid.material_override = lid_mat
	lid.position = Vector3(0, 0.5, 0)
	chest_root.add_child(lid)

	# Lock decoration (small metallic sphere)
	var lock = MeshInstance3D.new()
	var lock_mesh = SphereMesh.new()
	lock_mesh.radius = 0.08
	lock_mesh.height = 0.16
	lock.mesh = lock_mesh
	var lock_mat = StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.8, 0.75, 0.3)
	lock_mat.metallic = 0.8
	lock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	lock.material_override = lock_mat
	lock.position = Vector3(0, 0.38, 0.27)
	chest_root.add_child(lock)

	# Interact label (floating above chest)
	var label = Label3D.new()
	label.name = "InteractLabel"
	label.text = "[Shift] Open"
	label.font_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.9, 0.4)
	label.position = Vector3(0, 1.0, 0)
	label.visible = false
	chest_root.add_child(label)

	var world_pos = grid_manager.grid_to_world(grid_pos)
	world_pos.y = get_elevation_world_y(grid_pos)  # Sit on top of elevated terrain
	chest_root.position = world_pos

	_visuals_root.add_child(chest_root)
	_reserve_area(grid_pos, 0)

	# Generate chest contents using a deterministic seed so the same chest
	# always produces the same loot (important for persistence across transitions)
	var chest_index = chest_nodes.size()
	var contents = _generate_chest_contents(chest_index)

	chest_nodes.append({
		"node": chest_root,
		"grid_pos": grid_pos,
		"opened": false,
		"looted": false,
		"contents": contents,
		"body_mesh": body,
		"lid_mesh": lid
	})

func _generate_chest_contents(chest_index: int) -> Dictionary:
	# Use a deterministic RNG seeded by world + chest index so the same chest
	# always generates the same loot, even if the dungeon is recreated
	var rng = RandomNumberGenerator.new()
	if interior_id == "":
		rng.seed = hash("chest_w%d_c%d" % [world_level, chest_index])
	else:
		rng.seed = hash("chest_w%d_%s_c%d" % [world_level, interior_id, chest_index])

	var gold = rng.randi_range(15, 50) + (world_level - 1) * 10
	var contents: Dictionary = {"gold": gold, "item": null, "card": null}

	if rng.randf() < 0.5:
		contents["item"] = _get_random_item(rng)
	else:
		contents["card"] = _get_random_card(rng)

	return contents

func _get_random_item(rng: RandomNumberGenerator) -> ItemData:
	var item_creators: Array[Callable] = [
		ItemData.create_iron_helm,
		ItemData.create_leather_chest,
		ItemData.create_iron_sword,
		ItemData.create_wooden_shield,
		ItemData.create_gold_ring,
		ItemData.create_flame_dagger,
		ItemData.create_frost_orb,
		ItemData.create_leather_boots,
		ItemData.create_iron_gauntlets,
		ItemData.create_utility_belt,
		ItemData.create_ice_quiver,
		ItemData.create_fire_quiver,
		ItemData.create_belt_of_greater_healing,
	]
	var idx = rng.randi() % item_creators.size()
	return item_creators[idx].call()

func _get_random_card(rng: RandomNumberGenerator) -> Card:
	var card_creators: Array[Callable] = [
		Card.create_slash,
		Card.create_block,
		Card.create_heal,
		Card.create_draw,
		Card.create_empower,
		Card.create_healing_potion,
		Card.create_dagger_throw,
		Card.create_gain_mana,
		Card.create_halo,
		Card.create_blink,
	]
	var idx = rng.randi() % card_creators.size()
	return card_creators[idx].call()

# ============================================
# SPAWN ZONES (derived from rooms; difficulty scales with world + depth)
# ============================================

func _define_spawn_zones() -> void:
	spawn_zones.clear()

	# Enemy tiers scale with world level
	var base_melee = Enemy.EnemyType.WERERAT if world_level <= 2 else Enemy.EnemyType.SKELETON
	var mid_melee = Enemy.EnemyType.SKELETON if world_level <= 2 else Enemy.EnemyType.ARMORED_TROLL
	var heavy = Enemy.EnemyType.ARMORED_TROLL if world_level <= 3 else Enemy.EnemyType.ELITE
	var ranged = Enemy.EnemyType.ARCHER_RAT

	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue

		if kind == "arena" and interior_kind == "":
			_define_arena_zone(rect, mid_melee, heavy, ranged)
			continue

		# Chance for a room to host an enemy group
		var zone_chance = 0.75
		if kind in ["deep", "treasure"]:
			zone_chance = 1.0
		elif interior_kind == "building":
			zone_chance = 0.6
		if _rng.randf() >= zone_chance:
			continue

		# Group size grows with room area and depth into the map
		var depth = float(rect.get_center().x) / float(GRID_W)
		var count = clampi(2 + rect.get_area() / 36 + (1 if depth > 0.6 else 0), 2, 5)
		if interior_kind == "building":
			count = clampi(count - 1, 1, 3)

		var points: Array = []
		var types: Array = []
		for _i in range(count):
			var cell = _pick_free_cell(rect, points)
			if cell.x < 0:
				continue
			points.append(cell)
			types.append(_pick_enemy_type(depth, kind, base_melee, mid_melee, heavy, ranged))
		# Deep cave chambers are guarded by an elite-grade enemy
		if kind == "deep" and types.size() > 0:
			types[0] = heavy if world_level < 3 else Enemy.EnemyType.ELITE
		if points.is_empty():
			continue

		spawn_zones.append({
			"trigger_rect": rect.grow(1),
			"spawn_points": points,
			"enemy_types": types,
			"spawned": false
		})

	for pt_list in spawn_zones:
		for p in pt_list["spawn_points"]:
			_reserved[p] = true

	print("[DUNGEON] Defined %d spawn zones for %s" % [spawn_zones.size(), get_location_name()])

func _pick_enemy_type(depth: float, kind: String, base_melee, mid_melee, heavy, ranged):
	## Weighted pick; deeper rooms and cave chambers skew tougher.
	var roll = _rng.randf()
	var heavy_w = 0.10 + (0.10 if depth > 0.6 else 0.0) + (0.08 if kind in ["chamber", "deep"] else 0.0)
	var mid_w = 0.25 + (0.10 if depth > 0.4 else 0.0)
	var ranged_w = 0.25
	if roll < heavy_w:
		return heavy
	if roll < heavy_w + mid_w:
		return mid_melee
	if roll < heavy_w + mid_w + ranged_w:
		return ranged
	return base_melee

func _define_arena_zone(rect: Rect2i, mid_melee, heavy, ranged) -> void:
	var c = rect.get_center()
	var boss_points: Array = []
	var boss_types: Array = []
	if world_level >= 4:
		boss_points = [c + Vector2i(0, -2), c + Vector2i(2, 0), c + Vector2i(0, 2), c + Vector2i(3, -1)]
		boss_types = [Enemy.EnemyType.BOSS, Enemy.EnemyType.ELITE, heavy, ranged]
	elif world_level >= 2:
		boss_points = [c + Vector2i(0, -2), c + Vector2i(2, 1), c + Vector2i(1, 3)]
		boss_types = [Enemy.EnemyType.ELITE, heavy, ranged]
	else:
		boss_points = [c + Vector2i(0, 0), c + Vector2i(2, 2)]
		boss_types = [Enemy.EnemyType.SKELETON, mid_melee]

	spawn_zones.append({
		"trigger_rect": rect.grow(1),
		"spawn_points": boss_points,
		"enemy_types": boss_types,
		"spawned": false
	})

# ============================================
# WAYPOINTS
# ============================================

func _place_waypoints() -> void:
	var mid_z = GRID_H / 2

	# Transport portal in starting room
	_create_waypoint(Vector2i(3, mid_z), "transport", "Transport Portal")

	# Exit to next world (in the far exit room)
	if world_level < 5:
		_create_waypoint(Vector2i(GRID_W - 4, mid_z), "next_world", "World %d" % (world_level + 1))

	# Exit to previous world
	if world_level > 1:
		_create_waypoint(Vector2i(3, mid_z - 3), "prev_world", "World %d" % (world_level - 1))

func _create_waypoint(grid_pos: Vector2i, target: String, display_name: String) -> void:
	var wp_root = Node3D.new()
	wp_root.name = "Waypoint_%s" % target

	# Waypoint visual: flat glowing disc on the ground
	var pillar = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 0.08
	pillar.mesh = cyl
	var pillar_mat = StandardMaterial3D.new()
	match target:
		"transport":
			pillar_mat.albedo_color = Color(0.5, 0.7, 1.0, 0.9)
		"town":
			pillar_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.8)
		"next_world":
			pillar_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.8)
		"prev_world":
			pillar_mat.albedo_color = Color(1.0, 0.8, 0.3, 0.8)
		_:
			pillar_mat.albedo_color = Color(0.8, 0.8, 0.8, 0.8)
	pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar.material_override = pillar_mat
	pillar.position = Vector3(0, 0.05, 0)
	wp_root.add_child(pillar)

	# Label
	var label = Label3D.new()
	label.name = "WaypointLabel"
	label.text = display_name
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 1.0, 0.8)
	label.position = Vector3(0, 0.8, 0)
	wp_root.add_child(label)

	# Interact label (shown when nearby)
	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Travel"
	interact_label.font_size = 16
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 1.2, 0)
	interact_label.visible = false
	wp_root.add_child(interact_label)

	var world_pos = grid_manager.grid_to_world(grid_pos)
	world_pos.y = get_elevation_world_y(grid_pos)
	wp_root.position = world_pos
	_visuals_root.add_child(wp_root)
	_reserve_area(grid_pos, 1)

	waypoint_nodes.append({
		"node": wp_root,
		"grid_pos": grid_pos,
		"target": target,
		"display_name": display_name,
		"label_node": interact_label,
		"discovered": false,
		"pillar_mesh": pillar
	})

func get_nearby_waypoint(player_grid: Vector2i) -> int:
	## Returns the index of a waypoint within 1 tile of the player, or -1.
	for i in range(waypoint_nodes.size()):
		var wp_pos: Vector2i = waypoint_nodes[i]["grid_pos"]
		var dist = absi(player_grid.x - wp_pos.x) + absi(player_grid.y - wp_pos.y)
		if dist <= 1:
			return i
	return -1

func get_waypoint_target(index: int) -> String:
	if index >= 0 and index < waypoint_nodes.size():
		return waypoint_nodes[index]["target"]
	return ""

func discover_waypoint(index: int) -> bool:
	## Marks a waypoint as discovered. Returns true if newly discovered.
	if index < 0 or index >= waypoint_nodes.size():
		return false
	if waypoint_nodes[index]["discovered"]:
		return false
	waypoint_nodes[index]["discovered"] = true
	# Visual change: make pillar brighter/opaque to show it's activated
	var pillar = waypoint_nodes[index]["pillar_mesh"] as MeshInstance3D
	if pillar and pillar.material_override:
		var mat = pillar.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = 1.0
			mat.emission_enabled = true
			mat.emission = Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b)
			mat.emission_energy_multiplier = 0.5
	# Update interact label text
	var lbl = waypoint_nodes[index]["label_node"] as Label3D
	if lbl:
		lbl.text = "[Shift] Teleport"
	print("[DUNGEON] Waypoint discovered: %s" % waypoint_nodes[index]["display_name"])
	return true

func get_waypoint_on_tile(player_grid: Vector2i) -> int:
	## Returns the index of a waypoint the player is standing on, or -1.
	for i in range(waypoint_nodes.size()):
		if waypoint_nodes[i]["grid_pos"] == player_grid:
			return i
	return -1

func update_waypoint_prompts(player_grid: Vector2i) -> void:
	for wp in waypoint_nodes:
		var wp_pos: Vector2i = wp["grid_pos"]
		var dist = absi(player_grid.x - wp_pos.x) + absi(player_grid.y - wp_pos.y)
		var interact_lbl = wp["label_node"]
		if interact_lbl:
			if wp["discovered"]:
				interact_lbl.visible = dist <= 2
			else:
				# Undiscovered: show "Walk here to discover" hint
				interact_lbl.text = "Walk here to discover"
				interact_lbl.visible = dist <= 3

# ============================================
# MINIMAP DATA
# ============================================

func get_floor_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.FLOOR:
				tiles.append(Vector2i(x, z))
	return tiles

func check_player_position(player_grid: Vector2i) -> Array:
	## Returns array of spawn zone indices that should be triggered.
	var triggered: Array = []
	for i in range(spawn_zones.size()):
		if spawn_zones[i]["spawned"]:
			continue
		var rect: Rect2i = spawn_zones[i]["trigger_rect"]
		if rect.has_point(player_grid):
			spawn_zones[i]["spawned"] = true
			triggered.append(i)
			player_entered_zone.emit(i)
	return triggered

func get_spawn_zone(index: int) -> Dictionary:
	if index >= 0 and index < spawn_zones.size():
		return spawn_zones[index]
	return {}

func is_wall(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= GRID_W or grid_pos.y < 0 or grid_pos.y >= GRID_H:
		return true
	return grid[grid_pos.x][grid_pos.y] == Tile.WALL

func is_floor(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= GRID_W or grid_pos.y < 0 or grid_pos.y >= GRID_H:
		return false
	return grid[grid_pos.x][grid_pos.y] == Tile.FLOOR

func get_wall_tiles() -> Array[Vector2i]:
	## Returns all wall tiles (for pathfinding blocked tiles).
	var tiles: Array[Vector2i] = []
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.WALL:
				tiles.append(Vector2i(x, z))
	return tiles

func get_nearby_chest(player_grid: Vector2i) -> int:
	## Returns the index of a chest within 1 tile of the player, or -1.
	## Returns chests that are unopened OR opened but still have unclaimed loot.
	for i in range(chest_nodes.size()):
		if chest_nodes[i]["looted"]:
			continue
		var chest_pos: Vector2i = chest_nodes[i]["grid_pos"]
		var dist = absi(player_grid.x - chest_pos.x) + absi(player_grid.y - chest_pos.y)
		if dist <= 1:
			return i
	return -1

func open_chest(index: int) -> Dictionary:
	## Opens a chest (or re-opens one with unclaimed loot) and returns its contents.
	if index < 0 or index >= chest_nodes.size():
		return {}
	if chest_nodes[index]["looted"]:
		return {}

	var first_open = not chest_nodes[index]["opened"]
	chest_nodes[index]["opened"] = true

	# Visual feedback on first open: change chest color to dark / opened look
	if first_open:
		var body_mesh: MeshInstance3D = chest_nodes[index]["body_mesh"]
		var lid_mesh: MeshInstance3D = chest_nodes[index]["lid_mesh"]
		if body_mesh:
			var mat = body_mesh.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(0.35, 0.3, 0.15)  # Darkened
		if lid_mesh:
			# Rotate lid open
			lid_mesh.rotation_degrees.x = -110
			lid_mesh.position = Vector3(0, 0.55, -0.15)

	# Persist partial state so gold isn't re-granted if player leaves and returns
	if first_open:
		var key = _chest_key(index)
		if not _opened_chests_ref.has(key):
			_opened_chests_ref[key] = {"item_taken": false, "card_taken": false}

	print("[DUNGEON] Opened chest %d: %s" % [index, chest_nodes[index]["contents"]])
	return chest_nodes[index]["contents"]

func mark_chest_looted(index: int) -> void:
	## Marks a chest as fully looted (all items/cards claimed). No further interaction.
	if index < 0 or index >= chest_nodes.size():
		return
	chest_nodes[index]["looted"] = true

	# Record in global persistence dict so chests stay looted across world transitions
	_opened_chests_ref[_chest_key(index)] = true

	# Hide interact label
	var label = chest_nodes[index]["node"].get_node_or_null("InteractLabel")
	if label:
		label.visible = false

func remove_chest_item(index: int) -> void:
	## Removes the item reward from a chest's contents and updates persistence.
	if index >= 0 and index < chest_nodes.size():
		chest_nodes[index]["contents"]["item"] = null
		var key = _chest_key(index)
		if _opened_chests_ref.has(key) and _opened_chests_ref[key] is Dictionary:
			_opened_chests_ref[key]["item_taken"] = true

func remove_chest_card(index: int) -> void:
	## Removes the card reward from a chest's contents and updates persistence.
	if index >= 0 and index < chest_nodes.size():
		chest_nodes[index]["contents"]["card"] = null
		var key = _chest_key(index)
		if _opened_chests_ref.has(key) and _opened_chests_ref[key] is Dictionary:
			_opened_chests_ref[key]["card_taken"] = true

func update_chest_prompts(player_grid: Vector2i) -> void:
	## Show/hide interact labels based on player proximity and fog reveal.
	for i in range(chest_nodes.size()):
		var chest_pos: Vector2i = chest_nodes[i]["grid_pos"]
		var revealed = is_revealed(chest_pos)
		# Hide entire chest node if not revealed
		chest_nodes[i]["node"].visible = revealed
		if chest_nodes[i]["looted"]:
			continue
		var dist = absi(player_grid.x - chest_pos.x) + absi(player_grid.y - chest_pos.y)
		var label = chest_nodes[i]["node"].get_node_or_null("InteractLabel")
		if label:
			if chest_nodes[i]["opened"] and not chest_nodes[i]["looted"]:
				label.text = "[Shift] Loot"
			else:
				label.text = "[Shift] Open"
			label.visible = revealed and dist <= 2

func get_player_start_world() -> Vector3:
	return grid_manager.grid_to_world(player_start)

func clear() -> void:
	if _visuals_root and is_instance_valid(_visuals_root):
		_visuals_root.queue_free()
	_visuals_root = null
	chest_nodes.clear()
	waypoint_nodes.clear()
	site_nodes.clear()
	spawn_zones.clear()
	rooms.clear()
	_reserved.clear()
	_revealed.clear()
	_fog_mm = null
	_fog_initialized = false
	grid.clear()
	elevation.clear()
