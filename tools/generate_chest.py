#!/usr/bin/env python3
"""Treasure chest billboard sprites (closed + open), master-palette colors.

House style: upper-left key light, 4-step wood ramp, iron straps recolored
over the wood silhouette (so they follow the lid curve), gold hasp, painted
two-step contact shadow baked into the sprite (same treatment as the
tree/bush/rock billboards).
"""
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

WOOD_HI = H("e09060")     # LEATHER_2
WOOD = H("885038")        # LEATHER_9
WOOD_SH = H("7f4935")     # LEATHER_11
WOOD_CORE = H("5d3621")   # LEATHER_13
STEEL_HI = H("b6c5c5")    # STEEL_6
STEEL = H("7c8989")       # STEEL_8
STEEL_SH = H("525f5f")    # near STEEL_9, conformed at build time
GOLD_HI = H("f9dc3e")     # GOLD_1
GOLD = H("d8d396")        # GOLD_2
GOLD_SH = H("796b36")     # GOLD_3
DARK = H("2b2540")        # AMETHYST_3 (interior)
SHADOW_A = (24, 24, 24, 97)   # 38% contact core
SHADOW_B = (24, 24, 24, 51)   # 20% contact fringe

W, HGT = 28, 26
GROUND = 24               # baseline row: chest sits here (fringe row below is last)
CX0, CX1 = 3, 24          # chest horizontal extent (22px wide)
STRAPS = (CX0 + 3, CX1 - 4)   # left column of each 2px-wide strap


def canvas():
    return Image.new("RGBA", (W, HGT))


def contact_shadow(p):
    for x in range(CX0 - 1, CX1 + 2):
        p[x, GROUND + 1] = SHADOW_B
    for x in range(CX0, CX1 + 1):
        p[x, GROUND] = SHADOW_A


def rect(p, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            p[x, y] = c


def body_planks(p, y0, y1):
    """Front face of the box: lit rim, plank seam, shaded base."""
    rect(p, CX0, y0, CX1, y1, WOOD)
    for x in range(CX0, CX1 + 1):
        p[x, y0] = WOOD_HI                          # top rim catches the light
        p[x, y1] = WOOD_CORE                        # base line
        p[x, y1 - 1] = WOOD_SH
    seam = y0 + (y1 - y0) // 2
    for x in range(CX0, CX1 + 1):
        p[x, seam] = WOOD_CORE                      # plank seam
    for y in range(y0, y1 + 1):                     # right side falls into shade
        p[CX1, y] = WOOD_SH if p[CX1, y] == WOOD else p[CX1, y]
        p[CX1 - 1, y] = WOOD_SH if p[CX1 - 1, y] == WOOD else p[CX1 - 1, y]


def recolor_straps(p, y0, y1):
    """Iron straps painted over whatever wood is already there, so they
    follow the silhouette exactly (never float past the lid curve)."""
    wood = (WOOD_HI, WOOD, WOOD_SH, WOOD_CORE)
    for sx in STRAPS:
        for y in range(y0, y1 + 1):
            if p[sx, y] in wood:
                p[sx, y] = STEEL_HI if p[sx, y] == WOOD_HI else STEEL
            if p[sx + 1, y] in wood:
                p[sx + 1, y] = STEEL_SH


def chest_closed():
    img = canvas(); p = img.load()
    contact_shadow(p)
    lid_top, split, bot = 6, 12, GROUND
    # Lid: rounded arc of wood
    rect(p, CX0, lid_top + 2, CX1, split - 1, WOOD)
    rect(p, CX0 + 2, lid_top, CX1 - 2, lid_top + 1, WOOD)
    p[CX0 + 1, lid_top + 1] = WOOD
    p[CX1 - 1, lid_top + 1] = WOOD
    for x in range(CX0 + 2, CX1 - 1):
        p[x, lid_top] = WOOD_HI                     # lit crown
    p[CX0 + 1, lid_top + 1] = WOOD_HI
    for y in range(lid_top + 1, split):             # right of lid shaded
        for x in (CX1, CX1 - 1):
            if p[x, y] == WOOD:
                p[x, y] = WOOD_SH
    for x in range(CX0, CX1 + 1):                   # lid/body split
        p[x, split - 1] = WOOD_CORE
    # Body
    body_planks(p, split, bot)
    recolor_straps(p, lid_top, bot)
    # Gold hasp over the split
    lx = (CX0 + CX1) // 2 - 1
    rect(p, lx, split - 2, lx + 2, split + 2, GOLD)
    p[lx, split - 2] = GOLD_HI
    p[lx + 1, split - 2] = GOLD_HI
    for x in range(lx, lx + 3):
        p[x, split + 2] = GOLD_SH
    p[lx + 1, split + 1] = DARK                     # keyhole
    return img


def chest_open():
    img = canvas(); p = img.load()
    contact_shadow(p)
    split, bot = 12, GROUND
    # Lid thrown back: its shaded underside shows as a slab behind the body,
    # slightly narrower than the box.
    ly0, ly1 = 2, 7
    rect(p, CX0 + 1, ly0 + 1, CX1 - 1, ly1, WOOD_SH)
    for x in range(CX0 + 2, CX1 - 1):
        p[x, ly0] = WOOD                            # far edge of the lid
    rect(p, CX0 + 4, ly0 + 2, CX1 - 4, ly1 - 1, WOOD_CORE)  # inner panel
    recolor_straps(p, ly0, ly1)
    # Interior mouth between lid and rim
    rect(p, CX0 + 1, ly1 + 1, CX1 - 1, split - 2, DARK)
    p[CX0 + 1, ly1 + 1] = WOOD_SH                   # box side walls peeking
    p[CX1 - 1, ly1 + 1] = WOOD_SH
    # Gold hoard heaped up out of the mouth
    gy = split - 2
    for x in range(CX0 + 3, CX1 - 2):
        p[x, gy] = GOLD
    for x in range(CX0 + 5, CX1 - 4):
        if (x % 2) == 0:
            p[x, gy - 1] = GOLD
    for x in (CX0 + 6, (CX0 + CX1) // 2, CX1 - 6):
        p[x, gy - 1] = GOLD_HI                      # glints
    # Body
    body_planks(p, split, bot)
    recolor_straps(p, split, bot)
    # Hasp hangs open on the front, duller now
    lx = (CX0 + CX1) // 2 - 1
    rect(p, lx, split + 1, lx + 2, split + 3, GOLD_SH)
    p[lx + 1, split + 1] = GOLD
    return img


chest_closed().save("assets/textures/props/chest_closed.png")
chest_open().save("assets/textures/props/chest_open.png")
print("chest_closed / chest_open", (W, HGT))
