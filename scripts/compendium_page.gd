class_name CompendiumPage
extends Control

## Compendium page with Cards, Items, and Enemies tabs.
## Cards sorted by type, Items sorted by type, Enemies alphabetical.
## Each tab has a search bar. Cards show the card itself on hover.
## Items and Enemies show placeholder portrait + hover modal with details.

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBox/TabContainer
@onready var back_button: Button = $Panel/MarginContainer/VBox/BackButton

# Cards tab
var _cards_search: LineEdit
var _cards_container: VBoxContainer
var _cards_scroll: ScrollContainer

# Items tab
var _items_search: LineEdit
var _items_container: VBoxContainer
var _items_scroll: ScrollContainer

# Enemies tab
var _enemies_search: LineEdit
var _enemies_container: VBoxContainer
var _enemies_scroll: ScrollContainer

# Hover popup
var _hover_popup: PanelContainer = null
var _hover_vbox: VBoxContainer = null

# Data
var _all_cards: Array = []
var _all_items: Array = []
var _all_enemies: Array = []

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_apply_styles()
	_build_data()
	_build_cards_tab()
	_build_items_tab()
	_build_enemies_tab()
	_build_hover_popup()

func _apply_styles() -> void:
	var panel = $Panel as PanelContainer
	if panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.07, 0.1, 1.0)
		style.content_margin_left = 20.0
		style.content_margin_right = 20.0
		style.content_margin_top = 20.0
		style.content_margin_bottom = 20.0
		panel.add_theme_stylebox_override("panel", style)

	if back_button:
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

func _on_back_pressed() -> void:
	var title_scene = load("res://scenes/title_menu.tscn").instantiate()
	get_tree().root.add_child(title_scene)
	queue_free()

# ============================================
# DATA BUILDING
# ============================================

func _build_data() -> void:
	_build_all_cards()
	_build_all_items()
	_build_all_enemies()

func _build_all_cards() -> void:
	_all_cards = [
		# Base cards
		Card.create_slash(),
		Card.create_block(),
		Card.create_discard(),
		Card.create_draw(),
		Card.create_empower(),
		Card.create_blink(),
		Card.create_heal(),
		Card.create_gain_mana(),
		Card.create_healing_potion(),
		Card.create_dagger_throw(),
		Card.create_potion_of_continuance(),
		# Brad's cards
		Card.create_life_swap(),
		Card.create_wear_down(),
		Card.create_taunt(),
		Card.create_life_steal(),
		Card.create_roar(),
		Card.create_poke(),
		Card.create_armor_break(),
		Card.create_charge(),
		Card.create_heroic_leap(),
		Card.create_morphine(),
		Card.create_turtle_up(),
		Card.create_parry(),
		Card.create_approach(),
		Card.create_hold_the_line(),
		# Jeremy's cards
		Card.create_trick_shot(),
		Card.create_surrounding_ice(),
		Card.create_risk_it(),
		Card.create_biscuit(),
		Card.create_loaded_die(),
		Card.create_worst_that_could_happen(),
		Card.create_oops(),
		Card.create_house_money(),
		Card.create_hope_this_works(),
		Card.create_lady_luck(),
		Card.create_try_this(),
		Card.create_if_pigs_could_fly(),
		Card.create_snowballs_chance(),
		# Ryan's cards
		Card.create_raged_circulation(),
		Card.create_poisoned_blood(),
		Card.create_elixir(),
		Card.create_shadows(),
		Card.create_preparation(),
		Card.create_exacerbate_wounds(),
		Card.create_reposition(),
		Card.create_volatile_mixture(),
		Card.create_understanding(),
		Card.create_shuriken_pouch(),
		Card.create_shuriken(),
		Card.create_premeditated(),
		# Stephen's cards
		Card.create_mark(),
		Card.create_rise(),
		Card.create_quick_shot(),
		Card.create_reload(),
		Card.create_enchanted_quiver(),
		Card.create_tighten_string(),
		Card.create_down_town(),
		Card.create_barricade(),
		Card.create_sky_fall(),
		Card.create_sky_attack(),
		Card.create_lead_arrow(),
		Card.create_last_breath(),
		Card.create_mixed_bag(),
		Card.create_quick_arrow(),
		Card.create_bottomless_quiver(),
		# Cory's cards
		Card.create_round_em_up(),
		Card.create_trip(),
		Card.create_choke(),
		Card.create_push(),
		Card.create_defensive_awareness(),
		Card.create_sweeping_disarm(),
		Card.create_consecutive_snap(),
		Card.create_swap(),
		Card.create_meditate(),
		Card.create_spider_senses(),
		Card.create_thrown_stone(),
		Card.create_lightly_dazed(),
		Card.create_gulped_potion(),
	]

