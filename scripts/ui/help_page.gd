class_name HelpPage
extends Control

## Standalone help page accessible from the title menu.
## Displays the gameplay walkthrough and keyword legend.
##
## Wears the menus' Emerald Sanctum theme. The Walkthrough and Keywords tabs
## are shared with the in-battle help panel, so their scripts stay as they
## are; this page retunes their output after they build (bigger text for
## Courgette, the decorative heading colours turned emerald and gold).

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBox/TabContainer
@onready var back_button: Button = $Panel/MarginContainer/VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_apply_styles()

func _apply_styles() -> void:
	EmeraldTheme.apply(self, true, 0.55)
	var panel = $Panel as PanelContainer
	if panel:
		# Clear glass over the forest; the tab body carries the framed panel.
		var style := StyleBoxEmpty.new()
		style.set_content_margin_all(20.0)
		panel.add_theme_stylebox_override("panel", style)
	if back_button:
		EmeraldTheme.style_button(back_button, 16)
	_retune_walkthrough()
	_retune_keywords()

func _retune_walkthrough() -> void:
	var rtl := get_node_or_null("Panel/MarginContainer/VBox/TabContainer/Walkthrough/Content") as RichTextLabel
	if rtl == null:
		return
	var title := "#" + EmeraldTheme.TITLE.to_html(false)
	var gold := "#" + EmeraldTheme.GOLD.to_html(false)
	var text := rtl.text
	# Section banners (cyan) → emerald; sub-headings (yellow) and the page
	# title → gold. Stat and status colours are left as they are.
	text = text.replace("[font_size=24][color=gold]", "[font_size=34][color=%s]" % title)
	text = text.replace("[font_size=18][color=cyan]", "[font_size=24][color=%s]" % title)
	text = text.replace("[font_size=18]", "[font_size=24]")
	text = text.replace("[color=yellow]", "[color=%s]" % gold)
	rtl.text = text
	rtl.add_theme_font_size_override("normal_font_size", 17)
	rtl.add_theme_font_size_override("bold_font_size", 17)

func _retune_keywords() -> void:
	var content := get_node_or_null("Panel/MarginContainer/VBox/TabContainer/Keywords/Content")
	if content == null:
		return
	if content is VBoxContainer:
		content.add_theme_constant_override("separation", 6)
	for row in content.get_children():
		if row is Label:  # section header
			EmeraldTheme.style_heading(row, 24)
		elif row is HBoxContainer:
			row.custom_minimum_size.y = 34
			for lbl in row.get_children():
				if not lbl is Label:
					continue
				var fs: int = lbl.get_theme_font_size("font_size")
				lbl.add_theme_font_size_override("font_size", fs + 4)
				if lbl.custom_minimum_size.x > 0.0:  # the keyword column
					lbl.custom_minimum_size.x = 190
					lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
					lbl.add_theme_color_override("font_outline_color", EmeraldTheme.OUTLINE)
					lbl.add_theme_constant_override("outline_size", 3)
					if lbl.get_theme_color("font_color") == Color.WHITE:
						lbl.add_theme_color_override("font_color", EmeraldTheme.GOLD)

func _on_back_pressed() -> void:
	var title_scene = load("res://scenes/menus/title_menu.tscn").instantiate()
	get_tree().root.add_child(title_scene)
	queue_free()
