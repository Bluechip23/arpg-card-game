extends HealableSummon

## Summoned melee ally: the Sack of Bone Arrows skeleton, plus the manifest
## summons (skeleton / spirit / golem) that share its brain.
##
## Base stat block (skeleton, per the item): hits for 5, moves 4 spaces every
## tempo, attacks every 5 tempo. Spirits are fast and fragile; golems slow and
## tanky (see setup). Lives until killed (or the battle ends); at most 3
## summons stand at once.
##
## This node owns visuals/health/movement; main.gd drives per-tempo decisions
## (_update_skeletons) via the cadence accumulators.

# Per-kind cadence knobs — skeleton defaults; setup() retunes for the kind.
var base_attack := 5      # damage per hit
var move_interval := 1    # tempo between moves
var move_steps := 4       # tiles per move
var attack_interval := 5  # tempo between attacks
var kind := "skeleton"

func setup(gm: GridManager, spawn_pos: Vector3, hp: int, summon_kind := "skeleton") -> void:
	_place(gm, spawn_pos)
	glide_speed = 4.5
	kind = summon_kind
	match kind:
		"spirit":
			# Fast and fragile: weaker hits, quicker cadence, longer strides.
			display_name = "Spirit"
			base_attack = 3
			attack_interval = 3
			move_steps = 5
		"golem":
			# Slow and tanky: heavy hits on a long wind-up, short strides.
			display_name = "Golem"
			base_attack = 8
			attack_interval = 8
			move_steps = 2
		_:
			display_name = "Skeleton"
	max_health = maxi(1, hp)
	health = max_health
	_finish_setup()

func _build_visuals() -> void:
	match kind:
		"spirit":
			_build_figure("specter")         # the Craftpix ghost
		"golem":
			_build_figure("summon_golem")    # the Craftpix rock golem, ally-sized
		_:
			_build_figure("skeleton")        # the Craftpix skeleton the Graveyard's wear
	_build_health_label(1.7, Color(0.85, 0.9, 0.8))
