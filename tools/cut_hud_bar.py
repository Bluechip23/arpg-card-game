#!/usr/bin/env python3
"""Cut the designer's top-right HUD bar (hud_bar_board.webp, 2026-10-29: a
mossy stone bar of five panels — a bust, the green EXP arrow, a scroll, an
info banner, a question mark — on white) into the bar texture HudIconBar
draws, at the HUD's own size (no runtime scaling, so it stays crisp).

The white reached from the board's edge is cleared; the bar is shrunk with
a sharp (Lanczos) filter on premultiplied colour. The five button rects
(the stone panels, in output px) are printed for scripts/ui/hud_icon_bar.gd.

Output: assets/textures/ui/hud_bar.png
Run: python3 tools/cut_hud_bar.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/hud_bar_board.webp"
OUT = "assets/textures/ui/hud_bar.png"
BOX = (0, 160, 2000, 522)      # the bar, with a little white round it
HEIGHT = 52                    # px on screen
WHITE = 205                    # min channel at or above this is the board's white
# The five stone panels (board px): bust, EXP, scroll, banner, question mark.
PANELS = [(75, 205, 395, 472), (428, 205, 862, 472), (886, 205, 1212, 472),
          (1243, 205, 1577, 472), (1612, 205, 1937, 472)]


def main():
    rgb = np.asarray(Image.open(SRC).convert("RGB").crop(BOX)).astype(np.float32)
    white = rgb.min(axis=2) >= WHITE
    lab, _ = nd.label(white)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    solid = ~np.isin(lab, list(edge))
    ys, xs = np.nonzero(solid)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    img = Image.fromarray(np.dstack([rgb, solid * 255.0])[y0:y1, x0:x1].astype(np.uint8), "RGBA")
    k = HEIGHT / float(img.height)
    size = (round(img.width * k), HEIGHT)
    small = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    small.save(OUT)
    print("hud_bar: %dx%d" % size)
    ox, oy = BOX[0] + x0, BOX[1] + y0
    for p in PANELS:
        print("  panel (%d, %d, %d, %d)" % (round((p[0] - ox) * k), round((p[1] - oy) * k),
                                           round((p[2] - ox) * k), round((p[3] - oy) * k)))


if __name__ == "__main__":
    main()
