#!/usr/bin/env python3
"""Re-cut sprite sheets from the designer's boards as pure crops.

The hard rules (designer, 2026-11-05):
  * no resampling: every output pixel is a board pixel, copied verbatim
    (a mirrored facing is the same pixels flipped, nothing else);
  * one canvas per character, sized from its largest frame over every
    animation, with a transparent margin so nothing touches the edge;
  * each frame placed by a fixed anchor, not by centring its bounding box:
    vertically by its board row's ground line (so a frame keeps whatever lift
    the source gives it), horizontally by the centre of its feet;
  * hard alpha only (0 or 255): no new semi-transparent pixels, no new
    colours, no premultiplication.

Everything a cut needs is in one config (tools/recut_config.json): per
character, per animation, the board, how its figure is told from its
backdrop (a matte file, or a brightness key on a black board) and the box of
each frame on the board, row by row (front, back, left, right). Every
animation goes through cut_character() below.

Output (per character): <out>/<path>/<Animation>.png, rows front, back, left,
right of canvas-sized cells, and <out>/manifest.json for
tools/audit_sprite_cuts.py --manifest, plus a contact sheet and GIFs per
animation with --previews.

Run from the repo root:
  python3 tools/recut_sprites.py --out <dir> [--previews] [character ...]
Needs: numpy, Pillow, opencv-python-headless.
"""
import argparse
import json
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(HERE, "recut_config.json")
PAINTINGS = "assets/sprites/paintings"
ROWS = ["front", "back", "left", "right"]
PAD = 2            # transparent px kept round the largest frame on every side
FOOT_ROWS = 4      # the feet: this many lowest opaque rows give the horizontal anchor


# --------------------------------------------------------------------------
# Telling the figure from its backdrop (all hard masks, at board resolution)
# --------------------------------------------------------------------------

def _keep_pieces(mask, keep_share):
    n, lab, st, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), connectivity=8)
    if n <= 1:
        return mask
    areas = st[1:, cv2.CC_STAT_AREA]
    keep = np.zeros(n, bool)
    keep[1:] = areas >= areas.max() * keep_share
    return keep[lab]


def _fill_holes(mask, max_hole):
    """Fill enclosed gaps of at most max_hole px (dark paint inside the figure,
    an eye socket); larger enclosed gaps (backdrop between arm and body) stay."""
    inv = (~mask).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(inv, connectivity=4)
    h, w = mask.shape
    out = mask.copy()
    for i in range(1, n):
        x, y, bw, bh, area = st[i]
        touches = x == 0 or y == 0 or x + bw == w or y + bh == h
        if not touches and area <= max_hole:
            out[lab == i] = True
    return out


def figure_mask(board_rgba, box, spec, frame):
    """Hard mask of the figure inside `box` of the board. A "file" matte is a
    mask the size of the box (white = figure), named per frame ("matte") or
    per facing (the animation's matte "per_frame")."""
    x0, y0, x1, y1 = box
    m = spec["matte"]
    if m["kind"] == "file":
        path = frame.get("matte") or m["per_frame"][frame["row"]]
        mm = np.asarray(Image.open(os.path.join(PAINTINGS, path)).convert("L"))
        if mm.shape != (y1 - y0, x1 - x0):
            raise ValueError("matte %s is %s, box is %s" % (path, mm.shape, (y1 - y0, x1 - x0)))
        mask = mm >= 128
    elif m["kind"] == "black_key":
        crop = board_rgba[y0:y1, x0:x1]
        mask = crop[..., :3].max(axis=2) > m["threshold"]
        if board_rgba.shape[2] == 4:
            mask &= crop[..., 3] > 0
    else:
        raise ValueError("unknown matte kind %r" % m["kind"])
    if board_rgba.shape[2] == 4:
        mask &= board_rgba[y0:y1, x0:x1, 3] == 255   # a soft board alpha is not kept: hard alpha only
    mask = _keep_pieces(mask, m.get("keep_share", 0.04))
    if m.get("fill_holes"):
        mask = _fill_holes(mask, m["fill_holes"])
    return mask


# --------------------------------------------------------------------------
# The one code path
# --------------------------------------------------------------------------

def _board(name, cache={}):
    if name not in cache:
        cache[name] = np.asarray(Image.open(os.path.join(PAINTINGS, name)).convert("RGBA"))
    return cache[name]


