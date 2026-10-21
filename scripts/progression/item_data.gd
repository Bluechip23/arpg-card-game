class_name ItemData
extends Resource

## Defines an item's properties

enum ItemType { HELM, CHEST, RING, BELT, BOOTS, GAUNTLETS, WEAPON, QUIVER, SCROLL }
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

#region RARITY & FORGE LEVELS
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
@export var unerring_cap_bonus: int = 0  # +X to the unerring armor cap while worn (PlayerStats.get_unerring_cap)
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

# Gauntlet skill system
@export var gauntlet_skill_type: GauntletSkillType = GauntletSkillType.NONE
@export var gauntlet_skill_name: String = ""
@export var gauntlet_skill_description: String = ""
@export var gauntlet_skill_cooldown: int = 0  # Turns for active skills
@export var gauntlet_skill_mana_cost: int = 0  # For active skills
@export var gauntlet_skill_effect_id: String = ""  # Identifier for the effect

# Card slot system. Two kinds of slot:
#   card_slots    — BONUS slots: a card here gains the item's on-self riders
#                   (and, on a colored-slot item, that slot's color/payload).
#   vanilla_slots — PLAIN slots: the card only lives here (it joins the deck
#                   beyond the 8 base cards, engravings included) and gets
#                   no on-self bonus at all. Added 2026-10-20 so a build has
#                   somewhere to keep its weapon-labelled cards without every
#                   weapon handing out riders. Not upgradeable for now.
# Bonus slots fill first: slot indices 0..card_slots-1 are bonus, the rest
# vanilla; a card's index is stamped when it is slotted (slot_color_index) and
# kept for its whole stay, so a neighbor leaving never moves it.
@export var card_slots: int = 0  # Number of BONUS card slots this item has
@export var vanilla_slots: int = 0  # Number of plain, bonus-free card slots
var slotted_cards: Array = []  # Cards currently in the slots
var allowed_card_keywords: Array = []  # Empty = any card allowed. e.g. [Card.CardKeyword.ARROW] = only arrow cards

# Colored card slots (Mauls Sabre — the first of its kind; nothing else uses
# this yet). When slot_colors is non-empty, slot index i is the color
# slot_colors[i], and slot_effects[i] is that slot's OWN on-self payload —
# effects belong to the colored slot, not the item as a whole. Payload keys:
#   damage: +X damage when the slotted card is played (offensive only)
#   block: +X block when the slotted card is played
#   weaken / vulnerable: applied to the target on a damaging hit
#   discard: discard X random cards from the hand on play
#   combo_after: the color that primes this slot's combo — it fires when this
#     slot's card is played IMMEDIATELY after that color (any other play in
#     between breaks the chain):
#   combo_vulnerable: ...the target also takes X Vulnerable
#   combo_tempo: ...the play costs X less tempo
@export var slot_colors: Array = []
@export var slot_effects: Array = []
var last_color_played: String = ""  # runtime: this item's color if its card was the most recent play, else ""

## The color of the slot the card occupies ("" when uncolored/not slotted).
## The colored-slot index this card occupies. Stamped at slot time and kept
## for the card's whole stay, so unslotting a NEIGHBOR never silently
## reassigns this card's color, payload, or combo identity.
func _slot_index_of(card) -> int:
	if card != null and card is Object and card.has_meta("slot_color_index"):
		return int(card.get_meta("slot_color_index"))
	return slotted_cards.find(card)

## Every slot the item offers: bonus slots first, then the plain ones.
func total_card_slots() -> int:
	return card_slots + vanilla_slots

## The lowest slot index not currently occupied (-1 when full). Bonus slots
## (below card_slots) come first, so a card always takes a rider-bearing slot
## while one is open.
func _next_free_slot_index() -> int:
	var taken := {}
	for c in slotted_cards:
		taken[_slot_index_of(c)] = true
	for i in range(total_card_slots()):
		if not taken.has(i):
			return i
	return -1

## True when the card sits in one of this item's plain (vanilla) slots.
func is_vanilla_slot(card) -> bool:
	var idx := _slot_index_of(card)
	return idx >= card_slots

## The on-self bonus THIS card gets: the item's riders in a bonus slot, the
## neutral (all-zero) bonus in a vanilla slot. Every consumer that prices a
## slotted card goes through here (Card.get_on_self_bonus).
func get_on_self_bonus_for(card) -> Dictionary:
	if is_vanilla_slot(card):
		return neutral_on_self_bonus()
	return get_on_self_bonus()

static func slot_words(item) -> String:
	## "3 slots (1 bonus, 2 plain)" — the panel's one phrase for an item's slots.
	var total: int = item.total_card_slots()
	if item.vanilla_slots <= 0:
		return "%d slot%s" % [total, "" if total == 1 else "s"]
	return "%d slots (%d bonus, %d plain)" % [total, item.card_slots, item.vanilla_slots]

static var _neutral_osb: Dictionary = {}

## The bonus of an item with no riders at all — the same keys get_on_self_bonus
## returns, at their defaults (0, 1.0 for multipliers, false, "").
static func neutral_on_self_bonus() -> Dictionary:
	if _neutral_osb.is_empty():
		var blank := ItemData.new()
		_neutral_osb = blank.get_on_self_bonus()
	return _neutral_osb

func get_slot_color(card) -> String:
	var idx = _slot_index_of(card)
	if idx >= 0 and idx < slot_colors.size():
		return str(slot_colors[idx])
	return ""

## The payload of the colored slot the card occupies ({} when none).
func get_slot_effect(card) -> Dictionary:
	var idx = _slot_index_of(card)
	if idx >= 0 and idx < slot_effects.size() and slot_effects[idx] is Dictionary:
		return slot_effects[idx]
	return {}

# Granted cards (GRANT_CARDS / GRANT_BLINK_CARD). Built once the first time the
# item is equipped, then reused for the item's lifetime so the SAME instances
# come and go with the item on every swap — preserving per-card state (jail
# time, enhancement) across equip/unequip. Slotted (enchanted) cards
# live in slotted_cards; together they are the item's "owned" cards.
var granted_card_instances: Array = []
var granted_cards_built: bool = false

