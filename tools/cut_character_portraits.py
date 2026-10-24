#!/usr/bin/env python3
"""Cut the five hero portraits for the Choose Your Character screen.

Source: assets/sprites/paintings/character_portraits.png (.gdignore'd source
art, 2026-10-23): a 1307x232 strip of the heroes as busts on a dark glow, left
to right Jeremy, Cory, Ryan, Brad, Stephen — the portraits the designer chose
for the select screen (they replace the ones first cut from the screen's
mock-up board, character_select_board.webp).

Each bust is found as a run of bright columns, and cut as a box of the
screen's portrait shape (CharacterRow.PORTRAIT_BOX, 96:100) centred on it, as
tall as the strip (padded with the strip's black where the box runs past its
edge). Saved at OUT_SIZE — twice the box — with a sharp resample; the screen
shrinks it smoothly (mipmaps), so the portraits keep their detail.

Output: assets/sprites/portraits/<hero>.png
Run: python3 tools/cut_character_portraits.py   (Pillow, numpy)
"""
import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/character_portraits.png"
OUT = "assets/sprites/portraits/%s.png"
HEROES = ["jeremy", "cory", "ryan", "brad", "stephen"]   # left to right on the strip
ASPECT = 96.0 / 100.0                                     # the select screen's portrait box
OUT_SIZE = (192, 200)
BRIGHT = 60        # a column with a few pixels brighter than this belongs to a bust
MIN_GAP = 8        # columns between busts


def main() -> None:
    img = Image.open(SRC).convert("RGB")
    lum = np.asarray(img).max(axis=2)
    cols = np.nonzero((lum > BRIGHT).sum(axis=0) > 3)[0]
    runs, start = [], cols[0]
    for a, b in zip(cols, cols[1:]):
        if b > a + MIN_GAP:
            runs.append((start, a))
            start = b
    runs.append((start, cols[-1]))
    assert len(runs) == len(HEROES), runs
    h = img.height
    w = int(round(h * ASPECT))
    for hero, (x0, x1) in zip(HEROES, runs):
        cx = (x0 + x1) // 2
        box = (cx - w // 2, 0, cx - w // 2 + w, h)
        canvas = Image.new("RGB", (w, h))
        canvas.paste(img.crop((max(0, box[0]), 0, min(img.width, box[2]), h)), (max(0, -box[0]), 0))
        canvas.resize(OUT_SIZE, Image.LANCZOS).save(OUT % hero)
        print("%-8s bust %d-%d -> box %s" % (hero, x0, x1, box))


if __name__ == "__main__":
    main()
