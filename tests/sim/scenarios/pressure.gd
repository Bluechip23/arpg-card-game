extends RefCounted

## A fight with something to think about: a level-3 Brad with the starter
## deck and a Short Sword against two Wererats closing from either side.
## Used to tell the policies apart (random < greedy_dpt <= lookahead).

static func build() -> Dictionary:
	return {
		"name": "pressure",
		"max_bars": 40,
		"player": {
			"character": "brad",
			"level": 3,
			"allocation": {"strength": 2, "determination": 2, "wisdom": 2},
			"items": [["short_sword", 0]],
			"deck": SimScenario.starter_deck(),
			"cell": [8, 7],
		},
		"enemies": [
			{"type": "WERERAT", "cell": [11, 7]},
			{"type": "WERERAT", "cell": [5, 8]},
		],
		"policy": "lookahead",
	}
