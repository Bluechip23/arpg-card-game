class_name ItemData
extends Resource

## Defines an item's properties

enum ItemType { HELM, CHEST, RING, BELT, BOOTS, GAUNTLETS, WEAPON, QUIVER }
enum WeaponHand { ONE_HAND, TWO_HAND }
enum WeaponSubtype { SWORD, BOW, SHIELD, OTHER }
enum SpecialEffect {
	NONE,
	OVERFLOW_HEAL_ARMOR,
	GRANT_BLINK_CARD,
	INCREASE_HAND_SIZE,
	CHANCE_BOOST,
	GRANT_CARDS,
	ARMOR_ON_ARMOR_GAIN,
	ARMOR_PER_TURN,
	THORNS_PER_TEMPO,
	ON_TEMPO_MOVEMENT_DAMAGE,
	ON_KILL_INVISIBLE,
	CRIT_ZERO_MANA_CARDS
}

# Ring trigger conditions
enum RingTrigger {
	NONE,
	ON_ENEMY_KILL,
	ON_GAIN_ARMOR_THRESHOLD,
	ON_TAKE_DAMAGE,
	ON_HEAL,
	ON_PLAY_ATTACK_CARD,
	ON_PLAY_UTILITY_CARD,
	ON_DRAW_CARD,
	ON_DISCARD_CARD,
	ON_LOW_HEALTH,
	ON_FULL_MANA
}

# Ring trigger effects
enum RingEffect {
	NONE,
	HEAL_TO_FULL,
	GAIN_ARMOR,
	GAIN_MANA,
	DRAW_CARD,
	DEAL_DAMAGE_ALL_ENEMIES,
	REDUCE_COOLDOWNS,
	GAIN_TEMP_STRENGTH
}

# Gauntlet skill types
enum GauntletSkillType {
	NONE,
	ACTIVE,
	PASSIVE
}

@export var item_name: String = "Unknown Item"
@export var item_type: ItemType = ItemType.WEAPON
@export var item_type_name: String = "Weapon"

# Stats
@export var weight: int = 0
@export var strength_bonus: int = 0
@export var dexterity_bonus: int = 0
@export var intelligence_bonus: int = 0
@export var wisdom_bonus: int = 0
@export var determination_bonus: int = 0
@export var agility_bonus: int = 0
@export var health_bonus: int = 0
@export var mana_bonus: int = 0
@export var armor_bonus: int = 0
@export var hand_size_bonus: int = 0

# Percentage bonuses (for off-hand, etc.)
@export var damage_percent_bonus: float = 0.0
@export var fire_damage_percent: float = 0.0
@export var ice_damage_percent: float = 0.0
@export var lightning_damage_percent: float = 0.0

# Weapon specific
@export var weapon_damage: int = 0
@export var weapon_hand: WeaponHand = WeaponHand.ONE_HAND
@export var weapon_subtype: WeaponSubtype = WeaponSubtype.SWORD
@export var is_two_handed: bool = false

# Special effects
@export var special_effect: SpecialEffect = SpecialEffect.NONE
@export var special_effect_value: int = 0
@export var special_effect_value_2: int = 0
@export var granted_card_ids: Array[String] = []

# Ring trigger system
@export var ring_trigger: RingTrigger = RingTrigger.NONE
@export var ring_trigger_threshold: int = 0  # For threshold-based triggers (e.g., gain 10 armor)
@export var ring_effect: RingEffect = RingEffect.NONE
@export var ring_effect_value: int = 0  # Value for the effect (armor amount, mana amount, etc.)

# Gauntlet skill system
@export var gauntlet_skill_type: GauntletSkillType = GauntletSkillType.NONE
@export var gauntlet_skill_name: String = ""
@export var gauntlet_skill_description: String = ""
@export var gauntlet_skill_cooldown: int = 0  # Turns for active skills
@export var gauntlet_skill_mana_cost: int = 0  # For active skills
@export var gauntlet_skill_effect_id: String = ""  # Identifier for the effect

# Card slot system
@export var card_slots: int = 0  # Number of card slots this item has
var slotted_cards: Array = []  # Cards currently in the slots
var allowed_card_keywords: Array = []  # Empty = any card allowed. e.g. [Card.CardKeyword.ARROW] = only arrow cards

