#!/usr/bin/env python3
"""Cut the designer's hero sprites into the game's four-direction sheets.

Sources (assets/sprites/paintings/, .gdignore'd source art; the designer's
second, larger set, 2026-10-25 — ~400 px a figure where the first set was
100-170, which left Brad visibly blockier than the rest):
  heroes_front_back.webp — the five heroes in columns (Jeremy, Cory, Ryan,
    Brad, Stephen), the back view on the top row and the front below, on a
    flat dark-grey ground.
  heroes_side.webp — the same five from the side, two rows. Jeremy, Ryan and
    Brad face left, Cory and Stephen right. The top row is used, but for
    Stephen the lower row: it is the one without the bow across his front.
Designer's edits (2026-10-25): Cory's chest charm (the rabbit's foot on its
gold chain) and what is left of Stephen's bow in his side view are painted
out (ERASE); Brad wears the embroidered feather on his breastplate (FEATHER);
Jeremy's red, green and blue rings are put on his left hand's fingers in
every view (RINGS).

Keeping the art's nuance comes first (designer, 2026-10-23: the first cut,
34 texels tall, was far too pixelated; 2026-10-24: err on the side of
under-pixelating): each hero is drawn at 64 texels a tile, twice the tiles'
fineness — HEIGHT texels crown to feet, BOARD_HEIGHT tiles tall — and its
stockier build (WIDEN) is baked into the art. (2026-10-25: the art's own
~150 texels had been drawn into the default zoom's 64 screen pixels a tile,
so the GPU skipped every third row and column — crunchy and uneven. At 64 a
tile every art texel is one screen pixel at zoom 2 and two at zoom 4.) One scale per hero (set by the front pose), so the
poses keep their true proportions to each other. Brad's front comes from a
separate, larger image: it is scaled to the height of the sheet's own front.

The Secret of Mana touch, light enough to keep the shading: colour pushed a
little further from grey (VIBRANCE); a sharp
(Lanczos) resample with on/off alpha, so edges are crisp pixels rather than
soft fringes; the palette tidied to PALETTE colours a hero (no dithering),
which settles the resample's in-between tones into clusters (a small accent
it would swallow, like glowing eyes, keeps its colour); and no
outline: the dark line the boards paint round each figure is peeled off
(designer, 2026-10-28: no black outline on the heroes, like the monsters);
OUTLINE puts back the old one-texel inked silhouette.

The figure is lifted off the black first: the background (pure black with a
few levels of noise) is flood-filled in from the crop's edge, so dark cloth
inside the outline stays; labels and specks are dropped (only the figure and
pieces near its size survive). Poses are packed bottom-centred into square
cells, one column, rows in CharacterAnimator order: south (front), north
(back), east, west; a missing side is the mirror of the other.

Walk cycles (WALKS): a hero with the designer's walk board
(eight frames a direction on a ruled grid)
(all five heroes, 2026-10-31) gets them as columns 1.. beside the still pose in column 0, at the still
poses' scale and on their shared palette; SpriteFigure strides through them
instead of stepping the still pose up and down.

Output: assets/sprites/generated/heroes/<hero>.png
Run: python3 tools/cut_hero_sprites.py   (Pillow, numpy; opencv-python-headless
for Stephen's bow)
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import smooth_art  # noqa: E402  (the smooth, non-pixelated sheets)

SRC = "assets/sprites/paintings/%s"
OUT = "assets/sprites/generated/heroes/%s.png"
HEIGHT = 102       # texels, crown to feet, of the hero's front pose (~1.6 tiles at 64 a tile; the
                   # height it had with the old one-texel outline round it)
SMOOTH_HEIGHT = 204   # the smooth sheet's height, crown to feet: HEIGHT at 128 a tile
WIDEN = 1.12       # drawn this much wider than tall (SpriteFigure.BOARD_WIDEN), baked in
                   # (designer, 2026-10-24: err on the side of under-pixelating the heroes)
PALETTE = 96       # colours per hero after the tidy (0 = keep every colour)
ACCENT_KEEP = 36   # ...but a pixel the tidy would move further than this keeps its colour
VIBRANCE = 1.12    # SoM's saturated palette: colour pushed this much further from grey
OUTLINE = False    # the inked one-texel silhouette: off (designer, 2026-10-28: no black
                   # outline, so the heroes sit with the monsters and NPCs, which have none)
PEEL_DARK = 48     # the art's own painted outline (peel_painted_outline): an edge pixel this
PEEL_RATIO = 0.6   # dark (0-255 mean) and under this share of its neighbourhood's mean...
PEEL_WINDOW = 9    # ...(this many px square)...
PEEL_PASSES = 4    # ...goes, this many layers deep (the line is 2-4 source px)
KEEP_SHARE = 0.05  # pieces smaller than this share of the figure are dropped
ROWS = ["south", "north", "east", "west"]

# Per hero: (source, crop box (x0, y0, x1, y1), facing). East/west name the
# way the pose faces; the other side is its mirror. The first pose (the
# front) sets the hero's scale for every pose from the same source; a pose
# from the other source is scaled to the front's height.
FB = "heroes_front_back.webp"
SIDE = "heroes_side.webp"
STEPHEN = "stephen_v2_board.png"
RYAN = "ryan_v2_board.webp"
BRAD = "brad_v2_board.webp"
# Boards whose poses are drawn at different sizes (Ryan's side views are up
# to 22% smaller than his front): every pose is scaled to HEIGHT on its own,
# so he does not shrink when he turns.
MATCH_HEIGHT = {"ryan", "brad"}
HEROES = {
    "jeremy": [
        (FB, (28, 420, 252, 834), "south"),
        (FB, (36, 0, 257, 415), "north"),
        (SIDE, (38, 5, 183, 374), "west"),
    ],
    "cory": [
        (FB, (361, 417, 595, 833), "south"),
        (FB, (364, 0, 599, 411), "north"),
        (SIDE, (334, 2, 466, 372), "east"),
    ],
    # 2026-10-28: the new Ryan (goggles, masked, crossed axes on his back,
    # knives and potions at his belt), his own board on black: front, back,
    # facing right, facing left, top to bottom.
    "ryan": [
        (RYAN, (380, 0, 640, 429), "south"),
        (RYAN, (380, 429, 640, 847), "north"),
        (RYAN, (415, 847, 580, 1180), "east"),
        (RYAN, (430, 1180, 595, 1536), "west"),
    ],
    # 2026-10-28: the new Brad (fur-trimmed scale armour over red sleeves,
    # a gorget over his mouth, the War Rack on his back, the glowing feather
    # painted on his breastplate), his own board on black: front, back,
    # facing right, facing left.
    "brad": [
        (BRAD, (370, 0, 650, 396), "south"),
        (BRAD, (370, 396, 650, 779), "north"),
        (BRAD, (410, 779, 590, 1138), "east"),
        (BRAD, (425, 1138, 622, 1530), "west"),
    ],
    # 2026-10-28: the new Stephen (fur-collared ranger, axe and bow on his
    # back, a bear's arm for his left), from his own board on black, built by
    # tools/build_stephen_board.py: the right-facing view is the designer's
    # separate image (the board's own had the bear arm on the wrong side).
    "stephen": [
        (STEPHEN, (34, 0, 242, 287), "south"),
        (STEPHEN, (248, 0, 472, 291), "north"),
        (STEPHEN, (60, 286, 205, 620), "east"),
        (STEPHEN, (305, 286, 442, 620), "west"),
    ],
}

# Walk boards: (source, grid-line x's, grid-line y's, the facing each grid
# row draws, facings left out, ground). The cells sit between consecutive
# lines. Ground None: the figures are cut on the board's own alpha;
# "opaque": the board is painted on a dark ground with a soft glow behind
# the figure, fitted and filled in from each cell's edge (cut_opaque_cell). Stephen's board (2026-10-31):
# back, front, left, right rows. Its right row is left out: from frame 3 on
# it shows the bear arm on his near side, the mistake the designer had fixed
# on his still pose (2026-10-28); the redrawn row is its own board
# (WALK_EXTRA).
WALK_CELL_INSET = 4   # px kept clear of the grid lines
WALK_ALPHA = 40       # source alpha over this is figure (for finding it; the
                      # cut keeps the soft alpha for the resample)
WALKS = {
    "stephen": ("stephen_walk_board.webp",
                [92, 226, 359, 490, 619, 749, 872, 994, 1118],
                [10, 182, 344, 503, 669],
                ["north", "south", "west", "east"],
                {"east"}, None),
    # 2026-10-31: Ryan's walk board, on a dark plum ground with a soft
    # shadow under the feet: back, front, left, right rows, all used.
    "ryan": ("ryan_walk_board.webp",
             [126, 308, 490, 669, 850, 1031, 1204, 1373, 1528],
             [10, 246, 469, 688, 909],
             ["north", "south", "west", "east"],
             set(), "opaque", {"narrow": 7, "close": 7, "tol": 4}),   # 2026-11-01 board; his black trousers are the ground's colour
    # 2026-10-31: Jeremy's walk board, the same layout and ground as Ryan's
    # (his rings already painted on), all four rows used.
    "jeremy": ("jeremy_walk_board.webp",
               [126, 309, 489, 668, 844, 1019, 1194, 1368, 1526],
               [11, 247, 471, 685, 910],
               ["north", "south", "west", "east"],
               set(), "opaque"),
    # 2026-10-31: Cory's and Brad's walk boards, the same layout and ground.
    "cory": ("cory_walk_board.webp",
             [125, 309, 490, 670, 846, 1022, 1196, 1359, 1526],
             [14, 247, 470, 686, 910],
             ["north", "south", "west", "east"],
             set(), "opaque"),
    "brad": ("brad_walk_board.webp",
             [126, 307, 489, 670, 850, 1030, 1209, 1382, 1526],
             [12, 244, 469, 687, 907],
             ["north", "south", "west", "east"],
             set(), "opaque", {"halo": True}),   # the feather's glow stripped (HALO_STRIP)
}
# A direction redrawn on a board of its own, in WALKS' form: Stephen's right
# (2026-10-31, "Walk Right (Corrected)": his human arm on the near side,
# where his main board's right row showed the bear arm).
WALK_EXTRA = {
    "stephen": [("stephen_walk_right_board.webp",
                 [10, 234, 458, 683, 907, 1122, 1341, 1562, 1770], [87, 738],
                 ["east"], set(), "opaque", {"tol": 4, "narrow": 7})],   # his dark trousers
}
# The opaque boards' ground, fitted a cell (_ground_fit): within
# WALK_GROUND_TOL of the fit (max channel) and reached from the edge is ground;
# enclosed pockets of it (between arm and body) WALK_POCKET_MIN px or more,
# as flat as the ground, go too; then WALK_HALO_PEEL passes take the
# in-between tones (within BLEND_TOL: the foot shadow's rim) off the edge.
WALK_GROUND_TOL = 10
WALK_POCKET_MIN = 40
WALK_HALO_PEEL = 2
WALK_FIT_PASSES = 4   # ground fits, each to what the last fill reached
SHADE_UNDER = 3       # a floor shadow: darker than the ground fit by this in every channel...
SHADE_FLAT = 4.0      # ...and as smooth as the ground (5x5 spread)...
SHADE_ZONE = 0.3      # ...in the cell's lowest share (where feet are)
SOLE_CLOSE = 13       # but notches it bites into the figure this wide are the figure (a sole)
MATTE_BAND = 3        # the matte (cut_opaque_cell): edge pixels within this of the outside...
MATTE_EDGE = 1        # ...but only the outermost this-many px actually fade
MATTE_WINDOW = 9      # ...read the figure just inside them over this window...
MATTE_MIN_CONTRAST = 40.0   # ...unless that is as near the ground as they are (dark cloth)
MATTE_DROP = 0.12     # coverage under this is ground
RIM_PASSES = 3        # the near-black rim round an opaque board's figure: this deep...
RIM_DARK = 34         # ...no channel brighter than this...
RIM_RATIO = 0.55      # ...and under this share of the figure's brightness round it...
RIM_WINDOW = 9        # ...(this many px square)
NARROW_CREEP = 8      # px the narrow fill creeps past its wide openings
GLOW_CHANNEL = 2      # the glow's hue (channel) for glow=True: blue (Cory's field)
GLOW_REACH = 21       # ...within this of the cut figure...
GLOW_MIN = 5          # ...adding at least this much light...
GLOW_BODY = 3         # the body's silhouette closes gaps this wide
GLOW_EDGE_DARK = 140  # (glow_edge: the band's glow is dark...
GLOW_EDGE_NEAR = 15   # ...within this of the glowing thing itself)
GLOW_LEAN = 4         # a glow pixel: one channel above the ground this much more than the next...
GLOW_FULL = 110       # ...and fully solid once it adds this much light
HAZE_DARK = 60        # haze (cut_opaque_cell): no channel brighter than this...
HAZE_FLAT = 4.0       # ...and as smooth as the ground (5x5 spread)

# The sources' ground: a flat dark grey (with a few levels of compression
# noise). Anything within GROUND_TOL of it, reached from the crop's edge, is
# background; the figures' own dark outline keeps their dark cloth inside.
GROUND = {FB: (32, 32, 30), SIDE: (32, 32, 30), STEPHEN: (0, 0, 0), RYAN: (0, 0, 0), BRAD: (0, 0, 0)}
GROUND_TOL = 6
# The ground also sits in pockets the edge flood cannot reach — between an
# arm and the body, inside Stephen's bow — and as a blended halo round the
# silhouette. A pocket is the ground's colour (within GROUND_TOL) AND as flat
# as the ground (5x5 spread <= POCKET_FLAT; cloth always carries stitching
# and shading), at least POCKET_MIN pixels; it goes, with the in-between
# tones round it (within BLEND_TOL of the ground). Then HALO_PEEL passes take
# the same in-between tones off the silhouette's edge.
POCKET_FLAT = 3.0
POCKET_MIN = 30
BLEND_TOL = 14
HALO_PEEL = 2

# Painted out of the source before cutting (designer, 2026-10-25), from what
# surrounds them (OpenCV inpaint): inside each polygon (source pixels), the
# pixels the rule picks out. "charm": light or gold (Cory's rabbit's foot and
# its chain, on his near-black robe). "bow": the bow's brown-orange limb and
# gold nock against Stephen's dark trousers and pale arm-wrap above it.
ERASE = {
    ("cory", "east"): [([(428, 92), (452, 92), (456, 178), (426, 178)], "charm")],
}

# Jeremy's three rings — red, green and blue — on the fingers of his left
# hand (designer, 2026-10-25: put them on his side view's fingers; 2026-10-28:
# and on his front and back too). His left hand is the one the side view
# shows, the viewer's right in the front view and the viewer's left in the
# back. Drawn on the source at full resolution before cutting: a gold band
# round each bony finger with its gem on top. (x, y): the gem's centre in
# source pixels.
RINGS = {
    ("jeremy", "west"): [((87, 246), (214, 38, 38)), ((93, 248), (40, 186, 72)), ((100, 249), (58, 112, 236))],
    ("jeremy", "south"): [((214, 670), (214, 38, 38)), ((221, 671), (40, 186, 72)), ((228, 670), (58, 112, 236))],
    ("jeremy", "north"): [((56, 259), (58, 112, 236)), ((63, 260), (40, 186, 72)), ((70, 259), (214, 38, 38))],
}
RING_GOLD = (222, 178, 74)
RING_GOLD_DARK = (120, 84, 30)


def draw_rings(sheet, hero, facing):
    """Paint the RINGS for this pose onto `sheet` (RGB array): drawn 4x
    oversized and shrunk, so they are as fine as the art."""
    from PIL import ImageDraw
    rings = RINGS.get((hero, facing), [])
    if not rings:
        return sheet
    ss = 4
    xs = [p[0] for p, _ in rings]
    ys = [p[1] for p, _ in rings]
    x0, y0, x1, y1 = min(xs) - 6, min(ys) - 6, max(xs) + 7, max(ys) + 7
    layer = Image.new("RGBA", ((x1 - x0) * ss, (y1 - y0) * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for (x, y), gem in rings:
        cx, cy = (x - x0 + 0.5) * ss, (y - y0 + 0.5) * ss
        # The band: across the finger, a dark rim under the gold.
        d.rounded_rectangle([cx - 3.8 * ss, cy - 1.4 * ss, cx + 3.8 * ss, cy + 1.7 * ss],
                            radius=ss, fill=RING_GOLD_DARK + (255,))
        d.rounded_rectangle([cx - 3.4 * ss, cy - 1.1 * ss, cx + 3.4 * ss, cy + 1.1 * ss],
                            radius=ss, fill=RING_GOLD + (255,))
        # The gem, with a dark setting and a glint.
        r = 2.8 * ss
        d.ellipse([cx - r - ss * 0.5, cy - r - ss * 0.5, cx + r + ss * 0.5, cy + r + ss * 0.5], fill=RING_GOLD_DARK + (255,))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=gem + (255,))
        g = 0.8 * ss
        d.ellipse([cx - r * 0.55 - g, cy - r * 0.55 - g, cx - r * 0.55 + g, cy - r * 0.55 + g], fill=(255, 255, 255, 230))
    layer = layer.convert("RGBa").resize((x1 - x0, y1 - y0), Image.LANCZOS).convert("RGBA")
    base = Image.fromarray(np.ascontiguousarray(sheet[y0:y1, x0:x1]).astype(np.uint8), "RGB").convert("RGBA")
    base.alpha_composite(layer)
    out = sheet.copy()
    out[y0:y1, x0:x1] = np.asarray(base.convert("RGB"))
    return out


# Brad's chest piece: an embroidered feather, golden white, almost heavenly,
# lying across the middle of the breastplate with its tip raised 20 degrees,
# up and to the right, the quill running out down to the left (designer,
# 2026-10-24). No pack shows it, so it is drawn here at the source's own
# resolution on the front pose, before any resampling, so the pixel and the
# smooth sheets both carry it. (cx, cy): its centre as a fraction of the
# cut-out's width and height; length: as a fraction of the figure's height.
# 2026-10-28: Brad's new board paints the feather itself (glowing), so
# nothing is drawn on him any more; the drawing is kept for a hero that needs it.
FEATHER = {}
FEATHER_GOLD = (196, 170, 112)      # the gold thread outline
FEATHER_VANE = (252, 249, 236)      # pale gold-white vane
FEATHER_SHADE = (232, 214, 168)     # the deeper gold of the lower vane and barbs
FEATHER_QUILL = (226, 198, 130)
FEATHER_GLOW = (255, 252, 238)


def draw_feather(img, cx, cy, length, angle):
    """Brad's feather on the cut-out `img` (RGBA, in place): drawn 4x
    oversized and shrunk down, so its edges are as fine as the art's."""
    from PIL import ImageDraw, ImageFilter
    import math
    ss = 4
    L = length * img.height * ss
    W = L * 0.34
    size = int(L * 1.5)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = size / 2.0
    # The vane: a leaf whose upper edge bows out further than its lower one,
    # pointed at the tip (+x) and rounded at the base; the quill runs on out.
    upper, lower = [], []
    for i in range(41):
        t = i / 40.0
        x = c - L * 0.42 + t * L * 0.86
        bulge = math.sin(math.pi * min(1.0, t * 1.05)) ** 0.8
        upper.append((x, c - W * 0.55 * bulge))
        lower.append((x, c + W * 0.42 * bulge))
    vane = upper + lower[::-1]
    d.polygon(vane, fill=FEATHER_VANE + (255,), outline=FEATHER_GOLD + (255,), width=ss * 2)
    # The lower half a shade deeper, and the barbs as fine slanted threads.
    d.polygon([(c - L * 0.42, c)] + lower + [(c + L * 0.44, c)], fill=FEATHER_SHADE + (255,))
    for i in range(1, 9):
        x = c - L * 0.36 + i * L * 0.085
        d.line([(x, c), (x + L * 0.06, c - W * 0.40)], fill=FEATHER_SHADE + (255,), width=ss)
        d.line([(x, c), (x + L * 0.05, c + W * 0.32)], fill=FEATHER_GOLD + (200,), width=ss)
    d.line(vane[:41], fill=FEATHER_GOLD + (255,), width=ss * 2)
    d.line(lower, fill=FEATHER_GOLD + (255,), width=ss * 2)
    # The quill: from past the base, through the vane, to the tip.
    d.line([(c - L * 0.58, c + W * 0.06), (c + L * 0.44, c)], fill=FEATHER_QUILL + (255,), width=ss * 3)
    layer = layer.rotate(angle, resample=Image.BICUBIC, center=(c, c))
    # A faint heavenly glow where the thread meets the plate.
    glow = layer.getchannel("A").filter(ImageFilter.GaussianBlur(ss * 2.5))
    halo = Image.new("RGBA", layer.size, FEATHER_GLOW + (0,))
    halo.putalpha(glow.point(lambda v: int(v * 0.35)))
    small = (max(1, size // ss), max(1, size // ss))
    halo = halo.resize(small, Image.LANCZOS)
    layer = layer.convert("RGBa").resize(small, Image.LANCZOS).convert("RGBA")
    pos = (int(round(cx * img.width - small[0] / 2)), int(round(cy * img.height - small[1] / 2)))
    # Only on the figure: the feather never hangs out over the background.
    for part in (halo, layer):
        under = img.crop((pos[0], pos[1], pos[0] + small[0], pos[1] + small[1])).getchannel("A")
        a = np.minimum(np.asarray(part.getchannel("A")), np.asarray(under))
        part.putalpha(Image.fromarray(a.astype(np.uint8)))
        img.alpha_composite(part, pos)


_N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
_N8 = _N4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))