#endregion
#region ON-SELF SLOTTED-CARD BONUSES
# On-self bonuses (extra bonuses applied to cards slotted in this item)
@export var on_self_damage: int = 0
@export var on_self_block: int = 0
@export var on_self_heal: int = 0  # heal cards heal +X; a card that doesn't heal heals YOU X instead (Trench of Tranquility 5)
@export var on_self_self_heal: int = 0  # heal YOU X whenever the slotted card is played, whatever the card (Velvet Plate 5)
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
@export var on_self_armor_per_missing_health10: int = 0  # armor per missing-health step on slotted play (Boots of the Balancer 5)
@export var on_self_missing_health_step: int = 10        # % of missing health per armor grant (Balancer Lv3 tightens to 6)
@export var on_self_instant_damage_nearest: int = 0  # slotted instant → X damage to nearest enemy within 3 (Boot Holsters 10)
@export var on_self_attack_tempo_reduction: int = 0  # slotted attack costs X less tempo (Boot Holsters 1)
@export var on_self_invisible_tempo: int = 0       # slotted card → become invisible X tempo (Houdinis Slippers 5)
@export var on_self_melee_damage: int = 0          # +X damage on slotted MELEE offensive cards (Roman Bracers 5)
@export var on_self_crit_damage_percent: float = 0.0  # +X% crit damage for the slotted play (Feathered Hat 10)
@export var on_self_flash_counter_drain: int = 0   # slotted play drains X from the flash-crit counter (Feathered Hat 2)
@export var on_self_defense_armor: int = 0         # slotted DEFENSE card grants +X armor (Slotted Sash 3)
@export var on_self_utility_weaken: int = 0        # slotted UTILITY card weakens a random enemy within 5 (Slotted Sash 1)
@export var on_self_physical_resilient: int = 0    # slotted play: X% physical resist for 10 tempo (Strap of Stone 10)
@export var on_self_strengthen_value: int = 0      # slotted play: Strengthen +X... (Belt of Wumbology 10)
@export var on_self_strengthen_attacks: int = 0    # ...for X attacks (Belt of Wumbology 2)
@export var on_self_cleanse_stacks: int = 0        # slotted play: cleanse X stacks of a random debuff on the card's target (Corset 3)
@export var on_self_damage_while_invisible: int = 0  # slotted cards +X damage while invisible (Shadow Obi 5)
@export var on_self_taunt_cycles: int = 0          # slotted OFFENSIVE card taunts the enemy target X cycles (Girdle 3)
@export var on_self_support_heal: int = 0          # slotted UTILITY/DEFENSE card heals its target X (Girdle 15)
@export var on_self_damage_multiplier: float = 1.0 # slotted card damage x this (Megingjord 2.0)
@export var on_self_mana_multiplier: float = 1.0   # slotted card mana cost x this (Megingjord 2.0)

# Belt passive riders
@export var on_self_offensive_damage: int = 0      # slotted OFFENSIVE cards +X damage (Slotted Sash 3)
@export var on_self_apply_vulnerable: int = 0      # slotted offensive card applies X Vulnerable (Assasian Belt 1)
@export var on_self_target_aoe_damage: int = 0     # slotted card play detonates X AOE damage around its target (Tactical belt 2)
@export var on_self_utility_tempo_refund: int = 0  # slotted UTILITY cards cost X less tempo (Potion Belt 1)
@export var debuff_removed_conjure_id: String = "" # losing a debuff conjures this card into hand (Corset of Cure)
@export var heal_bonus_max_health_percent: float = 0.0  # heal cards add X% of YOUR max health (Alchemist belt 4)
@export var cheap_card_zap_damage: int = 0         # playing a card under 2 tempo zaps a random enemy for X (Shadow Obi 3)
@export var on_self_draw_card: int = 0             # draw X cards when a slotted card is played (Momentum Mits 1)
@export var on_self_summon_wolf: int = 0           # summon X wolves when a slotted card is played (Dungeon Mastering 1)
@export var on_self_root_offensive: int = 0        # slotted offensive card roots the target X cycles (Gravity Gauntlets 1)
@export var on_self_disarm_offensive: int = 0      # slotted offensive card Disarms the target 5 tempo per stack (Spidey 1)

# Weapon on-self riders (weapons pass 1)
@export var on_self_crit_percent: float = 0.0            # +% crit chance for the slotted play, any card (Rusty Dagger 15)
@export var on_self_weakened_damage_percent: float = 0.0 # +% damage vs Weakened targets, on top of Weaken itself (Bessy 25)
@export var on_self_max_hp_damage_percent: float = 0.0   # +damage equal to X% of YOUR max health (Hammer of Ajax 10)
@export var on_self_self_targets_allies: bool = false    # slotted self-target cards may target allies (Laurentius's Lost Spear)
@export var on_self_overdrive_multiplier: float = 1.0    # deal Xx damage; take HALF the bonus as self-damage (Fallen's Wrath 1.5)
@export var on_self_apply_slow: int = 0                  # slotted attacks apply X slow (Sword of Theseus 2, Lv3 3)
@export var on_self_slow_damage_per_stack: int = 0       # +X damage per slow stack already on the target (Theseus 1)

# Weapon passive riders (weapons pass 1)
@export var bonus_damage_to_armor: int = 0        # your attacks shred X extra enemy armor — armor only (Armor Chopper 10)
@export var shield_synergy: bool = false          # while ANY hand holds a shield: +1 melee reach, +2 melee damage (Spartan Spear)
@export var offhand_pair_bonus: bool = false      # in OFF hand beside a non-shield main weapon: weightless + slotted cards -1 tempo (Side Card Sabre)
@export var kill_flash_points: int = 0            # +X flash points per kill — MAY exceed the cap (Axe's Axe 5)
@export var attack_speed_threshold_bonus: int = 0 # attack-speed proc threshold +X while wielded — heavy iron swings slow (Bessy 5)
@export var wrath_weapon: bool = false            # Fallen's Wrath: +1 Wrath per damage instance taken (max 30); attacks +Wrath damage; 10+ Wrath = take +50%
@export var vitality_weapon: bool = false         # Nine Ruins: +1 Vitality per attack (max 9); +1% lifesteal +2 damage per stack; 9 summons the penguin
@export var same_target_bleed: int = 0            # Sabre Tooth: 2nd consecutive hit on one target: +1 attack-speed tick + X bleed
@export var pierce_targets: int = 0               # attacks strike X squares in a line through the target (Poseidons Trident 2, Lv3 3)
@export var armor_gain_melee_damage: int = 0      # gaining armor deals X damage to an enemy in melee range (Umbral Eclipse 5, Lv3 8)
@export var insight_flash_restore: int = 0        # Insight (brain-point) draws restore X flash points (Umbral Eclipse 2, Lv3 3)
#endregion
#region SHIELD RIDERS (shields pass 1)
# ============================================
# SHIELD RIDERS (shields pass 1)
# ============================================
# On-self riders: these ride cards slotted INTO the shield.
@export var on_self_fortify: int = 0             # slotted play grants Fortify — armor stops decaying (Sword Breaker 1)
@export var on_self_knockback: int = 0           # slotted card knocks its target back X squares (Vengeful Shield 1)
@export var on_self_discard: int = 0             # slotted play discards X cards from hand (Slotted Rope Half Sleeve 1)
@export var on_self_lifesteal_percent: float = 0.0  # slotted cards carry X% lifesteal (Coffin Lid 10)
@export var on_self_chance_boost: float = 0.0    # +X percentage points to a slotted card's rolls (Delfins 10)
@export var on_self_block_max_mana_percent: float = 0.0  # slotted play grants block worth X% of MAX mana (Presence of Mind 10, Lv2 15)

