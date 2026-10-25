#!/usr/bin/env python3
"""Scenery-pass billboard props (master-palette colors).

The small atmospheric sprites no purchased pack draws: a two-frame
butterfly, a drifting leaf, a dithered cloud shadow blob for the
outdoor light, and the dirt mound over a burrowed bull worm. (This generator once also drew grass tufts, mushrooms, a
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


def worm_mound():
    # The heaped earth over a burrowed Alaskan Bull Worm (Worms Armageddon).
    # No pack draws a dirt mound, so it is cut from the pack's own field-dirt
    # tile (floor_dirt_field.png, 32 texels a tile like the floor it sits on)
    # and shaded as a lumpy dome — upper-left light, a dark outline, clods
    # thrown up round it and the dark mouth of the burrow on top — so it
    # reads as the same earth.
    dirt = Image.open("assets/textures/craftpix/floor_dirt_field.png").convert("RGB")
    W, HGT = 42, 24
    cx, cy, rx, ry = 20.5, 13.0, 17.0, 8.0
    rng = random.Random(77)
    bumps = [rng.uniform(-0.09, 0.09) for _ in range(12)]

    def edge(x, y):   # <1 inside; a lumpy outline (radius wobbles by angle)
        nx, ny = (x - cx) / rx, (y - cy) / ry
        a = (math.atan2(ny, nx) / (2 * math.pi) + 1.0) * 12
        k = int(a) % 12
        f = a - int(a)
        wob = bumps[k] * (1 - f) + bumps[(k + 1) % 12] * f
        return math.hypot(nx, ny) / (1.0 + wob), nx, ny

    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    d = dirt.load()

    def tone(x, y, light):
        c = d[(x + 44) % dirt.width, (y + 52) % dirt.height]
        return tuple(max(0, min(255, int(v * light))) for v in c) + (255,)

    for y in range(HGT):
        for x in range(W):
            r, nx, ny = edge(x, y)
            if r > 1.0:
                continue
            dome = math.sqrt(max(0.0, 1.0 - r * r))          # height of the heap here
            light = 0.62 + 0.55 * dome - 0.28 * ny - 0.14 * nx
            if r > 0.86:
                light = 0.42                                  # outline
            hole = ((x - cx) / 4.0) ** 2 + ((y - (cy - 2.0)) / 1.8) ** 2
            if hole <= 1.0:
                light = 0.22 if hole <= 0.5 else 0.45         # the burrow's mouth
            elif hole <= 1.9 and y < cy - 2.0:
                light *= 0.8                                  # its far lip in shade
            elif hole <= 2.2 and y > cy - 2.0:
                light *= 1.15                                 # its near lip catches light
            p[x, y] = tone(x, y, light)
    # Clods: lit lumps with a shaded underside on the heap, and a few
    # thrown just past its rim.
    for _ in range(14):
        ang = rng.uniform(0, 2 * math.pi)
        rad = rng.uniform(0.35, 1.12)
        x = int(round(cx + math.cos(ang) * rx * rad))
        y = int(round(cy + math.sin(ang) * ry * rad))
        if not (1 <= x < W - 2 and 1 <= y < HGT - 2):
            continue
        if ((x - cx) / 5.5) ** 2 + ((y - (cy - 2.0)) / 2.6) ** 2 <= 1.0:
            continue
        p[x, y] = tone(x, y, 1.25)
        p[x + 1, y] = tone(x + 1, y, 1.05)
        p[x, y + 1] = tone(x, y + 1, 0.55)
        p[x + 1, y + 1] = tone(x + 1, y + 1, 0.45)
    save(img, "worm_mound")


butterfly()
leaf()
cloud_shadow()
worm_mound()
