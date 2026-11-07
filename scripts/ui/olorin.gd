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

## Any speech bar closed (Continue pressed).
signal dialog_closed

var _portrait_override: Texture2D = null  # an introduction's own close-up

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
#
# Every lesson's text lives in LESSONS so the Tutorials tab can list them
# all, seen or not, broken down beat by beat exactly as Olorin speaks them.

const LESSONS := [
	{"id": "field_tour", "title": "The Road Out — Olorin reads the screen", "beats": [
		{"title": "The Road Out", "paragraphs": [
			"\"Ah — there you are. I felt you cross the gate before I saw you; the grass leans toward a traveller the way a dog leans toward its master.\"",
			"\"Before you go further, let me show you how this world keeps time, and how to read what your eyes are given.\"",
		]},
		{"title": "Tempo", "focus": "counter", "paragraphs": [
			"\"Nothing here waits its turn. The world runs on TEMPO — a clock that moves only when you act. Every card you play, every tile you walk, every breath you wait spends some, and as it passes your foes take their own steps.\"",
			"\"This counter is your action ticking down. A card's ticks glow green; the gold mark is the moment it lands. Until it lands you are committed — no walking off mid-swing.\"",
			"\"The arrows beside it set how fast the ticks run, the stop sign holds everything, and the small arrow opens your queue, where an action whose tempo has not yet begun can still be called back.\"",
		]},
		{"title": "Your Measure", "focus": "bars", "paragraphs": [
			"\"To the left, your measure. Red is your health. The grey sliver under it is unerring armor — the shell some gear regrows on its own — and the shield beside them counts the armor you raise yourself.\"",
			"\"Blue is mana, the well your cards drink from. It refills a little every five tempo; the drop counts down to the next.\"",
			"\"Brown is what you carry against what your strength can bear — overload it and it turns red. The thin gold line is experience, your level beside it. And the map fills in as you walk.\"",
		], "tutorial_paragraphs": [
			"\"STRENGTH sets that brown bar: ten more carrying for every point, and half a point of melee damage. Carry near your limit and your attacks come slower.\"",
			"\"DETERMINATION decides what low health does to you. At 15 it does nothing. Above 15 your stats climb as your health falls; below 15 they sink.\"",
		]},
		{"title": "What Gear Gives", "focus": "bars", "tutorial_only": true, "paragraphs": [
			"\"Mark this: no stat raises your health, and no stat raises your mana. Those grow with your gear — and a little with each level and the sphere grid.\"",
			"\"The same holds for armor, critical chance and resistances. Gear, cards and passives give them; your stats never will.\"",
		]},
		{"title": "The Journal", "focus": "icons", "paragraphs": [
			"\"Top right. The figure opens your character — gear, stats, the cards you hold. The rising arrow is your level, and the points waiting to be spent. The scroll is your quest journal, the box your deck, and the question mark a book of everything I have ever told you, should your memory fail before mine does.\"",
		]},
		{"title": "Your Hands", "focus": "column", "paragraphs": [
			"\"Bottom left, what you can do without a card. The stack at the top is your draw pile — cards come to your hand on their own as tempo passes. The sword is a plain attack, five tempo of it; the raised hand waits a single tempo; the stop sign holds the world still.\"",
			"\"And the shield beside it raises the one you carry, for four tempo — it sits grey until you bear a shield.\"",
		]},
		{"title": "Flash", "focus": "flash", "paragraphs": [
			"\"The bolt is FLASH — quickness of the body. One point for every point of Agility, refilled every three cycles.\"",
			"\"Switch the boots on and each step spends flash instead of tempo, three a tile, until you switch them off or the flash runs dry. The crouching figure buys a sidestep for a little block — or, with a hand free, a quick cut at the nearest foe. The crossed daggers hurry your next attack along, five points a tick.\"",
		], "tutorial_paragraphs": [
			"\"So AGILITY is how much flash you have: more Agility, more free steps and sidesteps.\"",
		]},
		{"title": "Brain", "focus": "brain", "paragraphs": [
			"\"The brain is Wisdom's pool — a point for every point of Wisdom, refilled every five cycles. The eye shows you the next card of your draw pile; the card with the plus draws one outright.\"",
			"\"Each use in a window costs more than the last, so spend them with intent.\"",
		], "tutorial_paragraphs": [
			"\"WISDOM fills that pool, and every ten points of it lets you hold one more card in your hand.\"",
		]},
		{"title": "Speed and Crits", "focus": "column", "tutorial_only": true, "paragraphs": [
			"\"DEXTERITY is your attack speed. Play enough attack cards — forty-five, less half your Dexterity — and your next attack costs half its tempo and twenty less mana.\"",
			"\"It also makes your critical strikes hit harder: three percent more for every point. How OFTEN you strike critically is gear's business, not a stat's.\"",
		]},
		{"title": "Holding Your Weapons", "tutorial_only": true, "paragraphs": [
			"\"ONE HAND, one free: a single weapon or shield with the other hand empty. Every twelfth attack strikes twice, and your sidestep costs one flash less.\"",
			"\"TWO IN HAND — two weapons, or two shields: your attack speed needs four fewer attacks, but whatever sits in the off hand gives ninety parts in a hundred of its bonuses.\"",
			"\"TWO-HANDED: grip one weapon or shield with both hands. It weighs half as much to carry and gains a point of damage (or block) for every twenty-five of its weight, but you can carry only seven-tenths of what you could. Bows and staffs always take both hands, and gain nothing for it.\"",
		]},
		{"title": "Your Cards", "focus": "hand", "paragraphs": [
			"\"Last, the cards themselves. Every card has a TYPE, and the type says what it is for. Let me show you each.\"",
		]},
		{"title": "Attack", "card": "slash", "paragraphs": [
			"\"An ATTACK. It wounds, and it grows with your strength.\"",
		]},
		{"title": "Defense", "card": "block", "paragraphs": [
			"\"A DEFENSE card. It raises armor or turns a blow aside.\"",
		]},
		{"title": "Utility", "card": "draw", "paragraphs": [
			"\"UTILITY does the rest: draw, heal, move, strengthen.\"",
		]},
		{"title": "Power", "card": "armored_discipline", "paragraphs": [
			"\"A POWER stays in play for as long as you hold its mana up. The more you maintain, the less mana you have to spend.\"",
		]},
		{"title": "Reaction", "card": "cover", "paragraphs": [
			"\"A REACTION waits in your hand and springs on its own when its moment comes.\"",
		]},
		{"title": "Instant", "card": "hard_helmet", "paragraphs": [
			"\"An INSTANT is the same, at no mana: it fires from your hand the moment its condition is met.\"",
		]},
		{"title": "Enchantment", "card": "enchantment_attack", "paragraphs": [
			"\"An ENCHANTMENT is never played. It works by being held, and leaves when it is spent.\"",
		]},
		{"title": "Reach", "card": "dagger_throw", "paragraphs": [
			"\"Each card also says how far it reaches. MELEE is the next tile. RANGED is five tiles unless the card says otherwise. A few are CONDITIONAL — they take the reach of the weapon in your hand: ranged with a bow, melee with anything else.\"",
		]},
		{"title": "Offensive", "card": "fireball", "paragraphs": [
			"\"Above the types sits a broader word: OFFENSIVE. Anything that wounds is offensive — every attack card, and every spell or trick that deals damage.\"",
			"\"It branches two ways. An ATTACK is the body's work, and grows with your strength. A SPELL, like this one, is the mind's, grows with your intellect, and drinks deeper from your mana.\"",
		], "tutorial_paragraphs": [
			"\"INTELLIGENCE is that intellect: half a point of spell and healing power for every point, and one more mana back every cycle.\"",
		]},
		{"title": "The Road Out", "paragraphs": [
			"\"That is the reading of it. I will keep to the portal a while, should you want it told again.\"",
			"\"Now go. The grass has been restless for days, and I would know why.\"",
		]},
	]},
	{"id": "first_level_up", "title": "Your First Level — the sphere grid and stats", "beats": [
		{"title": "Your First Level", "paragraphs": [
			"\"Feel that? You have grown. Every level heals you fully, fills your mana, and adds a little to your health.\"",
		]},
		{"title": "Stats", "focus": "icons", "paragraphs": [
			"\"Every level also gives you three STAT POINTS. Open your level — the rising arrow at the top right — and spend them on your six stats. They stay where you put them.\"",
		], "tutorial_paragraphs": [
			"\"The points you set aside at the start are waiting there too. Now that you know what each stat does, spend them as your road demands.\"",
		]},
		{"title": "The Sphere Grid", "focus": "icons", "paragraphs": [
			"\"Beside it lies the SPHERE GRID. Each level brings two spheres; spend one to open a node, and nodes open only beside ones you already hold — so the grid is a path you choose.\"",
			"\"Nodes give stats, health, mana and passives. Some belong to a CONSTELLATION: open every node of one and its bonus is yours for good.\"",
		]},
	]},
	{"id": "combat_intro", "title": "Olorin's Counsel — the first foe", "beats": [
		{"title": "Olorin's Counsel", "paragraphs": [
			"\"Steady now. Battle here flows on tempo — every move, every card spends it, and your foes act as it passes.\"",
			"\"Play cards from your hand, mind your mana, and use the ground to your advantage. I will be near when there is more to learn.\"",
		]},
	]},
	{"id": "item_levels_intro", "title": "A Rare Find — the first mythic", "beats": [
		{"title": "A Rare Find", "paragraphs": [
			"\"Hold a moment — do you see what that rat was carrying? That glow... a MYTHIC. Rarest of all that falls, and I have never known one to fall so early.\"",
			"\"Take it up, and mind it well. We will speak of it when you are next in town.\"",
		]},
	]},
	{"id": "doughnut_keep", "title": "A Rare Find — keeping the doughnut", "speaker": "You", "beats": [
		{"title": "A Rare Find", "paragraphs": [
			"\"I do not think I can wield this...\"",
			"\"I'll keep it, and show Olorin what I have found.\"",
			"New quest: A Mythic Find — show the Bladed Doughnut to Olorin in town.",
		]},
	]},
	{"id": "mythic_lesson", "title": "The Bladed Doughnut — rarities, the forge and mythics", "beats": [
		{"title": "The Bladed Doughnut", "paragraphs": [
			"\"So it is true — a MYTHIC, from the first rat you ever felled. Let me see it... a Bladed Doughnut. Sit; there is much to know about such things.\"",
			"\"Items come in five rarities: Basic, Common, Rare, Legendary, and — rarest of all — Mythic. Every item drops at level 1. Find more copies of the SAME item, and the Blacksmith in town will forge them together to raise its level.\"",
			"\"Basic, Common, and Rare items climb only in STATS, and cap at level 2. The forge asks three spare copies — four found in all — and every stat the item offers grows.\"",
			"\"Legendary and Mythic items reach level 3, and most carry a SKILL baked into them. One spare copy forges level 2 — a pure stat boost. Two more — four found in all — forge level 3, where the skill transforms into its true, build-defining form. This doughnut conjures a Sprinkle on every kill; at level 3 the Sprinkle becomes a bomb.\"",
			"\"But hear me: you will not be able to equip this for quite some time. A mythic answers only to a seasoned hand — level fifteen at the least, and every fifteen levels after lets you bear one more.\"",
			"\"So take it to the Blacksmith. He can meld it down for you into a Mythic Piece. Two such pieces make a Mythic Mold, and a mold recreates any mythic you have ever owned — on the day you are ready to wield it. Nothing mythic is ever wasted, in the right hands.\"",
		]},
	]},
	{"id": "mythic_find_farewell", "title": "A Mentor's Gift — card slots and item cards", "beats": [
		{"title": "A Mentor's Gift", "paragraphs": [
			"\"Melded down, and the piece kept safe? Good. When a second joins it, the Blacksmith will pour you a mold — and that doughnut can come back to you the day you can wield it.\"",
			"\"A lesson deserves a fee, and a mentor is no thief — so take this Wooden Sword. No stats to speak of; its worth is in the teaching.\"",
			"\"See the CARD SLOT carved into it? Items can hold cards — drag one onto the slot from your character sheet, and it stays in your deck. A card in the slot gains the item's ON-SELF bonus. This sword's reads 'attacks deal +1 damage', so any attack card slotted into it strikes 1 harder.\"",
			"\"Some items also PROVIDE cards outright. While the sword is equipped, its card Splinter joins your deck — 20 mana, 2 tempo, range 3, and it leaves a Bleed that wounds the enemy for every tile it moves. Unequip the sword, and Splinter leaves with it.\"",
			"\"Good luck with your adventures, sir.\"",
		]},
	]},
]

