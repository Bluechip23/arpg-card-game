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
var player2_character: CharacterData = null  # Persistent co-op partner (recruited at the Sellsword)
var discovered_waypoints: Array = []
var quest_state: Dictionary = {}
var player_progression: Dictionary = {}
var opened_chests: Dictionary = {}
var return_world_level: int = 1  # World to return to when leaving town
var nearby_vendor: StaticBody3D = null
var vendor_open: bool = false
var quest_manager: QuestManager = null
var _quest_panel: PanelContainer = null
var _quest_panel_open: bool = false
var _town_waypoint_node: Node3D = null
# Return Scroll: the twin of a portal opened out in the world. Stepping through
# it returns the player to the exact spot where they set it.
var portal_return: Dictionary = {}
var _return_portal_node: Node3D = null
var _near_return_portal: bool = false
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
var _current_vendor_node: StaticBody3D = null

# Blacksmith forge state: the first mythic clicked for molding (a second
# click on another mythic completes the mold).
var _mold_selection: ItemData = null

# Stash UI state
var _stash_panel: PanelContainer = null
var _stash_open: bool = false
var _stash_inventory_list: VBoxContainer = null
var _stash_stash_list: VBoxContainer = null
var _stash_inv_count_label: Label = null
var _stash_stash_count_label: Label = null
var _stash_message_label: Label = null
var _stash_message_timer: float = 0.0

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
	},
	"Sellsword": {
		"name": "Sellsword",
		"description": "Hire a battle-partner. They fight alongside you — switch control with TAB.",
		"type": "sellsword"
	},
	"TownHall": {
		"name": "Town Hall",
		"description": "The heart of the city. Raise buildings with the resources you send home.",
		"type": "town_hall"
	}
}

func _ready() -> void:
	_unify_town_style()
	player.set_grid_manager(grid_manager)

	# The Return Scroll's twin portal shimmers beside the arrival spot.
	if not portal_return.is_empty():
		_spawn_return_portal()

	if starting_character:
		player.initialize_character(starting_character)
		print("[TOWN] Character loaded: %s" % starting_character.character_name)

	# Restore player progression from world transition (level, stats, passives, etc.)
	if not player_progression.is_empty():
		var stats = player.get_stats()
		if stats and player_progression.has("stats"):
			stats.restore_progression(player_progression["stats"])
			print("[TOWN] Restored progression: Level %d" % stats.current_level)

		# Restore equipped and stored items (inventory, stash, equipment)
		if player_progression.has("inventory"):
			var inv = player.get_inventory() if player.has_method("get_inventory") else null
			var inv_data = player_progression["inventory"]
			if inv:
				inv.equipped_helms = inv_data.get("equipped_helms", inv.equipped_helms)
				inv.equipped_chests = inv_data.get("equipped_chests", inv.equipped_chests)
				inv.equipped_rings = inv_data.get("equipped_rings", inv.equipped_rings)
				inv.equipped_belts = inv_data.get("equipped_belts", inv.equipped_belts)
				inv.equipped_boots = inv_data.get("equipped_boots", inv.equipped_boots)
				inv.equipped_gauntlets = inv_data.get("equipped_gauntlets", inv.equipped_gauntlets)
				inv.equipped_weapons = inv_data.get("equipped_weapons", inv.equipped_weapons)
				inv.stored_items = inv_data.get("stored_items", inv.stored_items)
				inv.stored_cards = inv_data.get("stored_cards", inv.stored_cards)
				inv.stash_items = inv_data.get("stash_items", inv.stash_items)
				inv.culling_stones = inv_data.get("culling_stones", inv.culling_stones)
				inv.mythic_molds = inv_data.get("mythic_molds", inv.mythic_molds)
				inv.equipment_changed.emit()
				print("[TOWN] Restored inventory: %d stored items, %d stash items" % [inv.stored_items.size(), inv.stash_items.size()])

	_apply_styles()

	vendor_close_button.pressed.connect(_close_vendor)
	fight_button.pressed.connect(_go_to_battle)
	back_button.pressed.connect(_on_back_pressed)
	_setup_save_button()

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

	# Create the Sellsword co-op recruiter NPC
	_create_sellsword_npc()

	# The Town Hall — the city loop's front door
	_create_town_hall_npc()

	# Create transport portal
	_create_town_waypoint()

	# Dress the plaza: market stalls over the vendor markers, lamps, props
	_dress_town()

	# Initialize camera
	_camera_focus = player.position + Vector3(3, 0, 0)
	_update_camera()

	# Coming home: bank the satchel, weather any struck calamity, first-time
	# flute hand-off. Shown as a notice overlay once the town is up.
	_arrive_home()

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
	# Orthographic, frame-matched to the zoom distance (16-bit pass, same
	# treatment as the world camera in main).
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0 * _camera_distance * tan(deg_to_rad(75.0) * 0.5) * 0.62

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
	# Fade out stash message
	if _stash_message_timer > 0:
		_stash_message_timer -= _delta
		if _stash_message_timer <= 0 and _stash_message_label and is_instance_valid(_stash_message_label):
			_stash_message_label.text = ""

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

	# Check proximity to the Return Scroll's twin portal
	_near_return_portal = false
	if is_instance_valid(_return_portal_node):
		if player.position.distance_to(_return_portal_node.position) < INTERACT_DISTANCE:
			_near_return_portal = true

	if _near_return_portal:
		interact_prompt.text = "Press [Shift] to step back through your portal"
	elif _near_town_waypoint:
		interact_prompt.text = "Press [Shift] to use Transport Portal"
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
				if _modal_open or vendor_open or _stash_open:
					return
				if _near_return_portal:
					_go_to_battle(true)
					return
				if _near_town_waypoint:
					_go_to_battle()
					return
				if nearby_vendor:
					_open_vendor(nearby_vendor)
			KEY_ESCAPE:
				if _modal_open:
					_close_detail_modal()
				elif _stash_open:
					_close_stash_ui()
				elif vendor_open:
					_close_vendor()
			KEY_COMMA:
				_camera_distance = max(CAMERA_ZOOM_MIN, _camera_distance - CAMERA_ZOOM_STEP)
				_update_camera()
			KEY_PERIOD:
				_camera_distance = min(CAMERA_ZOOM_MAX, _camera_distance + CAMERA_ZOOM_STEP)
				_update_camera()
			KEY_W:
				_wasd_step(Vector2(0, 1))
			KEY_S:
				_wasd_step(Vector2(0, -1))
			KEY_A:
				_wasd_step(Vector2(-1, 0))
			KEY_D:
				_wasd_step(Vector2(1, 0))

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
		if vendor_open or _stash_open:
			return
		var mouse_pos = _get_mouse_world_position()
		if mouse_pos != Vector3.ZERO:
			var distance = _get_grid_distance(player.position, mouse_pos)
			player.move_to_grid(mouse_pos, max(1, distance))

func _wasd_step(dir: Vector2) -> void:
	## Step the player one grid cell in a camera-relative direction (same short
	## hop as battle WASD): (0,1)=W, (0,-1)=S, (-1,0)=A, (1,0)=D. Snapped to the
	## nearest cardinal grid axis. Right-click still handles longer walks.
	if _modal_open or vendor_open or _stash_open:
		return
	if player == null or not is_instance_valid(player) or player.is_moving:
		return
	if not grid_manager:
		return

	var forward := Vector2(-sin(_camera_yaw), -cos(_camera_yaw))  # (x, z) camera faces
	var right := Vector2(-forward.y, forward.x)
	var world_dir := right * dir.x + forward * dir.y

	var cell_delta: Vector2i
	if absf(world_dir.x) >= absf(world_dir.y):
		cell_delta = Vector2i(int(signf(world_dir.x)), 0)
	else:
		cell_delta = Vector2i(0, int(signf(world_dir.y)))
	if cell_delta == Vector2i.ZERO:
		return

	var target_cell := grid_manager.world_to_grid(player.position) + cell_delta
	player.move_to_grid(grid_manager.grid_to_world(target_cell), 1)

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
			items.append(ItemData.create_wooden_sword())
			items.append(ItemData.create_frost_orb())
		"accessory":
			# No accessory items exist right now — the shelf stands empty
			# until new accessories are added to ItemData.
			pass
	return items

