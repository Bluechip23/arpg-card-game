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
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.45, 0.45, 0.5)  # grey wolf
	fur.roughness = 1.0
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.18
	body_mesh.height = 0.7
	body.mesh = body_mesh
	body.material_override = fur
	body.rotation_degrees = Vector3(90, 0, 0)
	body.position = Vector3(0, 0.3, 0)
	add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.22, 0.2, 0.3)
	head.mesh = head_mesh
	head.material_override = fur
	head.position = Vector3(0, 0.42, -0.42)
	add_child(head)
	_build_health_label(1.1, Color(0.8, 0.8, 0.9))
