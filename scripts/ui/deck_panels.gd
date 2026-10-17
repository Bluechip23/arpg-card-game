class_name DeckPanels
extends Node

## The deck-list panel (every card in the deck, counted across piles, with a
## hover preview) and the Manage Deck panel it opens (cull cards with Culling
## Stones, add stored cards back). Lifted out of main.gd; a child of Main that
## reads the live deck through `main.deck_manager` and the main.player's inventory.

var main: Main = null
var panel: PanelContainer = null
var _counts_label: Label = null
var _container: VBoxContainer = null
var _showing: bool = false
var _card_preview: PanelContainer = null
var manage_panel: PanelContainer = null
var _md_deck_list: VBoxContainer = null
var _md_stored_list: VBoxContainer = null
var _md_stones_label: Label = null
var _md_pending_cull: String = ""  # two-click confirm: name of the card armed for culling


func is_showing() -> bool:
	return panel != null and panel.visible

## Hide the deck list (the Player 2 panels close it when they open).
func close() -> void:
	_showing = false
	panel.visible = false
	_card_preview.visible = false

func setup_panel() -> void:
	var ui := main.get_node("UI") as CanvasLayer
	# Main panel
	panel = PanelContainer.new()
	panel.name = "DeckListPanel"
	ui.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -280.0
	panel.offset_top = -250.0
	panel.offset_right = -10.0
	panel.offset_bottom = 250.0
	panel.custom_minimum_size = Vector2(270, 400)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Deck Contents"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(title)

	# "Deck: 10 / 12" for the main.player's own cards, then how many more ride
	# along from gear (slotted into items, granted by items).
	_counts_label = Label.new()
	_counts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counts_label.add_theme_font_size_override("font_size", 13)
	_counts_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	vbox.add_child(_counts_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	vbox.add_child(scroll)

	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_container)

	var manage_btn := Button.new()
	manage_btn.text = "Manage Deck"
	manage_btn.pressed.connect(open_manage)
	vbox.add_child(manage_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(toggle)
	vbox.add_child(close_btn)

	panel.visible = false

	# Card preview popup (shown on hover over deck list entries)
	_card_preview = PanelContainer.new()
	_card_preview.name = "DeckListCardPreview"
	ui.add_child(_card_preview)
	_card_preview.custom_minimum_size = Vector2(180, 0)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.5, 0.5, 0.6)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	preview_style.content_margin_left = 8.0
	preview_style.content_margin_right = 8.0
	preview_style.content_margin_top = 8.0
	preview_style.content_margin_bottom = 8.0
	_card_preview.add_theme_stylebox_override("panel", preview_style)
	_card_preview.visible = false
	_card_preview.z_index = 200
	_card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

func toggle() -> void:
	_showing = !_showing
	panel.visible = _showing
	if _showing:
		_populate()
	else:
		_card_preview.visible = false

func _populate() -> void:
	# Clear existing entries
	for child in _container.get_children():
		child.queue_free()

	# Count cards across all piles
	var card_counts: Dictionary = {}
	var card_refs: Dictionary = {}  # Store a reference card for each name
	var all_cards: Array = []
	all_cards.append_array(main.deck_manager.draw_pile)
	all_cards.append_array(main.deck_manager.hand)
	all_cards.append_array(main.deck_manager.discard_pile)
	all_cards.append_array(main.deck_manager.jail_pile)

	var item_counts: Dictionary = {}  # name -> copies that belong to gear
	for card in all_cards:
		var from_gear: bool = card.slotted_in_item != null or card.granted_by_item != null
		if card.card_name in card_counts:
			card_counts[card.card_name] += 1
		else:
			card_counts[card.card_name] = 1
			card_refs[card.card_name] = card
		if from_gear:
			item_counts[card.card_name] = int(item_counts.get(card.card_name, 0)) + 1

	# Own cards vs the ones gear brings along.
	if _counts_label:
		var own: int = main.deck_manager.get_deck_size()
		var granted := 0
		for c in all_cards + main.deck_manager.maintained_cards:
			if c and c.slotted_in_item == null and c.granted_by_item != null:
				granted += 1
		var inv := main.player.get_inventory() if main.player else null
		var slotted: int = inv.get_all_slotted_cards().size() if inv else 0
		_counts_label.text = "Deck: %d / %d   With slotted cards: %d / %d\nSlotted in items: %d   Granted by items: %d (free)" % [
			own, main.deck_manager.get_max_deck_size(),
			main.deck_manager.get_total_deck_size(), main.deck_manager.get_max_total_deck_size(), slotted, granted]

	# Sort by name
	var names := card_counts.keys()
	names.sort()

	for card_name in names:
		var count = card_counts[card_name]
		var card_ref = card_refs[card_name]
		var entry := Button.new()
		var gear_n: int = int(item_counts.get(card_name, 0))
		entry.text = "%s (%d)" % [card_name, count]
		if gear_n > 0:
			entry.text += "  [%d from items]" % gear_n if gear_n < count else "  [from items]"
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_entry_hovered.bind(card_ref, entry))
		entry.mouse_exited.connect(_on_entry_unhovered)
		_container.add_child(entry)



