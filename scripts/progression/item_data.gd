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
@export var on_self_disarm_offensive: int = 0      # slotted offensive card disarms the target for X ATTACKS (Spidey 1)

# Weapon on-self riders (weapons pass 1)
@export var on_self_crit_percent: float = 0.0            # +% crit chance for the slotted play, any card (Rusty Dagger 15)
@export var on_self_weakened_damage_percent: float = 0.0 # +% damage vs Weakened targets, on top of Weaken itself (Bessy 25)
@export var on_self_max_hp_damage_percent: float = 0.0   # +damage equal to X% of YOUR max health (Hammer of Ajax 10)
@export var on_self_self_targets_allies: bool = false    # slotted self-target cards may target allies (Laurentius's Lost Spear)
@export var on_self_overdrive_multiplier: float = 1.0    # deal Xx damage; take HALF the bonus as self-damage (Fallen's Wrath 1.5)
@export var on_self_apply_slow: int = 0                  # slotted attacks apply X slow (Sword of Theseus 2, Lv3 3)
@export var on_self_slow_damage_per_stack: int = 0       # +X damage per slow stack already on the target (Theseus 1)
# Mauls Sabre: slotted offensive plays alternate ends — the maul end (+8
# damage, 5 armor shred), then the sabre end (-1 tempo, +15% crit). The
# runtime parity lives in end_swings (runtime tracking block).
@export var on_self_alternating_ends: bool = false

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
@export var movement_flash_tempo_threshold: int = 0  # after X movement flash spent, -1 tempo from a hand card (Boots of Speed 51)
@export var highground_damage_percent: float = 0.0  # +X% damage while attacking from high ground (Mountain Boots 20)
@export var trap_damage_percent: float = 0.0        # traps you spring on ENEMIES deal +X% (Hermes Boots 25)
@export var missing_life_damage_rate: float = 0.0   # +rate × enemy missing-health% as bonus damage (Jordan 1s 0.5)
@export var missing_life_threshold: int = 0         # only below this enemy health% (Jordan 1s 50)
@export var melee_crit_flat_bonus: int = 0          # flat extra damage when a melee attack crits (Knife Toed Boots 10)
@export var consecutive_attack_draw: int = 0        # draw a card after X consecutive attacks (Cyde Livingstons Sneakers 5)
@export var fire_trail_damage: int = 0              # >0 enables the fire trail; spots deal INT/5 damage (Elemental Trail Blazers)
@export var fire_trail_tempo: int = 0               # how long a fire spot persists (Elemental Trail Blazers 3)
@export var ally_regen_per_cycle: int = 0           # heal+mana per cycle to allies in radius (Guardian Greaves 10)
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
var end_swings: int = 0            # Mauls Sabre: offensive plays so far — even parity swings the maul end, odd the sabre end

# Description
@export var description: String = ""

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

const APPEARANCE_ICON_DIR := "res://assets/items/mythic/"

## Give an item its appearance text and the icon of the same slug.
static func _set_appearance(item: ItemData, slug: String, text: String) -> void:
	item.appearance = text
	item.appearance_icon = APPEARANCE_ICON_DIR + slug + ".png"

func has_appearance_art() -> bool:
	return appearance_icon != "" and ResourceLoader.exists(appearance_icon)

## The item's own art, or null when it has none (everything but the mythics).
func get_appearance_texture() -> Texture2D:
	if not has_appearance_art():
		return null
	return load(appearance_icon) as Texture2D

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
	# Town scrolls read maroon in the inventory, whatever their rarity.
	if special_id == "return_scroll":
		return Color(0.55, 0.12, 0.18)
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
		ItemType.SCROLL: return "Scroll"
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
	# A card an item provides is part of that item's kit — it can never be
	# slotted into anything (including the item that granted it).
	if card.granted_by_item != null:
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
	# Laurentius's Lost Spear: slotted self-target cards may also aim at allies.
	if on_self_self_targets_allies and card.target_types.has("self") and not card.target_types.has("ally"):
		card.target_types.append("ally")
		card.set_meta("ally_target_granted", true)
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
	# Take back the Laurentius ally-targeting grant with the slot.
	if card.get_meta("ally_target_granted", false):
		card.target_types.erase("ally")
		card.remove_meta("ally_target_granted")
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
		"alternating_ends": on_self_alternating_ends,
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
	## inventory to open a town portal where you stand. The portal's twin
	## appears in town, and stepping through either end crosses over.
	var item = ItemData.new()
	item.item_name = "Return Scroll"
	item.item_type = ItemType.SCROLL  # utility scroll — never equips
	item.item_type_name = "Scroll"
	item.rarity = Rarity.COMMON
	item.weight = 0
	item.special_id = "return_scroll"
	item.description = "Right-click to open a portal back to town. Walk in with [Shift]. Its twin waits in town to bring you back."
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
	_set_appearance(item, "bladed_doughnut",
		"A ring of fried dough gone wrong. The outer rim is hammered steel filed into eight razor teeth, and the pink glaze poured over the top never quite dries. The sprinkles are slivers of bone.")
	item.level_3_overrides = {
		"on_kill_card_id": "sprinkle_bomb",
	}
	item.level_3_description = "+16 STR. On Kill: add a Sprinkle Bomb to your hand (0 mana, 0 tempo, 25 damage AOE)."
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
	item.card_slots = 2
	item.flash_crit_threshold = 25  # spend 25 flash → next ranged offensive card crits
	item.on_self_damage = 5
	item.on_self_crit_damage_percent = 10.0
	item.on_self_flash_counter_drain = 2
	item.description = "+8 AGI, 2 card slots. On-self: +5 damage, +10% crit damage, and -2 from the flash point counter. Once you have spent an accumulated 25 flash points, your next ranged offensive card crits (resets to 0 on use)."
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
	item.auto_purge_per_cycle = 2       # purge 2 random debuffs...
	item.auto_purge_interval_cycles = 3  # ...every 3 cycles (15 tempo)
	item.description = "+6 DET. On-self: if an offensive card, apply 1 Bleed. Purge 2 random debuffs every 15 tempo while equipped."
	return item

static func create_the_headbandz() -> ItemData:
	var item = _new_helm("The Headbandz", Rarity.MYTHIC, 8)
	item.card_slots = 5
	item.on_self_mana_reduction_percent = 20.0
	var headbandz_cards: Array[String] = ["out_of_guesses"]
	item.granted_card_ids = headbandz_cards
	item.description = "No stats. Cards slotted in its 5 slots cost 20% less mana. Grants Out of Guesses: discard your whole hand and draw that many cards (15 mana / 3 tempo)."
	_set_appearance(item, "the_headbandz",
		"A headband with three cards slotted upright across the front, faces out — everyone can read them but you.")
	item.level_3_overrides = {"on_self_mana_reduction_percent": 35.0}
	# Out of Guesses dropping to 1 tempo at Lv.3 is read live off item_level
	# (see Card.get_burden_tempo_cost).
	item.level_3_description = "No stats. Cards slotted in its 5 slots cost 35% less mana. Grants Out of Guesses: discard your whole hand and draw that many cards (15 mana / 1 tempo)."
	return item

static func create_scholars_cap() -> ItemData:
	var item = _new_helm("Scholars Cap", Rarity.MYTHIC, 5)
	item.card_slots = 2
	item.wisdom_bonus = 5
	item.brain_points_bonus = 5
	item.peek_brain_discount = 1
	item.on_self_brain_regen = 2  # slotted cards regain 2 brain points on play
	item.level_3_overrides = {"wisdom_bonus": 7, "brain_points_bonus": 7, "on_self_brain_regen": 3}
	item.level_3_description = "+7 WIS, +7 max brain points. Peek costs 1 less brain point. On-self: regain 3 brain points."
	item.description = "+5 WIS, +5 max brain points. Peek costs 1 less brain point. On-self: regain 2 brain points. Upgraded: +7 WIS, +7 max brain points; on-self regains 3."
	_set_appearance(item, "scholars_cap",
		"A stiff black mortarboard with a gold tassel that never stops swinging, even in still air. The underside of the board is inked edge to edge with equations somebody kept correcting.")
	return item

static func create_hannibals_mask() -> ItemData:
	var item = _new_helm("Hannibals Mask", Rarity.MYTHIC, 5)
	item.health_bonus = 25
	item.card_slots = 2
	item.lifesteal_percent = 15.0
	var hannibals_cards: Array[String] = ["resourceful_replenish"]
	item.granted_card_ids = hannibals_cards
	item.description = "+25 life. On-self: 15% lifesteal. Grants Resourceful Replenish (Maintain): your attacks lifesteal 5% (20 mana, 2 tempo)."
	_set_appearance(item, "hannibals_mask",
		"Hannibal Lecter's mask: a hard leather muzzle strapped over the lower face, with a steel grille bolted across the mouth.")
	item.level_3_overrides = {"health_bonus": 50}
	# Resourceful Replenish maintaining at 8% at Lv.3 is read live off item_level
	# (see the maintained-lifesteal block in Card.execute).
	item.level_3_description = "+50 life. On-self: 15% lifesteal. Grants Resourceful Replenish (Maintain): your attacks lifesteal 8% (20 mana, 2 tempo)."
	return item

static func create_mane_of_narashimha() -> ItemData:
	var item = _new_helm("Mane of Narashimha", Rarity.MYTHIC, 15)
	item.strength_bonus = 10
	item.intelligence_bonus = 5
	item.determination_bonus = 5
	item.card_slots = 1
	var mane_cards: Array[String] = ["neither_man_nor_beast"]
	item.granted_card_ids = mane_cards
	item.void_resistance_percent = 5.0  # nearby enemies take +5% damage (lowered resistance)
	item.void_resistance_radius = 2
	item.level_3_overrides = {"strength_bonus": 12, "intelligence_bonus": 7,
		"determination_bonus": 7, "void_resistance_percent": 8.0}
	item.level_3_description = "+12 STR, +7 INT, +7 DET. Grants Neither Man nor Beast. Void resistance aura: lower all nearby enemies' resistances by 8% (2-square radius)."
	_set_appearance(item, "mane_of_narashimha",
		"An enormous lion's mane. It hoods the top of the head and falls all the way down the back to mid-spine.")
	item.description = "+10 STR, +5 INT, +5 DET. Grants Neither Man nor Beast: deal 10 base damage ignoring all resistances and armor; target cannot heal that damage for 10 tempo (Narashimha) (10 mana, 2 tempo). Void resistance aura: lower all nearby enemies' resistances by 5% (2-square radius)."
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
	item.block_bonus_to_defense_cards = 2      # armor-granting defense cards: +2 on top
	item.block_to_armorless_defense_cards = 2  # armorless defense cards: grant 2
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
	item.on_self_crit_ranged_percent = 25.0
	var monocle_cards: Array[String] = ["twenty_twenty"]
	item.granted_card_ids = monocle_cards
	item.description = "+10% crit chance. On-self: if an offensive ranged card, gain +5 range and 25% crit. Grants 20/20 (Maintain): gain 3 range on all ranged offensive cards (25 mana, 3 tempo)."
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
	item.agility_bonus = 3
	item.description = "+3 AGI."
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
	var roller_cards: Array[String] = ["shift"]
	item.granted_card_ids = roller_cards
	item.description = "+6 AGI, +5 STR. On-self: if an instant, gain 10 armor in addition to its effect. -1 cost to movement flash points. Grants shift: move 2 spaces for free (0 mana / 0 tempo)."
	return item

