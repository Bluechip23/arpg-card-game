class_name HelpPanel
extends CanvasLayer

## Help panel with keyword legend, gameplay walkthrough, and settings

signal closed
signal tick_speed_changed(speed: float)

@onready var panel: PanelContainer = $Panel
@onready var tab_container: TabContainer = $Panel/MarginContainer/VBox/TabContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/CloseButton
@onready var settings_tab: SettingsTab = $Panel/MarginContainer/VBox/TabContainer/Settings

func _ready() -> void:
	visible = false
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if settings_tab:
		settings_tab.tick_speed_changed.connect(func(speed): tick_speed_changed.emit(speed))

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func show_panel(tab_index: int = 0) -> void:
	visible = true
	if tab_container:
		tab_container.current_tab = tab_index

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
