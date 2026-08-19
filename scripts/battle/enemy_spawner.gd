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

func spawn_forest_pack() -> void:
	## A sampler of the forest-act bestiary for testing. Does not clear existing.
	spawn_enemy(Enemy.EnemyType.GIANT_BEAVER, Vector3(12.5, 0, 4.0))
	spawn_enemy(Enemy.EnemyType.MINI_BEAR, Vector3(13.5, 0, 6.0))
	spawn_enemy(Enemy.EnemyType.MINI_BEAR, Vector3(14.5, 0, 6.5))
	spawn_enemy(Enemy.EnemyType.LARGE_BEAR, Vector3(16.0, 0, 5.0))
	spawn_enemy(Enemy.EnemyType.WOLF, Vector3(12.0, 0, 8.0))
	spawn_enemy(Enemy.EnemyType.WOLF, Vector3(13.0, 0, 9.0))
	spawn_enemy(Enemy.EnemyType.COYOTE, Vector3(11.5, 0, 6.0))
	spawn_enemy(Enemy.EnemyType.BUGBEAR, Vector3(17.0, 0, 8.0))
	spawn_enemy(Enemy.EnemyType.INFECTED_HUNTER, Vector3(18.0, 0, 6.0))
	spawn_enemy(Enemy.EnemyType.GIANT_HAWK, Vector3(15.0, 0, 11.0))
	spawn_enemy(Enemy.EnemyType.TREANT, Vector3(19.0, 0, 9.0))
	spawn_enemy(Enemy.EnemyType.ICE_MAGE, Vector3(20.0, 0, 4.0))
	spawn_enemy(Enemy.EnemyType.FIRE_MAGE, Vector3(20.0, 0, 6.0))
	spawn_enemy(Enemy.EnemyType.SPARK_MAGE, Vector3(21.0, 0, 8.0))
	spawn_enemy(Enemy.EnemyType.AIR_MAGE, Vector3(21.0, 0, 10.0))
	spawn_enemy(Enemy.EnemyType.EARTH_MAGE, Vector3(19.0, 0, 12.0))
	print("[SPAWNER] Forest pack spawned: %d total" % enemies.size())

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

