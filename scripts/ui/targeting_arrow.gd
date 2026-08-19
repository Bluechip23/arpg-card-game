class_name TargetingArrow
extends Control

## Red targeting arrow drawn from the player to the mouse pointer while a card
## that targets a specific unit (enemy or ally) is selected — "click a thing to
## hit it". Cards that target self, a ground point (their AOE indicator follows
## the cursor already), or everything nearby never show it.

var main = null  # main.gd — supplies the selected card, player, and camera

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(_delta: float) -> void:
	visible = _selected_targeting_card() != null
	if visible:
		queue_redraw()

## The selected card, if it wants the arrow: it targets a specific unit
## (enemy or ally) rather than self, a ground point, or everything nearby.
func _selected_targeting_card():
	if main == null or main.deck_manager == null:
		return null
	var idx: int = main.selected_card_index
	if idx < 0 or idx >= main.deck_manager.hand.size():
		return null
	var card = main.deck_manager.hand[idx]
	var tt: Array = card.target_types
	if "point" in tt:
		return null
	if "enemy" in tt or "ally" in tt:
		return card
	return null

## 1cm of physical screen space, resolved from the display DPI (96 fallback).
static func _cm_to_px() -> float:
	var dpi := DisplayServer.screen_get_dpi()
	if dpi <= 0:
		dpi = 96
	return dpi / 2.54

func _draw() -> void:
	if main == null or main.player == null or not is_instance_valid(main.player):
		return
	var from: Vector2 = main.world_to_screen(main.player.position + Vector3.UP * 1.0)
	var to: Vector2 = get_viewport().get_mouse_position()
	var dir := to - from
	if dir.length() < 8.0:
		return
	var thickness := _cm_to_px()
	var color := Color(0.9, 0.08, 0.08, 0.85)
	var n := dir.normalized()
	# Arrowhead: a triangle at the pointer, wider than the shaft; the shaft
	# stops where the head begins so the tip stays crisp.
	var head_len := thickness * 1.6
	var head_w := thickness * 2.4
	var base := to - n * minf(head_len, dir.length() * 0.5)
	draw_line(from, base, color, thickness, true)
	var perp := Vector2(-n.y, n.x)
	var head := PackedVector2Array([to, base + perp * head_w * 0.5, base - perp * head_w * 0.5])
	draw_colored_polygon(head, color)
