class_name ItemData
extends Resource

## Defines an item's properties

enum ItemType { HELM, CHEST, RING, BELT, BOOTS, GAUNTLETS, WEAPON, QUIVER }
# Order matters for save compat — only append new subtypes.
enum WeaponSubtype { SWORD, BOW, SHIELD, OTHER, POLEARM, DAGGER, AXE, HAMMER, WAND, TOME, STAFF }

static func get_weapon_subtype_name(subtype: int) -> String:
	match subtype:
		WeaponSubtype.SWORD: return "Sword"
		WeaponSubtype.BOW: return "Bow"
		WeaponSubtype.SHIELD: return "Shield"
		WeaponSubtype.POLEARM: return "Polearm"
		WeaponSubtype.DAGGER: return "Dagger"
		WeaponSubtype.AXE: return "Axe"
		WeaponSubtype.HAMMER: return "Hammer"
		WeaponSubtype.WAND: return "Wand"
		WeaponSubtype.TOME: return "Tome"
		WeaponSubtype.STAFF: return "Staff"
	return "Weapon"
enum Rarity { BASIC, COMMON, RARE, LEGENDARY, MYTHIC }
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
	CRIT_ZERO_MANA_CARDS,
	POCKET_KNIFE_PROC
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

# ============================================
# RARITY & FORGE LEVELS
# ============================================
# Every item exists at level 1 (the only level that drops) and can be forged
# up by consuming extra copies of the same item at the Blacksmith:
#   Basic/Common/Rare:  max level 2 — costs 3 extra copies (4 found in total)
#   Legendary/Mythic:   max level 3 — Lv.2 costs 1 extra copy (2 total),
#                       Lv.3 costs 2 more copies (4 total)
# Level 2 is a stat boost — by default every nonzero flat bonus gets +1, but
# an item can define bespoke level_2_overrides instead. Level 3
# (legendary/mythic only) is the big power spike: level_3_overrides rewrites
# item properties — skills, granted cards, on-self abilities — so the item
# can transform into something build-defining.
@export var rarity: Rarity = Rarity.BASIC
@export var item_level: int = 1
# Property name -> new value, applied when the item reaches level 2. When
# empty, the default +1-to-every-nonzero-bonus boost applies instead.
@export var level_2_overrides: Dictionary = {}
# Replaces `description` at level 2 (when non-empty).
@export var level_2_description: String = ""
# Property name -> new value, applied when the item reaches level 3.
@export var level_3_overrides: Dictionary = {}
# Replaces `description` at level 3 (when non-empty) so the tooltip
# explains the transformed skill.
@export var level_3_description: String = ""

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

# Weapon specific. NOTE: no item is inherently one- or two-handed — wielding
# an item with both hands is a player choice tracked per-slot in Inventory
# (see Inventory.two_handed_slot), gated purely by weight.
@export var weapon_damage: int = 0
@export var weapon_subtype: WeaponSubtype = WeaponSubtype.SWORD

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

# Granted cards (GRANT_CARDS / GRANT_BLINK_CARD). Built once the first time the
# item is equipped, then reused for the item's lifetime so the SAME instances
# come and go with the item on every swap — preserving per-card state (jail
# time, enhancement) across equip/unequip. Slotted (enchanted) cards
# live in slotted_cards; together they are the item's "owned" cards.
var granted_card_instances: Array = []
var granted_cards_built: bool = false

# ============================================
# WEAPON MASTERY BREAKPOINT (per-item, optional)
# ============================================
# Some weapons carry a stat breakpoint: reach the threshold with your BASE
# stat and this particular weapon reveals its mastery — extra cards granted
# while it is equipped (riding the same owned-cards plumbing as granted
# cards). A breakpoint is a REWARD, never a requirement: the weapon works
# fully for anyone; a high-stat wielder just gets more out of this one.
# Base stat means allocation/sphere-grid growth — Determination's combat
# swings never flicker mastery on or off mid-fight.
@export var mastery_stat: String = ""        # "strength", "dexterity", ... ("" = no breakpoint)
@export var mastery_threshold: int = 0
@export var mastery_card_ids: Array[String] = []
@export var mastery_description: String = "" # short flavor for tooltips
var mastery_card_instances: Array = []       # built once, reused (like granted cards)

