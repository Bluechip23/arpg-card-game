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
signal flash_points_changed(current: int, max_points: int)
signal brain_points_changed(current: int, max_points: int)
# ACTION POINTS umbrella: flash (AGI/body) and brain (WIS/mind) are independent
# pools under one parent category — like attack/spell under Offensive. Both
# spend paths emit this with their pool tag so future items, sphere nodes,
# cards, and enemies can react to "spending action points", "spending brain
# points", or "spending flash points" specifically.
signal action_points_spent(pool: String, amount: int)

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

var max_mana: int = 50
var current_mana: float = 50.0
var base_mana_regen: float = 10.0
var maintained_mana: int = 0  # Mana reserved by maintained Power cards

# ============================================
# DERIVED STATS
# ============================================
var base_carry_capacity: int = 50
var current_carry_load: int = 0

var base_attack_speed_counter: int = 45
var current_attack_counter: int = 0

var base_draw_timer: float = 5.0
# hand_size is DERIVED: base + WIS bonus + the two modifiers below. Never
# add to hand_size directly — recalculate_derived_stats() rebuilds it.
var hand_size: int = 4
var equipment_hand_bonus: int = 0  # sum of equipped items' hand_size_bonus
var temp_hand_modifier: int = 0    # card effects (Try This, etc.)

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
var next_odds_boost: float = 0.0  # One-shot boost (Loaded Die / House Money), consumed on next roll
var elixir_stacks: int = 0  # Elixir: next N poison ticks heal instead of hurting (1 stack per tick)
var is_blinded: bool = false      # Blind (e.g. Giant Hawk): attacks may miss
var blind_tempo: int = 0
var blind_miss_chance: float = 0.8
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
var sphere_vulnerable_amp: float = 0.0     # Extra percentage points on YOUR Vulnerable's damage amp (25.0 → enemies take +55% instead of +30%)
var sphere_weaken_amp: float = 0.0         # Extra percentage points on YOUR Weaken's damage reduction (25.0 → enemies deal -55% instead of -30%)
# Buff amps: sphere-grid bonuses to the buffs YOU gain (playstyle amplification).
var sphere_haste_amp: int = 0              # +charges (movements) on Haste applications
var sphere_enlightened_amp: float = 0.0    # +percentage points on Enlightened's crit chance (10% base)
var sphere_brace_amp: int = 0              # +percentage points on Brace's damage reduction
var sphere_blessed_draw_amp: int = 0       # +cards per cycle on Blessed
var sphere_blessed_amp: int = 0            # +charges (cycles) on Blessed applications
# Equipment-granted equivalents (added/removed by Inventory on equip/unequip,
# mirroring the base_* stat pattern). Kept separate from the sphere bonuses so
# unequip subtracts exactly what the item added.
var equipment_crit_bonus: float = 0.0        # +% crit chance from gear (Monocle, Duelist's Visor)
var equipment_lifesteal_bonus: float = 0.0   # +% attack damage healed from gear (Hannibals Mask)
var equipment_resistance_bonus: float = 0.0  # +% all-damage resistance from gear (Thick Steel Helm)
var equipment_defense_card_block: int = 0    # +armor added when a DEFENSE card grants armor (Burgonet, Thick Steel)
var equipment_armorless_defense_block: int = 0  # armor granted by DEFENSE cards that grant none themselves (Burgonet)
var temp_on_self_crit_bonus: float = 0.0     # one-shot +% crit for the card currently resolving (Monocle on-self)
var temp_crit_damage_bonus: float = 0.0      # one-shot +crit-damage multiplier for the resolving card (Feathered Hat 0.10)
var flash_crit_accum: int = 0                # Feathered Hat: flash points spent toward the next armed crit
var flash_crit_armed: bool = false           # Feathered Hat: next ranged offensive card is a guaranteed crit
# Wizard Hat: every Nth attack arms +spell power on the next spell card played.
var equipment_spell_power_every_n: int = 0   # trigger every N attacks (Wizard Hat 3)
var equipment_spell_power_amount: int = 0    # spell-power granted when it triggers (Wizard Hat 5)
var _wizard_attack_counter: int = 0
var pending_spell_power_bonus: int = 0       # applied to the next spell card's damage, then cleared on play
# Boots pass-2 equipment riders
var equipment_sidestep_bonus_armor: int = 0  # +armor on a flash sidestep (Titanium Toe Tuckers)
var equipment_movement_flash_discount: int = 0  # movement flash costs this much less (Rollerblades)
var equipment_highground_damage_percent: float = 0.0  # +% damage from high ground (Mountain Boots)
var on_high_ground: bool = false             # updated by main each cycle; gates the high-ground bonus
var equipment_melee_crit_bonus: int = 0      # flat extra damage on a melee crit (Knife Toed Boots)
var resolving_melee_offensive: bool = false  # transient: set while a melee offensive CARD resolves (gates the above)
var resolving_attack_target = null           # transient: the victim of the card currently resolving (crit riders read it)
var equipment_trap_damage_percent: float = 0.0  # +% trap damage against enemies (Hermes Boots)
var movement_flash_accum: int = 0            # flash spent on movement toward the Boots of Speed threshold
var movement_flash_tempo_threshold: int = 0  # Boots of Speed: at this accum, fire the -1-tempo bonus
signal movement_flash_threshold_reached      # main removes 1 tempo from a hand card
var consecutive_attacks: int = 0             # Cyde Livingstons Sneakers streak counter
var consecutive_attacks_draw_at: int = 0     # streak length that triggers a draw (Cyde 5)
signal consecutive_attacks_reached           # main draws a card
var aura_physical_resist: float = 0.0        # Guardian Greaves aura: % physical resist, refreshed each cycle
# Gauntlets pass
var equipment_crit_damage_bonus: float = 0.0 # +crit damage multiplier from gear (Sleeved Katar 0.25)
var equipment_attack_card_damage: int = 0    # +X damage on attack cards (generic channel)
var equipment_melee_card_damage: int = 0     # +X damage on melee offensive cards only (Brass Knuckles)
var pending_melee_damage_bonus: int = 0      # next melee offensive card +X (Katar's Defense One with Offense)
var equipment_armor_loss_regen_threshold: int = 0  # Hallowed Trunk: armor lost per regen stack (0 = off)
var equipment_regen_include_health: bool = false   # Hallowed Trunk Lv3: health lost counts too
var aura_crit_bonus: float = 0.0             # smoke bomb zone: +% crit while inside (refreshed per tick)
var equipment_heal_maxhp_percent: float = 0.0  # healing cards add this % of max health (Alchemist belt)
var last_attacker = null                     # enemy that is currently striking us (Return Cut)
signal attack_fully_blocked                  # armor absorbed an entire hit (Return Cut trigger)
var _armor_loss_accum: int = 0
var _health_loss_accum: int = 0
# Iron Bastion constellation: chance to reduce an incoming hit by a percentage.
var damage_proc_reduction_chance: float = 0.0
var damage_proc_reduction_percent: float = 50.0
# Chests pass
var equipment_block_physical_resist: float = 0.0  # +% physical resist while armor is up (Smithed Excellence)
var equipment_resist_per_missing10: float = 0.0   # +% all-resist per missing-health step (Divine Resistance)
var equipment_resist_missing_step: int = 10       # % of missing health per resist grant (Divine Resistance 8, Lv3 7)
signal armor_broken                               # a hit just broke through your armor (Briarhide / Adimantium react)
signal curse_of_the_living_shared(amount: int)    # Coffin Lid: heal every ally by this much
var equipment_gold_gain_heal: int = 0             # heal X whenever gold is gained (Suit and Tie)
var equipment_hp_diff_divisor: int = 0            # health-gap bonus damage divisor, 0 = off (Tigers Sunday Red)
var equipment_ranged_range_bonus: int = 0         # +range on ranged offensive cards (Tigers Sunday Red)
var movement_tempo_surcharge: int = 0             # each tile moved on tempo costs this much extra (Adimantium)
var temp_strength_bonus: int = 0                  # summed MIGHT buffs (Ragnarok); damage only, never carry
var death_stack_crit_damage: float = 0.0          # Hide of Garmr Lv3: +crit-damage multiplier from death stacks
var free_move_tiles: int = 0                      # Shadow Cowl shift: tiles that cost no tempo and no flash
# Weapons pass
var equipment_armor_shred: int = 0                # attacks strip this much extra enemy armor (Armor Chopper)
var equipment_shield_melee_damage: int = 0        # +melee damage while a shield is up (Spartan Spear)
var equipment_melee_reach: int = 0                # +melee reach while a shield is up (Spartan Spear)
var equipment_attack_speed_penalty: int = 0       # attack-speed proc threshold penalty (Bessy)
var pending_wrath_percent: int = 0                # Purge Wrath: next attack's % bonus, then cleared
# Shields pass: the off hand that fights back.
var equipment_flat_damage_reduction: int = 0      # every incoming hit is cut by this, flat (Buckler / Vanguard 3)
var equipment_low_health_lifesteal: float = 0.0   # +% lifesteal while below half health (Coffin Lid 8)
var equipment_flash_bonus: int = 0                # +max flash points from gear (Slotted Rope Half Sleeve 4)
var current_temp_mana: int = 0                    # Bouncing Shield: mana that sits ABOVE the maximum
var temp_mana_tempo_remaining: int = 0            # tempo left on the temp-mana pool
var pending_mana_ward: bool = false               # Mind over Matter: next hit is halved and paid out of mana
var last_exposed_armor: int = 0                   # armor the most recent armor-breaking hit ate
var pending_armor_return: int = 0                 # Reverberate Regrowth: armor owed back after an Exposed hit
var pending_armor_return_tempo: int = 0           # raw tempo until that armor reverberates back
# Ranged pass
var improvised_ammo_crit_bonus: float = 0.0       # Wrist Rocket: +% crit on Improvised Ammo, banked by discards; cumulative — never resets
var bow_instance_count: int = 0                   # Bow of Budding Blasts: living bow summons (main keeps this current)
# Ring pass
var invulnerable_tempo: int = 0                   # Marvolo Gaunt: raw tempo of full damage immunity (ticks in process_tempo)
var shadow_form_tempo: int = 0                    # The Precious: raw tempo remaining in shadow form (0 = not in it)
var shadow_form_entered_at: int = 0               # global tempo when the form began (must spend >= 1 tempo inside)
var _shadow_mana_stash: int = 0                   # max mana withheld while in shadow form, restored on exit
var draupnir_clone_alive: bool = false            # Draupnir: a duplicate walks (main keeps this current); the ring waits while true
var _passive_heal: bool = false                   # transient: this heal is regen/lifesteal — ring heal counters ignore it (actual heals only)
signal marvolo_triggered                          # Marvolo Gaunt's lethal save just fired (main applies the Misunderstanding)
signal shadow_form_ended                          # shadow form just ended (expiry or toggle) — main hides the wraiths
var last_attack_target = null                     # Sabre Tooth: previous attack's target
var hit_streak: int = 0                           # Axe's Axe: hits taken toward the Death Vortex trigger

