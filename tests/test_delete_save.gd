extends SceneTree

## Deleting a save (designer, 2026-11-08): on the load screen each save has a
## "Hold to Delete" button that must be held for 4 seconds; letting go early
## cancels. After the hold an "are you sure" window opens, and only its
## Delete button removes the save.
## Run: godot --headless --path . --script tests/test_delete_save.gd

const SLOT := 5
var failures := 0
var _backup: SaveData = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _make_save() -> void:
	var sd := SaveData.new()
	sd.character_data = CharacterData.create_brad()
	sd.character_name = "Delete Me"
	sd.character_level = 3
	SaveManager.save_game(SLOT, sd)

func _screen():
	var ls = (load("res://scenes/character/load_character.tscn") as PackedScene).instantiate()
	get_root().add_child(ls)
	return ls

func _delete_button(ls) -> Button:
	for b in ls.find_children("DeleteButton", "Button", true, false):
		var card: Node = b
		while card and not (card is PanelContainer):
			card = card.get_parent()
		if card:
			for l in card.find_children("*", "Label", true, false):
				if str(l.text).begins_with("Delete Me"):
					return b
	return null

func _run() -> void:
	print("=== Delete a save ===")
	await process_frame
	_backup = SaveManager.load_game(SLOT)
	_make_save()
	SaveManager.current_slot = SLOT
	var ls = _screen()
	await process_frame
	var btn = _delete_button(ls)
	_check(btn != null, "each save has a Hold to Delete button")
	if btn == null:
		_finish()
		return
	_check(is_equal_approx(btn.hold_seconds, 4.0), "it needs a 4-second hold")

	# Let go early: nothing happens.
	btn.button_down.emit()
	btn.advance(2.0)
	_check(btn.progress() > 0.4 and btn.progress() < 0.6, "holding fills the button (%.2f)" % btn.progress())
	btn.button_up.emit()
	_check(btn.progress() == 0.0, "letting go early cancels the hold")
	btn.advance(3.0)
	_check(ls.get_node_or_null("DeleteConfirm") == null, "an early release asks nothing")

	# 3.9 seconds is not enough; 4 is.
	btn.button_down.emit()
	btn.advance(3.9)
	_check(ls.get_node_or_null("DeleteConfirm") == null, "3.9 seconds is not enough")
	btn.advance(0.2)
	await process_frame
	var confirm = ls.get_node_or_null("DeleteConfirm")
	_check(confirm != null, "after 4 seconds the 'are you sure' window opens")
	_check(SaveManager.save_exists(SLOT), "the save is still there while it asks")

	# Cancel keeps it.
	if confirm:
		confirm.find_child("CancelButton", true, false).pressed.emit()
		await process_frame
		await process_frame
	_check(ls.get_node_or_null("DeleteConfirm") == null and SaveManager.save_exists(SLOT), "Cancel keeps the save")

	# Hold again and confirm.
	btn.button_down.emit()
	btn.advance(4.1)
	await process_frame
	confirm = ls.get_node_or_null("DeleteConfirm")
	if confirm:
		confirm.find_child("ConfirmDeleteButton", true, false).pressed.emit()
		await process_frame
		await process_frame
	_check(not SaveManager.save_exists(SLOT), "Delete in the window removes the save")
	_check(SaveManager.current_slot == -1, "the slot in play is forgotten")
	_check(_delete_button(ls) == null, "and it leaves the list")
	ls.queue_free()
	_finish()

func _finish() -> void:
	if _backup:
		SaveManager.save_game(SLOT, _backup)
	elif SaveManager.save_exists(SLOT):
		SaveManager.delete_save(SLOT)
	SaveManager.current_slot = -1
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
