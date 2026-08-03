#!/usr/bin/env python3
"""First-pass generated monster battlers (style guide rules).

64x64 cells, master-palette colors only, upper-left painted light, selective
hue-shifted outlines (dark on lower/right, broken on the lit upper-left),
ground line at y=57. Floaters (ifrit, snow wraith) get a painted contact
shadow in-art and are excluded from the runtime blob shadow.

These are engineered placeholders that read at 360p — docs/ART_TODO.md still
tracks hand-drawn replacements.
"""
from PIL import Image

W = H = 64
GROUND = 57

# Master palette picks (see resources/palette/master_palette.gpl)
PAL = {
    "skin_hi": (0xf8, 0xd0, 0x98), "skin": (0xc6, 0xa8, 0x91), "skin_sh": (0x6b, 0x53, 0x3e),
    "leather_hi": (0xe0, 0x90, 0x60), "leather": (0xa9, 0x4c, 0x1f), "leather_sh": (0x6b, 0x53, 0x3e),
    "gold_hi": (0xf9, 0xdc, 0x3e), "gold": (0xd8, 0xd3, 0x96), "gold_sh": (0x79, 0x6b, 0x36),
    "blood_hi": (0xe0, 0x69, 0x69), "blood": (0xaa, 0x55, 0x53), "blood_sh": (0x60, 0x23, 0x23),
    "deep_red": (0x96, 0x23, 0x2c),
    "fol_hi": (0x9a, 0xd9, 0x94), "fol": (0x38, 0x98, 0x78), "fol_sh": (0x20, 0x60, 0x20),
    "teal_sh": (0x20, 0x58, 0x58),
    "steel_hi": (0xf2, 0xfd, 0xff), "steel": (0xb6, 0xc5, 0xc5), "steel_md": (0x88, 0x98, 0xa0),
    "steel_sh": (0x63, 0x77, 0x8f), "steel_dk": (0x3c, 0x55, 0x75),
    "cream": (0xf6, 0xf1, 0xd7), "bone": (0xd9, 0xde, 0xc2),
    "amet_hi": (0x73, 0x7e, 0xc4), "amet": (0x45, 0x3f, 0x60), "amet_sh": (0x2b, 0x25, 0x40),
    "shadow": (0x52, 0x52, 0x5f), "out": (0x2b, 0x25, 0x40), "eye": (0x18, 0x18, 0x18),
}


def C(name, a=255):
    r, g, b = PAL[name]
    return (r, g, b, a)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.px = self.img.load()

    def ell(self, cx, cy, rx, ry, col):
        for y in range(H):
            for x in range(W):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.px[x, y] = col

    def rect(self, x0, y0, x1, y1, col):
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
                p = (x, y)
                d0, d1, d2 = edge(p0, p1, p), edge(p1, p2, p), edge(p2, p0, p)
                neg = (d0 < 0) or (d1 < 0) or (d2 < 0)
                pos = (d0 > 0) or (d1 > 0) or (d2 > 0)
                if not (neg and pos):
                    self.px[x, y] = col

    def remap_shade(self, base, hi, sh, split_y, hi_edge=26):
        """Repaint `base` pixels: highlight above/left, shadow below/right."""
        for y in range(H):
            for x in range(W):
                if self.px[x, y][:3] == base[:3]:
                    if y < split_y and x < hi_edge + (split_y - y):
                        self.px[x, y] = hi
                    elif y > split_y + 6 or x > 46:
                        self.px[x, y] = sh

    def painted_shadow(self, cx, rx):
        for y in range(GROUND - 1, GROUND + 2):
            for x in range(W):
                if ((x - cx) / rx) ** 2 + ((y - GROUND) / 2.0) ** 2 <= 1.0:
                    self.px[x, y] = (0, 0, 0, 90)

    def outline(self):
        """Selective outline: dark on lower/right edges, open on upper-left."""
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
            if dy == -1 or dx == -1 or (dx == 1 and y > 30):
                self.px[x, y] = C("out")

    def save(self, name):
        self.img.save(f"assets/sprites/generated/monsters/{name}.png")
        print(name)


