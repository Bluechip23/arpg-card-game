class_name MaintainedIconUI
extends PanelContainer

## HUD badge for active maintained Power cards, shown in the top status row
## next to HP and the other buffs. One shared card icon with an xN count
## (like buff/debuff stacks); hovering lists every maintained card as
## "Card Name: description". Clicking opens the maintained-cards list panel
## (where cards can be dismissed).

signal pressed

# Card-shaped badge: slightly narrower than the round 30px buff badges.
const BADGE_W := 26
const BADGE_H := 32

# Power-card purple (matches the Power frame colour in CardUI).
const POWER_COLOR := Color(0.8, 0.5, 1.0)

var _cards: Array = []
var _count_label: Label = null

static var _glyph_cache: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(BADGE_W, BADGE_H)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = POWER_COLOR.darkened(0.6)
	style.border_color = POWER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", style)

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var glyph := TextureRect.new()
	glyph.texture = _get_card_glyph()
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 3
	glyph.offset_top = 3
	glyph.offset_right = -3
	glyph.offset_bottom = -3
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glyph)

	# xN count pinned to the bottom-right corner (same look as buff badges).
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

	_refresh()

func set_cards(cards: Array) -> void:
	## Called whenever the maintained-card set changes.
	_cards = cards.duplicate()
	_refresh()

func _refresh() -> void:
	visible = _cards.size() > 0
	if _count_label:
		_count_label.text = ("x%d" % _cards.size()) if _cards.size() > 1 else ""
	# Non-empty tooltip text is what makes Godot call _make_custom_tooltip.
	tooltip_text = " " if _cards.size() > 0 else ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()

func _make_custom_tooltip(_for_text: String) -> Control:
	if _cards.size() == 0:
		return null

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_border_width_all(2)
	style.border_color = POWER_COLOR
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Maintained Cards"
	title.add_theme_color_override("font_color", POWER_COLOR)
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	for card in _cards:
		var line = RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 260
		line.add_theme_font_size_override("normal_font_size", 13)
		line.add_theme_font_size_override("bold_italics_font_size", 13)
		line.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
		line.text = "[b][i]%s[/i][/b]: %s" % [card.card_name, card.description]
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(line)

	var hint = Label.new()
	hint.text = "Click icon to manage"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

	return panel

static func _get_card_glyph() -> Texture2D:
	## Tiny pixel-art playing card: white rounded card face with text lines,
	## drawn once and cached (same style as StatusIcons badges).
	if _glyph_cache:
		return _glyph_cache
	var sz := 24
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var face := Color(0.96, 0.94, 0.88)
	var edge := Color(0.35, 0.2, 0.5)
	var ink := Color(0.45, 0.3, 0.6)
	# Card body (rounded by clipping the 4 corner pixels).
	for y in range(2, 22):
		for x in range(6, 18):
			var corner := (x == 6 or x == 17) and (y == 2 or y == 21)
			if corner:
				continue
			var border := x == 6 or x == 17 or y == 2 or y == 21
			img.set_pixel(x, y, edge if border else face)
	# Art box + text lines on the face.
	for y in range(5, 10):
		for x in range(9, 15):
			img.set_pixel(x, y, ink.lightened(0.35))
	for lx in range(9, 15):
		img.set_pixel(lx, 13, ink)
		img.set_pixel(lx, 16, ink)
	for lx in range(9, 13):
		img.set_pixel(lx, 18, ink)
	_glyph_cache = ImageTexture.create_from_image(img)
	return _glyph_cache
