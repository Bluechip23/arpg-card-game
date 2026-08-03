extends SceneTree

## Dev helper: boot the game, reveal the map, capture wide environment shots
## at gameplay-like camera angles around points of interest.
##   ... --script tests/_capture_env.gd -- <prefix>

var _main: Node = null
var _cam: Camera3D = null
var _frames := 0
var _prefix := "/tmp/env"
var _spots: Array = []   # [{pos: Vector3, name: String}]
var _shot := 0

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
	if _spots.is_empty() and dm and not dm.chest_nodes.is_empty():
		for x in range(dm.GRID_W):
			for z in range(0, dm.GRID_H, 4):
				dm.reveal_around(Vector2i(x, z))
		var player := _main.get_node_or_null("Player")
		var ppos: Vector3 = player.global_position if player else Vector3(10, 0, 10)
		_spots = [
			{"pos": ppos, "name": "start"},
			{"pos": dm.chest_nodes[0]["node"].global_position, "name": "chest_area"},
			{"pos": Vector3(dm.GRID_W * 0.5, 0, dm.GRID_H * 0.5), "name": "center"},
			{"pos": Vector3(dm.GRID_W * 0.72, 0, dm.GRID_H * 0.3), "name": "far"},
		]
	if not _spots.is_empty() and _shot < _spots.size():
		var target: Vector3 = _spots[_shot]["pos"]
		_cam.global_position = target + Vector3(0, 7.5, 8.0)
		_cam.look_at(target, Vector3.UP)
		_cam.current = true
	if _frames >= 70 and (_frames - 70) % 8 == 0 and _shot < _spots.size():
		_save("_%s.png" % _spots[_shot]["name"])
		_shot += 1
		if _shot >= _spots.size():
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
