#!/usr/bin/env python3
"""Export the sphere grid as spreadsheet-ready tables (tab-separated).

Reads the grid the game builds (tests/sim/dump_sphere_grid.gd writes
sim_out/sphere_grid.json) and writes docs/SPHERE_GRID_SHEET.tsv with five
sections, each one a table that pastes straight into a Google Sheet tab:

  1. NODE TYPE SUMMARY   how many nodes of each kind, and what they add up to
                         (total STR on the grid, total HP, total Mana, ...)
  2. ALL NODES           one row per node: id, ring, type, label, effect,
                         stat gate, keystone id, constellations it belongs to,
                         neighbours
  3. KEYSTONES           the build-defining nodes and their unique effects
  4. CONSTELLATIONS      every constellation, its nodes (with labels), bonus,
                         and which other constellations it conflicts with
  5. NOTES               rules of the grid and known text/code mismatches

Re-run after any grid change:
  godot --headless --path . --script tests/sim/dump_sphere_grid.gd
  python3 tools/sphere_grid_sheet.py
"""
import argparse, collections, json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

STAT_NAMES = {"STR": "Strength", "DEX": "Dexterity", "INT": "Intelligence",
              "WIS": "Wisdom", "AGI": "Agility", "DET": "Determination"}
STAT_SHORT = {v.lower(): k for k, v in STAT_NAMES.items()}

TYPE_LABEL = {
    "START": "Start (Origin)",
    "STAT_BONUS": "Stat bonus",
    "HEALTH": "Max health",
    "MANA": "Max mana",
    "FREE_STAT": "Free stat points",
    "COMBAT_BONUS": "Combat bonus",
    "KEYSTONE": "Keystone",
    "CULLING_STONE": "Culling stone",
    "NULL_NODE": "Null (path only)",
    "PASSIVE": "Triggered passive",
    "RETROSPECTIVE": "Retrospective",
    "FEATHER": "Feather (retired)",
}

# Combat-bonus labels grouped so the summary can say "the grid holds +N Block".
COMBAT_GROUPS = [
    ("Block", r"^Block \+"), ("Damage", r"^Damage \+"), ("Heal power", r"^Heal \+"),
    ("Crit chance %", r"^Crit \+"), ("Thorns", r"^Thorns \+"), ("Regen / cycle", r"^Regen \+"),
    ("Life steal %", r"^Life Steal \+"), ("Resist %", r"^Resist \+"), ("Range", r"^Range \+"),
    ("Armor (once)", r"^Armor \+"), ("Unerring cap", r"^Unerring \+"), ("Armor / cycle", r"^Arm/Cyc \+"),
    ("Debuff amp: Vulnerable %", r"^Vuln Amp"), ("Debuff amp: Weaken %", r"^Weaken Amp"),
    ("Buff amp (self-buffs)", r"^(Haste|Enlight|Brace|Blessed|Strength|Bolster|Cleanse|Resil) (Amp|Draw)"),
    ("Debuff amp (hex arc)", r"^(Bleed|Stun|Disarm|Silence|Burn|Poison|Curse|Shatter|Shock|Slow|Root)"),
]


def load(path):
    d = json.load(open(path))
    nodes = sorted(d["nodes"], key=lambda n: n["id"])
    cons = d["constellations"]
    return nodes, cons


def value_of(label):
    m = re.search(r"\+(\d+)", label)
    return int(m.group(1)) if m else 0


def stat_of(label):
    m = re.match(r"^(STR|DEX|INT|WIS|AGI|DET) \+", label)
    return m.group(1) if m else ""


def gate(n):
    r = n.get("requirements") or {}
    if "stat" in r:
        return "%s %s" % (STAT_SHORT.get(r["stat"], r["stat"]), r["value"])
    return ""


def tsv(rows):
    out = []
    for r in rows:
        out.append("\t".join("" if c is None else str(c).replace("\t", " ").replace("\n", " ") for c in r))
    return "\n".join(out)


