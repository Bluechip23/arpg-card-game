class_name Player2UI
extends Node

## Handles all Player 2 (co-op) UI display: hand panel, deck panel,
## card previews, and button interactions.
## Extracted from main.gd to reduce god-object complexity.

var main  # Reference to the Main scene node
var _p2_hand_visible: bool = false
var _p2_deck_visible: bool = false
var _p2_hand_container: VBoxContainer = null
var _p2_deck_container: VBoxContainer = null

# Player 2 health/mana readout (shown beside Player 1's stat bars)
var _p2_hp_bar: ProgressBar = null
var _p2_hp_label: Label = null
var _p2_mana_bar: ProgressBar = null
var _p2_mana_label: Label = null
var _p2_title_label: Label = null

func init(main_ref) -> void:
	main = main_ref

func _initialize_player2() -> void:
	# Create a separate DeckManager for P2
	main._p2_deck_manager = DeckManager.new()
	main._p2_deck_manager.name = "P2DeckManager"
	add_child(main._p2_deck_manager)
	main._p2_deck_manager.initialize_deck(main.player2_character)

	# Spawn the partner as a real character on the battle grid (own stats/figure).
	_spawn_p2_player()

	print("[P2] Player 2 initialized: %s (hand: %d cards)" % [main.player2_character.character_name, main._p2_deck_manager.hand.size()])

	_setup_p2_buttons()
	_setup_p2_hand_panel()
	_setup_p2_deck_panel()
	_setup_p2_health_bar()

func _spawn_p2_player() -> void:
	## Adds a second Player node to the battlefield, one tile beside Player 1,
	## with its own stats, inventory and procedural figure.
	var p2 := load("res://scenes/character/player.tscn").instantiate() as Player
	p2.name = "Player2"
	main.add_child(p2)
	main._p2_player = p2

	if main.grid_manager:
		p2.set_grid_manager(main.grid_manager)
	p2.enemy_spawner = main.enemy_spawner
	reposition_beside_p1()

	p2.initialize_character(main.player2_character)
	# Connect P2's deck to its own inventory/stats so its cards work independently.
	main._p2_deck_manager.connect_player_stats(p2.get_stats())
	if p2.has_method("connect_deck_to_inventory"):
		p2.connect_deck_to_inventory(main._p2_deck_manager)
	main._p2_deck_manager.connect_inventory(p2.get_inventory())

func reposition_beside_p1() -> void:
	## Snap Player 2 to a free-ish tile beside Player 1. Called after the dungeon
	## places Player 1 so the partner starts the fight next to them.
	if not main._p2_player:
		return
	var spawn_pos: Vector3 = main.player.position + Vector3(1, 0, 0)
	if main.grid_manager:
		spawn_pos = main.grid_manager.snap_to_grid(spawn_pos)
	main._p2_player.position = spawn_pos
	main._p2_player.target_position = spawn_pos

func _setup_p2_health_bar() -> void:
	## A compact HP readout for Player 2, placed just right of Player 1's stat bars
	## so both partners' health is visible at a glance.
	var ui = main.get_node("UI") as CanvasLayer
	var wrapper := VBoxContainer.new()
	wrapper.name = "P2StatBars"
	ui.add_child(wrapper)
	# Sits right of the buff/debuff bars (which occupy x 440-800 beside P1's stats).
	wrapper.set_anchors_preset(Control.PRESET_TOP_LEFT)
	wrapper.offset_left = 810.0
	wrapper.offset_top = 8.0
	wrapper.offset_right = 1020.0
	wrapper.offset_bottom = 60.0
	wrapper.add_theme_constant_override("separation", 2)

	_p2_title_label = Label.new()
	_p2_title_label.add_theme_font_size_override("font_size", 12)
	_p2_title_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.35))
	wrapper.add_child(_p2_title_label)

	var hp_pair := _make_side_bar(wrapper, Color(0.7, 0.15, 0.15))
	_p2_hp_bar = hp_pair[0]
	_p2_hp_label = hp_pair[1]

	var mana_pair := _make_side_bar(wrapper, Color(0.15, 0.3, 0.8))
	_p2_mana_bar = mana_pair[0]
	_p2_mana_label = mana_pair[1]

	var p2_stats = main._p2_player.get_stats()
	if p2_stats:
		p2_stats.health_changed.connect(_on_p2_health_changed)
		p2_stats.mana_changed.connect(_on_p2_mana_changed)
		_on_p2_health_changed(p2_stats.current_health, p2_stats.max_health)
		_on_p2_mana_changed(p2_stats.current_mana, p2_stats.max_mana)
	update_control_indicator()

func _make_side_bar(parent: VBoxContainer, fill_color: Color) -> Array:
	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(200, 20)
	parent.add_child(bar_wrap)
	var bar := ProgressBar.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)
	bar_wrap.add_child(bar)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_wrap.add_child(lbl)
	return [bar, lbl]

func _on_p2_health_changed(current: int, maximum: int) -> void:
	if not _p2_hp_bar:
		return
	_p2_hp_bar.max_value = maximum
	_p2_hp_bar.value = current
	_p2_hp_label.text = "%d/%d" % [current, maximum]

