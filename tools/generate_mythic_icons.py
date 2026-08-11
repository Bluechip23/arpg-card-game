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
    c = Canvas()
    # Brow band straight across, tapering slightly at the far end.
    c.rect((1, 11, 23, 19), "cloth")
    c.rect((1, 12, 2, 18), "cloth", "hi")
    c.rect((1, 18, 23, 18), "cloth", "sh")
    # Knot on the right temple, with two tails trailing down off it.
    c.ellipse((21, 9, 28, 20), "cloth")
    c.rect((23, 9, 25, 20), "cloth", "sh")
    c.poly([(25, 19), (28, 20), (29, 29), (26, 29)], "cloth")
    c.poly([(20, 19), (23, 20), (21, 29), (18, 27)], "cloth")
    c.carve(_rect_mask((24, 21, 25, 31)))
    # Five gems sewn along the brow — one per card slot.
    for gx in (3, 7, 11, 15, 19):
        c.rect((gx, 14, gx + 1, 16), "gold")
        c.dot(gx, 14, "gold", "hi")
    return c


def scholars_cap():
    ## "A stiff mortarboard, gold tassel always swinging, equations inked
    ## across the underside of the board."
    c = Canvas()
    # Skull cap under the board.
    c.ellipse((9, 13, 23, 26), "dark")
    c.rect((9, 18, 23, 24), "dark")
    # The board itself: a flat diamond.
    c.poly([(2, 12), (16, 6), (30, 12), (16, 18)], "dark")
    c.line([(3, 13), (16, 19)], "dark", "sh")
    c.line([(16, 19), (29, 13)], "dark", "sh")
    # Inked equations along the underside of the board.
    for (ex, ey) in ((10, 15), (13, 16), (19, 16), (22, 15), (16, 17)):
        c.dot(ex, ey, "bone", "sh")
    # Button + tassel: cord out to the corner, then hanging with a tuft.
    c.rect((15, 11, 17, 13), "gold")
    c.line([(16, 12), (27, 13)], "gold")
    c.line([(27, 13), (27, 22)], "gold")
    c.poly([(25, 22), (29, 22), (28, 28), (26, 28)], "gold")
    c.dot(26, 24, "gold", "sh")
    c.dot(28, 26, "gold", "sh")
    return c


def hanibals_mask():
    ## "A muzzle of dark leather, steel grate over the mouth, two buckles at
    ## the temple, straps pulled tight."
    c = Canvas()
    # Straps running off both cheeks, pulled tight into buckles at the ends.
    c.rect((1, 12, 30, 15), "leather", "sh")
    c.rect((1, 11, 4, 16), "gold")
    c.rect((27, 11, 30, 16), "gold")
    # Mask face.
    c.ellipse((7, 3, 24, 29), "leather")
    c.rect((7, 10, 24, 24), "leather")
    # Eye slits.
    c.rect((10, 9, 13, 11), "dark", "sh")
    c.rect((18, 9, 21, 11), "dark", "sh")
    c.dot(10, 9, "dark", "hi")
    c.dot(18, 9, "dark", "hi")
    # Steel grate over the mouth: five bars behind two bands.
    c.rect((9, 16, 22, 26), "dark", "sh")
    for bx in range(10, 23, 3):
        c.rect((bx, 16, bx, 26), "steel")
    c.rect((9, 18, 22, 19), "steel", "sh")
    c.rect((9, 23, 22, 24), "steel", "sh")
    # Stitched seam down the nose.
    c.line([(15, 12), (15, 15)], "leather", "sh")
    return c


