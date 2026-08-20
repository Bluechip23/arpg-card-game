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

	# --- Buff amps: label parsing ---
	stats.apply_sphere_grid_combat_bonus("Haste Amp +1", "")
	stats.apply_sphere_grid_combat_bonus("Enlight Amp +10%", "")
	stats.apply_sphere_grid_combat_bonus("Brace Amp +10%", "")
	stats.apply_sphere_grid_combat_bonus("Blessed Draw +1", "")
	stats.apply_sphere_grid_combat_bonus("Blessed Amp +1", "")
	_check(stats.sphere_haste_amp == 1, "Haste Amp parses")
	_check(absf(stats.sphere_enlightened_amp - 10.0) < 0.001, "Enlight Amp parses")
	_check(stats.sphere_brace_amp == 10, "Brace Amp parses")
	_check(stats.sphere_blessed_draw_amp == 1, "Blessed Draw parses")
	_check(stats.sphere_blessed_amp == 1, "Blessed Amp parses")

	# --- Buff amps: applications arrive stronger ---
	var bm = BuffManager.new()
	bm.initialize(stats)
	bm.apply_buff(Buff.create_haste(1, 3, "Test"))
	_check(bm.get_buff(Buff.BuffType.HASTE).charges == 4, "Haste arrives with +1 charge (4)")
	bm.apply_buff(Buff.create_blessed(1, 3, "Test"))
	var blessed = bm.get_buff(Buff.BuffType.BLESSED)
	_check(blessed.value == 2 and blessed.charges == 4, "Blessed arrives with +1 draw and +1 cycle")
	bm.apply_buff(Buff.create_brace(10, 1, "Test"))
	_check(bm.get_buff(Buff.BuffType.BRACE).value == 20, "Brace 10% arrives as 20%")
	bm.apply_buff(Buff.create_enlightened(25, 3, "Test"))
	_check(bm.get_enlightened_crit_chance() == 20, "Enlightened grants 20% with the amp")
	bm.free()

	# --- The grid actually carries the nodes ---
	var grid = SphereGrid.new()
	var amp_labels: Array = []
	for node in grid.get_all_nodes():
		if "Amp +" in node.label or "Draw +" in node.label:
			amp_labels.append(node.label)
	_check(amp_labels.count("Vuln Amp +25%") == 2, "grid holds two Vuln Amp nodes")
	_check(amp_labels.count("Weaken Amp +25%") == 1, "grid holds one Weaken Amp node")
	for lbl in ["Haste Amp +1", "Enlight Amp +10%", "Brace Amp +10%", "Blessed Draw +1", "Blessed Amp +1"]:
		_check(amp_labels.count(lbl) == 1, "grid holds the '%s' node" % lbl)
	# The arc hangs off Ring 6 so it's pathable.
	for nid in range(134, 139):
		_check(not grid.get_connections_for(nid).is_empty(), "amp node %d is connected" % nid)

	# --- Buff amps survive save/restore ---
	var saved2 = stats.save_progression()
	var fresh2 = load("res://scripts/character/player_stats.gd").new()
	fresh2.initialize(CharacterData.create_ryan())
	fresh2.restore_progression(saved2)
	_check(fresh2.sphere_haste_amp == 1 and fresh2.sphere_brace_amp == 10 \
		and fresh2.sphere_blessed_draw_amp == 1 and fresh2.sphere_blessed_amp == 1 \
		and absf(fresh2.sphere_enlightened_amp - 10.0) < 0.001,
		"buff amps survive save/restore")
	fresh2.free()

	stats.free()
	fresh.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
