#!/usr/bin/env python3
"""Pack the designer's searing-fire animation (A Snowball's Chance) into one
horizontal sprite strip.

Sources: assets/sprites/paintings/searing_fire_0..4.png (.gdignore'd source
art, 2026-10-23): five 32x143 transparent frames on one shared canvas — a
flame column rising from its base at the bottom: a lick of flame, taller,
the full column, breaking into embers, the last embers. One-pixel art with
on/off alpha.

The card's fire runs along the ground, so each frame is turned a quarter
clockwise: the base on the LEFT, the flames reaching RIGHT (+X, the heading
convention the effect player turns along — the same as the fireball's).
The player (scripts/effects/searing_fire_fx.gd) pins the base to the caster
and stretches nothing: it scales the whole strip so the flames end where the
3-space fire line ends.

Output: assets/sprites/generated/fx/searing_fire_strip.png (5 frames of 143x32)
Run: python3 tools/cut_searing_fire.py   (Pillow)
"""
import os

from PIL import Image

SRC = "assets/sprites/paintings/searing_fire_%d.png"
OUT = "assets/sprites/generated/fx/searing_fire_strip.png"
FRAMES = 5
SIZE = (32, 143)  # the vertical source canvas (w, h)


def main() -> None:
    cells = []
    for i in range(FRAMES):
        f = Image.open(SRC % i).convert("RGBA")
        assert f.size == SIZE, f.size
        cells.append(f.transpose(Image.Transpose.ROTATE_270))  # a quarter clockwise: base left, tip right
    w, h = cells[0].size
    strip = Image.new("RGBA", (w * FRAMES, h))
    for i, c in enumerate(cells):
        strip.paste(c, (i * w, 0))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    strip.save(OUT)
    print("searing fire: %d frames of %dx%d -> %s" % (FRAMES, w, h, OUT))


if __name__ == "__main__":
    main()
