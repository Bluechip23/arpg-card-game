class_name LoadCharacter
extends Control

## Load character screen - displays saved characters with details

@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel
@onready var slot_container: VBoxContainer = $VBox/ScrollContainer/SlotContainer
@onready var back_button: Button = $BackButton
@onready var popup_overlay: ColorRect = $PopupOverlay
@onready var popup_panel: PanelContainer = $PopupOverlay/PopupPanel
@onready var popup_title: Label = $PopupOverlay/PopupPanel/PopupVBox/PopupTitle
@onready var popup_content: VBoxContainer = $PopupOverlay/PopupPanel/PopupVBox/PopupScroll/PopupContent
@onready var close_button: Button = $PopupOverlay/PopupPanel/PopupVBox/CloseButton

func _ready() -> void:
	_apply_styles()
	_load_save_slots()
	back_button.pressed.connect(_on_back_pressed)
	close_button.pressed.connect(_close_popup)
	popup_overlay.gui_input.connect(_on_overlay_click)

func _apply_styles() -> void:
	title_label.text = "Load Character"
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	subtitle_label.text = "Select a saved character to continue your journey."
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.72))

	# Back button
	back_button.add_theme_font_size_override("font_size", 16)
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color(0.2, 0.2, 0.25)
	back_style.border_width_left = 1
	back_style.border_width_right = 1
	back_style.border_width_top = 1
	back_style.border_width_bottom = 1
	back_style.border_color = Color(0.4, 0.4, 0.5)
	back_style.corner_radius_top_left = 4
	back_style.corner_radius_top_right = 4
	back_style.corner_radius_bottom_left = 4
	back_style.corner_radius_bottom_right = 4
	back_button.add_theme_stylebox_override("normal", back_style)
	var back_hover = StyleBoxFlat.new()
	back_hover.bg_color = Color(0.3, 0.3, 0.35)
	back_hover.border_width_left = 1
	back_hover.border_width_right = 1
	back_hover.border_width_top = 1
	back_hover.border_width_bottom = 1
	back_hover.border_color = Color(0.5, 0.5, 0.6)
	back_hover.corner_radius_top_left = 4
	back_hover.corner_radius_top_right = 4
	back_hover.corner_radius_bottom_left = 4
	back_hover.corner_radius_bottom_right = 4
	back_button.add_theme_stylebox_override("hover", back_hover)

	# Popup panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.4, 0.6)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 15.0
	panel_style.content_margin_bottom = 15.0
	popup_panel.add_theme_stylebox_override("panel", panel_style)

	popup_title.add_theme_font_size_override("font_size", 22)
	popup_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	# Close button
	close_button.add_theme_font_size_override("font_size", 14)
	_style_button(close_button, Color(0.4, 0.12, 0.12), Color(0.55, 0.18, 0.18), Color(0.7, 0.25, 0.25), Color(1.0, 0.35, 0.35))

func _load_save_slots() -> void:
	var saves = SaveManager.get_all_saves()
	var has_any_save = false

	for i in range(saves.size()):
		var save = saves[i]
		if save:
			has_any_save = true
			_create_save_slot_card(save, i)

	if not has_any_save:
		var empty_label = Label.new()
		empty_label.text = "No saved characters found."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		slot_container.add_child(empty_label)

