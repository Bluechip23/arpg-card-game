class_name DebuffManager
extends Node

## Manages debuffs on a character (player or enemy)

signal debuff_applied(debuff: Debuff)
signal debuff_removed(debuff: Debuff)
signal debuff_expired(debuff: Debuff)  # NATURAL expiry only, never purges (mirrors the enemy-side signal)
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
	# Stack-driven debuffs never expire by the clock — their stacks are burned
	# by what they react to (movement, damage, card plays), mirroring Burn.
	match debuff.debuff_type:
		Debuff.DebuffType.BURN, Debuff.DebuffType.BLEED, Debuff.DebuffType.SLOWED, \
		Debuff.DebuffType.STAGGERED, Debuff.DebuffType.WEIGHTED, Debuff.DebuffType.CLUMSY, \
		Debuff.DebuffType.WEAKENED:
			debuff.duration = -1

	var existing = get_debuff(debuff.debuff_type)
	# Hexed never merges: each hex is its own instance claiming its own card
	# in hand, so several cards can be hexed at once (Necromancer Bolt hexes 2).
	if debuff.debuff_type == Debuff.DebuffType.HEXED:
		existing = null

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
	
	# Cold -> Frozen conversion: at 5 stacks, become Frozen for 1 cycle.
	# Stacks are the summed VALUE (a Cold-3 application counts 3), matching
	# the displayed count and the enemy-side conversion.
	if debuff.debuff_type == Debuff.DebuffType.COLD:
		var cold = get_debuff(Debuff.DebuffType.COLD)
		if cold and cold.value >= 5:
			remove_debuff(Debuff.DebuffType.COLD)
			var frozen = Debuff.create(Debuff.DebuffType.FROZEN, 0, 5)
			frozen.source_name = "Cold"
			apply_debuff(frozen)
			print("[DEBUFF] Cold reached 5 stacks! Enemy is now Frozen!")
			return

	debuff_applied.emit(debuff)
	debuffs_changed.emit()

	# Point to Prove: signal that player can choose to sacrifice HP to remove
	# stun/disarm. Only offer it when surviving the rank-scaled cost (20%..6%
	# of max HP) is possible.
	if owner_stats and owner_stats.has_method("has_skill_tree_passive"):
		if owner_stats.has_skill_tree_passive("point_to_prove"):
			if debuff.debuff_type == Debuff.DebuffType.STUN or debuff.debuff_type == Debuff.DebuffType.DISARM:
				var ptp_pct: int = PassiveScaling.value("point_to_prove", "hp_percent", owner_stats.get_passive_level("point_to_prove"))
				var ptp_cost: int = maxi(1, ceili(owner_stats.max_health * ptp_pct / 100.0))
				if owner_stats.current_health > ptp_cost:
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

	# Poison: deal value damage, then lose 1 poison. Elixir flips a tick to
	# healing and burns one Elixir stack per converted tick.
	var poison = get_debuff(Debuff.DebuffType.POISON)
	if poison:
		if owner_stats and "elixir_stacks" in owner_stats and owner_stats.elixir_stacks > 0:
			owner_stats.heal(poison.value)
			owner_stats.elixir_stacks -= 1
			print("[DEBUFF] Elixir: Poison healed %d instead! (%d stack(s) left)" % [poison.value, owner_stats.elixir_stacks])
		else:
			result["damage_taken"] += poison.value
			print("[DEBUFF] Poison deals %d damage" % poison.value)
		poison.value -= 1
		poison._set_name_and_description()
		if poison.value <= 0:
			remove_debuff(Debuff.DebuffType.POISON)
			print("[DEBUFF] Poison expired (0 stacks)")

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

	# Timed durations no longer tick here — advance_time (below) runs on every
	# raw tempo advance so durations like "3 tempo" work.

## Advance timed debuff durations by raw tempo. Called on every tempo advance
## (any amount), so stun/frozen/etc handle durations not divisible by 5.
func advance_time(amount: int) -> void:
	if amount <= 0 or debuffs.is_empty():
		return
	var expired: Array[Debuff] = []
	for debuff in debuffs:
		if debuff.advance_time(amount):
			expired.append(debuff)

	for debuff in expired:
		# Reset burn damage tracker when burn expires
		if debuff.debuff_type == Debuff.DebuffType.BURN:
			burn_damage_next = 1
		debuffs.erase(debuff)
		# Natural expiry only — a purge goes through remove_debuff and never
		# fires this. Marvolo's Misunderstanding detonates off it.
		debuff_expired.emit(debuff)
		debuff_removed.emit(debuff)
		print("[DEBUFF] Expired: %s" % debuff.debuff_name)

	if expired.size() > 0:
		debuffs_changed.emit()

func process_armor_decay(base_decay: int) -> int:
	# Returns total armor decay including Brittle (a flat extra 2 while any stacks remain)
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

func modify_incoming_damage(damage: int) -> int:
	# Apply Vulnerable
	return _apply_vulnerable_modifier(damage)

func calculate_linked_damage(damage: int) -> int:
	# Fixed 20% share while Linked lasts; the debuff drains by tempo, not hits.
	var linked = get_debuff(Debuff.DebuffType.LINKED)
	if linked:
		return floori(damage * Debuff.LINKED_SHARE / 100.0)
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

func is_slowed() -> bool:
	return has_debuff(Debuff.DebuffType.SLOWED)

