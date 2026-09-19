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

- **One fixed view**, shared by battle and town: north up, pitched **-65°**,
  orthographic. Constants live in `scripts/core/camera_view.gd`
  (`CameraView`); nothing else hard-codes an angle. Zoom is free (mouse
  wheel, `<` / `>`); the angle is not — the top-down packs are drawn for a
  single viewpoint, and a free orbit made their fronts, painted shadows and
  wall faces lie.
- Why -65° and not a plan view: at -90° upright billboards are edge-on. At
  -65° the ground sits within ~10% of 1:1 texel mapping (sin 65° ≈ 0.906)
  while sprites still show their painted fronts, which is how the pack art
  is drawn. Everything that depends on the pitch derives it from
  `CameraView.ground_foreshortening()` (the shadow ellipse stretch, for one)
  so the number can move without a retune.
- Screen-up is grid north (-Z); `CharacterAnimator.Direction.SOUTH` faces
  the camera. WASD still projects through the (fixed) yaw.

## 1. Resolution & scale

- World render: **640×360** inside `WorldViewport` (SubViewport), nearest
  upscaled to the window. Rationale over 320×180: enemy name/health `Label3D`s
  and the tactical zoom range become unreadable at 180p; 360p keeps chunky
  texels at every zoom while staying legible. (Flagged in OPEN_QUESTIONS.md —
  one constant to change.)
- UI renders outside the viewport at window resolution (1280×720 base).
- Sprite texel density: **`PIXEL_SIZE = 0.034`** world units per texel for
  every billboard (party, enemies, overlays). No per-entity scale factors —
  bigger creatures get bigger *art* or an integer-ish rig scale, never a
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
- MonsterKit flyer cells (bee, hawk, bat, carpet, sword) have painted shadows
  in-art — those kinds skip the shadow node (no doubles). Craftpix packs ship
  every sheet twice; always use `Without_shadow/` and let the blob do it.

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
