#!/usr/bin/env python3
"""Audit the cut sprite sheets against the designer's source boards.

Every frame of every sheet is matched back to the board it was cut from
(multi-scale template matching, mirrored too) and measured:

  canvas        the cell's width x height (one size per character, or flagged)
  bbox          the opaque pixels' bounding box
  scale         source px per output px, x and y, from the match; "exact" when
                every opaque pixel equals the board's pixel at an integer offset
  new_colors    opaque pixels whose RGB is not anywhere in the matched source
                region (anything > 0 means resampled / recoloured)
  semi          pixels with 0 < alpha < 255, against the source region's own
  anchor        lowest opaque row (as a gap above the canvas bottom) and the
                horizontal centre of the bottom 4 opaque rows; the gap's
                deviation from the character's median, compared with what the
                source itself does (the frame's foot line against the other
                frames cut from the same board row)
  edge          opaque pixels on the canvas edge (clipping)

Writes <out>/frames.csv (one row per frame) and <out>/summary.md (one line per
animation with its verdict and the cause of each failure).

Run from the repo root:
  python3 tools/audit_sprite_cuts.py --sheets assets/sprites/generated \
      --out docs/sprite_audit/before [--only brad skeleton ...]
  python3 tools/audit_sprite_cuts.py --manifest <recut manifest.json> --out ...
Needs: numpy, Pillow, opencv-python-headless.
"""
import argparse
import csv
import glob
import json
import os
import re
import sys
from collections import defaultdict

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
PAINTINGS = "assets/sprites/paintings"
IMG_RE = re.compile(r"[\w./-]+\.(?:webp|png|jpg|jpeg)$", re.I)
# Strips that are effects (projectiles, bolts, smoke), not the character: no
# foot anchor to hold.
SPREAD_MIN_SCORE = 0.85   # matches below this are listed, not used for the board-scale spread
ANCHOR_TOL = 1.5      # px a foot line may sit off what the source implies
EXACT_SCALE_TOL = 0.0  # the 1:1 verdict is the exact-pixel test, not a tolerance


# --------------------------------------------------------------------------
# Which boards each output was cut from (read from the cutters' own configs)
# --------------------------------------------------------------------------

def _strings(obj):
    if isinstance(obj, str):
        if IMG_RE.search(obj):
            yield obj
    elif isinstance(obj, dict):
        for v in obj.values():
            yield from _strings(v)
    elif isinstance(obj, (list, tuple, set)):
        for v in obj:
            yield from _strings(v)


def _resolve(name):
    for p in (name, os.path.join(PAINTINGS, name)):
        if os.path.isfile(p):
            return os.path.normpath(p)
    return None


def candidate_boards():
    """{output key: [board paths]}; keys are 'sheets/<folder>' and 'heroes/<hero>'."""
    import cut_pose_boards as pb
    import cut_creature_sheets as cs
    import cut_hero_sprites as hs
    import cut_hero_actions as ha
    out = defaultdict(set)
    for name, cfg in pb.BOARDS.items():
        folder = cfg.get("into", name)
        for s in _strings(cfg):
            out["sheets/" + folder].add(s)
    for name, cfg in cs.FRAMES.items():
        for s in _strings(cfg):
            out["sheets/" + name].add(s)
    for hero in hs.HEROES:
        for table in (hs.HEROES, hs.WALKS, hs.WALK_EXTRA):
            for s in _strings(table.get(hero, ())):
                out["heroes/" + hero].add(s)
    for (hero, action), cfg in ha.ACTIONS.items():
        for s in _strings(cfg):
            out["heroes/%s_%s" % (hero, action)].add(s)
    res = {}
    for k, names in out.items():
        paths = sorted({p for p in (_resolve(n) for n in names) if p})
        res[k] = paths
    return res


# --------------------------------------------------------------------------
# Sheets -> frames
# --------------------------------------------------------------------------

