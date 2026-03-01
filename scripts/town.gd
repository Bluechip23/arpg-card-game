extends Node3D

## Town scene - vendors, stash, and preparation before battle

@onready var player: Player = $Player
@onready var grid_manager: GridManager = $GridManager
@onready var interact_prompt: Label = $UI/InteractPrompt
@onready var vendor_panel: PanelContainer = $UI/VendorPanel
@onready var vendor_name_label: Label = $UI/VendorPanel/MarginContainer/VBox/HeaderHBox/VendorNameLabel
@onready var vendor_close_button: Button = $UI/VendorPanel/MarginContainer/VBox/HeaderHBox/CloseButton
@onready var vendor_inventory_label: Label = $UI/VendorPanel/MarginContainer/VBox/InventoryLabel
@onready var vendor_item_list: VBoxContainer = $UI/VendorPanel/MarginContainer/VBox/ScrollContainer/ItemList
@onready var town_label: Label = $UI/TownLabel
@onready var fight_button: Button = $UI/FightButton

const INTERACT_DISTANCE: float = 2.5  # Max tiles from vendor to interact

var starting_character: CharacterData = null
var nearby_vendor: StaticBody3D = null
var vendor_open: bool = false

# Item detail modal (built dynamically)
var _detail_modal: PanelContainer = null
var _detail_item: ItemData = null
var _modal_open: bool = false

# Vendor metadata: node name -> display info
var vendor_info: Dictionary = {
	"Blacksmith": {
		"name": "Blacksmith",
		"description": "Enchant cards into items, extract cards from items.",
		"type": "blacksmith"
	},
	"Armory": {
		"name": "Armory",
		"description": "Buy and sell weapons and armor.",
		"type": "armory"
	},
	"CardDealer": {
		"name": "Card Dealer",
		"description": "Buy, sell, and trade cards for your deck.",
		"type": "card_dealer"
	},
	"AccessoryShop": {
		"name": "Accessory Shop",
		"description": "Rings, belts, boots, and other accessories.",
		"type": "accessory"
	},
	"Stash": {
		"name": "Stash",
		"description": "Store items and cards for later use.",
		"type": "stash"
	}
}

func _ready() -> void:
	player.set_grid_manager(grid_manager)

	if starting_character:
		player.initialize_character(starting_character)
		print("[TOWN] Character loaded: %s" % starting_character.character_name)

	_apply_styles()

	vendor_close_button.pressed.connect(_close_vendor)
	fight_button.pressed.connect(_go_to_battle)

	interact_prompt.text = ""
	vendor_panel.visible = false

func _apply_styles() -> void:
	# Town label
	town_label.add_theme_font_size_override("font_size", 24)
	town_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))

	# Interact prompt
	interact_prompt.add_theme_font_size_override("font_size", 16)
	interact_prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))

	# Vendor panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.13, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.35, 0.5)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	vendor_panel.add_theme_stylebox_override("panel", panel_style)

	# Vendor name
	vendor_name_label.add_theme_font_size_override("font_size", 20)
	vendor_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))

	# Inventory label
	vendor_inventory_label.add_theme_font_size_override("font_size", 14)
	vendor_inventory_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))

	# Close button
	vendor_close_button.add_theme_font_size_override("font_size", 16)

	# Fight button
	fight_button.add_theme_font_size_override("font_size", 16)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.5, 0.15, 0.15)
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.8, 0.3, 0.3)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	fight_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.65, 0.2, 0.2)
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.border_color = Color(1.0, 0.4, 0.4)
	btn_hover.corner_radius_top_left = 4
	btn_hover.corner_radius_top_right = 4
	btn_hover.corner_radius_bottom_left = 4
	btn_hover.corner_radius_bottom_right = 4
	fight_button.add_theme_stylebox_override("hover", btn_hover)

