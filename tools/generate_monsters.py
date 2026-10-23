#!/usr/bin/env python3
"""The one generated monster battler left: the Bone Dragon (no pack has a
bone dragon). The rest of this set (rats, trolls, golems, demons, hydra,
manticore...) was deleted on 2026-10-23 once pack art or the designer's own
sheets replaced every one of them.

64x64 cell, master-palette 4-step ramps, single upper-left light painted via
ramp-shaded primitives, selective hue-shifted outlines, ground line y=57.
Output: assets/sprites/generated/monsters/bone_dragon.png
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


for fn in [build_bone_dragon]:
    fn()
