class_name Card
extends Resource

## Card resource that holds card data

enum CardType { ATTACK, DEFENSE, UTILITY, REACTION, UNPLAYABLE, POWER, ENCHANTMENT }
enum CardKeyword { NONE, ARROW, POCKET, GEM, CHISEL, SWIFT, BUCKLER, CROWN, FIST }

# The card's SCHOOL — how the card is delivered — orthogonal to CardType (its
# role: offense/defense/utility). A spell can be offensive (Fireball) or
# supportive (Magic Barrier); either way Silence stops it. Disarm stops
# PHYSICAL offensive cards only. SPELL damage scales with INT, PHYSICAL with
# STR. Broad effects ("offensive cards +X") key off CardType and hit every
# school; school-specific effects ("spell damage +X") narrow by this field.
# TRAP is reserved for future placed-device cards; nothing is tagged yet.
enum CardSchool { PHYSICAL, SPELL, TRAP }

# Stack-signature prefix shared by every pure instant (reaction) card so they
# all merge into a single un-lettered hand stack.
const INSTANT_STACK_SIG_PREFIX := "INSTANT|"

# ============================================
# CARD RARITY TIERS
# ============================================
# Mirrors the item rarity tiers so drop tables can weight cards the same way
# (see DropRates.CARD_WEIGHTS). Every card is obtainable through play —
# rarity only shapes how often it drops; there is NO copies-to-upgrade
# system for cards. Retune a card's tier by editing this one dictionary.
enum Rarity { BASIC, COMMON, RARE, LEGENDARY, MYTHIC }

# How many copies of one card a deck may hold, by rarity. -1 = unlimited
# (spam all the Slashes you like); rarer cards are capped so build-defining
# effects stay singular. First-pass numbers — balance later.
const MAX_COPIES_BY_RARITY := {
	Rarity.BASIC: -1,
	Rarity.COMMON: -1,
	Rarity.RARE: 3,
	Rarity.LEGENDARY: 1,
	Rarity.MYTHIC: 1,
}

## Deck copy cap for a card id (-1 = unlimited).
static func max_deck_copies(cid: String) -> int:
	var r = CARD_RARITIES.get(cid, Rarity.COMMON)
	return int(MAX_COPIES_BY_RARITY.get(r, -1))

const CARD_RARITIES := {
	# --- Basic (24) ---
	"slash": Rarity.BASIC, "block": Rarity.BASIC, "discard": Rarity.BASIC,
	"draw": Rarity.BASIC, "empower": Rarity.BASIC, "heal": Rarity.BASIC,
	"gain_mana": Rarity.BASIC, "healing_potion": Rarity.BASIC, "dagger_throw": Rarity.BASIC,
	"wear_down": Rarity.BASIC, "poke": Rarity.BASIC, "parry": Rarity.BASIC,
	"approach": Rarity.BASIC, "shuriken": Rarity.BASIC, "quick_shot": Rarity.BASIC,
	"quick_arrow": Rarity.BASIC, "push": Rarity.BASIC, "lightly_dazed": Rarity.BASIC,
	"thrown_stone": Rarity.BASIC, "minor_wounds": Rarity.BASIC, "energy_ball": Rarity.BASIC,
	"armor_patch": Rarity.BASIC, "spark": Rarity.BASIC, "splinter": Rarity.BASIC,
	# --- Common (48) ---
	"blink": Rarity.COMMON, "taunt": Rarity.COMMON, "life_steal": Rarity.COMMON,
	"roar": Rarity.COMMON, "armor_break": Rarity.COMMON, "trick_shot": Rarity.COMMON,
	"risk_it": Rarity.COMMON, "biscuit": Rarity.COMMON, "loaded_die": Rarity.COMMON,
	"oops": Rarity.COMMON, "hope_this_works": Rarity.COMMON, "raged_circulation": Rarity.COMMON,
	"poisoned_blood": Rarity.COMMON, "elixir": Rarity.COMMON, "reposition": Rarity.COMMON,
	"premeditated": Rarity.COMMON, "mark": Rarity.COMMON, "rise": Rarity.COMMON,
	"reload": Rarity.COMMON, "barricade": Rarity.COMMON, "sky_attack": Rarity.COMMON,
	"mixed_bag": Rarity.COMMON, "trip": Rarity.COMMON, "choke": Rarity.COMMON,
	"defensive_awareness": Rarity.COMMON, "sweeping_disarm": Rarity.COMMON, "consecutive_snap": Rarity.COMMON,
	"swap": Rarity.COMMON, "meditate": Rarity.COMMON, "potion_of_continuance": Rarity.COMMON,
	"spider_senses": Rarity.COMMON, "gulped_potion": Rarity.COMMON, "energy_barrier": Rarity.COMMON,
	"collect_arrows": Rarity.COMMON, "self_infliction": Rarity.COMMON, "bob_and_weave": Rarity.COMMON,
	"cover": Rarity.COMMON, "fortify_alliance": Rarity.COMMON, "shield_ready": Rarity.COMMON,
	"healthy_habit": Rarity.COMMON, "anticipation": Rarity.COMMON, "prepare": Rarity.COMMON,
	"meister_of_faustmesser": Rarity.COMMON, "give_in": Rarity.COMMON, "provider": Rarity.COMMON,
	"healthy_bliss": Rarity.COMMON, "patience": Rarity.COMMON, "gargle_and_spit": Rarity.COMMON,
	# --- Rare (67) ---
	"life_swap": Rarity.RARE, "charge": Rarity.RARE, "heroic_leap": Rarity.RARE,
	"morphine": Rarity.RARE, "turtle_up": Rarity.RARE, "hold_the_line": Rarity.RARE,
	"surrounding_ice": Rarity.RARE, "worst_that_could_happen": Rarity.RARE, "house_money": Rarity.RARE,
	"try_this": Rarity.RARE, "snowballs_chance": Rarity.RARE,
	"shadows": Rarity.RARE, "preparation": Rarity.RARE, "exacerbate_wounds": Rarity.RARE,
	"volatile_mixture": Rarity.RARE, "understanding": Rarity.RARE, "shuriken_pouch": Rarity.RARE,
	"enchanted_quiver": Rarity.RARE, "tighten_string": Rarity.RARE, "down_town": Rarity.RARE,
	"sky_fall": Rarity.RARE, "lead_arrow": Rarity.RARE, "last_breath": Rarity.RARE,
	"bottomless_quiver": Rarity.RARE, "round_em_up": Rarity.RARE, "hydra_bite": Rarity.RARE,
	"halo": Rarity.RARE, "armored_discipline": Rarity.RARE,
	"reckless_strike": Rarity.RARE, "blade_barrage": Rarity.RARE, "cultish_wounds": Rarity.RARE,
	"fountain_of_life": Rarity.RARE, "absorb_essence": Rarity.RARE, "communal_donation": Rarity.RARE,
	"repelled_block": Rarity.RARE, "shield_of_growth": Rarity.RARE, "mana_surge": Rarity.RARE,
	"magic_barrier": Rarity.RARE, "shepherds_mark": Rarity.RARE, "bloodlust": Rarity.RARE,
	"lethal_recall": Rarity.RARE, "smith_thy_soul": Rarity.RARE, "down_but_not_out": Rarity.RARE,
	"enchantment_defense": Rarity.RARE, "enchantment_attack": Rarity.RARE, "enchantment_movement": Rarity.RARE,
	"enchantment_mana_regen": Rarity.RARE, "harness_lightning": Rarity.RARE, "best_offense": Rarity.RARE,
	"vengeful_shield": Rarity.RARE, "release_tension": Rarity.RARE, "vines": Rarity.RARE,
	"savage_strike": Rarity.RARE, "savage_strike_copy": Rarity.RARE, "heavy_swing": Rarity.RARE,
	"shed_weight": Rarity.RARE, "living_armor": Rarity.RARE, "the_lights_favor": Rarity.RARE,
	"hunker_down": Rarity.RARE, "harden": Rarity.RARE, "roll": Rarity.RARE,
	"cryonics": Rarity.RARE, "friendship": Rarity.RARE, "multishot": Rarity.RARE,
	"specific_strike": Rarity.RARE, "spirit_arrow": Rarity.RARE,
	# --- Legendary (13) ---
	"lady_luck": Rarity.LEGENDARY, "demonic_rage": Rarity.LEGENDARY, "item_mastery": Rarity.LEGENDARY,
	"deep_pockets": Rarity.LEGENDARY, "misery_loves_company": Rarity.LEGENDARY, "exposed_artery": Rarity.LEGENDARY,
	"internal_combustion": Rarity.LEGENDARY, "shield_slam": Rarity.LEGENDARY, "tower_shield": Rarity.LEGENDARY,
	"succumb": Rarity.LEGENDARY, "fireball": Rarity.LEGENDARY, "adrenaline_shot": Rarity.LEGENDARY,
	"exhausted_assault": Rarity.LEGENDARY,
	# Helm-granted (item pass 1)
	"twenty_twenty": Rarity.LEGENDARY, "its_alive": Rarity.LEGENDARY,
	# --- Mythic (8) ---
	"if_pigs_could_fly": Rarity.MYTHIC, "gift_from_the_phoenix": Rarity.MYTHIC, "petey_the_pet_rock": Rarity.MYTHIC,
	"mirror_mirror": Rarity.MYTHIC, "god_of_thunder": Rarity.MYTHIC, "worms_armageddon": Rarity.MYTHIC,
	"sprinkle": Rarity.MYTHIC, "sprinkle_bomb": Rarity.MYTHIC,
	# Helm-granted (item pass 1)
	"neither_man_nor_beast": Rarity.MYTHIC, "resourceful_replenish": Rarity.MYTHIC,
	"out_of_guesses": Rarity.MYTHIC,
	# Boot-granted (item pass 1)
	"shiv": Rarity.RARE,
	# Boot-granted (item pass 2)
	"shift": Rarity.LEGENDARY, "donate_cleats": Rarity.LEGENDARY,
	"terrain_formation": Rarity.LEGENDARY, "escape_and_bewilder": Rarity.LEGENDARY,
	"tight_rope": Rarity.MYTHIC, "mend": Rarity.MYTHIC,
	# Gauntlet-granted
	"stance_switch": Rarity.LEGENDARY, "switch_kick": Rarity.LEGENDARY,
	"return_cut": Rarity.LEGENDARY, "smoke_bomb": Rarity.MYTHIC,
	# Belt-granted
	"serene_center": Rarity.LEGENDARY, "stone_encase": Rarity.LEGENDARY,
	"m_for_mini": Rarity.LEGENDARY, "hemotoxins": Rarity.LEGENDARY,
	"poof_and_weave": Rarity.LEGENDARY, "healing_tonic": Rarity.LEGENDARY,
	"poison_bomb": Rarity.RARE,
	"chain_lightning": Rarity.MYTHIC, "ice_grenade": Rarity.MYTHIC, "fire_punch": Rarity.MYTHIC,
	"gift_from_the_gods": Rarity.MYTHIC,
	"protection_from_alnitak": Rarity.MYTHIC, "balance_of_alnilam": Rarity.MYTHIC,
	"crack_of_mintaka": Rarity.MYTHIC,
	# Chest-granted
	"clang_up": Rarity.RARE, "negotiate": Rarity.RARE,
	"detonova": Rarity.LEGENDARY, "mind_mend": Rarity.LEGENDARY,
	"deep_breaths": Rarity.LEGENDARY, "vined_encasing": Rarity.LEGENDARY,
	"adimantium_wall": Rarity.MYTHIC, "preemptive_answer": Rarity.MYTHIC,
	"ragnarok": Rarity.MYTHIC,
	# Weapon-granted
	"hard_helmet": Rarity.COMMON, "slice": Rarity.COMMON,
	"death_vortex": Rarity.LEGENDARY, "earth_rattle": Rarity.LEGENDARY,
	"feed_into_the_pain": Rarity.LEGENDARY, "psionic_flow": Rarity.LEGENDARY,
	"purge_wrath": Rarity.LEGENDARY, "sanguine_the_penguin": Rarity.LEGENDARY,
	"wrath_of_the_sea": Rarity.MYTHIC, "monk_of_the_night": Rarity.MYTHIC,
	# Ranged-item-granted (ranged pass 1)
	"improvised_ammo": Rarity.LEGENDARY,
	"cupids_golden_arrow": Rarity.LEGENDARY, "cupids_lead_arrow": Rarity.LEGENDARY,
	"territorial_mark": Rarity.MYTHIC, "balistic_arrow": Rarity.MYTHIC,
	"close_is_favored": Rarity.MYTHIC, "spirit_bow": Rarity.MYTHIC,
	# Ring-granted (rings pass 1)
	"tricks_of_alberich": Rarity.MYTHIC, "the_nibelung_curse": Rarity.MYTHIC,
	# Shield-granted (shields pass 1)
	"huck": Rarity.LEGENDARY, "rain_of_arrows": Rarity.LEGENDARY,
	"song_of_a_swords_sing": Rarity.LEGENDARY, "curse_of_the_living": Rarity.LEGENDARY,
	"bark_up": Rarity.LEGENDARY, "cinquedea": Rarity.LEGENDARY,
	"mage_shield": Rarity.MYTHIC, "reverberate_regrowth": Rarity.MYTHIC,
	"bouncing_shield": Rarity.MYTHIC, "mind_over_matter": Rarity.MYTHIC,
	# Spell-weapon-granted (spell weapons pass 1)
	"element_pollination": Rarity.LEGENDARY,
	"from_the_ashes": Rarity.MYTHIC, "polymorph": Rarity.MYTHIC,
	"reapers_taking": Rarity.MYTHIC,
	"clear_mind": Rarity.LEGENDARY, "grounding": Rarity.LEGENDARY,
	"defensive_sacrifice": Rarity.LEGENDARY, "crops": Rarity.LEGENDARY,
}

# Cards that never appear in random drops: item-conjured tokens (Sprinkle,
# Shuriken), status junk, generated copies, and cards with their own bespoke
# drop paths (Hydra Bite from the Hydra).
const DROP_EXCLUDED_CARD_IDS := {
	"sprinkle": true, "sprinkle_bomb": true, "splinter": true,
	"shuriken": true, "savage_strike_copy": true,
	"minor_wounds": true, "lightly_dazed": true,
	"hydra_bite": true,
	# Helm/boot-granted cards only arrive via their item, never from random drops.
	"neither_man_nor_beast": true, "resourceful_replenish": true,
	"out_of_guesses": true, "twenty_twenty": true, "its_alive": true,
	"shiv": true, "shift": true, "donate_cleats": true, "terrain_formation": true,
	"escape_and_bewilder": true, "tight_rope": true, "mend": true,
	"stance_switch": true, "switch_kick": true, "return_cut": true, "smoke_bomb": true,
	"serene_center": true, "stone_encase": true, "m_for_mini": true, "hemotoxins": true,
	"poof_and_weave": true, "healing_tonic": true, "poison_bomb": true,
	"chain_lightning": true, "ice_grenade": true, "fire_punch": true,
	"gift_from_the_gods": true, "protection_from_alnitak": true,
	"balance_of_alnilam": true, "crack_of_mintaka": true,
	"clang_up": true, "negotiate": true, "detonova": true, "mind_mend": true,
	"deep_breaths": true, "vined_encasing": true, "adimantium_wall": true,
	"preemptive_answer": true, "ragnarok": true,
	"hard_helmet": true, "slice": true, "death_vortex": true, "earth_rattle": true,
	"feed_into_the_pain": true, "psionic_flow": true, "purge_wrath": true,
	"sanguine_the_penguin": true, "wrath_of_the_sea": true, "monk_of_the_night": true,
	"improvised_ammo": true, "cupids_golden_arrow": true, "cupids_lead_arrow": true,
	"territorial_mark": true, "balistic_arrow": true, "close_is_favored": true,
	"spirit_bow": true,
	"tricks_of_alberich": true, "the_nibelung_curse": true,
	# Shield-granted cards (shields pass 1).
	"huck": true, "rain_of_arrows": true, "song_of_a_swords_sing": true,
	"curse_of_the_living": true, "bark_up": true, "cinquedea": true,
	"mage_shield": true, "reverberate_regrowth": true, "bouncing_shield": true,
	"mind_over_matter": true,
	# Spell-weapon-granted cards (spell weapons pass 1).
	"element_pollination": true, "from_the_ashes": true,
	"polymorph": true, "reapers_taking": true,
	"clear_mind": true, "grounding": true,
	"defensive_sacrifice": true, "crops": true,
}

@export var card_id: String = "slash"
@export var card_name: String = "Slash"
@export var description: String = "10 damage"
@export var card_type: CardType = CardType.ATTACK
@export var card_type_name: String = "Attack"
@export var mana_cost: int = 1
@export var health_cost: int = 0  # Paid in HEALTH on play, on top of mana (Mind Mend). Refuses the play at or below the cost.
@export var percent_mana_cost: float = 0.0  # Costs this fraction of CURRENT mana instead of mana_cost (Wrath of the Sea 0.5). The spend is recorded on last_percent_mana_paid.
var last_percent_mana_paid: int = 0  # What the last percent_mana_cost play actually spent (drives Wrath of the Sea's damage)
@export var damage: int = 10
@export var block: int = 0
@export var heal_amount: int = 0
@export var tempo_cost: int = 4
@export var resolve_tick: int = 1  # Which tick (1-based) the card's effect resolves on (1 = immediate, tempo_cost = last tick)
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
var rng_effective_chance: float = 0.0  # chance_effect_percent + boost used on the last roll
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
var snap_uses_at_play: int = 0  # uses BEFORE the current play (set by play_card; timing-safe for deferred execution)
var requires_high_ground: bool = false  # Needs elevated position
var last_damage_dealt: int = 0  # Used by cards that need main.gd to apply damage (charge, leap)
var has_on_draw: bool = false  # Card triggers an effect when drawn
var on_draw_effect: String = ""  # Description of the on-draw effect
var discard_on_draw: bool = false  # If true, card is discarded immediately after on-draw effect
var maintain_cost: int = 0  # Mana reserved while this card is maintained (Power cards)
var erase_tempo: int = 0  # If > 0, card is deleted from deck after this many tempo (Erase keyword)
var erase_tempo_remaining: int = 0  # Tracks remaining tempo before erase triggers
var in_hand_heal_tempo: int = 0  # (legacy field — Healthy Bliss now runs on cycles_in_hand in main)
var rt_chosen_debuff: String = ""  # Release Tension: which enemy debuff the player chose to drain
var picked_card: Card = null  # Reusable: a hand card chosen via the hand-card picker (e.g. Reposition)
var damage_type: int = DamageTypes.Type.PHYSICAL  # Damage type this card deals (all default to Physical for now)
var is_fire_spell: bool = false  # Counts toward Fireball's per-turn fire-spell mana discount
var linger: bool = false  # If true, status card can exceed hand size limit when added
var shop_excluded: bool = false  # If true, the card never appears in the Card Dealer's shop (item-generated cards like Sprinkle)
var erase_on_play: bool = false  # If true, card is erased from the deck entirely the moment it's played (not discarded). Same "erase" concept as erase_tempo, just triggered on play instead of on a timer.
var jail_on_play: int = 0  # If > 0, the card goes to jail for this many tempo after being played (instead of the discard pile)
var reaction_trigger: String = ""  # Trigger condition for reaction cards (e.g., "on_damage_taken")
var card_keyword: CardKeyword = CardKeyword.NONE  # Arrow, Pocket, Gem, Chisel - determines which items can slot this card
var school: CardSchool = CardSchool.PHYSICAL  # Delivery school (see CardSchool). Default PHYSICAL; factories tag spells explicitly.
var element: String = ""  # Elemental identity for Feral Evocation's colored slots: "red" (Burn), "blue" (Cold), "yellow" (Shock), "green" (Poison). "" = not elemental.
var is_chisel: bool = false  # If true, card can only be played when slotted in an item (Chisel keyword)
var has_reach: bool = false  # Reach: adds 1 square to melee attack range
var glut_tempo: int = 0  # Tempo duration the player cannot play cards after using this card
var delay_tempo: int = 0  # Tempo until the card's effect takes place
var has_burden: bool = false  # If true, cost increases by 10m/1t each time played. Can jail to reset.
var burden_plays: int = 0  # How many times this burden card has been played (increases cost)
var burden_jail_duration: int = 30  # Tempo to jail this card to reset burden
var burden_jail_cost_mana: int = 10  # Mana cost to jail a burden card
var burden_jail_cost_tempo: int = 1  # Tempo cost to jail a burden card
var has_on_discard: bool = false  # Card triggers an effect when discarded
var on_discard_effect: String = ""  # Description of the on-discard effect
var in_hand_debuff: String = ""  # Debuff applied while this card is in hand (e.g., "slowed_2")
var in_hand_buff: String = ""  # Buff applied while this card is in hand (Enchantment cards)

# Card upgrade system (Paper Feather upgrades)

# Card-item slot system
enum SlotCompatibility { PICKY, PLIABLE }
var slot_compatibility: SlotCompatibility = SlotCompatibility.PICKY  # Picky = same item type only, Pliable = any item type
var source_item_type: int = -1  # ItemData.ItemType the card was first extracted from (-1 = no restriction yet)
var is_molded: bool = false  # Card is locked into the item and cannot be extracted
var slotted_in_item = null  # Reference to the ItemData this card is slotted in (null = not slotted)
# The item that GRANTED this card to the deck (GRANT_CARDS / GRANT_BLINK_CARD).
# Parallels slotted_in_item: both mark a card as "owned" by an item, so it is
# pulled from every zone when the item is unequipped and returned when it is
# re-equipped. Cards merely PRODUCED during play (e.g. a goblet's heal orb) set
# neither reference and therefore detach — they stay in the deck on a swap.
var granted_by_item = null  # Reference to the ItemData that granted this card (null = not granted)

func is_slotted() -> bool:
	return slotted_in_item != null

func get_stack_signature() -> String:
	## Cards sharing a signature stack under one hand slot / play button. Only
	## copies that look and play identically merge; anything that changes the
	## card's face or how it plays (enhance, cost shifts, jailed, slotted)
	## splits it into its own stack.
	##
	## Pure instant (reaction) cards can never be played manually — they all
	## pile together under one un-lettered stack so they don't clutter the hand
	## or steal a play key (see HandSlots). A card that also plays as a normal
	## card isn't CardType.REACTION and stacks like any other card.
	if card_type == CardType.REACTION:
		return "%s%s" % [INSTANT_STACK_SIG_PREFIX, str(is_jailed())]
	return "%s|%s|%d|%d|%d|%d|%s|%s" % [
		card_id, card_name, mana_cost, tempo_cost,
		int(is_enhanced), bonus_damage,
		str(is_jailed()), str(is_slotted()),
	]

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

## How many KINDS of debuff an enemy is carrying — stacks within one kind count
## once (Song of a Swords Sing: "1 burn, 1 frost, 1 disarm = 3; 3 disarm = 1").
static func count_debuff_kinds(enemy) -> int:
	if enemy == null:
		return 0
	var kinds := 0
	for field in ["burn_stacks", "cold_stacks", "poison_stacks", "shock_stacks",
			"bleed_stacks", "vulnerable_stacks", "weaken_stacks", "slow_stacks",
			"choke_dot_stacks", "disarmed_attacks", "stun_tempo", "silenced_tempo",
			"rooted_tempo", "frozen_tempo", "disarmed_tempo", "marked_tempo"]:
		if field in enemy and int(enemy.get(field)) > 0:
			kinds += 1
	return kinds

func roll_rng(enemies: Array = [], chance_boost: float = 0.0) -> void:
	rng_outcomes.clear()

	# Delfins Deterministic Round Shield: cards slotted into it roll better.
	chance_boost += float(get_on_self_bonus().get("chance_boost", 0.0))

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
	elif chance_effect_percent > 0.0:
		# Pure per-enemy chance (Surrounding Ice): no card-level outcome to roll,
		# but mark the card rolled so the hand pipeline doesn't re-randomize the
		# per-enemy outcomes below on every hand refresh.
		rng_selected_index = 0

	# AOE per-enemy rolls
	if chance_effect_percent > 0.0:
		var effective_chance = chance_effect_percent + chance_boost
		rng_effective_chance = effective_chance
		for enemy in enemies:
			if is_instance_valid(enemy):
				var enemy_roll = randf() * 100.0
				rng_outcomes[enemy.get_instance_id()] = enemy_roll < effective_chance

func get_rng_outcome(enemy) -> bool:
	if not enemy:
		return false
	var id = enemy.get_instance_id()
	if not rng_outcomes.has(id):
		# Enemy appeared after the pre-roll (spawned mid-fight): roll it now at
		# the same boosted chance so late arrivals aren't guaranteed misses.
		if chance_effect_percent <= 0.0:
			return false
		var chance = rng_effective_chance if rng_effective_chance > 0.0 else chance_effect_percent
		rng_outcomes[id] = randf() * 100.0 < chance
	return rng_outcomes[id]

func has_chance_effect() -> bool:
	# Card-level outcomes OR per-enemy AOE rolls — both need the roll/reroll pipeline.
	return rng_outcomes_data.size() > 0 or chance_effect_percent > 0.0

func has_been_rolled() -> bool:
	return rng_selected_index != -1

func rng_binary_succeeded() -> bool:
	## True when a single-outcome (binary) chance card has rolled its success.
	return rng_outcomes_data.size() == 1 and rng_selected_index == 0

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

