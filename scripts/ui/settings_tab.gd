class_name SettingsTab
extends ScrollContainer

## Settings tab for the help panel. (Tick speed is set on the tempo
## counter itself — the arrow tiers on the tick bar; the paragraph that
## pointed there was cut, designer 2026-11-08: "not needed".)

signal tick_speed_changed(speed: float)  # kept for help_panel wiring compat

func _ready() -> void:
	var content = $Content as VBoxContainer
	if not content:
		return

	# The animation pauses (designer, 2026-10-31 for the enemies' swings,
	# 2026-11-08 for the heroes' drawn actions): the clock waits while a
	# character's attack, block or cast plays out. One switch covers both,
	# as it always did (the hero's hit wait rode the swing hold already);
	# off, ticks resolve at the tick speed and blows land at once.
	var hold_header = Label.new()
	hold_header.text = "ANIMATIONS"
	hold_header.add_theme_font_size_override("font_size", 18)
	hold_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	content.add_child(hold_header)
	var hold_sep = HSeparator.new()
	hold_sep.add_theme_color_override("color", Color(0.3, 0.3, 0.45))
	content.add_child(hold_sep)
	var hold = CheckButton.new()
	hold.name = "SwingHold"
	hold.text = "Pause for animations"
	hold.button_pressed = TempoManager.swing_hold_enabled()
	hold.add_theme_font_size_override("font_size", 13)
	hold.toggled.connect(func(on: bool): TempoManager.remember_swing_hold(on))
	content.add_child(hold)
	var hold_desc = Label.new()
	hold_desc.name = "SwingHoldDesc"
	hold_desc.text = "On, the tempo clock waits while your heroes and the enemies act, so every attack, block and spell cast plays out before the next tick lands. Off, ticks resolve at the tick speed regardless."
	hold_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	hold_desc.add_theme_font_size_override("font_size", 12)
	hold_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	content.add_child(hold_desc)
