# Trials of Olorin — Visual Style Guide

Target: Secret of Mana (SNES, 1993), executed through this project's actual
architecture: a **3D battle scene with billboard pixel sprites** seen from a
**fixed top-down three-quarter camera**, rendered **low-resolution inside a
SubViewport**, with full-resolution UI composited on top. The purchased packs
(Mana Seed character base, Seliel NPC packs, MonsterKit battlers, and the
Craftpix top-down character packs and tilesets catalogued in
`docs/ASSET_PACKS.md`) are the *reference art*: they define the palette, the
lighting convention, the viewpoint, and the level of finish everything else
must match. They are never modified (the Craftpix fills are cropped, not
repainted). Everything we generate (tile textures, recolors, VFX, icons)
conforms to them.

## 0. Camera

- **One fixed plan view**, shared by battle and town: north up, looking
  straight down (pitched **-89°**, a degree off vertical), orthographic.
  Constants live in `scripts/core/camera_view.gd` (`CameraView`); nothing
  else hard-codes an angle. The top-down packs are 2D art: a tile is 32
  texels, a figure stands on its tile and extends north. This camera shows
  them exactly as drawn.
- **Whole-pixel texel scale.** Zoom is a texel scale of 1–4 screen pixels
  per texel (mouse wheel, `<` / `>`), never a distance; the orthographic
  size is derived from the viewport height so a texel always covers an
  integer number of pixels. The world viewport renders at full resolution.
  The window stretch is integer-scaled with an expanding aspect, so a big
  window shows more world rather than a fractionally scaled one.
- **Depth is sorting.** The one degree of tilt puts anything further south
  0.017 units nearer the camera, so billboards y-sort by row for free. Every
  billboard sprite is lifted `CameraView.SPRITE_LIFT` (0.3) off the ground,
  above any wall or plateau (walls are flat autotiled quads; `ELEV_STEP`
  is 0.06), so terrain can never draw over a figure. Height barely moves a
  point on screen; head-up labels and bars therefore sit *north* of the
  feet, and world heights map to screen-up at `HEIGHT_ON_SCREEN` (cos 65°,
  the factor the old three-quarter view had) so nothing moved.
- The view scrolls but never turns: left-drag, the arrow keys and Home
  (re-centre) move a pan offset over the follow focus; walking re-centres.
- Screen-up is grid north (-Z); `CharacterAnimator.Direction.SOUTH` faces
  the camera. WASD projects through the (fixed) yaw.

## 1. Resolution & scale

- World render: **full resolution** inside `WorldViewport` (SubViewport).
  Pixel art is scaled by the camera's whole-number texel scale (§0), never
  by a viewport downscale — the old 640×360 world put every texel on 1.4
  screen pixels and the pack art read as mush.
- UI renders outside the viewport at window resolution (1280×720 base).
  So does **world text**: every `Label3D` is mirrored by a full-resolution
  `Label` in `WorldLabelOverlay` that follows its screen position each
  frame (the Label3D itself is hidden from the cameras with `layers = 0`
  but stays the source of truth for text, colour and visibility). Text
  rendered inside the half-res world was smeared 2× — never put text in
  the world viewport.
- Sprite texel density: **`PIXEL_SIZE = 1/32`** world units per texel
  (`CameraView.PIXEL_SIZE`) for every billboard (party, enemies, props,
  overlays) — the same 32 texels per unit as the ground, so sprites and
  tiles land on the same pixel grid. No per-entity scale factors — bigger
  creatures get bigger *art* or an integer-ish rig scale, never a
  texel-density change.
- 2D pixel art is never scaled fractionally; `Sprite2D` scale stays `(1,1)`.
- Terrain: 1 world unit = 1 grid tile = one 32×32-texel texture repeat.

## 2. Master palette

- `resources/palette/master_palette.gpl` — 64 colors extracted (median-cut,
  frequency-weighted) from the reference sprites. Mirrored as autoload
  `Palette` (`resources/palette/palette.gd`), swatch:
  `resources/palette/palette_swatch.png`.
- Families (see swatch for full ramps): SKIN, LEATHER, GOLD, BLOOD, ROSE,
  FOLIAGE, TEAL, SKY, AMETHYST, STEEL, SHADOW, OBSIDIAN.
- Canonical 4-step material ramps (highlight → base → shadow → core):

| Material | Highlight | Base | Shadow | Core |
|---|---|---|---|---|
| Skin | `#f8d098` | `#f7aa7a` | `#c6a891` | `#6b533e` |
| Leather/wood | `#e09060` | `#a94c1f` | `#6b533e` | `#452e5b` |
| Foliage | `#9ad994` | `#389878` | `#206020` | `#205858` |
| Steel | `#f2fdff` | `#b6c5c5` | `#63778f` | `#3c5575` |
| Cloth (blue) | `#737ec4` | `#53539c` | `#3e6794` | `#2b2540` |

  Note the hue drift: shadows move toward blue/violet (leather core lands in
  AMETHYST; steel shadow in SKY), highlights toward yellow/warm white. This is
  the Mana Seed convention and every generated asset must reproduce it —
  a ramp that only changes value is a defect.
- Budgets: any single generated sprite/tile ≤ **15 colors + transparency**.
  Purchased sheets are exempt (audited, not enforced).

## 3. Light

- **One global light: upper-left, 45°** — `rotation_degrees ≈ (-45, -30, 0)`
  on every `DirectionalLight3D` in the project (battle, select cards, sheet
  portrait, inspect viewport, capture harnesses).
- Billboards are `shaded = false`; their light is painted into the art
  (top/upper-left in all reference packs — consistent). The scene light only
  shades terrain and props, so its direction must match the painted art.
