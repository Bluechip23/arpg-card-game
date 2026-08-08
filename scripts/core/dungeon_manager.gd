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
# Height of fog-of-war volume tiles. Must exceed the tallest wall so unexplored
# walls stay hidden: max wall = 1.5 + 0.9 noise + 2 elevation * ELEV_STEP = 3.4,
# and the fog box top sits at FOG_HEIGHT - 0.5 (see _fog_shown_xform).
const FOG_HEIGHT: float = 4.2

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
	"ground": Color(0.03, 0.03, 0.04),
	"floor_a": Color(0.18, 0.16, 0.14),   # darker than the sewers — almost lightless
	"floor_b": Color(0.12, 0.11, 0.10),
	"wall_a": Color(0.22, 0.19, 0.17),
	"wall_b": Color(0.13, 0.12, 0.11),
	"cliff": Color(0.19, 0.16, 0.13),
	"step": Color(0.28, 0.25, 0.22),
	"accent": Color(0.30, 0.28, 0.24),
	"ambient": Color(0.18, 0.17, 0.17),
	"sun": Color(0.66, 0.64, 0.62),
	"sun_energy": 0.3,
	"water": Color(0.06, 0.08, 0.10),     # cold cave puddle
	"water_edge": Color(0.12, 0.15, 0.17),
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

# Damp, lightless brickwork. Greens of algae and stagnant water over cold grey
# stone — the first dungeon the player ever descends into (Act 1, the Sewers).
const SEWER_PALETTE := {
	"name": "Sewers",
	"ground": Color(0.04, 0.05, 0.05),
	"floor_a": Color(0.18, 0.20, 0.18),   # wet, mossy brick
	"floor_b": Color(0.12, 0.14, 0.13),
	"wall_a": Color(0.20, 0.22, 0.21),    # slick stone block
	"wall_b": Color(0.12, 0.13, 0.13),
	"cliff": Color(0.15, 0.17, 0.16),
	"step": Color(0.24, 0.26, 0.24),
	"accent": Color(0.20, 0.34, 0.22),    # algae green
	"ambient": Color(0.16, 0.20, 0.19),
	"sun": Color(0.55, 0.62, 0.60),
	"sun_energy": 0.3,
	"water": Color(0.07, 0.14, 0.12),     # murky channel water
	"water_edge": Color(0.13, 0.22, 0.18),
	"torch": Color(1.0, 0.62, 0.28),      # warm bracket flame
}

# Sun-dappled woodland. The bright, open counterpoint to the sewers — a high-
# fantasy forest of trees, trails, hills and hunters' traps (Act 1, Forest).
const FOREST_PALETTE := {
	"name": "Greenwood",
	"ground": Color(0.10, 0.13, 0.07),
	"floor_a": Color(0.26, 0.34, 0.16),   # grassy loam
	"floor_b": Color(0.19, 0.27, 0.12),
	"wall_a": Color(0.30, 0.26, 0.18),    # dense brush / treeline edge
	"wall_b": Color(0.21, 0.19, 0.13),
	"cliff": Color(0.34, 0.27, 0.18),     # earthen hillside
	"step": Color(0.44, 0.40, 0.30),
	"accent": Color(0.24, 0.42, 0.16),    # leafy green
	"ambient": Color(0.46, 0.52, 0.44),
	"sun": Color(1.0, 0.97, 0.84),
	"sun_energy": 1.35,
	"trail": Color(0.34, 0.28, 0.18),     # packed-dirt path
	"bark": Color(0.26, 0.18, 0.11),
	"leaf": Color(0.20, 0.40, 0.16),
	"leaf_b": Color(0.28, 0.48, 0.20),
}

# ============================================
# STATE
# ============================================

var grid: Array = []        # 2D array [x][z] of Tile
var elevation: Array = []   # 2D array [x][z] of int (0 = ground, 1+ = elevated)
var water: Array = []       # 2D bool array [x][z] — true where floor is a water channel
var rooms: Array = []       # [{rect: Rect2i, kind: String, elev: int}]

# Tiles where flavour lights live (sewer torches), so ambience code can tune them
var torch_positions: Array = []  # [Vector2i]

# Forest interactables, consumed by main.gd at setup.
var tree_nodes: Array = []   # climbable trees: [{node, grid_pos, label_node, climbed}]
var trap_defs: Array = []    # hazards: [{kind:"bear"/"dart", tiles:[Vector2i], grid_pos, node, sprung}]
var pit_tiles: Dictionary = {}  # Vector2i -> true: impassable pit hazards

# Per-location fog radius. Sewers reveal less; the open forest reveals more.
var fog_reveal_radius: int = FOG_REVEAL_RADIUS

var chest_nodes: Array = []     # [{node, grid_pos, opened, looted, contents, sprite}]
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
	elif interior_id.begins_with("sewer"):
		interior_kind = "sewer"
	elif interior_id.begins_with("forest"):
		interior_kind = "forest"

	# Fog scales with how lit the place is: tight, lightless sewers reveal least,
	# the bright open forest reveals most, everything else uses the default.
	match interior_kind:
		"sewer":
			fog_reveal_radius = 4
		"forest":
			fog_reveal_radius = 9
		_:
			fog_reveal_radius = FOG_REVEAL_RADIUS

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
	_init_water()
	match interior_kind:
		"cave":
			_generate_cave_layout()
		"building":
			_generate_building_layout()
		"sewer":
			_generate_sewer_layout()
		"forest":
			_generate_forest_layout()
		_:
			_generate_overworld_layout()
	_generate_elevation()

	# Interactables (placed before visuals so decorations avoid their tiles)
	_reserved.clear()
	_reserve_area(player_start, 1)
	if interior_kind == "forest":
		_place_forest_features()  # climbable trees, traps and pits (reserves tiles)
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
	if interior_kind == "sewer":
		# A long descent: wide enough for a winding network, tall enough for
		# branching water channels. The player enters at the far west.
		GRID_W = 56 + world_level * 2
		GRID_H = 34 + world_level
		player_start = Vector2i(3, GRID_H / 2)
		return
	if interior_kind == "forest":
		# A wide, open woodland of clearings and trails — the bright counterpoint
		# to the sewers. The player enters from a trailhead at the west.
		GRID_W = 62 + world_level * 2
		GRID_H = 42 + world_level
		player_start = Vector2i(3, GRID_H / 2)
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
	if interior_kind == "sewer":
		return SEWER_PALETTE
	if interior_kind == "forest":
		return FOREST_PALETTE
	return WORLD_PALETTES.get(world_level, WORLD_PALETTES[1])

## Pixel tile textures per location flavour (grayscale, tinted by the palette).
func floor_texture_path() -> String:
	match interior_kind:
		"sewer", "building":
			return "res://assets/textures/tile_brick.png"
		"cave":
			return "res://assets/textures/tile_dirt.png"
	return "res://assets/textures/tile_grass.png"


func wall_texture_path() -> String:
	match interior_kind:
		"sewer", "building":
			return "res://assets/textures/tile_brick.png"
	return "res://assets/textures/tile_rock.png"


func get_location_name() -> String:
	if interior_kind == "cave":
		return "Cave %d" % (int(interior_id.get_slice("_", 1)) + 1)
	if interior_kind == "building":
		return "Building %d" % (int(interior_id.get_slice("_", 1)) + 1)
	if interior_kind == "sewer":
		return "Sewers"
	if interior_kind == "forest":
		return "Greenwood"
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
	_place_cave_puddles()

func _place_cave_puddles() -> void:
	## Scatter shallow water puddles in low spots — small clusters of floor tiles
	## flagged as water (rendered by _build_floor_visuals).
	var puddle_count = 6 + world_level * 2
	for _i in range(puddle_count):
		var cx = _rng.randi_range(3, GRID_W - 3)
		var cz = _rng.randi_range(3, GRID_H - 3)
		if grid[cx][cz] != Tile.FLOOR:
			continue
		# A puddle is a tight blob of 1–4 adjacent floor tiles.
		water[cx][cz] = true
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			if _rng.randf() < 0.5:
				var p = Vector2i(cx + d.x, cz + d.y)
				if is_floor(p):
					water[p.x][p.y] = true

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
# SEWER INTERIOR LAYOUT
# A main trunk tunnel (with a water channel down its spine) runs west→east.
# Cistern chambers bud off it above and below, joined by short shafts. A central
# cistern is the Rat King's arena; the far-east chamber is the deepest point.
# This reads as a man-made sewer line rather than an organic cave.
# ============================================

func _generate_sewer_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	torch_positions.clear()
	var mid_z = GRID_H / 2

	# --- Main trunk: a 3-wide tunnel the length of the sewer. The centre row is
	# a flowing water channel (still walkable — the player wades the shallows). ---
	for x in range(1, GRID_W - 1):
		for dz in range(-1, 2):
			grid[x][mid_z + dz] = Tile.FLOOR
		water[x][mid_z] = true

	# --- Entry chamber (far west), where the player drops in. ---
	var entry = Rect2i(1, mid_z - 3, 7, 7)
	_carve_rect(entry)
	rooms.append({"rect": entry, "kind": "start", "elev": 0})

	# --- Cistern chambers budding off the trunk, alternating above and below. ---
	var chamber_count = 5 + world_level
	var spacing = maxi(6, (GRID_W - 22) / chamber_count)
	var arena_i = chamber_count / 2  # the middle cistern is the Rat King's lair
	for i in range(chamber_count):
		var cx = 13 + i * spacing
		if cx > GRID_W - 12:
			break
		var above = (i % 2 == 0)
		var is_arena = (i == arena_i)
		var rw = _rng.randi_range(7, 9) if not is_arena else 11
		var rh = _rng.randi_range(5, 6) if not is_arena else 9
		var rx = clampi(cx - rw / 2, 2, GRID_W - rw - 2)
		var rz: int
		if above:
			rz = clampi(mid_z - 3 - rh, 1, GRID_H - rh - 2)
		else:
			rz = clampi(mid_z + 4, 1, GRID_H - rh - 2)
		var rect = Rect2i(rx, rz, rw, rh)
		_carve_rect(rect)
		rooms.append({"rect": rect, "kind": "arena" if is_arena else "chamber", "elev": 0})

		# A 2-wide access shaft from the chamber down/up to the trunk.
		var shaft_x = clampi(rect.get_center().x, rect.position.x + 1, rect.end.x - 2)
		var join_z = rect.end.y - 1 if above else rect.position.y
		_carve_corridor_v(shaft_x, mid_z, join_z)
		_carve_corridor_v(shaft_x + 1, mid_z, join_z)

		# Roughly half the cisterns hold a standing pool fed by a branch channel.
		if _rng.randf() < 0.5:
			var pool = rect.grow(-2)
			if pool.size.x >= 2 and pool.size.y >= 2:
				_flag_water_rect(pool)
				# branch the channel from the trunk up/down the access shaft
				var bz0 = mini(mid_z, join_z)
				var bz1 = maxi(mid_z, join_z)
				for z in range(bz0, bz1 + 1):
					if z >= 0 and z < GRID_H and grid[shaft_x][z] == Tile.FLOOR:
						water[shaft_x][z] = true

	# --- Deepest chamber (far east), just before the exit shaft. ---
	var deep = Rect2i(GRID_W - 9, mid_z - 4, 8, 9)
	deep.position.x = clampi(deep.position.x, 2, GRID_W - deep.size.x - 2)
	_carve_rect(deep)
	rooms.append({"rect": deep, "kind": "deep", "elev": 0})
	_flag_water_rect(Rect2i(deep.position.x + 1, deep.position.y + 1, deep.size.x - 2, 3))

	_enforce_border_walls()
	# Border enforcement may have clipped channel tiles back to wall — clean up.
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR:
				water[x][z] = false

