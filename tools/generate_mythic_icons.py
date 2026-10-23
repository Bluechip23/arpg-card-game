#!/usr/bin/env python3
"""Mythic appearance icons: one 32x32 sprite per mythic item, drawn from that
item's `appearance` description in scripts/progression/item_data.gd — for the
mythics the designer has not painted yet. The painted ones (helms, chests,
the Sabre Tooth, Theseus' sword, Umbral Eclipse, Poseidon's trident,
gauntlets, boots) are cut from their sheets by tools/cut_mythic_art.py and are
not drawn here.

Output: assets/items/mythic/<slug>.png — the art the inventory shows for the
mythic (its storage cell, equipment slot and detail panel).

House style (docs/STYLE_GUIDE.md): drawn to read beside the Craftpix icon
packs the inventory already uses (slot icons, treasure) — a near-black,
hue-tinted outline, a bright upper-left rim with a white glint, two shadow
bands toward the lower right, punchy saturation, <= 20 colors per sprite.
The material ramps start from the master palette and are pushed harder at
render time.

Shading is mechanical rather than hand-placed: every sprite is painted as
material regions, then a single pass lights each region by its distance to
the region's edge (rim, base, mid, shadow, deep shadow) and rings the whole
thing in ink. Detail pixels can force a ramp step explicitly
(level="hi"/"sh") where the light needs a hand.

Usage: python3 tools/generate_mythic_icons.py
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw

G = 32  # icon is 32x32; keep drawing inside 1..30 so the outline pass fits
COLOR_BUDGET = 22  # the icon packs run 6-17 colors a sprite; the extra shadow band and glint need room
OUT_DIR = os.environ.get("MYTHIC_ICON_OUT") or os.path.join(os.path.dirname(__file__), "..", "assets", "items", "mythic")

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


def _crescent(c, box, shift, mat, level=None):
    """A true crescent: a disc with a second disc bitten out of its side."""
    x0, y0, x1, y1 = box
    m = ImageChops.subtract(_ellipse_mask(box), _ellipse_mask((x0 + shift, y0 - 1, x1 + shift, y1 + 1)))
    c.stamp(m, mat, level)


def _mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def _hsv_adjust(col, s_mul=1.0, v_mul=1.0):
    import colorsys
    h, s, v = colorsys.rgb_to_hsv(col[0] / 255.0, col[1] / 255.0, col[2] / 255.0)
    s = min(1.0, s * s_mul)
    v = min(1.0, v * v_mul)
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), 255)


OUTLINE_INK = (20, 17, 30)   # the near-black every Craftpix icon is ringed in
SPEC = (242, 253, 255)       # the white glint on polished edges


def _tones(mat):
    """The icon-pack look of one material: a punchier ramp than the flat
    palette entries, plus a mid step for the second shadow band and a
    near-black outline that keeps a trace of the material's hue."""
    ramp = MATS[mat]
    hi = _hsv_adjust(H(ramp["hi"]), 1.0, 1.08)
    base = _hsv_adjust(H(ramp["base"]), 1.12, 1.0)
    sh = _hsv_adjust(H(ramp["sh"]), 1.15, 0.86)
    mid = _mix(base, sh, 0.5)
    deep = _mix(sh, H(ramp["core"]), 0.6)
    line = _mix(H(ramp["core"]), OUTLINE_INK + (255,), 0.72)
    return {"hi": hi, "base": base, "mid": mid, "sh": sh, "deep": deep, "line": line}


