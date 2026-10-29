#!/usr/bin/env python3
"""Cut the designer's ground boards (grass, dirt, water, wall and cliff
panels painted on black) into the ground sheets DungeonManager lays.

A ground sheet is a 4x4 grid of tile variants, like the pack fills
(assets/textures/craftpix/floor_*.png), but at 64 texels a tile (256 px a
sheet) — twice the packs' 32, the fineness of the designer's creature and
prop art. Each square panel becomes one sheet: an inset square (clear of
the panel's ragged painted border) shrunk to 256 px with a sharp (Lanczos)
filter, then made to tile seamlessly: the panel blended into a copy of
itself rolled by half a sheet, so the wrap seams sit inside the copy and the
painting stays untouched in the middle. DungeonManager lays these sheets
continuously (a tile takes the variant its position in a 4x4 block calls
for), so the painting runs unbroken across the ground and repeats every
four tiles.

The cliff panel is a strip of grass hanging over a rock face: it becomes the
cliff strip (6 columns x 2 rows of 32 px: a left end, four middles and a
right end; the fringe row over the base row), as the pack strips are cut by
tools/extract_craftpix_cliffs.py at 16 px. Its black ground is cleared
(the black reached from the strip's edge).

Output: assets/textures/ground/<biome>_<name>.png
Run: python3 tools/cut_ground_boards.py
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/%s"
OUT = "assets/textures/ground/%s.png"
TILE = 64           # texels a tile
SHEET = TILE * 4    # a 4x4 sheet of tile variants
BLEND = 0.30        # share of the sheet, from each edge, over which the
                    # rolled copy takes over (the seamless wrap)
BLACK = 12          # brightness at or below this is the board's black

BOARDS = {
    # 2026-10-29: the Greenwood's ground (forest_ground_board.webp, on black:
    # lush grass, grass worn to dirt, cobbled dirt; water, a mossy cobble
    # wall; a cliff strip and a grass-topped cliff block). Boxes are inset
    # squares inside each panel's painted border.
    "forest_ground_board.webp": {
        "sheets": {
            "forest_grass": (45, 45, 455, 455),       # the forest floor
            "forest_grass_high": (540, 45, 950, 455), # raised ground: worn grass, like the cliff block's top
            "forest_dirt": (1062, 45, 1472, 455),     # trails
            "forest_water": (45, 520, 465, 940),
            "forest_wall": (535, 515, 965, 945),      # wall stone (the forest's edges are tree lines)
        },
        "strips": {
            "forest_cliff": (1052, 488, 1510, 622),   # grass over rock; the block below is the same cliff
        },
    },
    # 2026-10-29: the caves' ground (cave_ground_board.webp, on black: a cliff
    # block hanging in stalactites, earth floor, earth floor glittering with
    # blue crystals; a rock wall, dark water, a rock wall hung with glowing
    # crystals). Every other cave is a crystal cave (DungeonManager.cave_glows).
    "cave_ground_board.webp": {
        "sheets": {
            "cave_floor": (570, 45, 965, 440),
            "cave_floor_glow": (1075, 45, 1470, 440),
            "cave_wall": (40, 510, 470, 940),
            "cave_water": (555, 515, 980, 940),
            "cave_wall_glow": (1065, 510, 1495, 940),
        },
        # The cliff block's deep right side, where the face hangs its full
        # depth (it shallows toward the corner on the left): one tile of
        # face, its lip over its hanging rock, widened with mirrored copies.
        "faces": {
            "cave_cliff": (250, 88, 488, 416),
        },
    },
    # 2026-10-29: the Amber Wastes' ground (desert_ground_board.webp, on dark
    # grey: sand, a cliff block, water, a sand-topped cliff strip; olive
    # scrub, the cliff strip's left end / middle / right end and its corner
    # columns, and six shoreline tiles). The scrub is the floor, the sand
    # the tracks through it and the tops of raised ground, the cliff block
    # the wall stone; the strip is built from its own end pieces.
    "desert_ground_board.webp": {
        "black": 40,
        "sheets": {
            "desert_floor": (45, 530, 365, 850),
            "desert_sand": (45, 105, 355, 415),
            "desert_wall": (420, 100, 730, 410),
            "desert_water": (800, 100, 1105, 405),
        },
        "strip_parts": {
            "desert_cliff": [(418, 494, 563, 654), (577, 491, 861, 659), (872, 496, 1002, 665)],
        },
    },
}


def _shrink(img, size):
    return img.convert("RGB").resize(size, Image.LANCZOS)


def seamless(img):
    """`img` (square RGB) made to tile: blended into itself rolled by half,
    with the copy taking over toward the edges."""
    a = np.asarray(img).astype(np.float32)
    n = a.shape[0]
    rolled = np.roll(np.roll(a, n // 2, axis=0), n // 2, axis=1)
    t = np.arange(n, dtype=np.float32)
    edge = np.minimum(t, n - 1 - t) / (n * BLEND)        # 0 at the edge, 1 past the band
    w1 = np.clip(edge, 0.0, 1.0)
    w1 = w1 * w1 * (3 - 2 * w1)                           # smoothstep
    w = np.minimum.outer(w1, w1)[..., None]               # 1 in the middle, 0 at the edges
    out = a * w + rolled * (1 - w)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def cut_sheet(board, box):
    return seamless(_shrink(board.crop(box), (SHEET, SHEET))).convert("RGBA")


def cut_strip(board, box):
    """The cliff strip: 6 columns x 2 rows of TILE/2 cells."""
    cell = TILE // 2
    rgb = np.asarray(board.crop(box).convert("RGB")).astype(np.float32)
    black = rgb.max(axis=2) <= BLACK
    lab, _ = nd.label(black)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    solid = ~np.isin(lab, list(edge))
    ys, xs = np.nonzero(solid)
    rgb = rgb[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    solid = solid[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    img = Image.fromarray(np.dstack([rgb, solid * 255.0]).astype(np.uint8), "RGBA")
    h = cell * 2
    w = max(cell * 6, round(img.width * h / img.height))
    small = np.asarray(img.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")).copy()
    small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
    out = Image.new("RGBA", (cell * 6, h))
    # Ends from the strip's own ends; four middles spread across the rest.
    starts = [0] + [round(cell + i * (w - 3 * cell) / 3) for i in range(4)] + [w - cell]
    for c, x0 in enumerate(starts):
        out.paste(Image.fromarray(small[:, x0:x0 + cell], "RGBA"), (c * cell, 0))
    return out


# --- The ground atlas ---------------------------------------------------
# DungeonManager's autotiled ground (its Terrain enum: GRASS, DIRT, WATER,
# PIT, HIGH) prebuilt for a biome whose ground is the designer's: one row
# per terrain and tile variant (terrain * 16 + variant, the variant being the
# tile's place in its 4x4 block: column + 4 * row), one column per edge mask
# (the 4-bit N/E/S/W mask of neighbours of another terrain; column 0 is the
# plain tile). The edges are painted, not ruled: grass creeps over a dirt
# trail's edge and hangs over a pond's, raggedly, the raggedness running on
# from tile to tile; raised ground darkens toward a drop. (The pack biomes
# keep their runtime atlas with its flat palette bands.)
ATLASES = {
    # biome: {terrain sheet names}
    "forest": {"grass": "forest_grass", "dirt": "forest_dirt", "water": "forest_water",
               "high": "forest_grass_high"},
    # Caves: no trail or raised-ground sheet of their own (the floor serves,
    # trodden darker / lit lighter).
    "cave": {"grass": "cave_floor", "water": "cave_water"},
    "cave_glow": {"grass": "cave_floor_glow", "water": "cave_water"},
    "desert": {"grass": "desert_floor", "dirt": "desert_sand", "water": "desert_water",
               "high": "desert_sand"},
}
N_, E_, S_, W_ = 1, 2, 4, 8


def _periodic_noise(period, step, seed):
    """Smooth 1-D noise in 0..1 over `period` px that wraps (so a ragged edge
    runs on across tiles and repeats with the sheet)."""
    rng = np.random.default_rng(seed)
    knots = rng.random(period // step)
    t = np.arange(period) / float(step)
    i0 = np.floor(t).astype(int) % len(knots)
    i1 = (i0 + 1) % len(knots)
    f = t - np.floor(t)
    f = f * f * (3 - 2 * f)
    return knots[i0] * (1 - f) + knots[i1] * f


def _edge_alpha(mask, col, row, lo, hi, feather, seed):
    """Alpha (TILE x TILE, 0..1) of a ragged band `lo`..`hi` px deep along
    each side `mask` marks, for the tile at (col, row) of its 4x4 block."""
    n = TILE
    noise_x = _periodic_noise(SHEET, 12, seed) * 0.7 + _periodic_noise(SHEET, 5, seed + 1) * 0.3
    noise_z = _periodic_noise(SHEET, 12, seed + 2) * 0.7 + _periodic_noise(SHEET, 5, seed + 3) * 0.3
    u = noise_x[col * n:(col + 1) * n]       # along a horizontal side
    v = noise_z[row * n:(row + 1) * n]       # along a vertical side
    py, px = np.mgrid[0:n, 0:n].astype(np.float32)
    alpha = np.zeros((n, n), np.float32)
    for side, dist, along in ((N_, py, u[None, :]), (S_, n - 1 - py, u[None, :]),
                              (W_, px, v[:, None]), (E_, n - 1 - px, v[:, None])):
        if mask & side:
            depth = lo + (hi - lo) * along
            alpha = np.maximum(alpha, np.clip((depth - dist) / feather + 0.5, 0, 1))
    return alpha


def build_atlas(biome, names):
    sheets = {k: np.asarray(Image.open(OUT % v).convert("RGB")).astype(np.float32)
              for k, v in names.items()}
    grass = sheets["grass"]
    pit = grass * 0.45
    dirt = sheets.get("dirt", grass * 0.82)
    high = sheets.get("high", np.clip(grass * 1.14, 0, 255))
    terrains = [grass, dirt, sheets["water"], pit, high]
    n = TILE
    atlas = np.zeros((len(terrains) * 16 * n, 16 * n, 3), np.float32)
    for t, sheet in enumerate(terrains):
        for var in range(16):
            col, row = var % 4, var // 4
            base = sheet[row * n:(row + 1) * n, col * n:(col + 1) * n]
            over = grass[row * n:(row + 1) * n, col * n:(col + 1) * n]
            for mask in range(16):
                tile = base.copy()
                if mask and t == 1:      # dirt: grass creeps over the trail's edge
                    a = _edge_alpha(mask, col, row, 5, 15, 3.0, 11)[..., None]
                    tile = tile * (1 - a) + over * a
                elif mask and t == 2:    # water: a wet shadow, then grass hanging over the bank
                    wet = _edge_alpha(mask, col, row, 9, 18, 4.0, 23)[..., None]
                    tile = tile * (1 - 0.45 * wet)
                    a = _edge_alpha(mask, col, row, 4, 12, 2.5, 23)[..., None]
                    tile = tile * (1 - a) + over * a
                elif mask and t == 3:    # pit: a grass rim over the dark
                    a = _edge_alpha(mask, col, row, 3, 9, 2.5, 31)[..., None]
                    tile = tile * (1 - a) + over * a
                elif mask and t == 4:    # raised ground: darker toward the drop
                    a = _edge_alpha(mask, col, row, 4, 10, 6.0, 41)[..., None]
                    tile = tile * (1 - 0.35 * a)
                y0 = (t * 16 + var) * n
                atlas[y0:y0 + n, mask * n:(mask + 1) * n] = tile
    out = Image.fromarray(np.clip(atlas, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    out.save(OUT % ("%s_atlas" % biome))
    print("%s_atlas: %dx%d" % (biome, out.width, out.height))


def cut_face(board, box):
    """A cliff strip from a stretch of a cliff block's face: shrunk to the
    strip's height (its lip over its face, one tile) and laid out with
    mirrored copies to give the strip its width; the ends are the first
    piece and its mirror."""
    cell = TILE // 2
    rgb = np.asarray(board.crop(box).convert("RGB")).astype(np.float32)
    black = rgb.max(axis=2) <= BLACK
    lab, _ = nd.label(black)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    solid = ~np.isin(lab, list(edge))
    img = Image.fromarray(np.dstack([rgb, solid * 255.0]).astype(np.uint8), "RGBA")
    h = cell * 2
    w = round(img.width * h / img.height)
    small = np.asarray(img.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")).copy()
    small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
    wide = np.concatenate([small, small[:, ::-1], small, small[:, ::-1]], axis=1)
    out = Image.new("RGBA", (cell * 6, h))
    out.paste(Image.fromarray(wide[:, :cell], "RGBA"), (0, 0))                     # L
    for i in range(4):                                                                # middles, spread
        x0 = cell + round(i * (wide.shape[1] - 3 * cell) / 4)
        out.paste(Image.fromarray(wide[:, x0:x0 + cell], "RGBA"), ((1 + i) * cell, 0))
    out.paste(Image.fromarray(wide[:, :cell][:, ::-1].copy(), "RGBA"), (5 * cell, 0))  # R: L mirrored
    return out


def cut_strip_parts(board, boxes, black_at):
    """A cliff strip from its painted pieces (left end, middle, right end),
    each lifted off the board, set side by side on their bottoms and then
    cut like a strip drawn whole (cut_strip)."""
    parts = []
    for box in boxes:
        rgb = np.asarray(board.crop(box).convert("RGB")).astype(np.float32)
        dark = rgb.max(axis=2) <= black_at
        lab, _ = nd.label(dark)
        edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        solid = ~np.isin(lab, list(edge))
        ys, xs = np.nonzero(solid)
        rgb = rgb[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        solid = solid[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        parts.append(np.dstack([rgb, solid * 255.0]))
    h = max(p.shape[0] for p in parts)
    row = np.zeros((h, sum(p.shape[1] for p in parts), 4), np.float32)
    x = 0
    for p in parts:
        row[h - p.shape[0]:, x:x + p.shape[1]] = p
        x += p.shape[1]
    img = Image.fromarray(row.astype(np.uint8), "RGBA")
    cell = TILE // 2
    hh = cell * 2
    w = max(cell * 6, round(img.width * hh / img.height))
    small = np.asarray(img.convert("RGBa").resize((w, hh), Image.LANCZOS).convert("RGBA")).copy()
    small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
    out = Image.new("RGBA", (cell * 6, hh))
    starts = [0] + [round(cell + i * (w - 3 * cell) / 3) for i in range(4)] + [w - cell]
    for c, x0 in enumerate(starts):
        out.paste(Image.fromarray(small[:, x0:x0 + cell], "RGBA"), (c * cell, 0))
    return out


def main():
    os.makedirs(os.path.dirname(OUT % "x"), exist_ok=True)
    for src, cfg in BOARDS.items():
        board = Image.open(SRC % src)
        for name, box in cfg.get("sheets", {}).items():
            cut_sheet(board, box).save(OUT % name)
            print("%s: %dx%d sheet" % (name, SHEET, SHEET))
        for name, box in cfg.get("faces", {}).items():
            img = cut_face(board, box)
            img.save(OUT % name)
            print("%s: %dx%d strip" % (name, img.width, img.height))
        for name, boxes in cfg.get("strip_parts", {}).items():
            img = cut_strip_parts(board, boxes, cfg.get("black", BLACK))
            img.save(OUT % name)
            print("%s: %dx%d strip" % (name, img.width, img.height))
        for name, box in cfg.get("strips", {}).items():
            img = cut_strip(board, box)
            img.save(OUT % name)
            print("%s: %dx%d strip" % (name, img.width, img.height))
    for biome, names in ATLASES.items():
        build_atlas(biome, names)


if __name__ == "__main__":
    main()
