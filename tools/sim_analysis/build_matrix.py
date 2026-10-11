#!/usr/bin/env python3
"""Stored-build analysis for one character: designed builds vs enemies, and
the mix-and-match matrices (item set x deck, allocation x sphere path,
passive sets), optionally at one level.

Reads sim_out/<char>_<build>_e_<ENEMY>[__L_<level>][__k_<component>...]/lookahead/summary.csv
and writes sim_out/charts/<char>_*.png and .csv.
Usage: python3 tools/sim_analysis/build_matrix.py --character ryan [--level 18]
"""
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import simlib


def parse(name, char):
    """ryan_card_shark_e_WYVERN__L_50__i_apothecary__d_potions -> dict."""
    head, *tail = name.split("__")
    out = {"L": "18"}
    if "_e_" in head:
        build, enemy = head.split("_e_", 1)
        out["build"] = build[len(char) + 1:]
        out["e"] = enemy
    else:
        out["build"] = head[len(char) + 1:]
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
    ap = argparse.ArgumentParser()
    ap.add_argument("--character", default="ryan")
    ap.add_argument("--level", type=int, default=18)
    ap.add_argument("--root", default=simlib.SIM_OUT, help="snapshot to read (default sim_out; e.g. sim_out/ryan50)")
    args = ap.parse_args()
    char = args.character.lower()
    simlib.style()
    df = simlib.load_summaries(args.root)
    df = df[df["scenario"].str.startswith(char + "_") & (df["policy"] == "lookahead")].copy()
    if df.empty:
        raise SystemExit("no %s_* results under sim_out/ (run tests/sim/sweeps/%s_*.txt first)" % (char, char))
    parts = df["scenario"].apply(lambda n: parse(n, char))
    for k in ["build", "e", "i", "d", "a", "s", "p", "f", "w", "r", "t", "L"]:
        df[k] = parts.apply(lambda d: d.get(k))
    df = df[df["L"].astype(int) == args.level]
    if df.empty:
        raise SystemExit("no %s results at level %d" % (char, args.level))
    tag = char if args.level == 18 else "%s_L%d" % (char, args.level)
    df["clean"] = df["warnings"].fillna("").astype(str).str.len().eq(0).astype(float)

    # Designed builds x enemies.
    des = df[df["i"].isna() & df["a"].isna() & df["p"].isna() & df["f"].isna() & df["w"].isna() & df["r"].isna() & df["t"].isna()]
    if not des.empty:
        g = simlib.per_group(des, ["build", "e"])
        g["clean"] = des.groupby(["build", "e"])["clean"].mean().values
        g.to_csv(simlib.CHARTS + "/%s_designed.csv" % tag, index=False)
        win = g.pivot(index="build", columns="e", values="win_rate")
        dpt = g.pivot(index="build", columns="e", values="dpt")
        cl = g.pivot(index="build", columns="e", values="clean")
        print("designed builds — win rate:\n", win.round(2).to_string())
        print("\ndesigned builds — damage per tempo:\n", dpt.round(2).to_string())
        heatmap(win, "%s designed builds — win rate (level %d)" % (char, args.level), "%s_designed_win.png" % tag, clean=cl)
        heatmap(dpt, "%s designed builds — damage per tempo (level %d)" % (char, args.level), "%s_designed_dpt.png" % tag, clean=cl)

    # Item set x deck (enemy-averaged).
    m = df[df["i"].notna() & df["d"].notna()]
    if not m.empty:
        g = m.groupby(["i", "d"]).agg(win_rate=("win", "mean"), dpt=("damage_per_tempo", "mean"), taken=("total_damage_taken", "mean"), clean=("clean", "mean")).reset_index()
        g.to_csv(simlib.CHARTS + "/%s_items_x_decks.csv" % tag, index=False)
        for col, title in [("win_rate", "win rate"), ("dpt", "damage per tempo")]:
            piv = g.pivot(index="i", columns="d", values=col)
            print("\nitem set x deck — %s:\n" % title, piv.round(2).to_string())
            heatmap(piv, "%s item set (rows) x deck (columns) — %s, enemy-averaged" % (char, title), "%s_items_x_decks_%s.png" % (tag, col),
                    clean=g.pivot(index="i", columns="d", values="clean"))
        main_effects(g, "i", "d", "item set", "deck")

    # Allocation x sphere path, per build (enemy-averaged) and pooled.
    m = df[df["a"].notna() & df["s"].notna()]
    if not m.empty:
        g = m.groupby(["a", "s"]).agg(win_rate=("win", "mean"), dpt=("damage_per_tempo", "mean"), clean=("clean", "mean")).reset_index()
        g.to_csv(simlib.CHARTS + "/%s_alloc_x_sphere.csv" % tag, index=False)
        piv = g.pivot(index="a", columns="s", values="dpt")
        print("\nallocation x sphere — damage per tempo (all builds, all enemies):\n", piv.round(2).to_string())
        heatmap(piv, "%s allocation (rows) x sphere path (columns) — damage per tempo" % char, "%s_alloc_x_sphere_dpt.png" % tag,
                clean=g.pivot(index="a", columns="s", values="clean"))
        heatmap(g.pivot(index="a", columns="s", values="win_rate"), "%s allocation x sphere path — win rate" % char, "%s_alloc_x_sphere_win.png" % tag)
        per_build = m.groupby(["build", "a"]).agg(dpt=("damage_per_tempo", "mean")).reset_index().pivot(index="build", columns="a", values="dpt")
        print("\nallocation per build — damage per tempo:\n", per_build.round(2).to_string())
        heatmap(per_build, "%s build (rows) x allocation (columns) — damage per tempo" % char, "%s_build_x_alloc_dpt.png" % tag)

    # Passive sets per build.
    m = df[df["p"].notna()]
    if not m.empty:
        g = m.groupby(["build", "p"]).agg(win_rate=("win", "mean"), dpt=("damage_per_tempo", "mean"), taken=("total_damage_taken", "mean")).reset_index()
        g.to_csv(simlib.CHARTS + "/%s_passives.csv" % tag, index=False)
        piv = g.pivot(index="build", columns="p", values="dpt")
        print("\nbuild x passive set — damage per tempo:\n", piv.round(2).to_string())
        heatmap(piv, "%s build (rows) x passive set (columns) — damage per tempo" % char, "%s_passives_dpt.png" % tag)

    # Passive focus: one passive at rank 15, the rest spread. Uplift is against
    # the designed build on the same enemy when that run is in the snapshot.
    m = df[df["f"].notna()]
    if not m.empty:
        # How often the maxed passive itself fired per fight (passive_triggers column, newer runs only).
        def fired(row):
            txt = str(row.get("passive_triggers", "")) if "passive_triggers" in row else ""
            for part in txt.split("|"):
                k, _, v = part.partition(":")
                if k.replace("'", "") == row["f"].replace("'", "") and v.strip().lstrip("-").isdigit():
                    return float(v)
            return float("nan")
        m = m.copy(); m["fired"] = m.apply(fired, axis=1) if "passive_triggers" in m.columns else float("nan")
        g = m.groupby(["build", "e", "f"]).agg(win_rate=("win", "mean"), dpt=("damage_per_tempo", "mean"), dpt_median=("damage_per_tempo", "median"), taken=("total_damage_taken", "mean"), fired=("fired", "mean")).reset_index()
        base = df[df["f"].isna() & df["p"].isna() & df["i"].isna() & df["d"].isna() & df["a"].isna() & df["s"].isna() & df["w"].isna() & df["r"].isna() & df["t"].isna()]
        if not base.empty:
            b = base.groupby(["build", "e"]).agg(dpt0=("damage_per_tempo", "mean"), dpt0_median=("damage_per_tempo", "median"), win0=("win", "mean")).reset_index()
            g = g.merge(b, on=["build", "e"], how="left")
            g["d_dpt"] = g["dpt"] - g["dpt0"]; g["d_dpt_median"] = g["dpt_median"] - g["dpt0_median"]; g["d_win"] = g["win_rate"] - g["win0"]
        g.to_csv(simlib.CHARTS + "/%s_passive_focus.csv" % tag, index=False)
        per = g.groupby(["build", "f"]).agg(dpt=("dpt", "mean"), dpt_median=("dpt_median", "mean"), win_rate=("win_rate", "mean")).reset_index()
        piv = per.pivot(index="build", columns="f", values="dpt")
        print("\nbuild x maxed passive — damage per tempo (mean; one-shot seeds inflate it, see the median table):\n", piv.round(2).to_string())
        print("\nbuild x maxed passive — damage per tempo (median per enemy, averaged):\n", per.pivot(index="build", columns="f", values="dpt_median").round(2).to_string())
        heatmap(piv, "%s build (rows) x maxed passive (columns) — damage per tempo" % char, "%s_passive_focus_dpt.png" % tag)
        wpiv = per.pivot(index="build", columns="f", values="win_rate")
        print("\nbuild x maxed passive — win rate:\n", wpiv.round(2).to_string())
        heatmap(wpiv, "%s build (rows) x maxed passive (columns) — win rate" % char, "%s_passive_focus_win.png" % tag)
        if "d_dpt" in g:
            up = g.groupby("f").agg(d_dpt=("d_dpt", "mean"), d_dpt_median=("d_dpt_median", "mean"), d_win=("d_win", "mean"), fired_per_fight=("fired", "mean")).sort_values("d_dpt_median", ascending=False)
            print("\nmaxed passive — mean uplift over the designed build (DPT, win rate) and how often it fired per fight (NaN = runs predate the trigger column):\n", up.round(3).to_string())
        fp = g.pivot_table(index="build", columns="f", values="fired", aggfunc="mean")
        if not fp.empty and fp.notna().any().any():
            print("\nbuild x maxed passive — times it fired per fight:\n", fp.round(1).to_string())
            heatmap(fp, "%s build (rows) x maxed passive (columns) — fired per fight" % char, "%s_passive_focus_fired.png" % tag, fmt="%.1f")

    # Single-card swap: uplift over the designed build, paired by seed (the
    # swap runs fewer seeds than the designed run, so compare on shared seeds).
    des_runs = df[df["i"].isna() & df["a"].isna() & df["p"].isna() & df["f"].isna() & df["w"].isna() & df["r"].isna() & df["t"].isna()]
    m = df[df["w"].notna() & (df["clean"] == 1.0)]
    if not m.empty and not des_runs.empty:
        rows = []
        bk = des_runs.set_index(["build", "e", "seed"])
        for (build, e, w), g in m.groupby(["build", "e", "w"]):
            pairs = [(r["damage_per_tempo"], r["win"], r["total_damage_taken"], bk.loc[(build, e, s)]) for s, r in zip(g["seed"], g.to_dict("records")) if (build, e, s) in bk.index]
            if not pairs:
                continue
            dd = [p[0] - p[3]["damage_per_tempo"] for p in pairs]; dw = [p[1] - p[3]["win"] for p in pairs]; dt = [p[2] - p[3]["total_damage_taken"] for p in pairs]
            rows.append(dict(build=build, e=e, card=w, n=len(pairs), d_dpt=np.mean(dd), d_dpt_median=np.median(dd), d_win=np.mean(dw), d_taken=np.mean(dt)))
        sw = pd.DataFrame(rows)
        per = sw.groupby(["build", "card"]).agg(n=("n", "sum"), d_dpt=("d_dpt", "mean"), d_dpt_median=("d_dpt_median", "mean"), d_win=("d_win", "mean"), d_taken=("d_taken", "mean")).reset_index()
        per.to_csv(simlib.CHARTS + "/%s_card_swap.csv" % tag, index=False)
        print("\nsingle-card swap: top and bottom cards per build (uplift over the designed deck, paired seeds):")
        for build, g in per.groupby("build"):
            g = g.sort_values("d_dpt_median", ascending=False)
            top = ", ".join("%s %+.1f" % (r.card, r.d_dpt_median) for r in g.head(8).itertuples())
            bot = ", ".join("%s %+.1f" % (r.card, r.d_dpt_median) for r in g.tail(4).itertuples())
            wins = g.sort_values("d_win", ascending=False).head(4)
            print("  %-18s best DPT: %s\n  %-18s worst DPT: %s\n  %-18s best win rate: %s" % (build, top, "", bot, "", ", ".join("%s %+.0f pts" % (r.card, 100 * r.d_win) for r in wins.itertuples())))
        uni = per.groupby("card").agg(builds=("build", "nunique"), d_dpt_median=("d_dpt_median", "mean"), d_win=("d_win", "mean"), positive_on=("d_dpt_median", lambda x: int((x > 0).sum()))).reset_index()
        uni = uni[uni["builds"] >= max(2, uni["builds"].max() - 1)].sort_values("d_dpt_median", ascending=False)
        uni.to_csv(simlib.CHARTS + "/%s_card_swap_universal.csv" % tag, index=False)
        print("\ncards that help every build (mean uplift across builds, and on how many builds it is positive):\n", uni.head(15).round(2).to_string(index=False))
        print("\ncards that hurt every build:\n", uni.tail(8).round(2).to_string(index=False))

    # Recipe decks per build.
    m = df[df["r"].notna()]
    if not m.empty:
        g = m.groupby(["build", "r"]).agg(win_rate=("win", "mean"), dpt=("damage_per_tempo", "mean"), dpt_median=("damage_per_tempo", "median"), taken=("total_damage_taken", "mean")).reset_index()
        g.to_csv(simlib.CHARTS + "/%s_recipes.csv" % tag, index=False)
        if not des.empty:
            b = des.groupby("build").agg(win0=("win", "mean"), dpt0_median=("damage_per_tempo", "median")).reset_index()
            g = g.merge(b, on="build", how="left")
            g["d_win"] = g["win_rate"] - g["win0"]; g["d_dpt_median"] = g["dpt_median"] - g["dpt0_median"]
        print("\nbuild x recipe deck — win rate:\n", g.pivot(index="build", columns="r", values="win_rate").round(2).to_string())
        print("\nbuild x recipe deck — median DPT:\n", g.pivot(index="build", columns="r", values="dpt_median").round(2).to_string())
        if "d_win" in g:
            print("\nrecipe vs the build's own deck (win rate, median DPT):\n", g.groupby("r").agg(d_win=("d_win", "mean"), d_dpt_median=("d_dpt_median", "mean")).round(3).sort_values("d_win", ascending=False).to_string())
        heatmap(g.pivot(index="build", columns="r", values="win_rate"), "%s build (rows) x recipe deck (columns) — win rate" % char, "%s_recipes_win.png" % tag)

    # Tactic overlays per build, against the build's own designed run.
    m = df[df["t"].notna()]
    if not m.empty:
        g = m.groupby(["build", "e", "t"]).agg(win_rate=("win", "mean"), dpt_median=("damage_per_tempo", "median"), taken=("total_damage_taken", "mean")).reset_index()
        if not des.empty:
            b = des.groupby(["build", "e"]).agg(win0=("win", "mean"), dpt0_median=("damage_per_tempo", "median")).reset_index()
            g = g.merge(b, on=["build", "e"], how="left")
            g["d_win"] = g["win_rate"] - g["win0"]; g["d_dpt_median"] = g["dpt_median"] - g["dpt0_median"]
        g.to_csv(simlib.CHARTS + "/%s_tactics.csv" % tag, index=False)
        per = g.groupby(["build", "t"]).agg(win_rate=("win_rate", "mean"), dpt_median=("dpt_median", "mean"), d_win=("d_win", "mean") if "d_win" in g else ("win_rate", "mean"), d_dpt_median=("d_dpt_median", "mean") if "d_dpt_median" in g else ("dpt_median", "mean")).reset_index()
        print("\nbuild x tactic — win rate:\n", per.pivot(index="build", columns="t", values="win_rate").round(2).to_string())
        if "d_win" in g:
            print("\nbuild x tactic — win rate change vs the build's own loadout:\n", per.pivot(index="build", columns="t", values="d_win").round(2).to_string())
            print("\nbuild x tactic — median DPT change:\n", per.pivot(index="build", columns="t", values="d_dpt_median").round(2).to_string())
        heatmap(per.pivot(index="build", columns="t", values="win_rate"), "%s build (rows) x tactic (columns) — win rate" % char, "%s_tactics_win.png" % tag)


def main_effects(g, a, b, la, lb):
    """How much of the spread each factor explains: the range of row means vs column means."""
    ra = g.groupby(a)["dpt"].mean()
    rb = g.groupby(b)["dpt"].mean()
    print("\n%s main effect on DPT (max − min of means): %.2f   %s: %.2f" % (la, ra.max() - ra.min(), lb, rb.max() - rb.min()))
    print("best %s: %s (%.2f), best %s: %s (%.2f)" % (la, ra.idxmax(), ra.max(), lb, rb.idxmax(), rb.max()))


if __name__ == "__main__":
    main()
