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
@onready var info_panel: PanelContainer = $InfoPanel
@onready var info_label: Label = $InfoPanel/MarginContainer/InfoLabel
@onready var points_label: Label = $PointsLabel

var sphere_grid: SphereGrid
var sphere_inventory: SphereInventory
var player_stats = null  # PlayerStats — for stat-gated node requirements (set by main.gd)
var _hovered_node_id: int = -1
var _camera_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _zoom: float = 1.0

# Left-click vs drag disambiguation
var _left_pressed: bool = false
var _left_press_pos: Vector2 = Vector2.ZERO
var _left_dragged: bool = false
const _DRAG_THRESHOLD: float = 6.0  # Pixels of movement before a left-click becomes a drag

# Detail popup state
var _popup_node_id: int = -1  # Which node's popup is open (-1 = none)
var _detail_panel: PanelContainer = null
var _unlock_button: Button = null

# Constellation UI state
var _hovered_constellation_id: String = ""  # Constellation being hovered in the list
var _constellation_list_panel: PanelContainer = null
var _constellation_list_vbox: VBoxContainer = null
var _constellation_list_collapsed: bool = false  # When true, only the header row is shown
var _constellation_hover_panel: PanelContainer = null  # Tooltip shown on hover

# Constellation confirmation modal state
var _constellation_modal: PanelContainer = null
var _constellation_modal_overlay: ColorRect = null  # Dim background
var _pending_constellation_id: String = ""  # Constellation awaiting confirmation
var _conflicting_constellation_id: String = ""  # Active constellation that would be replaced

# Node drawing constants
const NODE_RADIUS_BASE: float = 16.0
const NODE_RADIUS_START: float = 22.0
const LINE_WIDTH: float = 3.0
const HOVER_GROW: float = 4.0

# Colors by node type
const COLOR_LOCKED := Color(0.65, 0.65, 0.72, 1.0)
const COLOR_UNLOCKED := Color(0.35, 1.0, 0.5, 1.0)
const COLOR_UNLOCKABLE := Color(1.0, 0.95, 0.35, 1.0)
const COLOR_START := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_STAT := Color(0.6, 0.8, 1.0, 1.0)
const COLOR_PASSIVE := Color(1.0, 0.7, 0.35, 1.0)
const COLOR_COMBAT := Color(1.0, 0.85, 0.35, 1.0)  # Gold/amber for combat bonus nodes
const COLOR_HEALTH := Color(1.0, 0.4, 0.4, 1.0)
const COLOR_MANA := Color(0.4, 0.7, 1.0, 1.0)
const COLOR_CULLING := Color(1.0, 0.35, 0.65, 1.0)  # Crimson/hot-pink - distinct from purple passives
const COLOR_RETROSPECTIVE := Color(0.4, 1.0, 0.95, 1.0)  # Teal/cyan - retrospective nodes
const COLOR_FEATHER := Color(0.95, 0.85, 0.45, 1.0)  # Warm gold - feather nodes for card removal
const COLOR_FREE_STAT := Color(0.75, 0.55, 1.0, 1.0)  # Bright violet - freely-allocatable stat points
const COLOR_LINE := Color(0.65, 0.65, 0.8, 1.0)
const COLOR_LINE_UNLOCKED := Color(0.5, 1.0, 0.6, 1.0)
const COLOR_BG := Color(0.08, 0.08, 0.13, 0.97)
const COLOR_HOVER_RING := Color(1.0, 1.0, 0.6, 0.9)

# Detail popup colors
const COLOR_POPUP_BG := Color(0.14, 0.14, 0.2, 0.97)
const COLOR_SECTION_HEADER := Color(0.8, 0.8, 0.9)
const COLOR_DIM_TEXT := Color(0.65, 0.65, 0.75)

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

	_build_constellation_list_panel()

	# Hide our own title/close button — the parent SkillTreeUI provides those
	title_label.visible = false
	close_button.visible = false

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

	# Info panel (bottom-left, opaque background for hover descriptions)
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	info_style.border_width_left = 2
	info_style.border_width_right = 2
	info_style.border_width_top = 2
	info_style.border_width_bottom = 2
	info_style.border_color = Color(0.35, 0.35, 0.55)
	info_style.corner_radius_top_left = 6
	info_style.corner_radius_top_right = 6
	info_style.corner_radius_bottom_left = 6
	info_style.corner_radius_bottom_right = 6
	info_style.content_margin_left = 10.0
	info_style.content_margin_right = 10.0
	info_style.content_margin_top = 8.0
	info_style.content_margin_bottom = 8.0
	info_panel.add_theme_stylebox_override("panel", info_style)

	info_label.text = ""
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(260, 0)
	info_panel.visible = false

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
	_refresh_constellation_list()
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
	var sphere_count = sphere_inventory.get_count(SphereInventory.SphereType.SPHERE)
	var text = "Spheres: %d" % sphere_count
	var retro_count = sphere_inventory.retrospective_tokens
	if retro_count > 0:
		text += " | Retro: %d" % retro_count
	points_label.text = text

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
		elif node.node_type == SphereGrid.NodeType.NULL_NODE:
			r *= 0.55  # Null connectors are visibly smaller
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
		SphereGrid.NodeType.NULL_NODE:
			return Color(0.35, 0.35, 0.42)  # muted — it grants nothing
		SphereGrid.NodeType.KEYSTONE:
			return Color(1.0, 0.8, 0.3)     # gold — build-defining
		SphereGrid.NodeType.STAT_BONUS:
			return COLOR_STAT
		SphereGrid.NodeType.FREE_STAT:
			return COLOR_FREE_STAT
		SphereGrid.NodeType.PASSIVE:
			return COLOR_PASSIVE
		SphereGrid.NodeType.COMBAT_BONUS:
			return COLOR_COMBAT
		SphereGrid.NodeType.HEALTH:
			return COLOR_HEALTH
		SphereGrid.NodeType.MANA:
			return COLOR_MANA
		SphereGrid.NodeType.CULLING_STONE:
			return COLOR_CULLING
		SphereGrid.NodeType.FEATHER:
			return COLOR_FEATHER
		SphereGrid.NodeType.RETROSPECTIVE:
			return COLOR_RETROSPECTIVE
	return COLOR_LOCKED

