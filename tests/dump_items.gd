extends SceneTree

## Dumps every ItemData factory (name, type, rarity, descriptions, the
## non-default numeric fields) to /tmp/items.json for the item audit.
## Run: godot --headless --path . --script tests/dump_items.gd

func _initialize() -> void:
	var out: Array = []
	var script: Script = ItemData
	var blank := ItemData.new()
	var seen := {}
	for method in script.get_script_method_list():
		var n: String = method["name"]
		if not n.begins_with("create_") or method["args"].size() != 0 or seen.has(n):
			continue
		seen[n] = true
		var item = script.call(n)
		if not (item is ItemData):
			continue
		var fields := {}
		for prop in item.get_property_list():
			var pn: String = prop["name"]
			if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var v = item.get(pn)
			var d = blank.get(pn)
			if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING] and v != d and pn not in ["description", "item_name", "level_2_description", "level_3_description", "appearance", "appearance_icon"]:
				fields[pn] = v
			elif typeof(v) in [TYPE_ARRAY, TYPE_DICTIONARY] and not v.is_empty() and pn not in ["slotted_cards", "ring_counters"]:
				fields[pn] = str(v)
		out.append({
			"factory": n,
			"name": item.item_name,
			"type": ItemData.ItemType.keys()[int(item.item_type)] if int(item.item_type) < ItemData.ItemType.size() else str(item.item_type),
			"rarity": ItemData.Rarity.keys()[int(item.rarity)] if int(item.rarity) < ItemData.Rarity.size() else str(item.rarity),
			"description": item.description,
			"level_2_description": item.get("level_2_description"),
			"level_3_description": item.get("level_3_description"),
			"fields": fields,
		})
	var f = FileAccess.open("/tmp/items.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("ITEM DUMP COMPLETE: %d items" % out.size())
	quit(0)