# On-self bonuses (extra bonuses applied to cards slotted in this item)
@export var on_self_damage: int = 0
@export var on_self_block: int = 0
@export var on_self_heal: int = 0
@export var on_self_mana_reduction: int = 0

# On-self debuff application (for quivers, etc.)
@export var on_self_apply_burn: int = 0  # Apply X burn stacks on hit
@export var on_self_apply_cold: int = 0  # Apply X cold stacks on hit

# Passive bonuses
@export var ranged_damage_bonus: int = 0  # +X damage to all ranged attacks
@export var healing_bonus: int = 0  # +X to all healing effects
@export var block_bonus_to_defense_cards: int = 0  # +X block to all defense cards
@export var damage_bonus_to_attack_cards: int = 0  # +X damage to all attack cards
@export var fire_resistance_percent: float = 0.0  # X% fire resistance
@export var movement_per_tempo_bonus: int = 0  # +X movement per tempo

# On-self special effects (beyond flat bonuses)
@export var on_self_thorns: int = 0  # Card grants X thorns on play
@export var on_self_upgrade: bool = false  # Card upgrades on play (requires gem)

# Runtime tracking
var current_cooldown: int = 0  # Current cooldown remaining

# Description
@export var description: String = ""

func get_type_name() -> String:
	match item_type:
		ItemType.HELM: return "Helm"
		ItemType.CHEST: return "Chest"
		ItemType.RING: return "Ring"
		ItemType.BELT: return "Belt"
		ItemType.BOOTS: return "Boots"
		ItemType.GAUNTLETS: return "Gauntlets"
		ItemType.WEAPON: return "Weapon"
		ItemType.QUIVER: return "Quiver"
	return "Unknown"

func get_ring_trigger_name() -> String:
	match ring_trigger:
		RingTrigger.ON_ENEMY_KILL: return "On Enemy Kill"
		RingTrigger.ON_GAIN_ARMOR_THRESHOLD: return "On Gain %d+ Armor" % ring_trigger_threshold
		RingTrigger.ON_TAKE_DAMAGE: return "On Take Damage"
		RingTrigger.ON_HEAL: return "On Heal"
		RingTrigger.ON_PLAY_ATTACK_CARD: return "On Play Attack"
		RingTrigger.ON_PLAY_UTILITY_CARD: return "On Play Utility"
		RingTrigger.ON_DRAW_CARD: return "On Draw Card"
		RingTrigger.ON_DISCARD_CARD: return "On Discard"
		RingTrigger.ON_LOW_HEALTH: return "On Low Health"
		RingTrigger.ON_FULL_MANA: return "On Full Mana"
	return ""

func get_ring_effect_name() -> String:
	match ring_effect:
		RingEffect.HEAL_TO_FULL: return "Heal to Full"
		RingEffect.GAIN_ARMOR: return "Gain %d Armor" % ring_effect_value
		RingEffect.GAIN_MANA: return "Gain %d Mana" % ring_effect_value
		RingEffect.DRAW_CARD: return "Draw %d Card(s)" % ring_effect_value
		RingEffect.DEAL_DAMAGE_ALL_ENEMIES: return "Deal %d to All" % ring_effect_value
		RingEffect.REDUCE_COOLDOWNS: return "Reduce Cooldowns by %d" % ring_effect_value
		RingEffect.GAIN_TEMP_STRENGTH: return "+%d STR this turn" % ring_effect_value
	return ""

func is_on_cooldown() -> bool:
	return current_cooldown > 0

func reduce_cooldown() -> bool:
	# Returns true if skill just came off cooldown
	if current_cooldown > 0:
		current_cooldown -= 1
		if current_cooldown == 0:
			return true
	return false

func activate_skill() -> void:
	if gauntlet_skill_type == GauntletSkillType.ACTIVE:
		current_cooldown = gauntlet_skill_cooldown

