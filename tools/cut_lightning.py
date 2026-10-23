#!/usr/bin/env python3
"""Cut the designer's lightning sheet into four effect strips.

Source: assets/sprites/paintings/lightning_sheet.png (.gdignore'd source art,
2026-10-23): a 484x407 screenshot of a sheet on flat grey (61,61,61), four
bands of frames left to right:
  1. blue  — long horizontal arcs             -> shock_arc_strip.png
  2. blue  — small crackles                    -> shock_crackle_strip.png
  3. gold  — a bolt forming and striking down -> thunder_strike_strip.png
  4. gold  — the strike's ground burst fading  -> thunder_impact_strip.png
(Blue is Shock, gold God of Thunder — designer, 2026-10-23.) The first
ground-burst frame is clipped by the sheet's left edge; it is used as is.

The art is soft glow on grey, so each pixel is un-blended from the grey:
alpha = how far it stands from the grey (its strongest channel), colour =
what over that grey at that alpha would give the pixel. Frames are found
at the columns measured below, cropped to what they hold, and packed into one strip per band with equal cells, aligned by how the
effect player pins them: arcs by their left-middle (stretched from the
shocked enemy to the one it jumps to), crackles by their centre (over the
enemy), strike and burst by their bottom-centre (on the target's feet).

Output: assets/sprites/generated/fx/<strip>.png; prints the cell sizes.
Run: python3 tools/cut_lightning.py   (numpy + Pillow)
"""
import os

import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/lightning_sheet.png"
OUT = "assets/sprites/generated/fx/%s.png"
BG = 61.0
KEY = 14          # a pixel this far from the grey (any channel) is art
FULL = 150.0      # a channel this far above the grey is fully opaque
# (name, y0, y1, align, frame columns) — bands and frames measured on the
# sheet. The sparse frames (fading crackles, the dying ground burst) have
# wide gaps inside them, so frames are cut at these columns, not at gaps.
BANDS = [
    ("shock_arc_strip", 14, 57, "left",
     [(28, 49), (55, 101), (108, 213), (215, 301), (308, 393), (400, 484)]),
    ("shock_crackle_strip", 66, 116, "center",
     [(98, 169), (180, 241), (245, 311), (318, 361), (372, 411)]),
    ("thunder_strike_strip", 140, 284, "bottom",
     [(98, 122), (124, 148), (150, 180), (184, 238), (247, 300), (316, 399)]),
    ("thunder_impact_strip", 284, 388, "bottom",
     [(0, 67), (80, 171), (182, 271), (283, 375), (392, 484)]),
]


def unblend(rgb: np.ndarray) -> np.ndarray:
    d = rgb - BG
    a = np.clip(np.abs(d).max(-1) / FULL, 0.0, 1.0)
    a[np.abs(d).max(-1) <= KEY] = 0.0
    col = BG + d / np.maximum(a, 1e-3)[..., None]
    out = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    out[..., :3] = np.clip(col, 0, 255).astype(np.uint8)
    out[..., 3] = (a * 255).astype(np.uint8)
    return out


def frames_in(band: np.ndarray, cols: list) -> list:
    out = []
    for x0, x1 in cols:
        f = band[:, x0:x1]
        ys = np.where((f[..., 3] > 0).any(axis=1))[0]
        xs = np.where((f[..., 3] > 0).any(axis=0))[0]
        out.append(f[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    return out


def pack(frames: list, align: str) -> Image.Image:
    cw = max(f.shape[1] for f in frames)
    ch = max(f.shape[0] for f in frames)
    strip = np.zeros((ch, cw * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        h, w = f.shape[:2]
        if align == "left":
            x, y = 0, (ch - h) // 2
        elif align == "center":
            x, y = (cw - w) // 2, (ch - h) // 2
        else:  # bottom
            x, y = (cw - w) // 2, ch - h
        strip[y:y + h, i * cw + x:i * cw + x + w] = f
    return Image.fromarray(strip, "RGBA")


def main() -> None:
    sheet = unblend(np.array(Image.open(SRC).convert("RGB")).astype(float))
    for name, y0, y1, align, cols in BANDS:
        frames = frames_in(sheet[y0:y1], cols)
        img = pack(frames, align)
        os.makedirs(os.path.dirname(OUT % name), exist_ok=True)
        img.save(OUT % name)
        print("%s: %d frames, cell %dx%d" % (name, len(frames), img.width // len(frames), img.height))


if __name__ == "__main__":
    main()