## One lesson's paragraphs (a single-beat lesson) by id.
static func lesson_paragraphs(id: String, beat: int = 0) -> Array:
	for l in LESSONS:
		if l["id"] == id:
			return l["beats"][beat]["paragraphs"]
	return []

static func lesson_title(id: String, beat: int = 0) -> String:
	for l in LESSONS:
		if l["id"] == id:
			return l["beats"][beat]["title"]
	return ""

func show_combat_intro() -> void:
	show_tutorial("combat_intro", lesson_title("combat_intro"), lesson_paragraphs("combat_intro"))

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
	show_tutorial("item_levels_intro", lesson_title("item_levels_intro"), lesson_paragraphs("item_levels_intro"))

## Beat 2 — the player claims the doughnut and thinks better of wielding it.
## Spoken in the character's own voice; main opens the quest alongside it.
func show_doughnut_keep_thought(character_name: String) -> void:
	show_tutorial("doughnut_keep", lesson_title("doughnut_keep"), lesson_paragraphs("doughnut_keep"),
		false, character_name if character_name != "" else "You")

## Beat 3 — in town, the doughnut in hand: Olorin's lesson on rarities, the
## forge, mythic levels and skills, and why it must go to the Blacksmith.
func show_mythic_lesson() -> void:
	if _active or has_seen("mythic_lesson"):
		return
	_mark_seen("mythic_lesson")
	_build_dialog(lesson_title("mythic_lesson"), lesson_paragraphs("mythic_lesson"),
		DoughnutIcon.new(), 1)  # the doughnut, held up to the light

