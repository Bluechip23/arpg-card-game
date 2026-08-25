extends SceneTree

## Dev helper: boot the battle scene, grant Brad a spread of skill-tree
## passives (some with cooldowns mid-recharge, some always-on), and capture
## the right-side passive tray. Run under xvfb + software GL:
##   xvfb-run godot --path . --script tests/_capture_passive_tray.gd -- /tmp/passive_tray

var _main: Node = null
var _frames := 0
var _prefix := "/tmp/passive_tray"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	match _frames:
		10:
			_grant_passives()
		30:
			_save("_tray.png")
			quit()
	return false

func _grant_passives() -> void:
	var stats: PlayerStats = _main.get_node("Player").get_stats()
	var ids := ["enraged_will", "in_the_trenches", "stone_skin", "point_to_prove",
		"directed_strength", "the_way_of_the_plate", "ancestral_aid", "redemption",
		"life_steal", "pristine_armor", "vines_codependence", "solemn_independence"]
	for i in ids.size():
		stats.passive_levels[ids[i]] = (i % 15) + 1
		stats.add_skill_tree_passive(ids[i])
	# Put the cooldown passives into visible recharge states.
	var tm: TempoManager = _main.get_node("TempoManager")
	tm.global_tempo = 50
	stats.st_enraged_will_last_tempo = 40   # recharging
	stats.st_itt_charges = 0
	stats.st_itt_last_used_tempo = 47       # pool empty, recharging
	_main.call("_update_passive_display_ui")

func _save(suffix: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(_prefix + suffix)
	print("[capture] " + _prefix + suffix)
