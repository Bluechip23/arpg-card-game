extends SceneTree

## The manage-cards window draws one square per slot (bonus then vanilla),
## offers the deck's fitting cards as draggable chips, and a drop on a chosen
## square slots the card THERE; a drop back on the pool unslots it.
## Run: godot --headless --path . --script tests/test_card_slot_window.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

const CellScript = preload("res://scripts/character/card_slot_cell.gd")

func _cells(node: Node, kind: String, out: Array) -> void:
	for ch in node.get_children():
		if ch.get_script() == CellScript and ch.kind == kind:
			out.append(ch)
		_cells(ch, kind, out)

func _initialize() -> void:
	_run()

func _run() -> void:
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null and main.character_panel != null, "the dojo and its character panel are up")
	if main.player == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	var inv = main.player.get_inventory()
	var dm = main.deck_manager
	var panel = main.character_panel

	var sword := ItemData.new()
	sword.item_name = "Window Sword"
	sword.item_type = ItemData.ItemType.WEAPON
	sword.weapon_subtype = ItemData.WeaponSubtype.SWORD
	sword.card_slots = 1
	sword.vanilla_slots = 2
	sword.on_self_damage = 2
	inv.stored_items.append(sword)
	_check(inv.equip_item(sword, 0), "the test sword is equipped")
	var card := Card.new()
	card.card_id = "test_window_card"
	card.card_name = "Window Card"
	card.card_type = Card.CardType.ATTACK
	card.base_damage = 5
	card.slot_labels = [Card.CardKeyword.SWORD]
	dm.draw_pile.append(card)

	panel._open_card_slot_panel(sword)
	await _settle(2)
	var win = panel._card_slot_panel
	_check(win != null, "the manage-cards window opened")
	var slots: Array = []
	var chips: Array = []
	var zones: Array = []
	_cells(win, "slot", slots)
	_cells(win, "chip", chips)
	_cells(win, "zone", zones)
	_check(slots.size() == 3, "one square per slot (%d)" % slots.size())
	_check(slots.size() == 3 and slots[0].kind_label(sword, 0) == "On-self" and slots[2].kind_label(sword, 2) == "Vanilla", "squares are labelled On-self then Vanilla")
	_check(chips.any(func(c): return c.card != null and c.card.card_id == "test_window_card"), "the fitting deck card is offered as a chip")
	_check(zones.size() == 1, "the pool area is a drop zone")

	# Drop the chip on the last (vanilla) square.
	panel._handle_card_drop_on_slot({"kind": "card", "source": "pool", "card": card, "item": sword, "slot_index": -1}, sword, 2)
	await _settle(2)
	_check(card.slotted_in_item == sword and sword.is_vanilla_slot(card) and int(card.get_on_self_bonus().get("damage", -1)) == 0,
		"dropped on the vanilla square it sits there with no rider")
	win = panel._card_slot_panel
	slots.clear()
	_cells(win, "slot", slots)
	_check(slots.size() == 3 and slots[2].card == card and slots[0].card == null, "the window redrew with the card in square 2")

	# Move it to the bonus square.
	panel._handle_card_drop_on_slot({"kind": "card", "source": "slot", "card": card, "item": sword, "slot_index": 2}, sword, 0)
	await _settle(2)
	_check(card.slotted_in_item == sword and not sword.is_vanilla_slot(card) and int(card.get_on_self_bonus().get("damage", 0)) == 2,
		"moved to the bonus square it gets the rider")

	# Drop it back on the pool: unslotted.
	panel._handle_card_drop_on_pool({"kind": "card", "source": "slot", "card": card, "item": sword, "slot_index": 0})
	await _settle(2)
	_check(card.slotted_in_item == null and sword.slotted_cards.is_empty(), "dropped on the pool it is unslotted")
	panel._close_card_slot_panel()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
