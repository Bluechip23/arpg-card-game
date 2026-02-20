class_name PlayerStats
extends Node

## Manages player's runtime stats

signal health_changed(current: int, max_val: int)
signal mana_changed(current: float, max_val: int)
signal armor_changed(current: int)
signal died
signal dexterity_proc
signal stats_updated

var character_data: CharacterData

# ============================================
# BASE CORE STATS (before determination modifier)
# ============================================
var base_strength: int = 10
var base_dexterity: int = 10
var base_intelligence: int = 10
var base_wisdom: int = 10
var base_agility: int = 10
var determination: int = 10  # Determination doesn't modify itself

# ============================================
# RESOURCE STATS
# ============================================
var max_health: int = 10
var current_health: int = 10

var max_mana: int = 10
var current_mana: float = 10.0
var base_mana_regen: float = 1.0

# ============================================
# DERIVED STATS
# ============================================
var base_carry_capacity: int = 100
var current_carry_load: int = 0

var base_attack_speed_counter: int = 30
var current_attack_counter: int = 0

var base_draw_timer: float = 5.0
var hand_size: int = 6

## Mana regen fires every this many global tempo (default 5 = every tempo cycle)
var mana_regen_tempo_interval: float = 5.0
## Accumulator for tempo-based mana regen
var _tempo_until_mana_regen: float = 0.0

var current_armor: int = 0
var armor_decay_per_turn: int = 2

# ============================================
# BUFF TRACKING
# ============================================
var empowered_cards_remaining: int = 0
var empower_damage_bonus: int = 3
var empower_block_reduction: int = 3
var chance_boost: float = 0.0
var healing_boost_percent: float = 0.0  # Raged Circulation: +30% healing
var healing_boost_turns: int = 0
var inventory = null  # Inventory - untyped to avoid circular dependency

# ============================================
# EFFECTIVE STATS (with determination modifier)
# ============================================

var strength: int:
	get:
		return get_effective_stat(base_strength)

var dexterity: int:
	get:
		return get_effective_stat(base_dexterity)

var intelligence: int:
	get:
		return get_effective_stat(base_intelligence)

var wisdom: int:
	get:
		return get_effective_stat(base_wisdom)

var agility: int:
	get:
		return get_effective_stat(base_agility)

func get_effective_stat(base_value: int) -> int:
	var modifier = get_determination_modifier()
	return max(1, floori(base_value * modifier))

# ============================================
# INITIALIZATION
# ============================================

func initialize(data: CharacterData) -> void:
	character_data = data
	
	# Base stats (before determination)
	base_strength = data.strength
	base_dexterity = data.dexterity
	base_intelligence = data.intelligence
	base_wisdom = data.wisdom
	base_agility = data.agility
	determination = data.determination
	
	# Resources
	max_health = data.base_health
	current_health = data.base_health
	
	max_mana = data.base_mana
	current_mana = data.base_mana
	base_mana_regen = data.base_mana_regen
	base_draw_timer = data.base_draw_timer
	
	# Reset runtime values
	current_armor = 0
	current_carry_load = 0
	empowered_cards_remaining = 0
	chance_boost = 0.0
	_tempo_until_mana_regen = mana_regen_tempo_interval
	
	# Calculate derived stats
	recalculate_derived_stats()
	
	# Initialize attack counter
	current_attack_counter = get_attack_speed_threshold()
	
	# Emit initial values
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)
	armor_changed.emit(current_armor)
	
	_print_stats()

func recalculate_derived_stats() -> void:
	var base_hand = character_data.base_hand_size if character_data else 6
	hand_size = base_hand + get_wisdom_hand_bonus()
	stats_updated.emit()

func _print_stats() -> void:
	print("[STATS] === %s ===" % character_data.character_name)
	print("[STATS] Base Stats: STR:%d DEX:%d INT:%d WIS:%d AGI:%d DET:%d" % [
		base_strength, base_dexterity, base_intelligence, base_wisdom, base_agility, determination
	])
	print("[STATS] Effective (at %.0f%% HP): STR:%d DEX:%d INT:%d WIS:%d AGI:%d" % [
		get_health_percent() * 100, strength, dexterity, intelligence, wisdom, agility
	])
	print("[STATS] HP:%d Mana:%d" % [max_health, max_mana])
	print("[STATS] Carry Capacity: %d | Physical Dmg Bonus: +%d" % [
		get_carry_capacity(), get_strength_damage_bonus()
	])
	print("[STATS] Attack Speed Threshold: %d" % get_attack_speed_threshold())
	print("[STATS] Movement/Turn: %d | Hand Size: %d | Draw Timer: %.2f" % [
		get_movement_per_turn(), hand_size, get_effective_draw_timer()
	])

