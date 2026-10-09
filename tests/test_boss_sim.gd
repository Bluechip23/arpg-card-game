extends SceneTree

## The Boss Simulator (Test > Boss Simulator, and the Boss Fights section of
## the sandbox panel): the sandbox booted inside a boss room.
##  - Every sandbox tool is there (the panel, refill, add card/item/passive).
##  - The room is never "cleared": the boss is up even for a character who has
##    beaten it, and beating it here is never written to the character.
##  - No sandbox high-ground platforms in a boss room (fought as laid out).
##  - Entering another boss room from inside one returns to the arena, not to
##    the previous room; Back to arena leaves with the sandbox intact.
## Run: godot --headless --path . --script tests/test_boss_sim.gd

var failures: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	await _test()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _dismiss(main) -> void:
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame

func _find_main() -> Node:
	for child in get_root().get_children():
		if child.get_script() and "current_interior_id" in child and not child.is_queued_for_deletion():
			return child
	return null

func _first(main, type: int) -> Enemy:
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == type:
			return e
	return null

func _flat(dm) -> bool:
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			if dm.elevation[x][z] != 0:
				return false
	return true

func _test() -> void:
	print("-- Boss Simulator: sandbox booted inside Hell's Gate --")
	var brad := CharacterData.create_brad()
	brad.mark_boss_defeated("hellgate")  # in the story this room would stand open
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", brad)
	main.set("sandbox_mode", true)
	main.set("current_interior_id", "hellgate")
	get_root().add_child(main)
	await _settle()
	await _dismiss(main)
	_check(main.sandbox_mode and main.boss_room_mode, "sandbox and boss room at once")
	_check(main.sandbox_ui != null and main.sandbox_ui.is_in_boss_room(), "the sandbox panel is up and knows the fight")
	var dog: Enemy = _first(main, Enemy.EnemyType.CERBERUS)
	var door: Enemy = _first(main, Enemy.EnemyType.HELL_DOOR)
	_check(dog != null and door != null, "Cerberus and the door are up even though this character already broke it")
	_check(main.dungeon_manager.get_site_by_id("exit") < 0, "the room is sealed")
	_check(_flat(main.dungeon_manager), "no sandbox platforms were raised in the boss room")
	var st = main.player.get_stats()
	_check(st.max_mana == 999 and st.current_mana == 999, "sandbox mana pool applies")
	# The sandbox tools: a card and a refill.
	var hand0: int = main.deck_manager.hand.size()
	main._on_sandbox_add_card("slash")
	_check(main.deck_manager.hand.size() == hand0 + 1, "Add Card works inside the fight")
	st.current_health = 1
	main._sandbox_refill()
	_check(st.current_health == st.max_health, "Refill works inside the fight")
	# Beat the fight: the exit opens, the character's record is untouched.
	if door:
		door.take_damage(100000, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(2)
	_check(main.dungeon_manager.get_site_by_id("exit") >= 0, "breaking the door opens the way out")
	_check(brad.defeated_bosses == ["hellgate"], "a sandbox clear writes nothing new to the character (%s)" % str(brad.defeated_bosses))

	print("-- Switching fights from inside a boss room --")
	main._on_sandbox_enter_boss_room("labyrinth")
	await _settle()
	var lab = _find_main()
	_check(lab != null and lab != main, "a new scene replaced the old one")
	if lab == null:
		return
	await _dismiss(lab)
	_check(lab.sandbox_mode and lab.current_interior_id == "labyrinth" and lab.boss_room_mode, "the Labyrinth, still in sandbox")
	_check(lab.parent_interior_id == "", "it returns to the arena, not to Hell's Gate")
	_check(lab.sandbox_ui != null and lab.sandbox_ui.is_in_boss_room(), "the panel follows")
	var bull: Enemy = _first(lab, Enemy.EnemyType.INFLAMED_MINOTAUR)
	_check(bull != null, "the Minotaur is up")
	_check(_flat(lab.dungeon_manager), "the maze is untouched by sandbox platforms")
	if bull:
		bull.take_damage(100000, true, DamageTypes.Type.PHYSICAL, true)
	await _settle(2)
	_check(not brad.has_defeated_boss("labyrinth"), "killing him here is practice: not recorded")
	_check(lab.dungeon_manager.get_site_by_id("exit") >= 0, "but the room still opens")

	print("-- Restart: the same room, fresh --")
	lab._on_sandbox_enter_boss_room("labyrinth")
	await _settle()
	var lab2 = _find_main()
	_check(lab2 != null and lab2 != lab and lab2.current_interior_id == "labyrinth" and lab2.sandbox_mode, "restart reloads the Labyrinth in sandbox")
	if lab2 == null:
		return
	await _dismiss(lab2)
	_check(_first(lab2, Enemy.EnemyType.INFLAMED_MINOTAUR) != null and lab2.dungeon_manager.get_site_by_id("exit") < 0, "the Minotaur is back and the room is sealed again")
	_check(lab2.parent_interior_id == "", "and it still returns to the arena")

	print("-- Back to the arena --")
	lab2._on_sandbox_leave_boss_room()
	await _settle()
	var arena = _find_main()
	_check(arena != null and arena.current_interior_id == "" and arena.sandbox_mode and not arena.boss_room_mode, "the arena, in sandbox")
	if arena == null:
		return
	await _dismiss(arena)
	_check(arena.sandbox_ui != null and not arena.sandbox_ui.is_in_boss_room(), "the panel is back to arena mode")
	_check(not _flat(arena.dungeon_manager), "the arena's high-ground platforms are raised again")
	# The picker (Test > Boss Simulator opens on it).
	arena.sandbox_ui.show_boss_picker()
	_check(arena.sandbox_ui.is_menu_open(), "the boss picker is modal while up")
	arena.sandbox_ui._close_boss_picker()
	_check(not arena.sandbox_ui.is_menu_open(), "and releases the field when closed")
	arena.queue_free()
	await _settle()
