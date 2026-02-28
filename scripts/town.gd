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
				if vendor_open:
					return
				if nearby_vendor:
					_open_vendor(nearby_vendor)
			KEY_ESCAPE:
				if vendor_open:
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

func _open_vendor(vendor_node: StaticBody3D) -> void:
	var info = vendor_info.get(vendor_node.name, null)
	if not info:
		return

	vendor_open = true
	vendor_name_label.text = info["name"]
	vendor_inventory_label.text = info["description"] + "\n\nInventory is empty."

	# Clear old items from list
	for child in vendor_item_list.get_children():
		child.queue_free()

	vendor_panel.visible = true
	interact_prompt.text = ""
	print("[TOWN] Opened vendor: %s" % info["name"])

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