def cut_frame(board_name, box, spec, frame, mirror=False):
    """One frame: the board's pixels inside `box` where the figure is, alpha
    255 there and 0 elsewhere (RGB zeroed where transparent)."""
    rgba = _board(board_name)
    x0, y0, x1, y1 = box
    mask = figure_mask(rgba, box, spec, frame)
    out = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    out[..., :3] = rgba[y0:y1, x0:x1, :3]
    out[..., 3] = np.where(mask, 255, 0)
    out[~mask, :3] = 0
    if mirror:
        out = out[:, ::-1].copy()
    return out


def cut_character(name, cfg):
    """Every frame of every animation of one character, anchored and packed
    on one canvas. Returns {anim: [[frame or None per col] per row]}, the
    canvas (w, h), the anchor in the canvas, and per-frame provenance."""
    cut = {}      # anim -> row -> [ {img, box, board, ground, foot_cx} ]
    for anim, acfg in cfg["animations"].items():
        cut[anim] = {}
        for row in ROWS:
            spec_row = acfg["rows"].get(row)
            if spec_row is None:
                continue
            frames = []
            for f in spec_row:
                if "mirror_of" in f:
                    continue
                img = cut_frame(acfg["board"], f["box"], acfg, dict(f, row=row), mirror=f.get("mirror", False))
                ys, xs = np.nonzero(img[..., 3])
                if len(ys) == 0:
                    raise ValueError("%s %s %s: empty frame %s" % (name, anim, row, f["box"]))
                bottom = int(ys.max())
                low = ys >= bottom - (FOOT_ROWS - 1)
                frames.append({"img": img, "box": f["box"], "board": acfg["board"],
                               "mirror": bool(f.get("mirror", False)),
                               "bottom_board": int(f["box"][1] + bottom),
                               "foot_cx": int(round(xs[low].mean()))})
            cut[anim][row] = frames
        # A facing given as the mirror of another: the same frames flipped.
        for row in ROWS:
            spec_row = acfg["rows"].get(row)
            if spec_row and "mirror_of" in spec_row[0]:
                src = cut[anim][spec_row[0]["mirror_of"]]
                cut[anim][row] = [dict(fr, img=fr["img"][:, ::-1].copy(), mirror=not fr["mirror"],
                                       foot_cx=fr["img"].shape[1] - 1 - fr["foot_cx"]) for fr in src]
    # Vertical anchor: the board row's ground line (its lowest foot), so each
    # frame keeps the lift the source draws. Horizontal: the feet's centre.
    for anim in cut:
        for row, frames in cut[anim].items():
            ground = max(fr["bottom_board"] for fr in frames)
            for fr in frames:
                fr["ax"] = fr["foot_cx"]
                fr["ay"] = ground - fr["box"][1] + 1     # the baseline: one below the ground row
    # One canvas: the largest reach from the anchor over every frame.
    L = R = U = D = 0
    for anim in cut:
        for frames in cut[anim].values():
            for fr in frames:
                ys, xs = np.nonzero(fr["img"][..., 3])
                L = max(L, fr["ax"] - xs.min())
                R = max(R, xs.max() + 1 - fr["ax"])
                U = max(U, fr["ay"] - ys.min())
                D = max(D, ys.max() + 1 - fr["ay"])
    L, R, U, D = int(L), int(R), int(U), int(D)
    cw, ch = PAD + L + R + PAD, PAD + U + D + PAD
    anchor = (PAD + L, PAD + U)
    return cut, (cw, ch), anchor


def place(fr, canvas, anchor):
    cw, ch = canvas
    cell = np.zeros((ch, cw, 4), np.uint8)
    img = fr["img"]
    ox, oy = anchor[0] - fr["ax"], anchor[1] - fr["ay"]
    h, w = img.shape[:2]
    # Copy only the figure's pixels (the crop's transparent margin may reach
    # past the canvas; the figure itself never does, by the canvas's sizing).
    ys, xs = np.nonzero(img[..., 3])
    cell[ys + oy, xs + ox] = img[ys, xs]
    return cell