func has_mastery() -> bool:
	return mastery_stat != "" and mastery_threshold > 0

func is_mastered_by(stats) -> bool:
	## True when the wielder's BASE stat meets this weapon's breakpoint.
	if not has_mastery() or stats == null:
		return false
	return int(stats.get_base_stat(mastery_stat)) >= mastery_threshold

func get_mastery_stat_label() -> String:
	return "%s %d" % [mastery_stat.substr(0, 3).to_upper(), mastery_threshold]

func get_mastery_text(stats = null) -> String:
	## Tooltip line, e.g. "Mastery (DEX 15): Sweeping strikes — UNLOCKED".
	if not has_mastery():
		return ""
	var line := "Mastery (%s)" % get_mastery_stat_label()
	if mastery_description != "":
		line += ": %s" % mastery_description
	elif not mastery_card_ids.is_empty():
		line += ": grants %s" % ", ".join(mastery_card_ids)
	if stats != null:
		line += " — UNLOCKED" if is_mastered_by(stats) else " — locked"
	return line

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

# On-kill card conjuring (Bladed Doughnut): every enemy kill while this item
# is equipped adds a fresh copy of this card directly to the hand.
@export var on_kill_card_id: String = ""

# Runtime tracking
var current_cooldown: int = 0  # Current cooldown remaining

# Description
@export var description: String = ""

# ============================================
# RARITY & FORGE LEVEL HELPERS
# ============================================

func get_rarity_name() -> String:
	match rarity:
		Rarity.BASIC: return "Basic"
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.LEGENDARY: return "Legendary"
		Rarity.MYTHIC: return "Mythic"
	return "Unknown"

func get_rarity_color() -> Color:
	match rarity:
		Rarity.BASIC: return Color(0.75, 0.75, 0.75)
		Rarity.COMMON: return Color(0.45, 0.85, 0.45)
		Rarity.RARE: return Color(0.4, 0.6, 1.0)
		Rarity.LEGENDARY: return Color(1.0, 0.6, 0.2)
		Rarity.MYTHIC: return Color(0.9, 0.35, 0.9)
	return Color.WHITE

func get_max_level() -> int:
	return 3 if rarity == Rarity.LEGENDARY or rarity == Rarity.MYTHIC else 2

func can_level_up() -> bool:
	return item_level < get_max_level()

## Extra copies the forge consumes to reach the NEXT level (on top of the item
## itself). Totals match the design: basic/common/rare need 4 copies found for
## Lv.2; legendary/mythic need 2 found for Lv.2 and 4 found for Lv.3.
func get_copies_for_next_level() -> int:
	if not can_level_up():
		return 0
	if rarity == Rarity.LEGENDARY or rarity == Rarity.MYTHIC:
		return 1 if item_level == 1 else 2
	return 3

## Display name with the forge level, e.g. "Iron Sword (Lv.2)".
func get_display_name() -> String:
	if item_level <= 1:
		return item_name
	return "%s (Lv.%d)" % [item_name, item_level]

## Forge the item to the next level. Returns false at max level.
## The caller (ItemForge) is responsible for consuming the copies.
func level_up() -> bool:
	if not can_level_up():
		return false
	item_level += 1
	if item_level == 2:
		_apply_level_2_boost()
	elif item_level == 3:
		_apply_overrides(level_3_overrides, level_3_description)
	return true

