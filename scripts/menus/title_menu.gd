class_name TitleMenu
extends Control

## Title menu screen - Trials of Olorin
##
## The title itself is drawn by the animated TitleCutscene (Olorin, the boy,
## the pipe, and the two smoke rings that become the O's of OLORIN). The menu
## fades in once the cutscene finishes (or is skipped).

const CharacterSelectScene = preload("res://scenes/character/character_select.tscn")
const LoadOrNewScene = preload("res://scenes/character/load_or_new.tscn")
const QuestionnaireScene = preload("res://scenes/character/character_questionnaire.tscn")
const TitleCutsceneScript = preload("res://scripts/menus/title_cutscene.gd")

@onready var title_label: Label = $VBox/TitleLabel
@onready var menu_container: VBoxContainer = $VBox/MenuContainer
@onready var background: ColorRect = $Background

# Red ball indicators (one pair per menu item)
var _left_balls: Array[ColorRect] = []
var _right_balls: Array[ColorRect] = []
var _menu_buttons: Array[Button] = []
var _cutscene: Control = null

var _menu_items: Array[Dictionary] = [
	{"text": "Single Player", "action": "_on_single_player"},
	{"text": "Multiplayer", "action": "_on_multiplayer"},
	{"text": "Roguelike", "action": "_on_roguelike"},
	{"text": "Test", "action": "_on_test"},
	{"text": "Compendium", "action": "_on_compendium"},
	{"text": "Settings", "action": "_on_settings"},
	{"text": "Help", "action": "_on_help"},
	{"text": "Quit", "action": "_on_quit"},
]

# The Test submenu: everything used for trying things out.
var _test_items: Array[Dictionary] = [
	{"text": "Sandbox", "action": "_on_sandbox"},
	{"text": "Animation Lab", "action": "_on_animation_lab"},
	{"text": "Enemy Lab", "action": "_on_enemy_lab"},
	{"text": "Back", "action": "_on_test_back"},
]

func _ready() -> void:
	_apply_styles()
	_build_menu()
	# The cutscene draws the backdrop AND the title; the plain label is retired.
	if title_label:
		title_label.visible = false
	_cutscene = TitleCutsceneScript.new()
	_cutscene.name = "TitleCutscene"
	_cutscene.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cutscene)
	move_child(_cutscene, 1)  # above Background, below VBox
	# Hide the menu until Olorin has settled back onto his chair.
	$VBox.visible = false
	$VBox.modulate.a = 0.0
	_cutscene.cutscene_finished.connect(_on_cutscene_finished)

func _on_cutscene_finished() -> void:
	$VBox.visible = true
	var tween := create_tween()
	tween.tween_property($VBox, "modulate:a", 1.0, 0.8)

func _apply_styles() -> void:
	if title_label:
		title_label.add_theme_font_size_override("font_size", 72)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

func _build_menu(items: Array[Dictionary] = []) -> void:
	if items.is_empty():
		items = _menu_items
	# Clear any previous menu (used when swapping to/from the Test submenu).
	for child in menu_container.get_children():
		child.queue_free()
	_left_balls.clear()
	_right_balls.clear()
	_menu_buttons.clear()
	for i in range(items.size()):
		var item = items[i]

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
	var load_or_new = LoadOrNewScene.instantiate()
	get_tree().root.add_child(load_or_new)
	queue_free()

func _on_character_quiz() -> void:
	var quiz_scene = QuestionnaireScene.instantiate()
	get_tree().root.add_child(quiz_scene)
	queue_free()

func _on_roguelike() -> void:
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "roguelike"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_multiplayer() -> void:
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "multiplayer"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_test() -> void:
	## Swap to the Test submenu (Sandbox / Animation Lab / Enemy Lab).
	_build_menu(_test_items)

func _on_test_back() -> void:
	_build_menu(_menu_items)

func _on_sandbox() -> void:
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "sandbox"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_compendium() -> void:
	var compendium_scene = load("res://scenes/ui/compendium_page.tscn").instantiate()
	get_tree().root.add_child(compendium_scene)
	queue_free()

func _on_animation_lab() -> void:
	var lab_scene = load("res://scenes/menus/animation_lab.tscn").instantiate()
	get_tree().root.add_child(lab_scene)
	queue_free()

func _on_enemy_lab() -> void:
	var lab_scene = load("res://scenes/menus/enemy_lab.tscn").instantiate()
	get_tree().root.add_child(lab_scene)
	queue_free()

func _on_settings() -> void:
	# Placeholder - settings not yet implemented
	print("[MENU] Settings selected (not yet implemented)")

func _on_help() -> void:
	var help_scene = load("res://scenes/ui/help_page.tscn").instantiate()
	get_tree().root.add_child(help_scene)
	queue_free()

func _on_quit() -> void:
	get_tree().quit()
