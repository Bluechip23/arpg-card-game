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
		"mana_plus": _draw_mana_plus(img)
		"recycle": _draw_recycle(img)
		"feather": _draw_feather(img)
		"flash_bolt": _draw_flash_bolt(img)
		"to_sigil": _draw_to_sigil(img)
		"card_draw": _draw_card_draw(img)
		"boots": _draw_boots(img)
		"duck": _draw_duck(img)
		"dual_daggers": _draw_dual_daggers(img)
		"info": _draw_info(img)
		"brain": _draw_brain(img)
		"eye": _draw_eye(img)
		"card_plus": _draw_card_plus(img)
		"bow": _draw_bow(img)
		"dagger": _draw_dagger(img)
		"axe": _draw_axe(img)
		"hammer": _draw_hammer(img)
		"polearm": _draw_polearm(img)
		"wand": _draw_wand(img)
		"tome": _draw_tome(img)
		"staff": _draw_staff(img)
		"quiver": _draw_quiver(img)
		"helm": _draw_helm(img)
		"chestplate": _draw_chestplate(img)
		"ring": _draw_ring(img)
		"belt": _draw_belt(img)
		"gauntlet": _draw_gauntlet(img)
		_:
			_cache[key] = null
			return null
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## The glyph key representing an item's slot type — a kite shield for shields,
## a bow for bows, a sword for swords, a ring for rings… Used by the slotted-
## card badge so a card shows WHICH kind of item it is enchanted into.
static func item_glyph_key(item) -> String:
	if item == null:
		return ""
	match int(item.item_type):
		0: return "helm"        # ItemData.ItemType.HELM
		1: return "chestplate"  # CHEST
		2: return "ring"        # RING
		3: return "belt"        # BELT
		4: return "boots"       # BOOTS
		5: return "gauntlet"    # GAUNTLETS
		7: return "quiver"      # QUIVER
		6:                      # WEAPON — by subtype
			match int(item.weapon_subtype):
				0: return "sword"
				1: return "bow"
				2: return "shield"
				4: return "polearm"
				5: return "dagger"
				6: return "axe"
				7: return "hammer"
				8: return "wand"
				9: return "tome"
				10: return "staff"
				_: return "sword"  # OTHER and anything new
	return "sword"


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

static func _draw_mana_plus(img: Image) -> void:
	## Mana drop with a small "+" pinned to its top-right corner
	## (Cory's gauntlet passive: mana back when a skill comes off cooldown).
	var body := Color(0.35, 0.62, 1.0)
	var edge := Color(0.12, 0.28, 0.6)
	var hi := Color(0.72, 0.86, 1.0)
	var plus := Color(0.55, 1.0, 0.65)
	# Drop nudged down-left to leave room for the plus.
	_fill_teardrop(img, 10.0, 16.0, 7.0, 4.0, edge)      # outline
	_fill_teardrop(img, 10.0, 16.0, 5.7, 6.0, body)      # body
	_disc(img, 8.0, 14.5, 1.5, hi)                        # highlight
	# "+" in the top-right corner.
	_rect(img, 16, 3, 7, 3, plus)
	_rect(img, 18, 1, 3, 7, plus)

static func _draw_recycle(img: Image) -> void:
	## Three green arrows chasing each other around a triangle (recycle symbol,
	## for Jeremy's ring double-trigger cycle passive).
	var green := Color(0.35, 0.8, 0.4)
	var dark := Color(0.16, 0.5, 0.22)
	# Triangle ring (dark under-stroke, then bright core).
	_line(img, 12, 4, 20, 18, dark, 2.6)
	_line(img, 20, 18, 4, 18, dark, 2.6)
	_line(img, 4, 18, 12, 4, dark, 2.6)
	_line(img, 12, 4, 20, 18, green, 1.4)
	_line(img, 20, 18, 4, 18, green, 1.4)
	_line(img, 4, 18, 12, 4, green, 1.4)
	# Arrowheads at each corner, chasing clockwise.
	_tri(img, Vector2(12, 1), Vector2(16, 5), Vector2(10, 6), green)
	_tri(img, Vector2(23, 18), Vector2(17, 15), Vector2(18, 22), green)
	_tri(img, Vector2(1, 18), Vector2(7, 21), Vector2(6, 14), green)

