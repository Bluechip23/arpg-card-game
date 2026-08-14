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
    # The three cards stand above the band, the middle one riding highest,
    # each in its own dark sleeve so they read as three separate cards.
    for i, cx in enumerate((2, 12, 22)):
        top = 2 if i == 1 else 5
        c.rect((cx - 1, top - 1, cx + 8, 21), "dark")
        c.rect((cx, top, cx + 7, 21), "bone")
        c.rect((cx + 1, top + 1, cx + 6, top + 2), "cloth", "hi")  # header band
        c.rect((cx + 2, top + 5, cx + 5, top + 10), "cloth")       # the pip
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


def hannibals_mask():
    ## Hannibal Lecter's mask: a hard leather muzzle over the lower face with a
    ## steel grille bolted across the mouth, strapped around the head.
    c = Canvas()
    # Straps: one over the crown, one around the head, buckled at both cheeks.
    c.rect((2, 13, 29, 16), "leather", "sh")
    c.rect((13, 1, 18, 12), "leather", "sh")
    c.rect((2, 12, 5, 17), "iron")
    c.rect((26, 12, 29, 17), "iron")
    # The muzzle: covers the nose down to the chin, tapering to the jaw.
    c.poly([(8, 8), (23, 8), (24, 20), (20, 27), (11, 27), (7, 20)], "leather")
    c.rect((10, 6, 21, 9), "leather")
    # Breathing holes punched over the nose.
    for hx in (13, 16, 19):
        c.dot(hx, 10, "dark", "sh")
    # The grille: vertical bars crossed by two horizontals, over the mouth.
    c.rect((9, 14, 22, 24), "dark", "sh")
    for bx in range(10, 23, 3):
        c.rect((bx, 14, bx, 24), "iron", "hi")
    c.rect((9, 16, 22, 16), "iron", "hi")
    c.rect((9, 22, 22, 22), "iron", "hi")
    return c


def mane_of_narashimha():
    ## A huge lion's mane: it hoods the top of the head and falls all the way
    ## down the back to mid-spine.
    c = Canvas()
    # The fall: from the shoulders it hangs straight down the back, widening.
    c.poly([(8, 8), (23, 8), (26, 20), (25, 29), (6, 29), (5, 20)], "gold")
    # The hood over the crown.
    c.ellipse((7, 1, 24, 16), "gold")
    # Shaggy edge down both sides and a ragged fringe along the bottom.
    for sy in range(9, 29, 3):
        w = 4 + (sy - 9) // 6
        c.poly([(7, sy), (7, sy + 3), (7 - w, sy + 2)], "gold")
        c.poly([(24, sy), (24, sy + 3), (24 + w, sy + 2)], "gold")
    for fx in range(5, 26, 4):
        c.poly([(fx, 26), (fx + 4, 26), (fx + 2, 31)], "gold")
    # Tufts over the crown.
    for i in range(7):
        a = math.pi + math.pi * i / 6.0
        c.poly([(15.5 + math.cos(a) * 8, 8 + math.sin(a) * 7),
                (15.5 + math.cos(a) * 9.5, 8 + math.sin(a) * 8.5),
                (15.5 + math.cos(a) * 11, 8 + math.sin(a) * 10)], "gold")
    # Fur combed downward through the fall.
    for fx in range(8, 25, 3):
        c.line([(fx, 14), (fx - 1, 27)], "gold", "sh")
    # The face opening at the front of the hood.
    c.ellipse((11, 4, 20, 15), "dark")
    c.ellipse((13, 6, 18, 13), "dark", "sh")
    return c


