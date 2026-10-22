#!/usr/bin/env python3
"""Cut the designer's boss sprite sheets into the game's directional sheets.

Sources (assets/sprites/paintings/, a .gdignore'd folder, not game assets):
  rat_king_sheet.webp, cerberus_sheet.webp, hades_sheet.webp,
  corrupted_archangel_sheet.webp
Each is a ~1125x610 board of frames on a flat slate panel colour, three rows
of cells. Their printed labels are unreliable, so FRAMES below picks each
direction's frames by what the frame shows (front = facing the camera,
back, and one side — the other side is the mirror).

Per frame: the panel colour is flood-filled away from the cell border (a
colour test alone would eat the dark fur), the cut-out is box-filtered down
DOWN x (the art's pixel blocks are 2-3 source pixels, so this lands on the
game's texel density), alpha is snapped to on/off for crisp pixel edges,
and every frame is placed bottom-centred in one square cell.

Output: assets/sprites/generated/bosses/<boss>/Idle.png and Walk.png in the
Craftpix layout SpriteEnemyFigure already plays (four direction rows, front,
back, left, right top to bottom; frames left to right).
Run: python3 tools/cut_boss_sheets.py
"""
import os
from collections import deque

import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/%s_sheet.webp"
OUT = "assets/sprites/generated/bosses/%s"
DOWN = 3
BG_TOL = 14.0   # RGB distance from the panel colour that still counts as panel
INSET = 3       # trim each cell's edge (the panel border line)

# Cell boxes (x0, x1) per row, and the rows' (y0, y1): same board on all three.
ROWS_X = [
    [(46, 215), (219, 389), (395, 578), (583, 765), (770, 945)],
    [(46, 215), (219, 389), (395, 565), (598, 768), (772, 945), (950, 1120)],
    [(46, 215), (219, 389), (395, 565)],
]
ROWS_Y = [(52, 218), (243, 411), (434, 604)]

# Per boss: frames (row, col) per direction. "side" frames face `side_faces`;
# the opposite side is their mirror. Idle is each direction's first frame.
FRAMES = {
    "rat_king": {
        "front": [(0, 0), (0, 1), (2, 0), (2, 1)],
        "back": [(0, 4), (2, 2)],
        "side": [(1, 2), (1, 1), (1, 5)],   # (1, 4) has a doubled crown: skipped
        "side_faces": "right",
    },
    "cerberus": {
        "front": [(0, 0), (0, 1), (2, 0), (2, 1)],
        "back": [(0, 4)],
        "side": [(1, 2), (1, 1), (1, 4), (1, 5)],
        "side_faces": "right",
    },
    "hades": {
        "front": [(0, 0), (2, 0), (2, 1)],
        "back": [(0, 4), (0, 1), (2, 2)],
        "side": [(1, 0), (1, 1), (1, 2), (1, 3), (1, 4), (1, 5)],
        "side_faces": "left",
    },
    # The board mixes feathered and bat wings; the feathered frames are used
    # throughout so the walk never swaps wings mid-step. The bat-winged ones
    # (back (0, 2), (0, 4); side (1, 2)-(1, 5)) are left for a corrupted phase.
    "corrupted_archangel": {
        "front": [(0, 0), (2, 0), (2, 1)],
        "back": [(0, 1)],
        "side": [(1, 0), (1, 1)],
        "side_faces": "right",
    },
}


def cut_cell(img: np.ndarray, r: int, c: int) -> np.ndarray:
    x0, x1 = ROWS_X[r][c]
    y0, y1 = ROWS_Y[r]
    cell = img[y0 + INSET:y1 - INSET, x0 + INSET:x1 - INSET].astype(float)
    h, w, _ = cell.shape
    border = np.concatenate([cell[0], cell[-1], cell[:, 0], cell[:, -1]])
    bg = np.median(border, axis=0)
    near = np.sqrt(((cell - bg) ** 2).sum(-1)) < BG_TOL
    panel = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not panel[y, x]:
                panel[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not panel[y, x]:
                panel[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and near[ny, nx] and not panel[ny, nx]:
                panel[ny, nx] = True
                q.append((ny, nx))
    rgba = np.zeros((h, w, 4), float)
    rgba[..., :3] = cell
    rgba[..., 3] = (~panel).astype(float)
    return rgba


def downscale(rgba: np.ndarray) -> np.ndarray:
    h, w, _ = rgba.shape
    h2, w2 = h // DOWN, w // DOWN
    a = rgba[:h2 * DOWN, :w2 * DOWN].reshape(h2, DOWN, w2, DOWN, 4)
    cover = a[..., 3].sum((1, 3))
    rgb = (a[..., :3] * a[..., 3:4]).sum((1, 3)) / np.maximum(cover, 1e-6)[..., None]
    out = np.zeros((h2, w2, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(cover / (DOWN * DOWN) >= 0.5, 255, 0)
    return out


def trim(fr: np.ndarray) -> np.ndarray:
    ys, xs = np.where(fr[..., 3] > 0)
    return fr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def build(boss: str) -> None:
    spec = FRAMES[boss]
    img = np.array(Image.open(SRC % boss).convert("RGB"))
    frames = {}
    for d in ("front", "back", "side"):
        frames[d] = [trim(downscale(cut_cell(img, r, c))) for r, c in spec[d]]
    if spec["side_faces"] == "right":
        right = frames["side"]
        left = [f[:, ::-1] for f in right]
    else:
        left = frames["side"]
        right = [f[:, ::-1] for f in left]
    dirs = [frames["front"], frames["back"], left, right]  # F, B, L, R rows
    cell = max(max(max(f.shape[0], f.shape[1]) for f in row) for row in dirs) + 2
    n = max(len(row) for row in dirs)
    out_dir = OUT % boss
    os.makedirs(out_dir, exist_ok=True)

    def sheet(cols: int, pick) -> Image.Image:
        s = np.zeros((cell * 4, cell * cols, 4), np.uint8)
        for ri, row in enumerate(dirs):
            for ci in range(cols):
                f = pick(row, ci)
                fh, fw = f.shape[:2]
                y = ri * cell + cell - 1 - fh   # feet on the cell's bottom row (one row of air)
                x = ci * cell + (cell - fw) // 2
                s[y:y + fh, x:x + fw] = f
        return Image.fromarray(s, "RGBA")

    sheet(1, lambda row, ci: row[0]).save(os.path.join(out_dir, "Idle.png"))
    # Rows with fewer frames repeat theirs to fill the walk cycle.
    sheet(n, lambda row, ci: row[ci % len(row)]).save(os.path.join(out_dir, "Walk.png"))
    print("%s: cell %d px, %d walk frames -> %s" % (boss, cell, n, out_dir))


if __name__ == "__main__":
    for b in FRAMES:
        build(b)
