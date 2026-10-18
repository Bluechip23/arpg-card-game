extends RefCounted

## Setup then payoff (Milestone 5's verification): a fight only won by
## stripping the plate and applying Vulnerable first, then landing the burst
## into it. A bare-handed level-5 Brad (18 health), boxed in so there is no
## stepping out of reach, against a Skeleton beside him with 10 armor over 13
## health that swings for 16 every 4 tempo: the first swing, on the fourth
## tempo, leaves 2 health and the second, on the eighth, is lethal through
## any block in hand. Stance Switch (2 tempo, 10 mana: removes the 10
## armor, 2 Vulnerable) then Slice (3 tempo, 10 mana: 17 damage, 22 into
## Vulnerable) kills it on the fifth tempo, with 30 mana for both. Slice
## alone chews 10 of plate and 7 of health, leaving 6, and the bare-handed
## auto attack (5 damage, 5 tempo) lands on the eighth for 1 short; the rest
## of the deck is blocks, heals and draws.

static func build() -> Dictionary:
	return {
		"name": "setup_payoff",
		"max_bars": 6,
		"tempo_threshold": 5,
		"player": {
			"character": "brad",
			"level": 5,
			"allocation": {"strength": 2, "dexterity": 2, "intelligence": 2,
				"wisdom": 2, "agility": 2, "determination": 2},
			"items": [],
			"deck": ["stance_switch", "slice", "block", "block", "block", "draw", "heal", "gain_mana"],
			"opening_hand": ["stance_switch", "slice"],
			"cell": [6, 7],
			"stat_overrides": {"current_mana": 30.0, "max_mana": 30},
		},
		"enemies": [
			{"type": "SKELETON", "cell": [7, 7], "overrides": {"max_health": 13, "max_armor": 10, "current_armor": 10, "attack_damage": 16}},
		],
		"map": {"interior": "dojo", "obstacles": [[5, 7], [6, 6], [6, 8], [5, 6], [5, 8], [7, 6], [7, 8]]},
		"policy": "combo_planner",
		"script": [],
	}
