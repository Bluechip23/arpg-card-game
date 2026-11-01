extends SceneTree

## Co-op: the basic Block button lights only when BOTH heroes wear a shield
## (designer, 2026-11-01). And a waypoint is a platform: a hero on its tile
## stands up on it, WAYPOINT_MOUND_HEIGHT above the ground.
## Run: godot --headless --path . --script tests/test_coop_block_and_waypoint.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Co-op block & waypoint platform ===")
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(main)
	for _i in range(12):
		await process_frame
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	# Waypoint platform: the ground under the waypoint's tile is the mound top.
	var dm = main.dungeon_manager
	_check(dm != null and dm.waypoint_nodes.size() > 0, "the world has a waypoint")
	if dm and dm.waypoint_nodes.size() > 0:
		var cell: Vector2i = dm.waypoint_nodes[0]["grid_pos"]
		var on: float = main._desired_ground_y(main.grid_manager.grid_to_world(cell))
		var beside: float = main._desired_ground_y(main.grid_manager.grid_to_world(cell + Vector2i(3, 0)))
		_check(absf(on - beside - DungeonManager.WAYPOINT_MOUND_HEIGHT) < 0.001 and DungeonManager.WAYPOINT_MOUND_HEIGHT > 0.2,
			"a hero on the waypoint tile stands %.2f up on the platform" % (on - beside))
		var shrine = dm.waypoint_nodes[0]["pillar_mesh"]
		_check(shrine.sorting_offset < 0.0, "the shrine draws behind whoever stands on it")
	# Co-op block.
	main._on_sandbox_add_ally("Jeremy")
	await process_frame
	var p1: Player = main._p1_player
	var p2: Player = main._p2_player
	_check(main.is_multiplayer and p2 != null, "a partner joins")
	var b: Button = main._block_button
	for p in [p1, p2]:
		var inv = p.get_inventory()
		for i in range(inv.equipped_weapons.size()):
			if inv.equipped_weapons[i] and inv.equipped_weapons[i] == inv.get_equipped_shield():
				inv.equipped_weapons[i] = null
	main._update_block_button_visibility()
	_check(b.disabled, "no shields: the Block button is greyed")
	var s1 = ItemData.create("wooden_shield")
	p1.get_inventory().stored_items.append(s1)
	p1.get_inventory().equip_item(s1, 1)
	main._update_block_button_visibility()
	_check(b.disabled and "Both" in b.tooltip_text, "only player 1 shielded: still greyed (%s)" % b.tooltip_text)
	var armor_before: int = p1.get_stats().current_armor
	main._on_block_pressed()
	_check(p1.get_stats().current_armor == armor_before, "and pressing it blocks nothing")
	var s2 = ItemData.create("wooden_shield")
	p2.get_inventory().stored_items.append(s2)
	p2.get_inventory().equip_item(s2, 1)
	main._update_block_button_visibility()
	_check(not b.disabled, "both shielded: the Block button lights")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