func open_manage() -> void:
	if manage_panel == null:
		_build_manage_panel()
	_md_pending_cull = ""
	manage_panel.visible = true
	_refresh_manage_panel()
	_center_panel_on_screen.call_deferred(manage_panel)

func _center_panel_on_screen(p: Control) -> void:
	## Explicit centering (anchors alone left this panel off screen).
	if p == null or not is_instance_valid(p):
		return
	p.reset_size()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	p.position = ((vp - p.size) / 2.0).floor()

func _build_manage_panel() -> void:
	var ui := main.get_node("UI") as CanvasLayer
	manage_panel = PanelContainer.new()
	manage_panel.name = "ManageDeckPanel"
	ui.add_child(manage_panel)
	manage_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	manage_panel.custom_minimum_size = Vector2(580, 500)
	manage_panel.z_index = 250  # above hovered hand cards
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.97)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.45, 0.25)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	manage_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	manage_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Manage Deck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(title)

	_md_stones_label = Label.new()
	_md_stones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_md_stones_label.add_theme_font_size_override("font_size", 13)
	_md_stones_label.add_theme_color_override("font_color", Color(0.9, 0.65, 0.35))
	vbox.add_child(_md_stones_label)

	vbox.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(columns)

	# Left column: current deck, click to cull.
	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_box)
	var left_title := Label.new()
	left_title.text = "Deck — click to cull (1 stone)"
	left_title.add_theme_font_size_override("font_size", 13)
	left_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
	left_box.add_child(left_title)
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.custom_minimum_size = Vector2(260, 360)
	left_box.add_child(left_scroll)
	_md_deck_list = VBoxContainer.new()
	_md_deck_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_md_deck_list)

	# Right column: cards carried in the inventory, click to add.
	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_box)
	var right_title := Label.new()
	right_title.text = "Cards on you — click to add (to discard)"
	right_title.add_theme_font_size_override("font_size", 13)
	right_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	right_box.add_child(right_title)
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.custom_minimum_size = Vector2(260, 360)
	right_box.add_child(right_scroll)
	_md_stored_list = VBoxContainer.new()
	_md_stored_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_md_stored_list)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): manage_panel.visible = false)
	vbox.add_child(close_btn)

	manage_panel.visible = false

func _refresh_manage_panel() -> void:
	if manage_panel == null or not manage_panel.visible:
		return
	var inv := main.player.get_inventory()
	_md_stones_label.text = "Culling Stones: %d" % (inv.get_culling_stone_count() if inv else 0)

	for child in _md_deck_list.get_children():
		child.queue_free()
	for child in _md_stored_list.get_children():
		child.queue_free()

	# Left: unique deck cards with counts (same scope as the deck list view).
	var card_counts: Dictionary = {}
	var all_cards: Array = []
	all_cards.append_array(main.deck_manager.draw_pile)
	all_cards.append_array(main.deck_manager.hand)
	all_cards.append_array(main.deck_manager.discard_pile)
	all_cards.append_array(main.deck_manager.jail_pile)
	for card in all_cards:
		card_counts[card.card_name] = card_counts.get(card.card_name, 0) + 1
	var names := card_counts.keys()
	names.sort()
	for card_name in names:
		var entry = Button.new()
		if _md_pending_cull == card_name:
			entry.text = "Cull %s? (click to confirm)" % card_name
			entry.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		else:
			entry.text = "%s (%d)" % [card_name, card_counts[card_name]]
			entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.4))
		entry.add_theme_font_size_override("font_size", 14)
		entry.pressed.connect(_on_manage_cull_pressed.bind(card_name))
		_md_deck_list.add_child(entry)

	# Right: cards carried in storage (NOT the town stash).
	var stored_count := inv.get_stored_card_count() if inv else 0
	if stored_count == 0:
		var none := Label.new()
		none.text = "(no cards on you)"
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_md_stored_list.add_child(none)
	for i in range(stored_count):
		var card = inv.get_stored_card(i)
		if card == null:
			continue
		var entry = Button.new()
		entry.text = card.card_name
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
		entry.add_theme_color_override("font_hover_color", Color(0.5, 1.0, 0.6))
		entry.add_theme_font_size_override("font_size", 14)
		entry.pressed.connect(_on_manage_add_pressed.bind(i))
		_md_stored_list.add_child(entry)

