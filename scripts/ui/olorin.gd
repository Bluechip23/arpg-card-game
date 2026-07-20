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

# ----- First-room item tutorial (the Bladed Doughnut) --------------------------

## Beat 1 — the first rat drops a mythic; Olorin explains item levels.
func show_item_levels_intro() -> void:
	show_tutorial(
		"item_levels_intro",
		"A Rare Find",
		[
			"\"Hold a moment — do you see what that rat was carrying? A MYTHIC. Before you touch it, let me explain how items grow.\"",
			"\"Every item in this world drops at level 1. Find more copies of the SAME item, and the Blacksmith in town can forge them together to raise its level.\"",
			"\"Basic, Common, and Rare items have two levels. Forge three spare copies into one — four found in all — and it reaches level 2: a pure boost to every stat the item offers.\"",
			"\"Legendary and Mythic items have THREE levels. One spare copy forges level 2 — the same stat boost. Two more copies — four found in all — forge level 3, and at level 3 the item truly transforms.\"",
		]
	)

## Beat 2 — the player picks the doughnut up; Olorin explains baked-in skills.
func show_bladed_doughnut_skill() -> void:
	show_tutorial(
		"bladed_doughnut_skill",
		"The Bladed Doughnut",
		[
			"\"All mythics and most legendaries will have a skill associated with them. This skill gets upgraded on level 3.\"",
			"\"For instance, this delicious bladed doughnut gives you a Sprinkle. When it is upgraded to level 3, the Sprinkle turns into an AOE bomb vs a single target shot.\"",
			"\"This is a pretty impressive find so early in the game! Should make things easy for you moving forward.\"",
		]
	)

## Beat 3 — the player takes a step; Olorin gets hungry and takes the doughnut.
func show_doughnut_farewell() -> void:
	if _active or has_seen("bladed_doughnut_farewell"):
		return
	_mark_seen("bladed_doughnut_farewell")
	_build_dialog(
		"Olorin Reappears",
		[
			"\"I am actually pretty hungry..... I will take that doughnut, actually.\"",
			"Olorin puts his hands above his head — the doughnut appears.",
			"\"Good luck with your adventures, sir.\"",
		],
		DoughnutIcon.new(),
		2  # the doughnut materializes right after the stage direction
	)

func is_busy() -> bool:
	return _active

## The Bladed Doughnut: a long john with chocolate frosting and pink, teal,
## and white sprinkles, drawn above Olorin's raised hands.
class DoughnutIcon extends Control:
	const DOUGH := Color(0.85, 0.62, 0.32)
	const FROSTING := Color(0.3, 0.17, 0.09)
	const SPRINKLE_COLORS := [Color(1.0, 0.5, 0.7), Color(0.3, 0.85, 0.8), Color(0.95, 0.95, 0.95)]
	# Fixed sprinkle placements (x, y, rotation) so redraws don't reshuffle them.
	const SPRINKLES := [
		[38, 34, 0.5], [58, 28, -0.9], [76, 38, 1.2], [95, 27, 0.2],
		[112, 36, -0.6], [130, 29, 0.9], [148, 37, -1.2], [66, 45, 2.1],
		[104, 46, -1.8], [142, 46, 0.4], [50, 42, 1.6], [122, 44, 2.4],
	]

	func _init() -> void:
		custom_minimum_size = Vector2(190, 84)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		# Long john body
		var dough_box := StyleBoxFlat.new()
		dough_box.bg_color = DOUGH
		dough_box.set_corner_radius_all(22)
		draw_style_box(dough_box, Rect2(8, 24, 174, 52))
		# Chocolate frosting draped over the top
		var frosting_box := StyleBoxFlat.new()
		frosting_box.bg_color = FROSTING
		frosting_box.set_corner_radius_all(16)
		draw_style_box(frosting_box, Rect2(14, 18, 162, 34))
		# Sprinkles (pink, teal, white)
		for i in range(SPRINKLES.size()):
			var s: Array = SPRINKLES[i]
			draw_set_transform(Vector2(s[0], s[1]), s[2], Vector2.ONE)
			draw_rect(Rect2(-4.5, -1.4, 9.0, 2.8), SPRINKLE_COLORS[i % SPRINKLE_COLORS.size()])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ----- UI ---------------------------------------------------------------------

func _build_dialog(title: String, paragraphs: Array, icon: Control = null, icon_after_paragraph: int = -1) -> void:
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

	for i in range(paragraphs.size()):
		var p = Label.new()
		p.text = str(paragraphs[i])
		p.add_theme_font_size_override("font_size", 15)
		p.add_theme_color_override("font_color", Color(0.88, 0.88, 0.9))
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(p)
		# Optional inline picture (e.g. the doughnut Olorin conjures overhead)
		if icon and i + 1 == icon_after_paragraph:
			vbox.add_child(icon)
	if icon and icon.get_parent() == null:
		vbox.add_child(icon)

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
