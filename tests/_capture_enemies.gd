extends SceneTree

## Dev helper: line up the four EnemyFigure models (skeleton, rat, archer_rat,
## armored_troll) and render them to a PNG. Run under xvfb + software GL.
##   ... --script tests/_capture_enemies.gd -- <out.png> [idle|walk|attack]

var _frames := 0
var _figs: Array = []

func _initialize() -> void:
	var root3d := Node3D.new()
	get_root().add_child(root3d)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 28, 0)
	key.light_energy = 1.2
	root3d.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12, -40, 0)
	fill.light_energy = 0.45
	root3d.add_child(fill)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.14, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.42, 0.48)
	env.ambient_light_energy = 0.5
	we.environment = env
	root3d.add_child(we)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 6)
	ground.mesh = pm
	ground.material_override = StandardMaterial3D.new()
	(ground.material_override as StandardMaterial3D).albedo_color = Color(0.18, 0.2, 0.22)
	root3d.add_child(ground)

	var args0 := OS.get_cmdline_user_args()
	var solo := ""
	if args0.size() > 2:
		solo = args0[2]

	var cam := Camera3D.new()
	root3d.add_child(cam)

	if solo != "":
		# Single figure, close 3/4 view.
		var f := EnemyFigure.new()
		root3d.add_child(f)
		f.setup(solo)
		_figs.append(f)
		cam.position = Vector3(0.9, 1.0, 2.3)
		cam.look_at(Vector3(0, 0.6, 0), Vector3.UP)
	else:
		var kinds := ["skeleton", "rat", "archer_rat", "armored_troll"]
		var x := -2.25
		for k in kinds:
			var f := EnemyFigure.new()
			f.position = Vector3(x, 0, 0)
			root3d.add_child(f)
			f.setup(k)
			_figs.append(f)
			x += 1.5
		cam.position = Vector3(0, 0.95, 3.35)
		cam.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	cam.current = true

func _process(_d: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	var mode := "idle"
	if args.size() > 1:
		mode = args[1]
	if _frames == 18:
		for f in _figs:
			if mode == "walk":
				f.set_walking(true)
			elif mode == "attack":
				f.play_action("attack")
	if _frames == 30:
		var out := "/tmp/enemies.png"
		if args.size() > 0:
			out = args[0]
		get_root().get_texture().get_image().save_png(out)
		print("[capture] " + out)
		quit()
	return false