func get_effective_stats(is_off_hand: bool, off_hand_modifier: float) -> Dictionary:
	# Returns stats with off-hand penalty/bonus applied
	var modifier = 1.0
	if is_off_hand:
		modifier = off_hand_modifier
	
	return {
		"strength_bonus": floori(strength_bonus * modifier),
		"dexterity_bonus": floori(dexterity_bonus * modifier),
		"intelligence_bonus": floori(intelligence_bonus * modifier),
		"wisdom_bonus": floori(wisdom_bonus * modifier),
		"determination_bonus": floori(determination_bonus * modifier),
		"agility_bonus": floori(agility_bonus * modifier),
		"health_bonus": floori(health_bonus * modifier),
		"mana_bonus": floori(mana_bonus * modifier),
		"armor_bonus": floori(armor_bonus * modifier),
		"damage_percent_bonus": damage_percent_bonus * modifier,
		"fire_damage_percent": fire_damage_percent * modifier,
		"ice_damage_percent": ice_damage_percent * modifier,
		"lightning_damage_percent": lightning_damage_percent * modifier,
		"weapon_damage": floori(weapon_damage * modifier)
	}

# ============================================
# CARD SLOT SYSTEM
# ============================================

func has_card_slots() -> bool:
	return card_slots > 0

func get_free_card_slots() -> int:
	return max(0, card_slots - slotted_cards.size())

func can_slot_card(card) -> bool:
	if slotted_cards.size() >= card_slots:
		return false
	# Check Picky compatibility: card must go into same item type it came from
	if card.slot_compatibility == 0 and card.source_item_type >= 0:  # PICKY = 0
		if card.source_item_type != item_type:
			return false
	# Check card keyword compatibility
	# If item has explicit allowed_card_keywords, use those
	if allowed_card_keywords.size() > 0:
		if card.card_keyword not in allowed_card_keywords:
			return false
	else:
		# Default restrictions based on item type
		var required = _get_default_keyword_for_item_type()
		if required >= 0 and card.card_keyword != required:
			return false
	return true

## Returns the default required card keyword for this item type (-1 = any card allowed).
func _get_default_keyword_for_item_type() -> int:
	match item_type:
		ItemType.BELT: return 2      # POCKET
		ItemType.BOOTS: return 5     # SWIFT
		ItemType.RING: return 3      # GEM
		ItemType.HELM: return 7      # CROWN
		ItemType.GAUNTLETS: return 8 # FIST
		ItemType.QUIVER: return 1    # ARROW
		ItemType.WEAPON:
			match weapon_subtype:
				WeaponSubtype.SHIELD: return 6  # BUCKLER
				WeaponSubtype.BOW: return -1     # ARROW + standard attacks (handled by allowed_card_keywords)
				_: return -1  # Swords and other weapons accept any card
	return -1  # CHEST and others accept any card

func slot_card(card) -> bool:
	if not can_slot_card(card):
		return false
	slotted_cards.append(card)
	card.slotted_in_item = self
	print("[ITEM] %s: slotted card '%s' (%d/%d slots)" % [item_name, card.card_name, slotted_cards.size(), card_slots])
	return true

func unslot_card(card_index: int):
	if card_index < 0 or card_index >= slotted_cards.size():
		return null
	var card = slotted_cards[card_index]
	if card.is_molded:
		print("[ITEM] %s: cannot remove '%s' - card is Molded!" % [item_name, card.card_name])
		return null
	slotted_cards.remove_at(card_index)
	card.slotted_in_item = null
	# Track source item type for Picky cards
	if card.source_item_type < 0:
		card.source_item_type = item_type
	print("[ITEM] %s: unslotted card '%s' (%d/%d slots)" % [item_name, card.card_name, slotted_cards.size(), card_slots])
	return card

func get_on_self_bonus() -> Dictionary:
	return {
		"damage": on_self_damage,
		"block": on_self_block,
		"heal": on_self_heal,
		"mana_reduction": on_self_mana_reduction,
		"apply_burn": on_self_apply_burn,
		"apply_cold": on_self_apply_cold,
		"thorns": on_self_thorns,
		"upgrade": on_self_upgrade
	}

