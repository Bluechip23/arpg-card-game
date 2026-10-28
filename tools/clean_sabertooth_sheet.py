#!/usr/bin/env python3
"""Black out the labels on the designer's new Sabertooth walk sheet.

sabertooth_v2_sheet.webp (2026-10-28): a 4x4 walk sheet on black with a
title over each row ("WALKING UP (BACK VIEW)"...) and "FRAME n" under every
frame. tools/cut_creature_sheets.py finds the frames by brightness and would
take the wide titles for part of the first frames, so the grey text is
blacked out first: in each label band, everything but the tiger's clearly
orange fur. Writes sabertooth_v2_clean.webp.

Run: python3 tools/clean_sabertooth_sheet.py
"""
import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/sabertooth_v2_sheet.webp"
OUT = "assets/sprites/paintings/sabertooth_v2_clean.webp"
# (y0, y1, x0, x1): the row titles and the FRAME labels.
BANDS = [
    (6, 30, 0, 480),        # WALKING UP (BACK VIEW)
    (240, 264, 100, 1440),  # FRAME 1..4
    (268, 296, 0, 480),     # WALKING LEFT (SIDE PROFILE VIEW)
    (462, 488, 100, 1440),
    (492, 519, 0, 480),     # WALKING DOWN (FRONT VIEW)
    (722, 747, 100, 1440),
    (748, 774, 0, 480),     # WALKING RIGHT (SIDE PROFILE VIEW)
    (955, 980, 100, 1440),
]


def main():
    a = np.asarray(Image.open(SRC).convert("RGB")).copy()
    mx = a.max(axis=2).astype(int)
    mn = a.min(axis=2).astype(int)
    # In a band, only the tiger's clearly orange fur stays; the letters and
    # their dim anti-aliased edges (grey, whatever their brightness) go.
    text = ~((mx > 60) & (mx - mn >= 40))
    n = 0
    for y0, y1, x0, x1 in BANDS:
        m = text[y0:y1, x0:x1]
        n += int(m.sum())
        a[y0:y1, x0:x1][m] = 0
    Image.fromarray(a).save(OUT, lossless=True)
    print("blacked %d label pixels; wrote %s" % (n, OUT))


if __name__ == "__main__":
    main()