# ============================================
# SPHERE GRID KEYSTONES (build-defining nodes)
# ============================================
var keystone_det_vitality: bool = false  # Bulwark Soul: +2 max HP per DET point, retroactive + ongoing
var keystone_dex_ranged: bool = false    # Deadeye Form: ranged damage scales with DEX instead of STR
# Unbroken Will: Determination's penalty can never push the stat multiplier
# below DET_FLOOR_MODIFIER (instead of the default 0.1) — half your stats is
# the worst low-health can do.
var keystone_det_floor: bool = false
# Wild Abandon: Determination's per-point effect is amplified in BOTH
# directions — a bigger low-health bonus for high DET, a bigger penalty for low.
var keystone_det_amplify: bool = false
# Flurry Form: the DEX attack proc strikes twice, but every attack deals
# DEX_TWIN_STRIKE_DAMAGE_PENALTY less — a faster, lighter flurry.
var keystone_dex_twin_strike: bool = false
# Killing Rhythm: no tempo/mana proc; instead every would-be proc arms a
# DEX-scaled bonus-damage burst on the next attack.
var keystone_dex_flat_damage: bool = false
# Bonus damage armed by Killing Rhythm, spent by the next attack that resolves.
var pending_dex_bonus_damage: int = 0
# Flash Cut: the Sidestep action (3 flash → block) becomes an attack instead —
# spend the same flash to strike the nearest enemy for FLASH_STRIKE_DAMAGE.
var keystone_flash_strike: bool = false
# Weighted Strikes: a one-handed weapon's heft feeds basic attacks (the
# weight-to-damage bonus normally only two-handing grants).
var keystone_str_weight_basic: bool = false
# Balanced Load: items in the chosen slot weigh STR_LIGHT_SLOT_REDUCTION less,
# stacking with other slot weight reductions. str_light_slot_type is the picked
# ItemData.ItemType (-1 until chosen).
var keystone_str_light_slot: bool = false
var str_light_slot_type: int = -1
# Quick Study: when the hand empties, auto-draw 1 card WITHOUT touching the
# timed-draw countdown (handled in Main._on_hand_updated).
var keystone_wis_empty_draw: bool = false
# Tactician's Eye: crit chance rises with the number of cards in hand.
var keystone_wis_hand_crit: bool = false
# Arcane Ward: each mana-regen tick grants armor equal to half your Intelligence.
var keystone_int_regen_armor: bool = false
# Arcane Echo: casting a spell has an INT/3% chance to deal INT/2 damage to a
# random enemy (rolled in Main at the spell-cast site).
var keystone_int_spell_proc: bool = false
# Sanguine Barrier: life steal grants temporary HP instead of healing.
var keystone_lifesteal_temp_hp: bool = false
# Living Bulwark: armor gains become temporary HP instead.
var keystone_armor_temp_hp: bool = false
# Arcane Blood: damage that reaches health is split evenly with mana (health
# takes the odd point and any share mana can't cover; death only at 0 HP).
var keystone_mana_blood: bool = false
# Willspring: Determination's swing is driven by mana percentage, not health.
var keystone_det_mana: bool = false
const CONVERSION_TEMP_HP_TEMPO: int = 15  # duration of keystone-converted temp HP
var _det_vitality_hp_applied: int = 0    # HP currently granted by Bulwark Soul (re-synced as DET changes)
const DET_VITALITY_HP_PER_POINT: int = 2
const DET_AMPLIFY_FACTOR: float = 1.5    # Wild Abandon: ×1.5 to the determination swing
const DET_FLOOR_MODIFIER: float = 0.5    # Unbroken Will: raised lower clamp (default 0.1)
const DEX_TWIN_STRIKE_DAMAGE_PENALTY: int = 2   # Flurry Form: per-hit damage traded for the extra strike (placeholder)
const DEX_FLAT_DAMAGE_PER_POINT: float = 0.5    # Killing Rhythm: bonus damage per DEX on each trigger (placeholder)
const STR_LIGHT_SLOT_REDUCTION: float = 0.10    # Balanced Load: chosen slot weighs this much less
const WIS_CRIT_PER_CARD: int = 2                # Tactician's Eye: +crit% per card in hand (placeholder)

func get_hand_size_crit_bonus() -> int:
	## Tactician's Eye: bonus crit chance from cards currently in hand.
	if not keystone_wis_hand_crit:
		return 0
	if inventory and inventory.deck_manager:
		return inventory.deck_manager.hand.size() * WIS_CRIT_PER_CARD
	return 0

func set_str_light_slot(item_type: int) -> void:
	## Balanced Load: choose which equipment slot the 10% weight cut applies to.
	str_light_slot_type = item_type
	if inventory:
		inventory._recalculate_carry_load()
	print("[STATS] Balanced Load slot set to %d" % item_type)

func refresh_det_vitality() -> void:
	## Re-sync Bulwark Soul's HP grant with the CURRENT determination — points
	## gained (or lost) after unlocking adjust max health immediately.
	if not keystone_det_vitality:
		return
	var target := DET_VITALITY_HP_PER_POINT * determination
	var delta := target - _det_vitality_hp_applied
	if delta == 0:
		return
	max_health += delta
	current_health = clampi(current_health + maxi(delta, 0), 1, max_health)
	_det_vitality_hp_applied = target
	health_changed.emit(current_health, max_health)
	print("[STATS] Bulwark Soul: %+d max HP (now %d)" % [delta, max_health])
# Per-damage-type resistance, keyed by DamageTypes.Type → percent reduction (0..100).
# Empty by default; nothing populates it yet, but the take_damage pipeline reads it.
var damage_resistances: Dictionary = {}
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
var st_pre_attack_target_id: int = -1  # Pre-hit snapshot (set per attack in arm_pre_attack_passives)
var st_pre_attack_armor: int = 0       # Target's armor before the hit landed
var st_pre_attack_health: int = 0      # Target's health before the hit landed
var st_ladder_discard_count: int = 0   # Ladder Work: non-play discards this cycle
var st_ladder_banked: int = 0          # Ladder Work: last cycle's count, spent on first attack

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
var st_dominate_cooldown: int = 0     # Dominate: remaining cooldown tempo
var st_deadly_crit_active: bool = false  # Deadly: +50% crit damage while resolving an attack on an isolated target

# Cory passive tracking
var st_mana_gain_counter: int = 0     # Energy Barrier: counts non-regen mana gains toward every-3rd
var st_expel_charges: int = 2          # Expel Negativity: shared charge pool (2 max); one charge per trigger
var st_expel_last_used_tempo: int = -100  # Expel Negativity: global tempo when charges were last exhausted
var st_enraged_will_last_tempo: int = -100  # Enraged Will: global tempo of the last AOE swing (10 tempo cooldown)
var st_cards_this_cycle: Array[String] = []  # Self Reliance: card types played this tempo cycle
var st_self_reliance_discount: bool = false   # Self Reliance: next card costs -10m
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
var st_whispers_caster = null         # PlayerStats of whoever cast the mark (pays the 8 HP cost); null = self
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
const HP_PER_LEVEL: int = 2          # Max health gained automatically each level
const STAT_POINTS_PER_LEVEL: int = 3 # Stat points banked each level

var current_level: int = 1
var current_xp: int = 0
var total_xp: int = 0  # Lifetime XP earned
var unspent_stat_points: int = 0  # Banked from level-ups; spent via the skill tree screen

# ============================================
# GOLD
# ============================================
var gold: int = 0

# ============================================
# EFFECTIVE STATS (with determination modifier)
# ============================================

var strength: int:
	get:
		return max(1, get_effective_stat(base_strength) + _directed_strength_mod())

func _directed_strength_mod() -> int:
	## Brad's Directed Strength passive: +5 STR below 50% health, lost above.
	if not has_skill_tree_passive("directed_strength"):
		return 0
	return 5 if get_health_percent() <= 0.5 else 0

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

func get_base_stat(stat_name: String) -> int:
	## Base (unmodified) value of a named stat — allocation and permanent
	## growth only, untouched by Determination's combat swings. Used by stat
	## gates and weapon mastery breakpoints.
	match stat_name:
		"strength": return base_strength
		"dexterity": return base_dexterity
		"intelligence": return base_intelligence
		"wisdom": return base_wisdom
		"agility": return base_agility
		"determination": return determination
	return 0

# ============================================
# INITIALIZATION
# ============================================

