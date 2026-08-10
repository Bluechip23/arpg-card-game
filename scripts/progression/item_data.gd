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
# Order matters for save compat — only append new rarities. (BASIC was
# removed: former basic items are simply Common now.)
enum Rarity { COMMON, RARE, LEGENDARY, MYTHIC }
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
# Non-equipment utility items (e.g. "return_scroll"): right-clicked in the
# inventory instead of equipped. Anything with a special_id refuses to equip.
@export var special_id: String = ""

# ============================================
# RARITY & FORGE LEVELS
# ============================================
# Every item exists at level 1 (the only level that drops) and can be forged
# up by consuming extra copies of the same item at the Blacksmith:
#   Common/Rare:        max level 2 — costs 3 extra copies (4 found in total)
#   Legendary/Mythic:   max level 3 — Lv.2 costs 1 extra copy (2 total),
#                       Lv.3 costs 2 more copies (4 total)
# Level 2 is a stat boost — by default every nonzero flat bonus gets +1, but
# an item can define bespoke level_2_overrides instead. Level 3
# (legendary/mythic only) is the big power spike: level_3_overrides rewrites
# item properties — skills, granted cards, on-self abilities — so the item
# can transform into something build-defining.
@export var rarity: Rarity = Rarity.COMMON
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
@export var on_self_mana_reduction_percent: float = 0.0  # % mana-cost cut for slotted cards (The Headbandz)

# Conditional on-self riders for slotted cards (item pass 1)
@export var on_self_range_offensive: int = 0        # +range on offensive slotted cards (Dragon Skull 1, Monocle 5)
@export var on_self_range_requires_ranged: bool = false  # if true the +range needs a RANGED offensive card (Monocle)
@export var on_self_crit_ranged_percent: float = 0.0     # +% crit on an offensive RANGED slotted card (Monocle 50)
@export var on_self_utility_heal: int = 0           # heal when a UTILITY card is slotted-played (Shamans mask 3)
@export var on_self_utility_spell_damage: int = 0   # spell damage to a random nearby enemy on UTILITY play (Shamans 1)
@export var on_self_brain_regen: int = 0            # regain X brain points when a slotted card is played (Scholars Cap 2)
@export var on_self_armor_any: int = 0             # gain X armor when ANY slotted card is played (Titanium Toe Tuckers 8)
@export var on_self_reaction_armor: int = 0        # gain X armor when a slotted REACTION/instant card plays (Rollerblades 10)
@export var on_self_flash_regen: int = 0           # restore X flash points when a slotted card is played (Hermes Boots 1)
@export var on_self_int_damage_percent: float = 0.0  # +X% of INT as bonus damage on slotted cards (Caster Boots 10)
@export var on_self_armor_per_missing_health10: int = 0  # armor per 10% missing health on slotted play (Boots of the Balancer 5)
@export var on_self_instant_damage_nearest: int = 0  # slotted instant → X damage to nearest enemy within 3 (Boot Holsters 10)
@export var on_self_attack_tempo_reduction: int = 0  # slotted attack costs X less tempo (Boot Holsters 1)
@export var on_self_invisible_tempo: int = 0       # slotted card → become invisible X tempo (Houdinis Slippers 5)

# Boots pass-2 passive riders
@export var sidestep_bonus_armor: int = 0          # +armor on a flash sidestep (Titanium Toe Tuckers 2)
@export var movement_flash_discount: int = 0       # movement flash costs X less (Rollerblades 1)
@export var movement_flash_tempo_threshold: int = 0  # after X movement flash spent, -1 tempo from a hand card (Boots of Speed 51)
@export var highground_damage_percent: float = 0.0  # +X% damage while attacking from high ground (Mountain Boots 20)
@export var trap_damage_percent: float = 0.0        # +X% trap damage (Hermes Boots 25) — traps not yet implemented
@export var missing_life_damage_rate: float = 0.0   # +rate × enemy missing-health% as bonus damage (Jordan 1s 0.5)
@export var missing_life_threshold: int = 0         # only below this enemy health% (Jordan 1s 50)
@export var melee_crit_flat_bonus: int = 0          # flat extra damage when a melee attack crits (Knife Toed Boots 10)
@export var consecutive_attack_draw: int = 0        # draw a card after X consecutive attacks (Cyde Livingstons Sneakers 5)
@export var fire_trail_damage: int = 0              # flash-move leaves fire dealing X (+INT) damage (Elemental Trail Blazers 5)
@export var fire_trail_tempo: int = 0               # how long a fire spot persists (Elemental Trail Blazers 3)