func _build_all_items() -> void:
	_all_items = [
		# Character starting items
		ItemData.create_bloodbound_plate(),
		ItemData.create_scholars_signet(),
		ItemData.create_flickerstep_boots(),
		ItemData.create_grasping_gauntlets(),
		ItemData.create_adventurers_belt(),
		# Rings
		ItemData.create_ring_of_vengeance(),
		ItemData.create_ring_of_fortitude(),
		ItemData.create_ring_of_the_scholar(),
		ItemData.create_gold_ring(),
		# Gauntlets
		ItemData.create_berserker_gauntlets(),
		ItemData.create_guardian_gauntlets(),
		# Weapons
		ItemData.create_iron_sword(),
		ItemData.create_wooden_shield(),
		ItemData.create_heavy_greatsword(),
		ItemData.create_flame_dagger(),
		ItemData.create_frost_orb(),
		# Armor
		ItemData.create_iron_helm(),
		ItemData.create_leather_chest(),
		ItemData.create_leather_boots(),
		ItemData.create_iron_gauntlets(),
		# Belts
		ItemData.create_utility_belt(),
		ItemData.create_belt_of_greater_healing(),
		# Quivers
		ItemData.create_ice_quiver(),
		ItemData.create_fire_quiver(),
	]

func _build_all_enemies() -> void:
	# Build enemy data entries (not actual Enemy nodes, just data dictionaries)
	_all_enemies = [
		{
			"name": "Armored Troll",
			"type": "Elite",
			"health": 45,
			"armor": 30,
			"damage": 4,
			"xp": 8,
			"actions": [
				{"name": "Move", "tempo": 4},
				{"name": "Kick", "tempo": 3},
				{"name": "Smash", "tempo": 6},
			],
			"special": "Regenerates 2 HP every 6 global tempo.\nAt range ≤1: 60% Smash / 40% Kick.\nOtherwise: Moves toward player.",
		},
		{
			"name": "Boss",
			"type": "Boss",
			"health": 200,
			"armor": 0,
			"damage": 10,
			"xp": 25,
			"actions": [
				{"name": "Attack", "tempo": 5},
				{"name": "Move", "tempo": 8},
			],
			"special": "High health and damage.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		},
		{
			"name": "Elite",
			"type": "Elite",
			"health": 80,
			"armor": 0,
			"damage": 6,
			"xp": 10,
			"actions": [
				{"name": "Attack", "tempo": 4},
				{"name": "Move", "tempo": 6},
			],
			"special": "Stronger than minions.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		},
		{
			"name": "Minion",
			"type": "Minion",
			"health": 25,
			"armor": 0,
			"damage": 3,
			"xp": 5,
			"actions": [
				{"name": "Attack", "tempo": 3},
				{"name": "Move", "tempo": 5},
			],
			"special": "Basic enemy.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		},
		{
			"name": "Skeleton",
			"type": "Minion",
			"health": 18,
			"armor": 10,
			"damage": 5,
			"xp": 5,
			"actions": [
				{"name": "Move", "tempo": 5},
				{"name": "Attack", "tempo": 4},
			],
			"special": "Has armor that must be broken.\nAt range ≤1: Attacks.\nOtherwise: Moves toward player.",
		},
		{
			"name": "Wererat",
			"type": "Minion",
			"health": 15,
			"armor": 0,
			"damage": 3,
			"xp": 5,
			"actions": [
				{"name": "Move", "tempo": 2},
				{"name": "Bite", "tempo": 2},
				{"name": "Scurry", "tempo": 4},
			],
			"special": "Fast and evasive.\nAt range ≤1: Bites.\nAt range ≥6: Scurries (dashes away).\nOtherwise: Moves toward player.",
		},
	]

# ============================================
# CARDS TAB
# ============================================

func _build_cards_tab() -> void:
	var cards_tab = tab_container.get_child(0)  # "Cards" tab

	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_tab.add_child(vbox)

	_cards_search = LineEdit.new()
	_cards_search.placeholder_text = "Search cards by name..."
	_cards_search.clear_button_enabled = true
	_cards_search.add_theme_font_size_override("font_size", 14)
	_cards_search.text_changed.connect(_on_cards_search_changed)
	vbox.add_child(_cards_search)

	_cards_scroll = ScrollContainer.new()
	_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_cards_scroll)

	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.add_child(_cards_container)

	_populate_cards("")

func _on_cards_search_changed(new_text: String) -> void:
	_populate_cards(new_text)

func _populate_cards(filter: String) -> void:
	for child in _cards_container.get_children():
		child.queue_free()

	# Group cards by type
	var type_groups: Dictionary = {}
	var type_order = [Card.CardType.ATTACK, Card.CardType.DEFENSE, Card.CardType.UTILITY, Card.CardType.REACTION, Card.CardType.UNPLAYABLE]
	var type_names = {
		Card.CardType.ATTACK: "Attack",
		Card.CardType.DEFENSE: "Defense",
		Card.CardType.UTILITY: "Utility",
		Card.CardType.REACTION: "Reaction",
		Card.CardType.UNPLAYABLE: "Unplayable",
	}
	var type_colors = {
		Card.CardType.ATTACK: Color(1, 0.3, 0.3),
		Card.CardType.DEFENSE: Color(0.3, 0.5, 1),
		Card.CardType.UTILITY: Color(0.3, 1, 0.3),
		Card.CardType.REACTION: Color(1, 0.8, 0.2),
		Card.CardType.UNPLAYABLE: Color(0.5, 0.5, 0.5),
	}

	for card_type in type_order:
		type_groups[card_type] = []

	for card in _all_cards:
		if filter.length() > 0 and filter.to_lower() not in card.card_name.to_lower():
			continue
		if card.card_type in type_groups:
			type_groups[card.card_type].append(card)

	for card_type in type_order:
		var cards = type_groups[card_type]
		if cards.size() == 0:
			continue

		# Sort cards alphabetically within type
		cards.sort_custom(func(a, b): return a.card_name.to_lower() < b.card_name.to_lower())

		# Type header
		var header = Label.new()
		header.text = type_names[card_type] + " (%d)" % cards.size()
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", type_colors[card_type])
		_cards_container.add_child(header)

		var sep = HSeparator.new()
		_cards_container.add_child(sep)

		# Card grid (flow container)
		var grid = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_cards_container.add_child(grid)

		for card in cards:
			var card_panel = _create_card_entry(card, type_colors.get(card.card_type, Color.WHITE))
			grid.add_child(card_panel)

		# Spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		_cards_container.add_child(spacer)

func _create_card_entry(card: Card, type_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 80)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = type_color * 0.6
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", type_color)
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "%dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	# Make it respond to hover
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(_on_card_entry_hovered.bind(card, panel))
	panel.mouse_exited.connect(_on_hover_exited)

	return panel

func _on_card_entry_hovered(card: Card, entry: PanelContainer) -> void:
	_clear_hover_popup()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_hover_popup.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = card.card_type_name
	type_lbl.add_theme_font_size_override("font_size", 13)
	match card.card_type:
		Card.CardType.ATTACK:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		Card.CardType.DEFENSE:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
		Card.CardType.UTILITY:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		Card.CardType.REACTION:
			type_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		Card.CardType.UNPLAYABLE:
			type_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(type_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(cost_lbl)

	if card.damage > 0:
		var dmg_lbl = Label.new()
		dmg_lbl.text = "Damage: %d" % card.damage
		dmg_lbl.add_theme_font_size_override("font_size", 12)
		dmg_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		vbox.add_child(dmg_lbl)

	if card.block > 0:
		var blk_lbl = Label.new()
		blk_lbl.text = "Block: %d" % card.block
		blk_lbl.add_theme_font_size_override("font_size", 12)
		blk_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		vbox.add_child(blk_lbl)

	if card.heal_amount > 0:
		var heal_lbl = Label.new()
		heal_lbl.text = "Heal: %d" % card.heal_amount
		heal_lbl.add_theme_font_size_override("font_size", 12)
		heal_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		vbox.add_child(heal_lbl)

	if card.is_ranged:
		var range_lbl = Label.new()
		range_lbl.text = card.get_range_display()
		range_lbl.add_theme_font_size_override("font_size", 12)
		range_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9))
		vbox.add_child(range_lbl)

	if card.is_aoe:
		var aoe_lbl = Label.new()
		aoe_lbl.text = "AOE: %s" % card.aoe_shape.capitalize()
		aoe_lbl.add_theme_font_size_override("font_size", 12)
		aoe_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		vbox.add_child(aoe_lbl)

	if card.sticky > 0:
		var sticky_lbl = Label.new()
		sticky_lbl.text = "Sticky %d" % card.sticky
		sticky_lbl.add_theme_font_size_override("font_size", 12)
		sticky_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		vbox.add_child(sticky_lbl)

	if card.has_on_draw:
		var od_lbl = Label.new()
		od_lbl.text = "On-Draw effect"
		od_lbl.add_theme_font_size_override("font_size", 12)
		od_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		vbox.add_child(od_lbl)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var desc_lbl = RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.text = card.description
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	desc_lbl.custom_minimum_size = Vector2(230, 0)
	desc_lbl.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(desc_lbl)

	_show_hover_popup(entry)

# ============================================
# ITEMS TAB
# ============================================

func _build_items_tab() -> void:
	var items_tab = tab_container.get_child(1)  # "Items" tab

	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_tab.add_child(vbox)

	_items_search = LineEdit.new()
	_items_search.placeholder_text = "Search items by name..."
	_items_search.clear_button_enabled = true
	_items_search.add_theme_font_size_override("font_size", 14)
	_items_search.text_changed.connect(_on_items_search_changed)
	vbox.add_child(_items_search)

	_items_scroll = ScrollContainer.new()
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_items_scroll)

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.add_child(_items_container)

	_populate_items("")

