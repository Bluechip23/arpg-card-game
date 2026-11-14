extends SceneTree

## The starter chest's item always carries an on-self effect (designer,
## 2026-11-14), and picking it up opens Olorin's first-gear lesson: card
## slots, what ON-SELF means (with the item's own rider as the example),
## plain slots, items that provide cards and items' standing effects.
## Run: godot --headless --path . --script tests/test_first_gear_lesson.gd

var failures := 0
var main

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== First gear lesson ===")
	# Every seed's starter chest: an item with bonus slots and an on-self.
	var dm := DungeonManager.new()
	get_root().add_child(dm)
	dm.world_level = 1
	var bad: Array = []
	var seen_items := {}
	for salt in range(60):
		dm.loot_salt = salt
		var c: Dictionary = dm._generate_chest_contents(0, true)
		var it: ItemData = c.get("item")
		if it == null or not DungeonManager.starter_item_ok(it) or c.get("card") == null or not c.get("starter", false):
			bad.append(it.item_name if it else "none")
		elif it:
			seen_items[it.item_name] = true
	_check(bad.is_empty(), "60 starter chests: each a card and an item with an on-self (bad: %s)" % [bad])
	_check(seen_items.size() >= 4, "the item varies (%d kinds: %s)" % [seen_items.size(), seen_items.keys()])
	var plain: Dictionary = dm._generate_chest_contents(1, false)
	_check(not plain.get("starter", false), "an ordinary chest is not a starter chest")
	dm.free()

	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 20:
		main.olorin._close()
		guard += 1
		await process_frame
	var ol = main.olorin
	_check(not ol.has_seen("first_item"), "the lesson is unseen at the start")

	# The lesson's text covers the three ways gear works.
	var all := ""
	for l in load("res://scripts/ui/olorin.gd").LESSONS:
		if l["id"] == "first_item":
			for b in l["beats"]:
				all += " ".join(b["paragraphs"]) + " "
	for word in ["CARD SLOTS", "ON-SELF", "PLAIN", "PROVIDE cards", "EFFECT"]:
		_check(all.contains(word), "the lesson explains %s" % word)

	# Picking up the starter chest's item opens it, with that item's on-self.
	var belt := ItemData.create("leather_belt")
	_check(DungeonManager.starter_item_ok(belt), "the Leather belt qualifies")
	main.chest_loot_ui._show_chest_modal({"item": belt, "starter": true})
	for _i in range(3):
		await process_frame
	main.chest_loot_ui._on_chest_pick_up_item(belt)
	for _i in range(3):
		await process_frame
	_check(main.player.get_inventory().stored_items.has(belt), "the item went to the bag")
	_check(ol.has_seen("first_item") and ol.is_busy(), "picking it up opens Olorin's first-gear lesson")
	var shown := _dialog_text(ol)
	_check(shown.contains("Leather belt"), "it opens on the item by name")
	ol._tour_next()
	for _i in range(3):
		await process_frame
	shown = _dialog_text(ol)
	_check(shown.contains("ON-SELF") and shown.contains("Leather belt's on-self reads: +1 damage"),
		"the On-Self beat uses the item's own on-self as the example")
	while ol.is_busy() and guard < 60:
		ol._close()
		guard += 1
		await process_frame
	# An ordinary chest's item teaches nothing.
	var other := ItemData.create("waistband")
	main.chest_loot_ui._show_chest_modal({"item": other})
	for _i in range(3):
		await process_frame
	main.chest_loot_ui._on_chest_pick_up_item(other)
	await process_frame
	_check(not ol.is_busy(), "an ordinary chest's item opens no lesson")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _dialog_text(ol: Node) -> String:
	var parts: Array[String] = []
	for l in ol.find_children("*", "Label", true, false):
		parts.append(str(l.text))
	for r in ol.find_children("*", "RichTextLabel", true, false):
		parts.append(r.get_parsed_text())
	return " ".join(parts)
