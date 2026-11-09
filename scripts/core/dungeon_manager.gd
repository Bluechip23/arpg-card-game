class_name DungeonManager
extends Node

## Something the head-up prompts and fog-gated visibility read has changed —
## a tile was revealed, a chest opened or looted, a trap sprung, a site or
## waypoint discovered, the feather trail moved. Main refreshes the prompt
## pass on it instead of every frame (see Main._process).
signal prompts_changed

## Generates and manages persistent world layouts: large outdoor regions made of
## rooms, corridors, terrain elevation (hills, cliff faces, stone steps), treasure
## chests, enemy zones, waypoints, and enterable sites (caves and buildings with
## their own interior maps).
##
## Layouts are DETERMINISTIC per world/interior (seeded by world level + interior
## id) so the world stays consistent across visits — this is a persistent RPG
## world, not a procedurally re-rolled roguelike.


var GRID_W: int = 70
var GRID_H: int = 46
const FOG_REVEAL_RADIUS: int = 6   # Tiles revealed around the player
## World units of height per elevation level. Kept shallow on purpose: the
## plan camera sorts by height, so a tall plateau north of a character would
## draw over them; the autotile lip marks the step visually instead.
const ELEV_STEP: float = 0.06
const WALL_HEIGHT: float = 0.06    # wall slab thickness (see _build_walls)

## TOP-DOWN GROUND. The ground is drawn as one autotiled mesh: each
## cell picks a 32px atlas tile by terrain (grass/dirt/water/pit/high) and by
## which neighbours differ, so trails, water and cliff tops get edge
## transitions. The atlas is assembled at runtime from the location's ground
## sheets — the Craftpix fills cut by tools/extract_craftpix_tiles.py — with the
## edge bands painted in the palette (_build_autotile_ground). The camera is
## fixed (CameraView).
## The waypoint's shrine is a platform: a hero walking onto its tile climbs
## up and stands on it (designer, 2026-11-01), not through it. In world
## units: lifts his feet to the middle of the shrine's dais on screen.
const WAYPOINT_MOUND_HEIGHT: float = 0.85
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
		"trail": Color(0.36, 0.29, 0.18),
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
		"trail": Color(0.45, 0.34, 0.20),
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
		"trail": Color(0.40, 0.38, 0.36),
	},
	4: {
		"name": "The Underworld",   # Hell: World 2 wears it (art_world); was Emberfall
		"water": Color(0.66, 0.24, 0.07),      # lava
		"water_edge": Color(1.0, 0.72, 0.2),   # its glowing crust
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
		"trail": Color(0.30, 0.20, 0.15),
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
		"trail": Color(0.28, 0.24, 0.30),
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

## A frozen cave: Frostreach's frost in the gloom (dimmer than the
## snowfields, brighter than a rock cave — the ice holds the light).
const ICE_CAVE_PALETTE := {
	"name": "Ice Cave",
	"ground": Color(0.05, 0.07, 0.10),
	"floor_a": Color(0.55, 0.60, 0.68),
	"floor_b": Color(0.44, 0.50, 0.60),
	"wall_a": Color(0.30, 0.36, 0.46),
	"wall_b": Color(0.20, 0.25, 0.34),
	"cliff": Color(0.26, 0.31, 0.41),
	"step": Color(0.46, 0.52, 0.60),
	"accent": Color(0.62, 0.72, 0.82),
	"ambient": Color(0.40, 0.46, 0.56),
	"sun": Color(0.80, 0.88, 1.0),
	"sun_energy": 0.5,
	"water": Color(0.30, 0.45, 0.60),    # frozen pool
	"water_edge": Color(0.70, 0.82, 0.92),
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
	# In buildings the "trail" flag marks the hall runner carpet, not dirt.
	"trail": Color(0.44, 0.16, 0.17),
	"torch": Color(1.0, 0.72, 0.4),       # hearth-warm wall sconces
}

# Damp, lightless brickwork. Greens of algae and stagnant water over cold grey
# stone — the first dungeon the player ever descends into (Act 1, the Sewers).
const SEWER_PALETTE := {
	"name": "Sewers",
	"ground": Color(0.04, 0.05, 0.05),
	"floor_a": Color(0.42, 0.46, 0.42),   # wet, mossy stone (a cast over the pack floor)
	"floor_b": Color(0.30, 0.34, 0.32),
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
var trail: Array = []       # 2D bool array [x][z] — true where floor is a worn dirt path
var rooms: Array = []       # [{rect: Rect2i, kind: String, elev: int}]

# When true, carving helpers flag the tiles they carve as trail (worn path).
# Turned on around road/trail carving in the overworld and forest layouts.
var _marking_trails: bool = false


# Forest interactables, consumed by main.gd at setup.
var tree_nodes: Array = []   # climbable trees: [{node, grid_pos, label_node, climbed}]
# Scenery that blocks movement for EVERY unit (tree trunks: the treeline,
# the overworld woods, and the climbable trees). Keyed Vector2i -> true.
# Placement runs a local cut-vertex test so no obstacle ever severs a path.
var obstacle_tiles: Dictionary = {}
var trap_defs: Array = []    # hazards: [{kind:"bear"/"dart", tiles:[Vector2i], grid_pos, node, sprung}]
var pit_tiles: Dictionary = {}  # Vector2i -> true: impassable pit hazards

# Per-location fog radius. Sewers reveal less; the open forest reveals more.
var fog_reveal_radius: int = FOG_REVEAL_RADIUS

var chest_nodes: Array = []     # [{node, grid_pos, opened, looted, contents, sprite}]
var spawn_zones: Array = []     # [{trigger_rect, spawn_points, enemy_types, spawned}]
var waypoint_nodes: Array = []  # [{node, grid_pos, target, display_name, label_node, discovered, pillar_mesh}]
## The waypoint shrines' sides and back (_block_waypoint_shrine): walls.
var waypoint_block_tiles: Dictionary = {}
var site_nodes: Array = []      # [{node, grid_pos (entrance), id, kind, display_name, label_node, footprint}]
var fountain_nodes: Array = []  # [{node, grid_pos, label_node, water_mesh, blessed, xp_used}] — see _place_fountains
var shrine_node: Dictionary = {}  # The Faithless' drowned shrine (sewer deep chamber): {node, grid_pos, label_node}
var player_start: Vector2i = Vector2i(2, 23)
## Where the exit arch stands off the entry tile: behind it, the way the
## player came in (west for nearly every interior; the Breach is entered
## from the south).
var exit_nudge: Vector3 = Vector3(-1, 0, 0)

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
	elif interior_id.begins_with("mountains"):
		interior_kind = "mountains"  # the Mountain Pass (Act 1, Mountains habitat)
	elif interior_id.begins_with("closet"):
		interior_kind = "closet"  # Thanatos Closet (the Underworld): undead crypts under the burning ground
	elif interior_id.begins_with("thanatoshall"):
		interior_kind = "thanatoshall"  # Thanatos's Hall: the boss room at the Closet's bottom
	elif interior_id.begins_with("icecave"):
		interior_kind = "icecave"  # a frozen cave (off the Mountain Pass, and Frostreach's caves)
	elif interior_id.begins_with("trolllair"):
		interior_kind = "trolllair"  # the Ice Troll Lair (off the Mountain Pass): its vault of gold
	elif interior_id.begins_with("graveyard"):
		interior_kind = "graveyard"
	elif interior_id.begins_with("dojo"):
		interior_kind = "dojo"
	elif interior_id.begins_with("ratking"):
		interior_kind = "ratking"  # the Rat King's Lair (boss room off the sewer)
	elif interior_id.begins_with("boneyard"):
		interior_kind = "boneyard"  # the Boneyard: the Bone Dragon's graveyard (boss room off the Old Graveyard)
	elif interior_id.begins_with("hellgate"):
		interior_kind = "hellgate"  # Hell's Gate: Cerberus and the door down (boss room off the caves)
	elif interior_id.begins_with("labyrinth"):
		interior_kind = "labyrinth"  # The Labyrinth: the Inflamed Minotaur (boss room off the second world's caves)
	else:
		# Act 2's later places (the Underworld, 2026-11-09): the Brimstone
		# Rift, the Citadel of Dis, the Ashen Stair and their sealed rooms.
		for k in ACT2_KINDS:
			if interior_id.begins_with(k):
				interior_kind = k
				break

	# Fog scales with how lit the place is: tight, lightless sewers reveal least,
	# the bright open forest reveals most, everything else uses the default.
	match interior_kind:
		"sewer":
			fog_reveal_radius = 4
		"forest", "mountains", "rift", "ascent":
			fog_reveal_radius = 9   # open, bright country: the view runs far
		"dojo":
			fog_reveal_radius = 64  # a lit hall: nothing to explore, nothing hidden
		"ratking", "boneyard", "hellgate", "labyrinth", "thanatoshall", "crucible", "throne", "breach":
			fog_reveal_radius = 64  # a boss arena: the whole room is in view from the gate
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
		"cave", "graveyard":
			_generate_cave_layout()
		"building":
			_generate_building_layout()
		"sewer":
			_generate_sewer_layout()
		"forest":
			_generate_forest_layout()
		"mountains":
			_generate_mountain_layout()
		"icecave", "closet":
			_generate_cave_layout()   # the cave's chambers and tunnels (frozen; or a crypt)
		"thanatoshall":
			_generate_thanatos_hall_layout()
		"trolllair":
			_generate_troll_lair_layout()
		"dojo":
			_generate_dojo_layout()
		"ratking":
			_generate_rat_king_layout()
		"boneyard":
			_generate_boneyard_layout()
		"hellgate":
			_generate_hellgate_layout()
		"labyrinth":
			_generate_labyrinth_layout()
		"rift":
			_generate_rift_layout()
		"crucible":
			_generate_crucible_layout()
		"citadel":
			_generate_citadel_layout()
		"throne":
			_generate_throne_layout()
		"ascent":
			_generate_mountain_layout()   # the Mountain Pass's terraces, in the hell art
			_place_ascent_lava()
			_prune_dead_ends()
		"breach":
			_generate_breach_layout()
		_:
			_generate_overworld_layout()
	_generate_elevation()
	_detect_cliffs()

	# Interactables (placed before visuals so decorations avoid their tiles)
	_reserved.clear()
	obstacle_tiles.clear()
	_reserve_area(player_start, 1)
	trap_defs.clear()  # every interior lays its own hazards (forest re-clears, harmlessly)
	for c in bridge_cells:
		_reserved[c] = true   # the Rift's bridges: no chest, spawn or scatter on them
	if interior_kind == "forest":
		_place_forest_features()  # climbable trees, traps and pits (reserves tiles)
	if interior_kind == "cave":
		_place_cave_webs()  # spiked spiderwebs strung across the tunnels
	if interior_kind == "building":
		_place_wall_dart_shooters()  # dart shooters set into the walls
	if interior_kind == "":
		_place_waypoints()
		_place_sites()
	elif is_boss_room(interior_id):
		# A boss room is sealed behind the player; main opens the exit when
		# the boss dies (an already-cleared room opens from the start).
		if is_boss_cleared():
			_place_exit_site()
			if interior_kind == "hellgate":
				_place_hell_descent()
			elif interior_kind == "breach":
				_place_breach_ascent()
	else:
		_place_exit_site()
		if interior_kind == "sewer":
			# The far wall of the central cistern: the Rat King's Lair.
			_place_boss_door("arena", "far_wall", "ratking_lair", "ratking", "Rat King's Lair", Color(1.0, 0.8, 0.7), Color(1.0, 0.55, 0.4))
		elif interior_kind == "graveyard":
			# The east end of the deepest crypt: the Boneyard.
			_place_boss_door("deep", "east", "boneyard", "boneyard", "The Boneyard", Color(0.8, 0.95, 0.85), Color(0.5, 1.0, 0.6))
		elif interior_kind == "cave" and world_level == 1:
			# The deepest cave of the first world: Hell's Gate, Cerberus's post.
			_place_boss_door("deep", "east", "hellgate", "hellgate", "Hell's Gate", Color(1.0, 0.6, 0.5), Color(1.0, 0.3, 0.15))
		elif interior_kind == "cave" and world_level == 2:
			# The deepest cave of the Underworld: the Labyrinth, the Inflamed Minotaur's maze.
			_place_boss_door("deep", "east", "labyrinth", "labyrinth", "The Labyrinth", Color(1.0, 0.7, 0.45), Color(1.0, 0.45, 0.1))
		elif interior_kind == "mountains":
			_place_mountain_caves()
		elif interior_kind == "closet":
			# The Closet's deepest crypt: the way down to Thanatos.
			_place_boss_door("deep", "east", "thanatoshall", "thanatoshall", "Thanatos's Hall", Color(0.75, 0.95, 0.8), Color(0.45, 1.0, 0.6))
		elif interior_kind == "rift":
			# The Rift's far landing: the Crucible, where two ifrits keep the fire.
			_place_boss_door("deep", "east", "crucible", "crucible", "The Crucible", Color(1.0, 0.72, 0.5), Color(1.0, 0.45, 0.15))
		elif interior_kind == "citadel":
			# The Citadel's inner court: the doors of the Throne of Dis.
			_place_boss_door("deep", "east", "throne", "throne", "Throne of Dis", Color(1.0, 0.65, 0.6), Color(1.0, 0.3, 0.2))
		elif interior_kind == "ascent":
			# The top of the Ashen Stair: the Breach, the way up out of the Underworld.
			_place_breach_door()
	_place_chests()
	_place_fountains()
	_place_shrine()
	if interior_kind == "trolllair":
		_place_troll_hoard()
	_define_spawn_zones()

	# Terrain visuals
	_build_autotile_ground()
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

	# Redraw the cell lines now that elevation exists, so they ride up onto
	# plateaus instead of hiding under them.
	if grid_manager and grid_manager.has_method("redraw_grid"):
		grid_manager.cell_height = Callable(self, "get_elevation_world_y")
		grid_manager.redraw_grid()

	print("[DUNGEON] Generated %s (%dx%d): %d rooms, %d chests, %d zones, %d sites" % [
		get_location_name(), GRID_W, GRID_H, rooms.size(), chest_nodes.size(),
		spawn_zones.size(), site_nodes.size()])

func _set_world_size() -> void:
	if interior_kind == "labyrinth":
		# One square maze; the player enters from the west, the Minotaur waits
		# in the open court at its heart.
		GRID_W = LB_SIZE
		GRID_H = LB_SIZE
		player_start = Vector2i(1, LB_ENTRY_Z)
		return
	if interior_kind == "hellgate":
		# One long cavern hall; the player enters from the west, the door is east.
		GRID_W = HG_SIZE.x
		GRID_H = HG_SIZE.y
		player_start = Vector2i(HG_FLOOR.position.x + 1, HG_FLOOR.get_center().y)
		return
	if interior_kind == "boneyard":
		# One walled square; the player enters through the gate on the west.
		GRID_W = BY_SIZE
		GRID_H = BY_SIZE
		player_start = Vector2i(BY_FLOOR.position.x + 1, BY_FLOOR.get_center().y)
		return
	if interior_kind == "ratking":
		# One round den; the player enters from the west edge.
		GRID_W = RK_SIZE
		GRID_H = RK_SIZE
		player_start = Vector2i(RK_CENTER.x - RK_RADIUS + 1, RK_CENTER.y)
		return
	if interior_kind == "dojo":
		# One training hall: four dummies in a square, the door at the south.
		GRID_W = DOJO_W
		GRID_H = DOJO_H
		player_start = Vector2i(DOJO_W / 2, DOJO_H - 3)
		return
	if interior_kind == "closet":
		# Thanatos Closet: a crypt warren bigger than a cave, entered from the west.
		GRID_W = 46 + world_level * 2
		GRID_H = 30 + world_level
		player_start = Vector2i(3, GRID_H / 2)
		return
	if interior_kind == "thanatoshall":
		GRID_W = TH_SIZE.x
		GRID_H = TH_SIZE.y
		player_start = Vector2i(TH_FLOOR.position.x + 1, TH_FLOOR.get_center().y)
		return
	if interior_kind == "trolllair":
		GRID_W = TL_SIZE.x
		GRID_H = TL_SIZE.y
		player_start = Vector2i(2, TL_SIZE.y / 2)
		return
	exit_nudge = Vector3(-1, 0, 0)
	match interior_kind:
		"rift":
			# A long canyon, entered from the west, its far landing east.
			GRID_W = 60 + world_level * 2
			GRID_H = 34 + world_level
			player_start = Vector2i(3, GRID_H / 2)
			return
		"citadel":
			# A walled fortress: the gate on the west, the throne's doors east.
			GRID_W = 54 + world_level * 2
			GRID_H = 36 + world_level
			player_start = Vector2i(2, GRID_H / 2)
			return
		"ascent":
			# The Mountain Pass's shape: the foot south-west, the top north-east.
			GRID_W = 62 + world_level * 2
			GRID_H = 44 + world_level
			player_start = Vector2i(4, GRID_H - 6)
			return
		"crucible":
			GRID_W = CR_SIZE.x
			GRID_H = CR_SIZE.y
			player_start = Vector2i(CR_FLOOR.position.x + 1, CR_FLOOR.get_center().y)
			return
		"throne":
			GRID_W = TR_SIZE.x
			GRID_H = TR_SIZE.y
			player_start = Vector2i(TR_FLOOR.position.x + 1, TR_FLOOR.get_center().y)
			return
		"breach":
			# Entered from the south (up the Stair); the gate is in the north wall.
			GRID_W = BR_SIZE.x
			GRID_H = BR_SIZE.y
			player_start = Vector2i(BR_FLOOR.get_center().x, BR_FLOOR.end.y - 2)
			exit_nudge = Vector3(0, 0, 1)
			return
	if interior_kind == "cave" or interior_kind == "graveyard" or interior_kind == "icecave":
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
	if interior_kind == "mountains":
		# A mountainside climbing up the screen: the trailhead at the foot,
		# south-west, the summit to the north-east.
		GRID_W = 62 + world_level * 2
		GRID_H = 44 + world_level
		player_start = Vector2i(4, GRID_H - 6)
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

var _graveyard_palette: Dictionary = {}

func _get_graveyard_palette() -> Dictionary:
	## Cold, moonlit stone: the cave palette shifted grey-green.
	if _graveyard_palette.is_empty():
		_graveyard_palette = CAVE_PALETTE.duplicate(true)
		_graveyard_palette["name"] = "Graveyard"
		_graveyard_palette["floor_a"] = Color(0.16, 0.19, 0.16)
		_graveyard_palette["floor_b"] = Color(0.11, 0.14, 0.12)
		_graveyard_palette["wall_a"] = Color(0.24, 0.26, 0.25)
		_graveyard_palette["wall_b"] = Color(0.14, 0.16, 0.16)
		_graveyard_palette["cliff"] = Color(0.20, 0.22, 0.21)
		_graveyard_palette["accent"] = Color(0.34, 0.38, 0.30)
		_graveyard_palette["ambient"] = Color(0.16, 0.19, 0.21)
		_graveyard_palette["sun"] = Color(0.62, 0.70, 0.78)
		_graveyard_palette["sun_energy"] = 0.35
	return _graveyard_palette

## Which world's art a world wears (designer, 2026-11-05: "build out Hell"):
## World 2 is the Underworld — Act 2, Hell, below Hell's Gate — so it wears
## the hell art first painted for World 4 (cursed earth, lava, volcanoes and
## demon idols); World 4 (Act 4, the corrupted Earth) takes the Amber
## Wastes' desert in exchange. Gameplay keys on world_level; only the look
## follows this.
func art_world() -> int:
	match world_level:
		2:
			return 4
		4:
			return 2
	return world_level

func get_palette() -> Dictionary:
	if interior_kind == "cave" or interior_kind == "hellgate" or interior_kind == "labyrinth":
		return CAVE_PALETTE
	if interior_kind in ["graveyard", "boneyard", "closet", "thanatoshall"]:
		return _get_graveyard_palette()
	if interior_kind == "building" or interior_kind == "dojo":
		return BUILDING_PALETTE
	if interior_kind == "sewer" or interior_kind == "ratking":
		return SEWER_PALETTE
	if interior_kind == "forest":
		return FOREST_PALETTE
	if interior_kind == "mountains":
		return WORLD_PALETTES[3]   # Frostreach's snow and frost (the winter pack)
	if interior_kind == "icecave" or interior_kind == "trolllair":
		return ICE_CAVE_PALETTE
	if act2_place():
		return WORLD_PALETTES[4]   # the Underworld's own light, whichever world boots it (the Boss Simulator)
	return WORLD_PALETTES.get(art_world(), WORLD_PALETTES[1])

## Act 2's later places (2026-11-09): the Brimstone Rift and the Crucible, the
## Citadel of Dis and its Throne, the Ashen Stair and the Breach. All six wear
## the Underworld's own art — the designer's cursed earth, veined cliffs and
## hell props — with the cave pack's lava for their molten ground.
const ACT2_KINDS := ["rift", "crucible", "citadel", "throne", "ascent", "breach"]

func act2_place() -> bool:
	return interior_kind in ACT2_KINDS

## Ground sheets per location flavour. Craftpix top-down tileset fills
## (assets/textures/craftpix/, cut by tools/extract_craftpix_tiles.py), the
## closest pack for each place. Every sheet is a 4x4 grid of 32px variants sampled triplanar (see
## _add_multimesh). Colour-authored sheets get only a light palette cast.
const CP_TEX := "res://assets/textures/craftpix"
## The designer's own ground (tools/cut_ground_boards.py): 4x4 sheets at 64
## texels a tile, painted to run on unbroken (laid by position, not hash).
const GROUND_TEX := "res://assets/textures/ground"

func floor_texture_path() -> String:
	if act2_place():
		return GROUND_TEX + "/cursed_floor.png"   # the Underworld's cursed earth (the designer's, 2026-10-29)
	match interior_kind:
		"boneyard", "closet", "thanatoshall":   # the undead land: the Boneyard and Thanatos Closet
			return GROUND_TEX + "/undead_floor.png"   # the designer's barrow land (2026-10-29)
		"sewer", "ratking":
			return CP_TEX + "/floor_glowing_cave.png"  # wet stone (glowing-cave pack; the plain cave fill went black under the sewer's dim light)
		"building", "dojo":
			return CP_TEX + "/floor_undead.png"  # grey flagstones (undead pack's cracked stone)
		"cave":
			return GROUND_TEX + ("/cave_floor_glow.png" if cave_glows() else "/cave_floor.png")   # the designer's (2026-10-29)
		"hellgate", "labyrinth":
			return CP_TEX + "/floor_cave.png"
		"forest":
			return GROUND_TEX + "/forest_grass.png"   # the designer's (2026-10-29); was the pack's floor_grass_forest
		"mountains", "icecave", "trolllair":
			return CP_TEX + "/floor_winter.png"   # Frostreach's snowfield (winter pack)
	match art_world():
		4:  # Emberfall — the designer's flesh-pink cursed earth (2026-10-29; was the cursed land pack's)
			return GROUND_TEX + "/cursed_floor.png"
		5:  # Umbral Expanse — the designer's pocked grey barrow earth (2026-10-29; was the undead land pack's)
			return GROUND_TEX + "/undead_floor.png"
		2:  # Amber Wastes — the designer's olive scrub (2026-10-29; was the desert pack's)
			return GROUND_TEX + "/desert_floor.png"
		3:  # Frostreach — snowfield (winter pack drifts over flat snow)
			return CP_TEX + "/floor_winter.png"
	return GROUND_TEX + "/field_grass.png"   # the designer's grass tiles (2026-10-29; was the grassland pack's)


## The accent-free variant of the floor sheet for the backdrop plane beyond
## the walls: under its dark tint, flowers and tufts read as specks. (The
## Craftpix fills are plain — their detail lives in overlay sheets — so they
## serve as their own far variant.)
func far_floor_texture_path() -> String:
	return floor_texture_path()


## Worn dirt trails / roads through the floor sheet above.
func trail_texture_path() -> String:
	if act2_place():
		return GROUND_TEX + "/cursed_dark.png"   # dark cracked earth: the Stair's steps, the Citadel's paved halls
	match interior_kind:
		"forest":
			return GROUND_TEX + "/forest_dirt.png"   # the designer's cobbled dirt (2026-10-29)
		"cave", "sewer", "building", "ratking", "hellgate", "labyrinth":
			return CP_TEX + "/floor_dirt_forest.png"  # trodden dark earth
		"boneyard", "closet", "thanatoshall":
			return GROUND_TEX + "/undead_cobble.png"   # the designer's barrow land (2026-10-29)
		"mountains", "icecave", "trolllair":
			return CP_TEX + "/floor_undead_sand.png"  # trodden grey slush: the trails and the steps up the cliffs
	if art_world() == 1:
		return GROUND_TEX + "/field_dirt.png"   # the designer's dirt (2026-10-29)
	if art_world() == 2:
		return GROUND_TEX + "/desert_sand.png"  # the designer's sand tracks through the scrub
	if art_world() == 3:
		return CP_TEX + "/floor_undead_sand.png"  # trodden grey slush through the snow
	if art_world() == 4:
		return GROUND_TEX + "/cursed_dark.png"  # the designer's dark cracked earth (2026-10-29)
	if art_world() == 5:
		return GROUND_TEX + "/undead_cobble.png"  # the designer's pale cobbles (2026-10-29)
	return GROUND_TEX + "/field_dirt.png"


## Cliff faces / rock walls: the matching pack's cobbled cliff fill.
func wall_texture_path() -> String:
	if act2_place():
		return GROUND_TEX + "/cursed_wall.png"   # the designer's woven veins, as the Underworld's
	match interior_kind:
		"boneyard", "closet", "thanatoshall":   # the undead land: the Boneyard and Thanatos Closet
			return GROUND_TEX + "/undead_wall.png"   # the designer's barrow land (2026-10-29)
		"sewer", "ratking":
			return CP_TEX + "/wall_cave.png"  # dark cave rock
		"building":
			return CP_TEX + "/wall_undead.png"  # grey barrow stone
		"cave":
			return GROUND_TEX + ("/cave_wall_glow.png" if cave_glows() else "/cave_wall.png")   # the designer's (2026-10-29)
		"hellgate", "labyrinth":
			return CP_TEX + "/wall_cave.png"
		"forest":
			return GROUND_TEX + "/forest_wall.png"   # the designer's mossy cobble (2026-10-29)
		"mountains", "icecave", "trolllair":
			return CP_TEX + "/wall_undead.png"  # grey rock under the frost palette, as Frostreach's
	match art_world():
		4:
			return GROUND_TEX + "/cursed_wall.png"   # the designer's woven veins (2026-10-29)
		5:
			return GROUND_TEX + "/undead_wall.png"   # the designer's dark spikes (2026-10-29)
		2:
			return GROUND_TEX + "/desert_wall.png"   # the designer's cliff rock
		3:
			return CP_TEX + "/wall_undead.png"  # the winter pack has no cliff; grey barrow stone under the frost palette
	return GROUND_TEX + "/field_wall.png"   # the designer's cobbled earth (2026-10-29)


## Still water: the pack's water colour under its foam overlay.
func water_texture_path() -> String:
	if act2_place():
		return CP_TEX + "/water_lava.png"   # lava no one wades (cave pack), as in the Burning Caves and the Labyrinth
	match interior_kind:
		"boneyard", "closet", "thanatoshall":   # the undead land: the Boneyard and Thanatos Closet
			return GROUND_TEX + "/undead_water.png"   # the designer's barrow land (2026-10-29)
		"hellgate", "labyrinth":
			return CP_TEX + "/water_lava.png"  # the pools at Hell's threshold, and in the Minotaur's court, are lava (cave pack)
		"cave":
			if hell_cave():
				return CP_TEX + "/water_lava.png"   # Hell's caves: lava, as at Hell's Gate (cave pack)
			return GROUND_TEX + "/cave_water.png"   # the designer's dark cave water (2026-10-29)
		"sewer", "ratking":
			return CP_TEX + "/water_cave.png"
		"forest":
			return GROUND_TEX + "/forest_water.png"   # the designer's (2026-10-29)
		"icecave", "trolllair", "mountains":
			return CP_TEX + "/water_winter.png"  # frozen over
	match art_world():
		4:
			return GROUND_TEX + "/cursed_water.png"  # the designer's dark water (2026-10-29; was the cave pack's lava)
		5:
			return GROUND_TEX + "/undead_water.png"   # the designer's green bog (2026-10-29)
		2:
			return GROUND_TEX + "/desert_water.png"
		3:
			return CP_TEX + "/water_winter.png"  # frozen over
	return GROUND_TEX + "/field_water.png"   # the designer's (2026-10-29)


## Prop sprites for this location: the pack biome's role in the cut
## props (CraftpixProps, tools/build_craftpix_props.py), or none when the
## biome has no such role. `base` is the prop family (tree,
## rock, bush ...); biome prefixes: field (World 1), forest, cave, undead
## (World 5), cursed (World 4), goods (buildings).
func _prop_biome() -> String:
	if act2_place():
		return "cursed"   # the designer's cursed land and hell, as the Underworld's surface
	match interior_kind:
		"forest":
			return "forest"
		"cave":
			return "cave"
		"building":
			return "goods"
		"sewer", "ratking":
			return "sewer"
		"boneyard", "closet", "thanatoshall":
			return "undead"
		"hellgate", "labyrinth":
			return "cave"
		"mountains":
			return "winter"   # snow-laden pines, snowy stones, ice
		"icecave", "trolllair":
			return "ice"      # the cave's dressing in ice (PROP_ROLES "ice")
	match art_world():
		2:
			return "desert"
		3:
			return "winter"
		4:
			return "cursed"
		5:
			return "undead"
	return "field"


## Roles tried in order for a prop family in a biome. Biomes without a
## family borrow a neighbour's (sewer bones are barrow bones, sewer reeds are
## forest reeds); anything unlisted is left out.
const PROP_ROLES := {
	"field": {"tree": ["field_tree", "field_tree_small"], "stump": ["field_stump"], "rock": ["field_rock"],
		"bush": ["field_bush"], "berry": ["field_berry"], "fern": ["field_fern"], "flower": ["field_flower"],
		"tuft": ["field_tuft"], "shroom": ["field_shroom"], "pebble": ["field_pebble"], "log": ["field_log"],
		"bones": ["undead_bones"], "reeds": ["forest_reeds"], "wallrock": ["wallrock_moss"]},
	"forest": {"tree": ["forest_tree"], "tree_big": ["forest_tree_big"], "stump": ["forest_stump"], "log": ["forest_log"],
		"rock": ["forest_rock"], "bush": ["forest_bush"], "berry": ["field_berry"], "fern": ["forest_fern"],
		"flower": ["field_flower"], "tuft": ["field_tuft"], "shroom": ["forest_shroom"], "pebble": ["forest_pebble"],
		"reeds": ["forest_reeds"], "bones": ["undead_bones"], "wallrock": ["wallrock_rust"]},
	"cave": {"stalagmite": ["cave_stalagmite"], "stalactite": ["cave_stalactite"], "rock": ["cave_rock"], "shroom": ["cave_shroom"],
		"crystal": ["cave_crystal"], "pebble": ["cave_pebble"], "bones": ["undead_bones"], "web": ["cave_web"],
		"wallrock": ["wallrock_grey"]},
	"undead": {"tree": ["undead_tree"], "stump": ["undead_stump"], "rock": ["undead_rock"], "bush": ["undead_bush"],
		# underground (Thanatos Closet, through the cave's dressing): headstones
		# for its stalagmites, the cave's stalactites, pale grave plants
		"stalagmite": ["undead_grave"], "stalactite": ["cave_stalactite"], "crystal": ["undead_plant"],
		"berry": ["undead_bush"], "fern": ["undead_plant"], "flower": ["undead_plant"], "tuft": ["undead_bones"],   # the designer's barrow land (2026-10-29)
		"shroom": ["undead_skulls"], "pebble": ["undead_bones"], "bones": ["undead_bones"], "reeds": ["forest_reeds"],
		"wallrock": ["wallrock_dark"]},
	# The designer's cursed land and hell (2026-10-29), mixed.
	"cursed": {"tree": ["cursed_tree", "hell_tree", "hell_spire"], "stump": ["cursed_eye", "hell_eye"],
		"rock": ["cursed_rock", "cursed_eye_rock", "hell_rock", "hell_horn"], "bush": ["cursed_pod", "hell_bloom", "hell_veins"],
		"berry": ["hell_pustule", "hell_vent"], "fern": ["cursed_plant", "hell_leaf"], "flower": ["cursed_coral", "hell_leaf"],
		"tuft": ["cursed_bones", "hell_bones"], "shroom": ["cursed_shroom"], "pebble": ["cursed_bones", "hell_shard", "hell_bones"],
		"bones": ["cursed_bones", "hell_bones", "hell_post"], "reeds": ["forest_reeds"],
		"wallrock": ["wallrock_lava"]},
	"desert": {"tree": ["desert_tree"], "stump": ["desert_tree_dead"], "rock": ["desert_mesa"], "bush": ["desert_bush"],   # (the pack's pale stacked rocks gave way to the designer's mesas, 2026-10-29)
		"berry": ["desert_cactus"], "fern": ["desert_bush"], "flower": ["desert_flower"], "tuft": ["desert_tuft"],
		"shroom": ["desert_cactus"], "pebble": ["desert_pebble"], "bones": ["desert_bones"], "reeds": ["desert_tuft"],
		"wallrock": ["wallrock_sand"]},
	"winter": {"tree": ["winter_tree", "winter_tree_big"], "stump": ["winter_snowman", "winter_idol"], "rock": ["winter_rock"], "bush": ["winter_bush"],   # the designer's Frostreach (2026-10-29)
		"berry": ["winter_flower"], "fern": ["winter_crystal"], "flower": ["winter_flower"], "tuft": ["winter_pebble"],
		"shroom": ["winter_shroom"], "pebble": ["winter_pebble"], "bones": ["undead_bones"], "reeds": ["winter_ice_tree"],
		"wallrock": ["wallrock_snow"]},
	# A frozen cave (icecave, trolllair): the cave's dressing in ice — the
	# winter pack's crystals rise as its stalagmites (no pack draws ice
	# stalagmites), snowy stones and pebbles, the cave's own stalactites.
	"ice": {"stalagmite": ["winter_crystal"], "stalactite": ["cave_stalactite"], "shroom": ["winter_shroom"],
		"crystal": ["winter_crystal"], "pebble": ["winter_pebble"], "rock": ["wallrock_snow"], "bones": ["undead_bones"],
		"wallrock": ["wallrock_snow"]},
	"goods": {"crate": ["goods_crate", "goods_sack"], "barrel": ["goods_barrel", "goods_rack", "goods_table"]},
	"sewer": {"bones": ["undead_bones"], "reeds": ["forest_reeds"], "rubble": ["cave_pebble", "cave_rock"],
		"wallrock": ["wallrock_dark"]},
}


## A billboard Sprite3D of one pack prop (role variant `k`), or null when
## the cut props have no such role. Pivot at the feet; lifted like every
## other billboard so the plan camera sorts it per pixel.
func _make_prop_sprite(role: String, scale: float = 1.0, k: int = 0, lift: float = CameraView.SPRITE_LIFT) -> Sprite3D:
	if not CraftpixProps.has(role):
		return null
	var cfg: Dictionary = CraftpixProps.PROPS[role]
	var v: Dictionary = cfg["variants"][k % cfg["variants"].size()]
	var sprite := Sprite3D.new()
	sprite.texture = load(v["path"])
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # writes depth: per-pixel sorting
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.pixel_size = 0.03125
	sprite.centered = false
	sprite.offset = Vector2(-float(v["w"]) * 0.5, 0)  # feet on the origin
	var sc: float = scale * float(cfg["scale"])
	sprite.scale = Vector3(sc, sc, sc)
	sprite.position = Vector3(0, lift, 0)
	return sprite


## The Return Scroll's town portal: a swirling purple oval (a flattened
## torus) with a glowing translucent film inside it, lying on its back just
## above the ground so the plan-view camera sees the portal's face, not its
## rim. Used on the battle side and for its twin in town. No pack draws a
## portal of this kind, so it is built in the packs' purple.
static func make_town_portal_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "PortalVisual"

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.75
	ring.mesh = torus
	ring.position = Vector3(0, 0.12, 0)  # flat: the torus's hole points up
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.6, 0.25, 0.95)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.55, 0.2, 0.9)
	ring_mat.emission_energy_multiplier = 1.6
	ring.material_override = ring_mat
	root.add_child(ring)

	var film := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.58
	disc.bottom_radius = 0.58
	disc.height = 0.05
	film.mesh = disc
	film.position = Vector3(0, 0.10, 0)  # a flat disc inside the ring
	var film_mat := StandardMaterial3D.new()
	film_mat.albedo_color = Color(0.75, 0.45, 1.0, 0.55)
	film_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	film_mat.emission_enabled = true
	film_mat.emission = Color(0.7, 0.4, 1.0)
	film_mat.emission_energy_multiplier = 1.2
	film.material_override = film_mat
	root.add_child(film)
	return root

func _prop_variants(base: String) -> Array:
	var roles: Array = PROP_ROLES.get(_prop_biome(), {}).get(base, [])
	var out: Array = []
	for role in roles:
		if CraftpixProps.has(role):
			var cfg: Dictionary = CraftpixProps.PROPS[role]
			for v in cfg["variants"]:
				out.append({"path": v["path"], "w": v["w"], "h": v["h"], "scale": cfg["scale"],
						"density": float(cfg.get("density", 32))})
	return out


## Scatter a prop family: pack variants spread across the items by cell
## hash (one MultiMesh per variant). A biome with no pack art for the
## family simply goes without it.
func _add_prop_decos(items: Array, base: String) -> void:
	var variants := _prop_variants(base)
	if items.is_empty() or variants.is_empty():
		return
	var buckets: Array = []
	for _v in variants:
		buckets.append([])
	for it in items:
		var pos: Vector3 = it["pos"]
		var k := int(_tile_noise(int(floor(pos.x)), int(floor(pos.z)), 131) * variants.size()) % variants.size()
		var copy: Dictionary = it.duplicate()
		copy["scale"] = float(it.get("scale", 1.0)) * float(variants[k]["scale"])
		buckets[k].append(copy)
	for k in range(variants.size()):
		if not buckets[k].is_empty():
			_add_sprite_decos(buckets[k], variants[k]["path"], variants[k]["w"], variants[k]["h"],
					float(variants[k]["h"]) * 32.0 / float(variants[k]["density"]))