## Description with the card's base numbers swapped for this character's
## effective values (computed by main.get_card_vacuum_values): what the card
## does in a vacuum — stats, equipment, and standing buffs, before any
## enemy-specific modifiers (those stay on the hover preview). Boosted
## numbers print green, debuffed ones red.
func get_display_description(effective: Dictionary) -> String:
	var text := description
	if rng_outcomes_data.size() > 0 and has_been_rolled():
		text = get_colored_description()
	if effective.is_empty():
		return text
	for kind in ["damage", "block", "heal"]:
		var base_key: String = kind + "_base"
		if effective.has(kind) and effective.has(base_key) \
				and effective[kind] != effective[base_key]:
			text = _sub_number(text, effective[base_key], effective[kind], kind)
	return text


## Words that identify which number in a description belongs to which stat,
## so two stats sharing the same base value (e.g. Fortify Alliance's 5 heal
## / 5 armor) each land on their own slot instead of grabbing left to right.
const _SUB_HINTS := {
	"damage": ["damage", "deal"],
	"block": ["armor", "block"],
	"heal": ["heal", "restore"],
}


## Replace the standalone occurrence of base_val in text with the effective
## value, colored by whether it went up or down. Digits glued to the match
## or a trailing "%" disqualify it (so "30" inside "130" or "30%" is left
## alone). When the kind is known, an occurrence sitting next to that kind's
## keyword ("armor", "heal", ...) wins over an earlier unrelated one.
static func _sub_number(text: String, base_val: int, shown: int, kind: String = "") -> String:
	var needle := str(base_val)
	var candidates: Array[int] = []
	var from := 0
	while true:
		var pos := text.find(needle, from)
		if pos < 0:
			break
		var end := pos + needle.length()
		var before_ok := pos == 0 or not text[pos - 1].is_valid_int()
		var after_ok := end >= text.length() or (not text[end].is_valid_int() and text[end] != "%")
		# Never match inside a BBCode tag (e.g. digits of a #hex color from an
		# earlier substitution).
		var open := text.rfind("[", pos)
		var in_tag := open >= 0 and text.find("]", open) >= end
		if before_ok and after_ok and not in_tag:
			candidates.append(pos)
		from = pos + 1
	if candidates.is_empty():
		return text
	var chosen: int = candidates[0]
	if kind in _SUB_HINTS:
		for pos in candidates:
			var context := text.substr(maxi(0, pos - 20), 20 + needle.length() + 20).to_lower()
			var hinted := false
			for word in _SUB_HINTS[kind]:
				if word in context:
					hinted = true
					break
			if hinted:
				chosen = pos
				break
	var end2 := chosen + needle.length()
	var color := "#8be98b" if shown > base_val else "#ff9c9c"
	return "%s[color=%s]%d[/color]%s" % [text.substr(0, chosen), color, shown, text.substr(end2)]


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

## Returns the CharacterFigure action this card should play when used.
## Single source of truth shared by in-battle playback (main.gd) and the
## Animation Lab. As per-card animations are authored, branch here on card_id
## (and add the matching case + play_* method in CharacterFigure.play_action).
func get_animation_action() -> String:
	# Per-card bespoke animations take priority over the card-type default.
	# Each maps to a play_* method in CharacterFigure.play_action().
	match card_id:
		# Brad — bespoke motion
		"approach": return "approach_stance"
		"charge": return "charge"
		"harden": return "harden"
		"heavy_swing": return "heavy_swing"
		"heroic_leap": return "heroic_leap"
		"hold_the_line": return "hold_the_line"
		"hunker_down": return "hunker_down"
		"life_steal": return "life_steal"
		"life_swap": return "life_swap"
		"morphine": return "morphine"
		"parry": return "parry"
		"roar": return "roar"
		"roll": return "roll"
		"shed_weight": return "shed_weight"
		"shield_slam": return "shield_slam"
		"succumb": return "succumb"
		"taunt": return "taunt"
		"cover": return "cover"
		# Brad — heal-flavoured
		"the_lights_favor": return "heal"
		"down_but_not_out": return "down_but_not_out"
		# Brad — reuse the standard defense pose (overrides their card type)
		"armor_break", "armored_discipline": return "block"
		# Brad — reuse the standard attack pose (overrides their card type)
		"wear_down": return "attack_slash"
		# Generic card animations (character-agnostic; see CharacterFigure.play_action)
		"absorb_essence": return "absorb_essence"
		"vines": return "vines"
		"bob_and_weave": return "bob_and_weave"
		"choke": return "choke"
		"energy_ball": return "energy_ball"
		"exposed_artery": return "exposed_artery"
		"meditate": return "meditate"
		"misery_loves_company": return "misery_loves_company"
		"potion_of_continuance": return "potion_of_continuance"
		"push": return "push"
		"release_tension": return "release_tension"
		"sweeping_disarm": return "sweeping_disarm"
		"anticipation": return "anticipation"
		"item_mastery": return "item_mastery"
		"blade_barrage": return "blade_barrage"
		"adrenaline_shot": return "adrenaline_shot"
		"bloodlust": return "bloodlust"
		"elixir": return "elixir"
		"poisoned_blood": return "poisoned_blood"
		"exacerbate_wounds": return "exacerbate_wounds"
		"gargle_and_spit": return "gargle_and_spit"
		"lethal_recall": return "lethal_recall"
		"patience": return "patience"
		"raged_circulation": return "raged_circulation"
		"shadows": return "shadows"
		"shuriken": return "shuriken"
		"shuriken_pouch": return "shuriken_pouch"
		"volatile_mixture": return "volatile_mixture"
		# Consecutive Snap is a ranged force-snap, not a sword swing.
		"consecutive_snap": return "energy_ball"
		# Round 'Em Up drags enemies toward a point — the inward-drawing
		# overhead gather reads as the pull.
		"round_em_up": return "absorb_essence"
		# Thrown weapons use the overarm throw instead of a melee slash.
		"dagger_throw": return "dagger_throw"
		"thrown_stone": return "thrown_stone"
		# Reuse the standard defense pose (overrides their card type)
		"defensive_awareness", "energy_barrier": return "block"
		# Stephen — archer/ranger bespoke motion.
		# "Normal arrow attack" cards all share the core bow shot.
		"mixed_bag", "quick_shot", "quick_arrow", "specific_strike", "spirit_arrow", "last_breath":
			return "bow_shot"
		"lead_arrow": return "lead_arrow"
		"multishot": return "multishot"
		"down_town": return "down_town"
		"sky_attack": return "sky_attack"
		"sky_fall": return "sky_fall"
		"tighten_string": return "tighten_string"
		"reload": return "reload"
		"mark": return "mark"
		"collect_arrows": return "collect_arrows"
		"enchanted_quiver": return "enchanted_quiver"
		"exhausted_assault": return "exhausted_assault"
		"bottomless_quiver": return "bottomless_quiver"
		"rise": return "rise"
		"barricade": return "barricade"
		# Jeremy — gambler/chaos mage bespoke motion.
		"communal_donation": return "communal_donation"
		"snowballs_chance": return "snowballs_chance"
		"biscuit": return "biscuit"
		"cryonics": return "cryonics"
		"demonic_rage": return "demonic_rage"
		"fireball": return "fireball"
		"god_of_thunder": return "god_of_thunder"
		"harness_lightning": return "harness_lightning"
		"if_pigs_could_fly": return "if_pigs_could_fly"
		"lady_luck": return "lady_luck"
		"magic_barrier": return "magic_barrier"
		"mana_surge": return "mana_surge"
		"meister_of_faustmesser": return "disco"
		"mirror_mirror": return "mirror_mirror"
		"risk_it": return "risk_it"
		"shepherds_mark": return "shepherds_mark"
		"spark": return "spark"
		"surrounding_ice": return "surrounding_ice"
		"trick_shot": return "trick_shot"
		"vengeful_shield": return "vengeful_shield"
		"worms_armageddon": return "worms_armageddon"
		"deep_pockets": return "deep_pockets"
		"friendship": return "friendship"
		"prepare": return "prepare"
		# Dice-rolling and shrug motions are shared across several gambler cards.
		"house_money", "loaded_die": return "dice_roll"
		"hope_this_works", "oops", "worst_that_could_happen": return "shrug"
		# Jeremy — reuse standard poses (override their card type).
		"best_offense": return "block"
		"provider", "healthy_bliss": return "heal"
		# Try This! buffs an ally — no attack swing.
		"try_this": return "battle_ready"
		# Healing cards use the heal glow, not the generic ready pose;
		# reactions that heal or armor-up shouldn't play a dodge sidestep.
		"heal", "healing_potion", "gulped_potion", "fortify_alliance", "gift_from_the_phoenix":
			return "heal"
		"spider_senses": return "block"
		# Internal Combustion is a self-centered burst — the roar reads radial.
		"internal_combustion": return "roar"
	match card_type:
		CardType.ATTACK:
			return "attack_ranged" if is_ranged else "attack_slash"
		CardType.DEFENSE:
			return "block"
		CardType.REACTION:
			return "dodge"
		CardType.UTILITY:
			match card_id:
				"blink": return "blink"
				"empower": return "empower"
				"draw": return "look_around"
				_: return "battle_ready"
		_:
			return "battle_ready"


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
		"maintain": "Reserves the card's mana cost from your max mana pool while active. If mana drops to 0, all maintained cards are discarded",
		"erase": "After X tempo, this card is permanently deleted from the deck",
		"empower": "Affects the next X cards played: +3 damage for attacks, -3 block for defense",
		"on-draw": "Card triggers an effect when drawn into hand",
		"on-discard": "Card triggers an effect when discarded",
		"in-hand": "Card applies a persistent effect while it remains in your hand",
		"sticky": "Card stays in hand for X uses before being discarded",
		"high ground": "Ranged attacks from elevated positions deal +4 damage and gain +2 range",
		"cycle": "1 cycle = every 5 tempo. Mana regen, card draws, buff/debuff ticks all happen per cycle",
		"glut": "Lose the ability to play cards for X tempo. Players must press the wait button if playing solo",
		"delay": "Tempo until the effect takes place",
		"burden": "Each time played, cost increases by 10m/1t. Jail the card for 30 tempo to reset (costs 10m/1t). Can only jail from hand",
		"instant": "Card triggers automatically from hand when its condition is met. Costs 0 mana",
		"linger": "Enemy status card can exceed hand size limit. While lingering, normal draws trigger overflow",
		"on-self": "Bonus effects that apply to cards slotted in a specific item, on top of the item's base bonuses",
		# Buffs
		"thorns": "Deal X damage back to attackers, lose 1 thorn per hit",
		"focused": "Gain 10 extra mana per cycle",
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
		"drain": "Lose 10 mana per cycle, lose 1 drain per cycle",
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
		"skip": "Overflow card is sent straight to the discard pile",
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
## How many cards this card's effect draws when it resolves. The deck manager
## reserves hand slots for queued cards using this, so a tempo draw can't
## steal the slot a played Draw freed (which made its effect resolve into a
## full hand and silently do nothing).
func get_effect_draw_count() -> int:
	match card_id:
		"draw", "quick_shot", "bob_and_weave", "deep_pockets", "the_lights_favor", "reposition":
			return 1
		"potion_of_continuance", "healthy_habit":
			return 2
		"reload", "prepare":
			return 3
	return 0


