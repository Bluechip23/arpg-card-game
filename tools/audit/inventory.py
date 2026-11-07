#!/usr/bin/env python3
"""Project inventory for the audit (docs/audit/inventory.md, Phase 0).

Maps the project from the files themselves, so every later pass can re-run
it instead of rebuilding the map by hand:

  - scripts, scenes, resources, autoloads and what references what
    (preload/load paths, scene ext_resources, class_name uses);
  - every card, item, enemy, character, summon, passive and status effect,
    where it is defined and every gameplay file that names it (where its
    behaviour lives);
  - dead-code candidates (functions whose name appears nowhere else),
    duplicated function bodies, orphaned scripts/scenes, preload cycles and
    class-reference cycles, and the files carrying the most bare numbers.

Heuristics are labelled as such in the output: a name that appears only in
its own definition can still be reached through a computed string, and a
texture no script names literally can be loaded from a built path.

Run: python3 tools/audit/inventory.py [--json OUT.json] [--md OUT.md]
"""
import argparse
import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAMEPLAY_DIRS = ("scripts", "resources")
SKIP_DIRS = {".git", ".godot", "sim_out", "node_modules"}


def rel(p):
    return os.path.relpath(p, ROOT).replace(os.sep, "/")


def walk(exts, dirs=None):
    out = []
    for base in (dirs or ["."]):
        for dp, dn, fn in os.walk(os.path.join(ROOT, base)):
            dn[:] = [d for d in dn if d not in SKIP_DIRS]
            for f in fn:
                if f.endswith(exts):
                    out.append(rel(os.path.join(dp, f)))
    return sorted(out)


def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8", errors="replace") as fh:
        return fh.read()


# ---------------------------------------------------------------- files

def project_settings():
    txt = read("project.godot")
    autoloads = dict(re.findall(r'^(\w+)="\*?(res://[^"]+)"', txt.split("[autoload]")[1].split("\n[")[0], re.M)) \
        if "[autoload]" in txt else {}
    main = re.search(r'run/main_scene="([^"]+)"', txt)
    return {"autoloads": autoloads, "main_scene": main.group(1) if main else ""}


FUNC_RE = re.compile(r"^(static\s+)?func\s+(\w+)\s*\(", re.M)
CLASS_RE = re.compile(r"^class_name\s+(\w+)", re.M)
EXTENDS_RE = re.compile(r"^extends\s+(\S+)", re.M)
RES_RE = re.compile(r'(preload|load)\(\s*"(res://[^"]+)"\s*\)')
RES_ANY_RE = re.compile(r'"(res://[^"]+)"')
EXT_RES_RE = re.compile(r'\[ext_resource[^\]]*path="(res://[^"]+)"')


def scan_scripts():
    scripts = {}
    for p in walk((".gd",)):
        txt = read(p)
        cls = CLASS_RE.search(txt)
        ext = EXTENDS_RE.search(txt)
        funcs = [m.group(2) for m in FUNC_RE.finditer(txt)]
        scripts[p] = {
            "class_name": cls.group(1) if cls else "",
            "extends": ext.group(1) if ext else "",
            "lines": txt.count("\n") + 1,
            "funcs": funcs,
            "preloads": sorted({m.group(2) for m in RES_RE.finditer(txt) if m.group(1) == "preload"}),
            "loads": sorted({m.group(2) for m in RES_RE.finditer(txt) if m.group(1) == "load"}),
            "res_strings": sorted(set(RES_ANY_RE.findall(txt))),
        }
    return scripts


def scan_resources(exts):
    out = {}
    for p in walk(exts):
        txt = read(p)
        out[p] = {"ext": sorted(set(EXT_RES_RE.findall(txt)))}
    return out


# ---------------------------------------------------------------- references

def build_text_index(paths):
    return {p: read(p) for p in paths}


def word_count(texts, word):
    rx = re.compile(r"\b%s\b" % re.escape(word))
    hits = {}
    for p, t in texts.items():
        n = len(rx.findall(t))
        if n:
            hits[p] = n
    return hits


def string_hits(texts, s, exclude_prefixes=()):
    """Files (and line numbers) holding the literal "s" (quoted)."""
    needle_a, needle_b = '"%s"' % s, "'%s'" % s
    out = {}
    for p, t in texts.items():
        if p.startswith(exclude_prefixes):
            continue
        if needle_a in t or needle_b in t:
            lines = [i + 1 for i, ln in enumerate(t.split("\n")) if needle_a in ln or needle_b in ln]
            out[p] = lines
    return out


