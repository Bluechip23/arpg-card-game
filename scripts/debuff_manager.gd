class_name DebuffManager
extends Node

## Manages debuffs on a character (player or enemy)

signal debuff_applied(debuff: Debuff)
signal debuff_removed(debuff: Debuff)
signal debuff_ticked(debuff: Debuff)
signal debuffs_changed
signal magnetize_pull(tiles: int, direction: Vector2)

var debuffs: Array[Debuff] = []
var owner_stats = null  # PlayerStats - untyped to avoid circular dependency
var owner_node: Node2D

# For Tethered - tracks starting position
var tether_origin: Vector2 = Vector2.ZERO

# For tracking linked ally damage sharing
var linked_ally: Node2D = null

func initialize(stats = null, owner: Node2D = null) -> void:
	owner_stats = stats
	owner_node = owner
	debuffs.clear()
	if owner_node:
		tether_origin = owner_node.position

func apply_debuff(debuff: Debuff) -> void:
	var existing = get_debuff(debuff.debuff_type)
	
	if existing:
		existing.duration = max(existing.duration, debuff.duration)
		existing.stacks += 1
		existing.value = debuff.value * existing.stacks
		print("[DEBUFF] %s stacked to %d (value: %d)" % [debuff.debuff_name, existing.stacks, existing.value])
	else:
		debuffs.append(debuff)
		
		# Special handling for Hexed and Locked - pick random card
		if debuff.debuff_type == Debuff.DebuffType.HEXED or debuff.debuff_type == Debuff.DebuffType.LOCKED:
			_assign_random_card_to_debuff(debuff)
		
		print("[DEBUFF] Applied: %s for %d turns" % [debuff.debuff_name, debuff.duration])
	
	debuff_applied.emit(debuff)
	debuffs_changed.emit()

func _assign_random_card_to_debuff(debuff: Debuff) -> void:
	# This will be called from deck_manager which has access to hand
	# For now, set to -1 and let deck_manager handle it
	debuff.affected_card_index = -1

func remove_debuff(type: Debuff.DebuffType) -> void:
	for i in range(debuffs.size() - 1, -1, -1):
		if debuffs[i].debuff_type == type:
			var removed = debuffs[i]
			debuffs.remove_at(i)
			debuff_removed.emit(removed)
			debuffs_changed.emit()
			print("[DEBUFF] Removed: %s" % removed.debuff_name)
			return

func get_debuff(type: Debuff.DebuffType) -> Debuff:
	for debuff in debuffs:
		if debuff.debuff_type == type:
			return debuff
	return null

func has_debuff(type: Debuff.DebuffType) -> bool:
	return get_debuff(type) != null

func clear_all_debuffs() -> void:
	debuffs.clear()
	debuffs_changed.emit()
	print("[DEBUFF] All debuffs cleared")

# ============================================
# TURN PROCESSING
# ============================================

func process_turn_start() -> Dictionary:
	var result = {
		"damage_taken": 0,
		"mana_lost": 0,
		"ally_damage": 0,
		"pull_direction": Vector2.ZERO,
		"pull_tiles": 0
	}
	
	for debuff in debuffs:
		match debuff.debuff_type:
			Debuff.DebuffType.BURN:
				result["damage_taken"] += debuff.value
				print("[DEBUFF] Burn deals %d damage" % debuff.value)
			
			Debuff.DebuffType.POISON:
				result["damage_taken"] += debuff.value
				print("[DEBUFF] Poison deals %d damage" % debuff.value)
			
			Debuff.DebuffType.DRAIN:
				result["mana_lost"] += debuff.value
				print("[DEBUFF] Drain steals %d mana" % debuff.value)
			
			Debuff.DebuffType.SHOCKED:
				result["ally_damage"] += debuff.value
				print("[DEBUFF] Shocked deals %d to nearby allies" % debuff.value)
			
			Debuff.DebuffType.MAGNETIZED:
				var pull_info = _calculate_magnetize_pull(debuff.value)
				result["pull_direction"] = pull_info["direction"]
				result["pull_tiles"] = pull_info["tiles"]
				print("[DEBUFF] Magnetized pulls %d tiles" % debuff.value)
			
			Debuff.DebuffType.BRITTLE:
				# Extra armor decay handled in process_armor_decay
				pass
	
	# Apply damage (with Vulnerable modifier)
	var damage = result["damage_taken"]
	if damage > 0:
		damage = _apply_vulnerable_modifier(damage)
		if owner_stats:
			owner_stats.take_damage(damage)
	
	if owner_stats and result["mana_lost"] > 0:
		owner_stats.current_mana = max(0, owner_stats.current_mana - result["mana_lost"])
		owner_stats.mana_changed.emit(owner_stats.current_mana, owner_stats.max_mana)
	
	# Emit magnetize signal for movement handling
	if result["pull_tiles"] > 0:
		magnetize_pull.emit(result["pull_tiles"], result["pull_direction"])
	
	return result

