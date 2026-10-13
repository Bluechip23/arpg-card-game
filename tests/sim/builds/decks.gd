class_name SimDecks
extends RefCounted

## The one deck library every character draws from (cards are universal:
## only a passive that names a card ties it to a character). Any build of
## any character loads any of these with `deck:<name>`; a new deck written
## here is available to all five at once. Base decks only: item-owned and
## engraved cards ride on top, and tactics, recipes and `swap:` rewrite a
## copy, never these lists.

const DECKS := {
	"starter": ["slash", "slash", "slash", "block", "block", "block", "draw", "draw", "gain_mana", "heal"],
	# Blades and steel.
	"daggers": ["dagger_throw", "dagger_throw", "dagger_throw", "slice", "slice", "savage_strike",
		"savage_strike", "specific_strike", "consecutive_snap", "splinter", "discard", "block"],
	"blades": ["savage_strike", "savage_strike", "specific_strike", "specific_strike", "slice", "slice",
		"parry", "life_steal", "reckless_strike", "block", "block", "heal"],
	"sword_and_board": ["savage_strike", "savage_strike", "specific_strike", "slice", "slice", "parry",
		"block", "block", "turtle_up", "hold_the_line", "heal", "draw"],
	# Range.
	"arrows": ["quick_shot", "quick_shot", "mixed_bag", "mixed_bag", "lead_arrow", "trick_shot",
		"spirit_arrow", "multishot", "reload", "thrown_stone", "block", "draw"],
	# Spells.
	"spells": ["fireball", "fireball", "mana_surge", "mana_surge", "magic_barrier", "magic_barrier",
		"heal", "heal", "gain_mana", "gain_mana", "draw", "block"],
	# Engines: potions and poison, discards, stealth, debuffs.
	"potions": ["healing_potion", "healing_potion", "gulped_potion", "poison_bomb", "poison_bomb",
		"poisoned_blood", "elixir", "potion_of_continuance", "potion_of_continuance", "slash", "slash", "block"],
	"discard_engine": ["discard", "discard", "reposition", "reposition", "volatile_mixture", "volatile_mixture",
		"exacerbate_wounds", "exacerbate_wounds", "meister_of_faustmesser", "armor_patch", "armor_patch", "slice"],
	"shadow": ["shadows", "blink", "dagger_throw", "dagger_throw", "slice", "slice", "savage_strike",
		"block", "block", "draw", "heal", "slash"],
	"debuffer": ["splinter", "splinter", "wear_down", "wear_down", "poison_bomb", "poison_bomb",
		"slash", "slash", "block", "block", "heal", "draw"],
}
