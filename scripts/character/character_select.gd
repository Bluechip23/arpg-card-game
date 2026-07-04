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

const CharacterCardScene = preload("res://scenes/character/character_card.tscn")
const QuestionnaireScene = preload("res://scenes/character/character_questionnaire.tscn")

var game_mode: String = "single_player"  # "single_player", "multiplayer" or "roguelike"
var _is_quiz_character: bool = false  # Track if selected character is the quiz option
var _selected_character: CharacterData = null
var _roguelike_saves: Dictionary = {}  # CharacterData -> SaveData (saved characters)

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
	# Roguelike is gated to characters that have started the story: only saved
	# characters can play. If there are none, show guidance instead of cards.
	if game_mode == "roguelike":
		if _add_saved_character_cards() == 0:
			_show_no_saves_message()
		return

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
	_add_preset_character_cards()

func _add_preset_character_cards() -> void:
	var characters = CharacterData.get_all_characters()
	for character in characters:
		var card = CharacterCardScene.instantiate()
		character_container.add_child(card)
		card.setup(character)
		card.selected.connect(_on_character_selected)
		card.skill_tree_requested.connect(_on_skill_tree_requested)

func _add_saved_character_cards() -> int:
	## Builds a card for each saved character (used in roguelike selection).
	## Remembers the save behind each character so its progression can be
	## carried into the run. Returns how many cards were added.
	var count := 0
	for save in SaveManager.get_all_saves():
		if save == null or save.character_data == null:
			continue
		_roguelike_saves[save.character_data] = save
		var card = CharacterCardScene.instantiate()
		character_container.add_child(card)
		card.setup(save.character_data)
		card.selected.connect(_on_character_selected)
		count += 1
	return count

func _show_no_saves_message() -> void:
	var lbl = Label.new()
	lbl.text = "No saved characters yet.\n\nPlay the story and use Save Game in Town to create a character, then return here to start a run."
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(520, 0)
	character_container.add_child(lbl)

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
	if game_mode == "roguelike":
		_launch_roguelike(_selected_character)
		return
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

func _launch_roguelike(character: CharacterData) -> void:
	print("[SELECT] Starting roguelike run as %s" % character.character_name)
	var map_scene = load("res://scenes/roguelike/roguelike_map.tscn").instantiate()
	map_scene.character = character
	# Hand the saved character to the map so it can carry story progression into
	# battles and persist/resume the character's single active run. Preset
	# characters have no save and run ephemerally.
	var save: SaveData = _roguelike_saves.get(character, null)
	if save:
		map_scene.save = save
	get_tree().root.add_child(map_scene)
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
	if character.character_name == "Customize":
		return
	_show_skill_tree_popup(character)

func _show_skill_tree_popup(character: CharacterData) -> void:
	if _skill_tree_overlay:
		_skill_tree_overlay.queue_free()

	# Get the skill tree data for this character
	var tree: SkillTreeData = _get_skill_tree_for_character(character.character_name)
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
