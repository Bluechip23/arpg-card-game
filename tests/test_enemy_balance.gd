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
		_check(by_name["Ring Wraith"]["health"] == 100, "Ring Wraith compendium HP matches code (100)")

	# --- Spot-check restrengthened stats (compendium side) ---
	_check(by_name["Rat King"]["health"] == 90 and by_name["Rat King"]["armor"] == 10,
		"Rat King is a real mini-boss now (90 HP, 10 armor)")
	_check(by_name["Bone Dragon"]["health"] == 150, "Bone Dragon 150 HP")
	_check(by_name["Grave Titan"]["health"] == 130 and by_name["Grave Titan"]["armor"] == 30,
		"Grave Titan 130 HP / 30 armor")
	_check(by_name["Hydra"]["health"] == 80, "Hydra 80 HP")
	_check(by_name["Treant"]["health"] == 110, "Treant 110 HP")
	_check(by_name["Coyote"]["health"] == 6, "Coyote stays blowy-uppy (6 HP)")
	_check(by_name["Swarm"]["health"] == 10, "Swarm stays blowy-uppy (10 HP)")
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
