class_name DebuffManager
extends Node

## Manages debuffs on a character (player or enemy)

signal debuff_applied(debuff: Debuff)
signal debuff_removed(debuff: Debuff)
signal debuff_ticked(debuff: Debuff)
signal debuffs_changed
signal magnetize_pull(tiles: int, direction: Vector3)
signal point_to_prove_triggered(debuff: Debuff)  # Emitted when stun/disarm hits with Point to Prove active

var debuffs: Array[Debuff] = []
var owner_stats = null  # PlayerStats - untyped to avoid circular dependency
var owner_node: Node3D

# For Tethered - tracks starting position
var tether_origin: Vector3 = Vector3.ZERO

# For tracking linked ally damage sharing
var linked_ally: Node3D = null

# For Burn - damage doubles each cycle
var burn_damage_next: int = 1

func initialize(stats = null, owner: Node3D = null) -> void:
	owner_stats = stats
	owner_node = owner
	debuffs.clear()
	if owner_node:
		tether_origin = owner_node.position

func apply_debuff(debuff: Debuff) -> void:
	# Burn lifecycle is stack-driven (value = cycles remaining, damage doubling
	# 1, 2, 4...), mirroring the enemy-side model — never duration-expired.
	if debuff.debuff_type == Debuff.DebuffType.BURN:
		debuff.duration = -1

	var existing = get_debuff(debuff.debuff_type)

	if existing:
		# -1 means "until depleted/cleansed" — it always wins the merge.
		if existing.duration < 0 or debuff.duration < 0:
			existing.duration = -1
		else:
			existing.duration = max(existing.duration, debuff.duration)
		existing.stacks += 1
		# Accumulate — recomputing from the newest instance's value corrupted
		# heterogeneous stacks (Bleed 3 + Bleed 1 used to become 2, not 4).
		existing.value += debuff.value
		existing._set_name_and_description()
		print("[DEBUFF] %s stacked to %d (value: %d)" % [debuff.debuff_name, existing.stacks, existing.value])
	else:
		debuffs.append(debuff)

		# Special handling for Hexed and Locked - pick random card
		if debuff.debuff_type == Debuff.DebuffType.HEXED or debuff.debuff_type == Debuff.DebuffType.LOCKED:
			_assign_random_card_to_debuff(debuff)

		# Reset burn damage tracker when burn is first applied
		if debuff.debuff_type == Debuff.DebuffType.BURN:
			burn_damage_next = 1

		print("[DEBUFF] Applied: %s for %d tempo" % [debuff.debuff_name, debuff.duration])
	
	# Cold -> Frozen conversion: at 5 stacks, become Frozen for 1 turn
	if debuff.debuff_type == Debuff.DebuffType.COLD:
		var cold = get_debuff(Debuff.DebuffType.COLD)
		if cold and cold.stacks >= 5:
			remove_debuff(Debuff.DebuffType.COLD)
			var frozen = Debuff.create(Debuff.DebuffType.FROZEN, 0, 5)
			frozen.source_name = "Cold"
			apply_debuff(frozen)
			print("[DEBUFF] Cold reached 5 stacks! Enemy is now Frozen!")
			return

	debuff_applied.emit(debuff)
	debuffs_changed.emit()

	# Point to Prove: signal that player can choose to sacrifice HP to remove stun/disarm
	if owner_stats and owner_stats.has_method("has_skill_tree_passive"):
		if owner_stats.has_skill_tree_passive("point_to_prove"):
			if debuff.debuff_type == Debuff.DebuffType.STUN or debuff.debuff_type == Debuff.DebuffType.DISARM:
				if owner_stats.current_health > 5:
					point_to_prove_triggered.emit(debuff)

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
		"pull_direction": Vector3.ZERO,
		"pull_tiles": 0
	}

	# Burn: damage doubles each cycle (1, 2, 4, 8...); each stack is one cycle
	# of burning, so "apply 5 burn" actually burns longer than "apply 1 burn"
	# (previously stacks were cosmetic and only the doubling counter mattered).
	var burn = get_debuff(Debuff.DebuffType.BURN)
	if burn:
		result["damage_taken"] += burn_damage_next
		print("[DEBUFF] Burn deals %d damage (doubles next cycle)" % burn_damage_next)
		burn_damage_next *= 2
		burn.value -= 1
		burn._set_name_and_description()
		if burn.value <= 0:
			remove_debuff(Debuff.DebuffType.BURN)
			burn_damage_next = 1
			print("[DEBUFF] Burn expired (0 stacks)")

	# Poison: deal value damage, then lose 1 poison. Elixir flips it to healing.
	var poison = get_debuff(Debuff.DebuffType.POISON)
	if poison:
		if owner_stats and "elixir_active" in owner_stats and owner_stats.elixir_active:
			owner_stats.heal(poison.value)
			print("[DEBUFF] Elixir: Poison healed %d instead!" % poison.value)
		else:
			result["damage_taken"] += poison.value
			print("[DEBUFF] Poison deals %d damage" % poison.value)
		poison.value -= 1
		poison._set_name_and_description()
		if poison.value <= 0:
			remove_debuff(Debuff.DebuffType.POISON)
			print("[DEBUFF] Poison expired (0 stacks)")

	# Elixir wears off over time (5 tempo per cycle).
	if owner_stats and "elixir_active" in owner_stats and owner_stats.elixir_active:
		owner_stats.elixir_tempo -= 5
		if owner_stats.elixir_tempo <= 0:
			owner_stats.elixir_active = false
			print("[DEBUFF] Elixir wore off")

	# Drain: lose 10 mana, then lose 1 drain stack
	var drain = get_debuff(Debuff.DebuffType.DRAIN)
	if drain:
		result["mana_lost"] += 10
		print("[DEBUFF] Drain steals 10 mana")
		drain.value -= 1
		drain._set_name_and_description()
		if drain.value <= 0:
			remove_debuff(Debuff.DebuffType.DRAIN)
			print("[DEBUFF] Drain expired (0 stacks)")

	# Shocked: deal value damage to nearby allies, then lose 1 shocked
	var shocked = get_debuff(Debuff.DebuffType.SHOCKED)
	if shocked:
		result["ally_damage"] += shocked.value
		print("[DEBUFF] Shocked deals %d to nearby allies" % shocked.value)
		shocked.value -= 1
		shocked._set_name_and_description()
		if shocked.value <= 0:
			remove_debuff(Debuff.DebuffType.SHOCKED)
			print("[DEBUFF] Shocked expired (0 stacks)")

	# Apply DOT damage (no Vulnerable modifier - that only applies to attacks)
	var damage = result["damage_taken"]
	if damage > 0 and owner_stats:
		owner_stats.take_damage(damage)

	if owner_stats and result["mana_lost"] > 0:
		owner_stats.current_mana = max(0, owner_stats.current_mana - result["mana_lost"])
		owner_stats.mana_changed.emit(owner_stats.current_mana, owner_stats.max_mana)
		if owner_stats.current_mana <= 0 and owner_stats.maintained_mana > 0:
			owner_stats._break_maintained_cards()

	return result

