class_name EnemySpawner
extends Node

## Spawns and manages enemies in the dungeon

signal all_enemies_defeated
signal enemy_killed(enemy: Enemy)
signal enemy_spawned(enemy: Enemy)
signal loot_dropped(loot: Dictionary, position: Vector3)

const EnemyScene = preload("res://scenes/battle/enemy.tscn")

var enemies: Array[Enemy] = []
var grid_manager: GridManager
var player: Player
# All player characters enemies may target (co-op aware). When empty, falls back
# to the single `player`. Enemies attack the nearest living one.
var players: Array = []

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

func spawn_fire_goblin_pack() -> void:
	## A Fire Goblin warband led by a shaman, plus a Hydra — for testing the new
	## enemies. Does not clear existing enemies.
	spawn_enemy(Enemy.EnemyType.FIRE_GOBLIN_SOLDIER, Vector3(12.5, 0, 4.0))
	spawn_enemy(Enemy.EnemyType.FIRE_GOBLIN_SOLDIER, Vector3(13.5, 0, 6.0))
	spawn_enemy(Enemy.EnemyType.FIRE_GOBLIN_MAGE, Vector3(16.0, 0, 5.0))
	spawn_enemy(Enemy.EnemyType.FIRE_GOBLIN_SHAMAN, Vector3(17.5, 0, 7.0))
	spawn_enemy(Enemy.EnemyType.HYDRA, Vector3(15.0, 0, 9.0))
	print("[SPAWNER] Fire goblin pack + hydra spawned: %d total" % enemies.size())

func spawn_enemy(type: Enemy.EnemyType, pos: Vector3) -> Enemy:
	var enemy = EnemyScene.instantiate() as Enemy
	get_parent().add_child(enemy)

	enemy.position = pos
	enemy.initialize(type, grid_manager)
	enemy.died.connect(_on_enemy_died)
	enemy.turn_completed.connect(_on_enemy_turn_completed)

	enemies.append(enemy)
	enemy_spawned.emit(enemy)
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
		enemy.on_tempo_advanced(amount, _target_for(enemy))

## Pick the nearest living player for this enemy to act against (co-op aware).
func _target_for(enemy: Enemy) -> Node3D:
	var candidates := _living_players()
	if candidates.is_empty():
		return player  # solo fallback (or both downed — let it act on P1)
	var best: Node3D = null
	var best_d := INF
	for p in candidates:
		var d: float = enemy.position.distance_to(p.position)
		if d < best_d:
			best_d = d
			best = p
	return best

func _living_players() -> Array:
	var out := []
	for p in players:
		if is_instance_valid(p) and p.has_method("get_stats"):
			# Cryonics-iced characters are untargetable.
			if p.get("untargetable") == true:
				continue
			var st = p.get_stats()
			if st and st.current_health > 0:
				out.append(p)
	return out

func _on_enemy_died(enemy: Enemy) -> void:
	enemy_killed.emit(enemy)

	# Generate and emit loot
	var loot = _generate_loot(enemy)
	if not loot.is_empty():
		loot_dropped.emit(loot, enemy.position)

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

# ============================================
# LOOT DROP SYSTEM
# ============================================

