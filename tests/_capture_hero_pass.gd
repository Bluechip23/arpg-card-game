extends SceneTree

## Dev helper: the hero in a real battle scene (the outdoor start, the game's
## own low-res world viewport and camera at a given zoom), snapped standing,
## walking, attacking and blocking, facing each way — exactly the pixels the
## player sees, so the cut-outs are judged in a fight, not the Animation Lab.
##   godot --path . --rendering-driver opengl3 --script tests/_capture_hero_pass.gd -- <out_dir> <Hero> [zoom]
## Writes <out_dir>/<hero>_<dir>_<pose>.png crops round the hero.

var _main: Node = null
var _dir := "/tmp/hero_pass"
var _who := "Brad"
var _zoom := 2.0
var _frame := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _dir = args[0]
	if args.size() > 1: _who = args[1]
	if args.size() > 2: _zoom = float(args[2])
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
		"Cory": return CharacterData.create_cory()
		_: return CharacterData.create_brad()

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _run() -> void:
	await _frames(40)
	var guard := 0
	while _main.olorin and _main.olorin.is_busy() and guard < 20:
		_main.olorin._close()
		guard += 1
		await process_frame
	_main._camera_distance = _zoom
	_main._update_camera()
	await _frames(5)
	# Freeze the figure's own clocks: every frame is picked by hand.
	Engine.time_scale = 0.0001
	if OS.get_environment("NOSHADOW") == "1":
		for n in get_root().find_children("*", "BlobShadow", true, false):
			n.visible = false
	var fig: SpriteFigure = _main.player._figure
	var D := CharacterAnimator.Direction
	var dirs := {"S": D.SOUTH, "N": D.NORTH, "E": D.EAST, "W": D.WEST}
	for dn in dirs:
		var d: int = dirs[dn]
		fig.set_walking(false)
		fig.set_facing(d)
		fig._play("idle", true)
		await _snap("%s_idle" % dn)
		if fig._strides():
			fig.set_walking(true)
			fig.set_facing(d)
			fig._play("walk", true)
			for k in [1, 4, 6]:
				fig._frame_i = k
				fig._apply_frame()
				await _snap("%s_walk%d" % [dn, k])
			fig.set_walking(false)
		for action in ["basic_attack", "basic_block"]:
			if not fig.has_drawn_action(action, d):
				continue
			fig.play_action(action, d)
			var n: int = fig._frames.size()
			var a: Dictionary = fig._actions[action]
			var picks := [0, int(a.get("hit", int(a["frames"]) / 2)) - 1, int(a["frames"]) - 1]
			for k in picks:
				fig._frame_i = clampi(k, 0, n - 1)
				fig._apply_frame()
				await _snap("%s_%s%d" % [dn, action.trim_prefix("basic_"), k])
			fig._play("idle", true)
	quit()

func _snap(name: String) -> void:
	await _frames(3)
	var sv: SubViewport = _main._world_viewport
	var img: Image = sv.get_texture().get_image()
	var cam: Camera3D = _main.get_world_camera()
	var p: Vector2 = cam.unproject_position(_main.player.position)
	if name == "S_idle":
		print("[snap] img ", img.get_size(), " sv ", sv.size, " p ", p, " player ", _main.player.position, " fig ", _main.player._figure.global_position, " focus ", _main._camera_focus)
	var w := int(72 * _zoom)
	var up := int(130 * _zoom)
	var down := int(26 * _zoom)
	var r := Rect2i(int(p.x) - w, int(p.y) - up, 2 * w, up + down)
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(r).save_png("%s/%s_%s.png" % [_dir, _who.to_lower(), name])
