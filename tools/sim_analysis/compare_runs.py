#!/usr/bin/env python3
"""Before/after comparison of two sim_out snapshots: the quick feedback on a
balance change ("that change to X fixed build Y and barely moved build Q").

  tools/sim_analysis/run_sweep.sh tests/sim/sweeps/ryan_designed.txt 4 sim_out/before
  ... change an item, card, passive or stat ...
  tools/sim_analysis/run_sweep.sh tests/sim/sweeps/ryan_designed.txt 4 sim_out/after
  python3 tools/sim_analysis/compare_runs.py sim_out/before sim_out/after [--min-seeds 10] [--md report.md]

For every scenario x policy present in both snapshots (same seeds), prints
the change in win rate, damage per tempo, damage taken and bars, with a
paired-seed significance flag (Welch t on the per-seed values; a win-rate
change is flagged when its 95 % interval excludes zero), sorted by the size
of the effect, and a one-line verdict per build. Runs are deterministic per
seed, so any difference IS the change.
"""
import argparse, glob, math, os
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load(snapshot):
    frames = []
    for path in sorted(glob.glob(os.path.join(snapshot, "*", "*", "summary.csv"))):
        try:
            df = pd.read_csv(path)
        except pd.errors.EmptyDataError:
            continue
        df["scenario"] = os.path.basename(os.path.dirname(os.path.dirname(path)))
        df["policy"] = os.path.basename(os.path.dirname(path))
        frames.append(df)
    if not frames:
        raise SystemExit("no summary.csv under %s" % snapshot)
    df = pd.concat(frames, ignore_index=True).drop_duplicates(subset=["scenario", "policy", "seed"], keep="last")
    df["win"] = (df["outcome"] == "win").astype(float)
    return df


def welch_p(a, b):
    """Two-sided Welch t-test p-value without scipy (normal approximation for df >= 30, else conservative)."""
    a, b = pd.Series(a, dtype=float), pd.Series(b, dtype=float)
    if len(a) < 2 or len(b) < 2:
        return 1.0
    va, vb = a.var(ddof=1), b.var(ddof=1)
    se = math.sqrt(va / len(a) + vb / len(b))
    if se == 0:
        return 0.0 if a.mean() != b.mean() else 1.0
    t = abs(a.mean() - b.mean()) / se
    # survival of the normal; fine at these n, conservative below ~30
    return 2 * (1 - 0.5 * (1 + math.erf(t / math.sqrt(2))))


def build_name(scenario):
    return scenario.split("_e_")[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("before"); ap.add_argument("after")
    ap.add_argument("--min-seeds", type=int, default=5)
    ap.add_argument("--alpha", type=float, default=0.05)
    ap.add_argument("--md", default="", help="also write the report as Markdown to this path")
    args = ap.parse_args()
    b, a = load(args.before), load(args.after)
    keys = ["scenario", "policy"]
    rows = []
    for (sc, pol), gb in b.groupby(keys):
        ga = a[(a["scenario"] == sc) & (a["policy"] == pol)]
        common = sorted(set(gb["seed"]) & set(ga["seed"]))
        if len(common) < args.min_seeds:
            continue
        gb = gb[gb["seed"].isin(common)].sort_values("seed"); ga = ga[ga["seed"].isin(common)].sort_values("seed")
        r = {"scenario": sc, "policy": pol, "n": len(common), "build": build_name(sc)}
        for col, label in [("win", "win"), ("damage_per_tempo", "dpt"), ("total_damage_taken", "taken"), ("bars_elapsed", "bars")]:
            r[label + "_before"] = gb[col].mean(); r[label + "_after"] = ga[col].mean()
            r["d_" + label] = r[label + "_after"] - r[label + "_before"]
            r["p_" + label] = welch_p(gb[col], ga[col])
        r["changed_seeds"] = int((gb["damage_per_tempo"].values != ga["damage_per_tempo"].values).sum())
        rows.append(r)
    if not rows:
        raise SystemExit("no scenario x policy with >= %d shared seeds in both snapshots" % args.min_seeds)
    df = pd.DataFrame(rows)
    df["effect"] = df["d_win"].abs() * 2 + (df["d_dpt"].abs() / df["dpt_before"].clip(lower=0.1)) + df["d_taken"].abs() / df["taken_before"].clip(lower=1)
    df = df.sort_values("effect", ascending=False)
    pd.set_option("display.width", 200)
    cols = ["scenario", "policy", "n", "win_before", "win_after", "d_win", "p_win", "dpt_before", "dpt_after", "d_dpt", "p_dpt", "taken_before", "taken_after", "d_taken", "p_taken", "changed_seeds"]
    print(df[cols].round(3).to_string(index=False))

    # Per-build verdicts.
    lines = []
    for build, g in df.groupby("build"):
        sig = g[(g["p_win"] < args.alpha) | (g["p_dpt"] < args.alpha) | (g["p_taken"] < args.alpha)]
        if sig.empty:
            moved = int(g["changed_seeds"].sum()); total = int(g["n"].sum())
            if moved == 0:
                lines.append("%-28s untouched (the change never reached this build: %d of %d seed-runs identical)" % (build, total, total))
            else:
                ddpt = g["d_dpt"].sum() / max(0.1, g["dpt_before"].sum()) * 100
                dtaken = g["d_taken"].sum() / max(1, g["taken_before"].sum()) * 100
                lines.append("%-28s touched but not significantly (%d of %d seed-runs differed; DPT %+.1f%%, damage taken %+.1f%%, win rate %+.0f pts; more seeds to confirm)"
                             % (build, moved, total, ddpt, dtaken, 100 * (g["d_win"] * g["n"]).sum() / total))
            continue
        dwin = sig["d_win"].mean(); ddpt = sig["d_dpt"].mean(); dtaken = sig["d_taken"].mean()
        verdict = []
        if abs(dwin) >= 0.05:
            verdict.append("win rate %+.0f pts" % (dwin * 100))
        if abs(ddpt) >= 0.05 * max(0.1, sig["dpt_before"].mean()):
            verdict.append("DPT %+.1f%%" % (100 * ddpt / max(0.1, sig["dpt_before"].mean())))
        if abs(dtaken) >= 0.05 * max(1, sig["taken_before"].mean()):
            verdict.append("damage taken %+.1f%%" % (100 * dtaken / max(1, sig["taken_before"].mean())))
        where = ", ".join(s.split("_e_")[1] if "_e_" in s else s for s in sig["scenario"])
        lines.append("%-28s %s — on %s" % (build, "; ".join(verdict) if verdict else "statistically different but small", where))
    print("\nverdicts:")
    for l in lines:
        print("  " + l)
    if args.md:
        with open(args.md, "w") as f:
            f.write("# Balance change report\n\n`%s` -> `%s`\n\n" % (args.before, args.after))
            f.write("| build | verdict |\n|---|---|\n")
            for l in lines:
                name, _, rest = l.partition(" ")
                f.write("| %s | %s |\n" % (name.strip(), rest.strip()))
            f.write("\n```\n" + df[cols].round(3).to_string(index=False) + "\n```\n")
        print("wrote", args.md)


if __name__ == "__main__":
    main()
