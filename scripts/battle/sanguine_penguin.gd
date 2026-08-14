extends Node3D

## Sanguine the blood penguin (Nine Ruins of Sanguine): summoned at 9 Vitality.
##
## Stat block (per the item): 50 HP, stays within 1 square of the wielder
## ("mimics your moves"), melee attacks for 8 every 5 tempo. He can be hit —
## friendly fire included — and every point of damage HE takes heals the
## wielder for half. While he lives, the dagger gains no Vitality.
##
## This node owns visuals/health/movement; main.gd drives per-tempo decisions
## (_update_penguin) and routes his heal-on-hurt to the player.

signal died(penguin)
signal hurt(amount)  # damage he absorbed — main heals the wielder for half

const BASE_ATTACK := 8      # per the spec: 8 damage every 5 tempo
const ATTACK_INTERVAL := 5  # tempo between attacks

var max_health: int = 50
var health: int = 50
var grid_manager: GridManager = null
var is_dead: bool = false
var attack_accum: int = 0

var _target_position: Vector3 = Vector3.ZERO
var _is_moving: bool = false
var _health_label: Label3D = null

func setup(gm: GridManager, spawn_pos: Vector3) -> void:
	grid_manager = gm
	position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	_target_position = position
	_build_visuals()
	_update_health_label()

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
	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 24
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, 1.05, 0)
	_health_label.modulate = Color(0.9, 0.5, 0.5)
	WorldText.crisp(_health_label)
	add_child(_health_label)

func _update_health_label() -> void:
	if _health_label:
		_health_label.text = "Sanguine %d/%d" % [max(health, 0), max_health]

func _process(delta: float) -> void:
	if not _is_moving:
		return
	position.x = move_toward(position.x, _target_position.x, 5.0 * delta)
	position.z = move_toward(position.z, _target_position.z, 5.0 * delta)
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
	if is_dead or amount <= 0:
		return
	var absorbed: int = mini(amount, health)
	health -= amount
	_update_health_label()
	hurt.emit(absorbed)  # the wielder drinks half of what Sanguine bleeds
	if health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	queue_free()
