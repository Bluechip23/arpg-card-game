extends SceneTree

## Cuts the Inflamed Minotaur battler out of the designer's painting
## (assets/sprites/paintings/inflamed_minotaur.webp, 797x542, lava background):
## two traced silhouettes (the body, and the flaming axe with its haft) mask
## the painting at full resolution, then it is box-filtered down 4x so the
## painting's pixel blocks land as single texels, with the mask's coverage
## as the alpha. Run once to (re)generate the sprite:
##   godot --headless --path . --script tools/cut_minotaur.gd
## Output: assets/sprites/generated/monsters/inflamed_minotaur.png (173x130)
## The paintings folder carries a .gdignore: the source is not a game asset.

const SRC := "res://assets/sprites/paintings/inflamed_minotaur.webp"
const OUT := "res://assets/sprites/generated/monsters/inflamed_minotaur.png"
const DOWN := 4

var body := PackedVector2Array([
	Vector2(440, 0), Vector2(480, 5), Vector2(510, 25), Vector2(550, 27), Vector2(560, 65), Vector2(545, 95),
	Vector2(525, 95), Vector2(560, 110), Vector2(585, 130), Vector2(605, 150), Vector2(612, 180), Vector2(598, 220),
	Vector2(595, 238), Vector2(585, 262), Vector2(598, 300), Vector2(625, 292), Vector2(630, 232), Vector2(640, 192),
	Vector2(655, 168), Vector2(672, 150), Vector2(700, 190), Vector2(702, 250), Vector2(692, 325), Vector2(682, 380),
	Vector2(652, 420), Vector2(630, 437), Vector2(600, 416), Vector2(592, 385), Vector2(578, 400), Vector2(577, 470),
	Vector2(586, 515), Vector2(520, 517), Vector2(500, 482), Vector2(480, 466), Vector2(450, 472), Vector2(410, 472),
	Vector2(385, 462), Vector2(372, 517), Vector2(280, 517), Vector2(272, 462), Vector2(284, 420), Vector2(296, 398),
	Vector2(302, 360), Vector2(322, 340), Vector2(343, 314), Vector2(343, 262), Vector2(320, 240), Vector2(293, 250),
	Vector2(258, 322), Vector2(236, 312), Vector2(232, 262), Vector2(238, 224),
	Vector2(262, 214), Vector2(268, 190), Vector2(276, 154), Vector2(300, 134), Vector2(312, 118), Vector2(336, 98),
	Vector2(346, 84), Vector2(360, 60), Vector2(350, 24), Vector2(386, 55), Vector2(396, 40), Vector2(420, 28),
])
var axe := PackedVector2Array([
	Vector2(50, 165), Vector2(70, 140), Vector2(100, 150), Vector2(122, 134), Vector2(150, 150), Vector2(176, 150),
	Vector2(196, 170), Vector2(188, 232), Vector2(226, 282), Vector2(258, 318), Vector2(294, 350), Vector2(290, 364),
	Vector2(250, 332), Vector2(226, 304), Vector2(166, 252), Vector2(112, 326), Vector2(60, 312), Vector2(22, 262), Vector2(14, 230),
	Vector2(30, 194),
])

func _inside(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, body) or Geometry2D.is_point_in_polygon(p, axe)

func _initialize() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	src.convert(Image.FORMAT_RGBA8)
	var crop := Rect2i(12, 0, 692, 520)  # x 12..704, y 0..520 -> 173 x 130 texels
	var w := crop.size.x / DOWN
	var h := crop.size.y / DOWN
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var rgb := Vector3.ZERO
			var cover := 0.0
			for sy in range(DOWN):
				for sx in range(DOWN):
					var px := crop.position.x + x * DOWN + sx
					var py := crop.position.y + y * DOWN + sy
					if _inside(Vector2(px + 0.5, py + 0.5)):
						var c := src.get_pixel(px, py)
						rgb += Vector3(c.r, c.g, c.b)
						cover += 1.0
			if cover > 0.0:
				rgb /= cover
			out.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, cover / float(DOWN * DOWN)))
	out.save_png(ProjectSettings.globalize_path(OUT))
	print("[mino] saved %s (%dx%d)" % [OUT, w, h])
	quit()
