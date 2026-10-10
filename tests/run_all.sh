#!/usr/bin/env bash
# Runs every tests/test_*.gd headlessly and reports pass/fail counts.
# Usage: tests/run_all.sh [-j N] [-o logdir] [pattern]
#   -j N      run N tests in parallel (default 1)
#   -o DIR    write one log per test into DIR (default: a temp dir)
#   pattern   only tests whose file name contains it (e.g. "sim")
set -u
cd "$(dirname "$0")/.."
jobs=1; logdir=""; pattern=""
while [ $# -gt 0 ]; do
	case "$1" in
		-j) jobs="$2"; shift 2 ;;
		-o) logdir="$2"; shift 2 ;;
		*) pattern="$1"; shift ;;
	esac
done
[ -z "$logdir" ] && logdir="$(mktemp -d)"
mkdir -p "$logdir"
tests=$(ls tests/test_*.gd | grep -- "$pattern")
run_one() {
	local t="$1" name
	name="$(basename "$t" .gd)"
	if timeout 600 godot --headless --path . --script "$t" > "$logdir/$name.log" 2>&1; then
		echo "PASS $name"
	else
		echo "FAIL $name"
	fi
}
export -f run_one
export logdir
results="$(printf '%s\n' $tests | xargs -P "$jobs" -I{} bash -c 'run_one {}')"
echo "$results" | sort
pass=$(echo "$results" | grep -c '^PASS')
fail=$(echo "$results" | grep -c '^FAIL')
echo "=== $pass passed, $fail failed (logs in $logdir) ==="
[ "$fail" -eq 0 ]