def sheet_layout(path, idle_cell=None, canvas=None):
    """(kind, cell_w, cell_h, rows, cols) of a sheet: a character sheet has 4
    direction rows of square cells; an effect strip is one row of square
    cells as tall as the sheet (or several such rows)."""
    im = Image.open(path)
    w, h = im.size
    if canvas:   # a re-cut sheet: its canvas is in the manifest
        cw, ch = canvas
        return "character", cw, ch, h // ch, w // cw
    if idle_cell and h == 4 * idle_cell and w % idle_cell == 0:
        return "character", idle_cell, idle_cell, 4, w // idle_cell
    if idle_cell is None and h % 4 == 0 and w % (h // 4) == 0:
        return "character", h // 4, h // 4, 4, w // (h // 4)
    if w % h == 0:
        return "effect", h, h, 1, w // h
    raise ValueError("unknown layout %s %dx%d" % (path, w, h))


def list_sheets(root):
    """[(character, animation, path)] for the pixel sheets under root."""
    items = []
    for p in sorted(glob.glob(os.path.join(root, "heroes", "*.png"))):
        base = os.path.basename(p)[:-4]
        hero, _, action = base.partition("_")
        items.append(("hero:" + hero, action or "walk", p, "heroes/" + base, None))
    for p in sorted(glob.glob(os.path.join(root, "sheets", "*", "*.png"))):
        folder = os.path.basename(os.path.dirname(p))
        items.append((folder, os.path.basename(p)[:-4], p, "sheets/" + folder, None))
    return items


# --------------------------------------------------------------------------
# Matching a frame back to its board
# --------------------------------------------------------------------------

_BOARD_CACHE = {}
_SMALL = {}


def load_board(path):
    if path not in _BOARD_CACHE:
        im = Image.open(path)
        has_alpha = im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info)
        rgba = np.asarray(im.convert("RGBA"))
        rgb = rgba[..., :3].astype(np.float32)
        a = rgba[..., 3].astype(np.float32) / 255.0
        gray = (rgb @ np.array([0.299, 0.587, 0.114], np.float32)) * a   # on black
        _BOARD_CACHE[path] = {"rgba": rgba, "gray": gray, "has_alpha": has_alpha}
    return _BOARD_CACHE[path]


def _gray(rgba):
    rgb = rgba[..., :3].astype(np.float32)
    return rgb @ np.array([0.299, 0.587, 0.114], np.float32)


def _match(board_gray, tmpl, mask):
    """Best TM_CCOEFF_NORMED (masked) score and location."""
    if board_gray.shape[0] < tmpl.shape[0] or board_gray.shape[1] < tmpl.shape[1]:
        return -1.0, (0, 0)
    r = cv2.matchTemplate(board_gray, tmpl, cv2.TM_CCOEFF_NORMED, mask=mask)
    r = np.nan_to_num(r, nan=-1.0, posinf=-1.0, neginf=-1.0)
    _, mx, _, loc = cv2.minMaxLoc(r)
    return float(mx), loc


def _search(board, tmpl, mask, scales, aspects, roi=None):
    """Try each (scale, aspect): board resized by 1/sx, 1/sy and matched.
    Returns (score, sx, sy, x0, y0) in full board pixels."""
    g = board["gray"]
    ox = oy = 0
    if roi is not None:
        x0, y0, x1, y1 = roi
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(g.shape[1], int(x1)), min(g.shape[0], int(y1))
        g = g[y0:y1, x0:x1]
        ox, oy = x0, y0
    best = (-2.0, 1.0, 1.0, 0, 0)
    th, tw = tmpl.shape
    for s in scales:
        for a in aspects:
            sy = s
            sx = s / a
            nw, nh = int(round(g.shape[1] / sx)), int(round(g.shape[0] / sy))
            if nw < tw or nh < th:
                continue
            if abs(sx - 1) < 1e-9 and abs(sy - 1) < 1e-9:
                gs = g
            else:
                gs = cv2.resize(g, (nw, nh), interpolation=cv2.INTER_AREA)
            sc, loc = _match(gs, tmpl, mask)
            if sc > best[0]:
                fx = g.shape[1] / nw
                fy = g.shape[0] / nh
                best = (sc, fx, fy, ox + loc[0] * fx, oy + loc[1] * fy)
    return best


def _geom(lo, hi, step):
    out = [lo]
    while out[-1] * step < hi:
        out.append(out[-1] * step)
    return out


