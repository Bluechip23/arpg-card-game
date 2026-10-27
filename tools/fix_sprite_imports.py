#!/usr/bin/env python3
"""Keep the generated figure sprites lossless in the editor.

Godot's texture importer defaults to "detect 3D": the first time the editor
sees a texture on a 3D sprite it re-imports it VRAM-compressed (lossy), which
smears the designer's art. Every sprite under assets/sprites/generated/ is
pinned instead: lossless, no 3D detection; mipmaps on for the smooth twins
(drawn with linear filtering and mipmaps), off for the pixel sheets (nearest).
project.godot's [importer_defaults] does the same for new files; this fixes
files imported before that (2026-10-27).

Run: python3 tools/fix_sprite_imports.py   (then godot --headless --import)
"""
import glob
import re

ROOT = "assets/sprites/generated"


def main():
    changed = 0
    for path in glob.glob(ROOT + "/**/*.png.import", recursive=True):
        s = open(path).read()
        smooth = "/smooth/" in path
        t = re.sub(r"detect_3d/compress_to=\d+", "detect_3d/compress_to=0", s)
        t = re.sub(r"compress/mode=\d+", "compress/mode=0", t)
        t = re.sub(r"mipmaps/generate=\w+", "mipmaps/generate=%s" % ("true" if smooth else "false"), t)
        if t != s:
            open(path, "w").write(t)
            changed += 1
    print("fixed %d import files" % changed)


if __name__ == "__main__":
    main()
