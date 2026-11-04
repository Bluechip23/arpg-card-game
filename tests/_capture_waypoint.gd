extends SceneTree
var _main = null
var _out := "/tmp/wp.png"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_main)
	_run.call_deferred()
func _run() -> void:
	for _i in range(40): await process_frame
	var g := 0
	while _main.olorin and _main.olorin.is_busy() and g < 20:
		_main.olorin._close(); g += 1
		await process_frame
	var dm = _main.dungeon_manager
	var cell: Vector2i = dm.waypoint_nodes[0]["grid_pos"]
	var p = _main.player
	var pos: Vector3 = _main.grid_manager.grid_to_world(cell)
	p.position = pos; p.target_position = pos
	_main._camera_distance = 3.0
	for _i in range(60): await process_frame
	p.position.y = _main._desired_ground_y(p.position)
	for _i in range(5): await process_frame
	var img: Image = _main._world_viewport.get_texture().get_image()
	var c: Vector2 = _main.get_world_camera().unproject_position(p.position)
	img.get_region(Rect2i(int(c.x) - 260, int(c.y) - 330, 520, 420).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))).save_png(_out)
	quit()
