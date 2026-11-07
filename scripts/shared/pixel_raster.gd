extends RefCounted

## Pixel primitives for the procedural icon painters (StatusIcons and
## UIGlyphs drew their glyphs with two copies of these). Every write is
## clipped to the image.

static func plot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)


static func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			plot(img, px, py, c)


static func disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for py in range(int(cy - r), int(cy + r) + 1):
		for px in range(int(cx - r), int(cx + r) + 1):
			if Vector2(px - cx, py - cy).length() <= r:
				plot(img, px, py, c)


static func line(img: Image, x0: float, y0: float, x1: float, y1: float, c: Color, thick := 1.0) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0))) * 2 + 1
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := lerpf(x0, x1, t)
		var y := lerpf(y0, y1, t)
		if thick <= 1.0:
			plot(img, int(round(x)), int(round(y)), c)
		else:
			disc(img, x, y, thick * 0.5, c)


static func tri(img: Image, a: Vector2, b: Vector2, c2: Vector2, col: Color) -> void:
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
			var has_neg := d0 < 0 or d1 < 0 or d2 < 0
			var has_pos := d0 > 0 or d1 > 0 or d2 > 0
			if not (has_neg and has_pos):
				plot(img, px, py, col)
