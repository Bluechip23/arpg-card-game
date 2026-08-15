extends Node3D

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

signal died(clone)

const MOVE_INTERVAL := 3    # tempo between moves
const MOVE_STEPS := 2       # tiles per move
const ATTACK_INTERVAL := 7  # tempo between attacks

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
	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 24
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, 1.4, 0)
	_health_label.modulate = Color(0.9, 0.85, 0.6)
	WorldText.crisp(_health_label)
	add_child(_health_label)

func _update_health_label() -> void:
	if _health_label:
		_health_label.text = "Duplicate %d/%d" % [max(health, 0), max_health]

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
