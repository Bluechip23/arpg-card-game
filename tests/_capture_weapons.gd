extends SceneTree

## Dev helper: one figure per held weapon kind, all swinging at once, captured
## mid-swing so each weapon layer / pose can be eyeballed.
##   ... --script tests/_capture_weapons.gd -- <out.png> [character]

const KINDS := ["none", "sword", "axe", "hammer", "dagger", "spear", "bow", "wand", "shield"]
var _figs: Array = []
var _out := "/tmp/weapons.png"
var _char := "Ryan"
var _t := 0.0
var _phase := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_char = args[1]
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
	for i in range(KIND_COUNT()):
		var fig := SpriteFigure.new()
		root3d.add_child(fig)
		fig.setup(_char)
		fig.position.x = float(i) * 2.0
		var kind: String = KINDS[i]
		fig.set_weapon_kind("sword" if kind == "shield" else kind, kind == "shield")
		_figs.append(fig)
		var lbl := Label3D.new()
		lbl.text = kind
		lbl.font_size = 40
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(fig.position.x, -0.3, 1.2)
		root3d.add_child(lbl)
	var focus := Vector3(float(KINDS.size() - 1), 0, 0.3)
	CameraView.apply(cam, focus, 2.0, get_root().get_visible_rect().size.y)

func KIND_COUNT() -> int:
	return KINDS.size()

func _process(delta: float) -> bool:
	_t += delta
	if _phase == 0 and _t > 0.3:
		_phase = 1
		_t = 0.0
		for i in range(_figs.size()):
			var action := "shield_slam" if KINDS[i] == "shield" else "attack_slash"
			_figs[i].play_action(action, CharacterAnimator.Direction.EAST)
	elif _phase == 1 and _t > 0.2:
		get_root().get_texture().get_image().save_png(_out)
		print("[capture] saved %s" % _out)
		quit()
		return true
	return false
