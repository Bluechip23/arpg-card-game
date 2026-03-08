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
@onready var back_button: Button = $UI/BackButton

const INTERACT_DISTANCE: float = 2.5  # Max tiles from vendor to interact

var starting_character: CharacterData = null
var discovered_waypoints: Array = []
var quest_state: Dictionary = {}
var nearby_vendor: StaticBody3D = null
var vendor_open: bool = false
var quest_manager: QuestManager = null
var _quest_panel: PanelContainer = null
var _quest_panel_open: bool = false
var _town_waypoint_node: Node3D = null
var _near_town_waypoint: bool = false

# Camera orbit state (same as main scene)
var _camera_focus: Vector3 = Vector3(10, 0, 6)
var _camera_yaw: float = 0.0
var _camera_pitch: float = -0.785
var _camera_distance: float = 17.0
var _camera_orbiting: bool = false
var _camera_drag_start: Vector2 = Vector2.ZERO
const CAMERA_PITCH_MIN: float = -1.4
const CAMERA_PITCH_MAX: float = -0.15
const CAMERA_ZOOM_MIN: float = 6.0
const CAMERA_ZOOM_MAX: float = 35.0
const CAMERA_ZOOM_STEP: float = 2.0
const CAMERA_ORBIT_SENSITIVITY: float = 0.005

