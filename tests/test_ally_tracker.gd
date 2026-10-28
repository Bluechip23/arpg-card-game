extends SceneTree

## The Allies & Summons tab (designer, 2026-10-28): beside the Enemies tab,
## listing every ally on the field — the other hero and every summon — with
## its picture, health, armor and its buffs / debuffs. Opening one tab closes
## the other.
## Run: godot --headless --path . --script tests/test_ally_tracker.gd

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

func _poll(ut) -> void:
	ut._ally_poll = 0.0
	await process_frame
	await process_frame

func _row_for(ut, u) -> Node:
	return ut._ally_content.get_node_or_null("Ally_%d" % u.get_instance_id())

func _run() -> void:
	print("=== Allies & Summons tab ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_jeremy())
	main.set("sandbox_mode", true)
	get_root().add_child(main)
	await _settle()
	if main.olorin and main.olorin.is_busy():
		main.olorin._close()
	var ut: UnitTrackerUI = main.unit_tracker
	await _poll(ut)
	_check(not ut._ally_btn.visible, "no allies: no Allies tab")

	main._on_sandbox_spawn_enemy(Enemy.EnemyType.WERERAT)
	main.player.get_stats().base_intelligence = 40
	main._on_sandbox_spawn_summon("battle_turtle")
	main._on_sandbox_spawn_summon("specter")
	main._refresh_unit_tracker()
	await _poll(ut)
	_check(ut._ally_btn.visible and ut._ally_btn.text.contains("Allies & Summons (2)"), "a summon on the field: the tab shows, counting them (%s)" % ut._ally_btn.text)
	_check(ut._ally_btn.position.x >= ut._toggle_btn.get_combined_minimum_size().x, "it sits beside the Enemies tab")
	_check(ut._content.visible and not ut._ally_content.visible, "the Enemies list stays open until the tab is pressed")

	ut._ally_btn.pressed.emit()
	await _poll(ut)
	_check(ut._ally_content.visible and not ut._content.visible, "pressing it: the allies' list, the enemies' closed")
	var turtle = main._skeletons.filter(func(s): return s.kind == "battle_turtle")[0]
	var spec = main._specters[0]
	var trow := _row_for(ut, turtle)
	_check(trow != null, "the Battle Turtle has a row")
	if trow:
		_check(trow.find_child("Name", true, false).text == "Battle Turtle", "named")
		var line: String = trow.find_child("Stats", true, false).text
		_check(line.contains("25/25 HP") and line.contains("ARM 20/20"), "with its health and its armor out of its cap (%s)" % line)
		var pic := trow.find_child("*", true, false)
		_check(trow.find_children("*", "TextureRect", true, false).size() > 0, "and its picture")
	var srow := _row_for(ut, spec)
	_check(srow != null and srow.find_child("Effect_Fading", true, false) != null, "the Specter shows its Fading timer as a badge")

	# Live: damage shows on the next look.
	turtle.take_damage(30)
	await _poll(ut)
	trow = _row_for(ut, turtle)
	_check(trow and trow.find_child("Stats", true, false).text.contains("15/25 HP") and trow.find_child("Stats", true, false).text.contains("ARM 0/20"),
		"a hit shows at once: armor first, then health (%s)" % (trow.find_child("Stats", true, false).text if trow else "-"))

	# A buff on the other hero shows as a badge.
	main._on_sandbox_add_ally("Brad")
	await _settle(3)
	var brad = main._p2_player if main.player != main._p2_player else main._p1_player
	if brad:
		brad.buff_manager.apply_buff(Buff.new(Buff.BuffType.STRENGTHEN, 3, 10))
	await _poll(ut)
	var brow := _row_for(ut, brad) if brad else null
	_check(brow != null and brow.find_child("Name", true, false).text == "Brad", "the other hero is listed")
	_check(brow != null and brow.find_child("Effects", true, false) != null, "with their buffs")

	# Back to the enemies.
	ut._toggle_btn.pressed.emit()
	await _poll(ut)
	_check(ut._content.visible and not ut._ally_content.visible, "the Enemies tab switches back")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
