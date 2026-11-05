#!/usr/bin/env python3
"""Upscale a designer's board that draws a hero smaller than his other boards.

Stephen's walk board (stephen_walk_board.webp, 2026-10-31) draws him about
135 px tall where his still poses are 277 px and his right walk about 430,
so the game had to enlarge its front, back and left walks and they came out
soft beside his crisp still poses (designer, 2026-11-05: "his walking in
both directions is incorrect", "the correct resolution" being the stills').
This runs the board through Real-ESRGAN's anime model (realesrgan-x4plus-anime,
BSD-3-Clause, the ncnn build that realesrgan-ncnn-vulkan ships) at 4x on the
CPU, then brings it down to `--scale` with Lanczos, so its figures stand as
tall as the still poses' and keep a clean edge. Colour and alpha go through
the model separately, as realesrgan-ncnn-vulkan does with RGBA input.

It is a resize, not new art: the drawing, colours and proportions are the
board's own. A board the designer draws at the size of the others replaces
the output.

Needs `pip install ncnn` and the model's two files
(realesrgan-x4plus-anime.param / .bin, from the realesrgan-ncnn-vulkan
release or the realesrgan-ncnn-py wheel's models folder).

Run: python3 tools/upscale_board.py <models_dir> <in.webp> <out.webp> [--scale 2]
"""
import argparse

import numpy as np
from PIL import Image

MODEL = "realesrgan-x4plus-anime"
MODEL_SCALE = 4
TILE = 160      # px of the input a pass (with PAD round it, cut off after)
PAD = 12


def _net(models_dir):
    import ncnn  # tool dependency (pip install ncnn)
    net = ncnn.Net()
    net.opt.use_vulkan_compute = False
    net.opt.num_threads = 4
    net.load_param("%s/%s.param" % (models_dir, MODEL))
    net.load_model("%s/%s.bin" % (models_dir, MODEL))
    return net


def _run(net, rgb):
    """HxWx3 uint8 through the model: (H*4)x(W*4)x3 uint8, tile by tile."""
    import ncnn
    h, w, _ = rgb.shape
    s = MODEL_SCALE
    out = np.zeros((h * s, w * s, 3), np.float32)
    for y0 in range(0, h, TILE):
        for x0 in range(0, w, TILE):
            y1, x1 = min(h, y0 + TILE), min(w, x0 + TILE)
            py0, px0 = max(0, y0 - PAD), max(0, x0 - PAD)
            py1, px1 = min(h, y1 + PAD), min(w, x1 + PAD)
            patch = np.ascontiguousarray(rgb[py0:py1, px0:px1])
            m = ncnn.Mat.from_pixels(patch, ncnn.Mat.PixelType.PIXEL_RGB, patch.shape[1], patch.shape[0])
            m.substract_mean_normalize([], [1 / 255.0] * 3)
            ex = net.create_extractor()
            ex.input("data", m)
            _, o = ex.extract("output")
            o = np.clip(np.array(o).transpose(1, 2, 0) * 255.0, 0, 255)
            oy, ox = (y0 - py0) * s, (x0 - px0) * s
            out[y0 * s:y1 * s, x0 * s:x1 * s] = o[oy:oy + (y1 - y0) * s, ox:ox + (x1 - x0) * s]
    return out.round().astype(np.uint8)


def upscale(img, models_dir, scale):
    net = _net(models_dir)
    a = np.asarray(img.convert("RGBA"))
    rgb = _run(net, np.ascontiguousarray(a[..., :3]))
    alpha = np.ascontiguousarray(np.repeat(a[..., 3:4], 3, axis=2))
    al = _run(net, alpha).mean(axis=2).round().astype(np.uint8)
    big = Image.fromarray(np.dstack([rgb, al]), "RGBA")
    size = (round(img.width * scale), round(img.height * scale))
    # Lanczos on premultiplied colour, so the dark under the clear parts
    # never bleeds into the figure's edge.
    return big.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("models_dir")
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--scale", type=float, default=2.0)
    a = p.parse_args()
    out = upscale(Image.open(a.src), a.models_dir, a.scale)
    out.save(a.dst, lossless=True, quality=100, method=6)
    print("%s -> %s (%dx%d)" % (a.src, a.dst, out.width, out.height))


if __name__ == "__main__":
    main()
