class_name BuffManager
extends Node

## Manages buffs on a character (player or enemy)

signal buff_applied(buff: Buff)
signal buff_removed(buff: Buff)
signal buff_ticked(buff: Buff)
signal buffs_changed
signal thorns_triggered(damage: int)
signal cleanse_triggered(count: int)

var buffs: Array[Buff] = []
var owner_stats = null  # PlayerStats - untyped to avoid circular dependency
var owner_node: Node3D
var debuff_manager = null  # DebuffManager - untyped to avoid circular dependency
var approach_armor_per_move: int = 0
var approach_tempo_remaining: int = 0
var poisoned_blood_active: bool = false
var poisoned_blood_tempo: int = 0
var understanding_tempo: int = 0  # Delayed crit: when reaches 0, apply ENLIGHTENED
var enchanted_quiver_charges: int = 0  # Next N ranged attacks create a free arrow card
var tighten_string_charges: int = 0  # Next N ranged attacks: +3 tempo, +6 dmg, +6 range, +20% crit

func initialize(stats = null, owner: Node3D = null) -> void:
	owner_stats = stats
	owner_node = owner
	buffs.clear()

func connect_debuff_manager(dm) -> void:
	debuff_manager = dm

# ============================================
# ADDING/REMOVING BUFFS
# ============================================

func apply_buff(buff: Buff) -> void:
	# Handle Cleanse immediately
	if buff.buff_type == Buff.BuffType.CLEANSE:
		_execute_cleanse(buff.value)
		return
	
	# Check if buff already exists (refresh or stack)
	var existing = get_buff(buff.buff_type)
	
	if existing:
		# Refresh duration/charges to higher value
		if buff.is_charge_based():
			existing.charges = max(existing.charges, buff.charges)
		else:
			existing.duration = max(existing.duration, buff.duration)
		
		# Stack value for stackable buffs
		if _is_stackable(buff.buff_type):
			existing.stacks += 1
			existing.value += buff.value
			existing._set_name_and_description()
		
		print("[BUFF] %s refreshed/stacked (value: %d)" % [buff.buff_name, existing.value])
	else:
		buffs.append(buff)
		print("[BUFF] Applied: %s for %s" % [buff.buff_name, buff.get_duration_display()])
	
	buff_applied.emit(buff)
	buffs_changed.emit()

func _is_stackable(type: Buff.BuffType) -> bool:
	match type:
		Buff.BuffType.THORNS, Buff.BuffType.REGEN, Buff.BuffType.STRENGTHEN, Buff.BuffType.BOLSTER:
			return true
	return false

func remove_buff(type: Buff.BuffType) -> void:
	for i in range(buffs.size() - 1, -1, -1):
		if buffs[i].buff_type == type:
			var removed = buffs[i]
			buffs.remove_at(i)
			buff_removed.emit(removed)
			buffs_changed.emit()
			print("[BUFF] Removed: %s" % removed.buff_name)
			return

func get_buff(type: Buff.BuffType) -> Buff:
	for buff in buffs:
		if buff.buff_type == type:
			return buff
	return null

func has_buff(type: Buff.BuffType) -> bool:
	return get_buff(type) != null

func clear_all_buffs() -> void:
	buffs.clear()
	buffs_changed.emit()
	print("[BUFF] All buffs cleared")

# ============================================
# TURN PROCESSING
# ============================================

func process_turn_start() -> Dictionary:
	var result = {
		"health_gained": 0,
		"mana_gained": 0,
		"armor_gained": 0,
		"extra_draws": 0
	}
	
	for buff in buffs:
		match buff.buff_type:
			Buff.BuffType.REGEN:
				result["health_gained"] += buff.value
				print("[BUFF] Regen heals %d" % buff.value)
			
			Buff.BuffType.FOCUSED:
				result["mana_gained"] += 1
				print("[BUFF] Focused grants +1 mana")
			
			Buff.BuffType.BLESSED:
				result["extra_draws"] += buff.value
				print("[BUFF] Blessed grants %d extra draw(s)" % buff.value)
			
			Buff.BuffType.SMITH:
				result["armor_gained"] += buff.value
				print("[BUFF] Smith grants %d armor" % buff.value)
	
	# Apply effects
	if owner_stats:
		if result["health_gained"] > 0:
			owner_stats.heal(result["health_gained"])
		if result["mana_gained"] > 0:
			owner_stats.gain_mana(result["mana_gained"])
		if result["armor_gained"] > 0:
			owner_stats.add_armor(result["armor_gained"])
	
	return result

