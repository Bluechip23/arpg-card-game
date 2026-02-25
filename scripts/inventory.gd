class_name Inventory
extends Node

## Manages character equipment slots and inventory

signal equipment_changed
signal item_equipped(item: ItemData, slot_type: String, slot_index: int)
signal item_unequipped(item: ItemData, slot_type: String, slot_index: int)
signal overflow_heal_armor_triggered(heal: int, armor: int)
signal ring_triggered(item: ItemData, effect: String)
signal gauntlet_skill_ready(item: ItemData)

# Slot configuration
var helm_slots: int = 1
var chest_slots: int = 1
var ring_slots: int = 2
var belt_slots: int = 1
var boots_slots: int = 1
var gauntlets_slots: int = 1
var weapon_slots: int = 2

# Special modifiers
var chest_weight_reduction: float = 0.0  # Brad
var belt_card_mana_reduction: int = 0     # Ryan
var ring_double_trigger: bool = false     # Jeremy
var off_hand_bonus: float = 0.0           # Stephen (+10%), others get -10% penalty
var gauntlet_cooldown_mana: bool = false  # Cory

# Default off-hand penalty
const DEFAULT_OFF_HAND_PENALTY: float = 0.9  # -10%

var character_name: String = ""

# Equipped items
var equipped_helms: Array[ItemData] = []
var equipped_chests: Array[ItemData] = []
var equipped_rings: Array[ItemData] = []
var equipped_belts: Array[ItemData] = []
var equipped_boots: Array[ItemData] = []
var equipped_gauntlets: Array[ItemData] = []
var equipped_weapons: Array[ItemData] = []

# Ring trigger tracking
var ring_triggered_this_turn: bool = false
var armor_gained_this_turn: int = 0

# Prevents infinite loop when granting armor-on-armor-gain bonuses
var _applying_armor_instance_bonus: bool = false

# References
var player_stats = null  # PlayerStats - untyped to avoid circular dependency
var deck_manager = null  # DeckManager - untyped to avoid circular dependency

func initialize(char_name: String) -> void:
	character_name = char_name
	
	match character_name:
		"Ryan":
			helm_slots = 1
			chest_slots = 1
			ring_slots = 2
			belt_slots = 4
			boots_slots = 1
			gauntlets_slots = 1
			weapon_slots = 2
			chest_weight_reduction = 0.0
			belt_card_mana_reduction = 1
			ring_double_trigger = false
			off_hand_bonus = 0.0
			gauntlet_cooldown_mana = false
		"Brad":
			helm_slots = 1
			chest_slots = 1
			ring_slots = 2
			belt_slots = 1
			boots_slots = 1
			gauntlets_slots = 1
			weapon_slots = 8
			chest_weight_reduction = 0.15
			belt_card_mana_reduction = 0
			ring_double_trigger = false
			off_hand_bonus = 0.0
			gauntlet_cooldown_mana = false
		"Jeremy":
			helm_slots = 1
			chest_slots = 1
			ring_slots = 4
			belt_slots = 2
			boots_slots = 1
			gauntlets_slots = 1
			weapon_slots = 2
			chest_weight_reduction = 0.0
			belt_card_mana_reduction = 0
			ring_double_trigger = true  # Jeremy's passive
			off_hand_bonus = 0.0
			gauntlet_cooldown_mana = false
		"Stephen":
			helm_slots = 1
			chest_slots = 1
			ring_slots = 3
			belt_slots = 1
			boots_slots = 1
			gauntlets_slots = 1
			weapon_slots = 4
			chest_weight_reduction = 0.0
			belt_card_mana_reduction = 0
			ring_double_trigger = false
			off_hand_bonus = 0.2  # +10% instead of -10% = +20% total swing
			gauntlet_cooldown_mana = false
		"Cory":
			helm_slots = 1
			chest_slots = 1
			ring_slots = 2
			belt_slots = 1
			boots_slots = 1
			gauntlets_slots = 2
			weapon_slots = 2
			chest_weight_reduction = 0.0
			belt_card_mana_reduction = 0
			ring_double_trigger = false
			off_hand_bonus = 0.0
			gauntlet_cooldown_mana = true  # Cory's passive
	
	_init_slot_arrays()
	
	print("[INVENTORY] Initialized for %s" % character_name)
	_print_passives()