func get_location_name() -> String:
	if interior_kind == "cave":
		return ("Burning Cave %d" if hell_cave() else "Cave %d") % (int(interior_id.get_slice("_", 1)) + 1)
	if interior_kind == "building":
		return "Building %d" % (int(interior_id.get_slice("_", 1)) + 1)
	if interior_kind == "sewer":
		return "Sewers"
	if interior_kind == "forest":
		return "Greenwood"
	if interior_kind == "mountains":
		return "Mountain Pass"
	if interior_kind == "icecave":
		return "Ice Cave %d" % (int(interior_id.get_slice("_", 1)) + 1)
	if interior_kind == "trolllair":
		return "Ice Troll Lair"
	if interior_kind == "closet":
		return "Thanatos Closet"
	if interior_kind == "thanatoshall":
		return "Thanatos's Hall"
	if interior_kind == "graveyard":
		return "Old Graveyard"
	if interior_kind == "dojo":
		return "Dojo"
	if interior_kind == "ratking":
		return "Rat King's Lair"
	if interior_kind == "boneyard":
		return "The Boneyard"
	if interior_kind == "hellgate":
		return "Hell's Gate"
	if interior_kind == "labyrinth":
		return "The Labyrinth"
	match interior_kind:
		"rift": return "Brimstone Rift"
		"crucible": return "The Crucible"
		"citadel": return "Citadel of Dis"
		"throne": return "Throne of Dis"
		"ascent": return "The Ashen Stair"
		"breach": return "The Breach"
	var pal = get_palette()
	return "World %d — %s" % [world_level, pal.get("name", "")]

# ============================================
# DOJO LAYOUT
# The town's training hall: one open room, flat, fully lit, no loot, no
# spawns. Main places the four dummies (see Main._setup_dojo) on
# DOJO_DUMMY_CELLS — a square, enemy side west, ally side east — and the
# player enters through the south door (player_start).
# ============================================
# ============================================
# THE RAT KING'S LAIR (interior_kind "ratking", id "ratking_lair")
# A boss room off the sewer's central cistern: one round den, entered from the
# west. The king waits at the bottom (south) of the circle with three rats in
# front of him and two archers behind. Across the circle stands a cliff of
# high ground, with two more cliffs 45 degrees to either side; a rat nest
# sits at the base of each. The room is sealed until the king is dead (main
# places the exit then). Boss rules: the player's hand, buffs and debuffs
# carry in unchanged (see main._enter_interior).
# ============================================
const RK_SIZE := 31
const RK_CENTER := Vector2i(15, 15)
const RK_RADIUS := 13
const RK_CLIFF_HALF := 1  # 3x3 cliff tops

## The three cliffs as rects (set by the layout; elevated by _generate_elevation).
var rat_cliffs: Array = []
## The nests, left to right as seen from the door: cell, the cliff-top perch
## its archer climbs to, the share of the king's max health it heals, label.
var rat_nests: Array = []
## Where main stands the king and his guard.
var rat_king_placements: Dictionary = {}
## Set by main before initialize(): the boss rooms this character has
## already cleared (CharacterData.defeated_bosses). A cleared room opens
## with its exit in place; the door to it outside reads as cleared.
var cleared_bosses: Array = []

## Interiors that are boss rooms (cutscene fights behind a sealed door).
static func is_boss_room(id: String) -> bool:
	return id.begins_with("ratking") or id.begins_with("boneyard") or id.begins_with("hellgate") \
		or id.begins_with("labyrinth") or id.begins_with("thanatoshall") or is_guardian_room(id)

## Sealed rooms held by a band of guardians rather than one boss (Act 2's
## elite rooms, 2026-11-09): the room opens when the last of them falls.
## The Crucible (two ifrits), the Throne of Dis (the court of Dis) and the
## Breach (the wardens of the way up).
const GUARDIAN_ROOMS := ["crucible", "throne", "breach"]

static func is_guardian_room(id: String) -> bool:
	for key in GUARDIAN_ROOMS:
		if id.begins_with(key):
			return true
	return false

## The boss-room key of an interior id ("ratking_lair" -> "ratking").
static func boss_room_key(id: String) -> String:
	for key in ["ratking", "boneyard", "hellgate", "labyrinth", "thanatoshall"] + GUARDIAN_ROOMS:
		if id.begins_with(key):
			return key
	return ""

func is_boss_cleared() -> bool:
	return cleared_bosses.has(boss_room_key(interior_id))

func _generate_rat_king_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	rat_cliffs.clear()
	rat_nests.clear()
	rat_king_placements.clear()
	_carve_circle(RK_CENTER, RK_RADIUS)
	# The doorway from the west: the player's start tile and the one behind it.
	for x in range(1, player_start.x + 1):
		grid[x][RK_CENTER.y] = Tile.FLOOR
	rooms.append({"rect": _circle_rect(RK_CENTER, RK_RADIUS), "kind": "boss", "elev": 0})

	# Cliffs: straight across from the king (north), then 45 degrees to each
	# side of it. Each is the pack's own cliff: a 3-wide plateau whose SOUTH
	# row is a wall tile that _build_cliff_walls draws as the cliff face
	# (the undead/cave strip, fringe over base), with two raised, walkable
	# rows behind it — the high ground the nest's archer climbs onto from
	# the sides. Nothing is modelled: the face, the cap outline and the top
	# all come from the biome's sheets.
	var reach := RK_RADIUS - 2
	var cliff_centres := {
		"left": RK_CENTER + Vector2i(-roundi(reach * 0.7071), -roundi(reach * 0.7071)),
		"middle": RK_CENTER + Vector2i(0, -reach),
		"right": RK_CENTER + Vector2i(roundi(reach * 0.7071), -roundi(reach * 0.7071)),
	}
	for key in ["left", "middle", "right"]:
		var cc: Vector2i = cliff_centres[key]
		var rect := Rect2i(cc.x - RK_CLIFF_HALF, cc.y - RK_CLIFF_HALF, RK_CLIFF_HALF * 2 + 1, RK_CLIFF_HALF * 2 + 1)
		rat_cliffs.append(rect)
		for x in range(rect.position.x, rect.end.x):
			grid[x][rect.end.y - 1] = Tile.WALL  # the cliff face row
	# A nest at the foot of each cliff face: the left nest heals 20% of the
	# king's health, the middle 30%, the right 50%.
	rat_nests = []
	for entry in [["left", 0.20], ["middle", 0.30], ["right", 0.50]]:
		var cc: Vector2i = cliff_centres[entry[0]]
		# The archer rounds the cliff on the side nearer the room's centre
		# (the floor beside the top rows), then steps up onto the perch.
		var side := 1 if cc.x < RK_CENTER.x else -1
		if entry[0] == "middle":
			side = -1
		rat_nests.append({
			"cell": cc + Vector2i(0, RK_CLIFF_HALF + 1), "perch": cc,
			"approach": cc + Vector2i(side * (RK_CLIFF_HALF + 1), 0),
			"heal_pct": entry[1], "label": entry[0],
		})
	# The king at the bottom middle, three rats in front of him (toward the
	# door side of the room) and two archers behind him against the wall.
	var king := RK_CENTER + Vector2i(0, RK_RADIUS - 3)
	rat_king_placements = {
		"king": king,
		"rats": [king + Vector2i(-2, -2), king + Vector2i(0, -2), king + Vector2i(2, -2)],
		"archers": [king + Vector2i(-1, 2), king + Vector2i(1, 2)],
	}
	_enforce_border_walls()

func _build_rat_king_decorations() -> void:
	## The den is lit like the sewer it hangs off: torches on the walls.
	var pal = get_palette()
	var wall_edges: Array = []
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] == Tile.WALL:
				var fdir = _adjacent_floor_dir(x, z)
				if fdir != Vector2i.ZERO:
					wall_edges.append({"pos": Vector2i(x, z), "dir": fdir})
	# (Cliff faces inside the room are walls too — no torches on them.)
	var room_walls: Array = []
	for e in wall_edges:
		var inside := false
		for rect in rat_cliffs:
			if (rect as Rect2i).has_point(e["pos"]):
				inside = true
		if not inside:
			room_walls.append(e)
	_place_sewer_torches(room_walls, pal, 10, 6, 14)
	# The nests and the king's places stay clear of any scatter.
	for n in rat_nests:
		_reserve_area(n["cell"], 1)
	for cell in [rat_king_placements.get("king", Vector2i(-1, -1))] + rat_king_placements.get("rats", []) + rat_king_placements.get("archers", []):
		if cell is Vector2i and cell.x >= 0:
			_reserve_area(cell, 0)

func _place_boss_door(room_kind: String, where: String, target_id: String, room_key: String,
		display_name: String, tint: Color, glow_color: Color) -> void:
	## Inside an interior: the door into a boss room, standing in the room of
	## `room_kind` — on its far wall (away from the access shaft) or at its
	## east end. Shift opens it (_enter_interior with `target_id`).
	var room_rect: Rect2i = Rect2i()
	var found := false
	for room in rooms:
		if room["kind"] == room_kind:
			room_rect = room["rect"]
			found = true
			break
	if not found:
		return
	var above := room_rect.get_center().y < GRID_H / 2
	var door: Vector2i
	var against := Vector3.ZERO  # offset of the sprite toward the wall behind the tile
	if where == "east":
		door = Vector2i(room_rect.end.x - 1, room_rect.get_center().y)
		var guard := 0
		while not is_floor(door) and guard < 8:
			door.x -= 1
			guard += 1
		against = Vector3(0.6, 0, 0)
	else:
		door = Vector2i(room_rect.get_center().x, room_rect.position.y if above else room_rect.end.y - 1)
		against = Vector3(0, 0, -0.6 if above else 0.6)
	if not is_floor(door):
		return
	_build_boss_door_site(door, against, target_id, room_key, display_name, tint, glow_color)

## The door into a boss room on `door` (its sprite pushed `against` the wall
## behind the tile): the pack archway, tinted and lit, its name ("(cleared)"
## once the room is), and the Shift prompt.
func _build_boss_door_site(door: Vector2i, against: Vector3, target_id: String, room_key: String,
		display_name: String, tint: Color, glow_color: Color) -> void:
	_reserve_area(door, 1)

	var site_root = Node3D.new()
	site_root.name = "Site_%s" % target_id
	site_root.position = grid_manager.grid_to_world(door) + against + Vector3(0, get_elevation_world_y(door), 0)
	var portal := _make_prop_sprite("gate_small", 1.3)
	if portal:
		portal.modulate = tint
		site_root.add_child(portal)
		var glow = OmniLight3D.new()
		glow.light_color = glow_color
		glow.light_energy = 0.9
		glow.omni_range = 3.0
		glow.position = Vector3(0, 0.6, 0.4)
		site_root.add_child(glow)
	var label = Label3D.new()
	label.text = display_name + (" (cleared)" if cleared_bosses.has(room_key) else "")
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint
	label.position = Vector3(0, 2.0, 0)
	WorldText.crisp(label)
	site_root.add_child(label)
	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Enter"
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
		"grid_pos": door,
		"id": target_id,
		"kind": room_key,
		"display_name": display_name,
		"label_node": interact_label,
		"footprint": [],
	})

# ============================================
# THE BONEYARD (interior_kind "boneyard", id "boneyard")
# The Bone Dragon's graveyard, off the Old Graveyard's deepest crypt: one
# large walled square entered through an iron-dark stone gate on the west.
# Twelve gravestones stand in rows across it; a crypt door in the north-east
# corner is where the grave diggers come out. The room is sealed until the
# dragon is dead. (The Necromancer prelude — stopping him raising the dead,
# which is what leaves these twelve stones — is the designer's to specify;
# main stands the yard up in its post-prelude state. See STORY.md.)
# ============================================
const BY_SIZE := 29
const BY_FLOOR := Rect2i(3, 3, 23, 23)
# Twelve stones on a loose 4x3 lattice: the rows sit well apart (the yard is
# read top to bottom), the columns a little, and every stone is nudged off
# its lattice point so nothing lines up like a parade ground.
const BY_GRAVE_COLS := [7, 11, 16, 20]
const BY_GRAVE_ROWS := [6, 13, 20]

## The twelve gravestone cells, the dragon's cell, and the crypt-door cell
## (inside the north-east corner) the grave diggers emerge from.
var gravestone_cells: Array = []
var boneyard_dragon_cell: Vector2i = Vector2i(-1, -1)
var boneyard_crypt_cell: Vector2i = Vector2i(-1, -1)

func _generate_boneyard_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	gravestone_cells.clear()
	_carve_rect(BY_FLOOR)
	# The gateway on the west: the start tile and the one behind it.
	for x in range(1, player_start.x + 1):
		grid[x][player_start.y] = Tile.FLOOR
	rooms.append({"rect": BY_FLOOR, "kind": "boss", "elev": 0})
	boneyard_dragon_cell = Vector2i(BY_FLOOR.end.x - 3, BY_FLOOR.get_center().y)
	boneyard_crypt_cell = Vector2i(BY_FLOOR.end.x - 1, BY_FLOOR.position.y + 2)
	var inner := BY_FLOOR.grow(-1)
	for ri in range(BY_GRAVE_ROWS.size()):
		for ci in range(BY_GRAVE_COLS.size()):
			var base := Vector2i(BY_GRAVE_COLS[ci], BY_GRAVE_ROWS[ri])
			# A deterministic nudge: up to a tile sideways, up to two up or down.
			var dx := int(_tile_noise(ci, ri, 401) * 3.0) - 1
			var dz := int(_tile_noise(ci, ri, 409) * 5.0) - 2
			var cell := base + Vector2i(dx, dz)
			cell.x = clampi(cell.x, inner.position.x, inner.end.x - 1)
			cell.y = clampi(cell.y, inner.position.y, inner.end.y - 1)
			# Never on the player's line in from the gate, the dragon or the crypt door.
			if cell.y == player_start.y and cell.x <= player_start.x + 2:
				cell.y += 1
			if (cell - boneyard_dragon_cell).length() < 2.5 or (cell - boneyard_crypt_cell).length() < 2.5:
				cell = base
			gravestone_cells.append(cell)
	_enforce_border_walls()

func _build_boneyard_decorations() -> void:
	## Everything here is the undead land pack: the gate arch over the way
	## in, broken iron-dark posts along the walls like a fallen fence, dead
	## trees leaning in over them, a skull-mouth crypt door where the diggers
	## come out, and bones in the grass between the graves.
	for n_cell in gravestone_cells:
		_reserve_area(n_cell, 1)
	_reserve_area(boneyard_dragon_cell, 1)
	_reserve_area(boneyard_crypt_cell, 1)
	# The gate: the pack's stone arch straddling the doorway tile, a
	# colonnade piece to either side of it on the wall.
	var gate_cell := Vector2i(player_start.x - 1, player_start.y)
	var arch := _make_prop_sprite("undead_ruin", 1.7, 1)
	if arch:
		arch.position = grid_manager.grid_to_world(gate_cell) + Vector3(0, CameraView.SPRITE_LIFT, 0.5)
		_visuals_root.add_child(arch)
	for dz in [-1, 1]:
		var pillar := _make_prop_sprite("undead_ruin", 1.1, 0)
		if pillar:
			pillar.position = grid_manager.grid_to_world(gate_cell + Vector2i(0, dz)) + Vector3(0, CameraView.SPRITE_LIFT, 0.5)
			_visuals_root.add_child(pillar)
	# The crypt door in the north-east corner, on the wall above its cell.
	var crypt := _make_prop_sprite("undead_skull_door", 1.2)
	if crypt:
		crypt.position = grid_manager.grid_to_world(boneyard_crypt_cell + Vector2i(0, -1)) + Vector3(0, CameraView.SPRITE_LIFT, 0.6)
		_visuals_root.add_child(crypt)
	# Fallen fence posts and dead trees along the walls (never on the row
	# nearest the camera, where a tall sprite would stand over the ground).
	var posts := 0
	var trees := 0
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] != Tile.WALL or not _has_adjacent_floor(x, z):
				continue
			var pos := Vector2i(x, z)
			if pos == gate_cell or (pos - gate_cell).length() < 2.5 or _is_floor_at(x, z - 1):
				continue
			var n := _tile_noise(x, z, 311)
			var world := grid_manager.grid_to_world(pos) + Vector3(0, CameraView.SPRITE_LIFT, 0.3)
			if n < 0.55:
				var post := _make_prop_sprite("undead_ruin", 1.0, 2)
				if post:
					post.position = world
					_visuals_root.add_child(post)
					posts += 1
			elif n < 0.75:
				var tree := _make_prop_sprite("undead_tree", 1.0, int(n * 100) % 5)
				if tree:
					tree.position = world + Vector3(0, 0, -0.4)
					_visuals_root.add_child(tree)
					trees += 1
	# Bones and skulls in the grass between the graves.
	var bones := 0
	for x in range(BY_FLOOR.position.x, BY_FLOOR.end.x):
		for z in range(BY_FLOOR.position.y, BY_FLOOR.end.y):
			var pos := Vector2i(x, z)
			if _reserved.has(pos) or pos == player_start:
				continue
			var n := _tile_noise(x, z, 331)
			if n < 0.06:
				var k := int(_tile_noise(x, z, 337) * 11)
				var bone := _make_prop_sprite("undead_bones", 0.9, k)
				if bone:
					bone.position = grid_manager.grid_to_world(pos) + Vector3((_tile_noise(x, z, 341) - 0.5) * 0.4, CameraView.SPRITE_LIFT, (_tile_noise(x, z, 347) - 0.5) * 0.4)
					_visuals_root.add_child(bone)
					bones += 1
	print("[DUNGEON] Boneyard dressed: %d posts, %d dead trees, %d bone piles" % [posts, trees, bones])

# ============================================
# HELL'S GATE (interior_kind "hellgate", id "hellgate")
# Cerberus guarding Hell's Door, off the deepest cave of the first world:
# one long cavern hall entered from the west, the iron door (the cave
# pack's gate) set in the east wall with the hound before it, lava pools
# in the corners. The objective is the door, not the hound: break it and
# the way down opens (and the way back). Cerberus need not die.
# ============================================
const HG_SIZE := Vector2i(31, 21)
const HG_FLOOR := Rect2i(3, 3, 25, 15)

var hellgate_door_cell: Vector2i = Vector2i(-1, -1)
var hellgate_cerberus_cell: Vector2i = Vector2i(-1, -1)

func _generate_hellgate_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	_carve_rect(HG_FLOOR)
	for x in range(1, player_start.x + 1):
		grid[x][player_start.y] = Tile.FLOOR
	rooms.append({"rect": HG_FLOOR, "kind": "boss", "elev": 0})
	hellgate_door_cell = Vector2i(HG_FLOOR.end.x - 1, HG_FLOOR.get_center().y)
	hellgate_cerberus_cell = hellgate_door_cell + Vector2i(-3, 0)
	# Lava pools in the four corners of the hall.
	for corner in [Vector2i(HG_FLOOR.position.x, HG_FLOOR.position.y), Vector2i(HG_FLOOR.end.x - 3, HG_FLOOR.position.y),
			Vector2i(HG_FLOOR.position.x, HG_FLOOR.end.y - 3), Vector2i(HG_FLOOR.end.x - 3, HG_FLOOR.end.y - 3)]:
		_flag_water_rect(Rect2i(corner, Vector2i(3, 3)))
	_enforce_border_walls()

func _build_hellgate_decorations() -> void:
	## The cave pack's hell pieces: spires and red rock along the walls, the
	## door's own glow. (The door itself is a structure main stands up.)
	_reserve_area(hellgate_door_cell, 1)
	_reserve_area(hellgate_cerberus_cell, 1)
	var spires := 0
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] != Tile.WALL or not _has_adjacent_floor(x, z) or _is_floor_at(x, z - 1):
				continue
			var pos := Vector2i(x, z)
			if (pos - hellgate_door_cell).length() < 2.5 or (pos - player_start).length() < 2.5:
				continue
			var n := _tile_noise(x, z, 421)
			var world := grid_manager.grid_to_world(pos) + Vector3(0, CameraView.SPRITE_LIFT, 0.3)
			if n < 0.4:
				var spire := _make_prop_sprite("hell_spire", 1.0, int(n * 100))
				if spire:
					spire.position = world
					_visuals_root.add_child(spire)
					spires += 1
			elif n < 0.55:
				var rock := _make_prop_sprite("hell_rock", 0.9, int(n * 100))
				if rock:
					rock.position = world
					_visuals_root.add_child(rock)
					spires += 1
	# A hot glow spilling from the door.
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.35, 0.15)
	glow.light_energy = 1.4
	glow.omni_range = 6.0
	glow.position = grid_manager.grid_to_world(hellgate_door_cell) + Vector3(0, 0.8, 0)
	_visuals_root.add_child(glow)
	print("[DUNGEON] Hell's Gate dressed: %d spires and rocks" % spires)

## The way down, once the door is broken: a site standing where the door
## stood. Shift there descends (main._try_interact_site, kind "descend").
func _place_hell_descent() -> void:
	if get_site_by_id("descend") >= 0:
		return
	_place_exit_site(hellgate_door_cell, "descend", "descend", "Hell's Door", "[Shift] Descend", Vector3(0.8, 0, 0), Color(1.0, 0.45, 0.3))

# ============================================
# THE LABYRINTH (interior_kind "labyrinth", id "labyrinth")
# The Inflamed Minotaur's maze, off the deepest cave of the second world
# (Act 2, through Hell's Door): one walled square of two-wide passages
# around an open court at its heart, where the bull waits beside four pools
# of lava. The player enters from the west. Every 25 tempo the maze takes
# hold of the player (Lost in the Labyrinth — main runs the curse); the
# room is sealed until the Minotaur is dead. Built from the cave pack's
# rock, floor and lava like Hell's Gate above it.
# ============================================
const LB_CELLS := 12                     # coarse maze cells per side
const LB_SIZE := 1 + LB_CELLS * 3        # 37: border wall + (2 floor + 1 wall) per cell
const LB_COURT := Rect2i(13, 13, 12, 12) # the open court: coarse cells 4..7 both ways
const LB_ENTRY_Z := 17                   # the entry passage's row (inside coarse row 5)
const LB_LOOP_CHANCE := 0.14             # extra passages knocked through so the maze has loops

var labyrinth_minotaur_cell: Vector2i = Vector2i(-1, -1)

func _lb_is_court(cx: int, cz: int) -> bool:
	return cx >= 4 and cx <= 7 and cz >= 4 and cz <= 7

func _lb_carve_cell(cx: int, cz: int) -> void:
	_carve_rect(Rect2i(1 + cx * 3, 1 + cz * 3, 2, 2))

func _lb_open_wall(ax: int, az: int, bx: int, bz: int) -> void:
	## Knock through the wall between two neighbouring coarse cells.
	if ax == bx:
		var wz: int = 3 + 3 * mini(az, bz)
		for x in range(1 + ax * 3, 3 + ax * 3):
			grid[x][wz] = Tile.FLOOR
	else:
		var wx: int = 3 + 3 * mini(ax, bx)
		for z in range(1 + az * 3, 3 + az * 3):
			grid[wx][z] = Tile.FLOOR

func _generate_labyrinth_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	# The court first: one open square (the inner walls go with it).
	_carve_rect(LB_COURT)
	rooms.append({"rect": LB_COURT, "kind": "boss", "elev": 0})
	labyrinth_minotaur_cell = LB_COURT.get_center()
	# Lava in the court's four corners.
	for corner in [LB_COURT.position, Vector2i(LB_COURT.end.x - 2, LB_COURT.position.y),
			Vector2i(LB_COURT.position.x, LB_COURT.end.y - 2), Vector2i(LB_COURT.end.x - 2, LB_COURT.end.y - 2)]:
		_flag_water_rect(Rect2i(corner, Vector2i(2, 2)))

	# The passages: a recursive backtracker over the coarse cells outside the
	# court (deterministic — _rng is seeded by the layout seed).
	var visited := {}
	var start := Vector2i(0, 5)  # the entry cell, west edge, middle row
	var stack: Array = [start]
	visited[start] = true
	_lb_carve_cell(start.x, start.y)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var options: Array = []
		for d in dirs:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= LB_CELLS or nxt.y >= LB_CELLS:
				continue
			if _lb_is_court(nxt.x, nxt.y) or visited.has(nxt):
				continue
			options.append(nxt)
		if options.is_empty():
			stack.pop_back()
			continue
		var pick: Vector2i = options[_rng.randi() % options.size()]
		visited[pick] = true
		_lb_carve_cell(pick.x, pick.y)
		_lb_open_wall(cur.x, cur.y, pick.x, pick.y)
		stack.append(pick)

	# Loops, so a wrong turn is a detour rather than a dead end to walk back.
	for cx in range(LB_CELLS):
		for cz in range(LB_CELLS):
			if _lb_is_court(cx, cz):
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = Vector2i(cx, cz) + d
				if nb.x >= LB_CELLS or nb.y >= LB_CELLS or _lb_is_court(nb.x, nb.y):
					continue
				if _rng.randf() < LB_LOOP_CHANCE:
					_lb_open_wall(cx, cz, nb.x, nb.y)

	# Two ways into the court on each side (the middle cells of each face).
	for i in [5, 6]:
		_lb_open_wall(3, i, 4, i)   # west face
		_lb_open_wall(7, i, 8, i)   # east face
		_lb_open_wall(i, 3, i, 4)   # north face
		_lb_open_wall(i, 7, i, 8)   # south face
	_enforce_border_walls()

func _build_labyrinth_decorations() -> void:
	## The cave pack's hell pieces, sparse along the passage walls so the
	## maze reads as rock; the court lit by its lava.
	_reserve_area(labyrinth_minotaur_cell, 1)
	var props := 0
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] != Tile.WALL or not _has_adjacent_floor(x, z) or _is_floor_at(x, z - 1):
				continue
			var pos := Vector2i(x, z)
			if (pos - player_start).length() < 2.5:
				continue
			var n := _tile_noise(x, z, 733)
			var world := grid_manager.grid_to_world(pos) + Vector3(0, CameraView.SPRITE_LIFT, 0.3)
			if n < 0.1:
				var spire := _make_prop_sprite("hell_spire", 0.9, int(n * 100))
				if spire:
					spire.position = world
					_visuals_root.add_child(spire)
					props += 1
			elif n < 0.2:
				var rock := _make_prop_sprite("hell_rock", 0.85, int(n * 100))
				if rock:
					rock.position = world
					_visuals_root.add_child(rock)
					props += 1
	# The court glows from its lava.
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.4, 0.15)
	glow.light_energy = 1.2
	glow.omni_range = 9.0
	glow.position = grid_manager.grid_to_world(labyrinth_minotaur_cell) + Vector3(0, 1.0, 0)
	_visuals_root.add_child(glow)
	print("[DUNGEON] The Labyrinth dressed: %d spires and rocks" % props)

const DOJO_W := 18
const DOJO_H := 14
const DOJO_DUMMY_CELLS := {
	"enemy": [Vector2i(5, 4), Vector2i(5, 8)],
	"ally": [Vector2i(12, 4), Vector2i(12, 8)],
}

func _generate_dojo_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	var hall := Rect2i(1, 1, GRID_W - 2, GRID_H - 2)
	_carve_rect(hall)
	# "start" keeps the chest placer away (it only chests a start room on the
	# overworld) and the fountain placer skips the dojo entirely.
	rooms.append({"rect": hall, "kind": "start", "elev": 0})

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

	# Corridor from arena to exit room. Corridors carved from here on are
	# flagged as worn dirt roads (painted by _build_autotile_ground).
	_marking_trails = true
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
	_marking_trails = false

	# Roads stop at the field edges: clear trail flags inside every room so the
	# dirt reads as paths BETWEEN clearings, not carpets across them.
	for room in rooms:
		var rect: Rect2i = room["rect"]
		for x in range(maxi(0, rect.position.x), mini(rect.end.x, GRID_W)):
			for z in range(maxi(0, rect.position.y), mini(rect.end.y, GRID_H)):
				trail[x][z] = false
	if art_world() == 4:
		_place_lava_pools()  # Hell (the Underworld, World 2): molten pools in the open ground

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
	## flagged as water (rendered by _build_autotile_ground).
	var puddle_count = 6 + world_level * 2
	for _i in range(puddle_count):
		var cx = _rng.randi_range(3, GRID_W - 3)
		var cz = _rng.randi_range(3, GRID_H - 3)
		if grid[cx][cz] != Tile.FLOOR:
			continue
		# A puddle is a tight blob of 1–4 adjacent floor tiles.
		var blob: Array = [Vector2i(cx, cz)]
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			if _rng.randf() < 0.5:
				var p = Vector2i(cx + d.x, cz + d.y)
				if is_floor(p):
					blob.append(p)
		if hell_cave():
			# Hell's caves (World 2): the puddles are lava — blocked, like the
			# Underworld's pools — and only where they cut no tunnel.
			if blob.has(player_start) or not _try_block_footprint(blob):
				continue
		for p in blob:
			water[p.x][p.y] = true

## A cave of the Underworld (World 2, Hell): lava for puddles, glowing.
func hell_cave() -> bool:
	return interior_kind == "cave" and world_level == 2

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
				_mark_trail(current.x + dx, current.y + dz)

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
	obstacle_tiles.clear()
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

	# Trails fade out where they open into a clearing: clear the flags inside
	# each clearing circle (leave one rim tile so the path visibly enters).
	for room in rooms:
		if not room.has("center"):
			continue
		var c: Vector2i = room["center"]
		var r: int = maxi(0, int(room["radius"]) - 1)
		for x in range(maxi(1, c.x - r), mini(GRID_W - 1, c.x + r + 1)):
			for z in range(maxi(1, c.y - r), mini(GRID_H - 1, c.y + r + 1)):
				var dx = x - c.x
				var dz = z - c.y
				if dx * dx + dz * dz <= r * r:
					trail[x][z] = false

	# The drunkard walk doubles back over itself and smears fat dirt fields at
	# the bends. Mottle those blobs: tiles buried deep inside a dirt mass (all
	# 8 neighbors dirt) mostly revert to grass, so wide patches break into
	# trampled dirt-and-grass mix while 2-wide trail lines stay untouched.
	var interior: Array = []
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if not trail[x][z]:
				continue
			var buried = true
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if not trail[x + dx][z + dz]:
						buried = false
			if buried:
				interior.append(Vector2i(x, z))
	for pos in interior:
		if _tile_noise(pos.x, pos.y, 37) < 0.62:
			trail[pos.x][pos.y] = false

func _carve_trail(from: Vector2i, to: Vector2i) -> void:
	## A winding 2-wide dirt trail between two clearings (reuses the cave walk).
	## The carved tiles are flagged so the floor pass paints them as packed dirt.
	_marking_trails = true
	_carve_tunnel(from, to)
	_marking_trails = false

# ============================================
# MOUNTAIN PASS LAYOUT (Act 1, Mountains habitat; 2026-11-05)
# A snowy mountainside climbing up the screen to the north-east in terraces
# MOUNTAIN_TIER_STEP levels apart, with raised outcrops on the lower ones.
# Neighbouring terraces are a cliff apart: nothing walks up or down one
# (can_step). A south-facing drop is a rock face — a wall tile the pack's
# cliff face draws (cliff_face_tiles) that only climbers and fliers cross;
# other drops are the ledge's lip. The way up is a step: one tile halfway up
# a cliff (step_tiles, drawn as a trodden track), laid wherever the climb
# must go on (every ledge is reachable on foot) and a few more for choice.
# ============================================

const MOUNTAIN_TIERS := 4            # valley floor, two terraces, the summit
const MOUNTAIN_TIER_STEP := 2        # levels between terraces: a cliff (MAX_STEP + 1)
## Rock faces (wall tiles) under a south-facing drop: blocked to walkers,
## crossed by climbers and fliers (main gives them their own blocked list).
var cliff_face_tiles: Dictionary = {}
## Steps up a cliff: odd-level tiles between two terraces.
var step_tiles: Dictionary = {}

func _generate_mountain_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	obstacle_tiles.clear()
	trap_defs.clear()
	pit_tiles.clear()
	cliff_face_tiles.clear()
	step_tiles.clear()
	elevation.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(0)
		elevation.append(col)

	# The open mountainside: overlapping snowfields joined by trails, from the
	# trailhead (south-west, the valley floor) up toward the summit (north-east).
	var entry_c := player_start + Vector2i(1, -1)
	_carve_circle(entry_c, 4)
	rooms.append({"rect": _circle_rect(entry_c, 4), "kind": "start", "elev": 0, "center": entry_c, "radius": 4})
	var fields: Array = []
	var count := 16 + world_level * 2
	var prev := entry_c
	for i in range(count):
		# Spread west to east, any height: the terraces come from the slope.
		var fx := int(lerpf(10.0, GRID_W - 7.0, float(i) / float(count - 1))) + _rng.randi_range(-4, 4)
		var c := Vector2i(clampi(fx, 6, GRID_W - 7), _rng.randi_range(6, GRID_H - 7))
		var r := _rng.randi_range(4, 7)
		_carve_tunnel(prev, c)   # unmarked: the only trodden ground here is the steps
		_carve_circle(c, r)
		fields.append({"center": c, "radius": r})
		prev = c
	_smooth_cave_walls()
	_smooth_cave_walls()
	_enforce_border_walls()

	# The slope: higher to the north (up the screen) and a little to the east,
	# broken by coarse noise so the terrace lines wander; then a majority
	# pass so no ledge is a stray tile.
	var tier := []
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			var u := 0.72 * (1.0 - float(z) / GRID_H) + 0.28 * (float(x) / GRID_W) \
					+ 0.22 * (_tile_noise(x / 2, z / 2, 401) - 0.5)
			col.append(clampi(int(floor((u - 0.18) * MOUNTAIN_TIERS / 0.72)), 0, MOUNTAIN_TIERS - 1))
		tier.append(col)
	for _pass in range(3):
		var next := []
		for x in range(GRID_W):
			var col: Array = []
			for z in range(GRID_H):
				var votes := {}
				for dx in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						var nx: int = clampi(x + dx, 0, GRID_W - 1)
						var nz: int = clampi(z + dz, 0, GRID_H - 1)
						votes[tier[nx][nz]] = int(votes.get(tier[nx][nz], 0)) + 1
				var best: int = tier[x][z]
				for t in votes:
					if int(votes[t]) > int(votes[best]):
						best = t
				col.append(best)
			next.append(col)
		tier = next
	# The trailhead stays on the valley floor.
	for x in range(GRID_W):
		for z in range(GRID_H):
			if absi(x - entry_c.x) + absi(z - entry_c.y) <= 7:
				tier[x][z] = 0

	# Outcrops: knolls a terrace higher than the ground round them, a perch
	# for whatever keeps watch over the pass.
	var outcrops: Array = []
	for _o in range(4 + world_level):
		var oc := Vector2i(_rng.randi_range(12, GRID_W - 8), _rng.randi_range(6, GRID_H - 7))
		if grid[oc.x][oc.y] != Tile.FLOOR or tier[oc.x][oc.y] >= MOUNTAIN_TIERS - 1:
			continue
		if absi(oc.x - entry_c.x) + absi(oc.y - entry_c.y) < 12:
			continue
		var base_t: int = tier[oc.x][oc.y]
		var rad := _rng.randi_range(2, 3)
		for x in range(oc.x - rad, oc.x + rad + 1):
			for z in range(oc.y - rad, oc.y + rad + 1):
				if x < 1 or z < 1 or x >= GRID_W - 1 or z >= GRID_H - 1:
					continue
				if (x - oc.x) * (x - oc.x) + (z - oc.y) * (z - oc.y) <= rad * rad and tier[x][z] == base_t:
					tier[x][z] = base_t + 1
		outcrops.append({"center": oc, "radius": rad})

	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.FLOOR:
				elevation[x][z] = int(tier[x][z]) * MOUNTAIN_TIER_STEP

	# Rock faces: the floor tile under a south-facing drop of a cliff or more
	# becomes the cliff face (it stands a level under the ledge above, so a
	# climber goes up it one level a step like anyone climbing).
	for x in range(1, GRID_W - 1):
		for z in range(2, GRID_H - 1):
			if grid[x][z] != Tile.FLOOR or grid[x][z - 1] != Tile.FLOOR:
				continue
			if elevation[x][z - 1] - elevation[x][z] > MAX_STEP:
				grid[x][z] = Tile.WALL
				cliff_face_tiles[Vector2i(x, z)] = true
				elevation[x][z] = elevation[x][z - 1] - 1

	_mountain_connect(player_start)
	# A few more ways up, so the climb is a choice and not one path.
	for _extra in range(3 + world_level):
		var cands := _mountain_step_candidates({})
		if cands.is_empty():
			break
		_mountain_lay_step(cands[_rng.randi_range(0, cands.size() - 1)])

	_mountain_tidy_steps()

	# Rooms (for spawns, chests and fountains): every snowfield and outcrop,
	# its terrace taken from its centre; the highest the summit ("deep").
	var best_i := -1
	var best_e := -1
	for f in fields + outcrops:
		var c: Vector2i = f["center"]
		if grid[c.x][c.y] != Tile.FLOOR:
			continue
		var e: int = elevation[c.x][c.y]
		# A chest waits up on each outcrop (and the summit): the climb pays.
		var outcrop: bool = f in outcrops
		rooms.append({"rect": _circle_rect(c, int(f["radius"]) - (1 if outcrop else 0)), "kind": "treasure" if outcrop else "clearing",
			"elev": e, "center": c, "radius": f["radius"], "outcrop": outcrop})
		if e > best_e or (e == best_e and c.x > rooms[best_i]["center"].x):
			best_e = e
			best_i = rooms.size() - 1
	if best_i >= 0:
		rooms[best_i]["kind"] = "deep"

## Lay steps until every floor tile can be walked to from `start`; anything
## no step can reach (more than a cliff above everything round it) is rock.
func _mountain_connect(start: Vector2i) -> void:
	for _i in range(400):
		var seen := _mountain_reach(start)
		var cands := _mountain_step_candidates(seen)
		if cands.is_empty():
			break
		_mountain_lay_step(cands[_rng.randi_range(0, cands.size() - 1)])
	var seen := _mountain_reach(start)
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.FLOOR and not seen.has(Vector2i(x, z)):
				grid[x][z] = Tile.WALL

