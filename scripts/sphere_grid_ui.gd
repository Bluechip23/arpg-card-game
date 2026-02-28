class_name SphereGridUI
extends CanvasLayer

## Full-screen sphere grid overlay for the leveling system.
## Toggle with L key. Renders 100 nodes in concentric rings with connection lines.
## Click a node to open a detail popup showing card/passive info, upgrade paths, etc.

signal closed
signal node_unlocked(node_id: int)

@onready var panel: PanelContainer = $Panel
@onready var grid_canvas: Control = $GridCanvas
@onready var close_button: Button = $CloseButton
@onready var title_label: Label = $TitleLabel
@onready var info_label: Label = $InfoLabel
@onready var points_label: Label = $PointsLabel

var sphere_grid: SphereGrid
var sphere_inventory: SphereInventory
var _hovered_node_id: int = -1
var _camera_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _zoom: float = 1.0

# Detail popup state
var _popup_node_id: int = -1  # Which node's popup is open (-1 = none)
var _detail_panel: PanelContainer = null
var _unlock_button: Button = null

# Node drawing constants
const NODE_RADIUS_BASE: float = 16.0
const NODE_RADIUS_START: float = 22.0
const LINE_WIDTH: float = 3.0
const HOVER_GROW: float = 4.0

# Colors by node type
const COLOR_LOCKED := Color(0.3, 0.3, 0.35, 1.0)
const COLOR_UNLOCKED := Color(0.2, 0.8, 0.3, 1.0)
const COLOR_UNLOCKABLE := Color(0.9, 0.85, 0.2, 1.0)
const COLOR_START := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_STAT := Color(0.4, 0.6, 1.0, 1.0)
const COLOR_PASSIVE := Color(0.9, 0.5, 0.2, 1.0)
const COLOR_CARD := Color(0.8, 0.3, 0.9, 1.0)
const COLOR_HEALTH := Color(0.9, 0.2, 0.2, 1.0)
const COLOR_MANA := Color(0.2, 0.5, 1.0, 1.0)
const COLOR_LINE := Color(0.4, 0.4, 0.55, 0.85)
const COLOR_LINE_UNLOCKED := Color(0.3, 0.85, 0.4, 0.9)
const COLOR_BG := Color(0.05, 0.05, 0.08, 0.95)
const COLOR_HOVER_RING := Color(1.0, 1.0, 0.6, 0.8)

# Detail popup colors
const COLOR_POPUP_BG := Color(0.08, 0.08, 0.12, 0.97)
const COLOR_UPGRADE := Color(0.3, 0.8, 1.0)
const COLOR_TRANSMUTE := Color(1.0, 0.6, 0.2)
const COLOR_SECTION_HEADER := Color(0.7, 0.7, 0.8)
const COLOR_DIM_TEXT := Color(0.55, 0.55, 0.65)

func _ready() -> void:
	layer = 110
	sphere_grid = SphereGrid.new()
	visible = false
	_apply_styles()

	close_button.pressed.connect(_on_close_pressed)
	grid_canvas.draw.connect(_on_grid_draw)
	grid_canvas.gui_input.connect(_on_grid_input)
	grid_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	grid_canvas.resized.connect(_on_canvas_resized)

func _on_canvas_resized() -> void:
	# Redraw when the canvas gets its proper size (e.g. first time shown)
	if visible and grid_canvas.size.x > 0 and grid_canvas.size.y > 0:
		grid_canvas.queue_redraw()

func connect_sphere_inventory(inv: SphereInventory) -> void:
	sphere_inventory = inv
	sphere_inventory.spheres_changed.connect(_update_points_label)
	_update_points_label()

func _apply_styles() -> void:
	# Panel background
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.5)
	panel.add_theme_stylebox_override("panel", style)

	# Title
	title_label.text = "SPHERE GRID"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Info label (bottom, shows hovered node info)
	info_label.text = "Hover over a node to see details. Click an adjacent node to unlock with a sphere."
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Points label
	_update_points_label()
	points_label.add_theme_font_size_override("font_size", 16)
	points_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))

	# Close button
	close_button.text = "Close [L]"
	close_button.add_theme_font_size_override("font_size", 14)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.2)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.35, 0.35, 0.5)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	close_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.25, 0.35)
	close_button.add_theme_stylebox_override("hover", btn_hover)

