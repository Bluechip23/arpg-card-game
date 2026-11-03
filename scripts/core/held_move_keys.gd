class_name HeldMoveKeys
extends RefCounted

## Hold-to-walk for WASD (designer, 2026-11-03): holding W keeps the hero
## stepping up until the key is let go; the same for S, A and D. The scene
## records each press here and, every frame the hero is standing still, asks
## for the direction to step next. With several keys down the most recently
## pressed one wins, and letting it go falls back to whichever is still held.

const DIRS := {
	KEY_W: Vector2(0, 1),
	KEY_S: Vector2(0, -1),
	KEY_A: Vector2(-1, 0),
	KEY_D: Vector2(1, 0),
}

var _order: Array[int] = []

static func is_move_key(keycode: int) -> bool:
	return DIRS.has(keycode)

static func dir_for(keycode: int) -> Vector2:
	return DIRS.get(keycode, Vector2.ZERO)

func press(keycode: int) -> void:
	if not DIRS.has(keycode):
		return
	_order.erase(keycode)
	_order.append(keycode)

func clear() -> void:
	_order.clear()

## The direction to keep walking, or ZERO when no move key is still held.
## Keys let go are dropped here, so a release the scene never saw (a menu
## swallowed it) can't leave the hero walking.
func current_dir() -> Vector2:
	for i in range(_order.size() - 1, -1, -1):
		if not Input.is_key_pressed(_order[i]):
			_order.remove_at(i)
	if _order.is_empty():
		return Vector2.ZERO
	return DIRS[_order[-1]]
