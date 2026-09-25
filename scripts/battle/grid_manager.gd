class_name GridManager
extends Node3D

## Manages the visual grid and grid-based calculations in 3D space.
## Each grid cell is 1x1 world unit. The grid lies on the XZ plane at Y=0.

@export var grid_size: float = 1.0  # Size of each grid cell in world units
@export var grid_color: Color = Color(0.03, 0.03, 0.02, 0.22)  # dark edge of each cell line — a thin tinted stroke
@export var grid_light: Color = Color(1.0, 1.0, 0.92, 0.07)  # faint light edge, just enough to read on dark cobbles

var grid_width: int = 20   # Number of cells wide (X axis)
var grid_height: int = 12  # Number of cells deep (Z axis)

## Optional: Callable(Vector2i) -> float giving each cell's floor height, so
## the lines ride up onto elevated terrain instead of hiding under it.
var cell_height: Callable = Callable()

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
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.material_override = mat

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# Continuous cell lines so the player can read exactly which square a
	# chest, doorway or enemy sits on. Each line is a light stroke with a
	# dark stroke one texel beside it, so it reads on grass, sand and dark
	# cobbles alike. Drawn a hair above the floor; walls and cliffs (0.06+
	# slabs) cover the lines under them.
	const LIFT := 0.02  # above floor overlays (+0.004 tiles), under wall slabs (0.06)
	if cell_height.is_valid():
		# Per-cell edges at that cell's own height (north + west edge each,
		# plus the closing south/east edges on the last row/column).
		for x in range(grid_width):
			for z in range(grid_height):
				var y: float = float(cell_height.call(Vector2i(x, z))) + LIFT
				var x0 := x * grid_size
				var z0 := z * grid_size
				_line(mesh, Vector3(x0, y, z0), Vector3(x0 + grid_size, y, z0))
				_line(mesh, Vector3(x0, y, z0), Vector3(x0, y, z0 + grid_size))
				if x == grid_width - 1:
					_line(mesh, Vector3(x0 + grid_size, y, z0), Vector3(x0 + grid_size, y, z0 + grid_size))
				if z == grid_height - 1:
					_line(mesh, Vector3(x0, y, z0 + grid_size), Vector3(x0 + grid_size, y, z0 + grid_size))
	else:
		var w := grid_width * grid_size
		var d := grid_height * grid_size
		for x in range(grid_width + 1):
			var cx := x * grid_size
			_line(mesh, Vector3(cx, LIFT, 0), Vector3(cx, LIFT, d))
		for z in range(grid_height + 1):
			var cz := z * grid_size
			_line(mesh, Vector3(0, LIFT, cz), Vector3(w, LIFT, cz))
	mesh.surface_end()

func _line(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	## One grid edge: light stroke on the edge, dark stroke one texel to the
	## south / east of it.
	const TEXEL := 1.0 / 32.0
	var off := Vector3(TEXEL, 0, 0) if is_equal_approx(a.x, b.x) else Vector3(0, 0, TEXEL)
	mesh.surface_set_color(grid_light)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_set_color(grid_color)
	mesh.surface_add_vertex(a + off)
	mesh.surface_add_vertex(b + off)

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
