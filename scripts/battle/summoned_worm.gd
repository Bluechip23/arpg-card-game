extends Node3D

## An Alaskan Bull Worm summoned by Worm's Armageddon (10% proc).
##
## Stat block (per the card): 12 HP, 6 damage, burrowed until it attacks,
## untargetable while burrowed, 1 movement per tempo.
##
## This node owns only visuals/health/movement animation;
## main.gd drives the per-tempo decisions (_update_summoned_worms).

signal died(worm)

const MAX_HEALTH := 12
const CONTACT_DAMAGE := 6

var health: int = MAX_HEALTH
var grid_manager: GridManager = null
var is_dead: bool = false
var burrowed: bool = true  # Untargetable until it surfaces to attack

var _target_position: Vector3 = Vector3.ZERO
var _is_moving: bool = false
var _mound: MeshInstance3D = null
var _body: Node3D = null
var _health_label: Label3D = null

func setup(gm: GridManager, spawn_pos: Vector3) -> void:
	grid_manager = gm
	position = Vector3(spawn_pos.x, 0.0, spawn_pos.z)
	_target_position = position
	_build_visuals()
	_update_health_label()

func _build_visuals() -> void:
	# Burrowed state: a low mound of churned earth.
	_mound = MeshInstance3D.new()
	var mound_mesh := SphereMesh.new()
	mound_mesh.radius = 0.32
	mound_mesh.height = 0.24
	_mound.mesh = mound_mesh
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.42, 0.30, 0.18)
	dirt.roughness = 1.0
	_mound.material_override = dirt
	_mound.position = Vector3(0, 0.08, 0)
	add_child(_mound)

	# Surfaced state: a pale segmented worm body (hidden until surface()).
	_body = Node3D.new()
	_body.visible = false
	add_child(_body)
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.85, 0.78, 0.86)
	for i in range(4):
		var seg := MeshInstance3D.new()
		var seg_mesh := SphereMesh.new()
		var r := 0.26 - i * 0.03
		seg_mesh.radius = r
		seg_mesh.height = r * 2.0
		seg.mesh = seg_mesh
		seg.material_override = pale
		seg.position = Vector3(0, 0.25 + i * 0.34, 0)
		_body.add_child(seg)
	# Simple mouth ring on the top segment.
	var mouth := MeshInstance3D.new()
	var mouth_mesh := TorusMesh.new()
	mouth_mesh.inner_radius = 0.07
	mouth_mesh.outer_radius = 0.15
	mouth.mesh = mouth_mesh
	var maw := StandardMaterial3D.new()
	maw.albedo_color = Color(0.55, 0.15, 0.2)
	mouth.material_override = maw
	mouth.position = Vector3(0, 0.25 + 3 * 0.34 + 0.17, 0)
	_body.add_child(mouth)

	_health_label = Label3D.new()
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 28
	_health_label.pixel_size = 0.005
	_health_label.position = Vector3(0, 1.7, 0)
	_health_label.modulate = Color(0.9, 0.85, 0.95)
	WorldText.crisp(_health_label)
	add_child(_health_label)

func surface() -> void:
	## The worm erupts from the ground to attack — from now on it is targetable.
	if not burrowed:
		return
	burrowed = false
	if _mound:
		_mound.visible = false
	if _body:
		_body.visible = true
	_update_health_label()

func _update_health_label() -> void:
	if _health_label:
		if burrowed:
			_health_label.text = "Worm (burrowed)"
		else:
			_health_label.text = "Worm %d/%d" % [max(health, 0), MAX_HEALTH]

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

func take_damage(amount: int) -> void:
	if is_dead or burrowed:
		return  # Untargetable while burrowed
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
