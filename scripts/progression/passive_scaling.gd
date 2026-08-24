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
		"damage_mod": [-7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7],
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
		"regen": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
		"strengthen": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
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
		"multiplier": [100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800],
	},
	"dominate": {
		"strengthen": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
	},
	"eagle_eye": {
		# % of the ranged card's range dealt as additional damage
		"multiplier": [100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240],
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
