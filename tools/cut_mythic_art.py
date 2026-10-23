#!/usr/bin/env python3
"""Cut the designer's mythic item art out of their five sheets.

Sources: assets/sprites/paintings/mythic_*.jpg (.gdignore'd source art,
2026-10-23). Each is a 1024x1024 sheet of framed dark panels, one item to a
panel (helms on one sheet, then chests, weapons, gauntlets, boots).

Each piece is lifted off its panel: the flat panel background (about
(23,24,30), JPEG noise of a few levels) is flood-filled away from the crop's
edge, enclosed pockets of the same background (the middle of a ring, the
gap under an arch) are dropped too, and the first ring of pixels next to the
background fades out instead of stopping hard. Loose specks of JPEG noise
left on the panel are dropped. The piece is then fitted,
centred, onto a CANVAS x CANVAS transparent square.

These replace the 32x32 icons tools/generate_mythic_icons.py used to draw
for the same items; that tool keeps only the mythics this art does not cover.

Output: assets/items/mythic/<slug>.png (CANVAS x CANVAS RGBA)
Run: python3 tools/cut_mythic_art.py   (Pillow, numpy)
"""
from collections import deque

import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/mythic_%s.jpg"
OUT = "assets/items/mythic/%s.png"
CANVAS = 128
FIT = 122          # the piece's longer side on the canvas (a little margin)
BG_TOL = 7         # max per-channel distance from the panel colour that is still panel (noise is ~4;
                   # the art's dark outlines sit only ~10 off it, so keep this tight)
EDGE_TOL = 20      # ...pixels between BG_TOL and this, touching the panel, fade out
HOLE_MIN = 600     # enclosed panel-coloured pockets bigger than this (source px) are cut too
HOLE_TOL = 5
SPECK = 40         # opaque bits smaller than this (source px), cut off from the piece, are JPEG noise

# The four panels of the boxed sheets: a few pixels inside the frames' inner
# bevel, so the crop's edge is plain panel (measured).
_TL = (58, 58, 451, 450)
_TR = (569, 58, 963, 450)
_BL = (58, 570, 451, 964)
_BR = (569, 570, 963, 964)

# sheet -> [(slug, crop box)]. The helm sheet is laid out differently: two
# short panels down the left, a tall one under them, and the cap below the
# label column on the right.
PIECES = {
    "helms": [
        ("the_headbandz", (36, 36, 490, 280)),
        ("hannibals_mask", (36, 294, 490, 490)),
        ("mane_of_narashimha", (36, 532, 490, 988)),
        ("scholars_cap", (532, 640, 988, 988)),
    ],
    "chests": [
        ("adimantium", _TL),
        ("tigers_sunday_red", _TR),
        ("divine_resistance", _BL),
        ("hide_of_garmr", _BR),
    ],
    "weapons": [
        ("sabre_tooth", _TL),
        ("sword_of_theseus", _TR),
        ("umbral_eclipse", _BL),
        ("poseidons_trident", _BR),
    ],
    "gauntlets": [
        ("gauntlets_of_dungeon_mastering", _TL),
        ("hallowed_trunk", _TR),
        ("cuffs_of_current", _BL),
        ("concealed_carry", _BR),
    ],
    "boots": [
        ("boots_of_the_balancer", _TL),
        ("hermes_boots", _TR),
        ("jordan_1s", _BL),
        ("guardian_greaves", _BR),
    ],
}

_N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def _flood(mask: np.ndarray, seeds) -> np.ndarray:
    """Pixels of `mask` 4-connected to any seed."""
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


def _components(mask: np.ndarray):
    """Each 4-connected component of `mask`, as a list of (y, x)."""
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


def cut(sheet: Image.Image, box) -> Image.Image:
    rgb = np.asarray(sheet.crop(box).convert("RGB")).astype(int)
    h, w, _ = rgb.shape
    ring = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(ring, axis=0)
    dist = np.abs(rgb - bg).max(axis=2)

    near = dist <= BG_TOL
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    panel = _flood(near, edge)
    # Enclosed pockets of plain panel (ring middles, arch gaps).
    for comp in _components((dist <= HOLE_TOL) & ~panel):
        if len(comp) >= HOLE_MIN:
            panel |= _flood(near, comp)

    alpha = np.where(panel, 0.0, 1.0)
    # Soften the rim: a not-quite-panel pixel touching the panel fades by how
    # close to the panel colour it is.
    touching = np.zeros_like(panel)
    touching[1:] |= panel[:-1]
    touching[:-1] |= panel[1:]
    touching[:, 1:] |= panel[:, :-1]
    touching[:, :-1] |= panel[:, 1:]
    rim = touching & ~panel & (dist < EDGE_TOL)
    alpha[rim] = (dist[rim] - BG_TOL) / float(EDGE_TOL - BG_TOL)

    for comp in _components(alpha > 0):
        if len(comp) < SPECK:
            alpha[tuple(np.array(comp).T)] = 0.0

    ys, xs = np.nonzero(alpha > 0)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgba = np.dstack([rgb, (alpha * 255).round()]).astype(np.uint8)[y0:y1, x0:x1]
    piece = Image.fromarray(rgba, "RGBA")

    # Downscale with premultiplied alpha, so the dark panel never bleeds in.
    scale = FIT / float(max(piece.size))
    size = (max(1, round(piece.width * scale)), max(1, round(piece.height * scale)))
    small = piece.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    out = Image.new("RGBA", (CANVAS, CANVAS))
    out.paste(small, ((CANVAS - size[0]) // 2, (CANVAS - size[1]) // 2))
    return out


def main() -> None:
    for sheet_name, pieces in PIECES.items():
        sheet = Image.open(SRC % sheet_name)
        for slug, box in pieces:
            img = cut(sheet, box)
            img.save(OUT % slug)
            bb = img.getbbox()
            print("%-32s %s -> %dx%d on %d" % (slug, sheet_name, bb[2] - bb[0], bb[3] - bb[1], CANVAS))


if __name__ == "__main__":
    main()