def _flood(mask, seeds):
    h, w = mask.shape
    out = np.zeros_like(mask)
    q = deque()
    for y, x in seeds:
        if mask[y, x] and not out[y, x]:
            out[y, x] = True
            q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in _N4:
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    return out


def _components(mask):
    h, w = mask.shape
    seen = np.zeros_like(mask)
    comps = []
    for y, x in zip(*np.nonzero(mask)):
        if seen[y, x]:
            continue
        seen[y, x] = True
        comp, q = [], deque([(y, x)])
        while q:
            cy, cx = q.popleft()
            comp.append((cy, cx))
            for dy, dx in _N4:
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        comps.append(comp)
    return comps


def erase_marks(sheet, hero, facing):
    """Paint the ERASE marks for this pose out of `sheet` (RGB array) from
    what surrounds them."""
    import cv2  # tool dependency (opencv-python-headless)
    from PIL import ImageDraw
    r, g, b = [sheet[..., i].astype(int) for i in range(3)]
    lum = (r + g + b) / 3.0
    marks = np.zeros(sheet.shape[:2], bool)
    for poly, rule in ERASE.get((hero, facing), []):
        mask = Image.new("L", (sheet.shape[1], sheet.shape[0]), 0)
        ImageDraw.Draw(mask).polygon(poly, fill=255)
        region = np.asarray(mask) > 0
        if rule == "charm":
            pick = (lum > 85) | ((r - b > 35) & (r > 80))
        else:  # "bow"
            pick = (r - b > 28) & (r > 60) & (lum < 170)
        marks |= region & pick
    if not marks.any():
        return sheet
    marks = cv2.dilate(marks.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    bgr = np.ascontiguousarray(sheet[..., ::-1].astype(np.uint8))
    return cv2.inpaint(bgr, marks.astype(np.uint8) * 255, 4, cv2.INPAINT_TELEA)[..., ::-1]


def strip_halo(rgba, core_px, keep_px, dark):
    """Drop what hangs off the figure's body (its thick core, what survives
    an opening core_px wide, grown back keep_px) and is dark or a coloured
    glow (max channel under `dark`, or orange: r > g > b with r - b > 60):
    Brad's feather glow, which the boards paint out past his chest."""
    import cv2  # tool dependency (opencv-python-headless)
    sol = (rgba[..., 3] > 0).astype(np.uint8)
    core = cv2.morphologyEx(sol, cv2.MORPH_OPEN, np.ones((core_px, core_px), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(core, connectivity=8)
    if n > 1:
        core = (lab == 1 + int(np.argmax(st[1:, 4]))).astype(np.uint8)
    core = cv2.dilate(core, np.ones((keep_px, keep_px), np.uint8)) > 0
    r, g, b = [rgba[..., i].astype(int) for i in range(3)]
    glow = (r > g) & (g > b) & (r - b > 60)
    drop = (sol > 0) & ~core & ((rgba[..., :3].max(axis=2) < dark) | glow)
    out = rgba.copy()
    out[drop] = 0
    return out


# Boards whose figure casts a painted glow out past its silhouette (Brad's
# feather): strip_halo's (core, keep, dark), on the still poses too
# (designer, 2026-11-01: "remove the black in front of Brad's chest
# completely, even when he is standing still").
HALO_STRIP = {"brad": (11, 7, 120)}


def cut(path, box, hero=None, facing=None):
    """The figure in `box`, full size, on transparency, cropped to itself."""
    sheet = np.asarray(Image.open(SRC % path).convert("RGB"))
    if (hero, facing) in ERASE:
        sheet = erase_marks(sheet, hero, facing)
    if (hero, facing) in RINGS:
        sheet = draw_rings(sheet, hero, facing)
    rgb = sheet[box[1]:box[3], box[0]:box[2]].astype(int)
    h, w, _ = rgb.shape
    ground = np.array(GROUND.get(path, (0, 0, 0)))
    dark = np.abs(rgb - ground).max(axis=2) <= GROUND_TOL
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    solid = ~_flood(dark, edge)
    solid = _clear_ground(rgb, solid, ground)
    comps = _components(solid)
    biggest = max(len(c) for c in comps)
    keep = np.zeros_like(solid)
    for comp in comps:
        if len(comp) >= biggest * KEEP_SHARE:
            keep[tuple(np.array(comp).T)] = True
    ys, xs = np.nonzero(keep)
    rgba = np.dstack([rgb.astype(np.uint8), np.where(keep, 255, 0).astype(np.uint8)])
    if hero in HALO_STRIP:
        rgba = strip_halo(rgba, *HALO_STRIP[hero])
        ys, xs = np.nonzero(rgba[..., 3])
    return Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


def _clear_ground(rgb, solid, ground):
    """Take the ground's enclosed pockets and its halo out of `solid`."""
    import cv2  # tool dependency (opencv-python-headless)
    f = rgb.astype(np.float32)
    off = np.abs(f - np.array(ground, np.float32)).max(axis=2)
    mean = cv2.blur(f, (5, 5))
    spread = np.sqrt(np.maximum(cv2.blur(f * f, (5, 5)) - mean * mean, 0)).max(axis=2)
    flat = solid & (off <= GROUND_TOL) & (spread <= POCKET_FLAT)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(flat.astype(np.uint8), connectivity=4)
    pocket = np.zeros_like(solid)
    for i in range(1, n):
        if stats[i][4] < POCKET_MIN:
            continue
        piece = lab == i
        r, g, b = f[piece].mean(axis=0)
        # The ground leans green-yellow (green >= blue); the near-black cloth
        # it can be mistaken for (Ryan's shirt) leans purple. Only the
        # ground's own tint is a pocket.
        if g - b >= -1.0 and abs(r - ground[0]) <= 5 and abs(g - ground[1]) <= 4:
            pocket |= piece
    blend = solid & (off <= BLEND_TOL)
    k = np.ones((3, 3), np.uint8)
    for _ in range(3):
        pocket |= (cv2.dilate(pocket.astype(np.uint8), k) > 0) & blend
    solid = solid & ~pocket
    for _ in range(HALO_PEEL):
        open_ = cv2.dilate((~solid).astype(np.uint8), k) > 0
        solid = solid & ~(open_ & blend)
    # Last, any edge pixel still the ground's own colour, until none is left.
    for _ in range(6):
        open_ = cv2.dilate((~solid).astype(np.uint8), k) > 0
        stray = open_ & solid & (off <= GROUND_TOL)
        if not stray.any():
            break
        solid = solid & ~stray
    return solid


def cut_walk(hero):
    """The hero's walk frames: {facing: [full-size RGBA cut-outs]}, plus the
    source height the south frames reach (their scale's reference)."""
    out = cut_walk_board(*WALKS[hero])
    return out, max(f.height for f in out["south"])


def cut_walk_board(path, xs, ys, facings, skip, ground, opts=None):
    """One walk board's frames: {facing: [full-size RGBA cut-outs]}. `opts`:
    "narrow" for cut_opaque_cell, and "close": px, notches in the silhouette
    that narrow filled (near-black clothes on the near-black ground)."""
    opts = opts or {}
    import cv2  # tool dependency (opencv-python-headless)
    board = np.asarray(Image.open(SRC % path).convert("RGBA"))
    out = {}
    for r, facing in enumerate(facings):
        if facing in skip:
            continue
        frames = []
        for c in range(len(xs) - 1):
            i = WALK_CELL_INSET
            cell = board[ys[r] + i:ys[r + 1] - i + 1, xs[c] + i:xs[c + 1] - i + 1]
            if ground == "opaque":
                cell = cut_opaque_cell(cell, True, False, opts.get("narrow", 0), opts.get("tol"), None,
                                       opts.get("glow", False), opts.get("glow_edge", 0))
                if opts.get("close"):
                    k = np.ones((opts["close"], opts["close"]), np.uint8)
                    a = cv2.morphologyEx((cell[..., 3] > 0).astype(np.uint8), cv2.MORPH_CLOSE, k)
                    cell[..., 3] = np.maximum(cell[..., 3], a * 255)
                if opts.get("halo"):
                    cell = strip_halo(cell, *HALO_STRIP["brad"])
            solid = (cell[..., 3] > WALK_ALPHA).astype(np.uint8)
            n, lab, stats, _ = cv2.connectedComponentsWithStats(solid, connectivity=8)
            biggest = stats[1:, 4].max()
            keep = np.zeros(solid.shape, bool)
            for k in range(1, n):
                if stats[k][4] >= biggest * KEEP_SHARE:
                    keep |= lab == k
            # The soft edge round what is kept, nothing else in the cell.
            near = cv2.dilate(keep.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
            f = cell.copy()
            f[~near] = 0
            yy, xx = np.nonzero(keep)
            frames.append(Image.fromarray(f[yy.min():yy.max() + 1, xx.min():xx.max() + 1], "RGBA"))
        out[facing] = frames
    return out


def _ground_fit(rgb, mask):
    """The ground as a smooth field: a cubic in (x, y) a channel, fitted to
    the pixels in `mask` (the boards' ground is a soft glow, brightest
    behind the figure, that no single colour matches)."""
    h, w, _ = rgb.shape
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / float(w) - 0.5, yy / float(h) - 0.5
    terms = [np.ones_like(u), u, v, u * u, u * v, v * v, u ** 3, u * u * v, u * v * v, v ** 3]
    A = np.stack([t[mask] for t in terms], axis=1)
    step = max(1, len(A) // 6000)
    coef, *_ = np.linalg.lstsq(A[::step], rgb[mask][::step].astype(float), rcond=None)
    return np.tensordot(np.stack(terms, axis=-1), coef, axes=1)


def cut_opaque_cell(cell, pockets=True, haze=False, narrow=0, tol=None, haze_dark=None, glow=False, glow_edge=0):
    """One cell of an opaque walk board, its ground made transparent (hard
    alpha). The ground is fitted as a smooth glow (_ground_fit) and filled in
    from the cell's edge wherever a pixel is within TOL of it,
    refitting to what the fill reached a few times; the figure's own dark
    outline stops the fill, so cloth as dark as the ground (Cory's robe)
    stays. Then its enclosed pockets (unless `pockets` is off: a shadow as
    dark as the ground inside the figure, like the back of Stephen's neck)
    and the halo round the figure go. `haze`: a soft glow round an effect
    (the flash of Stephen's crossed knives), dark and as smooth as the
    ground but off its colour, is ground too. `narrow`: the fill only gets
    through openings at least this many px wide (then creeps NARROW_CREEP px
    on), so a shadow as dark as the ground reached through a slit (the back
    of Stephen's neck, between hair and hood) stays."""
    import cv2  # tool dependency (opencv-python-headless)
    TOL = WALK_GROUND_TOL if tol is None else tol   # (a board may need a closer match)
    HDARK = HAZE_DARK if haze_dark is None else haze_dark
    rgb = cell[..., :3].astype(int)
    h, w, _ = rgb.shape
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    ground = np.zeros((h, w), bool)
    ground[:6] = ground[-6:] = True
    ground[:, :6] = ground[:, -6:] = True
    f = rgb.astype(np.float32)
    mean = cv2.blur(f, (5, 5))
    spread = np.sqrt(np.maximum(cv2.blur(f * f, (5, 5)) - mean * mean, 0)).max(axis=2)
    soft = (rgb.max(axis=2) < HDARK) & (spread <= HAZE_FLAT) if haze else np.zeros((h, w), bool)
    for _ in range(WALK_FIT_PASSES):
        model = _ground_fit(rgb, ground & ~soft)
        off = np.abs(rgb - model).max(axis=2)
        near = off <= TOL
        # A floor shadow (under the feet): smooth, and darker than the
        # ground in every channel.
        shade = (rgb < model - SHADE_UNDER).all(axis=2) & (spread <= SHADE_FLAT)
        shade[:int(h * (1.0 - SHADE_ZONE))] = False   # (only under the feet: black cloth mid-body is cloth)
        open_ = near | soft | shade
        if narrow:
            k = np.ones((narrow, narrow), np.uint8)
            core = _flood(cv2.morphologyEx(open_.astype(np.uint8), cv2.MORPH_OPEN, k) > 0, edge)
            for _ in range(NARROW_CREEP):
                core |= (cv2.dilate(core.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & open_
            ground = core
        else:
            ground = _flood(open_, edge)
    solid = ~ground
    flat = (solid & near & (spread <= POCKET_FLAT) & pockets).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(flat, connectivity=4)
    k = np.ones((3, 3), np.uint8)
    for j in range(1, n):
        if stats[j][4] >= WALK_POCKET_MIN:
            piece = (cv2.dilate((lab == j).astype(np.uint8), k) > 0) & near
            solid &= ~piece
    blend = off <= BLEND_TOL
    for _ in range(WALK_HALO_PEEL):
        open_ = cv2.dilate((~solid).astype(np.uint8), k) > 0
        solid &= ~(open_ & blend)
    # The rim: the boards paint a soft near-black shadow and outline round
    # the figure that the fill stops short of (designer, 2026-10-31: "a lot
    # of black spacing around" Stephen's parry). An edge pixel near-black
    # and far darker than the figure just inside it goes, RIM_PASSES deep;
    # dark cloth next to dark cloth stays.
    bright = rgb.max(axis=2).astype(np.float32)
    # The rim is on the OUTER outline: a hole inside the figure (black
    # pouch pockets the fill reached) keeps its edge.
    outer = np.zeros((h, w), np.uint8)
    ffm = np.zeros((h + 2, w + 2), np.uint8)
    tmp = (~solid).astype(np.uint8).copy()
    cv2.floodFill(tmp, ffm, (0, 0), 2)
    outer_ground = tmp == 2
    for _ in range(RIM_PASSES):
        edge = solid & (cv2.dilate(outer_ground.astype(np.uint8), k) > 0)
        win = (RIM_WINDOW, RIM_WINDOW)
        n = cv2.boxFilter(solid.astype(np.float32), -1, win, normalize=False, borderType=cv2.BORDER_CONSTANT)
        v = cv2.boxFilter(np.where(solid, bright, 0).astype(np.float32), -1, win, normalize=False, borderType=cv2.BORDER_CONSTANT)
        around = v / np.maximum(n, 1.0)
        rim = edge & (bright <= RIM_DARK) & (bright < around * RIM_RATIO)
        if not rim.any():
            break
        solid &= ~rim
        outer_ground |= rim
    # A notch the floor-shadow rule bit into the figure (a shoe's dark sole
    # seen from behind, open at the bottom) is the figure's own.
    closed = cv2.morphologyEx(solid.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((SOLE_CLOSE, SOLE_CLOSE), np.uint8)) > 0
    solid |= closed & shade
    # A hole the figure closes round that is not the ground's colour (a
    # shoe's dark sole, taken for a floor shadow) is the figure's own.
    n, lab, stats, _ = cv2.connectedComponentsWithStats((~solid).astype(np.uint8), connectivity=4)
    for j in range(1, n):
        x, y, bw, bh, _area = stats[j]
        if x == 0 or y == 0 or x + bw >= w or y + bh >= h:
            continue
        hole = lab == j
        if np.median(off[hole]) > TOL:
            solid |= hole
    alpha = np.where(solid, 255.0, 0.0)
    out_rgb = rgb.astype(np.float32)
    # The matte: the boards paint the figure's edge soft, blended into the
    # dark ground, so an edge pixel kept as it is wears a dark fringe in the
    # game (designer, 2026-11-01: "a lot of leftover black"). Within
    # MATTE_BAND of the outside, how far a pixel sits from the ground,
    # against how far the figure just inside it sits, is its coverage: its
    # alpha, and its colour un-blended from the ground by it.
    # Specks the figure closes round (what the pocket rule left: a few
    # ground-coloured pixels in a black pouch) are the figure's, or the
    # matte below would fade the cloth round each into a nick.
    ff = np.zeros((h + 2, w + 2), np.uint8)
    outside = (~solid).astype(np.uint8).copy()
    cv2.floodFill(outside, ff, (0, 0), 2)
    enclosed = (outside == 1)
    solid = solid | enclosed
    k3 = np.ones((3, 3), np.uint8)
    inner = cv2.erode(solid.astype(np.uint8), np.ones((2 * MATTE_BAND + 1, 2 * MATTE_BAND + 1), np.uint8)) > 0
    # The band is the outline only: pixels within MATTE_BAND of the
    # OUTSIDE (the ground the fill reached), not of every hole.
    out_reach = cv2.dilate((~solid).astype(np.uint8), np.ones((2 * MATTE_BAND + 1, 2 * MATTE_BAND + 1), np.uint8)) > 0
    band = solid & ~inner & out_reach
    if band.any():
        fm = rgb.astype(np.float32)
        win = (MATTE_WINDOW, MATTE_WINDOW)
        n_in = cv2.boxFilter(inner.astype(np.float32), -1, win, normalize=False, borderType=cv2.BORDER_CONSTANT)
        c_in = cv2.boxFilter(np.where(inner[..., None], fm, 0).astype(np.float32), -1, win, normalize=False, borderType=cv2.BORDER_CONSTANT)
        ref = c_in / np.maximum(n_in, 1.0)[..., None]
        d_px = np.linalg.norm(fm - model, axis=2)
        d_in = np.linalg.norm(ref - model, axis=2)
        cov = np.clip(d_px / np.maximum(d_in, 1.0), 0.0, 1.0)
        # Dark cloth is as near the ground as its own edge: no matte there.
        cov = np.where(d_in < MATTE_MIN_CONTRAST, 1.0, cov)
        # Only the outermost MATTE_EDGE px fade; deeper band pixels that
        # are merely darker cloth stay solid.
        edge_px = cv2.dilate((~solid).astype(np.uint8), np.ones((2 * MATTE_EDGE + 1, 2 * MATTE_EDGE + 1), np.uint8)) > 0
        cov = np.where(edge_px, cov, 1.0)
        cov = np.where((n_in > 0) & band, cov, 1.0)
        a_safe = np.maximum(cov, 0.05)[..., None]
        unblend = np.clip(model + (fm - model) / a_safe, 0, 255)
        out_rgb = np.where((band & (cov < 1.0))[..., None], unblend, out_rgb)
        alpha = np.where(band, np.round(cov * 255.0), alpha)
        alpha = np.where(band & (cov < MATTE_DROP), 0.0, alpha)
    if glow:
        # A coloured glow (Cory's field): light added over the ground, not
        # a solid thing. Where a pixel's colour above the ground leans hard
        # to one hue (GLOW_LEAN over the other two), it becomes see-through
        # by how much light it adds, its colour unblended from the ground,
        # so the halo fades into whatever it is drawn over.
        d = rgb.astype(np.float32) - model
        top = d.max(axis=2)
        rest = np.sort(d, axis=2)[..., 1]
        # (faint glow leans by ratio: blue at least twice what it adds to
        # the other channels)
        lean = top - np.maximum(rest, 0)
        hue = {"red": 0, "green": 1, "blue": 2}.get(glow, GLOW_CHANNEL)   # glow: True or a hue name
        lit = (lean > np.maximum(GLOW_LEAN, 0.5 * top)) & (d.argmax(axis=2) == hue)
        a = np.clip(top / GLOW_FULL, 0.0, 1.0)
        a_safe = np.maximum(a, 1e-3)[..., None]
        unblend = np.clip(model + d / a_safe, 0, 255)
        # Only light, not cloth: smooth (cloth has texture), near the
        # figure, and adding a real amount of light.
        # The body: what is cut and not the glow's hue, closed and filled.
        # The glow over the body stays as painted; the glow out past it
        # becomes see-through.
        body = (solid & ~lit & (off > TOL)).astype(np.uint8)
        body = cv2.morphologyEx(body, cv2.MORPH_CLOSE, np.ones((GLOW_BODY, GLOW_BODY), np.uint8))
        nb, blab, bst, _ = cv2.connectedComponentsWithStats(body, connectivity=8)
        if nb > 1:
            body = (blab == 1 + int(np.argmax(bst[1:, 4]))).astype(np.uint8)
        holes = body.copy()
        ff = np.zeros((h + 2, w + 2), np.uint8)
        cv2.floodFill(holes, ff, (0, 0), 1)
        body = (body | (1 - holes)) > 0
        reach = cv2.dilate(solid.astype(np.uint8), np.ones((GLOW_REACH, GLOW_REACH), np.uint8)) > 0
        lit &= reach & (top > GLOW_MIN) & ~body
        if glow_edge:
            # A thin glow on the outline only (Brad's feather): smooth, and
            # within glow_edge of the outside; hair and cloth have texture.
            outside = (~solid).astype(np.uint8)
            band = cv2.dilate(outside, np.ones((2 * glow_edge + 1, 2 * glow_edge + 1), np.uint8)) > 0
            # ...and only round the glowing thing itself (the feather's
            # bright orange), never his hair or boots.
            src = ((rgb[..., 0] > 200) & (rgb[..., 1] - rgb[..., 2] > 30) & (rgb[..., 0] - rgb[..., 2] > 90)).astype(np.uint8)
            # (the glowing thing: the biggest such patch, not a speck of
            # orange on his face)
            ns, slab, sst, _ = cv2.connectedComponentsWithStats(src, connectivity=8)
            src = (slab == 1 + int(np.argmax(sst[1:, 4]))).astype(np.uint8) if ns > 1 else src
            near_src = cv2.dilate(src, np.ones((GLOW_EDGE_NEAR, GLOW_EDGE_NEAR), np.uint8)) > 0
            lit &= band & near_src & (rgb.max(axis=2) < GLOW_EDGE_DARK)
        glow_px = lit & (a < 1.0)
        # The ground seen through the field (inside its ring, past the body)
        # is ground.
        through = solid & ~body & ~lit & (off <= TOL) & reach & (not glow_edge)
        out_rgb = np.where(glow_px[..., None], unblend, out_rgb)
        alpha = np.where(glow_px, np.maximum(a * 255.0, np.where(solid & ~glow_px, 255.0, 0.0)), alpha)
        alpha = np.where(lit & (a >= 1.0), 255.0, alpha)
        alpha = np.where(through, 0.0, alpha)
    return np.dstack([out_rgb.astype(np.uint8), alpha.astype(np.uint8)])


def resample(img, factor):
    """Down by `factor` (and WIDEN times less across) with a sharp (Lanczos)
    filter on premultiplied colour, then on/off alpha: crisp pixel edges, the
    art's detail kept."""
    size = (max(1, round(img.width * WIDEN / factor)), max(1, round(img.height / factor)))
    small = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    a = np.asarray(small).copy()
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    return a


def vibrance(f):
    """Push colour VIBRANCE times further from its own grey (SoM's saturated
    palette); greys and blacks stay as they are."""
    if VIBRANCE == 1.0:
        return f
    rgb = f[..., :3].astype(float)
    grey = rgb.mean(axis=2, keepdims=True)
    out = f.copy()
    out[..., :3] = np.clip(grey + (rgb - grey) * VIBRANCE, 0, 255).astype(np.uint8)
    return out


def tidy_palette(frames):
    """Settle every pose of a hero onto one shared palette of PALETTE colours
    (median cut, no dithering)."""
    if PALETTE <= 0:
        return frames
    opaque = np.concatenate([f[f[..., 3] > 0][:, :3] for f in frames.values()])
    strip = Image.fromarray(opaque.reshape(1, -1, 3).astype(np.uint8), "RGB")
    pal_img = strip.quantize(colors=PALETTE, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = {}
    for d, f in frames.items():
        rgb = np.asarray(Image.fromarray(f[..., :3], "RGB").quantize(
            palette=pal_img, dither=Image.Dither.NONE).convert("RGB"))
        # A small accent the shared palette has no room for (glowing eyes, a
        # potion's red) would be swallowed by its surroundings: any pixel the
        # tidy would move far keeps its own colour.
        moved = np.abs(rgb.astype(int) - f[..., :3].astype(int)).max(axis=2)
        rgb = np.where((moved > ACCENT_KEEP)[..., None], f[..., :3], rgb)
        g = f.copy()
        g[..., :3] = np.where(f[..., 3:4] > 0, rgb, 0)
        out[d] = g
    return out


def peel_painted_outline(img):
    """Take off the dark line the art itself draws round the figure (the
    source boards ink their silhouettes, 2-4 px wide), on the full-size
    cut-out so the pixel and smooth sheets both lose it: an edge pixel
    PEEL_DARK or darker AND under PEEL_RATIO of its neighbourhood's mean
    (PEEL_WINDOW px square, figure pixels only) goes transparent, PEEL_PASSES
    times. Dark cloth at the edge (Cory's robe, Ryan's shirt) is about as dark
    as its neighbourhood, so it stays."""
    import cv2  # tool dependency (opencv-python-headless)
    out = np.asarray(img).copy()
    k = np.ones((3, 3), np.uint8)
    for _ in range(PEEL_PASSES):
        solid = out[..., 3] > 0
        lum = out[..., :3].astype(np.float32).mean(axis=2)
        edge = solid & (cv2.dilate((~solid).astype(np.uint8), k) > 0)
        win = (PEEL_WINDOW, PEEL_WINDOW)
        w = cv2.boxFilter(solid.astype(np.float32), -1, win, normalize=False, borderType=cv2.BORDER_CONSTANT)
        v = cv2.boxFilter(np.where(solid, lum, 0).astype(np.float32), -1, win, normalize=False, borderType=cv2.BORDER_CONSTANT)
        around = v / np.maximum(w, 1.0)
        peel = edge & (lum <= PEEL_DARK) & (lum < around * PEEL_RATIO)
        if not peel.any():
            break
        out[peel] = 0
    ys, xs = np.nonzero(out[..., 3])
    return Image.fromarray(out[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


def ink_outline(f):
    """One texel of dark, hue-tinted ink around the silhouette (8-neighbour),
    in the shade of the colour it borders — SoM's outlined figures. Grows the
    frame by a texel each side."""
    f = np.pad(f, ((1, 1), (1, 1), (0, 0)))
    solid = f[..., 3] > 0
    h, w = solid.shape
    out = f.copy()
    for y, x in zip(*np.nonzero(~solid)):
        cols = []
        for dy, dx in _N8:
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and solid[ny, nx]:
                cols.append(f[ny, nx, :3].astype(float))
        if cols:
            c = np.mean(cols, axis=0)
            ink = np.clip(c * 0.28 + np.array([6, 4, 10]), 0, 255)  # darker, leaning cool
            out[y, x, :3] = ink.astype(np.uint8)
            out[y, x, 3] = 255
    return out


def soft_frame(img, factor):
    """The smooth version of a pose (smooth_art): the cut-out at
    SMOOTH_HEIGHT / HEIGHT times the pixel sheet's size, WIDEN as wide,
    soft-filtered with soft alpha — no palette tidy, no ink outline."""
    k = SMOOTH_HEIGHT / float(HEIGHT)
    size = (max(1, round(img.width * WIDEN * k / factor)), max(1, round(img.height * k / factor)))
    out = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    return smooth_art.bleed(out)


def _mass(f):
    """A cut frame's (height, filled texels)."""
    a = f[..., 3] > 0
    ys = np.nonzero(a.any(axis=1))[0]
    return (ys[-1] - ys[0] + 1, int(a.sum()))


def build(hero, poses):
    scale = None
    full = {}
    soft = {}
    for path, box, facing in poses:
        img = cut(path, box, hero, facing)
        if not OUTLINE:
            img = peel_painted_outline(img)
        if facing == "south" and hero in FEATHER:
            draw_feather(img, **FEATHER[hero])
        if scale is None or facing == "scale":
            # The first pose (or the "scale" reference) sets the hero's scale
            # for every pose cut from the same source.
            ref_h = img.height if HEIGHT is None else HEIGHT
            scale = (path, img.height / float(ref_h))
            if facing == "scale":
                continue
        factor = scale[1] if path == scale[0] and hero not in MATCH_HEIGHT else img.height / float(ref_h)
        full[facing] = resample(img, factor)
        soft[facing] = soft_frame(img, factor)
    raw = {}   # direction -> (frames, base factor, opaque)
    if hero in WALKS:
        walks, ref = cut_walk(hero)
        for d, fr in walks.items():
            raw[d] = (fr, ref / float(HEIGHT), WALKS[hero][5] == "opaque")
    # A direction redrawn on a board of its own (WALK_EXTRA), at its own
    # size: its tallest frame stands as tall as the main board's.
    for board in WALK_EXTRA.get(hero, []):
        for d, fr in cut_walk_board(*board).items():
            raw[d] = (fr, max(f.height for f in fr) / float(HEIGHT), board[5] == "opaque")
    for d, (fr, wf, opaque) in raw.items():
        # The opaque boards' figures are dark-clad on a dark ground: peeling
        # their outline would eat gloves and cloth.
        fr = [img if OUTLINE or opaque else peel_painted_outline(img) for img in fr]
        # Each way he walks, his stride is the size of his still pose that
        # way (designer, 2026-10-31: Stephen grew as he walked): the median
        # frame's height and bulk matched to it, as the actions are.
        if d in full:
            got = [_mass(resample(img, wf)) for img in fr]
            want = _mass(full[d])
            # Height only (designer, 2026-11-01: balancing in the bulk left
            # the side views "wider and shorter"): the tallest stride stands
            # as tall as the still pose.
            wf = wf / (want[0] / float(max(g[0] for g in got)))
        for i, img in enumerate(fr):
            full[(d, i)] = resample(img, wf)
            soft[(d, i)] = soft_frame(img, wf)
    full = {d: vibrance(f) for d, f in full.items()}
    full = tidy_palette(full)
    frames = {}
    for d, f in full.items():
        frame = ink_outline(f) if OUTLINE else f
        frames[d] = Image.fromarray(frame, "RGBA")
    if "east" not in frames:
        frames["east"] = frames["west"].transpose(Image.FLIP_LEFT_RIGHT)
    if "west" not in frames:
        frames["west"] = frames["east"].transpose(Image.FLIP_LEFT_RIGHT)
    cols = 1 + max([k[1] + 1 for k in frames if isinstance(k, tuple)] or [0])
    cell = max(max(f.size) for f in frames.values()) + 2
    cell += cell % 2
    sheet = Image.new("RGBA", (cell * cols, cell * len(ROWS)))
    for r, d in enumerate(ROWS):
        for c in range(cols):
            f = frames.get(d if c == 0 else (d, c - 1))
            if f is not None:
                sheet.paste(f, (c * cell + (cell - f.width) // 2, r * cell + cell - f.height), f)
    os.makedirs(os.path.dirname(OUT % hero), exist_ok=True)
    sheet.save(OUT % hero)
    # The smooth version, kept beside the pixel sheet.
    for d in list(soft):
        f = soft[d]
        soft[d] = smooth_art.trim(f)
    if "east" not in soft:
        soft["east"] = soft["west"].transpose(Image.FLIP_LEFT_RIGHT)
    if "west" not in soft:
        soft["west"] = soft["east"].transpose(Image.FLIP_LEFT_RIGHT)
    scell = max(max(f.size) for f in soft.values()) + 2
    scell += scell % 2
    sout = os.path.join(smooth_art.ROOT, "heroes", "%s.png" % hero)
    os.makedirs(os.path.dirname(sout), exist_ok=True)
    blank = Image.new("RGBA", (1, 1))
    grid = [[soft[d]] + [soft.get((d, c - 1), blank) for c in range(1, cols)] for d in ROWS]
    smooth_art.pack(grid, scell, cols, lambda row, ci: row[ci], air=0).save(sout)
    print("%-7s cell %d, %d col(s): %s" % (hero, cell, cols, ", ".join("%s %dx%d" % (d, frames[d].width, frames[d].height) for d in ROWS)))


def main():
    for hero, poses in HEROES.items():
        build(hero, poses)


if __name__ == "__main__":
    main()
