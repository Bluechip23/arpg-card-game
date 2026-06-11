extends SceneTree

## End-to-end test: boot main scene, enter a cave, leave it, verify the player
## returns to the cave entrance in the same world; then verify the town round
## trip preserves the current world level.
## Run: godot --headless --path . --script tests/test_interior_flow.gd

var failures: int = 0

func _initialize() -> void:
	_run()

func _fail(msg: String) -> void:
	failures += 1
	print("FAIL: %s" % msg)

func _find_main() -> Node:
	for child in get_root().get_children():
		if child.get_script() and "current_interior_id" in child and not child.is_queued_for_deletion():
			return child
	return null

func _find_town() -> Node:
	for child in get_root().get_children():
		if child.get_script() and "return_world_level" in child and not child.is_queued_for_deletion():
			return child
	return null

func _settle(frames: int = 8) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
	var main = load("res://scenes/core/main.tscn").instantiate()
	get_root().add_child(main)
	await _settle()

	if main.dungeon_manager == null:
		_fail("dungeon_manager missing after boot")
		return _finish()
	if main.dungeon_manager.site_nodes.size() < 2:
		_fail("expected at least 2 sites in world 1")

	# --- Enter the first cave ---
	var cave_site = null
	for s in main.dungeon_manager.site_nodes:
		if s["kind"] == "cave":
			cave_site = s
			break
	if cave_site == null:
		_fail("no cave site found in world 1")
		return _finish()
	var cave_id: String = cave_site["id"]
	var entrance: Vector2i = cave_site["grid_pos"]

	main._enter_interior(cave_id, "Cave")
	await _settle()

	var inside = _find_main()
	if inside == null:
		_fail("no main scene after entering interior")
		return _finish()
	if inside.current_interior_id != cave_id:
		_fail("expected interior %s, got '%s'" % [cave_id, inside.current_interior_id])
	if inside.current_world_level != 1:
		_fail("world level changed when entering interior")
	if inside.dungeon_manager.get_site_by_id("exit") < 0:
		_fail("interior has no exit site")
	if inside.dungeon_manager.waypoint_nodes.size() != 0:
		_fail("interior should have no waypoints")
	if inside.get_location_label().find("Cave") < 0:
		_fail("location label should mention Cave, got '%s'" % inside.get_location_label())

	# --- Leave the cave ---
	inside._exit_interior()
	await _settle()

	var back = _find_main()
	if back == null:
		_fail("no main scene after exiting interior")
		return _finish()
	if back.current_interior_id != "":
		_fail("should be back in overworld, got '%s'" % back.current_interior_id)
	var back_grid: Vector2i = back.grid_manager.world_to_grid(back.player.position)
	if back_grid != entrance:
		_fail("player should respawn at cave entrance %s, got %s" % [entrance, back_grid])
	if not back.dungeon_manager.is_revealed(entrance):
		_fail("entrance area should be revealed after returning")

	# --- Town round trip preserves world ---
	back._travel_to_world(2)
	await _settle()
	var w2 = _find_main()
	if w2 == null or w2.current_world_level != 2:
		_fail("travel to world 2 failed")
		return _finish()
	w2._travel_to_town()
	await _settle()
	var town = _find_town()
	if town == null:
		_fail("no town scene after traveling to town")
		return _finish()
	if town.return_world_level != 2:
		_fail("town should remember world 2, got %d" % town.return_world_level)
	town._go_to_battle()
	await _settle()
	var w2_again = _find_main()
	if w2_again == null or w2_again.current_world_level != 2:
		_fail("returning from town should land in world 2, got %s" % (str(w2_again.current_world_level) if w2_again else "none"))

	_finish()

func _finish() -> void:
	if failures == 0:
		print("ALL INTERIOR FLOW TESTS PASSED")
	else:
		print("TOTAL FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
