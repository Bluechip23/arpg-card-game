class_name ForestBackdrop
extends Control

## The Emerald Sanctum forest at night: sky gradient, aurora, stars and moon,
## a horizon line of the Craftpix forest pack's trees, mist, ground and
## drifting motes, with big framing trees at the sides. The title cutscene
## paints it under its actors (via the static draw_* functions); the other
## menu screens add this Control behind their content.
##
## Colours come from a palette dictionary (EmeraldTheme.PALETTE by default).

## Darkens the scene so a menu's panels and text read over it (0 = none).
@export var dim: float = 0.35
var palette: Dictionary = _menu_palette()
var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_backdrop(self, size, size.y * 0.80, _t, palette)
	draw_front_trees(self, size, palette)
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, dim))

## Menu screens keep their top-left for a Back button and tabs, so their
## moon hangs top-right instead.
static func _menu_palette() -> Dictionary:
	var pal: Dictionary = EmeraldTheme.PALETTE.duplicate()
	pal["moon_x"] = 0.9
	return pal

## Put a backdrop at the back of `root` (behind every other child).
static func add_to(root: Control, dim_amount: float = 0.35) -> ForestBackdrop:
	var bd := ForestBackdrop.new()
	bd.name = "ForestBackdrop"
	bd.dim = dim_amount
	root.add_child(bd)
	root.move_child(bd, 0)
	return bd

## The designer's Greenwood trees (tools/cut_prop_boards.py, 2026-10-29; was
## the forest pack's Tree1-11). Each old slot keeps its look and its height:
## `scale` below is the old factor, applied as the old pack tree's visible
## height (~76 px), so the skyline and the framing trees stand as tall.
const TREE_DIR := "res://assets/textures/props/boards/"
const TREES := {
	1: "forest_tree_big_2.png",   # round broadleaf
	2: "forest_tree_big_0.png",   # yellow-green conifer
	3: "forest_tree_big_3.png",   # broadleaf on pale roots
	5: "forest_tree_climb_0.png", # the great oak
	6: "forest_tree_big_1.png",   # columnar broadleaf
	11: "forest_tree_6.png",      # wide broadleaf
}
const OLD_TREE_H := 76.0
# Back row along the horizon: [tree, x as a fraction of the width, scale, y lift]
const BACK_TREES := [
	[1, 0.02, 2.0, 18.0], [5, 0.10, 2.0, 10.0], [2, 0.19, 2.0, 22.0], [6, 0.27, 2.0, 6.0],
	[11, 0.36, 2.0, 16.0], [3, 0.45, 2.0, 24.0], [5, 0.54, 2.0, 12.0], [1, 0.62, 2.0, 20.0],
	[6, 0.72, 2.0, 8.0], [2, 0.80, 2.0, 18.0], [11, 0.89, 2.0, 14.0], [3, 0.98, 2.0, 22.0],
]
# Big framing trees, half off the sides of the screen.
const FRONT_TREES := [[1, -0.03, 4.5], [5, 0.07, 3.2], [2, 1.03, 4.5], [6, 0.94, 3.0]]

static var _tree_cache: Dictionary = {}

## A tree pre-scaled with nearest-neighbour (crisp pixels under the
## project's linear canvas filter), cached per tree and scale: `factor` is
## the old pack factor, turned into this art's own by height.
static func tree_tex(index: int, factor: float) -> Texture2D:
	var key := "%d@%.2f" % [index, factor]
	if not _tree_cache.has(key):
		var path: String = TREE_DIR + str(TREES.get(index, TREES[1]))
		var tex := load(path) as Texture2D
		if tex == null:
			return null
		_tree_cache[key] = _bake(path, factor * OLD_TREE_H / float(tex.get_height()))
	return _tree_cache[key]

const GRASS := "res://assets/textures/ground/forest_grass.png"
static var _grass: Texture2D = null

static func _grass_tex() -> Texture2D:
	if _grass == null and ResourceLoader.exists(GRASS):
		_grass = _bake(GRASS, 2.0)
	return _grass