## Floor reachable on foot from `start` (can_step).
func _mountain_reach(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if seen.has(n) or n.x < 0 or n.y < 0 or n.x >= GRID_W or n.y >= GRID_H:
				continue
			if grid[n.x][n.y] != Tile.FLOOR or not can_step(cur, n):
				continue
			seen[n] = true
			queue.append(n)
	return seen

## Where a step would join two terraces a cliff apart: {tile, level} pairs.
## With `seen` (the reachable floor) only steps from it into new ground.
## A rock face between two terraces becomes a step; elsewhere the lower
## tile of a side or back drop rises to meet the ledge.
func _mountain_step_candidates(seen: Dictionary) -> Array:
	var out: Array = []
	var any := seen.is_empty()
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			var t := Vector2i(x, z)
			if cliff_face_tiles.has(t) and grid[x][z] == Tile.WALL:
				var below := Vector2i(x, z + 1)
				var above := Vector2i(x, z - 1)
				if grid[below.x][below.y] != Tile.FLOOR or grid[above.x][above.y] != Tile.FLOOR:
					continue
				if elevation[above.x][above.y] - elevation[below.x][below.y] != MOUNTAIN_TIER_STEP:
					continue
				if any or (seen.has(below) != seen.has(above)):
					out.append({"tile": t, "level": elevation[below.x][below.y] + 1})
				continue
			if grid[x][z] != Tile.FLOOR or step_tiles.has(t):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
				var n: Vector2i = t + d
				if grid[n.x][n.y] != Tile.FLOOR:
					continue
				if elevation[n.x][n.y] - elevation[x][z] != MOUNTAIN_TIER_STEP:
					continue
				if any or (seen.has(t) != seen.has(n)):
					out.append({"tile": t, "level": elevation[x][z] + 1})
	return out

## A step left joining nothing (the pocket below it turned out unreachable
## and became rock) is part of the ledge it sits on again.
func _mountain_tidy_steps() -> void:
	for t in step_tiles.keys():
		var e: int = elevation[t.x][t.y]
		var up := false
		var down := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if is_floor(n):
				up = up or elevation[n.x][n.y] == e + 1
				down = down or elevation[n.x][n.y] == e - 1
		if up and down:
			continue
		step_tiles.erase(t)
		elevation[t.x][t.y] = e + 1 if up else e - 1

func _mountain_lay_step(c: Dictionary) -> void:
	var t: Vector2i = c["tile"]
	grid[t.x][t.y] = Tile.FLOOR
	cliff_face_tiles.erase(t)
	elevation[t.x][t.y] = int(c["level"])
	step_tiles[t] = true

# ============================================
# ICE CAVES AND THE ICE TROLL LAIR (off the Mountain Pass; 2026-11-05)
# ============================================

## Cave mouths in the Mountain Pass's cliffs: an Ice Cave on a lower
## terrace, the Ice Troll Lair high up near the summit. Each stands on a
## ledge with rock directly behind it (north), so it opens out of the cliff.
func _place_mountain_caves() -> void:
	var cave := _mountain_cave_cell(MOUNTAIN_TIER_STEP, false)
	if cave.x >= 0:
		_place_door_site(cave, "icecave_0", "icecave", "Ice Cave", Color(0.75, 0.9, 1.0))
	var lair := _mountain_cave_cell(MOUNTAIN_TIER_STEP * 2, true)
	if lair.x >= 0:
		_place_door_site(lair, "trolllair_0", "trolllair", "Ice Troll Lair", Color(0.6, 0.85, 1.0))

## A floor tile at `min_level` or higher with rock behind it (north) and
## open ledge in front, clear of steps and spawns: the westmost (or with
## `east`, the eastmost) such tile.
func _mountain_cave_cell(min_level: int, east: bool) -> Vector2i:
	var best := Vector2i(-1, -1)
	for x in range(3, GRID_W - 3):
		for z in range(3, GRID_H - 3):
			var c := Vector2i(x, z)
			if not is_floor(c) or step_tiles.has(c) or _reserved.has(c):
				continue
			if elevation[x][z] < min_level or grid[x][z - 1] != Tile.WALL:
				continue
			var open := true
			for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 2)]:
				var n: Vector2i = c + d
				open = open and is_floor(n) and elevation[n.x][n.y] == elevation[x][z] and not step_tiles.has(n)
			if not open:
				continue
			if best.x < 0 or (x > best.x if east else x < best.x):
				best = c
	return best

## A door into another interior from inside this one (the Mountain Pass's
## caves): the pack's dark archway against the rock behind the tile, a
## frosty glow, its name. Shift beside it enters (`id`).
func _place_door_site(cell: Vector2i, id: String, kind: String, display_name: String, tint: Color) -> void:
	_reserve_area(cell, 1)
	var site_root = Node3D.new()
	site_root.name = "Site_%s" % id
	site_root.position = grid_manager.grid_to_world(cell) + Vector3(0, get_elevation_world_y(cell), -0.6)
	var mouth := _make_prop_sprite("gate_small", 1.3)
	if mouth:
		mouth.modulate = tint
		site_root.add_child(mouth)
	for side in [-1.0, 1.0]:
		var rock := _make_prop_sprite("wallrock_snow", 0.9, 0 if side < 0 else 1)
		if rock:
			rock.position = Vector3(side * 0.95, CameraView.SPRITE_LIFT, 0.15)
			site_root.add_child(rock)
	var glow = OmniLight3D.new()
	glow.light_color = tint
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.6, 0.4)
	site_root.add_child(glow)
	var label = Label3D.new()
	label.text = display_name
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint
	label.position = Vector3(0, 2.0, 0)
	WorldText.crisp(label)
	site_root.add_child(label)
	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Enter"
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
		"grid_pos": cell,
		"id": id,
		"kind": kind,
		"display_name": display_name,
		"label_node": interact_label,
		"footprint": [],
	})

## An Ice Cave's creatures: the Mountain Pass's roster underground — weregoats
## and sabertooths in the chambers, snow wraiths in the dark, an ice troll in
## the deepest chamber.
func _define_ice_cave_spawn_zones() -> void:
	var common := [Enemy.EnemyType.WEREGOAT, Enemy.EnemyType.SABERTOOTH, Enemy.EnemyType.SNOW_WRAITH,
		Enemy.EnemyType.SNOW_WRAITH]
	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue
		if kind != "deep" and _rng.randf() >= 0.7:
			continue
		var n := clampi(2 + rect.get_area() / 40, 2, 4)
		var points: Array = []
		var types: Array = []
		for _i in range(n):
			var cell := _pick_free_cell(rect, points)
			if cell.x < 0:
				continue
			points.append(cell)
			types.append(common[_rng.randi_range(0, common.size() - 1)])
		if points.is_empty():
			continue
		if kind == "deep":
			types[0] = Enemy.EnemyType.ICE_TROLL
		spawn_zones.append({"trigger_rect": rect.grow(1), "spawn_points": points, "enemy_types": types, "spawned": false})
	for z in spawn_zones:
		for p in z["spawn_points"]:
			_reserved[p] = true
	print("[DUNGEON] Defined %d ice cave spawn zones" % spawn_zones.size())

# The Ice Troll Lair (designer, 2026-11-05: "an Ice troll lair that has 5
# ice trolls in it and a few trash enemies ... a legendary chest ... gold
# laying around ... all the gold and treasure chest enclosed by ice
# stalactites with a small one square entrance"; then: "in the corner of
# the room is the loot enclosed with one opening, so the player can't dance
# around collecting stuff, they have to walk into the enclosed area"). A
# short tunnel from the door opens on the den, one big frozen room holding
# the trolls; in its north-east corner the vault, walled by the room's rock
# and by high mountains on the other two (mountain_wall_tiles; designer,
# 2026-11-05: "instead of icicles ... high mountains the player CANNOT blink
# through or walk on top of") with a single gap facing the room. No one
# walks the mountains (walls, climbers too: the climbing stat crosses only
# the Mountain Pass's cliff faces — a later boots quest, Olorin's advice,
# would let climbers in), and no blink crosses them (blink_clear).
const TL_SIZE := Vector2i(40, 28)
const TL_ROOM := Rect2i(8, 3, 28, 22)     # the den: x 8..35, z 3..24
const TL_VAULT := Rect2i(29, 3, 7, 6)     # the vault's floor, in the den's north-east corner
## The high mountains walling the vault in (walls: the cave's rock under
## the winter pack's snowy stone piles, heaped high). No blink crosses them.
var mountain_wall_tiles: Dictionary = {}
var troll_vault_entrance := Vector2i(-1, -1)
var troll_vault_chest_cell := Vector2i(-1, -1)
## Gold lying on the ground: [{cell, amount, key, node}]; walked onto, it is
## taken (take_gold_pile) and remembered (its key in the world state).
var gold_piles: Array = []

func _generate_troll_lair_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	mountain_wall_tiles.clear()
	var mid := TL_SIZE.y / 2
	# The tunnel in from the door.
	_carve_rect(Rect2i(1, mid - 1, TL_ROOM.position.x, 3))
	rooms.append({"rect": Rect2i(1, mid - 1, 6, 3), "kind": "start", "elev": 0})
	# The trolls' den: one big frozen room. Its west and south sides are
	# broken up so it reads as a cavern; the vault's corner stays square.
	_carve_rect(TL_ROOM)
	for c in [Vector2i(TL_ROOM.position.x, TL_ROOM.position.y + 4), Vector2i(TL_ROOM.position.x + 6, TL_ROOM.end.y - 1),
			Vector2i(TL_ROOM.position.x, TL_ROOM.end.y - 5), Vector2i(TL_ROOM.position.x + 16, TL_ROOM.end.y)]:
		_carve_circle(c, 2)
	rooms.append({"rect": TL_ROOM, "kind": "lair", "elev": 0, "center": TL_ROOM.get_center()})
	# The vault in the room's north-east corner: the room's own rock on its
	# north and east, ice spikes on its west and south, and one gap in the
	# south side, facing the trolls.
	var ring := TL_VAULT.grow(1)
	for x in range(ring.position.x, ring.end.x):
		for z in range(ring.position.y, ring.end.y):
			var c := Vector2i(x, z)
			if TL_VAULT.has_point(c) or grid[x][z] != Tile.FLOOR:
				continue
			grid[x][z] = Tile.WALL
			mountain_wall_tiles[c] = true
	troll_vault_entrance = Vector2i(TL_VAULT.position.x + TL_VAULT.size.x / 2, TL_VAULT.end.y)
	grid[troll_vault_entrance.x][troll_vault_entrance.y] = Tile.FLOOR
	mountain_wall_tiles.erase(troll_vault_entrance)
	troll_vault_chest_cell = Vector2i(TL_VAULT.end.x - 1, TL_VAULT.position.y)   # tucked in the corner
	rooms.append({"rect": TL_VAULT, "kind": "vault", "elev": 0})
	_enforce_border_walls()

## The hoard: gold heaped about the vault floor round the chest (not in the
## gap's mouth, so the way in stays clear).
func _place_troll_hoard() -> void:
	var cells: Array = []
	for x in range(TL_VAULT.position.x, TL_VAULT.end.x):
		for z in range(TL_VAULT.position.y, TL_VAULT.end.y):
			var c := Vector2i(x, z)
			if c == troll_vault_chest_cell or c == troll_vault_entrance + Vector2i(0, -1):
				continue
			if (x + 2 * z) % 4 == 0:
				cells.append(c)
	var k := 0
	for c in cells:
		_place_gold_pile(c, 40 + ((c.x * 7 + c.y * 13) % 5) * 15 + world_level * 10, k)
		k += 1
	# The cave's dressing keeps out of the vault and off the ground round its
	# ring: the hoard's floor, and the gap plain to see from the den.
	var clear := TL_VAULT.grow(2)
	for x in range(clear.position.x, clear.end.x):
		for z in range(clear.position.y, clear.end.y):
			_reserved[Vector2i(x, z)] = true

func _gold_key(index: int) -> String:
	return "world_%d_%s_gold_%d" % [world_level, interior_id, index]

func _place_gold_pile(cell: Vector2i, amount: int, index: int) -> void:
	var key := _gold_key(index)
	if _opened_chests_ref.get(key, false):
		return   # taken on an earlier visit
	var sprite := _make_prop_sprite("treasure_gold", 1.0, index)
	if sprite == null:
		return
	var root := Node3D.new()
	root.name = "GoldPile_%d" % index
	root.position = grid_manager.grid_to_world(cell) + Vector3(0, get_elevation_world_y(cell), 0)
	root.add_child(sprite)
	_visuals_root.add_child(root)
	_reserve_area(cell, 0)
	gold_piles.append({"cell": cell, "amount": amount, "key": key, "node": root})

## Take the gold lying on `cell`: its amount (0 when there is none); it is
## gone for good (remembered in the world state).
func take_gold_pile(cell: Vector2i) -> int:
	for i in range(gold_piles.size()):
		var g: Dictionary = gold_piles[i]
		if g["cell"] != cell:
			continue
		_opened_chests_ref[g["key"]] = true
		if is_instance_valid(g["node"]):
			g["node"].queue_free()
		gold_piles.remove_at(i)
		prompts_changed.emit()
		return int(g["amount"])
	return 0

## The vault's mountains: on each tile of the cave's rock (drawn by the
## cliff walls) a great snowy stone pile of the winter pack, heaped well
## above a hero's head so the ring reads as peaks, not a fence.
func _build_troll_vault_mountains() -> void:
	var k := 0
	for c in mountain_wall_tiles:
		# The two peaks either side of the gap are smaller and lean away from
		# it, so the one way in shows as a pass between them.
		var side: int = c.x - troll_vault_entrance.x if c.y == troll_vault_entrance.y else 0
		var flank := absi(side) == 1
		var sc: float = 1.0 if flank else 1.6 + _tile_noise(c.x, c.y, 811) * 0.4
		var peak := _make_prop_sprite("winter_rock", sc, k % 3)
		if peak == null:
			continue
		peak.position = grid_manager.grid_to_world(c) + Vector3(0.3 * side if flank else 0.0, CameraView.SPRITE_LIFT, 0.3)
		_visuals_root.add_child(peak)
		k += 1

## May a blink (a teleport, a card's leap to a tile) go from `from` to `to`?
## Not onto a mountain, nor across one: the straight line between the two
## tiles' centres may not pass over any of the vault's mountains.
func blink_clear(from: Vector2i, to: Vector2i) -> bool:
	if mountain_wall_tiles.is_empty():
		return true
	if mountain_wall_tiles.has(to):
		return false
	var a := Vector2(from.x + 0.5, from.y + 0.5)
	var b := Vector2(to.x + 0.5, to.y + 0.5)
	var steps := int(ceil(a.distance_to(b) * 4.0))
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		if mountain_wall_tiles.has(Vector2i(int(floor(p.x)), int(floor(p.y)))):
			return false
	return true

func _define_troll_lair_spawn_zones() -> void:
	var door := troll_vault_entrance
	var r := TL_ROOM
	# Five ice trolls in the den: two either side of the vault's gap, three
	# spread through the room; four snow wraiths round its edges. All wake as
	# one when the hero steps out of the tunnel into the den.
	var want: Array = [
		[door + Vector2i(-2, 2), Enemy.EnemyType.ICE_TROLL],
		[door + Vector2i(2, 2), Enemy.EnemyType.ICE_TROLL],
		[Vector2i(r.position.x + 8, r.position.y + 5), Enemy.EnemyType.ICE_TROLL],
		[Vector2i(r.position.x + 9, r.end.y - 5), Enemy.EnemyType.ICE_TROLL],
		[Vector2i(r.position.x + 17, r.get_center().y + 2), Enemy.EnemyType.ICE_TROLL],
		[Vector2i(r.position.x + 3, r.position.y + 2), Enemy.EnemyType.SNOW_WRAITH],
		[Vector2i(r.position.x + 3, r.end.y - 3), Enemy.EnemyType.SNOW_WRAITH],
		[Vector2i(r.end.x - 3, r.end.y - 3), Enemy.EnemyType.SNOW_WRAITH],
		[Vector2i(r.position.x + 15, r.position.y + 1), Enemy.EnemyType.SNOW_WRAITH],
	]
	var points: Array = []
	var types: Array = []
	for w in want:
		var c := _nearest_free_floor(w[0], points)
		if c.x < 0:
			continue
		points.append(c)
		types.append(w[1])
	spawn_zones.append({"trigger_rect": r.grow(1), "spawn_points": points,
		"enemy_types": types, "spawned": false})
	for p in points:
		_reserved[p] = true

## The floor tile nearest `c` (spiralling out) that is not reserved, nor in
## `avoid`, nor in the vault.
func _nearest_free_floor(c: Vector2i, avoid: Array) -> Vector2i:
	for r in range(0, 5):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var n := c + Vector2i(dx, dz)
				if is_floor(n) and not _reserved.has(n) and not (n in avoid) and not TL_VAULT.grow(1).has_point(n):
					return n
	return Vector2i(-1, -1)

# ============================================
# THANATOS CLOSET AND THANATOS'S HALL (the Underworld; designer, 2026-11-05:
# "a cave or some sort of underground area that utilizes the undead land
# pixel art ... called Thanatos Closet ... the player will adventure around
# and eventually fight Thanatos")
# The Closet: crypt warrens under the Underworld (the cave's chambers and
# tunnels) in the undead land art — barrow earth, its rock, its green bog
# for puddles, headstones, ruined pillars and skull doors along the walls,
# bones and skulls underfoot. Specters drift through it, mind eaters and
# demons lurk in its chambers; its deepest crypt opens on Thanatos's Hall,
# the boss room (sealed until he falls), where he waits on his dais between
# rows of pillars.
# ============================================

## The Underworld's far reaches (World 2): the Closet's way down, in the
## free field room farthest from the start (picked without the layout's
## dice). Its footprint is a raised block of the land, the skull door in it.
func _place_closet_site(candidates: Array) -> void:
	if world_level != 2 or interior_kind != "" or candidates.is_empty():
		return
	var pick := -1
	var best := -1
	for room_idx in candidates:
		var c: Vector2i = rooms[room_idx]["rect"].get_center()
		var d := absi(c.x - player_start.x) + absi(c.y - player_start.y)
		if d > best:
			best = d
			pick = room_idx
	var rect: Rect2i = rooms[pick]["rect"]
	var fp_w := 3
	var fp_d := 3
	var fx = clampi(rect.get_center().x - fp_w / 2, rect.position.x + 1, rect.end.x - fp_w - 1)
	var fz = rect.position.y + 1
	var footprint: Array = []
	for x in range(fx, fx + fp_w):
		for z in range(fz, fz + fp_d):
			footprint.append(Vector2i(x, z))
	var entrance = Vector2i(fx + fp_w / 2, fz + fp_d)
	if not is_floor(entrance) or not _try_block_footprint(footprint):
		return
	candidates.erase(pick)
	rooms[pick]["kind"] = "site"
	_create_site("closet", "closet_0", "Thanatos Closet", footprint, entrance, fx, fz, fp_w, fp_d)

func _build_closet_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	## The undead land pack on the burning ground: its skull-mouthed door in
	## the block's face, ruined pillars either side, a dead tree behind.
	var door := _make_prop_sprite("undead_skull_door", 1.4)
	if door:
		door.position = Vector3(0, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.35)
		root.add_child(door)
	for side in [-1.0, 1.0]:
		var pillar := _make_prop_sprite("undead_ruin", 1.1, 0)
		if pillar:
			pillar.position = Vector3(side * fp_w * 0.38, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.5)
			root.add_child(pillar)
	var tree := _make_prop_sprite("undead_tree", 1.0, 2)
	if tree:
		tree.position = Vector3(0.2, CameraView.SPRITE_LIFT, -fp_d / 2.0 + 0.4)
		root.add_child(tree)
	var glow = OmniLight3D.new()
	glow.light_color = Color(0.45, 1.0, 0.6)
	glow.light_energy = 0.7
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.5, fp_d / 2.0)
	root.add_child(glow)

## The Closet's dwellers: specters drifting everywhere, mind eaters in the
## chambers, a demon or two in the deeper crypts and the deepest.
func _define_closet_spawn_zones() -> void:
	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue
		if kind != "deep" and _rng.randf() >= 0.8:
			continue
		var depth := float(rect.get_center().x) / float(GRID_W)
		var n := clampi(2 + rect.get_area() / 40, 2, 5)
		var points: Array = []
		var types: Array = []
		for _i in range(n):
			var cell := _pick_free_cell(rect, points)
			if cell.x < 0:
				continue
			points.append(cell)
			var roll := _rng.randf()
			if roll < 0.15 + depth * 0.15:
				types.append(Enemy.EnemyType.DEMON)
			elif roll < 0.5:
				types.append(Enemy.EnemyType.MIND_EATER)
			else:
				types.append(Enemy.EnemyType.SPECTER)
		if points.is_empty():
			continue
		if kind == "deep":
			types[0] = Enemy.EnemyType.DEMON
		spawn_zones.append({"trigger_rect": rect.grow(1), "spawn_points": points, "enemy_types": types, "spawned": false})
	for z in spawn_zones:
		for p in z["spawn_points"]:
			_reserved[p] = true
	print("[DUNGEON] Defined %d Thanatos Closet spawn zones" % spawn_zones.size())

## Along the crypt walls, the undead land pack: ruined pillars, skull doors
## set in the rock and the odd dead tree (never on the row nearest the
## camera, where a tall sprite would stand over the ground).
func _dress_crypt_walls() -> void:
	var placed := 0
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] != Tile.WALL or not _has_adjacent_floor(x, z) or _is_floor_at(x, z - 1):
				continue
			var n := _tile_noise(x, z, 911)
			var world := grid_manager.grid_to_world(Vector2i(x, z)) + Vector3(0, CameraView.SPRITE_LIFT, 0.3)
			var sprite: Sprite3D = null
			if n < 0.16:
				sprite = _make_prop_sprite("undead_ruin", 1.0, int(n * 100) % 3)
			elif n < 0.20:
				sprite = _make_prop_sprite("undead_skull_door", 1.0)
			elif n < 0.26:
				sprite = _make_prop_sprite("undead_tree", 0.9, int(n * 100) % 5)
			if sprite:
				sprite.position = world
				_visuals_root.add_child(sprite)
				placed += 1
	print("[DUNGEON] Crypt walls dressed: %d pieces" % placed)

const TH_SIZE := Vector2i(28, 19)
const TH_FLOOR := Rect2i(1, 1, 26, 17)
## Thanatos's dais cell (east end of the hall).
var thanatos_cell := Vector2i(-1, -1)
## The hall's pillars (wall tiles in two rows down its length).
var thanatos_pillars: Array = []

func _generate_thanatos_hall_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	thanatos_pillars.clear()
	_carve_rect(TH_FLOOR)
	rooms.append({"rect": TH_FLOOR, "kind": "boss", "elev": 0})
	var mid := TH_FLOOR.get_center().y
	# Two rows of pillars down the hall, cover from his bolts.
	for x in [7, 11, 15, 19]:
		for z in [mid - 4, mid + 4]:
			var c := Vector2i(x, z)
			grid[c.x][c.y] = Tile.WALL
			thanatos_pillars.append(c)
	thanatos_cell = Vector2i(TH_FLOOR.end.x - 3, mid)
	_enforce_border_walls()

func _build_thanatos_hall_decorations() -> void:
	## The undead land pack: a ruined pillar on every pillar tile, skull
	## doors and pillars along the walls, headstones and bones about the
	## floor, a dead tree either side of his dais.
	_reserve_area(thanatos_cell, 1)
	_reserve_area(player_start, 1)
	for c in thanatos_pillars:
		var pillar := _make_prop_sprite("undead_ruin", 1.2, 0)
		if pillar:
			pillar.position = grid_manager.grid_to_world(c) + Vector3(0, CameraView.SPRITE_LIFT, 0.3)
			_visuals_root.add_child(pillar)
	_dress_crypt_walls()
	for dz in [-2, 2]:
		var tree := _make_prop_sprite("undead_tree", 1.1, 1 if dz < 0 else 3)
		if tree:
			tree.position = grid_manager.grid_to_world(thanatos_cell + Vector2i(1, dz)) + Vector3(0, CameraView.SPRITE_LIFT, 0)
			_visuals_root.add_child(tree)
	var bones := 0
	for x in range(TH_FLOOR.position.x, TH_FLOOR.end.x):
		for z in range(TH_FLOOR.position.y, TH_FLOOR.end.y):
			var pos := Vector2i(x, z)
			if _reserved.has(pos) or not is_floor(pos):
				continue
			var n := _tile_noise(x, z, 931)
			var role := ""
			if n < 0.05:
				role = "undead_bones"
			elif n < 0.08:
				role = "undead_skulls"
			elif n < 0.10:
				role = "undead_grave"
			if role == "":
				continue
			var piece := _make_prop_sprite(role, 0.9, int(_tile_noise(x, z, 937) * 11))
			if piece:
				piece.position = grid_manager.grid_to_world(pos) + Vector3(0, CameraView.SPRITE_LIFT, 0)
				_visuals_root.add_child(piece)
				bones += 1
	# A pale green light over the dais.
	var light = OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.65)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position = grid_manager.grid_to_world(thanatos_cell) + Vector3(0, 1.2, 0)
	_visuals_root.add_child(light)
	print("[DUNGEON] Thanatos's Hall dressed: %d pillars, %d bones and graves" % [thanatos_pillars.size(), bones])

# ============================================
# ACT 2, PARTS 2-4 — THE BRIMSTONE RIFT, THE CITADEL OF DIS, THE ASHEN STAIR
# (the Underworld; designer, 2026-11-09: "places & enemies only" — the story
# round them stays [TBD], STORY.md section 4)
# Three places off the Underworld's surface, each with a sealed room held by
# guardians (GUARDIAN_ROOMS; main stands them up from guardian_placements and
# opens the room when the last of them falls):
#  - the Brimstone Rift (rift): a canyon of cursed earth split by a river of
#    lava no one wades, its banks and islands joined by the cursed land
#    pack's vein bridges; ash harpies overhead, magma spiders nesting on the
#    islands. Its far landing opens on the Crucible, where two ifrits keep
#    the fire round a lava lake.
#  - the Citadel of Dis (citadel): a demon fortress of courts and pillared
#    halls behind a gate; the court of Dis waits in the Throne of Dis.
#  - the Ashen Stair (ascent): the Mountain Pass's terraces (walked one level
#    a step) climbing the Underworld's far edge in the hell art; at the top
#    the Breach, the way up out of the Underworld, held by its wardens. Once
#    they fall it leads up to the next world, as Hell's Door leads down.
# No pack draws a fortress wall: the Citadel's walls are the Underworld's
# own veined cliff, lined with the designer's vein-wrapped ruins, skull
# fences and posts (the closest pieces); its braziers are the designer's
# hell fire.
# ============================================

## Where main stands the guardians of a sealed Act 2 room: [{type, cell}].
var guardian_placements: Array = []
## The Rift's (and the Crucible's) vein bridges: [{cells, horizontal}]. A
## bridge's cells are floor laid over the lava (still flagged lava, drawn
## under the bridge); bridge_cells holds them all.
var rift_bridges: Array = []
var bridge_cells: Dictionary = {}
const RIFT_BRIDGE_MAX := 5   # the longest run of lava a bridge spans

## The three ways in on the Underworld's surface (World 2): the Stair in
## the free field room farthest east (the far edge), the Citadel in the next
## farthest east, the Rift nearest two-fifths of the way across. Picked by position, without the layout's dice (as the
## Closet's), so the rest of the surface keeps its layout; a room whose way
## in fails (a lava pool, a cut path) passes to the next nearest.
func _place_act2_sites(candidates: Array) -> void:
	if world_level != 2 or interior_kind != "":
		return
	var specs := [
		["ascent", "ascent_0", "The Ashen Stair", 1.0],
		["citadel", "citadel_0", "Citadel of Dis", 1.0],
		["rift", "rift_0", "Brimstone Rift", 0.4],
	]
	for spec in specs:
		var want_x: float = float(GRID_W) * float(spec[3])
		var order: Array = candidates.duplicate()
		order.sort_custom(func(a, b):
			var da := absf(float(rooms[a]["rect"].get_center().x) - want_x)
			var db := absf(float(rooms[b]["rect"].get_center().x) - want_x)
			if da != db:
				return da < db
			return a < b)
		for room_idx in order:
			if _place_block_site(room_idx, spec[0], spec[1], spec[2]):
				candidates.erase(room_idx)
				break

## A 3x3 site footprint at the top of field room `room_idx`, its way in on
## the south side; false (nothing changed) when the ground there is not
## open or the block would cut the land in two.
func _place_block_site(room_idx: int, kind: String, id: String, display_name: String) -> bool:
	var rect: Rect2i = rooms[room_idx]["rect"]
	var fp_w := 3
	var fp_d := 3
	var fx = clampi(rect.get_center().x - fp_w / 2, rect.position.x + 1, rect.end.x - fp_w - 1)
	var fz = rect.position.y + 1
	var footprint: Array = []
	for x in range(fx, fx + fp_w):
		for z in range(fz, fz + fp_d):
			footprint.append(Vector2i(x, z))
			if not is_floor(Vector2i(x, z)):
				return false
	var entrance = Vector2i(fx + fp_w / 2, fz + fp_d)
	if not is_floor(entrance) or not _try_block_footprint(footprint):
		return false
	rooms[room_idx]["kind"] = "site"
	_create_site(kind, id, display_name, footprint, entrance, fx, fz, fp_w, fp_d)
	return true

## The way down into the Rift: the designer's volcanic cones heaped on the
## block, lava vents either side of the mouth, the pack's dark archway going
## down, a red glow from below.
func _build_rift_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	var back_z := -fp_d / 2.0 + 0.6
	for spec in [[-fp_w * 0.3, back_z, 0.75, 2], [0.1, back_z - 0.25, 0.9, 1], [fp_w * 0.32, back_z, 0.7, 3]]:
		var cone := _make_prop_sprite("hell_spire", spec[2], spec[3])
		if cone:
			cone.position = Vector3(spec[0], CameraView.SPRITE_LIFT, spec[1])
			root.add_child(cone)
	for side in [-1.0, 1.0]:
		var vent := _make_prop_sprite("hell_vent", 0.9, 0 if side < 0 else 2, CameraView.GROUND_COVER_LIFT)
		if vent:
			vent.position.x = side * fp_w * 0.36
			vent.position.z = fp_d / 2.0 - 0.35
			root.add_child(vent)
	var mouth := _make_prop_sprite("gate_small", 1.3)
	if mouth:
		mouth.modulate = Color(1.0, 0.8, 0.65)
		mouth.position = Vector3(0, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.2)
		root.add_child(mouth)
	var glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.15)
	glow.light_energy = 0.9
	glow.omni_range = 3.5
	glow.position = Vector3(0, 0.5, fp_d / 2.0)
	root.add_child(glow)

## The Citadel's gate: a skull fence along the block, the designer's horned
## idol for its gatehouse face over the way in, skull posts at its sides.
func _build_citadel_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	var fence := _make_prop_sprite("hell_fence", 0.8, 0)
	if fence:
		fence.position = Vector3(0, CameraView.SPRITE_LIFT, -fp_d / 2.0 + 0.7)
		root.add_child(fence)
	var idol := _make_prop_sprite("hell_idol", 0.95)
	if idol:
		idol.position = Vector3(0, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.05)
		root.add_child(idol)
	for side in [-1.0, 1.0]:
		var post := _make_prop_sprite("hell_post", 1.0, 0 if side < 0 else 1)
		if post:
			post.position = Vector3(side * (fp_w * 0.5 - 0.2), CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.15)
			root.add_child(post)
	var glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.35, 0.2)
	glow.light_energy = 0.8
	glow.omni_range = 3.5
	glow.position = Vector3(0, 0.5, fp_d / 2.0)
	root.add_child(glow)

## The foot of the Ashen Stair: horned crags heaped on the block (the
## designer's hell horns) and his great vein arch over the way up.
func _build_ascent_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	var back_z := -fp_d / 2.0 + 0.55
	for spec in [[-fp_w * 0.34, back_z, 1.1, 0], [0.05, back_z - 0.3, 1.2, 1], [fp_w * 0.35, back_z, 1.0, 11]]:
		var crag := _make_prop_sprite("hell_horn", spec[2], spec[3])
		if crag:
			crag.position = Vector3(spec[0], CameraView.SPRITE_LIFT, spec[1])
			root.add_child(crag)
	var arch := _make_prop_sprite("hell_arch", 1.15, 0)
	if arch:
		arch.position = Vector3(0, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.05)
		root.add_child(arch)
	var glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.55)
	glow.light_energy = 0.8
	glow.omni_range = 3.5
	glow.position = Vector3(0, 0.5, fp_d / 2.0)
	root.add_child(glow)