func get_card_slot_summary() -> String:
	if card_slots == 0:
		return ""
	var parts: Array[String] = []
	parts.append("Slots: %d/%d" % [slotted_cards.size(), card_slots])
	for card in slotted_cards:
		var suffix = " [Molded]" if card.is_molded else ""
		parts.append("  - %s%s" % [card.card_name, suffix])
	if on_self_damage > 0:
		parts.append("On-Self: +%d damage" % on_self_damage)
	if on_self_block > 0:
		parts.append("On-Self: +%d block" % on_self_block)
	if on_self_heal > 0:
		parts.append("On-Self: +%d heal" % on_self_heal)
	if on_self_mana_reduction > 0:
		parts.append("On-Self: -%d mana cost" % on_self_mana_reduction)
	if on_self_apply_burn > 0:
		parts.append("On-Self: Apply %d Burn on hit" % on_self_apply_burn)
	if on_self_apply_cold > 0:
		parts.append("On-Self: Apply %d Cold on hit" % on_self_apply_cold)
	if on_self_thorns > 0:
		parts.append("On-Self: Gain %d Thorns on play" % on_self_thorns)
	if on_self_upgrade:
		parts.append("On-Self: Upgrade card on play")
	if allowed_card_keywords.size() > 0:
		var kw_names: Array[String] = []
		for kw in allowed_card_keywords:
			match kw:
				1: kw_names.append("Arrow")
				2: kw_names.append("Pocket")
				3: kw_names.append("Gem")
				4: kw_names.append("Chisel")
				5: kw_names.append("Swift")
				6: kw_names.append("Buckler")
				7: kw_names.append("Crown")
				8: kw_names.append("Fist")
		if kw_names.size() > 0:
			parts.append("Accepts: %s cards only" % ", ".join(kw_names))
	return "\n".join(parts)

# ============================================
# CHARACTER STARTING ITEMS
# ============================================

static func create_bloodbound_plate() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Bloodbound Plate"
	item.item_type = ItemType.CHEST
	item.item_type_name = "Chest"
	item.weight = 5
	item.determination_bonus = 2
	item.special_effect = SpecialEffect.OVERFLOW_HEAL_ARMOR
	item.special_effect_value = 2    # Heal 2 on overflow
	item.special_effect_value_2 = 1  # +1 Armor whenever armor is gained
	item.description = "+2 DET. Overflow: Heal 2. +1 Armor on Armor Gain"
	return item

static func create_flickerstep_boots() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Flickerstep Boots"
	item.item_type = ItemType.BOOTS
	item.item_type_name = "Boots"
	item.weight = 2
	item.dexterity_bonus = 2
	item.special_effect = SpecialEffect.GRANT_BLINK_CARD
	item.special_effect_value = 1
	item.description = "+2 DEX. Grants 1 Blink card"
	return item

static func create_grasping_gauntlets() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Grasping Gauntlets"
	item.item_type = ItemType.GAUNTLETS
	item.item_type_name = "Gauntlets"
	item.weight = 3
	item.hand_size_bonus = 2
	item.special_effect = SpecialEffect.INCREASE_HAND_SIZE
	item.special_effect_value = 2
	# Active skill: Power Grip
	item.gauntlet_skill_type = GauntletSkillType.ACTIVE
	item.gauntlet_skill_name = "Power Grip"
	item.gauntlet_skill_description = "Deal 8 damage"
	item.gauntlet_skill_cooldown = 3
	item.gauntlet_skill_mana_cost = 2
	item.gauntlet_skill_effect_id = "power_grip"
	item.description = "+2 Hand Size. Skill: Power Grip"
	return item

static func create_scholars_signet() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Scholar's Signet"
	item.item_type = ItemType.RING
	item.item_type_name = "Ring"
	item.weight = 0
	item.intelligence_bonus = 3
	item.special_effect = SpecialEffect.CHANCE_BOOST
	item.special_effect_value = 3
	# Ring trigger: On play utility card, gain mana
	item.ring_trigger = RingTrigger.ON_PLAY_UTILITY_CARD
	item.ring_effect = RingEffect.GAIN_MANA
	item.ring_effect_value = 1
	item.description = "+3 INT. +3% chance. On Utility: +1 Mana"
	return item

static func create_adventurers_belt() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Adventurer's Belt"
	item.item_type = ItemType.BELT
	item.item_type_name = "Belt"
	item.weight = 1
	item.special_effect = SpecialEffect.GRANT_CARDS
	item.granted_card_ids.assign(["healing_potion", "dagger_throw"])
	item.card_slots = 2
	item.on_self_heal = 1
	item.description = "Grants Healing Potion & Dagger Throw. 2 card slots, On-Self: +1 heal"
	return item

# ============================================
# SAMPLE RINGS WITH TRIGGERS
# ============================================

