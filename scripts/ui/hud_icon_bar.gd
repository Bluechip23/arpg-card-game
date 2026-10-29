class_name HudIconBar
extends HBoxContainer

## Top-right HUD bar: the designer's mossy stone bar (tools/cut_hud_bar.py,
## 2026-10-29; was a row of Emerald buttons with drawn glyphs) with five
## stone panels, each a button that opens its window (the keyboard shortcuts
## still work too): Character (the bust), Level Progress (the EXP arrow),
## Quest Journal (the scroll), Deck (the info banner) and Help (the question
## mark). The EXP and Quest panels carry a small yellow notification dot in
## their top-right corner when there's something to do — a level-up point to
## spend, or a new/updated quest.

signal character_pressed
signal level_pressed
signal quest_pressed
signal help_pressed
signal deck_pressed

const BAR := "res://assets/textures/ui/hud_bar.png"
## The stone panels in the bar texture (px), as tools/cut_hud_bar.py prints them.
const PANELS := [Rect2(11, 5, 49, 41), Rect2(65, 5, 65, 41), Rect2(134, 5, 49, 41),
	Rect2(187, 5, 51, 41), Rect2(243, 5, 49, 41)]

var _level_dot: Panel = null
var _quest_dot: Panel = null


func _ready() -> void:
	theme = EmeraldTheme.get_theme()   # Courgette tooltips, like the menus
	var bar := TextureRect.new()
	bar.texture = load(BAR)
	bar.stretch_mode = TextureRect.STRETCH_KEEP
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.custom_minimum_size = bar.texture.get_size()
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bar)

	var specs := [
		[character_pressed, "Character (I)"],
		[level_pressed, "Level Progress (L)"],
		[quest_pressed, "Quest Journal"],
		[deck_pressed, "Deck"],
		[help_pressed, "Help (H)"],
	]
	for i in specs.size():
		var b := _make_button(PANELS[i], specs[i][1])
		var sig: Signal = specs[i][0]
		b.pressed.connect(func(): sig.emit())
		bar.add_child(b)
		if i == 1:
			_level_dot = _make_dot(b)
		elif i == 2:
			_quest_dot = _make_dot(b)


func set_level_notify(on: bool) -> void:
	if _level_dot:
		_level_dot.visible = on

func set_quest_notify(on: bool) -> void:
	if _quest_dot:
		_quest_dot.visible = on


# =============================================================
# WIDGET BUILDERS
# =============================================================

func _make_button(rect: Rect2, tip: String) -> Button:
	## A clear button over one stone panel: the panel is the art; under the
	## mouse it takes a soft gold glow and rim, pressed a deeper one.
	var b := Button.new()
	b.flat = true
	b.tooltip_text = tip
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _glow(0.16, 0.85))
	b.add_theme_stylebox_override("pressed", _glow(0.28, 1.0))
	return b


func _glow(fill: float, rim: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.86, 0.45, fill)
	sb.border_color = Color(1.0, 0.85, 0.4, rim)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb


func _make_dot(parent: Button) -> Panel:
	## A small yellow "attention" dot pinned to the panel's top-right corner.
	var dot := Panel.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size = Vector2(10, 10)
	dot.position = Vector2(parent.size.x - 7, -3)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1.0, 0.85, 0.1)
	st.set_border_width_all(1)
	st.border_color = Color(0.4, 0.3, 0.0)
	st.set_corner_radius_all(5)
	dot.add_theme_stylebox_override("panel", st)
	dot.visible = false
	parent.add_child(dot)
	return dot
