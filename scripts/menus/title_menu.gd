class_name TitleMenu
extends Control

## Title menu screen - Trials of Olorin
##
## The title itself is drawn by the animated TitleCutscene (Olorin, the boy,
## the pipe, and the two smoke rings that become the O's of OLORIN). The menu
## fades in once the cutscene finishes (or is skipped).

const CharacterSelectScene = preload("res://scenes/character/character_select.tscn")
const LoadOrNewScene = preload("res://scenes/character/load_or_new.tscn")
const TitleCutsceneScript = preload("res://scripts/menus/title_cutscene.gd")
const DRAUPNIR := preload("res://assets/items/mythic/draupnir.png")

## The three forest looks on offer for the title screen (the designer picks
## one; until then 1 / 2 / 3 on the title screen swaps between them). Each is
## the backdrop palette the cutscene paints with plus the menu's button style.
const STYLES := [
	{
		"name": "Moonlit Glade",
		# Backdrop
		"sky_top": Color(0.02, 0.05, 0.05), "sky_horizon": Color(0.07, 0.19, 0.13),
		"stars": true, "moon": Color(0.93, 0.95, 0.82), "moon_crescent": true,
		"ground": Color(0.05, 0.12, 0.06), "ground_edge": Color(0.10, 0.22, 0.10),
		"tree_back": Color(0.13, 0.25, 0.18), "tree_front": Color(0.05, 0.10, 0.07),
		"motes": Color(0.85, 1.0, 0.45), "mote_count": 24,
		"mist": Color(0, 0, 0, 0),
		"title_fill": Color(0.98, 0.85, 0.48), "title_outline": Color(0.05, 0.16, 0.07),
		# Menu: bare script lettering, a faint leaf-green wash on hover
		"btn_bg": Color(0, 0, 0, 0), "btn_border": Color(0, 0, 0, 0), "btn_border_w": 0,
		"btn_hover_bg": Color(0.05, 0.16, 0.08, 0.55), "btn_hover_border": Color(0.85, 0.72, 0.35, 0.0),
		"btn_hover_border_w": 0, "btn_radius": 18, "btn_glow": Color(0, 0, 0, 0),
		"btn_font": Color(0.93, 0.89, 0.74), "btn_font_hover": Color(1.0, 0.86, 0.42),
		"btn_outline": Color(0.03, 0.08, 0.04, 0.9), "panel": Color(0, 0, 0, 0),
	},
	{
		"name": "Elderwood Dusk",
		"sky_top": Color(0.17, 0.16, 0.30), "sky_horizon": Color(0.92, 0.58, 0.26),
		"stars": false, "moon": Color(1.0, 0.86, 0.55), "moon_crescent": false,
		"ground": Color(0.13, 0.20, 0.07), "ground_edge": Color(0.27, 0.38, 0.13),
		"tree_back": Color(0.26, 0.18, 0.20), "tree_front": Color(0.12, 0.08, 0.07),
		"motes": Color(1.0, 0.82, 0.45), "mote_count": 16,
		"mist": Color(1.0, 0.75, 0.45, 0.07),
		"title_fill": Color(0.99, 0.95, 0.82), "title_outline": Color(0.32, 0.17, 0.06),
		# Menu: carved-wood plaques with gilt edges
		"btn_bg": Color(0.30, 0.19, 0.09, 0.94), "btn_border": Color(0.74, 0.56, 0.26), "btn_border_w": 2,
		"btn_hover_bg": Color(0.42, 0.27, 0.12, 0.97), "btn_hover_border": Color(1.0, 0.83, 0.42),
		"btn_hover_border_w": 3, "btn_radius": 10, "btn_glow": Color(0, 0, 0, 0.45),
		"btn_font": Color(0.98, 0.92, 0.78), "btn_font_hover": Color(1.0, 0.98, 0.88),
		"btn_outline": Color(0.18, 0.09, 0.03, 0.9), "panel": Color(0, 0, 0, 0),
	},
	{
		"name": "Emerald Sanctum",
		"sky_top": Color(0.01, 0.05, 0.07), "sky_horizon": Color(0.06, 0.27, 0.25),
		"stars": true, "moon": Color(0.82, 1.0, 0.93), "moon_crescent": true,
		"ground": Color(0.03, 0.11, 0.09), "ground_edge": Color(0.08, 0.28, 0.22),
		"tree_back": Color(0.12, 0.33, 0.30), "tree_front": Color(0.03, 0.09, 0.08),
		"motes": Color(0.55, 1.0, 0.85), "mote_count": 32, "aurora": true,
		"mist": Color(0.45, 0.95, 0.80, 0.10),
		"title_fill": Color(0.58, 0.98, 0.72), "title_outline": Color(0.42, 0.30, 0.07),
		# Menu: elven glass on a gilt-edged tablet
		"btn_bg": Color(0.03, 0.14, 0.11, 0.80), "btn_border": Color(0.70, 0.56, 0.26), "btn_border_w": 1,
		"btn_hover_bg": Color(0.05, 0.23, 0.18, 0.92), "btn_hover_border": Color(0.98, 0.82, 0.40),
		"btn_hover_border_w": 2, "btn_radius": 4, "btn_glow": Color(0.98, 0.80, 0.35, 0.35),
		"btn_font": Color(0.80, 0.96, 0.86), "btn_font_hover": Color(1.0, 0.90, 0.55),
		"btn_outline": Color(0.01, 0.06, 0.05, 0.9), "panel": Color(0.01, 0.07, 0.06, 0.55),
	},
]

