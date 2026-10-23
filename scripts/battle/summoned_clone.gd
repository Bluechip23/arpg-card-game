extends HealableSummon

## Draupnir's duplicate: every 9th hit the ring-bearer takes drips a copy of
## them onto the field.
##
## Stat block (per the ring): health = 1/4 of the bearer's max (1/2 at level
## 3), attacks for 1/2 the bearer's basic attack (3/4 at level 3) every 7
## tempo — computed by main at the moment it swings, and the swing feeds the
## bearer's attack-speed counter — moves 2 squares every 3 tempo,
## uncontrollable. Its death grants the bearer Strengthen 10 for 2 attacks.
## Lives until killed — one cumulative journey, no battle-end cleanup.
##
## This node owns visuals/health/movement; main.gd drives per-tempo decisions
## (_update_clones) via the cadence accumulators.

const MOVE_INTERVAL := 3    # tempo between moves
const MOVE_STEPS := 2       # tiles per move
const ATTACK_INTERVAL := 7  # tempo between attacks

var preset := "Brad"  # whose figure the echo wears (SpriteFigure.ROSTER)

func setup(gm: GridManager, spawn_pos: Vector3, hp: int, bearer_preset: String = "Brad") -> void:
	_place(gm, spawn_pos)
	preset = bearer_preset
	display_name = "Duplicate"
	max_health = maxi(1, hp)
	health = max_health
	_finish_setup()

func _build_visuals() -> void:
	# A gold-tinged, half-real echo of the bearer: their own figure.
	_build_player_figure(preset, Color(1.2, 1.05, 0.55, 0.6))
	_build_health_label(1.6, Color(0.9, 0.85, 0.6))
