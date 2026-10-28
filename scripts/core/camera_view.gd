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
## Ground cover (mushrooms, shrubs, tufts, pebbles, small rocks — anything up
## to GROUND_COVER_MAX_PX tall) sits a little lower: under the near-vertical
## camera a height difference outweighs a tile of depth, so characters always
## draw over it and walk on top of it. Trees and other tall props keep the
## full lift and still hide a character standing behind them.
const GROUND_COVER_LIFT := 0.18
const GROUND_COVER_MAX_PX := 36
## How much of a world-height offset shows as screen-up. Head-up labels and
## bars were placed for the old 65° view, where height projected at cos 65°;
## keeping that factor keeps them where they were on screen.
const HEIGHT_ON_SCREEN := 0.4226
## Texel scales the zoom steps through (screen pixels per texel).
const ZOOM_MIN := 1.0
const ZOOM_MAX := 5.0   # one step closer than before (designer, 2026-10-28)
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


# =============================================================
# KEEPING THE WORLD UNDER THE SPRITES
# =============================================================
# Under the near-vertical camera height decides depth (a unit of height
# outweighs ~57 tiles of row), so anything built taller than SPRITE_LIFT —
# a building's walls, a lamp post, a gate's pillars — covers every sprite
# whose art reaches over it on screen, even a character standing south of it
# (the heroes, 1.6 tiles tall, reach well over what is north of them).
# Seen from straight above that height doesn't show at all, so structures
# are kept under the sprites instead.

## The highest a structure's meshes may stand: just under the sprites.
const STRUCTURE_TOP := 0.26


## Stand a billboard on its feet at the sprite height (the art's bottom row
## on the ground point) instead of hanging it from its centre higher up —
## so it sorts with every other figure by row.
static func stand_on_ground(s: Sprite3D, lift: float = SPRITE_LIFT) -> void:
	var w: float = s.region_rect.size.x if s.region_enabled else float(s.texture.get_width())
	s.centered = false
	s.offset = Vector2(-w * 0.5, 0.0)
	s.position.y = lift


## Squash a structure's meshes (everything under `root`) vertically, by one
## factor about the ground, so the tallest ends at STRUCTURE_TOP. From above
## it looks the same; it just no longer outranks the sprites standing by it.
## Parts already on the ground (shadows, paving: under GROUND_PART) are left
## alone; sprites, labels, lights and collision are untouched.
const GROUND_PART := 0.03

static func flatten_below_sprites(root: Node3D) -> void:
	var parts: Array = []
	var top := 0.0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var to_root := _transform_to(mi, root)
		var box: AABB = to_root * mi.get_aabb()
		if box.end.y <= GROUND_PART:
			continue
		parts.append([mi, to_root])
		top = maxf(top, box.end.y)
	if top <= STRUCTURE_TOP:
		return
	var squash := Transform3D(Basis.from_scale(Vector3(1.0, STRUCTURE_TOP / top, 1.0)), Vector3.ZERO)
	for p in parts:
		var mi: MeshInstance3D = p[0]
		var parent_to_root := _transform_to(mi.get_parent(), root)
		mi.transform = parent_to_root.affine_inverse() * squash * p[1]


## `node`'s transform in `root`'s space (walking the parents, so it works
## before the structure is in the scene tree).
static func _transform_to(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
