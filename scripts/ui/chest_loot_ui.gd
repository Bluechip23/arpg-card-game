class_name ChestLootUI
extends Node

## Handles chest interaction, loot display modals, and item/card pickup.
## Extracted from main.gd to reduce god-object complexity.

var main  # Reference to the Main scene node
var _current_chest_idx: int = -1  # Index of the chest currently being interacted with

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

	_current_chest_idx = chest_idx
	var contents = main.dungeon_manager.open_chest(chest_idx)
	if contents.is_empty():
		return

	var gold_just_claimed = false
	# Grant gold immediately on first open only
	if not contents.get("_gold_claimed", false):
		var gold_amount = contents.get("gold", 0)
		if gold_amount > 0:
			main.player.get_stats().gain_gold(gold_amount)
			gold_just_claimed = true
		contents["_gold_claimed"] = true

	_show_chest_modal(contents, gold_just_claimed)

func _show_chest_modal(contents: Dictionary, gold_just_claimed: bool = false) -> void:
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
	var has_rewards = contents.get("item") != null or contents.get("card") != null \
		or contents.get("card_pack") != null
	var title = Label.new()
	title.text = "Treasure Chest!" if gold_just_claimed else ("Unclaimed Loot" if has_rewards else "Empty Chest")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Gold (only show if just claimed this interaction)
	var gold_amount = contents.get("gold", 0)
	if gold_amount > 0 and gold_just_claimed:
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

	# Card pack reward
	var pack_tier = contents.get("card_pack")
	if pack_tier != null:
		vbox.add_child(HSeparator.new())
		var pack := CardPack.create(pack_tier)
		var pack_lbl = Label.new()
		pack_lbl.text = pack.get_display_name()
		pack_lbl.add_theme_font_size_override("font_size", 18)
		pack_lbl.add_theme_color_override("font_color", pack.get_tier_color())
		pack_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(pack_lbl)
		var pack_desc = Label.new()
		pack_desc.text = "A sealed pack of %d cards." % int(DropRates.PACK_CARD_COUNT.get(pack_tier, 3))
		pack_desc.add_theme_font_size_override("font_size", 13)
		pack_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		pack_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(pack_desc)
		var open_btn = Button.new()
		open_btn.text = "Open Pack"
		open_btn.custom_minimum_size = Vector2(150, 36)
		open_btn.add_theme_font_size_override("font_size", 15)
		_style_chest_button(open_btn, Color(0.3, 0.15, 0.4), Color(0.6, 0.35, 0.8))
		open_btn.pressed.connect(_on_chest_open_pack.bind(pack))
		open_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(open_btn)

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

	# A card's keywords get their own little window beside the chest so the
	# player can read what Burden / Sticky / Glut mean before taking it. It
	# lives on the dim overlay, so closing the chest takes it down too.
	if card:
		var kw_win := KeywordWindow.for_card(card)
		if kw_win:
			overlay.add_child(kw_win)
			kw_win.place_beside(main._chest_modal)

func _build_chest_item_display(item: ItemData) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var name_lbl = Label.new()
	name_lbl.text = item.get_display_name()
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", item.get_rarity_color())
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_lbl)

	var type_lbl = Label.new()
	type_lbl.text = "[%s %s]" % [item.get_rarity_name(), item.get_type_name()]
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
	# Mythics get the full reveal sequence (glow → present → icon) instead of
	# slipping quietly into the bag; the item is stored when the sequence ends.
	if item.rarity == ItemData.Rarity.MYTHIC:
		main.dungeon_manager.remove_chest_item(_current_chest_idx)
		_close_chest_modal()
		main._start_mythic_reveal(item, main.player)
		return
	var inv = main.player.get_inventory()
	if inv.store_item(item):
		main.add_battle_log("Picked up %s!" % item.item_name, Color(1.0, 0.85, 0.3))
		main.dungeon_manager.remove_chest_item(_current_chest_idx)
	else:
		main.add_battle_log("Inventory full! Could not pick up %s." % item.item_name, Color(1.0, 0.4, 0.4))
	_close_chest_modal()

