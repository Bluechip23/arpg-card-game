class_name CharacterSelect
extends Control

## Character selection screen - supports single player and multiplayer

signal character_selected(character: CharacterData)

@onready var character_container: VBoxContainer = $VBox/ScrollContainer/CharacterContainer

const CARD_LIST_WIDTH := 760.0  # cards centred at a readable width in the vertical list


func _add_card_to_list(card: Control) -> void:
	# add_child first: the card's _ready() applies its default 280px minimum,
	# which the list width must override afterwards.
	character_container.add_child(card)
	card.custom_minimum_size.x = CARD_LIST_WIDTH
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var title_separator: HSeparator = $VBox/TitleSeparator
@onready var back_button: Button = $BackButton
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_title: Label = $ConfirmOverlay/ConfirmPanel/VBox/ConfirmTitle
@onready var confirm_subtitle: Label = $ConfirmOverlay/ConfirmPanel/VBox/ConfirmSubtitle
@onready var proceed_button: Button = $ConfirmOverlay/ConfirmPanel/VBox/ButtonContainer/ProceedButton
@onready var cancel_button: Button = $ConfirmOverlay/ConfirmPanel/VBox/ButtonContainer/CancelButton

const CharacterCardScene = preload("res://scenes/character/character_card.tscn")
const QuestionnaireScene = preload("res://scenes/character/character_questionnaire.tscn")

var game_mode: String = "single_player"  # "single_player", "multiplayer" or "sandbox"
var _is_quiz_character: bool = false  # Track if selected character is the quiz option
var _selected_character: CharacterData = null
var _name_edit: LineEdit = null        # rename field in the confirm dialog

const MAX_NAME_LENGTH := 20

# Multiplayer state
var _player1_character: CharacterData = null
var _player2_character: CharacterData = null
var _selecting_player: int = 1  # Which player is currently selecting (1 or 2)

# ---- Stat allocation (8 points to distribute on a fresh character) ----
const ALLOC_TOTAL := 8
var _allocated: Dictionary = {}          # characters that already allocated
var _alloc_overlay: ColorRect = null
var _alloc_char: CharacterData = null
var _alloc_on_confirm: Callable = Callable()
var _alloc_points: int = 0
var _alloc: Dictionary = {}              # stat key -> allocated points
var _alloc_base: Dictionary = {}         # stat key -> base (3)
var _alloc_value_labels: Dictionary = {}
var _alloc_remaining_lbl: Label = null
var _alloc_confirm_btn: Button = null

