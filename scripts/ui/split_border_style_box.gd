class_name SplitBorderStyleBox
extends StyleBox

## Panel stylebox whose outline is two colours: the LEFT half of the frame in
## one, the RIGHT half in the other. Inventory cells and the item detail
## panel use it so an item reads as both its type (left: red for weapons,
## blue for armour, ...) and its rarity (right: grey / orange / purple /
## mythic pink) at a glance.
##
## Drawn as a full rounded panel in the left colour with the right half of
## the border painted over in the right colour, so the corners stay rounded
## and the halves meet with no seam.

var _base := StyleBoxFlat.new()
var _right := StyleBoxFlat.new()

func _init(bg: Color = Color(0.16, 0.16, 0.22, 1.0), left_color: Color = Color(0.5, 0.5, 0.5),
		right_color: Color = Color(0.6, 0.6, 0.65), border_width: int = 2, radius: int = 4) -> void:
	_base.bg_color = bg
	_base.set_border_width_all(border_width)
	_base.border_color = left_color
	_base.set_corner_radius_all(radius)
	_right.draw_center = false
	_right.set_border_width_all(border_width)
	_right.border_width_left = 0
	_right.border_color = right_color
	_right.corner_radius_top_right = radius
	_right.corner_radius_bottom_right = radius
	content_margin_left = border_width
	content_margin_right = border_width
	content_margin_top = border_width
	content_margin_bottom = border_width

func set_colors(bg: Color, left_color: Color, right_color: Color) -> void:
	_base.bg_color = bg
	_base.border_color = left_color
	_right.border_color = right_color
	emit_changed()

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	_base.draw(to_canvas_item, rect)
	var half := floorf(rect.size.x * 0.5)
	_right.draw(to_canvas_item, Rect2(rect.position + Vector2(half, 0.0),
		Vector2(rect.size.x - half, rect.size.y)))
