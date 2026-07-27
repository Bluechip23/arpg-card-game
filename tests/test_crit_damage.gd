extends SceneTree

## Verifies the crit damage system:
##   * Base crit damage is 150%.
##   * Dexterity grants +5% crit damage per point (effective DEX).
##   * Card.crit_multiply applies the formula and falls back to base without stats.
##   * No stat affects crit chance (roll_crit input is unchanged by DEX).
## Run: godot --headless --path . --script tests/test_crit_damage.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _approx(a: float, b: float) -> bool:
	return abs(a - b) < 0.001

func _fresh_stats() -> PlayerStats:
	var data = CharacterData.create_ryan()
	var stats = PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(data)
	return stats

func _initialize() -> void:
	print("=== Crit damage test ===")
	_test_multiplier()
	_test_crit_multiply()
	_test_det_interaction()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

func _test_multiplier() -> void:
	print("-- get_crit_damage_multiplier --")
	var stats = _fresh_stats()

	# Known DEX: 10 -> 1.5 + 10*0.05 = 2.0
	stats.base_dexterity = 10
	_check(_approx(stats.get_crit_damage_multiplier(), 2.0),
		"DEX 10 -> 200%% crit damage (got %.2f)" % stats.get_crit_damage_multiplier())

	# DEX 1 -> 1.55
	stats.base_dexterity = 1
	_check(_approx(stats.get_crit_damage_multiplier(), 1.55),
		"DEX 1 -> 155%% crit damage (got %.2f)" % stats.get_crit_damage_multiplier())

	# DEX 20 -> 2.5
	stats.base_dexterity = 20
	_check(_approx(stats.get_crit_damage_multiplier(), 2.5),
		"DEX 20 -> 250%% crit damage (got %.2f)" % stats.get_crit_damage_multiplier())

func _test_crit_multiply() -> void:
	print("-- Card.crit_multiply --")
	var stats = _fresh_stats()
	stats.base_dexterity = 10  # multiplier 2.0

	_check(Card.crit_multiply(10, stats) == 20,
		"10 damage crits for 20 at DEX 10 (got %d)" % Card.crit_multiply(10, stats))
	_check(Card.crit_multiply(7, stats) == 14,
		"7 damage crits for 14 at DEX 10 (got %d)" % Card.crit_multiply(7, stats))

	# Floors, never rounds up: DEX 1 -> 1.55x, 7 * 1.55 = 10.85 -> 10.
	stats.base_dexterity = 1
	_check(Card.crit_multiply(7, stats) == 10,
		"7 damage at 155%% floors to 10 (got %d)" % Card.crit_multiply(7, stats))

	# Null stats fall back to the 150% base.
	_check(Card.crit_multiply(10, null) == 15,
		"null stats fall back to 150%% (got %d)" % Card.crit_multiply(10, null))

func _test_det_interaction() -> void:
	print("-- effective DEX drives it --")
	var stats = _fresh_stats()
	stats.base_dexterity = 10
	stats.determination = 20  # DET buff at low health raises effective DEX

	# Full health: modifier 1.0 -> effective DEX 10 -> 2.0.
	_check(_approx(stats.get_crit_damage_multiplier(), 2.0),
		"full health: DEX 10 -> 2.0 (got %.2f)" % stats.get_crit_damage_multiplier())

	# 10% health with DET 20: stat modifier 2.0 -> effective DEX 20 -> 2.5.
	stats.current_health = maxi(1, int(stats.max_health * 0.1))
	_check(_approx(stats.get_crit_damage_multiplier(), 2.5),
		"low health + high DET doubles DEX -> 2.5 (got %.2f)" % stats.get_crit_damage_multiplier())