# Always-on shield passives.
@export var flat_damage_reduction: int = 0       # every incoming hit is cut by X, flat (Buckler 3, Vanguard 3)
@export var melee_retaliate_bleed: int = 0       # a melee attacker takes X Bleed for striking you (Wooden Shield 1)
@export var regen_per_cycle: int = 0             # gain X Regen every cycle (Vanguard 1)
@export var thorns_per_cycle: int = 0            # gain X Thorns every cycle (Spiked Shield 1)
@export var blocked_melee_tempo_tax: int = 0     # melee damage your armor swallows whole adds X tempo to that enemy's next melee attack (Sword Breaker 2)
@export var low_health_lifesteal_bonus: float = 0.0  # +X% lifesteal below half health (Coffin Lid 8)
@export var flash_points_bonus: int = 0          # +X max flash points (Slotted Rope Half Sleeve 4)
@export var damage_taken_mana_gain: int = 0      # gain X mana whenever an enemy damages you (Steve Rodgers 5)
@export var duelist_shield: bool = false         # Crooked Dueling Shield: the full-block / crit Weaken-Vulnerable engine

# Overdraw riders — they fire when a draw overflows a full hand.
@export var overdraw_heal: int = 0               # heal X (Castle Wall 5)
@export var overdraw_regen: int = 0              # gain X Regen (Treebeards Branch 3)
@export var overdraw_peak: int = 0               # reveal the next X draw-pile cards (Delfins 4)
@export var overdraw_card_id: String = ""        # conjure this card into the manifest zone (Slotted Rope Half Sleeve: cinquedea)
@export var overdraw_card_max: int = 0           # ...up to X held there at once (5)
@export var overdraw_card_block: int = 0         # each one held grants +X block on block cards (1)
@export var overdraw_spell_id: String = ""       # cast this on overdraw, paying its mana and a charge (Castle Wall: rain_of_arrows)
@export var overdraw_spell_mana: int = 0         # what the cast costs (45)
@export var overdraw_spell_charges: int = 0      # charge capacity (3)
@export var overdraw_spell_recharge: int = 0     # tempo per charge regained — charges refill even when some remain (15)
# Shield runtime state (reset on equip/unequip like the chest accumulators)
var overdraw_charges_left: int = 0   # charges in hand right now
var overdraw_recharge_accum: int = 0 # tempo banked toward the next charge
var conjured_in_manifest: int = 0    # Cinquedea copies currently parked in the manifest zone

# Off-hand state (set by Inventory on every equip/swap/unequip): EVERYTHING
# about a weapon is 10% weaker in the off hand, not just its stat block —
# flat channels and on-self riders scale by OFF_HAND_RIDER_SCALE (floored),
# and per-hit integer riders roll a 10% fizzle at their consumption sites
# (exactly 10% weaker in expectation, no rounding cliffs on 1-3 stack
# riders). Maluses keep full strength — a softer drawback would be a buff.
# Shields and quivers are exempt: they are off-hand items by design.
var is_in_off_hand: bool = false
const OFF_HAND_RIDER_SCALE := 0.9

func rider_scale() -> float:
	return OFF_HAND_RIDER_SCALE if is_in_off_hand else 1.0

## Per-application off-hand roll for integer on-hit riders.
func rider_fizzles() -> bool:
	return is_in_off_hand and randf() < (1.0 - OFF_HAND_RIDER_SCALE)

# On-self benefit keys the off-hand penalty scales (see get_on_self_bonus).
# Maluses (surcharges, jail tempo, self-discards) and structural keys
# (booleans, step sizes, durations, the Side Card Sabre's own off-hand pair
# bonus) are deliberately absent.
const _OFF_HAND_SCALED_ON_SELF := [
	"damage", "block", "heal", "mana_reduction", "mana_reduction_percent",
	"apply_burn", "apply_cold", "apply_bleed", "apply_shock", "apply_weaken",
	"apply_vulnerable", "apply_slow", "slow_damage_per_stack", "thorns",
	"range_offensive", "crit_ranged_percent", "utility_heal",
	"utility_spell_damage", "brain_regen", "armor_any", "reaction_armor",
	"flash_regen", "int_damage_percent", "armor_per_missing_health10",
	"instant_damage_nearest", "attack_tempo_reduction", "melee_damage",
	"crit_damage_percent", "defense_armor", "utility_weaken",
	"physical_resilient", "strengthen_value", "cleanse_stacks",
	"damage_while_invisible", "support_heal", "offensive_damage",
	"target_aoe_damage", "utility_tempo_refund", "draw_card", "summon_wolf",
	"root_offensive", "disarm_offensive", "crit_percent",
	"weakened_damage_percent", "max_hp_damage_percent", "ranged_damage",
	"ranged_tempo_reduction", "resist_all_percent", "offensive_shift",
	"offensive_heal_percent", "armor_shred", "chance_boost",
	"lifesteal_percent", "knockback", "fortify", "block_max_mana_percent",
	"bounce_percent",
]

# Weapon runtime state (reset on equip/unequip like the chest accumulators)
var pair_active: bool = false   # Side Card Sabre: currently paired with a main-hand weapon
var wrath: int = 0              # Fallen's Wrath counter
var vitality_stacks: int = 0    # Nine Ruins: current Vitality

# Chest on-self riders (chests pass 1)
@export var on_self_ranged_damage: int = 0         # +X damage on slotted RANGED offensive cards (Elvish Cloak 2, Chewbaccas 5)
@export var on_self_ranged_tempo_reduction: int = 0  # slotted RANGED offensive cards cost X less tempo (Chewbaccas 1)
@export var on_self_resist_all_percent: float = 0.0  # slotted play: X% resist to ALL damage types... (Smithed Excellence 2)
@export var on_self_resist_all_tempo: int = 0        # ...for X tempo (Smithed Excellence 3)
@export var on_self_offensive_shift: int = 0       # slotted offensive card: shift X spaces after the hit (Shadow Cowl 2)
@export var on_self_offensive_heal_percent: float = 0.0  # slotted offensive card heals X% of max health (Tigers Sunday Red 5)
@export var on_self_adaptive_damage_type: bool = false   # slotted card deals its damage as the target's LOWEST resistance type, fire checked first (Blue Robe)

