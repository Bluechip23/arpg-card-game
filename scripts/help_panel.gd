class_name HelpPanel
extends CanvasLayer

## Help panel with keyword legend and gameplay walkthrough

signal closed

@onready var panel: PanelContainer = $Panel
@onready var tab_container: TabContainer = $Panel/MarginContainer/VBox/TabContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/CloseButton

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func show_panel(tab_index: int = 0) -> void:
	visible = true
	if tab_container:
		tab_container.current_tab = tab_index

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
