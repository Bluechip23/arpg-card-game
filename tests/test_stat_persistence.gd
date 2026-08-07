extends SceneTree

const Fixtures = preload("res://tests/item_fixtures.gd")

## Regression test: every derived stat bonus must survive a save_progression ->
## restore_progression round trip (world transitions and disk saves both go
## through these). The bug this guards: sphere-grid combat bonuses and
## equipment-derived bonuses (hand size, ranged damage, healing, chance boost)
## were baked into their own scalar fields but NOT snapshotted, so they silently
## reset to 0 on every transition — "equipped an item and it reset my stats".
## Run: godot --headless --path . --script tests/test_stat_persistence.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _mk(char_data):
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(char_data)
	var inv = Inventory.new()
	get_root().add_child(inv)
	inv.initialize(char_data.get_base_character())
	inv.connect_player_stats(stats)
	return [stats, inv]

func _initialize() -> void:
	print("=== Stat persistence round-trip test ===")
	_test_sphere_bonuses()
	_test_equipment_bonuses()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_sphere_bonuses() -> void:
	print("-- Sphere-grid combat bonuses survive save/restore --")
	var data = CharacterData.create_ryan()
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)

	stats.apply_sphere_grid_combat_bonus("Regen +2", "")
	stats.apply_sphere_grid_combat_bonus("Resist +3%", "")
	stats.apply_sphere_grid_combat_bonus("Life Steal +4%", "")
	stats.apply_sphere_grid_combat_bonus("Range +1", "")
	stats.apply_sphere_grid_combat_bonus("Arm/Cyc +1", "")
	stats.apply_sphere_grid_stat("determination", 3)
	stats.damage_proc_reduction_chance = 0.15  # Iron Bastion constellation

	var snap = stats.save_progression()
	var restored = PlayerStats.new()
	get_root().add_child(restored)
	restored.initialize(data)
	restored.restore_progression(snap)

	_check(restored.sphere_bonus_regen == 2, "Regen bonus preserved")
	_check(restored.sphere_bonus_resistance == 3.0, "Resist bonus preserved")
	_check(restored.sphere_bonus_life_steal == 4.0, "Life steal bonus preserved")
	_check(restored.sphere_bonus_range == 1, "Range bonus preserved")
	_check(restored.sphere_bonus_armor_per_cycle == 1, "Armor-per-cycle bonus preserved")
	_check(restored.sphere_bonus_determination == 3, "Sphere determination tracker preserved")
	_check(restored.damage_proc_reduction_chance == 0.15, "Iron Bastion proc chance preserved")

func _test_equipment_bonuses() -> void:
	print("-- Equipment non-base bonuses survive a world transition --")
	var data = CharacterData.create_ryan()
	var a = _mk(data)
	var stats_a: PlayerStats = a[0]
	var inv_a: Inventory = a[1]
	inv_a.equip_item(Fixtures.hand_size_gauntlets(), 0)   # hand_size_bonus 2
	inv_a.equip_item(Fixtures.quiver(), 1)               # ranged_damage_bonus 1
	inv_a.equip_item(Fixtures.healing_belt(), 0)         # healing_bonus 2
	inv_a.equip_item(Fixtures.chance_ring(), 0)          # CHANCE_BOOST 3

	var snap = stats_a.save_progression()
	# A world transition re-installs equipment by direct array assignment WITHOUT
	# re-running _apply_item_bonuses, so the snapshot alone must carry the bonuses.
	var b = _mk(data)
	var stats_b: PlayerStats = b[0]
	var inv_b: Inventory = b[1]
	stats_b.restore_progression(snap)
	inv_b.equipped_gauntlets = inv_a.equipped_gauntlets.duplicate()
	inv_b.equipped_weapons = inv_a.equipped_weapons.duplicate()
	inv_b.equipped_belts = inv_a.equipped_belts.duplicate()
	inv_b.equipped_rings = inv_a.equipped_rings.duplicate()
	inv_b.equipment_changed.emit()

	_check(stats_b.equipment_hand_bonus == stats_a.equipment_hand_bonus,
		"equipment hand-size bonus preserved (%d)" % stats_b.equipment_hand_bonus)
	_check(stats_b.hand_size == stats_a.hand_size,
		"derived hand size preserved (%d)" % stats_b.hand_size)
	_check(stats_b.ranged_damage_bonus == stats_a.ranged_damage_bonus,
		"ranged damage bonus preserved (%d)" % stats_b.ranged_damage_bonus)
	_check(stats_b.healing_bonus == stats_a.healing_bonus,
		"healing bonus preserved (%d)" % stats_b.healing_bonus)
	_check(stats_b.chance_boost == stats_a.chance_boost,
		"chance boost preserved (%.0f)" % stats_b.chance_boost)
