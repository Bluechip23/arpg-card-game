extends SceneTree

## Dev helper: every frame of a hero's drawn action, facing each way, in the
## real battle scene (the outdoor start, the game's own world viewport and
## camera at a given zoom) — the pixels the player sees, frame by frame.
##   godot --path . --rendering-driver opengl3 --script tests/_capture_action_frames.gd -- <out_dir> <Hero> <action> [zoom]
## Writes <out_dir>/<hero>_<dir>_<action>_<frame>.png crops round the hero.

var _main: Node = null
var _dir := "/tmp/action_frames"
var _who := "Cory"
var _action := "basic_attack"
var _zoom := 4.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _dir = args[0]
	if args.size() > 1: _who = args[1]
	if args.size() > 2: _action = args[2]
	if args.size() > 3: _zoom = float(args[3])
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", _make_char(_who))
	get_root().add_child(_main)
	_run.call_deferred()

func _make_char(who: String) -> CharacterData:
	match who:
		"Ryan": return CharacterData.create_ryan()
		"Jeremy": return CharacterData.create_jeremy()
		"Stephen": return CharacterData.create_stephen()
		"Brad": return CharacterData.create_brad()
		_: return CharacterData.create_cory()

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _run() -> void:
	await _frames(40)
	# Close every opening dialog (each may queue the next) until the scene
	# has run unpaused for half a second.
	var calm := 0
	var guard := 0
	while calm < 30 and guard < 2000:
		guard += 1
		if _main.olorin and _main.olorin.is_busy():
			_main.olorin._close()
			calm = 0
		elif paused:
			paused = false
			calm = 0
		else:
			calm += 1
		await process_frame
	_main._camera_distance = _zoom
	_main._update_camera()
	await _frames(5)
	Engine.time_scale = 0.0001   # every frame is picked by hand
	for n in get_root().find_children("*", "BlobShadow", true, false):
		n.visible = false
	var fig: SpriteFigure = _main.player._figure
	var D := CharacterAnimator.Direction
	var dirs := {"S": D.SOUTH, "N": D.NORTH, "E": D.EAST, "W": D.WEST}
	for dn in dirs:
		var d: int = dirs[dn]
		fig.set_facing(d)
		fig._play("idle", true)
		await _snap("%s_idle" % dn)
		if not fig.has_drawn_action(_action, d):
			continue
		fig.play_action(_action, d)
		var n: int = int(fig._actions[_action]["frames"])
		for k in n:
			fig._frame_i = k
			fig._apply_frame()
			await _snap("%s_%s_%02d" % [dn, _action, k])
		fig._play("idle", true)
	quit()

func _snap(name: String) -> void:
	await _frames(3)
	var img: Image = _main._world_viewport.get_texture().get_image()
	var cam: Camera3D = _main.get_world_camera()
	var p: Vector2 = cam.unproject_position(_main.player.position)
	var w := int(36 * _zoom)
	var up := int(80 * _zoom)
	var down := int(10 * _zoom)
	var r := Rect2i(int(p.x) - w, int(p.y) - up, 2 * w, up + down)
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(r).save_png("%s/%s_%s.png" % [_dir, _who.to_lower(), name])
