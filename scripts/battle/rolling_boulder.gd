class_name RollingBoulder
extends Node3D

## The Grave Titan's boulder in flight (Boulder Roll, designer 2026-11-03):
## the designer's eight-frame rolling strip (Boulder.png in his sheets,
## tools/cut_pose_boards.py "grave_titan_boulder"), a billboard that waits
## for his throw's release frame, rolls along the ground from his hands to
## the target, then sinks into the dust and is gone. Drawn rolling right;
## mirrored when it rolls toward the screen's left.

## Tiles a second it rolls.
const SPEED := 4.0
## Frames a second it turns over while rolling.
const ROLL_FPS := 12.0
## Seconds it takes to fade where it stops.
const FADE := 0.25

var _sprite: Sprite3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _delay := 0.0
var _travel := 0.0
var _clock := 0.0
var _cell := 0
var _frames := 1
var _fading := false


## Seconds from its launch until it reaches the target (the delay and the roll).
func total_time() -> float:
	return _delay + _travel


## `sheet`: the one-row strip in square cells; `texel`: world units a texel
## (the figure's pixel size times its rig scale); `gutter`: empty rows under
## the art (the smooth sheets' SMOOTH_GUTTER); `smooth`: filter like the
## smooth figures. `from` / `to` are global ground positions.
func launch(sheet: Texture2D, texel: float, gutter: int, smooth: bool,
		from: Vector3, to: Vector3, delay: float) -> void:
	_cell = sheet.get_height()
	_frames = maxi(1, int(sheet.get_width() / _cell))
	_from = from
	_to = to
	_delay = maxf(0.0, delay)
	_travel = Vector2(to.x - from.x, to.z - from.z).length() / SPEED
	_sprite = Sprite3D.new()
	_sprite.texture = sheet
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.pixel_size = texel
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth \
			else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS if smooth else SpriteBase3D.ALPHA_CUT_DISCARD
	# Its foot at the node: the strip's bottom (less its gutter) on the ground.
	_sprite.offset = Vector2(-_cell * 0.5, -gutter)
	# Rolling toward the screen's left: the strip mirrored.
	_sprite.flip_h = to.x < from.x - 0.01
	_sprite.position.y = CameraView.SPRITE_LIFT
	add_child(_sprite)
	global_position = from
	_sprite.visible = _delay <= 0.0
	_show_frame(0)


func _show_frame(i: int) -> void:
	_sprite.region_rect = Rect2((i % _frames) * _cell, 0, _cell, _cell)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_clock += delta
	if _clock < _delay:
		return
	_sprite.visible = true
	var t := _clock - _delay
	if t < _travel:
		global_position = _from.lerp(_to, t / _travel)
		_show_frame(int(t * ROLL_FPS))
		return
	global_position = _to
	if not _fading:
		_fading = true
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate:a", 0.0, FADE)
		tw.tween_callback(queue_free)
