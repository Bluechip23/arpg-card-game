class_name GridManager
extends Node3D

## Manages the visual grid and grid-based calculations in 3D space.
## Each grid cell is 1x1 world unit. The grid lies on the XZ plane at Y=0.

@export var grid_size: float = 1.0  # Size of each grid cell in world units
@export var grid_color: Color = Color(0.05, 0.08, 0.04, 0.16)  # subtle dark furrow lines

var grid_width: int = 20   # Number of cells wide (X axis)
var grid_height: int = 12  # Number of cells deep (Z axis)

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	_draw_grid()

func redraw_grid() -> void:
	## Rebuilds the grid lines after dimensions have changed.
	if _mesh_instance and is_instance_valid(_mesh_instance):
		_mesh_instance.queue_free()
		_mesh_instance = null
	_draw_grid()

func _draw_grid() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)

	var mesh = ImmediateMesh.new()
	_mesh_instance.mesh = mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = grid_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.material_override = mat

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# Short cross-ticks at cell corners instead of continuous ruled lines —
	# reads as subtle field marks, not a modern vector grid.
	var t := grid_size * 0.12
	for x in range(grid_width + 1):
		for z in range(grid_height + 1):
			var cx := x * grid_size
			var cz := z * grid_size
			mesh.surface_add_vertex(Vector3(cx - t, 0.01, cz))
			mesh.surface_add_vertex(Vector3(cx + t, 0.01, cz))
			mesh.surface_add_vertex(Vector3(cx, 0.01, cz - t))
			mesh.surface_add_vertex(Vector3(cx, 0.01, cz + t))
	mesh.surface_end()

func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / grid_size),
		floori(world_pos.z / grid_size)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	# Returns center of the grid cell on the ground plane (Y=0)
	return Vector3(
		grid_pos.x * grid_size + grid_size / 2.0,
		0.0,
		grid_pos.y * grid_size + grid_size / 2.0
	)

func snap_to_grid(world_pos: Vector3) -> Vector3:
	var grid_pos = world_to_grid(world_pos)
	return grid_to_world(grid_pos)

func get_distance_in_cells(from_pos: Vector3, to_pos: Vector3) -> int:
	var from_grid = world_to_grid(from_pos)
	var to_grid = world_to_grid(to_pos)
	# Manhattan distance (no diagonal movement)
	return absi(to_grid.x - from_grid.x) + absi(to_grid.y - from_grid.y)