func _get_node_shape(node: SphereGrid.GridNode) -> String:
	match node.node_type:
		SphereGrid.NodeType.PASSIVE:
			return "diamond"
		SphereGrid.NodeType.FREE_STAT:
			return "star"
		SphereGrid.NodeType.COMBAT_BONUS:
			return "square"
		SphereGrid.NodeType.CULLING_STONE:
			return "hexagon"
		SphereGrid.NodeType.FEATHER:
			return "hexagon"
		SphereGrid.NodeType.RETROSPECTIVE:
			return "star"
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

	# Build set of constellation edges for coloring (completed constellations + hovered)
	var constellation_edge_colors: Dictionary = {}  # "min_max" -> Color
	var constellation_node_sets: Dictionary = {}  # constellation_id -> node_id set
	for c in sphere_grid.get_all_constellations():
		var is_active = c.completed or c.id == _hovered_constellation_id
		if not is_active:
			continue
		var edges = sphere_grid.get_constellation_edges(c.id)
		var alpha = 1.0 if c.completed else 0.75
		for edge in edges:
			var key = "%d_%d" % [mini(edge[0], edge[1]), maxi(edge[0], edge[1])]
			constellation_edge_colors[key] = Color(c.color.r, c.color.g, c.color.b, alpha)

	# Draw constellation shaded areas (behind everything)
	_draw_constellation_fills()

	# Draw connections first (behind nodes)
	for node in all_nodes:
		var from_pos = _world_to_screen(node.position)
		for conn_id in node.connections:
			if conn_id > node.id:  # Draw each line once
				var other = sphere_grid.get_node_by_id(conn_id)
				if other:
					var to_pos = _world_to_screen(other.position)
					var edge_key = "%d_%d" % [mini(node.id, conn_id), maxi(node.id, conn_id)]
					var line_color = COLOR_LINE
					if edge_key in constellation_edge_colors:
						line_color = constellation_edge_colors[edge_key]
						# Draw constellation edges thicker and with glow
						grid_canvas.draw_line(from_pos, to_pos, Color(line_color.r, line_color.g, line_color.b, 0.5), (LINE_WIDTH + 6) * _zoom)
						grid_canvas.draw_line(from_pos, to_pos, line_color, (LINE_WIDTH + 2) * _zoom)
					elif node.unlocked and other.unlocked:
						line_color = COLOR_LINE_UNLOCKED
						grid_canvas.draw_line(from_pos, to_pos, line_color, LINE_WIDTH * _zoom)
					else:
						grid_canvas.draw_line(from_pos, to_pos, line_color, LINE_WIDTH * _zoom)

	# Draw nodes
	for node in all_nodes:
		var pos = _world_to_screen(node.position)
		var radius = NODE_RADIUS_BASE * _zoom
		if node.id == 0:
			radius = NODE_RADIUS_START * _zoom
		elif node.node_type == SphereGrid.NodeType.NULL_NODE:
			radius *= 0.55  # Null connectors are visibly smaller

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
			"hexagon":
				var hex_pts = PackedVector2Array()
				for hi in range(6):
					var ha = TAU / 6.0 * hi - PI / 6.0  # Flat-top hexagon
					hex_pts.append(pos + Vector2(cos(ha), sin(ha)) * radius)
				grid_canvas.draw_colored_polygon(hex_pts, color)
				if is_hovered or is_selected:
					var outline = hex_pts.duplicate()
					outline.append(hex_pts[0])
					var ring_color = COLOR_HOVER_RING if not is_selected else Color(1.0, 0.9, 0.3, 1.0)
					grid_canvas.draw_polyline(outline, ring_color, 2.0 * _zoom)
			"star":
				var star_pts = PackedVector2Array()
				for si in range(10):
					var sa = TAU / 10.0 * si - PI / 2.0
					var sr = radius if si % 2 == 0 else radius * 0.5
					star_pts.append(pos + Vector2(cos(sa), sin(sa)) * sr)
				grid_canvas.draw_colored_polygon(star_pts, color)
				if is_hovered or is_selected:
					var outline = star_pts.duplicate()
					outline.append(star_pts[0])
					var ring_color = COLOR_HOVER_RING if not is_selected else Color(1.0, 0.9, 0.3, 1.0)
					grid_canvas.draw_polyline(outline, ring_color, 2.0 * _zoom)

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
		[COLOR_COMBAT, "square", "Combat Bonus"],
		[COLOR_HEALTH, "circle", "Health"],
		[COLOR_MANA, "circle", "Mana"],
		[COLOR_CULLING, "hexagon", "Culling Stone"],
		[COLOR_FEATHER, "hexagon", "Feather"],
		[COLOR_FREE_STAT, "star", "Free Stats"],
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
			"hexagon":
				var hex_pts = PackedVector2Array()
				for hi in range(6):
					var ha = TAU / 6.0 * hi - PI / 6.0
					hex_pts.append(Vector2(legend_x + 8, y) + Vector2(cos(ha), sin(ha)) * 6)
				grid_canvas.draw_colored_polygon(hex_pts, color)
			"star":
				var star_pts = PackedVector2Array()
				for si in range(10):
					var sa = TAU / 10.0 * si - PI / 2.0
					var sr = 6.0 if si % 2 == 0 else 3.0
					star_pts.append(Vector2(legend_x + 8, y) + Vector2(cos(sa), sin(sa)) * sr)
				grid_canvas.draw_colored_polygon(star_pts, color)

		grid_canvas.draw_string(font, Vector2(legend_x + 22, y + 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.8, 0.8, 0.85))

