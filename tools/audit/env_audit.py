#!/usr/bin/env python3
"""Environment audit, step 2 (Phase 3): compare what blocks movement with
what is drawn, and check every map's reachability, from the JSON that
tools/audit/env_dump.gd writes.

Findings per map (cells are [x, z] grid coordinates):
  INVISIBLE_BLOCKER  a blocked non-wall cell (obstacle, pit, barricade) with
                     nothing standing on it
  INVISIBLE_WALL     a wall cell beside walkable floor with nothing drawn on it
                     (a wall the player bumps into but cannot see)
  WALK_THROUGH       an obstacle-looking prop (tree, rock, stump, pillar,
                     gravestone, crate...) drawn on a cell the player can walk
                     into
  POCKET             walkable floor the start cannot reach (by the game's own
                     one-level-a-step rule)
  UNREACHABLE_POI    a chest, waypoint, fountain, climbable tree or site
                     entrance no reachable floor touches
  STUCK_SPAWN        an enemy spawn point on a blocked cell, or one whose
                     floor the start cannot reach
  DEAD_END           a corridor 4+ cells long, one cell wide, that ends with
                     nothing at its end (heuristic)
  PLACEHOLDER_ART    a visual drawn from a bare primitive mesh with no texture,
                     or from art outside the pack folders (CLAUDE.md "Art:
                     Packs First")

Run: python3 tools/audit/env_audit.py <dump_dir> [--md OUT.md] [--json OUT.json]
"""
import argparse
import glob
import json
import os
import re
from collections import deque

OBSTACLE_WORDS = re.compile(r"(rock|tree|stump|boulder|pillar|column|statue|grave|headstone|tomb|crate|barrel|"
                            r"fence|ruin|log_|_log|stalag|totem|anvil|cart|wagon|post|cliff|crystal_big|"
                            r"obelisk|well|altar|coffin|throne)", re.I)
COVER_WORDS = re.compile(r"(tuft|flower|fern|berry|pebble|shroom|grass|puddle|leaf|moss|petal|bones|blood|"
                         r"crack|rubble|weed|clover|sprout|daisy|lily|reed|stain|decal)", re.I)
IGNORE_PATH = re.compile(r"(tile_fog|blob_shadow|AutotileGround|GridManager|PlaneMesh|ImmediateMesh|"
                         r"RescueNpc|CloudShadows|Torch|InteractLabel|Label|Waypoint_.*Label)", re.I)
PACK_DIRS = ("res://assets/textures/craftpix", "res://assets/sprites/", "res://assets/textures/props/boards",
             "res://assets/textures/ground", "res://assets/textures/walls", "res://assets/textures/cliffs",
             "res://assets/textures/water", "res://assets/textures/ui")

WALKABLE = set(".~")
DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]


def load_maps(d):
    out = []
    for p in sorted(glob.glob(os.path.join(d, "*.json"))):
        with open(p) as fh:
            m = json.load(fh)
        m["_file"] = os.path.basename(p)
        out.append(m)
    return out


def grid_at(m, x, z):
    if 0 <= z < m["h"] and 0 <= x < m["w"]:
        return m["cells"][z][x]
    return "#"


def reach(m):
    """Walkable cells the start reaches, stepping one elevation level at a
    time (cliff steps are walkable tiles of their own)."""
    sx, sz = m["start"]
    elev = m["elevation"]
    seen = {(sx, sz)}
    q = deque([(sx, sz)])
    while q:
        x, z = q.popleft()
        for dx, dz in DIRS:
            nx, nz = x + dx, z + dz
            if (nx, nz) in seen or grid_at(m, nx, nz) not in WALKABLE:
                continue
            if abs(elev[nz][nx] - elev[z][x]) > 1:
                continue
            seen.add((nx, nz))
            q.append((nx, nz))
    return seen


WALL_ART = re.compile(r"(CliffWalls|PackLedges|SiteBlocks|Walls|Wall_|wall|cliff|ledge|Pit)", re.I)


