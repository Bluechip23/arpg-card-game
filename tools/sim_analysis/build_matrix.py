#!/usr/bin/env python3
"""Stored-build analysis for one character: designed builds vs enemies, and
the mix-and-match matrices (item set x deck, allocation x sphere path,
passive sets), optionally at one level.

Reads sim_out/<char>_<build>_e_<ENEMY>[__L_<level>][__k_<component>...]/lookahead/summary.csv
and writes sim_out/charts/<char>_*.png and .csv.
Usage: python3 tools/sim_analysis/build_matrix.py --character ryan [--level 18]
"""
import argparse, os
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
    ap.add_argument("--update-ranking", action="store_true", help="copy the card-swap table to tests/sim/builds/rankings/ (the ranking deck recipes use; commit it)")
    args = ap.parse_args()
    char = args.character.lower()
    simlib.style()
    df = simlib.load_summaries(args.root)
    df = df[df["scenario"].str.startswith(char + "_") & (df["policy"] == "lookahead")].copy()
    if df.empty:
        raise SystemExit("no %s_* results under sim_out/ (run tests/sim/sweeps/%s_*.txt first)" % (char, char))
    parts = df["scenario"].apply(lambda n: parse(n, char))
    for k in ["build", "e", "i", "d", "a", "s", "p", "f", "w", "r", "t", "x", "h", "g", "L"]:
        df[k] = parts.apply(lambda d: d.get(k))
    df = df[df["L"].astype(int) == args.level]
    if df.empty:
        raise SystemExit("no %s results at level %d" % (char, args.level))
    tag = char if args.level == 18 else "%s_L%d" % (char, args.level)
    df["clean"] = df["warnings"].fillna("").astype(str).str.len().eq(0).astype(float)

    # Designed builds x enemies.
    des = df[df["i"].isna() & df["a"].isna() & df["p"].isna() & df["f"].isna() & df["w"].isna() & df["r"].isna() & df["t"].isna() & df["x"].isna() & df["h"].isna() & df["g"].isna()]
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
        base = df[df["f"].isna() & df["p"].isna() & df["i"].isna() & df["d"].isna() & df["a"].isna() & df["s"].isna() & df["w"].isna() & df["r"].isna() & df["t"].isna() & df["x"].isna() & df["h"].isna() & df["g"].isna()]
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

    # Single-card (w) and single-item (x) swaps: uplift over the designed
    # build, paired by seed (the swaps run fewer seeds, so compare on shared
    # seeds). Runs with warnings (a refused equip or slot) are excluded and
    # listed, never silently dropped.
    des_runs = df[df["i"].isna() & df["a"].isna() & df["p"].isna() & df["f"].isna() & df["w"].isna() & df["r"].isna() & df["t"].isna() & df["x"].isna() & df["h"].isna() & df["g"].isna()]
    for col, what, fname in (("w", "card", "card_swap"), ("x", "item", "item_swap")):
        swap_table(df, des_runs, col, what, tag, fname)
    engrave_table(df, des_runs, tag)
    if args.update_ranking:
        src = simlib.CHARTS + "/%s_card_swap.csv" % tag
        if os.path.exists(src):
            dst_dir = os.path.join(simlib.ROOT, "tests", "sim", "builds", "rankings")
            os.makedirs(dst_dir, exist_ok=True)
            r = pd.read_csv(src).rename(columns={"card": "card"})
            r.to_csv(os.path.join(dst_dir, "%s_card_swap.csv" % tag), index=False)
            print("\nranking updated: tests/sim/builds/rankings/%s_card_swap.csv (%d rows) — commit it" % (tag, len(r)))
        else:
            print("\nno card-swap table for %s; ranking not updated" % tag)

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

    # Second weapon sets per build (alt:none = one set), against the designed
    # build (which carries its own set, if any). Runs with a refusal are
    # listed and left out.
    m = df[df["h"].notna()]
    bad = m[m["clean"] < 1.0]
    if not bad.empty:
        print("\nweapon sets not wearable (excluded): " + "; ".join(
            "%s+%s (%s)" % (b, h, str(w).split("|")[0][:70]) for (b, h), w in bad.groupby(["build", "h"])["warnings"].first().items()))
    m = m[m["clean"] == 1.0]
    if not m.empty:
        m = m.assign(swaps=m["weapon_swaps"].fillna("").astype(str).apply(lambda v: sum(int(x.split(":")[1]) for x in v.split("|") if ":" in x)) if "weapon_swaps" in m else 0)
        g = m.groupby(["build", "e", "h"]).agg(win_rate=("win", "mean"), dpt_median=("damage_per_tempo", "median"), taken=("total_damage_taken", "mean"), swaps=("swaps", "mean")).reset_index()
        if not des.empty:
            b = des.groupby(["build", "e"]).agg(win0=("win", "mean"), dpt0_median=("damage_per_tempo", "median")).reset_index()
            g = g.merge(b, on=["build", "e"], how="left")
            g["d_win"] = g["win_rate"] - g["win0"]; g["d_dpt_median"] = g["dpt_median"] - g["dpt0_median"]
        g.to_csv(simlib.CHARTS + "/%s_weapon_sets.csv" % tag, index=False)
        per = g.groupby(["build", "h"]).agg(win_rate=("win_rate", "mean"), swaps=("swaps", "mean")).reset_index()
        print("\nbuild x second weapon set — win rate:\n", per.pivot(index="build", columns="h", values="win_rate").round(2).to_string())
        print("\nbuild x second weapon set — swaps per fight:\n", per.pivot(index="build", columns="h", values="swaps").round(1).to_string())
        heatmap(per.pivot(index="build", columns="h", values="win_rate"), "%s build (rows) x second weapon set (columns) — win rate" % char, "%s_weapon_sets_win.png" % tag)

    # Tactic overlays per build, against the build's own designed run (runs
    # with a refused equip are listed and left out, as in the swap tables).
    m = df[df["t"].notna()]
    bad = m[m["clean"] < 1.0]
    if not bad.empty:
        print("\ntactics not wearable as packaged (excluded): " + "; ".join(
            "%s+%s (%s)" % (b, t, str(w).split("|")[0][:70]) for (b, t), w in bad.groupby(["build", "t"])["warnings"].first().items()))
    m = m[m["clean"] == 1.0]
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