def boots_of_the_balancer():
    ## Shoes made for walking a tightrope: thin, flexible, and shown on the wire.
    c = Canvas()
    # The wire, taut across the icon, the shoe balanced on top of it.
    c.rect((0, 24, 31, 24), "bone", "hi")
    c.rect((0, 25, 31, 25), "bone", "sh")
    # One slim shoe in profile, sitting mid-wire: heel back-left, toe forward.
    c.poly([(7, 11), (13, 9), (19, 12), (23, 17), (25, 22), (7, 22)], "leather")
    c.rect((6, 21, 25, 23), "leather", "sh")   # thin gripping sole
    c.rect((6, 11, 9, 22), "leather", "sh")    # stiff heel counter
    c.poly([(23, 18), (26, 21), (26, 23), (23, 23)], "leather")  # tapered toe
    # Lacing pulled tight across the instep.
    for ly in range(12, 20, 2):
        c.line([(12, ly), (18, ly + 1)], "bone", "hi")
    return c


def hermes_boots():
    ## Hermes' winged slippers: a soft low slipper with a feathered wing
    ## sweeping off each side of the heel.
    c = Canvas()
    # Wings: three stepped feathers off each side, swept back and up.
    for side in (-1, 1):
        ox = 16 - side * 3
        for i in range(3):
            tip_x = ox + side * (9 + i * 3)
            c.poly([(ox, 14 - i), (tip_x, 8 - i * 3), (tip_x - side * 3, 15 - i)], "bone")
        c.line([(ox, 14), (ox + side * 13, 7)], "bone", "sh")
    # The slipper: low soft upper with the toe curling up, open at the ankle.
    c.poly([(6, 16), (10, 13), (20, 13), (25, 16), (27, 20), (26, 23), (6, 23)], "leather")
    c.poly([(26, 15), (29, 13), (29, 18), (26, 19)], "leather")   # curled toe
    c.rect((5, 22, 27, 24), "leather", "sh")                       # sole
    c.ellipse((9, 12, 18, 18), "dark", "sh")                       # foot opening
    c.line([(10, 20), (24, 20)], "gold")                           # trim
    return c


def jordan_1s():
    ## Black and red Jordan 1s: black collar, red quarter panel and toe, black
    ## swoop, on a black sole with a red stripe.
    c = Canvas()
    # Upper in black: ankle collar back-left, toe forward-right.
    c.poly([(5, 5), (16, 5), (16, 13), (27, 17), (29, 21), (5, 21)], "dark")
    c.rect((5, 5, 15, 20), "dark")
    # Red collar trim, heel panel and toe cap — the rest stays black.
    c.rect((5, 5, 15, 7), "blood")
    c.poly([(5, 13), (12, 13), (12, 21), (5, 21)], "blood")
    c.poly([(23, 15), (29, 20), (29, 21), (23, 21)], "blood")
    # Sole: black midsole with a red stripe running through it.
    c.poly([(3, 20), (29, 20), (29, 26), (3, 26)], "dark")
    c.rect((3, 22, 29, 23), "blood")
    c.rect((3, 25, 29, 26), "dark", "sh")
    # Lacing up the instep.
    for ly in range(10, 20, 3):
        c.line([(16, ly), (21, ly + 1)], "smoke", "hi")
    # The swoop down the flank: red where it crosses the black midfoot.
    c.line([(8, 19), (17, 14)], "blood", "hi", width=2)
    c.line([(17, 14), (24, 17)], "blood", "hi", width=2)
    return c


def guardian_greaves():
    ## Holy plate warboots, steel banded in gold, winged at the ankle, with a
    ## healing light spilling out of the seams. Modelled on DOTA 2's Guardian
    ## Greaves — drawn from the item's description, not the Valve icon, so it
    ## is worth a second pass against a reference.
    c = Canvas()
    for ox in (4, 18):
        # Greave over the shin, boot flaring out at the foot.
        c.rect((ox + 1, 5, ox + 9, 22), "steel")
        c.poly([(ox, 22), (ox + 10, 22), (ox + 11, 29), (ox - 1, 29)], "steel")
        # Gold bands across the plate, and a gold sole rail.
        for sy in (10, 16):
            c.rect((ox + 1, sy, ox + 9, sy + 1), "gold")
        c.rect((ox - 1, 27, ox + 11, 28), "gold", "sh")
        # Wing plates sweeping off the ankle.
        c.poly([(ox + 1, 19), (ox - 3, 17), (ox - 2, 23)], "gold")
        c.poly([(ox + 9, 19), (ox + 13, 17), (ox + 12, 23)], "gold")
        # The crown of the greave.
        c.rect((ox, 4, ox + 10, 6), "gold")
    # Holy light spilling out from under the plate.
    for (lx, ly) in ((2, 8), (15, 3), (30, 8), (16, 13), (1, 24), (30, 24), (16, 25)):
        c.dot(lx, ly, "teal", "hi")
    return c


