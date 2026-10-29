#!/usr/bin/env python3
"""Cut the designer's world-prop boards (bushes, trees, rocks... drawn on
black) into the prop sprites that replace the pack ones.

Each board lists its pieces in the order of the role's variants. A piece is
lifted off the black (the black reached from the crop's edge; black the
piece encloses is its own deep shading and stays; the outer rim's alpha is
soft, from its brightness, so its blend into black does not become a dark
line), shrunk with a sharp (Lanczos)
filter on premultiplied colour to its height in texels, then given on/off
alpha like the heroes and the creature boards.

The props are cut at 64 texels a tile, twice the packs' 32 and the
fineness of the designer's creature boards (2026-10-24: err on the side of
under-pixelating what we make), so the role draws at scale 0.5 in
tools/build_craftpix_props.py (DESIGNER). A piece's height is the height
the pack variant it replaces had, doubled: the world keeps its sizes.

Output: assets/textures/props/boards/<role>_<i>.png
Run: python3 tools/cut_prop_boards.py [role ...]; then
     python3 tools/build_craftpix_props.py (the manifest).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/%s"
OUT = "assets/textures/props/boards/%s_%d.png"
BLACK = 10      # brightness (max channel) at or below this is the board's black
RAMP = 40       # ...and alpha ramps to full over this many levels above it
SPECK = 40      # pieces of a cut-out smaller than this (source px) are dropped

# role -> board and pieces: (crop box (x0, y0, x1, y1) in source px, height
# in texels at 64 a tile). The boxes come from the board's own layout.
BOARDS = {
    # 2026-10-29: the designer's seven forest bushes (forest_bushes_board.webp,
    # two rows on black), each in the place of the pack bush it most
    # resembles; heights are the pack bushes' (34, 27, 28, 31, 22, 38, 32
    # texels at 32 a tile), doubled.
    "forest_bush": {
        "src": "forest_bushes_board.webp",
        "pieces": [
            ((526, 552, 995, 924), 68),     # the fan of long leaves (was the pack's star-leaf bush)
            ((1051, 552, 1450, 928), 54),   # bottom right
            ((27, 153, 357, 468), 56),      # top left
            ((375, 101, 780, 474), 62),     # the wide dome
            ((796, 218, 1121, 468), 44),    # the smallest
            ((1134, 107, 1518, 478), 76),   # the biggest
            ((68, 523, 442, 921), 64),      # the tall one, bottom left
        ],
    },
    # 2026-10-29: the designer's Greenwood trees (forest_trees_board.webp, 18
    # trees on black in three rows: conifers and a great oak; broadleaf trees,
    # two on pale roots; small round trees). Each takes the place of the pack
    # tree it most resembles at its height (doubled); the small round trees
    # past the eighth are new variants, sized as drawn beside the first.
    "forest_tree": {
        "src": "forest_trees_board.webp",
        "pieces": [
            ((1300, 507, 1512, 748), 84),   # broadleaf on pale roots, the smaller
            ((8, 8, 288, 423), 124),        # the big conifer
            ((304, 28, 541, 417), 118),     # the tall conifer
            ((311, 429, 515, 753), 128),    # the tall broadleaf
            ((554, 157, 726, 414), 78),     # the small conifer
            ((517, 526, 710, 759), 94),     # the small broadleaf
            ((720, 460, 988, 764), 124),    # the wide broadleaf
            ((48, 828, 200, 993), 74),      # small round trees, the smallest first
            ((244, 769, 475, 995), 101),
            ((511, 822, 657, 983), 72),
            ((693, 772, 948, 1000), 102),
            ((968, 769, 1252, 997), 102),
            ((1271, 772, 1511, 997), 101),
        ],
    },
    "forest_tree_big": {
        "src": "forest_trees_board.webp",
        "pieces": [
            ((740, 97, 934, 416), 148),     # the yellow-green conifer
            ((951, 64, 1127, 412), 156),    # the columnar broadleaf
            ((20, 442, 300, 766), 156),     # the round broadleaf
            ((1003, 418, 1296, 758), 150),  # broadleaf on pale roots, the bigger
        ],
    },
    # The climbable / landmark tree: the great oak.
    "forest_tree_climb": {
        "src": "forest_trees_board.webp",
        "pieces": [((1145, 23, 1527, 423), 154)],
    },
    # 2026-10-29: the fallen log, the stump and three ferns
    # (forest_logs_ferns_board.webp, on black).
    "forest_log": {
        "src": "forest_logs_ferns_board.webp",
        "pieces": [
            ((35, 59, 967, 459), 74),       # the fallen, splintered log
            ((1029, 144, 1479, 465), 44),   # the stump (the pack's log set had a small one)
        ],
    },
    "forest_stump": {
        "src": "forest_logs_ferns_board.webp",
        "pieces": [((1029, 144, 1479, 465), 56)],
    },
    # 2026-10-29: the designer's forest rocks (forest_rocks_board.webp, 12 on
    # black in three rows: rock clusters; cracked stone pillars, big to
    # small, and a low block; mossy clusters). Each of the first eight takes
    # the place of the pack rock it most resembles at its height (doubled);
    # the other four are new variants, sized like the clusters beside them.
    "forest_rock": {
        "src": "forest_rocks_board.webp",
        "pieces": [
            ((32, 343, 405, 662), 126),     # the big pillar
            ((471, 411, 756, 663), 94),     # the middle pillar
            ((872, 441, 1105, 655), 68),    # the small pillar
            ((27, 686, 403, 972), 70),      # mossy cluster, left
            ((1230, 741, 1486, 947), 58),   # mossy cluster, small
            ((440, 113, 792, 327), 56),     # the wide cluster
            ((842, 96, 1213, 337), 64),     # the slab cluster
            ((1271, 113, 1486, 288), 40),   # the lone pointed stone
            ((51, 77, 384, 319), 65),       # new: the tall pointed cluster
            ((1218, 473, 1489, 647), 47),   # new: the low block
            ((438, 701, 792, 963), 71),     # new: mossy cluster, middle
            ((828, 702, 1175, 972), 73),    # new: mossy cluster, right
        ],
    },
    "forest_fern": {
        "src": "forest_logs_ferns_board.webp",
        "pieces": [
            ((33, 628, 448, 930), 28),      # the low fern, left
            ((1078, 533, 1496, 931), 32),   # the upright fern, right
            ((496, 503, 1024, 925), 74),    # the great fern, middle
        ],
    },
}


def cut_piece(board, box, height):
    rgb = np.asarray(board.crop(box).convert("RGB")).astype(np.float32)
    bright = rgb.max(axis=2)
    # The background is the black reached from the crop's edge; black
    # enclosed by the piece is its own deep shading (the designer shades
    # foliage nearly to black) and stays.
    black = bright <= BLACK
    lab, n = nd.label(black)
    edge_labels = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    solid = ~np.isin(lab, list(edge_labels))
    lab, n = nd.label(solid)
    if n:
        sizes = nd.sum(solid, lab, range(1, n + 1))
        solid = np.isin(lab, 1 + np.nonzero(sizes >= SPECK)[0])
    # The outermost rim is blended into the black: soft there (RAMP), so
    # the shrink does not draw a dark line round the piece.
    rim = solid & ~nd.binary_erosion(solid, iterations=2)
    alpha = np.where(rim, np.clip((bright - BLACK) / RAMP, 0.0, 1.0), solid.astype(np.float32))
    ys, xs = np.nonzero(solid)
    rgb = rgb[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    alpha = alpha[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    # Colour stays as painted inside; the rim's blend with black is taken
    # back out (unpremultiply) where its alpha is soft.
    col = np.clip(rgb / np.maximum(alpha, 1e-3)[..., None], 0, 255)
    img = Image.fromarray(np.dstack([col, alpha * 255]).astype(np.uint8), "RGBA")
    k = height / float(img.height)
    size = (max(1, round(img.width * k)), height)
    small = np.asarray(img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")).copy()
    small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
    small[small[..., 3] == 0, :3] = 0
    return Image.fromarray(small, "RGBA")


def build(role, cfg):
    board = Image.open(SRC % cfg["src"])
    os.makedirs(os.path.dirname(OUT % (role, 0)), exist_ok=True)
    for i, (box, height) in enumerate(cfg["pieces"]):
        img = cut_piece(board, box, height)
        img.save(OUT % (role, i))
        print("%s_%d: %dx%d" % (role, i, img.width, img.height))


def main():
    for role in sys.argv[1:] or list(BOARDS):
        build(role, BOARDS[role])


if __name__ == "__main__":
    main()
