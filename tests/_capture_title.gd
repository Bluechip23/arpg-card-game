extends SceneTree
var _dir := "/tmp/title"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var tm = (load("res://scenes/menus/title_menu.tscn") as PackedScene).instantiate()
	get_root().add_child(tm)
	_run.call_deferred(tm)
func _run(tm) -> void:
	for _i in range(5): await process_frame
	var cs = tm.get_node_or_null("TitleCutscene")
	print("[probe] cutscene ", cs, " size ", cs.size if cs else null)
	for t in [1.0, 11.0, 16.0, 24.0]:
		cs._t = t
		cs.queue_redraw()
		for _i in range(3): await process_frame
		get_root().get_texture().get_image().save_png("%s/t%02d.png" % [_dir, int(t)])
	quit()