def gauntlets_of_dungeon_mastering():
    ## Silver gauntlets with a twenty-sided die set on each of the knuckles.
    c = Canvas()
    # Silver plate: short fingers up top, back of the hand, flared cuff.
    for fx in range(8, 25, 4):
        c.rect((fx, 4, fx + 2, 10), "steel")
    c.rect((7, 9, 25, 23), "steel")
    for gx in range(11, 25, 4):
        c.carve(_rect_mask((gx, 3, gx, 8)))
    c.poly([(7, 15), (4, 17), (4, 22), (7, 23)], "steel")  # thumb
    c.poly([(5, 23), (27, 23), (29, 29), (3, 29)], "steel")
    c.rect((5, 26, 29, 26), "steel", "sh")
    c.rect((7, 17, 25, 17), "steel", "sh")                 # knuckle ridge line
    # A d20 sitting on each knuckle: dark bezel, gold shell, face turned up.
    for kx in (9, 13, 17, 21):
        c.poly([(kx, 9), (kx + 3, 11), (kx + 3, 14), (kx, 16),
                (kx - 3, 14), (kx - 3, 11)], "dark")
        c.poly([(kx, 10), (kx + 2, 11), (kx + 2, 14), (kx, 15),
                (kx - 2, 14), (kx - 2, 11)], "gold", "sh")
        c.poly([(kx, 11), (kx + 2, 14), (kx - 2, 14)], "gold", "hi")
    return c


def hallowed_trunk():
    ## A hollowed-out tree trunk with fluorescent green butterflies on it.
    c = Canvas()
    c.rect((8, 3, 23, 25), "wood")
    # Splayed roots at the foot of the trunk.
    c.poly([(7, 23), (14, 23), (11, 30), (4, 29)], "wood")
    c.poly([(13, 23), (19, 23), (19, 30), (13, 30)], "wood")
    c.poly([(18, 23), (25, 23), (28, 29), (21, 30)], "wood")
    # Bark grooves down the trunk.
    for gx in (10, 14, 21):
        c.line([(gx, 5), (gx, 22)], "wood", "sh")
    # The hollow itself, opened right through the trunk.
    c.ellipse((11, 8, 20, 20), "dark")
    c.ellipse((13, 11, 18, 17), "dark", "sh")
    # Fluorescent green butterflies resting on the bark and drifting off it.
    for (bx, by) in ((9, 6), (20, 13), (16, 22), (25, 5), (5, 17)):
        c.poly([(bx - 2, by - 2), (bx, by), (bx - 2, by + 1)], "leaf", "hi")
        c.poly([(bx + 2, by - 2), (bx, by), (bx + 2, by + 1)], "leaf", "hi")
        c.dot(bx, by, "leaf", "sh")
    return c


