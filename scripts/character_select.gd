class_name CharacterSelect
extends Control

## Character selection screen

signal character_selected(character: CharacterData)

@onready var character_container: HBoxContainer = $VBox/CharacterContainer
@onready var title_label: Label = $VBox/TitleLabel

const CharacterCardScene = preload("res://scenes/character_card.tscn")

func _ready() -> void:
	_setup_characters()

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