static func create_cyde_livingstons_sneakers() -> ItemData:
	var item = _new_boot("Cyde Livingstons Sneakers", Rarity.LEGENDARY, 10)
	item.agility_bonus = 5
	item.dexterity_bonus = 4
	item.consecutive_attack_draw = 5  # 5 consecutive attacks → draw a card
	var cyde_cards: Array[String] = ["donate_cleats"]
	item.granted_card_ids = cyde_cards
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
	item.description = "+5 INT, +5 AGI. When moving with flash points, leave a trail of fire. Each fire spot deals INT/5 damage then extinguishes; fire persists 3 tempo."
	return item

static func create_mountain_boots() -> ItemData:
	var item = _new_boot("Mountain Boots", Rarity.LEGENDARY, 40)
	item.health_bonus = 15
	item.highground_damage_percent = 20.0
	var mountain_cards: Array[String] = ["terrain_formation"]
	item.granted_card_ids = mountain_cards
	item.description = "+15 health. When attacking from high ground, gain an additional 20% damage. Grants Terrain formation: create a hill you can walk on for 5 tempo (25 mana, 3 tempo)."
	return item

static func create_houdinis_slippers() -> ItemData:
	var item = _new_boot("Houdinis Slippers", Rarity.LEGENDARY, 2)
	item.card_slots = 1
	item.health_bonus = -10
	item.on_self_invisible_tempo = 5  # slotted card → invisible 5 tempo
	var houdini_cards: Array[String] = ["escape_and_bewilder"]
	item.granted_card_ids = houdini_cards
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
	var balancer_cards: Array[String] = ["tight_rope"]
	item.granted_card_ids = balancer_cards
	item.level_3_overrides = {"on_self_missing_health_step": 6,
		"granted_card_ids": ["tight_rope", "tight_rope"]}
	item.level_3_description = "+16 health, +4 WIS, +6 STR, +3 DET. On-self: gain 5 armor for each 6% health you are missing. Grants two copies of Tight rope."
	_set_appearance(item, "boots_of_the_balancer",
		"The thin, flexible shoes a tightrope walker works in.")
	item.description = "+15 health, +3 WIS, +5 STR, +2 DET. On-self: gain 5 armor for each 10% health you are missing. Grants Tight rope (Instant): when damage puts you below 20% health, gain 20 temp health and 15 Strengthen. Upgraded: each 6% missing health; Tight rope gains a second copy."
	return item

static func create_hermes_boots() -> ItemData:
	var item = _new_boot("Hermes Boots", Rarity.MYTHIC, 0)
	item.card_slots = 4
	item.agility_bonus = 4
	item.on_self_flash_regen = 1  # slotted card restores 1 flash point
	item.trap_damage_percent = 25.0  # stored; applies once the trap system exists
	item.level_3_overrides = {"agility_bonus": 6, "trap_damage_percent": 50.0}
	item.level_3_description = "+6 AGI. On-self: restore 1 flash point. Your traps deal 50% more damage."
	item.description = "+4 AGI. On-self: restore 1 flash point. Your traps deal 25% more damage. Upgraded: +6 AGI; traps deal 50% more."
	_set_appearance(item, "hermes_boots",
		"Hermes' famous slippers, with a feathered wing sweeping off each side.")
	return item

static func create_jordan_1s() -> ItemData:
	var item = _new_boot("Jordan 1s", Rarity.MYTHIC, 10)
	item.agility_bonus = 6
	item.determination_bonus = 7
	item.strength_bonus = 7
	item.dexterity_bonus = 6
	item.missing_life_damage_rate = 0.5  # +0.5 damage per missing enemy-health %
	item.missing_life_threshold = 50     # ...only while the enemy is at/below 50% health
	item.level_3_overrides = {"agility_bonus": 8, "determination_bonus": 9,
		"strength_bonus": 9, "dexterity_bonus": 8}
	item.level_3_description = "+8 AGI, +9 DET, +9 STR, +8 DEX. Below 50% enemy health, your hits deal +0.5 damage per missing health %."
	item.description = "+6 AGI, +7 DET, +7 STR, +6 DEX. Below 50% enemy health, your hits deal +0.5 damage per missing health %."
	_set_appearance(item, "jordan_1s",
		"Black and red Jordan 1s.")
	return item

static func create_guardian_greaves() -> ItemData:
	var item = _new_boot("Guardian Greaves", Rarity.MYTHIC, 40)
	item.intelligence_bonus = 5
	item.wisdom_bonus = 4
	item.strength_bonus = 5
	item.ally_regen_per_cycle = 6
	item.ally_regen_radius = 4
	item.ally_physical_resist = 5.0
	var guardian_cards: Array[String] = ["mend"]
	item.granted_card_ids = guardian_cards
	# Mend restoring 40%/40% at Lv.3 is read live off item_level (see the mend
	# world effect in main.gd); no field changes at Lv.3.
	item.level_3_description = "+6 INT, +5 WIS, +6 STR. Each cycle, give 6 health and mana regen to all allies (you included) within 4 squares, plus 5% physical resistance. Grants Mend: restore 40% health and 40% mana and grant armor to all allies within 4 squares based on health restored (30 mana, 4 tempo)."
	item.description = "+5 INT, +4 WIS, +5 STR. Each cycle, give 6 health and mana regen to all allies (you included) within 4 squares, plus 5% physical resistance. Grants Mend: restore 20% health and 20% mana and grant armor to all allies within 4 squares based on health restored (30 mana, 4 tempo)."
	# Modelled on DOTA 2's Guardian Greaves.
	_set_appearance(item, "guardian_greaves",
		"Holy plate warboots, steel banded in gold and winged at the ankle, with a healing light spilling out of the seams.")
	return item

static func create_chain_crocs() -> ItemData:
	var item = _new_boot("Chain Crocs", Rarity.RARE, 35)
	item.card_slots = 2
	item.agility_bonus = -2
	item.wisdom_bonus = -2
	item.on_self_mana_reduction_percent = 20.0
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 5
	item.armor_per_tempo_interval = 15
	item.description = "-2 AGI, -2 WIS. On-self: mana cost reduced 20%. Gain 5 armor every 15 tempo while equipped (counter resets when unequipped)."
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
	item.agility_bonus = 4
	item.dexterity_bonus = 3
	item.movement_flash_tempo_threshold = 36  # 36 movement-flash spent → -1 tempo from a hand card
	item.description = "+4 AGI, +3 DEX. After an accumulated 36 flash points spent on movement, remove 1 tempo from a card in your hand."
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
# GAUNTLETS (first gauntlets pass — hands slot)
# ============================================
# Skill cooldowns tick once per 5-tempo cycle, so the spec's tempo values are
# stored as cycles (20t=4, 15t=3, 10t=2, 8t=2, 25t=5).
static func _new_gauntlet(nm: String, r: Rarity, wt: int) -> ItemData:
	var item = ItemData.new()
	item.item_name = nm
	item.item_type = ItemType.GAUNTLETS
	item.item_type_name = "Gauntlets"
	item.rarity = r
	item.weight = wt
	return item

static func _set_skill(item: ItemData, nm: String, desc: String, effect_id: String, cd_cycles: int) -> void:
	item.gauntlet_skill_type = GauntletSkillType.ACTIVE
	item.gauntlet_skill_name = nm
	item.gauntlet_skill_description = desc
	item.gauntlet_skill_effect_id = effect_id
	item.gauntlet_skill_cooldown = cd_cycles

static func create_chain_gloves() -> ItemData:
	var item = _new_gauntlet("Chain Gloves", Rarity.COMMON, 15)
	item.strength_bonus = 2
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 1
	item.armor_per_tempo_interval = 15
	_set_skill(item, "Guard", "Gain 2 armor.", "chain_guard", 4)
	item.description = "+2 STR. Gain 1 armor every 15 tempo. Skill — Guard: gain 2 armor (20 tempo CD)."
	return item

static func create_leather_gauntlets() -> ItemData:
	var item = _new_gauntlet("Leather gauntlets", Rarity.COMMON, 5)
	item.hand_size_bonus = 1
	item.health_bonus = 5
	item.description = "+1 hand size, +5 life."
	return item

static func create_brass_knuckles() -> ItemData:
	var item = _new_gauntlet("Brass Knuckles", Rarity.COMMON, 10)
	item.damage_bonus_to_melee_cards = 2
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 1
	item.armor_per_tempo_interval = 20
	item.description = "+2 damage on melee offensive cards. Gain 1 armor every 20 tempo."
	return item

static func create_cloth_bracer() -> ItemData:
	var item = _new_gauntlet("Cloth bracer", Rarity.COMMON, 5)
	item.hand_size_bonus = 1
	item.dexterity_bonus = 2
	_set_skill(item, "Band aid", "Heal 5 HP.", "band_aid", 4)
	item.description = "+1 hand size, +2 DEX. Skill — Band aid: heal 5 HP (20 tempo CD)."
	return item

static func create_mits_of_chingiz() -> ItemData:
	var item = _new_gauntlet("Mits of Chingiz", Rarity.LEGENDARY, 5)
	item.determination_bonus = 2
	item.strength_bonus = 5
	item.agility_bonus = 2
	var chingiz_cards: Array[String] = ["stance_switch"]
	item.granted_card_ids = chingiz_cards
	# "3 count" is a cooldown passive handled in main: two offensive cards in a
	# row add a Switch Kick to the hand (20 tempo CD).
	item.gauntlet_skill_type = GauntletSkillType.PASSIVE
	item.gauntlet_skill_name = "3 count"
	item.gauntlet_skill_description = "Playing two offensive cards in a row adds a Switch Kick to your hand."
	item.gauntlet_skill_effect_id = "three_count"
	item.gauntlet_skill_cooldown = 4  # 20 tempo, read by main's 3 count trigger
	item.description = "+2 DET, +5 STR, +2 AGI. Grants Stance Switch: remove 10 armor from the enemy and apply 2 Vulnerable. 3 count: playing two offensive cards in a row adds a Switch Kick to your hand (20 tempo CD)."
	return item

