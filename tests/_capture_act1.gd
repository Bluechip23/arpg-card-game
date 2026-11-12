extends SceneTree

## Dev helper: boot one map of World 1 (the overworld or an interior), reveal
## it and save an overview and a few gameplay-angle close views.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script tests/_capture_act1.gd -- <interior_id|-> <out_prefix> [world]

var _main: Node = null
var _cam: Camera3D = null
var _frames := 0
var _prefix := "/tmp/act1"
var _interior := ""
var _spots: Array = []   # [{pos, name, h, back}]
var _shot := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "-":
		_interior = args[0]
	if args.size() > 1:
		_prefix = args[1]
	var world := 1
	if args.size() > 2:
		world = int(args[2])
	_main = load("res://scenes/core/main.tscn").instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_world_level", world)
	_main.set("current_interior_id", _interior)
	get_root().add_child(_main)
	_cam = Camera3D.new()
	get_root().add_child(_cam)

func _process(_delta: float) -> bool:
	_frames += 1
	if _main.get("olorin") and _main.olorin.is_busy():
		_main.olorin._close()
	_hide_ui()
	var dm = _main.get("dungeon_manager")
	if _spots.is_empty() and _frames > 10 and dm:
		for x in range(dm.GRID_W):
			for z in range(0, dm.GRID_H, 3):
				dm.reveal_around(Vector2i(x, z))
		var w: float = dm.GRID_W
		var h: float = dm.GRID_H
		var ppos: Vector3 = _main.player.global_position
		_spots = [{"pos": Vector3(w * 0.5, 0, h * 0.5), "name": "overview", "h": maxf(w, h) * 0.95, "back": maxf(w, h) * 0.55}]
		_spots.append({"pos": ppos, "name": "start", "h": 9.0, "back": 9.0})
		var i := 0
		for r in dm.rooms:
			if r["kind"] in ["deep", "stacks", "hall", "reading"] and i < 5:
				var c: Vector2i = (r["rect"] as Rect2i).get_center()
				_spots.append({"pos": Vector3(c.x + 0.5, 0, c.y + 0.5), "name": "%s_%d" % [r["kind"], i], "h": 9.0, "back": 9.0})
				i += 1
		for s in dm.site_nodes:
			if s["kind"] in ["library", "graveyard"]:
				var gp: Vector2i = s["grid_pos"]
				_spots.append({"pos": Vector3(gp.x + 0.5, 0, gp.y - 1.0), "name": "site_%s" % s["kind"], "h": 8.0, "back": 8.0})
				_spots.append({"cell": gp, "name": "game_site_%s" % s["kind"], "game": true})
		# Through the real game camera (UI shown), the hero at the door and in
		# the deepest room.
		_spots.append({"cell": dm.player_start, "name": "game_start", "game": true})
		for r in dm.rooms:
			if r["kind"] in ["deep", "stacks"] or r.get("lib", "") in ["stacks", "reading"]:
				var cc: Vector2i = dm.pick_free_cell_near((r["rect"] as Rect2i).get_center(), 3)
				if cc.x >= 0:
					_spots.append({"cell": cc, "name": "game_%s_%d" % [r.get("lib", r["kind"]), _spots.size()], "game": true})
	if not _spots.is_empty() and _shot < _spots.size():
		var s: Dictionary = _spots[_shot]
		if s.get("game", false):
			_cam.current = false
			var p: Vector3 = _main._ground_pos(s["cell"])
			_main.player.position = p
			_main.player.target_position = p
			_main._camera_focus = p
			_main._update_fog_of_war()
		else:
			var target: Vector3 = s["pos"]
			_cam.global_position = target + Vector3(0, s["h"], s["back"])
			_cam.look_at(target, Vector3.UP)
			_cam.far = 400.0
			_cam.current = true
	if _frames >= 80 and (_frames - 80) % 24 == 0 and _shot < _spots.size():
		var path: String = _prefix + "_%s.png" % _spots[_shot]["name"]
		get_root().get_texture().get_image().save_png(path)
		print("[capture] " + path)
		_shot += 1
		if _shot >= _spots.size():
			quit()
	if _frames > 1500:
		quit()
	return false

func _hide_ui() -> void:
	var game: bool = _shot < _spots.size() and _spots[_shot].get("game", false)
	for child in _main.get_children():
		if child is CanvasLayer:
			if not _ui_vis.has(child):
				_ui_vis[child] = child.visible
			child.visible = game and _ui_vis[child]

var _ui_vis := {}
