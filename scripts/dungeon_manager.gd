class_name DungeonManager
extends Node

## Generates and manages a progressive dungeon layout with walls, corridors,
## treasure chests, and enemy spawn zones. The dungeon is built on the existing
## 20x12 grid. Walls are 3D boxes placed on blocked tiles.

signal chest_interacted(chest_data: Dictionary)
signal player_entered_zone(zone_index: int)

const GRID_W: int = 20
const GRID_H: int = 12
const FOG_REVEAL_RADIUS: int = 4  # Tiles revealed around the player

# Tile types
enum Tile { FLOOR, WALL }

var grid: Array = []  # 2D array [x][z] of Tile
var wall_nodes: Array[MeshInstance3D] = []
var chest_nodes: Array = []  # [{node: Node3D, grid_pos: Vector2i, opened: bool, contents: Dictionary}]
var spawn_zones: Array = []  # [{rect: Rect2i, spawned: bool, enemies: Array}]
var elite_zone: Dictionary = {}  # {rect: Rect2i, spawned: bool}
var player_start: Vector2i = Vector2i(1, 6)

var grid_manager: GridManager
var _parent: Node3D

# Track which zones the player has triggered
var _zones_triggered: Array[bool] = []

# Fog of war
var _revealed: Array = []        # 2D bool array [x][z] - permanently revealed
var _fog_nodes: Array = []       # 2D array [x][z] of MeshInstance3D (fog planes)
var _fog_initialized: bool = false

func initialize(gm: GridManager, parent: Node3D) -> void:
	grid_manager = gm
	_parent = parent
	_generate_layout()
	_build_walls()
	_build_fog()
	_place_chests()
	_define_spawn_zones()
	# Reveal around the starting position
	reveal_around(player_start)

func _generate_layout() -> void:
	# Initialize all as wall
	grid.clear()
	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			col.append(Tile.WALL)
		grid.append(col)

	# Carve out the dungeon path: a winding corridor with rooms
	# Room 1: Starting room (left side)
	_carve_room(0, 3, 4, 6)  # x=0..3, z=3..8 (4x6 room)

	# Corridor 1: East from starting room
	_carve_corridor_h(4, 6, 5)  # z=5, x=4..6 (horizontal)

	# Room 2: Small chamber (middle-left)
	_carve_room(7, 3, 4, 5)  # x=7..10, z=3..7

	# Corridor 2: South jog
	_carve_corridor_v(9, 7, 9)  # x=9, z=7..9

	# Corridor 3: East from the jog
	_carve_corridor_h(9, 13, 9)  # z=9, x=9..13

	# Room 3: Treasure room (bottom right area)
	_carve_room(12, 7, 4, 4)  # x=12..15, z=7..10

	# Corridor 4: North from room 3
	_carve_corridor_v(14, 3, 7)  # x=14, z=3..6

	# Room 4: Upper corridor / arena (top right)
	_carve_room(13, 1, 6, 4)  # x=13..18, z=1..4

	# Corridor 5: Connect room 2 to room 4 via top
	_carve_corridor_h(10, 13, 4)  # z=4, x=10..12

	# Small alcove for second chest
	_carve_room(6, 8, 3, 3)  # x=6..8, z=8..10

	# Widen some corridors for playability (2 tiles wide)
	_carve_corridor_h(4, 6, 6)  # parallel to corridor 1
	_carve_corridor_h(9, 13, 10)  # parallel to corridor 3
	_carve_corridor_v(15, 3, 7)  # parallel to corridor 4
	_carve_corridor_h(10, 13, 3)  # parallel to corridor 5

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

	print("[DUNGEON] Built %d wall segments" % wall_nodes.size())

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

	# Create fog planes for every tile that could matter (floors + walls adjacent to floors)
	_fog_nodes.clear()

	var fog_mat = StandardMaterial3D.new()
	fog_mat.albedo_color = Color(0.02, 0.02, 0.05, 0.95)
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat.no_depth_test = true
	fog_mat.render_priority = 10  # Draw on top

	for x in range(GRID_W):
		var col: Array = []
		for z in range(GRID_H):
			var should_fog = (grid[x][z] == Tile.FLOOR) or _has_adjacent_floor(x, z)
			if should_fog:
				var fog = MeshInstance3D.new()
				var plane = PlaneMesh.new()
				plane.size = Vector2(1.05, 1.05)  # Slightly oversized to avoid seams
				fog.mesh = plane
				fog.material_override = fog_mat.duplicate()
				fog.position = Vector3(x + 0.5, 1.3, z + 0.5)  # Above walls
				fog.visible = true
				_parent.add_child(fog)
				col.append(fog)
			else:
				col.append(null)
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
	# Chest 1: In room 3 (treasure room)
	_create_chest(Vector2i(13, 8))
	# Chest 2: In the alcove
	_create_chest(Vector2i(7, 9))

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
	var gold = randi_range(15, 50)
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
	# Zone 0: Room 2 entrance (triggered when player enters room 2)
	spawn_zones.append({
		"trigger_rect": Rect2i(5, 4, 3, 4),  # Corridor + room 2 entrance
		"spawn_points": [
			Vector2i(8, 4), Vector2i(9, 5), Vector2i(10, 6)
		],
		"enemy_types": [Enemy.EnemyType.WERERAT, Enemy.EnemyType.WERERAT, Enemy.EnemyType.MINION],
		"spawned": false
	})

	# Zone 1: Corridor heading south (triggered near the south jog)
	spawn_zones.append({
		"trigger_rect": Rect2i(8, 7, 4, 3),  # South corridor area
		"spawn_points": [
			Vector2i(11, 9), Vector2i(12, 10)
		],
		"enemy_types": [Enemy.EnemyType.SKELETON, Enemy.EnemyType.SKELETON],
		"spawned": false
	})

	# Zone 2: Room 3 / treasure room (enemies guarding the chest)
	spawn_zones.append({
		"trigger_rect": Rect2i(11, 7, 3, 3),  # Entrance to room 3
		"spawn_points": [
			Vector2i(14, 8), Vector2i(13, 9), Vector2i(15, 8)
		],
		"enemy_types": [Enemy.EnemyType.MINION, Enemy.EnemyType.WERERAT, Enemy.EnemyType.SKELETON],
		"spawned": false
	})

	# Zone 3: Upper area - approaching room 4 (elites at the end)
	spawn_zones.append({
		"trigger_rect": Rect2i(12, 2, 3, 3),  # Corridor to room 4
		"spawn_points": [
			Vector2i(15, 2), Vector2i(16, 3), Vector2i(17, 2)
		],
		"enemy_types": [Enemy.EnemyType.ARMORED_TROLL, Enemy.EnemyType.ELITE],
		"spawned": false
	})

	# Zone 4: Alcove (near second chest)
	spawn_zones.append({
		"trigger_rect": Rect2i(5, 7, 3, 3),
		"spawn_points": [
			Vector2i(7, 8), Vector2i(6, 9)
		],
		"enemy_types": [Enemy.EnemyType.WERERAT, Enemy.EnemyType.MINION],
		"spawned": false
	})

	_zones_triggered.clear()
	for _i in range(spawn_zones.size()):
		_zones_triggered.append(false)

	print("[DUNGEON] Defined %d spawn zones" % spawn_zones.size())

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
	for chest in chest_nodes:
		if is_instance_valid(chest["node"]):
			chest["node"].queue_free()
	chest_nodes.clear()
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
