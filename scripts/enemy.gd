class_name Enemy
extends CharacterBody2D

## Enemy that acts based on its own tempo counter.
## Each enemy has an independent action_tempo_counter that increments with global tempo.
## Actions (attack, move, custom skills) each have their own tempo threshold.
## Designed to be easily extended: add new actions to the actions array and handle them
## in _execute_action() for future enemies like mages, necromancers, etc.

signal damaged(amount: int)
signal died(enemy: Enemy)
signal turn_completed  # Kept for compat

enum EnemyType { MINION, ELITE, BOSS }

@export var enemy_name: String = "Enemy"
@export var enemy_type: EnemyType = EnemyType.MINION
@export var max_health: int = 30
@export var move_speed: float = 150.0
@export var attack_damage: int = 2
@export var attack_range: float = 80.0
@export var aggro_range: float = 500.0
@export var move_distance: float = 50.0  # Pixels per action

var current_health: int = 30
var target: Node2D = null
var is_moving: bool = false
var target_position: Vector2
var is_dead: bool = false

var grid_manager: GridManager

# Status effects applied by player cards (duration in tempo cycles, 1 cycle = 5 global tempo)
var taunt_target: Node2D = null
var taunt_tempo: int = 0       # Remaining tempo cycles for taunt
var attack_reduction: int = 0
var wear_down_tempo: int = 0   # Remaining tempo cycles for wear down

# ============================================
# TEMPO ACTION SYSTEM
# ============================================

## Independent per-enemy tempo counter. Increments with global tempo.
var action_tempo_counter: int = 0

## Accumulator for tracking tempo cycles (used for status effect durations).
var _cycle_accumulator: int = 0

## Action list - defines what this enemy can do and at what tempo threshold.
## Each entry: { "name": String, "tempo_threshold": int }
## Lower threshold = fires more frequently. Checked in order (lowest first).
## Extend this for new enemy types: mages add "fireball", necromancers add "raise_dead", etc.
var actions: Array[Dictionary] = []

@onready var sprite: ColorRect = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var name_label: Label = $NameLabel
@onready var outline: ColorRect = $Outline

func _ready() -> void:
	current_health = max_health
	target_position = position
	update_health_display()
	update_name_display()
	update_outline()

func initialize(type: EnemyType, gm: GridManager = null) -> void:
	enemy_type = type
	grid_manager = gm

	match enemy_type:
		EnemyType.MINION:
			enemy_name = "Minion"
			max_health = 25
			attack_damage = 3
			move_distance = 50.0
			if sprite:
				sprite.color = Color(0.8, 0.2, 0.2)  # Red

		EnemyType.ELITE:
			enemy_name = "Elite"
			max_health = 80
			attack_damage = 6
			move_distance = 40.0
			if sprite:
				sprite.color = Color(0.6, 0.1, 0.1)  # Dark red

		EnemyType.BOSS:
			enemy_name = "Boss"
			max_health = 200
			attack_damage = 10
			move_distance = 30.0
			if sprite:
				sprite.color = Color(0.4, 0.0, 0.2)  # Purple-ish

	current_health = max_health
	update_health_display()
	update_name_display()
	update_outline()
	_setup_actions()

	if grid_manager:
		position = grid_manager.snap_to_grid(position)
		target_position = position

func _setup_actions() -> void:
	## Define tempo thresholds for each action per enemy type.
	## Attack threshold < move threshold so attacks fire before moves when both are ready.
	## Extend here for new enemy types with unique skills.
	match enemy_type:
		EnemyType.MINION:
			actions = [
				{"name": "attack", "tempo_threshold": 3},
				{"name": "move",   "tempo_threshold": 5},
			]
		EnemyType.ELITE:
			actions = [
				{"name": "attack", "tempo_threshold": 4},
				{"name": "move",   "tempo_threshold": 6},
			]
		EnemyType.BOSS:
			actions = [
				{"name": "attack", "tempo_threshold": 5},
				{"name": "move",   "tempo_threshold": 8},
			]

# ============================================
# TEMPO-DRIVEN ACTION HANDLING
# ============================================

## Called by EnemySpawner whenever global tempo advances.
## Increments this enemy's personal counter and fires actions when thresholds are met.
func on_tempo_advanced(amount: int, player_node: Node2D) -> void:
	if is_dead:
		return

	action_tempo_counter += amount
	_cycle_accumulator += amount

	# Tick status effect durations once per tempo cycle (every 5 global tempo)
	while _cycle_accumulator >= 5:
		_cycle_accumulator -= 5
		_tick_status_durations()

	_check_and_fire_actions(player_node)

func _tick_status_durations() -> void:
	if taunt_tempo > 0:
		taunt_tempo -= 1
		if taunt_tempo <= 0:
			taunt_target = null
			print("[%s] Taunt expired" % enemy_name)

	if wear_down_tempo > 0:
		wear_down_tempo -= 1
		if wear_down_tempo <= 0:
			attack_reduction = 0
			print("[%s] Wear Down expired, attack restored" % enemy_name)

