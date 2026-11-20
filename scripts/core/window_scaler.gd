extends Node

## Whole-pixel window scaling that fills the screen (style guide §0).
##
## The project stretch is `canvas_items` / `expand` / `integer`. On its own,
## integer mode floors the scale and letterboxes the rest: a 1920×1080 window
## got a 1280×720 picture at 1× inside a 320/180-pixel black frame, and only
## exact multiples of 1280×720 filled the screen. Here the scale is still the
## largest whole number that fits the base size, but the base itself grows to
## window ÷ scale, so the whole window is used and a bigger screen shows more
## world rather than a fractionally scaled one.

const BASE := Vector2i(1280, 720)


func _ready() -> void:
	var win := get_window()
	win.size_changed.connect(_fit)
	_fit()


## The largest whole-number scale at which the base size fits `window`
## (0 when the window is smaller than the base in either direction).
static func scale_for(window: Vector2i) -> int:
	return mini(window.x / BASE.x, window.y / BASE.y)


## The content size that fills `window` at `scale_for(window)`. A window
## smaller than the base keeps the base size and lets Godot shrink it.
static func content_size_for(window: Vector2i) -> Vector2i:
	var k := scale_for(window)
	if k < 1:
		return BASE
	return window / k


func _fit() -> void:
	var win := get_window()
	if win.size.x <= 0 or win.size.y <= 0:
		return
	var want := content_size_for(win.size)
	if win.content_scale_size != want:
		win.content_scale_size = want