func _is_lava(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < GRID_W and p.y < GRID_H and grid[p.x][p.y] == Tile.WALL and water[p.x][p.y]

func _make_lava(p: Vector2i) -> void:
	grid[p.x][p.y] = Tile.WALL
	water[p.x][p.y] = true

## The floor tiles reachable from `start` (4-neighbours; the flat places).
func _floor_reach(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if not seen.has(n) and is_floor(n):
				seen[n] = true
				queue.append(n)
	return seen

## Steps on foot from `a` to `b` over the floor (a large number if none).
func _walk_distance(a: Vector2i, b: Vector2i) -> int:
	var dist := {a: 0}
	var queue: Array = [a]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == b:
			return int(dist[cur])
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if not dist.has(n) and is_floor(n):
				dist[n] = int(dist[cur]) + 1
				queue.append(n)
	return 1 << 20

# ---- The Brimstone Rift ----

func _generate_rift_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	rift_bridges.clear()
	bridge_cells.clear()
	var mid := GRID_H / 2
	var ph: Array = []
	for _i in range(6):
		ph.append(_rng.randf() * TAU)
	# The canyon floor between its two rims, which wander.
	var top: Array = []
	var bot: Array = []
	for x in range(GRID_W):
		top.append(clampi(4 + roundi(1.6 * sin(x * 0.19 + ph[0]) + 0.9 * sin(x * 0.53 + ph[1])), 2, 7))
		bot.append(clampi(GRID_H - 5 - roundi(1.6 * sin(x * 0.17 + ph[2]) + 0.9 * sin(x * 0.47 + ph[3])), GRID_H - 8, GRID_H - 3))
	for x in range(1, GRID_W - 1):
		for z in range(top[x], bot[x] + 1):
			grid[x][z] = Tile.FLOOR
	# Buttresses of rock jutting out from the rims.
	for _b in range(7):
		var bx := _rng.randi_range(12, GRID_W - 15)
		var bw := _rng.randi_range(2, 3)
		var depth := _rng.randi_range(2, 4)
		var north := _rng.randf() < 0.5
		for x in range(bx, bx + bw):
			for k in range(depth):
				var z: int = (int(top[x]) + k) if north else (int(bot[x]) - k)
				grid[x][z] = Tile.WALL
	# The way in (west) and the far landing (east): solid ground.
	var entry := Rect2i(1, mid - 4, 8, 9)
	var landing := Rect2i(GRID_W - 10, mid - 5, 9, 11)
	_carve_rect(entry)
	_carve_rect(landing)
	# The river: out of the north rim west of the middle, into the south rim
	# east of it, meandering; two stretches part round an island between two
	# arms, and where it runs widest a rock islet stands in it.
	var x0 := 11
	var x1 := GRID_W - 12
	var span := x1 - x0
	var splits: Array = []
	for f in [[0.2, 0.42], [0.58, 0.8]]:
		splits.append(Vector2i(x0 + int(span * f[0]), x0 + int(span * f[1])))
	var islets: Array = []
	var cs: Array = []
	for x in range(GRID_W):
		var t := clampf(float(x - x0) / float(span), 0.0, 1.0)
		cs.append(lerpf(float(top[x]) - 1.0, float(bot[x]) + 1.0, t) + 3.0 * sin(t * TAU * 1.2 + ph[4]))
	for x in range(x0, x1 + 1):
		var t := float(x - x0) / float(span)
		var c: float = cs[x]
		# Painted a column at a time: a steep stretch is painted taller so the
		# river keeps its width across the slope.
		var steep := sqrt(1.0 + pow((float(cs[x + 1]) - float(cs[x - 1])) * 0.5, 2.0))
		# Widest in the middle and near its end, where a rock islet stands in it.
		var swell := 1.6 * (exp(-pow((t - 0.5) / 0.06, 2.0)) + exp(-pow((t - 0.9) / 0.05, 2.0)))
		var hw := (2.0 + 0.8 * (0.5 + 0.5 * sin(x * 0.29 + ph[5])) + swell) * steep
		var split := Vector2i(-1, -1)
		for sp in splits:
			if x >= sp.x and x <= sp.y:
				split = sp
		if split.x >= 0:
			var u := float(x - split.x) / float(split.y - split.x)
			var d := 1.5 + 3.5 * sin(u * PI)
			for arm in [-1.0, 1.0]:
				_rift_lava_band(x, c + arm * d * steep, 1.3 * steep)
		else:
			_rift_lava_band(x, c, hw)
			if swell > 1.5 and (islets.is_empty() or x - islets[islets.size() - 1].x > 9):
				islets.append(Vector2i(x, roundi(c)))
	for p in islets:
		for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var q: Vector2i = p + d
			if _is_lava(q):
				grid[q.x][q.y] = Tile.FLOOR
				water[q.x][q.y] = false
	# Spurs of the rims pinch the banks down to narrow ledges along the lava.
	for _p in range(5):
		var px := _rng.randi_range(x0 + 2, x1 - 4)
		var north := _rng.randf() < 0.5
		for x in range(px, px + 3):
			var edge := -1   # the river's near bank row in this column
			if north:
				for z in range(int(top[x]), int(bot[x]) + 1):
					if _is_lava(Vector2i(x, z)):
						edge = z
						break
			else:
				for z in range(int(bot[x]), int(top[x]) - 1, -1):
					if _is_lava(Vector2i(x, z)):
						edge = z
						break
			if edge < 0:
				continue
			var stop: int = edge - 3 if north else edge + 3
			var z0: int = int(top[x]) if north else stop + 1
			var z1: int = stop if north else int(bot[x]) + 1
			for z in range(z0, z1):
				if grid[x][z] == Tile.FLOOR and not water[x][z]:
					grid[x][z] = Tile.WALL
	# Lava pools on the banks.
	var pools := 0
	for _i in range(40):
		if pools >= 3:
			break
		var pc := Vector2i(_rng.randi_range(12, GRID_W - 13), _rng.randi_range(4, GRID_H - 5))
		var r := _rng.randi_range(1, 2)
		var open := true
		for dx in range(-r - 2, r + 3):
			for dz in range(-r - 2, r + 3):
				var q := pc + Vector2i(dx, dz)
				if not is_floor(q) or is_water(q) or entry.grow(1).has_point(q) or landing.grow(1).has_point(q):
					open = false
		if not open:
			continue
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if dx * dx + dz * dz <= r * r + 1:
					_make_lava(pc + Vector2i(dx, dz))
		pools += 1
	# Specks of ground too small to stand on sink.
	var seen_all := {}
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			var c0 := Vector2i(x, z)
			if seen_all.has(c0) or not is_floor(c0):
				continue
			var comp := _floor_reach(c0)
			for q in comp:
				seen_all[q] = true
			if comp.size() < 6:
				for q in comp:
					_make_lava(q)
	_enforce_border_walls()
	_rift_connect()
	# Rooms: the way in, the banks and islands a stretch of the canyon at a
	# time, the far landing (the deepest: the Crucible's door).
	rooms.append({"rect": entry, "kind": "start", "elev": 0})
	var band := 9
	for bx in range(entry.end.x + 1, landing.position.x - 1, band):
		var bx1 := mini(bx + band, landing.position.x - 1)
		var seen_b := {}
		for x in range(bx, bx1):
			for z in range(1, GRID_H - 1):
				var c0 := Vector2i(x, z)
				if seen_b.has(c0) or not is_floor(c0) or bridge_cells.has(c0):
					continue
				var comp: Array = [c0]
				seen_b[c0] = true
				var head := 0
				while head < comp.size():
					var cur: Vector2i = comp[head]
					head += 1
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var n: Vector2i = cur + d
						if n.x >= bx and n.x < bx1 and not seen_b.has(n) and is_floor(n) and not bridge_cells.has(n):
							seen_b[n] = true
							comp.append(n)
				if comp.size() < 10:
					continue
				var lo := Vector2i(GRID_W, GRID_H)
				var hi := Vector2i(-1, -1)
				var isle := true
				for p in comp:
					lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
					hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var n: Vector2i = p + d
						if grid[n.x][n.y] == Tile.WALL and not water[n.x][n.y]:
							isle = false   # touches the canyon's rock: a bank
				rooms.append({"rect": Rect2i(lo, hi - lo + Vector2i.ONE), "kind": "chamber", "elev": 0,
					"isle": isle, "cells": comp})
	rooms.append({"rect": landing, "kind": "deep", "elev": 0})

## One column of the river: lava `hw` tiles either side of row `c` (the
## canyon's rock stays rock).
func _rift_lava_band(x: int, c: float, hw: float) -> void:
	for z in range(roundi(c - hw), roundi(c + hw) + 1):
		if z >= 1 and z < GRID_H - 1 and grid[x][z] == Tile.FLOOR:
			_make_lava(Vector2i(x, z))

## Bridge the lava until every bank and island can be walked to from the
## way in (the shortest crossing first); anything no bridge reaches sinks.
## Then a few more crossings between ground already joined where the walk
## round is long, so the way over is a choice.
func _rift_connect() -> void:
	for _guard in range(80):
		var seen := _floor_reach(player_start)
		var cands := _rift_bridge_candidates(seen, false)
		if cands.is_empty():
			break
		var best := RIFT_BRIDGE_MAX + 1
		for c in cands:
			best = mini(best, c["cells"].size())
		var pool: Array = []
		for c in cands:
			if c["cells"].size() == best:
				pool.append(c)
		_lay_rift_bridge(pool[_rng.randi_range(0, pool.size() - 1)])
	var reach := _floor_reach(player_start)
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.FLOOR and not reach.has(Vector2i(x, z)):
				_make_lava(Vector2i(x, z))
	var extra := _rift_bridge_candidates(reach, true)
	for i in range(extra.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = extra[i]
		extra[i] = extra[j]
		extra[j] = tmp
	var added := 0
	var tried := 0
	for c in extra:
		if added >= 3 or tried >= 80:
			break
		if c["cells"].size() < 2:
			continue
		var near := false
		for b in rift_bridges:
			if (b["cells"][0] - c["cells"][0]).length() < 7.0:
				near = true
		if near:
			continue
		tried += 1
		if _walk_distance(c["from"], c["to"]) < 22:
			continue
		_lay_rift_bridge(c)
		added += 1

## Straight runs of lava (1..RIFT_BRIDGE_MAX tiles, east-west or north-south)
## from reached ground to ground across them: into new ground, or with
## `joined`, between two pieces already joined.
func _rift_bridge_candidates(seen: Dictionary, joined: bool) -> Array:
	var out: Array = []
	for cell in seen:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var run: Array = []
			var n: Vector2i = cell + d
			while run.size() <= RIFT_BRIDGE_MAX and _is_lava(n):
				run.append(n)
				n += d
			if run.is_empty() or run.size() > RIFT_BRIDGE_MAX or not is_floor(n) or bridge_cells.has(n):
				continue
			if seen.has(n) != joined:
				continue
			out.append({"cells": run, "horizontal": d.y == 0, "from": cell, "to": n})
	return out

## One tile of lava between two pieces of ground becomes a neck of rock;
## longer runs a vein bridge laid over the lava.
func _lay_rift_bridge(c: Dictionary) -> void:
	var cells: Array = c["cells"]
	if cells.size() == 1:
		var p: Vector2i = cells[0]
		grid[p.x][p.y] = Tile.FLOOR
		water[p.x][p.y] = false
		return
	for p in cells:
		grid[p.x][p.y] = Tile.FLOOR   # still lava underneath (water stays flagged)
		bridge_cells[p] = true
	rift_bridges.append({"cells": cells, "horizontal": c["horizontal"]})

## The cursed land pack's red vein bridges (cursed_bridge_h / _v), each
## stretched to its span with its roots on both banks, laid low so whoever
## crosses walks over it.
func _lay_bridge_sprites() -> void:
	var k := 0
	for b in rift_bridges:
		var cells: Array = b["cells"]
		var horizontal: bool = b["horizontal"]
		var role := "cursed_bridge_h" if horizontal else "cursed_bridge_v"
		if not CraftpixProps.has(role):
			continue
		var v: Dictionary = CraftpixProps.PROPS[role]["variants"][k % CraftpixProps.PROPS[role]["variants"].size()]
		var along: float = float(v["w"]) if horizontal else float(v["h"])
		var sc: float = (float(cells.size()) + 1.4) * 32.0 / along
		var a: Vector2i = cells[0]
		var e: Vector2i = cells[cells.size() - 1]
		var sprite := _make_prop_sprite(role, sc, k, 0.08)
		if sprite == null:
			continue
		var tall: float = float(v["h"]) * sc / 32.0
		sprite.name = "Bridge_%d" % k
		sprite.position = Vector3((a.x + e.x) * 0.5 + 0.5, 0.08, (a.y + e.y) * 0.5 + 0.5 + tall * 0.5)
		_visuals_root.add_child(sprite)
		k += 1

## Lava's light: a low orange glow over every few lava tiles (as in the
## Burning Caves), and the designer's lava vents smoking on the ground
## beside it.
func _dress_lava() -> void:
	_place_lava_glow()
	var vents := 0
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			var c := Vector2i(x, z)
			if vents >= 24 or not is_floor(c) or is_water(c) or _reserved.has(c):
				continue
			var by_lava := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				by_lava = by_lava or _is_lava(c + d)
			if not by_lava or _tile_noise(x, z, 977) > 0.14:
				continue
			var vent := _make_prop_sprite("hell_vent", 0.8, int(_tile_noise(x, z, 983) * 11), CameraView.GROUND_COVER_LIFT)
			if vent:
				vent.position.x = x + 0.5
				vent.position.z = z + 0.6
				_visuals_root.add_child(vent)
				_reserved[c] = true
				vents += 1

func _build_rift_decorations() -> void:
	## The bridges and the lava's glow; the banks then take the open
	## ground's scatter in the cursed biome (_build_decorations).
	_lay_bridge_sprites()
	_dress_lava()

## The Rift's creatures (STORY.md 5.4, Underworld): succubi, demons and
## specters along the banks with ash harpies over them; magma spiders
## nesting on the islands; demons and harpies keeping the far landing, at
## the Crucible's door.
func _define_rift_spawn_zones() -> void:
	var bank := [Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.DEMON, Enemy.EnemyType.SPECTER,
		Enemy.EnemyType.ASH_HARPY, Enemy.EnemyType.ASH_HARPY, Enemy.EnemyType.MIND_EATER]
	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue
		var types: Array = []
		if kind == "deep":
			types = [Enemy.EnemyType.DEMON, Enemy.EnemyType.DEMON, Enemy.EnemyType.ASH_HARPY,
				Enemy.EnemyType.ASH_HARPY, Enemy.EnemyType.MAGMA_SPIDER]
		elif room.get("isle", false):
			types = [Enemy.EnemyType.MAGMA_SPIDER, Enemy.EnemyType.MAGMA_SPIDER]
			if room["cells"].size() >= 16:
				types.append(Enemy.EnemyType.MAGMA_SPIDER)
			if _rng.randf() < 0.5:
				types.append(Enemy.EnemyType.ASH_HARPY)
		else:
			if _rng.randf() >= 0.8:
				continue
			for _i in range(clampi(2 + room.get("cells", []).size() / 45, 2, 4)):
				types.append(bank[_rng.randi_range(0, bank.size() - 1)])
		var points: Array = []
		var kept: Array = []
		var cells: Array = room.get("cells", [])
		for t in types:
			var cell := Vector2i(-1, -1)
			if cells.is_empty():
				cell = _pick_free_cell(rect, points)
			else:
				for _try in range(24):
					var q: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
					if not _reserved.has(q) and not (q in points):
						cell = q
						break
			if cell.x < 0:
				continue
			points.append(cell)
			kept.append(t)
		if points.is_empty():
			continue
		spawn_zones.append({"trigger_rect": rect.grow(1), "spawn_points": points, "enemy_types": kept, "spawned": false})
	for z in spawn_zones:
		for p in z["spawn_points"]:
			_reserved[p] = true
	print("[DUNGEON] Defined %d Brimstone Rift spawn zones (%d bridges)" % [spawn_zones.size(), rift_bridges.size()])

# ---- The Crucible: two ifrits round a lava lake ----
const CR_SIZE := Vector2i(31, 23)
const CR_FLOOR := Rect2i(2, 2, 27, 19)   # x 2..28, z 2..20
var crucible_isle := Vector2i(-1, -1)

func _generate_crucible_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	rift_bridges.clear()
	bridge_cells.clear()
	guardian_placements.clear()
	_carve_rect(CR_FLOOR)
	for x in range(1, player_start.x + 1):
		grid[x][player_start.y] = Tile.FLOOR
	rooms.append({"rect": CR_FLOOR, "kind": "boss", "elev": 0})
	var c := CR_FLOOR.get_center()
	crucible_isle = c
	# The lake: an oval of lava in the middle of the floor, an island of rock
	# at its heart.
	for x in range(c.x - 5, c.x + 6):
		for z in range(c.y - 4, c.y + 5):
			var u := float(x - c.x) / 4.6
			var w := float(z - c.y) / 3.6
			if u * u + w * w <= 1.0:
				_make_lava(Vector2i(x, z))
	for x in range(c.x - 1, c.x + 2):
		for z in range(c.y - 1, c.y + 2):
			grid[x][z] = Tile.FLOOR
			water[x][z] = false
	# Two vein bridges onto the island, from the west and the east.
	for d in [Vector2i(-1, 0), Vector2i(1, 0)]:
		var run: Array = []
		var n: Vector2i = c + d * 2
		while _is_lava(n):
			run.append(n)
			n += d
		if run.size() >= 2 and is_floor(n):
			_lay_rift_bridge({"cells": run, "horizontal": true})
	# Lava in the four corners.
	for corner in [CR_FLOOR.position, Vector2i(CR_FLOOR.end.x - 2, CR_FLOOR.position.y),
			Vector2i(CR_FLOOR.position.x, CR_FLOOR.end.y - 2), CR_FLOOR.end - Vector2i(2, 2)]:
		for dx in range(2):
			for dz in range(2):
				_make_lava(corner + Vector2i(dx, dz))
	# The two ifrits, north and south of the lake.
	guardian_placements = [
		{"type": Enemy.EnemyType.IFRIT, "cell": Vector2i(c.x, CR_FLOOR.position.y + 2)},
		{"type": Enemy.EnemyType.IFRIT, "cell": Vector2i(c.x, CR_FLOOR.end.y - 3)},
	]
	_enforce_border_walls()

func _build_crucible_decorations() -> void:
	## The designer's volcanic cones and red rock along the walls, the
	## bridges, the lava's glow, and a hot light over the island.
	for g in guardian_placements:
		_reserve_area(g["cell"], 1)
	_reserve_area(crucible_isle, 1)
	_dress_hell_walls(0.35, 541)
	_lay_bridge_sprites()
	_dress_lava()
	_scatter_hell_bones(0.05, 547)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.4, 0.12)
	glow.light_energy = 1.5
	glow.omni_range = 7.0
	glow.position = grid_manager.grid_to_world(crucible_isle) + Vector3(0, 1.0, 0)
	_visuals_root.add_child(glow)

## Along the walls of a sealed hell room, the designer's volcanic cones and
## red rock (never on the row nearest the camera, where a tall sprite would
## stand over the ground), as at Hell's Gate. `share` of the wall edge.
func _dress_hell_walls(share: float, salt: int) -> void:
	var placed := 0
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] != Tile.WALL or water[x][z] or not _has_adjacent_floor(x, z) or _is_floor_at(x, z - 1):
				continue
			var pos := Vector2i(x, z)
			if (pos - player_start).length() < 2.5:
				continue
			var n := _tile_noise(x, z, salt)
			if n >= share:
				continue
			var role := "hell_spire" if n < share * 0.55 else "hell_rock"
			var sprite := _make_prop_sprite(role, 0.85 if role == "hell_spire" else 0.8, int(n * 100))
			if sprite:
				sprite.position = grid_manager.grid_to_world(pos) + Vector3(0, CameraView.SPRITE_LIFT, 0.3)
				_visuals_root.add_child(sprite)
				placed += 1
	print("[DUNGEON] %s dressed: %d spires and rocks on the walls" % [get_location_name(), placed])

# ---- The Citadel of Dis ----
## The hall's pillars (wall tiles), and where the braziers stand.
var citadel_pillars: Array = []

func _generate_citadel_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	citadel_pillars.clear()
	var mid := GRID_H / 2
	var hall_x0 := 20
	var hall_x1 := GRID_W - 21          # last column of the great hall
	var inner_x0 := hall_x1 + 3
	var wing_split := (hall_x0 + hall_x1) / 2 + _rng.randi_range(-1, 1)
	# The gatehouse, the outer court, the great hall, the inner court.
	var gate := Rect2i(1, mid - 2, 5, 5)
	var outer := Rect2i(6, 4, 12, GRID_H - 8)
	var hall := Rect2i(hall_x0, mid - 3, hall_x1 - hall_x0 + 1, 7)
	var inner := Rect2i(inner_x0, 4, GRID_W - 4 - inner_x0, GRID_H - 8)
	for r in [gate, outer, hall, inner]:
		_carve_rect(r)
	# The wings north and south of the hall: two rooms each, a court and a
	# hall, parted by a wall with a door in it.
	var wings: Array = []
	for north in [true, false]:
		var z0: int = 2 if north else mid + 6
		var z1: int = mid - 6 if north else GRID_H - 3
		var west := Rect2i(hall_x0, z0, wing_split - hall_x0, z1 - z0 + 1)
		var east := Rect2i(wing_split + 2, z0, hall_x1 - wing_split - 1, z1 - z0 + 1)
		_carve_rect(west)
		_carve_rect(east)
		# The door between them.
		var dz := _rng.randi_range(z0 + 1, z1 - 2)
		for x in range(wing_split, wing_split + 2):
			for k in range(2):
				grid[x][dz + k] = Tile.FLOOR
		# A door from the hall into each (through the two-thick wall).
		var wall_z0: int = mid - 5 if north else mid + 4
		for r in [west, east]:
			var dx := _rng.randi_range(r.position.x + 1, r.end.x - 3)
			for x in range(dx, dx + 2):
				for z in range(wall_z0, wall_z0 + 2):
					grid[x][z] = Tile.FLOOR
		# The west room opens on the outer court, the east one on the inner.
		var side_z := _rng.randi_range(maxi(z0, outer.position.y) + 1, mini(z1, outer.end.y - 1) - 2)
		for x in range(outer.end.x, hall_x0):
			for k in range(2):
				grid[x][side_z + k] = Tile.FLOOR
		var side_z2 := _rng.randi_range(maxi(z0, inner.position.y) + 1, mini(z1, inner.end.y - 1) - 2)
		for x in range(hall_x1 + 1, inner_x0):
			for k in range(2):
				grid[x][side_z2 + k] = Tile.FLOOR
		wings.append({"rect": west, "court": north})
		wings.append({"rect": east, "court": not north})
	# The great gates: outer court -> hall -> inner court, three wide.
	for x in range(outer.end.x, hall_x0):
		for z in range(mid - 1, mid + 2):
			grid[x][z] = Tile.FLOOR
	for x in range(hall_x1 + 1, inner_x0):
		for z in range(mid - 1, mid + 2):
			grid[x][z] = Tile.FLOOR
	# Two rows of pillars down the hall.
	for x in range(hall_x0 + 2, hall_x1 - 1, 4):
		for z in [mid - 2, mid + 2]:
			grid[x][z] = Tile.WALL
			citadel_pillars.append(Vector2i(x, z))
	# The paved way: the hall's floor and the road across the courts.
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] != Tile.FLOOR:
				continue
			if hall.has_point(Vector2i(x, z)) or (absi(z - mid) <= 1 and x < inner.end.x - 2):
				trail[x][z] = true
	for w in wings:
		if not w["court"]:
			var r: Rect2i = w["rect"]
			for x in range(r.position.x, r.end.x):
				for z in range(r.position.y, r.end.y):
					if grid[x][z] == Tile.FLOOR:
						trail[x][z] = true   # a roofed hall: paved like the great hall
	# Lava: two basins either side of the road in the outer court, and in
	# the inner court's four corners.
	for rows in [[mid - 6, mid - 5], [mid + 5, mid + 6]]:
		for x in range(outer.position.x + 4, outer.position.x + 7):
			for z in rows:
				_make_lava(Vector2i(x, z))
	for corner in [inner.position, Vector2i(inner.end.x - 2, inner.position.y),
			Vector2i(inner.position.x, inner.end.y - 2), inner.end - Vector2i(2, 2)]:
		for dx in range(2):
			for dz in range(2):
				_make_lava(corner + Vector2i(dx, dz))
	_enforce_border_walls()
	rooms.append({"rect": gate, "kind": "start", "elev": 0})
	rooms.append({"rect": outer, "kind": "chamber", "elev": 0, "court": true})
	rooms.append({"rect": hall, "kind": "room", "elev": 0, "court": false})
	for w in wings:
		rooms.append({"rect": w["rect"], "kind": "chamber" if w["court"] else "room", "elev": 0, "court": w["court"]})
	rooms.append({"rect": inner, "kind": "deep", "elev": 0, "court": true})

## The Citadel's dwellers: demons, succubi and specters in its courts with
## harpies wheeling over them; mind eaters, succubi and specters in its
## halls; and before the Throne's doors its gatekeepers — an ifrit, two
## demons and a mind eater.
func _define_citadel_spawn_zones() -> void:
	var court := [Enemy.EnemyType.DEMON, Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.SPECTER,
		Enemy.EnemyType.ASH_HARPY, Enemy.EnemyType.SUCCUBUS]
	var halls := [Enemy.EnemyType.MIND_EATER, Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.SPECTER,
		Enemy.EnemyType.DEMON]
	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue
		var types: Array = []
		if kind == "deep":
			types = [Enemy.EnemyType.IFRIT, Enemy.EnemyType.DEMON, Enemy.EnemyType.DEMON, Enemy.EnemyType.MIND_EATER]
		else:
			if _rng.randf() >= 0.85:
				continue
			var pool: Array = court if room.get("court", false) else halls
			for _i in range(clampi(2 + rect.get_area() / 40, 2, 5)):
				types.append(pool[_rng.randi_range(0, pool.size() - 1)])
		var points: Array = []
		var kept: Array = []
		for t in types:
			var cell := _pick_free_cell(rect, points)
			if cell.x < 0:
				continue
			points.append(cell)
			kept.append(t)
		if points.is_empty():
			continue
		spawn_zones.append({"trigger_rect": rect.grow(1), "spawn_points": points, "enemy_types": kept, "spawned": false})
	for z in spawn_zones:
		for p in z["spawn_points"]:
			_reserved[p] = true
	print("[DUNGEON] Defined %d Citadel of Dis spawn zones" % spawn_zones.size())

## A fortress room's walls (the Citadel and the Throne): along every wall
## edge that faces into a room from the north, east or west (never the row
## nearest the camera), the designer's vein-wrapped ruin blocks, skull
## fences and skull posts, spaced; a ruin block on every pillar.
func _dress_fortress_walls(pillars: Array, salt: int) -> void:
	var placed := 0
	for c in pillars:
		var block := _make_prop_sprite("cursed_ruin", 0.42, [2, 6, 7][(c.x + c.y) % 3])
		if block:
			block.position = grid_manager.grid_to_world(c) + Vector3(0, CameraView.SPRITE_LIFT, 0.35)
			_visuals_root.add_child(block)
			placed += 1
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] != Tile.WALL or water[x][z] or not _has_adjacent_floor(x, z) or _is_floor_at(x, z - 1):
				continue
			var pos := Vector2i(x, z)
			if pos in pillars or (pos - player_start).length() < 2.5:
				continue
			var n := _tile_noise(x, z, salt)
			var sprite: Sprite3D = null
			if n < 0.16:
				sprite = _make_prop_sprite("cursed_ruin", 0.45, [2, 6, 7, 3][int(n * 1000) % 4])
			elif n < 0.30:
				sprite = _make_prop_sprite("hell_fence", 0.6, int(n * 100) % 3)
			elif n < 0.36:
				sprite = _make_prop_sprite("hell_post", 0.9, int(n * 100) % 7)
			if sprite:
				sprite.position = grid_manager.grid_to_world(pos) + Vector3(0, CameraView.SPRITE_LIFT, 0.3)
				_visuals_root.add_child(sprite)
				placed += 1
	print("[DUNGEON] %s walls dressed: %d ruins, fences and posts" % [get_location_name(), placed])

## Braziers: the designer's hell fire on the floor tile in front of a wall,
## each with a real flickering light; `want` of them, spaced.
func _place_braziers(want: int, min_gap: int) -> void:
	var edges: Array = []
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			var c := Vector2i(x, z)
			if not is_floor(c) or is_water(c) or _reserved.has(c) or trail[x][z]:
				continue
			if grid[x][z - 1] == Tile.WALL and not water[x][z - 1]:
				edges.append({"pos": c})
	var made := 0
	for e in _spaced_sample(edges, want, min_gap):
		var c: Vector2i = e["pos"]
		var fire := _make_prop_sprite("hell_fire", 1.0)
		if fire == null:
			continue
		var root := Node3D.new()
		root.name = "Brazier_%d" % made
		root.position = grid_manager.grid_to_world(c) + Vector3(0, 0, -0.2)
		root.add_child(fire)
		var light := TorchFlicker.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.light_energy = 1.8
		light.omni_range = 5.5
		light.omni_attenuation = 2.0
		light.shadow_enabled = false
		light.position = Vector3(0, 0.6, 0.2)
		root.add_child(light)
		_visuals_root.add_child(root)
		_reserved[c] = true
		made += 1

## Bones and shards about a court's floor (never on the paved way).
func _scatter_hell_bones(share: float, salt: int) -> void:
	var items_bones: Array = []
	var items_shards: Array = []
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			var c := Vector2i(x, z)
			if not is_floor(c) or is_water(c) or _reserved.has(c) or trail[x][z]:
				continue
			var n := _tile_noise(x, z, salt)
			if n >= share:
				continue
			var p3 := Vector3(x + 0.5 + (_tile_noise(x, z, salt + 3) - 0.5) * 0.4, 0, z + 0.5 + (_tile_noise(x, z, salt + 7) - 0.5) * 0.4)
			if n < share * 0.7:
				items_bones.append({"pos": p3, "scale": 0.85 + _tile_noise(x, z, salt + 11) * 0.3, "color": Color.WHITE})
			else:
				items_shards.append({"pos": p3, "scale": 0.85, "color": Color.WHITE})
	_add_prop_decos(items_bones, "bones")
	_add_prop_decos(items_shards, "pebble")

func _build_citadel_decorations() -> void:
	## Its walls, braziers and lava; then the halls and the paved road are
	## kept clear and the courts take the open ground's scatter in the cursed
	## biome (_build_decorations): dead trees, eyes and bones in the yards.
	_dress_fortress_walls(citadel_pillars, 613)
	_place_braziers(14, 7)
	_dress_lava()
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.FLOOR and trail[x][z]:
				_reserved[Vector2i(x, z)] = true

# ---- The Throne of Dis ----
const TR_SIZE := Vector2i(35, 21)
const TR_FLOOR := Rect2i(2, 2, 31, 17)   # x 2..32, z 2..18
var throne_cell := Vector2i(-1, -1)
var throne_pillars: Array = []

func _generate_throne_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	throne_pillars.clear()
	guardian_placements.clear()
	_carve_rect(TR_FLOOR)
	var mid := TR_FLOOR.get_center().y
	for x in range(1, player_start.x + 1):
		grid[x][mid] = Tile.FLOOR
	rooms.append({"rect": TR_FLOOR, "kind": "boss", "elev": 0})
	# Lava gutters down both long walls, from the door to the dais.
	for x in range(TR_FLOOR.position.x + 4, TR_FLOOR.end.x - 7):
		for z in [TR_FLOOR.position.y, TR_FLOOR.position.y + 1, TR_FLOOR.end.y - 2, TR_FLOOR.end.y - 1]:
			_make_lava(Vector2i(x, z))
	# Two rows of pillars down the hall, a lane between each row and its gutter.
	for x in range(TR_FLOOR.position.x + 6, TR_FLOOR.end.x - 7, 4):
		for z in [mid - 5, mid + 5]:
			grid[x][z] = Tile.WALL
			throne_pillars.append(Vector2i(x, z))
	# The carpet up to the dais.
	for x in range(1, TR_FLOOR.end.x - 2):
		for z in range(mid - 1, mid + 2):
			if grid[x][z] == Tile.FLOOR:
				trail[x][z] = true
	throne_cell = Vector2i(TR_FLOOR.end.x - 6, mid)
	var e := TR_FLOOR.end.x
	# The court of Dis: an ifrit enthroned, two demons at the dais steps, two
	# succubi either side of the throne, two mind eaters watching from the
	# lanes by the gutters.
	guardian_placements = [
		{"type": Enemy.EnemyType.IFRIT, "cell": throne_cell},
		{"type": Enemy.EnemyType.DEMON, "cell": Vector2i(e - 9, mid - 2)},
		{"type": Enemy.EnemyType.DEMON, "cell": Vector2i(e - 9, mid + 2)},
		{"type": Enemy.EnemyType.SUCCUBUS, "cell": Vector2i(e - 5, mid - 4)},
		{"type": Enemy.EnemyType.SUCCUBUS, "cell": Vector2i(e - 5, mid + 4)},
		{"type": Enemy.EnemyType.MIND_EATER, "cell": Vector2i(e - 12, mid - 6)},
		{"type": Enemy.EnemyType.MIND_EATER, "cell": Vector2i(e - 12, mid + 6)},
	]
	_enforce_border_walls()

func _build_throne_decorations() -> void:
	## The designer's horned idol over the throne on the east wall, ruin
	## blocks for pillars, fences and posts along the walls, braziers, the
	## gutters' glow.
	for g in guardian_placements:
		_reserve_area(g["cell"], 0)
	_reserve_area(throne_cell, 1)
	# The idol on the dais behind the throne, against the east wall (north
	# of the enthroned ifrit's feet, so he stands before it).
	var idol := _make_prop_sprite("hell_idol", 1.0)
	if idol:
		idol.position = grid_manager.grid_to_world(Vector2i(TR_FLOOR.end.x - 2, throne_cell.y)) + Vector3(0, CameraView.SPRITE_LIFT, -0.35)
		_visuals_root.add_child(idol)
	for c in range(TR_FLOOR.end.x - 3, TR_FLOOR.end.x):
		_reserve_area(Vector2i(c, throne_cell.y), 1)
	_dress_fortress_walls(throne_pillars, 631)
	_place_braziers(8, 6)
	_dress_lava()
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.35, 0.2)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.position = grid_manager.grid_to_world(throne_cell) + Vector3(0, 1.2, 0)
	_visuals_root.add_child(light)

# ---- The Ashen Stair ----

## Lava on the Stair's terraces: a few pools, each kept inside one level and
## off the steps, and only where it cuts no one's way up (the walk from the
## foot reaches as much as before, less the pool).
func _place_ascent_lava() -> void:
	var before := _mountain_reach(player_start).size()
	var made := 0
	for _i in range(140):
		if made >= 4 + world_level:
			break
		var c := Vector2i(_rng.randi_range(8, GRID_W - 8), _rng.randi_range(5, GRID_H - 6))
		if (c - player_start).length() < 9.0 or not is_floor(c):
			continue
		var r := 2 if _i < 80 else 1   # round pools where a terrace has the room, small ones after
		var e: int = elevation[c.x][c.y]
		var ok := true
		for dx in range(-r - 1, r + 2):
			for dz in range(-r - 1, r + 2):
				var q := c + Vector2i(dx, dz)
				if not is_floor(q) or step_tiles.has(q) or elevation[q.x][q.y] != e:
					ok = false
		if not ok:
			continue
		var cells: Array = []
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if dx * dx + dz * dz <= r * r + (1 if r > 1 else 0):
					cells.append(c + Vector2i(dx, dz))
		for q in cells:
			_make_lava(q)
		var now := _mountain_reach(player_start).size()
		if now != before - cells.size():
			for q in cells:
				grid[q.x][q.y] = Tile.FLOOR
				water[q.x][q.y] = false
			continue
		before = now
		made += 1

## The Stair's terraces leave one-tile spurs of ledge that lead nowhere:
## each tile with a single way on (by the step rule) is rock, until none is
## left (the foot and the steps stay).
func _prune_dead_ends() -> void:
	for _pass in range(60):
		var gone: Array = []
		for x in range(1, GRID_W - 1):
			for z in range(1, GRID_H - 1):
				var c := Vector2i(x, z)
				if not is_floor(c) or c == player_start or step_tiles.has(c):
					continue
				var ways := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if is_floor(c + d) and can_step(c, c + d):
						ways += 1
				if ways <= 1:
					gone.append(c)
		if gone.is_empty():
			break
		for c in gone:
			grid[c.x][c.y] = Tile.WALL

## The door into the Breach: at the top of the Stair, on the highest ledge
## with rock (not lava) behind it and open ground in front — the eastmost
## such tile on the summit, or failing that a terrace lower.
func _place_breach_door() -> void:
	var cell := Vector2i(-1, -1)
	for lvl in [MOUNTAIN_TIER_STEP * (MOUNTAIN_TIERS - 1), MOUNTAIN_TIER_STEP * 2, MOUNTAIN_TIER_STEP]:
		for x in range(3, GRID_W - 3):
			for z in range(3, GRID_H - 3):
				var c := Vector2i(x, z)
				if not is_floor(c) or is_water(c) or step_tiles.has(c) or _reserved.has(c):
					continue
				if elevation[x][z] < lvl or grid[x][z - 1] != Tile.WALL or water[x][z - 1]:
					continue
				var open := true
				for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 2)]:
					var n: Vector2i = c + d
					open = open and is_floor(n) and not is_water(n) and elevation[n.x][n.y] == elevation[x][z] and not step_tiles.has(n)
				if open and (cell.x < 0 or x > cell.x):
					cell = c
		if cell.x >= 0:
			break
	if cell.x < 0:
		return
	breach_door_cell = cell
	_build_boss_door_site(cell, Vector3(0, 0, -0.6), "breach", "breach", "The Breach",
		Color(1.0, 0.92, 0.75), Color(1.0, 0.85, 0.55))

var breach_door_cell := Vector2i(-1, -1)

## The Stair's creatures: succubi, demons and specters on the low terraces;
## mind eaters, magma spiders and specters keeping the ledges and outcrops,
## casting down at whoever climbs (they never walk); ash harpies riding the
## heights (they fly over the cliffs). At the top, an ifrit and a harpy.
func _define_ascent_spawn_zones() -> void:
	var low := [Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.DEMON, Enemy.EnemyType.SPECTER, Enemy.EnemyType.SUCCUBUS]
	var perch := [Enemy.EnemyType.MIND_EATER, Enemy.EnemyType.MAGMA_SPIDER, Enemy.EnemyType.SPECTER]
	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue
		var high: bool = int(room["elev"]) >= MOUNTAIN_TIER_STEP or room.get("outcrop", false)
		if kind != "deep" and _rng.randf() >= (0.85 if high else 0.65):
			continue
		var n := clampi(2 + rect.get_area() / 45, 2, 4)
		var points: Array = []
		var types: Array = []
		for _i in range(n * 3):
			if points.size() >= n:
				break
			var cell := _pick_free_cell(rect, points)
			if cell.x < 0 or step_tiles.has(cell) or is_water(cell):
				continue
			points.append(cell)
			var e: int = elevation[cell.x][cell.y]
			if e >= MOUNTAIN_TIER_STEP and _rng.randf() < 0.25:
				types.append(Enemy.EnemyType.ASH_HARPY)
			elif e >= MOUNTAIN_TIER_STEP or room.get("outcrop", false):
				types.append(perch[_rng.randi_range(0, perch.size() - 1)])
			else:
				types.append(low[_rng.randi_range(0, low.size() - 1)])
		if points.is_empty():
			continue
		if kind == "deep":
			types[0] = Enemy.EnemyType.IFRIT
			if types.size() > 1:
				types[1] = Enemy.EnemyType.ASH_HARPY
		spawn_zones.append({"trigger_rect": rect.grow(2), "spawn_points": points, "enemy_types": types, "spawned": false})
	for z in spawn_zones:
		for p in z["spawn_points"]:
			_reserved[p] = true
	print("[DUNGEON] Defined %d Ashen Stair spawn zones" % spawn_zones.size())

# ---- The Breach: the way up ----
const BR_SIZE := Vector2i(31, 25)
const BR_FLOOR := Rect2i(2, 3, 27, 20)   # x 2..28, z 3..22
var breach_gate_cell := Vector2i(-1, -1)

func _generate_breach_layout() -> void:
	_init_grid_walls()
	rooms.clear()
	guardian_placements.clear()
	_carve_rect(BR_FLOOR)
	var cx := BR_FLOOR.get_center().x
	# The way in from the south (the top of the Stair).
	for z in range(player_start.y, GRID_H - 1):
		grid[cx][z] = Tile.FLOOR
	rooms.append({"rect": BR_FLOOR, "kind": "boss", "elev": 0})
	breach_gate_cell = Vector2i(cx, BR_FLOOR.position.y)
	# Two fissures of lava run in from the side walls toward the middle,
	# leaving a lane by each wall and a broad one up the centre.
	for t in range(9):
		var z := BR_FLOOR.position.y + 6 + t / 2
		for k in range(2):
			_make_lava(Vector2i(BR_FLOOR.position.x + 2 + t, z + k))
			_make_lava(Vector2i(BR_FLOOR.end.x - 3 - t, z + k))
	# Pools in the lower corners.
	for side in [0, 1]:
		var corner := Vector2i(BR_FLOOR.position.x if side == 0 else BR_FLOOR.end.x - 3, BR_FLOOR.end.y - 3)
		for dx in range(3):
			for dz in range(3):
				var inward: int = dx if side == 0 else 2 - dx   # rounded off on the side toward the room
				if inward + dz < 4:
					_make_lava(corner + Vector2i(dx, dz))
	# The wardens: two ifrits flanking the gate, two demons before them, a
	# mind eater at the threshold, a succubus, and two ash harpies overhead.
	var g := breach_gate_cell
	guardian_placements = [
		{"type": Enemy.EnemyType.IFRIT, "cell": g + Vector2i(-4, 2)},
		{"type": Enemy.EnemyType.IFRIT, "cell": g + Vector2i(4, 2)},
		{"type": Enemy.EnemyType.DEMON, "cell": g + Vector2i(-2, 5)},
		{"type": Enemy.EnemyType.DEMON, "cell": g + Vector2i(2, 5)},
		{"type": Enemy.EnemyType.MIND_EATER, "cell": g + Vector2i(0, 2)},
		{"type": Enemy.EnemyType.SUCCUBUS, "cell": g + Vector2i(0, 7)},
		{"type": Enemy.EnemyType.ASH_HARPY, "cell": g + Vector2i(-9, 1)},
		{"type": Enemy.EnemyType.ASH_HARPY, "cell": g + Vector2i(9, 1)},
	]
	_enforce_border_walls()

func _build_breach_decorations() -> void:
	## The gate: the designer's great vein arch in the north wall, a pale
	## light through it; horned crags and cones along the walls; the lava's
	## glow; bones of those who tried.
	for gp in guardian_placements:
		_reserve_area(gp["cell"], 0)
	_reserve_area(breach_gate_cell, 1)
	var arch := _make_prop_sprite("hell_arch", 1.5, 0)
	if arch:
		arch.position = grid_manager.grid_to_world(breach_gate_cell) + Vector3(0, CameraView.SPRITE_LIFT, 0.35)
		_visuals_root.add_child(arch)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position = grid_manager.grid_to_world(breach_gate_cell) + Vector3(0, 1.2, 0.3)
	_visuals_root.add_child(light)
	var placed := 0
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if grid[x][z] != Tile.WALL or water[x][z] or not _has_adjacent_floor(x, z) or _is_floor_at(x, z - 1):
				continue
			var pos := Vector2i(x, z)
			if (pos - breach_gate_cell).length() < 2.5 or (pos - player_start).length() < 2.5:
				continue
			var n := _tile_noise(x, z, 661)
			var sprite: Sprite3D = null
			if n < 0.22:
				sprite = _make_prop_sprite("hell_horn", 0.8, int(n * 1000) % 17)
			elif n < 0.34:
				sprite = _make_prop_sprite("hell_spire", 0.8, int(n * 100))
			if sprite:
				sprite.position = grid_manager.grid_to_world(pos) + Vector3(0, CameraView.SPRITE_LIFT, 0.3)
				_visuals_root.add_child(sprite)
				placed += 1
	_dress_lava()
	_scatter_hell_bones(0.04, 667)
	print("[DUNGEON] The Breach dressed: %d crags and cones" % placed)