func _open_vendor(vendor_node: StaticBody3D) -> void:
	var info = vendor_info.get(vendor_node.name, null)
	if not info:
		return

	vendor_open = true
	_current_vendor_type = info["type"]
	_current_vendor_node = vendor_node
	_mold_selection = null
	vendor_name_label.text = info["name"]

	# Clear old items from list
	for child in vendor_item_list.get_children():
		child.queue_free()

	vendor_inventory_label.text = info["description"]

	if info["type"] == "quest_giver":
		_open_quest_dialog(vendor_node)
		return

	if info["type"] == "stash":
		_open_stash_ui()
		return

	if info["type"] == "sellsword":
		_open_sellsword_ui()
		vendor_panel.visible = true
		interact_prompt.text = ""
		return

	if info["type"] == "town_hall":
		_open_town_hall_ui()
		vendor_panel.visible = true
		interact_prompt.text = ""
		return

	if info["type"] == "card_dealer":
		# Show culling stone and paper feather counts
		var inventory = player.get_inventory() if player.has_method("get_inventory") else null
		var stones = inventory.get_culling_stone_count() if inventory else 0
		var feathers = inventory.get_paper_feather_count() if inventory else 0
		_add_info_label("Culling Stones: %d" % stones, Color(0.8, 0.5, 1.0))
		_add_info_label("Paper Feathers: %d" % feathers, Color(1.0, 0.85, 0.4))

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
		# Blacksmith: the Forge — level up items with spare copies, mold mythics
		if info["type"] == "blacksmith":
			_populate_blacksmith_forge()

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
	btn.text = "  %s   [%s %s]   %s" % [item.item_name, item.get_rarity_name(), item.get_type_name(), item.description]
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

	# Base cards — the same basic deck every character starts with (must match
	# DeckManager._create_default_deck).
	for i in range(4):
		all_ids.append("slash")
	for i in range(4):
		all_ids.append("block")
	all_ids.append("draw")
	all_ids.append("gain_mana")
	all_ids.append("heal")

	# Character-specific starting cards are no longer part of the deck.

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
			if card is Card and not card.shop_excluded:
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
	btn.text = "  %s%s   [%s]   %dM %dT   %s" % [prefix, card.card_name, card.card_type_name, card.mana_cost, card.tempo_cost, card.description]
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
	btn.text = "  [SELL] %s   [%s %s]   (%s)" % [item.get_display_name(), item.get_rarity_name(), item.get_type_name(), location]
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
# BLACKSMITH FORGE UI
# ============================================

func _populate_blacksmith_forge() -> void:
	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return

	_add_info_label("Mythic Molds: %d" % inventory.get_mythic_mold_count(), Color(0.9, 0.35, 0.9))

	# Sync ownership history up front, so mythics the player is about to meld
	# down are remembered as owned (and stay redeemable) first.
	var owned_mythics: Array = _get_owned_mythic_names(inventory)

	# --- Forge upgrades ---
	_add_section_separator("Forge — combine copies to level up an item")
	var candidates = ItemForge.get_forge_candidates(inventory)
	if candidates.is_empty():
		_add_info_label("No upgradable items in your inventory or stash.", Color(0.6, 0.6, 0.7))
		_add_info_label("(Items must be unequipped. Only spare level-1 copies count.)", Color(0.5, 0.5, 0.6))
	for entry in candidates:
		_add_forge_row(entry["item"], entry["copies_have"], entry["copies_needed"])

	# --- Mythic molding ---
	var moldable = ItemForge.get_moldable_mythics(inventory)
	if moldable.size() > 0:
		_add_section_separator("Mythic Molding — melt 2 mythics into a Mythic Mold")
		_add_info_label("Click two mythics to mold them down.", Color(0.6, 0.6, 0.7))
		for item in moldable:
			_add_mold_row(item)

	# --- Redeem molds (only mythics the character has owned) ---
	if inventory.get_mythic_mold_count() > 0:
		_add_section_separator("Redeem a Mythic Mold — pick a mythic you've owned")
		var any_redeemable := false
		for item in ItemData.get_items_of_rarity(ItemData.Rarity.MYTHIC):
			if owned_mythics.has(item.item_name):
				_add_mold_redeem_row(item)
				any_redeemable = true
		if not any_redeemable:
			_add_info_label("The mold waits — find a mythic first, and I can recreate it.", Color(0.6, 0.6, 0.7))

func _add_forge_row(item: ItemData, have: int, needed: int) -> void:
	var btn = Button.new()
	btn.custom_minimum_size.y = 40
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var ready = have >= needed
	btn.text = "  %s   [%s %s]   Lv.%d → Lv.%d   copies: %d/%d%s" % [
		item.get_display_name(), item.get_rarity_name(), item.get_type_name(),
		item.item_level, item.item_level + 1, have, needed,
		"   FORGE!" if ready else ""]
	btn.add_theme_font_size_override("font_size", 13)
	btn.disabled = not ready
	_style_forge_button(btn, item.get_rarity_color())
	btn.pressed.connect(_on_forge_item_clicked.bind(item))
	vendor_item_list.add_child(btn)

func _add_mold_row(item: ItemData) -> void:
	var btn = Button.new()
	btn.custom_minimum_size.y = 40
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var selected = item == _mold_selection
	btn.text = "  %s   [Mythic %s]%s" % [
		item.get_display_name(), item.get_type_name(),
		"   [SELECTED — click another mythic]" if selected else ""]
	btn.add_theme_font_size_override("font_size", 13)
	_style_forge_button(btn, Color(0.9, 0.35, 0.9))
	btn.pressed.connect(_on_mold_mythic_clicked.bind(item))
	vendor_item_list.add_child(btn)

func _add_mold_redeem_row(item: ItemData) -> void:
	var btn = Button.new()
	btn.custom_minimum_size.y = 40
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "  Craft: %s   [%s]   %s" % [item.item_name, item.get_type_name(), item.description]
	btn.add_theme_font_size_override("font_size", 13)
	_style_forge_button(btn, Color(1.0, 0.8, 0.3))
	btn.pressed.connect(_on_redeem_mold_clicked.bind(item.item_name))
	vendor_item_list.add_child(btn)

func _style_forge_button(btn: Button, accent: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.13, 0.17, 0.9)
	normal.border_width_bottom = 1
	normal.border_width_left = 2
	normal.border_color = accent.darkened(0.3)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.2, 0.28, 0.95)
	hover.border_width_bottom = 1
	hover.border_width_left = 2
	hover.border_color = accent
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", accent.lightened(0.25))
	btn.add_theme_color_override("font_hover_color", accent.lightened(0.45))
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.5))

func _refresh_blacksmith() -> void:
	## Rebuild the blacksmith panel in place (keeps _mold_selection intact).
	for child in vendor_item_list.get_children():
		child.queue_free()
	_populate_blacksmith_forge()
	var sell_items = _get_player_items_for_vendor("blacksmith")
	if sell_items.size() > 0:
		_add_section_separator("Your Equipment")
		for entry in sell_items:
			_add_sell_item_row(entry["item"], entry["slot_type"], entry["slot_index"])

func _on_forge_item_clicked(item: ItemData) -> void:
	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return
	if ItemForge.forge(inventory, item):
		print("[TOWN] Forged %s to Lv.%d" % [item.item_name, item.item_level])
	_refresh_blacksmith()

func _on_mold_mythic_clicked(item: ItemData) -> void:
	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return
	if _mold_selection == null:
		_mold_selection = item
	elif _mold_selection == item:
		_mold_selection = null  # clicked again — deselect
	else:
		ItemForge.mold_mythics(inventory, _mold_selection, item)
		_mold_selection = null
	_refresh_blacksmith()

func _on_redeem_mold_clicked(mythic_name: String) -> void:
	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return
	ItemForge.redeem_mold(inventory, mythic_name, _get_owned_mythic_names(inventory))
	_refresh_blacksmith()

## The character's mythic ownership history (what molds can recreate),
## self-healed with anything currently held so items acquired before the
## tracking existed still count.
func _get_owned_mythic_names(inventory) -> Array:
	var names: Array = starting_character.owned_mythic_names if starting_character else []
	var all_lists = [
		inventory.stored_items, inventory.stash_items,
		inventory.equipped_helms, inventory.equipped_chests, inventory.equipped_rings,
		inventory.equipped_belts, inventory.equipped_boots, inventory.equipped_gauntlets,
		inventory.equipped_weapons,
	]
	for list in all_lists:
		for item in list:
			if item and item.rarity == ItemData.Rarity.MYTHIC and not names.has(item.item_name):
				names.append(item.item_name)
	return names