func _calculate_magnetize_pull(tiles: int) -> Dictionary:
	if not owner_node:
		return {"direction": Vector3.ZERO, "tiles": 0}

	# Find nearest enemy - this requires access to enemy list
	# We'll emit a signal and let main.gd handle the actual movement
	return {"direction": Vector3.ZERO, "tiles": tiles}

func process_turn_end() -> void:
	# Magnetized: pull toward nearest enemy at end of turn
	var magnetized = get_debuff(Debuff.DebuffType.MAGNETIZED)
	if magnetized:
		var pull_info = _calculate_magnetize_pull(magnetized.value)
		if pull_info["tiles"] > 0:
			magnetize_pull.emit(pull_info["tiles"], pull_info["direction"])
			print("[DEBUFF] Magnetized pulls %d tiles toward enemy" % magnetized.value)

	# Brittle: consume 1 stack per cycle
	var brittle = get_debuff(Debuff.DebuffType.BRITTLE)
	if brittle:
		brittle.value -= 1
		brittle._set_name_and_description()
		if brittle.value <= 0:
			remove_debuff(Debuff.DebuffType.BRITTLE)
			print("[DEBUFF] Brittle expired (0 stacks)")

	var expired: Array[Debuff] = []

	for debuff in debuffs:
		debuff_ticked.emit(debuff)
		if debuff.tick():
			expired.append(debuff)

	for debuff in expired:
		# Reset burn damage tracker when burn expires
		if debuff.debuff_type == Debuff.DebuffType.BURN:
			burn_damage_next = 1
		debuffs.erase(debuff)
		debuff_removed.emit(debuff)
		print("[DEBUFF] Expired: %s" % debuff.debuff_name)

	if expired.size() > 0:
		debuffs_changed.emit()

