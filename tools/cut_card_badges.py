#!/usr/bin/env python3
"""Cut the card cost badges — the mana drop and the hourglass — from the
designer's Instant card (card_instant_board.webp, 2026-10-30).

On the board the drop sits over the frame's golden feathers and the
hourglass over its gilt corner, each with its number painted on. Each is
separated from the frame (the drop by GrabCut seeded from its blue body;
the hourglass by its outline, traced from the board), the number painted out, and the
result saved at 3x the badge box (the card shows each in a 32x40 box,
shrunk smoothly), centred, standing on the box's bottom.

Output: assets/ui/mana_drop.png and assets/ui/sand_timer.png (96x120).
Run: python3 tools/cut_card_badges.py
"""
import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/card_instant_board.webp"
OUT = "assets/ui/%s.png"
BOX = (96, 120)
PAD = 3   # texels left clear round the art inside the box

# Board crops: (x0, y0, x1, y1).
DROP_BOX = (40, 20, 215, 290)
HOURGLASS_BOX = (835, 75, 1000, 305)


def number_mask(rgb):
    """The painted number: near-white strokes plus their thick black rim."""
    mx = rgb.max(axis=2).astype(int)
    mn = rgb.min(axis=2).astype(int)
    white = (mn > 200) & (mx - mn < 40)
    lab, n = nd.label(white)
    if n == 0:
        return white
    sizes = nd.sum(white, lab, range(1, n + 1))
    keep = np.zeros_like(white)
    for i, s in enumerate(sizes):
        if s > 150:
            keep |= lab == i + 1
    # The glyphs' centre, and its black outline round them.
    return nd.binary_dilation(keep, iterations=9)


def grabcut(rgb, fg, prob_fg):
    mask = np.full(rgb.shape[:2], cv2.GC_BGD, np.uint8)
    mask[prob_fg] = cv2.GC_PR_FGD
    mask[fg] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    out = (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)
    out = nd.binary_fill_holes(nd.binary_opening(out, iterations=1))
    lab, n = nd.label(out)
    if n > 1:
        sizes = nd.sum(out, lab, range(1, n + 1))
        out = lab == 1 + int(np.argmax(sizes))
    return out


def drop_mask(rgb):
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(int)
    blue = (hsv[..., 0] > 90) & (hsv[..., 0] < 130) & (hsv[..., 1] > 90) & (hsv[..., 2] > 60)
    lab, n = nd.label(blue)
    sizes = nd.sum(blue, lab, range(1, n + 1))
    body = nd.binary_fill_holes(lab == 1 + int(np.argmax(sizes)))
    # The drop's black ink rim: a few texels beyond the blue.
    prob = nd.binary_dilation(body, iterations=7)
    return grabcut(rgb, nd.binary_erosion(body, iterations=2), prob) & nd.binary_dilation(body, iterations=7)


def hourglass_mask(rgb):
    """Drawn from the board rather than found: the gold hourglass stands on
    the gilt frame, too alike in colour for a cut to part them. Two caps,
    the collars under them and the posts between (crop texels)."""
    h, w = rgb.shape[:2]
    poly = np.array([
        (6, 5), (157, 5), (157, 30), (143, 31), (143, 40), (138, 42),
        (138, 195), (147, 198), (147, 205), (158, 206), (158, 227),
        (5, 227), (5, 206), (17, 205), (17, 198), (23, 195), (23, 42),
        (20, 40), (20, 31), (6, 30)], np.int32)
    mask = np.zeros((h, w), np.uint8)
    cv2.fillPoly(mask, [poly], 1)
    return mask.astype(bool)


def cut(name, box, mask_fn):
    board = np.asarray(Image.open(SRC).convert("RGB"))
    rgb = board[box[1]:box[3], box[0]:box[2]].copy()
    mask = mask_fn(rgb)
    num = number_mask(rgb) & mask
    rgb = cv2.inpaint(rgb, num.astype(np.uint8) * 255, 9, cv2.INPAINT_TELEA)
    ys, xs = np.nonzero(mask)
    rgb, mask = rgb[ys.min():ys.max() + 1, xs.min():xs.max() + 1], mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    # Soft edge: feather the matte by a texel before shrinking.
    alpha = cv2.GaussianBlur(mask.astype(np.float32), (0, 0), 1.2) * mask.astype(np.float32)
    alpha = np.maximum(alpha, nd.binary_erosion(mask, iterations=2).astype(np.float32))
    img = Image.fromarray(np.dstack([rgb, (alpha * 255).astype(np.uint8)]), "RGBA")
    k = min((BOX[0] - 2 * PAD) / img.width, (BOX[1] - 2 * PAD) / img.height)
    size = (max(1, round(img.width * k)), max(1, round(img.height * k)))
    small = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    out = Image.new("RGBA", BOX)
    out.paste(small, ((BOX[0] - size[0]) // 2, BOX[1] - PAD - size[1]))
    out.save(OUT % name)
    print("%s: art %dx%d in %dx%d" % (name, size[0], size[1], BOX[0], BOX[1]))


def main():
    cut("mana_drop", DROP_BOX, drop_mask)
    cut("sand_timer", HOURGLASS_BOX, hourglass_mask)


if __name__ == "__main__":
    main()
