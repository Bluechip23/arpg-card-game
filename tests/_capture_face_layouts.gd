extends SceneTree
## Dev helper: the card face under a few CardUI.face_layout settings, one row
## of cards per setting, saved as one picture (2x).
## Run: xvfb-run -a godot --path . --script tests/_capture_face_layouts.gd -- /tmp/out.png
var _frames := 0
var _out := "/tmp/face_layouts.png"
const IDS := ["berserkers_tithe", "exacerbate_wounds", "oops"]
## [label, layout]
var VARIANTS := [
	["As now", {}],
]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		VARIANTS = []
		var parsed = JSON.parse_string(args[1])
		for v in parsed:
			VARIANTS.append([v[0], v[1]])

func _build() -> void:
	var rows := VARIANTS.size()
	get_root().size = Vector2i(1500, 40 + rows * 490)
	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.25, 0.28)
	bg.size = Vector2(1500, 40 + rows * 490)
	get_root().add_child(bg)
	var y := 40.0
	for v in VARIANTS:
		var lbl := Label.new()
		lbl.text = v[0]
		lbl.position = Vector2(20, y - 40)
		lbl.add_theme_font_size_override("font_size", 22)
		get_root().add_child(lbl)
		var holder := Control.new()
		holder.scale = Vector2(2, 2)
		holder.position = Vector2(0, y + 16)
		get_root().add_child(holder)
		CardUI.face_layout = v[1]
		var x := 14.0
		for id in IDS:
			var card: Card = Card.create_by_id(str(id))
			var ui: CardUI = (load("res://scenes/cards/card_ui.tscn") as PackedScene).instantiate()
			holder.add_child(ui)
			ui.setup(card, 0)
			ui.position = Vector2(x, 14)
			x += float(v[1].get("width", 150.0)) + 22.0
		y += 490.0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_build()
	if _frames == 24:
		get_root().get_texture().get_image().save_png(_out)
		print("[capture] saved %s" % _out)
		quit()
		return true
	return false
