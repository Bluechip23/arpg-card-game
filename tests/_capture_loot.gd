extends SceneTree
## Dev helper: drop a loot pile on the player's tile in the dojo so the loot
## menu opens (gold auto-taken, item + card + pack waiting), then capture.
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
	var args := OS.get_cmdline_user_args()
	var out := "/tmp/loot.png"
	if args.size() > 0:
		out = args[0]
	if _frames == 30:
		if _main.olorin and _main.olorin.has_method("_close"):
			_main.olorin._close()
		_main._spawn_loot_drop({"gold": 14, "item": ItemData.create_wooden_sword(), "card": Card.create_by_id("charge"), "card_pack": ItemData.Rarity.COMMON}, _main.player.position)
	if _frames == 40:
		# Hover the first row so its description shows.
		var rows = _main._loot_menu_list.get_children()
		if rows.size() > 0:
			rows[0].mouse_entered.emit()
	if _frames == 50:
		get_root().get_texture().get_image().save_png(out)
		print("[capture] saved %s" % out)
		quit()
		return true
	return false