static func create_techno_wraps() -> ItemData:
	var item = _new_gauntlet("Techno Wraps", Rarity.LEGENDARY, 10)
	item.wisdom_bonus = 3
	item.intelligence_bonus = 3
	_set_skill(item, "Future is bright", "Shuffle your discard pile into your draw pile.", "future_is_bright", 3)
	item.description = "+3 WIS, +3 INT. Skill — Future is bright: shuffle your discard pile into your draw pile (15 tempo CD)."
	return item

static func create_spidey_web_shooters() -> ItemData:
	var item = _new_gauntlet("Spidey Web Shooters", Rarity.LEGENDARY, 2)
	item.card_slots = 2
	item.dexterity_bonus = 3
	item.agility_bonus = 3
	item.hand_size_bonus = 1
	item.on_self_disarm_offensive = 1  # the target skips its next 1 attack
	_set_skill(item, "Coming in!", "Pull yourself to the target from up to 5 squares away.", "coming_in", 2)
	item.description = "+3 DEX, +3 AGI, +1 hand size. On-self: offensive cards disarm the target for 1 attack. Skill — Coming in!: pull yourself to the target from 5 squares (10 tempo CD)."
	return item

static func create_gravity_gauntlets() -> ItemData:
	var item = _new_gauntlet("Gravity Gauntlets", Rarity.LEGENDARY, 20)
	item.card_slots = 1
	item.intelligence_bonus = 6
	item.wisdom_bonus = 3
	item.agility_bonus = 2
	item.on_self_root_offensive = 1  # hold for 1 cycle (5 tempo)
	_set_skill(item, "Suck", "Pull enemies within 2 squares into the target area.", "suck", 2)
	item.description = "+6 INT, +3 WIS, +2 AGI. On-self: offensive cards hold the target in place (attacks/casts fine, no movement). Skill — Suck: pull enemies into the target area, 2-square AOE (10 tempo CD)."
	return item

static func create_spiked_mitts() -> ItemData:
	var item = _new_gauntlet("Spiked Mitts", Rarity.LEGENDARY, 35)
	item.card_slots = 1
	item.health_bonus = 10
	item.strength_bonus = 5
	item.dexterity_bonus = -2
	item.on_self_armor_any = 5  # ANY slotted card grants +5 armor
	item.armor_gain_thorns_threshold = 25
	item.armor_gain_thorns_amount = 5
	_set_skill(item, "Well placed guard", "Gain 5 thorns.", "well_placed_guard", 3)
	item.description = "+10 health, +5 STR, -2 DEX. On-self: ANY card provides +5 armor. Every 25 armor gained, gain 5 thorns. Skill — Well placed guard: gain 5 thorns (15 tempo CD)."
	return item

static func create_momentum_mits() -> ItemData:
	var item = _new_gauntlet("Momentum Mits", Rarity.LEGENDARY, 10)
	item.card_slots = 1
	item.strength_bonus = 5
	item.intelligence_bonus = 5
	item.wisdom_bonus = -3
	item.agility_bonus = -3
	item.on_self_draw_card = 1  # slotted card play draws a card
	_set_skill(item, "Continue to move", "Draw a card.", "continue_to_move", 5)
	item.description = "+5 STR, +5 INT, -3 WIS, -3 AGI. On-self: draw a card. Skill — Continue to move: draw a card (25 tempo CD)."
	return item

static func create_sleeved_katar() -> ItemData:
	var item = _new_gauntlet("Sleeved Katar", Rarity.LEGENDARY, 35)
	item.card_slots = 1
	item.agility_bonus = 3
	item.strength_bonus = 5
	item.dexterity_bonus = 3
	item.crit_damage_percent = 25.0
	item.crit_chance_percent = 5.0
	var katar_cards: Array[String] = ["return_cut"]
	item.granted_card_ids = katar_cards
	_set_skill(item, "Defense one with offense", "Gain 5 armor; your next melee offensive card deals +5 damage.", "defense_one", 5)
	item.description = "+3 AGI, +5 STR, +3 DEX, +25% crit damage, +5% crit chance. Grants Return Cut (Instant): when an attack fails to break your armor, counter with a melee strike (+5% crit). Skill — Defense one with offense: gain 5 armor and your next melee offensive card gets +5 damage (25 tempo CD)."
	return item

static func create_gauntlets_of_dungeon_mastering() -> ItemData:
	var item = _new_gauntlet("Gauntlets of Dungeon Mastering", Rarity.MYTHIC, 15)
	item.card_slots = 1
	item.wisdom_bonus = 3
	item.intelligence_bonus = 4
	item.strength_bonus = 3
	item.on_self_summon_wolf = 1
	_set_skill(item, "House Rule", "Pick a card from your discard pile and put it in your hand.", "house_rule", 4)
	item.level_3_overrides = {"card_slots": 2, "gauntlet_skill_cooldown": 3}
	item.level_3_description = "+3 WIS, +4 INT, +3 STR, 2 card slots. On-self: summon a wolf (pack of 3 max). Skill — House Rule (15 tempo CD)."
	_set_appearance(item, "gauntlets_of_dungeon_mastering",
		"Silver gauntlets with a twenty-sided die set on each of the knuckles.")
	item.description = "+3 WIS, +4 INT, +3 STR. On-self: summon a wolf, up to a pack of 3 (20 HP, attacks every 5 tempo, moves 2 per 3 tempo, attacks apply bleed; wolves empower each other: +20% attack and +1 bleed per other wolf). Skill — House Rule: pick a card from your discard pile into your hand (20 tempo CD)."
	return item

static func create_hallowed_trunk() -> ItemData:
	var item = _new_gauntlet("Hallowed Trunk", Rarity.MYTHIC, 45)
	item.strength_bonus = 10
	item.health_bonus = 15
	item.dexterity_bonus = -3
	item.armor_loss_regen_threshold = 10
	_set_skill(item, "imbue tree", "Gain 5 regen and 10 thorns.", "imbue_tree", 2)
	item.level_3_overrides = {"health_bonus": 30, "regen_include_health": true}
	item.level_3_description = "+10 STR, +30 life, -3 DEX. Every 10 armor OR 10 health removed, gain 1 stack of regen. Skill — imbue tree: gain 5 regen and 10 thorns (10 tempo CD)."
	_set_appearance(item, "hallowed_trunk",
		"A hollowed-out tree trunk, worn over the arm, with fluorescent green butterflies resting on the bark.")
	item.description = "+10 STR, +15 life, -3 DEX. Every 10 armor removed, gain 1 stack of regen. Skill — imbue tree: gain 5 regen and 10 thorns (10 tempo CD)."
	return item

static func create_cuffs_of_current() -> ItemData:
	var item = _new_gauntlet("Cuffs of Current", Rarity.MYTHIC, 10)
	item.intelligence_bonus = 6
	item.hand_size_bonus = 2
	item.draw_every_cycles = 3
	_set_skill(item, "Zeet", "Deal damage equal to your INT / 2.", "zeet", 3)
	item.level_3_overrides = {"intelligence_bonus": 8}
	item.level_3_description = "+8 INT, +2 hand size. Draw 1 card every 3 cycles. Skill — Zeet: deal INT/2 damage; bounces once, dealing 1/4 damage to an enemy near the target (15 tempo CD)."
	_set_appearance(item, "cuffs_of_current",
		"Four gold rings — one at each wrist and one just below each elbow — with light blue electricity coming off them.")
	item.description = "+6 INT, +2 hand size. Draw 1 card every 3 cycles. Skill — Zeet: deal damage equal to your INT / 2 (15 tempo CD)."
	return item

static func create_concealed_carry() -> ItemData:
	var item = _new_gauntlet("Concealed Carry", Rarity.MYTHIC, 2)
	item.dexterity_bonus = 2
	item.agility_bonus = 2
	item.hand_size_bonus = 1
	var cc_cards: Array[String] = ["smoke_bomb"]
	item.granted_card_ids = cc_cards
	_set_skill(item, "Lethal Poke", "A 0-base-damage melee attack. Crits deal x1.5 on top of the crit.", "lethal_poke", 3)
	item.level_3_overrides = {"dexterity_bonus": 5, "agility_bonus": 5, "hand_size_bonus": 1,
		"gauntlet_skill_cooldown": 2}
	item.level_3_description = "+5 DEX, +5 AGI, +1 hand size. Grants smoke bomb. Skill — Lethal Poke (10 tempo CD)."
	_set_appearance(item, "concealed_carry",
		"Gauntlets that appear to be made of clouds of smoke.")
	item.description = "+2 DEX, +2 AGI, +1 hand size. Grants smoke bomb: a 2-square cloud granting allies inside invisibility and 10% crit while they stay in it (8 tempo; card jailed 20 after play). Skill — Lethal Poke: 0-base melee attack; crits deal x1.5 on top of the crit (15 tempo CD)."
	return item

static func create_medic_wraps() -> ItemData:
	var item = _new_gauntlet("Medic Wraps", Rarity.RARE, 15)
	item.strength_bonus = 3
	item.dexterity_bonus = -2
	item.health_bonus = 5
	_set_skill(item, "Slurp and pad", "Heal an ally for 5 HP and gain 3 armor.", "slurp_and_pad", 3)
	item.description = "+3 STR, -2 DEX, +5 life. Skill — Slurp and pad: heal an ally 5 HP and gain 3 armor (15 tempo CD)."
	return item

static func create_roman_bracers() -> ItemData:
	var item = _new_gauntlet("Roman Bracers", Rarity.RARE, 5)
	item.card_slots = 1
	item.hand_size_bonus = 1
	item.health_bonus = 15
	item.strength_bonus = 5
	item.on_self_melee_damage = 5  # slotted melee offensive cards +5 damage
	_set_skill(item, "Slice", "Perform a basic melee attack for 2 tempo.", "slice", 2)
	item.description = "+15 life, +5 STR, +1 hand size. On-self: +5 damage on melee cards. Skill — Slice: a basic melee attack costing 2 tempo (10 tempo CD)."
	return item

static func create_copper_bracers() -> ItemData:
	var item = _new_gauntlet("Copper Bracers", Rarity.RARE, 10)
	item.health_bonus = 10
	item.strength_bonus = 2
	item.agility_bonus = 1
	item.wisdom_bonus = 3
	_set_skill(item, "Clang", "Gain 8 armor.", "clang", 3)
	item.description = "+10 life, +2 STR, +1 AGI, +3 WIS. Skill — Clang: gain 8 armor (15 tempo CD)."
	return item

