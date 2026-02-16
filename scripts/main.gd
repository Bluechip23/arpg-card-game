extends Node2D

## Main game scene - turn-based card ARPG

@onready var deck_manager: DeckManager = $DeckManager
@onready var buff_bar: BuffBarUI = $UI/BuffBar
@onready var turn_manager: TurnManager = $TurnManager
@onready var grid_manager: GridManager = $GridManager
@onready var move_dialog: MoveConfirmDialog = $MoveConfirmDialog
@onready var character_panel: CharacterPanel = $CharacterPanel
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var test_ui: TestUI = $TestUi
@onready var gauntlet_skills_container: HBoxContainer = $UI/GauntletSkillsContainer
@onready var item_tooltip: ItemTooltip = $UI/ItemTooltip
@onready var aoe_indicator: AOEIndicator = $AOEIndicator
@onready var debuff_bar: DebuffBarUI = $UI/DebuffBar
@onready var hand_container: Control = $UI/HandArea/HandContainer
@onready var draw_label: Label = $UI/DeckInfo/DrawPileLabel
@onready var discard_label: Label = $UI/DeckInfo/DiscardPileLabel
@onready var jail_label: Label = $UI/DeckInfo/JailPileLabel
@onready var selected_label: Label = $UI/SelectedLabel
@onready var peaked_label: Label = $UI/PeakedLabel
@onready var tempo_label: Label = $UI/TempoContainer/TempoLabel
@onready var tempo_bar: ProgressBar = $UI/TempoContainer/TempoBar
@onready var overflow_buttons: HBoxContainer = $UI/OverflowButtons
@onready var player_health_label: Label = $UI/PlayerHealthLabel
@onready var player_mana_label: Label = $UI/PlayerManaLabel
@onready var player_armor_label: Label = $UI/PlayerArmorLabel
@onready var turn_label: Label = $UI/TurnLabel
@onready var player: Player = $Player
@onready var tempo_manager: TempoManager = $TempoManager
@onready var overflow_manager: OverflowManager = $OverflowManager
@onready var manifest_ui: ManifestUI = $UI/ManifestUI
@onready var overflow_ui: OverflowUI = $UI/OverflowUI
@onready var help_panel: HelpPanel = $HelpPanel
@onready var help_buttons: HelpButtons = $UI/HelpButtons

const GauntletSkillUIScene = preload("res://scenes/gauntlet_skill_ui.tscn")
const CardUIScene = preload("res://scenes/card_ui.tscn")

const CARD_KEYS = [
	KEY_A, KEY_S, KEY_D, KEY_F, KEY_G,
	KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T,
	KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B
]

var selected_card_index: int = -1
var current_character: CharacterData = null
var starting_character: CharacterData = null
var deck_list_panel: PanelContainer = null
var deck_list_container: VBoxContainer = null
var deck_list_visible: bool = false
var deck_list_card_preview: PanelContainer = null
var hand_card_preview: PanelContainer = null

func _ready() -> void:
	deck_manager.hand_updated.connect(_on_hand_updated)
	deck_manager.deck_shuffled.connect(_on_deck_shuffled)
	deck_manager.card_peaked.connect(_on_card_peaked)
	test_ui.apply_overflow_requested.connect(_on_apply_overflow)
	deck_manager.overflow_triggered.connect(_on_overflow_triggered)
	tempo_manager.tempo_threshold_reached.connect(_on_tempo_threshold_reached)
	tempo_manager.tempo_changed.connect(_on_tempo_changed)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.enemy_turn_started.connect(_on_enemy_turn)
	manifest_ui.manifest_card_clicked.connect(_on_manifest_card_clicked)
	overflow_manager.overcharge_triggered.connect(_on_overcharge_triggered)
	player.move_completed.connect(_on_player_move_completed)
	player.tile_reached.connect(_on_player_tile_reached)
	player.set_grid_manager(grid_manager)
	
	move_dialog.confirmed.connect(_on_move_confirmed)
	move_dialog.cancelled.connect(_on_move_cancelled)
	
	# Enemy spawner
	enemy_spawner.initialize(grid_manager, player)
	enemy_spawner.enemy_killed.connect(_on_enemy_killed)
	enemy_spawner.all_enemies_defeated.connect(_on_all_enemies_defeated)
	
	# Test UI
	test_ui.spawn_wave_requested.connect(_on_spawn_wave)
	test_ui.spawn_elite_requested.connect(_on_spawn_elite)
	test_ui.give_item_requested.connect(_on_give_item)
	test_ui.give_card_requested.connect(_on_give_card)
	test_ui.apply_buff_requested.connect(_on_apply_buff)
	
	help_buttons.keywords_pressed.connect(_on_keywords_pressed)
	help_buttons.walkthrough_pressed.connect(_on_walkthrough_pressed)
	help_panel.closed.connect(_on_help_closed)
	
	_setup_overflow_buttons()
	
	if starting_character:
		select_character(starting_character)
	else:
		select_character(CharacterData.create_ryan())
	
	# Style the hand area with solid background so battlefield doesn't bleed through
	_setup_hand_area_background()
	_setup_deck_list_button()
	_setup_deck_list_panel()
	_setup_hand_card_preview()

	# Spawn initial test wave
	enemy_spawner.spawn_test_arena()
	_update_enemy_count()
func _on_keywords_pressed() -> void:
	help_panel.show_panel(0)  # Keywords tab

func _on_walkthrough_pressed() -> void:
	help_panel.show_panel(1)  # Walkthrough tab

func _on_help_closed() -> void:
	pass  # Resume game if needed