# ============================================
# CONSTELLATION RENDERING
# ============================================

func _draw_constellation_fills() -> void:
	## Draws translucent filled polygons for completed or hovered constellations.
	if not sphere_grid:
		return
	for c in sphere_grid.get_all_constellations():
		var is_active = c.completed or c.id == _hovered_constellation_id
		if not is_active:
			continue

		# Collect screen positions of constellation nodes
		var positions: Array[Vector2] = []
		for nid in c.node_ids:
			var node = sphere_grid.get_node_by_id(nid)
			if node:
				positions.append(_world_to_screen(node.position))

		if positions.size() < 3:
			continue

		# Compute convex hull for the fill polygon
		var hull = _convex_hull(positions)
		if hull.size() < 3:
			continue

		var fill_alpha = 0.25 if c.completed else 0.15
		var fill_color = Color(c.color.r, c.color.g, c.color.b, fill_alpha)
		var packed = PackedVector2Array(hull)
		grid_canvas.draw_colored_polygon(packed, fill_color)

		# Draw hull outline
		var outline_alpha = 0.6 if c.completed else 0.35
		var outline_color = Color(c.color.r, c.color.g, c.color.b, outline_alpha)
		var outline = PackedVector2Array(hull)
		outline.append(hull[0])  # Close the loop
		grid_canvas.draw_polyline(outline, outline_color, 2.0 * _zoom)

func _convex_hull(points: Array[Vector2]) -> Array[Vector2]:
	## Computes the convex hull of a set of 2D points using the gift-wrapping algorithm.
	if points.size() < 3:
		return points

	# Find the leftmost point
	var start_idx = 0
	for i in range(1, points.size()):
		if points[i].x < points[start_idx].x or (points[i].x == points[start_idx].x and points[i].y < points[start_idx].y):
			start_idx = i

	var hull: Array[Vector2] = []
	var current = start_idx
	var iterations = 0
	while true:
		hull.append(points[current])
		var next = 0
		for i in range(points.size()):
			if i == current:
				continue
			if next == current:
				next = i
				continue
			# Cross product to determine turn direction
			var cross = (points[i] - points[current]).cross(points[next] - points[current])
			if cross > 0:
				next = i
			elif cross == 0:
				# Collinear — pick the farther point
				if points[current].distance_squared_to(points[i]) > points[current].distance_squared_to(points[next]):
					next = i
		current = next
		iterations += 1
		if current == start_idx or iterations > points.size() + 2:
			break
	return hull

# ============================================
# CONSTELLATION LIST PANEL
# ============================================

func _build_constellation_list_panel() -> void:
	## Creates the constellation list panel on the left side of the screen.
	_constellation_list_panel = PanelContainer.new()
	_constellation_list_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.3, 0.5)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	_constellation_list_panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	_constellation_list_panel.add_child(margin)

	_constellation_list_vbox = VBoxContainer.new()
	_constellation_list_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(_constellation_list_vbox)

	# Position: left side, below the legend area
	_constellation_list_panel.position = Vector2(10, 270)
	_constellation_list_panel.custom_minimum_size = Vector2(200, 0)

	add_child(_constellation_list_panel)
	_constellation_list_panel.visible = false

	# Build hover tooltip
	_constellation_hover_panel = PanelContainer.new()
	_constellation_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hover_style = panel_style.duplicate()
	hover_style.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	hover_style.border_color = Color(0.5, 0.5, 0.7)
	hover_style.content_margin_left = 12
	hover_style.content_margin_right = 12
	hover_style.content_margin_top = 8
	hover_style.content_margin_bottom = 8
	_constellation_hover_panel.add_theme_stylebox_override("panel", hover_style)
	_constellation_hover_panel.visible = false
	add_child(_constellation_hover_panel)