func _on_items_search_changed(new_text: String) -> void:
	_populate_items(new_text)

func _populate_items(filter: String) -> void:
	for child in _items_container.get_children():
		child.queue_free()

	# Group items by type
	var type_order = [
		ItemData.ItemType.WEAPON, ItemData.ItemType.HELM, ItemData.ItemType.CHEST,
		ItemData.ItemType.BOOTS, ItemData.ItemType.RING, ItemData.ItemType.BELT,
		ItemData.ItemType.GAUNTLETS, ItemData.ItemType.QUIVER
	]
	var type_names = {
		ItemData.ItemType.WEAPON: "Weapons",
		ItemData.ItemType.HELM: "Helms",
		ItemData.ItemType.CHEST: "Chest Armor",
		ItemData.ItemType.BOOTS: "Boots",
		ItemData.ItemType.RING: "Rings",
		ItemData.ItemType.BELT: "Belts",
		ItemData.ItemType.GAUNTLETS: "Gauntlets",
		ItemData.ItemType.QUIVER: "Quivers",
	}
	var type_colors = {
		ItemData.ItemType.WEAPON: Color(0.9, 0.4, 0.3),
		ItemData.ItemType.HELM: Color(0.6, 0.6, 0.8),
		ItemData.ItemType.CHEST: Color(0.5, 0.7, 0.5),
		ItemData.ItemType.BOOTS: Color(0.6, 0.5, 0.3),
		ItemData.ItemType.RING: Color(1.0, 0.85, 0.3),
		ItemData.ItemType.BELT: Color(0.7, 0.5, 0.3),
		ItemData.ItemType.GAUNTLETS: Color(0.7, 0.55, 0.5),
		ItemData.ItemType.QUIVER: Color(0.3, 0.7, 0.8),
	}

	var type_groups: Dictionary = {}
	for item_type in type_order:
		type_groups[item_type] = []

	for item in _all_items:
		if filter.length() > 0 and filter.to_lower() not in item.item_name.to_lower():
			continue
		if item.item_type in type_groups:
			type_groups[item.item_type].append(item)

	for item_type in type_order:
		var items = type_groups[item_type]
		if items.size() == 0:
			continue

		items.sort_custom(func(a, b): return a.item_name.to_lower() < b.item_name.to_lower())

		# Type header
		var header = Label.new()
		header.text = type_names[item_type] + " (%d)" % items.size()
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", type_colors[item_type])
		_items_container.add_child(header)

		var sep = HSeparator.new()
		_items_container.add_child(sep)

		var grid = GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_items_container.add_child(grid)

		for item in items:
			var item_panel = _create_item_entry(item, type_colors.get(item.item_type, Color.WHITE))
			grid.add_child(item_panel)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		_items_container.add_child(spacer)