def match_frame(frame_rgba, boards, hint=None, aspects=(1.0,)):
    """Find the frame (its opaque bbox) on one of the boards.
    `hint`: a previous match (board, flip, sx, sy) to try first."""
    a = frame_rgba[..., 3]
    ys, xs = np.nonzero(a)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = frame_rgba[y0:y1, x0:x1]
    mask = (crop[..., 3] > 0).astype(np.float32)
    base = _gray(crop) * (crop[..., 3].astype(np.float32) / 255.0)
    th, tw = base.shape
    results = []

    def run(path, flip, scales, aspects):
        """Coarse pass at reduced resolution: template ~48 px on its long side.
        Returns (score, sx, sy, x, y) in full-resolution terms."""
        b = load_board(path)
        t = base[:, ::-1].copy() if flip else base
        m = mask[:, ::-1].copy() if flip else mask
        k = max(1.0, max(th, tw) / 48.0)
        tws, ths = max(4, int(round(tw / k))), max(4, int(round(th / k)))
        ts = cv2.resize(t, (tws, ths), interpolation=cv2.INTER_AREA)
        ms = (cv2.resize(m, (tws, ths), interpolation=cv2.INTER_AREA) > 0.5).astype(np.float32)
        if ms.sum() < 8:
            return None
        key = (path, round(k, 3))
        if key not in _SMALL:
            H, W = b["gray"].shape
            _SMALL[key] = cv2.resize(b["gray"], (max(1, int(round(W / k))), max(1, int(round(H / k)))), interpolation=cv2.INTER_AREA)
        small = _SMALL[key]
        kbx = b["gray"].shape[1] / small.shape[1]
        kby = b["gray"].shape[0] / small.shape[0]
        sc, fx, fy, bx, by = _search({"gray": small}, ts, ms, scales, aspects)
        return (sc, fx * kbx * tws / tw, fy * kby * ths / th, bx * kbx, by * kby)

    def refine(path, flip, sx, sy, bx, by):
        b = load_board(path)
        t = base[:, ::-1].copy() if flip else base
        m = mask[:, ::-1].copy() if flip else mask
        best = None
        cs, ca = sy, sy / sx
        for rnd, (span, step, aspan, astep) in enumerate(((0.07, 1.015, 0.07, 1.02), (0.016, 1.004, 0.012, 1.006))):
            scales = [cs * f for f in _geom(1 - span, 1 + span, step)]
            aspects = [ca * f for f in _geom(1 - aspan, 1 + aspan, astep)]
            mx = 0.15 * tw * cs + 8
            my = 0.15 * th * cs + 8
            roi = (bx - mx, by - my, bx + tw * cs / ca + mx, by + th * cs + my)
            r = _search(b, t, m, scales, aspects, roi)
            if best is None or r[0] >= best[0]:
                best = r
            _, sx_, sy_, bx, by = best
            cs, ca = sy_, sy_ / sx_
        # Is it exactly 1:1? Try integer offsets around the match.
        sc, sx_, sy_, bx, by = best
        exact = 0.0
        if abs(sx_ - 1) < 0.03 and abs(sy_ - 1) < 0.03:
            exact, (bx, by) = exact_test(b["rgba"], crop, flip, int(round(bx)), int(round(by)))
            if exact == 1.0:
                sx_ = sy_ = 1.0
        return {"board": path, "flip": flip, "score": sc, "sx": sx_, "sy": sy_, "x": bx, "y": by,
                "exact": exact}

    candidates = []
    if hint is not None:
        hb, hf, hsx, hsy = hint
        r = run(hb, hf, [hsy * f for f in _geom(0.9, 1.11, 1.03)], [hsy / hsx])
        if r:
            candidates.append((r[0], hb, hf, r))
    if not candidates or candidates[0][0] < 0.9:   # a weak hint: search every board too
        for path in boards:
            for flip in (False, True):
                r = run(path, flip, _geom(0.95, 8.5, 1.04), aspects)
                if r:
                    candidates.append((r[0], path, flip, r))
    if not candidates:
        return None, (x0, y0, x1, y1)
    candidates.sort(key=lambda c: -c[0])
    # Refine the best two coarse candidates, keep the better.
    fine = []
    for sc, path, flip, r in candidates[:2]:
        fine.append(refine(path, flip, r[1], r[2], r[3], r[4]))
    fine.sort(key=lambda f: -f["score"])
    return fine[0], (x0, y0, x1, y1)


