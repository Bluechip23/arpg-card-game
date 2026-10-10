class_name JeremyBuilds
extends RefCounted

## Jeremy's build library (CharacterBuilds.compose("jeremy", parts)):
## the designer's loadouts from tests/_build_sims.gd with placeholder
## decks. Fill in the components, keep the shape.

const DEFAULT_ENEMY := "LARGE_BEAR"

const ITEM_SETS := {
	"scroll_evoker": [["belt_of_scrolls", 0], ["blue_robe", 0], ["wizard_hat", 0], ["caster_boots", 0], ["techno_wraps", 0],
		["wand_of_clarity", 0], ["reaction_rod", 1]],
	"shepherd": [["guardian_greaves", 0, "caster_boots"], ["blue_robe", 0], ["shamans_mask", 0],
		["corset_of_cure", 0], ["medic_wraps", 0], ["wand_of_clarity", 0], ["coffin_lid", 1]],
	"presence_of_mind": [["presence_of_mind", 1, "coffin_lid"], ["blue_robe", 0], ["wizard_hat", 0], ["caster_boots", 0],
		["techno_wraps", 0], ["wand_of_clarity", 0]],
}
const SLOTTED := {
	"scroll_evoker": {"blue_robe": ["approach", "armor_patch"]},
	"shepherd": {"corset_of_cure": ["healing_potion", "gulped_potion", "elixir"], "blue_robe": ["approach", "armor_patch"]},
	"presence_of_mind": {"blue_robe": ["approach", "armor_patch"]},
}
const DECKS := {
	"starter": ["slash", "slash", "slash", "block", "block", "block", "draw", "draw", "gain_mana", "heal"],
	"spells": ["fireball", "fireball", "mana_surge", "mana_surge", "magic_barrier", "magic_barrier",
		"heal", "heal", "gain_mana", "gain_mana", "draw", "block"],
}
const ALLOCS := {
	"int_wis": {"intelligence": 27, "wisdom": 18, "strength": 6},
	"wis_int_det": {"wisdom": 21, "intelligence": 15, "determination": 9, "strength": 6},
	"even": {"strength": 1, "dexterity": 1, "intelligence": 1, "wisdom": 1, "agility": 1, "determination": 1},
}
const SPHERES := {
	"arcane": [110, 107, 112],
	"sage": [112, 114, 107],
	"none": [],
}
const PASSIVES := {
	"evoker": {"arcane_overflow": 3, "harnessed_power": 3, "mana_surge": 3, "tricks_of_death": 2,
		"seance": 2, "a_mages_favor": 2, "fresh_start": 2},
	"shepherd": {"i_heal_you": 3, "whispers_of_the_flock": 3, "blood_libation": 3, "fresh_start": 2,
		"a_mages_favor": 2, "kinetic_armor": 2, "tricks_of_death": 2},
	"none": {},
}
const DESIGNED := {
	"scroll_evoker":    {"items": "scroll_evoker", "deck": "spells", "alloc": "int_wis", "sphere": "arcane", "passives": "evoker"},
	"shepherd":         {"items": "shepherd", "deck": "spells", "alloc": "wis_int_det", "sphere": "sage", "passives": "shepherd"},
	"presence_of_mind": {"items": "presence_of_mind", "deck": "spells", "alloc": "int_wis", "sphere": "arcane", "passives": "evoker"},
}
