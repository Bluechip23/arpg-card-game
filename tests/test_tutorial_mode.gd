extends SceneTree

## Tutorial mode and the first level-up (designer, 2026-11-07):
##  - the allocation screen's Tutorial box fades and locks the stat rows,
##    lets Confirm through without spending, and sets the hero to tutorial
##    mode with the 8 points set aside; PlayerStats banks them once;
##  - Olorin's field tour adds the stat, gear and wielding beats for a hero
##    in tutorial mode (and not otherwise), and each card-type beat shows its
##    example card enlarged in the middle of the screen;
##  - the first level-up raises the golden pillar round the hero and Olorin
##    explains stat points, the sphere grid and constellations, once.
## Run: godot --headless --path . --script tests/test_tutorial_mode.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

class FakeMain extends Node:
	var current_character: CharacterData = null

func _initialize() -> void:
	_run()

func _settle(n: int = 6) -> void:
	for _i in range(n):
		await process_frame

func _run() -> void:
	print("=== Tutorial mode ===")
	await _settle(2)   # nodes join the tree after _initialize
	await _test_allocation_box()
	_test_banking()
	await _test_tour_beats()
	await _test_first_level_up()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_allocation_box() -> void:
	print("-- The Tutorial box --")
	var cs = (load("res://scenes/character/character_select.tscn") as PackedScene).instantiate()
	get_root().add_child(cs)
	var c := CharacterData.create_ryan()
	var fired := [false]
	cs._show_stat_allocation(c, func(): fired[0] = true)
	_check(cs._alloc_tutorial != null, "the allocation screen has a Tutorial box")
	_check(cs._alloc_tutorial.get_theme_stylebox("normal") is StyleBoxEmpty, "the box sits on no grey panel, just its yellow outline")
	await process_frame
	await process_frame
	var frame: Control = cs._alloc_overlay.get_node_or_null("AllocFrame")
	var apanel: Control = frame.get_node_or_null("AllocPanel") if frame else null
	_check(cs._alloc_overlay.get_node_or_null("AllocBoard") != null, "the training-ground painting fills the screen")
	if apanel:
		var r := Rect2(apanel.global_position, apanel.size * apanel.scale)
		_check(frame.get_global_rect().grow(1.0).encloses(r), "the box sits in the painting's empty middle")
	_check(cs._alloc_confirm_btn.disabled, "Confirm waits for all 8 points while the box is clear")
	cs._alloc_tutorial.button_pressed = true
	_check(not cs._alloc_confirm_btn.disabled, "ticked, Confirm goes through without spending")
	_check(cs._alloc_rows.modulate.a < 0.5, "the stat rows fade out")
	var any_enabled := false
	for b in cs._alloc_rows.find_children("*", "BaseButton", true, false):
		any_enabled = any_enabled or not b.disabled
	_check(not any_enabled, "and their buttons are locked")
	cs._alloc_confirm()
	_check(fired[0], "Confirm proceeds")
	_check(c.tutorial_mode and c.banked_stat_points == 8, "the hero is in tutorial mode with 8 points set aside")
	_check(c.strength == 3 and c.agility == 3, "nothing was spent on the stats")
	cs.queue_free()

func _test_banking() -> void:
	print("-- Banking the set-aside points --")
	var c := CharacterData.create_brad()
	c.banked_stat_points = 8
	var s := PlayerStats.new()
	s.initialize(c)
	_check(s.unspent_stat_points == 8, "PlayerStats banks the 8 points for the stat screen")
	_check(c.banked_stat_points == 0, "…once: the character's field is spent")
	var s2 := PlayerStats.new()
	s2.initialize(c)
	_check(s2.unspent_stat_points == 0, "a second initialize does not bank them again")

func _titles(steps: Array) -> Array:
	return steps.map(func(st): return str(st["title"]))

func _all_text(steps: Array) -> String:
	var t := ""
	for st in steps:
		for p in st["paragraphs"]:
			t += str(p) + "\n"
	return t

