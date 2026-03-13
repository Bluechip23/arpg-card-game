class_name Card
extends Resource

## Card resource that holds card data

enum CardType { ATTACK, DEFENSE, UTILITY, REACTION, UNPLAYABLE, POWER, ENCHANTMENT }
enum CardKeyword { NONE, ARROW, POCKET, GEM, CHISEL, SWIFT, BUCKLER, CROWN, FIST }

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
var aoe_range: float = 1.5  # In world units (grid cells)
var chance_effect_percent: float = 0.0  # For AOE per-enemy rolls
var rng_outcomes: Dictionary = {}  # enemy_id -> bool (for AOE per-enemy indicators)
var rng_roll_tempo: int = 0  # Global tempo when RNG was last rolled
var cycles_in_hand: int = 0  # How many tempo cycles card has been in hand

# RNG outcome system - percentages that appear in the card description
# Each entry: {percent: float} matching a "XX%" in the description
# Binary (1 entry): rolls success/fail for that single percentage
# Multi (2+ entries): weighted random picks which outcome triggers
var rng_outcomes_data: Array = []
var rng_selected_index: int = -1  # -1=not rolled, >=0=which outcome won, -2=binary fail
var sticky: int = 0  # Uses before card auto-discards (0 = normal)
var duration: int = 0  # Effect duration in tempo
var is_ranged: bool = false  # If true, card is ranged (base range 5). If false, melee.
var range_modifier: int = 0  # Modifies base range: +2 = 7 range, -2 = 3 range
var card_range: float = 0.0  # Legacy range for specific overrides
var target_types: Array = ["enemy"]  # "enemy", "ally", "self", "point", "all_nearby"
var consecutive_uses: int = 0  # Track how many times card played in sequence
var requires_high_ground: bool = false  # Needs elevated position
var last_damage_dealt: int = 0  # Used by cards that need main.gd to apply damage (charge, leap)
var has_on_draw: bool = false  # Card triggers an effect when drawn
var on_draw_effect: String = ""  # Description of the on-draw effect
var discard_on_draw: bool = false  # If true, card is discarded immediately after on-draw effect
var maintain_cost: int = 0  # Mana reserved while this card is maintained (Power cards)
var erase_tempo: int = 0  # If > 0, card is deleted from deck after this many tempo (Erase keyword)
var erase_tempo_remaining: int = 0  # Tracks remaining tempo before erase triggers
var linger: bool = false  # If true, status card can exceed hand size limit when added
var reaction_trigger: String = ""  # Trigger condition for reaction cards (e.g., "on_damage_taken")
var card_keyword: CardKeyword = CardKeyword.NONE  # Arrow, Pocket, Gem, Chisel - determines which items can slot this card
var is_chisel: bool = false  # If true, card can only be played when slotted in an item (Chisel keyword)
var has_reach: bool = false  # Reach: adds 1 square to melee attack range
var glut_tempo: int = 0  # Tempo duration the player cannot play cards after using this card
var delay_tempo: int = 0  # Tempo until the card's effect takes place
var has_burden: bool = false  # If true, cost increases by 1m/1t each time played. Can jail to reset.
var burden_plays: int = 0  # How many times this burden card has been played (increases cost)
var burden_jail_duration: int = 30  # Tempo to jail this card to reset burden
var burden_jail_cost_mana: int = 1  # Mana cost to jail a burden card
var burden_jail_cost_tempo: int = 1  # Tempo cost to jail a burden card
var has_on_discard: bool = false  # Card triggers an effect when discarded
var on_discard_effect: String = ""  # Description of the on-discard effect
var in_hand_debuff: String = ""  # Debuff applied while this card is in hand (e.g., "slowed_2")
var in_hand_buff: String = ""  # Buff applied while this card is in hand (Enchantment cards)

# Card-item slot system
enum SlotCompatibility { PICKY, PLIABLE }
var slot_compatibility: SlotCompatibility = SlotCompatibility.PICKY  # Picky = same item type only, Pliable = any item type
var source_item_type: int = -1  # ItemData.ItemType the card was first extracted from (-1 = no restriction yet)
var is_molded: bool = false  # Card is locked into the item and cannot be extracted
var slotted_in_item = null  # Reference to the ItemData this card is slotted in (null = not slotted)

func is_slotted() -> bool:
	return slotted_in_item != null

func get_on_self_bonus() -> Dictionary:
	# Returns the on-self bonus from the item this card is slotted in
	if slotted_in_item and slotted_in_item.has_method("get_on_self_bonus"):
		return slotted_in_item.get_on_self_bonus()
	return {"damage": 0, "block": 0, "heal": 0, "mana_reduction": 0}

func get_slot_keyword() -> String:
	if is_molded:
		return "Molded"
	match slot_compatibility:
		SlotCompatibility.PICKY:
			return "Picky"
		SlotCompatibility.PLIABLE:
			return "Pliable"
	return "Picky"

func roll_rng(enemies: Array = [], chance_boost: float = 0.0) -> void:
	rng_outcomes.clear()

	if rng_outcomes_data.size() == 1:
		# Binary: single percentage, success or fail
		var roll = randf() * 100.0
		var effective_percent = rng_outcomes_data[0].percent + chance_boost
		if roll < effective_percent:
			rng_selected_index = 0  # Success
		else:
			rng_selected_index = -2  # Fail
		print("[CARD] %s RNG: %.0f%% (boosted from %.0f%%) → %s" % [card_name, effective_percent, rng_outcomes_data[0].percent, "SUCCESS" if rng_selected_index == 0 else "FAIL"])
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

func should_reroll_rng(current_tempo: int) -> bool:
	return current_tempo - rng_roll_tempo >= 15

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

## Returns all known game keywords and their descriptions for tooltip display.
static func get_keyword_definitions() -> Dictionary:
	return {
		# Card Types
		"attack": "Offensive cards that deal damage",
		"defense": "Protective cards that grant armor or block",
		"utility": "Support cards for draw, healing, buffs, etc.",
		"power": "Persistent effect cards with a Maintain cost. Reserves mana while active",
		"reaction": "Triggers automatically from hand when a condition is met. Costs 0 mana and 0 tempo",
		"unplayable": "Cannot be played. Takes up a hand slot",
		"enchantment": "Cannot be played. Provides a passive buff while in your hand. Auto-discards after 2 cycles. Effect is lost when the card leaves your hand",
		# Card Mechanics
		"maintain": "Reserves X mana from your max mana pool while active. If mana drops to 0, all maintained cards are discarded",
		"erase": "After X tempo, this card is permanently deleted from the deck",
		"empower": "Buffs the next X cards played: +3 damage for attacks, -3 mana cost for defense",
		"on-draw": "Card triggers an effect when drawn into hand",
		"on-discard": "Card triggers an effect when discarded",
		"in-hand": "Card applies a persistent effect while it remains in your hand",
		"sticky": "Card stays in hand for X uses before being discarded",
		"high ground": "Ranged attacks from elevated positions deal +4 damage and gain +2 range",
		"cycle": "1 cycle = every 5 tempo. Mana regen, card draws, buff/debuff ticks all happen per cycle",
		"glut": "Lose the ability to play cards for X tempo. Players must press the wait button if playing solo",
		"delay": "Tempo until the effect takes place",
		"burden": "Each time played, cost increases by 1m/1t. Jail the card for 30 tempo to reset (costs 1m/1t). Can only jail from hand",
		"instant": "Card triggers automatically from hand when its condition is met. Costs 0 mana",
		"linger": "Enemy status card can exceed hand size limit. While lingering, normal draws trigger overflow",
		"on-self": "Bonus effects that apply to cards slotted in a specific item, on top of the item's base bonuses",
		# Buffs
		"thorns": "Deal X damage back to attackers, lose 1 thorn per hit",
		"focused": "Gain 1 extra mana per cycle",
		"regen": "Heal X HP per cycle, lose 1 regen per cycle",
		"blessed": "Draw X additional card(s) per cycle",
		"fortify": "Armor does not decay",
		"enlightened": "+X% crit chance for next Y attacks",
		"strengthen": "+X damage on next Y attacks",
		"bolster": "+X armor next Y times you gain armor",
		"haste": "+X movement per tempo spent",
		"cleanse": "Remove X negative effects (instant)",
		"smith": "Gain X armor per cycle",
		"steady": "Next action does not add tempo",
		"brace": "Reduce incoming attack damage by X% for Y attacks",
		"resilient": "Reduce all incoming damage by X% for Y tempo",
		"life steal": "Next attack heals you for damage dealt",
		"morphine": "Gain temp HP. Lose it and take 2 damage when expired",
		"wear down": "Each attack reduces target's attack by 1 (stacks) for X tempo",
		"armor break": "Next attack deals double damage to armor only",
		# Debuffs
		"bleed": "On movement: take X damage per tile moved",
		"stun": "Cannot take any actions",
		"disarm": "Cannot play attack cards",
		"silence": "Cannot play spell cards",
		"burn": "Burn damage doubles each cycle (1, 2, 4, 8...)",
		"poison": "Take X damage per cycle, lose 1 poison each cycle",
		"inebriate": "Movement direction is randomized",
		"cursed": "Deal 20% less damage and deal 20% damage to self",
		"frozen": "Cannot play cards",
		"cuffed": "Cannot draw cards",
		"shocked": "Deal X damage to nearby allies per cycle, lose 1 per cycle",
		"slowed": "Lose X movement per cycle",
		"staggered": "Attack cards cost X more mana",
		"drain": "Lose 1 mana per cycle, lose 1 drain per cycle",
		"weighted": "Cards cost X more tempo",
		"hexed": "One random card costs +X mana",
		"locked": "One random card cannot be played",
		"rooted": "Cannot move",
		"tethered": "Cannot move more than X tiles from origin",
		"magnetized": "Pulled X tiles toward nearest enemy each cycle",
		"linked": "Share X% damage taken with nearest ally",
		"clumsy": "X% chance to discard random card when playing",
		"vulnerable": "Take 30% more damage on next X attack(s)",
		"exposed": "Remove 30% more armor when hit",
		"brittle": "Armor decays extra 2 per cycle",
		"cold": "Stacking debuff. At 5 stacks, enemy becomes Frozen",
		# Overflow
		"jailed": "Card goes to jail for 3 turns, cannot be played",
		"manifest": "Card goes to manifest zone as a token. Click to activate",
		"enhance": "Attack cards gain +X bonus damage, then discarded",
		"transferred": "Overflow card is sent to the discard pile",
		"peak": "See the next card on draw pile",
		"overcharge": "Triggers an effect when overflow occurs",
		# Range / AOE
		"melee": "Card must be used at close range",
		"ranged": "Card can be used at distance. Base range = 5 tiles",
		"aoe": "Area of Effect - hits multiple targets in a shape",
		"reach": "Adds 1 square to melee attack range",
		# Card-Item Slots
		"enchant": "Places a card into an item's card slot",
		"extract": "Removes a card from an item's card slot",
		"molded": "Card is locked into the item and cannot be extracted",
		"picky": "Card can only be re-equipped to same item type",
		"pliable": "Card can be re-equipped to any item type",
		# Card Keywords
		"arrow": "Requires a bow/quiver to slot. Ranged bow attack card",
		"pocket": "Small items like daggers and potions. Slots into belts",
		"gem": "Gem cards for rings",
		"chisel": "Card must be slotted in an item to be played. Cannot be played from hand alone",
		"swift": "Agility and movement cards. Slots into boots",
		"buckler": "Defensive technique cards. Slots into shields",
		"crown": "Mental and aura cards. Slots into helmets",
		"fist": "Unarmed combat cards. Slots into gauntlets",
	}

