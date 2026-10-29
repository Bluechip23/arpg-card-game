#!/usr/bin/env python3
"""Cut the designer's in-game HUD boards (2026-10-29) into the pieces the
battle HUD draws, at their on-screen size (no runtime scaling: crisp).

hud_bars_board.webp — the top-left stat block, painted over the forest
floor: a vine-wrapped health bar, the slate unerring-armor bar with blue
gems, the crystal-ended mana bar, the leather carry bar with its backpack,
the gold XP track, the armor shield badge, the blue mana-regen flame and
the level's gold diamonds. The board shows sample numbers, so:
  * each bar becomes a FRAME (the bar with its fill cut out — the health
    bar's vines that drape over the red are kept), a FILL and an UNDER
    (the empty track) for a TextureProgressBar, the painted text painted
    out (cv2 inpaint);
  * the shield and the flame lose their painted number (the HUD writes the
    live one).
The forest floor is the board's background: it is cleared by flood fill
from the board's edge over its dark greens (the art's near-black outlines
stop it).

hud_actions_board.webp — the bottom-left action panel on the same floor:
mossy stone frames round the draw pile, its info button, the flash row
(bolt and count; boots, sidestep, quick hands), the brain row (heart and
count; eye, card+), auto attack and raise shield, wait, and the discard
pile. Each frame becomes a button face (its icon kept, its painted
numbers painted out); the wide frames also give a nine-patch for any
width.

Output: assets/textures/ui/hud/*.png, and the layout (px, at output scale)
printed for scripts/core/main.gd.
Run: python3 tools/cut_hud_panels.py
"""
import os

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/%s"
OUT = "assets/textures/ui/hud/%s.png"
BARS_K = 0.19      # bars board px -> screen px
ACT_K = 0.20       # actions board px -> screen px


def load(name):
    return np.asarray(Image.open(SRC % name).convert("RGB")).astype(np.uint8)


def foreground(rgb):
    """True where the art is: everything but the forest floor reached from
    the board's edge (dark, green-leaning, not the near-black outline)."""
    a = rgb.astype(int)
    mx = a.max(axis=2)
    floor = (mx >= 13) & (mx <= 72) & (a[..., 1] >= a[..., 0] - 4)
    lab, _ = nd.label(floor)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = ~np.isin(lab, list(edge))
    lab, n = nd.label(fg)
    if n:
        sizes = nd.sum(fg, lab, range(1, n + 1))
        fg = np.isin(lab, 1 + np.nonzero(sizes >= 60)[0])
    # The art's darker greys (frame shadows) can read as floor: close the
    # small bites and fill what the outline encloses.
    return nd.binary_fill_holes(nd.binary_closing(fg, iterations=3))


def text_mask(rgb, box, dark=70, light=150):
    """The painted lettering inside `box` (board px): its pale strokes and
    their black outline, grown a little so the inpaint takes the fringe."""
    m = np.zeros(rgb.shape[:2], bool)
    x0, y0, x1, y1 = box
    sub = rgb[y0:y1, x0:x1].astype(int)
    pale = (sub.min(axis=2) >= light)
    blk = sub.max(axis=2) <= dark
    t = pale | (blk & nd.binary_dilation(pale, iterations=8))
    m[y0:y1, x0:x1] = nd.binary_dilation(t, iterations=4)
    return m


def inpaint(rgb, mask):
    if not mask.any():
        return rgb
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    out = cv2.inpaint(bgr, mask.astype(np.uint8) * 255, 9, cv2.INPAINT_TELEA)
    return cv2.cvtColor(out, cv2.COLOR_BGR2RGB)


