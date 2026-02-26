class_name SphereGridUI
extends CanvasLayer

## Full-screen sphere grid overlay for the leveling system.
## Toggle with L key. Renders 100 nodes in concentric rings with connection lines.

signal closed
signal node_unlocked(node_id: int)

@onready var panel: PanelContainer = $Panel
@onready var grid_canvas: Control = $Panel/GridCanvas
@onready var close_button: Button = $Panel/CloseButton
@onready var title_label: Label = $Panel/TitleLabel
@onready var info_label: Label = $Panel/InfoLabel
@onready var points_label: Label = $Panel/PointsLabel

var sphere_grid: SphereGrid
var skill_points: int = 0
var _hovered_node_id: int = -1
var _camera_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _zoom: float = 1.0

# Node drawing constants
const NODE_RADIUS_BASE: float = 16.0
const NODE_RADIUS_START: float = 22.0
const LINE_WIDTH: float = 2.0
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
const COLOR_LINE := Color(0.25, 0.25, 0.35, 0.7)
const COLOR_LINE_UNLOCKED := Color(0.2, 0.7, 0.3, 0.6)
const COLOR_BG := Color(0.05, 0.05, 0.08, 0.95)
const COLOR_HOVER_RING := Color(1.0, 1.0, 0.6, 0.8)

func _ready() -> void:
	layer = 110
	sphere_grid = SphereGrid.new()
	visible = false
	_apply_styles()

	close_button.pressed.connect(_on_close_pressed)
	grid_canvas.draw.connect(_on_grid_draw)
	grid_canvas.gui_input.connect(_on_grid_input)
	grid_canvas.mouse_filter = Control.MOUSE_FILTER_STOP

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
	info_label.text = "Hover over a node to see details. Click an adjacent unlocked node to spend a skill point."
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
	grid_canvas.queue_redraw()

func hide_panel() -> void:
	visible = false

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func add_skill_points(amount: int) -> void:
	skill_points += amount
	_update_points_label()

func _update_points_label() -> void:
	if points_label:
		points_label.text = "Skill Points: %d" % skill_points

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var canvas_center = grid_canvas.size / 2.0
	var grid_center = Vector2(640, 360)
	return canvas_center + (world_pos - grid_center + _camera_offset) * _zoom

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_center = grid_canvas.size / 2.0
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
		if is_hovered:
			radius += HOVER_GROW * _zoom

		# Draw shape
		match shape:
			"circle":
				grid_canvas.draw_circle(pos, radius, color)
				if is_hovered:
					grid_canvas.draw_arc(pos, radius + 2 * _zoom, 0, TAU, 32, COLOR_HOVER_RING, 2.0 * _zoom)
			"diamond":
				var pts = PackedVector2Array([
					pos + Vector2(0, -radius),
					pos + Vector2(radius, 0),
					pos + Vector2(0, radius),
					pos + Vector2(-radius, 0),
				])
				grid_canvas.draw_colored_polygon(pts, color)
				if is_hovered:
					var outline = pts.duplicate()
					outline.append(pts[0])
					grid_canvas.draw_polyline(outline, COLOR_HOVER_RING, 2.0 * _zoom)
			"square":
				var rect = Rect2(pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
				grid_canvas.draw_rect(rect, color)
				if is_hovered:
					grid_canvas.draw_rect(rect.grow(2 * _zoom), COLOR_HOVER_RING, false, 2.0 * _zoom)

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

	# Mouse button — click to unlock, middle/right drag to pan, scroll to zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos = grid_canvas.get_local_mouse_position()
				var clicked_id = _get_node_at_screen(local_pos)
				if clicked_id >= 0:
					_try_unlock_node(clicked_id)
			# Also start drag on left for convenience
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			if event.pressed:
				_drag_start = event.position

		# Scroll zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 1.1, 0.4, 2.5)
			grid_canvas.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom / 1.1, 0.4, 2.5)
			grid_canvas.queue_redraw()

func _try_unlock_node(id: int) -> void:
	if skill_points <= 0:
		_set_info("No skill points available!")
		return
	if not sphere_grid.is_unlockable(id):
		var node = sphere_grid.get_node_by_id(id)
		if node and node.unlocked:
			_set_info("Already unlocked: %s" % node.label)
		else:
			_set_info("Cannot unlock — must be adjacent to an unlocked node.")
		return

	sphere_grid.unlock_node(id)
	skill_points -= 1
	_update_points_label()
	var node = sphere_grid.get_node_by_id(id)
	_set_info("Unlocked: %s — %s" % [node.label, node.description])
	node_unlocked.emit(id)
	grid_canvas.queue_redraw()

func _update_info_label() -> void:
	if _hovered_node_id < 0:
		info_label.text = "Hover over a node to see details. Click to unlock adjacent nodes."
		return
	var node = sphere_grid.get_node_by_id(_hovered_node_id)
	if not node:
		return
	var status = "UNLOCKED" if node.unlocked else ("AVAILABLE" if sphere_grid.is_unlockable(node.id) else "LOCKED")
	var type_name = _get_type_name(node.node_type)
	info_label.text = "[%s] %s (%s) — %s" % [status, node.label, type_name, node.description]

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