# Item detail modal (built dynamically)
var _detail_modal: PanelContainer = null
var _detail_item: ItemData = null
var _detail_card: Card = null
var _detail_is_sell: bool = false  # Whether the modal is for selling
var _detail_sell_slot_type: int = -1  # ItemData.ItemType for sell
var _detail_sell_slot_index: int = -1  # Slot index for sell
var _modal_open: bool = false
var _current_vendor_type: String = ""

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
	},
	"Olorin": {
		"name": "Olorin",
		"description": "A wise old man with quests for brave adventurers.",
		"type": "quest_giver"
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
	back_button.pressed.connect(_on_back_pressed)

	interact_prompt.text = ""
	vendor_panel.visible = false

	# Create quest manager
	quest_manager = QuestManager.new()
	quest_manager.name = "QuestManager"
	add_child(quest_manager)
	# Restore quest state from battle scene
	if not quest_state.is_empty():
		quest_manager.load_state(quest_state)

	# Create Olorin NPC
	_create_olorin_npc()

	# Create battle waypoint portal
	_create_town_waypoint()

	# Initialize camera
	_camera_focus = player.position + Vector3(3, 0, 0)
	_update_camera()

func _update_camera() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var offset = Vector3(
		sin(_camera_yaw) * cos(_camera_pitch) * _camera_distance,
		-sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * cos(_camera_pitch) * _camera_distance
	)
	camera.position = _camera_focus + offset
	camera.look_at(_camera_focus, Vector3.UP)

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

	# Check proximity to battle waypoint
	_near_town_waypoint = false
	if _town_waypoint_node:
		var wp_dist = player.position.distance_to(_town_waypoint_node.position)
		if wp_dist < INTERACT_DISTANCE:
			_near_town_waypoint = true
		var wp_label = _town_waypoint_node.get_node_or_null("InteractLabel")
		if wp_label:
			wp_label.visible = wp_dist < INTERACT_DISTANCE + 1

	if _near_town_waypoint:
		interact_prompt.text = "Press [Shift] to enter the dungeon"
	elif nearby_vendor:
		var info = vendor_info.get(nearby_vendor.name, null)
		var display_name = info["name"] if info else nearby_vendor.name
		interact_prompt.text = "Press [Shift] to interact with %s" % display_name
	else:
		interact_prompt.text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SHIFT:
				if _modal_open or vendor_open:
					return
				if _near_town_waypoint:
					_go_to_battle()
					return
				if nearby_vendor:
					_open_vendor(nearby_vendor)
			KEY_ESCAPE:
				if _modal_open:
					_close_detail_modal()
				elif vendor_open:
					_close_vendor()
			KEY_COMMA:
				_camera_distance = max(CAMERA_ZOOM_MIN, _camera_distance - CAMERA_ZOOM_STEP)
				_update_camera()
			KEY_PERIOD:
				_camera_distance = min(CAMERA_ZOOM_MAX, _camera_distance + CAMERA_ZOOM_STEP)
				_update_camera()

	# Mouse wheel zoom
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = max(CAMERA_ZOOM_MIN, _camera_distance - CAMERA_ZOOM_STEP)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = min(CAMERA_ZOOM_MAX, _camera_distance + CAMERA_ZOOM_STEP)
			_update_camera()

	# Camera orbit - left click drag
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not vendor_open and not _modal_open:
				_camera_orbiting = true
				_camera_drag_start = event.position
		else:
			_camera_orbiting = false

	if event is InputEventMouseMotion and _camera_orbiting:
		var delta = event.relative
		_camera_yaw -= delta.x * CAMERA_ORBIT_SENSITIVITY
		_camera_pitch = clamp(_camera_pitch - delta.y * CAMERA_ORBIT_SENSITIVITY, CAMERA_PITCH_MIN, CAMERA_PITCH_MAX)
		_update_camera()

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
	_current_vendor_type = info["type"]
	vendor_name_label.text = info["name"]

	# Clear old items from list
	for child in vendor_item_list.get_children():
		child.queue_free()

	vendor_inventory_label.text = info["description"]

	if info["type"] == "quest_giver":
		_open_quest_dialog(vendor_node)
		return

	if info["type"] == "card_dealer":
		# Show culling stone count
		var inventory = player.get_inventory() if player.has_method("get_inventory") else null
		var stones = inventory.get_culling_stone_count() if inventory else 0
		_add_info_label("Culling Stones: %d" % stones, Color(0.8, 0.5, 1.0))

		# Card shop: show all available cards for purchase
		_add_section_separator("Available Cards")
		var all_cards = _get_all_cards()
		for card in all_cards:
			_add_vendor_card_row(card, false)

		# Show the player's full deck (base + starting + purchased - removed)
		var deck_ids = _get_current_deck_card_ids()
		if deck_ids.size() > 0:
			_add_section_separator("Your Deck (%d cards)" % deck_ids.size())
			for i in range(deck_ids.size()):
				var card = _create_card_from_id(deck_ids[i])
				if card:
					_add_vendor_card_row(card, true, i)
	else:
		# Item shops: show shop inventory
		var shop_items = _get_vendor_items(info["type"])
		for item in shop_items:
			_add_vendor_item_row(item)

		# Show player's matching items for selling
		var sell_items = _get_player_items_for_vendor(info["type"])
		if sell_items.size() > 0:
			_add_section_separator("Your Equipment")
			for entry in sell_items:
				_add_sell_item_row(entry["item"], entry["slot_type"], entry["slot_index"])

	vendor_panel.visible = true
	interact_prompt.text = ""
	print("[TOWN] Opened vendor: %s" % info["name"])

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
# CARD SHOP HELPERS
# ============================================

func _add_info_label(text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = "  %s" % text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	vendor_item_list.add_child(lbl)

func _get_current_deck_card_ids() -> Array:
	## Builds the full list of card_ids that would be in the player's battle deck.
	if not starting_character:
		return []

	var all_ids: Array = []

	# Base cards
	for i in range(4):
		all_ids.append("slash")
	for i in range(3):
		all_ids.append("block")
	for i in range(2):
		all_ids.append("heal")
	all_ids.append("draw")
	all_ids.append("discard")
	all_ids.append("gain_mana")

	# Character starting cards
	all_ids.append_array(starting_character.starting_card_ids)

	# Purchased cards
	all_ids.append_array(starting_character.purchased_card_ids)

	# Remove culled cards
	var removals = starting_character.removed_card_ids.duplicate()
	for removal_id in removals:
		var idx = all_ids.find(removal_id)
		if idx >= 0:
			all_ids.remove_at(idx)

	return all_ids

func _get_all_cards() -> Array[Card]:
	## Discovers all Card.create_* factory methods and returns one of each card.
	var cards: Array[Card] = []
	var card_script: Script = Card
	for method in card_script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("create_") and method["args"].size() == 0:
			var card = card_script.call(method_name)
			if card is Card:
				cards.append(card)
	# Sort by card type then name
	cards.sort_custom(func(a, b):
		if a.card_type_name != b.card_type_name:
			return a.card_type_name < b.card_type_name
		return a.card_name < b.card_name
	)
	return cards

func _create_card_from_id(card_id: String) -> Card:
	var card_script: Script = Card
	for method in card_script.get_script_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("create_") and method["args"].size() == 0:
			var card = card_script.call(method_name)
			if card is Card and card.card_id == card_id:
				return card
	return null

func _add_vendor_card_row(card: Card, is_sell: bool, sell_index: int = -1) -> void:
	var btn = Button.new()
	btn.custom_minimum_size.y = 40
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var prefix = "[SELL] " if is_sell else ""
	btn.text = "  %s%s   [%s]   %dM   %s" % [prefix, card.card_name, card.card_type_name, card.mana_cost, card.description]
	btn.add_theme_font_size_override("font_size", 13)

	# Style
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.12, 0.18, 0.9) if not is_sell else Color(0.18, 0.12, 0.12, 0.9)
	normal.border_width_bottom = 1
	normal.border_color = Color(0.25, 0.25, 0.3)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.2, 0.28, 0.95) if not is_sell else Color(0.28, 0.18, 0.18, 0.95)
	hover.border_width_bottom = 1
	hover.border_width_left = 2
	hover.border_color = Color(0.5, 0.45, 0.7) if not is_sell else Color(0.7, 0.4, 0.4)
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	btn.add_theme_stylebox_override("hover", hover)

	var type_color = _get_card_type_color(card)
	btn.add_theme_color_override("font_color", type_color)
	btn.add_theme_color_override("font_hover_color", type_color.lightened(0.2))

	if is_sell:
		btn.pressed.connect(_on_sell_card_clicked.bind(card, sell_index))
	else:
		btn.pressed.connect(_on_buy_card_clicked.bind(card))
	vendor_item_list.add_child(btn)

