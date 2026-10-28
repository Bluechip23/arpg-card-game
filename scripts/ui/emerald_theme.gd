class_name EmeraldTheme
extends RefCounted

## "Emerald Sanctum" — the menus' look (designer's pick, 2026-10-25): a night
## forest under an aurora, dark emerald glass framed in gold, and Courgette
## for every word. The title screen set it; every menu screen reached from
## it (Single Player, Load, Choose Your Character, the questionnaire,
## Compendium, Help and the test labs) wears it through apply().
##
## How it works: apply() gives the screen's root Control a Theme (so every
## Button, Label, panel, tab bar, scrollbar and text field below it picks up
## the font and styles) and puts a ForestBackdrop behind it. Per-control
## theme overrides still win, so a screen keeps its meaningful colours — a
## hero's accent, a card type, a rarity — and drops only the generic ones.

# ---- Palette ----------------------------------------------------------------

const PALETTE := {
	"name": "Emerald Sanctum",
	# Backdrop (ForestBackdrop)
	"sky_top": Color(0.01, 0.05, 0.07), "sky_horizon": Color(0.06, 0.27, 0.25),
	"stars": true, "moon": Color(0.82, 1.0, 0.93), "moon_crescent": true,
	"ground": Color(0.03, 0.11, 0.09), "ground_edge": Color(0.08, 0.28, 0.22),
	"tree_back": Color(0.12, 0.33, 0.30), "tree_front": Color(0.03, 0.09, 0.08),
	"motes": Color(0.55, 1.0, 0.85), "mote_count": 32, "aurora": true,
	"mist": Color(0.45, 0.95, 0.80, 0.10),
	"title_fill": Color(0.58, 0.98, 0.72), "title_outline": Color(0.42, 0.30, 0.07),
	# Menu buttons: elven glass on a gilt-edged tablet
	"btn_bg": Color(0.03, 0.14, 0.11, 0.80), "btn_border": Color(0.70, 0.56, 0.26), "btn_border_w": 1,
	"btn_hover_bg": Color(0.05, 0.23, 0.18, 0.92), "btn_hover_border": Color(0.98, 0.82, 0.40),
	"btn_hover_border_w": 2, "btn_radius": 4, "btn_glow": Color(0.98, 0.80, 0.35, 0.35),
	"btn_font": Color(0.80, 0.96, 0.86), "btn_font_hover": Color(1.0, 0.90, 0.55),
	"btn_outline": Color(0.01, 0.06, 0.05, 0.9),
}

## Body text: pale mint.
const TEXT := Color(0.86, 0.95, 0.89)
## Secondary text: hints, captions, "Level 3".
const TEXT_DIM := Color(0.58, 0.72, 0.66)
## Screen titles and headings: the title's emerald.
const TITLE := Color(0.58, 0.98, 0.72)
## Sub-headings, names, highlights: gold.
const GOLD := Color(1.0, 0.86, 0.45)
const GOLD_DIM := Color(0.70, 0.56, 0.26)
## Panels: dark emerald glass.
const PANEL_BG := Color(0.02, 0.09, 0.075, 0.88)
const PANEL_BG_SOLID := Color(0.02, 0.08, 0.065, 0.97)
const CARD_BG := Color(0.03, 0.13, 0.10, 0.85)
const CARD_HOVER_BG := Color(0.05, 0.20, 0.16, 0.92)
## Text outline that keeps lettering crisp over the forest.
const OUTLINE := Color(0.01, 0.05, 0.04, 0.9)

const DRAUPNIR := preload("res://assets/items/mythic/draupnir.png")

static var _theme: Theme = null

# ---- Applying it ---------------------------------------------------------------

## Theme `root` and everything under it; `backdrop` puts the forest behind it.
## `dim` darkens the forest so busy screens stay readable.
static func apply(root: Control, backdrop: bool = true, dim: float = 0.35) -> void:
	root.theme = get_theme()
	if backdrop:
		# The screen's own flat background would hide the forest.
		var old_bg := root.get_node_or_null("Background")
		if old_bg is CanvasItem:
			old_bg.visible = false
		if root.get_node_or_null("ForestBackdrop") == null:
			ForestBackdrop.add_to(root, dim)

