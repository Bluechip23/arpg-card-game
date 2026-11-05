#!/usr/bin/env python3
"""Measure the soft edges of the smooth sheets the game draws (ArtStyle.SMOOTH).

The designer's boards are flat RGB (no alpha), so any 0 < alpha < 255 pixel in
a cut is new: it comes from the cutter, not the source. Per sheet this writes
the opaque, semi-transparent and fully transparent-but-coloured (bled) pixel
counts, for the smooth sheets and their pixel twins side by side.

Run from the repo root: python3 tools/audit_smooth_alpha.py docs/sprite_audit/smooth_alpha.md
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

GEN = "assets/sprites/generated"


def stats(p):
    a = np.asarray(Image.open(p).convert("RGBA"))
    al = a[..., 3]
    return {"opaque": int((al == 255).sum()), "semi": int(((al > 0) & (al < 255)).sum()),
            "bled": int(((al == 0) & (a[..., :3].max(axis=2) > 0)).sum())}


def main():
    out = sys.argv[1]
    smooth = sorted(glob.glob(os.path.join(GEN, "smooth", "heroes", "*.png")) +
                    glob.glob(os.path.join(GEN, "smooth", "sheets", "*", "*.png")))
    lines = ["# Soft alpha in the sheets the game draws", "",
             "`ArtStyle.SMOOTH = true`: the game loads `generated/smooth/` (Lanczos-resampled, soft",
             "alpha, edge colour bled outward, imported with mipmaps and drawn with",
             "`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`). Semi = pixels with 0 < alpha < 255 (none exist in",
             "the RGB boards); bled = fully transparent pixels carrying colour (the bleed).", "",
             "| sheet | smooth opaque | smooth semi | semi share | smooth bled | pixel-sheet semi |",
             "|---|---|---|---|---|---|"]
    tot = {"opaque": 0, "semi": 0, "n": 0, "with_semi": 0}
    for p in smooth:
        s = stats(p)
        twin = p.replace(os.path.join(GEN, "smooth"), GEN)
        ps = stats(twin)["semi"] if os.path.exists(twin) else "-"
        share = s["semi"] / max(1, s["semi"] + s["opaque"])
        lines.append("| %s | %d | %d | %.1f%% | %d | %s |" % (os.path.relpath(p, GEN), s["opaque"], s["semi"],
                     100 * share, s["bled"], ps))
        tot["opaque"] += s["opaque"]
        tot["semi"] += s["semi"]
        tot["n"] += 1
        tot["with_semi"] += s["semi"] > 0
    lines[6:6] = ["**%d smooth sheets, %d with semi-transparent pixels; %d semi-transparent px in all "
                  "(%.1f%% of the figures' pixels).**" % (tot["n"], tot["with_semi"], tot["semi"],
                  100 * tot["semi"] / max(1, tot["semi"] + tot["opaque"])), ""]
    open(out, "w").write("\n".join(lines) + "\n")
    print(lines[6])


if __name__ == "__main__":
    main()
