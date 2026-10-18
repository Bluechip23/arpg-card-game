#!/usr/bin/env python3
"""3a on a character's designed builds (Milestone 5): what the combo planner
adds beyond lookahead, per build and per enemy.

Reads sim_out/<char>_<build>_e_<ENEMY>/{greedy_dpt,lookahead,combo_planner}/summary.csv
(from tests/sim/sweeps/<char>_3a_m5_*.txt; the plain designed sweep's folders,
no __component tags) and writes
  sim_out/charts/<char>_planner_gap.csv       per build x enemy: win / DPT / taken per policy, the gaps
  sim_out/charts/<char>_planner_gap_win.png   heatmap: planner - lookahead win rate
  sim_out/charts/<char>_planner_gap_dpt.png   heatmap: planner - lookahead damage per tempo
  sim_out/charts/<char>_strategy_gap_builds.png  strategy gap (planner - greedy) per build, enemy-averaged
Usage: python3 tools/sim_analysis/planner_gap.py --character ryan [--noise 0.1]
"""
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import simlib


def heat(table, title, name, center_zero=True):
    cmap = LinearSegmentedColormap.from_list("div", [simlib.CATEGORICAL[7], "#f4f1ea", simlib.CATEGORICAL[0]]) if center_zero \
        else LinearSegmentedColormap.from_list("seq", simlib.SEQUENTIAL)
    vals = table.values.astype(float)
    lim = np.nanmax(np.abs(vals)) if center_zero else None
    fig, ax = plt.subplots(figsize=(0.32 * table.shape[1] + 3, 0.5 * table.shape[0] + 2))
    im = ax.imshow(vals, cmap=cmap, aspect="auto", vmin=-lim if center_zero else None, vmax=lim if center_zero else None)
    ax.set_xticks(range(table.shape[1])); ax.set_xticklabels(table.columns, rotation=70, ha="right", fontsize=6)
    ax.set_yticks(range(table.shape[0])); ax.set_yticklabels(table.index)
    for i in range(table.shape[0]):
        for j in range(table.shape[1]):
            v = vals[i, j]
            if np.isfinite(v) and abs(v) >= 0.005:
                ax.text(j, i, "%+.2f" % v if center_zero else "%.2f" % v, ha="center", va="center", fontsize=5, color=simlib.TEXT_1)
    fig.colorbar(im, ax=ax, shrink=0.6)
    ax.set_title(title)
    ax.grid(visible=False)
    simlib.finish(fig, name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--character", default="ryan")
    ap.add_argument("--noise", type=float, default=0.1, help="a win-rate change at or under this is noise (0.1 = 2 wins of 20)")
    args = ap.parse_args()
    char = args.character.lower()
    simlib.style()
    df = simlib.load_summaries()
    df = df[df["scenario"].str.startswith(char + "_") & df["scenario"].str.contains("_e_") & ~df["scenario"].str.contains("__")].copy()
    if df.empty:
        raise SystemExit("no %s designed-build results under sim_out/" % char)
    df["build"] = df["scenario"].apply(lambda n: n.split("_e_", 1)[0][len(char) + 1:])
    df["e"] = df["scenario"].apply(lambda n: n.split("_e_", 1)[1])
    pols = [p for p in ["greedy_dpt", "lookahead", "combo_planner"] if p in set(df["policy"])]
    g = simlib.per_group(df, ["build", "e", "policy"])
    wide = g.pivot(index=["build", "e"], columns="policy")
    out = pd.DataFrame(index=wide.index)
    for p in pols:
        out[p + "_win"] = wide["win_rate"][p]
        out[p + "_dpt"] = wide["dpt"][p]
        out[p + "_taken"] = wide["taken"][p]
        out[p + "_n"] = wide["n"][p]
    if "lookahead" in pols and "combo_planner" in pols:
        out["planner_vs_lookahead_win"] = out["combo_planner_win"] - out["lookahead_win"]
        out["planner_vs_lookahead_dpt"] = out["combo_planner_dpt"] - out["lookahead_dpt"]
        out["planner_vs_lookahead_taken"] = out["lookahead_taken"] - out["combo_planner_taken"]
    if "greedy_dpt" in pols:
        for p in pols:
            if p != "greedy_dpt":
                out[p + "_strategy_gap"] = out[p + "_win"] - out["greedy_dpt_win"]
    out = out.reset_index()
    out.to_csv(simlib.CHARTS + "/%s_planner_gap.csv" % char, index=False)

    print("cells (build x enemy): %d; policies: %s" % (len(out), ", ".join(pols)))
    for p in pols:
        print("  %-14s mean win %.3f  mean DPT %.2f  mean taken %.1f" % (p, out[p + "_win"].mean(), out[p + "_dpt"].mean(), out[p + "_taken"].mean()))
    if "planner_vs_lookahead_win" in out:
        d = out["planner_vs_lookahead_win"]
        print("\nplanner vs lookahead, win rate: better on %d cells, worse on %d, within noise (<= %.2f) on %d"
              % (int((d > args.noise).sum()), int((d < -args.noise).sum()), args.noise, int((d.abs() <= args.noise).sum())))
        moved = out[d.abs() > args.noise].sort_values("planner_vs_lookahead_win", ascending=False)
        if not moved.empty:
            print(moved[["build", "e", "greedy_dpt_win", "lookahead_win", "combo_planner_win", "planner_vs_lookahead_win",
                         "lookahead_dpt", "combo_planner_dpt", "lookahead_taken", "combo_planner_taken"]].round(2).to_string(index=False))
        per_build = out.groupby("build").agg(lookahead_win=("lookahead_win", "mean"), planner_win=("combo_planner_win", "mean"),
                                             lookahead_dpt=("lookahead_dpt", "mean"), planner_dpt=("combo_planner_dpt", "mean"),
                                             lookahead_taken=("lookahead_taken", "mean"), planner_taken=("combo_planner_taken", "mean"))
        if "greedy_dpt" in pols:
            per_build["greedy_win"] = out.groupby("build")["greedy_dpt_win"].mean()
        print("\nper build (enemy-averaged):\n", per_build.round(3).to_string())
        per_enemy = out.groupby("e").agg(greedy_win=("greedy_dpt_win", "mean") if "greedy_dpt" in pols else ("lookahead_win", "mean"),
                                         lookahead_win=("lookahead_win", "mean"), planner_win=("combo_planner_win", "mean"))
        per_enemy["planner_vs_lookahead"] = per_enemy["planner_win"] - per_enemy["lookahead_win"]
        print("\nper enemy (build-averaged), sorted by what the planner adds:\n",
              per_enemy.sort_values("planner_vs_lookahead", ascending=False).round(3).to_string())
        heat(out.pivot(index="build", columns="e", values="planner_vs_lookahead_win"),
             "%s designed builds — combo planner minus lookahead, win rate" % char, "%s_planner_gap_win.png" % char)
        heat(out.pivot(index="build", columns="e", values="planner_vs_lookahead_dpt"),
             "%s designed builds — combo planner minus lookahead, damage per tempo" % char, "%s_planner_gap_dpt.png" % char)
    if "greedy_dpt" in pols and "combo_planner" in pols:
        sg = out.groupby("build")[["lookahead_strategy_gap", "combo_planner_strategy_gap"]].mean()
        fig, ax = plt.subplots(figsize=(7, 3.6))
        x = np.arange(len(sg))
        ax.bar(x - 0.18, sg["lookahead_strategy_gap"], width=0.36, color=simlib.CATEGORICAL[2], label="lookahead − greedy")
        ax.bar(x + 0.18, sg["combo_planner_strategy_gap"], width=0.36, color=simlib.CATEGORICAL[0], label="combo planner − greedy")
        ax.axhline(0, color=simlib.TEXT_2, linewidth=0.8)
        ax.set_xticks(x); ax.set_xticklabels(sg.index, rotation=20, ha="right")
        ax.set_ylabel("strategy gap (win rate over the auto-attacker)")
        ax.set_title("%s designed builds — strategy gap, enemy-averaged" % char)
        ax.legend(); ax.grid(axis="x", visible=False)
        simlib.finish(fig, "%s_strategy_gap_builds.png" % char)


if __name__ == "__main__":
    main()
