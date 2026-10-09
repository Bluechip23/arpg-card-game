#!/usr/bin/env python3
"""3e — Progression check: does a level-N character with tier gear beat level N-1?

Reads the progression sweep (name=e_<T>__L_<level>) and writes
sim_out/charts/progression.csv and progression.png: win rate and bars to
kill against the roster per level. A flat line means progression isn't felt.
Usage: python3 tools/sim_analysis/progression.py
"""
import pandas as pd
import matplotlib.pyplot as plt
import simlib


def main():
    simlib.style()
    df = simlib.load_summaries()
    df = df[(df["base"] == "baseline") & df["L"].notna() & df["e"].notna()]
    if df.empty:
        raise SystemExit("no progression results under sim_out/")
    df["L"] = df["L"].astype(int)
    per_enemy = simlib.per_group(df, ["L", "e"])
    per_enemy.to_csv(simlib.CHARTS + "/progression.csv", index=False)
    by_level = per_enemy.groupby("L").agg(win_rate=("win_rate", "mean"), bars_to_kill=("bars_to_kill", "mean"),
                                          dpt=("dpt", "mean"), taken=("taken", "mean"), enemies=("e", "count"))
    print(by_level.round(3).to_string())

    fig, axes = plt.subplots(1, 2, figsize=(10, 4))
    axes[0].plot(by_level.index, by_level["win_rate"], marker="o", color=simlib.CATEGORICAL[0], linewidth=2, markersize=6)
    axes[0].set_ylim(0, 1.05); axes[0].set_xlabel("level"); axes[0].set_ylabel("win rate (mean over the roster)")
    axes[0].set_title("Win rate vs level")
    axes[1].plot(by_level.index, by_level["bars_to_kill"], marker="o", color=simlib.CATEGORICAL[1], linewidth=2, markersize=6)
    axes[1].set_xlabel("level"); axes[1].set_ylabel("bars to kill (wins, mean over the roster)")
    axes[1].set_title("Bars to kill vs level")
    for ax in axes:
        ax.set_xticks(sorted(by_level.index))
    simlib.finish(fig, "progression.png")

    # Per-enemy small multiples of win rate, so one steep enemy cannot hide a flat roster.
    piv = per_enemy.pivot(index="L", columns="e", values="win_rate")
    fig, ax = plt.subplots(figsize=(8, 4.5))
    for i, col in enumerate(sorted(piv.columns)):
        ax.plot(piv.index, piv[col], color=simlib.CATEGORICAL[0], alpha=0.25, linewidth=1)
    ax.plot(by_level.index, by_level["win_rate"], color=simlib.CATEGORICAL[0], linewidth=2.5, label="roster mean")
    ax.set_ylim(0, 1.05); ax.set_xlabel("level"); ax.set_ylabel("win rate"); ax.set_title("Win rate vs level, every enemy (thin) and the mean")
    ax.legend(); ax.set_xticks(sorted(piv.index))
    simlib.finish(fig, "progression_by_enemy.png")


if __name__ == "__main__":
    main()