func _flag_water_rect(rect: Rect2i) -> void:
	for x in range(maxi(1, rect.position.x), mini(rect.end.x, GRID_W - 1)):
		for z in range(maxi(1, rect.position.y), mini(rect.end.y, GRID_H - 1)):
			if grid[x][z] == Tile.FLOOR:
				water[x][z] = true

# ============================================
# FOREST INTERIOR LAYOUT
# Open grassy clearings linked by winding dirt trails, with some clearings
# raised into hills (high ground). The bright, sprawling counterpoint to the
# sewers. Trees, traps and pits are layered on afterward (see _place_forest_*).
# ============================================

func _generate_forest_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	tree_nodes.clear()
	trap_defs.clear()
	pit_tiles.clear()
	var mid_z = GRID_H / 2

	# Entry clearing at the trailhead (far west).
	var entry_c = Vector2i(5, mid_z)
	_carve_circle(entry_c, 4)
	rooms.append({"rect": _circle_rect(entry_c, 4), "kind": "start", "elev": 0, "center": entry_c, "radius": 4})

	# Clearings scattered across the woods, joined to the previous one by a trail.
	var clearing_count = 6 + world_level
	var prev = entry_c
	var deepest_x = -1
	var deepest_idx = -1
	for _i in range(clearing_count):
		var c = Vector2i(
			_rng.randi_range(11, GRID_W - 6),
			_rng.randi_range(5, GRID_H - 6)
		)
		var r = _rng.randi_range(3, 6)
		_carve_trail(prev, c)
		_carve_circle(c, r)
		var room = {"rect": _circle_rect(c, r), "kind": "clearing", "elev": 0, "center": c, "radius": r}
		# Roughly a third of clearings rise into a wooded hill (high ground).
		if _rng.randf() < 0.30:
			room["hill"] = true
		rooms.append(room)
		if c.x > deepest_x:
			deepest_x = c.x
			deepest_idx = rooms.size() - 1
		prev = c

	# The far-east clearing is the deepest point — kept flat for a clean fight.
	if deepest_idx >= 0:
		rooms[deepest_idx]["kind"] = "deep"
		rooms[deepest_idx]["hill"] = false

	# A few cross-trails between clearings so paths branch and loop.
	var link_count = 2 + world_level / 2
	for _l in range(link_count):
		var a = _rng.randi_range(1, rooms.size() - 1)
		var b = _rng.randi_range(1, rooms.size() - 1)
		if a != b and rooms[a].has("center") and rooms[b].has("center"):
			_carve_trail(rooms[a]["center"], rooms[b]["center"])

	_smooth_cave_walls()      # round the treeline edges so the woods read organic
	_enforce_border_walls()

func _carve_trail(from: Vector2i, to: Vector2i) -> void:
	## A winding 2-wide dirt trail between two clearings (reuses the cave walk).
	_carve_tunnel(from, to)

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

func _init_water() -> void:
	water.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(false)
		water.append(col)

func is_water(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= GRID_W or grid_pos.y < 0 or grid_pos.y >= GRID_H:
		return false
	if water.is_empty():
		return false
	return water[grid_pos.x][grid_pos.y]

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
	if interior_kind == "sewer":
		return  # Sewers are flat; channels are carved into the floor, not raised
	if interior_kind == "forest":
		# Forest hills: clearings flagged as hills during layout become high ground.
		for room in rooms:
			if room.get("hill", false):
				_set_elevation_rect(room["rect"], 1)
				room["elev"] = 1
		return

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

func build_high_ground(center: Vector2i, radius: int = 1, elev: int = 1) -> void:
	## Sandbox helper: carve a walkable raised platform centred on `center`.
	## FLOOR tiles are given elevation `elev` (so the player glides up onto
	## them and gets the High Ground bonus), and a raised slab + cliff sides are
	## rendered so the platform is visible. WALL tiles are never consumed —
	## walls are a hard cutoff no matter the elevation beside them.
	var pal = get_palette()
	for x in range(center.x - radius, center.x + radius + 1):
		for z in range(center.y - radius, center.y + radius + 1):
			if x < 0 or x >= GRID_W or z < 0 or z >= GRID_H:
				continue
			if grid[x][z] != Tile.FLOOR:
				continue
			elevation[x][z] = elev
			var h: float = elev * ELEV_STEP
			# Cliff body up to just under the top, then a lit top surface.
			var cliff := MeshInstance3D.new()
			var cb := BoxMesh.new()
			cb.size = Vector3(1.0, h, 1.0)
			cliff.mesh = cb
			cliff.position = Vector3(x + 0.5, h / 2.0, z + 0.5)
			var cm := StandardMaterial3D.new()
			cm.albedo_color = pal.get("cliff", Color(0.4, 0.38, 0.34))
			cliff.material_override = cm
			_visuals_root.add_child(cliff)
			var top := MeshInstance3D.new()
			var tb := BoxMesh.new()
			tb.size = Vector3(1.0, 0.08, 1.0)
			top.mesh = tb
			top.position = Vector3(x + 0.5, h - 0.04, z + 0.5)
			var tm := StandardMaterial3D.new()
			tm.albedo_color = pal.get("floor_a", Color(0.5, 0.5, 0.45)).lightened(0.14)
			top.material_override = tm
			_visuals_root.add_child(top)


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

func _add_multimesh(mesh: Mesh, items: Array, shaded: bool = true, rough: float = 0.95, texture_path: String = "") -> void:
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
		var inst_color: Color = items[i]["color"]
		if texture_path != "":
			# Tile textures are authored in full master-palette color now; the
			# instance tint becomes a gentle theme cast instead of the color
			# source, so painted hues survive on screen (16-bit pass).
			inst_color = Color(1, 1, 1).lerp(inst_color, 0.5)
		mm.set_instance_color(i, inst_color)
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = rough
	if not shaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if texture_path != "":
		# Pixel-art dressing: a grayscale tile texture multiplied by the
		# per-instance palette tint. Each texture is a 4x4 sheet of 32px tile
		# variants; world-space triplanar at 1/4 scale maps one variant per
		# world unit with a 4-tile repeat period (kills visible tiling), and
		# nearest filtering keeps the pixels crisp (Mana Seed look).
		mat.albedo_texture = load(texture_path)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mmi.material_override = mat
	_visuals_root.add_child(mmi)


## Billboard sprite props (trees, bushes, rocks, stumps, ferns): a QuadMesh
## MultiMesh with a nearest-filtered billboard material. items entries:
## {pos: Vector3 ground point, scale: float, color: Color theme cast}.
func _add_sprite_decos(items: Array, texture_path: String, px_w: float, px_h: float) -> void:
	if items.is_empty():
		return
	var ps := 0.034  # world units per texel (style guide texel density)
	var quad := QuadMesh.new()
	quad.size = Vector2(px_w * ps, px_h * ps)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = items.size()
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var s: float = it.get("scale", 1.0)
		var pos: Vector3 = it["pos"] + Vector3(0, px_h * ps * 0.5 * s, 0)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), pos))
		mm.set_instance_color(i, Color(1, 1, 1).lerp(it.get("color", Color.WHITE), 0.25))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(texture_path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	_visuals_root.add_child(mmi)


func _build_floor_visuals() -> void:
	## Per-tile ground at elevation 0 with subtle natural color variation.
	## Sewer water channels render as a darker, glossy surface sunk below the brick.
	var pal = get_palette()
	var has_water = pal.has("water")
	var items: Array = []
	var water_items: Array = []
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR or elevation[x][z] > 0:
				continue
			var n = _tile_noise(x, z, 11)
			if has_water and is_water(Vector2i(x, z)):
				# Murky channel water: thin slab sunk slightly into the floor.
				var wcol: Color = pal["water"].lerp(pal["water_edge"], n)
				water_items.append({
					"xform": Transform3D(
						Basis.from_scale(Vector3(1.0, 0.06, 1.0)),
						Vector3(x + 0.5, -0.14, z + 0.5)
					),
					"color": wcol,
				})
				continue
			var col: Color = pal["floor_a"].lerp(pal["floor_b"], n)
			var xform = Transform3D(
				Basis.from_scale(Vector3(1.0, 0.1, 1.0)),
				Vector3(x + 0.5, -0.05, z + 0.5)
			)
			items.append({"xform": xform, "color": col})
	_add_multimesh(BoxMesh.new(), items, true, 0.95, floor_texture_path())
	if not water_items.is_empty():
		# Flat painted 16-bit water: the ripples live in the tile art. No
		# metallic/emission/gloss — modern PBR shine is a style violation.
		_add_multimesh(BoxMesh.new(), water_items, true, 1.0, "res://assets/textures/tile_water.png")
	print("[DUNGEON] Built %d floor tiles, %d water tiles" % [items.size(), water_items.size()])

var _chamfer_mesh_cache: Dictionary = {}

func _chamfered_unit_box(bh: float, ys: float) -> ArrayMesh:
	## Unit box (drop-in for BoxMesh transforms) whose top rim is chamfered so
	## wall and cliff silhouettes read as rounded SNES ledges, not razor edges.
	## bh = horizontal rim inset; ys = unit height where the bevel begins.
	var key := "%f_%f" % [bh, ys]
	if _chamfer_mesh_cache.has(key):
		return _chamfer_mesh_cache[key]
	var i := 0.5 - bh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Quads listed counter-clockwise viewed from outside; emitted flipped to
	# match Godot's clockwise front-face winding.
	var faces := [
		[Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(0.5, ys, 0.5), Vector3(-0.5, ys, 0.5)],
		[Vector3(0.5, -0.5, -0.5), Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, ys, -0.5), Vector3(0.5, ys, -0.5)],
		[Vector3(0.5, -0.5, 0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, ys, -0.5), Vector3(0.5, ys, 0.5)],
		[Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, -0.5, 0.5), Vector3(-0.5, ys, 0.5), Vector3(-0.5, ys, -0.5)],
		[Vector3(-0.5, ys, 0.5), Vector3(0.5, ys, 0.5), Vector3(i, 0.5, i), Vector3(-i, 0.5, i)],
		[Vector3(0.5, ys, -0.5), Vector3(-0.5, ys, -0.5), Vector3(-i, 0.5, -i), Vector3(i, 0.5, -i)],
		[Vector3(0.5, ys, 0.5), Vector3(0.5, ys, -0.5), Vector3(i, 0.5, -i), Vector3(i, 0.5, i)],
		[Vector3(-0.5, ys, -0.5), Vector3(-0.5, ys, 0.5), Vector3(-i, 0.5, i), Vector3(-i, 0.5, -i)],
		[Vector3(-i, 0.5, i), Vector3(i, 0.5, i), Vector3(i, 0.5, -i), Vector3(-i, 0.5, -i)],
		[Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.5, -0.5, 0.5)],
	]
	for f in faces:
		for idx in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(f[idx])
	st.generate_normals()
	var mesh := st.commit()
	_chamfer_mesh_cache[key] = mesh
	return mesh

