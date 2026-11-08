#!/usr/bin/env python3
"""Cut the designer's sphere grid painting (2026-11-08) into the grid
screen's backdrop and its node icons.

The painting (assets/sprites/paintings/sphere_grid_board.webp, 1774x887)
is a whole sphere grid screen: an ornate gilt Celtic-knot frame with a
compass rose at its head and a triquetra at its foot, a raven-and-wolf
scene down the left, a castle-and-battle scene down the right, and in the
middle, on a dark green ground with faint gold filigree, a web of orbs and
gold plaques joined by thin silver lines.

Output, under assets/textures/sphere_grid/:
  - backdrop.webp: the painting with its node web painted out. The web —
    the silver lines, the orbs and plaques and their glow — is found by
    colour and shape (see web_mask) and filled from the ground round it:
    the smooth tone by a push-pull (pyramid) fill, the grain and the
    filigree's fine strokes laid back over it from clean ground nearby.
    The side scenes and the frame are untouched. The game draws its own
    web on top, so none of the painted one may show.
  - one PNG per node icon, each cut from the painting round the clearest
    example of it (centre and body radius measured on upscaled crops), its
    own glow kept: the body at full alpha inside a soft-edged circle or
    rounded square, the glow round it rebuilt from its radial profile
    measured on the painting (the silver lines that cross the glow are
    left out of the measure, so no line stubs are cut with it). Every
    icon's texture is exactly 3x its body radius across, centred on the
    body: SphereGridUI reads the body radius back as width / 3.
    Cut at the painting's resolution (a body radius of 9-23 texels); the
    game scales them smoothly (linear filtering, mipmaps).

Run: python3 tools/cut_sphere_grid_art.py [--debug <dir>]
"""
import argparse
import os

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/sphere_grid_board.webp"
OUT_DIR = "assets/textures/sphere_grid"

# The polygon the web lies in on the painting: round the outermost plaques
# with a margin, clear of the potions and book at the lower left and the
# mist and the wizard's cloak at the lower right. Nothing outside it is
# touched.
WEB_POLY = [(670, 24), (955, 26), (1135, 126), (1242, 298), (1242, 542), (1167, 612),
            (1130, 714), (948, 822), (678, 822), (490, 714), (464, 614), (384, 542),
            (384, 294), (486, 126)]
# Kept whole although inside the polygon: the frame's compass rose.
KEEP_CIRCLES = [((887, 20), 28)]

# The icons: (centre x, centre y, body radius, shape, glow). Centres and
# radii measured on 6x crops of the painting (the gold rim's outer edge for
# an orb; the frame's outer edge, half its width, for a plaque). `glow`
# says how far out (in body radii) the glow is measured and kept.
ICONS = {
    # The heart orb: a red heart in a ruby orb, brass rim.
    "orb_heart": (864.5, 236.0, 15.5, "circle", 1.5),
    # The mana drop: a pale blue drop in a sapphire orb.
    "orb_mana": (655.5, 423.5, 15.5, "circle", 1.5),
    # The star orb: a magenta star burst in a deep purple orb, brass rim.
    "orb_star": (553.5, 392.0, 15.5, "circle", 1.5),
    # The violet sparkle: a smaller, dark-rimmed orb with a violet star of
    # light on black (the painting's spokes off the centre's axis).
    "orb_sparkle": (812.5, 281.5, 13.5, "circle", 1.5),
    # Crossed swords: two pale swords crossed on a fiery orange orb.
    "orb_swords": (751.5, 133.0, 15.5, "circle", 1.5),
    # The sun orb: an orange orb bursting with a golden sun.
    "orb_sun": (551.5, 431.5, 16.5, "circle", 1.5),
    # The yellow orbs that ring the centre: plain polished gold.
    "orb_gold": (813.0, 372.5, 11.5, "circle", 1.5),
    # The small silver orbs: plain pewter bosses where lines meet.
    "orb_silver": (760.5, 237.0, 9.0, "circle", 1.5),
    # The centre: a cut emerald in a gilt ring, glowing green.
    "gem_centre": (813.5, 421.0, 23.5, "circle", 1.5),
    # The gold square plaques, the clearest of each kind: centre and half
    # size from the box round each frame's gold rows and columns. They have
    # no glow of their own (what lies round them is the neighbours' light).
    "plaque_sword": (516.0, 154.0, 17.0, "square", 1.0),
    "plaque_fist": (571.0, 164.5, 16.5, "square", 1.0),
    "plaque_sun": (812.5, 180.5, 16.0, "square", 1.0),
    "plaque_crossed": (1054.0, 322.5, 16.0, "square", 1.0),
    "plaque_knot": (623.0, 258.0, 16.5, "square", 1.0),
    "plaque_triquetra": (761.0, 601.5, 16.5, "square", 1.0),
}


