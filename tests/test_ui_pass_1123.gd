extends SceneTree

## Designer's UI pass, 2026-11-23:
##  - the inventory's card window shows the card itself (its real face);
##  - the quest log lists a quest only once it is unlocked (test mode: all);
##  - the Stats tab leaves Passives / Sphere Grid / Close in reach, and a
##    stat's name, clicked, opens a small window saying what the stat does.
## Run: godot --headless --path . --script tests/test_ui_pass_1123.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _click(target: Control) -> void:
	## A real mouse click, so anything lying over the target would eat it.
	var pos: Vector2 = target.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_root().push_input(ev)
		await process_frame
	await _settle(3)

func _initialize() -> void:
	_run()

func _quests() -> void:
	print("--- quest log ---")
	var qm := QuestManager.new()
	get_root().add_child(qm)
	for id in qm.available_quests.keys():
		qm.accept_quest(id)
	var total := qm.get_active_quests().size()
	var ids: Array = []
	for q in qm.get_log_quests():
		ids.append(q.id)
	_check("olorin_kill_wererats" in ids, "a quest with nothing before it is in the log")
	_check(not ("holy_water_well" in ids), "a quest behind an unfinished one stays out of the log")
	_check(not ("ferryman_toll" in ids), "so does one from a later world")
	_check(qm.get_active_quests().size() == total, "the held quests themselves are untouched")
	for o in qm.get_quest("olorin_kill_wererats").objectives:
		o.current = o.count
	qm.get_quest("olorin_kill_wererats").refresh_complete()
	qm.turn_in_quest("olorin_kill_wererats")
	ids.clear()
	for q in qm.get_log_quests():
		ids.append(q.id)
	_check("holy_water_well" in ids, "turning in the quest before it unlocks it into the log")
	_check(not ("ferryman_toll" in ids), "the later world's quest still waits")
	qm.log_shows_all = true
	_check(qm.get_log_quests().size() == qm.get_active_quests().size(), "test mode lists every quest")
	var qm2 := QuestManager.new()
	get_root().add_child(qm2)
	qm2.load_state(qm.save_state())
	_check(qm2.log_shows_all, "test mode travels with the quest state")
	qm.queue_free()
	qm2.queue_free()

func _run() -> void:
	print("=== UI pass 2026-11-23 ===")
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle(10)
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(not main.quest_manager.log_shows_all, "real play: the log shows unlocked quests only")
	_quests()   # (the tree is running now: a new QuestManager defines its quests)

	print("--- card window ---")
	var inv = main.player.get_inventory()
	var card: Card = main.deck_manager.draw_pile[0]
	inv.stored_cards.append(card)
	var panel = main.character_panel
	panel.show_panel()
	panel._on_card_cell_clicked(card, inv.stored_cards.find(card))
	await _settle()
	var pop: Control = panel._card_confirm_popup
	var faces: Array = pop.find_children("*", "CardUI", true, false) if is_instance_valid(pop) else []
	_check(faces.size() == 1, "the card window holds the card's own face")
	if faces.size() == 1:
		_check(faces[0]._card == card, "and it is the clicked card")
		_check(pop.get_global_rect().grow(1.0).encloses(faces[0].get_parent().get_global_rect()), "the face sits inside the window")
	panel.hide_panel()

	print("--- stats tab ---")
	main.player.get_stats().unspent_stat_points = 3
	main._open_progression_screen()
	var ui = main.skill_tree_ui
	await _click(ui._stat_alloc_btn)
	_check(ui._stats_open(), "the Stats tab opens")
	var name_btn: Button = ui._stat_alloc_panel.find_child("Name_intelligence", true, false)
	_check(name_btn != null and name_btn.visible, "each stat's name is a button")
	if name_btn:
		await _click(name_btn)
		_check(is_instance_valid(ui._stat_info_window) and ui._stat_info_key == "INT", "clicking Intelligence opens its info window")
		if is_instance_valid(ui._stat_info_window):
			var body: Label = ui._stat_info_window.find_child("Body", true, false)
			_check(body != null and "spell" in body.text, "which says what the stat does")
			var screen := Rect2(Vector2.ZERO, get_root().get_visible_rect().size)
			var w: Control = ui._stat_info_window
			_check(screen.encloses(Rect2(w.position, w.size * w.scale)), "and sits on screen")
		await _click(name_btn)
		_check(not is_instance_valid(ui._stat_info_window), "clicking the name again closes it")
	await _click(ui._tab_btn_sphere_grid)
	_check(not ui._stats_open() and ui._current_tab == ui.Tab.SPHERE_GRID and ui.visible, "Sphere Grid is one click away from Stats")
	await _click(ui._stat_alloc_btn)
	await _click(ui._tab_btn_skill_tree)
	_check(not ui._stats_open() and ui._current_tab == ui.Tab.SKILL_TREE and ui.visible, "and so is Passives")
	_check(main.player.get_stats().unspent_stat_points == 3, "leaving Stats unconfirmed keeps the points banked")
	await _click(ui._stat_alloc_btn)
	await _click(ui.close_button)
	_check(not ui.visible, "Close still shuts the screen from Stats")

	# Read-only (nothing banked): names stay, +/- go.
	main.player.get_stats().unspent_stat_points = 0
	main._open_progression_screen()
	ui._on_tab_stats()
	await _settle(3)
	name_btn = ui._stat_alloc_panel.find_child("Name_strength", true, false)
	var plus := 0
	for b in ui._stat_alloc_panel.find_children("*", "Button", true, false):
		if b.text == "+" and b.visible:
			plus += 1
	_check(name_btn != null and name_btn.visible and plus == 0, "with no points the names still show and the +/- do not")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