func _min_adjacent_floor_elevation(x: int, z: int) -> int:
	var min_elev := 99
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var nx = x + dx
			var nz = z + dz
			if nx >= 0 and nx < GRID_W and nz >= 0 and nz < GRID_H:
				if grid[nx][nz] == Tile.FLOOR:
					min_elev = mini(min_elev, elevation[nx][nz])
	return 0 if min_elev == 99 else min_elev

func _build_walls() -> void:
	## Rock walls with varied heights and shades. Walls beside elevated terrain
	## grow taller so high ground stays properly enclosed.
	var pal = get_palette()
	var is_building = interior_kind == "building"
	var items: Array = []
	var skirt_items: Array = []
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
			# Painted contact band where the wall meets the walkable ground.
			var base_y = _min_adjacent_floor_elevation(x, z) * ELEV_STEP
			skirt_items.append({
				"xform": Transform3D(
					Basis.from_scale(Vector3(1.16, 0.045, 1.16)),
					Vector3(x + 0.5, base_y + 0.0225, z + 0.5)
				),
				"color": pal["ground"],
			})
	# Interior building walls stay crisp and man-made; natural rock is rounded.
	var wall_mesh: Mesh = BoxMesh.new() if is_building else _chamfered_unit_box(0.14, 0.42)
	_add_multimesh(wall_mesh, items, true, 0.95, wall_texture_path())
	if not is_building:
		_add_multimesh(BoxMesh.new(), skirt_items, false)
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
	var skirt_items: Array = []
	var dirs4 = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

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
			# Painted contact band at the base of exposed cliff faces.
			var lowest := 99
			for dir in dirs4:
				var nx = x + dir.x
				var nz = z + dir.y
				if nx >= 0 and nx < GRID_W and nz >= 0 and nz < GRID_H:
					if grid[nx][nz] == Tile.FLOOR and elevation[nx][nz] < elevation[x][z]:
						lowest = mini(lowest, elevation[nx][nz])
			if lowest < 99:
				skirt_items.append({
					"xform": Transform3D(
						Basis.from_scale(Vector3(1.16, 0.045, 1.16)),
						Vector3(x + 0.5, lowest * ELEV_STEP + 0.0225, z + 0.5)
					),
					"color": pal["ground"],
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

	# Chamfered rock shoulders under full-width turf caps: the caps overhang
	# the rounded rim slightly, the classic SNES plateau lip.
	_add_multimesh(_chamfered_unit_box(0.08, 0.30), cliff_items, true, 0.95, "res://assets/textures/tile_rock.png")
	_add_multimesh(BoxMesh.new(), top_items, true, 0.95, floor_texture_path())
	_add_multimesh(BoxMesh.new(), step_items, true, 0.85, "res://assets/textures/tile_dirt.png")
	if not skirt_items.is_empty():
		_add_multimesh(BoxMesh.new(), skirt_items, false)
	print("[DUNGEON] Built %d cliff tiles, %d stone steps" % [cliff_items.size(), step_items.size() / 3])

func _build_decorations() -> void:
	## Scatters small non-blocking props for natural variety: rocks and shrubs
	## outdoors, stalagmites in caves, crates inside buildings, and a full kit of
	## sewer dressing (pipes, torches, steam, grates, doors, mice) underground.
	if interior_kind == "sewer":
		_build_sewer_decorations()
		return
	if interior_kind == "forest":
		_build_forest_decorations()
		return
	if interior_kind == "cave":
		_build_cave_decorations()
		return
	var pal = get_palette()
	var rock_items: Array = []
	var bush_items: Array = []
	var cone_items: Array = []
	var _deco_trees: Array = []
	var _deco_rocks: Array = []
	var _deco_bushes: Array = []
	var _deco_ferns: Array = []
	var _deco_flowers: Array = []
	var _deco_spikes: Array = []

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
					# Stalagmite (billboard sprite)
					_deco_spikes.append({
						"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
						"scale": 0.5 + _tile_noise(x, z, 73) * 0.9,
						"color": pal["wall_a"].lerp(pal["wall_b"], n * 3.0),
					})
				elif near_wall and n < 0.2:
					_deco_rocks.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
							"scale": 0.8 + _tile_noise(x, z, 75) * 0.5, "color": pal["wall_a"]})
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
				if near_wall and n < 0.07:
					# Treeline trees hugging the walls (billboard sprites)
					_deco_trees.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
							"scale": 0.85 + _tile_noise(x, z, 73) * 0.5,
							"color": pal.get("leaf", pal["floor_a"])})
				elif near_wall and n < 0.11:
					_deco_rocks.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
							"scale": 0.7 + _tile_noise(x, z, 75) * 0.5, "color": pal["wall_a"]})
				elif n > 0.925:
					_deco_bushes.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
							"scale": 0.8 + _tile_noise(x, z, 83) * 0.5,
							"color": pal["accent"].lerp(pal["floor_a"], 0.5)})
				elif n > 0.885:
					_deco_ferns.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
							"scale": 0.8 + _tile_noise(x, z, 87) * 0.4,
							"color": pal["floor_a"]})
				elif n > 0.84:
					# Flower clumps scattered through the open meadow
					_deco_flowers.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
							"scale": 0.8 + _tile_noise(x, z, 89) * 0.4,
							"color": Color.WHITE})

	_add_multimesh(BoxMesh.new(), rock_items)
	_add_sprite_decos(_deco_trees, "res://assets/textures/props/tree.png", 48, 64)
	_add_sprite_decos(_deco_rocks, "res://assets/textures/props/rock.png", 32, 24)
	_add_sprite_decos(_deco_bushes, "res://assets/textures/props/bush.png", 32, 24)
	_add_sprite_decos(_deco_ferns, "res://assets/textures/props/fern.png", 24, 24)
	_add_sprite_decos(_deco_flowers, "res://assets/textures/props/flowers.png", 20, 14)
	_add_sprite_decos(_deco_spikes, "res://assets/textures/props/stalagmite.png", 16, 24)
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
	print("[DUNGEON] Placed %d mesh decos + %d trees, %d rocks, %d bushes, %d ferns, %d flowers" % [
		rock_items.size() + bush_items.size() + cone_items.size(),
		_deco_trees.size(), _deco_rocks.size(), _deco_bushes.size(),
		_deco_ferns.size(), _deco_flowers.size()])

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
# SEWER DRESSING
# Wall torches (real flickering lights), pipes that pour water, rising steam,
# floor grates over the channel, circular sliding doors at the cistern mouths,
# manholes, scuttling mice and damp rubble. All cosmetic and non-blocking.
# ============================================

func _build_sewer_decorations() -> void:
	var pal = get_palette()

	# Catalogue the candidate sites once.
	var wall_edges: Array = []   # [{pos: Vector2i, dir: Vector2i (wall→floor)}]
	var floor_tiles: Array = []  # dry, unreserved floor
	var water_tiles: Array = []  # channel/pool floor
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			var pos = Vector2i(x, z)
			if grid[x][z] == Tile.WALL:
				var fdir = _adjacent_floor_dir(x, z)
				if fdir != Vector2i.ZERO:
					wall_edges.append({"pos": pos, "dir": fdir})
			elif grid[x][z] == Tile.FLOOR:
				if is_water(pos):
					water_tiles.append(pos)
				elif not _reserved.has(pos):
					floor_tiles.append(pos)

	_place_sewer_torches(wall_edges, pal)
	_place_sewer_pipes(wall_edges, pal)
	_place_sewer_steam(water_tiles, pal)
	_place_sewer_grates(water_tiles, pal)
	_place_sewer_doors(pal)
	_place_sewer_manholes(pal)
	_place_sewer_rubble(wall_edges, pal)
	_place_sewer_mice(floor_tiles)

	print("[DUNGEON] Sewer dressing: %d torches, %d candidate walls, %d water tiles" % [
		torch_positions.size(), wall_edges.size(), water_tiles.size()])

func _adjacent_floor_dir(x: int, z: int) -> Vector2i:
	## For a wall tile, the cardinal direction toward an adjacent floor (or ZERO).
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx = x + dir.x
		var nz = z + dir.y
		if nx >= 0 and nx < GRID_W and nz >= 0 and nz < GRID_H and grid[nx][nz] == Tile.FLOOR:
			return dir
	return Vector2i.ZERO

func _spaced_sample(candidates: Array, want: int, min_gap: int) -> Array:
	## Deterministically pick up to `want` entries keeping a minimum tile gap.
	## Each entry must expose a "pos" Vector2i.
	var chosen: Array = []
	var taken: Array = []
	var pool := candidates.duplicate()
	# Fisher–Yates with the seeded RNG so picks are deterministic per layout.
	for i in range(pool.size() - 1, 0, -1):
		var j = _rng.randi_range(0, i)
		var tmp = pool[i]; pool[i] = pool[j]; pool[j] = tmp
	for entry in pool:
		if chosen.size() >= want:
			break
		var p: Vector2i = entry["pos"]
		var ok = true
		for t in taken:
			if absi(t.x - p.x) + absi(t.y - p.y) < min_gap:
				ok = false
				break
		if ok:
			chosen.append(entry)
			taken.append(p)
	return chosen

func _place_sewer_torches(wall_edges: Array, pal: Dictionary) -> void:
	## Wrought brackets with a live flame and a real (flickering) point light.
	var want = clampi(wall_edges.size() / 13, 8, 26)
	var picks = _spaced_sample(wall_edges, want, 5)
	var flame_col: Color = pal.get("torch", Color(1.0, 0.62, 0.28))
	for entry in picks:
		var pos: Vector2i = entry["pos"]
		var dir: Vector2i = entry["dir"]
		torch_positions.append(pos)
		var root = Node3D.new()
		root.name = "Torch"
		var base = Vector3(pos.x + 0.5, 0, pos.y + 0.5)
		var into = Vector3(dir.x, 0, dir.y) * 0.45  # nudge out of the wall into the room
		root.position = base + into + Vector3(0, 1.25, 0)
		_visuals_root.add_child(root)

		# Iron bracket arm.
		var bracket = MeshInstance3D.new()
		var arm = CylinderMesh.new()
		arm.top_radius = 0.03
		arm.bottom_radius = 0.04
		arm.height = 0.42
		arm.radial_segments = 5
		bracket.mesh = arm
		bracket.rotation_degrees = Vector3(0, 0, 90)
		var iron = StandardMaterial3D.new()
		iron.albedo_color = Color(0.10, 0.10, 0.11)
		iron.metallic = 0.0  # no modern specular pop
		iron.roughness = 0.6
		bracket.material_override = iron
		bracket.position = -into * 0.5
		root.add_child(bracket)

		# Flame: an emissive teardrop that always glows.
		var flame = MeshInstance3D.new()
		var fmesh = SphereMesh.new()
		fmesh.radius = 0.1
		fmesh.height = 0.28
		fmesh.radial_segments = 7
		fmesh.rings = 5
		flame.mesh = fmesh
		flame.position = Vector3(0, 0.18, 0)
		var fmat = StandardMaterial3D.new()
		fmat.albedo_color = flame_col
		fmat.emission_enabled = true
		fmat.emission = flame_col
		fmat.emission_energy_multiplier = 3.0
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame.material_override = fmat
		root.add_child(flame)

		# Real flickering light.
		var light = TorchFlicker.new()
		light.light_color = flame_col
		light.light_energy = 2.4
		light.omni_range = 7.5
		light.omni_attenuation = 2.0  # tighter falloff, less modern gradient
		light.shadow_enabled = false
		light.position = Vector3(0, 0.2, 0)
		root.add_child(light)