static func create_ring_of_vengeance() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Ring of Vengeance"
	item.item_type = ItemType.RING
	item.item_type_name = "Ring"
	item.weight = 0
	item.strength_bonus = 1
	item.ring_trigger = RingTrigger.ON_ENEMY_KILL
	item.ring_effect = RingEffect.HEAL_TO_FULL
	item.description = "+1 STR. On Kill: Heal to Full"
	return item

static func create_ring_of_fortitude() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Ring of Fortitude"
	item.item_type = ItemType.RING
	item.item_type_name = "Ring"
	item.weight = 0
	item.determination_bonus = 2
	item.ring_trigger = RingTrigger.ON_GAIN_ARMOR_THRESHOLD
	item.ring_trigger_threshold = 10
	item.ring_effect = RingEffect.GAIN_MANA
	item.ring_effect_value = 3
	item.description = "+2 DET. On Gain 10+ Armor: +3 Mana"
	return item

static func create_ring_of_the_scholar() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Ring of the Scholar"
	item.item_type = ItemType.RING
	item.item_type_name = "Ring"
	item.weight = 0
	item.intelligence_bonus = 2
	item.ring_trigger = RingTrigger.ON_DRAW_CARD
	item.ring_effect = RingEffect.GAIN_MANA
	item.ring_effect_value = 1
	item.description = "+2 INT. On Draw: +1 Mana"
	return item

# ============================================
# SAMPLE GAUNTLETS WITH SKILLS
# ============================================

static func create_berserker_gauntlets() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Berserker Gauntlets"
	item.item_type = ItemType.GAUNTLETS
	item.item_type_name = "Gauntlets"
	item.weight = 4
	item.strength_bonus = 2
	item.gauntlet_skill_type = GauntletSkillType.ACTIVE
	item.gauntlet_skill_name = "Rage Strike"
	item.gauntlet_skill_description = "Deal 15 damage, take 3 damage"
	item.gauntlet_skill_cooldown = 4
	item.gauntlet_skill_mana_cost = 3
	item.gauntlet_skill_effect_id = "rage_strike"
	item.description = "+2 STR. Skill: Rage Strike"
	return item

static func create_guardian_gauntlets() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Guardian Gauntlets"
	item.item_type = ItemType.GAUNTLETS
	item.item_type_name = "Gauntlets"
	item.weight = 5
	item.armor_bonus = 2
	item.gauntlet_skill_type = GauntletSkillType.PASSIVE
	item.gauntlet_skill_name = "Stalwart"
	item.gauntlet_skill_description = "Armor decays 1 less per turn"
	item.gauntlet_skill_effect_id = "stalwart"
	item.description = "+2 Armor. Passive: -1 Armor Decay"
	return item

# ============================================
# SAMPLE OFF-HAND WEAPONS
# ============================================

static func create_flame_dagger() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Flame Dagger"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.weight = 3
	item.weapon_damage = 5
	item.fire_damage_percent = 10.0
	item.weapon_hand = WeaponHand.ONE_HAND
	item.card_slots = 1
	item.on_self_damage = 1
	item.description = "5 dmg, +10% Fire Damage. 1 card slot, On-Self: +1 dmg"
	return item

static func create_frost_orb() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Frost Orb"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.weight = 2
	item.health_bonus = 100
	item.ice_damage_percent = 10.0
	item.weapon_hand = WeaponHand.ONE_HAND
	item.description = "+100 HP, +10% Ice Damage"
	return item

# ============================================
# GENERIC ITEMS
# ============================================

static func create_iron_helm() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Iron Helm"
	item.item_type = ItemType.HELM
	item.item_type_name = "Helm"
	item.weight = 3
	item.special_effect = SpecialEffect.ARMOR_ON_ARMOR_GAIN
	item.special_effect_value = 2
	item.card_slots = 1
	item.on_self_block = 1
	item.description = "+2 Armor on every Armor gain. 1 card slot, On-Self: +1 block"
	return item

static func create_leather_chest() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Leather Chest"
	item.item_type = ItemType.CHEST
	item.item_type_name = "Chest"
	item.weight = 5
	item.health_bonus = 2
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 3
	item.description = "+3 Armor per turn, +2 Max HP"
	return item

