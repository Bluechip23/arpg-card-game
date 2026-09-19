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
    # Field (World 1, grassland pack): plain grass, smooth dirt for trails,
    # the cobbled cliff face for walls / cliffs.
    "floor_grass_field":     ("tileset_grassland/ground_grasss.png", [(160, 179, 90), (131, 159, 83)], 18),
    "floor_dirt_field":      ("tileset_grassland/ground_grasss.png", [(180, 124, 67), (153, 99, 63)], 14),
    "wall_field":            ("tileset_grassland/ground_grasss.png", [(141, 84, 60), (136, 81, 58)], 12),
    # Greenwood (forest pack): same split.
    "floor_grass_forest":    ("tileset_forest/Ground_grass.png", [(122, 173, 85), (100, 155, 81)], 18),
    "floor_dirt_forest":     ("tileset_forest/Ground_grass.png", [(150, 126, 93), (131, 110, 85)], 16),
    "wall_forest":           ("tileset_forest/Ground_grass.png", [(85, 73, 61), (78, 65, 57), (92, 84, 65)], 12),
    # Caves.
    "floor_cave":            ("tileset_cave/ground_source.png", [(22, 16, 18)], 12),
    "wall_cave":             ("tileset_cave/ground_source.png", [(73, 52, 50)], 16),
    "floor_glowing_cave":    ("tileset_glowing_cave/Ground.png", [(19, 15, 21)], 10),
    "wall_glowing_cave":     ("tileset_glowing_cave/Ground.png", [(56, 54, 75)], 14),
    # Barrow land (World 5, undead pack).
    "floor_undead":          ("tileset_undead_land/Ground_rocks.png", [(109, 113, 105)], 14),
    "floor_undead_sand":     ("tileset_undead_land/Ground_rocks.png", [(152, 147, 126)], 16),
    "wall_undead":           ("tileset_undead_land/Ground_rocks.png", [(34, 41, 49)], 16),
    # Amber Wastes (World 2, desert pack): dry scrub floor, sand trails, the
    # dark sandstone cliff for walls.
    "floor_desert":          ("tileset_desert/Ground_grass.png", [(175, 160, 70), (152, 145, 62)], 16),
    "floor_desert_sand":     ("tileset_desert/Ground_grass.png", [(210, 178, 104), (189, 155, 96)], 18),
    "wall_desert":           ("tileset_desert/Ground_grass.png", [(103, 55, 35), (107, 70, 38)], 14),
    # Hell (World 4, cursed land pack).
    "floor_cursed":          ("tileset_cursed_land/Ground.png", [(156, 96, 87)], 14),
    "floor_cursed_dark":     ("tileset_cursed_land/Ground.png", [(116, 49, 46)], 14),
    "wall_cursed":           ("tileset_cursed_land/Ground.png", [(132, 62, 55), (116, 49, 46)], 14),
}

