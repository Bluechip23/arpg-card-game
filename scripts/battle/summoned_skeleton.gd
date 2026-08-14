extends Node3D

## Skeleton raised by the Sack of Bone Arrows (on-self: a kill made with a
## card slotted in the quiver).
##
## Stat block (per the item): max health = 50% of the enemy whose death raised
## it, hits for 5, moves 4 spaces every tempo, attacks every 5 tempo. Lives
## until killed (or the battle ends); at most 3 stand at once.
##
## This node owns visuals/health/movement; main.gd drives per-tempo decisions
## (_update_skeletons) via the cadence accumulators.

signal died(skeleton)

const BASE_ATTACK := 5      # bone-arrow skeletons hit for 5
const MOVE_INTERVAL := 1    # tempo between moves
const MOVE_STEPS := 4       # tiles per move
const ATTACK_INTERVAL := 5  # tempo between attacks

var max_health: int = 10
var health: int = 10
var grid_manager: GridManager = null
var is_dead: bool = false
var move_accum: int = 0
var attack_accum: int = 0

var _target_position: Vector3 = Vector3.ZERO
var _is_moving: bool = false
var _health_label: Label3D = null

func setup(gm: GridManager, spawn_pos: Vector3, hp: int) -> void:
	grid_manager = gm
	position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	_target_position = position
	max_health = maxi(1, hp)
	health = max_health
	_build_visuals()
	_update_health_label()

func _build_visuals() -> void:
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.88, 0.86, 0.76)  # dry bone
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
	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 24
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, 1.25, 0)
	_health_label.modulate = Color(0.85, 0.9, 0.8)
	WorldText.crisp(_health_label)
	add_child(_health_label)

func _update_health_label() -> void:
	if _health_label:
		_health_label.text = "Skeleton %d/%d" % [max(health, 0), max_health]

func _process(delta: float) -> void:
	if not _is_moving:
		return
	position.x = move_toward(position.x, _target_position.x, 4.5 * delta)
	position.z = move_toward(position.z, _target_position.z, 4.5 * delta)
	if abs(position.x - _target_position.x) < 0.01 and abs(position.z - _target_position.z) < 0.01:
		position.x = _target_position.x
		position.z = _target_position.z
		_is_moving = false

func get_cell() -> Vector2i:
	if grid_manager:
		return grid_manager.world_to_grid(position)
	return Vector2i.ZERO

func move_to_cell(cell: Vector2i) -> void:
	if not grid_manager or is_dead:
		return
	var world = grid_manager.grid_to_world(cell)
	_target_position = Vector3(world.x, 0.0, world.z)
	_is_moving = true

func get_health_percent() -> float:
	return float(health) / float(max_health) if max_health > 0 else 0.0

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = min(max_health, health + amount)
	_update_health_label()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	_update_health_label()
	if health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	queue_free()
