extends SceneTree
var _out := "/tmp/alloc.png"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	var scene: PackedScene = load("res://scenes/character/character_select.tscn")
	var cs = scene.instantiate()
	get_root().add_child(cs)
	_run.call_deferred(cs)
func _run(cs) -> void:
	for _i in range(10): await process_frame
	cs._show_stat_allocation(CharacterData.create_brad(), func(): pass)
	for _i in range(5): await process_frame
	# press the first stat's name button
	var btn: Button = null
	for n in cs._alloc_overlay.find_children("*", "Button", true, false):
		if n.text == CharacterData.stat_full_name("STR"):
			btn = n
	if btn: btn.pressed.emit()
	for _i in range(6): await process_frame
	get_root().get_texture().get_image().save_png(_out)
	quit()
