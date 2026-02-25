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

	# 3 Wererats (fast, aggressive)
	spawn_enemy(Enemy.EnemyType.WERERAT, Vector3(12.5, 0, 3.0))
	spawn_enemy(Enemy.EnemyType.WERERAT, Vector3(14.0, 0, 5.5))
	spawn_enemy(Enemy.EnemyType.WERERAT, Vector3(11.5, 0, 8.0))

	# 2 Skeletons (slow but sturdy)
	spawn_enemy(Enemy.EnemyType.SKELETON, Vector3(15.5, 0, 4.0))
	spawn_enemy(Enemy.EnemyType.SKELETON, Vector3(15.0, 0, 7.0))

	# 1 Armored Troll (elite, regenerating)
	spawn_enemy(Enemy.EnemyType.ARMORED_TROLL, Vector3(17.0, 0, 6.0))

	print("[SPAWNER] Test arena spawned: %d enemies" % enemies.size())

func spawn_enemy(type: Enemy.EnemyType, pos: Vector3) -> Enemy:
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

## Called every time global tempo advances.
## Each enemy manages its own action counter independently.
func on_tempo_advanced(amount: int) -> void:
	var living = get_living_enemies()
	for enemy in living:
		enemy.on_tempo_advanced(amount, player)

## Legacy method kept for any existing references.
func process_enemy_turns() -> void:
	pass

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

func get_enemy_at_position(pos: Vector3, radius: float = 1.0) -> Enemy:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			var diff = enemy.position - pos
			var flat_dist = Vector3(diff.x, 0, diff.z).length()
			if flat_dist <= radius:
				return enemy
	return null

func get_enemies_in_radius(pos: Vector3, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			var diff = enemy.position - pos
			var flat_dist = Vector3(diff.x, 0, diff.z).length()
			if flat_dist <= radius:
				result.append(enemy)
	return result

func get_enemies_in_line(start: Vector3, end: Vector3, width: float = 0.6) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var line_vec = end - start
	var line_dir = Vector3(line_vec.x, 0, line_vec.z).normalized()
	var line_length = Vector3(line_vec.x, 0, line_vec.z).length()
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			var to_enemy = enemy.position - start
			var to_enemy_flat = Vector3(to_enemy.x, 0, to_enemy.z)
			var projection = to_enemy_flat.dot(line_dir)
			if projection >= 0 and projection <= line_length:
				var closest_point = start + line_dir * projection
				var diff = enemy.position - closest_point
				var perpendicular_dist = Vector3(diff.x, 0, diff.z).length()
				if perpendicular_dist <= width:
					result.append(enemy)
	return result

func get_enemies_in_cone(origin: Vector3, direction: Vector3, length: float, half_angle_deg: float = 30.0) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var dir_flat = Vector3(direction.x, 0, direction.z).normalized()
	var cos_threshold = cos(deg_to_rad(half_angle_deg))
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			var to_enemy = enemy.position - origin
			var to_enemy_flat = Vector3(to_enemy.x, 0, to_enemy.z)
			var dist = to_enemy_flat.length()
			if dist > 0 and dist <= length:
				var dot = to_enemy_flat.normalized().dot(dir_flat)
				if dot >= cos_threshold:
					result.append(enemy)
	return result

func get_enemy_count() -> int:
	return get_living_enemies().size()
