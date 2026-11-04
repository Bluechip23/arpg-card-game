extends SceneTree

## Dev helper: boot the battle scene as Cory or Jeremy and crop the Draw-pile
## corner so the clock icon beside the pile can be eyeballed in each of its
## states (no item / mid-count / ready). Run under xvfb + software GL:
##   LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
##     --rendering-method gl_compatibility --rendering-driver opengl3 \
##     --script tests/_capture_pile_icon.gd -- cory /tmp/pile_icon

var _main: Node = null
var _frames := 0
var _who := "cory"
var _prefix := "/tmp/pile_icon"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_who = args[0]
	if args.size() > 1:
		_prefix = args[1]
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	var cd: CharacterData = CharacterData.create_cory() if _who == "cory" else CharacterData.create_jeremy()
	_main.set("starting_character", cd)
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)

func _inv() -> Inventory:
	return _main.player.get_inventory()

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames in [15, 25, 35]:
		_hush_olorin()
	match _frames:
		20:
			_save("_none.png")  # nothing equipped: faded
			if _who == "cory":
				var gloves := ItemData.create("chain_gloves")
				_inv().equip_item(gloves, 0)
				gloves.activate_skill()
				gloves.current_cooldown = 2  # 10/20 recharged -> 1 band
			else:
				_inv().equip_item(ItemData.create("gold_band"), 0)
				_inv().ring_cycle_count = 2   # 2 bands
			_main.call("_update_pile_passive_icon")
		30:
			_save("_mid.png")
			if _who == "cory":
				_inv().equipped_gauntlets[0].current_cooldown = 0  # ready
			else:
				_inv().ring_cycle_count = 3  # armed
			_main.call("_update_pile_passive_icon")
		40:
			_save("_ready.png")
			quit()
	return false

## Olorin's dojo lesson opens over the corner we crop; close it first.
func _hush_olorin() -> void:
	var guard := 0
	while _main.olorin and _main.olorin.is_busy() and guard < 20:
		_main.olorin._close()
		guard += 1

func _save(suffix: String) -> void:
	var img := get_root().get_texture().get_image()
	var h := img.get_height()
	var crop := img.get_region(Rect2i(0, h - 230, 260, 230))
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(_prefix + suffix)
	print("[capture] saved %s" % (_prefix + suffix))
