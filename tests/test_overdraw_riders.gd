extends SceneTree

## Shield Overdraw riders fire when a draw meets a full hand, with or
## without an overflow mode active. They used to run only inside
## OverflowManager.process_overflow, which a plain full-hand draw never
## reaches (handle_overflow returns early when no mode is active), so
## Castle Wall's "Overdraw: heal 5 and loose Rain of Arrows" never happened.
## Run: godot --headless --path . --script tests/test_overdraw_riders.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		print("  FAIL: " + msg)
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=== Overdraw riders test ===")
	var runner := SimRunner.new(self)
	var sc := SimScenario.with_defaults(CharacterBuilds.compose("brad", {"build": "castle_wall", "alt": "none", "enemy": "LARGE_BEAR"}))
	await runner.boot_only(sc, 1)
	var main = runner.main
	var dm = main.deck_manager
	var stats = main.player.get_stats()
	var shield = null
	for s in main.player.get_inventory().get_equipped_shields():
		if s.overdraw_heal > 0:
			shield = s
	_check(shield != null, "Castle Wall is worn and carries an Overdraw heal")
	_check(main.overflow_manager.overflow_effects.is_empty(), "no overflow mode is active (the ordinary case)")
	# Fill the hand to its cap, take a wound, then let the draw timer draw.
	while dm.hand.size() < dm.get_hand_cap() and not dm.draw_pile.is_empty():
		dm.draw_card()
	stats.current_health = stats.max_health - 20
	var hp0: int = stats.current_health
	var pile0: int = dm.draw_pile.size()
	dm.attempt_draw()
	_check(dm.hand.size() == dm.get_hand_cap() and dm.draw_pile.size() == pile0,
		"the overdrawn card stays on the draw pile (no overflow mode)")
	_check(stats.current_health >= hp0 + shield.overdraw_heal,
		"the shield's Overdraw heal fires (%d -> %d)" % [hp0, stats.current_health])
	runner.teardown()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