# ============================================
# STASH UI
# ============================================

func _open_stash_ui() -> void:
	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return

	_stash_open = true
	vendor_open = true

	# Fullscreen overlay
	var overlay = ColorRect.new()
	overlay.name = "StashOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Main stash panel
	_stash_panel = PanelContainer.new()
	_stash_panel.name = "StashPanel"
	_stash_panel.set_anchors_preset(Control.PRESET_CENTER)
	_stash_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stash_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_stash_panel.custom_minimum_size = Vector2(820, 500)

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
	_stash_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_stash_panel.add_child(margin)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(outer_vbox)

	# Title row
	var title_hbox = HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var title_lbl = Label.new()
	title_lbl.text = "Stash"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title_hbox.add_child(title_lbl)
	outer_vbox.add_child(title_hbox)

	# Instruction label
	var hint_lbl = Label.new()
	hint_lbl.text = "Right-click items to transfer between inventory and stash"
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(hint_lbl)

	# Message label for "Inventory is full" etc.
	_stash_message_label = Label.new()
	_stash_message_label.text = ""
	_stash_message_label.add_theme_font_size_override("font_size", 15)
	_stash_message_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_stash_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(_stash_message_label)

	outer_vbox.add_child(HSeparator.new())

	# Two columns: Inventory (left) | Stash (right)
	var columns_hbox = HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 16)
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# --- Left column: Inventory ---
	var inv_vbox = VBoxContainer.new()
	inv_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_stash_inv_count_label = Label.new()
	_stash_inv_count_label.add_theme_font_size_override("font_size", 15)
	_stash_inv_count_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	inv_vbox.add_child(_stash_inv_count_label)

	var inv_scroll = ScrollContainer.new()
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_scroll.custom_minimum_size = Vector2(380, 350)
	_stash_inventory_list = VBoxContainer.new()
	_stash_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_scroll.add_child(_stash_inventory_list)
	inv_vbox.add_child(inv_scroll)
	columns_hbox.add_child(inv_vbox)

	# Vertical separator
	var vsep = VSeparator.new()
	columns_hbox.add_child(vsep)

	# --- Right column: Stash ---
	var stash_vbox = VBoxContainer.new()
	stash_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_stash_stash_count_label = Label.new()
	_stash_stash_count_label.add_theme_font_size_override("font_size", 15)
	_stash_stash_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	stash_vbox.add_child(_stash_stash_count_label)

	var stash_scroll = ScrollContainer.new()
	stash_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stash_scroll.custom_minimum_size = Vector2(380, 350)
	_stash_stash_list = VBoxContainer.new()
	_stash_stash_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stash_scroll.add_child(_stash_stash_list)
	stash_vbox.add_child(stash_scroll)
	columns_hbox.add_child(stash_vbox)

	outer_vbox.add_child(columns_hbox)

	# Close button
	var close_hbox = HBoxContainer.new()
	close_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.add_theme_font_size_override("font_size", 15)
	_style_action_button(close_btn, Color(0.3, 0.15, 0.15), Color(0.45, 0.2, 0.2), Color(0.6, 0.3, 0.3))
	close_btn.pressed.connect(_close_stash_ui)
	close_hbox.add_child(close_btn)
	outer_vbox.add_child(close_hbox)

	$UI.add_child(overlay)
	$UI.add_child(_stash_panel)

	_refresh_stash_lists()
	vendor_panel.visible = false
	interact_prompt.text = ""
	print("[TOWN] Opened stash")

func _close_stash_ui() -> void:
	_stash_open = false
	vendor_open = false
	_stash_message_timer = 0.0

	var overlay = $UI.get_node_or_null("StashOverlay")
	if overlay:
		overlay.queue_free()
	if _stash_panel and is_instance_valid(_stash_panel):
		_stash_panel.queue_free()
		_stash_panel = null

	_stash_inventory_list = null
	_stash_stash_list = null
	_stash_inv_count_label = null
	_stash_stash_count_label = null
	_stash_message_label = null
	print("[TOWN] Closed stash")

func _refresh_stash_lists() -> void:
	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return

	# Update count labels
	if _stash_inv_count_label and is_instance_valid(_stash_inv_count_label):
		_stash_inv_count_label.text = "Inventory (%d/%d)" % [inventory.used_storage_slots(), inventory.max_storage_slots]
	if _stash_stash_count_label and is_instance_valid(_stash_stash_count_label):
		_stash_stash_count_label.text = "Stash (%d/%d)" % [inventory.stash_items.size(), inventory.max_stash_slots]

	# Rebuild inventory list
	if _stash_inventory_list and is_instance_valid(_stash_inventory_list):
		for child in _stash_inventory_list.get_children():
			child.queue_free()
		for i in range(inventory.stored_items.size()):
			var item = inventory.stored_items[i]
			if item:
				_add_stash_item_row(_stash_inventory_list, item, i, true)
		if inventory.stored_items.size() == 0:
			var empty_lbl = Label.new()
			empty_lbl.text = "  (empty)"
			empty_lbl.add_theme_font_size_override("font_size", 13)
			empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			_stash_inventory_list.add_child(empty_lbl)

	# Rebuild stash list
	if _stash_stash_list and is_instance_valid(_stash_stash_list):
		for child in _stash_stash_list.get_children():
			child.queue_free()
		for i in range(inventory.stash_items.size()):
			var item = inventory.stash_items[i]
			if item:
				_add_stash_item_row(_stash_stash_list, item, i, false)
		if inventory.stash_items.size() == 0:
			var empty_lbl = Label.new()
			empty_lbl.text = "  (empty)"
			empty_lbl.add_theme_font_size_override("font_size", 13)
			empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			_stash_stash_list.add_child(empty_lbl)

func _add_stash_item_row(parent: VBoxContainer, item: ItemData, index: int, is_inventory_side: bool) -> void:
	var btn = Button.new()
	btn.custom_minimum_size.y = 36
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "  %s   [%s %s]" % [item.get_display_name(), item.get_rarity_name(), item.get_type_name()]
	btn.add_theme_font_size_override("font_size", 13)

	var bg_color = Color(0.13, 0.15, 0.2, 0.9) if is_inventory_side else Color(0.15, 0.13, 0.1, 0.9)
	var hover_color = Color(0.2, 0.22, 0.3, 0.95) if is_inventory_side else Color(0.25, 0.2, 0.15, 0.95)
	var border_color = Color(0.35, 0.4, 0.55) if is_inventory_side else Color(0.55, 0.45, 0.3)

	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_width_bottom = 1
	normal.border_color = Color(0.2, 0.2, 0.25)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = hover_color
	hover.border_width_bottom = 1
	hover.border_width_left = 2
	hover.border_color = border_color
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	btn.add_theme_stylebox_override("hover", hover)

	var name_color = _get_item_name_color(item)
	btn.add_theme_color_override("font_color", name_color)
	btn.add_theme_color_override("font_hover_color", name_color.lightened(0.2))

	# Right-click to transfer
	btn.gui_input.connect(_on_stash_item_input.bind(index, is_inventory_side))
	parent.add_child(btn)

func _on_stash_item_input(event: InputEvent, index: int, is_inventory_side: bool) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return

	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory:
		return

	if is_inventory_side:
		# Move from inventory to stash
		if inventory.is_stash_full():
			_show_stash_message("Stash is full!")
			return
		if inventory.move_inventory_to_stash(index):
			_refresh_stash_lists()
	else:
		# Move from stash to inventory
		if inventory.is_storage_full():
			_show_stash_message("Inventory is full!")
			return
		if inventory.move_stash_to_inventory(index):
			_refresh_stash_lists()

