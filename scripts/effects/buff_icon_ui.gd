class_name BuffIconUI
extends PanelContainer

## Visual display for a single buff

const BADGE := 30  # px — a small round badge

var buff: Buff
var buff_manager: BuffManager = null  # set by the bar; enables click behavior
var _glyph_rect: TextureRect = null
var _count_label: Label = null
var _built: bool = false

func setup(b: Buff) -> void:
	buff = b
	update_display()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)

func _exit_tree() -> void:
	StatusHoverPopup.hide_for(self)

func _on_hover_in() -> void:
	## The hover window: what the buff does and how long is left (live).
	if buff == null:
		return
	var b := buff
	StatusHoverPopup.show_for(self, b.buff_name, b.get_icon_color(), b.description,
		func() -> String:
			if not is_instance_valid(b):
				return ""
			return "Remaining: %s" % b.get_duration_display(),
		("Source: %s" % b.source_name) if b.source_name != "" else "")

func _on_hover_out() -> void:
	StatusHoverPopup.hide_for(self)

func _gui_input(event: InputEvent) -> void:
	## The Precious: while in shadow form, clicking the Invisible badge steps
	## back out — allowed only after at least 1 tempo spent inside.
	if not (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if buff == null or buff.buff_type != Buff.BuffType.INVISIBLE:
		return
	if buff_manager == null or buff_manager.owner_stats == null:
		return
	var stats = buff_manager.owner_stats
	if stats.shadow_form_tempo <= 0:
		return
	# The counter starts at 10 and ticks per tempo — still at 10 means not a
	# single tempo has passed inside yet.
	if stats.shadow_form_tempo >= 10:
		print("[BUFF UI] Shadow form holds — spend at least 1 tempo inside first")
		return
	accept_event()
	stats.exit_shadow_form()

func _build_badge() -> void:
	## A compact round badge: type-coloured circle, glyph, and an xN count.
	if _built:
		return
	_built = true
	# Drop the old name/duration card layout from the scene.
	for child in get_children():
		child.queue_free()
	custom_minimum_size = Vector2(BADGE, BADGE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_glyph_rect = TextureRect.new()
	_glyph_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glyph_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glyph_rect.offset_left = 3
	_glyph_rect.offset_top = 2
	_glyph_rect.offset_right = -3
	_glyph_rect.offset_bottom = -4
	_glyph_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_glyph_rect)
	# xN count: a pill centred on the badge's bottom edge.
	_count_label = _make_count_pill()
	holder.add_child(_count_label)

static func _make_count_pill() -> Label:
	## The "xN" chip: a small dark pill centred on the badge's bottom edge,
	## hanging a few pixels below the circle so the count reads as a label
	## under the effect rather than a scribble over its glyph.
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.06, 0.09, 0.95)
	st.set_border_width_all(1)
	st.border_color = Color(0.8, 0.8, 0.8)
	st.set_corner_radius_all(6)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	lbl.add_theme_stylebox_override("normal", st)
	lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_END
	lbl.offset_left = -11
	lbl.offset_right = 11
	lbl.offset_top = -10
	lbl.offset_bottom = 3
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 1
	return lbl

func _badge_count() -> int:
	## The number shown as xN — what is left of the effect: charges for
	## charge-based buffs, else stacks, else the remaining count of a buff
	## that burns its value down per use (Thorns lose 1 per hit, Regen 1 per
	## cycle). Timed-only buffs show no count; the hover window has the clock.
	if buff.is_charge_based() and buff.charges > 0:
		return buff.charges
	if buff.stacks > 1:
		return buff.stacks
	if buff.value > 0 and buff.buff_type in [Buff.BuffType.THORNS, Buff.BuffType.REGEN]:
		return buff.value
	return -1

func update_display() -> void:
	if not buff:
		return
	_build_badge()

	# Round badge tinted by the buff colour, glyph on top.
	var col := buff.get_icon_color()
	var style := StyleBoxFlat.new()
	style.bg_color = col.darkened(0.5)
	style.border_color = col
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	var r := BADGE / 2
	style.corner_radius_top_left = r
	style.corner_radius_top_right = r
	style.corner_radius_bottom_left = r
	style.corner_radius_bottom_right = r
	add_theme_stylebox_override("panel", style)

	var tex := StatusIcons.get_icon(buff.get_icon_key())
	_glyph_rect.texture = tex
	_glyph_rect.visible = tex != null

	var n := _badge_count()
	_count_label.text = ("x%d" % n) if n > 0 else ""
	_count_label.visible = n > 0
	var pill := _count_label.get_theme_stylebox("normal") as StyleBoxFlat
	if pill:
		pill.border_color = col.lightened(0.2)

	# No engine tooltip: the StatusHoverPopup window is the badge's one and
	# only hover window (and this script defines no _make_custom_tooltip).
	tooltip_text = ""