func initialize(data: CharacterData) -> void:
	character_data = data

	# Willspring: every mana mutation emits mana_changed, so one self-connection
	# covers all of them — recalc stats when mana crosses a DET threshold.
	if not mana_changed.is_connected(_on_mana_changed_for_det):
		mana_changed.connect(_on_mana_changed_for_det)

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
	current_flash_points = get_max_flash_points()
	current_brain_points = get_max_brain_points()
	brain_draws_bought = 0
	brain_peeks_bought = 0

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
		"unspent_stat_points": unspent_stat_points,
		"gold": gold,
		# Sphere grid keystones
		"keystone_det_vitality": keystone_det_vitality,
		"keystone_dex_ranged": keystone_dex_ranged,
		"keystone_det_floor": keystone_det_floor,
		"keystone_det_amplify": keystone_det_amplify,
		"keystone_dex_twin_strike": keystone_dex_twin_strike,
		"keystone_dex_flat_damage": keystone_dex_flat_damage,
		"keystone_flash_strike": keystone_flash_strike,
		"keystone_str_weight_basic": keystone_str_weight_basic,
		"keystone_str_light_slot": keystone_str_light_slot,
		"str_light_slot_type": str_light_slot_type,
		"keystone_wis_empty_draw": keystone_wis_empty_draw,
		"keystone_wis_hand_crit": keystone_wis_hand_crit,
		"keystone_int_regen_armor": keystone_int_regen_armor,
		"keystone_int_spell_proc": keystone_int_spell_proc,
		"keystone_lifesteal_temp_hp": keystone_lifesteal_temp_hp,
		"keystone_armor_temp_hp": keystone_armor_temp_hp,
		"keystone_mana_blood": keystone_mana_blood,
		"keystone_det_mana": keystone_det_mana,
		"_det_vitality_hp_applied": _det_vitality_hp_applied,
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
		# Sphere combat bonuses that feed non-base fields. These are baked into
		# their own scalars (never re-derived from the grid after load), so they
		# MUST round-trip or they silently reset to 0 on every save / world
		# transition — the "my stats got reset" bug.
		"sphere_bonus_determination": sphere_bonus_determination,
		"sphere_bonus_regen": sphere_bonus_regen,
		"sphere_bonus_armor_per_cycle": sphere_bonus_armor_per_cycle,
		"sphere_bonus_life_steal": sphere_bonus_life_steal,
		"sphere_bonus_resistance": sphere_bonus_resistance,
		"sphere_bonus_range": sphere_bonus_range,
		"sphere_vulnerable_amp": sphere_vulnerable_amp,
		"sphere_weaken_amp": sphere_weaken_amp,
		"sphere_haste_amp": sphere_haste_amp,
		"sphere_enlightened_amp": sphere_enlightened_amp,
		"sphere_brace_amp": sphere_brace_amp,
		"sphere_blessed_draw_amp": sphere_blessed_draw_amp,
		"sphere_blessed_amp": sphere_blessed_amp,
		"damage_proc_reduction_chance": damage_proc_reduction_chance,
		"damage_proc_reduction_percent": damage_proc_reduction_percent,
		"damage_resistances": damage_resistances.duplicate(true),
		# Equipment-derived bonuses stored OUTSIDE base stats. Equipment is
		# re-installed on load by direct array assignment (no _apply_item_bonuses
		# re-run), so these too must round-trip or an equipped item's hand-size /
		# ranged / healing / chance bonus vanishes after a transition.
		"equipment_hand_bonus": equipment_hand_bonus,
		"ranged_damage_bonus": ranged_damage_bonus,
		"healing_bonus": healing_bonus,
		"chance_boost": chance_boost,
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
	unspent_stat_points = data.get("unspent_stat_points", unspent_stat_points)
	gold = data.get("gold", gold)
	# Sphere grid keystones
	keystone_det_vitality = data.get("keystone_det_vitality", keystone_det_vitality)
	keystone_dex_ranged = data.get("keystone_dex_ranged", keystone_dex_ranged)
	keystone_det_floor = data.get("keystone_det_floor", keystone_det_floor)
	keystone_det_amplify = data.get("keystone_det_amplify", keystone_det_amplify)
	keystone_dex_twin_strike = data.get("keystone_dex_twin_strike", keystone_dex_twin_strike)
	keystone_dex_flat_damage = data.get("keystone_dex_flat_damage", keystone_dex_flat_damage)
	keystone_flash_strike = data.get("keystone_flash_strike", keystone_flash_strike)
	keystone_str_weight_basic = data.get("keystone_str_weight_basic", keystone_str_weight_basic)
	keystone_str_light_slot = data.get("keystone_str_light_slot", keystone_str_light_slot)
	str_light_slot_type = data.get("str_light_slot_type", str_light_slot_type)
	keystone_wis_empty_draw = data.get("keystone_wis_empty_draw", keystone_wis_empty_draw)
	keystone_wis_hand_crit = data.get("keystone_wis_hand_crit", keystone_wis_hand_crit)
	keystone_int_regen_armor = data.get("keystone_int_regen_armor", keystone_int_regen_armor)
	keystone_int_spell_proc = data.get("keystone_int_spell_proc", keystone_int_spell_proc)
	keystone_lifesteal_temp_hp = data.get("keystone_lifesteal_temp_hp", keystone_lifesteal_temp_hp)
	keystone_armor_temp_hp = data.get("keystone_armor_temp_hp", keystone_armor_temp_hp)
	keystone_mana_blood = data.get("keystone_mana_blood", keystone_mana_blood)
	keystone_det_mana = data.get("keystone_det_mana", keystone_det_mana)
	_det_vitality_hp_applied = data.get("_det_vitality_hp_applied", _det_vitality_hp_applied)
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
	# Sphere combat bonuses that feed non-base fields (see save_progression).
	sphere_bonus_determination = data.get("sphere_bonus_determination", sphere_bonus_determination)
	sphere_bonus_regen = data.get("sphere_bonus_regen", sphere_bonus_regen)
	sphere_bonus_armor_per_cycle = data.get("sphere_bonus_armor_per_cycle", sphere_bonus_armor_per_cycle)
	sphere_bonus_life_steal = data.get("sphere_bonus_life_steal", sphere_bonus_life_steal)
	sphere_bonus_resistance = data.get("sphere_bonus_resistance", sphere_bonus_resistance)
	sphere_bonus_range = data.get("sphere_bonus_range", sphere_bonus_range)
	sphere_vulnerable_amp = data.get("sphere_vulnerable_amp", sphere_vulnerable_amp)
	sphere_weaken_amp = data.get("sphere_weaken_amp", sphere_weaken_amp)
	sphere_haste_amp = data.get("sphere_haste_amp", sphere_haste_amp)
	sphere_enlightened_amp = data.get("sphere_enlightened_amp", sphere_enlightened_amp)
	sphere_brace_amp = data.get("sphere_brace_amp", sphere_brace_amp)
	sphere_blessed_draw_amp = data.get("sphere_blessed_draw_amp", sphere_blessed_draw_amp)
	sphere_blessed_amp = data.get("sphere_blessed_amp", sphere_blessed_amp)
	damage_proc_reduction_chance = data.get("damage_proc_reduction_chance", damage_proc_reduction_chance)
	damage_proc_reduction_percent = data.get("damage_proc_reduction_percent", damage_proc_reduction_percent)
	damage_resistances = data.get("damage_resistances", damage_resistances)
	# Equipment-derived bonuses stored outside base stats (see save_progression).
	equipment_hand_bonus = data.get("equipment_hand_bonus", equipment_hand_bonus)
	ranged_damage_bonus = data.get("ranged_damage_bonus", ranged_damage_bonus)
	healing_bonus = data.get("healing_bonus", healing_bonus)
	chance_boost = data.get("chance_boost", chance_boost)
	# Skill tree passives
	skill_tree_passives = data.get("skill_tree_passives", skill_tree_passives)
	# Recalculate derived stats with restored values
	recalculate_derived_stats()
	refresh_flash_points()
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)
	armor_changed.emit(current_armor)
	print("[STATS] Progression restored: Level %d, XP %d, %d passives" % [current_level, current_xp, skill_tree_passives.size()])

func recalculate_derived_stats() -> void:
	var base_hand = character_data.base_hand_size if character_data else 4
	hand_size = maxi(1, base_hand + get_wisdom_hand_bonus() + equipment_hand_bonus + temp_hand_modifier)
	refresh_det_vitality()
	stats_updated.emit()

func adjust_temp_hand(delta: int) -> void:
	## Card-driven hand size changes (e.g. Try This ±2) — tracked separately so
	## they survive stat recalculation.
	temp_hand_modifier += delta
	recalculate_derived_stats()

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
	print("[STATS] Flash: %d/%d | Hand Size: %d | Draw Timer: %.2f" % [
		current_flash_points, get_max_flash_points(), hand_size, get_effective_draw_timer()
	])

# ============================================
# DETERMINATION SYSTEM
# ============================================

func get_health_percent() -> float:
	if max_health <= 0:
		return 1.0
	return float(current_health + current_temp_health) / float(max_health)

func get_mana_percent() -> float:
	if max_mana <= 0:
		return 1.0
	return current_mana / float(max_mana)

func get_determination_resource_percent() -> float:
	## The resource fraction Determination reacts to: health normally, mana
	## when the Willspring keystone is attached.
	if keystone_det_mana:
		return get_mana_percent()
	return get_health_percent()

var _det_mana_last_pct: float = 1.0

func _on_mana_changed_for_det(_cur: float, _max_val: int) -> void:
	## Willspring: mana is the Determination driver, so crossing a threshold on
	## the mana pool re-derives stats the same way health crossings do.
	var new_pct = get_mana_percent()
	if keystone_det_mana and _crossed_threshold(_det_mana_last_pct, new_pct):
		recalculate_derived_stats()
		stats_updated.emit()
	_det_mana_last_pct = new_pct

# DET's swing is deliberately gentle per point: at the cap (~63 DET) the
# death's-door bonus lands near +50%, not the multi-hundred-percent spikes
# an uncapped multiplier produced under the old 1/5/7/10% tiers.
const DET_NEUTRAL: int = 15

