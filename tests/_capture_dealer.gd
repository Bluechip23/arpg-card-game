extends SceneTree
## Dev helper: open the Card Dealer in town with some gold and a loose card.
var _town: Node = null
var _frames := 0
func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/menus/town.tscn")
	_town = packed.instantiate()
	_town.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_town)
func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	var out := "/tmp/dealer.png"
	if args.size() > 0:
		out = args[0]
	if _frames == 30:
		_town.player.get_stats().gain_gold(120)
		_town.player.get_inventory().store_card(Card.create_by_id("charge"))
		var dealer = _town.get_node("Vendors/CardDealer")
		_town._open_vendor(dealer)
	if _frames == 45:
		get_root().get_texture().get_image().save_png(out)
		print("[capture] saved %s" % out)
		quit()
		return true
	return false
