#!/usr/bin/env python3
"""Cut the mythics that came on their own painted boards (2026-11-13: the
Glutton's Cleaver, The Tenderizer; 2026-11-14: the Blueringed Skitter) onto the 128px canvas the others use.

Unlike the five mythic sheets (tools/cut_mythic_art.py), these boards' ground
is a smoky dark wash, not a flat panel, so a flood fill by colour will not
lift it: each piece is cut with GrabCut seeded from a box round it, small
loose bits are dropped and the edge is feathered. A board may name pockets
(crop coordinates) where GrabCut keeps dark ground between parts of the
piece: only there are dark pixels dropped.

Output: assets/items/mythic/<slug>.png (128x128 RGBA)
Run: python3 tools/cut_mythic_boards.py   (Pillow, numpy, opencv, scipy)

With --large it writes only the close-up cut, on a LARGE_CANVAS square in
assets/items/mythic/large/<slug>.png (see tools/cut_mythic_art.py).
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/mythic_%s.webp"
OUT = "assets/items/mythic/%s.png"
CANVAS = 128
FIT = 122
LARGE_OUT = "assets/items/mythic/large/%s.png"
LARGE_CANVAS = 384
LARGE_FIT = 368
# slug -> the box round the piece (x0, y0, x1, y1) and its dark pockets.
BOARDS = {
    "gluttons_cleaver": {"box": (520, 20, 1110, 900), "pockets": [(352, 232, 450, 400)]},
    "the_tenderizer": {"box": (60, 80, 964, 1520), "pockets": []},
    # 2026-11-14: a wavy dagger in purple smoke and green wisps on black.
    "blueringed_skitter": {"box": (30, 10, 1240, 1245), "pockets": [], "dark_key": (22, 70)},
}


def cut(slug, cfg):
    rgb = np.asarray(Image.open(SRC % slug).convert("RGB"))
    x0, y0, x1, y1 = cfg["box"]
    crop = np.ascontiguousarray(rgb[y0:y1, x0:x1])
    mask = np.zeros(crop.shape[:2], np.uint8)
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(crop, mask, (8, 8, crop.shape[1] - 16, crop.shape[0] - 16), bgd, fgd, 8, cv2.GC_INIT_WITH_RECT)
    fg = (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)
    # Anything clearly lit is the piece, whatever GrabCut thought.
    fg |= crop.max(axis=2) > 90
    fg = nd.binary_opening(fg, iterations=1)
    lab, n = nd.label(fg)
    if n > 1:
        sizes = nd.sum(fg, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= 400]
        fg = np.isin(lab, keep)
    for px0, py0, px1, py1 in cfg["pockets"]:
        pocket = np.zeros_like(fg)
        pocket[py0:py1, px0:px1] = True
        fg &= ~(pocket & (crop.max(axis=2) < 46))
    alpha = cv2.GaussianBlur(fg.astype(np.float32), (0, 0), 1.2)
    alpha = np.where(nd.binary_erosion(fg, iterations=2), 1.0, alpha)
    # A board painted on black with a smoky haze: the piece itself (its lit
    # silhouette, holes filled, the largest part) stays solid; everything
    # around it fades by how dark it is (lo and below gone, hi and above
    # kept), so the wisps glow on transparency instead of a muddy cloud.
    if cfg.get("dark_key"):
        lo, hi = cfg["dark_key"]
        bright = crop.max(axis=2).astype(np.float32)
        lit = nd.binary_closing(bright > cfg.get("solid_lit", 70), iterations=4)
        lit = nd.binary_fill_holes(lit)
        lab, n = nd.label(lit)
        solid = np.zeros_like(lit)
        if n > 0:
            sizes = nd.sum(lit, lab, range(1, n + 1))
            solid = nd.binary_erosion(lab == (int(np.argmax(sizes)) + 1), iterations=1)
        glow = np.clip((bright - lo) / float(hi - lo), 0.0, 1.0)
        alpha = np.where(solid, alpha, alpha * glow)
    ys, xs = np.nonzero(alpha > 0.05)
    piece = np.dstack([crop, (alpha * 255).astype(np.uint8)])[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    img = Image.fromarray(piece, "RGBA")
    k = FIT / float(max(img.size))
    img = img.convert("RGBa").resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(img, ((CANVAS - img.width) // 2, (CANVAS - img.height) // 2), img)
    canvas.save(OUT % slug)
    print("saved %s (%dx%d piece)" % (OUT % slug, img.width, img.height))


def main():
    global CANVAS, FIT, OUT
    if "--large" in sys.argv:
        CANVAS, FIT, OUT = LARGE_CANVAS, LARGE_FIT, LARGE_OUT
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
    for slug, cfg in BOARDS.items():
        cut(slug, cfg)


if __name__ == "__main__":
    main()
