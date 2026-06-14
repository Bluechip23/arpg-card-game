class_name Potions
extends RefCounted

## Catalog of roguelike potions. Potions are consumables held by the run; for
## now they are awarded and tracked (using them in battle is a later pass).

class Potion:
	var id: String
	var name: String
	var description: String
	func _init(p_id: String, p_name: String, p_desc: String) -> void:
		id = p_id
		name = p_name
		description = p_desc

static func all() -> Array:
	return [
		Potion.new("healing_draught", "Healing Draught", "Restores a chunk of HP."),
		Potion.new("swift_tonic", "Swift Tonic", "Quickens your next move."),
		Potion.new("iron_brew", "Iron Brew", "Grants armor for a fight."),
		Potion.new("clarity_elixir", "Clarity Elixir", "Draw extra cards next battle."),
	]

static func get_potion(id: String) -> Potion:
	for p in all():
		if p.id == id:
			return p
	return null

static func random_id() -> String:
	var list := all()
	return list[randi() % list.size()].id
