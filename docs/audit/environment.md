# Phase 3 — environment and movement audit

Every map the player can walk, except caves, ice caves and buildings (known to be old, per your instructions), was checked by script rather than by eye:

- `tools/audit/env_dump.gd` boots each map in the real game: the overworld of worlds 1–4, then every site and boss door found on them, following doors inside interiors. It runs under a virtual display (`xvfb-run … godot --rendering-driver opengl3`), because headless Godot does not keep multimesh instance positions. For each map it writes JSON with:
  - what blocks movement: walls, pits, obstacle tiles and barricades, exactly the set `Main._player_blocked_tiles()` hands the player;
  - the elevation of every cell;
  - every drawn thing and the cells it covers: billboards by their anchor cell, multimesh props per instance, flat painted meshes (cliff walls, ledges, site blocks) by the cells their triangles paint;
  - spawn points, points of interest and sites.
- `tools/audit/env_audit.py` compares the two and walks the map from the player's start, using the game's one-elevation-level-per-step rule.

Re-run both:
```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/audit/env_dump.gd -- <dir>
```
```bash
python3 tools/audit/env_audit.py <dir> --md out.md
```

Maps checked (13, scene `scenes/core/main.tscn` with the world and interior id): `w1_boneyard`, `w1_forest_0`, `w1_graveyard_0`, `w1_mountains_0`, `w1_overworld`, `w1_ratking_lair`, `w1_sewer_0`, `w1_trolllair_0`, `w2_closet_0`, `w2_overworld`, `w2_thanatoshall`, `w3_overworld`, `w4_overworld`.

## Result

| Check | Result |
|---|---|
| Blocking tile with nothing drawn on it (obstacles, pits, barricades) | **None.** Four apparent cases in the Greenwood were climbable trees hidden under the fog of war when the map loads. |
| Wall with nothing drawn on it, beside floor the player reaches | **48 cells, all on World 4's desert overworld**: wall edges the code deliberately leaves as open sand (`_build_boundary_props`: "the rest of the edge stays open sand"). FLAGGED, listed below. Every other map draws every reachable wall edge. |
| Obstacle-looking prop the player can walk through | **205 cells** across 12 maps: decorative stumps, rocks, logs, dead trees, gravestones and two healing wells, placed on walkable cells on purpose (`_build_decorations` and the forest dressing put them on floor without claiming an obstacle tile; only trees claim one). FLAGGED, listed below. |
| Walkable floor the start cannot reach (isolated pockets) | **None.** |
| Chests, waypoints, fountains, climbable trees or site entrances out of reach | **None.** |
| Enemy spawn points on blocked cells or out of the player's reach (stuck enemies) | **None.** |
| 1-wide dead-end corridors (4+ cells) with nothing at the end | **None.** |
| Props drawn from bare primitive meshes (not pack art) | **13 pieces in 7 maps**, listed below as outdated. |

**No collision was changed.** Nothing that blocks is invisible except the desert's open-sand edges, and those are a deliberate choice in code. The walk-through props are a deliberate choice too. Both need your decision (see FLAGGED), because making a prop block would change paths and pacing.

## FLAGGED — needs your decision

1. **World 4 desert edges (48 cells): walls that look like open sand.** Either fill them with mesas, bushes or dead trees like the other worlds' boundaries, or make the open sand walkable up to a drawn edge.
2. **Decorative props you can walk through (205 cells).** Stumps, rocks, logs, dead trees, gravestones and wells: should the large ones block (claim an obstacle tile, as trees do), or stay as walk-through set dressing? Making them block changes routes and enemy paths. The forest has the most (38 stumps, 4 logs).
3. **Healing fountains are walkable on every map** (graveyard and Thanatos' Closet show a drawn well on a walkable cell). Consistent everywhere, so probably intended.
4. **The Boneyard's entrance arch** (cells (3, 14)–(3, 16)) is a ruin arch you walk under. Intended (it's the doorway), listed for completeness.

## Outdated or placeholder props (art)

Procedural meshes with no texture, which CLAUDE.md's "Art: Packs First" rule rules out wherever a pack shows the thing.