func _place_sewer_pipes(wall_edges: Array, pal: Dictionary) -> void:
	## Wall pipes that jut into the room and pour a thin stream of water.
	var want = clampi(wall_edges.size() / 22, 4, 12)
	# Bias toward walls that overlook water so the pour lands in the channel.
	var over_water: Array = []
	for entry in wall_edges:
		var p: Vector2i = entry["pos"]
		var d: Vector2i = entry["dir"]
		if is_water(p + d):
			over_water.append(entry)
	var pool := over_water if over_water.size() >= want else wall_edges
	var picks = _spaced_sample(pool, want, 6)
	for entry in picks:
		var pos: Vector2i = entry["pos"]
		var dir: Vector2i = entry["dir"]
		var into = Vector3(dir.x, 0, dir.y)
		var root = Node3D.new()
		root.name = "SewerPipe"
		root.position = Vector3(pos.x + 0.5, 1.0, pos.y + 0.5) + into * 0.35
		_visuals_root.add_child(root)

		# The pipe: a stout cylinder protruding from the wall, elbowing down.
		var pipe = MeshInstance3D.new()
		var pmesh = CylinderMesh.new()
		pmesh.top_radius = 0.13
		pmesh.bottom_radius = 0.13
		pmesh.height = 0.55
		pmesh.radial_segments = 8
		pipe.mesh = pmesh
		# Lay the cylinder along the into-direction (it points out of the wall).
		if dir.x != 0:
			pipe.rotation_degrees = Vector3(0, 0, 90)
		else:
			pipe.rotation_degrees = Vector3(90, 0, 0)
		var metal = StandardMaterial3D.new()
		metal.albedo_color = Color(0.18, 0.20, 0.19)
		metal.metallic = 0.0  # no modern specular pop
		metal.roughness = 0.7
		pipe.material_override = metal
		root.add_child(pipe)

		# A rusty rim at the mouth.
		var rim = MeshInstance3D.new()
		var rmesh = TorusMesh.new()
		rmesh.inner_radius = 0.10
		rmesh.outer_radius = 0.16
		rim.mesh = rmesh
		if dir.x != 0:
			rim.rotation_degrees = Vector3(0, 0, 90)
		else:
			rim.rotation_degrees = Vector3(90, 0, 0)
		var rust = StandardMaterial3D.new()
		rust.albedo_color = Color(0.28, 0.18, 0.10)
		rust.roughness = 0.9
		rim.material_override = rust
		rim.position = into * 0.28
		root.add_child(rim)

		# Falling water: a thin particle stream from the mouth to the floor.
		var stream = _make_water_stream()
		stream.position = into * 0.28
		root.add_child(stream)

		# Faint splash where it lands.
		var splash = MeshInstance3D.new()
		var smesh = CylinderMesh.new()
		smesh.top_radius = 0.22
		smesh.bottom_radius = 0.22
		smesh.height = 0.02
		smesh.radial_segments = 10
		splash.mesh = smesh
		var smat = StandardMaterial3D.new()
		smat.albedo_color = pal.get("water_edge", Color(0.13, 0.22, 0.18)).lightened(0.1)
		smat.emission_enabled = true
		smat.emission = smat.albedo_color
		smat.emission_energy_multiplier = 0.3
		splash.material_override = smat
		splash.position = into * 0.28 + Vector3(0, -1.0, 0)
		root.add_child(splash)

func _make_pixel_anim(strip_path: String, frame_w: int, frame_h: int, fps: float) -> AnimatedSprite3D:
	## Looping frame-strip billboard: the 16-bit stand-in for GPU particles.
	var tex: Texture2D = load(strip_path)
	var frames = SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	var count := int(tex.get_width() / frame_w)
	for i in range(count):
		var at = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame("default", at)
	var spr = AnimatedSprite3D.new()
	spr.sprite_frames = frames
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false
	spr.pixel_size = 0.034
	spr.play("default")
	return spr

func _make_water_stream() -> Node3D:
	## Frame-animated pixel dribble replacing the GPU droplet spray.
	return _make_pixel_anim("res://assets/textures/props/drip_strip.png", 8, 16, 6.0)

func _place_sewer_steam(water_tiles: Array, pal: Dictionary) -> void:
	## Slow columns of warm steam rising off the water.
	if water_tiles.is_empty():
		return
	var entries: Array = []
	for p in water_tiles:
		entries.append({"pos": p})
	var want = clampi(water_tiles.size() / 18, 4, 14)
	var picks = _spaced_sample(entries, want, 4)
	for entry in picks:
		var pos: Vector2i = entry["pos"]
		var steam = _make_steam()
		steam.position = Vector3(pos.x + 0.5, 0.05, pos.y + 0.5)
		_visuals_root.add_child(steam)

func _make_steam() -> Node3D:
	## Frame-animated pixel wisp replacing the additive particle cloud.
	var spr = _make_pixel_anim("res://assets/textures/props/steam_strip.png", 16, 24, 3.0)
	spr.modulate = Color(1, 1, 1, 0.55)
	spr.position.y = 0.45
	return spr

func _place_sewer_grates(water_tiles: Array, pal: Dictionary) -> void:
	## Iron grates set over a few stretches of the channel.
	if water_tiles.is_empty():
		return
	var entries: Array = []
	for p in water_tiles:
		entries.append({"pos": p})
	var want = clampi(water_tiles.size() / 14, 3, 10)
	var picks = _spaced_sample(entries, want, 3)
	var bar_mat = StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.13, 0.13, 0.14)
	bar_mat.metallic = 0.0  # no modern specular pop
	bar_mat.roughness = 0.6
	for entry in picks:
		var pos: Vector2i = entry["pos"]
		var root = Node3D.new()
		root.name = "Grate"
		root.position = Vector3(pos.x + 0.5, -0.08, pos.y + 0.5)
		_visuals_root.add_child(root)
		# A frame plus four bars across.
		for i in range(4):
			var bar = MeshInstance3D.new()
			var bmesh = BoxMesh.new()
			bmesh.size = Vector3(0.9, 0.05, 0.08)
			bar.mesh = bmesh
			bar.material_override = bar_mat
			bar.position = Vector3(0, 0, -0.33 + i * 0.22)
			root.add_child(bar)

func _place_sewer_doors(pal: Dictionary) -> void:
	## Big circular stone valve-doors recessed into the wall at a few cistern
	## mouths — the rolled-aside discs that seal passages in the sewer.
	var placed = 0
	for room in rooms:
		if placed >= 5:
			break
		if room["kind"] not in ["chamber", "arena", "deep"]:
			continue
		if _rng.randf() > 0.6:
			continue
		var rect: Rect2i = room["rect"]
		# Find a wall tile on the room's perimeter to host the disc.
		var host = _find_perimeter_wall(rect)
		if host["pos"] == Vector2i(-1, -1):
			continue
		var pos: Vector2i = host["pos"]
		var dir: Vector2i = host["dir"]
		var into = Vector3(dir.x, 0, dir.y)
		var root = Node3D.new()
		root.name = "SlidingDoor"
		root.position = Vector3(pos.x + 0.5, 0.85, pos.y + 0.5) + into * 0.1
		_visuals_root.add_child(root)

		var disc = MeshInstance3D.new()
		var dmesh = CylinderMesh.new()
		dmesh.top_radius = 0.85
		dmesh.bottom_radius = 0.85
		dmesh.height = 0.22
		dmesh.radial_segments = 20
		disc.mesh = dmesh
		# Stand the disc upright, facing into the room.
		if dir.x != 0:
			disc.rotation_degrees = Vector3(0, 0, 90)
		else:
			disc.rotation_degrees = Vector3(90, 0, 0)
		var stone = StandardMaterial3D.new()
		stone.albedo_color = pal["wall_a"].lightened(0.05)
		stone.roughness = 0.95
		disc.material_override = stone
		root.add_child(disc)

		# Concentric hub ring so it reads as a valve/door, not a plain cylinder.
		var hub = MeshInstance3D.new()
		var hmesh = TorusMesh.new()
		hmesh.inner_radius = 0.28
		hmesh.outer_radius = 0.42
		hub.mesh = hmesh
		if dir.x != 0:
			hub.rotation_degrees = Vector3(0, 0, 90)
		else:
			hub.rotation_degrees = Vector3(90, 0, 0)
		var iron = StandardMaterial3D.new()
		iron.albedo_color = Color(0.16, 0.16, 0.17)
		iron.metallic = 0.0  # no modern specular pop
		iron.roughness = 0.7
		hub.material_override = iron
		hub.position = into * 0.13
		root.add_child(hub)
		placed += 1

func _find_perimeter_wall(rect: Rect2i) -> Dictionary:
	## A wall tile just outside the rect that borders the room (with facing dir).
	var tries = [
		{"pos": Vector2i(rect.get_center().x, rect.position.y - 1), "dir": Vector2i(0, 1)},
		{"pos": Vector2i(rect.get_center().x, rect.end.y), "dir": Vector2i(0, -1)},
		{"pos": Vector2i(rect.position.x - 1, rect.get_center().y), "dir": Vector2i(1, 0)},
		{"pos": Vector2i(rect.end.x, rect.get_center().y), "dir": Vector2i(-1, 0)},
	]
	for t in tries:
		var p: Vector2i = t["pos"]
		if p.x <= 0 or p.x >= GRID_W - 1 or p.y <= 0 or p.y >= GRID_H - 1:
			continue
		if grid[p.x][p.y] == Tile.WALL and grid[p.x + t["dir"].x][p.y + t["dir"].y] == Tile.FLOOR:
			return t
	return {"pos": Vector2i(-1, -1), "dir": Vector2i.ZERO}

