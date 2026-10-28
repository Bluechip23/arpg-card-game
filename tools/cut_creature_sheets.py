#!/usr/bin/env python3
"""Cut the designer's 4x4 creature walk sheets into the game's sheets.

Sources (assets/sprites/paintings/, .gdignore'd source art):
  white_manticore_sheet.webp, weregoat_walk_board.webp, wolf_sheet.webp,
    sabertooth_v2_clean.webp — 4x4 walk frames on pure black (row names on
    the left; the sabertooth's labels blacked out by
    tools/clean_sabertooth_sheet.py).
The row labels are not reliable ("walking left" rows that face right,
weregoat and wolf "Right" rows that face left), so FRAMES below picks each
direction's frames by what they show and the opposite side is the mirror.
(The stone-floor sheets — hydra, sabertooth, werewolf — and their cutter
are gone: all three moved to new art, 2026-10-28.)

Anything brighter than the black is the creature; rows and frames are split
where nothing lies between them.
Each frame is box-filtered DOWN x with on/off alpha (2026-10-25: each DOWN now
lands the creature on exactly the heroes' 64 texels a tile at
SpriteEnemyFigure's BOARD_SCALE, its height in tiles unchanged — the old
57-69 a tile drew the art a little off whole pixels) (2026-10-24, near the
heroes' fineness, ~64 texels a tile: the black sheets' art pixels are ~2
source pixels, DOWN 3 — DOWN 4 had thrown half their detail away) and packed
bottom-centred into square cells in the Craftpix layout SpriteEnemyFigure
plays (rows front, back, left, right): Idle = each direction's first frame,
Walk = all of them.

Output: assets/sprites/generated/sheets/<creature>/{Idle,Walk}.png
Needs: numpy, Pillow, opencv-python-headless (tool dependencies only)
Run: python3 tools/cut_creature_sheets.py [creature ...]
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import smooth_art  # noqa: E402  (the smooth, non-pixelated sheets)

SRC = "assets/sprites/paintings/%s"
OUT = "assets/sprites/generated/sheets/%s"

# Per creature: source, kind, DOWN, and (row, col) frames per direction.
# "right" frames face right; "left" frames face left; a missing side is the
# mirror of the other.
FRAMES = {
    "sabertooth": {
        # 2026-10-28: the designer's new walk sheet on black (rows: walking
        # up = back, "walking left" — which faces right too —, walking down
        # = front, walking right), its labels blacked out first by
        # tools/clean_sabertooth_sheet.py. The right-facing "walking right"
        # row is the right; the left is its mirror. Shrunk to the old
        # sheet's front height (114 texels).
        "src": "sabertooth_v2_clean.webp", "kind": "black", "down": 202 / 114.0,
        "back": [(0, c) for c in range(4)],
        "front": [(2, c) for c in range(4)],
        "right": [(3, c) for c in range(4)],
    },
    "white_manticore": {
        "src": "white_manticore_sheet.webp", "kind": "black", "down": 3 * 0.5 / 0.5625,
        "back": [(0, c) for c in range(4)],
        "front": [(1, c) for c in range(4)],
        "left": [(2, c) for c in range(4)],
        "right": [(3, c) for c in range(4)],
    },
    "weregoat": {
        # 2026-10-27: the designer's redrawn weregoat walk sheet (Up = back,
        # Down = front, both side rows facing left; the row names on the left).
        # Its frames are larger than the old sheet's: shrunk less, so it stands
        # a head above the heroes as before.
        "src": "weregoat_walk_board.webp", "kind": "black", "down": 2.1,
        "back": [(0, c) for c in range(4)],
        "front": [(1, c) for c in range(4)],
        "left": [(2, c) for c in range(4)],           # its "Right" row faces left as well
    },
    "wolf": {
        "src": "wolf_sheet.webp", "kind": "black", "down": 3 * 0.5 / 0.525,
        "back": [(0, c) for c in range(4)],
        "front": [(1, c) for c in range(4)],
        "left": [(2, c) for c in range(4)],           # its "Right" row faces left as well
    },
}


def _tidy(fg: np.ndarray, bg_like: np.ndarray = None) -> np.ndarray:
    """Drop specks (keep pieces >= 4% of the largest) and fill holes. With
    `bg_like` (pixels that look like the bare background), a hole of more
    than HOLE_OPEN_MIN px that is mostly background stays open: floor or
    label strip walled in between the hydra's necks, not part of it."""
    fg = fg.astype(np.uint8)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(fg, 8)
    if n > 1:
        biggest = int(stats[1:, cv2.CC_STAT_AREA].max())
        keep = np.zeros_like(fg)
        for i in range(1, n):
            if stats[i, cv2.CC_STAT_AREA] >= biggest * 0.04:
                keep[labels == i] = 1
        fg = keep
    # Fill holes: flood the outside from a one-pixel empty border (a tight
    # crop's corner can be creature), whatever the flood can't reach is inside.
    padded = np.pad(fg, 1)
    ff = np.zeros((padded.shape[0] + 2, padded.shape[1] + 2), np.uint8)
    cv2.floodFill(padded, ff, (0, 0), 1)
    holes = (1 - padded[1:-1, 1:-1]).astype(np.uint8)
    if bg_like is not None and holes.any():
        n, labels, stats, _ = cv2.connectedComponentsWithStats(holes, 4)
        for i in range(1, n):
            hole = labels == i
            if stats[i, cv2.CC_STAT_AREA] > HOLE_OPEN_MIN and bg_like[hole].mean() > 0.5:
                holes[hole] = 0
    return fg | holes


