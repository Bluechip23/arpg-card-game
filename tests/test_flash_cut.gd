extends SceneTree

## Verifies the Flash Cut agility keystone: the Sidestep action (3 flash → block)
## becomes an attack (3 flash → strike) while the keystone is active.
## Covers grid placement, the flash spend, and the save/restore round trip.
## (The actual enemy damage is applied in Main._flash_strike, which needs a live
## battle scene; here we verify the flash economy and keystone plumbing.)
## Run: godot --headless --path . --script tests/test_flash_cut.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Flash Cut keystone test ===")
	_test_grid_placement()
	_test_flash_spend()
	_test_persistence()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_grid_placement() -> void:
	print("-- Grid placement --")
	var grid = SphereGrid.new()
	var node = grid.get_node_by_id(118)
	_check(node.node_type == SphereGrid.NodeType.KEYSTONE and node.keystone_id == "flash_strike",
		"node 118 is the Flash Cut keystone")
	_check(node.requirements.get("stat", "") == "agility" and node.requirements.get("value", 0) == 15,
		"Flash Cut is gated behind AGI 15")

func _test_flash_spend() -> void:
	print("-- Flash economy --")
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	var data = CharacterData.create_ryan()
	data.agility = 10  # a healthy flash pool
	stats.initialize(data)
	stats.refresh_flash_points()
	var pool = stats.current_flash_points
	_check(pool >= PlayerStats.FLASH_COST_BLOCK, "start with enough flash to Sidestep/Cut (%d)" % pool)

	_check(stats.spend_flash_for_strike(), "Flash Cut spends successfully when affordable")
	_check(stats.current_flash_points == pool - PlayerStats.FLASH_COST_BLOCK,
		"it spends exactly FLASH_COST_BLOCK (%d -> %d)" % [pool, stats.current_flash_points])

	# Drain below the cost and confirm it refuses.
	stats.current_flash_points = PlayerStats.FLASH_COST_BLOCK - 1
	_check(not stats.spend_flash_for_strike(), "Flash Cut refuses when flash is too low")

	_check(PlayerStats.FLASH_STRIKE_DAMAGE >= 1, "Flash Cut deals at least 1 damage (%d)" % PlayerStats.FLASH_STRIKE_DAMAGE)

func _test_persistence() -> void:
	print("-- Save / restore --")
	var data = CharacterData.create_ryan()
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	stats.keystone_flash_strike = true
	var snap = stats.save_progression()
	var restored = PlayerStats.new()
	get_root().add_child(restored)
	restored.initialize(data)
	restored.restore_progression(snap)
	_check(restored.keystone_flash_strike, "Flash Cut flag survives save/restore")