func process_armor_decay(base_decay: int) -> int:
	# Returns total armor decay including Brittle (always extra 2 per stack)
	var total_decay = base_decay
	var brittle = get_debuff(Debuff.DebuffType.BRITTLE)
	if brittle:
		total_decay += 2
		print("[DEBUFF] Brittle adds 2 armor decay")
	return total_decay

# ============================================
# DAMAGE MODIFIERS
# ============================================

func _apply_vulnerable_modifier(damage: int) -> int:
	# Vulnerable: always 30% more damage, consume 1 stack
	var vulnerable = get_debuff(Debuff.DebuffType.VULNERABLE)
	if vulnerable:
		var increase = floori(damage * 30.0 / 100.0)
		damage += increase
		print("[DEBUFF] Vulnerable increases damage by 30%% (%d)" % increase)
		vulnerable.value -= 1
		vulnerable._set_name_and_description()
		if vulnerable.value <= 0:
			remove_debuff(Debuff.DebuffType.VULNERABLE)
			print("[DEBUFF] Vulnerable expired (0 stacks)")
	return damage

func get_armor_effectiveness() -> float:
	# Returns multiplier for armor (1.0 = full, 0.7 = 30% less effective)
	# Exposed: always 30% armor penalty, consume 1 stack on hit
	var exposed = get_debuff(Debuff.DebuffType.EXPOSED)
	if exposed:
		exposed.value -= 1
		exposed._set_name_and_description()
		if exposed.value <= 0:
			remove_debuff(Debuff.DebuffType.EXPOSED)
			print("[DEBUFF] Exposed expired (0 stacks)")
		return 0.7  # 30% less armor effectiveness
	return 1.0

func modify_incoming_damage(damage: int) -> int:
	# Apply Vulnerable
	return _apply_vulnerable_modifier(damage)

func calculate_linked_damage(damage: int) -> int:
	# Returns damage to share with linked ally, then consume 1 stack
	var linked = get_debuff(Debuff.DebuffType.LINKED)
	if linked:
		var shared = floori(damage * linked.value / 100.0)
		linked.value -= 1
		linked._set_name_and_description()
		if linked.value <= 0:
			remove_debuff(Debuff.DebuffType.LINKED)
			print("[DEBUFF] Linked expired (0 stacks)")
		return shared
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

func set_tether_origin(pos: Vector3) -> void:
	tether_origin = pos

func get_tether_origin() -> Vector3:
	return tether_origin

func is_within_tether_range(target_pos: Vector3, grid_size: float = 1.0) -> bool:
	if not is_tethered():
		return true

	var diff = tether_origin - target_pos
	var flat_dist = Vector3(diff.x, 0, diff.z).length()
	var distance_tiles = floori(flat_dist / grid_size)
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

func get_damage_reduction_percent() -> float:
	# Cursed: always 20% less damage dealt
	var cursed = get_debuff(Debuff.DebuffType.CURSED)
	if cursed:
		return 0.2
	return 0.0

func get_self_damage_percent() -> float:
	# Cursed: always 20% damage to self
	var cursed = get_debuff(Debuff.DebuffType.CURSED)
	if cursed:
		return 0.2
	return 0.0

# ============================================
# MOVEMENT EFFECTS
# ============================================

func on_movement(tiles_moved: int) -> int:
	var bleed = get_debuff(Debuff.DebuffType.BLEED)
	if bleed:
		var damage = bleed.value * tiles_moved
		if owner_stats:
			owner_stats.take_damage(damage)
		print("[DEBUFF] Bleed triggered: %d damage from %d tiles" % [damage, tiles_moved])
		return damage
	return 0

func on_attack() -> int:
	var burn = get_debuff(Debuff.DebuffType.BURN)
	if burn:
		# Burn on-attack uses the current burn_damage_next value
		if owner_stats:
			owner_stats.take_damage(burn_damage_next)
		print("[DEBUFF] Burn triggered on attack: %d damage" % burn_damage_next)
		return burn_damage_next
	return 0

# ============================================
# DISPLAY
# ============================================

func get_debuff_display_list() -> Array[String]:
	var list: Array[String] = []
	for debuff in debuffs:
		if debuff.duration < 0:
			list.append("%s (∞)" % debuff.get_short_display())
		else:
			list.append("%s (%d)" % [debuff.get_short_display(), debuff.duration])
	return list
