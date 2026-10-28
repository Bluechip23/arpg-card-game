#!/usr/bin/env python3
"""Cut a matte (figure mask) for every pose of the pose boards that ask for
one, with a background-removal model, for tools/cut_pose_boards.py.

The colour-and-GrabCut cutter struggles where a board's figure and scenery
share colours: a black hood on a night sky, a pale crawler on a grey cave,
a staff against a snowfield. A segmentation model (BiRefNet, through rembg)
sees the figure as a whole and is far cleaner there (2026-10-25). The
masks are saved, so cutting the sheets never needs the model: only this
script does, and only when a board or its boxes change.

Each pose is given to the model with PAD px of board around its box (the
model judges a figure better with some of its setting), then the mask is
cropped back to the box. Output, next to the boards (.gdignore'd):
  assets/sprites/paintings/mattes/<kind>_<direction>.png  (white = figure)

Needs (tool dependencies only, not the game's): rembg[cpu] (onnxruntime),
which downloads the birefnet-general-lite model on first use.
Run: python3 tools/make_mattes.py [kind ...]
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import cut_pose_boards as boards   # noqa: E402

MODEL = "birefnet-general-lite"
PAD = 80
OUT = "assets/sprites/paintings/mattes"


def main() -> None:
    from rembg import new_session, remove
    session = new_session(MODEL)
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or [k for k, cfg in boards.BOARDS.items() if cfg.get("matte")]
    for kind in names:
        cfg = boards.BOARDS[kind]
        board = Image.open(boards.SRC % cfg["src"])
        if board.mode == "RGBA":   # a board that came cut out: judged as drawn, on white
            white = Image.new("RGBA", board.size, (255, 255, 255, 255))
            white.alpha_composite(board)
            board = white
        board = board.convert("RGB")
        for d in cfg.get("matte", ()):
            # "Walk:left" names a pose of another animation (its own matte file).
            anim, dd = d.split(":") if ":" in d else ("Idle", d)
            x0, y0, x1, y1 = cfg[anim][dd]
            big = board.crop((x0 - PAD, y0 - PAD, x1 + PAD, y1 + PAD))
            mask = remove(big, session=session, only_mask=True)
            mask = mask.crop((PAD, PAD, PAD + x1 - x0, PAD + y1 - y0))
            mask.point(lambda v: 255 if v > 127 else 0).save(os.path.join(OUT, "%s_%s.png" % (kind, d.replace(":", "_"))))
            print(kind, d)


if __name__ == "__main__":
    main()