def humanoid(c, skin, skin_hi, skin_sh, cloth=None, bulk=1.0, head_r=6):
    """Broad biped filling the cell: legs, torso, arms, head. Returns head cy."""
    torso_w = int(13 * bulk)
    # legs
    c.rect(24, 44, 30, GROUND, skin_sh)
    c.rect(34, 44, 40, GROUND, skin_sh)
    # torso
    c.ell(32, 34, torso_w, 13, skin)
    # arms hanging at the sides
    c.rect(32 - torso_w - 4, 26, 32 - torso_w + 2, 48, skin)
    c.rect(32 + torso_w - 2, 26, 32 + torso_w + 4, 48, skin)
    # head
    head_cy = 17
    c.ell(32, head_cy, head_r + 1, head_r, skin)
    if cloth:
        c.rect(32 - torso_w, 38, 32 + torso_w, 46, cloth)
    c.remap_shade(skin, skin_hi, skin_sh, 26)
    return head_cy


def eyes(c, cy, dx=3, col=None):
    col = col or C("eye")
    c.px[32 - dx, cy] = col
    c.px[32 + dx, cy] = col


def build_armored_troll():
    c = Canvas()
    hy = humanoid(c, C("fol"), C("fol_hi"), C("fol_sh"), cloth=C("leather_sh"), bulk=1.25)
    # steel pauldrons + chestplate band
    c.ell(17, 26, 5, 4, C("steel"))
    c.ell(47, 26, 5, 4, C("steel"))
    c.rect(24, 30, 41, 34, C("steel_md"))
    # tusks
    c.px[28, hy + 4] = C("cream"); c.px[28, hy + 3] = C("cream")
    c.px[36, hy + 4] = C("cream"); c.px[36, hy + 3] = C("cream")
    eyes(c, hy)
    c.outline(); c.save("armored_troll")


def build_ice_troll():
    c = Canvas()
    hy = humanoid(c, C("steel"), C("steel_hi"), C("steel_sh"), cloth=C("steel_dk"), bulk=1.2)
    c.px[28, hy + 4] = C("cream"); c.px[36, hy + 4] = C("cream")
    # icy spikes on the shoulders
    c.tri((14, 24), (20, 24), (17, 16), C("steel_hi"))
    c.tri((44, 24), (50, 24), (47, 16), C("steel_hi"))
    eyes(c, hy, col=C("steel_dk", 255))
    c.outline(); c.save("ice_troll")


def build_granite_colossus():
    c = Canvas()
    # stacked slab body
    c.rect(18, 36, 46, GROUND, C("steel_md"))
    c.rect(14, 22, 50, 38, C("steel_md"))
    c.rect(22, 10, 42, 20, C("steel_md"))  # head slab
    # cracks
    for (x0, y0, x1, y1) in [(24, 28, 24, 36), (38, 24, 40, 30), (30, 44, 30, 52)]:
        c.rect(x0, y0, x1 + 1, y1, C("steel_dk"))
    # arms: chunky side pillars
    c.rect(8, 24, 15, 50, C("steel_md"))
    c.rect(49, 24, 56, 50, C("steel_md"))
    c.remap_shade(C("steel_md"), C("steel"), C("steel_sh"), 24)
    eyes(c, 15, dx=5, col=C("gold_hi"))
    c.outline(); c.save("granite_colossus")


def build_grave_titan():
    c = Canvas()
    hy = humanoid(c, C("amet"), C("amet_hi"), C("amet_sh"), bulk=1.3, head_r=5)
    # hunched crown of grave-stone plates
    c.rect(20, 8, 27, 14, C("shadow"))
    c.rect(30, 6, 37, 13, C("shadow"))
    c.rect(40, 9, 46, 15, C("shadow"))
    eyes(c, hy, dx=3, col=C("gold_hi"))
    c.outline(); c.save("grave_titan")


