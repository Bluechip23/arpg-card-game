class_name CryonicsIceFX
extends Sprite3D

## Cryonics: the designer's ice spike (tools/cut_ice_spike.py), widened into
## a block of ice that encases the iced character and kept see-through so
## they show inside it (designer, 2026-10-23). It rises around them (shard,
## rising, full), stands for as long as the ice holds, and on the thaw
## cracks and shatters. Parented to the character.

const STRIP := "res://assets/sprites/generated/fx/ice_spike_strip.png"
const FRAMES := 5
const CELL := 128
const BASE := Vector2(61, 98)         # the spike body's middle (it leans a pixel off the tool's base point) on the feet
# The full spike's body is 10-15 px wide and tapers to its tip; a figure is
# ~22 px wide and ~32 px tall. Widened x2.6 at x0.7 height it is >= 25 px
# wide even at the head and covers the whole figure, its point rising a
# figure's height above.
const WIDEN := 2.6
const HEIGHT := 0.7
const CLEAR := 0.45                   # see-through: the character reads inside
const TINT := Color(0.85, 0.95, 1.1)
const NODE_NAME := "CryonicsIce"
const RISE_STEP := 0.07
const THAW_STEP := 0.1


## Encase `who` (a Player). One casing per character: casting again keeps it.
static func encase(who: Node3D) -> CryonicsIceFX:
	if who == null or not who.is_inside_tree():
		return null
	var have := who.get_node_or_null(NODE_NAME)
	if have is CryonicsIceFX:
		return have
	var fx := CryonicsIceFX.new()
	fx.name = NODE_NAME
	who.add_child(fx)
	fx._start()
	return fx


## The ice on `who` melts: crack, shatter, gone.
static func thaw(who: Node3D) -> void:
	if who == null:
		return
	var fx := who.get_node_or_null(NODE_NAME)
	if fx is CryonicsIceFX:
		(fx as CryonicsIceFX)._thaw()


func _start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture = load(STRIP)
	hframes = FRAMES
	frame = 0
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED   # blended, so it can be see-through
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shaded = false
	render_priority = 5
	pixel_size = CameraView.PIXEL_SIZE
	scale = Vector3(WIDEN, HEIGHT, 1.0)
	offset = Vector2(CELL * 0.5 - BASE.x, BASE.y - CELL * 0.5)  # the base on the character's feet
	# Lifted toward the camera above so the ice draws over the figure it holds.
	position = Vector3(0, CameraView.SPRITE_LIFT + 0.12, 0)
	modulate = Color(TINT.r, TINT.g, TINT.b, CLEAR)
	var tw := create_tween()
	tw.tween_interval(RISE_STEP)
	tw.tween_callback(func(): frame = 1)
	tw.tween_interval(RISE_STEP)
	tw.tween_callback(func(): frame = 2)


func _thaw() -> void:
	name = NODE_NAME + "Thawing"   # a new casting during the thaw starts its own
	var tw := create_tween()
	tw.tween_callback(func(): frame = 3)
	tw.tween_interval(THAW_STEP)
	tw.tween_callback(func(): frame = 4)
	tw.tween_interval(THAW_STEP * 1.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
