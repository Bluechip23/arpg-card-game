extends Node3D

## Frankensteins Monster — summoned by the "ITS ALIVE!!!!!" card granted by
## Frankensteins Screws (helm). A corpse is stitched back together into a
## lumbering ally that hunts the nearest enemy.
##
## Stat block (per the item), all scaling off the summoner's INT at spawn:
##   HP        = 50 + INT * 0.8
##   attack    = 10 + INT * 0.25   (every 5 tempo, when adjacent)
##   movement  = 4 spaces every 8 tempo
##   resist    = 5 + INT / 10  (%) against ALL incoming damage
##
## This node owns visuals/health/movement animation; main.gd drives the
## per-tempo decisions (_update_frankensteins) using the cadence counters.

signal died(monster)

var max_health: int = 50
var health: int = 50
var attack_damage: int = 10
var resist_percent: float = 5.0

var grid_manager: GridManager = null
var is_dead: bool = false

# Cadence accumulators (tempo banked toward the next move / attack).
var move_accum: int = 0
var attack_accum: int = 0
const MOVE_INTERVAL := 8      # tempo between moves
const MOVE_STEPS := 4         # tiles per move
const ATTACK_INTERVAL := 5    # tempo between attacks

var _target_position: Vector3 = Vector3.ZERO
var _is_moving: bool = false
var _body: Node3D = null
var _health_label: Label3D = null

func setup(gm: GridManager, spawn_pos: Vector3, summoner_int: int) -> void:
	grid_manager = gm
	position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	_target_position = position
	max_health = 50 + int(summoner_int * 0.8)
	health = max_health
	attack_damage = 10 + int(summoner_int * 0.25)
	resist_percent = 5.0 + summoner_int / 10.0
	_build_visuals()
	_update_health_label()

func _build_visuals() -> void:
	_body = Node3D.new()
	add_child(_body)
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.45, 0.6, 0.4)  # stitched green
	flesh.roughness = 1.0
	# Torso
	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.55, 0.8, 0.4)
	torso.mesh = torso_mesh
	torso.material_override = flesh
	torso.position = Vector3(0, 0.7, 0)
	_body.add_child(torso)
	# Head
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.4, 0.4, 0.4)
	head.mesh = head_mesh
	head.material_override = flesh
	head.position = Vector3(0, 1.32, 0)
	_body.add_child(head)
	# Neck bolts
	var bolt_mat := StandardMaterial3D.new()
	bolt_mat.albedo_color = Color(0.7, 0.7, 0.5)
	bolt_mat.metallic = 0.8
	for sx in [-1.0, 1.0]:
		var bolt := MeshInstance3D.new()
		var bolt_mesh := CylinderMesh.new()
		bolt_mesh.top_radius = 0.06
		bolt_mesh.bottom_radius = 0.06
		bolt_mesh.height = 0.18
		bolt.mesh = bolt_mesh
		bolt.material_override = bolt_mat
		bolt.rotation_degrees = Vector3(0, 0, 90)
		bolt.position = Vector3(0.22 * sx, 1.1, 0)
		_body.add_child(bolt)

	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 28
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, 1.9, 0)
	_health_label.modulate = Color(0.6, 0.9, 0.6)
	WorldText.crisp(_health_label)
	add_child(_health_label)

func _update_health_label() -> void:
	if _health_label:
		_health_label.text = "Frankensteins Monster %d/%d" % [max(health, 0), max_health]

func _process(delta: float) -> void:
	if not _is_moving:
		return
	position.x = move_toward(position.x, _target_position.x, 3.0 * delta)
	position.z = move_toward(position.z, _target_position.z, 3.0 * delta)
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
	if max_health <= 0:
		return 0.0
	return float(health) / float(max_health)

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	health = min(max_health, health + amount)
	_update_health_label()

func take_damage(amount: int) -> void:
	if is_dead:
		return
	# Resist everything: reduce the incoming amount by resist_percent.
	var reduced := maxi(1, floori(amount * (1.0 - minf(resist_percent, 90.0) / 100.0)))
	health -= reduced
	_update_health_label()
	if health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	queue_free()
