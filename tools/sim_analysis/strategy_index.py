#!/usr/bin/env python3
"""3a — Enemy strategy index: does a strategic player beat an auto-attacker?

Reads sim_out/baseline_e_<TYPE>/{greedy_dpt,lookahead,combo_planner}/summary.csv
(from tests/sim/sweeps/enemy_strategy.txt) and writes
  sim_out/charts/strategy_index.csv   per enemy and strategic bot: win rates, gaps, entropy, bars to kill;
                                      planner_vs_lookahead when both ran (Milestone 5)
  sim_out/charts/strategy_index.png   strategy_gap bars, sorted (near zero = meat bag)
Usage: python3 tools/sim_analysis/strategy_index.py [--strategic lookahead|combo_planner]
"""
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import simlib


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--strategic", default="lookahead", help="the strategic bot the headline strategy_gap uses (lookahead or combo_planner)")
    args = ap.parse_args()
    simlib.style()
    df = simlib.load_summaries()
    df = df[(df["base"] == "baseline") & df["e"].notna() & df["c"].isna() & df["i"].isna() & df["b"].isna() & df["L"].isna()]
    if df.empty:
        raise SystemExit("no enemy_strategy results under sim_out/ (run tests/sim/sweeps/enemy_strategy.txt first)")
    g = simlib.per_group(df, ["e", "policy"])
    wide = g.pivot(index="e", columns="policy")
    policies = [p for p in wide["win_rate"].columns if p != "greedy_dpt"]
    strategic = args.strategic if args.strategic in policies else ("lookahead" if "lookahead" in policies else policies[0])
    out = pd.DataFrame({
        "greedy_win": wide["win_rate"].get("greedy_dpt"),
        "greedy_taken": wide["taken"].get("greedy_dpt"),
        "greedy_bars_to_kill": wide["bars_to_kill"].get("greedy_dpt"),
    })
    for p in policies:
        out[p + "_win"] = wide["win_rate"].get(p)
        out[p + "_taken"] = wide["taken"].get(p)
        out[p + "_entropy"] = wide["entropy"].get(p)
        out[p + "_bars_to_kill"] = wide["bars_to_kill"].get(p)
        out[p + "_gap"] = out[p + "_win"] - out["greedy_win"]
    out["n"] = wide["n"].get(strategic)
    # The headline columns name the chosen strategic bot (lookahead by default,
    # --strategic combo_planner for Milestone 5).
    out["strategy_gap"] = out[strategic + "_gap"]
    out["taken_gap"] = out["greedy_taken"] - out[strategic + "_taken"]
    out["lookahead_win"] = out.get("lookahead_win")
    out["lookahead_taken"] = out.get("lookahead_taken")
    if "lookahead" in policies and "combo_planner" in policies:
        # Milestone 5: what planning over the bar adds beyond one-step lookahead.
        out["planner_vs_lookahead"] = out["combo_planner_win"] - out["lookahead_win"]
        out["planner_taken_vs_lookahead"] = out["lookahead_taken"] - out["combo_planner_taken"]
    out = out.sort_values("strategy_gap", ascending=False)
    out.to_csv(simlib.CHARTS + "/strategy_index.csv")
    print("strategic bot: %s" % strategic)
    print(out.round(3).to_string())
    if "planner_vs_lookahead" in out:
        pv = out["planner_vs_lookahead"]
        print("\nplanner vs lookahead: win-rate change per enemy — mean %+.3f, better on %d, worse on %d, same on %d"
              % (pv.mean(), int((pv > 0.02).sum()), int((pv < -0.02).sum()), int((pv.abs() <= 0.02).sum())))

    fig, ax = plt.subplots(figsize=(max(8, 0.28 * len(out)), 4.8))
    colors = [simlib.CATEGORICAL[0] if v >= 0 else simlib.CATEGORICAL[7] for v in out["strategy_gap"]]
    ax.bar(out.index, out["strategy_gap"], color=colors, width=0.7)
    ax.axhline(0, color=simlib.TEXT_2, linewidth=0.8)
    # A zero gap means two different things: both players win (a meat bag)
    # or both lose (this enemy is simply above the baseline's level). Mark
    # each so the flat part of the chart still reads.
    flat = out[out["strategy_gap"].abs() < 0.05]
    trivial = flat[(flat[strategic + "_win"] >= 0.95) & (flat["greedy_win"] >= 0.95)]
    over = flat[(flat[strategic + "_win"] <= 0.05) & (flat["greedy_win"] <= 0.05)]
    pos = {name: i for i, name in enumerate(out.index)}
    ax.scatter([pos[n] for n in trivial.index], [-0.06] * len(trivial), marker="v", s=22, color=simlib.CATEGORICAL[2], label="meat bag: both win ≥ 95 %")
    ax.scatter([pos[n] for n in over.index], [-0.06] * len(over), marker="x", s=22, color=simlib.CATEGORICAL[7], label="above this level: both lose")
    ax.legend(loc="upper right")
    ax.set_ylim(-0.12, 1.05)
    ax.set_ylabel("strategy gap (%s − greedy win rate)" % strategic)
    ax.set_title("Enemy strategy index — a gap means the enemy rewards play; near zero, see the markers")
    ax.set_xticks(range(len(out)))
    ax.set_xticklabels(out.index, rotation=70, ha="right", fontsize=7)
    ax.grid(axis="x", visible=False)
    simlib.finish(fig, "strategy_index.png")

    fig, ax = plt.subplots(figsize=(max(8, 0.28 * len(out)), 4.2))
    tg = out.sort_values("taken_gap", ascending=False)
    ax.bar(tg.index, tg["taken_gap"], color=simlib.CATEGORICAL[2], width=0.7)
    ax.axhline(0, color=simlib.TEXT_2, linewidth=0.8)
    ax.set_ylabel("damage avoided by strategy (greedy − %s)" % strategic)
    ax.set_title("Damage taken gap per enemy")
    ax.set_xticks(range(len(tg)))
    ax.set_xticklabels(tg.index, rotation=70, ha="right", fontsize=7)
    ax.grid(axis="x", visible=False)
    simlib.finish(fig, "strategy_taken_gap.png")


if __name__ == "__main__":
    main()
