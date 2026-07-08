class_name CardUI
extends PanelContainer

## Visual representation of a card in hand with tween animations

signal card_hovered(card: Card, card_ui: CardUI)
signal card_unhovered()

@onready var name_label: Label = $Panel/VBox/TitleBar/TitleHBox/NameLabel
@onready var type_label: Label = $Panel/VBox/TypeBar/TypeHBox/TypeLabel
@onready var range_label: Label = $Panel/VBox/TypeBar/TypeHBox/RangeLabel
@onready var desc_label: RichTextLabel = $Panel/VBox/DescPanel/DescLabel
@onready var cost_label: Label = $Panel/VBox/TitleBar/TitleHBox/CostLabel
@onready var title_bar: PanelContainer = $Panel/VBox/TitleBar
@onready var type_bar: PanelContainer = $Panel/VBox/TypeBar
@onready var art_box: PanelContainer = $Panel/VBox/ArtBox
@onready var desc_panel: PanelContainer = $Panel/VBox/DescPanel

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

const CARD_W: float = 150.0
const CARD_H: float = 210.0
const HOVER_LIFT: float = 68.0
const SELECT_LIFT: float = 96.0
const TWEEN_DURATION: float = 0.12

# MtG-style frame colour per card type (border, title/type bars, art tint).
var _type_color: Color = Color(0.45, 0.45, 0.55)

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
				_type_color = Color(0.72, 0.25, 0.22)
			Card.CardType.DEFENSE:
				type_label.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
				_type_color = Color(0.25, 0.4, 0.72)
			Card.CardType.UTILITY:
				type_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
				_type_color = Color(0.25, 0.6, 0.32)
			Card.CardType.REACTION:
				type_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
				_type_color = Color(0.75, 0.6, 0.15)
			Card.CardType.UNPLAYABLE:
				type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
				_type_color = Color(0.4, 0.4, 0.44)
			Card.CardType.POWER:
				type_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
				_type_color = Color(0.5, 0.3, 0.68)
			Card.CardType.ENCHANTMENT:
				type_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
				_type_color = Color(0.18, 0.58, 0.55)
		_style_frame()

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

	_is_hexed = is_hexed
	_is_locked = is_locked

	# Card-affecting debuffs tint the whole card face (matches the status badge
	# designs): Locked = golden, Hexed = purple, Weighted = grey,
	# Staggered = grey on attack cards, Clumsy = brown.
	var tint := Color.WHITE
	if is_locked:
		tint = Color(1.0, 0.85, 0.45)
	elif is_hexed:
		tint = Color(0.82, 0.6, 1.0)
	elif debuff_mgr and debuff_mgr.get_tempo_increase() > 0:
		tint = Color(0.72, 0.72, 0.76)
	elif debuff_mgr and card.card_type == Card.CardType.ATTACK and debuff_mgr.get_attack_mana_increase() > 0:
		tint = Color(0.78, 0.78, 0.8)
	elif debuff_mgr and debuff_mgr.has_debuff(Debuff.DebuffType.CLUMSY):
		tint = Color(0.85, 0.7, 0.55)
	modulate = Color(tint.r, tint.g, tint.b, modulate.a)

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
	pivot_offset = Vector2(CARD_W * 0.5, CARD_H)  # Bottom-center pivot for fan rotation
	_ensure_badge()

# ============================================
# FLOATING PLAY BADGE + STACK DEPTH
# ============================================

var _keybind_badge: PanelContainer = null
var _badge_label: Label = null
var _stack_shadows: Array = []

func _ensure_badge() -> void:
	## The play button floats just above the card (rather than inside it) so the
	## card face has more room and the key is readable without hovering.
	if _keybind_badge and is_instance_valid(_keybind_badge):
		return
	var host: Node = get_node_or_null("Panel")
	if host == null:
		return
	_keybind_badge = PanelContainer.new()
	_keybind_badge.name = "KeybindBadge"
	_keybind_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.12, 0.96)
	style.set_border_width_all(2)
	style.border_color = _type_color.lightened(0.15)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_keybind_badge.add_theme_stylebox_override("panel", style)
	host.add_child(_keybind_badge)

	_badge_label = Label.new()
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_size_override("font_size", 15)
	_badge_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_keybind_badge.add_child(_badge_label)
	_keybind_badge.resized.connect(_reposition_badge)