static func _draw_card_draw(img: Image) -> void:
	## Two fanned cards with a small up-arrow (Flash Reserves: flash → draw).
	var back := Color(0.35, 0.45, 0.7)
	var face := Color(0.9, 0.9, 0.95)
	var edge := Color(0.2, 0.25, 0.4)
	var gold := Color(1.0, 0.85, 0.3)
	# Back card, tilted footprint suggested by offset.
	_rect(img, 4, 6, 10, 14, back)
	_rect(img, 4, 6, 10, 1, edge)
	# Front card.
	_rect(img, 9, 4, 10, 14, face)
	_rect(img, 9, 4, 10, 1, edge)
	_rect(img, 9, 4, 1, 14, edge)
	_rect(img, 18, 4, 1, 14, edge)
	_rect(img, 9, 17, 10, 1, edge)
	# Up arrow bursting from the front card (the draw).
	_tri(img, Vector2(14, 15), Vector2(11, 20), Vector2(17, 20), gold)
	_rect(img, 13, 19, 3, 4, gold)

static func _draw_info(img: Image) -> void:
	## A small ⓘ badge: ringed circle with a dot and stem.
	var blue := Color(0.45, 0.7, 1.0)
	var bright := Color(0.9, 0.95, 1.0)
	_ring(img, 12.0, 12.0, 9.0, 2.5, blue)
	_rect(img, 11, 6, 3, 3, bright)   # the dot
	_rect(img, 11, 10, 3, 8, bright)  # the stem

static func _draw_brain(img: Image) -> void:
	## A pink brain: two lobes with a center cleft and fold squiggles
	## (the brain-points pool — Wisdom's counterpart to the flash bolt).
	var pink := Color(0.95, 0.62, 0.72)
	var deep := Color(0.72, 0.38, 0.5)
	var stem := Color(0.82, 0.5, 0.58)
	# Two overlapping lobes form the mass.
	_disc(img, 8.5, 10.0, 5.5, pink)
	_disc(img, 15.5, 10.0, 5.5, pink)
	_disc(img, 12.0, 13.0, 6.0, pink)
	# Center cleft between the hemispheres.
	_rect(img, 11, 5, 2, 11, deep)
	# Fold squiggles on each lobe.
	_line(img, 5.0, 9.0, 8.0, 7.0, deep, 1.0)
	_line(img, 5.5, 12.0, 8.5, 11.0, deep, 1.0)
	_line(img, 16.0, 7.0, 19.0, 9.0, deep, 1.0)
	_line(img, 15.5, 11.0, 18.5, 12.0, deep, 1.0)
	# Brain stem.
	_rect(img, 13, 17, 3, 3, stem)

static func _draw_eye(img: Image) -> void:
	## An open eye (peek): almond outline, iris, and bright pupil glint.
	var white := Color(0.92, 0.94, 0.97)
	var lid := Color(0.35, 0.45, 0.7)
	var iris := Color(0.35, 0.65, 0.9)
	var dark := Color(0.12, 0.16, 0.3)
	# Almond: stacked shrinking rows of white bounded by lid lines.
	_rect(img, 6, 10, 12, 4, white)
	_rect(img, 8, 8, 8, 2, white)
	_rect(img, 8, 14, 8, 2, white)
	_line(img, 4.0, 12.0, 9.0, 7.0, lid, 1.2)
	_line(img, 9.0, 7.0, 15.0, 7.0, lid, 1.2)
	_line(img, 15.0, 7.0, 20.0, 12.0, lid, 1.2)
	_line(img, 4.0, 12.0, 9.0, 17.0, lid, 1.2)
	_line(img, 9.0, 17.0, 15.0, 17.0, lid, 1.2)
	_line(img, 15.0, 17.0, 20.0, 12.0, lid, 1.2)
	# Iris + pupil + glint.
	_disc(img, 12.0, 12.0, 3.5, iris)
	_disc(img, 12.0, 12.0, 1.8, dark)
	_px(img, 13, 10, Color(1, 1, 1))

