class_name StatusIcons
extends RefCounted

## Procedural pixel-art badge for every buff and debuff, drawn once and cached.
## Used anywhere a status effect is shown: the player buff/debuff bars, the
## enemy inspect panel, and the unit tracker. Glyphs follow the design table
## in the status-effects spreadsheet (an arm flexing for Strengthen, an anvil
## for Smith, a syringe for Morphine, and so on).
##
## StatusIcons.get_icon("Life Steal") -> Texture2D (null if no glyph exists,
## in which case callers fall back to their old colour swatch).

const SZ := 24

static var _cache: Dictionary = {}


static func get_icon(effect_name: String) -> Texture2D:
	var key := effect_name.to_lower().replace(" ", "_").replace("'", "")
	# Enemy-side effect names that differ from the player debuff names.
	match key:
		"slow": key = "slowed"
		"shock": key = "shocked"
		"stunned": key = "stun"
		"weaken": key = "weakened"
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if not _draw(img, key):
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


static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for py in range(int(cy - r), int(cy + r) + 1):
		for px in range(int(cx - r), int(cx + r) + 1):
			if Vector2(px - cx, py - cy).length() <= r:
				_px(img, px, py, c)


static func _ring(img: Image, cx: float, cy: float, r: float, thick: float, c: Color) -> void:
	for py in range(int(cy - r) - 1, int(cy + r) + 2):
		for px in range(int(cx - r) - 1, int(cx + r) + 2):
			var d := Vector2(px - cx, py - cy).length()
			if d <= r and d >= r - thick:
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
			_disc(img, x, y, thick * 0.5, c)


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


