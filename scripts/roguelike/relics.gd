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
	func _init(p_id: String, p_name: String, p_desc: String) -> void:
		id = p_id
		name = p_name
		description = p_desc

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
	]

static func get_relic(id: String) -> Relic:
	for r in all():
		if r.id == id:
			return r
	return null