## Beat 4 — the quest is turned in: Olorin pays for the lesson with the
## Wooden Sword (card slots, on-self bonuses, and item-granted cards).
func show_mythic_find_farewell() -> void:
	if _active or has_seen("mythic_find_farewell"):
		return
	_mark_seen("mythic_find_farewell")
	_build_dialog(lesson_title("mythic_find_farewell"), lesson_paragraphs("mythic_find_farewell"))

## A townsperson introduces themselves the first time the player speaks to
## them: their own voice and close-up in the same speech bar. Shown once per
## character (`intro_id` joins their seen list, which is saved). Returns true
## if it was shown; dialog_closed fires when the player reads on.
func show_introduction(intro_id: String, speaker: String, paragraphs: Array, portrait: Texture2D) -> bool:
	if _active or has_seen(intro_id):
		return false
	_mark_seen(intro_id)
	_portrait_override = portrait
	_build_dialog("", paragraphs, null, -1, speaker)
	return true

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
	var hand: Array = []
	var hand_area = m.get_node_or_null("UI/HandArea")
	if hand_area:
		hand.append(hand_area)
	var focus_by_key := {"": [], "counter": counter, "bars": bars, "icons": icons, "column": column,
		"flash": flash_row, "brain": brain_row, "hand": hand}
	return show_tour(FIELD_TOUR_ID, lesson_steps(0, focus_by_key), force)