func _setup_overflow_buttons() -> void:
	var modes = ["Jailed", "Enhance", "Peak", "Transferred", "Overcharge", "Manifest"]
	
	for i in range(modes.size()):
		var button = Button.new()
		button.text = modes[i]
		button.toggle_mode = true
		button.button_pressed = (i == 0)
		button.pressed.connect(_on_overflow_button_pressed.bind(i))
		overflow_buttons.add_child(button)
func _setup_hand_area_background() -> void:
	var hand_area = $UI/HandArea as PanelContainer
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	style.border_width_top = 2
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	hand_area.add_theme_stylebox_override("panel", style)
	# Do NOT clip - cards need to pop up above the hand area on hover
	hand_area.clip_contents = false

func _setup_deck_list_button() -> void:
	var hand_area = $UI/HandArea as PanelContainer
	var deck_btn = Button.new()
	deck_btn.name = "DeckListButton"
	deck_btn.text = "Deck"
	deck_btn.custom_minimum_size = Vector2(50, 30)
	deck_btn.pressed.connect(_on_deck_list_button_pressed)
	# Place button to the right of the hand area
	var ui = $UI as CanvasLayer
	var btn_container = Control.new()
	btn_container.name = "DeckButtonContainer"
	ui.add_child(btn_container)
	btn_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_container.offset_left = -95.0
	btn_container.offset_top = -40.0
	btn_container.offset_right = -5.0
	btn_container.offset_bottom = -5.0
	btn_container.add_child(deck_btn)
	deck_btn.set_anchors_preset(Control.PRESET_FULL_RECT)

func _setup_deck_list_panel() -> void:
	var ui = $UI as CanvasLayer
	# Main panel
	deck_list_panel = PanelContainer.new()
	deck_list_panel.name = "DeckListPanel"
	ui.add_child(deck_list_panel)
	deck_list_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	deck_list_panel.offset_left = -280.0
	deck_list_panel.offset_top = -250.0
	deck_list_panel.offset_right = -10.0
	deck_list_panel.offset_bottom = 250.0
	deck_list_panel.custom_minimum_size = Vector2(270, 400)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.4, 0.5)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_bottom = 10.0
	deck_list_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.layout_mode = 1
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck_list_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Deck Contents"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	vbox.add_child(scroll)

	deck_list_container = VBoxContainer.new()
	deck_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(deck_list_container)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_deck_list_button_pressed)
	vbox.add_child(close_btn)

	deck_list_panel.visible = false

	# Card preview popup (shown on hover over deck list entries)
	deck_list_card_preview = PanelContainer.new()
	deck_list_card_preview.name = "DeckListCardPreview"
	ui.add_child(deck_list_card_preview)
	deck_list_card_preview.custom_minimum_size = Vector2(180, 0)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.5, 0.5, 0.6)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	preview_style.content_margin_left = 8.0
	preview_style.content_margin_right = 8.0
	preview_style.content_margin_top = 8.0
	preview_style.content_margin_bottom = 8.0
	deck_list_card_preview.add_theme_stylebox_override("panel", preview_style)
	deck_list_card_preview.visible = false

func _on_deck_list_button_pressed() -> void:
	deck_list_visible = !deck_list_visible
	deck_list_panel.visible = deck_list_visible
	if deck_list_visible:
		_populate_deck_list()
	else:
		deck_list_card_preview.visible = false

func _populate_deck_list() -> void:
	# Clear existing entries
	for child in deck_list_container.get_children():
		child.queue_free()

	# Count cards across all piles
	var card_counts: Dictionary = {}
	var card_refs: Dictionary = {}  # Store a reference card for each name
	var all_cards: Array = []
	all_cards.append_array(deck_manager.draw_pile)
	all_cards.append_array(deck_manager.hand)
	all_cards.append_array(deck_manager.discard_pile)
	if deck_manager.has_method("get_jail_pile"):
		all_cards.append_array(deck_manager.jail_pile)
	else:
		all_cards.append_array(deck_manager.jail_pile)

	for card in all_cards:
		if card.card_name in card_counts:
			card_counts[card.card_name] += 1
		else:
			card_counts[card.card_name] = 1
			card_refs[card.card_name] = card

	# Sort by name
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
		entry.mouse_entered.connect(_on_deck_list_entry_hovered.bind(card_ref, entry))
		entry.mouse_exited.connect(_on_deck_list_entry_unhovered)
		deck_list_container.add_child(entry)

func _on_deck_list_entry_hovered(card: Card, entry: Button) -> void:
	# Clear previous preview content
	for child in deck_list_card_preview.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	deck_list_card_preview.add_child(vbox)

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
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
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

	if card.sticky > 0:
		var sticky_lbl = Label.new()
		sticky_lbl.text = "Sticky %d" % card.sticky
		sticky_lbl.add_theme_font_size_override("font_size", 12)
		sticky_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		vbox.add_child(sticky_lbl)

	# Position preview to the left of the deck list panel
	var entry_rect = entry.get_global_rect()
	deck_list_card_preview.position = Vector2(
		deck_list_panel.position.x - deck_list_card_preview.size.x - 10,
		entry_rect.position.y
	)
	deck_list_card_preview.visible = true

func _on_deck_list_entry_unhovered() -> void:
	deck_list_card_preview.visible = false

func _setup_hand_card_preview() -> void:
	var ui = $UI
	hand_card_preview = PanelContainer.new()
	hand_card_preview.name = "HandCardPreview"
	ui.add_child(hand_card_preview)
	hand_card_preview.custom_minimum_size = Vector2(200, 0)
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.15, 0.2, 0.98)
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.5, 0.5, 0.6)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	preview_style.content_margin_left = 10.0
	preview_style.content_margin_right = 10.0
	preview_style.content_margin_top = 10.0
	preview_style.content_margin_bottom = 10.0
	hand_card_preview.add_theme_stylebox_override("panel", preview_style)
	hand_card_preview.visible = false
	hand_card_preview.z_index = 200

