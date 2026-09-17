extends SceneTree

## Rescue NPCs: The Missing Woodcutter is found in the Greenwood's deep
## clearing, follows the player tile by tile once spoken to, and is
## delivered by leaving the forest; the rescued foreman then stands at the
## trailhead as a lumber depot. Same machinery for the Sellsword's partner.
## Run: godot --headless --path . --script tests/test_escort_quests.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _find_main() -> Node:
	for child in get_root().get_children():
		if child.get_script() and "current_interior_id" in child and not child.is_queued_for_deletion():
			return child
	return null

func _initialize() -> void:
	print("=== Escort quests test ===")
	await _run()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _run() -> void:
	# Quest state as if Olorin's first errand is done and both rescues accepted.
	var qm := QuestManager.new()
	qm._ready()
	qm.accept_quest("olorin_kill_wererats")
	for _i in range(5):
		qm.on_enemy_killed("Wererat")
	qm.turn_in_quest("olorin_kill_wererats")
	_check(qm.accept_quest("missing_woodcutter") and qm.accept_quest("sellswords_debt"), "both rescue quests are offered and accepted")

	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("quest_state", qm.save_state())
	get_root().add_child(main)
	await _settle()
	_check(main._rescue_npcs.is_empty(), "no rescue NPC on the surface before the rescue")

	var forest_id := ""
	for s in main.dungeon_manager.site_nodes:
		if s["kind"] == "forest":
			forest_id = s["id"]
	_check(forest_id != "", "world 1 has the Greenwood")
	main._enter_interior(forest_id, "Greenwood")
	await _settle()
	var inside = _find_main()
	_check(inside != null and inside.dungeon_manager.interior_kind == "forest", "entered the forest")
	_check(inside._rescue_npcs.size() == 1 and inside._rescue_npcs[0].npc_id == "npc_woodcutter", "the foreman waits in the Greenwood")
	var npc = inside._rescue_npcs[0]
	var deep_kind := ""
	for room in inside.dungeon_manager.rooms:
		if room["rect"].has_point(npc.grid_cell):
			deep_kind = room["kind"]
	_check(deep_kind == "deep", "…in the deep clearing (room kind %s)" % deep_kind)

	# Walk up and talk: he starts following; the "reach" objective completes.
	var beside: Vector2i = npc.grid_cell + Vector2i(1, 0)
	inside.player.position = inside.grid_manager.grid_to_world(beside)
	inside.player.target_position = inside.player.position
	inside._player_last_grid_cell = beside
	_check(inside._try_interact_rescue_npc(), "Shift beside the foreman talks to him")
	_check(npc.following and inside._follower == npc, "…and he follows")
	_check(inside.quest_manager.get_quest("missing_woodcutter").objectives[0].is_done(), "…completing 'find the foreman'")

	# Each tile the player takes, he steps onto the one just vacated.
	var next: Vector2i = beside + Vector2i(1, 0)
	inside.player.position = inside.grid_manager.grid_to_world(next)
	inside.player.tile_reached.emit()
	_check(npc.grid_cell == beside, "he follows onto the vacated tile (%s)" % [npc.grid_cell])

	# Leaving the forest with him delivers him.
	inside._exit_interior()
	await _settle()
	var outside = _find_main()
	var wq = outside.quest_manager.get_quest("missing_woodcutter")
	_check(wq != null and wq.is_complete, "walking him out completes The Missing Woodcutter")
	_check(outside._rescue_npcs.is_empty(), "no depot until the quest is turned in")

	# Turn in (as Olorin would) → the foreman stands at the trailhead as a depot.
	outside.quest_manager.turn_in_quest("missing_woodcutter", outside.player.get_stats())
	_check(outside.quest_manager.has_flag("woodcutter_rescued"), "turn-in records the rescue")
	outside._place_quest_npcs()
	var depot = null
	for n in outside._rescue_npcs:
		if n.depot:
			depot = n
	_check(depot != null, "the foreman now stands on the surface as a lumber depot")
	if depot:
		var fcell: Vector2i = Vector2i(-99, -99)
		for s in outside.dungeon_manager.site_nodes:
			if s["kind"] == "forest":
				fcell = s["grid_pos"]
		_check(absi(depot.grid_cell.x - fcell.x) + absi(depot.grid_cell.y - fcell.y) <= 3, "…beside the Greenwood trailhead")
		outside.player.position = outside.grid_manager.grid_to_world(depot.grid_cell + Vector2i(1, 0))
		outside.player.target_position = outside.player.position
		_check(outside._try_interact_rescue_npc(), "Shift at the depot is handled (no city yet: he says so)")

	# The partner uses the same machinery in a cave.
	var cave_id := ""
	for s in outside.dungeon_manager.site_nodes:
		if s["kind"] == "cave":
			cave_id = s["id"]
	outside._enter_interior(cave_id, "Cave")
	await _settle()
	var cave = _find_main()
	var partner = null
	for n in cave._rescue_npcs:
		if n.npc_id == "npc_partner":
			partner = n
	_check(partner != null, "the Sellsword's partner waits in the cave")
	if partner:
		cave.player.position = cave.grid_manager.grid_to_world(partner.grid_cell + Vector2i(0, 1))
		cave.player.target_position = cave.player.position
		cave._try_interact_rescue_npc()
		cave._exit_interior()
		await _settle()
		var back = _find_main()
		_check(back.quest_manager.get_quest("sellswords_debt").is_complete, "walking her out completes A Debt to the Sellsword")
