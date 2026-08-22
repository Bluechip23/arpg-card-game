class_name ProgressionIO
extends RefCounted

## Converts the in-memory player-progression dictionary (which holds live
## RefCounted / Resource objects) to and from a disk-safe form that can be
## embedded in a SaveData resource and written to disk.
##
## The live progression dict is produced by Main._save_player_progression and
## carried in Town.player_progression. It contains live objects (a SphereGrid
## Resource, a SkillTreeData RefCounted, ItemData Resources) that do not all
## survive ResourceSaver, so we snapshot the parts that matter into primitives.
##
## What round-trips today:
##   - level / XP / gold, base + sphere stat bonuses
##   - sphere-grid AND skill-tree PASSIVE EFFECTS (already baked into the stats
##     snapshot by PlayerStats.save_progression)
##   - the deck (card ids), sphere inventory counts
##   - which sphere-grid nodes are unlocked (rebuilt into a SphereGrid on load)
##
## Not yet serialized (a follow-up): the skill-tree node STRUCTURE and equipped
## items. Their effect on stats is preserved via the stats snapshot; what's lost
## is the visual tree/grid-equipment state and item-specific triggers.

## Build a disk-safe snapshot from a live progression dict. Pass a fresh
## stats snapshot via stats_override when the caller has up-to-date stats.
static func to_disk(live: Dictionary, stats_override: Dictionary = {}) -> Dictionary:
	var disk := {}
	if not stats_override.is_empty():
		disk["stats"] = stats_override
	elif live.has("stats"):
		disk["stats"] = live["stats"]
	if live.has("deck_state"):
		# The deck snapshot carries live Card references under "live" for
		# in-memory transitions — strip them for disk (only the plain data
		# lists are serializable; item links can't survive a disk save anyway).
		var deck: Dictionary = live["deck_state"].duplicate()
		deck.erase("live")
		disk["deck_state"] = deck
	if live.has("sphere_inventory"):
		disk["sphere_inventory"] = live["sphere_inventory"]
	var sg = live.get("sphere_grid")
	if sg is SphereGrid:
		var ids: Array[int] = []
		for node in sg.get_all_nodes():
			if node.unlocked:
				ids.append(node.id)
		disk["sphere_unlocked_ids"] = ids
	# City-loop state is already plain data — it round-trips as-is.
	CityBridge.carry_keys(live, disk)
	return disk

## Rebuild a live progression dict (consumable by Main._restore_player_progression
## and Town's _ready restore) from a disk-safe snapshot. Returns {} for an empty
## snapshot so callers can treat it like "no progression".
static func to_live(disk: Dictionary) -> Dictionary:
	var live := {}
	if disk == null or disk.is_empty():
		return live
	if disk.has("stats"):
		live["stats"] = disk["stats"]
	if disk.has("deck_state"):
		live["deck_state"] = disk["deck_state"]
	if disk.has("sphere_inventory"):
		live["sphere_inventory"] = disk["sphere_inventory"]
	if disk.has("sphere_unlocked_ids"):
		var sg := SphereGrid.new()
		var id_set := {}
		for nid in disk["sphere_unlocked_ids"]:
			id_set[int(nid)] = true
		for node in sg.get_all_nodes():
			# Keep nodes the grid unlocks by default (e.g. the START node) and
			# add every saved node id.
			node.unlocked = id_set.has(node.id) or node.unlocked
		live["sphere_grid"] = sg
	CityBridge.carry_keys(disk, live)
	return live