## Scans this card's properties and description for matching keywords.
## Returns an array of {keyword: String, definition: String} dictionaries.
func get_matching_keywords() -> Array:
	var all_keywords = Card.get_keyword_definitions()
	var matches: Array = []
	var found_keys: Dictionary = {}  # Avoid duplicates

	# Build a searchable text from the card
	var search_text = description.to_lower()

	# Also check card type name and properties
	if card_type == CardType.POWER:
		_add_keyword_match(found_keys, matches, all_keywords, "power")
	if card_type == CardType.REACTION:
		_add_keyword_match(found_keys, matches, all_keywords, "reaction")
	if maintain_cost > 0:
		_add_keyword_match(found_keys, matches, all_keywords, "maintain")
	if erase_tempo > 0:
		_add_keyword_match(found_keys, matches, all_keywords, "erase")
	if sticky > 0:
		_add_keyword_match(found_keys, matches, all_keywords, "sticky")
	if has_on_draw:
		_add_keyword_match(found_keys, matches, all_keywords, "on-draw")
	if has_on_discard:
		_add_keyword_match(found_keys, matches, all_keywords, "on-discard")
	if in_hand_debuff != "" or in_hand_buff != "":
		_add_keyword_match(found_keys, matches, all_keywords, "in-hand")
	if card_type == CardType.ENCHANTMENT:
		_add_keyword_match(found_keys, matches, all_keywords, "enchantment")
	if requires_high_ground:
		_add_keyword_match(found_keys, matches, all_keywords, "high ground")
	if is_ranged:
		_add_keyword_match(found_keys, matches, all_keywords, "ranged")
	if is_aoe:
		_add_keyword_match(found_keys, matches, all_keywords, "aoe")
	if glut_tempo > 0:
		_add_keyword_match(found_keys, matches, all_keywords, "glut")
	if delay_tempo > 0:
		_add_keyword_match(found_keys, matches, all_keywords, "delay")
	if has_burden:
		_add_keyword_match(found_keys, matches, all_keywords, "burden")
	if is_chisel:
		_add_keyword_match(found_keys, matches, all_keywords, "chisel")
	if has_reach:
		_add_keyword_match(found_keys, matches, all_keywords, "reach")

	# Scan the description for keyword mentions
	for keyword in all_keywords:
		if keyword in found_keys:
			continue
		# Match whole words to avoid false positives
		var kw_lower = keyword.to_lower()
		var pos = search_text.find(kw_lower)
		while pos >= 0:
			# Check word boundary before
			var before_ok = (pos == 0) or not _is_letter(search_text[pos - 1])
			# Check word boundary after
			var end_pos = pos + kw_lower.length()
			var after_ok = (end_pos >= search_text.length()) or not _is_letter(search_text[end_pos])
			if before_ok and after_ok:
				_add_keyword_match(found_keys, matches, all_keywords, keyword)
				break
			pos = search_text.find(kw_lower, pos + 1)

	return matches

static func _add_keyword_match(found_keys: Dictionary, matches: Array, all_keywords: Dictionary, keyword: String) -> void:
	if keyword not in found_keys:
		found_keys[keyword] = true
		matches.append({"keyword": keyword.capitalize(), "definition": all_keywords[keyword]})

static func _is_letter(c: String) -> bool:
	var code = c.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)

func increment_cycles_in_hand() -> void:
	cycles_in_hand += 1

func reset_hand_tracking() -> void:
	cycles_in_hand = 0
	rng_outcomes.clear()
