class_name CameraView
extends RefCounted

## The one battle/town camera: a FIXED plan view that shows the pack art
## exactly as drawn.
##
## The purchased top-down packs (Craftpix tiles, props and character
## sheets) are 2D art: a tile is 32 texels, a character stands on its tile
## and extends north. This camera looks straight down (a hair off vertical
## so that things further south are nearer the camera and draw on top —
## classic y-sorting for free), north is up, and the orthographic size is
## chosen so every texel covers a WHOLE number of screen pixels. Nothing in
## the world is drawn at a fractional scale; the world viewport renders at
## full resolution. Zoom is a texel scale of 1..4, not a distance.
##
## Every consumer reads the angle from here (`main.gd`, `town.gd`, the
## ground-plane shadows, the label mirror, the capture harnesses).

## Horizontal angle. 0 = looking toward -Z, so screen-up is grid north and
## screen-right is +X (CharacterAnimator.Direction.SOUTH faces the camera).
const YAW_DEG := 0.0
## One degree off a pure plan view: the ground and every billboard map 1:1
## to within 0.02%, while a sprite one tile further south sits 0.017 units
## nearer the camera, so depth sorts sprites by row without any hacks.
const PITCH_DEG := -89.0

const YAW := YAW_DEG * PI / 180.0
const PITCH := PITCH_DEG * PI / 180.0

## Texels per world unit (style guide §1: 1 grid tile = one 32-texel tile).
const TEXELS_PER_UNIT := 32.0
## Sprite3D / billboard pixel_size that puts one texel on one 32nd of a unit.
const PIXEL_SIZE := 1.0 / TEXELS_PER_UNIT
## Height every billboard sprite (characters, enemies, props, chests) is
## lifted off the ground. Under the plan camera height barely moves a point
## on screen (cos 89° per unit) but it decides depth: a sprite must sit
## nearer the camera than any wall slab or plateau (WALL_HEIGHT + 2 ×
## ELEV_STEP ≈ 0.18) so a wall north of it can never draw over its head.
const SPRITE_LIFT := 0.3
## How much of a world-height offset shows as screen-up. Head-up labels and
## bars were placed for the old 65° view, where height projected at cos 65°;
## keeping that factor keeps them where they were on screen.
const HEIGHT_ON_SCREEN := 0.4226
## Texel scales the zoom steps through (screen pixels per texel).
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const ZOOM_DEFAULT := 2.0


## Screen-height factor of a flat ground-plane length under this pitch.
static func ground_foreshortening() -> float:
	return absf(sin(PITCH))


## Camera offset from its focus point (any distance works under an
## orthographic camera; this one clears the tallest fog box).
static func offset(distance: float = 30.0) -> Vector3:
	return Vector3(
		sin(YAW) * cos(PITCH) * distance,
		-sin(PITCH) * distance,
		cos(YAW) * cos(PITCH) * distance
	)


## Orthographic frame height in world units for a texel scale and a
## viewport height in pixels: `scale` screen pixels per texel, exactly.
static func ortho_size(scale: float, viewport_height: float) -> float:
	var s := clampf(roundf(scale), ZOOM_MIN, ZOOM_MAX)
	return maxf(1.0, viewport_height) / (s * TEXELS_PER_UNIT)


## World units per screen pixel at a texel scale.
static func units_per_pixel(scale: float) -> float:
	return 1.0 / (clampf(roundf(scale), ZOOM_MIN, ZOOM_MAX) * TEXELS_PER_UNIT)


## Place `camera` on the fixed view looking at `focus`, framed for `scale`
## screen pixels per texel in a viewport `viewport_height` pixels tall.
static func apply(camera: Camera3D, focus: Vector3, scale: float, viewport_height: float) -> void:
	# Near-vertical view: the world up vector is parallel to the view, so
	# frame with north (-Z) as the camera's up instead.
	camera.look_at_from_position(focus + offset(), focus, Vector3(0, 0, -1))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ortho_size(scale, viewport_height)
	camera.near = 0.05
	camera.far = 200.0