# Gauntlet passive riders
@export var armor_gain_thorns_threshold: int = 0   # every X armor gained... (Spiked Mitts 25)
@export var armor_gain_thorns_amount: int = 0      # ...gain X thorns (Spiked Mitts 5)
@export var armor_loss_regen_threshold: int = 0    # every X armor removed → 1 regen stack (Hallowed Trunk 10)
@export var regen_include_health: bool = false     # Hallowed Trunk Lv3: health lost counts too
@export var draw_every_cycles: int = 0             # draw 1 card every X cycles (Cuffs of Current 3)
@export var crit_damage_percent: float = 0.0       # +X% crit damage multiplier (Sleeved Katar 25)

# Boots pass-2 passive riders
@export var sidestep_bonus_armor: int = 0          # +armor on a flash sidestep (Titanium Toe Tuckers 2)
@export var movement_flash_discount: int = 0       # movement flash costs X less (Rollerblades 1)
@export var movement_flash_tempo_threshold: int = 0  # after X movement flash spent, -1 tempo from a hand card (Boots of Speed 36)
@export var highground_damage_percent: float = 0.0  # +X% damage while attacking from high ground (Mountain Boots 20)
@export var trap_damage_percent: float = 0.0        # traps you spring on ENEMIES deal +X% (Hermes Boots 25)
@export var missing_life_damage_rate: float = 0.0   # +rate × enemy missing-health% as bonus damage (Jordan 1s 0.5)
@export var missing_life_threshold: int = 0         # only below this enemy health% (Jordan 1s 50)
@export var melee_crit_flat_bonus: int = 0          # flat extra damage when a melee attack crits (Knife Toed Boots 10)
@export var consecutive_attack_draw: int = 0        # draw a card after X consecutive attacks (Cyde Livingstons Sneakers 5)
@export var fire_trail_damage: int = 0              # >0 enables the fire trail; spots deal INT/5 damage (Elemental Trail Blazers)
@export var fire_trail_tempo: int = 0               # how long a fire spot persists (Elemental Trail Blazers 3)
@export var ally_regen_per_cycle: int = 0           # health per cycle to allies in radius (Guardian Greaves 6)
@export var ally_mana_per_cycle: int = 0            # mana per cycle to allies in radius (Guardian Greaves 60)
@export var ally_regen_radius: int = 0              # aura radius in tiles (Guardian Greaves 4)
@export var ally_physical_resist: float = 0.0       # % physical resist to allies in radius (Guardian Greaves 5)

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
@export var on_self_apply_shock: int = 0  # Apply X shock stacks on hit (Shock Quiver 2)
@export var on_self_apply_weaken: int = 0  # Apply X weaken stacks on hit (Improvised Ammo rides on this too)

# Ranged on-self riders (ranged pass 1). All of these apply only to cards
# slotted into the item that carries them — the "arrows fired from this
# bow/quiver" model.
@export var on_self_armor_shred: int = 0        # slotted hit shreds X extra enemy armor, armor only (Quiver of Wet Stones 4)
@export var on_self_tempo_penalty: int = 0      # slotted cards cost X MORE tempo; negative = less (Tightened Cross Bow +1, Stringless Sender -1)
@export var on_self_double_shot: bool = false   # slotted offensive card hits its target a second time at full damage (The Rapid Recurve)
@export var on_self_jail_tempo: int = 0         # slotted card is jailed X tempo after play instead of discarding (The Rapid Recurve 20)
@export var on_self_bounce_percent: float = 0.0 # X% chance a slotted shot bounces to the nearest other enemy at full damage, crit result mimicked (Stringless Sender 20)
@export var on_self_mana_to_life: bool = false  # half a slotted card's mana cost is paid as LIFE instead (Bow of Arash)
@export var on_self_kill_summon_skeleton: bool = false  # a kill with a slotted card raises a skeleton at 50% of the victim's max health (Sack of Bone Arrows)
@export var on_self_conjure_on_play_id: String = ""     # playing a slotted card puts a copy of this card into the hand (Belthronding: close_is_favored)
@export var on_self_crit_bud_bow: bool = false  # a crit with a slotted card buds a spirit-bow turret; also arms the per-bow-instance damage/crit stacking (Bow of Budding Blasts)

# Ranged passive riders (not on-self — always on while equipped)
@export var ally_damage_share_percent: float = 0.0  # you take X% of damage allies/summons deal within the radius (Belthronding 10)
@export var ally_damage_share_radius: int = 0       # radius in squares for the share above (Belthronding 3)

#endregion
#region SPELL WEAPON RIDERS (spell weapons pass 1)
# ============================================
# SPELL WEAPON RIDERS (spell weapons pass 1)
# ============================================
# Global on-hit debuffs: unlike the on_self_apply_* family these ride EVERY
# damaging offensive card the wielder plays, not just cards slotted here.
@export var attack_apply_burn: int = 0        # your damaging attacks apply X Burn (Fire Book 1)
@export var attack_apply_cold: int = 0        # ... X Cold (Frost Book 1, Ice Orb 2)
@export var attack_apply_shock: int = 0       # ... X Shock (Car Battery 3)
@export var attack_debuffs_on_self_only: bool = false  # the attack_apply_* riders only ride cards slotted in this item (Car Battery)
@export var attack_apply_silence: int = 0     # ... X Silence (Circe's Wand 1)
@export var attack_apply_vulnerable: int = 0  # ... X Vulnerable (Reaper Scythe 1)

# Always-on spell weapon passives.
@export var discard_gain_block: int = 0            # discarding a card grants X block (Abjurers Cane 3)
@export var range_bonus_all_cards: int = 0         # +X range on ALL cards (Wand of Deliverance 2)
@export var spell_mana_surcharge_percent: float = 0.0   # offensive SPELL cards cost X% more mana (Blast Stick 10)
@export var spell_damage_per_mana_percent: float = 0.0  # offensive SPELL cards deal +X% of their FINAL (surcharged) mana cost as damage (Blast Stick 20)
@export var elemental_charge_damage: int = 0       # applying Burn/Shock/Cold deals +X damage per stack applied (Elemental Weaver 1)
@export var burn_backlash_self: int = 0            # applying Burn to an enemy burns YOU X — per occasion, not per stack (Phoenix Feather 1)
@export var no_debuff_mana_discount_percent: float = 0.0  # ALL cards cost X% less while you carry no debuffs (Wand of Clarity 15)
@export var melee_retaliate_shock: int = 0         # a melee attacker takes X Shock for striking you (Reaction Rod 4)
@export var card_pull_target: int = 0              # every targeted card play pulls its target X squares toward you — allies included (Shepherds Crook 1)
@export var reaper_weapon: bool = false            # Reaper Scythe: targets above half health suffer 10% lifesteal; below, 10% of the damage returns as mana and the card costs 10% less
@export var feral_weapon: bool = false             # Feral Evocation: the colored-slot element-conversion engine
@export var feral_change_damage: int = 0           # damage to a random enemy within 4 squares each time a slotted card changes color (Feral Evocation 4, Lv3 6)

