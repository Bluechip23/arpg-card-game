extends SceneTree

## Right-clicking a card in hand shows it up close beside the battlefield
## (designer, 2026-10-31; choosing it, by click or number key, does not); it
## never takes the mouse and goes on another right-click, or when the card
## leaves the hand.
## Run: godot --headless --path . --script tests/test_card_closeup.gd

var failures := 0
var _main: Node = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_main)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	print("=== Card close-up ===")
	await _frames(60)
	if _main.olorin and _main.olorin.is_busy():
		_main.olorin._close()
	var hand: Array[Card] = []
	for id in ["slash", "fireball"]:
		hand.append(load("res://data/cards/%s.tres" % id).duplicate())
	_main.deck_manager.hand = hand
	_main._on_hand_updated()
	await _frames(5)
	_check(_main._closeup == null, "nothing is shown up close at first")
	_main.select_card(1)
	await _frames(3)
	_check(_main._closeup == null, "choosing a card (click or number key) does not show it up close")
	_main.select_card(-1)
	# Right-click the second card in the hand.
	_main._current_hand_hover_index = 1
	_check(_main._hand_right_click(), "a right-click on a hand card is the hand's (no move order)")
	await _frames(3)
	var c: Control = _main._closeup
	_check(c != null and is_instance_valid(c), "right-clicking a card shows it up close")
	var face: CardUI = c.get_child(0) if c else null
	var want: Card = _main._hand_groups[1]["rep"]
	_check(face != null and face.get_card() == want, "it is the right-clicked card")
	_check(face != null and face.scale.x >= 1.5, "bigger than in the hand (x%.2f)" % (face.scale.x if face else 0.0))
	var takes_mouse := false
	for n in [c, face]:
		if n and n.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			takes_mouse = true
	_check(not takes_mouse, "it never takes the mouse")
	_main._current_hand_hover_index = 1
	_main._hand_right_click()
	await _frames(3)
	_check(_main._closeup == null, "right-clicking it again puts it away")
	_main._current_hand_hover_index = 1
	_main._hand_right_click()
	await _frames(3)
	_check(_main._closeup != null, "and again brings it back")
	_main.deck_manager.hand.erase(want)
	_main._on_hand_updated()
	await _frames(3)
	_check(_main._closeup == null, "the card leaving the hand puts it away")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