def cuffs_of_current():
    ## Four gold rings — one at each wrist, one below each elbow — with light
    ## blue electricity coming off them. Each arm's pair is drawn as a column.
    c = Canvas()
    for ox, oy0 in ((7, 4), (22, 10)):   # the two arms, one held higher
        for oy in (oy0, oy0 + 14):
            # The ring, seen slightly on edge: a gold band with a dark bore.
            c.ellipse((ox - 6, oy - 3, ox + 6, oy + 3), "gold")
            c.ellipse((ox - 4, oy - 2, ox + 4, oy + 2), "dark", "sh")
            c.rect((ox - 6, oy - 3, ox + 6, oy - 3), "gold", "hi")
            c.rect((ox - 6, oy + 3, ox + 6, oy + 3), "gold", "sh")
        # Current running down between each arm's two rings.
        c.line([(ox - 3, oy0 + 4), (ox + 2, oy0 + 7), (ox - 2, oy0 + 9),
                (ox + 3, oy0 + 12)], "current", "hi")
        c.line([(ox + 4, oy0 + 5), (ox + 6, oy0 + 8), (ox + 3, oy0 + 10)], "current", "sh")
    # Arcs snapping between the two arms, and sparks thrown clear.
    c.line([(13, 6), (17, 9), (15, 12), (19, 14)], "current", "hi")
    c.line([(12, 20), (16, 22), (14, 25), (18, 26)], "current", "hi")
    for (sx, sy) in ((2, 10), (29, 17), (3, 22), (28, 29), (16, 2)):
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
    # Open air between the fingers, so the hand reads out of the cloud.
    for gx in (11, 16, 21):
        c.carve(_poly_mask([(gx, 2), (gx + 1, 2), (gx + 1, 13), (gx, 13)]))
    # Highlights where the cloud catches the key light, upper-left first.
    for (hx, hy, r) in ((8, 17, 3), (14, 22, 3), (5, 22, 2)):
        c.ellipse((hx - r, hy - r, hx + r, hy - 1), "smoke", "hi")
    # Wisps tearing off the edges instead of an outline.
    for (wx, wy) in ((4, 11), (29, 12), (1, 27), (28, 28), (16, 30), (26, 6)):
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
    # The slender band, dipping gently at the front.
    c.poly([(1, 12), (30, 12), (30, 17), (16, 20), (1, 17)], "gold")
    # The braid: alternating weave marks along the band.
    for bx in range(3, 29, 4):
        c.line([(bx, 13), (bx + 2, 17)], "gold", "sh")
        c.line([(bx + 2, 13), (bx, 17)], "gold", "hi")
    # The scallop-shell clasp at the front dip.
    c.ellipse((11, 14, 21, 24), "rose")
    c.poly([(11, 16), (21, 16), (16, 25)], "rose")
    for fx in (13, 16, 19):
        c.line([(16, 24), (fx, 16)], "rose", "sh")
    c.rect((11, 15, 21, 15), "rose", "hi")
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
    # The gold jewel: a faceted diamond set center-chest.
    c.poly([(15.5, 9), (20, 14), (15.5, 19), (11, 14)], "gold")
    c.dot(14, 12, "gold", "hi")
    c.dot(17, 16, "gold", "sh")
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
    c.line([(8, 9), (11, 23)], "steel", "hi")
    # The sun: a gold disc ringed with rays, right of center.
    c.ellipse((17, 11, 23, 17), "gold")
    for a8 in range(8):
        a = math.tau * a8 / 8.0
        c.dot(int(round(20 + math.cos(a) * 4.5)), int(round(14 + math.sin(a) * 4.5)), "gold", "hi")
    # The crescent moon left of center: a bone disc with the bite returned to steel.
    c.ellipse((8, 11, 14, 17), "bone")
    c.ellipse((10, 10, 15, 16), "steel")
    return c


