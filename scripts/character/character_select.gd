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
var _confirm_portrait_frame: PanelContainer = null  # the hero's portrait in the confirm dialog
var _confirm_portrait: TextureRect = null

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
	_setup_confirm_portrait()

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
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	row.add_child(lbl)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(220, 34)
	_name_edit.max_length = MAX_NAME_LENGTH
	_name_edit.placeholder_text = "Character name"
	_name_edit.add_theme_font_size_override("font_size", 17)
	row.add_child(_name_edit)
	# Sits between the subtitle (and portrait) and the Proceed/Cancel buttons.
	vbox.add_child(row)
	vbox.move_child(row, confirm_subtitle.get_index() + 1)

## The confirm dialog shows the chosen hero's portrait under "Play as X",
## framed in the hero's colour (designer, 2026-10-24).
const CONFIRM_PORTRAIT_SIZE := Vector2(192, 200)   # the portraits' stored size

func _setup_confirm_portrait() -> void:
	var vbox = $ConfirmOverlay/ConfirmPanel/VBox
	if not vbox:
		return
	_confirm_portrait_frame = PanelContainer.new()
	_confirm_portrait_frame.name = "ConfirmPortrait"
	_confirm_portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_portrait = TextureRect.new()
	_confirm_portrait.name = "Picture"
	_confirm_portrait.custom_minimum_size = CONFIRM_PORTRAIT_SIZE
	_confirm_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_confirm_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_confirm_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_confirm_portrait_frame.add_child(_confirm_portrait)
	vbox.add_child(_confirm_portrait_frame)
	vbox.move_child(_confirm_portrait_frame, confirm_title.get_index() + 1)
	if _name_edit:
		# The title follows a new name as it is typed.
		_name_edit.text_changed.connect(func(t: String):
			if _selected_character:
				confirm_title.text = "Play as %s" % (t.strip_edges() if t.strip_edges() != "" else _selected_character.character_name))

func _show_confirm_portrait(character: CharacterData) -> void:
	if not _confirm_portrait_frame:
		return
	var tex: Texture2D = character.get_portrait()
	_confirm_portrait_frame.visible = tex != null
	_confirm_portrait.texture = tex
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.02, 0.07, 0.06)
	st.set_border_width_all(2)
	st.border_color = character.get_accent_color().darkened(0.2)
	st.set_corner_radius_all(4)
	_confirm_portrait_frame.add_theme_stylebox_override("panel", st)

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
	EmeraldTheme.apply(self, true, 0.5)
	if title_label:
		EmeraldTheme.style_title(title_label, 40)
	if subtitle_label:
		subtitle_label.add_theme_font_size_override("font_size", 15)
		subtitle_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	if back_button:
		EmeraldTheme.style_button(back_button, 16)

	# Confirm modal: dark glass over a veil, gold-framed.
	if confirm_overlay:
		confirm_overlay.color = Color(0.0, 0.03, 0.02, 0.72)
	if confirm_title:
		EmeraldTheme.style_title(confirm_title, 34)
	if confirm_subtitle:
		confirm_subtitle.add_theme_font_size_override("font_size", 17)
		confirm_subtitle.add_theme_color_override("font_color", EmeraldTheme.GOLD)
	var confirm_panel = $ConfirmOverlay/ConfirmPanel
	if confirm_panel:
		confirm_panel.add_theme_stylebox_override("panel",
			EmeraldTheme.panel_box(EmeraldTheme.PANEL_BG_SOLID, EmeraldTheme.PALETTE["btn_hover_border"], 2, 8, 28.0))
	for btn in [proceed_button, cancel_button]:
		if btn:
			EmeraldTheme.style_button(btn, 20)
	if proceed_button:
		EmeraldTheme.add_ring_markers(proceed_button)

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
	_open_confirm(character)

## The questionnaire's "Play as …": its built character goes straight to the
## Play-as confirmation (rename, Proceed). Its stats came from the answers,
## so it skips the stat allocation the presets get.
func select_quiz_character(character: CharacterData) -> void:
	_selected_character = character
	_is_quiz_character = true
	_open_confirm(character)

func _open_confirm(character: CharacterData) -> void:
	# Show proceed/cancel confirmation
	confirm_title.text = "Play as %s" % character.character_name
	if game_mode == "multiplayer":
		confirm_subtitle.text = "Player 1" if _selecting_player == 1 else "Player 2"
		confirm_subtitle.visible = true
	else:
		confirm_subtitle.text = ""
		confirm_subtitle.visible = false
	_show_confirm_portrait(character)
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
	# Fresh presets get the allocation screen before launching; a quiz
	# character's answers already shaped its stats.
	return character != null and not (_is_quiz_character and character == _selected_character)

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
	_alloc_overlay.color = Color(0.0, 0.03, 0.02, 0.78)
	add_child(_alloc_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alloc_overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := EmeraldTheme.panel_box(EmeraldTheme.PANEL_BG_SOLID, EmeraldTheme.PALETTE["btn_hover_border"], 2, 8, 22.0)
	style.content_margin_left = 26
	style.content_margin_right = 26
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Allocate Stats — %s" % character.character_name
	EmeraldTheme.style_title(title, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "Every hero starts at 3 in each stat. Spend %d points to shape your build —\nhover or read the notes to learn what each stat does." % ALLOC_TOTAL
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	_alloc_remaining_lbl = Label.new()
	_alloc_remaining_lbl.add_theme_font_size_override("font_size", 19)
	_alloc_remaining_lbl.add_theme_color_override("font_color", EmeraldTheme.GOLD)
	_alloc_remaining_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_alloc_remaining_lbl)

	vb.add_child(HSeparator.new())

	# The stat rows live in a scroll capped to the window height, so the
	# Back/Confirm buttons below always stay on-screen — no more tabbing blind.
	var rows_scroll := ScrollContainer.new()
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vp_h := get_viewport_rect().size.y
	rows_scroll.custom_minimum_size = Vector2(720, clampf(vp_h - 340.0, 180.0, 420.0))
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
		name_lbl.custom_minimum_size = Vector2(130, 0)
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", EmeraldTheme.TEXT)
		row.add_child(name_lbl)

		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(34, 32)
		EmeraldTheme.style_button(minus, 18)
		minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		minus.pressed.connect(_alloc_add.bind(key, -1))
		row.add_child(minus)

		var val := Label.new()
		val.custom_minimum_size = Vector2(34, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.add_theme_font_size_override("font_size", 19)
		val.add_theme_color_override("font_color", EmeraldTheme.GOLD)
		row.add_child(val)
		_alloc_value_labels[key] = val

		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(34, 32)
		EmeraldTheme.style_button(plus, 18)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.pressed.connect(_alloc_add.bind(key, 1))
		row.add_child(plus)

		var desc := Label.new()
		desc.text = CharacterData.stat_description(key)
		desc.custom_minimum_size = Vector2(420, 0)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 14)
		desc.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
		row.add_child(desc)

		rows_vb.add_child(row)

	vb.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vb.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 40)
	EmeraldTheme.style_button(back_btn, 18)
	back_btn.pressed.connect(_alloc_cancel)
	btn_row.add_child(back_btn)

	_alloc_confirm_btn = Button.new()
	_alloc_confirm_btn.text = "Confirm"
	_alloc_confirm_btn.custom_minimum_size = Vector2(150, 40)
	EmeraldTheme.style_button(_alloc_confirm_btn, 18)
	EmeraldTheme.add_ring_markers(_alloc_confirm_btn)
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
	_is_quiz_character = false
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
