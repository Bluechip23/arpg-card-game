class_name CardUI
extends PanelContainer

## Visual representation of a card in hand

@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var type_label: Label = $Panel/VBox/TypeLabel
@onready var desc_label: Label = $Panel/VBox/DescLabel
@onready var cost_label: Label = $Panel/VBox/CostLabel
@onready var keybind_label: Label = $Panel/VBox/KeybindLabel
@onready var chance_label: Label = $VBox/ChanceLabel

var _card: Card
var _index: int
var _selected: bool = false

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
	
	if desc_label:
		desc_label.text = card.description
	
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
		cost_label.text = "%dM %dT" % [display_mana, card.tempo_cost]
		
		if is_locked:
			cost_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		elif is_hexed:
			cost_label.add_theme_color_override("font_color", Color(0.6, 0.0, 0.6))
		elif card.tempo_cost == 0:
			cost_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		else:
			cost_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	
	if keybind_label:
		keybind_label.text = _get_keybind_text(index)
	
	if chance_label:
		if card.has_chance_effect():
			chance_label.visible = true
			chance_label.text = "%.0f%% %s" % [card.chance_effect_percent, card.chance_effect_description]
			update_chance_display()
		else:
			chance_label.visible = false
	
	_is_hexed = is_hexed
	_is_locked = is_locked
	_update_visual()

var _is_hexed: bool = false
var _is_locked: bool = false

func _update_visual() -> void:
	if _is_locked:
		modulate = Color(0.4, 0.4, 0.4, 0.7)  # Grayed out
	elif _selected:
		modulate = Color(1, 1, 0.5)
	elif _is_hexed:
		modulate = Color(0.8, 0.5, 0.8)  # Purple tint
	elif _card and _card.is_enhanced:
		modulate = Color(0.5, 1, 0.5)
	else:
		modulate = Color(1, 1, 1)

func _get_keybind_text(index: int) -> String:
	if index >= 0 and index < KEYBIND_LABELS.size():
		return "[%s]" % KEYBIND_LABELS[index]
	return ""

func set_selected(selected: bool) -> void:
	_selected = selected
	_update_visual()
func update_chance_display() -> void:
	if not chance_label or not _card or not _card.has_chance_effect():
		return
	
	# Check if any RNG outcome is success (for single target, check if any enemy will succeed)
	var any_success = false
	for outcome in _card.rng_outcomes.values():
		if outcome:
			any_success = true
			break
	
	if _card.rng_outcomes.is_empty():
		# No roll yet - neutral color
		chance_label.add_theme_color_override("font_color", Color(1, 1, 1))
	elif any_success:
		# Will trigger on at least one target - green
		chance_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	else:
		# Won't trigger - red
		chance_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
