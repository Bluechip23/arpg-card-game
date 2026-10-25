extends HealableSummon

## Sanguine the blood penguin (Nine Ruins of Sanguine): summoned at 9 Vitality.
##
## Stat block (per the item): 50 HP, stays within 1 square of the wielder
## ("mimics your moves"), melee attacks for 8 every 5 tempo. He can be hit —
## friendly fire included — and every point of damage HE takes heals the
## wielder for half. While he lives, the dagger gains no Vitality.
##
## This node owns visuals/health/movement; main.gd drives per-tempo decisions
## (_update_penguin) and routes his heal-on-hurt to the player.

signal hurt(amount)  # damage he absorbed — main heals the wielder for half

const BASE_ATTACK := 8      # per the spec: 8 damage every 5 tempo
const ATTACK_INTERVAL := 5  # tempo between attacks

func setup(gm: GridManager, spawn_pos: Vector3) -> void:
	_place(gm, spawn_pos)
	display_name = "Sanguine"
	glide_speed = 5.0
	max_health = 50
	health = 50
	_finish_setup()

func _build_visuals() -> void:
	# The designer's blood penguin in a Spartan helm (sanguine_penguin_board.jpg,
	# cut by tools/cut_pose_boards.py): front, back and both sides.
	_build_figure("sanguine_penguin")
	_build_health_label(1.25, Color(0.9, 0.5, 0.5))

func _after_hit(dealt: int, health_before: int) -> void:
	hurt.emit(mini(dealt, health_before))  # the wielder drinks half of what Sanguine bleeds
