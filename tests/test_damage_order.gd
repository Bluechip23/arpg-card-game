extends SceneTree

## Verifies the default damage absorption order: Armor -> temp HP -> HP.
## Armor is always the first line of defense; temp HP only soaks what gets
## past it, and health takes the rest.
## Run: godot --headless --path . --script tests/test_damage_order.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _fresh_stats() -> PlayerStats:
	var data = CharacterData.create_ryan()
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	return stats

func _initialize() -> void:
	print("=== Damage absorption order test ===")
	_test_armor_before_temp_hp()
	_test_full_chain()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_armor_before_temp_hp() -> void:
	print("-- armor soaks before temp HP --")
	var stats = _fresh_stats()
	stats.current_armor = 5
	stats.add_temp_health(5, 30)
	var hp_before = stats.current_health

	# 3 damage: armor takes all of it, temp HP untouched.
	stats.take_damage(3)
	_check(stats.current_armor == 2 and stats.current_temp_health == 5,
		"3 damage: armor 5->%d, temp HP untouched at %d" % [stats.current_armor, stats.current_temp_health])
	_check(stats.current_health == hp_before, "health untouched")

	# 4 damage: armor breaks (2), temp HP takes the remaining 2.
	stats.take_damage(4)
	_check(stats.current_armor == 0 and stats.current_temp_health == 3,
		"4 damage: armor broke, temp HP 5->%d" % stats.current_temp_health)
	_check(stats.current_health == hp_before, "health still untouched")

func _test_full_chain() -> void:
	print("-- full chain: armor -> temp HP -> HP --")
	var stats = _fresh_stats()
	stats.current_armor = 3
	stats.add_temp_health(2, 30)
	var hp_before = stats.current_health

	# 9 damage: 3 armor + 2 temp HP + 4 health.
	stats.take_damage(9)
	_check(stats.current_armor == 0, "armor consumed")
	_check(stats.current_temp_health == 0, "temp HP consumed")
	_check(stats.current_health == hp_before - 4,
		"health takes the final 4 (HP %d -> %d)" % [hp_before, stats.current_health])
