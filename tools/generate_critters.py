#!/usr/bin/env python3
"""Tiny ambient-critter billboard: the forest squirrel, a side-view pixel
rodent with a painted one-row contact shadow. No pack draws a squirrel;
the sewer mouse is the giant-rat pack's Rat1 shrunk down (sewer_critter.gd),
so this generator no longer draws one."""
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
SHADOW = (24, 24, 24, 80)


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


squirrel()