## Which STYLES entry is showing. Static, so it survives returning to the
## title from another screen.
static var style: int = 0

@onready var title_label: Label = $VBox/TitleLabel
@onready var menu_container: VBoxContainer = $VBox/MenuContainer
@onready var background: ColorRect = $Background

# Draupnir markers (one pair per menu item), shown beside the hovered option.
var _left_rings: Array[TextureRect] = []
var _right_rings: Array[TextureRect] = []
var _menu_buttons: Array[Button] = []
var _cutscene: Control = null
var _hovered: int = -1
var _ring_t: float = 0.0
var _style_hint: Label = null
var _tablet: Panel = null

var _menu_items: Array[Dictionary] = [
	{"text": "Single Player", "action": "_on_single_player"},
	{"text": "Multiplayer", "action": "_on_multiplayer"},
	{"text": "Test", "action": "_on_test"},
	{"text": "Compendium", "action": "_on_compendium"},
	{"text": "Settings", "action": "_on_settings"},
	{"text": "Help", "action": "_on_help"},
	{"text": "Quit", "action": "_on_quit"},
]

# The Test submenu: everything used for trying things out.
var _test_items: Array[Dictionary] = [
	{"text": "Sandbox", "action": "_on_sandbox"},
	{"text": "Boss Simulator", "action": "_on_boss_simulator"},
	{"text": "Animation Lab", "action": "_on_animation_lab"},
	{"text": "Enemy Lab", "action": "_on_enemy_lab"},
	{"text": "Back", "action": "_on_test_back"},
]

static func current_style() -> Dictionary:
	return STYLES[clampi(style, 0, STYLES.size() - 1)]

func _ready() -> void:
	var pal := current_style()
	background.color = pal["sky_top"]
	_build_menu()
	# The cutscene draws the backdrop AND the title; the plain label is retired.
	if title_label:
		title_label.visible = false
	_cutscene = TitleCutsceneScript.new()
	_cutscene.name = "TitleCutscene"
	_cutscene.palette = pal
	_cutscene.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_cutscene)
	move_child(_cutscene, 1)  # above Background, below VBox
	# Hide the menu until Olorin has settled back onto his chair.
	$VBox.visible = false
	$VBox.modulate.a = 0.0
	_cutscene.cutscene_finished.connect(_on_cutscene_finished)
	_build_style_hint()