# ============================================
# DETERMINATION SYSTEM
# ============================================

func get_health_percent() -> float:
	if max_health <= 0:
		return 1.0
	return float(current_health) / float(max_health)

func get_determination_modifier() -> float:
	# Returns multiplier for stats based on health % and determination
	# At DET 10: no effect (1.0)
	# Below 10: penalties at low health
	# Above 10: bonuses at low health
	
	var health_pct = get_health_percent()
	var det_diff = determination - 10  # Positive = above 10, negative = below
	
	# Determine which threshold and effect percentage
	var effect_per_point = 0.0
	
	if health_pct <= 0.1:
		# 10% health or below: 10% per point
		effect_per_point = 0.10
	elif health_pct <= 0.4:
		# 40% health: 7% per point
		effect_per_point = 0.07
	elif health_pct <= 0.6:
		# 60% health: 5% per point
		effect_per_point = 0.05
	elif health_pct <= 0.8:
		# 80% health: 1% per point
		effect_per_point = 0.01
	else:
		# Above 80%: no effect
		return 1.0
	
	# Calculate total modifier
	var total_modifier = det_diff * effect_per_point
	
	# Return as multiplier (minimum 0.1 to prevent stats going to 0)
	return max(0.1, 1.0 + total_modifier)

func get_determination_description() -> String:
	var health_pct = get_health_percent()
	var modifier = get_determination_modifier()
	
	if modifier == 1.0:
		return "No effect (HP > 80%)"
	elif modifier > 1.0:
		return "+%.0f%% to stats" % ((modifier - 1.0) * 100)
	else:
		return "%.0f%% to stats" % ((modifier - 1.0) * 100)

# ============================================
# STRENGTH CALCULATIONS
# ============================================

func get_carry_capacity() -> int:
	# Uses effective strength (with determination)
	return base_carry_capacity + (strength * 10)

func get_free_carry_capacity() -> int:
	return get_carry_capacity() - current_carry_load

func get_strength_damage_bonus() -> int:
	# Uses effective strength
	return floori(strength / 2.0)

func set_carry_load(weight: int) -> void:
	current_carry_load = weight
	print("[STATS] Carry load: %d / %d" % [current_carry_load, get_carry_capacity()])

func is_overburdened() -> bool:
	return current_carry_load > get_carry_capacity()

# ============================================
# AGILITY CALCULATIONS
# ============================================

func get_movement_per_turn() -> int:
	# Every 5 AGI grants 1 movement per tempo
	# AGI 5 = 1 move, AGI 10 = 2 moves, etc.
	return max(1, floori(agility / 5.0))

# ============================================
# DEXTERITY / ATTACK SPEED
# ============================================

func get_attack_speed_threshold() -> int:
	# Uses effective dexterity
	var threshold = base_attack_speed_counter - dexterity
	
	# Carry capacity modifier
	var free_capacity = get_free_carry_capacity()
	var capacity_modifier = 30 - free_capacity
	threshold += capacity_modifier
	
	return max(5, threshold)

func register_attack() -> Dictionary:
	current_attack_counter -= 1
	
	print("[STATS] Attack counter: %d / %d" % [current_attack_counter, get_attack_speed_threshold()])
	
	if current_attack_counter <= 0:
		current_attack_counter = get_attack_speed_threshold()
		dexterity_proc.emit()
		print("[STATS] *** DEX PROC! *** Free attack + 2 mana discount!")
		return {
			"proc": true,
			"mana_discount": 2,
			"free_turn": true
		}
	
	return {
		"proc": false,
		"mana_discount": 0,
		"free_turn": false
	}

func get_attacks_until_proc() -> int:
	return current_attack_counter

# ============================================
# INTELLIGENCE CALCULATIONS
# ============================================

func get_intelligence_spell_bonus() -> int:
	# Every 2 point = +1 spell damage (flat, like strength)
	return floori(intelligence / 2.0)

func get_intelligence_mana_regen_bonus() -> float:
	# Every 5 points = +1 mana regen
	return floorf(intelligence / 5.0)

