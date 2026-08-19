class_name MinimapTabUI
extends Node

## Handles minimap rendering, tab menu (map/quest log), quest log display,
## and expanded map view.
## Extracted from main.gd to reduce god-object complexity.

var main  # Reference to the Main scene node

func init(main_ref) -> void:
	main = main_ref

func _setup_minimap() -> void:
	if main._minimap_panel and is_instance_valid(main._minimap_panel):
		main._minimap_panel.queue_free()

	var ui = main.get_node("UI") as CanvasLayer

	main._minimap_panel = PanelContainer.new()
	main._minimap_panel.name = "MinimapPanel"
	ui.add_child(main._minimap_panel)

	# Position in upper-left corner
	main._minimap_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main._minimap_panel.offset_left = 8.0
	main._minimap_panel.offset_top = 8.0
	main._minimap_panel.offset_right = 8.0 + main.MINIMAP_SIZE + 8
	main._minimap_panel.offset_bottom = 8.0 + main.MINIMAP_SIZE + 8

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.45, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	main._minimap_panel.add_theme_stylebox_override("panel", style)

	main._minimap_texture_rect = TextureRect.new()
	main._minimap_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp under the linear canvas default
	main._minimap_texture_rect.custom_minimum_size = Vector2(main.MINIMAP_SIZE, main.MINIMAP_SIZE)
	main._minimap_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Ignore the source image's native size so the rect (and its PanelContainer) stays
	# fixed at MINIMAP_SIZE. Larger worlds produce a bigger minimap image, and the default
	# EXPAND_KEEP_SIZE would balloon the panel over the stat bars beside it.
	main._minimap_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	main._minimap_panel.add_child(main._minimap_texture_rect)

	# Create initial minimap image
	main._minimap_image = Image.create(main.dungeon_manager.GRID_W * main.MINIMAP_PIXEL_SCALE, main.dungeon_manager.GRID_H * main.MINIMAP_PIXEL_SCALE, false, Image.FORMAT_RGBA8)
	main._minimap_image.fill(Color(0.02, 0.02, 0.05, 1.0))

func _update_minimap() -> void:
	if not main._minimap_image or not main.dungeon_manager or not main._minimap_texture_rect:
		return

	var gw = main.dungeon_manager.GRID_W
	var gh = main.dungeon_manager.GRID_H
	var s = main.MINIMAP_PIXEL_SCALE

	# Clear
	main._minimap_image.fill(Color(0.02, 0.02, 0.05, 1.0))

	# Draw revealed floor tiles
	for x in range(gw):
		for z in range(gh):
			if main.dungeon_manager.is_revealed(Vector2i(x, z)):
				var col: Color
				if main.dungeon_manager.is_floor(Vector2i(x, z)):
					col = Color(0.25, 0.22, 0.2, 1.0)
				else:
					col = Color(0.12, 0.1, 0.15, 1.0)
				for px in range(s):
					for pz in range(s):
						var ix = x * s + px
						var iz = z * s + pz
						if ix < main._minimap_image.get_width() and iz < main._minimap_image.get_height():
							main._minimap_image.set_pixel(ix, iz, col)

	# Draw waypoints
	for wp in main.dungeon_manager.waypoint_nodes:
		var wp_pos: Vector2i = wp["grid_pos"]
		var wp_col = Color(0.3, 0.7, 1.0)
		if wp["target"] == "next_world":
			wp_col = Color(0.3, 1.0, 0.4)
		elif wp["target"] == "prev_world":
			wp_col = Color(1.0, 0.8, 0.3)
		for px in range(s):
			for pz in range(s):
				var ix = wp_pos.x * s + px
				var iz = wp_pos.y * s + pz
				if ix < main._minimap_image.get_width() and iz < main._minimap_image.get_height():
					main._minimap_image.set_pixel(ix, iz, wp_col)

	# Draw cave/building entrances (amber)
	for site in main.dungeon_manager.site_nodes:
		var sp: Vector2i = site["grid_pos"]
		if site["kind"] != "exit" and not main.dungeon_manager.is_revealed(sp):
			continue
		for px in range(s):
			for pz in range(s):
				var ix = sp.x * s + px
				var iz = sp.y * s + pz
				if ix < main._minimap_image.get_width() and iz < main._minimap_image.get_height():
					main._minimap_image.set_pixel(ix, iz, Color(1.0, 0.6, 0.15))

	# Draw enemies
	for enemy in main.enemy_spawner.get_living_enemies():
		if not enemy.visible:
			continue
		var eg = main.grid_manager.world_to_grid(enemy.position)
		for px in range(s):
			for pz in range(s):
				var ix = eg.x * s + px
				var iz = eg.y * s + pz
				if ix >= 0 and ix < main._minimap_image.get_width() and iz >= 0 and iz < main._minimap_image.get_height():
					main._minimap_image.set_pixel(ix, iz, Color(1.0, 0.2, 0.2))

	# Draw player (slightly larger)
	var pg = main.grid_manager.world_to_grid(main.player.position)
	for px in range(-1, s + 1):
		for pz in range(-1, s + 1):
			var ix = pg.x * s + px
			var iz = pg.y * s + pz
			if ix >= 0 and ix < main._minimap_image.get_width() and iz >= 0 and iz < main._minimap_image.get_height():
				main._minimap_image.set_pixel(ix, iz, Color(0.2, 1.0, 0.4))

	var tex = ImageTexture.create_from_image(main._minimap_image)
	main._minimap_texture_rect.texture = tex

