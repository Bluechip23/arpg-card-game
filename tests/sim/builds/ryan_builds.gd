class_name RyanBuilds
extends RefCounted

## Ryan's build library for the simulation harness: named components (item
## sets, decks, stat allocation weights, sphere-grid targets, passive rank
## weights, slotted cards) and the designed builds that combine them.
## CharacterBuilds.compose("ryan", parts) turns any mix of them into a
## scenario at any level (tools/sim_analysis/gen_build_sweeps.py drives the
## mix-and-match sweeps). Mythic and legendary gear only; Ryan has 2 belt
## slots, 2 rings, a main hand (0) and an off hand (1), and belt cards cost
## him 10 less.

const DEFAULT_ENEMY := "LARGE_BEAR"

## Gear per archetype: [item id, slot] or [mythic id, slot, legendary
## fallback]. The game allows one equipped mythic per 15 levels, so the
## composer keeps the mythics in listed order up to the level's cap and
## wears the fallback for the rest (level 18: the first; 30: two; 45+:
## three). Bows are two-handed and take only a quiver in the off hand;
## staffs are two-handed. Weight is checked by the inventory at build time
## (carry = 50 + 10 per STR); a refused piece is a warning in the summary.
const ITEM_SETS := {
	# Mythic: Sabre Tooth. Dual daggers, light cloth, stealth belts.
	"shadow_blade": [["sabre_tooth", 0], ["nine_ruins_of_sanguine", 1], ["feathered_hat", 0],
		["shadow_cowl", 0], ["shadow_obi", 0], ["assasian_belt", 1], ["houdinis_slippers", 0],
		["concealed_carry", 0, "momentum_mits"], ["the_precious", 0, "legend_has_it"], ["marvolo_gaunt", 1]],
	# Mythic: Hannibal's Mask. Wands, potion belts, healer's gloves.
	"apothecary": [["hannibals_mask", 0], ["wand_of_clarity", 0], ["circes_wand_of_cauldron_stirring", 1, "reaction_rod"],
		["shadow_cowl", 0], ["alchemeist_belt", 0], ["corset_of_cure", 1], ["cyde_livingstons_sneakers", 0],
		["techno_wraps", 0], ["ring_of_nibelung", 0, "harnessed_sun"], ["marvolo_gaunt", 1]],
	# Mythic: The Headbandz (5 slots). Every slot the gear offers, filled.
	"card_shark": [["the_headbandz", 0], ["sword_of_theseus", 0, "wrist_rocket"], ["slotted_rope_half_sleeve", 1],
		["shadow_cowl", 0], ["the_slotted_sash", 0], ["belt_of_wumbology", 1], ["hermes_boots", 0, "boot_holsters"],
		["spidey_web_shooters", 0], ["legend_has_it", 0], ["cyclops_ring", 1]],
	# Mythic: Bow of Arash. Bow + quiver, range gear, light feet.
	"ranged_ambusher": [["bow_of_arash", 0], ["capacious_extremus", 1], ["monocle", 0],
		["chewbaccas_bandolier", 0], ["orions_belt", 0, "equator"], ["shadow_obi", 1], ["jordan_1s", 0, "rollerblades"],
		["momentum_mits", 0], ["captain_planets_circlet", 0], ["harnessed_sun", 1]],
	# Mythic: Sword of Theseus (5 slots). Sword and board, plate, heavy boots.
	"bruiser": [["sword_of_theseus", 0], ["steve_rodgers_bastion", 1, "sword_breaker"], ["dragon_skull", 0],
		["hide_of_garmr", 0, "smithed_excellence"], ["equator", 0], ["belt_of_wumbology", 1], ["titanium_toe_tuckers", 0],
		["sleeved_katar", 0], ["ring_of_stone_hide", 0], ["marvolo_gaunt", 1]],
	# Mythic: Belt of Scrolls (three spells). Wands, robe, caster gloves.
	"spellslinger": [["belt_of_scrolls", 0], ["wand_of_the_phoenix_feather", 0, "wand_of_clarity"], ["reaction_rod", 1],
		["scholars_cap", 0, "feathered_hat"], ["blue_robe", 0], ["corset_of_cure", 1], ["rollerblades", 0],
		["techno_wraps", 0], ["harnessed_sun", 0], ["legend_has_it", 1]],
}