func _on_hand_card_hovered(card: Card, card_ui: CardUI) -> void:
	# Clear previous preview content
	for child in hand_card_preview.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	hand_card_preview.add_child(vbox)

	# Card name (gold)
	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	# Card type (color-coded)
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
	vbox.add_child(type_lbl)

	# Cost
	var cost_lbl = Label.new()
	cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	# Range/Melee
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

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Description
	var desc_lbl = RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	if card.rng_outcomes_data.size() > 0 and card.has_been_rolled():
		desc_lbl.text = card.get_colored_description()
	else:
		desc_lbl.text = card.description
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	desc_lbl.custom_minimum_size = Vector2(180, 0)
	desc_lbl.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(desc_lbl)

	# Sticky indicator
	if card.sticky > 0:
		var sticky_lbl = Label.new()
		sticky_lbl.text = "Sticky %d" % card.sticky
		sticky_lbl.add_theme_font_size_override("font_size", 12)
		sticky_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		vbox.add_child(sticky_lbl)

	# Position popup above the hand area, centered on the hovered card
	var hand_area = $UI/HandArea as PanelContainer
	var card_global_rect = card_ui.get_global_rect()
	var card_center_x = card_global_rect.position.x + card_global_rect.size.x / 2.0

	# Wait a frame for the preview to calculate its size, then position
	await get_tree().process_frame
	var preview_width = hand_card_preview.size.x
	var popup_x = card_center_x - preview_width / 2.0

	# Clamp to screen bounds
	var screen_width = get_viewport().get_visible_rect().size.x
	popup_x = clamp(popup_x, 4.0, screen_width - preview_width - 4.0)

	# Place above the hand area
	var popup_y = hand_area.global_position.y - hand_card_preview.size.y - 8.0
	hand_card_preview.global_position = Vector2(popup_x, popup_y)
	hand_card_preview.visible = true

func _on_hand_card_unhovered() -> void:
	hand_card_preview.visible = false

func _setup_gauntlet_skills_ui() -> void:
	# Clear existing
	for child in gauntlet_skills_container.get_children():
		child.queue_free()
	
	var inventory = player.get_inventory()
	if not inventory:
		return
	
	var skills = inventory.get_available_gauntlet_skills()
	for gauntlet in skills:
		if gauntlet.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
			var skill_ui = GauntletSkillUIScene.instantiate() as GauntletSkillUI
			gauntlet_skills_container.add_child(skill_ui)
			skill_ui.setup(gauntlet)
			skill_ui.skill_activated.connect(_on_gauntlet_skill_activated)

func _update_gauntlet_skills_ui() -> void:
	for child in gauntlet_skills_container.get_children():
		if child is GauntletSkillUI:
			child.update_display()

func _on_gauntlet_skill_activated(gauntlet: ItemData) -> void:
	var inventory = player.get_inventory()
	
	# For targeted skills, we need to select a target
	# For now, use closest enemy or require click
	var enemies = enemy_spawner.get_living_enemies()
	var target = enemies[0] if enemies.size() > 0 else null
	
	if inventory.use_gauntlet_skill(gauntlet, target):
		tempo_manager.add_tempo(1)  # Skills cost 1 tempo
		_update_gauntlet_skills_ui()

func _on_gauntlet_skill_ready(_gauntlet: ItemData) -> void:
	_update_gauntlet_skills_ui()

func select_character(character: CharacterData) -> void:
	current_character = character
	
	player.initialize_character(character)
	deck_manager.connect_player_stats(player.get_stats())

	debuff_bar.connect_manager(player.get_debuff_manager())
	deck_manager.connect_inventory(player.get_inventory())
	player.connect_deck_to_inventory(deck_manager)
	tempo_manager.initialize(player.get_stats())
	update_tempo_display()
	turn_manager.initialize(player.get_stats(), deck_manager)
	overflow_manager.initialize(player.get_stats())
	deck_manager.connect_overflow_manager(overflow_manager)
	buff_bar.connect_manager(player.get_buff_manager())
	manifest_ui.connect_overflow_manager(overflow_manager)
	overflow_ui.connect_overflow_manager(overflow_manager)
	player.get_stats().health_changed.connect(_on_player_health_changed)
	player.get_stats().mana_changed.connect(_on_player_mana_changed)
	player.get_stats().armor_changed.connect(_on_player_armor_changed)
	player.get_stats().dexterity_proc.connect(_on_dexterity_proc)
	
	character_panel.connect_stats(player.get_stats(), player.get_inventory())
	
	deck_manager.initialize_deck(character)
	_setup_gauntlet_skills_ui()
	# Connect gauntlet cooldown signal so UI updates when skills come off cooldown
	var inventory = player.get_inventory()
	if inventory and not inventory.gauntlet_skill_ready.is_connected(_on_gauntlet_skill_ready):
		inventory.gauntlet_skill_ready.connect(_on_gauntlet_skill_ready)
	_on_hand_updated()
	update_deck_info()
	update_selected_display()
	update_peaked_display()
	update_turn_display()
	_on_player_health_changed(player.get_stats().current_health, player.get_stats().max_health)
	_on_player_mana_changed(player.get_stats().current_mana, player.get_stats().max_mana)
	_on_player_armor_changed(player.get_stats().current_armor)
	
	print("[MAIN] Selected character: %s" % character.character_name)