# Brain-point gear (Scholars Cap)
@export var brain_points_bonus: int = 0             # +X max brain points while equipped
@export var peek_brain_discount: int = 0            # brain-point Peek costs X less

# Spell-power-on-attack cadence (Wizard Hat): every N attacks, arm +X spell
# power on the next spell card played.
@export var spell_power_per_attacks: int = 0
@export var spell_power_bonus: int = 0

# On-self debuff application (for quivers, etc.)
@export var on_self_apply_burn: int = 0  # Apply X burn stacks on hit
@export var on_self_apply_cold: int = 0  # Apply X cold stacks on hit
@export var on_self_apply_bleed: int = 0  # Apply X bleed stacks on hit (Horned Nasal Helm)

# Passive bonuses
@export var ranged_damage_bonus: int = 0  # +X damage to all ranged attacks
@export var healing_bonus: int = 0  # +X to all healing effects
@export var block_bonus_to_defense_cards: int = 0  # +X block to all defense cards
@export var damage_bonus_to_attack_cards: int = 0  # +X damage to all attack cards
@export var fire_resistance_percent: float = 0.0  # X% fire resistance
@export var all_resistance_percent: float = 0.0  # X% resistance to ALL damage types
@export var crit_chance_percent: float = 0.0  # +X% crit chance while equipped
@export var lifesteal_percent: float = 0.0  # +X% of attack damage healed while equipped
@export var movement_per_tempo_bonus: int = 0  # +X movement per tempo

# Periodic armor (ARMOR_PER_TURN special_effect): armor granted every
# armor_per_tempo_interval tempo while equipped. Default 5 = once per cycle
# (the legacy cadence); Kettle/Mail use 15, Burgonet uses 5.
@export var armor_per_tempo_interval: int = 5

# On-self special effects (beyond flat bonuses)
@export var on_self_thorns: int = 0  # Card grants X thorns on play

# On-crit fire cone (Dragon Skull): when the wearer lands a crit, breathe a fire
# blast in a cone in front of them. Damage = base + INT/2; range in tiles.
@export var crit_fire_cone_damage: int = 0
@export var crit_fire_cone_range: int = 0

# Per-cycle helm passives (item pass 1)
@export var flash_crit_threshold: int = 0        # after spending X flash points, arm a guaranteed ranged crit (Feathered Hat)
@export var auto_purge_per_cycle: int = 0        # cleanse X of the wearer's debuffs each cycle (Horned Nasal Helm)
@export var void_resistance_percent: float = 0.0  # nearby enemies take +X% damage — "lowered resistance" (Mane)
@export var void_resistance_radius: int = 0       # aura radius in tiles (Mane 2)
@export var summon_heal_aura: int = 0             # heal summons below 25% HP within 3 tiles by X/cycle (Frankensteins Screws)

# On-kill card conjuring (Bladed Doughnut): every enemy kill while this item
# is equipped adds a fresh copy of this card directly to the hand.
@export var on_kill_card_id: String = ""

# Runtime tracking
var current_cooldown: int = 0  # Current cooldown remaining
# ARMOR_PER_TURN accumulator: tempo banked toward the next armor grant. Reset
# to 0 on equip/unequip so the counter restarts (per the helm spec).
var armor_per_tempo_accum: int = 0

# Description
@export var description: String = ""

# ============================================
# RARITY & FORGE LEVEL HELPERS
# ============================================

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.LEGENDARY: return "Legendary"
		Rarity.MYTHIC: return "Mythic"
	return "Unknown"

