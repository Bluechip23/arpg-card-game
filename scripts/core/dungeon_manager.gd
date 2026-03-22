class_name DungeonManager
extends Node

## Generates and manages a progressive dungeon layout with walls, corridors,
## treasure chests, and enemy spawn zones. Supports multiple world levels
## with scaling size and enemy counts.

signal chest_interacted(chest_data: Dictionary)
signal player_entered_zone(zone_index: int)

var GRID_W: int = 50   # Default larger width
var GRID_H: int = 35   # Default larger height
const FOG_REVEAL_RADIUS: int = 5  # Tiles revealed around the player

# Tile types
enum Tile { FLOOR, WALL }

var grid: Array = []  # 2D array [x][z] of Tile
var elevation: Array = []  # 2D array [x][z] of int (0 = ground, 1+ = elevated)
var elevation_nodes: Array[MeshInstance3D] = []  # Visual meshes for elevated terrain
var wall_nodes: Array[MeshInstance3D] = []
var chest_nodes: Array = []  # [{node: Node3D, grid_pos: Vector2i, opened: bool, contents: Dictionary}]
var spawn_zones: Array = []  # [{rect: Rect2i, spawned: bool, enemies: Array}]
var elite_zone: Dictionary = {}  # {rect: Rect2i, spawned: bool}
var player_start: Vector2i = Vector2i(1, 10)

var grid_manager: GridManager
var _parent: Node3D

# World level (1-5) determines size and enemy count
var world_level: int = 1

# Waypoint nodes for travel between worlds
var waypoint_nodes: Array = []  # [{node: Node3D, grid_pos: Vector2i, target: String, label_node: Label3D}]

# Track which zones the player has triggered
var _zones_triggered: Array[bool] = []

# Fog of war
var _revealed: Array = []        # 2D bool array [x][z] - permanently revealed
var _fog_nodes: Array = []       # 2D array [x][z] of MeshInstance3D (fog planes)
var _fog_initialized: bool = false

func initialize(gm: GridManager, parent: Node3D, level: int = 1) -> void:
	grid_manager = gm
	_parent = parent
	world_level = level
	_set_world_size()
	# Update grid_manager dimensions to match
	grid_manager.grid_width = GRID_W
	grid_manager.grid_height = GRID_H
	if grid_manager.has_method("redraw_grid"):
		grid_manager.redraw_grid()
	_generate_layout()
	_generate_elevation()
	_build_walls()
	_build_elevation_visuals()
	_build_fog()
	_place_chests()
	_define_spawn_zones()
	_place_waypoints()
	# Reveal around the starting position
	reveal_around(player_start)

func _set_world_size() -> void:
	match world_level:
		1:
			GRID_W = 50
			GRID_H = 35
			player_start = Vector2i(2, 17)
		2:
			GRID_W = 60
			GRID_H = 40
			player_start = Vector2i(2, 20)
		3:
			GRID_W = 70
			GRID_H = 45
			player_start = Vector2i(2, 22)
		4:
			GRID_W = 80
			GRID_H = 50
			player_start = Vector2i(2, 25)
		5:
			GRID_W = 90
			GRID_H = 55
			player_start = Vector2i(2, 27)
		_:
			GRID_W = 50
			GRID_H = 35
			player_start = Vector2i(2, 17)

