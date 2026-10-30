#!/usr/bin/env python3
"""Cut the designer's Trials of Olorin logo (logo_board.webp, 2026-10-30: an
emerald sword through a cracked silver ring with gold points, on the forest
floor) into the sizes the game draws it at, each shrunk once with a sharp
(Lanczos) filter so it stays crisp drawn 1:1.

The forest floor is cleared by flood fill from the board's edge over its
dark greens (the art's black outline stops it); what it encloses — the
floor seen through the ring — is cleared too.

Output: assets/textures/ui/to_logo_<px>.png (square, the logo centred,
<px> tall). UIGlyphs.to_logo(px) picks the nearest.
Run: python3 tools/cut_logo.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/logo_board.webp"
OUT = "assets/textures/ui/to_logo_%d.png"
SIZES = [20, 24, 26, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 72, 80, 128, 256]


def floor_mask(a):
    """The forest floor: dark, green-leaning pixels."""
    mx = a.max(axis=2)
    return (mx >= 14) & (mx <= 75) & (a[..., 1] >= a[..., 0] - 2) & (a[..., 1] >= a[..., 2] - 2)


def main():
    a = np.asarray(Image.open(SRC).convert("RGB")).astype(int)
    floor = floor_mask(a)
    lab, _ = nd.label(floor)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    # The floor inside the ring: the biggest enclosed floor patches.
    sizes = nd.sum(floor, lab, range(1, lab.max() + 1))
    for i, sz in enumerate(sizes):
        if sz > 4000 and (i + 1) not in edge:
            bg |= lab == i + 1
    fg = ~bg
    lab2, n = nd.label(fg)
    sz2 = nd.sum(fg, lab2, range(1, n + 1))
    fg = lab2 == 1 + int(np.argmax(sz2))   # the logo itself, no stray specks
    ys, xs = np.nonzero(fg)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([a, fg * 255]).astype(np.uint8)[y0:y1, x0:x1]
    img = Image.fromarray(rgba, "RGBA")
    for px in SIZES:
        k = px / float(img.height)
        w = max(1, round(img.width * k))
        small = np.asarray(img.convert("RGBa").resize((w, px), Image.LANCZOS).convert("RGBA")).copy()
        small[..., 3] = np.where(small[..., 3] >= 110, 255, 0)
        small[small[..., 3] == 0, :3] = 0
        out = Image.new("RGBA", (px, px))
        out.paste(Image.fromarray(small, "RGBA"), ((px - w) // 2, 0))
        out.save(OUT % px)
        print("to_logo_%d: %dx%d (logo %dx%d)" % (px, px, px, w, px))


if __name__ == "__main__":
    main()