func _show_stash_message(msg: String) -> void:
	if _stash_message_label and is_instance_valid(_stash_message_label):
		_stash_message_label.text = msg
		_stash_message_timer = 2.0

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
	name_lbl.text = item.get_display_name()
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", item.get_rarity_color())
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# --- Item type ---
	var type_lbl = Label.new()
	type_lbl.text = "%s %s · Lv.%d/%d" % [item.get_rarity_name(), item.get_type_name(), item.item_level, item.get_max_level()]
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
	type_lbl.text = "%s  |  %dM %dT" % [card.card_type_name, card.mana_cost, card.tempo_cost]
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
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)

	if is_sell:
		var inv = player.get_inventory() if player.has_method("get_inventory") else null
		var stones = inv.get_culling_stone_count() if inv else 0

		# Use Culling Stone button
		var cull_btn = Button.new()
		cull_btn.text = "Use Culling Stone (%d)" % stones
		cull_btn.custom_minimum_size = Vector2(280, 36)
		cull_btn.add_theme_font_size_override("font_size", 14)
		if stones > 0:
			_style_action_button(cull_btn, Color(0.5, 0.2, 0.1), Color(0.65, 0.3, 0.15), Color(0.8, 0.4, 0.2))
		else:
			_style_action_button(cull_btn, Color(0.2, 0.2, 0.2), Color(0.25, 0.25, 0.25), Color(0.3, 0.3, 0.3))
			cull_btn.disabled = true
		cull_btn.pressed.connect(_on_cull_stone_clicked)
		btn_vbox.add_child(cull_btn)

		# Cancel button
		var close_btn = Button.new()
		close_btn.text = "Cancel"
		close_btn.custom_minimum_size = Vector2(280, 36)
		close_btn.add_theme_font_size_override("font_size", 14)
		_style_action_button(close_btn, Color(0.3, 0.15, 0.15), Color(0.45, 0.2, 0.2), Color(0.6, 0.3, 0.3))
		close_btn.pressed.connect(_close_detail_modal)
		btn_vbox.add_child(close_btn)
	else:
		var btn_hbox = HBoxContainer.new()
		btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_hbox.add_theme_constant_override("separation", 16)

		var action_btn = Button.new()
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

		btn_vbox.add_child(btn_hbox)

	vbox.add_child(btn_vbox)

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

# ============================================
# CULLING STONE CONFIRMATION
# ============================================

var _pending_cull_card: Card = null
var _pending_cull_index: int = -1

func _on_cull_stone_clicked() -> void:
	## Shows a confirmation modal before using a culling stone.
	_pending_cull_card = _detail_card
	_pending_cull_index = _detail_sell_slot_index
	_close_detail_modal()
	_show_confirm_modal(
		"Confirm Culling",
		"Are you sure you want to use a Culling Stone to permanently remove this card from your deck?",
		Color(0.8, 0.4, 0.2),
		_on_cull_stone_confirmed
	)

func _on_cull_stone_confirmed() -> void:
	if not starting_character or _pending_cull_index < 0 or not _pending_cull_card:
		_close_confirm_modal()
		return

	var inventory = player.get_inventory() if player.has_method("get_inventory") else null
	if not inventory or not inventory.use_culling_stone():
		print("[TOWN] No culling stones! Cannot remove card from deck.")
		_close_confirm_modal()
		return

	var deck_ids = _get_current_deck_card_ids()
	if _pending_cull_index >= deck_ids.size():
		_close_confirm_modal()
		return

	var card_id = deck_ids[_pending_cull_index]

	# Try to remove from purchased_card_ids first
	var purchased_idx = starting_character.purchased_card_ids.find(card_id)
	if purchased_idx >= 0:
		starting_character.purchased_card_ids.remove_at(purchased_idx)
		print("[TOWN] Culled purchased card: %s" % card_id)
	else:
		starting_character.removed_card_ids.append(card_id)
		print("[TOWN] Culled base/starting card: %s (removals: %d)" % [card_id, starting_character.removed_card_ids.size()])

	_pending_cull_card = null
	_pending_cull_index = -1

	_close_confirm_modal()
	_refresh_vendor_panel()

# ============================================
# GENERIC CONFIRM MODAL
# ============================================

var _confirm_modal: PanelContainer = null
var _confirm_callback: Callable

func _show_confirm_modal(title: String, message: String, accent_color: Color, on_confirm: Callable) -> void:
	_confirm_callback = on_confirm
	_modal_open = true

	var overlay = ColorRect.new()
	overlay.name = "ConfirmOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	_confirm_modal = PanelContainer.new()
	_confirm_modal.custom_minimum_size = Vector2(400, 0)
	_confirm_modal.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_modal.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = accent_color
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_confirm_modal.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_confirm_modal.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", accent_color)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var msg_lbl = Label.new()
	msg_lbl.text = message
	msg_lbl.add_theme_font_size_override("font_size", 14)
	msg_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg_lbl)

	vbox.add_child(HSeparator.new())

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(120, 36)
	confirm_btn.add_theme_font_size_override("font_size", 14)
	_style_action_button(confirm_btn, Color(0.15, 0.4, 0.15), Color(0.2, 0.55, 0.2), Color(0.3, 0.7, 0.3))
	confirm_btn.pressed.connect(on_confirm)
	btn_hbox.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	_style_action_button(cancel_btn, Color(0.3, 0.15, 0.15), Color(0.45, 0.2, 0.2), Color(0.6, 0.3, 0.3))
	cancel_btn.pressed.connect(_close_confirm_modal)
	btn_hbox.add_child(cancel_btn)

	vbox.add_child(btn_hbox)

	$UI.add_child(overlay)
	$UI.add_child(_confirm_modal)

func _close_confirm_modal() -> void:
	_modal_open = false
	_detail_card = null
	_detail_sell_slot_index = -1
	_pending_cull_card = null
	_pending_cull_index = -1
	var overlay = $UI.get_node_or_null("ConfirmOverlay")
	if overlay:
		overlay.queue_free()
	if _confirm_modal and is_instance_valid(_confirm_modal):
		_confirm_modal.queue_free()
		_confirm_modal = null

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

	# Weapon mastery breakpoint
	if item.has_mastery():
		lines.append("[%s]" % item.get_mastery_text())

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

# ============================================
# TOWN DRESSING (procedural plaza visuals)
# ============================================

func _unify_town_style() -> void:
	## Brings the town in line with the 16-bit world pass: orthographic
	## camera, flat high-ambient lighting without real-time shadows, flat
	## backdrop instead of a gradient sky, and a pixel-tiled plaza floor.
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = false
		sun.light_energy = 0.7
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = Color8(26, 28, 20)
		we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		we.environment.ambient_light_color = Color(0.5, 0.46, 0.4)
		we.environment.ambient_light_energy = 1.0
		we.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var ground := get_node_or_null("GroundPlane") as MeshInstance3D
	if ground:
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.85, 0.78, 0.68)  # warm packed-earth cast
		gmat.albedo_texture = load("res://assets/textures/tile_dirt.png")
		gmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		gmat.uv1_triplanar = true
		gmat.uv1_scale = Vector3(0.25, 0.25, 0.25)
		gmat.roughness = 1.0
		ground.set_surface_override_material(0, gmat)