## A lesson's beats as tour steps: each lights its "focus" (a key of
## `focus_by_key`), shows its example "card" in the middle of the screen, and
## — for a hero in tutorial mode (CharacterData.tutorial_mode) — adds its
## "tutorial_paragraphs" and the "tutorial_only" beats (designer, 2026-11-07:
## the stats are taught in the lessons instead of allocated up front).
func lesson_steps(lesson_index: int, focus_by_key: Dictionary = {}) -> Array:
	var m = main
	var c = _character()
	var tutorial: bool = c != null and "tutorial_mode" in c and c.tutorial_mode
	var steps: Array = []
	for beat in LESSONS[lesson_index]["beats"]:
		if beat.get("tutorial_only", false) and not tutorial:
			continue
		var paragraphs: Array = beat["paragraphs"].duplicate()
		if beat["title"] == "Your Hands" and m != null:
			# The shield line only when a shield is actually carried.
			var has_shield: bool = "_block_button" in m and m._block_button and m._block_button.visible
			if not has_shield:
				paragraphs.resize(1)
		if tutorial:
			paragraphs.append_array(beat.get("tutorial_paragraphs", []))
		steps.append({"title": beat["title"], "focus": focus_by_key.get(beat.get("focus", ""), []),
			"paragraphs": paragraphs, "card": beat.get("card", "")})
	return steps


