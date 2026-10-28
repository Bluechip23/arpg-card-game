class_name StatusHoverPopup
extends PanelContainer

## The hover window for buff / debuff badges on the HUD: what the effect is
## and how much of it is left. One shared instance lives on its own
## CanvasLayer above everything else; badges call show_for() on mouse-enter
## and hide_for() on mouse-exit. The remaining-duration line is re-read
## every frame while the window is open, so it counts down live.
##
## This is the ONLY window a badge opens: the badges set no tooltip_text and
## define no _make_custom_tooltip, so the engine's own tooltip never doubles
## it. The frame is the game's crested tooltip frame (T&O seal on top).

static var _inst: StatusHoverPopup = null

var _anchor: Control = null
var _refresh: Callable = Callable()
var _title: Label
var _desc: Label
var _dur: Label
var _extra: Label
var _icon_slot: Control = null   # left of the words: the effect's icon, large


static func show_for(anchor: Control, title: String, color: Color, desc: String,
		refresh: Callable, extra: String = "", icon: Texture2D = null) -> void:
	## refresh: Callable() -> String, the remaining-duration line. `icon`:
	## the buff / debuff's icon, shown large beside the words (IconTooltip).
	var p := _instance_for(anchor)
	if p == null:
		return
	for c in p._icon_slot.get_children():
		p._icon_slot.remove_child(c)
		c.queue_free()
	var box := IconTooltip.icon_box(icon, color)
	if box:
		p._icon_slot.add_child(box)
	p._icon_slot.visible = box != null
	p._anchor = anchor
	p._refresh = refresh
	p._title.text = title
	p._title.add_theme_color_override("font_color", color)
	p._desc.text = desc
	p._desc.visible = desc != ""
	p._extra.text = extra
	p._extra.visible = extra != ""
	var style := p.get_theme_stylebox("panel") as CrestStyleBox
	if style:
		style.panel.border_color = color
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
	# Emerald Sanctum glass; the frame takes the effect's colour in show_for.
	theme = EmeraldTheme.get_theme()
	var style := CrestStyleBox.new(EmeraldTheme.PANEL_BG_SOLID, EmeraldTheme.GOLD_DIM, 4, 2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 7
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon_slot = MarginContainer.new()
	_icon_slot.name = "IconSlot"
	_icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_slot.visible = false
	row.add_child(_icon_slot)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_title)
	_desc = Label.new()
	_desc.add_theme_font_size_override("font_size", 12)
	_desc.add_theme_color_override("font_color", EmeraldTheme.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc.custom_minimum_size.x = 220
	vbox.add_child(_desc)
	_dur = Label.new()
	_dur.add_theme_font_size_override("font_size", 12)
	_dur.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	vbox.add_child(_dur)
	_extra = Label.new()
	_extra.add_theme_font_size_override("font_size", 11)
	_extra.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
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
	var pos := Vector2(r.position.x, r.end.y + 8)
	if pos.y + size.y > vp.y:
		pos.y = r.position.y - size.y - 8
	pos.x = clampf(pos.x, 4, maxf(4, vp.x - size.x - 4))
	global_position = pos