func _npc_box(parent: Node3D, n: String, pos: Vector3, size: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees = rot
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _npc_cyl(parent: Node3D, n: String, pos: Vector3, top_r: float, bot_r: float, h: float, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = h
	m.radial_segments = 10
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.7
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _npc_sphere(parent: Node3D, n: String, pos: Vector3, r: float, c: Color, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.position = pos
	mi.scale = scl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.7
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Replace the placeholder vendor cubes with themed market stalls, and scatter
## lamps, barrels and crates so the hub reads as a lived-in plaza.
func _dress_town() -> void:
	var vendors := get_node_or_null("Vendors")
	if vendors == null:
		return
	var awnings := {
		"Blacksmith": Color(0.45, 0.2, 0.16),
		"Armory": Color(0.22, 0.32, 0.5),
		"CardDealer": Color(0.42, 0.18, 0.36),
		"AccessoryShop": Color(0.55, 0.45, 0.16),
	}
	for vn in awnings:
		var vendor: Node3D = vendors.get_node_or_null(vn)
		if vendor == null:
			continue
		var old_mesh = vendor.get_node_or_null("Mesh")
		if old_mesh is MeshInstance3D:
			old_mesh.visible = false
		_build_stall(vendor, awnings[vn], vn)
	var stash: Node3D = vendors.get_node_or_null("Stash")
	if stash != null:
		var old_mesh2 = stash.get_node_or_null("Mesh")
		if old_mesh2 is MeshInstance3D:
			old_mesh2.visible = false
		_build_stash_chest(stash)

	# Street dressing (pure visuals, no collision, kept off the walkways)
	var dressing := Node3D.new()
	dressing.name = "TownDressing"
	add_child(dressing)
	for lamp_pos in [Vector3(1.2, 0, 1.2), Vector3(18.8, 0, 10.8), Vector3(1.2, 0, 10.8)]:
		_build_lamp(dressing, lamp_pos)
	# Barrels beside the blacksmith, crates by the armory
	_build_barrel(dressing, Vector3(2.6, 0, 3.4))
	_build_barrel(dressing, Vector3(2.9, 0, 4.1))
	var crate := _npc_box(dressing, "Crate", Vector3(9.4, 0.25, 2.2), Vector3(0.5, 0.5, 0.5), Color(0.45, 0.33, 0.2))
	crate.rotation_degrees = Vector3(0, 18, 0)
	_npc_box(dressing, "Crate2", Vector3(9.5, 0.7, 2.25), Vector3(0.38, 0.38, 0.38), Color(0.5, 0.38, 0.24), Vector3(0, -12, 0))


func _build_stall(vendor: Node3D, awning: Color, vn: String) -> void:
	var stall := Node3D.new()
	stall.name = "Stall"
	vendor.add_child(stall)
	var wood := Color(0.4, 0.29, 0.17)
	var wood2 := Color(0.32, 0.22, 0.13)
	var canvas := Color(0.88, 0.84, 0.74)
	# Corner posts + counter
	for sx in [-1, 1]:
		_npc_box(stall, "Post%d" % sx, Vector3(0.8 * sx, 1.0, -0.3), Vector3(0.12, 2.0, 0.12), wood)
	_npc_box(stall, "Counter", Vector3(0, 0.5, 0.45), Vector3(1.7, 0.12, 0.5), wood)
	_npc_box(stall, "CounterFront", Vector3(0, 0.25, 0.62), Vector3(1.7, 0.4, 0.08), wood2)
	# Striped awning sloping down over the counter
	for i in range(4):
		var c := awning if i % 2 == 0 else canvas
		_npc_box(stall, "Awning%d" % i, Vector3(-0.63 + i * 0.42, 1.92, 0.25), Vector3(0.43, 0.05, 1.3), c, Vector3(-16, 0, 0))
	match vn:
		"Blacksmith":
			# Anvil on a stump beside the counter, with a forge ember glow
			_npc_cyl(stall, "Stump", Vector3(-1.3, 0.25, 0.7), 0.22, 0.26, 0.5, wood2)
			_npc_box(stall, "AnvilBody", Vector3(-1.3, 0.62, 0.7), Vector3(0.4, 0.22, 0.2), Color(0.35, 0.36, 0.4))
			_npc_cyl(stall, "AnvilHorn", Vector3(-1.05, 0.62, 0.7), 0.03, 0.09, 0.24, Color(0.35, 0.36, 0.4), Vector3(0, 0, -90))
			var ember := _npc_box(stall, "Forge", Vector3(0.3, 0.6, 0.35), Vector3(0.3, 0.08, 0.22), Color(1.0, 0.45, 0.1))
			var em := ember.material_override as StandardMaterial3D
			em.emission_enabled = true
			em.emission = Color(1.0, 0.4, 0.08)
			em.emission_energy_multiplier = 1.3
			_npc_cyl(stall, "Hammer", Vector3(-0.4, 0.62, 0.45), 0.02, 0.02, 0.3, wood, Vector3(0, 0, 70))
			_npc_box(stall, "HammerHead", Vector3(-0.54, 0.64, 0.45), Vector3(0.1, 0.09, 0.09), Color(0.5, 0.52, 0.56))
		"Armory":
			# Armour stand wearing a breastplate and helm
			_npc_cyl(stall, "StandPost", Vector3(-0.4, 0.95, 0.1), 0.04, 0.05, 0.9, wood2)
			_npc_box(stall, "Breastplate", Vector3(-0.4, 1.05, 0.12), Vector3(0.42, 0.5, 0.24), Color(0.62, 0.66, 0.72))
			_npc_sphere(stall, "Helm", Vector3(-0.4, 1.45, 0.1), 0.16, Color(0.55, 0.58, 0.64))
			_npc_box(stall, "ShieldDisp", Vector3(0.45, 0.85, 0.3), Vector3(0.36, 0.5, 0.06), Color(0.28, 0.4, 0.62), Vector3(8, 0, 0))
			_npc_box(stall, "ShieldTrim", Vector3(0.45, 0.85, 0.34), Vector3(0.08, 0.42, 0.02), Color(0.75, 0.78, 0.84), Vector3(8, 0, 0))
		"CardDealer":
			# A hand of cards fanned on the counter and a stacked deck
			for i in range(3):
				_npc_box(stall, "Card%d" % i, Vector3(-0.25 + i * 0.25, 0.58, 0.42), Vector3(0.18, 0.015, 0.26), Color(0.92, 0.9, 0.84), Vector3(0, -14 + i * 14, 0))
				_npc_box(stall, "CardFace%d" % i, Vector3(-0.25 + i * 0.25, 0.59, 0.42), Vector3(0.13, 0.012, 0.2), Color(0.42, 0.18, 0.36), Vector3(0, -14 + i * 14, 0))
			_npc_box(stall, "Deck", Vector3(0.55, 0.6, 0.5), Vector3(0.2, 0.1, 0.28), Color(0.55, 0.25, 0.45))
		"AccessoryShop":
			# A jewel cushion with rings and gems catching the light
			_npc_box(stall, "Cushion", Vector3(0, 0.6, 0.45), Vector3(0.6, 0.08, 0.4), Color(0.35, 0.12, 0.2))
			var ring := MeshInstance3D.new()
			ring.name = "GoldRing"
			var tor := TorusMesh.new()
			tor.inner_radius = 0.03
			tor.outer_radius = 0.09
			ring.mesh = tor
			ring.position = Vector3(-0.15, 0.68, 0.45)
			var gold_m := StandardMaterial3D.new()
			gold_m.albedo_color = Color(0.9, 0.75, 0.3)
			gold_m.metallic = 0.0  # no modern specular pop
			gold_m.roughness = 0.3
			ring.material_override = gold_m
			stall.add_child(ring)
			for g in range(3):
				var gem := _npc_sphere(stall, "Gem%d" % g, Vector3(0.08 + g * 0.13, 0.66, 0.42 + (g % 2) * 0.08), 0.04, [Color(0.85, 0.2, 0.25), Color(0.2, 0.5, 0.85), Color(0.25, 0.7, 0.4)][g])
				var gm := gem.material_override as StandardMaterial3D
				gm.emission_enabled = true
				gm.emission = gm.albedo_color
				gm.emission_energy_multiplier = 0.5


func _build_stash_chest(stash: Node3D) -> void:
	# Same 16-bit chest billboard the dungeons use, scaled up for the stash.
	var chest := Sprite3D.new()
	chest.name = "Chest"
	chest.texture = load("res://assets/textures/props/chest_closed.png")
	chest.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chest.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	chest.shaded = false
	chest.pixel_size = 0.034
	var s := 1.4
	chest.scale = Vector3(s, s, s)
	chest.position = Vector3(0, 26.0 * 0.034 * 0.5 * s, 0)
	stash.add_child(chest)


func _build_lamp(parent: Node3D, pos: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = pos
	parent.add_child(lamp)
	var iron := Color(0.2, 0.21, 0.25)
	_npc_cyl(lamp, "Post", Vector3(0, 1.1, 0), 0.04, 0.06, 2.2, iron)
	_npc_box(lamp, "Cage", Vector3(0, 2.3, 0), Vector3(0.24, 0.3, 0.24), iron)
	var glass := _npc_box(lamp, "Glass", Vector3(0, 2.3, 0), Vector3(0.18, 0.22, 0.18), Color(1.0, 0.8, 0.45))
	var gm := glass.material_override as StandardMaterial3D
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.72, 0.35)
	gm.emission_energy_multiplier = 1.6
	_npc_cyl(lamp, "Cap", Vector3(0, 2.5, 0), 0.02, 0.18, 0.12, iron)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.3, 0)
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 1.1
	light.omni_range = 5.0
	lamp.add_child(light)


func _build_barrel(parent: Node3D, pos: Vector3) -> void:
	_npc_cyl(parent, "Barrel", pos + Vector3(0, 0.42, 0), 0.3, 0.34, 0.84, Color(0.45, 0.32, 0.18))
	for by in [0.2, 0.62]:
		var hoop := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.02
		tor.outer_radius = 0.35
		hoop.mesh = tor
		hoop.position = pos + Vector3(0, by, 0)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.28, 0.29, 0.33)
		hoop.material_override = m
		parent.add_child(hoop)


func _create_olorin_npc() -> void:
	var olorin = StaticBody3D.new()
	olorin.name = "Olorin"
	olorin.position = Vector3(14, 0, 8)

	# The wise old wanderer himself — the old-man sheet from the NPC pack
	# (grey beard, walking stick), matching the 16-bit party/NPC pipeline.
	var fig = Sprite3D.new()
	fig.name = "Figure"
	fig.texture = load("res://assets/sprites/NPCpackage1/npc old man A v01.png")
	fig.region_enabled = true
	fig.region_rect = Rect2(0, 0, 32, 32)  # south-facing idle frame
	fig.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fig.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fig.shaded = false
	fig.pixel_size = 0.034
	var olorin_scale := 1.25  # a touch taller than the party — presence
	fig.scale = Vector3(olorin_scale, olorin_scale, olorin_scale)
	fig.position = Vector3(0, 32.0 * 0.034 * 0.5 * olorin_scale, 0)
	olorin.add_child(fig)
	BlobShadow.attach(olorin, 0.6)

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
	WorldText.crisp(label)
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
	WorldText.crisp(quest_indicator)
	olorin.add_child(quest_indicator)

	$Vendors.add_child(olorin)
	print("[TOWN] Created Olorin NPC at position %s" % olorin.position)

func _create_sellsword_npc() -> void:
	## The Sellsword recruits a persistent co-op partner from the characters the
	## player did not choose for Player 1.
	var sellsword = StaticBody3D.new()
	sellsword.name = "Sellsword"
	sellsword.position = Vector3(18, 0, 3)

	# A mercenary at ease — the knight sheet from the NPC pack, in a darker
	# coat than Brad's, matching the 16-bit NPC pipeline.
	var fig = Sprite3D.new()
	fig.name = "Figure"
	fig.texture = load("res://assets/sprites/NPCpackage2/npc knight v04.png")
	fig.region_enabled = true
	fig.region_rect = Rect2(0, 0, 32, 32)  # south-facing idle frame
	fig.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fig.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fig.shaded = false
	fig.pixel_size = 0.034
	var sellsword_scale := 1.15
	fig.scale = Vector3(sellsword_scale, sellsword_scale, sellsword_scale)
	fig.position = Vector3(0, 32.0 * 0.034 * 0.5 * sellsword_scale, 0)
	sellsword.add_child(fig)
	BlobShadow.attach(sellsword, 0.55)

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.4, 1.8, 1.4)
	collision.shape = shape
	collision.position = Vector3(0, 0.9, 0)
	sellsword.add_child(collision)

	var label = Label3D.new()
	label.text = "SELLSWORD"
	label.font_size = 26
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.8, 0.45)
	label.outline_size = 8
	label.position = Vector3(0, 2.2, 0)
	WorldText.crisp(label)
	sellsword.add_child(label)

	$Vendors.add_child(sellsword)
	print("[TOWN] Created Sellsword NPC at position %s" % sellsword.position)

