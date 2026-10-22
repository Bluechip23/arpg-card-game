extends SceneTree

## Dev helper: the Return Scroll round trip on screen. Opens the portal from
## the inventory (the right-click path), steps through to town, steps back,
## and saves a frame at each stage: <out>_1_open.png, _2_town.png,
## _3_back.png. Pass "cave" as the second arg to do it inside a cave.
## Run under xvfb + software GL like _capture_hud.gd:
##   ... --script tests/_capture_portal.gd -- /tmp/portal [cave]

var _frames := 0
var _stage := 0
var _out := "/tmp/portal"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.starting_character = CharacterData.create_brad()
	get_root().add_child(main)

func _live(prop: String) -> Node:
	for c in get_root().get_children():
		if c.get_script() and prop in c and not c.is_queued_for_deletion():
			return c
	return null

func _snap(tag: String) -> void:
	var p := "%s_%s.png" % [_out, tag]
	get_root().get_texture().get_image().save_png(p)
	print("saved ", p)

func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	var cave := args.size() > 1 and args[1] == "cave"
	match _stage:
		0:
			if _frames == 20:
				var m = _live("current_interior_id")
				if m.olorin and m.olorin.is_busy():
					m.olorin._close()
				if cave:
					for s in m.dungeon_manager.site_nodes:
						if s["kind"] == "cave":
							m._enter_interior(s["id"], "Cave")
							break
				_stage = 1
				_frames = 0
		1:
			if _frames == 20:
				var m = _live("current_interior_id")
				var inv = m.player.get_inventory()
				var scroll = null
				for it in inv.stored_items:
					if it and it.special_id == "return_scroll":
						scroll = it
				m.character_panel.show_panel()
				m.character_panel._on_stored_item_right_clicked(scroll, 0)
			if _frames == 40:
				_snap("1_open")
				var m = _live("current_interior_id")
				m.player.position = m._town_portal_node.position + Vector3(0, 0, 1)
				m._try_interact_town_portal()
				_stage = 2
				_frames = 0
		2:
			if _frames == 40:
				_snap("2_town")
				_live("return_world_level")._go_to_battle(true)
				_stage = 3
				_frames = 0
		3:
			if _frames == 40:
				_snap("3_back")
				return true
	return false
