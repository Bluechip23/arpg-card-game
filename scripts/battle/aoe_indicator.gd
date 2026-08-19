class_name AOEIndicator
extends Node3D

## Visual indicator for AOE effects rendered on the ground plane (Y=0)

var shape: String = "cone"  # "cone", "circle", "line"
var aoe_range: float = 2.0  # In world units (grid cells)
var cone_angle: float = 60.0  # degrees for cone
var color: Color = Color(1, 0.4, 0.8, 0.3)  # Pink with transparency

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D

## Stores the mouse world position (XZ plane), updated from main.gd
var mouse_world_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = true
	_mesh_instance.material_override = _material
	# Start hidden so the indicator doesn't flash at origin (0,0,0) / upper-left
	visible = false

func _rebuild_mesh() -> void:
	match shape:
		"cone":
			_build_cone_mesh()
		"circle":
			_build_circle_mesh()
		"line":
			_build_line_mesh()

func _build_cone_mesh() -> void:
	var mesh = ImmediateMesh.new()
	_mesh_instance.mesh = mesh

	var local_mouse = mouse_world_pos - global_position
	var dir = Vector3(local_mouse.x, 0, local_mouse.z).normalized()
	if dir.length() < 0.01:
		dir = Vector3(0, 0, -1)
	var angle = atan2(dir.x, -dir.z)  # angle on XZ plane

	var half_angle = deg_to_rad(cone_angle / 2.0)
	var segments = 16

	var center = Vector3(0, 0.02, 0)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 = angle - half_angle + (half_angle * 2.0 * i / segments)
		var a1 = angle - half_angle + (half_angle * 2.0 * (i + 1) / segments)
		mesh.surface_add_vertex(center)
		mesh.surface_add_vertex(Vector3(sin(a0) * aoe_range, 0.02, -cos(a0) * aoe_range))
		mesh.surface_add_vertex(Vector3(sin(a1) * aoe_range, 0.02, -cos(a1) * aoe_range))
	mesh.surface_end()

func _build_circle_mesh() -> void:
	var mesh = ImmediateMesh.new()
	_mesh_instance.mesh = mesh

	var segments = 32
	var center = Vector3(0, 0.02, 0)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a0 = TAU * i / segments
		var a1 = TAU * (i + 1) / segments
		mesh.surface_add_vertex(center)
		mesh.surface_add_vertex(Vector3(cos(a0) * aoe_range, 0.02, sin(a0) * aoe_range))
		mesh.surface_add_vertex(Vector3(cos(a1) * aoe_range, 0.02, sin(a1) * aoe_range))
	mesh.surface_end()

func _build_line_mesh() -> void:
	var mesh = ImmediateMesh.new()
	_mesh_instance.mesh = mesh

	var local_mouse = mouse_world_pos - global_position
	var dir = Vector3(local_mouse.x, 0, local_mouse.z).normalized()
	if dir.length() < 0.01:
		dir = Vector3(0, 0, -1)
	var end_pos = dir * aoe_range
	var perp = Vector3(-dir.z, 0, dir.x) * 0.3  # Line width

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	mesh.surface_add_vertex(Vector3(-perp.x, 0.02, -perp.z))
	mesh.surface_add_vertex(Vector3(perp.x, 0.02, perp.z))
	mesh.surface_add_vertex(Vector3(end_pos.x - perp.x, 0.02, end_pos.z - perp.z))
	mesh.surface_add_vertex(Vector3(end_pos.x + perp.x, 0.02, end_pos.z + perp.z))
	mesh.surface_end()

func update_indicator(new_shape: String, new_range: float) -> void:
	shape = new_shape
	aoe_range = new_range
	_rebuild_mesh()

func show_indicator() -> void:
	# Only show if position has been set (not at origin/upper-left)
	if global_position.length() < 0.01 and mouse_world_pos.length() < 0.01:
		return
	visible = true
	_rebuild_mesh()

func hide_indicator() -> void:
	visible = false

func _process(delta: float) -> void:
	if visible:
		_rebuild_mesh()
		_refresh_rng_tiles()

func set_mouse_world_position(pos: Vector3) -> void:
	mouse_world_pos = pos

# ============================================
# PER-ENEMY CHANCE TILES (green = hit, red = miss)
# ============================================

var _rng_card: Card = null
var _rng_enemies: Array = []
var _rng_tiles: Dictionary = {}  # enemy instance id -> MeshInstance3D

func update_enemy_rng_indicators(enemies: Array, card: Card) -> void:
	## While a chance AOE card is selected, tile each enemy inside the shape
	## green or red for its PRE-ROLLED outcome (card.get_rng_outcome), so the
	## preview always matches what resolves when the card is played.
	_rng_enemies = enemies
	_rng_card = card if (card != null and card.chance_effect_percent > 0.0) else null
	_refresh_rng_tiles()

func _refresh_rng_tiles() -> void:
	var wanted := {}
	if visible and _rng_card != null:
		for enemy in _rng_enemies:
			if is_instance_valid(enemy) and not enemy.is_dead and _is_enemy_in_aoe(enemy):
				wanted[enemy.get_instance_id()] = enemy
	for id in wanted:
		var tile: MeshInstance3D = _rng_tiles.get(id)
		if tile == null:
			tile = _make_rng_tile()
			_rng_tiles[id] = tile
		var enemy = wanted[id]
		tile.visible = true
		tile.global_position = Vector3(enemy.global_position.x, 0.03, enemy.global_position.z)
		var mat := tile.material_override as StandardMaterial3D
		mat.albedo_color = Color(0.15, 0.9, 0.25, 0.45) if _rng_card.get_rng_outcome(enemy) \
			else Color(0.95, 0.12, 0.1, 0.45)
	for id in _rng_tiles:
		if not wanted.has(id):
			_rng_tiles[id].visible = false

func _make_rng_tile() -> MeshInstance3D:
	var tile := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9, 0.9)  # slightly inside a 1.0 grid cell
	tile.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	tile.material_override = mat
	add_child(tile)  # inherits the indicator's visibility, so hide_indicator() hides tiles too
	return tile

func _is_enemy_in_aoe(enemy) -> bool:
	var diff = enemy.global_position - global_position
	var flat_diff = Vector3(diff.x, 0, diff.z)
	var distance = flat_diff.length()

	if distance > aoe_range:
		return false

	if shape == "cone":
		var local_mouse = mouse_world_pos - global_position
		var direction = Vector3(local_mouse.x, 0, local_mouse.z).normalized()
		var enemy_direction = flat_diff.normalized()
		if direction.length() < 0.01 or enemy_direction.length() < 0.01:
			return false
		var dot = direction.dot(enemy_direction)
		var angle_threshold = cos(deg_to_rad(cone_angle / 2.0))
		return dot >= angle_threshold

	if shape == "line":
		# Match the resolution corridor (get_enemies_in_line uses width 0.8):
		# inside the segment along the aim direction AND close enough sideways.
		var local_mouse = mouse_world_pos - global_position
		var dir = Vector3(local_mouse.x, 0, local_mouse.z).normalized()
		if dir.length() < 0.01:
			return false
		var along = flat_diff.dot(dir)
		if along < 0.0 or along > aoe_range:
			return false
		return (flat_diff - dir * along).length() <= 0.8

	return true  # Circle - just check range