def sccs(graph):
    """Tarjan's strongly connected components (iterative)."""
    index, low, on, stack, out = {}, {}, set(), [], []
    counter = [0]
    for v0 in graph:
        if v0 in index:
            continue
        work = [(v0, iter(graph.get(v0, ())))]
        index[v0] = low[v0] = counter[0]; counter[0] += 1
        stack.append(v0); on.add(v0)
        while work:
            v, it = work[-1]
            advanced = False
            for w in it:
                if w not in index:
                    index[w] = low[w] = counter[0]; counter[0] += 1
                    stack.append(w); on.add(w)
                    work.append((w, iter(graph.get(w, ()))))
                    advanced = True
                    break
                elif w in on:
                    low[v] = min(low[v], index[w])
            if advanced:
                continue
            work.pop()
            if work:
                low[work[-1][0]] = min(low[work[-1][0]], low[v])
            if low[v] == index[v]:
                comp = []
                while True:
                    w = stack.pop(); on.discard(w); comp.append(w)
                    if w == v:
                        break
                if len(comp) > 1:
                    out.append(sorted(comp))
    return out


# ---------------------------------------------------------------- content

def cards():
    out = []
    for p in walk((".tres",), ["data/cards"]):
        t = read(p)
        g = lambda k: (re.search(r'^%s = (.+)$' % k, t, re.M) or [None, ""])[1].strip().strip('"')
        out.append({"id": g("card_id") or os.path.basename(p)[:-5], "name": g("card_name"),
                    "type": g("card_type_name"), "tempo": g("tempo_cost"), "mana": g("mana_cost"),
                    "file": p, "description": g("description")})
    return out


def items():
    out = []
    for p in walk((".tres",), ["data/items"]):
        t = read(p)
        g = lambda k: (re.search(r'^%s = (.+)$' % k, t, re.M) or [None, ""])[1].strip().strip('"')
        fields = [k for k in re.findall(r"^(\w+) = ", t, re.M)
                  if k not in ("script", "item_name", "rarity", "weight", "description", "item_type",
                               "weapon_subtype", "vanilla_slots", "appearance")]
        out.append({"id": os.path.basename(p)[:-5], "name": g("item_name"), "special_id": g("special_id"),
                    "file": p, "fields": fields, "description": g("description")})
    return out


def enemies(texts):
    enemy = texts["scripts/battle/enemy.gd"]
    enum = re.search(r"enum EnemyType\s*\{(.*?)\}", enemy, re.S).group(1)
    names = [n.strip() for n in re.sub(r"#.*", "", enum).replace("\n", " ").split(",") if n.strip()]
    defs = texts["scripts/battle/enemy_defs.gd"]
    out = []
    for n in names:
        m = re.search(r'"%s":\s*\{(.*?)\n\t\}' % n, defs, re.S)
        body = m.group(1) if m else ""
        dn = re.search(r'"name":\s*"([^"]+)"', body)
        tier = re.search(r'"tier":\s*"([^"]+)"', body)
        chooser = re.search(r"EnemyType\.%s:\s*\n\s*(_choose_\w+|chosen_action = )" % n, enemy)
        refs = {p: c for p, c in word_count(texts, "EnemyType.%s" % n).items() if not p.startswith("tests/")}
        tests = [p for p in word_count(texts, "EnemyType.%s" % n) if p.startswith("tests/")]
        out.append({"enum": n, "name": dn.group(1) if dn else "", "tier": tier.group(1) if tier else "",
                    "mockup": '"mockup": true' in body, "chooser": chooser.group(1) if chooser else "",
                    "refs": refs, "tests": tests})
    return out


def passives():
    ref = read("docs/PASSIVE_REFERENCE.md")
    out = []
    char = ""
    for ln in ref.split("\n"):
        h = re.match(r"^## (\w+) \(\d+ passives\)", ln)
        if h:
            char = h.group(1)
        m = re.match(r"^- \*\*(.+?)\*\* \(`(\w+)`, level (\d+)\)", ln)
        if m:
            out.append({"name": m.group(1), "id": m.group(2), "level": int(m.group(3)), "character": char})
    return out


