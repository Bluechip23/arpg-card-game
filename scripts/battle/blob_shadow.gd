class_name BlobShadow
extends Sprite3D

## Flat elliptical contact shadow (style guide §4): a hard two-step ellipse
## quad lying on the ground plane. Never billboarded, never rotated with
## facing, never soft. Width ≈ 70% of the owner sprite's drawn width.

const TEXTURE := "res://assets/textures/blob_shadow.png"


static func attach(parent: Node3D, width: float) -> BlobShadow:
	var s := BlobShadow.new()
	s.name = "Shadow"
	s.texture = load(TEXTURE)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	# 32px texture spans `width` world units.
	s.pixel_size = width / 32.0
	s.rotation_degrees = Vector3(-90, 0, 0)  # flat on the ground
	s.position = Vector3(0, 0.012, 0)
	s.sorting_offset = -0.5  # draw beneath the body sprite
	parent.add_child(s)
	return s


## Shrink slightly while the owner is airborne (hops, knockback).
func set_airborne_height(h: float) -> void:
	var f := clampf(1.0 - h * 0.45, 0.72, 1.0)
	scale = Vector3(f, f, f)