func _get_card_type_color(card: Card) -> Color:
	match card.card_type:
		Card.CardType.ATTACK: return Color(1.0, 0.6, 0.6)
		Card.CardType.DEFENSE: return Color(0.6, 0.8, 1.0)
		Card.CardType.UTILITY: return Color(0.6, 1.0, 0.6)
		Card.CardType.POWER: return Color(1.0, 0.8, 0.4)
		Card.CardType.REACTION: return Color(0.9, 0.6, 1.0)
		Card.CardType.ENCHANTMENT: return Color(0.2, 0.9, 0.8)
	return Color(0.8, 0.8, 0.8)

# ============================================
# SELL HELPERS
# ============================================

func _get_player_items_for_vendor(vendor_type: String) -> Array[Dictionary]:
	## Returns player's equipped items matching the vendor type.
	var result: Array[Dictionary] = []
	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return result

	var slot_types: Array = []
	match vendor_type:
		"armory":
			slot_types = [
				ItemData.ItemType.WEAPON, ItemData.ItemType.HELM,
				ItemData.ItemType.CHEST, ItemData.ItemType.GAUNTLETS
			]
		"accessory":
			slot_types = [
				ItemData.ItemType.RING, ItemData.ItemType.BELT,
				ItemData.ItemType.BOOTS, ItemData.ItemType.QUIVER
			]
		"blacksmith":
			slot_types = [
				ItemData.ItemType.WEAPON, ItemData.ItemType.HELM,
				ItemData.ItemType.CHEST, ItemData.ItemType.GAUNTLETS,
				ItemData.ItemType.RING, ItemData.ItemType.BELT,
				ItemData.ItemType.BOOTS, ItemData.ItemType.QUIVER
			]

	for slot_type in slot_types:
		var slot_array = inventory._get_slot_array(slot_type)
		for i in range(slot_array.size()):
			if slot_array[i] != null:
				result.append({"item": slot_array[i], "slot_type": slot_type, "slot_index": i})

	# Also include stored items
	for i in range(inventory.stored_items.size()):
		var item = inventory.stored_items[i]
		if item and item.item_type in slot_types:
			result.append({"item": item, "slot_type": -1, "slot_index": i})

	return result

func _add_section_separator(title: String) -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vendor_item_list.add_child(sep)

	var lbl = Label.new()
	lbl.text = "  — %s —" % title
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	vendor_item_list.add_child(lbl)