func _print_passives() -> void:
	if belt_card_mana_reduction > 0:
		print("[INVENTORY] Passive: Belt cards cost %d less mana" % belt_card_mana_reduction)
	if chest_weight_reduction > 0:
		print("[INVENTORY] Passive: Chest items weigh %.0f%% less" % (chest_weight_reduction * 100))
	if ring_double_trigger:
		print("[INVENTORY] Passive: First ring trigger per turn triggers twice")
	if off_hand_bonus > 0:
		print("[INVENTORY] Passive: +%.0f%% off-hand bonuses" % (off_hand_bonus * 100))
	if gauntlet_cooldown_mana:
		print("[INVENTORY] Passive: Gain 1 mana when gauntlet skill comes off cooldown")

func _init_slot_arrays() -> void:
	equipped_helms.clear()
	equipped_chests.clear()
	equipped_rings.clear()
	equipped_belts.clear()
	equipped_boots.clear()
	equipped_gauntlets.clear()
	equipped_weapons.clear()
	
	equipped_helms.resize(helm_slots)
	equipped_chests.resize(chest_slots)
	equipped_rings.resize(ring_slots)
	equipped_belts.resize(belt_slots)
	equipped_boots.resize(boots_slots)
	equipped_gauntlets.resize(gauntlets_slots)
	equipped_weapons.resize(weapon_slots)

func connect_player_stats(stats) -> void:
	player_stats = stats
	stats.inventory = self

func connect_deck_manager(deck) -> void:
	deck_manager = deck

func get_off_hand_modifier() -> float:
	# Stephen gets bonus, others get penalty
	return DEFAULT_OFF_HAND_PENALTY + off_hand_bonus

func equip_starting_item() -> void:
	match character_name:
		"Brad":
			equip_item(ItemData.create_bloodbound_plate(), 0)
		"Stephen":
			equip_item(ItemData.create_flickerstep_boots(), 0)
		"Cory":
			equip_item(ItemData.create_grasping_gauntlets(), 0)
		"Jeremy":
			equip_item(ItemData.create_scholars_signet(), 0)
		"Ryan":
			equip_item(ItemData.create_adventurers_belt(), 0)
	
	print("[INVENTORY] Equipped starting item for %s" % character_name)

func equip_item(item: ItemData, slot_index: int = 0) -> bool:
	var slot_array = _get_slot_array(item.item_type)
	var max_slots = _get_max_slots(item.item_type)
	
	if slot_index < 0 or slot_index >= max_slots:
		print("[INVENTORY] Invalid slot index %d for %s" % [slot_index, item.item_name])
		return false
	
	if slot_array[slot_index] != null:
		print("[INVENTORY] Slot %d already occupied" % slot_index)
		return false
	
	slot_array[slot_index] = item
	
	# Slot index > 0 means off-hand; two-handed weapons never get the penalty
	var is_off_hand = (item.item_type == ItemData.ItemType.WEAPON and
					   slot_index > 0 and not item.is_two_handed)

	_apply_item_bonuses(item, true, is_off_hand)
	_apply_special_effect(item, true)
	
	item_equipped.emit(item, item.get_type_name(), slot_index)
	equipment_changed.emit()
	
	print("[INVENTORY] Equipped %s in slot %d" % [item.item_name, slot_index])
	return true

func unequip_item(item_type: ItemData.ItemType, slot_index: int) -> ItemData:
	var slot_array = _get_slot_array(item_type)
	var max_slots = _get_max_slots(item_type)
	
	if slot_index < 0 or slot_index >= max_slots:
		return null
	
	var item = slot_array[slot_index]
	if item == null:
		return null
	
	var is_off_hand = (item.item_type == ItemData.ItemType.WEAPON and
					   slot_index > 0 and not item.is_two_handed)

	slot_array[slot_index] = null
	_apply_item_bonuses(item, false, is_off_hand)
	_apply_special_effect(item, false)
	
	item_unequipped.emit(item, item.get_type_name(), slot_index)
	equipment_changed.emit()
	
	print("[INVENTORY] Unequipped %s from slot %d" % [item.item_name, slot_index])
	return item