func show_panel() -> void:
	visible = true
	_camera_offset = Vector2.ZERO
	_zoom = 1.0
	_close_detail_popup()
	_update_points_label()
	# Defer redraw to ensure layout is computed and canvas has its actual size
	grid_canvas.call_deferred("queue_redraw")

func hide_panel() -> void:
	_close_detail_popup()
	visible = false

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func _update_points_label() -> void:
	if not points_label:
		return
	if not sphere_inventory:
		points_label.text = "Spheres: --"
		return
	var parts: Array[String] = []
	var stat_count = sphere_inventory.get_count(SphereInventory.SphereType.STAT)
	var passive_count = sphere_inventory.get_count(SphereInventory.SphereType.PASSIVE)
	var card_count = sphere_inventory.get_count(SphereInventory.SphereType.CARD)
	var any_count = sphere_inventory.get_count(SphereInventory.SphereType.ANY)
	var swap_count = sphere_inventory.get_count(SphereInventory.SphereType.SWAP)
	var rune_count = sphere_inventory.upgrade_runes
	if stat_count > 0: parts.append("Stat:%d" % stat_count)
	if passive_count > 0: parts.append("Passive:%d" % passive_count)
	if card_count > 0: parts.append("Card:%d" % card_count)
	if any_count > 0: parts.append("Any:%d" % any_count)
	if swap_count > 0: parts.append("Swap:%d" % swap_count)
	if rune_count > 0: parts.append("Runes:%d" % rune_count)
	if parts.is_empty():
		points_label.text = "Spheres: None"
	else:
		points_label.text = "Spheres: " + " | ".join(parts)

func _get_canvas_size() -> Vector2:
	var sz = grid_canvas.size
	if sz.x < 1 or sz.y < 1:
		sz = get_viewport().get_visible_rect().size
	return sz

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var canvas_center = _get_canvas_size() / 2.0
	var grid_center = Vector2(640, 360)
	return canvas_center + (world_pos - grid_center + _camera_offset) * _zoom

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_center = _get_canvas_size() / 2.0
	var grid_center = Vector2(640, 360)
	return (screen_pos - canvas_center) / _zoom - _camera_offset + grid_center

func _get_node_at_screen(screen_pos: Vector2) -> int:
	if not sphere_grid:
		return -1
	for node in sphere_grid.get_all_nodes():
		var npos = _world_to_screen(node.position)
		var r = NODE_RADIUS_BASE * _zoom
		if node.id == 0:
			r = NODE_RADIUS_START * _zoom
		if screen_pos.distance_to(npos) <= r:
			return node.id
	return -1

func _get_type_color(node: SphereGrid.GridNode) -> Color:
	if node.unlocked:
		return COLOR_UNLOCKED
	if sphere_grid.is_unlockable(node.id):
		return COLOR_UNLOCKABLE
	match node.node_type:
		SphereGrid.NodeType.START:
			return COLOR_START
		SphereGrid.NodeType.STAT_BONUS:
			return COLOR_STAT
		SphereGrid.NodeType.PASSIVE:
			return COLOR_PASSIVE
		SphereGrid.NodeType.CARD:
			return COLOR_CARD
		SphereGrid.NodeType.HEALTH:
			return COLOR_HEALTH
		SphereGrid.NodeType.MANA:
			return COLOR_MANA
	return COLOR_LOCKED

func _get_node_shape(node: SphereGrid.GridNode) -> String:
	match node.node_type:
		SphereGrid.NodeType.PASSIVE:
			return "diamond"
		SphereGrid.NodeType.CARD:
			return "square"
		_:
			return "circle"

# ============================================
# DRAWING
# ============================================

