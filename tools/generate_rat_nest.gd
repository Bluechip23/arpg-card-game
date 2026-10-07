extends SceneTree

## Draws the Rat King's nest battler: a 64x64 cell (same format as the other
## generated monsters) of a low heap of straw ringed with gnawed bones, dark
## at the hollow. Run once to (re)generate the sprite:
##   godot --headless --path . --script tools/generate_rat_nest.gd
## Output: assets/sprites/generated/monsters/rat_nest.png

const OUT := "res://assets/sprites/generated/monsters/rat_nest.png"
const SZ := 64

func _initialize() -> void:
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var straw := Color(0.72, 0.58, 0.30)
	var straw_lit := Color(0.84, 0.70, 0.40)
	var straw_dark := Color(0.48, 0.36, 0.18)
	var hollow := Color(0.22, 0.15, 0.09)
	var bone := Color(0.88, 0.86, 0.78)
	var bone_dark := Color(0.62, 0.58, 0.50)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# The heap: an ellipse sitting on the bottom third of the cell.
	var cx := 32.0
	var cy := 44.0
	var rx := 24.0
	var ry := 11.0
	for y in range(SZ):
		for x in range(SZ):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := dx * dx + dy * dy
			if d > 1.0:
				continue
			var c := straw
			# Rim lit from above, shaded underneath.
			if dy < -0.35 and d > 0.55:
				c = straw_lit
			elif dy > 0.3 or d > 0.85:
				c = straw_dark
			# Straw texture: streaks following the rim.
			if (x * 7 + y * 3) % 11 == 0:
				c = c.darkened(0.18)
			elif (x * 5 + y * 9) % 13 == 0:
				c = c.lightened(0.12)
			img.set_pixel(x, y, c)
	# The hollow: a smaller dark ellipse high on the heap.
	for y in range(SZ):
		for x in range(SZ):
			var dx := (x + 0.5 - cx) / 13.0
			var dy := (y + 0.5 - (cy - 3.0)) / 5.0
			if dx * dx + dy * dy <= 1.0:
				var c := hollow
				if dy < -0.4:
					c = hollow.darkened(0.3)
				img.set_pixel(x, y, c)
	# Loose straws poking out of the rim.
	for _i in range(14):
		var a := rng.randf_range(PI * 1.05, PI * 1.95)
		var sx := cx + cos(a) * rx * 0.95
		var sy := cy + sin(a) * ry * 0.95
		var len := rng.randi_range(3, 6)
		for t in range(len):
			var px := int(sx + cos(a) * t)
			var py := int(sy + sin(a) * t * 0.6)
			if px >= 0 and px < SZ and py >= 0 and py < SZ:
				img.set_pixel(px, py, straw_lit if t < 2 else straw)
	# Gnawed bones scattered on the heap.
	var bones := [Vector2i(14, 46), Vector2i(43, 48), Vector2i(26, 51), Vector2i(50, 42)]
	for b in bones:
		for t in range(6):
			var px: int = b.x + t
			var py: int = b.y + (t / 3)
			if px < SZ and py < SZ:
				img.set_pixel(px, py, bone)
				if py + 1 < SZ:
					img.set_pixel(px, py + 1, bone_dark)
		img.set_pixel(b.x, b.y - 1, bone)
		img.set_pixel(b.x + 5, b.y + 2, bone)
	# A skull in front: a pale knob with two dark sockets.
	for y in range(50, 57):
		for x in range(31, 39):
			var dx := (x + 0.5 - 35.0) / 4.0
			var dy := (y + 0.5 - 53.0) / 3.5
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, bone if dy < 0.3 else bone_dark)
	img.set_pixel(33, 53, hollow)
	img.set_pixel(36, 53, hollow)
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("[nest] saved %s (%s)" % [OUT, error_string(err)])
	quit()