func execute(target, player_stats: PlayerStats = null, deck_manager = null, damage_reduction_pct: float = 0.0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	last_damage_dealt = 0

	# Feral Evocation: arm the element remap for this play. Always assigned —
	# a non-feral play clears any remap a previous play left behind; main also
	# clears it once the play's world effects have resolved.
	Card.active_element_remap = ""
	if slotted_in_item and slotted_in_item.feral_weapon:
		var feral_col: String = str(get_meta("feral_color")) if has_meta("feral_color") else slotted_in_item.get_slot_color(self)
		Card.active_element_remap = str(Card.ELEMENT_DEBUFFS.get(feral_col, ""))

	# Cyde Livingstons Sneakers: a non-attack card breaks the consecutive-attack streak.
	if card_type != CardType.ATTACK and player_stats and player_stats.consecutive_attacks_draw_at > 0:
		player_stats.consecutive_attacks = 0

	# Knife Toed Boots: mark melee offensive resolution so crit_multiply adds the
	# flat melee-crit bonus for EVERY executor's crit, not just specific cards.
	# The victim rides along for the same reason — the Crooked Dueling Shield's
	# crit rider fires inside crit_multiply, so it reaches every executor.
	if player_stats:
		player_stats.resolving_melee_offensive = is_offensive() and not is_ranged
		player_stats.resolving_attack_target = target

	# Blind (e.g. Giant Hawk): an attack against an enemy may miss entirely.
	# Enemies expose take_damage but not get_stats (players have get_stats).
	if card_type == CardType.ATTACK and player_stats and player_stats.is_blinded \
			and target and target.has_method("take_damage") and not target.has_method("get_stats"):
		if randf() < player_stats.blind_miss_chance:
			print("[CARD] %s missed — blinded!" % card_name)
			return
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
		if base_block > 0 or card_type == CardType.DEFENSE:
			block += on_self_blk
			print("[CARD] On-Self: +%d block from %s" % [on_self_blk, slotted_in_item.item_name])
		else:
			# The card grants no block of its own (an attack in a shield slot):
			# nothing downstream reads `block`, so the rider lands as armor
			# directly. Zeroed so the cleanup pass has nothing to revert.
			if player_stats:
				player_stats.add_armor(on_self_blk)
				print("[CARD] On-Self: +%d armor from %s" % [on_self_blk, slotted_in_item.item_name])
			on_self_blk = 0
	if on_self_hl > 0:
		if heal_amount > 0:
			heal_amount += on_self_hl
			print("[CARD] On-Self: +%d heal from %s" % [on_self_hl, slotted_in_item.item_name])
		else:
			# Non-healing card (Band of Aid under an attack): heal directly —
			# no heal executor would ever read heal_amount.
			if player_stats:
				player_stats.heal(on_self_hl)
				print("[CARD] On-Self: healed %d from %s" % [on_self_hl, slotted_in_item.item_name])
			on_self_hl = 0

	# Conditional on-self riders (Shamans mask / Monocle). The random-enemy spell
	# damage (Shamans) and +range (Dragon Skull/Monocle) resolve in main.gd where
	# the world is available; here we handle the parts local to card resolution.
	var _gauntlet_bonus_applied := 0

	# Alchemist belt (passive, any healing card): heals add a % of YOUR max
	# health. Rides the on_self heal cleanup so it never sticks to the card.
	if heal_amount > 0 and player_stats and player_stats.equipment_heal_maxhp_percent > 0.0:
		var _alch_bonus: int = floori(player_stats.max_health * player_stats.equipment_heal_maxhp_percent / 100.0)
		heal_amount += _alch_bonus
		on_self_hl += _alch_bonus

	var _temp_crit_applied := 0.0
	var _temp_crit_dmg_applied := 0.0
	var _adaptive_type_prev := -999  # Blue Robe: original damage_type to restore after this play
	var _overdrive_extra := 0        # Fallen's Wrath: bonus whose half rebounds on the wielder
	var _slot_block_applied := 0     # Mauls Sabre colored slot: block granted this play, stripped after
	if slotted_in_item:
		# Studded belt: the long-dead on_self_thorns finally fires — slotted
		# plays grant thorns.
		if int(on_self.get("thorns", 0)) > 0 and buff_mgr:
			buff_mgr.apply_buff(Buff.create_thorns(int(on_self["thorns"]), 15, slotted_in_item.item_name))
		# Slotted Sash: offensive cards +damage; defense cards +armor.
		if int(on_self.get("offensive_damage", 0)) > 0 and is_offensive():
			_gauntlet_bonus_applied += int(on_self["offensive_damage"])
		if int(on_self.get("defense_armor", 0)) > 0 and card_type == CardType.DEFENSE and player_stats:
			player_stats.add_armor(int(on_self["defense_armor"]))
		# Strap of Stone: timed physical resistance on slotted play.
		if int(on_self.get("physical_resilient", 0)) > 0 and buff_mgr:
			buff_mgr.apply_buff(Buff.create_resilient(int(on_self["physical_resilient"]), 10, slotted_in_item.item_name, DamageTypes.Type.PHYSICAL))
		# Belt of Wumbology: Strengthen on slotted play.
		if int(on_self.get("strengthen_value", 0)) > 0 and buff_mgr:
			buff_mgr.apply_buff(Buff.create_strengthen(int(on_self["strengthen_value"]), maxi(1, int(on_self.get("strengthen_attacks", 1))), slotted_in_item.item_name))
		# Shadow Obi: slotted cards hit harder while invisible.
		if int(on_self.get("damage_while_invisible", 0)) > 0 and buff_mgr and buff_mgr.has_buff(Buff.BuffType.INVISIBLE):
			_gauntlet_bonus_applied += int(on_self["damage_while_invisible"])
		# Megingjord: double damage (mana doubling lives in the cost calc). The
		# extra is folded into bonus_damage and tracked for cleanup.
		var _dmg_mult: float = float(on_self.get("damage_multiplier", 1.0))
		if _dmg_mult > 1.0:
			var _mult_extra: int = floori((base_damage + bonus_damage + _gauntlet_bonus_applied) * (_dmg_mult - 1.0))
			_gauntlet_bonus_applied += _mult_extra
		# Feathered Hat: slotted cards get +10% crit damage for this play, and
		# playing them drains the flash-crit counter by 2.
		if on_self.get("crit_damage_percent", 0.0) > 0.0 and player_stats:
			_temp_crit_dmg_applied = on_self["crit_damage_percent"] / 100.0
			player_stats.temp_crit_damage_bonus += _temp_crit_dmg_applied
		if int(on_self.get("flash_counter_drain", 0)) > 0 and player_stats:
			player_stats.flash_crit_accum = max(0, player_stats.flash_crit_accum - int(on_self["flash_counter_drain"]))
		# Scholars Cap: any slotted card play refunds brain points.
		if on_self.get("brain_regen", 0) > 0 and player_stats and player_stats.has_method("gain_brain_points"):
			player_stats.gain_brain_points(on_self["brain_regen"])
			print("[CARD] On-Self: %s regained %d brain points" % [slotted_in_item.item_name, on_self["brain_regen"]])
		# Titanium Toe Tuckers: any slotted card grants armor.
		if on_self.get("armor_any", 0) > 0 and player_stats:
			player_stats.add_armor(on_self["armor_any"])
			print("[CARD] On-Self: %s granted %d armor (any card)" % [slotted_in_item.item_name, on_self["armor_any"]])
		# Rollerblades: a slotted instant (REACTION) grants extra armor.
		if card_type == CardType.REACTION and on_self.get("reaction_armor", 0) > 0 and player_stats:
			player_stats.add_armor(on_self["reaction_armor"])
			print("[CARD] On-Self: %s granted %d armor (instant)" % [slotted_in_item.item_name, on_self["reaction_armor"]])
		# Hermes Boots: any slotted card restores flash points.
		if on_self.get("flash_regen", 0) > 0 and player_stats and player_stats.has_method("gain_flash_points"):
			player_stats.gain_flash_points(on_self["flash_regen"])
			print("[CARD] On-Self: %s restored %d flash point(s)" % [slotted_in_item.item_name, on_self["flash_regen"]])
		# Caster Boots: bonus damage equal to a % of the wearer's INT. Tracked
		# (not written straight into bonus_damage) so cleanup reverts it and
		# repeat plays don't compound.
		if on_self.get("int_damage_percent", 0.0) > 0.0 and player_stats:
			var int_bonus := floori(player_stats.intelligence * on_self["int_damage_percent"] / 100.0)
			if int_bonus > 0:
				_gauntlet_bonus_applied += int_bonus
				print("[CARD] On-Self: +%d damage (%.0f%% of INT) from %s" % [int_bonus, on_self["int_damage_percent"], slotted_in_item.item_name])
		# Boots of the Balancer: armor scaling with the wearer's missing health.
		if on_self.get("armor_per_missing_health10", 0) > 0 and player_stats:
			var missing_pct := (1.0 - player_stats.get_health_percent()) * 100.0
			var bal_step: int = maxi(1, int(on_self.get("missing_health_step", 10)))
			var bal_armor: int = int(on_self["armor_per_missing_health10"]) * int(missing_pct / bal_step)
			if bal_armor > 0:
				player_stats.add_armor(bal_armor)
				print("[CARD] On-Self: +%d armor (missing-health) from %s" % [bal_armor, slotted_in_item.item_name])
		# Shamans mask: utility cards heal the player directly on play.
		if card_type == CardType.UTILITY and on_self.get("utility_heal", 0) > 0 and player_stats:
			player_stats.heal(on_self["utility_heal"])
			print("[CARD] On-Self: %s healed %d (utility)" % [slotted_in_item.item_name, on_self["utility_heal"]])
		# Monocle: offensive ranged cards gain a one-shot crit chance for this play.
		if is_offensive() and is_ranged and on_self.get("crit_ranged_percent", 0.0) > 0.0 and player_stats:
			_temp_crit_applied = on_self["crit_ranged_percent"]
			player_stats.temp_on_self_crit_bonus += _temp_crit_applied
			print("[CARD] On-Self: +%.0f%% crit from %s" % [_temp_crit_applied, slotted_in_item.item_name])
		# Elvish Cloak / Chewbaccas Bandolier: slotted RANGED offensive cards hit harder.
		if int(on_self.get("ranged_damage", 0)) > 0 and is_offensive() and is_ranged:
			_gauntlet_bonus_applied += int(on_self["ranged_damage"])
			print("[CARD] On-Self: +%d damage (ranged) from %s" % [int(on_self["ranged_damage"]), slotted_in_item.item_name])
		# Smithed Excellence: timed all-type resistance on slotted play.
		if on_self.get("resist_all_percent", 0.0) > 0.0 and buff_mgr:
			buff_mgr.apply_buff(Buff.create_resilient(int(on_self["resist_all_percent"]),
				maxi(1, int(on_self.get("resist_all_tempo", 3))), slotted_in_item.item_name, DamageTypes.ALL))
		# Tigers Sunday Red: offensive slotted cards heal a % of max health.
		if on_self.get("offensive_heal_percent", 0.0) > 0.0 and is_offensive() and player_stats:
			var tsr_heal: int = maxi(1, floori(player_stats.max_health * on_self["offensive_heal_percent"] / 100.0))
			player_stats.heal(tsr_heal)
			print("[CARD] On-Self: %s healed %d (offensive)" % [slotted_in_item.item_name, tsr_heal])
		# Blue Robe: the slotted card deals the type its target resists LEAST
		# (fire checked first, so ties break toward fire). Restored in cleanup.
		if bool(on_self.get("adaptive_damage_type", false)) and target and target.has_method("get_lowest_resistance_type"):
			_adaptive_type_prev = damage_type
			damage_type = target.get_lowest_resistance_type()
			print("[CARD] On-Self: %s adapts to %s damage" % [slotted_in_item.item_name, DamageTypes.type_name(damage_type)])
		# Rusty Dagger: flat crit chance for the slotted play.
		if on_self.get("crit_percent", 0.0) > 0.0 and player_stats:
			_temp_crit_applied += on_self["crit_percent"]
			player_stats.temp_on_self_crit_bonus += on_self["crit_percent"]
		# Bessy: hit Weakened enemies even harder.
		if on_self.get("weakened_damage_percent", 0.0) > 0.0 and is_offensive() and target \
				and "weaken_stacks" in target and target.weaken_stacks > 0:
			var wkd_bonus: int = floori((base_damage + bonus_damage + _gauntlet_bonus_applied) * on_self["weakened_damage_percent"] / 100.0)
			_gauntlet_bonus_applied += wkd_bonus
			print("[CARD] On-Self: +%d damage vs Weakened (%s)" % [wkd_bonus, slotted_in_item.item_name])
		# Hammer of Ajax: your bulk behind every blow.
		if on_self.get("max_hp_damage_percent", 0.0) > 0.0 and is_offensive() and player_stats:
			var ajax_bonus: int = floori(player_stats.max_health * on_self["max_hp_damage_percent"] / 100.0)
			_gauntlet_bonus_applied += ajax_bonus
		# Sword of Theseus: profit from the slow already on the target.
		if int(on_self.get("slow_damage_per_stack", 0)) > 0 and is_offensive() and target and "slow_stacks" in target:
			var slow_bonus: int = target.slow_stacks * int(on_self["slow_damage_per_stack"])
			if slow_bonus > 0:
				_gauntlet_bonus_applied += slow_bonus
		# Fallen's Wrath overdrive: 1.5x damage — half the bonus rebounds on you.
		var _od_mult: float = float(on_self.get("overdrive_multiplier", 1.0))
		if _od_mult > 1.0 and is_offensive():
			_overdrive_extra = floori((base_damage + bonus_damage + _gauntlet_bonus_applied) * (_od_mult - 1.0))
			_gauntlet_bonus_applied += _overdrive_extra
		# Colored slots (Mauls Sabre): the slot's own payload rides its card's
		# play. Combo effects read combo_prev_color, captured at play time.
		# The discard cost is player-chosen, so it lives in main.gd
		# (_colored_slot_discard) where the hand picker exists.
		# Sword Breaker: a slotted play locks your armor down.
		if int(on_self.get("fortify", 0)) > 0 and buff_mgr:
			buff_mgr.apply_buff(Buff.create_fortify(15, slotted_in_item.item_name))
		# Presence of Mind: extra block measured against the mana pool itself.
		# Non-block cards get it as direct armor (nothing reads their `block`).
		if on_self.get("block_max_mana_percent", 0.0) > 0.0 and player_stats:
			var pom_block: int = floori(player_stats.max_mana * on_self["block_max_mana_percent"] / 100.0)
			if pom_block > 0:
				if base_block > 0 or card_type == CardType.DEFENSE:
					_slot_block_applied += pom_block
					block += pom_block
				else:
					player_stats.add_armor(pom_block)
				print("[CARD] On-Self: +%d block (%.0f%% of max mana) from %s" % [pom_block, on_self["block_max_mana_percent"], slotted_in_item.item_name])
		var _slot_fx: Dictionary = slotted_in_item.get_slot_effect(self)
		if not _slot_fx.is_empty():
			if int(_slot_fx.get("damage", 0)) > 0 and is_offensive():
				_gauntlet_bonus_applied += int(_slot_fx["damage"])
			if int(_slot_fx.get("block", 0)) > 0:
				# Slot block payload: block-granting cards carry it as block;
				# anything else banks it as armor directly.
				if base_block > 0 or card_type == CardType.DEFENSE:
					_slot_block_applied += int(_slot_fx["block"])
					block += int(_slot_fx["block"])
				elif player_stats:
					player_stats.add_armor(int(_slot_fx["block"]))
					print("[CARD] Slot: +%d armor from %s" % [int(_slot_fx["block"]), slotted_in_item.item_name])
			# Crooked Dueling Shield: the blue/red pair, played back to back in
			# either order, pays out armor.
			if int(_slot_fx.get("combo_armor", 0)) > 0 and player_stats \
					and str(_slot_fx.get("combo_after", "")) != "" \
					and has_meta("combo_prev_color") \
					and str(get_meta("combo_prev_color")) == str(_slot_fx["combo_after"]):
				player_stats.add_armor(int(_slot_fx["combo_armor"]))
				print("[CARD] Colored combo: +%d armor from %s" % [int(_slot_fx["combo_armor"]), slotted_in_item.item_name])
		# Quiver of Wet Stones: slotted hits grind extra enemy armor (armor only).
		if int(on_self.get("armor_shred", 0)) > 0 and is_offensive() and target \
				and "current_armor" in target and target.current_armor > 0:
			target.current_armor = max(0, target.current_armor - int(on_self["armor_shred"]))
			if target.has_method("_update_armor_bar"):
				target._update_armor_bar()
			print("[CARD] On-Self: shredded %d armor (%s)" % [int(on_self["armor_shred"]), slotted_in_item.item_name])
		# Bow of Budding Blasts: this bow hits harder for every living bow summon.
		if bool(on_self.get("crit_bud_bow", false)) and player_stats and player_stats.bow_instance_count > 0:
			var bud_n: int = player_stats.bow_instance_count
			if is_offensive():
				_gauntlet_bonus_applied += 2 * bud_n
			_temp_crit_applied += 5.0 * bud_n
			player_stats.temp_on_self_crit_bonus += 5.0 * bud_n
			print("[CARD] On-Self: +%d damage / +%d%% crit from %d bow(s)" % [2 * bud_n, 5 * bud_n, bud_n])

	# Wrist Rocket: crit chance banked by discarded Improvised Ammo copies.
	if card_id == "improvised_ammo" and player_stats and player_stats.improvised_ammo_crit_bonus > 0.0:
		_temp_crit_applied += player_stats.improvised_ammo_crit_bonus
		player_stats.temp_on_self_crit_bonus += player_stats.improvised_ammo_crit_bonus

	# Feathered Hat: an armed guaranteed crit is spent by the next ranged
	# offensive card — any damaging ranged card, whatever item it's slotted in.
	if is_offensive() and is_ranged and player_stats and player_stats.flash_crit_armed:
		player_stats.flash_crit_armed = false
		_temp_crit_applied += 100.0
		player_stats.temp_on_self_crit_bonus += 100.0
		print("[CARD] Feathered Hat: guaranteed crit consumed")

	# Gauntlet flat riders on this play (tracked for cleanup)
	if player_stats:
		# Generic +X on attack cards (no current item; kept wired).
		if card_type == CardType.ATTACK and player_stats.equipment_attack_card_damage > 0:
			_gauntlet_bonus_applied += player_stats.equipment_attack_card_damage
		# Brass Knuckles: +X on melee offensive cards only.
		if is_offensive() and not is_ranged and player_stats.equipment_melee_card_damage > 0:
			_gauntlet_bonus_applied += player_stats.equipment_melee_card_damage
		# Sleeved Katar's skill: one-shot +X on the next melee offensive card.
		if is_offensive() and not is_ranged and player_stats.pending_melee_damage_bonus > 0:
			_gauntlet_bonus_applied += player_stats.pending_melee_damage_bonus
			player_stats.pending_melee_damage_bonus = 0
		# Tigers Sunday Red: bonus damage scaling with the health-percent gap
		# between you and the target — clamped at zero, never a penalty.
		if is_offensive() and player_stats.equipment_hp_diff_divisor > 0 and target \
				and "current_health" in target and "max_health" in target and target.max_health > 0:
			var tsr_php: float = player_stats.get_health_percent() * 100.0
			var tsr_ehp: float = float(target.current_health) / float(target.max_health) * 100.0
			var tsr_gap_pct: float = maxf(0.0, tsr_php - tsr_ehp) / float(player_stats.equipment_hp_diff_divisor)
			if tsr_gap_pct > 0.0:
				var tsr_gap_bonus: int = floori((base_damage + bonus_damage) * tsr_gap_pct / 100.0)
				if tsr_gap_bonus > 0:
					_gauntlet_bonus_applied += tsr_gap_bonus
					print("[CARD] Tigers Sunday Red: +%d damage (%.0f%% health-gap bonus)" % [tsr_gap_bonus, tsr_gap_pct])
		# Weapons pass: Wrath and Vitality ride every offensive card.
		if is_offensive() and player_stats.inventory and "equipped_weapons" in player_stats.inventory:
			for wpn in player_stats.inventory.equipped_weapons:
				if wpn == null:
					continue
				if wpn.wrath_weapon and wpn.wrath > 0:
					_gauntlet_bonus_applied += floori(wpn.wrath * wpn.rider_scale())
					print("[CARD] Fallen's Wrath: +%d damage (Wrath)" % floori(wpn.wrath * wpn.rider_scale()))
				if wpn.vitality_weapon and wpn.vitality_stacks > 0:
					_gauntlet_bonus_applied += floori(wpn.vitality_stacks * 2 * wpn.rider_scale())
		# Blast Stick: offensive spells hit harder the more they cost — the
		# bonus reads the SURCHARGED price, matching what the wielder pays.
		if is_offensive() and school == CardSchool.SPELL \
				and player_stats.inventory and "equipped_weapons" in player_stats.inventory:
			for bs_w in player_stats.inventory.equipped_weapons:
				if bs_w == null or bs_w.spell_damage_per_mana_percent <= 0.0:
					continue
				var bs_cost: int = get_burden_mana_cost()
				if bs_w.spell_mana_surcharge_percent > 0.0:
					bs_cost = ceili(bs_cost * (1.0 + bs_w.spell_mana_surcharge_percent / 100.0))
				var bs_bonus: int = floori(bs_cost * bs_w.spell_damage_per_mana_percent / 100.0)
				if bs_bonus > 0:
					_gauntlet_bonus_applied += bs_bonus
					print("[CARD] %s: +%d damage (%.0f%% of %d mana)" % [bs_w.item_name, bs_bonus, bs_w.spell_damage_per_mana_percent, bs_cost])
		# Purge Wrath: the armed percent lands on this attack, then clears.
		if is_offensive() and player_stats.pending_wrath_percent > 0:
			var pwp_bonus: int = floori((base_damage + bonus_damage + _gauntlet_bonus_applied) * player_stats.pending_wrath_percent / 100.0)
			_gauntlet_bonus_applied += pwp_bonus
			print("[CARD] Purge Wrath: +%d damage (+%d%%)" % [pwp_bonus, player_stats.pending_wrath_percent])
			player_stats.pending_wrath_percent = 0
		# Armor Chopper: attacks shred extra enemy armor (armor only).
		if is_offensive() and player_stats.equipment_armor_shred > 0 and target \
				and "current_armor" in target and target.current_armor > 0:
			target.current_armor = max(0, target.current_armor - player_stats.equipment_armor_shred)
			if target.has_method("_update_armor_bar"):
				target._update_armor_bar()
			print("[CARD] Armor Chopper: shredded %d armor" % player_stats.equipment_armor_shred)
		# Spartan Spear: +2 melee damage while a shield is up.
		if is_offensive() and not is_ranged and player_stats.equipment_shield_melee_damage > 0:
			_gauntlet_bonus_applied += player_stats.equipment_shield_melee_damage
	if slotted_in_item:
		# Roman Bracers: slotted melee offensive cards hit harder.
		var osb_melee := int(get_on_self_bonus().get("melee_damage", 0))
		if osb_melee > 0 and is_offensive() and not is_ranged:
			_gauntlet_bonus_applied += osb_melee
	if _gauntlet_bonus_applied > 0:
		bonus_damage += _gauntlet_bonus_applied

	# Momentum Mits: playing a slotted card draws.
	if slotted_in_item and deck_manager:
		var osb_draw := int(get_on_self_bonus().get("draw_card", 0))
		for _d in range(osb_draw):
			deck_manager.draw_card()

	# Apply ranged damage bonus from equipped items (quivers)
	var _ranged_bonus_applied = 0
	if is_ranged and card_type == CardType.ATTACK and player_stats and player_stats.ranged_damage_bonus > 0:
		_ranged_bonus_applied = player_stats.ranged_damage_bonus
		bonus_damage += _ranged_bonus_applied
		print("[CARD] Ranged bonus: +%d damage from equipment" % _ranged_bonus_applied)

	# Deadeye Form keystone: ranged attacks scale with DEX instead of STR.
	# The physical pipeline adds STR/2 downstream, so swap in the difference.
	# Tracked and reverted in cleanup — a permanent mutation would compound
	# on every play of the same card.
	var _deadeye_delta := 0
	if is_ranged and card_type == CardType.ATTACK and player_stats and player_stats.keystone_dex_ranged:
		_deadeye_delta = floori(player_stats.dexterity / 2.0) - player_stats.get_strength_damage_bonus()
		bonus_damage += _deadeye_delta

	# Wear Down: apply debuff BEFORE attack execution so the first hit stacks reduction
	if card_type == CardType.ATTACK and buff_mgr and buff_mgr.has_wear_down():
		if target and target.has_method("apply_wear_down"):
			target.apply_wear_down(15)
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
		# === Helm-granted cards (item pass 1) ===
		"neither_man_nor_beast":
			_execute_neither_man_nor_beast(target, player_stats, buff_mgr)
		"resourceful_replenish":
			# Maintain: the 5% lifesteal is applied passively in the attack path
			# while this card is maintained; nothing to do on activation.
			print("[CARD] Resourceful Replenish maintained: attacks lifesteal 5%")
		"out_of_guesses":
			_execute_out_of_guesses(deck_manager)
		"twenty_twenty":
			# Passive Maintain: the +3 ranged range is injected at card-play time in
			# main.gd (see _apply range block); nothing to do on activation.
			print("[CARD] 20/20 maintained: +3 range on ranged offensive cards")
		"its_alive":
			# Resurrect handled as a world effect in main.gd (needs grid + corpses).
			print("[CARD] ITS ALIVE!!!!! — resurrection resolved in world effects")
		"shiv":
			# Knife Toed Boots: a cheap melee jab. Same physical path as Slash.
			_execute_slash(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
		"tight_rope":
			# Boots of the Balancer instant: fired by the below-20%-health trigger.
			if player_stats:
				player_stats.add_temp_health(20, 15)
			if buff_mgr:
				buff_mgr.apply_buff(Buff.create_strengthen(15, 1, "Tight Rope"))
			print("[CARD] Tight Rope: +20 temp health, +15 damage on next attack")
		"shift", "donate_cleats", "terrain_formation", "escape_and_bewilder", "mend", "smoke_bomb":
			# Item-granted world effects — resolved in main._apply_card_world_effects.
			pass
		"serene_center":
			# Equator: health (temp included) and mana both go to half of max —
			# up or down. 100 max + 20 temp -> 60, temp cleared.
			if player_stats:
				var target_hp: int = maxi(1, floori((player_stats.max_health + player_stats.current_temp_health) / 2.0))
				player_stats.current_health = mini(target_hp, player_stats.max_health)
				player_stats.current_temp_health = 0
				player_stats.temp_health_tempo_remaining = 0
				player_stats.current_mana = floori(player_stats.max_mana / 2.0)
				player_stats.health_changed.emit(player_stats.current_health, player_stats.max_health)
				player_stats.temp_health_changed.emit(0)
				player_stats.mana_changed.emit(player_stats.current_mana, player_stats.max_mana)
				print("[CARD] Serene Center: health %d, mana %d" % [player_stats.current_health, player_stats.current_mana])
		"stone_encase":
			# Strap of Stone: 50 armor now; the self-stun resolves in main's world
			# effects (it needs the player's debuff manager).
			if player_stats:
				player_stats.add_armor(50)
				print("[CARD] Stone Encase: +50 armor")
		"m_for_mini":
			if target and target.has_method("apply_debuff"):
				target.apply_debuff("vulnerable", 2)
				target.apply_debuff("weaken", 2)
				print("[CARD] M for Mini: 2 Vulnerable + 2 Weaken")
		"hemotoxins":
			if target and target.has_method("apply_debuff"):
				var hemo_stacks := 10
				if "current_health" in target and "max_health" in target and target.max_health > 0 \
						and float(target.current_health) / float(target.max_health) < 0.5:
					hemo_stacks = 20
				target.apply_debuff("poison", hemo_stacks)
				last_damage_dealt = 0
				print("[CARD] Hemotoxins: %d Poison" % hemo_stacks)
		"protection_from_alnitak":
			# Orion's Belt: armor through the normal defense path (Burgonet et al
			# still apply), plus a Brace equal to the room left in your hand —
			# this card has already left it, so hand.size() is the live count.
			_execute_block(player_stats, is_empowered, buff_mgr)
			if buff_mgr and deck_manager:
				var brace_pct: int = maxi(0, deck_manager.get_hand_cap() - deck_manager.hand.size())
				buff_mgr.apply_buff(Buff.create_brace(brace_pct, 5, "Protection From Alnitak"))
				print("[CARD] Protection From Alnitak: Brace %d%% for 5 attacks" % brace_pct)
		"balance_of_alnilam":
			# The played card leaves the hand before execute, so "only card in
			# hand" reads as an empty hand here. Lv.3 belt: draw 10.
			if deck_manager and deck_manager.hand.is_empty():
				var alnilam_draws := 10 if (granted_by_item and granted_by_item.item_level >= 3) else 6
				for _i in range(alnilam_draws):
					deck_manager.draw_card()
				print("[CARD] Balance of Alnilam: drew %d" % alnilam_draws)
			else:
				print("[CARD] Balance of Alnilam: other cards in hand — no draw")
		"gift_from_the_gods":
			if buff_mgr:
				var gift_stacks := 4 if (granted_by_item and granted_by_item.item_level >= 3) else 3
				buff_mgr.apply_buff(Buff.new(Buff.BuffType.ENLIGHTENED, 10, -1, gift_stacks))
				if granted_by_item and granted_by_item.item_level >= 3 and player_stats:
					var gift_dm = deck_manager.debuff_manager if deck_manager and "debuff_manager" in deck_manager else null
					if gift_dm:
						var gift_list = gift_dm.debuffs.duplicate()
						gift_list.shuffle()
						for i in range(mini(3, gift_list.size())):
							gift_dm.remove_debuff(gift_list[i].debuff_type)
				print("[CARD] Gift from the Gods: %d Enlightened" % gift_stacks)
		"chain_lightning", "ice_grenade", "fire_punch", "poison_bomb", "crack_of_mintaka", "poof_and_weave":
			# World-scale belt cards — resolved in main._apply_card_world_effects.
			pass
		"healing_tonic":
			_execute_heal_with_poison_check(target, player_stats, buff_mgr)
		"clang_up":
			# Chain Mail: block through the normal defense path.
			_execute_block(player_stats, is_empowered, buff_mgr)
		"negotiate":
			# Suit and Tie: enemies carry no purse, so the steal mints the gold.
			# gain_gold also fires the chest's heal-on-gold passive.
			if player_stats:
				player_stats.gain_gold(5)
				print("[CARD] Negotiate: stole 5 gold")
		"detonova":
			# Supernova Cuirass: world-scale AoE — resolved in main._apply_card_world_effects.
			pass
		"mind_mend":
			# Trench of Tranquility: the 15-health cost is charged at play time
			# (see DeckManager.play_card's health_cost block).
			if player_stats:
				player_stats.gain_mana(60)
				print("[CARD] Mind Mend: +60 mana")
		"deep_breaths":
			_execute_heal_with_poison_check(target, player_stats, buff_mgr)
		"vined_encasing":
			# Briarhide Plate: thorns from current armor (1:1); the buff sheds
			# value equal to damage received instead of 1 per hit.
			if player_stats and buff_mgr:
				var vined_thorns: int = player_stats.current_armor
				if vined_thorns > 0:
					var vined_buff = Buff.create_thorns(vined_thorns, 20, "Vined Encasing")
					vined_buff.decay_by_damage = true
					buff_mgr.apply_buff(vined_buff)
					print("[CARD] Vined Encasing: %d thorns for 20 tempo" % vined_thorns)
				else:
					print("[CARD] Vined Encasing: no armor — no thorns")
		"adimantium_wall":
			# Adimantium Lv.3 upgrades the wall from 40 to 55 block.
			var wall_lv3_bonus: int = 15 if (granted_by_item and granted_by_item.item_level >= 3) else 0
			block += wall_lv3_bonus
			_execute_block(player_stats, is_empowered, buff_mgr)
			block -= wall_lv3_bonus
		"preemptive_answer":
			# Divine Resistance instant: fired by the below-25%-health trigger.
			if player_stats:
				var pa_dm = deck_manager.debuff_manager if deck_manager and "debuff_manager" in deck_manager else null
				if pa_dm:
					var pa_list = pa_dm.debuffs.duplicate()
					pa_list.shuffle()
					for i in range(mini(3, pa_list.size())):
						pa_dm.remove_debuff(pa_list[i].debuff_type)
				player_stats.heal(20)
				print("[CARD] Preemptive Answer: purged up to 3 debuffs, healed 20")
		"ragnarok":
			# Hide of Garmr: free the jail. Lv.3 heals 15 and grants 7 STR per card.
			if deck_manager:
				var released: int = deck_manager.release_jailed_to_hand(self)
				if released > 0:
					var rg_lv3: bool = granted_by_item != null and granted_by_item.item_level >= 3
					var rg_heal: int = (15 if rg_lv3 else 10) * released
					var rg_str: int = (7 if rg_lv3 else 5) * released
					if player_stats:
						player_stats.heal(rg_heal)
					if buff_mgr:
						buff_mgr.apply_buff(Buff.create_keen(10 * released, 10, "Ragnarok"))
						buff_mgr.apply_buff(Buff.create_might(rg_str, 10, "Ragnarok"))
					print("[CARD] Ragnarok: released %d — healed %d, +%d%% crit, +%d STR for 10 tempo" % [released, rg_heal, 10 * released, rg_str])
				else:
					print("[CARD] Ragnarok: no jailed cards to release")
		"hard_helmet":
			# Construction Hammer instant: armor here; the 2-damage zap to the
			# closest enemy resolves at the trigger site in main.
			if player_stats:
				player_stats.add_armor(8)
				print("[CARD] Hard Helmet: +8 armor")
		"slice":
			_execute_slash(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
		"death_vortex", "earth_rattle", "psionic_flow", "sanguine_the_penguin", "wrath_of_the_sea", "monk_of_the_night":
			# Weapon world effects (and the maintained Monk) — resolved in main.
			pass
		"from_the_ashes", "reapers_taking", "polymorph", "clear_mind", "grounding", "crops", "defensive_sacrifice":
			# Spell-weapon world effects — resolved at their trigger sites in main.
			pass
		"element_pollination":
			# Maintain: the elemental cross-pollination is read live off the
			# maintained pile (Card.element_pollination_active); nothing on activation.
			print("[CARD] Element Pollination maintained: Burn splashes, Shock freezes at 5, Cold ticks doubling damage")
		"feed_into_the_pain":
			# Hammer of Ajax instant: fired by taking damage below 30% health.
			if buff_mgr:
				buff_mgr.apply_buff(Buff.create_strengthen(20, 4, "Feed into the Pain"))
			if player_stats:
				player_stats.add_temp_health(25, 15)
			print("[CARD] Feed into the Pain: Strengthen 20 for 4 attacks, +25 temp HP")
		"purge_wrath":
			# Fallen's Wrath: arm the next attack with +Wrath% and reset the counter.
			if player_stats and player_stats.inventory and "equipped_weapons" in player_stats.inventory:
				for pw_w in player_stats.inventory.equipped_weapons:
					if pw_w and pw_w.wrath_weapon and pw_w.wrath > 0:
						player_stats.pending_wrath_percent += pw_w.wrath
						print("[CARD] Purge Wrath: next attack +%d%% — Wrath purged" % pw_w.wrath)
						pw_w.wrath = 0
		"stance_switch":
			# Mits of Chingiz: strip 10 armor, then 2 Vulnerable either way.
			if target and target.has_method("apply_debuff"):
				if "current_armor" in target and target.current_armor > 0:
					target.current_armor = max(0, target.current_armor - 10)
					if target.has_method("_update_armor_bar"):
						target._update_armor_bar()
					print("[CARD] Stance Switch: stripped 10 armor")
				target.apply_debuff("vulnerable", 2)
		"switch_kick":
			_execute_slash(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
			if target and target.has_method("apply_debuff"):
				target.apply_debuff("disarm_attacks", 1)
		# === Shields pass 1 ===
		"huck", "rain_of_arrows", "bouncing_shield":
			# World-scale shield cards — resolved in main._apply_card_world_effects.
			pass
		"reverberate_regrowth", "curse_of_the_living":
			# Maintained shield powers: the Bastion's echo fires off the
			# armor_broken signal and the Curse rides every heal(). Playing them
			# only puts them into maintenance.
			pass
		"mage_shield":
			# Delfins: the instant's block, through the normal defense path.
			# A forged shield raises it from 10 to 15 — read live off the item,
			# so the same card instance follows the shield's level.
			var mage_forged: int = 5 if (granted_by_item and granted_by_item.item_level >= 2) else 0
			block += mage_forged
			_execute_block(player_stats, is_empowered, buff_mgr)
			block -= mage_forged
		"mind_over_matter":
			# Presence of Mind: arm the ward. The halving and the mana payment
			# happen inside PlayerStats.take_damage on the next hit.
			if player_stats:
				player_stats.pending_mana_ward = true
				print("[CARD] Mind over Matter: the next hit will be met with mana")
		"bark_up":
			# Treebeards Branch: every point of Regen and Thorns hardens into
			# armor, and both buffs are spent doing it.
			if player_stats and buff_mgr:
				var bark_total := 0
				for bark_type in [Buff.BuffType.REGEN, Buff.BuffType.THORNS]:
					var bark_buff = buff_mgr.get_buff(bark_type)
					if bark_buff:
						bark_total += bark_buff.value
						buff_mgr.remove_buff(bark_type)
				if bark_total > 0:
					player_stats.add_armor(bark_total)
					print("[CARD] Bark Up: %d Regen+Thorns hardened into armor" % bark_total)
				else:
					print("[CARD] Bark Up: nothing green to harden")
		"song_of_a_swords_sing":
			# Sword Breaker: catch the blade, then read the enemy's suffering by
			# KIND — 3 Burn is one kind; Burn + Frost + Disarm is three.
			if target and target.has_method("apply_debuff"):
				var sword_kinds := count_debuff_kinds(target)
				target.apply_debuff("disarm_attacks", 1)
				if player_stats and sword_kinds > 0:
					player_stats.add_armor(sword_kinds * 2)
				print("[CARD] Song of a Swords Sing: Disarm 1, +%d armor from %d kind(s)" % [sword_kinds * 2, sword_kinds])
		"cinquedea":
			_execute_slash(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
			if target and target.has_method("apply_debuff"):
				target.apply_debuff("weaken", 1)
		"return_cut":
			# Counter the attacker whose hit our armor just ate, +5% crit.
			if player_stats and player_stats.last_attacker and is_instance_valid(player_stats.last_attacker):
				var rc_dmg: int = player_stats.get_effective_physical_damage(0)
				if buff_mgr and buff_mgr.roll_crit(5):
					rc_dmg = crit_multiply(rc_dmg, player_stats)
					print("[CARD] Return Cut CRITS!")
				player_stats.last_attacker.take_damage(rc_dmg, true)
				last_damage_dealt = rc_dmg
				print("[CARD] Return Cut counters for %d!" % rc_dmg)
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
			pass  # Applied to all allies in main._apply_card_world_effects
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
			pass  # Applied (with a timed revert) in main._apply_card_world_effects
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
			_execute_fortify_alliance(target, player_stats, buff_mgr, deck_manager)
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
		"shepherds_mark":
			_execute_shepherds_mark(player_stats, deck_manager)
		# === Previously unimplemented effects ===
		"heavy_swing", "specific_strike", "hydra_bite", "spark", "sprinkle":
			# Straight single-target damage (base_damage carries the value;
			# hand/tempo riders and play-time cost/gate handled elsewhere).
			_execute_slash(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
		"sprinkle_bomb":
			_compute_attack_damage(player_stats, true)   # AOE damage applied in main
		"splinter":
			# No damage — lodges a splinter that bleeds as the enemy moves.
			if target and target.has_method("apply_debuff"):
				target.apply_debuff("bleed", 1)
				print("[CARD] Splinter applies 1 Bleed")
		"savage_strike":
			_execute_savage_strike(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr, deck_manager, true)
		"savage_strike_copy":
			_execute_savage_strike(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr, deck_manager, false)
		"shield_slam":
			_execute_shield_slam(target, player_stats)
		"exposed_artery":
			_execute_exposed_artery(target)
		"tower_shield":
			_execute_tower_shield(player_stats, buff_mgr)
		"harden":
			_execute_harden(player_stats, buff_mgr)
		"hunker_down":
			_execute_hunker_down(buff_mgr)
		"energy_barrier":
			_execute_energy_barrier(player_stats)
		"the_lights_favor":
			_execute_the_lights_favor(player_stats, deck_manager)
		"healthy_habit":
			_execute_healthy_habit(player_stats, deck_manager)
		"gargle_and_spit":
			_execute_gargle_and_spit(player_stats)
		"living_armor":
			_execute_living_armor(buff_mgr)
		"multishot":
			_execute_multi_hit(target, 3, player_stats, damage_reduction_pct, buff_mgr, 10)
		"exhausted_assault":
			_execute_multi_hit(target, 3, player_stats, damage_reduction_pct, buff_mgr, 0)
		"provider":
			_execute_provider(player_stats)
		"give_in":
			_execute_give_in(player_stats, deck_manager)
		"shed_weight":
			_execute_shed_weight(deck_manager)
		"fireball":
			_compute_attack_damage(player_stats, true)   # AOE + burn applied in main
		"spirit_arrow", "balistic_arrow":
			_compute_attack_damage(player_stats, false)   # pierced line applied in main
		"improvised_ammo", "cupids_golden_arrow", "cupids_lead_arrow", "territorial_mark", "close_is_favored":
			# Single-target damage lands here; their debuff/zone/mark riders
			# resolve in main._apply_card_world_effects (or the trigger site).
			_execute_slash(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
		"internal_combustion", "god_of_thunder", "patience", "succumb", "adrenaline_shot", "vines", "release_tension", "roll", "misery_loves_company", "cryonics", "friendship", "worms_armageddon":
			pass  # Effect applied in main._apply_card_world_effects (needs world access)
		_:
			print("[CARD] Unknown card: %s" % card_id)

	# Life Steal: if an attack dealt damage and we have life steal buff, heal for damage dealt
	if card_type == CardType.ATTACK and buff_mgr and buff_mgr.has_life_steal():
		var dealt = last_damage_dealt if last_damage_dealt > 0 else damage
		if dealt > 0:
			buff_mgr.consume_life_steal(dealt)

	# Life Steal passive (Brad): all attacks heal for 1%..8% (rank-scaled) of damage dealt.
	if card_type == CardType.ATTACK and player_stats and player_stats.has_skill_tree_passive("life_steal"):
		var ls_dealt = last_damage_dealt if last_damage_dealt > 0 else damage
		if ls_dealt > 0:
			var ls_passive_pct: float = PassiveScaling.value("life_steal", "percent", player_stats.get_passive_level("life_steal"))
			player_stats.apply_life_steal(max(1, floori(ls_dealt * ls_passive_pct / 100.0)))

	# Sphere grid "Life Steal +X%" nodes, equipment lifesteal (Hannibals Mask),
	# Vitality stacks (Nine Ruins: +1% each), and a maintained Resourceful
	# Replenish: attacks heal a % of damage dealt.
	if card_type == CardType.ATTACK and player_stats:
		# get_equipment_lifesteal folds in the Coffin Lid's below-half bonus.
		var ls_pct := player_stats.sphere_bonus_life_steal + player_stats.get_equipment_lifesteal()
		# Coffin Lid: cards slotted into it drink on their own.
		ls_pct += float(get_on_self_bonus().get("lifesteal_percent", 0.0))
		if player_stats.inventory and "equipped_weapons" in player_stats.inventory:
			for ls_w in player_stats.inventory.equipped_weapons:
				if ls_w and ls_w.vitality_weapon and ls_w.vitality_stacks > 0:
					ls_pct += float(ls_w.vitality_stacks)
		if deck_manager and deck_manager.has_method("get_maintained_cards"):
			for mc in deck_manager.get_maintained_cards():
				if mc and mc.card_id == "resourceful_replenish":
					# Hannibals Mask Lv.3 maintains at 8% instead of 5%.
					ls_pct += 8.0 if (mc.granted_by_item and mc.granted_by_item.item_level >= 3) else 5.0
		if ls_pct > 0.0:
			var sls_dealt = last_damage_dealt if last_damage_dealt > 0 else damage
			if sls_dealt > 0:
				player_stats.apply_life_steal(max(1, floori(sls_dealt * ls_pct / 100.0)))

	# Reaper Scythe: damage against a target still above half health drinks 10%
	# back as life; against one below half, 10% returns as MANA instead (the
	# matching 10% mana-cost discount lives in DeckManager.play_card).
	if is_offensive() and player_stats and target \
			and "current_health" in target and "max_health" in target:
		var rs_dealt: int = last_damage_dealt if last_damage_dealt > 0 else 0
		if rs_dealt > 0 and player_stats.inventory and "equipped_weapons" in player_stats.inventory:
			for rs_w in player_stats.inventory.equipped_weapons:
				if rs_w == null or not rs_w.reaper_weapon:
					continue
				# The hit has already landed — judge the target by its PRE-hit pool.
				var rs_hp_before: int = mini(int(target.current_health) + rs_dealt, int(target.max_health))
				if rs_hp_before * 2 > int(target.max_health):
					player_stats.apply_life_steal(max(1, floori(rs_dealt * 0.10)))
					print("[CARD] Reaper Scythe: drank %d life" % max(1, floori(rs_dealt * 0.10)))
				else:
					player_stats.gain_mana(max(1, floori(rs_dealt * 0.10)))
					print("[CARD] Reaper Scythe: reclaimed %d mana" % max(1, floori(rs_dealt * 0.10)))
				break

	# Monk of the Night (Umbral Eclipse, maintained): attacks bank part of
	# their damage as block. Lv.3 converts 15% instead of 10%.
	if is_offensive() and player_stats and deck_manager and deck_manager.has_method("get_maintained_cards"):
		for monk in deck_manager.get_maintained_cards():
			if monk and monk.card_id == "monk_of_the_night":
				var monk_dealt = last_damage_dealt if last_damage_dealt > 0 else damage
				var monk_pct := 0.15 if (monk.granted_by_item and monk.granted_by_item.item_level >= 3) else 0.10
				var monk_block: int = floori(monk_dealt * monk_pct)
				if monk_block > 0:
					player_stats.add_armor(monk_block)
					print("[CARD] Monk of the Night: +%d block from the strike" % monk_block)
				break

	# Fallen's Wrath overdrive: half the bonus rebounds on the wielder.
	if _overdrive_extra > 0 and player_stats:
		player_stats.take_direct_damage(ceili(_overdrive_extra / 2.0))
		print("[CARD] Overdrive: took %d rebound damage" % ceili(_overdrive_extra / 2.0))

	# Sabre Tooth: striking the same target twice in a row ticks the
	# attack-speed counter an extra time and rakes 5 more Bleed.
	if is_offensive() and target and player_stats and player_stats.inventory \
			and "equipped_weapons" in player_stats.inventory:
		for st_w in player_stats.inventory.equipped_weapons:
			if st_w and st_w.same_target_bleed > 0:
				if player_stats.last_attack_target == target:
					# Only the attack-speed counter ticks — not the "real
					# attack" streaks (Wizard Hat, sneakers, free-hand echo).
					player_stats.register_attack(false)
					if target.has_method("apply_debuff"):
						target.apply_debuff("bleed", st_w.same_target_bleed)
					print("[CARD] Sabre Tooth: extra attack tick + %d Bleed" % st_w.same_target_bleed)
				break
		player_stats.last_attack_target = target

	# Clear armor break flag on target after attack resolves
	if armor_break_consumed and target and target.has_method("set_armor_break_incoming"):
		target.set_armor_break_incoming(false)

	# Girdle of Aphrodite: offensive slotted cards Taunt their enemy target;
	# utility/defense slotted cards heal their (ally/self) target.
	if slotted_in_item and target:
		var osb_g = get_on_self_bonus()
		if is_offensive() and int(osb_g.get("taunt_cycles", 0)) > 0 and target.has_method("apply_taunt") and buff_mgr:
			target.apply_taunt(buff_mgr.owner_node, int(osb_g["taunt_cycles"]) * 5)
			print("[CARD] On-Self: %s taunts the target" % slotted_in_item.item_name)
		if not is_offensive() and int(osb_g.get("support_heal", 0)) > 0:
			var heal_who = target if (target.has_method("get_stats") and target.get_stats()) else null
			if heal_who:
				heal_who.get_stats().heal(int(osb_g["support_heal"]))
			elif player_stats:
				player_stats.heal(int(osb_g["support_heal"]))
			print("[CARD] On-Self: %s heals %d" % [slotted_in_item.item_name, int(osb_g["support_heal"])])
		# Corset of Cure: cleanse stacks of a random debuff on the card's target
		# (players/allies only — enemies keep their ailments).
		if int(osb_g.get("cleanse_stacks", 0)) > 0 and target.has_method("get_debuff_manager"):
			var cdm = target.get_debuff_manager()
			if cdm and cdm.debuffs.size() > 0:
				var pick = cdm.debuffs[randi() % cdm.debuffs.size()]
				pick.stacks -= int(osb_g["cleanse_stacks"])
				if pick.stacks <= 0:
					cdm.remove_debuff(pick.debuff_type)
				print("[CARD] On-Self: cleansed %d stacks of %s" % [int(osb_g["cleanse_stacks"]), pick.debuff_name])

	# Burgonet: a DEFENSE card that grants no armor of its own grants the boots'
	# flat amount instead. (Armor-granting defense cards get their +2 inside
	# _execute_block, on top of what they already provide.)
	if card_type == CardType.DEFENSE and block <= 0 and player_stats \
			and player_stats.equipment_armorless_defense_block > 0:
		player_stats.add_armor(player_stats.equipment_armorless_defense_block)
		print("[CARD] %s grants %d armor (armorless defense card)" % [card_name, player_stats.equipment_armorless_defense_block])

	# Apply on-self debuffs (burn/cold/bleed from quivers and helms) to target
	# after any offensive card that dealt damage
	if is_offensive() and target and last_damage_dealt > 0:
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
					var cold = Debuff.create(Debuff.DebuffType.COLD, on_self_cold, 30)
					cold.source_name = source_name
					target_debuff_mgr.apply_debuff(cold)
			elif target.has_method("apply_debuff"):
				target.apply_debuff("cold", on_self_cold)
			print("[CARD] On-Self: Applied %d Cold to target from %s" % [on_self_cold, source_name])
		# Assasian Belt: Vulnerable on the struck target.
		var on_self_vuln = int(on_self.get("apply_vulnerable", 0))
		if on_self_vuln > 0 and target.has_method("apply_debuff"):
			target.apply_debuff("vulnerable", on_self_vuln)
		var on_self_bleed = on_self.get("apply_bleed", 0)
		if on_self_bleed > 0:
			if target.has_method("get_debuff_manager"):
				var target_debuff_mgr = target.get_debuff_manager()
				if target_debuff_mgr:
					var bleed = Debuff.create(Debuff.DebuffType.BLEED, on_self_bleed, 15)
					bleed.source_name = source_name
					target_debuff_mgr.apply_debuff(bleed)
			elif target.has_method("apply_debuff"):
				target.apply_debuff("bleed", on_self_bleed)
			print("[CARD] On-Self: Applied %d Bleed to target from %s" % [on_self_bleed, source_name])
		# Sword of Theseus: slotted attacks bog the target down.
		var on_self_slow = int(on_self.get("apply_slow", 0))
		if on_self_slow > 0 and is_offensive() and target.has_method("apply_debuff"):
			target.apply_debuff("slow", on_self_slow)
			print("[CARD] On-Self: Applied %d Slow to target from %s" % [on_self_slow, source_name])
		# Shock Quiver: slotted hits jolt the target.
		var on_self_shock = int(on_self.get("apply_shock", 0))
		if on_self_shock > 0 and target.has_method("apply_debuff"):
			target.apply_debuff("shock", on_self_shock)
			print("[CARD] On-Self: Applied %d Shock to target from %s" % [on_self_shock, source_name])
		# Weaken from the item the card is slotted in.
		var on_self_weaken = int(on_self.get("apply_weaken", 0))
		if on_self_weaken > 0 and target.has_method("apply_debuff"):
			target.apply_debuff("weaken", on_self_weaken)
			print("[CARD] On-Self: Applied %d Weaken to target from %s" % [on_self_weaken, source_name])
		# Spell weapons: global on-hit debuffs — unlike the on_self family these
		# ride EVERY damaging offensive card, slotted anywhere or nowhere
		# (Fire/Frost Book, Ice Orb, Car Battery, Circe's Wand, Reaper Scythe).
		if player_stats and player_stats.inventory and "equipped_weapons" in player_stats.inventory \
				and target.has_method("apply_debuff"):
			for sw in player_stats.inventory.equipped_weapons:
				if sw == null:
					continue
				for sw_pair in [["burn", sw.attack_apply_burn], ["cold", sw.attack_apply_cold],
						["shock", sw.attack_apply_shock], ["silenced", sw.attack_apply_silence],
						["vulnerable", sw.attack_apply_vulnerable]]:
					var sw_amt: int = int(sw_pair[1])
					if sw_amt > 0:
						if sw.rider_fizzles():
							print("[CARD] %s: off-hand %s fizzles" % [sw.item_name, str(sw_pair[0])])
							continue
						target.apply_debuff(str(sw_pair[0]), sw_amt)
						print("[CARD] %s: applied %d %s on hit" % [sw.item_name, sw_amt, str(sw_pair[0])])
		# Colored slots (Mauls Sabre): the slot's debuff payload, plus the
		# combo bonus when this color was primed by the other one.
		var slot_fx_late: Dictionary = slotted_in_item.get_slot_effect(self) if slotted_in_item else {}
		if not slot_fx_late.is_empty() and target.has_method("apply_debuff"):
			if int(slot_fx_late.get("weaken", 0)) > 0:
				target.apply_debuff("weaken", int(slot_fx_late["weaken"]))
				print("[CARD] %s slot: applied %d Weaken" % [slotted_in_item.get_slot_color(self), int(slot_fx_late["weaken"])])
			if int(slot_fx_late.get("vulnerable", 0)) > 0:
				target.apply_debuff("vulnerable", int(slot_fx_late["vulnerable"]))
			if int(slot_fx_late.get("combo_vulnerable", 0)) > 0 \
					and str(slot_fx_late.get("combo_after", "")) != "" \
					and has_meta("combo_prev_color") \
					and str(get_meta("combo_prev_color")) == str(slot_fx_late["combo_after"]):
				target.apply_debuff("vulnerable", int(slot_fx_late["combo_vulnerable"]))
				print("[CARD] Combo! %s after %s: +%d Vulnerable" % [slotted_in_item.get_slot_color(self), str(slot_fx_late["combo_after"]), int(slot_fx_late["combo_vulnerable"])])

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
	if _gauntlet_bonus_applied > 0:
		bonus_damage -= _gauntlet_bonus_applied
	if _deadeye_delta != 0:
		bonus_damage -= _deadeye_delta  # Deadeye Form: per-play swap, never sticks
	if _slot_block_applied > 0:
		block -= _slot_block_applied  # Mauls Sabre colored slot: never sticks to the card

	# Gravity Gauntlets / Spidey Web Shooters: a slotted offensive card holds or
	# disarms its target.
	if slotted_in_item and is_offensive() and target and target.has_method("apply_debuff"):
		var osb_late = get_on_self_bonus()
		if int(osb_late.get("root_offensive", 0)) > 0:
			target.apply_debuff("root", int(osb_late["root_offensive"]) * 5)
		if int(osb_late.get("disarm_offensive", 0)) > 0:
			target.apply_debuff("disarm_attacks", int(osb_late["disarm_offensive"]))

	# Clear the one-shot on-self crit so it never leaks to the next card.
	if _temp_crit_applied > 0.0 and player_stats:
		player_stats.temp_on_self_crit_bonus = max(0.0, player_stats.temp_on_self_crit_bonus - _temp_crit_applied)
	if _temp_crit_dmg_applied > 0.0 and player_stats:
		player_stats.temp_crit_damage_bonus = max(0.0, player_stats.temp_crit_damage_bonus - _temp_crit_dmg_applied)
	if _adaptive_type_prev != -999:
		damage_type = _adaptive_type_prev  # Blue Robe: the type swap never sticks to the card

	# Wizard Hat: a spell card consumes the armed spell-power bonus on play.
	if school == CardSchool.SPELL and player_stats and player_stats.pending_spell_power_bonus > 0:
		player_stats.pending_spell_power_bonus = 0

	# Clear the resolution markers so they can't leak past this play.
	if player_stats:
		player_stats.resolving_melee_offensive = false
		player_stats.resolving_attack_target = null

static func _duelist_shield_equipped(player_stats) -> bool:
	if player_stats == null or player_stats.inventory == null:
		return false
	if not ("equipped_weapons" in player_stats.inventory):
		return false
	for w in player_stats.inventory.equipped_weapons:
		if w and w.duelist_shield:
			return true
	return false

static func _duelist_crit_rider(target, player_stats) -> void:
	## Crooked Dueling Shield, on EVERY crit the wielder lands: an already
	## Weakened target eats 2 Vulnerable first — they go in before the damage,
	## so the crit itself is amplified by them — and then the crit leaves its
	## own Weaken behind. Order matters: the Vulnerable check reads the Weaken
	## the target already had, never the one this crit is about to apply.
	if target == null or not is_instance_valid(target) or not target.has_method("apply_debuff"):
		return
	if not _duelist_shield_equipped(player_stats):
		return
	if "weaken_stacks" in target and target.weaken_stacks > 0:
		target.apply_debuff("vulnerable", 2)
		print("[CARD] Crooked Dueling Shield: 2 Vulnerable land ahead of the crit")
	target.apply_debuff("weaken", 1)
	print("[CARD] Crooked Dueling Shield: the crit leaves 1 Weaken")

static func crit_multiply(damage: int, player_stats: PlayerStats, target = null) -> int:
	## The one crit-damage formula: 110% base + 3% per point of Dexterity.
	## Falls back to the 110% base when no stats are available.
	## Knife Toed Boots: while a melee offensive card is resolving, every crit
	## adds a flat unscaled bonus on top of the multiplied damage.
	## Every crit in the game funnels through here, so crit riders that need
	## the victim live here too — `target` falls back to the card resolution's
	## own victim, which Card.execute parks on the stats for exactly this.
	if player_stats:
		var victim = target if target != null else player_stats.resolving_attack_target
		_duelist_crit_rider(victim, player_stats)
	if player_stats and player_stats.resolving_melee_offensive \
			and player_stats.equipment_melee_crit_bonus > 0:
		return floori(damage * player_stats.get_crit_damage_multiplier()) + player_stats.equipment_melee_crit_bonus
	var mult := player_stats.get_crit_damage_multiplier() if player_stats else PlayerStats.BASE_CRIT_DAMAGE
	return floori(damage * mult)

func _execute_gain_mana(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.gain_mana(20)
		print("[CARD] Gained 20 mana!")
		
func _execute_slash(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction_pct: float = 0.0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage

	# Generic single-target path scales by the card's school: spells (Spark)
	# ride the INT pipeline, everything else stays STR physical.
	if player_stats:
		if school == CardSchool.SPELL:
			total_damage = player_stats.get_effective_spell_damage(total_damage)
		else:
			total_damage = player_stats.get_effective_physical_damage(total_damage)

	if is_empowered and player_stats:
		total_damage += player_stats.empower_damage_bonus

	# Strengthen bonus
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()

		# Crit check with Enlightened
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats, target)
			print("[CARD] CRITICAL HIT! Damage doubled!")

	# Cursed: reduce damage dealt by percentage
	if damage_reduction_pct > 0.0:
		total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))
	
	print("[CARD] %s deals %d damage!" % [card_name, total_damage])
	last_damage_dealt = total_damage

	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)

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
		target.take_damage(total_damage, true, damage_type)
	
	if self_damage_percent > 0.0 and player_stats:
		var self_dmg = floori(total_damage * self_damage_percent)
		if self_dmg > 0:
			player_stats.take_damage(self_dmg)

## Neither Man nor Beast (Mane of Narashimha): 5 base damage through the normal
## additive pipeline (STR, strengthen, on-self, crit) that bypasses armor and
## resistances; the target cannot heal back THIS hit's damage for 10 tempo.
func _execute_neither_man_nor_beast(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
			print("[CARD] CRITICAL HIT!")
	last_damage_dealt = total_damage
	if target and target.has_method("take_damage"):
		# ignore_armor = true; enemies have no per-type resistances, so bypassing
		# armor fulfills "ignoring all resistances and armor".
		target.take_damage(total_damage, true, damage_type, true)
		if target.has_method("apply_debuff"):
			target.apply_debuff("narashimha", 10)  # 10 tempo
		print("[CARD] Neither Man nor Beast: %d unresistable damage + Narashimha" % total_damage)

## Out of Guesses (The Headbandz): discard the whole hand, then draw that many.
func _execute_out_of_guesses(deck_manager) -> void:
	if not deck_manager:
		return
	var to_discard: Array = []
	for c in deck_manager.hand:
		if c != self:  # the card being played is discarded by the play flow itself
			to_discard.append(c)
	var n = to_discard.size()
	for c in to_discard:
		deck_manager.discard_card_from_hand(c)
	for _i in range(n):
		deck_manager.draw_card()
	print("[CARD] Out of Guesses: discarded %d, drew %d" % [n, n])

func _execute_block(player_stats: PlayerStats, is_empowered: bool = false, buff_mgr: BuffManager = null) -> void:
	var armor_amount = block

	# Empower on defense: "-3 block" per the card text — the aggression
	# trade-off weakens defensive plays while empowered.
	if is_empowered and player_stats:
		armor_amount = maxi(0, armor_amount - player_stats.empower_block_reduction)
		print("[CARD] Empowered defense: -%d block" % player_stats.empower_block_reduction)

	# Equipment "+X block to armor-granting defense cards" (Burgonet, Thick
	# Steel) — the total can be NEGATIVE (Slotted Rope Half Sleeve's -3), so
	# apply any non-zero sum, floored at 0 block.
	if player_stats and armor_amount > 0 and player_stats.equipment_defense_card_block != 0:
		armor_amount = maxi(0, armor_amount + player_stats.equipment_defense_card_block)

	if player_stats:
		player_stats.add_armor(armor_amount)
	
	print("[CARD] %s grants %d armor!" % [card_name, armor_amount])

func _execute_discard(deck_manager) -> void:
	if deck_manager and deck_manager.hand.size() > 0:
		var random_index = randi() % deck_manager.hand.size()
		var discarded = deck_manager.hand[random_index]
		deck_manager.hand.remove_at(random_index)
		deck_manager.discard_pile.append(discarded)
		# A true discard, not a play — announce it so discard-reactive passives
		# (Ladder Work, Abjurers Cane) see it like any other.
		deck_manager.discards_this_cycle += 1
		deck_manager.card_discarded.emit(discarded)
		deck_manager.non_play_discard.emit(discarded)
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
	# General healing logic: if Poison Blood is active and target is an enemy,
	# deal damage instead — burning one Poisoned Blood charge per converted heal.
	if buff_mgr and buff_mgr.has_poisoned_blood() and target and target.has_method("take_damage") and not target.has_method("get_stats"):
		var dmg = heal_amount
		if player_stats:
			dmg = player_stats.get_effective_heal_amount(heal_amount)
		target.take_damage(dmg, true)
		buff_mgr.consume_poisoned_blood()
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
		return mana_cost + burden_plays * 10
	return mana_cost

## "Offensive card" as the item specs use the term: anything that deals damage,
## not just CardType.ATTACK — a damaging utility/spell counts too.
func is_offensive() -> bool:
	return card_type == CardType.ATTACK or damage > 0 or base_damage > 0

# Boots of Speed: tempo shaved off while this card sits in hand. It lasts until
# the card is played or discarded (cleared when the card leaves the hand and
# again defensively on redraw), never a permanent change to the card.
var temp_hand_tempo_reduction: int = 0

func get_burden_tempo_cost() -> int:
	var cost := tempo_cost
	if has_burden:
		cost += burden_plays
	# Boot Holsters: slotted attack cards cost less tempo.
	if card_type == CardType.ATTACK and slotted_in_item:
		cost -= slotted_in_item.get_on_self_bonus().get("attack_tempo_reduction", 0)
	# Chewbaccas Bandolier: slotted RANGED offensive cards cost less tempo.
	if is_offensive() and is_ranged and slotted_in_item:
		cost -= int(slotted_in_item.get_on_self_bonus().get("ranged_tempo_reduction", 0))
	# Side Card Sabre: slotted cards cost less while the sabre is paired.
	if slotted_in_item:
		cost -= int(slotted_in_item.get_on_self_bonus().get("pair_tempo_reduction", 0))
	# Tightened Cross Bow (+1) / Stringless Sender (-1): signed tempo delta.
	if slotted_in_item:
		cost += int(slotted_in_item.get_on_self_bonus().get("tempo_penalty", 0))
	# Colored slots (Mauls Sabre): a primed combo makes this play faster —
	# red immediately after blue. Reads the item's live last_color_played, so
	# the number on the card face updates the moment the combo is primed.
	if slotted_in_item and slotted_in_item.slot_colors.size() > 0:
		var slot_fx: Dictionary = slotted_in_item.get_slot_effect(self)
		if int(slot_fx.get("combo_tempo", 0)) > 0 \
				and str(slot_fx.get("combo_after", "")) != "" \
				and slotted_in_item.last_color_played == str(slot_fx["combo_after"]):
			cost -= int(slot_fx["combo_tempo"])
	# Potion Belt: slotted utility cards refund tempo.
	if card_type == CardType.UTILITY and slotted_in_item:
		cost -= int(slotted_in_item.get_on_self_bonus().get("utility_tempo_refund", 0))
	# Boots of Speed: in-hand reduction, until played or discarded.
	cost -= temp_hand_tempo_reduction
	# The Headbandz Lv.3: Out of Guesses quickens to 1 tempo.
	if card_id == "out_of_guesses" and granted_by_item and granted_by_item.item_level >= 3:
		cost = 1
	return max(0, cost)

func apply_burden() -> void:
	if has_burden:
		burden_plays += 1
		print("[CARD] %s burden increased! Plays: %d (+%dm/+%dt)" % [card_name, burden_plays, burden_plays * 10, burden_plays])

func jail_burden() -> void:
	if has_burden:
		burden_plays = 0
		jail_time_remaining = burden_jail_duration
		print("[CARD] %s burden reset! Jailed for %d tempo" % [card_name, burden_jail_duration])

# ============================================
# CARD UPGRADE SYSTEM (Paper Feather)
# ============================================

# Factory methods
static func create_basic_attack(damage_amount: int) -> Card:
	## Creates a temporary card used for tracking basic attacks in the ticked tempo system.
	var card = Card.new()
	card.card_id = "basic_attack"
	card.card_name = "Basic Attack"
	card.description = "Basic melee attack"
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 5
	card.resolve_tick = 1
	card.damage = damage_amount
	card.base_damage = damage_amount
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	return card

static func create_slash() -> Card:
	var card = Card.new()
	card.card_id = "slash"
	card.card_name = "Slash"
	card.description = "10 damage"
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 10
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
	card.mana_cost = 10
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
	card.mana_cost = 10
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
	card.school = CardSchool.SPELL
	card.card_name = "Blink"
	card.description = "Teleport to cursor"
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 20
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
	card.mana_cost = 10
	card.tempo_cost = 2  # Takes effort to heal
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.target_types = ["self", "ally"]
	card.heal_amount = 4
	return card

static func create_gain_mana() -> Card:
	var card = Card.new()
	card.card_id = "gain_mana"
	card.card_name = "Energy"
	card.description = "Gain 20 mana"
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
	card.mana_cost = 10
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
	card.mana_cost = 10
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
	# Swap health and mana pools at the standing 10-mana-per-1-HP exchange
	# rate (mana runs on a x10 scale; HP does not). Never drop HP to 0.
	var new_health = max(1, min(floori(old_mana / 10.0), player_stats.max_health))
	var new_mana = min(old_health * 10, player_stats.max_mana)
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
			total_damage = crit_multiply(total_damage, player_stats)
	last_damage_dealt = total_damage
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
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
			total_damage = crit_multiply(total_damage, player_stats)
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
			total_damage = crit_multiply(total_damage, player_stats)
	last_damage_dealt = total_damage
	print("[CARD] Heroic Leap! %d paces, %d damage on landing" % [leap_distance, total_damage])

func _execute_morphine(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if not player_stats:
		return
	# Real temp HP via the shared pool: absorbed by damage like any temp HP and
	# expires on its own 15-tempo timer. The buff carries the 2-damage penalty.
	player_stats.add_temp_health(4, 15)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_morphine(4, 15, "Morphine"))
	print("[CARD] Morphine! Gained 4 temp HP. Will take 2 damage in 15 tempo")

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
		target.take_damage(total_damage, true, damage_type)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_brace(30, 1, "Parry"))
	print("[CARD] Parry! Gained 5 armor, dealt %d damage. Next damage reduced" % total_damage)

func _execute_approach(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Slow self for 10 tempo (2 cycles), gain 5 armor per movement taken
	if buff_mgr and buff_mgr.debuff_manager:
		buff_mgr.debuff_manager.apply_debuff(Debuff.create_slowed(2, "Approach"))
	if buff_mgr:
		buff_mgr.approach_armor_per_move = 5
		buff_mgr.approach_tempo_remaining = 10
	print("[CARD] Approach! Slowed 2, gain 5 armor per movement for 10 tempo")

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
			total_damage = crit_multiply(total_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
		last_damage_dealt = total_damage
	# 80% bounce chance, -20% per bounce; each bounce repeats the attack's damage.
	# The FIRST bounce honors the pre-rolled outcome shown on the card preview;
	# later bounces roll live at the decayed odds.
	var bounce_chance = 80.0
	var bounces = 0
	while true:
		var bounce_hits: bool
		if bounces == 0 and has_been_rolled():
			bounce_hits = rng_binary_succeeded()
		else:
			bounce_hits = randf() * 100.0 < bounce_chance
		if not bounce_hits:
			break
		bounces += 1
		if target and target.has_method("take_damage"):
			target.take_damage(total_damage, true, damage_type)
			last_damage_dealt += total_damage
		bounce_chance -= 20.0
		if bounce_chance <= 0:
			break
	print("[CARD] Trick Shot! Dealt %d damage, bounced %d times (%d each)" % [total_damage, bounces, total_damage])

func _execute_surrounding_ice(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_spell_damage(total_damage)
	# Store damage for main.gd AOE handling (independent roll per enemy)
	last_damage_dealt = total_damage
	print("[CARD] Surrounding Ice prepared! %d damage per hit (rolls per enemy in main)" % total_damage)

func _execute_risk_it(player_stats: PlayerStats, deck_manager = null) -> void:
	# 30% chance to receive the biscuit — uses the pre-rolled outcome so the
	# result matches the card preview (falls back to a live roll if unrolled).
	var success: bool = rng_binary_succeeded() if has_been_rolled() else randf() < 0.3
	if success:
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
		player_stats.next_odds_boost += 10.0
	print("[CARD] Loaded Die! Next card's odds increased by 10%")

func _execute_worst_that_could_happen(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = 5
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(5)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
	# Always deal base 5 damage
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
	# Use pre-rolled RNG: index 0 = +15 damage, index 1 = stun. Paths that
	# skipped the pre-roll flip a live coin instead of always landing on stun.
	var wtch_outcome = rng_selected_index
	if wtch_outcome < 0:
		wtch_outcome = 0 if randf() < 0.5 else 1
	if wtch_outcome == 0:
		if target and target.has_method("take_damage"):
			target.take_damage(15, true)
		total_damage += 15  # the rider counts toward the logged/lifesteal total
		print("[CARD] What's the worst? +15 bonus damage! Total: %d" % total_damage)
	else:
		if target and target.has_method("apply_debuff"):
			target.apply_debuff("stun", 5)
		print("[CARD] What's the worst? Target stunned! Dealt %d" % total_damage)
	last_damage_dealt = total_damage

func _execute_oops(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var hit_damage = base_damage + bonus_damage
	if player_stats:
		hit_damage = player_stats.get_effective_physical_damage(hit_damage)
	# Strengthen and crit ride the FIRST hit, matching the face preview.
	if buff_mgr:
		hit_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			hit_damage = crit_multiply(hit_damage, player_stats, target)
	# Use the pre-rolled outcome (30% = 5 hits, 40% = 3 hits, 30% = 2 hits) so
	# the result matches what the card preview showed.
	var hits = 2
	match rng_selected_index:
		0: hits = 5
		1: hits = 3
		_: hits = 2
	for i in range(hits):
		if target and target.has_method("take_damage"):
			target.take_damage(hit_damage, true)
	last_damage_dealt = hits * hit_damage
	print("[CARD] Oops! Hit %d times for %d each (total: %d)" % [hits, hit_damage, hits * hit_damage])

func _execute_house_money(player_stats: PlayerStats) -> void:
	if player_stats:
		player_stats.next_odds_boost = 100.0
	print("[CARD] House Money! Next odds will automatically trigger")

func _execute_hope_this_works(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# 50% to heal ally and provide strength for 3 attacks — uses the pre-rolled
	# outcome so the result matches the card preview.
	var success: bool = rng_binary_succeeded() if has_been_rolled() else randf() < 0.5
	if success:
		if player_stats:
			var heal_amt = max(3, player_stats.intelligence)
			player_stats.heal(heal_amt)
		if buff_mgr:
			buff_mgr.apply_buff(Buff.create_strengthen(2, 3, "Hope This Works"))
		print("[CARD] Hope This Works... it worked! Healed and +STR for 3 attacks")
	else:
		print("[CARD] Hope This Works... it didn't work")

func _execute_lady_luck(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Bless an ally: Enlightened for 5 attacks (flat +10% crit while it holds).
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_enlightened(10, 5, "Lady Luck"))
	print("[CARD] Lady Luck! Enlightened: +10% crit chance for 5 attacks")

func _execute_if_pigs_could_fly(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = 15
	if player_stats:
		total_damage = player_stats.get_effective_spell_damage(15)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats, target)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
	last_damage_dealt = total_damage
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
	print("[CARD] Raged Circulation! Healing +30% for 15 tempo")

func buff_mgr_exists(target) -> bool:
	return target and target.has_method("get_buff_manager") and target.get_buff_manager() != null

func _execute_poisoned_blood(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Stack-oriented: the next 3 heal cards deal damage instead of healing.
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_poisoned_blood(3, "Poisoned Blood"))
	print("[CARD] Poisoned Blood! Your next 3 heal cards deal damage instead")

func _execute_elixir(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Stack-oriented: the next 5 poison ticks heal instead of hurting.
	if player_stats:
		player_stats.elixir_stacks += 5
	# Surface it as a visible active effect in the buff bar.
	if buff_mgr:
		buff_mgr.sync_flag_buffs()
	print("[CARD] Elixir! Your next 5 poison ticks heal you instead")

func _execute_shadows(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_invisible(10, "Shadows"))
	print("[CARD] Shadows! Invisible for 10 tempo")

func _execute_preparation(player_stats: PlayerStats, deck_manager = null) -> void:
	if deck_manager:
		deck_manager.prep_utility_discount = 20
		deck_manager.prep_utility_charges = 2
	print("[CARD] Preparation! Next 2 utility cards cost 20 less")

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
			total_damage = crit_multiply(total_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
	print("[CARD] Exacerbate Wounds! %d cards discarded this cycle = %d damage" % [discard_count, total_damage])

func _execute_reposition(deck_manager) -> void:
	# Discard the chosen card (or a random one if none was picked) and draw.
	if not deck_manager or deck_manager.hand.is_empty():
		return
	var discard_idx := -1
	if picked_card and picked_card in deck_manager.hand:
		discard_idx = deck_manager.hand.find(picked_card)
	else:
		discard_idx = randi() % deck_manager.hand.size()
	var discarded = deck_manager.hand[discard_idx]
	deck_manager.hand.remove_at(discard_idx)
	deck_manager.discard_pile.append(discarded)
	deck_manager.discards_this_cycle += 1
	deck_manager.draw_card()
	deck_manager.hand_updated.emit()
	picked_card = null
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
	# "Deal 3 damage to a RANDOM enemy" — the random pick happens in main.gd's
	# world effects (the card layer has no enemy list). If a damageable target
	# somehow reaches us directly (e.g. quiver fire), hit that instead.
	last_damage_dealt = 3
	if target and target.has_method("take_damage") and not target.has_method("get_stats"):
		target.take_damage(3, true)
		print("[CARD] Shuriken! Dealt 3 damage")
	else:
		print("[CARD] Shuriken thrown — random target resolved in main")

func _execute_premeditated(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction_pct: float = 0.0, self_damage_percent: float = 0.0, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage

	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)

	if is_empowered and player_stats:
		total_damage += player_stats.empower_damage_bonus

	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
			print("[CARD] CRITICAL HIT! Damage doubled!")

	if damage_reduction_pct > 0.0:
		total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))

	print("[CARD] Premeditated deals %d damage!" % total_damage)
	last_damage_dealt = total_damage

	if target and target.has_method("take_damage"):
		var just_exposed = target.take_damage(total_damage, true)
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
		# Enemy timed debuffs tick on raw tempo — 25 = the card's 25 tempo.
		target.apply_debuff("marked", 25)
	print("[CARD] Mark! Target receives extra damage for 25 tempo")

func _execute_rise(target, _player_stats: PlayerStats) -> void:
	print("[CARD] Rise! Earth structure created on the map")

func _execute_quick_shot(target, player_stats: PlayerStats, deck_manager = null, buff_mgr: BuffManager = null) -> void:
	# 2 base damage + HALF of every modifier on top (stats, bonuses, buffs).
	var full = base_damage + bonus_damage
	if player_stats:
		full = player_stats.get_effective_physical_damage(full)
	if buff_mgr:
		full += buff_mgr.consume_strengthen()
	var total_damage = base_damage + int(floor((full - base_damage) / 2.0))
	if buff_mgr:
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
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
	# Next 3 ranged attacks: +3 tempo, +6 damage, +6 range, Enlightened (+10% crit)
	if buff_mgr:
		buff_mgr.tighten_string_charges = 3
	print("[CARD] Tighten String! Next 3 ranged attacks: +3 tempo, +6 damage, +6 range, +10% crit")

func _execute_down_town(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
	print("[CARD] Down Town! Long range (+7) shot for %d damage" % total_damage)

func _execute_barricade(target, _player_stats: PlayerStats) -> void:
	print("[CARD] Barricade! Land barrier created in front of you")

func _execute_sky_fall(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	last_damage_dealt = total_damage
	print("[CARD] Sky Fall! Arrow shot upward. In 10 tempo, it lands for %d damage" % total_damage)

func _execute_sky_attack(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
	print("[CARD] Sky Attack! Leaped and shot from above for %d damage (High Ground)" % total_damage)

func _execute_lead_arrow(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	total_damage = floori(total_damage * 1.8)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
	print("[CARD] Lead Arrow! 1.8x damage from high ground: %d" % total_damage)

func _execute_last_breath(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Consume all remaining mana, deal 3 damage per 10 mana spent
	var mana_used = 0
	if player_stats:
		mana_used = int(player_stats.current_mana)
		if mana_used > 0:
			player_stats.spend_mana(mana_used)
	# Damage is a design constant: 3 per 10 mana keeps the old damage-per-cast
	# feel after the x10 mana rescale.
	var total_damage = floori(mana_used * 0.3)
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
	print("[CARD] Last Breath! Consumed %d mana for %d damage" % [mana_used, total_damage])

func _execute_mixed_bag(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
	print("[CARD] Mixed Bag! Standard arrow for %d damage" % total_damage)

func _execute_quick_arrow(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_physical_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
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
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats, target)
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
	if target and target.has_method("apply_debuff"):
		target.apply_debuff("slow", 4)  # next 4 movements delayed, one stack each
	last_damage_dealt = total_damage
	print("[CARD] Trip! %d damage, enemy slowed 4" % total_damage)

func _execute_choke(target, player_stats: PlayerStats) -> void:
	if target and target.has_method("apply_debuff"):
		target.apply_debuff("silenced", 15)
		target.apply_debuff("choke_dot", 3)
		# The grip squeezes with your own strength: each round deals HALF a
		# basic attack's damage, locked in at cast time.
		if player_stats and "choke_dot_damage" in target:
			target.choke_dot_damage = maxi(1, floori(player_stats.get_basic_attack_damage() / 2.0))
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
			total_damage = crit_multiply(total_damage, player_stats)
	last_damage_dealt = total_damage
	# Actual damage and disarm applied by main.gd _apply_card_world_effects to all nearby enemies
	print("[CARD] Sweeping Disarm! %d damage, surrounding enemies disarmed" % total_damage)

func _execute_consecutive_snap(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# snap_uses_at_play = completed uses BEFORE this play, captured at play
	# time so deferred execution can't run one use ahead.
	var snap_damage = base_damage + (snap_uses_at_play * 9)
	if player_stats:
		snap_damage = player_stats.get_effective_physical_damage(snap_damage)
	if buff_mgr:
		snap_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			snap_damage = crit_multiply(snap_damage, player_stats)
	if target and target.has_method("take_damage"):
		target.take_damage(snap_damage, true)
	# Cost decreases by 10m/1t each use
	var next_uses = snap_uses_at_play + 1
	mana_cost = max(0, 30 - next_uses * 10)
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
	# Skip next turn: forfeit the next tempo-triggered draw (one cycle).
	if deck_manager:
		deck_manager.skip_next_tempo_draw = true
	print("[CARD] Meditate! Hand refreshed, healed to 80%, skipping next turn's draw")

# ============================================
# BRAD CARD FACTORY METHODS
# ============================================

static func create_life_swap() -> Card:
	var card = Card.new()
	card.card_id = "life_swap"
	card.card_name = "Life Swap"
	card.description = "Exchange HP and mana pools (10 mana = 1 HP). Deal damage equal to HP lost."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 40
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
	card.mana_cost = 40
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
	card.mana_cost = 10
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
	card.mana_cost = 10
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
	card.mana_cost = 30
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
	card.mana_cost = 20
	card.tempo_cost = 4
	card.damage = 8
	card.base_damage = 8
	card.target_types = ["enemy"]
	card.is_aoe = true
	card.aoe_shape = "line"
	card.resolve_tick = 3  # Wind up then charge forward
	return card

static func create_heroic_leap() -> Card:
	var card = Card.new()
	card.card_id = "heroic_leap"
	card.card_name = "Heroic Leap"
	card.description = "Jump based on STR. Deal damage based on distance leaped."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 40
	card.tempo_cost = 5
	card.damage = 12
	card.base_damage = 12
	card.target_types = ["point"]
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 1.5
	card.resolve_tick = 4  # Big windup before landing
	return card

static func create_morphine() -> Card:
	var card = Card.new()
	card.card_id = "morphine"
	card.card_name = "Morphine"
	card.description = "Gain 4 temp HP. After 3 turns, lose it and take 2 damage."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
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
	card.mana_cost = 30
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
	card.mana_cost = 10
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
	card.description = "Gain 2 Slowed (your next 2 tiles cost 3 tempo each). For each movement taken in the next 10 tempo, gain 5 armor."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 10
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
	card.mana_cost = 40
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
	card.description = "Deal damage. 80% chance to bounce, -20% per bounce."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
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
	card.school = CardSchool.SPELL
	card.card_name = "Surrounding Ice"
	card.description = "Ice stalagmites deal heavy damage around you. 30% miss chance per enemy."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
	card.tempo_cost = 4
	card.damage = 15
	card.base_damage = 15
	# Per-enemy 70% hit rolls only — a card-level binary roll used to sit here
	# too, but nothing consumed it at resolution: it just miscolored the "30%"
	# in the description as if it predicted the outcome.
	card.chance_effect_percent = 70.0
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.target_types = ["all_nearby"]
	return card

static func create_risk_it() -> Card:
	var card = Card.new()
	card.card_id = "risk_it"
	card.card_name = "Risk It"
	card.description = "30% chance to receive the Biscuit."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 10
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
	card.mana_cost = 20
	card.tempo_cost = 0
	card.duration = 15
	card.target_types = ["self"]
	return card

static func create_loaded_die() -> Card:
	var card = Card.new()
	card.card_id = "loaded_die"
	card.card_name = "Loaded Die"
	card.description = "Next card with a probability has +10% higher chance."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.card_keyword = CardKeyword.GEM
	card.mana_cost = 10
	card.tempo_cost = 1
	card.target_types = ["self"]
	return card

static func create_worst_that_could_happen() -> Card:
	var card = Card.new()
	card.card_id = "worst_that_could_happen"
	card.card_name = "What's the Worst?"
	card.description = "5 damage. 50% for +15 damage, 50% to stun target."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
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
	card.description = "30% for 5 hits, 40% for 3 hits, 30% for 2 hits."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
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
	card.mana_cost = 40
	card.tempo_cost = 5
	card.target_types = ["self"]
	return card

static func create_hope_this_works() -> Card:
	var card = Card.new()
	card.card_id = "hope_this_works"
	card.card_name = "Hope This Works"
	card.description = "50% to heal ally and provide STR for 3 attacks."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 20
	card.tempo_cost = 3
	card.rng_outcomes_data = [{percent = 50.0}]
	card.duration = 15
	card.target_types = ["ally"]
	return card

static func create_lady_luck() -> Card:
	var card = Card.new()
	card.card_id = "lady_luck"
	card.school = CardSchool.SPELL
	card.card_name = "Lady Luck"
	card.description = "Bless an ally. Enlightened: +10% crit chance for 5 attacks."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 40
	card.tempo_cost = 1
	card.duration = 10
	card.target_types = ["ally"]
	return card

static func create_try_this() -> Card:
	var card = Card.new()
	card.card_id = "try_this"
	card.card_name = "Try This!"
	card.description = "Ally +30 mana pool, +2 hand size for 10 tempo. 10% chance reverse."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 4
	card.rng_outcomes_data = [{percent = 10.0}]
	card.duration = 10
	card.target_types = ["ally"]
	return card

static func create_if_pigs_could_fly() -> Card:
	var card = Card.new()
	card.card_id = "if_pigs_could_fly"
	card.school = CardSchool.SPELL
	card.card_name = "If Pigs Could Fly"
	card.description = "Summon a flying pig that explodes on the target."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
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
	card.school = CardSchool.SPELL
	card.card_name = "A Snowball's Chance"
	card.description = "Searing fire 3 spaces forward. 50% to also spread snowballs in a cone."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
	card.tempo_cost = 3
	card.damage = 10
	card.base_damage = 10
	# Chance lives in the card-level binary roll (does the cone spread?). The
	# fire line always hits, so per-enemy rolls (chance_effect_percent) would
	# only paint false red "miss" tiles on enemies the line is guaranteed to hit.
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
	card.description = "Target receives 30% more from healing and regen for 15 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 20
	card.tempo_cost = 2
	card.is_ranged = true
	card.target_types = ["ally"]
	return card

static func create_poisoned_blood() -> Card:
	var card = Card.new()
	card.card_id = "poisoned_blood"
	card.card_name = "Poisoned Blood"
	card.description = "Your next 3 heal cards deal damage instead of healing."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 10
	card.tempo_cost = 2
	card.target_types = ["self"]
	return card

static func create_elixir() -> Card:
	var card = Card.new()
	card.card_id = "elixir"
	card.card_name = "Elixir"
	card.description = "Your next 5 poison ticks heal you instead of hurting."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 10
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
	card.mana_cost = 10
	card.tempo_cost = 4
	card.duration = 10
	card.target_types = ["self"]
	return card

static func create_preparation() -> Card:
	var card = Card.new()
	card.card_id = "preparation"
	card.card_name = "Preparation"
	card.description = "Next utility card and the one after cost 20 less."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 3
	card.target_types = ["self"]
	return card

static func create_exacerbate_wounds() -> Card:
	var card = Card.new()
	card.card_id = "exacerbate_wounds"
	card.card_name = "Exacerbate Wounds"
	card.description = "Deal damage for each card discarded this turn."
	card.damage = 0
	card.base_damage = 0  # damage comes from discards, not a base hit
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
	card.mana_cost = 10
	card.tempo_cost = 2
	card.target_types = ["self"]
	return card

static func create_volatile_mixture() -> Card:
	var card = Card.new()
	card.card_id = "volatile_mixture"
	card.school = CardSchool.SPELL
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
	card.mana_cost = 50
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
	card.mana_cost = 30
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
	# Hits a RANDOM enemy (no aiming) — plays immediately, resolved in main.gd.
	card.target_types = ["self"]
	return card

static func create_premeditated() -> Card:
	var card = Card.new()
	card.card_id = "premeditated"
	card.card_name = "Premeditated"
	card.description = "Deal 8 damage. If this Exposes the enemy, your next attack to that enemy deals +15 bonus damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
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
	card.description = "Marked: your attacks deal +3 damage to the target for 25 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 0
	card.is_ranged = true
	card.range_modifier = 7
	card.target_types = ["enemy"]
	return card

static func create_rise() -> Card:
	var card = Card.new()
	card.card_id = "rise"
	card.school = CardSchool.SPELL
	card.card_name = "Rise"
	card.description = "Lift the earth creating a structure on the map."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 10
	card.tempo_cost = 4
	card.target_types = ["point"]
	return card

static func create_quick_shot() -> Card:
	var card = Card.new()
	card.card_id = "quick_shot"
	card.card_name = "Quick Shot"
	card.description = "Deal 2 damage + half modifiers. Draw a card."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 10
	card.tempo_cost = 1
	card.damage = 2
	card.base_damage = 2
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
	card.mana_cost = 30
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
	card.mana_cost = 40
	card.tempo_cost = 5
	card.duration = 3
	card.target_types = ["self"]
	return card

static func create_tighten_string() -> Card:
	var card = Card.new()
	card.card_id = "tighten_string"
	card.card_name = "Tighten String"
	card.description = "Next 3 ranged attacks: +3 tempo cost, +6 damage, +6 range, +10% crit chance."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
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
	card.mana_cost = 30
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
	card.school = CardSchool.SPELL
	card.card_name = "Barricade"
	card.description = "Create a barricade of land in front of you."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
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
	card.mana_cost = 30
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
	card.mana_cost = 10
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
	card.range_modifier = -2  # "lower range": 5 -> 3 tiles
	card.card_name = "Lead Arrow"
	card.description = "1.8x damage. Requires high ground, lower range."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
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
	card.description = "Consume all remaining mana. Deal 3 damage per 10 mana spent."
	card.damage = 0
	card.base_damage = 0  # damage comes from mana consumed, not a base hit
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
	card.mana_cost = 10
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
	card.mana_cost = 40
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
	card.mana_cost = 20
	card.tempo_cost = 3
	card.target_types = ["point"]
	card.is_ranged = true
	card.range_modifier = 3
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 2.0  # matches the real 2-square pull radius
	return card

static func create_trip() -> Card:
	var card = Card.new()
	card.card_id = "trip"
	card.card_name = "Trip"
	card.description = "Deal 5 damage. Apply 4 Slow — the enemy's next 4 movements are delayed."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
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
	card.description = "Silence enemy. Deals half your auto attack damage every round."
	card.damage = 0
	card.base_damage = 0
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
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
	card.mana_cost = 10
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
	card.mana_cost = 30
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
	card.mana_cost = 20
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
	card.description = "3 damage. Each reuse: +9 damage, -10m/-1t cost."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
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
	card.mana_cost = 20
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
	card.mana_cost = 30
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
	card.description = "Instant. When you take damage, gain 5 armor."
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

static func create_hydra_bite() -> Card:
	var card = Card.new()
	card.card_id = "hydra_bite"
	card.card_name = "Hydra Bite"
	card.description = "Deal 7 damage. Erased from your deck after being played."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 10
	card.tempo_cost = 0
	card.resolve_tick = 0
	card.damage = 7
	card.base_damage = 7
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.erase_on_play = true
	card.linger = true  # Generated into hand; may exceed hand cap
	card.target_types = ["enemy"]
	return card

static func create_thrown_stone() -> Card:
	var card = Card.new()
	card.card_id = "thrown_stone"
	card.card_name = "Thrown Stone"
	card.description = "On Draw: Deal 4 damage to a random enemy. Deal 4 damage to an enemy."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
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
	card.mana_cost = 10
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
			total_damage = crit_multiply(total_damage, player_stats)
			print("[CARD] Thrown Stone CRIT!")
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
		last_damage_dealt = total_damage
		print("[CARD] Thrown Stone dealt %d damage!" % total_damage)

# ============================================
# POWER CARDS (Maintain keyword)
# ============================================

static func create_halo() -> Card:
	var card = Card.new()
	card.card_id = "halo"
	card.school = CardSchool.SPELL
	card.card_name = "Halo"
	card.description = "Maintain: Every cycle, heal all allies in AOE for 3 HP"
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 30  # Initial cast cost
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 3
	card.maintain_cost = 30  # 30 mana reserved from max while active
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
	card.description = "Maintain: When you take damage to your health, gain that much armor"
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 30
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.maintain_cost = 30  # Maintain reserve always equals the card's mana cost
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
	card.mana_cost = 10
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
			total_damage = crit_multiply(total_damage, player_stats)
	if damage_reduction_pct > 0.0:
		total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))
	last_damage_dealt = total_damage
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
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
	card.glut_tempo = 15
	card.card_name = "Blade Barrage"
	card.description = "Deal X*10 damage where X = the number of attack cards in your hand. Glut: 15 tempo."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 40
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

static func create_energy_barrier(armor: int = 5) -> Card:
	# armor comes from the Energy Barrier passive's rank (3..17)
	var card = Card.new()
	card.card_id = "energy_barrier"
	card.card_name = "Energy Barrier"
	card.description = "Gain %d armor. Erase 1." % armor
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = armor
	card.base_block = armor
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
	card.description = "Place two attack cards from your discard pile back into your hand. Glut: 15 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.glut_tempo = 15
	card.target_types = ["self"]  # a self utility — no enemy click required
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
			total_damage = crit_multiply(total_damage, player_stats)
			print("[CARD] Blade Barrage CRIT!")
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
		last_damage_dealt = total_damage
	print("[CARD] Blade Barrage: %d attack cards in hand, dealt %d damage! Glut: 15 tempo" % [attack_count, total_damage])

static func create_cultish_wounds() -> Card:
	var card = Card.new()
	card.card_id = "cultish_wounds"
	card.card_name = "Cultish Wounds"
	card.description = "Maintain: Deal 1 damage to self ignoring armor. Repeat every 5 tempo."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 20
	card.tempo_cost = 2
	card.damage = 1
	card.base_damage = 1
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.maintain_cost = 20
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
	card.description = "Deal 80% remaining health in damage to self. Gain 5 determination and 5 strength."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 20
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
	card.school = CardSchool.SPELL
	card.card_name = "Fountain of Life"
	card.description = "Maintain: Every cycle, deal 2 damage to self and draw a card."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 30
	card.tempo_cost = 4
	card.damage = 2
	card.base_damage = 2
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.maintain_cost = 30
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
		# strength is a read-only computed stat; raise the base and recalc.
		player_stats.base_strength += 5
		player_stats.recalculate_derived_stats()
		print("[CARD] Self Infliction: dealt %d damage to self (80%% of %d HP). Gained +5 DET, +5 STR" % [self_damage, player_stats.current_health + self_damage])

static func create_bob_and_weave() -> Card:
	var card = Card.new()
	card.card_id = "bob_and_weave"
	card.card_name = "Bob and Weave"
	card.description = "Gain 5 armor and draw a card."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 20
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
	card.school = CardSchool.SPELL
	card.card_name = "Absorb Essence"
	card.description = "Deal 1 damage to ALL things on the battlefield. Delay: 10 tempo, obtain Energy Ball."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 50
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
	card.school = CardSchool.SPELL
	card.card_name = "Energy Ball"
	card.description = "Deal X damage where X = total damage done by Absorb Essence. Erased after use."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 10
	card.tempo_cost = 1
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.range_modifier = 5
	card.target_types = ["enemy"]
	card.erase_on_play = true  # "Erased after use" — never recycles from discard
	return card

func _execute_energy_ball(target, player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Damage is set dynamically when Energy Ball is created (based on Absorb Essence hits)
	var total_damage = damage
	if player_stats:
		total_damage = player_stats.get_effective_spell_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
			print("[CARD] Energy Ball CRIT!")
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
		last_damage_dealt = total_damage
	print("[CARD] Energy Ball dealt %d damage (from Absorb Essence)!" % total_damage)

static func create_cover() -> Card:
	var card = Card.new()
	card.card_id = "cover"
	card.card_name = "Cover"
	card.description = "Instant: When an ally takes damage, heal them for the number of cards in your hand."
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	card.mana_cost = 0
	card.tempo_cost = 0  # Reactions never charge tempo; cost removed for now
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["ally"]
	card.reaction_trigger = "on_ally_damage_taken"
	return card

func _execute_cover(player_stats: PlayerStats, deck_manager = null) -> void:
	# Reaction (post-damage): heal the ally back by the number of cards in hand,
	# approximating "reduce the incoming damage by your hand size".
	var hand_size = 0
	if deck_manager:
		hand_size = deck_manager.hand.size()
	if player_stats and hand_size > 0:
		player_stats.heal(hand_size)
	print("[CARD] Cover triggered! Mitigated %d damage (cards in hand)" % hand_size)

static func create_fortify_alliance() -> Card:
	var card = Card.new()
	card.card_id = "fortify_alliance"
	card.card_name = "Fortify Alliance"
	card.description = "Heal an ally for 5 and give yourself 5 armor."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 20
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

func _execute_fortify_alliance(target, player_stats: PlayerStats, buff_mgr: BuffManager = null, deck_manager = null) -> void:
	if target and target.has_method("get_stats"):
		var ally_stats = target.get_stats()
		if ally_stats:
			ally_stats.heal(heal_amount)
			print("[CARD] Fortify Alliance: healed ally for %d" % heal_amount)
	elif target and target.has_method("heal"):
		target.heal(heal_amount)
		print("[CARD] Fortify Alliance: healed ally for %d" % heal_amount)
	# The armor goes to the CASTER. When ally-targeted, player_stats has been
	# rerouted to the ally, so pull the caster's own stats off the deck manager.
	var caster_stats: PlayerStats = player_stats
	if deck_manager and deck_manager.player_stats:
		caster_stats = deck_manager.player_stats
	if caster_stats:
		caster_stats.add_armor(base_block)
		print("[CARD] Fortify Alliance: caster gained %d armor" % base_block)

static func create_communal_donation() -> Card:
	var card = Card.new()
	card.card_id = "communal_donation"
	card.school = CardSchool.SPELL
	card.card_name = "Communal Donation"
	card.description = "Deal damage to yourself and heal allies based on the damage done. Choose amount and allocation."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
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
	card.mana_cost = 20
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
	card.mana_cost = 30
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
	card.mana_cost = 40
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
	card.school = CardSchool.SPELL
	card.card_name = "Gift from the Phoenix"
	card.description = "Instant: When your life drops below 50%, heal up to 80% and apply 5 burn to the nearest enemy."
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
	# Gain 30 mana
	if player_stats:
		player_stats.gain_mana(30)
		print("[CARD] Bloodlust: Gained 30 mana")
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
		print("[CARD] Demonic Rage: Next 50 mana costs use health instead")

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
	# Gain 10 mana, shuffle a Prepare into the deck
	if player_stats:
		player_stats.gain_mana(10)
		print("[CARD] Anticipation: Gained 10 mana")
	if deck_manager:
		deck_manager.add_card_to_deck_from_id("prepare")
		print("[CARD] Anticipation: Shuffled Prepare into deck")

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
	# Put all zero mana cost cards from discard pile into hand. Hand-cap rules
	# still apply (add_card_to_hand rejects non-Linger cards at capacity).
	if not deck_manager:
		return
	var moved := 0
	for c in deck_manager.discard_pile.duplicate():
		if c.mana_cost == 0:
			var before: int = deck_manager.hand.size()
			deck_manager.add_card_to_hand(c)
			if deck_manager.hand.size() > before:
				deck_manager.discard_pile.erase(c)
				moved += 1
	print("[CARD] Meister of Faustmesser: Moved %d zero-cost cards from discard to hand" % moved)

func _execute_item_mastery(player_stats: PlayerStats, deck_manager = null) -> void:
	# Place all cards from items into hand - handled by main.gd
	print("[CARD] Item Mastery: Requesting all item cards be placed into hand")

func _execute_mirror_mirror(deck_manager = null) -> void:
	# Duplicate a random card in hand (excluding itself); the copy has Erase 5.
	if not deck_manager or deck_manager.hand.is_empty():
		return
	var candidates: Array = []
	for c in deck_manager.hand:
		if c.card_id != "mirror_mirror":
			candidates.append(c)
	if candidates.is_empty():
		return
	var src = candidates[randi() % candidates.size()]
	var dup = deck_manager._create_card_from_id(src.card_id)
	if dup:
		dup.erase_tempo = 5
		dup.erase_tempo_remaining = 5
		deck_manager.add_card_to_hand(dup)
		print("[CARD] Mirror Mirror: duplicated %s (Erase 5)" % src.card_name)

func _execute_harness_lightning(player_stats: PlayerStats, buff_mgr: BuffManager = null) -> void:
	# Create lightning orb effect - handled by main.gd
	print("[CARD] Harness Lightning: Creating lightning orb (4 dmg / 5 tempo / 3 range / 30 tempo duration)")

func _execute_deep_pockets(deck_manager = null) -> void:
	# Draw cards until one costs more than 0 mana (draw_card returns the card).
	if not deck_manager:
		return
	var draws = 0
	for i in range(20):  # Safety limit
		var drawn = deck_manager.draw_card()
		draws += 1
		if drawn == null or drawn.mana_cost > 0:
			break
	print("[CARD] Deep Pockets: drew %d card(s) until one cost mana" % draws)

func _execute_best_offense(player_stats: PlayerStats, deck_manager = null, buff_mgr: BuffManager = null) -> void:
	# Gain 3 smith for 25 tempo, or 6 smith if holding no attack cards
	var smith_amount = 3
	if deck_manager:
		var has_attack = false
		for card in deck_manager.hand:
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
	# Reaction: gain 5 armor (the stun is handled in main on_exposed dispatch).
	if player_stats:
		player_stats.add_armor(5)
		print("[CARD] Vengeful Shield: Gained 5 armor")

# ============================================
# JEREMY GENERATED CARDS
# ============================================

func _execute_mana_surge(target, player_stats: PlayerStats, buff_mgr: BuffManager = null, damage_reduction_pct: float = 0.0, self_damage_percent: float = 0.0) -> void:
	# An orb of raw mana — spell school, so INT scales it (was physical).
	var total_damage = base_damage + bonus_damage
	if player_stats:
		total_damage = player_stats.get_effective_spell_damage(total_damage)
	if buff_mgr:
		total_damage += buff_mgr.consume_strengthen()
		if buff_mgr.roll_crit():
			total_damage = crit_multiply(total_damage, player_stats)
	if damage_reduction_pct > 0:
		total_damage = max(1, floori(total_damage * (1.0 - damage_reduction_pct)))
	if target and target.has_method("take_damage"):
		target.take_damage(total_damage, true, damage_type)
		last_damage_dealt = total_damage
	# Gain 10 mana
	if player_stats:
		player_stats.gain_mana(10)
	print("[CARD] Mana Surge: %d damage, +10 mana!" % total_damage)

func _execute_magic_barrier(player_stats: PlayerStats) -> void:
	## Armor comes from the card's block (set from A Mage's Favor's rank, 2..16).
	if player_stats:
		player_stats.add_armor(block)
	print("[CARD] Magic Barrier: +%d armor!" % block)

func _execute_shepherds_mark(player_stats: PlayerStats, deck_manager = null) -> void:
	# player_stats is the MARK TARGET (rerouted to the ally when ally-targeted).
	# The caster — who pays the 8 HP when the mark triggers — is the deck's owner.
	if player_stats:
		player_stats.st_whispers_active = true
		player_stats.st_whispers_tempo = 10
		player_stats.st_whispers_caster = deck_manager.player_stats if (deck_manager and deck_manager.player_stats) else player_stats
	print("[CARD] Shepherd's Mark: ally marked for 10 tempo!")

# ============================================
# PREVIOUSLY-UNIMPLEMENTED CARD EFFECTS (Tier 1)
# ============================================

func _execute_savage_strike(target, is_empowered: bool, player_stats: PlayerStats, damage_reduction_pct: float, self_damage_percent: float, buff_mgr: BuffManager, deck_manager, add_copy: bool) -> void:
	## Deal base damage, then (for the original only) seed a fragile copy into the
	## discard pile. The copy already carries Erase 20 from its create function.
	_execute_slash(target, is_empowered, player_stats, damage_reduction_pct, self_damage_percent, buff_mgr)
	if add_copy and deck_manager:
		deck_manager.add_card_to_deck_from_id("savage_strike_copy")
		print("[CARD] Savage Strike! Added a fragile copy (Erase 20) to discard")

func _execute_shield_slam(target, player_stats: PlayerStats) -> void:
	## Deal damage equal to current armor, then lose half of it.
	var armor_now := player_stats.current_armor if player_stats else 0
	last_damage_dealt = armor_now
	if target and target.has_method("take_damage") and armor_now > 0:
		target.take_damage(armor_now, true)
	if player_stats:
		player_stats.current_armor = player_stats.current_armor / 2
		player_stats.armor_changed.emit(player_stats.current_armor)
	print("[CARD] Shield Slam! Dealt %d damage (current armor); kept half" % armor_now)

func _execute_exposed_artery(target) -> void:
	## Deal damage equal to 0.5 x the target's missing-health percentage.
	if not target or not target.has_method("take_damage"):
		return
	var maxh = target.get("max_health")
	var curh = target.get("current_health")
	var dmg := 0
	if maxh != null and curh != null and int(maxh) > 0:
		var missing_pct := float(int(maxh) - int(curh)) / float(int(maxh)) * 100.0
		dmg = floori(0.5 * missing_pct)
	last_damage_dealt = dmg
	if dmg > 0:
		target.take_damage(dmg, true)
	print("[CARD] Exposed Artery! Dealt %d damage (0.5x missing health%%)" % dmg)

func _execute_tower_shield(player_stats: PlayerStats, buff_mgr: BuffManager) -> void:
	## Gain armor (card.block), then stagger yourself for 40 tempo.
	if player_stats:
		player_stats.add_armor(block)
	if buff_mgr and buff_mgr.debuff_manager:
		buff_mgr.debuff_manager.apply_debuff(Debuff.create(Debuff.DebuffType.STAGGERED, 4, -1))
	print("[CARD] Tower Shield! +%d armor, staggered for 40 tempo" % block)

func _execute_harden(player_stats: PlayerStats, buff_mgr: BuffManager) -> void:
	## Gain armor (card.block) and 10% damage resistance for 15 tempo.
	if player_stats:
		player_stats.add_armor(block)
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_resilient(10, 15, "Harden", DamageTypes.Type.PHYSICAL))
	print("[CARD] Harden! +%d armor, 10%% physical resistance for 15 tempo" % block)

func _execute_hunker_down(buff_mgr: BuffManager) -> void:
	## Fortify (armor does not decay) for 30 tempo.
	if buff_mgr:
		buff_mgr.apply_buff(Buff.create_fortify(30, "Hunker Down"))
	print("[CARD] Hunker Down! Fortify for 30 tempo")

func _execute_energy_barrier(player_stats: PlayerStats) -> void:
	## Gain armor (card.block). Erase 1 is handled as a card property.
	if player_stats:
		player_stats.add_armor(block)
	print("[CARD] Energy Barrier! +%d armor" % block)

func _execute_the_lights_favor(player_stats: PlayerStats, deck_manager) -> void:
	## Heal and draw a card.
	if player_stats:
		player_stats.heal(heal_amount)
	if deck_manager:
		deck_manager.draw_card()
	print("[CARD] The Light's Favor! Healed %d and drew a card" % heal_amount)

func _execute_healthy_habit(player_stats: PlayerStats, deck_manager) -> void:
	## Draw 2 cards and gain 20 mana. Burden is handled as a card property.
	if deck_manager:
		deck_manager.draw_card()
		deck_manager.draw_card()
	if player_stats:
		player_stats.gain_mana(20)
	print("[CARD] Healthy Habit! Drew 2 cards and gained 20 mana")

func _execute_gargle_and_spit(player_stats: PlayerStats) -> void:
	## Heal and gain +1 strength. Sticky is handled as a card property.
	if player_stats:
		player_stats.heal(heal_amount)
		player_stats.base_strength += 1
		player_stats.recalculate_derived_stats()
	print("[CARD] Gargle and Spit! Healed %d and +1 strength" % heal_amount)

func _execute_living_armor(buff_mgr: BuffManager) -> void:
	## Gain Regen equal to your current stacks of Fortify.
	if not buff_mgr:
		return
	var fort = buff_mgr.get_buff(Buff.BuffType.FORTIFY)
	var stacks = fort.stacks if fort else 0
	if stacks > 0:
		buff_mgr.apply_buff(Buff.create_regen(stacks, 15, "Living Armor"))
	print("[CARD] Living Armor! Regen %d (= Fortify stacks)" % stacks)

func _execute_multi_hit(target, hits: int, player_stats: PlayerStats, damage_reduction_pct: float, buff_mgr: BuffManager, crit_step: int) -> int:
	## Deal base_damage to a single target `hits` times. crit_step adds that much
	## crit chance per successive hit (multishot); 0 for flat hits (exhausted
	## assault). Stops early if the target dies mid-volley.
	var total := 0
	for hit in range(hits):
		if not target or not is_instance_valid(target) or not target.has_method("take_damage"):
			break
		var dead = target.get("is_dead")
		if dead == true:
			break
		var dmg = base_damage + bonus_damage
		if player_stats:
			dmg = player_stats.get_effective_physical_damage(dmg)
		if buff_mgr:
			dmg += buff_mgr.consume_strengthen()
			# +crit_step% per hit starting from the FIRST hit ("each time
			# gaining 10% crit chance"), not from the second.
			if buff_mgr.roll_crit(crit_step * (hit + 1)):
				dmg = crit_multiply(dmg, player_stats)
				print("[CARD] %s CRIT on hit %d!" % [card_name, hit + 1])
		if damage_reduction_pct > 0.0:
			dmg = max(1, floori(dmg * (1.0 - damage_reduction_pct)))
		target.take_damage(dmg, true)
		total += dmg
	last_damage_dealt = total
	print("[CARD] %s dealt %d damage across %d hits" % [card_name, total, hits])
	return total

func _execute_provider(player_stats: PlayerStats) -> void:
	## Heal the targeted ally and give them 10 mana. (Ally routing in
	## execute_deferred_card points player_stats at the chosen ally.) Burden is a
	## card property.
	if player_stats:
		player_stats.heal(heal_amount)
		player_stats.gain_mana(10)
	print("[CARD] Provider! Healed %d and gave 10 mana to the ally" % heal_amount)

func _execute_give_in(player_stats: PlayerStats, deck_manager) -> void:
	## Gain 30 mana now; skip the next tempo-triggered draw.
	if player_stats:
		player_stats.gain_mana(30)
	if deck_manager:
		deck_manager.skip_next_tempo_draw = true
	print("[CARD] Give In! +30 mana; next tempo draw skipped")

func _compute_attack_damage(player_stats: PlayerStats, spell: bool) -> int:
	## Compute (but do not deal) this card's damage, storing it in last_damage_dealt
	## for main.gd to apply across an area / line.
	var d = base_damage + bonus_damage
	if player_stats:
		d = player_stats.get_effective_spell_damage(d) if spell else player_stats.get_effective_physical_damage(d)
	last_damage_dealt = d
	return d

func _execute_shed_weight(deck_manager) -> void:
	## Discard every defensive card in hand; for each one discarded, knock 1 tempo
	## off a non-defensive card still in hand.
	if not deck_manager:
		return
	var defensive: Array = []
	for c in deck_manager.hand:
		if c != self and c.card_type == CardType.DEFENSE:
			defensive.append(c)
	var discarded := 0
	for c in defensive:
		if deck_manager.discard_card_from_hand(c):
			discarded += 1
	var reduced := 0
	for c in deck_manager.hand:
		if reduced >= discarded:
			break
		if c != self and c.card_type != CardType.DEFENSE:
			c.tempo_cost = max(0, c.tempo_cost - 1)
			reduced += 1
	print("[CARD] Shed Weight! Discarded %d defensive card(s); reduced %d card(s) by 1 tempo" % [discarded, reduced])

static func create_mana_surge(damage_amount: int = 5) -> Card:
	# damage_amount comes from the Mana Surge passive's rank (4..18)
	var card = Card.new()
	card.card_id = "mana_surge"
	card.school = CardSchool.SPELL
	card.card_name = "Mana Surge"
	card.description = "Deal %d damage, gain 10 mana. Erased after play." % damage_amount
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 2
	card.damage = damage_amount
	card.base_damage = damage_amount
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.erase_on_play = true  # one-shot: erased after play, not while in hand
	card.target_types = ["enemy"]
	return card

static func create_magic_barrier(armor: int = 8) -> Card:
	# armor comes from A Mage's Favor's rank (2..16)
	var card = Card.new()
	card.card_id = "magic_barrier"
	card.school = CardSchool.SPELL
	card.card_name = "Magic Barrier"
	card.description = "Gain %d armor. Instant." % armor
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = armor
	card.base_block = armor
	card.heal_amount = 0
	card.erase_on_play = true  # consumed when it triggers, not while waiting
	card.reaction_trigger = "on_damage_taken"
	card.target_types = ["self"]
	return card

# ============================================
# SHEPHERD'S MARK (Whispers of the Flock)
# ============================================

static func create_shepherds_mark(armor: int = 10) -> Card:
	# armor comes from Whispers of the Flock's rank (5..19)
	var card = Card.new()
	card.card_id = "shepherds_mark"
	card.school = CardSchool.SPELL
	card.card_name = "Shepherd's Mark"
	card.description = "Mark the healed ally for 10 tempo. If they would take lethal damage, they survive at 1 HP and gain %d armor, but Jeremy takes 8 damage." % armor
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.erase_tempo = 10
	card.erase_tempo_remaining = 10
	card.target_types = ["self", "ally"]
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
	card.description = "Apply 3 Vulnerable to self. Gain 30 mana. Gain Strengthen 3 for your next 3 attacks."
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
	card.mana_cost = 20
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
	card.mana_cost = 50
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
	card.mana_cost = 10
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
	card.mana_cost = 50
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
	card.description = "Gain +10 mana regen while this is in your hand. Discards after 2 cycles."
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
	card.description = "Draw 2 cards. Gain 20 mana. Burden."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 20
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
	card.description = "Gain 10 mana. Shuffle a Prepare into your deck."
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
	card.mana_cost = 30
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
	card.description = "Put all zero mana cost cards from discard pile into your hand. Jail: 20."
	card.jail_on_play = 20
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
	card.mana_cost = 50
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
	card.school = CardSchool.SPELL
	card.card_name = "Mirror Mirror"
	card.description = "Duplicate a card in your hand. The duplicate has Erase: 5."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 40
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
	card.school = CardSchool.SPELL
	card.card_name = "Harness Lightning"
	card.description = "Create an orb of lightning that circles you. Deals 4 damage every 5 tempo to a random enemy within 3 spaces. Lasts 30 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
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
	card.mana_cost = 40
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
	card.mana_cost = 40
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
	card.description = "Instant. When taking damage that exposes the player, stun an enemy within melee range and gain 5 armor."
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

# ============================================
# CORY NEW CARDS
# ============================================

static func create_misery_loves_company() -> Card:
	var card = Card.new()
	card.card_id = "misery_loves_company"
	card.card_name = "Misery Loves Company"
	card.description = "Your next AOE attack spreads the debuffs on yourself and all enemies hit, to all the enemies that are hit."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 50
	card.tempo_cost = 1
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_release_tension() -> Card:
	var card = Card.new()
	card.card_id = "release_tension"
	card.card_name = "Release Tension"
	card.description = "Remove a stack of debuffs from the enemy and heal for the amount of debuffs removed x3. Choose which debuff."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	return card

static func create_vines() -> Card:
	var card = Card.new()
	card.card_id = "vines"
	card.school = CardSchool.SPELL
	card.card_name = "Vines"
	card.description = "Summon vines holding an enemy in place for 3 turns. Deal 4 damage per turn the enemy is held still."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
	card.tempo_cost = 3
	card.damage = 4
	card.base_damage = 4
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.duration = 15  # 3 turns ~ 15 tempo
	card.target_types = ["enemy"]
	return card

static func create_exposed_artery() -> Card:
	var card = Card.new()
	card.card_id = "exposed_artery"
	card.card_name = "Exposed Artery"
	card.description = "Deal damage equal to 0.5x the enemy's missing health %."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 50
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	return card

# ============================================
# BRAD NEW CARDS
# ============================================

static func create_internal_combustion() -> Card:
	var card = Card.new()
	card.card_id = "internal_combustion"
	card.card_name = "Internal Combustion"
	card.description = "Remove half your armor and deal damage around you based on the amount."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 40
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 3.0  # matches the real 3-tile blast
	card.target_types = ["self"]
	return card

static func create_savage_strike() -> Card:
	var card = Card.new()
	card.card_id = "savage_strike"
	card.card_name = "Savage Strike"
	card.description = "Deal 6 damage. Add a copy of this card to your discard pile. The copy has Erase 20."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
	card.tempo_cost = 2
	card.damage = 6
	card.base_damage = 6
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	return card

static func create_savage_strike_copy() -> Card:
	var card = Card.new()
	card.card_id = "savage_strike_copy"
	card.card_name = "Savage Strike"
	card.description = "Deal 6 damage. Add a copy of this card to your discard pile. The copy has Erase 20."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
	card.tempo_cost = 2
	card.damage = 6
	card.base_damage = 6
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.erase_tempo = 20
	card.erase_tempo_remaining = 20
	card.target_types = ["enemy"]
	return card

static func create_heavy_swing() -> Card:
	var card = Card.new()
	card.card_id = "heavy_swing"
	card.card_name = "Heavy Swing"
	card.description = "Can only be played if only attack cards are in your hand. Deal 20 damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
	card.tempo_cost = 3
	card.damage = 20
	card.base_damage = 20
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	card.resolve_tick = 2  # Short windup for heavy hit
	return card

static func create_shed_weight() -> Card:
	var card = Card.new()
	card.card_id = "shed_weight"
	card.card_name = "Shed Weight"
	card.description = "Discard all defensive cards in your hand. For each card discarded, subtract one tempo from a non-defensive card in your hand."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 40
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_give_in() -> Card:
	var card = Card.new()
	card.card_id = "give_in"
	card.card_name = "Give In"
	card.description = "Immediately gain 30 mana. The next time you would draw from Tempo being triggered, you don't."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_shield_slam() -> Card:
	var card = Card.new()
	card.card_id = "shield_slam"
	card.card_name = "Shield Slam"
	card.description = "Deal damage based on your current armor. Lose half your armor."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 50
	card.tempo_cost = 10
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	card.resolve_tick = 7  # Heavy windup with shield
	return card

static func create_tower_shield() -> Card:
	var card = Card.new()
	card.card_id = "tower_shield"
	card.card_name = "Tower Shield"
	card.description = "Gain 40 armor. Gain 4 Staggered (your next 4 attack cards cost 15 more mana)."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 50
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.block = 40
	card.base_block = 40
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_living_armor() -> Card:
	var card = Card.new()
	card.card_id = "living_armor"
	card.card_name = "Living Armor"
	card.description = "Gain regen until it is equal to your fortify."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 30
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["self"]
	return card

static func create_the_lights_favor() -> Card:
	var card = Card.new()
	card.card_id = "the_lights_favor"
	card.school = CardSchool.SPELL
	card.card_name = "The Light's Favor"
	card.description = "Heal 5 and draw a card."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 20
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 5
	card.target_types = ["self"]
	return card

static func create_hunker_down() -> Card:
	var card = Card.new()
	card.card_id = "hunker_down"
	card.card_name = "Hunker Down"
	card.description = "Gain Fortify for 30 tempo."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 40
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.duration = 30
	card.target_types = ["self"]
	return card

static func create_succumb() -> Card:
	var card = Card.new()
	card.card_id = "succumb"
	card.card_name = "Succumb"
	card.description = "For 20 tempo, gain fortify, blessed 2, and Resilient 20%, plus Strengthen 5 on your next 5 attacks. After 10 tempo, take 10 damage. After 10 additional tempo, take 10 more damage and become cuffed, drained, and disarmed for 10 tempo."
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

static func create_harden() -> Card:
	var card = Card.new()
	card.card_id = "harden"
	card.card_name = "Harden"
	card.description = "Gain 10% physical resistance for 15 tempo and 10 armor."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 30
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.block = 10
	card.base_block = 10
	card.heal_amount = 0
	card.duration = 15
	card.target_types = ["self"]
	return card

static func create_roll() -> Card:
	var card = Card.new()
	card.card_id = "roll"
	card.card_name = "Roll"
	card.description = "Roll X squares where X is the tempo cost, max 5. When hitting another character, end the roll. If enemy, deal 10 damage and disarm for 5 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 10
	card.tempo_cost = 5
	card.damage = 10
	card.base_damage = 10
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["point"]
	return card

# ============================================
# JEREMY NEW CARDS
# ============================================

static func create_cryonics() -> Card:
	var card = Card.new()
	card.card_id = "cryonics"
	card.school = CardSchool.SPELL
	card.card_name = "Cryonics"
	card.description = "Encase an ally in ice for 15 tempo. They cannot act but are untargetable. They heal 3 health per 5 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 10
	card.tempo_cost = 6
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 3
	card.duration = 15
	card.is_ranged = true
	card.target_types = ["ally"]
	return card

static func create_friendship() -> Card:
	var card = Card.new()
	card.card_id = "friendship"
	card.school = CardSchool.SPELL
	card.card_name = "Friendship"
	card.description = "Choose two allies. When one heals, they both heal. When one takes damage, they split it."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.target_types = ["ally"]
	return card

static func create_provider() -> Card:
	var card = Card.new()
	card.card_id = "provider"
	card.school = CardSchool.SPELL
	card.card_name = "Provider"
	card.description = "Heal an ally 6 health and give them 10 mana. Burden."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 10
	card.tempo_cost = 1
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 6
	card.has_burden = true
	card.is_ranged = true
	card.target_types = ["ally"]
	return card

static func create_fireball() -> Card:
	var card = Card.new()
	card.card_id = "fireball"
	card.element = "red"  # Feral Evocation slot color
	card.school = CardSchool.SPELL
	card.card_name = "Fireball"
	card.description = "Hurl a massive fireball. Range +5, 12 damage, apply 3 burn. Costs 10 less mana for each other fire spell cast this turn. AOE circle 4 squares."
	card.is_fire_spell = true
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 80
	card.tempo_cost = 8
	card.damage = 12
	card.base_damage = 12
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.range_modifier = 5
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 2.0  # 4 squares diameter = 2 radius
	card.target_types = ["point"]
	card.resolve_tick = 6  # Channel the fireball
	return card

static func create_spark() -> Card:
	var card = Card.new()
	card.card_id = "spark"
	card.school = CardSchool.SPELL
	card.card_name = "Spark"
	card.description = "Deal 3 damage. Ranged -2. Subtract 2 tempo from 2 random cards in your hand. In 15 tempo, add 2 tempo to two random cards in your hand."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 10
	card.tempo_cost = 3
	card.damage = 3
	card.base_damage = 3
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.range_modifier = -2
	card.target_types = ["enemy"]
	return card

static func create_god_of_thunder() -> Card:
	var card = Card.new()
	card.card_id = "god_of_thunder"
	card.school = CardSchool.SPELL
	card.card_name = "God of Thunder"
	card.description = "Absorb all shock on enemies and cast down a massive bolt of lightning dealing damage based on the amount of shock absorbed."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 50
	card.tempo_cost = 10
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.target_types = ["point"]
	card.resolve_tick = 8  # Long channel for massive spell
	return card

# ============================================
# HELM-GRANTED CARDS (item pass 1)
# ============================================

static func create_neither_man_nor_beast() -> Card:
	var card = Card.new()
	card.card_id = "neither_man_nor_beast"
	card.card_name = "Neither Man nor Beast"
	card.description = "Deal 10 damage ignoring all resistances and armor. The target cannot heal that damage for 10 tempo."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 10
	card.tempo_cost = 2
	card.damage = 10
	card.base_damage = 10
	card.target_types = ["enemy"]
	return card

static func create_resourceful_replenish() -> Card:
	var card = Card.new()
	card.card_id = "resourceful_replenish"
	card.card_name = "Resourceful Replenish"
	card.description = "Maintain: your attacks heal you for 5% of the damage dealt."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 20
	card.maintain_cost = 20
	card.tempo_cost = 2
	card.target_types = ["self"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_out_of_guesses() -> Card:
	var card = Card.new()
	card.card_id = "out_of_guesses"
	card.card_name = "Out of Guesses"
	card.description = "Discard your whole hand, then draw that many cards."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 15
	card.tempo_cost = 3
	card.target_types = ["self"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_twenty_twenty() -> Card:
	var card = Card.new()
	card.card_id = "twenty_twenty"
	card.card_name = "20/20"
	card.description = "Maintain: gain +3 range on all ranged offensive cards."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 25
	card.maintain_cost = 25
	card.tempo_cost = 3
	card.target_types = ["self"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_its_alive() -> Card:
	var card = Card.new()
	card.card_id = "its_alive"
	card.card_name = "ITS ALIVE!!!!!"
	card.description = "Resurrect a nearby corpse into Frankensteins Monster — a summon that fights for you."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 20
	card.tempo_cost = 5
	card.target_types = ["point"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_protection_from_alnitak() -> Card:
	var card = Card.new()
	card.card_id = "protection_from_alnitak"
	card.card_name = "Protection From Alnitak"
	card.description = "Gain 10 armor and Brace for 5 attacks. The Brace percentage equals your empty hand slots (max hand size minus cards held)."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 20
	card.tempo_cost = 1
	card.block = 10
	card.base_block = 10
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

static func create_balance_of_alnilam() -> Card:
	var card = Card.new()
	card.card_id = "balance_of_alnilam"
	card.card_name = "Balance of Alnilam"
	card.description = "If this is the only card in your hand, draw 6 cards."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 10
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

static func create_crack_of_mintaka() -> Card:
	var card = Card.new()
	card.card_id = "crack_of_mintaka"
	card.card_name = "Crack of Mintaka"
	card.description = "Discard any number of cards, then deal 10 damage to an enemy within that many squares, with +3% crit damage per card discarded."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
	card.tempo_cost = 4
	card.damage = 10
	card.base_damage = 10
	card.target_types = ["enemy"]
	return card

static func create_serene_center() -> Card:
	var card = Card.new()
	card.card_id = "serene_center"
	card.card_name = "Serene Center"
	card.description = "Set your health (temp health included) and your mana to half of their maximums — whether that raises or lowers them."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

static func create_stone_encase() -> Card:
	var card = Card.new()
	card.card_id = "stone_encase"
	card.card_name = "Stone Encase"
	card.description = "Gain 50 armor and become stunned for 5 tempo."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 45
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

static func create_m_for_mini() -> Card:
	var card = Card.new()
	card.card_id = "m_for_mini"
	card.card_name = "M for Mini"
	card.description = "Apply 2 Vulnerable and 2 Weaken to an enemy."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 15
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["enemy"]
	return card

static func create_hemotoxins() -> Card:
	var card = Card.new()
	card.card_id = "hemotoxins"
	card.element = "green"  # Feral Evocation slot color
	card.card_name = "Hemotoxins"
	card.description = "Apply 10 Poison. If the target is below 50% health, apply 20 instead."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.school = CardSchool.SPELL
	card.mana_cost = 50
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["enemy"]
	return card

static func create_poof_and_weave() -> Card:
	var card = Card.new()
	card.card_id = "poof_and_weave"
	card.card_name = "Poof and Weave"
	card.description = "Become invisible, gain 10 armor and draw a card."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 40
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

static func create_healing_tonic() -> Card:
	var card = Card.new()
	card.card_id = "healing_tonic"
	card.card_name = "Healing Tonic"
	card.description = "Heal an ally within 5 squares for 5."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.card_keyword = CardKeyword.POCKET
	card.mana_cost = 0
	card.tempo_cost = 0
	card.heal_amount = 5
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["ally", "self"]
	return card

static func create_poison_bomb() -> Card:
	var card = Card.new()
	card.card_id = "poison_bomb"
	card.element = "green"  # Feral Evocation slot color
	card.card_name = "Poison Bomb"
	card.description = "A cloud of poison: all enemies in a 2-square radius gain 6 Poison."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.school = CardSchool.SPELL
	card.card_keyword = CardKeyword.POCKET
	card.mana_cost = 10
	card.tempo_cost = 3
	card.is_ranged = true
	card.range_modifier = 1  # range 6
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 2.0
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["point"]
	return card

static func create_chain_lightning() -> Card:
	var card = Card.new()
	card.card_id = "chain_lightning"
	card.element = "yellow"  # Feral Evocation slot color
	card.card_name = "Chain Lightning"
	card.description = "Deal 10 damage, then bounce to nearby enemies, losing 2 damage per bounce until it reaches zero."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.school = CardSchool.SPELL
	card.mana_cost = 50
	card.tempo_cost = 8
	card.is_ranged = true
	card.range_modifier = 3  # range 8
	card.damage = 10
	card.base_damage = 10
	card.target_types = ["enemy"]
	return card

static func create_ice_grenade() -> Card:
	var card = Card.new()
	card.card_id = "ice_grenade"
	card.element = "blue"  # Feral Evocation slot color
	card.card_name = "Ice Grenade"
	card.description = "Deal 5 damage and apply 2 Cold in a 2-square radius. Two shots — each aimed separately."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.school = CardSchool.SPELL
	card.mana_cost = 10
	card.tempo_cost = 2
	card.is_ranged = true
	card.range_modifier = 0  # range 5
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 2.0
	card.sticky = 2  # two throws before it discards
	card.damage = 5
	card.base_damage = 5
	card.target_types = ["point"]
	return card

static func create_fire_punch() -> Card:
	var card = Card.new()
	card.card_id = "fire_punch"
	card.card_name = "Fire Punch"
	card.description = "Melee: 0 base damage (+STR scaling). Leaves a path of fire behind the target. Puts a copy with Erase 5 in your hand (the copy does not copy itself)."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 5
	card.tempo_cost = 1
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["enemy"]
	return card

static func create_gift_from_the_gods() -> Card:
	var card = Card.new()
	card.card_id = "gift_from_the_gods"
	card.card_name = "Gift from the Gods"
	card.description = "Gain 3 Enlightened (10% crit chance; one stack is consumed per attack)."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 40
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

static func create_stance_switch() -> Card:
	var card = Card.new()
	card.card_id = "stance_switch"
	card.card_name = "Stance Switch"
	card.description = "Remove 10 armor from the enemy and apply 2 Vulnerable. No armor? Just apply 2 Vulnerable."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 10
	card.tempo_cost = 2
	card.target_types = ["enemy"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_switch_kick() -> Card:
	var card = Card.new()
	card.card_id = "switch_kick"
	card.card_name = "Switch Kick"
	card.description = "Deal 2 damage and disarm the enemy for 1 attack."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 2
	card.tempo_cost = 2
	card.damage = 2
	card.base_damage = 2
	card.target_types = ["enemy"]
	return card

static func create_return_cut() -> Card:
	var card = Card.new()
	card.card_id = "return_cut"
	card.card_name = "Return Cut"
	card.description = "Instant. When an attack fails to break through your armor, immediately counter with a melee strike (+5% crit chance)."
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.target_types = ["self"]
	card.reaction_trigger = "on_attack_blocked"
	card.damage = 0
	card.base_damage = 0
	return card

static func create_smoke_bomb() -> Card:
	var card = Card.new()
	card.card_id = "smoke_bomb"
	card.card_name = "smoke bomb"
	card.description = "A puff of smoke (2-square radius): allies inside are invisible and gain 10% crit chance while they stay in it. Lasts 8 tempo. Jailed for 20 after play."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 2
	card.jail_on_play = 20
	card.target_types = ["point"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_tight_rope() -> Card:
	var card = Card.new()
	card.card_id = "tight_rope"
	card.card_name = "Tight Rope"
	card.description = "Instant. When a hit puts you below 20% health, gain 20 temp health and +15 damage on your next attack."
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.target_types = ["self"]
	card.reaction_trigger = "on_health_below_20"
	card.damage = 0
	card.base_damage = 0
	return card

static func create_shift() -> Card:
	var card = Card.new()
	card.card_id = "shift"
	card.card_name = "shift"
	card.description = "Move up to 2 spaces for free."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.target_types = ["point"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_donate_cleats() -> Card:
	var card = Card.new()
	card.card_id = "donate_cleats"
	card.card_name = "Donate Cleats"
	card.description = "For 5 tempo, grant an ally +5 AGI and +4 DEX."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 35
	card.tempo_cost = 0
	card.target_types = ["ally", "self"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_terrain_formation() -> Card:
	var card = Card.new()
	card.card_id = "terrain_formation"
	card.card_name = "Terrain formation"
	card.description = "Create a hill you can walk on. The hill lasts 5 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 25
	card.tempo_cost = 3
	card.target_types = ["point"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_escape_and_bewilder() -> Card:
	var card = Card.new()
	card.card_id = "escape_and_bewilder"
	card.card_name = "Escape and bewilder"
	card.description = "Blink up to 5 spaces. Enemies within 3 of the space you left are stunned for 3 tempo."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 50
	card.tempo_cost = 2
	card.target_types = ["point"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_mend() -> Card:
	var card = Card.new()
	card.card_id = "mend"
	card.card_name = "Mend"
	card.description = "Allies within 4 squares restore 20% health and 20% mana, and gain armor equal to the health restored."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 4
	card.target_types = ["self"]
	card.damage = 0
	card.base_damage = 0
	return card

static func create_shiv() -> Card:
	var card = Card.new()
	card.card_id = "shiv"
	card.card_name = "Shiv"
	card.description = "Melee. 2 damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 5
	card.tempo_cost = 1
	card.damage = 2
	card.base_damage = 2
	card.target_types = ["enemy"]
	return card

static func create_worms_armageddon() -> Card:
	var card = Card.new()
	card.card_id = "worms_armageddon"
	card.school = CardSchool.SPELL
	card.card_name = "Worms Armageddon"
	card.description = "Rain massive meteors dealing 23 damage. 10% to summon two Alaskan Bull Worms (12 HP, 6 damage, burrowed until attacking, untargetable while burrowed, 1 movement per tempo)."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 50
	card.tempo_cost = 10
	card.damage = 23
	card.base_damage = 23
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 100.0  # hits every enemy on the field, like Absorb Essence
	card.rng_outcomes_data = [{"percent": 10.0}]
	card.target_types = ["point"]
	return card

static func create_healthy_bliss() -> Card:
	var card = Card.new()
	card.card_id = "healthy_bliss"
	card.school = CardSchool.SPELL
	card.card_name = "Healthy Bliss"
	card.description = "Instant: Once this has been in your hand for 20 tempo, automatically heal all allies for 10 health."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 10
	card.target_types = ["ally"]
	card.in_hand_heal_tempo = 20  # Heals all allies once it has spent this long in hand
	return card

# ============================================
# WEAPON-GRANTED CARDS (weapons pass 1)
# ============================================

static func create_hard_helmet() -> Card:
	var card = Card.new()
	card.card_id = "hard_helmet"
	card.card_name = "Hard Helmet"
	card.description = "Instant: when you play a utility card, gain 8 armor and deal 2 damage to the closest enemy."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.reaction_trigger = "on_utility_played"
	card.target_types = ["self"]
	return card

static func create_slice() -> Card:
	var card = Card.new()
	card.card_id = "slice"
	card.card_name = "Slice"
	card.description = "Deal 15 damage."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 10
	card.tempo_cost = 3
	card.damage = 15
	card.base_damage = 15
	card.target_types = ["enemy"]
	return card

static func create_death_vortex() -> Card:
	var card = Card.new()
	card.card_id = "death_vortex"
	card.card_name = "Death Vortex"
	card.description = "Instant: after you are hit 5 times, spin — 15 damage to all adjacent enemies. If the Vortex kills, it returns to your hand."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 1.0
	card.reaction_trigger = "on_hit_streak_5"
	card.target_types = ["self"]
	return card

static func create_earth_rattle() -> Card:
	var card = Card.new()
	card.card_id = "earth_rattle"
	card.card_name = "Earth Rattle"
	card.description = "Smash the ground: 40 damage in a 3-square quake around the impact. Enemies hit are Slowed 2 and Weakened 2."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 60
	card.tempo_cost = 6
	card.damage = 0
	card.base_damage = 0
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 3.0
	card.target_types = ["enemy"]
	return card

static func create_feed_into_the_pain() -> Card:
	var card = Card.new()
	card.card_id = "feed_into_the_pain"
	card.card_name = "Feed into the Pain"
	card.description = "Instant: when you take damage below 30% health, gain Strengthen 20 for 4 attacks and 25 temp HP."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.reaction_trigger = "on_damage_taken_low"
	card.target_types = ["self"]
	return card

static func create_psionic_flow() -> Card:
	var card = Card.new()
	card.card_id = "psionic_flow"
	card.card_name = "Psionic Flow"
	card.description = "Instant: when an ally takes damage within 3 squares, restore 8 to them and push the attacker back 1 — or when you play an attack, deal +8 damage and push the target back 1. Whichever comes first."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.reaction_trigger = "psionic_flow"
	card.target_types = ["self"]
	return card

static func create_purge_wrath() -> Card:
	var card = Card.new()
	card.card_id = "purge_wrath"
	card.card_name = "Purge Wrath"
	card.description = "Your next attack deals bonus damage equal to your Wrath as a percent, on top of the flat Wrath bonus. Wrath resets to 0."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 55
	card.tempo_cost = 8
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

static func create_sanguine_the_penguin() -> Card:
	var card = Card.new()
	card.card_id = "sanguine_the_penguin"
	card.card_name = "Sanguine the Penguin"
	card.description = "Instant: at 9 Vitality, the stacks purge and Sanguine the blood penguin waddles forth — 50 HP, stays beside you, 8 damage every 5 tempo; damage he takes heals you half as much."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.reaction_trigger = "on_vitality_9"
	card.target_types = ["self"]
	return card

static func create_wrath_of_the_sea() -> Card:
	var card = Card.new()
	card.card_id = "wrath_of_the_sea"
	card.card_name = "Wrath of the Sea"
	card.description = "Spend HALF your current mana. Blink to a point and deal the mana spent (plus STR) to every enemy in a 4x4 sea burst; all of them are shoved to its edge. Gain 15 mana per enemy hit."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.percent_mana_cost = 0.5
	card.tempo_cost = 8
	card.damage = 0
	card.base_damage = 0
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 2.0
	card.school = CardSchool.SPELL
	card.target_types = ["point"]
	return card

static func create_monk_of_the_night() -> Card:
	var card = Card.new()
	card.card_id = "monk_of_the_night"
	card.card_name = "Monk of the Night"
	card.description = "Maintain: your attack cards grant 10% of their damage as block."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 50
	card.maintain_cost = 50
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

# ============================================
# CHEST-GRANTED CARDS (chests pass 1)
# ============================================

static func create_clang_up() -> Card:
	var card = Card.new()
	card.card_id = "clang_up"
	card.card_name = "Clang Up"
	card.description = "Gain 10 block."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 20
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.block = 10
	card.base_block = 10
	card.target_types = ["self"]
	return card

static func create_negotiate() -> Card:
	var card = Card.new()
	card.card_id = "negotiate"
	card.card_name = "Negotiate"
	card.description = "Steal 5 gold from an enemy."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 20
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.is_ranged = true
	card.target_types = ["enemy"]
	return card

static func create_detonova() -> Card:
	var card = Card.new()
	card.card_id = "detonova"
	card.card_name = "Detonova"
	card.description = "Purge the cuirass's stacks and deal the absorbed total as fire damage to all enemies within 2 squares of you. Does NOT scale with INT."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 60
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 2.0
	card.damage_type = DamageTypes.Type.FIRE
	card.school = CardSchool.SPELL
	card.target_types = ["self"]
	return card

static func create_mind_mend() -> Card:
	var card = Card.new()
	card.card_id = "mind_mend"
	card.card_name = "Mind Mend"
	card.description = "Restore 60 mana. Costs 15 HEALTH instead of mana."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 0
	card.health_cost = 15
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

static func create_deep_breaths() -> Card:
	var card = Card.new()
	card.card_id = "deep_breaths"
	card.card_name = "Deep Breaths"
	card.description = "Heal 20."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.heal_amount = 20
	card.target_types = ["self"]
	return card

static func create_vined_encasing() -> Card:
	var card = Card.new()
	card.card_id = "vined_encasing"
	card.card_name = "Vined Encasing"
	card.description = "Gain 1 thorn for each point of armor you currently have, for 20 tempo. You lose X thorns whenever you receive X damage."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 50
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	return card

static func create_adimantium_wall() -> Card:
	var card = Card.new()
	card.card_id = "adimantium_wall"
	card.card_name = "Adimantium Wall"
	card.description = "Gain 40 block. Jailed for 40 tempo after play."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 35
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.block = 40
	card.base_block = 40
	card.jail_on_play = 40
	card.target_types = ["self"]
	return card

static func create_preemptive_answer() -> Card:
	var card = Card.new()
	card.card_id = "preemptive_answer"
	card.card_name = "Preemptive Answer"
	card.description = "Instant: when you drop to 25% health, purge 3 debuffs and heal 20."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.reaction_trigger = "on_hp_below_25"
	card.target_types = ["self"]
	return card

static func create_ragnarok() -> Card:
	var card = Card.new()
	card.card_id = "ragnarok"
	card.card_name = "Ragnarok"
	card.description = "Release all jailed cards into your hand. For each released card: heal 10 and gain 10% crit chance and 5 STR for 10 tempo. Jailed for 30 tempo after play."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 45
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.jail_on_play = 30
	card.target_types = ["self"]
	return card

# ============================================
# RYAN NEW CARDS
# ============================================

static func create_adrenaline_shot() -> Card:
	var card = Card.new()
	card.card_id = "adrenaline_shot"
	card.card_name = "Adrenaline Shot"
	card.description = "Decrease the tempo of two cards in the target's hand by 3. In 5 tempo, increase a random card's tempo by 3 and another by 2."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 30
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.target_types = ["ally"]
	return card

static func create_patience() -> Card:
	var card = Card.new()
	card.card_id = "patience"
	card.card_name = "Patience"
	card.description = "In 15 tempo, draw 3 cards."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 20
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.delay_tempo = 15
	card.target_types = ["self"]
	return card

static func create_gargle_and_spit() -> Card:
	var card = Card.new()
	card.card_id = "gargle_and_spit"
	card.card_name = "Gargle and Spit"
	card.description = "Heal 3 and provide +1 strength. Sticky 4."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 10
	card.tempo_cost = 1
	card.damage = 0
	card.base_damage = 0
	card.block = 0
	card.base_block = 0
	card.heal_amount = 3
	card.sticky = 4
	card.target_types = ["self"]
	return card

# ============================================
# STEPHEN NEW CARDS
# ============================================

static func create_exhausted_assault() -> Card:
	var card = Card.new()
	card.card_id = "exhausted_assault"
	card.card_name = "Exhausted Assault"
	card.description = "While you have zero mana, this card costs 0 mana. Deal 4 damage 3 times. Glut 10."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 40
	card.tempo_cost = 3
	card.damage = 4
	card.base_damage = 4
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.glut_tempo = 10
	card.target_types = ["enemy"]
	return card

static func create_multishot() -> Card:
	var card = Card.new()
	card.card_id = "multishot"
	card.card_name = "Multishot"
	card.description = "Deal 7 damage 3 times, each time gaining 10% crit chance. Glut 5."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
	card.tempo_cost = 6
	card.damage = 7
	card.base_damage = 7
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.glut_tempo = 5
	card.target_types = ["enemy"]
	return card

static func create_specific_strike() -> Card:
	var card = Card.new()
	card.card_id = "specific_strike"
	card.card_name = "Specific Strike"
	card.description = "Deal 13 damage. Costs +10m/+1t for each other card in your hand."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
	card.tempo_cost = 2
	card.damage = 13
	card.base_damage = 13
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.target_types = ["enemy"]
	return card

static func create_spirit_arrow() -> Card:
	var card = Card.new()
	card.card_id = "spirit_arrow"
	card.card_name = "Spirit Arrow"
	card.description = "Deal 8 damage. Arrow shoots through all enemies and obstructions in a direct line."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 30
	card.tempo_cost = 5
	card.damage = 8
	card.base_damage = 8
	card.block = 0
	card.base_block = 0
	card.heal_amount = 0
	card.is_ranged = true
	card.is_aoe = true
	card.aoe_shape = "line"
	card.aoe_range = 100.0  # pierces the full line, not just 1.5 tiles
	card.card_keyword = CardKeyword.ARROW
	card.target_types = ["point"]
	return card

# ============================================
# ITEM-GENERATED CARDS (Bladed Doughnut)
# ============================================
# Sprinkles are conjured into the hand by the Bladed Doughnut's on-kill skill
# — they never drop, never sit in the deck, and are erased the moment they're
# played so kills don't permanently pollute the deck.

static func create_sprinkle() -> Card:
	var card = Card.new()
	card.card_id = "sprinkle"
	card.card_name = "Sprinkle"
	card.description = "Deal 25 damage. Erased after play."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 25
	card.base_damage = 25
	card.target_types = ["enemy"]
	card.erase_on_play = true
	card.shop_excluded = true
	return card

static func create_sprinkle_bomb() -> Card:
	## The Bladed Doughnut's level-3 skill: the single-target Sprinkle becomes
	## an AOE bomb.
	var card = Card.new()
	card.card_id = "sprinkle_bomb"
	card.school = CardSchool.SPELL
	card.card_name = "Sprinkle Bomb"
	card.description = "Deal 25 damage to every enemy in a 2-tile radius. Erased after play. AOE circle."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 25
	card.base_damage = 25
	card.is_ranged = true
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 2.0
	card.target_types = ["point"]
	card.erase_on_play = true
	card.shop_excluded = true
	return card

# ============================================
# ITEM-GRANTED CARDS (Wooden Sword)
# ============================================

static func create_splinter() -> Card:
	## Granted by the Wooden Sword — Olorin's teaching example for items that
	## provide cards. Travels with the sword on equip/unequip.
	var card = Card.new()
	card.card_id = "splinter"
	card.card_name = "Splinter"
	card.description = "Apply 1 Bleed: the enemy takes 1 damage per tile it moves. Range 3."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 20
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.is_ranged = true
	card.range_modifier = -2  # base 5 - 2 = range 3
	card.target_types = ["enemy"]
	return card

# ============================================
# ITEM-GRANTED CARDS (ranged pass 1)
# ============================================

static func create_improvised_ammo() -> Card:
	## Granted by the Wrist Rocket (2 copies). Playing it hits and Weakens;
	## discarding it instead pops for 4 to the nearest enemy and permanently
	## (for the battle) sharpens Improvised Ammo's crit chance.
	var card = Card.new()
	card.card_id = "improvised_ammo"
	card.card_name = "Improvised Ammo"
	card.description = "Deal 8 damage and apply 3 Weaken. If discarded: deal 4 damage to the nearest enemy and Improvised Ammo permanently gains +10% crit chance."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 45
	card.tempo_cost = 0
	card.damage = 8
	card.base_damage = 8
	card.is_ranged = true
	card.card_keyword = CardKeyword.ARROW
	card.target_types = ["enemy"]
	card.has_on_discard = true
	card.on_discard_effect = "improvised_ammo_blast"
	card.shop_excluded = true
	return card

static func create_cupids_golden_arrow() -> Card:
	## Cupids Bow. The golden arrow of Eros — the struck heart is drawn in.
	var card = Card.new()
	card.card_id = "cupids_golden_arrow"
	card.card_name = "Golden"
	card.description = "Deal 10 damage and apply 2 Vulnerable. 50% chance to taunt the enemy, forcing it toward you. An enemy carrying both the Golden and Lead marks turns into a tree for 4 tempo."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 45
	card.tempo_cost = 3
	card.damage = 10
	card.base_damage = 10
	card.is_ranged = true
	card.card_keyword = CardKeyword.ARROW
	card.target_types = ["enemy"]
	card.rng_outcomes_data = [{percent = 50.0}]
	card.shop_excluded = true
	return card

static func create_cupids_lead_arrow() -> Card:
	## Cupids Bow. The leaden arrow — the struck heart flees.
	var card = Card.new()
	card.card_id = "cupids_lead_arrow"
	card.card_name = "Lead"
	card.description = "Deal 10 damage and apply 2 Weaken. 50% chance to send the enemy fleeing away from you. An enemy carrying both the Golden and Lead marks turns into a tree for 4 tempo."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 45
	card.tempo_cost = 3
	card.damage = 10
	card.base_damage = 10
	card.is_ranged = true
	card.card_keyword = CardKeyword.ARROW
	card.target_types = ["enemy"]
	card.rng_outcomes_data = [{percent = 50.0}]
	card.shop_excluded = true
	return card

static func create_territorial_mark() -> Card:
	## Bow of Arash. The arrow's flight path stays marked in blue glistening
	## smoke; enemies standing in the mark are Weakened while inside it.
	var card = Card.new()
	card.card_id = "territorial_mark"
	card.card_name = "Territorial Mark"
	card.description = "Costs 35 health. Deal 15 damage at range 10. The arrow's path — and 2 squares either side of it — glistens with blue smoke for 25 tempo; enemies inside are Weakened until they leave."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 45
	card.health_cost = 35
	card.tempo_cost = 5
	card.damage = 15
	card.base_damage = 15
	card.is_ranged = true
	card.range_modifier = 5  # base 5 + 5 = range 10
	card.card_keyword = CardKeyword.ARROW
	card.target_types = ["enemy"]
	card.shop_excluded = true
	return card

static func create_balistic_arrow() -> Card:
	## Belthronding. Hitting an enemy does not stop this arrow — same line
	## pierce as Spirit Arrow, much heavier head.
	var card = Card.new()
	card.card_id = "balistic_arrow"
	card.card_name = "Balistic Arrow"
	card.description = "Deal 30 damage. Hitting an enemy does not stop this arrow — it pierces everything in a direct line."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 75
	card.tempo_cost = 5
	card.damage = 30
	card.base_damage = 30
	card.is_ranged = true
	card.is_aoe = true
	card.aoe_shape = "line"
	card.aoe_range = 100.0  # pierces the full line
	card.card_keyword = CardKeyword.ARROW
	card.target_types = ["point"]
	card.shop_excluded = true
	return card

static func create_close_is_favored() -> Card:
	## Conjured by Belthronding whenever a slotted card is played. Sits in the
	## hand as a trap for anything that closes the distance.
	var card = Card.new()
	card.card_id = "close_is_favored"
	card.card_name = "Close is Favored"
	card.description = "Instant: when an enemy gets within melee range, deal 13 damage to it. This card is erased."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 13
	card.base_damage = 13
	card.reaction_trigger = "on_enemy_melee_range"
	card.target_types = ["enemy"]
	card.erase_on_play = true
	card.shop_excluded = true
	return card

static func create_spirit_bow() -> Card:
	## Bow of Budding Blasts. A maintained spirit bow that fights alongside
	## you for as long as the mana stays reserved.
	var card = Card.new()
	card.card_id = "spirit_bow"
	card.card_name = "Spirit Bow"
	card.description = "Maintain: summon a spirit bow that stalks your enemies — 1 square per tempo, a 10-damage shot every 4 tempo. Lasts while the mana stays reserved."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 65
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.maintain_cost = 65  # Maintain reserve always equals the card's mana cost
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

# ============================================
# ITEM-GRANTED CARDS (rings pass 1)
# ============================================

static func create_tricks_of_alberich() -> Card:
	## Ring of Nibelung. The dwarf-king's bargain: all eyes on you, and you
	## profit from every gaze.
	var card = Card.new()
	card.card_id = "tricks_of_alberich"
	card.card_name = "Tricks of Alberich"
	card.description = "Taunt enemies in a 4-square radius. Gain 10 STR for the taunt's 5 tempo, plus 4 armor and 2 Regen per enemy taunted."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 50
	card.tempo_cost = 6
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_the_nibelung_curse() -> Card:
	## Ring of Nibelung. Five heals charge it; the card carries their summed
	## total in the "curse_value" meta — take it as healing, or give it as
	## damage. Only one may exist at a time.
	var card = Card.new()
	card.card_id = "the_nibelung_curse"
	card.card_name = "The Nibelung Curse"
	card.description = "Target yourself to take the stored healing, or an enemy to deal it as damage. Erased after use."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 70
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.is_ranged = true
	card.target_types = ["enemy", "self"]
	card.erase_on_play = true
	card.shop_excluded = true
	return card

# ============================================
# ITEM-GRANTED CARDS (shields pass 1)
# ============================================
# Every one of these arrives with its shield and leaves with it. The world-side
# payloads (Huck's armor conversion, the arrow rain, the bouncing shield) live
# in main's _apply_card_world_effects, where the grid and the enemies are.

static func create_huck() -> Card:
	## Castle wall. Throw the wall itself: everything you were hiding behind,
	## delivered at once.
	var card = Card.new()
	card.card_id = "huck"
	card.card_name = "Huck"
	card.description = "Deal damage equal to your armor, then lose all of it."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 100
	card.tempo_cost = 5
	card.damage = 0
	card.base_damage = 0
	card.is_ranged = true
	card.target_types = ["enemy"]
	card.shop_excluded = true
	return card

static func create_rain_of_arrows() -> Card:
	## Castle wall's Overdraw payload — the wall answers with its archers. Never
	## held in hand; the shield fires it off a charge.
	var card = Card.new()
	card.card_id = "rain_of_arrows"
	card.card_name = "Rain of Arrows"
	card.description = "Deal 10 damage in a 3-square radius around you."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 45
	card.tempo_cost = 0
	card.damage = 10
	card.base_damage = 10
	card.is_aoe = true
	card.aoe_shape = "circle"
	card.aoe_range = 3.0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_song_of_a_swords_sing() -> Card:
	## Sword Breaker. Catch the blade in the notches and twist: the more the
	## enemy is already suffering, the more the shield takes from it.
	var card = Card.new()
	card.card_id = "song_of_a_swords_sing"
	card.card_name = "Song of a Swords Sing"
	card.description = "Disarm the enemy for 1 attack and gain 2 armor for every KIND of debuff on it (3 burn is one kind; burn + frost + disarm is three)."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.mana_cost = 35
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.is_ranged = false
	card.target_types = ["enemy"]
	card.shop_excluded = true
	return card

static func create_curse_of_the_living() -> Card:
	## Coffin Lid. The dead share what they are given, whether or not the living
	## wanted to.
	var card = Card.new()
	card.card_id = "curse_of_the_living"
	card.card_name = "Curse of the Living"
	card.description = "Maintain: every heal you take is halved, and each ally is healed for half of what remains (rounded up)."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 65
	card.maintain_cost = 65
	card.tempo_cost = 7
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_bark_up() -> Card:
	## Treebeards Branch. The bark hardens: everything green about you turns to
	## plating.
	var card = Card.new()
	card.card_id = "bark_up"
	card.card_name = "Bark Up"
	card.description = "Convert every point of your Regen and Thorns into armor."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 45
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_cinquedea() -> Card:
	## Slotted Rope Half Sleeve. The little ox-tongue blades tucked into the
	## sleeve's loops — each one waiting there stiffens your guard.
	var card = Card.new()
	card.card_id = "cinquedea"
	card.card_name = "Cinquedea"
	card.description = "Deal 6 damage and apply 1 Weaken. Range 4."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 10
	card.tempo_cost = 0
	card.damage = 6
	card.base_damage = 6
	card.is_ranged = true
	card.range_modifier = -1  # base ranged reach is 5; this one throws 4
	card.target_types = ["enemy"]
	card.shop_excluded = true
	return card

static func create_mage_shield() -> Card:
	## Delfins Deterministic Round Shield. No dice: the block is simply there.
	var card = Card.new()
	card.card_id = "mage_shield"
	card.card_name = "Mage Shield"
	card.description = "Instant. When you take damage, gain 10 block."
	card.card_type = CardType.REACTION
	card.card_type_name = "Reaction"
	# Instants in this game fire free and are spent out of the hand — the same
	# contract as Return Cut and Hard Helmet.
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.block = 10
	card.base_block = 10
	card.target_types = ["self"]
	card.reaction_trigger = "on_damage_taken"
	card.shop_excluded = true
	return card

static func create_reverberate_regrowth() -> Card:
	## Steve Rodgers Bastion of Reverberation. The blow that cracks the guard is
	## the blow the guard remembers.
	var card = Card.new()
	card.card_id = "reverberate_regrowth"
	card.card_name = "Reverberate Regrowth"
	card.description = "Maintain: when your armor is broken through, the armor that hit ate comes back 5 tempo later."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 55
	card.maintain_cost = 55
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_bouncing_shield() -> Card:
	## Steve Rodgers Bastion of Reverberation. It comes back. It always comes
	## back — and it brings something with it from every body it touched.
	var card = Card.new()
	card.card_id = "bouncing_shield"
	card.card_name = "Bouncing Shield"
	card.description = "Throw the shield: 5 damage to each enemy it bounces through (up to 5, each within 5 squares of the last). Every target hit returns 5 block and 10 temporary mana that may sit above your maximum, for 15 tempo. You lose half your armor while it flies."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.mana_cost = 55
	card.tempo_cost = 4
	card.damage = 5
	card.base_damage = 5
	card.is_ranged = true
	card.target_types = ["enemy"]
	card.shop_excluded = true
	return card

static func create_mind_over_matter() -> Card:
	## Presence of Mind. Meet the blow with the mind instead of the body.
	var card = Card.new()
	card.card_id = "mind_over_matter"
	card.card_name = "Mind over Matter"
	card.description = "The next hit you take is halved, and what is left is paid out of your mana instead of your health."
	card.card_type = CardType.DEFENSE
	card.card_type_name = "Defense"
	card.mana_cost = 20
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

# ============================================
# SPELL-WEAPON-GRANTED CARDS (spell weapons pass 1)
# ============================================

static func create_element_pollination() -> Card:
	## Elemental Weaver maintain: cross-pollinates the three weather elements.
	var card = Card.new()
	card.card_id = "element_pollination"
	card.card_name = "Element Pollination"
	card.description = "Maintain: your Burn also splashes nearby enemies like Shock, your Shock freezes at 5 stacks like Cold, and your Cold ticks doubling damage like Burn — on top of their normal effects."
	card.card_type = CardType.POWER
	card.card_type_name = "Power"
	card.mana_cost = 60
	card.maintain_cost = 60
	card.tempo_cost = 3
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_from_the_ashes() -> Card:
	## Wand of the Phoenix Feather: purge every self-Burn and turn it outward.
	## Lv.3 heals x8 and regens 3/4 — read live off granted_by_item in main.
	var card = Card.new()
	card.card_id = "from_the_ashes"
	card.card_name = "From the Ashes"
	card.description = "Purge ALL your Burn: enemies within 3 squares take 5 damage per stack purged; heal 5 per stack and gain Regen equal to half the stacks."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.school = CardSchool.SPELL
	card.mana_cost = 80
	card.tempo_cost = 2
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_polymorph() -> Card:
	## Circe's Wand instant: the 5th distinct debuff makes the enemy a pig.
	## Jailed 25 tempo after it fires (handled at the trigger site) — the
	## cauldron needs restirring between transformations.
	var card = Card.new()
	card.card_id = "polymorph"
	card.card_name = "Polymorph"
	card.description = "Instant: when you land a 5th distinct debuff on an enemy, they become a pig for 5 tempo — able only to walk and make basic melee attacks. Jailed 25 tempo after it fires."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.school = CardSchool.SPELL
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.jail_on_play = 25
	card.reaction_trigger = "on_enemy_fifth_debuff"
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_clear_mind() -> Card:
	## Wand of Clarity: shed what clouds you and read clearly again.
	var card = Card.new()
	card.card_id = "clear_mind"
	card.card_name = "Clear Mind"
	card.description = "Purge 3 random debuffs on you — whole stacks — and draw 1 card for each debuff purged."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.school = CardSchool.SPELL
	card.mana_cost = 50
	card.tempo_cost = 4
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_grounding() -> Card:
	## Reaction Rod: earth the whole field through the wielder. The -5 mana per
	## absorbable Shock is kept live on the card by main each tempo tick and
	## read at cost time in DeckManager.play_card.
	var card = Card.new()
	card.card_id = "grounding"
	card.card_name = "Grounding"
	card.description = "Absorb every Shock within 10 squares of you — enemies, allies and yourself — and deal 10 damage to each enemy in that radius, shocked or not. Costs 5 less mana per Shock absorbed."
	card.card_type = CardType.ATTACK
	card.card_type_name = "Attack"
	card.school = CardSchool.SPELL
	card.mana_cost = 200
	card.tempo_cost = 10
	card.damage = 0
	card.base_damage = 0
	card.is_ranged = true
	card.is_aoe = true
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_defensive_sacrifice() -> Card:
	## Abjurers Cane: an instant with a CHOICE — main prompts the wielder when
	## an enemy attack lands; declining leaves the card in hand unspent.
	var card = Card.new()
	card.card_id = "defensive_sacrifice"
	card.card_name = "Defensive Sacrifice"
	card.description = "Instant: when an enemy attack lands on you, you may discard a card of your choice — if you do, halve the damage and gain 10 mana. Decline and this card stays in your hand."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.reaction_trigger = "on_player_attacked_choice"
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_crops() -> Card:
	## Shepherds Crook: sow the field with berries for the flock.
	var card = Card.new()
	card.card_id = "crops"
	card.card_name = "Crops"
	card.description = "Grow 5 berry bushels at random within 8 squares of you. An ally who walks over one eats it for 20 life and 20 mana."
	card.card_type = CardType.UTILITY
	card.card_type_name = "Utility"
	card.school = CardSchool.SPELL
	card.mana_cost = 70
	card.tempo_cost = 7
	card.damage = 0
	card.base_damage = 0
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

static func create_reapers_taking() -> Card:
	## Reaper Scythe instant: an enemy dropping below a quarter within 5
	## squares pulls the reaper to them. Lv.3 deals 35 — read live off
	## granted_by_item at the trigger site in main.
	var card = Card.new()
	card.card_id = "reapers_taking"
	card.card_name = "Reaper's Taking"
	card.description = "Instant: when an enemy within 5 squares drops below 25% health, teleport to them and deal 20 damage."
	card.card_type = CardType.REACTION
	card.card_type_name = "Instant"
	card.school = CardSchool.SPELL
	card.mana_cost = 0
	card.tempo_cost = 0
	card.damage = 0
	card.base_damage = 0
	card.reaction_trigger = "on_enemy_low_health_nearby"
	card.target_types = ["self"]
	card.shop_excluded = true
	return card

# ============================================
# RARITY HELPERS
# ============================================

static var _factory_map: Dictionary = {}  # card_id -> factory method name

# Feral Evocation: while a converted card's play resolves, any Burn/Cold/
# Shock/Poison it lands on an enemy is swapped to this element's debuff
# ("" = off). Main sets it around the play; Enemy.apply_debuff reads it.
static var active_element_remap: String = ""
# Element Pollination (Elemental Weaver maintain): recomputed by main every
# tempo tick off the maintained pile; enemies read it during debuff ticking.
static var element_pollination_active: bool = false

# The colored-slot element table shared by Feral Evocation's engine.
const ELEMENT_DEBUFFS := {"red": "burn", "blue": "cold", "yellow": "shock", "green": "poison"}

func get_rarity() -> Rarity:
	return CARD_RARITIES.get(card_id, Rarity.COMMON)

func get_rarity_name() -> String:
	match get_rarity():
		Rarity.BASIC: return "Basic"
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.LEGENDARY: return "Legendary"
		Rarity.MYTHIC: return "Mythic"
	return "Unknown"

## Card ids of the given rarity that are allowed in random drops.
static func get_droppable_ids_of_rarity(r: Rarity) -> Array:
	var ids: Array = []
	for cid in CARD_RARITIES:
		if CARD_RARITIES[cid] == r and not DROP_EXCLUDED_CARD_IDS.has(cid):
			ids.append(cid)
	return ids

## Create a fresh card by id via the create_* factories (cached discovery).
static func create_by_id(cid: String) -> Card:
	if _factory_map.is_empty():
		var script: Script = Card
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			# Factories with only DEFAULTED args count too (rank-scaled conjured
			# cards like energy_barrier) — they rebuild at their default values.
			if method_name.begins_with("create_") \
					and method["args"].size() - method["default_args"].size() == 0:
				var card = script.call(method_name)
				if card is Card:
					_factory_map[card.card_id] = method_name
	if cid in _factory_map:
		return (Card as Script).call(_factory_map[cid])
	return null
