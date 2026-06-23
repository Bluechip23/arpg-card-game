class_name PlayerStats
extends Node

## Manages player's runtime stats

signal health_changed(current: int, max_val: int)
signal mana_changed(current: float, max_val: int)
signal armor_changed(current: int)
signal armor_gained(amount: int)  # Emitted only when armor increases (any source) — drives the overhead armor icon
signal temp_health_changed(current: int)
signal died
signal dexterity_proc
signal stats_updated
signal xp_changed(current_xp: int, xp_to_next: int)
signal leveled_up(new_level: int)
signal damage_taken(amount: int)
signal health_damage_taken(amount: int)  # Emitted with the HP-only portion of damage (after armor absorbs)
signal mana_gained(amount: int, is_regen: bool)  # Emitted when mana is gained (for Energy Barrier tracking)
signal maintained_cards_broken  # Emitted when mana hits 0, all maintained cards should be discarded
signal gold_changed(amount: int)
signal healed(amount: int)
signal shepherds_mark_triggered  # Whispers of the Flock: mark prevented lethal damage

var character_data: CharacterData

# Friendship link: when set, this character shares heals with and splits incoming
# damage 50/50 with the partner. Amounts are passed pre-modifier so each side
# applies its own amplification/penalty. _friendship_echo guards against echo
# loops while the linked call is in flight.
var friendship_partner: PlayerStats = null
var friendship_partner_debuff = null
var friendship_partner_buff = null
var _friendship_echo: bool = false

# Skill-tree passives needing runtime state:
# Blood Libation (Jeremy): Sanguine stacks add +1/heal; at 5 the next heal doubles,
# stacks clear, and Jeremy takes 10 non-lethal.
var sanguine_stacks: int = 0
# Solemn Independence: set true by the cycle trigger while 3+ enemies are within 2
# tiles — grants combat bonuses but blocks ally healing.
var solemn_active: bool = false

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
var maintained_mana: int = 0  # Mana reserved by maintained Power cards

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
var armor_decay_per_cycle: int = 2

var current_temp_health: int = 0
var temp_health_tempo_remaining: int = 0

# ============================================
# BUFF TRACKING
# ============================================
var empowered_cards_remaining: int = 0
var empower_damage_bonus: int = 3
var empower_block_reduction: int = 3
var chance_boost: float = 0.0
var healing_boost_percent: float = 0.0  # Raged Circulation: +30% healing
var healing_boost_tempo: int = 0
var ranged_damage_bonus: int = 0  # Flat bonus to all ranged attacks (from quivers, etc.)
var healing_bonus: int = 0  # Flat bonus to all healing effects (from belts, etc.)

# Enchantment bonuses (applied while enchantment cards are in hand)
var enchantment_damage_bonus: int = 0  # Flat bonus to all damage from enchantments
var enchantment_block_bonus: int = 0  # Flat bonus to all block from enchantments
var enchantment_mana_regen_bonus: float = 0.0  # Bonus mana regen from enchantments
var enchantment_movement_bonus: int = 0  # Bonus free moves from enchantments
var inventory = null  # Inventory - untyped to avoid circular dependency

# ============================================
# SPHERE GRID BONUSES (tracked separately from equipment)
# ============================================
var sphere_grid_passives: Array[Dictionary] = []  # Active passives from sphere grid
# Each entry: { "node_id": int, "trigger": String, "effect": String, "value": int/float, "chance": float }
# Triggers: "on_kill", "on_card_play", "on_move", "on_cycle", "on_attack", "on_dodge",
#           "on_heal", "on_block", "on_crit", "on_spell_cast", "on_discard", "on_draw",
#           "on_tempo_cycle"
var sphere_bonus_strength: int = 0
var sphere_bonus_dexterity: int = 0
var sphere_bonus_intelligence: int = 0
var sphere_bonus_wisdom: int = 0
var sphere_bonus_agility: int = 0
var sphere_bonus_determination: int = 0
var sphere_bonus_health: int = 0
var sphere_bonus_mana: int = 0

# Base combat stats
var base_crit_chance: int = 5         # Base 5% crit chance for all characters

