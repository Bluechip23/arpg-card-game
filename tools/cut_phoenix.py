#!/usr/bin/env python3
"""Cut the designer's Gift of the Phoenix animation into one sprite strip.

Sources: assets/sprites/paintings/phoenix_0..4.png (.gdignore'd source art,
2026-10-23): five 256x256 frames on one shared canvas — an ember, then the
phoenix spreading its wings in four poses. One-pixel art with on/off alpha.

The frames keep their shared alignment (cropped to the union of their
bounds), and are box-filtered DOWN x with on/off alpha so the bird sits at
the game's texel density (full size it would be ~6 tiles wide; halved it
spreads ~3 tiles over the player's head).

Output: assets/sprites/generated/fx/phoenix_strip.png (5 frames, left to right)
Played by scripts/effects/phoenix_rise.gd.
Run: python3 tools/cut_phoenix.py   (numpy + Pillow)
"""
import os

import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/phoenix_%d.png"
OUT = "assets/sprites/generated/fx/phoenix_strip.png"
FRAMES = 5
DOWN = 2


def downscale(rgba: np.ndarray) -> np.ndarray:
    h, w, _ = rgba.shape
    h2, w2 = h // DOWN, w // DOWN
    a = rgba[:h2 * DOWN, :w2 * DOWN].reshape(h2, DOWN, w2, DOWN, 4)
    cover = a[..., 3].sum((1, 3))
    rgb = (a[..., :3] * a[..., 3:4]).sum((1, 3)) / np.maximum(cover, 1e-6)[..., None]
    out = np.zeros((h2, w2, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(cover / (DOWN * DOWN) >= 0.5, 255, 0)
    return out


def main() -> None:
    frames = [Image.open(SRC % i).convert("RGBA") for i in range(FRAMES)]
    boxes = [f.getbbox() for f in frames]
    x0 = min(b[0] for b in boxes)
    y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes)
    y1 = max(b[3] for b in boxes)
    # Even size so every frame halves cleanly.
    x1 += (x1 - x0) % DOWN
    y1 += (y1 - y0) % DOWN
    cells = []
    for f in frames:
        a = np.array(f.crop((x0, y0, x1, y1))).astype(float)
        a[..., 3] /= 255.0
        cells.append(downscale(a))
    h, w = cells[0].shape[:2]
    strip = np.zeros((h, w * FRAMES, 4), np.uint8)
    for i, c in enumerate(cells):
        strip[:, i * w:(i + 1) * w] = c
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(strip, "RGBA").save(OUT)
    print("phoenix: %d frames of %dx%d -> %s" % (FRAMES, w, h, OUT))


if __name__ == "__main__":
    main()