func _generate_loot(enemy: Enemy) -> Dictionary:
	var loot: Dictionary = {"gold": 0, "item": null, "card": null, "culling_stones": 0}

	# Gold drop (always) - amount based on enemy type
	match enemy.enemy_type:
		Enemy.EnemyType.MINION:
			loot["gold"] = randi_range(2, 8)
		Enemy.EnemyType.WERERAT:
			loot["gold"] = randi_range(3, 10)
		Enemy.EnemyType.ARCHER_RAT:
			loot["gold"] = randi_range(2, 6)
		Enemy.EnemyType.SKELETON:
			loot["gold"] = randi_range(5, 15)
		Enemy.EnemyType.ARMORED_TROLL:
			loot["gold"] = randi_range(10, 25)
		Enemy.EnemyType.ELITE:
			loot["gold"] = randi_range(15, 40)
		Enemy.EnemyType.BOSS:
			loot["gold"] = randi_range(30, 80)

	# Culling stone drop chance
	var culling_chance = _get_culling_stone_drop_chance(enemy.enemy_type)
	if randf() < culling_chance:
		loot["culling_stones"] = 1

	# Item drop chance (varies by enemy type)
	var item_chance = _get_item_drop_chance(enemy.enemy_type)
	if randf() < item_chance:
		loot["item"] = _get_random_loot_item(enemy.enemy_type)

	# Card drop chance (rarer than items)
	var card_chance = _get_card_drop_chance(enemy.enemy_type)
	if randf() < card_chance:
		loot["card"] = _get_random_loot_card()

	# Rats carry the Infestation card — a roguelike-only summon. Rolled separately
	# so it isn't crowded out by the normal card pool, and only if nothing else
	# already filled the card slot this drop.
	if loot["card"] == null and _is_rat(enemy.enemy_type) and randf() < 0.25:
		loot["card"] = Card.create_infestation()

	return loot

func _is_rat(type: Enemy.EnemyType) -> bool:
	return type == Enemy.EnemyType.WERERAT or type == Enemy.EnemyType.ARCHER_RAT

func _get_item_drop_chance(type: Enemy.EnemyType) -> float:
	match type:
		Enemy.EnemyType.MINION: return 0.05
		Enemy.EnemyType.WERERAT: return 0.08
		Enemy.EnemyType.ARCHER_RAT: return 0.06
		Enemy.EnemyType.SKELETON: return 0.12
		Enemy.EnemyType.ARMORED_TROLL: return 0.20
		Enemy.EnemyType.ELITE: return 0.30
		Enemy.EnemyType.BOSS: return 0.80
	return 0.05

func _get_card_drop_chance(type: Enemy.EnemyType) -> float:
	match type:
		Enemy.EnemyType.MINION: return 0.03
		Enemy.EnemyType.WERERAT: return 0.05
		Enemy.EnemyType.ARCHER_RAT: return 0.04
		Enemy.EnemyType.SKELETON: return 0.08
		Enemy.EnemyType.ARMORED_TROLL: return 0.12
		Enemy.EnemyType.ELITE: return 0.20
		Enemy.EnemyType.BOSS: return 0.60
	return 0.03

func _get_culling_stone_drop_chance(type: Enemy.EnemyType) -> float:
	match type:
		Enemy.EnemyType.MINION: return 0.02
		Enemy.EnemyType.WERERAT: return 0.03
		Enemy.EnemyType.ARCHER_RAT: return 0.03
		Enemy.EnemyType.SKELETON: return 0.05
		Enemy.EnemyType.ARMORED_TROLL: return 0.08
		Enemy.EnemyType.ELITE: return 0.15
		Enemy.EnemyType.BOSS: return 0.40
	return 0.02

func _get_random_loot_item(type: Enemy.EnemyType) -> ItemData:
	var item_creators: Array[Callable] = [
		ItemData.create_iron_helm,
		ItemData.create_leather_chest,
		ItemData.create_iron_sword,
		ItemData.create_wooden_shield,
		ItemData.create_gold_ring,
		ItemData.create_leather_boots,
		ItemData.create_iron_gauntlets,
		ItemData.create_utility_belt,
	]
	# Better enemies drop better items
	if type == Enemy.EnemyType.ELITE or type == Enemy.EnemyType.BOSS or type == Enemy.EnemyType.ARMORED_TROLL:
		item_creators.append(ItemData.create_flame_dagger)
		item_creators.append(ItemData.create_frost_orb)
		item_creators.append(ItemData.create_ice_quiver)
		item_creators.append(ItemData.create_fire_quiver)
		item_creators.append(ItemData.create_belt_of_greater_healing)
	var idx = randi() % item_creators.size()
	return item_creators[idx].call()

func _get_random_loot_card() -> Card:
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

# ============================================
# SPATIAL QUERIES
# ============================================

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
