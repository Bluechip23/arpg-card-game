class_name JailedIconUI
extends PanelContainer

## HUD badge for jailed cards, shown in the top status rows with the buffs and
## debuffs. A small cage with an xN count when more than one card is jailed;
## hovering lists every jailed card as "Card Name: description" with its
## remaining jail time. Clicking opens the jail pile popup.

signal pressed

const BADGE_W := 30
const BADGE_H := 30

# Jail purple (matches the jail pile popup title colour).
const JAIL_COLOR := Color(0.85, 0.45, 0.85)

var _cards: Array = []
var _count_label: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(BADGE_W, BADGE_H)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = JAIL_COLOR.darkened(0.65)
	style.border_color = JAIL_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", style)

	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var glyph := TextureRect.new()
	glyph.texture = UIGlyphs.get_glyph("cage")
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
	## Called whenever the jail pile changes.
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
	style.border_color = JAIL_COLOR
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
	title.text = "Jailed Cards"
	title.add_theme_color_override("font_color", JAIL_COLOR)
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
		var time_txt := ""
		if card.jail_time_remaining > 0:
			time_txt = " [color=#8888aa](%d tempo left)[/color]" % card.jail_time_remaining
		line.text = "[b][i]%s[/i][/b]: %s%s" % [card.card_name, card.description, time_txt]
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(line)

	var hint = Label.new()
	hint.text = "Click icon to view the jail pile"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

	return panel