func _calculate_magnetize_pull(tiles: int) -> Dictionary:
	if not owner_node:
		return {"direction": Vector2.ZERO, "tiles": 0}
	
	# Find nearest enemy - this requires access to enemy list
	# We'll emit a signal and let main.gd handle the actual movement
	return {"direction": Vector2.ZERO, "tiles": tiles}

func process_turn_end() -> void:
	var expired: Array[Debuff] = []
	
	for debuff in debuffs:
		debuff_ticked.emit(debuff)
		if debuff.tick():
			expired.append(debuff)
	
	for debuff in expired:
		debuffs.erase(debuff)
		debuff_removed.emit(debuff)
		print("[DEBUFF] Expired: %s" % debuff.debuff_name)
	
	if expired.size() > 0:
		debuffs_changed.emit()

func process_armor_decay(base_decay: int) -> int:
	# Returns total armor decay including Brittle
	var total_decay = base_decay
	var brittle = get_debuff(Debuff.DebuffType.BRITTLE)
	if brittle:
		total_decay += brittle.value
		print("[DEBUFF] Brittle adds %d armor decay" % brittle.value)
	return total_decay

# ============================================
# DAMAGE MODIFIERS
# ============================================

func _apply_vulnerable_modifier(damage: int) -> int:
	var vulnerable = get_debuff(Debuff.DebuffType.VULNERABLE)
	if vulnerable:
		var increase = floori(damage * vulnerable.value / 100.0)
		damage += increase
		print("[DEBUFF] Vulnerable increases damage by %d" % increase)
	return damage

func get_armor_effectiveness() -> float:
	# Returns multiplier for armor (1.0 = full, 0.5 = half effective)
	var exposed = get_debuff(Debuff.DebuffType.EXPOSED)
	if exposed:
		return max(0.0, 1.0 - (exposed.value / 100.0))
	return 1.0

func modify_incoming_damage(damage: int) -> int:
	# Apply Vulnerable
	return _apply_vulnerable_modifier(damage)

func calculate_linked_damage(damage: int) -> int:
	# Returns damage to share with linked ally
	var linked = get_debuff(Debuff.DebuffType.LINKED)
	if linked:
		return floori(damage * linked.value / 100.0)
	return 0

# ============================================
# MOVEMENT QUERIES
# ============================================

func can_move() -> bool:
	if has_debuff(Debuff.DebuffType.STUN):
		return false
	if has_debuff(Debuff.DebuffType.ROOTED):
		return false
	return true

func get_movement_reduction() -> int:
	var slowed = get_debuff(Debuff.DebuffType.SLOWED)
	return slowed.value if slowed else 0

func get_random_movement_direction() -> bool:
	return has_debuff(Debuff.DebuffType.INEBRIATE)

func is_tethered() -> bool:
	return has_debuff(Debuff.DebuffType.TETHERED)

func get_tether_range() -> int:
	var tethered = get_debuff(Debuff.DebuffType.TETHERED)
	return tethered.value if tethered else 0

func set_tether_origin(pos: Vector2) -> void:
	tether_origin = pos

func get_tether_origin() -> Vector2:
	return tether_origin

func is_within_tether_range(target_pos: Vector2, grid_size: int = 64) -> bool:
	if not is_tethered():
		return true
	
	var distance_tiles = floori(tether_origin.distance_to(target_pos) / grid_size)
	return distance_tiles <= get_tether_range()

# ============================================
# CARD QUERIES
# ============================================