func _generate_layout() -> void:
	# Initialize all as wall
	grid.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(Tile.WALL)
		grid.append(col)

	var mid_z = GRID_H / 2

	# === STARTING AREA (left side) ===
	# Room 1: Starting room
	_carve_room(0, mid_z - 4, 6, 9)

	# Corridor east from starting room (2-wide)
	_carve_corridor_h(6, 12, mid_z)
	_carve_corridor_h(6, 12, mid_z + 1)

	# === FIRST HUB ===
	# Room 2: First hub chamber
	_carve_room(12, mid_z - 4, 7, 9)

	# === SOUTH PATH from hub ===
	# Corridor south from hub
	_carve_corridor_v(15, mid_z + 5, mid_z + 10)
	_carve_corridor_v(16, mid_z + 5, mid_z + 10)

	# Room 3: Southern cave
	_carve_room(12, mid_z + 10, 8, 6)

	# Corridor further south-east
	_carve_corridor_h(20, 27, mid_z + 12)
	_carve_corridor_h(20, 27, mid_z + 13)

	# Room 4: Southern treasure room
	_carve_room(27, mid_z + 10, 6, 6)

	# === NORTH PATH from hub ===
	# Corridor north from hub
	_carve_corridor_v(15, mid_z - 9, mid_z - 4)
	_carve_corridor_v(16, mid_z - 9, mid_z - 4)

	# Room 5: Northern chamber (elevated area - hill)
	_carve_room(12, mid_z - 13, 8, 5)

	# Corridor east from northern chamber
	_carve_corridor_h(20, 26, mid_z - 11)
	_carve_corridor_h(20, 26, mid_z - 10)

	# Room 6: Archer's perch (elevated)
	_carve_room(26, mid_z - 14, 6, 7)

	# === MAIN EAST CORRIDOR from hub ===
	_carve_corridor_h(19, 30, mid_z)
	_carve_corridor_h(19, 30, mid_z + 1)

	# Room 7: Central crossroads
	_carve_room(30, mid_z - 4, 8, 9)

	# === SOUTHEAST PATH ===
	_carve_corridor_v(34, mid_z + 5, mid_z + 10)
	_carve_corridor_v(35, mid_z + 5, mid_z + 10)

	# Room 8: Guard barracks
	_carve_room(31, mid_z + 10, 8, 6)

	# Small alcove off barracks
	_carve_room(39, mid_z + 11, 4, 4)
	_carve_corridor_h(39, 40, mid_z + 12)

	# === NORTHEAST PATH ===
	_carve_corridor_v(34, mid_z - 9, mid_z - 4)
	_carve_corridor_v(35, mid_z - 9, mid_z - 4)

	# Room 9: Armory (elevated)
	_carve_room(31, mid_z - 13, 8, 5)

	# === FAR EAST ===
	_carve_corridor_h(38, GRID_W - 8, mid_z)
	_carve_corridor_h(38, GRID_W - 8, mid_z + 1)

	# Room 10: Pre-boss arena
	_carve_room(GRID_W - 12, mid_z - 5, 8, 11)

	# Room 11: Waypoint / exit room (far east)
	_carve_room(GRID_W - 6, mid_z - 2, 5, 5)
	_carve_corridor_h(GRID_W - 5, GRID_W - 2, mid_z)
	_carve_corridor_h(GRID_W - 5, GRID_W - 2, mid_z + 1)

	# === EXTRA PATHS connecting south and north ===
	# Connect southern treasure room to guard barracks via corridor
	_carve_corridor_h(33, 35, mid_z + 12)
	_carve_corridor_v(33, mid_z + 12, mid_z + 14)
	_carve_corridor_h(28, 33, mid_z + 14)
	_carve_corridor_v(28, mid_z + 13, mid_z + 14)

	# Connect archer perch to armory via top corridor
	_carve_corridor_h(32, 35, mid_z - 12)
	_carve_corridor_h(26, 31, mid_z - 12)

	# Extra rooms for larger worlds
	if world_level >= 2:
		# Room 12: Hidden grotto (south-west)
		_carve_room(3, mid_z + 8, 5, 5)
		_carve_corridor_v(4, mid_z + 5, mid_z + 8)
		_carve_corridor_v(5, mid_z + 5, mid_z + 8)

	if world_level >= 3:
		# Room 13: Upper overlook (north-west)
		_carve_room(3, mid_z - 12, 6, 5)
		_carve_corridor_v(5, mid_z - 8, mid_z - 4)
		_carve_corridor_v(6, mid_z - 8, mid_z - 4)

func _carve_room(start_x: int, start_z: int, width: int, height: int) -> void:
	for x in range(start_x, mini(start_x + width, GRID_W)):
		for z in range(start_z, mini(start_z + height, GRID_H)):
			grid[x][z] = Tile.FLOOR

