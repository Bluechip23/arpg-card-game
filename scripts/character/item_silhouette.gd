class_name ItemSilhouette
extends Control

## Draws a faint, shadowed silhouette representing an equipment slot type.
## No per-item art is used — every item of a given type shares the same shadow
## shape (a ring for rings, a boot for boots, etc.).

var item_type: int = 0
var tint: Color = Color(0.34, 0.34, 0.44, 0.55)

func setup(t: int, faint: bool = true) -> void:
	item_type = t
	tint = Color(0.34, 0.34, 0.44, 0.55) if faint else Color(0.55, 0.55, 0.68, 0.8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var s: float = min(size.x, size.y)
	var c: Vector2 = size * 0.5
	var u: float = s * 0.52  # half-extent of the silhouette box
	match item_type:
		0: _draw_helm(c, u)
		1: _draw_chest(c, u)
		2: _draw_ring(c, u)
		3: _draw_belt(c, u)
		4: _draw_boots(c, u)
		5: _draw_gauntlets(c, u)
		6: _draw_weapon(c, u)
		7: _draw_quiver(c, u)

func _draw_helm(c: Vector2, u: float) -> void:
	# Dome + brow band
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var a: float = PI + PI * float(i) / float(steps)
		pts.append(c + Vector2(cos(a), sin(a)) * u * 0.9 + Vector2(0, u * 0.25))
	pts.append(c + Vector2(u * 0.9, u * 0.55))
	pts.append(c + Vector2(-u * 0.9, u * 0.55))
	draw_colored_polygon(pts, tint)
	draw_rect(Rect2(c + Vector2(-u * 0.95, u * 0.35), Vector2(u * 1.9, u * 0.32)), tint)

func _draw_chest(c: Vector2, u: float) -> void:
	# Cuirass: broad shoulders tapering to the waist
	var pts := PackedVector2Array([
		c + Vector2(-u * 0.95, -u * 0.75),
		c + Vector2(-u * 0.35, -u * 0.9),
		c + Vector2(u * 0.35, -u * 0.9),
		c + Vector2(u * 0.95, -u * 0.75),
		c + Vector2(u * 0.6, u * 0.9),
		c + Vector2(-u * 0.6, u * 0.9),
	])
	draw_colored_polygon(pts, tint)

func _draw_ring(c: Vector2, u: float) -> void:
	# Band (annulus) with a gem on top
	draw_circle(c + Vector2(0, u * 0.15), u * 0.78, tint)
	draw_circle(c + Vector2(0, u * 0.15), u * 0.44, Color(0, 0, 0, 0))
	# Punch the hole by redrawing centre in transparent — use blend by drawing bg-ish.
	# Godot has no true "erase"; approximate an annulus with an arc ring.
	draw_arc(c + Vector2(0, u * 0.15), u * 0.6, 0, TAU, 40, tint, u * 0.32)
	var gem := PackedVector2Array([
		c + Vector2(0, -u * 0.95),
		c + Vector2(u * 0.28, -u * 0.55),
		c + Vector2(0, -u * 0.2),
		c + Vector2(-u * 0.28, -u * 0.55),
	])
	draw_colored_polygon(gem, tint)

func _draw_belt(c: Vector2, u: float) -> void:
	draw_rect(Rect2(c + Vector2(-u * 0.98, -u * 0.28), Vector2(u * 1.96, u * 0.56)), tint)
	# Buckle
	draw_rect(Rect2(c + Vector2(-u * 0.26, -u * 0.42), Vector2(u * 0.52, u * 0.84)), tint)
	draw_rect(Rect2(c + Vector2(-u * 0.12, -u * 0.24), Vector2(u * 0.24, u * 0.48)), Color(0.1, 0.1, 0.13, 0.9))

func _draw_boots(c: Vector2, u: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-u * 0.35, -u * 0.9),
		c + Vector2(u * 0.1, -u * 0.9),
		c + Vector2(u * 0.1, u * 0.3),
		c + Vector2(u * 0.9, u * 0.35),
		c + Vector2(u * 0.9, u * 0.85),
		c + Vector2(-u * 0.35, u * 0.85),
	])
	draw_colored_polygon(pts, tint)

func _draw_gauntlets(c: Vector2, u: float) -> void:
	# Palm block + thumb
	draw_rect(Rect2(c + Vector2(-u * 0.5, -u * 0.55), Vector2(u * 1.0, u * 1.35)), tint)
	var thumb := PackedVector2Array([
		c + Vector2(-u * 0.5, -u * 0.15),
		c + Vector2(-u * 0.95, -u * 0.35),
		c + Vector2(-u * 0.8, u * 0.1),
		c + Vector2(-u * 0.5, u * 0.2),
	])
	draw_colored_polygon(thumb, tint)
	# Finger gaps
	for i in range(3):
		var x: float = -u * 0.3 + i * u * 0.32
		draw_rect(Rect2(c + Vector2(x - u * 0.04, -u * 0.55), Vector2(u * 0.08, u * 0.3)), Color(0.1, 0.1, 0.13, 0.9))

