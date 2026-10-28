#!/usr/bin/env python3
"""Olorin's "facing right" pose has a stray arm: a hand coming out of his back
gripping a second staff (he already holds his staff in front). The designer
(2026-10-28): keep the pose and the bear, remove the arm. This erases that
hand, its staff and orb from a copy of the sheet — above the shoulder line
everything left of his cloak, below it only the staff's warm wood (inpainted
from the cloak around it) — and writes olorin_board.png for
tools/cut_pose_boards.py. The sword on his back is kept.

Run: python3 tools/fix_olorin_board.py
"""
import cv2
import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/olorin_source.webp"
OUT = "assets/sprites/paintings/olorin_board.png"
BG = (236, 236, 236)          # the sheet's light backdrop (painted checker)

def main():
    a = np.asarray(Image.open(SRC).convert("RGB")).copy()
    h, w, _ = a.shape
    warm = (a[..., 0].astype(int) - a[..., 2].astype(int) > 22) & (a.max(axis=2) > 55)
    light = a.min(axis=2) > 150    # the white orb and its glints
    clear = np.zeros((h, w), bool)     # becomes backdrop
    fill = np.zeros((h, w), bool)      # inpainted from the cloak around it
    # The orb, branches, staff top and the hand: above the shoulder line,
    # everything left of the cloak; at the cloak's edge only wood / skin.
    clear[165:392, 1160:1218] = True
    clear[165:280, 1160:1232] = True   # the staff head's twigs, clear of the hat and sword hilt
    # The staff's shadowed lower end runs down left of the cloak hem,
    # from (1207, 380) to (1176, 545): everything left of that line (+5 px).
    ys, xs = np.mgrid[380:560, 1150:1215]
    line_x = 1207 - (ys - 380) * 31.0 / 165.0 + 5
    clear[380:560, 1150:1215] |= xs < line_x
    edge = np.zeros((h, w), bool); edge[165:392, 1218:1230] = True
    clear |= edge & (warm | light)
    # The shaft below runs down over the cloak's back hem: the wood only.
    shaft = np.zeros((h, w), bool); shaft[388:505, 1198:1228] = True
    fill |= shaft & warm
    fill = cv2.dilate(fill.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & shaft
    a[clear] = BG
    a = cv2.inpaint(a, fill.astype(np.uint8) * 255, 3, cv2.INPAINT_TELEA)
    Image.fromarray(a).save(OUT)
    print("wrote", OUT)

if __name__ == "__main__":
    main()
