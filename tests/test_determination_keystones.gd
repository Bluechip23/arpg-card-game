extends SceneTree

## Verifies the two Determination keystones on the sphere grid:
##   Unbroken Will (det_floor)  — raises the penalty clamp from 0.0 to 0.5
##   Wild Abandon  (det_amplify)— amplifies the determination swing ×1.5 both ways
## Covers grid placement, the get_determination_modifier() math, and that both
## flags survive a save_progression -> restore_progression round trip.
## Run: godot --headless --path . --script tests/test_determination_keystones.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _approx(a: float, b: float) -> bool:
	return abs(a - b) < 0.001

func _initialize() -> void:
	print("=== Determination keystones test ===")
	_test_grid_placement()
	_test_modifier_math()
	_test_persistence()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_grid_placement() -> void:
	print("-- Grid placement --")
	var grid = SphereGrid.new()
	var floor_node = grid.get_node_by_id(128)
	var amp_node = grid.get_node_by_id(129)
	_check(floor_node.node_type == SphereGrid.NodeType.KEYSTONE and floor_node.keystone_id == "det_floor",
		"node 128 is the Unbroken Will keystone")
	_check(amp_node.node_type == SphereGrid.NodeType.KEYSTONE and amp_node.keystone_id == "det_amplify",
		"node 129 is the Wild Abandon keystone")
	_check(floor_node.requirements.get("stat", "") == "determination" and floor_node.requirements.get("value", 0) == 15,
		"Unbroken Will is gated behind DET 15")
	_check(amp_node.requirements.get("stat", "") == "determination" and amp_node.requirements.get("value", 0) == 15,
		"Wild Abandon is gated behind DET 15")

func _test_modifier_math() -> void:
	print("-- get_determination_modifier() --")
	var data = CharacterData.create_ryan()  # DET 3 (det_diff = -12)
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	# Drive health to <=10% so the strongest band (0.01 per point) applies.
	stats.current_health = maxi(1, int(stats.max_health * 0.1))

	# Baseline: 1.0 + (-12 * 0.01) = 0.88
	_check(_approx(stats.get_determination_modifier(), 0.88),
		"baseline penalty at 10%% HP, DET 3 = 0.88 (got %.2f)" % stats.get_determination_modifier())

	# Wild Abandon: swing ×1.5 -> 1.0 + (-0.18) = 0.82
	stats.keystone_det_amplify = true
	_check(_approx(stats.get_determination_modifier(), 0.82),
		"Wild Abandon deepens the penalty to 0.82 (got %.2f)" % stats.get_determination_modifier())
	stats.keystone_det_amplify = false

	# The clamps still guard extreme penalties (unreachable through normal
	# play at 0.01/point, so force an absurd DET to exercise them).
	stats.determination = -100  # det_diff = -115 -> raw modifier -1.15
	_check(_approx(stats.get_determination_modifier(), 0.0),
		"penalty bottoms out at 0.0 without Unbroken Will (got %.2f)" % stats.get_determination_modifier())
	stats.keystone_det_floor = true
	_check(_approx(stats.get_determination_modifier(), 0.50),
		"Unbroken Will floors the penalty at 0.50 (got %.2f)" % stats.get_determination_modifier())

	# Both together: amplified penalty, but Unbroken Will still floors it at 0.50
	stats.keystone_det_amplify = true
	_check(_approx(stats.get_determination_modifier(), 0.50),
		"Unbroken Will floors even Wild Abandon's amplified penalty at 0.50 (got %.2f)" % stats.get_determination_modifier())
	stats.keystone_det_floor = false
	stats.keystone_det_amplify = false

	# Wild Abandon amplifies the UPSIDE too (no cap on buffs).
	stats.determination = 35  # det_diff = +20 -> 1.0 + 0.20 = 1.20 baseline
	_check(_approx(stats.get_determination_modifier(), 1.20),
		"high-DET buff baseline = 1.20 (got %.2f)" % stats.get_determination_modifier())
	stats.keystone_det_amplify = true
	_check(_approx(stats.get_determination_modifier(), 1.30),
		"Wild Abandon raises the buff to 1.30 (got %.2f)" % stats.get_determination_modifier())

func _test_persistence() -> void:
	print("-- Save / restore --")
	var data = CharacterData.create_ryan()
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	stats.keystone_det_floor = true
	stats.keystone_det_amplify = true
	var snap = stats.save_progression()

	var restored = PlayerStats.new()
	get_root().add_child(restored)
	restored.initialize(data)
	restored.restore_progression(snap)
	_check(restored.keystone_det_floor, "Unbroken Will flag survives save/restore")
	_check(restored.keystone_det_amplify, "Wild Abandon flag survives save/restore")
