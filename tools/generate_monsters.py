#!/usr/bin/env python3
"""Generated monster battlers, iteration 2-3 (see docs/STORY.md bestiary).

64x64 cells, master-palette 4-step ramps, single upper-left light painted via
ramp-shaded primitives (forms read round, not banded), selective hue-shifted
outlines, ground line y=57. Floaters carry a painted contact shadow and are
excluded from the runtime blob shadow.

Still engineered placeholders — docs/ART_TODO.md tracks hand-drawn art — but
each creature follows its bestiary description (crowned Rat King, kiting
Archer Rat with a bow, hunched regenerating trolls, gravestone titan, ...).
"""
import math
from PIL import Image

W = H = 64
GROUND = 57

HEX = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

# 4-step ramps: highlight, base, shadow, core (hue-shifted per style guide)
RAMPS = {
    "grey":    [HEX("f2fdff"), HEX("b6c5c5"), HEX("8898a0"), HEX("52525f")],
    "steel":   [HEX("f2fdff"), HEX("b6c5c5"), HEX("63778f"), HEX("3c5575")],
    "stone":   [HEX("b6c5c5"), HEX("8898a0"), HEX("63778f"), HEX("3c5575")],
    "moss":    [HEX("9ad994"), HEX("389878"), HEX("32716c"), HEX("205858")],
    "leaf":    [HEX("9ad994"), HEX("389878"), HEX("206020"), HEX("205858")],
    "leather": [HEX("e09060"), HEX("a94c1f"), HEX("6b533e"), HEX("452e5b")],
    "fur":     [HEX("d08860"), HEX("a78e51"), HEX("6b533e"), HEX("452e5b")],
    "blood":   [HEX("e06969"), HEX("aa5553"), HEX("96232c"), HEX("602323")],
    "dark_red": [HEX("c78175"), HEX("96232c"), HEX("602323"), HEX("452e5b")],
    "violet":  [HEX("737ec4"), HEX("53539c"), HEX("453f60"), HEX("2b2540")],
    "night":   [HEX("53539c"), HEX("453f60"), HEX("2b2540"), HEX("2b2540")],
    "bone":    [HEX("f6f1d7"), HEX("d9dec2"), HEX("b6c5c5"), HEX("63778f")],
    "gold":    [HEX("f9dc3e"), HEX("d8d396"), HEX("796b36"), HEX("454831")],
}
OUT = HEX("2b2540")
EYE = HEX("181818")
GLOW = HEX("f9dc3e")
ICE_EYE = HEX("3c5575")
WHITE = HEX("f2fdff")
SKIN = HEX("c6a891")
PINK = HEX("c78175")


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.px = self.img.load()

    # ---- ramp-shaded primitives (light from upper-left) ----
    def sphere(self, cx, cy, rx, ry, ramp):
        """Ellipse shaded as a round form: highlight up-left, core low-right."""
        for y in range(max(0, int(cy - ry)), min(H, int(cy + ry) + 1)):
            for x in range(max(0, int(cx - rx)), min(W, int(cx + rx) + 1)):
                nx = (x - cx) / rx
                ny = (y - cy) / ry
                t = nx * nx + ny * ny
                if t > 1.0:
                    continue
                lit = -(nx + ny) * 0.5 - t * 0.9
                if lit > -0.05:
                    col = ramp[0]
                elif lit > -0.62:
                    col = ramp[1]
                elif lit > -1.15:
                    col = ramp[2]
                else:
                    col = ramp[3]
                self.px[x, y] = col

    def slab(self, x0, y0, x1, y1, ramp, bevel=2):
        """Rect shaded like a chiselled block: top-lit, right/bottom in shadow."""
        for y in range(max(0, y0), min(H, y1)):
            for x in range(max(0, x0), min(W, x1)):
                if y < y0 + bevel and x < x1 - bevel:
                    col = ramp[0]
                elif x >= x1 - bevel or y >= y1 - bevel:
                    col = ramp[2]
                else:
                    col = ramp[1]
                self.px[x, y] = col

    def flat(self, x0, y0, x1, y1, col):
        for y in range(max(0, y0), min(H, y1)):
            for x in range(max(0, x0), min(W, x1)):
                self.px[x, y] = col

    def tri(self, p0, p1, p2, col):
        xs = [p[0] for p in (p0, p1, p2)]
        ys = [p[1] for p in (p0, p1, p2)]
        def edge(a, b, p):
            return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        for y in range(max(0, min(ys)), min(H, max(ys) + 1)):
            for x in range(max(0, min(xs)), min(W, max(xs) + 1)):
                d0 = edge(p0, p1, (x, y)); d1 = edge(p1, p2, (x, y)); d2 = edge(p2, p0, (x, y))
                if not (((d0 < 0) or (d1 < 0) or (d2 < 0)) and ((d0 > 0) or (d1 > 0) or (d2 > 0))):
                    self.px[x, y] = col

    def limb(self, x0, y0, x1, y1, w, ramp):
        """Thick shaded line — arms, legs, necks, tails."""
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            t = i / steps
            cx = x0 + (x1 - x0) * t
            cy = y0 + (y1 - y0) * t
            self.sphere(cx, cy, w, w, ramp)

    def painted_shadow(self, cx, rx):
        for y in range(GROUND - 1, GROUND + 2):
            for x in range(W):
                if ((x - cx) / rx) ** 2 + ((y - GROUND) / 2.0) ** 2 <= 1.0:
                    self.px[x, y] = (0, 0, 0, 90)

    def outline(self):
        edges = []
        for y in range(H):
            for x in range(W):
                if self.px[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < W and 0 <= ny < H and self.px[nx, ny][3] > 120:
                            edges.append((x, y, dx, dy))
                            break
        for x, y, dx, dy in edges:
            if dy == -1 or (dx == -1 and y > 20) or (dx == 1 and y > 26):
                self.px[x, y] = OUT

    def dot(self, x, y, col):
        self.px[int(x), int(y)] = col

    def save(self, name):
        self.img.save(f"assets/sprites/generated/monsters/{name}.png")
        print(name)


# =====================================================================
# Shared bodies
# =====================================================================

def troll_body(c, ramp, belly_ramp):
    """Hunched brute: knuckle-walking arms, heavy shoulders, underbite head."""
    # legs — short, thick
    c.limb(26, 48, 24, 55, 3, ramp)
    c.limb(38, 48, 40, 55, 3, ramp)
    # hunched torso: big shoulder mass tilting forward-left
    c.sphere(33, 36, 15, 13, ramp)
    c.sphere(31, 44, 10, 8, belly_ramp)          # belly
    # long arms down to the ground, knuckles
    c.limb(19, 32, 13, 52, 3.4, ramp)
    c.limb(47, 32, 51, 52, 3.4, ramp)
    c.sphere(13, 53, 4, 3, ramp)
    c.sphere(51, 53, 4, 3, ramp)
    # head sunk into the shoulders, jutting jaw
    c.sphere(32, 22, 8, 7, ramp)
    c.sphere(32, 26, 9, 4, belly_ramp)           # jaw
    # underbite tusks rising over the jaw line
    for tx in (25, 39):
        c.px[tx, 25] = RAMPS["bone"][0]
        c.px[tx, 24] = RAMPS["bone"][0]
        c.px[tx, 23] = RAMPS["bone"][1]
    return 21  # eye line


def bull_head(c, cx, cy, ramp):
    c.sphere(cx, cy, 8, 7, ramp)                              # skull
    c.sphere(cx, cy + 5, 5, 3.4, [SKIN, SKIN, RAMPS["fur"][2], RAMPS["fur"][3]])  # muzzle
    c.px[cx - 2, cy + 5] = OUT; c.px[cx + 2, cy + 5] = OUT    # nostrils
    # horns: thick, sweeping out then curving up
    for s in (-1, 1):
        c.limb(cx + s * 6, cy - 3, cx + s * 11, cy - 4, 2.2, RAMPS["bone"])
        c.limb(cx + s * 11, cy - 4, cx + s * 13, cy - 10, 1.7, RAMPS["bone"])


def bat_wing(c, sx, sy, direction, size, ramp):
    """Folded membrane wing with two ribs. direction: -1 left, +1 right."""
    tip = (sx + direction * size, sy - size)
    mid = (sx + direction * int(size * 0.8), sy + int(size * 0.55))
    c.tri((sx, sy), tip, mid, ramp[2])
    c.tri((sx, sy), mid, (sx + direction * int(size * 0.35), sy + int(size * 0.8)), ramp[3])
    # rib highlights
    c.limb(sx, sy, tip[0], tip[1], 1, ramp)


# =====================================================================
# Creatures
# =====================================================================

def rat_base(c, ramp):
    """Compact sewer rat, low and sleek (bestiary: scurries and bites)."""
    # tail whipping behind
    pts = [(44, 52), (50, 49), (55, 50), (59, 53), (61, 51)]
    for i in range(len(pts) - 1):
        c.limb(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 1, [SKIN, SKIN, SKIN, SKIN])
    c.sphere(36, 50, 9, 6, ramp)     # haunch
    c.sphere(27, 51, 8, 5, ramp)     # body
    c.sphere(18, 51, 5, 4, ramp)     # head
    c.tri((10, 51), (14, 48), (14, 54), ramp[2])  # snout
    c.sphere(21, 45, 2.6, 2.6, ramp)  # ear
    c.px[21, 45] = PINK
    for lx in (16, 23, 33, 40):
        c.flat(lx, 54, lx + 2, GROUND, ramp[2])
    c.px[16, 50] = EYE
    c.px[16, 49] = WHITE


def build_rat():
    c = Canvas()
    rat_base(c, RAMPS["grey"])
    c.outline(); c.save("rat")


def build_archer_rat():
    c = Canvas()
    rat_base(c, RAMPS["fur"])
    # a recurve bow slung across the back (the Archer Rat kites)
    for t in range(20):
        ang = 2.0 + t * 0.075
        bx = 33 + 8.0 * math.cos(ang)
        by = 46 + 8.0 * math.sin(ang)
        c.px[int(bx), int(by)] = RAMPS["leather"][1]
        c.px[int(bx), int(by) - 1] = RAMPS["leather"][0]
    for t in range(12):  # string
        c.px[int(28 + t * 0.9), int(38 + t * 1.35)] = RAMPS["bone"][1]
    c.outline(); c.save("archer_rat")


def build_rat_king():
    c = Canvas()
    rat_base(c, RAMPS["grey"])
    # regal cape draped over the back, behind the crown
    c.tri((22, 47), (43, 46), (35, 55), RAMPS["blood"][2])
    c.tri((24, 48), (40, 47), (33, 53), RAMPS["blood"][1])
    # the crown (bestiary: "a crowned rat") sits ON the head
    c.flat(14, 44, 23, 47, RAMPS["gold"][0])
    for px_ in (14, 18, 21):
        c.tri((px_, 44), (px_ + 2, 44), (px_ + 1, 41), RAMPS["gold"][0])
    c.px[16, 45] = RAMPS["blood"][1]; c.px[20, 45] = RAMPS["violet"][0]  # jewels
    c.outline(); c.save("rat_king")


def build_armored_troll():
    c = Canvas()
    eye_y = troll_body(c, RAMPS["moss"], RAMPS["leaf"])
    # scavenged steel: pauldrons, chest strap, helm cap
    c.sphere(19, 29, 5.5, 4, RAMPS["steel"])
    c.sphere(46, 29, 5.5, 4, RAMPS["steel"])
    c.slab(26, 33, 41, 37, RAMPS["steel"], bevel=1)
    c.sphere(32, 17, 7, 3.4, RAMPS["steel"])     # helm cap
    c.px[29, eye_y] = EYE; c.px[35, eye_y] = EYE
    c.outline(); c.save("armored_troll")


def build_ice_troll():
    c = Canvas()
    eye_y = troll_body(c, RAMPS["steel"], RAMPS["grey"])
    # ice growths on the back/shoulders
    c.tri((18, 26), (24, 26), (21, 16), WHITE)
    c.tri((42, 25), (48, 25), (45, 14), WHITE)
    c.tri((30, 22), (36, 22), (33, 12), RAMPS["steel"][1])
    c.px[29, eye_y] = ICE_EYE; c.px[35, eye_y] = ICE_EYE
    c.outline(); c.save("ice_troll")


def build_granite_colossus():
    c = Canvas()
    # a walking cairn: uneven boulders, not neat slabs
    c.sphere(31, 48, 16, 9, RAMPS["stone"])          # base boulder
    c.sphere(34, 32, 14, 11, RAMPS["grey"])          # torso boulder, lighter
    c.sphere(27, 16, 8, 7, RAMPS["stone"])           # head boulder, offset left
    # arm boulders at different heights
    c.sphere(12, 30, 6, 8, RAMPS["stone"])
    c.sphere(53, 36, 6, 7, RAMPS["grey"])
    c.sphere(11, 42, 4.5, 5, RAMPS["grey"])          # forearm rock
    c.sphere(54, 46, 4.5, 5, RAMPS["stone"])
    # cracks
    for (x0, y0, x1, y1) in [(30, 28, 27, 38), (40, 34, 42, 42), (26, 12, 24, 19)]:
        steps = max(abs(y1 - y0), 1)
        for i in range(steps):
            t = i / steps
            c.px[int(x0 + (x1 - x0) * t), int(y0 + (y1 - y0) * t)] = RAMPS["stone"][3]
    # moss tufts clinging to the shade side
    for (mx, my) in [(42, 26), (43, 27), (20, 44), (21, 45), (33, 11)]:
        c.px[mx, my] = RAMPS["leaf"][1]
    # deep-set glowing eyes
    c.flat(24, 15, 26, 17, EYE); c.flat(30, 15, 32, 17, EYE)
    c.px[25, 16] = GLOW; c.px[31, 16] = GLOW
    c.outline(); c.save("granite_colossus")


def build_grave_titan():
    c = Canvas()
    # towering shrouded mass wearing gravestones (graveyard: "Grave titans")
    c.sphere(32, 38, 14, 17, RAMPS["night"])
    c.sphere(32, 20, 9, 9, RAMPS["night"])
    # gravestone pauldrons + a leaning headstone on the back
    c.slab(16, 26, 24, 35, RAMPS["stone"], bevel=2)
    c.slab(41, 25, 48, 34, RAMPS["stone"], bevel=2)
    c.slab(26, 6, 38, 14, RAMPS["stone"], bevel=2)
    c.tri((26, 6), (38, 6), (32, 2), RAMPS["stone"][1])   # rounded headstone top
    # dragging knuckles
    c.limb(16, 36, 12, 53, 3, RAMPS["night"])
    c.limb(48, 35, 52, 53, 3, RAMPS["night"])
    c.px[28, 19] = GLOW; c.px[36, 19] = GLOW
    c.px[28, 20] = GLOW; c.px[36, 20] = GLOW
    c.outline(); c.save("grave_titan")


def build_inflamed_minotaur():
    c = Canvas()
    # broad bull-man wreathed in embers (Underworld)
    c.limb(26, 46, 24, 55, 3, RAMPS["dark_red"])
    c.limb(38, 46, 40, 55, 3, RAMPS["dark_red"])
    c.sphere(32, 36, 13, 11, RAMPS["blood"])
    c.limb(20, 30, 15, 45, 3, RAMPS["blood"])
    c.limb(44, 30, 49, 45, 3, RAMPS["blood"])
    c.sphere(15, 47, 3.4, 3, RAMPS["dark_red"])
    c.sphere(49, 47, 3.4, 3, RAMPS["dark_red"])
    bull_head(c, 32, 18, RAMPS["dark_red"])
    # embers rising off the shoulders
    for (ex, ey) in [(20, 24), (45, 22), (41, 27)]:
        c.px[ex, ey] = GLOW
    c.px[29, 17] = GLOW; c.px[35, 17] = GLOW
    c.outline(); c.save("inflamed_minotaur")


def build_demon():
    c = Canvas()
    bat_wing(c, 22, 30, -1, 13, RAMPS["dark_red"])
    bat_wing(c, 42, 30, 1, 13, RAMPS["dark_red"])
    # lean upright fiend with a tail
    c.limb(28, 46, 27, 55, 2.4, RAMPS["blood"])
    c.limb(36, 46, 37, 55, 2.4, RAMPS["blood"])
    c.sphere(32, 35, 9, 11, RAMPS["blood"])
    c.limb(25, 30, 22, 43, 2.2, RAMPS["blood"])
    c.limb(39, 30, 42, 43, 2.2, RAMPS["blood"])
    c.sphere(32, 19, 6, 6, RAMPS["blood"])
    # curved horns + spade tail
    c.limb(27, 15, 24, 9, 1.4, RAMPS["bone"])
    c.limb(37, 15, 40, 9, 1.4, RAMPS["bone"])
    pts = [(38, 50), (45, 53), (50, 49)]
    for i in range(len(pts) - 1):
        c.limb(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 1.2, RAMPS["dark_red"])
    c.tri((49, 45), (53, 49), (47, 50), RAMPS["dark_red"][2])
    c.px[30, 19] = GLOW; c.px[34, 19] = GLOW
    c.outline(); c.save("demon")


def build_pit_fiend():
    c = Canvas()
    bat_wing(c, 18, 26, -1, 17, RAMPS["dark_red"])
    bat_wing(c, 46, 26, 1, 17, RAMPS["dark_red"])
    eye_y = troll_body(c, RAMPS["dark_red"], RAMPS["blood"])
    # heavy ram horns
    c.limb(26, 16, 21, 10, 1.8, RAMPS["bone"])
    c.limb(38, 16, 43, 10, 1.8, RAMPS["bone"])
    c.px[29, eye_y] = GLOW; c.px[35, eye_y] = GLOW
    c.outline(); c.save("pit_fiend")


def build_bugbear():
    c = Canvas()
    # shaggy goblinoid ambusher (forest: First Strike) with a crude club
    c.limb(26, 46, 24, 55, 3, RAMPS["leather"])
    c.limb(38, 46, 40, 55, 3, RAMPS["leather"])
    c.sphere(32, 36, 12, 11, RAMPS["leather"])
    c.limb(21, 31, 16, 45, 2.6, RAMPS["leather"])
    c.limb(43, 31, 47, 44, 2.6, RAMPS["leather"])
    # spiked club dragging low from the right hand
    c.limb(47, 45, 52, 52, 2, RAMPS["fur"])
    c.sphere(54, 53, 4, 4, RAMPS["fur"])
    c.px[57, 50] = OUT; c.px[56, 56] = OUT; c.px[51, 56] = OUT  # spikes
    c.sphere(32, 20, 7.5, 7, RAMPS["leather"])
    # pointed goblin ears
    c.tri((24, 18), (26, 14), (22, 12), RAMPS["leather"][2])
    c.tri((40, 18), (38, 14), (42, 12), RAMPS["leather"][2])
    # heavy brow + eyes + fangs
    c.flat(27, 17, 38, 19, RAMPS["leather"][3])
    c.px[29, 19] = GLOW; c.px[35, 19] = GLOW
    c.sphere(32, 24, 4.4, 2.6, [SKIN, SKIN, RAMPS["leather"][2], RAMPS["leather"][3]])
    c.px[29, 25] = RAMPS["bone"][0]; c.px[35, 25] = RAMPS["bone"][0]
    # fur speckle
    for (fx, fy) in [(25, 33), (37, 31), (30, 41), (40, 38)]:
        c.px[fx, fy] = RAMPS["leather"][2]
    c.outline(); c.save("bugbear")


def build_ifrit():
    c = Canvas()
    c.painted_shadow(32, 11)
    # fire spirit: one strong teardrop, gold core, two raised flame arms
    c.sphere(32, 40, 10, 12, RAMPS["blood"])
    c.tri((24, 34), (40, 34), (32, 10), RAMPS["blood"][1])
    c.tri((28, 32), (36, 32), (32, 15), RAMPS["gold"][0])
    c.sphere(32, 40, 6, 8, RAMPS["gold"])
    # arms curling up like flames
    c.limb(23, 40, 18, 33, 2, RAMPS["blood"])
    c.limb(18, 33, 20, 28, 1.4, RAMPS["gold"])
    c.limb(41, 40, 46, 33, 2, RAMPS["blood"])
    c.limb(46, 33, 44, 28, 1.4, RAMPS["gold"])
    # face: dark slit eyes and a grin in the core
    c.flat(28, 38, 30, 40, EYE); c.flat(34, 38, 36, 40, EYE)
    c.flat(29, 44, 35, 45, EYE)
    c.outline(); c.save("ifrit")


def build_snow_wraith():
    c = Canvas()
    c.painted_shadow(32, 10)
    # hooded spirit with a tattered, trailing hem — floats above the snow
    c.sphere(32, 18, 9, 8, RAMPS["steel"])
    c.sphere(32, 32, 10, 12, RAMPS["steel"])
    # ragged hem
    for i, hx in enumerate(range(23, 42, 4)):
        depth = 48 + (4 if i % 2 == 0 else 8)
        c.tri((hx, 42), (hx + 4, 42), (hx + 2, depth), RAMPS["steel"][2])
    # hollow hood + cold eyes
    c.sphere(32, 19, 4.6, 4, [OUT, OUT, OUT, OUT])
    c.px[30, 19] = WHITE; c.px[34, 19] = WHITE
    # trailing wisp arms
    c.limb(23, 30, 15, 36, 1.8, RAMPS["steel"])
    c.limb(41, 30, 49, 36, 1.8, RAMPS["steel"])
    c.outline(); c.save("snow_wraith")


def build_hydra():
    c = Canvas()
    # one thick serpent trunk, three fanned necks, open jaws
    c.sphere(32, 49, 15, 8, RAMPS["leaf"])
    c.sphere(32, 44, 10, 5, RAMPS["leaf"])       # trunk shoulder mass
    necks = [
        [(25, 45), (14, 40), (9, 30), (13, 21)],
        [(32, 43), (28, 33), (34, 25), (31, 15)],
        [(39, 45), (50, 40), (55, 30), (51, 21)],
    ]
    for pts in necks:
        for i in range(len(pts) - 1):
            c.limb(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 3, RAMPS["leaf"])
    heads = [(14, 18, -1), (31, 12, -1), (51, 18, 1)]
    for (hx, hy, face) in heads:
        c.sphere(hx, hy, 5.5, 4.4, RAMPS["leaf"])
        # open jaw: upper snout + dropped lower jaw, red mouth between
        c.tri((hx + face * 5, hy - 1), (hx + face * 10, hy - 3), (hx + face * 5, hy - 3), RAMPS["leaf"][1])
        c.tri((hx + face * 5, hy + 1), (hx + face * 9, hy + 4), (hx + face * 4, hy + 3), RAMPS["leaf"][2])
        c.px[hx + face * 5, hy] = RAMPS["blood"][0]
        c.px[hx + face * 6, hy] = RAMPS["blood"][0]
        c.px[hx - face * 1, hy - 2] = EYE
    # belly plates on the trunk
    for by in range(46, 53, 2):
        c.px[31, by] = RAMPS["leaf"][0]; c.px[33, by] = RAMPS["leaf"][0]
    c.outline(); c.save("hydra")


def build_white_manticore():
    c = Canvas()
    # white lion, bat wing over the back, segmented stinger tail (mountains)
    # tail arc first (behind)
    tip = (0, 0)
    for t in range(22):
        ang = -0.25 + t * 0.085
        fx = 46 + 15 * math.cos(ang)
        fy = 38 - 17 * math.sin(ang)
        tip = (int(fx), int(fy))
        c.sphere(fx, fy, 1.6, 1.6, RAMPS["bone"])
    c.tri((tip[0] - 2, tip[1]), (tip[0] + 3, tip[1]), (tip[0], tip[1] - 8), RAMPS["dark_red"][1])
    c.sphere(34, 45, 14, 8, RAMPS["bone"])       # body
    for lx in (24, 30, 40, 45):
        c.limb(lx, 50, lx - 1, 55, 2.3, RAMPS["bone"])
    bat_wing(c, 36, 38, 1, 12, RAMPS["stone"])
    c.limb(36, 38, 45, 32, 0.9, RAMPS["grey"])   # second wing rib
    # mane + face
    c.sphere(20, 38, 8.5, 8.5, RAMPS["gold"])
    c.sphere(18, 37, 5, 5, RAMPS["bone"])
    c.sphere(17, 40, 3, 2, RAMPS["bone"])        # muzzle
    c.px[15, 36] = EYE; c.px[20, 36] = EYE
    c.px[13, 40] = OUT                            # nose
    c.outline(); c.save("white_manticore")


for fn in [build_rat, build_archer_rat, build_rat_king, build_armored_troll,
           build_ice_troll, build_granite_colossus, build_grave_titan,
           build_inflamed_minotaur, build_demon, build_pit_fiend, build_bugbear,
           build_ifrit, build_snow_wraith, build_hydra, build_white_manticore]:
    fn()
