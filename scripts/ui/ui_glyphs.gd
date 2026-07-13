class_name UIGlyphs
extends RefCounted

## Small procedural pixel-art glyphs for HUD buttons and badges (a sword for
## Attack, a raised hand for Wait, a stop sign for Pause, a cage for jailed
## cards, …). Drawn once and cached, same style as StatusIcons.

const SZ := 24

static var _cache: Dictionary = {}


static func get_glyph(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match key:
		"sword": _draw_sword(img)
		"wait_hand": _draw_wait_hand(img)
		"stop_sign": _draw_stop_sign(img)
		"play": _draw_play(img)
		"shield": _draw_shield(img)
		"cage": _draw_cage(img)
		"raindrop": _draw_raindrop(img)
		_:
			_cache[key] = null
			return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# =============================================================
# DRAWING PRIMITIVES
# =============================================================

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < SZ and y >= 0 and y < SZ:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			_px(img, px, py, c)


static func _line(img: Image, x0: float, y0: float, x1: float, y1: float, c: Color, thick := 1.0) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0))) * 2 + 1
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := lerpf(x0, x1, t)
		var y := lerpf(y0, y1, t)
		if thick <= 1.0:
			_px(img, int(round(x)), int(round(y)), c)
		else:
			for py in range(int(y - thick * 0.5), int(y + thick * 0.5) + 1):
				for px in range(int(x - thick * 0.5), int(x + thick * 0.5) + 1):
					if Vector2(px - x, py - y).length() <= thick * 0.5:
						_px(img, px, py, c)


static func _tri(img: Image, a: Vector2, b: Vector2, c2: Vector2, col: Color) -> void:
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
				_px(img, px, py, col)


# =============================================================
# GLYPHS
# =============================================================

static func _draw_sword(img: Image) -> void:
	## Diagonal blade with crossguard and pommel, tip pointing up-right.
	var blade := Color(0.82, 0.84, 0.9)
	var edge := Color(0.6, 0.63, 0.72)
	var hilt := Color(0.55, 0.38, 0.16)
	var gold := Color(0.85, 0.68, 0.25)
	_line(img, 8, 15, 19, 4, blade, 2.4)
	_line(img, 9.5, 16.5, 20, 6, edge, 1.0)
	_tri(img, Vector2(19, 2), Vector2(22, 5), Vector2(18, 6), blade)  # tip
	_line(img, 4.5, 12.5, 10.5, 18.5, gold, 2.2)  # crossguard
	_line(img, 6, 17, 3.5, 19.5, hilt, 2.4)  # grip
	_rect(img, 2, 20, 3, 3, gold)  # pommel

static func _draw_wait_hand(img: Image) -> void:
	## Raised open palm ("hold on").
	var skin := Color(0.92, 0.86, 0.72)
	var shade := Color(0.75, 0.68, 0.55)
	# Palm
	_rect(img, 8, 11, 9, 8, skin)
	_rect(img, 8, 18, 8, 2, shade)
	# Four fingers
	_rect(img, 8, 4, 2, 8, skin)
	_rect(img, 11, 3, 2, 9, skin)
	_rect(img, 14, 4, 2, 8, skin)
	_rect(img, 16, 6, 2, 6, skin)
	# Thumb out to the left
	_line(img, 7, 14, 4, 11, skin, 2.2)
	# Cuff
	_rect(img, 9, 20, 7, 2, Color(0.35, 0.4, 0.6))

static func _draw_stop_sign(img: Image) -> void:
	## Red octagon (stop sign without the word).
	var red := Color(0.78, 0.12, 0.12)
	var rim := Color(0.95, 0.9, 0.9)
	var c := SZ * 0.5 - 0.5
	# Octagon: |dx| + |dy| clipped square (cut corners at 45°)
	var half := 10.0
	var cut := 4.2
	for py in range(SZ):
		for px in range(SZ):
			var dx := absf(px - c)
			var dy := absf(py - c)
			if dx <= half and dy <= half and dx + dy <= half * 2.0 - cut:
				img.set_pixel(px, py, red)
	# Thin light rim so it reads on dark buttons
	for py in range(SZ):
		for px in range(SZ):
			var dx := absf(px - c)
			var dy := absf(py - c)
			var inside := dx <= half and dy <= half and dx + dy <= half * 2.0 - cut
			var inside_inner := dx <= half - 1.4 and dy <= half - 1.4 and dx + dy <= half * 2.0 - cut - 2.0
			if inside and not inside_inner:
				img.set_pixel(px, py, rim)

