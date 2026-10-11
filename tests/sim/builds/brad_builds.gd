class_name BradBuilds
extends RefCounted

## Brad's build library (CharacterBuilds.compose("brad", parts)). The
## designed builds are the designer's loadouts from tests/_build_sims.gd;
## the decks are placeholders (the starter deck plus a sword/shield deck)
## until Brad gets the same authoring pass Ryan had. Fill in the
## components, keep the shape.

const DEFAULT_ENEMY := "LARGE_BEAR"

const ITEM_SETS := {
	"immovable_warden": [["adimantium", 0, "steel_plate"], ["thick_steel_helm", 0], ["strap_of_stone", 0],
		["steel_boots", 0], ["copper_bracers", 0], ["short_sword", 0], ["castle_wall", 1]],
	"deathwish_berserker": [["hide_of_garmr", 0, "smithed_excellence"], ["hallowed_trunk", 0, "spiked_mitts"],
		["dragon_skull", 0], ["equator", 0], ["knife_toed_boots", 0], ["fallens_wrath", 0], ["sword_breaker", 1]],
	"castle_wall": [["short_sword", 0], ["castle_wall", 1], ["steel_plate", 0], ["thick_steel_helm", 0], ["steel_boots", 0]],
	"buckler_vanguard": [["buckler", 0], ["vanguard", 1], ["steel_plate", 0], ["thick_steel_helm", 0], ["steel_boots", 0]],
}
const SLOTTED := {
	"immovable_warden": {"castle_wall": ["repelled_block", "hunker_down"], "adimantium": ["approach", "hold_the_line"]},
	"deathwish_berserker": {"fallens_wrath": ["savage_strike", "reckless_strike"], "sword_breaker": ["repelled_block", "forever_armor", "hunker_down"]},
	"castle_wall": {"castle_wall": ["repelled_block", "hunker_down"]},
	"buckler_vanguard": {},
}
const DECKS := {
	"starter": ["slash", "slash", "slash", "block", "block", "block", "draw", "draw", "gain_mana", "heal"],
	"sword_and_board": ["savage_strike", "savage_strike", "specific_strike", "slice", "slice", "parry",
		"block", "block", "turtle_up", "hold_the_line", "heal", "draw"],
}
const ALLOCS := {
	"str_det": {"strength": 34, "determination": 9, "wisdom": 8},
	"str_agi": {"strength": 30, "determination": 15, "agility": 6},
	"even": {"strength": 1, "dexterity": 1, "intelligence": 1, "wisdom": 1, "agility": 1, "determination": 1},
}
const SPHERES := {
	"bulwark": [85, 103],          # Bulwark Soul (DET 12) + Weighted Strikes (STR 15)
	"iron_will": [85, 128, 103],   # needs DET 15: the berserker's spread
	"none": [],
}
const PASSIVES := {
	"warden": {"in_the_trenches": 3, "the_way_of_the_plate": 3, "pristine_armor": 3, "stone_skin": 2,
		"ancestral_aid": 2, "vines_codependence": 2, "solemn_independence": 2},
	"berserker": {"enraged_will": 3, "directed_strength": 3, "life_steal": 3, "point_to_prove": 2,
		"redemption": 2, "stone_skin": 2, "vines_codependence": 2},
	"none": {},
}
const DESIGNED := {
	"immovable_warden":    {"items": "immovable_warden", "deck": "sword_and_board", "alloc": "str_det", "sphere": "bulwark", "passives": "warden"},
	"deathwish_berserker": {"items": "deathwish_berserker", "deck": "sword_and_board", "alloc": "str_agi", "sphere": "iron_will", "passives": "berserker"},
	"castle_wall":         {"items": "castle_wall", "deck": "sword_and_board", "alloc": "str_det", "sphere": "bulwark", "passives": "warden"},
	"buckler_vanguard":    {"items": "buckler_vanguard", "deck": "starter", "alloc": "str_agi", "sphere": "none", "passives": "warden"},
}
