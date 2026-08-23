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
    """Compact sewer rat (bestiary: scurries and bites): arched haunch, raised
    head with big ears and a pointed snout, whiskers, S-curve tail."""
    # skinny pink tail whipping behind in an S
    pts = [(45, 50), (52, 46), (57, 49), (60, 54), (62, 50)]
    for i in range(len(pts) - 1):
        c.limb(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 1.1, [PINK, SKIN, SKIN, RAMPS["fur"][3]])
    # far legs first (shadow side), then the body over them
    for lx in (24, 40):
        c.limb(lx, 48, lx + 1, 55, 1.8, [ramp[2], ramp[2], ramp[3], ramp[3]])
    c.sphere(38, 46, 10, 9, ramp)      # arched haunch, high at the back
    c.sphere(27, 47, 9, 7, ramp)       # chest, a little lower
    c.sphere(29, 52, 8, 4, [RAMPS["bone"][1], RAMPS["bone"][1], ramp[2], ramp[3]])  # pale belly
    # head raised and alert, pointed snout
    c.sphere(17, 40, 6, 5.4, ramp)
    c.tri((7, 42), (13, 38), (13, 45), ramp[1])   # snout wedge
    c.tri((8, 42), (12, 40), (12, 44), ramp[0])   # lit top of the snout
    c.px[8, 42] = PINK                            # nose
    # two big ears, pink inside
    c.sphere(17, 33, 3.0, 3.4, ramp)
    c.sphere(22, 34, 2.6, 3.0, [ramp[1], ramp[2], ramp[2], ramp[3]])
    c.px[17, 33] = PINK; c.px[17, 34] = PINK
    c.px[22, 35] = PINK
    # near legs with little feet
    for lx in (21, 36):
        c.limb(lx, 50, lx - 1, 55, 2.0, ramp)
        c.flat(lx - 3, 55, lx + 2, GROUND, ramp[1])   # foot with toes forward
    # whiskers
    for wy in (41, 43):
        c.px[4, wy] = RAMPS["bone"][0]; c.px[5, wy] = RAMPS["bone"][0]; c.px[6, wy - 1] = RAMPS["bone"][0]
    c.px[14, 40] = EYE
    c.px[14, 39] = WHITE


def build_rat():
    c = Canvas()
    rat_base(c, RAMPS["grey"])
    c.outline(); c.save("rat")


def build_archer_rat():
    c = Canvas()
    # spec: brown fur, torso pivots UPRIGHT to stand and shoot; wood bow.
    FURB = [HEX("d08860"), HEX("a78e51"), HEX("6b533e"), HEX("452e5b")]
    # tail bracing behind
    pts = [(36, 54), (43, 55), (49, 52)]
    for i in range(len(pts) - 1):
        c.limb(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 1, [SKIN] * 4)
    c.limb(29, 50, 27, 55, 2, FURB)              # hind legs
    c.limb(36, 50, 38, 55, 2, FURB)
    c.sphere(32, 41, 7, 9, FURB)                 # upright torso
    c.sphere(31, 28, 5, 4.6, FURB)               # head
    c.tri((24, 28), (28, 26), (28, 31), FURB[2]) # snout left
    c.sphere(35, 23, 2.6, 2.6, FURB); c.px[35, 23] = PINK  # ear
    # bow held out front (left): thick arc, taut string, nocked arrow
    for t in range(30):
        ang = 1.35 + t * 0.062
        bx = 24 + 10 * math.cos(ang)
        by = 38 + 10 * math.sin(ang)
        c.px[int(bx), int(by)] = RAMPS["leather"][1]
        c.px[int(bx) + 1, int(by)] = RAMPS["leather"][0]
    for t in range(19):                           # string between the tips
        c.px[int(26 - 2), int(29 + t)] = RAMPS["bone"][0]
    c.flat(17, 37, 30, 38, RAMPS["fur"][3])       # arrow shaft
    c.tri((14, 35), (17, 37), (14, 39), RAMPS["steel"][0])  # arrowhead
    c.limb(30, 38, 26, 38, 1.4, FURB)             # forepaw on the grip
    c.px[29, 27] = EYE
    c.px[29, 26] = WHITE
    c.outline(); c.save("archer_rat")


