class_name HudIconBar
extends HBoxContainer

## Top-right HUD bar of icon buttons that replace the old "I / L / H" text
## hints. Each button opens its window (the keyboard shortcuts still work too).
## The Level (EXP) and Quest buttons carry a small yellow notification dot in
## their top-right corner when there's something to do — a level-up point to
## spend, or a new/updated quest.

signal character_pressed
signal level_pressed
signal quest_pressed
signal help_pressed
signal deck_pressed

const ICON_SZ := 30

var _level_dot: Panel = null
var _quest_dot: Panel = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var char_btn := _make_button(_tex_person(), "", "Character (I)")
	char_btn.pressed.connect(func(): character_pressed.emit())
	add_child(char_btn)

	var level_btn := _make_button(_tex_exp_arrow(), "EXP", "Level Progress (L)")
	level_btn.pressed.connect(func(): level_pressed.emit())
	add_child(level_btn)
	_level_dot = _make_dot(level_btn)

	var quest_btn := _make_button(_tex_scroll(), "", "Quest Journal")
	quest_btn.pressed.connect(func(): quest_pressed.emit())
	add_child(quest_btn)
	_quest_dot = _make_dot(quest_btn)

	var deck_btn := _make_button(_tex_deck_box(), "", "Deck")
	deck_btn.pressed.connect(func(): deck_pressed.emit())
	add_child(deck_btn)

	var help_btn := _make_button(_tex_question(), "", "Help (H)")
	help_btn.pressed.connect(func(): help_pressed.emit())
	add_child(help_btn)


func set_level_notify(on: bool) -> void:
	if _level_dot:
		_level_dot.visible = on

func set_quest_notify(on: bool) -> void:
	if _quest_dot:
		_quest_dot.visible = on


# =============================================================
# WIDGET BUILDERS
# =============================================================

func _make_button(icon: Texture2D, text: String, tip: String) -> Button:
	var b := Button.new()
	b.icon = icon
	b.text = text
	b.tooltip_text = tip
	b.expand_icon = false
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_constant_override("h_separation", 3)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.17, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.5)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", style)
	return b


func _make_dot(parent: Button) -> Panel:
	## A small yellow "attention" dot pinned to the button's top-right corner.
	var dot := Panel.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.custom_minimum_size = Vector2(12, 12)
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.position = Vector2(-8, -4)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1.0, 0.85, 0.1)
	st.border_width_left = 1
	st.border_width_right = 1
	st.border_width_top = 1
	st.border_width_bottom = 1
	st.border_color = Color(0.4, 0.3, 0.0)
	st.corner_radius_top_left = 6
	st.corner_radius_top_right = 6
	st.corner_radius_bottom_left = 6
	st.corner_radius_bottom_right = 6
	dot.add_theme_stylebox_override("panel", st)
	dot.visible = false
	parent.add_child(dot)
	return dot


# =============================================================
# ICON TEXTURES (small pixel glyphs)
# =============================================================