# Passive bonuses
@export var ranged_damage_bonus: int = 0  # +X damage to all ranged attacks
@export var healing_bonus: int = 0  # +X to all healing effects
@export var block_bonus_to_defense_cards: int = 0  # +X armor added to armor-granting defense cards
@export var block_to_armorless_defense_cards: int = 0  # defense cards granting NO armor grant X instead (Burgonet)
@export var damage_bonus_to_attack_cards: int = 0  # +X damage to all attack cards
@export var damage_bonus_to_melee_cards: int = 0   # +X damage to melee offensive cards only (Brass Knuckles)
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
@export var auto_purge_per_cycle: int = 0        # cleanse X of the wearer's debuffs per purge tick (Horned Nasal Helm)
@export var auto_purge_interval_cycles: int = 1  # cycles between purge ticks (Horned Nasal 3 = every 15 tempo)
@export var void_resistance_percent: float = 0.0  # nearby enemies take +X% damage — "lowered resistance" (Mane)
@export var void_resistance_radius: int = 0       # aura radius in tiles (Mane 2)
@export var summon_heal_aura: int = 0             # heal summons below 25% HP within 3 tiles by X/cycle (Frankensteins Screws)

# On-kill card conjuring (Bladed Doughnut): every enemy kill while this item
# is equipped adds a fresh copy of this card directly to the hand.
@export var on_kill_card_id: String = ""

# Chest passive riders (chests pass 1)
@export var block_physical_resist_percent: float = 0.0  # while you have armor up, +X% physical resist (Smithed Excellence 10)
@export var casing_damage: int = 0        # >0: playing a ranged offensive card drops a bullet casing dealing X (Chewbaccas Bandolier 8)
@export var casing_tempo: int = 0         # casing self-detonates after X tempo if nothing steps on it (Chewbaccas 5)
@export var damage_bank_percent: float = 0.0  # absorb X% of every damage instance into the cuirass as a stack (Supernova Cuirass 10)
@export var damage_bank_mitigate_percent: float = 0.0  # a further X% of the hit is mitigated outright while stacks have room (Supernova 2)
@export var damage_bank_max_stacks: int = 0   # stack cap (Supernova 10)
@export var exposed_armor_gain: int = 0       # gain X armor when your armor is BROKEN THROUGH (Briarhide 5, Adimantium 10)
@export var exposed_armor_cooldown_cycles: int = 0  # cycles between procs; 0 = no cooldown (Adimantium 15, Lv3 10; Briarhide none)
@export var low_health_regen: int = 0         # gain X Regen when dropping below 50% health (Wooden Plank 1)
@export var gold_gain_heal: int = 0           # heal X whenever you obtain gold (Suit and Tie 3)
@export var movement_tempo_penalty: int = 0   # each tile moved on tempo costs X extra tempo (Adimantium 1)
@export var ranged_range_bonus: int = 0       # +X range on ALL ranged offensive cards while equipped (Tigers Sunday Red 1)
@export var hp_diff_damage_divisor: int = 0   # bonus damage % = (your health% - enemy health%) / X, never below 0 (Tigers 4, Lv3 3)
@export var resist_per_missing10: float = 0.0 # +X% resist to all damage types per missing-health step (Divine Resistance 1.0, Lv3 1.5)
@export var resist_missing_step: int = 10     # % of missing health per resist grant (Divine Resistance 8, Lv3 7)
@export var death_crit_stack_radius: int = 0  # Garmr Lv3: any death within X squares grants a stack (2)
@export var death_crit_damage_per_stack: float = 0.0  # each stack: +X% crit damage; at 5 stacks purge + 10% current health self-damage (Garmr 5)

# Runtime tracking
var current_cooldown: int = 0  # Current cooldown remaining
# ARMOR_PER_TURN accumulator: tempo banked toward the next armor grant. Reset
# to 0 on equip/unequip so the counter restarts (per the helm spec).
var armor_per_tempo_accum: int = 0
# Chest pass runtime state (reset on equip/unequip alongside the armor accum)
var banked_damage: float = 0.0     # Supernova Cuirass: total damage banked across stacks
var banked_stacks: int = 0         # Supernova Cuirass: current stack count
var exposed_armor_cd_left: int = 0 # Exposed-armor proc cooldown, in cycles remaining
var death_crit_stacks: int = 0     # Hide of Garmr Lv3: current death stacks
# Ring pass: cumulative proc counters, keyed per ring ("heal", "shield",
# "burn", "hits", "cd", ...). One journey — these NEVER reset; they live and
# die with the item instance.
var ring_counters: Dictionary = {}

# Description
@export var description: String = ""

#endregion
#region APPEARANCE (mythics)
# ============================================
# APPEARANCE (mythics)
# ============================================
# A mythic is a thing you can picture, not just a stat line: `appearance`
# describes what it LOOKS like, and `appearance_icon` points at the 32x32
# sprite drawn from that description (assets/items/mythic/, generated by
# tools/generate_mythic_icons.py). While the mythic is equipped the inventory
# swaps the generic slot silhouette for this art and prints the description
# under it in the item detail panel.
@export var appearance: String = ""
@export var appearance_icon: String = ""

## Where the mythics' own art lives; every `appearance_icon` in data/items
## points under it (test_mythic_appearance checks that).
const APPEARANCE_ICON_DIR := "res://assets/items/mythic/"


## Give an item its appearance text and the icon of the same slug.
func has_appearance_art() -> bool:
	return appearance_icon != "" and ResourceLoader.exists(appearance_icon)

## The item's own art, or null when it has none (everything but the mythics).
func get_appearance_texture() -> Texture2D:
	if not has_appearance_art():
		return null
	return load(appearance_icon) as Texture2D

#endregion
#region RARITY & FORGE LEVEL HELPERS
# ============================================
# RARITY & FORGE LEVEL HELPERS
# ============================================

## Shop prices by rarity (placeholder economy — tune freely); a forged item
## is worth half again per level. Selling pays half.
const GOLD_VALUE_BY_RARITY := {
	Rarity.COMMON: 40,
	Rarity.RARE: 120,
	Rarity.LEGENDARY: 350,
	Rarity.MYTHIC: 900,
}

