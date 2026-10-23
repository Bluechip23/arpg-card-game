#!/usr/bin/env python3
"""Cut the five hero portraits off the designer's character-select board.

Source: assets/sprites/paintings/character_select_board.webp (.gdignore'd
source art, 2026-10-23): a 1366x911 mock-up of the Choose Your Character
screen, one row per hero (Ryan, Jeremy, Stephen, Cory, Brad), each led by a
square portrait on black. The rest of the board (names, blurbs, walk frames)
is the screen's layout, built in scripts/character/character_row.gd, not art.

Each portrait is found as the bright block in its row's left margin (the
board's black is pure 0; a portrait's own darkest outline is lighter than
the threshold only in its frame, so the block's bounding box is the frame),
and saved as is — the board's portraits are already the size the screen
shows them at.

Output: assets/sprites/portraits/<hero>.png
Run: python3 tools/cut_character_portraits.py   (Pillow, numpy)
"""
import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/character_select_board.webp"
OUT = "assets/sprites/portraits/%s.png"
HEROES = ["ryan", "jeremy", "stephen", "cory", "brad"]   # top to bottom on the board
MARGIN_X = 135     # the portraits sit left of this column
BRIGHT = 40        # a pixel brighter than this (max channel) is portrait, not the board's black
MIN_RUN = 20       # a row/column needs this many bright pixels to count


def main() -> None:
    img = Image.open(SRC).convert("RGB")
    lum = np.asarray(img).max(axis=2)[:, :MARGIN_X]
    rows = np.nonzero((lum > BRIGHT).sum(axis=1) > MIN_RUN)[0]
    blocks, start = [], rows[0]
    for a, b in zip(rows, rows[1:]):
        if b != a + 1:
            blocks.append((start, a))
            start = b
    blocks.append((start, rows[-1]))
    blocks = [(y0, y1) for y0, y1 in blocks if y1 - y0 > 40]
    assert len(blocks) == len(HEROES), blocks
    for hero, (y0, y1) in zip(HEROES, blocks):
        cols = np.nonzero((lum[y0:y1 + 1] > BRIGHT).sum(axis=0) > MIN_RUN)[0]
        box = (int(cols.min()), int(y0), int(cols.max()) + 1, int(y1) + 1)
        img.crop(box).save(OUT % hero)
        print("%-8s %s -> %dx%d" % (hero, box, box[2] - box[0], box[3] - box[1]))


if __name__ == "__main__":
    main()
