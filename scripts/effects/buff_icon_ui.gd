class_name BuffIconUI
extends PanelContainer

## Visual display for a single buff

const BADGE := 30  # px — a small round badge

var buff: Buff
var _glyph_rect: TextureRect = null
var _count_label: Label = null
var _built: bool = false

func setup(b: Buff) -> void:
	buff = b
	update_display()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

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
	# xN count pinned to the bottom-right corner.
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 11)
	_count_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_count_label.add_theme_constant_override("outline_size", 4)
	_count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count_label.offset_left = -18
	_count_label.offset_top = -14
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_count_label)

func _badge_count() -> int:
	## The number shown as xN: charges for charge-based, else stacks, else -1.
	if buff.is_charge_based() and buff.charges > 0:
		return buff.charges
	if buff.stacks > 1:
		return buff.stacks
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

	tooltip_text = buff.buff_name

func _make_custom_tooltip(for_text: String) -> Control:
	if not buff:
		return null

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = buff.get_icon_color()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = buff.buff_name
	title.add_theme_color_override("font_color", buff.get_icon_color())
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = buff.description
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.add_theme_font_size_override("font_size", 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size.x = 200
	vbox.add_child(desc)

	var dur = Label.new()
	dur.text = buff.get_duration_display()
	dur.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	dur.add_theme_font_size_override("font_size", 12)
	vbox.add_child(dur)

	if buff.source_name != "":
		var source = Label.new()
		source.text = "Source: %s" % buff.source_name
		source.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		source.add_theme_font_size_override("font_size", 11)
		vbox.add_child(source)

	return panel
