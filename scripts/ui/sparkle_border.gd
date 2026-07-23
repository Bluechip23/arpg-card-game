class_name SparkleBorder
extends Control

## Animated gold border for toggle buttons: a bright segment with a fading
## tail cycles around the button's edge, trailed by tiny twinkling sparkles.
## Signals an "auto" mode is active (e.g. flash movement). Add as a child of
## the button and flip `active`; it ignores the mouse so clicks pass through.

var active: bool = false:
	set(value):
		active = value
		visible = value
		set_process(value)
		if value:
			queue_redraw()

const SPEED := 0.45   # perimeter loops per second
const TAIL := 0.30    # fraction of the perimeter that glows behind the head
const GOLD := Color(1.0, 0.85, 0.3)

var _t: float = 0.0          # head position along the perimeter, 0..1
var _twinkle: float = 0.0    # sparkle animation clock

func _ready() -> void:
	# Track the parent rect explicitly — anchor presets don't reliably re-layout
	# when parented to a plain Control that was already sized.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := get_parent() as Control
	if p:
		p.resized.connect(_sync_rect)
	_sync_rect()
	visible = active
	set_process(active)

func _sync_rect() -> void:
	var p := get_parent() as Control
	if p:
		position = Vector2.ZERO
		size = p.size

func _process(delta: float) -> void:
	_t = fposmod(_t + delta * SPEED, 1.0)
	_twinkle += delta
	queue_redraw()

func _perimeter_point(u: float) -> Vector2:
	## Map u in [0,1) to a point on the rect border, clockwise from top-left.
	var s := size
	var per := 2.0 * (s.x + s.y)
	if per <= 0.0:
		return Vector2.ZERO
	var d := fposmod(u, 1.0) * per
	if d < s.x:
		return Vector2(d, 0)
	d -= s.x
	if d < s.y:
		return Vector2(s.x, d)
	d -= s.y
	if d < s.x:
		return Vector2(s.x - d, s.y)
	d -= s.x
	return Vector2(0, s.y - d)

func _draw() -> void:
	if not active:
		return
	# Tail: short segments fading out behind the head. Enough steps that
	# corner cuts stay unnoticeable.
	var steps := 20
	for i in range(steps):
		var u0 := _t - TAIL * float(i + 1) / steps
		var u1 := _t - TAIL * float(i) / steps
		var alpha := 0.9 * (1.0 - float(i) / steps)
		draw_line(_perimeter_point(u0), _perimeter_point(u1),
			Color(GOLD.r, GOLD.g, GOLD.b, alpha), 2.0)
	# Bright head dot.
	draw_circle(_perimeter_point(_t), 2.2, Color(1.0, 0.95, 0.75))
	# Sparkles: tiny 4-point stars twinkling along the tail.
	for i in range(3):
		var su := _t - 0.05 * (i + 1) - 0.02 * sin(_twinkle * 3.0 + i * 2.1)
		var p := _perimeter_point(su)
		var tw := 0.5 + 0.5 * sin(_twinkle * 6.0 + i * 2.6)
		var r := 1.2 + 1.6 * tw
		var col := Color(1.0, 0.95, 0.7, 0.35 + 0.65 * tw)
		draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), col, 1.0)
		draw_line(p + Vector2(0, -r), p + Vector2(0, r), col, 1.0)
