extends RefCounted

## The control group: a level-5 Brad with an even stat spread, the starter
## deck plus a Short Sword, against one Wererat three tiles away. Every
## sweep is a delta from this file — edit it here and the sweeps follow.

static func build() -> Dictionary:
	return {
		"name": "baseline",
		"max_bars": 40,              # hard cap: 40 cycles of 5 tempo
		"tempo_threshold": 5,
		"player": {
			"character": "brad",
			"level": 5,              # 4 level-ups: 12 stat points
			"allocation": {"strength": 2, "dexterity": 2, "intelligence": 2,
				"wisdom": 2, "agility": 2, "determination": 2},
			"passives": [],
			"items": [["short_sword", 0]],
			"deck": SimScenario.starter_deck(),
			"cell": [6, 7],
			"stat_overrides": {},
		},
		"enemies": [
			{"type": "WERERAT", "cell": [9, 7], "overrides": {}},
		],
		"map": {"interior": "dojo", "obstacles": []},
		"policy": "greedy_dpt",
		"script": [],
	}