func _open_sellsword_ui() -> void:
	## Lists the four characters not chosen by Player 1, with a Recruit/Dismiss action.
	if player2_character:
		_add_info_label("Current partner: %s" % player2_character.character_name, Color(0.6, 1.0, 0.6))
		var dismiss = Button.new()
		dismiss.text = "  Dismiss %s" % player2_character.character_name
		dismiss.custom_minimum_size.y = 36
		dismiss.alignment = HORIZONTAL_ALIGNMENT_LEFT
		dismiss.add_theme_font_size_override("font_size", 14)
		dismiss.pressed.connect(_on_dismiss_partner)
		vendor_item_list.add_child(dismiss)
		_add_section_separator("Swap partner")
	else:
		_add_info_label("No partner hired. Choose a battle-companion:", Color(0.85, 0.85, 0.9))

	# Compare preset identities so a renamed hero still can't recruit themselves.
	var p1_base := starting_character.get_base_character() if starting_character else ""
	for character in CharacterData.get_all_characters():
		if character.get_base_character() == p1_base:
			continue  # Player 1 cannot recruit themselves
		if player2_character and character.get_base_character() == player2_character.get_base_character():
			continue  # Already the active partner
		_add_sellsword_row(character)

func _add_sellsword_row(character: CharacterData) -> void:
	var btn = Button.new()
	btn.custom_minimum_size.y = 44
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "  Hire %s   —   %s" % [character.character_name, character.passive_description]
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_recruit_partner.bind(character))
	vendor_item_list.add_child(btn)

func _on_recruit_partner(character: CharacterData) -> void:
	player2_character = character
	print("[TOWN] Recruited partner: %s" % character.character_name)
	_open_vendor(nearby_vendor)  # Refresh the panel to reflect the new partner

func _on_dismiss_partner() -> void:
	print("[TOWN] Dismissed partner: %s" % (player2_character.character_name if player2_character else "none"))
	player2_character = null
	_open_vendor(nearby_vendor)

func _create_town_waypoint() -> void:
	## Creates the transport portal in town for returning to the dungeon.
	_town_waypoint_node = Node3D.new()
	_town_waypoint_node.name = "TransportPortal"

	# Slightly raised dirt mound so the portal reads as a landmark (matches
	# the dungeon waypoints).
	var mound = MeshInstance3D.new()
	var mound_mesh = CylinderMesh.new()
	mound_mesh.top_radius = 0.68
	mound_mesh.bottom_radius = 0.95
	mound_mesh.height = 0.22
	mound_mesh.radial_segments = 12
	mound.mesh = mound_mesh
	var mound_mat = StandardMaterial3D.new()
	mound_mat.albedo_texture = load("res://assets/textures/tile_dirt.png")
	mound_mat.albedo_color = Color(1, 1, 1).lerp(Color(0.62, 0.5, 0.36), 0.5)
	mound_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mound_mat.uv1_triplanar = true
	mound_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mound_mat.roughness = 1.0
	mound.material_override = mound_mat
	mound.position = Vector3(0, 0.11, 0)
	_town_waypoint_node.add_child(mound)

	# Pixel rune-ring on the mound's top, matching the dungeon waypoints.
	var pillar = Sprite3D.new()
	pillar.texture = load("res://assets/textures/props/waypoint_ring.png")
	pillar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pillar.shaded = false
	pillar.pixel_size = 0.045
	pillar.rotation_degrees = Vector3(-90, 0, 0)
	pillar.modulate = Color8(0x62, 0xa3, 0xb0)  # TEAL_1 (transport)
	pillar.position = Vector3(0, 0.25, 0)
	_town_waypoint_node.add_child(pillar)

	# Name label
	var label = Label3D.new()
	label.text = "Transport Portal"
	label.font_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.5, 0.7, 1.0)
	label.position = Vector3(0, 2.5, 0)
	WorldText.crisp(label)
	_town_waypoint_node.add_child(label)

	# Interact label
	var interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "[Shift] Travel"
	interact_label.font_size = 16
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.4)
	interact_label.position = Vector3(0, 3.0, 0)
	interact_label.visible = false
	WorldText.crisp(interact_label)
	_town_waypoint_node.add_child(interact_label)

	# Position near the town entrance area
	_town_waypoint_node.position = Vector3(4, 0, 10)
	add_child(_town_waypoint_node)
	print("[TOWN] Created transport portal")

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

# ── Save game ──

func _setup_save_button() -> void:
	var btn := Button.new()
	btn.name = "SaveButton"
	btn.text = "SAVE GAME"
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left = -160.0
	btn.offset_top = 65.0
	btn.offset_right = -20.0
	btn.offset_bottom = 100.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn.pressed.connect(_open_save_picker)
	$UI.add_child(btn)

