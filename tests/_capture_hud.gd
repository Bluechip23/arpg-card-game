extends SceneTree

## Dev helper: boot the battle scene as the dojo, give the character some
## regular and unerring armor, and crop the top-left HUD (HP bar, unerring
## bar, shield badge, mana bar) to a PNG. Run under xvfb + software GL:
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tests/_capture_hud.gd -- /tmp/hud.png

var _main: Node = null
var _frames := 0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		var stats = _main.player.get_stats()
		stats.add_unerring_armor(2)
		stats.add_armor(3)
	if _frames < 50:
		return false
	var args := OS.get_cmdline_user_args()
	var out := "/tmp/hud.png"
	if args.size() > 0:
		out = args[0]
	var img := get_root().get_texture().get_image()
	var crop := img.get_region(Rect2i(0, 0, 420, 150))
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(out)
	print("[capture] saved %s" % out)
	quit()
	return true
