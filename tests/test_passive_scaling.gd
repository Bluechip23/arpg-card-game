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

	# --- Jeremy endpoints ---
	_check(PassiveScaling.value("a_mage's_favor", "armor", 1) == 2, "A Mage's Favor rank 1 = 2 armor")
	_check(PassiveScaling.value("a_mage's_favor", "armor", 15) == 16, "A Mage's Favor rank 15 = 16 armor")
	_check(PassiveScaling.value("kinetic_armor", "tempo", 1) == 30, "Kinetic Armor rank 1 = 30 tempo hold")
	_check(PassiveScaling.value("kinetic_armor", "tempo", 15) == 16, "Kinetic Armor rank 15 = 16 tempo hold")
	_check(PassiveScaling.value("fresh_start", "cooldown", 1) == 25, "Fresh Start rank 1 cooldown 25")
	_check(PassiveScaling.value("fresh_start", "cooldown", 15) == 11, "Fresh Start rank 15 cooldown 11")
	_check(PassiveScaling.value("arcane_overflow", "cooldown", 1) == 20, "Arcane Overflow rank 1 cooldown 20")
	_check(PassiveScaling.value("arcane_overflow", "cooldown", 15) == 6, "Arcane Overflow rank 15 cooldown 6")
	_check(PassiveScaling.value("harnessed_power", "percent", 1) == 18, "Harnessed Power rank 1 = 18%")
	_check(PassiveScaling.value("harnessed_power", "percent", 15) == 32, "Harnessed Power rank 15 = 32%")
	_check(PassiveScaling.value("mana_surge", "damage", 1) == 4, "Mana Surge rank 1 = 4 damage")
	_check(PassiveScaling.value("mana_surge", "damage", 15) == 18, "Mana Surge rank 15 = 18 damage")
	_check(is_equal_approx(PassiveScaling.value("tricks_of_death", "chance", 1), 5.0), "Tricks of Death rank 1 = +5%")
	_check(is_equal_approx(PassiveScaling.value("tricks_of_death", "chance", 15), 12.0), "Tricks of Death rank 15 = +12%")
	_check(PassiveScaling.value("seance", "specter", 1) == 5, "Seance rank 1 = 5 HP/damage")
	_check(PassiveScaling.value("seance", "specter", 15) == 33, "Seance rank 15 = 33 HP/damage")
	_check(PassiveScaling.value("haunted_rebuke", "cooldown", 1) == 25, "Haunted Rebuke rank 1 cooldown 25")
	_check(PassiveScaling.value("haunted_rebuke", "cooldown", 15) == 11, "Haunted Rebuke rank 15 cooldown 11")
	_check(PassiveScaling.value("i_heal_you", "interval", 1) == 18, "I Heal You rank 1 every 18 tempo")
	_check(PassiveScaling.value("i_heal_you", "interval", 15) == 4, "I Heal You rank 15 every 4 tempo")
	_check(PassiveScaling.value("whispers_of_the_flock", "armor", 1) == 5, "Whispers rank 1 = 5 armor")
	_check(PassiveScaling.value("whispers_of_the_flock", "armor", 15) == 19, "Whispers rank 15 = 19 armor")
	_check(PassiveScaling.value("whispers_of_the_flock", "cooldown", 1) == 60, "Whispers rank 1 cooldown 60 (65-5)")
	_check(PassiveScaling.value("whispers_of_the_flock", "cooldown", 15) == 46, "Whispers rank 15 cooldown 46 (65-19)")
	_check(PassiveScaling.value("blood_libation", "heal_per_stack", 1) == 1, "Blood Libation rank 1 = +1/stack")
	_check(PassiveScaling.value("blood_libation", "heal_per_stack", 15) == 15, "Blood Libation rank 15 = +15/stack")
	# Whispers cooldown stays 65 - armor at every rank
	for r in range(1, 16):
		if PassiveScaling.value("whispers_of_the_flock", "cooldown", r) != 65 - int(PassiveScaling.value("whispers_of_the_flock", "armor", r)):
			_check(false, "Whispers rank %d cooldown = 65 - armor" % r)
			break

	# --- Ryan endpoints ---
	_check(PassiveScaling.value("stimulant", "cooldown", 1) == 19, "Stimulant rank 1 cooldown 19")
	_check(PassiveScaling.value("stimulant", "cooldown", 15) == 5, "Stimulant rank 15 cooldown 5")
	_check(PassiveScaling.value("pop_rocks", "cooldown", 1) == 19, "Pop Rocks rank 1 cooldown 19")
	_check(PassiveScaling.value("pop_rocks", "cooldown", 15) == 5, "Pop Rocks rank 15 cooldown 5")
	_check(PassiveScaling.value("mad_scientist", "regen", 1) == 2, "Mad Scientist rank 1 = +2 regen")
	_check(PassiveScaling.value("mad_scientist", "regen", 15) == 16, "Mad Scientist rank 15 = +16 regen")
	_check(PassiveScaling.value("mad_scientist", "strengthen", 15) == 16, "Mad Scientist rank 15 = +16 strengthen")
	_check(PassiveScaling.value("mad_scientist", "poison", 1) == 2, "Mad Scientist rank 1 = +2 poison")
	_check(PassiveScaling.value("mad_scientist", "poison", 15) == 9, "Mad Scientist rank 15 = +9 poison")
	_check(PassiveScaling.value("mad_scientist", "phys_defense", 1) == 1, "Mad Scientist rank 1 = -1% defense")
	_check(PassiveScaling.value("mad_scientist", "phys_defense", 15) == 15, "Mad Scientist rank 15 = -15% defense")
	_check(PassiveScaling.value("quick_step", "armor", 1) == 2, "Quick Step rank 1 = 2 armor")
	_check(PassiveScaling.value("quick_step", "armor", 15) == 16, "Quick Step rank 15 = 16 armor")
	_check(PassiveScaling.value("ladder_work", "dexterity", 1) == 1, "Ladder Work rank 1 = +1 DEX")
	_check(PassiveScaling.value("ladder_work", "dexterity", 15) == 8, "Ladder Work rank 15 = +8 DEX")
	_check(PassiveScaling.value("ladder_work", "agility", 1) == 1, "Ladder Work rank 1 = +1 AGI")
	_check(PassiveScaling.value("ladder_work", "agility", 15) == 15, "Ladder Work rank 15 = +15 AGI")
	_check(PassiveScaling.value("ladder_work", "damage_per_discard", 1) == 1, "Ladder Work rank 1 = +1/discard")
	_check(PassiveScaling.value("ladder_work", "damage_per_discard", 15) == 6, "Ladder Work rank 15 = +6/discard")
	_check(PassiveScaling.value("let's_dance", "divisor", 1) == 8, "Let's Dance rank 1 divisor 8")
	_check(PassiveScaling.value("let's_dance", "divisor", 15) == 1, "Let's Dance rank 15 divisor 1")
	_check(PassiveScaling.value("keep_them_guessing", "discards_required", 1) == 18, "Keep Them Guessing rank 1 = 18 discards")
	_check(PassiveScaling.value("keep_them_guessing", "discards_required", 15) == 4, "Keep Them Guessing rank 15 = 4 discards")
	_check(PassiveScaling.value("from_the_hip", "mana", 1) == 10, "From the Hip rank 1 = 10m (design 1)")
	_check(PassiveScaling.value("from_the_hip", "mana", 15) == 75, "From the Hip rank 15 = 75m (design 7.5)")
	_check(PassiveScaling.value("from_the_hip", "tempo", 10) == 0, "From the Hip rank 10 = no tempo discount")
	_check(PassiveScaling.value("from_the_hip", "tempo", 11) == 1, "From the Hip rank 11 = -1t")
	_check(PassiveScaling.value("from_the_hip", "tempo", 15) == 2, "From the Hip rank 15 = -2t")
	_check(PassiveScaling.value("nimble_assault", "cooldown", 1) == 15, "Nimble Assault rank 1 cooldown 15")
	_check(PassiveScaling.value("nimble_assault", "cooldown", 15) == 8, "Nimble Assault rank 15 cooldown 8")
	_check(PassiveScaling.value("now_you_see_me", "cooldown", 1) == 15, "Now You See Me rank 1 cooldown 15")
	_check(PassiveScaling.value("now_you_see_me", "cooldown", 15) == 1, "Now You See Me rank 15 cooldown 1")
	_check(PassiveScaling.value("surprise_opener", "first_strike", 1) == 1, "Surprise Opener rank 1 first strike +1")
	_check(PassiveScaling.value("surprise_opener", "first_strike", 15) == 8, "Surprise Opener rank 15 first strike +8")
	_check(PassiveScaling.value("surprise_opener", "no_armor", 15) == 15, "Surprise Opener rank 15 no-armor +15")
	_check(PassiveScaling.value("surprise_opener", "first_source", 1) == 3, "Surprise Opener rank 1 first-source +3")
	_check(PassiveScaling.value("surprise_opener", "first_source", 15) == 17, "Surprise Opener rank 15 first-source +17")
	_check(PassiveScaling.value("eye_scrape", "crits_required", 1) == 15, "Eye Scrape rank 1 = every 15th crit")
	_check(PassiveScaling.value("eye_scrape", "crits_required", 15) == 1, "Eye Scrape rank 15 = every crit")

	# --- Ladder Work DEX/AGI flow through the stat getters, not baked stats ---
	var rstats = PlayerStats.new()
	rstats.unspent_passive_points = 20
	var base_dex: int = rstats.dexterity
	var base_agi: int = rstats.agility
	rstats.allocate_passive_point("ladder_work")
	_check(rstats.dexterity == base_dex + 1 and rstats.agility == base_agi + 1,
		"Ladder Work rank 1 grants +1 DEX and +1 AGI dynamically")
	for i in range(14):
		rstats.allocate_passive_point("ladder_work")
	_check(rstats.dexterity == base_dex + 8 and rstats.agility == base_agi + 15,
		"Ladder Work rank 15 grants +8 DEX and +15 AGI dynamically")
	rstats.free()

	# --- Stephen endpoints ---
	_check(PassiveScaling.value("patience_is_a_virtue", "multiplier", 1) == 10, "Patience rank 1 = 10%")
	_check(PassiveScaling.value("patience_is_a_virtue", "multiplier", 15) == 290, "Patience rank 15 = 290%")
	_check(PassiveScaling.value("swing_for_the_fences", "multiplier", 1) == 100, "Swing rank 1 = 100%")
	_check(PassiveScaling.value("swing_for_the_fences", "multiplier", 15) == 800, "Swing rank 15 = 800%")
	_check(PassiveScaling.value("dominate", "strengthen", 1) == 2, "Dominate rank 1 = +2 Strengthen")
	_check(PassiveScaling.value("dominate", "strengthen", 15) == 16, "Dominate rank 15 = +16 Strengthen")
	_check(PassiveScaling.value("eagle_eye", "multiplier", 1) == 100, "Eagle Eye rank 1 = 100% of range")
	_check(PassiveScaling.value("eagle_eye", "multiplier", 15) == 240, "Eagle Eye rank 15 = 240% of range")
	_check(PassiveScaling.value("scouted", "range", 1) == 2, "Scouted rank 1 = +2 range")
	_check(PassiveScaling.value("scouted", "range", 12) == 5, "Scouted rank 12 = +5 range")
	_check(PassiveScaling.value("scouted", "range", 15) == 6, "Scouted rank 15 = +6 range")
	_check(PassiveScaling.value("scouted", "crit_damage", 1) == 2, "Scouted rank 1 = +2% crit damage")
	_check(PassiveScaling.value("scouted", "crit_damage", 15) == 30, "Scouted rank 15 = +30% crit damage")
	_check(PassiveScaling.value("laced_arrow", "chance", 1) == 50, "Laced Arrow rank 1 = 50%")
	_check(PassiveScaling.value("laced_arrow", "chance", 14) == 89, "Laced Arrow rank 14 = 89%")
	_check(PassiveScaling.value("laced_arrow", "chance", 15) == 100, "Laced Arrow rank 15 = 100%")
	_check(PassiveScaling.value("clean_exchange", "block", 1) == 1, "Clean Exchange rank 1 = +1 block")
	_check(PassiveScaling.value("clean_exchange", "block", 15) == 8, "Clean Exchange rank 15 = +8 block")
	_check(is_equal_approx(PassiveScaling.value("exposed_blind_spot", "crit_per_card", 1), 1.0), "Exposed Blind Spot rank 1 = 1%/card")
	_check(is_equal_approx(PassiveScaling.value("exposed_blind_spot", "crit_per_card", 15), 4.5), "Exposed Blind Spot rank 15 = 4.5%/card")
	_check(PassiveScaling.value("lethal_resourcefulness", "cooldown", 1) == 40, "Lethal Resourcefulness rank 1 cooldown 40")
	_check(PassiveScaling.value("lethal_resourcefulness", "cooldown", 15) == 12, "Lethal Resourcefulness rank 15 cooldown 12")
	_check(PassiveScaling.value("deadly", "damage", 1) == 2, "Deadly rank 1 = +2 damage")
	_check(PassiveScaling.value("deadly", "damage", 15) == 16, "Deadly rank 15 = +16 damage")
	_check(PassiveScaling.value("deadly", "crit_damage", 1) == 2, "Deadly rank 1 = +2% crit damage")
	_check(PassiveScaling.value("deadly", "crit_damage", 15) == 30, "Deadly rank 15 = +30% crit damage")
	_check(PassiveScaling.value("easy_target", "strengthen", 1) == 1, "Easy Target rank 1 = +1 Strengthen")
	_check(PassiveScaling.value("easy_target", "strengthen", 15) == 15, "Easy Target rank 15 = +15 Strengthen")
	_check(PassiveScaling.value("skilled_momentum", "attacks_required", 1) == 10, "Skilled Momentum rank 1 = 10 attacks")
	_check(PassiveScaling.value("skilled_momentum", "attacks_required", 15) == 3, "Skilled Momentum rank 15 = 3 attacks")

	# --- Deadly/Scouted crit damage flow through the crit multiplier ---
	var sstats = PlayerStats.new()
	sstats.unspent_passive_points = 20
	var base_crit_mult: float = sstats.get_crit_damage_multiplier()
	sstats.allocate_passive_point("deadly")
	sstats.st_deadly_crit_active = true
	_check(is_equal_approx(sstats.get_crit_damage_multiplier(), base_crit_mult + 0.02),
		"Deadly rank 1 adds +2% crit damage while armed")
	for i in range(14):
		sstats.allocate_passive_point("deadly")
	_check(is_equal_approx(sstats.get_crit_damage_multiplier(), base_crit_mult + 0.30),
		"Deadly rank 15 adds +30% crit damage while armed")
	sstats.st_deadly_crit_active = false
	sstats.allocate_passive_point("scouted")
	sstats.st_scouted_crit_active = true
	_check(is_equal_approx(sstats.get_crit_damage_multiplier(), base_crit_mult + 0.02),
		"Scouted rank 1 adds +2% crit damage on the scouted strike")
	sstats.free()

	# --- Jeremy's conjured cards carry the rank-scaled values ---
	var ms := Card.create_mana_surge(12)
	_check(ms.damage == 12 and ms.base_damage == 12, "Mana Surge card damage follows the passive rank")
	var mb := Card.create_magic_barrier(7)
	_check(mb.block == 7 and mb.base_block == 7, "Magic Barrier card armor follows the passive rank")
	var sm := Card.create_shepherds_mark(14)
	_check("14 armor" in sm.description, "Shepherd's Mark card description shows the scaled armor")

	# --- Tricks of Death feeds get_chance_boost dynamically ---
	var jstats = PlayerStats.new()
	jstats.unspent_passive_points = 20
	_check(is_equal_approx(jstats.get_chance_boost(), 0.0), "no chance boost without Tricks of Death")
	jstats.allocate_passive_point("tricks_of_death")
	_check(is_equal_approx(jstats.get_chance_boost(), 5.0), "Tricks of Death rank 1 boosts chances by 5")
	for i in range(14):
		jstats.allocate_passive_point("tricks_of_death")
	_check(is_equal_approx(jstats.get_chance_boost(), 12.0), "Tricks of Death rank 15 boosts chances by 12")
	jstats.chance_boost = 10.0
	_check(is_equal_approx(jstats.get_chance_boost(), 22.0), "equipment chance boost stacks with Tricks of Death")
	jstats.free()

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