## Quietly remove an enemy WITHOUT killing it: no loot, no on-kill triggers,
## no death animation (The Precious ring wraiths vanish when shadow form
## ends). Since no died signal fires, the wave check is re-run here.
func despawn_enemy(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemies.erase(enemy)
	enemy.queue_free()
	if get_living_enemies().size() == 0:
		all_enemies_defeated.emit()
		print("[SPAWNER] All enemies defeated (last hostile vanished)")

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
		# Reserve every other enemy's INTENDED destination (not just its current
		# tile) right before this one decides, so two enemies acting in the same
		# tick can't pick the same cell and end up stacked.
		_reserve_occupancy(living, enemy)
		enemy.on_tempo_advanced(amount, _target_for(enemy))

func _reserve_occupancy(living: Array, acting) -> void:
	var cells: Array[Vector2i] = []
	for e in living:
		if e == acting or not is_instance_valid(e):
			continue
		cells.append(e.intended_cell())
	acting.occupied_tiles = cells

## Pick the nearest living player for this enemy to act against (co-op aware).
# Player summons (Frankensteins Monsters, Bull Worms). Main refreshes this
# each tempo tick so enemies treat summons as ordinary targetable units.
var summons: Array = []

func _living_summons() -> Array:
	var out := []
	for s in summons:
		if not is_instance_valid(s):
			continue
		if s.get("is_dead") == true:
			continue
		if s.get("burrowed") == true:
			continue  # burrowed worms are untargetable
		out.append(s)
	return out

func _target_for(enemy: Enemy) -> Node3D:
	var candidates := _living_players()
	if candidates.is_empty():
		return player  # solo fallback (or both downed — let it act on P1)
	# Summons count as units: the enemy simply goes for whatever is nearest.
	candidates = candidates + _living_summons()
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
	var loot: Dictionary = {"gold": 0, "item": null, "card": null, "card_pack": null, "culling_stones": 0}

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

	# Card drop chance (rarer than items). A successful card drop sometimes
	# arrives as a sealed PACK instead of a single card (see DropRates).
	var card_chance = _get_card_drop_chance(enemy.enemy_type)
	if randf() < card_chance:
		if randf() < DropRates.PACK_CHANCE_OF_CARD_DROP:
			loot["card_pack"] = DropRates.roll_weighted(DropRates.PACK_TIER_WEIGHTS)
		else:
			loot["card"] = _get_random_loot_card()

	return loot

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

## Loot tier for an enemy type (see DropRates): trash never rolls high-end
## loot on its own, bosses roll the richest table. Unlisted types are "mid".
func get_loot_tier(type: Enemy.EnemyType) -> String:
	match type:
		Enemy.EnemyType.MINION, Enemy.EnemyType.WERERAT, Enemy.EnemyType.ARCHER_RAT, \
		Enemy.EnemyType.ZOMBIE, Enemy.EnemyType.SWARM, Enemy.EnemyType.COYOTE, \
		Enemy.EnemyType.WERERABBIT, Enemy.EnemyType.GIANT_BEAVER, Enemy.EnemyType.SLUDGE, \
		Enemy.EnemyType.PIPE_CRAWLER, Enemy.EnemyType.CRYPT_CRAWLER, Enemy.EnemyType.SCREECHER:
			return DropRates.TIER_TRASH
		Enemy.EnemyType.ELITE, Enemy.EnemyType.ARMORED_TROLL, Enemy.EnemyType.LARGE_BEAR, \
		Enemy.EnemyType.TREANT, Enemy.EnemyType.BUGBEAR, Enemy.EnemyType.VAMPIRE, \
		Enemy.EnemyType.NECROMANCER, Enemy.EnemyType.WEREWOLF, Enemy.EnemyType.SPIRIT_COLLECTOR, \
		Enemy.EnemyType.SEWER_CROC, Enemy.EnemyType.WYVERN, Enemy.EnemyType.ICE_TROLL, \
		Enemy.EnemyType.WHITE_MANTICORE:
			return DropRates.TIER_ELITE
		Enemy.EnemyType.BOSS, Enemy.EnemyType.HYDRA, Enemy.EnemyType.BONE_DRAGON, \
		Enemy.EnemyType.GRAVE_TITAN, Enemy.EnemyType.RAT_KING, Enemy.EnemyType.GRANITE_COLOSSUS:
			return DropRates.TIER_BOSS
	return DropRates.TIER_MID

func _get_random_loot_item(type: Enemy.EnemyType) -> ItemData:
	## Rarity-weighted by enemy tier (see DropRates.ENEMY_ITEM_WEIGHTS).
	## Mythics never roll here — they come exclusively from the per-kill
	## act-mythic layer in main (DropRates.roll_act_mythic_kill).
	var weights: Dictionary = DropRates.ENEMY_ITEM_WEIGHTS[get_loot_tier(type)]
	var rarity = DropRates.roll_weighted(weights)
	var pool = ItemData.get_items_of_rarity(rarity)
	if pool.is_empty():
		pool = ItemData.get_items_of_rarity(ItemData.Rarity.COMMON)
	return pool[randi() % pool.size()]

func _get_random_loot_card() -> Card:
	## Rarity-weighted over every droppable card (see Card.CARD_RARITIES).
	var rarity = DropRates.roll_weighted(DropRates.CARD_WEIGHTS)
	var ids = Card.get_droppable_ids_of_rarity(rarity)
	if ids.is_empty():
		ids = Card.get_droppable_ids_of_rarity(Card.Rarity.BASIC)
	return Card.create_by_id(ids[randi() % ids.size()])

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