func _carve_corridor_h(from_x: int, to_x: int, z: int) -> void:
	var min_x = mini(from_x, to_x)
	var max_x = maxi(from_x, to_x)
	for x in range(min_x, mini(max_x + 1, GRID_W)):
		if z >= 0 and z < GRID_H:
			grid[x][z] = Tile.FLOOR

func _carve_corridor_v(x: int, from_z: int, to_z: int) -> void:
	var min_z = mini(from_z, to_z)
	var max_z = maxi(from_z, to_z)
	for z in range(min_z, mini(max_z + 1, GRID_H)):
		if x >= 0 and x < GRID_W:
			grid[x][z] = Tile.FLOOR

func _generate_elevation() -> void:
	# Initialize elevation grid (all 0 = ground level)
	elevation.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(0)
		elevation.append(col)

	var mid_z = GRID_H / 2

	# Elevate specific rooms to create hills / high ground
	# Room 5: Northern chamber - elevation 1
	_set_elevation_rect(12, mid_z - 13, 8, 5, 1)

	# Room 6: Archer's perch - elevation 2
	_set_elevation_rect(26, mid_z - 14, 6, 7, 2)

	# Room 9: Armory - elevation 1
	_set_elevation_rect(31, mid_z - 13, 8, 5, 1)

	# Parts of pre-boss arena have a raised platform in the center
	_set_elevation_rect(GRID_W - 10, mid_z - 2, 4, 5, 1)

	# Southern treasure room has a small elevated section
	_set_elevation_rect(29, mid_z + 11, 3, 3, 1)

	# Extra elevation for larger worlds
	if world_level >= 2:
		# Hidden grotto has elevation
		_set_elevation_rect(3, mid_z + 8, 5, 5, 1)

	if world_level >= 3:
		# Upper overlook is high up
		_set_elevation_rect(3, mid_z - 12, 6, 5, 2)

	print("[DUNGEON] Elevation generated")

func _set_elevation_rect(start_x: int, start_z: int, width: int, height: int, elev: int) -> void:
	for x in range(start_x, mini(start_x + width, GRID_W)):
		for z in range(start_z, mini(start_z + height, GRID_H)):
			if grid[x][z] == Tile.FLOOR:
				elevation[x][z] = elev

func get_elevation(grid_pos: Vector2i) -> int:
	if grid_pos.x < 0 or grid_pos.x >= GRID_W or grid_pos.y < 0 or grid_pos.y >= GRID_H:
		return 0
	return elevation[grid_pos.x][grid_pos.y]

func get_elevation_world_y(grid_pos: Vector2i) -> float:
	## Returns the world Y position for the given grid tile based on elevation.
	return get_elevation(grid_pos) * 0.5  # Each elevation level = 0.5 units up

func is_higher_elevation(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	## Returns true if to_pos is at a higher elevation than from_pos.
	return get_elevation(to_pos) > get_elevation(from_pos)

func _build_elevation_visuals() -> void:
	for node in elevation_nodes:
		if is_instance_valid(node):
			node.queue_free()
	elevation_nodes.clear()

	var elev_mat_1 = StandardMaterial3D.new()
	elev_mat_1.albedo_color = Color(0.22, 0.18, 0.15, 1.0)  # Slightly lighter than ground
	elev_mat_1.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var elev_mat_2 = StandardMaterial3D.new()
	elev_mat_2.albedo_color = Color(0.28, 0.22, 0.18, 1.0)  # Even lighter for level 2
	elev_mat_2.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.FLOOR and elevation[x][z] > 0:
				var elev = elevation[x][z]
				var height = elev * 0.5
				var platform = MeshInstance3D.new()
				var box = BoxMesh.new()
				box.size = Vector3(1.02, height, 1.02)
				platform.mesh = box
				platform.material_override = (elev_mat_2 if elev >= 2 else elev_mat_1).duplicate()
				platform.position = Vector3(x + 0.5, height / 2.0, z + 0.5)
				_parent.add_child(platform)
				elevation_nodes.append(platform)

	print("[DUNGEON] Built %d elevation platforms" % elevation_nodes.size())

func _build_walls() -> void:
	for node in wall_nodes:
		if is_instance_valid(node):
			node.queue_free()
	wall_nodes.clear()

	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.25, 0.22, 0.3, 1.0)
	wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	for x in range(GRID_W):
		for z in range(GRID_H):
			if grid[x][z] == Tile.WALL:
				# Only build visible walls (adjacent to at least one floor tile)
				if not _has_adjacent_floor(x, z):
					continue

				var wall = MeshInstance3D.new()
				var box = BoxMesh.new()
				box.size = Vector3(1.0, 1.2, 1.0)
				wall.mesh = box
				wall.material_override = wall_mat.duplicate()
				wall.position = Vector3(x + 0.5, 0.6, z + 0.5)
				_parent.add_child(wall)
				wall_nodes.append(wall)

	print("[DUNGEON] Built %d wall segments (World %d: %dx%d)" % [wall_nodes.size(), world_level, GRID_W, GRID_H])

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