const FIRST_LEVEL_UP_ID := "first_level_up"

## Olorin's lesson at the hero's first level-up (designer, 2026-11-07): the
## full heal, stat points and how to spend them, the sphere grid and its
## constellations. Shown once per character.
func show_first_level_up() -> bool:
	for i in range(LESSONS.size()):
		if LESSONS[i]["id"] == FIRST_LEVEL_UP_ID:
			var focus := {}
			if main and "hud_icon_bar" in main and main.hud_icon_bar:
				focus["icons"] = [main.hud_icon_bar]
			return show_tour(FIRST_LEVEL_UP_ID, lesson_steps(i, focus))
	return false

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
var _tour_panel: PanelContainer = null  # the current beat's speech bar
var _spotlight: SpotlightOverlay = null

var _tour_card: Control = null   # the example card a beat shows, enlarged

## How large a beat's example card stands (CardUI scale), at most: it also
## shrinks to fit between the top of the screen and the speech bar.
const TOUR_CARD_SCALE := 1.9

## A beat's example card, enlarged in the middle of the screen above the
## speech bar (designer, 2026-11-07: "have them pop up enlarged in the middle
## of the screen and go through them that way"). "" clears it.
func _show_tour_card(card_id: String) -> void:
	if _tour_card and is_instance_valid(_tour_card):
		_tour_card.queue_free()
	_tour_card = null
	if card_id == "" or _layer == null or not is_instance_valid(_layer):
		return
	var card := Card.create_by_id(card_id)
	if card == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var sc := minf(TOUR_CARD_SCALE, (vp.y - SPEECH_ZONE - 40.0) / CardUI.CARD_H)
	var w := CardUI.CARD_W * sc
	var h := CardUI.CARD_H * sc
	var holder := Control.new()
	holder.name = "TourCard"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(w, h)
	holder.position = Vector2((vp.x - w) * 0.5, maxf(16.0, (vp.y - SPEECH_ZONE - h) * 0.5))
	_layer.add_child(holder)
	var face: CardUI = (load("res://scenes/cards/card_ui.tscn") as PackedScene).instantiate()
	face.scale = Vector2(sc, sc)
	holder.add_child(face)
	face.setup(card, 0)
	# A hand card scales about its bottom centre (the fan); this one grows
	# from its corner to fill the holder.
	face.pivot_offset = Vector2.ZERO
	face.position = Vector2.ZERO
	for n in face.find_children("*", "Control", true, false):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kb = face.get_node_or_null("Panel/KeybindBadge")
	if kb:
		kb.visible = false
	holder.modulate.a = 0.0
	holder.create_tween().tween_property(holder, "modulate:a", 1.0, 0.15)
	_tour_card = holder