static func create_fanned_bracers() -> ItemData:
	var item = _new_gauntlet("Fanned Bracers", Rarity.RARE, 15)
	item.health_bonus = 20
	item.hand_size_bonus = 1
	_set_skill(item, "Fan Save", "Inflict 1 stack of Weaken (target deals 30% less damage; a stack is consumed per attack).", "fan_save", 2)
	item.description = "+20 life, +1 hand size. Skill — Fan Save: inflict 1 Weaken — the enemy deals 30% less damage, one stack consumed per attack (10 tempo CD)."
	return item

# ============================================
# BELTS (first belts pass — waist slot)
# ============================================
static func _new_belt(nm: String, r: Rarity, wt: int) -> ItemData:
	var item = ItemData.new()
	item.item_name = nm
	item.item_type = ItemType.BELT
	item.item_type_name = "Belt"
	item.rarity = r
	item.weight = wt
	return item

static func create_leather_belt() -> ItemData:
	var item = _new_belt("Leather belt", Rarity.COMMON, 10)
	item.card_slots = 1
	item.strength_bonus = 3
	item.agility_bonus = 1
	item.on_self_damage = 1
	item.description = "+3 STR, +1 AGI. On-self: +1 damage."
	return item

static func create_waistband() -> ItemData:
	var item = _new_belt("Waistband", Rarity.COMMON, 2)
	item.card_slots = 1
	item.agility_bonus = 2
	item.wisdom_bonus = 2
	item.on_self_armor_any = 2
	item.description = "+2 AGI, +2 WIS. On-self: gain 2 armor."
	return item

static func create_studded_belt() -> ItemData:
	var item = _new_belt("Studded belt", Rarity.COMMON, 15)
	item.card_slots = 2
	item.health_bonus = 5
	item.strength_bonus = 2
	item.on_self_thorns = 3
	item.description = "+5 health, +2 STR. On-self: gain 3 thorns."
	return item

static func create_band_of_aid() -> ItemData:
	var item = _new_belt("Band of Aid", Rarity.COMMON, 5)
	item.card_slots = 1
	item.dexterity_bonus = 2
	item.health_bonus = 5
	item.on_self_heal = 1
	item.description = "+2 DEX, +5 health. On-self: heal 1."
	return item

static func create_holster() -> ItemData:
	var item = _new_belt("Holster", Rarity.RARE, 10)
	item.card_slots = 2
	item.strength_bonus = 3
	item.dexterity_bonus = 2
	item.on_self_damage = 2
	item.description = "+3 STR, +2 DEX. On-self: +2 damage to attack cards."
	return item

static func create_tactical_belt() -> ItemData:
	var item = _new_belt("Tactical belt", Rarity.RARE, 25)
	item.card_slots = 3
	item.intelligence_bonus = 5
	item.wisdom_bonus = 2
	item.on_self_target_aoe_damage = 2  # radius-1 blast around the card's target, enemies only
	item.description = "+5 INT, +2 WIS. On-self: an AOE explosive deals 2 damage around the target (allies unharmed)."
	return item

static func create_assasian_belt() -> ItemData:
	var item = _new_belt("Assasian Belt", Rarity.RARE, 10)
	item.card_slots = 1
	item.agility_bonus = 5
	item.dexterity_bonus = 1
	var ab_cards: Array[String] = ["shuriken", "shuriken"]
	item.granted_card_ids = ab_cards
	item.on_self_apply_vulnerable = 1
	item.description = "+5 AGI, +1 DEX. On-self: apply 1 Vulnerable. Grants two Shurikens."
	return item

static func create_potion_belt() -> ItemData:
	var item = _new_belt("Potion Belt", Rarity.RARE, 20)
	item.card_slots = 2
	item.wisdom_bonus = 3
	item.intelligence_bonus = 3
	var pb_cards: Array[String] = ["healing_potion", "poison_bomb"]
	item.granted_card_ids = pb_cards
	item.on_self_utility_tempo_refund = 1
	item.description = "+3 WIS, +3 INT. On-self: utility cards refund 1 tempo. Grants a Healing Potion and a Poison Bomb."
	return item

static func create_the_slotted_sash() -> ItemData:
	var item = _new_belt("The Slotted Sash", Rarity.LEGENDARY, 10)
	item.card_slots = 6
	item.wisdom_bonus = 3
	item.intelligence_bonus = 2
	item.on_self_offensive_damage = 2
	item.on_self_defense_armor = 2
	item.on_self_utility_weaken = 1
	item.description = "+3 WIS, +2 INT. 6 card slots. On-self: offensive cards +2 damage; defense cards +2 armor; utility cards apply 1 Weaken to a random enemy within 5 squares."
	return item

static func create_equator() -> ItemData:
	var item = _new_belt("Equator", Rarity.LEGENDARY, 45)
	item.card_slots = 2
	item.strength_bonus = 6
	item.determination_bonus = 2
	item.wisdom_bonus = 2
	item.on_self_apply_burn = 4
	var eq_cards: Array[String] = ["serene_center"]
	item.granted_card_ids = eq_cards
	item.description = "+6 STR, +2 DET, +2 WIS. On-self: apply 4 Burn. Grants Serene Center: set your health (temp included) and mana to half of max (30 mana, 4 tempo)."
	return item

static func create_strap_of_stone() -> ItemData:
	var item = _new_belt("Strap of Stone", Rarity.LEGENDARY, 50)
	item.card_slots = 1
	item.health_bonus = 20
	item.strength_bonus = 3
	item.on_self_physical_resilient = 10
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 10
	item.armor_per_tempo_interval = 20
	var ss_cards: Array[String] = ["stone_encase"]
	item.granted_card_ids = ss_cards
	item.description = "+20 life, +3 STR. Gain 10 armor every 20 tempo. On-self: gain 10% physical resistance for 10 tempo. Grants Stone Encase: gain 50 armor and become stunned for 5 tempo (45 mana, 5 tempo)."
	return item

static func create_belt_of_wumbology() -> ItemData:
	var item = _new_belt("Belt of Wumbology", Rarity.LEGENDARY, 15)
	item.card_slots = 2
	item.strength_bonus = 5
	item.health_bonus = 5
	item.wisdom_bonus = 1
	item.intelligence_bonus = 5
	item.on_self_strengthen_value = 10
	item.on_self_strengthen_attacks = 2
	var bw_cards: Array[String] = ["m_for_mini"]
	item.granted_card_ids = bw_cards
	item.description = "+5 STR, +5 health, +1 WIS, +5 INT. On-self: Strengthen +10 for your next 2 attacks. Grants M for Mini: apply 2 Vulnerable and 2 Weaken (15 mana, 2 tempo)."
	return item

static func create_corset_of_cure() -> ItemData:
	var item = _new_belt("Corset of Cure", Rarity.LEGENDARY, 25)
	item.card_slots = 3
	item.health_bonus = 25
	item.determination_bonus = 1
	item.wisdom_bonus = 1
	item.dexterity_bonus = 1
	item.on_self_cleanse_stacks = 3
	item.debuff_removed_conjure_id = "healing_tonic"
	item.description = "+25 health, +1 DET, +1 WIS, +1 DEX. On-self: cleanse 3 stacks of a random debuff on the card's target. When a debuff is removed from you, gain a Healing Tonic (0m/0t, range 5, heal an ally 5)."
	return item

static func create_alchemeist_belt() -> ItemData:
	var item = _new_belt("Alchemeist belt", Rarity.LEGENDARY, 10)
	item.card_slots = 3
	item.wisdom_bonus = 5
	item.intelligence_bonus = 5
	item.health_bonus = 15
	item.dexterity_bonus = -4
	item.heal_bonus_max_health_percent = 4.0
	var al_cards: Array[String] = ["hemotoxins"]
	item.granted_card_ids = al_cards
	item.description = "+5 WIS, +5 INT, +15 health, -4 DEX. Healing cards heal an additional 4% of your max health (self or ally). Grants Hemotoxins: apply 10 Poison — doubled if the target is below 50% health (50 mana, 5 tempo)."
	return item

static func create_shadow_obi() -> ItemData:
	var item = _new_belt("Shadow Obi", Rarity.LEGENDARY, 10)
	item.card_slots = 2
	item.agility_bonus = 8
	item.dexterity_bonus = 4
	item.on_self_damage_while_invisible = 5
	item.cheap_card_zap_damage = 3
	var so_cards: Array[String] = ["poof_and_weave"]
	item.granted_card_ids = so_cards
	item.description = "+8 AGI, +4 DEX. On-self: +5 damage while invisible. Playing a card that costs less than 2 tempo deals 3 damage to a random enemy. Grants Poof and Weave: become invisible, gain 10 armor and draw a card (40 mana, 5 tempo)."
	return item

static func create_belt_of_scrolls() -> ItemData:
	var item = _new_belt("Belt of Scrolls", Rarity.MYTHIC, 10)
	item.wisdom_bonus = 8
	item.intelligence_bonus = 8
	var bs_cards: Array[String] = ["chain_lightning", "ice_grenade", "fire_punch"]
	item.granted_card_ids = bs_cards
	_set_appearance(item, "belt_of_scrolls",
		"A wide leather belt hung with rolled parchment scrolls, each tucked into its own loop with a wax seal swinging below it.")
	item.description = "+8 WIS, +8 INT. Grants Chain Lightning (10 damage bouncing between enemies, -2 per bounce), Ice Grenade (5 damage + 2 Cold in a 2-square radius; two separately-aimed shots), and Fire Punch (STR-scaled melee that leaves a fire path behind the target and copies itself with Erase 5)."
	return item

static func create_megingjord() -> ItemData:
	var item = _new_belt("Megingjörð", Rarity.MYTHIC, 50)
	item.card_slots = 1
	item.strength_bonus = 15
	item.health_bonus = 30
	item.on_self_damage_multiplier = 2.0
	item.on_self_mana_multiplier = 2.0
	var mg_cards: Array[String] = ["gift_from_the_gods"]
	item.granted_card_ids = mg_cards
	_set_appearance(item, "megingjord",
		"Thor's girdle: a broad iron-studded leather band with a massive square buckle scored with runes.")
	item.level_3_overrides = {"strength_bonus": 20, "health_bonus": 45}
	item.level_3_description = "+20 STR, +45 life. On-self: double damage, double mana cost. Grants Gift from the Gods: gain 4 Enlightened and cleanse 3 negative effects."
	item.description = "+15 STR, +30 life. On-self: double damage, double mana cost. Grants Gift from the Gods: gain 3 Enlightened (10% crit chance, one stack consumed per attack)."
	return item

