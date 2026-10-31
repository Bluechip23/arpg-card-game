#!/usr/bin/env python3
"""Cut the designer's mythic present (mythic_present_board.webp, 2026-10-31:
a green gift box tied with a gold-edged purple ribbon and bow, on black)
for the mythic reveal (scripts/battle/mythic_reveal.gd), where it replaced
the present built from coloured boxes.

The black ground is flood-filled away from the board's edge (the art's own
dark outline stops it); the piece is cropped and saved at OUT_PX tall,
shrunk once with premultiplied Lanczos (the game draws it mipmapped).

Output: assets/textures/props/mythic_present.png
Run: python3 tools/cut_mythic_present.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/mythic_present_board.webp"
OUT = "assets/textures/props/mythic_present.png"
OUT_PX = 192
DARK = 26          # the ground is near-black; the outline sits a little above it


def main():
    a = np.asarray(Image.open(SRC).convert("RGB")).astype(int)
    dark = a.max(axis=2) <= DARK
    lab, _ = nd.label(dark)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    fg = ~bg
    lab2, n = nd.label(fg)
    sizes = nd.sum(fg, lab2, range(1, n + 1))
    fg = lab2 == 1 + int(np.argmax(sizes))
    fg = nd.binary_fill_holes(fg)
    ys, xs = np.nonzero(fg)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([a, fg * 255]).astype(np.uint8)[y0:y1, x0:x1]
    img = Image.fromarray(rgba, "RGBA")
    k = OUT_PX / float(img.height)
    small = img.convert("RGBa").resize((round(img.width * k), OUT_PX), Image.LANCZOS).convert("RGBA")
    small.save(OUT)
    print("mythic_present: %dx%d" % small.size)


if __name__ == "__main__":
    main()
