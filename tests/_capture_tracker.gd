extends SceneTree
## Dev helper: boot the dojo, capture the left-side unit tracker (with the
## group expanded) and the enemy inspect panel for the first dummy.
var _main: Node = null
var _frames := 0
func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)
func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	var out := "/tmp/tracker.png"
	if args.size() > 0:
		out = args[0]
	if _frames == 30:
		var ut = _main.unit_tracker
		if ut:
			for type_name in ut._group_entries:
				ut._group_entries[type_name]["expanded"] = true
			ut.refresh()
		var living: Array = _main.enemy_spawner.get_living_enemies()
		if living.size() > 0 and _main.enemy_inspect_ui:
			_main.enemy_inspect_ui.show_enemy(living[0])
	if _frames == 45:
		get_root().get_texture().get_image().save_png(out)
		print("[capture] saved %s" % out)
		quit()
		return true
	return false
