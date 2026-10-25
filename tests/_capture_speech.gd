extends SceneTree

## Dev helper: boot the battle scene with a fresh Brad, close the field tour,
## then show three of Olorin's dialogs (a short one, the long mythic lesson
## with the doughnut, and the player's own thought) and save a PNG of each
## speech bar. Run under xvfb + software GL:
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tests/_capture_speech.gd -- <out_dir>

var _main: Node = null
var _frames := 0
var _out := "/tmp/speech"
var _step := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 70:
		return false
	var olorin = _main.get("olorin")
	if olorin == null:
		quit(1)
		return true
	if _frames == 70 and olorin.is_busy():
		olorin._close()
	var shows := [
		func(): olorin.show_tutorial("combat_intro", olorin.lesson_title("combat_intro"),
			olorin.lesson_paragraphs("combat_intro"), true),
		func(): olorin._build_dialog(olorin.lesson_title("mythic_lesson"),
			olorin.lesson_paragraphs("mythic_lesson"), OlorinTutorial.DoughnutIcon.new(), 1),
		func(): olorin.show_tutorial("doughnut_keep", olorin.lesson_title("doughnut_keep"),
			olorin.lesson_paragraphs("doughnut_keep"), true, "Brad"),
	]
	# Each dialog: open at +0, shoot at +12 (after the body is sized), close.
	var local := _frames - 80
	if local < 0:
		return false
	var idx := local / 20
	var phase := local % 20
	if idx >= shows.size():
		quit()
		return true
	if phase == 0:
		shows[idx].call()
	elif phase == 12:
		get_root().get_texture().get_image().save_png("%s/speech_%d.png" % [_out, idx])
		print("[capture] saved speech_%d.png" % idx)
	elif phase == 14:
		olorin._close()
	return false