static func _draw_card_plus(img: Image) -> void:
	## A single card with a bold plus sign (buy a draw with brain points).
	var face := Color(0.9, 0.9, 0.95)
	var edge := Color(0.2, 0.25, 0.4)
	var gold := Color(1.0, 0.85, 0.3)
	_rect(img, 6, 3, 12, 17, face)
	_rect(img, 6, 3, 12, 1, edge)
	_rect(img, 6, 19, 12, 1, edge)
	_rect(img, 6, 3, 1, 17, edge)
	_rect(img, 17, 3, 1, 17, edge)
	# Plus sign centered on the card.
	_rect(img, 10, 7, 4, 10, gold)
	_rect(img, 7, 10, 10, 4, gold)

static func _ring(img: Image, cx: float, cy: float, r: float, th: float, c: Color) -> void:
	## Circle outline of thickness th centered at (cx, cy).
	for py in range(int(cy - r - th), int(cy + r + th) + 1):
		for px in range(int(cx - r - th), int(cx + r + th) + 1):
			var d := Vector2(px - cx, py - cy).length()
			if absf(d - r) <= th * 0.5:
				_px(img, px, py, c)

static func _draw_to_sigil(img: Image) -> void:
	## Tutorial/tooltip sigil: a green capital T whose stem is a sword blade
	## ending in a tip, threaded through a silver capital O. Layering per the
	## design: the O's top sits just below the crossbar and passes IN FRONT of
	## the stem; the O's bottom passes BEHIND the blade.
	var green := Color(0.3, 0.8, 0.35)
	var green_dark := Color(0.16, 0.5, 0.22)
	var silver := Color(0.8, 0.82, 0.88)
	var silver_dark := Color(0.55, 0.58, 0.66)
	# T: crossbar with shaded underside, stem doubling as the blade.
	_rect(img, 4, 1, 16, 3, green)
	_rect(img, 4, 4, 16, 1, green_dark)
	_rect(img, 10, 5, 4, 12, green)
	# Silver O threaded on the stem, top just below the crossbar (drawn over
	# the stem — the O is in front here).
	_ring(img, 12.0, 12.0, 6.2, 2.4, silver)
	_ring(img, 12.0, 12.0, 7.4, 0.8, silver_dark)  # outer rim shade
	# Lower stem + sword tip drawn back OVER the ring's bottom arc — the O's
	# bottom disappears behind the blade.
	_rect(img, 10, 11, 4, 6, green)
	_tri(img, Vector2(9, 17), Vector2(15, 17), Vector2(12, 23), green)
	_line(img, 12, 12, 12, 20, green_dark, 1.0)  # blade fuller

static func _draw_flash_bolt(img: Image) -> void:
	## Gold lightning bolt (flash points — Agility's quickness resource).
	var gold := Color(1.0, 0.83, 0.2)
	var hi := Color(1.0, 0.95, 0.6)
	# Upper stroke: wide at the top-right, angling down-left.
	_tri(img, Vector2(15, 1), Vector2(21, 1), Vector2(12, 13), gold)
	_tri(img, Vector2(15, 1), Vector2(12, 13), Vector2(7, 13), gold)
	# Lower spike, offset right of the upper stroke's foot to form the jag.
	_tri(img, Vector2(9, 11), Vector2(16, 11), Vector2(4, 23), gold)
	# Highlight along the leading edge.
	_line(img, 19, 2, 11, 12, hi, 1.0)

static func _draw_boots(img: Image) -> void:
	## Pair of brown boots, toes pointing right (flash movement toggle).
	var leather := Color(0.62, 0.42, 0.2)
	var dark := Color(0.42, 0.27, 0.12)
	var sole := Color(0.24, 0.16, 0.09)
	for ox in [1, 12]:
		_rect(img, ox + 1, 3, 5, 12, leather)   # shaft
		_rect(img, ox + 1, 3, 5, 2, dark)       # cuff
		_rect(img, ox + 1, 14, 8, 5, leather)   # foot
		_rect(img, ox + 6, 14, 3, 2, dark)      # instep shade
		_rect(img, ox + 1, 19, 9, 2, sole)      # sole

