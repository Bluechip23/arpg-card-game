#!/usr/bin/env python3
"""3b on the designed decks — which pairs of a deck's own cards pay together?

Reads the deck-pair ablation sweep (gen_deck_pairs.py; folders
<char>_<build>_e_<ENEMY>__d_{full|b-<a>|b-<a>+<b>}/<policy>/summary.csv,
where b-<a> is the deck with one copy of <a> swapped for the inert blank; the
older m- folders, with the card removed, are read with --mode remove) and
scores every pair per build and enemy, SEED BY SEED:

    synergy(a, b)[seed] = DPT(deck) - DPT(deck - a) - DPT(deck - b) + DPT(deck - a - b)

then the mean and standard error over seeds, averaged over the enemies that
have the complete quartet. The blank keeps the deck's size and the seed's
shuffle, so the four fights of a seed share their draw order until the
swapped card shows up; the paired error is a fraction of the unpaired one.
Positive: the two are worth more together (setup and payoff); negative: they
compete for the bar. A pair is "notable" when |synergy| exceeds --threshold
of the deck's own DPT (default 15 %); "resolved" when it also exceeds twice
its paired standard error.

Writes sim_out/charts/<char>_deck_pairs.csv (one row per build x pair, the
same columns combos.csv has — pair, synergy, base_dpt, enemies, notable —
plus build, win deltas and the error), <char>_deck_pairs_cards.csv (each
card's own worth: DPT(deck) - DPT(deck - card)) and <char>_deck_pairs.png.
Usage: python3 tools/sim_analysis/deck_pairs.py --character ryan [--policy combo_planner] [--threshold 0.15] [--mode blank|remove]
"""
import argparse
import math
import re

import matplotlib.pyplot as plt
import pandas as pd

import simlib