## The way up, once the wardens have fallen: a site standing at the gate.
## Shift there climbs to the next world (main._try_interact_site, kind
## "ascend"), as Hell's Door leads down to this one.
func _place_breach_ascent() -> void:
	if get_site_by_id("ascend") >= 0:
		return
	_place_exit_site(breach_gate_cell, "ascend", "ascend", "The Breach", "[Shift] Ascend", Vector3(0, 0, -0.8), Color(1.0, 0.92, 0.75))

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

	# A worn runner carpet down the central hall (rendered via the trail pass).
	for x in range(1, GRID_W - 1):
		for dz in range(-1, 2):
			if grid[x][mid_z + dz] == Tile.FLOOR:
				trail[x][mid_z + dz] = true

# ============================================
# SHARED CARVING HELPERS
# ============================================

func _init_grid_walls() -> void:
	grid.clear()
	trail.clear()
	for x in range(GRID_W):
		var col: Array = []
		var tcol: Array = []
		for z in range(GRID_H):
			col.append(Tile.WALL)
			tcol.append(false)
		grid.append(col)
		trail.append(tcol)

func is_trail(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= GRID_W or grid_pos.y < 0 or grid_pos.y >= GRID_H:
		return false
	if trail.is_empty():
		return false
	return trail[grid_pos.x][grid_pos.y]

func _mark_trail(x: int, z: int) -> void:
	if _marking_trails and x >= 0 and x < GRID_W and z >= 0 and z < GRID_H:
		trail[x][z] = true

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
			_mark_trail(x, z)

func _carve_corridor_v(x: int, from_z: int, to_z: int) -> void:
	var min_z = mini(from_z, to_z)
	var max_z = maxi(from_z, to_z)
	for z in range(maxi(0, min_z), mini(max_z + 1, GRID_H)):
		if x >= 0 and x < GRID_W:
			grid[x][z] = Tile.FLOOR
			_mark_trail(x, z)

# ============================================
# ELEVATION
# Some rooms become hills (elev 1) and plateaus (elev 2 with a terraced rim)
# so high ground reads as natural terrain rather than floating platforms.
# ============================================

func _generate_elevation() -> void:
	if interior_kind == "mountains" or interior_kind == "ascent":
		return  # the layout terraced it (_generate_mountain_layout)
	elevation.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(0)
		elevation.append(col)

	if interior_kind == "building" or interior_kind == "dojo":
		return  # Buildings and the dojo are flat inside
	if interior_kind == "sewer":
		return  # Sewers are flat; channels are carved into the floor, not raised
	if interior_kind == "boneyard" or interior_kind == "hellgate" or interior_kind == "labyrinth" \
			or interior_kind == "trolllair" or interior_kind == "thanatoshall" or interior_kind == "closet" \
			or act2_place():
		return  # a walled graveyard square / the gate hall / the maze / the Rift's banks, the Citadel's courts: flat
	if interior_kind == "ratking":
		# The lair's three cliffs: the walkable top rows behind each cliff
		# face (the face row itself is a wall tile; see _generate_rat_king_layout).
		for rect in rat_cliffs:
			_set_elevation_rect(rect, 1)
		return
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

func build_high_ground(center: Vector2i, radius: int = 1, elev: int = 1) -> Dictionary:
	## Carve a walkable raised platform centred on `center` (sandbox helper and
	## Terrain formation card). FLOOR tiles are given elevation `elev` (so the
	## player glides up onto them and gets the High Ground bonus), and the pack
	## ledge sheet is rebuilt so the rise is visible. WALL tiles are
	## never consumed — walls are a hard cutoff no matter the elevation beside
	## them. Returns a handle {cells, nodes} usable with remove_high_ground().
	var handle := {"cells": [], "nodes": []}
	for x in range(center.x - radius, center.x + radius + 1):
		for z in range(center.y - radius, center.y + radius + 1):
			if x < 0 or x >= GRID_W or z < 0 or z >= GRID_H:
				continue
			if grid[x][z] != Tile.FLOOR:
				continue
			if elevation[x][z] != 0:
				continue  # never stack on / overwrite existing high ground
			elevation[x][z] = elev
			handle["cells"].append(Vector2i(x, z))
	if not handle["cells"].is_empty():
		_rebuild_pack_ledges()
		_detect_cliffs()
	return handle

func remove_high_ground(handle: Dictionary) -> void:
	## Undo a build_high_ground() using its returned handle: flatten the raised
	## cells back to ground level and free the platform visuals (Terrain
	## formation's hill expiring).
	for cell in handle.get("cells", []):
		if cell.x >= 0 and cell.x < GRID_W and cell.y >= 0 and cell.y < GRID_H:
			elevation[cell.x][cell.y] = 0
	for node in handle.get("nodes", []):
		if is_instance_valid(node):
			node.queue_free()
	if not handle.get("cells", []).is_empty():
		_rebuild_pack_ledges()
		_detect_cliffs()


func get_elevation(grid_pos: Vector2i) -> int:
	if grid_pos.x < 0 or grid_pos.x >= GRID_W or grid_pos.y < 0 or grid_pos.y >= GRID_H:
		return 0
	# The grid redraws before a fresh layout has allocated its elevation map.
	if grid_pos.x >= elevation.size() or grid_pos.y >= elevation[grid_pos.x].size():
		return 0
	return elevation[grid_pos.x][grid_pos.y]

## Walking up or down: one elevation level a step (designer, 2026-11-05).
## Neighbouring tiles more than MAX_STEP levels apart are a cliff face that
## nothing walks up or down; the way up is a chain of ledges and steps (the
## Mountains). Fliers cross it (Enemy.immune_to_high_ground), and so does a
## climber (PlayerStats.climbs_cliffs, for climbing gear); a blink, leap,
## charge or knockback is not walking and ignores it.
const MAX_STEP := 1
## Whether any two neighbouring floor tiles here are a cliff apart: enemies
## then take the real way round (Enemy._build_route_path) rather than a
## greedy step that would stall at a cliff's foot.
var has_cliffs: bool = false

func can_step(from: Vector2i, to: Vector2i) -> bool:
	return absi(get_elevation(to) - get_elevation(from)) <= MAX_STEP

func _detect_cliffs() -> void:
	# The Mountain Pass: its south-facing cliffs are rock faces (walls), so
	# its floor alone need not show a cliff — but its walkers need the route.
	has_cliffs = interior_kind == "mountains" or interior_kind == "ascent"
	if has_cliffs:
		return
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR:
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = Vector2i(x, z) + d
				if n.x < GRID_W and n.y < GRID_H and grid[n.x][n.y] == Tile.FLOOR \
						and not can_step(Vector2i(x, z), n):
					has_cliffs = true
					return

func get_elevation_world_y(grid_pos: Vector2i) -> float:
	## Returns the world Y position for the given grid tile based on elevation.
	return get_elevation(grid_pos) * ELEV_STEP

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
			# source, so painted hues survive on screen (16-bit pass). The
			# purchased Craftpix fills carry their own finished colour, so they
			# take an even lighter cast than our generated sheets.
			inst_color = Color(1, 1, 1).lerp(inst_color, _tint_weight(texture_path))
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


## How much of the palette tint a textured tile keeps: 0.5 on our generated
## grayscale-derived sheets, 0.35 on purchased colour-authored fills (enough
## theme cast to sit the bright pack grass into the world's light, not enough
## to repaint it).
static func _tint_weight(texture_path: String) -> float:
	# The purchased fills keep their own colour (a whisper of the world's
	# cast); the generated grayscale sheets still take the palette.
	return 0.1 if is_colour_authored(texture_path) else 0.5


## A finished-colour sheet (a pack fill or the designer's ground), as opposed
## to our generated grayscale sheets that take the palette as their colour.
static func is_colour_authored(texture_path: String) -> bool:
	return texture_path.begins_with(CP_TEX) or texture_path.begins_with(GROUND_TEX)


## Raised ground's own sheet, or "" for the floor sheet lightened.
func high_texture_path() -> String:
	if interior_kind == "forest":
		return GROUND_TEX + "/forest_grass_high.png"   # worn grass, like the top of the designer's cliff block
	if interior_kind == "" and art_world() == 2:
		return GROUND_TEX + "/desert_sand.png"   # sand, like the top of the designer's desert cliff
	if (interior_kind == "" and art_world() == 4) or act2_place():
		return GROUND_TEX + "/cursed_floor.png"   # the cursed earth, like the lip of the designer's cliff
	return ""


## True when this location's ground is the designer's continuous sheets: a
## tile takes the variant its place in a 4x4 block calls for, so the
## painting runs on across tiles (the pack fills are flat, so their
## variants are picked by hash for variety).
func ground_continuous() -> bool:
	# The field's grass is separate painted tiles, not one painting: its
	# variants are picked by hash, so its daisies never fall in a lattice.
	var floor_path := floor_texture_path()
	return floor_path.begins_with(GROUND_TEX) and not floor_path.ends_with("/field_grass.png")


## The interior variant (0..15) for the open ground tile at (x, z).
func _ground_variant(x: int, z: int) -> int:
	if ground_continuous():
		return posmod(x, 4) + 4 * posmod(z, 4)
	return int(_tile_noise(x, z, 11) * ATLAS_VARIANTS) % ATLAS_VARIANTS


## Billboard sprite props (trees, bushes, rocks, stumps, ferns): a QuadMesh
## MultiMesh with a nearest-filtered billboard material. items entries:
## {pos: Vector3 ground point, scale: float, color: Color theme cast}.
## `cover_h`: the prop's height in pack texels (32 a tile) for the ground-cover
## test, when its art is finer than the packs' (the designer's props); -1: px_h.
func _add_sprite_decos(items: Array, texture_path: String, px_w: float, px_h: float, cover_h: float = -1.0) -> void:
	if items.is_empty():
		return
	var ps := 0.03125  # world units per texel (style guide texel density)
	var quad := QuadMesh.new()
	quad.size = Vector2(px_w * ps, px_h * ps)
	# Pivot at the bottom edge: the billboard turns about the instance origin,
	# so with the quad hung above it the art's ground row stays glued to the
	# ground point under the pitched camera (a centred quad's bottom edge
	# swings below the tile and the prop reads as sunk in). Per-instance
	# scale then grows the prop upward from its base, as it should.
	quad.center_offset = Vector3(0, px_h * ps * 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = items.size()
	# Low props are ground cover the player walks over; tall ones can hide them.
	var tall_h: float = px_h if cover_h < 0.0 else cover_h
	var lift: float = CameraView.SPRITE_LIFT if tall_h > CameraView.GROUND_COVER_MAX_PX else CameraView.GROUND_COVER_LIFT
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var s: float = it.get("scale", 1.0)
		var pos: Vector3 = it["pos"] + Vector3(0, lift, 0)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), pos))
		mm.set_instance_color(i, Color(1, 1, 1).lerp(it.get("color", Color.WHITE), 0.25))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(texture_path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Alpha scissor, not blending: pixel art has hard edges (the pack props
	# carry no semi-transparent texels), so the props render in the opaque
	# pass and WRITE DEPTH. A blended MultiMesh sorts as one object against
	# the character sprites — every stone in the batch either covered the
	# player or sat under them — while depth resolves it per pixel.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	_visuals_root.add_child(mmi)


# ============================================
# AUTOTILED GROUND
# ============================================
# Every walkable cell is one 32px tile from an atlas: 5 terrains × (16 edge
# masks + 16 plain variants). A cell's mask is which of its N/E/S/W
# neighbours are a *different* terrain, so grass meets dirt with a shadowed
# lip, dirt fades into grass with a dust edge, water carries a foam rim
# against land, and raised ground draws a sun-lit lip over its drop.
# The atlas is assembled at runtime (_make_ground_atlas) from the location's
# ground sheets — Craftpix fills where a pack matches, generated palette
# sheets elsewhere — with the edge bands painted in the palette. Cutting the
# packs' own edge pieces into the mask columns is the next step.

enum Terrain { GRASS, DIRT, WATER, PIT, HIGH }
## One atlas tile per world unit, at the game's texel density (style guide §1:
## 1 grid tile = 32 texels) — the same 32px variants the ground sheets hold.
const ATLAS_TILE := 32
## Columns 0..15: the 4-bit N/E/S/W edge mask on the sheet's first variant.
## Columns 16..31: the sheet's 16 plain variants, used for interior (mask 0)
## cells so open ground does not repeat one tile.
const ATLAS_MASKS := 16
const ATLAS_VARIANTS := 16
const ATLAS_COLS := ATLAS_MASKS + ATLAS_VARIANTS
const EDGE_BAND := 4   # px of painted edge on a marked side (2 pack texels)
var _atlas_cache: Dictionary = {}  # palette name|interior -> ImageTexture

func _terrain_of(x: int, z: int) -> int:
	if is_water(Vector2i(x, z)):
		return Terrain.WATER
	if pit_tiles.has(Vector2i(x, z)):
		return Terrain.PIT
	if step_tiles.has(Vector2i(x, z)):
		return Terrain.DIRT   # a step up a cliff: the trodden track, not the ledge (no pack draws stairs)
	if elevation[x][z] > 0:
		return Terrain.HIGH
	if trail[x][z]:
		return Terrain.DIRT
	return Terrain.GRASS

func _neighbor_differs(x: int, z: int, nx: int, nz: int, t: int) -> bool:
	## Walls never draw an edge on the floor beside them (the wall's own
	## skirt does that); everything else edges where the terrain changes,
	## and raised ground edges only against lower floor.
	if nx < 0 or nx >= GRID_W or nz < 0 or nz >= GRID_H:
		return false
	if grid[nx][nz] != Tile.FLOOR:
		return false
	if bridge_cells.has(Vector2i(nx, nz)):
		return false   # a bridge over the lava is lava to the ground beside it: no edge (as against lava itself)
	if t == Terrain.HIGH:
		return elevation[nx][nz] < elevation[x][z]
	return _terrain_of(nx, nz) != t

## The prebuilt ground atlas for this location (the designer's ground,
## tools/cut_ground_boards.py: a row per terrain and tile variant, a column
## per edge mask, the edges painted), or "" for the runtime atlas.
func ground_atlas_path() -> String:
	if interior_kind == "forest":
		return GROUND_TEX + "/forest_atlas.png"
	if interior_kind == "cave":
		return GROUND_TEX + ("/cave_glow_atlas.png" if cave_glows() else "/cave_atlas.png")
	if interior_kind == "" and art_world() == 2:
		return GROUND_TEX + "/desert_atlas.png"
	if interior_kind == "" and art_world() == 4:
		return GROUND_TEX + "/cursed_atlas.png"
	if floor_texture_path() == GROUND_TEX + "/undead_floor.png":
		return GROUND_TEX + "/undead_atlas.png"   # World 5 and the Boneyard
	if floor_texture_path() == GROUND_TEX + "/field_grass.png":
		return GROUND_TEX + "/field_atlas.png"   # the Verdant Frontier, and anywhere else on its grass
	return ""


## Every other cave is a crystal cave: the designer's glowing floor and
## crystal-hung rock (cave_1, cave_3 ...).
func cave_glows() -> bool:
	return interior_kind == "cave" and int(interior_id.get_slice("_", 1)) % 2 == 1

var _atlas_pre := false   # the ground mesh uses a prebuilt atlas (_atlas_cell)

## The atlas cell (u0, v0) for terrain `t` with edge `mask` at (x, z), and its
## size in _atlas_size.
func _atlas_cell(t: int, mask: int, x: int, z: int) -> Vector2:
	if _atlas_pre:
		return Vector2(mask / 16.0, float(t * 16 + _ground_variant(x, z)) / (Terrain.size() * 16))
	var col := mask
	if mask == 0:
		col = ATLAS_MASKS + _ground_variant(x, z)
	return Vector2(float(col) / ATLAS_COLS, float(t) / Terrain.size())

func _atlas_size() -> Vector2:
	if _atlas_pre:
		return Vector2(1.0 / 16.0, 1.0 / (Terrain.size() * 16))
	return Vector2(1.0 / ATLAS_COLS, 1.0 / Terrain.size())

func _build_autotile_ground() -> void:
	var pal = get_palette()
	var atlas: Texture2D
	var pre := ground_atlas_path()
	_atlas_pre = pre != "" and ResourceLoader.exists(pre)
	if _atlas_pre:
		atlas = load(pre)
	else:
		atlas = _make_ground_atlas(pal)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tw := _atlas_size().x
	var th := _atlas_size().y
	var count := 0
	var natural := _natural_boundary()
	var site_tiles = _all_site_footprint_tiles() if natural else {}
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR:
				if grid[x][z] == Tile.WALL and is_water(Vector2i(x, z)):
					# An impassable pool (Emberfall's lava): water with a rim
					# wherever the neighbour is not water.
					var lm := 0
					if not is_water(Vector2i(x, z - 1)): lm |= 1
					if not is_water(Vector2i(x + 1, z)): lm |= 2
					if not is_water(Vector2i(x, z + 1)): lm |= 4
					if not is_water(Vector2i(x - 1, z)): lm |= 8
					var lc := _atlas_cell(Terrain.WATER, lm, x, z)
					_ground_quad(st, x, z, -0.02, lc.x, lc.y, tw, th)
					count += 1
					continue
				# Outdoors the land runs on under the blocked tiles: plain
				# ground there too, so the tree line stands on grass, not void.
				if (natural or waypoint_block_tiles.has(Vector2i(x, z))) and grid[x][z] == Tile.WALL \
						and not site_tiles.has(Vector2i(x, z)) and _near_floor(x, z, 3):
					var wc := _atlas_cell(Terrain.GRASS, 0, x, z)
					var wy: float = _max_adjacent_floor_elevation(x, z) * ELEV_STEP + 0.004
					_ground_quad(st, x, z, wy, wc.x, wc.y, tw, th)
					count += 1
				continue
			var t := _terrain_of(x, z)
			var mask := 0
			if _neighbor_differs(x, z, x, z - 1, t): mask |= 1   # N
			if _neighbor_differs(x, z, x + 1, z, t): mask |= 2   # E
			if _neighbor_differs(x, z, x, z + 1, t): mask |= 4   # S
			if _neighbor_differs(x, z, x - 1, z, t): mask |= 8   # W
			var y: float = elevation[x][z] * ELEV_STEP + 0.004
			if t == Terrain.WATER:
				y = -0.02
			# Open ground (mask 0): one of the sheet's 16 variants (_ground_variant).
			var cell := _atlas_cell(t, mask, x, z)
			_ground_quad(st, x, z, y, cell.x, cell.y, tw, th)
			count += 1
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "AutotileGround"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	# Theme cast, same weights as the slab terrain: colour-authored pack
	# fills keep more of their own colour than the generated sheets.
	mat.albedo_color = Color(1, 1, 1).lerp(pal["floor_a"], _tint_weight(floor_texture_path()))
	mi.material_override = mat
	_visuals_root.add_child(mi)
	print("[DUNGEON] Autotiled %d ground tiles (%s)" % [count, pal.get("name", "")])

## One ground tile quad with its atlas cell.
static func _ground_quad(st: SurfaceTool, x: int, z: int, y: float, u0: float, v0: float, tw: float, th: float) -> void:
	var u1 := u0 + tw
	var v1 := v0 + th
	var a := Vector3(x, y, z)
	var b := Vector3(x + 1, y, z)
	var c := Vector3(x + 1, y, z + 1)
	var d := Vector3(x, y, z + 1)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
	st.set_uv(Vector2(u1, v0)); st.add_vertex(b)
	st.set_uv(Vector2(u1, v1)); st.add_vertex(c)
	st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
	st.set_uv(Vector2(u1, v1)); st.add_vertex(c)
	st.set_uv(Vector2(u0, v1)); st.add_vertex(d)

## True when a floor tile lies within `r` (Chebyshev) of (x, z).
func _near_floor(x: int, z: int, r: int) -> bool:
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if _is_floor_at(x + dx, z + dz):
				return true
	return false

static func _px_hash(x: int, y: int, salt: int) -> float:
	var h := int((x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)) & 0x7fffffff
	return float(h % 1000) / 1000.0

func _make_ground_atlas(pal: Dictionary) -> ImageTexture:
	## Ground atlas for this location: every terrain row takes its 32px
	## variants from a ground sheet (grass = floor sheet, dirt = trail sheet,
	## water = water sheet, pit = floor darkened, high = floor lightened), and
	## the 16 mask columns get palette-coloured edge bands on the sides where
	## the neighbouring terrain differs (plus a lip shadow under raised
	## ground). Cached per palette + interior.
	var key: String = str(pal.get("name", "")) + "|" + interior_kind + "|" + floor_texture_path()
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	# Tile size: the floor sheet's (a 4x4 sheet: 32 px tiles for the packs,
	# 64 for the designer's ground); the other sheets are fitted to it.
	var floor_sheet := _sheet_image(floor_texture_path())
	var n: int = maxi(ATLAS_TILE, floor_sheet.get_width() / 4)
	var k: int = n / ATLAS_TILE   # edge bands are drawn in pack texels, k px each
	var img := Image.create(n * ATLAS_COLS, n * Terrain.size(), false, Image.FORMAT_RGBA8)
	var ground: Color = pal.get("ground", Color(0.1, 0.1, 0.1))
	var floor_b: Color = pal.get("floor_b", Color(0.25, 0.42, 0.2))
	var trail_c: Color = pal.get("trail", Color(0.34, 0.28, 0.18))
	var water_c: Color = pal.get("water", Color(0.16, 0.3, 0.5))
	var water_e: Color = pal.get("water_edge", water_c.lightened(0.25))
	var trail_sheet := _fit_sheet(_sheet_image(trail_texture_path()), n)
	var water_sheet := _fit_sheet(_sheet_image(water_texture_path()), n)
	floor_sheet = _fit_sheet(floor_sheet, n)
	var pit_sheet := floor_sheet.duplicate()
	pit_sheet.adjust_bcs(0.45, 1.0, 0.8)
	var high_sheet: Image
	if high_texture_path() != "":
		high_sheet = _fit_sheet(_sheet_image(high_texture_path()), n)
	else:
		high_sheet = floor_sheet.duplicate()
		high_sheet.adjust_bcs(1.14, 1.0, 1.0)
	# [sheet, edge colour] per terrain
	var styles := {
		Terrain.GRASS: [floor_sheet, floor_b.darkened(0.35)],
		Terrain.DIRT: [trail_sheet, trail_c.lightened(0.28)],
		Terrain.WATER: [water_sheet, Color(0.85, 0.92, 1.0).lerp(water_e, 0.3)],
		Terrain.PIT: [pit_sheet, ground],
		Terrain.HIGH: [high_sheet, Color(1.0, 0.98, 0.85).lerp(pal.get("floor_a", floor_b), 0.45)],
	}
	var band := EDGE_BAND * k
	for t in range(Terrain.size()):
		var sheet: Image = styles[t][0]
		var edge: Color = styles[t][1]
		var oy := t * n
		# Interior variants: the sheet's 4x4 grid, straight copy.
		for v in range(ATLAS_VARIANTS):
			var src := Rect2i((v % 4) * n, (v / 4) * n, n, n)
			img.blit_rect(sheet, src, Vector2i((ATLAS_MASKS + v) * n, oy))
		# Mask tiles: first variant plus edge bands.
		for mask in range(ATLAS_MASKS):
			var ox := mask * n
			img.blit_rect(sheet, Rect2i(0, 0, n, n), Vector2i(ox, oy))
			if mask == 0:
				continue
			for py in range(n):
				for px in range(n):
					var on_edge := (mask & 1 and py < band) or (mask & 2 and px >= n - band) \
							or (mask & 4 and py >= n - band) or (mask & 8 and px < band)
					var col: Color
					if on_edge:
						col = edge
						# Outer texel row a shade darker: the pack art's outline.
						var outer := (mask & 1 and py < 2 * k) or (mask & 2 and px >= n - 2 * k) \
								or (mask & 4 and py >= n - 2 * k) or (mask & 8 and px < 2 * k)
						if outer and t != Terrain.WATER:
							col = edge.darkened(0.3)
						if t == Terrain.WATER and _px_hash(px / k, py / k, 3) > 0.6:
							col = edge.lightened(0.15)  # foam sparkle
					elif t == Terrain.HIGH and (mask & 4) and py >= n - band - 2 * k:
						col = floor_b.darkened(0.45)  # lip shadow under raised ground
					else:
						continue
					img.set_pixel(ox + px, oy + py, col)
	var tex := ImageTexture.create_from_image(img)
	_atlas_cache[key] = tex
	return tex


## `sheet` (a 4x4 sheet) at `n` px a tile: a pack sheet beside the designer's
## finer ground is scaled up texel for texel.
static func _fit_sheet(sheet: Image, n: int) -> Image:
	if sheet.get_width() != n * 4 or sheet.get_height() != n * 4:
		sheet.resize(n * 4, n * 4, Image.INTERPOLATE_NEAREST)
	return sheet


## A ground sheet as a decompressed RGBA8 image, or a flat palette fill if
## the file is missing (so a bad path can never leave holes in the ground).
func _sheet_image(path: String) -> Image:
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var img: Image = tex.get_image() if tex else null
	if img == null:
		img = Image.create(ATLAS_TILE * 4, ATLAS_TILE * 4, false, Image.FORMAT_RGBA8)
		img.fill(get_palette().get("floor_a", Color(0.3, 0.5, 0.25)))
		return img
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

## Outdoor zones have no "walls": the ground runs on under the blocked
## tiles and the edge of the walkable land is a line of trees, rocks and
## bushes (the way the packs' fields and forests read). Caves, sewers, the
## hellscape and the barrows keep their packs' rock and vein masses.
func _natural_boundary() -> bool:
	if act2_place():
		return false   # the Underworld's veined cliffs all round
	if interior_kind in ["cave", "sewer", "building", "dojo", "graveyard", "ratking", "boneyard", "hellgate", "labyrinth"]:
		return false
	if interior_kind == "forest":
		return true
	if interior_kind in ["mountains", "icecave", "trolllair", "closet", "thanatoshall"]:
		return false   # rock all round
	return art_world() in [1, 2, 3]

func _build_walls() -> void:
	## Rock walls drawn the way the packs draw cliffs: a flat autotiled mesh
	## on the ground plane. Every wall tile beside floor is four 16px quads —
	## a plateau cap cut from the biome's ground sheet with painted outlines
	## on the sides that face floor, and along every south-facing edge the
	## pack's own cliff face (fringe over base, or a single ledge row) from
	## the cliff strip cut by tools/extract_craftpix_cliffs.py. Nothing
	## rises above the floor, so nothing can draw over a character standing
	## beside it under the plan camera (CameraView). The rest of the wall
	## mass is capped too, so the level reads as one plateau world rather
	## than rooms cut into a void. Man-made interiors keep their crisp box
	## walls.
	var pal = get_palette()
	var is_building = interior_kind == "building" or interior_kind == "dojo"
	if not is_building:
		if _natural_boundary():
			_build_boundary_props()
		else:
			_build_cliff_walls()
			if (art_world() == 4 and interior_kind == "") or interior_kind in ["rift", "ascent"]:
				_place_hell_landmarks()   # the Underworld's skyline, on the Rift's and the Stair's rock too
		_build_site_blocks()
		return
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
			var height: float = WALL_HEIGHT + _max_adjacent_floor_elevation(x, z) * ELEV_STEP
			var col: Color = pal["wall_a"].lerp(pal["wall_b"], _tile_noise(x, z, 31))
			var xform = Transform3D(
				Basis.from_scale(Vector3(1.0, height, 1.0)),
				Vector3(x + 0.5, height / 2.0, z + 0.5)
			)
			items.append({"xform": xform, "color": col})
	_add_multimesh(BoxMesh.new(), items, true, 0.95, wall_texture_path())
	print("[DUNGEON] Built %d wall segments (%s %dx%d)" % [items.size(), get_location_name(), GRID_W, GRID_H])


## ---------------------------------------------------------------------------
## CLIFF WALLS. The wall atlas is 16px cells in one row:
##   0..3   cap fill variants (biome ground sheet, sun-lit like raised ground)
##   4..7   cap edge N / E / S / W (outline on that side)
##   8..11  cap outer corner NW / NE / SE / SW
##   12..15 cap inner corner NW / NE / SE / SW (a nick where a floor tile
##          touches only diagonally)
##   16..21 face fringe L, M1..M4, R      (cliff strip row 0)
##   22..27 face base   L, M1..M4, R      (cliff strip row 1)
##   28..31 lower-ground fill (the floor sheet as is) drawn under every face
##          tile so the pieces' transparent tufts and drips show ground, not
##          the backdrop
## Face rows per biome: 2 = fringe over base (a 32px face), 1 = the strip's
## first row is a single 16px ledge drawn under 16px of cap.
const WALL_CELL := 16
const WALL_ATLAS_CELLS := 32
const WALL_CAP_FILL := 0
const WALL_CAP_EDGE := 4
const WALL_CAP_OUTER := 8
const WALL_CAP_INNER := 12
const WALL_FACE_FRINGE := 16
const WALL_FACE_BASE := 22
const WALL_FACE_MIDS := 4
const WALL_UNDER := 28
var _wall_atlas_cache: Dictionary = {}


## The cliff strip for this location (see tools/extract_craftpix_cliffs.py).
func cliff_strip_path() -> String:
	if act2_place():
		return GROUND_TEX + "/cursed_cliff.png"   # the Underworld's veined cliff under its earth lip
	match interior_kind:
		"cave":
			return GROUND_TEX + "/cave_cliff.png"   # the designer's hanging rock face, 32 px cells (2026-10-29)
		"sewer", "ratking", "hellgate", "labyrinth":
			return CP_TEX + "/cliff_cave.png"
		"boneyard", "closet", "thanatoshall":   # the undead land: the Boneyard and Thanatos Closet
			return GROUND_TEX + "/undead_cliff.png"   # the designer's barrow land (2026-10-29)
		"forest":
			return GROUND_TEX + "/forest_cliff.png"   # the designer's grass-over-rock strip, 32 px cells (2026-10-29)
		"mountains", "icecave", "trolllair":
			return CP_TEX + "/cliff_undead.png"  # grey rock faces under the frost palette, as Frostreach's
	match art_world():
		4:
			return GROUND_TEX + "/cursed_cliff.png"   # the designer's veined cliff under its earth lip (2026-10-29)
		5:
			return GROUND_TEX + "/undead_cliff.png"   # the designer's spikes under an earth lip (2026-10-29)
		2:
			return GROUND_TEX + "/desert_cliff.png"   # the designer's sand-topped cliff, 32 px cells
		3:
			return CP_TEX + "/cliff_undead.png"  # grey barrow rock under the frost palette
	return GROUND_TEX + "/field_cliff.png"   # the designer's grass over cobbled earth (2026-10-29)


## How many 16px rows the biome's cliff face is: the forest and desert packs
## draw single-row ledges, the rest a fringe row over a base row.
func cliff_face_rows() -> int:
	return 2


## The top of a wall mass: the pack's cliff rock (shaded in _make_wall_atlas).
func cap_texture_path() -> String:
	return wall_texture_path()


func _make_wall_atlas(pal: Dictionary) -> ImageTexture:
	var key: String = str(pal.get("name", "")) + "|" + interior_kind + "|" + str(world_level) + "|" + wall_texture_path()
	if _wall_atlas_cache.has(key):
		return _wall_atlas_cache[key]
	# The cliff strip sets the cell size: 16 px pieces for the packs, 32 for
	# the designer's 64-a-tile ground; the sheets are fitted to match.
	var strip_path := cliff_strip_path()
	var strip: Image = null
	if ResourceLoader.exists(strip_path):
		var stex: Texture2D = load(strip_path)
		strip = stex.get_image() if stex else null
	var n := WALL_CELL
	if strip != null:
		n = maxi(WALL_CELL, strip.get_height() / 2)
	var img := Image.create(n * WALL_ATLAS_CELLS, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var underground := _fit_sheet(_sheet_image(floor_texture_path()), n * 2)
	# The cap is the pack's cliff rock, shaded down: a wall mass has to read
	# as solid from above, and a ground-coloured cap left thin walls looking
	# like floor the player could not step onto.
	var cap := _fit_sheet(_sheet_image(cap_texture_path()), n * 2)
	var is_rock := interior_kind in ["cave", "sewer", "ratking", "hellgate", "labyrinth"]
	# The designer's rock is painted dark already: shaded only lightly, it
	# lands where the pack rock's heavier shading did.
	var designer_cap := cap_texture_path().begins_with(GROUND_TEX)
	cap.adjust_bcs((0.85 if designer_cap else 0.55) if is_rock else (0.9 if designer_cap else 0.72), 1.0, 0.85)
	var floor_b: Color = pal.get("floor_b", Color(0.25, 0.42, 0.2))
	# Outline colours follow the pack art: a dark line the colour of the
	# ground's own shadow, then a lit rim.
	var dark: Color = floor_b.darkened(0.45)
	var light: Color = Color(1.0, 0.98, 0.85).lerp(pal.get("floor_a", floor_b), 0.5)
	if is_rock:
		dark = Color(0.03, 0.025, 0.03)
		light = pal.get("wall_a", Color(0.3, 0.28, 0.26)).darkened(0.1)
	for v in range(4):
		img.blit_rect(underground, Rect2i(v * n, 2 * n, n, n), Vector2i((WALL_UNDER + v) * n, 0))
	# Cap fill variants: four 16px windows of the ground sheet's first row.
	for v in range(4):
		img.blit_rect(cap, Rect2i(v * n, 0, n, n), Vector2i((WALL_CAP_FILL + v) * n, 0))
	# Edge, outer-corner and inner-corner cells: fill plus painted outline.
	# Outline = 2px dark line on the open side, 1px light rim inside it.
	for k in range(12):
		var cell := WALL_CAP_EDGE + k
		img.blit_rect(cap, Rect2i((k % 4) * n, n, n, n), Vector2i(cell * n, 0))
		var sides: Array = []
		var inner := -1
		if k < 4:
			sides = [k]  # N, E, S, W
		elif k < 8:
			sides = [[0, 3], [0, 1], [2, 1], [2, 3]][k - 4]  # NW, NE, SE, SW
		else:
			inner = k - 8  # NW, NE, SE, SW nick
		for py in range(n):
			for px in range(n):
				var d := 99
				for sd in sides:
					var dist: int
					match sd:
						0: dist = py
						1: dist = n - 1 - px
						2: dist = n - 1 - py
						_: dist = px
					d = mini(d, dist)
				if inner >= 0:
					# A 2px nick in the corner that touches the diagonal floor.
					var cx := px if (inner == 0 or inner == 3) else n - 1 - px
					var cy := py if (inner == 0 or inner == 1) else n - 1 - py
					d = maxi(cx, cy)
				if d == 0:
					img.set_pixel(cell * n + px, py, dark)
				elif d == 1:
					img.set_pixel(cell * n + px, py, light)
	# Face pieces straight from the cliff strip.
	if strip != null:
		if strip.is_compressed():
			strip.decompress()
		if strip.get_format() != Image.FORMAT_RGBA8:
			strip.convert(Image.FORMAT_RGBA8)
		for c in range(6):
			img.blit_rect(strip, Rect2i(c * n, 0, n, n), Vector2i((WALL_FACE_FRINGE + c) * n, 0))
			img.blit_rect(strip, Rect2i(c * n, n, n, n), Vector2i((WALL_FACE_BASE + c) * n, 0))
	else:
		# No strip: the cobbled wall fill with a dark base line, so a missing
		# file can never leave holes.
		var fill := _sheet_image(wall_texture_path())
		for c in range(6):
			img.blit_rect(fill, Rect2i((c % 4) * n, 0, n, n), Vector2i((WALL_FACE_FRINGE + c) * n, 0))
			img.blit_rect(fill, Rect2i((c % 4) * n, n, n, n), Vector2i((WALL_FACE_BASE + c) * n, 0))
			for px in range(n):
				img.set_pixel((WALL_FACE_BASE + c) * n + px, n - 1, dark)
				img.set_pixel((WALL_FACE_BASE + c) * n + px, n - 2, dark)
	var tex := ImageTexture.create_from_image(img)
	_wall_atlas_cache[key] = tex
	return tex


func _is_floor_at(x: int, z: int) -> bool:
	if x < 0 or x >= GRID_W or z < 0 or z >= GRID_H:
		return false
	return grid[x][z] == Tile.FLOOR


## A wall tile whose south neighbour is floor shows the cliff face.
func _is_face_tile(x: int, z: int) -> bool:
	if x < 0 or x >= GRID_W or z < 0 or z >= GRID_H:
		return false
	return grid[x][z] == Tile.WALL and _is_floor_at(x, z + 1)


static func _add_wall_quad(st: SurfaceTool, u0: float, cw: float, ax: float, y: float, az: float) -> void:
	var u1 := u0 + cw
	var a := Vector3(ax, y, az)
	var b := Vector3(ax + 0.5, y, az)
	var c := Vector3(ax + 0.5, y, az + 0.5)
	var d := Vector3(ax, y, az + 0.5)
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(u0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(u1, 0)); st.add_vertex(b)
	st.set_uv(Vector2(u1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(u0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(u1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(u0, 1)); st.add_vertex(d)


## `only`: draw just these wall tiles (a site's footprint as a raised block
## of the land's own cliff: _build_site_blocks), under `mesh_name`.
func _build_cliff_walls(only: Dictionary = {}, mesh_name: String = "CliffWalls") -> void:
	var pal = get_palette()
	var atlas := _make_wall_atlas(pal)
	var rows := cliff_face_rows()
	var site_tiles = _structure_tiles()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cw := 1.0 / WALL_ATLAS_CELLS
	var count := 0
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.WALL:
				continue
			if not only.is_empty():
				if not only.has(Vector2i(x, z)):
					continue
			elif site_tiles.has(Vector2i(x, z)):
				continue  # Site structures draw their own exteriors
			if is_water(Vector2i(x, z)):
				continue  # a lava pool: the ground autotile draws it
			var y: float = _max_adjacent_floor_elevation(x, z) * ELEV_STEP + 0.012
			var face := _is_face_tile(x, z)
			var n_f := _is_floor_at(x, z - 1)
			var e_f := _is_floor_at(x + 1, z)
			var w_f := _is_floor_at(x - 1, z)
			var ne_f := _is_floor_at(x + 1, z - 1)
			var nw_f := _is_floor_at(x - 1, z - 1)
			var se_f := _is_floor_at(x + 1, z + 1)
			var sw_f := _is_floor_at(x - 1, z + 1)
			# The face runs on while the neighbour is a face tile too; it
			# ends (rounded L / R piece) against floor or a wall that turns.
			var l_end := not _is_face_tile(x - 1, z)
			var r_end := not _is_face_tile(x + 1, z)
			if face:
				# Lower ground under the face so its cut-outs show ground.
				for qy in range(2):
					for qx in range(2):
						var ucell := WALL_UNDER + int(_tile_noise(x * 2 + qx, z * 2 + qy, 59) * 4) % 4
						_add_wall_quad(st, ucell * cw, cw, x + qx * 0.5, y - 0.004, z + qy * 0.5)
			for qy in range(2):
				for qx in range(2):
					var cell := -1
					var face_quad := face and (rows == 2 or qy == 1)
					if face_quad:
						var row_base := WALL_FACE_FRINGE if (rows == 2 and qy == 0) else WALL_FACE_BASE
						if rows == 1:
							row_base = WALL_FACE_FRINGE  # single ledge row lives in row 0
						var col: int
						if qx == 0 and l_end:
							col = 0
						elif qx == 1 and r_end:
							col = WALL_FACE_MIDS + 1
						else:
							col = 1 + int(_tile_noise(x * 2 + qx, z * 2 + qy, 53) * WALL_FACE_MIDS) % WALL_FACE_MIDS
						cell = row_base + col
					else:
						# Cap quad: outline on the sides that face floor.
						var open_v := n_f if qy == 0 else false   # S is never floor on a cap quad
						var open_h := w_f if qx == 0 else e_f
						var diag: bool
						if qy == 0:
							diag = nw_f if qx == 0 else ne_f
						else:
							diag = sw_f if qx == 0 else se_f
						if rows == 1 and face and qy == 0:
							open_v = n_f
						if open_v and open_h:
							cell = WALL_CAP_OUTER + (0 if qx == 0 else 1)  # NW / NE
						elif open_v:
							cell = WALL_CAP_EDGE + 0  # N
						elif open_h:
							cell = WALL_CAP_EDGE + (3 if qx == 0 else 1)  # W / E
						elif diag:
							var corner := 0
							if qy == 0:
								corner = 0 if qx == 0 else 1
							else:
								corner = 3 if qx == 0 else 2
							cell = WALL_CAP_INNER + corner
						else:
							cell = WALL_CAP_FILL + int(_tile_noise(x * 2 + qx, z * 2 + qy, 57) * 4) % 4
					_add_wall_quad(st, cell * cw, cw, x + qx * 0.5, y, z + qy * 0.5)
			count += 1
	if count == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.roughness = 1.0
	mat.albedo_color = Color(1, 1, 1).lerp(pal["floor_a"], _tint_weight(floor_texture_path()))
	mi.material_override = mat
	_visuals_root.add_child(mi)
	print("[DUNGEON] Built %d cliff wall tiles (%s %dx%d)" % [count, get_location_name(), GRID_W, GRID_H])

## The edge of the land, outdoors: every blocked tile touching the walkable
## ground carries one big prop — a tree, a rock or a bush of the zone — and
## the row behind it a thinner stand of trees fading into the fog, so the
## boundary reads as landscape, not a wall. Blocked tiles SOUTH of the
## ground (the row nearest the camera) take low props only (rocks, bushes),
## so nothing tall stands between the camera and a character at the edge.
func _build_boundary_props() -> void:
	var site_tiles = _structure_tiles()
	var trees: Array = []
	var rocks: Array = []
	var bushes: Array = []
	var biome := _prop_biome()
	# Family weights on the edge row: [tree, rock, bush] out of 100.
	var weights: Array = [50, 25, 25]
	match biome:
		"forest": weights = [70, 10, 20]
		"desert": weights = [30, 18, 30]   # the rest of the edge stays open sand (the designer's mesas are big; thinned 2026-10-29)
		"winter": weights = [55, 30, 15]
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.WALL or site_tiles.has(Vector2i(x, z)):
				continue
			var edge := _has_adjacent_floor(x, z)
			var back := not edge and _near_floor(x, z, 2)
			if not edge and not back:
				continue
			var y: float = _max_adjacent_floor_elevation(x, z) * ELEV_STEP + 0.012
			var jx: float = (_tile_noise(x, z, 211) - 0.5) * 0.4
			var jz: float = (_tile_noise(x, z, 223) - 0.5) * 0.4
			var pos := Vector3(x + 0.5 + jx, y, z + 0.5 + jz)
			var roll: float = _tile_noise(x, z, 229) * 100.0
			if back:
				# The stand behind the edge: trees only, every other tile — and
				# never on the camera side of the ground, where a tall sprite
				# would lean over the walkable edge.
				if not _is_floor_at(x, z - 1) and not _is_floor_at(x, z - 2) and _tile_noise(x, z, 233) < 0.5:
					trees.append({"pos": pos, "scale": 1.0 + _tile_noise(x, z, 239) * 0.3, "color": Color.WHITE})
				continue
			# A tile just south of the ground faces the camera: keep it low.
			var faces_camera: bool = _is_floor_at(x, z - 1)
			var open_edge: bool = biome == "desert" and roll >= weights[0] + weights[1] + weights[2]
			if open_edge:
				continue
			if biome == "desert" and faces_camera:
				# The mesas would stand over the walkable edge: scrub there instead.
				if roll < 45:
					bushes.append({"pos": pos, "scale": 1.0 + _tile_noise(x, z, 243) * 0.3, "color": Color.WHITE})
				continue
			if not faces_camera and roll < weights[0]:
				trees.append({"pos": pos, "scale": 1.05 + _tile_noise(x, z, 239) * 0.3, "color": Color.WHITE})
			elif roll < weights[0] + weights[1] or faces_camera and roll < 60:
				var rs: float = (0.9 + _tile_noise(x, z, 241) * 0.25) if biome == "desert" else (1.1 + _tile_noise(x, z, 241) * 0.4)
				rocks.append({"pos": pos, "scale": rs, "color": Color.WHITE})
			else:
				bushes.append({"pos": pos, "scale": 1.1 + _tile_noise(x, z, 243) * 0.4, "color": Color.WHITE})
	_add_prop_decos(trees, "tree")
	_add_prop_decos(rocks, "rock")
	_add_prop_decos(bushes, "bush")
	print("[DUNGEON] Natural boundary: %d trees, %d rocks, %d bushes (%s)" % [trees.size(), rocks.size(), bushes.size(), get_location_name()])

## Kinds of site whose footprint is a raised block of the land's own cliff
## (designer, 2026-11-05: the space behind an entrance was empty ground no
## one could reach — "build out the rest of the cave ... just make sure it is
## covering the spaces that are unreachable"; the designs come later).
## A building's walls and roof cover its footprint already; the forest
## trail's is filled with woods (_build_forest_entrance).
const SITE_BLOCK_KINDS := ["cave", "sewer", "mountains", "graveyard", "closet", "rift", "citadel", "ascent"]

## Every block-kind site's footprint drawn as the land's cliff: rock (or
## earth) on top, the cliff face along its south edge, the entrance art on
## that face.
func _build_site_blocks() -> void:
	if interior_kind != "":
		return
	var tiles := {}
	for site in site_nodes:
		if site["kind"] in SITE_BLOCK_KINDS:
			for c in site["footprint"]:
				tiles[c] = true
	if not tiles.is_empty():
		_build_cliff_walls(tiles, "SiteBlocks")

## Emberfall's skyline: animated volcanoes and demon idols (cave pack) and
## the designer's vein-wrapped ruins (2026-10-29) on the blocked tiles along
## the edge of the ground, well apart, never on the camera side of the land.
func _place_hell_landmarks() -> void:
	var site_tiles = _structure_tiles()
	# The designer's hell (tools/cut_prop_boards.py, 2026-10-29; was the cave
	# pack's volcanoes and demon head, hand and tail): three animations
	# [strip, fps] and the still pieces [role, variant] — the horned idol,
	# the vein arches, the skull-hung fences and the cursed ruins. All at 64
	# texels a tile.
	var strips: Array = [
		["res://assets/textures/props/boards/hell_lava_strip.png", 6.0],
		["res://assets/textures/props/boards/hell_hand_strip.png", 5.0],
		["res://assets/textures/props/boards/hell_tentacle_strip.png", 5.0],
	]
	var stills: Array = [["hell_idol", 0], ["hell_arch", 0], ["hell_arch", 1], ["hell_fence", 0], ["hell_fence", 2]]
	if CraftpixProps.has("cursed_ruin"):
		for k in range(CraftpixProps.PROPS["cursed_ruin"]["variants"].size()):
			stills.append(["cursed_ruin", k])
	var placed: Array = []
	var count := 0
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.WALL or site_tiles.has(Vector2i(x, z)) or not _has_adjacent_floor(x, z) or is_water(Vector2i(x, z)):
				continue
			if _is_floor_at(x, z - 1) or _is_floor_at(x, z - 2):
				continue  # the camera side: a tall idol would lean over the ground
			if _tile_noise(x, z, 251) > 0.16:
				continue
			var too_close := false
			for p in placed:
				if absi(p.x - x) < 7 and absi(p.y - z) < 7:
					too_close = true
					break
			if too_close:
				continue
			var y: float = _max_adjacent_floor_elevation(x, z) * ELEV_STEP + CameraView.SPRITE_LIFT
			var total := strips.size() + stills.size()
			var pick := int(_tile_noise(x, z, 257) * total) % total
			if pick >= strips.size():
				var still: Array = stills[pick - strips.size()]
				var piece := _make_prop_sprite(still[0], 1.0, still[1])
				if piece:
					piece.position = Vector3(x + 0.5, y, z + 0.5)
					_visuals_root.add_child(piece)
					placed.append(Vector2i(x, z))
					count += 1
				continue
			var spec: Array = strips[pick]
			var tex: Texture2D = load(spec[0])
			var fh := tex.get_height()
			var fw := _strip_frame_w(spec[0])
			var spr := _make_pixel_anim(spec[0], fw, fh, spec[1])
			spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			spr.centered = false
			spr.offset = Vector2(-float(fw) * 0.5, 0)
			spr.scale = Vector3(0.5, 0.5, 0.5)   # 64 texels a tile
			spr.position = Vector3(x + 0.5, y, z + 0.5)
			_visuals_root.add_child(spr)
			placed.append(Vector2i(x, z))
			count += 1
	print("[DUNGEON] Emberfall: %d hands, tentacles, lava pools, idols, arches and ruins on the edge" % count)

## A designer strip's frame width: its frame count is in its name's table
## (tools/cut_prop_boards.py lays frames in equal cells side by side).
const STRIP_FRAMES := {"hell_lava_strip.png": 11, "hell_hand_strip.png": 6, "hell_tentacle_strip.png": 6}
func _strip_frame_w(path: String) -> int:
	var tex: Texture2D = load(path)
	return int(tex.get_width() / int(STRIP_FRAMES.get(path.get_file(), 1)))

## Emberfall's pools: a few in the open ground (flagged water, drawn with
## the world's water: lava once, the designer's dark water since 2026-10-29).
## Called by the overworld generator for World 4.
func _place_lava_pools() -> void:
	# Pools are blocked tiles flagged water: nobody wades lava. They sit in
	# open ground (never on a road, never touching the edge, never in the
	# start field) so they never cut a route.
	var pools := 6 + _rng.randi_range(0, 4)
	var made := 0
	# Never in the rooms that matter whole: the start field, the arena (its
	# fight is laid out on fixed points) and the exit room.
	var keep_clear: Array = []
	for room in rooms:
		if room["kind"] in ["start", "arena", "exit"]:
			keep_clear.append((room["rect"] as Rect2i).grow(1))
	for _i in range(pools * 30):   # World 2 is smaller than World 4 was: more tries to find open ground
		if made >= pools:
			break
		var cx = _rng.randi_range(12, GRID_W - 5)
		var cz = _rng.randi_range(4, GRID_H - 5)
		var r = _rng.randi_range(1, 2)
		var open := true
		for dx in range(-r - 1, r + 2):
			for dz in range(-r - 1, r + 2):
				var q = Vector2i(cx + dx, cz + dz)
				if not is_floor(q) or trail[q.x][q.y] or is_water(q):
					open = false
				for kc in keep_clear:
					if kc.has_point(q):
						open = false
		if not open:
			continue
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if dx * dx + dz * dz > r * r + 1 or _rng.randf() > 0.85:
					continue
				var p = Vector2i(cx + dx, cz + dz)
				grid[p.x][p.y] = Tile.WALL
				water[p.x][p.y] = true
		made += 1
	# A floor tile a pool walled in (a gap left inside its ring) is lava too:
	# the ground stays one piece, or no site could be placed on it.
	var seen := {player_start: true}
	var stack: Array = [player_start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and is_floor(n):
				seen[n] = true
				stack.append(n)
	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.FLOOR and not seen.has(Vector2i(x, z)):
				grid[x][z] = Tile.WALL
				water[x][z] = true
	print("[DUNGEON] The Underworld: %d lava pools" % made)

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
	## Raised ground. The pack draws it: the ground
	## autotile paints the raised top from the biome's sheet with its edge
	## bands and lip shadow, and _build_pack_ledges lays the pack's cliff
	## fringe along every drop to lower floor — no modelled cliff bodies, no
	## carved steps (packs-first, CLAUDE.md). Rooms whose cliffs are authored
	## as wall face tiles (the lair) need nothing more.
	if interior_kind != "ratking":
		_build_pack_ledges()

## The pack's cliff fringe (the ledge row where a plateau top hangs over the
## rock) along the south edge of raised ground: wherever a raised floor
## tile has lower floor directly south, the fringe is drawn across the
## top half of that lower tile, ends rounded where the ledge stops. The
## same atlas and material as the cliff walls, so hills, plateaus and wall
## masses are one cut of stone.
func _build_pack_ledges() -> void:
	var pal = get_palette()
	var atlas := _make_wall_atlas(pal)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cw := 1.0 / WALL_ATLAS_CELLS
	var count := 0
	for x in range(GRID_W):
		for z in range(GRID_H):
			if not _is_drop_south(x, z):
				continue
			var y: float = elevation[x][z + 1] * ELEV_STEP + 0.014
			var l_end := not _is_drop_south(x - 1, z)
			var r_end := not _is_drop_south(x + 1, z)
			for qx in range(2):
				var col: int
				if qx == 0 and l_end:
					col = 0
				elif qx == 1 and r_end:
					col = WALL_FACE_MIDS + 1
				else:
					col = 1 + int(_tile_noise(x * 2 + qx, z, 53) * WALL_FACE_MIDS) % WALL_FACE_MIDS
				_add_wall_quad(st, (WALL_FACE_FRINGE + col) * cw, cw, x + qx * 0.5, y, z + 1.0)
			count += 1
	if count == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "PackLedges"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.roughness = 1.0
	mat.albedo_color = Color(1, 1, 1).lerp(pal["floor_a"], _tint_weight(floor_texture_path()))
	mi.material_override = mat
	_visuals_root.add_child(mi)
	print("[DUNGEON] Laid %d pack ledge tiles (%s)" % [count, get_location_name()])

## A raised floor tile whose southern neighbour is lower floor.
func _is_drop_south(x: int, z: int) -> bool:
	if x < 0 or x >= GRID_W or z < 0 or z + 1 >= GRID_H:
		return false
	if grid[x][z] != Tile.FLOOR or grid[x][z + 1] != Tile.FLOOR:
		return false
	return elevation[x][z] > elevation[x][z + 1]

## Re-lay the ledge sheet after runtime high ground comes or goes.
func _rebuild_pack_ledges() -> void:
	if _visuals_root == null:
		return
	var old := _visuals_root.get_node_or_null("PackLedges")
	if old:
		old.name = "PackLedges_old"
		old.queue_free()
	_build_pack_ledges()

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
	if interior_kind == "cave" or interior_kind == "icecave" or interior_kind == "trolllair":
		_build_cave_decorations()   # the ice kinds wear the "ice" prop roles
		if interior_kind == "trolllair":
			_build_troll_vault_mountains()
		return
	if interior_kind == "dojo":
		return  # bare boards: the dummies are the furniture
	if interior_kind == "ratking":
		_build_rat_king_decorations()
		return
	if interior_kind == "boneyard":
		_build_boneyard_decorations()
		return
	if interior_kind == "closet":
		_build_cave_decorations()   # the undead roles: headstones, bones, skulls
		_dress_crypt_walls()
		return
	if interior_kind == "thanatoshall":
		_build_thanatos_hall_decorations()
		return
	if interior_kind == "hellgate":
		_build_hellgate_decorations()
		return
	if interior_kind == "labyrinth":
		_build_labyrinth_decorations()
		return
	match interior_kind:
		"rift":
			_build_rift_decorations()   # then the open ground's scatter below, in the cursed biome
		"crucible":
			_build_crucible_decorations()
			return
		"citadel":
			_build_citadel_decorations()   # then the courts take the open ground's scatter below
		"throne":
			_build_throne_decorations()
			return
		"breach":
			_build_breach_decorations()
			return
		"ascent":
			_dress_lava()   # then the open ground's scatter below, in the cursed biome
	var pal = get_palette()
	var _deco_trees: Array = []
	var _deco_stumps: Array = []
	var _deco_rocks: Array = []
	var _deco_bushes: Array = []
	var _deco_ferns: Array = []
	var _deco_flowers: Array = []
	var _deco_tufts: Array = []
	var _deco_shrooms: Array = []
	var _deco_crates: Array = []
	var _deco_barrels: Array = []
	var _deco_berries: Array = []
	var _deco_pebbles: Array = []
	var _deco_bones: Array = []   # the Amber Wastes' bleached skeletons (the designer's, 2026-10-29)
	var desert := _prop_biome() == "desert"
	var butterfly_cells: Array = []
	var meadow_cells: Array = []
	var wall_edges: Array = []   # buildings: [{pos, dir}] for wall sconces

	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] != Tile.FLOOR:
				if interior_kind == "building" and grid[x][z] == Tile.WALL \
						and x > 0 and z > 0 and x < GRID_W - 1 and z < GRID_H - 1:
					var fdir = _adjacent_floor_dir(x, z)
					if fdir != Vector2i.ZERO:
						wall_edges.append({"pos": Vector2i(x, z), "dir": fdir})
				continue
			var pos = Vector2i(x, z)
			if _reserved.has(pos):
				continue
			var near_wall = not _has_adjacent_floor_on_all_sides(x, z)
			var y_base = elevation[x][z] * ELEV_STEP
			var n = _tile_noise(x, z, 53)
			var jx = (_tile_noise(x, z, 61) - 0.5) * 0.5
			var jz = (_tile_noise(x, z, 67) - 0.5) * 0.5
			var p3 = Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz)

			if interior_kind == "building":
				# Stored goods pushed against the walls: crates and barrels
				# (never on the hall carpet — the trail flag marks it).
				if trail[x][z]:
					continue
				if near_wall and n < 0.10:
					_deco_crates.append({"pos": Vector3(x + 0.5 + jx * 0.5, y_base, z + 0.5 + jz * 0.5),
							"scale": 0.85 + _tile_noise(x, z, 79) * 0.3, "color": Color.WHITE})
				elif near_wall and n < 0.16:
					_deco_barrels.append({"pos": Vector3(x + 0.5 + jx * 0.5, y_base, z + 0.5 + jz * 0.5),
							"scale": 0.85 + _tile_noise(x, z, 81) * 0.3, "color": Color.WHITE})
			else:
				# Overworld field. The treeline hugs the walls densely enough to
				# read as woods pressing in on the clearings (SoM field edges).
				if near_wall and n < 0.13 and _claim_obstacle(pos):
					_deco_trees.append({"pos": p3,
							"scale": 0.85 + _tile_noise(x, z, 73) * 0.55,
							"color": pal.get("leaf", pal["floor_a"])})
				elif near_wall and n < 0.16:
					_deco_stumps.append({"pos": p3,
							"scale": 0.75 + _tile_noise(x, z, 74) * 0.35,
							"color": pal["wall_a"].lerp(pal["accent"], 0.25)})
				elif near_wall and n < 0.20 and not (desert and n >= 0.17):
					_deco_rocks.append({"pos": p3,
							"scale": 0.7 + _tile_noise(x, z, 75) * 0.5, "color": pal["wall_a"]})
				elif near_wall and n < 0.24:
					_deco_shrooms.append({"pos": p3,
							"scale": 0.8 + _tile_noise(x, z, 76) * 0.4, "color": Color.WHITE})
				elif trail[x][z]:
					pass  # keep the roads themselves clean of growth
				elif _is_trail_edge(x, z) and _tile_noise(x, z, 105) < 0.30:
					# Kicked-aside stones line the road: the packed dirt gets
					# a worn edge instead of a hard cut into the grass.
					_deco_pebbles.append({"pos": p3,
							"scale": 0.8 + _tile_noise(x, z, 107) * 0.5,
							"color": pal["wall_a"].lerp(pal["step"], 0.4)})
				elif desert and not near_wall and n > 0.70 and n <= 0.72 and _tile_noise(x, z, 111) < 0.6:
					# Bones half-sunk in the open sand: spines, skulls, ribs.
					_deco_bones.append({"pos": p3, "scale": 0.85 + _tile_noise(x, z, 113) * 0.3,
							"color": Color.WHITE})
				elif n > 0.925:
					if _tile_noise(x, z, 109) < 0.4:
						_deco_berries.append({"pos": p3,
								"scale": 0.8 + _tile_noise(x, z, 83) * 0.5,
								"color": pal["accent"].lerp(pal["floor_a"], 0.5)})
					else:
						_deco_bushes.append({"pos": p3,
								"scale": 0.8 + _tile_noise(x, z, 83) * 0.5,
								"color": pal["accent"].lerp(pal["floor_a"], 0.5)})
				elif n > 0.885:
					_deco_ferns.append({"pos": p3,
							"scale": 0.8 + _tile_noise(x, z, 87) * 0.4,
							"color": pal["floor_a"]})
				elif n > 0.84:
					# Flower clumps scattered through the open meadow
					_deco_flowers.append({"pos": p3,
							"scale": 0.8 + _tile_noise(x, z, 89) * 0.4,
							"color": Color.WHITE})
					if n > 0.855:
						butterfly_cells.append({"pos": pos})
				elif n > 0.72:
					# Tall grass tufts: the workhorse filler that makes open
					# ground read as meadow instead of green carpet.
					_deco_tufts.append({"pos": p3,
							"scale": 0.75 + _tile_noise(x, z, 93) * 0.5,
							"color": pal["floor_a"].lerp(pal["accent"], _tile_noise(x, z, 95) * 0.6)})
				elif not near_wall:
					meadow_cells.append({"pos": pos})

	_add_prop_decos(_deco_trees, "tree")
	_add_prop_decos(_deco_stumps, "stump")
	_add_prop_decos(_deco_rocks, "rock")
	_add_prop_decos(_deco_bushes, "bush")
	_add_prop_decos(_deco_ferns, "fern")
	_add_prop_decos(_deco_flowers, "flower")
	_add_prop_decos(_deco_tufts, "tuft")
	_add_prop_decos(_deco_shrooms, "shroom")
	_add_prop_decos(_deco_crates, "crate")
	_add_prop_decos(_deco_barrels, "barrel")
	_add_prop_decos(_deco_berries, "berry")
	_add_prop_decos(_deco_pebbles, "pebble")
	_add_prop_decos(_deco_bones, "bones")

	if interior_kind == "":
		_place_signposts(pal)
		_place_crows(meadow_cells)
		_place_butterflies(butterfly_cells)
		_add_cloud_shadows()
	elif interior_kind == "building":
		# Wall sconces: a few real flickering lights make the hall feel lived
		# in — fewer and dimmer than the sewers' run of brackets.
		_place_sewer_torches(wall_edges, pal, 10, 3, 10, 1.6, 6.0)

	print("[DUNGEON] Placed %d trees, %d stumps, %d rocks, %d bushes (%d berried), %d ferns, %d flowers, %d tufts, %d shrooms, %d pebbles, %d crates/barrels, %d sconces" % [
		_deco_trees.size(), _deco_stumps.size(), _deco_rocks.size(), _deco_bushes.size() + _deco_berries.size(),
		_deco_berries.size(), _deco_ferns.size(), _deco_flowers.size(), _deco_tufts.size(), _deco_shrooms.size(),
		_deco_pebbles.size(), _deco_crates.size() + _deco_barrels.size(),
		wall_edges.size() if interior_kind == "building" else 0])

func _is_trail_edge(x: int, z: int) -> bool:
	## A non-trail floor tile that touches a trail on any side.
	if trail[x][z]:
		return false
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_trail(Vector2i(x + dir.x, z + dir.y)):
			return true
	return false

func _place_signposts(pal: Dictionary) -> void:
	## A wooden signpost where trails fork: stands on the grass beside the
	## junction tile (never on the road itself), spaced so each is a landmark.
	var candidates: Array = []
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for x in range(1, GRID_W - 1):
		for z in range(1, GRID_H - 1):
			if not trail[x][z]:
				continue
			var branches := 0
			for d in dirs:
				if is_trail(Vector2i(x + d.x, z + d.y)):
					branches += 1
			if branches < 3:
				continue
			# Plant the post on a grass tile beside the fork.
			for d in dirs:
				var side := Vector2i(x + d.x, z + d.y)
				if is_floor(side) and not is_trail(side) and not _reserved.has(side):
					candidates.append({"pos": side, "junction": Vector2i(x, z)})
					break
	if candidates.is_empty():
		return
	var want = clampi(candidates.size() / 6, 2, 6)
	var items: Array = []
	for entry in _spaced_sample(candidates, want, 10):
		var c: Vector2i = entry["pos"]
		# Lean the post toward the road it marks.
		var toward: Vector2i = entry["junction"] - c
		var p3 = Vector3(c.x + 0.5 + toward.x * 0.28, elevation[c.x][c.y] * ELEV_STEP, c.y + 0.5 + toward.y * 0.28)
		items.append({"pos": p3, "scale": 1.0, "color": Color(1, 1, 1)})
	# The designer's signpost (2026-10-29), its own colours; drawn at 64
	# texels a tile, so its size in pack texels is half its own.
	var sign := _first_prop_variant("field_sign")
	_add_sprite_decos(items, sign["path"], sign["w"] * sign["scale"], sign["h"] * sign["scale"], sign["h"] * sign["scale"])

func _place_crows(cells: Array) -> void:
	## A few crows working the open ground — hop, stand, peck.
	if cells.size() < 12:
		return
	var want = clampi(cells.size() / 90, 2, 6)
	var picks = _spaced_sample(cells, want, 9)
	for i in range(picks.size()):
		var pos: Vector2i = picks[i]["pos"]
		var crow = SewerCritter.new()
		crow.name = "Crow_%d" % i
		_visuals_root.add_child(crow)
		crow.setup(Vector3(pos.x + 0.5, 0.0, pos.y + 0.5), _layout_seed + i * 311, "crow")

func _place_butterflies(cells: Array) -> void:
	## A handful of butterflies flitting over the flower patches.
	if cells.is_empty():
		return
	var want = clampi(cells.size() / 5, 3, 9)
	var picks = _spaced_sample(cells, want, 8)
	for i in range(picks.size()):
		var pos: Vector2i = picks[i]["pos"]
		var b = SewerCritter.new()
		b.name = "Butterfly_%d" % i
		_visuals_root.add_child(b)
		b.setup(Vector3(pos.x + 0.5, 0.0, pos.y + 0.5), _layout_seed + i * 233, "butterfly")

func _add_cloud_shadows() -> void:
	## Slow cloud shadows drifting across open outdoor ground (SNES daylight cue).
	var clouds = CloudShadows.new()
	clouds.name = "CloudShadows"
	_visuals_root.add_child(clouds)
	clouds.setup(GRID_W, GRID_H, _layout_seed)

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
	_place_sewer_reeds(water_tiles, pal)
	_place_sewer_mice(floor_tiles)
	_place_bones(floor_tiles, pal, 60, 3, 10)

	print("[DUNGEON] Sewer dressing: %d candidate walls, %d water tiles" % [
		wall_edges.size(), water_tiles.size()])

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

func _place_sewer_torches(wall_edges: Array, pal: Dictionary, per_walls: int = 13,
		lo: int = 8, hi: int = 26, energy: float = 2.4, light_range: float = 7.5) -> void:
	## Wrought brackets with a live flame and a real (flickering) point light.
	## Buildings reuse this with a sparser, softer setting (hall sconces).
	var want = clampi(wall_edges.size() / per_walls, lo, hi)
	var picks = _spaced_sample(wall_edges, want, 5)
	var flame_col: Color = pal.get("torch", Color(1.0, 0.62, 0.28))
	for entry in picks:
		var pos: Vector2i = entry["pos"]
		var dir: Vector2i = entry["dir"]
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
		light.light_energy = energy
		light.omni_range = light_range
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
	spr.pixel_size = 0.03125
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
	## Sealed passages recessed into the wall at a few cistern mouths: the
	## pack's dark stone archway, tinted to the sewer stone.
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
		root.position = Vector3(pos.x + 0.5, 0, pos.y + 0.5) + into * 0.35
		_visuals_root.add_child(root)
		# A dark stone archway (the pack's) reads as the sealed passage.
		var arch := _make_prop_sprite("gate_small", 1.25)
		arch.modulate = Color(1, 1, 1).lerp(pal["wall_a"], 0.25)
		root.add_child(arch)
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
	## Damp rubble (the cave pack's pebbles and stones) and algae patches
	## hugging the walls. No pack draws an algae smear: those stay flat
	## tinted slabs.
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
			rubble.append({
				"pos": center,
				"scale": 0.7 + _tile_noise(pos.x, pos.y, 91) * 0.4,
				"color": pal["wall_b"].lerp(pal["floor_b"], n * 3.0),
			})
		elif n > 0.86:
			# Flat algae smear on the floor at the wall foot.
			moss.append({
				"xform": Transform3D(rot * Basis.from_scale(Vector3(0.5, 0.02, 0.5)),
					center + Vector3(0, 0.01, 0)),
				"color": pal["accent"].lerp(pal["floor_a"], _tile_noise(pos.x, pos.y, 89) * 0.5),
			})
	_add_prop_decos(rubble, "rubble")
	if not moss.is_empty():
		_add_multimesh(BoxMesh.new(), moss)

func _place_bones(floor_cells: Array, pal: Dictionary, per_cells: int, lo: int, hi: int) -> void:
	## Old remains — a skull and a few ribs — scattered on dry floor. Sewers
	## and caves both use it; the tint follows the location's floor.
	if floor_cells.is_empty():
		return
	var entries: Array = []
	for c in floor_cells:
		entries.append({"pos": c})
	var want = clampi(floor_cells.size() / per_cells, lo, hi)
	var items: Array = []
	for entry in _spaced_sample(entries, want, 6):
		var c: Vector2i = entry["pos"]
		var jx = (_tile_noise(c.x, c.y, 61) - 0.5) * 0.5
		var jz = (_tile_noise(c.x, c.y, 67) - 0.5) * 0.5
		items.append({"pos": Vector3(c.x + 0.5 + jx, 0.0, c.y + 0.5 + jz),
				"scale": 0.85 + _tile_noise(c.x, c.y, 111) * 0.3,
				"color": pal["floor_a"].lerp(Color.WHITE, 0.6)})
	_add_prop_decos(items, "bones")

func _place_sewer_reeds(water_tiles: Array, pal: Dictionary) -> void:
	## Marsh reeds rooted where the channel water meets dry brick — the one
	## thing that grows down here besides the algae.
	var candidates: Array = []
	for pos in water_tiles:
		# Water tile with at least one dry floor neighbor = channel edge.
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var np: Vector2i = pos + dir
			if is_floor(np) and not is_water(np) and not _reserved.has(np):
				candidates.append({"pos": pos})
				break
	var want = clampi(candidates.size() / 9, 6, 20)
	var items: Array = []
	for entry in _spaced_sample(candidates, want, 4):
		var pos: Vector2i = entry["pos"]
		var jx = (_tile_noise(pos.x, pos.y, 61) - 0.5) * 0.4
		var jz = (_tile_noise(pos.x, pos.y, 67) - 0.5) * 0.4
		items.append({
			"pos": Vector3(pos.x + 0.5 + jx, -0.1, pos.y + 0.5 + jz),
			"scale": 0.7 + _tile_noise(pos.x, pos.y, 69) * 0.5,
			"color": pal["accent"],
		})
	_add_prop_decos(items, "reeds")

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
		# A pit is impassable: never let it be the only way into a tile.
		if not _can_block_tile(pos):
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
	# Over-sample so spots rejected below (nook entrances) are replaced by the
	# next picks in the same deterministic order.
	var picks = _spaced_sample(clearing_cells, want * 3, 7)
	var placed := 0
	for i in range(picks.size()):
		if placed >= want:
			break
		var pos: Vector2i = picks[i]["pos"]
		if pos == player_start or _reserved.has(pos):
			continue
		# The trunk blocks movement: skip spots where that would seal off a tile.
		if not _claim_obstacle(pos):
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
		placed += 1

func _build_tree_mesh(root: Node3D, scale: float, climbable: bool) -> void:
	## Climbable/landmark tree visual: the same billboard pixel tree the rest
	## of the forest uses (no smooth mesh spheres — style guide §7), scaled up
	## into a canopy tree. The climbable sprite variant carries a painted low
	## bough and trunk pegs as the climb cue.
	# The Greenwood's big canopy trees (Craftpix forest pack); the climbable
	# one is the variant with the open trunk and low bough.
	var v := _first_prop_variant("forest_tree_climb" if climbable else "forest_tree_big")
	var sprite := Sprite3D.new()
	sprite.texture = load(v["path"])
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # writes depth: per-pixel sorting
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.pixel_size = 0.03125
	var s: float = 1.75 * scale * float(v["scale"])  # taller than the treeline so it reads as THE tree
	sprite.scale = Vector3(s, s, s)
	sprite.position = Vector3(0, CameraView.SPRITE_LIFT, 0)
	root.add_child(sprite)


## One pack sprite for a role (its first variant).
func _first_prop_variant(role: String) -> Dictionary:
	var cfg: Dictionary = CraftpixProps.PROPS[role]
	var v: Dictionary = cfg["variants"][0]
	return {"path": v["path"], "w": v["w"], "h": v["h"], "scale": cfg["scale"]}

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
# INTERIOR HAZARDS — cave spiderwebs and building wall darts (traps pass 1).
# Both ride the same trap_defs pipeline as the forest traps: single-use,
# sprung by main._trigger_terrain_traps_for when anything steps on a tile.
# ============================================

func _place_cave_webs() -> void:
	## Spiked spiderwebs strung across the tunnels — sticky silk threaded with
	## barbs. Stepping in deals damage and snares (player: Slowed; enemy: root).
	var candidates: Array = []
	for x in range(1, GRID_W - 1):
		for y in range(1, GRID_H - 1):
			var pos := Vector2i(x, y)
			if not is_floor(pos) or _reserved.has(pos):
				continue
			# Webs anchor where silk has something to hang from: beside a wall.
			var wall_neighbors := 0
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not is_floor(pos + off):
					wall_neighbors += 1
			if wall_neighbors >= 1:
				candidates.append({"pos": pos})
	if candidates.is_empty():
		return
	var want = clampi(candidates.size() / 40, 3, 8)
	var picks = _spaced_sample(candidates, want, 6)
	for i in range(picks.size()):
		var pos: Vector2i = picks[i]["pos"]
		if _reserved.has(pos):
			continue
		_reserved[pos] = true
		var root = Node3D.new()
		root.name = "SpikedWeb_%d" % i
		root.position = Vector3(pos.x + 0.5, 0.03, pos.y + 0.5)
		_visuals_root.add_child(root)
		_build_web_mesh(root)
		trap_defs.append({
			"kind": "web",
			"tiles": [pos],
			"grid_pos": pos,
			"node": root,
			"sprung": false,
		})

func _build_web_mesh(root: Node3D) -> void:
	## The cave pack's spiderweb, standing over the tile and sized to one
	## tile across (the variant is picked by cell, so neighbours differ).
	var cfg: Dictionary = CraftpixProps.PROPS["cave_web"]
	var k := int(_tile_noise(int(floor(root.position.x)), int(floor(root.position.z)), 97) * cfg["variants"].size())
	var v: Dictionary = cfg["variants"][k % cfg["variants"].size()]
	var web := CraftpixProps.make_sprite("cave_web", 36.0 / float(v["w"]) / float(cfg["scale"]), k)
	web.name = "WebSprite"
	root.add_child(web)

func _place_wall_dart_shooters() -> void:
	## Dart shooters set into the building's walls: a nozzle at chest height
	## covering the tiles straight out from the wall face. Stepping into the
	## firing line takes a dart. Single use, like the hunters' tripwires.
	var candidates: Array = []
	for x in range(1, GRID_W - 1):
		for y in range(1, GRID_H - 1):
			var pos := Vector2i(x, y)
			if not is_floor(pos) or _reserved.has(pos):
				continue
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not is_floor(pos + off):
					# floor tile with a wall behind it: a mount point firing -off
					candidates.append({"pos": pos, "wall": pos + off, "dir": -off})
					break
	if candidates.is_empty():
		return
	var want = clampi(candidates.size() / 35, 2, 6)
	var picks = _spaced_sample(candidates, want, 7)
	var shooter_idx := 0
	for cand in picks:
		var pos: Vector2i = cand["pos"]
		if _reserved.has(pos):
			continue
		# The firing line: from the wall face out across the room, up to 3 tiles.
		var dir: Vector2i = cand["dir"]
		var line: Array = []
		for step in range(3):
			var t: Vector2i = pos + dir * step
			if not is_floor(t) or _reserved.has(t):
				break
			line.append(t)
		if line.is_empty():
			continue
		for t in line:
			_reserved[t] = true
		var root = Node3D.new()
		root.name = "WallDart_%d" % shooter_idx
		shooter_idx += 1
		_visuals_root.add_child(root)
		_build_wall_dart_mesh(root, cand["wall"], dir)
		trap_defs.append({
			"kind": "wall_dart",
			"tiles": line,
			"grid_pos": pos,
			"node": root,
			"sprung": false,
		})

func _build_wall_dart_mesh(root: Node3D, wall: Vector2i, dir: Vector2i) -> void:
	# The housing: a small brass plate proud of the wall face.
	var face = Vector3(wall.x + 0.5 + dir.x * 0.45, 1.0, wall.y + 0.5 + dir.y * 0.45)
	var plate = MeshInstance3D.new()
	var pmesh = BoxMesh.new()
	pmesh.size = Vector3(0.06 + abs(dir.y) * 0.30, 0.36, 0.06 + abs(dir.x) * 0.30)
	plate.mesh = pmesh
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.45, 0.36, 0.18)
	pmat.metallic = 0.0  # no modern specular pop
	pmat.roughness = 0.6
	plate.material_override = pmat
	plate.position = face
	root.add_child(plate)
	# The nozzle: a short dark tube aimed down the firing line.
	var tube = MeshInstance3D.new()
	var tmesh = CylinderMesh.new()
	tmesh.top_radius = 0.05
	tmesh.bottom_radius = 0.05
	tmesh.height = 0.22
	tmesh.radial_segments = 6
	tube.mesh = tmesh
	if dir.x != 0:
		tube.rotation_degrees = Vector3(0, 0, 90)
	else:
		tube.rotation_degrees = Vector3(90, 0, 0)
	var tmat = StandardMaterial3D.new()
	tmat.albedo_color = Color(0.14, 0.12, 0.10)
	tmat.metallic = 0.0  # no modern specular pop
	tube.material_override = tmat
	tube.position = face + Vector3(dir.x * 0.12, 0, dir.y * 0.12)
	root.add_child(tube)

# ============================================
# FOREST DECORATIONS — background trees, stumps, bushes, ferns and squirrels.
# Pure visuals, placed in the decoration pass (avoids reserved feature tiles).
# ============================================

func _build_forest_decorations() -> void:
	var pal = get_palette()
	var trunk_items: Array = []
	var fern_items: Array = []
	var stump_items: Array = []
	var bush_items: Array = []
	var tuft_items: Array = []
	var shroom_items: Array = []
	var flower_items: Array = []
	var berry_items: Array = []
	var pebble_items: Array = []
	var log_candidates: Array = []
	var leaffall_candidates: Array = []
	var butterfly_cells: Array = []
	var floor_cells: Array = []
	var clearing_cells: Array = []

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
			var p3 = Vector3(x + 0.5 + jx, y_base, z + 0.5 + jz)
			if near_wall and n < 0.30 and _claim_obstacle(pos):
				# Treeline tree (billboard sprite). Trunks block movement.
				trunk_items.append({"pos": p3,
						"scale": 0.8 + _tile_noise(x, z, 73) * 0.7,
						"color": pal["leaf"].lerp(pal["leaf_b"], _tile_noise(x, z, 79))})
				if n < 0.05:
					leaffall_candidates.append({"pos": pos})
			elif near_wall and n < 0.38:
				# Mossy stump (billboard sprite).
				stump_items.append({"pos": p3,
						"scale": 0.7 + _tile_noise(x, z, 81) * 0.4,
						"color": pal["bark"].lerp(pal["accent"], 0.3)})
			elif near_wall and n < 0.46:
				# Toadstool clumps in the treeline shade.
				shroom_items.append({"pos": p3,
						"scale": 0.8 + _tile_noise(x, z, 82) * 0.4, "color": Color.WHITE})
			elif trail[x][z]:
				pass  # trails stay clear underfoot
			elif _is_trail_edge(x, z) and _tile_noise(x, z, 105) < 0.30:
				# Stones kicked to the trail's edge.
				pebble_items.append({"pos": p3,
						"scale": 0.8 + _tile_noise(x, z, 107) * 0.5,
						"color": pal["cliff"].lerp(pal["step"], 0.4)})
			elif n > 0.93:
				if _tile_noise(x, z, 109) < 0.45:
					# Berry bushes: the woodland's one splash of red.
					berry_items.append({"pos": p3,
							"scale": 0.7 + _tile_noise(x, z, 83) * 0.6,
							"color": pal["accent"].lerp(pal["leaf"], _tile_noise(x, z, 89))})
				else:
					bush_items.append({"pos": p3,
							"scale": 0.7 + _tile_noise(x, z, 83) * 0.6,
							"color": pal["accent"].lerp(pal["leaf"], _tile_noise(x, z, 89))})
			elif n > 0.88:
				fern_items.append({"pos": p3,
						"scale": 0.75 + _tile_noise(x, z, 91) * 0.4,
						"color": pal["leaf"]})
			elif n > 0.845:
				# Woodland flowers in the open clearings.
				flower_items.append({"pos": p3,
						"scale": 0.75 + _tile_noise(x, z, 92) * 0.4, "color": Color.WHITE})
				if n > 0.86:
					butterfly_cells.append({"pos": pos})
			elif n > 0.70:
				# Tall grass fills the clearings between the mown battle lanes.
				tuft_items.append({"pos": p3,
						"scale": 0.75 + _tile_noise(x, z, 93) * 0.5,
						"color": pal["floor_a"].lerp(pal["accent"], _tile_noise(x, z, 95) * 0.6)})
			elif not near_wall and n > 0.665:
				log_candidates.append({"pos": pos, "p3": p3})
			elif not near_wall:
				clearing_cells.append({"pos": pos})

	# Fallen logs: sparse and spaced so each one reads as a landmark.
	var log_items: Array = []
	for entry in _spaced_sample(log_candidates, clampi(log_candidates.size() / 12, 4, 9), 7):
		log_items.append({"pos": entry["p3"],
				"scale": 0.85 + _tile_noise(entry["pos"].x, entry["pos"].y, 96) * 0.35,
				"color": Color.WHITE})

	_add_prop_decos(trunk_items, "tree")
	_add_prop_decos(fern_items, "fern")
	_add_prop_decos(stump_items, "stump")
	_add_prop_decos(bush_items, "bush")
	_add_prop_decos(tuft_items, "tuft")
	_add_prop_decos(shroom_items, "shroom")
	_add_prop_decos(flower_items, "flower")
	_add_prop_decos(log_items, "log")
	_add_prop_decos(berry_items, "berry")
	_add_prop_decos(pebble_items, "pebble")

	_place_signposts(pal)
	_place_forest_squirrels(floor_cells)
	_place_crows(clearing_cells)
	_place_butterflies(butterfly_cells)
	_place_leaf_falls(leaffall_candidates)
	_add_cloud_shadows()
	print("[DUNGEON] Forest dressing: %d trees, %d stumps, %d bushes (%d berried), %d tufts, %d shrooms, %d logs, %d pebbles" % [
		trunk_items.size(), stump_items.size(), bush_items.size() + berry_items.size(), berry_items.size(),
		tuft_items.size(), shroom_items.size(), log_items.size(), pebble_items.size()])

func _place_leaf_falls(candidates: Array) -> void:
	## Drifting leaves shed from the canopy near the treeline.
	if candidates.is_empty():
		return
	var want = clampi(candidates.size() / 6, 4, 12)
	var picks = _spaced_sample(candidates, want, 9)
	for i in range(picks.size()):
		var pos: Vector2i = picks[i]["pos"]
		var lf = LeafFall.new()
		lf.name = "LeafFall_%d" % i
		_visuals_root.add_child(lf)
		lf.setup(Vector3(pos.x + 0.5, 0.0, pos.y + 0.5), _layout_seed + i * 389)

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
# MOVEMENT-BLOCKING SCENERY
# ============================================

func _is_walkable_for_obstacle_test(pos: Vector2i) -> bool:
	## Floor that a unit can actually stand on: not wall, pit, or an obstacle
	## already claimed. Reserved tiles (chests, waypoints, traps) stay walkable
	## here — treating them as blocked would let a tree wall them off.
	if not is_floor(pos):
		return false
	if pit_tiles.has(pos):
		return false
	if obstacle_tiles.has(pos):
		return false
	return true

func _can_block_tile(pos: Vector2i) -> bool:
	## True if turning `pos` into an obstacle cannot disconnect the map: every
	## walkable orthogonal neighbour stays linked through the ring of eight
	## cells around it. Conservative (a longer detour elsewhere is ignored),
	## which is exactly what keeps corridors and doorways tree-free.
	if not _is_walkable_for_obstacle_test(pos):
		return false
	if pos == player_start:
		return false
	# Enemy spawn points must stay open.
	for zone in spawn_zones:
		if pos in zone.get("spawn_points", []):
			return false
	# Ring around pos, clockwise from north. Consecutive ring cells are
	# orthogonally adjacent, so a run of walkable ring cells is connected.
	var ring := [
		Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
		Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
	]
	var walk: Array[bool] = []
	for d in ring:
		walk.append(_is_walkable_for_obstacle_test(pos + d))
	var ortho_count := 0
	for i in [0, 2, 4, 6]:
		if walk[i]:
			ortho_count += 1
	if ortho_count <= 1:
		return true  # dead end or isolated: nothing to sever
	# Count runs of walkable ring cells that contain an orthogonal neighbour.
	# All orthogonal neighbours are still connected iff there is exactly one.
	var start := -1
	for i in range(8):
		if not walk[i]:
			start = i
			break
	if start < 0:
		return true  # full ring: always connected
	var runs := 0
	var in_run := false
	var run_has_ortho := false
	for k in range(1, 9):
		var i := (start + k) % 8
		if walk[i]:
			in_run = true
			if i % 2 == 0:
				run_has_ortho = true
		elif in_run:
			if run_has_ortho:
				runs += 1
			in_run = false
			run_has_ortho = false
	return runs == 1

func _claim_obstacle(pos: Vector2i) -> bool:
	## Reserve `pos` as movement-blocking scenery if that is safe (see
	## _can_block_tile). Returns whether it was claimed.
	if not _can_block_tile(pos):
		return false
	obstacle_tiles[pos] = true
	return true

func get_obstacle_tiles() -> Array[Vector2i]:
	## Every scenery tile no unit may enter (for pathfinding blocked lists).
	var out: Array[Vector2i] = []
	for pos in obstacle_tiles.keys():
		out.append(pos)
	return out

func is_obstacle(grid_pos: Vector2i) -> bool:
	return obstacle_tiles.has(grid_pos)

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

# ============================================
# CAVE DRESSING — stalagmites (floor), stalactites (ceiling), divots and pebbles.
# Puddles are flagged in the layout and drawn by _build_autotile_ground. The whole
# place reads as a network of dripping stone tunnels.
# ============================================

func _build_cave_decorations() -> void:
	var pal = get_palette()
	var stalagmite_items: Array = []  # upward cones rooted to the floor
	var stalactite_items: Array = []  # downward cones hanging into the tunnel
	var divot_items: Array = []       # small dark floor depressions
	var pebble_items: Array = []      # scattered rubble (pack cave rocks)
	var shroom_items: Array = []      # pale fungus clumps in the dark
	var crystal_items: Array = []     # teal crystal clusters at the walls
	var stone_items: Array = []       # loose stone scatter (billboard)
	var dry_cells: Array = []         # for the bone scatter

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
				# (The designer's spikes, flipped: ~40 pack texels on average.)
				var hs = 0.5 + _tile_noise(x, z, 77) * 0.7
				stalactite_items.append({
					"pos": Vector3(x + 0.5 + jx, 2.9 - 40.0 * 0.03125 * hs, z + 0.5 + jz),
					"scale": hs,
					"color": pal["wall_a"].lerp(pal["wall_b"], n * 2.0),
				})
			elif near_wall and n < 0.36:
				# Pale cave fungus clustered where the drip water gathers.
				shroom_items.append({
					"pos": Vector3(x + 0.5 + jx, 0.0, z + 0.5 + jz),
					"scale": 0.7 + _tile_noise(x, z, 78) * 0.5,
					"color": Color.WHITE,
				})
			elif near_wall and n < 0.42:
				# Crystal clusters growing out of the wall foot — the cave's
				# one cold glow (a few carry a dim light, see below).
				crystal_items.append({
					"pos": Vector3(x + 0.5 + jx, 0.0, z + 0.5 + jz),
					"scale": 0.7 + _tile_noise(x, z, 113) * 0.6,
					"color": Color.WHITE,
				})
			elif near_wall and n > 0.70 and n <= 0.78:
				stone_items.append({
					"pos": Vector3(x + 0.5 + jx, 0.0, z + 0.5 + jz),
					"scale": 0.8 + _tile_noise(x, z, 107) * 0.5,
					"color": pal["wall_a"].lerp(pal["step"], 0.3),
				})
			elif not is_wet and not near_wall and n > 0.905 and n <= 0.93:
				dry_cells.append(pos)
			elif not is_wet and n > 0.93:
				# A shallow divot pressed into the cave floor.
				divot_items.append({
					"xform": Transform3D(rot * Basis.from_scale(Vector3(0.5, 0.04, 0.5)),
						Vector3(x + 0.5 + jx, -0.06, z + 0.5 + jz)),
					"color": pal["floor_b"].darkened(0.4),
				})
			elif near_wall and n > 0.78:
				pebble_items.append({
					"pos": Vector3(x + 0.5 + jx, 0.0, z + 0.5 + jz),
					"scale": 0.6 + _tile_noise(x, z, 91) * 0.4,
					"color": pal["cliff"].lerp(pal["wall_b"], _tile_noise(x, z, 103)),
				})

	_add_prop_decos(stalagmite_items, "stalagmite")
	_add_prop_decos(stalactite_items, "stalactite")
	_add_prop_decos(shroom_items, "shroom")
	_add_prop_decos(crystal_items, "crystal")
	_add_prop_decos(stone_items, "pebble")
	_add_prop_decos(pebble_items, "rock")
	_place_bones(dry_cells, pal, 4, 2, 8)

	# No pack draws a floor divot: those stay flat tinted slabs.
	_add_multimesh(BoxMesh.new(), divot_items)

	# A few slow drips falling from the larger stalactites add life to the gloom.
	_place_cave_drips(stalactite_items)
	_place_crystal_lights(crystal_items)
	if hell_cave():
		_place_lava_glow()
	print("[DUNGEON] Cave dressing: %d stalagmites, %d stalactites, %d crystals, %d divots" % [
		stalagmite_items.size(), stalactite_items.size(), crystal_items.size(), divot_items.size()])

## Hell's caves: a low orange light over every few lava tiles, so the pools
## light the rock round them.
func _place_lava_glow() -> void:
	var made := 0
	for x in range(GRID_W):
		for z in range(GRID_H):
			if made >= 14 or not is_water(Vector2i(x, z)) or (x + z * 3) % 3 != 0:
				continue
			var light = OmniLight3D.new()
			light.light_color = Color(1.0, 0.45, 0.15)
			light.light_energy = 1.4
			light.omni_range = 3.5
			light.omni_attenuation = 2.0
			light.shadow_enabled = false
			light.position = Vector3(x + 0.5, 0.5, z + 0.5)
			_visuals_root.add_child(light)
			made += 1

func _place_crystal_lights(crystal_items: Array) -> void:
	## Every few crystal clusters carries a dim, tight teal light — enough to
	## pick the cluster out of the dark, never a soft modern glow.
	if crystal_items.is_empty():
		return
	var want = clampi(crystal_items.size() / 5, 1, 8)
	var step = maxi(1, crystal_items.size() / want)
	var made = 0
	for i in range(0, crystal_items.size(), step):
		if made >= want:
			break
		var origin: Vector3 = crystal_items[i]["pos"]
		var light = OmniLight3D.new()
		light.light_color = Color(0.45, 0.85, 0.85)
		light.light_energy = 0.9
		light.omni_range = 3.2
		light.omni_attenuation = 2.0
		light.shadow_enabled = false
		light.position = origin + Vector3(0, 0.45, 0)
		_visuals_root.add_child(light)
		made += 1

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
	var changed := false
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
					changed = true
	if changed:
		prompts_changed.emit()

## The revealed tiles as one byte per tile (x-major), to carry across a
## scene change or a save: the layout is deterministic per world and
## interior, so the bytes map straight back onto the same ground.
func get_revealed_bytes() -> PackedByteArray:
	var out := PackedByteArray()
	if not _fog_initialized:
		return out
	out.resize(GRID_W * GRID_H)
	for x in range(GRID_W):
		for z in range(GRID_H):
			out[x * GRID_H + z] = 1 if _revealed[x][z] else 0
	return out

## Reveal again what a snapshot from this same layout had revealed (a
## snapshot of another size is ignored: a different layout).
func restore_revealed(bytes: PackedByteArray) -> void:
	if not _fog_initialized or bytes.size() != GRID_W * GRID_H:
		return
	var changed := false
	for x in range(GRID_W):
		for z in range(GRID_H):
			var i := x * GRID_H + z
			if bytes[i] != 0 and not _revealed[x][z]:
				_revealed[x][z] = true
				_fog_mm.set_instance_transform(i, _fog_hidden_xform())
				changed = true
	if changed:
		prompts_changed.emit()
		print("[DUNGEON] Fog of war restored: explored ground stays revealed")

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
		elif cave_count <= building_count:
			# Caves and buildings take turns by what has been placed, so a
			# room that could not take one (its way in a lava pool) leaves
			# the turn for the next room rather than skipping it.
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

		# The way in must be open ground (not a lava pool); then block the
		# footprint and verify the world is still fully walkable.
		if not is_floor(entrance) or not _try_block_footprint(footprint):
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
				# Frostreach's caves are frozen (designer, 2026-11-05).
				id = ("icecave_%d" if world_level == 3 else "cave_%d") % cave_count
				display_name = "Ice Cave" if world_level == 3 else "Cave"
				cave_count += 1

		_create_site(kind, id, display_name, footprint, entrance, fx, fz, fp_w, fp_d)

	_place_mountain_site(candidates)
	_place_closet_site(candidates)
	_place_act2_sites(candidates)
	_place_hidden_graveyard(candidates)
	print("[DUNGEON] Placed %d enterable sites" % site_nodes.size())

## The Mountain Pass (Act 1, Mountains habitat; 2026-11-05): World 1's
## trail up into the mountains, in the free field room nearest the top of
## the map (the mountains rise to the north) that is not the far room the
## Old Graveyard takes. Picked without the layout's dice, so the rest of the
## world keeps the layout it had.
func _place_mountain_site(candidates: Array) -> void:
	if world_level != 1 or interior_kind != "" or candidates.size() < 2:
		return
	var far_idx := -1
	var far_d := -1
	for room_idx in candidates:
		var c: Vector2i = rooms[room_idx]["rect"].get_center()
		var d := absi(c.x - player_start.x) + absi(c.y - player_start.y)
		if d > far_d:
			far_d = d
			far_idx = room_idx
	var pick := -1
	var best := 1 << 30
	for room_idx in candidates:
		if room_idx == far_idx:
			continue
		var c: Vector2i = rooms[room_idx]["rect"].get_center()
		var score: int = c.y * 4 - c.x
		if score < best:
			best = score
			pick = room_idx
	if pick < 0:
		return
	var rect: Rect2i = rooms[pick]["rect"]
	var fp_w := 3
	var fp_d := 3
	var fx = clampi(rect.get_center().x - fp_w / 2, rect.position.x + 1, rect.end.x - fp_w - 1)
	var fz = rect.position.y + 1
	var footprint: Array = []
	for x in range(fx, fx + fp_w):
		for z in range(fz, fz + fp_d):
			footprint.append(Vector2i(x, z))
	var entrance = Vector2i(fx + fp_w / 2, fz + fp_d)
	if not is_floor(entrance) or not _try_block_footprint(footprint):
		return
	candidates.erase(pick)
	rooms[pick]["kind"] = "site"
	_create_site("mountains", "mountains_0", "Mountain Pass", footprint, entrance, fx, fz, fp_w, fp_d)

func _place_hidden_graveyard(candidates: Array) -> void:
	## What the Crows Saw: World 1 hides an Old Graveyard in the field room
	## farthest from the start. It is built like any site but stays off the
	## minimap (site["hidden"]) until the player walks up to it.
	if world_level != 1 or interior_kind != "" or candidates.is_empty():
		return
	var best_idx := -1
	var best_d := -1
	for room_idx in candidates:
		var c: Vector2i = rooms[room_idx]["rect"].get_center()
		var d := absi(c.x - player_start.x) + absi(c.y - player_start.y)
		if d > best_d:
			best_d = d
			best_idx = room_idx
	if best_idx < 0:
		return
	var rect: Rect2i = rooms[best_idx]["rect"]
	var fp_w := 3
	var fp_d := 3
	var fx = clampi(rect.get_center().x - fp_w / 2, rect.position.x + 1, rect.end.x - fp_w - 1)
	var fz = rect.position.y + 1
	var footprint: Array = []
	for x in range(fx, fx + fp_w):
		for z in range(fz, fz + fp_d):
			footprint.append(Vector2i(x, z))
	var entrance = Vector2i(fx + fp_w / 2, fz + fp_d)
	if not is_floor(entrance) or not _try_block_footprint(footprint):
		return
	rooms[best_idx]["kind"] = "site"
	_create_site("graveyard", "graveyard_0", "Old Graveyard", footprint, entrance, fx, fz, fp_w, fp_d)
	var site: Dictionary = site_nodes[site_nodes.size() - 1]
	site["hidden"] = not _opened_chests_ref.get(_site_found_key("graveyard_0"), false)

func _site_found_key(site_id: String) -> String:
	return "world_%d_site_%s_found" % [world_level, site_id]

func get_hidden_site_near(player_grid: Vector2i, radius: int = 2) -> int:
	for i in range(site_nodes.size()):
		if not site_nodes[i].get("hidden", false):
			continue
		var sp: Vector2i = site_nodes[i]["grid_pos"]
		if absi(player_grid.x - sp.x) + absi(player_grid.y - sp.y) <= radius:
			return i
	return -1

func discover_site(index: int) -> void:
	## A hidden site found on foot: onto the minimap, remembered in world state.
	if index < 0 or index >= site_nodes.size():
		return
	site_nodes[index]["hidden"] = false
	_opened_chests_ref[_site_found_key(site_nodes[index]["id"])] = true
	prompts_changed.emit()

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

	# The footprint's own ground: its tiles are walls for pathing, so the
	# autotile floor skips them and the backdrop showed through the structure.
	# The footprint's tiles are blocked (no room floor is laid there), so the
	# site lays its own: built sites (buildings, the graveyard) pave it in
	# the tinted stone; a cave mouth, sewer grate or forest trail gets the
	# biome's plain ground so it sits in the field rather than on a slab.
	var ground = MeshInstance3D.new()
	var gmesh = PlaneMesh.new()
	gmesh.size = Vector2(fp_w, fp_d)
	ground.mesh = gmesh
	if kind in ["building", "graveyard"]:
		ground.material_override = _pixel_mat(floor_texture_path(), get_palette().get("floor_a", Color(0.5, 0.5, 0.45)))
	else:
		ground.material_override = _pixel_mat(floor_texture_path(), Color(1, 1, 1))
	ground.position = Vector3(0, 0.006, 0)
	site_root.add_child(ground)

	var ruin_site := interior_kind == "" and art_world() in [2, 3, 4] and kind in ["building", "cave"]
	if ruin_site and art_world() == 3:
		_build_winter_site(site_root, kind, fp_w, fp_d)
	elif ruin_site and art_world() == 4:
		_build_cursed_site(site_root, kind, fp_w, fp_d, fx + fz)
	elif ruin_site:
		_build_desert_site(site_root, kind, fp_w, fp_d, fx + fz)
	else: match kind:
		"graveyard":
			_build_graveyard_gate(site_root, fp_w, fp_d)
		"building":
			_build_building_exterior(site_root, fp_w, fp_d)
		"sewer":
			_build_sewer_entrance(site_root, fp_w, fp_d)
		"forest":
			_build_forest_entrance(site_root, fp_w, fp_d)
		"mountains":
			_build_mountain_entrance(site_root, fp_w, fp_d)
		"closet":
			_build_closet_entrance(site_root, fp_w, fp_d)
		"rift":
			_build_rift_entrance(site_root, fp_w, fp_d)
		"citadel":
			_build_citadel_entrance(site_root, fp_w, fp_d)
		"ascent":
			_build_ascent_entrance(site_root, fp_w, fp_d)
		_:
			_build_cave_entrance(site_root, fp_w, fp_d)
	# Its walls, pillars and lintels stay under the sprites, so the player at
	# the door draws over the structure behind him (CameraView).
	CameraView.flatten_below_sprites(site_root)

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

## The Amber Wastes' sites (the designer's desert ruins, 2026-10-29): a
## building is a temple over a stair going down (the falcon-headed temple or
## the orb shrine, by site), a cave a rock-framed arch or the collapsed ruin
## with its dark opening. Feet on the footprint's south edge, the opening
## over the entrance tile.
func _build_desert_site(root: Node3D, kind: String, fp_w: int, fp_d: int, salt: int) -> void:
	var role := "desert_ruin"
	var k := 0
	if kind == "building":
		k = 0 if salt % 2 == 0 else 1          # falcon temple / orb shrine
	else:
		if salt % 2 == 0:
			role = "desert_cave_arch"
		else:
			k = 2                               # the collapsed ruin
	var door_x := 0.5 if fp_w % 2 == 0 else 0.0
	var sprite := _make_prop_sprite(role, 1.0, k)
	if sprite:
		sprite.position = Vector3(door_x, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.05)
		root.add_child(sprite)


## Frostreach's sites (the designer's snowbound stone, 2026-10-29): a
## building is the stone hut with its dark doorway, a cave the snowy arch.
## Feet on the footprint's south edge.
func _build_winter_site(root: Node3D, kind: String, fp_w: int, fp_d: int) -> void:
	var sprite := _make_prop_sprite("winter_hut" if kind == "building" else "winter_ruin", 1.0, 0)
	var door_x := 0.5 if fp_w % 2 == 0 else 0.0
	if sprite:
		sprite.position = Vector3(door_x, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.05)
		root.add_child(sprite)


## Emberfall's sites (the designer's vein-wrapped ruins, 2026-10-29): a
## building is the broken ring with its door or the arch, by site; a cave the
## mound over its dark mouth. Feet on the footprint's south edge.
func _build_cursed_site(root: Node3D, kind: String, fp_w: int, fp_d: int, salt: int) -> void:
	var role := "cursed_cave" if kind == "cave" else "cursed_ruin"
	var k := 0 if kind == "cave" else (5 if salt % 2 == 0 else 1)
	var door_x := 0.5 if fp_w % 2 == 0 else 0.0
	var sprite := _make_prop_sprite(role, 1.0, k)
	if sprite:
		sprite.position = Vector3(door_x, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.05)
		root.add_child(sprite)


func _build_building_exterior(root: Node3D, fp_w: int, fp_d: int) -> void:
	## Simple generic structure: stone walls, pitched roof, door, lit windows.
	var w = fp_w - 0.3
	var d = fp_d - 0.3
	var wall_h = 1.8

	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(w, wall_h, d)
	body.mesh = body_mesh
	body.material_override = _pixel_mat(CP_TEX + "/wall_undead.png", Color(0.62, 0.58, 0.52))  # grey stone (undead pack)
	body.position = Vector3(0, wall_h / 2.0, 0)
	root.add_child(body)

	var roof = MeshInstance3D.new()
	var roof_mesh = PrismMesh.new()
	roof_mesh.size = Vector3(d + 0.2, 0.9, w + 0.2)
	roof_mesh.left_to_right = 0.5
	roof.mesh = roof_mesh
	roof.material_override = _pixel_mat(CP_TEX + "/wall_undead.png", Color(0.46, 0.50, 0.60))  # slate: the grey stone fill under a blue cast
	roof.rotation_degrees.y = 90.0  # Ridge runs along the building's long axis
	roof.position = Vector3(0, wall_h + 0.45, 0)
	root.add_child(roof)

	# Door on the south face, centred on the entrance tile: a 4-wide
	# footprint has its centre on a tile edge, so the door (and the windows
	# around it) shift half a tile to line up with where the player stands.
	var door_x := 0.5 if fp_w % 2 == 0 else 0.0
	var door := _make_prop_sprite("gate_small", 1.15)  # the pack's dark stone archway
	door.position = Vector3(door_x, CameraView.SPRITE_LIFT, d / 2.0 + 0.42)  # clear of the roof's overhang from above
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
		window.position = Vector3(door_x + side * w * 0.3, 1.1, d / 2.0 + 0.02)
		root.add_child(window)

func _build_graveyard_gate(root: Node3D, fp_w: int, fp_d: int) -> void:
	## Two weathered stone pillars and a lintel framing the undead pack's
	## skull-mouth doorway, the way down. (No pack draws stone gateposts or
	## iron bars: the pillars and lintel stay modelled in the wall stone; the
	## old modelled iron bars are gone — the pack doorway is the opening.)
	var stone := _pixel_mat(wall_texture_path(), Color(0.62, 0.66, 0.64))
	for side in [-1.0, 1.0]:
		var pillar = MeshInstance3D.new()
		var pm = BoxMesh.new()
		pm.size = Vector3(0.7, 2.4, 0.7)
		pillar.mesh = pm
		pillar.material_override = stone
		pillar.position = Vector3(side * (fp_w * 0.5 - 0.4), 1.2, fp_d / 2.0 - 0.5)
		root.add_child(pillar)
	var lintel = MeshInstance3D.new()
	var lm = BoxMesh.new()
	lm.size = Vector3(fp_w - 0.2, 0.5, 0.8)
	lintel.mesh = lm
	lintel.material_override = stone
	lintel.position = Vector3(0, 2.6, fp_d / 2.0 - 0.5)
	root.add_child(lintel)
	# The way down: the undead pack's skull-mouth doorway.
	var door := _make_prop_sprite("undead_skull_door", 1.5)
	door.position = Vector3(0, CameraView.SPRITE_LIFT, -0.3)
	root.add_child(door)
	# A few leaning headstones around the gate (pack graves)
	for k in range(3):
		var grave := _make_prop_sprite("undead_grave", 1.0, k * 3)
		var gx := -fp_w * 0.5 + 0.3 + k * (fp_w - 0.6) / 2.0
		grave.position = Vector3(gx, CameraView.SPRITE_LIFT, -fp_d / 2.0 + 0.3)
		root.add_child(grave)

func _build_cave_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	## A cave mouth built from the cave pack: big rock clusters piled into a
	## mound, a dark stone archway opening on the south face.
	var pal = get_palette()
	var back_z := -fp_d / 2.0 + 0.55
	# Three clusters across the back, two more flanking the mouth.
	for spec in [[-fp_w * 0.32, back_z, 1.35, 0], [0.0, back_z - 0.15, 1.55, 1], [fp_w * 0.32, back_z, 1.35, 2],
			[-fp_w * 0.42, fp_d / 2.0 - 0.55, 1.1, 3], [fp_w * 0.42, fp_d / 2.0 - 0.55, 1.1, 0]]:
		var rock := _make_prop_sprite("cave_boulder", spec[2], spec[3])
		rock.position = Vector3(spec[0], CameraView.SPRITE_LIFT, spec[1])
		rock.modulate = Color(1, 1, 1).lerp(pal["cliff"], 0.2)
		root.add_child(rock)

	# The dark opening itself: the pack archway on the entrance side.
	var gate := _make_prop_sprite("gate_small", 1.3)
	gate.position = Vector3(0, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.2)
	root.add_child(gate)

func _build_sewer_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	## A low stone kerb with the pack's dark archway descending into the dark —
	## the shaft the player climbs down to reach the sewers. (No pack draws a
	## kerb or iron bars: the kerb stays a box in the cave pack's wall stone;
	## the old modelled bars are gone — the pack archway is the opening.)
	var brick = _pixel_mat(CP_TEX + "/wall_cave.png", Color(0.36, 0.38, 0.36))  # dark cave stone

	# A low stone kerb around the shaft — seen from above it is a small dark
	# square the pack's archway opens out of, not a slab the size of a room.
	var block = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = Vector3(1.6, 0.35, 1.2)
	block.mesh = bmesh
	block.material_override = brick
	block.position = Vector3(0, 0.17, fp_d / 2.0 - 0.9)
	root.add_child(block)
	# The field pack's rocks pile up around the kerb so the headworks reads
	# as part of the ground it sits in.
	for spec in [[-1.0, -0.6, 0], [1.0, -0.4, 1], [-0.7, 0.5, 2], [0.9, 0.6, 3]]:
		var rock := _make_prop_sprite("field_rock", 0.5, spec[2])
		if rock:
			rock.position = Vector3(spec[0], CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.9 + spec[1])
			root.add_child(rock)

	# The dark descending mouth: the pack's stone archway.
	var mouth := _make_prop_sprite("gate_small", 1.2)
	mouth.position = Vector3(0, CameraView.SPRITE_LIFT, fp_d / 2.0 + 0.25)  # in front of the block, seen from above
	root.add_child(mouth)

	# A weak green glow leaking up from below.
	var glow = OmniLight3D.new()
	glow.light_color = Color(0.4, 0.7, 0.5)
	glow.light_energy = 0.8
	glow.omni_range = 3.5
	glow.omni_attenuation = 2.0  # tighter falloff, less modern gradient
	glow.position = Vector3(0, 0.3, fp_d / 2.0 - 0.1)
	root.add_child(glow)

func _build_mountain_entrance(root: Node3D, fp_w: int, fp_d: int) -> void:
	## The foot of the Mountain Pass: snow-capped boulders heaped on the
	## rock block (_build_site_blocks), two snow pines flanking the trail and
	## a carved bear totem marking where it climbs (the winter pack's).
	var back_z := -fp_d / 2.0 + 0.5
	for spec in [[-fp_w * 0.3, back_z, 1.2, 0], [0.05, back_z - 0.2, 1.4, 1], [fp_w * 0.32, back_z, 1.2, 2]]:
		var rock := _make_prop_sprite("wallrock_snow", spec[2], spec[3])
		if rock:
			rock.position = Vector3(spec[0], CameraView.SPRITE_LIFT, spec[1])
			root.add_child(rock)
	for side in [-1.0, 1.0]:
		var pine := _make_prop_sprite("winter_tree", 0.9, 0 if side < 0 else 1)
		if pine:
			pine.position = Vector3(side * fp_w * 0.4, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.6)
			root.add_child(pine)
	var totem := _make_prop_sprite("winter_idol", 0.8)
	if totem:
		totem.position = Vector3(0.0, CameraView.SPRITE_LIFT, fp_d / 2.0 - 0.45)
		root.add_child(totem)

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
		tree.texture = load(_first_prop_variant("field_tree")["path"])
		tree.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tree.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # writes depth: per-pixel sorting
		tree.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		tree.shaded = false
		tree.pixel_size = 0.03125
		var tree_scale := 1.6 * float(_first_prop_variant("field_tree")["scale"])   # the designer's tree at 64 texels a tile: ~4 tiles tall, as the pack tree stood
		tree.scale = Vector3(tree_scale, tree_scale, tree_scale)
		tree.position = Vector3(side * fp_w * 0.42, 0, -0.1)
		CameraView.stand_on_ground(tree)  # on its roots at the sprite height, sorted by row
		root.add_child(tree)

	# The woods behind the arch fill the rest of the footprint (nobody walks
	# there): bushes and young trees of the field.
	for spec in [[-0.55, -fp_d / 2.0 + 0.45, "field_bush", 0.9, 0], [0.55, -fp_d / 2.0 + 0.4, "field_bush", 0.9, 2],
			[0.0, -fp_d / 2.0 + 0.2, "field_tree_small", 1.0, 1]]:
		var shrub := _make_prop_sprite(spec[2], spec[3], spec[4])
		if shrub:
			shrub.position = Vector3(spec[0], CameraView.SPRITE_LIFT, spec[1])
			root.add_child(shrub)

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

func _place_exit_site(at: Vector2i = Vector2i(-9999, -9999), id: String = "exit", kind: String = "exit",
		text: String = "Exit", prompt: String = "[Shift] Leave", nudge: Vector3 = Vector3.ZERO,
		tint: Color = Color(0.8, 0.9, 1.0)) -> void:
	## Inside an interior: a glowing doorway (the pack archway) at the entry
	## tile, back the way the player came — or, with `at` / `kind`, another
	## threshold such as Hell's Door once it is broken. With no `nudge` the
	## arch sits just behind the entry, on the side the player came in by.
	if at.x < -9000:
		at = player_start
	if nudge == Vector3.ZERO:
		nudge = exit_nudge
	var site_root = Node3D.new()
	site_root.name = "Site_%s" % id
	var world_pos = grid_manager.grid_to_world(at)
	world_pos += nudge  # Sit just behind the tile so the player isn't on it
	site_root.position = world_pos

	var portal := _make_prop_sprite("gate_small", 1.3)  # the pack archway, lit from below
	portal.modulate = tint
	site_root.add_child(portal)
	var glow = OmniLight3D.new()
	glow.light_color = tint
	glow.light_energy = 0.9
	glow.omni_range = 3.0
	glow.position = Vector3(0, 0.6, 0.4)
	site_root.add_child(glow)

	var label = Label3D.new()
	label.text = text
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint
	label.position = Vector3(0, 2.0, 0)
	WorldText.crisp(label)
	site_root.add_child(label)

	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = prompt
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
		"grid_pos": at,
		"id": id,
		"kind": kind,
		"display_name": text,
		"label_node": interact_label,
		"footprint": [],
	})

## Tiles a structure stands on, which the land's edge dressing (treeline,
## cliff walls, landmarks) leaves alone: the sites' footprints and the
## waypoint shrines' sides and back (waypoint_block_tiles).
func _structure_tiles() -> Dictionary:
	var tiles := _all_site_footprint_tiles()
	for c in waypoint_block_tiles:
		tiles[c] = true
	return tiles

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
			"site", "boss":
				want = false
		if not want:
			continue
		var cell = _pick_free_cell(rect, placed)
		if cell.x < 0:
			continue
		placed.append(cell)
		# The overworld starter chest of act 1 is the player's first loot:
		# it always holds a card and a common item so deck-building and
		# gearing start before the first fight.
		_create_chest(cell, kind == "start" and world_level == 1)
	# The Ice Troll Lair's vault: one legendary chest at its back.
	if interior_kind == "trolllair":
		_create_chest(troll_vault_chest_cell, false, true)

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
			# Partially opened: gold was claimed, apply item/card/pack claim flags
			chest_nodes[i]["contents"]["_gold_claimed"] = true
			if state.get("item_taken", false):
				chest_nodes[i]["contents"]["item"] = null
			if state.get("card_taken", false):
				chest_nodes[i]["contents"]["card"] = null
			if state.get("pack_taken", false):
				chest_nodes[i]["contents"]["card_pack"] = null
			# Check if now fully looted
			var contents = chest_nodes[i]["contents"]
			if contents.get("item") == null and contents.get("card") == null \
					and contents.get("card_pack") == null:
				mark_chest_looted(i)
		else:
			# Legacy true value or fully looted
			mark_chest_looted(i)

func _set_chest_open_visual(index: int) -> void:
	var sprite: Sprite3D = chest_nodes[index].get("sprite")
	if sprite:
		var design: String = chest_nodes[index].get("design", "wood")
		_chest_sprite_art(sprite, _first_prop_variant("chest_%s_open" % design))


## A chest sprite wearing one of its art variants ({path, w, scale}): its
## bottom edge on the ground and centred, at the art's own texel size (the
## designer's chests are 64 texels a tile, scale 0.5) — the open chest is
## taller than the closed one, so the feet stay put when it swings open.
static func _chest_sprite_art(sprite: Sprite3D, v: Dictionary) -> void:
	sprite.texture = load(v["path"])
	sprite.centered = false
	sprite.pixel_size = 0.03125 * float(v.get("scale", 1.0))
	sprite.offset = Vector2(-float(v["w"]) * 0.5, 0.0)


## Chest design from its loot (the designer's chests, 2026-10-29): mythic
## gear gets the ice-crystal chest, legendary gear the red-gold chest under
## its crest, rare gear (and card packs) the red-gold chest, everything else
## iron-banded wood.
func _chest_design(contents: Dictionary) -> String:
	var item = contents.get("item")
	if item is ItemData:
		if int(item.rarity) >= ItemData.Rarity.MYTHIC:
			return "mythic"
		if int(item.rarity) >= ItemData.Rarity.LEGENDARY:
			return "legendary"
		if int(item.rarity) >= ItemData.Rarity.RARE:
			return "rare"
	if contents.get("card_pack") != null:
		return "rare"
	return "wood"

func _create_chest(grid_pos: Vector2i, starter: bool = false, legendary: bool = false) -> void:
	var chest_root = Node3D.new()
	chest_root.name = "TreasureChest_%d" % chest_nodes.size()

	# 16-bit billboard chest (closed sprite; swapped to the open sprite on open).
	# Contact shadow is painted into the sprite, same as the other ground props.
	# Generate chest contents first (deterministic seed, so the same chest
	# always holds the same loot) — the chest's design is chosen by them.
	var chest_index = chest_nodes.size()
	var contents = _generate_chest_contents(chest_index, starter, legendary)
	var design := _chest_design(contents)
	var closed := _first_prop_variant("chest_%s_closed" % design)
	var sprite = Sprite3D.new()
	sprite.name = "ChestSprite"
	_chest_sprite_art(sprite, closed)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD  # writes depth: per-pixel sorting
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	# Bottom edge of the sprite rests on the ground, matching _add_sprite_decos.
	sprite.position = Vector3(0, CameraView.SPRITE_LIFT, 0)
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

	chest_nodes.append({
		"node": chest_root,
		"design": design,
		"grid_pos": grid_pos,
		"opened": false,
		"looted": false,
		"contents": contents,
		"sprite": sprite
	})

# Per-character salt for chest rolls (CharacterData.get_loot_seed()), set by
# main before initialize(). Without it every character would open identical
# chests; with it a chest still holds the same loot for the character who
# found it, across saves and world transitions.
var loot_salt: int = 0

func _generate_chest_contents(chest_index: int, starter: bool = false, legendary: bool = false) -> Dictionary:
	# Deterministic RNG seeded by world + chest index + the character's loot
	# salt, so the same chest always generates the same loot for this
	# character even if the dungeon is recreated.
	var rng = RandomNumberGenerator.new()
	if interior_id == "":
		rng.seed = hash("chest_w%d_c%d_s%d" % [world_level, chest_index, loot_salt])
	else:
		rng.seed = hash("chest_w%d_%s_c%d_s%d" % [world_level, interior_id, chest_index, loot_salt])

	var gold = rng.randi_range(15, 50) + (world_level - 1) * 10
	var contents: Dictionary = {"gold": gold, "item": null, "card": null, "card_pack": null}

	if legendary:
		# A hoard's chest (the Ice Troll Lair's vault, designer 2026-11-05):
		# a legendary item and a heap of gold — the one chest that breaks the
		# rule that legendaries never come from chests.
		var pool = ItemData.get_items_of_rarity(ItemData.Rarity.LEGENDARY)
		if not pool.is_empty():
			contents["item"] = pool[rng.randi() % pool.size()]
		contents["gold"] = gold * 4
		return contents
	if starter:
		# Act-1 starter chest: a card AND a common item, guaranteed.
		var commons = ItemData.get_items_of_rarity(ItemData.Rarity.COMMON)
		if not commons.is_empty():
			contents["item"] = commons[rng.randi() % commons.size()]
		contents["card"] = _get_random_card(rng)
	elif rng.randf() < 0.5:
		contents["item"] = _get_random_item(rng)
	elif rng.randf() < DropRates.PACK_CHANCE_OF_CARD_DROP:
		# A sealed card pack: the TIER is seeded (same chest, same pack), the
		# cards inside roll fresh when it's ripped open.
		contents["card_pack"] = DropRates.roll_weighted(DropRates.PACK_TIER_WEIGHTS, rng)
	else:
		contents["card"] = _get_random_card(rng)

	return contents

# Act-1 mythic cap: set by main once this character's act-1 mythic has
# dropped — act-1 chests then stop offering mythics entirely.
var block_act1_mythics: bool = false

func _get_random_item(rng: RandomNumberGenerator) -> ItemData:
	# Chests roll the common/rare chest table (see DropRates); legendaries
	# and mythics never come from chests — the near-guaranteed act mythic
	# comes from the per-kill layer in main. Only level-1 items ever drop —
	# higher item levels exist solely through the forge.
	var weights: Dictionary = DropRates.CHEST_ITEM_WEIGHTS
	if block_act1_mythics and world_level == 1 and weights.has(ItemData.Rarity.MYTHIC):
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
	return DropRates.roll_card(DropRates.CARD_WEIGHTS, rng)

# ============================================
# SPAWN ZONES (derived from rooms; difficulty scales with world + depth)
# ============================================

func _define_spawn_zones() -> void:
	spawn_zones.clear()

	if interior_kind == "dojo":
		return  # nothing lives here but the dummies main places
	if is_boss_room(interior_id):
		return  # the boss, its guard and its structures are placed by main up front

	if interior_kind == "sewer":
		_define_sewer_spawn_zones()
		return

	if interior_kind == "forest":
		_define_forest_spawn_zones()
		return

	if interior_kind == "mountains":
		_define_mountain_spawn_zones()
		return

	if interior_kind == "icecave":
		_define_ice_cave_spawn_zones()
		return

	if interior_kind == "closet":
		_define_closet_spawn_zones()
		return

	match interior_kind:
		"rift":
			_define_rift_spawn_zones()
			return
		"citadel":
			_define_citadel_spawn_zones()
			return
		"ascent":
			_define_ascent_spawn_zones()
			return

	if interior_kind == "trolllair":
		_define_troll_lair_spawn_zones()
		return

	if interior_kind == "graveyard":
		_define_graveyard_spawn_zones()
		return

	# Enemy tiers scale with world level
	var base_melee = Enemy.EnemyType.WERERAT if world_level <= 2 else Enemy.EnemyType.SKELETON
	var mid_melee = Enemy.EnemyType.SKELETON if world_level <= 2 else Enemy.EnemyType.ARMORED_TROLL
	var heavy = Enemy.EnemyType.ARMORED_TROLL if world_level <= 3 else Enemy.EnemyType.ELITE
	var ranged = Enemy.EnemyType.ARCHER_RAT
	# Caves belong to the Fire Goblin warband: soldiers up front, mages at
	# range, a shaman (the teaching Channel) in every cave, trolls in the deep.
	if interior_kind == "cave":
		base_melee = Enemy.EnemyType.FIRE_GOBLIN_SOLDIER
		mid_melee = Enemy.EnemyType.FIRE_GOBLIN_SOLDIER
		ranged = Enemy.EnemyType.FIRE_GOBLIN_MAGE
	# The Underworld (World 2, Hell: its surface and its caves) is the
	# demons' (STORY.md 5.4, Underworld): succubi, magma spiders, mind eaters
	# and specters the rank and file (rolled per enemy, UNDERWORLD_TRASH),
	# demons the mid tier, ash harpies at range, ifrits the heavies. Its caves
	# keep a Fire Goblin Shaman (the Channel lesson) and lead to the Labyrinth.
	var underworld := world_level == 2 and interior_kind in ["", "cave"]
	if underworld:
		base_melee = Enemy.EnemyType.SUCCUBUS
		mid_melee = Enemy.EnemyType.DEMON
		heavy = Enemy.EnemyType.IFRIT
		ranged = Enemy.EnemyType.ASH_HARPY
	var deep_lords := [Enemy.EnemyType.IFRIT, Enemy.EnemyType.INFLAMED_MINOTAUR, Enemy.EnemyType.DJINN]
	var deep_lord_i := 0
	var shaman_placed := false

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
			var picked = _pick_enemy_type(depth, kind, base_melee, mid_melee, heavy, ranged)
			if underworld and picked == base_melee:
				picked = UNDERWORLD_TRASH[_rng.randi_range(0, UNDERWORLD_TRASH.size() - 1)]
			types.append(picked)
		# Deep cave chambers are guarded by an elite-grade enemy
		if kind == "deep" and types.size() > 0:
			types[0] = heavy if world_level < 3 else Enemy.EnemyType.ELITE
		# Act 2+ overworld deep rooms hold the lords of the deep — the
		# Ferryman's Toll targets — one per room, cycling through the three.
		if kind == "deep" and interior_kind == "" and world_level >= 2 and types.size() > 0:
			types[0] = deep_lords[deep_lord_i % deep_lords.size()]
			deep_lord_i += 1
		# Every cave gets at least one Fire Goblin Shaman.
		if interior_kind == "cave" and not shaman_placed and types.size() > 1:
			types[types.size() - 1] = Enemy.EnemyType.FIRE_GOBLIN_SHAMAN
			shaman_placed = true
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

## The Underworld's rank and file (_define_spawn_zones). (The Pit Fiend is
## a mock-up with no moves yet and stays out.)
const UNDERWORLD_TRASH := [Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.MAGMA_SPIDER,
	Enemy.EnemyType.MIND_EATER, Enemy.EnemyType.SPECTER]

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

func _define_graveyard_spawn_zones() -> void:
	## The dead of the Old Graveyard: shamblers near the gate, the hunters of
	## the night deeper in, and a Necromancer holding the deepest crypt.
	var shallow := [Enemy.EnemyType.ZOMBIE, Enemy.EnemyType.TREASURE_BUNNY, Enemy.EnemyType.SKELETON, Enemy.EnemyType.SCREECHER]
	var deep := [Enemy.EnemyType.WEREWOLF, Enemy.EnemyType.VAMPIRE, Enemy.EnemyType.CRYPT_CRAWLER, Enemy.EnemyType.ZOMBIE]
	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue
		if kind != "deep" and _rng.randf() >= 0.85:
			continue
		var depth = float(rect.get_center().x) / float(GRID_W)
		var count = clampi(2 + rect.get_area() / 36, 2, 5)
		var points: Array = []
		var types: Array = []
		for _i in range(count):
			var cell = _pick_free_cell(rect, points)
			if cell.x < 0:
				continue
			points.append(cell)
			var pool: Array = deep if depth > 0.55 else shallow
			types.append(pool[_rng.randi_range(0, pool.size() - 1)])
		if kind == "deep" and types.size() > 0:
			types[0] = Enemy.EnemyType.NECROMANCER
		if points.is_empty():
			continue
		spawn_zones.append({
			"trigger_rect": rect.grow(1),
			"spawn_points": points,
			"enemy_types": types,
			"spawned": false,
		})
	for zone in spawn_zones:
		for p in zone["spawn_points"]:
			_reserved[p] = true
	print("[DUNGEON] Defined %d graveyard spawn zones" % spawn_zones.size())

func _define_arena_zone(rect: Rect2i, mid_melee, heavy, ranged) -> void:
	var c = rect.get_center()
	var boss_points: Array = []
	var boss_types: Array = []
	if world_level >= 4:
		boss_points = [c + Vector2i(0, -2), c + Vector2i(2, 0), c + Vector2i(0, 2), c + Vector2i(3, -1)]
		boss_types = [Enemy.EnemyType.BOSS, Enemy.EnemyType.ELITE, heavy, ranged]
	elif world_level == 2:
		# The Underworld's arena: an ifrit, two demons and a harpy overhead.
		boss_points = [c + Vector2i(0, -2), c + Vector2i(2, 1), c + Vector2i(-2, 1), c + Vector2i(1, 3)]
		boss_types = [Enemy.EnemyType.IFRIT, Enemy.EnemyType.DEMON, Enemy.EnemyType.DEMON, ranged]
	elif world_level >= 2:
		boss_points = [c + Vector2i(0, -2), c + Vector2i(2, 1), c + Vector2i(1, 3)]
		boss_types = [Enemy.EnemyType.ELITE, heavy, ranged]
	else:
		boss_points = [c + Vector2i(0, 0), c + Vector2i(2, 2)]
		boss_types = [Enemy.EnemyType.SKELETON, mid_melee]

	# A point on rock or lava moves to the nearest open floor.
	for i in range(boss_points.size()):
		if not is_floor(boss_points[i]):
			var near := pick_free_cell_near(boss_points[i], 3)
			if near.x >= 0:
				boss_points[i] = near
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
			_define_rat_king_guard_zone(rect)
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
		# The deepest chamber is guarded by a Sewer Cobra.
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

func _define_rat_king_guard_zone(rect: Rect2i) -> void:
	## The cistern outside the Rat King's Lair: his door guard. The king
	## himself waits inside the lair (interior "ratking_lair", entered through
	## the door _place_lair_door builds here).
	var c = rect.get_center()
	var points: Array = []
	var types: Array = []
	var guard = [
		Enemy.EnemyType.WERERAT, Enemy.EnemyType.WERERAT, Enemy.EnemyType.ARCHER_RAT,
		Enemy.EnemyType.WERERAT, Enemy.EnemyType.SWARM,
	]
	var offsets = [
		Vector2i(-2, -1), Vector2i(2, -1), Vector2i(0, -2), Vector2i(-3, 1), Vector2i(3, 1),
	]
	for i in range(offsets.size()):
		var cell = c + offsets[i]
		if is_floor(cell) and not _reserved.has(cell) and not (cell in points):
			points.append(cell)
			types.append(guard[i])
	if points.is_empty():
		return
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

## The Mountain Pass's creatures (STORY.md 5.4, Mountains): weregoats and
## sabertooths roam the lower snowfields; the snow wraiths keep to the
## ledges and outcrops, throwing down at whoever climbs; ice trolls guard the
## upper terraces; wyverns, white manticores and rocs ride the heights (they
## fly over the cliffs). The summit holds the strongest. (The Granite
## Colossus has no moves yet and stays out.)
func _define_mountain_spawn_zones() -> void:
	var low := [Enemy.EnemyType.WEREGOAT, Enemy.EnemyType.WEREGOAT, Enemy.EnemyType.SABERTOOTH]
	var perch := [Enemy.EnemyType.SNOW_WRAITH, Enemy.EnemyType.SNOW_WRAITH, Enemy.EnemyType.ICE_TROLL]
	var fliers := [Enemy.EnemyType.WYVERN, Enemy.EnemyType.WHITE_MANTICORE, Enemy.EnemyType.ROC]
	for room in rooms:
		var rect: Rect2i = room["rect"]
		var kind: String = room["kind"]
		if kind in ["start", "exit"]:
			continue
		var high: bool = int(room["elev"]) >= MOUNTAIN_TIER_STEP or room.get("outcrop", false)
		if kind != "deep" and _rng.randf() >= (0.85 if high else 0.6):
			continue
		var n := clampi(2 + rect.get_area() / 45, 2, 4)
		var points: Array = []
		var types: Array = []
		for _i in range(n * 3):
			if points.size() >= n:
				break
			var cell := _pick_free_cell(rect, points)
			if cell.x < 0:
				continue
			if step_tiles.has(cell):
				continue   # nobody waits on the steps themselves
			points.append(cell)
			var e: int = elevation[cell.x][cell.y]
			if e >= MOUNTAIN_TIER_STEP and _rng.randf() < 0.25:
				types.append(fliers[_rng.randi_range(0, fliers.size() - 1)])
			elif e >= MOUNTAIN_TIER_STEP or room.get("outcrop", false):
				types.append(perch[_rng.randi_range(0, perch.size() - 1)])
			else:
				types.append(low[_rng.randi_range(0, low.size() - 1)])
		if points.is_empty():
			continue
		if kind == "deep":
			types[0] = Enemy.EnemyType.ICE_TROLL
			if types.size() > 1:
				types[1] = fliers[_rng.randi_range(0, fliers.size() - 1)]
		spawn_zones.append({
			"trigger_rect": rect.grow(2),
			"spawn_points": points,
			"enemy_types": types,
			"spawned": false,
		})
	for z in spawn_zones:
		for p in z["spawn_points"]:
			_reserved[p] = true
	print("[DUNGEON] Defined %d mountain spawn zones" % spawn_zones.size())

# ============================================
# WAYPOINTS
# ============================================

func _place_waypoints() -> void:
	var mid_z = GRID_H / 2
	waypoint_block_tiles.clear()

	# Transport portal in starting room. The hero arrives on its front step.
	_create_waypoint(Vector2i(3, mid_z), "transport", "Transport Portal")
	player_start = Vector2i(3, mid_z + 1)
	_reserve_area(player_start, 1)

	# Exit to next world (in the far exit room)
	if world_level < 5:
		_create_waypoint(Vector2i(GRID_W - 4, mid_z), "next_world", "World %d" % (world_level + 1))

	# Exit to previous world (a row clear of the Transport Portal's back)
	if world_level > 1:
		_create_waypoint(Vector2i(3, mid_z - 4), "prev_world", "World %d" % (world_level - 1))
	for wp in waypoint_nodes:
		_block_waypoint_shrine(wp["grid_pos"])

## The shrine is a platform you walk up onto from the front, over its steps
## (designer, 2026-11-05: "they should walk on top of the portal floor, not
## through it ... they can not walk out the back or the side"): the tiles
## its stones stand on — either side of its tile and the two rows behind —
## are blocked, so its tile opens only to the south.
func _block_waypoint_shrine(cell: Vector2i) -> void:
	var tiles: Array = shrine_block_cells(cell)
	var front := cell + Vector2i(0, 1)
	if not is_floor(front):
		return
	var free: Array = []
	for c in tiles:
		if c.x >= 0 and c.y >= 0 and c.x < GRID_W and c.y < GRID_H:
			free.append(c)
	if _try_block_footprint(free):
		for c in free:
			waypoint_block_tiles[c] = true

## The tiles a waypoint shrine on `cell` stands on besides its own (the
## sides and the two rows behind): town uses it too.
static func shrine_block_cells(cell: Vector2i) -> Array:
	var out: Array = []
	for dz in [-2, -1, 0]:
		for dx in [-1, 0, 1]:
			var c := cell + Vector2i(dx, dz)
			if c != cell:
				out.append(c)
	return out

func _create_waypoint(grid_pos: Vector2i, target: String, display_name: String) -> void:
	var wp_root = Node3D.new()
	wp_root.name = "Waypoint_%s" % target

	# The designer's shrine (2026-10-29; was a rune ring on a dirt mound,
	# tinted per destination): dim until discovered.
	var pillar := make_waypoint_shrine(false)
	wp_root.add_child(pillar)

	# Label
	var label = Label3D.new()
	label.name = "WaypointLabel"
	label.text = display_name
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 1.0, 0.8)
	label.position = Vector3(0, 0.8, -2.6)   # over the shrine's stones (-z is up the screen)
	WorldText.crisp(label)
	wp_root.add_child(label)

	# Interact label (shown when nearby)
	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Travel"
	interact_label.font_size = 16
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 1.55, 0)  # clear of the name at far zoom
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

