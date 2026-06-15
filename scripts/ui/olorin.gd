class_name OlorinTutorial
extends Node

## Olorin — the wandering mentor who teaches the player how the world works.
##
## He appears at key first-time moments (picking up a roguelike-only reward,
## entering combat for the first time, etc.), pauses the action, and offers a
## short explanation or hint. Each tutorial beat is shown once per character;
## the ids the player has already seen are stored on CharacterData so Olorin
## never repeats himself.

var main  # Reference to the Main scene node
var _active: bool = false
var _layer: CanvasLayer = null
var _resume_on_close: bool = false

func init(main_ref) -> void:
	main = main_ref
	# Olorin must keep running while the tree is paused so his Continue button works.
	process_mode = Node.PROCESS_MODE_ALWAYS

func has_seen(tutorial_id: String) -> bool:
	if main and main.current_character:
		return main.current_character.seen_tutorial_ids.has(tutorial_id)
	return false

func _mark_seen(tutorial_id: String) -> void:
	if main and main.current_character and not main.current_character.seen_tutorial_ids.has(tutorial_id):
		main.current_character.seen_tutorial_ids.append(tutorial_id)

## Show a tutorial beat once. Returns true if it was shown.
## If `force` is true it ignores the "already seen" check.
func show_tutorial(tutorial_id: String, title: String, paragraphs: Array, force: bool = false) -> bool:
	if _active:
		return false
	if not force and has_seen(tutorial_id):
		return false
	_mark_seen(tutorial_id)
	_build_dialog(title, paragraphs)
	return true

# ----- Specific tutorial beats -------------------------------------------------

func show_infestation_intro() -> void:
	show_tutorial(
		"infestation_pickup",
		"Olorin Appears",
		[
			"\"Ah — the rats were carrying this. Infestation. A curious little trick.\"",
			"\"Mark my words: some cards and rewards can only be wielded in the Roguelike. This is one of them. In the story it will sit quietly in your collection, waiting.\"",
			"\"How do you unlock such things? The same way all worthwhile power is earned: slay monsters, complete quests, and seek out hidden treasures. Do these, and everything will open to you in time.\"",
		]
	)

func show_combat_intro() -> void:
	show_tutorial(
		"combat_intro",
		"Olorin's Counsel",
		[
			"\"Steady now. Battle here flows on tempo — every move, every card spends it, and your foes act as it passes.\"",
			"\"Play cards from your hand, mind your mana, and use the ground to your advantage. I will be near when there is more to learn.\"",
		]
	)

# ----- UI ---------------------------------------------------------------------

func _build_dialog(title: String, paragraphs: Array) -> void:
	_active = true

	# Pause the action while Olorin speaks (unless the player already paused).
	_resume_on_close = not get_tree().paused
	if _resume_on_close:
		get_tree().paused = true

	_layer = CanvasLayer.new()
	_layer.layer = 100  # Above the normal UI
	add_child(_layer)

	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(overlay)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.55, 0.7, 1.0)  # arcane blue
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var speaker = Label.new()
	speaker.text = "Olorin, the Wandering Mentor"
	speaker.add_theme_font_size_override("font_size", 20)
	speaker.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(speaker)

	if title != "":
		var subtitle = Label.new()
		subtitle.text = title
		subtitle.add_theme_font_size_override("font_size", 13)
		subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	for paragraph in paragraphs:
		var p = Label.new()
		p.text = str(paragraph)
		p.add_theme_font_size_override("font_size", 15)
		p.add_theme_color_override("font_color", Color(0.88, 0.88, 0.9))
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(p)

	vbox.add_child(HSeparator.new())

	var continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(140, 36)
	continue_btn.add_theme_font_size_override("font_size", 15)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.25, 0.45)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.4, 0.6, 1.0)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	continue_btn.add_theme_stylebox_override("normal", normal)
	continue_btn.pressed.connect(_close)
	vbox.add_child(continue_btn)

func _close() -> void:
	if _resume_on_close:
		get_tree().paused = false
		_resume_on_close = false
	if _layer and is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null
	_active = false
