extends SceneTree

## Verifies PassiveScaling: every Brad passive table has exactly 15 ranks
## (one per investable point), endpoint values match the design sheet, and
## out-of-range levels clamp instead of crashing.
## Run: godot --headless --path . --script tests/test_passive_scaling.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Passive scaling table test ===")

	# --- Every table holds exactly PASSIVE_MAX_LEVEL (15) ranks ---
	for passive_id in PassiveScaling.TABLES:
		var table: Dictionary = PassiveScaling.TABLES[passive_id]
		_check(table.size() > 0, "%s has at least one scaled value" % passive_id)
		for key in table:
			var ranks: Array = table[key]
			_check(ranks.size() == SkillTreeData.PASSIVE_MAX_LEVEL,
				"%s.%s has %d ranks (want %d)" % [passive_id, key, ranks.size(), SkillTreeData.PASSIVE_MAX_LEVEL])

	# --- Endpoints match the design sheet ---
	_check(PassiveScaling.value("enraged_will", "cooldown", 1) == 25, "Enraged Will rank 1 cooldown 25")
	_check(PassiveScaling.value("enraged_will", "cooldown", 15) == 10, "Enraged Will rank 15 cooldown 10")
	_check(is_equal_approx(PassiveScaling.value("enraged_will", "hp_threshold", 1), 0.10), "Enraged Will rank 1 threshold 10%")
	_check(is_equal_approx(PassiveScaling.value("enraged_will", "hp_threshold", 15), 0.25), "Enraged Will rank 15 threshold 25%")
	_check(PassiveScaling.value("directed_strength", "strength", 1) == 1, "Directed Strength rank 1 = +1 STR")
	_check(PassiveScaling.value("directed_strength", "strength", 15) == 15, "Directed Strength rank 15 = +15 STR")
	_check(is_equal_approx(PassiveScaling.value("life_steal", "percent", 1), 1.0), "Life Steal rank 1 = 1%")
	_check(is_equal_approx(PassiveScaling.value("life_steal", "percent", 15), 8.0), "Life Steal rank 15 = 8%")
	_check(is_equal_approx(PassiveScaling.value("stone_skin", "resist", 1), 1.0), "Stone Skin rank 1 = 1%")
	_check(is_equal_approx(PassiveScaling.value("stone_skin", "resist", 15), 11.5), "Stone Skin rank 15 = 11.5%")
	_check(PassiveScaling.value("ancestral_aid", "mana_discount", 1) == 50, "Ancestral Aid rank 1 = 50m (design 5m)")
	_check(PassiveScaling.value("ancestral_aid", "mana_discount", 15) == 190, "Ancestral Aid rank 15 = 190m (design 19m)")
	_check(PassiveScaling.value("ancestral_aid", "heal", 1) == 3, "Ancestral Aid rank 1 heal 3")
	_check(PassiveScaling.value("ancestral_aid", "heal", 15) == 17, "Ancestral Aid rank 15 heal 17")
	_check(PassiveScaling.value("vines_codependence", "thorns", 1) == 1, "Vines rank 1 = 1 thorns")
	_check(PassiveScaling.value("vines_codependence", "regen", 1) == 0, "Vines rank 1 = no regen")
	_check(PassiveScaling.value("vines_codependence", "thorns", 15) == 8, "Vines rank 15 = 8 thorns")
	_check(PassiveScaling.value("vines_codependence", "regen", 15) == 7, "Vines rank 15 = 7 regen")
	_check(PassiveScaling.value("point_to_prove", "hp_percent", 1) == 20, "Point to Prove rank 1 = 20% HP")
	_check(PassiveScaling.value("point_to_prove", "hp_percent", 15) == 6, "Point to Prove rank 15 = 6% HP")
	_check(PassiveScaling.value("redemption", "crit_chance", 1) == 1, "Redemption rank 1 = 1% crit")
	_check(PassiveScaling.value("redemption", "crit_chance", 15) == 15, "Redemption rank 15 = 15% crit")
	_check(PassiveScaling.value("solemn_independence", "damage_percent", 1) == 5, "Solemn rank 1 = 5% damage")
	_check(PassiveScaling.value("solemn_independence", "damage_percent", 15) == 12, "Solemn rank 15 = 12% damage")
	_check(PassiveScaling.value("solemn_independence", "armor", 1) == 1, "Solemn rank 1 = 1 armor")
	_check(PassiveScaling.value("solemn_independence", "armor", 15) == 8, "Solemn rank 15 = 8 armor")
	_check(PassiveScaling.value("in_the_trenches", "damage_mod", 1) == -7, "Trenches rank 1 = -7%")
	_check(PassiveScaling.value("in_the_trenches", "damage_mod", 8) == 0, "Trenches rank 8 = +0%")
	_check(PassiveScaling.value("in_the_trenches", "damage_mod", 15) == 7, "Trenches rank 15 = +7%")
	_check(PassiveScaling.value("the_way_of_the_plate", "cards_required", 1) == 9, "Way of the Plate rank 1 = every 9th")
	_check(PassiveScaling.value("the_way_of_the_plate", "cards_required", 15) == 2, "Way of the Plate rank 15 = every 2nd")
	_check(PassiveScaling.value("pristine_armor", "armor", 1) == 1, "Pristine Armor rank 1 = +1 armor")
	_check(PassiveScaling.value("pristine_armor", "streak_bonus", 1) == 3, "Pristine Armor rank 1 streak = +3")
	_check(PassiveScaling.value("pristine_armor", "armor", 15) == 5, "Pristine Armor rank 15 = +5 armor")
	_check(PassiveScaling.value("pristine_armor", "streak_bonus", 15) == 14, "Pristine Armor rank 15 streak = +14")

	# --- Cory endpoints ---
	_check(PassiveScaling.value("wither", "cooldown", 1) == 15, "Wither rank 1 cooldown 15")
	_check(PassiveScaling.value("wither", "cooldown", 15) == 1, "Wither rank 15 cooldown 1")
	_check(PassiveScaling.value("territorial_death", "cooldown", 1) == 15, "Territorial Death rank 1 cooldown 15")
	_check(PassiveScaling.value("territorial_death", "cooldown", 15) == 1, "Territorial Death rank 15 cooldown 1")
	_check(PassiveScaling.value("death_as_lifeblood", "regen_per_enemy", 1) == 1, "Death as Lifeblood rank 1 = 1/enemy")
	_check(PassiveScaling.value("death_as_lifeblood", "regen_per_enemy", 15) == 5, "Death as Lifeblood rank 15 = 5/enemy")
	_check(PassiveScaling.value("death_as_lifeblood", "max_enemies", 1) == 3, "Death as Lifeblood rank 1 max 3 enemies")
	_check(PassiveScaling.value("death_as_lifeblood", "max_enemies", 15) == 12, "Death as Lifeblood rank 15 max 12 enemies")
	_check(PassiveScaling.value("budding", "amount", 1) == 5, "Budding rank 1 = 5")
	_check(PassiveScaling.value("budding", "amount", 15) == 19, "Budding rank 15 = 19")
	_check(PassiveScaling.value("circle_of_life", "amount", 1) == 10, "Circle of Life rank 1 = 10")
	_check(PassiveScaling.value("circle_of_life", "amount", 15) == 24, "Circle of Life rank 15 = 24")
	_check(PassiveScaling.value("regrowth", "cooldown", 1) == 25, "Regrowth rank 1 cooldown 25")
	_check(PassiveScaling.value("regrowth", "cooldown", 15) == 11, "Regrowth rank 15 cooldown 11")
	_check(PassiveScaling.value("prey_on_the_weak", "damage", 1) == 3, "Prey on the Weak rank 1 = 3")
	_check(PassiveScaling.value("prey_on_the_weak", "damage", 15) == 17, "Prey on the Weak rank 15 = 17")
	_check(PassiveScaling.value("eat", "heal_percent", 1) == 1, "Eat rank 1 heals 1%")
	_check(PassiveScaling.value("eat", "heal_percent", 15) == 15, "Eat rank 15 heals 15%")
	_check(PassiveScaling.value("eat", "threshold_percent", 1) == 11, "Eat rank 1 threshold 11%")
	_check(PassiveScaling.value("eat", "threshold_percent", 15) == 39, "Eat rank 15 threshold 39%")
	_check(is_equal_approx(PassiveScaling.value("serial_killer", "hp_threshold", 1), 0.11), "Serial Killer rank 1 = 11%")
	_check(is_equal_approx(PassiveScaling.value("serial_killer", "hp_threshold", 15), 0.25), "Serial Killer rank 15 = 25%")
	_check(PassiveScaling.value("energy_barrier", "armor", 1) == 3, "Energy Barrier rank 1 = 3 armor")
	_check(PassiveScaling.value("energy_barrier", "armor", 15) == 17, "Energy Barrier rank 15 = 17 armor")
	_check(is_equal_approx(PassiveScaling.value("expel_negativity", "hp_threshold", 1), 0.35), "Expel Negativity rank 1 = 35%")
	_check(is_equal_approx(PassiveScaling.value("expel_negativity", "hp_threshold", 15), 0.63), "Expel Negativity rank 15 = 63%")
	_check(PassiveScaling.value("self_reliance", "mana_discount", 1) == 10, "Self Reliance rank 1 = 10m (design 1)")
	_check(PassiveScaling.value("self_reliance", "mana_discount", 15) == 80, "Self Reliance rank 15 = 80m (design 8)")

	# --- Energy Barrier card carries the rank-scaled armor ---
	var eb := Card.create_energy_barrier(9)
	_check(eb.block == 9 and eb.base_block == 9, "Energy Barrier card block follows the passive rank")
	_check("9 armor" in eb.description, "Energy Barrier card description shows the scaled armor")

	# --- Out-of-range levels clamp (legacy save with no recorded level = rank 1) ---
	_check(PassiveScaling.value("life_steal", "percent", 0) == PassiveScaling.value("life_steal", "percent", 1),
		"level 0 clamps to rank 1")
	_check(PassiveScaling.value("life_steal", "percent", 99) == PassiveScaling.value("life_steal", "percent", 15),
		"level 99 clamps to rank 15")
	_check(PassiveScaling.value("no_such_passive", "x", 5) == 0, "unknown passive returns 0")

	# --- Rank-scaled effects read through PlayerStats ---
	var stats = PlayerStats.new()
	stats.unspent_passive_points = 20
	stats.allocate_passive_point("directed_strength")
	stats.current_health = floori(stats.max_health * 0.4)
	_check(stats.strength == max(1, stats.get_effective_stat(stats.base_strength) + 1),
		"Directed Strength rank 1 adds +1 STR below half health")
	for i in range(14):
		stats.allocate_passive_point("directed_strength")
	_check(stats.get_passive_level("directed_strength") == 15, "Directed Strength capped at 15")
	_check(stats.strength == max(1, stats.get_effective_stat(stats.base_strength) + 15),
		"Directed Strength rank 15 adds +15 STR below half health")
	stats.free()

	print("")
	if failures == 0:
		print("ALL PASSED")
	else:
		printerr("%d FAILURE(S)" % failures)
	quit(1 if failures > 0 else 0)