# ============================================
# WISDOM CALCULATIONS
# ============================================

func get_wisdom_hand_bonus() -> int:
	# Uses effective wisdom
	return floori(wisdom / 5.0)

func get_wisdom_draw_bonus() -> float:
	# Uses effective wisdom
	return wisdom * 0.25

func get_effective_draw_timer() -> float:
	var timer = base_draw_timer - get_wisdom_draw_bonus()
	return max(1.0, timer)

# ============================================
# COMBINED CALCULATIONS
# ============================================

func get_effective_mana_regen() -> float:
	return base_mana_regen + get_intelligence_mana_regen_bonus()

func get_effective_physical_damage(base_damage: int) -> int:
	var damage = base_damage + get_strength_damage_bonus()
	return max(1, damage)

func get_effective_spell_damage(base_damage: int) -> int:
	# INT: +1 damage per point (flat)
	return max(1, base_damage + get_intelligence_spell_bonus())

func get_effective_heal_amount(base_heal: int) -> int:
	# INT also boosts healing (flat)
	var amount = base_heal + get_intelligence_spell_bonus()
	if healing_boost_percent > 0.0:
		amount = floori(amount * (1.0 + healing_boost_percent))
	return amount

# ============================================
# TURN PROCESSING
# ============================================

## Called every global tempo advance. Handles mana regen on its own interval.
func process_tempo(amount: int) -> void:
	_tempo_until_mana_regen -= float(amount)
	if _tempo_until_mana_regen <= 0.0:
		_tempo_until_mana_regen += mana_regen_tempo_interval
		var mana_regen = get_effective_mana_regen()
		current_mana = min(current_mana + mana_regen, max_mana)
		mana_changed.emit(current_mana, max_mana)
		print("[STATS] Mana regen: +%.1f → %d/%d" % [mana_regen, int(current_mana), max_mana])

## Called once per tempo cycle (every 5 global tempo). Handles armor decay and misc upkeep.
func process_turn(debuff_mgr = null, buff_mgr = null) -> void:
	# Armor decay (check Fortify)
	if current_armor > 0:
		var should_decay = true
		if buff_mgr and buff_mgr.should_ignore_armor_decay():
			should_decay = false
			print("[STATS] Fortify prevents armor decay")

		if should_decay:
			var decay = armor_decay_per_turn
			if inventory and inventory.has_passive_effect("stalwart"):
				decay = max(0, decay - 1)
				print("[STATS] Stalwart reduces armor decay by 1")
			if debuff_mgr:
				decay = debuff_mgr.process_armor_decay(decay)
			current_armor = max(0, current_armor - decay)
			armor_changed.emit(current_armor)

	# Tick healing boost
	if healing_boost_turns > 0:
		healing_boost_turns -= 1
		if healing_boost_turns <= 0:
			healing_boost_percent = 0.0
			print("[STATS] Healing boost expired")

	recalculate_derived_stats()

# ============================================
# RESOURCE MANAGEMENT
# ============================================

func take_damage(amount: int, debuff_mgr = null, buff_mgr = null) -> void:
	var remaining = amount
	
	# Apply Vulnerable modifier from debuffs
	if debuff_mgr:
		remaining = debuff_mgr.modify_incoming_damage(remaining)
	
	# Apply Brace and Resilient from buffs
	if buff_mgr:
		remaining = buff_mgr.calculate_damage_reduction(remaining)
	
	# Armor absorption with Exposed modifier
	if current_armor > 0:
		var armor_effectiveness = 1.0
		if debuff_mgr:
			armor_effectiveness = debuff_mgr.get_armor_effectiveness()
		
		var effective_armor = floori(current_armor * armor_effectiveness)
		
		if effective_armor >= remaining:
			var armor_used = ceili(remaining / armor_effectiveness) if armor_effectiveness > 0 else remaining
			current_armor = max(0, current_armor - armor_used)
			remaining = 0
			print("[STATS] Armor absorbed damage. Armor: %d" % current_armor)
		else:
			remaining -= effective_armor
			current_armor = 0
			print("[STATS] Armor broke! %d damage passes through" % remaining)
		
		armor_changed.emit(current_armor)
	
	if remaining > 0:
		var old_pct = get_health_percent()
		current_health = max(0, current_health - remaining)
		health_changed.emit(current_health, max_health)
		
		if _crossed_threshold(old_pct, get_health_percent()):
			recalculate_derived_stats()
	
	if current_health <= 0:
		died.emit()
		
