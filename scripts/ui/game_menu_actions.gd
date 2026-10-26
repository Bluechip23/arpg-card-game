class_name GameMenuActions
extends RefCounted

## What the in-game ? menu's Save / Quit to Menu / Quit to Desktop buttons do,
## shared by town and the world (main.gd). The host passes `build`, a
## Callable(slot) -> SaveData that snapshots the character as they are now.

const TITLE_MENU := "res://scenes/menus/title_menu.tscn"

## Save button: pick a slot (the picker stays open to show the result).
static func save(host: Node, build: Callable) -> void:
	SaveSlotPicker.open(host, build)

## "Save before you quit?" answered: save first when asked (straight to the
## character's own slot, or through the picker when they have none yet —
## closing the picker without saving calls the quit off), then leave.
static func quit(host: Node, to_desktop: bool, save_first: bool, build: Callable) -> void:
	if not save_first:
		leave(host, to_desktop)
		return
	if SaveManager.has_current_slot():
		var slot := SaveManager.current_slot
		var data: SaveData = build.call(slot)
		if data != null and SaveManager.save_game(slot, data):
			leave(host, to_desktop)
		else:
			# Writing failed: let them choose another slot rather than lose it.
			_pick_then_leave(host, to_desktop, build)
		return
	_pick_then_leave(host, to_desktop, build)

static func _pick_then_leave(host: Node, to_desktop: bool, build: Callable) -> void:
	var picker := SaveSlotPicker.open(host, build, true)
	picker.finished.connect(func(saved: bool):
		if saved:
			leave(host, to_desktop))

## Leave the game: to the desktop, or back to the title menu.
static func leave(host: Node, to_desktop: bool) -> void:
	var tree := host.get_tree()
	if tree == null:
		return
	tree.paused = false
	if to_desktop:
		tree.quit()
		return
	var title: Node = load(TITLE_MENU).instantiate()
	tree.root.add_child(title)
	host.queue_free()