func _blank() -> Image:
	var img := Image.create(ICON_SZ, ICON_SZ, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for py in range(int(cy - r), int(cy + r) + 1):
		for px in range(int(cx - r), int(cx + r) + 1):
			if px >= 0 and px < ICON_SZ and py >= 0 and py < ICON_SZ:
				if Vector2(px - cx, py - cy).length() <= r:
					img.set_pixel(px, py, c)

func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and px < ICON_SZ and py >= 0 and py < ICON_SZ:
				img.set_pixel(px, py, c)

func _tri(img: Image, a: Vector2, b: Vector2, c2: Vector2, col: Color) -> void:
	var minx := int(min(a.x, min(b.x, c2.x)))
	var maxx := int(max(a.x, max(b.x, c2.x)))
	var miny := int(min(a.y, min(b.y, c2.y)))
	var maxy := int(max(a.y, max(b.y, c2.y)))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var p := Vector2(px, py)
			var d0 := (b - a).cross(p - a)
			var d1 := (c2 - b).cross(p - b)
			var d2 := (a - c2).cross(p - c2)
			if not ((d0 < 0 or d1 < 0 or d2 < 0) and (d0 > 0 or d1 > 0 or d2 > 0)):
				if px >= 0 and px < ICON_SZ and py >= 0 and py < ICON_SZ:
					img.set_pixel(px, py, col)

func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


func _tex_person() -> Texture2D:
	var img := _blank()
	var c := Color(0.85, 0.87, 0.95)
	_disc(img, 15, 9, 5.5, c)              # head
	# shoulders/body trapezoid
	_tri(img, Vector2(6, 26), Vector2(24, 26), Vector2(15, 15), c)
	_rect(img, 7, 22, 16, 5, c)
	return _tex(img)


func _tex_exp_arrow() -> Texture2D:
	## An up arrow (the "EXP" label sits beside it on the button).
	var img := _blank()
	var g := Color(0.55, 0.95, 0.55)
	_tri(img, Vector2(6, 16), Vector2(24, 16), Vector2(15, 4), g)   # arrowhead
	_rect(img, 12, 16, 6, 10, g)                                     # shaft
	return _tex(img)


func _tex_scroll() -> Texture2D:
	var img := _blank()
	var parch := Color(0.92, 0.85, 0.62)
	var roll := Color(0.75, 0.62, 0.4)
	var line := Color(0.5, 0.42, 0.28)
	_rect(img, 7, 8, 16, 14, parch)          # parchment body
	_rect(img, 5, 5, 20, 4, roll)            # top roll
	_rect(img, 5, 21, 20, 4, roll)           # bottom roll
	for ly in [11, 14, 17]:                   # writing lines
		_rect(img, 10, ly, 10, 1, line)
	return _tex(img)


func _tex_question() -> Texture2D:
	var img := _blank()
	var c := Color(0.7, 0.85, 1.0)
	# hook of the question mark
	_disc(img, 15, 10, 6, c)
	_disc(img, 15, 10, 3.2, Color(0, 0, 0, 0))
	_rect(img, 15, 10, 6, 4, Color(0, 0, 0, 0))   # open the lower-left of the ring
	_rect(img, 14, 13, 4, 6, c)                    # stem down to the dot
	_disc(img, 15, 24, 2.4, c)                     # dot
	return _tex(img)


func _tex_deck_box() -> Texture2D:
	## A boxed deck of cards (tuck box) with a sheathed sword pointing down on
	## the face — hilt at the top, scabbard covering the blade down to the tip.
	var img := _blank()
	var box := Color(0.86, 0.88, 0.94)     # pale card box
	var box_edge := Color(0.5, 0.52, 0.62) # box outline / seams
	var leather := Color(0.45, 0.3, 0.16)  # scabbard
	var gold := Color(0.85, 0.68, 0.28)    # hilt fittings
	# Box body with a slight top lip so it reads as a 3D tuck box.
	_rect(img, 6, 4, 18, 23, box)
	_rect(img, 6, 4, 18, 2, box_edge)          # top lip
	_rect(img, 6, 4, 1, 23, box_edge)          # left seam
	_rect(img, 23, 4, 1, 23, box_edge)         # right seam
	_rect(img, 6, 26, 18, 1, box_edge)         # bottom seam
	# Sheathed sword on the face, pointing DOWN.
	_rect(img, 11, 6, 8, 2, gold)              # pommel / top guard
	_rect(img, 14, 8, 2, 2, gold)              # grip
	_rect(img, 10, 10, 10, 2, gold)            # crossguard
	_rect(img, 13, 12, 4, 11, leather)         # scabbard down the face
	_tri(img, Vector2(13, 23), Vector2(17, 23), Vector2(15, 26), leather)  # tip
	_rect(img, 13, 15, 4, 1, gold)             # scabbard band
	_rect(img, 13, 19, 4, 1, gold)             # scabbard band
	return _tex(img)