func _crossed_threshold(old_pct: float, new_pct: float) -> bool:
	var thresholds = [0.8, 0.6, 0.4, 0.1]
	for t in thresholds:
		if old_pct > t and new_pct <= t:
			return true
		if old_pct <= t and new_pct > t:
			return true
	return false

func heal(amount: int) -> void:
	var boosted_amount = get_effective_heal_amount(amount)
	var old_health_pct = get_health_percent()
	var old_health = current_health
	current_health += boosted_amount
	current_health = min(current_health, max_health)
	var actual_heal = current_health - old_health
	health_changed.emit(current_health, max_health)
	
	var new_health_pct = get_health_percent()
	print("[STATS] Healed %d (base %d)! Health: %d/%d" % [actual_heal, amount, current_health, max_health])
	
	# Check if we crossed a determination threshold (healing can restore stats)
	if _crossed_threshold(old_health_pct, new_health_pct):
		var mod = get_determination_modifier()
		print("[STATS] Determination threshold crossed! Modifier: %.0f%%" % (mod * 100))
		recalculate_derived_stats()
		stats_updated.emit()

	if actual_heal > 0 and inventory:
		inventory.on_healed()

func add_armor(amount: int) -> void:
	current_armor += amount
	armor_changed.emit(current_armor)
	print("[STATS] Gained %d armor! Armor: %d" % [amount, current_armor])
	if inventory:
		inventory.on_armor_gained(amount)

func add_armor_with_bolster(amount: int, buff_mgr = null) -> void:
	var total = amount
	if buff_mgr:
		total += buff_mgr.consume_bolster()
	current_armor += total
	armor_changed.emit(current_armor)
	print("[STATS] Gained %d armor (incl. bolster)! Armor: %d" % [total, current_armor])
	if inventory:
		inventory.on_armor_gained(total)

func spend_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, max_mana)
		return true
	return false

func has_mana(amount: int) -> bool:
	return current_mana >= amount

func gain_mana(amount: int) -> void:
	current_mana = min(current_mana + amount, max_mana)
	mana_changed.emit(current_mana, max_mana)
	print("[STATS] Gained %d mana! Mana: %d/%d" % [amount, int(current_mana), max_mana])

# ============================================
# EMPOWER SYSTEM
# ============================================

func apply_empower(card_count: int) -> void:
	empowered_cards_remaining = card_count
	print("[STATS] Empowered! Next %d cards buffed" % card_count)

func consume_empower() -> bool:
	if empowered_cards_remaining > 0:
		empowered_cards_remaining -= 1
		print("[STATS] Empower consumed. %d remaining" % empowered_cards_remaining)
		return true
	return false

func is_empowered() -> bool:
	return empowered_cards_remaining > 0

# ============================================
# EQUIPMENT SUPPORT
# ============================================

func equip_weapon(total_weight: int) -> void:
	set_carry_load(total_weight)
	print("[STATS] Attack speed threshold updated: %d" % get_attack_speed_threshold())

func add_base_stat(stat_name: String, amount: int) -> void:
	# Used by items to modify base stats
	match stat_name:
		"strength": base_strength += amount
		"dexterity": base_dexterity += amount
		"intelligence": base_intelligence += amount
		"wisdom": base_wisdom += amount
		"agility": base_agility += amount
		"determination": determination += amount
	recalculate_derived_stats()

# ============================================
# DEBUG / DISPLAY
# ============================================

func get_stats_summary() -> String:
	var free_moves = 1 + floori(agility / 5.0)
	return """STR: %d (base %d) → +%d carry, +%d phys dmg
DEX: %d (base %d) → proc in %d atks
INT: %d (base %d) → +%d spell dmg, +%.0f regen
WIS: %d (base %d) → +%d hand, -%.1f draw
AGI: %d (base %d) → %d free moves/tempo
DET: %d → %s""" % [
		strength, base_strength, strength * 10, get_strength_damage_bonus(),
		dexterity, base_dexterity, get_attacks_until_proc(),
		intelligence, base_intelligence, get_intelligence_spell_bonus(), get_intelligence_mana_regen_bonus(),
		wisdom, base_wisdom, get_wisdom_hand_bonus(), get_wisdom_draw_bonus(),
		agility, base_agility, free_moves,
		determination, get_determination_description()
	]