func _place_sewer_manholes(pal: Dictionary) -> void:
	## Heavy round covers set flush in the chamber floors — flavour shafts to the
	## streets above. Non-interactive; the real exit is the portal site.
	for room in rooms:
		if room["kind"] not in ["chamber", "deep"]:
			continue
		if _rng.randf() > 0.4:
			continue
		var rect: Rect2i = room["rect"]
		var cell = Vector2i(rect.get_center().x, rect.get_center().y)
		if not is_floor(cell) or _reserved.has(cell) or is_water(cell):
			continue
		var cover = MeshInstance3D.new()
		cover.name = "Manhole"
		var cmesh = CylinderMesh.new()
		cmesh.top_radius = 0.42
		cmesh.bottom_radius = 0.42
		cmesh.height = 0.04
		cmesh.radial_segments = 18
		cover.mesh = cmesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.14, 0.15, 0.15)
		mat.metallic = 0.0  # no modern specular pop
		mat.roughness = 0.8
		cover.material_override = mat
		cover.position = Vector3(cell.x + 0.5, 0.02, cell.y + 0.5)
		_visuals_root.add_child(cover)

func _place_sewer_rubble(wall_edges: Array, pal: Dictionary) -> void:
	## Damp rubble and algae patches hugging the walls, as a MultiMesh.
	var rubble: Array = []
	var moss: Array = []
	for entry in wall_edges:
		var pos: Vector2i = entry["pos"]
		var dir: Vector2i = entry["dir"]
		var floor_pos = pos + dir
		if not is_floor(floor_pos) or _reserved.has(floor_pos):
			continue
		var n = _tile_noise(pos.x, pos.y, 53)
		var into = Vector3(dir.x, 0, dir.y)
		var center = Vector3(floor_pos.x + 0.5, 0, floor_pos.y + 0.5) - into * 0.3
		var rot = Basis(Vector3.UP, _tile_noise(pos.x, pos.y, 71) * TAU)
		if n < 0.16:
			var s = 0.12 + _tile_noise(pos.x, pos.y, 91) * 0.2
			rubble.append({
				"xform": Transform3D(rot * Basis.from_scale(Vector3(s * 1.4, s, s * 1.2)),
					center + Vector3(0, s * 0.5, 0)),
				"color": pal["wall_b"].lerp(pal["floor_b"], n * 3.0),
			})
		elif n > 0.86:
			# Flat algae smear on the floor at the wall foot.
			moss.append({
				"xform": Transform3D(rot * Basis.from_scale(Vector3(0.5, 0.02, 0.5)),
					center + Vector3(0, 0.01, 0)),
				"color": pal["accent"].lerp(pal["floor_a"], _tile_noise(pos.x, pos.y, 89) * 0.5),
			})
	_add_multimesh(BoxMesh.new(), rubble)
	if not moss.is_empty():
		_add_multimesh(BoxMesh.new(), moss)

func _place_sewer_mice(floor_tiles: Array) -> void:
	## A handful of background sewer mice scuttling near the walls.
	if floor_tiles.size() < 8:
		return
	var entries: Array = []
	for p in floor_tiles:
		entries.append({"pos": p})
	var want = clampi(floor_tiles.size() / 60, 4, 9)
	var picks = _spaced_sample(entries, want, 6)
	for i in range(picks.size()):
		var pos: Vector2i = picks[i]["pos"]
		var mouse = SewerCritter.new()
		mouse.name = "Mouse_%d" % i
		_visuals_root.add_child(mouse)
		mouse.setup(Vector3(pos.x + 0.5, 0.0, pos.y + 0.5), _layout_seed + i * 131)

# ============================================
# FOREST FEATURES — climbable trees, hunter traps, bear traps and pits.
# These are gameplay objects (reserved tiles, queried by main.gd), placed during
# the interactables phase so chests/enemies avoid them.
# ============================================

func _place_forest_features() -> void:
	# Gather candidate floor cells, split into clearing interiors and trail tiles.
	var clearing_cells: Array = []
	var trail_cells: Array = []
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			var pos = Vector2i(x, z)
			if grid[x][z] != Tile.FLOOR or _reserved.has(pos):
				continue
			if _in_a_clearing(pos):
				clearing_cells.append({"pos": pos})
			else:
				trail_cells.append({"pos": pos})

	_place_forest_pits(clearing_cells)
	_place_climbable_trees(clearing_cells)
	_place_bear_traps(clearing_cells + trail_cells)
	_place_dart_traps(trail_cells)

	print("[DUNGEON] Forest features: %d trees, %d traps, %d pits" % [
		tree_nodes.size(), trap_defs.size(), pit_tiles.size()])

func _in_a_clearing(pos: Vector2i) -> bool:
	for room in rooms:
		if not room.has("center"):
			continue
		var c: Vector2i = room["center"]
		var r: int = room.get("radius", 3)
		if (pos - c).length_squared() <= (r - 1) * (r - 1):
			return true
	return false

func _place_forest_pits(clearing_cells: Array) -> void:
	## A few impassable holes in the clearings (blocked + reserved so nothing
	## spawns on them; main.gd treats them as obstacles).
	if clearing_cells.size() < 6:
		return
	var want = clampi(clearing_cells.size() / 70, 2, 6)
	var picks = _spaced_sample(clearing_cells, want, 6)
	for entry in picks:
		var pos: Vector2i = entry["pos"]
		if pos == player_start:
			continue
		pit_tiles[pos] = true
		_reserved[pos] = true
		# Recessed dark hole with a raised earthen rim.
		var hole = MeshInstance3D.new()
		hole.name = "Pit"
		var hmesh = BoxMesh.new()
		hmesh.size = Vector3(0.94, 0.5, 0.94)
		hole.mesh = hmesh
		var hmat = StandardMaterial3D.new()
		hmat.albedo_color = Color(0.03, 0.03, 0.03)
		hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hole.material_override = hmat
		hole.position = Vector3(pos.x + 0.5, -0.28, pos.y + 0.5)
		_visuals_root.add_child(hole)

func _place_climbable_trees(clearing_cells: Array) -> void:
	## Sturdy trees with a distinct low branch the player can climb (Shift) for
	## high ground. Each occupies a reserved, blocked tile.
	if clearing_cells.is_empty():
		return
	var want = clampi(clearing_cells.size() / 55, 2, 6)
	var picks = _spaced_sample(clearing_cells, want, 7)
	for i in range(picks.size()):
		var pos: Vector2i = picks[i]["pos"]
		if pos == player_start or _reserved.has(pos):
			continue
		_reserved[pos] = true
		var root = Node3D.new()
		root.name = "ClimbTree_%d" % i
		root.position = Vector3(pos.x + 0.5, 0, pos.y + 0.5)
		_build_tree_mesh(root, 1.0, true)

		var label = Label3D.new()
		label.name = "InteractLabel"
		label.text = "[Shift] Climb"
		WorldText.crisp(label)
		label.font_size = 16
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.7, 1.0, 0.5)
		label.position = Vector3(0, 1.5, 0)
		label.visible = false
		root.add_child(label)
		_visuals_root.add_child(root)

		tree_nodes.append({
			"node": root,
			"grid_pos": pos,
			"label_node": label,
			"climbed": false,
		})

func _build_tree_mesh(root: Node3D, scale: float, climbable: bool) -> void:
	## Shared tree visual: trunk + canopy, and (for climbable trees) a distinct
	## low branch that signals it can be climbed.
	var pal = get_palette()
	var bark = StandardMaterial3D.new()
	bark.albedo_color = pal.get("bark", Color(0.26, 0.18, 0.11))
	bark.roughness = 1.0
	var leaf = StandardMaterial3D.new()
	leaf.albedo_color = pal.get("leaf", Color(0.20, 0.40, 0.16))
	leaf.roughness = 1.0

	var trunk = MeshInstance3D.new()
	var tmesh = CylinderMesh.new()
	tmesh.top_radius = 0.16 * scale
	tmesh.bottom_radius = 0.24 * scale
	tmesh.height = 2.6 * scale
	tmesh.radial_segments = 8
	trunk.mesh = tmesh
	trunk.material_override = bark
	trunk.position = Vector3(0, 1.3 * scale, 0)
	root.add_child(trunk)

	# Canopy: a couple of overlapping leaf clusters.
	for off in [Vector3(0, 2.9, 0), Vector3(0.35, 2.6, 0.2), Vector3(-0.3, 2.7, -0.25)]:
		var canopy = MeshInstance3D.new()
		var cmesh = SphereMesh.new()
		cmesh.radius = 0.7 * scale
		cmesh.height = 1.3 * scale
		cmesh.radial_segments = 8
		cmesh.rings = 5
		canopy.mesh = cmesh
		canopy.material_override = leaf
		canopy.position = off * scale
		root.add_child(canopy)

	if climbable:
		# A distinct, near-horizontal low branch — the climbing handhold.
		var branch = MeshInstance3D.new()
		var bmesh = CylinderMesh.new()
		bmesh.top_radius = 0.06
		bmesh.bottom_radius = 0.10
		bmesh.height = 0.9
		bmesh.radial_segments = 6
		branch.mesh = bmesh
		branch.rotation_degrees = Vector3(0, 0, 68)  # juts out and slightly up
		branch.material_override = bark
		branch.position = Vector3(0.45, 1.05, 0)
		root.add_child(branch)
		# A small leaf tuft on the branch tip so it reads as the obvious foothold.
		var tuft = MeshInstance3D.new()
		var tmesh2 = SphereMesh.new()
		tmesh2.radius = 0.22
		tmesh2.height = 0.4
		tmesh2.radial_segments = 6
		tmesh2.rings = 4
		tuft.mesh = tmesh2
		var bright = StandardMaterial3D.new()
		bright.albedo_color = pal.get("leaf_b", Color(0.28, 0.48, 0.20))
		bright.roughness = 1.0
		tuft.material_override = bright
		tuft.position = Vector3(0.78, 1.2, 0)
		root.add_child(tuft)

func _place_bear_traps(cells: Array) -> void:
	## Iron jaw traps on the ground — 7 damage to anything that steps on them
	## (10 to bears). Single use; main.gd springs and disarms them.
	if cells.is_empty():
		return
	var want = clampi(cells.size() / 45, 3, 9)
	var picks = _spaced_sample(cells, want, 5)
	for i in range(picks.size()):
		var pos: Vector2i = picks[i]["pos"]
		if _reserved.has(pos) or pit_tiles.has(pos):
			continue
		_reserved[pos] = true
		var root = Node3D.new()
		root.name = "BearTrap_%d" % i
		root.position = Vector3(pos.x + 0.5, 0.02, pos.y + 0.5)
		_visuals_root.add_child(root)
		_build_bear_trap_mesh(root)
		trap_defs.append({
			"kind": "bear",
			"tiles": [pos],
			"grid_pos": pos,
			"node": root,
			"sprung": false,
		})

func _build_bear_trap_mesh(root: Node3D) -> void:
	var iron = StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.16, 0.17)
	iron.metallic = 0.0  # no modern specular pop
	iron.roughness = 0.5
	# Base ring.
	var ring = MeshInstance3D.new()
	var rmesh = TorusMesh.new()
	rmesh.inner_radius = 0.20
	rmesh.outer_radius = 0.34
	ring.mesh = rmesh
	ring.material_override = iron
	root.add_child(ring)
	# Jaw teeth around the rim.
	for k in range(8):
		var a = TAU * k / 8.0
		var tooth = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.05
		cone.height = 0.22
		cone.radial_segments = 4
		tooth.mesh = cone
		tooth.material_override = iron
		tooth.position = Vector3(cos(a) * 0.27, 0.11, sin(a) * 0.27)
		tooth.rotation_degrees = Vector3(rad_to_deg(a) * 0.0, 0, 0)
		root.add_child(tooth)
	# Pressure plate.
	var plate = MeshInstance3D.new()
	var pmesh = CylinderMesh.new()
	pmesh.top_radius = 0.16
	pmesh.bottom_radius = 0.16
	pmesh.height = 0.03
	plate.mesh = pmesh
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.22, 0.20, 0.16)
	plate.material_override = pmat
	plate.position = Vector3(0, 0.02, 0)
	root.add_child(plate)

