class_name AOEIndicator
extends Node2D

## Visual indicator for AOE effects

var shape: String = "cone"  # "cone", "circle", "line"
var aoe_range: float = 100.0
var cone_angle: float = 60.0  # degrees for cone
var color: Color = Color(1, 0.4, 0.8, 0.3)  # Pink with transparency

var enemy_indicators: Dictionary = {}  # enemy_id -> ColorRect

func _draw() -> void:
	match shape:
		"cone":
			_draw_cone()
		"circle":
			_draw_circle()
		"line":
			_draw_line_shape()

func _draw_cone() -> void:
	var mouse_pos = get_local_mouse_position()
	var direction = mouse_pos.normalized()
	var angle = direction.angle()
	
	var half_angle = deg_to_rad(cone_angle / 2.0)
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)
	
	var segments = 16
	for i in range(segments + 1):
		var segment_angle = angle - half_angle + (half_angle * 2.0 * i / segments)
		points.append(Vector2.from_angle(segment_angle) * aoe_range)
	
	draw_colored_polygon(points, color)

func _draw_circle() -> void:
	draw_circle(Vector2.ZERO, aoe_range, color)

func _draw_line_shape() -> void:
	var mouse_pos = get_local_mouse_position()
	var direction = mouse_pos.normalized()
	var end_pos = direction * aoe_range
	var perpendicular = direction.rotated(PI / 2) * 20  # Width of line
	
	var points = PackedVector2Array([
		-perpendicular,
		perpendicular,
		end_pos + perpendicular,
		end_pos - perpendicular
	])
	draw_colored_polygon(points, color)

func update_indicator(new_shape: String, new_range: float) -> void:
	shape = new_shape
	aoe_range = new_range
	queue_redraw()

func show_indicator() -> void:
	visible = true
	queue_redraw()

func hide_indicator() -> void:
	visible = false
	clear_enemy_indicators()

func _process(delta: float) -> void:
	if visible:
		queue_redraw()

func update_enemy_rng_indicators(enemies: Array, card: Card) -> void:
	clear_enemy_indicators()
	
	if not card.has_chance_effect():
		return
	
	for enemy in enemies:
		if is_instance_valid(enemy) and _is_enemy_in_aoe(enemy):
			var success = card.get_rng_outcome(enemy)
			_create_enemy_indicator(enemy, success)

func _is_enemy_in_aoe(enemy) -> bool:
	var enemy_local = to_local(enemy.global_position)
	var distance = enemy_local.length()
	
	if distance > aoe_range:
		return false
	
	if shape == "cone":
		var mouse_pos = get_local_mouse_position()
		var direction = mouse_pos.normalized()
		var enemy_direction = enemy_local.normalized()
		var angle_diff = abs(direction.angle_to(enemy_direction))
		return angle_diff <= deg_to_rad(cone_angle / 2.0)
	
	return true  # Circle and line - just check range

func _create_enemy_indicator(enemy, success: bool) -> void:
	var indicator = ColorRect.new()
	indicator.size = Vector2(60, 10)
	indicator.position = enemy.global_position + Vector2(-30, 40)
	# AOE uses shaded/muted versions of the colors
	indicator.color = Color(0.3, 0.8, 0.4, 0.55) if success else Color(0.8, 0.3, 0.3, 0.55)
	get_tree().root.add_child(indicator)
	enemy_indicators[enemy.get_instance_id()] = indicator

func clear_enemy_indicators() -> void:
	for id in enemy_indicators:
		var indicator = enemy_indicators[id]
		if is_instance_valid(indicator):
			indicator.queue_free()
	enemy_indicators.clear()
