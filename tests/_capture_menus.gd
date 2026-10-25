extends SceneTree

## Dev helper: boot each menu screen reachable from the title menu and save
## a PNG of it. Run under xvfb + software GL:
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tests/_capture_menus.gd -- <out_dir>

const SCREENS := [
	["load_or_new", "res://scenes/character/load_or_new.tscn", {}],
	["load_character", "res://scenes/character/load_character.tscn", {}],
	["character_select", "res://scenes/character/character_select.tscn", {"game_mode": "single_player"}],
	["character_select_mp", "res://scenes/character/character_select.tscn", {"game_mode": "multiplayer"}],
	["questionnaire", "res://scenes/character/character_questionnaire.tscn", {}],
	["compendium", "res://scenes/ui/compendium_page.tscn", {}],
	["help", "res://scenes/ui/help_page.tscn", {}],
	["animation_lab", "res://scenes/menus/animation_lab.tscn", {}],
	["enemy_lab", "res://scenes/menus/enemy_lab.tscn", {}],
]

var _out := "/tmp/menus"
var _idx := -1
var _frames := 0
var _scene: Node = null

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_next()

func _next() -> void:
	if _scene and is_instance_valid(_scene):
		_scene.free()
	# Screens replace themselves (queue_free + add to root); clear strays.
	for child in get_root().get_children():
		if child is Control:
			child.free()
	_idx += 1
	_frames = 0
	if _idx >= SCREENS.size():
		quit()
		return
	var entry: Array = SCREENS[_idx]
	_scene = (load(entry[1]) as PackedScene).instantiate()
	for key in entry[2]:
		_scene.set(key, entry[2][key])
	get_root().add_child(_scene)

func _process(_delta: float) -> bool:
	if _idx >= SCREENS.size():
		return true
	_frames += 1
	if _frames == 40:
		get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, SCREENS[_idx][0]])
		print("[capture] saved %s.png" % SCREENS[_idx][0])
		_next()
	return false
