class_name ChestLootUI
extends Node

## Handles chest interaction, loot display modals, and item/card pickup.
## Extracted from main.gd to reduce god-object complexity.

var main  # Reference to the Main scene node

func init(main_ref) -> void:
	main = main_ref

func _try_interact_chest() -> void:
	if not main.dungeon_manager:
		return
	if main._chest_modal_open:
		return

	var player_grid = main.grid_manager.world_to_grid(main.player.position)
	var chest_idx = main.dungeon_manager.get_nearby_chest(player_grid)
	if chest_idx < 0:
		return

	var contents = main.dungeon_manager.open_chest(chest_idx)
	if contents.is_empty():
		return

	# Grant gold immediately
	var gold_amount = contents.get("gold", 0)
	if gold_amount > 0:
		main.player.get_stats().gain_gold(gold_amount)

	_show_chest_modal(contents)

func _show_chest_modal(contents: Dictionary) -> void:
	main._chest_modal_open = true
	main._chest_modal_contents = contents

	var ui = main.get_node("UI") as CanvasLayer

	# Dimmed overlay
	var overlay = ColorRect.new()
	overlay.name = "ChestOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_chest_overlay_input)
	ui.add_child(overlay)

	# Modal panel
	main._chest_modal = PanelContainer.new()
	main._chest_modal.name = "ChestModal"
	main._chest_modal.custom_minimum_size = Vector2(420, 0)
	main._chest_modal.set_anchors_preset(Control.PRESET_CENTER)
	main._chest_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main._chest_modal.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.1, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.7, 0.55, 0.2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	main._chest_modal.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	main._chest_modal.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Treasure Chest!"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Gold
	var gold_amount = contents.get("gold", 0)
	if gold_amount > 0:
		var gold_lbl = Label.new()
		gold_lbl.text = "+ %d Gold" % gold_amount
		gold_lbl.add_theme_font_size_override("font_size", 18)
		gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(gold_lbl)

	# Item reward
	var item: ItemData = contents.get("item")
	if item:
		vbox.add_child(HSeparator.new())
		var item_container = _build_chest_item_display(item)
		vbox.add_child(item_container)

		var pick_up_btn = Button.new()
		pick_up_btn.text = "Pick Up Item"
		pick_up_btn.custom_minimum_size = Vector2(160, 36)
		pick_up_btn.add_theme_font_size_override("font_size", 15)
		_style_chest_button(pick_up_btn, Color(0.15, 0.4, 0.15), Color(0.3, 0.7, 0.3))
		pick_up_btn.pressed.connect(_on_chest_pick_up_item.bind(item))
		vbox.add_child(pick_up_btn)

	# Card reward
	var card: Card = contents.get("card")
	if card:
		vbox.add_child(HSeparator.new())
		var card_container = _build_chest_card_display(card)
		vbox.add_child(card_container)

		var btn_hbox = HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 12)

		var add_inv_btn = Button.new()
		add_inv_btn.text = "Take Card"
		add_inv_btn.custom_minimum_size = Vector2(140, 36)
		add_inv_btn.add_theme_font_size_override("font_size", 15)
		_style_chest_button(add_inv_btn, Color(0.15, 0.3, 0.45), Color(0.3, 0.5, 0.8))
		add_inv_btn.pressed.connect(_on_chest_take_card.bind(card))
		btn_hbox.add_child(add_inv_btn)

		# Check if card can be slotted into any weapon
		var inv = main.player.get_inventory()
		var compatible_items = _get_compatible_items_for_card(card, inv)
		if compatible_items.size() > 0:
			var slot_btn = Button.new()
			slot_btn.text = "Slot into Weapon"
			slot_btn.custom_minimum_size = Vector2(150, 36)
			slot_btn.add_theme_font_size_override("font_size", 15)
			_style_chest_button(slot_btn, Color(0.4, 0.25, 0.1), Color(0.7, 0.5, 0.2))
			slot_btn.pressed.connect(_on_chest_slot_card.bind(card, compatible_items))
			btn_hbox.add_child(slot_btn)

		vbox.add_child(btn_hbox)

	vbox.add_child(HSeparator.new())

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 34)
	close_btn.add_theme_font_size_override("font_size", 14)
	_style_chest_button(close_btn, Color(0.3, 0.15, 0.15), Color(0.6, 0.3, 0.3))
	close_btn.pressed.connect(_close_chest_modal)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_btn)

	ui.add_child(main._chest_modal)

func _build_chest_item_display(item: ItemData) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = "[%s]" % item.get_type_name()
	type_lbl.add_theme_font_size_override("font_size", 13)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(type_lbl)

	# Stats (build same as town modal)
	var stats_text = _build_chest_item_stats(item)
	if stats_text != "":
		var stats_lbl = Label.new()
		stats_lbl.text = stats_text
		stats_lbl.add_theme_font_size_override("font_size", 13)
		stats_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		container.add_child(stats_lbl)

	if item.description != "":
		var desc_lbl = Label.new()
		desc_lbl.text = item.description
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(desc_lbl)

	return container

