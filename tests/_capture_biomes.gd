extends SceneTree

## Dev helper: build each location (no UI, no enemies), lift the fog, and
## shoot it through the fixed game camera (CameraView) so the terrain fills,
## walls, water and prop dressing can be eyeballed per biome.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --script tests/_capture_biomes.gd -- <out_dir>

const CONFIGS := [
	{"level": 1, "interior": "", "name": "world1_field"},
	{"level": 1, "interior": "forest_0", "name": "forest"},
	{"level": 1, "interior": "cave_0", "name": "cave"},
	{"level": 2, "interior": "", "name": "world2_desert"},
	{"level": 3, "interior": "", "name": "world3_winter"},
	{"level": 4, "interior": "", "name": "world4_cursed"},
	{"level": 5, "interior": "", "name": "world5_undead"},
	{"level": 1, "interior": "building_0", "name": "building"},
	{"level": 1, "interior": "sewer_0", "name": "sewer"},
]

var _out := "/tmp/biomes"
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
	# Lift the fog of war: hide whatever draws the fog MultiMesh.
	_hide_fog(parent)
	_cam = Camera3D.new()
	_holder.add_child(_cam)
	var start: Vector2i = _dm.player_start
	# Look a little way into the map from the start so walls, trails and
	# props all land in frame.
	var focus := Vector3(start.x + 6.0, 0, start.y)
	CameraView.apply(_cam, focus, 2.0, 720.0)
	_cam.current = true
	_frames = 0


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
