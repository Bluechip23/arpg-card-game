extends RefCounted

## Outnumbered: a level-2 Brad (starter deck + Short Sword) against three
## Wererats closing from three sides. Bites add up fast at 12 HP.

static func build() -> Dictionary:
	return {
		"name": "gauntlet",
		"max_bars": 40,
		"player": {
			"character": "brad",
			"level": 2,
			"allocation": {"strength": 3},
			"items": [["short_sword", 0]],
			"deck": SimScenario.starter_deck(),
			"cell": [8, 7],
		},
		"enemies": [
			{"type": "WERERAT", "cell": [11, 7]},
			{"type": "WERERAT", "cell": [5, 8]},
			{"type": "WERERAT", "cell": [8, 4]},
		],
		"policy": "lookahead",
	}