def mane_of_narashimha():
    ## "A lion's mane worn like a hood, gold-white at the tips, framing a dark
    ## hollow. Amber eyes inside it; the upper fangs still sit in the brow."
    c = Canvas()
    # Ragged mane: a disc with fur spikes pushed out all the way round.
    for i in range(12):
        ang = i / 12.0
        dx = [1, 0.87, 0.5, 0, -0.5, -0.87, -1, -0.87, -0.5, 0, 0.5, 0.87][i]
        dy = [0, 0.5, 0.87, 1, 0.87, 0.5, 0, -0.5, -0.87, -1, -0.87, -0.5][i]
        tip = (16 + dx * 15.5, 16 + dy * 15.5)
        c.poly([(16 + (dx * 10 - dy * 4), 16 + (dy * 10 + dx * 4)),
                (16 + (dx * 10 + dy * 4), 16 + (dy * 10 - dx * 4)),
                tip], "gold")
    c.ellipse((3, 3, 28, 28), "gold")
    c.ellipse((6, 6, 25, 25), "leather")
    # Fur strands combed outward through the inner ring.
    for i in range(12):
        a = math.tau * (i + 0.5) / 12.0
        c.line([(16 + math.cos(a) * 7, 16 + math.sin(a) * 7),
                (16 + math.cos(a) * 11, 16 + math.sin(a) * 11)], "leather", "sh")
    # The face hollow, with a muzzle pushed out of the dark.
    c.ellipse((9, 10, 22, 26), "dark")
    c.ellipse((12, 17, 19, 23), "leather", "sh")
    c.rect((15, 18, 16, 19), "dark", "sh")
    # Amber eyes above, upper fangs biting down out of the muzzle.
    c.rect((11, 14, 12, 15), "gold", "hi")
    c.rect((19, 14, 20, 15), "gold", "hi")
    c.dot(14, 22, "bone", "hi")
    c.dot(14, 23, "bone", "hi")
    c.dot(17, 22, "bone", "hi")
    c.dot(17, 23, "bone", "hi")
    return c


def boots_of_the_balancer():
    ## "Close-laced boots with a brass scale-and-beam stamped on the shaft,
    ## pans hanging level, soles wrapped in rope."
    c = Canvas()
    # Boot: shaft above, foot striding forward, rope-wrapped sole.
    c.poly([(8, 2), (19, 2), (20, 19), (7, 19)], "leather")
    c.poly([(7, 18), (20, 18), (27, 22), (29, 26), (7, 26)], "leather")
    c.rect((6, 26, 29, 28), "bone", "sh")
    for rx in range(7, 29, 3):
        c.dot(rx, 27, "bone", "hi")
    # Brass scale stamped on the shaft: post, beam, two pans hanging level.
    c.rect((13, 4, 14, 16), "gold")
    c.rect((9, 6, 18, 6), "gold")
    for cx in (9, 18):  # chains down to the pans
        c.line([(cx, 7), (cx, 9)], "gold", "sh")
    c.poly([(7, 10), (11, 10), (10, 12), (8, 12)], "gold", "hi")
    c.poly([(16, 10), (20, 10), (19, 12), (17, 12)], "gold", "hi")
    c.rect((8, 12, 10, 12), "gold", "sh")
    c.rect((17, 12, 19, 12), "gold", "sh")
    # Close lacing over the instep.
    for ly in range(20, 26, 2):
        c.line([(21, ly), (25, ly + 1)], "bone", "hi")
    return c


def hermes_boots():
    ## "Weightless sandals of pale wrapped leather, a white feathered wing at
    ## each ankle, resting a finger's width off the ground."
    c = Canvas()
    # Wings sweeping back off both ankles.
    for side in (-1, 1):
        ox = 16 + side * 7
        for i, (dx, dy) in enumerate(((4, 0), (6, 2), (7, 5))):
            c.poly([(ox, 9 + i * 2), (ox + side * dx, 8 + dy), (ox, 13 + i * 2)], "bone")
    # Sandal body + sole.
    c.rect((11, 8, 20, 20), "leather")
    c.poly([(11, 19), (20, 19), (26, 22), (26, 25), (11, 25)], "leather")
    c.rect((10, 25, 26, 26), "bone", "sh")
    # Wrapping straps.
    for sy in (11, 15, 19):
        c.rect((11, sy, 20, sy), "bone", "hi")
    # Hovering: a two-step dash of ground it never touches.
    for dx in range(11, 26, 4):
        c.dot(dx, 29, "steel", "sh")
        c.dot(dx + 1, 29, "steel", "sh")
    return c


