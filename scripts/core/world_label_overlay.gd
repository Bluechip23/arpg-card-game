class_name WorldLabelOverlay
extends CanvasLayer

## Crisp world text. The 3D world renders at half resolution (the pixel-art
## look), which turned every Label3D — names, health, prompts, damage
## numbers — into smeared 2x text. This layer mirrors each Label3D with a
## full-resolution UI Label that follows the 3D node's screen position every
## frame, and hides the Label3D from the cameras (`layers = 0`). The Label3D
## stays the source of truth: gameplay code keeps setting its text, colour,
## visibility and position exactly as before.
##
## `setup(root, project)`: `root` is the node whose descendants are mirrored
## (new Label3Ds are caught through SceneTree.node_added); `project` maps a
## world position to full-resolution screen pixels.

var _root: Node = null
var _project: Callable
var _entries: Dictionary = {}  # Label3D -> Label


func setup(root: Node, project: Callable) -> void:
	_root = root
	_project = project
	layer = -50  # above the world render (-100), below the UI layers


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	if _root:
		_scan(_root)


func _scan(node: Node) -> void:
	if node is Label3D:
		_track(node)
	for c in node.get_children():
		_scan(c)


func _on_node_added(node: Node) -> void:
	if node is Label3D and _root and (_root == node or _root.is_ancestor_of(node)):
		_track(node)


func _track(l: Label3D) -> void:
	if _entries.has(l):
		return
	l.layers = 0  # no camera draws it; the mirror does
	var ui := Label.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.visible = false
	add_child(ui)
	_entries[l] = ui


## On-screen pixel height for a Label3D. Labels sized through WorldText
## (`fixed_size`) were supersampled 2x; anything else is converted at the
## measured screen factor.
static func _px(l: Label3D, ppu: float) -> int:
	if l.fixed_size:
		return maxi(8, roundi(l.font_size / WorldText.SUPERSAMPLE))
	if l.has_meta("world_scaled"):
		# Sized in world units: keeps its ratio to the sprites at every zoom.
		return maxi(6, roundi(l.font_size * l.pixel_size * ppu))
	return clampi(roundi(l.font_size * l.pixel_size * WorldText.PX_FACTOR), 9, 28)


## Screen pixels per world unit, from the two projected ends of a unit.
func _pixels_per_unit() -> float:
	var a: Vector2 = _project.call(Vector3.ZERO)
	var b: Vector2 = _project.call(Vector3(1, 0, 0))
	return maxf(1.0, a.distance_to(b))


func _process(_delta: float) -> void:
	if not _project.is_valid():
		return
	var dead: Array = []
	var ppu := _pixels_per_unit()
	for l in _entries.keys():
		var ui: Label = _entries[l]
		if not is_instance_valid(l) or not l.is_inside_tree():
			dead.append(l)
			if is_instance_valid(ui):
				ui.queue_free()
			continue
		var shown: bool = l.is_visible_in_tree() and l.text != "" and l.modulate.a > 0.01
		ui.visible = shown
		if not shown:
			continue
		var px := _px(l, ppu)
		ui.text = l.text
		ui.add_theme_font_size_override("font_size", px)
		ui.add_theme_color_override("font_color", l.modulate)
		var outline: bool = l.outline_size > 0
		ui.add_theme_constant_override("outline_size", maxi(2, roundi(px * 0.18)) if outline else 0)
		var oc: Color = l.outline_modulate
		oc.a *= l.modulate.a
		ui.add_theme_color_override("font_outline_color", oc)
		# Under the plan camera, height above the ground does not move a
		# point on screen; a label's world height is meant as "above the
		# head", so it becomes a screen-up shift at the current texel scale.
		var gp: Vector3 = l.global_position
		var p: Vector2 = _project.call(Vector3(gp.x, 0.0, gp.z))
		p.y -= gp.y * CameraView.HEIGHT_ON_SCREEN * ppu
		var sz: Vector2 = ui.get_minimum_size()
		ui.size = sz
		# Label3D.offset is in its own texels (y up); mirror it as screen pixels.
		var off: Vector2 = Vector2(l.offset.x, -l.offset.y) * l.pixel_size * WorldText.PX_FACTOR
		if l.has_meta("world_scaled"):
			off = Vector2(l.offset.x, -l.offset.y) * l.pixel_size * ppu
		if l.fixed_size:
			off = Vector2(l.offset.x, -l.offset.y) / WorldText.SUPERSAMPLE
		ui.position = (p - sz * 0.5 + off).round()
	for l in dead:
		_entries.erase(l)