static func create_iron_sword() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Iron Sword"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.weight = 80
	item.weapon_damage = 10
	item.weapon_hand = WeaponHand.ONE_HAND
	item.card_slots = 1
	item.on_self_damage = 2
	item.description = "+10 Melee Attack damage. Weight 80. 1 card slot, On-Self: +2 dmg"
	return item

static func create_wooden_shield() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Wooden Shield"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Shield"
	item.weight = 4
	item.armor_bonus = 5  # Block value when using basic block action
	item.special_effect = SpecialEffect.ARMOR_ON_ARMOR_GAIN
	item.special_effect_value = 2
	item.weapon_hand = WeaponHand.ONE_HAND
	item.weapon_subtype = WeaponSubtype.SHIELD
	item.card_slots = 1
	item.on_self_block = 2
	item.description = "Block: 5. +2 Armor on every Armor gain. 1 card slot, On-Self: +2 block"
	return item

static func create_gold_ring() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Gold Ring"
	item.item_type = ItemType.RING
	item.item_type_name = "Ring"
	item.weight = 0
	item.mana_bonus = 2
	item.ring_trigger = RingTrigger.ON_ENEMY_KILL
	item.ring_effect = RingEffect.DRAW_CARD
	item.ring_effect_value = 1
	item.description = "+2 Mana. On Kill: Draw 1 card"
	return item

static func create_heavy_greatsword() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Heavy Greatsword"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.weight = 130
	item.weapon_damage = 25
	item.weapon_hand = WeaponHand.TWO_HAND
	item.is_two_handed = true
	item.card_slots = 2
	item.on_self_damage = 3
	item.description = "+25 Melee Attack damage. Weight 130. Two-handed. 2 card slots, On-Self: +3 dmg"
	return item

static func create_leather_boots() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Leather Boots"
	item.item_type = ItemType.BOOTS
	item.item_type_name = "Boots"
	item.weight = 2
	item.agility_bonus = 2
	item.card_slots = 1
	item.on_self_mana_reduction = 1
	item.description = "+2 Agility. 1 card slot, On-Self: -1 mana cost"
	return item

static func create_iron_gauntlets() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Iron Gauntlets"
	item.item_type = ItemType.GAUNTLETS
	item.item_type_name = "Gauntlets"
	item.weight = 3
	item.strength_bonus = 1
	item.special_effect = SpecialEffect.ARMOR_ON_ARMOR_GAIN
	item.special_effect_value = 1
	item.description = "+1 Strength. +1 Armor on every Armor gain"
	return item

static func create_utility_belt() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Utility Belt"
	item.item_type = ItemType.BELT
	item.item_type_name = "Belt"
	item.weight = 1
	item.wisdom_bonus = 1
	item.special_effect = SpecialEffect.GRANT_CARDS
	item.granted_card_ids.assign(["dagger_throw", "potion_of_continuance"])
	item.description = "+1 Wisdom. Grants Dagger Throw & Potion of Continuance"
	return item

# ============================================
# QUIVERS
# ============================================

static func create_ice_quiver() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Ice Quiver"
	item.item_type = ItemType.QUIVER
	item.item_type_name = "Quiver"
	item.weight = 2
	item.ranged_damage_bonus = 1
	item.on_self_apply_cold = 1
	item.card_slots = 3
	item.allowed_card_keywords = [Card.CardKeyword.ARROW]
	item.description = "All ranged attacks gain +1 damage. On-Self (Arrow): Apply 1 Cold on hit. 3 Arrow card slots."
	return item

static func create_fire_quiver() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Fire Quiver"
	item.item_type = ItemType.QUIVER
	item.item_type_name = "Quiver"
	item.weight = 2
	item.ranged_damage_bonus = 2
	item.on_self_apply_burn = 1
	item.card_slots = 1
	item.allowed_card_keywords = [Card.CardKeyword.ARROW]
	item.description = "All ranged attacks gain +2 damage. On-Self (Arrow): Apply 1 Burn on hit. 1 Arrow card slot."
	return item

# ============================================
# SPECIAL BELTS
# ============================================