func _build_save_data(slot: int) -> SaveData:
	var data := SaveData.new()
	data.save_slot = slot
	data.character_data = starting_character
	data.player2_character = player2_character
	data.character_name = starting_character.character_name if starting_character else "Unknown"
	data.current_location = "Town"
	data.world_level = return_world_level
	data.sprite_path = starting_character.sprite_path if starting_character else ""
	var stats = player.get_stats() if player else null
	data.character_level = stats.current_level if stats else 1

	# Disk-safe progression snapshot. Town's player_progression already carries
	# the full live progression (deck, sphere grid/inventory, inventory) that
	# main.gd handed off when travelling here; pair it with a fresh stats snapshot.
	var stats_snapshot := stats.save_progression() if stats else {}
	data.progression = ProgressionIO.to_disk(player_progression, stats_snapshot)
	# The city also lives in its dedicated SaveData field (the progression
	# snapshot carries the satchel + calamity keys via ProgressionIO).
	data.city = player_progression.get("city", {})
	data.progression["quest_state"] = quest_manager.save_state() if quest_manager else {}
	data.progression["discovered_waypoints"] = discovered_waypoints.duplicate(true)
	data.progression["opened_chests"] = opened_chests.duplicate(true)

	# Deck snapshot (display only) — same basic deck + purchased, minus culls.
	var ids: Array[String] = []
	for c in _get_current_deck_card_ids():
		ids.append(str(c))
	data.deck_card_ids = ids
	return data

func _open_save_picker() -> void:
	if vendor_open:
		_close_vendor()

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var p_style := StyleBoxFlat.new()
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
	p_style.content_margin_left = 28
	p_style.content_margin_right = 28
	p_style.content_margin_top = 22
	p_style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", p_style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(380, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Save Game — choose a slot"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var status := Label.new()
	status.text = ""
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status)

	var slot_buttons: Array[Button] = []
	for slot in range(SaveManager.MAX_SAVE_SLOTS):
		var b := Button.new()
		b.custom_minimum_size = Vector2(360, 38)
		b.pressed.connect(_do_save.bind(slot, slot_buttons, status))
		vbox.add_child(b)
		slot_buttons.append(b)
	_refresh_slot_buttons(slot_buttons)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(360, 36)
	close_btn.pressed.connect(overlay.queue_free)
	vbox.add_child(close_btn)

	$UI.add_child(overlay)

func _refresh_slot_buttons(slot_buttons: Array[Button]) -> void:
	for slot in range(slot_buttons.size()):
		var existing := SaveManager.load_game(slot)
		if existing:
			slot_buttons[slot].text = "Slot %d — %s (Lv %d)" % [slot + 1, existing.character_name, existing.character_level]
		else:
			slot_buttons[slot].text = "Slot %d — Empty" % [slot + 1]

func _do_save(slot: int, slot_buttons: Array[Button], status: Label) -> void:
	var data := _build_save_data(slot)
	var ok := SaveManager.save_game(slot, data)
	if ok:
		status.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		status.text = "Saved %s to slot %d." % [data.character_name, slot + 1]
	else:
		status.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
		status.text = "Save failed (see log)."
	_refresh_slot_buttons(slot_buttons)

func _on_back_pressed() -> void:
	if vendor_open:
		_close_vendor()
	var title_scene = load("res://scenes/menus/title_menu.tscn").instantiate()
	get_tree().root.add_child(title_scene)
	queue_free()

func _close_vendor() -> void:
	vendor_open = false
	vendor_panel.visible = false
	print("[TOWN] Closed vendor")

func _go_to_battle(via_portal: bool = false) -> void:
	if vendor_open:
		_close_vendor()

	print("[TOWN] Heading to battle!")
	# Leaving home: if the city stands and nothing is brewing, fate arms the
	# next calamity — its countdown ticks on kills out in the world.
	CalamitySystem.schedule(player_progression)
	var saved_quest_state = quest_manager.save_state() if quest_manager else {}
	# Save current player progression before transitioning
	var stats = player.get_stats()
	var saved_progression = player_progression.duplicate(true)
	if stats:
		saved_progression["stats"] = stats.save_progression()
	# Re-snapshot the inventory from the live object: consumable counters
	# (culling stones, mythic molds) are plain ints, so — unlike the shared
	# item arrays — changes made in town would otherwise be lost.
	var live_inv = player.get_inventory() if player.has_method("get_inventory") else null
	if live_inv:
		saved_progression["inventory"] = {
			"equipped_helms": live_inv.equipped_helms.duplicate(),
			"equipped_chests": live_inv.equipped_chests.duplicate(),
			"equipped_rings": live_inv.equipped_rings.duplicate(),
			"equipped_belts": live_inv.equipped_belts.duplicate(),
			"equipped_boots": live_inv.equipped_boots.duplicate(),
			"equipped_gauntlets": live_inv.equipped_gauntlets.duplicate(),
			"equipped_weapons": live_inv.equipped_weapons.duplicate(),
			"stored_items": live_inv.stored_items.duplicate(),
			"stored_cards": live_inv.stored_cards.duplicate(),
			"stash_items": live_inv.stash_items.duplicate(),
			"culling_stones": live_inv.culling_stones,
			"mythic_molds": live_inv.mythic_molds,
		}
	var main_scene = load("res://scenes/core/main.tscn").instantiate()
	main_scene.starting_character = starting_character
	main_scene.player2_character = player2_character
	main_scene.is_multiplayer = player2_character != null
	main_scene.current_world_level = return_world_level
	main_scene.discovered_waypoints = discovered_waypoints
	main_scene.quest_state = saved_quest_state
	main_scene.player_progression = saved_progression
	main_scene.opened_chests = opened_chests
	# Return Scroll: stepping through the twin drops the player back at the
	# exact spot where they opened the portal (same world, same tile).
	if via_portal and not portal_return.is_empty():
		main_scene.current_world_level = portal_return.get("world_level", return_world_level)
		main_scene.portal_return_position = portal_return.get("position")
	get_tree().root.add_child(main_scene)
	queue_free()

func _spawn_return_portal() -> void:
	## The twin of the Return Scroll portal, matching the battle-side visual.
	var portal_root = Node3D.new()
	portal_root.name = "ReturnPortal"
	portal_root.position = player.position + Vector3(2.0, 0, 1.0)

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.75
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, 1.1, 0)
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.6, 0.25, 0.95)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.55, 0.2, 0.9)
	ring_mat.emission_energy_multiplier = 1.6
	ring.material_override = ring_mat
	portal_root.add_child(ring)

	var film = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 0.58
	disc.bottom_radius = 0.58
	disc.height = 0.05
	film.mesh = disc
	film.rotation_degrees = Vector3(90, 0, 0)
	film.position = Vector3(0, 1.1, 0)
	var film_mat = StandardMaterial3D.new()
	film_mat.albedo_color = Color(0.75, 0.45, 1.0, 0.55)
	film_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	film_mat.emission_enabled = true
	film_mat.emission = Color(0.7, 0.4, 1.0)
	film_mat.emission_energy_multiplier = 1.2
	film.material_override = film_mat
	portal_root.add_child(film)

	var label = Label3D.new()
	label.text = "Your Portal"
	label.modulate = Color(0.85, 0.6, 1.0)
	label.position = Vector3(0, 2.3, 0)
	WorldText.crisp(label, 32)
	portal_root.add_child(label)

	_return_portal_node = portal_root
	add_child(portal_root)
	print("[TOWN] Return portal opened at %s" % portal_root.position)

# ============================================
# THE TOWN HALL (city loop — STORY.md §6)
# ============================================

