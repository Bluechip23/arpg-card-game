extends SceneTree
## Dev helper: a shield-holder walking, then blocking, then idle — the shield
## should only appear on the block.
var _figs: Array = []
var _out := "/tmp/guard.png"
var _t := 0.0
var _phase := 0
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.14, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.ambient_light_energy = 1.0
	we.environment = env
	root3d.add_child(we)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	var labels := ["walking", "block", "idle", "walking (Brad)", "block (Brad)", "idle (Brad)"]
	for i in range(6):
		var fig := SpriteFigure.new()
		root3d.add_child(fig)
		fig.setup("Ryan" if i < 3 else "Brad")
		fig.position.x = float(i) * 2.0
		fig.set_weapon_kind("sword", true)
		_figs.append(fig)
		var lbl := Label3D.new()
		lbl.text = labels[i]
		lbl.font_size = 36
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(fig.position.x, -0.3, 1.2)
		root3d.add_child(lbl)
	CameraView.apply(cam, Vector3(5.0, 0, 0.3), 2.0, get_root().get_visible_rect().size.y)
func _process(delta: float) -> bool:
	_t += delta
	if _phase == 0 and _t > 0.3:
		_phase = 1
		_t = 0.0
		for i in [0, 3]:
			_figs[i].set_walking(true)
			_figs[i].set_facing(CharacterAnimator.Direction.EAST)
		for i in [1, 4]:
			_figs[i].play_action("block", CharacterAnimator.Direction.EAST)
		for i in [2, 5]:
			_figs[i].set_facing(CharacterAnimator.Direction.EAST)
	elif _phase == 1 and _t > 0.2:
		get_root().get_texture().get_image().save_png(_out)
		print("[capture] saved %s" % _out)
		quit()
		return true
	return false
