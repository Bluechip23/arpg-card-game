class_name EnemyStatusHover
extends Control

## Hovering a buff / debuff dot over an enemy's head opens the same hover
## window the player's own badges use (StatusHoverPopup): what the effect
## does and how much is left, counting down live. The dots are 3D, so they
## cannot take mouse events themselves; each frame this projects every
## living enemy's dots (Enemy.get_status_hover_targets) to the screen and
## opens the window for the one under the cursor.

const PICK_RADIUS := 14.0   # px around a dot's centre that counts as over it

var main = null

var _anchor: Control = null       # parked over the hovered dot; the popup sits beside it
var _hover_enemy = null
var _hover_name: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_anchor = Control.new()
	_anchor.name = "StatusHoverAnchor"
	_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor.size = Vector2(PICK_RADIUS * 2.0, PICK_RADIUS * 2.0)
	add_child(_anchor)


func _process(_delta: float) -> void:
	var hit := _dot_under(get_viewport().get_mouse_position())
	if hit.is_empty():
		_clear()
		return
	_anchor.position = hit["screen"] - _anchor.size * 0.5
	if hit["enemy"] == _hover_enemy and hit["name"] == _hover_name:
		return
	_hover_enemy = hit["enemy"]
	_hover_name = hit["name"]
	var enemy = _hover_enemy
	var eff: String = _hover_name
	var info: Dictionary = enemy.get_effect_tooltip(eff)
	StatusHoverPopup.show_for(_anchor, eff, info.get("color", Color.WHITE), info.get("desc", ""),
		func() -> String:
			if not is_instance_valid(enemy):
				return ""
			return str(enemy.get_effect_tooltip(eff).get("remaining", "")))


## The dot nearest `mouse` within PICK_RADIUS: {enemy, name, screen}, or {}.
## A UI panel under the cursor wins over the world behind it.
func _dot_under(mouse: Vector2) -> Dictionary:
	if main == null or not is_instance_valid(main) or main.enemy_spawner == null:
		return {}
	var over_ui := get_viewport().gui_get_hovered_control()
	if over_ui != null:
		return {}
	var best := {}
	var best_d := PICK_RADIUS
	for enemy in main.enemy_spawner.get_living_enemies():
		if not is_instance_valid(enemy) or not enemy.is_visible_in_tree():
			continue
		for t in enemy.get_status_hover_targets():
			var sp: Vector2 = main.world_to_screen(t["pos"])
			var d := sp.distance_to(mouse)
			if d <= best_d:
				best_d = d
				best = {"enemy": enemy, "name": t["name"], "screen": sp}
	return best


func _clear() -> void:
	if _hover_enemy != null or _hover_name != "":
		StatusHoverPopup.hide_for(_anchor)
	_hover_enemy = null
	_hover_name = ""