def exact_test(board_rgba, crop, flip, bx, by, reach=3):
    """Share of the crop's opaque pixels whose RGB equals the board's at the
    best integer offset within `reach` of (bx, by)."""
    c = crop[:, ::-1] if flip else crop
    h, w = c.shape[:2]
    m = c[..., 3] > 0
    n = int(m.sum())
    best, bxy = 0.0, (bx, by)
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            x, y = bx + dx, by + dy
            if x < 0 or y < 0 or y + h > board_rgba.shape[0] or x + w > board_rgba.shape[1]:
                continue
            reg = board_rgba[y:y + h, x:x + w, :3]
            eq = np.all(reg == c[..., :3], axis=2) & m
            f = eq.sum() / n
            if f > best:
                best, bxy = f, (x, y)
    return float(best), bxy


def _pack_rgb(a):
    a = a.astype(np.uint32)
    return (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]


def palette_check(frame_crop, board, m, pad=3):
    """(new-colour pixels, new distinct colours, source semi-transparent px)
    of an opaque crop against the source region the match covers."""
    rgba = board["rgba"]
    h, w = frame_crop.shape[:2]
    x0 = int(np.floor(m["x"])) - pad
    y0 = int(np.floor(m["y"])) - pad
    x1 = int(np.ceil(m["x"] + w * m["sx"])) + pad
    y1 = int(np.ceil(m["y"] + h * m["sy"])) + pad
    reg = rgba[max(0, y0):max(0, y1), max(0, x0):max(0, x1)]
    src = np.unique(_pack_rgb(reg[..., :3]))
    op = frame_crop[..., 3] > 0
    px = _pack_rgb(frame_crop[..., :3])[op]
    new = ~np.isin(px, src)
    semi_src = int(((reg[..., 3] > 0) & (reg[..., 3] < 255)).sum()) if board["has_alpha"] else 0
    return int(new.sum()), int(len(np.unique(px[new]))), semi_src, (max(0, x0), max(0, y0), x1, y1)


# --------------------------------------------------------------------------
# The audit
# --------------------------------------------------------------------------

def frames_of(path, layout):
    kind, cw, ch, rows, cols = layout
    im = np.asarray(Image.open(path).convert("RGBA"))
    for r in range(rows):
        for c in range(cols):
            cell = im[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw]
            yield r, c, cell


def audit(items, boards_for, out_dir, jobs=4):
    os.makedirs(out_dir, exist_ok=True)
    by_char = defaultdict(list)
    for char, anim, path, key, canvas in items:
        by_char[char].append((anim, path, key, canvas))
    work = [(c, by_char[c], {k: boards_for.get(k, []) for _, _, k, _ in by_char[c]}) for c in sorted(by_char)]
    rows_out = []
    if jobs > 1:
        import multiprocessing as mp
        with mp.Pool(jobs) as pool:
            for rows in pool.imap(_audit_character, work):
                rows_out.extend(rows)
    else:
        for w in work:
            rows_out.extend(_audit_character(w))
    write_reports(rows_out, out_dir)
    return rows_out


