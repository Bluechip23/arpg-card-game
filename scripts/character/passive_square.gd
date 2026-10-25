class_name PassiveSquare
extends Panel

## One passive on the Choose Your Character screen: the passive's pack icon
## (SkillIconArt, the same art the in-battle passive tray shows) in a square
## trimmed in the hero's colour. Hovering it opens a tooltip with what the
## passive is: its name, archetype and stage, what its first point does and
## what it grows to at full rank (PassiveScaling, as the passive tree shows).
## Clicks pass through to the hero's row (it selects the hero).

const SIZE := Vector2(52, 52)

var option: SkillTreeData.SkillOption = null
var archetype := ""
var stage := 0
var accent := Color.WHITE


func setup(opt: SkillTreeData.SkillOption, lane_name: String, stage_index: int, color: Color) -> void:
	option = opt
	archetype = lane_name
	stage = stage_index
	accent = color
	name = "Passive_%s" % opt.passive_id
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Non-empty tooltip text is what makes Godot call _make_custom_tooltip.
	tooltip_text = opt.name
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.06)
	style.set_border_width_all(2)
	style.border_color = color.darkened(0.25)
	style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = SkillIconArt.passive(opt.passive_id, lane_name)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)
	if icon.texture == null:
		# No pack art resolved: the passive's initial stands in.
		var letter := Label.new()
		letter.text = opt.name.left(1)
		letter.set_anchors_preset(Control.PRESET_FULL_RECT)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", 22)
		letter.add_theme_color_override("font_color", color)
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(letter)


## The rules text without the "Name (Archetype): " prefix the tree data adds.
func rules_text() -> String:
	var body: String = option.description
	var prefix := "%s (%s): " % [option.name, option.archetype]
	if body.begins_with(prefix):
		body = body.substr(prefix.length())
	return body


## The tooltip's lines, plain (also what tests read).
func tooltip_lines() -> Array[String]:
	var body := rules_text()
	var max_rank: int = SkillTreeData.PASSIVE_MAX_LEVEL
	var lines: Array[String] = []
	lines.append("%s · Stage %d" % [archetype, stage + 1])
	lines.append("First point: %s" % PassiveScaling.describe_at_rank(option.passive_id, body, 1))
	var top := PassiveScaling.describe_at_rank(option.passive_id, body, max_rank)
	if top != PassiveScaling.describe_at_rank(option.passive_id, body, 1):
		lines.append("At rank %d: %s" % [max_rank, top])
	return lines


func _make_custom_tooltip(_for_text: String) -> Control:
	if option == null:
		return null
	# The game's tooltip frame (UiTheme) holds this; the name carries the colour.
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = option.name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", accent)
	vb.add_child(title)
	var lines := tooltip_lines()
	for i in range(lines.size()):
		var lbl := Label.new()
		lbl.text = lines[i]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size.x = 320
		lbl.add_theme_font_size_override("font_size", 12 if i > 0 else 11)
		lbl.add_theme_color_override("font_color", Color(0.86, 0.86, 0.9) if i > 0 else Color(0.6, 0.6, 0.72))
		vb.add_child(lbl)
	return vb