## Level 2 is a stat boost. Items with bespoke level_2_overrides apply those;
## everything else gets the default: every nonzero flat bonus the item
## provides gets +1 (design note: "max number +1").
func _apply_level_2_boost() -> void:
	if not level_2_overrides.is_empty():
		_apply_overrides(level_2_overrides, level_2_description)
		return
	for prop in ["strength_bonus", "dexterity_bonus", "intelligence_bonus",
			"wisdom_bonus", "determination_bonus", "agility_bonus",
			"health_bonus", "mana_bonus", "armor_bonus", "weapon_damage",
			"ranged_damage_bonus", "healing_bonus",
			"block_bonus_to_defense_cards", "damage_bonus_to_attack_cards"]:
		var value: int = get(prop)
		if value > 0:
			set(prop, value + 1)

## Rewrite properties from an overrides dict — the machinery behind both the
## Lv.2 bespoke boost and the Lv.3 transformation. Typed arrays are assigned
## in place, and overriding the granted/mastery card lists resets their built
## instances so the new cards are constructed on the next equip (forged items
## are always unequipped, so no live deck references exist).
func _apply_overrides(overrides: Dictionary, new_description: String) -> void:
	var cards_changed := false
	for prop in overrides:
		var current = get(prop)
		var value = overrides[prop]
		if current is Array and value is Array:
			current.assign(value)
		else:
			set(prop, value)
		if prop == "granted_card_ids" or prop == "mastery_card_ids":
			cards_changed = true
	if cards_changed:
		granted_card_instances.clear()
		mastery_card_instances.clear()
		granted_cards_built = false
	if new_description != "":
		description = new_description

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
# SIGNATURE ITEMS (formerly character starting items — now regular loot;
# no character starts with an item)
# ============================================

static func create_bloodbound_plate() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Bloodbound Plate"
	item.item_type = ItemType.CHEST
	item.item_type_name = "Chest"
	item.rarity = Rarity.RARE
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
	item.rarity = Rarity.RARE
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
	item.rarity = Rarity.RARE
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
	item.rarity = Rarity.RARE
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
	item.rarity = Rarity.RARE
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
	item.rarity = Rarity.RARE
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
	item.rarity = Rarity.RARE
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
	item.rarity = Rarity.RARE
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
	item.rarity = Rarity.RARE
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
	item.rarity = Rarity.RARE
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
	item.weapon_subtype = WeaponSubtype.DAGGER
	item.item_type_name = "Weapon"
	item.rarity = Rarity.COMMON
	item.weight = 3
	item.weapon_damage = 5
	item.fire_damage_percent = 10.0
	item.card_slots = 1
	item.on_self_damage = 1
	item.description = "5 dmg, +10% Fire Damage. 1 card slot, On-Self: +1 dmg"
	return item

static func create_frost_orb() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Frost Orb"
	item.item_type = ItemType.WEAPON
	item.weapon_subtype = WeaponSubtype.WAND
	item.item_type_name = "Weapon"
	item.rarity = Rarity.COMMON
	item.weight = 2
	item.health_bonus = 100
	item.ice_damage_percent = 10.0
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
	item.rarity = Rarity.COMMON
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
	item.rarity = Rarity.RARE
	item.weight = 130
	item.weapon_damage = 25
	item.card_slots = 2
	item.on_self_damage = 3
	item.description = "+25 Melee Attack damage. Weight 130. 2 card slots, On-Self: +3 dmg"
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
	item.rarity = Rarity.COMMON
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
	item.rarity = Rarity.COMMON
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
	item.rarity = Rarity.COMMON
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
	item.rarity = Rarity.RARE
	item.weapon_subtype = WeaponSubtype.SHIELD
	item.weight = 40
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
	item.rarity = Rarity.RARE
	item.weapon_subtype = WeaponSubtype.BOW
	item.weight = 30
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
	item.rarity = Rarity.RARE
	item.weapon_subtype = WeaponSubtype.BOW
	item.weight = 50
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
	item.weapon_subtype = WeaponSubtype.HAMMER
	item.item_type_name = "Weapon"
	item.weight = 25
	item.weapon_damage = 1
	item.description = "+1 damage. Weight 25."
	return item

# ============================================
# MASTERY BREAKPOINT WEAPONS (examples)
# ============================================