func _add_sell_item_row(item: ItemData, slot_type: int, slot_index: int) -> void:
	var btn = Button.new()
	btn.custom_minimum_size.y = 40
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var location = "equipped" if slot_type >= 0 else "stored"
	btn.text = "  [SELL] %s   [%s]   (%s)" % [item.item_name, item.get_type_name(), location]
	btn.add_theme_font_size_override("font_size", 13)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.12, 0.12, 0.9)
	normal.border_width_bottom = 1
	normal.border_color = Color(0.3, 0.2, 0.2)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.28, 0.18, 0.18, 0.95)
	hover.border_width_bottom = 1
	hover.border_width_left = 2
	hover.border_color = Color(0.7, 0.4, 0.4)
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.75))

	btn.pressed.connect(_on_sell_item_clicked.bind(item, slot_type, slot_index))
	vendor_item_list.add_child(btn)

# ============================================
# ITEM DETAIL MODAL
# ============================================

func _on_vendor_item_clicked(item: ItemData) -> void:
	_show_detail_modal(item)

func _show_detail_modal(item: ItemData, is_sell: bool = false, slot_type: int = -1, slot_index: int = -1) -> void:
	# Close existing modal if open
	if _detail_modal and is_instance_valid(_detail_modal):
		_detail_modal.queue_free()

	_detail_item = item
	_detail_card = null
	_detail_is_sell = is_sell
	_detail_sell_slot_type = slot_type
	_detail_sell_slot_index = slot_index
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

	var action_btn = Button.new()
	if is_sell:
		action_btn.text = "Sell"
		action_btn.custom_minimum_size = Vector2(120, 36)
		action_btn.add_theme_font_size_override("font_size", 16)
		_style_action_button(action_btn, Color(0.5, 0.2, 0.1), Color(0.65, 0.3, 0.15), Color(0.8, 0.4, 0.2))
		action_btn.pressed.connect(_on_sell_item_confirmed)
	else:
		action_btn.text = "Buy"
		action_btn.custom_minimum_size = Vector2(120, 36)
		action_btn.add_theme_font_size_override("font_size", 16)
		_style_action_button(action_btn, Color(0.15, 0.4, 0.15), Color(0.2, 0.55, 0.2), Color(0.3, 0.7, 0.3))
		action_btn.pressed.connect(_on_buy_pressed)
	btn_hbox.add_child(action_btn)

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
	_detail_card = null
	_detail_is_sell = false
	_detail_sell_slot_type = -1
	_detail_sell_slot_index = -1
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
	_refresh_vendor_panel()

func _on_sell_item_clicked(item: ItemData, slot_type: int, slot_index: int) -> void:
	_show_detail_modal(item, true, slot_type, slot_index)

func _on_sell_item_confirmed() -> void:
	if not _detail_item:
		_close_detail_modal()
		return

	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		_close_detail_modal()
		return

	if _detail_sell_slot_type >= 0:
		# Equipped item — unequip it
		inventory.unequip_item(_detail_sell_slot_type, _detail_sell_slot_index)
		print("[TOWN] Sold equipped item: %s" % _detail_item.item_name)
	else:
		# Stored item — remove from storage
		inventory.remove_stored_item(_detail_sell_slot_index)
		print("[TOWN] Sold stored item: %s" % _detail_item.item_name)

	_close_detail_modal()
	_refresh_vendor_panel()

func _on_buy_card_clicked(card: Card) -> void:
	_show_card_detail_modal(card, false)

func _on_sell_card_clicked(card: Card, sell_index: int) -> void:
	_show_card_detail_modal(card, true, sell_index)

