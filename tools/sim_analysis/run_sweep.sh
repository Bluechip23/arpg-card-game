#!/usr/bin/env bash
# Runs one sweep file across N godot processes (one shard each) and waits.
# Jobs whose summary.csv already holds every seed are skipped, so a killed
# sweep resumes by re-running the same command (use a fresh out dir to redo).
# Usage: tools/sim_analysis/run_sweep.sh <sweep file> [shards=4] [out=sim_out]
set -u
cd "$(dirname "$0")/../.."
sweep="$1"; shards="${2:-4}"; out="${3:-sim_out}"
mkdir -p "$out/logs"
pids=()
for ((i = 0; i < shards; i++)); do
	godot --headless --quiet --path . --script tests/sim/run_sim.gd -- --sweep="$sweep" --shard="$i/$shards" --out="$out" --skip-done \
		> "$out/logs/$(basename "$sweep" .txt).$i.log" 2>&1 &
	pids+=($!)
done
status=0
for p in "${pids[@]}"; do wait "$p" || status=1; done
grep -h "^\[SIM\] done" "$out"/logs/"$(basename "$sweep" .txt)".*.log
exit $status