def build_rat_king():
    c = Canvas()
    rat_base(c, RAMPS["grey"])
    # ragged crimson cape draped along the arched back, torn strips trailing
    for t in range(22):
        x = 24 + t
        top = 39 + int(t * 0.32)
        c.flat(x, top, x + 1, min(50, top + 4), HEX("96232c") if t % 3 else HEX("602323"))
    for hx in (42, 45, 48):                       # torn trailing strips
        c.tri((hx, 48), (hx + 2, 47), (hx, 54), HEX("602323"))
    c.px[25, 41] = RAMPS["gold"][0]               # gold clasp at the shoulder
    # the crown (bestiary: "a crowned rat") sits ON the raised head
    c.flat(13, 31, 22, 33, RAMPS["gold"][0])
    for px_ in (13, 16, 19):
        c.tri((px_, 31), (px_ + 3, 31), (px_ + 1, 27), RAMPS["gold"][0])
    c.px[15, 32] = RAMPS["blood"][1]; c.px[19, 32] = RAMPS["violet"][0]  # jewels
    c.px[14, 40] = HEX("e06969")                  # the king's eye burns red
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
    # A rock GIANT, not a cairn: chiselled slabs stacked into shoulders, chest
    # and fists, planted on thick stone legs. Angular silhouette throughout.
    # legs: two heavy pillars with slab feet
    c.slab(21, 40, 30, 54, RAMPS["stone"])
    c.slab(37, 40, 46, 54, RAMPS["grey"])
    c.slab(18, 54, 32, GROUND, RAMPS["stone"])       # feet
    c.slab(35, 54, 49, GROUND, RAMPS["stone"])
    # hips and chest: broad tapering slabs
    c.slab(19, 34, 48, 42, RAMPS["grey"])
    c.slab(15, 20, 52, 36, RAMPS["stone"])           # massive chest block
    c.slab(12, 16, 55, 24, RAMPS["grey"])            # shoulder yoke, wider than the chest
    # arms: block forearms ending in boulder-slab fists at the ground
    c.slab(8, 22, 16, 40, RAMPS["stone"])
    c.slab(51, 22, 59, 40, RAMPS["grey"])
    c.slab(6, 40, 17, 52, RAMPS["grey"])             # left fist
    c.slab(50, 40, 61, 52, RAMPS["stone"])           # right fist
    # head: small block sunk INTO the yoke (no neck)
    c.slab(26, 8, 40, 20, RAMPS["stone"])
    # cracks with ember glow running down chest and arm
    for (x0, y0, x1, y1) in [(33, 22, 30, 34), (44, 26, 46, 38), (12, 26, 10, 36)]:
        steps = max(abs(y1 - y0), 1)
        for i in range(steps):
            t = i / steps
            warm = HEX("a78e51") if i % 2 == 0 else RAMPS["stone"][3]
            c.px[int(x0 + (x1 - x0) * t), int(y0 + (y1 - y0) * t)] = warm
    c.px[32, 26] = GLOW; c.px[45, 32] = GLOW         # crack glow cores
    # moss tufts clinging to the shade side
    for (mx, my) in [(48, 28), (49, 29), (44, 44), (28, 12), (54, 42)]:
        c.px[mx, my] = RAMPS["leaf"][1]
    # deep-set glowing eyes under the brow line
    c.flat(29, 12, 32, 15, EYE); c.flat(35, 12, 38, 15, EYE)
    c.px[30, 13] = GLOW; c.px[36, 13] = GLOW
    c.outline(); c.save("granite_colossus")