func _create_item_entry(item: ItemData, type_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 90)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = type_color * 0.5
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Placeholder portrait
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.color = type_color * 0.4
	hbox.add_child(portrait)

	# Portrait icon letter
	var portrait_container = Control.new()
	portrait_container.custom_minimum_size = Vector2(0, 0)
	var icon_label = Label.new()
	icon_label.text = item.item_name[0].to_upper()
	icon_label.add_theme_font_size_override("font_size", 24)
	icon_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	icon_label.position = Vector2(0, 0)
	portrait.add_child(icon_label)

	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	info_vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = item.get_type_name()
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", type_color)
	info_vbox.add_child(type_lbl)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(_on_item_entry_hovered.bind(item, panel))
	panel.mouse_exited.connect(_on_hover_exited)

	return panel

func _on_item_entry_hovered(item: ItemData, entry: PanelContainer) -> void:
	_clear_hover_popup()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_hover_popup.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = item.get_type_name()
	type_lbl.add_theme_font_size_override("font_size", 13)
	type_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	vbox.add_child(type_lbl)

	if item.weight > 0:
		_add_detail_line(vbox, "Weight: %d" % item.weight, Color(0.6, 0.6, 0.6))

	# Stat bonuses
	if item.strength_bonus != 0:
		_add_detail_line(vbox, "+%d Strength" % item.strength_bonus, Color(0.9, 0.4, 0.3))
	if item.dexterity_bonus != 0:
		_add_detail_line(vbox, "+%d Dexterity" % item.dexterity_bonus, Color(0.4, 0.8, 0.4))
	if item.intelligence_bonus != 0:
		_add_detail_line(vbox, "+%d Intelligence" % item.intelligence_bonus, Color(0.4, 0.5, 1.0))
	if item.wisdom_bonus != 0:
		_add_detail_line(vbox, "+%d Wisdom" % item.wisdom_bonus, Color(0.7, 0.4, 1.0))
	if item.determination_bonus != 0:
		_add_detail_line(vbox, "+%d Determination" % item.determination_bonus, Color(1.0, 0.6, 0.2))
	if item.agility_bonus != 0:
		_add_detail_line(vbox, "+%d Agility" % item.agility_bonus, Color(0.3, 0.9, 0.9))
	if item.health_bonus != 0:
		_add_detail_line(vbox, "+%d Health" % item.health_bonus, Color(0.9, 0.3, 0.3))
	if item.mana_bonus != 0:
		_add_detail_line(vbox, "+%d Mana" % item.mana_bonus, Color(0.3, 0.5, 1.0))
	if item.armor_bonus != 0:
		_add_detail_line(vbox, "+%d Armor" % item.armor_bonus, Color(0.7, 0.7, 0.7))
	if item.hand_size_bonus != 0:
		_add_detail_line(vbox, "+%d Hand Size" % item.hand_size_bonus, Color(0.8, 0.7, 0.4))

	if item.weapon_damage > 0:
		_add_detail_line(vbox, "Weapon Damage: %d" % item.weapon_damage, Color(1.0, 0.5, 0.3))
	if item.is_two_handed:
		_add_detail_line(vbox, "Two-Handed", Color(0.8, 0.6, 0.3))

	if item.fire_damage_percent > 0:
		_add_detail_line(vbox, "+%.0f%% Fire Damage" % item.fire_damage_percent, Color(1.0, 0.5, 0.2))
	if item.ice_damage_percent > 0:
		_add_detail_line(vbox, "+%.0f%% Ice Damage" % item.ice_damage_percent, Color(0.4, 0.7, 1.0))
	if item.ranged_damage_bonus > 0:
		_add_detail_line(vbox, "+%d Ranged Damage" % item.ranged_damage_bonus, Color(0.3, 0.8, 0.9))
	if item.healing_bonus > 0:
		_add_detail_line(vbox, "+%d Healing Bonus" % item.healing_bonus, Color(0.4, 0.9, 0.4))

	# Ring trigger
	if item.ring_trigger != ItemData.RingTrigger.NONE:
		var sep = HSeparator.new()
		vbox.add_child(sep)
		_add_detail_line(vbox, "Trigger: %s" % item.get_ring_trigger_name(), Color(1.0, 0.85, 0.3))
		_add_detail_line(vbox, "Effect: %s" % item.get_ring_effect_name(), Color(0.8, 1.0, 0.5))

	# Gauntlet skill
	if item.gauntlet_skill_type != ItemData.GauntletSkillType.NONE:
		var sep = HSeparator.new()
		vbox.add_child(sep)
		var skill_type_str = "Active" if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE else "Passive"
		_add_detail_line(vbox, "%s Skill: %s" % [skill_type_str, item.gauntlet_skill_name], Color(0.9, 0.6, 0.3))
		_add_detail_line(vbox, item.gauntlet_skill_description, Color(0.7, 0.7, 0.8))
		if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
			_add_detail_line(vbox, "CD: %d turns, Cost: %dM" % [item.gauntlet_skill_cooldown, item.gauntlet_skill_mana_cost], Color(0.6, 0.6, 0.7))

	# Card slots
	if item.card_slots > 0:
		var sep = HSeparator.new()
		vbox.add_child(sep)
		_add_detail_line(vbox, "Card Slots: %d" % item.card_slots, Color(0.7, 0.6, 1.0))
		if item.on_self_damage > 0:
			_add_detail_line(vbox, "On-Self: +%d damage" % item.on_self_damage, Color(0.6, 0.9, 0.6))
		if item.on_self_block > 0:
			_add_detail_line(vbox, "On-Self: +%d block" % item.on_self_block, Color(0.6, 0.9, 0.6))
		if item.on_self_heal > 0:
			_add_detail_line(vbox, "On-Self: +%d heal" % item.on_self_heal, Color(0.6, 0.9, 0.6))
		if item.on_self_mana_reduction > 0:
			_add_detail_line(vbox, "On-Self: -%d mana cost" % item.on_self_mana_reduction, Color(0.6, 0.9, 0.6))
		if item.on_self_apply_burn > 0:
			_add_detail_line(vbox, "On-Self: Apply %d Burn" % item.on_self_apply_burn, Color(1.0, 0.5, 0.2))
		if item.on_self_apply_cold > 0:
			_add_detail_line(vbox, "On-Self: Apply %d Cold" % item.on_self_apply_cold, Color(0.4, 0.7, 1.0))

	# Description
	if item.description.length() > 0:
		var sep = HSeparator.new()
		vbox.add_child(sep)
		var desc_lbl = Label.new()
		desc_lbl.text = item.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(230, 0)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		vbox.add_child(desc_lbl)

	_show_hover_popup(entry)