func _refresh_constellation_list() -> void:
	## Rebuilds the constellation list entries.
	if not _constellation_list_vbox or not sphere_grid:
		return

	# Clear existing entries
	for child in _constellation_list_vbox.get_children():
		child.queue_free()

	_constellation_list_panel.visible = true

	# Header row: title + minimize/restore toggle
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.custom_minimum_size = Vector2(180, 0)

	var title = Label.new()
	title.text = "CONSTELLATIONS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var toggle = Button.new()
	toggle.text = "+" if _constellation_list_collapsed else "-"
	toggle.tooltip_text = "Expand" if _constellation_list_collapsed else "Minimize"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.custom_minimum_size = Vector2(22, 22)
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.pressed.connect(_on_constellation_list_toggle)
	header.add_child(toggle)

	_constellation_list_vbox.add_child(header)

	# When minimized, show only the header so the list stays out of the way.
	if _constellation_list_collapsed:
		return

	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	sep.add_theme_constant_override("separation", 2)
	_constellation_list_vbox.add_child(sep)

	# Add each constellation entry
	for c in sphere_grid.get_all_constellations():
		var progress = sphere_grid.get_constellation_progress(c.id)
		var entry = _create_constellation_entry(c, progress)
		_constellation_list_vbox.add_child(entry)

func _on_constellation_list_toggle() -> void:
	## Collapse/expand the constellation list, leaving just its header visible.
	_constellation_list_collapsed = not _constellation_list_collapsed
	_refresh_constellation_list()

