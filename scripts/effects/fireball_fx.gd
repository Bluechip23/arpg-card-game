class_name FireballFX
extends Node3D

## Fireball: the designer's animation (tools/cut_fireball.py). An ember
## kindles at the caster's hand, the fireball flies to the aimed point —
## laid flat under the plan-view camera so it can point along any heading,
## its trail streaming behind — and bursts there in three stages, then fades.
## Lives in the world (not on the caster) so the blast stays where it lands;
## frees itself when done.

const STRIP := "res://assets/sprites/generated/fx/fireball_strip.png"
const FRAMES := 5
const CELL := 128
const ANCHOR := Vector2(77, 69)     # the shared point on the canvas (see the tool)
const HAND := 0.45                  # the ember kindles this far out toward the target
const EMBER_TIME := 0.12
const SPEED := 16.0                 # world units per second in flight
const MIN_FLIGHT := 0.12
const MAX_FLIGHT := 0.45
const BLAST_TIME := 0.09            # per explosion stage
const FADE_TIME := 0.15

var _sprite: Sprite3D = null


## Throw one from `from` (the caster's feet) to `to` (the aimed point) under
## `world` (the node the field lives in).
static func play(world: Node, from: Vector3, to: Vector3) -> FireballFX:
	if world == null or not world.is_inside_tree():
		return null
	var fx := FireballFX.new()
	world.add_child(fx)
	fx._start(from, to)
	return fx


func _start(from: Vector3, to: Vector3) -> void:
	name = "FireballFX"
	process_mode = Node.PROCESS_MODE_ALWAYS  # plays out even if the game pauses as it lands
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3.RIGHT
	var lift := CameraView.SPRITE_LIFT + 0.25
	var start := Vector3(from.x, lift, from.z) + dir * HAND
	var end := Vector3(to.x, lift, to.z)
	position = start
	# Point the art (drawn heading right, +X) along the flight: a turn about Y.
	rotation.y = atan2(-dir.z, dir.x)

	_sprite = Sprite3D.new()
	_sprite.texture = load(STRIP)
	_sprite.hframes = FRAMES
	_sprite.frame = 0
	_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_sprite.rotation_degrees.x = -90.0                 # lie flat, face the camera above
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED  # blended, so it can fade
	_sprite.shaded = false
	_sprite.no_depth_test = true
	_sprite.render_priority = 10
	_sprite.pixel_size = CameraView.PIXEL_SIZE
	# Pin the canvas's anchor to this node (Sprite3D offsets are y-up).
	_sprite.offset = Vector2(CELL * 0.5 - ANCHOR.x, ANCHOR.y - CELL * 0.5)
	add_child(_sprite)

	var flight := clampf(start.distance_to(end) / SPEED, MIN_FLIGHT, MAX_FLIGHT)
	var tw := create_tween()
	tw.tween_interval(EMBER_TIME)
	tw.tween_callback(func(): _sprite.frame = 1)
	tw.tween_property(self, "position", end, flight)
	# The blast stands upright whatever way the ball flew.
	tw.tween_callback(func(): rotation.y = 0.0)
	for f in range(2, FRAMES):
		tw.tween_callback(func(): _sprite.frame = f)
		tw.tween_interval(BLAST_TIME)
	tw.tween_property(_sprite, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
