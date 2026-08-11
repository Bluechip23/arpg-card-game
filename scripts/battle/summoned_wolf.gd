extends Node3D

## Wolf summoned by Gauntlets of Dungeon Mastering (on-self: slotted card play).
##
## Stat block (per the item): 20 HP, attacks every 5 tempo, moves 2 spaces every
## 3 tempo, attacks apply bleed. Wolfpack: each OTHER friendly wolf grants +20%
## attack damage and +1 bleed (computed by main at attack time).
##
## This node owns visuals/health/movement; main.gd drives per-tempo decisions
## (_update_wolves) via the cadence accumulators.

signal died(wolf)

const BASE_ATTACK := 5      # confirmed: wolves hit for 5 before pack bonuses
const MOVE_INTERVAL := 3    # tempo between moves
const MOVE_STEPS := 2       # tiles per move
const ATTACK_INTERVAL := 5  # tempo between attacks

var max_health: int = 20
var health: int = 20
var grid_manager: GridManager = null
var is_dead: bool = false
var move_accum: int = 0
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
	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 24
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, 1.1, 0)
	_health_label.modulate = Color(0.8, 0.8, 0.9)
	WorldText.crisp(_health_label)
	add_child(_health_label)

func _update_health_label() -> void:
	if _health_label:
		_health_label.text = "Wolf %d/%d" % [max(health, 0), max_health]

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