# ============================================
# ENEMIES TAB
# ============================================

func _build_enemies_tab() -> void:
	var enemies_tab = tab_container.get_child(2)  # "Enemies" tab

	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemies_tab.add_child(vbox)

	_enemies_search = LineEdit.new()
	_enemies_search.placeholder_text = "Search enemies by name..."
	_enemies_search.clear_button_enabled = true
	_enemies_search.add_theme_font_size_override("font_size", 14)
	_enemies_search.text_changed.connect(_on_enemies_search_changed)
	vbox.add_child(_enemies_search)

	_enemies_scroll = ScrollContainer.new()
	_enemies_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_enemies_scroll)

	_enemies_container = VBoxContainer.new()
	_enemies_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemies_scroll.add_child(_enemies_container)

	_populate_enemies("")

func _on_enemies_search_changed(new_text: String) -> void:
	_populate_enemies(new_text)

func _populate_enemies(filter: String) -> void:
	for child in _enemies_container.get_children():
		child.queue_free()

	# Already sorted alphabetically in _build_all_enemies
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_enemies_container.add_child(grid)

	for enemy_data in _all_enemies:
		if filter.length() > 0 and filter.to_lower() not in enemy_data["name"].to_lower():
			continue
		var enemy_panel = _create_enemy_entry(enemy_data)
		grid.add_child(enemy_panel)

