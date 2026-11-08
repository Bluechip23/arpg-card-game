extends SceneTree

## A card's number key toggles it (designer, 2026-11-08): the first press
## selects the card, pressing the same key again deselects it, and another
## card's key still switches straight to that card.
## Run: godot --headless --path . --script tests/test_card_key_toggle.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _press(main, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.pressed = true
	main._input(ev)

func _run() -> void:
	print("=== Card key toggle ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var dm = main.deck_manager
	dm.hand.clear()
	dm.hand.append(Card.create_by_id("slash"))
	dm.hand.append(Card.create_by_id("block"))
	dm.hand_updated.emit()
	await process_frame
	main._build_hand_groups()
	main.selected_card_index = -1

	# Which key holds which card comes from the persistent slot map, not hand
	# order: take the first two occupied slots and press their keys.
	var slots: Array = []
	var card_at := {}
	for g in main._hand_groups:
		slots.append(int(g["slot"]))
		card_at[int(g["slot"])] = dm.hand.find(g["rep"])
	slots.sort()
	_check(slots.size() >= 2, "two cards sit on number keys (%s)" % str(slots))
	if slots.size() < 2:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	var key_a: Key = main.CARD_KEYS[slots[0]]
	var key_b: Key = main.CARD_KEYS[slots[1]]
	_press(main, key_a)
	_check(main.selected_card_index == card_at[slots[0]], "pressing a card's key selects it")
	_press(main, key_a)
	_check(main.selected_card_index == -1, "pressing the same key again deselects it")
	_press(main, key_a)
	_check(main.selected_card_index == card_at[slots[0]], "and a third press selects it again")
	_press(main, key_b)
	_check(main.selected_card_index == card_at[slots[1]], "another card's key switches to that card")
	_press(main, key_b)
	_check(main.selected_card_index == -1, "and its own key puts it back down")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