func get_determination_modifier() -> float:
	# Returns multiplier for stats based on determination and the driving
	# resource percent — health normally, mana under Willspring.
	# At DET_NEUTRAL: no effect (1.0)
	# Below it: penalties as the resource drains
	# Above it: bonuses as the resource drains

	var health_pct = get_determination_resource_percent()
	var det_diff = determination - DET_NEUTRAL

	# Determine which threshold and effect percentage
	var effect_per_point = 0.0

	if health_pct <= 0.1:
		# 10% health or below: 1% per point
		effect_per_point = 0.01
	elif health_pct <= 0.4:
		# 40% health: 0.6% per point
		effect_per_point = 0.006
	elif health_pct <= 0.6:
		# 60% health: 0.25% per point
		effect_per_point = 0.0025
	elif health_pct <= 0.8:
		# 80% health: 0.1% per point
		effect_per_point = 0.001
	else:
		# Above 80%: no effect
		return 1.0

	# Calculate total modifier
	var total_modifier = det_diff * effect_per_point

	# Wild Abandon: amplify the whole swing (buff and penalty alike).
	if keystone_det_amplify:
		total_modifier *= DET_AMPLIFY_FACTOR

	# Return as multiplier. The penalty side only clamps at zero (Unbroken Will
	# raises that floor to DET_FLOOR_MODIFIER); the buff side is uncapped — at
	# these per-point rates the reachable ceiling stays modest.
	var floor_clamp = DET_FLOOR_MODIFIER if keystone_det_floor else 0.0
	return max(floor_clamp, 1.0 + total_modifier)

func get_determination_description() -> String:
	var modifier = get_determination_modifier()

	if modifier == 1.0:
		return "No effect (%s > 80%%)" % ("Mana" if keystone_det_mana else "HP")
	elif modifier > 1.0:
		return "+%.0f%% to stats" % ((modifier - 1.0) * 100)
	else:
		return "%.0f%% to stats" % ((modifier - 1.0) * 100)

# ============================================
# STRENGTH CALCULATIONS
# ============================================

# Wielding something two-handed ties up both arms: total carry capacity drops
# to 70%. (The two-handed item's own weight halves — see Inventory's
# two-handed constants — so the trade only pays off for genuinely heavy
# gear.) 0.7 is a deliberate floor: any harsher and a maxed-STR hero
# two-handing the heaviest gear starts losing attack speed, and two-handing
# stops enabling early wields.
const TWO_HAND_CAPACITY_MULT: float = 0.7

var two_hand_active: bool = false   # set by Inventory.set_two_handed
var two_hand_damage_bonus: int = 0  # from the two-handed weapon's ORIGINAL weight

func get_carry_capacity() -> int:
	return get_carry_capacity_two_handing(two_hand_active)

func get_carry_capacity_two_handing(two_handing: bool) -> int:
	# Uses effective strength (with determination) — a DET berserker's capacity
	# genuinely spikes at low HP, which can turn a two-hander one-handable.
	var cap = base_carry_capacity + (strength * 10)
	if two_handing:
		cap = floori(cap * TWO_HAND_CAPACITY_MULT)
	return cap

func get_free_carry_capacity() -> int:
	return get_carry_capacity() - current_carry_load

# The basic attack's flat baseline (STR pipeline applies on top).
const BASIC_ATTACK_BASE_DAMAGE := 3

func get_basic_attack_damage() -> int:
	## The deterministic core of a basic swing — baseline through the physical
	## pipeline. Consumable bonuses (Killing Rhythm, Strengthen, crit) land on
	## top of this in the attack path; effects that scale off "auto attack
	## damage" (e.g. Choke) read this value.
	return get_effective_physical_damage(BASIC_ATTACK_BASE_DAMAGE)

func get_strength_damage_bonus() -> int:
	# Uses effective strength: +0.5 melee damage per point (rounds down).
	# temp_strength_bonus is the summed MIGHT buffs (Ragnarok) — damage only.
	return floori((strength + temp_strength_bonus) * 0.5)

func set_carry_load(weight: int) -> void:
	current_carry_load = weight
	print("[STATS] Carry load: %d / %d" % [current_carry_load, get_carry_capacity()])

func set_two_hand_state(active: bool, damage_bonus: int) -> void:
	two_hand_active = active
	two_hand_damage_bonus = damage_bonus
	print("[STATS] Two-handing %s (+%d damage), capacity %d" % [
		"ON" if active else "off", damage_bonus, get_carry_capacity()])

func is_overburdened() -> bool:
	return current_carry_load > get_carry_capacity()

# ============================================
# AGILITY / FLASH POINTS
# ============================================

## Flash points: 1 per AGI point, refreshed every FLASH_REFRESH_CYCLES tempo
## cycles — 3 cycles = 15 tempo (TempoManager drives the refresh).
## spend_flash_points() is the generic hook — movement costs FLASH_COST_MOVE;
## dodge-blocks, attack-speed proc ticks etc. draw from the same pool.
const FLASH_REFRESH_CYCLES: int = 3
const FLASH_COST_MOVE: int = 3
const FLASH_COST_BLOCK: int = 3   # "quick enough to get slightly out of the way"
const FLASH_BLOCK_ARMOR: int = 2
const FLASH_STRIKE_DAMAGE: int = 1   # Flash Cut keystone: damage per Sidestep spend (placeholder)
const FLASH_COST_PROC_TICK: int = 5  # advance the attack-speed counter 1 tick

# ---- The free-hand stance ----
# Exactly one hand item (weapon OR shield) with a genuinely empty hand.
# Kept fresh by Inventory. Benefits: the flash parry costs 1 less, and every
# SINGLE_HAND_ECHO_EVERY-th attack echoes — it triggers twice. The echo is
# free: it never advances the attack-speed counter and can't itself echo.
const SINGLE_HAND_ECHO_EVERY: int = 12
var free_hand_stance: bool = false
var _free_hand_attack_count: int = 0
var _pending_free_hand_echo: bool = false

var current_flash_points: int = 0
# HUD toggle (the lightning-bolt button): spending flash on movement is the
# player's CHOICE — off by default, moves cost tempo as normal.
var flash_movement_enabled: bool = false

func get_max_flash_points() -> int:
	# Movement enchantments feed the pool too: each old "+1 free move per tempo"
	# bonus is worth 5 FREE MOVES of flash per refresh window (denominated in
	# moves, so it scales with the move cost).
	return agility + enchantment_movement_bonus * 5 * FLASH_COST_MOVE + equipment_flash_bonus

func refresh_flash_points() -> void:
	current_flash_points = get_max_flash_points()
	flash_points_changed.emit(current_flash_points, get_max_flash_points())

func spend_flash_points(amount: int) -> bool:
	if current_flash_points < amount:
		return false
	current_flash_points -= amount
	flash_points_changed.emit(current_flash_points, get_max_flash_points())
	action_points_spent.emit("flash", amount)
	return true

func gain_flash_points(amount: int) -> void:
	## Restore flash points, capped at max (Hermes Boots on-self).
	if amount <= 0:
		return
	current_flash_points = min(get_max_flash_points(), current_flash_points + amount)
	flash_points_changed.emit(current_flash_points, get_max_flash_points())

func get_flash_block_cost() -> int:
	## The free-hand stance parries cheaper (3 → 2): one hand item, one hand
	## empty, nothing between you and the sidestep.
	return FLASH_COST_BLOCK - 1 if free_hand_stance else FLASH_COST_BLOCK

func spend_flash_for_block() -> bool:
	## Convert flash points into FLASH_BLOCK_ARMOR armor (cost via
	## get_flash_block_cost — the free-hand stance discounts it).
	## Raw armor on purpose — this is a sidestep, not a block card, so
	## enchantment/sphere block bonuses don't apply.
	var cost := get_flash_block_cost()
	if not spend_flash_points(cost):
		return false
	var sidestep_armor := FLASH_BLOCK_ARMOR + equipment_sidestep_bonus_armor  # Titanium Toe Tuckers
	current_armor += sidestep_armor
	armor_changed.emit(current_armor)
	armor_gained.emit(sidestep_armor)
	print("[STATS] Flash block: -%d flash → +%d armor (%d armor total)" % [
		cost, sidestep_armor, current_armor])
	return true

func spend_flash_for_strike() -> bool:
	## Flash Cut: spend the same flash the Sidestep would, but the caller turns it
	## into an attack (FLASH_STRIKE_DAMAGE to the nearest enemy) instead of armor.
	## Pays the free-hand discount exactly like the Sidestep.
	return spend_flash_points(get_flash_block_cost())

func spend_flash_for_proc_tick() -> bool:
	## Buy one tick of the attack-speed counter with flash points ("quick
	## hands"). Reuses register_attack, so reaching 0 fires the proc normally.
	if not spend_flash_points(FLASH_COST_PROC_TICK):
		return false
	register_attack(false)  # a bought tick, not a real attack — no echo credit
	return true

# ============================================
# WISDOM / BRAIN POINTS
# ============================================

## Brain points: 1 per WIS point, refreshed every BRAIN_REFRESH_CYCLES tempo
## cycles (5 cycles = 25 tempo — slower than flash on purpose: the body is
## twitchy, the mind is deliberate). Spends are card-economy only, upholding
## the AGI/WIS domain line: flash never touches cards, brain never touches
## tiles. Both pools are independent children of the ACTION POINTS category
## (see the action_points_spent signal).
const BRAIN_REFRESH_CYCLES: int = 5
## Cost of each draw bought within one refresh window (then +5 per extra,
## with no cap — pools above 75 keep buying). The first five total 75, so a
## 75-WIS pool buys the full set in one window; WIS itself has no maximum
## (DET and items push it higher).
const BRAIN_DRAW_COSTS := [5, 10, 15, 20, 25]
const BRAIN_PEEK_BASE_COST: int = 5   # first peek each window
const BRAIN_PEEK_COST_STEP: int = 2   # each further peek costs this much more

var current_brain_points: int = 0
var brain_draws_bought: int = 0   # draws bought this refresh window (escalates the price)
var brain_peeks_bought: int = 0   # peeks bought this refresh window (escalates the price)

var equipment_brain_points_bonus: int = 0  # +max brain points from gear (Scholars Cap)
var equipment_peek_discount: int = 0        # brain-point Peek cost reduction from gear (Scholars Cap)

func get_max_brain_points() -> int:
	return wisdom + equipment_brain_points_bonus