def hsv_planes(img):
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV)
    return hsv[..., 0].astype(np.int32), hsv[..., 1].astype(np.int32), hsv[..., 2].astype(np.int32)


def disk(r):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))


def web_region(shape):
    """The polygon the web lies in (WEB_POLY), as a mask."""
    region = np.zeros(shape, np.uint8)
    cv2.fillPoly(region, [np.array(WEB_POLY, np.int32)], 1)
    return region


def web_mask(img):
    """The painted web: True where a silver line, a node or a node's glow
    lies, inside WEB_POLY. Lines are the pale, near-grey pixels (the
    filigree is gold, the ground dark). Nodes are the thick bright blobs:
    everything clearly lighter than the ground, opened so the thin lines
    and filigree strokes fall away from it, holes filled (the dark star
    orbs' black middles), a blob too small for a node (a filigree knot)
    dropped, and the rest grown over its rim's edge and glow."""
    _H, S, V = hsv_planes(img)
    region = web_region(V.shape)
    lines = ((S < 95) & (V > 64)).astype(np.uint8) & region
    lit = (V > 58).astype(np.uint8) & region
    blobs = cv2.morphologyEx(lit, cv2.MORPH_OPEN, disk(3))
    blobs = nd.binary_fill_holes(cv2.morphologyEx(blobs, cv2.MORPH_CLOSE, disk(3))).astype(np.uint8)
    # A node is at least 13 px both ways; the lines are the pale strokes
    # that run into a node. The filigree's brighter knots and flourishes
    # (some of their highlights near white) lie off the web.
    lab, n = nd.label(blobs)
    keep = np.zeros(n + 1, bool)
    for i, sl in enumerate(nd.find_objects(lab)):
        keep[i + 1] = min(sl[0].stop - sl[0].start, sl[1].stop - sl[1].start) >= 13
    blobs = keep[lab].astype(np.uint8)
    near_node = cv2.dilate(blobs, disk(4)).astype(bool)
    lab, n = nd.label(cv2.dilate(lines, disk(3)))
    hit = np.unique(lab[near_node & (lab > 0)])
    keep = np.zeros(n + 1, bool)
    keep[hit] = True
    lines = (keep[lab].astype(np.uint8) & lines)
    on_line = cv2.dilate(lines, disk(2)).astype(bool)
    lab, n = nd.label(blobs)
    hit = np.unique(lab[on_line & (lab > 0)])
    keep = np.zeros(n + 1, bool)
    keep[hit] = True
    blobs = keep[lab].astype(np.uint8)
    web = cv2.dilate(lines, disk(3)) | cv2.dilate(blobs, disk(9))
    # Grow a few pixels further into whatever is still lit round a node:
    # a plaque's lower bevel, a rim's highlight, the brighter glow.
    near = cv2.dilate(blobs, disk(16)) & (V > 40).astype(np.uint8)
    for _ in range(5):
        web = web | (cv2.dilate(web, disk(1)) & near)
    for (cx, cy), r in KEEP_CIRCLES:
        keep = np.zeros_like(web)
        cv2.circle(keep, (cx, cy), r, 1, -1)
        web = web & (1 - keep)
    return web.astype(bool) & region.astype(bool), blobs.astype(bool)