## Slowed: burn one stack for a tile moved. Called by the tempo charger, which
## also prices the tile at Debuff.SLOWED_TEMPO_PER_TILE instead of 1.
func consume_slowed_stack() -> void:
	var slowed = get_debuff(Debuff.DebuffType.SLOWED)
	if slowed == null:
		return
	slowed.value -= 1
	slowed._set_name_and_description()
	if slowed.value <= 0:
		remove_debuff(Debuff.DebuffType.SLOWED)
		print("[DEBUFF] Slowed expired (0 stacks)")
	else:
		debuffs_changed.emit()

func get_random_movement_direction() -> bool:
	return has_debuff(Debuff.DebuffType.INEBRIATE)

func is_tethered() -> bool:
	return has_debuff(Debuff.DebuffType.TETHERED)

func get_tether_range() -> int:
	# Fixed leash: the debuff's stacks are its remaining tempo, never the radius.
	return Debuff.TETHER_RANGE if is_tethered() else 0

func set_tether_origin(pos: Vector3) -> void:
	tether_origin = pos

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
	# Fixed surcharge while any stacks remain; stacks burn per attack card played.
	return Debuff.STAGGERED_MANA if has_debuff(Debuff.DebuffType.STAGGERED) else 0

func get_tempo_increase() -> int:
	# Fixed surcharge while any stacks remain; stacks burn per card played.
	return Debuff.WEIGHTED_TEMPO if has_debuff(Debuff.DebuffType.WEIGHTED) else 0

## Stack bookkeeping when a card is successfully played: Weighted and Clumsy
## burn on every card, Staggered only on attack cards.
func on_card_played(is_attack_card: bool) -> void:
	for entry in [[Debuff.DebuffType.WEIGHTED, true], [Debuff.DebuffType.CLUMSY, true],
			[Debuff.DebuffType.STAGGERED, is_attack_card]]:
		if not entry[1]:
			continue
		var d = get_debuff(entry[0])
		if d == null:
			continue
		d.value -= 1
		d._set_name_and_description()
		if d.value <= 0:
			remove_debuff(entry[0])
		else:
			debuffs_changed.emit()

## Every Hexed instance — each one claims its own card in hand.
func get_hexed_debuffs() -> Array[Debuff]:
	var out: Array[Debuff] = []
	for d in debuffs:
		if d.debuff_type == Debuff.DebuffType.HEXED:
			out.append(d)
	return out

func get_hexed_mana_increase(index: int) -> int:
	## Total hex surcharge on THIS card. Hexes usually spread across different
	## cards, but stack onto one when there are more hexes than cards.
	var total := 0
	for d in get_hexed_debuffs():
		if d.affected_card_index == index:
			total += d.value
	return total

## Playing a hexed card (paying its surcharge) clears every hex riding it.
func remove_hexes_on_card(index: int) -> void:
	var removed_any := false
	for i in range(debuffs.size() - 1, -1, -1):
		var d = debuffs[i]
		if d.debuff_type == Debuff.DebuffType.HEXED and d.affected_card_index == index:
			debuffs.remove_at(i)
			debuff_removed.emit(d)
			removed_any = true
			print("[DEBUFF] Hex broken (card %d played)" % index)
	if removed_any:
		debuffs_changed.emit()

## A card left the hand — every hex claiming a later card shifts down one.
func shift_hexed_indices(removed_index: int) -> void:
	for d in get_hexed_debuffs():
		if d.affected_card_index > removed_index:
			d.affected_card_index -= 1

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
	for d in get_hexed_debuffs():
		if d.affected_card_index == index:
			return true
	return false

func get_clumsy_chance() -> int:
	# Fixed chance while any stacks remain; stacks burn per card played.
	return Debuff.CLUMSY_CHANCE if has_debuff(Debuff.DebuffType.CLUMSY) else 0

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
	var reduction := 0.0
	# Cursed: always 20% less damage dealt
	if has_debuff(Debuff.DebuffType.CURSED):
		reduction += 0.2
	# Weakened (mirrors the enemy-side Weaken): -30% damage dealt while any
	# stacks remain; one stack burns per attack (see on_attack).
	var weakened = get_debuff(Debuff.DebuffType.WEAKENED)
	if weakened and weakened.value > 0:
		reduction += Debuff.WEAKENED_REDUCTION / 100.0
	return minf(reduction, 0.9)

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
	# Bleed: 1 damage per tile moved, and each point of damage removes a stack.
	var bleed = get_debuff(Debuff.DebuffType.BLEED)
	if bleed:
		var damage = mini(bleed.value, tiles_moved)
		if damage <= 0:
			return 0
		bleed.value -= damage
		bleed._set_name_and_description()
		if owner_stats:
			owner_stats.take_damage(damage)
		print("[DEBUFF] Bleed triggered: %d damage from %d tiles (%d stack(s) left)" % [damage, tiles_moved, bleed.value])
		if bleed.value <= 0:
			remove_debuff(Debuff.DebuffType.BLEED)
			print("[DEBUFF] Bleed expired (0 stacks)")
		else:
			debuffs_changed.emit()
		return damage
	return 0

func on_attack() -> int:
	# Weakened: the attack just resolved (already reduced) — burn one stack.
	var weakened = get_debuff(Debuff.DebuffType.WEAKENED)
	if weakened:
		weakened.value -= 1
		weakened._set_name_and_description()
		if weakened.value <= 0:
			remove_debuff(Debuff.DebuffType.WEAKENED)
			print("[DEBUFF] Weakened worn off")
		else:
			debuffs_changed.emit()

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
