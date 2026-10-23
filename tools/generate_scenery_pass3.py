#!/usr/bin/env python3
"""Scenery pass 3 billboard props (master-palette colors).

Third environment pass. What is left is the one piece no purchased pack
draws:
  - signpost: a wooden post with an arrow board, for trail junctions
(It once also drew pebbles, a berry bush, bones, a crystal cluster and a
ground crow; the packs show all of those now — CLAUDE.md "Art: Packs
First" — so they were removed.)

Same conventions as the other prop generators: exact master-palette members,
painted contact shadow, bottom row of the sprite sits at ground level,
upper-left light. Deterministic seeds.
"""
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

# Exact master-palette members.
FOLIAGE_1 = H("9ad994")
TEAL_1 = H("62a3b0")
TEAL_3 = H("389878")
TEAL_5 = H("32716c")
GOLD_2 = H("d8d396")
STEEL_3 = H("f4f9f8")
STEEL_5 = H("d9dec2")
STEEL_6 = H("b6c5c5")
STEEL_8 = H("7c8989")
SKY_7 = H("374e6e")
SKY_9 = H("203440")
BLOOD_1 = H("e06969")
BLOOD_3 = H("b74248")
BLOOD_5 = H("96232c")
LEATHER_2 = H("e09060")
LEATHER_7 = H("9f8156")
LEATHER_9 = H("885038")
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


# ----------------------------------------------------------------- signpost
def signpost():
    W, HGT = 20, 30
    ground = 28
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 6, 14, 2)
    # Post: lit west face, dark east face.
    for y in range(6, ground):
        p[9, y] = LEATHER_9
        p[10, y] = LEATHER_13
    # Board with an arrow point on the east end.
    for y in range(5, 13):
        for x in range(2, 17):
            p[x, y] = LEATHER_7
    for x in range(2, 17):
        p[x, 5] = LEATHER_2      # lit top edge
        p[x, 12] = LEATHER_13    # underside
    for y in range(5, 13):
        p[2, y] = LEATHER_2
    for (x, y0, y1) in [(17, 6, 12), (18, 7, 11), (19, 8, 10)]:
        for y in range(y0, y1):
            p[x, y] = LEATHER_7
        p[x, y0] = LEATHER_2
        p[x, y1 - 1] = LEATHER_13
    # Carved "lettering": two rows of scratches.
    for x in range(4, 15, 2):
        p[x, 8] = LEATHER_13
    for x in range(5, 14, 3):
        p[x, 10] = LEATHER_13
    # Nails holding the board to the post.
    p[9, 7] = STEEL_6
    p[10, 10] = STEEL_6
    save(img, "signpost")


signpost()
