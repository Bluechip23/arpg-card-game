#!/usr/bin/env bash
# Refactor verification gate (see PLAN.md, Step 0).
#
#   tools/refactor_gate.sh snapshot <out_dir> [quick|full]   # run the gate, write results under <out_dir>
#   tools/refactor_gate.sh compare  <baseline_dir> <out_dir> # byte-compare two snapshots (exit 1 on any difference)
#
# quick (~3 min): parse sweep, sim determinism, catalog dump, example sweep,
#   and the first 2 jobs of every character's *_designed.txt at seeds 1-10.
# full (~40 min on 4 shards): quick + every *_designed.txt, combos.txt,
#   build_divergence.txt and enemy_strategy.txt at seeds 1-20, + tests/run_all.sh.
# The stored sweep files are never edited; seed-rewritten copies live in <out_dir>/sweeps.
# Quick-tier combats land in <out_dir>/sim_quick, full-tier ones in <out_dir>/sim_full, so the
# 10-seed and 20-seed versions of a designed job never overwrite each other.
# stamp.txt (the code hash) and logs are excluded from the comparison by design.
set -u
cd "$(dirname "$0")/.."
mode="${1:-}"
case "$mode" in
snapshot)
	out="${2:?out_dir}"; tier="${3:-quick}"
	shards="${SHARDS:-4}"
	mkdir -p "$out/sweeps" "$out/logs" "$out/sim_quick"
	# Keep the Godot importer out of the results: without this a later
	# `godot --import` turns every result CSV into a translation table.
	touch "$out/.gdignore" "$(dirname "$out")/.gdignore" 2>/dev/null
	status=0
	run() { # name, command...
		local name="$1"; shift
		echo "== $name"
		if "$@" > "$out/logs/$name.log" 2>&1; then echo "   ok"; else echo "   FAILED (see $out/logs/$name.log)"; status=1; fi
	}
	# 1. every script parses
	run parse godot --headless --path . --script tests/test_parse_all.gd
	grep -E 'checked|failure' "$out/logs/parse.log" > "$out/parse.txt"
	# 2. the harness is still deterministic
	run determinism godot --headless --path . --script tests/test_sim_determinism.gd
	grep -E 'PASS|FAIL|failure' "$out/logs/determinism.log" > "$out/determinism.txt"
	# 3. every card / item / enemy stat / sphere node / build component
	run catalog godot --headless --quiet --path . --script tests/sim/dump_catalog.gd -- --out="$out/catalog.json"
	# 4. combat: the hand-written example sweep (baseline + hand_check scenarios, 3 policies)
	run sim_example godot --headless --quiet --path . --script tests/sim/run_sim.gd -- --sweep=tests/sim/sweeps/example.txt --out="$out/sim_quick"
	# 5. combat: first 2 jobs of each character's designed sweep, 10 seeds
	: > "$out/sweeps/quick_designed.txt"
	for c in brad cory jeremy ryan stephen; do
		grep -v '^#' "tests/sim/sweeps/${c}_designed.txt" | grep . | head -2 | sed 's/seeds=[0-9]*-[0-9]*/seeds=1-10/' >> "$out/sweeps/quick_designed.txt"
	done
	run sim_quick_designed godot --headless --quiet --path . --script tests/sim/run_sim.gd -- --sweep="$out/sweeps/quick_designed.txt" --out="$out/sim_quick"
	if [ "$tier" = "full" ]; then
		mkdir -p "$out/sim_full"
		# 6. combat at 20 seeds, sharded: every designed build, the card-pair combos,
		#    the allocation x enemy matrix, and every acting enemy under both policies
		: > "$out/sweeps/full_designed.txt"
		for c in brad cory jeremy ryan stephen; do
			grep -v '^#' "tests/sim/sweeps/${c}_designed.txt" | grep . | sed 's/seeds=[0-9]*-[0-9]*/seeds=1-20/' >> "$out/sweeps/full_designed.txt"
		done
		for s in combos build_divergence enemy_strategy; do
			grep -v '^#' "tests/sim/sweeps/$s.txt" | grep . | sed 's/seeds=[0-9]*-[0-9]*/seeds=1-20/' > "$out/sweeps/${s}_20.txt"
		done
		for s in full_designed combos_20 build_divergence_20 enemy_strategy_20; do
			run "sim_$s" tools/sim_analysis/run_sweep.sh "$out/sweeps/$s.txt" "$shards" "$out/sim_full"
		done
		# 7. the SceneTree test suite (PASS/FAIL set only; log paths differ per run)
		echo "== tests"
		tests/run_all.sh -j "$shards" -o "$out/logs/tests" > "$out/logs/tests.log" 2>&1 || true
		grep -E '^(PASS|FAIL) ' "$out/logs/tests.log" | sort > "$out/tests.txt"
		echo "   $(grep -c '^PASS' "$out/tests.txt") passed, $(grep -c '^FAIL' "$out/tests.txt") failed"
	fi
	rm -rf "$out/sim_quick/logs" "$out/sim_full/logs"
	echo "== snapshot $tier -> $out (status $status)"
	exit $status
	;;
compare)
	base="${2:?baseline_dir}"; out="${3:?out_dir}"
	# Only compare what the other side also produced (a quick snapshot vs a full baseline).
	fail=0
	for f in parse.txt determinism.txt catalog.json tests.txt; do
		if [ -f "$base/$f" ] && [ -f "$out/$f" ]; then
			if [ "$f" = parse.txt ]; then
				# the script count may change (a refactor adds or removes files); the failure count may not
				if [ "$(grep failure "$base/$f")" = "$(grep failure "$out/$f")" ]; then echo "same   $f (failure count)"; else echo "DIFF   $f"; fail=1; fi
			elif cmp -s "$base/$f" "$out/$f"; then echo "same   $f"; else echo "DIFF   $f"; fail=1; fi
		fi
	done
	# Sim: every job directory present in the snapshot must be byte-identical to the baseline's.
	for tier in sim_quick sim_full; do
		[ -d "$out/$tier" ] || continue
		n=0
		while IFS= read -r -d '' d; do
			rel="${d#$out/$tier/}"
			[ -d "$base/$tier/$rel" ] || { echo "MISSING-IN-BASELINE $tier/$rel"; fail=1; continue; }
			if diff -rq --exclude=stamp.txt "$base/$tier/$rel" "$d" > /dev/null; then n=$((n+1)); else echo "DIFF   $tier/$rel"; diff -rq --exclude=stamp.txt "$base/$tier/$rel" "$d" | head -3; fail=1; fi
		done < <(find "$out/$tier" -mindepth 2 -maxdepth 2 -type d -print0)
		echo "$tier: $n job dir(s) identical"
	done
	[ $fail -eq 0 ] && echo "== MATCH" || echo "== MISMATCH"
	exit $fail
	;;
*)
	echo "usage: $0 snapshot <out_dir> [quick|full] | compare <baseline_dir> <out_dir>"; exit 2 ;;
esac
