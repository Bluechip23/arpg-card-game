extends SceneTree

## The scripted hand-check scenario matches numbers worked out by hand:
## a level-1 Brad (STR 3, crit forced to 0) plays Attack on an adjacent
## Wererat. Expected: 10 + floor(3 * 0.5) = 11 damage, the 8-HP rat dies,
## 20 mana spent, the card's 3 tempo elapse, the rat never acts.
## Run: godot --headless --path . --script tests/test_sim_hand_check.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Sim hand-check test ===")
	var sc := SimScenario.load_file("res://tests/sim/scenarios/hand_check.gd")
	var runner := SimRunner.new(self)
	var policy = load("res://tests/sim/policies/scripted.gd").new()
	var summary: Dictionary = await runner.run(sc, policy, 1)
	_check(runner.warnings.is_empty(), "no build warnings: %s" % str(runner.warnings))
	_check(summary["outcome"] == "win", "outcome is win (%s %s)" % [summary["outcome"], summary["error"]])
	var rows: Array = runner.rows
	_check(rows.size() == 1, "exactly one row: the player's Attack (%d)" % rows.size())
	if rows.is_empty():
		quit(1)
		return
	var r: Dictionary = rows[0]
	var expected_damage := 10 + int(floor(3 * 0.5))
	_check(r["actor"] == "player" and r["action_id"] == "play:slash", "row is the player's Attack")
	_check(r["tempo_before"] == 0 and r["tempo_after"] == 3, "the card's 3 tempo elapse (%d -> %d)" % [r["tempo_before"], r["tempo_after"]])
	_check(r["damage_dealt"] == expected_damage, "Attack deals %d (got %d)" % [expected_damage, r["damage_dealt"]])
	_check(r["damage_taken"] == 0, "the rat never bites")
	_check(r["enemy_hp"] == 0 and r["enemy_id"] == "Wererat#0", "the rat is dead (%s hp %s)" % [r["enemy_id"], str(r["enemy_hp"])])
	_check(r["distance"] == 1 and r["player_pos"] == "6:7" and r["enemy_pos"] == "7:7", "positions and distance as placed")
	_check(r["player_hp"] == 10 and r["player_mana"] == 50, "pre-action HP 10 / mana 50 (got %d / %d)" % [r["player_hp"], r["player_mana"]])
	_check(r["hand_size"] == 4, "opening hand of 4 (%d)" % r["hand_size"])
	_check(summary["total_damage_dealt"] == expected_damage and summary["total_damage_taken"] == 0, "summary totals match")
	_check(is_equal_approx(summary["bars_elapsed"], 0.6), "0.6 bars elapsed (%.2f)" % summary["bars_elapsed"])
	_check(is_equal_approx(summary["damage_per_tempo"], expected_damage / 3.0), "damage per tempo = 11/3 (%.3f)" % summary["damage_per_tempo"])
	_check(summary["cards_played"] == 1 and summary["distinct_cards_played"] == 1 and is_zero_approx(summary["card_entropy"]), "one card, entropy 0")
	_check(summary["enemy_actions_by_type"] == "", "the rat took no action")
	_check(is_equal_approx(summary["end_hp_pct"], 1.0), "ends at full health")
	# CSV text round-trips the row exactly.
	var csv := runner.run_csv_text()
	var expected_line := "0,0,3,player,play:slash,enemy:0,10,0,0,50,4,Wererat#0,0,7:7,6:7,1,%d,0,,," % expected_damage
	_check(csv.split("\n")[1] == expected_line, "CSV row is byte-exact:\n    %s" % csv.split("\n")[1])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