def build_inflamed_minotaur():
    c = Canvas()
    hy = humanoid(c, C("leather"), C("leather_hi"), C("leather_sh"), cloth=C("blood_sh"), bulk=1.2)
    # bull horns
    c.tri((22, hy - 4), (27, hy - 2), (18, hy - 10), C("cream"))
    c.tri((42, hy - 4), (37, hy - 2), (46, hy - 10), C("cream"))
    # snout
    c.ell(32, hy + 4, 4, 3, C("skin"))
    c.px[30, hy + 4] = C("out"); c.px[34, hy + 4] = C("out")
    eyes(c, hy - 1, col=C("blood_hi"))
    c.outline(); c.save("inflamed_minotaur")


def wings(c, y_top, span, col):
    c.tri((10, y_top + 14), (22, y_top), (24, y_top + 14), col)
    c.tri((54, y_top + 14), (42, y_top), (40, y_top + 14), col)


def build_demon():
    c = Canvas()
    wings(c, 14, 14, C("blood_sh"))
    hy = humanoid(c, C("blood"), C("blood_hi"), C("blood_sh"), bulk=1.0)
    c.tri((26, hy - 5), (29, hy - 3), (25, hy - 11), C("cream"))
    c.tri((38, hy - 5), (35, hy - 3), (39, hy - 11), C("cream"))
    eyes(c, hy, col=C("gold_hi"))
    c.outline(); c.save("demon")


def build_pit_fiend():
    c = Canvas()
    wings(c, 8, 18, C("deep_red"))
    hy = humanoid(c, C("deep_red"), C("blood"), C("blood_sh"), bulk=1.35)
    c.tri((24, hy - 4), (28, hy - 2), (22, hy - 12), C("bone"))
    c.tri((40, hy - 4), (36, hy - 2), (42, hy - 12), C("bone"))
    eyes(c, hy, dx=4, col=C("gold_hi"))
    c.outline(); c.save("pit_fiend")


def build_bugbear():
    c = Canvas()
    hy = humanoid(c, C("skin_sh"), C("leather_hi"), C("out"), cloth=C("leather"), bulk=1.25, head_r=7)
    # big round ears
    c.ell(23, hy - 6, 4, 4, C("skin_sh"))
    c.ell(41, hy - 6, 4, 4, C("skin_sh"))
    c.ell(23, hy - 6, 2, 2, C("skin"))
    c.ell(41, hy - 6, 2, 2, C("skin"))
    c.ell(32, hy + 3, 3, 2, C("skin"))  # muzzle
    eyes(c, hy - 1, col=C("gold_hi"))
    c.outline(); c.save("bugbear")


def build_ifrit():
    c = Canvas()
    c.painted_shadow(32, 12)
    # flame body: layered teardrops, floating above the ground
    c.ell(32, 36, 12, 15, C("blood"))
    c.tri((22, 30), (42, 30), (32, 8), C("blood"))
    c.ell(32, 38, 8, 11, C("gold_hi"))
    c.tri((26, 32), (38, 32), (32, 14), C("gold_hi"))
    c.ell(32, 41, 4, 6, C("cream"))
    eyes(c, 34, dx=3)
    c.outline(); c.save("ifrit")


def build_snow_wraith():
    c = Canvas()
    c.painted_shadow(32, 11)
    # hooded shroud tapering to a wisp, floating
    c.ell(32, 20, 9, 8, C("steel"))           # hood
    c.rect(24, 22, 41, 40, C("steel"))        # robe
    c.tri((24, 40), (41, 40), (32, 52), C("steel"))  # tapered wisp
    c.ell(32, 21, 5, 4, C("out"))             # hollow face
    c.remap_shade(C("steel"), C("steel_hi"), C("steel_sh"), 24)
    eyes(c, 21, dx=2, col=C("steel_hi"))
    c.outline(); c.save("snow_wraith")


