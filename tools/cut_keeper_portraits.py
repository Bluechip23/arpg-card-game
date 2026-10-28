#!/usr/bin/env python3
"""Cut the shopkeepers' speech-bar portraits from their NPC sheets.

Each of the designer's NPC sheets carries a head close-up (a framed panel
top-right on the Sellsword's and Blacksmith's, the "head detail" bottom-left
on the Armory keeper's and Card Dealer's). The square inside that panel
becomes assets/sprites/portraits/<keeper>.png, shown when the keeper
introduces themselves. The Card Dealer's panel has a painted checkerboard
behind the head; it is replaced by the portraits' dark backdrop.

Run: python3 tools/cut_keeper_portraits.py
"""
import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/%s_npc_board.webp"
OUT = "assets/sprites/portraits/%s.png"
SIZE = 256
BACKDROP = (14, 16, 20)

# keeper -> (sheet, square crop box in sheet pixels, key out the checkerboard)
KEEPERS = {
    "keeper_sellsword": ("sellsword", (1250, 30, 1490, 270), False),
    "keeper_blacksmith": ("blacksmith", (1298, 40, 1522, 264), False),
    "keeper_armory": ("armory", (26, 616, 256, 846), False),
    "keeper_card_dealer": ("card_dealer", (20, 630, 340, 950), True),
}


def key_checker(im):
    """The light grey / white checker squares (bright, colourless) -> backdrop,
    flood-filled in from the edges so the ruff and feather stay."""
    a = np.asarray(im).astype(int)
    h, w, _ = a.shape
    mx, mn = a.max(axis=2), a.min(axis=2)
    bg = (mn > 175) & (mx - mn < 18)
    seen = np.zeros((h, w), bool)
    stack = [(y, x) for y in range(h) for x in (0, w - 1) if bg[y, x]]
    stack += [(y, x) for x in range(w) for y in (0, h - 1) if bg[y, x]]
    while stack:
        y, x = stack.pop()
        if seen[y, x] or not bg[y, x]:
            continue
        seen[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and bg[ny, nx]:
                stack.append((ny, nx))
    a[seen] = BACKDROP
    return Image.fromarray(a.astype(np.uint8))


def main():
    for keeper, (sheet, box, checker) in KEEPERS.items():
        im = Image.open(SRC % sheet).convert("RGB").crop(box)
        if checker:
            im = key_checker(im)
        im.resize((SIZE, SIZE), Image.LANCZOS).save(OUT % keeper)
        print("wrote", OUT % keeper)


if __name__ == "__main__":
    main()