func gold_value() -> int:
	var base: int = int(GOLD_VALUE_BY_RARITY.get(rarity, 40))
	return int(round(base * (1.0 + 0.5 * float(maxi(0, item_level - 1)))))

func sell_value() -> int:
	return maxi(1, floori(gold_value() / 2.0))

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.LEGENDARY: return "Legendary"
		Rarity.MYTHIC: return "Mythic"
	return "Unknown"

func get_rarity_color() -> Color:
	# Town scrolls read maroon in the inventory, whatever their rarity.
	if special_id == "return_scroll":
		return Color(0.55, 0.12, 0.18)
	return rarity_color_of(rarity)

## The rarity palette (shared with cards): Common grey, Rare orange,
## Legendary purple, Mythic pink.
static func rarity_color_of(r: Rarity) -> Color:
	match r:
		Rarity.COMMON: return Color(0.62, 0.62, 0.66)
		Rarity.RARE: return Color(1.0, 0.6, 0.2)
		Rarity.LEGENDARY: return Color(0.6, 0.4, 0.95)
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
			"block_bonus_to_defense_cards", "damage_bonus_to_attack_cards",
			"damage_bonus_to_melee_cards"]:
		var value: int = get(prop)
		if value > 0:
			set(prop, value + 1)
	# Periodic-armor pieces (Kettle Hat, Mail Coif, Chain Crocs, Brass
	# Knuckles…) carry their number in special_effect_value: +1 per grant.
	if special_effect == SpecialEffect.ARMOR_PER_TURN and special_effect_value > 0:
		special_effect_value += 1

## Rewrite properties from an overrides dict — the machinery behind both the
## Lv.2 bespoke boost and the Lv.3 transformation. Typed arrays are assigned
## in place, and overriding the granted card list resets its built
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
		if prop == "granted_card_ids":
			cards_changed = true
	if cards_changed:
		granted_card_instances.clear()
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
		ItemType.SCROLL: return "Scroll"
	return "Unknown"

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

#endregion
#region CARD SLOT SYSTEM
# ============================================
# CARD SLOT SYSTEM
# ============================================

func has_card_slots() -> bool:
	return total_card_slots() > 0

func get_free_card_slots() -> int:
	return max(0, total_card_slots() - slotted_cards.size())

func can_slot_card(card) -> bool:
	if slotted_cards.size() >= total_card_slots():
		return false
	return _slot_gate_ok(card, _next_free_slot_index())

## Whether `card` may take slot `index` specifically (the manage-cards window
## drags a card onto a chosen square): the slot must exist and be free, and
## the same label / colour gate as can_slot_card applies at that index.
func can_slot_card_at(card, index: int) -> bool:
	if index < 0 or index >= total_card_slots():
		return false
	for c in slotted_cards:
		if _slot_index_of(c) == index:
			return false
	return _slot_gate_ok(card, index)

## Whether a card already slotted HERE may move to slot `index` (a drag
## between two squares of the same item): the square must be free and, on a
## coloured-slot item, match the card's element. Its label passed when it
## was slotted.
func can_move_slotted_card_to(card, index: int) -> bool:
	if card == null or card.slotted_in_item != self:
		return false
	if index < 0 or index >= total_card_slots():
		return false
	for c in slotted_cards:
		if _slot_index_of(c) == index:
			return false
	if feral_weapon and index < slot_colors.size() and card.element != str(slot_colors[index]):
		return false
	return true

## The gates shared by every slotting path, for the slot at `index`.
func _slot_gate_ok(card, index: int) -> bool:
	# A card an item provides is part of that item's kit — it can never be
	# slotted into anything (including the item that granted it).
	if card.granted_by_item != null:
		return false
	# One home per card: a card already enchanted into an item can't also be
	# slotted into another.
	if card.slotted_in_item != null:
		return false
	# Feral Evocation: each colored slot takes only a card of its element —
	# red Burn, blue Cold, yellow Shock, green Poison. The slot's color is
	# the gate (a plain slot past the colors takes any labeled card).
	if feral_weapon:
		if index >= 0 and index < slot_colors.size():
			if card.element != str(slot_colors[index]):
				return false
	# Slot labels: an unlabeled card lives in the deck only and can never be
	# slotted; a labeled card may go into any slot one of its labels names.
	if not card.is_slottable():
		return false
	if allowed_card_keywords.size() > 0:
		# Explicit allow-list on the item: any shared label will do.
		var ok := false
		for kw in card.slot_labels:
			if kw in allowed_card_keywords:
				ok = true
				break
		if not ok:
			return false
	else:
		# Default restrictions based on item type
		var required = _get_default_keyword_for_item_type()
		if required >= 0 and not card.has_slot_label(required):
			return false
	return true

## Returns the default required card label for this item type (-1 = any
## LABELED card; unlabeled cards are refused by can_slot_card regardless).
func _get_default_keyword_for_item_type() -> int:
	match item_type:
		ItemType.BELT: return Card.CardKeyword.POCKET
		ItemType.BOOTS: return Card.CardKeyword.SWIFT
		ItemType.RING: return Card.CardKeyword.GEM
		ItemType.HELM: return Card.CardKeyword.CROWN
		ItemType.GAUNTLETS: return Card.CardKeyword.FIST
		ItemType.QUIVER: return Card.CardKeyword.ARROW
		ItemType.CHEST: return Card.CardKeyword.BULWARK
		ItemType.WEAPON:
			match weapon_subtype:
				WeaponSubtype.BOW: return Card.CardKeyword.ARROW
				WeaponSubtype.SHIELD: return Card.CardKeyword.BUCKLER
				WeaponSubtype.SWORD: return Card.CardKeyword.SWORD
				WeaponSubtype.AXE: return Card.CardKeyword.AXE
				WeaponSubtype.DAGGER: return Card.CardKeyword.DAGGER
				WeaponSubtype.HAMMER: return Card.CardKeyword.HAMMER
				WeaponSubtype.POLEARM: return Card.CardKeyword.SPEAR
				WeaponSubtype.WAND: return Card.CardKeyword.WAND
				WeaponSubtype.TOME: return Card.CardKeyword.WAND  # Tome folded into Wand (2026-10-20)
				WeaponSubtype.STAFF: return Card.CardKeyword.STAFF
				_: return -1  # "Other" weapons take any labeled card
	return -1

func slot_card(card) -> bool:
	if not can_slot_card(card):
		return false
	# The lowest free slot (bonus slots first).
	return _take_slot(card, _next_free_slot_index())