# ============================================
# FOG OF WAR
# ============================================

func _build_fog() -> void:
	# Initialize revealed grid (all false)
	_revealed.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(false)
		_revealed.append(col)

	# Create fog columns for every tile that could matter (floors + walls adjacent to floors)
	# Using tall boxes instead of flat planes so fog can't be seen under from any camera angle
	_fog_nodes.clear()

	var fog_mat = StandardMaterial3D.new()
	fog_mat.albedo_color = Color(0.02, 0.02, 0.05, 1.0)
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var fog_height: float = 10.0  # Tall enough to block any camera angle

	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			var fog = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(1.05, fog_height, 1.05)  # Slightly oversized to avoid seams
			fog.mesh = box
			fog.material_override = fog_mat.duplicate()
			# Center the box so it spans from below ground to well above everything
			fog.position = Vector3(x + 0.5, fog_height / 2.0 - 0.5, z + 0.5)
			fog.visible = true
			fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_parent.add_child(fog)
			col.append(fog)
		_fog_nodes.append(col)

	_fog_initialized = true
	print("[DUNGEON] Fog of war initialized")

func reveal_around(center: Vector2i) -> void:
	## Permanently reveals tiles within FOG_REVEAL_RADIUS of center.
	if not _fog_initialized:
		return

	for dx in range(-FOG_REVEAL_RADIUS, FOG_REVEAL_RADIUS + 1):
		for dz in range(-FOG_REVEAL_RADIUS, FOG_REVEAL_RADIUS + 1):
			# Use circular reveal (Euclidean distance)
			if dx * dx + dz * dz > FOG_REVEAL_RADIUS * FOG_REVEAL_RADIUS:
				continue
			var nx = center.x + dx
			var nz = center.y + dz
			if nx >= 0 and nx < GRID_W and nz >= 0 and nz < GRID_H:
				if not _revealed[nx][nz]:
					_revealed[nx][nz] = true
					# Hide the fog plane
					var fog_node = _fog_nodes[nx][nz]
					if fog_node and is_instance_valid(fog_node):
						fog_node.visible = false

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

func _place_chests() -> void:
	var mid_z = GRID_H / 2
	# Chest 1: Starting room bonus
	_create_chest(Vector2i(4, mid_z + 3))
	# Chest 2: First hub
	_create_chest(Vector2i(16, mid_z - 2))
	# Chest 3: Southern cave
	_create_chest(Vector2i(15, mid_z + 12))
	# Chest 4: Southern treasure room
	_create_chest(Vector2i(30, mid_z + 12))
	# Chest 5: Northern chamber (elevated)
	_create_chest(Vector2i(16, mid_z - 11))
	# Chest 6: Archer's perch (elevated)
	_create_chest(Vector2i(28, mid_z - 12))
	# Chest 7: Guard barracks
	_create_chest(Vector2i(35, mid_z + 13))
	# Chest 8: Barracks alcove
	_create_chest(Vector2i(40, mid_z + 12))
	# Chest 9: Armory (elevated)
	_create_chest(Vector2i(35, mid_z - 11))
	# Chest 10: Pre-boss arena
	_create_chest(Vector2i(GRID_W - 9, mid_z + 3))
	# Extra chests for larger worlds
	if world_level >= 2:
		_create_chest(Vector2i(5, mid_z + 10))   # Hidden grotto
		_create_chest(Vector2i(GRID_W - 4, mid_z))  # Exit room
	if world_level >= 3:
		_create_chest(Vector2i(5, mid_z - 10))  # Upper overlook

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
	chest_root.position = world_pos

	_parent.add_child(chest_root)

	# Generate chest contents
	var contents = _generate_chest_contents()

	chest_nodes.append({
		"node": chest_root,
		"grid_pos": grid_pos,
		"opened": false,
		"contents": contents,
		"body_mesh": body,
		"lid_mesh": lid
	})

