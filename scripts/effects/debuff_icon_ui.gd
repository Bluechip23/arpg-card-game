class_name DebuffIconUI
extends PanelContainer

## Visual display for a single debuff

const BADGE := 30  # px — a small round badge

var debuff: Debuff
var _glyph_rect: TextureRect = null
var _count_label: Label = null
var _built: bool = false

func setup(d: Debuff) -> void:
	debuff = d
	update_display()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)

func _exit_tree() -> void:
	StatusHoverPopup.hide_for(self)

func _on_hover_in() -> void:
	## The hover window: what the debuff does and how long is left (live).
	if debuff == null:
		return
	var d := debuff
	var extra := ""
	if d.stacks > 1:
		extra = "Stacks: %d" % d.stacks
	if d.source_name != "":
		extra += ("\n" if extra != "" else "") + "Source: %s" % d.source_name
	StatusHoverPopup.show_for(self, d.debuff_name, d.get_icon_color(), d.description,
		func() -> String:
			if not is_instance_valid(d):
				return ""
			if d.duration < 0:
				return "Remaining: until cleansed"
			return "Remaining: %d tempo" % d.duration,
		extra)

func _on_hover_out() -> void:
	StatusHoverPopup.hide_for(self)

func _build_badge() -> void:
	## A compact round badge: type-coloured circle, glyph, and an xN count.
	if _built:
		return
	_built = true
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

## Debuffs that only run on the clock (or whose value is not a count, like
## Hexed's +X mana): they show no xN — the hover window has the clock.
const NO_COUNT_TYPES := [Debuff.DebuffType.STUN, Debuff.DebuffType.SILENCE, Debuff.DebuffType.DISARM,
	Debuff.DebuffType.FROZEN, Debuff.DebuffType.ROOTED, Debuff.DebuffType.CURSED, Debuff.DebuffType.CUFFED,
	Debuff.DebuffType.LOCKED, Debuff.DebuffType.HEXED]

func _badge_count() -> int:
	## xN — what is left of the debuff: stacks when >1, else its value (the
	## charges of Bleed 3, Poison 2, ...). Timed-only debuffs (Stun, Silence,
	## a clock-timed Slowed) show no count; the hover window has the clock.
	if debuff.stacks > 1:
		return debuff.stacks
	if debuff.clock_timed or debuff.debuff_type in NO_COUNT_TYPES:
		return -1
	if debuff.value > 0:
		return debuff.value
	return -1

func update_display() -> void:
	if not debuff:
		return
	_build_badge()

	var col := debuff.get_icon_color()
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

	var tex := StatusIcons.get_icon(debuff.debuff_name)
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
