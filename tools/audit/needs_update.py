#!/usr/bin/env python3
"""Phase 5 helper: the outstanding-content facts for every enemy, gathered
from the code and the art folders, for docs/audit/needs_update.md.

Per enemy type: its figure kind and where that art comes from (the
designer's board, a Craftpix pack, an old MonsterKit cell, or nothing),
the sheets on disk, every non-movement action and whether an animation
plays for it, and code markers in its executors (TODO(sheet), FIRST PASS,
mock-up). Prints JSON; the size estimates and wording in needs_update.md
are judgement on top of these facts.

Run: python3 tools/audit/needs_update.py > out.json
"""
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ENEMY = open(os.path.join(ROOT, "scripts/battle/enemy.gd")).read()
DEFS = open(os.path.join(ROOT, "scripts/battle/enemy_defs.gd")).read()
FIG = open(os.path.join(ROOT, "scripts/battle/sprite_enemy_figure.gd")).read()
SHEETS = os.path.join(ROOT, "assets/sprites/generated/sheets")
MOVES = {"move", "hydra_move", "goblin_move", "scurry", "scurry_away", "get_into_range", "flee",
         "roc_retreat", "seek_nest", "dig_walk"}


def enum_names():
    body = re.search(r"enum EnemyType\s*\{(.*?)\}", ENEMY, re.S).group(1)
    return [n.strip() for n in re.sub(r"#.*", "", body).replace("\n", " ").split(",") if n.strip()]


def def_body(name):
    m = re.search(r'"%s":\s*\{(.*?)\n\t\}' % name, DEFS, re.S)
    return m.group(1) if m else ""


ACTIONS_FN = re.search(r"^static func actions_for_type\(.*?(?=^(?:static )?func )", ENEMY, re.S | re.M).group(0)


def actions(name):
    """The action names in this type's own match arm of actions_for_type
    (an arm may list several types: `EnemyType.A, EnemyType.B:`)."""
    arms = re.split(r"\n\t\t(?=EnemyType\.)", ACTIONS_FN)
    for arm in arms:
        head = arm.split(":", 1)[0]
        if re.search(r"\bEnemyType\.%s\b" % name, head):
            return re.findall(r'"name":\s*"(\w+)"', arm)
    return []


def executor(action):
    m = re.search(r'\n\t\t"%s":\s*\n\t\t\treturn (_\w+)' % action, ENEMY)
    return m.group(1) if m else ""


def func_body(fn):
    m = re.search(r"^func %s\(.*?(?=^func |\Z)" % re.escape(fn), ENEMY, re.S | re.M)
    return m.group(0) if m else ""


def kinds_entry(kind):
    m = re.search(r'^\t"%s":\s*(\{.*?\}),?\s*(#.*)?$' % re.escape(kind), FIG, re.M)
    return m.group(1) if m else ""


def main():
    out = []
    for n in enum_names():
        body = def_body(n)
        kind = (re.search(r'"figure_kind":\s*"([^"]*)"', body) or [None, ""])[1]
        entry = kinds_entry(kind) if kind else ""
        if not kind or not entry:
            source = "none (coloured box or label)"
        elif '"cp"' in entry:
            source = "Craftpix pack battler"
        elif '"cell"' in entry:
            source = "MonsterKit cell (old placeholder art)"
        elif '"sheets"' in entry:
            source = "designer's board"
        else:
            source = "other"
        folder = re.search(r'"sheets":\s*SHEETS \+ "/(\w+)"', entry)
        sheet_dir = folder.group(1) if folder else kind
        on_disk = sorted(f[:-4] for f in os.listdir(os.path.join(SHEETS, sheet_dir))
                         if f.endswith(".png")) if sheet_dir and os.path.isdir(os.path.join(SHEETS, sheet_dir)) else []
        act_sheets = dict(re.findall(r'"(\w+)":\s*"(\w+)"', (re.search(r'"action_sheets":\s*\{(.*?)\}', entry) or [None, ""])[1])) if entry else {}
        acts = []
        for a in actions(n):
            if a in MOVES:
                continue
            fn = executor(a)
            fb = func_body(fn) if fn else ""
            anim = act_sheets.get(a) or ("Attack" if "Attack" in on_disk else "")
            acts.append({"action": a, "executor": fn, "animation": anim,
                         "todo_sheet": "TODO(sheet)" in fb, "first_pass": bool(re.search(r"first pass", fb, re.I))})
        out.append({"enum": n, "name": (re.search(r'"name":\s*"([^"]+)"', body) or [None, ""])[1],
                    "tier": (re.search(r'"tier":\s*"([^"]+)"', body) or [None, ""])[1],
                    "mockup": '"mockup": true' in body, "intended_level": int((re.search(r'"intended_level":\s*(\d+)', body) or [None, 0])[1]),
                    "has_resists": '"resists"' in body, "figure_kind": kind, "art_source": source,
                    "sheets": on_disk, "actions": acts})
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
