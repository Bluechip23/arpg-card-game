# Phase 0 — Visual Systems Audit

Read-only survey of the project's visual state before the Secret-of-Mana style
restructure. Architecture decision (confirmed with owner): the battle world
stays **3D with billboard sprites**; the SoM spec is adapted to that, with the
world rendered low-res in a SubViewport and UI composited at full resolution.
UI conformance is a separate later milestone.

## 1. Scene / rendering structure

- `scenes/core/main.tscn` — the whole battle. `Main` (Node3D) with `Camera3D`
  (perspective, fov 60, free-orbit), `WorldEnvironment`, `DirectionalLight3D`
  (shadow-casting), `GroundPlane` (PlaneMesh), grid/turn/tempo managers,
  `Player` instance, and a full-res `UI` CanvasLayer (cards, HUD).
  There is **no SubViewport**: the 3D world renders at window resolution
  (1280×720, stretch mode `viewport`).
- Player visual: `scripts/character/sprite_figure.gd` (billboard Sprite3D
  paper-doll/NPC sheets) chosen at `scripts/character/player.gd:92`;
  procedural-mesh `CharacterFigure` remains as fallback.
- Enemy visual: `scripts/battle/sprite_enemy_figure.gd` (billboard battlers /
  NPC humanoids) chosen at `scripts/battle/enemy.gd:_setup_sprite()`;
  procedural `EnemyFigure` fallback for generic MINION/ELITE/BOSS tiers.
- Terrain: `scripts/core/dungeon_manager.gd` `_build_floor_visuals/_build_walls/
  _build_elevation_visuals` — MultiMesh BoxMesh instances, vertex-color tinted,
  now with triplanar pixel textures (`assets/textures/tile_*.png`).
- Other 3D viewports: character select cards
  (`scripts/character/character_card.gd:322`), character sheet portrait
  (`scripts/character/character_panel.gd:486`), enemy inspect
  (`scripts/ui/enemy_inspect_ui.gd:147`) — each its own SubViewport + lights.

## 2. Textures (595 PNGs)

| Group | Files | Sizes | Sampled color counts |
|---|---|---|---|
| `assets/sprites/SeedcharacterBase/**` (purchased, reference) | ~490 | 512×512, 256×256 | ≤ ~50/sheet (many low) |
| `assets/sprites/NPCpackage1,2/**` (purchased, reference) | ~90 | 128×256 | ≤ ~40/sheet |
| `assets/sprites/MonsterKit/` (purchased, reference) | 1 | 512×193 | ~100 across 24 battlers |
| `assets/sprites/generated/**` (ours, derived) | 14 | 512×512, 64×64 | inherit source |
| `assets/textures/tile_*.png` (ours, procedural) | 4 | 32×32 | **74 (tile_grass)**, 60+ others — over budget |
| `assets/ui/*.png` (ours) | 2 | 26×34 | 7 |
| `assets/characters/*_south.png` (legacy portraits) | 5 | 56×56 | ≤36 |

Violations to fix in Phase 3: the 4 procedural tile textures exceed any
sensible ramp budget (random ±noise generated up to 74 uniques); generated
recolors inherit purchased-pack palettes (acceptable — derived from reference).

## 3. Scale / pixel-size / filtering

- 2D demo (`scripts/demo/sprite_character.gd`): all sprites scale (1,1) ✔,
  nearest filter ✔ (line 117).
- 3D billboards: `SpriteFigure.PIXEL_SIZE = 0.034`; NPC-mode enemies use
  `PIXEL_SIZE * 1.15` (`sprite_enemy_figure.gd:131`) — a **fractional pixel
  scale mismatch** (world pixels differ per entity class; visible as differing
  texel densities). Battlers use 0.032; party figures 0.034.
- Project default 2D filter: nearest ✔ (`project.godot`
  `textures/canvas_textures/default_texture_filter=0`).
- Sprite3D/materials set `TEXTURE_FILTER_NEAREST` at: `sprite_figure.gd`,
  `sprite_enemy_figure.gd:125`, `enemy.gd:1235,3063`, `dungeon_manager.gd:1024`,
  various UI icon scripts. No systemic import-level enforcement.
- Import settings (spot check `monster battler set.png.import`):
  `compress/mode=0` (lossless) ✔, `mipmaps/generate=false` ✔. 3D usage has not
  triggered `detect_3d` mipmap regeneration because materials set filters
  explicitly. Risk noted; Phase 2 will pin imports project-wide.

## 4. Lighting — every light in the project

| Where | Direction (rot_degrees) | Notes |
|---|---|---|
| `scenes/core/main.tscn` DirectionalLight3D | pitch ≈ −50°, **yaw 0** | light from screen-top, NOT upper-left; casts real shadows |
| `character_card.gd:356` key | (−38, **+28**, 0) | from upper-RIGHT |
| `character_panel.gd:501` key | (−42, **+28**, 0) | from upper-RIGHT |
| `tests/_capture_anim.gd:31` key | (−42, **+28**, 0) | from upper-RIGHT |
| fills in the above | yaw −40..−42 | opposing fill |

The purchased sprite art itself is lit from **top / slightly upper-left**
(Mana Seed convention) and billboards render `shaded = false`, so sprites are
immune to scene lights; the inconsistency only affects shaded geometry
(terrain boxes, procedural figures, props). Unify in Phase 5.

## 5. Shadows — current handling

- `CharacterFigure` (procedural): flat cylinder disc, α 0.28
  (`character_figure.gd:96-110`) — closest match to spec today.
- `EnemyFigure` (procedural): no contact shadow.
- `SpriteFigure` (party billboards): **no shadow node**.
- `SpriteEnemyFigure` (battler billboards): no shadow node; several battler
  cells have a **painted** elliptical shadow baked into the art (bee, hawk,
  bat, carpet, sword — the flyers) while grounded battlers have none.
- `DirectionalLight3D.shadow_enabled = true` in main.tscn — engine-cast soft
  shadows on terrain from 3D geometry; billboards (double-sided quads) also
  cast thin sliver shadows. Violates the "discrete flat shadows only" rule.

## 6. Animation timings (already near spec)

- Party walk 135 ms/frame (~7.4 fps), NPC walk 180 ms (~5.6 fps), attacks
  160/65/65/200 ms (strike frames briefly ~15 fps — matches the pack's own
  recommended timing; noted for VERIFY_PASS1 tolerance).
- Hit flash is currently a `modulate` tween (`sprite_figure.gd:flash`,
  `sprite_enemy_figure.gd:flash`) — spec wants a 2-frame hard palette flash.
- Procedural motion (tweens for lunge/hop) exists on billboard *positions*
  (whole-sprite translation), not frame interpolation — allowed under the 3D
  adaptation; no rotation of pixel art except the enemy "waddle" ±0.05 rad
  z-rock (`sprite_enemy_figure.gd:_process`) — borderline, review Phase 7.

## 7. Cameras

- Main battle: free orbit (any yaw), pitch clamp −80°..−9°, scroll zoom
  8..30 (`main.gd:327-340,549-560,7123+`). Free yaw defeats a fixed light/
  sprite-facing relationship; Phase 2 quantizes.
- Character select/panel/inspect SubViewports: fixed cameras ✔.

## 8. Known off-spec items carried forward

- Terrain decorations (`_build_decorations`: rocks, shrubs, crates, sewer
  pipes) are untextured colored boxes/cylinders — logged for ART_TODO /
  texture pass.
- Yellow "chest" prop in battle is a flat-colored box.
- `assets/characters/*_south.png` legacy portraits only feed the palette
  sampler of the procedural figures; unused by sprite pipeline.