def build_grave_titan():
    c = Canvas()
    # spec (enemy_figure.gd): white fur d7d9dd, grey skin, carries a boulder
    FURW = [HEX("f2fdff"), HEX("d9dec2"), HEX("b6c5c5"), HEX("63778f")]
    c.limb(26, 46, 24, 55, 3.4, FURW)
    c.limb(38, 46, 40, 55, 3.4, FURW)
    c.sphere(32, 34, 14, 14, FURW)               # torso
    c.limb(19, 28, 13, 48, 3.2, FURW)            # left arm hangs
    c.sphere(13, 50, 4, 3, RAMPS["stone"])       # stony knuckle
    c.limb(45, 28, 50, 40, 3.2, FURW)            # right arm up to the boulder
    c.sphere(32, 18, 7, 6.4, [HEX("b6c5c5"), HEX("8898a0"), HEX("63778f"), HEX("3c5575")])  # grey face
    c.sphere(32, 13, 7.4, 3, FURW)               # furred brow/crown
    # the boulder resting on the right shoulder
    c.sphere(50, 22, 8.5, 8, RAMPS["stone"])
    c.px[47, 20] = RAMPS["stone"][3]; c.px[52, 24] = RAMPS["stone"][3]  # cracks
    # fur shag along the belly
    for (fx, fy) in [(26, 42), (31, 44), (37, 42), (29, 38)]:
        c.px[fx, fy] = FURW[2]
    c.px[29, 18] = EYE; c.px[35, 18] = EYE
    c.outline(); c.save("grave_titan")


def build_inflamed_minotaur():
    c = Canvas()
    # spec: dark brown hide with ember glow, cream horns, fiery great-axe.
    HIDE = [HEX("d08860"), HEX("6b533e"), HEX("452e5b"), HEX("2b2540")]
    c.limb(26, 46, 24, 55, 3, HIDE)
    c.limb(38, 46, 40, 55, 3, HIDE)
    c.sphere(31, 35, 12, 11, HIDE)
    c.limb(21, 30, 16, 44, 2.8, HIDE)
    c.limb(41, 30, 46, 42, 2.8, HIDE)
    bull_head(c, 31, 17, HIDE)
    # ember glow cracks on the hide
    for (ex, ey) in [(27, 33), (28, 34), (34, 31), (35, 32), (31, 40)]:
        c.px[ex, ey] = HEX("e09060")
    c.px[28, 33] = GLOW; c.px[35, 31] = GLOW
    # fiery great-axe: long haft, broad crescent blade, flames off the edge
    c.flat(50, 12, 52, 52, RAMPS["fur"][2])       # haft
    c.tri((50, 13), (50, 27), (40, 20), RAMPS["steel"][1])   # blade
    c.tri((50, 15), (50, 25), (43, 20), RAMPS["steel"][0])   # blade highlight
    for (fx, fy) in [(41, 16), (39, 20), (41, 24)]:          # flames on the edge
        c.px[fx, fy] = GLOW
        c.px[fx - 1, fy] = HEX("e09060")
    c.px[29, 16] = GLOW; c.px[34, 16] = GLOW      # burning eyes
    c.outline(); c.save("inflamed_minotaur")


