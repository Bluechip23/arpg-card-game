#!/usr/bin/env python3
"""Pack the designer's Fireball animation into one sprite strip.

Sources: assets/sprites/paintings/fireball_0..4.png (.gdignore'd source art,
2026-10-23): five 128x128 transparent frames on one shared canvas — the
kindling ember, the fireball in flight (heading right, trail behind), and
three stages of the explosion. One-pixel art with on/off alpha, kept at its
own size: the blast then spans ~4 tiles, Fireball's 2-tile radius.

Every frame shares one anchor on the canvas, ANCHOR below (the ball's core,
which is also where the ember sits and the blast blooms from), so the
player (scripts/effects/fireball_fx.gd) pins that point to the caster's
hand, the flight path and the impact.

Output: assets/sprites/generated/fx/fireball_strip.png (5 frames of 128x128)
Run: python3 tools/cut_fireball.py   (Pillow)
"""
import os

from PIL import Image

SRC = "assets/sprites/paintings/fireball_%d.png"
OUT = "assets/sprites/generated/fx/fireball_strip.png"
FRAMES = 5
CELL = 128
ANCHOR = (77, 69)  # measured: the flying ball's core; the ember and blast centre on it too


def main() -> None:
    strip = Image.new("RGBA", (CELL * FRAMES, CELL))
    for i in range(FRAMES):
        f = Image.open(SRC % i).convert("RGBA")
        assert f.size == (CELL, CELL), f.size
        strip.paste(f, (i * CELL, 0))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    strip.save(OUT)
    print("fireball: %d frames of %dx%d, anchor %s -> %s" % (FRAMES, CELL, CELL, ANCHOR, OUT))


if __name__ == "__main__":
    main()
