extends SceneTree

## The shopkeepers introduce themselves (designer, 2026-10-28): the first time
## the player speaks to the Blacksmith, the Armory keeper, the Card Dealer or
## the Sellsword, they say who they are and what they do — in the speech bar,
## with their own close-up, by title only (no names yet). Reading on opens
## their shop. Each does it once per character; the next visit goes straight
## to the shop.
## Run: godot --headless --path . --script tests/test_keeper_intros.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(n := 4) -> void:
	for _i in range(n):
		await process_frame

func _shift(town) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SHIFT
	ev.pressed = true
	town._input(ev)

func _run() -> void:
	print("=== Shopkeeper introductions ===")
	var town = load("res://scenes/menus/town.tscn").instantiate()
	var who := CharacterData.create_ryan()
	town.starting_character = who
	get_root().add_child(town)
	await _settle()
	var tut = town._olorin_tutorial
	if tut.is_busy():
		tut._close()
	for key in town.KEEPER_INTROS:
		var intro: Dictionary = town.KEEPER_INTROS[key]
		var node = town.get_node_or_null("Vendors/" + key)
		_check(node != null, "%s stands in town" % key)
		if node == null:
			continue
		_check(ResourceLoader.exists(str(intro["portrait"])), "%s has a close-up" % intro["speaker"])
		_check(str(intro["speaker"]).begins_with("The "), "%s goes by title only" % intro["speaker"])
		town.nearby_vendor = node
		town.vendor_open = false
		_shift(town)
		await process_frame
		_check(tut.is_busy(), "first Shift at the %s: an introduction, not the shop" % key)
		var bar: Node = tut._layer.find_child("SpeechBar", true, false) if tut._layer else null
		_check(bar != null and bar.find_child("Speaker", true, false).text == intro["speaker"], "spoken by %s" % intro["speaker"])
		var face: TextureRect = bar.find_child("Face", true, false) if bar else null
		_check(face != null and face.texture != null and face.texture.resource_path == str(intro["portrait"]), "with their own face")
		_check(not town.vendor_open, "the shop waits while they talk")
		(bar.find_child("ContinueButton", true, false) as Button).pressed.emit()
		await process_frame
		_check(not tut.is_busy() and town.vendor_open, "reading on opens the %s" % key)
		_check(who.seen_tutorial_ids.has(intro["id"]), "remembered on the character (saved)")
		town._close_vendor()
		await process_frame
		town.nearby_vendor = node
		_shift(town)
		await process_frame
		_check(not tut.is_busy() and town.vendor_open, "the next visit goes straight to the shop")
		town._close_vendor()
		await process_frame
	# A fresh character meets them anew; Olorin's own face is untouched.
	_check(tut._portrait_for(tut.OLORIN_SPEAKER).resource_path == tut.OLORIN_PORTRAIT, "Olorin keeps his own close-up afterwards")
	town.queue_free()
	await _settle(2)
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
