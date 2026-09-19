#!/usr/bin/env python3
"""Cut seamless ground fills out of the Craftpix top-down tilesets.

The purchased tilesets (assets/sprites/craftpix/tileset_*/) are 16px autotile
sets: mostly edge/transition pieces, plus a handful of solid "inner" fill
tiles per surface. The terrain renderer (dungeon_manager._add_multimesh)
wants a 128x128 sheet of 4x4 seamless 32px variants, sampled triplanar at one
variant per world unit with a 4-tile repeat period.

For each theme this finds the sheet's interior 16px tiles (fully opaque, all
four 8px quadrants near the tile's mean colour — so no autotile edge runs
through it — and that mean within `tol` of the theme's fill colour), then
composes sixteen 32px variants as 2x2 arrangements of those tiles. Inner
fill tiles are drawn to abut each other, so the composites and the sheet
repeat cleanly. Deterministic. Pack art is only cropped, never repainted.

    python3 tools/extract_craftpix_tiles.py
"""
import os
import random
from PIL import Image

SRC = "assets/sprites/craftpix"
OUT = "assets/textures/craftpix"
T = 16       # pack tile
N = 32       # sheet variant (one world unit)
GRID = 4
QUAD_TOL = 12.0  # max quadrant-vs-tile mean deviation for an "interior" tile

# name -> (sheet, fill colour (r, g, b), colour tolerance)
# Fill colours are the cluster means reported by the survey in this file's
# history; a tile joins the pool when its mean is within `tol` of them.
THEMES = {
    "floor_grass_field":     ("tileset_grassland/ground_grasss.png", [(160, 179, 90), (131, 159, 83)], 18),
    "floor_dirt_field":      ("tileset_grassland/ground_grasss.png", [(141, 84, 60), (153, 99, 63)], 16),
    "floor_grass_forest":    ("tileset_forest/Ground_grass.png", [(122, 173, 85), (100, 155, 81)], 18),
    "floor_dirt_forest":     ("tileset_forest/Ground_grass.png", [(85, 73, 61), (92, 84, 65)], 14),
    "floor_cave":            ("tileset_cave/ground_source.png", [(22, 16, 18)], 12),
    "wall_cave":             ("tileset_cave/ground_source.png", [(73, 52, 50)], 16),
    "floor_glowing_cave":    ("tileset_glowing_cave/Ground.png", [(19, 15, 21)], 10),
    "floor_undead":          ("tileset_undead_land/Ground_rocks.png", [(109, 113, 105)], 14),
    "floor_undead_sand":     ("tileset_undead_land/Ground_rocks.png", [(152, 147, 126)], 16),
    "floor_cursed":          ("tileset_cursed_land/Ground.png", [(156, 96, 87)], 14),
    "floor_cursed_dark":     ("tileset_cursed_land/Ground.png", [(116, 49, 46)], 14),
}


def tile_mean(px, x, y, w, h):
    sm = [0, 0, 0]
    for j in range(h):
        for i in range(w):
            p = px[x + i, y + j]
            sm[0] += p[0]; sm[1] += p[1]; sm[2] += p[2]
    n = w * h
    return [c / n for c in sm]


def dist(a, b):
    return sum((a[k] - b[k]) ** 2 for k in range(3)) ** 0.5


def interior_tiles(img):
    """Yield (x, y, mean) for every fully opaque 16px tile with no edge inside."""
    px = img.load()
    w, h = img.size
    for y in range(0, h - T + 1, T):
        for x in range(0, w - T + 1, T):
            opaque = True
            for j in range(T):
                for i in range(T):
                    if px[x + i, y + j][3] < 255:
                        opaque = False
                        break
                if not opaque:
                    break
            if not opaque:
                continue
            m = tile_mean(px, x, y, T, T)
            worst = 0.0
            for qy in (0, T // 2):
                for qx in (0, T // 2):
                    worst = max(worst, dist(tile_mean(px, x + qx, y + qy, T // 2, T // 2), m))
            if worst <= QUAD_TOL:
                yield x, y, m


def build(name, sheet, fills, tol):
    img = Image.open(os.path.join(SRC, sheet)).convert("RGBA")
    pool = []
    seen = set()
    for x, y, m in interior_tiles(img):
        if min(dist(m, f) for f in fills) > tol:
            continue
        tile = img.crop((x, y, x + T, y + T))
        key = tile.tobytes()
        if key in seen:
            continue
        seen.add(key)
        pool.append(tile)
    if not pool:
        raise SystemExit(f"{name}: no interior tiles near {fills} in {sheet}")
    rng = random.Random(name)
    out = Image.new("RGBA", (N * GRID, N * GRID))
    # Every pool tile appears at least once; the rest is a seeded shuffle.
    order = list(range(len(pool)))
    slots = GRID * GRID * 4
    picks = []
    while len(picks) < slots:
        rng.shuffle(order)
        picks.extend(order)
    picks = picks[:slots]
    k = 0
    for v in range(GRID * GRID):
        ox, oy = (v % GRID) * N, (v // GRID) * N
        for dy in (0, T):
            for dx in (0, T):
                out.paste(pool[picks[k]], (ox + dx, oy + dy))
                k += 1
    out.save(os.path.join(OUT, name + ".png"))
    print(f"{name:22s} <- {sheet:44s} {len(pool):2d} distinct interior tiles")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, cfg in THEMES.items():
        build(name, *cfg)
