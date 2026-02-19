class_name Card
extends Resource

## Card resource that holds card data

enum CardType { ATTACK, DEFENSE, UTILITY }

@export var card_id: String = "slash"
@export var card_name: String = "Slash"
@export var description: String = "10 damage"
@export var card_type: CardType = CardType.ATTACK
@export var card_type_name: String = "Attack"
@export var mana_cost: int = 1
@export var damage: int = 10
@export var block: int = 0
@export var heal_amount: int = 0
@export var tempo_cost: int = 4
var is_enhanced: bool = false  
var base_damage: int = 10
var base_block: int = 0
var bonus_damage: int = 0
var jail_time_remaining: int = 0
var is_aoe: bool = false
var aoe_shape: String = ""  # "cone", "circle", "line"
var aoe_range: float = 100.0
var chance_effect_percent: float = 0.0  # For AOE per-enemy rolls
var rng_outcomes: Dictionary = {}  # enemy_id -> bool (for AOE per-enemy indicators)
var rng_roll_turn: int = 0  # Turn when RNG was last rolled
var turns_in_hand: int = 0  # How long card has been in hand

# RNG outcome system - percentages that appear in the card description
# Each entry: {percent: float} matching a "XX%" in the description
# Binary (1 entry): rolls success/fail for that single percentage
# Multi (2+ entries): weighted random picks which outcome triggers
var rng_outcomes_data: Array = []
var rng_selected_index: int = -1  # -1=not rolled, >=0=which outcome won, -2=binary fail
var sticky: int = 0  # Turns card stays in hand before auto-discarding (0 = normal)
var duration: int = 0  # Effect duration in turns
var is_ranged: bool = false  # If true, card is ranged (base range 5). If false, melee.
var range_modifier: int = 0  # Modifies base range: +2 = 7 range, -2 = 3 range
var card_range: float = 0.0  # Legacy range for specific overrides
var target_types: Array = ["enemy"]  # "enemy", "ally", "self", "point", "all_nearby"
var consecutive_uses: int = 0  # Track how many times card played in sequence
var requires_high_ground: bool = false  # Needs elevated position
var last_damage_dealt: int = 0  # Used by cards that need main.gd to apply damage (charge, leap)
func roll_rng(enemies: Array = [], chance_boost: float = 0.0) -> void:
	rng_outcomes.clear()

	if rng_outcomes_data.size() == 1:
		# Binary: single percentage, success or fail
		var roll = randf() * 100.0
		if roll < rng_outcomes_data[0].percent:
			rng_selected_index = 0  # Success
		else:
			rng_selected_index = -2  # Fail
		print("[CARD] %s RNG: %.0f%% → %s" % [card_name, rng_outcomes_data[0].percent, "SUCCESS" if rng_selected_index == 0 else "FAIL"])
	elif rng_outcomes_data.size() > 1:
		# Multi-outcome: weighted random selection
		var roll = randf() * 100.0
		var cumulative = 0.0
		rng_selected_index = rng_outcomes_data.size() - 1
		for i in range(rng_outcomes_data.size()):
			cumulative += rng_outcomes_data[i].percent
			if roll < cumulative:
				rng_selected_index = i
				break
		print("[CARD] %s RNG: rolled outcome %d (%.0f%%)" % [card_name, rng_selected_index, rng_outcomes_data[rng_selected_index].percent])

	# AOE per-enemy rolls
	if chance_effect_percent > 0.0:
		var effective_chance = chance_effect_percent + chance_boost
		for enemy in enemies:
			if is_instance_valid(enemy):
				var enemy_roll = randf() * 100.0
				rng_outcomes[enemy.get_instance_id()] = enemy_roll < effective_chance

func get_rng_outcome(enemy) -> bool:
	if not enemy:
		return false
	var id = enemy.get_instance_id()
	return rng_outcomes.get(id, false)

func has_chance_effect() -> bool:
	return rng_outcomes_data.size() > 0

func has_been_rolled() -> bool:
	return rng_selected_index != -1

func should_reroll_rng(current_turn: int) -> bool:
	return current_turn - rng_roll_turn >= 3

func get_colored_description() -> String:
	# No outcomes or not rolled yet - return plain description
	if rng_outcomes_data.is_empty() or not has_been_rolled():
		return description

	# Find each outcome's percentage in the original description and color it
	var result = description
	var search_from = 0

	for i in range(rng_outcomes_data.size()):
		var percent_str = "%.0f%%" % rng_outcomes_data[i].percent
		var pos = _find_standalone_percent(result, percent_str, search_from)
		if pos < 0:
			continue

		if rng_outcomes_data.size() == 1:
			# Binary: green if success, red if fail
			var color = "green" if rng_selected_index == 0 else "red"
			var colored = "[color=%s]%s[/color]" % [color, percent_str]
			result = result.substr(0, pos) + colored + result.substr(pos + percent_str.length())
			search_from = pos + colored.length()
		else:
			# Multi: green if this outcome was rolled, red otherwise
			var color = "green" if i == rng_selected_index else "red"
			var colored = "[color=%s]%s[/color]" % [color, percent_str]
			result = result.substr(0, pos) + colored + result.substr(pos + percent_str.length())
			search_from = pos + colored.length()

	return result

func _find_standalone_percent(text: String, percent_str: String, from: int) -> int:
	# Find a percentage like "30%" but not inside "-30%" or "130%"
	var pos = text.find(percent_str, from)
	while pos >= 0:
		if pos > 0:
			var char_before = text.unicode_at(pos - 1)
			# Skip if preceded by a digit (0-9) or minus sign
			if (char_before >= 48 and char_before <= 57) or char_before == 45:
				pos = text.find(percent_str, pos + 1)
				continue
		# Also skip if inside a BBCode tag
		if pos > 0 and text.substr(max(0, pos - 7), 7).find("[color") >= 0:
			pos = text.find(percent_str, pos + 1)
			continue
		return pos
	return -1

func get_effective_range() -> int:
	# Melee cards have 0 range. Ranged cards have base 5 + modifier.
	if not is_ranged:
		return 0
	return 5 + range_modifier

func get_range_display() -> String:
	# Returns display string for card range keyword
	if not is_ranged:
		return "Melee"
	var effective = get_effective_range()
	if range_modifier == 0:
		return "Ranged"
	elif range_modifier > 0:
		return "Ranged +%d" % range_modifier
	else:
		return "Ranged %d" % range_modifier

func increment_turns_in_hand() -> void:
	turns_in_hand += 1

func reset_hand_tracking() -> void:
	turns_in_hand = 0
	rng_outcomes.clear()
