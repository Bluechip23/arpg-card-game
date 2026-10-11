class_name CoryBuilds
extends RefCounted

## Cory's build library (CharacterBuilds.compose("cory", parts)): the
## designer's loadouts from tests/_build_sims.gd with placeholder decks.
## Fill in the components, keep the shape.

const DEFAULT_ENEMY := "LARGE_BEAR"

const ITEM_SETS := {
	"withering_lurker": [["hannibals_mask", 0, "feathered_hat"], ["gravity_gauntlets", 0], ["spidey_web_shooters", 1],
		["blue_robe", 0], ["belt_of_wumbology", 0], ["knife_toed_boots", 0], ["wand_of_clarity", 0], ["reaction_rod", 1]],
	"overcharged_monk": [["cuffs_of_current", 0, "techno_wraps"], ["copper_bracers", 1], ["suit_and_tie", 0],
		["wizard_hat", 0], ["potion_belt", 0], ["cloth_slippers", 0], ["wand_of_clarity", 0]],
	"attrition_grove": [["briarhide_plate", 0], ["hallowed_trunk", 0, "spiked_mitts"], ["spiked_mitts", 1],
		["strap_of_stone", 0], ["thick_steel_helm", 0], ["steel_boots", 0], ["treebeards_branch", 1], ["short_sword", 0]],
}
const SLOTTED := {
	"withering_lurker": {"blue_robe": ["approach", "armor_patch"], "belt_of_wumbology": ["healing_potion", "discard"]},
	"overcharged_monk": {},
	"attrition_grove": {"treebeards_branch": ["repelled_block", "hunker_down"]},
}
const DECKS := {
	"starter": ["slash", "slash", "slash", "block", "block", "block", "draw", "draw", "gain_mana", "heal"],
	"debuffer": ["splinter", "splinter", "wear_down", "wear_down", "poison_bomb", "poison_bomb",
		"slash", "slash", "block", "block", "heal", "draw"],
}
const ALLOCS := {
	"dex_int_agi": {"dexterity": 18, "intelligence": 18, "agility": 15},
	"wis_int_agi": {"wisdom": 18, "intelligence": 21, "agility": 12},
	"str_det": {"strength": 43, "determination": 8},
	"even": {"strength": 1, "dexterity": 1, "intelligence": 1, "wisdom": 1, "agility": 1, "determination": 1},
}
const SPHERES := {
	"arcane": [110, 107],          # Arcane Echo + Arcane Ward (INT 15)
	"weighted": [103],
	"bulwark": [85, 128, 103],
	"none": [],
}
const PASSIVES := {
	"lurker": {"wither": 3, "territorial_death": 3, "death_as_lifeblood": 2, "prey_on_the_weak": 3, "eat": 2, "serial_killer": 2, "budding": 2},
	"monk": {"energy_barrier": 3, "self_reliance": 3, "expel_negativity": 2, "budding": 2, "circle_of_life": 3, "regrowth": 2, "death_as_lifeblood": 2},
	"grove": {"wither": 2, "territorial_death": 2, "death_as_lifeblood": 3, "expel_negativity": 2, "budding": 3, "circle_of_life": 3, "eat": 2},
	"none": {},
}
const DESIGNED := {
	"withering_lurker": {"items": "withering_lurker", "deck": "debuffer", "alloc": "dex_int_agi", "sphere": "arcane", "passives": "lurker"},
	"overcharged_monk": {"items": "overcharged_monk", "deck": "starter", "alloc": "wis_int_agi", "sphere": "arcane", "passives": "monk"},
	"attrition_grove":  {"items": "attrition_grove", "deck": "starter", "alloc": "str_det", "sphere": "weighted", "passives": "grove"},
}