def build(nodes, cons):
    byid = {n["id"]: n for n in nodes}
    cons_of = collections.defaultdict(list)
    for c in cons:
        for nid in c["nodes"]:
            cons_of[int(nid)].append(c["name"])

    sections = []

    # ---------- 1. Node type summary ----------
    rows = [["SECTION 1: NODE TYPE SUMMARY"], [],
            ["Node type", "Count", "What the whole grid adds up to", "Node ids"]]
    by_type = collections.defaultdict(list)
    for n in nodes:
        by_type[n["type"]].append(n)
    order = ["START", "STAT_BONUS", "FREE_STAT", "HEALTH", "MANA", "COMBAT_BONUS", "KEYSTONE",
             "CULLING_STONE", "NULL_NODE", "PASSIVE", "RETROSPECTIVE", "FEATHER"]
    for t in order:
        ns = by_type.get(t, [])
        if not ns and t not in TYPE_LABEL:
            continue
        total = ""
        if t == "STAT_BONUS":
            per = collections.Counter()
            for n in ns:
                per[stat_of(n["label"])] += value_of(n["label"])
            total = ", ".join("+%d %s" % (per[s], s) for s in STAT_NAMES if per[s])
        elif t == "HEALTH":
            total = "+%d max HP" % sum(value_of(n["label"]) for n in ns)
        elif t == "MANA":
            total = "+%d max Mana" % sum(value_of(n["label"]) for n in ns)
        elif t == "FREE_STAT":
            total = "+%d free stat points" % sum(value_of(n["label"]) for n in ns)
        elif t == "CULLING_STONE":
            total = "%d culling stones" % len(ns)
        elif t == "KEYSTONE":
            total = "%d keystones, max 3 attached at once" % len(ns)
        elif t == "COMBAT_BONUS":
            total = "see breakdown below"
        rows.append([TYPE_LABEL.get(t, t), len(ns), total, ", ".join(str(n["id"]) for n in ns)])
    rows.append(["TOTAL", len(nodes), "", ""])

    rows += [[], ["Stat bonus nodes by stat", "Count", "Total on grid", "Node ids (value)"]]
    for s in STAT_NAMES:
        ns = [n for n in by_type["STAT_BONUS"] if stat_of(n["label"]) == s]
        rows.append(["%s (%s)" % (s, STAT_NAMES[s]), len(ns), "+%d" % sum(value_of(n["label"]) for n in ns),
                     ", ".join("%d (+%d)" % (n["id"], value_of(n["label"])) for n in ns)])

    rows += [[], ["Vitality nodes by size", "Count", "Total", "Node ids"]]
    for t, word in (("HEALTH", "HP"), ("MANA", "Mana")):
        sizes = collections.defaultdict(list)
        for n in by_type[t]:
            sizes[value_of(n["label"])].append(n["id"])
        for v in sorted(sizes):
            rows.append(["%s +%d" % (word, v), len(sizes[v]), "+%d" % (v * len(sizes[v])),
                         ", ".join(str(i) for i in sizes[v])])

    rows += [[], ["Combat bonus group", "Count", "Total on grid", "Node ids (label)"]]
    seen = set()
    for name, pat in COMBAT_GROUPS:
        ns = [n for n in by_type["COMBAT_BONUS"] if re.search(pat, n["label"])]
        for n in ns:
            seen.add(n["id"])
        if not ns:
            continue
        if name.startswith(("Buff amp", "Debuff amp (hex")):
            total = "%d distinct amps" % len(ns)
        else:
            total = "+%d" % sum(value_of(n["label"]) for n in ns)
        rows.append([name, len(ns), total, ", ".join("%d (%s)" % (n["id"], n["label"]) for n in ns)])
    rest = [n for n in by_type["COMBAT_BONUS"] if n["id"] not in seen]
    if rest:
        rows.append(["Other", len(rest), "", ", ".join("%d (%s)" % (n["id"], n["label"]) for n in rest)])

    rows += [[], ["Nodes per ring", "Count", "Radius (px)", "Node ids"]]
    ring_names = {0: "Ring 0 (Origin)", 1: "Ring 1", 2: "Ring 2", 3: "Ring 3 (+ null links 31-36)",
                  4: "Ring 4", 5: "Ring 5", 6: "Ring 6", 7: "Buff-amp arc", 8: "Debuff-amp (hex) arc"}
    for r in sorted(set(n["ring"] for n in nodes)):
        ns = [n for n in nodes if n["ring"] == r]
        radii = sorted(set(round(((n["x"] - 640) ** 2 + (n["y"] - 360) ** 2) ** 0.5) for n in ns))
        rows.append([ring_names.get(r, "Ring %d" % r), len(ns), "/".join(str(x) for x in radii),
                     "%d-%d" % (ns[0]["id"], ns[-1]["id"]) if len(ns) > 1 else str(ns[0]["id"])])
    sections.append(rows)

    # ---------- 2. All nodes ----------
    rows = [["SECTION 2: ALL NODES"], [],
            ["Id", "Ring", "Type", "Label", "Effect", "Stat gate", "Keystone id",
             "Constellations", "Connected to"]]
    for n in nodes:
        rows.append([n["id"], n["ring"], TYPE_LABEL.get(n["type"], n["type"]),
                     n["label"] if n["type"] != "NULL_NODE" else "(null)",
                     n["description"], gate(n), n.get("keystone", ""),
                     ", ".join(cons_of.get(n["id"], [])),
                     ", ".join(str(c) for c in sorted(int(c) for c in n["connections"]))])
    sections.append(rows)

    # ---------- 3. Keystones ----------
    rows = [["SECTION 3: KEYSTONES (unique effects; a character may attach at most 3)"], [],
            ["Id", "Ring", "Name", "Keystone id", "Stat gate", "Effect", "Constellations"]]
    for n in nodes:
        if n["type"] != "KEYSTONE":
            continue
        desc = re.sub(r"^Keystone:\s*", "", n["description"])
        rows.append([n["id"], n["ring"], n["label"], n.get("keystone", ""), gate(n) or "none",
                     desc, ", ".join(cons_of.get(n["id"], [])) or "none"])
    sections.append(rows)

    # ---------- 4. Constellations ----------
    rows = [["SECTION 4: CONSTELLATIONS"], [],
            ["Constellation", "Id", "Bonus", "Required nodes (id: label)", "Node count",
             "Conflicts with (shares nodes)", "Shared node ids"]]
    for c in cons:
        mine = set(int(i) for i in c["nodes"])
        conflicts, shared = [], []
        for o in cons:
            if o["id"] == c["id"]:
                continue
            common = mine & set(int(i) for i in o["nodes"])
            if common:
                conflicts.append(o["name"])
                shared.append("%s: %s" % (o["name"], ", ".join(str(i) for i in sorted(common))))
        node_txt = "; ".join("%d: %s" % (i, byid[i]["label"] if byid[i]["type"] != "NULL_NODE" else "null")
                             for i in c["nodes"])
        rows.append([c["name"], c["id"], c["bonus_description"], node_txt, len(c["nodes"]),
                     ", ".join(conflicts) or "none", "; ".join(shared)])

    rows += [[], ["Node", "Label", "Member of"]]
    for nid in sorted(cons_of):
        if len(cons_of[nid]) > 1:
            lbl = byid[nid]["label"] if byid[nid]["type"] != "NULL_NODE" else "(null)"
            rows.append([nid, lbl, ", ".join(cons_of[nid])])
    sections.append(rows)

    # ---------- 5. Notes ----------
    rows = [["SECTION 5: NOTES"], [],
            ["Topic", "Note"],
            ["Unlocking", "A node can be unlocked when any neighbour is unlocked. Origin (id 0) starts unlocked."],
            ["Keystone cap", "MAX_KEYSTONES = 3. A fourth keystone cannot be unlocked while three are attached."],
            ["Stat gates", "Gated nodes compare against the character's BASE stat (sphere and equipment bonuses excluded; DET uses the live determination value)."],
            ["Constellations", "Completing all required nodes offers the bonus. Two constellations that share a node cannot both be active: the newer one replaces the older (replacement modal), and the old bonus is removed."],
            ["Null nodes", "Ids 31-36 are placeholder links between Rings 3 and 4 kept so Windwalker, Storm Runner, Unyielding, Shadow Strike and Iron Bastion stay completable."],
            ["Free stat nodes", "'+3 Stats' banks 3 points into the level-up pool; the player allocates them on the stat screen."],
            ["Armor +1", "Grants 1 armor once on unlock (not a permanent max); also adds to sphere_bonus_armor."],
            ["Unyielding (text vs code)", "Tooltip says 'Determination scaling +20%'. Code grants a flat +2 Determination (apply_sphere_grid_stat('determination', 2))."],
            ["Vuln Amp (text)", "Node 72 reads '45% instead of 30%'; node 101 reads 'an extra 15% (stacks)'. Both add +15 to sphere_vulnerable_amp."],
            ["Conversion keystones", "Ids 130-133 (Sanguine Barrier, Living Bulwark, Arcane Blood, Willspring) have no stat gate yet; placement and gates await the layout pass."],
            ["Shelved passives", "16 triggered PASSIVE nodes were retired from Rings 4-6 (now null links); those effects are destined for item engravings."],
            ["Source", "scripts/progression/sphere_grid.gd (data), scripts/progression/progression_triggers.gd (node + constellation effects), scripts/character/player_stats.gd (combat bonus parsing)."]]
    sections.append(rows)
    return sections


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default=os.path.join(ROOT, "sim_out", "sphere_grid.json"))
    ap.add_argument("--output", default=os.path.join(ROOT, "docs", "SPHERE_GRID_SHEET.tsv"))
    args = ap.parse_args()
    nodes, cons = load(args.input)
    sections = build(nodes, cons)
    with open(args.output, "w") as f:
        f.write("\n\n\n".join(tsv(s) for s in sections) + "\n")
    print("wrote %s (%d nodes, %d constellations)" % (args.output, len(nodes), len(cons)))


if __name__ == "__main__":
    main()