func gain_brain_points(amount: int) -> void:
	if amount <= 0:
		return
	current_brain_points = min(get_max_brain_points(), current_brain_points + amount)
	brain_points_changed.emit(current_brain_points, get_max_brain_points())

func refresh_brain_points() -> void:
	current_brain_points = get_max_brain_points()
	brain_draws_bought = 0
	brain_peeks_bought = 0
	brain_points_changed.emit(current_brain_points, get_max_brain_points())

func get_next_brain_draw_cost() -> int:
	if brain_draws_bought < BRAIN_DRAW_COSTS.size():
		return BRAIN_DRAW_COSTS[brain_draws_bought]
	return BRAIN_DRAW_COSTS[-1] + 5 * (brain_draws_bought - BRAIN_DRAW_COSTS.size() + 1)

func get_next_brain_peek_cost() -> int:
	return max(1, BRAIN_PEEK_BASE_COST + BRAIN_PEEK_COST_STEP * brain_peeks_bought - equipment_peek_discount)

func spend_brain_points(amount: int) -> bool:
	if current_brain_points < amount:
		return false
	current_brain_points -= amount
	brain_points_changed.emit(current_brain_points, get_max_brain_points())
	action_points_spent.emit("brain", amount)
	return true

func spend_brain_for_draw() -> bool:
	## Buy an extra card draw (the caller performs the actual draw).
	var cost := get_next_brain_draw_cost()
	if not spend_brain_points(cost):
		return false
	brain_draws_bought += 1
	print("[STATS] Brain draw bought: -%d brain (%d left, next costs %d)" % [
		cost, current_brain_points, get_next_brain_draw_cost()])
	return true

func spend_brain_for_peek() -> bool:
	## Buy one card of peek depth (the deck manager tracks what's revealed).
	var cost := get_next_brain_peek_cost()
	if not spend_brain_points(cost):
		return false
	brain_peeks_bought += 1
	print("[STATS] Brain peek bought: -%d brain (%d left, next costs %d)" % [
		cost, current_brain_points, get_next_brain_peek_cost()])
	return true

# ============================================
# DEXTERITY / ATTACK SPEED
# ============================================

# Encumbrance term of the attack-speed threshold. Carrying weight only ever
# SLOWS the counter: a naked character takes no modifier at all, and the
# penalty grows with the FRACTION of carry capacity in use — capacity itself
# (STR) never speeds anything up, it just raises how much you can wear before
# the penalty bites. Speeding the counter up belongs to DEX, items, and other
# effects, which keeps that space open for itemization.
const CAPACITY_SPEED_MAX_PENALTY: int = 7   # penalty at 100% of carry capacity
const OVERBURDENED_SPEED_PENALTY: int = 10  # flat penalty while over carry capacity

func get_capacity_speed_modifier() -> int:
	## 0 while unencumbered; positive (slower) as the load ratio climbs.
	if is_overburdened():
		return OVERBURDENED_SPEED_PENALTY
	var capacity = get_carry_capacity()
	if capacity <= 0 or current_carry_load <= 0:
		return 0
	var ratio = clampf(float(current_carry_load) / float(capacity), 0.0, 1.0)
	return roundi(ratio * CAPACITY_SPEED_MAX_PENALTY)

# DEX pays per-point into crit damage too, so its counter contribution is
# fractional. The minimum of 1 is deliberately reachable by a maxed light
# build — proc-per-attack is the DEX capstone fantasy (Dominate's cooldown
# keeps that from looping). Encumbrance only ever ADDS to the threshold.
const DEX_COUNTER_PER_POINT: float = 0.5
const ATTACK_COUNTER_MIN: int = 1
const DUAL_WIELD_COUNTER_BONUS: int = 4  # attacks shaved while dual wielding

func get_attack_speed_threshold() -> int:
	# Uses effective dexterity
	var threshold = base_attack_speed_counter - floori(dexterity * DEX_COUNTER_PER_POINT) \
			+ get_capacity_speed_modifier() + equipment_attack_speed_penalty
	if inventory and inventory.is_dual_wielding():
		threshold -= DUAL_WIELD_COUNTER_BONUS
	return max(ATTACK_COUNTER_MIN, threshold)

func register_attack(is_real_attack: bool = true) -> Dictionary:
	current_attack_counter -= 1

	# Wizard Hat: every Nth real attack arms bonus spell power on the next spell.
	if is_real_attack and equipment_spell_power_every_n > 0:
		_wizard_attack_counter += 1
		if _wizard_attack_counter >= equipment_spell_power_every_n:
			_wizard_attack_counter = 0
			pending_spell_power_bonus += equipment_spell_power_amount
			print("[STATS] Wizard Hat: next spell gains +%d spell power" % equipment_spell_power_amount)

	# Cyde Livingstons Sneakers: a run of consecutive attacks draws a card.
	if is_real_attack and consecutive_attacks_draw_at > 0:
		consecutive_attacks += 1
		if consecutive_attacks >= consecutive_attacks_draw_at:
			consecutive_attacks = 0
			consecutive_attacks_reached.emit()

	# Free hand: every 12th registered attack echoes. Echoes themselves are
	# never registered, so they can't advance this count or the DEX counter —
	# and bought counter ticks (flash proc-tick) aren't attacks either.
	if free_hand_stance and is_real_attack:
		_free_hand_attack_count += 1
		if _free_hand_attack_count >= SINGLE_HAND_ECHO_EVERY:
			_free_hand_attack_count = 0
			_pending_free_hand_echo = true
			print("[STATS] Free hand echo! The attack strikes twice.")

	print("[STATS] Attack counter: %d / %d" % [current_attack_counter, get_attack_speed_threshold()])
	
	if current_attack_counter <= 0:
		current_attack_counter = get_attack_speed_threshold()
		# Killing Rhythm: trade the tempo/mana proc for a DEX-scaled damage burst
		# armed on the next attack. No dexterity_proc signal (no half tempo/mana).
		if keystone_dex_flat_damage:
			var bonus = get_dex_proc_flat_bonus()
			pending_dex_bonus_damage += bonus
			print("[STATS] Killing Rhythm! Next attack +%d damage (DEX %d)" % [bonus, dexterity])
			return {
				"proc": false,
				"mana_discount": 0,
				"half_tempo": false,
				"flat_damage": bonus
			}
		dexterity_proc.emit()
		print("[STATS] *** DEX PROC! *** Half tempo + 2 mana discount!")
		return {
			"proc": true,
			"mana_discount": 2,
			"half_tempo": true,
			# Flurry Form: the proc-empowered attack strikes twice (read at play time).
			"twin_strike": keystone_dex_twin_strike
		}

	return {
		"proc": false,
		"mana_discount": 0,
		"half_tempo": false
	}

func get_attacks_until_proc() -> int:
	return current_attack_counter

func consume_free_hand_echo() -> bool:
	## True exactly once per armed echo — the attack that was just registered
	## should repeat. Callers fire the repeat WITHOUT registering it again.
	var fire := _pending_free_hand_echo
	_pending_free_hand_echo = false
	return fire

# ============================================
# INTELLIGENCE CALCULATIONS
# ============================================

func get_intelligence_spell_bonus() -> int:
	# +0.5 spell/heal power per point (flat, like strength; rounds down)
	return floori(intelligence * 0.5)

func get_intelligence_mana_regen_bonus() -> float:
	# +1 mana regen per point — INT is the sustain stat, the way STR is the
	# damage stat. Every point matters on the x10 mana scale: at INT 75 a
	# caster regenerates a big spell (~80 mana) every cycle.
	return float(intelligence)

func get_int_spell_proc_chance() -> float:
	## Arcane Echo: percent chance (INT/3) to echo bonus damage on a spell cast.
	return intelligence / 3.0

func get_int_spell_proc_damage() -> int:
	## Arcane Echo: bonus damage (INT/2) to a random enemy when it echoes.
	return floori(intelligence / 2.0)

# ============================================
# WISDOM CALCULATIONS
# ============================================

func get_wisdom_hand_bonus() -> int:
	# Secondary WIS perk: +1 hand size per 10 points (rounds down). Hand size
	# growth mainly lives on gear and the sphere grid; WIS's primary identity
	# is brain points (1 per point).
	return floori(wisdom / 10.0)

func get_effective_draw_timer() -> float:
	## Card-draw interval in GLOBAL TEMPO — a flat base (default 5 cycles =
	## 25 tempo). WIS no longer accelerates it; extra draws come from
	## brain-point purchases instead.
	return max(1.0, base_draw_timer * 5.0)

# ============================================
# COMBINED CALCULATIONS
# ============================================

func get_effective_mana_regen() -> float:
	return base_mana_regen + get_intelligence_mana_regen_bonus() + enchantment_mana_regen_bonus

func get_tempo_until_mana_regen() -> int:
	## Whole tempo remaining before the next mana-regen tick (shown in the HUD
	## raindrop). Clamped to at least 1 so it never reads 0 between ticks.
	return maxi(1, int(ceil(_tempo_until_mana_regen)))

# Crit damage: every crit multiplies damage by 110% base, and Dexterity adds
# +3% per point on top — DEX's second job alongside the attack-speed proc.
# No stat affects crit CHANCE; that stays on items, cards, and other effects.
const BASE_CRIT_DAMAGE: float = 1.1
const CRIT_DAMAGE_PER_DEX: float = 0.03

func get_crit_damage_multiplier() -> float:
	## Uses effective Dexterity, so Determination swings crit damage too.
	## Deadly adds +50% while resolving an attack on an isolated target.
	var deadly_bonus := 0.5 if st_deadly_crit_active else 0.0
	return BASE_CRIT_DAMAGE + dexterity * CRIT_DAMAGE_PER_DEX + deadly_bonus + equipment_crit_damage_bonus \
		+ temp_crit_damage_bonus + death_stack_crit_damage

## Mountain Boots: +% damage while attacking from high ground.
func _apply_highground(damage: int) -> int:
	if on_high_ground and equipment_highground_damage_percent > 0.0:
		return floori(damage * (1.0 + equipment_highground_damage_percent / 100.0))
	return damage