func _place_dart_traps(trail_cells: Array) -> void:
	## Hunters' tripwire traps: a wire strung across a trail; crossing it fires
	## darts from a tube mounted on a nearby tree. main.gd handles the volley.
	if trail_cells.size() < 6:
		return
	var want = clampi(trail_cells.size() / 60, 2, 6)
	var picks = _spaced_sample(trail_cells, want, 8)
	for i in range(picks.size()):
		var pos: Vector2i = picks[i]["pos"]
		if _reserved.has(pos):
			continue
		# The tripwire spans this tile and its two cross-trail neighbours.
		var perp = _trail_perp(pos)
		var line: Array = [pos]
		for s in [-1, 1]:
			var t = pos + perp * s
			if is_floor(t) and not _reserved.has(t):
				line.append(t)
		for t in line:
			_reserved[t] = true

		var root = Node3D.new()
		root.name = "DartTrap_%d" % i
		_visuals_root.add_child(root)
		_build_dart_trap_mesh(root, pos, perp)
		trap_defs.append({
			"kind": "dart",
			"tiles": line,
			"grid_pos": pos,
			"node": root,
			"sprung": false,
		})

func _trail_perp(pos: Vector2i) -> Vector2i:
	## A direction across the trail at pos (perpendicular to where the floor runs).
	# If floor continues east/west, the wire runs north/south, and vice-versa.
	var horizontal = is_floor(pos + Vector2i(1, 0)) or is_floor(pos + Vector2i(-1, 0))
	return Vector2i(0, 1) if horizontal else Vector2i(1, 0)

func _build_dart_trap_mesh(root: Node3D, pos: Vector2i, perp: Vector2i) -> void:
	var pal = get_palette()
	# The tripwire: a thin dark line just above the ground spanning the trail.
	var wire = MeshInstance3D.new()
	var wmesh = BoxMesh.new()
	wmesh.size = Vector3(0.04 + abs(perp.x) * 2.6, 0.03, 0.04 + abs(perp.y) * 2.6)
	wire.mesh = wmesh
	var wmat = StandardMaterial3D.new()
	wmat.albedo_color = Color(0.12, 0.10, 0.07)
	wire.material_override = wmat
	wire.position = Vector3(pos.x + 0.5, 0.12, pos.y + 0.5)
	root.add_child(wire)

	# A dart tube mounted on a post at the trail's edge, aimed across the wire.
	var post_pos = Vector3(pos.x + 0.5 - perp.x * 1.6, 0, pos.y + 0.5 - perp.y * 1.6)
	var tube = MeshInstance3D.new()
	var tmesh = CylinderMesh.new()
	tmesh.top_radius = 0.07
	tmesh.bottom_radius = 0.07
	tmesh.height = 0.5
	tmesh.radial_segments = 6
	tube.mesh = tmesh
	# Lay the tube along the firing direction (toward the wire).
	if perp.x != 0:
		tube.rotation_degrees = Vector3(0, 0, 90)
	else:
		tube.rotation_degrees = Vector3(90, 0, 0)
	var tmat = StandardMaterial3D.new()
	tmat.albedo_color = pal.get("bark", Color(0.26, 0.18, 0.11)).darkened(0.2)
	tmat.metallic = 0.0  # no modern specular pop
	tube.material_override = tmat
	tube.position = post_pos + Vector3(0, 0.9, 0)
	root.add_child(tube)

# ============================================
# FOREST DECORATIONS — background trees, stumps, bushes, ferns and squirrels.
# Pure visuals, placed in the decoration pass (avoids reserved feature tiles).
# ============================================

func _build_forest_decorations() -> void:
	var pal = get_palette()
	var trunk_items: Array = []
	var canopy_items: Array = []
	var stump_items: Array = []
	var bush_items: Array = []
	var floor_cells: Array = []

	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			var pos = Vector2i(x, z)
			if grid[x][z] != Tile.FLOOR:
				continue
			if not _reserved.has(pos):
				floor_cells.append(pos)
			var near_wall = not _has_adjacent_floor_on_all_sides(x, z)
			if _reserved.has(pos):
				continue
			var n = _tile_noise(x, z, 53)
			var jx = (_tile_noise(x, z, 61) - 0.5) * 0.4
			var jz = (_tile_noise(x, z, 67) - 0.5) * 0.4
			var y_base = elevation[x][z] * ELEV_STEP
			var rot = Basis(Vector3.UP, _tile_noise(x, z, 71) * TAU)
			if near_wall and n < 0.30:
				# Treeline tree (billboard sprite).
				trunk_items.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
						"scale": 0.8 + _tile_noise(x, z, 73) * 0.7,
						"color": pal["leaf"].lerp(pal["leaf_b"], _tile_noise(x, z, 79))})
			elif near_wall and n < 0.40:
				# Mossy stump (billboard sprite).
				stump_items.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
						"scale": 0.7 + _tile_noise(x, z, 81) * 0.4,
						"color": pal["bark"].lerp(pal["accent"], 0.3)})
			elif n > 0.93:
				bush_items.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
						"scale": 0.7 + _tile_noise(x, z, 83) * 0.6,
						"color": pal["accent"].lerp(pal["leaf"], _tile_noise(x, z, 89))})
			elif n > 0.88:
				canopy_items.append({"pos": Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz),
						"scale": 0.75 + _tile_noise(x, z, 91) * 0.4,
						"color": pal["leaf"]})

	_add_sprite_decos(trunk_items, "res://assets/textures/props/tree.png", 48, 64)
	_add_sprite_decos(canopy_items, "res://assets/textures/props/fern.png", 24, 24)
	_add_sprite_decos(stump_items, "res://assets/textures/props/stump.png", 24, 20)
	_add_sprite_decos(bush_items, "res://assets/textures/props/bush.png", 32, 24)

	_place_forest_squirrels(floor_cells)
	print("[DUNGEON] Forest dressing: %d trees, %d stumps, %d bushes" % [
		trunk_items.size(), stump_items.size(), bush_items.size()])

func _cylinder_mesh(top_r: float, bot_r: float, h: float) -> CylinderMesh:
	var m = CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = h
	m.radial_segments = 8
	return m

func _place_forest_squirrels(floor_cells: Array) -> void:
	## Background squirrels darting about the clearings. Cosmetic only.
	if floor_cells.size() < 10:
		return
	var entries: Array = []
	for p in floor_cells:
		entries.append({"pos": p})
	var want = clampi(floor_cells.size() / 70, 4, 10)
	var picks = _spaced_sample(entries, want, 7)
	for i in range(picks.size()):
		var pos: Vector2i = picks[i]["pos"]
		var sq = SewerCritter.new()
		sq.name = "Squirrel_%d" % i
		_visuals_root.add_child(sq)
		sq.setup(Vector3(pos.x + 0.5, 0.0, pos.y + 0.5), _layout_seed + i * 197, "squirrel")

# ============================================
# FOREST QUERIES (for main.gd: climbing, traps, blocked tiles)
# ============================================

func get_nearby_climbable_tree(player_grid: Vector2i) -> int:
	## Index of a climbable tree within 1 tile of the player, or -1.
	for i in range(tree_nodes.size()):
		var tp: Vector2i = tree_nodes[i]["grid_pos"]
		if absi(player_grid.x - tp.x) + absi(player_grid.y - tp.y) <= 1:
			return i
	return -1

func update_tree_prompts(player_grid: Vector2i) -> void:
	for tree in tree_nodes:
		var tp: Vector2i = tree["grid_pos"]
		var revealed = is_revealed(tp)
		if tree["node"] and is_instance_valid(tree["node"]):
			tree["node"].visible = revealed
		var lbl = tree["label_node"]
		if lbl:
			var dist = absi(player_grid.x - tp.x) + absi(player_grid.y - tp.y)
			lbl.visible = revealed and dist <= 2 and not tree["climbed"]

func get_obstacle_tiles() -> Array[Vector2i]:
	## Tree trunks and pits block movement (queried by main.gd for pathfinding).
	var tiles: Array[Vector2i] = []
	for tree in tree_nodes:
		tiles.append(tree["grid_pos"])
	for p in pit_tiles.keys():
		tiles.append(p)
	return tiles

# ============================================
# CAVE DRESSING — stalagmites (floor), stalactites (ceiling), divots and pebbles.
# Puddles are flagged in the layout and drawn by _build_floor_visuals. The whole
# place reads as a network of dripping stone tunnels.
# ============================================

func _build_cave_decorations() -> void:
	var pal = get_palette()
	var stalagmite_items: Array = []  # upward cones rooted to the floor
	var stalactite_items: Array = []  # downward cones hanging into the tunnel
	var divot_items: Array = []       # small dark floor depressions
	var pebble_items: Array = []      # scattered rubble

	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR:
				continue
			var pos = Vector2i(x, z)
			if _reserved.has(pos):
				continue
			var near_wall = not _has_adjacent_floor_on_all_sides(x, z)
			var n = _tile_noise(x, z, 53)
			var jx = (_tile_noise(x, z, 61) - 0.5) * 0.5
			var jz = (_tile_noise(x, z, 67) - 0.5) * 0.5
			var rot = Basis(Vector3.UP, _tile_noise(x, z, 71) * TAU)
			var is_wet = is_water(pos)

			if near_wall and n < 0.16:
				# Stalagmite rising from the floor (billboard sprite).
				var s = 0.6 + _tile_noise(x, z, 73) * 0.9
				stalagmite_items.append({
					"pos": Vector3(x + 0.5 + jx, 0.0, z + 0.5 + jz),
					"scale": s,
					"color": pal["wall_a"].lerp(pal["wall_b"], n * 3.0),
				})
			elif near_wall and n < 0.30:
				# Stalactite hanging from the gloom above (billboard sprite,
				# drawn tip-down; anchored so its root touches the dark above).
				var hs = 0.5 + _tile_noise(x, z, 77) * 0.7
				stalactite_items.append({
					"pos": Vector3(x + 0.5 + jx, 2.9 - 24.0 * 0.034 * hs, z + 0.5 + jz),
					"scale": hs,
					"color": pal["wall_a"].lerp(pal["wall_b"], n * 2.0),
				})
			elif not is_wet and n > 0.93:
				# A shallow divot pressed into the cave floor.
				divot_items.append({
					"xform": Transform3D(rot * Basis.from_scale(Vector3(0.5, 0.04, 0.5)),
						Vector3(x + 0.5 + jx, -0.06, z + 0.5 + jz)),
					"color": pal["floor_b"].darkened(0.4),
				})
			elif near_wall and n > 0.78:
				pebble_items.append(_make_rock(x, z, jx, jz, 0.0, rot, pal))

	_add_sprite_decos(stalagmite_items, "res://assets/textures/props/stalagmite.png", 16, 24)
	_add_sprite_decos(stalactite_items, "res://assets/textures/props/stalactite.png", 16, 24)

	_add_multimesh(BoxMesh.new(), divot_items)
	_add_multimesh(BoxMesh.new(), pebble_items)

	# A few slow drips falling from the larger stalactites add life to the gloom.
	_place_cave_drips(stalactite_items)
	print("[DUNGEON] Cave dressing: %d stalagmites, %d stalactites, %d divots" % [
		stalagmite_items.size(), stalactite_items.size(), divot_items.size()])

