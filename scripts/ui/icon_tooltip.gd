class_name IconTooltip
extends RefCounted

## The hover info windows show the thing's icon large beside its words
## (designer, 2026-10-28): passives, buffs and debuffs. One builder so every
## window sizes and frames the icon alike.

const ICON_SIZE := 64  # px: big enough to read the pack art at a glance

## A framed square holding `icon` at ICON_SIZE, crisp (nearest), on a disc of
## the effect's colour darkened behind it. Null when there is no icon.
static func icon_box(icon: Texture2D, accent: Color = EmeraldTheme.GOLD_DIM) -> Control:
	if icon == null:
		return null
	var frame := PanelContainer.new()
	frame.name = "BigIcon"
	frame.custom_minimum_size = Vector2(ICON_SIZE + 8, ICON_SIZE + 8)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(accent.r, accent.g, accent.b, 1.0).darkened(0.65)
	st.border_color = accent
	st.set_border_width_all(2)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", st)
	var pic := TextureRect.new()
	pic.name = "Icon"
	pic.texture = icon
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)
	return frame

## A whole tooltip body for _make_custom_tooltip: the big icon, then `text`.
static func make(icon: Texture2D, text: String, accent: Color = EmeraldTheme.GOLD_DIM) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var box := icon_box(icon, accent)
	if box:
		row.add_child(box)
	var lbl := Label.new()
	lbl.name = "Text"
	lbl.text = text
	lbl.theme_type_variation = &"TooltipLabel"   # the engine tooltip's own text look
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	return row