def hide_of_garmr():
    ## A furry grey hide worn as a chest piece: shaggy fur, a spiked collar,
    ## and the wolf's head resting at the chest.
    c = Canvas()
    # The hide: a furry torso with a ragged hem.
    c.poly([(6, 7), (25, 7), (26, 20), (24, 28), (7, 28), (5, 20)], "smoke")
    for fx in range(5, 27, 4):
        c.poly([(fx, 26), (fx + 4, 26), (fx + 2, 31)], "smoke")
    # Shaggy side fur.
    for sy in range(9, 25, 4):
        c.poly([(6, sy), (6, sy + 3), (2, sy + 2)], "smoke")
        c.poly([(25, sy), (25, sy + 3), (29, sy + 2)], "smoke")
    # Fur combed downward.
    for fx in range(8, 25, 3):
        c.line([(fx, 12), (fx - 1, 26)], "smoke", "sh")
    # The spiked collar across the shoulders.
    c.rect((5, 5, 26, 8), "leather")
    for sx in range(6, 26, 4):
        c.poly([(sx, 5), (sx + 2, 1), (sx + 3, 5)], "iron")
    # The wolf's head at the chest: ears, skull, muzzle, eyes.
    c.poly([(11, 12), (13, 9), (14, 12)], "iron")
    c.poly([(20, 12), (18, 9), (17, 12)], "iron")
    c.ellipse((10, 11, 21, 22), "iron")
    c.poly([(13, 20), (18, 20), (15, 25)], "iron", "sh")
    c.dot(13, 15, "dark", "sh")
    c.dot(18, 15, "dark", "sh")
    c.dot(15, 22, "dark", "sh")
    return c


def sabre_tooth():
    ## A khatar: sabertooth tiger head at the grip, a giant tooth as the blade.
    c = Canvas()
    # The tooth blade: a long curved fang sweeping up.
    c.poly([(13, 16), (18, 16), (17, 6), (15, 1)], "bone")
    c.line([(15, 3), (16, 12)], "bone", "hi")
    # The tiger head grip: gold-furred head with dark stripes and bared fangs.
    c.ellipse((9, 15, 22, 27), "gold")
    c.poly([(9, 17), (12, 13), (13, 18)], "gold")   # ears
    c.poly([(22, 17), (19, 13), (18, 18)], "gold")
    for sx in (11, 15, 19):
        c.line([(sx, 16), (sx + 1, 20)], "leather", "sh")  # stripes
    c.dot(13, 20, "dark", "sh")
    c.dot(18, 20, "dark", "sh")
    # Bared side fangs below the jaw and the crossbar the fist holds.
    c.poly([(11, 26), (13, 26), (12, 30)], "bone")
    c.poly([(20, 26), (18, 26), (19, 30)], "bone")
    c.rect((7, 28, 24, 30), "iron")
    return c


def poseidons_trident():
    ## Poseidon's trident: three barbed tines on a long sea-worn shaft.
    c = Canvas()
    # The shaft, rising through the middle.
    c.line([(15, 30), (15, 12)], "teal", None, 3)
    c.rect((14, 12, 16, 30), "teal")
    # The crossbar.
    c.rect((7, 12, 24, 14), "gold")
    # Three tines: outer pair curve up from the bar, center runs straight.
    c.rect((7, 3, 9, 12), "gold")
    c.poly([(7, 3), (9, 3), (8, 0)], "gold", "hi")
    c.rect((22, 3, 24, 12), "gold")
    c.poly([(22, 3), (24, 3), (23, 0)], "gold", "hi")
    c.rect((14, 1, 16, 12), "gold")
    c.poly([(14, 1), (16, 1), (15, -2)], "gold", "hi")
    # Sea-spray droplets.
    for (wx, wy) in ((5, 8), (26, 7), (11, 5), (20, 4)):
        c.dot(wx, wy, "current", "hi")
    return c


def sword_of_theseus():
    ## A long broadsword: minotaur-head grip, horn cross-guards, and a second
    ## small blade jutting from the pommel.
    c = Canvas()
    # The main blade, wide and long.
    c.poly([(13, 0), (18, 0), (17, 17), (14, 17)], "steel")
    c.line([(15, 1), (15, 15)], "steel", "hi")
    # Horn cross-guards curving out and up.
    c.poly([(5, 17), (13, 17), (12, 20), (6, 20)], "bone")
    c.poly([(5, 17), (7, 17), (4, 12)], "bone")
    c.poly([(18, 17), (26, 17), (25, 20), (19, 20)], "bone")
    c.poly([(24, 17), (26, 17), (27, 12)], "bone")
    # The minotaur head grip.
    c.ellipse((12, 19, 19, 26), "leather")
    c.dot(14, 22, "dark", "sh")
    c.dot(17, 22, "dark", "sh")
    # The pommel's second blade, jutting down.
    c.poly([(14, 26), (17, 26), (15, 31)], "steel")
    return c