# Combat bonuses from sphere grid (neutral bonuses)
var sphere_bonus_block: int = 0       # Extra block from block cards
var sphere_bonus_thorns: int = 0      # Damage dealt to attackers when hit
var sphere_bonus_damage: int = 0      # Flat bonus to all attacks
var sphere_bonus_heal_power: int = 0  # Extra HP from heal cards
var sphere_bonus_crit: float = 0.0    # Extra crit chance (percentage points)
var sphere_bonus_armor: int = 0       # Starting armor each combat
var sphere_bonus_regen: int = 0       # Health regenerated per tempo cycle
var sphere_bonus_armor_per_cycle: int = 0  # Armor gained per tempo cycle
var sphere_bonus_life_steal: float = 0.0   # Percentage of damage healed (e.g. 2.0 = 2%)
var sphere_bonus_resistance: float = 0.0   # Flat damage reduction percentage (e.g. 3.0 = 3%)
var sphere_bonus_range: int = 0       # Bonus range for ranged attacks

# ============================================
# SKILL TREE PASSIVES (from archetype choices)
# ============================================
var skill_tree_passives: Array[String] = []  # Active passive IDs from skill tree choices

# Stateful tracking for skill tree passives
var st_crit_counter: int = 0          # Eye Scrape: tracks crits toward every-3rd invisibility
var st_from_hip_card: Card = null     # From the Hip: the card currently discounted
var st_from_hip_original_cost: int = 0  # From the Hip: original mana cost to restore
var st_enemy_first_strikes: Dictionary = {}  # Surprise Opener: tracks which enemies have been struck

# Brad passive tracking
var st_defense_cards_played: int = 0  # The Way of the Plate: counts defense cards for every-other discount
var st_corrupted_strength_active: bool = false  # Corrupted Strength: true when 3+ enemies within 2 tiles
var st_corrupted_strength_no_ally_heal: bool = false  # Corrupted Strength: blocks ally healing while active
var st_consecutive_defense: int = 0   # Pristine Armor: counts consecutive defense cards for 3-in-a-row bonus
var st_itt_charges: int = 2            # In the Trenches: shared charge pool (2 max)
var st_itt_last_used_tempo: int = -100 # In the Trenches: global tempo when charges were last exhausted

# Stephen passive tracking
var st_consecutive_attacks: int = 0   # Skilled Momentum: tracks consecutive attack cards played
var st_scouted_target_id: int = -1    # Scouted: instance_id of the enemy being tracked
var st_scouted_hits: int = 0          # Scouted: consecutive hits on the same enemy
var st_scouted_bonus_active: bool = false  # Scouted: +6 range and auto-crit ready
var st_exposed_blind_spot_crit: int = 0  # Exposed Blind Spot: bonus crit % for next attack
var st_lethal_resource_attacking: bool = false  # Lethal Resourcefulness: guard against recursion

# Cory passive tracking
var st_mana_gain_counter: int = 0     # Energy Barrier: counts non-regen mana gains toward every-3rd
var st_expel_triggered: bool = false   # Expel Negativity: tracks if already triggered this threshold cross
var st_cards_this_cycle: Array[String] = []  # Self Reliance: card types played this tempo cycle
var st_self_reliance_discount: bool = false   # Self Reliance: next card costs -1m
var st_budding_types: Array[String] = []     # Budding: card types played (no back-to-back)
var st_budding_last_type: String = ""         # Budding: last card type to prevent back-to-back
var st_serial_killer_enemies: Dictionary = {} # Serial Killer: enemies already triggered (enemy_id -> true)
var st_regrowth_cooldown: int = 0     # Regrowth: remaining cooldown tempo
var st_stimulant_cooldown: int = 0    # Stimulant: remaining cooldown tempo

