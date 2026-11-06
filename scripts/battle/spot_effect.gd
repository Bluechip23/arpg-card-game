class_name SpotEffect
extends Node3D

## An effect played on one spot of the ground (the Rat King's Infest,
## designer 2026-11-04: a purple ring about the victim's feet, smoke rising
## from it, the smoke liquefying into little rats that crawl into the
## square): a one-row strip of the designer's frames (Infest.png beside his
## sheets, tools/cut_pose_boards.py "rat_king_infest"), a billboard on the
## spot that waits `delay`, plays its frames once and fades.

## Seconds its last frame takes to fade.
const FADE := 0.2

var _sprite: Sprite3D
var _delay := 0.0
var _fps := 10.0
var _clock := 0.0
var _cell := 0
var _frames := 1
var _fading := false
var _hold := false   # its last frame stays until it is freed (the Magma Spider's web lasts while the web does)
## Held, it fades once this returns false (the Crypt Crawler's web: while its
## victim still holds the Paralysis card) — or once whoever made it is gone.
## Checked every frame; unset, a held effect stays until it is freed.
var hold_while: Callable = Callable()


## Seconds from its launch until it is gone (until its last frame shows,
## when it holds it).
func total_time() -> float:
	return _delay + float(_frames) / _fps + (0.0 if _hold else FADE)


## `sheet`: the one-row strip in square cells; `texel`: world units a texel;
## `gutter`: empty rows under the art (the smooth sheets' SMOOTH_GUTTER);
## `smooth`: filter like the smooth figures; `at`: the spot (global, on the
## ground); `hang`: the share of the art's height that hangs below the spot
## (the ring is drawn about the feet, not under them).
func launch(sheet: Texture2D, texel: float, gutter: int, smooth: bool, at: Vector3,
		delay: float, fps: float, hang: float = 0.0, hold: bool = false, ground: bool = false) -> void:
	_hold = hold
	_cell = sheet.get_height()
	_frames = maxi(1, int(sheet.get_width() / _cell))
	_delay = maxf(0.0, delay)
	_fps = maxf(1.0, fps)
	var art_h := float(_cell - gutter)
	var img := sheet.get_image()
	if img:
		if img.is_compressed():
			img.decompress()
		art_h = float(img.get_used_rect().size.y)
	_sprite = Sprite3D.new()
	_sprite.texture = sheet
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.pixel_size = texel
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth \
			else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED   # its smoke is soft: blended, not cut
	_sprite.offset = Vector2(-_cell * 0.5, -gutter - art_h * hang)
	# `ground`: lying on the floor under whoever stands on it (the Magma
	# Spider's web), at the ground cover's height, below the standing figures.
	_sprite.position.y = CameraView.GROUND_COVER_LIFT if ground else CameraView.SPRITE_LIFT
	add_child(_sprite)
	global_position = at
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
	if f < _frames:
		_show_frame(f)
		return
	_show_frame(_frames - 1)
	if _hold and (hold_while.is_null() or (hold_while.is_valid() and hold_while.call())):
		return
	if not _fading:
		_fading = true
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate:a", 0.0, FADE)
		tw.tween_callback(queue_free)
