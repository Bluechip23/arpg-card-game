class_name SaveSlotPicker
extends CanvasLayer

## The "choose a slot" save dialog, shared by town and the world (the HUD's
## ? menu, town's SAVE GAME button, and "save before you quit" when the
## character has no slot of their own yet). `build` makes the SaveData for a
## slot; the picker writes it and lists the slots again.
##   SaveSlotPicker.open(host, build)            — stays open after saving
##   SaveSlotPicker.open(host, build, true)      — closes on the first save
## `finished(saved)` fires when it closes: whether anything was written.

signal finished(saved: bool)

var _build: Callable
var _close_on_save := false
var _saved := false
var _buttons: Array[Button] = []
var _status: Label

static func open(host: Node, build: Callable, close_on_save: bool = false) -> SaveSlotPicker:
	var p := SaveSlotPicker.new()
	p._build = build
	p._close_on_save = close_on_save
	host.add_child(p)
	return p

func _ready() -> void:
	layer = 110                                 # over the help panel (90) and the HUD
	process_mode = Node.PROCESS_MODE_ALWAYS     # works while the game is paused
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	var box := EmeraldTheme.panel_box(EmeraldTheme.PANEL_BG_SOLID)
	box.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", box)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(400, 0)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "Save Game — choose a slot"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	EmeraldTheme.style_heading(title, 24)
	vbox.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", EmeraldTheme.font())
	_status.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_status)
	for slot in range(SaveManager.MAX_SAVE_SLOTS):
		var b := Button.new()
		b.name = "Slot%d" % slot
		b.custom_minimum_size = Vector2(380, 38)
		EmeraldTheme.style_button(b, 16)
		b.pressed.connect(save_to.bind(slot))
		vbox.add_child(b)
		_buttons.append(b)
	var close := Button.new()
	close.name = "Close"
	close.text = "Close"
	close.custom_minimum_size = Vector2(380, 36)
	EmeraldTheme.style_button(close, 16)
	close.pressed.connect(close_picker)
	vbox.add_child(close)
	_refresh()

func _refresh() -> void:
	for slot in range(_buttons.size()):
		var existing := SaveManager.load_game(slot)
		if existing:
			_buttons[slot].text = "Slot %d — %s (Lv %d)" % [slot + 1, existing.character_name, existing.character_level]
		else:
			_buttons[slot].text = "Slot %d — Empty" % [slot + 1]

## Write the game to `slot`.
func save_to(slot: int) -> void:
	var data: SaveData = _build.call(slot)
	var ok := data != null and SaveManager.save_game(slot, data)
	if ok:
		_saved = true
		_status.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		_status.text = "Saved %s to slot %d." % [data.character_name, slot + 1]
	else:
		_status.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
		_status.text = "Save failed (see log)."
	_refresh()
	if ok and _close_on_save:
		close_picker()

func close_picker() -> void:
	finished.emit(_saved)
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_picker()
		get_viewport().set_input_as_handled()