func _on_grid_draw() -> void:
	if not sphere_grid:
		return

	# Skip drawing if canvas hasn't been laid out yet; the resized signal will retrigger
	if grid_canvas.size.x < 1 or grid_canvas.size.y < 1:
		grid_canvas.call_deferred("queue_redraw")
		return

	var all_nodes = sphere_grid.get_all_nodes()

	# Draw connections first (behind nodes)
	for node in all_nodes:
		var from_pos = _world_to_screen(node.position)
		for conn_id in node.connections:
			if conn_id > node.id:  # Draw each line once
				var other = sphere_grid.get_node_by_id(conn_id)
				if other:
					var to_pos = _world_to_screen(other.position)
					var line_color = COLOR_LINE
					if node.unlocked and other.unlocked:
						line_color = COLOR_LINE_UNLOCKED
					grid_canvas.draw_line(from_pos, to_pos, line_color, LINE_WIDTH * _zoom)

	# Draw nodes
	for node in all_nodes:
		var pos = _world_to_screen(node.position)
		var radius = NODE_RADIUS_BASE * _zoom
		if node.id == 0:
			radius = NODE_RADIUS_START * _zoom

		var color = _get_type_color(node)
		var shape = _get_node_shape(node)

		# Hover highlight
		var is_hovered = (node.id == _hovered_node_id)
		# Selected node highlight (popup open)
		var is_selected = (node.id == _popup_node_id)
		if is_hovered or is_selected:
			radius += HOVER_GROW * _zoom

		# Draw shape
		match shape:
			"circle":
				grid_canvas.draw_circle(pos, radius, color)
				if is_hovered or is_selected:
					var ring_color = COLOR_HOVER_RING if not is_selected else Color(1.0, 0.9, 0.3, 1.0)
					grid_canvas.draw_arc(pos, radius + 2 * _zoom, 0, TAU, 32, ring_color, 2.0 * _zoom)
			"diamond":
				var pts = PackedVector2Array([
					pos + Vector2(0, -radius),
					pos + Vector2(radius, 0),
					pos + Vector2(0, radius),
					pos + Vector2(-radius, 0),
				])
				grid_canvas.draw_colored_polygon(pts, color)
				if is_hovered or is_selected:
					var outline = pts.duplicate()
					outline.append(pts[0])
					var ring_color = COLOR_HOVER_RING if not is_selected else Color(1.0, 0.9, 0.3, 1.0)
					grid_canvas.draw_polyline(outline, ring_color, 2.0 * _zoom)
			"square":
				var rect = Rect2(pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
				grid_canvas.draw_rect(rect, color)
				if is_hovered or is_selected:
					var ring_color = COLOR_HOVER_RING if not is_selected else Color(1.0, 0.9, 0.3, 1.0)
					grid_canvas.draw_rect(rect.grow(2 * _zoom), ring_color, false, 2.0 * _zoom)

		# Draw unlocked checkmark or lock
		if node.unlocked and node.id != 0:
			grid_canvas.draw_circle(pos, 4.0 * _zoom, Color(0.0, 0.2, 0.0))

		# Draw label text
		var font = ThemeDB.fallback_font
		var font_size = int(10 * _zoom)
		if font and font_size >= 6:
			var text_size = font.get_string_size(node.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos = pos - Vector2(text_size.x / 2.0, -radius - 4 * _zoom)
			grid_canvas.draw_string(font, text_pos, node.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.9, 0.9, 0.9))

	# Draw legend
	_draw_legend()

func _draw_legend() -> void:
	var legend_x = 20.0
	var legend_y = 60.0
	var spacing = 22.0
	var font = ThemeDB.fallback_font
	var font_size = 12
	if not font:
		return

	var entries = [
		[COLOR_STAT, "circle", "Stat Bonus"],
		[COLOR_PASSIVE, "diamond", "Passive"],
		[COLOR_CARD, "square", "Card"],
		[COLOR_HEALTH, "circle", "Health"],
		[COLOR_MANA, "circle", "Mana"],
		[COLOR_UNLOCKED, "circle", "Unlocked"],
		[COLOR_UNLOCKABLE, "circle", "Available"],
		[COLOR_LOCKED, "circle", "Locked"],
	]

	for i in range(entries.size()):
		var y = legend_y + i * spacing
		var color: Color = entries[i][0]
		var shape: String = entries[i][1]
		var label: String = entries[i][2]

		match shape:
			"circle":
				grid_canvas.draw_circle(Vector2(legend_x + 8, y), 6, color)
			"diamond":
				var pts = PackedVector2Array([
					Vector2(legend_x + 8, y - 6),
					Vector2(legend_x + 14, y),
					Vector2(legend_x + 8, y + 6),
					Vector2(legend_x + 2, y),
				])
				grid_canvas.draw_colored_polygon(pts, color)
			"square":
				grid_canvas.draw_rect(Rect2(legend_x + 2, y - 6, 12, 12), color)

		grid_canvas.draw_string(font, Vector2(legend_x + 22, y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.8, 0.8, 0.85))

# ============================================
# INPUT
# ============================================

func _on_grid_input(event: InputEvent) -> void:
	if not visible or not sphere_grid:
		return

	# Mouse motion — hover detection + drag panning
	if event is InputEventMouseMotion:
		if _dragging:
			_camera_offset += event.relative / _zoom
			grid_canvas.queue_redraw()
		else:
			var local_pos = grid_canvas.get_local_mouse_position()
			var old_hover = _hovered_node_id
			_hovered_node_id = _get_node_at_screen(local_pos)
			if _hovered_node_id != old_hover:
				_update_info_label()
				grid_canvas.queue_redraw()

	# Mouse button — click opens detail popup, middle/right drag to pan, scroll to zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = grid_canvas.get_local_mouse_position()
			var clicked_id = _get_node_at_screen(local_pos)
			if clicked_id >= 0:
				_open_detail_popup(clicked_id)
			else:
				# Clicked empty space — close popup
				_close_detail_popup()

		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			if event.pressed:
				_drag_start = event.position
				_close_detail_popup()

		# Scroll zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 1.1, 0.4, 2.5)
			_close_detail_popup()
			grid_canvas.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom / 1.1, 0.4, 2.5)
			_close_detail_popup()
			grid_canvas.queue_redraw()

