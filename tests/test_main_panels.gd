extends SceneTree

## The UI panels lifted out of main.gd (PilePopup, MaintainedList,
## DeckPanels) still open, populate, preview and close through the real
## buttons, and their panels still live under Main/UI.
## Run: godot --headless --path . --script tests/test_main_panels.gd

var _main: Node = null
var _frames := 0
var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	print("=== Main panels test ===")
	_pile_popup()
	_maintained_list()
	_deck_panels()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
	return true

func _pile_popup() -> void:
	print("-- pile popup")
	var ui: CanvasLayer = _main.get_node("UI")
	var pp = _main.get("_pile_popup")
	_check(pp != null and pp.get_parent() == _main, "popup node is a child of Main")
	_check(_main.window_layer().get_node_or_null("PilePopupPanel") != null, "PilePopupPanel lives on the window layer (above the HUD)")
	_check(_main.window_layer().get_node_or_null("PilePopupCardPreview") != null, "PilePopupCardPreview lives on the window layer (above the HUD)")
	_check(not pp.is_showing(), "hidden at start")
	_main._draw_pile_btn.pressed.emit()
	_check(pp.is_showing() and pp._current_pile == "draw", "Draw button opens the draw pile")
	_check(pp._title_label.text.begins_with("Draw Pile ("), "title: " + pp._title_label.text)
	var entries: Array = pp._container.get_children()
	_check(entries.size() > 0, "%d draw pile entries" % entries.size())
	if entries.size() > 0 and entries[0] is Button:
		entries[0].mouse_entered.emit()
		_check(pp._card_preview.visible, "hover shows the card preview")
		entries[0].mouse_exited.emit()
		_check(not pp._card_preview.visible, "unhover hides it")
	_main._discard_pile_btn.pressed.emit()
	_check(pp.is_showing() and pp._current_pile == "discard", "Discard button switches pile")
	_main._discard_pile_btn.pressed.emit()
	_check(not pp.is_showing(), "pressing the same button again closes")
	_main.jailed_icon.pressed.emit()
	_check(pp.is_showing() and pp._current_pile == "jail", "jail icon opens the jail pile: " + pp._title_label.text)
	pp.refresh_if_open()
	pp.close()
	_check(not pp.is_showing(), "close() hides")

func _maintained_list() -> void:
	print("-- maintained list")
	var ui: CanvasLayer = _main.get_node("UI")
	var ml = _main.get("_maintained_list")
	_check(ml != null and ml.get_parent() == _main, "maintained list node is a child of Main")
	_check(_main.window_layer().get_node_or_null("MaintainedListPanel") != null, "MaintainedListPanel lives on the window layer (above the HUD)")
	_check(_main.window_layer().get_node_or_null("MaintainedListCardPreview") != null, "MaintainedListCardPreview lives on the window layer (above the HUD)")
	_check(_main.maintained_icon != null and _main.jailed_icon != null, "status-row icons still built by main")
	_check(not ml.is_showing(), "hidden at start")
	_main.maintained_icon.pressed.emit()
	_check(ml.is_showing(), "icon press opens the panel")
	var entries: Array = ml._container.get_children()
	_check(entries.size() == 1 and entries[0] is Label, "empty list shows the 'No maintained cards.' label")
	# Maintain a card for real so the list has an entry.
	var dm = _main.deck_manager
	var card: Card = null
	for c in dm.hand:
		if c.maintain_cost > 0: card = c; break
	if card == null:
		for c in dm.draw_pile:
			if c.maintain_cost > 0: card = c; break
	if card == null:
		card = Card.create_by_id("harden") if Card.factory_ids().has("harden") else null
	if card != null:
		dm.maintained_cards.append(card)
		ml.refresh()
		entries = ml._container.get_children().filter(func(n): return not n.is_queued_for_deletion())
		_check(entries.size() >= 1 and entries[0] is HBoxContainer, "refresh() lists %d maintained card(s)" % entries.size())
		if entries.size() >= 1 and entries[0] is HBoxContainer:
			var btn: Button = entries[0].get_child(0)
			btn.mouse_entered.emit()
			_check(ml._card_preview.visible, "hover shows the preview")
			btn.mouse_exited.emit()
			_check(not ml._card_preview.visible, "unhover hides it")
			var dismiss: Button = entries[0].get_child(1)
			dismiss.pressed.emit()
			_check(dm.get_maintained_cards().size() == 0, "dismiss removes the maintained card")
			_check(not ml.is_showing(), "panel auto-closes when the last maintained card goes")
	else:
		print("  (no maintainable card found / no add_maintained_card; skipped entry checks)")
	if ml.is_showing():
		ml.toggle()
	_check(not ml.is_showing(), "toggle closes")

func _deck_panels() -> void:
	print("-- deck panels")
	var ui: CanvasLayer = _main.get_node("UI")
	var dp = _main.get("_deck_panels")
	_check(dp != null and dp.get_parent() == _main, "deck panels node is a child of Main")
	_check(_main.window_layer().get_node_or_null("DeckListPanel") != null, "DeckListPanel lives on the window layer (above the HUD)")
	_check(not dp.is_showing(), "hidden at start")
	_main.hud_icon_bar.deck_pressed.emit()
	_check(dp.is_showing(), "HUD deck button opens the list")
	var entries: Array = dp._container.get_children()
	_check(entries.size() > 0, "%d deck entries" % entries.size())
	_check(dp._counts_label != null and dp._counts_label.text != "", "counts label: " + str(dp._counts_label.text if dp._counts_label else ""))
	var first_btn: Button = null
	for e in entries:
		if e is Button: first_btn = e; break
		if e is HBoxContainer:
			for c in e.get_children():
				if c is Button: first_btn = c; break
		if first_btn: break
	if first_btn:
		first_btn.mouse_entered.emit()
		_check(dp._card_preview.visible, "hover shows the preview")
		first_btn.mouse_exited.emit()
		_check(not dp._card_preview.visible, "unhover hides it")
	dp.open_manage()
	_check(dp.manage_panel != null and dp.manage_panel.visible, "Manage Deck panel opens")
	_check(_main.window_layer().get_node_or_null("ManageDeckPanel") != null, "ManageDeckPanel lives on the window layer (above the HUD)")
	_check(dp._md_deck_list != null and dp._md_deck_list.get_child_count() > 0, "manage panel lists %d deck rows" % (dp._md_deck_list.get_child_count() if dp._md_deck_list else -1))
	dp.manage_panel.visible = false
	dp.close()
	_check(not dp.is_showing() and not dp._card_preview.visible, "close() hides list + preview")
	_main.hud_icon_bar.deck_pressed.emit()
	_check(dp.is_showing(), "toggle reopens")
	_main.hud_icon_bar.deck_pressed.emit()
	_check(not dp.is_showing(), "toggle closes")