# Water: the packs draw water as a flat colour under a semi-transparent foam
# overlay (`water_detilazation.png`), so a water sheet is composed: the
# pack's water colour, sampled from its coast tiles, with foam crops on top.
# name -> (coast sheet, foam sheet)
WATER = {
    "water_field":   ("tileset_grassland/Water_coasts.png", "tileset_grassland/water_detilazation.png"),
    "water_forest":  ("tileset_forest/Water_coasts.png", "tileset_forest/water_detilazation.png"),
    "water_cave":    ("tileset_cave/water_n_lava_coasts_source.png", "tileset_cave/water_detilazation_source.png"),
    "water_undead":  ("tileset_undead_land/Water_coasts.png", "tileset_undead_land/water_detilazation.png"),
    "water_cursed":  ("tileset_cursed_land/Water_coasts.png", "tileset_cursed_land/water_detilazation.png"),
    "water_desert":  ("tileset_desert/Water_coasts.png", "tileset_desert/water_detilazation.png"),
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


def water_colour(foam_sheet):
    """The water body under a pack's foam overlay: the foam is a lighter tint
    of it, so the mean foam colour darkened reads as the still water."""
    img = Image.open(os.path.join(SRC, foam_sheet)).convert("RGBA")
    px = img.load()
    acc = [0, 0, 0]
    n = 0
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a > 0:
                acc[0] += r; acc[1] += g; acc[2] += b
                n += 1
    if n == 0:
        return (40, 70, 110)
    return tuple(int(c / n * 0.5) for c in acc)


# Overlay-only grounds: the winter pack draws no solid snow tile — Snow.png
# is drifts and sparkle to scatter over a flat snow colour, Ice.png a
# semi-transparent crack overlay for frozen water. Composed the same way as
# the water sheets: a flat base colour with overlay crops on top.
# name -> (overlay sheet, base colour, crop coverage window, overlay alpha,
#          max fraction of dark texels — the ice sheet's big dark crack-stars
#          get sliced by a 32px window, so windows are kept to the fine
#          crack lattice with at most a sliver of a star)
OVERLAY_GROUNDS = {
    "floor_winter": ("tileset_winter/Snow.png", (232, 238, 242), (0.0, 0.25), 1.0, 1.0),
    "water_winter": ("tileset_winter/Ice.png", (150, 196, 214), (0.3, 1.01), 1.0, 0.06),
}


def build_overlay_ground(name, overlay_sheet, base, coverage, alpha, max_dark):
    overlay = Image.open(os.path.join(SRC, overlay_sheet)).convert("RGBA")
    rng = random.Random(name)
    out = Image.new("RGBA", (N * GRID, N * GRID), base + (255,))
    px = overlay.load()
    windows = []
    for y in range(0, overlay.height - N + 1, 8):
        for x in range(0, overlay.width - N + 1, 8):
            cov = sum(1 for j in range(0, N, 4) for i in range(0, N, 4) if px[x + i, y + j][3] > 0) / 64.0
            if not (coverage[0] <= cov < coverage[1]):
                continue
            if max_dark < 1.0:
                dark = 0
                for j in range(0, N, 2):
                    for i in range(0, N, 2):
                        r, g, b, a = px[x + i, y + j]
                        if a > 0 and (r + g + b) / 3 < 165:
                            dark += 1
                if dark / 256.0 > max_dark:
                    continue
            windows.append((x, y))
    rng.shuffle(windows)
    for v in range(GRID * GRID):
        if not windows:
            break
        x, y = windows[v % len(windows)]
        crop = overlay.crop((x, y, x + N, y + N))
        if alpha < 1.0:
            r, g, b, a = crop.split()
            crop = Image.merge("RGBA", (r, g, b, a.point(lambda q: int(q * alpha))))
        out.alpha_composite(crop, ((v % GRID) * N, (v // GRID) * N))
    out.save(os.path.join(OUT, name + ".png"))
    print(f"{name:22s} <- {overlay_sheet:44s} base {base}, {len(windows)} overlay windows")


def build_water(name, coast_sheet, foam_sheet):
    base = water_colour(foam_sheet)
    foam = Image.open(os.path.join(SRC, foam_sheet)).convert("RGBA")
    rng = random.Random(name)
    out = Image.new("RGBA", (N * GRID, N * GRID), base + (255,))
    # Foam crops: 32px windows with some but not too much foam, tinted toward
    # the water so they read as ripples rather than white streaks.
    windows = []
    px = foam.load()
    for y in range(0, foam.height - N + 1, 8):
        for x in range(0, foam.width - N + 1, 8):
            cov = sum(1 for j in range(0, N, 4) for i in range(0, N, 4) if px[x + i, y + j][3] > 0) / 64.0
            if 0.04 < cov < 0.35:
                windows.append((x, y))
    rng.shuffle(windows)
    for v in range(GRID * GRID):
        if not windows:
            break
        x, y = windows[v % len(windows)]
        crop = foam.crop((x, y, x + N, y + N))
        # Soften: half-alpha foam over the water colour.
        r, g, b, a = crop.split()
        a = a.point(lambda v: int(v * 0.55))
        crop = Image.merge("RGBA", (r, g, b, a))
        out.alpha_composite(crop, ((v % GRID) * N, (v // GRID) * N))
    out.save(os.path.join(OUT, name + ".png"))
    print(f"{name:22s} <- {coast_sheet:44s} water {base}, {len(windows)} foam windows")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, cfg in THEMES.items():
        build(name, *cfg)
    for name, cfg in WATER.items():
        build_water(name, *cfg)
    for name, cfg in OVERLAY_GROUNDS.items():
        build_overlay_ground(name, *cfg)
