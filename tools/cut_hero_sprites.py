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
  hero_brad.png, hero_brad_front.png — "4. Warrior (Chieftain)": back, front,
    two side views (both face left), and on its own the front view with the
    War Rack's weapon over his right shoulder, which is the front used
    (designer, 2026-10-23).

Keeping the art's nuance comes first (designer, 2026-10-23: the first cut,
34 texels tall, was far too pixelated): each hero keeps HEIGHT texels from
crown to feet — the warrior's own resolution, two thirds of the others' —
and the game draws them finer than its 32-texel tiles (SpriteFigure's board
pixel size) so they stand ~1.35 tiles tall. One scale per hero (set by the front pose), so the
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
Run: python3 tools/cut_hero_sprites.py   (Pillow, numpy)
"""
import os
from collections import deque

import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/%s"
OUT = "assets/sprites/generated/heroes/%s.png"
HEIGHT = 96        # texels, crown to feet, of the hero's front pose
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
    "brad": [
        ("hero_brad.png", (0, 136, 74, 236), "scale"),       # the sheet's front: sets the scale only
        ("hero_brad_front.png", (0, 36, 68, 138), "south"),  # the front with the War Rack over his shoulder
        ("hero_brad.png", (0, 35, 74, 135), "north"),
        ("hero_brad.png", (0, 239, 74, 338), "west"),
    ],
}

# Cory's side view: the chest charm (beads and a pendant) hangs off the front
# of the robe inside this box (source pixels); its light and coloured pixels
# are nothing like the near-black robe around it.
CHARM_BOX = {"cory": (68, 585, 92, 628)}
# ...and a speck of the blue his eyes glow in the front view, lit inside the
# hood opening of the finished side frame (east-facing), as a fraction of the
# frame's width and height (so it holds whatever HEIGHT is).
EYE_SPECK = {"cory": (0.80, 0.155)}
EYE_BLUE = (110, 190, 255, 255)

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


def cut(path, box, charm=None):
    """The figure in `box`, full size, on transparency, cropped to itself."""
    rgb = np.asarray(Image.open(SRC % path).convert("RGB").crop(box)).astype(int)
    h, w, _ = rgb.shape
    dark = rgb.max(axis=2) <= BG
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    solid = ~_flood(dark, edge)
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
    """Down by `factor` with a sharp (Lanczos) filter on premultiplied colour,
    then on/off alpha: crisp pixel edges, the art's detail kept."""
    size = (max(1, round(img.width / factor)), max(1, round(img.height / factor)))
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


def build(hero, poses):
    scale = None
    full = {}
    for path, box, facing in poses:
        charm = CHARM_BOX.get(hero) if facing in ("east", "west") else None
        img = cut(path, box, charm)
        if scale is None or facing == "scale":
            # The first pose (or the "scale" reference) sets the hero's scale
            # for every pose cut from the same source.
            scale = (path, img.height / float(HEIGHT))
            if facing == "scale":
                continue
        factor = scale[1] if path == scale[0] else img.height / float(HEIGHT)
        full[facing] = resample(img, factor)
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
    print("%-7s cell %d: %s" % (hero, cell, ", ".join("%s %dx%d" % (d, frames[d].width, frames[d].height) for d in ROWS)))


def main():
    for hero, poses in HEROES.items():
        build(hero, poses)


if __name__ == "__main__":
    main()