func trigger_turn() -> void:
	deck_manager.process_turn()
	turn_manager.take_turn()
	update_turn_display()
	_update_enemy_count()

func trigger_multiple_turns(count: int) -> void:
	for i in range(count):
		trigger_turn()

func _on_player_tile_reached() -> void:
	# Tempo accumulates per tile in real time
	tempo_manager.add_movement_tempo()

func _on_player_move_completed() -> void:
	pass

func _on_move_confirmed(target_pos: Vector2, spaces: int) -> void:
	var debuff_mgr = player.get_debuff_manager()
	
	# Check Tethered range
	if debuff_mgr and debuff_mgr.is_tethered():
		if not debuff_mgr.is_within_tether_range(target_pos, grid_manager.grid_size):
			print("[MAIN] Cannot move - Tethered! Out of range.")
			return
	
	player.move_to_grid(target_pos, spaces)

func _on_move_cancelled() -> void:
	print("[INPUT] Movement cancelled")

func _on_enemy_turn() -> void:
	enemy_spawner.process_enemy_turns()

func _on_enemy_killed(enemy: Enemy) -> void:
	print("[MAIN] Enemy killed: %s" % enemy.enemy_name)
	_update_enemy_count()

func _on_all_enemies_defeated() -> void:
	print("[MAIN] Wave complete! Press 'Spawn Wave' for more enemies.")

func _update_enemy_count() -> void:
	test_ui.update_enemy_count(enemy_spawner.get_enemy_count())

func _on_turn_ended(turn_number: int) -> void:
	update_deck_info()

func _on_player_health_changed(current: int, max_hp: int) -> void:
	if player_health_label:
		player_health_label.text = "HP: %d / %d" % [current, max_hp]

func _on_player_mana_changed(current: float, max_mana: int) -> void:
	if player_mana_label:
		player_mana_label.text = "Mana: %d / %d" % [int(current), max_mana]

func _on_player_armor_changed(current: int) -> void:
	if player_armor_label:
		player_armor_label.text = "Armor: %d" % current

func _on_dexterity_proc() -> void:
	print("[MAIN] Dexterity proc! Next attack is free + 2 mana discount!")
	deck_manager.apply_dex_proc_bonus()

func update_turn_display() -> void:
	if turn_label:
		turn_label.text = "Turn: %d | Tempo: %d/%d | Draw: %.1f | Atk: %d" % [
			turn_manager.current_turn,
			tempo_manager.get_tempo(),
			tempo_manager.get_threshold(),
			turn_manager.get_turns_until_draw(),
			player.get_stats().get_attacks_until_proc()
		]

func _on_overflow_button_pressed(mode_index: int) -> void:
	for i in range(overflow_buttons.get_child_count()):
		var button = overflow_buttons.get_child(i) as Button
		button.button_pressed = (i == mode_index)
	
	deck_manager.set_overflow_mode(mode_index as DeckManager.OverflowMode)
	update_peaked_display()

func _on_hand_updated() -> void:
	if hand_card_preview:
		hand_card_preview.visible = false
	for child in hand_container.get_children():
		child.queue_free()

	var debuff_mgr = player.get_debuff_manager()

	# Assign Hexed/Locked cards if needed
	deck_manager.assign_hexed_locked_cards(debuff_mgr)

	# Roll RNG for cards that haven't been rolled yet
	var enemies = enemy_spawner.get_living_enemies()
	var chance_boost = player.get_stats().chance_boost
	for card in deck_manager.hand:
		if card.has_chance_effect() and not card.has_been_rolled():
			card.roll_rng(enemies, chance_boost)
			card.rng_roll_turn = turn_manager.current_turn

	var hand_size = deck_manager.hand.size()
	if hand_size == 0:
		if selected_card_index >= 0:
			selected_card_index = -1
		update_deck_info()
		update_selected_display()
		update_card_highlights()
		return

	var card_width: float = 120.0
	var card_height: float = 160.0
	var container_width: float = hand_container.size.x
	if container_width <= 0:
		container_width = 1080.0  # fallback

	# Calculate spacing: fit all cards proportionally within the container
	# If cards would fit without overlap, space them evenly
	# If not, overlap them so they all fit
	var total_cards_width = card_width * hand_size
	var spacing: float
	if total_cards_width <= container_width:
		# Cards fit - distribute evenly across the space
		if hand_size == 1:
			spacing = 0.0
		else:
			spacing = (container_width - card_width) / (hand_size - 1)
		# Cap spacing so cards don't spread too far apart
		spacing = min(spacing, card_width + 8.0)
	else:
		# Cards overlap - shrink spacing to fit
		spacing = (container_width - card_width) / max(hand_size - 1, 1)

	# Center the hand within the container
	var total_hand_width = card_width + spacing * max(hand_size - 1, 0)
	var start_x = (container_width - total_hand_width) / 2.0
	var card_y = (hand_container.size.y - card_height) / 2.0
	if card_y < 0:
		card_y = 0.0

	for i in range(hand_size):
		var card_ui = CardUIScene.instantiate()
		hand_container.add_child(card_ui)
		card_ui.setup(deck_manager.hand[i], i, debuff_mgr)
		card_ui.position = Vector2(start_x + i * spacing, card_y)
		card_ui.z_index = i
		card_ui.store_base_position()
		card_ui.card_hovered.connect(_on_hand_card_hovered)
		card_ui.card_unhovered.connect(_on_hand_card_unhovered)

	if selected_card_index >= deck_manager.hand.size():
		selected_card_index = -1

	update_deck_info()
	update_selected_display()
	update_card_highlights()

func _on_deck_shuffled() -> void:
	update_deck_info()

func _on_card_peaked(card: Card) -> void:
	update_peaked_display()

