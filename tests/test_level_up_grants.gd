extends SceneTree

## Verifies per-level grants: +2 max HP and +3 banked stat points on every
## level-up, allocation spending (partial allowed, over-spend refused), and
## that banked points survive a save/restore round trip.
## Run: godot --headless --path . --script tests/test_level_up_grants.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Level-up grants test ===")

	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())  # 10 HP, all stats 3
	_check(stats.max_health == 10, "starting max health is 10")
	_check(stats.unspent_stat_points == 0, "no banked stat points at start")

	# --- Level 1 → 2 (needs 10 XP) ---
	stats.gain_xp(10)
	_check(stats.current_level == 2, "10 XP reaches level 2")
	_check(stats.max_health == 12, "level 2: +2 max HP (12)")
	_check(stats.current_health == 12, "level-up heals to the new max")
	_check(stats.unspent_stat_points == 3, "level 2: 3 stat points banked")

	# --- Level 2 → 3 (needs 20 XP) ---
	stats.gain_xp(20)
	_check(stats.current_level == 3, "20 more XP reaches level 3")
	_check(stats.max_health == 14, "level 3: max HP 14")
	_check(stats.unspent_stat_points == 6, "level 3: 6 stat points banked")

	# --- Allocation: partial spend keeps the remainder banked ---
	_check(stats.apply_stat_allocation({"strength": 2, "agility": 2}), "spending 4 of 6 points works")
	_check(stats.base_strength == 5 and stats.base_agility == 5, "points landed on base stats")
	_check(stats.unspent_stat_points == 2, "2 points stay banked after a partial spend")

	# --- Guards ---
	_check(not stats.apply_stat_allocation({"wisdom": 3}), "over-spend is refused")
	_check(not stats.apply_stat_allocation({}), "empty allocation is refused")
	_check(stats.unspent_stat_points == 2, "refused spends leave the bank untouched")

	# --- Banked points survive save/restore ---
	var saved = stats.save_progression()
	var fresh = load("res://scripts/character/player_stats.gd").new()
	fresh.initialize(CharacterData.create_ryan())
	fresh.restore_progression(saved)
	_check(fresh.unspent_stat_points == 2, "banked points survive save/restore")
	_check(fresh.max_health == 14, "grown max health survives save/restore")
	_check(fresh.base_strength == 5, "allocated stats survive save/restore")

	stats.free()
	fresh.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