func get_equipped_item(item_type: ItemData.ItemType, slot_index: int) -> ItemData:
	var slot_array = _get_slot_array(item_type)
	var max_slots = _get_max_slots(item_type)
	
	if slot_index < 0 or slot_index >= max_slots:
		return null
	
	return slot_array[slot_index]

func _get_slot_array(item_type: ItemData.ItemType) -> Array:
	match item_type:
		ItemData.ItemType.HELM: return equipped_helms
		ItemData.ItemType.CHEST: return equipped_chests
		ItemData.ItemType.RING: return equipped_rings
		ItemData.ItemType.BELT: return equipped_belts
		ItemData.ItemType.BOOTS: return equipped_boots
		ItemData.ItemType.GAUNTLETS: return equipped_gauntlets
		ItemData.ItemType.WEAPON: return equipped_weapons
	return []

func _get_max_slots(item_type: ItemData.ItemType) -> int:
	match item_type:
		ItemData.ItemType.HELM: return helm_slots
		ItemData.ItemType.CHEST: return chest_slots
		ItemData.ItemType.RING: return ring_slots
		ItemData.ItemType.BELT: return belt_slots
		ItemData.ItemType.BOOTS: return boots_slots
		ItemData.ItemType.GAUNTLETS: return gauntlets_slots
		ItemData.ItemType.WEAPON: return weapon_slots
	return 0

func _apply_item_bonuses(item: ItemData, equipping: bool, is_off_hand: bool = false) -> void:
	if not player_stats:
		return
	
	var multiplier = 1 if equipping else -1
	var stats: Dictionary
	
	if is_off_hand:
		stats = item.get_effective_stats(true, get_off_hand_modifier())
		print("[INVENTORY] Applying off-hand modifier: %.0f%%" % (get_off_hand_modifier() * 100))
	else:
		stats = item.get_effective_stats(false, 1.0)
	
	# Modify base stats (determination will apply automatically)
	player_stats.base_strength += stats["strength_bonus"] * multiplier
	player_stats.base_dexterity += stats["dexterity_bonus"] * multiplier
	player_stats.base_intelligence += stats["intelligence_bonus"] * multiplier
	player_stats.base_wisdom += stats["wisdom_bonus"] * multiplier
	player_stats.base_agility += stats["agility_bonus"] * multiplier
	player_stats.determination += item.determination_bonus * multiplier
	
	# Direct resource modifications (not affected by determination)
	player_stats.max_health += stats["health_bonus"] * multiplier
	player_stats.current_health = min(player_stats.current_health, player_stats.max_health)
	
	player_stats.max_mana += stats["mana_bonus"] * multiplier
	player_stats.current_mana = min(player_stats.current_mana, player_stats.max_mana)
	
	# Hand size from item (direct bonus)
	player_stats.hand_size += item.hand_size_bonus * multiplier
	
	# Recalculate derived stats
	player_stats.recalculate_derived_stats()
	
	# Update carry load
	_recalculate_carry_load()
	
	player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
	player_stats.mana_changed.emit(player_stats.current_mana, player_stats.max_mana)
func _recalculate_carry_load() -> void:
	if not player_stats:
		return
	
	var total_weight = get_total_weight()
	player_stats.set_carry_load(total_weight)
	
func _apply_special_effect(item: ItemData, equipping: bool) -> void:
	if not player_stats:
		return
	
	match item.special_effect:
		ItemData.SpecialEffect.GRANT_BLINK_CARD:
			if equipping and deck_manager:
				for i in range(item.special_effect_value):
					var blink_card = Card.create_blink()
					deck_manager.draw_pile.append(blink_card)
				deck_manager.shuffle_draw_pile()
				print("[INVENTORY] Added %d Blink card(s) to deck" % item.special_effect_value)
		
		ItemData.SpecialEffect.CHANCE_BOOST:
			var mult = 1 if equipping else -1
			player_stats.chance_boost += item.special_effect_value * mult
			print("[INVENTORY] Chance boost now: %.0f%%" % player_stats.chance_boost)
		
		ItemData.SpecialEffect.GRANT_CARDS:
			if equipping and deck_manager:
				for card_id in item.granted_card_ids:
					var card = _create_card_by_id(card_id)
					if card:
						if item.item_type == ItemData.ItemType.BELT and belt_card_mana_reduction > 0:
							card.mana_cost = max(0, card.mana_cost - belt_card_mana_reduction)
							print("[INVENTORY] %s mana cost reduced to %d (belt bonus)" % [card.card_name, card.mana_cost])
						deck_manager.draw_pile.append(card)
						print("[INVENTORY] Added %s to deck" % card.card_name)
				deck_manager.shuffle_draw_pile()

