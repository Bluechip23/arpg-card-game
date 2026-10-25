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
out (ERASE); Brad wears the embroidered feather on his breastplate (FEATHER).

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
it would swallow, like glowing eyes, keeps its colour); and a
one-texel outline in a dark, hue-tinted shade of the colour it borders,
SoM's inked silhouette.

The figure is lifted off the black first: the background (pure black with a
few levels of noise) is flood-filled in from the crop's edge, so dark cloth
inside the outline stays; labels and specks are dropped (only the figure and
pieces near its size survive). Poses are packed bottom-centred into square
cells, one column, rows in CharacterAnimator order: south (front), north
(back), east, west; a missing side is the mirror of the other.

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
HEIGHT = 100       # texels, crown to feet, of the hero's front pose (+ the outline: ~1.6 tiles at 64 a tile)
SMOOTH_HEIGHT = 204   # the smooth sheet's height, crown to feet: HEIGHT (+ outline) at 128 a tile
WIDEN = 1.12       # drawn this much wider than tall (SpriteFigure.BOARD_WIDEN), baked in
                   # (designer, 2026-10-24: err on the side of under-pixelating the heroes)
PALETTE = 96       # colours per hero after the tidy (0 = keep every colour)
ACCENT_KEEP = 36   # ...but a pixel the tidy would move further than this keeps its colour
VIBRANCE = 1.12    # SoM's saturated palette: colour pushed this much further from grey
OUTLINE = True     # the inked one-texel silhouette
KEEP_SHARE = 0.05  # pieces smaller than this share of the figure are dropped
ROWS = ["south", "north", "east", "west"]

# Per hero: (source, crop box (x0, y0, x1, y1), facing). East/west name the
# way the pose faces; the other side is its mirror. The first pose (the
# front) sets the hero's scale for every pose from the same source; a pose
# from the other source is scaled to the front's height.
FB = "heroes_front_back.webp"
SIDE = "heroes_side.webp"
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
    "ryan": [
        (FB, (704, 419, 928, 835), "south"),
        (FB, (710, 3, 930, 413), "north"),
        (SIDE, (655, 4, 787, 371), "west"),
    ],
    "brad": [
        (FB, (1040, 422, 1283, 835), "south"),
        (FB, (1042, 0, 1280, 414), "north"),
        (SIDE, (960, 5, 1112, 372), "west"),
    ],
    "stephen": [
        (FB, (1398, 417, 1636, 835), "south"),
        (FB, (1404, 0, 1649, 413), "north"),
        (SIDE, (1264, 367, 1420, 702), "east"),
    ],
}

# The sources' ground: a flat dark grey (with a few levels of compression
# noise). Anything within GROUND_TOL of it, reached from the crop's edge, is
# background; the figures' own dark outline keeps their dark cloth inside.
GROUND = {FB: (32, 32, 30), SIDE: (32, 32, 30)}
GROUND_TOL = 6

# Painted out of the source before cutting (designer, 2026-10-25), from what
# surrounds them (OpenCV inpaint): inside each polygon (source pixels), the
# pixels the rule picks out. "charm": light or gold (Cory's rabbit's foot and
# its chain, on his near-black robe). "bow": the bow's brown-orange limb and
# gold nock against Stephen's dark trousers and pale arm-wrap above it.
ERASE = {
    ("cory", "east"): [([(428, 92), (452, 92), (456, 178), (426, 178)], "charm")],
    ("stephen", "east"): [([(1356, 606), (1370, 610), (1340, 646), (1324, 642)], "bow")],
}

# Brad's chest piece: an embroidered feather, golden white, almost heavenly,
# lying across the middle of the breastplate with its tip raised 20 degrees,
# up and to the right, the quill running out down to the left (designer,
# 2026-10-24). No pack shows it, so it is drawn here at the source's own
# resolution on the front pose, before any resampling, so the pixel and the
# smooth sheets both carry it. (cx, cy): its centre as a fraction of the
# cut-out's width and height; length: as a fraction of the figure's height.
FEATHER = {"brad": {"cx": 0.50, "cy": 0.335, "length": 0.15, "angle": 20.0}}
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
    rgb = sheet[box[1]:box[3], box[0]:box[2]].astype(int)
    h, w, _ = rgb.shape
    ground = np.array(GROUND.get(path, (0, 0, 0)))
    dark = np.abs(rgb - ground).max(axis=2) <= GROUND_TOL
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    solid = ~_flood(dark, edge)
    comps = _components(solid)
    biggest = max(len(c) for c in comps)
    keep = np.zeros_like(solid)
    for comp in comps:
        if len(comp) >= biggest * KEEP_SHARE:
            keep[tuple(np.array(comp).T)] = True
    ys, xs = np.nonzero(keep)
    rgba = np.dstack([rgb.astype(np.uint8), np.where(keep, 255, 0).astype(np.uint8)])
    return Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


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
        if facing == "south" and hero in FEATHER:
            draw_feather(img, **FEATHER[hero])
        if scale is None or facing == "scale":
            # The first pose (or the "scale" reference) sets the hero's scale
            # for every pose cut from the same source.
            ref_h = img.height if HEIGHT is None else HEIGHT
            scale = (path, img.height / float(ref_h))
            if facing == "scale":
                continue
        factor = scale[1] if path == scale[0] else img.height / float(ref_h)
        full[facing] = resample(img, factor)
        soft[facing] = soft_frame(img, factor)
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
    cell = max(max(f.size) for f in frames.values()) + 2
    cell += cell % 2
    sheet = Image.new("RGBA", (cell, cell * len(ROWS)))
    for r, d in enumerate(ROWS):
        f = frames[d]
        sheet.paste(f, ((cell - f.width) // 2, r * cell + cell - f.height), f)
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
    smooth_art.pack([[soft[d]] for d in ROWS], scell, 1, lambda row, ci: row[0], air=0).save(sout)
    print("%-7s cell %d: %s" % (hero, cell, ", ".join("%s %dx%d" % (d, frames[d].width, frames[d].height) for d in ROWS)))


def main():
    for hero, poses in HEROES.items():
        build(hero, poses)


if __name__ == "__main__":
    main()
