extends SceneTree

## Milestone 5 verification. (1) A fight only won by setup-then-payoff —
## Vulnerable, then the burst into it — that the one-step lookahead loses and
## the combo planner wins. (2) On a deck with no registered combos (the
## skeleton scenario, starter deck) the planner matches lookahead within
## noise on win rate, damage per tempo and damage taken.
## Run: godot --headless --path . --script tests/test_combo_planner.gd

const SEEDS := 12
var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _stats(runner: SimRunner, sc: Dictionary, pol_name: String, seeds: int) -> Dictionary:
	var wins := 0
	var dpt := 0.0
	var taken := 0.0
	var plans := {}
	for s in range(1, seeds + 1):
		var policy = load("res://tests/sim/policies/%s.gd" % pol_name).new()
		var summary: Dictionary = await runner.run(sc, policy, s)
		_check(summary["outcome"] != "error", "%s / %s seed %d ran without error (%s)" % [sc["name"], pol_name, s, summary["error"]])
		if summary["outcome"] == "win":
			wins += 1
		dpt += float(summary["damage_per_tempo"])
		taken += float(summary["total_damage_taken"])
		if "last_plan" in policy:
			plans[s] = policy.last_plan
	return {"win": float(wins) / seeds, "dpt": dpt / seeds, "taken": taken / seeds, "plans": plans}

func _run() -> void:
	print("=== Combo planner test ===")
	var runner := SimRunner.new(self)
	var SimCombos = load("res://tests/sim/combos.gd")
	_check(SimCombos.registry().is_empty(), "the promoted registry is empty (3b has scored no positive synergy yet)")

	# --- 1. Setup then payoff: lookahead loses, the planner wins — unaided.
	var sc := SimScenario.load_file("res://tests/sim/scenarios/setup_payoff.gd")
	var la: Dictionary = await _stats(runner, sc, "lookahead", 4)
	var cp: Dictionary = await _stats(runner, sc, "combo_planner", 4)
	print("  setup_payoff: lookahead win %.2f, planner win %.2f" % [la["win"], cp["win"]])
	_check(la["win"] == 0.0, "lookahead loses the setup-then-payoff fight (win %.2f)" % la["win"])
	_check(cp["win"] == 1.0, "the combo planner wins it (win %.2f)" % cp["win"])

	# --- 1b. The same fight with the combo registered: still won (the macro is priced as a unit).
	SimCombos.register({"id": "stance_switch+heavy_swing", "cards": ["stance_switch", "heavy_swing"],
		"preconditions": {"target": "enemy", "min_mana": 40}, "payoff": 6.0})
	var cp2: Dictionary = await _stats(runner, sc, "combo_planner", 2)
	_check(cp2["win"] == 1.0, "with the combo registered the planner still wins (win %.2f)" % cp2["win"])
	SimCombos.clear_extra()

	# --- 2. No registered combos: the planner matches lookahead within noise.
	var sk := SimScenario.load_file("res://tests/sim/scenarios/skeleton.gd")
	var la2: Dictionary = await _stats(runner, sk, "lookahead", SEEDS)
	var cp3: Dictionary = await _stats(runner, sk, "combo_planner", SEEDS)
	print("  skeleton: lookahead win %.2f dpt %.2f taken %.1f | planner win %.2f dpt %.2f taken %.1f" % [
		la2["win"], la2["dpt"], la2["taken"], cp3["win"], cp3["dpt"], cp3["taken"]])
	_check(absf(cp3["win"] - la2["win"]) <= 0.15, "win rate within noise (%.2f vs %.2f)" % [cp3["win"], la2["win"]])
	_check(absf(cp3["dpt"] - la2["dpt"]) <= 0.25 * maxf(0.5, la2["dpt"]), "damage per tempo within noise (%.2f vs %.2f)" % [cp3["dpt"], la2["dpt"]])
	_check(cp3["taken"] <= la2["taken"] + 0.25 * maxf(4.0, la2["taken"]), "damage taken within noise (%.1f vs %.1f)" % [cp3["taken"], la2["taken"]])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