func _create_card_by_id(card_id: String) -> Card:
	match card_id:
		"healing_potion": return Card.create_healing_potion()
		"dagger_throw": return Card.create_dagger_throw()
		"blink": return Card.create_blink()
		"slash": return Card.create_slash()
		"block": return Card.create_block()
		"potion_of_continuance": return Card.create_potion_of_continuance()
	return null

func apply_starting_item_card_effects() -> void:
	## Re-apply card-granting effects from equipped items after deck initialization.
	## Called after deck_manager is connected and deck is initialized.
	if not deck_manager:
		return

	var cards_added = false

	for item_array in [equipped_belts, equipped_boots, equipped_helms, equipped_chests, equipped_rings, equipped_gauntlets, equipped_weapons]:
		for item in item_array:
			if not item:
				continue
			match item.special_effect:
				ItemData.SpecialEffect.GRANT_CARDS:
					for card_id in item.granted_card_ids:
						var card = _create_card_by_id(card_id)
						if card:
							if item.item_type == ItemData.ItemType.BELT and belt_card_mana_reduction > 0:
								card.mana_cost = max(0, card.mana_cost - belt_card_mana_reduction)
								print("[INVENTORY] %s mana cost reduced to %d (belt bonus)" % [card.card_name, card.mana_cost])
							deck_manager.draw_pile.append(card)
							print("[INVENTORY] Starting item added %s to deck" % card.card_name)
							cards_added = true
				ItemData.SpecialEffect.GRANT_BLINK_CARD:
					for i in range(item.special_effect_value):
						var blink_card = Card.create_blink()
						deck_manager.draw_pile.append(blink_card)
						print("[INVENTORY] Starting item added Blink to deck")
						cards_added = true

	if cards_added:
		deck_manager.shuffle_draw_pile()
		print("[INVENTORY] Shuffled deck after adding starting item cards")

func _recalculate_total_weapon_weight() -> void:
	# This now just triggers carry load recalculation
	_recalculate_carry_load()

# ============================================
# TURN PROCESSING
# ============================================

func process_turn() -> void:
	# Reset per-turn tracking
	ring_triggered_this_turn = false
	armor_gained_this_turn = 0
	
	# Process gauntlet cooldowns
	for gauntlet in equipped_gauntlets:
		if gauntlet and gauntlet.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
			var came_off_cooldown = gauntlet.reduce_cooldown()
			if came_off_cooldown:
				print("[INVENTORY] %s skill ready!" % gauntlet.gauntlet_skill_name)
				gauntlet_skill_ready.emit(gauntlet)
				
				# Cory's passive: gain mana when skill comes off cooldown
				if gauntlet_cooldown_mana and player_stats:
					player_stats.gain_mana(1)
					print("[INVENTORY] Cory passive: Gained 1 mana from cooldown")

	# Grant armor-per-turn from chest items (e.g. Leather Chest)
	if player_stats:
		for item in equipped_chests:
			if item and item.special_effect == ItemData.SpecialEffect.ARMOR_PER_TURN:
				player_stats.add_armor(item.special_effect_value)
				print("[INVENTORY] %s: +%d armor per turn" % [item.item_name, item.special_effect_value])

# ============================================
# RING TRIGGER SYSTEM
# ============================================

func trigger_rings(trigger_type: ItemData.RingTrigger, value: int = 0) -> void:
	for ring in equipped_rings:
		if ring and ring.ring_trigger == trigger_type:
			# Check threshold if applicable
			if trigger_type == ItemData.RingTrigger.ON_GAIN_ARMOR_THRESHOLD:
				if value < ring.ring_trigger_threshold:
					continue
			
			_execute_ring_effect(ring)
			
			# Jeremy's passive: first ring trigger happens twice
			if ring_double_trigger and not ring_triggered_this_turn:
				print("[INVENTORY] Jeremy passive: Double trigger!")
				_execute_ring_effect(ring)
			
			ring_triggered_this_turn = true