func _on_chest_take_card(card: Card) -> void:
	var inv = main.player.get_inventory()
	print("[CHEST] Take card pressed: %s, inv=%s" % [card.card_name if card else "null", inv])
	if inv and inv.store_card(card):
		main.add_battle_log("Added %s to card inventory!" % card.card_name, Color(0.3, 0.8, 1.0))
		print("[CHEST] Card stored successfully: %s (now %d cards)" % [card.card_name, inv.get_stored_card_count()])
		main.dungeon_manager.remove_chest_card(_current_chest_idx)
	else:
		main.add_battle_log("Card inventory full! Could not take %s." % card.card_name, Color(1.0, 0.4, 0.4))
		print("[CHEST] Failed to store card: %s" % [card.card_name if card else "null"])
	_close_chest_modal()

func _on_chest_slot_card(card: Card, compatible_items: Array[ItemData]) -> void:
	# For simplicity, slot into first compatible item
	var claimed = false
	if compatible_items.size() > 0:
		var target_item = compatible_items[0]
		var inv = main.player.get_inventory()
		if inv.enchant_card(card, target_item):
			# A chest card was never in a deck zone — enchanted cards live in
			# the deck AND the slot, so put it into the draw pile too (the
			# equip/unequip card lifecycle tracks it from here).
			if main.deck_manager and not inv._card_in_any_zone(card):
				main.deck_manager.draw_pile.append(card)
				main.deck_manager.shuffle_draw_pile()
			main.add_battle_log("Slotted %s into %s!" % [card.card_name, target_item.item_name], Color(0.8, 0.6, 1.0))
			claimed = true
		else:
			# Fallback: add to card inventory
			if inv.store_card(card):
				main.add_battle_log("Could not slot card. Added %s to card inventory." % card.card_name, Color(1.0, 0.6, 0.3))
				claimed = true
	if claimed:
		main.dungeon_manager.remove_chest_card(_current_chest_idx)
	_close_chest_modal()

func _on_chest_open_pack(pack: CardPack) -> void:
	## Rip the pack open: cards roll fresh, land in the card inventory, and a
	## small results modal shows what was pulled.
	var inv = main.player.get_inventory()
	var cards: Array = pack.open()
	var pulled: Array[String] = []
	for pc in cards:
		if inv and inv.store_card(pc):
			pulled.append(pc.card_name)
		else:
			main.add_battle_log("Card inventory full! %s was lost." % pc.card_name, Color(1.0, 0.4, 0.4))
	main.add_battle_log("Opened a %s: %s" % [pack.get_display_name(), ", ".join(pulled)], pack.get_tier_color())
	main.dungeon_manager.remove_chest_pack(_current_chest_idx)
	_close_chest_modal()
	_show_pack_results(pack, cards)

func _show_pack_results(pack: CardPack, cards: Array) -> void:
	## Lightweight reveal panel: the pack's name and each card pulled, colored
	## by its own rarity. Auto-dismissed by its Close button.
	var ui = main.get_node("UI") as CanvasLayer
	var panel = PanelContainer.new()
	panel.name = "PackResults"
	panel.custom_minimum_size = Vector2(320, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.98)
	style.set_border_width_all(2)
	style.border_color = pack.get_tier_color()
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var title = Label.new()
	title.text = "%s opened!" % pack.get_display_name()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", pack.get_tier_color())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	for pc in cards:
		var lbl = Label.new()
		lbl.text = "%s  (%s)" % [pc.card_name, pc.get_rarity_name()]
		lbl.add_theme_font_size_override("font_size", 14)
		match pc.get_rarity():
			Card.Rarity.RARE: lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
			Card.Rarity.LEGENDARY: lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			Card.Rarity.MYTHIC: lbl.add_theme_color_override("font_color", Color(0.9, 0.35, 0.9))
			_: lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
	var close = Button.new()
	close.text = "Nice!"
	close.custom_minimum_size = Vector2(110, 32)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_chest_button(close, Color(0.15, 0.35, 0.2), Color(0.35, 0.7, 0.4))
	close.pressed.connect(panel.queue_free)
	vbox.add_child(close)
	ui.add_child(panel)

func _on_chest_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_chest_modal()

func _close_chest_modal() -> void:
	# Check if chest is fully looted (no remaining item or card)
	if _current_chest_idx >= 0 and main.dungeon_manager:
		var chest = main.dungeon_manager.chest_nodes[_current_chest_idx]
		var contents = chest["contents"]
		var has_item = contents.get("item") != null
		var has_card = contents.get("card") != null
		var has_pack = contents.get("card_pack") != null
		if not has_item and not has_card and not has_pack:
			main.dungeon_manager.mark_chest_looted(_current_chest_idx)

	_current_chest_idx = -1
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