# ============================================
# TAB MENU (QUEST LOG / MAP)
# ============================================

func _setup_tab_menu() -> void:
	if main._tab_menu_panel and is_instance_valid(main._tab_menu_panel):
		main._tab_menu_panel.queue_free()

	var ui = main.get_node("UI") as CanvasLayer

	main._tab_menu_panel = PanelContainer.new()
	main._tab_menu_panel.name = "TabMenuPanel"
	ui.add_child(main._tab_menu_panel)
	# Explicitly center on 1280x720 screen
	var tab_w = 750.0
	var tab_h = 550.0
	main._tab_menu_panel.offset_left = (1280.0 - tab_w) / 2.0
	main._tab_menu_panel.offset_top = (720.0 - tab_h) / 2.0
	main._tab_menu_panel.offset_right = (1280.0 + tab_w) / 2.0
	main._tab_menu_panel.offset_bottom = (720.0 + tab_h) / 2.0
	main._tab_menu_panel.custom_minimum_size = Vector2(tab_w, tab_h)
	main._tab_menu_panel.visible = false
	main._tab_menu_panel.z_index = 100  # Sit on top of cards and other UI

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.35, 0.55)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	main._tab_menu_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	main._tab_menu_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Tab buttons row
	var tab_hbox = HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(tab_hbox)

	var map_tab_btn = Button.new()
	map_tab_btn.text = "World Map"
	map_tab_btn.custom_minimum_size = Vector2(140, 32)
	map_tab_btn.add_theme_font_size_override("font_size", 16)
	map_tab_btn.pressed.connect(_on_tab_map_pressed)
	tab_hbox.add_child(map_tab_btn)

	var quest_tab_btn = Button.new()
	quest_tab_btn.text = "Quest Log"
	quest_tab_btn.custom_minimum_size = Vector2(120, 32)
	quest_tab_btn.add_theme_font_size_override("font_size", 16)
	quest_tab_btn.pressed.connect(_on_tab_quest_pressed)
	tab_hbox.add_child(quest_tab_btn)

	var card_inv_tab_btn = Button.new()
	card_inv_tab_btn.text = "Card Inventory"
	card_inv_tab_btn.custom_minimum_size = Vector2(140, 32)
	card_inv_tab_btn.add_theme_font_size_override("font_size", 16)
	card_inv_tab_btn.pressed.connect(_on_tab_card_inv_pressed)
	tab_hbox.add_child(card_inv_tab_btn)

	# World label
	var world_lbl = Label.new()
	world_lbl.text = main.get_location_label()
	world_lbl.add_theme_font_size_override("font_size", 16)
	world_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	world_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tab_hbox.add_child(world_lbl)

	vbox.add_child(HSeparator.new())

	# Map content (shown by default — tab 0)
	main._tab_map_container = VBoxContainer.new()
	main._tab_map_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._tab_map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(main._tab_map_container)

	# Large map texture rect for dungeon map
	main._tab_map_texture_rect = TextureRect.new()
	main._tab_map_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp under the linear canvas default
	main._tab_map_texture_rect.custom_minimum_size = Vector2(400, 350)
	main._tab_map_texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._tab_map_texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._tab_map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	main._tab_map_container.add_child(main._tab_map_texture_rect)

	# Quest log content (hidden by default — tab 1)
	var quest_scroll = ScrollContainer.new()
	quest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_scroll.custom_minimum_size = Vector2(0, 400)
	quest_scroll.visible = false
	vbox.add_child(quest_scroll)

	main._tab_quest_container = VBoxContainer.new()
	main._tab_quest_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_scroll.add_child(main._tab_quest_container)

	# Card inventory content (hidden by default — tab 2)
	var card_inv_scroll = ScrollContainer.new()
	card_inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_inv_scroll.custom_minimum_size = Vector2(0, 400)
	card_inv_scroll.visible = false
	vbox.add_child(card_inv_scroll)

	main._tab_card_inv_container = VBoxContainer.new()
	main._tab_card_inv_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_inv_scroll.add_child(main._tab_card_inv_container)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close [Tab]"
	close_btn.custom_minimum_size = Vector2(120, 32)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(_toggle_tab_menu)
	vbox.add_child(close_btn)

	# Default to map tab
	main._tab_menu_current_tab = 0

