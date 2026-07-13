class_name PileIcon
extends RefCounted

## Procedural "stack of cards with an arrow" icon for the Draw and Discard
## piles. A fanned stack of layered cards (drawn isometrically) with a lifted
## top card and a bold coloured arrow through it — up for Draw, down for
## Discard. Built once per (direction, colour, flip) and cached.

const SZ := 44

static var _cache: Dictionary = {}


static func get_icon(up: bool, arrow_col: Color, flip: bool) -> Texture2D:
	var key := "%s_%s_%08x" % ["u" if up else "d", "f" if flip else "n", arrow_col.to_rgba32()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_stack(img)
	_draw_arrow(img, up, arrow_col)
	if flip:
		img.flip_x()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# =============================================================
# PRIMITIVES
# =============================================================

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)


static func _line(img: Image, a: Vector2, b: Vector2, c: Color, thick := 1.0) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) * 2 + 1
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		if thick <= 1.0:
			_px(img, int(round(p.x)), int(round(p.y)), c)
		else:
			var r := thick * 0.5
			for py in range(int(p.y - r), int(p.y + r) + 1):
				for px in range(int(p.x - r), int(p.x + r) + 1):
					if Vector2(px - p.x, py - p.y).length() <= r:
						_px(img, px, py, c)


static func _fill_tri(img: Image, a: Vector2, b: Vector2, c2: Vector2, col: Color) -> void:
	var minx := int(minf(a.x, minf(b.x, c2.x)))
	var maxx := int(maxf(a.x, maxf(b.x, c2.x)))
	var miny := int(minf(a.y, minf(b.y, c2.y)))
	var maxy := int(maxf(a.y, maxf(b.y, c2.y)))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var p := Vector2(px, py)
			var d0 := (b - a).cross(p - a)
			var d1 := (c2 - b).cross(p - b)
			var d2 := (a - c2).cross(p - c2)
			if not ((d0 < 0 or d1 < 0 or d2 < 0) and (d0 > 0 or d1 > 0 or d2 > 0)):
				_px(img, px, py, col)


static func _rhombus_outline(img: Image, cx: float, cy: float, hw: float, hh: float, c: Color, thick := 2.0) -> void:
	var l := Vector2(cx - hw, cy)
	var t := Vector2(cx, cy - hh)
	var r := Vector2(cx + hw, cy)
	var b := Vector2(cx, cy + hh)
	_line(img, l, t, c, thick)
	_line(img, t, r, c, thick)
	_line(img, r, b, c, thick)
	_line(img, b, l, c, thick)


static func _rhombus_fill(img: Image, cx: float, cy: float, hw: float, hh: float, c: Color) -> void:
	var l := Vector2(cx - hw, cy)
	var t := Vector2(cx, cy - hh)
	var r := Vector2(cx + hw, cy)
	var b := Vector2(cx, cy + hh)
	_fill_tri(img, l, t, r, c)
	_fill_tri(img, l, r, b, c)


# =============================================================
# ICON PARTS
# =============================================================

static func _draw_stack(img: Image) -> void:
	## A fanned stack of card layers (isometric rhombi) plus a lifted top card.
	var card := Color(0.95, 0.95, 0.97)
	var cx := 22.0
	var hw := 15.0
	var hh := 6.0
	# Four base layers fanning slightly to the right, bottom (37) to top (22).
	for i in range(4):
		var cy := 37.0 - i * 5.0
		var lean := i * 1.5
		_rhombus_outline(img, cx + lean, cy, hw, hh, card, 2.0)
	# Lifted top card, filled so it reads as the card being drawn.
	_rhombus_fill(img, cx + 6.0, 13.0, 13.0, 5.5, card)


static func _draw_arrow(img: Image, up: bool, col: Color) -> void:
	## A bold vertical arrow centred on the stack: head up for Draw, down for
	## Discard. Outlined in dark so it reads on top of the white cards.
	var cx := 20.0
	var outline := Color(0.08, 0.08, 0.1)
	if up:
		# Shaft then head near the top.
		_line(img, Vector2(cx, 20), Vector2(cx, 8), outline, 8.0)
		_fill_tri(img, Vector2(cx - 8, 8), Vector2(cx + 8, 8), Vector2(cx, 0), outline)
		_line(img, Vector2(cx, 19), Vector2(cx, 8), col, 5.0)
		_fill_tri(img, Vector2(cx - 6, 8), Vector2(cx + 6, 8), Vector2(cx, 1), col)
	else:
		_line(img, Vector2(cx, 22), Vector2(cx, 34), outline, 8.0)
		_fill_tri(img, Vector2(cx - 8, 34), Vector2(cx + 8, 34), Vector2(cx, 42), outline)
		_line(img, Vector2(cx, 23), Vector2(cx, 34), col, 5.0)
		_fill_tri(img, Vector2(cx - 6, 34), Vector2(cx + 6, 34), Vector2(cx, 41), col)
