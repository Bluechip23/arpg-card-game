extends SceneTree

## Verifies the attack-speed threshold — DEX-primary (0.6 tick per point, base
## 46, minimum 1), with a capped square-root encumbrance modifier and the -4
## dual-wield bonus — and the Wisdom draw timer (0.25 tempo per point).
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

	# --- Encumbrance modifier: sqrt-scaled around a baseline of 60 free capacity ---
	_check(stats.get_carry_capacity() == 80, "fresh Ryan carries 80 (50 + STR 3 x10)")
	_check(stats.get_capacity_speed_modifier() == -1,
		"unencumbered (80 free) shaves 1 attack (%d)" % stats.get_capacity_speed_modifier())
	_check(stats.get_attack_speed_threshold() == 44,
		"naked threshold = 46 - 1 (DEX 3 x 0.6) - 1 (%d)" % stats.get_attack_speed_threshold())

	stats.set_carry_load(20)  # 60 free = the neutral point
	_check(stats.get_capacity_speed_modifier() == 0, "60 free capacity is neutral")
	_check(stats.get_attack_speed_threshold() == 45, "baseline-load threshold = 46 - 1 (DEX 3 x 0.6)")

	stats.set_carry_load(70)  # 10 free = heavy
	_check(stats.get_capacity_speed_modifier() == 5, "10 free capacity adds 5 attacks")

	stats.set_carry_load(81)  # over capacity
	_check(stats.get_capacity_speed_modifier() == stats.OVERBURDENED_SPEED_PENALTY,
		"overburdened = flat +%d" % stats.OVERBURDENED_SPEED_PENALTY)

	# --- Cap: raw STR can help but never out-race DEX ---
	stats.set_carry_load(0)
	stats.base_strength = 30  # capacity 350
	_check(stats.get_capacity_speed_modifier() == -stats.CAPACITY_SPEED_BONUS_CAP,
		"huge spare capacity clamps at -%d" % stats.CAPACITY_SPEED_BONUS_CAP)

	# --- DEX: 0.6 tick per point (5 points = exactly 3 fewer attacks) ---
	stats.base_strength = 3
	stats.base_dexterity = 10
	var t10 = stats.get_attack_speed_threshold()
	stats.base_dexterity = 11
	_check(t10 == stats.get_attack_speed_threshold(), "a lone odd DEX point changes nothing (0.6 floors)")
	stats.base_dexterity = 15
	_check(t10 - stats.get_attack_speed_threshold() == 3, "every 5 DEX points = 3 fewer attacks to proc")

	stats.base_dexterity = 100
	_check(stats.get_attack_speed_threshold() == 1,
		"threshold bottoms out at 1 — proc-per-attack is reachable (%d)" % stats.get_attack_speed_threshold())

	# --- Wisdom draw timer: 0.25 tempo shaved per point ---
	stats.base_dexterity = 3
	_check(stats.get_effective_draw_timer() == 25.0, "WIS 3 draws every 25 tempo (0.75 floors to 0)")
	stats.base_wisdom = 10
	_check(stats.get_effective_draw_timer() == 23.0, "WIS 10 draws every 23 tempo")
	stats.base_wisdom = 40
	_check(stats.get_effective_draw_timer() == 15.0, "WIS 40 draws every 15 tempo")
	stats.base_wisdom = 100
	_check(stats.get_effective_draw_timer() == 1.0, "draw interval bottoms out at 1 tempo")

	stats.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
