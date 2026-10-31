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

	# The swing hold (designer, 2026-10-31): the clock pauses while an enemy
	# swings so the attack can be seen; off, ticks resolve as they always did.
	var hold_header = Label.new()
	hold_header.text = "ENEMY SWINGS"
	hold_header.add_theme_font_size_override("font_size", 18)
	hold_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	content.add_child(hold_header)
	var hold_sep = HSeparator.new()
	hold_sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))
	content.add_child(hold_sep)
	var hold = CheckButton.new()
	hold.name = "SwingHold"
	hold.text = "Pause the clock while an enemy swings"
	hold.button_pressed = TempoManager.swing_hold_enabled()
	hold.add_theme_font_size_override("font_size", 13)
	hold.toggled.connect(func(on: bool): TempoManager.remember_swing_hold(on))
	content.add_child(hold)
	var hold_desc = Label.new()
	hold_desc.text = "On, the tempo clock waits for each enemy attack to play out before the next tick lands, so slashes, bites and shots can be seen. Off, ticks resolve at the tick speed regardless."
	hold_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	hold_desc.add_theme_font_size_override("font_size", 12)
	hold_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	content.add_child(hold_desc)