func _toggle_tab_menu() -> void:
	main._tab_menu_visible = not main._tab_menu_visible
	if main._tab_menu_panel:
		main._tab_menu_panel.visible = main._tab_menu_visible
	if main._tab_menu_visible:
		_refresh_tab_menu()

func _on_tab_map_pressed() -> void:
	main._tab_menu_current_tab = 0
	_refresh_tab_menu()

func _on_tab_quest_pressed() -> void:
	main._tab_menu_current_tab = 1
	_refresh_tab_menu()

func open_quest_log() -> void:
	## Open the tab menu straight to the Quest Log (used by the HUD scroll icon).
	main._tab_menu_current_tab = 1
	main._tab_menu_visible = true
	if main._tab_menu_panel:
		main._tab_menu_panel.visible = true
	_refresh_tab_menu()

func _on_tab_card_inv_pressed() -> void:
	main._tab_menu_current_tab = 2
	_refresh_tab_menu()

func _refresh_tab_menu() -> void:
	if not main._tab_quest_container or not main._tab_map_container:
		return

	# Hide all tabs
	main._tab_map_container.visible = false
	main._tab_quest_container.get_parent().visible = false
	if main._tab_card_inv_container:
		main._tab_card_inv_container.get_parent().visible = false

	if main._tab_menu_current_tab == 0:
		# Dungeon Map tab
		main._tab_map_container.visible = true
		_refresh_expanded_map()
	elif main._tab_menu_current_tab == 1:
		# Quest Log tab
		main._tab_quest_container.get_parent().visible = true
		_refresh_quest_log()
	elif main._tab_menu_current_tab == 2:
		# Card Inventory tab
		if main._tab_card_inv_container:
			main._tab_card_inv_container.get_parent().visible = true
			_refresh_card_inventory()

func _refresh_quest_log() -> void:
	for child in main._tab_quest_container.get_children():
		child.queue_free()

	if not main.quest_manager:
		var no_quests = Label.new()
		no_quests.text = "No quests available."
		no_quests.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		main._tab_quest_container.add_child(no_quests)
		return

	# Active quests
	var active = main.quest_manager.get_active_quests()
	if active.size() > 0:
		var header = Label.new()
		header.text = "Active Quests"
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		main._tab_quest_container.add_child(header)

		for quest in active:
			var quest_panel = _create_quest_entry(quest)
			main._tab_quest_container.add_child(quest_panel)

	# Completed quests
	var completed = main.quest_manager.get_completed_quests()
	if completed.size() > 0:
		main._tab_quest_container.add_child(HSeparator.new())
		var header2 = Label.new()
		header2.text = "Completed Quests"
		header2.add_theme_font_size_override("font_size", 18)
		header2.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		main._tab_quest_container.add_child(header2)

		for quest in completed:
			var quest_panel = _create_quest_entry(quest)
			main._tab_quest_container.add_child(quest_panel)

	if active.is_empty() and completed.is_empty():
		var no_quests = Label.new()
		no_quests.text = "No quests yet. Talk to NPCs in town!"
		no_quests.add_theme_font_size_override("font_size", 14)
		no_quests.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		main._tab_quest_container.add_child(no_quests)