func _process(_delta: float) -> void:
	if vendor_open:
		return

	# Check proximity to vendors
	var closest_vendor: StaticBody3D = null
	var closest_dist: float = INTERACT_DISTANCE + 1

	for vendor_node in $Vendors.get_children():
		if vendor_node is StaticBody3D:
			var dist = player.position.distance_to(vendor_node.position)
			if dist < INTERACT_DISTANCE and dist < closest_dist:
				closest_vendor = vendor_node
				closest_dist = dist

	nearby_vendor = closest_vendor

	if nearby_vendor:
		var info = vendor_info.get(nearby_vendor.name, null)
		var display_name = info["name"] if info else nearby_vendor.name
		interact_prompt.text = "Press [A] to interact with %s" % display_name
	else:
		interact_prompt.text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				if _modal_open or vendor_open:
					return
				if nearby_vendor:
					_open_vendor(nearby_vendor)
			KEY_ESCAPE:
				if _modal_open:
					_close_detail_modal()
				elif vendor_open:
					_close_vendor()

	# Right-click movement (simplified town movement)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if vendor_open:
			return
		var mouse_pos = _get_mouse_world_position()
		if mouse_pos != Vector3.ZERO:
			var distance = _get_grid_distance(player.position, mouse_pos)
			player.move_to_grid(mouse_pos, max(1, distance))

func _get_grid_distance(from: Vector3, to: Vector3) -> int:
	var from_grid = grid_manager.world_to_grid(from)
	var to_grid = grid_manager.world_to_grid(to)
	return absi(to_grid.x - from_grid.x) + absi(to_grid.y - from_grid.y)

func _get_mouse_world_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)

	# Intersect with ground plane (Y=0)
	if ray_dir.y == 0:
		return Vector3.ZERO

	var t = -ray_origin.y / ray_dir.y
	if t < 0:
		return Vector3.ZERO

	return ray_origin + ray_dir * t

func _get_vendor_items(vendor_type: String) -> Array[ItemData]:
	var items: Array[ItemData] = []
	match vendor_type:
		"armory":
			items.append(ItemData.create_iron_sword())
			items.append(ItemData.create_heavy_greatsword())
			items.append(ItemData.create_flame_dagger())
			items.append(ItemData.create_frost_orb())
			items.append(ItemData.create_wooden_shield())
			items.append(ItemData.create_iron_helm())
			items.append(ItemData.create_leather_chest())
			items.append(ItemData.create_iron_gauntlets())
			items.append(ItemData.create_berserker_gauntlets())
			items.append(ItemData.create_guardian_gauntlets())
		"accessory":
			items.append(ItemData.create_ice_quiver())
			items.append(ItemData.create_fire_quiver())
			items.append(ItemData.create_belt_of_greater_healing())
			items.append(ItemData.create_utility_belt())
			items.append(ItemData.create_leather_boots())
			items.append(ItemData.create_gold_ring())
			items.append(ItemData.create_ring_of_vengeance())
			items.append(ItemData.create_ring_of_fortitude())
			items.append(ItemData.create_ring_of_the_scholar())
	return items

func _open_vendor(vendor_node: StaticBody3D) -> void:
	var info = vendor_info.get(vendor_node.name, null)
	if not info:
		return

	vendor_open = true
	vendor_name_label.text = info["name"]

	# Clear old items from list
	for child in vendor_item_list.get_children():
		child.queue_free()

	# Populate vendor inventory
	var shop_items = _get_vendor_items(info["type"])
	if shop_items.is_empty():
		vendor_inventory_label.text = info["description"] + "\n\nInventory is empty."
	else:
		vendor_inventory_label.text = info["description"]
		for item in shop_items:
			_add_vendor_item_row(item)

	vendor_panel.visible = true
	interact_prompt.text = ""
	print("[TOWN] Opened vendor: %s (%d items)" % [info["name"], shop_items.size()])

func _add_vendor_item_row(item: ItemData) -> void:
	var btn = Button.new()
	btn.custom_minimum_size.y = 40
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "  %s   [%s]   %s" % [item.item_name, item.get_type_name(), item.description]
	btn.add_theme_font_size_override("font_size", 13)

	# Normal style
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.13, 0.17, 0.9)
	normal.border_width_bottom = 1
	normal.border_color = Color(0.25, 0.25, 0.3)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", normal)

	# Hover style
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.2, 0.28, 0.95)
	hover.border_width_bottom = 1
	hover.border_width_left = 2
	hover.border_color = Color(0.5, 0.45, 0.7)
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed style
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.25, 0.22, 0.35, 1.0)
	pressed.border_width_bottom = 1
	pressed.border_color = Color(0.6, 0.5, 0.8)
	pressed.corner_radius_top_left = 4
	pressed.corner_radius_top_right = 4
	pressed.corner_radius_bottom_left = 4
	pressed.corner_radius_bottom_right = 4
	pressed.content_margin_left = 8
	pressed.content_margin_right = 8
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.8))

	btn.pressed.connect(_on_vendor_item_clicked.bind(item))
	vendor_item_list.add_child(btn)

