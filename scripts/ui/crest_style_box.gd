class_name CrestStyleBox
extends StyleBox

## Panel stylebox with the T&O sigil mounted at the top-center of the border,
## like a crest on the frame. Used by tooltips and tutorial popups so they
## share one visual language. Colors/radius are configurable so each popup
## family keeps its own accent (gold tooltips, arcane-blue Olorin, ...).

var panel := StyleBoxFlat.new()
## Height of the crest in pixels (it is 4:3, so a 24px crest is 32px wide).
## Setting it keeps the top content margin clear of the crest.
var crest_size: float = 24.0:
	set(v):
		crest_size = v
		content_margin_top = crest_size + 4.0

func _init(bg := Color(0.08, 0.08, 0.14, 0.98), border := Color(0.5, 0.4, 0.2),
		radius := 8, border_width := 2) -> void:
	panel.bg_color = bg
	panel.set_border_width_all(border_width)
	panel.border_color = border
	panel.set_corner_radius_all(radius)
	content_margin_left = 12.0
	content_margin_top = crest_size + 4.0
	content_margin_right = 12.0
	content_margin_bottom = 8.0

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	panel.draw(to_canvas_item, rect)
	# The smooth seal at its exact pixel size — no runtime scaling, so the
	# edges stay soft rather than stair-stepped.
	var sigil: Texture2D = UIGlyphs.get_sigil(int(round(crest_size)))
	if sigil:
		var sz: Vector2 = sigil.get_size()
		var pos := Vector2(
			rect.position.x + (rect.size.x - sz.x) * 0.5,
			rect.position.y + 1.0)
		sigil.draw_rect(to_canvas_item, Rect2(pos, sz), false)
