extends SceneTree

## Dev helper: boot the town with a character and save the full frame, then
## the frame again with the character panel and quest journal open (via the
## HUD bar). Run under xvfb + software GL like _capture_hud.gd:
##   ... --script tests/_capture_town.gd -- /tmp/town.png

var _town: Node = null
var _frames := 0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/menus/town.tscn")
	_town = packed.instantiate()
	_town.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_town)

func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	var out := "/tmp/town.png"
	if args.size() > 0:
		out = args[0]
	if _frames == 20:
		# Whole plaza in frame: zoom all the way out and look at its centre.
		_town._camera_distance = CameraView.ZOOM_MIN
		_town._camera_focus = Vector3(10.5, 0, 7.5)
		_town._camera_pan = Vector3.ZERO
		_town._update_camera()
	if _frames == 40:
		get_root().get_texture().get_image().save_png(out)
		print("[capture] saved %s" % out)
		_town._toggle_quest_log()
		_town.character_panel.toggle_panel()
	if _frames == 60:
		get_root().get_texture().get_image().save_png(out.replace(".png", "_open.png"))
		print("[capture] saved %s" % out.replace(".png", "_open.png"))
		quit()
		return true
	return false
