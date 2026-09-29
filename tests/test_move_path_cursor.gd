extends SceneTree

## Movement hover feedback: the route preview a right-click would order
## (Player.preview_path_cells) and the ground cursor that draws it
## (MovePathCursor — corner brackets on the target, a dot per path tile).
## Run: godot --headless --path . --script tests/test_move_path_cursor.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Move path cursor test ===")
	await _run()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

class FakeEnemy extends Node3D:
	var dest: Vector2i
	func intended_cell() -> Vector2i:
		return dest

class FakeSpawner extends Node:
	var enemies: Array = []
	var players: Array = []
	func get_living_enemies() -> Array:
		return enemies

func _run() -> void:
	var holder := Node3D.new()
	get_root().add_child(holder)
	var gm := GridManager.new()
	holder.add_child(gm)
	var player: Player = load("res://scenes/character/player.tscn").instantiate()
	holder.add_child(player)
	await process_frame  # let _ready wire up the stat / debuff / buff managers
	player.set_grid_manager(gm)
	player.position = gm.grid_to_world(Vector2i(2, 2))
	player.target_position = player.position

	# --- preview_path_cells mirrors what move_to_grid would walk ---
	var open_target := gm.grid_to_world(Vector2i(2, 5))
	var route := player.preview_path_cells(open_target, 3)
	var straight: Array[Vector2i] = [Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)]
	_check(route == straight,
		"open ground: route is the three tiles up to the target (got %s)" % [route])
	_check(not player.is_moving, "previewing never starts a move")

	_check(player.preview_path_cells(player.position, 0).is_empty(),
		"the tile the player stands on previews as no route")

	# A wall between the player and the target: a budget smaller than the
	# detour cuts the route, while the whole-route budget a right-click
	# grants (main's ROUTE_BUDGET) walks the detour all the way there.
	var wall: Array[Vector2i] = []
	for z in range(0, 4):
		wall.append(Vector2i(4, z))
	player.blocked_tiles = wall
	var far_target := gm.grid_to_world(Vector2i(6, 2))
	var budget := gm.get_distance_in_cells(player.position, far_target)
	route = player.preview_path_cells(far_target, budget)
	_check(route.size() == budget, "walled route is cut to a short budget (%d tiles)" % budget)
	_check(route[route.size() - 1] != Vector2i(6, 2), "…and so stops short of the target")
	for c in route:
		_check(c not in wall, "route never crosses the wall (%s)" % [c])
	route = player.preview_path_cells(far_target, 100000)
	_check(route.size() > budget, "the whole-route budget takes the detour (%d tiles)" % route.size())
	_check(route[route.size() - 1] == Vector2i(6, 2), "…and reaches the clicked tile")
	player.blocked_tiles = []

	# An enemy on the target: the route ends one tile short, like the move would.
	var spawner := FakeSpawner.new()
	holder.add_child(spawner)
	var rat := FakeEnemy.new()
	holder.add_child(rat)
	rat.position = gm.grid_to_world(Vector2i(5, 2))
	rat.dest = Vector2i(5, 2)
	spawner.enemies = [rat]
	player.enemy_spawner = spawner
	route = player.preview_path_cells(gm.grid_to_world(Vector2i(5, 2)), 3)
	var before_rat: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2)]
	_check(route == before_rat,
		"route aimed at an enemy stops on the tile before it (got %s)" % [route])
	_check(player.move_path.is_empty(), "previewing leaves the live move path untouched")
	player.enemy_spawner = null

	# Rooted: nothing to walk.
	player.debuff_manager.apply_debuff(Debuff.create(Debuff.DebuffType.ROOTED, 0, 2))
	_check(player.preview_path_cells(open_target, 3).is_empty(), "a rooted character previews no route")
	player.debuff_manager.clear_all_debuffs()

	# --- the cursor itself ---
	var cursor := MovePathCursor.new()
	cursor.grid_manager = gm
	var lifted := {"cells": []}
	cursor.ground_y_provider = func(world_pos: Vector3) -> float:
		lifted["cells"].append(gm.world_to_grid(world_pos))
		return 2.0 if gm.world_to_grid(world_pos) == Vector2i(2, 5) else 0.0
	holder.add_child(cursor)
	await process_frame
	_check(not cursor.visible, "cursor starts hidden")

	var full: Array[Vector2i] = [Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5)]
	cursor.show_path(Vector2i(2, 5), full)
	_check(cursor.visible, "show_path makes the cursor visible")
	_check(cursor.reachable, "a route ending on the target is reachable (gold)")
	_check(cursor.route == full, "cursor remembers the route it is drawing")
	var mesh: ImmediateMesh = cursor._mesh_instance.mesh
	_check(mesh != null and mesh.get_surface_count() == 1, "cursor built one triangle surface")
	var verts: int = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	# 2 dots (destination gets brackets, not a dot) × 8 tris × 3 verts
	# + 4 corners × 2 arms × 6 verts
	_check(verts == 2 * MovePathCursor.DOT_SEGMENTS * 3 + 4 * 2 * 6,
		"two path dots plus four corner brackets (%d verts)" % verts)
	_check(Vector2i(2, 5) in lifted["cells"] and Vector2i(2, 3) in lifted["cells"],
		"marks sample terrain height per cell")
	var max_y := -INF
	for v in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		max_y = maxf(max_y, v.y)
	_check(absf(max_y - (2.0 + MovePathCursor.LIFT)) < 0.001,
		"brackets on a raised tile sit on top of it (max y %.3f)" % max_y)

	var same_mesh := mesh
	cursor.show_path(Vector2i(2, 5), full)
	_check(cursor._mesh_instance.mesh == same_mesh, "an unchanged preview does not rebuild the mesh")

	var short: Array[Vector2i] = [Vector2i(2, 3)]
	cursor.show_path(Vector2i(2, 5), short)
	_check(not cursor.reachable, "a route that stops short flags the target as blocked (red)")
	_check(cursor._mesh_instance.mesh != same_mesh, "a changed preview rebuilds the mesh")
	verts = cursor._mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	_check(verts == 1 * MovePathCursor.DOT_SEGMENTS * 3 + 4 * 2 * 6,
		"every walked tile gets a dot when the route stops short (%d verts)" % verts)

	cursor.show_path(Vector2i(2, 5), [] as Array[Vector2i])
	_check(not cursor.reachable, "no route at all still brackets the target, in red")

	cursor.hide_cursor()
	_check(not cursor.visible and cursor.route.is_empty(), "hide_cursor clears the preview")

	holder.queue_free()
	await process_frame
