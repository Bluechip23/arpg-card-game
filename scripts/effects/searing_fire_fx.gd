class_name SearingFireFX
extends Node3D

## A Snowball's Chance: the designer's searing fire (tools/cut_searing_fire.py)
## sweeps along the ground from the caster: a lick of flame at their feet
## reaches out to the full 3-space line, holds, breaks into embers and the
## embers die away. Laid flat under the plan-view camera and turned along
## the line's heading; scaled so the flames end where the line's damage
## ends. Lives in the world; frees itself when done.

const STRIP := "res://assets/sprites/generated/fx/searing_fire_strip.png"
const FRAMES := 5
const LENGTH_PX := 143.0          # the strip frame's length (base left, tip right)
const GROW_TIME := 0.08           # per growing frame (lick, taller)
const HOLD_TIME := 0.22           # the full line of fire
const EMBER_TIME := 0.12          # per ember frame
const FADE_TIME := 0.15

var _sprite: Sprite3D = null


## Sear from `from` (the caster's feet) along `direction` for `length` world
## units, under `world` (the node the field lives in).
static func play(world: Node, from: Vector3, direction: Vector3, length: float) -> SearingFireFX:
	if world == null or not world.is_inside_tree():
		return null
	var fx := SearingFireFX.new()
	world.add_child(fx)
	fx._start(from, direction, length)
	return fx


func _start(from: Vector3, direction: Vector3, length: float) -> void:
	name = "SearingFireFX"
	process_mode = Node.PROCESS_MODE_ALWAYS  # plays out even if the game pauses
	var dir := Vector3(direction.x, 0, direction.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT
	position = Vector3(from.x, CameraView.SPRITE_LIFT + 0.1, from.z)
	rotation.y = atan2(-dir.z, dir.x)      # the strip runs +X: turn it along the line
	var s := maxf(0.1, length) / (LENGTH_PX * CameraView.PIXEL_SIZE)
	scale = Vector3(s, s, s)

	_sprite = Sprite3D.new()
	_sprite.texture = load(STRIP)
	_sprite.hframes = FRAMES
	_sprite.frame = 0
	_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_sprite.rotation_degrees.x = -90.0                   # lie flat, face the camera above
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED  # blended, so it can fade
	_sprite.shaded = false
	_sprite.no_depth_test = true
	_sprite.render_priority = 10
	_sprite.pixel_size = CameraView.PIXEL_SIZE
	_sprite.offset = Vector2(LENGTH_PX * 0.5, 0)          # the base (left edge) on the caster
	add_child(_sprite)

	var tw := create_tween()
	tw.tween_interval(GROW_TIME)
	tw.tween_callback(func(): _sprite.frame = 1)
	tw.tween_interval(GROW_TIME)
	tw.tween_callback(func(): _sprite.frame = 2)
	tw.tween_interval(HOLD_TIME)
	tw.tween_callback(func(): _sprite.frame = 3)
	tw.tween_interval(EMBER_TIME)
	tw.tween_callback(func(): _sprite.frame = 4)
	tw.tween_interval(EMBER_TIME)
	tw.tween_property(_sprite, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(queue_free)
