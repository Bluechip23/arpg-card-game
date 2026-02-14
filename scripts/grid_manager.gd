class_name GridManager
extends Node2D

## Manages the visual grid and grid-based calculations

@export var grid_size: int = 64  # Size of each grid cell in pixels
@export var grid_color: Color = Color(1, 1, 1, 0.1)
@export var grid_line_width: float = 1.0

var grid_width: int = 20  # Number of cells wide
var grid_height: int = 12  # Number of cells tall

func _ready() -> void:
	# Calculate grid dimensions based on screen size
	grid_width = ceili(1280.0 / grid_size)
	grid_height = ceili(720.0 / grid_size)

func _draw() -> void:
	# Draw vertical lines
	for x in range(grid_width + 1):
		var start = Vector2(x * grid_size, 0)
		var end = Vector2(x * grid_size, grid_height * grid_size)
		draw_line(start, end, grid_color, grid_line_width)
	
	# Draw horizontal lines
	for y in range(grid_height + 1):
		var start = Vector2(0, y * grid_size)
		var end = Vector2(grid_width * grid_size, y * grid_size)
		draw_line(start, end, grid_color, grid_line_width)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / grid_size),
		floori(world_pos.y / grid_size)
	)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	# Returns center of the grid cell
	return Vector2(
		grid_pos.x * grid_size + grid_size / 2.0,
		grid_pos.y * grid_size + grid_size / 2.0
	)

func snap_to_grid(world_pos: Vector2) -> Vector2:
	var grid_pos = world_to_grid(world_pos)
	return grid_to_world(grid_pos)

func get_distance_in_cells(from_pos: Vector2, to_pos: Vector2) -> int:
	var from_grid = world_to_grid(from_pos)
	var to_grid = world_to_grid(to_pos)
	# Manhattan distance (no diagonal movement)
	return absi(to_grid.x - from_grid.x) + absi(to_grid.y - from_grid.y)

func get_distance_diagonal(from_pos: Vector2, to_pos: Vector2) -> int:
	var from_grid = world_to_grid(from_pos)
	var to_grid = world_to_grid(to_pos)
	# Chebyshev distance (diagonal movement allowed)
	return maxi(absi(to_grid.x - from_grid.x), absi(to_grid.y - from_grid.y))