func _create_town_hall_npc() -> void:
	## The Town Hall building marker: a small stone hall on the plaza's north
	## edge. Interacting opens the city panel (resources, buildings, defenses).
	var hall = StaticBody3D.new()
	hall.name = "TownHall"
	hall.position = Vector3(10, 0, 12)

	# A squat stone hall with a timber roof and banner — chunky primitives,
	# same language as the market stalls.
	_npc_box(hall, "Base", Vector3(0, 0.8, 0), Vector3(3.2, 1.6, 2.2), Color(0.52, 0.5, 0.48))
	_npc_box(hall, "Roof", Vector3(0, 1.85, 0), Vector3(3.6, 0.5, 2.6), Color(0.4, 0.26, 0.16))
	_npc_box(hall, "Door", Vector3(0, 0.55, 1.12), Vector3(0.7, 1.1, 0.08), Color(0.3, 0.2, 0.12))
	_npc_box(hall, "Banner", Vector3(1.2, 1.5, 1.14), Vector3(0.5, 0.9, 0.04), Color(0.75, 0.62, 0.28))

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.4, 2.2, 2.4)
	collision.shape = shape
	collision.position = Vector3(0, 1.1, 0)
	hall.add_child(collision)

	var label = Label3D.new()
	label.text = "TOWN HALL"
	label.font_size = 26
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.95, 0.85, 0.5)
	label.outline_size = 8
	label.position = Vector3(0, 2.7, 0)
	WorldText.crisp(label)
	hall.add_child(label)

	$Vendors.add_child(hall)
	print("[TOWN] Created Town Hall at position %s" % hall.position)

func _open_town_hall_ui() -> void:
	if not CityBridge.city_started(player_progression):
		_add_info_label("The city awaits its first shipment.", Color(0.85, 0.85, 0.9))
		_add_info_label("Fight out in the world and your satchel fills with lumber, stone, gold and essence. It is banked here the moment you come home.", Color(0.6, 0.6, 0.72))
		return

	var city := CityBridge.get_city(player_progression)

	# ── Overview ──
	var res_parts: Array[String] = []
	for res in CityState.RESOURCES:
		res_parts.append("%s %d" % [res.capitalize(), int(city.resources.get(res, 0))])
	_add_info_label("Stores: %s   (cap %d)" % ["  ".join(res_parts), city.get_storage_cap()], Color(1.0, 0.85, 0.4))
	var prod := city.get_production_per_hour()
	if not prod.is_empty():
		_add_info_label("Production: %s per hour" % _format_city_cost(prod), Color(0.6, 0.9, 0.6))
	_add_info_label("City power %d — defense %d, garrison attack %d, %d%% of stores protected" % [
		city.get_power(), city.get_defense_power(), city.get_attack_power(),
		int(city.get_protected_fraction() * 100)], Color(0.7, 0.85, 1.0))
	var brewing := CalamitySystem.pending(player_progression)
	if not brewing.is_empty():
		if brewing.get("struck", false):
			_add_info_label("The city is under threat RIGHT NOW — %s" % CalamitySystem.warning_text(player_progression), Color(1.0, 0.4, 0.35))
		else:
			_add_info_label("Olorin's flute is silent... for now.", Color(0.6, 0.6, 0.72))

	# ── Buildings ──
	_add_section_separator("Buildings")
	for id in CityState.BUILDING_DEFS:
		_add_town_hall_building_row(city, id)

	# ── Defense log ──
	if city.defense_log.size() > 0:
		_add_section_separator("Chronicle of Attacks")
		for i in range(mini(city.defense_log.size(), 5)):
			var entry: Dictionary = city.defense_log[i]
			var text: String
			if entry.get("won", false):
				text = "%s breached the defenses — lost %s" % [
					entry.get("attacker", "?"), _format_city_cost(entry.get("loot", {}))]
			else:
				text = "%s was driven off — nothing lost" % entry.get("attacker", "?")
			_add_info_label(text, Color(1.0, 0.55, 0.45) if entry.get("won", false) else Color(0.55, 0.9, 0.55))

func _add_town_hall_building_row(city: CityState, id: String) -> void:
	var def: Dictionary = CityState.BUILDING_DEFS[id]
	var lvl := city.get_building_level(id)
	var btn := Button.new()
	btn.custom_minimum_size.y = 44
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 13)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var action: String
	if lvl >= int(def["max_level"]):
		action = "MAX"
		btn.disabled = true
	else:
		var cost := city.get_upgrade_cost(id)
		action = "Upgrade: %s" % _format_city_cost(cost)
		if id != "town_hall" and lvl >= city.get_building_level("town_hall"):
			action += "  (needs Town Hall Lv %d)" % (lvl + 1)
			btn.disabled = true
		elif not city.can_afford(cost):
			action += "  (not enough resources)"
			btn.disabled = true
	btn.text = "  %s  Lv %d/%d — %s\n      %s" % [def["name"], lvl, int(def["max_level"]), def["desc"], action]
	btn.pressed.connect(_on_upgrade_building.bind(id))
	vendor_item_list.add_child(btn)

func _on_upgrade_building(id: String) -> void:
	var city := CityBridge.get_city(player_progression)
	if city.upgrade(id):
		CityBridge.store_city(player_progression, city)
		print("[TOWN] Upgraded %s to Lv %d" % [id, city.get_building_level(id)])
	# Rebuild the panel with fresh levels, costs and stores either way.
	for child in vendor_item_list.get_children():
		child.queue_free()
	_open_town_hall_ui()

func _format_city_cost(amounts: Dictionary) -> String:
	var parts: Array[String] = []
	for res in CityState.RESOURCES:
		if amounts.has(res) and int(amounts[res]) > 0:
			parts.append("%d %s" % [int(amounts[res]), res])
	return ", ".join(parts) if parts.size() > 0 else "nothing"

# ============================================
# COMING HOME (bank the satchel, weather calamities)
# ============================================

func _arrive_home() -> void:
	var lines: Array[String] = []
	var now := int(Time.get_unix_time_from_system())

	# A struck calamity resolves the moment the hero reaches home. Whether
	# they made it back promptly decides if they stood with the garrison.
	if CalamitySystem.has_struck(player_progression):
		var power := ExpeditionSystem.hero_power(player.get_stats() if player else null)
		var outcome := CalamitySystem.resolve(player_progression, power, now)
		if not outcome.is_empty():
			if outcome["hero_joined"]:
				lines.append("You answered the flute in time — you stood with the garrison against the %s." % outcome["name"])
			else:
				lines.append("The flute called, but you tarried. The city faced the %s alone." % outcome["name"])
			if outcome["held"]:
				lines.append("The city HELD. Nothing was lost.")
			else:
				lines.append("The city suffered — lost %s." % _format_city_cost(outcome["lost"]))

	# Bank the satchel (founding the city on the first shipment).
	var pouch := CityBridge.satchel(player_progression)
	var founding := not CityBridge.city_started(player_progression) and not pouch.is_empty()
	if not pouch.is_empty() or CityBridge.city_started(player_progression):
		var result := CityBridge.bank_satchel(player_progression, now)
		if not result["produced"].is_empty():
			lines.append("While you were away, the city produced %s." % _format_city_cost(result["produced"]))
		if not result["banked"].is_empty():
			lines.append("Satchel banked: %s." % _format_city_cost(result["banked"]))
		if not result["lost"].is_empty():
			lines.append("The warehouses overflowed — %s went to waste. Raise the Warehouse." % _format_city_cost(result["lost"]))

	# The first shipment founds the city — and Olorin hands over the flute.
	if founding and starting_character and not starting_character.seen_tutorial_ids.has("olorin_flute"):
		starting_character.seen_tutorial_ids.append("olorin_flute")
		lines.append("Olorin presses a bone-white flute into your hands: \"The city grows — and what grows, draws eyes. When this flute sounds, wherever you are, home needs you.\"")
		lines.append("Visit the TOWN HALL to raise the city's buildings.")

	if lines.size() > 0:
		_show_town_notice("The City", lines)

func _show_town_notice(title_text: String, lines: Array[String]) -> void:
	var overlay := ColorRect.new()
	overlay.name = "TownNotice"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	p_style.border_width_left = 2
	p_style.border_width_right = 2
	p_style.border_width_top = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.75, 0.62, 0.28)
	p_style.corner_radius_top_left = 8
	p_style.corner_radius_top_right = 8
	p_style.corner_radius_bottom_left = 8
	p_style.corner_radius_bottom_right = 8
	p_style.content_margin_left = 28
	p_style.content_margin_right = 28
	p_style.content_margin_top = 22
	p_style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", p_style)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(460, 0)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(460, 0)
		vbox.add_child(lbl)

	var ok := Button.new()
	ok.text = "Continue"
	ok.custom_minimum_size = Vector2(460, 38)
	ok.pressed.connect(overlay.queue_free)
	vbox.add_child(ok)

	$UI.add_child(overlay)
