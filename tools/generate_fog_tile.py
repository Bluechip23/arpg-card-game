#!/usr/bin/env python3
"""Fog-of-war surface tile: dark backdrop olive with a sparse one-shade
dither so the unexplored slabs read as textured 16-bit darkness instead of
flat modern boxes. Tiles every 32px (one world unit at the standard
triplanar scale)."""
import random
from PIL import Image

BASE = (26, 28, 20, 255)      # matches the WorldEnvironment backdrop
LIGHT = (37, 41, 30, 255)     # one gentle step up
DARK = (18, 20, 14, 255)

N = 32
img = Image.new("RGBA", (N * 4, N * 4))
p = img.load()
for ty in range(4):
    for tx in range(4):
        rng = random.Random(hash(("fog", tx, ty)) & 0xFFFF)
        for y in range(N):
            for x in range(N):
                p[tx * N + x, ty * N + y] = BASE
        # Sparse ordered-feeling dither clumps.
        for _ in range(rng.randint(10, 14)):
            x, y = rng.randrange(N - 1), rng.randrange(N - 1)
            c = LIGHT if rng.random() < 0.6 else DARK
            p[tx * N + x, ty * N + y] = c
            if rng.random() < 0.5:
                p[tx * N + x + 1, ty * N + y] = c

img.save("assets/textures/tile_fog.png")
print("tile_fog", img.size)