def shrink(img, k=None, size=None):
    """Lanczos on premultiplied colour, then a hard alpha (pixel art)."""
    im = Image.fromarray(img, "RGBA" if img.shape[2] == 4 else "RGB")
    if size is None:
        size = (max(1, round(im.width * k)), max(1, round(im.height * k)))
    if im.mode == "RGBA":
        out = np.asarray(im.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")).copy()
        out[..., 3] = np.where(out[..., 3] >= 128, 255, 0)
        out[out[..., 3] == 0, :3] = 0
        return Image.fromarray(out, "RGBA")
    return im.resize(size, Image.LANCZOS)


def save(img, name):
    img.save(OUT % name)
    return img


# --- The stat block --------------------------------------------------------
# name: frame box, interior (fill) box, text box, under/fill recipe
BARS = {
    "hp":       {"frame": (40, 60, 1650, 252), "fill": (200, 124, 1530, 211), "text": (680, 128, 1100, 215), "fill_from": "board", "under": "dark"},
    "unerring": {"frame": (100, 236, 1600, 346), "fill": (160, 251, 1540, 331), "text": (800, 262, 940, 325), "fill_from": "silver", "under": "board"},
    "mana":     {"frame": (25, 336, 1645, 494), "fill": (200, 380, 1525, 464), "text": (780, 390, 970, 455), "fill_from": "board", "under": "dark"},
    "carry":    {"frame": (55, 492, 1575, 608), "fill": (200, 520, 1505, 586), "text": (730, 528, 1020, 585), "fill_from": "leather", "under": "board"},
    "xp":       {"frame": (148, 610, 1600, 668), "fill": (200, 625, 1565, 652), "text": None, "fill_from": "xp", "under": "xp"},
}
# Within the health bar's red, the vines and leaves that drape over it stay
# in the frame; the red and the lettering go.
def _health_keep(sub):
    a = sub.astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    leaf = (g > r + 15) & (g > 70)
    vine = (r > 70) & (r < 210) & (g > 45) & (g > b + 10) & (r - g < 75) & ~((r > g + 60))
    keep = leaf | vine
    keep = nd.binary_closing(keep, iterations=2)
    dark = a.max(axis=2) <= 45
    keep |= dark & nd.binary_dilation(keep, iterations=3)
    lab, n = nd.label(keep)
    if n:
        sizes = nd.sum(keep, lab, range(1, n + 1))
        keep = np.isin(lab, 1 + np.nonzero(sizes >= 40)[0])
    return keep


def recolour(rgb, tint, gain):
    """The track's own texture under a new colour (its luminance kept)."""
    lum = rgb.astype(float).mean(axis=2, keepdims=True) / 255.0
    lum = lum / max(1e-3, lum.mean())
    return np.clip(lum * np.array(tint) * 255.0 * gain, 0, 255).astype(np.uint8)


def cut_bars():
    rgb = load("hud_bars_board.webp")
    fg = foreground(rgb)
    layout = {}
    for name, spec in BARS.items():
        fx0, fy0, fx1, fy1 = spec["frame"]
        ix0, iy0, ix1, iy1 = spec["fill"]
        clean = rgb
        if spec["text"]:
            clean = inpaint(rgb, text_mask(rgb, spec["text"]))
        if name == "hp":
            keep = np.zeros(rgb.shape[:2], bool)
            keep[iy0:iy1, ix0:ix1] = _health_keep(rgb[iy0:iy1, ix0:ix1])
            vines = keep & ~text_mask(rgb, spec["text"])
            clean = inpaint(clean, nd.binary_dilation(vines, iterations=2))
        # Frame: the art, the interior cleared (but the health vines).
        alpha = fg.copy()
        # The bar's own body (its interior and its rim) is all art.
        alpha[iy0 - 14:iy1 + 14, ix0 - 6:ix1 + 6] = True
        hole = np.zeros_like(alpha)
        hole[iy0:iy1, ix0:ix1] = True
        if name == "hp":
            hole &= ~vines
        alpha &= ~hole
        frame = np.dstack([rgb, alpha * 255]).astype(np.uint8)[fy0:fy1, fx0:fx1]
        fr = save(shrink(frame, BARS_K), "bar_%s_frame" % name)
        track = clean[iy0:iy1, ix0:ix1].copy()
        if spec["text"]:
            # Over the lettering, a clean stretch of the same bar beside it
            # (the inpaint alone leaves a ghost on the patterned fills).
            tx0, tx1 = spec["text"][0] - ix0, spec["text"][2] - ix0
            wdt = tx1 - tx0
            src = tx1 + 30 if tx1 + 30 + wdt <= track.shape[1] else max(0, tx0 - 30 - wdt)
            band = track[:, src:src + wdt].copy()
            # Feather the seams over a few columns so the copy doesn't edge.
            f = 12
            ramp = np.ones(wdt)
            ramp[:f] = np.linspace(0, 1, f)
            ramp[-f:] = np.linspace(1, 0, f)
            r = ramp[None, :, None]
            track[:, tx0:tx1] = (band * r + track[:, tx0:tx1] * (1 - r)).astype(np.uint8)
        w = round((ix1 - ix0) * BARS_K)
        h = round((iy1 - iy0) * BARS_K)
        if spec["fill_from"] == "board":
            fill = track
        elif spec["fill_from"] == "silver":
            fill = recolour(track, (0.62, 0.70, 0.86), 1.0)
        elif spec["fill_from"] == "leather":
            fill = recolour(track, (0.62, 0.44, 0.24), 1.0)
        else:   # xp: the painted gold, stretched along the whole track
            fill = rgb[iy0:iy1, 330:700]
        if spec["under"] == "dark":
            under = (track.astype(float) * np.array([0.22, 0.22, 0.26])).astype(np.uint8)
        elif spec["under"] == "xp":
            under = rgb[iy0:iy1, 760:1540]
        else:
            under = track
        save(shrink(np.ascontiguousarray(fill), size=(w, h)), "bar_%s_fill" % name)
        save(shrink(np.ascontiguousarray(under), size=(w, h)), "bar_%s_under" % name)
        layout[name] = {"frame": (round(fx0 * BARS_K), round(fy0 * BARS_K), fr.width, fr.height),
                        "fill": (round(ix0 * BARS_K), round(iy0 * BARS_K), w, h)}

    # The shield badge and the regen flame, their numbers painted out.
    for name, box, numbox, fill_with in [("armor_shield", (1678, 82, 1962, 352), (1772, 180, 1852, 272), None),
                                         ("mana_flame", (1745, 368, 1905, 548), (1790, 440, 1862, 530), None)]:
        x0, y0, x1, y1 = box
        nx0, ny0, nx1, ny1 = numbox
        m = np.zeros(rgb.shape[:2], bool)
        m[ny0:ny1, nx0:nx1] = True
        clean = inpaint(rgb, m)
        img = np.dstack([clean, fg * 255]).astype(np.uint8)[y0:y1, x0:x1]
        im = save(shrink(img, BARS_K), name)
        layout[name] = (round(x0 * BARS_K), round(y0 * BARS_K), im.width, im.height)
    # The level's two gold diamonds.
    for name, box in [("lvl_left", (1622, 610, 1685, 668)), ("lvl_right", (1878, 610, 1940, 668))]:
        x0, y0, x1, y1 = box
        img = np.dstack([rgb, fg * 255]).astype(np.uint8)[y0:y1, x0:x1]
        im = save(shrink(img, BARS_K), name)
        layout[name] = (round(x0 * BARS_K), round(y0 * BARS_K), im.width, im.height)
    return layout


# --- The action panel ------------------------------------------------------
# name: crop (board px; the row crops tile edge to edge, so the faces laid
# side by side rebuild the painting), the painted numbers to paint out, and
# where the live number goes (its centre, board px) for the HUD's labels.
ACTIONS = {
    "draw":    {"box": (35, 15, 385, 285), "erase": [(240, 60, 330, 135)], "num": (285, 98)},
    "info":    {"box": (385, 112, 497, 218), "erase": [], "num": None},
    "flash":   {"box": (30, 285, 628, 462), "erase": [(405, 345, 490, 430)], "num": (447, 385)},
    "boots":   {"box": (628, 285, 782, 462), "erase": [], "num": None},
    "sidestep": {"box": (782, 285, 928, 462), "erase": [], "num": None},
    "quick":   {"box": (928, 285, 1102, 462), "erase": [], "num": None},
    "brain":   {"box": (30, 462, 628, 632), "erase": [(405, 510, 490, 595)], "num": (447, 550)},
    "peek":    {"box": (628, 462, 838, 632), "erase": [], "num": None},
    "buy":     {"box": (838, 462, 1032, 632), "erase": [(966, 486, 1003, 526)], "num": (987, 507)},
    "attack":  {"box": (30, 632, 772, 802), "erase": [(270, 680, 660, 770)], "num": (270, 722)},
    "block":   {"box": (772, 632, 1102, 802), "erase": [(925, 680, 1040, 770)], "num": (982, 722)},
    "wait":    {"box": (30, 802, 1112, 1000), "erase": [(840, 840, 955, 935)], "num": (897, 885)},
    "discard": {"box": (1135, 285, 1518, 692), "erase": [(1372, 565, 1428, 632)], "num": (1400, 598)},
}


def cut_actions():
    rgb = load("hud_actions_board.webp")
    fg = foreground(rgb)
    m = np.zeros(rgb.shape[:2], bool)
    for spec in ACTIONS.values():
        for x0, y0, x1, y1 in spec["erase"]:
            m[y0:y1, x0:x1] = True
    clean = inpaint(rgb, m)
    layout = {}
    for name, spec in ACTIONS.items():
        x0, y0, x1, y1 = spec["box"]
        img = np.dstack([clean, fg * 255]).astype(np.uint8)[y0:y1, x0:x1]
        im = save(shrink(img, ACT_K), "act_%s" % name)
        num = None
        if spec["num"]:
            num = (round((spec["num"][0] - x0) * ACT_K), round((spec["num"][1] - y0) * ACT_K))
        layout[name] = {"size": (im.width, im.height), "num": num}
    return layout


def main():
    os.makedirs(os.path.dirname(OUT % "x"), exist_ok=True)
    for k, v in cut_bars().items():
        print(k, v)
    for k, v in cut_actions().items():
        print(k, v)


if __name__ == "__main__":
    main()