func _on_cutscene_finished() -> void:
	$VBox.visible = true
	var tween := create_tween()
	tween.tween_property($VBox, "modulate:a", 1.0, 0.8)

func _process(delta: float) -> void:
	_fit_tablet()
	# The hovered option's rings rock gently, like a coin catching the light.
	_ring_t += delta
	if _hovered >= 0 and _hovered < _left_rings.size():
		var rock := sin(_ring_t * 2.4) * 0.14
		_left_rings[_hovered].rotation = rock
		_right_rings[_hovered].rotation = -rock

func _unhandled_input(event: InputEvent) -> void:
	# Style preview: 1 / 2 / 3 swap the title screen's look.
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < STYLES.size() and idx != style:
			style = idx
			var fresh = load("res://scenes/menus/title_menu.tscn").instantiate()
			get_tree().root.add_child(fresh)
			queue_free()

func _build_style_hint() -> void:
	_style_hint = Label.new()
	_style_hint.text = "Style %d of %d: %s  (press 1 / 2 / 3 to compare)" % [
		style + 1, STYLES.size(), current_style()["name"]]
	_style_hint.add_theme_font_override("font", GameFonts.courgette())
	_style_hint.add_theme_font_size_override("font_size", 16)
	_style_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_style_hint.position = Vector2(14, 8)
	_style_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_style_hint)

func _build_menu(items: Array[Dictionary] = []) -> void:
	if items.is_empty():
		items = _menu_items
	var pal := current_style()
	# Clear any previous menu (used when swapping to/from the Test submenu).
	for child in menu_container.get_children():
		child.queue_free()
	_left_rings.clear()
	_right_rings.clear()
	_menu_buttons.clear()
	_hovered = -1
	menu_container.add_theme_constant_override("separation", 10)
	_apply_menu_panel(pal)
	for i in range(items.size()):
		var item = items[i]

		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 14)
		menu_container.add_child(hbox)

		var left_ring := _create_ring(false)
		hbox.add_child(left_ring)
		_left_rings.append(left_ring)

		var btn = Button.new()
		btn.text = item["text"]
		btn.custom_minimum_size = Vector2(270, 50)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", GameFonts.courgette())
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", pal["btn_font"])
		btn.add_theme_color_override("font_hover_color", pal["btn_font_hover"])
		btn.add_theme_color_override("font_pressed_color", pal["btn_font_hover"])
		btn.add_theme_color_override("font_outline_color", pal["btn_outline"])
		btn.add_theme_constant_override("outline_size", 5)
		btn.add_theme_stylebox_override("normal",
			_button_box(pal["btn_bg"], pal["btn_border"], pal["btn_border_w"], pal["btn_radius"], Color(0, 0, 0, 0)))
		btn.add_theme_stylebox_override("hover",
			_button_box(pal["btn_hover_bg"], pal["btn_hover_border"], pal["btn_hover_border_w"], pal["btn_radius"], pal["btn_glow"]))
		btn.add_theme_stylebox_override("pressed",
			_button_box(pal["btn_hover_bg"].darkened(0.25), pal["btn_hover_border"], pal["btn_hover_border_w"], pal["btn_radius"], pal["btn_glow"]))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		btn.mouse_entered.connect(_on_button_hover.bind(i))
		btn.mouse_exited.connect(_on_button_unhover.bind(i))
		btn.pressed.connect(Callable(self, item["action"]))

		hbox.add_child(btn)
		_menu_buttons.append(btn)

		var right_ring := _create_ring(true)
		hbox.add_child(right_ring)
		_right_rings.append(right_ring)

