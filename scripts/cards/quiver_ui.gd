class_name QuiverUI
extends PanelContainer

## UI for the Bottomless Quiver - shows stored attack cards and allows playing them

signal quiver_card_targeting_selected(card: Card, index: int, target_type: String)

var overflow_manager: OverflowManager

# UI nodes (built in _ready)
var _title_label: Label
var _open_button: Button
var _cards_area: PanelContainer
var _cards_hbox: HBoxContainer
var _targeting_area: HBoxContainer
var _target_label: Label
var _cancel_button: Button

var _quiver_open: bool = false
var _selected_card_index: int = -1
var _ready_complete: bool = false

func _ready() -> void:
	_build_ui()
	_apply_panel_style()
	_ready_complete = true
	_refresh_display()

func _apply_panel_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.55, 0.35, 0.15)  # Brown-orange for quiver
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# ── Header Row ─────────────────────────────────
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)

	_title_label = Label.new()
	_title_label.text = "Quiver: 0 cards"
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_title_label)

	_open_button = Button.new()
	_open_button.text = "Open Quiver"
	_open_button.add_theme_font_size_override("font_size", 12)
	_open_button.pressed.connect(_on_open_button_pressed)
	_apply_button_style(_open_button, Color(0.3, 0.2, 0.08))
	header_row.add_child(_open_button)

	# ── Cards Area (hidden by default) ──────────────
	_cards_area = PanelContainer.new()
	_cards_area.visible = false
	var cards_style = StyleBoxFlat.new()
	cards_style.bg_color = Color(0.08, 0.08, 0.1, 1.0)
	cards_style.border_width_left = 1
	cards_style.border_width_right = 1
	cards_style.border_width_top = 1
	cards_style.border_width_bottom = 1
	cards_style.border_color = Color(0.4, 0.25, 0.1)
	cards_style.corner_radius_top_left = 4
	cards_style.corner_radius_top_right = 4
	cards_style.corner_radius_bottom_left = 4
	cards_style.corner_radius_bottom_right = 4
	cards_style.content_margin_left = 6.0
	cards_style.content_margin_right = 6.0
	cards_style.content_margin_top = 6.0
	cards_style.content_margin_bottom = 6.0
	_cards_area.add_theme_stylebox_override("panel", cards_style)
	vbox.add_child(_cards_area)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cards_area.add_child(scroll)

	_cards_hbox = HBoxContainer.new()
	_cards_hbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_cards_hbox)

	# ── Targeting Row (hidden until card selected) ──
	_targeting_area = HBoxContainer.new()
	_targeting_area.add_theme_constant_override("separation", 6)
	_targeting_area.visible = false
	vbox.add_child(_targeting_area)

	_target_label = Label.new()
	_target_label.text = "Target:"
	_target_label.add_theme_font_size_override("font_size", 12)
	_target_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_targeting_area.add_child(_target_label)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.add_theme_font_size_override("font_size", 12)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_apply_button_style(_cancel_button, Color(0.35, 0.1, 0.1))
	_targeting_area.add_child(_cancel_button)

