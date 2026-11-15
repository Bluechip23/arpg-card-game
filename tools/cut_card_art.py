#!/usr/bin/env python3
"""Cut the designer's painted card art out of its boards.

Sources: assets/sprites/paintings/card_art_*_board.webp (.gdignore'd source
art). Each board is a row of square paintings, each in a thin black panel
border; PANELS gives each painting's box on its board, just inside that
border (measured: the black columns and rows run to mean luminance < 12).

The first board (2026-11-15): Basic Attack (a sword through a straw-and-wood
target) and Block (a sword turned on a lion-crest shield).

Each painting is shrunk to SIZE x SIZE. The card's art window is wider than
it is tall, so CardUI shows these "covered": scaled to the window's width
and cropped top and bottom about the middle, where both paintings put their
point of impact.

Output: assets/textures/cards/art/<card_id>.png, which
scripts/ui/skill_icon_art.gd maps in CARD_PAINTINGS.
Run: python3 tools/cut_card_art.py   (Pillow)
"""
import os

from PIL import Image

SRC = "assets/sprites/paintings/%s"
OUT = "assets/textures/cards/art/%s.png"
SIZE = 384   # about four times the art window's width: sharp on the hovered and close-up card

# board -> {card_id: (left, top, right, bottom)}
PANELS = {
    "card_art_attack_block_board.webp": {
        "basic_attack": (9, 8, 873, 879),
        "block": (903, 8, 1768, 879),
    },
}


def main() -> None:
    os.makedirs(os.path.dirname(OUT % "x"), exist_ok=True)
    for board, cuts in PANELS.items():
        src = Image.open(SRC % board).convert("RGB")
        for card_id, box in cuts.items():
            piece = src.crop(box)
            # A few pixels off square: centre-crop to the shorter side.
            side = min(piece.size)
            l = (piece.width - side) // 2
            t = (piece.height - side) // 2
            piece = piece.crop((l, t, l + side, t + side)).resize((SIZE, SIZE), Image.LANCZOS)
            piece.save(OUT % card_id, optimize=True)
            print("wrote", OUT % card_id)


if __name__ == "__main__":
    main()