static func create_belt_of_greater_healing() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Belt of Greater Healing"
	item.item_type = ItemType.BELT
	item.item_type_name = "Belt"
	item.weight = 2
	item.healing_bonus = 2
	item.on_self_heal = 1
	item.special_effect = SpecialEffect.GRANT_CARDS
	item.granted_card_ids.assign(["gulped_potion"])
	item.card_slots = 2
	item.allowed_card_keywords = [Card.CardKeyword.POCKET]
	item.description = "All healing effects get +2. Grants Gulped Potion. On-Self: Heal 1 to all allies. 2 Pocket card slots."
	return item

# ============================================
# WEAPON ITEMS
# ============================================

static func create_spiked_shield() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Spiked Shield"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Shield"
	item.weapon_subtype = WeaponSubtype.SHIELD
	item.weight = 40
	item.weapon_hand = WeaponHand.ONE_HAND
	item.special_effect = SpecialEffect.THORNS_PER_TEMPO
	item.special_effect_value = 3  # Gain 3 thorns
	item.special_effect_value_2 = 5  # Every 5 tempo
	item.on_self_thorns = 3
	item.block_bonus_to_defense_cards = 1
	item.card_slots = 1
	item.description = "Gain 3 Thorns every 5 tempo. On-Self: +3 Thorns on play. +1 block to defense cards. Weight 40."
	return item

static func create_bow_of_true_sight() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Bow of True Sight"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Bow"
	item.weapon_subtype = WeaponSubtype.BOW
	item.weight = 30
	item.weapon_hand = WeaponHand.ONE_HAND
	item.weapon_damage = 3
	item.ranged_damage_bonus = 3
	item.on_self_damage = 3
	item.movement_per_tempo_bonus = -2
	item.card_slots = 1
	item.allowed_card_keywords = [Card.CardKeyword.ARROW]
	item.description = "+3 damage. +3 range. -2 movement/tempo. Weight 30. 1 Arrow card slot."
	return item

static func create_bow_of_deep_wounds() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Bow of Deep Wounds"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Bow"
	item.weapon_subtype = WeaponSubtype.BOW
	item.weight = 50
	item.weapon_hand = WeaponHand.ONE_HAND
	item.weapon_damage = 10
	item.on_self_damage = 3
	item.card_slots = 2
	item.allowed_card_keywords = [Card.CardKeyword.ARROW]
	item.description = "+10 damage. On-Self: +3 damage +1 tempo. Weight 50. 2 Arrow card slots."
	return item

static func create_club() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Club"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.weight = 25
	item.weapon_hand = WeaponHand.ONE_HAND
	item.weapon_damage = 1
	item.description = "+1 damage. Weight 25."
	return item

static func create_cyclops_ring() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Cyclops Ring"
	item.item_type = ItemType.RING
	item.item_type_name = "Ring"
	item.weight = 0
	item.fire_resistance_percent = 15.0
	item.block_bonus_to_defense_cards = 2
	item.damage_bonus_to_attack_cards = 2
	item.on_self_upgrade = true
	item.card_slots = 1
	item.allowed_card_keywords = [Card.CardKeyword.GEM]
	item.description = "15% Fire Resistance. +2 block to defense cards. +2 damage to attack cards. On-Self (Gem): Upgrade card. 1 Gem card slot."
	return item

static func create_trailblazers() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Trailblazers"
	item.item_type = ItemType.BOOTS
	item.item_type_name = "Boots"
	item.weight = 10
	item.special_effect = SpecialEffect.ON_TEMPO_MOVEMENT_DAMAGE
	item.special_effect_value = 5  # Deal 5 damage
	item.card_slots = 1
	item.description = "When causing tempo with movement, deal 5 damage to nearest enemy. Weight 10. 1 card slot."
	return item

static func create_shadow_dagger() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Shadow Dagger"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.weight = 10
	item.weapon_hand = WeaponHand.ONE_HAND
	item.weapon_damage = 4
	item.special_effect = SpecialEffect.ON_KILL_INVISIBLE
	item.special_effect_value = 75  # Cooldown 75 tempo
	item.special_effect_value_2 = 10  # Crit chance %
	item.on_self_damage = 4
	item.card_slots = 1
	item.allowed_card_keywords = [Card.CardKeyword.POCKET]
	item.description = "+4 damage. On Kill: Become invisible (75 tempo cooldown). On-Self (Pocket): Zero mana cards gain 10% extra crit chance. Weight 10."
	return item