## The designer's waypoint shrine (2026-10-29): rune circle, raven statues
## and glowing standing stones, set just behind its tile so a unit on the
## tile draws in front of it. Dim until discovered.
const WAYPOINT_DIM := Color(0.5, 0.52, 0.58)

static func make_waypoint_shrine(lit: bool) -> Sprite3D:
	var shrine := CraftpixProps.make_sprite("waypoint_shrine", 1.0, 0)
	shrine.name = "Shrine"
	shrine.position.z -= 0.55
	# Drawn behind whoever stands on it (a hero on the tile is lifted onto
	# the platform; the shrine's stone face must not cover his feet).
	shrine.sorting_offset = -0.6
	shrine.modulate = Color.WHITE if lit else WAYPOINT_DIM
	return shrine


func discover_waypoint(index: int) -> bool:
	## Marks a waypoint as discovered. Returns true if newly discovered.
	if index < 0 or index >= waypoint_nodes.size():
		return false
	if waypoint_nodes[index]["discovered"]:
		return false
	waypoint_nodes[index]["discovered"] = true
	prompts_changed.emit()
	# Visual change: the ring lights up to full strength once activated
	var pillar = waypoint_nodes[index]["pillar_mesh"] as Sprite3D
	if pillar:
		pillar.modulate = Color.WHITE   # the shrine lights up
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
# THE FEATHER TRAIL (What the Crows Saw)
# ============================================
# Crow feathers dropped every few tiles along the walk from the start to a
# hidden site, each laid flat with its tip pointing at the next one. Only
# placed while the quest is active (Main asks for it); revealed with the fog.