# ============================================
# ITEM DETAIL MODAL
# ============================================

func _on_vendor_item_clicked(item: ItemData) -> void:
	_show_detail_modal(item)

func _show_detail_modal(item: ItemData) -> void:
	# Close existing modal if open
	if _detail_modal and is_instance_valid(_detail_modal):
		_detail_modal.queue_free()

	_detail_item = item
	_modal_open = true

	# --- Dimmed background overlay ---
	var overlay = ColorRect.new()
	overlay.name = "ModalOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Clicking the overlay closes the modal
	overlay.gui_input.connect(_on_overlay_input)

	# --- Modal panel ---
	_detail_modal = PanelContainer.new()
	_detail_modal.custom_minimum_size = Vector2(460, 0)
	_detail_modal.set_anchors_preset(Control.PRESET_CENTER)
	_detail_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_detail_modal.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.5, 0.45, 0.65)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_detail_modal.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_detail_modal.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# --- Item name ---
	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	var name_color = _get_item_name_color(item)
	name_lbl.add_theme_color_override("font_color", name_color)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# --- Item type ---
	var type_lbl = Label.new()
	type_lbl.text = item.get_type_name()
	type_lbl.add_theme_font_size_override("font_size", 14)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)

	vbox.add_child(HSeparator.new())

	# --- Stats ---
	var stats_text = _build_modal_stats(item)
	if stats_text != "":
		var stats_lbl = Label.new()
		stats_lbl.text = stats_text
		stats_lbl.add_theme_font_size_override("font_size", 14)
		stats_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		vbox.add_child(stats_lbl)

	# --- Special effects ---
	var effects_text = _build_modal_effects(item)
	if effects_text != "":
		var effects_lbl = Label.new()
		effects_lbl.text = effects_text
		effects_lbl.add_theme_font_size_override("font_size", 13)
		effects_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		effects_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(effects_lbl)

	# --- Card slot info ---
	var slots_text = _build_modal_slots(item)
	if slots_text != "":
		var slots_lbl = Label.new()
		slots_lbl.text = slots_text
		slots_lbl.add_theme_font_size_override("font_size", 13)
		slots_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
		vbox.add_child(slots_lbl)

	# --- Description ---
	if item.description != "":
		vbox.add_child(HSeparator.new())
		var desc_lbl = Label.new()
		desc_lbl.text = item.description
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

	vbox.add_child(HSeparator.new())

	# --- Buttons row ---
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)

	var buy_btn = Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(120, 36)
	buy_btn.add_theme_font_size_override("font_size", 16)
	_style_action_button(buy_btn, Color(0.15, 0.4, 0.15), Color(0.2, 0.55, 0.2), Color(0.3, 0.7, 0.3))
	buy_btn.pressed.connect(_on_buy_pressed)
	btn_hbox.add_child(buy_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 36)
	close_btn.add_theme_font_size_override("font_size", 14)
	_style_action_button(close_btn, Color(0.3, 0.15, 0.15), Color(0.45, 0.2, 0.2), Color(0.6, 0.3, 0.3))
	close_btn.pressed.connect(_close_detail_modal)
	btn_hbox.add_child(close_btn)

	vbox.add_child(btn_hbox)

	# Add overlay and modal to UI layer
	$UI.add_child(overlay)
	$UI.add_child(_detail_modal)

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_detail_modal()

func _close_detail_modal() -> void:
	_modal_open = false
	_detail_item = null
	# Remove overlay
	var overlay = $UI.get_node_or_null("ModalOverlay")
	if overlay:
		overlay.queue_free()
	# Remove modal
	if _detail_modal and is_instance_valid(_detail_modal):
		_detail_modal.queue_free()
		_detail_modal = null