func get_rarity_color() -> Color:
	match rarity:
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
## itself). Totals match the design: common/rare need 4 copies found for
## Lv.2; legendary/mythic need 2 found for Lv.2 and 4 found for Lv.3.
func get_copies_for_next_level() -> int:
	if not can_level_up():
		return 0
	if rarity == Rarity.LEGENDARY or rarity == Rarity.MYTHIC:
		return 1 if item_level == 1 else 2
	return 3

## Display name with the forge level, e.g. "Wooden Sword (Lv.2)".
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
		"mana_reduction_percent": on_self_mana_reduction_percent,
		"apply_burn": on_self_apply_burn,
		"apply_cold": on_self_apply_cold,
		"apply_bleed": on_self_apply_bleed,
		"thorns": on_self_thorns,
		"range_offensive": on_self_range_offensive,
		"range_requires_ranged": on_self_range_requires_ranged,
		"crit_ranged_percent": on_self_crit_ranged_percent,
		"utility_heal": on_self_utility_heal,
		"utility_spell_damage": on_self_utility_spell_damage,
		"brain_regen": on_self_brain_regen,
		"armor_any": on_self_armor_any,
		"reaction_armor": on_self_reaction_armor,
		"flash_regen": on_self_flash_regen,
		"int_damage_percent": on_self_int_damage_percent,
		"armor_per_missing_health10": on_self_armor_per_missing_health10,
		"instant_damage_nearest": on_self_instant_damage_nearest,
		"attack_tempo_reduction": on_self_attack_tempo_reduction,
		"invisible_tempo": on_self_invisible_tempo,
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
# WEAPONS
# ============================================

static func create_return_scroll() -> ItemData:
	## Utility scroll every adventurer carries: right-click it in the
	## inventory to open a town portal where you stand.
	var item = ItemData.new()
	item.item_name = "Return Scroll"
	item.item_type = ItemType.WEAPON  # storage bookkeeping only — never equips
	item.item_type_name = "Scroll"
	item.rarity = Rarity.COMMON
	item.weight = 0
	item.special_id = "return_scroll"
	item.description = "Right-click to open a portal back to town. Walk in with [Shift]."
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
# TUTORIAL GIFT (Olorin's trade for the Bladed Doughnut)
# ============================================

static func create_wooden_sword() -> ItemData:
	## No stats at all — its worth is the lesson: a card slot with an on-self
	## bonus, plus a granted card (Splinter) that travels with the item.
	var item = ItemData.new()
	item.item_name = "Wooden Sword"
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.rarity = Rarity.COMMON
	item.weight = 2
	item.weapon_damage = 0
	item.card_slots = 1
	item.on_self_damage = 1
	item.special_effect = SpecialEffect.GRANT_CARDS
	item.granted_card_ids.assign(["splinter"])
	item.description = "No stats. 1 card slot, On-Self: attacks deal +1 damage. Grants Splinter while equipped."
	return item

# ============================================
# MYTHIC ITEMS (max level 3)
# ============================================

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
# HELMS (first item pass — head slot)
# ============================================
# Shared setup for every helm so the 19 factories stay declarative.
static func _new_helm(nm: String, r: Rarity, wt: int) -> ItemData:
	var item = ItemData.new()
	item.item_name = nm
	item.item_type = ItemType.HELM
	item.item_type_name = "Helm"
	item.rarity = r
	item.weight = wt
	return item

static func create_leather_cap() -> ItemData:
	var item = _new_helm("Leather Cap", Rarity.COMMON, 3)
	item.health_bonus = 5
	item.description = "+5 health."
	return item

static func create_baseball_hat() -> ItemData:
	var item = _new_helm("Baseball Hat", Rarity.COMMON, 5)
	item.dexterity_bonus = 1
	item.strength_bonus = 1
	item.agility_bonus = 1
	item.description = "+1 DEX, +1 STR, +1 AGI."
	return item