func _show_card_detail_modal(card: Card, is_sell: bool, sell_index: int = -1) -> void:
	if _detail_modal and is_instance_valid(_detail_modal):
		_detail_modal.queue_free()

	_detail_card = card
	_detail_item = null
	_detail_is_sell = is_sell
	_detail_sell_slot_index = sell_index
	_modal_open = true

	# --- Dimmed background overlay ---
	var overlay = ColorRect.new()
	overlay.name = "ModalOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_input)

	# --- Modal panel ---
	_detail_modal = PanelContainer.new()
	_detail_modal.custom_minimum_size = Vector2(420, 0)
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

	# --- Card name ---
	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", _get_card_type_color(card))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# --- Card type + cost ---
	var type_lbl = Label.new()
	type_lbl.text = "%s  |  %d Mana  |  %d Tempo" % [card.card_type_name, card.mana_cost, card.tempo_cost]
	type_lbl.add_theme_font_size_override("font_size", 14)
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_lbl)

	vbox.add_child(HSeparator.new())

	# --- Description ---
	var desc_lbl = Label.new()
	desc_lbl.text = card.description
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_lbl)

	# --- Extra info ---
	var extras: Array[String] = []
	if card.is_ranged:
		extras.append("Ranged (range %d)" % (5 + card.range_modifier))
	if card.is_aoe:
		extras.append("AOE: %s" % card.aoe_shape)
	if card.sticky > 0:
		extras.append("Sticky (%d uses)" % card.sticky)
	if card.maintain_cost > 0:
		extras.append("Maintain: %d mana" % card.maintain_cost)
	if card.card_keyword != Card.CardKeyword.NONE:
		var kw_names = {1: "Arrow", 2: "Pocket", 3: "Gem"}
		extras.append("Keyword: %s" % kw_names.get(card.card_keyword, "Unknown"))
	if extras.size() > 0:
		var extra_lbl = Label.new()
		extra_lbl.text = "\n".join(extras)
		extra_lbl.add_theme_font_size_override("font_size", 13)
		extra_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		extra_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(extra_lbl)

	vbox.add_child(HSeparator.new())

	# --- Buttons ---
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)

	var action_btn = Button.new()
	if is_sell:
		var inv = player.get_inventory() if player.has_method("get_inventory") else null
		var stones = inv.get_culling_stone_count() if inv else 0
		action_btn.text = "Cull from Deck (1 Stone)"
		action_btn.custom_minimum_size = Vector2(200, 36)
		action_btn.add_theme_font_size_override("font_size", 14)
		if stones > 0:
			_style_action_button(action_btn, Color(0.5, 0.2, 0.1), Color(0.65, 0.3, 0.15), Color(0.8, 0.4, 0.2))
		else:
			_style_action_button(action_btn, Color(0.2, 0.2, 0.2), Color(0.25, 0.25, 0.25), Color(0.3, 0.3, 0.3))
			action_btn.disabled = true
		action_btn.pressed.connect(_on_sell_card_confirmed)
	else:
		action_btn.text = "Add to Deck"
		action_btn.custom_minimum_size = Vector2(140, 36)
		action_btn.add_theme_font_size_override("font_size", 14)
		_style_action_button(action_btn, Color(0.15, 0.4, 0.15), Color(0.2, 0.55, 0.2), Color(0.3, 0.7, 0.3))
		action_btn.pressed.connect(_on_buy_card_confirmed)
	btn_hbox.add_child(action_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 36)
	close_btn.add_theme_font_size_override("font_size", 14)
	_style_action_button(close_btn, Color(0.3, 0.15, 0.15), Color(0.45, 0.2, 0.2), Color(0.6, 0.3, 0.3))
	close_btn.pressed.connect(_close_detail_modal)
	btn_hbox.add_child(close_btn)

	vbox.add_child(btn_hbox)

	$UI.add_child(overlay)
	$UI.add_child(_detail_modal)

func _on_buy_card_confirmed() -> void:
	if not _detail_card or not starting_character:
		_close_detail_modal()
		return

	starting_character.purchased_card_ids.append(_detail_card.card_id)
	print("[TOWN] Added %s to deck (purchased_card_ids: %d)" % [_detail_card.card_name, starting_character.purchased_card_ids.size()])
	_close_detail_modal()
	_refresh_vendor_panel()

func _on_sell_card_confirmed() -> void:
	if not starting_character or _detail_sell_slot_index < 0 or not _detail_card:
		_close_detail_modal()
		return

	# Require a culling stone
	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory or not inventory.use_culling_stone():
		print("[TOWN] No culling stones! Cannot remove card from deck.")
		_close_detail_modal()
		return

	# Get the card_id from the deck list at this index
	var deck_ids = _get_current_deck_card_ids()
	if _detail_sell_slot_index >= deck_ids.size():
		_close_detail_modal()
		return

	var card_id = deck_ids[_detail_sell_slot_index]

	# Try to remove from purchased_card_ids first
	var purchased_idx = starting_character.purchased_card_ids.find(card_id)
	if purchased_idx >= 0:
		starting_character.purchased_card_ids.remove_at(purchased_idx)
		print("[TOWN] Culled purchased card: %s" % card_id)
	else:
		# It's a base or starting card — track as a removal
		starting_character.removed_card_ids.append(card_id)
		print("[TOWN] Culled base/starting card: %s (removals: %d)" % [card_id, starting_character.removed_card_ids.size()])

	_close_detail_modal()
	_refresh_vendor_panel()

