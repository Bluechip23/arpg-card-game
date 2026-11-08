extends RefCounted

## One box per keyword (designer, 2026-11-07: instead of one block listing
## every keyword, each keyword gets its own box with its explanation, in
## text big enough to read). Used by the hand-card popups
## (Main._append_keyword_tooltips) and the KeywordWindow beside card views.

const NAME_SIZE := 16
const TEXT_SIZE := 14
const COLOR_NAME := Color(0.86, 0.62, 1.0)
const COLOR_TEXT := Color(0.9, 0.9, 0.92)
const BG := Color(0.08, 0.06, 0.12, 0.97)
const BORDER := Color(0.55, 0.42, 0.8)

## A box for each keyword the card carries, added to `parent` (a container).
## Returns how many were added.
static func add_for_card(parent: Container, card: Card, width: float = 260.0) -> int:
	if card == null:
		return 0
	var n := 0
	for kw in card.get_matching_keywords():
		parent.add_child(make_box(str(kw["keyword"]), str(kw["definition"]), width))
		n += 1
	return n

## One keyword's box: its name over its explanation.
static func make_box(keyword: String, definition: String, width: float = 260.0) -> PanelContainer:
	var box := PanelContainer.new()
	box.name = "Keyword_" + keyword.capitalize().replace(" ", "")
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(width, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = BG
	st.set_border_width_all(1)
	st.border_color = BORDER
	st.set_corner_radius_all(5)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 7
	box.add_theme_stylebox_override("panel", st)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vb)
	var name_lbl := Label.new()
	name_lbl.text = keyword.capitalize()
	name_lbl.add_theme_font_size_override("font_size", NAME_SIZE)
	name_lbl.add_theme_color_override("font_color", COLOR_NAME)
	vb.add_child(name_lbl)
	var text := Label.new()
	text.text = definition
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(width - 20.0, 0)
	text.add_theme_font_size_override("font_size", TEXT_SIZE)
	text.add_theme_color_override("font_color", COLOR_TEXT)
	vb.add_child(text)
	return box
