extends SceneTree

## Dev helper: boot the dojo, put Vulnerable and Burn on the dummy, move the
## mouse onto its first status dot and onto its tracker circle, and save a
## PNG of each hover window. Run under xvfb + software GL:
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tests/_capture_enemy_status_hover.gd -- <out_dir>

var _main: Node = null
var _frames := 0
var _out := "/tmp/status_hover"
var _foe = null

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40:
		if _main.olorin and _main.olorin.is_busy():
			_main.olorin._close()
		var living: Array = _main.enemy_spawner.get_living_enemies()
		if living.is_empty():
			print("[capture] no enemy")
			quit(1)
			return true
		_foe = living[0]
		# Stand it in the open beside the player so its dots are on screen.
		var gm = _main.grid_manager
		var here: Vector2i = gm.world_to_grid(_main.player.position)
		_foe.position = gm.grid_to_world(here + Vector2i(3, -1))
		_foe.vulnerable_stacks = 2
		_foe.apply_debuff("Burn", 3) if _foe.has_method("apply_debuff") else null
		_foe._update_status_indicators()
		_main._refresh_unit_tracker()
	if _frames == 50:
		var targets: Array = _foe.get_status_hover_targets()
		print("[capture] dots: %s" % str(targets.map(func(t): return t["name"])))
		if not targets.is_empty():
			var sp: Vector2 = _main.world_to_screen(targets[0]["pos"])
			Input.warp_mouse(sp)
	if _frames == 69:
		var hov = get_root().gui_get_hovered_control()
		print("[capture] mouse %s hovered=%s path=%s" % [get_root().get_mouse_position(), hov, hov.get_path() if hov else ""])
		print("[capture] popup visible: %s" % (StatusHoverPopup._inst != null and is_instance_valid(StatusHoverPopup._inst) and StatusHoverPopup._inst.visible))
	if _frames == 70:
		get_root().get_texture().get_image().save_png("%s/over_head.png" % _out)
		print("[capture] saved over_head.png")
		# Now the tracker circle for the same effect.
		var circles := _find_tracker_circles(_main.unit_tracker)
		if not circles.is_empty():
			Input.warp_mouse(circles[0].get_global_rect().get_center())
	if _frames == 90:
		get_root().get_texture().get_image().save_png("%s/tracker.png" % _out)
		print("[capture] saved tracker.png")
		quit()
		return true
	return false

func _find_tracker_circles(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is PanelContainer and c.custom_minimum_size == Vector2(14, 14):
			out.append(c)
		out.append_array(_find_tracker_circles(c))
	return out
