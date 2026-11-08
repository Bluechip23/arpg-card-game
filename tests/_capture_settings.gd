extends SceneTree

## Dev helper: the in-game ? panel open on its Settings tab, saved as a PNG.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script tests/_capture_settings.gd -- <out.png>

var _main: Node = null
var _frames := 0
var _out := "/tmp/settings.png"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40:
		if _main.olorin and _main.olorin.is_busy():
			_main.olorin._close()
		_main.help_panel.show_panel(2)
	if _frames == 50:
		get_root().get_texture().get_image().save_png(_out)
		quit()
		return true
	return false
