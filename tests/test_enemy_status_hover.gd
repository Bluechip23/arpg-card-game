extends SceneTree

## Hovering an enemy's buff / debuff opens the status hover window (what it
## does, what is left): both the dots over its head (EnemyStatusHover finds
## the dot under the cursor) and the circles in the enemy tracker.
## Run: godot --headless --path . --script tests/test_enemy_status_hover.gd

var failures: int = 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _popup_open() -> bool:
	return StatusHoverPopup._inst != null and is_instance_valid(StatusHoverPopup._inst) and StatusHoverPopup._inst.visible

func _run() -> void:
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	if main.olorin and main.olorin.is_busy():
		main.olorin._close()
	var living: Array = main.enemy_spawner.get_living_enemies()
	if living.is_empty():
		_check(false, "the dojo has an enemy")
		_finish()
		return
	var foe = living[0]
	foe.vulnerable_stacks = 2
	foe._update_status_indicators()
	await process_frame

	# Over its head.
	var hover: EnemyStatusHover = main.get_node_or_null("UI/EnemyStatusHover")
	_check(hover != null, "the battle scene has the over-head status hover")
	var targets: Array = foe.get_status_hover_targets()
	_check(targets.size() == 1 and targets[0]["name"] == "Vulnerable", "the enemy shows a Vulnerable dot")
	if hover and not targets.is_empty():
		var sp: Vector2 = main.world_to_screen(targets[0]["pos"])
		var hit: Dictionary = hover._dot_under(sp + Vector2(3, 2))
		_check(hit.get("enemy") == foe and hit.get("name") == "Vulnerable", "the cursor on the dot finds it")
		_check(hover._dot_under(sp + Vector2(60, 60)).is_empty(), "the cursor away from it finds nothing")
	var info: Dictionary = foe.get_effect_tooltip("Vulnerable")
	_check("30%" in str(info.get("desc", "")), "its window says what Vulnerable does: %s" % info.get("desc", ""))
	_check(str(info.get("remaining", "")) == "Stacks: 2", "and what is left (%s)" % info.get("remaining", ""))

	# In the tracker.
	var circle: PanelContainer = main.unit_tracker._create_status_icon(Color.ORANGE, 2, "Vulnerable", foe)
	main.get_node("UI").add_child(circle)
	await process_frame
	_check(circle.tooltip_text == "", "the tracker circle opens the hover window, not a bare tooltip")
	circle.mouse_entered.emit()
	_check(_popup_open() and StatusHoverPopup._inst._title.text == "Vulnerable", "hovering the tracker circle opens the window")
	_check("30%" in StatusHoverPopup._inst._desc.text, "with what the effect does")
	circle.mouse_exited.emit()
	_check(not _popup_open(), "leaving the circle closes it")
	_finish()

func _finish() -> void:
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