func _ready() -> void:
	_apply_styles()
	_setup_characters()
	_update_title_for_mode()
	_setup_name_edit()

	back_button.pressed.connect(_on_back_pressed)
	proceed_button.pressed.connect(_on_proceed_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

func _setup_name_edit() -> void:
	## Rename field in the confirm dialog: the hero keeps their preset kit and
	## story identity, but the player can call them whatever they like.
	var vbox = $ConfirmOverlay/ConfirmPanel/VBox
	if not vbox:
		return
	var row := HBoxContainer.new()
	row.name = "NameRow"
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl := Label.new()
	lbl.text = "Name:"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	row.add_child(lbl)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(220, 34)
	_name_edit.max_length = MAX_NAME_LENGTH
	_name_edit.placeholder_text = "Character name"
	_name_edit.add_theme_font_size_override("font_size", 15)
	row.add_child(_name_edit)
	# Sits between the "Playing as X" subtitle and the Proceed/Cancel buttons.
	vbox.add_child(row)
	vbox.move_child(row, confirm_subtitle.get_index() + 1)

func _apply_rename() -> void:
	## Commit the name field to the selected character (before launch/allocation).
	if not _selected_character or not _name_edit:
		return
	var new_name := _name_edit.text.strip_edges()
	if new_name == "" or new_name == _selected_character.character_name:
		return
	# Old saves predate base_character — lock in their preset identity before
	# the display name changes.
	if _selected_character.base_character == "":
		_selected_character.base_character = _selected_character.character_name
	print("[SELECT] Renamed %s to %s" % [_selected_character.character_name, new_name])
	_selected_character.character_name = new_name

func _update_title_for_mode() -> void:
	if game_mode == "multiplayer":
		_update_multiplayer_title()
	else:
		title_label.text = "Choose Your Character"
		subtitle_label.text = "Each character brings a unique playstyle, passive, and starting equipment.\nNote: the archetypes are character guidelines. You will not be forced to follow any one path and will obtain options from all paths mixing and matching as you please."

func _update_multiplayer_title() -> void:
	if _selecting_player == 1:
		title_label.text = "Player 1 - Choose Your Character"
		subtitle_label.text = "Select the main player's character."
	else:
		title_label.text = "Player 2 - Choose Your Character"
		subtitle_label.text = "Select the secondary player's character."

func _apply_styles() -> void:
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	if subtitle_label:
		subtitle_label.add_theme_font_size_override("font_size", 13)
		subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.72))

	if title_separator:
		title_separator.add_theme_color_override("color", Color(0.3, 0.3, 0.45))

	# Back button style
	if back_button:
		back_button.add_theme_font_size_override("font_size", 16)
		var back_style = StyleBoxFlat.new()
		back_style.bg_color = Color(0.2, 0.2, 0.25)
		back_style.border_width_left = 1
		back_style.border_width_right = 1
		back_style.border_width_top = 1
		back_style.border_width_bottom = 1
		back_style.border_color = Color(0.4, 0.4, 0.5)
		back_style.corner_radius_top_left = 4
		back_style.corner_radius_top_right = 4
		back_style.corner_radius_bottom_left = 4
		back_style.corner_radius_bottom_right = 4
		back_button.add_theme_stylebox_override("normal", back_style)
		var back_hover = StyleBoxFlat.new()
		back_hover.bg_color = Color(0.3, 0.3, 0.35)
		back_hover.border_width_left = 1
		back_hover.border_width_right = 1
		back_hover.border_width_top = 1
		back_hover.border_width_bottom = 1
		back_hover.border_color = Color(0.5, 0.5, 0.6)
		back_hover.corner_radius_top_left = 4
		back_hover.corner_radius_top_right = 4
		back_hover.corner_radius_bottom_left = 4
		back_hover.corner_radius_bottom_right = 4
		back_button.add_theme_stylebox_override("hover", back_hover)

	# Confirm modal styles
	if confirm_title:
		confirm_title.add_theme_font_size_override("font_size", 28)
		confirm_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	if confirm_subtitle:
		confirm_subtitle.add_theme_font_size_override("font_size", 14)
		confirm_subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))

	var confirm_panel = $ConfirmOverlay/ConfirmPanel
	if confirm_panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.4, 0.6)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 30.0
		style.content_margin_right = 30.0
		style.content_margin_top = 25.0
		style.content_margin_bottom = 25.0
		confirm_panel.add_theme_stylebox_override("panel", style)

	# Proceed button style (green)
	if proceed_button:
		proceed_button.add_theme_font_size_override("font_size", 18)
		var proc_style = StyleBoxFlat.new()
		proc_style.bg_color = Color(0.15, 0.3, 0.15)
		proc_style.border_width_left = 2
		proc_style.border_width_right = 2
		proc_style.border_width_top = 2
		proc_style.border_width_bottom = 2
		proc_style.border_color = Color(0.3, 0.6, 0.3)
		proc_style.corner_radius_top_left = 6
		proc_style.corner_radius_top_right = 6
		proc_style.corner_radius_bottom_left = 6
		proc_style.corner_radius_bottom_right = 6
		proceed_button.add_theme_stylebox_override("normal", proc_style)
		var proc_hover = StyleBoxFlat.new()
		proc_hover.bg_color = Color(0.2, 0.4, 0.2)
		proc_hover.border_width_left = 2
		proc_hover.border_width_right = 2
		proc_hover.border_width_top = 2
		proc_hover.border_width_bottom = 2
		proc_hover.border_color = Color(0.4, 0.8, 0.4)
		proc_hover.corner_radius_top_left = 6
		proc_hover.corner_radius_top_right = 6
		proc_hover.corner_radius_bottom_left = 6
		proc_hover.corner_radius_bottom_right = 6
		proceed_button.add_theme_stylebox_override("hover", proc_hover)

	# Cancel button style (red)
	if cancel_button:
		cancel_button.add_theme_font_size_override("font_size", 18)
		var cancel_style = StyleBoxFlat.new()
		cancel_style.bg_color = Color(0.4, 0.12, 0.12)
		cancel_style.border_width_left = 2
		cancel_style.border_width_right = 2
		cancel_style.border_width_top = 2
		cancel_style.border_width_bottom = 2
		cancel_style.border_color = Color(0.7, 0.25, 0.25)
		cancel_style.corner_radius_top_left = 6
		cancel_style.corner_radius_top_right = 6
		cancel_style.corner_radius_bottom_left = 6
		cancel_style.corner_radius_bottom_right = 6
		cancel_button.add_theme_stylebox_override("normal", cancel_style)
		var cancel_hover = StyleBoxFlat.new()
		cancel_hover.bg_color = Color(0.55, 0.18, 0.18)
		cancel_hover.border_width_left = 2
		cancel_hover.border_width_right = 2
		cancel_hover.border_width_top = 2
		cancel_hover.border_width_bottom = 2
		cancel_hover.border_color = Color(1.0, 0.35, 0.35)
		cancel_hover.corner_radius_top_left = 6
		cancel_hover.corner_radius_top_right = 6
		cancel_hover.corner_radius_bottom_left = 6
		cancel_hover.corner_radius_bottom_right = 6
		cancel_button.add_theme_stylebox_override("hover", cancel_hover)