func _generate_chest_contents() -> Dictionary:
	# Each chest contains gold + either an item or a card
	var gold = randi_range(15, 50) + (world_level - 1) * 10
	var contents: Dictionary = {"gold": gold, "item": null, "card": null}

	if randf() < 0.5:
		# Give a random item
		contents["item"] = _get_random_item()
	else:
		# Give a random card
		contents["card"] = _get_random_card()

	return contents

func _get_random_item() -> ItemData:
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
	var idx = randi() % item_creators.size()
	return item_creators[idx].call()

func _get_random_card() -> Card:
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
	var idx = randi() % card_creators.size()
	return card_creators[idx].call()

func _define_spawn_zones() -> void:
	var mid_z = GRID_H / 2

	# All worlds use the expanded layout with many zones
	_define_common_zones(mid_z)

	_zones_triggered.clear()
	for _i in range(spawn_zones.size()):
		_zones_triggered.append(false)

	print("[DUNGEON] Defined %d spawn zones for World %d" % [spawn_zones.size(), world_level])

func _define_common_zones(mid_z: int) -> void:
	## Expanded spawn zones for the larger map layout.
	## Enemy difficulty scales with world_level.

	# Helper: scale enemy types based on world level
	var base_melee = Enemy.EnemyType.WERERAT if world_level <= 2 else Enemy.EnemyType.SKELETON
	var mid_melee = Enemy.EnemyType.SKELETON if world_level <= 2 else Enemy.EnemyType.ARMORED_TROLL
	var heavy = Enemy.EnemyType.ARMORED_TROLL if world_level <= 3 else Enemy.EnemyType.ELITE
	var ranged = Enemy.EnemyType.ARCHER_RAT

	# Zone 0: East corridor from starting room - 2 wererats
	spawn_zones.append({
		"trigger_rect": Rect2i(7, mid_z - 2, 4, 5),
		"spawn_points": [Vector2i(10, mid_z - 1), Vector2i(11, mid_z + 2)],
		"enemy_types": [Enemy.EnemyType.WERERAT, Enemy.EnemyType.WERERAT],
		"spawned": false
	})

	# Zone 1: First hub room
	spawn_zones.append({
		"trigger_rect": Rect2i(13, mid_z - 3, 5, 7),
		"spawn_points": [Vector2i(15, mid_z - 2), Vector2i(17, mid_z + 1), Vector2i(16, mid_z + 3)],
		"enemy_types": [base_melee, base_melee, ranged],
		"spawned": false
	})

	# Zone 2: South corridor
	spawn_zones.append({
		"trigger_rect": Rect2i(14, mid_z + 6, 3, 4),
		"spawn_points": [Vector2i(15, mid_z + 8), Vector2i(16, mid_z + 9)],
		"enemy_types": [base_melee, Enemy.EnemyType.WERERAT],
		"spawned": false
	})

	# Zone 3: Southern cave
	spawn_zones.append({
		"trigger_rect": Rect2i(12, mid_z + 10, 7, 5),
		"spawn_points": [Vector2i(14, mid_z + 11), Vector2i(16, mid_z + 13), Vector2i(18, mid_z + 12)],
		"enemy_types": [mid_melee, base_melee, ranged],
		"spawned": false
	})

	# Zone 4: South-east corridor to treasure room
	spawn_zones.append({
		"trigger_rect": Rect2i(21, mid_z + 11, 5, 3),
		"spawn_points": [Vector2i(24, mid_z + 12), Vector2i(26, mid_z + 13)],
		"enemy_types": [base_melee, ranged],
		"spawned": false
	})

	# Zone 5: Southern treasure room guards
	spawn_zones.append({
		"trigger_rect": Rect2i(27, mid_z + 10, 5, 5),
		"spawn_points": [Vector2i(29, mid_z + 11), Vector2i(31, mid_z + 13), Vector2i(30, mid_z + 14)],
		"enemy_types": [mid_melee, heavy, ranged],
		"spawned": false
	})

	# Zone 6: North corridor
	spawn_zones.append({
		"trigger_rect": Rect2i(14, mid_z - 8, 3, 4),
		"spawn_points": [Vector2i(15, mid_z - 7), Vector2i(16, mid_z - 6)],
		"enemy_types": [base_melee, ranged],
		"spawned": false
	})

	# Zone 7: Northern elevated chamber
	spawn_zones.append({
		"trigger_rect": Rect2i(12, mid_z - 13, 7, 4),
		"spawn_points": [Vector2i(14, mid_z - 12), Vector2i(17, mid_z - 11), Vector2i(15, mid_z - 10)],
		"enemy_types": [mid_melee, ranged, ranged],
		"spawned": false
	})

	# Zone 8: Archer's perch (elevated, mostly ranged enemies)
	spawn_zones.append({
		"trigger_rect": Rect2i(26, mid_z - 14, 5, 6),
		"spawn_points": [Vector2i(28, mid_z - 13), Vector2i(30, mid_z - 11), Vector2i(29, mid_z - 9)],
		"enemy_types": [ranged, ranged, base_melee],
		"spawned": false
	})

	# Zone 9: Central crossroads
	spawn_zones.append({
		"trigger_rect": Rect2i(30, mid_z - 3, 7, 7),
		"spawn_points": [Vector2i(32, mid_z - 2), Vector2i(35, mid_z), Vector2i(33, mid_z + 3), Vector2i(36, mid_z + 2)],
		"enemy_types": [mid_melee, mid_melee, ranged, heavy],
		"spawned": false
	})

	# Zone 10: Guard barracks
	spawn_zones.append({
		"trigger_rect": Rect2i(31, mid_z + 10, 7, 5),
		"spawn_points": [Vector2i(33, mid_z + 11), Vector2i(35, mid_z + 13), Vector2i(37, mid_z + 12), Vector2i(34, mid_z + 14)],
		"enemy_types": [mid_melee, heavy, ranged, base_melee],
		"spawned": false
	})

	# Zone 11: Barracks alcove
	spawn_zones.append({
		"trigger_rect": Rect2i(39, mid_z + 11, 3, 3),
		"spawn_points": [Vector2i(40, mid_z + 12), Vector2i(41, mid_z + 13)],
		"enemy_types": [heavy, ranged],
		"spawned": false
	})

	# Zone 12: Armory (elevated)
	spawn_zones.append({
		"trigger_rect": Rect2i(31, mid_z - 13, 7, 4),
		"spawn_points": [Vector2i(33, mid_z - 12), Vector2i(36, mid_z - 11), Vector2i(35, mid_z - 10)],
		"enemy_types": [heavy, mid_melee, ranged],
		"spawned": false
	})

	# Zone 13: Far east corridor
	spawn_zones.append({
		"trigger_rect": Rect2i(39, mid_z - 1, 4, 3),
		"spawn_points": [Vector2i(41, mid_z), Vector2i(43, mid_z + 1)],
		"enemy_types": [mid_melee, ranged],
		"spawned": false
	})

	# Zone 14: Pre-boss arena
	var boss_types: Array = []
	var boss_points: Array = []
	if world_level >= 4:
		boss_points = [Vector2i(GRID_W - 10, mid_z - 3), Vector2i(GRID_W - 8, mid_z), Vector2i(GRID_W - 10, mid_z + 3), Vector2i(GRID_W - 7, mid_z - 1)]
		boss_types = [Enemy.EnemyType.BOSS, Enemy.EnemyType.ELITE, heavy, ranged]
	elif world_level >= 2:
		boss_points = [Vector2i(GRID_W - 10, mid_z - 2), Vector2i(GRID_W - 8, mid_z + 1), Vector2i(GRID_W - 9, mid_z + 3)]
		boss_types = [Enemy.EnemyType.ELITE, heavy, ranged]
	else:
		boss_points = [Vector2i(GRID_W - 10, mid_z), Vector2i(GRID_W - 8, mid_z + 2)]
		boss_types = [Enemy.EnemyType.SKELETON, mid_melee]

	spawn_zones.append({
		"trigger_rect": Rect2i(GRID_W - 12, mid_z - 4, 7, 9),
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

	# Waypoint visual: glowing pillar
	var pillar = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.4
	cyl.height = 2.0
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
	pillar.position = Vector3(0, 1.0, 0)
	wp_root.add_child(pillar)

	# Label
	var label = Label3D.new()
	label.name = "WaypointLabel"
	label.text = display_name
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 1.0, 0.8)
	label.position = Vector3(0, 2.5, 0)
	wp_root.add_child(label)

	# Interact label (shown when nearby)
	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Travel"
	interact_label.font_size = 16
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 3.0, 0)
	interact_label.visible = false
	wp_root.add_child(interact_label)

	var world_pos = grid_manager.grid_to_world(grid_pos)
	wp_root.position = world_pos
	_parent.add_child(wp_root)

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
	for i in range(chest_nodes.size()):
		if chest_nodes[i]["opened"]:
			continue
		var chest_pos: Vector2i = chest_nodes[i]["grid_pos"]
		var dist = absi(player_grid.x - chest_pos.x) + absi(player_grid.y - chest_pos.y)
		if dist <= 1:
			return i
	return -1