func _on_overflow_triggered(mode: String, card: Card) -> void:
	update_deck_info()
	update_peaked_display()

func _on_apply_debuff(debuff_name: String) -> void:
	var debuff_mgr = player.get_debuff_manager()
	var debuff: Debuff = null
	
	match debuff_name:
		# Original debuffs
		"Bleed (3)": debuff = Debuff.create(Debuff.DebuffType.BLEED, 3, 3)
		"Stun": debuff = Debuff.create(Debuff.DebuffType.STUN, 0, 1)
		"Disarm": debuff = Debuff.create(Debuff.DebuffType.DISARM, 0, 3)
		"Silence": debuff = Debuff.create(Debuff.DebuffType.SILENCE, 0, 3)
		"Burn (2)": debuff = Debuff.create(Debuff.DebuffType.BURN, 2, 3)
		"Poison (2)": debuff = Debuff.create(Debuff.DebuffType.POISON, 2, 3)
		"Inebriate": debuff = Debuff.create(Debuff.DebuffType.INEBRIATE, 0, 3)
		"Cursed (2)": debuff = Debuff.create(Debuff.DebuffType.CURSED, 2, 3)
		"Frozen": debuff = Debuff.create(Debuff.DebuffType.FROZEN, 0, 2)
		"Cuffed": debuff = Debuff.create(Debuff.DebuffType.CUFFED, 0, 3)
		"Shocked (3)": debuff = Debuff.create(Debuff.DebuffType.SHOCKED, 3, 3)
		"Slowed (2)": debuff = Debuff.create(Debuff.DebuffType.SLOWED, 2, 3)
		"Staggered (1)": debuff = Debuff.create(Debuff.DebuffType.STAGGERED, 1, 3)
		"Drain (2)": debuff = Debuff.create(Debuff.DebuffType.DRAIN, 2, 3)
		"Weighted (1)": debuff = Debuff.create(Debuff.DebuffType.WEIGHTED, 1, 3)
		"Hexed (2)": debuff = Debuff.create(Debuff.DebuffType.HEXED, 2, 3)
		"Locked": debuff = Debuff.create(Debuff.DebuffType.LOCKED, 0, 2)
		"Rooted": debuff = Debuff.create(Debuff.DebuffType.ROOTED, 0, 2)
		"Tethered (3)": 
			debuff = Debuff.create(Debuff.DebuffType.TETHERED, 3, 4)
			debuff_mgr.set_tether_origin(player.position)
		"Magnetized (1)": debuff = Debuff.create(Debuff.DebuffType.MAGNETIZED, 1, 3)
		"Linked (25)": debuff = Debuff.create(Debuff.DebuffType.LINKED, 25, 3)
		"Clumsy (30)": debuff = Debuff.create(Debuff.DebuffType.CLUMSY, 30, 3)
		"Vulnerable (25)": debuff = Debuff.create(Debuff.DebuffType.VULNERABLE, 25, 3)
		"Exposed (50)": debuff = Debuff.create(Debuff.DebuffType.EXPOSED, 50, 3)
		"Brittle (2)": debuff = Debuff.create(Debuff.DebuffType.BRITTLE, 2, 3)
	if debuff and debuff_mgr:
		debuff_mgr.apply_debuff(debuff)
		_on_hand_updated()  # Refresh cards for Hexed/Locked
		print("[MAIN] Applied debuff: %s" % debuff_name)		

func _on_apply_buff(buff_name: String) -> void:
	var buff_mgr = player.get_buff_manager()
	var buff: Buff = null
	
	match buff_name:
		"Thorns (3 dmg)":
			buff = Buff.create_thorns(3, 3, "Test")
		"Focused":
			buff = Buff.create_focused(3, "Test")
		"Regen (2)":
			buff = Buff.create_regen(2, 3, "Test")
		"Blessed (1)":
			buff = Buff.create_blessed(1, 3, "Test")
		"Fortify":
			buff = Buff.create_fortify(3, "Test")
		"Enlightened (25%, 3)":
			buff = Buff.create_enlightened(25, 3, "Test")
		"Strengthen (+3, 3)":
			buff = Buff.create_strengthen(3, 3, "Test")
		"Bolster (+2, 3)":
			buff = Buff.create_bolster(2, 3, "Test")
		"Haste (+1)":
			buff = Buff.create_haste(1, 3, "Test")
		"Cleanse (1)":
			buff = Buff.create_cleanse(1, "Test")
		"Smith (2)":
			buff = Buff.create_smith(2, 3, "Test")
		"Steady":
			buff = Buff.create_steady("Test")
		"Brace (5)":
			buff = Buff.create_brace(5, "Test")
		"Resilient (25%, 3)":
			buff = Buff.create_resilient(25, 3, "Test")
	
	if buff and buff_mgr:
		buff_mgr.apply_buff(buff)
		print("[MAIN] Applied buff: %s" % buff_name)
	

func _on_tempo_threshold_reached(times: int) -> void:
	print("[MAIN] === TEMPO THRESHOLD × %d ===" % times)

	# Pause player movement while enemies act
	var was_moving = player.is_moving
	if was_moving:
		player.pause_movement()

	for i in range(times):
		var debuff_mgr = player.get_debuff_manager()
		var buff_mgr = player.get_buff_manager()

		# Process buff effects at turn start
		if buff_mgr:
			var buff_result = buff_mgr.process_turn_start()

			# Extra draws from Blessed
			if buff_result["extra_draws"] > 0:
				for d in range(buff_result["extra_draws"]):
					deck_manager.attempt_draw()

		# Process debuffs
		if debuff_mgr:
			debuff_mgr.process_turn_start()

		deck_manager.process_turn()

		# Pass both managers to turn processing
		var stats = player.get_stats()
		stats.process_turn(debuff_mgr, buff_mgr)

		turn_manager.take_turn()
		enemy_spawner.process_enemy_turns()

		# Process end of turn
		if debuff_mgr:
			debuff_mgr.process_turn_end()
		if buff_mgr:
			buff_mgr.process_turn_end()

	_update_gauntlet_skills_ui()
	update_turn_display()
	_update_enemy_count()
	_reroll_card_rng()
	_on_hand_updated()

	# Resume player movement after enemies finish
	if was_moving:
		player.resume_movement()