## Slot the card into slot `index` (a dragged drop on a chosen square).
func slot_card_at(card, index: int) -> bool:
	if not can_slot_card_at(card, index):
		return false
	return _take_slot(card, index)

func _take_slot(card, idx: int) -> bool:
	# Stamp the slot the card takes BEFORE appending, so its color/payload
	# identity survives neighbors unslotting.
	slotted_cards.append(card)
	card.set_meta("slot_color_index", idx if idx >= 0 else slotted_cards.size() - 1)
	card.slotted_in_item = self
	# Laurentius's Lost Spear: slotted self-target cards may also aim at allies
	# (a rider, so bonus slots only).
	if on_self_self_targets_allies and not is_vanilla_slot(card) and card.target_types.has("self") and not card.target_types.has("ally"):
		card.target_types.append("ally")
		card.set_meta("ally_target_granted", true)
	print("[ITEM] %s: slotted card '%s' (%d/%d slots%s)" % [item_name, card.card_name, slotted_cards.size(), total_card_slots(), ", plain slot" if is_vanilla_slot(card) else ""])
	return true

func unslot_card(card_index: int):
	if card_index < 0 or card_index >= slotted_cards.size():
		return null
	var card = slotted_cards[card_index]
	slotted_cards.remove_at(card_index)
	card.slotted_in_item = null
	if card.has_meta("slot_color_index"):
		card.remove_meta("slot_color_index")
	# Take back the Laurentius ally-targeting grant with the slot.
	if card.get_meta("ally_target_granted", false):
		card.target_types.erase("ally")
		card.remove_meta("ally_target_granted")
	print("[ITEM] %s: unslotted card '%s' (%d/%d slots)" % [item_name, card.card_name, slotted_cards.size(), total_card_slots()])
	return card

func get_on_self_bonus() -> Dictionary:
	var osb := {
		"damage": on_self_damage,
		"block": on_self_block,
		"heal": on_self_heal,
		"self_heal": on_self_self_heal,
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
		"missing_health_step": on_self_missing_health_step,
		"instant_damage_nearest": on_self_instant_damage_nearest,
		"attack_tempo_reduction": on_self_attack_tempo_reduction,
		"invisible_tempo": on_self_invisible_tempo,
		"melee_damage": on_self_melee_damage,
		"crit_damage_percent": on_self_crit_damage_percent,
		"flash_counter_drain": on_self_flash_counter_drain,
		"defense_armor": on_self_defense_armor,
		"utility_weaken": on_self_utility_weaken,
		"physical_resilient": on_self_physical_resilient,
		"strengthen_value": on_self_strengthen_value,
		"strengthen_attacks": on_self_strengthen_attacks,
		"cleanse_stacks": on_self_cleanse_stacks,
		"damage_while_invisible": on_self_damage_while_invisible,
		"taunt_cycles": on_self_taunt_cycles,
		"support_heal": on_self_support_heal,
		"damage_multiplier": on_self_damage_multiplier,
		"mana_multiplier": on_self_mana_multiplier,
		"offensive_damage": on_self_offensive_damage,
		"apply_vulnerable": on_self_apply_vulnerable,
		"target_aoe_damage": on_self_target_aoe_damage,
		"utility_tempo_refund": on_self_utility_tempo_refund,
		"draw_card": on_self_draw_card,
		"summon_wolf": on_self_summon_wolf,
		"root_offensive": on_self_root_offensive,
		"disarm_offensive": on_self_disarm_offensive,
		"crit_percent": on_self_crit_percent,
		"weakened_damage_percent": on_self_weakened_damage_percent,
		"max_hp_damage_percent": on_self_max_hp_damage_percent,
		"overdrive_multiplier": on_self_overdrive_multiplier,
		"apply_slow": on_self_apply_slow,
		"slow_damage_per_stack": on_self_slow_damage_per_stack,
		"pair_tempo_reduction": 1 if (offhand_pair_bonus and pair_active) else 0,
		"ranged_damage": on_self_ranged_damage,
		"ranged_tempo_reduction": on_self_ranged_tempo_reduction,
		"resist_all_percent": on_self_resist_all_percent,
		"resist_all_tempo": on_self_resist_all_tempo,
		"offensive_shift": on_self_offensive_shift,
		"offensive_heal_percent": on_self_offensive_heal_percent,
		"adaptive_damage_type": on_self_adaptive_damage_type,
		"apply_shock": on_self_apply_shock,
		"apply_weaken": on_self_apply_weaken,
		"armor_shred": on_self_armor_shred,
		"tempo_penalty": on_self_tempo_penalty,
		"double_shot": on_self_double_shot,
		"jail_tempo": on_self_jail_tempo,
		"bounce_percent": on_self_bounce_percent,
		"mana_to_life": on_self_mana_to_life,
		"kill_summon_skeleton": on_self_kill_summon_skeleton,
		"conjure_on_play_id": on_self_conjure_on_play_id,
		"crit_bud_bow": on_self_crit_bud_bow,
		"fortify": on_self_fortify,
		"knockback": on_self_knockback,
		"discard": on_self_discard,
		"lifesteal_percent": on_self_lifesteal_percent,
		"chance_boost": on_self_chance_boost,
		"block_max_mana_percent": on_self_block_max_mana_percent,
	}
	# Off hand: every benefit this weapon's slots confer is 10% weaker too
	# (floored for ints). Only positive values scale — a negative
	# mana_reduction is a surcharge, and maluses keep their full bite.
	if is_in_off_hand:
		for osb_k in _OFF_HAND_SCALED_ON_SELF:
			var osb_v = osb.get(osb_k)
			if osb_v is int and osb_v > 0:
				osb[osb_k] = floori(osb_v * OFF_HAND_RIDER_SCALE)
			elif osb_v is float and osb_v > 0.0:
				osb[osb_k] = osb_v * OFF_HAND_RIDER_SCALE
	return osb

#endregion
#region ITEM CATALOGUE (data/items/*.tres)
# ============================================
# ITEM CATALOGUE (data/items/*.tres)
# ============================================

