class_name LoadOrNew
extends Control

## Intermediate screen: Load an existing character or start New

const CharacterSelectScene = preload("res://scenes/character/character_select.tscn")

@onready var title_label: Label = $VBox/TitleLabel
@onready var load_button: Button = $VBox/ButtonContainer/LoadButton
@onready var new_button: Button = $VBox/ButtonContainer/NewButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	_apply_styles()
	_check_saves()

	load_button.pressed.connect(_on_load_pressed)
	new_button.pressed.connect(_on_new_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _apply_styles() -> void:
	EmeraldTheme.apply(self)
	if title_label:
		title_label.text = "Single Player"
		EmeraldTheme.style_title(title_label, 48)
	for btn in [load_button, new_button]:
		if btn:
			btn.custom_minimum_size = Vector2(210, 60)
			EmeraldTheme.style_button(btn, 22)
			EmeraldTheme.add_ring_markers(btn)
	if load_button:
		load_button.text = "Load Character"
	if new_button:
		new_button.text = "New Character"
	if back_button:
		EmeraldTheme.style_button(back_button, 16)

func _check_saves() -> void:
	# Disable Load button if no saves exist
	var has_saves = false
	for i in range(SaveManager.MAX_SAVE_SLOTS):
		if SaveManager.save_exists(i):
			has_saves = true
			break
	if not has_saves:
		load_button.disabled = true
		load_button.tooltip_text = "No saved characters found"

func _on_load_pressed() -> void:
	var load_scene = load("res://scenes/character/load_character.tscn").instantiate()
	get_tree().root.add_child(load_scene)
	queue_free()

func _on_new_pressed() -> void:
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "single_player"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_back_pressed() -> void:
	var title_scene = load("res://scenes/menus/title_menu.tscn").instantiate()
	get_tree().root.add_child(title_scene)
	queue_free()
