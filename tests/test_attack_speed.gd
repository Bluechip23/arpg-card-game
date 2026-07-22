extends SceneTree

## Verifies the attack-speed threshold — DEX-primary, with a capped square-root
## encumbrance modifier — and the Wisdom draw timer (-1 global tempo per point).
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

	# --- Encumbrance modifier: sqrt-scaled around a baseline of 50 free capacity ---
	_check(stats.get_carry_capacity() == 80, "fresh Ryan carries 80 (50 + STR 3 x10)")
	_check(stats.get_capacity_speed_modifier() == -2,
		"unencumbered (80 free) shaves 2 attacks (%d)" % stats.get_capacity_speed_modifier())
	_check(stats.get_attack_speed_threshold() == 25,
		"naked threshold = 30 - 3 DEX - 2 (%d)" % stats.get_attack_speed_threshold())

	stats.set_carry_load(30)  # 50 free = the neutral point
	_check(stats.get_capacity_speed_modifier() == 0, "50 free capacity is neutral")
	_check(stats.get_attack_speed_threshold() == 27, "baseline-load threshold = 30 - 3 DEX")

	stats.set_carry_load(70)  # 10 free = heavy
	_check(stats.get_capacity_speed_modifier() == 4, "10 free capacity adds 4 attacks")

	stats.set_carry_load(81)  # over capacity
	_check(stats.get_capacity_speed_modifier() == stats.OVERBURDENED_SPEED_PENALTY,
		"overburdened = flat +%d" % stats.OVERBURDENED_SPEED_PENALTY)

	# --- Cap: raw STR can help but never out-race DEX ---
	stats.set_carry_load(0)
	stats.base_strength = 30  # capacity 350
	_check(stats.get_capacity_speed_modifier() == -stats.CAPACITY_SPEED_BONUS_CAP,
		"huge spare capacity clamps at -%d" % stats.CAPACITY_SPEED_BONUS_CAP)

	# --- DEX is linear: each point = exactly one fewer attack ---
	stats.base_strength = 3
	stats.base_dexterity = 10
	var t10 = stats.get_attack_speed_threshold()
	stats.base_dexterity = 11
	_check(t10 - stats.get_attack_speed_threshold() == 1, "each DEX point = 1 fewer attack to proc")

	stats.base_dexterity = 40
	_check(stats.get_attack_speed_threshold() == 5, "threshold floors at 5")

	# --- Wisdom draw timer: -1 global tempo per point, floor one cycle ---
	_check(stats.get_effective_draw_timer() == 22.0, "WIS 3 draws every 22 tempo (25 - 3)")
	stats.base_wisdom = 10
	_check(stats.get_effective_draw_timer() == 15.0, "WIS 10 draws every 15 tempo")
	stats.base_wisdom = 30
	_check(stats.get_effective_draw_timer() == 5.0, "draw interval floors at one cycle (5 tempo)")

	stats.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
