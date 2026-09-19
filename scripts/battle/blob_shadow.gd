class_name BlobShadow
extends Sprite3D

## Flat elliptical contact shadow (style guide §4): a hard two-step ellipse
## quad lying on the ground plane. Never billboarded, never rotated with
## facing, never soft. Width ≈ 70% of the owner sprite's drawn width.
##
## The texture is a 32x16 ellipse (2:1). Lying flat, its depth is
## foreshortened by the camera pitch, so the quad is stretched along the
## ground by 1/sin(pitch) (CameraView) to keep the ON-SCREEN ellipse at the
## 2:1 the pack art paints under its own shadows — the same read at every
## zoom, and no re-tuning if the fixed pitch ever changes.

const TEXTURE := "res://assets/textures/blob_shadow.png"
## Screen aspect (height / width) the shadow should show.
const SCREEN_ASPECT := 0.5
## Texture aspect (16 / 32).
const TEXTURE_ASPECT := 0.5


static func attach(parent: Node3D, width: float) -> BlobShadow:
	var s := BlobShadow.new()
	s.name = "Shadow"
	s.texture = load(TEXTURE)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	# 32px texture spans `width` world units.
	s.pixel_size = width / 32.0
	s.rotation_degrees = Vector3(-90, 0, 0)  # flat on the ground
	# Local Y of the flat quad runs along world -Z (depth); scale it so the
	# foreshortened depth still reads as SCREEN_ASPECT of the width.
	var depth_stretch := SCREEN_ASPECT / TEXTURE_ASPECT / CameraView.ground_foreshortening()
	s.scale = Vector3(1.0, depth_stretch, 1.0)
	s.position = Vector3(0, 0.012, 0)
	s.sorting_offset = -0.5  # draw beneath the body sprite
	parent.add_child(s)
	return s


## Shrink slightly while the owner is airborne (hops, knockback).
func set_airborne_height(h: float) -> void:
	var f := clampf(1.0 - h * 0.45, 0.72, 1.0)
	var depth_stretch := SCREEN_ASPECT / TEXTURE_ASPECT / CameraView.ground_foreshortening()
	scale = Vector3(f, f * depth_stretch, f)
