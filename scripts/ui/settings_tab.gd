class_name SettingsTab
extends ScrollContainer

## Settings tab for the help panel. Tick speed moved onto the tempo counter
## itself (the arrow tiers on the tick bar), so this tab just points there.

signal tick_speed_changed(speed: float)  # kept for help_panel wiring compat

func _ready() -> void:
	var content = $Content as VBoxContainer
	if not content:
		return

	var header = Label.new()
	header.text = "TICK SPEED"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	content.add_child(header)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))
	content.add_child(sep)

	var desc = Label.new()
	desc.text = "Tick speed is now controlled on the tempo counter itself — the arrow buttons under the tick bar.\n◀ arrows slow the action down, ▶ arrows speed it up (▶ = normal 1.0× speed)."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	content.add_child(desc)
