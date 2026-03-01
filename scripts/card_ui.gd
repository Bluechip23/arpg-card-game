class_name CardUI
extends PanelContainer

## Visual representation of a card in hand

signal card_hovered(card: Card, card_ui: CardUI)
signal card_unhovered()

@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var type_label: Label = $Panel/VBox/TypeLabel
@onready var range_label: Label = $Panel/VBox/RangeLabel
@onready var desc_label: RichTextLabel = $Panel/VBox/DescLabel
@onready var cost_label: Label = $Panel/VBox/CostLabel
@onready var keybind_label: Label = $Panel/VBox/KeybindLabel

var _card: Card
var _index: int
var _selected: bool = false
var _is_hexed: bool = false
var _is_locked: bool = false
var _is_hovered: bool = false
var _base_y: float = 0.0
var _base_z: int = 0

const KEYBIND_LABELS = ["A", "S", "D", "F", "G", "Q", "W", "E", "R", "T", "Z", "X", "C", "V", "B"]

func setup(card: Card, index: int, debuff_mgr: DebuffManager = null) -> void:
	_card = card
	_index = index

	if name_label:
		name_label.text = card.card_name

	if type_label:
		type_label.text = card.card_type_name
		match card.card_type:
			Card.CardType.ATTACK:
				type_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			Card.CardType.DEFENSE:
				type_label.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
			Card.CardType.UTILITY:
				type_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
			Card.CardType.REACTION:
				type_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
			Card.CardType.UNPLAYABLE:
				type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			Card.CardType.POWER:
				type_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))

	if range_label:
		if card.is_ranged:
			range_label.visible = true
			range_label.text = card.get_range_display()
			range_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		else:
			range_label.visible = false

	_update_description()

	# Calculate displayed mana cost with debuff modifiers
	var display_mana = card.mana_cost
	var is_hexed = false
	var is_locked = false

	if debuff_mgr:
		if debuff_mgr.is_card_hexed(index):
			display_mana += debuff_mgr.get_hexed_mana_increase()
			is_hexed = true
		is_locked = debuff_mgr.is_card_locked(index)

	if cost_label:
		if card.maintain_cost > 0:
			cost_label.text = "%dM %dT | Maintain: %dM" % [display_mana, card.tempo_cost, card.maintain_cost]
		else:
			cost_label.text = "%dM %dT" % [display_mana, card.tempo_cost]

		if is_locked:
			cost_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		elif is_hexed:
			cost_label.add_theme_color_override("font_color", Color(0.6, 0.0, 0.6))
		elif card.tempo_cost <= 1:
			cost_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		else:
			cost_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))

	if keybind_label:
		keybind_label.text = _get_keybind_text(index)

	_is_hexed = is_hexed
	_is_locked = is_locked
	_update_visual()

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_default_style()

func store_base_position() -> void:
	_base_y = position.y
	_base_z = z_index

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_visual()
	if _card:
		card_hovered.emit(_card, self)

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_visual()
	card_unhovered.emit()

func _update_description() -> void:
	if not desc_label or not _card:
		return
	# Use colored BBCode description if card has multi-outcome RNG data
	if _card.rng_outcomes_data.size() > 0 and _card.has_been_rolled():
		desc_label.text = _card.get_colored_description()
	else:
		desc_label.text = _card.description

func update_chance_display() -> void:
	# Called when RNG re-rolls happen - update the description colors
	_update_description()

func _update_visual() -> void:
	if _is_locked:
		modulate = Color(0.4, 0.4, 0.4, 0.7)
		position.y = _base_y
		z_index = _base_z
		_clear_gold_trim()
	elif _selected:
		modulate = Color(1, 1, 1)
		position.y = _base_y - 40
		z_index = 100
		_apply_gold_trim()
	elif _is_hovered:
		modulate = Color(1, 1, 1)
		position.y = _base_y
		z_index = 99
		_clear_gold_trim()
	elif _is_hexed:
		modulate = Color(0.8, 0.5, 0.8)
		position.y = _base_y
		z_index = _base_z
		_clear_gold_trim()
	elif _card and _card.is_enhanced:
		modulate = Color(0.5, 1, 0.5)
		position.y = _base_y
		z_index = _base_z
		_clear_gold_trim()
	else:
		modulate = Color(1, 1, 1)
		position.y = _base_y
		z_index = _base_z
		_clear_gold_trim()

func _apply_gold_trim() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.84, 0.0)  # Gold
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)

func _apply_default_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)

func _clear_gold_trim() -> void:
	_apply_default_style()

func _get_keybind_text(index: int) -> String:
	if index >= 0 and index < KEYBIND_LABELS.size():
		return "[%s]" % KEYBIND_LABELS[index]
	return ""

func set_hovered_external(hovered: bool) -> void:
	_is_hovered = hovered
	_update_visual()

func set_selected(selected: bool) -> void:
	_selected = selected
	_update_visual()