| map | cell (x, z) | what | node |
|---|---|---|---|
| w1_forest_0 | (32, 18) | dart trap posts (box + cylinder) | `DungeonVisuals/DartTrap_5/@MeshInstance3D@6362` |
| w1_forest_0 | (32, 19) | dart trap posts (box + cylinder) | `DungeonVisuals/DartTrap_5/@MeshInstance3D@6361` |
| w1_forest_0 | (53, 19) | bear trap jaws (torus ring + teeth) | `DungeonVisuals/BearTrap_8/@MeshInstance3D@6341` |
| w1_overworld | (16, 36) | building site block (box) | `DungeonVisuals/Site_building_0/@MeshInstance3D@921` |
| w1_ratking_lair | (28, 11) | bare SphereMesh, no texture | `DungeonVisuals/@Node3D@11333/@MeshInstance3D@11335` |
| w1_ratking_lair | (28, 11) | bare CylinderMesh, no texture | `DungeonVisuals/@Node3D@11333/@MeshInstance3D@11334` |
| w1_sewer_0 | (3, 14) | bare BoxMesh, no texture | `DungeonVisuals/@MultiMeshInstance3D@5324` |
| w1_sewer_0 | (45, 17) | bare BoxMesh, no texture | `DungeonVisuals/@Node3D@5300/@MeshInstance3D@5304` |
| w1_sewer_0 | (46, 22) | bare CylinderMesh, no texture | `DungeonVisuals/@Node3D@5267/@MeshInstance3D@5271` |
| w1_sewer_0 | (46, 22) | bare TorusMesh, no texture | `DungeonVisuals/@Node3D@5267/@MeshInstance3D@5269` |
| w1_sewer_0 | (37, 8) | bare SphereMesh, no texture | `DungeonVisuals/@Node3D@5214/@MeshInstance3D@5216` |
| w1_trolllair_0 | (9, 10) | bare BoxMesh, no texture | `DungeonVisuals/@MultiMeshInstance3D@12506` |
| w2_closet_0 | (19, 4) | bare BoxMesh, no texture | `DungeonVisuals/@MultiMeshInstance3D@9351` |

## Every finding, with its location

Scene: `scenes/core/main.tscn`, booted with the map's world level and interior id (`w<level>_<interior>`). Cells are grid coordinates (x, z).