static func _draw_duck(img: Image) -> void:
	## Figure ducking under a horizontal blade swing (flash block / sidestep).
	var blade := Color(0.82, 0.84, 0.9)
	var swoosh := Color(0.75, 0.8, 0.92, 0.55)
	var skin := Color(0.92, 0.86, 0.72)
	var body := Color(0.4, 0.55, 0.8)
	# Blade sweeping across the top, tip to the right, with a motion dash.
	_line(img, 1, 4, 19, 4, blade, 1.8)
	_tri(img, Vector2(19, 2), Vector2(23, 4), Vector2(19, 7), blade)
	_line(img, 3, 8, 10, 8, swoosh, 1.0)
	# Ducking figure: head tucked low, hunched back, bent legs.
	_disc(img, 8.0, 13.0, 3.0, skin)            # head, well under the swing
	_line(img, 10, 14, 17, 17, body, 3.0)       # hunched back sloping down
	_rect(img, 14, 17, 4, 4, body)              # crouched hips
	_rect(img, 8, 19, 3, 3, body)               # front leg folded under
	_line(img, 18, 21, 21, 21, body, 1.6)       # trailing foot

static func _draw_dual_daggers(img: Image) -> void:
	## Two crossed daggers (buy an attack-speed tick — "quick hands").
	var blade := Color(0.82, 0.84, 0.9)
	var hilt := Color(0.55, 0.38, 0.16)
	var gold := Color(0.85, 0.68, 0.25)
	# Blades crossing in an X, tips up.
	_line(img, 7, 17, 18, 6, blade, 2.0)
	_line(img, 17, 17, 6, 6, blade, 2.0)
	_tri(img, Vector2(20, 2), Vector2(17, 4), Vector2(19, 7), blade)   # right tip
	_tri(img, Vector2(4, 2), Vector2(7, 4), Vector2(5, 7), blade)      # left tip
	# Crossguards perpendicular to each blade, near the hilts.
	_line(img, 5, 15, 9, 19, gold, 1.8)
	_line(img, 19, 15, 15, 19, gold, 1.8)
	# Grips angling down-out to the corners.
	_line(img, 6, 18, 4, 21, hilt, 2.2)
	_line(img, 18, 18, 20, 21, hilt, 2.2)

static func _draw_feather(img: Image) -> void:
	## Pale feather angled up-right: a thin quill with soft barbs sweeping off
	## it (lightness — Brad's chest weight reduction).
	var vane := Color(0.9, 0.92, 0.97)
	var shade := Color(0.65, 0.7, 0.82)
	var quill := Color(0.5, 0.55, 0.68)
	# Vane: strokes fanning off the quill line, widest through the middle, so
	# the shape reads as a leaf-like plume rather than a bare stick.
	for i in range(10):
		var t := float(i) / 9.0
		var qx := lerpf(7.0, 20.0, t)
		var qy := lerpf(18.0, 3.0, t)
		var spread := sin(t * PI) * 5.0 + 1.5
		_line(img, qx, qy, qx - spread, qy - spread * 0.7, vane if i % 2 == 0 else shade, 2.2)
	# Quill runs the full length, with a bare tip at the bottom.
	_line(img, 4, 21, 20, 3, quill, 1.2)


# =============================================================
# ITEM-TYPE GLYPHS (slotted-card badge: which item holds the card)
# =============================================================

static func _draw_bow(img: Image) -> void:
	## Strung bow with a nocked arrow pointing up-right.
	var wood := Color(0.62, 0.4, 0.2)
	var string := Color(0.9, 0.9, 0.82)
	var head := Color(0.82, 0.84, 0.9)
	# Limb: an arc bowing toward the lower-left.
	for i in range(20):
		var t := float(i) / 19.0
		var ang := lerpf(PI * 0.62, PI * 1.38, t)
		_px(img, int(11.0 + 8.5 * cos(ang) + 4.0), int(12.0 + 8.5 * sin(ang)), wood)
		_px(img, int(11.0 + 7.5 * cos(ang) + 4.0), int(12.0 + 7.5 * sin(ang)), wood)
	_line(img, 12, 4, 12, 20, string, 1.0)
	# Arrow across the middle.
	_line(img, 7, 12, 18, 12, wood, 1.0)
	_tri(img, Vector2(21, 12), Vector2(17, 9.5), Vector2(17, 14.5), head)