func _create_enemy_entry(enemy_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 100)

	var type_color = Color(0.8, 0.3, 0.3)
	if enemy_data["type"] == "Elite":
		type_color = Color(0.8, 0.6, 0.2)
	elif enemy_data["type"] == "Boss":
		type_color = Color(0.7, 0.2, 0.5)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = type_color * 0.5
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Placeholder portrait
	var portrait = ColorRect.new()
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.color = type_color * 0.35
	hbox.add_child(portrait)

	var icon_label = Label.new()
	icon_label.text = enemy_data["name"][0].to_upper()
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	portrait.add_child(icon_label)

	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = enemy_data["name"]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	info_vbox.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = enemy_data["type"]
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", type_color)
	info_vbox.add_child(type_lbl)

	var hp_text = "HP: %d" % enemy_data["health"]
	if enemy_data["armor"] > 0:
		hp_text += "  Armor: %d" % enemy_data["armor"]
	var hp_lbl = Label.new()
	hp_lbl.text = hp_text
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(hp_lbl)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(_on_enemy_entry_hovered.bind(enemy_data, panel))
	panel.mouse_exited.connect(_on_hover_exited)

	return panel

func _on_enemy_entry_hovered(enemy_data: Dictionary, entry: PanelContainer) -> void:
	_clear_hover_popup()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_hover_popup.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = enemy_data["name"]
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	vbox.add_child(name_lbl)

	_add_detail_line(vbox, "Type: %s" % enemy_data["type"], Color(0.7, 0.7, 0.85))
	_add_detail_line(vbox, "Health: %d" % enemy_data["health"], Color(0.9, 0.3, 0.3))
	if enemy_data["armor"] > 0:
		_add_detail_line(vbox, "Armor: %d" % enemy_data["armor"], Color(0.7, 0.7, 0.7))
	_add_detail_line(vbox, "Attack: %d" % enemy_data["damage"], Color(1.0, 0.5, 0.3))
	_add_detail_line(vbox, "XP Reward: %d" % enemy_data["xp"], Color(0.5, 0.9, 0.5))

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Actions
	var actions_header = Label.new()
	actions_header.text = "Actions:"
	actions_header.add_theme_font_size_override("font_size", 14)
	actions_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	vbox.add_child(actions_header)

	for action in enemy_data["actions"]:
		_add_detail_line(vbox, "  %s (Tempo: %d)" % [action["name"], action["tempo"]], Color(0.75, 0.75, 0.8))

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Special / AI
	var special_lbl = Label.new()
	special_lbl.text = enemy_data["special"]
	special_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	special_lbl.custom_minimum_size = Vector2(230, 0)
	special_lbl.add_theme_font_size_override("font_size", 12)
	special_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(special_lbl)

	_show_hover_popup(entry)