var feather_nodes: Array = []  # [{node, grid_pos}]
const FEATHER_SPACING := 4
static var _feather_tex: ImageTexture = null

static func _feather_texture() -> ImageTexture:
	## A 10x18 pixel crow feather: dark vane, pale quill, tip at the top.
	if _feather_tex:
		return _feather_tex
	var img := Image.create(10, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var vane := Color(0.13, 0.12, 0.16)
	var edge := Color(0.24, 0.23, 0.30)
	var quill := Color(0.72, 0.68, 0.60)
	for y in range(18):
		var half: int
		if y < 3:
			half = y            # tip
		elif y < 13:
			half = 3            # body
		else:
			half = 3 - (y - 12) # taper toward the quill
		if half < 0:
			half = 0
		for x in range(5 - half, 5 + half):
			img.set_pixel(x, y, edge if (x == 5 - half or x == 4 + half) else vane)
	for y in range(6, 18):
		img.set_pixel(4, y, quill)
	for y in range(15, 18):
		img.set_pixel(5, y, quill)
	_feather_tex = ImageTexture.create_from_image(img)
	return _feather_tex

func place_feather_trail(target: Vector2i) -> void:
	## Drop feathers along the shortest floor path from the start to `target`.
	clear_feather_trail()
	var path := _floor_path(player_start, target)
	if path.size() < 2:
		return
	var samples: Array = []
	var i := FEATHER_SPACING
	while i < path.size() - 1:
		samples.append(path[i])
		i += FEATHER_SPACING
	for k in range(samples.size()):
		var cell: Vector2i = samples[k]
		var next: Vector2i = samples[k + 1] if k + 1 < samples.size() else target
		_create_feather(cell, next)
	# Crows keep watch at the gate.
	_place_crows_at(target, 2)
	print("[DUNGEON] Feather trail: %d feathers toward %s" % [feather_nodes.size(), target])
	prompts_changed.emit()

func clear_feather_trail() -> void:
	for f in feather_nodes:
		var n = f.get("node")
		if n and is_instance_valid(n):
			n.queue_free()
	feather_nodes.clear()
	prompts_changed.emit()

func _create_feather(cell: Vector2i, points_to: Vector2i) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "Feather_%d" % feather_nodes.size()
	sprite.texture = _feather_texture()
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.pixel_size = 0.045
	# Lay it flat (tip toward -Z), then spin it about Y so the tip points at
	# the next feather: rotating -Z by θ about Y gives (-sin θ, -cos θ).
	var d := Vector2(points_to.x - cell.x, points_to.y - cell.y)
	var theta := atan2(-d.x, -d.y) if d.length() > 0.01 else 0.0
	sprite.rotation_degrees = Vector3(-90, rad_to_deg(theta), 0)
	var pos := grid_manager.grid_to_world(cell)
	pos.y = get_elevation_world_y(cell) + 0.03
	# Off-centre so the feather sits beside the trail rather than under feet.
	pos.x += 0.25
	pos.z -= 0.2
	sprite.position = pos
	sprite.visible = false
	_visuals_root.add_child(sprite)
	feather_nodes.append({"node": sprite, "grid_pos": cell})

func _place_crows_at(cell: Vector2i, count: int) -> void:
	for i in range(count):
		var c := pick_free_cell_near(cell, 3)
		if c.x < 0:
			return
		var crow = SewerCritter.new()
		crow.name = "TrailCrow_%d" % i
		_visuals_root.add_child(crow)
		crow.setup(Vector3(c.x + 0.5, 0.0, c.y + 0.5), _layout_seed + 977 + i * 131, "crow")

func update_feather_visibility() -> void:
	for f in feather_nodes:
		var n = f.get("node")
		if n and is_instance_valid(n):
			n.visible = is_revealed(f["grid_pos"])

func _floor_path(from: Vector2i, to: Vector2i) -> Array:
	## BFS over floor tiles (4-way). Returns the cell list from `from` to the
	## walkable cell nearest `to` (the target itself may be a blocked footprint).
	var came_from: Dictionary = {from: from}
	var frontier: Array = [from]
	var head := 0
	var best: Vector2i = from
	var best_d := absi(from.x - to.x) + absi(from.y - to.y)
	while head < frontier.size():
		var cur: Vector2i = frontier[head]
		head += 1
		var d := absi(cur.x - to.x) + absi(cur.y - to.y)
		if d < best_d:
			best_d = d
			best = cur
			if d == 0:
				break
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + dir
			if came_from.has(nxt):
				continue
			if nxt.x < 0 or nxt.x >= GRID_W or nxt.y < 0 or nxt.y >= GRID_H:
				continue
			if grid[nxt.x][nxt.y] != Tile.FLOOR:
				continue
			came_from[nxt] = cur
			frontier.append(nxt)
	var path: Array = []
	var trace: Vector2i = best
	while trace != from:
		path.push_front(trace)
		trace = came_from[trace]
	path.push_front(from)
	return path

# ============================================
# THE DROWNED SHRINE (The Faithless) + TRAP DISARMING
# ============================================
func _place_shrine() -> void:
	## The Faithless' shrine stands in the sewer's deepest chamber.
	if interior_kind != "sewer":
		return
	for room in rooms:
		if room["kind"] != "deep":
			continue
		var cell = _pick_free_cell(room["rect"], [])
		if cell.x < 0:
			return
		var root = Node3D.new()
		root.name = "DrownedShrine"
		var plinth = MeshInstance3D.new()
		var pm = BoxMesh.new()
		pm.size = Vector3(0.9, 0.5, 0.9)
		plinth.mesh = pm
		plinth.material_override = _pixel_mat(wall_texture_path(), Color(0.55, 0.5, 0.6))
		plinth.position = Vector3(0, 0.25, 0)
		root.add_child(plinth)
		var idol := _make_prop_sprite("winter_idol", 0.9, 0)  # the designer's bear totem (2026-10-29)
		idol.modulate = Color(0.8, 0.7, 1.0)
		idol.position = Vector3(0, 0.5 + CameraView.SPRITE_LIFT, 0)
		root.add_child(idol)
		var label = Label3D.new()
		label.text = "Drowned Shrine"
		label.font_size = 20
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.85, 0.7, 1.0)
		label.position = Vector3(0, 1.7, 0)
		WorldText.crisp(label)
		root.add_child(label)
		var interact = Label3D.new()
		interact.name = "InteractLabel"
		interact.text = "[Shift] Shrine"
		interact.font_size = 16
		interact.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		interact.modulate = Color(1.0, 0.9, 0.4)
		interact.position = Vector3(0, 2.3, 0)
		interact.visible = false
		WorldText.crisp(interact)
		root.add_child(interact)
		var world_pos = grid_manager.grid_to_world(cell)
		world_pos.y = get_elevation_world_y(cell)
		root.position = world_pos
		_visuals_root.add_child(root)
		_reserve_area(cell, 1)
		shrine_node = {"node": root, "grid_pos": cell, "label_node": interact}
		return