func _apply_magnetize_pull(tiles: int) -> void:
	var enemies = enemy_spawner.get_living_enemies()
	if enemies.size() == 0:
		return
	
	# Find nearest enemy
	var nearest_enemy = enemies[0]
	var nearest_dist = player.position.distance_to(nearest_enemy.position)
	
	for enemy in enemies:
		var dist = player.position.distance_to(enemy.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy = enemy
	
	# Calculate pull direction
	var direction = (nearest_enemy.position - player.position).normalized()
	var pull_distance = tiles * grid_manager.grid_size
	var new_pos = player.position + direction * pull_distance
	new_pos = grid_manager.snap_to_grid(new_pos)
	
	# Move player
	player.position = new_pos
	player.target_position = new_pos
	print("[MAIN] Magnetized pulled player %d tiles toward %s" % [tiles, nearest_enemy.enemy_name])
func _reroll_card_rng() -> void:
	var enemies = enemy_spawner.get_living_enemies()
	var chance_boost = player.get_stats().chance_boost

	for card in deck_manager.hand:
		if card.has_chance_effect():
			if card.should_reroll_rng(turn_manager.current_turn):
				card.roll_rng(enemies, chance_boost)
				card.rng_roll_turn = turn_manager.current_turn

	# Update chance displays on existing card UIs
	for child in hand_container.get_children():
		if child is CardUI:
			child.update_chance_display()
	
func _on_tempo_changed(current: int, threshold: int) -> void:
	update_turn_display()
	update_tempo_display()

func update_tempo_display() -> void:
	if tempo_label:
		tempo_label.text = "Tempo: %d/%d" % [tempo_manager.get_tempo(), tempo_manager.get_threshold()]
	if tempo_bar:
		tempo_bar.max_value = tempo_manager.get_threshold()
		tempo_bar.value = tempo_manager.get_tempo()
func update_deck_info() -> void:
	if draw_label:
		draw_label.text = "Draw: %d" % deck_manager.get_draw_pile_size()
	if discard_label:
		discard_label.text = "Discard: %d" % deck_manager.get_discard_pile_size()
	if jail_label:
		jail_label.text = "Jail: %d" % deck_manager.get_jail_pile_size()

func update_selected_display() -> void:
	if selected_label:
		if selected_card_index >= 0 and selected_card_index < deck_manager.hand.size():
			var card = deck_manager.hand[selected_card_index]
			selected_label.text = "Selected: %s [%d mana] (Click to play)" % [card.card_name, card.mana_cost]
		else:
			selected_label.text = "Press A/S/D/F/G to select a card"

func update_peaked_display() -> void:
	if peaked_label:
		var peaked = deck_manager.get_peaked_card()
		if peaked and deck_manager.current_overflow_mode == DeckManager.OverflowMode.PEAK:
			peaked_label.text = "NEXT CARD: %s" % peaked.card_name
			peaked_label.visible = true
		else:
			peaked_label.visible = false

func update_card_highlights() -> void:
	var cards = hand_container.get_children()
	for i in range(cards.size()):
		var card_ui = cards[i] as CardUI
		if card_ui:
			card_ui.set_selected(i == selected_card_index)

func select_card(index: int) -> void:
	if index < 0 or index >= deck_manager.hand.size():
		selected_card_index = -1
		if aoe_indicator:
			aoe_indicator.hide_indicator()
		update_selected_display()
		return
	
	selected_card_index = index
	update_selected_display()
	
	# Show AOE indicator if applicable
	var card = deck_manager.hand[selected_card_index]
	if card.is_aoe and aoe_indicator:
		aoe_indicator.update_indicator(card.aoe_shape, card.aoe_range)
		aoe_indicator.position = player.position
		aoe_indicator.show_indicator()
		
		# Update enemy RNG indicators
		var enemies = enemy_spawner.get_living_enemies()
		aoe_indicator.update_enemy_rng_indicators(enemies, card)
	elif aoe_indicator:
		aoe_indicator.hide_indicator()

func play_selected_card(target) -> void:
	if selected_card_index < 0:
		print("[INPUT] No card selected!")
		return

	var card = deck_manager.hand[selected_card_index]
	var tempo_cost = card.tempo_cost

	var debuff_mgr = player.get_debuff_manager()
	var buff_mgr = player.get_buff_manager()

	if debuff_mgr:
		tempo_cost += debuff_mgr.get_tempo_increase()

	var result = deck_manager.play_card(selected_card_index, target, player)

	if result["played"]:
		selected_card_index = -1

		# Apply world effects (knockback, movement, AOE) that need game-level access
		_apply_card_world_effects(card, target)

		if not result["free_turn"]:
			if buff_mgr and buff_mgr.consume_steady():
				print("[MAIN] Steady! No tempo added.")
			else:
				tempo_manager.add_card_tempo(tempo_cost)
		else:
			print("[MAIN] Free attack! No tempo added.")

		_on_hand_updated()
		update_deck_info()

func _is_target_in_card_range(card: Card, target) -> bool:
	if not target or not target is Node2D:
		return true
	var distance_px = player.position.distance_to(target.position)
	var distance_tiles = distance_px / grid_manager.grid_size
	if card.is_ranged:
		var max_range = 5 + card.range_modifier
		return distance_tiles <= max_range + 0.5  # Small tolerance
	else:
		# Melee: must be adjacent (within ~1.5 tiles)
		return distance_tiles <= 1.5

func _apply_card_world_effects(card: Card, target) -> void:
	var mouse_pos = get_global_mouse_position()

	match card.card_id:
		"roar":
			# Knock all nearby enemies back 1 space
			var nearby = enemy_spawner.get_enemies_in_radius(player.position, card.aoe_range)
			for enemy in nearby:
				enemy.knockback(player.position, 1)
			print("[MAIN] Roar knocked back %d enemies" % nearby.size())

		"taunt":
			# Force nearby enemies to target this player for 2 turns
			var nearby = enemy_spawner.get_enemies_in_radius(player.position, card.aoe_range)
			for enemy in nearby:
				enemy.apply_taunt(player, 2)
			print("[MAIN] Taunted %d enemies for 2 turns" % nearby.size())

		"charge":
			# Move player toward targeted enemy, damage all enemies in path, knock them back
			var charge_dest = target.position if target else grid_manager.snap_to_grid(mouse_pos)
			var snapped_target = grid_manager.snap_to_grid(charge_dest)
			var start_pos = player.position
			# Teleport player to charge destination (no tempo for this movement)
			player.position = snapped_target
			player.target_position = snapped_target
			# Find and damage all enemies along the charge path
			var enemies_hit = enemy_spawner.get_enemies_in_line(start_pos, snapped_target, 50.0)
			for enemy in enemies_hit:
				enemy.take_damage(card.last_damage_dealt)
				enemy.knockback(snapped_target, 1)
			print("[MAIN] Charge: moved to %s, hit %d enemies for %d damage" % [snapped_target, enemies_hit.size(), card.last_damage_dealt])

		"heroic_leap":
			# Jump to click position based on STR, deal AOE damage on landing
			var stats = player.get_stats()
			var leap_distance = 3
			if stats:
				leap_distance = max(2, stats.strength / 3)
			var direction = (mouse_pos - player.position).normalized()
			var leap_target = player.position + direction * (leap_distance * grid_manager.grid_size)
			leap_target = grid_manager.snap_to_grid(leap_target)
			# Teleport player to landing spot (no tempo for this movement)
			player.position = leap_target
			player.target_position = leap_target
			# Deal AOE damage to enemies at landing
			var landing_enemies = enemy_spawner.get_enemies_in_radius(leap_target, 100.0)
			for enemy in landing_enemies:
				enemy.take_damage(card.last_damage_dealt)
			print("[MAIN] Heroic Leap: jumped %d tiles to %s, hit %d enemies for %d damage" % [leap_distance, leap_target, landing_enemies.size(), card.last_damage_dealt])
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Character panel toggle
		if event.keycode == KEY_I:
			character_panel.toggle_panel()
			return
		
		# Card selection
		for i in range(CARD_KEYS.size()):
			if event.keycode == CARD_KEYS[i]:
				select_card(i)
				return
		
		if event.keycode == KEY_ESCAPE:
			selected_card_index = -1
			update_selected_display()
			update_card_highlights()
			move_dialog.hide_dialog()
			character_panel.hide_panel()
	
	# Left click - play card or use gauntlet skill
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_card_index >= 0:
			var card = deck_manager.hand[selected_card_index]
			var mouse_pos = get_global_mouse_position()

			match card.target_type:
				"self":
					play_selected_card(player)
				"ally":
					# TODO: ally selection - for now target self
					play_selected_card(player)
				"point":
					play_selected_card(player)
				"all_nearby":
					play_selected_card(player)
				"enemy":
					var enemy = enemy_spawner.get_enemy_at_position(mouse_pos)
					if enemy:
						if _is_target_in_card_range(card, enemy):
							play_selected_card(enemy)
						else:
							var range_type = "ranged" if card.is_ranged else "melee"
							print("[INPUT] Enemy is out of %s range!" % range_type)
					else:
						print("[INPUT] No enemy at that position!")
				_:
					play_selected_card(null)
	
	# Right click - movement
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not player.is_moving:
			var mouse_pos = get_global_mouse_position()
			var spaces = grid_manager.get_distance_in_cells(player.position, mouse_pos)
			
			if spaces == 0:
				print("[INPUT] Already at that location")
			elif spaces == 1:
				player.move_to_grid(mouse_pos, 1)
			else:
				move_dialog.show_dialog(mouse_pos, spaces)

# ============================================
# TEST UI HANDLERS
# ============================================

func _on_spawn_wave() -> void:
	enemy_spawner.spawn_test_arena()
	_update_enemy_count()
	print("[MAIN] Spawned new wave!")

func _on_spawn_elite() -> void:
	var pos = Vector2(randf_range(600, 1000), randf_range(150, 500))
	enemy_spawner.spawn_enemy(Enemy.EnemyType.ELITE, pos)
	_update_enemy_count()
	print("[MAIN] Spawned elite enemy!")

func _on_give_item(item_name: String) -> void:
	var item: ItemData = null
	
	match item_name:
		"Iron Helm": item = ItemData.create_iron_helm()
		"Leather Chest": item = ItemData.create_leather_chest()
		"Iron Sword": item = ItemData.create_iron_sword()
		"Wooden Shield": item = ItemData.create_wooden_shield()
		"Gold Ring": item = ItemData.create_gold_ring()
		"Flame Dagger": item = ItemData.create_flame_dagger()
		"Frost Orb": item = ItemData.create_frost_orb()
		"Ring of Vengeance": item = ItemData.create_ring_of_vengeance()
		"Ring of Fortitude": item = ItemData.create_ring_of_fortitude()
		"Berserker Gauntlets": item = ItemData.create_berserker_gauntlets()
		"Guardian Gauntlets": item = ItemData.create_guardian_gauntlets()
	
	if item:
		var inventory = player.get_inventory()
		# Find first empty slot
		var slot_array = inventory._get_slot_array(item.item_type)
		var max_slots = inventory._get_max_slots(item.item_type)
		
		for i in range(max_slots):
			if slot_array[i] == null:
				inventory.equip_item(item, i)
				print("[MAIN] Gave item: %s" % item_name)
				return
		
		print("[MAIN] No empty slot for %s!" % item_name)

func _on_give_card(card_name: String) -> void:
	var card: Card = null
	
	match card_name:
		"Slash": card = Card.create_slash()
		"Block": card = Card.create_block()
		"Blink": card = Card.create_blink()
		"Heal": card = Card.create_heal()
		"Draw": card = Card.create_draw()
		"Discard": card = Card.create_discard()
		"Empower": card = Card.create_empower()
		"Healing Potion": card = Card.create_healing_potion()
		"Dagger Throw": card = Card.create_dagger_throw()
		"Gain Mana": card = Card.create_gain_mana()
	
	if card:
		deck_manager.hand.append(card)
		deck_manager.hand_updated.emit()
		print("[MAIN] Gave card: %s" % card_name)
func _on_manifest_card_clicked(index: int) -> void:
	var result = overflow_manager.activate_manifest(index)
	
	if result.is_empty():
		return
	
	# Execute manifest effect
	match result["manifest_id"]:
		"summon_skeleton":
			_spawn_summoned_creature("skeleton", result["manifest_value"])
		"summon_spirit":
			_spawn_summoned_creature("spirit", result["manifest_value"])
		"summon_golem":
			_spawn_summoned_creature("golem", result["manifest_value"])
		"use_mushroom":
			player.get_stats().heal(result["manifest_value"])
			print("[MAIN] Used Mushroom: Healed %d" % result["manifest_value"])
		"deal_damage":
			var enemies = enemy_spawner.get_living_enemies()
			if enemies.size() > 0:
				enemies[0].take_damage(result["manifest_value"])
		_:
			print("[MAIN] Unknown manifest effect: %s" % result["manifest_id"])
	
	# Add tempo cost
	if result["tempo_cost"] > 0:
		tempo_manager.add_tempo(result["tempo_cost"])
	
	manifest_ui.refresh()

func _on_overcharge_triggered(effect_id: String, value: int) -> void:
	match effect_id:
		"damage_all":
			var enemies = enemy_spawner.get_living_enemies()
			for enemy in enemies:
				enemy.take_damage(value)
			print("[MAIN] Overcharge: Dealt %d damage to %d enemies" % [value, enemies.size()])

func _spawn_summoned_creature(creature_type: String, count: int) -> void:
	for i in range(count):
		var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var spawn_pos = player.position + offset
		
		if grid_manager:
			spawn_pos = grid_manager.snap_to_grid(spawn_pos)
		
		match creature_type:
			"skeleton":
				_create_ally_marker("Skeleton", spawn_pos, Color(0.9, 0.9, 0.8))
			"spirit":
				_create_ally_marker("Spirit", spawn_pos, Color(0.6, 0.8, 1.0))
			"golem":
				_create_ally_marker("Golem", spawn_pos, Color(0.6, 0.5, 0.4))
		
		print("[MAIN] Summoned %s at %s" % [creature_type, spawn_pos])

func _create_ally_marker(ally_name: String, pos: Vector2, color: Color) -> void:
	var marker = ColorRect.new()
	marker.size = Vector2(40, 40)
	marker.position = pos - Vector2(20, 20)
	marker.color = color
	marker.modulate.a = 0.8
	add_child(marker)
	
	var label = Label.new()
	label.text = ally_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-10, -20)
	marker.add_child(label)