func _apply_menu_panel(pal: Dictionary) -> void:
	## Styles that set "panel" seat the options on a translucent tablet: a
	## sibling just behind the menu column (outside its layout) that tracks
	## the column's rect and fade each frame.
	var col: Color = pal["panel"]
	if col.a <= 0.0 or (_tablet and is_instance_valid(_tablet)):
		return
	var tablet := Panel.new()
	tablet.name = "MenuPanelBG"
	tablet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_border_width_all(1)
	sb.border_color = Color(pal["btn_border"], 0.6)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 14
	tablet.add_theme_stylebox_override("panel", sb)
	add_child(tablet)
	move_child(tablet, $VBox.get_index())
	_tablet = tablet

func _fit_tablet() -> void:
	if _tablet and is_instance_valid(_tablet):
		var r := menu_container.get_global_rect().grow_individual(8, 22, 8, 22)
		_tablet.global_position = r.position
		_tablet.size = r.size
		_tablet.visible = $VBox.visible
		_tablet.modulate.a = $VBox.modulate.a

static func _button_box(bg: Color, border: Color, border_w: int, radius: int, glow: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.content_margin_top = 2
	sb.content_margin_bottom = 6  # script descenders sit low; lift the text
	if glow.a > 0.0:
		sb.shadow_color = glow
		sb.shadow_size = 9
	return sb

func _create_ring(mirrored: bool) -> TextureRect:
	## Draupnir, the mythic ring, marks the hovered option on both sides.
	var ring := TextureRect.new()
	ring.texture = DRAUPNIR
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ring.custom_minimum_size = Vector2(46, 46)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ring.pivot_offset = Vector2(23, 23)
	ring.flip_h = mirrored
	ring.modulate.a = 0.0
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ring

func _on_button_hover(index: int) -> void:
	if index >= 0 and index < _left_rings.size():
		_hovered = index
		for ring in [_left_rings[index], _right_rings[index]]:
			ring.scale = Vector2(0.6, 0.6)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(ring, "modulate:a", 1.0, 0.12)
			tw.tween_property(ring, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_button_unhover(index: int) -> void:
	if index >= 0 and index < _left_rings.size():
		if _hovered == index:
			_hovered = -1
		for ring in [_left_rings[index], _right_rings[index]]:
			create_tween().tween_property(ring, "modulate:a", 0.0, 0.12)

func _on_single_player() -> void:
	var load_or_new = LoadOrNewScene.instantiate()
	get_tree().root.add_child(load_or_new)
	queue_free()

func _on_multiplayer() -> void:
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "multiplayer"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_test() -> void:
	## Swap to the Test submenu (Sandbox / Animation Lab / Enemy Lab).
	_build_menu(_test_items)

func _on_test_back() -> void:
	_build_menu(_menu_items)

func _on_sandbox() -> void:
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "sandbox"
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_boss_simulator() -> void:
	## The sandbox, booted straight into a boss-room picker: every sandbox
	## tool (cards, items, passives, stats, allies) works inside the fight.
	var select_scene = CharacterSelectScene.instantiate()
	select_scene.game_mode = "sandbox"
	select_scene.boss_sim = true
	get_tree().root.add_child(select_scene)
	queue_free()

func _on_compendium() -> void:
	var compendium_scene = load("res://scenes/ui/compendium_page.tscn").instantiate()
	get_tree().root.add_child(compendium_scene)
	queue_free()

func _on_animation_lab() -> void:
	var lab_scene = load("res://scenes/menus/animation_lab.tscn").instantiate()
	get_tree().root.add_child(lab_scene)
	queue_free()

func _on_enemy_lab() -> void:
	var lab_scene = load("res://scenes/menus/enemy_lab.tscn").instantiate()
	get_tree().root.add_child(lab_scene)
	queue_free()

func _on_settings() -> void:
	# Placeholder - settings not yet implemented
	print("[MENU] Settings selected (not yet implemented)")

func _on_help() -> void:
	var help_scene = load("res://scenes/ui/help_page.tscn").instantiate()
	get_tree().root.add_child(help_scene)
	queue_free()

func _on_quit() -> void:
	get_tree().quit()