func _on_p2_mana_changed(current: float, maximum: int) -> void:
	if not _p2_mana_bar:
		return
	_p2_mana_bar.max_value = maximum
	_p2_mana_bar.value = int(current)
	_p2_mana_label.text = "%d/%d" % [int(current), maximum]

func update_control_indicator() -> void:
	## Shows which character TAB is currently controlling.
	if not _p2_title_label:
		return
	var controlling_p2: bool = main._active_index == 1
	var marker := "[CONTROL] " if controlling_p2 else ""
	_p2_title_label.text = "%sP2: %s" % [marker, main.player2_character.character_name]

func _setup_p2_buttons() -> void:
	var ui = main.get_node("UI") as CanvasLayer
	var btn_container = Control.new()
	btn_container.name = "P2ButtonContainer"
	ui.add_child(btn_container)
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_container.offset_left = -95.0
	btn_container.offset_top = -110.0
	btn_container.offset_right = -5.0
	btn_container.offset_bottom = -45.0

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	btn_container.add_child(vbox)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	var hand_btn = Button.new()
	hand_btn.name = "P2HandButton"
	hand_btn.text = "P2 Hand"
	hand_btn.custom_minimum_size = Vector2(80, 28)
	hand_btn.pressed.connect(_on_p2_hand_button_pressed)
	vbox.add_child(hand_btn)

	var deck_btn = Button.new()
	deck_btn.name = "P2DeckButton"
	deck_btn.text = "P2 Deck"
	deck_btn.custom_minimum_size = Vector2(80, 28)
	deck_btn.pressed.connect(_on_p2_deck_button_pressed)
	vbox.add_child(deck_btn)

func _setup_p2_hand_panel() -> void:
	var ui = main.get_node("UI") as CanvasLayer

	main._p2_hand_panel = PanelContainer.new()
	main._p2_hand_panel.name = "P2HandPanel"
	ui.add_child(main._p2_hand_panel)
	main._p2_hand_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	main._p2_hand_panel.offset_left = -280.0
	main._p2_hand_panel.offset_top = -250.0
	main._p2_hand_panel.offset_right = -10.0
	main._p2_hand_panel.offset_bottom = 250.0
	main._p2_hand_panel.custom_minimum_size = Vector2(270, 400)
	main._p2_hand_panel.add_theme_stylebox_override("panel", _make_p2_panel_style())

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._p2_hand_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Player 2 Hand"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	vbox.add_child(scroll)

	_p2_hand_container = VBoxContainer.new()
	_p2_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_p2_hand_container)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_p2_hand_button_pressed)
	vbox.add_child(close_btn)

	main._p2_hand_panel.visible = false

	# Card preview for P2 hand hover
	main._p2_hand_card_preview = _make_p2_card_preview("P2HandCardPreview")
	ui.add_child(main._p2_hand_card_preview)

func _setup_p2_deck_panel() -> void:
	var ui = main.get_node("UI") as CanvasLayer

	main._p2_deck_panel = PanelContainer.new()
	main._p2_deck_panel.name = "P2DeckPanel"
	ui.add_child(main._p2_deck_panel)
	main._p2_deck_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	main._p2_deck_panel.offset_left = -280.0
	main._p2_deck_panel.offset_top = -250.0
	main._p2_deck_panel.offset_right = -10.0
	main._p2_deck_panel.offset_bottom = 250.0
	main._p2_deck_panel.custom_minimum_size = Vector2(270, 400)
	main._p2_deck_panel.add_theme_stylebox_override("panel", _make_p2_panel_style())

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._p2_deck_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Player 2 Deck"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	vbox.add_child(scroll)

	_p2_deck_container = VBoxContainer.new()
	_p2_deck_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_p2_deck_container)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_p2_deck_button_pressed)
	vbox.add_child(close_btn)

	main._p2_deck_panel.visible = false

	# Card preview for P2 deck hover
	main._p2_deck_card_preview = _make_p2_card_preview("P2DeckCardPreview")
	ui.add_child(main._p2_deck_card_preview)

func _make_p2_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.08, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.35, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _make_p2_card_preview(preview_name: String) -> PanelContainer:
	var preview = PanelContainer.new()
	preview.name = preview_name
	preview.custom_minimum_size = Vector2(180, 0)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.12, 0.12, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.5, 0.4, 0.35)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	preview_style.content_margin_left = 8.0
	preview_style.content_margin_right = 8.0
	preview_style.content_margin_top = 8.0
	preview_style.content_margin_bottom = 8.0
	preview.add_theme_stylebox_override("panel", preview_style)
	preview.visible = false
	preview.z_index = 200
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return preview

func _on_p2_hand_button_pressed() -> void:
	_p2_hand_visible = !_p2_hand_visible
	main._p2_hand_panel.visible = _p2_hand_visible
	if _p2_hand_visible:
		# Hide other panels
		if _p2_deck_visible:
			_p2_deck_visible = false
			main._p2_deck_panel.visible = false
			main._p2_deck_card_preview.visible = false
		if main.deck_list_visible:
			main.deck_list_visible = false
			main.deck_list_panel.visible = false
			main.deck_list_card_preview.visible = false
		_populate_p2_hand()
	else:
		main._p2_hand_card_preview.visible = false