# Jeremy passive tracking
var st_arcane_overflow_discount: bool = false  # Arcane Overflow: next spell costs -1 tempo
var st_mana_spent_window: Array = []  # Mana Surge: [{amount, tempo}] entries within 5 tempo window
var st_whispers_cooldown: int = 0     # Whispers of the Flock: remaining cooldown tempo
var st_whispers_active: bool = false  # Whispers of the Flock: mark currently active
var st_whispers_tempo: int = 0        # Whispers of the Flock: remaining mark duration
var st_haunted_rebuke_cooldown: int = 0  # Haunted Rebuke: remaining cooldown tempo
var st_kinetic_armor_tempo: int = 0   # Kinetic Armor: tempo since armor was last at 0
var st_kinetic_armor_triggered: bool = false  # Kinetic Armor: already triggered this armor retention
var st_i_heal_you_tempo: int = 0      # I Heal You: tempo counter for ally healing aura
var st_seance_specters: Array = []    # Seance: active specters [{node, hp, tempo_remaining, position}]

func has_skill_tree_passive(passive_id: String) -> bool:
	return passive_id in skill_tree_passives

func add_skill_tree_passive(passive_id: String) -> void:
	if passive_id not in skill_tree_passives:
		skill_tree_passives.append(passive_id)
		print("[STATS] Skill tree passive added: %s" % passive_id)

# ============================================
# EXPERIENCE / LEVEL
# ============================================
var current_level: int = 1
var current_xp: int = 0
var total_xp: int = 0  # Lifetime XP earned

# ============================================
# GOLD
# ============================================
var gold: int = 0

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
	current_temp_health = 0
	temp_health_tempo_remaining = 0
	current_carry_load = 0
	empowered_cards_remaining = 0
	chance_boost = 0.0
	maintained_mana = 0
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

## Capture all persistent progression state into a dictionary for world transitions.
## This preserves everything that accumulates during gameplay and must survive scene changes.
func save_progression() -> Dictionary:
	return {
		# Level / XP
		"current_level": current_level,
		"current_xp": current_xp,
		"total_xp": total_xp,
		"gold": gold,
		# Base stats (may have been boosted by sphere grid / skill tree)
		"base_strength": base_strength,
		"base_dexterity": base_dexterity,
		"base_intelligence": base_intelligence,
		"base_wisdom": base_wisdom,
		"base_agility": base_agility,
		"determination": determination,
		# Resource caps (sphere grid can raise these)
		"max_health": max_health,
		"current_health": current_health,
		"max_mana": max_mana,
		"current_mana": current_mana,
		"current_armor": current_armor,
		"base_mana_regen": base_mana_regen,
		"base_draw_timer": base_draw_timer,
		# Sphere grid bonuses
		"sphere_grid_passives": sphere_grid_passives.duplicate(true),
		"sphere_bonus_strength": sphere_bonus_strength,
		"sphere_bonus_dexterity": sphere_bonus_dexterity,
		"sphere_bonus_intelligence": sphere_bonus_intelligence,
		"sphere_bonus_wisdom": sphere_bonus_wisdom,
		"sphere_bonus_agility": sphere_bonus_agility,
		"sphere_bonus_health": sphere_bonus_health,
		"sphere_bonus_mana": sphere_bonus_mana,
		"sphere_bonus_block": sphere_bonus_block,
		"sphere_bonus_thorns": sphere_bonus_thorns,
		"sphere_bonus_damage": sphere_bonus_damage,
		"sphere_bonus_heal_power": sphere_bonus_heal_power,
		"sphere_bonus_crit": sphere_bonus_crit,
		"sphere_bonus_armor": sphere_bonus_armor,
		# Skill tree passives
		"skill_tree_passives": skill_tree_passives.duplicate(),
	}

