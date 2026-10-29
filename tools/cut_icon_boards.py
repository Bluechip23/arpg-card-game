#!/usr/bin/env python3
"""Cut the designer's icon boards (item icons painted on black) into the
icons the UI shows: each one lifted off the black the way the props are
(tools/cut_prop_boards.py cut_piece), fitted inside FIT texels and centred
in a CELL-texel square — twice the 32 px pack icons, the fineness of the
designer's other art. ItemSilhouette draws them at whole multiples of
their size; the loot bag draws at half scale on the ground.

Output: assets/textures/ui_icons/<name>.png
Run: python3 tools/cut_icon_boards.py
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cut_prop_boards import SRC, cut_piece  # noqa: E402

OUT = "assets/textures/ui_icons/%s.png"
CELL = 64
FIT = 60

# 2026-10-29: the designer's item icons and loot bag (item_icons_board.webp,
# 18 icons on black, three rows). Names follow the slot icons they replace
# (ItemSilhouette.ICONS); the wooden shield, the curved sword and the
# trident have no slot of their own yet.
BOARDS = {
    "item_icons_board.webp": {
        "slot_ring": (41, 81, 236, 285),
        "slot_shield": (298, 60, 473, 311),
        "slot_polearm": (516, 56, 754, 312),
        "slot_sword": (775, 59, 1005, 313),
        "shield_wooden": (1053, 68, 1232, 319),
        "slot_wand": (1272, 30, 1517, 326),
        "icon_bag": (19, 335, 249, 610),
        "slot_axe": (278, 361, 497, 607),
        "slot_belt": (543, 388, 752, 568),
        "slot_boots": (775, 364, 974, 603),
        "sword_curved": (1026, 352, 1248, 604),
        "slot_chest": (1272, 364, 1521, 609),
        "slot_dagger": (42, 676, 222, 905),
        "slot_gauntlets": (236, 676, 507, 905),
        "slot_hammer": (512, 629, 755, 900),
        "slot_helm": (778, 637, 974, 909),
        "trident": (1015, 640, 1264, 908),
        "slot_quiver": (1268, 664, 1512, 918),   # an arrow
    },
}


def cut_icon(board, box):
    img = cut_piece(board, box, FIT)
    if img.width > FIT:
        img = cut_piece(board, box, max(1, round(FIT * FIT / img.width)))
    cell = Image.new("RGBA", (CELL, CELL))
    cell.paste(img, ((CELL - img.width) // 2, (CELL - img.height) // 2), img)
    return cell


def main():
    os.makedirs(os.path.dirname(OUT % "x"), exist_ok=True)
    for src, icons in BOARDS.items():
        board = Image.open(SRC % src)
        for name, box in icons.items():
            cut_icon(board, box).save(OUT % name)
        print("%s: %d icons" % (src, len(icons)))


if __name__ == "__main__":
    main()
