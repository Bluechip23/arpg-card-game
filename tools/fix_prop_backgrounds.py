#!/usr/bin/env python3
"""Strip opaque background fills from prop billboards.

fern/rock/stump were exported with an opaque dark backing rectangle, which
renders in-game as a floating navy panel behind the art. Flood-fills every
border-connected pixel of the backing color to transparent, leaving interior
outline pixels (same color) untouched.
"""
from collections import deque
from PIL import Image

TARGETS = ["fern", "rock", "stump", "tree", "bush"]

for name in TARGETS:
    path = f"assets/textures/props/{name}.png"
    im = Image.open(path).convert("RGBA")
    p = im.load()
    w, h = im.size
    # Backing color = the dominant opaque color on the image border.
    counts = {}
    border = [(x, y) for x in range(w) for y in (0, h - 1)] + \
             [(x, y) for x in (0, w - 1) for y in range(h)]
    for (x, y) in border:
        c = p[x, y]
        if c[3] > 0:
            counts[c] = counts.get(c, 0) + 1
    if not counts:
        print(f"{name}: border already transparent")
        continue
    bg = max(counts, key=counts.get)
    if counts[bg] < len(border) * 0.3:
        print(f"{name}: no dominant border fill ({counts[bg]}/{len(border)}), skipped")
        continue
    q = deque((pt for pt in border if p[pt[0], pt[1]] == bg))
    seen = set(q)
    cleared = 0
    while q:
        x, y = q.popleft()
        p[x, y] = (0, 0, 0, 0)
        cleared += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and p[nx, ny] == bg:
                seen.add((nx, ny))
                q.append((nx, ny))
    im.save(path)
    print(f"{name}: cleared {cleared} background px (color {bg})")
