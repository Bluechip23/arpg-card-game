#!/usr/bin/env python3
"""Ryan build analysis: designed builds vs enemies, and the mix-and-match
matrices (item set x deck, allocation x sphere path, passive sets).

Reads sim_out/ryan_<build>_e_<ENEMY>[__k_<component>...]/lookahead/summary.csv
and writes sim_out/charts/ryan_*.png and .csv.
Usage: python3 tools/sim_analysis/ryan_builds.py
"""
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import simlib


def parse(name):
    """ryan_card_shark_e_WYVERN__i_apothecary__d_potions -> dict."""
    head, *tail = name.split("__")
    out = {}
    if "_e_" in head:
        build, enemy = head.split("_e_", 1)
        out["build"] = build[len("ryan_"):]
        out["e"] = enemy
    else:
        out["build"] = head[len("ryan_"):]
    for t in tail:
        k, _, v = t.partition("_")
        out[k] = v
    return out


def heatmap(table, title, name, fmt="%.2f", clean=None):
    cmap = LinearSegmentedColormap.from_list("seq", simlib.SEQUENTIAL)
    fig, ax = plt.subplots(figsize=(1.3 * table.shape[1] + 3.5, 0.5 * table.shape[0] + 2))
    im = ax.imshow(table.values.astype(float), cmap=cmap, aspect="auto")
    ax.set_xticks(range(table.shape[1])); ax.set_xticklabels(table.columns, rotation=30, ha="right")
    ax.set_yticks(range(table.shape[0])); ax.set_yticklabels(table.index)
    mean = np.nanmean(table.values.astype(float))
    for i in range(table.shape[0]):
        for j in range(table.shape[1]):
            v = table.values[i, j]
            if not np.isnan(v):
                txt = fmt % v
                if clean is not None and clean.values[i, j] < 1:
                    txt += "*"
                ax.text(j, i, txt, ha="center", va="center", fontsize=8, color=simlib.SURFACE if v > mean else simlib.TEXT)
    ax.grid(False); ax.set_title(title + ("   (* = a build warning: something was refused)" if clean is not None else ""))
    fig.colorbar(im, ax=ax, shrink=0.8)
    simlib.finish(fig, name)


def main():
    simlib.style()
    df = simlib.load_summaries()
    df = df[df["scenario"].str.startswith("ryan_") & (df["policy"] == "lookahead")].copy()
    if df.empty:
        raise SystemExit("no ryan_* results under sim_out/ (run tests/sim/sweeps/ryan_*.txt first)")
    parts = df["scenario"].apply(parse)
    for k in ["build", "e", "i", "d", "a", "s", "p"]:
        df[k] = parts.apply(lambda d: d.get(k))
    df["clean"] = df["warnings"].fillna("").astype(str).str.len().eq(0).astype(float)

    # Designed builds x enemies.
    des = df[df["i"].isna() & df["a"].isna() & df["p"].isna()]
    if not des.empty:
        g = simlib.per_group(des, ["build", "e"])
        g["clean"] = des.groupby(["build", "e"])["clean"].mean().values
        g.to_csv(simlib.CHARTS + "/ryan_designed.csv", index=False)
        win = g.pivot(index="build", columns="e", values="win_rate")
        dpt = g.pivot(index="build", columns="e", values="dpt")
        cl = g.pivot(index="build", columns="e", values="clean")
        print("designed builds — win rate:\n", win.round(2).to_string())
        print("\ndesigned builds — damage per tempo:\n", dpt.round(2).to_string())
        heatmap(win, "Ryan designed builds — win rate", "ryan_designed_win.png", clean=cl)
        heatmap(dpt, "Ryan designed builds — damage per tempo", "ryan_designed_dpt.png", clean=cl)

    # Item set x deck (enemy-averaged).
    m = df[df["i"].notna() & df["d"].notna()]
    if not m.empty:
        g = m.groupby(["i", "d"]).agg(win_rate=("win", "mean"), dpt=("damage_per_tempo", "mean"), taken=("total_damage_taken", "mean"), clean=("clean", "mean")).reset_index()
        g.to_csv(simlib.CHARTS + "/ryan_items_x_decks.csv", index=False)
        for col, title in [("win_rate", "win rate"), ("dpt", "damage per tempo")]:
            piv = g.pivot(index="i", columns="d", values=col)
            print("\nitem set x deck — %s:\n" % title, piv.round(2).to_string())
            heatmap(piv, "Ryan item set (rows) x deck (columns) — %s, enemy-averaged" % title, "ryan_items_x_decks_%s.png" % col,
                    clean=g.pivot(index="i", columns="d", values="clean"))
        main_effects(g, "i", "d", "item set", "deck")

    # Allocation x sphere path, per build (enemy-averaged) and pooled.
    m = df[df["a"].notna() & df["s"].notna()]
    if not m.empty:
        g = m.groupby(["a", "s"]).agg(win_rate=("win", "mean"), dpt=("damage_per_tempo", "mean"), clean=("clean", "mean")).reset_index()
        g.to_csv(simlib.CHARTS + "/ryan_alloc_x_sphere.csv", index=False)
        piv = g.pivot(index="a", columns="s", values="dpt")
        print("\nallocation x sphere — damage per tempo (all builds, all enemies):\n", piv.round(2).to_string())
        heatmap(piv, "Ryan allocation (rows) x sphere path (columns) — damage per tempo", "ryan_alloc_x_sphere_dpt.png",
                clean=g.pivot(index="a", columns="s", values="clean"))
        heatmap(g.pivot(index="a", columns="s", values="win_rate"), "Ryan allocation x sphere path — win rate", "ryan_alloc_x_sphere_win.png")
        per_build = m.groupby(["build", "a"]).agg(dpt=("damage_per_tempo", "mean")).reset_index().pivot(index="build", columns="a", values="dpt")
        print("\nallocation per build — damage per tempo:\n", per_build.round(2).to_string())
        heatmap(per_build, "Ryan build (rows) x allocation (columns) — damage per tempo", "ryan_build_x_alloc_dpt.png")

    # Passive sets per build.
    m = df[df["p"].notna()]
    if not m.empty:
        g = m.groupby(["build", "p"]).agg(win_rate=("win", "mean"), dpt=("damage_per_tempo", "mean"), taken=("total_damage_taken", "mean")).reset_index()
        g.to_csv(simlib.CHARTS + "/ryan_passives.csv", index=False)
        piv = g.pivot(index="build", columns="p", values="dpt")
        print("\nbuild x passive set — damage per tempo:\n", piv.round(2).to_string())
        heatmap(piv, "Ryan build (rows) x passive set (columns) — damage per tempo", "ryan_passives_dpt.png")


def main_effects(g, a, b, la, lb):
    """How much of the spread each factor explains: the range of row means vs column means."""
    ra = g.groupby(a)["dpt"].mean()
    rb = g.groupby(b)["dpt"].mean()
    print("\n%s main effect on DPT (max − min of means): %.2f   %s: %.2f" % (la, ra.max() - ra.min(), lb, rb.max() - rb.min()))
    print("best %s: %s (%.2f), best %s: %s (%.2f)" % (la, ra.idxmax(), ra.max(), lb, rb.idxmax(), rb.max()))


if __name__ == "__main__":
    main()