static func font() -> Font:
	return GameFonts.courgette()

## Courgette made heavier, for [b] text and bold headings.
static func bold_font() -> Font:
	var fv := FontVariation.new()
	fv.base_font = font()
	fv.variation_embolden = 0.7
	return fv

static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme

# ---- Building blocks -----------------------------------------------------------------

## A button face: emerald glass with a gold edge (`glow` adds a soft halo).
static func button_box(bg: Color = PALETTE["btn_bg"], border: Color = PALETTE["btn_border"],
		border_w: int = 1, radius: int = 4, glow: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 5  # script descenders sit low; lift the text
	if glow.a > 0.0:
		sb.shadow_color = glow
		sb.shadow_size = 8
	return sb

## A framed panel: dark glass, thin gold border.
static func panel_box(bg: Color = PANEL_BG, border: Color = GOLD_DIM, border_w: int = 1,
		radius: int = 6, margin: float = 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_w)
	sb.border_color = Color(border, border.a * 0.8)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	return sb

## Restyle a button in the theme's glass and gold, replacing any per-button
## styleboxes it was given. `accent` tints the border (a hero's colour).
static func style_button(btn: Button, font_size: int = 18, accent: Color = Color(0, 0, 0, 0)) -> void:
	var border: Color = PALETTE["btn_border"] if accent.a <= 0.0 else accent.darkened(0.15)
	var hover_border: Color = PALETTE["btn_hover_border"] if accent.a <= 0.0 else accent.lightened(0.2)
	btn.add_theme_stylebox_override("normal", button_box(PALETTE["btn_bg"], border, 1))
	btn.add_theme_stylebox_override("hover",
		button_box(PALETTE["btn_hover_bg"], hover_border, 2, 4, PALETTE["btn_glow"]))
	btn.add_theme_stylebox_override("pressed",
		button_box(PALETTE["btn_hover_bg"].darkened(0.3), hover_border, 2, 4, PALETTE["btn_glow"]))
	btn.add_theme_stylebox_override("disabled",
		button_box(Color(0.02, 0.07, 0.06, 0.6), Color(0.35, 0.33, 0.25, 0.6), 1))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		btn.remove_theme_color_override(key)
	btn.remove_theme_font_override("font")
	btn.add_theme_font_size_override("font_size", font_size)

## A screen title: big emerald Courgette with a gold outline, as on the
## title screen.
static func style_title(label: Label, font_size: int = 40) -> void:
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TITLE)
	label.add_theme_color_override("font_outline_color", PALETTE["title_outline"])
	label.add_theme_constant_override("outline_size", 6)

## A heading: gold Courgette.
static func style_heading(label: Label, font_size: int = 22) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GOLD)

# ---- In game: windows over the battlefield and the town ------------------------------

## Marks a window dressed by apply_in_game(); content added under it later
## is dressed as it arrives.
const IN_GAME_META := &"emerald_in_game"

static var _watched_tree: SceneTree = null

## Dress an in-game window (character sheet, a picker, a vendor, the quest
## log...) in the menus' look without touching its layout: the window gets
## the Theme, so its plain Buttons, Labels, tabs and scrollbars turn emerald
## and gold in Courgette, and every old slate/navy stylebox it was built with
## (on the window and on everything inside it, now and later) is re-dressed
## by restyle_legacy() — keeping any meaningful accent: a rarity or item-type
## frame, a card-type colour, a red Close, a hero's tint.
## Card faces (CardUI) shown inside keep their own look.
static func apply_in_game(root: Control) -> void:
	if root == null:
		return
	root.theme = get_theme()
	root.set_meta(IN_GAME_META, true)
	restyle_legacy(root)
	# Builders usually add a window's contents (and the window itself to the
	# tree) right after dressing it.
	(func():
		if is_instance_valid(root):
			restyle_legacy(root)
			if root.is_inside_tree():
				_watch(root.get_tree())).call_deferred()

## Dress every window on a CanvasLayer that holds only windows (the
## character sheet's layer, the battle's window layer): the ones on it now
## and any added later get apply_in_game().
static func dress_layer(layer: CanvasLayer) -> void:
	if layer == null:
		return
	layer.set_meta(IN_GAME_META, true)
	for child in layer.get_children():
		if child is Control:
			apply_in_game(child)
	if layer.is_inside_tree():
		_watch(layer.get_tree())
	else:
		layer.tree_entered.connect(func(): _watch(layer.get_tree()), CONNECT_ONE_SHOT)

