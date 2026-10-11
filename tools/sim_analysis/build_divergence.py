#!/usr/bin/env python3
"""3d — Build divergence: do stat allocations produce different outcomes?

Reads the build_divergence sweep (name=e_<T>__b_<build>) and writes
sim_out/charts/build_divergence.csv plus two heatmaps (build × enemy): win
rate and damage per tempo. Rows that look the same mean stats don't matter.
Usage: python3 tools/sim_analysis/build_divergence.py
"""
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import simlib


def heatmap(table, title, name, fmt):
    cmap = LinearSegmentedColormap.from_list("seq", simlib.SEQUENTIAL)
    fig, ax = plt.subplots(figsize=(1.2 * table.shape[1] + 3, 0.5 * table.shape[0] + 2))
    im = ax.imshow(table.values, cmap=cmap, aspect="auto")
    ax.set_xticks(range(table.shape[1])); ax.set_xticklabels(table.columns, rotation=30, ha="right")
    ax.set_yticks(range(table.shape[0])); ax.set_yticklabels(table.index)
    for i in range(table.shape[0]):
        for j in range(table.shape[1]):
            v = table.values[i, j]
            if not np.isnan(v):
                ax.text(j, i, fmt % v, ha="center", va="center", fontsize=8,
                        color=simlib.SURFACE if v > np.nanmean(table.values) else simlib.TEXT)
    ax.grid(False); ax.set_title(title)
    fig.colorbar(im, ax=ax, shrink=0.8)
    simlib.finish(fig, name)


def main():
    simlib.style()
    df = simlib.load_summaries()
    df = df[(df["base"] == "baseline") & df["b"].notna() & df["e"].notna()]
    if df.empty:
        raise SystemExit("no build_divergence results under sim_out/")
    g = simlib.per_group(df, ["b", "e"])
    g.to_csv(simlib.CHARTS + "/build_divergence.csv", index=False)
    win = g.pivot(index="b", columns="e", values="win_rate")
    dpt = g.pivot(index="b", columns="e", values="dpt")
    print("win rate:\n", win.round(2).to_string()); print("\ndamage per tempo:\n", dpt.round(2).to_string())
    print("\nspread across builds (max − min per enemy): win", (win.max() - win.min()).round(2).to_dict(), "dpt", (dpt.max() - dpt.min()).round(2).to_dict())
    heatmap(win, "Build divergence — win rate (build × enemy)", "build_divergence_win.png", "%.2f")
    heatmap(dpt, "Build divergence — damage per tempo (build × enemy)", "build_divergence_dpt.png", "%.2f")


if __name__ == "__main__":
    main()