## Restore persistent progression state from a dictionary after scene transition.
func restore_progression(data: Dictionary) -> void:
	if data.is_empty():
		return
	# Level / XP
	current_level = data.get("current_level", current_level)
	current_xp = data.get("current_xp", current_xp)
	total_xp = data.get("total_xp", total_xp)
	gold = data.get("gold", gold)
	# Base stats
	base_strength = data.get("base_strength", base_strength)
	base_dexterity = data.get("base_dexterity", base_dexterity)
	base_intelligence = data.get("base_intelligence", base_intelligence)
	base_wisdom = data.get("base_wisdom", base_wisdom)
	base_agility = data.get("base_agility", base_agility)
	determination = data.get("determination", determination)
	# Resources (preserve current HP/mana — no free heal on world transition)
	max_health = data.get("max_health", max_health)
	current_health = data.get("current_health", max_health)
	max_mana = data.get("max_mana", max_mana)
	current_mana = data.get("current_mana", max_mana)
	current_armor = data.get("current_armor", 0)
	base_mana_regen = data.get("base_mana_regen", base_mana_regen)
	base_draw_timer = data.get("base_draw_timer", base_draw_timer)
	# Sphere grid bonuses
	sphere_grid_passives = data.get("sphere_grid_passives", sphere_grid_passives)
	sphere_bonus_strength = data.get("sphere_bonus_strength", sphere_bonus_strength)
	sphere_bonus_dexterity = data.get("sphere_bonus_dexterity", sphere_bonus_dexterity)
	sphere_bonus_intelligence = data.get("sphere_bonus_intelligence", sphere_bonus_intelligence)
	sphere_bonus_wisdom = data.get("sphere_bonus_wisdom", sphere_bonus_wisdom)
	sphere_bonus_agility = data.get("sphere_bonus_agility", sphere_bonus_agility)
	sphere_bonus_health = data.get("sphere_bonus_health", sphere_bonus_health)
	sphere_bonus_mana = data.get("sphere_bonus_mana", sphere_bonus_mana)
	sphere_bonus_block = data.get("sphere_bonus_block", sphere_bonus_block)
	sphere_bonus_thorns = data.get("sphere_bonus_thorns", sphere_bonus_thorns)
	sphere_bonus_damage = data.get("sphere_bonus_damage", sphere_bonus_damage)
	sphere_bonus_heal_power = data.get("sphere_bonus_heal_power", sphere_bonus_heal_power)
	sphere_bonus_crit = data.get("sphere_bonus_crit", sphere_bonus_crit)
	sphere_bonus_armor = data.get("sphere_bonus_armor", sphere_bonus_armor)
	# Skill tree passives
	skill_tree_passives = data.get("skill_tree_passives", skill_tree_passives)
	# Recalculate derived stats with restored values
	recalculate_derived_stats()
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)
	armor_changed.emit(current_armor)
	print("[STATS] Progression restored: Level %d, XP %d, %d passives" % [current_level, current_xp, skill_tree_passives.size()])

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
	print("[STATS] Movement/Cycle: %d | Hand Size: %d | Draw Timer: %.2f" % [
		get_movement_per_cycle(), hand_size, get_effective_draw_timer()
	])

# ============================================
# DETERMINATION SYSTEM
# ============================================

func get_health_percent() -> float:
	if max_health <= 0:
		return 1.0
	return float(current_health + current_temp_health) / float(max_health)

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

