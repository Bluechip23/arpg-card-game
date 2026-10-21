class_name SimDecks
extends RefCounted

## The one deck library every character draws from (cards are universal:
## only a passive that names a card ties it to a character). Any build of
## any character loads any of these with `deck:<name>`; a new deck written
## here is available to all five at once. Base decks only: item-owned and
## engraved cards ride on top, and tactics, recipes and `swap:` rewrite a
## copy, never these lists.

const DECKS := {
	# Eight cards each: the base cap since 2026-10-20 (the build's identity
	# cards live in gear). Trimmed from the 12-card lists filler-first:
	# Draw / Heal / spare Block and Slash went, then the card the deck-pair
	# sweep measured lowest (RESULTS.md 2026-10-19).
	"starter": ["slash", "exposing_strike", "block", "braced_draw", "heal"],
	# Blades and steel.
	"daggers": ["dagger_throw", "dagger_throw", "slice", "slice", "savage_strike",
		"savage_strike", "specific_strike", "consecutive_snap"],
	"blades": ["savage_strike", "savage_strike", "specific_strike", "specific_strike", "slice",
		"parry", "life_steal", "reckless_strike"],
	"sword_and_board": ["savage_strike", "savage_strike", "specific_strike", "slice", "parry",
		"block", "turtle_up", "hold_the_line"],
	# Range.
	"arrows": ["quick_shot", "quick_shot", "mixed_bag", "mixed_bag", "lead_arrow", "trick_shot",
		"multishot", "thrown_stone"],
	# Spells.
	"spells": ["fireball", "fireball", "mana_surge", "mana_surge", "magic_barrier", "magic_barrier",
		"heal", "gain_mana"],
	# Engines: potions and poison, discards, stealth, debuffs.
	"potions": ["healing_potion", "gulped_potion", "poison_bomb", "poison_bomb",
		"poisoned_blood", "potion_of_continuance", "potion_of_continuance", "slash"],
	"discard_engine": ["discard", "discard", "reposition", "volatile_mixture", "volatile_mixture",
		"exacerbate_wounds", "meister_of_faustmesser", "slice"],
	"shadow": ["shadows", "blink", "dagger_throw", "dagger_throw", "slice", "slice", "savage_strike",
		"block"],
	"debuffer": ["splinter", "splinter", "wear_down", "wear_down", "poison_bomb", "poison_bomb",
		"slash", "block"],
}