func _on_manage_cull_pressed(card_name: String) -> void:
	# First click arms the cull, second click on the same entry confirms.
	if _md_pending_cull != card_name:
		_md_pending_cull = card_name
		_refresh_manage_panel()
		return
	_md_pending_cull = ""
	var inv := main.player.get_inventory()
	if not inv or inv.get_culling_stone_count() <= 0:
		main.add_battle_log("No Culling Stones left.", Color(1.0, 0.5, 0.4))
		_refresh_manage_panel()
		return
	# Prefer culling an instance the main.player won't miss mid-fight.
	var target: Card = null
	for pile in [main.deck_manager.discard_pile, main.deck_manager.draw_pile, main.deck_manager.jail_pile, main.deck_manager.hand]:
		for c in pile:
			if c.card_name == card_name:
				target = c
				break
		if target:
			break
	if target == null or not inv.use_culling_stone():
		_refresh_manage_panel()
		return
	main.deck_manager.remove_card_from_all_piles(target)
	# Keep the character's card lists in sync, matching the town cull flow.
	if main.starting_character:
		var pidx := main.starting_character.purchased_card_ids.find(target.card_id)
		if pidx >= 0:
			main.starting_character.purchased_card_ids.remove_at(pidx)
		else:
			main.starting_character.removed_card_ids.append(target.card_id)
	main.add_battle_log("Culled %s from the deck." % card_name, Color(1.0, 0.6, 0.3))
	main.update_deck_info()
	if _showing:
		_populate()
	_refresh_manage_panel()

func _on_manage_add_pressed(index: int) -> void:
	var inv := main.player.get_inventory()
	if not inv:
		return
	var card = inv.get_stored_card(index)
	if card == null:
		return
	if inv.add_card_to_deck(index, main.deck_manager):
		main.add_battle_log("Added %s to your discard pile." % card.card_name, Color(0.4, 1.0, 0.5))
		main.update_deck_info()
		if _showing:
			_populate()
		_refresh_manage_panel()
	elif not main.deck_manager.can_add_copy(card.card_id):
		main.add_battle_log("Deck limit: only %d cop%s of %s (%s) allowed." % [
			Card.max_deck_copies(card.card_id),
			"y" if Card.max_deck_copies(card.card_id) == 1 else "ies",
			card.card_name, card.get_rarity_name()], Color(1.0, 0.5, 0.3))

func _on_entry_hovered(card: Card, entry: Button) -> void:
	# Clear previous preview content
	for child in _card_preview.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	_card_preview.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 12)
	match card.card_type:
		Card.CardType.ATTACK:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Card.CardType.DEFENSE:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
		Card.CardType.UTILITY:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		Card.CardType.POWER:
			type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
		Card.CardType.ENCHANTMENT:
			type_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	vbox.add_child(type_lbl)

	var cost_lbl := Label.new()
	if card.maintain_cost > 0:
		cost_lbl.text = "Cost: %dM / %dT | Maintain: %dM" % [card.mana_cost, card.tempo_cost, card.maintain_cost]
	else:
		cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	if card.is_ranged:
		var range_lbl := Label.new()
		range_lbl.text = card.get_range_display()
		range_lbl.add_theme_font_size_override("font_size", 12)
		range_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		vbox.add_child(range_lbl)
	else:
		var melee_lbl := Label.new()
		melee_lbl.text = "Melee"
		melee_lbl.add_theme_font_size_override("font_size", 12)
		melee_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		vbox.add_child(melee_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl := RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.text = card.description
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	desc_lbl.custom_minimum_size = Vector2(160, 0)
	desc_lbl.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(desc_lbl)

	if card.sticky > 0:
		var sticky_lbl := Label.new()
		sticky_lbl.text = "Sticky %d" % card.sticky
		sticky_lbl.add_theme_font_size_override("font_size", 12)
		sticky_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		vbox.add_child(sticky_lbl)

	main._append_keyword_tooltips(vbox, card)

	# Position preview to the left of the deck list panel, above the hand area
	var entry_rect := entry.get_global_rect()
	var preview_x := panel.position.x - _card_preview.size.x - 10
	var preview_y = entry_rect.position.y

	# Clamp so the preview doesn't extend below the hand area
	var hand_area := main.get_node("UI/HandArea") as PanelContainer
	var max_y := hand_area.global_position.y - _card_preview.size.y - 8.0
	preview_y = min(preview_y, max_y)

	# Also clamp to top of screen
	preview_y = max(preview_y, 4.0)

	_card_preview.global_position = Vector2(preview_x, preview_y)
	_card_preview.visible = true

func _on_entry_unhovered() -> void:
	_card_preview.visible = false