def jordan_1s():
    ## "High-tops in red and bone-white leather, double-laced, a wing stitched
    ## over the ankle and a black swoop down the flank. Somehow spotless."
    c = Canvas()
    # Upper: ankle collar back-left, toe forward-right.
    c.poly([(5, 6), (16, 6), (16, 14), (27, 18), (29, 22), (5, 22)], "blood")
    c.rect((5, 6, 15, 21), "blood")
    # Bone-white sole with a raised heel.
    c.poly([(3, 21), (29, 21), (29, 26), (3, 26)], "bone")
    c.rect((3, 22, 29, 23), "bone", "hi")
    c.rect((3, 25, 29, 26), "bone", "sh")
    # Collar padding + the wing stitched over the ankle.
    c.rect((5, 6, 15, 8), "bone")
    c.line([(7, 10), (12, 10)], "bone", "hi")
    c.line([(7, 11), (11, 11)], "bone", "hi")
    c.dot(9, 12, "bone", "hi")
    # Double lacing up the instep.
    for ly in range(11, 21, 3):
        c.line([(16, ly), (21, ly + 1)], "bone", "hi")
        c.line([(16, ly + 1), (21, ly + 2)], "bone", "sh")
    # The swoop down the flank: a bone-white sweep with a dark keyline under it.
    c.line([(6, 19), (17, 15)], "bone", "hi", width=2)
    c.line([(17, 15), (25, 18)], "bone", "hi", width=2)
    c.line([(6, 21), (17, 17)], "dark", "sh")
    c.line([(17, 17), (25, 20)], "dark", "sh")
    return c


def guardian_greaves():
    ## "Full plate greaves, heavy as an anvil, a shield engraved on each shin,
    ## a soft light bleeding out of the seams."
    c = Canvas()
    for ox in (5, 18):
        c.rect((ox, 4, ox + 8, 24), "steel")
        c.poly([(ox - 1, 24), (ox + 9, 24), (ox + 10, 29), (ox - 2, 29)], "steel")
        # Plate seams across the shin.
        for sy in (9, 14, 19):
            c.rect((ox, sy, ox + 8, sy), "steel", "sh")
            c.rect((ox, sy + 1, ox + 8, sy + 1), "steel", "hi")
        # Engraved shield on the shin.
        c.poly([(ox + 1, 5), (ox + 7, 5), (ox + 7, 9), (ox + 4, 12), (ox + 1, 9)], "gold")
        c.rect((ox + 3, 7, ox + 5, 8), "gold", "sh")
    # Light bleeding out of the seams, top-left key light first.
    for (lx, ly) in ((3, 6), (2, 12), (15, 3), (30, 9), (29, 17), (14, 27)):
        c.dot(lx, ly, "teal", "hi")
    return c


def gauntlets_of_dungeon_mastering():
    ## "A worn leather glove with a gold twenty-sided die set into the back of
    ## the hand. It rerolls itself when nobody is looking."
    c = Canvas()
    # Fingers, hand, flared cuff — the fingers keep visible gaps between them.
    for fx in range(9, 24, 4):
        c.rect((fx, 4, fx + 2, 11), "leather")
    c.rect((8, 9, 24, 23), "leather")
    for gx in range(12, 24, 4):
        c.carve(_rect_mask((gx, 3, gx, 9)))
    c.poly([(8, 14), (5, 16), (5, 21), (8, 22)], "leather")  # thumb
    c.poly([(6, 23), (26, 23), (28, 29), (4, 29)], "leather")
    c.rect((6, 25, 28, 25), "leather", "sh")
    # The d20 set into the back of the hand: hexagon shell, faceted face.
    c.poly([(16, 9), (24, 13), (24, 22), (16, 26), (8, 22), (8, 13)], "dark")
    c.poly([(16, 10), (23, 14), (23, 21), (16, 25), (9, 21), (9, 14)], "gold", "sh")
    c.poly([(16, 12), (21, 22), (11, 22)], "gold", "hi")   # the face turned up
    for tip, corners in (((16, 12), ((9, 14), (23, 14))),
                         ((21, 22), ((23, 21), (16, 25))),
                         ((11, 22), ((9, 21), (16, 25)))):
        for corner in corners:
            c.line([tip, corner], "gold", "base")
    return c