static func create_orions_belt() -> ItemData:
	var item = _new_belt("Orions Belt", Rarity.MYTHIC, 5)
	item.strength_bonus = 5
	item.dexterity_bonus = 3
	var ob_cards: Array[String] = ["protection_from_alnitak", "balance_of_alnilam", "crack_of_mintaka"]
	item.granted_card_ids = ob_cards
	_set_appearance(item, "orions_belt",
		"A midnight-blue band with three star-bright studs in a perfect row — Alnitak, Alnilam, and Mintaka.")
	item.description = "+5 STR, +3 DEX. Grants Protection From Alnitak (10 armor + Brace equal to your empty hand slots for 5 attacks), Balance of Alnilam (if this is your only card, draw 6), and Crack of Mintaka (discard any number of cards; melee strike with range and crit damage per card discarded)."
	return item

static func create_girdle_of_aphrodite() -> ItemData:
	var item = _new_belt("Girdle of Aphrodite", Rarity.MYTHIC, 15)
	item.card_slots = 2
	item.health_bonus = 10
	item.determination_bonus = 2
	item.agility_bonus = 2
	item.dexterity_bonus = 2
	item.wisdom_bonus = 2
	item.on_self_taunt_cycles = 3   # 15 tempo
	item.on_self_support_heal = 15
	_set_appearance(item, "girdle_of_aphrodite",
		"A slender golden girdle woven like braided hair, clasped at the front with a scallop shell.")
	item.level_3_overrides = {"card_slots": 3, "health_bonus": 20, "determination_bonus": 2,
		"agility_bonus": 3, "dexterity_bonus": 3, "wisdom_bonus": 4, "on_self_support_heal": 35}
	item.level_3_description = "+20 health, +2 DET, +3 AGI, +3 DEX, +4 WIS. 3 card slots. On-self: offensive cards Taunt the target for 15 tempo; utility/defense cards heal their target 35."
	item.description = "+10 health, +2 DET, +2 AGI, +2 DEX, +2 WIS. On-self: offensive cards Taunt the target for 15 tempo; utility/defense cards heal their target 15."
	return item

# ============================================
# WEAPONS (first weapons pass — both hands)
# ============================================
static func _new_weapon(nm: String, r: Rarity, sub: WeaponSubtype, wt: int) -> ItemData:
	var item = ItemData.new()
	item.item_name = nm
	item.item_type = ItemType.WEAPON
	item.item_type_name = "Weapon"
	item.weapon_subtype = sub
	item.rarity = r
	item.weight = wt
	return item

static func create_pick() -> ItemData:
	var item = _new_weapon("Pick", Rarity.COMMON, WeaponSubtype.AXE, 50)
	item.card_slots = 1
	item.strength_bonus = 3
	item.health_bonus = 5
	item.agility_bonus = 1
	item.on_self_damage = 5
	item.description = "+3 STR, +5 health, +1 AGI. On-self: +5 damage."
	return item

static func create_rusty_dagger() -> ItemData:
	var item = _new_weapon("Rusty Dagger", Rarity.COMMON, WeaponSubtype.DAGGER, 10)
	item.card_slots = 1
	item.agility_bonus = 3
	item.dexterity_bonus = 1
	item.on_self_crit_percent = 15.0
	item.description = "+3 AGI, +1 DEX. On-self: +15% crit chance."
	return item

static func create_construction_hammer() -> ItemData:
	var item = _new_weapon("Construction Hammer", Rarity.COMMON, WeaponSubtype.HAMMER, 15)
	item.agility_bonus = 2
	item.strength_bonus = 2
	var ch_cards: Array[String] = ["hard_helmet"]
	item.granted_card_ids = ch_cards
	item.description = "+2 AGI, +2 STR. Grants Hard Helmet (instant): when you play a utility card, gain 8 armor and deal 2 damage to the closest enemy."
	return item

static func create_short_sword() -> ItemData:
	var item = _new_weapon("Short Sword", Rarity.COMMON, WeaponSubtype.SWORD, 25)
	item.dexterity_bonus = 2
	item.strength_bonus = 3
	var ss_cards: Array[String] = ["slice"]
	item.granted_card_ids = ss_cards
	item.description = "+2 DEX, +3 STR. Grants Slice: deal 15 damage (10 mana, 3 tempo)."
	return item

static func create_wooden_spear() -> ItemData:
	var item = _new_weapon("Wooden Spear", Rarity.COMMON, WeaponSubtype.POLEARM, 20)
	item.card_slots = 1
	item.wisdom_bonus = 3
	item.strength_bonus = 3
	item.dexterity_bonus = 1
	item.on_self_apply_bleed = 1
	item.description = "+3 WIS, +3 STR, +1 DEX. On-self: apply 1 Bleed."
	return item

static func create_armor_chopper() -> ItemData:
	var item = _new_weapon("Armor Chopper", Rarity.RARE, WeaponSubtype.AXE, 120)
	item.health_bonus = 5
	item.strength_bonus = 3
	item.bonus_damage_to_armor = 10
	item.description = "+5 health, +3 STR. Your attacks deal an additional 10 damage to enemy armor."
	return item

static func create_lions_halberd() -> ItemData:
	var item = _new_weapon("Lions Halberd", Rarity.RARE, WeaponSubtype.AXE, 120)
	item.card_slots = 1
	item.dexterity_bonus = 3
	item.agility_bonus = 3
	item.on_self_damage = 10
	item.description = "+3 DEX, +3 AGI. On-self: +10 damage."
	return item

static func create_spartan_spear() -> ItemData:
	var item = _new_weapon("Spartan Spear", Rarity.RARE, WeaponSubtype.POLEARM, 80)
	item.wisdom_bonus = 3
	item.agility_bonus = 2
	item.strength_bonus = 4
	item.shield_synergy = true
	item.description = "+3 WIS, +2 AGI, +4 STR. While wielding a shield, gain Reach and +2 melee damage."
	return item

static func create_side_card_sabre() -> ItemData:
	var item = _new_weapon("Side Card Sabre", Rarity.RARE, WeaponSubtype.SWORD, 20)
	item.card_slots = 2
	item.agility_bonus = 2
	item.dexterity_bonus = 2
	item.offhand_pair_bonus = true
	item.description = "+2 AGI, +2 DEX. In your off hand beside a main-hand weapon (shields don't count): this sword is weightless and its slotted cards cost 1 less tempo."
	return item

static func create_axes_axe() -> ItemData:
	var item = _new_weapon("Axe's Axe", Rarity.LEGENDARY, WeaponSubtype.AXE, 150)
	item.strength_bonus = 8
	item.determination_bonus = 6
	item.intelligence_bonus = -6
	item.wisdom_bonus = -4
	item.kill_flash_points = 5
	var aa_cards: Array[String] = ["death_vortex", "death_vortex", "death_vortex"]
	item.granted_card_ids = aa_cards
	item.description = "+8 STR, +6 DET, -6 INT, -4 WIS. Grants 3 Death Vortexes (instant): after you are hit 5 times, every copy in hand fires — a spin attack dealing 15 damage to all adjacent enemies; a Vortex that kills returns to your hand. Killing an enemy banks 5 flash points (may exceed your cap)."
	return item

static func create_bessy() -> ItemData:
	var item = _new_weapon("Bessy", Rarity.LEGENDARY, WeaponSubtype.HAMMER, 450)
	item.card_slots = 1
	item.weapon_damage = 15
	item.attack_speed_threshold_bonus = 5
	item.on_self_weakened_damage_percent = 25.0
	var by_cards: Array[String] = ["earth_rattle"]
	item.granted_card_ids = by_cards
	item.description = "15 weapon damage. Attack-speed procs take 5 more swings — she is HEAVY. On-self: +25% damage to Weakened enemies (on top of Weaken itself). Grants Earth Rattle: smash the ground — 40 damage in a 3-square quake; enemies hit are Slowed 2 and Weakened 2 (60 mana, 6 tempo)."
	return item

static func create_hammer_of_ajax() -> ItemData:
	var item = _new_weapon("Hammer of Ajax", Rarity.LEGENDARY, WeaponSubtype.HAMMER, 250)
	item.card_slots = 1
	item.determination_bonus = 8
	item.strength_bonus = 8
	item.agility_bonus = -2
	item.on_self_max_hp_damage_percent = 10.0
	var ha_cards: Array[String] = ["feed_into_the_pain"]
	item.granted_card_ids = ha_cards
	item.description = "+8 DET, +8 STR, -2 AGI. On-self: +damage equal to 10% of your max health. Grants Feed into the Pain (instant): when you take damage below 30% health, gain Strengthen 20 for 4 attacks and 25 temp HP."
	return item

static func create_laurentius_lost_spear() -> ItemData:
	var item = _new_weapon("Laurentius's Lost Spear", Rarity.LEGENDARY, WeaponSubtype.POLEARM, 75)
	item.card_slots = 2
	item.strength_bonus = 6
	item.wisdom_bonus = 2
	item.intelligence_bonus = 6
	item.on_self_self_targets_allies = true
	var ll_cards: Array[String] = ["psionic_flow", "psionic_flow"]
	item.granted_card_ids = ll_cards
	item.description = "+6 STR, +2 WIS, +6 INT. On-self: slotted self-target cards may target allies. Grants 2 Psionic Flows (instant): when an ally takes damage within 3 squares, restore 8 to them and push the attacker back 1 — or, when you play an attack, deal +8 damage and push the target back 1. Whichever comes first."
	return item

static func create_mauls_sabre() -> ItemData:
	## A blade on both ends of the staff, and nothing else in your hands — a
	## staff shares the hands with NOTHING, so the sabre IS the whole kit.
	var item = _new_weapon("Mauls Sabre", Rarity.LEGENDARY, WeaponSubtype.STAFF, 40)
	item.card_slots = 2
	item.agility_bonus = 8
	item.strength_bonus = 3
	item.dexterity_bonus = 4
	item.on_self_alternating_ends = true
	var ms_cards: Array[String] = ["vault"]
	item.granted_card_ids = ms_cards
	item.description = "+8 AGI, +3 STR, +4 DEX. 2 card slots. On-self: offensive plays alternate ends — the maul end deals +8 damage and shreds 5 armor; the sabre end costs 1 less tempo and gains 15% crit. Grants Vault: leap up to 3 squares over anything (10 mana, 0 tempo; jailed 10 tempo after play)."
	return item

static func create_fallens_wrath() -> ItemData:
	var item = _new_weapon("Fallen's Wrath", Rarity.LEGENDARY, WeaponSubtype.SWORD, 50)
	item.card_slots = 2
	item.intelligence_bonus = 5
	item.strength_bonus = 5
	item.wisdom_bonus = 5
	item.health_bonus = 25
	item.wrath_weapon = true
	item.on_self_overdrive_multiplier = 1.5
	var fw_cards: Array[String] = ["purge_wrath"]
	item.granted_card_ids = fw_cards
	item.description = "+5 INT, +5 STR, +5 WIS, +25 health. Each damage instance you take grants 1 Wrath (max 30); your attacks deal +Wrath damage; at 10+ Wrath you take 50% more damage. On-self: deal 1.5x damage, take half the bonus yourself. Grants Purge Wrath: your next attack deals +Wrath% bonus damage; Wrath resets to 0 (55 mana, 8 tempo)."
	return item