func _create_constellation_entry(c: SphereGrid.Constellation, progress: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.custom_minimum_size = Vector2(180, 24)

	# Color indicator dot
	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size = Vector2(10, 10)
	dot.color = c.color if c.completed else Color(c.color.r, c.color.g, c.color.b, 0.75)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_center = CenterContainer.new()
	dot_center.custom_minimum_size = Vector2(12, 24)
	dot_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_center.add_child(dot)
	hbox.add_child(dot_center)

	# Name + progress
	var label = Label.new()
	var status_text = ""
	if c.completed:
		status_text = " [ACTIVE]"
	else:
		status_text = " (%d/%d)" % [progress["unlocked"], progress["total"]]

	label.text = c.name + status_text
	label.add_theme_font_size_override("font_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c.completed:
		label.add_theme_color_override("font_color", Color(c.color.r * 0.8 + 0.2, c.color.g * 0.8 + 0.2, c.color.b * 0.8 + 0.2))
	else:
		label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	hbox.add_child(label)

	# Mouse hover handling
	hbox.gui_input.connect(_on_constellation_entry_input.bind(c.id))
	hbox.mouse_entered.connect(_on_constellation_entry_hover.bind(c.id, hbox))
	hbox.mouse_exited.connect(_on_constellation_entry_unhover)

	return hbox

func _on_constellation_entry_hover(constellation_id: String, entry: HBoxContainer) -> void:
	_hovered_constellation_id = constellation_id
	grid_canvas.queue_redraw()
	_show_constellation_hover_tooltip(constellation_id, entry)

func _on_constellation_entry_unhover() -> void:
	_hovered_constellation_id = ""
	grid_canvas.queue_redraw()
	_constellation_hover_panel.visible = false

func _on_constellation_entry_input(event: InputEvent, constellation_id: String) -> void:
	# Clicking a constellation could pan to center it
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pan_to_constellation(constellation_id)

func _pan_to_constellation(constellation_id: String) -> void:
	## Centers the camera on the constellation's node cluster.
	var c = sphere_grid.get_constellation(constellation_id)
	if not c:
		return
	var center_pos = Vector2.ZERO
	var count = 0
	for nid in c.node_ids:
		var node = sphere_grid.get_node_by_id(nid)
		if node:
			center_pos += node.position
			count += 1
	if count > 0:
		center_pos /= count
		# Set camera offset so this position is at screen center
		var grid_center = Vector2(640, 360)
		_camera_offset = grid_center - center_pos
		_close_detail_popup()
		grid_canvas.queue_redraw()

func _show_constellation_hover_tooltip(constellation_id: String, entry: HBoxContainer) -> void:
	## Shows a detailed tooltip to the right of the hovered constellation entry.
	var c = sphere_grid.get_constellation(constellation_id)
	if not c:
		return

	# Clear existing tooltip content
	for child in _constellation_hover_panel.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_constellation_hover_panel.add_child(vbox)

	# Constellation name
	var name_label = Label.new()
	name_label.text = c.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", c.color)
	vbox.add_child(name_label)

	# Status
	var progress = sphere_grid.get_constellation_progress(c.id)
	var status_label = Label.new()
	if c.completed:
		status_label.text = "COMPLETED — ACTIVE"
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	else:
		status_label.text = "Progress: %d / %d nodes" % [progress["unlocked"], progress["total"]]
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	status_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(status_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vbox.add_child(sep)

	# Bonus description
	var bonus_header = Label.new()
	bonus_header.text = "Bonus: %s" % c.bonus_name
	bonus_header.add_theme_font_size_override("font_size", 13)
	bonus_header.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	vbox.add_child(bonus_header)

	var bonus_desc = Label.new()
	bonus_desc.text = c.bonus_description
	bonus_desc.add_theme_font_size_override("font_size", 12)
	bonus_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	bonus_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_desc.custom_minimum_size.x = 220
	vbox.add_child(bonus_desc)

	# Node list
	var nodes_sep = HSeparator.new()
	nodes_sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	vbox.add_child(nodes_sep)

	var nodes_header = Label.new()
	nodes_header.text = "Required Nodes:"
	nodes_header.add_theme_font_size_override("font_size", 11)
	nodes_header.add_theme_color_override("font_color", COLOR_SECTION_HEADER)
	vbox.add_child(nodes_header)

	for nid in c.node_ids:
		var node = sphere_grid.get_node_by_id(nid)
		if not node:
			continue
		var node_label = Label.new()
		var check = "[x]" if node.unlocked else "[ ]"
		node_label.text = "%s %s (Ring %d)" % [check, node.label, node.ring]
		node_label.add_theme_font_size_override("font_size", 11)
		if node.unlocked:
			node_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		else:
			node_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(node_label)

	# Shared constellation warning
	var shared_with: Array[String] = []
	for other_c in sphere_grid.get_all_constellations():
		if other_c.id == c.id:
			continue
		var shared_count = 0
		for nid in c.node_ids:
			if nid in other_c.node_ids:
				shared_count += 1
		if shared_count > 0:
			shared_with.append("%s (%d shared)" % [other_c.name, shared_count])

	if shared_with.size() > 0:
		var share_sep = HSeparator.new()
		share_sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
		vbox.add_child(share_sep)

		var share_label = Label.new()
		share_label.text = "Overlaps with:"
		share_label.add_theme_font_size_override("font_size", 11)
		share_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		vbox.add_child(share_label)

		for s in shared_with:
			var sl = Label.new()
			sl.text = "  " + s
			sl.add_theme_font_size_override("font_size", 10)
			sl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
			vbox.add_child(sl)

	# Position tooltip to the right of the entry
	_constellation_hover_panel.visible = true
	await get_tree().process_frame
	if not is_instance_valid(_constellation_hover_panel):
		return
	var entry_pos = entry.global_position
	var tooltip_x = entry_pos.x + entry.size.x + _constellation_list_panel.size.x - entry.size.x + 15
	var tooltip_y = entry_pos.y
	var screen_size = get_viewport().get_visible_rect().size
	if tooltip_y + _constellation_hover_panel.size.y > screen_size.y - 20:
		tooltip_y = screen_size.y - 20 - _constellation_hover_panel.size.y
	_constellation_hover_panel.position = Vector2(tooltip_x, tooltip_y)

# ============================================
# INPUT
# ============================================

func _on_grid_input(event: InputEvent) -> void:
	if not visible or not sphere_grid:
		return

	# Mouse motion — hover detection + drag panning (right/middle or left-after-threshold)
	if event is InputEventMouseMotion:
		# Detect when a held left-click should turn into a drag
		if _left_pressed and not _left_dragged:
			if event.position.distance_to(_left_press_pos) > _DRAG_THRESHOLD:
				_left_dragged = true
				_close_detail_popup()

		if _dragging or _left_dragged:
			_camera_offset += event.relative / _zoom
			grid_canvas.queue_redraw()
		else:
			var local_pos = grid_canvas.get_local_mouse_position()
			var old_hover = _hovered_node_id
			_hovered_node_id = _get_node_at_screen(local_pos)
			if _hovered_node_id != old_hover:
				_update_info_label()
				grid_canvas.queue_redraw()

	# Mouse button — click opens detail popup, drag to pan, scroll to zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Defer the click action until release so we can detect drag intent
				_left_pressed = true
				_left_dragged = false
				_left_press_pos = event.position
			else:
				# Released — treat as a click only if the user didn't drag
				if _left_pressed and not _left_dragged:
					var local_pos = grid_canvas.get_local_mouse_position()
					var clicked_id = _get_node_at_screen(local_pos)
					if clicked_id >= 0:
						_open_detail_popup(clicked_id)
					else:
						# Clicked empty space — close popup
						_close_detail_popup()
				_left_pressed = false
				_left_dragged = false

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
		SphereGrid.NodeType.PASSIVE:
			_build_passive_popup_content(vbox, node)
		SphereGrid.NodeType.STAT_BONUS, SphereGrid.NodeType.HEALTH, SphereGrid.NodeType.MANA, SphereGrid.NodeType.COMBAT_BONUS:
			_build_stat_popup_content(vbox, node)
		SphereGrid.NodeType.FREE_STAT:
			_add_popup_label(vbox, node.description, 15, COLOR_FREE_STAT)
			_add_popup_label(vbox, "Points bank to your pool — spend them on any stats from the character/stat screen, just like leveling up.", 11, COLOR_DIM_TEXT)
		SphereGrid.NodeType.KEYSTONE:
			_add_popup_label(vbox, node.description, 14, Color(1.0, 0.85, 0.4))
			_add_popup_label(vbox, "Keystones attached: %d / %d" % [sphere_grid.unlocked_keystone_count(), SphereGrid.MAX_KEYSTONES], 12, COLOR_DIM_TEXT)
		SphereGrid.NodeType.CULLING_STONE:
			_add_popup_label(vbox, "Grants 1 Culling Stone", 14, COLOR_CULLING)
			_add_popup_label(vbox, "Use at the Card Dealer to remove a card from your deck.", 12, COLOR_DIM_TEXT)
		SphereGrid.NodeType.RETROSPECTIVE:
			_add_popup_label(vbox, "Grants 1 Retrospective Token", 14, COLOR_RETROSPECTIVE)
			_add_popup_label(vbox, "Use in the Skill Tree to reclaim a reward you previously skipped. Pick one of the blacked-out options from any past level.", 12, COLOR_DIM_TEXT)
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


func _build_passive_popup_content(vbox: VBoxContainer, node: SphereGrid.GridNode) -> void:
	_add_popup_label(vbox, node.description, 14, Color(0.95, 0.8, 0.5))

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
		return "Dexterity: faster attack speed proc, +5% crit damage per point"
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
	var reqs_met = SphereGrid.requirements_met(node, player_stats)
	var keystone_blocked = node.node_type == SphereGrid.NodeType.KEYSTONE \
		and not sphere_grid.keystone_slots_free()
	var can_unlock = sphere_grid.is_unlockable(node.id) and reqs_met \
		and not keystone_blocked \
		and sphere_inventory and sphere_inventory.has_sphere_for_node(node.node_type)

	if not sphere_grid.is_unlockable(node.id):
		_add_popup_label(vbox, "Must be adjacent to an unlocked node", 12, Color(0.7, 0.3, 0.3))
	elif not reqs_met:
		_add_popup_label(vbox, SphereGrid.requirement_text(node), 12, Color(0.9, 0.55, 0.2))
	elif keystone_blocked:
		_add_popup_label(vbox, "Keystone limit reached (%d of %d attached)" % [sphere_grid.unlocked_keystone_count(), SphereGrid.MAX_KEYSTONES], 12, Color(0.7, 0.3, 0.3))
	elif not sphere_inventory or not sphere_inventory.has_sphere_for_node(node.node_type):
		_add_popup_label(vbox, "Requires: 1 sphere", 12, Color(0.7, 0.3, 0.3))
	else:
		_add_popup_label(vbox, "Costs 1 sphere", 12, Color(0.5, 0.8, 0.5))
		if SphereGrid.requirement_text(node) != "":
			_add_popup_label(vbox, SphereGrid.requirement_text(node) + " — met", 11, Color(0.5, 0.8, 0.5))

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
	if not SphereGrid.requirements_met(node, player_stats):
		return
	if not sphere_inventory or not sphere_inventory.has_sphere_for_node(node.node_type):
		return

	# Unlock first, spend after — unlock_node can refuse (e.g. keystone limit)
	# and the sphere must not be consumed on a refused unlock.
	if not sphere_grid.unlock_node(_popup_node_id):
		return
	sphere_inventory.spend_sphere_for_node(node.node_type)
	_update_points_label()
	_set_info("Unlocked: %s — %s" % [node.label, node.description])
	node_unlocked.emit(_popup_node_id)

	# Grant retrospective token if this was a retrospective node
	if node.node_type == SphereGrid.NodeType.RETROSPECTIVE:
		sphere_inventory.add_retrospective_token()

	# Grant feather (paper feather for card removal) if this was a feather node
	if node.node_type == SphereGrid.NodeType.FEATHER:
		pass  # Handled by progression_triggers via node_unlocked signal

	# Check for constellations that are now ready (but require confirmation)
	_check_pending_constellations()

	# Refresh constellation list to show updated progress
	_refresh_constellation_list()

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

# ============================================
# INFO LABEL / HELPERS
# ============================================

func _update_info_label() -> void:
	if _hovered_node_id < 0:
		info_panel.visible = false
		return
	var node = sphere_grid.get_node_by_id(_hovered_node_id)
	if not node:
		info_panel.visible = false
		return
	info_panel.visible = true

	var lines: Array[String] = []

	# Node name and type
	var type_name = _get_type_name(node.node_type)
	lines.append("%s  (%s)" % [node.label, type_name])

	# Status
	var status = "UNLOCKED" if node.unlocked else ("AVAILABLE" if sphere_grid.is_unlockable(node.id) else "LOCKED")
	lines.append("Status: %s" % status)

	# Description
	lines.append(node.description)

	# Sphere requirement
	if not node.unlocked and node.node_type != SphereGrid.NodeType.START:
		var have = 0
		if sphere_inventory:
			have = sphere_inventory.get_count(SphereInventory.SphereType.SPHERE)
		lines.append("Requires: 1 sphere (have: %d)" % have)

	info_label.text = "\n".join(lines)
	_position_info_panel_near_node(node)

func _position_info_panel_near_node(node: SphereGrid.GridNode) -> void:
	## Positions the info panel adjacent to the hovered node, clamping to the canvas bounds.
	if not info_panel:
		return
	# Detach from any preset anchoring so we can set explicit screen coords
	info_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Wait one frame so size is recomputed if the text changed substantially
	await get_tree().process_frame
	if not info_panel.visible:
		return

	var node_screen = _world_to_screen(node.position)
	var node_radius = NODE_RADIUS_BASE * _zoom + 6.0
	var canvas_size = _get_canvas_size()
	var panel_size = info_panel.size
	if panel_size.x <= 0:
		panel_size.x = 280
	if panel_size.y <= 0:
		panel_size.y = 100

	# Prefer placing the panel to the right of the node, then left, then below
	var pos = Vector2.ZERO
	pos.x = node_screen.x + node_radius
	pos.y = node_screen.y - panel_size.y / 2.0
	if pos.x + panel_size.x > canvas_size.x - 8:
		# Doesn't fit on the right — try the left
		pos.x = node_screen.x - node_radius - panel_size.x
	if pos.x < 8:
		# Still off-screen — clamp and place above/below the node
		pos.x = clampf(node_screen.x - panel_size.x / 2.0, 8.0, canvas_size.x - panel_size.x - 8.0)
		pos.y = node_screen.y + node_radius
		if pos.y + panel_size.y > canvas_size.y - 8:
			pos.y = node_screen.y - node_radius - panel_size.y

	pos.y = clampf(pos.y, 8.0, canvas_size.y - panel_size.y - 8.0)
	info_panel.position = pos

func _set_info(text: String) -> void:
	info_label.text = text

func _get_type_name(t: SphereGrid.NodeType) -> String:
	match t:
		SphereGrid.NodeType.STAT_BONUS: return "Stat Bonus"
		SphereGrid.NodeType.FREE_STAT: return "Free Stats"
		SphereGrid.NodeType.PASSIVE: return "Passive"
		SphereGrid.NodeType.COMBAT_BONUS: return "Combat Bonus"
		SphereGrid.NodeType.HEALTH: return "Health"
		SphereGrid.NodeType.MANA: return "Mana"
		SphereGrid.NodeType.START: return "Start"
		SphereGrid.NodeType.CULLING_STONE: return "Culling Stone"
		SphereGrid.NodeType.RETROSPECTIVE: return "Retrospective"
		SphereGrid.NodeType.FEATHER: return "Feather"
		SphereGrid.NodeType.NULL_NODE: return "Null Node"
		SphereGrid.NodeType.KEYSTONE: return "Keystone"
	return "Unknown"

func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()

# ============================================
# CONSTELLATION CONFIRMATION MODAL
# ============================================

func _check_pending_constellations() -> void:
	## Checks if any constellations are now completable and shows confirmation modal.
	if not sphere_grid:
		return
	for c in sphere_grid.get_all_constellations():
		if c.completed:
			continue
		if not sphere_grid.is_constellation_complete(c.id):
			continue

		# This constellation has all nodes unlocked — check for conflicts
		var conflicting_id = _find_conflicting_active_constellation(c)
		if conflicting_id != "":
			# Shares nodes with an already-active constellation — replacement modal
			_show_constellation_replace_modal(c.id, conflicting_id)
		else:
			# No conflict — acceptance modal
			_show_constellation_accept_modal(c.id)
		return  # Only show one modal at a time

func _find_conflicting_active_constellation(new_constellation: SphereGrid.Constellation) -> String:
	## Returns the ID of an already-completed constellation that shares nodes with the new one.
	## Returns "" if no conflict exists.
	var new_nodes = {}
	for nid in new_constellation.node_ids:
		new_nodes[nid] = true

	for c in sphere_grid.get_all_constellations():
		if not c.completed or c.id == new_constellation.id:
			continue
		for nid in c.node_ids:
			if nid in new_nodes:
				return c.id
	return ""

func _show_constellation_accept_modal(constellation_id: String) -> void:
	## Shows a modal for accepting a new constellation with no conflicts.
	_pending_constellation_id = constellation_id
	_conflicting_constellation_id = ""

	var c = sphere_grid.get_constellation(constellation_id)
	if not c:
		return

	_create_modal_overlay()

	_constellation_modal = PanelContainer.new()
	_constellation_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = _create_modal_style()
	_constellation_modal.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_constellation_modal.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "CONSTELLATION COMPLETE"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_popup_separator(vbox)

	# Constellation name
	var name_label = Label.new()
	name_label.text = c.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", c.color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Bonus description
	var desc = Label.new()
	desc.text = c.bonus_description
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 320
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	_add_popup_separator(vbox)

	# Note
	var note = Label.new()
	note.text = "Note: This constellation can be replaced later\nif a different constellation using shared nodes\nis completed."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 320
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(note)

	# Buttons
	var btn_box = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 12)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_box)

	var accept_btn = _create_modal_button("Accept", Color(0.15, 0.45, 0.25), Color(0.2, 0.55, 0.3))
	accept_btn.pressed.connect(_on_constellation_accept)
	btn_box.add_child(accept_btn)

	var decline_btn = _create_modal_button("Decline", Color(0.35, 0.2, 0.2), Color(0.45, 0.25, 0.25))
	decline_btn.pressed.connect(_on_constellation_decline)
	btn_box.add_child(decline_btn)

	_constellation_modal.custom_minimum_size = Vector2(380, 0)
	add_child(_constellation_modal)
	_center_modal()

func _show_constellation_replace_modal(new_id: String, old_id: String) -> void:
	## Shows a modal for replacing an active constellation with a new one.
	_pending_constellation_id = new_id
	_conflicting_constellation_id = old_id

	var new_c = sphere_grid.get_constellation(new_id)
	var old_c = sphere_grid.get_constellation(old_id)
	if not new_c or not old_c:
		return

	_create_modal_overlay()

	_constellation_modal = PanelContainer.new()
	_constellation_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var style = _create_modal_style()
	_constellation_modal.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_constellation_modal.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "REPLACE CONSTELLATION?"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_popup_separator(vbox)

	# Current constellation
	var current_header = Label.new()
	current_header.text = "Currently Active:"
	current_header.add_theme_font_size_override("font_size", 12)
	current_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(current_header)

	var old_name = Label.new()
	old_name.text = old_c.name
	old_name.add_theme_font_size_override("font_size", 15)
	old_name.add_theme_color_override("font_color", old_c.color)
	vbox.add_child(old_name)

	var old_desc = Label.new()
	old_desc.text = old_c.bonus_description
	old_desc.add_theme_font_size_override("font_size", 12)
	old_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	old_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	old_desc.custom_minimum_size.x = 340
	vbox.add_child(old_desc)

	_add_popup_separator(vbox)

	# New constellation
	var new_header = Label.new()
	new_header.text = "Replace With:"
	new_header.add_theme_font_size_override("font_size", 12)
	new_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(new_header)

	var new_name = Label.new()
	new_name.text = new_c.name
	new_name.add_theme_font_size_override("font_size", 15)
	new_name.add_theme_color_override("font_color", new_c.color)
	vbox.add_child(new_name)

	var new_desc = Label.new()
	new_desc.text = new_c.bonus_description
	new_desc.add_theme_font_size_override("font_size", 12)
	new_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	new_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_desc.custom_minimum_size.x = 340
	vbox.add_child(new_desc)

	_add_popup_separator(vbox)

	# Warning
	var warning = Label.new()
	warning.text = "WARNING: This is a permanent change.\nYou cannot revert back to the replaced constellation."
	warning.add_theme_font_size_override("font_size", 12)
	warning.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size.x = 340
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(warning)

	# Buttons
	var btn_box = HBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 12)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_box)

	var replace_btn = _create_modal_button("Replace", Color(0.5, 0.25, 0.15), Color(0.6, 0.3, 0.2))
	replace_btn.pressed.connect(_on_constellation_replace)
	btn_box.add_child(replace_btn)

	var cancel_btn = _create_modal_button("Cancel", Color(0.25, 0.25, 0.3), Color(0.3, 0.3, 0.35))
	cancel_btn.pressed.connect(_on_constellation_decline)
	btn_box.add_child(cancel_btn)

	_constellation_modal.custom_minimum_size = Vector2(400, 0)
	add_child(_constellation_modal)
	_center_modal()

