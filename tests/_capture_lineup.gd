extends SceneTree

## Dev helper: heroes and enemy figures side by side under the game's own
## camera (CameraView, plan view, 2 screen pixels per texel by default) on
## the dungeon's field-grass floor, so sizes and pixel density can be
## compared the way they are seen in play.
##   ... --script tests/_capture_lineup.gd -- <out.png> <item,item,...> [zoom]
## An item is a SpriteEnemyFigure kind, or "hero:<Name>" for a player figure;
## "|" starts a new row.

var _frames := 0
var _out := "/tmp/lineup.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var items: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	var zoom := float(args[2]) if args.size() > 2 else CameraView.ZOOM_DEFAULT

	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.1, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	env.environment = e
	root.add_child(env)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 24)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/craftpix/floor_grass_field.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)   # 128 px over 4 tiles: 32 texels a tile, as in the dungeon
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = mat
	root.add_child(ground)

	var x := 0.0
	var z := 0.0
	var row_items: Array = []
	for it in items:
		if it == "|":
			z += 3.2
			x = 0.0
			continue
		var node: Node3D
		if it.begins_with("hero:"):
			var f := SpriteFigure.new()
			root.add_child(f)
			f.setup(it.substr(5))
			node = f
		else:
			if not SpriteEnemyFigure.supports(it):
				continue
			var g := SpriteEnemyFigure.new()
			root.add_child(g)
			g.setup(it)
			node = g
		node.position = Vector3(x, CameraView.SPRITE_LIFT, z)
		var label := Label3D.new()
		label.text = it.replace("hero:", "")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.006
		label.font_size = 28
		label.position = Vector3(x, 0.5, z + 0.55)
		root.add_child(label)
		x += 2.0
		_widest = maxf(_widest, x - 2.0)

	_cam = Camera3D.new()
	root.add_child(_cam)
	_cam.current = true
	_focus = Vector3(_widest / 2.0, 0, z / 2.0 - 0.6)
	_zoom = zoom

var _cam: Camera3D = null
var _focus := Vector3.ZERO
var _zoom := 2.0
var _widest := 0.0

func _process(_d: float) -> bool:
	_frames += 1
	# The window has its real size by now: frame it at `zoom` px per texel.
	CameraView.apply(_cam, _focus, _zoom, float(DisplayServer.window_get_size().y))
	if _frames >= 25:
		get_root().get_texture().get_image().save_png(_out)
		print("[capture] " + _out)
		quit()
	return false
