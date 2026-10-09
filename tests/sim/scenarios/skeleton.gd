extends RefCounted

## A real threat: a level-4 Brad (starter deck + Short Sword) against a
## Skeleton — 20 HP under 12 armor, a 6-damage swing on a 4-tempo wind-up.

static func build() -> Dictionary:
	return {
		"name": "skeleton",
		"max_bars": 40,
		"player": {
			"character": "brad",
			"level": 4,
			"allocation": {"strength": 3, "determination": 3, "wisdom": 3},
			"items": [["short_sword", 0]],
			"deck": SimScenario.starter_deck(),
			"cell": [6, 7],
		},
		"enemies": [
			{"type": "SKELETON", "cell": [9, 7]},
		],
		"policy": "lookahead",
	}
