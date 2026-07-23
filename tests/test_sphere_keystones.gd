extends SceneTree

## Verifies the sphere grid framework additions: stat-gated requirements,
## KEYSTONE nodes (Bulwark Soul / Flash Reserves / Deadeye Form), and
## NULL_NODE connectors.
## Run: godot --headless --path . --script tests/test_sphere_keystones.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Sphere keystone framework test ===")

	var grid = SphereGrid.new()

	# --- Grid data: keystones, gates, and null nodes landed where expected ---
	var bulwark = grid.get_node_by_id(85)
	_check(bulwark.node_type == SphereGrid.NodeType.KEYSTONE and bulwark.keystone_id == "det_vitality",
		"node 85 is the Bulwark Soul keystone")
	var crit_gate = grid.get_node_by_id(82)
	_check(crit_gate.requirements.get("stat", "") == "dexterity" and crit_gate.requirements.get("value", 0) == 20,
		"Crit +20 node is gated behind DEX 20")
	_check(grid.get_node_by_id(58).node_type == SphereGrid.NodeType.NULL_NODE
		and grid.get_node_by_id(60).node_type == SphereGrid.NodeType.NULL_NODE,
		"ring 4 null connectors exist (ids 58, 60)")

	# --- Requirements check against base stats ---
	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())  # base 3 everywhere
	_check(not SphereGrid.requirements_met(crit_gate, stats), "DEX 3 fails the DEX 20 gate")
	stats.base_dexterity = 25
	_check(SphereGrid.requirements_met(crit_gate, stats), "DEX 25 passes the DEX 20 gate")
	_check(SphereGrid.requirement_text(crit_gate) == "Requires DEX 20", "requirement text renders")
	_check(SphereGrid.requirements_met(grid.get_node_by_id(58), stats), "ungated nodes always pass")

	# --- Bulwark Soul: retroactive and ongoing HP per DET ---
	var base_hp = stats.max_health
	stats.keystone_det_vitality = true
	stats.refresh_det_vitality()
	_check(stats.max_health == base_hp + 2 * stats.determination,
		"unlock grants +2 HP per existing DET point (retroactive)")
	stats.add_base_stat("determination", 2)  # triggers recalculate -> refresh
	_check(stats.max_health == base_hp + 2 * stats.determination,
		"future DET points keep granting +2 HP each")

	# --- Keystone flags survive save/restore ---
	stats.keystone_flash_draw = true
	var saved = stats.save_progression()
	var fresh = load("res://scripts/character/player_stats.gd").new()
	fresh.initialize(CharacterData.create_ryan())
	fresh.restore_progression(saved)
	_check(fresh.keystone_det_vitality and fresh.keystone_flash_draw,
		"keystones survive save/restore")
	_check(fresh.max_health == stats.max_health, "Bulwark HP survives save/restore")

	stats.free()
	fresh.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