func _create_save_slot_card(save: SaveData, slot: int) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 120)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.35, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	slot_container.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	# ── Character Sprite ──
	var sprite_panel = PanelContainer.new()
	sprite_panel.custom_minimum_size = Vector2(80, 96)
	var sp_style = StyleBoxFlat.new()
	sp_style.bg_color = Color(0.06, 0.06, 0.1, 1.0)
	sp_style.border_width_left = 1
	sp_style.border_width_right = 1
	sp_style.border_width_top = 1
	sp_style.border_width_bottom = 1
	sp_style.border_color = Color(0.3, 0.3, 0.45)
	sp_style.corner_radius_top_left = 4
	sp_style.corner_radius_top_right = 4
	sp_style.corner_radius_bottom_left = 4
	sp_style.corner_radius_bottom_right = 4
	sprite_panel.add_theme_stylebox_override("panel", sp_style)
	hbox.add_child(sprite_panel)

	if save.sprite_path != "" and ResourceLoader.exists(save.sprite_path):
		var tex = TextureRect.new()
		tex.texture = load(save.sprite_path)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sprite_panel.add_child(tex)
	else:
		var letter = Label.new()
		letter.text = save.character_name.left(1) if save.character_name != "" else "?"
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
		letter.add_theme_color_override("font_color", Color(0.35, 0.35, 0.5))
		letter.add_theme_font_size_override("font_size", 36)
		sprite_panel.add_child(letter)

	# ── Info Column ──
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Character name
	var name_label = Label.new()
	name_label.text = save.character_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	info_vbox.add_child(name_label)

	# Level
	var level_label = Label.new()
	level_label.text = "Level %d" % save.character_level
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	info_vbox.add_child(level_label)

	# Location
	var location_label = Label.new()
	location_label.text = "Location: %s" % save.current_location
	location_label.add_theme_font_size_override("font_size", 12)
	location_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	info_vbox.add_child(location_label)

	# Time played
	var time_label = Label.new()
	time_label.text = "Time Played: %s" % save.get_time_played_string()
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	info_vbox.add_child(time_label)

	# ── Button Column ──
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)
	btn_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn_vbox)

	# Load button
	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(100, 35)
	load_btn.add_theme_font_size_override("font_size", 14)
	_style_button(load_btn, Color(0.15, 0.3, 0.15), Color(0.2, 0.4, 0.2), Color(0.3, 0.6, 0.3), Color(0.4, 0.8, 0.4))
	load_btn.pressed.connect(_on_load_slot.bind(save))
	btn_vbox.add_child(load_btn)

	# Inventory button
	var inv_btn = Button.new()
	inv_btn.text = "Inventory"
	inv_btn.custom_minimum_size = Vector2(100, 35)
	inv_btn.add_theme_font_size_override("font_size", 14)
	_style_button(inv_btn, Color(0.15, 0.25, 0.45), Color(0.2, 0.35, 0.6), Color(0.3, 0.5, 0.8), Color(0.4, 0.65, 1.0))
	inv_btn.pressed.connect(_show_inventory_popup.bind(save))
	btn_vbox.add_child(inv_btn)

	# Deck button
	var deck_btn = Button.new()
	deck_btn.text = "Deck"
	deck_btn.custom_minimum_size = Vector2(100, 35)
	deck_btn.add_theme_font_size_override("font_size", 14)
	_style_button(deck_btn, Color(0.35, 0.2, 0.45), Color(0.45, 0.28, 0.58), Color(0.55, 0.35, 0.7), Color(0.7, 0.45, 0.9))
	deck_btn.pressed.connect(_show_deck_popup.bind(save))
	btn_vbox.add_child(deck_btn)

func _on_load_slot(save: SaveData) -> void:
	if not save.character_data:
		print("[LOAD] No character data in save!")
		return

	print("[LOAD] Loading character: %s" % save.character_name)
	_show_mode_select(save.character_data)

func _show_mode_select(character: CharacterData) -> void:
	# Same mode select as character_select: Town vs Fight
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -200.0
	panel.offset_top = -120.0
	panel.offset_right = 200.0
	panel.offset_bottom = 120.0

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	p_style.border_width_left = 2
	p_style.border_width_right = 2
	p_style.border_width_top = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.4, 0.4, 0.6)
	p_style.corner_radius_top_left = 8
	p_style.corner_radius_top_right = 8
	p_style.corner_radius_bottom_left = 8
	p_style.corner_radius_bottom_right = 8
	p_style.content_margin_left = 30.0
	p_style.content_margin_right = 30.0
	p_style.content_margin_top = 25.0
	p_style.content_margin_bottom = 25.0
	panel.add_theme_stylebox_override("panel", p_style)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var mtitle = Label.new()
	mtitle.text = "Where to?"
	mtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtitle.add_theme_font_size_override("font_size", 28)
	mtitle.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	vbox.add_child(mtitle)

	var msub = Label.new()
	msub.text = "Playing as %s" % character.character_name
	msub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msub.add_theme_font_size_override("font_size", 14)
	msub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(msub)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(btn_hbox)

	var town_btn = Button.new()
	town_btn.text = "To Town"
	town_btn.custom_minimum_size = Vector2(150, 50)
	town_btn.add_theme_font_size_override("font_size", 18)
	_style_button(town_btn, Color(0.15, 0.3, 0.15), Color(0.2, 0.4, 0.2), Color(0.3, 0.6, 0.3), Color(0.4, 0.8, 0.4))
	town_btn.pressed.connect(_on_mode_town.bind(character, overlay))
	btn_hbox.add_child(town_btn)

	var fight_btn = Button.new()
	fight_btn.text = "Fight"
	fight_btn.custom_minimum_size = Vector2(150, 50)
	fight_btn.add_theme_font_size_override("font_size", 18)
	_style_button(fight_btn, Color(0.4, 0.12, 0.12), Color(0.55, 0.18, 0.18), Color(0.7, 0.25, 0.25), Color(1.0, 0.35, 0.35))
	fight_btn.pressed.connect(_on_mode_fight.bind(character, overlay))
	btn_hbox.add_child(fight_btn)

	add_child(overlay)

