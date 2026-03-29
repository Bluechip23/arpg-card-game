class_name Player
extends CharacterBody3D

## Player character with turn-based grid movement in 3D

signal move_completed
signal move_started(spaces: int)
signal tile_reached  # Emitted each time the player reaches a single tile

@export var move_speed: float = 5.0  # Units per second (1 unit = 1 grid cell)

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var character_sprite: Sprite3D = $CharacterSprite
@onready var animator: CharacterAnimator = $CharacterAnimator
@onready var stats: PlayerStats = $PlayerStats
@onready var inventory: Inventory = $Inventory
@onready var debuff_manager: DebuffManager = $DebuffManager
@onready var buff_manager: BuffManager = $BuffManager

# Animation action map (game actions -> animation names)
var _action_map: Dictionary = {}

var target_position: Vector3
var is_moving: bool = false
var spaces_to_move: int = 0
var spaces_moved: int = 0
var move_path: Array[Vector3] = []

var movement_paused: bool = false  # Pause movement while enemies act
var grid_manager: GridManager
var enemy_spawner = null  # Set by main.gd so pathfinding can avoid enemy tiles
var blocked_tiles: Array[Vector2i] = []  # Set by main.gd for barricade obstacles
var _last_position: Vector3 = Vector3.ZERO
var _stuck_frames: int = 0
const STUCK_THRESHOLD: int = 10  # Cancel movement after this many frames with no progress

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
	_initialize_animations(data)

func _load_mesh_color(data: CharacterData) -> void:
	# Apply a unique color per character to the mesh material
	if not mesh:
		return
	var mat = mesh.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		# Keep the default blue; characters will insert their own sprites later
		pass

func _get_animation_class(character_name: String):
	match character_name:
		"Stephen":
			return StephenAnimations
		"Brad":
			return BradAnimations
		"Ryan":
			return RyanAnimations
		"Cory":
			return CoryAnimations
		"Jeremy":
			return JeremyAnimations
		_:
			return null

func _initialize_animations(data: CharacterData) -> void:
	if not animator or not character_sprite:
		return

	# Load character-specific animation data
	var anim_data: Dictionary = {}
	var sheet_path: String = ""

	var anim_class = _get_animation_class(data.character_name)
	if anim_class == null:
		return
	anim_data = anim_class.get_animation_data()
	_action_map = anim_class.get_action_map()
	sheet_path = anim_class.SPRITE_SHEET_PATH

	if sheet_path == "" or anim_data.is_empty():
		return

	animator.initialize(character_sprite, anim_data, sheet_path)

	if animator.sprite_sheet_loaded:
		# Hide the capsule mesh when sprite animations are active
		mesh.visible = false
		animator.animation_finished.connect(_on_animation_finished)
	else:
		# Keep capsule visible as fallback
		character_sprite.visible = false

func play_animation(action: String, direction: CharacterAnimator.Direction = CharacterAnimator.Direction.SOUTH) -> void:
	if not animator or not animator.sprite_sheet_loaded:
		return
	var anim_name = _action_map.get(action, action)
	animator.play(anim_name, direction)

func _on_animation_finished(anim_name: String) -> void:
	# Return to idle/stance after one-shot animations complete
	if anim_name != "stance" and anim_name != "walking" and anim_name != "running" and anim_name != "battle_stance":
		animator.play("stance")

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
			_stuck_frames = 0

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
				# Return to idle stance when movement completes
				if animator and animator.sprite_sheet_loaded:
					animator.play("stance")
				move_completed.emit()
		else:
			var direction = flat_diff.normalized()
			velocity = direction * move_speed

			# Update animation direction and play walk animation
			if animator and animator.sprite_sheet_loaded:
				animator.set_direction_from_velocity(velocity)
				if not animator.is_animation_playing("walking"):
					animator.play("walking")

			# Detect if stuck (collision blocking progress toward target)
			var moved_dist = (position - _last_position).length()
			if moved_dist < 0.01:
				_stuck_frames += 1
				if _stuck_frames >= STUCK_THRESHOLD:
					print("[PLAYER] Movement blocked - cancelling path")
					# Snap to nearest grid cell and stop
					if grid_manager:
						position = grid_manager.snap_to_grid(position)
						target_position = position
					is_moving = false
					velocity = Vector3.ZERO
					move_path.clear()
					_stuck_frames = 0
					if animator and animator.sprite_sheet_loaded:
						animator.play("stance")
					move_completed.emit()
			else:
				_stuck_frames = 0
		_last_position = position
	else:
		velocity = Vector3.ZERO

	move_and_slide()

func calculate_path_to(target_pos: Vector3) -> Array[Vector3]:
	if not grid_manager:
		return [target_pos]

	var current_grid = grid_manager.world_to_grid(position)
	var target_grid = grid_manager.world_to_grid(target_pos)

	if current_grid == target_grid:
		return []

	# BFS pathfinding — walls/barricades are impassable, enemy tiles are passable
	var frontier: Array[Vector2i] = [current_grid]
	var came_from: Dictionary = {}
	came_from[current_grid] = current_grid

	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	while frontier.size() > 0:
		var current = frontier.pop_front()

		if current == target_grid:
			break

		for dir in directions:
			var next = current + dir
			if came_from.has(next):
				continue
			if next in blocked_tiles:
				continue
			if next.x < 0 or next.x >= grid_manager.grid_width or next.y < 0 or next.y >= grid_manager.grid_height:
				continue
			came_from[next] = current
			frontier.append(next)

	if not came_from.has(target_grid):
		return []  # No path found

	# Reconstruct path from target back to start
	var path: Array[Vector3] = []
	var trace = target_grid
	while trace != current_grid:
		path.push_front(grid_manager.grid_to_world(trace))
		trace = came_from[trace]

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
		_stuck_frames = 0
		_last_position = position
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

# ============================================
# FLOATING NUMBERS
# ============================================

func spawn_damage_number(amount: int) -> void:
	if amount <= 0:
		return
	var label = Label3D.new()
	label.text = str(amount)
	label.font_size = 26
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 50
	label.modulate = Color(1.0, 0.3, 0.3)
	label.position = position + Vector3(randf_range(-0.3, 0.3), 1.8, 0)
	get_parent().add_child(label)

	var tween = label.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain()
	tween.tween_callback(label.queue_free)

func spawn_heal_number(amount: int) -> void:
	if amount <= 0:
		return
	var label = Label3D.new()
	label.text = "+" + str(amount)
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 50
	label.modulate = Color(0.3, 1.0, 0.4)
	label.position = position + Vector3(randf_range(-0.2, 0.2), 1.8, 0)
	get_parent().add_child(label)

	var tween = label.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain()
	tween.tween_callback(label.queue_free)

func spawn_armor_number(amount: int) -> void:
	if amount <= 0:
		return
	var label = Label3D.new()
	label.text = "+" + str(amount) + " Armor"
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 50
	label.modulate = Color(0.5, 0.7, 1.0)
	label.position = position + Vector3(randf_range(-0.2, 0.2), 1.6, 0)
	get_parent().add_child(label)

	var tween = label.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.8, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tween.chain()
	tween.tween_callback(label.queue_free)
