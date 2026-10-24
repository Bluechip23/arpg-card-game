#!/usr/bin/env python3
"""Square up the designer's chosen passive icons for the skill-icon folder.

Sources: assets/sprites/paintings/passive_icons/<passive_id>.png (.gdignore'd
source art). The designer picked these per passive (all twelve of Brad's,
Cory's and Jeremy's, 2026-10-24); they arrive as screenshot crops a few
pixels off square, some with a strip of whatever sat next to the icon on
screen. TRIM drops those strips, the rest is centre-cropped to a square and
shrunk to SIZE (the craftpix icon packs' export size, so these sit at the
same texel density as every other icon).

Output: assets/textures/craftpix/icons/passive_<passive_id>.png, which
scripts/ui/skill_icon_art.gd maps as "passive_<passive_id>" (an apostrophe in
the id is dropped from the file name: a_mage's_favor -> a_mages_favor).
Run: python3 tools/cut_passive_icons.py   (Pillow)
"""
import glob
import os

from PIL import Image

SRC_DIR = "assets/sprites/paintings/passive_icons"
OUT = "assets/textures/craftpix/icons/passive_%s.png"
SIZE = 48

# passive_id -> (left, top, right, bottom) of the icon in its source, past the
# screenshot strips (measured).
TRIM = {
    "directed_strength": (0, 0, 82, 82),   # a navy strip under it
    "enraged_will": (0, 0, 92, 89),        # a dark red edge down the right
    "in_the_trenches": (1, 0, 90, 82),     # a navy column on the left
    "life_steal": (0, 0, 85, 90),          # a navy column on the right
    "point_to_prove": (0, 7, 86, 92),      # navy rows on top
    "redemption": (0, 2, 97, 107),         # a navy and a brown row on top
    "solemn_independence": (0, 0, 101, 101),  # a dark row under it
    "stone_skin": (1, 1, 105, 107),        # a dark row on top, a column on the left
    "vines_codependence": (0, 3, 76, 85),  # navy rows on top
    "budding": (2, 0, 92, 77),             # dark columns on the left
    "death_as_lifeblood": (1, 0, 102, 100),  # a dark column on the left
    "eat": (0, 5, 85, 92),                 # navy rows on top
    "expel_negativity": (0, 5, 90, 90),    # navy rows on top
    "regrowth": (0, 1, 106, 110),          # a dark row on top, two under it
    "self_reliance": (0, 0, 85, 87),       # dark rows under it
    "serial_killer": (3, 1, 90, 87),       # navy columns on the left, a dark row on top
    "blood_libation": (0, 3, 97, 107),     # dark rows on top
    "fresh_start": (4, 0, 101, 97),        # dark columns on the left
    "harnessed_power": (0, 0, 87, 87),     # dark columns on the right, rows under it
    "kinetic_armor": (0, 0, 90, 82),       # a dark column on the right
    "a_mages_favor": (5, 4, 115, 112),     # a sliver of the next icon and dark columns on the left, dark rows on top
    "seance": (3, 0, 112, 97),             # dark columns on the left
    "tricks_of_death": (3, 0, 113, 97),    # dark columns on both sides
    "arcane_overflow": (2, 2, 111, 110),   # dark rows on top, dark columns on both sides
}


def square(img: Image.Image) -> Image.Image:
    w, h = img.size
    side = min(w, h)
    x0, y0 = (w - side) // 2, (h - side) // 2
    return img.crop((x0, y0, x0 + side, y0 + side))


def main() -> None:
    for path in sorted(glob.glob(os.path.join(SRC_DIR, "*.png"))):
        pid = os.path.splitext(os.path.basename(path))[0]
        img = Image.open(path).convert("RGBA")
        if pid in TRIM:
            img = img.crop(TRIM[pid])
        out = square(img).resize((SIZE, SIZE), Image.LANCZOS)
        out.save(OUT % pid)
        print("%-24s %s -> %dx%d" % (pid, img.size, SIZE, SIZE))


if __name__ == "__main__":
    main()
