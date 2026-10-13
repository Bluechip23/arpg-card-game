#!/usr/bin/env python3
"""3b — Combo discovery: which card pairs are more than the sum of their parts?

synergy(A,B) = DPT(deck+A+B) − DPT(deck+A) − DPT(deck+B) + DPT(deck), averaged
over the enemies the sweep ran (tests/sim/sweeps/combos.txt). Pairs with
|synergy| above --threshold (default 15 %) of the baseline DPT are notable.
Writes sim_out/charts/combos.csv and combos.png (top/bottom 20).
Usage: python3 tools/sim_analysis/combos.py [--threshold 0.15]
"""
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import simlib


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--threshold", type=float, default=0.15)
    args = ap.parse_args()
    simlib.style()
    df = simlib.load_summaries()
    df = df[(df["base"] == "baseline") & (df["policy"] == "lookahead") & df["e"].notna() & (df["c"].notna() | df["cc"].notna())]
    if df.empty:
        raise SystemExit("no combo results under sim_out/ (run tests/sim/sweeps/combos.txt first)")
    df["variant"] = df["cc"].fillna(df["c"])
    g = df.groupby(["e", "variant"]).agg(dpt=("damage_per_tempo", "mean"), win=("win", "mean"), n=("seed", "count")).reset_index()
    rows = []
    for e, ge in g.groupby("e"):
        dpt = dict(zip(ge["variant"], ge["dpt"]))
        base = dpt.get("base")
        if base is None:
            continue
        for v in dpt:
            if "+" not in v:
                continue
            a, b = v.split("+", 1)
            if a in dpt and b in dpt:
                rows.append({"enemy": e, "pair": v, "a": a, "b": b, "base_dpt": base, "dpt_a": dpt[a], "dpt_b": dpt[b], "dpt_ab": dpt[v],
                             "synergy": dpt[v] - dpt[a] - dpt[b] + base})
    if not rows:
        raise SystemExit("no complete pair/single/base triples yet")
    per = pd.DataFrame(rows)
    out = per.groupby("pair").agg(synergy=("synergy", "mean"), base_dpt=("base_dpt", "mean"), enemies=("enemy", "count")).sort_values("synergy", ascending=False)
    out["notable"] = out["synergy"].abs() > args.threshold * out["base_dpt"]
    out.to_csv(simlib.CHARTS + "/combos.csv")
    print("top 20 positive synergies:\n", out.head(20).round(3).to_string())
    print("\ntop 20 negative synergies:\n", out.tail(20).round(3).to_string())

    show = pd.concat([out.head(20), out.tail(20)]).drop_duplicates()
    fig, ax = plt.subplots(figsize=(8, max(4, 0.25 * len(show))))
    colors = [simlib.CATEGORICAL[0] if v >= 0 else simlib.CATEGORICAL[7] for v in show["synergy"]]
    ax.barh(show.index[::-1], show["synergy"][::-1], color=colors[::-1], height=0.7)
    ax.axvline(0, color=simlib.TEXT_2, linewidth=0.8)
    thr = args.threshold * out["base_dpt"].mean()
    ax.axvline(thr, color=simlib.GRID, linestyle="--"); ax.axvline(-thr, color=simlib.GRID, linestyle="--")
    ax.set_xlabel("synergy (damage per tempo beyond the sum of the parts)")
    ax.set_title("Card pair synergy — top and bottom 20")
    ax.grid(axis="y", visible=False)
    simlib.finish(fig, "combos.png")


if __name__ == "__main__":
    main()