static func create_serpent_fang() -> ItemData:
	## Polearm with a DEX breakpoint: anyone can wield it, but a dexterous
	## hand unlocks its sweeping technique.
	var item = ItemData.new()
	item.item_name = "Serpent Fang"
	item.item_type = ItemType.WEAPON
	item.weapon_subtype = WeaponSubtype.POLEARM
	item.item_type_name = "Weapon"
	item.rarity = Rarity.RARE
	item.weight = 40
	item.weapon_damage = 6
	item.mastery_stat = "dexterity"
	item.mastery_threshold = 15
	item.mastery_card_ids.assign(["sweeping_disarm"])
	item.mastery_description = "grants Sweeping Disarm while wielded"
	item.description = "+6 damage. Weight 40. Mastery (DEX 15): grants Sweeping Disarm while wielded."
	return item

static func create_earthsplitter_sledge() -> ItemData:
	## Sledgehammer with a STR breakpoint: raw muscle unlocks the heavy swing.
	var item = ItemData.new()
	item.item_name = "Earthsplitter Sledge"
	item.item_type = ItemType.WEAPON
	item.weapon_subtype = WeaponSubtype.HAMMER
	item.item_type_name = "Weapon"
	item.rarity = Rarity.RARE
	item.weight = 90
	item.weapon_damage = 12
	item.mastery_stat = "strength"
	item.mastery_threshold = 15
	item.mastery_card_ids.assign(["heavy_swing"])
	item.mastery_description = "grants Heavy Swing while wielded"
	item.description = "+12 damage. Weight 90. Mastery (STR 15): grants Heavy Swing while wielded."
	return item

static func create_cyclops_ring() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Cyclops Ring"
	item.item_type = ItemType.RING
	item.item_type_name = "Ring"
	item.rarity = Rarity.RARE
	item.weight = 0
	item.fire_resistance_percent = 15.0
	item.block_bonus_to_defense_cards = 2
	item.damage_bonus_to_attack_cards = 2
	item.card_slots = 1
	item.allowed_card_keywords = [Card.CardKeyword.GEM]
	item.description = "15% Fire Resistance. +2 block to defense cards. +2 damage to attack cards. 1 Gem card slot."
	return item

static func create_trailblazers() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Trailblazers"
	item.item_type = ItemType.BOOTS
	item.item_type_name = "Boots"
	item.rarity = Rarity.COMMON
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
	item.weapon_subtype = WeaponSubtype.DAGGER
	item.item_type_name = "Weapon"
	item.rarity = Rarity.RARE
	item.weight = 10
	item.weapon_damage = 4
	item.special_effect = SpecialEffect.ON_KILL_INVISIBLE
	item.special_effect_value = 75  # Cooldown 75 tempo
	item.special_effect_value_2 = 10  # Crit chance %
	item.on_self_damage = 4
	item.card_slots = 1
	item.allowed_card_keywords = [Card.CardKeyword.POCKET]
	item.description = "+4 damage. On Kill: Become invisible (75 tempo cooldown). On-Self (Pocket): Zero mana cards gain 10% extra crit chance. Weight 10."
	return item

static func create_pocket_knife() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Pocket Knife"
	item.item_type = ItemType.WEAPON
	item.weapon_subtype = WeaponSubtype.DAGGER
	item.item_type_name = "Weapon"
	item.rarity = Rarity.COMMON
	item.weight = 1
	item.weapon_damage = 1
	item.special_effect = SpecialEffect.POCKET_KNIFE_PROC
	item.description = "On attack speed proc: attack resolves on first tick and costs 2 less tempo (after halving). Weight 1."
	return item

# ============================================
# TUTORIAL GIFT (Olorin's trade for the Bladed Doughnut)
# ============================================

