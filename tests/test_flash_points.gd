extends SceneTree

## Verifies Agility flash points: pool = 1 per AGI point (+5 per movement
## enchantment), movement spends 1 point before costing tempo, and the pool
## refreshes every 3 tempo cycles.
## Run: godot --headless --path . --script tests/test_flash_points.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Flash points test ===")

	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())  # AGI 3
	_check(stats.get_max_flash_points() == 3, "pool = 1 flash point per AGI point")
	_check(stats.current_flash_points == 3, "pool starts full")

	var tm = load("res://scripts/battle/tempo_manager.gd").new()
	tm.initialize(stats)

	# --- Spending flash is opt-in: with the toggle off, moves cost tempo ---
	tm.add_movement_tempo()
	_check(stats.current_flash_points == 3, "toggle off: the pool is untouched")
	_check(tm.get_global_tempo() == 1, "toggle off: a move costs 1 tempo")

	# --- Toggled on, movement spends flash first, then tempo ---
	stats.flash_movement_enabled = true
	for i in range(3):
		tm.add_movement_tempo()
	_check(stats.current_flash_points == 0, "3 moves spend the 3-point pool")
	_check(tm.get_global_tempo() == 1, "flash moves cost no tempo")

	tm.add_movement_tempo()
	_check(tm.get_global_tempo() == 2, "empty pool: a move costs 1 tempo")

	# --- Refresh every 3 cycles ---
	tm.add_tempo(4)  # completes cycle 1 (5 tempo total)
	_check(stats.current_flash_points == 0, "1 cycle is not enough to refresh")
	tm.add_tempo(5)  # completes cycle 2
	_check(stats.current_flash_points == 0, "2 cycles are not enough to refresh")
	tm.add_tempo(5)  # completes cycle 3
	_check(stats.current_flash_points == 3, "pool refreshes after 3 cycles")

	# --- Modifiers ---
	stats.enchantment_movement_bonus = 1
	_check(stats.get_max_flash_points() == 8, "movement enchantment adds 5 flash points")

	# --- Flash block: 3 flash → 2 armor ---
	stats.refresh_flash_points()
	_check(stats.spend_flash_for_block(), "flash block spends 3 points")
	_check(stats.current_armor == 2, "3 flash bought 2 armor")
	_check(stats.current_flash_points == 5, "block left 5 of 8 flash")

	# --- Flash proc tick: 5 flash advances the attack counter ---
	var before = stats.get_attacks_until_proc()
	_check(stats.spend_flash_for_proc_tick(), "proc tick spends 5 points")
	_check(stats.get_attacks_until_proc() == before - 1, "attack counter advanced 1 tick")
	_check(stats.current_flash_points == 0, "proc tick emptied the pool")
	_check(not stats.spend_flash_for_proc_tick(), "proc tick refused on an empty pool")

	_check(not stats.spend_flash_points(99), "cannot overspend the pool")

	stats.free()
	tm.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
