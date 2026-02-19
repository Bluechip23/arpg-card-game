class_name CharacterSelect
extends Control

## Character selection screen

signal character_selected(character: CharacterData)

@onready var character_container: HBoxContainer = $VBox/ScrollContainer/CharacterContainer
@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var title_separator: HSeparator = $VBox/TitleSeparator

const CharacterCardScene = preload("res://scenes/character_card.tscn")

func _ready() -> void:
	_apply_styles()
	_setup_characters()

func _apply_styles() -> void:
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	if subtitle_label:
		subtitle_label.add_theme_font_size_override("font_size", 13)
		subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.72))

	if title_separator:
		title_separator.add_theme_color_override("color", Color(0.3, 0.3, 0.45))

func _setup_characters() -> void:
	var characters = CharacterData.get_all_characters()

	for character in characters:
		var card = CharacterCardScene.instantiate()
		character_container.add_child(card)
		card.setup(character)
		card.selected.connect(_on_character_selected)

func _on_character_selected(character: CharacterData) -> void:
	print("[SELECT] Character selected: %s" % character.character_name)
	character_selected.emit(character)

	# Transition to main game
	var main_scene = load("res://main.tscn").instantiate()
	main_scene.starting_character = character
	get_tree().root.add_child(main_scene)
	queue_free()