func _place_cave_drips(stalactite_items: Array) -> void:
	if stalactite_items.is_empty():
		return
	var want = clampi(stalactite_items.size() / 8, 2, 8)
	var step = maxi(1, stalactite_items.size() / want)
	var made = 0
	for i in range(0, stalactite_items.size(), step):
		if made >= want:
			break
		var origin: Vector3 = stalactite_items[i]["pos"]
		var drip = _make_water_stream()
		drip.position = Vector3(origin.x, origin.y - 0.4, origin.z)
		_visuals_root.add_child(drip)
		made += 1

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
	# Matches the WorldEnvironment backdrop (dark olive) so unexplored land
	# and the out-of-map void blend into one darkened treeline — no pure
	# black holes against the meadow (16-bit pass). A faint dither texture
	# keeps the slabs from reading as flat modern boxes.
	fog_mat.albedo_color = Color(1, 1, 1)
	fog_mat.albedo_texture = load("res://assets/textures/tile_fog.png")
	fog_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fog_mat.uv1_triplanar = true
	fog_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
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
	var r = fog_reveal_radius
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			# Circular reveal (Euclidean distance)
			if dx * dx + dz * dz > r * r:
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
	## World 1 gets two extra slots for the opening sewer grate and a forest
	## trailhead (on top of its usual cave + building), so all four are present.
	var site_total = 2 + (world_level - 1)
	if world_level == 1:
		site_total += 2
	var cave_count = 0
	var building_count = 0
	var sewer_count = 0
	var forest_count = 0
	var candidates: Array = []
	for i in range(rooms.size()):
		var room = rooms[i]
		if room["kind"] != "field" or room["elev"] > 0:
			continue
		var rect: Rect2i = room["rect"]
		# Room must fit the largest footprint (building, 4 wide) with a margin.
		if rect.size.x >= 7 and rect.size.y >= 6:
			candidates.append(i)

	for s in range(site_total):
		if candidates.is_empty():
			break
		var pick = _rng.randi_range(0, candidates.size() - 1)
		var room_idx = candidates[pick]
		candidates.remove_at(pick)
		var rect: Rect2i = rooms[room_idx]["rect"]
		# On the surface world (Act 1, World 1) the very first site is a sewer
		# grate — the game opens by descending into the sewers (see STORY.md).
		var kind: String
		if world_level == 1 and s == 0:
			kind = "sewer"
		elif world_level == 1 and s == 1:
			kind = "forest"
		elif s % 2 == 0:
			kind = "cave"
		else:
			kind = "building"

		var fp_w = 4 if kind == "building" else 3
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
		match kind:
			"sewer":
				id = "sewer_%d" % sewer_count
				display_name = "Sewer Entrance"
				sewer_count += 1
			"forest":
				id = "forest_%d" % forest_count
				display_name = "Forest Trail"
				forest_count += 1
			"building":
				id = "building_%d" % building_count
				display_name = "Building"
				building_count += 1
			_:
				id = "cave_%d" % cave_count
				display_name = "Cave"
				cave_count += 1

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

	match kind:
		"building":
			_build_building_exterior(site_root, fp_w, fp_d)
		"sewer":
			_build_sewer_entrance(site_root, fp_w, fp_d)
		"forest":
			_build_forest_entrance(site_root, fp_w, fp_d)
		_:
			_build_cave_entrance(site_root, fp_w, fp_d)

	# Name label floating above the structure
	var label = Label3D.new()
	label.text = display_name
	label.font_size = 22
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.95, 0.75)
	label.position = Vector3(0, 3.2, 0)
	WorldText.crisp(label)
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
	WorldText.crisp(interact_label)
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

func _pixel_mat(texture_path: String, tint: Color) -> StandardMaterial3D:
	## Nearest-filtered triplanar tile material for site structures, matching
	## the terrain formula: near-white cast so the sheet's colors survive.
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1).lerp(tint, 0.5)
	mat.albedo_texture = load(texture_path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mat.roughness = 1.0
	return mat

func _build_building_exterior(root: Node3D, fp_w: int, fp_d: int) -> void:
	## Simple generic structure: stone walls, pitched roof, door, lit windows.
	var w = fp_w - 0.3
	var d = fp_d - 0.3
	var wall_h = 1.8

	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(w, wall_h, d)
	body.mesh = body_mesh
	body.material_override = _pixel_mat("res://assets/textures/tile_brick.png", Color(0.55, 0.50, 0.44))
	body.position = Vector3(0, wall_h / 2.0, 0)
	root.add_child(body)

	var roof = MeshInstance3D.new()
	var roof_mesh = PrismMesh.new()
	roof_mesh.size = Vector3(d + 0.5, 0.9, w + 0.5)
	roof_mesh.left_to_right = 0.5
	roof.mesh = roof_mesh
	roof.material_override = _pixel_mat("res://assets/textures/tile_dirt.png", Color(0.42, 0.22, 0.16))
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
	mound.material_override = _pixel_mat("res://assets/textures/tile_rock.png", pal["cliff"])
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
		boulder.material_override = _pixel_mat("res://assets/textures/tile_rock.png", pal["wall_b"])
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

func _build_sewer_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	## A low brick headworks with an arched, barred opening descending into the
	## dark — the manhole/grate the player climbs down to reach the sewers.
	var brick = _pixel_mat("res://assets/textures/tile_brick.png", Color(0.30, 0.31, 0.29))

	# Squat stone surround.
	var block = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = Vector3(fp_w - 0.3, 1.3, fp_d - 0.4)
	block.mesh = bmesh
	block.material_override = brick
	block.position = Vector3(0, 0.65, -0.2)
	root.add_child(block)

	# Arched headstone over the mouth.
	var arch = MeshInstance3D.new()
	var amesh = CylinderMesh.new()
	amesh.top_radius = 0.55
	amesh.bottom_radius = 0.55
	amesh.height = fp_w - 0.5
	amesh.radial_segments = 12
	arch.mesh = amesh
	arch.rotation_degrees = Vector3(0, 0, 90)
	arch.material_override = brick
	arch.position = Vector3(0, 1.3, -0.2)
	root.add_child(arch)

	# The dark descending mouth.
	var mouth = MeshInstance3D.new()
	var mmesh = BoxMesh.new()
	mmesh.size = Vector3(1.0, 1.15, 0.5)
	mouth.mesh = mmesh
	var mmat = StandardMaterial3D.new()
	mmat.albedo_color = Color(0.01, 0.02, 0.02)
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mouth.material_override = mmat
	mouth.position = Vector3(0, 0.6, fp_d / 2.0 - 0.15)
	root.add_child(mouth)

	# Iron bars across the mouth (a raised grate).
	var bar_mat = StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.12, 0.12, 0.13)
	bar_mat.metallic = 0.0  # no modern specular pop
	bar_mat.roughness = 1.0
	for i in range(3):
		var bar = MeshInstance3D.new()
		var barmesh = BoxMesh.new()
		barmesh.size = Vector3(0.06, 1.0, 0.06)
		bar.mesh = barmesh
		bar.material_override = bar_mat
		bar.position = Vector3(-0.3 + i * 0.3, 0.6, fp_d / 2.0 + 0.02)
		root.add_child(bar)

	# A weak green glow leaking up from below.
	var glow = OmniLight3D.new()
	glow.light_color = Color(0.4, 0.7, 0.5)
	glow.light_energy = 0.8
	glow.omni_range = 3.5
	glow.omni_attenuation = 2.0  # tighter falloff, less modern gradient
	glow.position = Vector3(0, 0.3, fp_d / 2.0 - 0.1)
	root.add_child(glow)

func _build_forest_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	## A trailhead: two flanking trees over a wooden arch, opening onto a path
	## that leads into the deep woods.
	var bark = StandardMaterial3D.new()
	bark.albedo_color = Color(0.26, 0.18, 0.11)
	bark.roughness = 1.0

	# Two flanking trees — the same billboard sprite the forest interior uses,
	# scaled up into gateposts (no smooth mesh spheres).
	for side in [-1.0, 1.0]:
		var tree = Sprite3D.new()
		tree.texture = load("res://assets/textures/props/tree.png")
		tree.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tree.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		tree.shaded = false
		tree.pixel_size = 0.034
		var tree_scale := 1.6
		tree.scale = Vector3(tree_scale, tree_scale, tree_scale)
		tree.position = Vector3(side * fp_w * 0.42, 64.0 * 0.034 * 0.5 * tree_scale, -0.1)
		root.add_child(tree)

	# A simple wooden lintel spanning the two trees.
	var lintel = MeshInstance3D.new()
	var lmesh = BoxMesh.new()
	lmesh.size = Vector3(fp_w * 0.95, 0.18, 0.18)
	lintel.mesh = lmesh
	lintel.material_override = bark
	lintel.position = Vector3(0, 1.9, -0.1)
	root.add_child(lintel)

	# A shaded opening into the woods.
	var opening = MeshInstance3D.new()
	var omesh = BoxMesh.new()
	omesh.size = Vector3(1.1, 1.5, 0.4)
	opening.mesh = omesh
	var omat = StandardMaterial3D.new()
	omat.albedo_color = Color(0.04, 0.07, 0.04)
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	opening.material_override = omat
	opening.position = Vector3(0, 0.75, fp_d / 2.0 - 0.15)
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
	WorldText.crisp(label)
	site_root.add_child(label)

	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Leave"
	interact_label.font_size = 16
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 1.7, 0)
	interact_label.visible = false
	WorldText.crisp(interact_label)
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
		_set_chest_open_visual(i)

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

func _set_chest_open_visual(index: int) -> void:
	var sprite: Sprite3D = chest_nodes[index].get("sprite")
	if sprite:
		sprite.texture = load("res://assets/textures/props/chest_open.png")

func _create_chest(grid_pos: Vector2i) -> void:
	var chest_root = Node3D.new()
	chest_root.name = "TreasureChest_%d" % chest_nodes.size()

	# 16-bit billboard chest (closed sprite; swapped to the open sprite on open).
	# Contact shadow is painted into the sprite, same as the other ground props.
	var sprite = Sprite3D.new()
	sprite.name = "ChestSprite"
	sprite.texture = load("res://assets/textures/props/chest_closed.png")
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.pixel_size = 0.034  # style guide texel density
	# Bottom edge of the sprite rests on the ground, matching _add_sprite_decos.
	sprite.position = Vector3(0, 26.0 * 0.5 * sprite.pixel_size, 0)
	chest_root.add_child(sprite)

	# Interact label (floating above chest)
	var label = Label3D.new()
	label.name = "InteractLabel"
	label.text = "[Shift] Open"
	label.font_size = 18
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.9, 0.4)
	label.position = Vector3(0, 1.0, 0)
	label.visible = false
	WorldText.crisp(label)
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
		"sprite": sprite
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

