class_name WorldText
extends RefCounted

## One place that makes world-space text readable — not by inflating it, but
## by rendering it correctly:
##  - fixed_size: the label keeps ONE on-screen size at any camera zoom.
##  - Exact pixel mapping: the game camera displays a fixed-size glyph at
##    ~PX_FACTOR screen pixels per (font px x pixel_size). We render each
##    glyph at 2x its target screen size and scale down (supersampling), so
##    edges stay sharp instead of mip-blurred.
##  - LINEAR filtering without mipmaps: mip minification is what smeared the
##    old labels; at a controlled 2:1 ratio plain linear sampling is crisp.
##  - A dark outline proportional to the glyph size, and no depth test so a
##    wall or hill never buries a name tag.

# Measured on the game's orthographic camera at the design resolution
# (1280x720): a fixed_size label displays at font_size * pixel_size * 466
# screen pixels.
const PX_FACTOR := 466.0
const SUPERSAMPLE := 2.0

## target_px is the desired ON-SCREEN text height in pixels (at 720p design
## res). Pass 0 to derive it from the label's existing font size — sized for
## world space, ~0.8x maps into a sane screen size, clamped to 13..20.
static func crisp(label: Label3D, target_px: int = 0) -> Label3D:
	if target_px <= 0:
		target_px = clampi(roundi(label.font_size * 0.8), 13, 20)
	label.font_size = roundi(target_px * SUPERSAMPLE)
	label.pixel_size = 1.0 / (PX_FACTOR * SUPERSAMPLE)
	# Solid black outline ~22% of the displayed size — colored names must pop
	# against same-hue terrain (green troll name over green grass).
	label.outline_size = maxi(roundi(target_px * 0.22 * SUPERSAMPLE), 6)
	label.outline_modulate = Color(0, 0, 0, 1.0)
	label.fixed_size = true
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	label.render_priority = maxi(label.render_priority, 10)
	return label


## A damage / heal number that rises and fades above a unit, then frees
## itself. `at` is the world position to start from (callers roll their own
## horizontal jitter so the RNG order of a hit is unchanged); `outline_size`
## 0 keeps the Label3D default; `pop` bumps the font size up and back for
## the enemy hit numbers.
static func float_number(parent: Node, at: Vector3, text: String, color: Color, font_size: int,
		outline_size: int, rise: float, rise_time: float, fade_time: float, pop: bool = false) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	if outline_size > 0:
		label.outline_size = outline_size
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 50
	label.modulate = color
	label.position = at
	parent.add_child(label)

	var tween := label.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + rise, rise_time)
	tween.tween_property(label, "modulate:a", 0.0, fade_time).set_delay(0.3)
	if pop:
		# Slight scale up then down
		tween.tween_property(label, "font_size", label.font_size + 6, 0.1)
		tween.chain()
		tween.tween_property(label, "font_size", label.font_size, 0.3)
	tween.chain()
	tween.tween_callback(label.queue_free)