func _execute_ring_effect(ring: ItemData) -> void:
	if not player_stats:
		return
	
	match ring.ring_effect:
		ItemData.RingEffect.HEAL_TO_FULL:
			player_stats.current_health = player_stats.max_health
			player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
			print("[INVENTORY] Ring effect: Healed to full!")
		
		ItemData.RingEffect.GAIN_ARMOR:
			player_stats.add_armor(ring.ring_effect_value)
			print("[INVENTORY] Ring effect: Gained %d armor" % ring.ring_effect_value)
		
		ItemData.RingEffect.GAIN_MANA:
			player_stats.gain_mana(ring.ring_effect_value)
			print("[INVENTORY] Ring effect: Gained %d mana" % ring.ring_effect_value)
		
		ItemData.RingEffect.DRAW_CARD:
			if deck_manager:
				for i in range(ring.ring_effect_value):
					deck_manager.draw_card()
			print("[INVENTORY] Ring effect: Drew %d card(s)" % ring.ring_effect_value)
		
		ItemData.RingEffect.REDUCE_COOLDOWNS:
			for gauntlet in equipped_gauntlets:
				if gauntlet and gauntlet.current_cooldown > 0:
					gauntlet.current_cooldown = max(0, gauntlet.current_cooldown - ring.ring_effect_value)
			print("[INVENTORY] Ring effect: Reduced cooldowns by %d" % ring.ring_effect_value)
	
	ring_triggered.emit(ring, ring.get_ring_effect_name())

func on_armor_gained(amount: int) -> void:
	armor_gained_this_turn += amount
	trigger_rings(ItemData.RingTrigger.ON_GAIN_ARMOR_THRESHOLD, armor_gained_this_turn)

	# Apply armor-on-armor-gain passives across all equipment slots
	if not _applying_armor_instance_bonus and player_stats:
		_applying_armor_instance_bonus = true
		var all_slots = [equipped_helms, equipped_chests, equipped_rings, equipped_belts, equipped_boots, equipped_gauntlets, equipped_weapons]
		for slot in all_slots:
			for item in slot:
				if not item:
					continue
				# Bloodbound Plate uses OVERFLOW_HEAL_ARMOR with special_effect_value_2
				if item.special_effect == ItemData.SpecialEffect.OVERFLOW_HEAL_ARMOR and item.special_effect_value_2 > 0:
					player_stats.add_armor(item.special_effect_value_2)
					print("[INVENTORY] %s: +%d armor from armor instance" % [item.item_name, item.special_effect_value_2])
				# General armor-on-armor-gain items (helm, shield, gauntlets, etc.)
				elif item.special_effect == ItemData.SpecialEffect.ARMOR_ON_ARMOR_GAIN:
					player_stats.add_armor(item.special_effect_value)
					print("[INVENTORY] %s: +%d armor from armor instance" % [item.item_name, item.special_effect_value])
		_applying_armor_instance_bonus = false

func on_enemy_killed() -> void:
	trigger_rings(ItemData.RingTrigger.ON_ENEMY_KILL)

func on_card_played(card: Card) -> void:
	if card.card_type == Card.CardType.ATTACK:
		trigger_rings(ItemData.RingTrigger.ON_PLAY_ATTACK_CARD)
	elif card.card_type == Card.CardType.UTILITY:
		trigger_rings(ItemData.RingTrigger.ON_PLAY_UTILITY_CARD)

func on_card_drawn() -> void:
	trigger_rings(ItemData.RingTrigger.ON_DRAW_CARD)

func on_damage_taken() -> void:
	trigger_rings(ItemData.RingTrigger.ON_TAKE_DAMAGE)

func on_healed() -> void:
	trigger_rings(ItemData.RingTrigger.ON_HEAL)

# ============================================
# GAUNTLET SKILL SYSTEM
# ============================================

func get_available_gauntlet_skills() -> Array[ItemData]:
	var skills: Array[ItemData] = []
	for gauntlet in equipped_gauntlets:
		if gauntlet and gauntlet.gauntlet_skill_type != ItemData.GauntletSkillType.NONE:
			skills.append(gauntlet)
	return skills

