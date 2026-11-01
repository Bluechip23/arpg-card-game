"""The smooth (non-pixelated) versions of the figures cut from the designer's
art (designer, 2026-10-25): the same cut-outs, resampled to SMOOTH_DENSITY
texels a tile with a soft filter and soft alpha (no on/off edges, no palette
tidy, no ink outline), drawn by the game with linear filtering and mipmaps.

Every cutter writes these next to its pixel sheets, into
assets/sprites/generated/smooth/ (same folder names), so the game can switch
between the two looks (ArtStyle.SMOOTH) and the pixel sheets stay on hand.
"""
import numpy as np
from PIL import Image

SMOOTH_DENSITY = 128   # texels a tile: 1:1 with the screen at the closest zoom
ROOT = "assets/sprites/generated/smooth"
SHEET_BLEED = 14   # px of edge colour out past the figure on a packed sheet (mip 3 at zoom 1 reads 8)


def to_image(frame) -> Image.Image:
    """A cut-out as a PIL RGBA image: a PIL image as is, or an array (uint8
    RGBA, or float colour 0..255 with alpha 0..1)."""
    if isinstance(frame, Image.Image):
        return frame.convert("RGBA")
    a = np.asarray(frame)
    if a.dtype != np.uint8:
        a = np.dstack([np.clip(a[..., :3], 0, 255), np.clip(a[..., 3:4] * 255, 0, 255)]).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def bleed(img: Image.Image, passes: int = 6) -> Image.Image:
    """Give the transparent pixels round the figure the colour of the figure's
    edge (alpha unchanged), so linear filtering and mipmaps never blend a
    dark fringe in from the empty pixels' black."""
    a = np.asarray(img).astype(np.float32)
    rgb, al = a[..., :3], a[..., 3]
    # Only the solid figure seeds the bleed: a half-covered edge pixel
    # carries the painted outline's dark, which must not spread.
    have = al >= 255
    if not have.any():
        have = al > 0
    for _ in range(passes):
        if have.all():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros(have.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(have, (dy, dx), (0, 1))
            acc += np.roll(rgb, (dy, dx), (0, 1)) * sh[..., None]
            cnt += sh
        new = ~have & (cnt > 0)
        rgb[new] = acc[new] / cnt[new][:, None]
        have = have | new
    out = np.dstack([rgb, al]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def resample(frame, factor: float) -> Image.Image:
    """Scale a cut-out by 1/factor (down for factor > 1, up below 1) with a
    sharp but smooth (Lanczos) filter on premultiplied colour, keeping the
    soft alpha, then bleed the edge colour outwards."""
    img = to_image(frame)
    size = (max(1, round(img.width / factor)), max(1, round(img.height / factor)))
    out = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    return bleed(out)


def trim(img: Image.Image) -> Image.Image:
    box = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return img.crop(box) if box else img


def pack(rows: list, cell: int, cols: int, pick, air: int = 1) -> Image.Image:
    """Frames bottom-centred into square cells, rows top to bottom (pasted
    without a mask: the cells are empty, and a masked paste would square the
    soft alpha). `air`: empty rows under the feet, as the pixel sheet has."""
    sheet = Image.new("RGBA", (cell * cols, cell * len(rows)))
    for ri, row in enumerate(rows):
        for ci in range(cols):
            f = pick(row, ci)
            sheet.paste(f, (ci * cell + (cell - f.width) // 2, ri * cell + cell - air - f.height))
    # Bled far: the game's mipmaps (zoomed out) average the empty pixels'
    # colour into the edge, and the import's own border fix reaches a pixel.
    return bleed(sheet, SHEET_BLEED)