func get_effective_physical_damage(base_damage: int) -> int:
	var damage = base_damage + get_strength_damage_bonus() + enchantment_damage_bonus + sphere_bonus_damage + two_hand_damage_bonus
	if keystone_dex_twin_strike:
		damage -= DEX_TWIN_STRIKE_DAMAGE_PENALTY
	return max(1, _apply_highground(damage))

func get_effective_ranged_damage(base_damage: int) -> int:
	var damage = base_damage + get_strength_damage_bonus() + ranged_damage_bonus + enchantment_damage_bonus + sphere_bonus_damage + two_hand_damage_bonus
	if keystone_dex_twin_strike:
		damage -= DEX_TWIN_STRIKE_DAMAGE_PENALTY
	return max(1, _apply_highground(damage))

func get_dex_proc_flat_bonus() -> int:
	## Killing Rhythm: DEX-scaled bonus damage granted on each would-be proc.
	return floori(dexterity * DEX_FLAT_DAMAGE_PER_POINT)

func consume_pending_dex_bonus_damage() -> int:
	## Take (and clear) the Killing Rhythm bonus armed for the next attack.
	var b = pending_dex_bonus_damage
	pending_dex_bonus_damage = 0
	return b

func get_effective_spell_damage(base_damage: int) -> int:
	# INT: +1 damage per point (flat). Wizard Hat's armed spell power (if any)
	# rides along; it's cleared on the spell's play, not here (this is a query).
	return max(1, _apply_highground(base_damage + get_intelligence_spell_bonus() + enchantment_damage_bonus + sphere_bonus_damage + pending_spell_power_bonus))

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
	# Ring pass timers run on raw tempo.
	if invulnerable_tempo > 0:
		invulnerable_tempo = max(0, invulnerable_tempo - amount)
	if shadow_form_tempo > 0:
		shadow_form_tempo = max(0, shadow_form_tempo - amount)
		if shadow_form_tempo <= 0:
			exit_shadow_form()
	# Reverberate Regrowth: the armor the Exposed hit ate comes back on time.
	if pending_armor_return > 0:
		pending_armor_return_tempo = max(0, pending_armor_return_tempo - amount)
		if pending_armor_return_tempo <= 0:
			var echoed: int = pending_armor_return
			pending_armor_return = 0
			add_armor(echoed)
			print("[STATS] Reverberate Regrowth: %d armor echoes back" % echoed)
	# Temporary mana (Bouncing Shield) runs on raw tempo, like the ring timers.
	if current_temp_mana > 0 and temp_mana_tempo_remaining > 0:
		temp_mana_tempo_remaining = max(0, temp_mana_tempo_remaining - amount)
		if temp_mana_tempo_remaining <= 0:
			_expire_temp_mana()
	_tempo_until_mana_regen -= float(amount)
	if _tempo_until_mana_regen <= 0.0:
		_tempo_until_mana_regen += mana_regen_tempo_interval
		var mana_regen = get_effective_mana_regen()
		current_mana = min(current_mana + mana_regen, get_available_max_mana())
		mana_changed.emit(current_mana, max_mana)
		mana_gained.emit(int(mana_regen), true)
		print("[STATS] Mana regen: +%.1f → %d/%d (reserved: %d)" % [mana_regen, int(current_mana), max_mana, maintained_mana])
		# Arcane Ward: convert each regen tick into armor equal to half INT. Raw
		# armor (like the flash sidestep) — block bonuses don't apply.
		if keystone_int_regen_armor:
			var ward = floori(intelligence / 2.0)
			if ward > 0:
				current_armor += ward
				armor_changed.emit(current_armor)
				armor_gained.emit(ward)
				print("[STATS] Arcane Ward: +%d armor (%d total)" % [ward, current_armor])

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

	# Blind ticks per raw tempo in advance_status_tempo, not here.

	recalculate_derived_stats()

## Timed status flags that count RAW tempo — called on every tempo advance
## (any amount), so durations not divisible by 5 work.
func advance_status_tempo(amount: int) -> void:
	if amount <= 0:
		return
	if blind_tempo > 0:
		blind_tempo -= amount
		if blind_tempo <= 0:
			blind_tempo = 0
			is_blinded = false
			print("[STATS] Blind wore off")

# ============================================
# RESOURCE MANAGEMENT
# ============================================

func get_damage_resistance(damage_type: int) -> float:
	## Percent reduction (0..100) this character has against `damage_type`.
	return float(damage_resistances.get(damage_type, 0.0))

func add_damage_resistance(damage_type: int, percent: float) -> void:
	damage_resistances[damage_type] = get_damage_resistance(damage_type) + percent

func take_damage(amount: int, debuff_mgr = null, buff_mgr = null, damage_type: int = DamageTypes.Type.PHYSICAL) -> void:
	# Marvolo Gaunt: nothing touches you while the ring's grace holds.
	if invulnerable_tempo > 0:
		print("[STATS] Invulnerable — %d damage ignored" % amount)
		return
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

	# Mind over Matter (Presence of Mind): the armed hit is halved and what is
	# left is paid out of the mana pool, point for point. Mana that can't cover
	# it lets the remainder through the normal pipeline — the ward is spent
	# either way.
	if pending_mana_ward and amount > 0:
		var ward_incoming := amount
		pending_mana_ward = false
		amount = amount - floori(amount * 0.5)
		var ward_paid: int = mini(amount, floori(current_mana))
		if ward_paid > 0:
			_spend_temp_mana_first(ward_paid)
			amount -= ward_paid
		print("[STATS] Mind over Matter: %d damage paid in mana, %d left over" % [ward_paid, amount])
		if amount <= 0:
			# The blow still landed as far as reaction cards are concerned.
			damage_taken.emit(ward_incoming)
			return

	var remaining = amount

	# Stone Skin: 10% damage resistance against Fire, Physical, and Lightning only.
	if has_skill_tree_passive("stone_skin") and damage_type in [DamageTypes.Type.PHYSICAL, DamageTypes.Type.FIRE, DamageTypes.Type.LIGHTNING]:
		remaining = floori(remaining * 0.9)

	# Per-type resistance (e.g. elemental resists once cards start tagging types).
	# Guardian Greaves' aura adds transient physical resist on top.
	var type_resist = get_damage_resistance(damage_type)
	if damage_type == DamageTypes.Type.PHYSICAL:
		type_resist += aura_physical_resist
		# Smithed Excellence: extra physical resist while you have block up.
		if current_armor > 0 and equipment_block_physical_resist > 0.0:
			type_resist += equipment_block_physical_resist
	if type_resist > 0.0:
		remaining = floori(remaining * (1.0 - min(type_resist, 100.0) / 100.0))

	# Flat all-damage resistance from the sphere grid ("Resist +X%") plus any
	# equipment resistance (e.g. Thick Steel Helm): percent reduction on all damage.
	var flat_resist := sphere_bonus_resistance + equipment_resistance_bonus
	# Divine Resistance: +X% all-type resist per full step of missing health.
	if equipment_resist_per_missing10 > 0.0:
		var resist_step: int = maxi(1, equipment_resist_missing_step)
		flat_resist += equipment_resist_per_missing10 * int((1.0 - get_health_percent()) * 100.0 / resist_step)
	if flat_resist > 0.0:
		remaining = floori(remaining * (1.0 - minf(flat_resist, 90.0) / 100.0))

	# Shields (Buckler, Vanguard): a flat bite taken out of every hit, applied
	# after the percentage resists so it is worth the most against chip damage.
	if equipment_flat_damage_reduction > 0 and remaining > 0:
		remaining = maxi(0, remaining - equipment_flat_damage_reduction)

	# Iron Bastion: chance to shrug off part of the hit.
	if damage_proc_reduction_chance > 0.0 and remaining > 0 and randf() < damage_proc_reduction_chance:
		remaining = floori(remaining * (1.0 - damage_proc_reduction_percent / 100.0))
		print("[STATS] Iron Bastion! Incoming damage reduced %d%%" % int(damage_proc_reduction_percent))

	# Apply Vulnerable modifier from debuffs
	if debuff_mgr:
		remaining = debuff_mgr.modify_incoming_damage(remaining)

	# Linked: share a portion of the damage with the linked ally (co-op).
	if debuff_mgr and debuff_mgr.linked_ally != null and is_instance_valid(debuff_mgr.linked_ally) and remaining > 0:
		var linked_share = debuff_mgr.calculate_linked_damage(remaining)
		if linked_share > 0 and debuff_mgr.linked_ally.has_method("get_stats") and debuff_mgr.linked_ally.get_stats():
			debuff_mgr.linked_ally.get_stats().take_direct_damage(linked_share)
			print("[STATS] Linked shares %d damage with the ally" % linked_share)

	# Apply Brace and Resilient from buffs (Resilient may be type-gated, e.g. Harden)
	if buff_mgr:
		remaining = buff_mgr.calculate_damage_reduction(remaining, damage_type)

	# Fallen's Wrath: every damage instance stokes the counter, and holding
	# 10+ Wrath means every hit lands half again as hard. Applied before
	# armor so the risk is real.
	if remaining > 0 and inventory and "equipped_weapons" in inventory:
		for fw_w in inventory.equipped_weapons:
			if fw_w and fw_w.wrath_weapon:
				fw_w.wrath = mini(30, fw_w.wrath + 1)
				if fw_w.wrath >= 10:
					remaining = floori(remaining * 1.5)
					print("[STATS] Fallen's Wrath: 10+ Wrath — the hit lands 50%% harder")
				break

	# Vined Encasing (Briarhide Plate): thorns shed value equal to damage received.
	if buff_mgr and remaining > 0 and buff_mgr.has_method("decay_thorns_by_damage"):
		buff_mgr.decay_thorns_by_damage(remaining)

	# Supernova Cuirass: while it has stack room, the plate drinks part of the
	# hit — damage_bank_percent is absorbed into the cuirass (fuel for
	# Detonova) and damage_bank_mitigate_percent simply vanishes.
	if remaining > 0 and inventory and "equipped_chests" in inventory:
		for sn_chest in inventory.equipped_chests:
			if sn_chest and sn_chest.damage_bank_percent > 0.0 \
					and sn_chest.banked_stacks < sn_chest.damage_bank_max_stacks:
				var sn_absorbed: float = remaining * sn_chest.damage_bank_percent / 100.0
				var sn_cut: int = floori(remaining * (sn_chest.damage_bank_percent + sn_chest.damage_bank_mitigate_percent) / 100.0)
				sn_chest.banked_damage += sn_absorbed
				sn_chest.banked_stacks += 1
				remaining -= sn_cut
				print("[STATS] %s absorbed %.1f (%d/%d stacks), hit reduced by %d" % [sn_chest.item_name,
					sn_absorbed, sn_chest.banked_stacks, sn_chest.damage_bank_max_stacks, sn_cut])

	# Default absorption order: Armor -> temp HP -> HP. Armor is always the
	# first line of defense; items, nodes, enemies, or cards may manipulate
	# this later, but this is the baseline.
	if current_armor > 0 and remaining > 0:
		var armor_before := current_armor
		if current_armor >= remaining:
			current_armor -= remaining
			remaining = 0
			print("[STATS] Armor absorbed damage. Armor: %d" % current_armor)
			# Return Cut: the whole hit was eaten by armor.
			attack_fully_blocked.emit()
		else:
			remaining -= current_armor
			current_armor = 0
			# Reverberate Regrowth reads what the breaking hit actually ate.
			last_exposed_armor = armor_before
			print("[STATS] Armor broke! %d damage passes through" % remaining)
			# Briarhide / Adimantium: the shell cracked — armored chests react.
			# The reaction armor arrives AFTER this hit resolves.
			armor_broken.emit()

		# Hallowed Trunk: bank armor lost toward regen stacks.
		if equipment_armor_loss_regen_threshold > 0 and buff_mgr:
			_armor_loss_accum += armor_before - current_armor
			while _armor_loss_accum >= equipment_armor_loss_regen_threshold:
				_armor_loss_accum -= equipment_armor_loss_regen_threshold
				buff_mgr.apply_buff(Buff.create_regen(1, 15, "Hallowed Trunk"))

		armor_changed.emit(current_armor)

	# Temp health absorbs what gets past armor
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

	# Arcane Blood: mana soaks half of what would hit health (health keeps the
	# odd point) at the standing 10-mana-per-1-damage exchange rate. If mana
	# can't cover its share, health takes the leftover — so death still only
	# comes from HP reaching 0.
	if keystone_mana_blood and remaining > 1 and current_mana > 0:
		var mana_share = mini(remaining / 2, floori(current_mana / 10.0))
		if mana_share > 0:
			_drain_mana_as_health(mana_share * 10)
			remaining -= mana_share

	if remaining > 0:
		# Hallowed Trunk Lv3: health lost also banks toward regen stacks.
		if equipment_armor_loss_regen_threshold > 0 and equipment_regen_include_health and buff_mgr:
			_health_loss_accum += remaining
			while _health_loss_accum >= equipment_armor_loss_regen_threshold:
				_health_loss_accum -= equipment_armor_loss_regen_threshold
				buff_mgr.apply_buff(Buff.create_regen(1, 15, "Hallowed Trunk"))
		var old_pct = get_health_percent()
		current_health = max(0, current_health - remaining)
		health_changed.emit(current_health, max_health)
		health_damage_taken.emit(remaining)

		if _crossed_threshold(old_pct, get_health_percent()):
			recalculate_derived_stats()

	# Emit damage_taken for reaction card triggers
	damage_taken.emit(amount)

	# Whispers of the Flock: Shepherd's Mark prevents lethal damage
	# When triggered, the marked target survives but the CASTER takes 8 damage
	if current_health <= 0 and st_whispers_active:
		current_health = 1
		add_armor(10)
		st_whispers_active = false
		st_whispers_tempo = 0
		st_whispers_cooldown = 20
		health_changed.emit(current_health, max_health)
		_pay_whispers_cost()
		shepherds_mark_triggered.emit()
		print("[STATS] Shepherd's Mark triggered! Survived at 1 HP + 10 armor.")

	# Marvolo Gaunt: a lethal blow leaves you at 1 instead. Deliberately AFTER
	# Shepherd's Mark, so the mark wins the race and the ring's 50-tempo
	# cooldown isn't burned when the mark would have saved you anyway.
	_try_marvolo_save()

	if current_health <= 0:
		died.emit()

	# Blood Libation: gain a Sanguine stack whenever Jeremy takes damage.
	if has_skill_tree_passive("blood_libation"):
		sanguine_stacks = min(5, sanguine_stacks + 1)

