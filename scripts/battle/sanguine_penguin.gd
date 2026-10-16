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
	# A squat crimson-and-white penguin: blood-dark back, pale belly, tiny beak.
	var back := StandardMaterial3D.new()
	back.albedo_color = Color(0.45, 0.10, 0.14)  # dried-blood plumage
	back.roughness = 1.0
	var belly := StandardMaterial3D.new()
	belly.albedo_color = Color(0.92, 0.88, 0.86)
	belly.roughness = 1.0
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.2
	body_mesh.height = 0.62
	body.mesh = body_mesh
	body.material_override = back
	body.position = Vector3(0, 0.34, 0)
	add_child(body)
	var front := MeshInstance3D.new()
	var front_mesh := CapsuleMesh.new()
	front_mesh.radius = 0.14
	front_mesh.height = 0.46
	front.mesh = front_mesh
	front.material_override = belly
	front.position = Vector3(0, 0.30, -0.09)
	add_child(front)
	var beak := MeshInstance3D.new()
	var beak_mesh := CylinderMesh.new()
	beak_mesh.top_radius = 0.0
	beak_mesh.bottom_radius = 0.05
	beak_mesh.height = 0.14
	beak.mesh = beak_mesh
	var beak_mat := StandardMaterial3D.new()
	beak_mat.albedo_color = Color(0.9, 0.6, 0.15)
	beak.material_override = beak_mat
	beak.rotation_degrees = Vector3(90, 0, 0)
	beak.position = Vector3(0, 0.56, -0.24)
	add_child(beak)
	_build_health_label(1.05, Color(0.9, 0.5, 0.5))

func _after_hit(dealt: int, health_before: int) -> void:
	hurt.emit(mini(dealt, health_before))  # the wielder drinks half of what Sanguine bleeds