func _setup_characters() -> void:
	# Add "Customize from Inquiry" as the first option (quiz character)
	var quiz_data = CharacterData.new()
	quiz_data.character_name = "Customize"
	quiz_data.strength = 5
	quiz_data.dexterity = 5
	quiz_data.intelligence = 5
	quiz_data.wisdom = 5
	quiz_data.determination = 5
	quiz_data.agility = 5
	quiz_data.base_health = 10
	quiz_data.base_mana = 5
	quiz_data.base_mana_regen = 1.0
	quiz_data.base_draw_timer = 5
	quiz_data.passive_description = "Determined by your answers"
	quiz_data.slot_specialty = "Determined by quiz"
	quiz_data.sprite_path = ""

	# The 5 preset characters first; the Customize quiz card goes last.
	_add_preset_character_cards()

	var quiz_card = CharacterCardScene.instantiate()
	_add_card_to_list(quiz_card)
	quiz_card.setup(quiz_data)
	# Override the sprite label to show "?" instead of "C"
	quiz_card._sprite_label.text = "?"
	quiz_card.selected.connect(_on_character_selected)

func _add_preset_character_cards() -> void:
	var characters = CharacterData.get_all_characters()
	for character in characters:
		var card = CharacterCardScene.instantiate()
		_add_card_to_list(card)
		card.setup(character)
		card.selected.connect(_on_character_selected)
		card.skill_tree_requested.connect(_on_skill_tree_requested)

func _on_character_selected(character: CharacterData) -> void:
	print("[SELECT] Character selected: %s" % character.character_name)

	# If the quiz option was selected, launch the questionnaire
	if character.character_name == "Customize":
		_launch_questionnaire()
		return

	_selected_character = character
	_is_quiz_character = false
	character_selected.emit(character)

	# Show proceed/cancel confirmation
	if game_mode == "multiplayer":
		var player_str = "Player 1" if _selecting_player == 1 else "Player 2"
		confirm_title.text = "Confirm Selection"
		confirm_subtitle.text = "%s: %s" % [player_str, character.character_name]
	else:
		confirm_title.text = "Confirm Selection"
		confirm_subtitle.text = "Playing as %s" % character.character_name
	if _name_edit:
		_name_edit.text = character.character_name
	confirm_overlay.visible = true

func _launch_questionnaire() -> void:
	var quiz_scene = QuestionnaireScene.instantiate()
	get_tree().root.add_child(quiz_scene)
	queue_free()

func _on_proceed_pressed() -> void:
	if not _selected_character:
		return

	_apply_rename()

	# Fresh (non-saved) characters allocate 8 stat points before launching.
	if _needs_allocation(_selected_character) and not _allocated.has(_selected_character):
		confirm_overlay.visible = false
		var character := _selected_character
		_show_stat_allocation(character, func():
			_allocated[character] = true
			_dispatch_proceed())
		return

	_dispatch_proceed()

