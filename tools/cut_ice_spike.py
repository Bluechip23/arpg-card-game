#!/usr/bin/env python3
"""Pack the designer's ice-spike animation (Surrounding Ice) into one strip.

Sources: assets/sprites/paintings/ice_spike_0..4.png (.gdignore'd source
art, 2026-10-23): five 128x128 transparent frames on one shared canvas, in
the order the spike plays them — a thin shard breaking the ground, the
spike rising, the full stalagmite, cracking, shattered into ice chips. (The
designer numbered them 3, 4, 7, 9, 11 of their sequence; they are stored
here in that playing order.) One-pixel art with on/off alpha, kept at its
own size.

Every frame's spike stands on the same ground point, BASE below; the player
(scripts/effects/surrounding_ice_fx.gd) pins it to the tile it erupts from.

Output: assets/sprites/generated/fx/ice_spike_strip.png (5 frames of 128x128)
Run: python3 tools/cut_ice_spike.py   (Pillow)
"""
import os

from PIL import Image

SRC = "assets/sprites/paintings/ice_spike_%d.png"
OUT = "assets/sprites/generated/fx/ice_spike_strip.png"
FRAMES = 5
CELL = 128
BASE = (62, 98)  # measured: where every frame's spike meets the ground (its root cracks spread from here)


def main() -> None:
    strip = Image.new("RGBA", (CELL * FRAMES, CELL))
    for i in range(FRAMES):
        f = Image.open(SRC % i).convert("RGBA")
        assert f.size == (CELL, CELL), f.size
        strip.paste(f, (i * CELL, 0))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    strip.save(OUT)
    print("ice spike: %d frames of %dx%d, base %s -> %s" % (FRAMES, CELL, CELL, BASE, OUT))


if __name__ == "__main__":
    main()
