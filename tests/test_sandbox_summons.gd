extends SceneTree

## The sandbox menu's Summon row: every summoned ally the game has is in the
## list, and each one, spawned from it, stands on the field beside the player.
## Run: godot --headless --path . --script tests/test_sandbox_summons.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(n := 6) -> void:
	for _i in range(n):
		await process_frame

func _count(main) -> int:
	var n: int = main._all_summons().size()
	n += main._summoned_worms.filter(func(w): return is_instance_valid(w) and not (w.has_method("heal"))).size()
	n += main._specters.filter(func(s): return is_instance_valid(s) and not s.is_dead).size()
	return n

func _run() -> void:
	print("=== Sandbox: Summon row ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("sandbox_mode", true)
	get_root().add_child(main)
	await _settle()
	var ui = main.sandbox_ui
	_check(ui != null, "the sandbox has its menu")
	if ui == null:
		quit(1)
		return
	var dd: OptionButton = ui.find_child("SummonDropdown", true, false)
	var btn: Button = ui.find_child("SummonButton", true, false)
	_check(dd != null and btn != null, "with a Summon row (list + Spawn)")
	_check(dd != null and dd.item_count == ui.SUMMON_ORDER.size(), "listing every summon")
	if dd == null or btn == null:
		quit(1)
		return
	for i in range(dd.item_count):
		var before := _count(main)
		dd.select(i)
		btn.pressed.emit()
		await _settle(2)
		_check(_count(main) == before + 1, "%s spawns (%d -> %d)" % [dd.get_item_text(i), before, _count(main)])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