# ============================================
# NODE DETAIL POPUP
# ============================================

func _open_detail_popup(node_id: int) -> void:
	var node = sphere_grid.get_node_by_id(node_id)
	if not node:
		return

	# Close existing popup
	_close_detail_popup()
	_popup_node_id = node_id
	grid_canvas.queue_redraw()

	# Build the popup panel
	_detail_panel = PanelContainer.new()
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = COLOR_POPUP_BG
	popup_style.border_width_left = 2
	popup_style.border_width_right = 2
	popup_style.border_width_top = 2
	popup_style.border_width_bottom = 2
	popup_style.border_color = _get_type_color(node).lerp(Color.WHITE, 0.3)
	popup_style.corner_radius_top_left = 6
	popup_style.corner_radius_top_right = 6
	popup_style.corner_radius_bottom_left = 6
	popup_style.corner_radius_bottom_right = 6
	popup_style.content_margin_left = 14
	popup_style.content_margin_right = 14
	popup_style.content_margin_top = 10
	popup_style.content_margin_bottom = 10
	_detail_panel.add_theme_stylebox_override("panel", popup_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_detail_panel.add_child(vbox)

	# --- Header: node name + type ---
	var type_name = _get_type_name(node.node_type)
	var status_text = "UNLOCKED" if node.unlocked else ("AVAILABLE" if sphere_grid.is_unlockable(node.id) else "LOCKED")
	_add_popup_label(vbox, node.label, 18, _get_type_color(node))
	_add_popup_label(vbox, "%s  |  %s  |  Ring %d" % [type_name, status_text, node.ring], 12, COLOR_DIM_TEXT)

	# --- Separator ---
	_add_popup_separator(vbox)

	# --- Content based on node type ---
	match node.node_type:
		SphereGrid.NodeType.CARD:
			_build_card_popup_content(vbox, node)
		SphereGrid.NodeType.PASSIVE:
			_build_passive_popup_content(vbox, node)
		SphereGrid.NodeType.STAT_BONUS, SphereGrid.NodeType.HEALTH, SphereGrid.NodeType.MANA:
			_build_stat_popup_content(vbox, node)
		SphereGrid.NodeType.START:
			_add_popup_label(vbox, "Starting node — always unlocked.", 13, Color(0.8, 0.8, 0.85))

	# --- Unlock button (if unlockable and not yet unlocked) ---
	if not node.unlocked and node.node_type != SphereGrid.NodeType.START:
		_add_popup_separator(vbox)
		_add_unlock_section(vbox, node)

	# --- Close hint ---
	_add_popup_label(vbox, "Click elsewhere or right-click to close", 10, Color(0.4, 0.4, 0.5))

	# Add popup directly to the CanvasLayer so it sits on top of everything
	add_child(_detail_panel)

	# Position near the node but keep on screen
	_position_popup(node)

func _close_detail_popup() -> void:
	if _detail_panel and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
	_detail_panel = null
	_unlock_button = null
	_popup_node_id = -1
	grid_canvas.queue_redraw()

func _position_popup(node: SphereGrid.GridNode) -> void:
	if not _detail_panel:
		return

	# Wait one frame for the popup to compute its size
	await get_tree().process_frame

	if not is_instance_valid(_detail_panel):
		return

	var node_screen_pos = _world_to_screen(node.position)
	var popup_size = _detail_panel.size
	var screen_size = get_viewport().get_visible_rect().size

	# Default: to the right of the node
	var px = node_screen_pos.x + 30
	var py = node_screen_pos.y - popup_size.y / 2.0

	# Clamp to screen
	if px + popup_size.x > screen_size.x - 10:
		px = node_screen_pos.x - popup_size.x - 30
	if py < 45:
		py = 45
	if py + popup_size.y > screen_size.y - 40:
		py = screen_size.y - 40 - popup_size.y

	_detail_panel.position = Vector2(px, py)

# ============================================
# POPUP CONTENT BUILDERS
# ============================================

func _build_card_popup_content(vbox: VBoxContainer, node: SphereGrid.GridNode) -> void:
	# Show card info
	if node.card_id != "":
		var card = _try_create_card(node.card_id)
		if card:
			_add_popup_label(vbox, card.card_name, 16, Color(0.95, 0.95, 1.0))
			var cost_text = "Cost: %d Mana  |  %d Tempo" % [card.mana_cost, card.tempo_cost]
			_add_popup_label(vbox, cost_text, 12, COLOR_DIM_TEXT)
			_add_popup_label(vbox, card.description, 13, Color(0.8, 0.8, 0.9))

			if card.card_type == Card.CardType.ATTACK and card.damage > 0:
				_add_popup_label(vbox, "Damage: %d" % card.damage, 12, Color(1.0, 0.5, 0.5))
			if card.card_type == Card.CardType.DEFENSE and card.block > 0:
				_add_popup_label(vbox, "Block: %d" % card.block, 12, Color(0.5, 0.7, 1.0))
			if card.heal_amount > 0:
				_add_popup_label(vbox, "Heal: %d" % card.heal_amount, 12, Color(0.5, 1.0, 0.5))
			if card.is_ranged:
				_add_popup_label(vbox, "Ranged  |  %s" % card.get_range_display(), 12, Color(0.8, 0.8, 0.5))
		else:
			_add_popup_label(vbox, "Card: %s" % node.card_id, 14, Color(0.8, 0.8, 0.9))
	else:
		_add_popup_label(vbox, node.description, 14, Color(0.8, 0.8, 0.9))

	# Upgrade paths
	if node.upgrade_paths.size() > 0:
		_add_popup_separator(vbox)
		_add_popup_label(vbox, "UPGRADE PATHS", 12, COLOR_SECTION_HEADER)
		for i in range(node.upgrade_paths.size()):
			var path = node.upgrade_paths[i]
			_add_popup_label(vbox, "%d. %s" % [i + 1, path["label"]], 13, COLOR_UPGRADE)
			_add_popup_label(vbox, "   %s" % path["description"], 11, COLOR_DIM_TEXT)

	# Transmute paths
	if node.transmute_paths.size() > 0:
		_add_popup_separator(vbox)
		_add_popup_label(vbox, "TRANSMUTE PATHS", 12, COLOR_SECTION_HEADER)
		for i in range(node.transmute_paths.size()):
			var path = node.transmute_paths[i]
			_add_popup_label(vbox, "%d. %s" % [i + 1, path["label"]], 13, COLOR_TRANSMUTE)
			_add_popup_label(vbox, "   %s" % path["description"], 11, COLOR_DIM_TEXT)

func _build_passive_popup_content(vbox: VBoxContainer, node: SphereGrid.GridNode) -> void:
	_add_popup_label(vbox, node.description, 14, Color(0.95, 0.8, 0.5))

	# Upgrade paths
	if node.upgrade_paths.size() > 0:
		_add_popup_separator(vbox)
		_add_popup_label(vbox, "UPGRADE PATHS", 12, COLOR_SECTION_HEADER)
		for i in range(node.upgrade_paths.size()):
			var path = node.upgrade_paths[i]
			_add_popup_label(vbox, "%d. %s" % [i + 1, path["label"]], 13, COLOR_UPGRADE)
			_add_popup_label(vbox, "   %s" % path["description"], 11, COLOR_DIM_TEXT)

	# Transmute paths
	if node.transmute_paths.size() > 0:
		_add_popup_separator(vbox)
		_add_popup_label(vbox, "TRANSMUTE PATHS", 12, COLOR_SECTION_HEADER)
		for i in range(node.transmute_paths.size()):
			var path = node.transmute_paths[i]
			_add_popup_label(vbox, "%d. %s" % [i + 1, path["label"]], 13, COLOR_TRANSMUTE)
			_add_popup_label(vbox, "   %s" % path["description"], 11, COLOR_DIM_TEXT)

func _build_stat_popup_content(vbox: VBoxContainer, node: SphereGrid.GridNode) -> void:
	_add_popup_label(vbox, node.description, 15, Color(0.8, 0.9, 1.0))

	# Provide context on what the stat does
	var stat_detail = _get_stat_detail(node.label)
	if stat_detail != "":
		_add_popup_label(vbox, stat_detail, 11, COLOR_DIM_TEXT)

func _get_stat_detail(label: String) -> String:
	if label.begins_with("STR"):
		return "Strength: +carry capacity, +physical damage"
	elif label.begins_with("DEX"):
		return "Dexterity: faster attack speed proc"
	elif label.begins_with("INT"):
		return "Intelligence: +spell damage, +mana regen"
	elif label.begins_with("WIS"):
		return "Wisdom: +hand size, faster card draw"
	elif label.begins_with("AGI"):
		return "Agility: +movement per tempo cycle"
	elif label.begins_with("DET"):
		return "Determination: stats scale with missing HP"
	elif label.begins_with("HP"):
		return "Increases maximum health pool"
	elif label.begins_with("Mana"):
		return "Increases maximum mana pool"
	return ""

func _add_unlock_section(vbox: VBoxContainer, node: SphereGrid.GridNode) -> void:
	var req_type = SphereInventory.get_required_sphere_type(node.node_type)
	var type_name = SphereInventory.get_sphere_name(req_type) if req_type >= 0 else "Unknown"

	var can_unlock = sphere_grid.is_unlockable(node.id) and sphere_inventory and sphere_inventory.has_sphere_for_node(node.node_type)

	if not sphere_grid.is_unlockable(node.id):
		_add_popup_label(vbox, "Must be adjacent to an unlocked node", 12, Color(0.7, 0.3, 0.3))
	elif not sphere_inventory or not sphere_inventory.has_sphere_for_node(node.node_type):
		_add_popup_label(vbox, "Requires: %s sphere (or Any)" % type_name, 12, Color(0.7, 0.3, 0.3))
	else:
		_add_popup_label(vbox, "Costs 1 %s sphere" % type_name, 12, Color(0.5, 0.8, 0.5))

	_unlock_button = Button.new()
	_unlock_button.text = "Unlock Node" if can_unlock else "Cannot Unlock"
	_unlock_button.disabled = not can_unlock
	_unlock_button.add_theme_font_size_override("font_size", 14)
	_unlock_button.custom_minimum_size = Vector2(180, 32)

	var btn_style = StyleBoxFlat.new()
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	if can_unlock:
		btn_style.bg_color = Color(0.15, 0.4, 0.2)
		btn_style.border_color = Color(0.3, 0.7, 0.4)
	else:
		btn_style.bg_color = Color(0.2, 0.2, 0.2)
		btn_style.border_color = Color(0.35, 0.35, 0.35)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	_unlock_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.5, 0.3) if can_unlock else Color(0.2, 0.2, 0.2)
	_unlock_button.add_theme_stylebox_override("hover", btn_hover)

	_unlock_button.pressed.connect(_on_unlock_pressed)
	vbox.add_child(_unlock_button)

