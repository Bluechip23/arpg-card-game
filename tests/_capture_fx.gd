extends SceneTree

## Dev helper: the designer's imported spell effects (fireball, ice spike,
## searing fire, phoenix, lightning) played under the game's own camera on
## the field-grass floor, beside a hero and two of the new board creatures,
## so their look can be judged against the figures they share the screen
## with. One effect per run, captured `seconds` after it fires.
##   ... --script tests/_capture_fx.gd -- <out.png> <effect> <seconds> [zoom]
## effect: fireball | cryonics | surrounding_ice | searing_fire | phoenix |
##         thunder | arc | crackle

var _frames := 0
var _out := "/tmp/fx.png"
var _effect := "fireball"
var _secs := 0.3
var _zoom := 2.5
var _root: Node3D
var _hero: Node3D
var _foe: Node3D
var _cam: Camera3D
var _fired_at := -1.0
var _t := 0.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _effect = args[1]
	if args.size() > 2: _secs = float(args[2])
	if args.size() > 3: _zoom = float(args[3])
	_root = Node3D.new()
	get_root().add_child(_root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.1, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	env.environment = e
	_root.add_child(env)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 24)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/ground/field_grass.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = mat
	_root.add_child(ground)
	var hero := SpriteFigure.new()
	_root.add_child(hero)
	hero.setup("Brad")
	hero.position = Vector3(0, CameraView.SPRITE_LIFT, 0)
	_hero = hero
	var foe := SpriteEnemyFigure.new()
	_root.add_child(foe)
	foe.setup("fire_goblin_mage")
	foe.position = Vector3(4, CameraView.SPRITE_LIFT, 0)
	_foe = foe
	var z := SpriteEnemyFigure.new()
	_root.add_child(z)
	z.setup("zombie")
	z.position = Vector3(-2.5, CameraView.SPRITE_LIFT, 0)
	_cam = Camera3D.new()
	_root.add_child(_cam)
	_cam.current = true

func _fire() -> void:
	var a := Vector3(0, 0, 0)
	var b := Vector3(4, 0, 0)
	match _effect:
		"fireball": FireballFX.play(_root, a + Vector3(0, 0.6, 0), b + Vector3(0, 0.6, 0))
		"cryonics": CryonicsIceFX.encase(_hero)
		"surrounding_ice":
			var g := GridManager.new()
			_root.add_child(g)
			SurroundingIceFX.play(_root, g, a, 1.6)
		"searing_fire": SearingFireFX.play(_root, a, Vector3(1, 0, 0), 3.0)
		"phoenix": PhoenixRise.play(_hero)
		"thunder": LightningFX.thunder(_root, b)
		"arc": LightningFX.arc(_root, a, b)
		"crackle": LightningFX.crackle(_root, b)

func _process(d: float) -> bool:
	_frames += 1
	_t += d
	CameraView.apply(_cam, Vector3(1.0, 0, -0.6), _zoom, float(DisplayServer.window_get_size().y))
	if _frames == 10:
		_fire()
		_fired_at = _t
	if _fired_at >= 0.0 and _t - _fired_at >= _secs:
		get_root().get_texture().get_image().save_png(_out)
		print("[capture] " + _out)
		quit()
	return false