static func create_wooden_sword() -> ItemData:
	## No stats at all — its worth is the lesson: a card slot with an on-self
	## bonus, plus a granted card (Splinter) that travels with the item.
	var item = ItemData.new()
	item.item_name = "Wooden Sword"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.rarity = Rarity.BASIC
	item.weight = 2
	item.weapon_damage = 0
	item.card_slots = 1
	item.on_self_damage = 1
	item.special_effect = SpecialEffect.GRANT_CARDS
	item.granted_card_ids.assign(["splinter"])
	item.description = "No stats. 1 card slot, On-Self: attacks deal +1 damage. Grants Splinter while equipped."
	return item

# ============================================
# LEGENDARY ITEMS (max level 3)
# ============================================
# Some legendaries carry a baked-in skill; level 3 transforms it via
# level_3_overrides into the build-defining version.

static func create_dawnbreaker_greatsword() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Dawnbreaker Greatsword"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.rarity = Rarity.LEGENDARY
	item.weight = 110
	item.weapon_damage = 20
	item.strength_bonus = 2
	item.card_slots = 2
	item.on_self_damage = 3
	item.description = "+20 Melee Attack damage, +2 STR. Weight 110. 2 card slots, On-Self: +3 dmg"
	item.level_3_overrides = {
		"damage_bonus_to_attack_cards": 3,
		"on_self_damage": 6,
	}
	item.level_3_description = "+20 Melee Attack damage, +2 STR. ALL attack cards deal +3 damage. Weight 110. 2 card slots, On-Self: +6 dmg"
	return item

static func create_aegis_of_the_colossus() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Aegis of the Colossus"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Shield"
	item.weapon_subtype = WeaponSubtype.SHIELD
	item.rarity = Rarity.LEGENDARY
	item.weight = 45
	item.armor_bonus = 8
	item.block_bonus_to_defense_cards = 1
	item.card_slots = 1
	item.on_self_block = 2
	item.description = "Block: 8. +1 block to defense cards. Weight 45. 1 card slot, On-Self: +2 block"
	item.level_3_overrides = {
		"block_bonus_to_defense_cards": 3,
		"special_effect": SpecialEffect.ARMOR_ON_ARMOR_GAIN,
		"special_effect_value": 3,
	}
	item.level_3_description = "Block: 8. +3 block to defense cards. +3 Armor on every Armor gain. Weight 45. 1 card slot, On-Self: +2 block"
	return item

static func create_ring_of_the_phoenix() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Ring of the Phoenix"
	item.item_type = ItemType.RING
	item.item_type_name = "Ring"
	item.rarity = Rarity.LEGENDARY
	item.weight = 0
	item.determination_bonus = 2
	item.ring_trigger = RingTrigger.ON_TAKE_DAMAGE
	item.ring_effect = RingEffect.GAIN_ARMOR
	item.ring_effect_value = 2
	item.description = "+2 DET. On Take Damage: Gain 2 Armor"
	item.level_3_overrides = {
		"ring_effect_value": 4,
		"determination_bonus": 4,
	}
	item.level_3_description = "+4 DET. On Take Damage: Gain 4 Armor"
	return item

# ============================================
# MYTHIC ITEMS (max level 3, all carry a skill)
# ============================================

static func create_worldsplitter_gauntlets() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Worldsplitter Gauntlets"
	item.item_type = ItemType.GAUNTLETS
	item.item_type_name = "Gauntlets"
	item.rarity = Rarity.MYTHIC
	item.weight = 5
	item.strength_bonus = 3
	item.gauntlet_skill_type = GauntletSkillType.ACTIVE
	item.gauntlet_skill_name = "Worldsplitter"
	item.gauntlet_skill_description = "Deal 20 damage"
	item.gauntlet_skill_cooldown = 4
	item.gauntlet_skill_mana_cost = 3
	item.gauntlet_skill_effect_id = "worldsplitter"
	item.description = "+3 STR. Skill: Worldsplitter (deal 20 damage)"
	item.level_3_overrides = {
		"gauntlet_skill_effect_id": "worldsplitter_awakened",
		"gauntlet_skill_name": "Worldsplitter Awakened",
		"gauntlet_skill_description": "Deal 30 damage, gain 5 Armor",
		"gauntlet_skill_cooldown": 3,
	}
	item.level_3_description = "+3 STR. Skill: Worldsplitter Awakened (deal 30 damage, gain 5 Armor)"
	return item

