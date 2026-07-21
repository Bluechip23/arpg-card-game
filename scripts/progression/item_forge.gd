class_name ItemForge
extends RefCounted

## Blacksmith forging: upgrade an item by consuming extra copies of it, and
## mold spare mythics into Mythic Molds redeemable for any mythic item.
##
## Rules (see ItemData's rarity section for the copy math):
##   * Only level-1 items drop; higher levels exist only through the forge.
##   * Fodder copies must be level 1, unequipped (inventory or stash), carry no
##     slotted cards (so enchanted cards are never silently destroyed), and
##     must not be the item being upgraded.
##   * The upgraded item itself must also be unequipped — town restores stat
##     snapshots without re-applying equip bonuses, so forging an equipped
##     item would desync player stats.

## All valid fodder copies for `target` in inventory + stash, excluding the
## target itself.
static func get_fodder_copies(inv: Inventory, target: ItemData) -> Array[ItemData]:
	var copies: Array[ItemData] = []
	for list in [inv.stored_items, inv.stash_items]:
		for item in list:
			if item == null or item == target:
				continue
			if item.item_name == target.item_name and item.item_level == 1 \
					and item.slotted_cards.is_empty() and item.granted_card_instances.is_empty():
				copies.append(item)
	return copies

static func is_unequipped(inv: Inventory, item: ItemData) -> bool:
	return inv.stored_items.has(item) or inv.stash_items.has(item)

static func can_forge(inv: Inventory, target: ItemData) -> bool:
	if target == null or not target.can_level_up():
		return false
	if not is_unequipped(inv, target):
		return false
	return get_fodder_copies(inv, target).size() >= target.get_copies_for_next_level()

## Consume the required copies and level the target up.
## Returns true on success.
static func forge(inv: Inventory, target: ItemData) -> bool:
	if not can_forge(inv, target):
		return false
	var needed = target.get_copies_for_next_level()
	var fodder = get_fodder_copies(inv, target)
	for i in range(needed):
		_remove_item(inv, fodder[i])
	target.level_up()
	inv.storage_changed.emit()
	print("[FORGE] %s forged to Lv.%d (%d copies consumed)" % [target.item_name, target.item_level, needed])
	return true

## Mold two spare mythic items down into one Mythic Mold. Both must be
## unequipped level-1 mythics with no slotted/granted card instances attached.
static func can_mold(inv: Inventory, a: ItemData, b: ItemData) -> bool:
	if a == null or b == null or a == b:
		return false
	for item in [a, b]:
		if item.rarity != ItemData.Rarity.MYTHIC or item.item_level != 1:
			return false
		if not is_unequipped(inv, item):
			return false
		if not item.slotted_cards.is_empty() or not item.granted_card_instances.is_empty():
			return false
	return true

static func mold_mythics(inv: Inventory, a: ItemData, b: ItemData) -> bool:
	if not can_mold(inv, a, b):
		return false
	_remove_item(inv, a)
	_remove_item(inv, b)
	inv.add_mythic_mold()
	inv.storage_changed.emit()
	print("[FORGE] Molded %s + %s into a Mythic Mold" % [a.item_name, b.item_name])
	return true

## Redeem one Mythic Mold for a fresh level-1 copy of the chosen mythic.
## When allowed_names is non-empty, only those mythics can be crafted —
## the Blacksmith passes the character's owned-mythic history, so molds
## forge copies of what the player has found, never unfound items.
## Returns the created item (already stored in the inventory), or null.
static func redeem_mold(inv: Inventory, mythic_name: String, allowed_names: Array = []) -> ItemData:
	if inv.mythic_molds <= 0:
		return null
	if not allowed_names.is_empty() and not allowed_names.has(mythic_name):
		print("[FORGE] %s has never been owned — molds only recreate found mythics" % mythic_name)
		return null
	var item = ItemData.create_by_name(mythic_name)
	if item == null or item.rarity != ItemData.Rarity.MYTHIC:
		print("[FORGE] %s is not a mythic item" % mythic_name)
		return null
	if inv.is_storage_full():
		print("[FORGE] Cannot redeem mold — inventory full")
		return null
	inv.use_mythic_mold()
	inv.store_item(item)
	print("[FORGE] Redeemed Mythic Mold for %s" % item.item_name)
	return item

## Every unequipped item that could ever be forged (level below max), grouped
## as {item, copies_have, copies_needed}. Groups collapse duplicates: only the
## first instance of each (name, level) pair becomes the upgrade target.
static func get_forge_candidates(inv: Inventory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for list in [inv.stored_items, inv.stash_items]:
		for item in list:
			if item == null or not item.can_level_up():
				continue
			var key = "%s|%d" % [item.item_name, item.item_level]
			if seen.has(key):
				continue
			seen[key] = true
			result.append({
				"item": item,
				"copies_have": get_fodder_copies(inv, item).size(),
				"copies_needed": item.get_copies_for_next_level(),
			})
	return result

## Spare mythics eligible for molding.
static func get_moldable_mythics(inv: Inventory) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for list in [inv.stored_items, inv.stash_items]:
		for item in list:
			if item == null:
				continue
			if item.rarity == ItemData.Rarity.MYTHIC and item.item_level == 1 \
					and item.slotted_cards.is_empty() and item.granted_card_instances.is_empty():
				result.append(item)
	return result

static func _remove_item(inv: Inventory, item: ItemData) -> void:
	var idx = inv.stored_items.find(item)
	if idx >= 0:
		inv.stored_items.remove_at(idx)
		return
	idx = inv.stash_items.find(item)
	if idx >= 0:
		inv.stash_items.remove_at(idx)