func _on_constellation_accept() -> void:
	## Player accepted a new constellation with no conflicts.
	if _pending_constellation_id == "":
		_close_constellation_modal()
		return

	var c = sphere_grid.get_constellation(_pending_constellation_id)
	if c:
		c.completed = true
		sphere_grid.constellation_completed.emit(_pending_constellation_id)
		print("[SPHERE GRID] Constellation accepted: %s" % c.name)

	_close_constellation_modal()
	_refresh_constellation_list()
	grid_canvas.queue_redraw()

func _on_constellation_replace() -> void:
	## Player chose to replace an active constellation with a new one.
	if _pending_constellation_id == "" or _conflicting_constellation_id == "":
		_close_constellation_modal()
		return

	var old_id = _conflicting_constellation_id
	var new_id = _pending_constellation_id

	# Deactivate the old constellation
	var old_c = sphere_grid.get_constellation(old_id)
	if old_c:
		old_c.completed = false
		print("[SPHERE GRID] Constellation deactivated: %s (replaced)" % old_c.name)

	# Activate the new constellation
	var new_c = sphere_grid.get_constellation(new_id)
	if new_c:
		new_c.completed = true
		sphere_grid.constellation_replaced.emit(old_id, new_id)
		sphere_grid.constellation_completed.emit(new_id)
		print("[SPHERE GRID] Constellation replaced with: %s" % new_c.name)

	_close_constellation_modal()
	_refresh_constellation_list()
	grid_canvas.queue_redraw()

