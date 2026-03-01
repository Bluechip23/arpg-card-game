class_name TitleMenu
extends Control

## Title menu screen - Rock USA

const CharacterSelectScene = preload("res://scenes/character_select.tscn")

@onready var title_label: Label = $VBox/TitleLabel
@onready var menu_container: VBoxContainer = $VBox/MenuContainer
@onready var background: ColorRect = $Background

# Red ball indicators (one pair per menu item)
var _left_balls: Array[ColorRect] = []
var _right_balls: Array[ColorRect] = []
var _menu_buttons: Array[Button] = []

var _menu_items: Array[Dictionary] = [
	{"text": "Single Player", "action": "_on_single_player"},
	{"text": "Multiplayer", "action": "_on_multiplayer"},
	{"text": "Settings", "action": "_on_settings"},
	{"text": "Help", "action": "_on_help"},
	{"text": "Quit", "action": "_on_quit"},
]

func _ready() -> void:
	_apply_styles()
	_build_menu()

func _apply_styles() -> void:
	if title_label:
		title_label.add_theme_font_size_override("font_size", 72)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

func _build_menu() -> void:
	for i in range(_menu_items.size()):
		var item = _menu_items[i]

		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 20)
		menu_container.add_child(hbox)

		# Left red ball (hidden by default)
		var left_ball = _create_red_ball()
		left_ball.visible = false
		hbox.add_child(left_ball)
		_left_balls.append(left_ball)

		# Menu button
		var btn = Button.new()
		btn.text = item["text"]
		btn.custom_minimum_size = Vector2(260, 50)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

		# Normal style - dark transparent
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.12, 0.12, 0.18, 0.8)
		normal_style.border_width_left = 1
		normal_style.border_width_right = 1
		normal_style.border_width_top = 1
		normal_style.border_width_bottom = 1
		normal_style.border_color = Color(0.3, 0.3, 0.45)
		normal_style.corner_radius_top_left = 6
		normal_style.corner_radius_top_right = 6
		normal_style.corner_radius_bottom_left = 6
		normal_style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", normal_style)

		# Hover style - slightly brighter
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.18, 0.18, 0.26, 0.9)
		hover_style.border_width_left = 2
		hover_style.border_width_right = 2
		hover_style.border_width_top = 2
		hover_style.border_width_bottom = 2
		hover_style.border_color = Color(0.5, 0.3, 0.3)
		hover_style.corner_radius_top_left = 6
		hover_style.corner_radius_top_right = 6
		hover_style.corner_radius_bottom_left = 6
		hover_style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("hover", hover_style)

		# Pressed style
		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = Color(0.22, 0.15, 0.15, 0.95)
		pressed_style.border_width_left = 2
		pressed_style.border_width_right = 2
		pressed_style.border_width_top = 2
		pressed_style.border_width_bottom = 2
		pressed_style.border_color = Color(0.7, 0.3, 0.3)
		pressed_style.corner_radius_top_left = 6
		pressed_style.corner_radius_top_right = 6
		pressed_style.corner_radius_bottom_left = 6
		pressed_style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.mouse_entered.connect(_on_button_hover.bind(i))
		btn.mouse_exited.connect(_on_button_unhover.bind(i))
		btn.pressed.connect(Callable(self, item["action"]))

		hbox.add_child(btn)
		_menu_buttons.append(btn)

		# Right red ball (hidden by default)
		var right_ball = _create_red_ball()
		right_ball.visible = false
		hbox.add_child(right_ball)
		_right_balls.append(right_ball)

func _create_red_ball() -> ColorRect:
	var ball = ColorRect.new()
	ball.custom_minimum_size = Vector2(16, 16)
	ball.color = Color(0.9, 0.15, 0.15)
	return ball

func _on_button_hover(index: int) -> void:
	if index >= 0 and index < _left_balls.size():
		_left_balls[index].visible = true
		_right_balls[index].visible = true

func _on_button_unhover(index: int) -> void:
	if index >= 0 and index < _left_balls.size():
		_left_balls[index].visible = false
		_right_balls[index].visible = false

func _on_single_player() -> void:
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "single_player"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_multiplayer() -> void:
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "multiplayer"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_settings() -> void:
	# Placeholder - settings not yet implemented
	print("[MENU] Settings selected (not yet implemented)")

func _on_help() -> void:
	# Placeholder - help not yet implemented
	print("[MENU] Help selected (not yet implemented)")

func _on_quit() -> void:
	get_tree().quit()