static func _drop(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	# Teardrop: round bottom, pointed top.
	_disc(img, cx, cy, r, c)
	_tri(img, Vector2(cx - r, cy - 1), Vector2(cx + r, cy - 1), Vector2(cx, cy - r * 2.4), c)


static func _shield(img: Image, cx: float, top: float, w: float, h: float, c: Color) -> void:
	# Heater shield: flat top, sides tapering to a point.
	var half := w * 0.5
	_rect(img, int(cx - half), int(top), int(w), int(h * 0.45), c)
	_tri(img, Vector2(cx - half, top + h * 0.45 - 1), Vector2(cx + half, top + h * 0.45 - 1), Vector2(cx, top + h), c)


# =============================================================
# GLYPHS
# =============================================================

static func _draw(img: Image, key: String) -> bool:
	var skin := Color(0.85, 0.68, 0.52)
	var steel := Color(0.68, 0.72, 0.78)
	var dark := Color(0.16, 0.16, 0.2)
	var wood := Color(0.55, 0.38, 0.2)
	match key:
		# ---------------- BUFFS ----------------
		"strengthen":
			# An arm flexing: forearm up, bicep bump.
			_rect(img, 4, 15, 12, 4, skin)                    # upper arm (horizontal)
			_disc(img, 8, 12, 4, skin)                        # bicep bump
			_rect(img, 14, 7, 4, 10, skin)                    # forearm raised
			_disc(img, 16, 6, 3, skin)                        # fist
		"enlightened":
			# A crit sparkle: four-point star.
			var gold := Color(1.0, 0.95, 0.5)
			_tri(img, Vector2(12, 2), Vector2(9, 12), Vector2(15, 12), gold)
			_tri(img, Vector2(12, 22), Vector2(9, 12), Vector2(15, 12), gold)
			_tri(img, Vector2(2, 12), Vector2(12, 9), Vector2(12, 15), gold)
			_tri(img, Vector2(22, 12), Vector2(12, 9), Vector2(12, 15), gold)
			_disc(img, 12, 12, 2.5, Color(1.0, 1.0, 0.85))
		"life_steal":
			# Vampire fangs under a red gum line.
			_rect(img, 5, 6, 14, 3, Color(0.7, 0.12, 0.2))
			_tri(img, Vector2(7, 9), Vector2(11, 9), Vector2(9, 18), Color(0.97, 0.97, 1.0))
			_tri(img, Vector2(13, 9), Vector2(17, 9), Vector2(15, 18), Color(0.97, 0.97, 1.0))
		"weakened":
			# A drooping sword: blade sagging left with a blue-grey down arrow.
			var wkn := Color(0.5, 0.5, 0.8)
			_rect(img, 13, 6, 3, 9, steel)
			_line(img, 13, 6, 10, 4, steel)                   # drooped tip
			_rect(img, 11, 15, 7, 2, wood)
			_rect(img, 13, 17, 2, 4, wood)
			_rect(img, 5, 5, 2, 8, wkn)
			_tri(img, Vector2(3, 13), Vector2(9, 13), Vector2(6, 18), wkn)
		"wear_down":
			# A blade being ground down: chipped sword + red arrow pressing down.
			_rect(img, 13, 4, 4, 11, steel)
			_px(img, 13, 6, Color(0, 0, 0, 0)); _px(img, 16, 9, Color(0, 0, 0, 0))  # chips
			_rect(img, 10, 15, 10, 2, wood)
			_rect(img, 14, 17, 2, 5, wood)
			_rect(img, 5, 5, 2, 8, Color(0.85, 0.25, 0.2))
			_tri(img, Vector2(3, 13), Vector2(9, 13), Vector2(6, 18), Color(0.85, 0.25, 0.2))
		"armor_break":
			# Shield with a crack running down the middle.
			_shield(img, 12, 4, 14, 17, steel)
			_line(img, 12, 4, 10, 9, dark, 1.5)
			_line(img, 10, 9, 14, 14, dark, 1.5)
			_line(img, 14, 14, 12, 20, dark, 1.5)
		"fortify":
			# A small brown rook.
			var rook := Color(0.5, 0.35, 0.2)
			_rect(img, 6, 4, 3, 4, rook); _rect(img, 11, 4, 3, 4, rook); _rect(img, 16, 4, 3, 4, rook)
			_rect(img, 6, 7, 13, 3, rook)
			_rect(img, 8, 10, 9, 8, rook)
			_rect(img, 5, 18, 15, 3, rook)
		"bolster":
			# A chest piece.
			_disc(img, 7, 8, 3, steel); _disc(img, 17, 8, 3, steel)   # shoulders
			_rect(img, 6, 8, 13, 11, steel)
			_rect(img, 10, 5, 5, 3, dark)                             # neck hole
			_line(img, 12, 10, 12, 18, Color(0.5, 0.54, 0.6))         # centre seam
		"smith":
			# An anvil.
			var iron := Color(0.42, 0.44, 0.5)
			_rect(img, 4, 8, 15, 4, iron)
			_tri(img, Vector2(19, 8), Vector2(23, 10), Vector2(19, 12), iron)
			_rect(img, 9, 12, 6, 5, iron)
			_rect(img, 6, 17, 12, 3, iron)
		"brace":
			# A helmeted head behind a shield.
			_disc(img, 9, 8, 4.5, steel)                              # helmet
			_rect(img, 6, 8, 7, 3, dark)                              # visor
			_shield(img, 15, 8, 11, 13, Color(0.35, 0.5, 0.8))
		"resilient":
			# Two layered shields.
			_shield(img, 9, 5, 11, 14, Color(0.45, 0.38, 0.6))
			_shield(img, 15, 8, 11, 13, Color(0.65, 0.55, 0.85))
		"thorns":
			# Three small thorns.
			var green := Color(0.25, 0.5, 0.25)
			_tri(img, Vector2(3, 20), Vector2(9, 20), Vector2(6, 6), green)
			_tri(img, Vector2(9, 20), Vector2(15, 20), Vector2(12, 3), green)
			_tri(img, Vector2(15, 20), Vector2(21, 20), Vector2(18, 6), green)
		"shield_ready":
			# A shield with a red arrow rising beneath it.
			_shield(img, 12, 3, 13, 11, Color(0.35, 0.5, 0.8))
			_rect(img, 11, 18, 2, 4, Color(0.85, 0.25, 0.2))
			_tri(img, Vector2(8, 18), Vector2(16, 18), Vector2(12, 14), Color(0.85, 0.25, 0.2))
		"repelled_block":
			# A shield with a gust of wind beside it.
			_shield(img, 8, 4, 11, 15, Color(0.35, 0.5, 0.8))
			var wind := Color(0.7, 0.9, 1.0)
			_line(img, 15, 7, 22, 7, wind); _px(img, 21, 6, wind)
			_line(img, 15, 11, 22, 11, wind); _px(img, 21, 12, wind)
			_line(img, 15, 15, 20, 15, wind)
		"shield_of_growth":
			# Three shields, each progressively bigger.
			_shield(img, 4, 14, 5, 7, Color(0.3, 0.65, 0.4))
			_shield(img, 11, 10, 7, 10, Color(0.35, 0.75, 0.45))
			_shield(img, 19, 5, 9, 14, Color(0.4, 0.85, 0.5))
		"regen":
			# A red raindrop.
			_drop(img, 12, 14, 5.5, Color(0.85, 0.2, 0.25))
			_px(img, 10, 13, Color(1.0, 0.6, 0.6))
		"morphine":
			# A syringe.
			var pink := Color(0.95, 0.75, 0.85)
			_rect(img, 5, 9, 11, 5, pink)
			_rect(img, 2, 8, 3, 7, steel)                             # plunger
			_line(img, 16, 11, 22, 11, steel, 1.0)                    # needle
			_rect(img, 7, 10, 3, 3, Color(0.8, 0.4, 0.6))             # fluid
		"cleanse":
			# A chalice.
			var gold2 := Color(0.9, 0.75, 0.35)
			_rect(img, 6, 5, 12, 2, gold2)
			_tri(img, Vector2(6, 7), Vector2(18, 7), Vector2(12, 13), gold2)
			_rect(img, 11, 12, 2, 6, gold2)
			_rect(img, 7, 19, 10, 2, gold2)
		"focused":
			# A blue lightbulb.
			var blue := Color(0.4, 0.65, 1.0)
			_disc(img, 12, 9, 6, blue)
			_rect(img, 9, 15, 6, 2, blue)
			_rect(img, 10, 17, 4, 3, steel)
			_line(img, 10, 9, 14, 9, Color(0.9, 0.95, 1.0))           # filament
		"blessed":
			# A card with a halo.
			_rect(img, 8, 8, 9, 13, Color(0.95, 0.93, 0.85))
			_rect(img, 10, 11, 5, 6, Color(0.6, 0.6, 0.75))
			_ring(img, 12, 4, 4, 1.5, Color(0.95, 0.85, 0.3))
		"steady":
			# A balance beam.
			_rect(img, 3, 9, 18, 2, wood)
			_tri(img, Vector2(12, 11), Vector2(8, 19), Vector2(16, 19), Color(0.45, 0.45, 0.5))
			_disc(img, 5, 8, 1.5, steel); _disc(img, 19, 8, 1.5, steel)
		"haste":
			# Starter's blocks.
			var cyan := Color(0.4, 0.85, 0.9)
			_tri(img, Vector2(4, 19), Vector2(15, 19), Vector2(15, 7), cyan)
			_rect(img, 15, 7, 3, 12, cyan.darkened(0.3))
			_line(img, 17, 5, 22, 5, cyan); _line(img, 18, 9, 23, 9, cyan)  # speed lines
		"demonic_rage":
			# A small demon head.
			var red := Color(0.8, 0.15, 0.15)
			_disc(img, 12, 13, 6, red)
			_tri(img, Vector2(6, 9), Vector2(9, 10), Vector2(6, 3), red.darkened(0.2))
			_tri(img, Vector2(18, 9), Vector2(15, 10), Vector2(18, 3), red.darkened(0.2))
			_px(img, 10, 12, Color(1.0, 0.9, 0.3)); _px(img, 14, 12, Color(1.0, 0.9, 0.3))
			_rect(img, 10, 16, 5, 1, dark)
		"invisible":
			# A Zorro mask.
			_rect(img, 3, 9, 18, 6, dark)
			_disc(img, 8, 12, 1.8, Color(0, 0, 0, 0))                 # eye holes punched out
			_disc(img, 16, 12, 1.8, Color(0, 0, 0, 0))
			_line(img, 21, 11, 23, 8, dark)                           # tie tail

		# ---------------- DEBUFFS ----------------
		"bleed":
			# Three blood drops.
			var blood := Color(0.8, 0.1, 0.1)
			_drop(img, 6, 9, 3, blood)
			_drop(img, 17, 8, 2.6, blood)
			_drop(img, 12, 17, 3.4, blood)
		"burn":
			# A small fire ember.
			_tri(img, Vector2(7, 14), Vector2(17, 14), Vector2(12, 2), Color(1.0, 0.5, 0.0))
			_disc(img, 12, 15, 5.5, Color(1.0, 0.5, 0.0))
			_disc(img, 12, 16, 3, Color(1.0, 0.85, 0.3))
		"poison":
			# A green raindrop.
			_drop(img, 12, 14, 5.5, Color(0.25, 0.75, 0.25))
			_px(img, 10, 13, Color(0.7, 1.0, 0.7))
		"poisoned_blood":
			# A dark blood droplet laced with a green venom core.
			_drop(img, 12, 14, 6.0, Color(0.55, 0.08, 0.12))
			_disc(img, 12, 15, 2.2, Color(0.4, 0.85, 0.3))
			_px(img, 10, 12, Color(0.95, 0.5, 0.5))
		"elixir":
			# A round potion flask with glowing green liquid and a cork.
			var glass := Color(0.78, 0.86, 0.92)
			_rect(img, 10, 3, 4, 2, wood)                     # cork
			_rect(img, 10, 5, 4, 4, glass)                    # neck
			_disc(img, 12, 15, 6.0, glass)                    # glass body
			_disc(img, 12, 16, 4.6, Color(0.3, 0.9, 0.5))     # green liquid
			_rect(img, 10, 8, 4, 3, Color(0.3, 0.9, 0.5))     # liquid up the neck
			_px(img, 10, 13, Color(0.85, 1.0, 0.9))           # shine
		"raged_circulation":
			# A heart with an upward boost arrow.
			var red := Color(0.85, 0.2, 0.25)
			_disc(img, 9, 11, 3, red)
			_disc(img, 15, 11, 3, red)
			_tri(img, Vector2(6, 12), Vector2(18, 12), Vector2(12, 21), red)
			_tri(img, Vector2(12, 3), Vector2(8, 9), Vector2(16, 9), Color(1, 1, 1))
		"understanding":
			# An eye of insight with a bright pupil.
			var blue := Color(0.3, 0.7, 1.0)
			_ring(img, 12, 12, 7, 2, blue)
			_disc(img, 12, 12, 3, blue)
			_disc(img, 12, 12, 1.4, Color(1, 1, 1))
		"approach":
			# A marching boot print.
			var gray := Color(0.62, 0.66, 0.72)
			_disc(img, 11, 8, 4, gray)
			_rect(img, 8, 11, 7, 8, gray)
			_disc(img, 11, 19, 3.5, gray)
		"enchanted_quiver":
			# A quiver with green-fletched arrows.
			var green := Color(0.2, 0.75, 0.4)
			_rect(img, 8, 9, 8, 12, wood)
			_line(img, 10, 2, 10, 9, steel)
			_line(img, 13, 2, 13, 9, steel)
			_line(img, 16, 2, 16, 9, steel)
			_tri(img, Vector2(9, 2), Vector2(11, 4), Vector2(10, 6), green)
			_tri(img, Vector2(12, 2), Vector2(14, 4), Vector2(13, 6), green)
		"tighten_string":
			# A drawn bow with a nocked arrow.
			var gold := Color(1.0, 0.8, 0.2)
			_ring(img, 7, 12, 8, 2, wood)
			_line(img, 7, 5, 7, 19, gold)
			_line(img, 7, 12, 20, 12, steel)
			_tri(img, Vector2(20, 10), Vector2(20, 14), Vector2(23, 12), steel)
		"loaded_die":
			# A purple die showing five pips.
			var purple := Color(0.6, 0.35, 0.72)
			var wp := Color(1, 1, 1)
			_rect(img, 5, 5, 14, 14, purple)
			_disc(img, 9, 9, 1.4, wp)
			_disc(img, 15, 9, 1.4, wp)
			_disc(img, 12, 12, 1.4, wp)
			_disc(img, 9, 15, 1.4, wp)
			_disc(img, 15, 15, 1.4, wp)
		"shocked":
			# A lightning bolt.
			var yellow := Color(1.0, 0.95, 0.3)
			_tri(img, Vector2(14, 2), Vector2(8, 13), Vector2(13, 13), yellow)
			_tri(img, Vector2(13, 13), Vector2(15, 10), Vector2(9, 22), yellow)
		"cursed":
			# A voodoo doll with pins.
			var burlap := Color(0.6, 0.45, 0.3)
			_disc(img, 12, 6, 3, burlap)
			_rect(img, 9, 9, 7, 8, burlap)
			_rect(img, 5, 10, 4, 2, burlap); _rect(img, 16, 10, 4, 2, burlap)
			_rect(img, 9, 17, 2, 4, burlap); _rect(img, 14, 17, 2, 4, burlap)
			_line(img, 7, 4, 12, 11, steel); _disc(img, 7, 4, 1.2, Color(0.9, 0.2, 0.2))
			_line(img, 19, 7, 13, 13, steel); _disc(img, 19, 7, 1.2, Color(0.9, 0.2, 0.2))
		"drain":
			# A green swirl.
			var g := Color(0.35, 0.8, 0.4)
			_ring(img, 12, 12, 8, 2, g)
			_rect(img, 4, 12, 9, 9, Color(0, 0, 0, 0))                # open the outer ring
			_ring(img, 12, 12, 4.5, 2, g.darkened(0.15))
			_rect(img, 12, 3, 9, 7, Color(0, 0, 0, 0))                # open the inner ring
			_disc(img, 12, 12, 1.5, g)
		"stun":
			# An exclamation point.
			var y2 := Color(1.0, 0.95, 0.2)
			_rect(img, 10, 3, 4, 11, y2)
			_disc(img, 12, 19, 2.2, y2)
		"frozen":
			# An ice cube.
			var ice := Color(0.6, 0.85, 1.0)
			_rect(img, 5, 6, 14, 13, ice)
			_rect(img, 5, 6, 14, 3, Color(0.8, 0.95, 1.0))
			_line(img, 8, 10, 12, 16, Color(1, 1, 1)); _line(img, 15, 9, 13, 13, Color(1, 1, 1))
		"disarm":
			# A hand dropping a small knife.
			_disc(img, 9, 7, 3.4, skin)
			for f in range(3):
				_rect(img, 6 + f * 3, 2, 2, 4, skin)
			var kx := 15.0
			_tri(img, Vector2(kx, 13), Vector2(kx + 3, 13), Vector2(kx + 1.5, 20), steel)
			_rect(img, int(kx), 10, 3, 3, wood)
			_line(img, 12, 12, 13, 15, Color(0.7, 0.7, 0.75))         # falling motion
		"silence":
			# A face with an X for a mouth.
			_disc(img, 12, 12, 8, skin)
			_px(img, 9, 9, dark); _px(img, 15, 9, dark)
			_line(img, 9, 14, 15, 18, dark, 1.5)
			_line(img, 15, 14, 9, 18, dark, 1.5)
		"cuffed":
			# Two hands cuffed together.
			_ring(img, 7, 13, 4, 2, steel)
			_ring(img, 17, 13, 4, 2, steel)
			_rect(img, 10, 12, 4, 2, steel.darkened(0.25))            # chain link
			_rect(img, 5, 5, 4, 4, skin); _rect(img, 15, 5, 4, 4, skin)  # hands above
		"rooted":
			# Roots.
			_rect(img, 10, 3, 4, 7, wood)
			_line(img, 12, 10, 5, 20, wood, 2.0)
			_line(img, 12, 10, 12, 21, wood, 2.0)
			_line(img, 12, 10, 19, 20, wood, 2.0)
			_line(img, 8, 15, 5, 13, wood)
			_line(img, 16, 16, 19, 14, wood)
		"slowed":
			# A foot stuck in molasses.
			_rect(img, 7, 7, 8, 5, skin)
			_disc(img, 16, 9, 2.5, skin)                              # toes
			var goo := Color(0.45, 0.3, 0.15)
			_rect(img, 4, 12, 16, 4, goo)
			_drop(img, 7, 19, 1.8, goo)
			_drop(img, 15, 20, 2.2, goo)
		"hexed":
			# A purple cloud.
			var purple := Color(0.6, 0.3, 0.8)
			_disc(img, 8, 13, 4, purple)
			_disc(img, 13, 10, 5, purple)
			_disc(img, 17, 13, 4, purple)
			_rect(img, 5, 13, 15, 4, purple)
			_px(img, 9, 20, purple); _px(img, 14, 21, purple)         # drips of magic
		"locked":
			# A padlock.
			var gold3 := Color(0.85, 0.7, 0.3)
			_ring(img, 12, 8, 4.5, 2, steel)
			_rect(img, 6, 10, 13, 10, gold3)
			_disc(img, 12, 14, 1.6, dark)
			_rect(img, 11, 15, 2, 3, dark)
		"weighted":
			# Three weights stacked on each other.
			var grey := Color(0.5, 0.5, 0.55)
			_rect(img, 9, 4, 6, 4, grey.lightened(0.15))
			_rect(img, 7, 9, 10, 5, grey)
			_rect(img, 4, 15, 16, 6, grey.darkened(0.15))
			_rect(img, 11, 2, 2, 2, grey)                             # top handle
		"staggered":
			# A kneeling figure.
			_disc(img, 9, 5, 2.6, skin)
			_line(img, 9, 8, 12, 14, skin, 2.4)                       # torso leaning forward
			_line(img, 12, 14, 8, 19, skin, 2.2)                      # kneeling leg
			_rect(img, 6, 19, 5, 2, skin)                             # shin on ground
			_line(img, 12, 14, 16, 20, skin, 2.2)                     # braced leg
			_line(img, 10, 10, 5, 14, skin, 1.6)                      # arm hanging
		"clumsy":
			# Someone walking into a pole.
			_rect(img, 16, 3, 3, 18, Color(0.55, 0.55, 0.6))          # the pole
			_disc(img, 11, 8, 2.6, skin)                              # head at the pole
			_line(img, 11, 11, 9, 18, skin, 2.4)                      # body
			_line(img, 9, 18, 6, 21, skin, 2.0)                       # legs
			_line(img, 9, 18, 12, 21, skin, 2.0)
			_px(img, 14, 4, Color(1, 1, 0.4)); _px(img, 15, 6, Color(1, 1, 0.4)); _px(img, 13, 6, Color(1, 1, 0.4))  # impact
		"brittle":
			# A chest piece crumbling, crumbs beneath.
			_disc(img, 7, 6, 2.6, steel); _disc(img, 17, 6, 2.6, steel)
			_rect(img, 6, 6, 13, 10, steel)
			_line(img, 12, 8, 10, 12, dark); _line(img, 10, 12, 13, 16, dark)
			_px(img, 8, 16, Color(0, 0, 0, 0)); _px(img, 15, 15, Color(0, 0, 0, 0))  # missing chunks
			_rect(img, 7, 19, 2, 2, steel.darkened(0.2))              # crumbs
			_rect(img, 12, 20, 2, 2, steel.darkened(0.2))
			_rect(img, 16, 19, 1, 2, steel.darkened(0.2))
		"cold":
			# A snowflake.
			var flake := Color(0.55, 0.8, 1.0)
			_line(img, 12, 3, 12, 21, flake, 1.5)
			_line(img, 4, 7, 20, 17, flake, 1.5)
			_line(img, 20, 7, 4, 17, flake, 1.5)
			for p in [Vector2(12, 5), Vector2(12, 19), Vector2(6, 8), Vector2(18, 16), Vector2(18, 8), Vector2(6, 16)]:
				_disc(img, p.x, p.y, 1.2, flake)
		"blind":
			# A face with X's for eyes.
			_disc(img, 12, 12, 8, skin)
			_line(img, 7, 8, 10, 11, dark); _line(img, 10, 8, 7, 11, dark)
			_line(img, 14, 8, 17, 11, dark); _line(img, 17, 8, 14, 11, dark)
			_rect(img, 9, 16, 6, 1, dark)
		# ---------------- extras (no glyph spec given) ----------------
		"vulnerable":
			# A cracked heart taking extra damage.
			var hred := Color(0.9, 0.25, 0.3)
			_disc(img, 8.5, 9, 4, hred); _disc(img, 15.5, 9, 4, hred)
			_tri(img, Vector2(4.5, 11), Vector2(19.5, 11), Vector2(12, 21), hred)
			_line(img, 12, 6, 10, 11, dark); _line(img, 10, 11, 13, 16, dark)
		"exposed":
			# A shield with a bite taken out of it.
			_shield(img, 12, 4, 14, 17, steel)
			_disc(img, 19, 8, 4, Color(0, 0, 0, 0))
		"taunt":
			# An angry double exclamation.
			var orange := Color(1.0, 0.6, 0.0)
			_rect(img, 8, 4, 3, 10, orange); _disc(img, 9, 18, 1.8, orange)
			_rect(img, 14, 4, 3, 10, orange); _disc(img, 15, 18, 1.8, orange)
		"fear":
			# A fleeing figure — legs mid-sprint, motion lines behind.
			var fpurp := Color(0.75, 0.55, 0.95)
			_disc(img, 15, 6, 2.5, fpurp)
			_line(img, 14, 9, 12, 14, fpurp, 2.0)
			_line(img, 12, 14, 8, 19, fpurp, 2.0)
			_line(img, 12, 14, 16, 18, fpurp, 2.0)
			_line(img, 3, 7, 8, 7, fpurp); _line(img, 2, 11, 7, 11, fpurp)
		"tree":
			# A little tree: trunk and crown.
			_rect(img, 11, 13, 3, 8, Color(0.42, 0.28, 0.12))
			_disc(img, 12, 9, 6, Color(0.25, 0.6, 0.25))
		"cupid":
			# A pink heart pierced by an arrow.
			var pink := Color(1.0, 0.6, 0.7)
			_disc(img, 9, 9, 3.6, pink); _disc(img, 15, 9, 3.6, pink)
			_tri(img, Vector2(5.5, 11), Vector2(18.5, 11), Vector2(12, 20), pink)
			_line(img, 3, 16, 20, 6, Color(0.95, 0.9, 0.6), 1.2)
		"marked":
			# A red target reticle.
			var mred := Color(1.0, 0.25, 0.25)
			_ring(img, 12, 12, 8, 2, mred)
			_disc(img, 12, 12, 2, mred)
			_rect(img, 11, 1, 2, 4, mred); _rect(img, 11, 19, 2, 4, mred)
			_rect(img, 1, 11, 4, 2, mred); _rect(img, 19, 11, 4, 2, mred)
		_:
			return false
	return true
