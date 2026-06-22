extends SceneTree

## Dev helper: render Stephen performing one archer card animation to a PNG,
## captured on a chosen frame so we catch the signature pose.
##   ... --script tests/_capture_archer.gd -- <out.png> <action> <capture_frame>

var _fig: CharacterFigure = null
var _action := "bow_shot"
var _grab := 0.25  # seconds into the animation to capture the signature pose
var _out := "/tmp/archer.png"
var _settle := 0.0
var _action_t := -1.0
var _done := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_action = args[1]
	if args.size() > 2:
		_grab = float(args[2])

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
	pm.size = Vector2(8, 8)
	ground.mesh = pm
	ground.material_override = StandardMaterial3D.new()
	(ground.material_override as StandardMaterial3D).albedo_color = Color(0.18, 0.2, 0.22)
	root3d.add_child(ground)

	_fig = CharacterFigure.new()
	root3d.add_child(_fig)
	_fig.setup("Stephen", "res://assets/characters/stephen_south.png")

	var cam := Camera3D.new()
	root3d.add_child(cam)
	# 3/4 view from the figure's right-front so the bow (right side) is visible.
	cam.look_at_from_position(Vector3(1.5, 1.15, 2.5), Vector3(0, 0.75, 0), Vector3.UP)
	cam.current = true

func _process(d: float) -> bool:
	if _done:
		return true
	# Let the rig settle briefly, then kick the action.
	_settle += d
	if _settle >= 0.1 and _action_t < 0.0:
		_action_t = 0.0
		_fig.play_action(_action, CharacterAnimator.Direction.SOUTH)
		return false
	if _action_t >= 0.0:
		_action_t += d
		# Capture once accumulated animation time reaches the target pose.
		# (Tweens advance by the same per-frame delta, so this matches progress.)
		if _action_t >= _grab:
			get_root().get_texture().get_image().save_png(_out)
			print("[capture] %s  (%s @ %.2fs)" % [_out, _action, _grab])
			_done = true
			quit()
	return false
