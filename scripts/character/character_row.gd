class_name CharacterRow
extends PanelContainer

## One hero on the Choose Your Character screen, laid out after the
## designer's board (assets/sprites/paintings/character_select_board.webp,
## 2026-10-23): the portrait, the name in the hero's colour with what the
## hero is rewarded for under it, then the hero's four passive trees — each
## headed by the tree's (archetype's) name, its three passives as icon squares
## beneath (twelve in all). Hovering a square explains the passive; hovering
## the portrait or name shows the hero's unique passive and slots. Clicking
## anywhere on the row chooses the hero.
##
## The Customize row (the questionnaire) has a "?" in place of the portrait
## and no trees: they come from the player's answers.

signal selected(character: CharacterData)

const PORTRAIT_BOX := Vector2(96, 100)
const TEXT_WIDTH := 230.0
const SECTION_GAP := 22

var character_data: CharacterData = null
var _style: StyleBoxFlat = null
var _hover_style: StyleBoxFlat = null


func setup(character: CharacterData, is_customize: bool = false) -> void:
	character_data = character
	name = "Row_%s" % character.get_base_character()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var accent := character.get_accent_color()
	_style = _panel_style(Color(0.08, 0.08, 0.11), Color(0.2, 0.2, 0.28))
	_hover_style = _panel_style(Color(0.11, 0.11, 0.16), accent)
	add_theme_stylebox_override("panel", _style)
	mouse_entered.connect(func(): add_theme_stylebox_override("panel", _hover_style))
	mouse_exited.connect(func():
		# Moving onto a square still counts as over the row.
		if not get_global_rect().has_point(get_global_mouse_position()):
			add_theme_stylebox_override("panel", _style))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	row.add_child(_build_portrait(character, accent, is_customize))
	row.add_child(_build_text(character, accent, is_customize))
	if is_customize:
		var note := Label.new()
		note.text = "Your passive trees come from your answers: pick the archetypes that fit how you play."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", 13)
		note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(note)
		return
	var tree := SkillTreeData.create_tree_for(character.get_base_character())
	var trees := HBoxContainer.new()
	trees.name = "PassiveTrees"
	trees.add_theme_constant_override("separation", SECTION_GAP)
	trees.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trees)
	for lane in tree.get_archetype_lanes():
		trees.add_child(_build_tree_section(lane, accent))


func _build_portrait(character: CharacterData, accent: Color, is_customize: bool) -> Control:
	var frame := PanelContainer.new()
	frame.name = "Portrait"
	frame.custom_minimum_size = PORTRAIT_BOX
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.tooltip_text = _identity_tooltip(character, is_customize)
	frame.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.05, 0.08), accent.darkened(0.35), 0, 0))
	var tex := character.get_portrait() if not is_customize else null
	if tex:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pic)
	else:
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 44)
		q.add_theme_color_override("font_color", accent)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(q)
	return frame


func _build_text(character: CharacterData, accent: Color, is_customize: bool) -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = TEXT_WIDTH
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.name = "Name"
	title.text = character.character_name.to_upper()
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", accent)
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.tooltip_text = _identity_tooltip(character, is_customize)
	vb.add_child(title)
	var blurb := Label.new()
	blurb.name = "RewardedFor"
	blurb.text = character.get_rewarded_for() if not is_customize \
		else "Answer a few questions and build a hero of your own."
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size.x = TEXT_WIDTH
	blurb.add_theme_font_size_override("font_size", 13)
	blurb.add_theme_color_override("font_color", Color(0.86, 0.87, 0.92))
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(blurb)
	return vb


func _build_tree_section(lane: Dictionary, accent: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.name = "Tree_%s" % str(lane["name"]).replace(" ", "")
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := Label.new()
	head.name = "TreeName"
	head.text = str(lane["name"]).to_upper()
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", accent)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(head)
	var squares := HBoxContainer.new()
	squares.alignment = BoxContainer.ALIGNMENT_CENTER
	squares.add_theme_constant_override("separation", 8)
	squares.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(squares)
	var passives: Array = lane["passives"]
	for i in range(passives.size()):
		var sq := PassiveSquare.new()
		sq.setup(passives[i], str(lane["name"]), i, accent)
		squares.add_child(sq)
	return vb


func _identity_tooltip(character: CharacterData, is_customize: bool) -> String:
	if is_customize:
		return "Your unique passive and equipment slots are determined by your answers."
	return "Unique passive: %s\nSlots: %s" % [character.passive_description, character.slot_specialty]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		selected.emit(character_data)


static func _panel_style(bg: Color, border: Color, radius: int = 6, margin: int = -1) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_border_width_all(2)
	st.border_color = border
	st.set_corner_radius_all(radius)
	st.content_margin_left = 12 if margin < 0 else margin
	st.content_margin_right = 12 if margin < 0 else margin
	st.content_margin_top = 10 if margin < 0 else margin
	st.content_margin_bottom = 10 if margin < 0 else margin
	return st