## Cards engraved into an item set's slots, by item id. Slot labels are the
## game's (a helm takes Crown cards, a belt Pocket, boots Swift, gauntlets
## Fist, a sword Sword cards, a dagger Dagger, a shield Buckler, a chest
## Bulwark, a quiver or bow Arrow); a mismatch is a warning.
const SLOTTED := {
	"shadow_blade": {
		"sabre_tooth": ["exposed_artery"],
		"feathered_hat": ["provider", "armor_patch"],
		"shadow_cowl": ["approach", "armor_patch", "turtle_up", "roar"],
		"shadow_obi": ["shuriken", "poke"],
		"assasian_belt": ["volatile_mixture"],
		"houdinis_slippers": ["blink"],
		"momentum_mits": ["push"],
	},
	"apothecary": {
		"circes_wand_of_cauldron_stirring": ["the_lights_favor"],
		"wand_of_clarity": ["the_lights_favor"],
		"hannibals_mask": ["provider", "armor_patch"],
		"shadow_cowl": ["approach", "armor_patch", "turtle_up", "roar"],
		"alchemeist_belt": ["poison_bomb", "poisoned_blood", "potion_of_continuance"],
		"corset_of_cure": ["healing_potion", "gulped_potion", "elixir"],
	},
	"card_shark": {
		"wrist_rocket": ["savage_strike"],
		"sword_of_theseus": ["savage_strike", "specific_strike", "life_steal", "parry", "reckless_strike"],
		"hermes_boots": ["blink", "reposition", "bob_and_weave", "swap"],
		"slotted_rope_half_sleeve": ["repelled_block", "forever_armor"],
		"the_headbandz": ["armor_patch", "provider", "barbed_exterior", "snowballs_chance", "forever_armor"],
		"shadow_cowl": ["approach", "armor_patch", "turtle_up", "roar"],
		"the_slotted_sash": ["dagger_throw", "volatile_mixture", "shuriken", "poke", "healing_potion", "discard"],
		"belt_of_wumbology": ["thrown_stone", "quick_shot"],
		"boot_holsters": ["blink", "reposition", "bob_and_weave"],
		"spidey_web_shooters": ["push", "consecutive_snap"],
	},
	"ranged_ambusher": {
		"bow_of_arash": ["multishot", "spirit_arrow", "trick_shot"],
		"capacious_extremus": ["quick_shot", "mixed_bag", "shuriken", "lead_arrow"],
		"monocle": ["provider"],
		"chewbaccas_bandolier": ["approach", "armor_patch"],
		"equator": ["shuriken", "poke"],
		"orions_belt": [],
		"shadow_obi": ["thrown_stone", "poke"],
		"rollerblades": ["blink"],
		"momentum_mits": ["push"],
	},
	"bruiser": {
		"sword_of_theseus": ["savage_strike", "specific_strike", "life_steal", "parry", "reckless_strike"],
		"sword_breaker": ["repelled_block", "hunker_down", "forever_armor"],
		"dragon_skull": ["provider", "armor_patch"],
		"smithed_excellence": ["harden", "best_offense", "smith_thy_soul"],
		"hide_of_garmr": [],
		"steve_rodgers_bastion": [],
		"equator": ["shuriken", "poke"],
		"belt_of_wumbology": ["healing_potion", "discard"],
		"titanium_toe_tuckers": ["reposition", "swap"],
		"sleeved_katar": ["push"],
	},
	"spellslinger": {
		"wand_of_clarity": ["the_lights_favor"],
		"wand_of_the_phoenix_feather": ["the_lights_favor", "provider"],
		"scholars_cap": ["provider", "snowballs_chance"],
		"feathered_hat": ["provider", "snowballs_chance"],
		"blue_robe": ["approach", "hold_the_line"],
		"corset_of_cure": ["healing_tonic", "healing_potion", "gulped_potion"],
		"rollerblades": ["blink"],
	},
}

## The 12-card base decks (item-owned cards ride on top).
const DECKS := {
	"daggers": ["dagger_throw", "dagger_throw", "dagger_throw", "slice", "slice", "savage_strike",
		"savage_strike", "specific_strike", "consecutive_snap", "splinter", "discard", "block"],
	"potions": ["healing_potion", "healing_potion", "gulped_potion", "poison_bomb", "poison_bomb",
		"poisoned_blood", "elixir", "potion_of_continuance", "potion_of_continuance", "slash", "slash", "block"],
	"discard_engine": ["discard", "discard", "reposition", "reposition", "volatile_mixture", "volatile_mixture",
		"exacerbate_wounds", "exacerbate_wounds", "meister_of_faustmesser", "armor_patch", "armor_patch", "slice"],
	"shadow": ["shadows", "blink", "dagger_throw", "dagger_throw", "slice", "slice", "savage_strike",
		"block", "block", "draw", "heal", "slash"],
	"arrows": ["quick_shot", "quick_shot", "mixed_bag", "mixed_bag", "lead_arrow", "trick_shot",
		"spirit_arrow", "multishot", "reload", "thrown_stone", "block", "draw"],
	"blades": ["savage_strike", "savage_strike", "specific_strike", "specific_strike", "slice", "slice",
		"parry", "life_steal", "reckless_strike", "block", "block", "heal"],
	"starter": ["slash", "slash", "slash", "block", "block", "block", "draw", "draw", "gain_mana", "heal"],
}