func process_turn_end() -> void:
	# Tick approach armor-on-move
	if approach_tempo_remaining > 0:
		approach_tempo_remaining -= 5
		if approach_tempo_remaining <= 0:
			approach_armor_per_move = 0
			print("[BUFF] Approach expired")

	# Tick poisoned blood
	if poisoned_blood_tempo > 0:
		poisoned_blood_tempo -= 5
		if poisoned_blood_tempo <= 0:
			poisoned_blood_active = false
			print("[BUFF] Poisoned Blood expired")

	# Tick understanding delayed crit
	if understanding_tempo > 0:
		understanding_tempo -= 5
		if understanding_tempo <= 0:
			apply_buff(Buff.create_enlightened(100, 1, "Understanding"))
			print("[BUFF] Understanding ready! Next attack will auto-crit")

	# Regen: lose 1 regen value at end of turn
	var regen = get_buff(Buff.BuffType.REGEN)
	if regen:
		regen.value -= 1
		regen._set_name_and_description()
		if regen.value <= 0:
			remove_buff(Buff.BuffType.REGEN)
			print("[BUFF] Regen expired (0 stacks remaining)")
		else:
			print("[BUFF] Regen decayed to %d" % regen.value)
			buffs_changed.emit()

	var expired: Array[Buff] = []

	for buff in buffs:
		if not buff.is_charge_based():
			buff_ticked.emit(buff)
			if buff.tick():
				expired.append(buff)

	for buff in expired:
		# Morphine penalty on expiry: lose the temp HP and take 2 damage
		if buff.buff_type == Buff.BuffType.MORPHINE and owner_stats:
			var armor_to_remove = buff.value
			owner_stats.current_armor = max(0, owner_stats.current_armor - armor_to_remove)
			owner_stats.armor_changed.emit(owner_stats.current_armor)
			owner_stats.take_damage(2)
			print("[BUFF] Morphine expired! Lost %d armor and took 2 damage" % armor_to_remove)

		buffs.erase(buff)
		buff_removed.emit(buff)
		print("[BUFF] Expired: %s" % buff.buff_name)

	if expired.size() > 0:
		buffs_changed.emit()

# ============================================
# COMBAT QUERIES
# ============================================

func get_thorns_damage() -> int:
	var thorns = get_buff(Buff.BuffType.THORNS)
	return thorns.value if thorns else 0

func on_attacked(attacker) -> void:
	var thorns = get_buff(Buff.BuffType.THORNS)
	if thorns and thorns.value > 0 and attacker and attacker.has_method("take_damage"):
		attacker.take_damage(thorns.value)
		thorns_triggered.emit(thorns.value)
		print("[BUFF] Thorns deals %d damage to attacker!" % thorns.value)
		# Lose 1 thorn after each hit
		thorns.value -= 1
		thorns._set_name_and_description()
		if thorns.value <= 0:
			remove_buff(Buff.BuffType.THORNS)
			print("[BUFF] Thorns expired (0 stacks remaining)")
		else:
			buffs_changed.emit()

func has_wear_down() -> bool:
	return has_buff(Buff.BuffType.WEAR_DOWN)

func has_life_steal() -> bool:
	return has_buff(Buff.BuffType.LIFE_STEAL)

func consume_life_steal(damage_dealt: int) -> int:
	var life_steal = get_buff(Buff.BuffType.LIFE_STEAL)
	if life_steal:
		if life_steal.use_charge():
			remove_buff(Buff.BuffType.LIFE_STEAL)
		if owner_stats:
			owner_stats.heal(damage_dealt)
			print("[BUFF] Life Steal healed %d HP!" % damage_dealt)
		return damage_dealt
	return 0

func get_strengthen_bonus() -> int:
	var strengthen = get_buff(Buff.BuffType.STRENGTHEN)
	return strengthen.value if strengthen else 0

func consume_strengthen() -> int:
	# Returns bonus and uses a charge
	var strengthen = get_buff(Buff.BuffType.STRENGTHEN)
	if strengthen:
		var bonus = strengthen.value
		if strengthen.use_charge():
			remove_buff(Buff.BuffType.STRENGTHEN)
		return bonus
	return 0

func get_enlightened_crit_chance() -> int:
	var enlightened = get_buff(Buff.BuffType.ENLIGHTENED)
	return enlightened.value if enlightened else 0

func consume_enlightened() -> int:
	# Returns crit chance bonus and uses a charge
	var enlightened = get_buff(Buff.BuffType.ENLIGHTENED)
	if enlightened:
		var bonus = enlightened.value
		if enlightened.use_charge():
			remove_buff(Buff.BuffType.ENLIGHTENED)
		return bonus
	return 0

func roll_crit(base_crit_chance: int = 0) -> bool:
	var total_chance = base_crit_chance + get_enlightened_crit_chance()
	if total_chance <= 0:
		return false
	
	var roll = randi() % 100
	var is_crit = roll < total_chance
	
	if is_crit:
		print("[BUFF] CRITICAL HIT! (rolled %d < %d)" % [roll, total_chance])
	
	return is_crit

