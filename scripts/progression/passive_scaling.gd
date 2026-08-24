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
