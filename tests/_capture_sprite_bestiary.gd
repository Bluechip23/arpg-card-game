extends SceneTree

## Dev helper: render rows of SpriteEnemyFigure kinds on a plain stage.
##   ... --script tests/_capture_sprite_bestiary.gd -- <out.png> <kind,kind,...>

var _frames := 0
var _out := "/tmp/sprite_bestiary.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var kinds: PackedStringArray = []
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		kinds = args[1].split(",")

	var root := Node3D.new()
	get_root().add_child(root)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.19, 0.15)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 1.0
	env.environment = e
	root.add_child(env)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 14)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.42, 0.3)
	mat.albedo_texture = load("res://assets/textures/tile_grass.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	ground.material_override = mat
	root.add_child(ground)

	var per_row := 6
	for i in range(kinds.size()):
		var kind := kinds[i]
		if not SpriteEnemyFigure.supports(kind):
			continue
		var fig := SpriteEnemyFigure.new()
		root.add_child(fig)
		fig.position = Vector3((i % per_row) * 2.6 - 6.5, 0, (i / per_row) * 3.4 - 3.2)
		fig.setup(kind)
		var label := Label3D.new()
		label.text = kind
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.008
		label.position = fig.position + Vector3(0, 2.3, 0.9)
		root.add_child(label)

	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 8.5, 9.5), Vector3(0, 0.6, 0), Vector3.UP)
	cam.current = true

func _process(_d: float) -> bool:
	_frames += 1
	if _frames >= 25:
		get_root().get_texture().get_image().save_png(_out)
		print("[capture] " + _out)
		quit()
	return false
