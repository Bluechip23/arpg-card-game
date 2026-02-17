class_name EnemySpawner
extends Node

## Spawns and manages enemies in the test arena

signal all_enemies_defeated
signal enemy_killed(enemy: Enemy)

const EnemyScene = preload("res://scenes/enemy.tscn")

var enemies: Array[Enemy] = []
var grid_manager: GridManager
var player: Player

func initialize(gm: GridManager, p: Player) -> void:
	grid_manager = gm
	player = p

func spawn_test_arena() -> void:
	# Clear existing enemies
	clear_enemies()
	
	# Spawn minions in various positions
	spawn_enemy(Enemy.EnemyType.MINION, Vector2(800, 200))
	spawn_enemy(Enemy.EnemyType.MINION, Vector2(900, 350))
	spawn_enemy(Enemy.EnemyType.MINION, Vector2(750, 500))
	spawn_enemy(Enemy.EnemyType.MINION, Vector2(1000, 250))
	
	# Spawn elite in the back
	spawn_enemy(Enemy.EnemyType.ELITE, Vector2(1050, 400))
	
	print("[SPAWNER] Test arena spawned: %d enemies" % enemies.size())

func spawn_enemy(type: Enemy.EnemyType, pos: Vector2) -> Enemy:
	var enemy = EnemyScene.instantiate() as Enemy
	get_parent().add_child(enemy)
	
	enemy.position = pos
	enemy.initialize(type, grid_manager)
	enemy.died.connect(_on_enemy_died)
	enemy.turn_completed.connect(_on_enemy_turn_completed)
	
	enemies.append(enemy)
	return enemy

func clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

func get_living_enemies() -> Array[Enemy]:
	var living: Array[Enemy] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			living.append(enemy)
	return living

func process_enemy_turns() -> void:
	var living = get_living_enemies()
	for enemy in living:
		enemy.take_turn(player)

func _on_enemy_died(enemy: Enemy) -> void:
	enemy_killed.emit(enemy)
	
	# Trigger ring effects
	if player:
		var inventory = player.get_inventory()
		if inventory:
			inventory.on_enemy_killed()
	
	# Check if all enemies defeated
	await get_tree().create_timer(0.6).timeout  # Wait for death animation
	
	var living = get_living_enemies()
	if living.size() == 0:
		all_enemies_defeated.emit()
		print("[SPAWNER] All enemies defeated!")

func _on_enemy_turn_completed() -> void:
	pass  # Can add logic here for sequential turns

func get_enemy_at_position(pos: Vector2, radius: float = 50.0) -> Enemy:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			if enemy.position.distance_to(pos) <= radius:
				return enemy
	return null

func get_enemies_in_radius(pos: Vector2, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			if enemy.position.distance_to(pos) <= radius:
				result.append(enemy)
	return result

func get_enemies_in_line(start: Vector2, end: Vector2, width: float = 40.0) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var line_dir = (end - start).normalized()
	var line_length = start.distance_to(end)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			var to_enemy = enemy.position - start
			var projection = to_enemy.dot(line_dir)
			if projection >= 0 and projection <= line_length:
				var closest_point = start + line_dir * projection
				if enemy.position.distance_to(closest_point) <= width:
					result.append(enemy)
	return result

func get_enemies_in_cone(origin: Vector2, direction: Vector2, length: float, half_angle_deg: float = 30.0) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var dir_normalized = direction.normalized()
	var cos_threshold = cos(deg_to_rad(half_angle_deg))
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			var to_enemy = enemy.position - origin
			var dist = to_enemy.length()
			if dist > 0 and dist <= length:
				var dot = to_enemy.normalized().dot(dir_normalized)
				if dot >= cos_threshold:
					result.append(enemy)
	return result

func get_enemy_count() -> int:
	return get_living_enemies().size()
