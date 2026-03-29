class_name CardUI
extends PanelContainer

## Visual representation of a card in hand with tween animations

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
var _base_x: float = 0.0
var _base_z: int = 0
var _base_rotation: float = 0.0  # Fan rotation angle

# Animation
var _hover_tween: Tween = null
var _select_tween: Tween = null
var _is_animating_out: bool = false  # True while play/discard animation runs

const KEYBIND_LABELS = ["A", "S", "D", "F", "G", "Q", "W", "E", "R", "T", "Z", "X", "C", "V", "B"]
const HOVER_LIFT: float = 15.0
const SELECT_LIFT: float = 40.0
const TWEEN_DURATION: float = 0.12

func setup(card: Card, index: int, debuff_mgr: DebuffManager = null, dex_proc_active: bool = false, pocket_knife: bool = false) -> void:
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
			Card.CardType.ENCHANTMENT:
				type_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))

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
	var display_tempo = card.tempo_cost
	var is_hexed = false
	var is_locked = false
	var is_dex_proc = false

	# Dex proc preview: show reduced mana and half tempo for attack cards
	if dex_proc_active and card.card_type == Card.CardType.ATTACK:
		display_mana = max(0, display_mana - 2)
		display_tempo = display_tempo / 2
		# Pocket Knife: additional -2 tempo and resolve on first tick
		if pocket_knife:
			display_tempo = maxi(0, display_tempo - 2)
		is_dex_proc = true

	if debuff_mgr:
		if debuff_mgr.is_card_hexed(index):
			display_mana += debuff_mgr.get_hexed_mana_increase()
			is_hexed = true
		is_locked = debuff_mgr.is_card_locked(index)

	if cost_label:
		if is_dex_proc:
			if card.maintain_cost > 0:
				cost_label.text = "%dM %dT | Maintain: %dM" % [display_mana, display_tempo, card.maintain_cost]
			else:
				cost_label.text = "%dM %dT" % [display_mana, display_tempo]
		elif card.maintain_cost > 0:
			cost_label.text = "%dM %dT | Maintain: %dM" % [display_mana, display_tempo, card.maintain_cost]
		else:
			cost_label.text = "%dM %dT" % [display_mana, display_tempo]

		if is_locked:
			cost_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		elif is_hexed:
			cost_label.add_theme_color_override("font_color", Color(0.6, 0.0, 0.6))
		elif is_dex_proc:
			cost_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif card.tempo_cost <= 1:
			cost_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
		else:
			cost_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))

	if keybind_label:
		var kb_text = _get_keybind_text(index)
		if card.is_slotted():
			kb_text += " \u2234"  # Upside-down triangle dots (∴) for slotted cards
			keybind_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		keybind_label.text = kb_text

	_is_hexed = is_hexed
	_is_locked = is_locked

	# Build tempo tick bars (thin vertical cylinders showing resolve tick)
	if is_dex_proc:
		var halved_resolve: int
		if pocket_knife and display_tempo > 0:
			halved_resolve = 1  # Pocket Knife: always resolve on first tick
		else:
			halved_resolve = card.resolve_tick / 2
			halved_resolve = maxi(halved_resolve, mini(1, display_tempo))  # At least tick 1 if there's any tempo
		_build_tempo_bars(card, display_tempo, halved_resolve)
	else:
		_build_tempo_bars(card)

	_update_visual_instant()

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_default_style()
	pivot_offset = Vector2(60, 160)  # Bottom-center pivot for fan rotation

func store_base_position() -> void:
	_base_y = position.y
	_base_x = position.x
	_base_z = z_index

func set_fan_rotation(angle_deg: float) -> void:
	_base_rotation = angle_deg
	rotation_degrees = angle_deg

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
	## Tweened version of visual update for hover/select transitions.
	if _is_animating_out:
		return

	_kill_hover_tween()

	var target_y: float = _base_y
	var target_mod: Color = Color(1, 1, 1)
	var target_rot: float = _base_rotation

	if _is_locked:
		target_mod = Color(0.4, 0.4, 0.4, 0.7)
		z_index = _base_z
		_clear_gold_trim()
	elif _selected:
		target_y = _base_y - SELECT_LIFT
		target_rot = 0.0  # Straighten selected card
		z_index = 100
		_apply_gold_trim()
	elif _is_hovered:
		target_y = _base_y - HOVER_LIFT
		target_rot = _base_rotation * 0.3  # Reduce rotation on hover
		z_index = 99
		_clear_gold_trim()
	elif _is_hexed:
		target_mod = Color(0.8, 0.5, 0.8)
		z_index = _base_z
		_clear_gold_trim()
	elif _card and _card.is_upgraded:
		target_mod = Color(1.0, 0.9, 0.6)  # Gold tint for upgraded cards
	elif _card and _card.is_enhanced:
		target_mod = Color(0.5, 1, 0.5)
		z_index = _base_z
		_clear_gold_trim()
	else:
		z_index = _base_z
		_clear_gold_trim()

	_hover_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_hover_tween.set_parallel(true)
	_hover_tween.tween_property(self, "position:y", target_y, TWEEN_DURATION)
	_hover_tween.tween_property(self, "modulate", target_mod, TWEEN_DURATION)
	_hover_tween.tween_property(self, "rotation_degrees", target_rot, TWEEN_DURATION)

