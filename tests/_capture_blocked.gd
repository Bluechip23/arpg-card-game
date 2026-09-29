extends SceneTree

## Dev helper: build a location, lift the fog, and overlay every blocked
## tile — red for walls beside floor, orange for scenery obstacles, blue
## for pits — so the drawn walls can be checked against what the
## pathfinder refuses. Shoots the area around the player start at the
## game's zoom.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --script tests/_capture_blocked.gd -- <out_dir>

const CONFIGS := [
	{"level": 1, "interior": "", "name": "world1_field", "zoom": 1.0},
	{"level": 1, "interior": "", "name": "world1_field_far", "zoom": 1.6},
	{"level": 1, "interior": "cave_0", "name": "cave", "zoom": 1.0},
	{"level": 1, "interior": "forest_0", "name": "forest", "zoom": 1.0},
	{"level": 1, "interior": "sewer_0", "name": "sewer", "zoom": 1.0},
]

var _out := "/tmp/blocked"
var _idx := -1
var _frames := 0
var _holder: Node3D = null
var _cam: Camera3D = null
var _dm = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_next()


func _next() -> void:
	if _holder:
		_holder.queue_free()
	_idx += 1
	if _idx >= CONFIGS.size():
		quit(0)
		return
	var cfg: Dictionary = CONFIGS[_idx]
	_holder = Node3D.new()
	get_root().add_child(_holder)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color8(26, 28, 20)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.47, 0.42)
	e.ambient_light_energy = 1.0
	env.environment = e
	_holder.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = false
	_holder.add_child(light)
	var gm := GridManager.new()
	_holder.add_child(gm)
	var parent := Node3D.new()
	_holder.add_child(parent)
	_dm = DungeonManager.new()
	_holder.add_child(_dm)
	_dm.initialize(gm, parent, cfg["level"], cfg["interior"])
	_hide_fog(parent)
	_overlay()
	_cam = Camera3D.new()
	_holder.add_child(_cam)
	var start: Vector2i = _dm.player_start
	var focus := Vector3(start.x + 6.0, 0, start.y)
	CameraView.apply(_cam, focus, float(cfg["zoom"]), 720.0)
	_cam.current = true
	_frames = 0


func _overlay() -> void:
	var walls: Array = _dm.get_wall_tiles()
	var floor_lookup := {}
	for x in range(_dm.GRID_W):
		for z in range(_dm.GRID_H):
			if _dm.is_floor(Vector2i(x, z)):
				floor_lookup[Vector2i(x, z)] = true
	for w in walls:
		var beside := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if floor_lookup.has(w + d):
				beside = true
		if beside:
			_mark(w, Color(1, 0.1, 0.1, 0.35))
	for o in _dm.get_obstacle_tiles():
		_mark(o, Color(1, 0.6, 0.0, 0.55))
	for p in _dm.pit_tiles.keys():
		_mark(p, Color(0.2, 0.4, 1.0, 0.55))


func _mark(cell: Vector2i, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.02, 0.8)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Vector3(cell.x + 0.5, 0.35, cell.y + 0.5)
	_holder.add_child(mi)


func _hide_fog(node: Node) -> void:
	for c in node.get_children():
		if c is MultiMeshInstance3D and c.multimesh == _dm._fog_mm:
			c.visible = false
		_hide_fog(c)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 6:
		var path := "%s/%s.png" % [_out, CONFIGS[_idx]["name"]]
		get_root().get_texture().get_image().save_png(path)
		print("[capture] " + path)
		_next()
	return false
