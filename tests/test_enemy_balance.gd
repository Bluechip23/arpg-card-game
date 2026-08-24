extends SceneTree

## Verifies the Act 1 enemy balance pass: compendium covers every enemy type
## (including Ring Wraith, previously missing — a crash bug), compendium
## numbers match initialize(), and the new hard-tier stats are in place.
## Run: godot --headless --path . --script tests/test_enemy_balance.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Enemy balance pass test ===")

	# --- Compendium covers every enum value (Ring Wraith crash fix) ---
	var data: Array = Enemy.get_all_enemy_data()
	_check(data.size() == Enemy.EnemyType.size(),
		"compendium has one entry per enemy type (%d)" % data.size())
	var by_name := {}
	for e in data:
		by_name[e["name"]] = e
	_check(by_name.has("Ring Wraith"), "Ring Wraith present in compendium")
	if by_name.has("Ring Wraith"):
		_check(by_name["Ring Wraith"]["health"] == 100, "Ring Wraith compendium HP matches code (100, unbanded so unscaled)")

	# --- Passive-rework scaling curve ---
	var s_low: Dictionary = Enemy.passive_power_scale(2)
	var s_mid: Dictionary = Enemy.passive_power_scale(8)
	var s_high: Dictionary = Enemy.passive_power_scale(19)
	_check(is_equal_approx(s_low["hp"], 0.9) and is_equal_approx(s_low["dmg"], 0.9),
		"early bands ease off to x0.9 (weak low-rank passives)")
	_check(is_equal_approx(s_mid["hp"], 1.0) and is_equal_approx(s_mid["dmg"], 1.0),
		"band 8 is the crossover (x1.0)")
	_check(is_equal_approx(s_high["hp"], 1.45) and is_equal_approx(s_high["dmg"], 1.3),
		"late bands grow to x1.45 HP / x1.3 damage (maxed lanes)")
	_check(is_equal_approx(Enemy.passive_power_scale(0)["hp"], 1.0), "unbanded enemies unscaled")

	# --- Spot-check restrengthened stats (compendium side, base x band scale) ---
	_check(by_name["Rat King"]["health"] == 81 and by_name["Rat King"]["armor"] == 9,
		"Rat King is a real mini-boss (90x0.9 HP, 10x0.9 armor at band 5)")
	_check(by_name["Bone Dragon"]["health"] == 180, "Bone Dragon 150x1.2 HP (band 12)")
	_check(by_name["Grave Titan"]["health"] == 156 and by_name["Grave Titan"]["armor"] == 36,
		"Grave Titan 130x1.2 HP / 30x1.2 armor (band 12)")
	_check(by_name["Hydra"]["health"] == 104, "Hydra 80x1.3 HP (band 14)")
	_check(by_name["Treant"]["health"] == 160, "Treant 110x1.45 HP (band 19)")
	_check(by_name["Coyote"]["health"] == 7, "Coyote stays blowy-uppy (6x1.2 HP)")
	_check(by_name["Swarm"]["health"] == 9, "Swarm stays blowy-uppy (10x0.9 HP)")
	_check(by_name["Bugbear"]["type"] == "Elite", "Bugbear display tier fixed to Elite")

	# --- initialize() agrees with the compendium for every implemented enemy ---
	var mismatches := 0
	for t in Enemy.EnemyType.values():
		var entry = data[t]
		if int(entry["health"]) == 0:
			continue  # design mock-ups — stats TBD
		var e = Enemy.new()
		e.initialize(t)
		if e.max_health != int(entry["health"]) or e.max_armor != int(entry["armor"]) \
				or e.xp_reward != int(entry["xp"]):
			mismatches += 1
			printerr("  MISMATCH %s: init hp=%d/ar=%d/xp=%d vs compendium hp=%s/ar=%s/xp=%s" % [
				entry["name"], e.max_health, e.max_armor, e.xp_reward,
				entry["health"], entry["armor"], entry["xp"]])
		e.free()
	_check(mismatches == 0, "initialize() matches compendium for all implemented enemies")

	# --- Every implemented, XP-granting enemy has a level band ---
	var missing_bands := 0
	for t in Enemy.EnemyType.values():
		var entry = data[t]
		if int(entry["health"]) == 0 or int(entry["xp"]) == 0:
			continue  # mock-ups and XP-less enemies (Wererabbit gives XP; Ring Wraith gives 0)
		if int(Enemy.INTENDED_LEVELS.get(t, 0)) <= 0:
			missing_bands += 1
			printerr("  MISSING BAND: %s" % entry["name"])
	_check(missing_bands == 0, "every XP-granting enemy has an intended-level band")

	# --- Level-gap XP falloff ---
	var stats = load("res://scripts/character/player_stats.gd").new()
	stats.initialize(CharacterData.create_ryan())
	stats.current_level = 10
	_check(stats.get_xp_multiplier(0) == 1.0, "unbanded source (0) has no falloff")
	_check(stats.get_xp_multiplier(20) == 1.0, "fighting above your level never penalized")
	_check(stats.get_xp_multiplier(5) == 1.0, "within grace (5 levels over) pays full XP")
	_check(absf(stats.get_xp_multiplier(4) - 0.85) < 0.001, "6 over: 85%")
	_check(absf(stats.get_xp_multiplier(2) - 0.55) < 0.001, "8 over: 55%")
	_check(stats.get_xp_multiplier(1) < 0.5, "9 over: under half")
	stats.current_level = 20
	_check(stats.get_xp_multiplier(2) == 0.0, "level 20 vs sewer rats (band 2): zero XP")
	var xp_before = stats.total_xp
	stats.gain_xp(100, 2)
	_check(stats.total_xp == xp_before, "gain_xp grants nothing at zero multiplier")
	stats.gain_xp(100, 18)
	_check(stats.total_xp == xp_before + 100, "gain_xp grants full XP on-curve")
	_check(PlayerStats.PASSIVE_POINTS_PER_LEVEL == 1, "level-ups bank exactly 1 passive point")
	stats.free()

	print("=== %s ===" % ("ALL PASSED" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(1 if failures > 0 else 0)