static func _bake(path: String, factor: float) -> ImageTexture:
	var img: Image = (load(path) as Texture2D).get_image()
	img.resize(int(img.get_width() * factor), int(img.get_height() * factor), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

static func draw_backdrop(ci: CanvasItem, size: Vector2, g: float, _t: float, pal: Dictionary) -> void:
	# Sky gradient (horizontal bands), then stars, moon, the horizon tree
	# line, mist, ground and drifting motes, all coloured by the palette.
	var sky_top: Color = pal.get("sky_top", Color(0.02, 0.05, 0.05))
	var sky_hz: Color = pal.get("sky_horizon", Color(0.07, 0.19, 0.13))
	var bands := 32
	for i in range(bands):
		var u := float(i) / float(bands - 1)
		ci.draw_rect(Rect2(0, g * u, size.x, g / bands + 1.0), sky_top.lerp(sky_hz, u * u))
	if pal.get("stars", true):
		for i in range(30):
			var sx := fposmod(float(i) * 197.31, size.x)
			var sy := fposmod(float(i) * 83.7, g * 0.55)
			var tw := 0.35 + 0.3 * sin(_t * 1.5 + i * 1.7)
			ci.draw_circle(Vector2(sx, sy), 1.3, Color(1, 1, 0.9, tw))
	# Moon (or a low sun when the style has no crescent)
	var moon_c := Vector2(size.x * float(pal.get("moon_x", 0.12)), size.y * 0.14)
	var moon: Color = pal.get("moon", Color(0.93, 0.95, 0.82))
	if pal.get("moon_crescent", true):
		ci.draw_circle(moon_c, 34.0, Color(moon, 0.12))
		ci.draw_circle(moon_c, 26.0, Color(moon, 0.92))
		ci.draw_circle(moon_c + Vector2(9.0, -4.0), 22.0, sky_top.lerp(sky_hz, 0.12))
	else:
		var sun_c := Vector2(size.x * 0.24, g - 46.0)
		for k in range(4):
			ci.draw_circle(sun_c, 70.0 - k * 12.0, Color(moon, 0.08 + k * 0.05))
		ci.draw_circle(sun_c, 30.0, Color(moon, 0.95))
	if pal.get("aurora", false):
		_draw_aurora(ci, size, g, _t)
	# Horizon tree line: pack trees darkened into a soft silhouette.
	var back_tint: Color = pal.get("tree_back", Color(0.13, 0.25, 0.18))
	for entry in BACK_TREES:
		draw_tree(ci, entry[0], Vector2(size.x * entry[1], g + 26.0 - entry[3]), entry[2], back_tint)
	# Mist lying in the glade.
	var mist: Color = pal.get("mist", Color(0, 0, 0, 0))
	if mist.a > 0.0:
		# Thin overlapping strips, densest just above the grass, so the
		# mist fades out softly instead of banding.
		var strips := 24
		for k in range(strips):
			var u := float(k) / float(strips - 1)
			var my := g - 110.0 + u * 110.0 + sin(_t * 0.4 + k * 0.7) * 3.0
			var a := mist.a * u * u * (0.75 + 0.25 * sin(_t * 0.3 + k * 0.9))
			ci.draw_rect(Rect2(0, my, size.x, 8.0), Color(mist, a))
	# Ground: the designer's Greenwood grass (2026-10-29), darkened to the
	# palette's night ground, tiled at the art's own pixels doubled.
	var ground_c: Color = pal.get("ground", Color(0.05, 0.12, 0.06))
	ci.draw_rect(Rect2(0, g, size.x, size.y - g), ground_c)
	var grass := _grass_tex()
	if grass:
		var tint := Color(minf(ground_c.r * 3.2, 1.0), minf(ground_c.g * 3.2, 1.0), minf(ground_c.b * 3.2, 1.0))
		ci.draw_texture_rect(grass, Rect2(0, g, size.x, size.y - g), true, tint)
	ci.draw_rect(Rect2(0, g, size.x, 3.0), pal.get("ground_edge", Color(0.10, 0.22, 0.10)))
	# Fireflies / dust motes drifting over the glade.
	var mote: Color = pal.get("motes", Color(0.85, 1.0, 0.45))
	for i in range(int(pal.get("mote_count", 24))):
		var seed := float(i) * 12.9898
		var mx := fposmod(seed * 37.0 + sin(_t * 0.35 + i) * 40.0 + _t * (6.0 + i % 5), size.x)
		var my := g - 30.0 - fposmod(seed * 23.0, g * 0.62) + sin(_t * 0.8 + i * 2.1) * 12.0
		var glow := 0.5 + 0.5 * sin(_t * (1.2 + (i % 4) * 0.35) + i)
		ci.draw_circle(Vector2(mx, my), 5.0, Color(mote, 0.10 * glow))
		ci.draw_circle(Vector2(mx, my), 1.8, Color(mote, 0.85 * glow))

static func _draw_aurora(ci: CanvasItem, size: Vector2, g: float, _t: float) -> void:
	## Slow ribbons of emerald and violet light across the upper sky.
	var cols := [Color(0.35, 1.0, 0.65), Color(0.55, 0.45, 1.0)]
	for r in range(2):
		var base_y := g * (0.16 + r * 0.12)
		var step := 8.0
		var x := 0.0
		while x < size.x:
			var u := x / size.x
			var y := base_y + sin(u * 5.5 + _t * 0.25 + r * 2.0) * 28.0 + sin(u * 13.0 - _t * 0.4) * 8.0
			var h := 70.0 + 30.0 * sin(u * 7.0 + _t * 0.3 + r)
			var a := 0.11 * (0.6 + 0.4 * sin(u * 9.0 + _t * 0.5 + r * 3.0))
			# Fade the ribbon in from its lower edge upward.
			for k in range(4):
				ci.draw_rect(Rect2(x, y - h * (k + 1) / 4.0, step, h / 4.0), Color(cols[r], a * (1.0 - k * 0.22)))
			x += step

static func draw_tree(ci: CanvasItem, index: int, foot: Vector2, factor: float, tint: Color) -> void:
	## One pack tree with its trunk base at `foot`, tinted (multiplied).
	var tex := tree_tex(index, factor)
	if tex == null:
		return
	var sz := tex.get_size()
	# The designer's trees are cut tight: their roots stand on the bottom edge.
	ci.draw_texture(tex, foot - Vector2(sz.x * 0.5, sz.y * 0.97), tint)

static func draw_front_trees(ci: CanvasItem, size: Vector2, pal: Dictionary) -> void:
	var tint: Color = pal.get("tree_front", Color(0.05, 0.10, 0.07))
	for entry in FRONT_TREES:
		draw_tree(ci, entry[0], Vector2(size.x * entry[1], size.y + 40.0), entry[2], tint)

