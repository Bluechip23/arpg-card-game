extends SceneTree

## Dev helper: boot the game and capture through the REAL game camera and
## SubViewport pipeline (UI included) — for camera/projection experiments.
##   ... --script tests/_capture_gamecam.gd -- <prefix>

var _main: Node = null
var _frames := 0
var _prefix := "/tmp/gamecam"

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
	_press_continue(get_root())
	match _frames:
		90:
			_save("_view.png")
			quit()
	return false

func _press_continue(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton and not child.disabled and child.is_visible_in_tree():
			var label: String = child.text.to_lower()
			if "continue" in label or "got it" in label or "close" in label:
				child.pressed.emit()
		_press_continue(child)

func _save(suffix: String) -> void:
	get_root().get_texture().get_image().save_png(_prefix + suffix)
	print("[capture] " + _prefix + suffix)