func open_chest(index: int) -> Dictionary:
	## Marks a chest as opened and returns its contents.
	if index < 0 or index >= chest_nodes.size():
		return {}
	if chest_nodes[index]["opened"]:
		return {}

	chest_nodes[index]["opened"] = true

	# Visual feedback: change chest color to dark / opened look
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

	# Hide interact label
	var label = chest_nodes[index]["node"].get_node_or_null("InteractLabel")
	if label:
		label.visible = false

	print("[DUNGEON] Opened chest %d: %s" % [index, chest_nodes[index]["contents"]])
	return chest_nodes[index]["contents"]

func update_chest_prompts(player_grid: Vector2i) -> void:
	## Show/hide interact labels based on player proximity and fog reveal.
	for i in range(chest_nodes.size()):
		var chest_pos: Vector2i = chest_nodes[i]["grid_pos"]
		var revealed = is_revealed(chest_pos)
		# Hide entire chest node if not revealed
		chest_nodes[i]["node"].visible = revealed
		if chest_nodes[i]["opened"]:
			continue
		var dist = absi(player_grid.x - chest_pos.x) + absi(player_grid.y - chest_pos.y)
		var label = chest_nodes[i]["node"].get_node_or_null("InteractLabel")
		if label:
			label.visible = revealed and dist <= 2

func get_player_start_world() -> Vector3:
	return grid_manager.grid_to_world(player_start)

func clear() -> void:
	for node in wall_nodes:
		if is_instance_valid(node):
			node.queue_free()
	wall_nodes.clear()
	for node in elevation_nodes:
		if is_instance_valid(node):
			node.queue_free()
	elevation_nodes.clear()
	for chest in chest_nodes:
		if is_instance_valid(chest["node"]):
			chest["node"].queue_free()
	chest_nodes.clear()
	for wp in waypoint_nodes:
		if is_instance_valid(wp["node"]):
			wp["node"].queue_free()
	waypoint_nodes.clear()
	spawn_zones.clear()
	_zones_triggered.clear()
	# Clean up fog
	for col in _fog_nodes:
		for fog in col:
			if fog and is_instance_valid(fog):
				fog.queue_free()
	_fog_nodes.clear()
	_revealed.clear()
	_fog_initialized = false
	grid.clear()
	elevation.clear()
