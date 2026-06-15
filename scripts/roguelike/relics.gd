class_name Relics
extends RefCounted

## Catalog of roguelike relics. Relics are run-level pickups (carried for the
## current run). For now every catalogued relic is available to drop; story-mode
## discovery will later gate which relics can appear (via the world meta / run
## snapshot). Effects are read where they apply (see RoguelikeMapUI).

class Relic:
	var id: String
	var name: String
	var description: String
	var is_base: bool  # Base relics are always available; non-base must be unlocked in the story
	func _init(p_id: String, p_name: String, p_desc: String, p_base: bool = true) -> void:
		id = p_id
		name = p_name
		description = p_desc
		is_base = p_base

static func all() -> Array:
	return [
		Relic.new("alchemists_satchel", "Alchemist's Satchel",
			"Battles are far more likely to yield a potion."),
		Relic.new("golden_idol", "Golden Idol",
			"Gain extra gold from every battle."),
		Relic.new("whetstone", "Whetstone",
			"A keen edge — a memento of a hard-won elite."),
		Relic.new("traveler's_charm", "Traveler's Charm",
			"Fortune favors the bold on unknown paths."),
		# Non-base: discovered in the story (e.g. dropped by a Hydra).
		Relic.new("hydra_heart", "Hydra Heart",
			"When you take damage on your own turn, gain 1 strength.", false),
	]

static func get_relic(id: String) -> Relic:
	for r in all():
		if r.id == id:
			return r
	return null

## Relics that can appear in this character's runs: all base relics plus any the
## character has unlocked in the story.
static func available_for(character: CharacterData) -> Array:
	var unlocked: Array = character.unlocked_relic_ids if character else []
	var out: Array = []
	for r in all():
		if r.is_base or unlocked.has(r.id):
			out.append(r)
	return out