func _dispatch_proceed() -> void:
	confirm_overlay.visible = false
	if game_mode == "multiplayer":
		_handle_multiplayer_proceed()
	else:
		_handle_singleplayer_proceed()

func _needs_allocation(character: CharacterData) -> bool:
	# Fresh presets get the allocation screen before launching.
	return character != null

# ---- Stat allocation overlay ----

func _show_stat_allocation(character: CharacterData, on_confirm: Callable) -> void:
	_alloc_char = character
	_alloc_on_confirm = on_confirm
	_alloc_points = ALLOC_TOTAL
	_alloc = {}
	_alloc_base = {}
	_alloc_value_labels = {}
	for key in CharacterData.STAT_KEYS:
		_alloc[key] = 0
	_alloc_base = {
		"STR": character.strength, "DEX": character.dexterity, "INT": character.intelligence,
		"WIS": character.wisdom, "DET": character.determination, "AGI": character.agility,
	}

	_alloc_overlay = ColorRect.new()
	_alloc_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alloc_overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	add_child(_alloc_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alloc_overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.16, 1.0)
	style.set_border_width_all(2)
	style.border_color = Color(0.45, 0.6, 0.85)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Allocate Stats — %s" % character.character_name
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "Every hero starts at 3 in each stat. Spend %d points to shape your build —\nhover or read the notes to learn what each stat does." % ALLOC_TOTAL
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.72, 0.72, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	_alloc_remaining_lbl = Label.new()
	_alloc_remaining_lbl.add_theme_font_size_override("font_size", 16)
	_alloc_remaining_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_alloc_remaining_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_alloc_remaining_lbl)

	vb.add_child(HSeparator.new())

	for key in CharacterData.STAT_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = CharacterData.stat_description(key)

		var name_lbl := Label.new()
		name_lbl.text = CharacterData.stat_full_name(key)
		name_lbl.custom_minimum_size = Vector2(120, 0)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		row.add_child(name_lbl)

		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(32, 30)
		minus.pressed.connect(_alloc_add.bind(key, -1))
		row.add_child(minus)

		var val := Label.new()
		val.custom_minimum_size = Vector2(34, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 16)
		val.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
		row.add_child(val)
		_alloc_value_labels[key] = val

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(32, 30)
		plus.pressed.connect(_alloc_add.bind(key, 1))
		row.add_child(plus)

		var desc := Label.new()
		desc.text = CharacterData.stat_description(key)
		desc.custom_minimum_size = Vector2(380, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.66, 0.66, 0.74))
		row.add_child(desc)

		vb.add_child(row)

	vb.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vb.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(110, 36)
	back_btn.pressed.connect(_alloc_cancel)
	btn_row.add_child(back_btn)

	_alloc_confirm_btn = Button.new()
	_alloc_confirm_btn.text = "Confirm"
	_alloc_confirm_btn.custom_minimum_size = Vector2(140, 36)
	_alloc_confirm_btn.pressed.connect(_alloc_confirm)
	btn_row.add_child(_alloc_confirm_btn)

	_alloc_refresh()

func _alloc_add(key: String, delta: int) -> void:
	if delta > 0 and _alloc_points <= 0:
		return
	if delta < 0 and _alloc[key] <= 0:
		return
	_alloc[key] += delta
	_alloc_points -= delta
	_alloc_refresh()

func _alloc_refresh() -> void:
	if _alloc_remaining_lbl:
		_alloc_remaining_lbl.text = "Points to allocate: %d" % _alloc_points
	for key in _alloc_value_labels:
		_alloc_value_labels[key].text = str(_alloc_base.get(key, 0) + _alloc.get(key, 0))
	if _alloc_confirm_btn:
		_alloc_confirm_btn.disabled = _alloc_points != 0

func _alloc_confirm() -> void:
	if _alloc_points != 0 or _alloc_char == null:
		return
	var c := _alloc_char
	c.strength += _alloc.get("STR", 0)
	c.dexterity += _alloc.get("DEX", 0)
	c.intelligence += _alloc.get("INT", 0)
	c.wisdom += _alloc.get("WIS", 0)
	c.determination += _alloc.get("DET", 0)
	c.agility += _alloc.get("AGI", 0)
	var cb := _alloc_on_confirm
	_close_alloc_overlay()
	if cb.is_valid():
		cb.call()