static func _draw_dagger(img: Image) -> void:
	## Single short blade, point up.
	var blade := Color(0.82, 0.84, 0.9)
	var hilt := Color(0.5, 0.32, 0.16)
	_tri(img, Vector2(12, 2), Vector2(9, 13), Vector2(15, 13), blade)
	_line(img, 12, 5, 12, 13, Color(0.95, 0.97, 1.0), 1.0)
	_rect(img, 7, 13, 11, 2, hilt)
	_line(img, 12, 15, 12, 20, hilt, 2.4)
	_rect(img, 10, 20, 5, 3, Color(0.72, 0.6, 0.3))

static func _draw_axe(img: Image) -> void:
	## Haft up-right with a broad wedge blade.
	var wood := Color(0.55, 0.36, 0.18)
	var steel := Color(0.78, 0.8, 0.88)
	var edge := Color(0.94, 0.96, 1.0)
	_line(img, 6, 21, 16, 5, wood, 2.2)
	_tri(img, Vector2(15, 3), Vector2(21, 9), Vector2(12, 10), steel)
	_line(img, 20, 10, 21, 9, edge, 1.4)
	_line(img, 15, 3, 21, 9, edge, 1.0)

static func _draw_hammer(img: Image) -> void:
	## War hammer: vertical haft, heavy rectangular head.
	var wood := Color(0.55, 0.36, 0.18)
	var steel := Color(0.7, 0.72, 0.82)
	_line(img, 12, 8, 12, 22, wood, 2.4)
	_rect(img, 5, 3, 14, 7, steel)
	_rect(img, 5, 3, 14, 2, Color(0.88, 0.9, 0.98))
	_rect(img, 5, 8, 14, 2, Color(0.5, 0.52, 0.62))

static func _draw_polearm(img: Image) -> void:
	## Long diagonal haft ending in a leaf-shaped spearhead.
	var wood := Color(0.55, 0.36, 0.18)
	var steel := Color(0.82, 0.84, 0.9)
	_line(img, 4, 22, 16, 8, wood, 1.8)
	_tri(img, Vector2(20, 2), Vector2(13, 9), Vector2(18, 12), steel)
	_line(img, 20, 2, 15, 10, Color(0.95, 0.97, 1.0), 1.0)

static func _draw_wand(img: Image) -> void:
	## Short wand with a four-point star spark at the tip.
	var wood := Color(0.5, 0.32, 0.16)
	var spark := Color(1.0, 0.9, 0.4)
	_line(img, 8, 21, 15, 10, wood, 2.0)
	_line(img, 17, 7, 17, 3, spark, 1.4)
	_line(img, 17, 7, 17, 11, spark, 1.4)
	_line(img, 13, 7, 21, 7, spark, 1.4)
	_px(img, 17, 7, Color(1.0, 1.0, 0.85))

static func _draw_tome(img: Image) -> void:
	## Closed spellbook: cover, pale page edge, clasp.
	var cover := Color(0.45, 0.25, 0.5)
	var page := Color(0.9, 0.88, 0.76)
	var clasp := Color(0.85, 0.7, 0.3)
	_rect(img, 5, 5, 13, 15, cover)
	_rect(img, 18, 6, 2, 14, page)
	_rect(img, 5, 5, 13, 2, Color(0.58, 0.36, 0.62))
	_rect(img, 15, 11, 5, 3, clasp)
	_line(img, 7, 8, 7, 18, Color(0.32, 0.16, 0.36), 1.0)

static func _draw_staff(img: Image) -> void:
	## Full-length staff crowned with an orb.
	var wood := Color(0.5, 0.34, 0.18)
	var orb := Color(0.45, 0.75, 0.95)
	_line(img, 10, 22, 14, 7, wood, 2.0)
	for py in range(2, 9):
		for px in range(11, 18):
			if Vector2(px - 14, py - 5).length() <= 3.2:
				_px(img, px, py, orb)
	_px(img, 13, 4, Color(0.85, 0.95, 1.0))

