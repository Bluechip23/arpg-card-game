#!/usr/bin/env python3
"""Meadow bush billboard prop (master-palette colors).

Clumped foliage with a notched leaf silhouette — replaces the earlier
smooth mound that read as a glossy pancake. Painted contact shadow at the
base; bottom row of the sprite sits at ground level.
"""
import math
import random
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

LEAF_HI = H("9ad994")     # FOLIAGE_1
LEAF = H("389878")        # TEAL_3
LEAF_SH = H("32716c")     # TEAL_5
LEAF_CORE = H("205858")   # TEAL_6
STEM = H("5d3621")        # LEATHER_13
SHADOW_A = (24, 24, 24, 97)
SHADOW_B = (24, 24, 24, 51)

W, HGT = 32, 24
GROUND = 22

rng = random.Random(11)
img = Image.new("RGBA", (W, HGT))
p = img.load()


def disc(cx, cy, r, c, jitter=0.35):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if not (0 <= x < W and 0 <= y < HGT):
                continue
            d = math.hypot(x - cx, y - cy)
            if d <= r + (rng.random() - 0.5) * jitter * 2:
                p[x, y] = c


# Contact shadow.
for x in range(4, 28):
    p[x, GROUND + 1] = SHADOW_B
for x in range(6, 26):
    p[x, GROUND] = SHADOW_A

# Foliage mass: dark under-layer, then mid clumps, then lit crowns upper-left.
disc(16, 15, 9.5, LEAF_CORE)
for (cx, cy, r) in [(9, 14, 5.5), (21, 14, 5.5), (15, 10, 6)]:
    disc(cx, cy, r, LEAF_SH)
for (cx, cy, r) in [(10, 12, 4), (20, 12, 4), (15, 9, 4.5)]:
    disc(cx, cy, r, LEAF)
# Lit side: scattered leaf specks instead of solid discs, so the bush reads
# leafy at distance rather than glossy.
for _ in range(14):
    x = rng.randint(6, 17)
    y = rng.randint(6, 13)
    if p[x, y][3] == 255 and p[x, y][:3] in (LEAF[:3], LEAF_SH[:3]):
        p[x, y] = LEAF_HI
        if rng.random() < 0.4 and p[x + 1, y][3] == 255:
            p[x + 1, y] = LEAF_HI

# Leaf notches: single-pixel bites out of the silhouette edge.
edge = []
for y in range(HGT):
    for x in range(W):
        if p[x, y][3] == 255 and p[x, y][:3] != SHADOW_A[:3]:
            for dx, dy in ((1, 0), (-1, 0), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < HGT and p[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
for (x, y) in rng.sample(edge, len(edge) // 4):
    p[x, y] = (0, 0, 0, 0)

# A couple of tiny berry accents.
for (x, y) in [(19, 10), (12, 14)]:
    p[x, y] = H("f890d0")

img.save("assets/textures/props/bush.png")
print("bush", img.size)
