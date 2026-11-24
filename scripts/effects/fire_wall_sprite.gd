class_name FireWallSprite
extends Node3D
## One tile of the Fire Goblin Shaman's Fire Wall (designer, 2026-11-24): his
## own wall strip (Wall.png beside his sheets, tools/cut_pose_boards.py
## "fire_goblin_shaman_wall") — a bed of burning rock whose flames kindle and
## rise, burn as a full sheet of fire while the wall stands, and die under
## black smoke when it goes (`die_out`). The other fire hazards (the Ifrit's
## breath, the Minotaur's wake) keep the pack flame, FireTileSprite.

const SHEETS := "res://assets/sprites/generated/sheets/fire_goblin_shaman"
const RISE := [0, 1, 2, 3]   # kindling, rising, the full sheet
const BURN := [3, 4]         # the two full frames, turned over while it stands
const DIE := [5, 6, 7]       # the flames sinking under smoke
const FPS := 8.0
const FADE := 0.25
## The share of its height that hangs below the tile's middle: the bed of
## rock lies across the tile, not behind it.
const HANG := 0.1
const SMOOTH_GUTTER := 8     # empty rows under the smooth strip's art

# This script's own path: the factory builds instances by loading it, so
# callers never depend on the global class cache (as FireTileSprite).
const SELF_PATH := "res://scripts/effects/fire_wall_sprite.gd"

var _sprite: Sprite3D
var _cell := 0
var _clock := 0.0
var _dying := false
var _fading := false


## The wall strip in the look the figures wear; "" when it has not been cut.
static func sheet_path() -> String:
	var soft := ArtStyle.smooth_folder(SHEETS)
	var path := "%s/Wall.png" % (soft if soft != "" else SHEETS)
	return path if ResourceLoader.exists(path) else ""


## A tile of the wall at `world_pos` (the tile's middle, on its ground), or
## null when the strip is missing (the caller falls back to the pack flame).
static func make(world_pos: Vector3) -> Node3D:
	var path := sheet_path()
	if path == "":
		return null
	var smooth := ArtStyle.smooth_folder(SHEETS) != ""
	var n: Node3D = load(SELF_PATH).new()
	var tex: Texture2D = load(path)
	n._cell = tex.get_height()
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.region_enabled = true
	s.centered = false
	s.pixel_size = 1.0 / (ArtStyle.SMOOTH_DENSITY if smooth else 64.0)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth \
			else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Soft flames and smoke that still sort against the figures by depth.
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS if smooth else SpriteBase3D.ALPHA_CUT_DISCARD
	var gutter := SMOOTH_GUTTER if smooth else 0
	s.offset = Vector2(-n._cell * 0.5, -gutter - (n._cell - gutter) * HANG)
	n._sprite = s
	n.add_child(s)
	# A hair under the figures' lift, so a unit standing in the fire draws in
	# front of it (as FireTileSprite).
	n.position = Vector3(world_pos.x, world_pos.y + CameraView.SPRITE_LIFT - 0.02, world_pos.z)
	n._show(RISE[0])
	return n


func _show(frame: int) -> void:
	_sprite.region_rect = Rect2(frame * _cell, 0, _cell, _cell)


## The wall is spent: the flames sink under smoke, then it is gone.
func die_out() -> void:
	if _dying:
		return
	_dying = true
	_clock = 0.0


func _process(delta: float) -> void:
	if _sprite == null or _fading:
		return
	_clock += delta
	var f := int(_clock * FPS)
	if _dying:
		if f < DIE.size():
			_show(DIE[f])
			return
		_fading = true
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate:a", 0.0, FADE)
		tw.tween_callback(queue_free)
		return
	if f < RISE.size():
		_show(RISE[f])
	else:
		_show(BURN[(f - RISE.size()) % BURN.size()])