def _audit_character(work):
    char, entries, boards_for = work
    log = lambda m: print(m, flush=True)
    if True:
        idle_cell = None
        if not char.startswith("hero:"):
            idle = [p for a, p, k, _ in entries if a == "Idle"]
            if idle:
                idle_cell = Image.open(idle[0]).size[1] // 4
        char_rows = []
        for anim, path, key, canvas in entries:
            layout = sheet_layout(path, idle_cell, canvas)
            kind = layout[0]
            boards = boards_for.get(key, [])
            hint = {}
            for r, c, cell in frames_of(path, layout):
                a = cell[..., 3]
                rec = {"character": char, "animation": anim, "sheet": path, "kind": kind,
                       "row": r, "col": c, "canvas_w": cell.shape[1], "canvas_h": cell.shape[0]}
                if not (a > 0).any():
                    rec["empty"] = 1
                    char_rows.append(rec)
                    continue
                rec["empty"] = 0
                ys, xs = np.nonzero(a)
                rec.update(bbox_x0=int(xs.min()), bbox_y0=int(ys.min()),
                           bbox_w=int(xs.max() - xs.min() + 1), bbox_h=int(ys.max() - ys.min() + 1))
                rec["semi"] = int(((a > 0) & (a < 255)).sum())
                rec["edge"] = "".join(k for k, v in (("T", a[0]), ("B", a[-1]), ("L", a[:, 0]), ("R", a[:, -1])) if (v > 0).any())
                bottom = int(ys.max())
                rec["foot_gap"] = cell.shape[0] - 1 - bottom
                low = ys >= bottom - 3
                rec["foot_cx"] = round(float(xs[low].mean()), 1)
                asp = (1.0, 1.12) if char.startswith("hero:") else (1.0,)
                m, (fx0, fy0, fx1, fy1) = match_frame(cell, boards, hint.get(r, hint.get("last")), asp) if boards else (None, None)
                if m is None:
                    rec.update(board="", score="", sx="", sy="", exact="", new_px="", new_colors="", src_semi="")
                else:
                    hint[r] = hint["last"] = (m["board"], m["flip"], m["sx"], m["sy"])
                    crop = cell[fy0:fy1, fx0:fx1]
                    new_px, new_cols, semi_src, reg = palette_check(crop, load_board(m["board"]), m)
                    rec.update(board=os.path.basename(m["board"]), flip=int(m["flip"]),
                               score=round(m["score"], 3), sx=round(m["sx"], 3), sy=round(m["sy"], 3),
                               src_x=round(m["x"], 1), src_y=round(m["y"], 1), exact=round(m["exact"], 4),
                               new_px=new_px, new_colors=new_cols, src_semi=semi_src,
                               # the source's own foot line for this frame (board px)
                               src_bottom=round(m["y"] + (bottom - fy0 + 1) * m["sy"], 1))
                char_rows.append(rec)
            log("  %-22s %-10s %s" % (char, anim, "%d frames" % sum(1 for x in char_rows if x["animation"] == anim and not x["empty"])))
        judge_character(char_rows)
        return char_rows


def judge_character(rows):
    """Fill in the per-frame flags that need the whole character."""
    live = [r for r in rows if not r["empty"]]
    canv = sorted({(r["canvas_w"], r["canvas_h"]) for r in rows if r["kind"] == "character"})
    # Foot line: relative to the canvas bottom, against the character's median.
    chars = [r for r in live if r["kind"] == "character"]
    # (per canvas size: a gap means nothing across canvases of other sizes)
    med = {}
    for size in {(r["canvas_w"], r["canvas_h"]) for r in chars}:
        med[size] = float(np.median([r["foot_gap"] for r in chars if (r["canvas_w"], r["canvas_h"]) == size]))
    medx = {}
    for row in range(4):
        xs = [r["foot_cx"] - r["canvas_w"] / 2 for r in chars if r["row"] == row]
        medx[row] = float(np.median(xs)) if xs else 0.0
    # What the source does: within one animation row cut from one board, the
    # frames' source foot lines against the row's lowest (in output px).
    groups = defaultdict(list)
    for r in chars:
        if r.get("board"):
            groups[(r["animation"], r["row"], r["board"])].append(r)
    for g in groups.values():
        ground = max(r["src_bottom"] for r in g)
        for r in g:
            r["src_lift"] = round((ground - r["src_bottom"]) / r["sy"], 1)
    for g in groups.values():
        lifts = [r["foot_gap"] for r in g]
        base = min(lifts)
        for r in g:
            r["out_lift"] = r["foot_gap"] - base
    for r in rows:
        r["canvas_sizes"] = ";".join("%dx%d" % c for c in canv)
        fails = []
        if r["empty"]:
            r["fails"] = ""
            continue
        if r["kind"] == "character" and len(canv) > 1:
            fails.append("canvas")
        if r.get("board") == "":
            fails.append("unmatched")
        else:
            if r["exact"] != 1.0:
                fails.append("scale")
            if r["new_px"] > 0:
                fails.append("blur/colour")
            if r["semi"] > r["src_semi"]:
                fails.append("semi-alpha")
        if r["edge"]:
            fails.append("clipping")
        if r["kind"] == "character":
            r["foot_dev"] = round(r["foot_gap"] - med[(r["canvas_w"], r["canvas_h"])], 1)
            r["foot_cx_dev"] = round(r["foot_cx"] - r["canvas_w"] / 2 - medx[r["row"]], 1)
            # Verdict against the source: the frame's foot line, relative to
            # its board row's, must lift as far as the source's does.
            if "src_lift" in r and abs(r["out_lift"] - r["src_lift"]) > ANCHOR_TOL:
                fails.append("anchor")
        r["fails"] = ",".join(fails)


