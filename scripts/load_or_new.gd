class_name LoadOrNew
extends Control

## Intermediate screen: Load an existing character or start New

const CharacterSelectScene = preload("res://scenes/character_select.tscn")

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
	if title_label:
		title_label.text = "Single Player"
		title_label.add_theme_font_size_override("font_size", 36)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	# Load button style (blue)
	if load_button:
		load_button.text = "Load Character"
		load_button.add_theme_font_size_override("font_size", 20)
		_style_button(load_button, Color(0.15, 0.25, 0.45), Color(0.2, 0.35, 0.6), Color(0.3, 0.5, 0.8), Color(0.4, 0.65, 1.0))

	# New button style (green)
	if new_button:
		new_button.text = "New Character"
		new_button.add_theme_font_size_override("font_size", 20)
		_style_button(new_button, Color(0.15, 0.3, 0.15), Color(0.2, 0.4, 0.2), Color(0.3, 0.6, 0.3), Color(0.4, 0.8, 0.4))

	# Back button
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
		load_button.modulate = Color(0.5, 0.5, 0.5)

func _style_button(btn: Button, normal_bg: Color, hover_bg: Color, normal_border: Color, hover_border: Color) -> void:
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

func _on_load_pressed() -> void:
	var load_scene = load("res://scenes/load_character.tscn").instantiate()
	get_tree().root.add_child(load_scene)
	queue_free()

func _on_new_pressed() -> void:
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "single_player"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_back_pressed() -> void:
	var title_scene = load("res://scenes/title_menu.tscn").instantiate()
	get_tree().root.add_child(title_scene)
	queue_free()
