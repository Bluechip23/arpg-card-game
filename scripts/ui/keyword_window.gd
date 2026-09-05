class_name KeywordWindow
extends PanelContainer

## A small companion window that sits beside a card view — the chest loot
## modal, the card-inventory confirm popup — and spells out every keyword the
## card carries (Burden, Sticky, Glut, Maintain, Arrow...) with its rules
## text. The card face only has room for the word; this is where the player
## learns what the word means without opening the help compendium.
##
## Usage (both call sites are synchronous builders, so placement is deferred
## inside this node):
##     var kw := KeywordWindow.for_card(card)
##     if kw:
##         parent.add_child(kw)
##         kw.place_beside(modal)

const WIDTH := 236.0
const GAP := 10.0
const COLOR_TITLE := Color(0.9, 0.8, 0.4)
const COLOR_KEYWORD := Color(0.8, 0.53, 1.0)
const COLOR_TEXT := Color(0.85, 0.85, 0.88)

## Builds the window for `card`, or returns null when the card has no
## keywords (so callers never show an empty box).
static func for_card(card: Card) -> KeywordWindow:
	if card == null:
		return null
	var keywords: Array = card.get_matching_keywords()
	if keywords.is_empty():
		return null
	var win := KeywordWindow.new()
	win._build(keywords)
	return win

func _build(keywords: Array) -> void:
	name = "KeywordWindow"
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks here don't fall through to the dim overlay
	z_index = 210  # above the card popup it accompanies

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.1, 0.97)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.42, 0.8)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var title := Label.new()
	title.text = "Keywords"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	for kw in keywords:
		var entry := RichTextLabel.new()
		entry.bbcode_enabled = true
		entry.fit_content = true
		entry.scroll_active = false
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.custom_minimum_size = Vector2(WIDTH - 20.0, 0)
		entry.add_theme_font_size_override("normal_font_size", 11)
		entry.add_theme_color_override("default_color", COLOR_TEXT)
		# Colour alone carries the keyword name: the default font has no bold
		# face, and the faux-bold fallback draws it doubled.
		entry.text = "[color=#%s]%s[/color] — %s" % [
			COLOR_KEYWORD.to_html(false), kw["keyword"], kw["definition"]]
		vbox.add_child(entry)

## Park this window just right of `host` (same parent, top edges aligned),
## or on its left when the right side would leave the screen. Waits for the
## layout pass so both rects are final — callers that centre their popup a
## frame later are covered too.
func place_beside(host: Control) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(host) or not is_instance_valid(self):
		return
	var screen_w := get_viewport_rect().size.x
	var x := host.position.x + host.size.x + GAP
	if x + size.x > screen_w - 4.0:
		x = host.position.x - size.x - GAP
	x = maxf(4.0, x)
	position = Vector2(x, host.position.y)
