extends SceneTree

## Dev helper: a hero walking for real in the outdoor start, the frame shown
## logged every frame (run with --fixed-fps 60 so a frame is 1/60 s).
##   godot --path . --fixed-fps 60 --script tests/_capture_walk_seq.gd -- <out_dir> <Hero> <mode> [zoom] [snap]
## mode "path": a four-tile click-move each way; "wasd": a held key (through
## the scene's own input) for the same distance. Prints one line a frame:
## frame, moving, walking, the column shown, the figure's offset y. With
## snap = 1 it also saves a crop round the hero each frame.

var _main: Node = null
var _dir := "/tmp/walk_seq"
var _who := "Brad"
var _mode := "path"
var _zoom := 2.0
var _snap := false
var _n := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _dir = args[0]
	if args.size() > 1: _who = args[1]
	if args.size() > 2: _mode = args[2]
	if args.size() > 3: _zoom = float(args[3])
	if args.size() > 4: _snap = args[4] == "1"
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

func _log(tag: String) -> void:
	var fig: SpriteFigure = _main.player._figure
	var col := -1
	if not fig._frames.is_empty():
		col = int(fig._frames[fig._frame_i].get("col", -1))
	print("[walk] %s %s f%04d moving=%d walking=%d facing=%d col=%d offy=%.1f pos=(%.2f,%.2f)" % [
		_who, tag, _n, int(_main.player.is_moving), int(fig._walking), fig.facing, col,
		fig._npc_sprite.offset.y, _main.player.position.x, _main.player.position.z])
	if _snap:
		var sv: SubViewport = _main._world_viewport
		var img: Image = sv.get_texture().get_image()
		var cam: Camera3D = _main.get_world_camera()
		var p: Vector2 = cam.unproject_position(_main.player.position)
		var w := int(60 * _zoom)
		var up := int(120 * _zoom)
		var r := Rect2i(int(p.x) - w, int(p.y) - up, 2 * w, up + int(20 * _zoom))
		r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.get_region(r).save_png("%s/%s_%s_%04d.png" % [_dir, _who.to_lower(), tag, _n])
	_n += 1

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
	await _frames(10)
	print("[walk] state: physics=%s paused=%s pmode=%d main_physics=%s target=%s pos=%s" % [_main.player.is_physics_processing(), paused, _main.player.process_mode, _main.is_physics_processing(), _main.player.target_position, _main.player.position])
	var gm = _main.grid_manager
	# key, (dx, dz) in cells: D east, A west, S south, W north
	var legs := [[KEY_D, Vector2i(1, 0), "E"], [KEY_S, Vector2i(0, 1), "S"], [KEY_A, Vector2i(-1, 0), "W"], [KEY_W, Vector2i(0, -1), "N"]]
	for leg in legs:
		var tag: String = leg[2]
		if _mode == "path":
			var cell: Vector2i = gm.world_to_grid(_main.player.position) + (leg[1] as Vector2i) * 4
			var ok: bool = _main.player.move_to_grid(gm.grid_to_world(cell), 4)
			print("[walk] %s %s move_to_grid ok=%s" % [_who, tag, ok])
			var t := 0
			while (_main.player.is_moving or t < 2) and t < 240:
				await process_frame
				_log(tag)
				t += 1
		else:
			var start: Vector3 = _main.player.position
			var ev := InputEventKey.new()
			ev.keycode = leg[0]
			ev.physical_keycode = leg[0]
			ev.pressed = true
			Input.parse_input_event(ev)
			var t := 0
			while t < 240:
				await process_frame
				_log(tag)
				t += 1
				if (_main.player.position - start).length() >= 3.9 and not _main.player.is_moving:
					break
			var up: InputEventKey = ev.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
		await _frames(10)
		_log(tag + "_rest")
	quit()
