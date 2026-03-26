class_name SettingsTab
extends ScrollContainer

## Settings tab for the help panel - contains tick speed and other game settings.

signal tick_speed_changed(speed: float)

var _speed_buttons: Array[Button] = []
var _current_speed: float = 1.5
var _speed_label: Label = null

const TICK_SPEEDS := [0.15, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
const TICK_SPEED_LABELS := ["0.15s (Fastest)", "0.5s", "1.0s", "1.5s (Default)", "2.0s", "2.5s", "3.0s (Slowest)"]

func _ready() -> void:
	var content = $Content as VBoxContainer
	if not content:
		return

	_build_tick_speed_section(content)

func _build_tick_speed_section(content: VBoxContainer) -> void:
	# Section header
	var header = Label.new()
	header.text = "TICK SPEED"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	content.add_child(header)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))
	content.add_child(sep)

	# Description
	var desc = Label.new()
	desc.text = "Controls how fast tempo ticks advance after playing a card.\nFaster speeds resolve cards quickly. Slower speeds give more time to watch the action unfold."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	content.add_child(desc)

	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	content.add_child(spacer)

	# Current speed display
	_speed_label = Label.new()
	_speed_label.text = "Current: %.2fs per tick" % _current_speed
	_speed_label.add_theme_font_size_override("font_size", 14)
	_speed_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_speed_label)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 4
	content.add_child(spacer2)

	# Speed buttons in a row
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 6)
	content.add_child(btn_hbox)

	_speed_buttons.clear()
	for i in range(TICK_SPEEDS.size()):
		var btn = Button.new()
		btn.text = TICK_SPEED_LABELS[i]
		btn.custom_minimum_size = Vector2(90, 36)
		btn.add_theme_font_size_override("font_size", 11)

		var speed_val = TICK_SPEEDS[i]
		btn.pressed.connect(_on_speed_selected.bind(speed_val, i))
		btn_hbox.add_child(btn)
		_speed_buttons.append(btn)

	_update_button_styles()

func _on_speed_selected(speed: float, index: int) -> void:
	_current_speed = speed
	tick_speed_changed.emit(speed)
	_update_button_styles()
	if _speed_label:
		_speed_label.text = "Current: %.2fs per tick" % speed

func set_current_speed(speed: float) -> void:
	_current_speed = speed
	_update_button_styles()
	if _speed_label:
		_speed_label.text = "Current: %.2fs per tick" % speed

func _update_button_styles() -> void:
	for i in range(_speed_buttons.size()):
		var btn = _speed_buttons[i]
		var is_active = absf(TICK_SPEEDS[i] - _current_speed) < 0.01

		if is_active:
			var active_style = StyleBoxFlat.new()
			active_style.bg_color = Color(0.2, 0.45, 0.2)
			active_style.border_width_left = 2
			active_style.border_width_right = 2
			active_style.border_width_top = 2
			active_style.border_width_bottom = 2
			active_style.border_color = Color(0.4, 0.9, 0.4)
			active_style.corner_radius_top_left = 4
			active_style.corner_radius_top_right = 4
			active_style.corner_radius_bottom_left = 4
			active_style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", active_style)

			var active_hover = StyleBoxFlat.new()
			active_hover.bg_color = Color(0.25, 0.55, 0.25)
			active_hover.border_width_left = 2
			active_hover.border_width_right = 2
			active_hover.border_width_top = 2
			active_hover.border_width_bottom = 2
			active_hover.border_color = Color(0.5, 1.0, 0.5)
			active_hover.corner_radius_top_left = 4
			active_hover.corner_radius_top_right = 4
			active_hover.corner_radius_bottom_left = 4
			active_hover.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("hover", active_hover)
		else:
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.15, 0.15, 0.2)
			normal_style.border_width_left = 1
			normal_style.border_width_right = 1
			normal_style.border_width_top = 1
			normal_style.border_width_bottom = 1
			normal_style.border_color = Color(0.3, 0.3, 0.4)
			normal_style.corner_radius_top_left = 4
			normal_style.corner_radius_top_right = 4
			normal_style.corner_radius_bottom_left = 4
			normal_style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", normal_style)

			var hover_style = StyleBoxFlat.new()
			hover_style.bg_color = Color(0.22, 0.22, 0.3)
			hover_style.border_width_left = 1
			hover_style.border_width_right = 1
			hover_style.border_width_top = 1
			hover_style.border_width_bottom = 1
			hover_style.border_color = Color(0.4, 0.4, 0.55)
			hover_style.corner_radius_top_left = 4
			hover_style.corner_radius_top_right = 4
			hover_style.corner_radius_bottom_left = 4
			hover_style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("hover", hover_style)
