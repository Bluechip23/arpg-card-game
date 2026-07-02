class_name MoveConfirmDialog
extends CanvasLayer

## Confirmation dialog for multi-space movement

signal confirmed(target_position: Vector3, spaces: int)
signal cancelled
signal lock_in_requested(target_position: Vector3, spaces: int)

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/VBox/Label
@onready var yes_button: Button = $Panel/VBox/Buttons/YesButton
@onready var no_button: Button = $Panel/VBox/Buttons/NoButton

var lock_in_button: Button = null
var pending_position: Vector3
var pending_spaces: int

func _ready() -> void:
	# Add the co-op "Lock In Movement" option beside Yes/No.
	lock_in_button = Button.new()
	lock_in_button.text = "Lock In Movement"
	lock_in_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	yes_button.get_parent().add_child(lock_in_button)
	lock_in_button.pressed.connect(_on_lock_in_pressed)

	hide_dialog()
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)

func show_dialog(target_pos: Vector3, spaces: int, allow_lock_in: bool = false) -> void:
	pending_position = target_pos
	pending_spaces = spaces
	label.text = "Move %d space%s?" % [spaces, "s" if spaces > 1 else ""]
	if spaces >= 4:
		label.text += "\n(right-click mid-move to stop)"
	if lock_in_button:
		lock_in_button.visible = allow_lock_in
	panel.visible = true
	
	# Position dialog near mouse
	var mouse_pos = get_viewport().get_mouse_position()
	panel.position = mouse_pos + Vector2(20, -50)
	
	# Keep on screen
	var screen_size = get_viewport().get_visible_rect().size
	if panel.position.x + panel.size.x > screen_size.x:
		panel.position.x = screen_size.x - panel.size.x - 10
	if panel.position.y < 0:
		panel.position.y = 10

func hide_dialog() -> void:
	panel.visible = false

func _on_yes_pressed() -> void:
	hide_dialog()
	confirmed.emit(pending_position, pending_spaces)

func _on_no_pressed() -> void:
	hide_dialog()
	cancelled.emit()

func _on_lock_in_pressed() -> void:
	hide_dialog()
	lock_in_requested.emit(pending_position, pending_spaces)