func set_keybind_badge(letter: String, count: int = 1, slotted: bool = false) -> void:
	## Set the floating play button's key letter and stack count (xN).
	_ensure_badge()
	if not _badge_label:
		return
	var txt := "[%s]" % letter
	if count > 1:
		txt += " x%d" % count
	if slotted:
		txt += " ∴"  # slotted-card marker (∴)
		_badge_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	else:
		_badge_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_badge_label.text = txt
	# Border picks up the card's type colour.
	var style: StyleBoxFlat = _keybind_badge.get_theme_stylebox("panel")
	if style:
		style.border_color = _type_color.lightened(0.2)
	_reposition_badge()

func _reposition_badge() -> void:
	if not _keybind_badge or not is_instance_valid(_keybind_badge):
		return
	# Centred just above the card's top edge (re-centres whenever the badge
	# resizes to fit longer text like "[A] x3").
	var w: float = _keybind_badge.size.x
	_keybind_badge.position = Vector2(CARD_W * 0.5 - w * 0.5, -30.0)

func set_stack_depth(count: int) -> void:
	## Show a small "pile" of offset card backs behind this card when it
	## represents a stack of identical cards.
	for s in _stack_shadows:
		if is_instance_valid(s):
			s.queue_free()
	_stack_shadows.clear()
	var host: Node = get_node_or_null("Panel")
	if host == null:
		return
	var extra: int = clampi(count - 1, 0, 3)
	for k in range(extra, 0, -1):
		var shadow := Panel.new()
		shadow.show_behind_parent = true  # draw behind the card face
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.size = Vector2(CARD_W, CARD_H)
		# Peek out to the top-right so the pile reads as several stacked cards.
		shadow.position = Vector2(k * 4.0, -k * 4.0)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.11, 0.1, 0.09, 1.0)
		st.set_border_width_all(2)
		st.border_color = _type_color.darkened(0.3)
		st.set_corner_radius_all(9)
		shadow.add_theme_stylebox_override("panel", st)
		host.add_child(shadow)
		host.move_child(shadow, 0)  # keep shadows beneath the VBox contents
		_stack_shadows.append(shadow)

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

func get_card() -> Card:
	return _card


## The shared "sucked into the discard pile" finish: the card is pulled toward
## the pile as if squeezing into a too-small tube — the bottom edge narrows
## first (pivot sits at the bottom-centre so the base converges before the
## rest), then the whole card stretches thin and vanishes into the pile.
func _tube_suck_to(tween: Tween, discard_pos: Vector2, on_complete: Callable = Callable()) -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)
	# Bottom narrows first...
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.5, 1.08), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# ...then the rest funnels in after it.
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(self, "position", discard_pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.06, 1.4), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation_degrees", -12.0, 0.28)
	tween.tween_property(self, "modulate:a", 0.0, 0.12).set_delay(0.18)
	tween.chain()
	tween.tween_callback(func():
		if on_complete.is_valid():
			on_complete.call()
		queue_free()
	)


func animate_played_to_discard(discard_pos: Vector2, on_complete: Callable = Callable()) -> void:
	## Played/discarded card: pops up, pauses a beat, then is sucked into the
	## discard pile bottom-first.
	_is_animating_out = true
	_kill_hover_tween()
	z_index = 200

	var tween = create_tween()
	# Pop up and hold.
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 46, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", 0.0, 0.14)
	tween.chain()
	tween.tween_interval(0.22)
	_tube_suck_to(tween, discard_pos, on_complete)


func animate_instant(discard_pos: Vector2, on_complete: Callable = Callable()) -> void:
	## Instant (reaction) trigger: the card pops up, spins twice on the spot,
	## then is sucked into the discard pile like any other discard.
	_is_animating_out = true
	_kill_hover_tween()
	z_index = 200
	pivot_offset = size * 0.5

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 56, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain()
	# Two full spins.
	tween.tween_property(self, "rotation_degrees", rotation_degrees + 720.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.08)
	_tube_suck_to(tween, discard_pos, on_complete)


