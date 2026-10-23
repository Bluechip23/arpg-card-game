#!/usr/bin/env python3
"""Scenery-pass billboard props (master-palette colors).

The small atmospheric sprites no purchased pack draws: a two-frame
butterfly, a drifting leaf, and a dithered cloud shadow blob for the
outdoor light. (This generator once also drew grass tufts, mushrooms, a
log, reeds, a crate, a barrel and a climbable tree; the packs show all of
those now — CLAUDE.md "Art: Packs First" — so they were removed.)

Same conventions as the other prop generators: exact master-palette members,
painted contact shadow, bottom row of the sprite sits at ground level,
upper-left light. Deterministic seeds.
"""
import math
import random
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

# Exact master-palette members.
FOLIAGE_1 = H("9ad994")
TEAL_3 = H("389878")
TEAL_5 = H("32716c")
TEAL_6 = H("205858")
TEAL_1 = H("62a3b0")
GOLD_1 = H("f9dc3e")
GOLD_2 = H("d8d396")
STEEL_3 = H("f4f9f8")
STEEL_5 = H("d9dec2")
STEEL_6 = H("b6c5c5")
STEEL_8 = H("7c8989")
SKY_7 = H("374e6e")
SKIN_1 = H("f8d098")
SKIN_2 = H("d4ba7e")
LEATHER_2 = H("e09060")
LEATHER_5 = H("a94c1f")
LEATHER_7 = H("9f8156")
LEATHER_9 = H("885038")
LEATHER_11 = H("7f4935")
LEATHER_13 = H("5d3621")
SHADOW_A = (24, 24, 24, 97)
SHADOW_B = (24, 24, 24, 51)

OUT = "assets/textures/props"


def contact_shadow(p, ground, x0, x1, inset=2):
    for x in range(x0, x1):
        p[x, ground + 1] = SHADOW_B
    for x in range(x0 + inset, x1 - inset):
        p[x, ground] = SHADOW_A


def save(img, name):
    img.save(f"{OUT}/{name}.png")
    print(name, img.size)


# ---------------------------------------------------------------- butterfly
def butterfly():
    # Two frames side by side: wings open / wings folded upward.
    FW, FH = 10, 8
    img = Image.new("RGBA", (FW * 2, FH))
    p = img.load()

    def body(ox):
        for y in (3, 4):
            p[ox + 4, y] = LEATHER_13
            p[ox + 5, y] = LEATHER_13

    # Frame 0: wings spread wide.
    body(0)
    for (x, y) in [(2, 2), (3, 2), (2, 3), (3, 3), (6, 2), (7, 2), (6, 3), (7, 3)]:
        p[x, y] = GOLD_1
    for (x, y) in [(1, 3), (2, 4), (7, 4), (8, 3)]:
        p[x, y] = GOLD_2
    p[3, 2] = STEEL_3
    p[6, 2] = STEEL_3
    # Frame 1: wings folded up (narrow, taller).
    body(FW)
    for (x, y) in [(FW + 4, 1), (FW + 5, 1), (FW + 4, 2), (FW + 5, 2)]:
        p[x, y] = GOLD_1
    p[FW + 4, 0] = GOLD_2
    p[FW + 5, 0] = GOLD_2
    save(img, "butterfly")


# --------------------------------------------------------------------- leaf
def leaf():
    # Two frames: tilted left / tilted right, for the falling-leaf flutter.
    FW, FH = 7, 7
    img = Image.new("RGBA", (FW * 2, FH))
    p = img.load()
    for (x, y) in [(2, 3), (3, 2), (3, 3), (4, 3), (3, 4)]:
        p[x, y] = TEAL_3
    p[3, 2] = FOLIAGE_1
    p[4, 4] = TEAL_5
    ox = FW
    for (x, y) in [(ox + 2, 3), (ox + 3, 3), (ox + 4, 2), (ox + 4, 3), (ox + 3, 4)]:
        p[x, y] = TEAL_3
    p[ox + 4, 2] = FOLIAGE_1
    p[ox + 2, 4] = TEAL_5
    save(img, "leaf")


# ------------------------------------------------------------- cloud shadow
def cloud_shadow():
    # A big soft-SHAPED but hard-EDGED blob: two alpha steps, checker-dithered
    # rim — the SNES flying-cloud shadow, not a gradient.
    W, HGT = 64, 44
    rng = random.Random(101)
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    lobes = [(20, 22, 13), (34, 18, 11), (46, 24, 10), (28, 28, 12), (40, 30, 8)]

    def dist(x, y):
        return min(math.hypot(x - cx, y - cy) / r for (cx, cy, r) in lobes)

    CORE = (24, 24, 24, 66)
    RIM = (24, 24, 24, 36)
    for y in range(HGT):
        for x in range(W):
            d = dist(x, y)
            if d < 0.82:
                p[x, y] = CORE
            elif d < 1.0:
                p[x, y] = RIM if (x + y) % 2 == 0 else (24, 24, 24, 0)
    save(img, "cloud_shadow")


butterfly()
leaf()
cloud_shadow()