static func create_nine_ruins_of_sanguine() -> ItemData:
	var item = _new_weapon("Nine Ruins of Sanguine", Rarity.LEGENDARY, WeaponSubtype.DAGGER, 15)
	item.dexterity_bonus = 7
	item.wisdom_bonus = 2
	item.vitality_weapon = true
	var nr_cards: Array[String] = ["sanguine_the_penguin"]
	item.granted_card_ids = nr_cards
	item.description = "+7 DEX, +2 WIS. Every attack grants 1 Vitality (max 9): each stack gives +1% lifesteal and +2 attack damage. At 9, the stacks purge and Sanguine the blood penguin waddles forth — 50 HP, stays beside you, 8 damage every 5 tempo, can be hit (even by you); damage HE takes heals YOU half as much. No Vitality while he lives."
	return item

static func create_sabre_tooth() -> ItemData:
	var item = _new_weapon("Sabre Tooth", Rarity.MYTHIC, WeaponSubtype.DAGGER, 10)
	item.card_slots = 1
	item.dexterity_bonus = 10
	item.agility_bonus = 5
	item.determination_bonus = 3
	item.on_self_apply_bleed = 5
	item.same_target_bleed = 5
	_set_appearance(item, "sabre_tooth",
		"A khatar with a sabertooth tiger head where the hand grip is, and a giant sabertooth tooth as the blade.")
	item.description = "+10 DEX, +5 AGI, +3 DET. On-self: apply 5 Bleed. Striking the same target twice in a row ticks the attack-speed counter an extra time and inflicts 5 Bleed."
	return item

static func create_poseidons_trident() -> ItemData:
	var item = _new_weapon("Poseidons Trident", Rarity.MYTHIC, WeaponSubtype.POLEARM, 80)
	item.card_slots = 2
	item.intelligence_bonus = 10
	item.wisdom_bonus = 8
	item.health_bonus = 15
	item.mana_bonus = 25
	item.pierce_targets = 2
	var pt_cards: Array[String] = ["wrath_of_the_sea"]
	item.granted_card_ids = pt_cards
	# Wrath of the Sea granting 18 mana per enemy at Lv.3 is read live off
	# item_level (see main's wrath_of_the_sea world case).
	item.level_3_overrides = {"health_bonus": 20, "mana_bonus": 35, "pierce_targets": 3}
	item.level_3_description = "+10 INT, +8 WIS, +20 health, +35 mana. Your attacks strike 3 squares in a line. Grants Wrath of the Sea: spend half your current mana, blink, and deal the mana spent (plus STR) to every enemy in a 4x4 sea burst — all of them shoved to its edge; gain 18 mana per enemy hit (8 tempo)."
	_set_appearance(item, "poseidons_trident",
		"Poseidon's trident.")
	item.description = "+10 INT, +8 WIS, +15 health, +25 mana. Your attacks strike 2 squares in a line. Grants Wrath of the Sea: spend half your current mana, blink, and deal the mana spent (plus STR) to every enemy in a 4x4 sea burst — all of them shoved to its edge; gain 15 mana per enemy hit (8 tempo)."
	return item

static func create_sword_of_theseus() -> ItemData:
	var item = _new_weapon("Sword of Theseus", Rarity.MYTHIC, WeaponSubtype.SWORD, 30)
	item.card_slots = 5
	item.strength_bonus = 8
	item.determination_bonus = 7
	item.lifesteal_percent = 5.0
	item.on_self_apply_slow = 2
	item.on_self_slow_damage_per_stack = 1
	item.level_3_overrides = {"lifesteal_percent": 8.0, "on_self_apply_slow": 3}
	item.level_3_description = "+8 STR, +7 DET, 8% lifesteal. 5 card slots. On-self: attacks apply 3 Slow and deal +1 damage per Slow already on the target."
	_set_appearance(item, "sword_of_theseus",
		"A long broadsword with a minotaur head as the grip and horns as the cross-guards. A second small blade juts from the pommel.")
	item.description = "+8 STR, +7 DET, 5% lifesteal. 5 card slots. On-self: attacks apply 2 Slow and deal +1 damage per Slow already on the target."
	return item

static func create_umbral_eclipse() -> ItemData:
	var item = _new_weapon("Umbral Eclipse", Rarity.MYTHIC, WeaponSubtype.HAMMER, 200)
	item.card_slots = 2
	item.wisdom_bonus = 8
	item.agility_bonus = 8
	item.strength_bonus = 3
	item.mana_bonus = 15
	item.armor_gain_melee_damage = 5
	item.insight_flash_restore = 2
	var ue_cards: Array[String] = ["monk_of_the_night"]
	item.granted_card_ids = ue_cards
	# Monk of the Night converting 15% at Lv.3 is read live off item_level
	# (see the maintained-block conversion in Card.execute).
	item.level_3_overrides = {"armor_gain_melee_damage": 8, "insight_flash_restore": 3}
	item.level_3_description = "+8 WIS, +8 AGI, +3 STR, +15 mana. Gaining armor deals 8 damage to an enemy in melee range. Insight draws restore 3 flash points. Grants Monk of the Night (Maintain): attack cards grant 15% of their damage as block (50 mana, 4 tempo)."
	_set_appearance(item, "umbral_eclipse",
		"A double-sided hammer — a head on both ends of the shaft — with the full lunar cycle inlaid along the handle and a full moon on both hammer faces.")
	item.description = "+8 WIS, +8 AGI, +3 STR, +15 mana. Gaining armor deals 5 damage to an enemy in melee range. Insight draws restore 2 flash points. Grants Monk of the Night (Maintain): attack cards grant 10% of their damage as block (50 mana, 4 tempo)."
	return item

# ============================================
# CHESTS (first chests pass — torso slot)
# ============================================
static func _new_chest(nm: String, r: Rarity, wt: int) -> ItemData:
	var item = ItemData.new()
	item.item_name = nm
	item.item_type = ItemType.CHEST
	item.item_type_name = "Chest"
	item.rarity = r
	item.weight = wt
	return item

static func create_wooden_plank() -> ItemData:
	var item = _new_chest("Wooden Plank", Rarity.COMMON, 45)
	item.health_bonus = 15
	item.low_health_regen = 1
	item.description = "+15 health. When you drop below 50% health, gain 1 Regen."
	return item

static func create_elvish_cloak() -> ItemData:
	var item = _new_chest("Elvish Cloak", Rarity.COMMON, 10)
	item.card_slots = 1
	item.dexterity_bonus = 2
	item.agility_bonus = 1
	item.on_self_ranged_damage = 2
	item.description = "+2 DEX, +1 AGI. On-self: ranged offensive cards deal +2 damage."
	return item

static func create_steel_plate() -> ItemData:
	var item = _new_chest("Steel Plate", Rarity.COMMON, 80)
	item.strength_bonus = 3
	item.health_bonus = 10
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 8
	item.armor_per_tempo_interval = 20
	item.description = "+3 STR, +10 health. Gain 8 block every 20 tempo."
	return item

static func create_tattered_cloth() -> ItemData:
	var item = _new_chest("Tattered Cloth", Rarity.COMMON, 10)
	item.determination_bonus = 2
	item.agility_bonus = 2
	item.wisdom_bonus = 2
	item.dexterity_bonus = 2
	item.health_bonus = 5
	item.description = "+2 DET, +2 AGI, +2 WIS, +2 DEX, +5 health."
	return item

static func create_velvet_plate() -> ItemData:
	var item = _new_chest("Velvet Plate", Rarity.RARE, 120)
	item.card_slots = 1
	item.strength_bonus = 5
	item.health_bonus = 20
	item.on_self_heal = 10
	item.description = "+5 STR, +20 health. On-self: heal 10."
	return item

static func create_buffed_leather() -> ItemData:
	var item = _new_chest("Buffed Leather", Rarity.RARE, 100)
	item.health_bonus = 40
	item.description = "+40 health."
	return item

static func create_chain_mail() -> ItemData:
	var item = _new_chest("Chain Mail", Rarity.RARE, 200)
	item.health_bonus = 15
	item.special_effect = SpecialEffect.ARMOR_PER_TURN
	item.special_effect_value = 8
	item.armor_per_tempo_interval = 15
	var cm_cards: Array[String] = ["clang_up"]
	item.granted_card_ids = cm_cards
	item.description = "+15 health. Gain 8 armor every 15 tempo. Grants Clang Up: gain 10 block (20 mana, 5 tempo)."
	return item

static func create_suit_and_tie() -> ItemData:
	var item = _new_chest("Suit and Tie", Rarity.RARE, 10)
	item.intelligence_bonus = 3
	item.wisdom_bonus = 2
	item.determination_bonus = 1
	item.gold_gain_heal = 3
	var st_cards: Array[String] = ["negotiate"]
	item.granted_card_ids = st_cards
	item.description = "+3 INT, +2 WIS, +1 DET. Heal 3 whenever you obtain gold. Grants Negotiate: steal 5 gold from an enemy (20 mana, 3 tempo)."
	return item

static func create_smithed_excellence() -> ItemData:
	var item = _new_chest("Smithed Excellence", Rarity.LEGENDARY, 65)
	item.card_slots = 3
	item.health_bonus = 30
	item.strength_bonus = 5
	item.wisdom_bonus = 4
	item.on_self_resist_all_percent = 2.0
	item.on_self_resist_all_tempo = 3
	item.block_physical_resist_percent = 10.0
	item.description = "+30 health, +5 STR, +4 WIS. On-self: gain 2% resistance to all damage types for 3 tempo. While you have block, you have an additional 10% physical resistance."
	return item

static func create_shadow_cowl() -> ItemData:
	var item = _new_chest("Shadow Cowl", Rarity.LEGENDARY, 10)
	item.card_slots = 4
	item.health_bonus = -10
	item.agility_bonus = 5
	item.dexterity_bonus = 7
	item.on_self_offensive_damage = 2
	item.on_self_offensive_shift = 2
	item.description = "-10 health, +5 AGI, +7 DEX. On-self: offensive cards deal +2 damage and shift you 2 spaces."
	return item