func get_bolster_bonus() -> int:
	var bolster = get_buff(Buff.BuffType.BOLSTER)
	return bolster.value if bolster else 0

func consume_bolster() -> int:
	# Called when gaining armor - returns bonus and uses a charge
	var bolster = get_buff(Buff.BuffType.BOLSTER)
	if bolster:
		var bonus = bolster.value
		if bolster.use_charge():
			remove_buff(Buff.BuffType.BOLSTER)
		return bonus
	return 0

# ============================================
# MOVEMENT QUERIES
# ============================================

func get_haste_bonus() -> int:
	var haste = get_buff(Buff.BuffType.HASTE)
	return haste.value if haste else 0

func get_extra_movement_per_tempo() -> int:
	return get_haste_bonus()

func on_movement(tiles: int) -> int:
	var armor_gained = 0
	if approach_armor_per_move > 0 and approach_tempo_remaining > 0:
		armor_gained = approach_armor_per_move * tiles
		if owner_stats:
			owner_stats.add_armor(armor_gained)
			print("[BUFF] Approach grants %d armor from movement" % armor_gained)
	return armor_gained

# ============================================
# ARMOR QUERIES
# ============================================

func should_ignore_armor_decay() -> bool:
	return has_buff(Buff.BuffType.FORTIFY)

# ============================================
# DRAW QUERIES
# ============================================

func get_extra_draws() -> int:
	var blessed = get_buff(Buff.BuffType.BLESSED)
	return blessed.value if blessed else 0

# ============================================
# CLEANSE
# ============================================

func _execute_cleanse(count: int) -> void:
	if not debuff_manager:
		print("[BUFF] Cleanse failed - no debuff manager connected")
		return
	
	var removed = 0
	var debuffs_to_remove = debuff_manager.debuffs.duplicate()
	debuffs_to_remove.shuffle()  # Random order
	
	for i in range(min(count, debuffs_to_remove.size())):
		var debuff = debuffs_to_remove[i]
		debuff_manager.remove_debuff(debuff.debuff_type)
		removed += 1
	
	cleanse_triggered.emit(removed)
	print("[BUFF] Cleanse removed %d debuff(s)" % removed)

# ============================================
# DISPLAY
# ============================================

func get_buff_display_list() -> Array[String]:
	var list: Array[String] = []
	for buff in buffs:
		list.append("%s (%s)" % [buff.get_short_display(), buff.get_duration_display()])
	return list
	
# ============================================
# DAMAGE REDUCTION QUERIES (Brace, Resilient)
# ============================================

func get_brace_reduction() -> int:
	var brace = get_buff(Buff.BuffType.BRACE)
	return brace.value if brace else 0

func consume_brace() -> int:
	# Returns percent damage reduction and uses charge
	var brace = get_buff(Buff.BuffType.BRACE)
	if brace:
		var percent = brace.value
		if brace.use_charge():
			remove_buff(Buff.BuffType.BRACE)
		return percent
	return 0

func get_resilient_percent() -> int:
	var resilient = get_buff(Buff.BuffType.RESILIENT)
	return resilient.value if resilient else 0

func consume_resilient() -> int:
	# Returns percent reduction and uses charge
	var resilient = get_buff(Buff.BuffType.RESILIENT)
	if resilient:
		var percent = resilient.value
		if resilient.use_charge():
			remove_buff(Buff.BuffType.RESILIENT)
		return percent
	return 0

func calculate_damage_reduction(incoming_damage: int) -> int:
	# Calculate total damage after Resilient and Brace
	var damage = incoming_damage

	# Resilient: percentage reduction first (turn-based, always active while buff exists)
	var resilient_percent = get_resilient_percent()
	if resilient_percent > 0:
		var reduction = floori(damage * resilient_percent / 100.0)
		damage -= reduction
		print("[BUFF] Resilient reduces damage by %d%% (%d)" % [resilient_percent, reduction])

	# Brace: percentage reduction second (charge-based, consumes a charge)
	var brace_percent = consume_brace()
	if brace_percent > 0:
		var reduction = floori(damage * brace_percent / 100.0)
		damage -= reduction
		print("[BUFF] Brace reduces damage by %d%% (%d)" % [brace_percent, reduction])

	return max(0, damage)
	
# ============================================
# TEMPO QUERIES (Steady)
# ============================================

func should_skip_tempo() -> bool:
	return has_buff(Buff.BuffType.STEADY)

func consume_steady() -> bool:
	# Returns true if Steady was active and consumed
	var steady = get_buff(Buff.BuffType.STEADY)
	if steady:
		if steady.use_charge():
			remove_buff(Buff.BuffType.STEADY)
		return true
	return false