func _on_buy_pressed() -> void:
	if not _detail_item:
		return

	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		print("[TOWN] No inventory available!")
		_close_detail_modal()
		return

	# Try to equip directly into the matching slot type
	var equipped = false
	var item_type = _detail_item.item_type
	var max_slots = inventory._get_max_slots(item_type)
	for i in range(max_slots):
		var slot_array = inventory._get_slot_array(item_type)
		if slot_array[i] == null:
			equipped = inventory.equip_item(_detail_item, i)
			if equipped:
				print("[TOWN] Equipped %s in %s slot %d" % [_detail_item.item_name, _detail_item.get_type_name(), i])
				break

	# If no equip slot free, try storage
	if not equipped:
		if inventory.store_item(_detail_item):
			print("[TOWN] Stored %s in inventory" % _detail_item.item_name)
			equipped = true
		else:
			print("[TOWN] Inventory full! Cannot buy %s" % _detail_item.item_name)

	_close_detail_modal()

func _style_action_button(btn: Button, normal_color: Color, hover_color: Color, border_color: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = normal_color
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
	hover.bg_color = hover_color
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.border_color = border_color
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("hover", hover)

func _get_item_name_color(item: ItemData) -> Color:
	match item.item_type:
		ItemData.ItemType.WEAPON: return Color(1.0, 0.5, 0.5)
		ItemData.ItemType.RING: return Color(0.5, 0.5, 1.0)
		ItemData.ItemType.QUIVER: return Color(0.3, 0.8, 0.9)
		ItemData.ItemType.BELT: return Color(0.8, 0.6, 0.3)
		ItemData.ItemType.BOOTS: return Color(0.5, 1.0, 0.5)
		ItemData.ItemType.GAUNTLETS: return Color(0.9, 0.6, 0.2)
		ItemData.ItemType.HELM: return Color(0.7, 0.7, 0.7)
		ItemData.ItemType.CHEST: return Color(0.6, 0.4, 0.2)
	return Color(1.0, 0.9, 0.6)

func _build_modal_stats(item: ItemData) -> String:
	var lines: Array[String] = []
	if item.strength_bonus != 0:
		lines.append("+%d Strength" % item.strength_bonus if item.strength_bonus > 0 else "%d Strength" % item.strength_bonus)
	if item.dexterity_bonus != 0:
		lines.append("+%d Dexterity" % item.dexterity_bonus if item.dexterity_bonus > 0 else "%d Dexterity" % item.dexterity_bonus)
	if item.intelligence_bonus != 0:
		lines.append("+%d Intelligence" % item.intelligence_bonus if item.intelligence_bonus > 0 else "%d Intelligence" % item.intelligence_bonus)
	if item.wisdom_bonus != 0:
		lines.append("+%d Wisdom" % item.wisdom_bonus if item.wisdom_bonus > 0 else "%d Wisdom" % item.wisdom_bonus)
	if item.determination_bonus != 0:
		lines.append("+%d Determination" % item.determination_bonus if item.determination_bonus > 0 else "%d Determination" % item.determination_bonus)
	if item.agility_bonus != 0:
		lines.append("+%d Agility" % item.agility_bonus if item.agility_bonus > 0 else "%d Agility" % item.agility_bonus)
	if item.health_bonus != 0:
		lines.append("+%d Health" % item.health_bonus if item.health_bonus > 0 else "%d Health" % item.health_bonus)
	if item.mana_bonus != 0:
		lines.append("+%d Mana" % item.mana_bonus if item.mana_bonus > 0 else "%d Mana" % item.mana_bonus)
	if item.armor_bonus != 0:
		lines.append("+%d Armor" % item.armor_bonus if item.armor_bonus > 0 else "%d Armor" % item.armor_bonus)
	if item.hand_size_bonus != 0:
		lines.append("+%d Hand Size" % item.hand_size_bonus)
	if item.weapon_damage > 0:
		lines.append("%d Weapon Damage" % item.weapon_damage)
	if item.ranged_damage_bonus > 0:
		lines.append("+%d Ranged Damage (all)" % item.ranged_damage_bonus)
	if item.healing_bonus > 0:
		lines.append("+%d Healing (all)" % item.healing_bonus)
	if item.weight > 0:
		lines.append("Weight: %d" % item.weight)
	return "\n".join(lines)

func _build_modal_effects(item: ItemData) -> String:
	var lines: Array[String] = []

	# Ring triggers
	if item.ring_trigger != ItemData.RingTrigger.NONE:
		lines.append("[Ring] %s -> %s" % [item.get_ring_trigger_name(), item.get_ring_effect_name()])

	# Gauntlet skills
	if item.gauntlet_skill_type == ItemData.GauntletSkillType.ACTIVE:
		lines.append("[Active Skill] %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description])
		lines.append("  Cost: %d Mana | Cooldown: %d turns" % [item.gauntlet_skill_mana_cost, item.gauntlet_skill_cooldown])
	elif item.gauntlet_skill_type == ItemData.GauntletSkillType.PASSIVE:
		lines.append("[Passive] %s: %s" % [item.gauntlet_skill_name, item.gauntlet_skill_description])

	# Special effects
	match item.special_effect:
		ItemData.SpecialEffect.OVERFLOW_HEAL_ARMOR:
			lines.append("[Overflow] Heal %d, +%d Armor" % [item.special_effect_value, item.special_effect_value_2])
		ItemData.SpecialEffect.GRANT_BLINK_CARD:
			lines.append("[Equip] Grants %d Blink card(s)" % item.special_effect_value)
		ItemData.SpecialEffect.CHANCE_BOOST:
			lines.append("[Passive] +%d%% chance effects" % item.special_effect_value)
		ItemData.SpecialEffect.GRANT_CARDS:
			lines.append("[Equip] Grants cards: %s" % ", ".join(item.granted_card_ids))
		ItemData.SpecialEffect.ARMOR_ON_ARMOR_GAIN:
			lines.append("[Passive] +%d Armor on every Armor gain" % item.special_effect_value)
		ItemData.SpecialEffect.ARMOR_PER_TURN:
			lines.append("[Passive] +%d Armor per turn" % item.special_effect_value)

	# On-self bonuses
	var on_self_parts: Array[String] = []
	if item.on_self_damage > 0:
		on_self_parts.append("+%d damage" % item.on_self_damage)
	if item.on_self_block > 0:
		on_self_parts.append("+%d block" % item.on_self_block)
	if item.on_self_heal > 0:
		on_self_parts.append("+%d heal" % item.on_self_heal)
	if item.on_self_mana_reduction > 0:
		on_self_parts.append("-%d mana cost" % item.on_self_mana_reduction)
	if item.on_self_apply_burn > 0:
		on_self_parts.append("Apply %d Burn on hit" % item.on_self_apply_burn)
	if item.on_self_apply_cold > 0:
		on_self_parts.append("Apply %d Cold on hit" % item.on_self_apply_cold)
	if on_self_parts.size() > 0:
		lines.append("[On-Self] %s" % ", ".join(on_self_parts))

	return "\n".join(lines)

func _build_modal_slots(item: ItemData) -> String:
	if item.card_slots <= 0:
		return ""
	var lines: Array[String] = []
	lines.append("[Card Slots] %d available" % item.card_slots)
	# Show allowed keywords
	if item.allowed_card_keywords.size() > 0:
		var kw_names: Array[String] = []
		for kw in item.allowed_card_keywords:
			match kw:
				1: kw_names.append("Arrow")
				2: kw_names.append("Pocket")
				3: kw_names.append("Gem")
		if kw_names.size() > 0:
			lines.append("  Accepts: %s cards only" % ", ".join(kw_names))
	return "\n".join(lines)

func _close_vendor() -> void:
	vendor_open = false
	vendor_panel.visible = false
	print("[TOWN] Closed vendor")

func _go_to_battle() -> void:
	if vendor_open:
		_close_vendor()

	print("[TOWN] Heading to battle!")
	var main_scene = load("res://main.tscn").instantiate()
	main_scene.starting_character = starting_character
	get_tree().root.add_child(main_scene)
	queue_free()
