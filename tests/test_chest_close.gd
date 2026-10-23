extends SceneTree

## Closing the chest window takes everything it opened with it: the dim
## overlay that swallows clicks and the card's keyword window. Both live on
## main's window layer; closing used to look for the overlay under $UI,
## never found it, and left the screen frozen behind an invisible-click wall
## with the keyword window still up (play report, 2026-10-23).
## Every way out is checked: Close button, clicking the overlay, Escape,
## taking the card, and re-opening the chest after closing it.
## Run: godot --headless --path . --script tests/test_chest_close.gd

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

func _leftovers() -> Array:
	var out := []
	for layer in [main.window_layer(), main.get_node("UI")]:
		for n in layer.get_children():
			if n.is_queued_for_deletion():
				continue
			if n is ColorRect and n.mouse_filter == Control.MOUSE_FILTER_STOP and n.anchor_right == 1.0 and n.color.a > 0.3:
				out.append("overlay " + str(n.name))
			if n.find_children("*", "KeywordWindow", true, false).size() > 0 or n is KeywordWindow:
				out.append("keyword window under " + str(n.name))
	return out

func _open() -> void:
	main.chest_loot_ui._show_chest_modal({"card": Card.create_by_id("exposing_strike")})
	for _i in range(3):
		await process_frame

func _run() -> void:
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	_check(_leftovers().is_empty(), "nothing modal on screen before the chest opens")

	await _open()
	var open_now := _leftovers()
	_check(open_now.size() >= 2, "an open chest shows its overlay and the card's keyword window (%s)" % [open_now])

	var ways := {
		"Close button": func(): main.chest_loot_ui._close_chest_modal(),
		"clicking the overlay": func():
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			main.chest_loot_ui._on_chest_overlay_input(ev),
		"Escape": func():
			var ev := InputEventKey.new()
			ev.keycode = KEY_ESCAPE
			ev.pressed = true
			main._input(ev),
		"taking the card": func(): main.chest_loot_ui._on_chest_take_card(main._chest_modal_contents.get("card")),
	}
	for way in ways:
		if way != "Close button":
			await _open()
		ways[way].call()
		for _i in range(3):
			await process_frame
		var left := _leftovers()
		_check(left.is_empty(), "%s: no overlay or keyword window left behind %s" % [way, left])
		_check(not main._chest_modal_open, "%s: the chest counts as closed (game input resumes)" % way)
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures else 0)
