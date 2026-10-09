extends RefCounted

## Hand-computable control: a fresh level-1 Brad, no items, crit chance
## forced to 0, with one Wererat on the next tile. The script plays Attack
## (slash) once: 10 + floor(STR 3 * 0.5) = 11 damage, 20 mana, 3 tempo,
## resolving on tick 1 — the 8-HP rat dies before its 2-tempo bite lands.
## tests/test_sim_hand_check.gd asserts the CSV line by line.

static func build() -> Dictionary:
	var deck: Array = []
	for i in range(6):
		deck.append("slash")
	return {
		"name": "hand_check",
		"max_bars": 10,
		"player": {
			"character": "brad",
			"level": 1,
			"deck": deck,
			"cell": [6, 7],
			"stat_overrides": {"base_crit_chance": 0},
		},
		"enemies": [
			{"type": "WERERAT", "cell": [7, 7]},
		],
		"policy": "scripted",
		"script": [
			{"type": "play", "card": "slash", "target": "enemy:0"},
		],
	}