static func create_crown_of_the_first_king() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Crown of the First King"
	item.item_type = ItemType.HELM
	item.item_type_name = "Helm"
	item.rarity = Rarity.MYTHIC
	item.weight = 4
	item.wisdom_bonus = 2
	item.hand_size_bonus = 1
	item.special_effect = SpecialEffect.INCREASE_HAND_SIZE
	item.special_effect_value = 1
	item.card_slots = 1
	item.description = "+2 WIS, +1 Hand Size. 1 card slot"
	item.level_3_overrides = {
		"hand_size_bonus": 2,
		"special_effect_value": 2,
		"mana_bonus": 3,
		"card_slots": 2,
	}
	item.level_3_description = "+2 WIS, +2 Hand Size, +3 Mana. 2 card slots"
	return item

static func create_eternity_quiver() -> ItemData:
	var item = ItemData.new()
	item.item_name = "Eternity Quiver"
	item.item_type = ItemType.QUIVER
	item.item_type_name = "Quiver"
	item.rarity = Rarity.MYTHIC
	item.weight = 2
	item.ranged_damage_bonus = 3
	item.on_self_apply_burn = 1
	item.card_slots = 2
	item.allowed_card_keywords = [Card.CardKeyword.ARROW]
	item.description = "All ranged attacks gain +3 damage. On-Self (Arrow): Apply 1 Burn on hit. 2 Arrow card slots."
	item.level_3_overrides = {
		"ranged_damage_bonus": 5,
		"on_self_apply_burn": 2,
		"on_self_apply_cold": 1,
		"card_slots": 3,
	}
	item.level_3_description = "All ranged attacks gain +5 damage. On-Self (Arrow): Apply 2 Burn and 1 Cold on hit. 3 Arrow card slots."
	return item

static func create_bladed_doughnut() -> ItemData:
	## Tutorial mythic: the first rat of the story drops it, and Olorin eats it.
	## It remains a real mythic — redeemable later via a Mythic Mold.
	var item = ItemData.new()
	item.item_name = "Bladed Doughnut"
	item.item_type = ItemType.WEAPON
	item.weapon_subtype = WeaponSubtype.OTHER
	item.item_type_name = "Weapon"
	item.rarity = Rarity.MYTHIC
	item.weight = 5
	item.strength_bonus = 15
	item.on_kill_card_id = "sprinkle"
	item.description = "+15 STR. On Kill: add a Sprinkle to your hand (0 mana, 0 tempo, 25 damage)."
	item.level_3_overrides = {
		"on_kill_card_id": "sprinkle_bomb",
	}
	item.level_3_description = "+15 STR. On Kill: add a Sprinkle Bomb to your hand (0 mana, 0 tempo, 25 damage AOE)."
	return item

# ============================================
# ITEM FACTORY DISCOVERY
# ============================================

## One instance of every item defined by a zero-arg create_* factory.
static func get_all_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	var script: Script = ItemData
	for method in script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("create_") and method["args"].size() == 0:
			var item = script.call(method_name)
			if item is ItemData:
				items.append(item)
	return items

## Fresh level-1 instances of every item of the given rarity (used for
## rarity-weighted loot and for redeeming Mythic Molds).
static func get_items_of_rarity(r: Rarity) -> Array[ItemData]:
	var items: Array[ItemData] = []
	for item in get_all_items():
		if item.rarity == r:
			items.append(item)
	return items

## Recreate a fresh level-1 instance of an item by name (forge fodder checks,
## mold redemption). Returns null for unknown names.
static func create_by_name(item_name_to_find: String) -> ItemData:
	for item in get_all_items():
		if item.item_name == item_name_to_find:
			return item
	return null
