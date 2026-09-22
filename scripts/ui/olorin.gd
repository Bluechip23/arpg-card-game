class_name OlorinTutorial
extends Node

## Olorin — the wandering mentor who teaches the player how the world works.
##
## He appears at key first-time moments (entering combat for the first time,
## etc.), pauses the action, and offers a
## short explanation or hint. Each tutorial beat is shown once per character;
## the ids the player has already seen are stored on CharacterData so Olorin
## never repeats himself. The same dialog also carries the player's own
## thoughts when a beat is theirs to voice (see show_doughnut_keep_thought).

var main  # The owning scene (Main in the dungeon, Town in town)
var _active: bool = false
var _layer: CanvasLayer = null
var _resume_on_close: bool = false

func init(main_ref) -> void:
	main = main_ref
	# Olorin must keep running while the tree is paused so his Continue button works.
	process_mode = Node.PROCESS_MODE_ALWAYS

## The character whose seen-tutorial list gates each beat. Main exposes it as
## current_character; the town scene as starting_character.
func _character():
	if main == null:
		return null
	if "current_character" in main and main.current_character:
		return main.current_character
	if "starting_character" in main and main.starting_character:
		return main.starting_character
	return null

func has_seen(tutorial_id: String) -> bool:
	var c = _character()
	return c != null and c.seen_tutorial_ids.has(tutorial_id)

func _mark_seen(tutorial_id: String) -> void:
	var c = _character()
	if c and not c.seen_tutorial_ids.has(tutorial_id):
		c.seen_tutorial_ids.append(tutorial_id)

## Show a tutorial beat once. Returns true if it was shown.
## If `force` is true it ignores the "already seen" check. `speaker` swaps
## Olorin's name line for another voice (the player's own thoughts).
func show_tutorial(tutorial_id: String, title: String, paragraphs: Array, force: bool = false,
		speaker: String = OLORIN_SPEAKER) -> bool:
	if _active:
		return false
	if not force and has_seen(tutorial_id):
		return false
	_mark_seen(tutorial_id)
	_build_dialog(title, paragraphs, null, -1, speaker)
	return true

# ----- Specific tutorial beats -------------------------------------------------

func show_combat_intro() -> void:
	show_tutorial(
		"combat_intro",
		"Olorin's Counsel",
		[
			"\"Steady now. Battle here flows on tempo — every move, every card spends it, and your foes act as it passes.\"",
			"\"Play cards from your hand, mind your mana, and use the ground to your advantage. I will be near when there is more to learn.\"",
		]
	)

# ----- First-room tutorial (the Bladed Doughnut) --------------------------------
#
# The chain: the first rat drops a mythic (beat 1, in the dungeon) → the
# player picks it up and decides to show Olorin (beat 2, the quest "A Mythic
# Find" opens) → Olorin's lesson in town on rarities, forging, mythic levels
# and melding (beat 3) → the Blacksmith melds it into a Mythic Piece → Olorin
# pays for the lesson with the Wooden Sword and explains card slots (beat 4).

## Beat 1 — the first rat drops a mythic; Olorin points it out and asks the
## player to bring it to him.
func show_item_levels_intro() -> void:
	show_tutorial(
		"item_levels_intro",
		"A Rare Find",
		[
			"\"Hold a moment — do you see what that rat was carrying? That glow... a MYTHIC. Rarest of all that falls, and I have never known one to fall so early.\"",
			"\"Take it up, and mind it well. We will speak of it when you are next in town.\"",
		]
	)

## Beat 2 — the player claims the doughnut and thinks better of wielding it.
## Spoken in the character's own voice; main opens the quest alongside it.
func show_doughnut_keep_thought(character_name: String) -> void:
	show_tutorial(
		"doughnut_keep",
		"A Rare Find",
		[
			"\"I do not think I can wield this...\"",
			"\"I'll keep it, and show Olorin what I have found.\"",
			"New quest: A Mythic Find — show the Bladed Doughnut to Olorin in town.",
		],
		false,
		character_name if character_name != "" else "You"
	)

## Beat 3 — in town, the doughnut in hand: Olorin's lesson on rarities, the
## forge, mythic levels and skills, and why it must go to the Blacksmith.
func show_mythic_lesson() -> void:
	if _active or has_seen("mythic_lesson"):
		return
	_mark_seen("mythic_lesson")
	_build_dialog(
		"The Bladed Doughnut",
		[
			"\"So it is true — a MYTHIC, from the first rat you ever felled. Let me see it... a Bladed Doughnut. Sit; there is much to know about such things.\"",
			"\"Items come in five rarities: Basic, Common, Rare, Legendary, and — rarest of all — Mythic. Every item drops at level 1. Find more copies of the SAME item, and the Blacksmith in town will forge them together to raise its level.\"",
			"\"Basic, Common, and Rare items climb only in STATS, and cap at level 2. The forge asks three spare copies — four found in all — and every stat the item offers grows.\"",
			"\"Legendary and Mythic items reach level 3, and most carry a SKILL baked into them. One spare copy forges level 2 — a pure stat boost. Two more — four found in all — forge level 3, where the skill transforms into its true, build-defining form. This doughnut conjures a Sprinkle on every kill; at level 3 the Sprinkle becomes a bomb.\"",
			"\"But hear me: you will not be able to equip this for quite some time. A mythic answers only to a seasoned hand — level fifteen at the least, and every fifteen levels after lets you bear one more.\"",
			"\"So take it to the Blacksmith. He can meld it down for you into a Mythic Piece. Two such pieces make a Mythic Mold, and a mold recreates any mythic you have ever owned — on the day you are ready to wield it. Nothing mythic is ever wasted, in the right hands.\"",
		],
		DoughnutIcon.new(),
		1  # the doughnut, held up to the light
	)

## Beat 4 — the quest is turned in: Olorin pays for the lesson with the
## Wooden Sword (card slots, on-self bonuses, and item-granted cards).
func show_mythic_find_farewell() -> void:
	if _active or has_seen("mythic_find_farewell"):
		return
	_mark_seen("mythic_find_farewell")
	_build_dialog(
		"A Mentor's Gift",
		[
			"\"Melded down, and the piece kept safe? Good. When a second joins it, the Blacksmith will pour you a mold — and that doughnut can come back to you the day you can wield it.\"",
			"\"A lesson deserves a fee, and a mentor is no thief — so take this Wooden Sword. No stats to speak of; its worth is in the teaching.\"",
			"\"See the CARD SLOT carved into it? Items can hold cards — the Blacksmith will enchant one in for you. A slotted card gains the item's ON-SELF bonus. This sword's reads 'attacks deal +1 damage', so any attack card slotted into it strikes 1 harder.\"",
			"\"Some items also PROVIDE cards outright. While the sword is equipped, its card Splinter joins your deck — 20 mana, 2 tempo, range 3, and it leaves a Bleed that wounds the enemy for every tile it moves. Unequip the sword, and Splinter leaves with it.\"",
			"\"Good luck with your adventures, sir.\"",
		]
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

const OLORIN_SPEAKER := "Olorin, the Wandering Mentor"

func _build_dialog(title: String, paragraphs: Array, icon: Control = null, icon_after_paragraph: int = -1,
		speaker_name: String = OLORIN_SPEAKER) -> void:
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

	# Arcane-blue frame with the T&O crest mounted top-center on the border.
	var style = CrestStyleBox.new(Color(0.07, 0.08, 0.12, 0.98), Color(0.55, 0.7, 1.0), 10)
	style.crest_size = 26.0
	style.content_margin_top = 28.0
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
	speaker.text = speaker_name
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