## Fit the beat's card into the screen space the speech bar leaves (the bar
## grows with Olorin's words, so this waits for its layout): as large as
## TOUR_CARD_SCALE allows, centred in that space.
func _fit_tour_card() -> void:
	await get_tree().process_frame
	if _tour_card == null or not is_instance_valid(_tour_card) or _tour_panel == null or not is_instance_valid(_tour_panel):
		return
	var vp := get_viewport().get_visible_rect().size
	var bar := _tour_panel.get_global_rect()
	var top := 16.0
	var bottom := vp.y - 16.0
	if bar.position.y > vp.y * 0.5:
		bottom = bar.position.y - 12.0      # the bar along the bottom
	else:
		top = bar.end.y + 12.0              # the bar along the top
	var sc := minf(TOUR_CARD_SCALE, maxf(0.6, (bottom - top) / CardUI.CARD_H))
	var face := _tour_card.get_child(0) as Control
	if face:
		face.scale = Vector2(sc, sc)
	_tour_card.size = Vector2(CardUI.CARD_W * sc, CardUI.CARD_H * sc)
	_tour_card.position = Vector2((vp.x - _tour_card.size.x) * 0.5,
		top + ((bottom - top) - _tour_card.size.y) * 0.5)

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
	# A tour of several beats can be left at any beat but the last.
	_show_tour_card(str(step.get("card", "")))
	_tour_panel = _build_speech_bar(str(step.get("title", "")), step.get("paragraphs", []), null, -1,
			OLORIN_SPEAKER, "Farewell" if last else "Continue", _tour_next,
			"" if last else "Skip", _close)
	_layer.add_child(_tour_panel)
	_dock_bar(_tour_panel, placement_for(hole, get_viewport().get_visible_rect().size))
	_keep_clear(_tour_panel, hole)
	if _tour_card:
		_fit_tour_card.call_deferred()

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

## Where Olorin's speech bar docks so it never covers the lit part of the
## screen: along the "bottom" as usual, or along the "top" when the lit area
## reaches down into the bottom strip the bar fills. A lit area that spans
## both strips takes the edge it overlaps least.
static func placement_for(hole: Rect2, screen: Vector2) -> String:
	if hole.size == Vector2.ZERO:
		return "bottom"
	var bottom_strip := Rect2(0, screen.y - SPEECH_ZONE, screen.x, SPEECH_ZONE)
	var top_strip := Rect2(0, 0, screen.x, SPEECH_ZONE)
	var under_bottom := _overlap_area(hole, bottom_strip)
	if under_bottom <= 0.0:
		return "bottom"
	return "top" if _overlap_area(hole, top_strip) < under_bottom else "bottom"

static func _overlap_area(a: Rect2, b: Rect2) -> float:
	var r := a.intersection(b)
	return r.size.x * r.size.y

## Height the bar is planned around (portrait, a few lines, buttons).
const SPEECH_ZONE := 250.0
const TOUR_MARGIN := 24.0

## Pin the speech bar to the bottom or top edge (full width either way).
func _dock_bar(bar: Control, edge: String) -> void:
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_left = SPEECH_MARGIN
	bar.offset_right = -SPEECH_MARGIN
	if edge == "top":
		bar.anchor_top = 0.0
		bar.anchor_bottom = 0.0
		bar.offset_top = SPEECH_MARGIN
		bar.offset_bottom = SPEECH_MARGIN
		bar.grow_vertical = Control.GROW_DIRECTION_END
	else:
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_top = -SPEECH_MARGIN
		bar.offset_bottom = -SPEECH_MARGIN
		bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.set_meta("edge", edge)

