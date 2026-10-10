#!/usr/bin/env python3
"""3c — Card and item power: one-at-a-time deltas against the control.

For each added card (tests/sim/sweeps/card_power.txt) and each item
(item_power.txt): delta in win rate, damage per tempo and damage taken versus
the e_<T>__c_base / i_base control, averaged over enemies, grouped by rarity.
Writes sim_out/charts/card_power.csv, item_power.csv, card_power.png (DPT delta
vs mana cost, color = rarity; and vs tempo cost), item_power.png (vs weight).
Usage: python3 tools/sim_analysis/card_item_power.py
"""
import pandas as pd
import matplotlib.pyplot as plt
import simlib


def deltas(df, key):
    g = df.groupby(["e", key]).agg(win=("win", "mean"), dpt=("damage_per_tempo", "mean"), taken=("total_damage_taken", "mean"),
                                   n=("seed", "count"), clean=("clean", "mean")).reset_index()
    rows = []
    for e, ge in g.groupby("e"):
        base = ge[ge[key] == "base"]
        if base.empty:
            continue
        b = base.iloc[0]
        for _, r in ge[ge[key] != "base"].iterrows():
            rows.append({"enemy": e, key: r[key], "d_win": r["win"] - b["win"], "d_dpt": r["dpt"] - b["dpt"],
                         "d_taken": r["taken"] - b["taken"], "n": r["n"], "clean": r["clean"]})
    if not rows:
        return pd.DataFrame()
    per = pd.DataFrame(rows)
    return per.groupby(key).agg(d_win=("d_win", "mean"), d_dpt=("d_dpt", "mean"), d_taken=("d_taken", "mean"),
                                enemies=("enemy", "count"), clean=("clean", "min")).reset_index()


def scatter(out, x, xlabel, title, name, rarity_col):
    fig, ax = plt.subplots(figsize=(8, 5))
    # An item the inventory refused (carry gate, mythic limit, slot) is not a
    # measurement of the item: hollow marker, left out of the tier band.
    refused = out[out["clean"] < 1]
    if not refused.empty:
        ax.scatter(refused[x], refused["d_dpt"], s=28, facecolors="none", edgecolors=simlib.TEXT_2, linewidths=1, label="equip refused")
    out = out[out["clean"] >= 1]
    for i, rar in enumerate(simlib.RARITY_ORDER):
        sub = out[out[rarity_col].str.capitalize() == rar]
        if sub.empty:
            continue
        ax.scatter(sub[x], sub["d_dpt"], s=28, color=simlib.CATEGORICAL[i], label=rar, edgecolors=simlib.SURFACE, linewidths=1)
        # the band: mean ± std per tier; points outside are the outliers
        m, s = sub["d_dpt"].mean(), sub["d_dpt"].std()
        if pd.notna(s):
            ax.axhspan(m - s, m + s, color=simlib.CATEGORICAL[i], alpha=0.06)
            for _, r in sub[(sub["d_dpt"] - m).abs() > s].iterrows():
                ax.annotate(r["id"], (r[x], r["d_dpt"]), fontsize=6, color=simlib.TEXT_2, xytext=(3, 3), textcoords="offset points")
    ax.axhline(0, color=simlib.TEXT_2, linewidth=0.8)
    ax.set_xlabel(xlabel); ax.set_ylabel("damage per tempo vs control")
    ax.set_title(title); ax.legend(title="rarity")
    simlib.finish(fig, name)


def main():
    simlib.style()
    cat = simlib.load_catalog()
    df = simlib.load_summaries()
    df = df[(df["base"] == "baseline") & (df["policy"] == "lookahead") & df["e"].notna()]
    cards = df[df["c"].notna() & df["cc"].isna()]
    items = df[df["i"].notna()]
    meta_c = {c["id"]: c for c in cat["cards"]}
    meta_i = {i["id"]: i for i in cat["items"]}
    if not cards.empty:
        out = deltas(cards, "c").rename(columns={"c": "id"})
        out["rarity"] = out["id"].map(lambda i: meta_c.get(i, {}).get("rarity", "?"))
        out["mana"] = out["id"].map(lambda i: meta_c.get(i, {}).get("mana"))
        out["tempo"] = out["id"].map(lambda i: meta_c.get(i, {}).get("tempo"))
        out = out.sort_values("d_dpt", ascending=False)
        out.to_csv(simlib.CHARTS + "/card_power.csv", index=False)
        print("cards (top/bottom 10 by DPT delta):\n", pd.concat([out.head(10), out.tail(10)]).round(3).to_string())
        scatter(out, "mana", "mana cost", "Card power — DPT delta vs mana cost (shaded: tier mean ± 1 sd)", "card_power.png", "rarity")
        scatter(out, "tempo", "tempo cost", "Card power — DPT delta vs tempo cost", "card_power_tempo.png", "rarity")
    else:
        print("no card_power results under sim_out/")
    if not items.empty:
        out = deltas(items, "i").rename(columns={"i": "id"})
        out["rarity"] = out["id"].map(lambda i: meta_i.get(i, {}).get("rarity", "?"))
        out["weight"] = out["id"].map(lambda i: meta_i.get(i, {}).get("weight"))
        out["type"] = out["id"].map(lambda i: meta_i.get(i, {}).get("type"))
        out = out.sort_values("d_dpt", ascending=False)
        out.to_csv(simlib.CHARTS + "/item_power.csv", index=False)
        print("items (top/bottom 10 by DPT delta; clean=0 means an equip was refused):\n", pd.concat([out.head(10), out.tail(10)]).round(3).to_string())
        scatter(out, "weight", "item weight", "Item power — DPT delta vs weight (shaded: tier mean ± 1 sd)", "item_power.png", "rarity")
    else:
        print("no item_power results under sim_out/")


if __name__ == "__main__":
    main()
