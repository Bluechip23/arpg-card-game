extends SceneTree

## The detail box (designer, 2026-10-31): clicking an ally or summon in the
## Allies & Summons tab opens the same box an enemy's square does, and the
## box's enlarge button makes everything in it bigger (and back).
## Run: godot --headless --path . --script tests/test_inspect_box.gd

var failures := 0
var _main: Node = null

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_main = (load("res://scenes/core/main.tscn") as PackedScene).instantiate()
	_main.set("starting_character", CharacterData.create_brad())
	_main.set("current_interior_id", "dojo")
	get_root().add_child(_main)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	print("=== Inspect box ===")
	await _frames(60)
	if _main.olorin and _main.olorin.is_busy():
		_main.olorin._close()
	var box = _main.enemy_inspect_ui
	var gm = _main.grid_manager
	var wolf: Enemy = _main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WOLF,
		gm.grid_to_world(gm.world_to_grid(_main.player.position) + Vector2i(2, 0)))
	_main._spawn_summon(30, _main.player.position, "golem")
	await _frames(10)

	box.show_enemy(wolf)
	await _frames(3)
	var small_w: float = box.size.x
	var small_font: int = box._name_label.get_theme_font_size("font_size")
	box.toggle_zoom()
	await _frames(3)
	_check(box.zoom > 1.0 and box._name_label.get_theme_font_size("font_size") > small_font, "enlarge makes the text bigger")
	_check(box.size.x > small_w, "and the box wider (%d -> %d)" % [small_w, box.size.x])
	box.toggle_zoom()
	await _frames(3)
	_check(is_equal_approx(box.zoom, 1.0) and absf(box.size.x - small_w) < 2.0, "shrinking puts it back (%d)" % box.size.x)

	var summon = null
	for u in _main.unit_tracker._allies():
		if u is Summon:
			summon = u
	_check(summon != null, "a summon stands in the Allies & Summons tab")
	if summon:
		_main.unit_tracker.ally_clicked.emit(summon)
		await _frames(3)
		_check(box.visible and box._ally == summon, "clicking it opens the box on it")
		_check(box._name_label.text == UnitTrackerUI.ally_info(summon)["name"], "the box names it (%s)" % box._name_label.text)
		_main.unit_tracker.ally_clicked.emit(summon)
		await _frames(2)
		_check(not box.visible, "clicking it again closes the box")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
