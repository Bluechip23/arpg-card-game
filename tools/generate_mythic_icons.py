#!/usr/bin/env python3
"""Mythic appearance icons: one 32x32 sprite per mythic item, drawn from that
item's `appearance` description in scripts/progression/item_data.gd — for the
mythics the designer has not painted. Every other mythic is the designer's
painting, cut from its sheet by tools/cut_mythic_art.py; since 2026-10-23
the only one left here is the Bladed Doughnut.

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


ICONS = {
    "bladed_doughnut": bladed_doughnut,
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
