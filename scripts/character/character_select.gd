class_name CharacterSelect
extends Control

## Character selection screen - supports single player and multiplayer


@onready var character_container: VBoxContainer = $VBox/ScrollContainer/CharacterContainer

## The heroes are listed one row each (CharacterRow, after the designer's
## select-screen board): portrait, name and what the hero is rewarded for,
## then its four passive trees with their twelve passives.
const ROW_WIDTH := 1170.0


func _add_row_to_list(row: Control) -> void:
	character_container.add_child(row)
	row.custom_minimum_size.x = ROW_WIDTH
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var title_separator: HSeparator = $VBox/TitleSeparator
@onready var back_button: Button = $BackButton
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_title: Label = $ConfirmOverlay/ConfirmPanel/VBox/ConfirmTitle
@onready var confirm_subtitle: Label = $ConfirmOverlay/ConfirmPanel/VBox/ConfirmSubtitle
@onready var proceed_button: Button = $ConfirmOverlay/ConfirmPanel/VBox/ButtonContainer/ProceedButton
@onready var cancel_button: Button = $ConfirmOverlay/ConfirmPanel/VBox/ButtonContainer/CancelButton

const QuestionnaireScene = preload("res://scenes/character/character_questionnaire.tscn")

var game_mode: String = "single_player"  # "single_player", "multiplayer" or "sandbox"
var boss_sim: bool = false  # sandbox that opens on the boss-fight picker (Test > Boss Simulator)
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
		subtitle_label.text = "Each character brings a unique playstyle, passive, and equipment slots.\nNote: the archetypes are character guidelines. You will not be forced to follow any one path and will obtain options from all paths mixing and matching as you please."

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
	# The 5 preset heroes first; the Customize (questionnaire) row goes last.
	for character in CharacterData.get_all_characters():
		var row := CharacterRow.new()
		row.setup(character)
		_add_row_to_list(row)
		row.selected.connect(_on_character_selected)

	var quiz_data = CharacterData.new()
	quiz_data.character_name = "Customize"
	quiz_data.passive_description = "Determined by your answers"
	quiz_data.slot_specialty = "Determined by quiz"
	var quiz_row := CharacterRow.new()
	quiz_row.setup(quiz_data, true)
	_add_row_to_list(quiz_row)
	quiz_row.selected.connect(_on_character_selected)

func _on_character_selected(character: CharacterData) -> void:
	print("[SELECT] Character selected: %s" % character.character_name)

	# If the quiz option was selected, launch the questionnaire
	if character.character_name == "Customize":
		_launch_questionnaire()
		return

	_selected_character = character
	_is_quiz_character = false

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

	# The stat rows live in a scroll capped to the window height, so the
	# Back/Confirm buttons below always stay on-screen — no more tabbing blind.
	var rows_scroll := ScrollContainer.new()
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vp_h := get_viewport_rect().size.y
	rows_scroll.custom_minimum_size = Vector2(660, clampf(vp_h - 340.0, 180.0, 420.0))
	vb.add_child(rows_scroll)
	var rows_vb := VBoxContainer.new()
	rows_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_vb.add_theme_constant_override("separation", 8)
	rows_scroll.add_child(rows_vb)

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

		rows_vb.add_child(row)

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
	# Every journey starts at home: straight to town, where Olorin waits.
	_go_to_town()

func _launch_sandbox(character: CharacterData) -> void:
	print("[SELECT] Starting sandbox as %s" % character.character_name)
	var main_scene = load("res://scenes/core/main.tscn").instantiate()
	main_scene.starting_character = character
	main_scene.sandbox_mode = true
	main_scene.boss_sim_pick = boss_sim
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
		_go_to_town()

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

# ---- Into town ----

func _go_to_town() -> void:
	var character = _player1_character if game_mode == "multiplayer" else _selected_character
	if not character:
		return

	print("[SELECT] Going to town with %s" % character.character_name)
	var town_scene = load("res://scenes/menus/town.tscn").instantiate()
	town_scene.starting_character = character
	if game_mode == "multiplayer" and _player2_character:
		town_scene.player2_character = _player2_character
	get_tree().root.add_child(town_scene)
	queue_free()