func _alloc_cancel() -> void:
	# Abandon allocation and return to the character confirm dialog.
	_close_alloc_overlay()
	confirm_overlay.visible = true

func _close_alloc_overlay() -> void:
	_alloc_on_confirm = Callable()
	_alloc_char = null
	_alloc_value_labels = {}
	_alloc_remaining_lbl = null
	_alloc_confirm_btn = null
	if _alloc_overlay and is_instance_valid(_alloc_overlay):
		_alloc_overlay.queue_free()
	_alloc_overlay = null

func _handle_singleplayer_proceed() -> void:
	if game_mode == "sandbox":
		_launch_sandbox(_selected_character)
		return
	# Show the mode select (Town vs Fight) as a second confirmation
	_show_mode_select()

func _launch_sandbox(character: CharacterData) -> void:
	print("[SELECT] Starting sandbox as %s" % character.character_name)
	var main_scene = load("res://scenes/core/main.tscn").instantiate()
	main_scene.starting_character = character
	main_scene.sandbox_mode = true
	get_tree().root.add_child(main_scene)
	queue_free()

func _handle_multiplayer_proceed() -> void:
	if _selecting_player == 1:
		_player1_character = _selected_character
		_selected_character = null
		_selecting_player = 2
		_update_multiplayer_title()
		print("[SELECT] Player 1 chose %s, now selecting Player 2" % _player1_character.character_name)
	else:
		_player2_character = _selected_character
		print("[SELECT] Player 2 chose %s" % _player2_character.character_name)
		# Show mode select for multiplayer too
		_show_mode_select()

func _on_cancel_pressed() -> void:
	_selected_character = null
	confirm_overlay.visible = false

func _on_back_pressed() -> void:
	if game_mode == "multiplayer" and _selecting_player == 2:
		# Go back to player 1 selection
		_selecting_player = 1
		_player1_character = null
		_selected_character = null
		_update_multiplayer_title()
		return

	# Go back to Load or New screen (single player) or title menu (other modes)
	if game_mode == "single_player":
		var load_or_new_scene = load("res://scenes/character/load_or_new.tscn").instantiate()
		get_tree().root.add_child(load_or_new_scene)
	else:
		var title_scene = load("res://scenes/menus/title_menu.tscn").instantiate()
		get_tree().root.add_child(title_scene)
	queue_free()

# ---- Mode select (Town vs Fight) ----

var _mode_overlay: ColorRect = null

func _show_mode_select() -> void:
	_mode_overlay = ColorRect.new()
	_mode_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_overlay.color = Color(0.0, 0.0, 0.0, 0.7)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -200.0
	panel.offset_top = -120.0
	panel.offset_right = 200.0
	panel.offset_bottom = 120.0

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	p_style.border_width_left = 2
	p_style.border_width_right = 2
	p_style.border_width_top = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.4, 0.4, 0.6)
	p_style.corner_radius_top_left = 8
	p_style.corner_radius_top_right = 8
	p_style.corner_radius_bottom_left = 8
	p_style.corner_radius_bottom_right = 8
	p_style.content_margin_left = 30.0
	p_style.content_margin_right = 30.0
	p_style.content_margin_top = 25.0
	p_style.content_margin_bottom = 25.0
	panel.add_theme_stylebox_override("panel", p_style)
	_mode_overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var mtitle = Label.new()
	mtitle.text = "Where to?"
	mtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtitle.add_theme_font_size_override("font_size", 28)
	mtitle.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	vbox.add_child(mtitle)

	var char_name = ""
	if game_mode == "multiplayer":
		char_name = "%s & %s" % [_player1_character.character_name, _player2_character.character_name]
	else:
		char_name = _selected_character.character_name
	var msub = Label.new()
	msub.text = "Playing as %s" % char_name
	msub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msub.add_theme_font_size_override("font_size", 14)
	msub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(msub)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(btn_hbox)

	var town_btn = Button.new()
	town_btn.text = "To Town"
	town_btn.custom_minimum_size = Vector2(150, 50)
	town_btn.add_theme_font_size_override("font_size", 18)
	_style_mode_button(town_btn, Color(0.15, 0.3, 0.15), Color(0.2, 0.4, 0.2), Color(0.3, 0.6, 0.3), Color(0.4, 0.8, 0.4))
	town_btn.pressed.connect(_on_mode_town)
	btn_hbox.add_child(town_btn)

	var fight_btn = Button.new()
	fight_btn.text = "Fight"
	fight_btn.custom_minimum_size = Vector2(150, 50)
	fight_btn.add_theme_font_size_override("font_size", 18)
	_style_mode_button(fight_btn, Color(0.4, 0.12, 0.12), Color(0.55, 0.18, 0.18), Color(0.7, 0.25, 0.25), Color(1.0, 0.35, 0.35))
	fight_btn.pressed.connect(_on_mode_fight)
	btn_hbox.add_child(fight_btn)

	add_child(_mode_overlay)