func _build_chest_item_stats(item: ItemData) -> String:
	var lines: Array[String] = []
	if item.strength_bonus != 0:
		lines.append("+%d Strength" % item.strength_bonus if item.strength_bonus > 0 else "%d Strength" % item.strength_bonus)
	if item.dexterity_bonus != 0:
		lines.append("+%d Dexterity" % item.dexterity_bonus if item.dexterity_bonus > 0 else "%d Dexterity" % item.dexterity_bonus)
	if item.intelligence_bonus != 0:
		lines.append("+%d Intelligence" % item.intelligence_bonus if item.intelligence_bonus > 0 else "%d Intelligence" % item.intelligence_bonus)
	if item.weapon_damage > 0:
		lines.append("%d Weapon Damage" % item.weapon_damage)
	if item.armor_bonus > 0:
		lines.append("+%d Armor" % item.armor_bonus)
	if item.health_bonus > 0:
		lines.append("+%d Health" % item.health_bonus)
	if item.mana_bonus > 0:
		lines.append("+%d Mana" % item.mana_bonus)
	if item.weight > 0:
		lines.append("Weight: %d" % item.weight)
	return "\n".join(lines)

func _build_chest_card_display(card: Card) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_lbl)

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
		Card.CardType.POWER:
			type_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
		Card.CardType.ENCHANTMENT:
			type_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.8))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(type_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "Cost: %dM / %dT" % [card.mana_cost, card.tempo_cost]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(cost_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = card.description
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(desc_lbl)

	return container

func _get_compatible_items_for_card(card: Card, inv: Inventory) -> Array[ItemData]:
	var result: Array[ItemData] = []
	var items = inv.get_all_items_with_card_slots()
	for item in items:
		if item.can_slot_card(card):
			result.append(item)
	return result

func _on_chest_pick_up_item(item: ItemData) -> void:
	var inv = main.player.get_inventory()
	if inv.store_item(item):
		main.add_battle_log("Picked up %s!" % item.item_name, Color(1.0, 0.85, 0.3))
	else:
		main.add_battle_log("Inventory full! Could not pick up %s." % item.item_name, Color(1.0, 0.4, 0.4))
	main._chest_modal_contents["_item_claimed"] = true
	_close_chest_modal()

func _on_chest_take_card(card: Card) -> void:
	var inv = main.player.get_inventory()
	if inv and inv.store_card(card):
		main.add_battle_log("Took %s (card inventory)" % card.card_name, Color(0.3, 0.8, 1.0))
	else:
		main.add_battle_log("Card inventory full! Could not take %s." % card.card_name, Color(1.0, 0.4, 0.4))
	main._chest_modal_contents["_card_claimed"] = true
	_close_chest_modal()

func _on_chest_slot_card(card: Card, compatible_items: Array[ItemData]) -> void:
	# For simplicity, slot into first compatible item
	if compatible_items.size() > 0:
		var target_item = compatible_items[0]
		var inv = main.player.get_inventory()
		if inv.enchant_card(card, target_item):
			main.add_battle_log("Slotted %s into %s!" % [card.card_name, target_item.item_name], Color(0.8, 0.6, 1.0))
		else:
			# Fallback: add to card inventory
			if inv.store_card(card):
				main.add_battle_log("Could not slot card. Added %s to card inventory." % card.card_name, Color(1.0, 0.6, 0.3))
	main._chest_modal_contents["_card_claimed"] = true
	_close_chest_modal()

func _on_chest_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_chest_modal()

func _close_chest_modal() -> void:
	# Auto-collect any unclaimed items/cards before closing
	var contents = main._chest_modal_contents
	if not contents.is_empty():
		var inv = main.player.get_inventory()
		var item: ItemData = contents.get("item")
		if item and not contents.get("_item_claimed", false):
			if inv.store_item(item):
				main.add_battle_log("Picked up %s!" % item.item_name, Color(1.0, 0.85, 0.3))
			else:
				main.add_battle_log("Inventory full! Could not pick up %s." % item.item_name, Color(1.0, 0.4, 0.4))
		var card: Card = contents.get("card")
		if card and not contents.get("_card_claimed", false):
			if inv and inv.store_card(card):
				main.add_battle_log("Took %s (card inventory)" % card.card_name, Color(0.3, 0.8, 1.0))
			else:
				main.add_battle_log("Card inventory full! Could not take %s." % card.card_name, Color(1.0, 0.4, 0.4))

	main._chest_modal_open = false
	main._chest_modal_contents = {}
	var ui = main.get_node("UI") as CanvasLayer
	var overlay = ui.get_node_or_null("ChestOverlay")
	if overlay:
		overlay.queue_free()
	if main._chest_modal and is_instance_valid(main._chest_modal):
		main._chest_modal.queue_free()
		main._chest_modal = null

func _style_chest_button(btn: Button, bg_color: Color, border_color: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = border_color
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = bg_color.lightened(0.15)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.border_color = border_color.lightened(0.2)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hover)

