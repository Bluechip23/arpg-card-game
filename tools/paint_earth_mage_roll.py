#!/usr/bin/env python3
"""Carry the Earth Mage's neck roll into the views that lack it.

The designer's druid board (2026-10-27, earth_mage_druid_source.png) shows a
roll of intertwined branches round the back of his neck only in the front
view: two bands of thin twisting strands come forward over his shoulders and
it never crosses the throat. The designer asked for it in every view, round
the back of the neck and not the front: across the nape in the back view,
and from behind the neck down over the near shoulder in each side view.

Not drawn from scratch: the front view's own left band is lifted as a strip
(straightened along its centre line) and laid along each new path — the same
branches, bent to the new curve, repeated mirror-wise where the path is
longer than the strip. 4x supersampled; the board's black between the
strands stays see-through. Writes earth_mage_druid_board.png, which
tools/cut_pose_boards.py cuts.

Run: python3 tools/paint_earth_mage_roll.py
"""
import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/earth_mage_druid_source.png"
OUT = "assets/sprites/paintings/earth_mage_druid_board.png"
SS = 4             # supersampling
SRC_HALF = 3.6     # half the source band's width, board pixels
HALF = 6.0         # half the laid band's width: thicker than the source (designer,
                   # 2026-10-27: "quite a bit thicker"), its strands stretched to fit
BACKDROP = 26      # the board's black: at or under this a sample is not branch
GAP = np.array([0x3a, 0x24, 0x1a], float)   # the dark bark between the strands

# The front view's left band: its centre line, top (behind the neck) first.
SOURCE_BAND = [(89.0, 64.5), (86.6, 71.0), (84.0, 77.0), (80.8, 83.5)]

# Where it goes, per view (board pixels, the board is 560x280), each path
# starting behind the neck like the source band does.
PATHS = {
    "back_left": [(220, 68), (209, 69.5), (201, 72.5), (195, 77)],
    "back_right": [(220, 68), (231, 69.5), (239, 72.5), (245, 77)],
    "left": [(405.5, 63), (404, 68.5), (399, 74), (392.5, 78)],    # faces left
    "right": [(500, 63), (501.5, 68.5), (506.5, 74), (513, 78)],   # faces right
}
LANES = 2          # copies of the source band laid side by side across the width


def _spline(pts, n=300):
    """Catmull-Rom through the points (ends clamped), with arc length."""
    p = [np.array(pts[0], float)] + [np.array(q, float) for q in pts] + [np.array(pts[-1], float)]
    out = []
    per = max(2, n // (len(p) - 3))
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for t in np.linspace(0, 1, per, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(p[-2])
    c = np.array(out)
    arc = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(c, axis=0), axis=1))])
    return c, arc


def _frame(c, arc, s):
    """Point and unit normal on curve `c` at arc length `s` (arrays)."""
    s = np.clip(s, 0, arc[-1])
    i = np.clip(np.searchsorted(arc, s) - 1, 0, len(c) - 2)
    t = (s - arc[i]) / np.maximum(arc[i + 1] - arc[i], 1e-9)
    p = c[i] + (c[i + 1] - c[i]) * t[:, None]
    tan = c[i + 1] - c[i]
    tan /= np.maximum(np.linalg.norm(tan, axis=1, keepdims=True), 1e-9)
    nrm = np.stack([-tan[:, 1], tan[:, 0]], 1)
    return p, nrm


def _bilinear(img, x, y):
    h, w, _ = img.shape
    x = np.clip(x, 0, w - 1.001)
    y = np.clip(y, 0, h - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy)
            + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)


def lay_band(board, src, path):
    """The source band laid along `path`: an RGBA layer (premultiplied)."""
    h, w, _ = board.shape
    sc, sarc = _spline(SOURCE_BAND)
    tc, tarc = _spline(path)
    L = sarc[-1]
    x0, y0 = (tc.min(axis=0) - HALF - 2).astype(int)
    x1, y1 = (tc.max(axis=0) + HALF + 2).astype(int) + 1
    x0, y0, x1, y1 = max(0, x0), max(0, y0), min(w, x1), min(h, y1)
    ys, xs = np.mgrid[y0 * SS:y1 * SS, x0 * SS:x1 * SS]
    P = np.stack([(xs + 0.5) / SS, (ys + 0.5) / SS], -1).reshape(-1, 2)
    # Nearest point on the target path: arc length and signed offset.
    best_d = np.full(len(P), np.inf)
    best_s = np.zeros(len(P))
    best_o = np.zeros(len(P))
    for i in range(len(tc) - 1):
        a, v = tc[i], tc[i + 1] - tc[i]
        L2 = max(v @ v, 1e-12)
        t = np.clip(((P - a) @ v) / L2, 0, 1)
        q = a + t[:, None] * v
        d = np.linalg.norm(P - q, axis=1)
        better = d < best_d
        best_d[better] = d[better]
        best_s[better] = tarc[i] + t[better] * np.sqrt(L2)
        cross = v[0] * (P[:, 1] - a[1]) - v[1] * (P[:, 0] - a[0])
        best_o[better] = np.sign(cross[better]) * d[better]
    inside = best_d <= HALF
    # Along the strip: mirrored repeats past its length (no seam jump).
    m = np.mod(best_s, 2 * L)
    s_src = np.where(m > L, 2 * L - m, m)
    p, nrm = _frame(sc, sarc, s_src)
    # Two lanes of the real strands side by side (not one band stretched: the
    # strands stay as thin as the front's), each lane offset along the path
    # and the second mirrored, so they twist past one another.
    lane_w = 2 * HALF / LANES
    across = np.clip(best_o + HALF, 0, 2 * HALF - 1e-6)
    lane = np.floor(across / lane_w)
    local = (across - lane * lane_w) - lane_w / 2          # -lane_w/2 .. lane_w/2
    m2 = np.mod(best_s + lane * L * 0.43, 2 * L)
    s_lane = np.where(m2 > L, 2 * L - m2, m2)
    off = local * (SRC_HALF / (lane_w / 2)) * np.where(lane % 2 == 1, -1, 1)
    p, nrm = _frame(sc, sarc, s_lane)
    xy = p + nrm * off[:, None]
    col = _bilinear(src, xy[:, 0], xy[:, 1])
    lum = col.max(axis=1)
    # Solid: the board's black between the strands becomes dark bark, so the
    # hood doesn't show through and the roll reads as one thick bundle.
    k = np.clip((lum - BACKDROP) / 18.0, 0, 1)[:, None]
    col = col * k + GAP * (1 - k)
    a = inside * np.clip((HALF - best_d) / 0.8, 0, 1)
    # Soft round ends where the path starts and stops.
    a *= np.clip((tarc[-1] - best_s) / 1.5 + 0.5, 0, 1)
    layer = np.zeros(((y1 - y0) * SS * (x1 - x0) * SS, 4))
    layer[:, :3] = col * a[:, None]
    layer[:, 3] = a
    layer = layer.reshape((y1 - y0), SS, (x1 - x0), SS, 4).mean(axis=(1, 3))
    full = np.zeros((h, w, 4))
    full[y0:y1, x0:x1] = layer
    return full


def main():
    src = np.asarray(Image.open(SRC).convert("RGB")).astype(float)
    board = src.copy()
    for path in PATHS.values():
        lay = lay_band(board, src, path)
        board = board * (1 - lay[..., 3:4]) + lay[..., :3]
    Image.fromarray(np.clip(board, 0, 255).round().astype(np.uint8)).save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
