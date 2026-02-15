class_name Enemy
extends CharacterBody2D

## Enemy that acts on turns

signal damaged(amount: int)
signal died(enemy: Enemy)
signal turn_completed

enum EnemyType { MINION, ELITE, BOSS }

@export var enemy_name: String = "Enemy"
@export var enemy_type: EnemyType = EnemyType.MINION
@export var max_health: int = 30
@export var move_speed: float = 150.0
@export var attack_damage: int = 2
@export var attack_range: float = 80.0
@export var aggro_range: float = 500.0
@export var move_distance: float = 50.0  # Pixels per turn

var current_health: int = 30
var target: Node2D = null
var is_moving: bool = false
var target_position: Vector2
var is_dead: bool = false

var grid_manager: GridManager

# Status effects applied by player cards
var taunt_target: Node2D = null
var taunt_turns: int = 0
var attack_reduction: int = 0
var wear_down_turns: int = 0  # While active, each hit reduces attack by 1 more

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
			move_distance = 40.0  # Slower but stronger
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
	
	# Snap to grid if available
	if grid_manager:
		position = grid_manager.snap_to_grid(position)
		target_position = position

func update_outline() -> void:
	if not outline:
		return
	
	match enemy_type:
		EnemyType.ELITE:
			outline.visible = true
			outline.color = Color(1.0, 0.85, 0.0, 0.8)  # Yellow
		EnemyType.BOSS:
			outline.visible = true
			outline.color = Color(0.8, 0.0, 0.8, 0.8)  # Purple
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

func set_target(new_target: Node2D) -> void:
	target = new_target

func take_turn(player_node: Node2D) -> void:
	if is_dead:
		turn_completed.emit()
		return

	if not player_node:
		turn_completed.emit()
		return

	# Tick down status effects
	if taunt_turns > 0:
		taunt_turns -= 1
		if taunt_turns <= 0:
			taunt_target = null
			print("[%s] Taunt expired" % enemy_name)

	if wear_down_turns > 0:
		wear_down_turns -= 1
		if wear_down_turns <= 0:
			attack_reduction = 0
			print("[%s] Wear Down expired, attack restored" % enemy_name)

	# Determine who to move toward / attack
	var move_target = player_node
	if taunt_target and is_instance_valid(taunt_target):
		move_target = taunt_target

	var distance_to_target = position.distance_to(move_target.position)

	if distance_to_target <= attack_range:
		attack_player(move_target)
		turn_completed.emit()
	elif distance_to_target <= aggro_range:
		move_towards_target(move_target.position)
	else:
		turn_completed.emit()

func move_towards_target(pos: Vector2) -> void:
	var direction = (pos - position).normalized()
	var new_target = position + direction * move_distance
	
	# Snap to grid if available
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
			player_stats.take_damage(effective_damage)
			
			# Trigger ring effect for taking damage
			if player_node.has_method("get_inventory"):
				var inventory = player_node.get_inventory()
				if inventory:
					inventory.on_damage_taken()
	
	# Flash when attacking
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.ORANGE, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func take_damage(amount: int) -> void:
	if is_dead:
		return

	# Wear Down: each hit while active reduces attack by 1 more
	if wear_down_turns > 0:
		attack_reduction += 1
		print("[%s] Wear Down stacks! Attack reduced by %d" % [enemy_name, attack_reduction])

	current_health -= amount
	current_health = max(0, current_health)
	damaged.emit(amount)
	update_health_display()
	
	# Flash red
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	print("[%s] Took %d damage! Health: %d/%d" % [enemy_name, amount, current_health, max_health])
	
	if current_health <= 0:
		die()

func update_health_display() -> void:
	if health_bar:
		health_bar.value = (float(current_health) / float(max_health)) * 100
	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]

func die() -> void:
	is_dead = true
	print("[%s] Defeated!" % enemy_name)
	died.emit(self)
	
	# Fade out and remove
	if sprite:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.5)
		tween.tween_callback(queue_free)

func is_alive() -> bool:
	return not is_dead

func knockback(away_from: Vector2, spaces: int = 1) -> void:
	if is_dead:
		return
	var direction = (position - away_from).normalized()
	var new_pos = position + direction * (spaces * 64.0)  # 64 = grid_size
	if grid_manager:
		new_pos = grid_manager.snap_to_grid(new_pos)
	position = new_pos
	target_position = new_pos
	print("[%s] Knocked back %d space(s)" % [enemy_name, spaces])

func apply_taunt(taunter: Node2D, turns: int) -> void:
	taunt_target = taunter
	taunt_turns = turns
	print("[%s] Taunted for %d turns" % [enemy_name, turns])

func apply_wear_down(turns: int) -> void:
	wear_down_turns = max(wear_down_turns, turns)
	print("[%s] Wear Down applied! Each hit will reduce attack by 1 for %d turns" % [enemy_name, wear_down_turns])
