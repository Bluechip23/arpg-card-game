class_name PassiveScaling
extends RefCounted

## Per-rank scaling tables for leveled skill-tree passives.
## Each passive holds up to PASSIVE_MAX_LEVEL (15) points; every table below
## has exactly 15 entries, indexed by rank (table[rank - 1]).
## Mana values are in code units (the x10 economy: design "1 mana" = 10 here).

const TABLES := {
	# --- Brad ---
	"enraged_will": {
		"cooldown": [25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 10],
		"hp_threshold": [0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21, 0.22, 0.23, 0.25],
	},
	"directed_strength": {
		"strength": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
	},
	"life_steal": {
		"percent": [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0],
	},
	"stone_skin": {
		"resist": [1.0, 1.75, 2.5, 3.25, 4.0, 4.75, 5.5, 6.25, 7.0, 7.75, 8.5, 9.25, 10.0, 10.75, 11.5],
	},
	"ancestral_aid": {
		"mana_discount": [50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, 190],
		"heal": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
	},
	"vines_codependence": {
		"thorns": [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8],
		"regen": [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7],
	},
	"point_to_prove": {
		"hp_percent": [20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6],
	},
	"redemption": {
		"crit_chance": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
	},
	"solemn_independence": {
		"damage_percent": [5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12],
		"armor": [1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6, 7, 7, 8, 8],
	},
	"in_the_trenches": {
		"damage_mod": [-50, -45, -40, -35, -30, -25, -20, -15, -10, -5, 0, 5, 10, 15, 20],
	},
	"the_way_of_the_plate": {
		"cards_required": [9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2],
	},
	"pristine_armor": {
		"armor": [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5],
		"streak_bonus": [3, 4, 5, 5, 6, 7, 8, 9, 10, 10, 11, 12, 12, 13, 14],
	},

	# --- Cory ---
	"wither": {
		"cooldown": [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
	},
	"territorial_death": {
		"cooldown": [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
	},
	"death_as_lifeblood": {
		"regen_per_enemy": [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5],
		"max_enemies": [3, 4, 4, 4, 5, 6, 6, 7, 8, 8, 9, 10, 10, 11, 12],
	},
	"budding": {
		"amount": [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
	},
	"circle_of_life": {
		"amount": [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24],
	},
	"regrowth": {
		"cooldown": [25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11],
	},
	"prey_on_the_weak": {
		"damage": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
	},
	"eat": {
		"heal_percent": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
		"threshold_percent": [11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39],
	},
	"serial_killer": {
		"hp_threshold": [0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21, 0.22, 0.23, 0.24, 0.25],
	},
	"energy_barrier": {
		"armor": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
	},
	"expel_negativity": {
		"hp_threshold": [0.35, 0.37, 0.39, 0.41, 0.43, 0.45, 0.47, 0.49, 0.51, 0.53, 0.55, 0.57, 0.59, 0.61, 0.63],
	},
	"self_reliance": {
		"mana_discount": [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80],
	},

	# --- Jeremy ---
	"a_mage's_favor": {
		"armor": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
	},
	"kinetic_armor": {
		"tempo": [30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16],
	},
	"fresh_start": {
		"cooldown": [25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11],
	},
	"arcane_overflow": {
		"cooldown": [20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6],
	},
	"harnessed_power": {
		"percent": [18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32],
	},
	"mana_surge": {
		"damage": [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18],
	},
	"tricks_of_death": {
		"chance": [5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0, 10.5, 11.0, 11.5, 12.0],
	},
	"seance": {
		# One value drives both the Specter's HP and its on-death damage
		"specter": [5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33],
	},
	"haunted_rebuke": {
		"cooldown": [25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11],
	},
	"i_heal_you": {
		"interval": [18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4],
	},
	"whispers_of_the_flock": {
		"armor": [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
		# Design: cooldown = 65 - armor
		"cooldown": [60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46],
	},
	"blood_libation": {
		"heal_per_stack": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
	},

	# --- Ryan ---
	"stimulant": {
		"cooldown": [19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5],
	},
	"pop_rocks": {
		"cooldown": [19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5],
	},
	"mad_scientist": {
		# regen/strengthen use the same every-other cadence as poison, 2..8
		"regen": [2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 8],
		"strengthen": [2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 8],
		"poison": [2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9],
		"phys_defense": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
	},
	"quick_step": {
		"armor": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
	},
	"ladder_work": {
		# Rank 1 grants all three; then +1 DEX every other rank, +1 AGI every
		# rank, +1 damage-per-discard every 3rd rank
		"dexterity": [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8],
		"agility": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
		"damage_per_discard": [1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6],
	},
	"let's_dance": {
		# Armor and damage both = spaces moved / divisor, rounded down
		"divisor": [8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 1],
	},
	"keep_them_guessing": {
		"discards_required": [18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4],
	},
	"from_the_hip": {
		"mana": [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 65, 70, 75],
		"tempo": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 2],
	},
	"nimble_assault": {
		"cooldown": [15, 15, 14, 14, 13, 13, 12, 12, 11, 11, 10, 10, 9, 9, 8],
	},
	"now_you_see_me": {
		"cooldown": [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
	},
	"surprise_opener": {
		"first_strike": [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8],
		"no_armor": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
		"first_source": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
	},
	"eye_scrape": {
		"crits_required": [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
	},

	# --- Stephen ---
	"patience_is_a_virtue": {
		# % of the Glut amount dealt as damage before the Glut is halved
		"multiplier": [10, 30, 50, 70, 90, 110, 130, 150, 170, 190, 210, 230, 250, 270, 290],
	},
	"swing_for_the_fences": {
		# % of the card's tempo cost dealt as additional damage
		"multiplier": [100, 120, 140, 160, 180, 200, 220, 240, 260, 280, 300, 320, 340, 360, 380],
	},
	"dominate": {
		"strengthen": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
	},
	"eagle_eye": {
		# % of the ranged card's range dealt as additional damage
		"multiplier": [100, 103, 106, 109, 112, 115, 118, 121, 124, 127, 130, 133, 136, 139, 142],
	},
	"scouted": {
		"range": [2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6],
		"crit_damage": [2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30],
	},
	"laced_arrow": {
		"chance": [50, 53, 56, 59, 62, 65, 68, 71, 74, 77, 80, 83, 86, 89, 100],
	},
	"clean_exchange": {
		"block": [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8],
	},
	"exposed_blind_spot": {
		"crit_per_card": [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 4.25, 4.5],
	},
	"lethal_resourcefulness": {
		"cooldown": [40, 38, 36, 34, 32, 30, 28, 26, 24, 22, 20, 18, 16, 14, 12],
	},
	"deadly": {
		"damage": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
		"crit_damage": [2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30],
	},
	"easy_target": {
		"strengthen": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
	},
	"skilled_momentum": {
		"attacks_required": [10, 10, 9, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3],
	},
}

## Look up a passive's value for `key` at `level`. Levels outside 1..15 are
## clamped (a legacy save with the passive active but no recorded level reads
## as rank 1). Returns 0 for unknown passive/key pairs.
static func value(passive_id: String, key: String, level: int) -> Variant:
	var table: Dictionary = TABLES.get(passive_id, {})
	var ranks: Array = table.get(key, [])
	if ranks.is_empty():
		return 0
	var idx := clampi(level, 1, ranks.size()) - 1
	return ranks[idx]


# ============================================
# RANK-SPECIFIC DESCRIPTION TEXT
# ============================================

## Tree descriptions write scaling values as "A→B" ranges ("10%→25% HP",
## "25→10 tempo", "9th→2nd"). The tree UI wants the value at ONE rank instead,
## so the player reads what the passive does right now and what the next
## point changes. Each range is resolved against this passive's table (the
## key whose first/last entries match A and B — percentages may be stored as
## fractions, mana discounts as positive numbers of a negative range); ranges
## with no matching table interpolate linearly across the 15 ranks.
static var _range_regex: RegEx = null

static func _get_range_regex() -> RegEx:
	if _range_regex == null:
		_range_regex = RegEx.new()
		_range_regex.compile("(-?\\d+(?:\\.\\d+)?)(%|m|st|nd|rd|th)?→(-?\\d+(?:\\.\\d+)?)(%|m|st|nd|rd|th)?")
	return _range_regex

## The number a "A→B" range takes at `rank` (1-based; clamped to the table).
static func range_value_at_rank(passive_id: String, a: float, b: float, rank: int) -> float:
	var max_rank := 15
	var table: Dictionary = TABLES.get(passive_id, {})
	for key in table:
		var ranks: Array = table[key]
		if ranks.is_empty():
			continue
		max_rank = ranks.size()
		var first := float(ranks[0])
		var last := float(ranks[ranks.size() - 1])
		for factor in [1.0, 100.0]:
			for sign in [1.0, -1.0]:
				if is_equal_approx(first * factor * sign, a) and is_equal_approx(last * factor * sign, b):
					var idx := clampi(rank, 1, ranks.size()) - 1
					return float(ranks[idx]) * factor * sign
	# No table (or the description's numbers drifted from it): spread the
	# range evenly over the ranks so the text still moves with each point.
	var t := float(clampi(rank, 1, max_rank) - 1) / float(maxi(1, max_rank - 1))
	return a + (b - a) * t

static func _format_value(v: float, like: String, suffix: String) -> String:
	var text := ""
	if "." in like and not is_equal_approx(v, roundf(v)):
		text = ("%.2f" % v).rstrip("0").rstrip(".")
	elif is_equal_approx(v, roundf(v)):
		text = "%d" % int(roundf(v))
	else:
		text = ("%.2f" % v).rstrip("0").rstrip(".")
	if suffix in ["st", "nd", "rd", "th"]:
		return text + _ordinal_suffix(int(roundf(v)))
	return text + suffix

static func _ordinal_suffix(n: int) -> String:
	var abs_n := absi(n)
	if abs_n % 100 >= 11 and abs_n % 100 <= 13:
		return "th"
	match abs_n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"

## `description` with every "A→B" range replaced by its value at `rank`, and
## the "(scales with rank)" reminders dropped. Non-numeric arrows (card type
## conversions like "Attack→Heal") are left alone.
static func describe_at_rank(passive_id: String, description: String, rank: int) -> String:
	var out := description
	var matches := _get_range_regex().search_all(out)
	# Splice from the back so earlier match offsets stay valid.
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var a_text := m.get_string(1)
		var b_text := m.get_string(3)
		var suffix := m.get_string(2)
		if suffix == "":
			suffix = m.get_string(4)
		var v := range_value_at_rank(passive_id, float(a_text), float(b_text), rank)
		var rendered := _format_value(v, a_text, suffix)
		out = out.substr(0, m.get_start()) + rendered + out.substr(m.get_end())
	out = out.replace(" (scales with rank)", "").replace("(scales with rank)", "")
	return out.strip_edges()
