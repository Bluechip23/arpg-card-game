class_name Player
extends CharacterBody3D

## Player character with turn-based grid movement in 3D

signal move_completed
signal move_started(spaces: int)
signal tile_reached  # Emitted each time the player reaches a single tile

@export var move_speed: float = 5.0  # Units per second (1 unit = 1 grid cell)

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var stats: PlayerStats = $PlayerStats
@onready var inventory: Inventory = $Inventory
@onready var debuff_manager: DebuffManager = $DebuffManager
@onready var buff_manager: BuffManager = $BuffManager

var target_position: Vector3
var is_moving: bool = false
var spaces_to_move: int = 0
var spaces_moved: int = 0
var move_path: Array[Vector3] = []

var movement_paused: bool = false  # Pause movement while enemies act
var grid_manager: GridManager

func _ready() -> void:
	target_position = position

	if not has_node("PlayerStats"):
		var stats_node = PlayerStats.new()
		stats_node.name = "PlayerStats"
		add_child(stats_node)
		stats = stats_node

	if not has_node("Inventory"):
		var inv_node = Inventory.new()
		inv_node.name = "Inventory"
		add_child(inv_node)
		inventory = inv_node

	if not has_node("DebuffManager"):
		var debuff_node = DebuffManager.new()
		debuff_node.name = "DebuffManager"
		add_child(debuff_node)
		debuff_manager = debuff_node

	if not has_node("BuffManager"):
		var buff_node = BuffManager.new()
		buff_node.name = "BuffManager"
		add_child(buff_node)
		buff_manager = buff_node

func set_grid_manager(gm: GridManager) -> void:
	grid_manager = gm
	if grid_manager:
		position = grid_manager.snap_to_grid(position)
		target_position = position

func initialize_character(data: CharacterData) -> void:
	stats.initialize(data)
	inventory.initialize(data.character_name)
	inventory.connect_player_stats(stats)
	inventory.equip_starting_item()
	debuff_manager.initialize(stats, self)
	buff_manager.initialize(stats, self)
	buff_manager.connect_debuff_manager(debuff_manager)  # For Cleanse
	_load_mesh_color(data)

func _load_mesh_color(data: CharacterData) -> void:
	# Apply a unique color per character to the mesh material
	if not mesh:
		return
	var mat = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		# Keep the default blue; characters will insert their own sprites later
		pass

func pause_movement() -> void:
	movement_paused = true

func resume_movement() -> void:
	movement_paused = false

func _physics_process(delta: float) -> void:
	if is_moving and not movement_paused:
		var diff = target_position - position
		var flat_diff = Vector3(diff.x, 0, diff.z)
		var distance = flat_diff.length()

		if distance < 0.1:
			position = target_position
			spaces_moved += 1

			# Trigger bleed damage on movement
			debuff_manager.on_movement(1)

			# Trigger buff effects on movement (e.g. Approach armor)
			buff_manager.on_movement(1)

			# Emit per-tile signal so tempo updates in real time
			tile_reached.emit()

			if move_path.size() > 0:
				target_position = move_path.pop_front()
			else:
				is_moving = false
				velocity = Vector3.ZERO
				move_completed.emit()
		else:
			var direction = flat_diff.normalized()
			velocity = direction * move_speed
	else:
		velocity = Vector3.ZERO

	move_and_slide()

func calculate_path_to(target_pos: Vector3) -> Array[Vector3]:
	if not grid_manager:
		return [target_pos]

	var path: Array[Vector3] = []
	var current_grid = grid_manager.world_to_grid(position)
	var target_grid = grid_manager.world_to_grid(target_pos)

	var current = current_grid

	while current != target_grid:
		var diff_x = target_grid.x - current.x
		var diff_y = target_grid.y - current.y

		if diff_x != 0:
			current.x += signi(diff_x)
		elif diff_y != 0:
			current.y += signi(diff_y)

		path.append(grid_manager.grid_to_world(current))

	return path

func move_to_grid(target_pos: Vector3, spaces: int) -> bool:
	if is_moving:
		return false

	if not debuff_manager.can_move():
		print("[PLAYER] Cannot move - stunned or rooted!")
		return false

	var reduction = debuff_manager.get_movement_reduction()
	spaces = max(1, spaces - reduction)

	# Add haste bonus movement
	var haste_bonus = buff_manager.get_haste_bonus()
	if haste_bonus > 0:
		spaces += haste_bonus
		print("[PLAYER] Haste grants +%d movement" % haste_bonus)

	if debuff_manager.get_random_movement_direction():
		var random_offset = Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		target_pos = position + random_offset
		print("[PLAYER] Inebriated! Moving in random direction")

	if not grid_manager:
		target_position = target_pos
		is_moving = true
		spaces_to_move = 1
		spaces_moved = 0
		move_started.emit(1)
		return true

	var snapped_target = grid_manager.snap_to_grid(target_pos)
	move_path = calculate_path_to(snapped_target)

	if move_path.size() > spaces:
		move_path.resize(spaces)

	if move_path.size() > 0:
		spaces_to_move = move_path.size()
		spaces_moved = 0
		target_position = move_path.pop_front()
		is_moving = true
		move_started.emit(spaces_to_move)
		return true

	return false

func stop_moving() -> void:
	is_moving = false
	velocity = Vector3.ZERO
	move_path.clear()

func blink_to(target_pos: Vector3) -> void:
	if grid_manager:
		target_pos = grid_manager.snap_to_grid(target_pos)
	position = target_pos
	target_position = target_pos
	is_moving = false
	move_path.clear()
	print("[PLAYER] Blinked to %s" % target_pos)

var deck_manager_ref: DeckManager = null

func get_stats() -> PlayerStats:
	return stats
func connect_deck_to_inventory(deck: DeckManager) -> void:
	deck_manager_ref = deck
	if inventory:
		inventory.connect_deck_manager(deck)
func get_deck_manager() -> DeckManager:
	return deck_manager_ref
func get_inventory() -> Inventory:
	return inventory

func get_debuff_manager() -> DebuffManager:
	return debuff_manager

func get_buff_manager() -> BuffManager:
	return buff_manager

func on_attacked_by(attacker) -> void:
	# Called when this player is attacked
	buff_manager.on_attacked(attacker)
