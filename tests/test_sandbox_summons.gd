extends SceneTree

## The sandbox menu's Summon row: every summoned ally the game has is in the
## list, and each one, spawned from it, stands on the field beside the player.
## The panel never runs off the right edge of the screen.
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
	# The panel stays on screen: nothing inside (a dropdown's longest entry,
	# a long card or passive name) may push it past the right edge.
	ui._panel.visible = true
	var vp_w: float = ui._panel.get_viewport_rect().size.x
	var worst := 0.0
	for tab in [0, 1]:
		ui._set_tab(tab)
		for g in range(ui._char_dd.item_count):
			ui._char_dd.select(g)
			ui._refresh_active_tab()
			await process_frame
			worst = maxf(worst, ui._panel.get_global_rect().end.x)
	_check(worst <= vp_w, "the sandbox panel stays on screen on every tab and list (right edge %d of %d)" % [worst, vp_w])
	_check(ui._panel.size.x <= 300.0, "and keeps its width (%d)" % ui._panel.size.x)
	_check(btn.size.x >= 40.0 and btn.get_global_rect().end.x <= vp_w, "the Summon row's Spawn button shows in full (%d wide)" % btn.size.x)
	var ally_btn: Button = ui._ally_btn
	_check(ally_btn.size.x >= 40.0 and ally_btn.get_global_rect().end.x <= vp_w, "and so does Add Ally's (%d wide)" % ally_btn.size.x)
	for i in range(dd.item_count):
		var before := _count(main)
		dd.select(i)
		btn.pressed.emit()
		await _settle(2)
		_check(_count(main) == before + 1, "%s spawns (%d -> %d)" % [dd.get_item_text(i), before, _count(main)])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
