extends MarkableSummon

## Wolf summoned by Gauntlets of Dungeon Mastering (on-self: slotted card play).
##
## Stat block (per the item): 20 HP, attacks every 5 tempo, moves 2 spaces every
## 3 tempo, attacks apply bleed. Wolfpack: each OTHER friendly wolf grants +20%
## attack damage and +1 bleed (computed by main at attack time).
##
## This node owns visuals/health/movement; main.gd drives per-tempo decisions
## (_update_wolves) via the cadence accumulators.

const BASE_ATTACK := 5      # confirmed: wolves hit for 5 before pack bonuses
const MOVE_INTERVAL := 3    # tempo between moves
const MOVE_STEPS := 2       # tiles per move
const ATTACK_INTERVAL := 5  # tempo between attacks

func setup(gm: GridManager, spawn_pos: Vector3) -> void:
	_place(gm, spawn_pos)
	display_name = "Wolf"
	max_health = 20
	health = 20
	_finish_setup()

func _build_visuals() -> void:
	_build_figure("wolf")  # the designer's wolf sheet, as the Forest wolves wear
	_build_health_label(1.7, Color(0.8, 0.8, 0.9))
