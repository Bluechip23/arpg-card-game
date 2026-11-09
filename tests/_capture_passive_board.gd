extends SceneTree

## Dev helper: the Passives tab — Brad's painted board with some passives
## taken (one maxed), some open and the last stage locked, a passive's hover
## tooltip, and Cory's lane table for comparison — saved as PNGs. Run under
## xvfb + software GL (a window size, e.g. 1920x1080, as the third argument):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
##     --rendering-driver opengl3 --script tests/_capture_passive_board.gd -- <out_dir> [suffix] [WxH]

var _main: Node = null
var _frames := 0
var _out := "/tmp/passive_board"
var _suffix := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_suffix = "_" + args[1]
	if args.size() > 2:   # window size, e.g. 1920x1080
		var wh: PackedStringArray = args[2].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)

func _shot(name: String) -> void:
	get_root().get_texture().get_image().save_png("%s/%s%s.png" % [_out, name, _suffix])
	print("[capture] saved %s%s.png" % [name, _suffix])

func _process(_delta: float) -> bool:
	_frames += 1
	var ui: SkillTreeUI = _main.skill_tree_ui if _main else null
	if _frames == 40:
		if _main.olorin and _main.olorin.is_busy():
			_main.olorin._close()
		var st = _main.player.get_stats()
		ui.player_stats = st
		ui.set_skill_tree(SkillTreeData.create_brad_tree())
		# Stage 1: Enraged Will maxed, In the Trenches 2 -> stage 2 opens;
		# Stage 2: Directed Strength 4 (< 5) -> stage 3 stays locked.
		st.unspent_passive_points = 40
		for _i in range(15):
			st.allocate_passive_point("enraged_will")
		for _i in range(2):
			st.allocate_passive_point("in_the_trenches")
		for _i in range(4):
			st.allocate_passive_point("directed_strength")
		st.unspent_passive_points = 6
		ui.show_panel()
		ui._switch_to_tab(SkillTreeUI.Tab.SKILL_TREE)
	if _frames == 55:
		_shot("brad_board")
		# Hover a passive: move the mouse onto Directed Strength's circle.
		var btn: Control = ui._board_view.find_child("Triangle_Berserker", true, false).get_node("Passive_1/PassiveButton")
		var at: Vector2 = btn.get_global_rect().get_center()
		var ev := InputEventMouseMotion.new()
		ev.position = at
		ev.global_position = at
		get_root().warp_mouse(at)
		get_root().push_input(ev)
	if _frames == 120:
		_shot("brad_board_tooltip")
		var st = _main.player.get_stats()
		var cory_ui: SkillTreeUI = ui
		cory_ui.set_skill_tree(SkillTreeData.create_cory_tree())
		var ev := InputEventMouseMotion.new()
		ev.position = Vector2(4, 4)
		ev.global_position = Vector2(4, 4)
		get_root().push_input(ev)
		st.unspent_passive_points = 3
		cory_ui._rebuild_table()
	if _frames == 135:
		_shot("cory_lanes")
		quit()
		return true
	return false
