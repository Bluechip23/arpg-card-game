extends SceneTree

## Wisdom speeds up the auto draw: the 25-tempo interval loses
## DRAW_TEMPO_PER_WIS per effective WIS point and never drops below
## MIN_DRAW_TEMPO, and the DrawTimer draws on exactly that cadence.
## Run: godot --headless --path . --script tests/test_wis_draw_timer.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== WIS draw timer test ===")
	var stats := PlayerStats.new()
	get_root().add_child(stats)
	stats.initialize(CharacterData.create_brad())
	var per: float = PlayerStats.DRAW_TEMPO_PER_WIS
	var floor_t: float = PlayerStats.MIN_DRAW_TEMPO
	_check(is_equal_approx(stats.get_effective_draw_timer(), 25.0 - stats.wisdom * per),
		"starting WIS %d draws every %.1f tempo" % [stats.wisdom, stats.get_effective_draw_timer()])
	stats.base_wisdom = 20
	_check(is_equal_approx(stats.get_effective_draw_timer(), 25.0 - 20.0 * per),
		"WIS 20 draws every %.1f tempo" % stats.get_effective_draw_timer())
	stats.base_wisdom = 60
	_check(is_equal_approx(stats.get_effective_draw_timer(), floor_t),
		"the interval never drops below %.0f tempo" % floor_t)
	stats.base_wisdom = 10
	var dm := DeckManager.new()
	get_root().add_child(dm)
	dm.connect_player_stats(stats)
	for i in range(3):
		dm.draw_pile.append(Card.create_slash())
	var tm := DrawTimer.new()
	get_root().add_child(tm)
	tm.initialize(stats, dm)
	var interval: int = int(stats.get_effective_draw_timer())
	_check(is_equal_approx(tm.tempo_until_draw, 25.0 - 10.0 * per), "the timer starts a full WIS-shortened interval away")
	for i in range(interval - 1):
		tm.process_tempo(1)
	_check(dm.hand.is_empty(), "no draw one tempo short of the interval")
	tm.process_tempo(1)
	_check(dm.hand.size() == 1, "the draw lands on the WIS-shortened interval (%d tempo)" % interval)
	stats.base_wisdom = 30
	tm.process_tempo(1)
	_check(is_equal_approx(tm.draw_every_x_tempo, floor_t), "raising WIS mid-fight shortens the next interval (%.1f)" % tm.draw_every_x_tempo)
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
