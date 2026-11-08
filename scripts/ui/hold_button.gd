extends Button

## A button that fires only after being held down for `hold_seconds`: a fill
## sweeps across it while held, and letting go early cancels. Used where an
## action cannot be undone (deleting a save, designer 2026-11-08).

signal held

@export var hold_seconds: float = 4.0
const FILL := Color(0.75, 0.18, 0.14, 0.55)

var _elapsed := -1.0          # < 0: not being held
var _fill: ColorRect = null
var _idle_text := ""

func _ready() -> void:
	_idle_text = text
	_fill = ColorRect.new()
	_fill.name = "HoldFill"
	_fill.color = FILL
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.size = Vector2(0, size.y)
	add_child(_fill)
	button_down.connect(_on_down)
	button_up.connect(_cancel)
	mouse_exited.connect(_cancel)
	set_process(false)

func _on_down() -> void:
	_elapsed = 0.0
	set_process(true)

func _cancel() -> void:
	if _elapsed < 0.0:
		return
	_elapsed = -1.0
	set_process(false)
	_show_progress(0.0)

## How far the hold has got, 0..1 (0 when not held).
func progress() -> float:
	return 0.0 if _elapsed < 0.0 else clampf(_elapsed / hold_seconds, 0.0, 1.0)

## Advance the hold by `delta` seconds (the frame loop calls this; tests can too).
func advance(delta: float) -> void:
	if _elapsed < 0.0:
		return
	_elapsed += delta
	if _elapsed >= hold_seconds:
		_elapsed = -1.0
		set_process(false)
		_show_progress(0.0)
		held.emit()
		return
	_show_progress(progress())

func _process(delta: float) -> void:
	advance(delta)

func _show_progress(p: float) -> void:
	if _fill:
		_fill.size = Vector2(size.x * p, size.y)
	if p <= 0.0:
		text = _idle_text
	else:
		text = "Hold… %d" % ceili(hold_seconds * (1.0 - p))
