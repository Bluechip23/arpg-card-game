#!/usr/bin/env python3
"""Scenery-pass billboard props (master-palette colors).

Second environment pass: the small dressing that makes the world read as a
lived-in Secret-of-Mana field rather than an arena — tall grass tufts,
mushroom clumps (meadow + pale cave variant), a fallen mossy log, water-edge
reeds, crate/barrel furniture for building interiors, a two-frame butterfly,
a drifting leaf, and a dithered cloud shadow blob for the outdoor light.

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


# ---------------------------------------------------------------- grass tuft
# A clump of tall blades — the workhorse meadow filler. Blades lean apart,
# shaded left-dark right... no: light is upper-LEFT, so left blades get the
# highlight and the clump core stays dark.
def grass_tuft():
    W, HGT = 14, 12
    ground = 10
    rng = random.Random(31)
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 2, 12, 2)
    blades = [(3, 4, -1), (5, 6, 0), (7, 7, 0), (9, 6, 0), (11, 4, 1)]
    for (bx, h, lean) in blades:
        col = TEAL_5 if abs(bx - 7) > 3 else TEAL_3
        x = bx
        for dy in range(h):
            y = ground - 1 - dy
            if dy > h * 0.55:
                x = bx + lean
            p[x, y] = col
        # Lit tip (upper-left light): west-side blades catch the sun.
        tip_y = ground - h
        if bx <= 7:
            p[x, tip_y] = FOLIAGE_1
    # Dark core pixels root the clump.
    for x in range(5, 10):
        p[x, ground - 1] = TEAL_6
    save(img, "grass_tuft")


# ----------------------------------------------------------------- mushrooms
def mushrooms(name, cap, cap_hi, cap_sh, stem, stem_sh, speck):
    W, HGT = 16, 13
    ground = 11
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 2, 14, 2)
    shrooms = [(4, 5, 3), (10, 3, 4)]  # (cx, cap_y, cap_half_w)
    for (cx, cap_y, hw) in shrooms:
        # Stem down to the ground row.
        for y in range(cap_y + 2, ground):
            p[cx, y] = stem
            p[cx + 1, y] = stem_sh
        # Cap: a dome two rows tall plus a wide brim row.
        for dx in range(-hw + 1, hw):
            p[cx + dx, cap_y + 1] = cap
        for dx in range(-hw + 2, hw - 1):
            p[cx + dx, cap_y] = cap
        # Brim shadow under the cap; highlight along the upper-left curve.
        for dx in range(-hw + 1, hw):
            p[cx + dx, cap_y + 2] = cap_sh
        p[cx - hw + 2, cap_y] = cap_hi
        p[cx - hw + 3, cap_y] = cap_hi
        p[cx - hw + 1, cap_y + 1] = cap_hi
        # Speckles.
        p[cx + 1, cap_y] = speck
        p[cx - 1, cap_y + 1] = speck
    save(img, name)


# --------------------------------------------------------------- fallen log
def fallen_log():
    W, HGT = 36, 16
    ground = 14
    rng = random.Random(17)
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 1, 35, 3)
    top, bot = 5, ground  # trunk band
    for x in range(2, 34):
        for y in range(top, bot):
            if y == top:
                c = LEATHER_2          # lit top edge
            elif y <= top + 3:
                c = LEATHER_9          # upper bark
            elif y <= top + 6:
                c = LEATHER_11         # lower bark
            else:
                c = LEATHER_13         # underside core
            p[x, y] = c
    # Bark cracks: short dark verticals.
    for x in range(4, 33, 4):
        for y in range(top + 2 + (x // 4) % 2, top + 6):
            p[x, y] = LEATHER_13
    # End grain on the east cut face.
    for y in range(top, bot):
        p[33, y] = SKIN_2 if top + 1 < y < bot - 2 else LEATHER_9
        p[34, y] = LEATHER_9
    p[33, top + 3] = LEATHER_7
    p[33, top + 5] = LEATHER_7
    # Moss saddle along the lit top.
    for x in range(5, 26):
        if rng.random() < 0.7:
            p[x, top] = TEAL_3
        if rng.random() < 0.35:
            p[x, top + 1] = TEAL_5
    for x in (7, 13, 20):
        p[x, top - 1] = TEAL_3
        p[x + 1, top - 1] = FOLIAGE_1
    # A couple of tiny shelf fungi.
    for (fx, fy) in [(10, top + 4), (24, top + 3)]:
        p[fx, fy] = LEATHER_2
        p[fx + 1, fy] = SKIN_2
    save(img, "log")


# -------------------------------------------------------------------- reeds
def reeds():
    W, HGT = 14, 22
    ground = 20
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 2, 12, 2)
    stalks = [(3, 12, False), (6, 17, True), (9, 15, True), (12, 10, False)]
    for (sx, h, head) in stalks:
        col = TEAL_5 if sx in (3, 12) else TEAL_3
        for dy in range(h):
            p[sx, ground - 1 - dy] = col
        tip = ground - h
        if head:
            # Cattail seed head: a 2x4 brown lozenge below a pale tip.
            for dy in range(1, 5):
                p[sx, tip + dy] = LEATHER_9
                p[sx - 1, tip + dy] = LEATHER_11
            p[sx, tip] = SKIN_2
        else:
            p[sx, tip] = FOLIAGE_1
    # Blade leaves leaning off the clump.
    for (sx, sy) in [(4, ground - 6), (10, ground - 8)]:
        p[sx + 1, sy] = TEAL_3
        p[sx + 2, sy - 1] = FOLIAGE_1
    save(img, "reeds")


# -------------------------------------------------------------------- crate
def crate():
    W, HGT = 22, 20
    ground = 18
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 1, 21, 2)
    x0, x1, y0, y1 = 2, 20, 2, ground
    for x in range(x0, x1):
        for y in range(y0, y1):
            band = (y - y0) * 4 // (y1 - y0)
            c = [LEATHER_7, LEATHER_9, LEATHER_9, LEATHER_11][band]
            p[x, y] = c
    # Plank seams.
    for y in (y0 + 4, y0 + 8, y0 + 12):
        for x in range(x0, x1):
            p[x, y] = LEATHER_13
    # Frame: lit top/left, dark bottom/right (upper-left light).
    for x in range(x0, x1):
        p[x, y0] = LEATHER_2
        p[x, y1 - 1] = LEATHER_13
    for y in range(y0, y1):
        p[x0, y] = LEATHER_2
        p[x1 - 1, y] = LEATHER_13
    # Diagonal brace.
    for i in range(x1 - x0 - 2):
        y = y0 + 1 + i * (y1 - y0 - 2) // (x1 - x0 - 2)
        p[x0 + 1 + i, y] = LEATHER_7
    # Corner nails.
    for (nx, ny) in [(x0 + 1, y0 + 1), (x1 - 2, y0 + 1), (x0 + 1, y1 - 2), (x1 - 2, y1 - 2)]:
        p[nx, ny] = STEEL_6
    save(img, "crate")


# ------------------------------------------------------------------- barrel
def barrel():
    W, HGT = 18, 22
    ground = 20
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 1, 17, 2)
    y0, y1 = 2, ground
    mid = (y0 + y1) // 2
    for y in range(y0, y1):
        # Bulge: wider at the waist.
        bulge = 1 if y in (y0, y1 - 1) else 0
        xa, xb = 3 + bulge - 1, 15 - bulge + 1
        for x in range(xa, xb):
            third = (x - xa) * 3 // max(1, xb - xa)
            c = [LEATHER_7, LEATHER_9, LEATHER_11][third]
            p[x, y] = c
    # Stave seams.
    for x in (6, 9, 12):
        for y in range(y0, y1):
            p[x, y] = LEATHER_13
    # Iron hoops.
    for hy in (y0 + 2, mid, y1 - 3):
        for x in range(2, 16):
            p[x, hy] = STEEL_8
        p[2, hy] = STEEL_6
        p[3, hy] = STEEL_6
    # Lit rim.
    for x in range(4, 14):
        p[x, y0] = LEATHER_2
    save(img, "barrel")


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


grass_tuft()
mushrooms("mushroom", LEATHER_5, LEATHER_2, LEATHER_13, SKIN_2, LEATHER_7, SKIN_1)
mushrooms("mushroom_pale", STEEL_6, STEEL_3, SKY_7, STEEL_5, STEEL_8, TEAL_1)
fallen_log()
reeds()
crate()
barrel()
butterfly()
leaf()
cloud_shadow()