def build_demon():
    c = Canvas()
    # spec: red hide, spiral thorns on shoulders/back, gold eyes,
    # left hand dagger + right hand trident. No wings.
    c.limb(28, 46, 27, 55, 2.4, RAMPS["blood"])
    c.limb(36, 46, 37, 55, 2.4, RAMPS["blood"])
    c.sphere(32, 34, 10, 11, RAMPS["blood"])
    c.limb(25, 29, 20, 42, 2.2, RAMPS["blood"])
    c.limb(39, 29, 45, 40, 2.2, RAMPS["blood"])
    # spiral thorns stacking over the shoulders
    for s, sx in ((-1, 23), (1, 41)):
        c.sphere(sx, 26, 2.6, 2.6, RAMPS["dark_red"])
        c.sphere(sx + s * 2, 23, 2.0, 2.0, RAMPS["dark_red"])
        c.px[sx + s * 3, 20] = RAMPS["dark_red"][1]
    c.sphere(32, 19, 6, 6, RAMPS["blood"])
    c.limb(27, 15, 24, 9, 1.9, RAMPS["dark_red"])   # dark horns
    c.limb(37, 15, 40, 9, 1.9, RAMPS["dark_red"])
    c.px[23, 7] = RAMPS["dark_red"][1]; c.px[41, 7] = RAMPS["dark_red"][1]
    # right hand: trident planted
    c.flat(46, 20, 48, 52, RAMPS["fur"][2])
    for tx in (44, 47, 50):
        c.tri((tx, 18), (tx + 2, 18), (tx + 1, 12), RAMPS["steel"][1])
    c.flat(44, 18, 51, 20, RAMPS["steel"][2])
    # left hand: dagger — dark grip, bright blade
    c.flat(19, 41, 22, 43, RAMPS["dark_red"][2])
    c.tri((18, 40), (23, 40), (20, 31), RAMPS["steel"][0])
    c.px[20, 33] = RAMPS["steel"][1]
    c.px[29, 19] = GLOW; c.px[35, 19] = GLOW
    c.outline(); c.save("demon")


def build_pit_fiend():
    c = Canvas()
    # spec: deep red, right hand holds a coiled whip, thin tail with an
    # arrowhead barb, gold ornaments. Heavy build, no wings.
    eye_y = troll_body(c, RAMPS["dark_red"], RAMPS["blood"])
    # gold collar band
    c.flat(26, 29, 40, 31, RAMPS["gold"][1])
    # coiled whip in the right hand: thick leather rings + handle
    for r in (5.0, 3.2):
        for t in range(30):
            ang = t * 0.21
            wx = 51 + r * math.cos(ang)
            wy = 47 + r * 0.65 * math.sin(ang)
            c.sphere(wx, wy, 1.1, 1.1, RAMPS["leather"])
    c.flat(48, 39, 50, 44, RAMPS["leather"][3])   # handle
    # thin tail whipping out left with arrowhead barb
    pts = [(24, 50), (14, 48), (8, 42)]
    for i in range(len(pts) - 1):
        c.limb(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 1.2, RAMPS["dark_red"])
    c.tri((5, 38), (10, 41), (5, 43), RAMPS["dark_red"][1])
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
    # heavy spiked mace in the right fist (wood haft, steel head)
    c.limb(47, 45, 51, 51, 1.6, RAMPS["fur"])
    c.sphere(53, 52, 4, 4, RAMPS["steel"])
    for (sx2, sy2) in [(57, 49), (57, 55), (50, 56), (53, 47)]:
        c.px[sx2, sy2] = RAMPS["steel"][0]
    c.sphere(32, 20, 7.5, 7, RAMPS["leather"])
    # pointed goblin ears
    c.tri((24, 18), (26, 14), (22, 12), RAMPS["leather"][2])
    c.tri((40, 18), (38, 14), (42, 12), RAMPS["leather"][2])
    # heavy brow + eyes + fangs
    c.flat(27, 17, 38, 19, RAMPS["leather"][3])
    c.px[29, 19] = HEX("e06969"); c.px[35, 19] = HEX("e06969")  # red eyes
    c.sphere(32, 24, 4.4, 2.6, [SKIN, SKIN, RAMPS["leather"][2], RAMPS["leather"][3]])
    c.px[29, 25] = RAMPS["bone"][0]; c.px[35, 25] = RAMPS["bone"][0]
    # fur speckle
    for (fx, fy) in [(25, 33), (37, 31), (30, 41), (40, 38)]:
        c.px[fx, fy] = RAMPS["leather"][2]
    c.outline(); c.save("bugbear")