def umbral_eclipse():
    ## A double-headed hammer: a face on both ends, the lunar cycle inlaid
    ## along the handle, a full moon on both hammer faces.
    c = Canvas()
    # The two hammer heads, top and bottom.
    c.rect((8, 1, 23, 9), "iron")
    c.rect((8, 22, 23, 30), "iron")
    # Full moons on both faces.
    c.ellipse((13, 2, 18, 7), "bone", "hi")
    c.ellipse((13, 23, 18, 28), "bone", "hi")
    # The shaft between them.
    c.rect((14, 9, 17, 22), "wood")
    # The lunar cycle inlaid down the handle: waxing, full, waning.
    c.dot(15, 11, "bone", "sh")
    c.ellipse((14, 13, 16, 15), "bone")
    c.ellipse((14, 17, 16, 19), "bone", "hi")
    c.dot(15, 21, "bone", "sh")
    return c


def bow_of_arash():
    ## Arash's divine longbow: golden limbs drawn in a great arc, a bright
    ## string, and the blue glisten of its territorial mark about the grip.
    c = Canvas()
    # The string, taut down the right side between the limb tips.
    c.line([(23, 3), (23, 28)], "bone", "hi")
    # The golden limb, arcing out to the left.
    c.line([(23, 3), (14, 5), (8, 10), (6, 16), (8, 22), (14, 27), (23, 28)],
           "gold", None, 3)
    # A leather-wrapped grip at the belly of the arc.
    c.rect((4, 14, 9, 18), "leather")
    # The blue glistening smoke of the mark, drifting off the limbs.
    for (wx, wy) in ((3, 8), (2, 21), (12, 1), (12, 30), (1, 15)):
        c.dot(wx, wy, "current", "hi")
    return c


def belthronding():
    ## Belthronding: a longbow of dark black yew-wood, its stiff ends fitted
    ## with hard animal horn.
    c = Canvas()
    # The string, drawn down the right.
    c.line([(22, 4), (22, 27)], "bone", "sh")
    # The black yew limb.
    c.line([(22, 4), (13, 6), (8, 11), (6, 16), (8, 21), (13, 25), (22, 27)],
           "dark", None, 3)
    # Stiff horn ends, capping both limb tips.
    c.poly([(19, 2), (24, 3), (21, 7)], "bone")
    c.poly([(19, 29), (24, 28), (21, 24)], "bone")
    # A leather wrap at the grip.
    c.rect((4, 14, 9, 18), "leather")
    return c


def bow_of_budding_blasts():
    ## Bow of Budding Blasts: a thick, slimy sea-cucumber of a bow, little
    ## bows budding off its flanks.
    c = Canvas()
    # The string, bowed down the right side.
    c.line([(23, 4), (23, 27)], "current", "hi")
    # The slimy body: fat overlapping lobes along the arc.
    for box in ((16, 2, 24, 8), (10, 5, 18, 12), (6, 10, 14, 21),
                (10, 19, 18, 26), (16, 23, 24, 29)):
        c.ellipse(box, "teal")
    # Buds sprouting off the flank — each a tiny bow-to-be.
    c.ellipse((2, 8, 6, 12), "leaf")
    c.ellipse((1, 19, 5, 23), "leaf")
    c.ellipse((13, 0, 17, 3), "leaf")
    # Slime beads glistening down the belly.
    for (wx, wy) in ((9, 14), (11, 23), (18, 6), (8, 18)):
        c.dot(wx, wy, "current", "hi")
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