static func create_kettle_hat() -> ItemData:
	var item = _new_helm("Kettle Hat", Rarity.COMMON, 15)
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 2
	item.armor_per_tempo_interval = 15
	item.description = "Gain 2 armor every 15 tempo while equipped (counter resets when unequipped)."
	return item

static func create_mail_coif() -> ItemData:
	var item = _new_helm("Mail Coif", Rarity.COMMON, 25)
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 5
	item.armor_per_tempo_interval = 15
	item.description = "Gain 5 armor every 15 tempo while equipped (counter resets when unequipped)."
	return item

static func create_dragon_skull() -> ItemData:
	var item = _new_helm("Dragon Skull", Rarity.LEGENDARY, 30)
	item.strength_bonus = 8
	item.dexterity_bonus = 8
	item.card_slots = 2
	item.on_self_range_offensive = 1  # +1 range on any offensive slotted card
	item.crit_fire_cone_damage = 10   # on crit: 10 + INT/2 fire damage...
	item.crit_fire_cone_range = 3     # ...in a 3-range cone in front of the wearer
	item.description = "+8 STR, +8 DEX. On-self: if ANY offensive card, gain +1 range. When landing a critical strike, the helm breathes a 10 damage blast of fire in a 3 range cone in front of it (scales with INT: +1 damage per 2 INT)."
	return item

static func create_feathered_hat() -> ItemData:
	var item = _new_helm("Feathered Hat", Rarity.LEGENDARY, 10)
	item.agility_bonus = 8
	item.flash_crit_threshold = 40  # spend 40 flash → next ranged offensive card crits
	item.description = "+8 AGI. Once you have spent an accumulated 40 flash points, your next ranged offensive card crits (resets to 0 on use)."
	return item

static func create_frankensteins_screws() -> ItemData:
	var item = _new_helm("Frankensteins Screws", Rarity.LEGENDARY, 10)
	item.intelligence_bonus = 5
	var frank_cards: Array[String] = ["its_alive"]
	item.granted_card_ids = frank_cards
	item.summon_heal_aura = 3  # summons below 25% HP within 3 tiles heal 3/cycle
	item.description = "+5 INT. Grants ITS ALIVE!!!!!: Resurrect a dead corpse into Frankensteins Monster (50 + summoner INT×0.8 HP; moves every 8 tempo/4 spaces; attacks every 5 tempo for 10 + INT×0.25; 5% + INT/10 resist to all). 20 mana, 5 tempo. When your summons are below 25% health and within 3 squares of you, they heal 3 per cycle."
	return item

static func create_horned_nasal_helm() -> ItemData:
	var item = _new_helm("Horned Nasal Helm", Rarity.LEGENDARY, 30)
	item.determination_bonus = 6
	item.card_slots = 1
	item.on_self_apply_bleed = 1  # on-self: "if an offensive card apply 1 bleed"
	item.auto_purge_per_cycle = 2  # purge 2 random debuffs every 5 tempo (1 cycle)
	item.description = "+6 DET. On-self: if an offensive card, apply 1 Bleed. Purge 2 random debuffs every 5 tempo while equipped."
	return item

static func create_the_headbandz() -> ItemData:
	var item = _new_helm("The Headbandz", Rarity.MYTHIC, 8)
	item.card_slots = 5
	item.on_self_mana_reduction_percent = 20.0
	var headbandz_cards: Array[String] = ["out_of_guesses"]
	item.granted_card_ids = headbandz_cards
	# Upgrade path (mana-reduction 35%, Out of Guesses 1 tempo) via level overrides.
	item.description = "No stats. Cards slotted in its 5 slots cost 20% less mana. Grants Out of Guesses: discard your whole hand and draw that many cards (15 mana / 3 tempo). Upgraded: 35% mana reduction; Out of Guesses costs 1 tempo."
	return item

static func create_scholars_cap() -> ItemData:
	var item = _new_helm("Scholars Cap", Rarity.MYTHIC, 5)
	item.card_slots = 2
	item.wisdom_bonus = 5
	item.brain_points_bonus = 5
	item.peek_brain_discount = 1
	item.on_self_brain_regen = 2  # slotted cards regain 2 brain points on play
	# Upgrade path (on-self 3 brain, +7/+7) via level overrides.
	item.description = "+5 WIS, +5 max brain points. Peek costs 1 less brain point. On-self: regain 2 brain points. Upgraded: +7 WIS, +7 max brain points; on-self regains 3."
	return item

