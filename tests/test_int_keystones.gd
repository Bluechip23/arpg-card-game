extends SceneTree

## Verifies the two Intelligence keystones:
##   Arcane Ward (int_regen_armor) — each mana-regen tick grants armor = INT/2
##   Arcane Echo (int_spell_proc)  — spells have an INT/3% chance to deal INT/2
##                                   bonus damage to a random enemy
## Covers grid placement, the armor-on-regen tick, the Arcane Echo formulas, and
## the save/restore round trip. (The Echo roll + enemy hit live in
## Main._try_arcane_echo and want a live scene; here we verify the numbers.)
## Run: godot --headless --path . --script tests/test_int_keystones.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Intelligence keystones test ===")
	_test_grid_placement()
	_test_arcane_ward()
	_test_arcane_echo_formulas()
	_test_persistence()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _fresh(int_val: int) -> PlayerStats:
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_ryan())
	stats.base_intelligence = int_val
	return stats

func _test_grid_placement() -> void:
	print("-- Grid placement --")
	var grid = SphereGrid.new()
	var ward = grid.get_node_by_id(107)
	var echo = grid.get_node_by_id(110)
	_check(ward.node_type == SphereGrid.NodeType.KEYSTONE and ward.keystone_id == "int_regen_armor",
		"node 107 is the Arcane Ward keystone")
	_check(echo.node_type == SphereGrid.NodeType.KEYSTONE and echo.keystone_id == "int_spell_proc",
		"node 110 is the Arcane Echo keystone")
	_check(ward.requirements.get("stat", "") == "intelligence" and echo.requirements.get("value", 0) == 15,
		"both gated behind INT 15")

func _test_arcane_ward() -> void:
	print("-- Arcane Ward: armor on mana regen --")
	var stats = _fresh(20)  # INT 20 -> ward = 10
	_check(stats.current_armor == 0, "no armor to start")
	# Without the keystone, a regen tick grants no armor.
	stats.process_tempo(int(stats.mana_regen_tempo_interval))
	_check(stats.current_armor == 0, "no armor from regen while the keystone is off")
	# Enable it and drive one more regen tick.
	stats.keystone_int_regen_armor = true
	stats.process_tempo(int(stats.mana_regen_tempo_interval))
	_check(stats.current_armor == 10, "a regen tick grants INT/2 = 10 armor (got %d)" % stats.current_armor)

func _test_arcane_echo_formulas() -> void:
	print("-- Arcane Echo: chance / damage formulas --")
	var stats = _fresh(30)  # INT 30
	_check(is_equal_approx(stats.get_int_spell_proc_chance(), 10.0),
		"INT 30 -> 10%% echo chance (got %.1f)" % stats.get_int_spell_proc_chance())
	_check(stats.get_int_spell_proc_damage() == 15,
		"INT 30 -> 15 echo damage (got %d)" % stats.get_int_spell_proc_damage())
	var s2 = _fresh(9)
	_check(is_equal_approx(s2.get_int_spell_proc_chance(), 3.0) and s2.get_int_spell_proc_damage() == 4,
		"INT 9 -> 3%% chance, 4 damage")

func _test_persistence() -> void:
	print("-- Save / restore --")
	var stats = _fresh(10)
	stats.keystone_int_regen_armor = true
	stats.keystone_int_spell_proc = true
	var snap = stats.save_progression()
	var restored = PlayerStats.new()
	get_root().add_child(restored)
	restored.initialize(CharacterData.create_ryan())
	restored.restore_progression(snap)
	_check(restored.keystone_int_regen_armor, "Arcane Ward flag survives save/restore")
	_check(restored.keystone_int_spell_proc, "Arcane Echo flag survives save/restore")
