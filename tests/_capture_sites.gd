extends SceneTree

## Dev helper: a frame of every enterable site on a world's overworld (cave
## mouth, building, sewer grate, forest trail, graveyard, mountain path) and
## of the Transport Portal, the hero standing at each entrance:
## <out>_<site id>.png and <out>_portal.png. Optional second arg: the world.
## With a third arg (an interior id, e.g. mountains_0) it walks into that
## interior and saves full frames round it instead: <out>_in_<n>.png at the
## start, at each step up a cliff and at the summit, zoomed out.
## Run under xvfb + software GL like _capture_hud.gd:
##   ... --script tests/_capture_sites.gd -- /tmp/sites [world]

var _main = null
var _out := "/tmp/sites"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_main)
	_run.call_deferred()

## Travel and interiors rebuild the main scene: the live one.
func _live_main() -> Node:
	for c in get_root().get_children():
		if c.get_script() and "current_interior_id" in c and not c.is_queued_for_deletion():
			return c
	return null

func _shot(cell: Vector2i, tag: String, w := 640, h := 480) -> void:
	var p = _main.player
	var pos: Vector3 = _main.grid_manager.grid_to_world(cell)
	p.position = pos
	p.target_position = pos
	_main.dungeon_manager.reveal_around(cell) if _main.dungeon_manager.has_method("reveal_around") else null
	for _i in range(30):
		await process_frame
	p.position.y = _main._desired_ground_y(p.position)
	for _i in range(5):
		await process_frame
	var img: Image = _main._world_viewport.get_texture().get_image()
	var c: Vector2 = _main.get_world_camera().unproject_position(p.position)
	var r := Rect2i(int(c.x) - w / 2, int(c.y) - h * 2 / 3, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	var path := "%s_%s.png" % [_out, tag]
	img.get_region(r).save_png(path)
	print("saved ", path)

func _run() -> void:
	for _i in range(40):
		await process_frame
	var g := 0
	while _main.olorin and _main.olorin.is_busy() and g < 20:
		_main.olorin._close()
		g += 1
		await process_frame
	var a := OS.get_cmdline_user_args()
	if a.size() > 1 and int(a[1]) != _main.current_world_level:
		_main._travel_to_world(int(a[1]))
		for _i in range(60):
			await process_frame
		_main = _live_main()
	var dm = _main.dungeon_manager
	if a.size() > 2:
		_main._enter_interior(a[2], a[2])
		for _i in range(60):
			await process_frame
		_main = _live_main()
		dm = _main.dungeon_manager
		_main._camera_distance = 1.0
		for x in range(dm.GRID_W):
			for z in range(dm.GRID_H):
				dm.reveal_around(Vector2i(x, z)) if (x % 6 == 0 and z % 6 == 0) else null
		var spots: Array = [dm.player_start]
		var steps: Array = dm.step_tiles.keys()
		steps.sort()
		for k in range(0, steps.size(), maxi(1, steps.size() / 4)):
			spots.append(steps[k])
		for r in dm.rooms:
			if r["kind"] == "deep" and r.has("center"):
				spots.append(r["center"] + Vector2i(0, 2))
		for st in dm.site_nodes:
			if st["id"] != "exit":
				spots.append(st["grid_pos"] + Vector2i(0, 1))   # each door out of here
		if dm.troll_vault_chest_cell.x >= 0:
			spots.append(dm.troll_vault_entrance + Vector2i(-6, 3))   # the den, the vault in its corner
			spots.append(dm.troll_vault_chest_cell + Vector2i(-3, 0))   # inside, by the hoard
		for k in range(spots.size()):
			await _shot(spots[k], "in_%d" % k, 1280, 720)
		quit()
		return
	for s in dm.site_nodes:
		await _shot(s["grid_pos"], s["id"])
	for wp in dm.waypoint_nodes:
		if wp["target"] == "transport":
			await _shot(wp["grid_pos"] + Vector2i(0, 2), "portal")
	quit()