NAME = re.compile(r"^(?P<char>[a-z]+)_(?P<build>[a-z_]+?)_e_(?P<e>[A-Z_]+)__d_(?P<v>.+)$")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--character", default="ryan")
    ap.add_argument("--policy", default="combo_planner")
    ap.add_argument("--threshold", type=float, default=0.15)
    ap.add_argument("--mode", choices=["blank", "remove"], default="blank")
    args = ap.parse_args()
    tagc = "b" if args.mode == "blank" else "m"
    simlib.style()
    df = simlib.load_summaries()
    if df.empty:
        raise SystemExit("no summaries under sim_out/")
    cells = {}
    for scen, g in df[df["policy"] == args.policy].groupby("scenario"):
        m = NAME.match(scen)
        if not m or m.group("char") != args.character:
            continue
        v = m.group("v")
        if v != "full" and not v.startswith(tagc + "-"):
            continue
        cells[(m.group("build"), m.group("e"), v)] = g.set_index("seed")[["damage_per_tempo", "win"]]
    if not cells:
        raise SystemExit("no deck-pair results for %s / %s / mode %s (run tests/sim/sweeps/%s_deck_pairs.txt)" % (args.character, args.policy, args.mode, args.character))
    per = []
    singles = []
    builds_enemies = sorted({(b, e) for (b, e, _v) in cells})
    for b, e in builds_enemies:
        full = cells.get((b, e, "full"))
        if full is None:
            continue
        pre = tagc + "-"
        variants = {v: t for (bb, ee, v), t in cells.items() if bb == b and ee == e and v != "full"}
        for v, t in variants.items():
            if "+" in v:
                continue
            j = full.join(t, lsuffix="_f", rsuffix="_v", how="inner")
            if j.empty:
                continue
            singles.append({"build": b, "e": e, "card": v[len(pre):], "worth": (j["damage_per_tempo_f"] - j["damage_per_tempo_v"]).mean(),
                            "win_delta": (j["win_f"] - j["win_v"]).mean(), "base_dpt": full["damage_per_tempo"].mean()})
        for v, t in variants.items():
            if "+" not in v:
                continue
            a, c = v[len(pre):].split("+", 1)
            ta, tc = variants.get(pre + a), variants.get(pre + c)
            if ta is None or tc is None:
                continue
            j = pd.concat([full["damage_per_tempo"].rename("f"), ta["damage_per_tempo"].rename("a"), tc["damage_per_tempo"].rename("c"), t["damage_per_tempo"].rename("ac"),
                           full["win"].rename("wf"), ta["win"].rename("wa"), tc["win"].rename("wc"), t["win"].rename("wac")], axis=1, join="inner")
            if len(j) < 2:
                continue
            syn = j["f"] - j["a"] - j["c"] + j["ac"]
            wsyn = j["wf"] - j["wa"] - j["wc"] + j["wac"]
            per.append({"build": b, "e": e, "pair": "%s+%s" % (a, c), "a": a, "b": c, "base_dpt": j["f"].mean(),
                        "synergy": syn.mean(), "se": syn.std(ddof=1) / math.sqrt(len(j)), "n": len(j),
                        "win_full": j["wf"].mean(), "win_minus_pair": j["wac"].mean(), "win_synergy": wsyn.mean()})
    if not per:
        raise SystemExit("no complete full / minus-a / minus-b / minus-pair quartet yet")
    per = pd.DataFrame(per)
    out = per.groupby(["build", "pair"]).agg(synergy=("synergy", "mean"), base_dpt=("base_dpt", "mean"),
                                             enemies=("e", "count"), se=("se", lambda s: math.sqrt((s ** 2).sum()) / max(1, len(s))),
                                             win_synergy=("win_synergy", "mean"), win_full=("win_full", "mean")).reset_index()
    out["share"] = out["synergy"] / out["base_dpt"]
    out["notable"] = out["synergy"].abs() > args.threshold * out["base_dpt"]
    out["resolved"] = out["synergy"].abs() > 2.0 * out["se"]
    out = out.sort_values("synergy", ascending=False)
    out.to_csv(simlib.CHARTS + "/%s_deck_pairs.csv" % args.character, index=False)
    sing = pd.DataFrame(singles).groupby(["build", "card"]).agg(worth=("worth", "mean"), win_delta=("win_delta", "mean"),
                                                                 base_dpt=("base_dpt", "mean"), enemies=("e", "count")).reset_index()
    sing["share"] = sing["worth"] / sing["base_dpt"]
    sing = sing.sort_values(["build", "worth"], ascending=[True, False])
    sing.to_csv(simlib.CHARTS + "/%s_deck_pairs_cards.csv" % args.character, index=False)

    pd.set_option("display.width", 200)
    print("mode %s: pairs scored: %d over %d build(s); notable: %d; notable and resolved: %d"
          % (args.mode, len(out), out["build"].nunique(), int(out["notable"].sum()), int((out["notable"] & out["resolved"]).sum())))
    print("\ntop 20 positive synergies:\n", out.head(20).round(3).to_string(index=False))
    print("\nbottom 10 (the pairs that compete):\n", out.tail(10).round(3).to_string(index=False))
    print("\neach card's own worth (DPT with it minus DPT without it), per build:")
    for b, gb in sing.groupby("build"):
        print("  %s: %s" % (b, ", ".join("%s %+.2f" % (r["card"], r["worth"]) for r in gb.to_dict("records"))))

    show = out[out["notable"]].copy()
    if show.empty:
        show = pd.concat([out.head(10), out.tail(10)]).drop_duplicates()
    show["label"] = show["build"] + " : " + show["pair"]
    fig, ax = plt.subplots(figsize=(9, max(4, 0.28 * len(show))))
    colors = [simlib.CATEGORICAL[0] if v >= 0 else simlib.CATEGORICAL[7] for v in show["synergy"]]
    ax.barh(show["label"][::-1], show["synergy"][::-1], xerr=(2.0 * show["se"])[::-1], color=colors[::-1], height=0.7,
            error_kw={"ecolor": simlib.TEXT_2, "elinewidth": 0.8})
    ax.axvline(0, color=simlib.TEXT_2, linewidth=0.8)
    ax.set_xlabel("synergy (damage per tempo beyond the sum of the parts; bars are ±2 s.e.)")
    ax.set_title("%s — deck pairs that pay together (notable at %d %% of deck DPT)" % (args.character, round(args.threshold * 100)))
    ax.grid(axis="y", visible=False)
    simlib.finish(fig, "%s_deck_pairs.png" % args.character)


if __name__ == "__main__":
    main()
