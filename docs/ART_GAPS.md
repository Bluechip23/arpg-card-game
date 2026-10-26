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
| Elevation cliff sides | Overworld high ground | the ground autotile paints the raised top and the pack's cliff fringe is laid along each drop (`_build_pack_ledges`); the old modelled cliff boxes and stone steps were deleted 2026-10-23 | fine as is; a dedicated stair/ledge piece would be nicer |
| Graveyard gate pillars & lintel, sewer-entrance kerb | Overworld sites | boxes in the pack's wall stone around the pack doorways (undead skull door / dark archway); the modelled iron bars were deleted 2026-10-23 (no pack draws bars) | a stone gatepost / grate piece; the undead pack's broken arch (`undead_ruin`, already the Boneyard gate) could stand in for the graveyard's pillars |
| Fog of war tile | everywhere | generated dither | none needed |

## Props & dressing

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Signpost | trail forks, World 1 | generated sprite | wooden signpost / direction post (any top-down village set) |
| Waypoint marker | waypoints, town | a raised dirt mound with our generated rune ring (`waypoint_ring.png`) on top, tinted per destination — the look the designer chose (the glowing-cave `waypoint_totem` cut exists but is not used) | keep |
| Town portal (Return Scroll) | battle, town | a purple torus + glowing disc built in the packs' purple — the designer's chosen look | keep |
| Critters: squirrel, butterfly | forest, meadow | generated sprites (the crow is the mountain-monster pack's Bird on its flight cycle and the sewer mouse the giant-rat pack's Rat1 shrunk down, since 2026-10-23) | small animal sprite packs (side view) |
| Falling leaves | Greenwood | generated leaf | leaf particle sheet |
| Cave drips & sewer steam | cave, sewer | generated strips | water drip / steam VFX sheets |
| Cloud shadows | overworld | generated blob | none needed |
| Bear trap, dart trap, wall dart shooter, tree-pit | Greenwood, caves | box meshes | trap props (jaw trap, dart tube) |
| ~~Spider web~~ | caves | **done (2026-10-23):** the spiked-web trap is the cave pack's `cave_web` sprite | — |
| Cave floor divots, sewer algae smears | caves, sewers | flat tinted slabs (the cave rubble and sewer rubble are the cave pack's rocks and pebbles since 2026-10-23) | none needed |
| ~~Berry bushels, barricade, enemy "tree form"~~ | battle | **done (2026-10-23):** the Crops bushels are the field pack's berry bushes, a Barricade segment the forest pack's fallen log (cut to a tile), the tree form the field pack's small tree | a crate/palisade piece if a log reads wrong |
| Crates and barrels | building interiors, town stalls | our own drawings (`assets/textures/props/crate.png`, `barrel.png`; no pack has them). Sacks, shelves and tables are pack art (2026-10-23: the old "goods" cuts showed backpacks and gold bars) | a crate / barrel / barrel-stack prop set |
| Chest "opening" and "empty" states | chests | closed / open-with-loot only | pack has 4 rows; the empty state is engineering |
| Town stalls, well, fences, houses | Town | box meshes | a village / market top-down set |
| Healing fountain | overworld sites | meshes | fountain / altar props (the Drowned Shrine now stands the winter pack's carved idol on a pack-stone plinth) |

## Characters

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Player characters (Brad, Cory, Stephen, Jeremy, Ryan) | everywhere | Mana Seed base + Seliel NPC sheets (4-dir, fine under the fixed camera) | none unless you want the whole cast in the Craftpix style; the swordsman pack covers a human fighter with attack frames |
| Town NPCs (Olorin, Sellsword, vendors, the Dojo master) | Town | Seliel NPC sheets (the Dojo master is the pack's bald old sensei, `npc old man B`, since 2026-10-23 — the drawn ninja is gone) | as above |
| Character-select cards and the load screen | menus | the character's own pack figure in a small 3D view (`SpriteFigure.make_preview`); the old hand-drawn portraits (`assets/characters/*_south.png`) were deleted 2026-10-23 | — |
| ~~Summons~~ | battle | **done (2026-10-23):** the wolf (the designer's wolf sheet), Seance specter and Spirit (Craftpix ghost), Skeleton (Craftpix skeleton), Golem (Craftpix rock golem), Frankensteins Monster (the designer's pose board since 2026-10-23; the Craftpix stitched zombie before), Draupnir's duplicate (its bearer's own figure, gold-tinted) and the spirit bows (the weapon pack's bow) — no shape meshes left on them | — |
| Self-made figures still in the game (kept by the 2026-10-23 cleanup: no pack has them) | battle | the dojo's **chicken** dummies (generated still), the **Rat King's nest** (drawn in the packs' palette by design), the burrowed bull worm's **mound** (cut from the pack's dirt). (The Bone Dragon, Sanguine and the bull worm wear the designer's boards since 2026-10-24/25.) | a chicken |
| Enemies still on stand-in art (2026-10-26): the Consumed, the Mind Eater, Pipe Crawler and Crypt Crawler (MonsterKit battlers), the Specter (Craftpix ghost), the Demon (Craftpix demon), the Roc (mountain-monster bird), the Grave Digger (NPC-sheet recolour); the generic Minion / Elite / Boss (Craftpix swordsmen, Enemy Lab only). Everything else wears the designer's own art — the four-pose boards (tools/cut_pose_boards.py; see ASSET_PACKS *paintings*) now cover, among others, the coyote, swarm, magma spider, cherub, Treasure Bunny (once the Wererabbit), mages, succubus, ash harpy, sewer cobra, snow wraith, sludge, fire goblins, skeleton, zombie, wererat, archer rat and Rat King | battle | MonsterKit battlers / Craftpix / NPC-sheet recolours | the designer's four-pose boards on black, as for the rest of the bestiary |
| Mountain-monster stand-ins: the roc is a crow (the Giant Hawk wears the designer's board since 2026-10-25) (the trolls wear the designer's boards since 2026-10-25, the Screecher its own board too) (the Sewer Cobra IS the pack's serpent) | battle | mountain_monsters pack, tinted and scaled | a proper troll pair, a second bird (hawk vs. harpy) — side-view frame packs like this one drop straight in |
| Dwarf (`mountain_monsters/Dworf`) | — | unused | nothing to fill; spare if a dwarf NPC or enemy is ever added |
| ~~Rat King crown~~ | Sewers boss | **done (2026-10-22):** the designer's own Rat King board (`tools/cut_boss_sheets.py`) | — |
| Boss silhouettes: ~~Corrupted Archangel~~, Granite Colossus (now rock golem), ~~Rat King~~ | bosses | **2026-10-22:** the Rat King, Cerberus and the Corrupted Archangel play the designer's boss boards (front/back/side Idle + Walk, `assets/sprites/generated/bosses/`); Hades' board is cut and staged with no enemy yet; the Archer Rat is the designer's too (`tools/cut_archer_rat.py`) | Granite Colossus only, if the golem bothers you |

## UI & icons

| Asset | Where | Today | Wanted |
|---|---|---|---|
| Quiver slot icon | inventory | an arrow from the weapon pack stands in | a proper quiver icon (the belt is covered by the knight armour pack) |
| Any-weapon composite (empty main/off hand) | inventory | drawn sword/bow/shield/book composite | an "any weapon" glyph, or leave as is |
| Mythic item art (40 icons) | inventory, chests | the designer's paintings for 39 (`tools/cut_mythic_art.py`, 2026-10-23); the Bladed Doughnut keeps its hand-made 32×32 | its painting, when the designer has one; the knight armour (100) and weapon (100) icon packs still cover per-item icons for commons/rares/legendaries if you want that wired |
| Gauntlet skill icons (17) | gauntlet UI | hand-made | keep, or pick from the three skill-icon packs (now wired for statuses, passives and cards via `skill_icon_art.gd`) |
| Status, passive and card icon picks | buff/debuff bars, skill tree, HUD tray, card art window | skill-icon packs, provisional mapping in `scripts/ui/skill_icon_art.gd` (unmapped ids draw from a themed pool) | your final pass over the tables in that file; more packs if a status has no fitting icon |
| Card cost badges (mana drop, sand timer) | cards | hand-made | a UI icon pack (mana, time, gold) |
| Procedural UI glyphs (`ui_glyphs.gd`: hand, stop, play, cage, feather, bolt, brain, eye, card…) | HUD buttons | drawn at runtime | a pixel UI/HUD icon pack |
| Card frames | hand | themed panels; the art window now shows a skill-pack icon per card | a card frame set (borders, cost seals) if wanted |
| Bitmap font, 9-slice panels | all UI | engine font, flat panels | pixel UI kit (deferred milestone, style guide §8) |
| Portraits | character panel | in-game sprite | portrait set if wanted |