HOLE_OPEN_MIN = 20


def _segments(profile: np.ndarray, min_gap: int) -> list:
    """Runs where the profile is non-empty, merging gaps shorter than min_gap."""
    on = profile > 2
    runs = []
    start = None
    gap = 0
    for i, v in enumerate(on):
        if v:
            if start is None:
                start = i
            gap = 0
            end = i
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                runs.append((start, end + 1))
                start = None
    if start is not None:
        runs.append((start, end + 1))
    return runs


def black_frames(rgb: np.ndarray) -> list:
    """Every creature on a black sheet, as 4 rows of 4 crops. Tails and
    horns reach into the next row, so rows are not split on empty bands:
    each connected piece goes to the row (quarter of the sheet, cut at the
    emptiest line near each quarter mark) its centre falls in, and each row
    then splits into its four widest runs (the row name is a narrow run at
    the far left)."""
    bright = rgb.max(axis=2) > 16
    h = bright.shape[0]
    prof = bright[:, 150:].sum(1).astype(float)
    cuts = [0]
    for k in (1, 2, 3):
        lo, hi = int(h * k / 4 - h / 10), int(h * k / 4 + h / 10)
        cuts.append(lo + int(np.argmin(prof[lo:hi])))
    cuts.append(h)
    near = cv2.dilate(bright.astype(np.uint8), np.ones((5, 5), np.uint8))
    n, labels, stats, cents = cv2.connectedComponentsWithStats(near, 8)
    grid = []
    for ri in range(4):
        y0, y1 = cuts[ri], cuts[ri + 1]
        ids = [i for i in range(1, n) if y0 <= cents[i][1] < y1 and stats[i, cv2.CC_STAT_AREA] > 40]
        row_mask = np.isin(labels, ids) & bright
        ys = np.where(row_mask.any(axis=1))[0]
        ry0, ry1 = int(ys.min()), int(ys.max()) + 1
        cols = _segments(row_mask[ry0:ry1].sum(0), 8)
        cols = sorted(sorted(cols, key=lambda c: c[1] - c[0])[-4:])
        if len(cols) < 4 or max(c[1] - c[0] for c in cols) > 2.2 * min(c[1] - c[0] for c in cols):
            # Creatures touch (a tail curled into the next one): cut the
            # row at the emptiest column near each quarter of its width.
            # The row's span starts where the creatures do: the row name is a
            # run ending left of x=150, but a snout can reach past that line
            # (the wolf's does), so only whole runs are skipped, never pixels.
            runs = _segments(row_mask[ry0:ry1].sum(0), 8)
            rx0 = min(a for a, b in runs if b > 150)
            rx1 = max(b for a, b in runs)
            xprof = row_mask[ry0:ry1].sum(0).astype(float)
            w = rx1 - rx0
            xc = [rx0]
            for k in (1, 2, 3):
                lo, hi = int(rx0 + w * k / 4 - w / 12), int(rx0 + w * k / 4 + w / 12)
                xc.append(lo + int(np.argmin(xprof[lo:hi])))
            xc.append(rx1)
            cols = [(xc[i], xc[i + 1]) for i in range(4)]
        cells = []
        for x0, x1 in cols:
            fg = _tidy(row_mask[ry0:ry1, x0:x1])
            out = np.zeros((ry1 - ry0, x1 - x0, 4), float)
            out[..., :3] = rgb[ry0:ry1, x0:x1]
            out[..., 3] = fg
            cells.append(out)
        grid.append(cells)
    return grid


