"""Shared loaders and chart style for the sim analysis scripts (docs/sim/README.md).

Reads sim_out/<scenario>/<policy>/summary.csv files written by
tests/sim/run_sim.gd. Scenario folder names carry the sweep's overrides as
`<base>_<k>_<v>__<k>_<v>` (see gen_sweeps.py): e = enemy type, c = added card,
cc = added pair (a+b), i = item, b = build, L = level.
"""
import glob, json, os
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SIM_OUT = os.environ.get("SIM_OUT", os.path.join(ROOT, "sim_out"))
CHARTS = os.path.join(SIM_OUT, "charts")

# Validated default palette (dataviz skill, references/palette.md): fixed
# categorical order, one-hue sequential blue, blue<->red diverging.
CATEGORICAL = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948"]
SEQUENTIAL = ["#cde2fb", "#b7d3f6", "#9ec5f4", "#86b6ef", "#6da7ec", "#5598e7", "#3987e5", "#2a78d6", "#256abf", "#1c5cab", "#184f95", "#104281", "#0d366b"]
DIVERGING = ("#2a78d6", "#f0efec", "#e34948")
TEXT = "#0b0b0b"
TEXT_2 = "#52514e"
GRID = "#e4e3df"
SURFACE = "#fcfcfb"
RARITY_SLOT = {"Basic": 0, "Common": 0, "COMMON": 0, "Rare": 1, "RARE": 1, "Legendary": 2, "LEGENDARY": 2, "Mythic": 3, "MYTHIC": 3}
RARITY_ORDER = ["Common", "Rare", "Legendary", "Mythic"]


def style():
    os.makedirs(CHARTS, exist_ok=True)
    plt.rcParams.update({
        "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
        "axes.edgecolor": GRID, "axes.labelcolor": TEXT_2, "xtick.color": TEXT_2, "ytick.color": TEXT_2,
        "text.color": TEXT, "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.6,
        "axes.spines.top": False, "axes.spines.right": False, "axes.titleweight": "normal",
        "axes.titlesize": 12, "font.size": 9, "legend.frameon": False,
    })


def load_summaries(sim_out=SIM_OUT) -> pd.DataFrame:
    frames = []
    for path in sorted(glob.glob(os.path.join(sim_out, "*", "*", "summary.csv"))):
        policy = os.path.basename(os.path.dirname(path))
        scenario = os.path.basename(os.path.dirname(os.path.dirname(path)))
        try:
            df = pd.read_csv(path)
        except pd.errors.EmptyDataError:
            continue
        df["scenario"] = scenario
        df["policy"] = policy
        frames.append(df)
    if not frames:
        return pd.DataFrame()
    df = pd.concat(frames, ignore_index=True)
    df = df.drop_duplicates(subset=["scenario", "policy", "seed"], keep="last")
    parts = df["scenario"].apply(parse_name)
    for key in ["base", "e", "c", "cc", "i", "b", "L"]:
        df[key] = parts.apply(lambda d: d.get(key))
    df["win"] = (df["outcome"] == "win").astype(float)
    df["clean"] = df["warnings"].fillna("").astype(str).str.len().eq(0) if "warnings" in df else True
    return df


def parse_name(name: str) -> dict:
    """baseline_e_WERERAT__c_fireball -> {base: baseline, e: WERERAT, c: fireball}."""
    out = {}
    if "_" not in name:
        return {"base": name}
    head, *tail = name.split("__")
    # the first chunk is <base>_<k>_<v> where base has no "_k_" marker... bases are single words
    bits = head.split("_", 2)
    out["base"] = bits[0]
    if len(bits) == 3:
        out[bits[1]] = bits[2]
    elif len(bits) == 2:
        out["base"] = head
    for t in tail:
        k, _, v = t.partition("_")
        out[k] = v
    return out


def load_catalog(sim_out=SIM_OUT) -> dict:
    with open(os.path.join(sim_out, "catalog.json")) as f:
        return json.load(f)


def charts_dir() -> str:
    os.makedirs(CHARTS, exist_ok=True)
    return CHARTS


def per_group(df: pd.DataFrame, keys) -> pd.DataFrame:
    """Win rate, mean DPT, damage taken, bars (wins only) and entropy per group."""
    g = df.groupby(keys)
    out = g.agg(n=("seed", "count"), win_rate=("win", "mean"), dpt=("damage_per_tempo", "mean"),
                taken=("total_damage_taken", "mean"), entropy=("card_entropy", "mean"),
                bars=("bars_elapsed", "mean"), end_hp=("end_hp_pct", "mean"))
    wins = df[df["win"] == 1].groupby(keys)["bars_elapsed"].mean().rename("bars_to_kill")
    return out.join(wins).reset_index()


def finish(fig, name: str):
    path = os.path.join(charts_dir(), name)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print("wrote", os.path.relpath(path, ROOT))
    return path