## Once the bar has its real height (a long beat runs taller than the planned
## strip), make sure it still clears the lit area; if it does not, try the
## other edge and keep whichever covers less of it.
func _keep_clear(bar: Control, hole: Rect2) -> void:
	for i in range(4):
		await get_tree().process_frame
	if bar == null or not is_instance_valid(bar) or bar != _tour_panel or hole.size == Vector2.ZERO:
		return
	var here := _overlap_area(bar.get_global_rect(), hole)
	if here <= 0.0:
		return
	var edge: String = bar.get_meta("edge", "bottom")
	_dock_bar(bar, "top" if edge == "bottom" else "bottom")
	await get_tree().process_frame
	if not is_instance_valid(bar) or bar != _tour_panel:
		return
	if _overlap_area(bar.get_global_rect(), hole) > here:
		_dock_bar(bar, edge)

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
## The Bladed Doughnut held up to the light: the designer's painting
## (assets/items/mythic/bladed_doughnut.png, 2026-10-31) — the same art its
## inventory cell shows. (It was once drawn here from boxes as a plain long
## john.)
class DoughnutIcon extends TextureRect:
	func _init() -> void:
		texture = load("res://assets/items/mythic/bladed_doughnut.png")
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		custom_minimum_size = Vector2(96, 96)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	# A light veil over the scene (it still blocks clicks), darkening toward
	# the bottom where the speech bar sits.
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.25)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(overlay)

	var bar := _build_speech_bar(title, paragraphs, icon, icon_after_paragraph, speaker_name, "Continue", _close)
	_layer.add_child(bar)

# ----- Speech bar (bottom of the screen) ----------------------------------------

const SPEECH_MARGIN := 18.0
const PORTRAIT_SIZE := 168.0
const SPEECH_BG := Color(0.035, 0.075, 0.05, 0.97)
const SPEECH_BORDER := Color(0.80, 0.65, 0.32)
const SPEECH_NAME := Color(1.0, 0.86, 0.45)
const OLORIN_PORTRAIT := "res://assets/sprites/portraits/olorin.png"

## The talking-head bar along the bottom of the screen, as in most RPGs: a
## framed close-up of the speaker on the left, their name and words beside
## it, and the same buttons as before at the bottom right.
func _build_speech_bar(title: String, paragraphs: Array, icon: Control, icon_after_paragraph: int,
		speaker_name: String, button_text: String, on_button: Callable,
		secondary_text: String = "", on_secondary: Callable = Callable()) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.name = "SpeechBar"
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = SPEECH_MARGIN
	bar.offset_right = -SPEECH_MARGIN
	bar.offset_bottom = -SPEECH_MARGIN
	bar.offset_top = -SPEECH_MARGIN
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := CrestStyleBox.new(SPEECH_BG, SPEECH_BORDER, 10, 2)
	style.crest_size = CrestStyleBox.default_size * 1.3
	style.content_margin_top = maxf(18.0, style.content_margin_top)   # room for the crest
	style.content_margin_left = 16.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 14.0
	style.panel.shadow_color = Color(0, 0, 0, 0.5)
	style.panel.shadow_size = 12
	bar.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	bar.add_child(row)

	# The close-up of whoever is talking.
	row.add_child(_build_portrait(speaker_name))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	col.add_child(header)
	var speaker := Label.new()
	speaker.name = "Speaker"
	speaker.text = speaker_name
	speaker.add_theme_font_override("font", GameFonts.courgette())
	speaker.add_theme_font_size_override("font_size", 26)
	speaker.add_theme_color_override("font_color", SPEECH_NAME)
	speaker.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.03))
	speaker.add_theme_constant_override("outline_size", 4)
	header.add_child(speaker)
	if title != "":
		var subtitle := Label.new()
		subtitle.text = "— " + title
		subtitle.size_flags_vertical = Control.SIZE_SHRINK_END
		subtitle.add_theme_font_override("font", GameFonts.courgette())
		subtitle.add_theme_font_size_override("font_size", 16)
		subtitle.add_theme_color_override("font_color", Color(0.62, 0.72, 0.6))
		header.add_child(subtitle)

	var body := ScrollContainer.new()
	body.name = "Body"
	body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(0, 80)  # until _fit_speech measures the text
	col.add_child(body)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	body.add_child(content)
	for i in range(paragraphs.size()):
		var p := Label.new()
		p.text = str(paragraphs[i])
		p.add_theme_font_size_override("font_size", 16)
		p.add_theme_color_override("font_color", Color(0.92, 0.91, 0.86))
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(p)
		if icon and i + 1 == icon_after_paragraph:
			content.add_child(icon)
	if icon and icon.get_parent() == null:
		content.add_child(icon)
	_fit_speech.call_deferred(bar, body, content)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(buttons)
	if secondary_text != "" and on_secondary.is_valid():
		var skip_btn = _panel_button(secondary_text, Color(0.12, 0.13, 0.2), Color(0.35, 0.4, 0.55))
		skip_btn.name = "SkipButton"
		skip_btn.pressed.connect(on_secondary)
		buttons.add_child(skip_btn)
	var continue_btn = _panel_button(button_text, Color(0.15, 0.25, 0.45), Color(0.4, 0.6, 1.0))
	continue_btn.name = "ContinueButton"
	continue_btn.pressed.connect(on_button)
	buttons.add_child(continue_btn)
	return bar

