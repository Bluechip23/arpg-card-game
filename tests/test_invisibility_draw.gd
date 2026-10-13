extends SceneTree

## The invisibility draw (designer rule): entering invisibility offers the
## top card; drawing it costs a separate discard, and that discard cannot be
## skipped by cancelling the picker. Driven through the real Main scene.
## Run: godot --headless --path . --script tests/test_invisibility_draw.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		failures += 1

func _picker(main: Node, name: String) -> Node:
	var ui = main.get_node_or_null("UI")
	return ui.find_child(name, true, false) if ui else null

func _press(node: Node, text_prefix: String) -> bool:
	for b in node.find_children("*", "Button", true, false):
		if str(b.text).begins_with(text_prefix):
			b.pressed.emit()
			return true
	return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=== Invisibility draw test ===")
	var runner := SimRunner.new(self)
	var sc := SimScenario.with_defaults(CharacterBuilds.compose("ryan", {"build": "shadow_blade", "enemy": "WERERAT"}))
	sc["max_bars"] = 1
	# Build the fight and stop before any decision: the scripted policy with no script waits.
	await runner.boot_only(sc, 1)
	var main = runner.main
	var dm = main.deck_manager
	while dm.hand.size() > 2:
		dm.discard_card_from_hand(dm.hand.back())
	var hand_before: int = dm.hand.size()
	var top: Card = dm.draw_pile.back()
	main.player.get_buff_manager().apply_buff(Buff.create_invisible(5, "test"))
	await process_frame
	await process_frame
	var choice := _picker(main, "ChoicePicker")
	_check(choice != null, "entering invisibility opens the draw choice")
	_check(choice != null and _press(choice, "Draw"), "the choice offers to draw the top card")
	await process_frame
	_check(dm.hand.has(top), "the top card is drawn (%s)" % top.card_name)
	var discard := _picker(main, "HandCardPicker")
	_check(discard != null, "a discard picker follows the draw")
	if discard:
		_press(discard, "Cancel")
		discard.name = "Cancelled"
	await process_frame
	await process_frame
	var again := _picker(main, "HandCardPicker")
	_check(again != null, "cancelling the discard re-opens it (the discard is not optional)")
	if again:
		var btns := again.find_children("*", "Button", true, false)
		var drawn_name := top.card_name
		var pressed := false
		for b in btns:
			if b.text != "Cancel" and b.text.find(drawn_name) < 0:
				b.pressed.emit()
				pressed = true
				break
		_check(pressed, "a card other than the drawn one can be discarded")
	await process_frame
	_check(dm.hand.size() == hand_before and dm.hand.has(top), "net hand size unchanged and the drawn card kept (%d)" % dm.hand.size())
	# Already invisible: a refresh is not entering.
	main.player.get_buff_manager().apply_buff(Buff.create_invisible(5, "test again"))
	await process_frame
	await process_frame
	_check(_picker(main, "ChoicePicker") == null, "refreshing invisibility does not offer a second draw")
	await runner.teardown()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