## Marvolo Gaunt: if lethal damage just landed and the ring is equipped and
## off cooldown, survive at 1 HP, become untouchable for 3 tempo, and heal 25.
## The ring then misunderstands: main applies the purgeable 25-damage-in-7
## debuff off the marvolo_triggered signal (the debuff manager isn't
## reachable from here).
func _try_marvolo_save() -> void:
	if current_health > 0 or inventory == null:
		return
	for r in inventory.equipped_rings:
		if r != null and r.item_name == "Marvolo Gaunt" and int(r.ring_counters.get("cd", 0)) <= 0:
			r.ring_counters["cd"] = 50  # tempo
			current_health = 1
			invulnerable_tempo = 3
			health_changed.emit(current_health, max_health)
			heal(25)
			marvolo_triggered.emit()
			print("[STATS] Marvolo Gaunt: saved at 1 HP — invulnerable 3 tempo, healed 25. The ring misunderstands.")
			return

## The Precious: enter shadow form. Halves the max mana pool (restored on
## exit) and grants 10 brain + 10 flash points that may exceed their caps.
func enter_shadow_form(global_tempo_now: int) -> void:
	if shadow_form_tempo > 0:
		return
	shadow_form_tempo = 10
	shadow_form_entered_at = global_tempo_now
	_shadow_mana_stash = max_mana - floori(max_mana / 2.0)
	max_mana -= _shadow_mana_stash
	current_mana = min(current_mana, max_mana)
	mana_changed.emit(current_mana, max_mana)
	# Deliberately uncapped — the shadow gives generously, beyond the maxima.
	current_brain_points += 10
	brain_points_changed.emit(current_brain_points, get_max_brain_points())
	current_flash_points += 10
	flash_points_changed.emit(current_flash_points, get_max_flash_points())
	stats_updated.emit()
	print("[STATS] Shadow form: mana halved (-%d), +10 brain, +10 flash." % _shadow_mana_stash)

func exit_shadow_form() -> void:
	if shadow_form_tempo <= 0 and _shadow_mana_stash == 0:
		return
	shadow_form_tempo = 0
	max_mana += _shadow_mana_stash
	_shadow_mana_stash = 0
	mana_changed.emit(current_mana, max_mana)
	stats_updated.emit()
	shadow_form_ended.emit()
	print("[STATS] Shadow form ends — the world sharpens back.")

func _pay_whispers_cost() -> void:
	## The 8-HP cost of a triggered Shepherd's Mark goes to whoever cast it.
	## A self-cast mark can't re-kill the survivor it just saved — it costs
	## HP down to a floor of 1 instead.
	var caster = st_whispers_caster
	st_whispers_caster = null
	if caster != null and caster != self:
		caster.take_direct_damage(8)
		print("[STATS] Shepherd's Mark cost: caster takes 8 damage.")
	else:
		current_health = max(1, current_health - 8)
		health_changed.emit(current_health, max_health)
		print("[STATS] Shepherd's Mark cost: 8 HP (non-lethal, self-cast).")

func take_direct_damage(amount: int) -> void:
	## Deal damage directly to HP, bypassing armor entirely. Deliberately NOT
	## blocked by Marvolo's invulnerability: this path carries self-paid costs
	## (card health costs, the Bow of Arash's life half, Shepherd's cost, the
	## Misunderstanding itself) — the ring's grace stops enemies, not bills.
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
	# When triggered, the marked target survives but the CASTER takes 8 damage
	if current_health <= 0 and st_whispers_active:
		current_health = 1
		add_armor(10)
		st_whispers_active = false
		st_whispers_tempo = 0
		st_whispers_cooldown = 20
		health_changed.emit(current_health, max_health)
		_pay_whispers_cost()
		shepherds_mark_triggered.emit()
		print("[STATS] Shepherd's Mark triggered! Survived at 1 HP + 10 armor.")

	# Marvolo Gaunt: the same lethal save guards the direct-damage path (a
	# save on only one of the two paths would be a real hole).
	_try_marvolo_save()

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

