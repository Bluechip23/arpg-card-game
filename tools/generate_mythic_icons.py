#!/usr/bin/env python3
"""Mythic appearance icons: one 32x32 sprite per mythic item, drawn from that
item's `appearance` description in scripts/progression/item_data.gd.

Output: assets/items/mythic/<slug>.png — the art the inventory shows in the
equipment slot while the mythic is equipped (EquipmentSlotCell swaps the
generic slot silhouette for it).

House style (docs/STYLE_GUIDE.md): master-palette colors only, <= 15 colors
per sprite, one upper-left key light, hue-shifted ramps (shadows drift toward
blue/violet), colored outlines — never pure black.

Shading is mechanical rather than hand-placed: every sprite is painted as
material regions, then a single pass lights each region's upper-left silhouette
edge with its highlight, its lower-right edge with its shadow, and rings the
whole thing in the material's core color. Detail pixels can force a ramp step
explicitly (level="hi"/"sh") where the light needs a hand.

Usage: python3 tools/generate_mythic_icons.py
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw

G = 32  # icon is 32x32; keep drawing inside 1..30 so the outline pass fits
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "items", "mythic")

H = lambda s: (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)

# Material ramps: highlight -> base -> shadow -> core (core doubles as the
# outline color, which is why every core is a dark, hue-shifted palette entry).
MATS = {
    #                     highlight    base        shadow      core
    "steel":   dict(hi="f2fdff", base="b6c5c5", sh="63778f", core="3c5575"),
    "iron":    dict(hi="b6c5c5", base="7c8989", sh="52525f", core="2b2540"),
    "leather": dict(hi="e09060", base="a94c1f", sh="6b533e", core="452e5b"),
    "wood":    dict(hi="e09060", base="885038", sh="7f4935", core="5d3621"),
    "gold":    dict(hi="f9dc3e", base="d8d396", sh="796b36", core="454831"),
    "cloth":   dict(hi="737ec4", base="53539c", sh="3e6794", core="2b2540"),
    "rose":    dict(hi="f890d0", base="926077", sh="50384e", core="2b2540"),
    "blood":   dict(hi="e06969", base="b74248", sh="96232c", core="381618"),
    "leaf":    dict(hi="9ad994", base="389878", sh="206020", core="205858"),
    "bone":    dict(hi="f4f9f8", base="d9dec2", sh="a8b5a8", core="7c8989"),
    "dark":    dict(hi="453f60", base="452e5b", sh="2b2540", core="2b2540"),
    "spark":   dict(hi="f2fdff", base="737ec4", sh="4539b8", core="2b2540"),
    "teal":    dict(hi="62a3b0", base="4e8c8c", sh="32716c", core="205858"),
    # Light-blue arc current, and the gray-violet billow of smoke.
    "current": dict(hi="f2fdff", base="62a3b0", sh="3e6794", core="2b2540"),
    "smoke":   dict(hi="b6c5c5", base="686878", sh="52525f", core="453f60"),
}


# ---------------------------------------------------------------------------
# Tiny drawing toolkit: shapes are stamped as masks into a material grid, so
# the shading pass sees regions rather than colors.
# ---------------------------------------------------------------------------

class Canvas:
    def __init__(self):
        self.cells = [[None] * G for _ in range(G)]

    def set(self, x, y, mat, level=None):
        if 0 <= x < G and 0 <= y < G:
            self.cells[y][x] = (mat, level)

    def filled(self, x, y):
        return 0 <= x < G and 0 <= y < G and self.cells[y][x] is not None

    def stamp(self, mask, mat, level=None):
        px = mask.load()
        for y in range(G):
            for x in range(G):
                if px[x, y]:
                    self.cells[y][x] = (mat, level)

    def carve(self, mask):
        px = mask.load()
        for y in range(G):
            for x in range(G):
                if px[x, y]:
                    self.cells[y][x] = None

    # Shape helpers ---------------------------------------------------------
    def rect(self, box, mat, level=None):
        self.stamp(_mask(lambda d: d.rectangle(box, fill=255)), mat, level)

    def ellipse(self, box, mat, level=None):
        self.stamp(_mask(lambda d: d.ellipse(box, fill=255)), mat, level)

    def poly(self, pts, mat, level=None):
        self.stamp(_mask(lambda d: d.polygon(pts, fill=255)), mat, level)

    def line(self, pts, mat, level=None, width=1):
        self.stamp(_mask(lambda d: d.line(pts, fill=255, width=width)), mat, level)

    def dot(self, x, y, mat, level=None):
        self.set(x, y, mat, level)


def _mask(draw_fn):
    m = Image.new("L", (G, G), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def _ellipse_mask(box):
    return _mask(lambda d: d.ellipse(box, fill=255))


def _rect_mask(box):
    return _mask(lambda d: d.rectangle(box, fill=255))


def _poly_mask(pts):
    return _mask(lambda d: d.polygon(pts, fill=255))


def _lerp_path(pts, steps=240):
    """Walk a polyline at even parameter steps, so shapes can be stroked."""
    out = []
    segs = len(pts) - 1
    for i in range(steps + 1):
        t = i * segs / float(steps)
        k = min(int(t), segs - 1)
        f = t - k
        (x0, y0), (x1, y1) = pts[k], pts[k + 1]
        out.append((x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, i / float(steps)))
    return out


def _stroke(c, pts, mat, r_end=2.0, r_mid=None, level=None):
    """Stamp a path as overlapping discs, fattest at its middle.

    This is how the curved solids get drawn — an S-shaped shield, a fang, a
    bow limb — because a swept disc gives smooth, rounded pixel edges where a
    polygon would give faceted ones.
    """
    r_mid = r_end if r_mid is None else r_mid
    for (x, y, t) in _lerp_path(pts):
        r = r_end + (r_mid - r_end) * math.sin(math.pi * t)
        c.ellipse((x - r, y - r, x + r, y + r), mat, level)


def _clump(c, x, y, r, mat, level=None):
    """One rounded tuft — the unit fur and smoke are built out of."""
    c.ellipse((x - r, y - r, x + r, y + r), mat, level)


def _taper(c, p0, p1, r0, r1, mat, level=None):
    """A tapered blob from p0 to p1 — one lock of hair, one feather quill."""
    for i in range(49):
        t = i / 48.0
        x = p0[0] + (p1[0] - p0[0]) * t
        y = p0[1] + (p1[1] - p0[1]) * t
        r = r0 + (r1 - r0) * t
        c.ellipse((x - r, y - r, x + r, y + r), mat, level)


def _lock(c, cx, cy, angle, inner, outer, w, mat):
    """A single clump of fur: a tapered lock swept outward from the head, lit
    along its upper-left flank and shadowed under its lower-right one."""
    ix, iy = cx + math.cos(angle) * inner, cy + math.sin(angle) * inner
    ox, oy = cx + math.cos(angle) * outer, cy + math.sin(angle) * outer
    _taper(c, (ix, iy), (ox, oy), w, max(0.7, w - 1.2), mat)
    # Perpendicular offset picks the lit side of the lock and the shaded side.
    px_, py_ = -math.sin(angle), math.cos(angle)
    for sgn, lvl in ((-1, "hi"), (1, "sh")):
        c.line([(ix + px_ * sgn * (w - 0.6), iy + py_ * sgn * (w - 0.6)),
                (ox + px_ * sgn * 0.5, oy + py_ * sgn * 0.5)], mat, lvl)


def _crescent(c, box, shift, mat, level=None):
    """A true crescent: a disc with a second disc bitten out of its side."""
    x0, y0, x1, y1 = box
    m = ImageChops.subtract(_ellipse_mask(box), _ellipse_mask((x0 + shift, y0 - 1, x1 + shift, y1 + 1)))
    c.stamp(m, mat, level)


def _hexagon(cx, cy, r):
    return [(cx + r * math.cos(math.tau * i / 6.0 - math.pi / 2.0),
             cy + r * math.sin(math.tau * i / 6.0 - math.pi / 2.0)) for i in range(6)]


def _d20(c, cx, cy, r, mat, bezel="dark"):
    """A twenty-sided die: the hexagon silhouette every d20 icon leans on, the
    up-facing triangle catching the light, side facets falling away from it.

    The bezel is drawn as a hexagon rather than a disc so the die keeps its
    corners when it is set into a plate of the same brightness.
    """
    c.poly(_hexagon(cx, cy, r + 1.0), bezel, "sh")
    c.poly(_hexagon(cx, cy, r), mat, "sh")
    # The face turned toward the viewer, and the facets folding off its sides.
    top, tl, tr = (cx, cy - r * 0.55), (cx - r * 0.8, cy + r * 0.62), (cx + r * 0.8, cy + r * 0.62)
    c.poly([top, tl, tr], mat, "hi")
    c.poly([(cx, cy - r), (cx - r * 0.87, cy - r * 0.5), tl, top], mat, "base")
    c.poly([(cx, cy - r), (cx + r * 0.87, cy - r * 0.5), tr, top], mat, "base")


def render(canvas):
    """Light the material regions and ring them in their core color."""
    img = Image.new("RGBA", (G, G), (0, 0, 0, 0))
    px = img.load()
    for y in range(G):
        for x in range(G):
            cell = canvas.cells[y][x]
            if cell is None:
                continue
            mat, level = cell
            ramp = MATS[mat]
            if level:
                px[x, y] = H(ramp[level])
                continue
            up = canvas.filled(x, y - 1)
            left = canvas.filled(x - 1, y)
            down = canvas.filled(x, y + 1)
            right = canvas.filled(x + 1, y)
            if not up or not left:
                px[x, y] = H(ramp["hi"])
            elif not down or not right:
                px[x, y] = H(ramp["sh"])
            else:
                px[x, y] = H(ramp["base"])
    # Outline: every empty pixel touching the sprite takes the core color of a
    # neighbouring material (colored outlines, never #000000).
    for y in range(G):
        for x in range(G):
            if canvas.cells[y][x] is not None:
                continue
            core = None
            for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                nb = canvas.cells[y + dy][x + dx] if 0 <= x + dx < G and 0 <= y + dy < G else None
                if nb is not None:
                    core = MATS[nb[0]]["core"]
                    break
            if core:
                px[x, y] = H(core)
    return img


# ---------------------------------------------------------------------------
# The mythics — each function draws what its appearance description says.
# ---------------------------------------------------------------------------

def bladed_doughnut():
    ## "Fried dough gone wrong: the outer rim is hammered steel filed into
    ## razor teeth, the pink glaze never quite dries, sprinkles are bone."
    c = Canvas()
    # Eight razor teeth filed around the rim, then the steel band, then dough.
    for i in range(8):
        a = math.tau * i / 8.0 - math.pi / 2.0
        ux, uy = math.cos(a), math.sin(a)
        px_, py_ = -uy, ux  # perpendicular, for the tooth's base
        c.poly([(16 + ux * 11 + px_ * 2.6, 16 + uy * 11 + py_ * 2.6),
                (16 + ux * 11 - px_ * 2.6, 16 + uy * 11 - py_ * 2.6),
                (16 + ux * 15.0, 16 + uy * 15.0)], "steel")
    c.ellipse((3, 3, 28, 28), "steel")
    c.ellipse((5, 5, 26, 26), "wood")
    # Pink glaze poured over the top, drooling down the left and right and
    # clipped to the dough so it never spills onto the steel rim.
    glaze = _rect_mask((0, 0, G - 1, G - 1))
    gpx = glaze.load()
    for x in range(G):
        drip = 19 + (4 if x in (8, 9, 10) else 0) + (5 if x in (19, 20) else 0)
        for y in range(drip + 1, G):
            gpx[x, y] = 0
    glaze = ImageChops.multiply(glaze, _ellipse_mask((5, 5, 26, 26)))
    c.stamp(glaze, "rose", "hi")
    # The glaze keeps its own lower lip in the mid tone so it reads as poured on.
    gpx = glaze.load()
    for x in range(G):
        for y in range(G - 1):
            if gpx[x, y] and not gpx[x, y + 1]:
                c.set(x, y, "rose", "base")
                c.set(x, y - 1, "rose", "base")
    # Bite hole in the middle.
    c.carve(_ellipse_mask((12, 12, 19, 19)))
    # Bone sprinkles scattered across the glaze.
    for (sx, sy) in ((10, 8), (11, 9), (15, 6), (16, 7), (20, 9), (21, 10),
                     (9, 14), (13, 17), (22, 15), (18, 19)):
        c.dot(sx, sy, "bone", "hi")
    return c


def the_headbandz():
    ## "A wide indigo band knotted at the side with long tails, five little
    ## gems sewn along the brow."
    ## "Three cards slotted upright across the front of the band, faces out."
    c = Canvas()
    # Three cards standing upright out of the band, the middle one riding
    # highest, each in a dark sleeve so they read as three separate cards.
    for i, cx in enumerate((2, 12, 22)):
        top = 2 if i == 1 else 5
        c.rect((cx - 1, top - 1, cx + 8, 21), "dark")
        c.rect((cx, top, cx + 7, 21), "bone")
        # Faces out: a corner index at the top left and the suit pip below it.
        c.rect((cx + 1, top + 1, cx + 2, top + 3), "blood" if i == 1 else "dark", "sh")
        px_, py_ = cx + 4, top + 9
        if i == 1:   # a heart
            c.ellipse((px_ - 3, py_ - 4, px_ - 1, py_ - 1), "blood")
            c.ellipse((px_, py_ - 4, px_ + 2, py_ - 1), "blood")
            c.poly([(px_ - 3, py_ - 2), (px_ + 2, py_ - 2), (px_, py_ + 3)], "blood")
        else:        # a spade
            c.poly([(px_, py_ - 5), (px_ + 3, py_), (px_ - 3, py_)], "dark", "sh")
            c.ellipse((px_ - 3, py_ - 2, px_ - 1, py_ + 1), "dark", "sh")
            c.ellipse((px_, py_ - 2, px_ + 2, py_ + 1), "dark", "sh")
            c.rect((px_ - 1, py_, px_, py_ + 3), "dark", "sh")
    # The band itself, wrapped across the bottom of the cards.
    c.rect((1, 20, 30, 27), "cloth")
    c.rect((1, 21, 30, 21), "cloth", "hi")
    c.rect((1, 26, 30, 26), "cloth", "sh")
    for sx in range(3, 30, 6):  # stitching along the band
        c.dot(sx, 23, "cloth", "sh")
        c.dot(sx + 1, 24, "cloth", "sh")
    return c


def scholars_cap():
    ## "A stiff mortarboard, gold tassel always swinging, equations inked
    ## across the underside of the board."
    c = Canvas()
    # Skull cap under the board, held black.
    c.ellipse((9, 14, 22, 27), "dark", "sh")
    c.rect((9, 19, 22, 25), "dark", "sh")
    # The board: a stiff flat diamond, black on top, with the underside
    # showing along the near edge.
    c.poly([(1, 12), (16, 5), (31, 12), (16, 19)], "dark", "sh")
    c.poly([(1, 12), (16, 19), (31, 12), (31, 13), (16, 20), (1, 13)], "dark", "hi")
    # Equations inked edge to edge across the underside, and corrected again.
    for (ex, ey) in ((7, 13), (10, 14), (13, 16), (17, 17), (20, 16),
                     (23, 14), (26, 13), (15, 15), (19, 15)):
        c.dot(ex, ey, "bone", "sh")
    c.dot(13, 15, "blood", "hi")   # the correction somebody kept making
    c.dot(20, 15, "blood", "hi")
    # Button and tassel: the cord runs out to the corner, then swings free.
    c.rect((15, 10, 17, 12), "gold")
    c.line([(16, 11), (28, 12)], "gold")
    c.line([(28, 12), (29, 20)], "gold")
    # The tuft: strands, not a block, so it reads as hanging thread.
    for (tx, ty) in ((27, 21), (28, 21), (29, 21), (30, 21)):
        c.line([(tx, ty), (tx - 1, ty + 6)], "gold")
    c.rect((27, 20, 30, 21), "gold", "hi")
    for tx in (27, 29):
        c.dot(tx, 26, "gold", "sh")
    return c


def hannibals_mask():
    ## Hannibal Lecter's mask: a hard leather muzzle over the lower face with a
    ## steel grille bolted across the mouth, strapped around the head.
    c = Canvas()
    # The straps run right off both edges of the icon and are drawn thin, so
    # they read as webbing going round a head rather than as ears.
    c.rect((0, 12, 31, 14), "leather", "sh")
    c.rect((0, 21, 31, 23), "leather", "sh")
    c.rect((13, 0, 18, 9), "leather", "sh")
    for bx in (3, 26):     # the buckles, one at each cheek
        c.rect((bx, 11, bx + 3, 15), "iron")
        c.rect((bx + 1, 12, bx + 2, 14), "dark", "sh")
    # The muzzle: over the nose, down to the chin, tapering into the jaw.
    c.poly([(8, 7), (23, 7), (24, 19), (20, 27), (11, 27), (7, 19)], "leather")
    c.rect((10, 5, 21, 8), "leather")
    c.line([(9, 8), (9, 18)], "leather", "hi")
    # Breathing holes punched over the nose.
    for hx in (13, 16, 19):
        c.dot(hx, 10, "dark", "sh")
    # The grille bolted across the mouth: vertical bars on two rails, and the
    # bolt heads that hold it to the leather.
    c.rect((9, 15, 22, 25), "dark", "sh")
    for bx in range(10, 23, 3):
        c.rect((bx, 15, bx, 25), "iron", "hi")
    c.rect((9, 17, 22, 17), "iron", "hi")
    c.rect((9, 23, 22, 23), "iron", "hi")
    for (bx, by) in ((8, 16), (23, 16), (8, 24), (23, 24)):
        c.dot(bx, by, "iron", "hi")
    return c


def mane_of_narashimha():
    ## An enormous lion's mane, hooding the crown and falling down the back to
    ## mid-spine. Everything here is built from rounded, overlapping clumps —
    ## fur is soft and matted, so there is not a spike anywhere in it.
    c = Canvas()
    fx, fy = 16, 10   # the face the mane hoods; every lock is combed from here

    def outer(a):
        ## The mane is short over the crown and long down the back, so the
        ## boundary is pulled well past the head below the shoulder line.
        return 9.5 + 11.0 * max(0.0, math.sin(a)) ** 2.4

    # Undercoat: a darker ring sitting behind the tips of the outer locks, so
    # the coat has depth at its edge without muddying the body of the mane.
    for i in range(24):
        a = math.tau * i / 24.0
        _clump(c, fx + math.cos(a) * (outer(a) - 1.6), fy + math.sin(a) * (outer(a) - 1.6),
               3.0, "leather", "sh")
    # The body of the coat, filled first so no undercoat shows through it.
    c.ellipse((fx - 9, fy - 9, fx + 9, fy + 9), "gold")
    c.ellipse((fx - 8, fy + 2, fx + 8, fy + 18), "gold")
    # The locks themselves. Each is a barely-tapered clump with a ROUND tip —
    # the tips are what form the silhouette, so the mane's edge comes out
    # lobed and matted instead of spiked.
    for i in range(26):
        a = math.tau * i / 26.0 - math.pi / 2.0
        o = outer(a) + (0.9 if i % 2 else -0.9)
        ox, oy = fx + math.cos(a) * o, fy + math.sin(a) * o
        _taper(c, (fx + math.cos(a) * 5.0, fy + math.sin(a) * 5.0), (ox, oy),
               2.9, 2.3, "gold")
        _clump(c, ox, oy, 2.3, "gold")
    # A second, shorter layer shingled over the first, lit on the upper-left
    # of the head and shaded on the lower-right, to give the coat volume.
    for i in range(18):
        a = math.tau * i / 18.0 - math.pi / 2.0 + 0.12
        mid = (outer(a) + 5.0) * 0.5
        lvl = "hi" if math.cos(a + math.pi * 0.75) > 0.45 else None
        _clump(c, fx + math.cos(a) * mid, fy + math.sin(a) * mid, 2.6, "gold", lvl)
    # Lock partings: short curved strokes lying in the outer half of the coat
    # only. Run all the way to the head they turn the mane into a starburst;
    # kept to the tips they read as the partings between hanging locks.
    for i in range(14):
        a = math.tau * i / 14.0 - math.pi / 2.0
        o = outer(a)
        c.line([(fx + math.cos(a + 0.04) * (o * 0.62), fy + math.sin(a + 0.04) * (o * 0.62)),
                (fx + math.cos(a + 0.13) * (o * 0.82), fy + math.sin(a + 0.13) * (o * 0.82)),
                (fx + math.cos(a + 0.19) * (o - 1.8), fy + math.sin(a + 0.19) * (o - 1.8))],
               "gold", "sh")
    # The face opening the mane hoods, with the ruff overhanging its brow.
    c.ellipse((11, 4, 20, 16), "dark")
    c.ellipse((12, 6, 19, 14), "dark", "sh")
    return c


def boots_of_the_balancer():
    ## Shoes made for walking a tightrope: thin, flexible, and shown on the wire.
    c = Canvas()
    # The wire, thin and taut all the way across — the thing that says
    # tightrope — with a single shoe balanced on it.
    c.rect((0, 24, 31, 24), "bone", "hi")
    c.rect((0, 25, 31, 25), "bone", "sh")
    # One slim shoe in profile: a low, soft, flexible slipper, not a boot.
    # It sits high and thin so the wire stays visible either side of it.
    c.poly([(7, 15), (12, 12), (19, 13), (24, 17), (27, 22), (27, 23), (7, 23)], "leather")
    c.rect((6, 22, 28, 24), "leather", "sh")      # thin gripping sole
    c.poly([(6, 15), (9, 14), (9, 23), (6, 23)], "leather", "sh")   # heel counter
    c.line([(9, 18), (24, 19)], "leather", "sh")  # the seam along the flex point
    # Lacing pulled tight across the instep, with the ties trailing loose.
    for ly in range(14, 21, 2):
        c.line([(13, ly), (18, ly + 1)], "bone", "hi")
    c.line([(18, 15), (22, 11)], "bone", "hi")
    c.line([(18, 15), (23, 14)], "bone", "hi")
    return c


def hermes_boots():
    ## Hermes' winged slippers: a soft low slipper with a feathered wing
    ## sweeping off each side of the heel.
    c = Canvas()
    # A wing off each side of the ankle, sweeping back and level rather than
    # straight up, so the pair reads as two wings and not one plume. Each is
    # a row of overlapping quills, longest at the leading edge.
    for (side, lvl) in ((1, "sh"), (-1, None)):
        hx, hy = 15 + side * 3, 18     # the ankle each wing springs from
        for i in range(4):
            a = math.radians(200 - i * 16) if side < 0 else math.radians(-20 + i * 16)
            length = 12.0 - i * 1.8
            tip = (hx + math.cos(a) * length, hy + math.sin(a) * length)
            _taper(c, (hx, hy), tip, 2.0, 1.0, "bone", lvl)
            c.line([(hx, hy), tip], "bone", "hi" if lvl is None else "sh")
    # The slipper: a low soft upper sitting under the wings, toe turning up.
    c.poly([(9, 20), (13, 18), (21, 18), (25, 20), (28, 23), (28, 26), (9, 26)], "leather")
    c.poly([(26, 20), (30, 18), (31, 22), (28, 24)], "leather")   # curled toe
    c.rect((8, 25, 29, 27), "leather", "sh")                      # thin sole
    c.ellipse((11, 17, 19, 22), "dark", "sh")                     # foot opening
    c.line([(12, 23), (26, 23)], "gold")                          # gold trim
    return c


def jordan_1s():
    ## Black and red Jordan 1s: black collar, red quarter panel and toe, black
    ## swoop, on a black sole with a red stripe.
    c = Canvas()
    # High-top silhouette in profile, toe to the right: the padded ankle
    # collar stands well above the throat of the shoe, which is what makes a
    # 1 read as a 1 rather than as a low-top.
    c.poly([(4, 6), (13, 6), (14, 14), (23, 17), (28, 20), (28, 24), (4, 24)], "dark")
    c.rect((4, 6, 13, 23), "dark")
    # Red panels: the ankle collar and the whole quarter panel through the
    # midfoot, leaving the toe box and the heel counter black.
    c.rect((4, 6, 13, 9), "blood")
    c.poly([(4, 14), (16, 14), (22, 18), (24, 24), (4, 24)], "blood")
    c.poly([(22, 17), (28, 20), (28, 24), (23, 24)], "dark", "sh")
    # The Swoosh, black across the red panel: thin at the heel, swelling as it
    # runs out toward the toe.
    _stroke(c, [(8, 21), (13, 19), (18, 17), (23, 19)], "dark", r_end=0.9, r_mid=1.9, level="sh")
    # Sole: a pale midsole curving up at the toe, outsole dark beneath it.
    c.poly([(3, 24), (29, 24), (29, 27), (3, 27)], "bone")
    c.poly([(26, 22), (29, 23), (29, 26), (26, 25)], "bone")
    c.rect((3, 26, 29, 26), "bone", "sh")
    c.poly([(4, 28), (28, 28), (27, 29), (5, 29)], "dark", "sh")
    # Collar padding and the lacing running up the throat.
    c.rect((5, 7, 12, 7), "blood", "hi")
    for ly in range(11, 22, 3):
        c.line([(11, ly), (15, ly + 1)], "bone", "hi")
    return c


def guardian_greaves():
    ## Holy plate warboots, steel banded in gold, winged at the ankle, with a
    ## healing light spilling out of the seams. Modelled on DOTA 2's Guardian
    ## Greaves — drawn from the item's description, not the Valve icon, so it
    ## is worth a second pass against a reference.
    c = Canvas()
    # One warboot, drawn big enough that the wings and the seams both read,
    # in profile with the toe to the right.
    c.poly([(10, 4), (20, 4), (21, 13), (22, 20), (8, 20), (9, 13)], "steel")  # greave
    c.poly([(8, 20), (21, 20), (27, 24), (28, 27), (7, 27)], "steel")          # the foot
    c.rect((9, 3, 21, 5), "gold")              # the crown of the greave
    for sy in (9, 15):                         # gold bands across the plate
        c.rect((9, sy, 21, sy + 1), "gold")
    c.rect((7, 27, 28, 28), "gold", "sh")      # the gold sole rail
    c.line([(11, 6), (10, 19)], "steel", "hi") # the plate's lit edge
    # The wings at the ankle: three stepped feathers off each side, swept back.
    for side in (-1, 1):
        ox = 15 + side * 6
        for i in range(3):
            a = math.radians(180 + i * 22) if side < 0 else math.radians(-i * 22)
            tip = (ox + math.cos(a) * (7 - i), 19 + math.sin(a) * (7 - i) - i * 2)
            _taper(c, (ox, 19), tip, 1.9, 0.9, "gold")
    # The healing light spilling out of the seams, brightest where the plates
    # actually meet rather than scattered over the boot.
    for (lx, ly) in ((9, 12), (21, 12), (9, 18), (21, 18)):
        c.line([(lx, ly), (lx, ly + 2)], "teal", "hi")
    for (lx, ly) in ((6, 25), (29, 25), (15, 2), (15, 21)):
        c.dot(lx, ly, "teal", "hi")
    return c


def gauntlets_of_dungeon_mastering():
    ## Silver gauntlets with a twenty-sided die set on each of the knuckles.
    ## Drawn as a closed fist seen from the back, because that is the view
    ## that puts all four knuckles — and so all four dice — in a row.
    c = Canvas()
    # The curled fingers above the knuckle line: four plated segments, each
    # capped round, with open air between them so they read as fingers.
    KNUCKLES = (5, 12, 19, 26)
    # The fingers standing above the knuckle row: four plated columns with
    # real gaps of background between them, so they read as separate digits.
    for i, fx in enumerate(KNUCKLES):
        top = (6, 3, 3, 5)[i]
        c.rect((fx - 2, top, fx + 1, 11), "steel")
        c.rect((fx - 1, top - 1, fx + 1, top - 1), "steel")   # squared plate cap
        c.rect((fx - 2, top, fx - 1, top), "steel", "hi")
        c.rect((fx - 2, 7, fx + 1, 7), "steel", "sh")         # first joint lame
    # The back of the hand: one broad mass drawn under the dice, drawing in
    # slightly toward the wrist so it is a hand and not a box.
    c.poly([(3, 16), (28, 16), (27, 23), (24, 27), (7, 27), (4, 23)], "steel")
    c.rect((4, 17, 5, 23), "steel", "hi")     # key light down the near edge
    c.rect((7, 26, 24, 26), "steel", "sh")
    c.line([(9, 21), (22, 21)], "steel", "sh")   # a single articulation lame
    # Knuckle sockets: the plate swells up under each die so the dice look
    # set into the gauntlet rather than resting on a black bar.
    for kx in KNUCKLES:
        c.ellipse((kx - 4, 13, kx + 4, 19), "steel")
        c.line([(kx - 3, 14), (kx - 2, 13)], "steel", "hi")
    # The thumb, folded across the near side of the fist.
    c.poly([(0, 17), (4, 16), (5, 21), (3, 26), (0, 25)], "steel")
    c.line([(1, 21), (4, 20)], "steel", "sh")
    # The cuff flaring off the wrist.
    c.poly([(7, 27), (24, 27), (28, 31), (3, 31)], "steel")
    c.rect((5, 29, 26, 29), "steel", "hi")
    # A d20 seated on each knuckle — the whole point of the item, so they are
    # drawn as large as four across 32px allows.
    for kx in KNUCKLES:
        _d20(c, kx, 14, 3.4, "gold")
    return c


def hallowed_trunk():
    ## A hollowed-out tree trunk with fluorescent green butterflies on it.
    c = Canvas()
    # It is worn over the arm, so it reads as a length of hollow trunk seen
    # end-on and slightly from above: the bore you put your arm through is
    # open at the top, the barrel of bark runs down from it.
    c.ellipse((6, 1, 26, 11), "wood")           # the cut top end
    c.rect((6, 6, 26, 26), "wood")
    c.ellipse((6, 22, 26, 30), "wood")          # the barrel's lower curve
    c.ellipse((9, 2, 23, 10), "dark")           # the hollow the arm goes into
    c.ellipse((11, 4, 21, 9), "dark", "sh")
    # Bark: ragged vertical ridges down the barrel, and a torn lower lip.
    for gx in (9, 13, 18, 23):
        c.line([(gx, 9), (gx - 1, 27)], "wood", "sh")
        c.line([(gx + 1, 10), (gx, 26)], "wood", "hi")
    for (kx, ky) in ((6, 16), (26, 14), (7, 25), (25, 24)):
        _clump(c, kx, ky, 1.8, "wood", "sh")
    # Fluorescent green butterflies resting on the bark: upper wings, smaller
    # lower wings, a body between them and a pair of antennae.
    for (bx, by) in ((10, 16), (21, 21), (27, 9), (14, 26)):
        c.poly([(bx - 1, by), (bx - 4, by - 3), (bx - 4, by + 1)], "leaf", "hi")
        c.poly([(bx + 1, by), (bx + 4, by - 3), (bx + 4, by + 1)], "leaf", "hi")
        c.poly([(bx - 1, by + 1), (bx - 3, by + 3), (bx - 1, by + 3)], "leaf")
        c.poly([(bx + 1, by + 1), (bx + 3, by + 3), (bx + 1, by + 3)], "leaf")
        c.rect((bx, by - 1, bx, by + 2), "leaf", "sh")
        c.dot(bx - 1, by - 3, "leaf", "hi")
        c.dot(bx + 1, by - 3, "leaf", "hi")
    return c


def cuffs_of_current():
    ## Four gold rings — one at each wrist, one below each elbow — with light
    ## blue electricity coming off them. Each arm's pair is drawn as a column.
    c = Canvas()
    # Four rings: the elbow pair up top, the wrist pair below, one arm held
    # higher than the other so they do not stack into a grid.
    for ox, oy0 in ((8, 7), (23, 10)):
        for oy in (oy0, oy0 + 14):
            # Seen almost face on, so each one reads as a round gold band
            # with an open bore rather than as a flattened lozenge.
            c.ellipse((ox - 6, oy - 6, ox + 6, oy + 6), "gold")
            c.ellipse((ox - 4, oy - 4, ox + 4, oy + 4), "dark", "sh")
            c.line([(ox - 3, oy - 6), (ox + 3, oy - 6)], "gold", "hi")
            c.line([(ox - 3, oy + 6), (ox + 3, oy + 6)], "gold", "sh")
        # Current running down the forearm between each pair of rings.
        c.line([(ox - 2, oy0 + 7), (ox + 2, oy0 + 9), (ox - 2, oy0 + 11),
                (ox + 1, oy0 + 13)], "current", "hi")
    # Arcs snapping across the gap between the two arms.
    c.line([(14, 8), (17, 10), (14, 12), (17, 14)], "current", "hi")
    c.line([(14, 22), (17, 24), (14, 26), (17, 28)], "current", "hi")
    # Sparks thrown clear of the rings entirely.
    for (sx, sy) in ((2, 14), (30, 8), (1, 26), (30, 29), (16, 2)):
        c.dot(sx, sy, "current", "hi")
    return c


def concealed_carry():
    ## A gauntlet that appears to be made of clouds of smoke: the shape of a
    ## hand, billowed out of overlapping puffs, trailing off at the edges.
    c = Canvas()
    # Fingers: four billowed columns with gaps of open air between them.
    for fx in (9, 14, 19, 24):
        c.ellipse((fx - 3, 3, fx + 1, 9), "smoke")
        c.rect((fx - 3, 6, fx + 1, 13), "smoke")
        c.ellipse((fx - 3, 10, fx + 1, 15), "smoke")
    # Back of the hand and the cuff, massed out of overlapping puffs.
    for (bx, by, r) in ((12, 16, 6), (20, 16, 6), (9, 21, 5), (23, 21, 5),
                        (16, 21, 7), (12, 26, 5), (20, 26, 5)):
        c.ellipse((bx - r, by - r, bx + r, by + r), "smoke")
    c.ellipse((2, 15, 9, 24), "smoke")   # thumb, curling off the side
    # Open air driven down between the fingers, deep enough that they part
    # instead of massing into a mitten.
    for gx in (11, 16, 21):
        c.carve(_rect_mask((gx, 1, gx + 1, 15)))
    # Highlights where the cloud catches the key light, upper-left first.
    for (hx, hy, r) in ((8, 17, 3), (14, 22, 3), (5, 22, 2)):
        c.ellipse((hx - r, hy - r, hx + r, hy - 1), "smoke", "hi")
    # The cuff, where the gauntlet would end — the one place the cloud gathers
    # thick enough to hold an edge.
    for bx in (8, 14, 20, 25):
        _clump(c, bx, 28, 3.4, "smoke")
    c.line([(6, 27), (26, 27)], "smoke", "hi")
    # Wisps tearing off the edges instead of an outline, so the whole thing
    # keeps dissolving back into smoke.
    for (wx, wy) in ((4, 10), (29, 11), (1, 26), (30, 27), (16, 31), (27, 5),
                     (3, 5), (12, 1), (21, 0)):
        c.dot(wx, wy, "smoke", "hi")
        c.dot(wx + (1 if wx < 16 else -1), wy + 1, "smoke", "sh")
    return c


def belt_of_scrolls():
    ## A wide leather belt hung with rolled parchment scrolls in loops, wax
    ## seals swinging below them.
    c = Canvas()
    # The belt band across the middle, with a simple frame buckle.
    c.rect((1, 10, 30, 17), "leather")
    c.rect((13, 9, 18, 18), "gold")
    c.rect((15, 11, 16, 16), "leather", "sh")
    # Scrolls tucked into loops on both sides of the buckle.
    for sx in (3, 8, 21, 26):
        c.rect((sx, 6, sx + 3, 20), "bone")
        c.rect((sx, 6, sx + 3, 7), "bone", "hi")     # rolled top edge
        c.rect((sx, 12, sx + 3, 14), "leather", "sh")  # the loop holding it
        # The wax seal swinging below on a short cord.
        c.line([(sx + 1, 20), (sx + 1, 23)], "leather", "sh")
        c.ellipse((sx, 23, sx + 2, 25), "blood")
    return c


def megingjord():
    ## Thor's girdle: broad iron-studded leather, a massive square buckle
    ## scored with runes.
    c = Canvas()
    # The broad band.
    c.rect((1, 9, 30, 20), "leather")
    c.rect((1, 9, 30, 10), "leather", "hi")
    c.rect((1, 19, 30, 20), "leather", "sh")
    # Iron studs marching down both wings.
    for sx in (3, 7, 24, 28):
        for sy in (12, 17):
            c.dot(sx, sy, "iron", "hi")
            c.dot(sx + 1, sy + 1, "iron", "sh")
    # The massive square buckle.
    c.rect((10, 6, 21, 23), "iron")
    c.rect((12, 8, 19, 21), "leather", "sh")
    # Runes scored into the tongue.
    c.line([(14, 10), (14, 19)], "gold", "hi")
    c.line([(14, 12), (17, 10)], "gold", "hi")
    c.line([(14, 15), (17, 19)], "gold", "hi")
    return c


def orions_belt():
    ## A midnight band with three star-bright studs in a perfect row.
    c = Canvas()
    # The midnight-blue band, slightly sagging like the asterism.
    c.poly([(1, 11), (30, 9), (30, 16), (1, 18)], "cloth")
    c.line([(1, 11), (30, 9)], "cloth", "hi")
    c.line([(1, 18), (30, 16)], "cloth", "sh")
    # Alnitak, Alnilam, Mintaka: three stars set in a row, each with a sparkle.
    for i, (sx, sy) in enumerate(((6, 14), (15, 13), (24, 12))):
        c.ellipse((sx - 1, sy - 1, sx + 1, sy + 1), "spark", "hi")
        c.dot(sx, sy - 2, "spark")
        c.dot(sx, sy + 2, "spark")
        c.dot(sx - 2, sy, "spark")
        c.dot(sx + 2, sy, "spark")
    return c


def girdle_of_aphrodite():
    ## A slender golden girdle woven like braided hair, clasped with a scallop
    ## shell at the front.
    c = Canvas()
    # Braided hair: a run of short strands laid alternately across the band,
    # each one crossing the last, with the parting between them shaded so the
    # over-and-under of a real plait reads at this size.
    for i, bx in enumerate(range(-2, 33, 4)):
        top, bot = ((13, 19) if i % 2 else (19, 13))
        _taper(c, (bx, top), (bx + 5, bot), 2.1, 2.1, "gold")
        c.line([(bx, top), (bx + 5, bot)], "gold", "hi")
        c.line([(bx + 1, top + (2 if i % 2 else -2)), (bx + 6, bot + (2 if i % 2 else -2))],
               "gold", "sh")
    # The scallop-shell clasp at the front: hinged at the top, fanning wider
    # as it drops, with the ribbed fan and scalloped lip a scallop needs to
    # read as a shell and not as a cone.
    c.poly([(14, 11), (18, 11), (24, 23), (8, 23)], "rose")
    c.poly([(13, 10), (19, 10), (19, 12), (13, 12)], "rose", "hi")   # the hinge ears
    for (lx, ly) in ((10, 23), (14, 24), (18, 24), (22, 23)):
        _clump(c, lx, ly, 2.2, "rose")                # the scalloped lower lip
    # Ribs fanning from the hinge, alternating lit and shaded so the fan
    # reads as corrugated rather than as flat pink.
    for i, fx in enumerate((9, 12, 15, 18, 21)):
        c.line([(16, 12), (fx, 24)], "rose", "hi" if i % 2 else "sh")
    c.line([(9, 22), (23, 22)], "rose", "sh")         # the growth line near the lip
    return c


def adimantium():
    ## Teal chest piece with a gold jewel on the chest.
    c = Canvas()
    # Pauldron flares over each shoulder.
    c.ellipse((1, 4, 10, 12), "teal")
    c.ellipse((21, 4, 30, 12), "teal")
    # The breastplate: broad at the chest, tapering to the waist.
    c.poly([(5, 4), (26, 4), (25, 18), (21, 28), (10, 28), (6, 18)], "teal")
    # Neckline opening.
    c.ellipse((12, 2, 19, 7), "dark")
    # Ridged plate lines following the taper.
    c.line([(8, 21), (23, 21)], "teal", "sh")
    c.line([(9, 25), (22, 25)], "teal", "sh")
    # The gold jewel set center-chest: a brilliant cut, with the table on top
    # catching the key light and the pavilion facets falling away under it.
    c.poly([(15.5, 8), (21, 13), (15.5, 20), (10, 13)], "gold")
    c.poly([(15.5, 9), (19, 13), (12, 13)], "gold", "hi")     # the table
    c.line([(12, 13), (15.5, 19)], "gold", "sh")              # pavilion facets
    c.line([(19, 13), (15.5, 19)], "gold", "sh")
    c.line([(10, 13), (21, 13)], "gold", "hi")                # the girdle line
    c.dot(13, 11, "gold", "hi")                               # the sparkle on it
    return c


def tigers_sunday_red():
    ## Sunday red: a red polo — short sleeves, open collar, buttoned placket.
    c = Canvas()
    # Sleeves out to each side.
    c.poly([(2, 8), (8, 5), (9, 15), (3, 16)], "blood")
    c.poly([(29, 8), (23, 5), (22, 15), (28, 16)], "blood")
    # The body of the polo.
    c.poly([(7, 4), (24, 4), (25, 28), (6, 28)], "blood")
    # Collar: two folded points around the neck opening.
    c.poly([(13, 2), (18, 2), (15, 6)], "dark")
    c.poly([(10, 2), (15, 2), (12, 9)], "blood", "sh")
    c.poly([(21, 2), (16, 2), (19, 9)], "blood", "sh")
    # Placket with pearl buttons.
    c.rect((15, 7, 16, 15), "blood", "sh")
    c.dot(15, 9, "bone", "hi")
    c.dot(15, 12, "bone", "hi")
    c.dot(15, 15, "bone", "hi")
    # Hem shadow.
    c.line([(7, 27), (24, 27)], "blood", "sh")
    return c


def divine_resistance():
    ## A shiny silver chest with a crescent moon and a sun on the breastplate.
    c = Canvas()
    # Pauldrons.
    c.ellipse((1, 4, 10, 12), "steel")
    c.ellipse((21, 4, 30, 12), "steel")
    # The polished cuirass.
    c.poly([(5, 4), (26, 4), (25, 18), (21, 28), (10, 28), (6, 18)], "steel")
    c.ellipse((12, 2, 19, 7), "dark")
    # Mirror shine streaking down the left of the plate.
    c.line([(8, 22), (10, 26)], "steel", "hi")
    # The sun, right of center: a gold disc with rays struck off it.
    c.ellipse((18, 11, 24, 17), "gold")
    c.dot(20, 12, "gold", "hi")
    for a8 in range(8):
        a = math.tau * a8 / 8.0 + math.pi / 8.0
        c.line([(21 + math.cos(a) * 4.0, 14 + math.sin(a) * 4.0),
                (21 + math.cos(a) * 6.0, 14 + math.sin(a) * 6.0)], "gold", "hi")
    # The crescent moon, left of center, cut properly so it reads as a moon
    # and not as a chipped disc.
    _crescent(c, (7, 10, 15, 18), 3, "bone", "hi")
    return c


def hide_of_garmr():
    ## A furry grey hide worn as a chest piece: shaggy fur, a spiked collar,
    ## and the wolf's head resting at the chest.
    c = Canvas()
    # The hide, cut and worn as a chest piece: shoulders out wide, the body
    # drawing in to the waist. The silhouette is built from rounded clumps so
    # the whole edge reads as pelt rather than as cut cloth.
    body = [(7, 9), (24, 9), (26, 17), (24, 26), (7, 26), (5, 17)]
    c.poly(body, "smoke")
    for (px_, py_) in ((5, 12), (5, 17), (6, 22), (26, 12), (26, 17), (25, 22),
                       (8, 27), (13, 28), (18, 28), (23, 27)):
        _clump(c, px_, py_, 2.6, "smoke")
    # Shoulders: the pelt bunching where it is thrown over them.
    for (sx, sy) in ((7, 10), (11, 9), (20, 9), (24, 10)):
        _clump(c, sx, sy, 3.0, "smoke")
    # Guard hairs lying down the pelt, each a short curved clump.
    for (gx, gy) in ((8, 14), (12, 16), (20, 16), (24, 14), (9, 21),
                     (13, 23), (19, 23), (23, 21), (16, 25)):
        c.line([(gx, gy - 2), (gx + 1, gy + 1), (gx, gy + 3)], "smoke", "sh")
        c.line([(gx - 1, gy - 2), (gx, gy + 1)], "smoke", "hi")
    # The spiked collar, banded across the shoulders and nowhere else.
    c.rect((4, 5, 27, 9), "leather")
    c.rect((4, 6, 27, 6), "leather", "hi")
    for sx in range(6, 27, 5):
        c.poly([(sx - 2, 5), (sx + 2, 5), (sx, 0)], "iron")
        c.dot(sx, 7, "iron", "sh")   # the stud each spike is set on
    # The wolf's head resting at the chest. It is ringed in dark first: the
    # pelt and the head are both grey, so without that separation the head
    # sinks into the fur it is lying on.
    c.poly([(9, 16), (23, 16), (24, 22), (20, 25), (12, 25), (8, 22)], "dark", "sh")
    c.poly([(9, 16), (12, 9), (16, 16)], "dark", "sh")
    c.poly([(23, 16), (20, 9), (16, 16)], "dark", "sh")
    c.poly([(13, 23), (19, 23), (18, 29), (14, 29)], "dark", "sh")
    c.poly([(11, 15), (13, 10), (15, 15)], "iron")             # pricked ears
    c.poly([(21, 15), (19, 10), (17, 15)], "iron")
    c.poly([(10, 17), (22, 17), (23, 21), (19, 24), (13, 24), (9, 21)], "iron")
    c.poly([(14, 22), (18, 22), (17, 28), (15, 28)], "iron")   # long muzzle
    c.line([(10, 18), (22, 18)], "iron", "hi")                 # brow
    for ex in (12, 18):                                        # eyes
        c.rect((ex, 19, ex + 1, 20), "dark", "sh")
    c.dot(15, 27, "dark", "sh")                                # nose
    c.dot(16, 27, "dark", "sh")
    return c


def sabre_tooth():
    ## A khatar: sabertooth tiger head at the grip, a giant tooth as the blade.
    c = Canvas()
    # The khatar's frame: two side bars running back along the forearm with
    # the grip bar slung between them — the H the fist closes around. The
    # bars are kept narrow and the grip short so it reads as a handle.
    c.rect((3, 22, 6, 31), "iron")
    c.rect((25, 22, 28, 31), "iron")
    c.rect((3, 22, 6, 22), "iron", "hi")
    c.rect((25, 22, 28, 22), "iron", "hi")
    c.rect((6, 28, 25, 30), "iron")
    c.rect((6, 28, 25, 28), "iron", "hi")
    for gx in (10, 15, 20):     # the grip's wrapped ridges
        c.dot(gx, 29, "iron", "sh")
    # The blade: one giant sabertooth fang, curving as it tapers, swelling
    # out of the tiger's jaw.
    _taper(c, (16, 20), (17, 12), 3.4, 2.6, "bone")
    _taper(c, (17, 12), (13, 1), 2.6, 0.8, "bone")
    c.line([(15, 17), (16, 11), (13, 4)], "bone", "hi")   # the fang's front ridge
    # The sabertooth's head, where the hand sits. Built with a flat brow and a
    # squared muzzle so it reads as a cat's skull rather than as a ball.
    c.poly([(7, 22), (10, 15), (14, 21)], "gold")     # ears, set wide
    c.poly([(25, 22), (22, 15), (18, 21)], "gold")
    c.poly([(8, 21), (24, 21), (25, 25), (21, 28), (11, 28), (7, 25)], "gold")
    c.poly([(9, 18), (23, 18), (24, 22), (8, 22)], "gold")           # brow ridge
    c.poly([(12, 24), (20, 24), (19, 28), (13, 28)], "gold", "sh")   # muzzle
    c.line([(9, 19), (23, 19)], "gold", "hi")
    for (sx, sy) in ((10, 20), (13, 19), (19, 19), (22, 20)):
        c.line([(sx, sy), (sx + 1, sy + 2)], "leather", "sh")        # stripes
    for ex in (11, 19):                                              # eyes
        c.rect((ex, 22, ex + 2, 23), "dark", "sh")
    c.dot(15, 25, "dark", "sh")                                      # nose
    c.dot(16, 25, "dark", "sh")
    # The lower fangs bared under the jaw, small against the great one above.
    c.poly([(12, 28), (14, 28), (13, 31)], "bone")
    c.poly([(20, 28), (18, 28), (19, 31)], "bone")
    return c


def poseidons_trident():
    ## Poseidon's trident: three barbed tines on a long sea-worn shaft.
    c = Canvas()
    # The shaft, rising through the middle.
    c.line([(15, 30), (15, 12)], "teal", None, 3)
    c.rect((14, 12, 16, 30), "teal")
    # The crossbar the tines spring from.
    c.rect((6, 12, 25, 14), "gold")
    c.rect((6, 12, 25, 12), "gold", "hi")
    # Three tines. The outer pair flare outward before turning back in to
    # their points, the center one runs straight up and stands tallest.
    for side in (-1, 1):
        _taper(c, (15.5 + side * 8, 12), (15.5 + side * 9.5, 6), 1.4, 1.1, "gold")
        _taper(c, (15.5 + side * 9.5, 6), (15.5 + side * 8, 1), 1.1, 0.5, "gold")
        # Barbs, hooked back off the inside of each outer tine.
        c.poly([(15.5 + side * 8, 5), (15.5 + side * 5, 7), (15.5 + side * 8, 8)], "gold")
    _taper(c, (15.5, 12), (15.5, 0), 1.5, 0.5, "gold")
    c.poly([(14, 5), (12, 7), (14, 8)], "gold")
    c.poly([(17, 5), (19, 7), (17, 8)], "gold")
    # Sea-spray thrown off the tines.
    for (wx, wy) in ((4, 8), (27, 7), (10, 3), (21, 2)):
        c.dot(wx, wy, "current", "hi")
    return c


def sword_of_theseus():
    ## A long broadsword: minotaur-head grip, horn cross-guards, and a second
    ## small blade jutting from the pommel.
    c = Canvas()
    # The main blade: long, wide, tapering to a point at the top.
    c.poly([(13, 1), (18, 1), (19, 4), (18, 16), (13, 16), (12, 4)], "steel")
    c.poly([(13, 2), (18, 2), (15.5, 0)], "steel", "hi")
    c.line([(15, 3), (15, 15)], "steel", "hi")   # the fuller
    # The cross-guard IS the pair of horns, sweeping out of the head and
    # curling up at their tips.
    for side in (-1, 1):
        base = 15.5 + side * 3
        _taper(c, (base, 18), (15.5 + side * 12, 17), 2.2, 1.2, "bone")
        _taper(c, (15.5 + side * 12, 17), (15.5 + side * 14, 12), 1.2, 0.6, "bone")
    # The minotaur's head as the grip: broad skull, muzzle dropping to the
    # pommel, a ring through the nose.
    c.poly([(11, 17), (20, 17), (21, 22), (19, 25), (12, 25), (10, 22)], "leather")
    c.poly([(13, 24), (18, 24), (17, 28), (14, 28)], "leather", "sh")   # muzzle
    c.poly([(11, 17), (13, 13), (15, 17)], "leather")                   # ears
    c.poly([(20, 17), (18, 13), (16, 17)], "leather")
    for ex in (13, 17):
        c.dot(ex, 20, "dark", "sh")
        c.dot(ex + 1, 20, "dark", "sh")
    c.dot(14, 26, "dark", "sh")
    c.dot(17, 26, "dark", "sh")
    # The second, smaller blade jutting from the pommel.
    c.poly([(14, 28), (17, 28), (15.5, 31)], "steel")
    return c


def umbral_eclipse():
    ## A double-headed hammer: a face on both ends, the lunar cycle inlaid
    ## along the handle, a full moon on both hammer faces.
    c = Canvas()
    # A head on both ends of the shaft, each face slightly belled out.
    for (ty, by) in ((0, 5), (26, 31)):
        c.rect((7, ty, 24, by), "iron")
        c.rect((5, ty + 1, 26, by - 1), "iron")
        c.rect((7, ty, 24, ty), "iron", "hi")
        c.rect((7, by, 24, by), "iron", "sh")
    # A full moon struck into both faces, cratered so it is plainly the moon.
    for my in (2, 28):
        c.ellipse((12, my - 2, 19, my + 2), "bone", "hi")
        c.dot(14, my - 1, "bone", "sh")
        c.dot(17, my, "bone", "sh")
    # The shaft, wide enough to carry the inlay.
    c.rect((12, 5, 19, 26), "wood")
    c.rect((12, 5, 12, 26), "wood", "hi")
    c.rect((19, 5, 19, 26), "wood", "sh")
    # The lunar cycle inlaid down the handle. Each phase is kept to three rows
    # with two clear rows of wood after it — at this size the gaps are what
    # make it read as a cycle of separate moons rather than one white stripe.
    for i, phase in enumerate(("waxing", "quarter", "full", "waning")):
        y = 7 + i * 5
        if phase == "waxing":
            _crescent(c, (14, y, 18, y + 3), 2, "bone", "hi")
        elif phase == "quarter":
            c.poly([(16, y), (18, y + 1), (18, y + 2), (16, y + 3)], "bone", "hi")
        elif phase == "full":
            c.ellipse((14, y, 18, y + 3), "bone", "hi")
        else:
            _crescent(c, (13, y, 17, y + 3), -2, "bone", "hi")
    return c


def bow_of_arash():
    ## Arash's divine longbow: golden limbs drawn in a great arc, a bright
    ## string, and the blue glisten of its territorial mark about the grip.
    c = Canvas()
    limb = [(24, 2), (16, 4), (10, 9), (8, 16), (10, 23), (16, 28), (24, 30)]
    # The string, taut between the two limb tips.
    c.line([(24, 2), (24, 30)], "bone", "hi")
    # The golden limbs, thickest at the belly of the arc where the grip sits.
    _stroke(c, limb, "gold", r_end=1.2, r_mid=2.4)
    c.line([(24, 2), (16, 4), (10, 9)], "gold", "hi")
    # Nocks turned back at both tips to take the string.
    c.dot(24, 2, "gold", "sh")
    c.dot(24, 30, "gold", "sh")
    # The leather-wrapped grip, set on the limb rather than floating beside it.
    c.rect((6, 13, 11, 19), "leather")
    for wy in (14, 16, 18):
        c.line([(6, wy), (11, wy)], "leather", "sh")
    # The blue glisten of the territorial mark, drifting off the wood.
    for (wx, wy) in ((4, 8), (3, 22), (14, 1), (14, 31), (2, 15), (20, 6)):
        c.dot(wx, wy, "current", "hi")
        c.dot(wx + 1, wy + 1, "current", "sh")
    return c


def belthronding():
    ## Belthronding: a longbow of dark black yew-wood, its stiff ends fitted
    ## with hard animal horn.
    c = Canvas()
    limb = [(22, 5), (15, 6), (10, 10), (8, 16), (10, 22), (15, 26), (22, 27)]
    # The string, drawn down the right between the horn nocks.
    c.line([(23, 3), (23, 29)], "bone", "sh")
    # The limb, cut from black yew — the darkest wood on the palette.
    _stroke(c, limb, "dark", r_end=1.4, r_mid=2.6)
    c.line([(22, 5), (15, 6), (10, 10)], "dark", "hi")
    # The stiff horn the ends are fitted with: a hard cap over each tip, with
    # the string notched into it.
    for (hy, ny) in ((5, 3), (27, 29)):
        _taper(c, (20, hy), (23, ny), 2.2, 1.0, "bone")
        c.dot(23, ny, "bone", "hi")
    # A leather wrap at the grip.
    c.rect((6, 13, 11, 19), "leather")
    for wy in (14, 16, 18):
        c.line([(6, wy), (11, wy)], "leather", "sh")
    return c


def bow_of_budding_blasts():
    ## Bow of Budding Blasts: a thick, slimy sea-cucumber of a bow, little
    ## bows budding off its flanks.
    c = Canvas()
    # The string, bowed down the right side.
    c.line([(24, 3), (24, 28)], "current", "hi")
    # The body: a thick sea-cucumber of a bow, lumpy along its whole length.
    _stroke(c, [(24, 3), (16, 5), (11, 10), (9, 16), (11, 22), (16, 27), (24, 28)],
            "teal", r_end=1.8, r_mid=3.4)
    for (lx, ly) in ((18, 4), (13, 8), (10, 16), (13, 24), (18, 28)):
        _clump(c, lx, ly, 2.6, "teal")
    # Buds sprouting off the flank — each one a whole small bow, string and
    # all, budding off its parent.
    for (bx, by, s) in ((4, 9, 1.0), (3, 21, 0.9), (15, 1, 0.8)):
        _stroke(c, [(bx + 3 * s, by - 4 * s), (bx - 2 * s, by), (bx + 3 * s, by + 4 * s)],
                "leaf", r_end=0.9, r_mid=1.5)
        c.line([(bx + 3 * s, by - 4 * s), (bx + 3 * s, by + 4 * s)], "leaf", "hi")
    # Slime beading up and running off the belly.
    for (wx, wy) in ((10, 13), (12, 22), (19, 6), (9, 18), (17, 26)):
        c.dot(wx, wy, "current", "hi")
    return c


def _ring_band(c, cx=15, cy=17, outer=9, inner=5, mat="gold"):
    ## Shared ring silhouette: a band drawn as an ellipse with a carved hole,
    ## slightly squashed so it reads as a ring lying toward the viewer.
    c.stamp(_ellipse_mask((cx - outer, cy - outer + 2, cx + outer, cy + outer)), mat)
    c.carve(_ellipse_mask((cx - inner, cy - inner + 3, cx + inner, cy + inner - 1)))


def the_precious():
    ## The One Ring: plain gold, the elvish script glowing faintly around the
    ## band. It looks like nothing much. That is the point.
    c = Canvas()
    _ring_band(c, 15, 16, 10, 6, "gold")
    # The elvish script: traced faintly, so it is engraving catching the light
    # around the band rather than the fire-writing it only shows in flame.
    for i in range(16):
        a = math.tau * i / 16.0
        sx = int(round(15 + math.cos(a) * 7.8))
        sy = int(round(17 + math.sin(a) * 7.4))
        c.set(sx, sy, "gold", "sh" if i % 2 else "hi")
    return c


def draupnir():
    ## Draupnir: the Viking arm-ring that drips new rings — three small bands
    ## falling from the great one.
    c = Canvas()
    _ring_band(c, 15, 12, 8, 4, "gold")
    # The dripping child-rings.
    for (rx, ry) in ((6, 24), (15, 27), (24, 24)):
        c.stamp(_ellipse_mask((rx - 3, ry - 3, rx + 3, ry + 3)), "gold")
        c.carve(_ellipse_mask((rx - 1, ry - 1, rx + 1, ry + 1)))
    return c


def ring_of_nibelung():
    ## The Ring of the Nibelung: a plain band forged from Rhine-gold,
    ## Alberich's curse gleaming red in its heart.
    c = Canvas()
    _ring_band(c, 15, 16, 10, 6, "gold")
    # The curse is not set on the ring — it gleams in its heart. The red is
    # held small and centered so the bore still reads as an open hole with
    # something burning down inside it.
    c.ellipse((13, 14, 18, 19), "blood", "sh")
    c.ellipse((14, 15, 17, 18), "blood")
    c.dot(15, 16, "blood", "hi")
    for (gx, gy) in ((12, 13), (19, 13), (12, 20), (19, 20)):
        c.dot(gx, gy, "blood", "sh")   # the curse's glow licking the band
    return c


def ring_of_thomas_the_train_tracks():
    ## A ring whose band is laid track — sleepers across the rails — crowned
    ## not with a diamond but with that famous round blue face.
    c = Canvas()
    cx, cy, rad = 15, 19, 8.5
    # The sleepers come first, laid radially like ties under a curving line,
    # so the two iron rails can be run over the top of them.
    for i in range(14):
        a = math.tau * i / 14.0
        ux, uy = math.cos(a), math.sin(a)
        px_, py_ = -uy, ux
        c.poly([(cx + ux * (rad - 3.2) + px_ * 1.1, cy + uy * (rad - 3.2) + py_ * 1.1),
                (cx + ux * (rad - 3.2) - px_ * 1.1, cy + uy * (rad - 3.2) - py_ * 1.1),
                (cx + ux * (rad + 2.2) - px_ * 1.1, cy + uy * (rad + 2.2) - py_ * 1.1),
                (cx + ux * (rad + 2.2) + px_ * 1.1, cy + uy * (rad + 2.2) + py_ * 1.1)],
               "wood")
    # The two rails, run as concentric iron rings over the sleepers.
    for r in (rad - 2.4, rad + 1.4):
        ring = ImageChops.difference(_ellipse_mask((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1)),
                                     _ellipse_mask((cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1)))
        c.stamp(ring, "iron")
    # Where the diamond should sit: Thomas' face, on his blue boiler front.
    c.ellipse((9, 1, 22, 13), "cloth")
    c.ellipse((11, 2, 20, 11), "bone")
    for ex in (13, 17):                       # wide eyes, pupils looking out
        c.rect((ex, 4, ex + 2, 6), "bone", "hi")
        c.dot(ex + 1, 5, "dark", "sh")
    c.line([(13, 8), (14, 9), (17, 9), (18, 8)], "dark", "sh")   # the smile
    c.dot(15, 7, "bone", "sh")
    return c


def delfins_deterministic_round_shield():
    ## "A wooden shield banded with iron."
    c = Canvas()
    # The round board.
    c.ellipse((3, 2, 28, 29), "wood")
    # Iron bands: a vertical spine and a horizontal crossbar, plus the rim.
    c.rect((14, 3, 17, 28), "iron")
    c.rect((4, 14, 27, 17), "iron")
    rim = ImageChops.difference(_ellipse_mask((3, 2, 28, 29)), _ellipse_mask((5, 4, 26, 27)))
    c.stamp(rim, "iron")
    # Iron boss riveted over the crossing.
    c.ellipse((12, 12, 19, 19), "iron")
    c.dot(14, 14, "iron", "hi")
    c.dot(17, 17, "iron", "sh")
    # Plank seams read through the timber on both wings.
    c.line([(8, 5), (8, 26)], "wood", "sh")
    c.line([(23, 5), (23, 26)], "wood", "sh")
    return c


def steve_rodgers_bastion():
    ## "The Captain America shield."
    c = Canvas()
    c.ellipse((2, 2, 29, 29), "blood")
    c.ellipse((5, 5, 26, 26), "bone")
    c.ellipse((8, 8, 23, 23), "blood")
    c.ellipse((11, 11, 20, 20), "cloth")
    # The white star at the center.
    star = []
    for i in range(10):
        a = math.tau * i / 10.0 - math.pi / 2.0
        r = 5.0 if i % 2 == 0 else 2.1
        star.append((15.5 + math.cos(a) * r, 15.5 + math.sin(a) * r))
    c.poly(star, "bone", "hi")
    return c


def presence_of_mind():
    ## "A black kite shield marked in yellow: a man sitting in meditation, a
    ## half crescent moon above his head."
    c = Canvas()
    # Kite shield: square shoulders tapering to a point. Held flat black —
    # the levels are forced so the plate stays black and the mark stays the
    # only thing with any brightness on it.
    c.poly([(5, 1), (26, 1), (26, 15), (15.5, 31), (5, 15)], "dark", "sh")
    c.line([(5, 1), (26, 1)], "dark", "hi")     # a thin rim catching the light
    c.line([(5, 1), (5, 15)], "dark", "hi")
    c.line([(26, 2), (26, 15)], "dark", "base")
    # The half crescent, riding just above the man's head.
    _crescent(c, (11, 2, 20, 10), 4, "gold", "hi")
    # The meditant. Drawn as one solid gold silhouette — head, body, and the
    # wide seat of the crossed legs — with the arms CARVED BACK OUT of it in
    # black. At 32px cutting the arms into the body reads far better than
    # trying to draw them alongside it, where they only fuse with the torso.
    c.ellipse((14, 10, 17, 13), "gold", "hi")            # head
    c.poly([(13, 15), (18, 15), (20, 24), (11, 24)], "gold", "hi")   # body
    c.poly([(8, 24), (23, 24), (21, 28), (10, 28)], "gold", "hi")    # crossed legs
    _clump(c, 9, 25, 1.8, "gold", "hi")                  # the knees, rounded off
    _clump(c, 22, 25, 1.8, "gold", "hi")
    # The arms, cut into the silhouette as they fall from the shoulders and
    # come to rest on the knees.
    for side in (-1, 1):
        c.line([(15.5 + side * 2, 17), (15.5 + side * 4, 20), (15.5 + side * 4, 23)],
               "dark", "sh")
    c.line([(14, 25), (17, 25)], "dark", "sh")           # the lap, under the hands
    return c


def crooked_dueling_shield():
    ## "A steel shield shaped like an S, swelling slightly fatter through the
    ## center."
    c = Canvas()
    # Read it as the letter S and nothing else: the spine starts at the top
    # right terminal, sweeps left over the upper bowl, crosses back through
    # the waist, and finishes at the bottom left terminal.
    spine = [(24, 8), (23, 5), (19, 3), (15, 3), (11, 5), (10, 8), (11, 11),
             (14, 13), (16, 15), (18, 17), (21, 19), (22, 22), (21, 25),
             (17, 27), (13, 27), (9, 25), (8, 22)]
    # Thin at both terminals, swelling fatter through the center of the S.
    _stroke(c, spine, "steel", r_end=2.0, r_mid=3.6)
    # A fuller chased down the middle of the swell, following the same curve
    # so the plate reads as a shaped shield rather than a flat letter.
    for (x, y, t) in _lerp_path(spine):
        if 0.18 < t < 0.82:
            c.set(int(round(x)), int(round(y)), "steel", "sh")
    # Rivets at the two terminals and at the waist where the grip sits behind.
    for (rx, ry) in ((23, 6), (16, 15), (10, 24)):
        c.dot(rx, ry, "iron", "hi")
        c.dot(rx + 1, ry + 1, "iron", "sh")
    return c


def wand_of_the_phoenix_feather():
    ## A red wand shaped like a single long feather, a phoenix head at the
    ## pommel — golden beak, dark eye, a small crest of flame.
    c = Canvas()
    # The feather: a curved spine sweeping up to the tip.
    spine = [(16, 25), (15, 18), (15, 11), (17, 3)]
    _stroke(c, spine, "blood", r_end=0.6, r_mid=1.0)
    # Barbs off both sides of the spine, longer near the pommel.
    for i, (bx, by) in enumerate(((15, 22), (15, 19), (15, 16), (15, 13), (15, 10), (16, 7))):
        w = 5 - i // 2
        c.line([(bx - w, by + 2), (bx, by)], "blood", "sh")
        c.line([(bx + w, by + 1), (bx, by)], "blood")
    c.line([(15, 23), (16, 5)], "blood", "hi")  # the spine catches the light
    # The phoenix head at the pommel.
    c.ellipse((12, 25, 19, 30), "gold")
    c.poly([(19, 26), (24, 28), (19, 29)], "gold", "sh")   # the beak
    c.dot(15, 27, "dark", "sh")                            # the eye
    for (fx, fy) in ((12, 24), (14, 23), (16, 24)):        # the flame crest
        c.dot(fx, fy, "blood", "hi")
    return c


def circes_wand_of_cauldron_stirring():
    ## A thin tree branch with living smaller branches coiled around its
    ## length — the sorceress's wand exactly as the tale tells it.
    c = Canvas()
    # The branch itself, running corner to corner.
    c.line([(6, 29), (25, 3)], "wood", None, 2)
    c.line([(7, 28), (25, 4)], "wood", "hi")
    # Two live shoots spiral around it, crossing over and back.
    _stroke(c, [(8, 30), (12, 24), (10, 20), (15, 16), (13, 12), (19, 8), (17, 5), (23, 2)],
            "leaf", r_end=0.5, r_mid=0.7)
    _stroke(c, [(5, 26), (10, 23), (14, 19), (12, 14), (18, 11), (16, 7), (22, 4)],
            "wood", r_end=0.5, r_mid=0.6)
    # Buds where the coils cross the branch.
    for (lx, ly) in ((11, 22), (14, 14), (20, 6)):
        c.dot(lx, ly, "leaf", "hi")
    return c


def reaper_scythe():
    ## A towering reaper's scythe, a blue substance forever dripping from the
    ## edge of its great crescent blade.
    c = Canvas()
    # The snath: a long haft with the reaper's slight double bend.
    _stroke(c, [(9, 31), (12, 21), (12, 11), (15, 3)], "wood", r_end=1.0, r_mid=1.3)
    # The blade sweeping off the head to the right, hollow along its belly.
    c.poly([(15, 2), (21, 2), (27, 5), (30, 10), (25, 8), (19, 6), (15, 5)], "steel")
    c.line([(16, 2), (27, 5)], "steel", "hi")
    # The blue substance, beading along the edge and falling free.
    for (dx, dy) in ((19, 8), (23, 9), (28, 11)):
        c.dot(dx, dy, "current", "hi")
    c.line([(21, 10), (21, 12)], "current")
    c.dot(25, 14, "current")
    c.dot(21, 16, "current", "sh")
    return c


def feral_evocation():
    ## A great white staff crowned by a tiger's open mouth, a purple orb
    ## glowing between its fangs.
    c = Canvas()
    # The staff, stout and bone-white.
    c.rect((14, 13, 17, 31), "bone")
    c.rect((14, 13, 14, 31), "bone", "hi")
    c.rect((17, 13, 17, 31), "bone", "sh")
    # The tiger's skull, ears up, jaw hinged wide.
    c.poly([(9, 2), (22, 2), (24, 6), (20, 8), (11, 8), (7, 6)], "gold")
    c.poly([(9, 2), (8, 0), (11, 3)], "gold")          # ears
    c.poly([(22, 2), (23, 0), (20, 3)], "gold")
    for sx in (12, 15, 18):                            # the stripes
        c.line([(sx, 2), (sx, 3)], "dark", "sh")
    c.dot(11, 5, "dark", "sh")                         # eyes
    c.dot(20, 5, "dark", "sh")
    # The lower jaw, open wide where the mouth swallows the staff's head.
    c.poly([(9, 13), (22, 13), (20, 11), (11, 11)], "gold")
    # Fangs closing on the orb from above and below.
    c.poly([(10, 8), (12, 8), (11, 11)], "bone", "hi")
    c.poly([(21, 8), (19, 8), (20, 11)], "bone", "hi")
    # The purple orb glowing between them.
    c.ellipse((13, 7, 18, 12), "cloth")
    c.dot(14, 8, "cloth", "hi")
    return c


ICONS = {
    "bladed_doughnut": bladed_doughnut,
    "the_headbandz": the_headbandz,
    "scholars_cap": scholars_cap,
    "hannibals_mask": hannibals_mask,
    "mane_of_narashimha": mane_of_narashimha,
    "boots_of_the_balancer": boots_of_the_balancer,
    "hermes_boots": hermes_boots,
    "jordan_1s": jordan_1s,
    "guardian_greaves": guardian_greaves,
    "gauntlets_of_dungeon_mastering": gauntlets_of_dungeon_mastering,
    "hallowed_trunk": hallowed_trunk,
    "cuffs_of_current": cuffs_of_current,
    "concealed_carry": concealed_carry,
    "belt_of_scrolls": belt_of_scrolls,
    "megingjord": megingjord,
    "orions_belt": orions_belt,
    "girdle_of_aphrodite": girdle_of_aphrodite,
    "adimantium": adimantium,
    "tigers_sunday_red": tigers_sunday_red,
    "divine_resistance": divine_resistance,
    "hide_of_garmr": hide_of_garmr,
    "sabre_tooth": sabre_tooth,
    "poseidons_trident": poseidons_trident,
    "sword_of_theseus": sword_of_theseus,
    "umbral_eclipse": umbral_eclipse,
    "bow_of_arash": bow_of_arash,
    "belthronding": belthronding,
    "bow_of_budding_blasts": bow_of_budding_blasts,
    "the_precious": the_precious,
    "draupnir": draupnir,
    "ring_of_nibelung": ring_of_nibelung,
    "ring_of_thomas_the_train_tracks": ring_of_thomas_the_train_tracks,
    "delfins_deterministic_round_shield": delfins_deterministic_round_shield,
    "steve_rodgers_bastion": steve_rodgers_bastion,
    "presence_of_mind": presence_of_mind,
    "crooked_dueling_shield": crooked_dueling_shield,
    "wand_of_the_phoenix_feather": wand_of_the_phoenix_feather,
    "circes_wand_of_cauldron_stirring": circes_wand_of_cauldron_stirring,
    "reaper_scythe": reaper_scythe,
    "feral_evocation": feral_evocation,
}


def main():
    ## Set MYTHIC_ICON_SHEET to a path to also drop a 4x contact sheet there
    ## (proofing aid; the sheet is not a game asset).
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet_path = os.environ.get("MYTHIC_ICON_SHEET", "")
    sheet = Image.new("RGBA", (G * 4 * 4, G * 4 * 4), (18, 18, 24, 255))
    over_budget = []
    for i, (slug, fn) in enumerate(ICONS.items()):
        img = render(fn())
        colors = {c for c in img.getdata() if c[3]}
        if len(colors) > 15:
            over_budget.append((slug, len(colors)))
        img.save(os.path.join(OUT_DIR, "%s.png" % slug))
        big = img.resize((G * 4, G * 4), Image.NEAREST)
        sheet.paste(big, ((i % 4) * G * 4, (i // 4) * G * 4), big)
        print("%-34s %2d colors" % (slug, len(colors)))
    if sheet_path:
        sheet.save(sheet_path)
    if over_budget:
        raise SystemExit("over the 15-color budget: %s" % over_budget)


if __name__ == "__main__":
    main()
