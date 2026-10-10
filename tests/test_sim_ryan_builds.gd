extends SceneTree

## Every designed Ryan build assembles through the real rules without a
## refusal: one mythic within the level-18 cap, gear under the carry
## weight, every slotted card accepted by its slot, every sphere target
## reachable past its stat gate, every passive rank paid for. Also checks
## that compose() swaps components and the runner keeps a mismatched part.
## Run: godot --headless --path . --script tests/test_sim_ryan_builds.gd

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
	print("=== Ryan build directory test ===")
	var runner := SimRunner.new(self)
	for build in RyanBuilds.DESIGNED.keys():
		var sc := SimScenario.with_defaults(RyanBuilds.compose({"build": build, "enemy": "WERERAT"}))
		_check(SimScenario.validate(sc) == "", "%s validates" % build)
		var policy = load("res://tests/sim/policies/lookahead.gd").new()
		var summary: Dictionary = await runner.run(sc, policy, 1)
		_check(runner.warnings.is_empty(), "%s builds with no refusals: %s" % [build, str(runner.warnings)])
		_check(summary["outcome"] in ["win", "loss", "timeout"], "%s ran to %s" % [build, summary["outcome"]])
		var stats = null
	# A mismatch keeps the swapped parts.
	var mixed := SimScenario.with_defaults(RyanBuilds.compose({"build": "bruiser", "deck": "potions", "alloc": "int_wis", "sphere": "none", "passives": "apothecary", "enemy": "WERERAT"}))
	_check(mixed["player"]["deck"] == RyanBuilds.DECKS["potions"], "compose swaps the deck")
	_check(mixed["player"]["allocation"] == RyanBuilds.ALLOCS["int_wis"], "compose swaps the allocation")
	_check(mixed["player"]["sphere_targets"].is_empty() and mixed["player"]["passives"] == RyanBuilds.PASSIVES["apothecary"], "compose swaps sphere path and passives")
	_check(mixed["player"]["items"] == RyanBuilds.ITEM_SETS["bruiser"], "the build's own gear stays")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
