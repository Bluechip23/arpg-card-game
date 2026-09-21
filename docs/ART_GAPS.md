# ART_GAPS — art the purchased packs do not cover

After the Craftpix pass (`docs/ASSET_PACKS.md`), these are the pieces still
drawn by our generated/hand-made placeholders because none of the packs has a
better option. Grouped by where they show up; the **Wanted** column is the
shopping brief. Anything not listed here is now pack art.

## Terrain & structures

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Sewer / building interior masonry | Sewers, building interiors | pack fills stand in: sewers use the glowing-cave stone floor and cave rock walls, buildings the barrow-land flagstones and grey stone walls; doorways are the desert pack's dark archway | A proper dungeon/sewer or castle-interior top-down tileset (brick floor, wall faces, arches, iron doors) if the borrow bothers you |
| Building exteriors (walls, roof, windows) | Overworld enterable buildings | box walls in the pack's grey stone fill, a slate-tinted roof, the pack archway as the door | A village/house top-down set with roofs (from above only the roof shows) |
| Sewer fixtures: torches / sconces, pipes, grates, manholes, water channels & steam | Sewers, building sconces | procedural meshes + generated strips (the sealed passage doors are now the pack archway) | Sewer / dungeon props set (wall torch with flame frames, pipes, grates, iron doors) |
| Frostreach cliffs and trails | Overworld level 3 | grey barrow-stone walls and slush trails borrowed from the undead pack (the winter pack has no cliff or path tiles) | a snow cliff / frozen rock face and a packed-snow path, if the borrow bothers you |
| Autotile edges from the packs | every biome | edge bands painted from the palette over pack fills | none to buy — engineering (map the packs' edge pieces into the 16 mask columns) |
| Elevation cliff sides & stone steps | Overworld high ground | cliff = pack cobble fill on a box; steps = trail fill | fine as is; a dedicated stair/ledge piece would be nicer |
| Fog of war tile | everywhere | generated dither | none needed |

## Props & dressing

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Signpost | trail forks, World 1 | generated sprite | wooden signpost / direction post (any top-down village set) |
| Waypoint marker | waypoints, town | the glowing-cave pack's animated totem on a pack-dirt mound, tinted per destination | keep, or a dedicated teleport circle if you want one per destination |
| Critters: crow, mouse, squirrel, butterfly | meadow, sewer, forest | generated 2-frame strips | small animal sprite packs (4-dir or side) |
| Falling leaves | Greenwood | generated leaf | leaf particle sheet |
| Cave drips & sewer steam | cave, sewer | generated strips | water drip / steam VFX sheets |
| Cloud shadows | overworld | generated blob | none needed |
| Bear trap, dart trap, wall dart shooter, tree-pit | Greenwood, caves | box meshes | trap props (jaw trap, dart tube) |
| Spider web | caves | `cave_web` pack sprite is available but the web is still a mesh | engineering only |
| Chest "opening" and "empty" states | chests | closed / open-with-loot only | pack has 4 rows; the empty state is engineering |
| Town stalls, well, fences, houses | Town | box meshes | a village / market top-down set |
| Healing fountain | overworld sites | meshes | fountain / altar props (the Drowned Shrine now stands the winter pack's carved idol on a pack-stone plinth) |

## Characters

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Player characters (Brad, Cory, Stephen, Jeremy, Ryan) | everywhere | Mana Seed base + Seliel NPC sheets (4-dir, fine under the fixed camera) | none unless you want the whole cast in the Craftpix style; the swordsman pack covers a human fighter with attack frames |
| Town NPCs (Olorin, Sellsword, vendors) | Town | Seliel NPC sheets | as above |
| Enemies without a pack: wolf, coyote, beaver, wererabbit, treant, consumed, crawlers, swarm, djinn, minotaur, hydra, manticore, wyvern, bone dragon, cerberus, werewolf, sabertooth, magma spider, mages, vampire, succubus, cherub, archangel | battle | MonsterKit battlers / generated / NPC-sheet recolours | animal packs (wolf, boar), spider, dragon/wyvern, humanoid casters, angels — 4-dir animated to match the Craftpix rigs (skeletons and goblins are done; the mountain-monster pack now covers bears, hawk/roc/harpy/screecher, both trolls and the Sewer Cobra, side-view only) |
| Mountain-monster stand-ins: trolls are an orc and a yeti, all four birds share one crow (the Sewer Cobra IS the pack's serpent) | battle | mountain_monsters pack, tinted and scaled | a proper troll pair, a second bird (hawk vs. harpy) — side-view frame packs like this one drop straight in |
| Dwarf (`mountain_monsters/Dworf`) | — | unused | nothing to fill; spare if a dwarf NPC or enemy is ever added |
| Rat King crown | Sewers boss | plague-rat variant scaled ×1.7 | a crown overlay or a bespoke king rat |
| Boss silhouettes: Corrupted Archangel, Granite Colossus (now rock golem), Rat King | bosses | see above | bespoke boss sheets |

## UI & icons

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Quiver slot icon | inventory | an arrow from the weapon pack stands in | a proper quiver icon (the belt is covered by the knight armour pack) |
| Any-weapon composite (empty main/off hand) | inventory | drawn sword/bow/shield/book composite | an "any weapon" glyph, or leave as is |
| Mythic item art (40 icons) | inventory, chests | hand-made 32×32 | keep — bespoke by design; the knight armour (100) and weapon (100) icon packs now cover per-item icons for commons/rares/legendaries, tiered plain → gilded → elemental, if you want that wired |
| Gauntlet skill icons (17) | gauntlet UI | hand-made | keep, or pick from the three skill-icon packs (now wired for statuses, passives and cards via `skill_icon_art.gd`) |
| Status, passive and card icon picks | buff/debuff bars, skill tree, HUD tray, card art window | skill-icon packs, provisional mapping in `scripts/ui/skill_icon_art.gd` (unmapped ids draw from a themed pool) | your final pass over the tables in that file; more packs if a status has no fitting icon |
| Card cost badges (mana drop, sand timer) | cards | hand-made | a UI icon pack (mana, time, gold) |
| Procedural UI glyphs (`ui_glyphs.gd`: hand, stop, play, cage, feather, bolt, brain, eye, card…) | HUD buttons | drawn at runtime | a pixel UI/HUD icon pack |
| Card frames | hand | themed panels; the art window now shows a skill-pack icon per card | a card frame set (borders, cost seals) if wanted |
| Bitmap font, 9-slice panels | all UI | engine font, flat panels | pixel UI kit (deferred milestone, style guide §8) |
| Portraits | character panel | in-game sprite | portrait set if wanted |
