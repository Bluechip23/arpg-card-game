extends SceneTree

## The swing hold (designer, 2026-10-31): when an enemy's attack fires, the
## tick clock pauses for the length of its swing plus a beat, so the slash,
## bite or shot plays out before the next tick lands. On by default; the
## Settings tab turns it off (TempoManager.remember_swing_hold), and then
## ticks resolve as they always did. The clock is driven by hand here, so
## nothing depends on frame timing.
## Run: godot --headless --path . --script tests/test_swing_hold.gd

var failures := 0
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

func _run() -> void:
	print("=== Swing hold test ===")
	_test_clock()
	await _test_enemy()
	TempoManager.preferred_swing_hold = -1
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


## Ticks a bare clock by hand: the hold stalls it, then it runs on.
func _test_clock() -> void:
	print("-- The clock --")
	TempoManager.preferred_swing_hold = 1   # on, whatever the settings file says
	var tm := TempoManager.new()
	tm.initialize(null)
	tm.tick_speed = 0.1
	var card := Card.new()
	card.card_name = "Test Ticks"
	tm.start_card_ticks(card, 10, 10)
	tm._process(0.1)
	_check(tm.get_global_tempo() == 1, "a tick lands at the tick speed (%d)" % tm.get_global_tempo())
	tm.hold_for(0.5)
	_check(tm.is_holding_for_swing(), "an enemy's swing holds the clock")
	tm._process(0.1)
	tm._process(0.1)
	tm._process(0.1)
	tm._process(0.1)
	_check(tm.get_global_tempo() == 1, "no tick lands during the swing (%d)" % tm.get_global_tempo())
	tm.hold_for(0.05)
	_check(tm._hold_timer > 0.09 and tm._hold_timer < 0.11, "a shorter swing never cuts a longer hold short (%.2f left)" % tm._hold_timer)
	tm.hold_for(0.3)
	_check(tm._hold_timer > 0.29, "a longer swing extends it (%.2f left)" % tm._hold_timer)
	tm._process(0.1)
	tm._process(0.1)
	tm._process(0.1)
	_check(not tm.is_holding_for_swing(), "the swing done, the hold lifts")
	tm._process(0.1)
	_check(tm.get_global_tempo() == 2, "and the clock runs on from where it stopped (%d)" % tm.get_global_tempo())
	# Off: the swing changes nothing.
	TempoManager.preferred_swing_hold = 0
	tm.hold_for(0.5)
	_check(not tm.is_holding_for_swing(), "with the hold off, a swing does not touch the clock")
	tm._process(0.1)
	_check(tm.get_global_tempo() == 3, "ticks resolve as they always did (%d)" % tm.get_global_tempo())
	TempoManager.preferred_swing_hold = 1
	_check(TempoManager.swing_hold_enabled(), "the hold is on again")
	tm.free()


## A wolf's bite in the dojo: the fired swing holds Main's clock for the
## bite's frames plus the beat.
func _test_enemy() -> void:
	print("-- The enemy --")
	TempoManager.preferred_swing_hold = 1
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null and main.enemy_spawner != null and main.tempo_manager != null, "the dojo is up")
	if main.player == null:
		return
	var tm = main.tempo_manager
	main.player.get_stats().current_health = 500
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var w: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WOLF, main._ground_pos(cell + Vector2i(1, 0)))
	await _settle(2)
	var fig: SpriteEnemyFigure = w._enemy_figure
	_check(fig != null and fig._cp_sheets.has("Attack"), "the wolf wears its bite sheet")
	_check(not tm.is_holding_for_swing(), "nothing holds the clock before the bite")
	w._execute_action("wolf_bite", main.player)
	var swing: float = fig.attack_time() if fig else 0.0
	_check(fig != null and fig._cp_anim == "Attack" and absf(swing - 0.4) < 0.01, "the bite swings for %.2f s (4 frames at 10 fps)" % swing)
	_check(tm.is_holding_for_swing() and absf(tm._hold_timer - (swing + TempoManager.SWING_HOLD_BEAT)) < 0.01,
		"the fired bite holds the clock for the swing and a beat (%.2f s)" % tm._hold_timer)
	tm._hold_timer = 0.0
	# A move holds nothing.
	w._play_enemy_animation("move")
	_check(not tm.is_holding_for_swing(), "a move never holds the clock")
	# Off: the bite fires and the clock is not held.
	TempoManager.preferred_swing_hold = 0
	w._execute_action("wolf_bite", main.player)
	_check(not tm.is_holding_for_swing(), "with the hold off, the bite leaves the clock alone")
	main.enemy_spawner.despawn_enemy(w)
