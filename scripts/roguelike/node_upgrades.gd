class_name NodeUpgrades
extends RefCounted

## Catalog of meta-progression upgrades that attach to roguelike map nodes.
##
## Upgrades are unlocked at the WORLD level (WorldData.node_upgrades, keyed by
## node-type id). A run freezes the world's unlocks into its meta_snapshot at
## start, so an upgrade only affects a run if it was already unlocked when that
## run began — unlocking one mid-run benefits the NEXT run, not the current one.
##
## This is the extension point: add an Upgrade entry here, then read it where the
## node resolves (see RoguelikeMapUI). Effects are intentionally small for now.

class Upgrade:
	var id: String
	var node_type_id: String   # matches RoguelikeMapNode.type_id(...)
	var name: String
	var description: String
	func _init(p_id: String, p_type: String, p_name: String, p_desc: String) -> void:
		id = p_id
		node_type_id = p_type
		name = p_name
		description = p_desc

static func all() -> Array:
	return [
		Upgrade.new("deep_rest", "campfire", "Deep Rest",
			"Resting restores 50% of max HP instead of 30%."),
		Upgrade.new("war_supplies", "campfire", "War Supplies",
			"Resting also grants +8 max HP for the rest of the run."),
		Upgrade.new("founders_discount", "shop", "Founder's Discount",
			"Shops greet you with discounted wares."),
		Upgrade.new("lucky_find", "random", "Lucky Find",
			"Unknown sites yield extra gold."),
	]

static func get_upgrade(id: String) -> Upgrade:
	for u in all():
		if u.id == id:
			return u
	return null

static func for_type(node_type_id: String) -> Array:
	var out: Array = []
	for u in all():
		if u.node_type_id == node_type_id:
			out.append(u)
	return out

## Upgrades that exist in the catalog but are NOT yet unlocked in the given world.
static func locked_in(world: WorldData) -> Array:
	var out: Array = []
	if not world:
		return out
	for u in all():
		if not world.has_node_upgrade(u.node_type_id, u.id):
			out.append(u)
	return out