func _style_mode_button(btn: Button, normal_bg: Color, hover_bg: Color, normal_border: Color, hover_border: Color) -> void:
	var ns = StyleBoxFlat.new()
	ns.bg_color = normal_bg
	ns.border_width_left = 2
	ns.border_width_right = 2
	ns.border_width_top = 2
	ns.border_width_bottom = 2
	ns.border_color = normal_border
	ns.corner_radius_top_left = 6
	ns.corner_radius_top_right = 6
	ns.corner_radius_bottom_left = 6
	ns.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", ns)
	var hs = StyleBoxFlat.new()
	hs.bg_color = hover_bg
	hs.border_width_left = 2
	hs.border_width_right = 2
	hs.border_width_top = 2
	hs.border_width_bottom = 2
	hs.border_color = hover_border
	hs.corner_radius_top_left = 6
	hs.corner_radius_top_right = 6
	hs.corner_radius_bottom_left = 6
	hs.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hs)

func _on_mode_town() -> void:
	var character = _player1_character if game_mode == "multiplayer" else _selected_character
	if not character:
		return

	print("[SELECT] Going to town with %s" % character.character_name)
	var town_scene = load("res://scenes/menus/town.tscn").instantiate()
	town_scene.starting_character = character
	get_tree().root.add_child(town_scene)
	queue_free()

func _on_mode_fight() -> void:
	var character = _player1_character if game_mode == "multiplayer" else _selected_character
	if not character:
		return

	print("[SELECT] Going to fight with %s" % character.character_name)
	var main_scene = load("res://scenes/core/main.tscn").instantiate()
	main_scene.starting_character = character
	if game_mode == "multiplayer" and _player2_character:
		main_scene.player2_character = _player2_character
		main_scene.is_multiplayer = true
	get_tree().root.add_child(main_scene)
	queue_free()

# ---- Skill Tree Popup ----

var _skill_tree_overlay: ColorRect = null

func _on_skill_tree_requested(character: CharacterData) -> void:
	if character.get_base_character() == "Customize":
		return
	_show_skill_tree_popup(character)