static func _draw_play(img: Image) -> void:
	## Green play triangle (shown on the pause button while paused).
	_tri(img, Vector2(7, 4), Vector2(7, 20), Vector2(20, 12), Color(0.25, 0.75, 0.3))

static func _draw_shield(img: Image) -> void:
	var steel := Color(0.45, 0.55, 0.75)
	var rim := Color(0.75, 0.8, 0.9)
	for py in range(3, 21):
		# Shield silhouette: straight sides tapering to a point at the bottom.
		var w: int
		if py <= 12:
			w = 8
		else:
			w = 8 - (py - 12)
		if w <= 0:
			continue
		for px in range(12 - w, 12 + w):
			var col := steel
			if py == 3 or px == 12 - w or px == 11 + w or (py > 12 and py == 20 - (8 - w)):
				col = rim
			_px(img, px, py, col)
	_line(img, 12, 5, 12, 18, rim, 1.0)

static func _draw_cage(img: Image) -> void:
	## Birdcage: domed top, vertical bars, solid base.
	var bar := Color(0.78, 0.78, 0.85)
	var dark := Color(0.5, 0.5, 0.58)
	# Hanging ring
	_rect(img, 11, 1, 2, 2, bar)
	# Dome
	_line(img, 5, 8, 12, 3, bar, 1.2)
	_line(img, 12, 3, 19, 8, bar, 1.2)
	# Top rail and base
	_rect(img, 4, 8, 16, 2, bar)
	_rect(img, 4, 20, 16, 2, bar)
	_rect(img, 5, 22, 14, 1, dark)
	# Vertical bars
	for bx in [5, 9, 13, 17]:
		_rect(img, bx, 10, 2, 10, bar)
	# Shadow between bars
	for bx in [7, 11, 15]:
		_rect(img, bx + 1, 10, 1, 10, Color(0.2, 0.2, 0.25, 0.6))

static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for py in range(int(cy - r), int(cy + r) + 1):
		for px in range(int(cx - r), int(cx + r) + 1):
			if Vector2(px - cx, py - cy).length() <= r:
				_px(img, px, py, c)

static func _fill_teardrop(img: Image, cx: float, cy: float, r: float, apex_y: float, col: Color) -> void:
	## Round bottom (disc at cx,cy) merged with a point at (cx, apex_y).
	var apex := Vector2(cx, apex_y)
	var bl := Vector2(cx - r, cy)
	var br := Vector2(cx + r, cy)
	for py in range(int(apex_y), int(cy + r) + 1):
		for px in range(int(cx - r) - 1, int(cx + r) + 2):
			var p := Vector2(px, py)
			var in_disc := (p - Vector2(cx, cy)).length() <= r
			# Point-in-triangle for the upper spike.
			var d0 := (bl - apex).cross(p - apex)
			var d1 := (br - bl).cross(p - bl)
			var d2 := (apex - br).cross(p - br)
			var in_tri := not ((d0 < 0 or d1 < 0 or d2 < 0) and (d0 > 0 or d1 > 0 or d2 > 0))
			if in_disc or in_tri:
				_px(img, px, py, col)

static func _draw_raindrop(img: Image) -> void:
	## Blue teardrop: pointed top, round bottom, with a small highlight.
	var body := Color(0.35, 0.62, 1.0)
	var edge := Color(0.12, 0.28, 0.6)
	var hi := Color(0.72, 0.86, 1.0)
	_fill_teardrop(img, 12.0, 15.0, 8.0, 1.0, edge)      # outline
	_fill_teardrop(img, 12.0, 15.0, 6.6, 3.5, body)      # body
	_disc(img, 9.5, 13.0, 1.7, hi)                        # highlight