static func create_hanibals_mask() -> ItemData:
	var item = _new_helm("Hanibals Mask", Rarity.MYTHIC, 5)
	item.health_bonus = 25
	item.card_slots = 2
	item.lifesteal_percent = 15.0
	var hanibals_cards: Array[String] = ["resourceful_replenish"]
	item.granted_card_ids = hanibals_cards
	# Upgrade path (+50 life, Resourceful Replenish 8%) via level overrides.
	item.description = "+25 life. On-self: 15% lifesteal. Grants Resourceful Replenish (Maintain): your attacks lifesteal 5% (20 mana, 2 tempo). Upgraded: 50 life; Resourceful Replenish 8%."
	return item

static func create_mane_of_narashimha() -> ItemData:
	var item = _new_helm("Mane of Narashimha", Rarity.MYTHIC, 15)
	item.strength_bonus = 5
	item.intelligence_bonus = 5
	item.determination_bonus = 5
	item.card_slots = 1
	var mane_cards: Array[String] = ["neither_man_nor_beast"]
	item.granted_card_ids = mane_cards
	item.void_resistance_percent = 5.0  # nearby enemies take +5% damage (lowered resistance)
	item.void_resistance_radius = 2
	# Narashimha debuff is wired (enemy.gd). Upgrade path (7/7/7, 8% aura) via overrides.
	item.description = "+5 STR, +5 INT, +5 DET. Grants Neither Man nor Beast: deal 5 base damage ignoring all resistances and armor; target cannot heal that damage for 10 tempo (Narashimha) (10 mana, 2 tempo). Void resistance aura: lower all nearby enemies' resistances by 5% (2-square radius). Upgraded: 7/7/7 stats; aura 8%."
	return item

static func create_shamans_mask() -> ItemData:
	var item = _new_helm("Shamans mask", Rarity.RARE, 10)
	item.wisdom_bonus = 2
	item.health_bonus = 10
	item.card_slots = 3
	item.on_self_utility_heal = 3         # utility cards heal 3
	item.on_self_utility_spell_damage = 1  # ...and deal 1 spell damage to a random enemy in 3
	item.description = "+2 WIS, +10 life. On-self: utility cards heal 3 and deal 1 spell damage to a random enemy within 3 range."
	return item

static func create_wizard_hat() -> ItemData:
	var item = _new_helm("Wizard Hat", Rarity.RARE, 10)
	item.intelligence_bonus = 8
	item.wisdom_bonus = 2
	item.spell_power_per_attacks = 3  # every 3rd attack...
	item.spell_power_bonus = 5        # ...arms +5 spell power on the next spell card
	item.description = "+8 INT, +2 WIS. Every 3rd attack, your next spell card gains +5 spell power."
	return item

static func create_dunce_cap() -> ItemData:
	var item = _new_helm("Dunce Cap", Rarity.RARE, 15)
	item.strength_bonus = 8
	item.intelligence_bonus = -6
	item.description = "+8 STR, -6 INT."
	return item

static func create_burgonet() -> ItemData:
	var item = _new_helm("Burgonet", Rarity.RARE, 40)
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 2
	item.armor_per_tempo_interval = 5
	item.block_bonus_to_defense_cards = 2
	# NOTE (rider nuance): "additional two if it already grants armor" — the base
	# +2 to armor-granting defense cards is wired; the extra-to-zero-armor-defense
	# branch is flagged in the audit for your confirmation.
	item.description = "Gain 2 armor every 5 tempo while equipped (resets if unequipped). All defensive cards grant 2 armor (additional 2 if they already grant armor)."
	return item

