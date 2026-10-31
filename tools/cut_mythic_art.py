#!/usr/bin/env python3
"""Cut the designer's mythic item art out of their five sheets.

Sources: assets/sprites/paintings/mythic_*.jpg / .webp (.gdignore'd source
art, 2026-10-23). Each is a 1024x1024 sheet of framed dark panels, one item to
a panel: helms, chests, weapons, gauntlets, boots, then wands, belts, rings,
shields and bows (that last sheet has an empty fourth panel).

Each piece is lifted off its panel: the flat panel background (about
(23,24,30), JPEG noise of a few levels) is flood-filled away from the crop's
edge, enclosed pockets of the same background (the middle of a ring, the
gap under an arch) are dropped too, and the first ring of pixels next to the
background fades out instead of stopping hard. Loose specks of JPEG noise
left on the panel are dropped. The piece is then fitted,
centred, onto a CANVAS x CANVAS transparent square.

The Bow of Arash's arrow is painted pointing back over the string; the
designer asked for it flipped (2026-10-23). FIXES swaps its two ends — the
head and the fletching, each turned half a turn about the arrow's midpoint —
after the panel is cut away, on a padded canvas (the fletching is longer
than the head, so at the head's end it reaches past the panel's frame).

These replace the 32x32 icons tools/generate_mythic_icons.py used to draw.
The Bladed Doughnut, the last of them, came on its own panel on 2026-10-31
(mythic_bladed_doughnut.png).

Output: assets/items/mythic/<slug>.png (CANVAS x CANVAS RGBA)
Run: python3 tools/cut_mythic_art.py   (Pillow, numpy)
"""
import os
from collections import deque

import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/mythic_%s"   # .jpg or .webp
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
    "wands": [
        ("wand_of_the_phoenix_feather", _TL),
        ("circes_wand_of_cauldron_stirring", _TR),
        ("reaper_scythe", _BL),
        ("feral_evocation", _BR),
    ],
    "belts": [
        ("belt_of_scrolls", _TL),
        ("megingjord", _TR),
        ("orions_belt", _BL),
        ("girdle_of_aphrodite", _BR),
    ],
    "rings": [
        ("the_precious", _TL),
        ("ring_of_nibelung", _TR),
        ("draupnir", _BL),
        ("ring_of_thomas_the_train_tracks", _BR),
    ],
    "shields": [
        ("delfins_deterministic_round_shield", _TL),
        ("steve_rodgers_bastion", _TR),
        ("presence_of_mind", _BL),
        ("crooked_dueling_shield", _BR),
    ],
    # The Bladed Doughnut on its own panel (2026-10-31): a frosted doughnut
    # ringed with steel spikes. Cropped inside the panel's purple bevel.
    "bladed_doughnut": [
        ("bladed_doughnut", (10, 12, 334, 340)),
    ],
    "bows": [
        ("bow_of_arash", _TL),
        ("belthronding", (573, 63, 963, 450)),   # past a speck of frame bevel in the corner
        ("bow_of_budding_blasts", _BL),
    ],
}

# The Bow of Arash's arrow, measured on its sheet: the shaft's centre line
# runs x = y + 2.5; the head's tip and the nock project onto it at x+y = 148
# and 839, so the arrow's midpoint is (248, 245.5) and a pixel p maps to
# ARROW_TWICE_MID - p under the half turn. HEAD_BOX holds the head (and, once
# swapped, the longer fletching); its mirror holds the fletching.
ARROW_TWICE_MID = (496, 491)
HEAD_BOX = (44, 42, 186, 184)
PAD = 24


def _flip_arrow(rgba: np.ndarray, origin) -> np.ndarray:
    """Swap the arrow's ends: each end's box, turned half a turn about the
    arrow's midpoint, lands exactly on the other end's box."""
    sx, sy = ARROW_TWICE_MID[0] - 2 * origin[0], ARROW_TWICE_MID[1] - 2 * origin[1]
    x0, y0, x1, y1 = (HEAD_BOX[0] - origin[0], HEAD_BOX[1] - origin[1],
                      HEAD_BOX[2] - origin[0], HEAD_BOX[3] - origin[1])
    tx0, ty0, tx1, ty1 = sx - x1 + 1, sy - y1 + 1, sx - x0 + 1, sy - y0 + 1
    head = rgba[y0:y1, x0:x1].copy()
    tail = rgba[ty0:ty1, tx0:tx1].copy()
    out = rgba.copy()
    out[ty0:ty1, tx0:tx1] = head[::-1, ::-1]
    out[y0:y1, x0:x1] = tail[::-1, ::-1]
    return out


FIXES = {"bow_of_arash": _flip_arrow}

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


# Panels whose plain ground is less even than the boxed sheets': the
# doughnut's has a soft dark shadow along its foot (sheet -> (bg, edge) tol).
TOLS = {"bladed_doughnut": (16, 30)}


def cut(sheet: Image.Image, box, fix=None, tols=None) -> Image.Image:
    bg_tol, edge_tol = tols or (BG_TOL, EDGE_TOL)
    rgb = np.asarray(sheet.crop(box).convert("RGB")).astype(int)
    h, w, _ = rgb.shape
    ring = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(ring, axis=0)
    dist = np.abs(rgb - bg).max(axis=2)

    near = dist <= bg_tol
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
    rim = touching & ~panel & (dist < edge_tol)
    alpha[rim] = (dist[rim] - bg_tol) / float(edge_tol - bg_tol)

    for comp in _components(alpha > 0):
        if len(comp) < SPECK:
            alpha[tuple(np.array(comp).T)] = 0.0

    rgba = np.dstack([rgb, (alpha * 255).round()]).astype(np.uint8)
    if fix is not None:
        rgba = np.pad(rgba, ((PAD, PAD), (PAD, PAD), (0, 0)))
        rgba = fix(rgba, (box[0] - PAD, box[1] - PAD))
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    piece = Image.fromarray(rgba[y0:y1, x0:x1], "RGBA")

    # Downscale with premultiplied alpha, so the dark panel never bleeds in.
    scale = FIT / float(max(piece.size))
    size = (max(1, round(piece.width * scale)), max(1, round(piece.height * scale)))
    small = piece.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    out = Image.new("RGBA", (CANVAS, CANVAS))
    out.paste(small, ((CANVAS - size[0]) // 2, (CANVAS - size[1]) // 2))
    return out


def main() -> None:
    for sheet_name, pieces in PIECES.items():
        path = next(SRC % sheet_name + ext for ext in (".jpg", ".webp", ".png")
                    if os.path.exists(SRC % sheet_name + ext))
        sheet = Image.open(path)
        for slug, box in pieces:
            img = cut(sheet, box, FIXES.get(slug), TOLS.get(sheet_name))
            img.save(OUT % slug)
            bb = img.getbbox()
            print("%-32s %s -> %dx%d on %d" % (slug, sheet_name, bb[2] - bb[0], bb[3] - bb[1], CANVAS))


if __name__ == "__main__":
    main()