static func create_chewbaccas_bandolier() -> ItemData:
	var item = _new_chest("Chewbaccas Bandolier", Rarity.LEGENDARY, 45)
	item.card_slots = 2
	item.strength_bonus = 8
	item.agility_bonus = 2
	item.health_bonus = -10
	item.dexterity_bonus = 2
	item.wisdom_bonus = -2
	item.on_self_ranged_tempo_reduction = 1
	item.on_self_ranged_damage = 5
	item.casing_damage = 8
	item.casing_tempo = 5
	item.description = "+8 STR, +2 AGI, +2 DEX, -10 health, -2 WIS. On-self: ranged offensive cards cost 1 less tempo and deal +5 damage. After playing a ranged offensive card, drop a bullet casing — when an enemy steps on it, or after 5 tempo, it explodes for 8 damage (never hurts allies or summons)."
	return item

static func create_supernova_cuirass() -> ItemData:
	var item = _new_chest("Supernova Cuirass", Rarity.LEGENDARY, 250)
	item.determination_bonus = 2
	item.health_bonus = 10
	item.damage_bank_percent = 10.0
	item.damage_bank_mitigate_percent = 2.0
	item.damage_bank_max_stacks = 10
	var sc_cards: Array[String] = ["detonova"]
	item.granted_card_ids = sc_cards
	item.description = "+2 DET, +10 health. While the cuirass has stack room (max 10), it absorbs 10% of every hit — harnessed as a stack — and mitigates a further 2% entirely. Grants Detonova: purge your stacks and deal the absorbed total as fire damage 2 squares around you — does NOT scale with INT (60 mana, 5 tempo)."
	return item

static func create_trench_of_tranquility() -> ItemData:
	var item = _new_chest("Trench of Tranquility", Rarity.LEGENDARY, 100)
	item.card_slots = 2
	item.health_bonus = 25
	item.mana_bonus = 35
	item.intelligence_bonus = 5
	item.strength_bonus = 5
	item.determination_bonus = 2
	item.agility_bonus = -5
	item.on_self_heal = 5
	var tt_cards: Array[String] = ["mind_mend", "deep_breaths"]
	item.granted_card_ids = tt_cards
	item.description = "+25 health, +35 mana, +5 INT, +5 STR, +2 DET, -5 AGI. On-self: heal 5. Grants Mind Mend: restore 60 mana (costs 15 HEALTH, 3 tempo) and Deep Breaths: heal 20 (30 mana, 4 tempo)."
	return item

static func create_briarhide_plate() -> ItemData:
	var item = _new_chest("Briarhide Plate", Rarity.LEGENDARY, 300)
	item.health_bonus = 35
	item.exposed_armor_gain = 5
	var bp_cards: Array[String] = ["vined_encasing"]
	item.granted_card_ids = bp_cards
	item.description = "+35 health. When your armor is broken through, gain 5 armor. Grants Vined Encasing: gain 1 thorn per point of armor you currently have, for 20 tempo — you lose X thorns whenever you receive X damage (50 mana, 4 tempo)."
	return item

static func create_blue_robe() -> ItemData:
	var item = _new_chest("Blue Robe", Rarity.LEGENDARY, 25)
	item.card_slots = 2
	item.wisdom_bonus = 5
	item.intelligence_bonus = 8
	item.health_bonus = 20
	item.on_self_adaptive_damage_type = true
	item.description = "+5 WIS, +8 INT, +20 health. On-self: the card's damage type adapts to each enemy hit — it always deals the type they resist LEAST (fire is checked first)."
	return item

static func create_adimantium() -> ItemData:
	var item = _new_chest("Adimantium", Rarity.MYTHIC, 350)
	item.card_slots = 2
	item.strength_bonus = 8
	item.agility_bonus = -2
	item.dexterity_bonus = -1
	item.on_self_block = 8
	item.movement_tempo_penalty = 1
	item.exposed_armor_gain = 10
	item.exposed_armor_cooldown_cycles = 15
	var ad_cards: Array[String] = ["adimantium_wall"]
	item.granted_card_ids = ad_cards
	# Adimantium Wall granting 55 block at Lv.3 is read live off item_level
	# (see Card.execute's adimantium_wall case).
	item.level_3_overrides = {"exposed_armor_gain": 15, "exposed_armor_cooldown_cycles": 10}
	item.level_3_description = "+8 STR, -2 AGI, -1 DEX. On-self: +8 block. Each tile you move costs 1 extra tempo. When your armor is broken through, gain 15 armor (10-cycle cooldown). Grants Adimantium Wall: gain 55 block; the card is jailed 40 tempo after play (35 mana, 4 tempo)."
	_set_appearance(item, "adimantium",
		"Teal chest piece with a gold jewel on the chest.")
	item.description = "+8 STR, -2 AGI, -1 DEX. On-self: +8 block. Each tile you move costs 1 extra tempo. When your armor is broken through, gain 10 armor (15-cycle cooldown). Grants Adimantium Wall: gain 40 block; the card is jailed 40 tempo after play (35 mana, 4 tempo)."
	return item

static func create_tigers_sunday_red() -> ItemData:
	var item = _new_chest("Tigers Sunday Red", Rarity.MYTHIC, 10)
	item.card_slots = 2
	item.health_bonus = 15
	item.agility_bonus = 5
	item.dexterity_bonus = 5
	item.on_self_offensive_heal_percent = 3.0
	item.ranged_range_bonus = 1
	item.hp_diff_damage_divisor = 4
	item.level_3_overrides = {"on_self_offensive_heal_percent": 6.0, "hp_diff_damage_divisor": 3}
	item.level_3_description = "+15 health, +5 AGI, +5 DEX. On-self: offensive cards heal you 6% of your max health. +1 range on ranged offensive cards. Bonus damage equal to the difference between your health % and the enemy's, divided by 3 (never below 0)."
	_set_appearance(item, "tigers_sunday_red",
		"Red Polo.")
	item.description = "+15 health, +5 AGI, +5 DEX. On-self: offensive cards heal you 3% of your max health. +1 range on ranged offensive cards. Bonus damage equal to the difference between your health % and the enemy's, divided by 4 (never below 0)."
	return item

static func create_divine_resistance() -> ItemData:
	var item = _new_chest("Divine Resistance", Rarity.MYTHIC, 400)
	item.health_bonus = 45
	item.strength_bonus = 5
	item.resist_per_missing10 = 1.0
	item.resist_missing_step = 8
	var dr_cards: Array[String] = ["preemptive_answer"]
	item.granted_card_ids = dr_cards
	item.level_3_overrides = {"resist_per_missing10": 1.5, "resist_missing_step": 7}
	item.level_3_description = "+45 health, +5 STR. Gain 1.5% resistance to all damage types per 7% missing health. Grants Preemptive Answer (instant): when you drop to 25% health, purge 3 debuffs and heal 20."
	_set_appearance(item, "divine_resistance",
		"Shiny silver chest, with a crescent moon and sun on the chest.")
	item.description = "+45 health, +5 STR. Gain 1% resistance to all damage types per 8% missing health. Grants Preemptive Answer (instant): when you drop to 25% health, purge 3 debuffs and heal 20."
	return item

static func create_hide_of_garmr() -> ItemData:
	var item = _new_chest("Hide of Garmr", Rarity.MYTHIC, 80)
	item.health_bonus = 25
	item.agility_bonus = 8
	item.dexterity_bonus = 8
	item.strength_bonus = 8
	var hg_cards: Array[String] = ["ragnarok"]
	item.granted_card_ids = hg_cards
	# Ragnarok healing 15 / granting 7 STR per released card at Lv.3 is read
	# live off item_level (see Card.execute's ragnarok case).
	item.level_3_overrides = {"agility_bonus": 9, "dexterity_bonus": 9, "strength_bonus": 9,
		"death_crit_stack_radius": 2, "death_crit_damage_per_stack": 5.0}
	item.level_3_description = "+25 health, +9 AGI, +9 DEX, +9 STR. When there is a death of any kind within 2 squares of you (your own summons included), gain a stack: each stack grants +5% crit damage. At 5 stacks, purge them all and take 10% of your current health as damage. Grants Ragnarok: release all jailed cards into your hand — for each, heal 15 and gain 10% crit chance and 7 STR for 10 tempo; jailed 30 tempo after play (45 mana, 5 tempo)."
	_set_appearance(item, "hide_of_garmr",
		"Furry grey hide in the shape of a chest piece, a spiked collar and a wolf head at the chest.")
	item.description = "+25 health, +8 AGI, +8 DEX, +8 STR. Grants Ragnarok: release all jailed cards into your hand — for each, heal 10 and gain 10% crit chance and 5 STR for 10 tempo; jailed 30 tempo after play (45 mana, 5 tempo)."
	return item

# ============================================
# RANGED (first ranged pass — bows & quivers)
# ============================================
# Bows are two-handed (Inventory.is_two_hand_only) and admit only a quiver
# alongside them; the quiver rides in the other hand slot and takes that
# slot's off-hand modifier like any hand item. The Boomerang and Wrist Rocket
# are the one-handed exceptions — thrown "bows" that still pair with a quiver.
static func _new_bow(nm: String, r: Rarity, wt: int) -> ItemData:
	var item = _new_weapon(nm, r, WeaponSubtype.BOW, wt)
	item.item_type_name = "Bow"
	return item

static func _new_quiver(nm: String, r: Rarity, wt: int) -> ItemData:
	var item = ItemData.new()
	item.item_name = nm
	item.item_type = ItemType.QUIVER
	item.item_type_name = "Quiver"
	item.rarity = r
	item.weight = wt
	return item

static func create_short_bow() -> ItemData:
	var item = _new_bow("Short Bow", Rarity.COMMON, 20)
	item.agility_bonus = 3
	item.dexterity_bonus = 1
	item.description = "+3 AGI, +1 DEX. A simple two-handed bow — pairs with a quiver."
	return item

static func create_boomerang() -> ItemData:
	var item = _new_weapon("Boomerang", Rarity.COMMON, WeaponSubtype.OTHER, 5)
	item.strength_bonus = 3
	item.description = "+3 STR. A one-handed throwing arm that counts as a bow — pairs with a quiver."
	return item

static func create_cross_bow() -> ItemData:
	var item = _new_bow("Cross Bow", Rarity.COMMON, 30)
	item.dexterity_bonus = 1
	item.agility_bonus = -2
	item.intelligence_bonus = 3
	item.description = "+1 DEX, -2 AGI, +3 INT. Heavy machinery for careful hands."
	return item

static func create_standard_quiver() -> ItemData:
	var item = _new_quiver("Standard Quiver", Rarity.COMMON, 20)
	item.card_slots = 2
	item.agility_bonus = 1
	item.dexterity_bonus = 1
	item.on_self_range_offensive = 1
	item.description = "+1 AGI, +1 DEX. 2 card slots. On-self: +1 range."
	return item

