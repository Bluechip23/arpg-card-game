class_name SummonedRat
extends Node3D

## A rat summoned by the Infestation card (roguelike only).
##
## Behaviour (driven by main.gd on every tempo tick):
##  - Scurries 1 grid square toward the nearest enemy each tempo.
##  - When it reaches contact (adjacent to an enemy) it lunges: deals 2 damage
##    and dies.
##  - Only has 3 health, so enemies can swat it before it ever connects.
##
## This node owns its visuals, health and movement animation only. The decision
## of when to move / lunge lives in main.gd (which has full battlefield context).

signal died(rat: SummonedRat)

const MAX_HEALTH := 3
const CONTACT_DAMAGE := 2

var health: int = MAX_HEALTH
var grid_manager: GridManager = null
var is_dead: bool = false

var _target_position: Vector3 = Vector3.ZERO
var _is_moving: bool = false
var _mesh: MeshInstance3D = null
var _health_label: Label3D = null

func setup(gm: GridManager, spawn_pos: Vector3) -> void:
	grid_manager = gm
	position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	_target_position = position
	_build_visuals()
	_update_health_label()

func _build_visuals() -> void:
	_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.35, 0.25, 0.5)
	_mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.4, 0.38)  # ratty grey-brown
	_mesh.material_override = mat
	_mesh.position = Vector3(0, 0.18, 0)
	add_child(_mesh)

	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 28
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, 0.55, 0)
	_health_label.modulate = Color(0.9, 0.9, 0.7)
	add_child(_health_label)

func _update_health_label() -> void:
	if _health_label:
		_health_label.text = "Rat %d/%d" % [max(health, 0), MAX_HEALTH]

func _process(delta: float) -> void:
	if not _is_moving:
		return
	position.x = move_toward(position.x, _target_position.x, 4.0 * delta)
	position.z = move_toward(position.z, _target_position.z, 4.0 * delta)
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

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	_update_health_label()
	if health <= 0:
		die()
	else:
		_flash(Color(1.0, 0.4, 0.4))

func _flash(color: Color) -> void:
	if not _mesh:
		return
	var mat := _mesh.material_override as StandardMaterial3D
	if not mat:
		return
	var original := mat.albedo_color
	mat.albedo_color = color
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", original, 0.25)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	queue_free()