func _apply_button_style(btn: Button, base_color: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_color = base_color.lightened(0.2)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = base_color.lightened(0.15)
	hover.border_width_left = 1
	hover.border_width_right = 1
	hover.border_width_top = 1
	hover.border_width_bottom = 1
	hover.border_color = base_color.lightened(0.35)
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("hover", hover)

func connect_overflow_manager(om: OverflowManager) -> void:
	overflow_manager = om
	overflow_manager.quiver_changed.connect(_on_quiver_changed)
	if _ready_complete:
		_refresh_display()

func _on_quiver_changed() -> void:
	_refresh_display()

func _refresh_display() -> void:
	if not _ready_complete:
		return
	if not overflow_manager:
		visible = false
		return

	var quiver_cards = overflow_manager.get_quiver_zone()
	if quiver_cards.size() == 0:
		visible = false
		_quiver_open = false
		_selected_card_index = -1
		return

	visible = true
	_title_label.text = "Quiver: %d card%s" % [quiver_cards.size(), "s" if quiver_cards.size() != 1 else ""]

	if _quiver_open:
		_open_button.text = "Close Quiver"
		_cards_area.visible = true
		_rebuild_cards(quiver_cards)
	else:
		_open_button.text = "Open Quiver"
		_cards_area.visible = false

func _rebuild_cards(quiver_cards: Array[Card]) -> void:
	# Clear existing card buttons
	for child in _cards_hbox.get_children():
		child.queue_free()

	_selected_card_index = -1
	_targeting_area.visible = false

	for i in range(quiver_cards.size()):
		var card = quiver_cards[i]
		var card_btn = _make_card_panel(card, i)
		_cards_hbox.add_child(card_btn)

func _make_card_panel(card: Card, index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 150)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.35, 0.35, 0.5)
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card_style.content_margin_left = 6.0
	card_style.content_margin_right = 6.0
	card_style.content_margin_top = 6.0
	card_style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", card_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	# Card name
	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_lbl)

	# Cost
	var cost_lbl = Label.new()
	cost_lbl.text = "%dM/%dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_lbl)

	# Type
	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Always Attack
	vbox.add_child(type_lbl)

	# Range tag
	if card.is_ranged:
		var range_lbl = Label.new()
		range_lbl.text = card.get_range_display()
		range_lbl.add_theme_font_size_override("font_size", 10)
		range_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		range_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(range_lbl)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))
	vbox.add_child(sep)

	# Description (short)
	var desc_lbl = Label.new()
	desc_lbl.text = card.description
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_lbl)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# "Play" button at bottom
	var play_btn = Button.new()
	play_btn.text = "Play"
	play_btn.add_theme_font_size_override("font_size", 11)
	play_btn.pressed.connect(_on_quiver_card_selected.bind(index))
	_apply_button_style(play_btn, Color(0.15, 0.3, 0.15))
	vbox.add_child(play_btn)

	return panel

func _on_open_button_pressed() -> void:
	_quiver_open = !_quiver_open
	_selected_card_index = -1
	_targeting_area.visible = false
	_refresh_display()

func _on_quiver_card_selected(index: int) -> void:
	if not overflow_manager:
		return
	var quiver_cards = overflow_manager.get_quiver_zone()
	if index < 0 or index >= quiver_cards.size():
		return

	_selected_card_index = index
	var card = quiver_cards[index]
	_show_targeting_buttons(card, index)

func _show_targeting_buttons(card: Card, index: int) -> void:
	# Remove old targeting buttons (keep label and cancel)
	for child in _targeting_area.get_children():
		if child != _target_label and child != _cancel_button:
			child.queue_free()

	_target_label.text = "Playing '%s' - choose target:" % card.card_name

	# Add targeting buttons based on card's target_types
	var target_types = card.target_types

	if "enemy" in target_types:
		var btn = Button.new()
		btn.text = "Enemy"
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_targeting_chosen.bind(index, "enemy"))
		_apply_button_style(btn, Color(0.35, 0.1, 0.1))
		_targeting_area.add_child(btn)
		_targeting_area.move_child(btn, _targeting_area.get_child_count() - 2)

	if "point" in target_types:
		var btn = Button.new()
		btn.text = "Point"
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_targeting_chosen.bind(index, "point"))
		_apply_button_style(btn, Color(0.15, 0.15, 0.35))
		_targeting_area.add_child(btn)
		_targeting_area.move_child(btn, _targeting_area.get_child_count() - 2)

	if "self" in target_types or "ally" in target_types or "all_nearby" in target_types:
		var btn = Button.new()
		btn.text = "Self"
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_targeting_chosen.bind(index, "self"))
		_apply_button_style(btn, Color(0.15, 0.3, 0.15))
		_targeting_area.add_child(btn)
		_targeting_area.move_child(btn, _targeting_area.get_child_count() - 2)

	_targeting_area.visible = true

func _on_targeting_chosen(index: int, target_type: String) -> void:
	if not overflow_manager:
		return
	var quiver_cards = overflow_manager.get_quiver_zone()
	if index < 0 or index >= quiver_cards.size():
		return

	var card = quiver_cards[index]
	quiver_card_targeting_selected.emit(card, index, target_type)
	_targeting_area.visible = false
	_selected_card_index = -1

func _on_cancel_pressed() -> void:
	_targeting_area.visible = false
	_selected_card_index = -1

func refresh() -> void:
	_refresh_display()
