#!/usr/bin/env python3
"""Meadow flower-cluster billboard prop (master-palette colors).

A small clump of blooms on dark tufts with a painted contact shadow —
same treatment as the other ground props. Bottom row of the sprite sits
at ground level.
"""
import random
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

GRASS_HI = H("9ad994")    # FOLIAGE_1
GRASS_SH = H("32716c")    # TEAL_5
GRASS_CORE = H("205858")  # TEAL_6
GOLD = H("f9dc3e")        # GOLD_1
ROSE = H("f890d0")        # ROSE_1
WHITE = H("f2fdff")       # STEEL_3
SHADOW_A = (24, 24, 24, 97)
SHADOW_B = (24, 24, 24, 51)

W, HGT = 20, 14
GROUND = 12

rng = random.Random(7)
img = Image.new("RGBA", (W, HGT))
p = img.load()

# Contact shadow strip.
for x in range(3, 17):
    p[x, GROUND + 1] = SHADOW_B
for x in range(4, 16):
    p[x, GROUND] = SHADOW_A

# Leaf tufts rooted on the ground row.
for cx in (5, 9, 14):
    h = rng.randint(2, 3)
    for dy in range(h):
        p[cx, GROUND - 1 - dy] = GRASS_SH
    p[cx - 1, GROUND - 1] = GRASS_CORE
    p[cx + 1, GROUND - 1] = GRASS_SH

# Blooms: plus-shaped heads on stems that reach the ground row.
blooms = [(4, 5, GOLD), (9, 3, ROSE), (14, 5, WHITE), (11, 8, GOLD)]
for (bx, by, c) in blooms:
    for y in range(by + 2, GROUND):               # stem, connected to the head
        p[bx, y] = GRASS_CORE
    shade = tuple(max(0, v - 70) for v in c[:3]) + (255,)
    p[bx, by] = c                                 # petal top
    p[bx - 1, by + 1] = c
    p[bx + 1, by + 1] = shade                     # right petal in shade
    p[bx, by + 2] = shade                         # petal bottom
    p[bx, by + 1] = GOLD if c != GOLD else ROSE   # contrasting center

img.save("assets/textures/props/flowers.png")
print("flowers", img.size)
