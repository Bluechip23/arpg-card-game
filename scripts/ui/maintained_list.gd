class_name MaintainedList
extends Node

## The "Maintained Cards" panel: every card the player is paying upkeep on,
## with a hover preview and a dismiss button per card. Lifted out of main.gd;
## a child of Main that reads the live deck through `main.deck_manager` and
## keeps the status-row maintained icon and mana-reserve tooltip in sync.

var main: Main = null
var panel: PanelContainer = null
var _container: VBoxContainer = null
var _showing: bool = false
var _card_preview: PanelContainer = null


func is_showing() -> bool:
	return panel != null and panel.visible

func setup_panel() -> void:
	var ui := main.get_node("UI") as CanvasLayer
	panel = PanelContainer.new()
	panel.name = "MaintainedListPanel"
	main.window_layer().add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -280.0
	panel.offset_top = -200.0
	panel.offset_right = -10.0
	panel.offset_bottom = 200.0
	panel.custom_minimum_size = Vector2(270, 300)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.6, 0.3, 0.8)
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
	title.text = "Maintained Cards"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 250)
	vbox.add_child(scroll)

	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_container)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(toggle)
	vbox.add_child(close_btn)

	panel.visible = false

	# Card preview popup for maintained list
	_card_preview = PanelContainer.new()
	_card_preview.name = "MaintainedListCardPreview"
	main.window_layer().add_child(_card_preview)
	_card_preview.custom_minimum_size = Vector2(180, 0)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.6, 0.3, 0.8)
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

func refresh() -> void:
	var cards := main.deck_manager.get_maintained_cards()
	if main.maintained_icon:
		main.maintained_icon.set_cards(cards)
	if main._mana_reserve_tip:
		main._mana_reserve_tip.set_cards(cards)
	if _showing:
		if cards.size() == 0:
			# Last maintained card gone — close the manage panel too.
			toggle()
		else:
			_populate()

func toggle() -> void:
	_showing = !_showing
	panel.visible = _showing
	if _showing:
		_populate()
		_place_beside_icon()
	else:
		_card_preview.visible = false

## Open right beside the maintained icon that was clicked (just below it,
## pulled back on-screen at the edges), not across the screen.
func _place_beside_icon() -> void:
	var icon = main.maintained_icon if main else null
	if icon == null or not is_instance_valid(icon) or not icon.is_visible_in_tree():
		return
	var r: Rect2 = icon.get_global_rect()
	var size := panel.custom_minimum_size.max(panel.get_combined_minimum_size())
	var vp: Vector2 = panel.get_viewport_rect().size
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = size
	var pos := Vector2(r.position.x, r.end.y + 6.0)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp.x - size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - size.y - 8.0))
	panel.position = pos

func _populate() -> void:
	for child in _container.get_children():
		child.queue_free()

	var maintained_cards := main.deck_manager.get_maintained_cards()
	if maintained_cards.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "No maintained cards."
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_container.add_child(empty_lbl)
		return

	for i in range(maintained_cards.size()):
		var card := maintained_cards[i]
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var entry := Button.new()
		entry.text = "%s (%dM)" % [card.card_name, card.maintain_cost]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", Color(0.8, 0.5, 1.0))
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_entry_hovered.bind(card, entry))
		entry.mouse_exited.connect(_on_entry_unhovered)
		hbox.add_child(entry)

		var dismiss_btn := Button.new()
		dismiss_btn.text = "X"
		dismiss_btn.custom_minimum_size = Vector2(28, 28)
		dismiss_btn.add_theme_font_size_override("font_size", 14)
		var dismiss_style := StyleBoxFlat.new()
		dismiss_style.bg_color = Color(0.6, 0.15, 0.15, 0.9)
		dismiss_style.corner_radius_top_left = 4
		dismiss_style.corner_radius_top_right = 4
		dismiss_style.corner_radius_bottom_left = 4
		dismiss_style.corner_radius_bottom_right = 4
		dismiss_btn.add_theme_stylebox_override("normal", dismiss_style)
		var dismiss_hover := StyleBoxFlat.new()
		dismiss_hover.bg_color = Color(0.8, 0.2, 0.2, 0.95)
		dismiss_hover.corner_radius_top_left = 4
		dismiss_hover.corner_radius_top_right = 4
		dismiss_hover.corner_radius_bottom_left = 4
		dismiss_hover.corner_radius_bottom_right = 4
		dismiss_btn.add_theme_stylebox_override("hover", dismiss_hover)
		dismiss_btn.pressed.connect(_on_dismiss.bind(i))
		hbox.add_child(dismiss_btn)

		_container.add_child(hbox)

func _on_dismiss(index: int) -> void:
	main.deck_manager.dismiss_maintained_card(index)
	_populate()
	refresh()
	main.update_deck_info()
	main.add_battle_log("Dismissed a maintained card.", Color(0.8, 0.5, 1.0))

func _on_entry_hovered(card: Card, entry: Button) -> void:
	for child in _card_preview.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	_card_preview.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	vbox.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	vbox.add_child(type_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "Maintain: %dM reserved" % card.maintain_cost
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = card.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(160, 0)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc_lbl)

	main._append_keyword_tooltips(vbox, card)

	var entry_rect := entry.get_global_rect()
	var preview_x := panel.position.x - _card_preview.size.x - 10
	var preview_y = entry_rect.position.y
	var hand_area := main.get_node("UI/HandArea") as PanelContainer
	var max_y := hand_area.global_position.y - _card_preview.size.y - 8.0
	preview_y = min(preview_y, max_y)
	preview_y = max(preview_y, 4.0)
	_card_preview.global_position = Vector2(preview_x, preview_y)
	_card_preview.visible = true

func _on_entry_unhovered() -> void:
	_card_preview.visible = false
