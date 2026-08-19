extends SceneTree

## Verifies the sphere grid debuff-amp nodes (Vuln Amp / Weaken Amp): label
## parsing into player stats, stacking, and save/restore round-trip.
## Run: godot --headless --path . --script tests/test_debuff_amps.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Debuff amp (Vuln/Weaken) test ===")

	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())

	# --- Label parsing ---
	stats.apply_sphere_grid_combat_bonus("Vuln Amp +25%", "")
	_check(absf(stats.sphere_vulnerable_amp - 25.0) < 0.001, "Vuln Amp +25%% parses to 25")
	stats.apply_sphere_grid_combat_bonus("Weaken Amp +25%", "")
	_check(absf(stats.sphere_weaken_amp - 25.0) < 0.001, "Weaken Amp +25%% parses to 25")

	# --- Stacking (a second Vuln Amp node exists on Ring 6) ---
	stats.apply_sphere_grid_combat_bonus("Vuln Amp +25%", "")
	_check(absf(stats.sphere_vulnerable_amp - 50.0) < 0.001, "second Vuln Amp node stacks to 50")

	# --- Save / restore round-trip ---
	var saved = stats.save_progression()
	var fresh = load("res://scripts/character/player_stats.gd").new()
	fresh.initialize(CharacterData.create_ryan())
	fresh.restore_progression(saved)
	_check(absf(fresh.sphere_vulnerable_amp - 50.0) < 0.001, "vulnerable amp survives save/restore")
	_check(absf(fresh.sphere_weaken_amp - 25.0) < 0.001, "weaken amp survives save/restore")

	# --- The grid actually carries the nodes ---
	var grid = SphereGrid.new()
	var amp_labels: Array = []
	for node in grid.get_all_nodes():
		if "Amp +" in node.label:
			amp_labels.append(node.label)
	_check(amp_labels.count("Vuln Amp +25%") == 2, "grid holds two Vuln Amp nodes")
	_check(amp_labels.count("Weaken Amp +25%") == 1, "grid holds one Weaken Amp node")

	stats.free()
	fresh.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
