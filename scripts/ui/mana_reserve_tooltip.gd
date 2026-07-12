class_name ManaReserveTooltip
extends Control

## Invisible overlay on the mana bar. While maintained Power cards are
## reserving mana, hovering the bar shows how much each card reserves:
## "Card Name: NM reserved".

const POWER_COLOR := Color(0.8, 0.5, 1.0)

var _cards: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

func set_cards(cards: Array) -> void:
	_cards = cards.duplicate()
	# Non-empty tooltip text is what makes Godot call _make_custom_tooltip;
	# with nothing reserved the bar has no tooltip at all.
	tooltip_text = " " if _cards.size() > 0 else ""

func _make_custom_tooltip(_for_text: String) -> Control:
	if _cards.size() == 0:
		return null

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.5, 1.0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Reserved Mana"
	title.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(title)

	var total := 0
	for card in _cards:
		total += card.maintain_cost
		var line = RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 200
		line.add_theme_font_size_override("normal_font_size", 13)
		line.add_theme_font_size_override("bold_italics_font_size", 13)
		line.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
		line.text = "[b][i]%s[/i][/b]: %dM reserved" % [card.card_name, card.maintain_cost]
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(line)

	if _cards.size() > 1:
		var total_lbl = Label.new()
		total_lbl.text = "Total: %dM" % total
		total_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		total_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(total_lbl)

	return panel