| map | type | cell (x, z) | finding |
|---|---|---|---|
| w1_boneyard | FLAGGED walk-through | (3, 14) | walkable cell under undead_ruin_0.png |
| w1_boneyard | FLAGGED walk-through | (3, 15) | walkable cell under undead_ruin_1.png |
| w1_boneyard | FLAGGED walk-through | (3, 16) | walkable cell under undead_ruin_0.png |
| w1_forest_0 | FLAGGED walk-through | (28, 1) | walkable cell under forest_stump_2.png |
| w1_forest_0 | FLAGGED walk-through | (29, 1) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (30, 1) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (32, 1) | walkable cell under forest_stump_2.png |
| w1_forest_0 | FLAGGED walk-through | (26, 3) | walkable cell under forest_log_0.png |
| w1_forest_0 | FLAGGED walk-through | (25, 7) | walkable cell under forest_stump_0.png |
| w1_forest_0 | FLAGGED walk-through | (35, 7) | walkable cell under forest_stump_0.png |
| w1_forest_0 | FLAGGED walk-through | (25, 8) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (24, 10) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (27, 11) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (55, 11) | walkable cell under forest_stump_2.png |
| w1_forest_0 | FLAGGED walk-through | (59, 11) | walkable cell under forest_stump_2.png |
| w1_forest_0 | FLAGGED walk-through | (34, 12) | walkable cell under forest_stump_2.png |
| w1_forest_0 | FLAGGED walk-through | (35, 12) | walkable cell under forest_stump_2.png |
| w1_forest_0 | FLAGGED walk-through | (35, 13) | walkable cell under forest_stump_2.png |
| w1_forest_0 | FLAGGED walk-through | (10, 15) | walkable cell under forest_stump_0.png |
| w1_forest_0 | FLAGGED walk-through | (13, 16) | walkable cell under forest_log_1.png |
| w1_forest_0 | FLAGGED walk-through | (25, 16) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (26, 16) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (47, 16) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (53, 16) | walkable cell under forest_stump_2.png |
| w1_forest_0 | FLAGGED walk-through | (20, 18) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (28, 18) | walkable cell under forest_stump_0.png |
| w1_forest_0 | FLAGGED walk-through | (31, 18) | walkable cell under forest_stump_0.png |
| w1_forest_0 | FLAGGED walk-through | (32, 18) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (62, 18) | walkable cell under forest_stump_0.png |
| w1_forest_0 | FLAGGED walk-through | (42, 20) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (51, 21) | walkable cell under forest_stump_0.png |
| w1_forest_0 | FLAGGED walk-through | (6, 22) | walkable cell under forest_log_1.png |
| w1_forest_0 | FLAGGED walk-through | (13, 23) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (15, 23) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (19, 23) | walkable cell under forest_log_0.png |
| w1_forest_0 | FLAGGED walk-through | (4, 24) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (18, 24) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (36, 24) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (14, 26) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (10, 28) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (44, 28) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (54, 30) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (12, 33) | walkable cell under forest_stump_1.png |
| w1_forest_0 | FLAGGED walk-through | (50, 33) | walkable cell under forest_stump_2.png |
| w1_forest_0 | FLAGGED walk-through | (56, 33) | walkable cell under well_healing_0.png |
| w1_forest_0 | FLAGGED walk-through | (60, 33) | walkable cell under forest_stump_0.png |
| w1_graveyard_0 | FLAGGED walk-through | (6, 5) | walkable cell under field_rock_0.png |
| w1_graveyard_0 | FLAGGED walk-through | (7, 5) | walkable cell under field_rock_1.png |
| w1_graveyard_0 | FLAGGED walk-through | (11, 7) | walkable cell under field_rock_1.png |
| w1_graveyard_0 | FLAGGED walk-through | (30, 8) | walkable cell under well_healing_0.png |
| w1_graveyard_0 | FLAGGED walk-through | (33, 11) | walkable cell under field_rock_2.png |
| w1_graveyard_0 | FLAGGED walk-through | (10, 13) | walkable cell under field_stump_0.png |
| w1_mountains_0 | FLAGGED walk-through | (38, 5) | walkable cell under winter_rock_4.png |
| w1_mountains_0 | FLAGGED walk-through | (20, 6) | walkable cell under winter_rock_3.png |
| w1_mountains_0 | FLAGGED walk-through | (46, 6) | walkable cell under winter_rock_2.png |
| w1_mountains_0 | FLAGGED walk-through | (58, 9) | walkable cell under wallrock_snow_0.png |
| w1_mountains_0 | FLAGGED walk-through | (60, 9) | walkable cell under wallrock_snow_1.png |
| w1_mountains_0 | FLAGGED walk-through | (29, 11) | walkable cell under winter_rock_4.png |
| w1_mountains_0 | FLAGGED walk-through | (53, 14) | walkable cell under winter_rock_5.png |
| w1_mountains_0 | FLAGGED walk-through | (41, 16) | walkable cell under winter_rock_6.png |
| w1_mountains_0 | FLAGGED walk-through | (60, 16) | walkable cell under winter_rock_5.png |
| w1_mountains_0 | FLAGGED walk-through | (62, 16) | walkable cell under winter_rock_5.png |
| w1_mountains_0 | FLAGGED walk-through | (61, 17) | walkable cell under winter_rock_6.png |
| w1_mountains_0 | FLAGGED walk-through | (10, 18) | walkable cell under wallrock_snow_0.png |
| w1_mountains_0 | FLAGGED walk-through | (12, 18) | walkable cell under wallrock_snow_1.png |
| w1_mountains_0 | FLAGGED walk-through | (45, 20) | walkable cell under winter_rock_4.png |
| w1_mountains_0 | FLAGGED walk-through | (55, 20) | walkable cell under well_healing_0.png |
| w1_mountains_0 | FLAGGED walk-through | (31, 26) | walkable cell under winter_rock_1.png |
| w1_mountains_0 | FLAGGED walk-through | (9, 29) | walkable cell under winter_rock_4.png |
| w1_mountains_0 | FLAGGED walk-through | (14, 41) | walkable cell under winter_rock_6.png |
| w1_overworld | FLAGGED walk-through | (50, 4) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (34, 5) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (49, 5) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (12, 6) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (21, 6) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (55, 9) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (56, 9) | walkable cell under field_rock_3.png |
| w1_overworld | FLAGGED walk-through | (58, 10) | walkable cell under field_rock_2.png |
| w1_overworld | FLAGGED walk-through | (17, 12) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (15, 13) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (43, 13) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (15, 14) | walkable cell under field_rock_2.png |
| w1_overworld | FLAGGED walk-through | (44, 14) | walkable cell under field_rock_0.png |
| w1_overworld | FLAGGED walk-through | (60, 14) | walkable cell under field_rock_2.png |
| w1_overworld | FLAGGED walk-through | (60, 15) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (60, 17) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (16, 18) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (17, 18) | walkable cell under field_rock_2.png |
| w1_overworld | FLAGGED walk-through | (25, 18) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (28, 18) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (29, 18) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (17, 19) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (29, 19) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (24, 20) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (28, 20) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (51, 23) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (11, 25) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (23, 26) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (27, 26) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (62, 28) | walkable cell under field_stump_0.png |
| w1_overworld | FLAGGED walk-through | (51, 33) | walkable cell under field_rock_1.png |
| w1_overworld | FLAGGED walk-through | (29, 38) | walkable cell under well_healing_0.png |
| w1_overworld | FLAGGED walk-through | (46, 39) | walkable cell under well_healing_0.png |
| w1_overworld | FLAGGED walk-through | (48, 42) | walkable cell under field_rock_1.png |
| w1_sewer_0 | FLAGGED walk-through | (14, 9) | walkable cell under cave_rock_0.png |
| w1_sewer_0 | FLAGGED walk-through | (40, 13) | walkable cell under cave_rock_2.png |
| w1_sewer_0 | FLAGGED walk-through | (50, 15) | walkable cell under well_healing_0.png |
| w1_sewer_0 | FLAGGED walk-through | (35, 18) | walkable cell under cave_rock_2.png |
| w1_sewer_0 | FLAGGED walk-through | (43, 19) | walkable cell under cave_rock_1.png |
| w1_sewer_0 | FLAGGED walk-through | (55, 19) | walkable cell under cave_rock_5.png |
| w1_sewer_0 | FLAGGED walk-through | (1, 20) | walkable cell under cave_rock_4.png |
| w1_sewer_0 | FLAGGED walk-through | (43, 20) | walkable cell under cave_rock_3.png |
| w1_sewer_0 | FLAGGED walk-through | (16, 25) | walkable cell under cave_rock_2.png |
| w1_sewer_0 | FLAGGED walk-through | (40, 25) | walkable cell under cave_rock_6.png |
| w1_trolllair_0 | FLAGGED walk-through | (7, 6) | walkable cell under wallrock_snow_2.png |
| w1_trolllair_0 | FLAGGED walk-through | (35, 18) | walkable cell under wallrock_snow_0.png |
| w1_trolllair_0 | FLAGGED walk-through | (20, 24) | walkable cell under wallrock_snow_2.png |
| w2_closet_0 | FLAGGED walk-through | (20, 2) | walkable cell under undead_rock_2.png |
| w2_closet_0 | FLAGGED walk-through | (30, 3) | walkable cell under undead_grave_8.png |
| w2_closet_0 | FLAGGED walk-through | (18, 4) | walkable cell under undead_rock_1.png |
| w2_closet_0 | FLAGGED walk-through | (30, 6) | walkable cell under undead_rock_2.png |
| w2_closet_0 | FLAGGED walk-through | (38, 7) | walkable cell under well_healing_0.png |
| w2_closet_0 | FLAGGED walk-through | (23, 8) | walkable cell under undead_rock_3.png |
| w2_closet_0 | FLAGGED walk-through | (24, 12) | walkable cell under undead_rock_2.png |
| w2_closet_0 | FLAGGED walk-through | (16, 13) | walkable cell under undead_rock_3.png |
| w2_closet_0 | FLAGGED walk-through | (17, 13) | walkable cell under undead_rock_2.png |
| w2_closet_0 | FLAGGED walk-through | (21, 13) | walkable cell under undead_rock_1.png |
| w2_closet_0 | FLAGGED walk-through | (32, 13) | walkable cell under undead_rock_1.png |
| w2_closet_0 | FLAGGED walk-through | (39, 13) | walkable cell under undead_rock_3.png |
| w2_closet_0 | FLAGGED walk-through | (12, 14) | walkable cell under undead_rock_3.png |
| w2_closet_0 | FLAGGED walk-through | (13, 14) | walkable cell under undead_rock_2.png |
| w2_closet_0 | FLAGGED walk-through | (14, 14) | walkable cell under undead_rock_2.png |
| w2_closet_0 | FLAGGED walk-through | (23, 14) | walkable cell under undead_rock_1.png |
| w2_closet_0 | FLAGGED walk-through | (28, 14) | walkable cell under undead_rock_1.png |
| w2_closet_0 | FLAGGED walk-through | (15, 15) | walkable cell under undead_rock_3.png |
| w2_closet_0 | FLAGGED walk-through | (27, 15) | walkable cell under undead_grave_6.png |
| w2_closet_0 | FLAGGED walk-through | (27, 17) | walkable cell under undead_grave_7.png |
| w2_overworld | FLAGGED walk-through | (51, 3) | walkable cell under hell_rock_1.png |
| w2_overworld | FLAGGED walk-through | (26, 6) | walkable cell under well_healing_0.png |
| w2_overworld | FLAGGED walk-through | (31, 8) | walkable cell under hell_rock_4.png |
| w2_overworld | FLAGGED walk-through | (33, 8) | walkable cell under hell_rock_1.png |
| w2_overworld | FLAGGED walk-through | (35, 8) | walkable cell under hell_rock_2.png |
| w2_overworld | FLAGGED walk-through | (28, 15) | walkable cell under hell_rock_2.png |
| w2_overworld | FLAGGED walk-through | (7, 26) | walkable cell under hell_rock_4.png |
| w2_overworld | FLAGGED walk-through | (9, 26) | walkable cell under hell_rock_0.png |
| w2_overworld | FLAGGED walk-through | (57, 28) | walkable cell under hell_rock_0.png |
| w2_overworld | FLAGGED walk-through | (60, 43) | walkable cell under well_healing_0.png |
| w2_overworld | FLAGGED walk-through | (55, 46) | walkable cell under cursed_eye_rock_0.png |
| w2_thanatoshall | FLAGGED walk-through | (9, 1) | walkable cell under undead_grave_2.png |
| w2_thanatoshall | FLAGGED walk-through | (25, 7) | walkable cell under undead_tree_1.png |
| w2_thanatoshall | FLAGGED walk-through | (4, 9) | walkable cell under undead_grave_2.png |
| w2_thanatoshall | FLAGGED walk-through | (25, 11) | walkable cell under undead_tree_3.png |
| w3_overworld | FLAGGED walk-through | (52, 4) | walkable cell under winter_rock_4.png |
| w3_overworld | FLAGGED walk-through | (62, 5) | walkable cell under well_healing_0.png |
| w3_overworld | FLAGGED walk-through | (44, 8) | walkable cell under winter_rock_4.png |
| w3_overworld | FLAGGED walk-through | (29, 13) | walkable cell under winter_rock_4.png |
| w3_overworld | FLAGGED walk-through | (64, 16) | walkable cell under winter_rock_0.png |
| w3_overworld | FLAGGED walk-through | (53, 21) | walkable cell under well_healing_0.png |
| w3_overworld | FLAGGED walk-through | (45, 22) | walkable cell under winter_rock_6.png |
| w3_overworld | FLAGGED walk-through | (47, 23) | walkable cell under winter_rock_5.png |
| w3_overworld | FLAGGED walk-through | (11, 24) | walkable cell under winter_rock_6.png |
| w3_overworld | FLAGGED walk-through | (54, 24) | walkable cell under winter_rock_3.png |
| w3_overworld | FLAGGED walk-through | (75, 24) | walkable cell under winter_rock_3.png |
| w3_overworld | FLAGGED walk-through | (85, 32) | walkable cell under winter_rock_4.png |
| w3_overworld | FLAGGED walk-through | (28, 33) | walkable cell under winter_rock_5.png |
| w3_overworld | FLAGGED walk-through | (48, 34) | walkable cell under winter_rock_6.png |
| w3_overworld | FLAGGED walk-through | (54, 34) | walkable cell under winter_rock_4.png |
| w3_overworld | FLAGGED walk-through | (38, 35) | walkable cell under winter_rock_4.png |
| w3_overworld | FLAGGED walk-through | (68, 38) | walkable cell under winter_rock_0.png |
| w3_overworld | FLAGGED walk-through | (68, 41) | walkable cell under winter_rock_5.png |
| w4_overworld | FLAGGED walk-through | (34, 3) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (49, 4) | walkable cell under desert_tree_dead_0.png |
| w4_overworld | FLAGGED walk-through | (30, 6) | walkable cell under desert_tree_dead_3.png |
| w4_overworld | FLAGGED walk-through | (47, 6) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (57, 6) | walkable cell under desert_tree_dead_1.png |
| w4_overworld | FLAGGED walk-through | (58, 6) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (77, 6) | walkable cell under desert_tree_dead_0.png |
| w4_overworld | FLAGGED invisible wall | (45, 10) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (46, 10) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (47, 10) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (77, 12) | walkable cell under desert_tree_dead_0.png |
| w4_overworld | FLAGGED walk-through | (18, 15) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (63, 15) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (64, 15) | walkable cell under desert_tree_dead_4.png |
| w4_overworld | FLAGGED walk-through | (65, 15) | walkable cell under desert_tree_dead_3.png |
| w4_overworld | FLAGGED walk-through | (74, 15) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (20, 18) | walkable cell under desert_tree_dead_3.png |
| w4_overworld | FLAGGED invisible wall | (11, 20) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (82, 21) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (83, 21) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (84, 21) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (89, 24) | walkable cell under desert_tree_dead_1.png |
| w4_overworld | FLAGGED invisible wall | (25, 25) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (26, 25) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (27, 25) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (28, 25) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (66, 25) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (51, 26) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (48, 30) | walkable cell under well_healing_0.png |
| w4_overworld | FLAGGED walk-through | (31, 31) | walkable cell under desert_tree_dead_3.png |
| w4_overworld | FLAGGED walk-through | (74, 31) | walkable cell under desert_tree_dead_0.png |
| w4_overworld | FLAGGED walk-through | (99, 34) | walkable cell under desert_tree_dead_3.png |
| w4_overworld | FLAGGED invisible wall | (48, 35) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (49, 35) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (85, 35) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (14, 36) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED invisible wall | (27, 36) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (68, 36) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED invisible wall | (97, 36) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (98, 36) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (99, 36) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (2, 37) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (3, 37) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (4, 37) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (5, 37) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (67, 37) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (91, 38) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (29, 41) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED invisible wall | (43, 42) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (54, 42) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (56, 44) | walkable cell under desert_tree_dead_3.png |
| w4_overworld | FLAGGED invisible wall | (70, 45) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (53, 48) | walkable cell under desert_tree_dead_1.png |
| w4_overworld | FLAGGED invisible wall | (27, 49) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (28, 49) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (29, 49) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (30, 49) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (81, 51) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (12, 52) | walkable cell under desert_tree_dead_3.png |
| w4_overworld | FLAGGED walk-through | (18, 52) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED walk-through | (42, 52) | walkable cell under desert_tree_dead_1.png |
| w4_overworld | FLAGGED walk-through | (63, 54) | walkable cell under desert_tree_dead_3.png |
| w4_overworld | FLAGGED walk-through | (64, 55) | walkable cell under desert_tree_dead_3.png |
| w4_overworld | FLAGGED walk-through | (65, 55) | walkable cell under desert_tree_dead_4.png |
| w4_overworld | FLAGGED walk-through | (54, 56) | walkable cell under desert_tree_dead_2.png |
| w4_overworld | FLAGGED invisible wall | (49, 57) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (50, 57) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (51, 57) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (52, 57) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED walk-through | (73, 57) | walkable cell under well_healing_0.png |
| w4_overworld | FLAGGED invisible wall | (15, 59) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (16, 59) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (17, 59) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (69, 59) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (36, 60) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (37, 60) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (25, 61) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (26, 61) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (27, 61) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (28, 61) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (29, 61) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (61, 61) | wall beside reachable floor, nothing drawn |
| w4_overworld | FLAGGED invisible wall | (76, 61) | wall beside reachable floor, nothing drawn |

