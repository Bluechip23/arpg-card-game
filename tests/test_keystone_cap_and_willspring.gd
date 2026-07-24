extends SceneTree

## Verifies the keystone attachment limit and the Willspring keystone:
##   * A character can attach at most SphereGrid.MAX_KEYSTONES (3) keystones —
##     unlock_node refuses the 4th; non-keystone nodes are unaffected.
##   * Willspring (det_mana) — Determination reads mana percentage, not health.
## Run: godot --headless --path . --script tests/test_keystone_cap_and_willspring.gd

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
	print("=== Keystone cap + Willspring test ===")
	_test_keystone_cap()
	_test_willspring_placement()
	_test_willspring_modifier()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_keystone_cap() -> void:
	print("-- Keystone limit (max %d) --" % SphereGrid.MAX_KEYSTONES)
	var grid = SphereGrid.new()
	# Ids 130-133 are consecutive keystone neighbors on ring 6. Seed the walk
	# from ring 5 node 96 (HP +30, non-keystone), which connects to 130.
	grid.get_node_by_id(96).unlocked = true

	_check(grid.unlock_node(130), "1st keystone unlocks")
	_check(grid.unlock_node(131), "2nd keystone unlocks")
	_check(grid.unlock_node(132), "3rd keystone unlocks")
	_check(grid.unlocked_keystone_count() == 3, "count reports 3 attached")
	_check(not grid.keystone_slots_free(), "no keystone slots free at the cap")
	_check(not grid.unlock_node(133), "4th keystone is refused")
	_check(not grid.get_node_by_id(133).unlocked, "refused keystone stays locked")

	# Non-keystone nodes are unaffected by the cap (123 HP+35 seeds 124 Thorns+5).
	grid.get_node_by_id(123).unlocked = true
	_check(grid.unlock_node(124), "combat-bonus node still unlocks at the cap")

	# Direct flag-setting (the save-restore path) bypasses the cap by design.
	grid.get_node_by_id(129).unlocked = true
	_check(grid.unlocked_keystone_count() == 4, "restore path bypasses the cap — 4 counted")

func _test_willspring_placement() -> void:
	print("-- Willspring grid placement --")
	var grid = SphereGrid.new()
	var node = grid.get_node_by_id(133)
	_check(node != null and node.node_type == SphereGrid.NodeType.KEYSTONE and node.keystone_id == "det_mana",
		"node 133 is the Willspring keystone")
	_check(node.requirements.is_empty(), "Willspring is ungated for now")
	_check(node.connections.size() > 0, "Willspring is wired into the grid")

func _test_willspring_modifier() -> void:
	print("-- Willspring modifier (DET follows mana) --")
	var data = CharacterData.create_ryan()
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	stats.determination = 20  # det_diff = +10

	# Full health AND full mana: no effect either way.
	_check(_approx(stats.get_determination_modifier(), 1.0), "full resources: modifier 1.0")

	# Low HEALTH, full mana: normally a buff — under Willspring, nothing.
	stats.current_health = maxi(1, int(stats.max_health * 0.1))
	var health_driven = stats.get_determination_modifier()
	_check(_approx(health_driven, 2.0), "without keystone, low health drives the buff (got %.2f)" % health_driven)

	stats.keystone_det_mana = true
	_check(_approx(stats.get_determination_modifier(), 1.0),
		"with Willspring, low health is ignored while mana is full")

	# Low MANA now drives the swing: 10% mana -> 0.10/point -> 2.0.
	stats.current_mana = maxf(0.0, stats.max_mana * 0.1)
	_check(_approx(stats.get_determination_modifier(), 2.0),
		"with Willspring, 10%% mana drives the buff (got %.2f)" % stats.get_determination_modifier())

	# Effective stats read it live.
	var expected_str = maxi(1, floori(stats.base_strength * 2.0))
	_check(stats.strength == expected_str,
		"effective STR doubles at 10%% mana (got %d, expected %d)" % [stats.strength, expected_str])

	# Low DET flips it into a penalty as mana drains.
	stats.determination = 3  # det_diff = -7 -> 1.0 - 0.7 = 0.30
	_check(_approx(stats.get_determination_modifier(), 0.30),
		"low DET at 10%% mana is a penalty (got %.2f)" % stats.get_determination_modifier())

	# Refilling mana clears the effect even at low health.
	stats.current_mana = float(stats.max_mana)
	_check(_approx(stats.get_determination_modifier(), 1.0),
		"full mana clears the swing despite low health")
