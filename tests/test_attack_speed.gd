extends SceneTree

## Verifies the attack-speed threshold — DEX-primary (0.5 tick per point, base
## 45, minimum 1) — and the encumbrance penalty per the README: capacity never
## speeds attacks up; the penalty scales 0..+7 with the load ratio and is a
## flat +10 while overburdened. Also the Wisdom draw timer (0.25 tempo/point).
## Run: godot --headless --path . --script tests/test_attack_speed.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Attack speed & draw timer test ===")

	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())  # all stats 3, full HP

	# --- Encumbrance: 0 unencumbered, ratio-scaled up to +7, +10 overburdened ---
	_check(stats.get_carry_capacity() == 80, "fresh Ryan carries 80 (50 + STR 3 x10)")
	_check(stats.get_capacity_speed_modifier() == 0,
		"no load = no penalty (capacity never speeds attacks up) (%d)" % stats.get_capacity_speed_modifier())
	_check(stats.get_attack_speed_threshold() == 44,
		"naked threshold = 45 - 1 (DEX 3 x 0.5) (%d)" % stats.get_attack_speed_threshold())

	stats.set_carry_load(30)  # 30/80 of capacity
	_check(stats.get_capacity_speed_modifier() == 3,
		"3/8 load adds 3 attacks (ratio x 7 rounded) (%d)" % stats.get_capacity_speed_modifier())

	stats.set_carry_load(70)  # 70/80
	_check(stats.get_capacity_speed_modifier() == 6,
		"7/8 load adds 6 attacks (%d)" % stats.get_capacity_speed_modifier())

	stats.set_carry_load(80)  # exactly full
	_check(stats.get_capacity_speed_modifier() == stats.CAPACITY_SPEED_MAX_PENALTY,
		"a full load maxes the penalty at +%d" % stats.CAPACITY_SPEED_MAX_PENALTY)

	stats.set_carry_load(81)  # over capacity
	_check(stats.get_capacity_speed_modifier() == stats.OVERBURDENED_SPEED_PENALTY,
		"overburdened = flat +%d" % stats.OVERBURDENED_SPEED_PENALTY)

	# --- Raw STR raises capacity but never grants a speed BONUS ---
	stats.set_carry_load(0)
	stats.base_strength = 30  # capacity 350
	_check(stats.get_capacity_speed_modifier() == 0,
		"huge spare capacity is still just 0 — never negative (%d)" % stats.get_capacity_speed_modifier())

	# --- DEX: 0.5 tick per point (2 points = exactly 1 fewer attack) ---
	stats.base_strength = 3
	stats.base_dexterity = 10
	var t10 = stats.get_attack_speed_threshold()
	stats.base_dexterity = 11
	_check(t10 == stats.get_attack_speed_threshold(), "a lone odd DEX point changes nothing (0.5 floors)")
	stats.base_dexterity = 12
	_check(t10 - stats.get_attack_speed_threshold() == 1, "every 2 DEX points = 1 fewer attack to proc")

	stats.base_dexterity = 100
	_check(stats.get_attack_speed_threshold() == 1,
		"threshold bottoms out at 1 — proc-per-attack is reachable (%d)" % stats.get_attack_speed_threshold())

	# --- Draw timer: flat 25 tempo; WIS no longer accelerates it (README) ---
	stats.base_dexterity = 3
	_check(stats.get_effective_draw_timer() == 25.0, "base draw timer is 25 tempo (5 cycles)")
	stats.base_wisdom = 40
	_check(stats.get_effective_draw_timer() == 25.0, "WIS does not speed the auto draw — it stays 25 tempo")

	stats.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
