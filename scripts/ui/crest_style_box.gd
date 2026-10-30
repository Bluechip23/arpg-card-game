class_name CrestStyleBox
extends StyleBox

## Panel stylebox with the Trials of Olorin logo mounted at the top-center of the border,
## like a crest on the frame. Used by tooltips and tutorial popups so they
## share one visual language. Colors/radius are configurable so each popup
## family keeps its own accent (gold tooltips, arcane-blue Olorin, ...).

var panel := StyleBoxFlat.new()
## The largest a crest grows (px): popups take the designer's 56 (2026-10-30),
## Olorin's dialog 1.3x that.
static var default_size: float = 56.0
## The smallest: a crest never shrinks below this on a narrow box.
const MIN_SIZE := 28.0
## The crest scales with its box: this share of the box's width, between
## MIN_SIZE and crest_size.
const WIDTH_SHARE := 0.2
## The logo rides the top border: this share of it rises above the frame,
## the rest sits inside and the content makes room for it.
## (The engine's own tooltips are windows that clip what is drawn outside
## them: theirs sits wholly inside, rise 0.)
const RISE := 0.6
var rise: float = RISE:
	set(v):
		rise = v
		content_margin_top = crest_size * (1.0 - rise) + 4.0
var crest_size: float = 56.0:
	set(v):
		crest_size = v
		content_margin_top = crest_size * (1.0 - rise) + 4.0

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

## The crest's size on a box this wide: it grows with the box, up to crest_size.
func size_for(width: float) -> float:
	return clampf(roundf(width * WIDTH_SHARE), minf(MIN_SIZE, crest_size), crest_size)

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	panel.draw(to_canvas_item, rect)
	var s := size_for(rect.size.x)
	var sigil: Texture2D = UIGlyphs.to_logo(int(s))
	if sigil:
		var pos := Vector2(
			rect.position.x + (rect.size.x - s) * 0.5,
			rect.position.y - s * rise + (2.0 if rise <= 0.0 else 0.0))
		sigil.draw_rect(to_canvas_item, Rect2(pos.round(), Vector2(s, s)), false)
