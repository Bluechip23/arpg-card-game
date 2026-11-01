extends SceneTree
var _dir := "/tmp/cut"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var cs = load("res://scripts/menus/title_cutscene.gd").new()
	cs.palette = load("res://scripts/menus/title_menu.gd").STYLE
	cs.size = Vector2(1280, 720)
	get_root().add_child(cs)
	cs.set_anchors_preset(Control.PRESET_FULL_RECT)
	_run.call_deferred(cs)
func _run(cs) -> void:
	for _i in range(5): await process_frame
	for t in [1.0, 11.0, 16.0, 24.0]:
		cs._t = t
		cs.queue_redraw()
		for _i in range(3): await process_frame
		get_root().get_texture().get_image().save_png("%s/t%02d.png" % [_dir, int(t)])
	quit()