def classify(v):
    res = v.get("res", "")
    if re.search(r"AutotileGround|GridManager|tile_fog|PlaneMesh", v["path"] + " " + res):
        return "ignore"
    if v.get("painted") and WALL_ART.search(v["path"] + " " + res):
        return "wall_art"
    if IGNORE_PATH.search(v["path"]) or IGNORE_PATH.search(res):
        return "ignore"
    if v.get("height", 0) < 0.05 and not v.get("raised"):
        return "flat"
    if COVER_WORDS.search(res):
        return "cover"
    if OBSTACLE_WORDS.search(res) or OBSTACLE_WORDS.search(v["path"]):
        return "obstacle"
    return "other"


def audit(m):
    f = []
    w, h = m["w"], m["h"]
    drawn = {}        # cell -> set of classes standing there
    obstacle_on = {}  # cell -> example res
    for v in m["visuals"]:
        cls = classify(v)
        if cls in ("ignore", "flat"):
            continue
        if cls == "wall_art":
            cells = v["painted"]
        else:
            cells = v.get("raised") or v["cells"]
            if not v.get("multi") and not v.get("raised") and len(v["cells"]) > 9:
                continue  # a big box with no raised geometry: nothing to place
        # A tall billboard (tree, mesa) stands on its anchor cell but its art
        # spreads over the cells around and behind it on screen: count those
        # as visibly drawn (for "is this wall visible?"), never as where it
        # stands (for "can the player walk through it?").
        hgt = float(v.get("height", 0))
        spread_x = int(round(hgt * 0.35)) if cls != "wall_art" and hgt >= 1.5 else 0
        spread_z = int(round(hgt * 0.5)) if cls != "wall_art" and hgt >= 1.5 else 0
        for c in cells:
            t = (c[0], c[1])
            drawn.setdefault(t, set()).add(cls)
            for dx in range(-spread_x, spread_x + 1):
                for dz in range(-spread_z, 1):
                    drawn.setdefault((c[0] + dx, c[1] + dz), set()).add(cls + "_spread")
            if cls == "obstacle":
                obstacle_on.setdefault(t, v["res"].split("/")[-1] or v["path"])
    # A site (cave mouth, building, door) is drawn by its own art over its
    # footprint; a point of interest by its own node.
    site_cells = set()
    for s in m["sites"]:
        for c in s.get("footprint", []):
            site_cells.add(tuple(c))
        site_cells.add(tuple(s["cell"]))
    for p in m["poi"]:
        x0, z0 = p["cell"]
        r = 1 if p["kind"] == "waypoint" else 0   # a shrine's block is the 3x3 round it
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                site_cells.add((x0 + dx, z0 + dz))
    reached = reach(m)

    for z in range(h):
        for x in range(w):
            ch = grid_at(m, x, z)
            t = (x, z)
            if ch in "OPB" and t not in drawn and t not in site_cells:
                kind = {"O": "obstacle tile", "P": "pit", "B": "barricade"}[ch]
                f.append(("INVISIBLE_BLOCKER", t, "%s with nothing drawn on it" % kind))
            if ch == "#" and t not in drawn and t not in site_cells:
                if any(grid_at(m, x + dx, z + dz) in WALKABLE and (x + dx, z + dz) in reached for dx, dz in DIRS):
                    f.append(("INVISIBLE_WALL", t, "wall beside reachable floor, nothing drawn"))
            if ch in WALKABLE and t in obstacle_on:
                f.append(("WALK_THROUGH", t, "walkable cell under %s" % obstacle_on[t]))

    # Pockets: walkable components the start does not reach.
    seen = set(reached)
    for z in range(h):
        for x in range(w):
            if (x, z) in seen or grid_at(m, x, z) not in WALKABLE:
                continue
            comp = []
            q = deque([(x, z)])
            seen.add((x, z))
            while q:
                cx, cz = q.popleft()
                comp.append((cx, cz))
                for dx, dz in DIRS:
                    n = (cx + dx, cz + dz)
                    if n not in seen and grid_at(m, *n) in WALKABLE \
                            and abs(m["elevation"][n[1]][n[0]] - m["elevation"][cz][cx]) <= 1:
                        seen.add(n)
                        q.append(n)
            if len(comp) >= 2:
                xs = [c[0] for c in comp]
                zs = [c[1] for c in comp]
                f.append(("POCKET", comp[0], "%d walkable cells unreachable from the start (x %d-%d, z %d-%d)" % (
                    len(comp), min(xs), max(xs), min(zs), max(zs))))

    def touches_reach(c):
        x, z = c
        return (x, z) in reached or any((x + dx, z + dz) in reached for dx, dz in DIRS)

    for p in m["poi"]:
        c = tuple(p["cell"])
        if c[0] >= 0 and not touches_reach(c):
            f.append(("UNREACHABLE_POI", c, p["kind"]))
    for s in m["sites"]:
        c = tuple(s["cell"])
        if c[0] >= 0 and not touches_reach(c):
            f.append(("UNREACHABLE_POI", c, "site %s (%s)" % (s["id"], s["kind"])))
    for sp in m.get("spawn_points", []):
        c = tuple(sp)
        if grid_at(m, *c) not in WALKABLE:
            f.append(("STUCK_SPAWN", c, "spawn point on a blocked cell (%s)" % grid_at(m, *c)))
        elif c not in reached:
            f.append(("STUCK_SPAWN", c, "spawn point the start cannot reach (enemy could never path to the player)"))

    # Dead ends: walk back from every 1-neighbour floor cell along a 1-wide corridor.
    poi_cells = {tuple(p["cell"]) for p in m["poi"]} | {tuple(s["cell"]) for s in m["sites"]}
    for (x, z) in reached:
        nbrs = [(x + dx, z + dz) for dx, dz in DIRS if (x + dx, z + dz) in reached]
        if len(nbrs) != 1:
            continue
        length, prev, cur = 1, (x, z), nbrs[0]
        while True:
            nn = [(cur[0] + dx, cur[1] + dz) for dx, dz in DIRS if (cur[0] + dx, cur[1] + dz) in reached and (cur[0] + dx, cur[1] + dz) != prev]
            if len(nn) != 1:
                break
            length += 1
            prev, cur = cur, nn[0]
            if length > 60:
                break
        near_poi = any(abs(px - x) + abs(pz - z) <= 2 for px, pz in poi_cells)
        if length >= 4 and not near_poi:
            f.append(("DEAD_END", (x, z), "1-wide corridor of %d cells ending here with nothing at its end" % length))

    # Art outside the packs / bare primitives.
    flagged = set()
    for v in m["visuals"]:
        res = v.get("res", "")
        cls = classify(v)
        if cls == "ignore":
            continue
        prim = re.match(r"^(BoxMesh|CylinderMesh|PrismMesh|SphereMesh|CapsuleMesh|TorusMesh)\s*$", res.strip())
        tex = re.findall(r"res://\S+", res)
        off_pack = tex and not any(t.startswith(PACK_DIRS) for t in tex)
        if prim or off_pack:
            key = (res, v["path"].split("/")[0])
            if key in flagged:
                continue
            flagged.add(key)
            c = v["cells"][0] if v["cells"] else [-1, -1]
            f.append(("PLACEHOLDER_ART", tuple(c), "%s at %s (%s)" % ("bare %s, no texture" % res.strip() if prim else "art outside the pack folders: " + ", ".join(tex), v["path"], v["cls"])))
    return f


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dump_dir")
    ap.add_argument("--md", default="")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    # "exit" is the door back out of an interior: the same overworld again.
    maps = [m for m in load_maps(a.dump_dir) if m["interior"] != "exit"]
    report = []
    for m in maps:
        fs = audit(m)
        report.append({"map": m["_file"][:-5], "level": m["level"], "interior": m["interior"], "kind": m["kind"],
                       "size": [m["w"], m["h"]], "findings": [{"type": t, "cell": list(c), "note": n} for t, c, n in fs]})
    if a.json:
        with open(a.json, "w") as fh:
            json.dump(report, fh, indent=1)
    for r in report:
        counts = {}
        for x in r["findings"]:
            counts[x["type"]] = counts.get(x["type"], 0) + 1
        print("%-28s %s" % (r["map"], " ".join("%s=%d" % kv for kv in sorted(counts.items())) or "clean"))
    if a.md:
        L = ["| map | type | cell (x, z) | finding |", "|---|---|---|---|"]
        for r in report:
            for x in r["findings"]:
                L.append("| %s | %s | (%d, %d) | %s |" % (r["map"], x["type"], x["cell"][0], x["cell"][1], x["note"].replace("|", "\\|")))
        with open(a.md, "w") as fh:
            fh.write("\n".join(L) + "\n")


if __name__ == "__main__":
    main()