static func create_summoners_cap() -> ItemData:
	var item = _new_helm("Summoners Cap", Rarity.RARE, 20)
	item.intelligence_bonus = 3
	item.card_slots = 1
	item.on_self_heal = 3  # "heal 3 to cards that heal" (applies to slotted cards)
	var summoner_cards: Array[String] = ["heal"]  # the existing basic "Heal" card
	item.granted_card_ids = summoner_cards
	item.description = "+3 INT. On-self: heal 3 to cards that heal. Grants a Heal card."
	return item

static func create_thick_steel_helm() -> ItemData:
	var item = _new_helm("Thick Steel Helm", Rarity.LEGENDARY, 55)
	item.health_bonus = 25
	item.all_resistance_percent = 10.0
	item.block_bonus_to_defense_cards = 2
	item.description = "+25 health, 10% resistance to all damage. Armor-providing cards grant 2 additional armor."
	return item

static func create_monocle() -> ItemData:
	var item = _new_helm("Monocle", Rarity.LEGENDARY, 0)
	item.crit_chance_percent = 10.0
	item.card_slots = 1
	item.on_self_range_offensive = 5
	item.on_self_range_requires_ranged = true
	item.on_self_crit_ranged_percent = 50.0
	var monocle_cards: Array[String] = ["twenty_twenty"]
	item.granted_card_ids = monocle_cards
	item.description = "+10% crit chance. On-self: if an offensive ranged card, gain +5 range and 50% crit. Grants 20/20 (Maintain): gain 3 range on all ranged offensive cards (15 mana, 3 tempo)."
	return item

static func create_theif_hat() -> ItemData:
	var item = _new_helm("Theif Hat", Rarity.COMMON, 3)
	item.agility_bonus = 2
	item.dexterity_bonus = 1
	item.description = "+2 AGI, +1 DEX."
	return item

# ============================================
# BOOTS (first boots pass — feet slot)
# ============================================
static func _new_boot(nm: String, r: Rarity, wt: int) -> ItemData:
	var item = ItemData.new()
	item.item_name = nm
	item.item_type = ItemType.BOOTS
	item.item_type_name = "Boots"
	item.rarity = r
	item.weight = wt
	return item

static func create_leather_boots() -> ItemData:
	var item = _new_boot("Leather Boots", Rarity.COMMON, 15)
	item.agility_bonus = 1
	item.health_bonus = 5
	item.description = "+1 AGI, +5 life."
	return item

static func create_cloth_slippers() -> ItemData:
	var item = _new_boot("Cloth Slippers", Rarity.COMMON, 5)
	item.dexterity_bonus = 2
	item.agility_bonus = 1
	item.description = "+2 DEX, +1 AGI."
	return item

static func create_brown_boots() -> ItemData:
	var item = _new_boot("Brown Boots", Rarity.COMMON, 8)
	item.agility_bonus = 5
	item.description = "+5 AGI."
	return item

static func create_steel_boots() -> ItemData:
	var item = _new_boot("Steel Boots", Rarity.COMMON, 25)
	item.strength_bonus = 3
	item.health_bonus = 10
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 1
	item.armor_per_tempo_interval = 15
	item.description = "+3 STR, +10 health. Gain 1 armor every 15 tempo while equipped."
	return item

static func create_titanium_toe_tuckers() -> ItemData:
	var item = _new_boot("Titanium Toe Tuckers", Rarity.LEGENDARY, 50)
	item.card_slots = 2
	item.strength_bonus = 10
	item.agility_bonus = -2
	item.dexterity_bonus = -2
	item.health_bonus = 10
	item.on_self_armor_any = 8  # ANY slotted card grants +8 armor
	item.sidestep_bonus_armor = 2
	item.description = "+10 STR, -2 AGI, -2 DEX, +10 health. On-self: ANY card provides +8 armor. Side step provides an additional 2 armor."
	return item