func _on_unlock_pressed() -> void:
	if _popup_node_id < 0:
		return
	var node = sphere_grid.get_node_by_id(_popup_node_id)
	if not node or node.unlocked:
		return
	if not sphere_grid.is_unlockable(_popup_node_id):
		return
	if not sphere_inventory or not sphere_inventory.has_sphere_for_node(node.node_type):
		return

	sphere_inventory.spend_sphere_for_node(node.node_type)
	sphere_grid.unlock_node(_popup_node_id)
	_update_points_label()
	_set_info("Unlocked: %s — %s" % [node.label, node.description])
	node_unlocked.emit(_popup_node_id)

	# Refresh popup to show new state
	var node_id = _popup_node_id
	_close_detail_popup()
	_open_detail_popup(node_id)

# ============================================
# POPUP HELPERS
# ============================================

func _add_popup_label(parent: VBoxContainer, text: String, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 280
	parent.add_child(label)
	return label

func _add_popup_separator(parent: VBoxContainer) -> void:
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	sep.add_theme_constant_override("separation", 4)
	parent.add_child(sep)

func _try_create_card(card_id: String) -> Card:
	## Try to instantiate a card by ID so we can show its details.
	var method_name = "create_" + card_id
	var temp = Card.new()
	if temp.has_method(method_name):
		return temp.call(method_name)
	return null

# ============================================
# INFO LABEL / HELPERS
# ============================================

func _update_info_label() -> void:
	if _hovered_node_id < 0:
		info_label.text = "Hover over a node to see details. Click to open node details."
		return
	var node = sphere_grid.get_node_by_id(_hovered_node_id)
	if not node:
		return
	var status = "UNLOCKED" if node.unlocked else ("AVAILABLE" if sphere_grid.is_unlockable(node.id) else "LOCKED")
	var type_name = _get_type_name(node.node_type)
	var sphere_hint = ""
	if not node.unlocked and node.node_type != SphereGrid.NodeType.START:
		var req = SphereInventory.get_required_sphere_type(node.node_type)
		if req >= 0:
			sphere_hint = " [Requires: %s sphere]" % SphereInventory.get_sphere_name(req)
	info_label.text = "[%s] %s (%s) — %s%s" % [status, node.label, type_name, node.description, sphere_hint]

func _set_info(text: String) -> void:
	info_label.text = text

func _get_type_name(t: SphereGrid.NodeType) -> String:
	match t:
		SphereGrid.NodeType.STAT_BONUS: return "Stat Bonus"
		SphereGrid.NodeType.PASSIVE: return "Passive"
		SphereGrid.NodeType.CARD: return "Card"
		SphereGrid.NodeType.HEALTH: return "Health"
		SphereGrid.NodeType.MANA: return "Mana"
		SphereGrid.NodeType.START: return "Start"
	return "Unknown"

func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()