func _update_visual_instant() -> void:
	## Non-tweened version for initial setup.
	if _is_locked:
		modulate = Color(0.4, 0.4, 0.4, 0.7)
		position.y = _base_y
		z_index = _base_z
		_clear_gold_trim()
	elif _selected:
		modulate = Color(1, 1, 1)
		position.y = _base_y - SELECT_LIFT
		z_index = 100
		_apply_gold_trim()
	elif _is_hovered:
		modulate = Color(1, 1, 1)
		position.y = _base_y - HOVER_LIFT
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

func _kill_hover_tween() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
		_hover_tween = null

# ============================================
# ANIMATION HELPERS (called by main.gd)
# ============================================

func animate_draw_in(from_pos: Vector2, final_pos: Vector2, delay: float = 0.0) -> void:
	## Animate card sliding from draw pile area into its hand position.
	position = from_pos
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	rotation_degrees = -15.0

	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if delay > 0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(self, "position", final_pos, 0.3)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	tween.tween_property(self, "rotation_degrees", _base_rotation, 0.25)

func animate_slide_to(target_pos: Vector2, duration: float = 0.2) -> void:
	## Smoothly slide card to a new hand position (rearrange).
	_base_x = target_pos.x
	_base_y = target_pos.y
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position", target_pos, duration)

func animate_play(target_screen_pos: Vector2, on_complete: Callable = Callable()) -> void:
	## Card lifts, scales up briefly, flies to target, fades out.
	_is_animating_out = true
	_kill_hover_tween()
	z_index = 200

	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# Phase 1: Lift and scale up
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 30, 0.1)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.1)

	# Phase 2: Fly to target and fade
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_screen_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.05)

	tween.chain()
	tween.tween_callback(func():
		if on_complete.is_valid():
			on_complete.call()
		queue_free()
	)

func animate_discard(discard_pos: Vector2, on_complete: Callable = Callable()) -> void:
	## Card sweeps to the discard pile area and fades.
	_is_animating_out = true
	_kill_hover_tween()
	z_index = 200

	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(self, "position", discard_pos, 0.3)
	tween.tween_property(self, "rotation_degrees", 25.0, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.05)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)

	tween.chain()
	tween.tween_callback(func():
		if on_complete.is_valid():
			on_complete.call()
		queue_free()
	)

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

func _build_tempo_bars(card: Card, tempo_override: int = -1, resolve_override: int = -1) -> void:
	## Add thin vertical bars at the bottom of the card showing tempo ticks.
	## The highlighted bar indicates the resolve tick.
	var effective_tempo = tempo_override if tempo_override >= 0 else card.tempo_cost
	if effective_tempo <= 0:
		return

	var vbox = $Panel/VBox
	if not vbox:
		return

	# Remove existing tempo bar container if re-setup
	var existing = vbox.get_node_or_null("TempoBarContainer")
	if existing:
		existing.queue_free()

	var bar_container = HBoxContainer.new()
	bar_container.name = "TempoBarContainer"
	bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_container.add_theme_constant_override("separation", 2)
	bar_container.custom_minimum_size.y = 16
	vbox.add_child(bar_container)

	# Get the card type color for the resolve tick highlight
	var highlight_color: Color
	match card.card_type:
		Card.CardType.ATTACK:
			highlight_color = Color(1.0, 0.3, 0.3)
		Card.CardType.DEFENSE:
			highlight_color = Color(0.3, 0.5, 1.0)
		Card.CardType.UTILITY:
			highlight_color = Color(0.3, 1.0, 0.3)
		Card.CardType.POWER:
			highlight_color = Color(0.8, 0.5, 1.0)
		_:
			highlight_color = Color(1.0, 0.85, 0.4)

	var dim_color = Color(0.2, 0.2, 0.28)
	var resolve_tick = resolve_override if resolve_override >= 0 else mini(card.resolve_tick, effective_tempo)

	for i in range(effective_tempo):
		var bar = ColorRect.new()
		bar.custom_minimum_size = Vector2(4, 14)
		if i + 1 == resolve_tick:
			# This is the resolve tick - highlighted
			bar.color = highlight_color
		else:
			bar.color = dim_color
		bar_container.add_child(bar)

func set_hovered_external(hovered: bool) -> void:
	_is_hovered = hovered
	_update_visual()

func set_selected(selected: bool) -> void:
	_selected = selected
	_update_visual()
