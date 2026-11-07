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
An action board that asks for mattes ("actions": {"matte": True}: the Battle
Turtle's armor board, whose dark shading is as dark as its navy backdrop)
gets one per frame too, <kind>_act_<direction>_<pose>.png
(cut_pose_boards.action_matte_path).

Needs (tool dependencies only, not the game's): rembg[cpu] (onnxruntime),
which downloads the birefnet-general-lite model on first use.
Hero action boards that ask for mattes ("matte": True in
tools/cut_hero_actions.py: Cory's kick, whose shadow legs are as dark as
the board's ground) get one a grid cell,
<hero>_<action>_<facing>_<col>.png (hero_action_matte_path).

Run: python3 tools/make_mattes.py [kind ...]
     python3 tools/make_mattes.py <kind> --actions   (only its action frames)
     python3 tools/make_mattes.py --hero [hero_action ...]   (e.g. cory_attack)
     python3 tools/make_mattes.py --walk [hero ...]   (the walk boards that ask, e.g. brad)
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import cut_pose_boards as boards   # noqa: E402

MODEL = "birefnet-general-lite"
PAD = 80
OUT = "assets/sprites/paintings/mattes"


def hero_action_matte_path(hero: str, action: str, facing: str, col: int) -> str:
    """A hero action cell's matte (tools/cut_hero_actions.py, "matte": True)."""
    return os.path.join(OUT, "%s_%s_%s_%d.png" % (hero, action, facing, col))


def hero_actions(session, remove, which) -> None:
    """Mattes for the hero action boards that ask for them ("matte": True in
    cut_hero_actions.ACTIONS): one a grid cell, the cell given to the model
    padded with its own ground colour (the next cells' figures would be in
    a padding of board), so the model judges the figure alone."""
    import numpy as np
    import cut_hero_actions as ha
    for (hero, action), spec in ha.ACTIONS.items():
        if not spec.get("matte") or (which and "%s_%s" % (hero, action) not in which):
            continue
        board = np.asarray(Image.open(ha.hs.SRC % spec["src"]).convert("RGB"))
        cols, i = spec["cols"], ha.CELL_INSET
        for (top, bottom), facing in zip(spec["rows"], spec["facings"]):
            for c in range(len(cols) - 1):
                cell = board[top + i:bottom - i + 1, cols[c] + i:cols[c + 1] - i + 1]
                border = np.concatenate([cell[0], cell[-1], cell[:, 0], cell[:, -1]])
                ground = np.median(border, axis=0).astype(np.uint8)
                big = np.empty((cell.shape[0] + 2 * PAD, cell.shape[1] + 2 * PAD, 3), np.uint8)
                big[:] = ground
                big[PAD:PAD + cell.shape[0], PAD:PAD + cell.shape[1]] = cell
                mask = remove(Image.fromarray(big), session=session, only_mask=True)
                mask = mask.crop((PAD, PAD, PAD + cell.shape[1], PAD + cell.shape[0]))
                mask.point(lambda v: 255 if v > 127 else 0).save(hero_action_matte_path(hero, action, facing, c))
                print(hero, action, facing, c)


def hero_walks(session, remove, which) -> None:
    """Mattes for the hero walk boards that ask for them ("matte" in
    cut_hero_sprites.WALKS' options: Brad's, whose War Rack is dark wood on
    the board's dark ground): one a grid cell, padded with the cell's own
    ground colour, saved where cut_hero_sprites.hero_walk_matte_path reads."""
    import numpy as np
    import cut_hero_sprites as hs
    for hero, w in hs.WALKS.items():
        opts = w[6] if len(w) > 6 else {}
        if not opts.get("matte") or (which and hero not in which):
            continue
        path, xs, ys, facings, skip = w[:5]
        board = np.asarray(Image.open(hs.SRC % path).convert("RGB"))
        i = hs.WALK_CELL_INSET
        for r, facing in enumerate(facings):
            if facing in skip:
                continue
            for c in range(len(xs) - 1):
                cell = board[ys[r] + i:ys[r + 1] - i + 1, xs[c] + i:xs[c + 1] - i + 1]
                border = np.concatenate([cell[0], cell[-1], cell[:, 0], cell[:, -1]])
                ground = np.median(border, axis=0).astype(np.uint8)
                big = np.empty((cell.shape[0] + 2 * PAD, cell.shape[1] + 2 * PAD, 3), np.uint8)
                big[:] = ground
                big[PAD:PAD + cell.shape[0], PAD:PAD + cell.shape[1]] = cell
                mask = remove(Image.fromarray(big), session=session, only_mask=True)
                mask = mask.crop((PAD, PAD, PAD + cell.shape[1], PAD + cell.shape[0]))
                mask.point(lambda v: 255 if v > 127 else 0).save(hs.hero_walk_matte_path(hero, facing, c))
                print(hero, "walk", facing, c)


def main() -> None:
    from rembg import new_session, remove
    session = new_session(MODEL)
    os.makedirs(OUT, exist_ok=True)
    if sys.argv[1:2] == ["--walk"]:
        hero_walks(session, remove, sys.argv[2:])
        return
    if sys.argv[1:2] == ["--hero"]:
        hero_actions(session, remove, sys.argv[2:])
        return
    args = sys.argv[1:]
    actions_only = "--actions" in args   # only the action frames' mattes (the poses' are kept)
    args = [a for a in args if a != "--actions"]
    names = args or [k for k, cfg in boards.BOARDS.items()
                     if cfg.get("matte") or cfg.get("actions", {}).get("matte")
                     or cfg.get("actions", {}).get("matte_union")]
    for kind in names:
        cfg = boards.BOARDS[kind]
        board = Image.open(boards.SRC % cfg["src"])
        if board.mode == "RGBA":   # a board that came cut out: judged as drawn, on white
            white = Image.new("RGBA", board.size, (255, 255, 255, 255))
            white.alpha_composite(board)
            board = white
        board = board.convert("RGB")
        for d in (() if actions_only else cfg.get("matte", ())):
            # "Walk:left" names a pose of another animation (its own matte file).
            anim, dd = d.split(":") if ":" in d else ("Idle", d)
            x0, y0, x1, y1 = cfg[anim][dd]
            big = board.crop((x0 - PAD, y0 - PAD, x1 + PAD, y1 + PAD))
            mask = remove(big, session=session, only_mask=True)
            mask = mask.crop((PAD, PAD, PAD + x1 - x0, PAD + y1 - y0))
            mask.point(lambda v: 255 if v > 127 else 0).save(os.path.join(OUT, "%s_%s.png" % (kind, d.replace(":", "_"))))
            print(kind, d)
        act = cfg.get("actions", {})
        if act.get("matte") or act.get("matte_union"):
            for d, poses in act["frames"].items():
                name = act["src"][d] if isinstance(act["src"], dict) else act["src"]
                src = Image.open(boards.SRC % name).convert("RGB")
                for pose, spec in poses.items():
                    if spec[0] == "same":
                        continue
                    x0, y0, x1, y1 = spec[1] if spec[0] == "mirror" else spec
                    big = src.crop((x0 - PAD, y0 - PAD, x1 + PAD, y1 + PAD))
                    mask = remove(big, session=session, only_mask=True)
                    mask = mask.crop((PAD, PAD, PAD + x1 - x0, PAD + y1 - y0))
                    mask.point(lambda v: 255 if v > 127 else 0).save(boards.action_matte_path(kind, d, pose))
                    print(kind, "action", d, pose)


if __name__ == "__main__":
    main()
