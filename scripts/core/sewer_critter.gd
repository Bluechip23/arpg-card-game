class_name SewerCritter
extends Node3D

## A tiny background critter — a sewer mouse — that scuttles between random points
## near its spawn. Purely atmospheric: no collision, no health, the player never
## interacts with it. It just makes the sewers feel inhabited.

var _home: Vector3
var _target: Vector3
var _speed: float = 1.7
var _roam: float = 3.5
var _pause: float = 0.0
var _rng := RandomNumberGenerator.new()
var _bob_t: float = 0.0
var _body: MeshInstance3D

func setup(home: Vector3, seed_val: int) -> void:
	_home = home
	position = home
	_target = home
	_rng.seed = seed_val
	_phase_offset()
	_build()
	_pick_target()

func _phase_offset() -> void:
	# Stagger critters so they don't all move in lockstep.
	_bob_t = _rng.randf() * TAU
	_speed = _rng.randf_range(1.3, 2.2)
	_roam = _rng.randf_range(2.5, 4.5)

func _build() -> void:
	var fur = Color(0.17, 0.15, 0.13)
	_body = MeshInstance3D.new()
	var body_mesh = SphereMesh.new()
	body_mesh.radius = 0.09
	body_mesh.height = 0.18
	body_mesh.radial_segments = 6
	body_mesh.rings = 4
	_body.mesh = body_mesh
	_body.scale = Vector3(0.8, 0.65, 1.7)  # long little rodent body
	var mat = StandardMaterial3D.new()
	mat.albedo_color = fur
	mat.roughness = 1.0
	_body.material_override = mat
	_body.position.y = 0.07
	add_child(_body)

	# Thin tail trailing behind.
	var tail = MeshInstance3D.new()
	var tail_mesh = CylinderMesh.new()
	tail_mesh.top_radius = 0.005
	tail_mesh.bottom_radius = 0.02
	tail_mesh.height = 0.22
	tail_mesh.radial_segments = 4
	tail.mesh = tail_mesh
	tail.rotation_degrees = Vector3(90, 0, 0)
	tail.position = Vector3(0, 0.06, -0.18)
	tail.material_override = mat
	add_child(tail)

func _pick_target() -> void:
	var a = _rng.randf() * TAU
	var r = _rng.randf() * _roam
	_target = _home + Vector3(cos(a) * r, 0.0, sin(a) * r)
	_pause = _rng.randf_range(0.2, 1.5)

func _process(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	var to = _target - position
	to.y = 0.0
	var d = to.length()
	if d < 0.12:
		_pick_target()
		return
	var dir = to / d
	position += dir * _speed * delta
	rotation.y = atan2(dir.x, dir.z)
	# Subtle scurry bob.
	_bob_t += delta * 18.0
	if _body:
		_body.position.y = 0.07 + absf(sin(_bob_t)) * 0.02