def build_hydra():
    c = Canvas()
    # single coiled base, three necks and heads
    c.ell(32, 50, 15, 7, C("fol"))
    for (hx, hy2, bend) in [(18, 20, -1), (32, 12, 0), (46, 20, 1)]:
        # neck
        for t in range(30):
            fx = 32 + (hx - 32) * t / 30.0 + bend * 2 * (1 - abs(t / 15.0 - 1))
            fy = 48 - (48 - hy2) * t / 30.0
            c.rect(int(fx) - 2, int(fy) - 1, int(fx) + 2, int(fy) + 2, C("fol"))
        # head
        c.ell(hx, hy2, 5, 4, C("fol"))
        c.px[hx - 2, hy2] = C("eye"); c.px[hx + 2, hy2] = C("eye")
        c.px[hx, hy2 + 3] = C("blood_hi")  # tongue tip
    c.remap_shade(C("fol"), C("fol_hi"), C("fol_sh"), 30)
    c.outline(); c.save("hydra")


def build_white_manticore():
    c = Canvas()
    # winged lion: body, wing over the back, mane, curled scorpion tail
    c.ell(34, 46, 15, 8, C("cream"))
    c.rect(24, 50, 28, GROUND, C("cream")); c.rect(42, 50, 46, GROUND, C("cream"))
    c.tri((28, 40), (44, 40), (38, 26), C("steel_md"))  # wing over the back
    # tail: rises from the rear and curls over the back, stinger at its tip
    import math
    tip = (0, 0)
    for t in range(24):
        ang = -0.3 + t * 0.072
        fx = 44 + 16 * math.cos(ang)
        fy = 36 - 16 * math.sin(ang)
        tip = (int(fx), int(fy))
        c.rect(tip[0] - 1, tip[1] - 1, tip[0] + 1, tip[1] + 1, C("gold_sh"))
    c.tri((tip[0] - 3, tip[1] - 1), (tip[0] + 2, tip[1] - 1), (tip[0], tip[1] - 8), C("blood_sh"))
    c.ell(20, 38, 8, 8, C("gold"))   # mane
    c.ell(19, 37, 5, 5, C("cream"))  # face
    c.remap_shade(C("cream"), C("steel_hi"), C("bone"), 42)
    c.px[17, 36] = C("eye"); c.px[21, 36] = C("eye")
    c.outline(); c.save("white_manticore")


def build_rat():
    c = Canvas()
    # compact rat (the first pass read too large): ~38px long, 20px tall
    BASE, HI, SH = (0x88, 0x98, 0xa0, 255), (0xb6, 0xc5, 0xc5, 255), (0x52, 0x52, 0x5f, 255)
    # tail
    for t in range(22):
        fx = 44 + t * 0.75; fy = 51 - 3.0 * abs((t / 11.0) - 1) + 3
        if fx < 63:
            c.px[int(fx), int(fy)] = C("skin")
    c.ell(38, 50, 8, 6, BASE)   # haunch
    c.ell(30, 50, 9, 6, BASE)   # body
    c.ell(21, 51, 6, 5, BASE)   # head
    c.tri((12, 50), (16, 47), (16, 54), BASE)  # snout
    c.ell(24, 44, 3, 3, BASE)   # ear
    c.ell(24, 45, 1, 1, (0xc7, 0x81, 0x75, 255))
    for lx in (18, 26, 36, 42):  # legs
        c.rect(lx, 54, lx + 2, GROUND, BASE)
    c.remap_shade(BASE, HI, SH, 48, hi_edge=20)
    c.px[18, 49] = C("eye"); c.px[18, 48] = C("steel_hi")
    c.outline(); c.save("rat")


for fn in [build_rat, build_armored_troll, build_ice_troll, build_granite_colossus,
           build_grave_titan, build_inflamed_minotaur, build_demon, build_pit_fiend,
           build_bugbear, build_ifrit, build_snow_wraith, build_hydra,
           build_white_manticore]:
    fn()