func _curse_of_the_living_active() -> bool:
	## True while the Coffin Lid's Curse of the Living is being maintained.
	if inventory == null or not ("deck_manager" in inventory) or inventory.deck_manager == null:
		return false
	var dm = inventory.deck_manager
	if not dm.has_method("get_maintained_cards"):
		return false
	for mc in dm.get_maintained_cards():
		if mc and mc.card_id == "curse_of_the_living":
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
	# Blood Libation: Sanguine stacks add +1 healing each; at 5 the heal doubles
	# and the stacks are consumed.
	var bl_consume := false
	if sanguine_stacks > 0 and has_skill_tree_passive("blood_libation"):
		amount += sanguine_stacks
		if sanguine_stacks >= 5:
			amount *= 2
			bl_consume = true
			sanguine_stacks = 0
	# Curse of the Living (Coffin Lid, maintained): the dead take half of
	# everything you are given and pass half of the rest to your allies. The
	# share is emitted for main to deliver — allies aren't reachable from here.
	var curse_share := 0
	if amount > 0 and _curse_of_the_living_active():
		var kept: int = amount - floori(amount / 2.0)
		curse_share = ceili(kept / 2.0)
		amount = kept
		print("[STATS] Curse of the Living: heal halved to %d, %d to each ally" % [kept, curse_share])
	var boosted_amount = get_effective_heal_amount(amount)
	var old_health_pct = get_health_percent()

	# Blood Libation: the 5-stack burst costs 10 non-lethal HP FIRST — the
	# damage resolves before the (doubled) heal lands. A self-heal therefore
	# takes the hit, then heals up from the lowered health.
	if bl_consume:
		current_health = max(1, current_health - 10)
		health_changed.emit(current_health, max_health)
		print("[STATS] Blood Libation burst! Took 10 non-lethal, heal doubled.")

	var old_health = current_health
	current_health += boosted_amount
	current_health = min(current_health, max_health)
	var actual_heal = current_health - old_health
	health_changed.emit(current_health, max_health)
	if actual_heal > 0:
		healed.emit(actual_heal)

	if curse_share > 0:
		curse_of_the_living_shared.emit(curse_share)

	var new_health_pct = get_health_percent()
	print("[STATS] Healed %d (base %d)! Health: %d/%d" % [actual_heal, amount, current_health, max_health])
	
	# Check if we crossed a determination threshold (healing can restore stats)
	if _crossed_threshold(old_health_pct, new_health_pct):
		var mod = get_determination_modifier()
		print("[STATS] Determination threshold crossed! Modifier: %.0f%%" % (mod * 100))
		recalculate_derived_stats()
		stats_updated.emit()

	if actual_heal > 0 and inventory:
		# Ring counters (Heal Stone, Nibelung) count ACTUAL heals only —
		# regen ticks and lifesteal pass 0 so the trigger still fires but the
		# counters stand still.
		inventory.on_healed(0 if _passive_heal else actual_heal)

func apply_life_steal(amount: int) -> void:
	## Single funnel for all life-steal healing (buff, skill-tree passive, sphere
	## bonus). With the Sanguine Barrier keystone, stolen life becomes temporary
	## HP instead of a heal — uncapped by missing health, but it expires.
	if amount <= 0:
		return
	if keystone_lifesteal_temp_hp:
		add_temp_health(amount, CONVERSION_TEMP_HP_TEMPO)
		print("[STATS] Sanguine Barrier: %d life steal became temp HP" % amount)
	else:
		# Lifesteal is not an "actual heal" — ring heal counters skip it.
		_passive_heal = true
		heal(amount)
		_passive_heal = false

func add_armor(amount: int) -> void:
	var total = amount + enchantment_block_bonus + sphere_bonus_block
	# Sword Specialist: +25% block when only wielding swords
	if has_skill_tree_passive("sword_specialist") and inventory and inventory.has_only_swords_equipped():
		total = floori(total * 1.25)
	# Living Bulwark: the full armor gain (bonuses included) becomes temp HP.
	# Armor-gain hooks (overhead icon, on_armor_gained item procs) don't fire —
	# no armor was actually gained.
	if keystone_armor_temp_hp:
		if total > 0:
			add_temp_health(total, CONVERSION_TEMP_HP_TEMPO)
			print("[STATS] Living Bulwark: %d armor became temp HP" % total)
		return
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
	# Living Bulwark: converted to temp HP (see add_armor).
	if keystone_armor_temp_hp:
		if total > 0:
			add_temp_health(total, CONVERSION_TEMP_HP_TEMPO)
			print("[STATS] Living Bulwark: %d armor became temp HP" % total)
		return
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

## Bouncing Shield (Steve Rodgers): mana granted ON TOP of the pool, exactly
## as temp health sits on top of health. It lifts the available ceiling too, so
## a maintained card stops squeezing you while the temp mana lasts.
func add_temp_mana(amount: int, duration_tempo: int) -> void:
	if amount <= 0:
		return
	current_temp_mana += amount
	temp_mana_tempo_remaining = maxi(temp_mana_tempo_remaining, duration_tempo)
	current_mana += amount
	mana_changed.emit(current_mana, max_mana)
	mana_gained.emit(amount, false)
	print("[STATS] Gained %d temporary mana for %d tempo (pool: %d/%d)" % [amount, duration_tempo, int(current_mana), get_available_max_mana()])

func _spend_temp_mana_first(amount: int) -> void:
	## Drain the temp pool before the real one — temp mana is the volatile
	## half, so it should be what a cost eats first.
	var from_temp: int = mini(current_temp_mana, amount)
	current_temp_mana -= from_temp
	current_mana = maxf(0.0, current_mana - amount)
	mana_changed.emit(current_mana, max_mana)
	if current_mana <= 0 and maintained_mana > 0:
		_break_maintained_cards()

func _expire_temp_mana() -> void:
	if current_temp_mana <= 0:
		return
	print("[STATS] Temporary mana expired (-%d)" % current_temp_mana)
	current_temp_mana = 0
	temp_mana_tempo_remaining = 0
	current_mana = minf(current_mana, float(get_available_max_mana()))
	mana_changed.emit(current_mana, max_mana)

## Total lifesteal percent from gear, including the Coffin Lid's below-half
## bonus. Sphere-grid lifesteal and per-card riders are added by the caller.
func get_equipment_lifesteal() -> float:
	var pct := equipment_lifesteal_bonus
	if equipment_low_health_lifesteal > 0.0 and get_health_percent() < 0.5:
		pct += equipment_low_health_lifesteal
	return pct

func spend_mana(amount: int) -> bool:
	if current_mana >= amount:
		_spend_temp_mana_first(amount)
		return true
	return false

func refund_action_cost(mana_amount: int, health_amount: int = 0) -> void:
	## Voluntary action cancel: give back exactly what the play spent — raw
	## amounts, no healing/regen bonuses, capped at the maxima. Health covers
	## plays paid with Demonic Rage.
	if mana_amount > 0:
		current_mana = minf(current_mana + mana_amount, float(max_mana))
		mana_changed.emit(current_mana, max_mana)
	if health_amount > 0:
		current_health = mini(current_health + health_amount, max_health)
		health_changed.emit(current_health, max_health)

func _drain_mana_as_health(amount: int) -> void:
	## Arcane Blood: mana absorbing damage. Mirrors spend_mana's bookkeeping —
	## including breaking maintained cards when the pool hits 0.
	current_mana = max(0.0, current_mana - amount)
	mana_changed.emit(current_mana, max_mana)
	print("[STATS] Arcane Blood: mana absorbed %d damage (mana: %d/%d)" % [amount, int(current_mana), max_mana])
	if current_mana <= 0 and maintained_mana > 0:
		_break_maintained_cards()

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
	## Max mana minus mana reserved by maintained cards, plus any temporary
	## mana — which deliberately eclipses the maximum while it lasts.
	return max(0, max_mana - maintained_mana) + current_temp_mana

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
	## "Regen +1", "Arm/Cyc +1", "Life Steal +3%", "Resist +3%", "Range +1",
	## "Vuln Amp +25%", "Weaken Amp +25%", "Haste Amp +1", "Enlight Amp +10%",
	## "Brace Amp +10%", "Blessed Draw +1", "Blessed Amp +1"
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
		"vuln amp":
			sphere_vulnerable_amp += float(value)
		"weaken amp":
			sphere_weaken_amp += float(value)
		"haste amp":
			sphere_haste_amp += value
		"enlight amp":
			sphere_enlightened_amp += float(value)
		"brace amp":
			sphere_brace_amp += value
		"blessed draw":
			sphere_blessed_draw_amp += value
		"blessed amp":
			sphere_blessed_amp += value
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
	return """STR: %d (base %d) → +%d carry, +%d phys dmg
DEX: %d (base %d) → proc in %d atks
INT: %d (base %d) → +%d spell dmg, +%.0f regen
WIS: %d (base %d) → +%d hand, %d/%d brain points
AGI: %d (base %d) → %d/%d flash points
DET: %d → %s
Level: %d | XP: %d / %d""" % [
		strength, base_strength, strength * 10, get_strength_damage_bonus(),
		dexterity, base_dexterity, get_attacks_until_proc(),
		intelligence, base_intelligence, get_intelligence_spell_bonus(), get_intelligence_mana_regen_bonus(),
		wisdom, base_wisdom, get_wisdom_hand_bonus(), current_brain_points, get_max_brain_points(),
		agility, base_agility, current_flash_points, get_max_flash_points(),
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
	# Suit and Tie: obtaining gold heals — any source, Negotiate included.
	if amount > 0 and equipment_gold_gain_heal > 0:
		heal(equipment_gold_gain_heal)

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

	# Every level: the health floor rises and stat points bank for allocation.
	max_health += HP_PER_LEVEL
	unspent_stat_points += STAT_POINTS_PER_LEVEL

	# Full health and mana on level up
	current_health = max_health
	current_mana = max_mana
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)

	print("[STATS] *** LEVEL UP! *** Now level %d! +%d max HP, +%d stat points (%d banked). HP and Mana fully restored." % [
		current_level, HP_PER_LEVEL, STAT_POINTS_PER_LEVEL, unspent_stat_points])
	leveled_up.emit(current_level)
	xp_changed.emit(current_xp, get_xp_to_next_level())

func apply_stat_allocation(allocations: Dictionary) -> bool:
	## Spend banked level-up stat points. allocations: stat name -> points
	## (e.g. {"strength": 2, "agility": 1}). Partial spends are fine — the
	## remainder stays banked.
	var total := 0
	for stat_name in allocations:
		total += maxi(0, int(allocations[stat_name]))
	if total <= 0 or total > unspent_stat_points:
		return false
	for stat_name in allocations:
		var amount := int(allocations[stat_name])
		if amount > 0:
			add_base_stat(stat_name, amount)
	unspent_stat_points -= total
	stats_updated.emit()
	print("[STATS] Allocated %d stat points (%d still banked): %s" % [total, unspent_stat_points, str(allocations)])
	return true

func grant_stat_points(amount: int) -> void:
	## Banks freely-allocatable stat points into the same pool that level-ups feed.
	## Used by sphere-grid FREE_STAT nodes — the player spends them on the stat
	## screen just like level-up points.
	if amount <= 0:
		return
	unspent_stat_points += amount
	stats_updated.emit()
	print("[STATS] Granted %d free stat point(s) (%d banked)." % [amount, unspent_stat_points])