func pick_room_cell(kind: String) -> Vector2i:
	## A free floor cell inside the first room of `kind` (reserved once
	## picked so nothing else lands on it), or (-1,-1) if there is none.
	for room in rooms:
		if room["kind"] != kind:
			continue
		var cell = _pick_free_cell(room["rect"], [])
		if cell.x >= 0:
			_reserved[cell] = true
			return cell
	return Vector2i(-1, -1)

func pick_free_cell_near(center: Vector2i, radius: int = 2) -> Vector2i:
	## The nearest walkable, unreserved cell within `radius` of center.
	var best := Vector2i(-1, -1)
	var best_d := 999
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var c := center + Vector2i(dx, dz)
			if c.x < 0 or c.x >= GRID_W or c.y < 0 or c.y >= GRID_H:
				continue
			if not is_floor(c) or _reserved.has(c) or is_obstacle(c) or pit_tiles.has(c):
				continue
			var d := absi(dx) + absi(dz)
			if d > 0 and d < best_d:
				best_d = d
				best = c
	if best.x >= 0:
		_reserved[best] = true
	return best

func is_near_shrine(player_grid: Vector2i) -> bool:
	if shrine_node.is_empty():
		return false
	var pos: Vector2i = shrine_node["grid_pos"]
	return absi(player_grid.x - pos.x) + absi(player_grid.y - pos.y) <= 1

func update_shrine_prompt(player_grid: Vector2i) -> void:
	if shrine_node.is_empty():
		return
	var pos: Vector2i = shrine_node["grid_pos"]
	shrine_node["node"].visible = is_revealed(pos)
	var lbl: Label3D = shrine_node["label_node"]
	if lbl:
		lbl.visible = absi(player_grid.x - pos.x) + absi(player_grid.y - pos.y) <= 2

func get_nearby_trap(player_grid: Vector2i, kind: String = "bear") -> int:
	## Index into trap_defs of an unsprung trap of `kind` within 1 tile, or -1.
	for i in range(trap_defs.size()):
		var trap: Dictionary = trap_defs[i]
		if trap.get("kind", "") != kind or trap.get("sprung", false):
			continue
		for t in trap.get("tiles", []):
			if absi(player_grid.x - t.x) + absi(player_grid.y - t.y) <= 1:
				return i
	return -1

func disarm_trap(index: int) -> bool:
	## Spring a trap harmlessly: it never triggers again and its jaws close.
	if index < 0 or index >= trap_defs.size():
		return false
	var trap: Dictionary = trap_defs[index]
	if trap.get("sprung", false):
		return false
	trap["sprung"] = true
	prompts_changed.emit()
	var node = trap.get("node")
	if node and is_instance_valid(node):
		node.scale = Vector3(1.0, 0.35, 1.0)
		for child in node.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				child.material_override = child.material_override.duplicate()
				child.material_override.albedo_color = child.material_override.albedo_color.darkened(0.45)
	return true

# ============================================
# HEALING FOUNTAINS
# ============================================
# A stone basin of holy water. Standing beside one (Shift) offers two things:
#   - Drink: restore to full health. Uses up the blessing; the basin runs dry
#     until the player pours a vial of Holy Water (dropped by enemies) back in.
#   - Bathe in the light: +20% of the XP to the next level. Once per fountain,
#     ever — it never restores.
# State persists per fountain in the world-object state dictionary shared
# with chests (keys "world_N[_interior]_fountain_i"), so it survives leaving
# and re-entering and rides along in the save file.

const FOUNTAIN_ROOM_KINDS := ["field", "chamber", "room", "deep", "clearing"]

func _place_fountains() -> void:
	if interior_kind == "dojo" or interior_kind == "trolllair" or is_boss_room(interior_id):
		return  # the dojo is a room, not a pilgrimage; a boss room is a fight
	var want: int = 2 if interior_kind == "" else 1
	var candidates: Array = []
	for room in rooms:
		if room["kind"] in FOUNTAIN_ROOM_KINDS:
			candidates.append(room)
	if candidates.size() < want:
		for room in rooms:
			if room["kind"] not in ["start", "site"] and room not in candidates:
				candidates.append(room)
	# Spread them out: farthest room from the start first, then the median one.
	candidates.sort_custom(func(a, b):
		return _room_start_distance(a) > _room_start_distance(b))
	var picks: Array = []
	if candidates.size() > 0:
		picks.append(candidates[0])
	if want > 1 and candidates.size() > 1:
		picks.append(candidates[candidates.size() / 2])
	var placed: Array[Vector2i] = []
	for room in picks:
		var cell = _pick_free_cell(room["rect"], placed)
		if cell.x < 0:
			continue
		placed.append(cell)
		_create_fountain(cell)
	_restore_fountain_state()

func _room_start_distance(room: Dictionary) -> int:
	var c: Vector2i = room["rect"].get_center()
	return absi(c.x - player_start.x) + absi(c.y - player_start.y)

func _create_fountain(grid_pos: Vector2i) -> void:
	var root = Node3D.new()
	root.name = "Fountain_%d" % fountain_nodes.size()

	# The designer's healing well (2026-10-29; was a stone basin of glowing
	# water): bright while blessed, greyed once drunk dry.
	var well := CraftpixProps.make_sprite("well_healing", 1.0, 0)
	well.name = "Well"
	well.position.z -= 0.45
	root.add_child(well)

	var label = Label3D.new()
	label.name = "FountainLabel"
	label.text = "Healing Fountain"
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.8, 0.95, 1.0)
	label.position = Vector3(0, 1.1, -2.2)   # over the well's roof
	WorldText.crisp(label)
	root.add_child(label)

	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Fountain"
	interact_label.font_size = 16
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 1.75, 0)
	interact_label.visible = false
	WorldText.crisp(interact_label)
	root.add_child(interact_label)

	var world_pos = grid_manager.grid_to_world(grid_pos)
	world_pos.y = get_elevation_world_y(grid_pos)
	root.position = world_pos
	_visuals_root.add_child(root)
	_reserve_area(grid_pos, 1)

	fountain_nodes.append({
		"node": root,
		"grid_pos": grid_pos,
		"label_node": interact_label,
		"water_mesh": well,   # the well sprite (the old basin's water mesh)
		"blessed": true,
		"xp_used": false,
	})
	_apply_fountain_visual(fountain_nodes.size() - 1)

func _fountain_key(index: int) -> String:
	if interior_id == "":
		return "world_%d_fountain_%d" % [world_level, index]
	return "world_%d_%s_fountain_%d" % [world_level, interior_id, index]

func _restore_fountain_state() -> void:
	## Fountain state lives beside chest state in the shared world-object dict.
	for i in range(fountain_nodes.size()):
		var state = _opened_chests_ref.get(_fountain_key(i))
		if state is Dictionary:
			fountain_nodes[i]["blessed"] = bool(state.get("blessed", true))
			fountain_nodes[i]["xp_used"] = bool(state.get("xp_used", false))
			_apply_fountain_visual(i)

func set_fountain_state(index: int, blessed: bool, xp_used: bool) -> void:
	if index < 0 or index >= fountain_nodes.size():
		return
	fountain_nodes[index]["blessed"] = blessed
	fountain_nodes[index]["xp_used"] = xp_used
	_opened_chests_ref[_fountain_key(index)] = {"blessed": blessed, "xp_used": xp_used}
	_apply_fountain_visual(index)

func _apply_fountain_visual(index: int) -> void:
	var well: Sprite3D = fountain_nodes[index]["water_mesh"]
	# Blessed: the well as painted, its water glowing; drunk dry: greyed.
	well.modulate = Color.WHITE if fountain_nodes[index]["blessed"] else Color(0.48, 0.5, 0.52)

func get_nearby_fountain(player_grid: Vector2i) -> int:
	## Index of a fountain within 1 tile of the player, or -1.
	for i in range(fountain_nodes.size()):
		var pos: Vector2i = fountain_nodes[i]["grid_pos"]
		if absi(player_grid.x - pos.x) + absi(player_grid.y - pos.y) <= 1:
			return i
	return -1

func update_fountain_prompts(player_grid: Vector2i) -> void:
	for i in range(fountain_nodes.size()):
		var pos: Vector2i = fountain_nodes[i]["grid_pos"]
		fountain_nodes[i]["node"].visible = is_revealed(pos)
		var lbl: Label3D = fountain_nodes[i]["label_node"]
		if lbl:
			var dist = absi(player_grid.x - pos.x) + absi(player_grid.y - pos.y)
			lbl.visible = dist <= 2

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
	prompts_changed.emit()

	# Visual feedback on first open: swap to the open-lid sprite
	if first_open:
		_set_chest_open_visual(index)

	# Persist partial state so gold isn't re-granted if player leaves and returns
	if first_open:
		var key = _chest_key(index)
		if not _opened_chests_ref.has(key):
			_opened_chests_ref[key] = {"item_taken": false, "card_taken": false, "pack_taken": false}

	print("[DUNGEON] Opened chest %d: %s" % [index, chest_nodes[index]["contents"]])
	return chest_nodes[index]["contents"]

func mark_chest_looted(index: int) -> void:
	## Marks a chest as fully looted (all items/cards claimed). No further interaction.
	if index < 0 or index >= chest_nodes.size():
		return
	chest_nodes[index]["looted"] = true
	prompts_changed.emit()

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

func remove_chest_pack(index: int) -> void:
	## Removes the card-pack reward from a chest's contents and updates persistence.
	if index >= 0 and index < chest_nodes.size():
		chest_nodes[index]["contents"]["card_pack"] = null
		var key = _chest_key(index)
		if _opened_chests_ref.has(key) and _opened_chests_ref[key] is Dictionary:
			_opened_chests_ref[key]["pack_taken"] = true

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
	fountain_nodes.clear()
	shrine_node = {}
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
	obstacle_tiles.clear()
	trap_defs.clear()
	pit_tiles.clear()
