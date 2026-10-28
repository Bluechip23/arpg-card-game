#!/usr/bin/env python3
"""Cut the designer's hero sprites into the game's four-direction sheets.

Sources (assets/sprites/paintings/, .gdignore'd source art, 2026-10-23):
  hero_jeremy.png  — the skeleton in the rust-brown hooded cloak: four
    poses stacked, labelled Up / Down / Left / Right. The "Up" pose shows the
    face (it is the front: facing down the screen), "Down" the back, and both
    side views face left, so poses are taken by what they show.
  hero_cory.png    — "2. Monk (Shadow)": front, back, two side views (both
    face right). On the side view the charm on his chest (beads and a
    pendant) is cut away and a speck of his eyes' blue is lit inside the hood
    (designer, 2026-10-23).
  hero_ryan.png    — "3. Rogue (Outlaw)": back, front, two side views (both
    face left).
  hero_stephen.png — "5. Apex Hunter (Seeker)": back, front, two side views
    (both face right), bow and axe across his back; on the side view the bow
    is cut away (designer, 2026-10-23).
  hero_brad.png, hero_brad_front.png — "4. Warrior (Chieftain)": back, front,
    two side views (both face left), and on its own the front view with the
    War Rack's weapon over his right shoulder, which is the front used
    (designer, 2026-10-23).

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
BG = 14            # max channel at or below this is the black background
KEEP_SHARE = 0.05  # pieces smaller than this share of the figure are dropped
ROWS = ["south", "north", "east", "west"]

# Per hero: (source, crop box (x0, y0, x1, y1), facing). East/west name the
# way the pose faces; the other side is its mirror. The first source's front
# sets the hero's scale; a pose from another source is scaled to the height
# the hero's front would have (Brad's front from the larger image).
HEROES = {
    "jeremy": [
        ("hero_jeremy.png", (100, 8, 294, 172), "south"),    # labelled "Up": the face shows
        ("hero_jeremy.png", (100, 178, 294, 348), "north"),  # labelled "Down": the back
        ("hero_jeremy.png", (100, 350, 294, 507), "west"),   # both side views face left
    ],
    "cory": [
        ("hero_cory.png", (0, 50, 149, 220), "south"),
        ("hero_cory.png", (0, 223, 149, 395), "north"),
        ("hero_cory.png", (0, 555, 149, 705), "east"),       # the second side view
    ],
    "ryan": [
        ("hero_ryan.png", (0, 223, 114, 386), "south"),
        ("hero_ryan.png", (0, 60, 114, 220), "north"),
        ("hero_ryan.png", (0, 388, 114, 550), "west"),
    ],
    # Stephen's second board (designer, 2026-10-28): the bear-pelt arm is his
    # LEFT arm only, so facing left shows it (the board's bottom-right pose)
    # and facing right shows his bare right arm — a view of its own (the
    # board's bottom-left pose shows the pelt, so it is not used). The
    # board draws its side views ~15% larger than the front: they are
    # brought to the front's height (FIT_HEIGHT). (His first board,
    # hero_stephen.png with its glow and bow, is kept in paintings.)
    "stephen": [
        ("hero_stephen_2.png", (35, 0, 242, 287), "south"),
        ("hero_stephen_2.png", (246, 0, 474, 290), "north"),
        ("hero_stephen_2.png", (300, 291, 446, 616), "west"),
        ("hero_stephen_2_right.png", (0, 0, 69, 138), "east"),
    ],
    "brad": [
        ("hero_brad.png", (0, 136, 74, 236), "scale"),       # the sheet's front: sets the scale only
        ("hero_brad_front.png", (0, 36, 68, 138), "south"),  # the front with the War Rack over his shoulder
        ("hero_brad.png", (0, 35, 74, 135), "north"),
        ("hero_brad.png", (0, 239, 74, 338), "west"),
    ],
}

# Stephen's FIRST sheet (hero_stephen.png) set each figure in a soft dark-brown glow (rising from the
# black to ~30 before the figure's ~50+), which also fills the gaps under his
# arms, between his legs and inside the bow's curve. The glow is dark and
# smooth; the figure — even its dark outline — is textured. So for him the
# background is every dark (max channel <= limit), smooth (its 3x3 spread <=
# smooth) pixel reached from the edge or boxed in by the figure in a pocket
# at least `pocket` big; then `peel` passes take the glow's last fringe off
# the edge (his own outline is redrawn by the ink).
GLOW = {}   # (was {"stephen": ...} for his first board, hero_stephen.png)

# Stephen's side view: the bow is cut away entirely (designer, 2026-10-23).
# It hangs in front of him from shoulder to knee, string across his chest:
# inside this band (source pixels) its orange-brown stave and gold string
# are found by colour — his tattooed forearm, whose markings share the
# orange, is left out — and painted over from the tunic around them
# (OpenCV inpaint); where the bow stood clear of him it becomes background.
# (His second board, 2026-10-28, carries no bow in its side views: no band.)
BOW_BAND = {}
BOW_KEEP = {}
# First board's values, for hero_stephen.png: band [(100, 350), (108, 362),
# (104, 400), (95, 420), (85, 446), (73, 472), (56, 482), (48, 474),
# (60, 442), (72, 412), (82, 386), (86, 358)], keep [(48, 398, 77, 458)].

# Poses brought to the front's height instead of the front's scale (a board
# that draws its side views larger than its front).
FIT_HEIGHT = {"stephen": ("west",)}

# Cory's side view: the chest charm (beads and a pendant) hangs off the front
# of the robe inside this box (source pixels); its light and coloured pixels
# are nothing like the near-black robe around it.
CHARM_BOX = {"cory": (68, 585, 92, 628)}
# ...and a speck of the blue his eyes glow in the front view, lit inside the
# hood opening of the finished side frame (east-facing), as a fraction of the
# frame's width and height (so it holds whatever HEIGHT is).
EYE_SPECK = {"cory": (0.80, 0.155)}
EYE_BLUE = (110, 190, 255, 255)

# Brad's chest piece: an embroidered feather, golden white, almost heavenly,
# lying horizontal in the middle of the breastplate (designer, 2026-10-24). No pack shows it,
# so it is stitched in here texel by texel, in the sheet's own palette range,
# on the front frame after the ink pass: (fx, fy) is the feather's centre as
# a fraction of the frame's width and height. The plate is seen edge-on in
# the side views and hidden in the back view, so only the front carries it.
FEATHER = {"brad": (0.49, 0.36)}
# o = gold thread outline, h = white-gold highlight, m = pale gold vane,
# s = deeper gold shade, q = the quill; "." leaves the plate. It lies across
# the plate with its tip raised 20 degrees, up and to the right, the quill
# running out down to the left (designer).
FEATHER_ART = [
    "........oo..",
    ".....ooohhoo",
    "....ohhhmmhh",
    "...ohmmmqqqo",
    "..ohmqqqsso.",
    "..qqqmmmoo..",
    "qqossssso...",
    "...ooooo....",
]
FEATHER_INK = {
    "o": (196, 170, 112), "h": (255, 255, 252), "m": (252, 249, 236),
    "s": (238, 224, 184), "q": (226, 198, 130),
}
FEATHER_GLOW = (255, 252, 238)   # a faint halo where the thread meets the plate
FEATHER_GLOW_MIX = 0.15


def stitch_feather(frame, fx, fy):
    """Paint FEATHER_ART centred at (fx, fy) of the frame, with a soft glow
    on the plate texels around it."""
    h, w = len(FEATHER_ART), len(FEATHER_ART[0])
    cx = int(round(fx * (frame.shape[1] - 1)))
    cy = int(round(fy * (frame.shape[0] - 1)))
    x0, y0 = cx - w // 2, cy - h // 2
    inked = set()
    for r, row in enumerate(FEATHER_ART):
        for c, ch in enumerate(row):
            if ch != ".":
                inked.add((y0 + r, x0 + c))
    for y, x in {(y + dy, x + dx) for y, x in inked for dy, dx in _N8} - inked:
        if frame[y, x, 3] > 0:
            px = frame[y, x, :3].astype(float)
            frame[y, x, :3] = (px + (np.array(FEATHER_GLOW) - px) * FEATHER_GLOW_MIX).round().astype(np.uint8)
    for r, row in enumerate(FEATHER_ART):
        for c, ch in enumerate(row):
            if ch != ".":
                frame[y0 + r, x0 + c] = FEATHER_INK[ch] + (255,)


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


def erase_bow(sheet, band, keep):
    """Paint the bow out of `sheet` (RGB array): its stave and string, found by
    colour inside the `band` polygon (bar the `keep` boxes), inpainted from
    what surrounds them."""
    import cv2  # tool dependency (opencv-python-headless), only for this
    from PIL import ImageDraw
    mask = Image.new("L", (sheet.shape[1], sheet.shape[0]), 0)
    ImageDraw.Draw(mask).polygon(band, fill=255)
    region = np.asarray(mask) > 0
    for x0, y0, x1, y1 in keep:
        region[y0:y1, x0:x1] = False
    r, g, b = [sheet[..., i].astype(int) for i in range(3)]
    bow = region & (r > 90) & (r - b > 50) & (r - g > 12)
    bow = (cv2.dilate(bow.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & region
    bgr = np.ascontiguousarray(sheet[..., ::-1].astype(np.uint8))
    return cv2.inpaint(bgr, bow.astype(np.uint8) * 255, 3, cv2.INPAINT_TELEA)[..., ::-1]


def cut(path, box, charm=None, bow=None, glow=None):
    """The figure in `box`, full size, on transparency, cropped to itself."""
    sheet = np.asarray(Image.open(SRC % path).convert("RGB"))
    if bow is not None:
        sheet = erase_bow(sheet, *bow)
    rgb = sheet[box[1]:box[3], box[0]:box[2]].astype(int)
    h, w, _ = rgb.shape
    level = rgb.max(axis=2)
    if glow is None:
        dark = level <= BG
    else:
        pad = np.pad(level, 1, mode="edge")
        spread = np.max([pad[dy:dy + h, dx:dx + w] for dy in range(3) for dx in range(3)], axis=0) - \
                 np.min([pad[dy:dy + h, dx:dx + w] for dy in range(3) for dx in range(3)], axis=0)
        dark = (level <= glow["limit"]) & (spread <= glow["smooth"])
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    solid = ~_flood(dark, edge)
    if glow is not None:
        for comp in _components(solid & dark):
            if len(comp) >= glow["pocket"]:
                solid[tuple(np.array(comp).T)] = False
        fringe = level < glow["peel_limit"]
        for _ in range(glow["peel"]):
            open_ = ~solid
            touching = np.zeros_like(solid)
            touching[1:] |= open_[:-1]
            touching[:-1] |= open_[1:]
            touching[:, 1:] |= open_[:, :-1]
            touching[:, :-1] |= open_[:, 1:]
            solid &= ~(touching & fringe)
    if charm is not None:
        cx0, cy0, cx1, cy1 = charm[0] - box[0], charm[1] - box[1], charm[2] - box[0], charm[3] - box[1]
        region = np.zeros_like(solid)
        region[cy0:cy1, cx0:cx1] = True
        lum = rgb.mean(axis=2)
        sat = rgb.max(axis=2) - rgb.min(axis=2)
        charm_px = region & solid & ((lum > 70) | (sat > 40))
        # Where the charm hangs past the robe it goes; where it lies on the
        # robe, the robe's colour (the nearest dark pixel to its left) shows.
        for y, x in zip(*np.nonzero(charm_px)):
            robe = None
            for dx in range(1, 6):
                if x - dx >= 0 and solid[y, x - dx] and not charm_px[y, x - dx] and lum[y, x - dx] < 70:
                    robe = rgb[y, x - dx]
                    break
            if robe is None or not solid[y, min(w - 1, x + 2)] or charm_px[y, min(w - 1, x + 2)]:
                solid[y, x] = False
            else:
                rgb[y, x] = robe
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


def stitch_feather_soft(img, fx, fy):
    """Brad's feather on the smooth front: FEATHER_ART drawn at the pixel
    sheet's texel size, then scaled up smooth onto the plate."""
    k = SMOOTH_HEIGHT / float(HEIGHT)
    h, w = len(FEATHER_ART), len(FEATHER_ART[0])
    art = Image.new("RGBA", (w, h))
    for r, row in enumerate(FEATHER_ART):
        for c, ch in enumerate(row):
            if ch != ".":
                art.putpixel((c, r), FEATHER_INK[ch] + (255,))
    art = art.convert("RGBa").resize((round(w * k), round(h * k)), Image.LANCZOS).convert("RGBA")
    cx = int(round(fx * (img.width - 1)))
    cy = int(round(fy * (img.height - 1)))
    img.alpha_composite(art, (cx - art.width // 2, cy - art.height // 2))


def build(hero, poses):
    scale = None
    full = {}
    soft = {}
    for path, box, facing in poses:
        charm = CHARM_BOX.get(hero) if facing in ("east", "west") else None
        bow = (BOW_BAND[hero], BOW_KEEP.get(hero, [])) if hero in BOW_BAND and facing in ("east", "west") else None
        img = cut(path, box, charm, bow, GLOW.get(hero))
        if scale is None or facing == "scale":
            # The first pose (or the "scale" reference) sets the hero's scale
            # for every pose cut from the same source.
            ref_h = img.height if HEIGHT is None else HEIGHT
            scale = (path, img.height / float(ref_h))
            if facing == "scale":
                continue
        factor = scale[1] if path == scale[0] and facing not in FIT_HEIGHT.get(hero, ()) \
            else img.height / float(ref_h)
        full[facing] = resample(img, factor)
        soft[facing] = soft_frame(img, factor)
    full = {d: vibrance(f) for d, f in full.items()}
    full = tidy_palette(full)
    frames = {}
    for d, f in full.items():
        frame = ink_outline(f) if OUTLINE else f
        if d in ("east", "west") and hero in EYE_SPECK:
            fx, fy = EYE_SPECK[hero]
            x = int(round(fx * (frame.shape[1] - 1)))
            if d == "west":
                x = frame.shape[1] - 1 - x
            y = int(round(fy * (frame.shape[0] - 1)))
            frame[y, x] = EYE_BLUE
        if d == "south" and hero in FEATHER:
            stitch_feather(frame, *FEATHER[hero])
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
        if d in ("east", "west") and hero in EYE_SPECK:
            fx, fy = EYE_SPECK[hero]
            x = int(round(fx * (f.width - 1)))
            if d == "west":
                x = f.width - 1 - x
            y = int(round(fy * (f.height - 1)))
            dot = Image.new("RGBA", (2, 2), EYE_BLUE)
            f.alpha_composite(dot, (x, y))
        if d == "south" and hero in FEATHER:
            stitch_feather_soft(f, *FEATHER[hero])
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
