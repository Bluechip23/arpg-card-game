class_name StatusHoverPopup
extends PanelContainer

## The hover window for buff / debuff badges on the HUD: what the effect is
## and how much of it is left. One shared instance lives on its own
## CanvasLayer above everything else; badges call show_for() on mouse-enter
## and hide_for() on mouse-exit. The remaining-duration line is re-read
## every frame while the window is open, so it counts down live.

static var _inst: StatusHoverPopup = null

var _anchor: Control = null
var _refresh: Callable = Callable()
var _title: Label
var _desc: Label
var _dur: Label
var _extra: Label


static func show_for(anchor: Control, title: String, color: Color, desc: String,
		refresh: Callable, extra: String = "") -> void:
	## refresh: Callable() -> String, the remaining-duration line.
	var p := _instance_for(anchor)
	if p == null:
		return
	p._anchor = anchor
	p._refresh = refresh
	p._title.text = title
	p._title.add_theme_color_override("font_color", color)
	p._desc.text = desc
	p._desc.visible = desc != ""
	p._extra.text = extra
	p._extra.visible = extra != ""
	var style := p.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = color
	p._tick()
	p.visible = true
	p.reset_size()
	p._place()


static func hide_for(anchor: Control) -> void:
	if _inst != null and is_instance_valid(_inst) and _inst._anchor == anchor:
		_inst.visible = false
		_inst._anchor = null
		_inst._refresh = Callable()


static func _instance_for(anchor: Control) -> StatusHoverPopup:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree := anchor.get_tree()
	if tree == null:
		return null
	var layer := CanvasLayer.new()
	layer.name = "StatusHoverLayer"
	layer.layer = 200
	tree.root.add_child(layer)
	_inst = StatusHoverPopup.new()
	layer.add_child(_inst)
	return _inst


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_title)
	_desc = Label.new()
	_desc.add_theme_font_size_override("font_size", 12)
	_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc.custom_minimum_size.x = 220
	vbox.add_child(_desc)
	_dur = Label.new()
	_dur.add_theme_font_size_override("font_size", 12)
	_dur.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	vbox.add_child(_dur)
	_extra = Label.new()
	_extra.add_theme_font_size_override("font_size", 11)
	_extra.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(_extra)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _anchor == null or not is_instance_valid(_anchor) or not _anchor.is_visible_in_tree():
		visible = false
		_anchor = null
		return
	_tick()
	_place()


func _tick() -> void:
	if _refresh.is_valid():
		_dur.text = str(_refresh.call())
	_dur.visible = _dur.text != ""


func _place() -> void:
	## Just below the badge, kept inside the window.
	if _anchor == null:
		return
	var r := _anchor.get_global_rect()
	var vp := get_viewport_rect().size
	var pos := Vector2(r.position.x, r.end.y + 6)
	if pos.y + size.y > vp.y:
		pos.y = r.position.y - size.y - 6
	pos.x = clampf(pos.x, 4, maxf(4, vp.x - size.x - 4))
	global_position = pos