def enum_members(text, enum_name):
    m = re.search(r"enum %s\s*\{(.*?)\}" % enum_name, text, re.S)
    body = re.sub(r"#[^\n]*", "", m.group(1))
    return [n.strip().split("=")[0].strip() for n in body.split(",") if n.strip()]


# ---------------------------------------------------------------- code health

def func_bodies(text):
    """(name, normalized body, line) for each top-level func."""
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        m = re.match(r"^(static\s+)?func\s+(\w+)", lines[i])
        if not m:
            i += 1
            continue
        start = i
        i += 1
        body = []
        while i < len(lines) and (lines[i].startswith(("\t", " ")) or lines[i].strip() == ""):
            s = lines[i].strip()
            if s and not s.startswith("#"):
                body.append(re.sub(r"\s+", " ", s))
            i += 1
        out.append((m.group(2), "\n".join(body), start + 1))
    return out


NUM_RE = re.compile(r"(?<![\w.#\"'])(-?\d+\.\d+|-?\d+)(?![\w.])")


def magic_numbers(text):
    n = 0
    for ln in text.split("\n"):
        s = ln.strip()
        if not s or s.startswith("#") or s.startswith("const ") or s.startswith("##") \
                or s.startswith("enum") or "Color(" in s or "Vector" in s:
            continue
        s = re.sub(r'"[^"]*"', '""', s)
        s = s.split("#")[0]
        for v in NUM_RE.findall(s):
            if v not in ("0", "1", "-1", "2", "0.0", "1.0", "0.5", "-1.0", "2.0"):
                n += 1
    return n


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="")
    ap.add_argument("--md", default="")
    args = ap.parse_args()

    settings = project_settings()
    scripts = scan_scripts()
    scenes = scan_resources((".tscn",))
    tres = scan_resources((".tres",))
    all_text_paths = [p for p in walk((".gd", ".tscn", ".tres", ".godot", ".cfg", ".py", ".sh"))]
    texts = build_text_index(all_text_paths)
    game_texts = {p: t for p, t in texts.items() if p.startswith(GAMEPLAY_DIRS)}

    # Inbound references by path and by class_name.
    by_class = {v["class_name"]: p for p, v in scripts.items() if v["class_name"]}
    inbound = defaultdict(set)
    for p, t in texts.items():
        for s in set(RES_ANY_RE.findall(t)):
            target = s[len("res://"):]
            if target != p:
                inbound[target].add(p)
    for cls, p in by_class.items():
        for q, n in word_count(texts, cls).items():
            if q != p:
                inbound[p].add(q)
    entry = set([settings["main_scene"][6:]] + [v[6:] for v in settings["autoloads"].values()])

    # Orphans: game scripts/scenes no other file reaches (tests and tools are entry points).
    orphan_scripts = [p for p in scripts if p.startswith("scripts/") and p not in entry
                      and not (inbound[p] - {p + ".uid"})]
    orphan_scenes = [p for p in scenes if p not in entry and not inbound[p]]
    test_only = [p for p in scripts if p.startswith("scripts/") and inbound[p]
                 and all(q.startswith(("tests/", "tools/")) for q in inbound[p])]

    # Preload graph (compile-time) and class-use graph among game scripts.
    preload_graph = {p: [x[6:] for x in v["preloads"] if x[6:].endswith(".gd")] for p, v in scripts.items()
                     if p.startswith("scripts/")}
    preload_cycles = sccs(preload_graph)
    class_graph = defaultdict(list)
    game_scripts = [p for p in scripts if p.startswith("scripts/")]
    for cls, p in by_class.items():
        if not p.startswith("scripts/"):
            continue
        for q in word_count({k: texts[k] for k in game_scripts}, cls):
            if q != p:
                class_graph[q].append(p)
    class_cycles = sccs(class_graph)

    # Dead-code candidates: a function name that appears exactly once in all
    # text (its own definition), excluding engine callbacks.
    engine = {"_ready", "_process", "_physics_process", "_input", "_unhandled_input", "_gui_input",
              "_init", "_notification", "_draw", "_enter_tree", "_exit_tree", "_initialize", "_finalize",
              "_get_drag_data", "_can_drop_data", "_drop_data", "_make_custom_tooltip", "_to_string",
              "_get_minimum_size", "_has_point", "_unhandled_key_input", "_shortcut_input", "_get", "_set",
              "_get_property_list", "_validate_property", "_iter_init", "_iter_next", "_iter_get",
              "_integrate_forces", "_run", "_get_configuration_warnings", "_structured_text_parser"}
    all_blob = "\n".join(texts.values())
    word_freq = defaultdict(int)
    for w in re.findall(r"\b[_A-Za-z]\w*\b", all_blob):
        word_freq[w] += 1
    dead = []
    for p, v in scripts.items():
        if not p.startswith("scripts/"):
            continue
        for f in v["funcs"]:
            if f in engine:
                continue
            if word_freq[f] <= 1:
                dead.append((p, f))

    # Duplicated function bodies (>= 4 statements) across different places.
    seen = defaultdict(list)
    for p in game_scripts:
        for name, body, line in func_bodies(texts[p]):
            if body.count("\n") >= 3:
                seen[body].append("%s:%d %s" % (p, line, name))
    dupes = [locs for locs in seen.values() if len(locs) > 1]

    numbers = sorted(((magic_numbers(texts[p]), p) for p in game_scripts), reverse=True)

    # Content.
    card_list = cards()
    for c in card_list:
        hits = string_hits(game_texts, c["id"], ("resources/",))
        c["behaviour"] = {p: ln[:6] for p, ln in hits.items()}
        c["tests"] = sorted(string_hits({p: t for p, t in texts.items() if p.startswith("tests/")}, c["id"]))
    item_list = items()
    for it in item_list:
        keys = [it["name"]] + ([it["special_id"]] if it["special_id"] else []) + [it["id"]]
        beh = {}
        for k in keys:
            for p, ln in string_hits(game_texts, k).items():
                beh.setdefault(p, []).extend(ln[:4])
        it["behaviour"] = beh
        it["tests"] = sorted({p for k in keys for p in string_hits({q: t for q, t in texts.items() if q.startswith("tests/")}, k)})
    enemy_list = enemies(texts)
    passive_list = passives()
    for ps in passive_list:
        ps["behaviour"] = {p: ln[:4] for p, ln in string_hits(game_texts, ps["id"]).items()}
        ps["tests"] = sorted(string_hits({p: t for p, t in texts.items() if p.startswith("tests/")}, ps["id"]))
    debuffs = enum_members(texts["scripts/effects/debuff.gd"], "DebuffType")
    buffs = enum_members(texts["scripts/effects/buff.gd"], "BuffType")
    status = []
    for kind, names in (("Debuff", debuffs), ("Buff", buffs)):
        for n in names:
            refs = word_count(game_texts, "%sType.%s" % (kind, n))
            status.append({"kind": kind, "name": n, "refs": refs,
                           "retired": "retired" in texts["scripts/effects/%s.gd" % kind.lower()].split(n)[1].split("\n")[0]})
    chars = re.findall(r"static func create_(\w+)\(\) -> CharacterData", texts["scripts/character/character_data.gd"])
    summons = [p for p in game_scripts if re.search(r"summon", p)]

    data = {
        "settings": settings, "scripts": scripts, "scenes": scenes,
        "tres_other": {p: v for p, v in tres.items() if not p.startswith(("data/cards", "data/items"))},
        "inbound": {k: sorted(v) for k, v in inbound.items()},
        "orphan_scripts": orphan_scripts, "orphan_scenes": orphan_scenes, "test_only_scripts": test_only,
        "preload_cycles": preload_cycles, "class_cycles": class_cycles,
        "dead_candidates": dead, "duplicate_bodies": dupes, "magic_numbers": numbers[:25],
        "cards": card_list, "items": item_list, "enemies": enemy_list, "passives": passive_list,
        "status": status, "characters": chars, "summons": summons,
    }
    if args.json:
        with open(args.json, "w") as fh:
            json.dump(data, fh, indent=1, default=list)
    if args.md:
        write_md(args.md, data)
    print("scripts %d, scenes %d, cards %d, items %d, enemies %d, passives %d, status %d, dead %d, dupes %d" % (
        len(scripts), len(scenes), len(card_list), len(item_list), len(enemy_list), len(passive_list),
        len(status), len(dead), len(dupes)))


