#!/usr/bin/env python3
"""3a — Enemy strategy index: does a strategic player beat an auto-attacker?

Reads sim_out/baseline_e_<TYPE>/{greedy_dpt,lookahead}/summary.csv (from
tests/sim/sweeps/enemy_strategy.txt) and writes
  sim_out/charts/strategy_index.csv   per enemy: win rates, strategy_gap, taken_gap, entropy, bars to kill
  sim_out/charts/strategy_index.png   strategy_gap bars, sorted (near zero = meat bag)
Usage: python3 tools/sim_analysis/strategy_index.py
"""
import pandas as pd
import matplotlib.pyplot as plt
import simlib


def main():
    simlib.style()
    df = simlib.load_summaries()
    df = df[(df["base"] == "baseline") & df["e"].notna() & df["c"].isna() & df["i"].isna() & df["b"].isna() & df["L"].isna()]
    if df.empty:
        raise SystemExit("no enemy_strategy results under sim_out/ (run tests/sim/sweeps/enemy_strategy.txt first)")
    g = simlib.per_group(df, ["e", "policy"])
    wide = g.pivot(index="e", columns="policy")
    out = pd.DataFrame({
        "greedy_win": wide["win_rate"].get("greedy_dpt"),
        "lookahead_win": wide["win_rate"].get("lookahead"),
        "greedy_taken": wide["taken"].get("greedy_dpt"),
        "lookahead_taken": wide["taken"].get("lookahead"),
        "lookahead_entropy": wide["entropy"].get("lookahead"),
        "greedy_bars_to_kill": wide["bars_to_kill"].get("greedy_dpt"),
        "lookahead_bars_to_kill": wide["bars_to_kill"].get("lookahead"),
        "n": wide["n"].get("lookahead"),
    })
    out["strategy_gap"] = out["lookahead_win"] - out["greedy_win"]
    out["taken_gap"] = out["greedy_taken"] - out["lookahead_taken"]
    out = out.sort_values("strategy_gap", ascending=False)
    out.to_csv(simlib.CHARTS + "/strategy_index.csv")
    print(out.round(3).to_string())

    fig, ax = plt.subplots(figsize=(max(8, 0.28 * len(out)), 4.8))
    colors = [simlib.CATEGORICAL[0] if v >= 0 else simlib.CATEGORICAL[7] for v in out["strategy_gap"]]
    ax.bar(out.index, out["strategy_gap"], color=colors, width=0.7)
    ax.axhline(0, color=simlib.TEXT_2, linewidth=0.8)
    ax.set_ylabel("strategy gap (lookahead − greedy win rate)")
    ax.set_title("Enemy strategy index — enemies near zero are meat bags")
    ax.set_xticks(range(len(out)))
    ax.set_xticklabels(out.index, rotation=70, ha="right", fontsize=7)
    ax.grid(axis="x", visible=False)
    simlib.finish(fig, "strategy_index.png")

    fig, ax = plt.subplots(figsize=(max(8, 0.28 * len(out)), 4.2))
    tg = out.sort_values("taken_gap", ascending=False)
    ax.bar(tg.index, tg["taken_gap"], color=simlib.CATEGORICAL[2], width=0.7)
    ax.axhline(0, color=simlib.TEXT_2, linewidth=0.8)
    ax.set_ylabel("damage avoided by strategy (greedy − lookahead)")
    ax.set_title("Damage taken gap per enemy")
    ax.set_xticks(range(len(tg)))
    ax.set_xticklabels(tg.index, rotation=70, ha="right", fontsize=7)
    ax.grid(axis="x", visible=False)
    simlib.finish(fig, "strategy_taken_gap.png")


if __name__ == "__main__":
    main()