func execute(target, player_stats: PlayerStats = null, deck_manager = null, damage_reduction_pct: float = 0.0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	last_damage_dealt = 0
	var is_empowered = false
	if player_stats and player_stats.is_empowered():
		is_empowered = player_stats.consume_empower()

	# Apply on-self bonuses from the item this card is slotted in
	var on_self = get_on_self_bonus()
	var on_self_dmg = on_self["damage"]
	var on_self_blk = on_self["block"]
	var on_self_hl = on_self["heal"]
	if on_self_dmg > 0:
		bonus_damage += on_self_dmg
		print("[CARD] On-Self: +%d damage from %s" % [on_self_dmg, slotted_in_item.item_name])
	if on_self_blk > 0:
		block += on_self_blk
		print("[CARD] On-Self: +%d block from %s" % [on_self_blk, slotted_in_item.item_name])
	if on_self_hl > 0:
		heal_amount += on_self_hl
		print("[CARD] On-Self: +%d heal from %s" % [on_self_hl, slotted_in_item.item_name])

	# Apply ranged damage bonus from equipped items (quivers)
	var _ranged_bonus_applied = 0
	if is_ranged and card_type == CardType.ATTACK and player_stats and player_stats.ranged_damage_bonus > 0:
		_ranged_bonus_applied = player_stats.ranged_damage_bonus
		bonus_damage += _ranged_bonus_applied
		print("[CARD] Ranged bonus: +%d damage from equipment" % _ranged_bonus_applied)

	# Wear Down: apply debuff BEFORE attack execution so the first hit stacks reduction
	if card_type == CardType.ATTACK and buff_mgr and buff_mgr.has_wear_down():
		if target and target.has_method("apply_wear_down"):
			target.apply_wear_down(3)
			print("[CARD] Wear Down triggered! Enemy attack will be reduced")

	# Armor Break: flag enemy so take_damage uses armor-only double-damage logic
	var armor_break_consumed = false
	if card_type == CardType.ATTACK and buff_mgr and buff_mgr.has_armor_break():
		if target and target.has_method("set_armor_break_incoming"):
			target.set_armor_break_incoming(true)
			buff_mgr.consume_armor_break()
			armor_break_consumed = true
			print("[CARD] Armor Break! Double damage to armor only")

	match card_id:
		"slash":
			_execute_slash(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
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
			_execute_dagger_throw(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent)
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
		"shuriken_pouch":
			_execute_shuriken_pouch(player_stats)
		"shuriken":
			_execute_shuriken(target, player_stats)
		"premeditated":
			_execute_premeditated(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
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
		"bottomless_quiver":
			_execute_bottomless_quiver(player_stats)
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
		# === New Card Types ===
		"spider_senses":
			_execute_spider_senses(player_stats)
		"thrown_stone":
			_execute_thrown_stone(target, player_stats, buff_mgr)
		"gulped_potion":
			_execute_heal_with_poison_check(target, player_stats, buff_mgr)
		"lightly_dazed":
			pass  # Unplayable card - no execute logic
		"reckless_strike":
			_execute_reckless_strike(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
		# === Power Cards (Maintain) ===
		"halo":
			_execute_halo(player_stats, buff_mgr)
		"armored_discipline":
			_execute_armored_discipline(player_stats, buff_mgr)
		"fountain_of_life":
			_execute_fountain_of_life(player_stats, buff_mgr)
		# === New Cards ===
		"blade_barrage":
			_execute_blade_barrage(target, player_stats, deck_manager, buff_mgr)
		"cultish_wounds":
			_execute_cultish_wounds(player_stats, buff_mgr)
		"self_infliction":
			_execute_self_infliction(player_stats, buff_mgr)
		"bob_and_weave":
			_execute_bob_and_weave(player_stats, deck_manager, buff_mgr)
		"absorb_essence":
			_execute_absorb_essence(player_stats, buff_mgr)
		"energy_ball":
			_execute_energy_ball(target, player_stats, buff_mgr)
		"cover":
			_execute_cover(player_stats, deck_manager)
		"fortify_alliance":
			_execute_fortify_alliance(target, player_stats, buff_mgr)
		"communal_donation":
			_execute_communal_donation(player_stats, buff_mgr)
		"shield_ready":
			_execute_shield_ready(player_stats, buff_mgr)
		"repelled_block":
			_execute_repelled_block(player_stats, buff_mgr)
		"shield_of_growth":
			_execute_shield_of_growth(player_stats, buff_mgr)
		"gift_from_the_phoenix":
			_execute_gift_from_the_phoenix(player_stats, buff_mgr)
		# === New Utility / Defense Cards ===
		"bloodlust":
			_execute_bloodlust(player_stats, buff_mgr)
		"lethal_recall":
			_execute_lethal_recall(target, player_stats, deck_manager, buff_mgr)
		"demonic_rage":
			_execute_demonic_rage(player_stats, buff_mgr)
		"smith_thy_soul":
			_execute_smith_thy_soul(player_stats, buff_mgr)
		"down_but_not_out":
			_execute_down_but_not_out(player_stats, buff_mgr)
		# === New Cards (Weapon Items Update) ===
		"anticipation":
			_execute_anticipation(player_stats, deck_manager)
		"prepare":
			_execute_prepare(deck_manager)
		"meister_of_faustmesser":
			_execute_meister_of_faustmesser(deck_manager)
		"item_mastery":
			_execute_item_mastery(player_stats, deck_manager)
		"mirror_mirror":
			_execute_mirror_mirror(deck_manager)
		"harness_lightning":
			_execute_harness_lightning(player_stats, buff_mgr)
		"deep_pockets":
			_execute_deep_pockets(deck_manager)
		"best_offense":
			_execute_best_offense(player_stats, deck_manager, buff_mgr)
		"vengeful_shield":
			_execute_vengeful_shield(player_stats, buff_mgr)
		# === Jeremy Generated Cards ===
		"mana_surge":
			_execute_mana_surge(target, player_stats, buff_mgr, damage_reduction_pct, self_damage_percent)
		"magic_barrier":
			_execute_magic_barrier(player_stats)
		_:
			print("[CARD] Unknown card: %s" % card_id)

	# Life Steal: if an attack dealt damage and we have life steal buff, heal for damage dealt
	if card_type == CardType.ATTACK and buff_mgr and buff_mgr.has_life_steal():
		var dealt = last_damage_dealt if last_damage_dealt > 0 else damage
		if dealt > 0:
			buff_mgr.consume_life_steal(dealt)

	# Clear armor break flag on target after attack resolves
	if armor_break_consumed and target and target.has_method("set_armor_break_incoming"):
		target.set_armor_break_incoming(false)

	# Apply on-self debuffs (burn/cold from quivers) to target after attack
	if card_type == CardType.ATTACK and target and last_damage_dealt > 0:
		var on_self_burn = on_self.get("apply_burn", 0)
		var on_self_cold = on_self.get("apply_cold", 0)
		var source_name = slotted_in_item.item_name if slotted_in_item else "Equipment"
		if on_self_burn > 0:
			if target.has_method("get_debuff_manager"):
				var target_debuff_mgr = target.get_debuff_manager()
				if target_debuff_mgr:
					var burn = Debuff.create(Debuff.DebuffType.BURN, on_self_burn, 15)
					burn.source_name = source_name
					target_debuff_mgr.apply_debuff(burn)
			elif target.has_method("apply_debuff"):
				target.apply_debuff("burn", on_self_burn)
			print("[CARD] On-Self: Applied %d Burn to target from %s" % [on_self_burn, source_name])
		if on_self_cold > 0:
			if target.has_method("get_debuff_manager"):
				var target_debuff_mgr = target.get_debuff_manager()
				if target_debuff_mgr:
					var cold = Debuff.create(Debuff.DebuffType.COLD, 1, 30)
					cold.source_name = source_name
					target_debuff_mgr.apply_debuff(cold)
			elif target.has_method("apply_debuff"):
				target.apply_debuff("cold", on_self_cold)
			print("[CARD] On-Self: Applied %d Cold to target from %s" % [on_self_cold, source_name])

	# Clean up on-self bonuses so they don't stack permanently
	if on_self_dmg > 0:
		bonus_damage -= on_self_dmg
	if on_self_blk > 0:
		block -= on_self_blk
	if on_self_hl > 0:
		heal_amount -= on_self_hl

	# Clean up ranged bonus
	if _ranged_bonus_applied > 0:
		bonus_damage -= _ranged_bonus_applied

func _execute_gain_mana(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.gain_mana(2)
		print("[CARD] Gained 2 mana!")
		
func _execute_slash(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction_pct: float = 0.0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage

	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)

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

	# Cursed: reduce damage dealt by percentage
	if damage_reduction_pct > 0.0:
		total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))
	
	print("[CARD] %s deals %d damage!" % [card_name, total_damage])
	last_damage_dealt = total_damage

	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)

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
func _execute_dagger_throw(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction_pct: float = 0.0, self_damage_percent: float = 0.0) -> void:
	var total_damage = base_damage + bonus_damage

	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)

	if is_empowered and player_stats:
		total_damage += player_stats.empower_damage_bonus

	# Cursed: reduce damage dealt by percentage
	if damage_reduction_pct > 0.0:
		total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))
	
	print("[CARD] Dagger Throw deals %d damage!" % total_damage)
	
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
	
	if self_damage_percent > 0.0 and player_stats:
		var self_dmg = floori(total_damage * self_damage_percent)
		if self_dmg > 0:
			player_stats.take_damage(self_dmg)
func _execute_block(player_stats: PlayerStats, is_empowered: bool = false, buff_mgr: BuffManager = null) -> void:
	var armor_amount = block

	if is_empowered and player_stats:
		armor_amount = max(1, armor_amount - player_stats.empower_block_reduction)

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

func _execute_blink(_player_node) -> void:
	print("[CARD] Blinked!")

