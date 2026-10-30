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
(The sidestep face keeps hud_actions_board_v1.webp's straight-across arrow
over the newer board's ducking man, as the designer asked.)

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
    "draw":    {"box": (35, 15, 390, 290), "erase": [(250, 65, 330, 130)], "num": (290, 98)},
    "info":    {"box": (390, 112, 505, 220), "erase": [], "num": None},
    "flash":   {"box": (30, 290, 618, 458), "erase": [(410, 340, 500, 420)], "num": (455, 378)},
    "boots":   {"box": (618, 290, 774, 458), "erase": [], "num": None},
    "sidestep": {"box": (774, 290, 920, 458), "erase": [(864, 324, 902, 352), (863, 350, 904, 372), (822, 337, 863, 350)], "num": None},
    "quick":   {"box": (920, 290, 1090, 458), "erase": [], "num": None},
    "brain":   {"box": (30, 458, 618, 625), "erase": [(410, 505, 500, 585)], "num": (455, 543)},
    "peek":    {"box": (618, 458, 828, 625), "erase": [], "num": None},
    "buy":     {"box": (828, 458, 1028, 625), "erase": [(960, 485, 1000, 528)], "num": (980, 507)},
    "attack":  {"box": (30, 625, 768, 795), "erase": [(275, 675, 660, 765)], "num": (275, 715)},
    "block":   {"box": (768, 625, 1100, 795), "erase": [(925, 675, 1035, 765)], "num": (980, 715)},
    "wait":    {"box": (30, 795, 1110, 985), "erase": [(840, 840, 950, 925)], "num": (895, 882)},
    "discard": {"box": (1118, 295, 1515, 690), "erase": [(1361, 553, 1407, 618)], "num": (1385, 588)},
}
# The sidestep's ducking man (2026-10-29) keeps the first board's arrow that
# points straight across, not his own pointing down: (source box on
# hud_actions_board_v1.webp, where its top-left lands on this board).
SIDESTEP_ARROW = ((818, 326, 905, 360), (810, 314))


def cut_actions():
    rgb = load("hud_actions_board.webp")
    fg = foreground(rgb)
    m = np.zeros(rgb.shape[:2], bool)
    for spec in ACTIONS.values():
        for x0, y0, x1, y1 in spec["erase"]:
            m[y0:y1, x0:x1] = True
    clean = inpaint(rgb, m)
    # Paste the straight-across arrow (its bright strokes and their outline).
    old = load("hud_actions_board_v1.webp")
    (sx0, sy0, sx1, sy1), (dx, dy) = SIDESTEP_ARROW
    src = old[sy0:sy1, sx0:sx1]
    bright = src.max(axis=2) > 90
    keep = bright | ((src.max(axis=2) < 18) & nd.binary_dilation(bright, iterations=2))
    dst = clean[dy:dy + src.shape[0], dx:dx + src.shape[1]]
    dst[keep] = src[keep]
    layout = {}
    for name, spec in ACTIONS.items():
        if name in ("wait", "attack", "block"):
            continue   # only their slimmed cuts (below) are on screen
        x0, y0, x1, y1 = spec["box"]
        img = np.dstack([clean, fg * 255]).astype(np.uint8)[y0:y1, x0:x1]
        im = save(shrink(img, ACT_K), "act_%s" % name)
        num = None
        if spec["num"]:
            num = (round((spec["num"][0] - x0) * ACT_K), round((spec["num"][1] - y0) * ACT_K))
        layout[name] = {"size": (im.width, im.height), "num": num}
    # The attack row is as wide as the flash row above it (the designer:
    # attack and shield 90%, wait 10%). Its faces are slimmed by dropping
    # stretches of empty interior (board px column spans kept, joined edge to
    # edge), at the row's height; wait is the long frame's two ends round
    # the hand alone (its tempo is in the tooltip).
    art = np.dstack([clean, fg * 255]).astype(np.uint8)
    rows = round((ACTIONS["attack"]["box"][3] - ACTIONS["attack"]["box"][1]) * ACT_K)
    for name, row_box, spans, num in [
            ("attack_slim", ACTIONS["attack"]["box"], [(30, 555), (668, 768)], (275, 715)),
            ("block_slim", ACTIONS["block"]["box"], [(768, 1035), (1068, 1100)], (980, 715)),
            ("wait_slim", ACTIONS["wait"]["box"], [(30, 60), (140, 226), (1084, 1110)], None)]:
        y0, y1 = row_box[1], row_box[3]
        parts = [art[y0:y1, a:b] for a, b in spans]
        joined = np.ascontiguousarray(np.concatenate(parts, axis=1))
        k = rows / float(joined.shape[0])
        im = save(shrink(joined, size=(round(joined.shape[1] * k), rows)), "act_" + name)
        n = None
        if num:
            off = 0
            for a, b in spans:
                if a <= num[0] < b:
                    n = (round((off + num[0] - a) * k), round((num[1] - y0) * k))
                    break
                off += b - a
        layout[name] = {"size": (im.width, im.height), "num": n}
    return layout


def main():
    os.makedirs(os.path.dirname(OUT % "x"), exist_ok=True)
    for k, v in cut_bars().items():
        print(k, v)
    for k, v in cut_actions().items():
        print(k, v)


if __name__ == "__main__":
    main()