static func create_rollerblades() -> ItemData:
	var item = _new_boot("Rollerblades", Rarity.LEGENDARY, 20)
	item.card_slots = 1
	item.agility_bonus = 6
	item.strength_bonus = 5
	item.on_self_reaction_armor = 10  # slotted instant → +10 armor
	item.movement_flash_discount = 1  # movement flash costs 1 less
	# GAP (granted card): "shift" (bounded 2-space free move) — needs movement card support.
	item.description = "+6 AGI, +5 STR. On-self: if an instant, gain 10 armor in addition to its effect. -1 cost to movement flash points. Grants shift: move 2 spaces for free (0 mana / 0 tempo)."
	return item

static func create_cyde_livingstons_sneakers() -> ItemData:
	var item = _new_boot("Cyde Livingstons Sneakers", Rarity.LEGENDARY, 10)
	item.agility_bonus = 5
	item.dexterity_bonus = 4
	item.consecutive_attack_draw = 5  # 5 consecutive attacks → draw a card
	# GAP (granted card): "Donate Cleats" (ally AGI/DEX buff) — needs ally targeting.
	item.description = "+5 AGI, +4 DEX. If you play 5 consecutive attacks, draw a card. Grants Donate Cleats: for 5 tempo, grant 5 AGI and 4 DEX to an ally (35 mana, 0 tempo)."
	return item

static func create_boot_holsters() -> ItemData:
	var item = _new_boot("Boot Holsters", Rarity.LEGENDARY, 5)
	item.card_slots = 3
	item.wisdom_bonus = 3
	item.agility_bonus = 3
	item.dexterity_bonus = 1
	item.on_self_instant_damage_nearest = 10
	item.on_self_attack_tempo_reduction = 1
	item.description = "+3 WIS, +3 AGI, +1 DEX. On-self: if an instant, deal 10 damage to the nearest enemy within 3 squares; if an attack card, -1 tempo."
	return item

static func create_elemental_trail_blazers() -> ItemData:
	var item = _new_boot("Elemental Trail Blazers", Rarity.LEGENDARY, 10)
	item.intelligence_bonus = 5
	item.agility_bonus = 5
	item.fire_trail_damage = 5
	item.fire_trail_tempo = 3
	item.description = "+5 INT, +5 AGI. When moving with flash points, leave a trail of fire. Each fire spot deals 5 damage (scales with INT) then extinguishes; fire persists 3 tempo."
	return item

static func create_mountain_boots() -> ItemData:
	var item = _new_boot("Mountain Boots", Rarity.LEGENDARY, 40)
	item.health_bonus = 15
	item.highground_damage_percent = 20.0
	# GAP (granted card): "Terrain formation" (create a walkable hill) — needs terrain support.
	item.description = "+15 health. When attacking from high ground, gain an additional 20% damage. Grants Terrain formation: create a hill you can walk on for 5 tempo (25 mana, 3 tempo)."
	return item

static func create_houdinis_slippers() -> ItemData:
	var item = _new_boot("Houdinis Slippers", Rarity.LEGENDARY, 2)
	item.card_slots = 1
	item.health_bonus = -10
	item.on_self_invisible_tempo = 5  # slotted card → invisible 5 tempo
	# GAP (granted card): "Escape and bewilder" (blink + AOE stun) — needs a movement+stun card.
	item.description = "-10 health. On-self: become invisible for 5 tempo (standard invisibility rules). Grants Escape and bewilder: blink up to 5 spaces and stun all enemies within 3 of the space you left for 3 tempo (50 mana, 2 tempo)."
	return item

static func create_boots_of_the_balancer() -> ItemData:
	var item = _new_boot("Boots of the Balancer", Rarity.MYTHIC, 15)
	item.card_slots = 1
	item.health_bonus = 15
	item.wisdom_bonus = 3
	item.strength_bonus = 5
	item.determination_bonus = 2
	item.on_self_armor_per_missing_health10 = 5  # 5 armor per 10% missing health
	# GAP (granted card): "Tight rope" (below-20%-HP instant) — needs a threshold reaction card.
	item.description = "+15 health, +3 WIS, +5 STR, +2 DET. On-self: gain 5 armor for each 10% health you are missing. Grants Tight rope (Instant): when damage puts you below 20% health, gain 20 temp health and 15 Strengthen. Upgraded: each 6% missing health; Tight rope gains a second copy."
	return item