func _on_constellation_decline() -> void:
	## Player declined the constellation.
	print("[SPHERE GRID] Constellation declined: %s" % _pending_constellation_id)
	_close_constellation_modal()

func _close_constellation_modal() -> void:
	_pending_constellation_id = ""
	_conflicting_constellation_id = ""
	if _constellation_modal:
		_constellation_modal.queue_free()
		_constellation_modal = null
	if _constellation_modal_overlay:
		_constellation_modal_overlay.queue_free()
		_constellation_modal_overlay = null

func _create_modal_overlay() -> void:
	## Creates a semi-transparent overlay behind the modal.
	_constellation_modal_overlay = ColorRect.new()
	_constellation_modal_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	_constellation_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_constellation_modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_constellation_modal_overlay)

func _create_modal_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.16, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.45, 0.3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _create_modal_button(text: String, normal_color: Color, hover_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 36)
	btn.add_theme_font_size_override("font_size", 14)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = normal_color
	btn_style.border_color = Color(normal_color.r + 0.2, normal_color.g + 0.2, normal_color.b + 0.2)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = hover_color
	btn.add_theme_stylebox_override("hover", btn_hover)

	return btn

func _center_modal() -> void:
	## Centers the constellation modal on screen.
	if not _constellation_modal:
		return
	await get_tree().process_frame
	var viewport_size = get_viewport().get_visible_rect().size
	var modal_size = _constellation_modal.size
	_constellation_modal.position = (viewport_size - modal_size) / 2.0
