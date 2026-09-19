# ART_GAPS — art the purchased packs do not cover

After the Craftpix pass (`docs/ASSET_PACKS.md`), these are the pieces still
drawn by our generated/hand-made placeholders because none of the packs has a
better option. Grouped by where they show up; the **Wanted** column is the
shopping brief. Anything not listed here is now pack art.

## Terrain & structures

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Brick / masonry walls & floors | Sewers, building interiors, building exteriors, the waypoint plinth | generated `tile_brick.png` | A dungeon/sewer or castle-interior top-down tileset (stone brick floor, wall faces, arches, doors) |
| Building exteriors (walls, roof, door, windows) | Overworld enterable buildings | box meshes + brick/dirt fills | A village/house top-down set with roofs and doors |
| Sewer fixtures: torches / sconces, pipes, grates, manholes, doors, water channels & steam | Sewers, building sconces | procedural meshes + generated strips | Sewer / dungeon props set (wall torch with flame frames, pipes, grates, iron doors) |
| Worlds 2 & 3 ground and cliffs (Amber Wastes, Frostreach) | Overworld levels 2–3 | generated grass/dirt/rock tinted by palette | A desert/wasteland tileset and a snow/ice tileset |
| Water for Worlds 2 & 3 | as above | generated `tile_water.png` | comes with those tilesets |
| Autotile edges from the packs | every biome | edge bands painted from the palette over pack fills | none to buy — engineering (map the packs' edge pieces into the 16 mask columns) |
| Elevation cliff sides & stone steps | Overworld high ground | cliff = pack cobble fill on a box; steps = trail fill | fine as is; a dedicated stair/ledge piece would be nicer |
| Fog of war tile | everywhere | generated dither | none needed |

## Props & dressing

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Signpost | trail forks, World 1 | generated sprite | wooden signpost / direction post (any top-down village set) |
| Waypoint ring | waypoints, town | generated ring sprite + dirt mound | a teleport circle / rune ring / shrine (glowing) |
| Critters: crow, mouse, squirrel, butterfly | meadow, sewer, forest | generated 2-frame strips | small animal sprite packs (4-dir or side) |
| Falling leaves | Greenwood | generated leaf | leaf particle sheet |
| Cave drips & sewer steam | cave, sewer | generated strips | water drip / steam VFX sheets |
| Cloud shadows | overworld | generated blob | none needed |
| Bear trap, dart trap, wall dart shooter, tree-pit | Greenwood, caves | box meshes | trap props (jaw trap, dart tube) |
| Spider web | caves | `cave_web` pack sprite is available but the web is still a mesh | engineering only |
| Chest "opening" and "empty" states | chests | closed / open-with-loot only | pack has 4 rows; the empty state is engineering |
| Town stalls, well, fences, houses | Town | box meshes | a village / market top-down set |
| Healing fountain, shrine, plinth | overworld sites | meshes | fountain / altar props |

## Characters

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Player characters (Brad, Cory, Stephen, Jeremy, Ryan) | everywhere | Mana Seed base + Seliel NPC sheets (4-dir, fine under the fixed camera) | none unless you want the whole cast in the Craftpix style; the swordsman pack covers a human fighter with attack frames |
| Town NPCs (Olorin, Sellsword, vendors) | Town | Seliel NPC sheets | as above |
| Enemies without a pack: wolf, coyote, bears, beaver, wererabbit, skeleton, treant, consumed, sewer croc, crawlers, swarm, hawk/roc, screecher, djinn, trolls, minotaur, hydra, manticore, wyvern, bone dragon, cerberus, werewolf, sabertooth, harpy, magma spider, fire goblins, mages, vampire, succubus, cherub, archangel, spirit collector's kin | battle | MonsterKit battlers / generated / NPC-sheet recolours | animal packs (wolf, bear, boar), skeleton & undead knight, spider, dragon/wyvern, troll/ogre, goblin, humanoid casters — 4-dir animated to match the Craftpix rigs |
| Rat King crown | Sewers boss | plague-rat variant scaled ×1.7 | a crown overlay or a bespoke king rat |
| Boss silhouettes: Corrupted Archangel, Granite Colossus (now rock golem), Rat King | bosses | see above | bespoke boss sheets |

## UI & icons

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Belt slot icon | inventory | drawn silhouette | a belt / sash icon |
| Quiver slot icon | inventory | drawn silhouette | a quiver icon |
| Any-weapon composite (empty main/off hand) | inventory | drawn sword/bow/shield/book composite | an "any weapon" glyph, or leave as is |
| Mythic item art (40 icons) | inventory, chests | hand-made 32×32 | keep — bespoke by design; the armour/weapon pack can stand in for commons/rares if you want per-item icons there |
| Gauntlet skill icons (17) | gauntlet UI | hand-made | keep, or a skill-icon pack |
| Card cost badges (mana drop, sand timer) | cards | hand-made | a UI icon pack (mana, time, gold) |
| Procedural UI glyphs (`ui_glyphs.gd`: hand, stop, play, cage, feather, bolt, brain, eye, card…) | HUD buttons | drawn at runtime | a pixel UI/HUD icon pack |
| Card frames and card artwork | hand | themed panels, `~ artwork ~` placeholder | card frame set + per-card art (big item) |
| Bitmap font, 9-slice panels | all UI | engine font, flat panels | pixel UI kit (deferred milestone, style guide §8) |
| Portraits | character panel | in-game sprite | portrait set if wanted |
