#!/usr/bin/env python3
"""Waypoint ground-ring sprite: a chunky pixel stone circle with rune ticks.

Drawn in neutral light greys (STEEL ramp) and tinted per destination at
runtime via modulate, replacing the smooth translucent cylinder disc.
"""
import math
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

RING = H("f4f9f8")      # STEEL_3
RING_SH = H("b6c5c5")   # STEEL_6
RUNE = H("d9dec2")      # STEEL_5

N = 26
img = Image.new("RGBA", (N, N))
p = img.load()
c = (N - 1) / 2.0

for y in range(N):
    for x in range(N):
        d = math.hypot(x - c, y - c)
        if 9.0 <= d <= 11.6:
            # Quantize the ring into chunky arc segments with a lit top-left
            ang = math.atan2(y - c, x - c)
            seg = int(((ang + math.pi) / (2 * math.pi)) * 12) % 12
            if seg % 3 == 2:
                continue                       # gaps break the smooth circle
            lit = (x - c) + (y - c) < 0
            p[x, y] = RING if lit else RING_SH

# Rune ticks at the four cardinals, just inside the ring.
for (dx, dy) in ((0, -6), (0, 6), (-6, 0), (6, 0)):
    x, y = int(c + dx), int(c + dy)
    p[x, y] = RUNE
    p[x + (0 if dx else 1), y + (0 if dy else 1)] = RUNE

# Center glyph: small diamond.
for (dx, dy) in ((0, -1), (0, 1), (-1, 0), (1, 0), (0, 0)):
    p[int(c) + dx, int(c) + dy] = RUNE

img.save("assets/textures/props/waypoint_ring.png")
print("waypoint_ring", img.size)