def render(canvas):
    """Light the material regions the way the Craftpix icon packs are drawn:
    a near-black outline, a bright upper-left rim, two shadow bands toward
    the lower right (a deeper one against the outline), and one white glint
    on the lit corner of every big region."""
    img = Image.new("RGBA", (G, G), (0, 0, 0, 0))
    px = img.load()
    tones = {}
    seed_of, size_of = _regions(canvas)

    def tone(mat):
        if mat not in tones:
            tones[mat] = _tones(mat)
        return tones[mat]

    def same(x, y, mat):
        # A neighbouring pixel of the same material (region continues).
        return canvas.filled(x, y) and canvas.cells[y][x][0] == mat

    # Distance (1..3) to the nearest non-region pixel toward the light
    # (up/left) and away from it (down/right), per pixel.
    def dist(x, y, mat, dx, dy):
        d = 0
        while d < 3 and same(x + dx * (d + 1), y + dy * (d + 1), mat):
            d += 1
        return d + 1

    glint_at = {}  # mat region seed -> best glint pixel
    for y in range(G):
        for x in range(G):
            cell = canvas.cells[y][x]
            if cell is None:
                continue
            mat, level = cell
            t = tone(mat)
            if level:
                px[x, y] = t[level]
                continue
            d_up = dist(x, y, mat, 0, -1)
            d_left = dist(x, y, mat, -1, 0)
            d_down = dist(x, y, mat, 0, 1)
            d_right = dist(x, y, mat, 1, 0)
            d_ul = min(d_up, d_left)
            d_dr = min(d_down, d_right)
            if d_ul == 1:
                px[x, y] = t["hi"]
            elif d_dr == 1:
                px[x, y] = t["deep"] if d_ul >= 3 else t["sh"]
            elif d_dr == 2 and d_ul >= 3:
                px[x, y] = t["sh"]
            else:
                px[x, y] = t["base"]
            # Candidate glint: the lit corner just inside the highlight rim.
            if d_ul == 2 and d_dr >= 3:
                key = (mat, seed_of[(x, y)])
                if key not in glint_at or (x + y) < sum(glint_at[key]):
                    glint_at[key] = (x, y)
    for (mat, seed), (x, y) in glint_at.items():
        if size_of[seed] >= 28 and mat not in ("dark", "smoke"):
            px[x, y] = SPEC
    # Outline: every empty pixel touching the sprite takes the near-black ink
    # of a neighbouring material.
    for y in range(G):
        for x in range(G):
            if canvas.cells[y][x] is not None:
                continue
            for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                nb = canvas.cells[y + dy][x + dx] if 0 <= x + dx < G and 0 <= y + dy < G else None
                if nb is not None:
                    px[x, y] = tone(nb[0])["line"]
                    break
    return img


def _regions(canvas):
    """Connected same-material regions (4-neighbour): pixel -> region seed,
    and region seed -> size."""
    seed_of = {}
    size_of = {}
    for y in range(G):
        for x in range(G):
            if canvas.cells[y][x] is None or (x, y) in seed_of:
                continue
            mat = canvas.cells[y][x][0]
            stack = [(x, y)]
            seed_of[(x, y)] = (x, y)
            n = 0
            while stack:
                cx, cy = stack.pop()
                n += 1
                for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < G and 0 <= ny < G and (nx, ny) not in seed_of \
                            and canvas.cells[ny][nx] is not None and canvas.cells[ny][nx][0] == mat:
                        seed_of[(nx, ny)] = (x, y)
                        stack.append((nx, ny))
            size_of[(x, y)] = n
    return seed_of, size_of


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
    "belt_of_scrolls": belt_of_scrolls,
    "megingjord": megingjord,
    "orions_belt": orions_belt,
    "girdle_of_aphrodite": girdle_of_aphrodite,
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
        if len(colors) > COLOR_BUDGET:
            over_budget.append((slug, len(colors)))
        img.save(os.path.join(OUT_DIR, "%s.png" % slug))
        big = img.resize((G * 4, G * 4), Image.NEAREST)
        sheet.paste(big, ((i % 4) * G * 4, (i // 4) * G * 4), big)
        print("%-34s %2d colors" % (slug, len(colors)))
    if sheet_path:
        sheet.save(sheet_path)
    if over_budget:
        raise SystemExit("over the %d-color budget: %s" % (COLOR_BUDGET, over_budget))


if __name__ == "__main__":
    main()
