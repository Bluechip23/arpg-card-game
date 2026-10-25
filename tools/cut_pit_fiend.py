#!/usr/bin/env python3
"""Cut the designer's Pit Fiend out of its action board.

Source: assets/sprites/paintings/pit_fiend_sheet.jpg (1408x768, .gdignore'd
source art): facing stills, walk cycles, flight, jump, dash, tail sweep and
wing shield on slate panels. The board's labels are unreliable (its "WEST"
still faces right, its "EAST" still faces left), so frames are picked by
what they show. Used here:
  Idle   — front (the flaming sword), back, left-facing, right-facing stills
  Walk   — the right-facing and left-facing walk cycles (side views only, so
           walking north / south shows the left-facing walk)
  Attack — the tail sweep (faces right; mirrored for left)
Flight, jump, dash and wing shield are left on the board: the Pit Fiend
does none of them in the game.

Per frame the slate panel is flood-filled away from the cell border (JPEG,
so a wide tolerance; the fiend is red and black, nowhere near the slate),
specks are dropped, it is box-filtered DOWN x with on/off alpha and packed
bottom-centred into square cells in the Craftpix layout SpriteEnemyFigure
plays (rows front, back, left, right).
Output: assets/sprites/generated/bosses/pit_fiend/{Idle,Walk,Attack}.png
Run: python3 tools/cut_pit_fiend.py   (numpy + Pillow)
"""
import os
from collections import deque

import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/pit_fiend_sheet.jpg"
OUT = "assets/sprites/generated/bosses/pit_fiend"
DOWN = 1   # was 2, drawn x1.3 up: now the source's own pixels, x0.65 (2026-10-25: ~49 texels a tile — the most the board holds)
BG_TOL = 34.0
INSET = 4

IDLE = {
    "front": (173, 66, 350, 160),
    "back": (8, 66, 168, 160),
    "left": (525, 66, 695, 160),    # labelled EAST on the board
    "right": (355, 66, 520, 160),   # labelled WEST on the board
}
WALK_RIGHT = [(12, 302, 95, 393), (98, 302, 180, 393), (183, 302, 265, 393), (268, 302, 350, 393)]
WALK_LEFT = [(366, 417, 448, 507), (451, 417, 530, 507), (533, 417, 612, 507), (615, 417, 695, 507)]
TAIL_SWEEP_RIGHT = [(716, 668, 810, 756), (815, 668, 910, 756), (913, 668, 1008, 756)]


def cut(img: np.ndarray, box) -> np.ndarray:
    x0, y0, x1, y1 = box
    cell = img[y0 + INSET:y1 - INSET, x0 + INSET:x1 - INSET].astype(float)
    h, w, _ = cell.shape
    border = np.concatenate([cell[0], cell[-1], cell[:, 0], cell[:, -1]])
    bg = np.median(border, axis=0)
    near = np.sqrt(((cell - bg) ** 2).sum(-1)) < BG_TOL
    panel = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x]:
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
    # Slate walled in between wing, leg and tail: the fiend is red and black
    # with nothing blue-grey on it, so every blue-leaning slate pixel goes.
    blueish = cell[..., 2] > cell[..., 0] + 12
    panel |= near & blueish
    fg = ~panel
    # Drop specks: keep pieces at least 3% of the largest (the sword's flame
    # and a raised claw can be their own pieces).
    labels = np.zeros((h, w), int)
    sizes = [0]
    n = 0
    for sy in range(h):
        for sx in range(w):
            if fg[sy, sx] and labels[sy, sx] == 0:
                n += 1
                count = 0
                q = deque([(sy, sx)])
                labels[sy, sx] = n
                while q:
                    y, x = q.popleft()
                    count += 1
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and labels[ny, nx] == 0:
                            labels[ny, nx] = n
                            q.append((ny, nx))
                sizes.append(count)
    if n:
        biggest = max(sizes)
        keep = {i for i in range(1, n + 1) if sizes[i] >= biggest * 0.03}
        fg = np.isin(labels, list(keep))
    rgba = np.zeros((h, w, 4), float)
    rgba[..., :3] = cell
    rgba[..., 3] = fg.astype(float)
    return rgba


def downscale(rgba: np.ndarray) -> np.ndarray:
    if DOWN != int(DOWN):
        # Premultiplied box resample by a fractional factor, then on/off alpha.
        img = Image.fromarray(np.dstack([np.clip(rgba[..., :3], 0, 255),
                                         np.clip(rgba[..., 3:4] * 255, 0, 255)]).astype(np.uint8), "RGBA")
        size = (max(1, round(img.width / DOWN)), max(1, round(img.height / DOWN)))
        small = np.asarray(img.convert("RGBa").resize(size, Image.BOX).convert("RGBA")).copy()
        small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
        return small
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


def frame(img, box) -> np.ndarray:
    return trim(downscale(cut(img, box)))


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


def main() -> None:
    img = np.array(Image.open(SRC).convert("RGB"))
    idle = {k: frame(img, b) for k, b in IDLE.items()}
    walk_r = [frame(img, b) for b in WALK_RIGHT]
    walk_l = [frame(img, b) for b in WALK_LEFT]
    sweep_r = [frame(img, b) for b in TAIL_SWEEP_RIGHT]
    sweep_l = [f[:, ::-1] for f in sweep_r]
    sets = {
        "Idle": [[idle["front"]], [idle["back"]], [idle["left"]], [idle["right"]]],
        "Walk": [walk_l, walk_l, walk_l, walk_r],
        "Attack": [sweep_l, sweep_l, sweep_l, sweep_r],
    }
    cell = max(max(f.shape[0], f.shape[1]) for rows in sets.values() for row in rows for f in row) + 2
    os.makedirs(OUT, exist_ok=True)
    for name, rows in sets.items():
        pack(rows, cell, max(len(r) for r in rows)).save(os.path.join(OUT, name + ".png"))
    print("pit_fiend: cell %d px -> %s (Idle, Walk, Attack)" % (cell, OUT))


if __name__ == "__main__":
    main()
