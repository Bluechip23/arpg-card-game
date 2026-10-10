class_name StephenBuilds
extends RefCounted

## Stephen's build library (CharacterBuilds.compose("stephen", parts)):
## the designer's loadouts from tests/_build_sims.gd with placeholder
## decks. Fill in the components, keep the shape.

const DEFAULT_ENEMY := "LARGE_BEAR"

const ITEM_SETS := {
	"longshot_ranger": [["jordan_1s", 0, "rollerblades"], ["chewbaccas_bandolier", 0], ["monocle", 0], ["holster", 0],
		["fanned_bracers", 0], ["stringless_sender", 0], ["capacious_extremus", 1]],
	"heavy_swing": [["hide_of_garmr", 0, "smithed_excellence"], ["dragon_skull", 0], ["equator", 0], ["mountain_boots", 0],
		["sleeved_katar", 0], ["fallens_wrath", 0], ["sword_breaker", 1]],
	"sentinel_duelist": [["hallowed_trunk", 0, "spiked_mitts"], ["smithed_excellence", 0], ["burgonet", 0], ["strap_of_stone", 0],
		["chain_crocs", 0], ["fallens_wrath", 0], ["sword_breaker", 1]],
	"crooked_duelist": [["rusty_dagger", 0], ["crooked_dueling_shield", 1, "sword_breaker"], ["shadow_cowl", 0],
		["feathered_hat", 0], ["knife_toed_boots", 0]],
}
const SLOTTED := {
	"longshot_ranger": {"capacious_extremus": ["quick_shot", "mixed_bag", "lead_arrow", "multishot"], "stringless_sender": ["spirit_arrow", "trick_shot"], "chewbaccas_bandolier": ["approach", "armor_patch"]},
	"heavy_swing": {"fallens_wrath": ["savage_strike", "reckless_strike"], "sword_breaker": ["repelled_block", "forever_armor", "hunker_down"], "smithed_excellence": ["harden", "best_offense", "smith_thy_soul"]},
	"sentinel_duelist": {"fallens_wrath": ["parry", "specific_strike"], "sword_breaker": ["repelled_block", "forever_armor", "hunker_down"], "smithed_excellence": ["harden", "best_offense", "smith_thy_soul"]},
	"crooked_duelist": {"shadow_cowl": ["approach", "armor_patch", "turtle_up", "roar"], "feathered_hat": ["provider", "armor_patch"]},
}
const DECKS := {
	"starter": ["slash", "slash", "slash", "block", "block", "block", "draw", "draw", "gain_mana", "heal"],
	"arrows": ["quick_shot", "quick_shot", "mixed_bag", "mixed_bag", "lead_arrow", "trick_shot",
		"spirit_arrow", "multishot", "reload", "thrown_stone", "block", "draw"],
	"blades": ["savage_strike", "savage_strike", "specific_strike", "specific_strike", "slice", "slice",
		"parry", "life_steal", "reckless_strike", "block", "block", "heal"],
}
const ALLOCS := {
	"dex_agi": {"dexterity": 30, "agility": 15, "strength": 6},
	"str_dex_det": {"strength": 27, "dexterity": 12, "determination": 12},
	"str_dex_wis": {"strength": 20, "dexterity": 16, "wisdom": 15},
	"even": {"strength": 1, "dexterity": 1, "intelligence": 1, "wisdom": 1, "agility": 1, "determination": 1},
}
const SPHERES := {
	"deadeye": [89, 82, 118],
	"flurry": [106, 127, 118],
	"bulwark": [85, 128, 103],
	"weighted": [103],
	"none": [],
}
const PASSIVES := {
	"ranger": {"eagle_eye": 3, "scouted": 3, "laced_arrow": 2, "deadly": 3, "clean_exchange": 2, "skilled_momentum": 2, "dominate": 2},
	"avenger": {"swing_for_the_fences": 3, "patience_is_a_virtue": 3, "dominate": 2, "skilled_momentum": 2, "deadly": 3, "clean_exchange": 2, "lethal_resourcefulness": 2},
	"sentinel": {"clean_exchange": 3, "exposed_blind_spot": 3, "lethal_resourcefulness": 2, "deadly": 3, "patience_is_a_virtue": 2, "swing_for_the_fences": 2, "scouted": 2},
	"none": {},
}
const DESIGNED := {
	"longshot_ranger":  {"items": "longshot_ranger", "deck": "arrows", "alloc": "dex_agi", "sphere": "deadeye", "passives": "ranger"},
	"heavy_swing":      {"items": "heavy_swing", "deck": "blades", "alloc": "str_dex_det", "sphere": "bulwark", "passives": "avenger"},
	"sentinel_duelist": {"items": "sentinel_duelist", "deck": "blades", "alloc": "str_dex_wis", "sphere": "weighted", "passives": "sentinel"},
	"crooked_duelist":  {"items": "crooked_duelist", "deck": "blades", "alloc": "dex_agi", "sphere": "flurry", "passives": "ranger"},
}
