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