func _refresh_vendor_panel() -> void:
	## Re-opens the current vendor to refresh the item list after buy/sell.
	if not vendor_open or not nearby_vendor:
		return
	# Re-populate by closing and re-opening
	vendor_panel.visible = false
	vendor_open = false
	_open_vendor(nearby_vendor)

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

func _create_olorin_npc() -> void:
	var olorin = StaticBody3D.new()
	olorin.name = "Olorin"
	olorin.position = Vector3(14, 0, 8)

	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.4, 1.8, 1.4)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.2, 0.5)  # Purple robe
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh.material_override = mat
	mesh.position = Vector3(0, 0.9, 0)
	olorin.add_child(mesh)

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.4, 1.8, 1.4)
	collision.shape = shape
	collision.position = Vector3(0, 0.9, 0)
	olorin.add_child(collision)

	var label = Label3D.new()
	label.text = "OLORIN"
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.8, 0.6, 1.0)
	label.outline_size = 8
	label.position = Vector3(0, 2.2, 0)
	olorin.add_child(label)

	# Quest indicator
	var quest_indicator = Label3D.new()
	quest_indicator.name = "QuestIndicator"
	quest_indicator.text = "!"
	quest_indicator.font_size = 40
	quest_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	quest_indicator.modulate = Color(1.0, 0.85, 0.0)
	quest_indicator.outline_size = 12
	quest_indicator.position = Vector3(0, 2.8, 0)
	olorin.add_child(quest_indicator)

	$Vendors.add_child(olorin)
	print("[TOWN] Created Olorin NPC at position %s" % olorin.position)

func _create_town_waypoint() -> void:
	## Creates a waypoint portal in town that takes the player back to battle.
	_town_waypoint_node = Node3D.new()
	_town_waypoint_node.name = "BattleWaypoint"

	# Glowing pillar (green to match dungeon world portals)
	var pillar = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.4
	cyl.height = 2.0
	pillar.mesh = cyl
	var pillar_mat = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.3, 1.0, 0.4, 1.0)
	pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar_mat.emission_enabled = true
	pillar_mat.emission = Color(0.3, 1.0, 0.4)
	pillar_mat.emission_energy_multiplier = 0.5
	pillar.material_override = pillar_mat
	pillar.position = Vector3(0, 1.0, 0)
	_town_waypoint_node.add_child(pillar)

	# Name label
	var label = Label3D.new()
	label.text = "Battle Portal"
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.3, 1.0, 0.5)
	label.position = Vector3(0, 2.5, 0)
	_town_waypoint_node.add_child(label)

	# Interact label
	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Enter Dungeon"
	interact_label.font_size = 16
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 3.0, 0)
	interact_label.visible = false
	_town_waypoint_node.add_child(interact_label)

	# Position near the town entrance area
	_town_waypoint_node.position = Vector3(4, 0, 10)
	add_child(_town_waypoint_node)
	print("[TOWN] Created battle waypoint portal")