func _on_p2_deck_button_pressed() -> void:
	_p2_deck_visible = !_p2_deck_visible
	main._p2_deck_panel.visible = _p2_deck_visible
	if _p2_deck_visible:
		# Hide other panels
		if _p2_hand_visible:
			_p2_hand_visible = false
			main._p2_hand_panel.visible = false
			main._p2_hand_card_preview.visible = false
		if main.deck_list_visible:
			main.deck_list_visible = false
			main.deck_list_panel.visible = false
			main.deck_list_card_preview.visible = false
		_populate_p2_deck()
	else:
		main._p2_deck_card_preview.visible = false

func _populate_p2_hand() -> void:
	for child in _p2_hand_container.get_children():
		child.queue_free()

	if not main._p2_deck_manager:
		return

	for i in range(main._p2_deck_manager.hand.size()):
		var card = main._p2_deck_manager.hand[i]
		var entry = Button.new()
		entry.text = "%s (%dM / %dT)" % [card.card_name, card.mana_cost, card.tempo_cost]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_p2_hand_entry_hovered.bind(card, entry))
		entry.mouse_exited.connect(_on_p2_hand_entry_unhovered)
		_p2_hand_container.add_child(entry)

func _populate_p2_deck() -> void:
	for child in _p2_deck_container.get_children():
		child.queue_free()

	if not main._p2_deck_manager:
		return

	# Count cards across all piles
	var card_counts: Dictionary = {}
	var card_refs: Dictionary = {}
	var all_cards: Array = []
	all_cards.append_array(main._p2_deck_manager.draw_pile)
	all_cards.append_array(main._p2_deck_manager.hand)
	all_cards.append_array(main._p2_deck_manager.discard_pile)
	all_cards.append_array(main._p2_deck_manager.jail_pile)

	for card in all_cards:
		if card.card_name in card_counts:
			card_counts[card.card_name] += 1
		else:
			card_counts[card.card_name] = 1
			card_refs[card.card_name] = card

	var names = card_counts.keys()
	names.sort()

	for card_name in names:
		var count = card_counts[card_name]
		var card_ref = card_refs[card_name]
		var entry = Button.new()
		entry.text = "%s (%d)" % [card_name, count]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.flat = true
		entry.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		entry.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.4))
		entry.add_theme_font_size_override("font_size", 14)
		entry.mouse_entered.connect(_on_p2_deck_entry_hovered.bind(card_ref, entry))
		entry.mouse_exited.connect(_on_p2_deck_entry_unhovered)
		_p2_deck_container.add_child(entry)

func _build_p2_card_preview_content(card: Card, preview: PanelContainer) -> void:
	for child in preview.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	preview.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 12)
	match card.card_type:
		Card.CardType.ATTACK:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Card.CardType.DEFENSE:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
		Card.CardType.UTILITY:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		Card.CardType.POWER:
			type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
		Card.CardType.ENCHANTMENT:
			type_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
	if card.maintain_cost > 0:
		cost_lbl.text = "Cost: %dM / %dT | Maintain: %dM" % [card.mana_cost, card.tempo_cost, card.maintain_cost]
	else:
		cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	if card.is_ranged:
		var range_lbl = Label.new()
		range_lbl.text = card.get_range_display()
		range_lbl.add_theme_font_size_override("font_size", 12)
		range_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		vbox.add_child(range_lbl)
	else:
		var melee_lbl = Label.new()
		melee_lbl.text = "Melee"
		melee_lbl.add_theme_font_size_override("font_size", 12)
		melee_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		vbox.add_child(melee_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl = RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.text = card.description
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	desc_lbl.custom_minimum_size = Vector2(160, 0)
	desc_lbl.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(desc_lbl)

	main._append_keyword_tooltips(vbox, card)

func _position_p2_preview(preview: PanelContainer, panel: PanelContainer, entry: Button) -> void:
	var entry_rect = entry.get_global_rect()
	var preview_x = panel.position.x - preview.size.x - 10
	var preview_y = entry_rect.position.y
	var hand_area = main.get_node("UI/HandArea") as PanelContainer
	var max_y = hand_area.global_position.y - preview.size.y - 8.0
	preview_y = min(preview_y, max_y)
	preview_y = max(preview_y, 4.0)
	preview.global_position = Vector2(preview_x, preview_y)
	preview.visible = true

func _on_p2_hand_entry_hovered(card: Card, entry: Button) -> void:
	_build_p2_card_preview_content(card, main._p2_hand_card_preview)
	_position_p2_preview(main._p2_hand_card_preview, main._p2_hand_panel, entry)

func _on_p2_hand_entry_unhovered() -> void:
	main._p2_hand_card_preview.visible = false

func _on_p2_deck_entry_hovered(card: Card, entry: Button) -> void:
	_build_p2_card_preview_content(card, main._p2_deck_card_preview)
	_position_p2_preview(main._p2_deck_card_preview, main._p2_deck_panel, entry)

func _on_p2_deck_entry_unhovered() -> void:
	main._p2_deck_card_preview.visible = false
