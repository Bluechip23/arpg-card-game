class_name HelpPanel
extends CanvasLayer

## Help panel with keyword legend, gameplay walkthrough, and settings.
## In game (town and the world) the host also turns on the game actions
## row: Save, Quit to Menu, Quit to Desktop — quitting first asks "Save
## before you quit?" (Yes / No / Cancel). See GameMenuActions.

signal closed
signal tick_speed_changed(speed: float)
## Save pressed.
signal save_requested
## A quit was confirmed: where to, and whether to save first.
signal quit_requested(to_desktop: bool, save_first: bool)

@onready var panel: PanelContainer = $Panel
@onready var tab_container: TabContainer = $Panel/MarginContainer/VBox/TabContainer
@onready var close_button: Button = $Panel/MarginContainer/VBox/CloseButton
@onready var settings_tab: SettingsTab = $Panel/MarginContainer/VBox/TabContainer/Settings

var actions_row: HBoxContainer = null
var save_button: Button = null
var quit_menu_button: Button = null
var quit_desktop_button: Button = null
var _can_save := true
var _prompt: Control = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS   # usable while the game is paused
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if settings_tab:
		settings_tab.tick_speed_changed.connect(func(speed): tick_speed_changed.emit(speed))

## Show the Save / Quit to Menu / Quit to Desktop row under the tabs. With
## `can_save` off (the sandbox arena: nothing there is a saved character)
## Save is hidden and quitting doesn't ask about saving.
func enable_game_actions(can_save: bool = true) -> void:
	_can_save = can_save
	if actions_row == null:
		actions_row = HBoxContainer.new()
		actions_row.name = "GameActions"
		actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
		actions_row.add_theme_constant_override("separation", 12)
		save_button = _action_button("Save", _on_save_pressed)
		quit_menu_button = _action_button("Quit to Menu", func(): ask_quit(false))
		quit_desktop_button = _action_button("Quit to Desktop", func(): ask_quit(true))
		$Panel/MarginContainer/VBox.add_child(actions_row)
	save_button.visible = can_save

func _action_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.name = text.replace(" ", "")
	b.text = text
	b.custom_minimum_size = Vector2(170, 36)
	EmeraldTheme.style_button(b, 16)
	b.pressed.connect(on_press)
	actions_row.add_child(b)
	return b

func _on_save_pressed() -> void:
	save_requested.emit()

## Quit pressed: ask "Save before you quit?" (straight out when saving
## isn't possible here).
func ask_quit(to_desktop: bool) -> void:
	if not _can_save:
		quit_requested.emit(to_desktop, false)
		return
	_close_prompt()
	var overlay := ColorRect.new()
	overlay.name = "QuitPrompt"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_prompt = overlay
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := PanelContainer.new()
	var style := EmeraldTheme.panel_box(EmeraldTheme.PANEL_BG_SOLID)
	style.set_content_margin_all(24)
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	box.add_child(vbox)
	var q := Label.new()
	q.name = "Question"
	q.text = "Save before you quit?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EmeraldTheme.style_heading(q, 26)
	vbox.add_child(q)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)
	for spec in [["Yes", func(): _answer(to_desktop, true)],
			["No", func(): _answer(to_desktop, false)],
			["Cancel", _close_prompt]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[0]
		b.custom_minimum_size = Vector2(120, 38)
		EmeraldTheme.style_button(b, 18)
		b.pressed.connect(spec[1])
		row.add_child(b)

func _answer(to_desktop: bool, save_first: bool) -> void:
	_close_prompt()
	quit_requested.emit(to_desktop, save_first)

func _close_prompt() -> void:
	if _prompt and is_instance_valid(_prompt):
		_prompt.queue_free()
	_prompt = null

func is_prompting() -> bool:
	return _prompt != null and is_instance_valid(_prompt)

func _on_close_pressed() -> void:
	_close_prompt()
	visible = false
	closed.emit()

func show_panel(tab_index: int = 0) -> void:
	visible = true
	if tab_container:
		tab_container.current_tab = tab_index

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if is_prompting():
		# Esc backs out of the question, not the whole panel.
		if event.is_action_pressed("ui_cancel"):
			_close_prompt()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
