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

# ----- The field tour: Olorin reads the screen for the player ------------------
#
# Spoken at the Transport Portal the first time the player leaves town. Each
# beat lights one part of the HUD and dims the rest (SpotlightOverlay), so
# the thing he is talking about is the only thing on screen.

const FIELD_TOUR_ID := "field_tour"

## Olorin's tour of tempo and the HUD. `force` replays it (Shift beside him).
func show_field_tour(force: bool = false) -> bool:
	if main == null:
		return false
	var m = main
	var bars: Array = []
	if "_minimap_panel" in m and m._minimap_panel:
		bars.append(m._minimap_panel)
	if "_hp_bar" in m and m._hp_bar:
		var bars_box = m._hp_bar.get_parent().get_parent()  # StatBarsContainer
		bars.append(bars_box)
		# The shield badge, mana drop and level badge hang off the bars' right edge.
		for wrapper in bars_box.get_children():
			for child in wrapper.get_children():
				if child is Control and child.name in ["ArmorShield", "ManaRegenDrop", "LevelBadge"]:
					bars.append(child)
	var counter: Array = []
	var frame = m.get_node_or_null("UI/TickBarFrame")
	if frame:
		counter.append(frame)
	var icons: Array = []
	if "hud_icon_bar" in m and m.hud_icon_bar:
		icons.append(m.hud_icon_bar)
	var column: Array = []
	var flash_row: Array = []
	var brain_row: Array = []
	if "_action_vbox" in m and m._action_vbox:
		column.append(m._action_vbox)
		var fr = m._action_vbox.get_node_or_null("FlashRow")
		if fr:
			flash_row.append(fr)
		var br = m._action_vbox.get_node_or_null("BrainRow")
		if br:
			brain_row.append(br)
	var hands_text := "\"Bottom left, what you can do without a card. The stack at the top is your draw pile — cards come to your hand on their own as tempo passes. The sword is a plain attack, five tempo of it; the raised hand waits a single tempo; the stop sign holds the world still.\""
	if "_block_button" in m and m._block_button and m._block_button.visible:
		hands_text += " \"And the shield you carry can be raised, for five tempo more.\""
	var steps: Array = [
		{"title": "The Road Out", "focus": [], "paragraphs": [
			"\"Ah — there you are. I felt you cross the gate before I saw you; the grass leans toward a traveller the way a dog leans toward its master.\"",
			"\"Before you go further, let me show you how this world keeps time, and how to read what your eyes are given.\"",
		]},
		{"title": "Tempo", "focus": counter, "paragraphs": [
			"\"Nothing here waits its turn. The world runs on TEMPO — a clock that moves only when you act. Every card you play, every tile you walk, every breath you wait spends some, and as it passes your foes take their own steps.\"",
			"\"This counter is your action ticking down. A card's ticks glow green; the gold mark is the moment it lands. Until it lands you are committed — no walking off mid-swing.\"",
			"\"The arrows beside it set how fast the ticks run, the stop sign holds everything, and the small arrow opens your queue, where an action whose tempo has not yet begun can still be called back.\"",
		]},
		{"title": "Your Measure", "focus": bars, "paragraphs": [
			"\"To the left, your measure. Red is your health. The grey sliver under it is unerring armor — the shell some gear regrows on its own — and the shield beside them counts the armor you raise yourself.\"",
			"\"Blue is mana, the well your cards drink from. It refills a little every five tempo; the drop counts down to the next.\"",
			"\"Brown is what you carry against what your strength can bear — overload it and it turns red. The thin gold line is experience, your level beside it. And the map fills in as you walk.\"",
		]},
		{"title": "The Journal", "focus": icons, "paragraphs": [
			"\"Top right. The figure opens your character — gear, stats, the cards you hold. The rising arrow is your level, and the points waiting to be spent. The scroll is your quest journal, the box your deck, and the question mark a book of everything I have ever told you, should your memory fail before mine does.\"",
		]},
		{"title": "Your Hands", "focus": column, "paragraphs": [hands_text]},
		{"title": "Flash", "focus": flash_row, "paragraphs": [
			"\"The bolt is FLASH — quickness of the body. One point for every point of Agility, refilled every three cycles.\"",
			"\"The boots make each step spend flash instead of tempo, three a tile. The crouching figure buys a sidestep for a little block — or, with a hand free, a quick cut at the nearest foe. The crossed daggers hurry your next attack along, five points a tick.\"",
		]},
		{"title": "Brain", "focus": brain_row, "paragraphs": [
			"\"The brain is Wisdom's pool — a point for every point of Wisdom, refilled every five cycles. The eye shows you the next card of your draw pile; the card with the plus draws one outright.\"",
			"\"Each use in a window costs more than the last, so spend them with intent.\"",
		]},
		{"title": "The Road Out", "focus": [], "paragraphs": [
			"\"That is the reading of it. I will keep to the portal a while, should you want it told again.\"",
			"\"Now go. The grass has been restless for days, and I would know why.\"",
		]},
	]
	return show_tour(FIELD_TOUR_ID, steps, force)

## A guided tour: several beats, each lighting the Controls in its `focus`
## list while the rest of the screen dims. Steps are dictionaries of
## {"title": String, "paragraphs": Array, "focus": Array of Control}; an
## empty focus dims everything evenly. Shown once per character unless
## `force`. Returns true if it started.
func show_tour(tutorial_id: String, steps: Array, force: bool = false) -> bool:
	if _active or steps.is_empty():
		return false
	if not force and has_seen(tutorial_id):
		return false
	_mark_seen(tutorial_id)
	_active = true
	_resume_on_close = not get_tree().paused
	if _resume_on_close:
		get_tree().paused = true
	_tour_steps = steps
	_tour_index = -1
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_spotlight = SpotlightOverlay.new()
	_spotlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spotlight.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_spotlight)
	_tour_next()
	return true

