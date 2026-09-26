#!/usr/bin/env python3
"""Cut cliff-face strips out of the Craftpix top-down tilesets.

Every pack draws its cliffs the classic 2D way: a plateau top that matches
the ground, and along every south-facing edge a rock face two 16px rows
tall - a "fringe" row where the top surface hangs over the rock, and a
"base" row where the rock meets the ground below (scalloped bottom, tufts
or drips on transparency). Each row comes as a left end, a run of middle
variants and a right end.

This composes one small strip sheet per biome (assets/textures/craftpix/
cliff_<biome>.png), 6 columns x 2 rows of 16px pieces:

    row 0 (fringe):  L  M1 M2 M3 M4  R
    row 1 (base):    L  M1 M2 M3 M4  R

Middle slots repeat when a pack has fewer variants. DungeonManager's wall
autotile (_make_wall_atlas) reads these strips 1:1 and builds the 32px wall
tiles from them at runtime (two pieces per row, ends where a face stops).
Pack art is only cropped, never repainted.

    python3 tools/extract_craftpix_cliffs.py [--preview DIR]
"""
import os
import sys
from PIL import Image

SRC = "assets/sprites/craftpix"
OUT = "assets/textures/craftpix"
T = 16
MIDS = 4

# biome -> (sheet, fringe [L, mids..., R], base [L, mids..., R]) in 16px tile
# coordinates on the pack's ground sheet. Coordinates were read off the sheets
# by hand (see docs/ASSET_PACKS.md, "Cliff strips").
STRIPS = {
    # World 1 grassland: the grass-capped cobbled cliff block (cols 0-2,
    # rows 0-4) plus the thin ledge (cols 3-4) for middle variants.
    "field": ("tileset_grassland/ground_grasss.png",
              [(0, 2), (1, 2), (3, 1), (4, 1), (2, 2)],
              [(0, 4), (1, 4), (3, 2), (4, 2), (2, 4)]),
    # Greenwood: the dark rock face (cols 9-12, row 0): flat-topped rock over
    # a rock-with-grass base; the pack only rounds single-row ledges, so the
    # ends come from the ledge blob at cols 0-2, rows 16-17.
    "forest": ("tileset_forest/Ground_grass.png",
               [(0, 16), (9, 0), (10, 0), (2, 16)],
               [(0, 17), (11, 0), (12, 0), (2, 17)]),
    # Caves and sewers: the cobbled cave rock block (cols 0-4, rows 4 / 6).
    "cave": ("tileset_cave/ground_source.png",
             [(0, 4), (1, 4), (2, 4), (3, 4), (4, 4)],
             [(0, 6), (1, 6), (2, 6), (3, 6), (4, 6)]),
    # Barrow land (World 5, and the grey stone under World 3's frost): the
    # jagged dark rock blob (cols 1-3, rows 3 / 5), base variants from the
    # long strip on row 33.
    "undead": ("tileset_undead_land/Ground_rocks.png",
               [(1, 3), (2, 3), (3, 3)],
               [(1, 5), (2, 5), (1, 33), (2, 33), (3, 5)]),
    # Amber Wastes: sand-lipped sandstone (row 7) over a tufted base (row 6);
    # rounded ends from the single-row ledge at cols 10-13, rows 8-9.
    "desert": ("tileset_desert/Ground_grass.png",
               [(10, 8), (4, 7), (5, 7), (13, 8)],
               [(10, 9), (0, 6), (1, 6), (13, 9)]),
    # Hell: the vein-wrapped flesh cliff (cols 2-5, rows 3 / 5).
    "cursed": ("tileset_cursed_land/Ground.png",
               [(2, 3), (3, 3), (4, 3), (5, 3)],
               [(2, 5), (3, 5), (4, 5), (5, 5)]),
}


def piece(img, tx, ty):
    return img.crop((tx * T, ty * T, tx * T + T, ty * T + T))


def build(name, sheet, fringe, base):
    img = Image.open(os.path.join(SRC, sheet)).convert("RGBA")
    out = Image.new("RGBA", (T * (MIDS + 2), T * 2), (0, 0, 0, 0))
    for row, coords in enumerate((fringe, base)):
        left, right = coords[0], coords[-1]
        mids = coords[1:-1]
        cols = [left] + [mids[i % len(mids)] for i in range(MIDS)] + [right]
        for c, (tx, ty) in enumerate(cols):
            out.paste(piece(img, tx, ty), (c * T, row * T))
    out.save(os.path.join(OUT, f"cliff_{name}.png"))
    print(f"cliff_{name:8s} <- {sheet}")
    return out


def preview(name, strip, out_dir):
    """A sample wall run against a flat ground colour, the way the runtime
    composes it: [L M M R] over two rows, then a single-piece [L R] tile."""
    sc = 4
    w, h = T * 7, T * 4
    img = Image.new("RGBA", (w, h), (90, 110, 70, 255))
    def put(col, row, x, y):
        img.alpha_composite(strip.crop((col * T, row * T, col * T + T, row * T + T)), (x, y))
    seq = [0, 1, 2, 3, 4, 5]
    for i, c in enumerate(seq):
        put(c, 0, i * T, T)
        put(c, 1, i * T, T * 2)
    big = img.resize((w * sc, h * sc), Image.NEAREST)
    big.save(os.path.join(out_dir, f"cliff_{name}_preview.png"))


if __name__ == "__main__":
    prev = None
    if "--preview" in sys.argv:
        prev = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(prev, exist_ok=True)
    for name, (sheet, fringe, base) in STRIPS.items():
        strip = build(name, sheet, fringe, base)
        if prev:
            preview(name, strip, prev)
