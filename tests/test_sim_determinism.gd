extends SceneTree

## The simulation harness is deterministic: the same scenario, policy and
## seed produce byte-identical per-run CSVs and summaries, and different
## seeds differ. Runs the baseline under the random policy (the one that
## consumes the most RNG) twice.
## Run: godot --headless --path . --script tests/test_sim_determinism.gd

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
	print("=== Sim determinism test ===")
	var sc := SimScenario.load_file("res://tests/sim/scenarios/baseline.gd")
	_check(SimScenario.validate(sc) == "", "the baseline scenario validates")
	var runner := SimRunner.new(self)
	var outputs := {}
	for pass_index in range(2):
		for s in [11, 12]:
			var policy = load("res://tests/sim/policies/random.gd").new()
			var summary: Dictionary = await runner.run(sc, policy, s)
			var key := "%d/%d" % [pass_index, s]
			outputs[key] = {"csv": runner.run_csv_text(), "summary": SimRunner.summary_csv_line(summary)}
			_check(summary["outcome"] in ["win", "loss", "timeout"], "pass %d seed %d finished as %s" % [pass_index, s, summary["outcome"]])
	for s in [11, 12]:
		_check(outputs["0/%d" % s]["csv"] == outputs["1/%d" % s]["csv"], "seed %d: identical per-run CSV on both passes" % s)
		_check(outputs["0/%d" % s]["summary"] == outputs["1/%d" % s]["summary"], "seed %d: identical summary row" % s)
	_check(outputs["0/11"]["csv"] != outputs["0/12"]["csv"], "seeds 11 and 12 play out differently")
	_check(outputs["0/11"]["csv"].split("\n").size() > 2, "the run produced rows (%d lines)" % outputs["0/11"]["csv"].split("\n").size())
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
