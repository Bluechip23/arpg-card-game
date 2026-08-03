#!/usr/bin/env python3
"""Tiny ambient-critter billboards: sewer mouse and forest squirrel.
Side-view pixel rodents with a painted one-row contact shadow."""
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
SHADOW = (24, 24, 24, 80)


def mouse():
    BODY = H("453f60")     # AMETHYST_1 (dark grey-violet fur in the gloom)
    BODY_SH = H("2b2540")  # AMETHYST_3
    img = Image.new("RGBA", (14, 9))
    p = img.load()
    for x in range(4, 12):                 # low humped body
        p[x, 5] = BODY
        p[x, 6] = BODY_SH
    for x in range(5, 11):
        p[x, 4] = BODY
    for x in range(6, 9):
        p[x, 3] = BODY
    p[11, 4] = BODY                        # head/snout
    p[12, 5] = BODY_SH
    p[10, 3] = BODY_SH                     # ear
    p[11, 3] = (0, 0, 0, 255)              # eye
    for i, x in enumerate(range(1, 4)):    # thin tail
        p[x, 6 - (i % 2)] = BODY_SH
    for x in range(3, 13):
        p[x, 8] = SHADOW
    img.save("assets/textures/props/critter_mouse.png")
    print("critter_mouse", img.size)


def squirrel():
    FUR = H("885038")      # LEATHER_9 (red-brown)
    FUR_HI = H("e09060")   # LEATHER_2
    FUR_SH = H("5d3621")   # LEATHER_13
    img = Image.new("RGBA", (14, 12))
    p = img.load()
    for x in range(5, 11):                 # body
        p[x, 8] = FUR
        p[x, 9] = FUR_SH
    for x in range(6, 10):
        p[x, 7] = FUR
    p[10, 6] = FUR                         # head up
    p[11, 7] = FUR
    p[10, 5] = FUR_SH                      # ear
    p[11, 6] = (0, 0, 0, 255)              # eye
    # Bushy tail arcing over the back.
    for (x, y) in [(4, 8), (3, 7), (2, 6), (2, 5), (3, 4), (4, 3), (5, 3)]:
        p[x, y] = FUR
    for (x, y) in [(3, 6), (3, 5), (4, 4)]:
        p[x, y] = FUR_HI
    for x in range(3, 12):
        p[x, 11] = SHADOW
    img.save("assets/textures/props/critter_squirrel.png")
    print("critter_squirrel", img.size)


mouse()
squirrel()