def build_ifrit():
    c = Canvas()
    # spec: coal hide, ember cracks, glow, canine head, long arms near the
    # ground, short bent legs, pale claws. A molten beast — not a flame wisp.
    COAL = [HEX("a94c1f"), HEX("6b533e"), HEX("452e5b"), HEX("2b2540")]
    c.limb(27, 48, 25, 55, 2.8, COAL)
    c.limb(37, 48, 39, 55, 2.8, COAL)
    c.sphere(32, 37, 13, 12, COAL)               # hunched torso
    c.limb(20, 32, 13, 52, 3, COAL)              # long arms to the ground
    c.limb(44, 32, 51, 52, 3, COAL)
    for (hx, hy) in [(12, 54), (52, 54)]:        # pale claws
        c.px[hx, hy] = RAMPS["bone"][0]; c.px[hx + 1, hy] = RAMPS["bone"][0]; c.px[hx - 1, hy] = RAMPS["bone"][0]
    # canine head: skull + lighter snout with jaw and fangs
    c.sphere(32, 21, 7, 6, COAL)
    c.sphere(25, 24, 5, 3, [HEX("d08860"), HEX("a94c1f"), HEX("6b533e"), HEX("452e5b")])
    c.px[20, 23] = OUT; c.px[20, 24] = OUT        # nose
    c.px[23, 27] = RAMPS["bone"][0]; c.px[26, 27] = RAMPS["bone"][0]  # fangs
    c.px[22, 25] = HEX("602323")                  # mouth line
    # glowing ember cracks across chest, arms, brow
    EMB = HEX("e09060"); GLW = HEX("f9dc3e")
    for (ex, ey) in [(28, 34), (29, 35), (30, 36), (35, 32), (36, 33), (37, 34),
                     (33, 40), (34, 41), (17, 40), (18, 41), (46, 38), (47, 39), (30, 17), (31, 18)]:
        c.px[ex, ey] = EMB
    for (ex, ey) in [(29, 35), (36, 33), (33, 40), (17, 41), (46, 39)]:
        c.px[ex, ey] = GLW
    c.px[29, 20] = GLW; c.px[34, 20] = GLW       # burning eyes
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
    c.px[30, 19] = HEX("62a3b0"); c.px[34, 19] = HEX("62a3b0")  # cold blue eyes
    # trailing wisp arms
    c.limb(23, 30, 15, 36, 1.8, RAMPS["steel"])
    c.limb(41, 30, 49, 36, 1.8, RAMPS["steel"])
    c.outline(); c.save("snow_wraith")


def build_hydra():
    c = Canvas()
    # spec: serpent trunk rearing up — raised chest where the necks root,
    # barrel + coiled hindquarters, pale belly scutes, dorsal ridge, stubby
    # clawed forelegs, gold eyes.
    c.sphere(38, 51, 13, 6, RAMPS["leaf"])        # coiled hindquarters
    c.sphere(30, 45, 10, 9, RAMPS["leaf"])        # barrel
    c.sphere(27, 34, 8, 9, RAMPS["leaf"])         # rearing chest
    # dorsal ridge down the spine
    for (dx, dy) in [(24, 26), (21, 32), (22, 40), (27, 51), (36, 46)]:
        c.tri((dx, dy), (dx + 4, dy), (dx + 2, dy - 4), RAMPS["leaf"][2])
    # pale belly scutes plating the chest
    for by in range(30, 42, 3):
        c.flat(29, by, 34, by + 2, RAMPS["leaf"][0])
    # stubby clawed forelegs bracing
    c.limb(24, 42, 21, 48, 2, RAMPS["leaf"])
    c.px[20, 49] = RAMPS["bone"][0]; c.px[22, 49] = RAMPS["bone"][0]
    # three necks rooting at the chest
    necks = [
        [(25, 28), (13, 24), (8, 16)],
        [(28, 26), (29, 16), (33, 10)],
        [(31, 28), (44, 24), (52, 16)],
    ]
    for pts in necks:
        for i in range(len(pts) - 1):
            c.limb(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 2.6, RAMPS["leaf"])
    for (hx, hy, face) in [(8, 14, -1), (34, 8, 1), (53, 14, 1)]:
        c.sphere(hx, hy, 5, 4, RAMPS["leaf"])
        c.tri((hx + face * 5, hy - 1), (hx + face * 9, hy - 2), (hx + face * 4, hy - 3), RAMPS["leaf"][1])
        c.tri((hx + face * 4, hy + 1), (hx + face * 8, hy + 3), (hx + face * 3, hy + 3), RAMPS["leaf"][2])
        c.px[hx + face * 4, hy] = RAMPS["blood"][0]
        c.px[hx - face * 1, hy - 2] = GLOW        # gold eyes
    c.outline(); c.save("hydra")


