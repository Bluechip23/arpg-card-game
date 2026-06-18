extends SceneTree

## Dev helper: render the character-select screen to a PNG so the 3D figures can
## be eyeballed without a real display. Run under a virtual framebuffer with a
## software GL driver, e.g.:
##
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tests/_capture_select.gd [output.png]

var _frames := 0

var _scene: Node = null

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/character/character_select.tscn")
	_scene = packed.instantiate()
	get_root().add_child(_scene)

func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	# Optionally scroll the card row (arg 1 = "right") to view later characters.
	if _frames == 2 and args.size() > 1 and args[1] == "right":
		var sc := _scene.get_node_or_null("VBox/ScrollContainer") as ScrollContainer
		if sc:
			sc.scroll_horizontal = 99999
	# Give the SubViewport figures a few frames to render.
	if _frames < 60:
		return false
	var out := "/tmp/character_select.png"
	if args.size() > 0:
		out = args[0]
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("[capture] saved %s (%dx%d)" % [out, img.get_width(), img.get_height()])
	quit()
	return true
