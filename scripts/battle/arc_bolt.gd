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
var _cols := 1
var _mirrored := false   # drawn from the strip's mirror image (it runs toward the screen's left)
## Driven from outside (VortexPath picks its frame each tick with show_frame):
## its own clock is off.
var manual := false

## Mirror images of the strips, made once each (see launch).
static var _mirrors: Dictionary = {}

static func _mirror_of(sheet: Texture2D) -> Texture2D:
	var key := sheet.resource_path if sheet.resource_path != "" else str(sheet.get_instance_id())
	if not _mirrors.has(key):
		var img := sheet.get_image()
		if img.is_compressed():
			img.decompress()
		var mips := img.has_mipmaps()
		img.clear_mipmaps()
		img.flip_x()
		if mips:
			img.generate_mipmaps()
		_mirrors[key] = ImageTexture.create_from_image(img)
	return _mirrors[key]


## Seconds from its launch until its flash is over.
func total_time() -> float:
	return _delay + float(_frames) / _fps


## `sheet`: the one-row strip in square cells; `texel`: world units a texel
## (the figure's pixel size times its rig scale); `smooth`: filter like the
## smooth figures. `from` / `to`: global positions of its two ends.
## `on_top`: drawn over everything (see below). `end_span` / `mid` / `thickness` stand in for NODE_SPAN, MID_FROM_BOTTOM and
## THICKNESS for another strip (the Ash Harpy's vortex) when given (>0).
func launch(sheet: Texture2D, texel: float, smooth: bool, from: Vector3, to: Vector3,
		delay: float, fps: float = 24.0, end_span: float = 0.0, mid: float = -1.0,
		thickness: float = 0.0, rows: int = 1, on_top: bool = false) -> void:
	var node_span := end_span if end_span > 0.0 else NODE_SPAN
	var mid_from_bottom := mid if mid >= 0.0 else MID_FROM_BOTTOM
	var thick := thickness if thickness > 0.0 else THICKNESS
	# A long strip comes in `rows` rows of square cells (the Harpy's vortex).
	_cell = int(sheet.get_height() / maxi(1, rows))
	_cols = maxi(1, int(sheet.get_width() / _cell))
	_frames = _cols * maxi(1, rows)
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
	# `on_top`: over the figures it lies across (the Harpy's vortex), as the
	# heroes' spell effects are (no depth test, a raised render priority).
	_sprite.no_depth_test = on_top
	if on_top:
		_sprite.render_priority = 10
	_sprite.offset = Vector2(-_cell * 0.5, -_cell * mid_from_bottom)
	add_child(_sprite)
	var span := to - from
	var length := span.length()
	var x := span / length if length > 0.001 else Vector3.RIGHT
	# Its plane holds the line and faces the camera as squarely as it can,
	# its art kept upright on screen: run toward the screen's left, it is
	# mirrored, not turned upside down (the Harpy's vortex has a top).
	var up := CameraView.screen_up()
	var y := up - x * up.dot(x)
	if y.length() < 0.2:
		var back := CameraView.toward_camera()
		var nn := (back - x * back.dot(x)).normalized()
		y = nn.cross(x)
	y = y.normalized()
	var n := x.cross(y).normalized()
	if n.dot(CameraView.toward_camera()) < 0.0:
		# Running toward the screen's left the plane would face away and is
		# not drawn from behind (nor is a flip_h'd soft sprite, on the
		# Compatibility renderer): turn it round and draw the strip's mirror
		# image, so its left end still lands on `from`.
		x = -x
		n = -n
		_mirrored = true
		_sprite.texture = _mirror_of(sheet)
	var stretch := length / maxf(0.001, node_span * _cell * texel)
	global_transform = Transform3D(Basis(x * stretch, y * thick, n), (from + to) * 0.5)
	_sprite.visible = _delay <= 0.0
	_show_frame(0)


func _show_frame(i: int) -> void:
	var f := clampi(i, 0, _frames - 1)
	var col := f % _cols
	if _mirrored:
		col = _cols - 1 - col   # the mirror image's rows run backward
	_sprite.region_rect = Rect2(col * _cell, (f / _cols) * _cell, _cell, _cell)


## For a driven bolt (`manual`): show frame `i`, or nothing for -1.
func show_frame(i: int) -> void:
	if _sprite == null:
		return
	_sprite.visible = i >= 0
	if i >= 0:
		_show_frame(i)


func _process(delta: float) -> void:
	if _sprite == null or manual:
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
