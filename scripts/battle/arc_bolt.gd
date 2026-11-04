class_name ArcBolt
extends Node3D

## A bolt of lightning between two points (the Djinn's Chain Lightning,
## designer 2026-11-04): the designer's ten-frame arc strip (Arc.png beside
## his sheets, tools/cut_pose_boards.py "djinn_arc") laid between `from` and
## `to`, stretched so its two glowing ends land on them, turned to face the
## camera as squarely as a line between those points can. It waits `delay`,
## flashes through its frames once and is gone.

## How far apart the arc's two glowing ends sit, as a share of its cell
## (measured on the packed strip: 0.67-0.85, most frames ~0.72; the frames
## fill their cells across).
const NODE_SPAN := 0.72
## Its thickness against the figure's own scale: the strip's glow is broad,
## and at full height the bolt read as a heavy band (2026-11-04).
const THICKNESS := 0.7
## Where the arc runs across its cell, from the cell's bottom (it is packed
## low in its cell: its middle sits ~0.7 of the way down).
const MID_FROM_BOTTOM := 0.3

var _sprite: Sprite3D
var _delay := 0.0
var _fps := 24.0
var _clock := 0.0
var _cell := 0
var _frames := 1


## Seconds from its launch until its flash is over.
func total_time() -> float:
	return _delay + float(_frames) / _fps


## `sheet`: the one-row strip in square cells; `texel`: world units a texel
## (the figure's pixel size times its rig scale); `smooth`: filter like the
## smooth figures. `from` / `to`: global positions of its two ends.
func launch(sheet: Texture2D, texel: float, smooth: bool, from: Vector3, to: Vector3,
		delay: float, fps: float = 24.0) -> void:
	_cell = sheet.get_height()
	_frames = maxi(1, int(sheet.get_width() / _cell))
	_delay = maxf(0.0, delay)
	_fps = maxf(1.0, fps)
	_sprite = Sprite3D.new()
	_sprite.texture = sheet
	_sprite.shaded = false
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.pixel_size = texel
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth \
			else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED   # its glow is soft: blended, not cut
	_sprite.no_depth_test = false
	_sprite.offset = Vector2(-_cell * 0.5, -_cell * MID_FROM_BOTTOM)
	add_child(_sprite)
	var span := to - from
	var length := span.length()
	var x := span / length if length > 0.001 else Vector3.RIGHT
	# Its plane holds the line and faces the camera as squarely as it can.
	var back := CameraView.toward_camera()
	var n := back - x * back.dot(x)
	if n.length() < 0.001:
		n = Vector3.UP - x * Vector3.UP.dot(x)
	n = n.normalized()
	var y := n.cross(x).normalized()
	var stretch := length / maxf(0.001, NODE_SPAN * _cell * texel)
	global_transform = Transform3D(Basis(x * stretch, y * THICKNESS, n), (from + to) * 0.5)
	_sprite.visible = _delay <= 0.0
	_show_frame(0)


func _show_frame(i: int) -> void:
	_sprite.region_rect = Rect2(clampi(i, 0, _frames - 1) * _cell, 0, _cell, _cell)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_clock += delta
	if _clock < _delay:
		return
	_sprite.visible = true
	var f := int((_clock - _delay) * _fps)
	if f >= _frames:
		queue_free()
		return
	_show_frame(f)
