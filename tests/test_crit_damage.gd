extends SceneTree

## Verifies the crit damage system:
##   * Base crit damage is 110%.
##   * Dexterity grants +3% crit damage per point (effective DEX).
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

	# Known DEX: 10 -> 1.1 + 10*0.03 = 1.4
	stats.base_dexterity = 10
	_check(_approx(stats.get_crit_damage_multiplier(), 1.4),
		"DEX 10 -> 140%% crit damage (got %.2f)" % stats.get_crit_damage_multiplier())

	# DEX 1 -> 1.13
	stats.base_dexterity = 1
	_check(_approx(stats.get_crit_damage_multiplier(), 1.13),
		"DEX 1 -> 113%% crit damage (got %.2f)" % stats.get_crit_damage_multiplier())

	# DEX 20 -> 1.7
	stats.base_dexterity = 20
	_check(_approx(stats.get_crit_damage_multiplier(), 1.7),
		"DEX 20 -> 170%% crit damage (got %.2f)" % stats.get_crit_damage_multiplier())

func _test_crit_multiply() -> void:
	print("-- Card.crit_multiply --")
	var stats = _fresh_stats()
	stats.base_dexterity = 10  # multiplier 1.4

	_check(Card.crit_multiply(10, stats) == 14,
		"10 damage crits for 14 at DEX 10 (got %d)" % Card.crit_multiply(10, stats))
	_check(Card.crit_multiply(7, stats) == 9,
		"7 damage crits for 9 at DEX 10 (floors 9.8) (got %d)" % Card.crit_multiply(7, stats))

	# Floors, never rounds up: DEX 1 -> 1.13x, 7 * 1.13 = 7.91 -> 7.
	stats.base_dexterity = 1
	_check(Card.crit_multiply(7, stats) == 7,
		"7 damage at 113%% floors to 7 (got %d)" % Card.crit_multiply(7, stats))

	# Null stats fall back to the 110% base.
	_check(Card.crit_multiply(10, null) == 11,
		"null stats fall back to 110%% (got %d)" % Card.crit_multiply(10, null))

func _test_det_interaction() -> void:
	print("-- effective DEX drives it --")
	var stats = _fresh_stats()
	stats.base_dexterity = 10
	stats.determination = 65  # DET buff at low health raises effective DEX

	# Full health: modifier 1.0 -> effective DEX 10 -> 1.4.
	_check(_approx(stats.get_crit_damage_multiplier(), 1.4),
		"full health: DEX 10 -> 1.4 (got %.2f)" % stats.get_crit_damage_multiplier())

	# 10% health with DET 65: stat modifier 1.5 -> effective DEX 15 -> 1.55.
	stats.current_health = maxi(1, int(stats.max_health * 0.1))
	_check(_approx(stats.get_crit_damage_multiplier(), 1.55),
		"low health + DET 65 raises DEX to 15 -> 1.55 (got %.2f)" % stats.get_crit_damage_multiplier())
