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
##   - the skill tree's choices (rebuilt onto a fresh tree by Main on load)
##   - the inventory: equipped items, storage, stash, rack, currencies — each
##     item as {name, level, slotted card ids}, rebuilt via ItemData.create_by_name
##
## Cards slotted into items are re-linked to the restored deck's cards by
## Inventory.relink_slotted_cards once Main has rebuilt the deck.

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
	var tree = live.get("skill_tree")
	if tree is SkillTreeData:
		disk["skill_tree"] = tree.collect_choices()
	if live.has("inventory"):
		disk["inventory"] = _inventory_to_disk(live["inventory"])
	# City-loop state is already plain data — it round-trips as-is.
	CityBridge.carry_keys(live, disk)
	return disk

const _ITEM_LISTS := ["equipped_helms", "equipped_chests", "equipped_rings", "equipped_belts",
	"equipped_boots", "equipped_gauntlets", "equipped_weapons", "stored_items", "stash_items", "rack_items"]
const _INT_FIELDS := ["culling_stones", "mythic_molds", "rack_cooldown_tempo"]

static func _item_to_disk(item) -> Variant:
	if not (item is ItemData):
		return null  # empty equipment slot
	var slotted: Array = []
	for c in item.slotted_cards:
		if c is Card:
			slotted.append(c.card_id)
	return {"name": item.item_name, "level": item.item_level, "slotted": slotted}

static func _item_from_disk(entry) -> ItemData:
	if not (entry is Dictionary):
		return null
	var item := ItemData.create_by_name(str(entry.get("name", "")))
	if item == null:
		push_warning("[SAVE] Unknown item in save: %s" % str(entry.get("name", "")))
		return null
	for _i in range(int(entry.get("level", 1)) - 1):
		item.level_up()
	var slotted: Array = entry.get("slotted", [])
	if not slotted.is_empty():
		item.set_meta("pending_slotted_ids", slotted.duplicate())
	return item

static func _inventory_to_disk(inv: Dictionary) -> Dictionary:
	var out := {}
	for key in _ITEM_LISTS:
		if inv.has(key):
			var lst: Array = []
			for item in inv[key]:
				lst.append(_item_to_disk(item))
			out[key] = lst
	if inv.has("stored_cards"):
		var ids: Array = []
		for c in inv["stored_cards"]:
			if c is Card:
				ids.append(c.card_id)
		out["stored_cards"] = ids
	for key in _INT_FIELDS:
		if inv.has(key):
			out[key] = int(inv[key])
	return out

static func _inventory_to_live(disk_inv: Dictionary) -> Dictionary:
	var out := {}
	for key in _ITEM_LISTS:
		if disk_inv.has(key):
			var lst: Array[ItemData] = []
			for entry in disk_inv[key]:
				lst.append(_item_from_disk(entry))
			out[key] = lst if key != "rack_items" else Array(lst)
	if disk_inv.has("stored_cards"):
		var cards: Array = []
		for cid in disk_inv["stored_cards"]:
			var c := Card.create_by_id(str(cid))
			if c:
				cards.append(c)
		out["stored_cards"] = cards
	for key in _INT_FIELDS:
		if disk_inv.has(key):
			out[key] = int(disk_inv[key])
	return out

## Rebuild a live progression dict (consumable by Main._restore_player_progression
## and Town's _ready restore) from a disk-safe snapshot. Returns {} for an empty
## snapshot so callers can treat it like "no progression".
static func to_live(disk: Dictionary) -> Dictionary:
	var live := {}
	if disk == null or disk.is_empty():
		return live
	# Trials were called calamities in older saves.
	if disk.has("city_calamity") and not disk.has("city_trial"):
		disk["city_trial"] = disk["city_calamity"]
		disk.erase("city_calamity")
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
	if disk.has("skill_tree"):
		# Main rebuilds the tree for the character, then applies these choices.
		live["skill_tree_choices"] = disk["skill_tree"]
	if disk.has("inventory"):
		live["inventory"] = _inventory_to_live(disk["inventory"])
	CityBridge.carry_keys(disk, live)
	return live