def push_pull(img, known):
    """Fill the unknown pixels smoothly from the known ones: average down a
    pyramid with the known mask as weights, then fill each level's holes
    from the level below."""
    levels = []
    cur = img.astype(np.float32) * known[..., None]
    wt = known.astype(np.float32)
    while min(cur.shape[:2]) > 4:
        levels.append((cur, wt))
        h, w = cur.shape[:2]
        cur = cv2.resize(cur, ((w + 1) // 2, (h + 1) // 2), interpolation=cv2.INTER_AREA)
        wt = cv2.resize(wt, ((w + 1) // 2, (h + 1) // 2), interpolation=cv2.INTER_AREA)
    filled = cur / np.maximum(wt, 1e-6)[..., None]
    for cur, wt in reversed(levels):
        h, w = cur.shape[:2]
        up = cv2.resize(filled, (w, h), interpolation=cv2.INTER_LINEAR)
        mean = cur / np.maximum(wt, 1e-6)[..., None]
        a = np.clip(wt, 0, 1)[..., None]
        filled = mean * a + up * (1 - a)
    return filled


def grain(img, known, sigma=2.5):
    """The fine detail of the known ground (the image less its masked blur)."""
    f = img.astype(np.float32)
    k = known.astype(np.float32)
    blur = cv2.GaussianBlur(f * k[..., None], (0, 0), sigma)
    wb = cv2.GaussianBlur(k, (0, 0), sigma)
    return (f - blur / np.maximum(wb, 1e-6)[..., None]) * k[..., None]


def lay_grain(fill, detail, known, hole):
    """Lay the ground's grain over the smooth fill: each hole pixel takes the
    detail of the nearest clean pixel along one of a few offsets (tried in
    turn), so the patch carries the ground's mottle and filigree strokes."""
    out = fill.copy()
    todo = hole.copy()
    h, w = hole.shape
    offsets = [(0, 46), (0, -46), (46, 0), (-46, 0), (33, 33), (-33, -33), (33, -33), (-33, 33),
               (0, 80), (0, -80), (80, 0), (-80, 0), (60, 60), (-60, -60), (60, -60), (-60, 60)]
    ys, xs = np.nonzero(todo)
    for dy, dx in offsets:
        if len(ys) == 0:
            break
        sy, sx = ys + dy, xs + dx
        ok = (sy >= 0) & (sy < h) & (sx >= 0) & (sx < w)
        ok[ok] &= known[sy[ok], sx[ok]]
        out[ys[ok], xs[ok]] += detail[sy[ok], sx[ok]]
        ys, xs = ys[~ok], xs[~ok]
    return out


def backdrop(img, debug=None):
    web, nodes = web_mask(img)
    known = ~web
    # The smooth fill, in Lab: its lightness from the ground right at the
    # hole's edge (so the patch meets it without a step), its colour from
    # the ground at large (so the faint glow still tinting an edge — red by
    # a heart, violet by a star — does not bleed in as a blotch).
    lab = cv2.cvtColor(img, cv2.COLOR_RGB2LAB).astype(np.float32)
    near = push_pull(lab, known)
    wide = cv2.GaussianBlur(lab * known[..., None], (0, 0), 40)
    wide /= np.maximum(cv2.GaussianBlur(known.astype(np.float32), (0, 0), 40), 1e-6)[..., None]
    fill_lab = np.dstack([near[..., 0], wide[..., 1], wide[..., 2]])
    fill = cv2.cvtColor(np.clip(fill_lab, 0, 255).astype(np.uint8), cv2.COLOR_LAB2RGB).astype(np.float32)
    # The grain is taken only from ground well clear of the web (a hole's
    # rim still carries the edge of a line or a glow, which would copy in
    # as bright stitches), and damped: the filigree's strokes are what it
    # carries brightest, and a copied stroke must read fainter than the
    # painting's own.
    clear = ~cv2.dilate(web.astype(np.uint8), disk(4)).astype(bool)
    detail = grain(img, clear)
    detail = np.clip(detail, -18, 18) * 0.6
    out = lay_grain(fill, detail, clear, web)
    out = np.where(web[..., None], out, img.astype(np.float32))
    # Feather the seam a pixel into the painting.
    edge = cv2.dilate(web.astype(np.uint8), disk(1)).astype(bool) & ~web
    soft = cv2.GaussianBlur(out, (0, 0), 0.8)
    out[edge] = soft[edge]
    out = np.clip(out, 0, 255).astype(np.uint8)
    if debug:
        vis = img.copy()
        vis[web] = (vis[web] * 0.4 + np.array([255, 0, 255]) * 0.6).astype(np.uint8)
        Image.fromarray(vis).save(os.path.join(debug, "web_mask.png"))
    return out


def radial_glow(img, ground, cx, cy, r, reach, lines):
    """The glow round a body: per ring of radius (r, r*reach], the median
    over the ring of how much the painting outshines the cleaned ground
    there (line pixels left out), and the median colour of that excess."""
    h, w = img.shape[:2]
    R = int(np.ceil(r * reach)) + 2
    yy, xx = np.mgrid[-R:R + 1, -R:R + 1]
    x0, y0 = int(round(cx)) - R, int(round(cy)) - R
    patch = img[y0:y0 + 2 * R + 1, x0:x0 + 2 * R + 1].astype(np.float32)
    gpatch = ground[y0:y0 + 2 * R + 1, x0:x0 + 2 * R + 1].astype(np.float32)
    lpatch = lines[y0:y0 + 2 * R + 1, x0:x0 + 2 * R + 1]
    dist = np.sqrt((xx + x0 - cx) ** 2 + (yy + y0 - cy) ** 2)
    excess = patch - gpatch
    prof = []
    for k in np.arange(np.floor(r) + 1, np.ceil(r * reach) + 1):
        ring = (dist >= k - 0.5) & (dist < k + 0.5) & ~lpatch
        if ring.sum() < 6:
            prof.append((k, np.zeros(3)))
            continue
        prof.append((k, np.median(excess[ring], axis=0)))
    return prof


def cut_icon(img, ground, lines, name, spec):
    cx, cy, r, shape, reach = spec
    size = int(round(3 * r))
    half = size / 2.0
    # Sub-pixel shift: the body's centre lands on the texture's centre.
    m = np.float32([[1, 0, half - cx - 0.5], [0, 1, half - cy - 0.5]])
    body = cv2.warpAffine(img, m, (size, size), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)
    yy, xx = np.mgrid[0:size, 0:size] + 0.5
    dx, dy = xx - half, yy - half
    if shape == "circle":
        d = np.sqrt(dx ** 2 + dy ** 2)
    else:
        # A rounded square: the plaque's corners are rounded a few texels.
        cr = r * 0.22
        qx, qy = np.maximum(np.abs(dx) - (r - cr), 0), np.maximum(np.abs(dy) - (r - cr), 0)
        inner = np.minimum(np.maximum(np.abs(dx), np.abs(dy)) - (r - cr), 0)
        d = np.sqrt(qx ** 2 + qy ** 2) + inner + (r - cr)
    a_body = np.clip(r + 0.5 - d, 0, 1)

    # The glow, rebuilt from its measured radial profile.
    a_glow = np.zeros_like(d)
    colour = np.zeros(3)
    prof = radial_glow(img, ground, cx, cy, r, reach, lines) if reach > 1.0 else []
    if prof:
        excess = np.array([p[1] for p in prof])
        pos = np.clip(excess, 0, None)
        amount = pos.max(axis=1)                       # per ring, how strong
        colour = pos.sum(axis=0)
        colour = colour / max(colour.max(), 1e-6) * 255.0
        ks = np.array([p[0] for p in prof])
        a_glow = np.interp(d, ks, amount / 255.0 * 1.6, left=0, right=0)
        a_glow *= np.clip((r * reach - d) / (r * 0.25), 0, 1)
        a_glow = np.clip(a_glow, 0, 0.85) * (d > r - 0.5)
    alpha = np.maximum(a_body, a_glow)
    rgb = body.astype(np.float32) * a_body[..., None] + colour[None, None, :] * (a_glow * (1 - a_body))[..., None]
    rgb = rgb / np.maximum(alpha, 1e-6)[..., None]
    rgba = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT_DIR, name + ".png"))
    print("%s: %dx%d (body radius %.1f)" % (name, size, size, r))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--debug", default=None, help="save the web mask overlay here")
    args = ap.parse_args()
    os.makedirs(OUT_DIR, exist_ok=True)
    img = np.asarray(Image.open(SRC).convert("RGB"))
    ground = backdrop(img, args.debug)
    Image.fromarray(ground).save(os.path.join(OUT_DIR, "backdrop.webp"), quality=94, method=6)
    print("backdrop: %dx%d" % (ground.shape[1], ground.shape[0]))
    _H, S, V = hsv_planes(img)
    lines = (S < 95) & (V > 72)
    for name, spec in ICONS.items():
        cut_icon(img, ground, lines, name, spec)


if __name__ == "__main__":
    main()
