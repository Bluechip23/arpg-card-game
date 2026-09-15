class_name MovePathCursor
extends Node3D

## Ground-plane movement cursor. Four corner brackets frame the grid cell
## under the mouse, and a dot sits in the middle of every cell the player
## would walk through to get there — the exact route a right-click orders.
##
## The scene feeds it the destination cell and the previewed route each
## frame (see Player.preview_path_cells); the mesh is only rebuilt when
## either changes. Marks follow terrain height through ground_y_provider.

const PATH_COLOR := Color8(249, 220, 62, 235)     # Palette GOLD_1
const BLOCKED_COLOR := Color8(224, 105, 105, 225)  # Palette BLOOD_1

const LIFT := 0.035           # Sit above the field marks so nothing z-fights
const BRACKET_LEN := 0.26     # Arm length of each corner bracket, in cells
const BRACKET_WIDTH := 0.075  # Arm thickness, in cells
const BRACKET_INSET := 0.05   # Pull the corners in so neighbouring cells stay clear
const DOT_RADIUS := 0.11      # Path dot radius, in cells
const DOT_SEGMENTS := 8       # Octagon: reads as a dot, stays crisp at 16-bit scale
const PULSE_SPEED := 3.0      # Radians per second of the alpha breath
const PULSE_DEPTH := 0.22     # How far the alpha dips at the bottom of the breath

var grid_manager: GridManager = null
var ground_y_provider: Callable = Callable()  # world_pos -> ground Y (optional)

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _base_color: Color = PATH_COLOR
var _cache_key: String = ""
var _pulse_t: float = 0.0

# Last preview shown — readable by tests and by anything that wants to know
# what the cursor is currently saying.
var target_cell: Vector2i = Vector2i(-1, -1)
var route: Array[Vector2i] = []
var reachable: bool = false

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = true
	_mesh_instance.material_override = _material
	# Start hidden so nothing flashes at the origin before the first hover
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	# A slow breath on the alpha so the cursor reads as live feedback, not a
	# painted decal. Colour itself never changes mid-breath.
	_pulse_t += delta * PULSE_SPEED
	var breath := 1.0 - PULSE_DEPTH * (0.5 - 0.5 * cos(_pulse_t))
	var c := _base_color
	c.a = _base_color.a * breath
	_material.albedo_color = c

func show_path(cell: Vector2i, path_cells: Array[Vector2i]) -> void:
	## Bracket `cell` and dot every tile of `path_cells` (the route, start
	## tile excluded, in walking order). A route that stops short of the cell
	## — walls, an occupied tile, a rooted character — turns the bracket red so
	## the player sees the order would not land where the mouse is.
	if grid_manager == null:
		return
	var reaches: bool = not path_cells.is_empty() and path_cells[path_cells.size() - 1] == cell
	var key := "%s|%s|%s" % [cell, path_cells, reaches]
	if key != _cache_key:
		_cache_key = key
		target_cell = cell
		route = path_cells.duplicate()
		reachable = reaches
		_base_color = PATH_COLOR if reaches else BLOCKED_COLOR
		_rebuild_mesh()
	if not visible:
		_pulse_t = 0.0
		_material.albedo_color = _base_color
		visible = true

func hide_cursor() -> void:
	if not visible:
		return
	visible = false
	_cache_key = ""
	target_cell = Vector2i(-1, -1)
	route = []
	reachable = false

func _cell_y(cell: Vector2i) -> float:
	## Ground height at the middle of `cell`, so marks ride pillars and steps.
	if ground_y_provider.is_valid():
		return float(ground_y_provider.call(grid_manager.grid_to_world(cell))) + LIFT
	return LIFT

func _rebuild_mesh() -> void:
	var mesh := ImmediateMesh.new()
	_mesh_instance.mesh = mesh
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	# Path dots: one per tile walked, skipping the destination itself — the
	# bracket already marks where the route ends.
	for cell in route:
		if cell == target_cell:
			continue
		_add_dot(mesh, cell)

	_add_brackets(mesh, target_cell)
	mesh.surface_end()

func _add_dot(mesh: ImmediateMesh, cell: Vector2i) -> void:
	var c := grid_manager.grid_to_world(cell)
	c.y = _cell_y(cell)
	var r := DOT_RADIUS * grid_manager.grid_size
	for i in range(DOT_SEGMENTS):
		var a0 := TAU * i / DOT_SEGMENTS
		var a1 := TAU * (i + 1) / DOT_SEGMENTS
		mesh.surface_add_vertex(c)
		mesh.surface_add_vertex(c + Vector3(cos(a0) * r, 0.0, sin(a0) * r))
		mesh.surface_add_vertex(c + Vector3(cos(a1) * r, 0.0, sin(a1) * r))

func _add_brackets(mesh: ImmediateMesh, cell: Vector2i) -> void:
	## An L at each of the cell's four corners, arms running along the edges.
	var s := grid_manager.grid_size
	var y := _cell_y(cell)
	var x0 := cell.x * s
	var z0 := cell.y * s
	var inset := BRACKET_INSET * s
	var arm := BRACKET_LEN * s
	var thick := BRACKET_WIDTH * s
	# (corner x, corner z, direction into the cell along x, along z)
	for corner in [
			[x0, z0, 1.0, 1.0],
			[x0 + s, z0, -1.0, 1.0],
			[x0, z0 + s, 1.0, -1.0],
			[x0 + s, z0 + s, -1.0, -1.0]]:
		var cx: float = corner[0]
		var cz: float = corner[1]
		var dx: float = corner[2]
		var dz: float = corner[3]
		# Arm along X
		_add_rect(mesh, y,
			cx + dx * inset, cz + dz * inset,
			cx + dx * (inset + arm), cz + dz * (inset + thick))
		# Arm along Z
		_add_rect(mesh, y,
			cx + dx * inset, cz + dz * inset,
			cx + dx * (inset + thick), cz + dz * (inset + arm))

func _add_rect(mesh: ImmediateMesh, y: float, xa: float, za: float, xb: float, zb: float) -> void:
	## Axis-aligned rectangle on the ground plane between two opposite corners.
	var a := Vector3(xa, y, za)
	var b := Vector3(xb, y, za)
	var c := Vector3(xb, y, zb)
	var d := Vector3(xa, y, zb)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_add_vertex(c)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(c)
	mesh.surface_add_vertex(d)