- **No engine shadow casting** (`shadow_enabled = false`): all shadows are
  discrete flat blobs (§4). Ambient via `WorldEnvironment`; keep it flat and
  neutral so palette colors survive.
- Torch/point lights: hard, short falloff; never a big soft radius.

## 4. Shadows

- Every character and enemy carries a `Shadow` node: a flat ellipse quad on
  the ground plane (local −90° X rotation, never billboarded), created by
  `scripts/battle/blob_shadow.gd`.
- Ellipse ≈ 70% of the sprite's drawn width; hard two-step edge (core at 38%
  black, rim at 20%); **no gradient falloff**. Texture:
  `assets/textures/blob_shadow.png` (generated, 2-step, 32×16). The flat quad
  is stretched along the ground by `1 / CameraView.ground_foreshortening()`
  so the ellipse reads **2:1 on screen** — the proportion the Craftpix packs
  paint under their own figures — whatever the fixed pitch is set to.
- Anchored at the feet anchor, y ≈ 0.01 above ground; does not rotate or flip
  with facing; scales down ~20% when the body is airborne (hop/knockback).
- **Billboards pivot at the feet, never the centre.** A centred `Sprite3D` /
  billboard quad rotates about the middle of the art, so under the pitched
  battle camera its bottom edge swings below the ground anchor and the
  figure reads as sunk into the tile (or hovering, from the far side). Party
  and enemy sprites set `centered = false` with an `offset` that puts the
  art's ground row at the node origin; prop `QuadMesh`es use a
  `center_offset` of half their height; critters do the same. The ground
  row then stays glued to the tile (and the blob shadow) at the fixed pitch.
- **Depth, not draw order.** Every billboard — party, enemies, props,
  chests, critters — uses a hard alpha cut (`ALPHA_CUT_DISCARD` on
  `Sprite3D`, `TRANSPARENCY_ALPHA_SCISSOR` on prop MultiMesh materials) so it
  writes depth and sorts per pixel against walls and each other. Pixel art
  has no soft edges to lose, and blended sprites sort by node origin (a
  whole MultiMesh of stones as one object), which is what buried the player
  under the scenery. Only true translucency (blob shadows, fog, portals,
  water film) stays alpha-blended.
- Walls are drawn the way the packs draw cliffs: a flat autotiled mesh on
  the ground plane (`DungeonManager._build_cliff_walls`). Every wall tile is
  four 16px quads — the biome's ground sheet as a plateau cap, outlined on
  the sides that face floor, and along every south-facing edge the pack's
  own cliff face (fringe over base, rounded ends) from the strips cut by
  `tools/extract_craftpix_cliffs.py`. The whole wall mass is capped, so a
  level reads as one plateau world. Nothing rises above the floor, so a
  wall can never draw over a figure standing beside it (§0). Building and
  dojo interiors keep their crisp 0.06 box walls.
- MonsterKit flyer cells (bee, hawk, bat, carpet, sword) have painted shadows
  in-art — those kinds skip the shadow node (no doubles). Craftpix character
  packs ship every sheet twice; always use `Without_shadow/` and let the blob
  do it. Craftpix *props* are the exception: their painted light shadow is
  kept (it is the prop's contact shadow, drawn for this very view).

## 5. Sprites & animation

- Party frames 64×64 (base) / 32×32 (NPC models); feet on the ground line
  (base: row 44 of the cell; NPC: cell bottom). Battlers 64×64. Craftpix
  enemies: square cells (64 or 128, cell = sheet height ÷ 4), one sheet per
  animation, four direction rows (front, back, left, right in every pack so
  far) — the row map is `SpriteEnemyFigure.CP_ROWS`, never re-derived at a
  call site.
- Craftpix frame rates (`SpriteEnemyFigure.CP_FPS`): idle 5, walk 8, run 10,
  attack / hurt 12, death 10. Attack, hurt and death are one-shots; death
  holds its last frame while the corpse shrinks away.
- Cycles: walk 4–6 frames at 5.5–7.5 fps; attacks use the pack's canonical
  160/65/65/200 ms timing. Nothing animates above 12 fps sustained.
- No rotation of pixel art off-axis; no scale tweens on sprite frames.
  Whole-body *translation* (lunge, hop, shake) is allowed — it reads as
  SNES-style sprite movement. The old ±0.05 rad enemy "waddle" roll is
  removed.
- Hit flash: hard 2-frame white flash via modulate saturation
  (`(12,12,12)` multiply — everything but the darkest outline clips to white),
  held then dropped with no tween curve.
- Slash/impact VFX come from the weapon-layer sheets (white crescent, painted)
  on the strike frame only.

## 6. Terrain & environment

- Grayscale 32-texel tile textures multiplied by the location palette
  (`dungeon_manager.get_palette()`), triplanar world-mapped, nearest-filtered:
  `tile_grass`, `tile_dirt`, `tile_rock`, `tile_brick` — each authored as a
  **128×128 sheet of 4×4 distinct variants** so the repeat period is 4 tiles,
  not 1 (kills visible tiling).
- Tile textures quantized to ≤8 grays (value steps only — hue comes from the
  palette tint).
- Environment stays in the mid-value band; characters keep the darkest darks
  and brightest lights. Floors must lose the squint test against sprites.

## 7. Explicitly banned

Blur, bloom, glow, soft particles, gaussian/gradient shadows, smooth alpha
falloff, mipmapped or filtered pixel textures, fractional sprite scaling,
engine-cast sprite shadows, hue-less value-only ramps, pure `#000000`
outlines on generated art (reference art's own outlines are exempt).

## 8. UI (deferred milestone)

Bitmap font, 9-slice pixel panels, palette-conformant colors — tracked
separately; the current full-res themed UI stays until that pass.