var _tour_steps: Array = []
var _tour_index: int = -1
var _tour_panel: PanelContainer = null
var _spotlight: SpotlightOverlay = null

func tour_step_index() -> int:
	return _tour_index

func tour_hole() -> Rect2:
	return _spotlight.hole if _spotlight else Rect2()

func _tour_next() -> void:
	_tour_index += 1
	if _tour_index >= _tour_steps.size():
		_close()
		return
	var step: Dictionary = _tour_steps[_tour_index]
	var hole := _focus_rect(step.get("focus", []))
	_spotlight.hole = hole
	_spotlight.queue_redraw()
	if _tour_panel and is_instance_valid(_tour_panel):
		_tour_panel.queue_free()
	var last := _tour_index == _tour_steps.size() - 1
	_tour_panel = _build_panel(str(step.get("title", "")), step.get("paragraphs", []), null, -1,
			OLORIN_SPEAKER, "Farewell" if last else "Continue", _tour_next)
	_layer.add_child(_tour_panel)
	_anchor_beside(_tour_panel, hole)

## The screen rectangle covering every visible Control in `focus`, padded.
## Rect2() (empty) when nothing is lit.
static func _focus_rect(focus: Array) -> Rect2:
	var out := Rect2()
	var any := false
	for c in focus:
		if not (c is Control) or not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		out = r if not any else out.merge(r)
		any = true
	if not any:
		return Rect2()
	return out.grow(10.0)

## Where the dialog sits so it never covers the lit part of the screen:
## "centre" when nothing is lit or the lit area sits clear of the screen's
## middle column (the bottom-left action column), "below" a lit area in the
## top half, "above" one in the bottom half.
static func placement_for(hole: Rect2, screen: Vector2) -> String:
	if hole.size == Vector2.ZERO:
		return "centre"
	var column_left := (screen.x - TOUR_PANEL_WIDTH) * 0.5 - TOUR_MARGIN
	var column_right := column_left + TOUR_PANEL_WIDTH + TOUR_MARGIN * 2.0
	if hole.end.x < column_left or hole.position.x > column_right:
		return "centre"
	return "below" if hole.get_center().y < screen.y * 0.5 else "above"

const TOUR_PANEL_WIDTH := 520.0
const TOUR_MARGIN := 24.0

## Anchors the dialog by placement_for: the panel keeps its natural height,
## so it is pinned by anchors and offsets rather than measured. (Anchors are
## set by hand: a preset applied after the panel joins the layer resolves
## against an empty parent rect and lands at the screen's left edge.)
func _anchor_beside(panel: Control, hole: Rect2) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var half := TOUR_PANEL_WIDTH * 0.5
	panel.custom_minimum_size = Vector2(TOUR_PANEL_WIDTH, 0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -half
	panel.offset_right = half
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	match placement_for(hole, screen):
		"below":
			panel.anchor_top = 0.0
			panel.anchor_bottom = 0.0
			panel.offset_top = hole.end.y + TOUR_MARGIN
			panel.offset_bottom = panel.offset_top
			panel.grow_vertical = Control.GROW_DIRECTION_END
		"above":
			panel.anchor_top = 1.0
			panel.anchor_bottom = 1.0
			panel.offset_bottom = hole.position.y - TOUR_MARGIN - screen.y
			panel.offset_top = panel.offset_bottom
			panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_:
			panel.anchor_top = 0.5
			panel.anchor_bottom = 0.5
			panel.offset_top = 0.0
			panel.offset_bottom = 0.0
			panel.grow_vertical = Control.GROW_DIRECTION_BOTH

## Dims the screen except for `hole`, which keeps a thin gold frame.
class SpotlightOverlay extends Control:
	var hole: Rect2 = Rect2()
	const DIM := Color(0, 0, 0, 0.72)
	const FRAME := Color(0.95, 0.8, 0.35, 0.9)

	func _draw() -> void:
		var full := Rect2(Vector2.ZERO, size)
		if hole.size == Vector2.ZERO:
			draw_rect(full, DIM)
			return
		var h := hole.intersection(full)
		# Four dim bands around the lit rectangle.
		draw_rect(Rect2(0, 0, size.x, h.position.y), DIM)                                  # above
		draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), DIM)                          # below
		draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), DIM)                       # left
		draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), DIM)             # right
		draw_rect(h, FRAME, false, 2.0)

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

	var panel := _build_panel(title, paragraphs, icon, icon_after_paragraph, speaker_name, "Continue", _close)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_layer.add_child(panel)

## The arcane-blue speech panel: speaker line, title, paragraphs, an optional
## inline picture, and one button that runs `on_button`.
func _build_panel(title: String, paragraphs: Array, icon: Control, icon_after_paragraph: int,
		speaker_name: String, button_text: String, on_button: Callable) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)

	# Arcane-blue frame with the T&O crest mounted top-center on the border.
	var style = CrestStyleBox.new(Color(0.07, 0.08, 0.12, 0.98), Color(0.55, 0.7, 1.0), 10)
	style.crest_size = 26.0
	style.content_margin_top = 28.0
	panel.add_theme_stylebox_override("panel", style)

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
	continue_btn.text = button_text
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
	continue_btn.pressed.connect(on_button)
	vbox.add_child(continue_btn)
	return panel

func _close() -> void:
	if _resume_on_close:
		get_tree().paused = false
		_resume_on_close = false
	if _layer and is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null
	_tour_panel = null
	_spotlight = null
	_tour_steps = []
	_tour_index = -1
	_active = false