## The speaker's close-up in a gilt frame: the hero's select-screen portrait
## for the player's own thoughts, and for Olorin the head of his NPC sprite
## (a stand-in until he has a painted close-up).
func _build_portrait(speaker_name: String) -> Control:
	var frame := PanelContainer.new()
	frame.name = "Portrait"
	frame.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.09, 0.16, 0.10)
	fs.set_border_width_all(3)
	fs.border_color = SPEECH_BORDER
	fs.set_corner_radius_all(6)
	fs.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fs)
	var pic := TextureRect.new()
	pic.name = "Face"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.texture = _portrait_for(speaker_name)
	if pic.texture is AtlasTexture:
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel-art sprite
	frame.add_child(pic)
	return frame

func _portrait_for(speaker_name: String) -> Texture2D:
	if _portrait_override:
		return _portrait_override
	if speaker_name != OLORIN_SPEAKER:
		var c = _character()
		if c and c.has_method("get_portrait"):
			var tex = c.get_portrait()
			if tex:
				return tex
		return null
	# The head-detail panel of the designer's Olorin sheet (2026-10-28).
	return load(OLORIN_PORTRAIT) as Texture2D

## Size the bar's scrolling body to its text, up to about a third of the
## screen; longer speeches scroll. Re-run when the window resizes.
func _fit_speech(bar: Control, body: ScrollContainer, content: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(bar) or not is_instance_valid(body) or not is_instance_valid(content):
		return
	var screen_h: float = bar.get_viewport_rect().size.y
	var text_h: float = content.get_combined_minimum_size().y
	var room: float = maxf(screen_h * 0.34, 80.0)
	body.custom_minimum_size.y = clampf(text_h, PORTRAIT_SIZE - 90.0, room)
	# A fresh lambda per bar: the same method bound to other args counts as
	# already connected once an earlier bar's hook is still waiting.
	bar.get_viewport().size_changed.connect(func(): _fit_speech(bar, body, content), CONNECT_ONE_SHOT)

static func _panel_button(text: String, bg: Color, border: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 36)
	btn.add_theme_font_size_override("font_size", 15)
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = border
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)
	return btn

func _close() -> void:
	if _resume_on_close:
		get_tree().paused = false
		_resume_on_close = false
	if _layer and is_instance_valid(_layer):
		_layer.queue_free()
		_layer = null
	_tour_panel = null
	_tour_card = null   # freed with the layer
	_spotlight = null
	_tour_steps = []
	_tour_index = -1
	_portrait_override = null
	_active = false
	dialog_closed.emit()
