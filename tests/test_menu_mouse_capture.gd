extends SceneTree
## Menus own the mouse (designer, 2026-10-31): scrolling the battle log or
## the sandbox menu scrolls them, never the camera; over the open map the
## wheel still zooms.
## Run: godot --path . --script tests/test_menu_mouse_capture.gd (needs a display)
var failures := 0
func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)
var _main: Node = null
func _initialize() -> void:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("sandbox_mode", true)
	get_root().add_child(_main)
	_run.call_deferred()
func _wheel(p: Vector2) -> float:
	var before: float = _main._camera_distance
	for b in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var m := InputEventMouseMotion.new(); m.position = p; m.global_position = p
		get_root().push_input(m)
		await process_frame
		var e := InputEventMouseButton.new(); e.button_index = b; e.pressed = true; e.position = p; e.global_position = p
		get_root().push_input(e)
		await process_frame
	return _main._camera_distance - before
func _run() -> void:
	for i in 60:
		await process_frame
	if _main.olorin and _main.olorin.is_busy():
		_main.olorin._close()
	for i in 5:
		await process_frame
	var log_panel: Control = _main.battle_log_panel
	var lr := log_panel.get_global_rect()
	_check(is_zero_approx(await _wheel(lr.get_center())), "the wheel over the log leaves the camera alone")
	_check(not is_zero_approx(await _wheel(Vector2(500, 300))), "the wheel over the map still zooms")
	var sb = _main.sandbox_ui
	if sb:
		if sb.has_method("toggle_menu"): sb.toggle_menu()
		elif sb.has_method("open_menu"): sb.open_menu()
		for i in 10: await process_frame
		var hov_c: Control = sb._card_scroll if sb._card_scroll else null
		if hov_c and hov_c.is_visible_in_tree():
			_check(is_zero_approx(await _wheel(hov_c.get_global_rect().get_center())), "the wheel over the sandbox menu leaves the camera alone")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