static func _watch(tree: SceneTree) -> void:
	if tree == null or _watched_tree == tree:
		return
	_watched_tree = tree
	tree.node_added.connect(_on_node_added)

## Content added under a dressed window (a refreshed list, a hover preview)
## is dressed too. Deferred: builders set their overrides after add_child.
static func _on_node_added(node: Node) -> void:
	if not node is Control:
		return
	var p := node.get_parent()
	if p is CanvasLayer:
		if p.has_meta(IN_GAME_META):
			_dress_window.call_deferred(node)
		return
	while p is Control:
		if p is CardUI:
			return
		if p.has_meta(IN_GAME_META):
			_restyle_one.call_deferred(node)
			return
		p = p.get_parent()

static func _dress_window(node: Node) -> void:
	if is_instance_valid(node) and node is Control and not node.has_meta(IN_GAME_META):
		apply_in_game(node)

static func _restyle_one(node: Node) -> void:
	if is_instance_valid(node) and node is Control:
		_restyle_control(node)

## Re-dress the old in-game look under `root`: a dark slate/navy/walnut
## panel or button face becomes emerald glass (lighter faces stay a little
## lighter, so nested rows still read), a grey or blue-grey frame turns gold.
## Saturated frames — rarity, type, danger, a hero's colour — are kept.
static func restyle_legacy(root: Node) -> void:
	if root is CardUI:
		_shield_card(root)
		return
	if root is Control:
		_restyle_control(root)
	for child in root.get_children():
		restyle_legacy(child)

const _STYLE_SLOTS := ["panel", "normal", "hover", "pressed", "disabled", "hover_pressed",
	"tab_selected", "tab_unselected", "tab_hovered"]

static func _restyle_control(c: Control) -> void:
	if c is CardUI:
		_shield_card(c)
		return
	for slot in _STYLE_SLOTS:
		if not c.has_theme_stylebox_override(slot):
			continue
		var sb := c.get_theme_stylebox(slot)
		var lit: bool = slot in ["hover", "pressed", "hover_pressed", "tab_selected", "tab_hovered"]
		if sb is StyleBoxFlat:
			var re := _restyled_flat(sb, lit)
			if re != sb:
				c.add_theme_stylebox_override(slot, re)
		elif sb is SplitBorderStyleBox:
			sb.set_background(_emerald_bg(sb.get_background()))

## A card face keeps the engine's default look (and the card's own colours)
## even inside a themed window.
static func _shield_card(card: Control) -> void:
	if card.theme == null:
		card.theme = ThemeDB.get_default_theme()

## The StyleBoxFlat re-dressed, or `sb` itself when nothing in it is legacy.
static func _restyled_flat(sb: StyleBoxFlat, lit: bool) -> StyleBoxFlat:
	var bg_old := is_legacy_bg(sb.bg_color) and sb.draw_center
	var has_border := sb.border_width_left + sb.border_width_top + sb.border_width_right + sb.border_width_bottom > 0
	var border_old := has_border and is_legacy_border(sb.border_color)
	if not bg_old and not border_old:
		return sb
	var re := sb.duplicate() as StyleBoxFlat
	if bg_old:
		re.bg_color = _emerald_bg(sb.bg_color)
	if border_old:
		var gold: Color = PALETTE["btn_hover_border"] if lit else GOLD_DIM
		re.border_color = Color(gold, sb.border_color.a)
	return re

## The old in-game face colours: dark and not already green — slate, navy,
## charcoal, walnut. Strong tints (a dark red danger button) are left alone.
static func is_legacy_bg(col: Color) -> bool:
	if col.a <= 0.0 or col.v > 0.3 or col.s >= 0.62:
		return false
	return not (col.g > col.b + 0.005 and col.g > col.r)

