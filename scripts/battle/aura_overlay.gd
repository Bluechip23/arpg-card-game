class_name AuraOverlay
extends Node3D

## The squares an enemy's standing effect reaches (a totem's burn, shock,
## heal, blast or drag; the Necromancer's Raise the Fallen), laid on the
## floor while the inspect box shows that enemy (designer, 2026-11-07).
## Reach is in grid steps, the way the effects measure it, so the area is
## the diamond of squares around the enemy's own.

const TILE_ALPHA := 0.28
const EDGE_ALPHA := 0.55

var _enemy: Enemy = null
var _cell := Vector2i(-9999, -9999)
var _key: Array = []

## Lay the enemy's zones down (or clear them when it has none).
func show_for(enemy: Enemy) -> void:
	_enemy = enemy
	_key = []
	refresh()

func clear() -> void:
	_enemy = null
	_key = []
	for c in get_children():
		remove_child(c)
		c.queue_free()
	visible = false

## Follow the enemy (a totem stands still; the Necromancer walks).
func refresh() -> void:
	if _enemy == null or not is_instance_valid(_enemy) or _enemy.is_dead or _enemy.grid_manager == null:
		clear()
		return
	var zones: Array = _enemy.aura_zones()
	var gm = _enemy.grid_manager
	var cell: Vector2i = gm.world_to_grid(_enemy.position)
	var key := [cell, zones.size()]
	for z in zones:
		key.append(int(z["reach"]))
	if key == _key:
		return
	_key = key
	_cell = cell
	for c in get_children():
		remove_child(c)
		c.queue_free()
	visible = not zones.is_empty()
	# Widest first, so a smaller zone draws over a larger one.
	zones.sort_custom(func(a, b): return int(a["reach"]) > int(b["reach"]))
	var y := _enemy.global_position.y
	for z in zones:
		var reach := int(z["reach"])
		var col: Color = z["color"]
		for dx in range(-reach, reach + 1):
			var span := reach - absi(dx)
			for dz in range(-span, span + 1):
				var c := cell + Vector2i(dx, dz)
				if c.x < 0 or c.y < 0 or c.x >= gm.grid_width or c.y >= gm.grid_height:
					continue
				var edge := absi(dx) + absi(dz) == reach
				_add_tile(gm.grid_to_world(c), y, col, EDGE_ALPHA if edge else TILE_ALPHA)

func _add_tile(at: Vector3, y: float, col: Color, alpha: float) -> void:
	var tile := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.92, 0.92)
	tile.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	tile.material_override = mat
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tile)
	tile.global_position = Vector3(at.x, y + 0.04, at.z)
