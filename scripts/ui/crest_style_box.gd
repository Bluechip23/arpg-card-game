class_name CrestStyleBox
extends StyleBox

## Panel stylebox with the Trials of Olorin logo mounted at the top-center of the border,
## like a crest on the frame. Used by tooltips and tutorial popups so they
## share one visual language. Colors/radius are configurable so each popup
## family keeps its own accent (gold tooltips, arcane-blue Olorin, ...).

var panel := StyleBoxFlat.new()
## The size every new crest takes (px); Olorin's dialog wears it larger.
static var default_size: float = 20.0
## The logo straddles the top border: this share of it rises above the frame.
const RISE := 0.35
var crest_size: float = 20.0:
	set(v):
		crest_size = v
		content_margin_top = crest_size * (1.0 - RISE) + 4.0

func _init(bg := Color(0.08, 0.08, 0.14, 0.98), border := Color(0.5, 0.4, 0.2),
		radius := 8, border_width := 2) -> void:
	panel.bg_color = bg
	panel.set_border_width_all(border_width)
	panel.border_color = border
	panel.set_corner_radius_all(radius)
	content_margin_left = 12.0
	crest_size = default_size
	content_margin_right = 12.0
	content_margin_bottom = 8.0

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	panel.draw(to_canvas_item, rect)
	var sigil: Texture2D = UIGlyphs.to_logo(int(crest_size))
	if sigil:
		var pos := Vector2(
			rect.position.x + (rect.size.x - crest_size) * 0.5,
			rect.position.y - crest_size * RISE)
		sigil.draw_rect(to_canvas_item, Rect2(pos, Vector2(crest_size, crest_size)), false)
