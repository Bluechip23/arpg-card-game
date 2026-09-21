class_name PlayerHudUI
extends Control

## The player's status frame, top-left: the HP/mana/scroll bar pack's black
## dragon frame with the character's face in the circle, the level in the
## badge beside it, the wavy health bar (permanent health bright red, temp
## health a darker red behind it), the straight mana bar (blue) and the thin
## experience bar (yellow) under it, then a row of armor (star), gold (coin)
## and the tempo until the next mana regen (drop). Everything polls the
## PlayerStats handed in through `stats_provider` every frame, so no update
## call is needed anywhere else.

## Pieces cut from the pack's Bars.png by tools (assets/textures/craftpix/ui):
## the frame with its loose fills erased, the wavy health fill, the straight
## fill recoloured blue for mana, the thin fill recoloured yellow for XP.
const UI := "res://assets/textures/craftpix/ui/"
const FACES := "res://assets/sprites/craftpix/hud_bars/Icons.png"
const S := 2.0  # pixel scale of the 16-bit frame on the 1280x720 UI

const FRAME_SIZE := Vector2(202, 41)
const FACE_FALLBACK := Rect2(9, 8, 32, 32)  # the pack's own face, for characters without a sheet

# Frame-local positions (1x texels).
const HP_AT := Vector2(44, 3)
const MANA_AT := Vector2(55, 17)  # the lower slot starts right of the level badge
const XP_AT := Vector2(44, 29)
const XP_W := 98.0
const BADGE := Rect2(40, 15, 14, 12)  # the cream badge set into the slot's left end
const PORTRAIT := Rect2(5, 5, 32, 32)

const HP_COLOR := Color(1, 1, 1)
const TEMP_HP_COLOR := Color(0.5, 0.42, 0.45)   # darker red: temporary health

var stats_provider: Callable = Callable()
var mana_area: Control
var hp_label: Label
var mana_label: Label
var level_label: Label
var armor_label: Label
var gold_label: Label
var regen_label: Label

var _frame_tex: Texture2D
var _hp_tex: Texture2D
var _mana_tex: Texture2D
var _xp_tex: Texture2D
var _portrait: TextureRect
var _hp_ratio := 1.0
var _temp_ratio := 1.0
var _mana_ratio := 1.0
var _xp_ratio := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame_tex = load(UI + "hud_frame.png")
	_hp_tex = load(UI + "hud_fill_hp.png")
	_mana_tex = load(UI + "hud_fill_mana.png")
	_xp_tex = load(UI + "hud_fill_xp.png")
	custom_minimum_size = Vector2(FRAME_SIZE.x * S, FRAME_SIZE.y * S + 24)
	size = custom_minimum_size

	# Character face inside the circle (drawn under the frame's rim via _draw order:
	# the frame is painted in _draw, the portrait is a child so it sits on top).
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.position = PORTRAIT.position * S
	_portrait.size = PORTRAIT.size * S
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)

	hp_label = _label(Rect2(HP_AT, _hp_tex.get_size()), 11, Color(1, 1, 1))
	hp_label.tooltip_text = "Health (darker red: temporary health)"
	mana_area = Control.new()
	mana_area.name = "ManaArea"
	mana_area.position = MANA_AT * S
	mana_area.size = _mana_tex.get_size() * S
	mana_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mana_area)
	mana_label = _label(Rect2(MANA_AT, _mana_tex.get_size()), 10, Color(1, 1, 1))
	level_label = _label(BADGE, 12, Color(0.22, 0.16, 0.08), false)
	level_label.tooltip_text = "Character level"

	# Armor / gold / mana-regen row under the frame.
	var row := HBoxContainer.new()
	row.name = "BadgeRow"
	row.position = Vector2(HP_AT.x * S, FRAME_SIZE.y * S + 3)
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	armor_label = _badge(row, load(UI + "hud_star.png"), "Current armor")
	gold_label = _badge(row, load(UI + "hud_coin.png"), "Gold")
	regen_label = _badge(row, UIGlyphs.get_glyph("raindrop"), "Tempo until your next mana regen")


