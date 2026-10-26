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
	EmeraldTheme.apply(self)
	title_label.text = "Load Character"
	EmeraldTheme.style_title(title_label, 44)

	subtitle_label.text = "Select a saved character to continue your journey."
	subtitle_label.add_theme_font_size_override("font_size", 17)
	subtitle_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)

	EmeraldTheme.style_button(back_button, 16)

	# Inventory / Deck popup: solid emerald glass, gold frame.
	popup_panel.add_theme_stylebox_override("panel",
		EmeraldTheme.panel_box(EmeraldTheme.PANEL_BG_SOLID, EmeraldTheme.GOLD_DIM, 2, 8, 18.0))
	EmeraldTheme.style_heading(popup_title, 26)
	EmeraldTheme.style_button(close_button, 16)
	close_button.custom_minimum_size = Vector2(140, 36)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

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
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
		slot_container.add_child(empty_label)

func _create_save_slot_card(save: SaveData, slot: int) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 120)
	panel.add_theme_stylebox_override("panel",
		EmeraldTheme.panel_box(EmeraldTheme.PANEL_BG, EmeraldTheme.GOLD_DIM, 1, 6, 14.0))
	slot_container.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	# ── Character Sprite ──
	var sprite_panel = PanelContainer.new()
	sprite_panel.custom_minimum_size = Vector2(80, 96)
	sprite_panel.add_theme_stylebox_override("panel",
		EmeraldTheme.panel_box(Color(0.01, 0.05, 0.04, 0.9), EmeraldTheme.GOLD_DIM, 1, 4, 2.0))
	hbox.add_child(sprite_panel)

	if save.character_data:
		# The character's own pack sprite (the old hand-drawn portraits are gone).
		sprite_panel.add_child(SpriteFigure.make_preview(SpriteFigure.preset_for(save.character_data)))
	else:
		var letter = Label.new()
		letter.text = save.character_name.left(1) if save.character_name != "" else "?"
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
		letter.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
		letter.add_theme_font_size_override("font_size", 36)
		sprite_panel.add_child(letter)

	# ── Info Column ──
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Character name
	var name_label = Label.new()
	name_label.text = save.character_name + ("  (Autosave)" if SaveManager.is_autosave(slot) else "")
	EmeraldTheme.style_heading(name_label, 24)
	info_vbox.add_child(name_label)

	# Level
	var level_label = Label.new()
	level_label.text = "Level %d" % save.character_level
	level_label.add_theme_font_size_override("font_size", 17)
	level_label.add_theme_color_override("font_color", EmeraldTheme.TITLE)
	info_vbox.add_child(level_label)

	# Location
	var location_label = Label.new()
	location_label.text = "Location: %s" % save.current_location
	location_label.add_theme_font_size_override("font_size", 15)
	location_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	info_vbox.add_child(location_label)

	# Time played
	var time_label = Label.new()
	time_label.text = "Time Played: %s" % save.get_time_played_string()
	time_label.add_theme_font_size_override("font_size", 15)
	time_label.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
	info_vbox.add_child(time_label)

	# ── Button Column ──
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)
	btn_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn_vbox)

	# Load button
	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(120, 38)
	EmeraldTheme.style_button(load_btn, 18)
	EmeraldTheme.add_ring_markers(load_btn, 28.0)
	load_btn.pressed.connect(_on_load_slot.bind(save))
	btn_vbox.add_child(load_btn)

	# Inventory button
	var inv_btn = Button.new()
	inv_btn.text = "Inventory"
	inv_btn.custom_minimum_size = Vector2(120, 34)
	EmeraldTheme.style_button(inv_btn, 16)
	inv_btn.pressed.connect(_show_inventory_popup.bind(save))
	btn_vbox.add_child(inv_btn)

	# Deck button
	var deck_btn = Button.new()
	deck_btn.text = "Deck"
	deck_btn.custom_minimum_size = Vector2(120, 34)
	EmeraldTheme.style_button(deck_btn, 16)
	deck_btn.pressed.connect(_show_deck_popup.bind(save))
	btn_vbox.add_child(deck_btn)

func _on_load_slot(save: SaveData) -> void:
	if not save.character_data:
		print("[LOAD] No character data in save!")
		return

	print("[LOAD] Loading character: %s" % save.character_name)
	# Remember where this character lives, so "save before you quit" can
	# write back to it (the autosave slot doesn't count: that asks for a slot).
	SaveManager.current_slot = save.save_slot
	_go_to_town(save)

func _go_to_town(save: SaveData) -> void:
	## A loaded character always wakes up at home, in town.
	print("[LOAD] Going to town with %s" % save.character_name)
	var town_scene = load("res://scenes/menus/town.tscn").instantiate()
	town_scene.starting_character = save.character_data
	town_scene.player2_character = save.player2_character
	town_scene.player_progression = ProgressionIO.to_live(save.progression)
	if not save.city.is_empty():
		town_scene.player_progression["city"] = save.city
	town_scene.return_world_level = save.world_level
	town_scene.quest_state = save.progression.get("quest_state", {})
	town_scene.discovered_waypoints = save.progression.get("discovered_waypoints", [])
	town_scene.opened_chests = save.progression.get("opened_chests", {})
	get_tree().root.add_child(town_scene)
	queue_free()

func _show_inventory_popup(save: SaveData) -> void:
	_clear_popup_content()
	popup_title.text = "%s's Inventory" % save.character_name

	if save.equipped_item_names.size() == 0:
		var empty = Label.new()
		empty.text = "No items equipped."
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
		popup_content.add_child(empty)
	else:
		for item_name in save.equipped_item_names:
			var lbl = Label.new()
			lbl.text = item_name
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", EmeraldTheme.GOLD)
			popup_content.add_child(lbl)

	popup_overlay.visible = true

# ── Popup: Deck ──

func _show_deck_popup(save: SaveData) -> void:
	_clear_popup_content()
	popup_title.text = "%s's Deck" % save.character_name

	if save.deck_card_ids.size() == 0:
		var empty = Label.new()
		empty.text = "No cards in deck."
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", EmeraldTheme.TEXT_DIM)
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
			lbl.add_theme_font_size_override("font_size", 16)
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
		return EmeraldTheme.TEXT  # Default light

func _clear_popup_content() -> void:
	for child in popup_content.get_children():
		child.queue_free()

func _close_popup() -> void:
	popup_overlay.visible = false

func _on_overlay_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_popup()

func _on_back_pressed() -> void:
	var load_or_new_scene = load("res://scenes/character/load_or_new.tscn").instantiate()
	get_tree().root.add_child(load_or_new_scene)
	queue_free()
