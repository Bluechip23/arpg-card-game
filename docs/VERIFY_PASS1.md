# Verification Pass 1 — Structural

Re-audit after Phases 0–8, checks re-run against the actual files (not
memory). Checks marked *(3D-adapted)* apply the spec's intent to the 3D
billboard architecture per the confirmed scope. Status after the fix round:
**all rows PASS or N/A.**

| Check | Status | File:Line | Notes |
|---|---|---|---|
| 2D sprite scales exactly (1,1) | PASS | `scenes/**/*.tscn` (grep `scale = Vector2` → no sprite hits); `scripts/demo/sprite_character.gd` | No Sprite2D/AnimatedSprite2D carries a scale. |
| Uniform billboard texel density *(3D-adapted)* | PASS | `scripts/character/sprite_figure.gd:49`, `scripts/battle/sprite_enemy_figure.gd:97` | Both `PIXEL_SIZE := 0.034`; NPC-enemy 1.15× multiplier removed (`sprite_enemy_figure.gd:131` now uses `PIXEL_SIZE`). Creature size differences use integer-ish rig scale only. |
| Texture imports: nearest, mipmaps off | PASS | `project.godot` (`default_texture_filter=0`); grep `mipmaps/generate=true` over `assets/**` → 0 files | Materials additionally pin `TEXTURE_FILTER_NEAREST` (`sprite_figure.gd:_make_sprite`, `sprite_enemy_figure.gd:126`, `dungeon_manager.gd:1023`). |
| Generated sprite dims multiple of 8 | PASS | see `docs/AUDIT.md` §2; `assets/ui/*.png` now 32×40 | UI icons were 26×34 (**FAIL→fixed**: padded to 32×40; badge geometry updated `scripts/cards/card_ui.gd:_ensure_cost_badges`). Tiles 128², monsters 64², blob 32×16. |
| ≤15 colors + transparency per generated sprite | PASS | `tools/conform_palette.py --check` output | UI icons 4/6; monster recolors 5–10; tiles 3–5 grays. 14 files, 0 over budget. |
| Every generated color ∈ master palette | PASS | `tools/conform_palette.py` (CIE-Lab rewrite, Phase 3 commit) | Color assets are exact palette members by construction; tile textures exempt-by-design (grayscale × runtime palette tint, ≤8-step ladder). Purchased packs exempt per owner. |
| Shadow node on every character/enemy | PASS | `scripts/character/sprite_figure.gd:111`, `scripts/battle/sprite_enemy_figure.gd:163`, `scripts/battle/blob_shadow.gd` | Hard 2-step ellipse (38%/20% black), flat quad, never billboarded/rotated with facing, airborne shrink (`sprite_figure.gd:_process`). Flyers with painted shadows excluded (`PAINTED_SHADOW_KINDS`, `sprite_enemy_figure.gd:100`). Procedural-figure fallbacks keep their spec-compatible hard disc (`character_figure.gd:96`). |
| No engine-cast shadows | PASS | `scripts/core/main.gd:388` | `shadow_enabled = false` at boot. |
| Single global light upper-left | PASS | `main.gd:384-388`, `character_card.gd:359`, `character_panel.gd:501`, `enemy_inspect_ui.gd:139`, `tests/_capture_anim.gd:31` | All keys at `(-45, -30, 0)`. |
| World geometry on the grid | PASS | `scripts/core/dungeon_manager.gd` (integer tile grid; `_build_floor_visuals` at `x+0.5, z+0.5`) | All terrain generated on 1-unit cells; `ALL DUNGEON TESTS PASSED`. |
| Y-sort / feet origin | N/A | — | 2D-only concept; 3D depth sorting + feet-anchored billboards (`sprite_figure.gd:_setup_doll` y=12px lift) serve the same role. |
| Animation ≤12 fps | PASS* | `sprite_figure.gd:46-48` | Walks 5.5–7.4 fps. Attack strike frames run 65 ms (~15 fps momentary) — this is the purchased pack's own canonical timing (`guides/using sword & shield.txt`), kept deliberately as reference-authoritative; documented exception. |
| No off-axis pixel rotation / no sprite scale tweens | PASS | `sprite_enemy_figure.gd:_process` (waddle roll removed); `blob_shadow.gd:22` (−90° flat quad, allowed) | Remaining tweens translate whole billboards only; `_guard_fx` scales the 3D rig (squash) — flagged to Pass 2 for feel review. |
| Hit flash: hard 2-frame, no tween curve | PASS | `sprite_figure.gd:flash`, `sprite_enemy_figure.gd:flash` | Snap on → 0.07 s hold → snap off; white saturating on damage. |
| Camera quantized *(3D-adapted)* | PASS | `main.gd:7434` | Orbit yaw settles to 45° steps on release. |
| Low-res world render, no filtering artifacts | PASS | `main.gd:342-379` (`WORLD_RES 640×360`, nearest `SubViewportContainer`); `docs/screens/*.png` | Screenshots show 2× chunky texels, crisp full-res UI overlay. |
| No default Godot theme in UI | N/A | — | UI is a deferred milestone per owner decision (STYLE_GUIDE §8). |
| Screenshots generated | PASS | `tools/capture_screens.gd`; `docs/screens/battle_brad.png`, `battle_ryan.png`, `character_select.png`, `sprite_viewer.png` | Harness runs under xvfb + GL. |

Fix round applied in this pass: UI icon dimensions (26×34 → 32×40 with badge
geometry update). All other rows passed on first re-audit. Regression:
`test_dungeon_gen`, `test_ally_party`, `test_hand_slots` green.