func animate_disintegrate(on_complete: Callable = Callable()) -> void:
	## Erase expiring: the card crumbles into drifting particles right in the
	## hand — no discard pile, it is simply gone.
	_is_animating_out = true
	_kill_hover_tween()
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Scatter fragments sampled across the card's face.
	var frag_colors := [Color(0.75, 0.75, 0.8), Color(0.55, 0.55, 0.62), Color(0.9, 0.9, 0.95)]
	for i in range(26):
		var frag := ColorRect.new()
		frag.color = frag_colors[i % frag_colors.size()]
		frag.size = Vector2(randf_range(4, 9), randf_range(4, 9))
		frag.position = Vector2(randf_range(0, size.x), randf_range(0, size.y))
		frag.z_index = 210
		add_child(frag)
		var drift := Vector2(randf_range(-50, 50), randf_range(-90, -30))
		var ftw := frag.create_tween().set_parallel(true)
		var dur := randf_range(0.45, 0.8)
		ftw.tween_property(frag, "position", frag.position + drift, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ftw.tween_property(frag, "modulate:a", 0.0, dur)
		ftw.tween_property(frag, "rotation_degrees", randf_range(-180, 180), dur)

	# The card body flashes pale, shudders, and dissolves under the fragments.
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.4, 1.4, 1.5, 1.0), 0.1)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + 14, 0.4)
	tween.chain()
	tween.tween_interval(0.5)  # let the fragments finish drifting
	tween.tween_callback(func():
		if on_complete.is_valid():
			on_complete.call()
		queue_free()
	)


func show_sticky_counter(uses: int, max_uses: int) -> void:
	## Sticky card staying in hand: a use counter pops up over the card, holds,
	## and fades as the card settles back into the hand.
	var counter := Label.new()
	counter.text = "%d/%d" % [uses, max_uses]
	counter.add_theme_font_size_override("font_size", 26)
	counter.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	counter.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.0))
	counter.add_theme_constant_override("outline_size", 6)
	counter.z_index = 220
	add_child(counter)
	counter.position = Vector2(size.x * 0.5 - 22, -34)
	counter.pivot_offset = Vector2(22, 16)
	counter.scale = Vector2.ZERO
	var tw := counter.create_tween()
	tw.tween_property(counter, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(counter, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(counter, "position:y", -58.0, 0.35)
	tw.tween_callback(counter.queue_free)


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
	## Every discard shares the pop-pause-and-tube-suck.
	animate_played_to_discard(discard_pos, on_complete)

func _apply_gold_trim() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.1, 0.09, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.84, 0.0)  # Gold
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	add_theme_stylebox_override("panel", style)

func _apply_default_style() -> void:
	# MtG-style outer frame: a thick dark "card back" edge with the type's
	# colour glowing through the inner border.
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.1, 0.09, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = _type_color.darkened(0.25)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	add_theme_stylebox_override("panel", style)


func _bar_style(bg: Color, radius: int = 4) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.05, 0.05, 0.05, 0.9)
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


func _style_frame() -> void:
	## Dress the inner frame like a trading card: coloured title bar, framed
	## art window (placeholder until real artwork lands), type line, and a
	## parchment-dark rules box.
	_apply_default_style()
	if title_bar:
		title_bar.add_theme_stylebox_override("panel", _bar_style(_type_color.darkened(0.45)))
	if type_bar:
		type_bar.add_theme_stylebox_override("panel", _bar_style(_type_color.darkened(0.55), 3))
	if art_box:
		var art = _bar_style(_type_color.darkened(0.72), 3)
		art.border_color = _type_color.lightened(0.05)
		art.content_margin_top = 0
		art.content_margin_bottom = 0
		art_box.add_theme_stylebox_override("panel", art)
	if desc_panel:
		var box = _bar_style(Color(0.17, 0.16, 0.14), 3)
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		desc_panel.add_theme_stylebox_override("panel", box)

func _clear_gold_trim() -> void:
	_apply_default_style()

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