func can_act() -> bool:
	return not has_debuff(Debuff.DebuffType.STUN)

func can_play_cards() -> bool:
	if has_debuff(Debuff.DebuffType.STUN):
		return false
	if has_debuff(Debuff.DebuffType.FROZEN):
		return false
	return true

func can_play_attack_cards() -> bool:
	if not can_play_cards():
		return false
	return not has_debuff(Debuff.DebuffType.DISARM)

func can_play_spell_cards() -> bool:
	if not can_play_cards():
		return false
	return not has_debuff(Debuff.DebuffType.SILENCE)

func can_draw_cards() -> bool:
	return not has_debuff(Debuff.DebuffType.CUFFED)

func get_attack_mana_increase() -> int:
	var staggered = get_debuff(Debuff.DebuffType.STAGGERED)
	return staggered.value if staggered else 0

func get_tempo_increase() -> int:
	var weighted = get_debuff(Debuff.DebuffType.WEIGHTED)
	return weighted.value if weighted else 0

func get_hexed_mana_increase() -> int:
	var hexed = get_debuff(Debuff.DebuffType.HEXED)
	return hexed.value if hexed else 0

func get_hexed_card_index() -> int:
	var hexed = get_debuff(Debuff.DebuffType.HEXED)
	return hexed.affected_card_index if hexed else -1

func set_hexed_card_index(index: int) -> void:
	var hexed = get_debuff(Debuff.DebuffType.HEXED)
	if hexed:
		hexed.affected_card_index = index

func get_locked_card_index() -> int:
	var locked = get_debuff(Debuff.DebuffType.LOCKED)
	return locked.affected_card_index if locked else -1

func set_locked_card_index(index: int) -> void:
	var locked = get_debuff(Debuff.DebuffType.LOCKED)
	if locked:
		locked.affected_card_index = index

func is_card_locked(index: int) -> bool:
	var locked = get_debuff(Debuff.DebuffType.LOCKED)
	if locked and locked.affected_card_index == index:
		return true
	return false

func is_card_hexed(index: int) -> bool:
	var hexed = get_debuff(Debuff.DebuffType.HEXED)
	if hexed and hexed.affected_card_index == index:
		return true
	return false

func get_clumsy_chance() -> int:
	var clumsy = get_debuff(Debuff.DebuffType.CLUMSY)
	return clumsy.value if clumsy else 0

func roll_clumsy() -> bool:
	# Returns true if clumsy triggers (should discard a card)
	var chance = get_clumsy_chance()
	if chance > 0:
		var roll = randi() % 100
		if roll < chance:
			print("[DEBUFF] Clumsy triggered! (%d < %d)" % [roll, chance])
			return true
	return false

func get_damage_reduction() -> int:
	var reduction = 0
	var poison = get_debuff(Debuff.DebuffType.POISON)
	var cursed = get_debuff(Debuff.DebuffType.CURSED)
	if poison:
		reduction += poison.value
	if cursed:
		reduction += cursed.value
	return reduction

func get_self_damage_percent() -> float:
	var cursed = get_debuff(Debuff.DebuffType.CURSED)
	if cursed:
		return cursed.value * 0.1
	return 0.0

# ============================================
# MOVEMENT EFFECTS
# ============================================

func on_movement(tiles_moved: int) -> int:
	var bleed = get_debuff(Debuff.DebuffType.BLEED)
	if bleed:
		var damage = bleed.value * tiles_moved
		damage = _apply_vulnerable_modifier(damage)
		if owner_stats:
			owner_stats.take_damage(damage)
		print("[DEBUFF] Bleed triggered: %d damage from %d tiles" % [damage, tiles_moved])
		return damage
	return 0

func on_attack() -> int:
	var burn = get_debuff(Debuff.DebuffType.BURN)
	if burn:
		var damage = _apply_vulnerable_modifier(burn.value)
		if owner_stats:
			owner_stats.take_damage(damage)
		print("[DEBUFF] Burn triggered on attack: %d damage" % damage)
		return damage
	return 0

# ============================================
# DISPLAY
# ============================================

func get_debuff_display_list() -> Array[String]:
	var list: Array[String] = []
	for debuff in debuffs:
		list.append("%s (%d)" % [debuff.get_short_display(), debuff.duration])
	return list