func set_portrait(sheet_path: String) -> void:
	## The character's south-facing idle frame (32px NPC sheets); characters
	## without a sheet get the pack's face.
	var atlas := AtlasTexture.new()
	if sheet_path != "" and ResourceLoader.exists(sheet_path):
		atlas.atlas = load(sheet_path)
		atlas.region = Rect2(0, 0, 32, 32)
	else:
		atlas.atlas = load(FACES)
		atlas.region = FACE_FALLBACK
	_portrait.texture = atlas


func _label(r: Rect2, px: int, col: Color, outline: bool = true) -> Label:
	var l := Label.new()
	l.position = r.position * S
	l.size = r.size * S
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(l)
	return l


func _badge(row: HBoxContainer, icon: Texture2D, tip: String) -> Label:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.tooltip_text = tip
	row.add_child(box)
	var tex := TextureRect.new()
	tex.texture = icon
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.custom_minimum_size = Vector2(18, 18)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tex)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l


func _process(_delta: float) -> void:
	if not stats_provider.is_valid():
		return
	var st = stats_provider.call()
	if st == null:
		return
	var max_hp: int = maxi(1, int(st.max_health))
	var hp: int = int(st.current_health)
	var temp: int = int(st.get("current_temp_health")) if "current_temp_health" in st else 0
	_hp_ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_temp_ratio = clampf(float(hp + temp) / float(max_hp), 0.0, 1.0)
	var max_mana: int = maxi(1, int(st.max_mana))
	_mana_ratio = clampf(float(st.current_mana) / float(max_mana), 0.0, 1.0)
	var to_next: int = maxi(1, int(st.get_xp_to_next_level()))
	_xp_ratio = clampf(float(st.current_xp) / float(to_next), 0.0, 1.0)
	var pct := int(_hp_ratio * 100.0)
	hp_label.text = ("%d/%d (%d%%)" % [hp, max_hp, pct]) + ((" +%d" % temp) if temp > 0 else "")
	mana_label.text = "%d/%d" % [int(st.current_mana), max_mana]
	level_label.text = str(st.current_level)
	armor_label.text = str(st.current_armor)
	gold_label.text = str(st.gold)
	regen_label.text = str(st.get_tempo_until_mana_regen())
	queue_redraw()


func _draw() -> void:
	if _frame_tex == null:
		return
	# The frame, then the fills on top of its slots (each cut from the left
	# so the shaped left end stays and the right edge recedes).
	draw_texture_rect(_frame_tex, Rect2(Vector2.ZERO, FRAME_SIZE * S), false)
	_fill(_hp_tex, HP_AT, _temp_ratio, TEMP_HP_COLOR)
	_fill(_hp_tex, HP_AT, _hp_ratio, HP_COLOR)
	_fill(_mana_tex, MANA_AT, _mana_ratio, Color.WHITE)
	# Experience: the thin fill stretched across the slot width.
	if _xp_ratio > 0.0 and _xp_tex:
		var w := XP_W * _xp_ratio
		draw_texture_rect_region(_xp_tex, Rect2(XP_AT * S, Vector2(w, _xp_tex.get_height()) * S),
			Rect2(Vector2.ZERO, Vector2(_xp_tex.get_width() * _xp_ratio, _xp_tex.get_height())), Color.WHITE)


func _fill(tex: Texture2D, at: Vector2, ratio: float, col: Color) -> void:
	if tex == null or ratio <= 0.0:
		return
	var w := floorf(tex.get_width() * ratio)
	if w < 1.0:
		return
	draw_texture_rect_region(tex, Rect2(at * S, Vector2(w, tex.get_height()) * S),
		Rect2(Vector2.ZERO, Vector2(w, tex.get_height())), col)