func _draw_weapon(c: Vector2, u: float) -> void:
	# A hand slot takes any weapon: sword (top-left), shield (top-right),
	# bow & arrow (bottom-left), and a spell book (bottom-right).
	var q: float = u * 0.5   # quadrant offset from centre
	var r: float = u * 0.42  # mini-icon half-extent
	_mini_sword(c + Vector2(-q, -q), r)
	_mini_shield(c + Vector2(q, -q), r)
	_mini_bow(c + Vector2(-q, q), r)
	_mini_book(c + Vector2(q, q), r)

func _mini_sword(p: Vector2, r: float) -> void:
	var blade := PackedVector2Array([
		p + Vector2(-r * 0.7, r * 0.7), p + Vector2(-r * 0.4, r * 0.4),
		p + Vector2(r * 0.85, -r * 0.75), p + Vector2(r * 0.95, -r * 0.35),
	])
	draw_colored_polygon(blade, tint)
	# Cross-guard + short grip toward the lower-left.
	draw_line(p + Vector2(-r * 0.85, r * 0.25), p + Vector2(-r * 0.2, r * 0.9), tint, maxf(1.5, r * 0.2))
	draw_line(p + Vector2(-r * 0.55, r * 0.55), p + Vector2(-r * 0.95, r * 0.95), tint, maxf(1.5, r * 0.22))

func _mini_shield(p: Vector2, r: float) -> void:
	var pts := PackedVector2Array([
		p + Vector2(-r * 0.8, -r * 0.8), p + Vector2(r * 0.8, -r * 0.8),
		p + Vector2(r * 0.8, r * 0.2), p + Vector2(0, r),
		p + Vector2(-r * 0.8, r * 0.2),
	])
	draw_colored_polygon(pts, tint)

func _mini_bow(p: Vector2, r: float) -> void:
	# Curved bow (right-opening arc) + a nocked arrow.
	draw_arc(p + Vector2(-r * 0.2, 0), r * 0.95, -PI * 0.55, PI * 0.55, 18, tint, maxf(1.5, r * 0.2))
	draw_line(p + Vector2(-r * 0.9, -r * 0.8), p + Vector2(-r * 0.9, r * 0.8), tint, maxf(1.0, r * 0.12))  # string
	draw_line(p + Vector2(-r * 0.9, 0), p + Vector2(r * 0.9, 0), tint, maxf(1.0, r * 0.14))  # shaft
	var head := PackedVector2Array([
		p + Vector2(r * 0.9, 0), p + Vector2(r * 0.55, -r * 0.28), p + Vector2(r * 0.55, r * 0.28),
	])
	draw_colored_polygon(head, tint)

func _mini_book(p: Vector2, r: float) -> void:
	# Closed spell book: cover, a spine down the left, page edges on the right,
	# and a small clasp crossing the fore-edge.
	draw_rect(Rect2(p + Vector2(-r * 0.78, -r * 0.7), Vector2(r * 1.56, r * 1.4)), tint)
	# Spine along the left edge, darker so it reads as a book.
	draw_rect(Rect2(p + Vector2(-r * 0.78, -r * 0.7), Vector2(r * 0.22, r * 1.4)), Color(0.1, 0.1, 0.13, 0.9))
	# Page edges: a thin dark inset just inside the right (fore) edge.
	draw_rect(Rect2(p + Vector2(r * 0.48, -r * 0.52), Vector2(r * 0.12, r * 1.04)), Color(0.1, 0.1, 0.13, 0.9))
	# Clasp: a short band poking off the fore-edge, centred vertically.
	draw_rect(Rect2(p + Vector2(r * 0.6, -r * 0.14), Vector2(r * 0.32, r * 0.28)), tint)

func _draw_quiver(c: Vector2, u: float) -> void:
	draw_rect(Rect2(c + Vector2(-u * 0.4, -u * 0.35), Vector2(u * 0.8, u * 1.2)), tint)
	# Arrow shafts poking out
	for i in range(3):
		var x: float = -u * 0.28 + i * u * 0.28
		draw_line(c + Vector2(x, -u * 0.35), c + Vector2(x, -u * 0.95), tint, u * 0.06)
		var head := PackedVector2Array([
			c + Vector2(x, -u * 0.98),
			c + Vector2(x - u * 0.1, -u * 0.78),
			c + Vector2(x + u * 0.1, -u * 0.78),
		])
		draw_colored_polygon(head, tint)