func _on_mode_town(character: CharacterData, _overlay: ColorRect) -> void:
	print("[LOAD] Going to town with %s" % character.character_name)
	var town_scene = load("res://scenes/town.tscn").instantiate()
	town_scene.starting_character = character
	get_tree().root.add_child(town_scene)
	queue_free()

func _on_mode_fight(character: CharacterData, _overlay: ColorRect) -> void:
	print("[LOAD] Going to fight with %s" % character.character_name)
	var main_scene = load("res://main.tscn").instantiate()
	main_scene.starting_character = character
	get_tree().root.add_child(main_scene)
	queue_free()

# ── Popup: Inventory ──

func _show_inventory_popup(save: SaveData) -> void:
	_clear_popup_content()
	popup_title.text = "%s's Inventory" % save.character_name

	if save.equipped_item_names.size() == 0:
		var empty = Label.new()
		empty.text = "No items equipped."
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		popup_content.add_child(empty)
	else:
		for item_name in save.equipped_item_names:
			var lbl = Label.new()
			lbl.text = item_name
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
			popup_content.add_child(lbl)

	popup_overlay.visible = true

# ── Popup: Deck ──

func _show_deck_popup(save: SaveData) -> void:
	_clear_popup_content()
	popup_title.text = "%s's Deck" % save.character_name

	if save.deck_card_ids.size() == 0:
		var empty = Label.new()
		empty.text = "No cards in deck."
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		popup_content.add_child(empty)
	else:
		# Count duplicates for cleaner display
		var card_counts: Dictionary = {}
		for card_id in save.deck_card_ids:
			if card_id in card_counts:
				card_counts[card_id] += 1
			else:
				card_counts[card_id] = 1

		for card_id in card_counts:
			var count = card_counts[card_id]
			var display_name = _card_id_to_display_name(card_id)
			var lbl = Label.new()
			if count > 1:
				lbl.text = "%s x%d" % [display_name, count]
			else:
				lbl.text = display_name
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", _get_card_color(card_id))
			popup_content.add_child(lbl)

	popup_overlay.visible = true

func _card_id_to_display_name(card_id: String) -> String:
	# Convert snake_case card_id to Title Case display name
	var words = card_id.split("_")
	var result = ""
	for word in words:
		if result != "":
			result += " "
		result += word.capitalize()
	return result

func _get_card_color(card_id: String) -> Color:
	# Color-code by known card types for visual clarity
	var attack_ids = ["slash", "empower", "mark", "quick_shot", "trick_shot", "charge", "poke", "sky_attack", "sky_fall"]
	var defense_ids = ["block", "barricade", "turtle_up", "parry", "hold_the_line"]
	var utility_ids = ["heal", "draw", "discard", "gain_mana", "blink", "preparation", "meditate", "reload"]

	if card_id in attack_ids:
		return Color(1.0, 0.5, 0.4)  # Red-ish
	elif card_id in defense_ids:
		return Color(0.5, 0.7, 1.0)  # Blue-ish
	elif card_id in utility_ids:
		return Color(0.5, 1.0, 0.5)  # Green-ish
	else:
		return Color(0.85, 0.85, 0.9)  # Default light

func _clear_popup_content() -> void:
	for child in popup_content.get_children():
		child.queue_free()

func _close_popup() -> void:
	popup_overlay.visible = false

func _on_overlay_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_popup()

func _on_back_pressed() -> void:
	var load_or_new_scene = load("res://scenes/load_or_new.tscn").instantiate()
	get_tree().root.add_child(load_or_new_scene)
	queue_free()

# ── Helpers ──

func _style_button(btn: Button, normal_bg: Color, hover_bg: Color, normal_border: Color, hover_border: Color) -> void:
	var ns = StyleBoxFlat.new()
	ns.bg_color = normal_bg
	ns.border_width_left = 2
	ns.border_width_right = 2
	ns.border_width_top = 2
	ns.border_width_bottom = 2
	ns.border_color = normal_border
	ns.corner_radius_top_left = 6
	ns.corner_radius_top_right = 6
	ns.corner_radius_bottom_left = 6
	ns.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", ns)
	var hs = StyleBoxFlat.new()
	hs.bg_color = hover_bg
	hs.border_width_left = 2
	hs.border_width_right = 2
	hs.border_width_top = 2
	hs.border_width_bottom = 2
	hs.border_color = hover_border
	hs.corner_radius_top_left = 6
	hs.corner_radius_top_right = 6
	hs.corner_radius_bottom_left = 6
	hs.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hs)
