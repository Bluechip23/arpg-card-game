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
	var bone := StandardMaterial3D.new()
	match kind:
		"spirit":
			bone.albedo_color = Color(0.55, 0.75, 1.0, 0.6)  # ghostly blue
			bone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"golem":
			bone.albedo_color = Color(0.5, 0.44, 0.38)       # weathered stone
		_:
			bone.albedo_color = Color(0.88, 0.86, 0.76)      # dry bone
	bone.roughness = 1.0
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.14
	body_mesh.height = 0.65
	body.mesh = body_mesh
	body.material_override = bone
	body.position = Vector3(0, 0.45, 0)
	add_child(body)
	var skull := MeshInstance3D.new()
	var skull_mesh := BoxMesh.new()
	skull_mesh.size = Vector3(0.2, 0.2, 0.2)
	skull.mesh = skull_mesh
	skull.material_override = bone
	skull.position = Vector3(0, 0.9, 0)
	add_child(skull)
	var eyes := StandardMaterial3D.new()
	eyes.albedo_color = Color(0.2, 0.9, 0.5)
	eyes.emission_enabled = true
	eyes.emission = Color(0.2, 0.9, 0.5)
	for ex in [-0.05, 0.05]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.03
		eye_mesh.height = 0.06
		eye.mesh = eye_mesh
		eye.material_override = eyes
		eye.position = Vector3(ex, 0.92, -0.1)
		add_child(eye)
	_build_health_label(1.25, Color(0.85, 0.9, 0.8))