func get_movement_per_cycle() -> int:
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
		print("[STATS] *** DEX PROC! *** Half tempo + 2 mana discount!")
		return {
			"proc": true,
			"mana_discount": 2,
			"half_tempo": true
		}
	
	return {
		"proc": false,
		"mana_discount": 0,
		"half_tempo": false
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
	return base_mana_regen + get_intelligence_mana_regen_bonus() + enchantment_mana_regen_bonus

func get_effective_physical_damage(base_damage: int) -> int:
	var damage = base_damage + get_strength_damage_bonus() + enchantment_damage_bonus + sphere_bonus_damage
	return max(1, damage)

func get_effective_ranged_damage(base_damage: int) -> int:
	var damage = base_damage + get_strength_damage_bonus() + ranged_damage_bonus + enchantment_damage_bonus + sphere_bonus_damage
	return max(1, damage)

func get_effective_spell_damage(base_damage: int) -> int:
	# INT: +1 damage per point (flat)
	return max(1, base_damage + get_intelligence_spell_bonus() + enchantment_damage_bonus + sphere_bonus_damage)

func get_effective_heal_amount(base_heal: int) -> int:
	# INT also boosts healing (flat) + flat healing_bonus from equipment + sphere grid heal bonus
	var amount = base_heal + get_intelligence_spell_bonus() + healing_bonus + sphere_bonus_heal_power
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
		current_mana = min(current_mana + mana_regen, get_available_max_mana())
		mana_changed.emit(current_mana, max_mana)
		mana_gained.emit(int(mana_regen), true)
		print("[STATS] Mana regen: +%.1f → %d/%d (reserved: %d)" % [mana_regen, int(current_mana), max_mana, maintained_mana])

## Called once per tempo cycle (every 5 global tempo). Handles armor decay and misc upkeep.
func process_turn(debuff_mgr = null, buff_mgr = null) -> void:
	# Armor decay (check Fortify)
	if current_armor > 0:
		var should_decay = true
		if buff_mgr and buff_mgr.should_ignore_armor_decay():
			should_decay = false
			print("[STATS] Fortify prevents armor decay")

		if should_decay:
			var decay = armor_decay_per_cycle
			if inventory and inventory.has_passive_effect("stalwart"):
				decay = max(0, decay - 1)
				print("[STATS] Stalwart reduces armor decay by 1")
			if debuff_mgr:
				decay = debuff_mgr.process_armor_decay(decay)
			current_armor = max(0, current_armor - decay)
			armor_changed.emit(current_armor)

	# Temp health expiry
	if current_temp_health > 0 and temp_health_tempo_remaining > 0:
		temp_health_tempo_remaining -= 5
		if temp_health_tempo_remaining <= 0:
			var old_pct = get_health_percent()
			current_temp_health = 0
			temp_health_tempo_remaining = 0
			temp_health_changed.emit(current_temp_health)
			print("[STATS] Temp HP expired")
			if _crossed_threshold(old_pct, get_health_percent()):
				recalculate_derived_stats()

	# Tick healing boost
	if healing_boost_tempo > 0:
		healing_boost_tempo -= 5
		if healing_boost_tempo <= 0:
			healing_boost_percent = 0.0
			print("[STATS] Healing boost expired")

	recalculate_derived_stats()

# ============================================
# RESOURCE MANAGEMENT
# ============================================

func take_damage(amount: int, debuff_mgr = null, buff_mgr = null) -> void:
	# Friendship: split incoming damage 50/50 (pre-modifier). The partner takes
	# its half through its own debuff/buff managers; we keep the remainder.
	if friendship_partner and not _friendship_echo and amount > 1:
		_friendship_echo = true
		friendship_partner._friendship_echo = true
		var partner_half = amount / 2
		amount = amount - partner_half
		friendship_partner.take_damage(partner_half, friendship_partner_debuff, friendship_partner_buff)
		_friendship_echo = false
		friendship_partner._friendship_echo = false

	var remaining = amount

	# Stone Skin: 10% damage resistance (Fire, Physical, Lightning)
	if has_skill_tree_passive("stone_skin"):
		remaining = floori(remaining * 0.9)

	# Apply Vulnerable modifier from debuffs
	if debuff_mgr:
		remaining = debuff_mgr.modify_incoming_damage(remaining)
	
	# Apply Brace and Resilient from buffs
	if buff_mgr:
		remaining = buff_mgr.calculate_damage_reduction(remaining)
	
	# Temp health absorbs damage first
	if current_temp_health > 0 and remaining > 0:
		if current_temp_health >= remaining:
			current_temp_health -= remaining
			remaining = 0
			print("[STATS] Temp HP absorbed damage. Temp HP: %d" % current_temp_health)
		else:
			remaining -= current_temp_health
			current_temp_health = 0
			print("[STATS] Temp HP broke! %d damage passes through" % remaining)
		temp_health_changed.emit(current_temp_health)

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
		health_damage_taken.emit(remaining)

		if _crossed_threshold(old_pct, get_health_percent()):
			recalculate_derived_stats()

	# Emit damage_taken for reaction card triggers
	damage_taken.emit(amount)

	# Whispers of the Flock: Shepherd's Mark prevents lethal damage
	# When triggered, the marked target survives but Jeremy takes 8 damage
	if current_health <= 0 and st_whispers_active:
		current_health = 1
		add_armor(10)
		st_whispers_active = false
		st_whispers_tempo = 0
		st_whispers_cooldown = 20
		health_changed.emit(current_health, max_health)
		shepherds_mark_triggered.emit()
		print("[STATS] Shepherd's Mark triggered! Survived at 1 HP + 10 armor. Jeremy takes 8 damage.")

	if current_health <= 0:
		died.emit()

	# Blood Libation: gain a Sanguine stack whenever Jeremy takes damage.
	if has_skill_tree_passive("blood_libation"):
		sanguine_stacks = min(5, sanguine_stacks + 1)

func take_direct_damage(amount: int) -> void:
	## Deal damage directly to HP, bypassing armor entirely.
	if amount <= 0:
		return
	var old_pct = get_health_percent()
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	health_damage_taken.emit(amount)
	if _crossed_threshold(old_pct, get_health_percent()):
		recalculate_derived_stats()
	damage_taken.emit(amount)

	# Whispers of the Flock: Shepherd's Mark prevents lethal damage (direct damage too)
	# When triggered, the marked target survives but Jeremy takes 8 damage
	if current_health <= 0 and st_whispers_active:
		current_health = 1
		add_armor(10)
		st_whispers_active = false
		st_whispers_tempo = 0
		st_whispers_cooldown = 20
		health_changed.emit(current_health, max_health)
		shepherds_mark_triggered.emit()
		print("[STATS] Shepherd's Mark triggered! Survived at 1 HP + 10 armor. Jeremy takes 8 damage.")

	if current_health <= 0:
		died.emit()

	# Blood Libation: gain a Sanguine stack whenever Jeremy takes damage (its own
	# 10-HP burst is applied directly in heal(), so it never reaches here).
	if has_skill_tree_passive("blood_libation"):
		sanguine_stacks = min(5, sanguine_stacks + 1)

func _crossed_threshold(old_pct: float, new_pct: float) -> bool:
	var thresholds = [0.8, 0.6, 0.4, 0.1]
	for t in thresholds:
		if old_pct > t and new_pct <= t:
			return true
		if old_pct <= t and new_pct > t:
			return true
	return false

func heal(amount: int, from_ally: bool = false) -> void:
	# Corrupted Strength / Solemn Independence: block ally healing while active
	if from_ally and (st_corrupted_strength_no_ally_heal or solemn_active):
		return
	# Friendship: the partner receives the same base heal (their modifiers apply).
	if friendship_partner and not _friendship_echo and amount > 0:
		_friendship_echo = true
		friendship_partner._friendship_echo = true
		friendship_partner.heal(amount, from_ally)
		_friendship_echo = false
		friendship_partner._friendship_echo = false
	# Blood Libation: Sanguine stacks add +1 healing each; at 5 the heal doubles,
	# the stacks are consumed, and Jeremy takes 10 non-lethal afterward.
	var bl_consume := false
	if sanguine_stacks > 0 and has_skill_tree_passive("blood_libation"):
		amount += sanguine_stacks
		if sanguine_stacks >= 5:
			amount *= 2
			bl_consume = true
			sanguine_stacks = 0
	var boosted_amount = get_effective_heal_amount(amount)
	var old_health_pct = get_health_percent()
	var old_health = current_health
	current_health += boosted_amount
	current_health = min(current_health, max_health)
	var actual_heal = current_health - old_health
	health_changed.emit(current_health, max_health)
	if actual_heal > 0:
		healed.emit(actual_heal)

	# Blood Libation: the 5-stack burst costs 10 non-lethal HP after the heal.
	if bl_consume:
		current_health = max(1, current_health - 10)
		health_changed.emit(current_health, max_health)
		print("[STATS] Blood Libation burst! Heal doubled, took 10 non-lethal.")

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
	var total = amount + enchantment_block_bonus + sphere_bonus_block
	# Sword Specialist: +25% block when only wielding swords
	if has_skill_tree_passive("sword_specialist") and inventory and inventory.has_only_swords_equipped():
		total = floori(total * 1.25)
	current_armor += total
	armor_changed.emit(current_armor)
	if total > 0:
		armor_gained.emit(total)
	var bonus = enchantment_block_bonus + sphere_bonus_block
	if bonus > 0:
		print("[STATS] Gained %d armor (+%d bonus)! Armor: %d" % [amount, bonus, current_armor])
	else:
		print("[STATS] Gained %d armor! Armor: %d" % [total, current_armor])
	if inventory:
		inventory.on_armor_gained(total)

func add_armor_with_bolster(amount: int, buff_mgr = null) -> void:
	var total = amount + enchantment_block_bonus + sphere_bonus_block
	if buff_mgr:
		total += buff_mgr.consume_bolster()
	# Sword Specialist: +25% block when only wielding swords
	if has_skill_tree_passive("sword_specialist") and inventory and inventory.has_only_swords_equipped():
		total = floori(total * 1.25)
	current_armor += total
	armor_changed.emit(current_armor)
	if total > 0:
		armor_gained.emit(total)
	print("[STATS] Gained %d armor (incl. bolster/enchantment)! Armor: %d" % [total, current_armor])
	if inventory:
		inventory.on_armor_gained(total)

func add_temp_health(amount: int, duration_tempo: int) -> void:
	var old_pct = get_health_percent()
	current_temp_health += amount
	temp_health_tempo_remaining = max(temp_health_tempo_remaining, duration_tempo)
	temp_health_changed.emit(current_temp_health)
	print("[STATS] Gained %d temp HP (duration: %d tempo)! Temp HP: %d" % [amount, duration_tempo, current_temp_health])
	if _crossed_threshold(old_pct, get_health_percent()):
		recalculate_derived_stats()

func spend_mana(amount: int) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		mana_changed.emit(current_mana, max_mana)
		if current_mana <= 0 and maintained_mana > 0:
			_break_maintained_cards()
		return true
	return false

func has_mana(amount: int) -> bool:
	return current_mana >= amount

func gain_mana(amount: int) -> void:
	current_mana = min(current_mana + amount, get_available_max_mana())
	mana_changed.emit(current_mana, max_mana)
	mana_gained.emit(amount, false)
	print("[STATS] Gained %d mana! Mana: %d/%d (reserved: %d)" % [amount, int(current_mana), max_mana, maintained_mana])

# ============================================
# MAINTAIN SYSTEM (Power Cards)
# ============================================

func get_available_max_mana() -> int:
	## Max mana minus mana reserved by maintained cards
	return max(0, max_mana - maintained_mana)

func reserve_mana(amount: int) -> void:
	## Reserve mana for a maintained Power card
	maintained_mana += amount
	# Cap current mana to new available max
	current_mana = min(current_mana, get_available_max_mana())
	mana_changed.emit(current_mana, max_mana)
	print("[STATS] Reserved %d mana for maintain. Available max: %d/%d" % [amount, get_available_max_mana(), max_mana])

func release_mana(amount: int) -> void:
	## Release reserved mana when a maintained card is discarded
	maintained_mana = max(0, maintained_mana - amount)
	mana_changed.emit(current_mana, max_mana)
	print("[STATS] Released %d maintained mana. Available max: %d/%d" % [amount, get_available_max_mana(), max_mana])

func _break_maintained_cards() -> void:
	## Called when current mana hits 0 - all maintained cards lose their effect
	print("[STATS] Mana hit 0! All maintained cards are broken!")
	maintained_mana = 0
	maintained_cards_broken.emit()

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

func apply_sphere_grid_stat(stat_name: String, amount: int) -> void:
	## Applies a stat bonus from an unlocked sphere grid node.
	match stat_name:
		"strength":
			sphere_bonus_strength += amount
			base_strength += amount
		"dexterity":
			sphere_bonus_dexterity += amount
			base_dexterity += amount
		"intelligence":
			sphere_bonus_intelligence += amount
			base_intelligence += amount
		"wisdom":
			sphere_bonus_wisdom += amount
			base_wisdom += amount
		"agility":
			sphere_bonus_agility += amount
			base_agility += amount
		"determination":
			sphere_bonus_determination += amount
			determination += amount
	recalculate_derived_stats()
	stats_updated.emit()
	print("[STATS] Sphere grid bonus: %s +%d" % [stat_name, amount])

func apply_sphere_grid_health(amount: int) -> void:
	## Increases max health from a sphere grid node.
	sphere_bonus_health += amount
	max_health += amount
	current_health += amount  # Also heal the gained amount
	health_changed.emit(current_health, max_health)
	print("[STATS] Sphere grid: Max HP +%d (now %d)" % [amount, max_health])

func apply_sphere_grid_mana(amount: int) -> void:
	## Increases max mana from a sphere grid node.
	sphere_bonus_mana += amount
	max_mana += amount
	current_mana = min(current_mana + amount, get_available_max_mana())
	mana_changed.emit(current_mana, max_mana)
	print("[STATS] Sphere grid: Max Mana +%d (now %d)" % [amount, max_mana])

func apply_sphere_grid_combat_bonus(label: String, _description: String) -> void:
	## Applies a neutral combat bonus from a sphere grid node.
	## Parses labels like "Block +2", "Thorns +1", "Damage +3", "Heal +2", "Crit +5%", "Armor +3",
	## "Regen +1", "Arm/Cyc +1", "Life Steal +3%", "Resist +3%", "Range +1"
	var regex = RegEx.new()
	regex.compile("(.+?)\\s*\\+(\\d+)")
	var result = regex.search(label)
	if not result:
		return
	var bonus_type = result.get_string(1).strip_edges().to_lower()
	var value = int(result.get_string(2))
	match bonus_type:
		"block":
			sphere_bonus_block += value
		"thorns":
			sphere_bonus_thorns += value
		"damage":
			sphere_bonus_damage += value
		"heal":
			sphere_bonus_heal_power += value
		"crit":
			sphere_bonus_crit += float(value)
		"armor":
			sphere_bonus_armor += value
			# Immediately grant the armor
			current_armor += value
			armor_changed.emit(current_armor)
			if value > 0:
				armor_gained.emit(value)
		"regen":
			sphere_bonus_regen += value
		"arm/cyc":
			sphere_bonus_armor_per_cycle += value
		"life steal":
			sphere_bonus_life_steal += float(value)
		"resist":
			sphere_bonus_resistance += float(value)
		"range":
			sphere_bonus_range += value
	stats_updated.emit()
	print("[STATS] Sphere grid combat bonus: %s" % label)

func add_sphere_grid_passive(passive_data: Dictionary) -> void:
	## Registers a passive from an unlocked sphere grid node.
	sphere_grid_passives.append(passive_data)
	print("[STATS] Sphere grid passive added: %s → %s" % [passive_data.get("trigger", "?"), passive_data.get("effect", "?")])

func get_sphere_grid_passives_for_trigger(trigger: String) -> Array[Dictionary]:
	## Returns all sphere grid passives that match a given trigger.
	var result: Array[Dictionary] = []
	for passive in sphere_grid_passives:
		if passive.get("trigger", "") == trigger:
			result.append(passive)
	return result

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
DET: %d → %s
Level: %d | XP: %d / %d""" % [
		strength, base_strength, strength * 10, get_strength_damage_bonus(),
		dexterity, base_dexterity, get_attacks_until_proc(),
		intelligence, base_intelligence, get_intelligence_spell_bonus(), get_intelligence_mana_regen_bonus(),
		wisdom, base_wisdom, get_wisdom_hand_bonus(), get_wisdom_draw_bonus(),
		agility, base_agility, free_moves,
		determination, get_determination_description(),
		current_level, current_xp, get_xp_to_next_level()
	]

# ============================================
# EXPERIENCE / LEVELING
# ============================================

func get_xp_to_next_level() -> int:
	## XP needed for the NEXT level: 10 for level 1→2, 20 for 2→3, 30 for 3→4, etc.
	return current_level * 10

func gain_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	print("[STATS] Gained %d gold! (Total: %d)" % [amount, gold])

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	print("[STATS] Spent %d gold! (Total: %d)" % [amount, gold])
	return true

func gain_xp(amount: int) -> void:
	current_xp += amount
	total_xp += amount
	print("[STATS] Gained %d XP! (%d / %d to level %d)" % [amount, current_xp, get_xp_to_next_level(), current_level + 1])
	xp_changed.emit(current_xp, get_xp_to_next_level())

	# Check for level up (can level multiple times from one XP gain)
	while current_xp >= get_xp_to_next_level():
		_level_up()

func _level_up() -> void:
	current_xp -= get_xp_to_next_level()
	current_level += 1

	# Full health and mana on level up
	current_health = max_health
	current_mana = max_mana
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)

	print("[STATS] *** LEVEL UP! *** Now level %d! HP and Mana fully restored." % current_level)
	leveled_up.emit(current_level)
	xp_changed.emit(current_xp, get_xp_to_next_level())