func _create_quest_entry(quest) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	style.border_width_left = 1
	style.border_color = Color(0.3, 0.3, 0.4)
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = quest.name
	name_lbl.add_theme_font_size_override("font_size", 16)
	if quest.is_complete:
		name_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = quest.description
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var progress_lbl = Label.new()
	progress_lbl.text = quest.get_objective_text()
	progress_lbl.add_theme_font_size_override("font_size", 14)
	if quest.is_complete:
		progress_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		progress_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(progress_lbl)

	return panel

func _refresh_expanded_map() -> void:
	## Renders a large dungeon map into the tab menu map texture rect.
	if not main.dungeon_manager or not main._tab_map_texture_rect:
		return

	var gw = main.dungeon_manager.GRID_W
	var gh = main.dungeon_manager.GRID_H
	var scale = 8  # Larger pixel scale for expanded view
	var img = Image.create(gw * scale, gh * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.02, 0.05, 1.0))

	# Draw tiles
	for x in range(gw):
		for z in range(gh):
			if main.dungeon_manager.is_revealed(Vector2i(x, z)):
				var col: Color
				if main.dungeon_manager.is_floor(Vector2i(x, z)):
					col = Color(0.25, 0.22, 0.2, 1.0)
				else:
					col = Color(0.12, 0.1, 0.15, 1.0)
				for px in range(scale):
					for pz in range(scale):
						img.set_pixel(x * scale + px, z * scale + pz, col)

	# Draw waypoints (larger in expanded view)
	for wp in main.dungeon_manager.waypoint_nodes:
		var wp_pos: Vector2i = wp["grid_pos"]
		var wp_col = Color(0.3, 0.7, 1.0)
		if wp["target"] == "next_world":
			wp_col = Color(0.3, 1.0, 0.4)
		elif wp["target"] == "prev_world":
			wp_col = Color(1.0, 0.8, 0.3)
		for px in range(scale):
			for pz in range(scale):
				var ix = wp_pos.x * scale + px
				var iz = wp_pos.y * scale + pz
				if ix < img.get_width() and iz < img.get_height():
					img.set_pixel(ix, iz, wp_col)

	# Draw chests
	for chest in main.dungeon_manager.chest_nodes:
		var cp: Vector2i = chest["grid_pos"]
		if not main.dungeon_manager.is_revealed(cp):
			continue
		var cc = Color(0.9, 0.7, 0.2) if not chest["opened"] else Color(0.4, 0.35, 0.2)
		for px in range(scale):
			for pz in range(scale):
				var ix = cp.x * scale + px
				var iz = cp.y * scale + pz
				if ix < img.get_width() and iz < img.get_height():
					img.set_pixel(ix, iz, cc)

	# Draw cave/building entrances (amber, slightly larger)
	for site in main.dungeon_manager.site_nodes:
		var sp: Vector2i = site["grid_pos"]
		if site["kind"] != "exit" and not main.dungeon_manager.is_revealed(sp):
			continue
		for px in range(-1, scale + 1):
			for pz in range(-1, scale + 1):
				var ix = sp.x * scale + px
				var iz = sp.y * scale + pz
				if ix >= 0 and ix < img.get_width() and iz >= 0 and iz < img.get_height():
					img.set_pixel(ix, iz, Color(1.0, 0.6, 0.15))

	# Draw enemies
	for enemy in main.enemy_spawner.get_living_enemies():
		if not enemy.visible:
			continue
		var eg = main.grid_manager.world_to_grid(enemy.position)
		for px in range(scale):
			for pz in range(scale):
				var ix = eg.x * scale + px
				var iz = eg.y * scale + pz
				if ix >= 0 and ix < img.get_width() and iz >= 0 and iz < img.get_height():
					img.set_pixel(ix, iz, Color(1.0, 0.2, 0.2))

	# Draw player (slightly larger)
	var pg = main.grid_manager.world_to_grid(main.player.position)
	for px in range(-1, scale + 1):
		for pz in range(-1, scale + 1):
			var ix = pg.x * scale + px
			var iz = pg.y * scale + pz
			if ix >= 0 and ix < img.get_width() and iz >= 0 and iz < img.get_height():
				img.set_pixel(ix, iz, Color(0.2, 1.0, 0.4))

	var tex = ImageTexture.create_from_image(img)
	main._tab_map_texture_rect.texture = tex

