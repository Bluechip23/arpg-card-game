class_name PointToProveDialog
extends CanvasLayer

## Confirmation dialog for Point to Prove passive.
## Asks the player if they want to sacrifice HP to ignore a stun or disarm.

signal confirmed(debuff_type: int)
signal declined(debuff_type: int)

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/VBox/Label
@onready var yes_button: Button = $Panel/VBox/Buttons/YesButton
@onready var no_button: Button = $Panel/VBox/Buttons/NoButton

var pending_debuff_type: int = -1
var hp_cost: int = 5

func _ready() -> void:
	hide_dialog()
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)

func show_dialog(debuff_name: String, debuff_type: int, cost: int = 5) -> void:
	pending_debuff_type = debuff_type
	hp_cost = cost
	label.text = "Point to Prove: Sacrifice %d HP to ignore %s?" % [cost, debuff_name]
	panel.visible = true

	# Center on screen
	var screen_size = get_viewport().get_visible_rect().size
	panel.position = Vector2(
		(screen_size.x - panel.size.x) / 2.0,
		(screen_size.y - panel.size.y) / 2.0
	)

func hide_dialog() -> void:
	panel.visible = false

func is_showing() -> bool:
	return panel.visible

func _on_yes_pressed() -> void:
	hide_dialog()
	confirmed.emit(pending_debuff_type)

func _on_no_pressed() -> void:
	hide_dialog()
	declined.emit(pending_debuff_type)