## Addendum, 2026-11-09 — Act 2's new places

World 2 re-dumped and audited after the Brimstone Rift, the Citadel of Dis, the Ashen Stair and their sealed rooms (the Crucible, the Throne of Dis, the Breach) were added: `w2_overworld`, `w2_rift_0`, `w2_crucible`, `w2_citadel_0`, `w2_throne`, `w2_ascent_0`, `w2_breach` (found by following doors). None of them has an invisible blocker, an invisible wall, an unreachable pocket, POI or site, a stuck spawn or a dead end. Their only findings are of the kinds already accepted above: walk-through scatter (the cursed biome's rocks, the healing wells) on 0–5 cells each, and the battle's AOE indicator dot (a bare cylinder at no cell, `AOEIndicator/CenterDot`), which every map now shows, the old ones included.

## Addendum, 2026-11-09 — Act 3: World 3 is the corrupted Heaven

World 3 re-dumped and audited after it became Heaven (Frostreach's snow and Ice Caves gone from it) and Act 3's four places and their sealed rooms were added: `w3_overworld`, `w3_sanctum_0`, `w3_altar`, `w3_garden_0`, `w3_font`, `w3_spire_0`, `w3_belfry`, `w3_causeway_0`, `w3_rent` (found by following doors; `env_dump.gd` skips `breach_down`, Heaven's way back down, which is a door to World 2's Breach, not an interior). None of them has an invisible blocker, an invisible wall, an unreachable pocket, POI or site, a stuck spawn or a dead end (the Causeway's one-tile spurs of bank are pruned, the Desecrated Altar's relic claims its tile). Their only findings are of the kinds already accepted above: walk-through scatter — Heaven's pale limestone rocks (`wallrock_pale`, the stand-in rock family) and the healing wells — on 0–20 cells each (the Gilded Garden's beds the most), and the battle's AOE indicator dot (`AOEIndicator/CenterDot`). All of Heaven's art is stand-in pack art until the designer's Heaven boards (`DungeonManager.HEAVEN_ART`).

## Addendum, 2026-11-09 — Act 4: World 4 is the Earth returned to

World 4 re-dumped and audited after it became Act 4's corrupted Earth (the Amber Wastes' desert gone from it, so the 48 open-sand edge cells flagged above are gone too: its fields now end in the Verdant Frontier's trees, rocks and bushes) and Act 4's four places and their sealed rooms were added: `w4_overworld`, `w4_hamlet_0`, `w4_green`, `w4_vale_0`, `w4_hellmouth`, `w4_basilica_0`, `w4_reliquary`, `w4_riven_0`, `w4_confluence` (found by following doors; `env_dump.gd` skips `rent_up`, the Earth's way back up, which is a door to World 3's Rent, not an interior). None of them has an invisible blocker, an invisible wall, an unreachable pocket, POI or site, a stuck spawn or a dead end (on the Riven Heights no obstacle is claimed by a step or a ledge's lip, or where it would leave a cul-de-sac: `_level_ring`; the arrival's colonnade claims the tile behind the way up). Their only findings are of the kinds already accepted above: walk-through scatter — the Frontier's rocks and stumps, the cursed biome's rocks and posts by Hell's tears, Heaven's pale limestone where it fell, the healing wells — on 0–63 cells each (the surface and the Hamlet's crofts the most, as World 1's fields), and the battle's AOE indicator dot (`AOEIndicator/CenterDot`). All of Act 4's art is stand-in pack art until the designer's Act 4 boards (`DungeonManager.EARTH_RETURN_ART`).