# ============================================
# HOVER POPUP SYSTEM
# ============================================

func _build_hover_popup() -> void:
	_hover_popup = PanelContainer.new()
	_hover_popup.name = "HoverPopup"
	_hover_popup.custom_minimum_size = Vector2(260, 0)
	_hover_popup.visible = false
	_hover_popup.z_index = 200
	_hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.45, 0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_hover_popup.add_theme_stylebox_override("panel", style)

	add_child(_hover_popup)

func _clear_hover_popup() -> void:
	for child in _hover_popup.get_children():
		child.queue_free()

func _show_hover_popup(entry: Control) -> void:
	# Position popup to the right of the entry, or left if not enough space
	await get_tree().process_frame  # Wait for layout
	var entry_rect = entry.get_global_rect()
	var popup_x = entry_rect.position.x + entry_rect.size.x + 10
	var popup_y = entry_rect.position.y

	# Clamp to screen bounds
	var viewport_size = get_viewport_rect().size
	if popup_x + _hover_popup.size.x > viewport_size.x:
		popup_x = entry_rect.position.x - _hover_popup.size.x - 10
	popup_y = clamp(popup_y, 4.0, viewport_size.y - _hover_popup.size.y - 4.0)

	_hover_popup.global_position = Vector2(popup_x, popup_y)
	_hover_popup.visible = true

func _on_hover_exited() -> void:
	_hover_popup.visible = false

func _add_detail_line(parent: VBoxContainer, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