static func create_fire_quiver() -> ItemData:
	var item = _new_quiver("Fire Quiver", Rarity.RARE, 20)
	item.card_slots = 2
	item.dexterity_bonus = 3
	item.agility_bonus = 1
	item.on_self_apply_burn = 1
	item.on_self_damage = 2
	item.description = "+3 DEX, +1 AGI. 2 card slots. On-self: +2 damage and apply 1 Burn."
	return item

static func create_quiver_of_wet_stones() -> ItemData:
	var item = _new_quiver("Quiver of Wet Stones", Rarity.RARE, 30)
	item.card_slots = 2
	item.strength_bonus = 5
	item.dexterity_bonus = 1
	item.on_self_damage = 2
	item.on_self_armor_shred = 4
	item.description = "+5 STR, +1 DEX. 2 card slots. On-self: +2 damage and an additional 4 damage to armor."
	return item

static func create_frost_quiver() -> ItemData:
	var item = _new_quiver("Frost Quiver", Rarity.RARE, 20)
	item.card_slots = 2
	item.wisdom_bonus = 5
	item.agility_bonus = 1
	item.on_self_apply_cold = 1
	item.on_self_damage = 1
	item.on_self_armor_any = 2
	item.description = "+5 WIS, +1 AGI. 2 card slots. On-self: +1 damage, apply 1 Cold, and gain 2 armor."
	return item

static func create_shock_quiver() -> ItemData:
	var item = _new_quiver("Shock Quiver", Rarity.RARE, 10)
	item.card_slots = 2
	item.agility_bonus = 3
	item.wisdom_bonus = 2
	item.dexterity_bonus = 2
	item.on_self_apply_shock = 2
	item.on_self_crit_percent = 5.0
	item.description = "+3 AGI, +2 WIS, +2 DEX. 2 card slots. On-self: apply 2 Shock and +5% crit chance."
	return item

static func create_long_bow() -> ItemData:
	var item = _new_bow("Long Bow", Rarity.RARE, 25)
	item.card_slots = 2
	item.dexterity_bonus = 2
	item.agility_bonus = 4
	item.health_bonus = 5
	item.on_self_range_offensive = 2
	item.on_self_damage = 2
	item.description = "+2 DEX, +4 AGI, +5 health. 2 card slots. On-self: +2 range and +2 damage."
	return item

static func create_tightened_cross_bow() -> ItemData:
	var item = _new_bow("Tightened Cross Bow", Rarity.RARE, 40)
	item.card_slots = 2
	item.dexterity_bonus = 3
	item.agility_bonus = -2
	item.intelligence_bonus = 5
	item.strength_bonus = 2
	item.on_self_damage = 5
	item.on_self_tempo_penalty = 1
	item.description = "+3 DEX, -2 AGI, +5 INT, +2 STR. 2 card slots. On-self: +5 damage but +1 tempo."
	return item

static func create_sack_of_bone_arrows() -> ItemData:
	var item = _new_quiver("Sack of Bone Arrows", Rarity.LEGENDARY, 40)
	item.card_slots = 2
	item.wisdom_bonus = 5
	item.intelligence_bonus = 3
	item.on_self_kill_summon_skeleton = true
	item.description = "+5 WIS, +3 INT. 2 card slots. On-self: a kill raises a skeleton with half the victim's max health — 5 damage, 4 squares per tempo, attacks every 5 tempo; up to 3 at once."
	return item

static func create_wrist_rocket() -> ItemData:
	var item = _new_weapon("Wrist Rocket", Rarity.LEGENDARY, WeaponSubtype.OTHER, 10)
	item.card_slots = 1
	item.dexterity_bonus = 5
	item.agility_bonus = 6
	item.crit_chance_percent = 10.0
	var wr_cards: Array[String] = ["improvised_ammo", "improvised_ammo"]
	item.granted_card_ids = wr_cards
	item.description = "+5 DEX, +6 AGI, +10% crit chance. One-handed; pairs with a quiver. Grants 2 copies of Improvised Ammo: deal 8 damage and apply 3 Weaken — or discard it to deal 4 damage to the nearest enemy and give Improvised Ammo +10% crit chance this battle (45 mana, 0 tempo)."
	return item

static func create_cupids_bow() -> ItemData:
	var item = _new_bow("Cupids Bow", Rarity.LEGENDARY, 30)
	item.wisdom_bonus = 3
	item.strength_bonus = 5
	item.intelligence_bonus = 4
	var cb_cards: Array[String] = ["cupids_golden_arrow", "cupids_lead_arrow"]
	item.granted_card_ids = cb_cards
	item.description = "+3 WIS, +5 STR, +4 INT. Grants Golden — 10 damage, 2 Vulnerable, 50% chance to taunt the enemy toward you — and Lead — 10 damage, 2 Weaken, 50% chance to send the enemy fleeing (each 45 mana, 3 tempo). An enemy struck by both arrows turns into a tree for 4 tempo: it keeps every buff and debuff, cannot act, and regenerates 3 health on each of its first 3 tempo."
	return item

static func create_the_rapid_recurve() -> ItemData:
	var item = _new_bow("The Rapid Recurve", Rarity.LEGENDARY, 60)
	item.card_slots = 2
	item.strength_bonus = 8
	item.agility_bonus = -4
	item.dexterity_bonus = 2
	item.on_self_double_shot = true
	item.on_self_mana_multiplier = 1.5
	item.on_self_jail_tempo = 20
	item.description = "+8 STR, -4 AGI, +2 DEX. 2 card slots. On-self: Double Shot — the card hits a second time at full damage, costs 1.5x mana, and is jailed 20 tempo after play."
	return item

static func create_capacious_extremus() -> ItemData:
	var item = _new_quiver("Capacious Extremus", Rarity.LEGENDARY, 15)
	item.card_slots = 4
	item.intelligence_bonus = 8
	item.wisdom_bonus = 2
	item.on_self_mana_reduction_percent = 10.0
	item.description = "+8 INT, +2 WIS. 4 card slots. On-self: mana cost decreased by 10%."
	return item

static func create_stringless_sender() -> ItemData:
	var item = _new_bow("Stringless Sender", Rarity.LEGENDARY, 20)
	item.card_slots = 2
	item.intelligence_bonus = 6
	item.agility_bonus = 6
	item.wisdom_bonus = 1
	item.dexterity_bonus = 1
	item.on_self_tempo_penalty = -1
	item.on_self_mana_reduction = -10
	item.on_self_bounce_percent = 20.0
	item.description = "+6 INT, +6 AGI, +1 WIS, +1 DEX. 2 card slots. On-self: -1 tempo, +10 mana cost, and a 20% chance the shot bounces to a second target at full damage — a crit success or failure carries over with it."
	return item

static func create_bow_of_arash() -> ItemData:
	var item = _new_bow("Bow of Arash", Rarity.MYTHIC, 25)
	item.card_slots = 3
	item.agility_bonus = 5
	item.dexterity_bonus = 2
	item.wisdom_bonus = 4
	item.ranged_range_bonus = 2
	item.on_self_mana_to_life = true
	var ba_cards: Array[String] = ["territorial_mark"]
	item.granted_card_ids = ba_cards
	item.level_3_overrides = {"ranged_range_bonus": 3, "agility_bonus": 6}
	item.level_3_description = "+3 range on ranged cards, +6 AGI, +2 DEX, +4 WIS. 3 card slots. On-self: half the card's mana cost is paid as life instead. Grants Territorial Mark: a 15-damage arrow whose flight path — and the 2 squares either side of it — glistens with blue smoke for 25 tempo; enemies inside the mark are Weakened until they leave it (45 mana + 35 health, 5 tempo, range 10)."
	_set_appearance(item, "bow_of_arash",
		"A longbow of divine origin: golden limbs, a bright string, and the blue glisten of its territorial mark drifting off the wood.")
	item.description = "+2 range on ranged cards, +5 AGI, +2 DEX, +4 WIS. 3 card slots. On-self: half the card's mana cost is paid as life instead. Grants Territorial Mark: a 15-damage arrow whose flight path — and the 2 squares either side of it — glistens with blue smoke for 25 tempo; enemies inside the mark are Weakened until they leave it (45 mana + 35 health, 5 tempo, range 10)."
	return item

static func create_belthronding() -> ItemData:
	var item = _new_bow("Belthronding", Rarity.MYTHIC, 60)
	item.card_slots = 2
	item.strength_bonus = 10
	item.health_bonus = 20
	item.dexterity_bonus = 8
	item.on_self_conjure_on_play_id = "close_is_favored"
	item.ally_damage_share_percent = 10.0
	item.ally_damage_share_radius = 3
	var bt_cards: Array[String] = ["balistic_arrow"]
	item.granted_card_ids = bt_cards
	item.level_3_overrides = {"strength_bonus": 12, "dexterity_bonus": 10}
	item.level_3_description = "+12 STR, +20 health, +10 DEX. 2 card slots. On-self: playing a slotted card puts a copy of Close is Favored into your hand, up to 3 held at once (Instant: an enemy entering melee range takes 13 damage; erased). When an ally deals damage within 3 squares of you, you take 10% of it as well. Grants Balistic Arrow: 30 damage — hitting an enemy does not stop this arrow (75 mana, 5 tempo)."
	_set_appearance(item, "belthronding",
		"Crafted entirely from rare, dark black yew-wood, its stiff ends fitted with hard animal horn.")
	item.description = "+10 STR, +20 health, +8 DEX. 2 card slots. On-self: playing a slotted card puts a copy of Close is Favored into your hand, up to 3 held at once (Instant: an enemy entering melee range takes 13 damage; erased). When an ally deals damage within 3 squares of you, you take 10% of it as well. Grants Balistic Arrow: 30 damage — hitting an enemy does not stop this arrow (75 mana, 5 tempo)."
	return item

static func create_bow_of_budding_blasts() -> ItemData:
	var item = _new_bow("Bow of Budding Blasts", Rarity.MYTHIC, 35)
	item.card_slots = 2
	item.intelligence_bonus = 3
	item.wisdom_bonus = 4
	item.mana_bonus = 25
	item.on_self_crit_bud_bow = true
	var bb_cards: Array[String] = ["spirit_bow"]
	item.granted_card_ids = bb_cards
	_set_appearance(item, "bow_of_budding_blasts",
		"A bow with the slick, slimy texture of a sea cucumber — smaller bows budding off its flanks.")
	item.description = "+3 INT, +4 WIS, +25 mana. 2 card slots. On-self: a crit buds a bow turret — 6 damage, attacks every 5 tempo, dies to any damage or after 2 attacks; up to 4 at once. This bow and its bow summons gain +2 damage and +5% crit chance per living bow summon. Grants Spirit Bow (Maintain): a spirit bow that stalks your enemies, 1 square per tempo, loosing a 10-damage shot every 4 tempo (65 mana, 3 tempo)."
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