def build_bone_dragon():
    c = Canvas()
    # Graveyard boss: a skeletal dragon — horned skull with open jaw, a neck
    # and tail of vertebrae, a bare ribcage, tattered bone wings raised.
    BONE = RAMPS["bone"]
    # far wing: bone fingers with torn membrane scraps, rooted at the shoulder
    for (tipx, tipy) in [(44, 4), (54, 10), (58, 20)]:
        c.limb(30, 25, tipx, tipy, 1.3, [BONE[2], BONE[2], BONE[3], BONE[3]])
    c.tri((30, 25), (44, 4), (54, 10), RAMPS["violet"][2])
    c.tri((30, 25), (54, 10), (58, 20), RAMPS["night"][1])
    # tail: vertebrae shrinking toward a bony barb
    tail = [(44, 46), (50, 49), (56, 52), (60, 50)]
    for i in range(len(tail) - 1):
        c.limb(tail[i][0], tail[i][1], tail[i + 1][0], tail[i + 1][1], 2.2 - i * 0.4, BONE)
    for (sx, sy) in tail[1:]:
        c.px[int(sx), int(sy) - 2] = BONE[0]          # tail spines
    c.tri((60, 50), (64, 46), (62, 52), BONE[0])      # barb
    # pelvis and planted hind leg, clawed
    c.sphere(42, 44, 4.5, 4, BONE)
    c.limb(41, 47, 43, 54, 2.4, BONE)
    c.flat(40, 55, 47, GROUND, BONE[1])
    # spine arching from hips up to the neck, thick and continuous
    spine = [(42, 42), (37, 36), (31, 31), (25, 26), (21, 20)]
    for i in range(len(spine) - 1):
        c.limb(spine[i][0], spine[i][1], spine[i + 1][0], spine[i + 1][1], 2.3, BONE)
    for (sx, sy) in spine:
        c.px[int(sx), int(sy) - 3] = BONE[0]          # dorsal spikes
    # ribcage: three clean C-arcs hanging from the spine, chest void between
    for i, (rcx, rcy, rr) in enumerate([(34, 36, 8), (31, 39, 7), (28, 41, 5.5)]):
        for t in range(16):
            ang = 0.35 + t * 0.14                     # sweep down-left
            fx = rcx - rr * math.sin(ang)
            fy = rcy + rr * (1 - math.cos(ang))
            col = BONE[1] if i == 0 else BONE[2]
            c.px[int(fx), int(fy)] = col
            c.px[int(fx) + 1, int(fy)] = col
    # foreleg: short wing-arm knuckled to the ground under the chest
    c.limb(27, 36, 22, 50, 1.8, BONE)
    c.flat(19, 51, 26, 53, BONE[1])
    # near wing raised in front, from the same shoulder hump
    for (tipx, tipy) in [(30, 3), (40, 6)]:
        c.limb(26, 23, tipx, tipy, 1.4, BONE)
    c.tri((26, 23), (30, 3), (40, 6), RAMPS["violet"][1])
    # skull: horned, jaw open showing fangs
    c.sphere(17, 18, 6.5, 5, BONE)                    # cranium
    c.tri((4, 18), (12, 15), (12, 22), BONE[1])       # upper snout
    c.tri((6, 26), (14, 22), (15, 27), BONE[2])       # lower jaw, open
    c.px[7, 20] = BONE[0]; c.px[6, 21] = BONE[0]      # upper fangs
    c.px[8, 24] = BONE[0]
    for s in (-1, 1):                                 # swept horns
        c.limb(20 + max(0, s), 14, 24 + s * 4, 8, 1.5, BONE)
    c.flat(14, 17, 17, 19, EYE)                       # empty socket...
    c.px[15, 18] = HEX("62a3b0")                      # ...with a cold spark
    c.outline(); c.save("bone_dragon")


