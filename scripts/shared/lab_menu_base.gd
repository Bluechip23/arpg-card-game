extends Control

## What the two dev labs (AnimationLab, EnemyLab) share: the searchable list
## of entries down the left, its section headers and button style, the
## glass panels and the facing buttons. Each lab builds its own list and
## says what a facing button does (_on_set_direction).

var _list_vbox: VBoxContainer = null
var _entry_buttons: Array[Dictionary] = []   # {"button": Button, "search": lower-case text}

## A facing button pressed (each lab turns its figure).
func _on_set_direction(_dir: int) -> void:
	pass

func _add_dir_button(parent: Node, label: String, dir: int) -> void:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(_on_set_direction.bind(dir))
	parent.add_child(btn)

func _add_section_header(text: String) -> void:
	var header := Label.new()
	header.text = text
	EmeraldTheme.style_heading(header, 19)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_list_vbox.add_child(spacer)
	_list_vbox.add_child(header)

func _on_filter_changed(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	for entry in _entry_buttons:
		var btn: Button = entry["button"]
		btn.visible = needle == "" or entry["search"].contains(needle)

func _glass_panel(column: Control, expand: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",
		EmeraldTheme.panel_box(EmeraldTheme.PANEL_BG, EmeraldTheme.GOLD_DIM, 1, 6, 10))
	panel.add_child(column)
	return panel

static func _style_list_button(btn: Button) -> void:
	var bare := StyleBoxEmpty.new()
	bare.content_margin_left = 8
	bare.content_margin_right = 8
	bare.content_margin_top = 1
	bare.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", bare)
	var hover := EmeraldTheme.button_box(EmeraldTheme.PALETTE["btn_hover_bg"], EmeraldTheme.PALETTE["btn_hover_border"], 1, 3)
	hover.content_margin_left = 8
	hover.content_margin_top = 1
	hover.content_margin_bottom = 3
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_constant_override("outline_size", 0)