static func create_hermes_boots() -> ItemData:
	var item = _new_boot("Hermes Boots", Rarity.MYTHIC, 0)
	item.card_slots = 4
	item.agility_bonus = 4
	item.on_self_flash_regen = 1  # slotted card restores 1 flash point
	item.trap_damage_percent = 25.0  # stored; applies once the trap system exists
	item.description = "+4 AGI. On-self: restore 1 flash point. Your traps deal 25% more damage. Upgraded: +6 AGI; traps deal 50% more."
	return item

static func create_jordan_1s() -> ItemData:
	var item = _new_boot("Jordan 1s", Rarity.MYTHIC, 10)
	item.agility_bonus = 8
	item.determination_bonus = 8
	item.strength_bonus = 8
	item.dexterity_bonus = 8
	item.missing_life_damage_rate = 0.5  # +0.5 damage per missing enemy-health %
	item.missing_life_threshold = 50     # ...only while the enemy is at/below 50% health
	item.description = "+8 AGI, +8 DET, +8 STR, +8 DEX. Below 50% enemy health, your hits deal +0.5 damage per missing health %. Upgraded: 10/10/10/10."
	return item

static func create_guardian_greaves() -> ItemData:
	var item = _new_boot("Guardian Greaves", Rarity.MYTHIC, 40)
	item.intelligence_bonus = 5
	item.wisdom_bonus = 4
	item.strength_bonus = 5
	# GAP (rider): grants "Mend" (AOE heal/mana/armor); per-cycle regen + resist aura.
	item.description = "+5 INT, +4 WIS, +5 STR. Each cycle, give 10 health and mana regen to all allies within 4 squares, plus 5% physical resistance. Grants Mend: restore 20% health and 20% mana and grant armor to all allies within 4 squares based on health restored (30 mana, 4 tempo). Upgraded: 40% / 40%."
	return item

static func create_chain_crocs() -> ItemData:
	var item = _new_boot("Chain Crocs", Rarity.RARE, 35)
	item.card_slots = 2
	item.agility_bonus = -4
	item.wisdom_bonus = -2
	item.on_self_mana_reduction_percent = 20.0
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 5
	item.armor_per_tempo_interval = 15
	item.description = "-4 AGI, -2 WIS. On-self: mana cost reduced 20%. Gain 5 armor every 15 tempo while equipped (counter resets when unequipped)."
	return item

static func create_knife_toed_boots() -> ItemData:
	var item = _new_boot("Knife Toed Boots", Rarity.RARE, 30)
	item.agility_bonus = -3
	item.dexterity_bonus = 2
	item.strength_bonus = 5
	var knife_cards: Array[String] = ["shiv"]
	item.granted_card_ids = knife_cards
	item.melee_crit_flat_bonus = 10  # melee crits deal +10 flat (no scaling)
	item.description = "-3 AGI, +2 DEX, +5 STR. When melee offensive cards crit, deal an additional flat 10 damage. Grants shiv: melee, 2 damage (5 mana, 1 tempo)."
	return item

static func create_boots_of_speed() -> ItemData:
	var item = _new_boot("Boots of Speed", Rarity.RARE, 1)
	item.agility_bonus = 5
	item.dexterity_bonus = 5
	item.movement_flash_tempo_threshold = 51  # 51 movement-flash spent → -1 tempo from a hand card
	item.description = "+5 AGI, +5 DEX. After an accumulated 51 flash points spent on movement, remove 1 tempo from a card in your hand."
	return item

static func create_caster_boots() -> ItemData:
	var item = _new_boot("Caster Boots", Rarity.RARE, 15)
	item.card_slots = 1
	item.intelligence_bonus = 6
	item.agility_bonus = 2
	item.wisdom_bonus = 2
	item.on_self_int_damage_percent = 10.0  # +10% of INT as bonus damage on slotted cards
	item.description = "+6 INT, +2 AGI, +2 WIS. On-self: deal an additional 10% damage based on your INT."
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