func _on_apply_overflow(overflow_name: String) -> void:
	var effect: OverflowEffect = null
	
	match overflow_name:
		"Jailed (3)":
			effect = OverflowEffect.create_jailed(3, "Test")
		"Manifest: Skeleton (3)":
			effect = OverflowEffect.create_manifest_skeleton(3, "Test")
		"Manifest: Mushroom (∞)":
			effect = OverflowEffect.create_manifest_mushroom(-1, "Test")
		"Manifest: Spirit (3)":
			effect = OverflowEffect.create_manifest_spirit(3, "Test")
		"Enhance +3 (3)":
			effect = OverflowEffect.create_enhance(3, 3, "Test")
		"Transferred (3)":
			effect = OverflowEffect.create_transferred(3, "Test")
		"Peak (∞)":
			effect = OverflowEffect.create_peak(-1, "Test")
		"Overcharge: +2 Health (∞)":
			effect = OverflowEffect.create_overcharge_health(2, -1, "Test")
		"Overcharge: +2 Mana (∞)":
			effect = OverflowEffect.create_overcharge_mana(2, -1, "Test")
		"Overcharge: +2 Armor (3)":
			effect = OverflowEffect.create_overcharge_armor(2, 3, "Test")
		"Overcharge: 3 Dmg All (3)":
			effect = OverflowEffect.create_overcharge_damage(3, 3, "Test")
	
	if effect:
		overflow_manager.add_overflow_effect(effect)
		print("[MAIN] Applied overflow: %s" % overflow_name)
