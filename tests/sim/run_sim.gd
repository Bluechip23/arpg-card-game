extends SceneTree

## Combat simulation harness entry point (docs/sim/README.md).
##
##   godot --headless --path . --script tests/sim/run_sim.gd -- \
##       --scenario=tests/sim/scenarios/baseline.gd --seed=1 --runs=100 \
##       --policy=greedy_dpt --out=sim_out/ [--verbose]
##   godot --headless --path . --script tests/sim/run_sim.gd -- --sweep=tests/sim/sweeps/example.txt
##
## Writes sim_out/<scenario>/<policy>/<seed>.csv per run, summary.csv per
## scenario × policy, and aggregate.csv over the seeds run. The game's own
## prints are noisy; add --quiet to Godot and read the report on stderr.

const POLICY_DIR := "res://tests/sim/policies/"

var _args := {}
var _runner: SimRunner
var _failures := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_runner = SimRunner.new(self)
	_runner.verbose = _args.has("verbose")
	_go()

func _go() -> void:
	var jobs: Array = []
	if _args.has("sweep"):
		jobs = parse_sweep(str(_args["sweep"]))
	elif _args.has("scenario"):
		jobs.append({
			"scenario": str(_args["scenario"]),
			"policy": str(_args.get("policy", "")),
			"seed": int(_args.get("seed", "1")),
			"runs": int(_args.get("runs", "1")),
		})
	else:
		printerr("usage: --scenario=<path> [--seed=n] [--runs=k] [--policy=name] [--out=dir] | --sweep=<file>")
		quit(2)
		return
	var out_dir := str(_args.get("out", "sim_out"))
	var started := Time.get_ticks_msec()
	var total_runs := 0
	for job in jobs:
		var sc := SimScenario.load_file(_to_res(job["scenario"]))
		if sc.is_empty():
			_failures += 1
			continue
		var problem := SimScenario.validate(sc)
		if problem != "":
			printerr("[SIM] %s: %s" % [job["scenario"], problem])
			_failures += 1
			continue
		var policy_name: String = str(job["policy"]) if str(job["policy"]) != "" else str(sc["policy"])
		var policy := make_policy(policy_name)
		if policy == null:
			printerr("[SIM] unknown policy '%s'" % policy_name)
			_failures += 1
			continue
		var dir := "%s/%s/%s" % [_abs(out_dir), sc["name"], policy_name]
		var summaries: Array = []
		var t0 := Time.get_ticks_msec()
		for i in range(int(job["runs"])):
			var s: int = int(job["seed"]) + i
			var summary: Dictionary = await _runner.run(sc, policy, s)
			SimRunner.write_text("%s/%d.csv" % [dir, s], _runner.run_csv_text())
			SimRunner.append_summary("%s/summary.csv" % dir, summary)
			summaries.append(summary)
			total_runs += 1
			for w in _runner.warnings:
				printerr("[SIM] warning (seed %d): %s" % [s, w])
		SimRunner.write_text("%s/aggregate.csv" % dir, SimRunner.aggregate_text(summaries))
		var wins := 0
		for s in summaries:
			if s["outcome"] == "win":
				wins += 1
		printerr("[SIM] %s / %s: %d run(s), %d win(s), %.1f s -> %s" % [
			sc["name"], policy_name, summaries.size(), wins, (Time.get_ticks_msec() - t0) / 1000.0, dir])
	printerr("[SIM] done: %d run(s) in %.1f s%s" % [total_runs, (Time.get_ticks_msec() - started) / 1000.0,
		"" if _failures == 0 else ", %d job(s) failed" % _failures])
	quit(1 if _failures > 0 else 0)

## Sweep file: one job per line, `key=value` pairs separated by spaces.
## Keys: scenario, policy, seed, runs (or seeds=a-b). `#` starts a comment.
static func parse_sweep(path: String) -> Array:
	var jobs: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("[SIM] cannot read sweep %s" % path)
		return jobs
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var job := {"policy": "", "seed": 1, "runs": 1}
		for tok in line.split(" ", false):
			var kv := tok.split("=", true, 1)
			if kv.size() != 2:
				continue
			match kv[0]:
				"seeds":
					var ab := kv[1].split("-")
					job["seed"] = int(ab[0])
					job["runs"] = int(ab[1]) - int(ab[0]) + 1 if ab.size() > 1 else 1
				"seed": job["seed"] = int(kv[1])
				"runs": job["runs"] = int(kv[1])
				_: job[kv[0]] = kv[1]
		if job.has("scenario"):
			jobs.append(job)
	return jobs

static func make_policy(policy_name: String) -> SimPolicy:
	var script = load(POLICY_DIR + policy_name + ".gd")
	if script == null:
		return null
	return script.new()

static func _to_res(path: String) -> String:
	if path.begins_with("res://") or path.is_absolute_path():
		return path
	return "res://" + path

static func _abs(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://").path_join(path)