def engrave_table(df, des_runs, tag):
    """The engraving sweep: each card engraved into each slotted item, paired
    by seed against the designed build. Per build and item: the best and
    worst cards and what stripping the item's engravings does; across
    everything: the cards that are worth a slot, and the slots worth filling."""
    m = df[df["g"].notna()]
    if m.empty or des_runs.empty:
        return
    swap_table(df, des_runs, "g", "engraving", tag, "engrave", universal=False)
    src = simlib.CHARTS + "/%s_engrave.csv" % tag
    if not os.path.exists(src):
        return
    per = pd.read_csv(src)
    sp = per["engraving"].astype(str).str.split("~", n=1, expand=True)
    per["item"], per["card"] = sp[0], sp[1]
    stripped = per[per["card"] == "none"]
    cards = per[per["card"] != "none"]
    if not stripped.empty:
        print("\nitem stripped of its engravings (uplift over the designed build; positive = the engravings were costing):")
        print(stripped[["build", "item", "d_dpt_median", "d_win", "d_taken"]].sort_values("d_dpt_median", ascending=False).round(2).to_string(index=False))
    if cards.empty:
        return
    for (build, item), g in cards.groupby(["build", "item"]):
        g = g.sort_values("d_dpt_median", ascending=False)
        print("  %-18s %-24s best: %s | worst: %s" % (build, item,
              ", ".join("%s %+.1f" % (r.card, r.d_dpt_median) for r in g.head(4).itertuples()),
              ", ".join("%s %+.1f" % (r.card, r.d_dpt_median) for r in g.tail(2).itertuples())))
    by_card = cards.groupby("card").agg(slots=("engraving", "count"), builds=("build", "nunique"), d_dpt_median=("d_dpt_median", "mean"),
                                        d_win=("d_win", "mean"), positive_in=("d_dpt_median", lambda x: int((x > 0).sum()))).reset_index()
    by_card = by_card.sort_values("d_dpt_median", ascending=False)
    by_card.to_csv(simlib.CHARTS + "/%s_engrave_by_card.csv" % tag, index=False)
    print("\nbest cards to engrave (mean uplift over every slot that takes them; positive_in = slots where it helps):\n", by_card.head(15).round(2).to_string(index=False))
    print("\nworst cards to engrave:\n", by_card.tail(8).round(2).to_string(index=False))