func can_use_gauntlet_skill(gauntlet: ItemData) -> bool:
	if gauntlet.gauntlet_skill_type != ItemData.GauntletSkillType.ACTIVE:
		return false
	if gauntlet.is_on_cooldown():
		return false
	if player_stats and not player_stats.has_mana(gauntlet.gauntlet_skill_mana_cost):
		return false
	return true

func use_gauntlet_skill(gauntlet: ItemData, target = null) -> bool:
	if not can_use_gauntlet_skill(gauntlet):
		return false
	
	# Spend mana
	if player_stats:
		player_stats.spend_mana(gauntlet.gauntlet_skill_mana_cost)
	
	# Execute skill effect
	_execute_gauntlet_skill(gauntlet, target)
	
	# Start cooldown
	gauntlet.activate_skill()
	
	print("[INVENTORY] Used skill: %s (CD: %d turns)" % [gauntlet.gauntlet_skill_name, gauntlet.gauntlet_skill_cooldown])
	return true

func _execute_gauntlet_skill(gauntlet: ItemData, target) -> void:
	match gauntlet.gauntlet_skill_effect_id:
		"power_grip":
			if target and target.has_method("take_damage"):
				target.take_damage(8)
				print("[SKILL] Power Grip deals 8 damage!")
		
		"rage_strike":
			if target and target.has_method("take_damage"):
				target.take_damage(15)
			if player_stats:
				player_stats.take_damage(3)
			print("[SKILL] Rage Strike deals 15 damage, costs 3 HP!")

func get_passive_effects() -> Array[String]:
	var effects: Array[String] = []
	for gauntlet in equipped_gauntlets:
		if gauntlet and gauntlet.gauntlet_skill_type == ItemData.GauntletSkillType.PASSIVE:
			effects.append(gauntlet.gauntlet_skill_effect_id)
	return effects

func has_passive_effect(effect_id: String) -> bool:
	return effect_id in get_passive_effects()

# ============================================
# OVERFLOW EFFECTS
# ============================================

func check_overflow_effects() -> void:
	for item in equipped_chests:
		if item and item.special_effect == ItemData.SpecialEffect.OVERFLOW_HEAL_ARMOR:
			var heal_amount = item.special_effect_value

			if player_stats:
				player_stats.heal(heal_amount)
				overflow_heal_armor_triggered.emit(heal_amount, 0)
				print("[INVENTORY] Overflow effect: Healed %d" % heal_amount)

# ============================================
# UTILITY
# ============================================

func get_equipped_shield() -> ItemData:
	for weapon in equipped_weapons:
		if weapon and "Shield" in weapon.item_name:
			return weapon
	return null

func has_shield_equipped() -> bool:
	return get_equipped_shield() != null

func get_total_weight() -> int:
	var total = 0
	
	for item in equipped_helms:
		if item: total += item.weight
	
	for item in equipped_chests:
		if item:
			var weight = item.weight
			weight = floori(weight * (1.0 - chest_weight_reduction))
			total += weight
	
	for item in equipped_rings:
		if item: total += item.weight
	
	for item in equipped_belts:
		if item: total += item.weight
	
	for item in equipped_boots:
		if item: total += item.weight
	
	for item in equipped_gauntlets:
		if item: total += item.weight
	
	for item in equipped_weapons:
		if item: total += item.weight
	
	return total

func get_total_weapon_damage() -> int:
	var total = 0
	for i in range(equipped_weapons.size()):
		var weapon = equipped_weapons[i]
		if weapon:
			var is_off_hand = (i > 0 and not weapon.is_two_handed)
			if is_off_hand:
				total += floori(weapon.weapon_damage * get_off_hand_modifier())
			else:
				total += weapon.weapon_damage
	return total

func get_slot_info() -> Dictionary:
	return {
		"helm": {"max": helm_slots, "equipped": equipped_helms},
		"chest": {"max": chest_slots, "equipped": equipped_chests},
		"ring": {"max": ring_slots, "equipped": equipped_rings},
		"belt": {"max": belt_slots, "equipped": equipped_belts},
		"boots": {"max": boots_slots, "equipped": equipped_boots},
		"gauntlets": {"max": gauntlets_slots, "equipped": equipped_gauntlets},
		"weapon": {"max": weapon_slots, "equipped": equipped_weapons}
	}