static func _draw_quiver(img: Image) -> void:
	## Leather tube, tilted, with two fletched arrows poking out the top.
	var leather := Color(0.55, 0.36, 0.18)
	var band := Color(0.72, 0.6, 0.3)
	var fletch := Color(0.85, 0.3, 0.3)
	_line(img, 9, 21, 14, 8, leather, 4.6)
	_line(img, 10, 19, 13, 11, Color(0.42, 0.26, 0.12), 1.4)
	_line(img, 9.5, 17, 15, 15, band, 1.6)
	# Arrows: shafts up-right of the mouth, fletching triangles.
	_line(img, 14, 9, 18, 3, Color(0.8, 0.72, 0.5), 1.0)
	_line(img, 11, 8, 13, 2, Color(0.8, 0.72, 0.5), 1.0)
	_tri(img, Vector2(18, 3), Vector2(20, 1), Vector2(20, 5), fletch)
	_tri(img, Vector2(13, 2), Vector2(15, 0), Vector2(15, 4), fletch)

static func _draw_helm(img: Image) -> void:
	## Round-domed helm with a dark eye slit and a nose guard.
	var steel := Color(0.7, 0.72, 0.82)
	var lit := Color(0.88, 0.9, 0.98)
	var slit := Color(0.12, 0.12, 0.16)
	for py in range(5, 20):
		var w := 8
		if py < 10:
			w = int(sqrt(maxf(0.0, 64.0 - pow(10.0 - py, 2) * 2.2)))
		for px in range(12 - w, 12 + w):
			_px(img, px, py, steel)
	_rect(img, 6, 6, 5, 2, lit)
	_rect(img, 6, 12, 12, 2, slit)
	_line(img, 12, 12, 12, 19, Color(0.5, 0.52, 0.62), 2.0)

static func _draw_chestplate(img: Image) -> void:
	## Breastplate: shoulders, tapered waist, centre ridge.
	var steel := Color(0.7, 0.72, 0.82)
	var lit := Color(0.88, 0.9, 0.98)
	for py in range(4, 21):
		var w := 9
		if py <= 7:
			w = 9
		elif py <= 13:
			w = 8
		else:
			w = 8 - (py - 13)
		if w <= 2:
			continue
		for px in range(12 - w, 12 + w):
			_px(img, px, py, steel)
	_rect(img, 4, 4, 4, 3, lit)   # pauldron highlights
	_rect(img, 16, 4, 4, 3, lit)
	_line(img, 12, 5, 12, 19, Color(0.5, 0.52, 0.62), 1.4)
	_line(img, 8, 8, 10, 10, lit, 1.0)

static func _draw_ring(img: Image) -> void:
	## Gold band with a red gem on top.
	var gold := Color(0.9, 0.75, 0.3)
	var gold_dark := Color(0.65, 0.5, 0.18)
	var gem := Color(0.9, 0.25, 0.3)
	for py in range(0, SZ):
		for px in range(0, SZ):
			var d := Vector2(px - 12, py - 14).length()
			if d >= 4.5 and d <= 7.5:
				_px(img, px, py, gold if px + py < 26 else gold_dark)
	_rect(img, 10, 3, 5, 5, gem)
	_px(img, 11, 4, Color(1.0, 0.7, 0.72))

static func _draw_belt(img: Image) -> void:
	## Curved leather strap with a square gold buckle.
	var leather := Color(0.55, 0.36, 0.18)
	var dark := Color(0.42, 0.26, 0.12)
	var buckle := Color(0.85, 0.7, 0.3)
	for i in range(22):
		var t := float(i) / 21.0
		var x := lerpf(2.0, 22.0, t)
		var y := 12.0 + sin(t * PI) * 3.0
		_line(img, x, y - 2, x, y + 2, leather if i % 5 else dark, 1.0)
	_rect(img, 9, 9, 7, 8, buckle)
	_rect(img, 11, 11, 3, 4, Color(0.12, 0.12, 0.16))

static func _draw_gauntlet(img: Image) -> void:
	## Armored fist: knuckle plates over a clenched mitt, cuff below.
	var steel := Color(0.7, 0.72, 0.82)
	var lit := Color(0.88, 0.9, 0.98)
	var dark := Color(0.5, 0.52, 0.62)
	_rect(img, 6, 4, 12, 10, steel)      # fist block
	for kx in range(6, 18, 3):           # knuckles
		_rect(img, kx, 4, 2, 3, lit)
	_rect(img, 4, 8, 3, 5, steel)        # thumb
	_rect(img, 6, 13, 12, 2, dark)
	_rect(img, 5, 15, 14, 6, steel)      # cuff
	_rect(img, 5, 15, 14, 2, lit)