FIELDS = ["character", "animation", "row", "col", "kind", "canvas_w", "canvas_h", "canvas_sizes",
          "empty", "bbox_x0", "bbox_y0", "bbox_w", "bbox_h", "board", "flip", "score", "sx", "sy",
          "src_x", "src_y", "exact", "new_px", "new_colors", "semi", "src_semi", "foot_gap",
          "foot_dev", "foot_cx", "foot_cx_dev", "src_lift", "out_lift", "edge", "fails", "sheet"]


def write_reports(rows, out_dir):
    with open(os.path.join(out_dir, "frames.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, FIELDS, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)
    anims = defaultdict(list)
    for r in rows:
        if not r["empty"]:
            anims[(r["character"], r["animation"])].append(r)
    lines = ["# Sprite cut audit", "",
             "One line per animation. A frame passes only with every check clean.",
             "Causes: `scale` = not an exact 1:1 crop of the source; `blur/colour` = colours not in the",
             "source region (resampling, palette tidy, recolouring); `semi-alpha` = more semi-transparent",
             "pixels than the source region; `anchor` = foot line moves where the source's does not;",
             "`clipping` = opaque pixels on the canvas edge; `canvas` = the character's frames use more",
             "than one canvas size; `unmatched` = no source board found.", ""]
    n_pass = n_fail = f_pass = f_fail = 0
    lines.append("| character | animation | frames | failing | causes (frames) | sx range | sy range | canvases | edges touched |")
    lines.append("|---|---|---|---|---|---|---|---|---|")
    for (char, anim), fs in sorted(anims.items()):
        bad = [r for r in fs if r["fails"]]
        causes = defaultdict(int)
        for r in bad:
            for c in r["fails"].split(","):
                causes[c] += 1
        sxs = [r["sx"] for r in fs if r.get("sx") not in ("", None)]
        sys_ = [r["sy"] for r in fs if r.get("sy") not in ("", None)]
        rng = lambda v: ("%.2f-%.2f" % (min(v), max(v))) if v else "-"
        edges = defaultdict(int)
        for r in fs:
            for e in r["edge"]:
                edges[e] += 1
        lines.append("| %s | %s | %d | %d | %s | %s | %s | %s | %s |" % (
            char, anim, len(fs), len(bad),
            ", ".join("%s (%d)" % kv for kv in sorted(causes.items())) or "PASS",
            rng(sxs), rng(sys_), fs[0]["canvas_sizes"] or "%dx%d" % (fs[0]["canvas_w"], fs[0]["canvas_h"]),
            " ".join("%s:%d" % kv for kv in sorted(edges.items())) or "-"))
        if bad:
            n_fail += 1
        else:
            n_pass += 1
        f_fail += len(bad)
        f_pass += len(fs) - len(bad)
    # How differently the source boards draw each character: the median
    # source-px-per-output-px of each (animation, board), and the spread of
    # those, after the output's own scale is taken out (output bbox height vs
    # the front idle's is not used: poses differ). A spread > 1 means a 1:1
    # re-cut shows the character at different sizes in different animations.
    lines += ["", "## Source drawing scale per character", "",
              "Median source px per output px (sy) for each animation's board, and the spread",
              "(largest / smallest). The old cuts hold each character near one on-screen size, so a",
              "spread above 1 is how much bigger one board draws the character than another: a 1:1",
              "crop of both cannot show the character at one size.",
              "", "| character | (animation: board sy) | board-scale spread |", "|---|---|---|"]
    per = defaultdict(lambda: defaultdict(list))
    for r in rows:
        if not r["empty"] and r.get("board") and r["kind"] == "character" and r["score"] >= SPREAD_MIN_SCORE:
            per[r["character"]][(r["animation"], r["board"])].append(r["sy"])
    for char in sorted(per):
        meds = {k: float(np.median(v)) for k, v in per[char].items()}
        spread = max(meds.values()) / min(meds.values())
        lines.append("| %s | %s | %.2f |" % (char, "; ".join("%s: %s %.2f" % (a, b, v) for (a, b), v in sorted(meds.items())), spread))
    # Matches too weak to trust for the numbers above (the verdicts do not
    # rest on them: a weak match still cannot be an exact 1:1 crop).
    weak = [r for r in rows if not r["empty"] and r.get("board") and r["score"] < SPREAD_MIN_SCORE]
    lines += ["", "## Weak matches (score < %.2f)" % SPREAD_MIN_SCORE, "",
              "Frames whose best match on any board is weak: mostly effects (smoke, bolts, a vortex)",
              "whose cut was recoloured or faded, or figures whose cut differs a lot from the board.",
              "Their sx/sy are left out of the spread above; their verdicts stand (a weak match",
              "cannot be an exact 1:1 crop either).", "",
              "| character | animation | frames | best board | score range |", "|---|---|---|---|---|"]
    wg = defaultdict(list)
    for r in weak:
        wg[(r["character"], r["animation"])].append(r)
    for (c, a), fs in sorted(wg.items()):
        lines.append("| %s | %s | %d | %s | %.2f-%.2f |" % (c, a, len(fs), fs[0]["board"],
                     min(r["score"] for r in fs), max(r["score"] for r in fs)))
    lines[8:8] = ["**%d animations pass, %d fail; %d frames pass, %d fail.**" % (n_pass, n_fail, f_pass, f_fail), ""]
    with open(os.path.join(out_dir, "summary.md"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines[8:9]))


def read_csv(path):
    ints = {"row", "col", "canvas_w", "canvas_h", "empty", "bbox_x0", "bbox_y0", "bbox_w", "bbox_h", "flip",
            "new_px", "new_colors", "semi", "src_semi", "foot_gap"}
    floats = {"score", "sx", "sy", "src_x", "src_y", "exact", "foot_dev", "foot_cx", "foot_cx_dev", "src_lift", "out_lift"}
    rows = []
    for r in csv.DictReader(open(path)):
        for k in list(r):
            if r[k] == "":
                if k in ints | floats:
                    r[k] = "" if k in ("score", "sx", "sy") else r[k]
                continue
            if k in ints:
                r[k] = int(float(r[k]))
            elif k in floats:
                r[k] = float(r[k])
        rows.append(r)
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheets", default="assets/sprites/generated")
    ap.add_argument("--manifest", help="a re-cut manifest (tools/recut_sprites.py) instead of --sheets")
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--resummarize", action="store_true", help="rebuild summary.md from <out>/frames.csv")
    args = ap.parse_args()
    if args.resummarize:
        write_reports(read_csv(os.path.join(args.out, "frames.csv")), args.out)
        return
    if args.manifest:
        man = json.load(open(args.manifest))
        items = [(e["character"], e["animation"], e["sheet"], e["key"], tuple(e["canvas"])) for e in man["sheets"]]
        boards_for = defaultdict(list)
        for e in man["sheets"]:
            boards_for[e["key"]] = sorted(set(boards_for[e["key"]]) | set(e["boards"]))
    else:
        items = list_sheets(args.sheets)
        boards_for = candidate_boards()
    if args.only:
        items = [i for i in items if i[0].split(":")[-1] in args.only]
    audit(items, boards_for, args.out, args.jobs)


if __name__ == "__main__":
    main()
