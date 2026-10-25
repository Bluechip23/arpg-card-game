extends SceneTree

## Dev helper: boot the title menu, skip the cutscene, and save one PNG per
## menu style (with the first button hovered so the Draupnir markers show).
## Run under xvfb + software GL:
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tests/_capture_title.gd -- <out_dir>

var _menu: Node = null
var _frames := 0
var _out := "/tmp/title"
var _style := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_boot()

func _boot() -> void:
	if _menu and is_instance_valid(_menu):
		_menu.free()
	if "style" in TitleMenu:
		TitleMenu.style = _style
	_menu = (load("res://scenes/menus/title_menu.tscn") as PackedScene).instantiate()
	get_root().add_child(_menu)
	_frames = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		var cs = _menu.get_node_or_null("TitleCutscene")
		if cs:
			cs._skip()
	if _frames == 40:
		if _menu.has_method("_on_button_hover"):
			_menu._on_button_hover(0)
	if _frames == 70:
		get_root().get_texture().get_image().save_png("%s/title_%d.png" % [_out, _style])
		print("[capture] saved title_%d.png" % _style)
		_style += 1
		var count: int = TitleMenu.STYLES.size() if "STYLES" in TitleMenu else 1
		if _style >= count:
			quit()
			return true
		_boot()
	return false
