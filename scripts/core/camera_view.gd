class_name CameraView
extends RefCounted

## The one battle/town camera: a FIXED top-down three-quarter view.
##
## The purchased top-down packs (Craftpix character sheets and tilesets) are
## drawn for a single steep viewpoint — north is up, the camera never orbits.
## Every consumer of the view angle reads it from here so the world camera,
## the town camera, the ground-plane shadows and the capture harnesses can
## never disagree: `main.gd` / `town.gd` position their cameras from these,
## `BlobShadow` stretches its ellipse by the ground foreshortening, and
## `tests/capture_screenshots.gd` frames the README shots with them.
##
## Zoom (orthographic size) is still free; only the angle is locked.

## Horizontal angle. 0 = looking toward -Z, so screen-up is grid north and
## screen-right is +X (CharacterAnimator.Direction.SOUTH faces the camera).
const YAW_DEG := 0.0
## Steep three-quarter pitch. -90 would be a pure plan view (billboards
## edge-on and unreadable); -45 was the old free-orbit default. -65 keeps the
## ground within ~10% of 1:1 texel mapping while upright sprites still show
## their painted fronts, which is how the pack art is drawn.
const PITCH_DEG := -65.0

const YAW := YAW_DEG * PI / 180.0
const PITCH := PITCH_DEG * PI / 180.0


## Screen-height factor of a flat ground-plane length under this pitch:
## a 1-unit tile is drawn this many units tall (sin 65° ≈ 0.906).
static func ground_foreshortening() -> float:
	return absf(sin(PITCH))


## Camera offset from its focus point for a given orbit distance.
static func offset(distance: float) -> Vector3:
	return Vector3(
		sin(YAW) * cos(PITCH) * distance,
		-sin(PITCH) * distance,
		cos(YAW) * cos(PITCH) * distance
	)


## Orthographic frame size for a zoom distance: frame-matched to the old
## 75° perspective view so the zoom steps feel unchanged (16-bit pass).
static func ortho_size(distance: float) -> float:
	return 2.0 * distance * tan(deg_to_rad(75.0) * 0.5) * 0.62


## Place `camera` on the fixed view looking at `focus` from `distance`.
static func apply(camera: Camera3D, focus: Vector3, distance: float) -> void:
	camera.position = focus + offset(distance)
	camera.look_at(focus, Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ortho_size(distance)
