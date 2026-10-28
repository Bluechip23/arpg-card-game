extends HealableSummon

## Frankensteins Monster — summoned by the "ITS ALIVE!!!!!" card granted by
## Frankensteins Screws (helm). A corpse is stitched back together into a
## lumbering ally that hunts the nearest enemy.
##
## Stat block (per the item), all scaling off the summoner's INT at spawn:
##   HP        = 50 + INT * 0.8
##   attack    = 10 + INT * 0.25   (every 5 tempo, when adjacent)
##   movement  = 4 spaces every 8 tempo
##   resist    = 5 + INT / 10  (%) against ALL incoming damage
##
## This node owns visuals/health/movement animation; main.gd drives the
## per-tempo decisions (_update_frankensteins) using the cadence counters.

var attack_damage: int = 10
var resist_percent: float = 5.0

const MOVE_INTERVAL := 8      # tempo between moves
const MOVE_STEPS := 4         # tiles per move
const ATTACK_INTERVAL := 5    # tempo between attacks

func setup(gm: GridManager, spawn_pos: Vector3, summoner_int: int) -> void:
	_place(gm, spawn_pos)
	display_name = "Frankensteins Monster"
	glide_speed = 3.0
	max_health = 50 + int(summoner_int * 0.8)
	health = max_health
	attack_damage = 10 + int(summoner_int * 0.25)
	resist_percent = 5.0 + summoner_int / 10.0
	_finish_setup()

func _build_visuals() -> void:
	# The Craftpix stitched zombie (exposed brain), a head taller than the dead it rose from.
	_build_figure("frankenstein")
	_build_health_label(2.0, Color(0.7, 0.95, 0.6))

func _absorb(amount: int) -> int:
	# Resist everything: reduce the incoming amount by resist_percent.
	return maxi(1, floori(amount * (1.0 - minf(resist_percent, 90.0) / 100.0)))


func get_status_effects() -> Array:
	return [{"name": "Resist All", "color": Color(0.6, 0.9, 0.6), "stacks": int(resist_percent),
		"desc": "Takes %d%% less damage from everything." % int(resist_percent)}]
