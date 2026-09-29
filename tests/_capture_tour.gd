extends SceneTree

## Dev helper: boot the battle scene on World 1 with a fresh character (so
## Olorin waits at the portal), run his field tour, and save one PNG per beat
## into a directory. Run under xvfb + software GL:
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tests/_capture_tour.gd -- <out_dir>

var _main: Node = null
var _frames := 0
var _out := "/tmp/tour"
var _shot := -1

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	var olorin = _main.get("olorin")
	if _frames < 70 or olorin == null or not olorin.is_busy():
		return false
	var idx: int = olorin.tour_step_index()
	if idx == _shot:
		olorin._tour_next()
		if not olorin.is_busy():
			print("[capture] done")
			quit()
			return true
		return false
	# Give the new beat a frame to draw before shooting it.
	_shot = idx
	get_root().get_texture().get_image().save_png("%s/tour_%d.png" % [_out, idx])
	print("[capture] saved tour_%d.png" % idx)
	return false
