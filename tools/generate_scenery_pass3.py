#!/usr/bin/env python3
"""Scenery pass 3 billboard props (master-palette colors).

Third environment pass — the dressing that gives each location a few more
landmarks and some life at ground level:
  - pebbles: a scatter of small stones for trail edges and cave floors
  - signpost: a wooden post with an arrow board, for trail junctions
  - bush_berry: the meadow bush with a crop of red berries
  - bones: a skull and rib fragments for caves and sewers
  - crystal: a teal crystal cluster for cave walls
  - critter_crow: a two-frame ground crow (standing / pecking) for meadows

Same conventions as the other prop generators: exact master-palette members,
painted contact shadow, bottom row of the sprite sits at ground level,
upper-left light. Deterministic seeds.
"""
import random
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


# ------------------------------------------------------------------ pebbles
def pebbles():
    W, HGT = 14, 8
    ground = 6
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 1, 13, 2)
    # Three stones: (x0, x1, top). Lit upper-left, dark underside.
    for (x0, x1, top) in [(1, 5, 3), (6, 11, 2), (11, 14, 4)]:
        for x in range(x0, x1):
            for y in range(top, ground):
                p[x, y] = STEEL_8
            p[x, ground - 1] = SKY_7
        p[x0, top] = STEEL_6
        p[x0 + 1, top] = STEEL_6
        p[x0, top + 1] = STEEL_6
        p[x1 - 1, top] = (0, 0, 0, 0)  # knock the corner off
    save(img, "pebbles")


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


# --------------------------------------------------------------- berry bush
def bush_berry():
    src = Image.open(f"{OUT}/bush.png").convert("RGBA")
    img = src.copy()
    p = img.load()
    W, HGT = img.size
    rng = random.Random(23)
    leafy = {TEAL_3[:3], TEAL_5[:3], FOLIAGE_1[:3]}
    # The stock bush carries two pink accents — turn those red.
    for y in range(HGT):
        for x in range(W):
            if p[x, y][3] == 255 and p[x, y][:3] == (248, 144, 208):
                p[x, y] = BLOOD_3
    # A crop of berries across the mid/lit foliage, each with a highlight.
    spots = [(x, y) for y in range(7, 17) for x in range(6, 26)
             if p[x, y][3] == 255 and p[x, y][:3] in leafy]
    rng.shuffle(spots)
    placed = []
    for (x, y) in spots:
        if len(placed) >= 9:
            break
        if any(abs(x - px) < 3 and abs(y - py) < 3 for (px, py) in placed):
            continue
        p[x, y] = BLOOD_3
        if p[x + 1, y][3] == 255:
            p[x + 1, y] = BLOOD_5
        if p[x, y - 1][3] == 255 and p[x, y - 1][:3] in leafy:
            p[x, y - 1] = BLOOD_1
        placed.append((x, y))
    save(img, "bush_berry")


# -------------------------------------------------------------------- bones
def bones():
    W, HGT = 18, 10
    ground = 8
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 2, 17, 2)
    # Skull: rounded cranium, two dark sockets, a row of teeth.
    for y in range(2, 8):
        for x in range(3, 9):
            p[x, y] = STEEL_5
    p[3, 2] = (0, 0, 0, 0)
    p[8, 2] = (0, 0, 0, 0)
    for (x, y) in [(4, 2), (5, 2), (3, 3), (4, 3)]:
        p[x, y] = STEEL_3
    for x in range(3, 9):
        p[x, 7] = STEEL_8
    p[4, 4] = SKY_7
    p[5, 4] = SKY_7
    p[7, 4] = SKY_7
    p[6, 5] = STEEL_8            # nose notch
    for x in range(4, 8):
        p[x, 6] = STEEL_3 if x % 2 == 0 else SKY_7
    # Rib fragments: two pale arcs with shaded undersides.
    for (x0, y0) in [(10, 3), (13, 4)]:
        p[x0, y0 + 2] = STEEL_6
        p[x0 + 1, y0 + 1] = STEEL_6
        p[x0 + 2, y0] = STEEL_6
        p[x0 + 3, y0] = STEEL_6
        p[x0 + 4, y0 + 1] = STEEL_8
        p[x0 + 1, y0 + 2] = STEEL_8
        p[x0 + 2, y0 + 1] = STEEL_3
    # A stray long bone lying flat.
    for x in range(9, 17):
        p[x, 7] = STEEL_6
    p[9, 6] = STEEL_5
    p[16, 6] = STEEL_5
    p[9, 7] = STEEL_8
    p[16, 7] = STEEL_8
    save(img, "bones")


# ------------------------------------------------------------------ crystal
def crystal():
    W, HGT = 16, 22
    ground = 20
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    contact_shadow(p, ground, 1, 15, 2)
    # Three shards: (x0, x1, top). Each tapers to a point; lit west facet.
    for (x0, x1, top) in [(2, 6, 9), (6, 10, 2), (10, 15, 6)]:
        mid = (x0 + x1 - 1) / 2.0
        for y in range(top, ground):
            spread = (y - top) / float(ground - top)
            half = max(0.4, spread * (x1 - x0) / 2.0)
            for x in range(x0, x1):
                if abs(x - mid) <= half:
                    p[x, y] = TEAL_1 if x <= mid else TEAL_5
        # Facet highlight down the lit edge, dark base band.
        for y in range(top + 2, ground - 2):
            x = x0 + int((y - top) / float(ground - top) * 1.5)
            if p[x, y][3] == 255:
                p[x, y] = STEEL_3 if (y - top) % 3 else TEAL_1
        p[int(mid), top] = STEEL_3
        for x in range(x0, x1):
            if p[x, ground - 1][3] == 255:
                p[x, ground - 1] = SKY_7
    save(img, "crystal")


# --------------------------------------------------------------------- crow
def crow():
    # Two frames side by side: standing (head up) / pecking (head down).
    FW, FH = 12, 10
    ground = 8
    img = Image.new("RGBA", (FW * 2, FH))
    p = img.load()

    def body(ox):
        for x in range(ox + 3, ox + 9):      # low body
            p[x, 5] = SKY_9
            p[x, 6] = SKY_9
        for x in range(ox + 4, ox + 8):
            p[x, 4] = SKY_9
        p[ox + 4, 4] = SKY_7                 # wing highlight (upper-left light)
        p[ox + 5, 4] = SKY_7
        for x in range(ox + 1, ox + 4):      # tail feathers trailing west
            p[x, 4 + (x - ox) % 2] = SKY_9
        p[ox + 5, 7] = SKY_7                 # legs
        p[ox + 7, 7] = SKY_7
        for x in range(ox + 2, ox + 10):     # painted contact shadow
            p[x, ground] = SHADOW_A

    # Frame 0: head up, looking about.
    body(0)
    for (x, y) in [(8, 3), (9, 3), (9, 2), (8, 2)]:
        p[x, y] = SKY_9
    p[9, 2] = STEEL_3                          # eye glint
    p[10, 3] = GOLD_2                          # beak
    p[11, 3] = GOLD_2
    # Frame 1: head down, pecking the ground.
    body(FW)
    for (x, y) in [(FW + 9, 5), (FW + 10, 5), (FW + 9, 6), (FW + 10, 6)]:
        p[x, y] = SKY_9
    p[FW + 10, 5] = STEEL_3
    p[FW + 11, 7] = GOLD_2
    p[FW + 10, 7] = GOLD_2
    save(img, "critter_crow")


pebbles()
signpost()
bush_berry()
bones()
crystal()
crow()
