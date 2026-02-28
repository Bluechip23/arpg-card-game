class_name CharacterSelect
extends Control

## Character selection screen

signal character_selected(character: CharacterData)

@onready var character_container: HBoxContainer = $VBox/ScrollContainer/CharacterContainer
@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var title_separator: HSeparator = $VBox/TitleSeparator
@onready var mode_overlay: ColorRect = $ModeSelectOverlay
@onready var mode_title: Label = $ModeSelectOverlay/ModePanel/VBox/ModeTitle
@onready var mode_subtitle: Label = $ModeSelectOverlay/ModePanel/VBox/ModeSubtitle
@onready var town_button: Button = $ModeSelectOverlay/ModePanel/VBox/ButtonContainer/TownButton
@onready var fight_button: Button = $ModeSelectOverlay/ModePanel/VBox/ButtonContainer/FightButton

const CharacterCardScene = preload("res://scenes/character_card.tscn")

var _selected_character: CharacterData = null

func _ready() -> void:
	_apply_styles()
	_setup_characters()

	town_button.pressed.connect(_on_town_pressed)
	fight_button.pressed.connect(_on_fight_pressed)

func _apply_styles() -> void:
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	if subtitle_label:
		subtitle_label.add_theme_font_size_override("font_size", 13)
		subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.72))

	if title_separator:
		title_separator.add_theme_color_override("color", Color(0.3, 0.3, 0.45))

	# Mode modal styles
	if mode_title:
		mode_title.add_theme_font_size_override("font_size", 28)
		mode_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	if mode_subtitle:
		mode_subtitle.add_theme_font_size_override("font_size", 14)
		mode_subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))

	var mode_panel = $ModeSelectOverlay/ModePanel
	if mode_panel:
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
		mode_panel.add_theme_stylebox_override("panel", style)

	# Town button style
	if town_button:
		town_button.add_theme_font_size_override("font_size", 18)
		var town_style = StyleBoxFlat.new()
		town_style.bg_color = Color(0.15, 0.3, 0.15)
		town_style.border_width_left = 2
		town_style.border_width_right = 2
		town_style.border_width_top = 2
		town_style.border_width_bottom = 2
		town_style.border_color = Color(0.3, 0.6, 0.3)
		town_style.corner_radius_top_left = 6
		town_style.corner_radius_top_right = 6
		town_style.corner_radius_bottom_left = 6
		town_style.corner_radius_bottom_right = 6
		town_button.add_theme_stylebox_override("normal", town_style)
		var town_hover = StyleBoxFlat.new()
		town_hover.bg_color = Color(0.2, 0.4, 0.2)
		town_hover.border_width_left = 2
		town_hover.border_width_right = 2
		town_hover.border_width_top = 2
		town_hover.border_width_bottom = 2
		town_hover.border_color = Color(0.4, 0.8, 0.4)
		town_hover.corner_radius_top_left = 6
		town_hover.corner_radius_top_right = 6
		town_hover.corner_radius_bottom_left = 6
		town_hover.corner_radius_bottom_right = 6
		town_button.add_theme_stylebox_override("hover", town_hover)

	# Fight button style
	if fight_button:
		fight_button.add_theme_font_size_override("font_size", 18)
		var fight_style = StyleBoxFlat.new()
		fight_style.bg_color = Color(0.4, 0.12, 0.12)
		fight_style.border_width_left = 2
		fight_style.border_width_right = 2
		fight_style.border_width_top = 2
		fight_style.border_width_bottom = 2
		fight_style.border_color = Color(0.7, 0.25, 0.25)
		fight_style.corner_radius_top_left = 6
		fight_style.corner_radius_top_right = 6
		fight_style.corner_radius_bottom_left = 6
		fight_style.corner_radius_bottom_right = 6
		fight_button.add_theme_stylebox_override("normal", fight_style)
		var fight_hover = StyleBoxFlat.new()
		fight_hover.bg_color = Color(0.55, 0.18, 0.18)
		fight_hover.border_width_left = 2
		fight_hover.border_width_right = 2
		fight_hover.border_width_top = 2
		fight_hover.border_width_bottom = 2
		fight_hover.border_color = Color(1.0, 0.35, 0.35)
		fight_hover.corner_radius_top_left = 6
		fight_hover.corner_radius_top_right = 6
		fight_hover.corner_radius_bottom_left = 6
		fight_hover.corner_radius_bottom_right = 6
		fight_button.add_theme_stylebox_override("hover", fight_hover)

func _setup_characters() -> void:
	var characters = CharacterData.get_all_characters()

	for character in characters:
		var card = CharacterCardScene.instantiate()
		character_container.add_child(card)
		card.setup(character)
		card.selected.connect(_on_character_selected)

func _on_character_selected(character: CharacterData) -> void:
	print("[SELECT] Character selected: %s" % character.character_name)
	_selected_character = character
	character_selected.emit(character)

	# Show mode selection modal
	mode_subtitle.text = "Playing as %s" % character.character_name
	mode_overlay.visible = true

func _on_town_pressed() -> void:
	if not _selected_character:
		return

	print("[SELECT] Going to town with %s" % _selected_character.character_name)
	var town_scene = load("res://scenes/town.tscn").instantiate()
	town_scene.starting_character = _selected_character
	get_tree().root.add_child(town_scene)
	queue_free()

func _on_fight_pressed() -> void:
	if not _selected_character:
		return

	print("[SELECT] Going to fight with %s" % _selected_character.character_name)
	var main_scene = load("res://main.tscn").instantiate()
	main_scene.starting_character = _selected_character
	get_tree().root.add_child(main_scene)
	queue_free()