func _test_tour_beats() -> void:
	print("-- Olorin's field tour --")
	var holder := Node.new()
	get_root().add_child(holder)
	var main := FakeMain.new()
	main.current_character = CharacterData.create_brad()
	holder.add_child(main)
	var olorin := OlorinTutorial.new()
	olorin.init(main)
	holder.add_child(olorin)
	await _settle(2)

	var plain := olorin.lesson_steps(0)
	var plain_titles := _titles(plain)
	_check(not ("What Gear Gives" in plain_titles) and not ("Holding Your Weapons" in plain_titles),
		"without tutorial mode the stat beats are left out")
	_check(not _all_text(plain).contains("DETERMINATION"), "…and so are the stat paragraphs")
	main.current_character.tutorial_mode = true
	var tut := olorin.lesson_steps(0)
	var tut_titles := _titles(tut)
	for t in ["What Gear Gives", "Speed and Crits", "Holding Your Weapons"]:
		_check(t in tut_titles, "tutorial mode adds the '%s' beat" % t)
	var text := _all_text(tut)
	for stat in ["STRENGTH", "DEXTERITY", "INTELLIGENCE", "WISDOM", "DETERMINATION", "AGILITY"]:
		_check(text.contains(stat), "tutorial mode teaches %s" % stat)
	_check(text.contains("no stat raises your health") and text.contains("mana"), "it says only gear raises health and mana")
	_check(text.contains("ONE HAND") and text.contains("TWO IN HAND") and text.contains("TWO-HANDED"),
		"it covers single-hand, dual and two-handed wielding")

	var card_steps := tut.filter(func(st): return str(st["card"]) != "")
	_check(card_steps.size() >= 8, "each card type has its own beat with an example card (%d)" % card_steps.size())
	var titles := _titles(tut)
	_check(titles.has("Instant") and not titles.has("Reaction"), "reactions and instants share one beat")
	_check(titles.has("Drawing") and titles.has("The Cheese Rule"), "Olorin explains drawing and the cheese rule")
	var cheese_beat = tut.filter(func(st): return str(st["title"]) == "The Cheese Rule")
	_check(cheese_beat.size() == 1 and str(cheese_beat[0]["card"]) == "heavy_greedy_cheese",
		"…showing the Heavy Greedy Cheese card")
	var all_real := true
	for st in card_steps:
		all_real = all_real and Card.create_by_id(str(st["card"])) != null
	_check(all_real, "every example card exists")

	# Run the card beats: the card stands in the middle, enlarged, then goes.
	var steps := [card_steps[0], {"title": "After", "focus": [], "paragraphs": ["x"], "card": ""}]
	_check(olorin.show_tour("test_cards", steps, true), "a tour with a card beat starts")
	await _settle(3)
	var card_node: Control = olorin._tour_card
	_check(card_node != null and is_instance_valid(card_node), "the beat's card is shown")
	if card_node:
		var vp: Vector2 = get_root().get_visible_rect().size
		var mid: float = card_node.position.x + card_node.size.x * 0.5
		_check(absf(mid - vp.x * 0.5) < 4.0, "…centred across the screen")
		_check(card_node.size.y > CardUI.CARD_H * 1.2, "…and enlarged (%d px tall)" % card_node.size.y)
	olorin._tour_next()
	await _settle(2)
	_check(olorin._tour_card == null or not is_instance_valid(olorin._tour_card), "the next beat without a card clears it")
	olorin._close()
	holder.queue_free()
	await _settle(2)

func _test_first_level_up() -> void:
	print("-- The first level-up --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	var c := CharacterData.create_brad()
	main.set("starting_character", c)
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle(6)
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	var stats = main.player.get_stats()
	stats.current_health = 1
	stats.gain_xp(stats.get_xp_to_next_level() - stats.current_xp)
	await _settle(2)
	_check(stats.current_level == 2, "the hero reached level 2")
	_check(stats.current_health == stats.max_health, "a level heals fully")
	_check(main.player.get_node_or_null("LevelUpFX") != null, "the golden pillar rises round the hero")
	_check(main.olorin.is_busy() and main.olorin.tour_step_index() == 0, "Olorin steps in with the first level-up lesson")
	_check(main.olorin.has_seen(OlorinTutorial.FIRST_LEVEL_UP_ID), "…and remembers it")
	main.olorin._close()
	await _settle(2)
	stats.gain_xp(stats.get_xp_to_next_level() - stats.current_xp)
	await _settle(2)
	_check(not main.olorin.is_busy(), "the next level-up does not repeat the lesson")
	main.queue_free()
	await _settle(2)