func _execute_heal_with_poison_check(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# General healing logic: if Poison Blood is active and target is an enemy, deal damage instead
	if buff_mgr and buff_mgr.poisoned_blood_active and target and target.has_method("take_damage") and not target.has_method("get_stats"):
		var dmg = heal_amount
		if player_stats:
			dmg = player_stats.get_effective_heal_amount(heal_amount)
		target.take_damage(dmg, true)
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

func jail(dur: int) -> void:
	jail_time_remaining = dur
	print("[CARD] %s jailed for %d tempo" % [card_name, dur])

func get_burden_mana_cost() -> int:
	if has_burden:
		return mana_cost + burden_plays
	return mana_cost

func get_burden_tempo_cost() -> int:
	if has_burden:
		return tempo_cost + burden_plays
	return tempo_cost

func apply_burden() -> void:
	if has_burden:
		burden_plays += 1
		print("[CARD] %s burden increased! Plays: %d (+%dm/+%dt)" % [card_name, burden_plays, burden_plays, burden_plays])

func jail_burden() -> void:
	if has_burden:
		burden_plays = 0
		jail_time_remaining = burden_jail_duration
		print("[CARD] %s burden reset! Jailed for %d tempo" % [card_name, burden_jail_duration])

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
	card.tempo_cost = 1 
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
	card.tempo_cost = 1  
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
	card.target_types = ["self"]
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
	card.tempo_cost = 1
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.is_ranged = true
	card.range_modifier = 3
	card.target_types = ["point"]
	card.heal_amount = 0
	return card

static func create_heal() -> Card:
	var card = Card.new()
	card.card_id = "heal"
	card.card_name = "Heal"
	card.description = "Restore 4 HP."
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
	card.tempo_cost = 1  
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.target_types = ["self"]
	card.heal_amount = 0
	return card

static func create_healing_potion() -> Card:
	var card = Card.new()
	card.card_id = "healing_potion"
	card.card_name = "Healing Potion"
	card.description = "Heal 5. "
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 1
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 5
	card.target_types = ["self"]
	card.card_keyword = CardKeyword.POCKET
	return card

static func create_dagger_throw() -> Card:
	var card = Card.new()
	card.card_id = "dagger_throw"
	card.card_name = "Dagger Throw"
	card.description = "5 damage"
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 1
	card.damage = 5
	card.base_damage = 5
	card.block = 0
	card.base_block = 0
	card.is_ranged = true
	card.target_types = ["enemy"]
	card.heal_amount = 0
	card.card_keyword = CardKeyword.POCKET
	return card

# ============================================
# BRAD CARD EXECUTE FUNCTIONS
# ============================================

func _execute_life_swap(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if not player_stats:
		return
	var old_health = player_stats.current_health
	var old_mana = int(player_stats.current_mana)
	# Swap health and mana pools (never drop HP to 0)
	var new_health = max(1, min(old_mana, player_stats.max_health))
	var new_mana = min(old_health, player_stats.max_mana)
	var life_lost = max(0, old_health - new_health)
	player_stats.current_health = new_health
	player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
	player_stats.current_mana = new_mana
	player_stats.mana_changed.emit(player_stats.current_mana, player_stats.max_mana)
	# Deal damage equal to life lost
	if life_lost > 0 and target and target.has_method("take_damage"):
		target.take_damage(life_lost, true)
	print("[CARD] Life Swap! HP: %d→%d, Mana: %d→%d, dealt %d damage" % [old_health, new_health, old_mana, new_mana, life_lost])

func _execute_wear_down(_target, _player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_wear_down(15, "Wear Down"))
	print("[CARD] Wear Down active! Each attack reduces enemy's attack by 1 for 15 tempo")

func _execute_taunt(_target, _player_stats: PlayerStats) -> void:
	# Taunt effect applied via world effects in main.gd (needs enemy_spawner)
	print("[CARD] Taunt! Nearby enemies must target you for 10 tempo")

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
		target.take_damage(total_damage, true)
	print("[CARD] Poke deals %d damage!" % total_damage)

func _execute_armor_break(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Next attack deals double damage but only affects armor
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_armor_break("Armor Break"))
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
		leap_distance = max(2, player_stats.strength)
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
	# Add 4 temp HP (can exceed max health)
	player_stats.current_health += 4
	player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_morphine(4, 15, "Morphine"))
	print("[CARD] Morphine! Gained 4 temp HP. Will lose it and take 2 damage in 15 tempo")

func _execute_turtle_up(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_fortify(20, "Turtle Up"))
	print("[CARD] Turtle Up! Armor won't decay for 20 tempo")

func _execute_parry(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if player_stats:
		player_stats.add_armor(5)
	var total_damage = 5
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(5)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_brace(30, 1, "Parry"))
	print("[CARD] Parry! Gained 5 armor, dealt %d damage. Next damage reduced" % total_damage)

func _execute_approach(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Slow self for 10 tempo (2 cycles), gain 5 armor per movement taken
	if buff_mgr and buff_mgr.debuff_manager:
		buff_mgr.debuff_manager.apply_debuff(Debuff.create_slowed(2, 10, "Approach"))
	if buff_mgr:
		buff_mgr.approach_armor_per_move = 5
		buff_mgr.approach_tempo_remaining = 10
	print("[CARD] Approach! Slowed for 10 tempo, gain 5 armor per movement")

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
		target.take_damage(total_damage, true)
		last_damage_dealt = total_damage
	# 80% bounce chance, -20% per bounce, each bounce deals 8 damage
	var bounce_chance = 80.0
	var bounces = 0
	while randf() * 100.0 < bounce_chance:
		bounces += 1
		if target and target.has_method("take_damage"):
			target.take_damage(8, true)
			last_damage_dealt += 8
		bounce_chance -= 20.0
		if bounce_chance <= 0:
			break
	print("[CARD] Trick Shot! Dealt %d damage, bounced %d times (8 each)" % [total_damage, bounces])

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
	print("[CARD] Biscuit! Fully healed and +3 damage for 3 attacks")

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
		target.take_damage(total_damage, true)
	# Use pre-rolled RNG: index 0 = +15 damage, index 1 = stun
	if rng_selected_index == 0:
		if target and target.has_method("take_damage"):
			target.take_damage(15, true)
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
			target.take_damage(hit_damage, true)
	print("[CARD] Oops! Hit %d times for %d each (total: %d)" % [hits, hit_damage, hits * hit_damage])

func _execute_house_money(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.chance_boost = 100.0
	print("[CARD] House Money! Next odds will automatically trigger")

func _execute_hope_this_works(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# 50% to heal ally and provide strength for 3 attacks
	if randf() < 0.5:
		if player_stats:
			var heal_amt = max(3, player_stats.intelligence)
			player_stats.heal(heal_amt)
			player_stats.base_strength += 2
			player_stats.recalculate_derived_stats()
		print("[CARD] Hope This Works... it worked! Healed and +STR for 3 attacks")
	else:
		print("[CARD] Hope This Works... it didn't work")

func _execute_lady_luck(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Bless an ally - crit chance +30% for 5 attacks
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_enlightened(30, 5, "Lady Luck"))
	print("[CARD] Lady Luck! Crit chance +30%% for 5 attacks")

func _execute_try_this(target, player_stats: PlayerStats) -> void:
	# Increase ally mana pool by 3 and hand size by 2 for 10 tempo. 10% reverse
	if player_stats:
		if randf() < 0.1:
			player_stats.max_mana = max(1, player_stats.max_mana - 3)
			player_stats.hand_size = max(1, player_stats.hand_size - 2)
			print("[CARD] Try This! Reversed! -3 mana pool, -2 hand size")
		else:
			player_stats.max_mana += 3
			player_stats.hand_size += 2
			print("[CARD] Try This! +3 mana pool, +2 hand size for 10 tempo")

func _execute_if_pigs_could_fly(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = 15
	if player_stats:
		total_damage = player_stats.get_effective_spell_damage(15)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
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
	# +30% healing effectiveness for 15 tempo (3 cycles)
	if player_stats:
		player_stats.healing_boost_percent = 0.3
		player_stats.healing_boost_tempo = 15
	print("[CARD] Raged Circulation! Healing +30%% for 15 tempo")

func buff_mgr_exists(target) -> bool:
	return target and target.has_method("get_buff_manager") and target.get_buff_manager() != null

func _execute_poisoned_blood(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Heal cards now deal damage instead of healing for 15 tempo (3 cycles)
	if buff_mgr:
		buff_mgr.poisoned_blood_active = true
		buff_mgr.poisoned_blood_tempo = 15
	print("[CARD] Poisoned Blood! Heal cards now deal damage instead for 15 tempo")

func _execute_elixir(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Poison cards now heal
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_regen(3, 495, "Elixir"))
	print("[CARD] Elixir! Poison effects now heal instead")

func _execute_shadows(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_invisible(10, "Shadows"))
	print("[CARD] Shadows! Invisible for 10 tempo")

func _execute_preparation(player_stats: PlayerStats, deck_manager = null) -> void:
	if deck_manager:
		deck_manager.prep_utility_discount = 2
		deck_manager.prep_utility_charges = 2
	print("[CARD] Preparation! Next 2 utility cards cost 2 less")

func _execute_exacerbate_wounds(target, player_stats: PlayerStats, deck_manager = null, buff_mgr: BuffManager = null) -> void:
	var discard_count = 0
	if deck_manager:
		discard_count = deck_manager.discards_this_cycle
	var total_damage = discard_count * 2
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
	print("[CARD] Exacerbate Wounds! %d cards discarded this cycle = %d damage" % [discard_count, total_damage])

func _execute_reposition(deck_manager) -> void:
	# Discard a selected card and draw
	if deck_manager:
		if deck_manager.hand.size() > 0:
			var random_index = randi() % deck_manager.hand.size()
			var discarded = deck_manager.hand[random_index]
			deck_manager.hand.remove_at(random_index)
			deck_manager.discard_pile.append(discarded)
			deck_manager.discards_this_cycle += 1
			deck_manager.draw_card()
			deck_manager.hand_updated.emit()
			print("[CARD] Reposition! Discarded %s, drew a new card" % discarded.card_name)

func _execute_volatile_mixture(target, player_stats: PlayerStats) -> void:
	# Playing the card safely removes it from hand (no effect)
	# The real effects are: discard -> damage enemy, end of turn in hand -> self-damage
	print("[CARD] Volatile Mixture played! Safely disposed of")

func _execute_understanding(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Start a 10 tempo countdown; when it expires, next attack auto-crits
	if buff_mgr:
		buff_mgr.understanding_tempo = 10
	print("[CARD] Understanding! In 10 tempo, the next attack will auto-crit")

func _execute_shuriken_pouch(player_stats: PlayerStats) -> void:
	# Signal handled in main.gd: adds MANIFEST overflow effect (shuriken, 3 charges)
	print("[CARD] Shuriken Pouch! Next 3 overflow cards become Shuriken")

func _execute_shuriken(target, player_stats: PlayerStats) -> void:
	# Deals 3 damage to target enemy (ranged, counts as attack)
	var total_damage = 3
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
	last_damage_dealt = total_damage
	print("[CARD] Shuriken! Dealt %d damage" % total_damage)

func _execute_premeditated(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction_pct: float = 0.0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage

	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)

	if is_empowered and player_stats:
		total_damage += player_stats.empower_damage_bonus

	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			print("[CARD] CRITICAL HIT! Damage doubled!")
			buff_mgr.consume_enlightened()

	if damage_reduction_pct > 0.0:
		total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))

	print("[CARD] Premeditated deals %d damage!" % total_damage)
	last_damage_dealt = total_damage

	if target and target.has_method("take_damage"):
		var just_exposed = target.take_damage(total_damage)
		# If this attack broke the enemy's armor, mark them for bonus damage
		if just_exposed and target.has_method("is_alive") and target.is_alive():
			target.bonus_damage_next_hit = 15
			print("[CARD] Premeditated EXPOSED the target! Next attack deals +15 damage!")

	if self_damage_percent > 0.0 and player_stats:
		var self_dmg = floori(total_damage * self_damage_percent)
		if self_dmg > 0:
			player_stats.take_damage(self_dmg)
			print("[CARD] Cursed: took %d self-damage!" % self_dmg)

# ============================================
# STEPHEN CARD EXECUTE FUNCTIONS
# ============================================

func _execute_mark(target, _player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if target and target.has_method("apply_debuff"):
		target.apply_debuff("marked", 25)
	print("[CARD] Mark! Target receives extra damage for 25 tempo")

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
		target.take_damage(total_damage, true)
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
		target.take_damage(total_damage, true)
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
		target.take_damage(total_damage, true)
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
		target.take_damage(total_damage, true)
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
		target.take_damage(total_damage, true)
	print("[CARD] Last Breath! Consumed %d mana for %d damage" % [mana_used, total_damage])

func _execute_mixed_bag(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
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
		target.take_damage(total_damage, true)
	print("[CARD] Quick Arrow! Free arrow for %d damage" % total_damage)

func _execute_bottomless_quiver(_player_stats: PlayerStats) -> void:
	# Signal handled in main.gd: adds QUIVER overflow effect (5 charges)
	print("[CARD] Bottomless Quiver! Next 5 overflow attack cards go to the quiver")

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
		target.take_damage(total_damage, true)
	if target and target.has_method("apply_debuff"):
		target.apply_debuff("slow", 4)  # -4 movement (4 grid spaces)
	print("[CARD] Trip! %d damage, enemy movement -4" % total_damage)

func _execute_choke(target, _player_stats: PlayerStats) -> void:
	if target and target.has_method("apply_debuff"):
		target.apply_debuff("silenced", 3) 
		target.apply_debuff("choke_dot", 3)
	print("[CARD] Choke! Enemy silenced and taking damage per round. Sticky 3")

func _execute_push(target, _player_stats: PlayerStats) -> void:
	print("[CARD] Push! Unit pushed away from you")

func _execute_defensive_awareness(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Armor is applied by main.gd _apply_card_world_effects which has access to enemy positions
	print("[CARD] Defensive Awareness! (armor applied via world effects)")

func _execute_sweeping_disarm(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Store effective damage for main.gd world effects to apply to all nearby enemies
	var total_damage = base_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(base_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	last_damage_dealt = total_damage
	# Actual damage and disarm applied by main.gd _apply_card_world_effects to all nearby enemies
	print("[CARD] Sweeping Disarm! %d damage, surrounding enemies disarmed" % total_damage)

func _execute_consecutive_snap(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# consecutive_uses tracks how many times played so far (incremented by play_card after execute)
	var snap_damage = base_damage + (consecutive_uses * 9)
	if player_stats:
		snap_damage = player_stats.get_effective_physical_damage(snap_damage)
	if buff_mgr:
		snap_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			snap_damage = floori(snap_damage * 2.0)
			buff_mgr.consume_enlightened()
	if target and target.has_method("take_damage"):
		target.take_damage(snap_damage, true)
	# Cost decreases by 1m/1t each use (use consecutive_uses+1 since play_card increments after)
	var next_uses = consecutive_uses + 1
	mana_cost = max(0, 3 - next_uses)
	tempo_cost = max(0, 3 - next_uses)
	if next_uses >= sticky:
		print("[CARD] Consecutive Snap! %d damage (final use #%d)" % [snap_damage, next_uses])
	else:
		print("[CARD] Consecutive Snap! %d damage (use #%d). Next costs %dm/%dt" % [snap_damage, next_uses, mana_cost, tempo_cost])

func _execute_swap(target, _player_stats: PlayerStats) -> void:
	print("[CARD] Swap! Switched positions with target")

func _execute_meditate(player_stats: PlayerStats, deck_manager = null) -> void:
	# Discard hand, draw to full -2, heal to 80%, skip next turn
	if deck_manager:
		while deck_manager.hand.size() > 0:
			var card = deck_manager.hand.pop_back()
			deck_manager.discard_pile.append(card)
			deck_manager.discards_this_cycle += 1
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
	card.description = "Decrease enemy attack by 1 per consecutive hit. Lasts 15 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 1
	card.duration = 15
	card.target_types = ["self"]
	return card

static func create_taunt() -> Card:
	var card = Card.new()
	card.card_id = "taunt"
	card.card_name = "Taunt"
	card.description = "Taunt enemies around you. They must target you."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
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
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
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
	card.card_keyword = CardKeyword.FIST
	return card

static func create_armor_break() -> Card:
	var card = Card.new()
	card.card_id = "armor_break"
	card.card_name = "Armor Break"
	card.description = "Next attack deals double damage to armor only. Does nothing to unarmored enemies."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
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
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 1.5
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
	card.description = "Armor does not decay for 20 tempo."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 3
	card.tempo_cost = 0
	card.duration = 20
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
	card.description = "Slowed for 10 tempo. For each movement taken, gain 5 armor."
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
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
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
	card.description = "Fully heal yourself and gain +3 damage for 3 attacks."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 0
	card.duration = 15
	card.target_types = ["self"]
	return card

static func create_loaded_die() -> Card:
	var card = Card.new()
	card.card_id = "loaded_die"
	card.card_name = "Loaded Die"
	card.description = "Next card with a probability has +10%% higher chance."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.card_keyword = CardKeyword.GEM
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
	card.description = "50%% to heal ally and provide STR for 3 attacks."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 3
	card.rng_outcomes_data = [{percent = 50.0}]
	card.duration = 15
	card.target_types = ["ally"]
	return card

static func create_lady_luck() -> Card:
	var card = Card.new()
	card.card_id = "lady_luck"
	card.card_name = "Lady Luck"
	card.description = "Bless an ally. Crit chance +30%% for 5 attacks."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 1
	card.duration = 10
	card.target_types = ["ally"]
	return card

static func create_try_this() -> Card:
	var card = Card.new()
	card.card_id = "try_this"
	card.card_name = "Try This!"
	card.description = "Ally +3 mana pool, +2 hand size for 10 tempo. 10%% chance reverse."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.rng_outcomes_data = [{percent = 10.0}]
	card.duration = 10
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
	card.aoe_range = 3.0  # 3 grid spaces
	card.target_types = ["point"]
	return card

# ============================================
# RYAN CARD FACTORY METHODS
# ============================================

static func create_raged_circulation() -> Card:
	var card = Card.new()
	card.card_id = "raged_circulation"
	card.card_name = "Raged Circulation"
	card.description = "Target receives 30%% more from healing and regen for 15 tempo."
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
	card.description = "Go invisible for 10 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 4
	card.duration = 10
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
	card.description = "After 10 tempo delay, next card auto-crits."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 5
	card.tempo_cost = 1
	card.duration = 10
	card.target_types = ["self"]
	return card

static func create_shuriken_pouch() -> Card:
	var card = Card.new()
	card.card_id = "shuriken_pouch"
	card.card_name = "Shuriken Pouch"
	card.description = "Manifest 3: Overflow cards become Shuriken. Each Shuriken deals 3 damage to a random enemy (free, ranged, counts as attack)."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 2
	card.target_types = ["self"]
	return card

static func create_shuriken() -> Card:
	var card = Card.new()
	card.card_id = "shuriken"
	card.card_name = "Shuriken"
	card.description = "Deal 3 damage to a random enemy. Free."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 3
	card.base_damage = 3
	card.is_ranged = true
	card.target_types = ["enemy"]
	return card

static func create_premeditated() -> Card:
	var card = Card.new()
	card.card_id = "premeditated"
	card.card_name = "Premeditated"
	card.description = "Deal 8 damage. If this Exposes the enemy, your next attack to that enemy deals 15 damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 2
	card.tempo_cost = 4
	card.damage = 8
	card.base_damage = 8
	card.target_types = ["enemy"]
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
	card.card_keyword = CardKeyword.ARROW
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
	card.card_keyword = CardKeyword.ARROW
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
	card.description = "Shoot an arrow upward. In 10 tempo, it lands at the designated location dealing 18 damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 5
	card.damage = 18
	card.base_damage = 18
	card.duration = 10
	card.is_ranged = true
	card.range_modifier = 4
	card.target_types = ["point"]
	card.card_keyword = CardKeyword.ARROW
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
	card.card_keyword = CardKeyword.ARROW
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
	card.card_keyword = CardKeyword.ARROW
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
	card.card_keyword = CardKeyword.ARROW
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
	card.card_keyword = CardKeyword.ARROW
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
	card.card_keyword = CardKeyword.ARROW
	return card

static func create_bottomless_quiver() -> Card:
	var card = Card.new()
	card.card_id = "bottomless_quiver"
	card.card_name = "Bottomless Quiver"
	card.description = "Manifest 5: Overflow attack cards are stored in the quiver and can be played at full cost. Non-attack overflow cards are discarded."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 4
	card.target_types = ["self"]
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
	card.card_keyword = CardKeyword.FIST
	return card

static func create_choke() -> Card:
	var card = Card.new()
	card.card_id = "choke"
	card.card_name = "Choke"
	card.description = "Silence enemy and deal damage per round."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.sticky = 3
	card.duration = 3
	card.is_ranged = true
	card.target_types = ["enemy"]
	card.card_keyword = CardKeyword.FIST
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
	card.card_keyword = CardKeyword.FIST
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
	card.card_keyword = CardKeyword.FIST
	return card

static func create_consecutive_snap() -> Card:
	var card = Card.new()
	card.card_id = "consecutive_snap"
	card.card_name = "Consecutive Snap"
	card.description = "3 damage. Each reuse: +9 damage, -1m/-1t cost."
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
	card.card_keyword = CardKeyword.FIST
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
	card.description = "Discard hand, draw to full -2, heal to 80%. Skip next turn."
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

# === Reaction / Unplayable / On Draw Cards ===

static func create_spider_senses() -> Card:
	var card = Card.new()
	card.card_id = "spider_senses"
	card.card_name = "Spider Senses"
	card.description = "When you take damage, gain 5 armor."
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 5
	card.base_block = 5
	card.heal_amount = 0
	card.target_types = ["self"]
	card.reaction_trigger = "on_damage_taken"
	return card

static func create_lightly_dazed() -> Card:
	var card = Card.new()
	card.card_id = "lightly_dazed"
	card.card_name = "Lightly Dazed"
	card.description = "This card cannot be played. Linger. Erases from deck after 40 tempo."
	card.card_type = CardType.UNPLAYABLE
	card.card_type_name = "Unplayable"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.erase_tempo = 40
	card.erase_tempo_remaining = 40
	card.linger = true
	card.target_types = ["self"]
	return card

static func create_thrown_stone() -> Card:
	var card = Card.new()
	card.card_id = "thrown_stone"
	card.card_name = "Thrown Stone"
	card.description = "On Draw: Deal 4 damage to a random enemy. Deal 4 damage to an enemy."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 2
	card.tempo_cost = 2
	card.damage = 4
	card.base_damage = 4
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	card.has_on_draw = true
	card.on_draw_effect = "deal_4_random_enemy"
	return card

static func create_gulped_potion() -> Card:
	var card = Card.new()
	card.card_id = "gulped_potion"
	card.card_name = "Gulped Potion"
	card.description = "Heal 1, 3 times. Targets: ally, self."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 1
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 1
	card.sticky = 3
	card.target_types = ["self", "ally"]
	card.card_keyword = CardKeyword.POCKET
	return card

func _execute_spider_senses(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.add_armor(5)
		print("[CARD] Spider Senses! Gained 5 armor")

func _execute_thrown_stone(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			print("[CARD] Thrown Stone CRIT!")
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
		last_damage_dealt = total_damage
		print("[CARD] Thrown Stone dealt %d damage!" % total_damage)

# ============================================
# POWER CARDS (Maintain keyword)
# ============================================

static func create_halo() -> Card:
	var card = Card.new()
	card.card_id = "halo"
	card.card_name = "Halo"
	card.description = "Maintain 3M: Every cycle, heal all allies in AOE for 3 HP"
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 3  # Initial cast cost
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 3
	card.maintain_cost = 3  # 3 mana reserved from max while active
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 3.0
	card.target_types = ["self"]
	return card

func _execute_halo(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Halo's heal-per-cycle effect is handled by the maintain system in DeckManager.
	# On play, we just log activation. The maintained_cards processing does the healing.
	if player_stats:
		print("[CARD] Halo activated! Reserving %d mana. Heals allies in AOE each cycle." % maintain_cost)

static func create_armored_discipline() -> Card:
	var card = Card.new()
	card.card_id = "armored_discipline"
	card.card_name = "Armored Discipline"
	card.description = "Maintain 5M: When you take damage to your health, gain that much armor"
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 3
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.maintain_cost = 5
	card.target_types = ["self"]
	return card

func _execute_armored_discipline(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Armored Discipline's armor-on-HP-damage effect is handled by the maintain system.
	# On play, we just log activation.
	if player_stats:
		print("[CARD] Armored Discipline activated! Reserving %d mana. Gain armor when taking HP damage." % maintain_cost)

# ============================================
# RECKLESS STRIKE
# ============================================

static func create_reckless_strike() -> Card:
	var card = Card.new()
	card.card_id = "reckless_strike"
	card.card_name = "Reckless Strike"
	card.description = "Deal 15 damage. Add 2 Minor Wounds to your deck."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 4
	card.damage = 15
	card.base_damage = 15
	card.target_types = ["enemy"]
	return card

func _execute_reckless_strike(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction_pct: float, self_damage_percent: float, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if is_empowered and player_stats:
		total_damage += player_stats.empower_damage_bonus
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if damage_reduction_pct > 0.0:
		total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))
	last_damage_dealt = total_damage
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
	if self_damage_percent > 0.0 and player_stats:
		var self_dmg = floori(total_damage * self_damage_percent)
		if self_dmg > 0:
			player_stats.take_damage(self_dmg)
	print("[CARD] Reckless Strike! Dealt %d damage" % total_damage)

# NEW CARDS
# ============================================

static func create_blade_barrage() -> Card:
	var card = Card.new()
	card.card_id = "blade_barrage"
	card.card_name = "Blade Barrage"
	card.description = "Deal X*10 damage where X = the number of attack cards in your hand. Glut: 15 tempo."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 4
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	return card

# ============================================
# MINOR WOUNDS (Status card with Erase)
# ============================================

static func create_minor_wounds() -> Card:
	var card = Card.new()
	card.card_id = "minor_wounds"
	card.card_name = "Minor Wounds"
	card.description = "On draw, deal 2 damage to self. Erase: 40"
	card.card_type = CardType.UNPLAYABLE
	card.card_type_name = "Status"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 2
	card.base_damage = 2
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.has_on_draw = true
	card.on_draw_effect = "deal_2_self"
	card.erase_tempo = 40
	card.erase_tempo_remaining = 40
	card.target_types = []
	return card

static func create_energy_barrier() -> Card:
	var card = Card.new()
	card.card_id = "energy_barrier"
	card.card_name = "Energy Barrier"
	card.description = "Gain 5 armor. Erase 1."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 5
	card.base_block = 5
	card.heal_amount = 0
	card.erase_tempo = 1
	card.erase_tempo_remaining = 1
	card.target_types = ["self"]
	return card

# ============================================
# COLLECT ARROWS
# ============================================

static func create_collect_arrows() -> Card:
	var card = Card.new()
	card.card_id = "collect_arrows"
	card.card_name = "Collect Arrows"
	card.description = "Place two attack cards from your discard pile back into your hand."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.glut_tempo = 15
	return card

func _execute_blade_barrage(target, player_stats: PlayerStats, deck_manager, buff_mgr: BuffManager = null) -> void:
	# Count attack cards in hand (deck_manager.hand is accessible)
	var attack_count = 0
	if deck_manager and deck_manager.hand:
		for c in deck_manager.hand:
			if c.card_type == CardType.ATTACK:
				attack_count += 1
	var total_damage = attack_count * 10
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			print("[CARD] Blade Barrage CRIT!")
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
		last_damage_dealt = total_damage
	print("[CARD] Blade Barrage: %d attack cards in hand, dealt %d damage! Glut: 15 tempo" % [attack_count, total_damage])

static func create_cultish_wounds() -> Card:
	var card = Card.new()
	card.card_id = "cultish_wounds"
	card.card_name = "Cultish Wounds"
	card.description = "Maintain 2M: Deal 1 damage to self ignoring armor. Repeat every 5 tempo."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 2
	card.tempo_cost = 2
	card.damage = 1
	card.base_damage = 1
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.maintain_cost = 2
	card.target_types = ["self"]
	return card

func _execute_cultish_wounds(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# On play, deal 1 damage to self ignoring armor and activate maintain.
	# The repeating effect is handled by process_maintained_cards in deck_manager.
	if player_stats:
		player_stats.take_direct_damage(1)
		print("[CARD] Cultish Wounds activated! Took 1 HP damage (ignoring armor). Reserving %dM. Repeats every cycle." % maintain_cost)

static func create_self_infliction() -> Card:
	var card = Card.new()
	card.card_id = "self_infliction"
	card.card_name = "Self Infliction"
	card.description = "Deal 80%% remaining health in damage to self. Gain 5 determination and 5 strength."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

# ============================================
# FOUNTAIN OF LIFE (Power card with Maintain)
# ============================================

static func create_fountain_of_life() -> Card:
	var card = Card.new()
	card.card_id = "fountain_of_life"
	card.card_name = "Fountain of Life"
	card.description = "Maintain 3M: Every cycle, deal 2 damage to self and draw a card."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.damage = 2
	card.base_damage = 2
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.maintain_cost = 3
	card.target_types = ["self"]
	return card

func _execute_fountain_of_life(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Fountain of Life's per-cycle effect is handled by process_maintained_cards in DeckManager.
	# On play, we just log activation.
	if player_stats:
		print("[CARD] Fountain of Life activated! Reserving %d mana. Deal 2 damage to self and draw a card each cycle." % maintain_cost)
func _execute_self_infliction(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if player_stats:
		var self_damage = floori(player_stats.current_health * 0.8)
		player_stats.take_direct_damage(self_damage)
		player_stats.determination += 5
		player_stats.strength += 5
		print("[CARD] Self Infliction: dealt %d damage to self (80%% of %d HP). Gained +5 DET, +5 STR" % [self_damage, player_stats.current_health + self_damage])

static func create_bob_and_weave() -> Card:
	var card = Card.new()
	card.card_id = "bob_and_weave"
	card.card_name = "Bob and Weave"
	card.description = "Gain 5 armor and draw a card."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 2
	card.tempo_cost = 1
	card.damage = 0
	card.base_damage = 0
	card.block = 5
	card.base_block = 5
	card.heal_amount = 0
	card.target_types = ["self"]
	card.card_keyword = CardKeyword.FIST
	return card

func _execute_bob_and_weave(player_stats: PlayerStats, deck_manager, buff_mgr: BuffManager = null) -> void:
	if player_stats:
		player_stats.add_armor(base_block)
		print("[CARD] Bob and Weave: gained %d armor" % base_block)
	if deck_manager and deck_manager.has_method("draw_card"):
		deck_manager.draw_card()
		print("[CARD] Bob and Weave: drew a card")

static func create_absorb_essence() -> Card:
	var card = Card.new()
	card.card_id = "absorb_essence"
	card.card_name = "Absorb Essence"
	card.description = "Deal 1 damage to ALL things on the battlefield. Delay: 10 tempo, obtain Energy Ball."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 5
	card.tempo_cost = 5
	card.damage = 1
	card.base_damage = 1
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["all_nearby"]
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 100.0
	card.delay_tempo = 10
	return card

func _execute_absorb_essence(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# The AOE damage to all things is handled in main.gd _apply_card_world_effects.
	# Energy Ball creation after 10 tempo delay is also handled in main.gd.
	print("[CARD] Absorb Essence activated! Dealing 1 damage to ALL things. Energy Ball in 10 tempo.")

static func create_energy_ball() -> Card:
	var card = Card.new()
	card.card_id = "energy_ball"
	card.card_name = "Energy Ball"
	card.description = "Deal X damage where X = total damage done by Absorb Essence. Erased after use."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 1
	card.tempo_cost = 1
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.range_modifier = 5
	card.target_types = ["enemy"]
	card.erase_tempo = 1
	card.erase_tempo_remaining = 1
	return card

func _execute_energy_ball(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Damage is set dynamically when Energy Ball is created (based on Absorb Essence hits)
	var total_damage = damage
	if player_stats:
		total_damage = player_stats.get_effective_spell_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			print("[CARD] Energy Ball CRIT!")
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
		last_damage_dealt = total_damage
	print("[CARD] Energy Ball dealt %d damage (from Absorb Essence)!" % total_damage)

static func create_cover() -> Card:
	var card = Card.new()
	card.card_id = "cover"
	card.card_name = "Cover"
	card.description = "Instant: When an ally within 2 spaces takes damage, reduce it by the number of cards in your hand."
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	card.mana_cost = 0
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["ally"]
	card.reaction_trigger = "on_ally_damage_taken"
	return card

func _execute_cover(player_stats: PlayerStats, deck_manager = null) -> void:
	# Cover's damage reduction is calculated based on hand size at time of trigger.
	# The actual interception is handled in main.gd.
	var hand_size = 0
	if deck_manager:
		hand_size = deck_manager.hand.size()
	print("[CARD] Cover triggered! Reducing ally damage by %d (cards in hand)" % hand_size)

static func create_fortify_alliance() -> Card:
	var card = Card.new()
	card.card_id = "fortify_alliance"
	card.card_name = "Fortify Alliance"
	card.description = "Heal an ally for 5 and give yourself 5 armor."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 2
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.block = 5
	card.base_block = 5
	card.heal_amount = 5
	card.is_ranged = true
	card.range_modifier = 2
	card.target_types = ["ally"]
	return card

func _execute_fortify_alliance(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if target and target.has_method("get_stats"):
		var ally_stats = target.get_stats()
		if ally_stats:
			ally_stats.heal(heal_amount)
			print("[CARD] Fortify Alliance: healed ally for %d" % heal_amount)
	elif target and target.has_method("heal"):
		target.heal(heal_amount)
		print("[CARD] Fortify Alliance: healed ally for %d" % heal_amount)
	if player_stats:
		player_stats.add_armor(base_block)
		print("[CARD] Fortify Alliance: gained %d armor" % base_block)

static func create_communal_donation() -> Card:
	var card = Card.new()
	card.card_id = "communal_donation"
	card.card_name = "Communal Donation"
	card.description = "Deal damage to yourself and heal allies based on the damage done. Choose amount and allocation."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

func _execute_communal_donation(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# The actual self-damage amount and ally healing allocation is handled in main.gd
	# via a UI prompt where the player enters damage amount and distributes healing.
	print("[CARD] Communal Donation activated! Player will choose self-damage and ally healing allocation.")

# ============================================
# SHIELD READY
# ============================================
static func create_shield_ready() -> Card:
	var card = Card.new()
	card.card_id = "shield_ready"
	card.card_name = "Shield Ready"
	card.description = "Gain 5 armor. In 5 tempo, gain 5 more armor."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 2
	card.tempo_cost = 4
	card.block = 5
	card.base_block = 5
	card.delay_tempo = 5
	card.target_types = ["self"]
	return card

func _execute_shield_ready(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if player_stats:
		player_stats.add_armor(base_block)
		print("[CARD] Shield Ready: gained %d armor now" % base_block)
	# Delayed: buff that grants 5 more armor after 5 tempo (handled by main.gd tick)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_shield_ready(5, 5, "Shield Ready"))
		print("[CARD] Shield Ready: will gain 5 more armor in 5 tempo")

# ============================================
# REPELLED BLOCK
# ============================================
static func create_repelled_block() -> Card:
	var card = Card.new()
	card.card_id = "repelled_block"
	card.card_name = "Repelled Block"
	card.description = "Gain 5 armor. If the enemy's next melee attack is fully blocked by your armor, take 0 damage, push the enemy back 4 spaces, and push yourself back 2 spaces. If your armor is reduced to 0, take the damage."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 3
	card.tempo_cost = 3
	card.block = 5
	card.base_block = 5
	card.target_types = ["self"]
	return card

func _execute_repelled_block(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if player_stats:
		player_stats.add_armor(base_block)
		print("[CARD] Repelled Block: gained %d armor" % base_block)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_repelled_block("Repelled Block"))
		print("[CARD] Repelled Block: next melee attack fully blocked pushes enemy 4 + self back 2")

# ============================================
# SHIELD OF GROWTH
# ============================================
static func create_shield_of_growth() -> Card:
	var card = Card.new()
	card.card_id = "shield_of_growth"
	card.card_name = "Shield of Growth"
	card.description = "For the next 10 tempo, all damage done to you increases your armor count. Disarms self for the duration."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 4
	card.tempo_cost = 5
	card.duration = 10
	card.target_types = ["self"]
	return card

func _execute_shield_of_growth(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_shield_of_growth(10, "Shield of Growth"))
		if buff_mgr.debuff_manager:
			var disarm = Debuff.create(Debuff.DebuffType.DISARM, 0, 10)
			disarm.source_name = "Shield of Growth"
			buff_mgr.debuff_manager.apply_debuff(disarm)
		print("[CARD] Shield of Growth: all damage taken increases armor for 10 tempo. Disarmed for 10 tempo.")

# ============================================
# GIFT FROM THE PHOENIX
# ============================================
static func create_gift_from_the_phoenix() -> Card:
	var card = Card.new()
	card.card_id = "gift_from_the_phoenix"
	card.card_name = "Gift from the Phoenix"
	card.description = "Instant: When your life drops below 50%%, heal up to 80%% and apply 5 burn to the nearest enemy."
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.reaction_trigger = "on_hp_below_50"
	card.target_types = ["self"]
	return card

func _execute_gift_from_the_phoenix(_player_stats: PlayerStats, _buff_mgr: BuffManager = null) -> void:
	# Instant/Reaction card - effect is handled by main.gd when HP drops below 50%
	# This function is kept for the execute dispatch but does nothing on manual play
	print("[CARD] Gift from the Phoenix is an instant card - triggers automatically from hand")

# ============================================
# NEW UTILITY / DEFENSE CARD EXECUTE FUNCTIONS
# ============================================

func _execute_bloodlust(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Apply 3 Vulnerable to self
	if buff_mgr and buff_mgr.debuff_manager:
		var vulnerable = Debuff.create(Debuff.DebuffType.VULNERABLE, 3, -1)
		vulnerable.source_name = "Bloodlust"
		buff_mgr.debuff_manager.apply_debuff(vulnerable)
		print("[CARD] Bloodlust: Applied 3 Vulnerable to self")
	# Gain 3 mana
	if player_stats:
		player_stats.gain_mana(3)
		print("[CARD] Bloodlust: Gained 3 mana")
	# Gain 3 Strengthen for 20 tempo (applied as attacks-based buff)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_strengthen(3, 3, "Bloodlust"))
		print("[CARD] Bloodlust: Gained 3 Strengthen")

func _execute_lethal_recall(_target, _player_stats: PlayerStats, _deck_manager = null, _buff_mgr: BuffManager = null) -> void:
	# Trigger last instant card's effect 2 times
	# The actual replay logic requires access to the last played card history in main.gd
	# This is dispatched here but the replay is handled by main.gd post-execute
	print("[CARD] Lethal Recall: Triggering last instant card's effect 2 times (handled by main.gd)")

func _execute_demonic_rage(_player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Your next 5 uses of mana use health instead
	# This applies a buff that main.gd checks when spending mana
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_demonic_rage(5, "Demonic Rage"))
		print("[CARD] Demonic Rage: Next 5 mana costs use health instead")

func _execute_smith_thy_soul(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Gain armor equal to half the sum of your health and mana
	if player_stats:
		var total = player_stats.current_health + int(player_stats.current_mana)
		var armor_gain = total / 2
		player_stats.add_armor_with_bolster(armor_gain, buff_mgr)
		print("[CARD] Smith thy Soul: HP(%d) + Mana(%d) = %d, gained %d armor" % [player_stats.current_health, int(player_stats.current_mana), total, armor_gain])

func _execute_down_but_not_out(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Heal 1 health for each stack of debuff on your character
	var total_stacks = 0
	if buff_mgr and buff_mgr.debuff_manager:
		for debuff in buff_mgr.debuff_manager.debuffs:
			total_stacks += debuff.stacks
	if player_stats and total_stacks > 0:
		player_stats.heal(total_stacks)
		print("[CARD] Down but not out: %d debuff stacks, healed %d HP" % [total_stacks, total_stacks])
	else:
		print("[CARD] Down but not out: No debuff stacks, no healing")

# ============================================
# NEW CARD EXECUTE FUNCTIONS (Weapon Items Update)
# ============================================

func _execute_anticipation(player_stats: PlayerStats, deck_manager = null) -> void:
	# Gain 1 mana, shuffle a Prepare into the deck
	if player_stats:
		player_stats.gain_mana(1)
		print("[CARD] Anticipation: Gained 1 mana")
	if deck_manager and deck_manager.has_method("shuffle_card_into_deck"):
		var prepare_card = Card.create_prepare()
		deck_manager.shuffle_card_into_deck(prepare_card)
		print("[CARD] Anticipation: Shuffled Prepare into deck")
	elif deck_manager and deck_manager.has_method("add_card_to_deck"):
		var prepare_card = Card.create_prepare()
		deck_manager.add_card_to_deck(prepare_card)
		print("[CARD] Anticipation: Added Prepare to deck")

func _execute_prepare(deck_manager = null) -> void:
	# Draw 3 cards
	if deck_manager and deck_manager.has_method("draw_cards"):
		deck_manager.draw_cards(3)
		print("[CARD] Prepare: Drew 3 cards")
	elif deck_manager and deck_manager.has_method("draw_card"):
		for i in range(3):
			deck_manager.draw_card()
		print("[CARD] Prepare: Drew 3 cards")

func _execute_meister_of_faustmesser(deck_manager = null) -> void:
	# Put all zero mana cost cards from discard pile into hand
	if deck_manager and deck_manager.has_method("get_discard_pile"):
		var discard = deck_manager.get_discard_pile()
		var zero_cost_cards: Array = []
		for card in discard:
			if card.mana_cost == 0:
				zero_cost_cards.append(card)
		for card in zero_cost_cards:
			if deck_manager.has_method("move_from_discard_to_hand"):
				deck_manager.move_from_discard_to_hand(card)
		print("[CARD] Meister of Faustmesser: Moved %d zero-cost cards from discard to hand" % zero_cost_cards.size())

func _execute_item_mastery(player_stats: PlayerStats, deck_manager = null) -> void:
	# Place all cards from items into hand - handled by main.gd
	print("[CARD] Item Mastery: Requesting all item cards be placed into hand")

func _execute_mirror_mirror(deck_manager = null) -> void:
	# Duplicate a card in hand with Erase: 5 - selection handled by main.gd
	print("[CARD] Mirror Mirror: Requesting card duplication with Erase: 5")

func _execute_harness_lightning(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Create lightning orb effect - handled by main.gd
	print("[CARD] Harness Lightning: Creating lightning orb (4 dmg / 5 tempo / 3 range / 30 tempo duration)")

func _execute_deep_pockets(deck_manager = null) -> void:
	# Draw cards until one costs more than 0 mana
	if deck_manager and deck_manager.has_method("draw_card"):
		var max_draws = 20  # Safety limit
		var draws = 0
		while draws < max_draws:
			var drawn = null
			if deck_manager.has_method("draw_card_and_return"):
				drawn = deck_manager.draw_card_and_return()
			else:
				deck_manager.draw_card()
				draws += 1
				break
			draws += 1
			if drawn and drawn.mana_cost > 0:
				break
		print("[CARD] Deep Pockets: Drew %d card(s)" % draws)

func _execute_best_offense(player_stats: PlayerStats, deck_manager = null, buff_mgr: BuffManager = null) -> void:
	# Gain 3 smith for 25 tempo, or 6 smith if holding no attack cards
	var smith_amount = 3
	if deck_manager and deck_manager.has_method("get_hand"):
		var hand = deck_manager.get_hand()
		var has_attack = false
		for card in hand:
			if card.card_type == CardType.ATTACK:
				has_attack = true
				break
		if not has_attack:
			smith_amount = 6
			print("[CARD] Best Offense: No attack cards in hand! Gaining 6 Smith instead of 3")
	if buff_mgr:
		var smith_buff = Buff.create_smith(smith_amount, 25, "Best Offense")
		buff_mgr.apply_buff(smith_buff)
		print("[CARD] Best Offense: Gained %d Smith for 25 tempo" % smith_amount)

func _execute_vengeful_shield(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Reaction: stun enemy + gain 5 armor - stun is handled by main.gd
	if player_stats:
		player_stats.gain_armor(5)
		print("[CARD] Vengeful Shield: Gained 5 armor")

# ============================================
# JEREMY GENERATED CARDS
# ============================================

func _execute_mana_surge(target, player_stats: PlayerStats, buff_mgr: BuffManager = null, damage_reduction_pct: float = 0.0, self_damage_percent: float = 0.0) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = floori(total_damage * 2.0)
			buff_mgr.consume_enlightened()
	if damage_reduction_pct > 0:
		total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true)
		last_damage_dealt = total_damage
	# Gain 1 mana
	if player_stats:
		player_stats.gain_mana(1)
	print("[CARD] Mana Surge: %d damage, +1 mana!" % total_damage)

func _execute_magic_barrier(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.add_armor(8)
	print("[CARD] Magic Barrier: +8 armor!")

static func create_mana_surge() -> Card:
	var card = Card.new()
	card.card_id = "mana_surge"
	card.card_name = "Mana Surge"
	card.description = "Deal 5 damage, gain 1 mana."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 2
	card.damage = 5
	card.base_damage = 5
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.erase_tempo = 1
	card.erase_tempo_remaining = 1
	card.target_types = ["enemy"]
	return card

static func create_magic_barrier() -> Card:
	var card = Card.new()
	card.card_id = "magic_barrier"
	card.card_name = "Magic Barrier"
	card.description = "Gain 8 armor. Instant."
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 8
	card.base_block = 8
	card.heal_amount = 0
	card.erase_tempo = 1
	card.erase_tempo_remaining = 1
	card.reaction_trigger = "on_damage_taken"
	card.target_types = ["self"]
	return card

# ============================================
# PETEY THE PET ROCK
# ============================================

static func create_petey_the_pet_rock() -> Card:
	var card = Card.new()
	card.card_id = "petey_the_pet_rock"
	card.card_name = "Petey the Pet Rock"
	card.description = "On Draw: Draw 3 cards. On Discard: Discard 2 cards. While in hand: Slowed 2."
	card.card_type = CardType.UNPLAYABLE
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.has_on_draw = true
	card.on_draw_effect = "draw_3_cards"
	card.has_on_discard = true
	card.on_discard_effect = "discard_2_cards"
	card.in_hand_debuff = "slowed_2"
	card.target_types = []
	return card

# ============================================
# ARMOR PATCH
# ============================================

static func create_armor_patch() -> Card:
	var card = Card.new()
	card.card_id = "armor_patch"
	card.card_name = "Armor Patch"
	card.description = "On Draw: Gain 3 armor, Cleanse 1. Immediately discarded."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 3
	card.base_block = 3
	card.heal_amount = 0
	card.has_on_draw = true
	card.on_draw_effect = "gain_3_armor_cleanse_1"
	card.discard_on_draw = true
	card.target_types = []
	return card

# ============================================
# NEW UTILITY / DEFENSE CARDS
# ============================================

static func create_bloodlust() -> Card:
	var card = Card.new()
	card.card_id = "bloodlust"
	card.card_name = "Bloodlust"
	card.description = "Apply 3 Vulnerable to self. Gain 3 mana. Gain 3 Strengthen for 20 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_lethal_recall() -> Card:
	var card = Card.new()
	card.card_id = "lethal_recall"
	card.card_name = "Lethal Recall"
	card.description = "Trigger your last instant card's effect 2 times."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_demonic_rage() -> Card:
	var card = Card.new()
	card.card_id = "demonic_rage"
	card.card_name = "Demonic Rage"
	card.description = "Your next 5 uses of mana use health instead."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 5
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_smith_thy_soul() -> Card:
	var card = Card.new()
	card.card_id = "smith_thy_soul"
	card.card_name = "Smith thy Soul"
	card.description = "Gain armor equal to half the sum of your health and mana."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 1
	card.tempo_cost = 6
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_down_but_not_out() -> Card:
	var card = Card.new()
	card.card_id = "down_but_not_out"
	card.card_name = "Down but not out"
	card.description = "Heal 1 health for each stack of debuff on your character."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 5
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

# ============================================
# ENCHANTMENT CARDS
# ============================================

static func create_enchantment_defense() -> Card:
	var card = Card.new()
	card.card_id = "enchantment_defense"
	card.card_name = "Enchantment: Defense"
	card.description = "Gain +3 block from cards and effects while this is in your hand. Discards after 2 cycles."
	card.card_type = CardType.ENCHANTMENT
	card.card_type_name = "Enchantment"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.in_hand_buff = "block_3"
	card.target_types = []
	return card

static func create_enchantment_attack() -> Card:
	var card = Card.new()
	card.card_id = "enchantment_attack"
	card.card_name = "Enchantment: Attack"
	card.description = "Cards deal +3 damage while this is in your hand. Discards after 2 cycles."
	card.card_type = CardType.ENCHANTMENT
	card.card_type_name = "Enchantment"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.in_hand_buff = "damage_3"
	card.target_types = []
	return card

static func create_enchantment_movement() -> Card:
	var card = Card.new()
	card.card_id = "enchantment_movement"
	card.card_name = "Enchantment: Movement"
	card.description = "Gain +1 movement per Tempo while this is in your hand. Discards after 2 cycles."
	card.card_type = CardType.ENCHANTMENT
	card.card_type_name = "Enchantment"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.in_hand_buff = "movement_1"
	card.target_types = []
	return card

static func create_enchantment_mana_regen() -> Card:
	var card = Card.new()
	card.card_id = "enchantment_mana_regen"
	card.card_name = "Enchantment: Mana Regen"
	card.description = "Gain +1 mana regen while this is in your hand. Discards after 2 cycles."
	card.card_type = CardType.ENCHANTMENT
	card.card_type_name = "Enchantment"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.in_hand_buff = "mana_regen_1"
	card.target_types = []
	return card

static func create_healthy_habit() -> Card:
	var card = Card.new()
	card.card_id = "healthy_habit"
	card.card_name = "Healthy Habit"
	card.description = "Draw 2 cards. Gain 2 mana. Burden."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 2
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.has_burden = true
	card.target_types = ["self"]
	return card

# ============================================
# NEW UTILITY / DEFENSE / REACTION CARDS
# ============================================

static func create_anticipation() -> Card:
	var card = Card.new()
	card.card_id = "anticipation"
	card.card_name = "Anticipation"
	card.description = "Gain 1 mana. Shuffle a Prepare into your deck."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_prepare() -> Card:
	var card = Card.new()
	card.card_id = "prepare"
	card.card_name = "Prepare"
	card.description = "Draw 3 cards. Erase: 1"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.erase_tempo = 1
	card.erase_tempo_remaining = 1
	card.target_types = ["self"]
	return card

static func create_meister_of_faustmesser() -> Card:
	var card = Card.new()
	card.card_id = "meister_of_faustmesser"
	card.card_name = "Meister of Faustmesser"
	card.description = "Put all zero mana cost cards from discard pile into your hand."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_item_mastery() -> Card:
	var card = Card.new()
	card.card_id = "item_mastery"
	card.card_name = "Item Mastery"
	card.description = "Place all your cards from items, or slotted in an item, into your hand."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 5
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_mirror_mirror() -> Card:
	var card = Card.new()
	card.card_id = "mirror_mirror"
	card.card_name = "Mirror Mirror"
	card.description = "Duplicate a card in your hand. The duplicate has Erase: 5."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_harness_lightning() -> Card:
	var card = Card.new()
	card.card_id = "harness_lightning"
	card.card_name = "Harness Lightning"
	card.description = "Create an orb of lightning that circles you. Deals 4 damage every 5 tempo to a random enemy within 3 spaces. Lasts 30 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 3
	card.tempo_cost = 4
	card.damage = 4
	card.base_damage = 4
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.duration = 30
	card.target_types = ["self"]
	return card

static func create_deep_pockets() -> Card:
	var card = Card.new()
	card.card_id = "deep_pockets"
	card.card_name = "Deep Pockets"
	card.description = "Draw a card. Draw again until a card has a mana cost more than 0."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 4
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_best_offense() -> Card:
	var card = Card.new()
	card.card_id = "best_offense"
	card.card_name = "Best Offense is a Good Defense"
	card.description = "Gain 3 Smith for 25 tempo. If holding no attack cards, gain 6 Smith instead."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 4
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_vengeful_shield() -> Card:
	var card = Card.new()
	card.card_id = "vengeful_shield"
	card.card_name = "Vengeful Shield"
	card.description = "When taking damage that exposes the player, stun an enemy within melee range and gain 5 armor."
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 5
	card.base_block = 5
	card.heal_amount = 0
	card.reaction_trigger = "on_exposed"
	card.target_types = ["self"]
	return card
