class_name WorldText
extends RefCounted

## One place that makes world-space text readable. Every persistent Label3D
## (names, portals, waypoints, prompts) should pass through crisp(): it
## switches the label to constant screen size (fixed_size + pixel_size 0.001)
## so it stays the same legible size at ANY camera zoom, guarantees a dark
## outline behind the glyphs, and draws over geometry so a wall or hill can
## never bury a name tag.

static func crisp(label: Label3D, font_px: int = 0) -> Label3D:
	if font_px > 0:
		label.font_size = font_px
	else:
		# Labels were sized for world-space rendering (pixel_size 0.01);
		# rescale into readable screen pixels, never below 28.
		label.font_size = maxi(roundi(label.font_size * 1.5), 28)
	if label.outline_size < 8:
		label.outline_size = 8
	if label.outline_modulate.a < 0.5:
		label.outline_modulate = Color(0, 0, 0, 0.85)
	# 0.0015 at fixed_size ≈ 0.7 screen px per font px — a 40px font reads
	# as ~28px text on a 720p viewport, comfortably legible when zoomed out.
	label.pixel_size = 0.0015
	label.fixed_size = true
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.render_priority = maxi(label.render_priority, 10)
	return label