## The old frame colours: greys and blue-greys (gold, rarity and type frames
## are saturated warm or bright colours and stay).
static func is_legacy_border(col: Color) -> bool:
	if col.a <= 0.0:
		return false
	# Common rarity is a grey frame too, and it means something.
	if Color(col, 1.0).is_equal_approx(ItemData.rarity_color_of(ItemData.Rarity.COMMON)):
		return false
	if col.s < 0.36:
		return true
	return col.h >= 0.5 and col.h <= 0.72 and col.s < 0.6

## Emerald glass at the same depth: the darkest faces map to the panel glass,
## lighter ones (rows, buttons, hover states) to lighter emerald.
static func _emerald_bg(col: Color) -> Color:
	if not is_legacy_bg(col):
		return col
	var t := clampf((col.v - 0.05) / 0.25, 0.0, 1.0)
	var c := Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b).lerp(Color(0.07, 0.27, 0.21), t)
	return Color(c, col.a)

## Draupnir, the mythic ring, beside a button while the mouse is over it —
## the title menu's hover marker, for a screen's main choices.
static func add_ring_markers(btn: Button, ring_size: float = 34.0) -> void:
	var rings: Array[TextureRect] = []
	for side in [-1, 1]:
		var ring := TextureRect.new()
		ring.texture = DRAUPNIR
		ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ring.size = Vector2(ring_size, ring_size)
		ring.pivot_offset = ring.size * 0.5
		ring.flip_h = side > 0
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.modulate.a = 0.0
		ring.set_meta("side", side)
		btn.add_child(ring)
		rings.append(ring)
	var place := func():
		for ring in rings:
			var gap := 10.0
			var x: float = -ring.size.x - gap if ring.get_meta("side") < 0 else btn.size.x + gap
			ring.position = Vector2(x, (btn.size.y - ring.size.y) * 0.5)
	btn.resized.connect(place)
	place.call()
	btn.mouse_entered.connect(func():
		for ring in rings:
			ring.scale = Vector2(0.6, 0.6)
			var tw := ring.create_tween().set_parallel(true)
			tw.tween_property(ring, "modulate:a", 1.0, 0.12)
			tw.tween_property(ring, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	btn.mouse_exited.connect(func():
		for ring in rings:
			ring.create_tween().tween_property(ring, "modulate:a", 0.0, 0.12))

# ---- The Theme resource --------------------------------------------------------------

static func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_constant("outline_size", "Label", 0)

	# Buttons (and the button-likes that share its look)
	for type in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		t.set_color("font_color", type, PALETTE["btn_font"])
		t.set_color("font_hover_color", type, PALETTE["btn_font_hover"])
		t.set_color("font_pressed_color", type, PALETTE["btn_font_hover"])
		t.set_color("font_hover_pressed_color", type, PALETTE["btn_font_hover"])
		t.set_color("font_focus_color", type, PALETTE["btn_font"])
		t.set_color("font_disabled_color", type, Color(0.5, 0.58, 0.54, 0.7))
		t.set_color("font_outline_color", type, OUTLINE)
		t.set_constant("outline_size", type, 3)
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, button_box())
		t.set_stylebox("hover", type, button_box(PALETTE["btn_hover_bg"], PALETTE["btn_hover_border"], 2, 4, PALETTE["btn_glow"]))
		t.set_stylebox("pressed", type, button_box(PALETTE["btn_hover_bg"].darkened(0.3), PALETTE["btn_hover_border"], 2, 4, PALETTE["btn_glow"]))
		t.set_stylebox("disabled", type, button_box(Color(0.02, 0.07, 0.06, 0.6), Color(0.35, 0.33, 0.25, 0.6), 1))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	# CheckBoxes keep their tick box but lose the button plate.
	for type in ["CheckBox", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb := StyleBoxEmpty.new()
			sb.content_margin_left = 4
			sb.content_margin_right = 4
			t.set_stylebox(state, type, sb)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())

	# Panels
	t.set_stylebox("panel", "Panel", panel_box(PANEL_BG, GOLD_DIM, 1, 6, 0))
	t.set_stylebox("panel", "PanelContainer", panel_box())

	# Tabs
	var tab_sel := button_box(Color(0.05, 0.22, 0.17, 0.95), PALETTE["btn_hover_border"], 0)
	tab_sel.border_width_bottom = 2
	tab_sel.set_corner_radius_all(0)
	tab_sel.corner_radius_top_left = 5
	tab_sel.corner_radius_top_right = 5
	var tab_un := button_box(Color(0.02, 0.09, 0.07, 0.75), GOLD_DIM, 0)
	tab_un.set_corner_radius_all(0)
	tab_un.corner_radius_top_left = 5
	tab_un.corner_radius_top_right = 5
	var tab_hover := tab_un.duplicate() as StyleBoxFlat
	tab_hover.bg_color = Color(0.04, 0.16, 0.12, 0.9)
	for type in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_selected", type, tab_sel)
		t.set_stylebox("tab_unselected", type, tab_un)
		t.set_stylebox("tab_hovered", type, tab_hover)
		t.set_stylebox("tab_focus", type, StyleBoxEmpty.new())
		t.set_color("font_selected_color", type, GOLD)
		t.set_color("font_unselected_color", type, TEXT_DIM)
		t.set_color("font_hovered_color", type, PALETTE["btn_font_hover"])
		t.set_font_size("font_size", type, 18)
	t.set_stylebox("panel", "TabContainer", panel_box(PANEL_BG, GOLD_DIM, 1, 4, 10))

	# Text entry
	for type in ["LineEdit", "TextEdit"]:
		var le := button_box(Color(0.01, 0.06, 0.05, 0.9), GOLD_DIM, 1, 4)
		le.content_margin_left = 8
		t.set_stylebox("normal", type, le)
		var lf := le.duplicate() as StyleBoxFlat
		lf.border_color = PALETTE["btn_hover_border"]
		t.set_stylebox("focus", type, lf)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_placeholder_color", type, Color(TEXT_DIM, 0.7))
		t.set_color("caret_color", type, GOLD)
		t.set_color("selection_color", type, Color(0.25, 0.6, 0.45, 0.5))

	# Rich text
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", bold_font())
	t.set_font("italics_font", "RichTextLabel", font())
	t.set_font("bold_italics_font", "RichTextLabel", bold_font())
	t.set_font_size("normal_font_size", "RichTextLabel", 16)
	t.set_font_size("bold_font_size", "RichTextLabel", 16)

	# Lists
	t.set_stylebox("panel", "ItemList", panel_box(Color(0.01, 0.06, 0.05, 0.85), GOLD_DIM, 1, 4, 4))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", GOLD)
	t.set_color("font_hovered_color", "ItemList", PALETTE["btn_font_hover"])
	var sel := button_box(Color(0.06, 0.25, 0.19, 0.9), PALETTE["btn_hover_border"], 1, 3)
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel)
	t.set_stylebox("hovered", "ItemList", button_box(Color(0.05, 0.18, 0.14, 0.7), Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())

	# Popups (OptionButton lists)
	t.set_stylebox("panel", "PopupMenu", panel_box(PANEL_BG_SOLID, GOLD_DIM, 1, 4, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", PALETTE["btn_font_hover"])
	t.set_stylebox("hover", "PopupMenu", button_box(Color(0.06, 0.25, 0.19, 0.9), Color(0, 0, 0, 0), 0, 3))

	# Scrollbars: a thin gold rail
	for type in ["VScrollBar", "HScrollBar"]:
		var rail := StyleBoxFlat.new()
		rail.bg_color = Color(0.01, 0.06, 0.05, 0.6)
		rail.set_corner_radius_all(4)
		rail.set_content_margin_all(3)
		t.set_stylebox("scroll", type, rail)
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color(GOLD_DIM, 0.85)
		grab.set_corner_radius_all(4)
		t.set_stylebox("grabber", type, grab)
		var grab_hi := grab.duplicate() as StyleBoxFlat
		grab_hi.bg_color = PALETTE["btn_hover_border"]
		t.set_stylebox("grabber_highlight", type, grab_hi)
		t.set_stylebox("grabber_pressed", type, grab_hi)

	# Separators: a faint gold rule
	for type in ["HSeparator", "VSeparator"]:
		var line := StyleBoxLine.new()
		line.color = Color(GOLD_DIM, 0.5)
		line.thickness = 1
		line.vertical = type == "VSeparator"
		t.set_stylebox("separator", type, line)

	# Sliders / progress
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.01, 0.06, 0.05, 0.85)
	bar_bg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.25, 0.75, 0.5)
	bar_fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t
