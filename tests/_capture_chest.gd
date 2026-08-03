extends SceneTree

## Dev helper: boot the game, fly a camera to the first treasure chest,
## capture it closed, open it, capture again.
##   ... --script tests/_capture_chest.gd -- <prefix>

var _main: Node = null
var _cam: Camera3D = null
var _frames := 0
var _prefix := "/tmp/chest"
var _chest_idx := -1
var _angle := 0.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	_main = packed.instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	get_root().add_child(_main)
	_cam = Camera3D.new()
	get_root().add_child(_cam)

func _process(_delta: float) -> bool:
	_frames += 1
	_press_continue(get_root())
	_hide_ui()
	var dm = _main.get("dungeon_manager")
	if _chest_idx == -1 and dm and not dm.chest_nodes.is_empty():
		_chest_idx = 0
		for x in range(dm.GRID_W):
			for z in range(0, dm.GRID_H, 4):
				dm.reveal_around(Vector2i(x, z))
	if _chest_idx >= 0 and dm:
		var chest_pos: Vector3 = dm.chest_nodes[_chest_idx]["node"].global_position
		var off := Vector3(sin(_angle) * 3.0, 1.8, cos(_angle) * 3.0)
		_cam.global_position = chest_pos + off
		_cam.look_at(chest_pos + Vector3(0, 0.35, 0), Vector3.UP)
		_cam.current = true
		if _frames == 60:
			print("[capture] chest at %s cam at %s" % [chest_pos, _cam.global_position])
	match _frames:
		70:
			_save("_closed_a0.png"); _angle = PI / 2.0
		74:
			_save("_closed_a90.png"); _angle = PI
		78:
			_save("_closed_a180.png"); _angle = 0.0
		84:
			if _chest_idx >= 0 and dm:
				dm.open_chest(_chest_idx)
		100:
			_save("_open.png")
			quit()
	return false

func _hide_ui() -> void:
	for child in _main.get_children():
		if child is CanvasLayer:
			child.visible = false

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
