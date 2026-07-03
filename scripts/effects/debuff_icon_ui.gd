class_name DebuffIconUI
extends PanelContainer

## Visual display for a single debuff

@onready var icon_rect: ColorRect = $IconRect
@onready var name_label: Label = $IconRect/VBox/NameLabel
@onready var duration_label: Label = $IconRect/VBox/DurationLabel

var debuff: Debuff
var _glyph_rect: TextureRect = null

func setup(d: Debuff) -> void:
	debuff = d
	update_display()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _glyph() -> TextureRect:
	## Pixel-art badge drawn behind the labels (created on first use).
	if _glyph_rect and is_instance_valid(_glyph_rect):
		return _glyph_rect
	_glyph_rect = TextureRect.new()
	_glyph_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glyph_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glyph_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.add_child(_glyph_rect)
	icon_rect.move_child(_glyph_rect, 0)
	return _glyph_rect

func update_display() -> void:
	if not debuff:
		return

	if icon_rect:
		var tex := StatusIcons.get_icon(debuff.debuff_name)
		if tex:
			# Badge glyph over a darkened tint of the debuff colour.
			icon_rect.color = debuff.get_icon_color().darkened(0.62)
			_glyph().texture = tex
		else:
			icon_rect.color = debuff.get_icon_color()

	if name_label:
		name_label.text = debuff.debuff_name

	if duration_label:
		if debuff.duration < 0:
			duration_label.text = "∞"
		else:
			duration_label.text = str(debuff.duration)

	tooltip_text = debuff.debuff_name

func _make_custom_tooltip(for_text: String) -> Control:
	if not debuff:
		return null

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = debuff.get_icon_color()
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
	title.text = debuff.debuff_name
	title.add_theme_color_override("font_color", debuff.get_icon_color())
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = debuff.description
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.add_theme_font_size_override("font_size", 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size.x = 200
	vbox.add_child(desc)

	var dur = Label.new()
	if debuff.duration < 0:
		dur.text = "Duration: Permanent"
	else:
		dur.text = "Duration: %d turn(s)" % debuff.duration
	dur.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	dur.add_theme_font_size_override("font_size", 12)
	vbox.add_child(dur)

	if debuff.stacks > 1:
		var stacks_label = Label.new()
		stacks_label.text = "Stacks: %d" % debuff.stacks
		stacks_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		stacks_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(stacks_label)

	return panel