func _open_quest_dialog(vendor_node: StaticBody3D) -> void:
	var info = vendor_info.get(vendor_node.name, null)
	if not info:
		return

	vendor_open = true
	_current_vendor_type = info["type"]
	vendor_name_label.text = info["name"]

	# Clear old items from list
	for child in vendor_item_list.get_children():
		child.queue_free()

	vendor_inventory_label.text = info["description"]

	# Check for turnable quests
	if quest_manager.has_complete_quest_for("Olorin"):
		var quest = quest_manager.get_turnable_quest_for("Olorin")
		if quest:
			_add_info_label("Quest Complete: %s" % quest.name, Color(0.5, 1.0, 0.5))
			var turn_in_btn = Button.new()
			turn_in_btn.text = "Turn In Quest"
			turn_in_btn.custom_minimum_size = Vector2(200, 40)
			turn_in_btn.add_theme_font_size_override("font_size", 16)
			turn_in_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			turn_in_btn.pressed.connect(_on_turn_in_quest.bind(quest.id))
			vendor_item_list.add_child(turn_in_btn)

	# Check for available quests
	elif not quest_manager.has_active_quest_from("Olorin"):
		var available = quest_manager.get_available_quests_from("Olorin")
		for quest in available:
			_add_info_label(quest.name, Color(1.0, 0.85, 0.3))
			var desc_lbl = Label.new()
			desc_lbl.text = "  %s" % quest.description
			desc_lbl.add_theme_font_size_override("font_size", 13)
			desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vendor_item_list.add_child(desc_lbl)

			var obj_lbl = Label.new()
			obj_lbl.text = "  Objective: %s" % quest.get_objective_text()
			obj_lbl.add_theme_font_size_override("font_size", 13)
			obj_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
			vendor_item_list.add_child(obj_lbl)

			var reward_text = "  Rewards:"
			if quest.rewards.has("gold"):
				reward_text += " %d Gold" % quest.rewards["gold"]
			if quest.rewards.has("xp"):
				reward_text += ", %d XP" % quest.rewards["xp"]
			var reward_lbl = Label.new()
			reward_lbl.text = reward_text
			reward_lbl.add_theme_font_size_override("font_size", 13)
			reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			vendor_item_list.add_child(reward_lbl)

			var accept_btn = Button.new()
			accept_btn.text = "Accept Quest"
			accept_btn.custom_minimum_size = Vector2(200, 40)
			accept_btn.add_theme_font_size_override("font_size", 16)
			accept_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			accept_btn.pressed.connect(_on_accept_quest.bind(quest.id))
			vendor_item_list.add_child(accept_btn)
	else:
		# Quest is active but not complete — show progress
		for quest in quest_manager.get_active_quests():
			if quest.giver == "Olorin":
				_add_info_label(quest.name, Color(0.5, 1.0, 0.5))
				var progress_lbl = Label.new()
				progress_lbl.text = "  %s" % quest.get_objective_text()
				progress_lbl.add_theme_font_size_override("font_size", 14)
				progress_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
				vendor_item_list.add_child(progress_lbl)

				var accepted_lbl = Label.new()
				accepted_lbl.text = "Accepted"
				accepted_lbl.add_theme_font_size_override("font_size", 16)
				accepted_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
				vendor_item_list.add_child(accepted_lbl)
				break

	vendor_panel.visible = true
	interact_prompt.text = ""
	print("[TOWN] Opened quest dialog with Olorin")

func _on_accept_quest(quest_id: String) -> void:
	if quest_manager.accept_quest(quest_id):
		print("[TOWN] Quest accepted: %s" % quest_id)
		# Refresh the dialog to show "Accepted" state instead of closing
		_refresh_quest_dialog_after_accept(quest_id)

func _refresh_quest_dialog_after_accept(_quest_id: String) -> void:
	## Replace the accept button with a green "Accepted" label in the current dialog.
	# Find and remove the accept button, replace with accepted label
	for child in vendor_item_list.get_children():
		if child is Button and child.text == "Accept Quest":
			var accepted_lbl = Label.new()
			accepted_lbl.text = "Accepted"
			accepted_lbl.add_theme_font_size_override("font_size", 16)
			accepted_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			vendor_item_list.add_child(accepted_lbl)
			child.queue_free()
			break

func _on_turn_in_quest(quest_id: String) -> void:
	var rewards = quest_manager.turn_in_quest(quest_id)
	if rewards.is_empty():
		return

	# Apply rewards
	var stats = player.get_stats() if player.has_method("get_stats") else null
	if stats:
		if rewards.has("gold"):
			stats.gain_gold(rewards["gold"])
		if rewards.has("xp"):
			stats.gain_xp(rewards["xp"])

	print("[TOWN] Quest turned in! Rewards: %s" % rewards)
	_close_vendor()

func _on_back_pressed() -> void:
	if vendor_open:
		_close_vendor()
	var title_scene = load("res://scenes/title_menu.tscn").instantiate()
	get_tree().root.add_child(title_scene)
	queue_free()

func _close_vendor() -> void:
	vendor_open = false
	vendor_panel.visible = false
	print("[TOWN] Closed vendor")

func _go_to_battle() -> void:
	if vendor_open:
		_close_vendor()

	print("[TOWN] Heading to battle!")
	var saved_quest_state = quest_manager.save_state() if quest_manager else {}
	var main_scene = load("res://main.tscn").instantiate()
	main_scene.starting_character = starting_character
	main_scene.discovered_waypoints = discovered_waypoints
	main_scene.quest_state = saved_quest_state
	get_tree().root.add_child(main_scene)
	queue_free()