def swap_table(df, des_runs, col, what, tag, fname, universal=True):
    allm = df[df[col].notna()]
    if allm.empty or des_runs.empty:
        return
    dirty = allm[allm["clean"] < 1.0]
    if not dirty.empty:
        bad = dirty.groupby(["build", col]).size().reset_index()
        print("\n%s swap: %d %s(s) not measurable on some build (excluded, not scored):" % (what, bad[col].nunique(), what))
        for build, g in dirty.groupby("build"):
            why = {}
            for w, wt in zip(g[col], g["warnings"].astype(str)):
                kind = ("hand conflict" if "hand conflict" in wt else "over carry capacity" if "carry capacity" in wt
                        else "copy / mythic cap" if "copy cap" in wt or "mythic cap" in wt else "slot refused" if "slot" in wt else "other")
                why.setdefault(kind, set()).add(w)
            print("  %-18s " % build + "; ".join("%s: %s" % (k, ", ".join(sorted(v))) for k, v in sorted(why.items())))
        reasons = dirty["warnings"].dropna().astype(str).str.split("|").explode().str.replace(r"\d+", "#", regex=True).value_counts().head(6)
        print("  most common warnings:\n" + "\n".join("    %4d  %s" % (n, w[:110]) for w, n in reasons.items()))
    m = allm[allm["clean"] == 1.0]
    rows = []
    bk = des_runs.set_index(["build", "e", "seed"])
    for (build, e, w), g in m.groupby(["build", "e", col]):
        pairs = [(r["damage_per_tempo"], r["win"], r["total_damage_taken"], bk.loc[(build, e, s)]) for s, r in zip(g["seed"], g.to_dict("records")) if (build, e, s) in bk.index]
        if not pairs:
            continue
        dd = [p[0] - p[3]["damage_per_tempo"] for p in pairs]; dw = [p[1] - p[3]["win"] for p in pairs]; dt = [p[2] - p[3]["total_damage_taken"] for p in pairs]
        rows.append(dict(build=build, e=e, card=w, n=len(pairs), d_dpt=np.mean(dd), d_dpt_median=np.median(dd), d_win=np.mean(dw), d_taken=np.mean(dt)))
    if not rows:
        return
    sw = pd.DataFrame(rows)
    # Packs are reported on their own: only some cards may have run against
    # them, and averaging a card over "bear + pack" against others over the
    # bear alone would rank them on different fights.
    pack = sw[sw["e"].astype(str).str.startswith("PACK_")]
    sw = sw[~sw["e"].astype(str).str.startswith("PACK_")]
    if not pack.empty:
        pk = pack.groupby(["build", "card"]).agg(d_dpt_median=("d_dpt_median", "mean"), d_win=("d_win", "mean")).reset_index()
        pk.to_csv(simlib.CHARTS + "/%s_%s_packs.csv" % (tag, fname), index=False)
        print("\nsingle-%s swap against packs (%s), median DPT uplift:\n" % (what, ", ".join(sorted(pack["e"].unique()))),
              pk.pivot(index="card", columns="build", values="d_dpt_median").round(1).to_string())
    # One enemy set for every ranked entry: keep the enemies most entries share.
    sets = sw.groupby(["build", "card"])["e"].apply(lambda x: tuple(sorted(set(x))))
    common = sets.value_counts().idxmax() if len(sets) else ()
    if len(sets.unique()) > 1:
        print("\nnote: %s swaps ran against different enemy sets; ranking on %s only" % (what, ", ".join(common)))
        sw = sw[sw["e"].isin(common)]
    per = sw.groupby(["build", "card"]).agg(n=("n", "sum"), d_dpt=("d_dpt", "mean"), d_dpt_median=("d_dpt_median", "mean"), d_win=("d_win", "mean"), d_taken=("d_taken", "mean")).reset_index()
    per = per.rename(columns={"card": what})
    per.to_csv(simlib.CHARTS + "/%s_%s.csv" % (tag, fname), index=False)
    print("\nsingle-%s swap: top and bottom per build (uplift over the designed loadout, paired seeds):" % what)
    for build, g in per.groupby("build"):
        g = g.sort_values("d_dpt_median", ascending=False)
        top = ", ".join("%s %+.1f" % (getattr(r, what), r.d_dpt_median) for r in g.head(8).itertuples())
        bot = ", ".join("%s %+.1f" % (getattr(r, what), r.d_dpt_median) for r in g.tail(4).itertuples())
        wins = g.sort_values("d_win", ascending=False).head(4)
        print("  %-18s best DPT: %s\n  %-18s worst DPT: %s\n  %-18s best win rate: %s" % (build, top, "", bot, "", ", ".join("%s %+.0f pts" % (getattr(r, what), 100 * r.d_win) for r in wins.itertuples())))
    if not universal:
        return
    uni = per.groupby(what).agg(builds=("build", "nunique"), d_dpt_median=("d_dpt_median", "mean"), d_win=("d_win", "mean"), positive_on=("d_dpt_median", lambda x: int((x > 0).sum()))).reset_index()
    uni = uni[uni["builds"] >= max(2, uni["builds"].max() - 1)].sort_values("d_dpt_median", ascending=False)
    uni.to_csv(simlib.CHARTS + "/%s_%s_universal.csv" % (tag, fname), index=False)
    print("\n%ss that help every build (mean uplift across builds, and on how many builds it is positive):\n" % what, uni.head(15).round(2).to_string(index=False))
    print("\n%ss that hurt every build:\n" % what, uni.tail(8).round(2).to_string(index=False))


def main_effects(g, a, b, la, lb):
    """How much of the spread each factor explains: the range of row means vs column means."""
    ra = g.groupby(a)["dpt"].mean()
    rb = g.groupby(b)["dpt"].mean()
    print("\n%s main effect on DPT (max − min of means): %.2f   %s: %.2f" % (la, ra.max() - ra.min(), lb, rb.max() - rb.min()))
    print("best %s: %s (%.2f), best %s: %s (%.2f)" % (la, ra.idxmax(), ra.max(), lb, rb.idxmax(), rb.max()))


if __name__ == "__main__":
    main()