# ============================================
# CARD INVENTORY TAB
# ============================================

func _refresh_card_inventory() -> void:
	if not main._tab_card_inv_container:
		return

	for child in main._tab_card_inv_container.get_children():
		child.queue_free()

	var inv = main.player.get_inventory()
	if not inv:
		return

	# Header
	var header = Label.new()
	header.text = "Cards — Inventory %d/%d" % [inv.used_storage_slots(), inv.max_storage_slots]
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main._tab_card_inv_container.add_child(header)

	var desc = Label.new()
	desc.text = "Cards from enemy loot — they share your inventory slots. Add to your deck or keep for later."
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main._tab_card_inv_container.add_child(desc)

	main._tab_card_inv_container.add_child(HSeparator.new())

	if inv.stored_cards.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No cards in inventory."
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		main._tab_card_inv_container.add_child(empty_lbl)
		return

	for i in range(inv.stored_cards.size()):
		var card = inv.stored_cards[i]
		var card_row = HBoxContainer.new()
		card_row.add_theme_constant_override("separation", 12)
		main._tab_card_inv_container.add_child(card_row)

		# Card name
		var name_lbl = Label.new()
		name_lbl.text = card.card_name
		name_lbl.custom_minimum_size = Vector2(150, 0)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		card_row.add_child(name_lbl)

		# Card type
		var type_lbl = Label.new()
		var type_names = ["ATK", "DEF", "UTIL", "REACT", "UNPLAY", "POWER", "ENCH"]
		var type_idx = card.card_type as int
		type_lbl.text = type_names[type_idx] if type_idx < type_names.size() else "???"
		type_lbl.custom_minimum_size = Vector2(50, 0)
		type_lbl.add_theme_font_size_override("font_size", 12)
		type_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
		card_row.add_child(type_lbl)

		# Mana cost
		var cost_lbl = Label.new()
		cost_lbl.text = "%d mana" % card.mana_cost
		cost_lbl.custom_minimum_size = Vector2(60, 0)
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		card_row.add_child(cost_lbl)

		# Add to Deck button
		var add_btn = Button.new()
		add_btn.text = "Add to Deck"
		add_btn.custom_minimum_size = Vector2(100, 28)
		add_btn.add_theme_font_size_override("font_size", 12)
		var card_idx = i
		add_btn.pressed.connect(_on_add_card_to_deck.bind(card_idx))
		card_row.add_child(add_btn)

		# Destroy button
		var destroy_btn = Button.new()
		destroy_btn.text = "Destroy"
		destroy_btn.custom_minimum_size = Vector2(80, 28)
		destroy_btn.add_theme_font_size_override("font_size", 12)
		destroy_btn.pressed.connect(_on_destroy_stored_card.bind(card_idx))
		card_row.add_child(destroy_btn)

func _on_add_card_to_deck(card_index: int) -> void:
	var inv = main.player.get_inventory()
	if inv and main.deck_manager:
		var card = inv.get_stored_card(card_index)
		if card:
			if inv.add_card_to_deck(card_index, main.deck_manager):
				main.add_battle_log("Added %s to deck (discard pile)" % card.card_name, Color(0.4, 1.0, 0.5))
				_refresh_card_inventory()
			elif not main.deck_manager.can_add_copy(card.card_id):
				main.add_battle_log("Deck limit reached for %s (%s)." % [card.card_name, card.get_rarity_name()], Color(1.0, 0.5, 0.3))

func _on_destroy_stored_card(card_index: int) -> void:
	var inv = main.player.get_inventory()
	if inv:
		var card = inv.remove_stored_card(card_index)
		if card:
			main.add_battle_log("Destroyed %s" % card.card_name, Color(1.0, 0.4, 0.3))
			_refresh_card_inventory()