## Allocation WEIGHTS, spread over the level's points (3 a level: 51 at 18,
## 147 at 50). Carry capacity is 50 + 10 per STR, so even the casters keep
## a share in STR or they cannot wear their gear.
const ALLOCS := {
	"dex_agi": {"dexterity": 25, "agility": 20, "strength": 6},
	"wis_int": {"wisdom": 18, "intelligence": 15, "dexterity": 12, "strength": 6},
	"dex_wis": {"dexterity": 18, "agility": 12, "wisdom": 15, "strength": 6},
	"str_det": {"strength": 30, "determination": 15, "agility": 6},
	"int_wis": {"intelligence": 27, "wisdom": 18, "strength": 6},
	"even": {"strength": 1, "dexterity": 1, "intelligence": 1, "wisdom": 1, "agility": 1, "determination": 1},
}

## Sphere-grid targets (node ids; the runner lights the shortest gated path
## to each). Keystones: 106 Flurry Form, 127 Killing Rhythm, 118 Flash Cut,
## 89 Deadeye Form, 82 Crit +1% (DEX 20), 114 Tactician's Eye (WIS 15), 112 Quick Study,
## 107 Arcane Ward, 110 Arcane Echo, 85 Bulwark Soul, 128 Unbroken Will,
## 103 Weighted Strikes. At most three keystones light.
const SPHERES := {
	"flurry": [106, 127, 118],
	"deadeye": [89, 82, 118],
	"sage": [112, 114, 107],
	"arcane": [110, 107, 112],
	"bulwark": [85, 128, 103],
	"none": [],
}

## Passive rank WEIGHTS, spread over the level's passive points (1 a level,
## ranks capped at 15) and spent through the real allocator.
const PASSIVES := {
	"shadow": {"now_you_see_me": 3, "surprise_opener": 4, "eye_scrape": 2, "quick_step": 3,
		"ladder_work": 2, "keep_them_guessing": 2, "let's_dance": 1},
	"apothecary": {"stimulant": 4, "pop_rocks": 4, "mad_scientist": 4, "quick_step": 2,
		"keep_them_guessing": 1, "from_the_hip": 1, "nimble_assault": 1},
	"relentless": {"keep_them_guessing": 4, "from_the_hip": 4, "nimble_assault": 4, "ladder_work": 2,
		"surprise_opener": 2, "quick_step": 1},
	"light_foot": {"quick_step": 4, "ladder_work": 4, "let's_dance": 4, "now_you_see_me": 2,
		"surprise_opener": 2, "keep_them_guessing": 1},
	"none": {},
}

## The designed builds: each archetype with its own gear, deck, stats,
## sphere path and passives. The mismatch sweeps start from these.
const DESIGNED := {
	"shadow_blade":    {"items": "shadow_blade", "deck": "shadow", "alloc": "dex_agi", "sphere": "flurry", "passives": "shadow"},
	"apothecary":      {"items": "apothecary", "deck": "potions", "alloc": "wis_int", "sphere": "sage", "passives": "apothecary"},
	"card_shark":      {"items": "card_shark", "deck": "discard_engine", "alloc": "dex_wis", "sphere": "deadeye", "passives": "relentless"},
	"ranged_ambusher": {"items": "ranged_ambusher", "deck": "arrows", "alloc": "dex_agi", "sphere": "deadeye", "passives": "light_foot"},
	"bruiser":         {"items": "bruiser", "deck": "blades", "alloc": "str_det", "sphere": "bulwark", "passives": "relentless"},
	"spellslinger":    {"items": "spellslinger", "deck": "potions", "alloc": "int_wis", "sphere": "arcane", "passives": "apothecary"},
}

static func components() -> Dictionary:
	return CharacterBuilds.components("ryan")

static func compose(parts: Dictionary) -> Dictionary:
	return CharacterBuilds.compose("ryan", parts)
