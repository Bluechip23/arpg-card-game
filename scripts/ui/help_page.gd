class_name HelpPage
extends Control

## Standalone help page accessible from the title menu.
## Displays the gameplay walkthrough and keyword legend.

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBox/TabContainer
@onready var back_button: Button = $Panel/MarginContainer/VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_apply_styles()

func _apply_styles() -> void:
	var panel = $Panel as PanelContainer
	if panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.07, 0.1, 1.0)
		style.content_margin_left = 20.0
		style.content_margin_right = 20.0
		style.content_margin_top = 20.0
		style.content_margin_bottom = 20.0
		panel.add_theme_stylebox_override("panel", style)

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

func _on_back_pressed() -> void:
	var title_scene = load("res://scenes/menus/title_menu.tscn").instantiate()
	get_tree().root.add_child(title_scene)
	queue_free()