# Act-1 mythic cap: set by main once this character's act-1 mythic has
# dropped — act-1 chests then stop offering mythics entirely.
var block_act1_mythics: bool = false

func _get_random_item(rng: RandomNumberGenerator) -> ItemData:
	# Chests roll the flat baseline rarity table (see DropRates) — mythic and
	# legendary stay at baseline in every act; the near-guaranteed act mythic
	# comes from the per-kill layer in main, never from chests. Only level-1
	# items ever drop — higher item levels exist solely through the forge.
	var weights: Dictionary = DropRates.CHEST_ITEM_WEIGHTS
	if block_act1_mythics and world_level == 1:
		weights = weights.duplicate()
		weights.erase(ItemData.Rarity.MYTHIC)
	var rarity = DropRates.roll_weighted(weights, rng)
	var pool = ItemData.get_items_of_rarity(rarity)
	if pool.is_empty():
		pool = ItemData.get_items_of_rarity(ItemData.Rarity.COMMON)
	return pool[rng.randi() % pool.size()]

func _get_random_card(rng: RandomNumberGenerator) -> Card:
	## Rarity-weighted over every droppable card (see Card.CARD_RARITIES),
	## deterministic per chest via the seeded rng.
	var rarity = DropRates.roll_weighted(DropRates.CARD_WEIGHTS, rng)
	var ids = Card.get_droppable_ids_of_rarity(rarity)
	if ids.is_empty():
		ids = Card.get_droppable_ids_of_rarity(Card.Rarity.BASIC)
	ids.sort()  # discovery order isn't guaranteed — sort so the seed is stable
	return Card.create_by_id(ids[rng.randi() % ids.size()])

# ============================================
# SPAWN ZONES (derived from rooms; difficulty scales with world + depth)
# ============================================

func _define_spawn_zones() -> void:
	spawn_zones.clear()

	if interior_kind == "sewer":
		_define_sewer_spawn_zones()
		return

	if interior_kind == "forest":
		_define_forest_spawn_zones()
		return

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
# SEWER SPAWN PROGRESSION
# West of the Rat King: rats and oozes (the player's first fights). The central
# cistern is the Rat King and his rat army. East of him the sewer turns deadly —
# crocodiles, swarms and pipe crawlers.
# ============================================

func _define_sewer_spawn_zones() -> void:
	# Locate the Rat King's arena so rooms can be classed as before/after the boss.
	var arena_x = GRID_W / 2
	for room in rooms:
		if room["kind"] == "arena":
			arena_x = (room["rect"] as Rect2i).get_center().x
			break

	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue

		if kind == "arena":
			_define_rat_king_zone(rect)
			continue

		# Pre-boss cisterns crawl with rats and oozes; post-boss ones with the
		# things that eat the rats.
		var post_boss = rect.get_center().x >= arena_x
		var roster: Array
		if post_boss:
			roster = [Enemy.EnemyType.SEWER_CROC, Enemy.EnemyType.SWARM,
				Enemy.EnemyType.PIPE_CRAWLER, Enemy.EnemyType.SLUDGE]
		else:
			roster = [Enemy.EnemyType.WERERAT, Enemy.EnemyType.ARCHER_RAT,
				Enemy.EnemyType.WERERAT, Enemy.EnemyType.SLUDGE]

		var zone_chance = 1.0 if kind == "deep" else 0.8
		if _rng.randf() >= zone_chance:
			continue

		var count = clampi(2 + rect.get_area() / 32, 2, 5)
		var points: Array = []
		var types: Array = []
		for _i in range(count):
			var cell = _pick_free_cell(rect, points)
			if cell.x < 0:
				continue
			points.append(cell)
			types.append(roster[_rng.randi_range(0, roster.size() - 1)])
		# The deepest chamber is guarded by a Sewer Crocodile.
		if kind == "deep" and types.size() > 0:
			types[0] = Enemy.EnemyType.SEWER_CROC
		if points.is_empty():
			continue

		spawn_zones.append({
			"trigger_rect": rect.grow(1),
			"spawn_points": points,
			"enemy_types": types,
			"spawned": false,
		})

	for pt_list in spawn_zones:
		for p in pt_list["spawn_points"]:
			_reserved[p] = true

	print("[DUNGEON] Defined %d sewer spawn zones (arena_x=%d)" % [spawn_zones.size(), arena_x])

func _define_rat_king_zone(rect: Rect2i) -> void:
	## The first mini-boss: the Rat King flanked by his swarming army.
	var c = rect.get_center()
	var points: Array = [c]
	var types: Array = [Enemy.EnemyType.RAT_KING]
	var army = [
		Enemy.EnemyType.WERERAT, Enemy.EnemyType.WERERAT, Enemy.EnemyType.ARCHER_RAT,
		Enemy.EnemyType.WERERAT, Enemy.EnemyType.SWARM, Enemy.EnemyType.ARCHER_RAT,
		Enemy.EnemyType.SWARM, Enemy.EnemyType.WERERAT,
	]
	var offsets = [
		Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-3, 1), Vector2i(3, 1),
		Vector2i(0, -3), Vector2i(0, 3), Vector2i(-4, 0), Vector2i(4, 0),
	]
	for i in range(offsets.size()):
		var cell = c + offsets[i]
		if is_floor(cell) and not (cell in points):
			points.append(cell)
			types.append(army[i])
	spawn_zones.append({
		"trigger_rect": rect.grow(1),
		"spawn_points": points,
		"enemy_types": types,
		"spawned": false,
	})

# ============================================
# FOREST SPAWN PROGRESSION
# Woodland beasts: packs of coyotes/wolves and bears across the clearings (bears
# matter because of the bear traps), hawks favouring the hills, and tougher
# elites deeper in. The deep clearing is guarded by a Large Bear.
# ============================================

func _define_forest_spawn_zones() -> void:
	var minions = [Enemy.EnemyType.COYOTE, Enemy.EnemyType.WOLF, Enemy.EnemyType.MINI_BEAR,
		Enemy.EnemyType.BUGBEAR, Enemy.EnemyType.GIANT_HAWK]
	var elites = [Enemy.EnemyType.LARGE_BEAR, Enemy.EnemyType.GIANT_BEAVER,
		Enemy.EnemyType.INFECTED_HUNTER, Enemy.EnemyType.TREANT]

	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue
		var zone_chance = 1.0 if kind == "deep" else 0.75
		if _rng.randf() >= zone_chance:
			continue
		var count = clampi(2 + rect.get_area() / 40, 2, 5)
		var points: Array = []
		var types: Array = []
		for _i in range(count):
			var cell = _pick_free_cell(rect, points)
			if cell.x < 0:
				continue
			points.append(cell)
			if room.get("hill", false) and _rng.randf() < 0.5:
				types.append(Enemy.EnemyType.GIANT_HAWK)  # hawks rule the high ground
			elif _rng.randf() < 0.22:
				types.append(elites[_rng.randi_range(0, elites.size() - 1)])
			else:
				types.append(minions[_rng.randi_range(0, minions.size() - 1)])
		if kind == "deep" and types.size() > 0:
			types[0] = Enemy.EnemyType.LARGE_BEAR
		if points.is_empty():
			continue
		spawn_zones.append({
			"trigger_rect": rect.grow(1),
			"spawn_points": points,
			"enemy_types": types,
			"spawned": false,
		})

	for pt_list in spawn_zones:
		for p in pt_list["spawn_points"]:
			_reserved[p] = true

	print("[DUNGEON] Defined %d forest spawn zones" % spawn_zones.size())

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

	# Slightly raised dirt mound under the ring, so waypoints read as a
	# landmark at a glance instead of a flat glow on the ground.
	var mound = MeshInstance3D.new()
	var mound_mesh = CylinderMesh.new()
	mound_mesh.top_radius = 0.68
	mound_mesh.bottom_radius = 0.95
	mound_mesh.height = 0.22
	mound_mesh.radial_segments = 12
	mound.mesh = mound_mesh
	mound.material_override = _pixel_mat("res://assets/textures/tile_dirt.png", Color(0.62, 0.5, 0.36))
	mound.position = Vector3(0, 0.11, 0)
	wp_root.add_child(mound)

	# Waypoint visual: chunky pixel rune-ring laid flat on the mound's top,
	# tinted per destination (master-palette tints, style guide §2).
	var pillar = Sprite3D.new()
	pillar.texture = load("res://assets/textures/props/waypoint_ring.png")
	pillar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pillar.shaded = false
	pillar.pixel_size = 0.045  # ring spans ~1.2 tiles
	pillar.rotation_degrees = Vector3(-90, 0, 0)
	var tint: Color
	match target:
		"transport":
			tint = Color8(0x62, 0xa3, 0xb0)  # TEAL_1
		"town":
			tint = Color8(0x3e, 0x67, 0x94)  # SKY_4
		"next_world":
			tint = Color8(0x38, 0x98, 0x78)  # TEAL_3
		"prev_world":
			tint = Color8(0xd8, 0xd3, 0x96)  # GOLD_2
		_:
			tint = Color8(0xb6, 0xc5, 0xc5)  # STEEL_6
	pillar.modulate = Color(tint, 0.75)  # dimmed until discovered
	pillar.position = Vector3(0, 0.25, 0)  # resting on the mound's top
	wp_root.add_child(pillar)

	# Label
	var label = Label3D.new()
	label.name = "WaypointLabel"
	label.text = display_name
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 1.0, 0.8)
	label.position = Vector3(0, 0.8, 0)
	WorldText.crisp(label)
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
	WorldText.crisp(interact_label)
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
	# Visual change: the ring lights up to full strength once activated
	var pillar = waypoint_nodes[index]["pillar_mesh"] as Sprite3D
	if pillar:
		pillar.modulate = Color(pillar.modulate.lightened(0.35), 1.0)
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

func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	## True if no wall sits between cells `a` and `b`. Walks the grid line with a
	## supercover DDA so attacks can't fire diagonally through a wall corner.
	## The endpoints themselves are never treated as blockers.
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var x := a.x
	var y := a.y
	var sx := 1 if b.x > a.x else -1
	var sy := 1 if b.y > a.y else -1
	var err := dx - dy
	var guard := 0
	while (x != b.x or y != b.y) and guard < 256:
		guard += 1
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		elif e2 < dx:
			err += dx
			y += sy
		else:
			err -= dy
			err += dx
			x += sx
			y += sy
		if x == b.x and y == b.y:
			break
		if is_wall(Vector2i(x, y)):
			return false
	return true

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

	# Visual feedback on first open: swap to the open-lid sprite
	if first_open:
		_set_chest_open_visual(index)

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
	water.clear()
	tree_nodes.clear()
	trap_defs.clear()
	pit_tiles.clear()
	torch_positions.clear()
