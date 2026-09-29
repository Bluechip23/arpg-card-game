extends SceneTree

## Dev helper: boot the dojo, wear a Heal Stone, heal a little, and crop the
## bottom-right passive tray (with the ring's tally box) to a PNG.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --script tests/_capture_tray.gd -- /tmp/tray.png

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
		var inv = _main.player.get_inventory()
		var stone := ItemData.create_heal_stone()
		inv.stored_items.append(stone)
		inv.equip_item(stone)
		var stats = _main.player.get_stats()
		stats.take_damage(8)
		stats.heal(3)
		_main._update_passive_display_ui()
	if _frames < 40:
		return false
	var args := OS.get_cmdline_user_args()
	var out := "/tmp/tray.png"
	if args.size() > 0:
		out = args[0]
	var img := get_root().get_texture().get_image()
	var crop := img.get_region(Rect2i(980, 500, 300, 220))
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(out)
	print("[capture] saved %s" % out)
	quit()
	return true
