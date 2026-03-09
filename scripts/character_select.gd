class_name CharacterSelect
extends Control

## Character selection screen - supports single player and multiplayer

signal character_selected(character: CharacterData)

@onready var character_container: HBoxContainer = $VBox/ScrollContainer/CharacterContainer
@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var title_separator: HSeparator = $VBox/TitleSeparator
@onready var back_button: Button = $BackButton
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_title: Label = $ConfirmOverlay/ConfirmPanel/VBox/ConfirmTitle
@onready var confirm_subtitle: Label = $ConfirmOverlay/ConfirmPanel/VBox/ConfirmSubtitle
@onready var proceed_button: Button = $ConfirmOverlay/ConfirmPanel/VBox/ButtonContainer/ProceedButton
@onready var cancel_button: Button = $ConfirmOverlay/ConfirmPanel/VBox/ButtonContainer/CancelButton

const CharacterCardScene = preload("res://scenes/character_card.tscn")
const QuestionnaireScene = preload("res://scenes/character_questionnaire.tscn")

var game_mode: String = "single_player"  # "single_player" or "multiplayer"
var _is_quiz_character: bool = false  # Track if selected character is the quiz option
var _selected_character: CharacterData = null

# Multiplayer state
var _player1_character: CharacterData = null
var _player2_character: CharacterData = null
var _selecting_player: int = 1  # Which player is currently selecting (1 or 2)

func _ready() -> void:
	_apply_styles()
	_setup_characters()
	_update_title_for_mode()

	back_button.pressed.connect(_on_back_pressed)
	proceed_button.pressed.connect(_on_proceed_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

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
	quiz_data.base_health = 5
	quiz_data.base_mana = 5
	quiz_data.base_mana_regen = 1.0
	quiz_data.base_draw_timer = 5
	quiz_data.base_hand_size = 5
	quiz_data.passive_description = "Determined by your answers"
	quiz_data.starting_item_name = "Determined by quiz"
	quiz_data.starting_item_description = "Answer 11 questions to build your character"
	quiz_data.slot_specialty = "Determined by quiz"
	quiz_data.sprite_path = ""

	var quiz_card = CharacterCardScene.instantiate()
	character_container.add_child(quiz_card)
	quiz_card.setup(quiz_data)
	# Override the sprite label to show "?" instead of "C"
	quiz_card._sprite_label.text = "?"
	quiz_card.selected.connect(_on_character_selected)

	# Add the 5 preset characters
	var characters = CharacterData.get_all_characters()
	for character in characters:
		var card = CharacterCardScene.instantiate()
		character_container.add_child(card)
		card.setup(character)
		card.selected.connect(_on_character_selected)

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
	confirm_overlay.visible = true

func _launch_questionnaire() -> void:
	var quiz_scene = QuestionnaireScene.instantiate()
	get_tree().root.add_child(quiz_scene)
	queue_free()

func _on_proceed_pressed() -> void:
	if not _selected_character:
		return

	confirm_overlay.visible = false

	if game_mode == "multiplayer":
		_handle_multiplayer_proceed()
	else:
		_handle_singleplayer_proceed()

func _handle_singleplayer_proceed() -> void:
	# Show the mode select (Town vs Fight) as a second confirmation
	_show_mode_select()

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
		var load_or_new_scene = load("res://scenes/load_or_new.tscn").instantiate()
		get_tree().root.add_child(load_or_new_scene)
	else:
		var title_scene = load("res://scenes/title_menu.tscn").instantiate()
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
	var town_scene = load("res://scenes/town.tscn").instantiate()
	town_scene.starting_character = character
	get_tree().root.add_child(town_scene)
	queue_free()

func _on_mode_fight() -> void:
	var character = _player1_character if game_mode == "multiplayer" else _selected_character
	if not character:
		return

	print("[SELECT] Going to fight with %s" % character.character_name)
	var main_scene = load("res://main.tscn").instantiate()
	main_scene.starting_character = character
	if game_mode == "multiplayer" and _player2_character:
		main_scene.player2_character = _player2_character
		main_scene.is_multiplayer = true
	get_tree().root.add_child(main_scene)
	queue_free()