func _show_skill_tree_popup(character: CharacterData) -> void:
	if _skill_tree_overlay:
		_skill_tree_overlay.queue_free()

	# Get the skill tree data for this character (preset identity survives renames)
	var tree: SkillTreeData = _get_skill_tree_for_character(character.get_base_character())
	if not tree:
		return

	# Build overlay
	_skill_tree_overlay = ColorRect.new()
	_skill_tree_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill_tree_overlay.color = Color(0.0, 0.0, 0.0, 0.8)

	# Main panel
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60.0
	panel.offset_top = 40.0
	panel.offset_right = -60.0
	panel.offset_bottom = -40.0

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	p_style.border_width_left = 2
	p_style.border_width_right = 2
	p_style.border_width_top = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.4, 0.4, 0.6)
	p_style.corner_radius_top_left = 8
	p_style.corner_radius_top_right = 8
	p_style.corner_radius_bottom_left = 8
	p_style.corner_radius_bottom_right = 8
	p_style.content_margin_left = 20.0
	p_style.content_margin_right = 20.0
	p_style.content_margin_top = 15.0
	p_style.content_margin_bottom = 15.0
	panel.add_theme_stylebox_override("panel", p_style)
	_skill_tree_overlay.add_child(panel)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(outer_vbox)

	# Header row with title and close button
	var header_hbox = HBoxContainer.new()
	outer_vbox.add_child(header_hbox)

	var title = Label.new()
	title.text = "%s - Skill Tree" % character.character_name
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.custom_minimum_size = Vector2(40, 40)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.4, 0.12, 0.12)
	close_style.corner_radius_top_left = 4
	close_style.corner_radius_top_right = 4
	close_style.corner_radius_bottom_left = 4
	close_style.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("normal", close_style)
	var close_hover = StyleBoxFlat.new()
	close_hover.bg_color = Color(0.55, 0.18, 0.18)
	close_hover.corner_radius_top_left = 4
	close_hover.corner_radius_top_right = 4
	close_hover.corner_radius_bottom_left = 4
	close_hover.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("hover", close_hover)
	close_btn.pressed.connect(_on_skill_tree_close)
	header_hbox.add_child(close_btn)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))
	outer_vbox.add_child(sep)

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 6)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vbox)

	# Extract passives from the skill tree rows
	# Description format is "Name (Archetype): Description"
	var passives_by_archetype: Dictionary = {}
	for row in tree.rows:
		for option in row.options:
			if option.option_type == SkillTreeData.OptionType.PASSIVE:
				var arch := "General"
				var desc := option.description
				# Parse archetype from description: "Name (Archetype): Description"
				var paren_start = desc.find("(")
				var paren_end = desc.find(")")
				if paren_start >= 0 and paren_end > paren_start:
					arch = desc.substr(paren_start + 1, paren_end - paren_start - 1)
					# Clean description to just the part after ": "
					var colon_pos = desc.find(": ", paren_end)
					if colon_pos >= 0:
						desc = desc.substr(colon_pos + 2)
				if not passives_by_archetype.has(arch):
					passives_by_archetype[arch] = []
				passives_by_archetype[arch].append({
					"level": row.level,
					"name": option.name,
					"description": desc,
					"color": option.icon_color
				})

	# Group by archetype
	var archetype_names = passives_by_archetype.keys()
	for arch in archetype_names:
		var arch_header = Label.new()
		arch_header.text = arch
		arch_header.add_theme_font_size_override("font_size", 16)
		arch_header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.5))
		content_vbox.add_child(arch_header)

		var arch_passives = passives_by_archetype[arch]
		arch_passives.sort_custom(func(a, b): return a["level"] < b["level"])
		for p in arch_passives:
			var row_hbox = _create_passive_row(p)
			content_vbox.add_child(row_hbox)

		var arch_sep = HSeparator.new()
		arch_sep.add_theme_color_override("color", Color(0.2, 0.2, 0.3))
		content_vbox.add_child(arch_sep)

	add_child(_skill_tree_overlay)

func _create_passive_row(p: Dictionary) -> HBoxContainer:
	var row_hbox = HBoxContainer.new()
	row_hbox.add_theme_constant_override("separation", 10)

	# Level badge
	var level_label = Label.new()
	level_label.text = "Lv %d" % p["level"]
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
	level_label.custom_minimum_size.x = 40
	row_hbox.add_child(level_label)

	# Color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(4, 0)
	color_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	color_rect.color = p.get("color", Color.WHITE)
	row_hbox.add_child(color_rect)

	# Name and description
	var text_vbox = VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_hbox.add_child(text_vbox)

	var name_label = Label.new()
	name_label.text = p["name"]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", p.get("color", Color.WHITE))
	text_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = p["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	text_vbox.add_child(desc_label)

	return row_hbox

func _on_skill_tree_close() -> void:
	if _skill_tree_overlay:
		_skill_tree_overlay.queue_free()
		_skill_tree_overlay = null

func _get_skill_tree_for_character(char_name: String) -> SkillTreeData:
	match char_name:
		"Ryan":
			return SkillTreeData.create_ryan_tree()
		"Brad":
			return SkillTreeData.create_brad_tree()
		"Stephen":
			return SkillTreeData.create_stephen_tree()
		"Cory":
			return SkillTreeData.create_cory_tree()
		"Jeremy":
			return SkillTreeData.create_jeremy_tree()
	# Custom questionnaire character - use archetypes if available
	if _selected_character and _selected_character.archetypes.size() > 0:
		return SkillTreeData.create_placeholder_tree(char_name, 20, _selected_character.archetypes)
	return null