def downscale(rgba: np.ndarray, down) -> np.ndarray:
    if down != int(down):
        # A fractional factor: premultiplied box
        # resample, then on/off alpha.
        # (frames arrive as floats: colour 0..255, alpha 0..1)
        u8 = np.dstack([np.clip(rgba[..., :3], 0, 255), np.clip(rgba[..., 3:4], 0, 1) * 255]).round().astype(np.uint8)
        img = Image.fromarray(u8, "RGBA").convert("RGBa")
        size = (max(1, round(img.width / down)), max(1, round(img.height / down)))
        small = np.asarray(img.resize(size, Image.BOX).convert("RGBA")).copy()
        small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
        return small
    down = int(down)
    h, w, _ = rgba.shape
    h2, w2 = h // down, w // down
    a = rgba[:h2 * down, :w2 * down].reshape(h2, down, w2, down, 4)
    cover = a[..., 3].sum((1, 3))
    rgb = (a[..., :3] * a[..., 3:4]).sum((1, 3)) / np.maximum(cover, 1e-6)[..., None]
    out = np.zeros((h2, w2, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(cover / (down * down) >= 0.5, 255, 0)
    return out


def trim(fr: np.ndarray) -> np.ndarray:
    ys, xs = np.where(fr[..., 3] > 0)
    return fr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def pack(rows, cell, cols) -> Image.Image:
    s = np.zeros((cell * 4, cell * cols, 4), np.uint8)
    for ri, row in enumerate(rows):
        for ci in range(cols):
            f = row[ci % len(row)]
            fh, fw = f.shape[:2]
            y = ri * cell + cell - 1 - fh
            x = ci * cell + (cell - fw) // 2
            s[y:y + fh, x:x + fw] = f
    return Image.fromarray(s, "RGBA")


def build(name: str) -> None:
    spec = FRAMES[name]
    down = spec["down"]
    grid = black_frames(np.array(Image.open(SRC % spec["src"]).convert("RGB")).astype(float))
    get = lambda r, c: grid[r][c]
    raw = {}
    frames = {}
    for d in ("front", "back", "left", "right"):
        if d in spec:
            for r, c in spec[d]:
                raw.setdefault((r, c), get(r, c))
            frames[d] = [trim(downscale(raw[(r, c)], down)) for r, c in spec[d]]
    if "left" not in frames:
        frames["left"] = [f[:, ::-1] for f in frames["right"]]
    if "right" not in frames:
        frames["right"] = [f[:, ::-1] for f in frames["left"]]
    rows = [frames["front"], frames["back"], frames["left"], frames["right"]]
    cell = max(max(f.shape[0], f.shape[1]) for row in rows for f in row) + 2
    out = OUT % name
    os.makedirs(out, exist_ok=True)
    pack([[row[0]] for row in rows], cell, 1).save(os.path.join(out, "Idle.png"))
    pack(rows, cell, max(len(r) for r in rows)).save(os.path.join(out, "Walk.png"))
    print("%s: cell %d px -> %s" % (name, cell, out))
    # The smooth version (smooth_art): the same cut-outs at SMOOTH_DENSITY
    # texels a tile (DOWN lands on 64 at BOARD_SCALE), soft, kept beside.
    sdown = down * 64.0 / smooth_art.SMOOTH_DENSITY
    soft = {}
    for d in ("front", "back", "left", "right"):
        if d in spec:
            soft[d] = [smooth_art.trim(smooth_art.resample(raw[(r, c)], sdown)) for r, c in spec[d]]
    if "left" not in soft:
        soft["left"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in soft["right"]]
    if "right" not in soft:
        soft["right"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in soft["left"]]
    srows = [soft["front"], soft["back"], soft["left"], soft["right"]]
    scell = max(max(f.width, f.height) for row in srows for f in row) + 2
    sdir = os.path.join(smooth_art.ROOT, "sheets", name)
    os.makedirs(sdir, exist_ok=True)
    smooth_art.pack(srows, scell, 1, lambda row, ci: row[0]).save(os.path.join(sdir, "Idle.png"))
    smooth_art.pack(srows, scell, max(len(r) for r in srows), lambda row, ci: row[ci % len(row)]).save(os.path.join(sdir, "Walk.png"))


if __name__ == "__main__":
    for n in (sys.argv[1:] or list(FRAMES)):
        build(n)