def build_white_manticore():
    c = Canvas()
    # spec: snow-leopard body (white with grey rosettes), bat wings,
    # spiked scorpion tail arching over the back. No lion mane.
    SNOW = [HEX("f2fdff"), HEX("f6f1d7"), HEX("b6c5c5"), HEX("63778f")]
    # far bat wing behind the body (darker, membrane fully visible)
    bat_wing(c, 38, 34, 1, 13, RAMPS["grey"])
    # scorpion tail: thick segmented arc from the rump curling over the back,
    # ending in a bulb and a clear curved stinger barb
    seg = []
    for t in range(20):
        ang = -0.35 + t * 0.105
        fx = 46 + 13 * math.cos(ang)
        fy = 40 - 17 * math.sin(ang)
        seg.append((fx, fy))
        c.sphere(fx, fy, 2.4 - t * 0.05, 2.4 - t * 0.05, SNOW)
    for i in range(2, 19, 3):                    # segment shadow rings
        c.px[int(seg[i][0]), int(seg[i][1]) + 1] = SNOW[3]
    bx, by = int(seg[-1][0]), int(seg[-1][1])
    c.sphere(bx, by, 3.0, 3.0, [RAMPS["grey"][0], RAMPS["grey"][1], RAMPS["grey"][2], RAMPS["grey"][3]])  # venom bulb
    c.limb(bx, by - 2, bx - 4, by - 7, 1.4, RAMPS["steel"])   # curved stinger
    c.tri((bx - 6, by - 9), (bx - 3, by - 6), (bx - 6, by - 5), RAMPS["steel"][0])
    # far legs (shadow side)
    for lx in (26, 43):
        c.limb(lx, 48, lx + 1, 55, 2.0, [SNOW[2], SNOW[2], SNOW[3], SNOW[3]])
    # cat body: chest higher than rump, standing tall on straight legs
    c.sphere(36, 43, 13, 8, SNOW)                # body
    c.sphere(24, 40, 9, 8, SNOW)                 # chest/shoulders
    # near legs with paws
    for lx in (22, 30, 40, 46):
        c.limb(lx, 47, lx - 1, 54, 2.2, SNOW)
        c.sphere(lx - 1, 55, 2.6, 1.6, SNOW)     # paw
    # near wing rising from the shoulder, in front
    bat_wing(c, 30, 33, 1, 10, [RAMPS["grey"][0], RAMPS["grey"][1], RAMPS["grey"][2], RAMPS["grey"][3]])
    # head: round cat skull, short muzzle, two ears
    c.sphere(16, 32, 6.4, 6, SNOW)
    c.sphere(12, 36, 3.4, 2.2, SNOW)             # muzzle
    c.tri((12, 28), (16, 26), (16, 30), SNOW[1]) # near ear
    c.tri((18, 27), (21, 26), (21, 30), SNOW[2]) # far ear
    c.px[10, 36] = PINK                          # nose
    # grey rosette spots along the flank
    for (rx, ry) in [(31, 42), (38, 46), (43, 41), (34, 48), (27, 44), (40, 38)]:
        c.px[rx, ry] = RAMPS["grey"][2]; c.px[rx + 1, ry] = RAMPS["grey"][2]
    c.px[14, 32] = EYE; c.px[18, 32] = EYE
    c.px[14, 31] = WHITE
    c.outline(); c.save("white_manticore")


for fn in [build_rat, build_archer_rat, build_rat_king, build_armored_troll,
           build_ice_troll, build_granite_colossus, build_grave_titan,
           build_inflamed_minotaur, build_demon, build_pit_fiend, build_bugbear,
           build_ifrit, build_snow_wraith, build_hydra, build_bone_dragon,
           build_white_manticore]:
    fn()
