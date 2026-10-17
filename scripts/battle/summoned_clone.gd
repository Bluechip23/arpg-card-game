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

func setup(gm: GridManager, spawn_pos: Vector3, hp: int) -> void:
	_place(gm, spawn_pos)
	display_name = "Duplicate"
	max_health = maxi(1, hp)
	health = max_health
	_finish_setup()

func _build_visuals() -> void:
	# A gold-tinged, half-real echo of the bearer.
	var ghost := StandardMaterial3D.new()
	ghost.albedo_color = Color(0.85, 0.75, 0.4, 0.55)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.emission_enabled = true
	ghost.emission = Color(0.5, 0.42, 0.15)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.18
	body_mesh.height = 0.8
	body.mesh = body_mesh
	body.material_override = ghost
	body.position = Vector3(0, 0.5, 0)
	add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.13
	head_mesh.height = 0.26
	head.mesh = head_mesh
	head.material_override = ghost
	head.position = Vector3(0, 1.05, 0)
	add_child(head)
	_build_health_label(1.4, Color(0.9, 0.85, 0.6))
