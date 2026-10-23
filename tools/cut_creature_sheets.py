#!/usr/bin/env python3
"""Cut the designer's 4x4 creature walk sheets into the game's sheets.

Sources (assets/sprites/paintings/, .gdignore'd source art), 2026-10-22:
  hydra_sheet.jpg, werewolf_sheet.jpg, sabertooth_sheet.jpg — 4x4 walk
    frames on a dark stone floor, a label strip over each row.
  white_manticore_sheet.webp, weregoat_sheet.webp, wolf_sheet.webp — 4x4 walk frames on
    pure black, row names on the left.
The row labels are not reliable ("walking left" rows that face right, a
weregoat and wolf "Right" rows that face left, werewolf "back" frames that are side
views — the werewolf walks those, upright), so FRAMES below picks each direction's frames by what they show and
the opposite side is the mirror.

Stone sheets: the three share one floor template repeated in every cell,
so a clean plate of the bare floor is rebuilt from the cells (floor_plate);
each creature is what differs from it, minus its own shadow, with GrabCut
settling the edge; specks are dropped and holes filled. Black sheets: anything brighter than the
black is the creature; rows and frames are split where nothing lies between them.
Each frame is box-filtered DOWN x with on/off alpha and packed
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

SRC = "assets/sprites/paintings/%s"
OUT = "assets/sprites/generated/sheets/%s"

# Stone sheets: the cell grid below the label strips.
STONE_COLS = [(0, 322), (325, 646), (649, 970), (974, 1281)]
STONE_ROWS = [(32, 205), (248, 413), (453, 622), (662, 830)]

# Per creature: source, kind, DOWN, and (row, col) frames per direction.
# "right" frames face right; "left" frames face left; a missing side is the
# mirror of the other.
FRAMES = {
    "hydra": {
        "src": "hydra_sheet.jpg", "kind": "stone", "down": 3,
        "back": [(0, 0), (0, 1), (0, 2), (0, 3)],
        "front": [(2, 0), (2, 1), (2, 2), (2, 3)],
        "right": [(3, 0), (3, 1), (3, 2), (3, 3)],   # row 2 ("walking left") is mostly right-facing too
    },
    "werewolf": {
        "src": "werewolf_sheet.jpg", "kind": "stone", "down": 3,
        "back": [(0, 0), (0, 1)],                     # (0, 2), (0, 3) are side views
        "front": [(2, 0), (2, 1), (2, 2), (2, 3)],
        # Side: the upright walk on its hind legs (the back row's two side
        # views, facing right), not the "walking right" row on all fours
        # (designer, 2026-10-23).
        "right": [(0, 2), (0, 3)],
    },
    "sabertooth": {
        "src": "sabertooth_sheet.jpg", "kind": "stone", "down": 3,
        "back": [(0, 0), (0, 1), (0, 2), (0, 3)],
        "front": [(2, 0), (2, 1), (2, 2), (2, 3)],
        "right": [(3, 0), (3, 1), (3, 2), (3, 3)],
    },
    "white_manticore": {
        "src": "white_manticore_sheet.webp", "kind": "black", "down": 4,
        "back": [(0, c) for c in range(4)],
        "front": [(1, c) for c in range(4)],
        "left": [(2, c) for c in range(4)],
        "right": [(3, c) for c in range(4)],
    },
    "weregoat": {
        "src": "weregoat_sheet.webp", "kind": "black", "down": 4,
        "back": [(0, c) for c in range(4)],
        "front": [(1, c) for c in range(4)],
        "left": [(2, c) for c in range(4)],           # its "Right" row faces left as well
    },
    "wolf": {
        "src": "wolf_sheet.webp", "kind": "black", "down": 4,
        "back": [(0, c) for c in range(4)],
        "front": [(1, c) for c in range(4)],
        "left": [(2, c) for c in range(4)],           # its "Right" row faces left as well
    },
}


def _tidy(fg: np.ndarray) -> np.ndarray:
    """Drop specks (keep pieces >= 4% of the largest) and fill holes."""
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
    return fg | (1 - padded[1:-1, 1:-1])


_PLATE = None


def floor_plate() -> np.ndarray:
    """The bare floor of one stone cell (RGB, float). The three stone sheets
    share one floor template, repeated in every cell (they differ only by
    JPEG noise), so the floor at each cell pixel is the median of the
    samples there that look like stone, taken over the 32 hydra and
    sabertooth cells (their yellow and orange never pass for stone; the
    werewolf's dark fur would). The small patch every creature covers is
    inpainted."""
    global _PLATE
    if _PLATE is not None:
        return _PLATE
    w = min(b - a for a, b in STONE_COLS)
    h = min(b - a for a, b in STONE_ROWS)
    stack = []
    for name in ("hydra", "sabertooth"):
        a = np.array(Image.open(SRC % FRAMES[name]["src"]).convert("RGB")).astype(float)
        for y0, _ in STONE_ROWS:
            for x0, _ in STONE_COLS:
                stack.append(a[y0:y0 + h, x0:x0 + w])
    st = np.stack(stack)
    r, g, b = st[..., 0], st[..., 1], st[..., 2]
    stone = ((b >= r - 2) & (b >= g - 6)) | ((g > r + 6) & (g > b + 6))
    masked = np.where(stone[..., None], st, np.nan)
    with np.errstate(all="ignore"):
        import warnings
        warnings.simplefilter("ignore")
        plate = np.nanmedian(masked, axis=0)
    hole = np.isnan(plate[..., 0])
    plate = np.where(np.isnan(plate), 0, plate).astype(np.uint8)
    plate = cv2.inpaint(plate, hole.astype(np.uint8), 5, cv2.INPAINT_TELEA)
    _PLATE = plate.astype(float)
    return _PLATE


def cut_stone(bgr: np.ndarray, r: int, c: int) -> np.ndarray:
    """One stone cell: the creature is what differs from the bare floor
    (floor_plate), minus its own shadow (the floor, darker, same hue);
    GrabCut settles the uncertain edge between the two."""
    plate = floor_plate()
    ph, pw, _ = plate.shape
    x0 = STONE_COLS[c][0]
    y0 = STONE_ROWS[r][0]
    cell_bgr = bgr[y0:y0 + ph, x0:x0 + pw].copy()
    rgb = cv2.cvtColor(cell_bgr, cv2.COLOR_BGR2RGB).astype(float)
    diff = np.sqrt(((rgb - plate) ** 2).sum(-1))
    lum = rgb.sum(-1) + 1.0
    plum = plate.sum(-1) + 1.0
    hue = rgb / lum[..., None]
    phue = plate / plum[..., None]
    # Floor lit differently: the creature's own shadow (darker), or bare
    # floor where the plate kept other creatures' averaged shadows (lighter)
    # — either way the same stone hue, only the brightness moved.
    shadow = np.abs(hue - phue).sum(-1) < 0.06
    rr, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    warm = ((rr - b) >= 8) | ((g - b) >= 12)
    mask = np.full((ph, pw), cv2.GC_PR_BGD, np.uint8)
    mask[diff > 22] = cv2.GC_PR_FGD
    mask[(diff > 40) & ~shadow] = cv2.GC_FGD
    mask[(diff > 22) & warm] = cv2.GC_FGD
    mask[diff < 10] = cv2.GC_BGD
    mask[shadow & ~warm] = cv2.GC_BGD
    # The edges of the cell are floor.
    mask[:3, :] = cv2.GC_BGD
    mask[-3:, :] = cv2.GC_BGD
    mask[:, :3] = cv2.GC_BGD
    mask[:, -3:] = cv2.GC_BGD
    bgd = np.zeros((1, 65), np.float64)
    fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(cell_bgr, mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    fg = ((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)).astype(np.uint8)
    fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    fg = _tidy(fg)
    out = np.zeros((ph, pw, 4), float)
    out[..., :3] = rgb
    out[..., 3] = fg
    return out


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
            xs = np.where(row_mask[ry0:ry1, 150:].any(axis=0))[0] + 150
            rx0, rx1 = int(xs.min()), int(xs.max()) + 1
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


def downscale(rgba: np.ndarray, down: int) -> np.ndarray:
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
    if spec["kind"] == "stone":
        bgr = cv2.imread(SRC % spec["src"])
        get = lambda r, c: cut_stone(bgr, r, c)
    else:
        grid = black_frames(np.array(Image.open(SRC % spec["src"]).convert("RGB")).astype(float))
        get = lambda r, c: grid[r][c]
    frames = {}
    for d in ("front", "back", "left", "right"):
        if d in spec:
            frames[d] = [trim(downscale(get(r, c), down)) for r, c in spec[d]]
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


if __name__ == "__main__":
    for n in (sys.argv[1:] or list(FRAMES)):
        build(n)