def write_character(name, cfg, out_root, previews):
    cut, canvas, anchor = cut_character(name, cfg)
    cw, ch = canvas
    sheets = []
    for anim, rows in cut.items():
        cols = max(len(v) for v in rows.values())
        sheet = np.zeros((ch * 4, cw * cols, 4), np.uint8)
        prov = []
        for ri, row in enumerate(ROWS):
            for ci, fr in enumerate(rows.get(row, [])):
                sheet[ri * ch:(ri + 1) * ch, ci * cw:(ci + 1) * cw] = place(fr, canvas, anchor)
                prov.append({"row": row, "col": ci, "board": fr["board"], "box": fr["box"],
                             "mirror": fr["mirror"], "anchor_in_crop": [int(fr["ax"]), int(fr["ay"])]})
        d = os.path.join(out_root, cfg["path"])
        os.makedirs(d, exist_ok=True)
        p = os.path.join(d, anim + ".png")
        # Plain RGBA, lossless; no colour profile, no premultiplied alpha.
        Image.fromarray(sheet, "RGBA").save(p, optimize=False, compress_level=6)
        sheets.append({"character": cfg.get("audit_name", name), "animation": anim, "sheet": p,
                       "key": cfg["path"], "boards": [os.path.join(PAINTINGS, cfg["animations"][anim]["board"])],
                       "canvas": [cw, ch], "anchor": list(anchor), "frames": prov})
    if previews:
        write_previews(name, cut, canvas, anchor, os.path.join(out_root, "previews", name))
    print("%-16s canvas %dx%d, anchor %s, %s" % (name, cw, ch, anchor,
          ", ".join("%s %d" % (a, sum(len(v) for v in r.values())) for a, r in cut.items())))
    return sheets


# --------------------------------------------------------------------------
# Viewing aids (nearest-neighbour upscales, for viewing only)
# --------------------------------------------------------------------------

ZOOM = 4
CHECK = ((58, 58, 66), (72, 72, 80))


def _checker(w, h, s=8):
    yy, xx = np.mgrid[0:h, 0:w]
    c = ((yy // s + xx // s) % 2).astype(bool)
    out = np.zeros((h, w, 3), np.uint8)
    out[~c] = CHECK[0]
    out[c] = CHECK[1]
    return out


def _over(bg, fg):
    a = fg[..., 3:4] > 0
    return np.where(a, fg[..., :3], bg)


def _up(a, k):
    return np.repeat(np.repeat(a, k, axis=0), k, axis=1)


def write_previews(name, cut, canvas, anchor, d):
    os.makedirs(d, exist_ok=True)
    cw, ch = canvas
    gap = 2
    # Contact sheet: every frame of every animation, one line per animation
    # and facing, all at the same 4x zoom, with the anchor baseline drawn.
    lines = []
    for anim, rows in cut.items():
        for row in ROWS:
            if row in rows:
                lines.append(("%s %s" % (anim, row), [place(fr, canvas, anchor) for fr in rows[row]]))
    ncol = max(len(f) for _, f in lines)
    for z in (ZOOM, 1):
        label_w = 120
        W = label_w + ncol * (cw * z + gap)
        H = len(lines) * (ch * z + gap)
        img = Image.new("RGB", (W, H), (30, 30, 36))
        dr = ImageDraw.Draw(img)
        for li, (label, frames) in enumerate(lines):
            y = li * (ch * z + gap)
            dr.text((6, y + 6), label, fill=(220, 220, 220))
            for ci, f in enumerate(frames):
                x = label_w + ci * (cw * z + gap)
                tile = _up(_over(_checker(cw, ch, 4), f), z)
                img.paste(Image.fromarray(tile), (x, y))
                # The anchor baseline (the row under the feet) and the anchor x.
                by = y + anchor[1] * z
                dr.line([(x, by), (x + cw * z - 1, by)], fill=(255, 64, 64), width=1)
                ax = x + anchor[0] * z
                dr.line([(ax, by - 6), (ax, by + 6)], fill=(255, 64, 64), width=1)
        img.save(os.path.join(d, "%s_contact_%dx.png" % (name, z)))
    # GIFs per animation and facing, native and 4x. GIF has 1-bit
    # transparency, which suits the hard alpha; frames are quantised for GIF
    # only (the PNGs are the art).
    for anim, rows in cut.items():
        for row, frames in rows.items():
            for k, tag in ((1, "1x"), (ZOOM, "4x")):
                ims = []
                for fr in frames:
                    f = place(fr, canvas, anchor)
                    rgb = _up(_over(_checker(cw, ch, 4), f), k)
                    ims.append(Image.fromarray(rgb).convert("P", palette=Image.ADAPTIVE, colors=255))
                ims[0].save(os.path.join(d, "%s_%s_%s_%s.gif" % (name, anim, row, tag)), save_all=True,
                            append_images=ims[1:], duration=100, loop=0, disposal=2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--previews", action="store_true")
    ap.add_argument("names", nargs="*")
    args = ap.parse_args()
    cfg = json.load(open(CONFIG))
    names = args.names or [k for k in cfg if not k.startswith("_")]
    sheets = []
    for n in names:
        sheets += write_character(n, cfg[n], args.out, args.previews)
    with open(os.path.join(args.out, "manifest.json"), "w") as f:
        json.dump({"sheets": sheets}, f, indent=1)


if __name__ == "__main__":
    main()
