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
(Stephen, Jeremy, Ryan; 2026-10-31) gets them as columns 1.. beside the still pose in column 0, at the still
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
# "opaque": the board is painted on a flat dark ground, filled in from each
# cell's edge (cut_opaque_cell). Stephen's board (2026-10-31):
# back, front, left, right rows. Its right row is left out: from frame 3 on
# it shows the bear arm on his near side, the mistake the designer had fixed
# on his still pose (2026-10-28), so facing east he steps his still pose
# until that row is redrawn.
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
             set(), "opaque"),
    # 2026-10-31: Jeremy's walk board, the same layout and ground as Ryan's
    # (his rings already painted on), all four rows used.
    "jeremy": ("jeremy_walk_board.webp",
               [126, 309, 489, 668, 844, 1019, 1194, 1368, 1526],
               [11, 247, 471, 685, 910],
               ["north", "south", "west", "east"],
               set(), "opaque"),
}
# The opaque boards' ground, taken from each cell's border: within
# WALK_GROUND_TOL of it (max channel) and reached from the edge is ground;
# enclosed pockets of it (between arm and body) WALK_POCKET_MIN px or more,
# as flat as the ground, go too; then WALK_HALO_PEEL passes take the
# in-between tones (within BLEND_TOL: the foot shadow's rim) off the edge.
WALK_GROUND_TOL = 10
WALK_POCKET_MIN = 40
WALK_HALO_PEEL = 2
WALK_PLUM_LUM = 55    # the glow: plum (blue over green, not under red) this dark

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
    import cv2  # tool dependency (opencv-python-headless)
    path, xs, ys, facings, skip, ground = WALKS[hero]
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
                cell = cut_opaque_cell(cell)
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
    ref = max(f.height for f in out["south"])
    return out, ref


def cut_opaque_cell(cell):
    """One cell of an opaque walk board, its ground made transparent (hard
    alpha): flood-filled in from the cell's edge, then its enclosed pockets
    and the halo round the figure."""
    import cv2  # tool dependency (opencv-python-headless)
    rgb = cell[..., :3].astype(int)
    h, w, _ = rgb.shape
    border = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3),
                             rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
    ground = np.median(border, axis=0)
    off = np.abs(rgb - ground).max(axis=2)
    # ...or the ground's own plum, a little lit: the boards glow faintly
    # behind the figure (Jeremy's), brighter than the border's ground.
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    plum = (rgb.mean(axis=2) < WALK_PLUM_LUM) & (b >= g + 5) & (b >= r - 3) & \
           (rgb.max(axis=2) - rgb.min(axis=2) < 18)
    near = (off <= WALK_GROUND_TOL) | plum
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    solid = ~_flood(near, edge)
    f = rgb.astype(np.float32)
    mean = cv2.blur(f, (5, 5))
    spread = np.sqrt(np.maximum(cv2.blur(f * f, (5, 5)) - mean * mean, 0)).max(axis=2)
    flat = (solid & (off <= WALK_GROUND_TOL) & (spread <= POCKET_FLAT)).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(flat, connectivity=4)
    k = np.ones((3, 3), np.uint8)
    for j in range(1, n):
        if stats[j][4] >= WALK_POCKET_MIN:
            piece = (cv2.dilate((lab == j).astype(np.uint8), k) > 0) & (off <= WALK_GROUND_TOL)
            solid &= ~piece
    blend = (off <= BLEND_TOL) | plum
    for _ in range(WALK_HALO_PEEL):
        open_ = cv2.dilate((~solid).astype(np.uint8), k) > 0
        solid &= ~(open_ & blend)
    return np.dstack([rgb.astype(np.uint8), np.where(solid, 255, 0).astype(np.uint8)])


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
    if hero in WALKS:
        walks, ref = cut_walk(hero)
        wf = ref / float(HEIGHT)
        for d, frames in walks.items():
            for i, img in enumerate(frames):
                # The opaque boards' figures are dark-clad on a dark ground:
                # peeling their outline would eat gloves and cloth.
                if not OUTLINE and WALKS[hero][5] != "opaque":
                    img = peel_painted_outline(img)
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