func _check_and_fire_actions(player_node: Node2D) -> void:
	if not player_node:
		return

	var move_target = player_node
	if taunt_target and is_instance_valid(taunt_target):
		move_target = taunt_target

	# Actions are already sorted ascending by tempo_threshold in _setup_actions.
	# The lowest threshold (attack) is checked first. If the enemy can attack, it does.
	# If it can't (not in range), the next action (move) is checked.
	for action_def in actions:
		if action_tempo_counter >= action_def["tempo_threshold"]:
			if _execute_action(action_def["name"], move_target):
				action_tempo_counter = 0
				return  # One action per tempo check

## Execute a named action. Returns true if the action was performed, false if it couldn't fire.
## Add new action types here for future enemy variants (fireball, raise_dead, etc.)
func _execute_action(action_name: String, move_target: Node2D) -> bool:
	match action_name:
		"attack":
			return _try_attack(move_target)
		"move":
			return _try_move(move_target)
		_:
			push_warning("[%s] Unknown action: %s" % [enemy_name, action_name])
			return false

func _try_attack(target_node: Node2D) -> bool:
	var distance = position.distance_to(target_node.position)
	if distance <= attack_range:
		attack_player(target_node)
		turn_completed.emit()
		return true
	return false

func _try_move(target_node: Node2D) -> bool:
	var distance = position.distance_to(target_node.position)
	if distance <= aggro_range:
		move_towards_target(target_node.position)
		return true
	return false  # Out of aggro range - idle

# ============================================
# PHYSICS
# ============================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_moving:
		var direction = (target_position - position).normalized()
		var distance = position.distance_to(target_position)

		if distance < 5.0:
			position = target_position
			is_moving = false
			velocity = Vector2.ZERO
			turn_completed.emit()
		else:
			velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

# ============================================
# MOVEMENT & COMBAT
# ============================================

func set_target(new_target: Node2D) -> void:
	target = new_target

func move_towards_target(pos: Vector2) -> void:
	var direction = (pos - position).normalized()
	var new_target = position + direction * move_distance

	if grid_manager:
		new_target = grid_manager.snap_to_grid(new_target)

	target_position = new_target
	is_moving = true

func attack_player(player_node: Node2D) -> void:
	var effective_damage = max(0, attack_damage - attack_reduction)
	print("[%s] Attacks for %d damage! (base %d, reduction %d)" % [enemy_name, effective_damage, attack_damage, attack_reduction])

	if player_node.has_method("get_stats"):
		var player_stats = player_node.get_stats()
		if player_stats and effective_damage > 0:
			var debuff_mgr = null
			var buff_mgr = null
			if player_node.has_method("get_debuff_manager"):
				debuff_mgr = player_node.get_debuff_manager()
			if player_node.has_method("get_buff_manager"):
				buff_mgr = player_node.get_buff_manager()
			player_stats.take_damage(effective_damage, debuff_mgr, buff_mgr)

			if player_node.has_method("get_inventory"):
				var inventory = player_node.get_inventory()
				if inventory:
					inventory.on_damage_taken()

	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.ORANGE, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

# ============================================
# TAKING DAMAGE
# ============================================

func take_damage(amount: int) -> void:
	if is_dead:
		return

	if wear_down_tempo > 0:
		attack_reduction += 1
		print("[%s] Wear Down stacks! Attack reduced by %d" % [enemy_name, attack_reduction])

	current_health -= amount
	current_health = max(0, current_health)
	damaged.emit(amount)
	update_health_display()

	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

	print("[%s] Took %d damage! Health: %d/%d" % [enemy_name, amount, current_health, max_health])

	if current_health <= 0:
		die()

# ============================================
# STATUS EFFECTS
# ============================================

func apply_taunt(taunter: Node2D, cycles: int) -> void:
	taunt_target = taunter
	taunt_tempo = cycles
	print("[%s] Taunted for %d tempo cycles" % [enemy_name, cycles])

func apply_wear_down(cycles: int) -> void:
	wear_down_tempo = max(wear_down_tempo, cycles)
	print("[%s] Wear Down applied for %d tempo cycles" % [enemy_name, wear_down_tempo])

func knockback(away_from: Vector2, spaces: int = 1) -> void:
	if is_dead:
		return
	var direction = (position - away_from).normalized()
	var new_pos = position + direction * (spaces * 64.0)
	if grid_manager:
		new_pos = grid_manager.snap_to_grid(new_pos)
	position = new_pos
	target_position = new_pos
	print("[%s] Knocked back %d space(s)" % [enemy_name, spaces])

# ============================================
# HEALTH & DISPLAY
# ============================================

func update_health_display() -> void:
	if health_bar:
		health_bar.value = (float(current_health) / float(max_health)) * 100
	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]

func update_outline() -> void:
	if not outline:
		return
	match enemy_type:
		EnemyType.ELITE:
			outline.visible = true
			outline.color = Color(1.0, 0.85, 0.0, 0.8)
		EnemyType.BOSS:
			outline.visible = true
			outline.color = Color(0.8, 0.0, 0.8, 0.8)
		_:
			outline.visible = false

func update_name_display() -> void:
	if name_label:
		name_label.text = enemy_name
		match enemy_type:
			EnemyType.ELITE:
				name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
			EnemyType.BOSS:
				name_label.add_theme_color_override("font_color", Color(0.8, 0.0, 0.8))

func die() -> void:
	is_dead = true
	print("[%s] Defeated!" % enemy_name)
	died.emit(self)

	if sprite:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(queue_free)

func is_alive() -> bool:
	return not is_dead
