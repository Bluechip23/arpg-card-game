extends SceneTree

## The in-game ? menu: Save, Quit to Menu and Quit to Desktop under the help
## tabs; quitting asks "Save before you quit?" (Yes / No / Cancel). Saving
## from the world snapshots the character as they are (a harpy keeps the card
## it carries; the save holds it in hand); "Yes" writes to the character's own
## slot, or opens the slot picker when they have none; then it's back to the
## title menu. The sandbox offers only the quits.
## Run: godot --headless --path . --script tests/test_game_menu_actions.gd

var failures := 0
const SLOT := 5
var _backup: PackedByteArray = PackedByteArray()
var _had_backup := false

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(n: int = 6) -> void:
	for _i in range(n):
		await process_frame

func _backup_slot() -> void:
	var path := SaveManager.get_save_path(SLOT)
	if FileAccess.file_exists(path):
		_had_backup = true
		_backup = FileAccess.get_file_as_bytes(path)
		DirAccess.remove_absolute(path)

func _restore_slot() -> void:
	var path := SaveManager.get_save_path(SLOT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if _had_backup:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(_backup)
		f.close()

func _new_main() -> Node:
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	return main

func _run() -> void:
	print("=== In-game ? menu: save and quit ===")
	_backup_slot()
	SaveManager.current_slot = -1
	var main = await _new_main()
	var hp: HelpPanel = main.help_panel

	# The row.
	_check(hp.actions_row != null, "the ? panel has a game actions row")
	_check(hp.save_button.visible and hp.save_button.text == "Save", "with Save")
	_check(hp.quit_menu_button.text == "Quit to Menu" and hp.quit_desktop_button.text == "Quit to Desktop", "and both quits")

	# The question, and Cancel backing out of it.
	# Listen in place of the game (a real "No" here would quit the test run);
	# GameMenuActions is driven directly further down.
	for con in hp.quit_requested.get_connections():
		hp.quit_requested.disconnect(con["callable"])
	var asked := []
	hp.quit_requested.connect(func(d, s): asked.append([d, s]))
	hp.show_panel(0)
	hp.ask_quit(false)
	await process_frame
	_check(hp.is_prompting(), "quitting asks first")
	var prompt: Node = hp.get_node("QuitPrompt")
	_check(prompt.find_child("Question", true, false).text == "Save before you quit?", "\"Save before you quit?\"")
	for nm in ["Yes", "No", "Cancel"]:
		_check(prompt.find_child(nm, true, false) is Button, "with %s" % nm)
	(prompt.find_child("Cancel", true, false) as Button).pressed.emit()
	await process_frame
	_check(not hp.is_prompting() and asked.is_empty() and hp.visible, "Cancel goes back to the panel, nothing quits")
	hp.ask_quit(true)
	await process_frame
	(hp.get_node("QuitPrompt").find_child("No", true, false) as Button).pressed.emit()
	await process_frame
	_check(asked.size() == 1 and asked[0] == [true, false], "No: quit to desktop without saving (%s)" % [asked])
	asked.clear()
	hp.ask_quit(false)
	await process_frame
	(hp.get_node("QuitPrompt").find_child("Yes", true, false) as Button).pressed.emit()
	await process_frame
	_check(asked.size() == 1 and asked[0] == [false, true], "Yes: quit to menu, saving first (%s)" % [asked])
	hp.visible = false

	# The world save: a snapshot of the character as they are.
	var data: SaveData = main._build_save_data(SLOT)
	_check(data != null and data.character_name == main.starting_character.character_name, "the world builds a save of %s" % (data.character_name if data else "nothing"))
	_check(data.current_location == "Town", "it wakes up in town when loaded")
	_check(data.progression.has("stats") and data.progression.has("deck_state") and data.progression.has("inventory"), "with stats, deck and inventory")
	_check(not data.deck_card_ids.is_empty(), "and the deck list for the load screen (%d cards)" % data.deck_card_ids.size())

	# A harpy holding a card: the save keeps it in hand, the harpy keeps it.
	var dm: DeckManager = main.deck_manager
	if not dm.hand.is_empty():
		var card: Card = dm.hand[0]
		dm.hand.erase(card)
		var harpy: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.ASH_HARPY, main.player.position + Vector3(3, 0, 3))
		await process_frame
		harpy._stolen_card = card
		harpy._stolen_from = main.player
		var hand_before := dm.hand.size()
		var d2: SaveData = main._build_save_data(SLOT)
		var ids := []
		for e in d2.progression["deck_state"]["hand"]:
			ids.append(e.get("id"))
		_check(card.card_id in ids, "a card in a harpy's claws is saved in hand")
		_check(harpy._stolen_card == card and dm.hand.size() == hand_before, "and saving doesn't hand it back mid-fight")
		harpy._stolen_card = null
		dm.hand.append(card)
	else:
		_check(false, "the hand has a card to steal")

	# The picker when the character has no slot: closing it calls the quit off.
	SaveManager.current_slot = -1
	GameMenuActions.quit(main, false, true, main._build_save_data)
	await process_frame
	var picker: SaveSlotPicker = null
	for c in main.get_children():
		if c is SaveSlotPicker:
			picker = c
	_check(picker != null, "no slot yet: Yes opens the slot picker")
	picker.close_picker()
	await _settle(2)
	_check(is_instance_valid(main) and main.is_inside_tree(), "closing the picker without saving stays in the game")

	# Yes with a slot of their own: saved there, then the title menu.
	SaveManager.current_slot = SLOT
	GameMenuActions.quit(main, false, true, main._build_save_data)
	await _settle(4)
	var loaded := SaveManager.load_game(SLOT)
	_check(loaded != null and loaded.character_name == "Brad", "Yes writes the save to the character's slot")
	_check(not is_instance_valid(main), "and the game closes")
	var title_up := false
	for c in get_root().get_children():
		if c.scene_file_path == GameMenuActions.TITLE_MENU:
			title_up = true
	_check(title_up, "back at the title menu")
	_check(SaveManager.current_slot == -1, "where no slot is the character's any more")
	for c in get_root().get_children():
		if c.scene_file_path == GameMenuActions.TITLE_MENU:
			c.queue_free()
	await _settle(2)

	# The save made out in the world loads, the way the Load screen does it.
	var town = load("res://scenes/menus/town.tscn").instantiate()
	town.starting_character = loaded.character_data
	town.player2_character = loaded.player2_character
	town.player_progression = ProgressionIO.to_live(loaded.progression)
	if not loaded.city.is_empty():
		town.player_progression["city"] = loaded.city
	town.return_world_level = loaded.world_level
	town.quest_state = loaded.progression.get("quest_state", {})
	town.discovered_waypoints = loaded.progression.get("discovered_waypoints", [])
	town.opened_chests = loaded.progression.get("opened_chests", {})
	get_root().add_child(town)
	await _settle(8)
	_check(town.player != null and is_instance_valid(town.player), "the world save loads into town")
	_check(town.player.get_stats().current_level == loaded.character_level, "at the saved level (%d)" % loaded.character_level)
	_check(town.help_panel.actions_row != null and town.help_panel.save_button.visible, "and town's ? menu has the same row")
	town.queue_free()
	await _settle(2)

	# The sandbox: quits only, no question.
	var sb = load("res://scenes/core/main.tscn").instantiate()
	sb.set("starting_character", CharacterData.create_brad())
	sb.set("sandbox_mode", true)
	get_root().add_child(sb)
	await _settle()
	_check(not sb.help_panel.save_button.visible, "the sandbox hides Save")
	for con in sb.help_panel.quit_requested.get_connections():
		sb.help_panel.quit_requested.disconnect(con["callable"])
	var sb_asked := []
	sb.help_panel.quit_requested.connect(func(d, s): sb_asked.append([d, s]))
	sb.help_panel.ask_quit(false)
	_check(sb_asked.size() == 1 and sb_asked[0] == [false, false] and not sb.help_panel.is_prompting(), "and quits without asking about saving")
	sb.queue_free()

	_restore_slot()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