func execute(target, player_stats: PlayerStats = null, deck_manager = null, damage_reduction: int = 0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	last_damage_dealt = 0
	var is_empowered = false
	if player_stats and player_stats.is_empowered():
		is_empowered = player_stats.consume_empower()
	match card_id:
		"slash":
			_execute_slash(target, is_empowered, player_stats, damage_reduction, self_damage_percent, buff_mgr)
		"block":
			_execute_block(player_stats, is_empowered, buff_mgr)
		"discard":
			_execute_discard(deck_manager)
		"draw":
			_execute_draw(deck_manager)
		"potion_of_continuance":
			_execute_potion_of_continuance(deck_manager)
		"empower":
			_execute_empower(player_stats)
		"blink":
			_execute_blink(target)
		"heal":
			_execute_heal_with_poison_check(target, player_stats, buff_mgr)
		"gain_mana":
			_execute_gain_mana(player_stats)
		"healing_potion":
			_execute_heal_with_poison_check(target, player_stats, buff_mgr)
		"dagger_throw":
			_execute_dagger_throw(target, is_empowered, player_stats, damage_reduction, self_damage_percent)
		# === Brad Cards ===
		"life_swap":
			_execute_life_swap(target, player_stats, buff_mgr)
		"wear_down":
			_execute_wear_down(target, player_stats, buff_mgr)
		"taunt":
			_execute_taunt(target, player_stats)
		"life_steal":
			_execute_life_steal(player_stats, buff_mgr)
		"roar":
			_execute_roar(target, player_stats)
		"poke":
			_execute_poke(target, player_stats, buff_mgr)
		"armor_break":
			_execute_armor_break(player_stats, buff_mgr)
		"charge":
			_execute_charge(target, player_stats, buff_mgr)
		"heroic_leap":
			_execute_heroic_leap(target, player_stats, buff_mgr)
		"morphine":
			_execute_morphine(player_stats, buff_mgr)
		"turtle_up":
			_execute_turtle_up(player_stats, buff_mgr)
		"parry":
			_execute_parry(target, player_stats, buff_mgr)
		"approach":
			_execute_approach(player_stats, buff_mgr)
		"hold_the_line":
			_execute_hold_the_line(player_stats, buff_mgr)
		# === Jeremy Cards ===
		"trick_shot":
			_execute_trick_shot(target, player_stats, buff_mgr)
		"surrounding_ice":
			_execute_surrounding_ice(target, player_stats, buff_mgr)
		"risk_it":
			_execute_risk_it(player_stats, deck_manager)
		"biscuit":
			_execute_biscuit(player_stats, buff_mgr)
		"loaded_die":
			_execute_loaded_die(player_stats)
		"worst_that_could_happen":
			_execute_worst_that_could_happen(target, player_stats, buff_mgr)
		"oops":
			_execute_oops(target, player_stats, buff_mgr)
		"house_money":
			_execute_house_money(player_stats)
		"hope_this_works":
			_execute_hope_this_works(target, player_stats, buff_mgr)
		"lady_luck":
			_execute_lady_luck(target, player_stats, buff_mgr)
		"try_this":
			_execute_try_this(target, player_stats)
		"if_pigs_could_fly":
			_execute_if_pigs_could_fly(target, player_stats, buff_mgr)
		"snowballs_chance":
			_execute_snowballs_chance(target, player_stats, buff_mgr)
		# === Ryan Cards ===
		"raged_circulation":
			_execute_raged_circulation(target, player_stats)
		"poisoned_blood":
			_execute_poisoned_blood(player_stats, buff_mgr)
		"elixir":
			_execute_elixir(player_stats, buff_mgr)
		"shadows":
			_execute_shadows(player_stats, buff_mgr)
		"preparation":
			_execute_preparation(player_stats, deck_manager)
		"exacerbate_wounds":
			_execute_exacerbate_wounds(target, player_stats, deck_manager, buff_mgr)
		"reposition":
			_execute_reposition(deck_manager)
		"volatile_mixture":
			_execute_volatile_mixture(target, player_stats)
		"understanding":
			_execute_understanding(player_stats, buff_mgr)
		# === Stephen Cards ===
		"mark":
			_execute_mark(target, player_stats, buff_mgr)
		"rise":
			_execute_rise(target, player_stats)
		"quick_shot":
			_execute_quick_shot(target, player_stats, deck_manager, buff_mgr)
		"reload":
			_execute_reload(deck_manager)
		"enchanted_quiver":
			_execute_enchanted_quiver(player_stats, deck_manager, buff_mgr)
		"tighten_string":
			_execute_tighten_string(player_stats, buff_mgr)
		"down_town":
			_execute_down_town(target, player_stats, buff_mgr)
		"barricade":
			_execute_barricade(target, player_stats)
		"sky_fall":
			_execute_sky_fall(target, player_stats, buff_mgr)
		"sky_attack":
			_execute_sky_attack(target, player_stats, buff_mgr)
		"lead_arrow":
			_execute_lead_arrow(target, player_stats, buff_mgr)
		"last_breath":
			_execute_last_breath(target, player_stats, buff_mgr)
		"mixed_bag":
			_execute_mixed_bag(target, player_stats, buff_mgr)
		"quick_arrow":
			_execute_quick_arrow(target, player_stats, buff_mgr)
		# === Cory Cards ===
		"round_em_up":
			_execute_round_em_up(target, player_stats)
		"trip":
			_execute_trip(target, player_stats, buff_mgr)
		"choke":
			_execute_choke(target, player_stats)
		"push":
			_execute_push(target, player_stats)
		"defensive_awareness":
			_execute_defensive_awareness(player_stats, buff_mgr)
		"sweeping_disarm":
			_execute_sweeping_disarm(target, player_stats, buff_mgr)
		"consecutive_snap":
			_execute_consecutive_snap(target, player_stats, buff_mgr)
		"swap":
			_execute_swap(target, player_stats)
		"meditate":
			_execute_meditate(player_stats, deck_manager)
		_:
			print("[CARD] Unknown card: %s" % card_id)

	# Life Steal: if an attack dealt damage and we have life steal buff, heal for damage dealt
	if card_type == CardType.ATTACK and buff_mgr and buff_mgr.has_life_steal():
		var dealt = last_damage_dealt if last_damage_dealt > 0 else damage
		if dealt > 0:
			buff_mgr.consume_life_steal(dealt)

	# Wear Down: if an attack hit an enemy and we have wear_down buff, apply wear_down to that enemy
	if card_type == CardType.ATTACK and buff_mgr and buff_mgr.has_wear_down():
		if target and target.has_method("apply_wear_down"):
			target.apply_wear_down(3)
			print("[CARD] Wear Down triggered! Enemy attack reduced")

func _execute_gain_mana(player_stats: PlayerStats) -> void:
	if player_stats:
		var amount = 2
		# Intelligence boosts mana gain via spell multiplier
		amount = player_stats.get_effective_heal_amount(amount)
		player_stats.gain_mana(amount)
		print("[CARD] Gained %d mana!" % amount)
		
func _execute_slash(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction: int = 0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
		player_stats.register_attack()
	
	if is_empowered and player_stats:
		total_damage += player_stats.empower_damage_bonus
	
	# Strengthen bonus
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		
		# Crit check with Enlightened
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			print("[CARD] CRITICAL HIT! Damage doubled!")
			buff_mgr.consume_enlightened()
	
	total_damage = max(1, total_damage - damage_reduction)
	
	print("[CARD] %s deals %d damage!" % [card_name, total_damage])
	last_damage_dealt = total_damage

	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)

		# Thorns check - if target has buff_manager
		if target.has_method("get_buff_manager"):
			var target_buff = target.get_buff_manager()
			if target_buff:
				target_buff.on_attacked(buff_mgr.owner_node if buff_mgr else null)

	if self_damage_percent > 0.0 and player_stats:
		var self_dmg = floori(total_damage * self_damage_percent)
		if self_dmg > 0:
			player_stats.take_damage(self_dmg)
			print("[CARD] Cursed: took %d self-damage!" % self_dmg)
func _execute_dagger_throw(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction: int = 0, self_damage_percent: float = 0.0) -> void:
	var total_damage = base_damage + bonus_damage
	
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	
	if is_empowered and player_stats:
		total_damage += player_stats.empower_damage_bonus
	
	total_damage = max(1, total_damage - damage_reduction)
	
	print("[CARD] Dagger Throw deals %d damage!" % total_damage)
	
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	
	if self_damage_percent > 0.0 and player_stats:
		var self_dmg = floori(total_damage * self_damage_percent)
		if self_dmg > 0:
			player_stats.take_damage(self_dmg)
func _execute_block(player_stats: PlayerStats, is_empowered: bool = false, buff_mgr: BuffManager = null) -> void:
	var armor_amount = block
	
	if is_empowered and player_stats:
		armor_amount = max(1, armor_amount - player_stats.empower_block_reduction)
	
	# Bolster bonus
	if buff_mgr:
		armor_amount += buff_mgr.consume_bolster()
	
	if player_stats:
		player_stats.add_armor(armor_amount)
	
	print("[CARD] %s grants %d armor!" % [card_name, armor_amount])

func _execute_discard(deck_manager) -> void:
	if deck_manager and deck_manager.hand.size() > 0:
		var random_index = randi() % deck_manager.hand.size()
		var discarded = deck_manager.hand[random_index]
		deck_manager.hand.remove_at(random_index)
		deck_manager.discard_pile.append(discarded)
		deck_manager.hand_updated.emit()
		print("[CARD] Discarded: %s" % discarded.card_name)
	else:
		print("[CARD] No cards to discard!")

func _execute_draw(deck_manager) -> void:
	if deck_manager:
		deck_manager.draw_card()
		print("[CARD] Drew a card!")

func _execute_potion_of_continuance(deck_manager) -> void:
	if deck_manager:
		deck_manager.draw_card()
		deck_manager.draw_card()
		print("[CARD] Potion of Continuance: Drew 2 cards!")

func _execute_empower(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.apply_empower(2)
		print("[CARD] Next 2 cards empowered!")

func _execute_blink(player_node) -> void:
	if player_node and player_node.has_method("blink_to_mouse"):
		player_node.blink_to_mouse()
		print("[CARD] Blinked!")

func _execute_heal_with_poison_check(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# General healing logic: if Poison Blood is active and target is an enemy, deal damage instead
	if buff_mgr and buff_mgr.poisoned_blood_active and target and target.has_method("take_damage") and not target.has_method("get_stats"):
		var dmg = heal_amount
		if player_stats:
			dmg = player_stats.get_effective_heal_amount(heal_amount)
		target.take_damage(dmg)
		print("[CARD] Poisoned Blood: %s dealt %d damage!" % [card_name, dmg])
	else:
		if player_stats:
			player_stats.heal(heal_amount)
			print("[CARD] %s restored health!" % card_name)

func enhance(amount: int) -> bool:
	# Only enhance attack cards, and only once
	if card_type != CardType.ATTACK:
		print("[CARD] %s is not an attack card, cannot enhance" % card_name)
		return false
	
	if is_enhanced:
		print("[CARD] %s already enhanced, skipping" % card_name)
		return false
	
	bonus_damage += amount
	is_enhanced = true
	print("[CARD] %s enhanced! Bonus damage now: %d" % [card_name, bonus_damage])
	return true

func get_total_damage() -> int:
	return base_damage + bonus_damage

func is_jailed() -> bool:
	return jail_time_remaining > 0

# This is now handled by deck_manager.process_turn()
# Can remove update_jail or keep for compatibility
func update_jail_turn() -> void:
	if jail_time_remaining > 0:
		jail_time_remaining -= 1
		if jail_time_remaining <= 0:
			print("[CARD] %s released from jail!" % card_name)

func jail(duration: int) -> void:
	jail_time_remaining = duration
	print("[CARD] %s jailed for %d turns" % [card_name, duration])

# Factory methods
static func create_slash() -> Card:
	var card = Card.new()
	card.card_id = "slash"
	card.card_name = "Slash"
	card.description = "10 damage"
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 4  # Standard attack
	card.damage = 10
	card.base_damage = 10
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	return card

static func create_block() -> Card:
	var card = Card.new()
	card.card_id = "block"
	card.card_name = "Block"
	card.description = "5 armor"
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 1
	card.tempo_cost = 2  # Standard defense
	card.damage = 0
	card.base_damage = 0
	card.block = 5
	card.base_block = 5
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_discard() -> Card:
	var card = Card.new()
	card.card_id = "discard"
	card.card_name = "Discard"
	card.description = "Discard a random card"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 1  # Quick action
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_draw() -> Card:
	var card = Card.new()
	card.card_id = "draw"
	card.card_name = "Draw"
	card.description = "Draw a card"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 1  # Quick action
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_empower() -> Card:
	var card = Card.new()
	card.card_id = "empower"
	card.card_name = "Empower"
	card.description = "Next 2 cards: +3 dmg or -3 block"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 2  # Setup action
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card

static func create_blink() -> Card:
	var card = Card.new()
	card.card_id = "blink"
	card.card_name = "Blink"
	card.description = "Teleport to cursor"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 1  # Quick/instant
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.target_types = ["point"]
	card.heal_amount = 0
	return card

static func create_heal() -> Card:
	var card = Card.new()
	card.card_id = "heal"
	card.card_name = "Heal"
	card.description = "Restore 4 HP. Deals damage instead with Poisoned Blood."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 2  # Takes effort to heal
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.target_types =  ["self", "ally"]
	card.heal_amount = 4
	card.target_types = ["self"]
	return card

static func create_gain_mana() -> Card:
	var card = Card.new()
	card.card_id = "gain_mana"
	card.card_name = "Energy"
	card.description = "Gain 2 mana"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 1  # Quick action
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card

static func create_healing_potion() -> Card:
	var card = Card.new()
	card.card_id = "healing_potion"
	card.card_name = "Healing Potion"
	card.description = "Heal 5. Deals damage instead with Poisoned Blood."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 1  # Quick action
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 5
	card.target_types = ["self"]
	return card

static func create_dagger_throw() -> Card:
	var card = Card.new()
	card.card_id = "dagger_throw"
	card.card_name = "Dagger Throw"
	card.description = "5 damage"
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 1  # Quick action
	card.damage = 5
	card.base_damage = 5
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	return card

# ============================================
# BRAD CARD EXECUTE FUNCTIONS
# ============================================

func _execute_life_swap(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if not player_stats:
		return
	var old_health = player_stats.current_health
	var old_mana = int(player_stats.current_mana)
	# Swap health and mana pools
	var new_health = min(old_mana, player_stats.max_health)
	var new_mana = min(old_health, player_stats.max_mana)
	var life_lost = max(0, old_health - new_health)
	player_stats.current_health = new_health
	player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
	player_stats.current_mana = new_mana
	player_stats.mana_changed.emit(player_stats.current_mana, player_stats.max_mana)
	# Deal damage equal to life lost
	if life_lost > 0 and target and target.has_method("take_damage"):
		target.take_damage(life_lost)
	print("[CARD] Life Swap! HP: %d→%d, Mana: %d→%d, dealt %d damage" % [old_health, new_health, old_mana, new_mana, life_lost])

func _execute_wear_down(_target, _player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_wear_down(3, "Wear Down"))
	print("[CARD] Wear Down active! Each attack reduces enemy's attack by 1 for 3 turns")

func _execute_taunt(_target, _player_stats: PlayerStats) -> void:
	# Taunt effect applied via world effects in main.gd (needs enemy_spawner)
	print("[CARD] Taunt! Nearby enemies must target you for 2 turns")

func _execute_life_steal(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_life_steal("Life Steal"))
	print("[CARD] Life Steal active! Next hit heals for damage dealt")

func _execute_roar(_target, _player_stats: PlayerStats) -> void:
	# Knockback applied via world effects in main.gd (needs enemy_spawner)
	print("[CARD] Roar! Enemies knocked back 1 space")

func _execute_poke(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = 2
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(2)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	last_damage_dealt = total_damage
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	print("[CARD] Poke deals %d damage!" % total_damage)

func _execute_armor_break(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Next attack deals double damage but only affects armor
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_strengthen(5, 1, "Armor Break"))
	print("[CARD] Armor Break! Next attack deals double damage to armor only")

func _execute_charge(_target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Damage calculated here, movement + multi-hit + knockback handled by main.gd
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	last_damage_dealt = total_damage
	print("[CARD] Charge! %d damage to all enemies in path" % total_damage)

func _execute_heroic_leap(_target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Calculate leap distance from STR, damage from distance. Jump handled by main.gd
	var leap_distance = 3
	if player_stats:
		leap_distance = max(2, player_stats.strength / 3)
	var total_damage = leap_distance * 3
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	last_damage_dealt = total_damage
	print("[CARD] Heroic Leap! %d paces, %d damage on landing" % [leap_distance, total_damage])

func _execute_morphine(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if not player_stats:
		return
	player_stats.add_armor(4)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_morphine(4, 3, "Morphine"))
	print("[CARD] Morphine! Gained 4 temp HP. Will lose it and take 2 damage in 3 turns")

func _execute_turtle_up(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_fortify(4, "Turtle Up"))
	print("[CARD] Turtle Up! Armor won't decay for 4 turns")

func _execute_parry(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if player_stats:
		player_stats.add_armor(5)
	var total_damage = 5
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(5)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_brace(30, 1, "Parry"))
	print("[CARD] Parry! Gained 5 armor, dealt %d damage. Next damage reduced" % total_damage)

func _execute_approach(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Slow self for 2 turns, gain 5 armor per movement taken
	if buff_mgr and buff_mgr.debuff_manager:
		buff_mgr.debuff_manager.apply_debuff(Debuff.create_slowed(2, 2, "Approach"))
	if buff_mgr:
		buff_mgr.approach_armor_per_move = 5
		buff_mgr.approach_turns_remaining = 2
	print("[CARD] Approach! Slowed for 2 turns, gain 5 armor per movement")

func _execute_hold_the_line(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# All allies gain 5 armor, 2 determination, 2 strength
	if player_stats:
		player_stats.add_armor(5)
		player_stats.determination += 2
		player_stats.base_strength += 2
		player_stats.recalculate_derived_stats()
	print("[CARD] Hold the Line! All allies gain 5 armor, +2 DET, +2 STR")

# ============================================
# JEREMY CARD EXECUTE FUNCTIONS
# ============================================

func _execute_trick_shot(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	# 80% bounce chance, -20% per bounce
	var bounce_chance = 80.0
	var bounces = 0
	while randf() * 100.0 < bounce_chance:
		bounces += 1
		bounce_chance -= 20.0
		if bounce_chance <= 0:
			break
	print("[CARD] Trick Shot! Dealt %d damage, bounced %d times" % [total_damage, bounces])

func _execute_surrounding_ice(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_spell_damage(total_damage)
	# Store damage for main.gd AOE handling (independent roll per enemy)
	last_damage_dealt = total_damage
	print("[CARD] Surrounding Ice prepared! %d damage per hit (rolls per enemy in main)" % total_damage)

func _execute_risk_it(player_stats: PlayerStats, deck_manager = null) -> void:
	# 30% chance to receive the biscuit
	if randf() < 0.3:
		# Add Biscuit card to hand
		if deck_manager:
			var biscuit = Card.create_biscuit()
			deck_manager.hand.append(biscuit)
			deck_manager.hand_updated.emit()
		print("[CARD] Risk It pays off! You got the Biscuit!")
	else:
		print("[CARD] Risk It... no biscuit this time")

func _execute_biscuit(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if player_stats:
		player_stats.current_health = player_stats.max_health
		player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_strengthen(3, 3, "Biscuit"))
	print("[CARD] Biscuit! Fully healed and +30%% damage for 3 turns")

func _execute_loaded_die(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.chance_boost += 10.0
	print("[CARD] Loaded Die! Next card's odds increased by 10%%")

func _execute_worst_that_could_happen(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = 5
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(5)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	# Always deal base 5 damage
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	# Use pre-rolled RNG: index 0 = +15 damage, index 1 = stun
	if rng_selected_index == 0:
		if target and target.has_method("take_damage"):
			target.take_damage(15)
		print("[CARD] What's the worst? +15 bonus damage! Total: %d" % (total_damage + 15))
	else:
		if target and target.has_method("apply_debuff"):
			target.apply_debuff("stun", 1)
		print("[CARD] What's the worst? Target stunned! Dealt %d" % total_damage)

func _execute_oops(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var hit_damage = base_damage + bonus_damage
	if player_stats:
		hit_damage = player_stats.get_effective_physical_damage(hit_damage)
	# 30% = 5 hits, 40% = 3 hits, 30% = 2 hits
	var roll = randf()
	var hits = 2
	if roll < 0.3:
		hits = 5
	elif roll < 0.7:
		hits = 3
	for i in range(hits):
		if target and target.has_method("take_damage"):
			target.take_damage(hit_damage)
	print("[CARD] Oops! Hit %d times for %d each (total: %d)" % [hits, hit_damage, hits * hit_damage])

func _execute_house_money(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.chance_boost = 100.0
	print("[CARD] House Money! Next odds will automatically trigger")

func _execute_hope_this_works(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# 50% to heal ally and provide strength for 3 turns
	if randf() < 0.5:
		if player_stats:
			var heal_amt = max(3, player_stats.intelligence)
			player_stats.heal(heal_amt)
			player_stats.base_strength += 2
			player_stats.recalculate_derived_stats()
		print("[CARD] Hope This Works... it worked! Healed and +STR for 3 turns")
	else:
		print("[CARD] Hope This Works... it didn't work")

func _execute_lady_luck(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Bless an ally - crit chance +30% for 2 turns
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_enlightened(30, 5, "Lady Luck"))
	print("[CARD] Lady Luck! Crit chance +30%% for 2 turns")

func _execute_try_this(target, player_stats: PlayerStats) -> void:
	# Increase ally mana pool by 3 and hand size by 2 for 2 turns. 10% reverse
	if player_stats:
		if randf() < 0.1:
			player_stats.max_mana = max(1, player_stats.max_mana - 3)
			player_stats.hand_size = max(1, player_stats.hand_size - 2)
			print("[CARD] Try This! Reversed! -3 mana pool, -2 hand size")
		else:
			player_stats.max_mana += 3
			player_stats.hand_size += 2
			print("[CARD] Try This! +3 mana pool, +2 hand size for 2 turns")

func _execute_if_pigs_could_fly(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = 15
	if player_stats:
		total_damage = player_stats.get_effective_spell_damage(15)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	print("[CARD] If Pigs Could Fly! Flying pig explodes for %d damage!" % total_damage)

func _execute_snowballs_chance(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_spell_damage(total_damage)
	# Store damage for main.gd AOE handling (fire line + optional cone)
	last_damage_dealt = total_damage
	print("[CARD] A Snowball's Chance prepared! %d damage (AOE in main)" % total_damage)

# ============================================
# RYAN CARD EXECUTE FUNCTIONS
# ============================================

func _execute_raged_circulation(target, player_stats: PlayerStats) -> void:
	# +30% healing effectiveness for 3 turns
	if player_stats:
		player_stats.healing_boost_percent = 0.3
		player_stats.healing_boost_turns = 3
	print("[CARD] Raged Circulation! Healing +30%% for 3 turns")

func buff_mgr_exists(target) -> bool:
	return target and target.has_method("get_buff_manager") and target.get_buff_manager() != null

func _execute_poisoned_blood(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Heal cards now deal damage instead of healing for 3 turns
	if buff_mgr:
		buff_mgr.poisoned_blood_active = true
		buff_mgr.poisoned_blood_turns = 3
	print("[CARD] Poisoned Blood! Heal cards now deal damage instead for 3 turns")

func _execute_elixir(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Poison cards now heal
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_regen(3, 99, "Elixir"))
	print("[CARD] Elixir! Poison effects now heal instead")

func _execute_shadows(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_resilient(50, 2, "Shadows"))
	print("[CARD] Shadows! Invisible for 2 turns")

func _execute_preparation(player_stats: PlayerStats, deck_manager = null) -> void:
	# Next utility card costs 2 less; chains while playing utilities
	if deck_manager:
		deck_manager.prep_utility_discount = 2
	print("[CARD] Preparation! Next utility cards cost 2 less (chains while playing utilities)")

func _execute_exacerbate_wounds(target, player_stats: PlayerStats, deck_manager = null, buff_mgr: BuffManager = null) -> void:
	var discard_count = 0
	if deck_manager:
		discard_count = deck_manager.discard_pile.size()
	var total_damage = discard_count * 2
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	print("[CARD] Exacerbate Wounds! %d cards discarded this turn = %d damage" % [discard_count, total_damage])

func _execute_reposition(deck_manager) -> void:
	# Discard a selected card and draw
	if deck_manager:
		if deck_manager.hand.size() > 0:
			var random_index = randi() % deck_manager.hand.size()
			var discarded = deck_manager.hand[random_index]
			deck_manager.hand.remove_at(random_index)
			deck_manager.discard_pile.append(discarded)
			deck_manager.draw_card()
			deck_manager.hand_updated.emit()
			print("[CARD] Reposition! Discarded %s, drew a new card" % discarded.card_name)

func _execute_volatile_mixture(target, player_stats: PlayerStats) -> void:
	# Playing the card safely removes it from hand (no effect)
	# The real effects are: discard -> damage enemy, end of turn in hand -> self-damage
	print("[CARD] Volatile Mixture played! Safely disposed of")

func _execute_understanding(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Start a 2-turn countdown; when it expires, next attack auto-crits
	if buff_mgr:
		buff_mgr.understanding_turns = 2
	print("[CARD] Understanding! In 2 turns, the next attack will auto-crit")

# ============================================
# STEPHEN CARD EXECUTE FUNCTIONS
# ============================================

func _execute_mark(target, _player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if target and target.has_method("apply_debuff"):
		target.apply_debuff("marked", 99)
	print("[CARD] Mark! Target receives extra damage from your attacks")

func _execute_rise(target, _player_stats: PlayerStats) -> void:
	print("[CARD] Rise! Earth structure created on the map")

func _execute_quick_shot(target, player_stats: PlayerStats, deck_manager = null, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	if deck_manager:
		deck_manager.draw_card()
	print("[CARD] Quick Shot! %d damage + drew a card" % total_damage)

func _execute_reload(deck_manager) -> void:
	if deck_manager:
		for i in range(3):
			deck_manager.draw_card()
	print("[CARD] Reload! Drew 3 cards")

func _execute_enchanted_quiver(player_stats: PlayerStats, deck_manager = null, buff_mgr: BuffManager = null) -> void:
	# Next 3 ranged attacks create a 0-cost ranged attack card (4 damage)
	if buff_mgr:
		buff_mgr.enchanted_quiver_charges = 3
	print("[CARD] Enchanted Quiver! Next 3 ranged attacks create free arrow cards")

func _execute_tighten_string(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Next 3 ranged attacks: +3 tempo, +6 damage, +6 range, +20% crit
	if buff_mgr:
		buff_mgr.tighten_string_charges = 3
	print("[CARD] Tighten String! Next 3 ranged attacks: +3 tempo, +6 damage, +6 range, +20%% crit")

func _execute_down_town(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	print("[CARD] Down Town! Long range (+7) shot for %d damage" % total_damage)

func _execute_barricade(target, _player_stats: PlayerStats) -> void:
	print("[CARD] Barricade! Land barrier created in front of you")

func _execute_sky_fall(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	last_damage_dealt = total_damage
	print("[CARD] Sky Fall! Arrow shot upward. In 2 turns, it lands for %d damage" % total_damage)

func _execute_sky_attack(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	print("[CARD] Sky Attack! Leaped and shot from above for %d damage (High Ground)" % total_damage)

func _execute_lead_arrow(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	total_damage = floori(total_damage * 1.8)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	print("[CARD] Lead Arrow! 1.8x damage from high ground: %d" % total_damage)

func _execute_last_breath(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Consume all remaining mana, deal 3 damage per mana spent
	var mana_used = 0
	if player_stats:
		mana_used = int(player_stats.current_mana)
		if mana_used > 0:
			player_stats.spend_mana(mana_used)
	var total_damage = mana_used * 3
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	print("[CARD] Last Breath! Consumed %d mana for %d damage" % [mana_used, total_damage])

func _execute_mixed_bag(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
		player_stats.register_attack()
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	print("[CARD] Mixed Bag! Standard arrow for %d damage" % total_damage)

func _execute_quick_arrow(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	print("[CARD] Quick Arrow! Free arrow for %d damage" % total_damage)

# ============================================
# CORY CARD EXECUTE FUNCTIONS
# ============================================

func _execute_round_em_up(target, _player_stats: PlayerStats) -> void:
	print("[CARD] Round 'Em Up! Enemies near target point displaced inward")

func _execute_trip(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = 5
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(5)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	if target and target.has_method("apply_debuff"):
		target.apply_debuff("slow", 1)  # -4 movement
	print("[CARD] Trip! %d damage, enemy movement -4" % total_damage)

func _execute_choke(target, _player_stats: PlayerStats) -> void:
	if target and target.has_method("apply_debuff"):
		target.apply_debuff("silenced", 3)  # Sticky 3
		target.apply_debuff("choke_dot", 3)
	print("[CARD] Choke! Enemy silenced and taking damage per round. Sticky 3")

func _execute_push(target, _player_stats: PlayerStats) -> void:
	print("[CARD] Push! Unit pushed away from you")

func _execute_defensive_awareness(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Gain 3 armor per enemy within 2 spaces
	var armor_gain = 3  # Base (would multiply by nearby enemy count)
	if player_stats:
		player_stats.add_armor(armor_gain)
	print("[CARD] Defensive Awareness! Gained %d armor (3 per nearby enemy)" % armor_gain)

func _execute_sweeping_disarm(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = 3
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(3)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage)
	if target and target.has_method("apply_debuff"):
		target.apply_debuff("disarmed", 1)
	print("[CARD] Sweeping Disarm! %d damage, surrounding enemies disarmed" % total_damage)

func _execute_consecutive_snap(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var snap_damage = base_damage + (consecutive_uses * 9)
	if player_stats:
		snap_damage = player_stats.get_effective_physical_damage(snap_damage)
	if buff_mgr:
		snap_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			snap_damage = floori(snap_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(snap_damage)
	consecutive_uses += 1
	# Cost decreases by 1m/1t each use (max 3 uses via sticky)
	mana_cost = max(0, 3 - consecutive_uses)
	tempo_cost = max(0, 3 - consecutive_uses)
	if consecutive_uses >= sticky:
		print("[CARD] Consecutive Snap! %d damage (final use #%d)" % [snap_damage, consecutive_uses])
	else:
		print("[CARD] Consecutive Snap! %d damage (use #%d). Next costs %dm/%dt" % [snap_damage, consecutive_uses, mana_cost, tempo_cost])

func _execute_swap(target, _player_stats: PlayerStats) -> void:
	print("[CARD] Swap! Switched positions with target")

func _execute_meditate(player_stats: PlayerStats, deck_manager = null) -> void:
	# Discard hand, draw to full -2, heal to 80%, skip next turn
	if deck_manager:
		while deck_manager.hand.size() > 0:
			var card = deck_manager.hand.pop_back()
			deck_manager.discard_pile.append(card)
		var draw_count = max(0, deck_manager.get_hand_cap() - 2)
		for i in range(draw_count):
			deck_manager.draw_card()
		deck_manager.hand_updated.emit()
	if player_stats:
		var target_hp = floori(player_stats.max_health * 0.8)
		if player_stats.current_health < target_hp:
			player_stats.current_health = target_hp
			player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
	print("[CARD] Meditate! Hand refreshed, healed to 80%%, skipping next turn")

# ============================================
# BRAD CARD FACTORY METHODS
# ============================================

static func create_life_swap() -> Card:
	var card = Card.new()
	card.card_id = "life_swap"
	card.card_name = "Life Swap"
	card.description = "Exchange HP and mana pools. Deal damage equal to HP lost."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 4
	card.target_types = ["enemy"]
	return card

static func create_wear_down() -> Card:
	var card = Card.new()
	card.card_id = "wear_down"
	card.card_name = "Wear Down"
	card.description = "Decrease enemy attack by 1 per consecutive hit. Lasts 3 turns."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 1
	card.duration = 3
	card.target_types = ["self"]
	return card

static func create_taunt() -> Card:
	var card = Card.new()
	card.card_id = "taunt"
	card.card_name = "Taunt"
	card.description = "Taunt enemies around you. They must target you."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 0
	card.target_types = ["all_nearby"]
	card.is_aoe = true
	card.aoe_shape = "circle"
	return card

static func create_life_steal() -> Card:
	var card = Card.new()
	card.card_id = "life_steal"
	card.card_name = "Life Steal"
	card.description = "Heal for the amount of damage done on next hit."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 2
	card.target_types = ["self"]
	return card

static func create_roar() -> Card:
	var card = Card.new()
	card.card_id = "roar"
	card.card_name = "Roar"
	card.description = "Knock enemies back 1 space."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 2
	card.target_types = ["all_nearby"]
	card.is_aoe = true
	card.aoe_shape = "circle"
	return card

static func create_poke() -> Card:
	var card = Card.new()
	card.card_id = "poke"
	card.card_name = "Poke"
	card.description = "Deal 2 damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 2
	card.base_damage = 2
	card.target_types = ["enemy"]
	return card

static func create_armor_break() -> Card:
	var card = Card.new()
	card.card_id = "armor_break"
	card.card_name = "Armor Break"
	card.description = "Next attack deals double damage, but only affects armor."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.target_types = ["enemy"]
	return card

static func create_charge() -> Card:
	var card = Card.new()
	card.card_id = "charge"
	card.card_name = "Charge"
	card.description = "Charge forward, deal damage to all enemies hit and knock them back."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 2
	card.tempo_cost = 4
	card.damage = 8
	card.base_damage = 8
	card.target_types = ["enemy"]
	card.is_aoe = true
	card.aoe_shape = "line"
	return card

static func create_heroic_leap() -> Card:
	var card = Card.new()
	card.card_id = "heroic_leap"
	card.card_name = "Heroic Leap"
	card.description = "Jump based on STR. Deal damage based on distance leaped."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 4
	card.tempo_cost = 5
	card.damage = 12
	card.base_damage = 12
	card.target_types = ["point"]
	return card

static func create_morphine() -> Card:
	var card = Card.new()
	card.card_id = "morphine"
	card.card_name = "Morphine"
	card.description = "Gain 4 temp HP. After 3 turns, lose it and take 2 damage."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 0
	card.target_types = ["self"]
	return card

static func create_turtle_up() -> Card:
	var card = Card.new()
	card.card_id = "turtle_up"
	card.card_name = "Turtle Up"
	card.description = "Armor does not decay for 4 turns."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 3
	card.tempo_cost = 0
	card.duration = 4
	card.target_types = ["self"]
	return card

static func create_parry() -> Card:
	var card = Card.new()
	card.card_id = "parry"
	card.card_name = "Parry"
	card.description = "Gain 5 armor, deal 5 damage. Next damage to you is reduced."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 1
	card.tempo_cost = 5
	card.damage = 5
	card.base_damage = 5
	card.block = 5
	card.base_block = 5
	card.target_types = ["enemy"]
	return card

static func create_approach() -> Card:
	var card = Card.new()
	card.card_id = "approach"
	card.card_name = "Approach"
	card.description = "Slowed for 2 turns. For each movement taken, gain 5 armor."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 1
	card.tempo_cost = 3
	card.target_types = ["self"]
	return card

static func create_hold_the_line() -> Card:
	var card = Card.new()
	card.card_id = "hold_the_line"
	card.card_name = "Hold the Line"
	card.description = "All allies gain 5 armor, +2 DET, and +2 STR."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 5
	card.block = 5
	card.base_block = 5
	card.target_types = ["self"]
	return card

# ============================================
# JEREMY CARD FACTORY METHODS
# ============================================

static func create_trick_shot() -> Card:
	var card = Card.new()
	card.card_id = "trick_shot"
	card.card_name = "Trick Shot"
	card.description = "Deal damage. 80%% chance to bounce, -20%% per bounce."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 2
	card.tempo_cost = 4
	card.damage = 8
	card.base_damage = 8
	card.rng_outcomes_data = [{percent = 80.0}]
	card.is_ranged = true
	card.target_types = ["enemy"]
	return card

static func create_surrounding_ice() -> Card:
	var card = Card.new()
	card.card_id = "surrounding_ice"
	card.card_name = "Surrounding Ice"
	card.description = "Ice stalagmites deal heavy damage around you. 30%% miss chance per enemy."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.damage = 15
	card.base_damage = 15
	card.chance_effect_percent = 70.0
	card.rng_outcomes_data = [{percent = 30.0}]
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.target_types = ["all_nearby"]
	return card

static func create_risk_it() -> Card:
	var card = Card.new()
	card.card_id = "risk_it"
	card.card_name = "Risk It"
	card.description = "30%% chance to receive the Biscuit."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 0
	card.rng_outcomes_data = [{percent = 30.0}]
	card.target_types = ["self"]
	return card

static func create_biscuit() -> Card:
	var card = Card.new()
	card.card_id = "biscuit"
	card.card_name = "Biscuit"
	card.description = "Fully heal yourself and gain 30%% damage for 3 turns."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 0
	card.duration = 3
	card.target_types = ["self"]
	return card

static func create_loaded_die() -> Card:
	var card = Card.new()
	card.card_id = "loaded_die"
	card.card_name = "Loaded Die"
	card.description = "Next card with a probability has +10%% higher chance."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 1
	card.target_types = ["self"]
	return card

static func create_worst_that_could_happen() -> Card:
	var card = Card.new()
	card.card_id = "worst_that_could_happen"
	card.card_name = "What's the Worst?"
	card.description = "5 damage. 50%% for +15 damage, 50%% to stun target."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 7
	card.damage = 5
	card.base_damage = 5
	card.rng_outcomes_data = [{percent = 50.0}, {percent = 50.0}]
	card.target_types = ["enemy"]
	return card

static func create_oops() -> Card:
	var card = Card.new()
	card.card_id = "oops"
	card.card_name = "Oops"
	card.description = "30%% for 5 hits, 40%% for 3 hits, 30%% for 2 hits."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.damage = 4
	card.base_damage = 4
	card.rng_outcomes_data = [{percent = 30.0}, {percent = 40.0}, {percent = 30.0}]
	card.target_types = ["enemy"]
	return card

static func create_house_money() -> Card:
	var card = Card.new()
	card.card_id = "house_money"
	card.card_name = "House Money"
	card.description = "Your next odds will automatically trigger."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 5
	card.target_types = ["self"]
	return card

static func create_hope_this_works() -> Card:
	var card = Card.new()
	card.card_id = "hope_this_works"
	card.card_name = "Hope This Works"
	card.description = "50%% to heal ally and provide STR for 3 turns."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 3
	card.rng_outcomes_data = [{percent = 50.0}]
	card.duration = 3
	card.target_types = ["ally"]
	return card

static func create_lady_luck() -> Card:
	var card = Card.new()
	card.card_id = "lady_luck"
	card.card_name = "Lady Luck"
	card.description = "Bless an ally. Crit chance +30%% for 2 turns."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 1
	card.duration = 2
	card.target_types = ["ally"]
	return card

static func create_try_this() -> Card:
	var card = Card.new()
	card.card_id = "try_this"
	card.card_name = "Try This!"
	card.description = "Ally +3 mana pool, +2 hand size for 2 turns. 10%% chance reverse."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.rng_outcomes_data = [{percent = 10.0}]
	card.duration = 2
	card.target_types = ["ally"]
	return card

static func create_if_pigs_could_fly() -> Card:
	var card = Card.new()
	card.card_id = "if_pigs_could_fly"
	card.card_name = "If Pigs Could Fly"
	card.description = "Summon a flying pig that explodes on the target."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 0
	card.damage = 15
	card.base_damage = 15
	card.is_ranged = true
	card.range_modifier = 2
	card.target_types = ["enemy"]
	return card

static func create_snowballs_chance() -> Card:
	var card = Card.new()
	card.card_id = "snowballs_chance"
	card.card_name = "A Snowball's Chance"
	card.description = "Searing fire 3 spaces forward. 50%% to also spread snowballs in a cone."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 2
	card.tempo_cost = 3
	card.damage = 10
	card.base_damage = 10
	card.chance_effect_percent = 50.0
	card.rng_outcomes_data = [{percent = 50.0}]
	card.is_aoe = true
	card.aoe_shape = "line"
	card.aoe_range = 192.0  # 3 grid spaces (64px each)
	card.target_types = ["point"]
	return card

# ============================================
# RYAN CARD FACTORY METHODS
# ============================================

static func create_raged_circulation() -> Card:
	var card = Card.new()
	card.card_id = "raged_circulation"
	card.card_name = "Raged Circulation"
	card.description = "Target receives 30%% more from healing and regen for 3 turns."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 2
	card.is_ranged = true
	card.target_types = ["ally"]
	return card

static func create_poisoned_blood() -> Card:
	var card = Card.new()
	card.card_id = "poisoned_blood"
	card.card_name = "Poisoned Blood"
	card.description = "Heal cards now apply damage instead."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 2
	card.target_types = ["self"]
	return card

static func create_elixir() -> Card:
	var card = Card.new()
	card.card_id = "elixir"
	card.card_name = "Elixir"
	card.description = "Poison cards now heal instead."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 2
	card.target_types = ["self"]
	return card

static func create_shadows() -> Card:
	var card = Card.new()
	card.card_id = "shadows"
	card.card_name = "Shadows"
	card.description = "Go invisible for 2 turns."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 4
	card.duration = 2
	card.target_types = ["self"]
	return card

static func create_preparation() -> Card:
	var card = Card.new()
	card.card_id = "preparation"
	card.card_name = "Preparation"
	card.description = "Next utility card and the one after cost 2 less."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 3
	card.target_types = ["self"]
	return card

static func create_exacerbate_wounds() -> Card:
	var card = Card.new()
	card.card_id = "exacerbate_wounds"
	card.card_name = "Exacerbate Wounds"
	card.description = "Deal damage for each card discarded this turn."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 7
	card.target_types = ["enemy"]
	return card

static func create_reposition() -> Card:
	var card = Card.new()
	card.card_id = "reposition"
	card.card_name = "Reposition"
	card.description = "Discard a card and draw a new one."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 2
	card.target_types = ["self"]
	return card

static func create_volatile_mixture() -> Card:
	var card = Card.new()
	card.card_id = "volatile_mixture"
	card.card_name = "Volatile Mixture"
	card.description = "Discard: deal 8 damage to enemy. End of turn in hand: 8 self-damage."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 8
	card.base_damage = 8
	card.target_types = ["self"]
	return card

static func create_understanding() -> Card:
	var card = Card.new()
	card.card_id = "understanding"
	card.card_name = "Understanding"
	card.description = "After 2 turn delay, next card auto-crits."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 5
	card.tempo_cost = 1
	card.duration = 2
	card.target_types = ["self"]
	return card

# ============================================
# STEPHEN CARD FACTORY METHODS
# ============================================

static func create_mark() -> Card:
	var card = Card.new()
	card.card_id = "mark"
	card.card_name = "Mark"
	card.description = "Target receives extra damage from your attacks."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 0
	card.is_ranged = true
	card.range_modifier = 7
	card.target_types = ["enemy"]
	return card

static func create_rise() -> Card:
	var card = Card.new()
	card.card_id = "rise"
	card.card_name = "Rise"
	card.description = "Lift the earth creating a structure on the map."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 4
	card.target_types = ["point"]
	return card

static func create_quick_shot() -> Card:
	var card = Card.new()
	card.card_id = "quick_shot"
	card.card_name = "Quick Shot"
	card.description = "Deal X damage, draw a card."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 1
	card.damage = 6
	card.base_damage = 6
	card.is_ranged = true
	card.target_types = ["enemy"]
	return card

static func create_reload() -> Card:
	var card = Card.new()
	card.card_id = "reload"
	card.card_name = "Reload"
	card.description = "Draw 3 cards."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 3
	card.target_types = ["self"]
	return card

static func create_enchanted_quiver() -> Card:
	var card = Card.new()
	card.card_id = "enchanted_quiver"
	card.card_name = "Enchanted Quiver"
	card.description = "Next 3 ranged attacks create a free 0-cost Quick Arrow (4 damage) in your hand."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 5
	card.duration = 3
	card.target_types = ["self"]
	return card

static func create_tighten_string() -> Card:
	var card = Card.new()
	card.card_id = "tighten_string"
	card.card_name = "Tighten String"
	card.description = "Next 3 ranged attacks: +3 tempo cost, +6 damage, +6 range, +20%% crit chance."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 3
	card.duration = 3
	card.target_types = ["self"]
	return card

static func create_down_town() -> Card:
	var card = Card.new()
	card.card_id = "down_town"
	card.card_name = "Down Town"
	card.description = "Shoot a very long range (+7) shot."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 5
	card.damage = 12
	card.base_damage = 12
	card.is_ranged = true
	card.range_modifier = 7
	card.target_types = ["enemy"]
	return card

static func create_barricade() -> Card:
	var card = Card.new()
	card.card_id = "barricade"
	card.card_name = "Barricade"
	card.description = "Create a barricade of land in front of you."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 2
	card.target_types = ["self"]
	return card

static func create_sky_fall() -> Card:
	var card = Card.new()
	card.card_id = "sky_fall"
	card.card_name = "Sky Fall"
	card.description = "Shoot an arrow upward. In 2 turns, it lands at the designated location dealing 18 damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 5
	card.damage = 18
	card.base_damage = 18
	card.duration = 2
	card.is_ranged = true
	card.range_modifier = 4
	card.target_types = ["point"]
	return card

static func create_sky_attack() -> Card:
	var card = Card.new()
	card.card_id = "sky_attack"
	card.card_name = "Sky Attack"
	card.description = "Leap in the air and shoot arrow down. High Ground bonus."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 4
	card.damage = 10
	card.base_damage = 10
	card.is_ranged = true
	card.target_types = ["enemy"]
	return card

static func create_lead_arrow() -> Card:
	var card = Card.new()
	card.card_id = "lead_arrow"
	card.card_name = "Lead Arrow"
	card.description = "1.8x damage. Requires high ground, lower range."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 5
	card.damage = 10
	card.base_damage = 10
	card.is_ranged = true
	card.requires_high_ground = true
	card.target_types = ["enemy"]
	return card

static func create_last_breath() -> Card:
	var card = Card.new()
	card.card_id = "last_breath"
	card.card_name = "Last Breath"
	card.description = "Consume all remaining mana. Deal 3 damage per mana spent."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 5
	card.is_ranged = true
	card.range_modifier = 5
	card.target_types = ["enemy"]
	return card

static func create_mixed_bag() -> Card:
	var card = Card.new()
	card.card_id = "mixed_bag"
	card.card_name = "Mixed Bag"
	card.description = "Shoot a standard arrow."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 1
	card.damage = 7
	card.base_damage = 7
	card.is_ranged = true
	card.range_modifier = 3
	card.target_types = ["enemy"]
	return card

static func create_quick_arrow() -> Card:
	var card = Card.new()
	card.card_id = "quick_arrow"
	card.card_name = "Quick Arrow"
	card.description = "A free ranged attack created by Enchanted Quiver. Deal 4 damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 2
	card.damage = 4
	card.base_damage = 4
	card.is_ranged = true
	card.target_types = ["enemy"]
	return card

# ============================================
# CORY CARD FACTORY METHODS
# ============================================

static func create_round_em_up() -> Card:
	var card = Card.new()
	card.card_id = "round_em_up"
	card.card_name = "Round 'Em Up"
	card.description = "Pick a point. Enemies near it are displaced towards it."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 3
	card.target_types = ["point"]
	card.is_ranged = true
	card.range_modifier = 3
	card.is_aoe = true
	card.aoe_shape = "circle"
	return card

static func create_trip() -> Card:
	var card = Card.new()
	card.card_id = "trip"
	card.card_name = "Trip"
	card.description = "Deal 5 damage. Decrease enemy movement by 4."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 2
	card.tempo_cost = 4
	card.damage = 5
	card.base_damage = 5
	card.target_types = ["enemy"]
	return card

static func create_choke() -> Card:
	var card = Card.new()
	card.card_id = "choke"
	card.card_name = "Choke"
	card.description = "Silence enemy and deal damage per round. Sticky 3."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.sticky = 3
	card.duration = 3
	card.is_ranged = true
	card.target_types = ["enemy"]
	return card

static func create_push() -> Card:
	var card = Card.new()
	card.card_id = "push"
	card.card_name = "Push"
	card.description = "Move a unit away from you X squares."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 1
	card.is_ranged = true
	card.range_modifier = 1
	card.target_types = ["enemy"]
	return card

static func create_defensive_awareness() -> Card:
	var card = Card.new()
	card.card_id = "defensive_awareness"
	card.card_name = "Defensive Awareness"
	card.description = "Gain 3 armor for every enemy within 2 spaces."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 3
	card.tempo_cost = 2
	card.target_types = ["self"]
	return card

static func create_sweeping_disarm() -> Card:
	var card = Card.new()
	card.card_id = "sweeping_disarm"
	card.card_name = "Sweeping Disarm"
	card.description = "Surrounding enemies are disarmed. Deal 3 damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 2
	card.tempo_cost = 5
	card.damage = 3
	card.base_damage = 3
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.target_types = ["all_nearby"]
	return card

static func create_consecutive_snap() -> Card:
	var card = Card.new()
	card.card_id = "consecutive_snap"
	card.card_name = "Consecutive Snap"
	card.description = "3 damage. Each reuse: +9 damage, -1m/-1t cost. Sticky 3."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 3
	card.damage = 3
	card.base_damage = 3
	card.sticky = 3
	card.is_ranged = true
	card.range_modifier = -2
	card.target_types = ["enemy"]
	return card

static func create_swap() -> Card:
	var card = Card.new()
	card.card_id = "swap"
	card.card_name = "Swap"
	card.description = "Switch positions with an enemy or ally."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 3
	card.is_ranged = true
	card.range_modifier = 4
	card.target_types = ["enemy", "ally"]
	return card

static func create_meditate() -> Card:
	var card = Card.new()
	card.card_id = "meditate"
	card.card_name = "Meditate"
	card.description = "Discard hand, draw to full -2, heal to 80%%. Skip next turn."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 6
	card.target_types = ["self"]
	return card

static func create_potion_of_continuance() -> Card:
	var card = Card.new()
	card.card_id = "potion_of_continuance"
	card.card_name = "Potion of Continuance"
	card.description = "Draw 2 cards."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card