def hallowed_trunk():
    ## "Bark grown into the shape of an arm — a hollowed trunk, knot-holed and
    ## split, sap beading in the cracks, green shoots out of the knuckles."
    c = Canvas()
    c.rect((9, 4, 22, 24), "wood")
    # Splayed roots for fingers.
    c.poly([(8, 22), (14, 22), (11, 30), (5, 29)], "wood")
    c.poly([(13, 22), (19, 22), (19, 30), (13, 30)], "wood")
    c.poly([(18, 22), (24, 22), (27, 29), (21, 30)], "wood")
    # Bark grooves down the trunk.
    for gx in (11, 15, 20):
        c.line([(gx, 6), (gx, 21)], "wood", "sh")
    # The hollow knot.
    c.ellipse((12, 9, 19, 16), "dark")
    c.ellipse((14, 11, 17, 14), "dark", "sh")
    # Sap beading out of the cracks.
    for (sx, sy) in ((11, 18), (20, 8), (16, 20)):
        c.dot(sx, sy, "gold", "hi")
        c.dot(sx, sy + 1, "gold", "sh")
    # Green shoots pushing out of the knuckles.
    c.line([(22, 6), (26, 3)], "leaf")
    c.poly([(25, 2), (28, 3), (25, 5)], "leaf")
    c.line([(10, 5), (7, 3)], "leaf")
    c.poly([(4, 2), (8, 3), (5, 5)], "leaf")
    return c


def cuffs_of_current():
    ## "Twin steel cuffs, unfinished at the seam, a live arc of blue lightning
    ## crossing the gap."
    c = Canvas()
    for (y0, y1) in ((5, 11), (20, 26)):
        c.rect((4, y0, 27, y1), "steel")
        c.rect((4, y0 + 2, 27, y0 + 2), "steel", "sh")
        # Rivets along the band.
        for rx in range(6, 27, 5):
            c.dot(rx, y1 - 1, "steel", "sh")
    # The unfinished seam: a gap bitten out of both cuffs.
    c.carve(_rect_mask((13, 4, 18, 12)))
    c.carve(_rect_mask((13, 19, 18, 27)))
    # Live arc crossing the gaps, top to bottom.
    arc = [(16, 2), (14, 7), (17, 10), (15, 15), (18, 18), (14, 23), (17, 26), (15, 30)]
    c.line(arc, "spark", "sh", width=2)
    c.line([(p[0], p[1]) for p in arc], "spark", "hi")
    # Sparks jumping off the arc.
    for (sx, sy) in ((11, 14), (21, 16), (12, 24), (20, 8)):
        c.dot(sx, sy, "spark", "hi")
    return c


def concealed_carry():
    ## "A plain forearm wrap you would not look at twice, with a spring-loaded
    ## blade folded flat along the underside and a holster inside the cuff."
    c = Canvas()
    # The wrap.
    c.poly([(6, 4), (20, 4), (22, 19), (8, 19)], "leather")
    for sy in (7, 11, 15):
        c.rect((6, sy, 21, sy), "leather", "sh")
        c.rect((6, sy + 1, 21, sy + 1), "leather", "hi")
    # Buckle at the top of the cuff.
    c.rect((11, 2, 15, 5), "iron")
    # The hidden blade, out of its housing and running down past the wrist.
    c.rect((12, 18, 17, 21), "iron")
    c.poly([(13, 20), (17, 20), (24, 30), (20, 30)], "steel")
    c.line([(15, 21), (22, 30)], "steel", "hi")
    # Small holster stitched inside the cuff.
    c.poly([(3, 9), (7, 9), (7, 17), (3, 16)], "leather", "sh")
    c.dot(5, 11, "iron", "hi")
    return c


ICONS = {
    "bladed_doughnut": bladed_doughnut,
    "the_headbandz": the_headbandz,
    "scholars_cap": scholars_cap,
    "hanibals_mask": hanibals_mask,
    "mane_of_narashimha": mane_of_narashimha,
    "boots_of_the_balancer": boots_of_the_balancer,
    "hermes_boots": hermes_boots,
    "jordan_1s": jordan_1s,
    "guardian_greaves": guardian_greaves,
    "gauntlets_of_dungeon_mastering": gauntlets_of_dungeon_mastering,
    "hallowed_trunk": hallowed_trunk,
    "cuffs_of_current": cuffs_of_current,
    "concealed_carry": concealed_carry,
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