def esc(s):
    return str(s).replace("|", "\\|").replace("\n", " ")


def short(s, n=90):
    s = esc(s)
    return s if len(s) <= n else s[:n - 1] + "…"


def where(beh, n=4):
    keys = sorted(beh, key=lambda p: (not p.startswith("scripts/cards"), p))
    parts = []
    for p in keys[:n]:
        lines = beh[p]
        parts.append("`%s`%s" % (p.replace("scripts/", ""), (":" + ",".join(map(str, lines[:3]))) if isinstance(lines, list) and lines else ""))
    if len(keys) > n:
        parts.append("+%d more" % (len(keys) - n))
    return "; ".join(parts) or "—"


def write_md(path, d):
    L = []
    w = L.append
    s = d["scripts"]
    game = [p for p in s if p.startswith("scripts/")]
    w("# Inventory — generated map (Phase 0)\n")
    w("Generated by `python3 tools/audit/inventory.py --md docs/audit/inventory_generated.md`. "
      "Hand-written analysis lives in `docs/audit/inventory.md`; this file is the raw map it cites.\n")
    w("## Totals\n")
    w("| What | Count |\n|---|---|")
    w("| Game scripts (`scripts/`) | %d (%d lines) |" % (len(game), sum(s[p]["lines"] for p in game)))
    w("| Test scripts (`tests/`) | %d |" % len([p for p in s if p.startswith("tests/")]))
    w("| Tool scripts (`tools/`, .gd) | %d |" % len([p for p in s if p.startswith("tools/")]))
    w("| Scenes | %d |" % len(d["scenes"]))
    w("| Cards (`data/cards`) | %d |" % len(d["cards"]))
    w("| Items (`data/items`) | %d |" % len(d["items"]))
    w("| Enemy types | %d |" % len(d["enemies"]))
    w("| Passives (skill trees) | %d |" % len(d["passives"]))
    w("| Status effects (Debuff + Buff types) | %d |" % len(d["status"]))
    w("| Characters | %d (%s) |" % (len(d["characters"]), ", ".join(d["characters"])))
    w("")
    w("## Entry points\n")
    w("- Main scene: `%s`" % d["settings"]["main_scene"])
    for k, v in d["settings"]["autoloads"].items():
        w("- Autoload `%s`: `%s`" % (k, v))
    w("")
    w("## Scripts (game)\n")
    w("| Script | class_name | extends | lines | funcs | referenced by |\n|---|---|---|---|---|---|")
    for p in sorted(game, key=lambda p: -s[p]["lines"]):
        inb = [q for q in d["inbound"].get(p, []) if not q.endswith(".uid")]
        w("| `%s` | %s | %s | %d | %d | %d files |" % (p, s[p]["class_name"] or "—", esc(s[p]["extends"]),
                                                       s[p]["lines"], len(s[p]["funcs"]), len(inb)))
    w("")
    w("## Scenes\n")
    w("| Scene | ext_resources | instanced/loaded by |\n|---|---|---|")
    for p, v in sorted(d["scenes"].items()):
        inb = [q for q in d["inbound"].get(p, []) if not q.endswith(".uid")]
        w("| `%s` | %d | %s |" % (p, len(v["ext"]), ", ".join("`%s`" % q for q in inb[:4]) + (" +%d" % (len(inb) - 4) if len(inb) > 4 else "") or "—"))
    w("")
    w("## Other resources (`.tres` outside data/)\n")
    for p in sorted(d["tres_other"]):
        w("- `%s`" % p)
    w("")
    w("## Orphans and reach\n")
    w("- Game scripts no other file references: %s" % (", ".join("`%s`" % p for p in d["orphan_scripts"]) or "none"))
    w("- Scenes no other file references: %s" % (", ".join("`%s`" % p for p in d["orphan_scenes"]) or "none"))
    w("- Game scripts reached only from tests/tools: %s" % (", ".join("`%s`" % p for p in d["test_only_scripts"]) or "none"))
    w("")
    w("## Cycles\n")
    w("- Preload cycles (compile-time): %s" % ("; ".join(" → ".join(c) for c in d["preload_cycles"]) or "none"))
    w("- class_name reference cycles among game scripts (strongly connected groups; normal in GDScript, but they mark tangled ownership):")
    for c in sorted(d["class_cycles"], key=len, reverse=True):
        w("  - %d scripts: %s" % (len(c), ", ".join("`%s`" % x.replace("scripts/", "") for x in c)))
    w("")
    w("## Dead-code candidates (heuristic)\n")
    w("A function whose name appears nowhere in the repo but its own definition (scripts, scenes, resources, tests, tools). "
      "A name built at run time (`call(\"_x_\" + id)`) would hide a caller; each is checked by hand before removal.\n")
    for p, f in d["dead_candidates"]:
        w("- `%s` `%s()`" % (p, f))
    w("")
    w("## Duplicated function bodies (4+ statements)\n")
    for locs in d["duplicate_bodies"]:
        w("- " + " = ".join("`%s`" % x for x in locs))
    w("")
    w("## Bare numbers in logic (top 25 files)\n")
    w("Numeric literals other than 0/±1/2/0.5 outside `const` lines, colours and vectors — a rough measure of hard-coded tuning.\n")
    w("| File | count |\n|---|---|")
    for n, p in d["magic_numbers"]:
        w("| `%s` | %d |" % (p, n))
    w("")
    w("## Cards\n")
    w("Defined in `data/cards/<id>.tres` (data) with behaviour in the code that names the id.\n")
    w("| id | name | type | tempo | mana | behaviour (file:lines naming the id) | tests |\n|---|---|---|---|---|---|---|")
    for c in d["cards"]:
        w("| `%s` | %s | %s | %s | %s | %s | %d |" % (c["id"], esc(c["name"]), c["type"], c["tempo"], c["mana"],
                                                    where(c["behaviour"]), len(c["tests"])))
    w("")
    w("## Items\n")
    w("Defined in `data/items/<id>.tres`. Behaviour is mostly data fields read by shared code (the `fields` column); "
      "code that names the item itself is listed too.\n")
    w("| id | name | data fields | code naming it | tests |\n|---|---|---|---|---|")
    for it in d["items"]:
        w("| `%s` | %s | %s | %s | %d |" % (it["id"], esc(it["name"]), short(", ".join(it["fields"]), 80),
                                          where(it["behaviour"], 3), len(it["tests"])))
    w("")
    w("## Enemies\n")
    w("Base numbers in `scripts/battle/enemy_defs.gd`; actions, choosers and executors in `scripts/battle/enemy.gd`.\n")
    w("| EnemyType | name | tier | chooser | other game files naming it | tests |\n|---|---|---|---|---|---|")
    for e in d["enemies"]:
        files = [p for p in e["refs"] if p not in ("scripts/battle/enemy.gd", "scripts/battle/enemy_defs.gd")]
        w("| %s | %s%s | %s | %s | %s | %d |" % (e["enum"], esc(e["name"]), " (mock-up)" if e["mockup"] else "", e["tier"],
                                               e["chooser"].replace("chosen_action = ", "inline") or "—",
                                               ", ".join("`%s`" % p.replace("scripts/", "") for p in files[:4]) + (" +%d" % (len(files) - 4) if len(files) > 4 else "") or "—",
                                               len(e["tests"])))
    w("")
    w("## Characters\n")
    w("Factories in `scripts/character/character_data.gd` (`create_<name>`): %s.\n" % ", ".join(d["characters"]))
    w("## Summons\n")
    for p in d["summons"]:
        w("- `%s` (%s)" % (p, d["scripts"][p]["class_name"] or "no class_name"))
    w("")
    w("## Passives\n")
    w("Rows in `scripts/progression/skill_tree_data.gd`; ids from `docs/PASSIVE_REFERENCE.md`.\n")
    w("| id | character | level | behaviour | tests |\n|---|---|---|---|---|")
    for ps in d["passives"]:
        w("| `%s` | %s | %d | %s | %d |" % (ps["id"], ps["character"], ps["level"], where(ps["behaviour"], 3), len(ps["tests"])))
    w("")
    w("## Status effects\n")
    w("| Type | name | retired | game files naming it |\n|---|---|---|---|")
    for st in d["status"]:
        w("| %s | %s | %s | %d |" % (st["kind"], st["name"], "yes" if st["retired"] else "", len(st["refs"])))
    with open(path, "w") as fh:
        fh.write("\n".join(L) + "\n")


if __name__ == "__main__":
    main()
