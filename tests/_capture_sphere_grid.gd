extends SceneTree

## Dev helper: the sphere grid tab of the skill tree panel, with a few nodes
## unlocked so all three states (locked / available / unlocked) show, saved
## as PNGs: the whole grid at the default zoom, zoomed in on the centre,
## zoomed out, with a node's detail popup open, and with a constellation
## hovered. Run under xvfb + software GL:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-driver opengl3 --script tests/_capture_sphere_grid.gd -- <out_dir>

var _main: Node = null
var _frames := 0
var _out := "/tmp/sphere_grid"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_main)

func _shot(name: String) -> void:
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[capture] saved %s.png" % name)

func _process(_delta: float) -> bool:
	_frames += 1
	var ui = _main.sphere_grid_ui if _main else null
	if _frames == 40:
		if _main.olorin and _main.olorin.is_busy():
			_main.olorin._close()
		var grid: SphereGrid = ui.sphere_grid
		# A path out from the centre: STR, its HP branch, the free-stat node
		# past it, and one each of the other kinds along the way.
		for id in [1, 2, 7, 8, 9, 19, 20, 21]:
			grid.unlock_node(id)
		_main.sphere_inventory.add_sphere(SphereInventory.SphereType.SPHERE, 5)
		_main.skill_tree_ui.show_panel()
		_main.skill_tree_ui._switch_to_tab(_main.skill_tree_ui.Tab.SPHERE_GRID)
	if _frames == 55:
		_shot("grid")
		ui._zoom = 2.0
		ui.grid_canvas.queue_redraw()
	if _frames == 62:
		_shot("grid_zoom_in")
		ui._zoom = 0.5
		ui.grid_canvas.queue_redraw()
	if _frames == 69:
		_shot("grid_zoom_out")
		ui._zoom = 1.0
		ui._hovered_node_id = 10
		ui._update_info_label()
		ui._open_detail_popup(19)
	if _frames == 78:
		_shot("grid_popup")
		ui._close_detail_popup()
		ui._hovered_node_id = -1
		ui._update_info_label()
		var cs = ui.sphere_grid.get_all_constellations()
		if cs.size() > 0:
			ui._hovered_constellation_id = cs[0].id
		ui.grid_canvas.queue_redraw()
	if _frames == 85:
		_shot("grid_constellation")
		quit()
		return true
	return false
