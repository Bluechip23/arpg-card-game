class_name WaypointManager
extends Node

## Handles waypoint discovery, waypoint menu display, and teleportation.
## Extracted from main.gd to reduce god-object complexity.

var main  # Reference to the Main scene node

func init(main_ref) -> void:
	main = main_ref

func _restore_discovered_waypoints() -> void:
	## Marks waypoints in the current dungeon as discovered if they were previously found.
	if not main.dungeon_manager:
		return
	for i in range(main.dungeon_manager.waypoint_nodes.size()):
		var wp = main.dungeon_manager.waypoint_nodes[i]
		for d in main.discovered_waypoints:
			if d["world"] == main.current_world_level and d["target"] == wp["target"]:
				main.dungeon_manager.discover_waypoint(i)
				break

func _check_waypoint_discovery(player_grid: Vector2i) -> void:
	## Discover any waypoint the player is standing on.
	if not main.dungeon_manager:
		return
	var wp_idx = main.dungeon_manager.get_waypoint_on_tile(player_grid)
	if wp_idx < 0:
		return
	if main.dungeon_manager.discover_waypoint(wp_idx):
		var wp = main.dungeon_manager.waypoint_nodes[wp_idx]
		# Register in global discovered list
		var entry = {
			"world": main.current_world_level,
			"target": wp["target"],
			"display_name": wp["display_name"]
		}
		# Check if already registered (e.g. from a previous visit)
		var already = false
		for d in main.discovered_waypoints:
			if d["world"] == entry["world"] and d["target"] == entry["target"]:
				already = true
				break
		if not already:
			main.discovered_waypoints.append(entry)
		main.add_battle_log("Waypoint discovered: %s" % wp["display_name"], Color(0.3, 0.9, 1.0))

func _try_interact_waypoint() -> bool:
	## Handles Shift near a waypoint. World exits travel directly,
	## transport portal opens the menu.
	if not main.dungeon_manager:
		return false
	var player_grid = main.grid_manager.world_to_grid(main.player.position)
	var wp_idx = main.dungeon_manager.get_nearby_waypoint(player_grid)
	if wp_idx < 0:
		return false
	# Must be discovered to use
	if not main.dungeon_manager.waypoint_nodes[wp_idx]["discovered"]:
		main.add_battle_log("Walk onto the waypoint to discover it first.", Color(0.8, 0.8, 0.5))
		return true
	var target = main.dungeon_manager.waypoint_nodes[wp_idx]["target"]
	match target:
		"next_world":
			main._travel_to_world(main.current_world_level + 1)
			return true
		"prev_world":
			main._travel_to_world(main.current_world_level - 1)
			return true
	# Transport portal opens the menu
	_open_waypoint_menu()
	return true

func _open_waypoint_menu() -> void:
	## Shows a centered panel listing all discovered waypoints for teleportation.
	if main._waypoint_menu_visible:
		_close_waypoint_menu()
		return

	var ui = $UI as CanvasLayer

	main._waypoint_menu_panel = PanelContainer.new()
	main._waypoint_menu_panel.name = "WaypointMenu"
	ui.add_child(main._waypoint_menu_panel)
	# Explicitly center on 1280x720 screen
	var wp_w = 350.0
	var wp_h = 300.0
	main._waypoint_menu_panel.offset_left = (1280.0 - wp_w) / 2.0
	main._waypoint_menu_panel.offset_top = (720.0 - wp_h) / 2.0
	main._waypoint_menu_panel.offset_right = (1280.0 + wp_w) / 2.0
	main._waypoint_menu_panel.offset_bottom = (720.0 + wp_h) / 2.0
	main._waypoint_menu_panel.custom_minimum_size = Vector2(wp_w, wp_h)
	main._waypoint_menu_panel.z_index = 100  # Sit on top of cards and other UI

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	main._waypoint_menu_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	main._waypoint_menu_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Transport Portal"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Always offer town as a destination
	var town_btn = Button.new()
	town_btn.text = "Town"
	town_btn.custom_minimum_size = Vector2(280, 36)
	town_btn.add_theme_font_size_override("font_size", 15)
	town_btn.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	town_btn.pressed.connect(func():
		_close_waypoint_menu()
		_teleport_to_waypoint("town", 0)
	)
	vbox.add_child(town_btn)

	# World portal destinations
	if main.current_world_level > 1:
		var prev_btn = Button.new()
		prev_btn.text = "World %d (Previous)" % (main.current_world_level - 1)
		prev_btn.custom_minimum_size = Vector2(280, 36)
		prev_btn.add_theme_font_size_override("font_size", 15)
		prev_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		var prev_world = main.current_world_level - 1
		prev_btn.pressed.connect(func():
			_close_waypoint_menu()
			main._travel_to_world(prev_world)
		)
		vbox.add_child(prev_btn)

	if main.current_world_level < 5:
		var next_btn = Button.new()
		next_btn.text = "World %d (Next)" % (main.current_world_level + 1)
		next_btn.custom_minimum_size = Vector2(280, 36)
		next_btn.add_theme_font_size_override("font_size", 15)
		next_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		var next_world = main.current_world_level + 1
		next_btn.pressed.connect(func():
			_close_waypoint_menu()
			main._travel_to_world(next_world)
		)
		vbox.add_child(next_btn)

	# Also list any other discovered waypoints from other worlds
	for wp in main.discovered_waypoints:
		if wp["target"] == "town" or wp["target"] == "transport":
			continue
		if wp["world"] == main.current_world_level:
			continue  # Already covered by next/prev buttons above
		var btn = Button.new()
		btn.text = wp["display_name"]
		btn.custom_minimum_size = Vector2(280, 36)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		var world = wp["world"]
		btn.pressed.connect(func():
			_close_waypoint_menu()
			main._travel_to_world(world)
		)
		vbox.add_child(btn)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Cancel [Esc]"
	close_btn.custom_minimum_size = Vector2(120, 32)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(_close_waypoint_menu)
	vbox.add_child(close_btn)

	main._waypoint_menu_visible = true

func _close_waypoint_menu() -> void:
	if main._waypoint_menu_panel and is_instance_valid(main._waypoint_menu_panel):
		main._waypoint_menu_panel.queue_free()
		main._waypoint_menu_panel = null
	main._waypoint_menu_visible = false

func _teleport_to_waypoint(target: String, world: int) -> void:
	match target:
		"town":
			main._travel_to_town()
		_:
			if world == main.current_world_level:
				# Same world: teleport to the waypoint position within the dungeon
				for wp in main.dungeon_manager.waypoint_nodes:
					if wp["target"] == target:
						var wp_world_pos = main.grid_manager.grid_to_world(wp["grid_pos"])
						main.player.position = wp_world_pos
						main.player.target_position = wp_world_pos
						main._camera_focus = wp_world_pos + Vector3(3, 0, 0)
						main._update_camera()
						main._update_fog_of_war()
						main.add_battle_log("Teleported to %s" % wp["display_name"], Color(0.3, 0.9, 1.0))
						return
			else:
				main._travel_to_world(world)

