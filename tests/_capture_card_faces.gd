extends SceneTree
## Dev helper: lay up to four card faces side by side at 2x and save a picture.
## Run: xvfb-run -a godot --path . --script tests/_capture_card_faces.gd -- /tmp/faces.png id1 id2 …
var _frames := 0
var _out := "/tmp/card_faces.png"
var _ids: Array = ["if_pigs_could_fly", "slash", "fireball"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_ids = args.slice(1)

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.25, 0.28)
	bg.size = Vector2(1280, 720)
	get_root().add_child(bg)
	var holder := Control.new()
	holder.scale = Vector2(2, 2)
	get_root().add_child(holder)
	var x := 20.0
	for id in _ids:
		var card: Card = Card.create_by_id(str(id))
		if card == null:
			continue
		var ui: CardUI = (load("res://scenes/cards/card_ui.tscn") as PackedScene).instantiate()
		holder.add_child(ui)
		ui.setup(card, 0)
		ui.position = Vector2(x, 60)
		x += 160.0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_build()
	if _frames == 20:
		get_root().get_texture().get_image().save_png(_out)
		print("[capture] saved %s" % _out)
		quit()
		return true
	return false
