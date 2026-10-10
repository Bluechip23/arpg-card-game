extends SceneTree

## Milestone 2 check: on a fight that actually threatens the player (the
## skeleton scenario) the strategic policy is at least as good as the
## auto-attacker on win rate and damage taken, both out-damage the random
## floor per tempo (lookahead may trade raw damage for safety). 20 seeds each (~30 s).
## Run: godot --headless --path . --script tests/test_sim_policies.gd

const SEEDS := 20
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
	print("=== Sim policy ordering test ===")
	var sc := SimScenario.load_file("res://tests/sim/scenarios/skeleton.gd")
	var runner := SimRunner.new(self)
	var stats := {}
	for pol_name in ["random", "greedy_dpt", "lookahead"]:
		var wins := 0
		var dpt := 0.0
		var taken := 0.0
		for s in range(1, SEEDS + 1):
			var policy = load("res://tests/sim/policies/%s.gd" % pol_name).new()
			var summary: Dictionary = await runner.run(sc, policy, s)
			_check(summary["outcome"] != "error", "%s seed %d ran without error (%s)" % [pol_name, s, summary["error"]])
			if summary["outcome"] == "win":
				wins += 1
			dpt += float(summary["damage_per_tempo"])
			taken += float(summary["total_damage_taken"])
		stats[pol_name] = {"win": float(wins) / SEEDS, "dpt": dpt / SEEDS, "taken": taken / SEEDS}
		print("  %s: win %.2f, dpt %.2f, taken %.1f" % [pol_name, stats[pol_name]["win"], stats[pol_name]["dpt"], stats[pol_name]["taken"]])
	_check(stats["random"]["dpt"] < stats["greedy_dpt"]["dpt"], "greedy out-damages random per tempo")
	_check(stats["greedy_dpt"]["win"] <= stats["lookahead"]["win"], "lookahead wins at least as often as greedy")
	# Lookahead prices mitigation (block / sidestep / wait when a hit is coming),
	# so it may trade damage per tempo for fights it does not lose; it must still
	# clearly out-damage the random player.
	_check(stats["random"]["dpt"] < stats["lookahead"]["dpt"], "lookahead out-damages random per tempo")
	_check(stats["lookahead"]["taken"] <= stats["greedy_dpt"]["taken"], "lookahead takes no more damage than greedy")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
