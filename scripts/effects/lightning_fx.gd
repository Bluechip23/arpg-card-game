class_name LightningFX
extends Node3D

## The designer's lightning (tools/cut_lightning.py): blue for Shock, gold
## for God of Thunder (designer, 2026-10-23).
##   crackle(world, feet)     — Shock ticking: a blue crackle over the body
##   arc(world, from, to)     — Shock jumping between two bodies: a blue arc,
##                              laid flat and stretched from one to the other
##   thunder(world, feet)     — God of Thunder: the gold bolt strikes down on
##                              the spot and bursts across the ground there
## Each lives in the world and frees itself; all play through a pause.

const ARC := "res://assets/sprites/generated/fx/shock_arc_strip.png"
const CRACKLE := "res://assets/sprites/generated/fx/shock_crackle_strip.png"
const STRIKE := "res://assets/sprites/generated/fx/thunder_strike_strip.png"
const IMPACT := "res://assets/sprites/generated/fx/thunder_impact_strip.png"
const ARC_FRAMES := 6
const CRACKLE_FRAMES := 5
const STRIKE_FRAMES := 6
const IMPACT_FRAMES := 5
const BODY := Vector3(0, 0, -0.45)  # a figure's middle on screen (north of the feet)
const CRACKLE_SIZE := 0.9           # ~1.9 tiles across over a body
const ARC_STEP := 0.05
const CRACKLE_STEP := 0.06
const STRIKE_STEP := 0.05
const IMPACT_STEP := 0.07

var _sprite: Sprite3D = null


static func crackle(world: Node, feet: Vector3) -> LightningFX:
	var fx := _make(world, "ShockCrackle")
	if fx == null:
		return null
	fx.position = Vector3(feet.x, CameraView.SPRITE_LIFT + 0.3, feet.z) + BODY
	fx._sprite = fx._sheet(CRACKLE, CRACKLE_FRAMES, true)
	fx._sprite.scale = Vector3.ONE * CRACKLE_SIZE
	fx._run([[0, CRACKLE_FRAMES, CRACKLE_STEP]])
	return fx


static func arc(world: Node, from_feet: Vector3, to_feet: Vector3) -> LightningFX:
	var flat := Vector3(to_feet.x - from_feet.x, 0, to_feet.z - from_feet.z)
	if flat.length() < 0.1:
		return null
	var fx := _make(world, "ShockArc")
	if fx == null:
		return null
	fx.position = Vector3(from_feet.x, CameraView.SPRITE_LIFT + 0.3, from_feet.z) + BODY
	fx.rotation.y = atan2(-flat.z, flat.x)          # the arc art runs +X: turn it along the jump
	fx._sprite = fx._sheet(ARC, ARC_FRAMES, false)
	var cell_w := float(fx._sprite.texture.get_width()) / ARC_FRAMES
	fx._sprite.offset = Vector2(cell_w * 0.5, 0)      # its left end on the source body
	var s := flat.length() / (cell_w * CameraView.PIXEL_SIZE)
	fx._sprite.scale = Vector3(s, s, s)
	fx._run([[0, ARC_FRAMES, ARC_STEP]])
	return fx


static func thunder(world: Node, feet: Vector3, delay: float = 0.0) -> LightningFX:
	var fx := _make(world, "GodOfThunder")
	if fx == null:
		return null
	fx.position = Vector3(feet.x, CameraView.SPRITE_LIFT, feet.z)
	fx._sprite = fx._sheet(STRIKE, STRIKE_FRAMES, true)
	fx._bottom_anchor()
	fx._sprite.visible = delay <= 0.0
	var steps := []
	if delay > 0.0:
		steps.append(["wait", delay])
	steps.append([0, STRIKE_FRAMES, STRIKE_STEP])
	steps.append(["sheet", IMPACT, IMPACT_FRAMES])
	steps.append([0, IMPACT_FRAMES, IMPACT_STEP])
	fx._run(steps)
	return fx


static func _make(world: Node, nm: String) -> LightningFX:
	if world == null or not world.is_inside_tree():
		return null
	var fx := LightningFX.new()
	fx.name = nm
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	world.add_child(fx)
	return fx


func _sheet(path: String, frames: int, upright: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(path)
	s.hframes = frames
	s.frame = 0
	if upright:
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	else:
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		s.rotation_degrees.x = -90.0                    # lie flat, face the camera above
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED       # the glow is soft: blend it
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 10
	s.pixel_size = CameraView.PIXEL_SIZE
	add_child(s)
	return s


func _bottom_anchor() -> void:
	# The bolt and the burst stand on the spot: their bottom edge on it.
	_sprite.offset = Vector2(0, float(_sprite.texture.get_height()) * 0.5)


## steps: [first, count, seconds per frame] runs frames; ["wait", s] holds
## hidden; ["sheet", path, frames] swaps to the next strip.
func _run(steps: Array) -> void:
	var tw := create_tween()
	for st in steps:
		if st[0] is String and st[0] == "wait":
			tw.tween_interval(st[1])
			tw.tween_callback(func(): _sprite.visible = true)
		elif st[0] is String and st[0] == "sheet":
			var path: String = st[1]
			var n: int = st[2]
			tw.tween_callback(func():
				_sprite.texture = load(path)
				_sprite.hframes = n
				_sprite.frame = 0
				_bottom_anchor())
		else:
			for f in range(st[0], st[0] + st[1]):
				tw.tween_callback(func(): _sprite.frame = f)
				tw.tween_interval(st[2])
	tw.tween_callback(queue_free)
