extends SceneTree

## Return Scroll round trip, on the overworld and inside a cave: open the
## portal, step through to town, step back through the twin. The player must
## land beside the portal tile with the ground around them (and everything
## walked before) still revealed, and the battle-side portal must be gone —
## it is spent once the player has come back through it.
## Run: godot --headless --path . --script tests/test_town_portal_return.gd

var failures: int = 0

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

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

func _settle(frames: int = 10) -> void:
	for _i in range(frames):
		await process_frame

func _revealed_count(dm) -> int:
	var n := 0
	var bytes: PackedByteArray = dm.get_revealed_bytes()
	for b in bytes:
		n += 1 if b != 0 else 0
	return n

func _round_trip(main: Node, where: String) -> Node:
	var dm = main.dungeon_manager
	var gm = main.grid_manager
	# Walk somewhere far from the level's start first: the scene opens
	# looking at the start, so a return there used to show only fog.
	var start: Vector2i = gm.world_to_grid(main.player.position)
	var far := start
	for x in range(dm.GRID_W):
		for z in range(dm.GRID_H):
			var c := Vector2i(x, z)
			if dm.is_floor(c) and dm.is_floor(c + Vector2i(1, 0)) and dm.is_floor(c + Vector2i(0, 1)) \
					and c.distance_to(start) > far.distance_to(start) and c.distance_to(start) < 30:
				far = c
	_check(far.distance_to(start) > 12, "%s: found ground far from the start (%s)" % [where, far])
	var fw: Vector3 = gm.grid_to_world(far)
	main.player.position = Vector3(fw.x, dm.get_elevation_world_y(far), fw.z)
	main.player.target_position = main.player.position
	main._update_fog_of_war()
	main.spawn_town_portal()
	await _settle(2)
	var portal_pos: Vector3 = main._town_portal_node.position
	var before := _revealed_count(dm)
	_check(before > 0, "%s: some ground is revealed before leaving (%d tiles)" % [where, before])
	_check(main._try_interact_town_portal(), "%s: stepping into the portal travels home" % where)
	await _settle()
	var town = _find_town()
	_check(town != null, "%s: arrived in town" % where)
	if town == null:
		return null
	_check(is_instance_valid(town._return_portal_node), "%s: the twin portal stands in town" % where)
	town._go_to_battle(true)
	await _settle(14)
	var back = _find_main()
	_check(back != null, "%s: back in the world" % where)
	if back == null:
		return null
	var bdm = back.dungeon_manager
	var bgm = back.grid_manager
	var cell: Vector2i = bgm.world_to_grid(back.player.position)
	var pcell: Vector2i = bgm.world_to_grid(portal_pos)
	_check(cell.distance_to(pcell) <= 1.5, "%s: landed beside the portal tile (%s vs %s)" % [where, cell, pcell])
	_check(bdm.is_revealed(cell), "%s: the player's own tile is revealed" % where)
	var around := 0
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if bdm.is_revealed(cell + Vector2i(dx, dz)):
				around += 1
	_check(around >= 20, "%s: the ground around the player is revealed (%d/25)" % [where, around])
	var cam: Vector3 = back._camera_focus
	_check(Vector2(cam.x - back.player.position.x, cam.z - back.player.position.z).length() < 4.0,
		"%s: the camera looks at the player, not the level's start" % where)
	var after := _revealed_count(bdm)
	_check(after >= before, "%s: everything walked before stays revealed (%d >= %d)" % [where, after, before])
	_check(not is_instance_valid(back._town_portal_node), "%s: the portal is gone once used to come back" % where)
	_check(back.get_node_or_null("TownPortal") == null, "%s: no TownPortal node left in the scene" % where)
	return back

func _run() -> void:
	print("=== Town portal return test ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.starting_character = CharacterData.create_brad()
	get_root().add_child(main)
	await _settle()
	if main.olorin and main.olorin.has_method("is_busy") and main.olorin.is_busy():
		main.olorin._close()
	var back = await _round_trip(main, "overworld")
	if back == null:
		return _finish()
	# Every kind of place the player can go into from world 1 (caves,
	# buildings, sewers, forests...): the same round trip from inside each.
	var seen := {}
	var ids: Array = []
	for s in back.dungeon_manager.site_nodes:
		var sid: String = s["id"]
		var kind := sid.rstrip("0123456789_")
		if s["kind"] in ["exit", "start"] or seen.has(kind):
			continue
		seen[kind] = true
		ids.append(sid)
	_check(ids.size() >= 2, "world 1 has places to go into (%s)" % ", ".join(ids))
	var outside = back
	for sid in ids:
		outside._enter_interior(sid, sid)
		await _settle()
		var inside = _find_main()
		_check(inside != null and inside.current_interior_id == sid, "entered %s" % sid)
		if inside == null or inside.current_interior_id != sid:
			continue
		var came_back = await _round_trip(inside, sid)
		if came_back == null:
			break
		_check(came_back.current_interior_id == sid, "%s: came back inside, not the overworld" % sid)
		came_back._exit_interior()
		await _settle()
		outside = _find_main()
		if outside == null or outside.current_interior_id != "":
			_check(false, "%s: left it for the overworld" % sid)
			break
	_finish()

func _finish() -> void:
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
