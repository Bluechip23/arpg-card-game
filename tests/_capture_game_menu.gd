extends SceneTree

## Dev helper: the in-game ? panel with its Save / Quit row, then the "Save
## before you quit?" question, saved as two PNGs.
##   ... --script tests/_capture_game_menu.gd -- <out_dir>

var _main: Node = null
var _frames := 0
var _out := "/tmp/game_menu"

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
	if _frames == 40:
		if _main.olorin and _main.olorin.is_busy():
			_main.olorin._close()
		_main.help_panel.show_panel(0)
	if _frames == 50:
		get_root().get_texture().get_image().save_png("%s/panel.png" % _out)
		_main.help_panel.ask_quit(false)
	if _frames == 60:
		get_root().get_texture().get_image().save_png("%s/prompt.png" % _out)
		quit()
		return true
	return false
