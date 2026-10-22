class_name PilePopup
extends Node

## The shared Draw / Discard / Jail pile contents popup: a list of the pile's
## cards aggregated by name, with a hover preview. Lifted out of main.gd; it
## is a child of Main and reads the live deck through `main.deck_manager`
## (co-op swaps that reference per owner).

var main: Main = null
var panel: PanelContainer = null
var _container: VBoxContainer = null
var _title_label: Label = null
var _card_preview: PanelContainer = null
var _showing: bool = false
var _current_pile: String = ""  # "draw", "discard", or "jail"


func is_showing() -> bool:
	return panel != null and panel.visible

func setup_panel() -> void:
	## Creates the shared popup panel used by the Draw, Discard, and Jail buttons.
	var ui := main.get_node("UI") as CanvasLayer
	panel = PanelContainer.new()
	panel.name = "PilePopupPanel"
	main.window_layer().add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -290.0
	panel.offset_top = -220.0
	panel.offset_right = -10.0
	panel.offset_bottom = 220.0
	panel.custom_minimum_size = Vector2(280, 320)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.55, 0.8)
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

	_title_label = Label.new()
	_title_label.text = ""
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 270)
	vbox.add_child(scroll)

	_container = VBoxContainer.new()
	_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_container)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)

	panel.visible = false

	# Hover preview panel for pile entries
	_card_preview = PanelContainer.new()
	_card_preview.name = "PilePopupCardPreview"
	main.window_layer().add_child(_card_preview)
	_card_preview.custom_minimum_size = Vector2(180, 0)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.4, 0.55, 0.8)
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

func toggle(pile: String) -> void:
	## Opens the popup for the given pile, or closes it if already showing the same pile.
	if _showing and _current_pile == pile:
		close()
		return
	_current_pile = pile
	_showing = true
	panel.visible = true
	_populate()

func close() -> void:
	_showing = false
	_current_pile = ""
	if panel:
		panel.visible = false
	if _card_preview:
		_card_preview.visible = false

func _populate() -> void:
	if not _container or not _title_label:
		return

	for child in _container.get_children():
		child.queue_free()

	var cards: Array = []
	var title_text = ""
	var title_color = Color(0.55, 0.85, 1.0)
	match _current_pile:
		"draw":
			cards = main.deck_manager.draw_pile.duplicate()
			title_text = "Draw Pile (%d)" % cards.size()
			title_color = Color(0.55, 0.85, 1.0)
		"discard":
			cards = main.deck_manager.discard_pile.duplicate()
			title_text = "Discard Pile (%d)" % cards.size()
			title_color = Color(1.0, 0.7, 0.4)
		"jail":
			cards = main.deck_manager.jail_pile.duplicate()
			title_text = "Jail Pile (%d)" % cards.size()
			title_color = Color(0.85, 0.45, 0.85)

	_title_label.text = title_text
	_title_label.add_theme_color_override("font_color", title_color)

	if cards.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Empty."
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_container.add_child(empty_lbl)
		return

	# Aggregate by card name to avoid huge lists
	var card_counts: Dictionary = {}
	var card_refs: Dictionary = {}
	for card in cards:
		if card.card_name in card_counts:
			card_counts[card.card_name] += 1
		else:
			card_counts[card.card_name] = 1
			card_refs[card.card_name] = card

	var names := card_counts.keys()
	names.sort()

	for card_name in names:
		var count = card_counts[card_name]
		var card_ref = card_refs[card_name]
		var entry := Button.new()
		entry.text = "%s (%d)" % [card_name, count]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", title_color)
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_entry_hovered.bind(card_ref, entry))
		entry.mouse_exited.connect(_on_entry_unhovered)
		_container.add_child(entry)

func _on_entry_hovered(card: Card, entry: Button) -> void:
	for child in _card_preview.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	_card_preview.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
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

	main._append_keyword_tooltips(vbox, card)

	# Position preview to the left of the popup panel, near the hovered entry
	var entry_rect := entry.get_global_rect()
	var preview_x := panel.position.x - _card_preview.size.x - 10
	var preview_y = entry_rect.position.y
	preview_y = max(preview_y, 4.0)
	_card_preview.global_position = Vector2(preview_x, preview_y)
	_card_preview.visible = true

func _on_entry_unhovered() -> void:
	if _card_preview:
		_card_preview.visible = false

func refresh_if_open() -> void:
	## Refreshes the pile popup if it's currently visible (to keep counts in sync).
	if _showing:
		_populate()