## Every item is a .tres under data/items, named by id. The order here is the
## catalogue order (loot pools index into it), so keep new items at the end
## of their group rather than sorting the list.
const ITEM_DIR := "res://data/items"
const ITEM_IDS: Array[String] = [
	"return_scroll",
	"wooden_sword",
	"bladed_doughnut",
	"leather_cap",
	"baseball_hat",
	"kettle_hat",
	"mail_coif",
	"dragon_skull",
	"feathered_hat",
	"frankensteins_screws",
	"horned_nasal_helm",
	"the_headbandz",
	"scholars_cap",
	"hannibals_mask",
	"mane_of_narashimha",
	"shamans_mask",
	"wizard_hat",
	"dunce_cap",
	"burgonet",
	"summoners_cap",
	"thick_steel_helm",
	"monocle",
	"theif_hat",
	"leather_boots",
	"blink_boots",
	"cloth_slippers",
	"brown_boots",
	"steel_boots",
	"titanium_toe_tuckers",
	"rollerblades",
	"cyde_livingstons_sneakers",
	"boot_holsters",
	"elemental_trail_blazers",
	"mountain_boots",
	"houdinis_slippers",
	"boots_of_the_balancer",
	"hermes_boots",
	"jordan_1s",
	"guardian_greaves",
	"chain_crocs",
	"knife_toed_boots",
	"boots_of_speed",
	"caster_boots",
	"chain_gloves",
	"leather_gauntlets",
	"brass_knuckles",
	"cloth_bracer",
	"mits_of_chingiz",
	"techno_wraps",
	"spidey_web_shooters",
	"gravity_gauntlets",
	"spiked_mitts",
	"momentum_mits",
	"sleeved_katar",
	"gauntlets_of_dungeon_mastering",
	"hallowed_trunk",
	"cuffs_of_current",
	"concealed_carry",
	"medic_wraps",
	"roman_bracers",
	"copper_bracers",
	"fanned_bracers",
	"leather_belt",
	"waistband",
	"studded_belt",
	"band_of_aid",
	"holster",
	"tactical_belt",
	"assasian_belt",
	"potion_belt",
	"the_slotted_sash",
	"equator",
	"strap_of_stone",
	"belt_of_wumbology",
	"corset_of_cure",
	"alchemeist_belt",
	"shadow_obi",
	"belt_of_scrolls",
	"megingjord",
	"orions_belt",
	"girdle_of_aphrodite",
	"pick",
	"rusty_dagger",
	"pocket_knife",
	"construction_hammer",
	"short_sword",
	"wooden_spear",
	"armor_chopper",
	"lions_halberd",
	"spartan_spear",
	"side_card_sabre",
	"axes_axe",
	"bessy",
	"hammer_of_ajax",
	"laurentius_lost_spear",
	"mauls_sabre",
	"fallens_wrath",
	"nine_ruins_of_sanguine",
	"sabre_tooth",
	"poseidons_trident",
	"sword_of_theseus",
	"umbral_eclipse",
	"bloodbound_plate",
	"wooden_plank",
	"elvish_cloak",
	"steel_plate",
	"tattered_cloth",
	"velvet_plate",
	"buffed_leather",
	"chain_mail",
	"suit_and_tie",
	"smithed_excellence",
	"shadow_cowl",
	"chewbaccas_bandolier",
	"supernova_cuirass",
	"trench_of_tranquility",
	"briarhide_plate",
	"blue_robe",
	"adimantium",
	"tigers_sunday_red",
	"divine_resistance",
	"hide_of_garmr",
	"short_bow",
	"boomerang",
	"cross_bow",
	"standard_quiver",
	"fire_quiver",
	"quiver_of_wet_stones",
	"frost_quiver",
	"shock_quiver",
	"long_bow",
	"tightened_cross_bow",
	"sack_of_bone_arrows",
	"wrist_rocket",
	"cupids_bow",
	"the_rapid_recurve",
	"capacious_extremus",
	"stringless_sender",
	"bow_of_arash",
	"belthronding",
	"bow_of_budding_blasts",
	"buckler",
	"wooden_shield",
	"vengeful_shield",
	"vanguard",
	"spiked_shield",
	"castle_wall",
	"sword_breaker",
	"coffin_lid",
	"treebeards_branch",
	"slotted_rope_half_sleeve",
	"elemental_emblem",
	"delfins_deterministic_round_shield",
	"steve_rodgers_bastion",
	"presence_of_mind",
	"crooked_dueling_shield",
	"frost_book",
	"fire_book",
	"earth_book",
	"magic_staff",
	"wand_of_deliverance",
	"ice_orb",
	"car_battery",
	"abjurers_cane",
	"wand_of_clarity",
	"reaction_rod",
	"shepherds_crook",
	"blast_stick",
	"elemental_weaver",
	"wand_of_the_phoenix_feather",
	"circes_wand_of_cauldron_stirring",
	"reaper_scythe",
	"feral_evocation",
	"heal_stone",
	"gold_band",
	"emerald",
	"friendship_ring",
	"scholars_signet",
	"diamond_ring",
	"captain_planets_circlet",
	"cyclops_ring",
	"ring_of_stone_hide",
	"legend_has_it",
	"harnessed_sun",
	"marvolo_gaunt",
	"the_precious",
	"ring_of_nibelung",
	"draupnir",
	"ring_of_thomas_the_train_tracks",
]

## A fresh level-1 instance of the item with this id (the .tres file name).
## Items are mutable (forge levels, slotted cards, cooldowns), so every call
## hands out its own deep copy of the loaded resource.
static func create(id: String) -> ItemData:
	var base := load("%s/%s.tres" % [ITEM_DIR, id]) as ItemData
	if base == null:
		push_error("[ItemData] no item '%s'" % id)
		return null
	return base.duplicate(true)

## One fresh instance of every item, in catalogue order.
static func get_all_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for id in ITEM_IDS:
		items.append(create(id))
	return items

## Fresh level-1 instances of every item of the given rarity (used for
## rarity-weighted loot and for redeeming Mythic Molds).
# Items that exist in the catalogue but must never roll as random loot:
# the Return Scroll (a utility every character already carries) and Olorin's
# tutorial trade sword. (The Bladed Doughnut stays listed — Mythic Mold
# redemption enumerates mythics through get_items_of_rarity.)
const DROP_EXCLUDED_ITEM_NAMES := {
	"Return Scroll": true, "Wooden Sword": true,
}

static func get_items_of_rarity(r: Rarity) -> Array[ItemData]:
	var items: Array[ItemData] = []
	for item in get_all_items():
		if item.rarity == r and not DROP_EXCLUDED_ITEM_NAMES.has(item.item_name):
			items.append(item)
	return items

## Recreate a fresh level-1 instance of an item by name (forge fodder checks,
## mold redemption). Returns null for unknown names.
# Old item names that live on in saved data (owned_mythic_names, molds).
const RENAMED_ITEMS := {
	"Hanibals Mask": "Hannibals Mask",
}

static func create_by_name(item_name_to_find: String) -> ItemData:
	if RENAMED_ITEMS.has(item_name_to_find):
		item_name_to_find = RENAMED_ITEMS[item_name_to_find]
	for item in get_all_items():
		if item.item_name == item_name_to_find:
			return item
	return null
#endregion
