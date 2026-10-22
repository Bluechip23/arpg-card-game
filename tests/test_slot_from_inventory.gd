extends SceneTree

## Slotting a card straight from the card inventory:
##  - the manage-cards window offers every carried card that fits (not only
##    Engrave cards), marked as coming from the inventory
##  - clicking a carried card offers "Slot in Item", which opens "Where do you
##    want to slot the item?" listing each worn item (and kind of slot) it fits
##  - picking one slots it there and it joins the deck; the copy limit holds
##  - unslotting it again with the 8-card base deck full sends it back to the
##    card inventory instead of over the cap
## Run: godot --headless --path . --script tests/test_slot_from_inventory.gd

var failures := 0
var main = null

const CellScript = preload("res://scripts/character/card_slot_cell.gd")

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _cells(node: Node, kind: String, out: Array) -> void:
	for ch in node.get_children():
		if ch.get_script() == CellScript and ch.kind == kind:
			out.append(ch)
		_cells(ch, kind, out)

func _find_buttons(node: Node, text: String, out: Array) -> void:
	for ch in node.get_children():
		if ch is Button and (ch as Button).text.begins_with(text):
			out.append(ch)
		_find_buttons(ch, text, out)

func _find_label(node: Node, text: String) -> bool:
	for ch in node.get_children():
		if ch is Label and (ch as Label).text.contains(text):
			return true
		if _find_label(ch, text):
			return true
	return false

func _sword_card(id: String) -> Card:
	var card := Card.new()
	card.card_id = id
	card.card_name = id.capitalize()
	card.card_type = Card.CardType.ATTACK
	card.base_damage = 5
	card.slot_labels = [Card.CardKeyword.SWORD]
	return card

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Slot from card inventory test ===")
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
	var inv = main.player.get_inventory()
	var dm = main.deck_manager
	var panel = main.character_panel

	var sword := ItemData.new()
	sword.item_name = "Bag Sword"
	sword.item_type = ItemData.ItemType.WEAPON
	sword.weapon_subtype = ItemData.WeaponSubtype.SWORD
	sword.card_slots = 1
	sword.vanilla_slots = 1
	sword.on_self_damage = 2
	inv.stored_items.append(sword)
	_check(inv.equip_item(sword, 0), "the test sword is equipped")

	var carried := _sword_card("bag_card")
	inv.stored_cards.append(carried)

	# 1) The manage-cards window lists the carried card, marked as such.
	panel._open_card_slot_panel(sword)
	await _settle(2)
	var chips: Array = []
	_cells(panel._card_slot_panel, "chip", chips)
	var found = null
	for c in chips:
		if c.card == carried:
			found = c
	_check(found != null, "the manage-cards window offers a plain card from the card inventory")
	_check(found != null and _find_label(found, "from inventory"), "and marks it as coming from the inventory")
	panel._close_card_slot_panel()

	# 2) Clicking the carried card offers Slot in Item.
	panel.show_panel()
	panel._on_card_cell_clicked(carried, inv.stored_cards.find(carried))
	await _settle(2)
	var slot_btns: Array = []
	_find_buttons(panel._card_confirm_popup, "Slot in Item", slot_btns)
	_check(slot_btns.size() == 1 and not slot_btns[0].disabled, "the card popup has an enabled Slot in Item button")

	# 3) The chooser lists the sword's on-self slot and its vanilla slot.
	slot_btns[0].pressed.emit()
	await _settle(2)
	var pop = panel._slot_choice_popup
	_check(pop != null and _find_label(pop, "Where do you want to slot the item?"), "the chooser asks where to slot it")
	var opts: Array = []
	_find_buttons(pop, "Bag Sword", opts)
	_check(opts.size() == 2, "it lists the sword once per kind of slot (%d)" % opts.size())
	_check(_find_label(pop, "+2 damage") or _find_label(pop, "damage"), "the on-self option says what bonus the card gets")
	_check(_find_label(pop, "Vanilla slot: no bonus."), "the vanilla option says it gives no bonus")

	# 4) Picking the on-self slot slots it and it joins the deck.
	var deck_before: int = dm.get_total_deck_size()
	var on_self_btn = null
	for b in opts:
		if b.text.ends_with("on-self slot"):
			on_self_btn = b
	_check(on_self_btn != null, "an on-self option is listed")
	if on_self_btn:
		on_self_btn.pressed.emit()
	await _settle(2)
	_check(carried.slotted_in_item == sword and not sword.is_vanilla_slot(carried), "the card sits in the sword's on-self slot")
	_check(not inv.stored_cards.has(carried), "it left the card inventory")
	_check(dm.get_total_deck_size() == deck_before + 1, "it joined the deck (%d -> %d)" % [deck_before, dm.get_total_deck_size()])
	_check(not is_instance_valid(panel._card_confirm_popup) and not is_instance_valid(panel._slot_choice_popup),
		"the popups close after slotting")

	# 5) No worn item takes it: the button is greyed out.
	var nowhere := Card.new()
	nowhere.card_id = "bag_wand_card"
	nowhere.card_name = "Wand Only"
	nowhere.slot_labels = [Card.CardKeyword.WAND]
	inv.stored_cards.append(nowhere)
	panel._on_card_cell_clicked(nowhere, inv.stored_cards.find(nowhere))
	await _settle(2)
	slot_btns.clear()
	_find_buttons(panel._card_confirm_popup, "Slot in Item", slot_btns)
	_check(slot_btns.size() == 1 and slot_btns[0].disabled, "a card no worn item fits gets a greyed-out Slot in Item")
	panel._dismiss_card_confirm_modal()

	# 6) Copy limit: a legendary already in the deck cannot come in again via a slot.
	var leg_id := ""
	for cid in Card.CARD_RARITIES:
		if Card.max_deck_copies(cid) == 1:
			var probe = Card.create_by_id(cid)
			if probe and probe.has_slot_label(Card.CardKeyword.SWORD):
				leg_id = cid
				break
	if leg_id != "":
		var a = Card.create_by_id(leg_id)
		dm.draw_pile.append(a)
		var b = Card.create_by_id(leg_id)
		inv.stored_cards.append(b)
		_check(not inv.enchant_card(b, sword), "a second copy of %s is refused through a slot (%s)" % [leg_id, inv.last_refusal])
		_check(inv.stored_cards.has(b), "and stays in the card inventory")
		dm.draw_pile.erase(a)
		inv.stored_cards.erase(b)
	else:
		print("  (skip: no single-copy sword card to test the copy limit)")

	# 7) Unslot with the base deck full: back to the card inventory.
	while dm.get_deck_size() < dm.get_max_deck_size():
		dm.draw_pile.append(Card.create_by_id("slash"))
	var idx: int = sword.slotted_cards.find(carried)
	_check(inv.extract_card(sword, idx) == carried, "the card comes out of the sword")
	_check(inv.stored_cards.has(carried) and not dm.draw_pile.has(carried) and not dm.hand.has(carried) \
		and not dm.discard_pile.has(carried), "a full base deck sends it back to the card inventory")
	_check(dm.get_deck_size() == dm.get_max_deck_size(), "the base deck stays at its cap (%d)" % dm.get_deck_size())

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
