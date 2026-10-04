extends SceneTree

## Dev helper: the four chaos-monster icon battlers beside the demon and
## cerberus battlers for a size check. Run under xvfb + software GL.
##   ... --script tests/_capture_chaos.gd -- <out.png>

var _frames := 0

func _initialize() -> void:
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.14, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 1.0
	we.environment = env
	root3d.add_child(we)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(16, 6)
	ground.mesh = pm
	ground.material_override = StandardMaterial3D.new()
	(ground.material_override as StandardMaterial3D).albedo_color = Color(0.18, 0.2, 0.22)
	root3d.add_child(ground)
	var kinds := ["succubus", "ifrit", "inflamed_minotaur", "ash_harpy", "demon", "cerberus", "vampire"]
	var x := -6.0
	for k in kinds:
		var f := SpriteEnemyFigure.new()
		f.position = Vector3(x, 0, 0)
		root3d.add_child(f)
		f.setup(k)
		f.set_facing(CharacterAnimator.Direction.WEST if x < 0.0 else CharacterAnimator.Direction.EAST)
		x += 2.0
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.position = Vector3(0, 2.6, 7.5)
	cam.look_at_from_position(cam.position, Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 30:
		var args := OS.get_cmdline_user_args()
		var out := "/tmp/chaos.png"
		if args.size() > 0:
			out = args[0]
		get_root().get_texture().get_image().save_png(out)
		print("[capture] " + out)
		quit()
	return false
