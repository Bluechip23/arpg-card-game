extends SceneTree

## Verifies the field QoL batch: crisp world text helper, the Return Scroll /
## town portal plumbing, and the Manage Deck flows (cull scope + add-to-discard).
## Run: godot --headless --path . --script tests/test_field_qol.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Field QoL test ===")

	# --- Parse checks on every script this batch touched ---
	for path in [
		"res://scripts/core/main.gd",
		"res://scripts/core/world_text.gd",
		"res://scripts/core/dungeon_manager.gd",
		"res://scripts/menus/town.gd",
		"res://scripts/cards/unit_tracker_ui.gd",
		"res://scripts/character/character_panel.gd",
		"res://scripts/character/storage_item_cell.gd",
		"res://scripts/progression/item_data.gd",
		"res://scripts/progression/inventory.gd",
	]:
		var script = load(path)
		_check(script != null and script.can_instantiate(), "%s parses" % path.get_file())

	# --- WorldText.crisp: constant screen size + outline + depth-free ---
	var lbl = Label3D.new()
	lbl.font_size = 16
	WorldText.crisp(lbl)
	_check(lbl.fixed_size and lbl.no_depth_test, "crisp label is fixed-size and never buried")
	_check(absf(lbl.pixel_size - 0.0015) < 0.0001, "crisp label pixel_size 0.0015")
	_check(lbl.font_size >= 28, "small fonts scale up to >=28 (got %d)" % lbl.font_size)
	_check(lbl.outline_size >= 8, "crisp label always outlined")
	lbl.free()

	# --- Return Scroll item ---
	var scroll = ItemData.create_return_scroll()
	_check(scroll.special_id == "return_scroll", "scroll carries special_id")
	_check(scroll.weight == 0, "scroll weighs nothing")

	# --- ensure_return_scroll: idempotent, survives restores ---
	var inv = load("res://scripts/progression/inventory.gd").new()
	inv.initialize("Stephen")
	inv.ensure_return_scroll()
	inv.ensure_return_scroll()
	var scroll_count = 0
	for item in inv.stored_items:
		if item and item.special_id == "return_scroll":
			scroll_count += 1
	_check(scroll_count == 1, "exactly one Return Scroll after double ensure (got %d)" % scroll_count)

	# --- utility items refuse to equip ---
	var scroll_idx := -1
	for i in range(inv.stored_items.size()):
		if inv.stored_items[i] and inv.stored_items[i].special_id == "return_scroll":
			scroll_idx = i
	_check(not inv.equip_from_storage(scroll_idx, 0), "Return Scroll cannot be equipped")

	# --- Manage Deck: adding a carried card goes to the DISCARD pile ---
	var dm = load("res://scripts/cards/deck_manager.gd").new()
	inv.stored_cards.append(Card.create_provider())
	_check(inv.add_card_to_deck(0, dm), "add_card_to_deck succeeds")
	_check(dm.discard_pile.size() == 1 and dm.discard_pile[0].card_id == "provider",
		"added card landed in the discard pile")
	_check(inv.get_stored_card_count() == 0, "card left the inventory")

	# --- Manage Deck: culling removes exactly one instance ---
	var c1 = Card.create_block()
	var c2 = Card.create_block()
	dm.draw_pile.append(c1)
	dm.discard_pile.append(c2)
	_check(dm.remove_card_from_all_piles(c2), "cull removes the chosen instance")
	_check(dm.draw_pile.has(c1) and not dm.discard_pile.has(c2), "the other copy survives")

	inv.free()
	dm.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
