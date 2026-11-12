# STORY.md — Narrative & Worldbuilding Bible

This is the **canonical story document** for the game. It pairs with
[`CLAUDE.md`](../CLAUDE.md) (design direction): `CLAUDE.md` answers *"what kind
of game is this?"*, this file answers *"what story does it tell, and in what
world?"*

It is a **living document**. The lore here is the seed; we grow it together.
When a story decision is made, write it down here so every future session
builds on the same canon instead of re-inventing it. Sections marked
**`[TBD]`** are deliberate placeholders to be designed together, and entries
marked **`[DRAFT]`** are proposals under discussion — not yet locked canon. Do
**not** quietly promote a `[DRAFT]` to canon or invent new plot/creatures
without confirming.

> Reminder from `CLAUDE.md`: **this is a TRUE RPG, not a roguelike.** One
> persistent character, one journey through a story with a beginning, middle,
> and end. The end-game is being redesigned from scratch (Section 6); whatever
> it becomes layers on top of the story, and nothing resets.

---

## 1. Premise & Tone

The world is **fraying**, and only one being can feel it happening.

The mood is high fantasy with a creeping undercurrent of *wrongness* — the
sense that the sickness afflicting the land comes from somewhere beyond it.
Think Tolkien's Middle-earth in its texture (Act 1), descending into the
infernal (Act 2), ascending into a corrupted holy realm (Act 3), and finally a
desperate defense of home (Act 4).

The central question the player chases across the whole game:
**what, exactly, is poisoning the world — and where is it really coming from?**

---

## 2. Olorin — The Through-Line

> *"It cannot be a leader, must not be a sickness of the mind… the earth's
> psyche feels wilted and a spoil is setting in, the morals of the trees are
> becoming poisoned."*

Olorin is a Gandalf-like figure (hence the name — a nod to Gandalf's Valinorean
name). He does **not** wield magic in the conventional sense. Instead he
possesses an almost supernatural *empathy with the world itself*: a hyper-
advanced EQ extended to nature, weather, animals, and the collective emotional
"tides" of all living things.

- He reads the world the way a person reads a room. Does it feel like evil is
  coming? Does a certain leader make him uneasy — and *why*?
- He is almost **Gaia-like**: imagine the Earth itself holding a database of
  every human, every shift in weather, every trend that ever happened — and
  being able to weigh all of it at once to sense **what comes next**.
- He understands animal calls at a deep, intuitive level and reads human
  behavior with the same fluency.

**The inciting realization:** Olorin senses a sickness overriding not just
humans but the trees, the animals, and the life of the planet itself. Bending
to the grass, he finds the blades stiffer than they should be — *"almost like
hair that has risen on the back of one's neck."* His conclusion:

> *"Curious… one must assume a war. Not a war of this world. One much higher,
> more consequential."*

This is the thread the player pulls on for the entire game: the fraying is not
of this plane. It comes from the Underworld, reaches into the Heavens, and aims,
ultimately, at Earth.

**Narrative role:** Olorin is the player's guide and quest-giver — the voice
that interprets the world's "tides" and points the player toward what is wrong.

> **Already in-game (do not duplicate):** Olorin exists today as a town NPC.
> See *Section 8 — Story ↔ Systems Map*.
>
> **The first-room tutorial, "A Mythic Find":** the first rat the player fells
> in the story carries a mythic, the Bladed Doughnut. Olorin names it from
> afar; on claiming it the player thinks better of wielding it ("I do not
> think I can wield this... I'll keep it and show Olorin") and the quest opens.
> Shown the doughnut in town, Olorin teaches rarities, the forge, mythic
> levels and skills, then admits the player cannot wear a mythic for a long
> while (level 15) and sends it to the Blacksmith to be melded into a Mythic
> Piece (two pieces pour into a Mythic Mold). He pays for the lesson with the
> Wooden Sword, his prop for card slots and item-granted cards.

---

## 3. Structure: Acts & Parts

There is **one world**. The player's character is persistent across all of it.
The story is told in **four Acts**, and each Act is a journey to a different
**plane of existence**:

| Act | Plane | Theme |
|-----|-------|-------|
| **Act 1** | **Earth** | Civilization — classic high fantasy, the surface world |
| **Act 2** | **Hell (the Underworld)** | Fire, darkness, sickness, demons |
| **Act 3** | **Heaven** | A corrupted, infiltrated holy realm |
| **Act 4** | **Earth (Return)** | All three planes collide on Earth — the final battle for the world |

**Parts & pacing:**
- Each Act contains **4 parts**.
- Each part should be roughly **~1 hour** of play — quests, boss battles, and
  general travel/exploration combined.
- **Act 4** is the most **compressed and climactic**: its parts move fast and
  build directly to the **final boss fight**. It still has 4 parts, but lean.

That's **4 Acts × 4 parts = 16 parts**, ending in the final confrontation.

> **Terminology is settled:** we say **"Act"** (Act 1–4), never "World," for
> story structure. There is only one world. (Code still uses `world_level` /
> `WorldData` internally — see Section 8 for the rename follow-up.)

---

## 4. The Four Acts in Detail

> Enemies are **not** organized by Act — they're catalogued by **habitat** (see
> Section 5). Each Act simply *draws from* one or more habitats. The affinities
> below are loose guidelines, not walls.

### Act 1 — Earth: Civilization
*Classic high fantasy. The surface world before the player understands the scope
of the threat.* Think Middle-earth / LOTR.

- **Environments:** town, sewers, cemetery, library, forests, mountains, caves.
- **Habitats it draws from:** Forest, Graveyard, Cave, Sewer, Mountains.
- **Tone:** familiar, grounded fantasy. The sickness is subtle here — felt by
  Olorin, not yet obvious. This is where the mystery is seeded.
- **Part slots:** 1) **Town & Sewers** — *the Sewers are built* (the opening dungeon; Olorin's first quests; Rat King mini-boss). See Section 5.4. · 2) Cemetery / Library (first clues) — *the Old Graveyard and the **Ruined Library** are built* (the library 2026-11-09, `interior_kind == "library"`, its door in the World 1 field room nearest the Old Graveyard; see Section 5.4, Graveyard); the clues, quests and NPCs of this part `[TBD]` · 3) **Forests / wilds** — *the Greenwood forest, the Caves and the Mountain Pass are built* (climbable trees, hunters' traps, woodland beasts; dark dripping cave tunnels). See Section 5.4. · 4) Act 1 climax / **threshold downward — Hell's Gate is built** (Cerberus guarding Hell's Door at the bottom of the first world's deepest cave; through the broken door lies the next world) — the climax around it `[TBD]`.

### Act 2 — Hell: The Underworld
*The descent. The apparent source of the rot.*

- **Theme:** fire, darkness, sickness.
- **Habitats it draws from:** Underworld (primarily); Cave bleed-over.
- **Tone:** oppressive and infernal. The player reaches the "source" — and
  learns the corruption is spreading *upward*, not contained here.
- **Built (2026-11-05): World 2 is the Underworld.** Hell's Gate's broken door leads down to it. Its surface wears the hell art first painted for World 4 (cursed earth, molten pools no one wades, volcanoes, demon idols and vein-wrapped ruins on its skyline; `DungeonManager.art_world`; World 4 took the Amber Wastes' desert in exchange until it became Act 4's Earth, 2026-11-09), and is the demons' ground: succubi, magma spiders, mind eaters and specters, demons, ash harpies overhead and ifrits; its arena an ifrit with two demons; its deep rooms the lords of the deep (the Ferryman's Toll). Its caves are **Burning Caves** — lava for puddles, lit orange — with the same host, a Fire Goblin Shaman each (the Channel lesson) and the door to the Labyrinth.
- **Thanatos Closet is built** (2026-11-05; `interior_kind == "closet"`, its way down in the Underworld's far reaches): crypt warrens under the burning ground in the **undead land art** (barrow earth and rock, green bog, headstones, ruined pillars and skull doors along the walls, bones and skulls underfoot), where specters drift and mind eaters and demons lurk. Its deepest crypt opens on **Thanatos's Hall** (`thanatoshall`, a boss room sealed until he falls): two rows of pillars and Death on his dais. **Thanatos** — *in code, first pass*: Boss (400 HP, 40 armor; resists 25% physical / fire / lightning); **Reap** (5 tempo, 25 + 6 Bleed beside him), **Death Bolt** (6 tempo, 15 at up to 6 squares + Hexes a card), **Raise the Dead** (10 tempo, a skeleton or zombie, two at most; each servant that falls rises as a Skeleton and costs him 10), Move. His figure is the designer's board (2026-11-05): a black-winged reaper in dark violet plate, red-eyed, scythe in hand, black smoke curling round him. `[TBD]`: his story beats, his final kit.
- **Parts 2–4: places and enemies built** (designer, 2026-11-09: "places & enemies only" — the story beats, quests and dialogue around them stay `[TBD]`). Three more ways in on the Underworld's surface, each a place with a **sealed room held by a band of guardians** (`DungeonManager.GUARDIAN_ROOMS`: like a boss room it seals behind the player and opens — and is remembered — when the last guardian falls; a demon's mimics don't count). All three wear the Underworld's own art (the designer's cursed earth, veined cliffs and hell props) with the cave pack's lava for molten ground no one wades; every creature is the Underworld's built roster at its band (specters, magma spiders, ash harpies 26; succubi, mind eaters 27; demons, ifrits 28). Their doors are raised blocks on the surface, picked by position: the Stair in the easternmost free field room (the far edge), the Citadel in the next, the Rift nearest two-fifths across.
  - **The Brimstone Rift** (`interior_kind == "rift"`; its door the designer's volcanic cones over the pack's dark archway): a canyon of cursed earth split by a meandering river of lava that runs out of the north rim and into the south one, parting round islands; spurs of the rim pinch its banks to ledges along the lava. Banks and islands are joined by the **cursed land pack's red vein bridges** (one tile wide; the only ways over). Succubi, demons, specters, mind eaters and **ash harpies** keep the banks; **magma spiders nest on the islands**; demons, harpies and a spider hold the far landing, where the door opens on **the Crucible** (`crucible`): **two ifrits** either side of a lava lake with an island at its heart, two vein bridges onto it.
  - **The Citadel of Dis** (`citadel`; its gate the designer's horned idol between skull posts): a demon fortress of open courts and paved halls — a gatehouse, an outer court with two lava basins, a great hall with two rows of pillars, wings of courts and halls north and south, an inner court with lava in its corners. Demons, succubi, specters and harpies in the courts; mind eaters, succubi, specters and demons in the halls; **an ifrit, two demons and a mind eater** keep the inner court before **the Throne of Dis** (`throne`): a long hall between lava gutters and pillars, the court of Dis on its dais — **an ifrit enthroned** under the horned idol, **two demons**, **two succubi**, **two mind eaters**. No pack draws a fortress wall: its walls are the Underworld's veined cliff lined with the designer's vein-wrapped ruins, skull fences and posts; its braziers his hell fire.
  - **The Ashen Stair** (`ascent`; its door the designer's horns and great vein arch): the **way up** — the Mountain Pass's terraces (walked one level a step; fliers cross the cliffs) climbing the Underworld's far edge, lava pools on its ledges. Succubi, demons and specters on the low terraces; mind eaters, magma spiders and specters keeping the ledges; ash harpies riding the heights; an ifrit at the top. Its door at the top opens on **the Breach** (`breach`, entered from the south): the gate in its north wall (the designer's great vein arch), held by its **wardens — two ifrits, two demons, a mind eater, a succubus and two ash harpies** (the strongest band the built roster makes; no new kits). When the last falls the way up opens: **Shift at the gate climbs to the next world** — World 3, the corrupted Heaven (Act 3 below), where the hero arrives at Heaven's way back down to this gate — as Hell's Door leads down to this one; and the way back down the Stair opens too.
- **Part slots:** 1) **The Labyrinth is built** — the Inflamed Minotaur's maze through a door at the east end of the Underworld's deepest cave (see Section 5.4, Underworld); the arrival and the parts around it `[TBD]` · 2) **The Brimstone Rift is built** (and the Crucible) — its beats `[TBD]` · 3) **The Citadel of Dis is built** (and the Throne of Dis) — its beats `[TBD]` · 4) Act 2 climax / **threshold upward — the Ashen Stair and the Breach are built** (the way up to the next world) — the climax around it `[TBD]`

### Act 3 — Heaven (Corrupted)
*The ascent. The Underworld has infiltrated the Heavens; the player climbs to
stop the invasion.*

- **Theme:** what was once pure is now gloomy and sickened.
- **Habitats it draws from:** Heavens (with Underworld invaders present).
- **Tone:** tragic corruption — beauty defiled. The twist: the heavenly
  invasion was never the real goal.
- **Built (2026-11-09): World 3 is Heaven** (designer: "Make World 3 the Heaven"; it was Frostreach — its snow stays on World 1's Mountain Pass and its Ice Caves). **Places and enemies only** — the story beats, quests, dialogue and the Act's climax stay `[TBD]`. Its name for now, **The Tarnished Heavens** (`WORLD_PALETTES[3]`): a pale-gold light gone wan over pale stone, the holy pools turned to murk. The Breach (Act 2, part 4) leads up to it: the hero arrives in Heaven's start field at **the way back down** (a door under the Underworld's vein arch — Shift there returns to the Breach's gate). Heaven's host is the Heavens roster in code — **cherubs** (its rank and file) and **djinn** (its elites) — with the **Underworld's invaders broken in among it**: demons, succubi, specters, ash harpies and mind eaters (the Corrupted Archangel has no kit yet and stays out). On its surface: cherubs, specters, succubi and mind eaters in the fields, demons, harpies overhead, a djinn with two demons and a cherub in its arena; two broken ruins; no caves.
- **Art: stand-ins until the designer's Heaven boards** ("You'll send boards"). Every art choice for Heaven goes through one table, `DungeonManager.HEAVEN_ART` (read by `heaven_art()`), so the boards swap in slot by slot. The slots to paint, and what stands in for each now:
  - **Ground** — the barrow land's pale cobbles (`undead_cobble`).
  - **Paved ways / walks / runners / steps** — the designer's desert sand, gold under the light (`desert_sand`).
  - **Cliffs and the land's edge (walls)** — the glowing-cave pack's dusk-violet rock (`wall_glowing_cave`) above, the undead pack's dark rock face (`cliff_undead`) for the drop.
  - **Water: the sickened pools** — the cave pack's murky water (`water_cave`); **the gulf** under Heaven's broken floor (the Causeway, the Rent) — the designer's dark cursed water (`cursed_water`).
  - **Decorations** (prop roles `"heaven"`) — the glowing-cave pack's growth, newly cut: gold-flecked dark rock (`glow_gold`), pink and violet crystals (`glow_crystal`, `glow_teal`), glowing ferns, flowers, leaves and fungi (`glow_fern`, `glow_flower`, `glow_bush`, `glow_shroom`); the rock pack's pale limestone (`wallrock_pale`), the forest's pebbles, the barrow land's bones.
  - **Skyline / boundary landmarks** — the barrow land's broken columns and arches (`undead_ruin`, pale-tinted), great crystals, gilded rock.
  - **Columns** (the Sanctum, the sealed rooms) — the designer's sandstone pillar on its steps from the Greenwood (`forest_ruin` 2).
  - **Site entrances** — the Sanctum: the desert's gilded eye-crowned door (`desert_door`); the Garden: an overgrown ring of ruined walls (`forest_ruin` 0); the Spire: the desert's shrine over a stair (`desert_ruin` 1); the Causeway: a broken colonnade (`undead_ruin` 4); the ruins: a broken arch (`undead_ruin` 1); each on a raised block heaped with gilded rock and crystal.
  - **The way back down** — the Underworld's vein arch (`hell_arch`); **bridges** over the gulf — the cursed land pack's vein bridges; **braziers** — the designer's hell fire; **the altar** — the glowing-cave pack's totem (`waypoint_totem`).
  - **Sky / backdrop** — none of its own: the ground plane beyond the walls is the ground sheet darkened, as everywhere.
- **The four parts — places built, beats `[TBD]`.** Four ways in on Heaven's surface, raised blocks picked by position (as Act 2's): the Sanctum nearest the arrival in the west, the Garden mid-way, the Spire three-quarters across, the Causeway in the easternmost field (Heaven's far edge). Each has a **sealed room held by guardians** (`GUARDIAN_ROOMS`: it seals behind the hero and opens — and is remembered — when the last guardian falls). Levels: cherubs 33, djinn 35; the invaders keep their Underworld bands (26–28).
  - **The Defiled Sanctum** (`interior_kind == "sanctum"`): a cruciform temple — a narthex, a nave between two rows of columns with side chapels off it, a domed crossing ringed with columns where the four fonts have gone to bog, transepts north and south ending in apses with their basins, the choir — and a gold runner from the door to the altar. Cherubs, specters and succubi in the nave; mind eaters and succubi in the chapels; demons, harpies and cherubs under the dome and in the transepts; **a djinn** with a demon and cherubs in the choir's apse, whose door opens on **the Desecrated Altar** (`altar`): a round sanctuary ringed with columns, **a djinn on the altar**, two cherubs either side of it, two succubi beyond, a mind eater at the back.
  - **The Gilded Garden** (`garden`): a formal garden overrun — beds hedged with luminous overgrowth (the hedges and the garden's edge are its natural boundary) between gold walks, a great fountain gone to murk in the plaza at its heart. Cherubs, succubi, specters and mind eaters in the beds; harpies, cherubs and specters on the walks; demons and cherubs round the fountain; a djinn in the far grove, at the door of **the Sickened Font** (`font`): a hedged court round a fountain gone to bog, **two djinn** north and south of it, two cherubs either side, a succubus and a mind eater by the far wall.
  - **The Silent Spire** (`spire`): the Mountain Pass's terraces as a climb up Heaven's tower (walked one level a step; the cherubs and harpies fly over its cliffs). Demons, succubi and specters low; mind eaters, specters and cherubs on the ledges; ash harpies and cherubs on the heights; a djinn and a harpy at the top, where the door opens on **the Belfry** (`belfry`, entered from the stair below): four great piers round where the bells hung — no bell drawn — **a djinn** beneath them, a demon and a mind eater before him, two cherubs and two ash harpies in the open corners.
  - **The Sundered Causeway** (`causeway`, part 4, at Heaven's far edge): the Brimstone Rift's canyon with **a gulf for its river** — banks and islands of pale stone, the Underworld's vein bridges the only ways over. Demons, succubi, specters, mind eaters and cherubs on the banks with harpies over them; cherubs and harpies on the islands; a djinn, two demons, a harpy and a cherub at the far landing, the door of **the Rent** (`rent`): a long hall whose floor is torn open — a jagged tear of the gulf across its east end — held by its **wardens: two djinn, two demons, a mind eater, two cherubs and an ash harpy** (the strongest band Heaven's host and the invaders make). When the last falls **Shift at the tear's lip goes down to the next world** (World 4; as the Breach leads up here), and the way back opens.
- **Part slots:** 1) **The arrival and the Defiled Sanctum are built** (and the Desecrated Altar) — the beats `[TBD]` · 2) **The Gilded Garden is built** (and the Sickened Font) — its beats `[TBD]` · 3) **The Silent Spire is built** (and the Belfry) — its beats `[TBD]` · 4) Act 3 climax / **threshold downward — the Sundered Causeway and the Rent are built** (the way down to the next world) — the climax and the twist around it `[TBD]`

### Act 4 — Earth: Return
*The reveal and the last stand.*

- While the player defended the Heavens, the enemy began **leaking back to
  Earth** — the plan they truly wanted all along.
- **All three planes collide here:** the **normal plane, Hell, and Heaven now
  all exist on Earth at once.** The world itself becomes the battlefield, and
  this is the **final battle for the world** — its fate decided here.
- **Habitats it draws from:** the Earth habitats again, now **corrupted**, plus
  Underworld *and* Heaven creatures present together through tears in reality.
  *The familiar made monstrous.*
- **Pacing:** lean, urgent parts building to the **final boss fight**.
- **Final boss:** `[TBD]` — the architect of the cross-realm war; the presence
  Olorin first sensed in the grass.
- **Built (2026-11-09): World 4 is the Earth returned to** (designer: "go ahead and build Act 4"). **Places and enemies only** — the story beats, quests, dialogue, the Act's climax and **the final boss stay `[TBD]`**. Its name for now, **The Blighted Frontier** (`BLIGHT_PALETTE`; it had worn the Amber Wastes' desert as a placeholder, a look now worn by no world and kept on the shelf — its door and sand still stand in for Heaven's): World 1's Earth — the Verdant Frontier's grass, trees and ruins — under a sun dimmed by smoke, **torn**: Hell's lava wells up through it in pools with the Underworld's dark blight round them and on its roads, its growth and pieces (vein arches, skull fences, the horned idol) at the tears; Heaven has fallen on it in places (great crystals, pale broken columns, luminous growth, a cold light). The Rent (Act 3, part 4) leads down to it: the hero arrives in its start field at **the way back up** (Heaven's broken colonnade — Shift there returns to the Rent's lip). Two caves (the Fire Goblin warband, the corrupted cave dwellers among them, an ifrit in the deepest) and a ruined hall beside its four places. **Its host is all three planes at once**: the Earth's own creatures gone monstrous (the Act 1 roster — the Greenwood's beasts, the Graveyard's dead, the mountains' creatures), the Underworld's and Heaven's among them, rolled together; its arena a Large Bear, an ifrit and a djinn with a demon and a cherub. **Act 4's band**: everything met on it stands at least at **38** (`DungeonManager.ACT4_BAND`, above Heaven's 33–35; `Enemy.band_floor`), the Earth's low-band creatures grown to the scaling's cap.
- **Art: stand-ins until the designer's Act 4 boards.** Every art choice for Act 4 goes through one table, `DungeonManager.EARTH_RETURN_ART` (read by `earth_art()`), so the boards swap in slot by slot. Where each plane shows is the tears (`blight_tears`, `_plane_at`): each prop takes the plane of the ground it stands on. The slots to paint, and what stands in for each now:
  - **Ground** (`floor`) — the Verdant Frontier's grass (`field_grass`); **Heaven's paving** where it fell (`heaven_floor`, the Basilica and the Reliquary) — Act 3's stand-in, the barrow land's pale cobbles (`undead_cobble`); **Hell's earth** where it broke clean through (`hell_floor`, the Hellmouth) — the Underworld's cursed earth (`cursed_floor`).
  - **The blight** (`blight`: the roads, the ground round Hell's tears, the Vale's banks along the lava) — the Underworld's dark cracked earth (`cursed_dark`); **Heaven's walks** (`heaven_trail`) — the desert sand (`desert_sand`).
  - **Rock and the land's edge** (`wall`, `cliff`; the Vale, the Basilica, the Heights, the sealed rooms — World 4's fields and the Hamlet end in trees) — the Greenwood's mossy cobble and mossy rock face (`forest_wall`, `forest_cliff`).
  - **Lava** (`lava`: pools, the Vale's river, the wells, the fonts) — the cave pack's lava (`water_lava`).
  - **Prop families by plane** (`plane_earth` / `plane_hell` / `plane_heaven`) — the Frontier's own (`field`), the cursed land and hell (`cursed`), Act 3's luminous growth (`heaven`).
  - **A tear of Hell's pieces** (`tear_hell`) — the vein arches, a skull fence, the horned idol, vein-wrapped ruins; **a tear of Heaven's** (`tear_heaven`) — great crystals, gilded rock, the barrow land's broken columns and colonnade (pale-tinted, `stone_tint`).
  - **Site entrances** — the Hamlet: the Frontier's ruined tower (`field_ruin` 0); the Vale: a stone arch bound in veins (`cursed_ruin` 1); the Basilica: Heaven's gilded eye door (`desert_door`, as the Sanctum's); the Heights: a ruined stair (`field_ruin` 1); caves: the cursed mound over a dark mouth (`cursed_cave`); the hall: the Greenwood's ring of ruined walls (`forest_ruin` 0); each on a raised block heaped with its plane's pieces.
  - **The way back up** (`arrival_ruin`) — Heaven's broken colonnade (`undead_ruin` 4); **the Hamlet's cottages** (`cottage`) — the Frontier's and the Greenwood's ruins (no pack draws a village house in ruins); **bridges** — the cursed land's vein bridges; **columns** — the Greenwood's sandstone pillar (`forest_ruin` 2, as Heaven's); **the relic** — the glowing-cave totem (`waypoint_totem`); **braziers** — the hell fire.
- **The four parts — places built, beats `[TBD]`.** Four ways in on World 4's surface, raised blocks picked by position (as Act 2's and 3's): the Hamlet nearest the arrival in the west, the Vale two-fifths across, the Basilica two-thirds, the Riven Heights in the easternmost field (the far edge). Each has a **sealed room held by guardians of all three planes** (`GUARDIAN_ROOMS`: it seals behind the hero and opens — and is remembered — when the last falls).
  - **The Forsaken Hamlet** (`interior_kind == "hamlet"`, part 1 — the familiar made monstrous): Act 1's countryside torn — the Gilded Garden's plots as hedged crofts (hedgerows of the Earth's trees, rocks and bushes) with a cottage in ruins in each, lanes of grass between, the green's pond welled up as lava with the blight round it, Heaven fallen in a croft or two. The Graveyard's dead and the Greenwood's beasts in the crofts with a succubus or a cherub; wolves, hawks, specters, harpies and crawlers on the lanes; werewolves, vampires, demons and cherubs round the burning pond; **a Large Bear gone monstrous** with a werewolf, a demon and a cherub in the far croft, at the gate of **the Blighted Green** (`green`): a hedged green round a well torn open to Hell — **a Large Bear** at the well, a werewolf and a vampire, a demon and a succubus out of the fire, two cherubs.
  - **The Smouldering Vale** (`vale`, part 2 — Hell bleeding through): the Brimstone Rift's canyon as an Earth valley, a river of lava through it with the blight along its banks (Hell's growth there, the Earth's grass beyond), the cursed land's vein bridges the only ways over, Heaven's crystal on a bank. Demons, succubi, specters, magma spiders, harpies, wolves, infected hunters and cherubs on the banks; magma spiders nesting on the islands, a cherub or harpy over them; **an ifrit**, a demon, a treant, a harpy and a cherub at the far landing, the door of **the Hellmouth** (`hellmouth`): a crater of Hell's earth inside the Earth's rock, a lava lake with an island and two bridges, Heaven fallen at its far wall — **two ifrits**, **a Fire Mage of the Greenwood on the island** (its Fire Totem by it), two demons at the bridgeheads, two cherubs.
  - **The Shattered Basilica** (`basilica`, part 3 — Heaven's debris on Earth): the Defiled Sanctum's cross lying broken in the Earth's rock — Heaven's paving and gold runner, a third of its columns fallen, the Earth's growth through its floor in two chapels and the north apse, its crossing's fonts welling lava. Cherubs, specters, wolves and skeletons in the nave; mind eaters, cherubs, zombies and crawlers in the chapels; demons, cherubs, harpies and a werewolf under the broken dome; cherubs, a succubus, a vampire and a hawk in the transepts; cherubs, demons and a weregoat in the choir; **a djinn** with a white manticore and two cherubs in the apse, the door of **the Fallen Reliquary** (`reliquary`): Heaven's round sanctuary fallen to Earth, its fonts burning — **a djinn on the relic and a second behind it**, two cherubs, the mountains' fliers drawn to the fallen height (**a wyvern, a white manticore**), a mind eater.
  - **The Riven Heights** (`riven`, part 4 — the approach to the final battle, at World 4's far edge): the Mountain Pass's terraces (walked one level a step; fliers cross the cliffs) as Earth's last climb, lava on its ledges with the blight round it, Heaven's crystal fallen on its highest ledges. Wolves, bugbears, weregoats, sabertooths, demons and succubi low; mind eaters, specters, cherubs, snow wraiths and hunters on the ledges; ash harpies, rocs and cherubs on the heights; **an ice troll and a roc** at the top, at the door of **the Confluence** (`confluence`, entered from the stair below): **the final chamber, where the three planes meet** — Hell's fire in fissures down its west side, Heaven fallen along its east, the Earth's ground between — **and the place where the final boss will stand: a dais at its north end ringed with columns, its slot EMPTY (`confluence_boss_cell`; the boss is `[TBD]`)**. Until the designer names it, **a guard gauntlet holds the chamber** in three ranks from the stair to the dais — the Earth's (**a Large Bear, an ice troll, a werewolf**), Hell's (**an ifrit, two demons**), Heaven's (**two djinn and a cherub**) — and it opens when the last of them falls. Nothing lies beyond it yet.
- **Part slots:** 1) **The arrival and the Forsaken Hamlet are built** (and the Blighted Green) — the beats `[TBD]` · 2) **The Smouldering Vale is built** (and the Hellmouth) — its beats `[TBD]` · 3) **The Shattered Basilica is built** (and the Fallen Reliquary) — its beats `[TBD]` · 4) the final battle — **the Riven Heights and the Confluence are built** (the final chamber, its boss slot empty, a guard gauntlet in it for now) — **the final boss `[TBD]`**, the climax and the ending `[TBD]`

---

## 5. The Bestiary

Enemies are not just obstacles — they are a **persistent record**. Each
character tracks the monsters they've defeated
(`CharacterData.defeated_monster_ids`), and certain enemies drop **cards** into
the character's permanent collection (e.g. the Hydra → Growth Within
Resilience). Design every notable creature with two lives in mind: its role in
the **story** *and* its echo in the **end-game** (bestiary entry, intent-reveal
gate, card source).

### 5.1 How enemies work (so creatures are buildable, not just flavor)
Grounded in `scripts/battle/enemy.gd`:
- **Tempo actions:** an enemy commits to **one action at a time**; each action
  has a **tempo cost**, and it fires when the enemy's personal tempo counter
  reaches that cost. **Lower tempo cost = acts more often.** A creature's
  rhythm is its action list (e.g. Wererat: Move 2 / Bite 2 / Scurry 4).
- **Action keywords** (full rules and worked tick tables in
  [`ENEMY_ACTION_KEYWORDS.md`](ENEMY_ACTION_KEYWORDS.md)): **Sync** (default,
  one shared clock) · **Async** (the action keeps its own clock) · **Channel N**
  (the last N tempo are a channel — planted, other clocks pause) ·
  **Disruptable X** (X damage restarts its clock) · **Trigger** (fires on an
  event, no clock). **Immediate** and **Non-interruptible** are the defaults.
- **Range-based AI roles:** behavior keys off distance to the player —
  *melee rusher*, *ranged kiter*, *support*, *evasive skirmisher*, *scaling
  threat*, etc.
- **Core stats:** health, **armor** (break to 0 → enemy is *exposed*), attack
  damage, attack range (grid cells), move distance, XP.
- **Tiers:** `Minion` (cheap, numerous) · `Elite` (a real threat) · `Boss`.
- **Status toolkit a creature can apply or synergize with** (implemented):
  **burn** (doubles each cycle), **poison**, **shock**, **cold** (5 → **frozen**),
  **slow**, **stun**, **disarm**, **mark**, **taunt**, **wear-down**,
  **armor-break/expose**, **bleed** (damages the player when they move),
  **vulnerable** (+30% damage taken), **root** (cannot move), **blind** (attacks
  may miss).
- **Damage types** (implemented): every point of damage carries a type —
  **physical, fire, lightning, poison, ice, wind, earth**. Defenders can resist
  per-type (e.g. **Harden** = physical-only). Nothing is required to specify a
  type — untyped damage is physical — so creatures can opt in element by element.
- **Reusable mechanic patterns already in the game:** per-hit **scaling**
  (Hydra), **regeneration** (Armored Troll, Treant, Wolf packs), **terrain
  hazards / fire walls** (Fire Goblin Shaman), **ally heal/buff support**
  (Shaman), **pack tactics** (Mini Bears, Wolves), **first strike** (Bugbear),
  **pull/hook** (Infected Hunter), **armor-on-hit** (Earth Mage), **flying /
  ignores high ground** (Giant Hawk). Concepts to add: **summoning**, **charge
  lanes**, **on-death bursts**, **stealth/sound-only visibility**.
- **Drops:** elites/bosses can drop **cards**. Every kill is recorded to the
  bestiary.
- **Design rule — wakes are Traps:** anything a creature (or player) leaves
  behind in "the wake" of its movement — the Inflamed Minotaur's fire trail,
  future ice trails, ichor, etc. — is a **Trap** unless a design says
  otherwise. Keep this convention for all future wake-things.
- **Elite resist columns:** the elite first-pass sheet specifies three resists
  per creature — **Physical / Fire / Lightning** (negative = vulnerability).
  Other damage types stay at 0 until the sheet grows columns for them.

### 5.2 Creature design template
When we solidify a creature, capture it with these fields:
- **Name** · **Habitat(s)** · **Tier** (Minion / Elite / Boss) ·
- **Role** (melee rusher / armored tank / ranged kiter / evasive skirmisher /
  support / scaling / swarm / summoner / charger / ambusher) ·
- **Signature mechanic** (prefer existing status effects/patterns from 5.1) ·
- **Card / resource hook** (elites & bosses — what it feeds the end-game) ·
- **Status:** `existing` (in code) · `[TBD]` (roster only, theme not yet set).

### 5.3 Organizing principle — by habitat, not by Act
Creatures are catalogued by **where they could be found**. This is a
**structuring guideline, not a hard rule**: a creature can appear in more than
one habitat, an Act may draw from a single habitat or several, and the lists
will be revisited to **solidify each creature's theme and mechanics later**.
Right now this is the **master roster** — names captured, themes to come.

**Loose Act ↔ habitat affinity** (not binding):
- **Act 1 (Earth):** Forest · Graveyard · Cave · Sewer · Mountains
- **Act 2 (Hell):** Underworld
- **Act 3 (Heaven):** Heavens
- **Act 4 (Earth, return):** the Earth habitats, corrupted, + Underworld/Heaven bleed-through

**Already in code** (slotted into their best-fit habitat, all canon):
Wererat & Archer Rat → *Sewer* · Skeleton → *Graveyard* · Armored Troll →
*Cave* · Hydra → *Forest* · Fire Goblin Soldier/Mage/Shaman → goblin kin
(*Cave*), fire-themed (*Underworld* affinity) · Minion/Elite/Boss → generic
scaling fallback, any habitat.

### 5.4 Master roster by habitat
Faithful capture of the roster. `*in code*` = already built. Italic text is the
original flavor note. Everything else is `[TBD]` theme/mechanics.

#### Forest
- **Giant Beaver** — *in code*. Elite. Chomp (4 tempo, 9 dmg, **Stun** 3 tempo) queues a **Tail Whip** follow-up (2 tempo later, 6 dmg, **Vulnerable** 15 tempo). Sits upright when still, scurries on all fours. **Act 4** (World 4, 2026-11-09): World 4 (mid roll).
- **Mini Bear** — *in code*. Minion, *packs*. When a packmate in sight is hurt, the others gain **+1 attack damage**. **Act 4** (World 4, 2026-11-09): World 4 (trash roll), the Forsaken Hamlet's crofts.
- **Wolf** — *in code*. Minion, *packs*. Within 4 tiles of another wolf: **+2 attack damage and +2 HP regen/cycle**. **Act 4** (World 4, 2026-11-09): World 4 (trash roll), the Hamlet's crofts and lanes, the Smouldering Vale's banks, the Shattered Basilica's nave, the Riven Heights' low terraces.
- **Coyote** — *in code*. Minion. Fragile (5 HP) 1-damage nuisance.
- **Bugbear** — *in code*. Minion. **First Strike**: +5 damage if it hits before the player hits it. **Act 4** (World 4, 2026-11-09): World 4 (trash roll), the Hamlet's crofts, the Heights' low terraces.
- **Giant Hawk** — *in code*. Minion. Flying — **ignores the player's high-ground bonus**; 15% to **Blind** on hit (attacks may miss). **Act 4** (World 4, 2026-11-09): World 4 (ranged roll), the Hamlet's lanes, the Basilica's transepts.
- **Large Bear** — *in code*. Elite. **Maul applies Bleed**; **Roar** leaves everything within 4 squares Vulnerable. Below 50% HP it **toughens** (30% physical resist, permanent) and **rages** — 1.5x attacks, double Bleed, and it heals from bleed damage its enemies take. With Mini Bears present it gains **Strengthen** every time it is hurt. Drops to all fours below 20% HP. **Act 4** (World 4, 2026-11-09): World 4 (heavy roll, its arena), the Hamlet's far croft; **at the well of the Blighted Green**, and in the Confluence's gauntlet.
- **Infected Hunter** — *in code*. Elite. **Hook** (range 7, starts charged) reels the player in over 2 tempo; AOE **Cleave**. **Act 4** (World 4, 2026-11-09): World 4 (mid roll), the Vale's banks, the Heights' ledges.
- **Treant** — *in code*. Elite. Heals 5 HP/5 tempo (**+2 per 10% HP below 60%**); every 10 tempo it **strips its enemies' thorns and heals for the total**; **Root** pins the player 8 tempo (can attack, cannot move); deals **Earth** damage. Takes 10% extra fire damage. **Act 4** (World 4, 2026-11-09): World 4 (heavy roll), the Vale's far landing.
- **Elemental Mages** — *in code*. The five caster variants deal **typed damage**: Ice (→ **Slow**), Fire (→ **Burn**), Spark/Lightning (→ **Shock**), Air/Wind, Earth (**gains 3 armor every time it is hit**). **Totems** (designer, 2026-11-06, "at least for right now"; *in code*): each mage **raises its element's totem** beside it (Raise Totem, 6 tempo; one standing at a time, another 30 tempo after it is broken), a 24-HP structure in the designer's art that **crumbles when its mage falls**. **Air Totem** (a winged pillar under a whirlwind): the mage's foes' movement drops by 4 − N, N their squares from the vortex — a tile is 1 tempo, so each tile moved within 3 squares costs 3 / 2 / 1 extra tempo (`Main.vortex_drag`; paid like climbing, flash or not; the strongest totem counts). **Earth Totem** (a titan carved from a crag, bound in rose vines): heals the mage's allies (first pass: 4 health every 5 tempo, within 3 squares); has **thorns** (first pass: 5 back at every direct hit). **Fire Totem** (a lava-veined spire): 3 Burn to every foe within 3 squares every 5 tempo. **Ice Totem** (an ice obelisk coiled by an ice dragon holding a frozen pocket watch): **explodes when it dies** for 1 damage + 1 a tempo it stood, up to 10 — a 10-tempo timer: at 10 it goes off by itself (first pass: on every foe within 3 squares). **Shock Totem** (the Spark Mage's, an iron-banded storm mast): every 5 tempo it hits the nearest foe (first pass: 4 lightning) and gives 1 Shock to every foe within 4 squares. Set numbers scale with the hero's level like every enemy's. `[TBD]`: the first-pass numbers. **Where:** the Greenwood's elite clearings (2026-11-09) — each mage leads the woodland pack of a clearing of its own, Spark, Air, Fire, Ice, then Earth from west to east (their level bands, 13–17). **Act 4** (2026-11-09): a **Fire Mage** on the Hellmouth's island, its Fire Totem by it.
- **Druid** — `[TBD]`.
- **Hydra** — *in code*. Holds the Greenwood's widest clearing (2026-11-09).

> **The Greenwood (Act 1, Forest) — built.** A bright, open woodland level
> (`dungeon_manager.gd`, `interior_kind == "forest"`), reached from a **forest
> trailhead** site in the World 1 overworld. The sunlit counterpoint to the
> sewers.
>
> - **Layout:** grassy **clearings** linked by winding **dirt trails**, with some
>   clearings raised into **wooded hills** (high ground). A deep clearing to the
>   east is guarded by a **Large Bear**.
> - **Light & fog:** the brightest interior — full dappled daylight, thin air, and
>   a **large fog-reveal radius** (9 tiles) so moving uncovers much more of the map
>   than the sewers do.
> - **Climbable trees:** select trees have a **distinct low branch**; press
>   **[Shift]** beside one to climb up for **high ground** (ranged damage/range
>   bonus, and melee can't reach you up there). A **one-time tutorial bubble**
>   (`first_climbable_tree`, via Olorin) fires the first time the player climbs.
> - **Traps:** **bear traps** snap shut for **7 damage** to whatever steps on them
>   — **10 to bears** (Mini/Large Bear). Hunters' **dart tripwires** strung across
>   trails fire a volley for **5 damage** when crossed. Both are single-use and
>   spring on enemies *or* the player. Scattered **pits** are impassable holes.
> - **Life & dressing:** packs of coyotes, wolves, bears, bugbears and hill-dwelling
>   hawks (plus elite beavers, hunters and treants); background **squirrels** dart
>   about; trees, **stumps**, bushes and ferns line the treeline.
> - **Elite clearings (2026-11-09):** the **Hydra** holds the widest clearing, and
>   each of the five **Elemental Mages** leads the pack of a clearing of its own
>   (raising its element's totem in the fight).

#### Graveyard
- **Skeleton** — *in code*. **Act 4** (World 4, 2026-11-09): World 4 (trash roll), the Hamlet's crofts, the Basilica's nave.
- **Zombie** — *in code*. **Act 4** (World 4, 2026-11-09): World 4 (trash roll), the Hamlet's crofts, the Basilica's chapels.
- **Zombie dog**
- **Werewolf** — *in code*. Elite. Armor-piercing **Claw** (+3 vs armor) rakes a debuffed target a second time for half; consecutive claws on the same target arm **1 tempo faster** each time (reset on switching targets). **Act 4** (World 4, 2026-11-09): World 4 (mid roll), round the Hamlet's burning pond and in its far croft, under the Basilica's dome; one in the Blighted Green, one in the Confluence.
- **Treasure Bunny** (named the Wererabbit until 2026-10-26)
- **Ghoul**
- **Wight**
- **Screeches** — *a soul-like creature that can only be seen from its noise*
- **Vampire** — *in code*. Elite. Bite **life-steals 100% of health damage** (armor heals nothing); below 50% HP, **Bat Form** flits 6 squares away (2 charges, never recharge), always followed by **Absorb** — draining the healthiest player-side unit on the map (20, then 10). **Act 4** (World 4, 2026-11-09): World 4 (mid roll), the Hamlet's pond, the Basilica's transepts; one in the Blighted Green.
- **Necromancer** — *in code*. Elite. **Bolt** (range 10) also **Hexes 2 cards** in the hand (each +30 mana until played); **Summon** raises undead (first-pass roster: skeletons/zombies). **Raise the Fallen:** every summon of his that dies **rises again as a Skeleton and costs him 10 health**; any other ally that dies **within 8 squares** of him rises as a Skeleton too. A risen Skeleton rises no further and costs him nothing.
- **Bone Dragon** — *in code*. Elite (150 HP, resists 45% physical / 45% fire; Bite 12, Breath Swarm down a 6-tile line). Fought as the **second boss** in the **Boneyard** (`interior_kind == "boneyard"`, through a door at the east end of the Old Graveyard's deepest crypt): a large walled square gated on the west, with twelve **gravestones** (10 HP) in rows across it. The fight is meant to open with the **Necromancer** — the player's job is to stop him raising the dead, and what he leaves behind is those twelve stones (*the Necromancer part is not yet specified; the room is built in its post-prelude state*). Then the dragon: for every gravestone still standing he has **1 regen that never decays** (1 health a cycle per stone — shown as *Gravebound*); the only way to lower it is to break the stones. The catch: **grave diggers** (20 HP, three in all, only one out at a time) come out of the crypt door and repair a broken stone back to full in **8 tempo**, then vanish. Kill the stones, kill the diggers, and the dragon is beatable.
- **Bone dragon** — *in code*. Elite. **Breath Swarm**: 12 damage down a 6-tile line, hatching a **Swarm** beside every unit hit.
- **Grave digger**
- **The Consumed** — *a golem-like creature but far worse: something that has had its spirit consumed and is now flesh and hatred* — *in code*. Walks the Old Graveyard's deep crypts and the Ruined Library's deeper rooms.
- **Spirit collector** — *in code*. Keeps the Ruined Library: its deeper rooms, and two at the archive's dais (each Release Soul strengthens every living collector).
- **Grave titans** — *in code*. One holds the Old Graveyard's last crypt short of the Necromancer's. **Act 4** (World 4, 2026-11-09): World 4 (heavy roll).
- **Guilty Shifter**
- **Crypt Crawlers** — *in code*. The Old Graveyard's deep crypts and the Ruined Library's stacks. **Act 4** (World 4, 2026-11-09): World 4 (trash roll, caves), the Hamlet's lanes, the Basilica's chapels.

> **The Ruined Library (Act 1, Part 2) — built (2026-11-09).** `interior_kind ==
> "library"` (`dungeon_manager.gd`), its door — a broken stone arch on a raised
> block — in the World 1 field room nearest the Old Graveyard (the same part of the
> story, the same corner of the map).
>
> - **Layout:** from the door a long **nave** runs east, both its walls lined with
>   bookcases and a worn runner down it; either side a wing of three bays opening off
>   it and onto each other — **stacks** (rows of cases one deep, two-tile aisles
>   between them, a walkway at the ends and a gap through the long rows) and, the
>   widest bay of each wing, a **reading room** of desks. Across the east end, through
>   an arch, the **archive**: the deepest room, four ruined pillars, short runs of
>   cases, the runner leading to the **dais**.
> - **Dwellers (levels 8–10, the graveyard's band):** screechers heard between the
>   cases everywhere, crypt crawlers in the stacks, zombies in the near rooms, the
>   Consumed and Spirit Collectors past the middle; the archive is the elite room —
>   **two Spirit Collectors** at the dais with the Consumed, a crawler and a screecher.
> - **Atmosphere:** dim as the crypts; the light is the reading desks' candles (every
>   desk, and one at the end of every stack) and a cold glow over the dais; the hero
>   carries a torch. Cobwebs in the corners, bones on the floor, a few fallen cases.
>   A chest or two, a healing fountain in the archive.
> - **Art:** the undead pack's flagstones and stone (as the buildings); every bookcase
>   is the designer's tall case of books and scrolls (`town_scroll_case`), every desk
>   the designer's desk with its candle, quill and papers (`town_contract_desk`) — no
>   Craftpix pack draws a bookcase; the barrow pack's ruined pillars, arch, stones and
>   bones; the cave's cobwebs.
> - `[TBD]`: what the player finds here (the "first clues"), its quests and NPCs.

#### Cave
- **Bear**
- **Troll** — *in code as Armored Troll*. **Act 4** (World 4, 2026-11-09): World 4's caves.
- **Yeti**
- **Goblin** — *in code as Fire Goblin variants (fire-themed)*. **Act 4** (World 4, 2026-11-09): World 4's caves (the warband and a shaman in each).
- **Kobold**
- **Orc**
- **Embodied Darkness**
- **Bats**
- **Flesh-eating worms**
- **Tunnel Rippers**
- **Pale Fang Cats**
- **Stonepedes**
- **Stalagmites** *(living)*
- **Troglodytes**
- **Gnome**
- **The Hollowed**
- **Leviathans**
- **Stone Drake**

> **Caves — built/enhanced.** The cave interiors (`interior_kind == "cave"`) are a
> network of organic stone **tunnels and chambers**, now dressed to match: they
> are **darker even than the sewers** (lowest ambient/sun, heaviest gloom, and a
> **player-carried torch**), with **stalagmites** rising from the floor,
> **stalactites** hanging from the dark above (some **dripping**), cold **water
> puddles**, shallow **divots** and scattered rubble. Reached from cave-mouth
> sites in the overworld.

> **Boss fights — ground rules (designer).** A boss fight is a **cutscene
> room**: the player steps through a door into the boss's own interior, and
> cinematics play there (*not yet built*; the hooks are the room's entry).
> The room is **enclosed** — there is no way out until the boss is dead, when
> the exit appears and leads back through the door the player came in by.
> **Nothing resets on the threshold:** the player's hand is exactly what it was
> outside, and every buff and debuff on them carries in (`main._enter_interior`
> hands the live effects over; `DungeonManager.is_boss_room` marks the rooms).
> Built so far: the **Rat King's Lair** (Sewer), the **Boneyard** (Old
> Graveyard, Bone Dragon) and **Hell's Gate** (Caves, Cerberus — the one room
> whose objective is a door, not the boss) — see the bestiary entries — and in
> the Underworld the Labyrinth, Thanatos's Hall and three **guardian rooms**
> held by a band instead of one boss (the Crucible, the Throne of Dis, the
> Breach; Section 4, Act 2): they open when the last guardian falls. Like everything in the
> world, they are dressed with the purchased packs (cliff tiles, headstones,
> gates): nothing is modelled by hand where a pack piece exists, and the few
> things no pack has (the rat nests) are drawn to match (see CLAUDE.md,
> *Art: Packs First*).

#### Sewer
*The game's opening dungeon — see **The Sewers (Act 1, Part 1)** below for the
built level. The roster is themed and in code:*
- **Rats** — *in code as Wererat / Archer Rat*. The player's first kills; the Wererat scurries and bites, the Archer Rat kites.
- **Sludge Being** — *in code*. Minion. **Ranged ooze** (10 HP): wades close or spits acid from range 6. The "oozes" the player fights alongside the rats at the entrance.
- **Pipe Crawler** — *in code*. Minion. **Fast skirmisher** (20 HP): creeps out of the wall pipes, moves on a cheap 2-tempo so it closes quickly; its claw can disarm you.
- **Sewer Cobra** — *in code*. Elite. **Armored ambusher** (40 HP, 20 armor, 12 dmg): lurks in the channels; break its armor to expose it, or its bite hurts. Guards the deepest chamber.
- **Rat King** — *in code*. Elite, **first mini-boss** (90 HP, 10 armor) and the game's **first boss room**: the **Rat King's Lair**, entered through a door in the central cistern (`interior_kind == "ratking"`). A round den, entered from the west; the king waits at the bottom with three Wererats in front of him and two Archer Rats behind. Straight across the room stands a cliff of high ground, with two more cliffs 45° to either side — each the pack's own cliff tile, a face row under a walkable top — and a **rat nest** (15 HP) at the foot of each face. Treading on a nest sends its Archer Rat up to the top of the cliff, where it holds the high ground. At **50%, then 30%, then 30% again** of his health the king bolts for a random untouched nest and feeds on it — the left nest restores 20% of his health, the middle 30%, the right 50% — and a nest he has fed on is spent; he never revisits one. Tear the nests down first and he has nowhere to run. Bites and repositions relentlessly otherwise.
- **Swarm** — *in code*. Minion. **Fast swarm** (10 HP): one creature rendered as a boil of vermin/insects; blitzes 8 tiles at a time. *one creature, but a bunch of bugs representing one*
- **Faithless cultist** — `[TBD]`.
- **The drowned** — `[TBD]`.
- **Slime** — `[TBD]` (smaller cousin of the Sludge Being).

> **The Sewers (Act 1, Part 1) — built.** This is the **first dungeon the player
> ever enters**, and the first location fully realised in code
> (`dungeon_manager.gd`, `interior_kind == "sewer"`). It is reached from a
> **sewer grate / manhole** in the World 1 overworld (a guaranteed site there).
>
> - **Layout:** a man-made **trunk tunnel** runs the length of the level with a
>   **water channel down its spine**; brick **cistern chambers** bud off it above
>   and below, joined by short access shafts. The far-west chamber is the entry;
>   the **central cistern holds the Rat King's door guard and the door to the
>   Rat King's Lair** (his own sealed boss room, see the bestiary entry); the
>   far-east chamber is the deepest, guarded by a Sewer Cobra.
> - **Progression (west → east):** the player opens by **killing rats and fighting
>   oozes** (Wererats, Archer Rats, Sludge Beings), reaches the central cistern,
>   cuts through the guard and steps into the **Rat King's Lair** for the
>   mini-boss, then descends into deadlier water — **Sewer Cobras, Swarms and
>   Pipe Crawlers** (plus more sludge).
> - **Atmosphere:** deliberately **dim and claustrophobic**. Near-lightless ambient
>   with a thick dank haze; **each player carries their own pool of torchlight**;
>   **wall torches** throw flickering light over wet brick; **fog of war reveals
>   less** than the surface. Dressing includes **wall pipes pouring water**,
>   **rising steam off the channels**, **iron floor grates**, **circular sliding
>   stone doors** at the cistern mouths, **manhole covers**, damp rubble and algae,
>   and **background mice** scuttling along the walls (purely cosmetic — the player
>   never interacts with them).

#### Mountains
**The Mountain Pass is built** (2026-11-05; `interior_kind == "mountains"`, reached from World 1's overworld by the Mountain Pass site): a snowy mountainside climbing up the screen in four terraces (valley floor, two terraces, the summit), with raised outcrops on the lower ones. **Elevation is walked one level a step** (`DungeonManager.can_step`): neighbouring terraces are a cliff apart, and no one walks up or down a cliff — a south-facing drop is a rock face (`cliff_face_tiles`), the rest the ledge's lip. The way up is a **step** halfway up a cliff (`step_tiles`, the trodden track); every ledge can be reached on foot. Fliers (`immune_to_high_ground`) cross cliffs; so would a climber (`PlayerStats.climbs_cliffs`, for climbing gear — none in the game yet); a blink, leap or knockback is not walking. Weregoats and sabertooths roam the low snowfields; snow wraiths and ice trolls hold the ledges and outcrops; wyverns, white manticores and rocs ride the heights; the summit holds an ice troll and a flier; every one of the seven is met on the Pass (2026-11-09: one the dice leave out takes the place of a kin that came up twice). A chest waits on each outcrop and the summit. Art: the winter pack's ground, rock and props (Frostreach's, World 3's until it became Heaven) (no pack draws stairs: the steps are the slush track). Granite Colossi stay out until they have moves.
**Its caves** (2026-11-05): two cave mouths open out of the Pass's cliffs. The **Ice Cave** (`interior_kind == "icecave"`, on a lower terrace) is the cave layout frozen — snow floor, frosted rock, ice crystals for stalagmites — with the mountain's creatures and an ice troll in its deepest chamber. (World 3's caves were Ice Caves too while it was Frostreach; since 2026-11-09 World 3 is Heaven and the Ice Caves open off the Pass alone.) The **Ice Troll Lair** (`interior_kind == "trolllair"`, high up near the summit) is a treasure pocket meant to kill the unready: a tunnel opens on the trolls' den, one frozen room where **five ice trolls** (two at the vault's gap) and four snow wraiths wake together; in the den's corner the **vault**, walled by **high mountains** (no walking on them, no blinking across them — `blink_clear`; a later quest might have Olorin send the hero for mountain boots) with a **single one-tile way in**, holds a **legendary chest** (the one chest allowed a legendary) and **gold lying about the floor** — walked onto, it is taken, and stays taken (`DungeonManager.gold_piles`, the treasure pack's gold). No fountain in the lair.
- **Weregoat** — *in code*. **Act 4** (World 4, 2026-11-09): World 4 (trash roll), the Basilica's choir, the Heights' low terraces.
- **Wyvern** — *in code*. Elite. Flier (ignores high ground). **Talon Grab** (2-cycle cooldown): flies above its target, 25 damage, and drags them to an open space **8 squares away**. **Act 4** (World 4, 2026-11-09): one in the Fallen Reliquary.
- **Rocs** — *in code*. **Act 4** (World 4, 2026-11-09): the Riven Heights' heights and top.
- **Ice Troll** — *in code*. Elite. Every attack adds a stack of **frost (Cold) and Brittle**; when an attack **freezes** its target, **Clobber (50)** triggers automatically; he can also wind Clobber up as a 10-tempo blow of its own (designer, 2026-11-08). **Act 4** (World 4, 2026-11-09): World 4 (heavy roll, caves), the top of the Riven Heights, the Confluence's gauntlet.
- **Snow Wraiths** — *in code*. **Act 4** (World 4, 2026-11-09): the Riven Heights' ledges.
- **Granite Colossi**
- **White Manticores** — *in code*. Elite. Flier. **Stinger** (5-tempo cooldown): 25 damage + **Clumsy** + **8 Poison**. **Act 4** (World 4, 2026-11-09): the Basilica's apse, the Fallen Reliquary.
- **Snow leopard**
- **Sabertooth tiger** — *in code*. **Act 4** (World 4, 2026-11-09): World 4 (mid roll), the Heights' low terraces.

#### Underworld
- **Cerberus** — *in code*. Boss (sheet: 250 HP, 50 armor, 25 bites, 6 spaces a move; resists 30% physical / 40% fire / 15% lightning). **Guards Hell's Door** in the **third boss room, Hell's Gate** (`interior_kind == "hellgate"`, through a door at the east end of the first world's deepest cave): one long cavern hall with lava in its corners, the iron door (the cave pack's gate, 150 HP) set in the east wall and the hound before it. **The objective is the door, not the hound**: break it and the way down opens (and the way back) — killing Cerberus is optional, just far easier to work around a corpse. At **75%, 50% and 33%** health the door **seals itself against all damage for 10 tempo**; and the door **counts as Cerberus's ally**, so its drop below half feeds his Guardian of Death. His kit, from the sheet: **Bite** (5 tempo, 25) — below 66% health the **second head** bites too (25 + 5 Bleed), below 33% the **third** as well (25, life-stolen); **Swipe** (8 tempo): 8 Bleed; **Venom Tail** (15 tempo): the victim discards 3 random cards and is stunned 15 tempo, and when that lifts gains 2 Vulnerable and 10 tempo of Cuffed; **Roar** (12 tempo): +25 armor and 25 thorns. Passives: **Guardian of Death** — the first time *he* drops below 50% he gains Brace 30% for 5 incoming hits, and *every* time any other unit within 8 squares drops below 50% (foe or ally; heal back over half and drop again and it counts again) he gains it again; **Deathyard Dog** — whenever a foe heals within 5 squares, +15 Strengthen. Otherwise straightforward, and very hard.
- **Thanatos** — *in code (first pass)*. Boss of Thanatos Closet; see Act 2 above.
- **Succubus** — *in code*. Lives on the Underworld's surface and in its Burning Caves, on the Brimstone Rift's banks, in the Citadel of Dis's courts and halls, on the Ashen Stair's low terraces; two in the court of Dis (Throne of Dis), one among the Breach's wardens. **Invading Heaven** (Act 3): its surface, the Sanctum's nave and chapels, the Garden's beds, the Spire's low terraces, the Causeway's banks; two at the Desecrated Altar, one at the Sickened Font. **Act 4** (World 4, 2026-11-09): World 4 (trash roll), the Hamlet's crofts, the Vale's banks, the Basilica's transepts, the Heights' low terraces; one in the Blighted Green.
- **Demon** — *in code*. The surface (the arena's pair), the Burning Caves and Thanatos Closet; the Rift's banks and far landing, the Citadel (its inner court's gatekeepers among them), the Stair's low terraces; two in the court of Dis, two among the Breach's wardens. **Invading Heaven**: its surface (the arena's pair), the Sanctum's crossing, transepts and choir, round the Garden's fountain, the Spire's low terraces, the Causeway's banks and far landing; one in the Belfry, two among the Rent's wardens. **Act 4** (World 4, 2026-11-09): World 4 (mid and heavy rolls, its arena, caves), round the Hamlet's pond and in its far croft, the Vale's banks and far landing, the Basilica's crossing and choir, the Heights' low terraces; one in the Blighted Green, two in the Hellmouth, two in the Confluence.
- **Ifrits** — *in code*. Elite. **Fire Breath**: a 5x5 sheet of flame, and he keeps breathing it for 6 more tempo (a Channel, designer 2026-11-08) — the tiles burn all the while and 3 tempo after; **Backflip** springs it 3 squares back from any single blow over 40 damage. The surface's arena and deep rooms (a lord of the deep); **the Crucible** (a pair), the Citadel's inner court, enthroned in the **Throne of Dis**, the top of the Ashen Stair, and two of **the Breach's** wardens. **Act 4** (World 4, 2026-11-09): World 4's arena and its caves' deepest chambers, the Vale's far landing; **two in the Hellmouth**, one in the Confluence.
- **Mind eater** — *in code*. The surface and caves, Thanatos Closet; the Rift's banks, the Citadel's halls and inner court, the Stair's ledges; two in the court of Dis, one at the Breach's gate. **Invading Heaven**: its surface, the Sanctum's chapels and choir, the Garden's beds, the Spire's ledges, the Causeway's banks; one each at the Desecrated Altar, the Sickened Font, the Belfry and the Rent. **Act 4** (World 4, 2026-11-09): World 4 (trash roll), the Basilica's chapels, the Heights' ledges; one in the Fallen Reliquary.
- **Specters** — *in code*. The surface and caves, Thanatos Closet; the Rift's banks, the Citadel, the Stair's terraces and ledges. **Invading Heaven**: its surface, the Sanctum, the Garden's beds and walks, the Spire's terraces and ledges, the Causeway's banks. **Act 4** (World 4, 2026-11-09): World 4 (trash roll, caves), the Hamlet's lanes, the Vale's banks, the Basilica's nave, the Heights' ledges.
- **Echo Beasts**
- **Magma Spiders** — *in code*. The surface and caves; **nesting on the Brimstone Rift's islands** (and at its far landing), on the Ashen Stair's ledges. **Act 4** (World 4, 2026-11-09): World 4 (trash roll, caves), the Vale's banks, **nesting on its islands**.
- **Pit Fiends** — design mock-up (stats & moves TBD): placed nowhere.
- **Ash Harpies** — *in code*. Flier. The surface (the arena) and caves; over the Rift's banks and far landing, the Citadel's courts, the Ashen Stair's heights; two among the Breach's wardens. **Invading Heaven**: over its surface, the Sanctum's crossing, the Garden's walks and fountain, the Spire's heights, the Causeway's banks and islands; two in the Belfry, one at the Rent. **Act 4** (World 4, 2026-11-09): World 4 (ranged roll), the Hamlet's lanes, the Vale's banks, islands and landing, the Basilica's crossing, the Heights.
- **Inflamed Minotaur** — *in code*. **Boss** (sheet: level 9, 350 HP, 100 armor, 35 + 2 Burn a hit, 6 spaces a move; resists 15% physical / 50% fire / 25% lightning). Fought in **the fourth boss room, the Labyrinth** (`interior_kind == "labyrinth"`, through a door at the east end of the second world's deepest cave): a square maze of two-wide passages in the cave pack's rock around an open court with lava in its corners, the bull waiting in the court; sealed until he is dead, and his death opens the way out. Leaves **fire in its wake** (Traps — see 5.1; along every charge too) and heals 10 when the fire burns a player. Once he has taken **over 20 damage since his last leap** (a running total across hits, not a single blow) he makes a **Labyrinth Leap** (14 spaces to a random open tile, **minus 1 per Slow stack — Slow is his weakness**, Sword of Theseus applies it; minotaur-specific, not a universal slow rule), then **Bull Rush** a random **5 to 15 tempo** later — damage equal to the spaces covered by leap and rush together, spaces×4% chance to stun **and Weaken** the final target, Vulnerable to the target and everything trampled en route (a player is always preferred over summons). He walks the maze by the real route round its walls. **The room's curse — Lost in the Labyrinth:** every **25 tempo** the player is Lost for **15**: the hand is reshuffled into a random order and **must be played left to right** (the hand shows one card per slot, in order, and only the first in line can be played), and **nothing can be drawn** by any means (Debuff `LOST`). It lifts the moment the Minotaur dies.

#### Heavens
*Where they live (2026-11-09): World 3, the corrupted Heaven — see Section 4, Act 3 — and, fallen with it, World 4, the Earth returned to (Act 4).*
- **Cherub** — *in code*. Trash (band 33), winged (crosses cliffs). **Love's Arrow** (2; for 5 tempo it cannot be attacked directly — area, poison and burn still land; the first arrow flies the moment you enter range 4, then a 10-tempo clock). **Heaven's rank and file**: everywhere on World 3's surface (and the arena), in every Act 3 place — the Sanctum's nave, the Garden's beds and walks, the Spire's ledges and heights, the Causeway's banks and its islands (which only fliers keep) — and two among each sealed room's guardians. **Act 4** (World 4, 2026-11-09): World 4 (trash and ranged rolls, its arena) and every Act 4 place; two in the Blighted Green, the Hellmouth and the Fallen Reliquary, one in the Confluence.
- **Djinn** — *in code*. Elite (band 35). **Chain Lightning** (35 per unit; cast range 5, bounds arc 4). Every attack against it puts **3 Wishes** in the attacker's hand — each sears the holder for 1/3 of that attack's damage per cycle held, and costs **60 mana (0 tempo)** to be rid of. **Heaven's elite**: World 3's arena; the Sanctum's apse, the Garden's grove, the top of the Spire, the Causeway's far landing; **on the Desecrated Altar**, **two at the Sickened Font**, beneath the Belfry's piers, **two among the Rent's wardens**. (Still a lord of the deep in the Ferryman's Toll.) **Act 4** (World 4, 2026-11-09): World 4's arena, the Basilica's apse; **two in the Fallen Reliquary** (one on the relic), two in the Confluence's gauntlet.
- **Corrupted Archangel** — design mock-up (stats & moves TBD): placed nowhere.

---

## 6. End-Game

**Being redesigned from scratch** (designer, 2026-11-07). The town-building
end-game (the City: resources gathered on the adventure and sent home through
a satchel, buildings and their upgrades, expeditions, raids on rival cities,
and trials that struck the town) was removed from the game, code and saves
alike; see `docs/audit/REPORT.md` for what was taken out. The **Town Hall**
still stands on the town plaza as scenery, with nothing attached.

What any new end-game must keep: the `CLAUDE.md` guardrail. The persistent
character is the spine, and nothing resets.

---

## 7. The Persistent Character (Cast)

The player carries **one** character through the entire story and into the
end-game. The current playable roster (`scripts/character/character_data.gd`):

| Character | Fantasy | Signature archetypes | Slot specialty |
|-----------|---------|----------------------|----------------|
| **Brad** | Tank / bruiser; pain is strength | Berserker, Warden, The Ancient, The Fallen | War Rack (one back-slung weapon, drawn two-handed for free); chest items weigh 20% less |
| **Ryan** | Dexterous duelist / rogue | Relentless Blade, Light Foot, Apothecary, Shadow Blade | 2 belt slots; belt cards cost 1 less mana |
| **Stephen** | Versatile killer / marksman | The Apex, Sentinel, Ranger, Avenger | standard slots; cheaper weapon swaps; off hand empowered by his White Sleeve (110%; others 90%) |
| **Cory** | Druid / monk / witherer | Monk, Lurker, Druid, Atrophist | 2 gauntlet slots; gauntlet-skill synergy |
| **Jeremy** | Elemental mage | Evocation, Abjurer, Shepherd, Poltergeist | 3 ring slots; first ring trigger fires twice every 3rd cycle |

All five share the same slot baseline (1 helm, 2 rings, 1 belt, 1 chest, 1 main
hand, 1 off hand, 1 pair of boots, 1 gauntlet) and the same 5-card basic deck;
the table lists each character's single deviation from it. There are no
character classes and no per-character starter decks: the playstyles come
from the built-in passives, written up in
[`CHARACTERS.md`](CHARACTERS.md).

> These are the *player's* avatars, distinct from Olorin (the guide). Whether
> any of them have story-specific arcs woven into the Acts is `[TBD]`.

---

## 8. Story ↔ Systems Map (what already exists in code)

To "build upon this," here is how the narrative connects to systems already in
the repo. Keep this table honest as the code changes.

| Story element | Where it lives today | Notes |
|---------------|----------------------|-------|
| **Olorin (guide / quest-giver)** | `scripts/menus/town.gd` (`_create_olorin_npc`, `vendor_info["Olorin"]`), `scripts/core/quest_manager.gd`, `scripts/ui/olorin.gd` (spoken lessons; the field tour), `scripts/core/main.gd` (`_place_field_olorin`) | Already an in-town NPC: *"A wise old man with quests for brave adventurers."* The first time the player leaves town he waits beside the Transport Portal and reads them the screen — tempo, the bars, the journal icons, the action column, flash and brain — lighting each part in turn (`show_field_tour`; Shift beside him replays it that visit). First quest: **Rat Infestation** (clear 5 wererats from the sewers). The hidden tutorial quest **A Mythic Find** (the Bladed Doughnut → Olorin's mythic lesson → the Blacksmith's meld → the Wooden Sword) opens itself on the first story kill. Origami Swans (folded from destroyed cards) become Culling Stones at 20. |
| **Acts / planes** | `scripts/core/dungeon_manager.gd` → `WORLD_PALETTES` (1–5), `art_world()` (World 2 wears the hell palette, "The Underworld"; World 4 World 1's Earth, corrupted); World 3 is Heaven ("The Tarnished Heavens", `heaven_land()`, `HEAVEN_ART`); World 4 the Earth returned to ("The Blighted Frontier", `BLIGHT_PALETTE`, `earth_return_land()`, `EARTH_RETURN_ART`) | Themes are explicitly **placeholder** ("final per-world themes TBD"). Current names: Verdant Frontier, The Tarnished Heavens (was Frostreach, whose snow is `FROST_PALETTE` on the Mountain Pass), The Underworld (was Emberfall), The Blighted Frontier (World 4 since 2026-11-09; it wore the Amber Wastes, `WORLD_PALETTES[2]`, now worn by no world), Umbral Expanse. The lore here is what those palettes should *become*. |
| **Habitats / biomes** | `dungeon_manager.gd` palettes + `CAVE_PALETTE`, `BUILDING_PALETTE`, `SEWER_PALETTE`; site generation (caves, buildings, sewers) | The generator distinguishes overworld vs. cave vs. building vs. **sewer** interiors — a natural hook for habitat-specific enemy spawn tables (Section 5). |
| **The Sewers (Act 1, Part 1)** | `dungeon_manager.gd` (`interior_kind == "sewer"`: `_generate_sewer_layout`, `_build_sewer_decorations`, `_define_sewer_spawn_zones`), `main.gd` (`_apply_world_ambience` sewer branch + `_ensure_player_torch`), `torch_flicker.gd`, `sewer_critter.gd` | **Built.** The opening dungeon: trunk + water channels, Rat King arena, west→east rat/ooze → boss → croc/swarm/crawler progression, dim torchlit atmosphere, reduced fog. Reached via a sewer grate site in World 1. See Section 5.4. |
| **The Greenwood (Act 1, Forest)** | `dungeon_manager.gd` (`interior_kind == "forest"`: `_generate_forest_layout`, `_place_forest_features`, `_build_forest_decorations`, `_define_forest_spawn_zones`), `main.gd` (forest ambience, terrain-trap + tree-climb systems, tutorial), `sewer_critter.gd` (squirrels) | **Built.** Open clearings/trails/hills; climbable trees → high ground (+ one-time tutorial); bear traps (7 dmg / 10 to bears) and hunter dart tripwires (5 dmg) that hit players *and* enemies; pits; squirrels; bright fog. Reached via a forest trailhead site in World 1. See Section 5.4. |
| **The Ruined Library (Act 1, Part 2)** | `dungeon_manager.gd` (`interior_kind == "library"`: `_generate_library_layout`, `_library_stack_rows`, `_place_library_desks`, `_build_library_decorations`, `_define_library_spawn_zones`; `_place_library_site`, `_build_library_entrance`), `main.gd` (`_apply_world_ambience` library branch + player torch) | **Built** (2026-11-09). Nave, stacks and reading rooms, the archive (two Spirit Collectors); candle-lit; door beside the Old Graveyard in World 1. Its clues `[TBD]`. See Section 5.4, Graveyard. |
| **Act 1 spawn tables** | `dungeon_manager.gd` (`_define_forest_spawn_zones` + `_forest_heads`, `_define_graveyard_spawn_zones`, `_define_mountain_spawn_zones`, `_ensure_zone_types`), `tests/test_act1_spawns.gd` | Every built Act 1 creature lives somewhere in World 1 (2026-11-09): the Hydra and the five Elemental Mages in the Greenwood, the Grave Titan and the Consumed in the Old Graveyard, the Spirit Collectors in the Ruined Library, all seven of the Mountains roster on the Mountain Pass. The Granite Colossus (no moves) stays out. |
| **The Mountain Pass (Act 1, Mountains)** | `dungeon_manager.gd` (`interior_kind == "mountains"`: `_generate_mountain_layout`, `_mountain_connect`, `_define_mountain_spawn_zones`; `can_step`, `cliff_face_tiles`, `step_tiles`), `player.gd` (`step_check`), `enemy.gd` (`_can_step`, route-first on cliffs), `main.gd` (`_climber_blocked_tiles`) | **Built.** Terraced snowy mountainside, cliffs walked round by steps, enemies on the ledges, fliers over the cliffs. Reached via the Mountain Pass site in World 1. See Section 5.4. |
| **Ice Caves & the Ice Troll Lair (Act 1, Mountains)** | `dungeon_manager.gd` (`icecave`: the cave layout, `_define_ice_cave_spawn_zones`; `trolllair`: `_generate_troll_lair_layout`, `mountain_wall_tiles`, `blink_clear`, `_place_troll_hoard`, `gold_piles` / `take_gold_pile`, `_create_chest(..., legendary)`; `_place_mountain_caves`, `_place_door_site`), `main.gd` (`_check_gold_pile_pickup`) | **Built.** Off the Mountain Pass (World 3's Ice Caves went when it became Heaven, 2026-11-09). |
| **The Brimstone Rift, the Citadel of Dis, the Ashen Stair (Act 2, parts 2–4)** | `dungeon_manager.gd` (`ACT2_KINDS`, `act2_place()`; `_place_act2_sites`; `rift`: `_generate_rift_layout`, `_rift_connect`, `rift_bridges`, `_lay_bridge_sprites`, `_define_rift_spawn_zones`; `citadel`: `_generate_citadel_layout`, `_dress_fortress_walls`, `_place_braziers`, `_define_citadel_spawn_zones`; `ascent`: `_generate_mountain_layout` + `_place_ascent_lava`, `_prune_dead_ends`, `_place_breach_door`, `_define_ascent_spawn_zones`; the sealed rooms `crucible` / `throne` / `breach`: `GUARDIAN_ROOMS`, `guardian_placements`, `_place_breach_ascent`), `main.gd` (`_setup_guardian_room`, `_guardians_fallen`, kind `"ascend"` in `_try_interact_site`), `craftpix_props.gd` (`cursed_bridge_h` / `_v`, the cursed land pack's vein bridges), `sandbox_ui.gd` (Boss Simulator) | **Built** (places & enemies only; beats `[TBD]`). Lava-river canyon with vein bridges and island nests; a fortress of courts and pillared halls; a terraced climb to the Breach, whose wardens' fall opens the way up to the next world. See Section 4, Act 2. Tests: `tests/test_act2_parts.gd`. |
| **The corrupted Heaven — World 3 and Act 3's four places** | `dungeon_manager.gd` (`WORLD_PALETTES[3]`, `HEAVEN_ART` / `heaven_art()` — the stand-in table — `heaven_land()`, `ACT3_KINDS`, `act3_place()`, `PROP_ROLES["heaven"]`, `HEAVEN_TRASH`; `_place_act3_sites`, `_build_heaven_site`, `_place_heaven_arrival` (`HEAVEN_ARRIVAL_ID`), `_place_heaven_landmarks`; `sanctum`: `_generate_sanctum_layout`, `_define_sanctum_spawn_zones`; `garden`: `_generate_garden_layout`; `spire`: `_generate_mountain_layout` + `_prune_dead_ends`, `_place_summit_door`; `causeway`: `_generate_rift_layout`; the sealed rooms `altar` / `font` / `belfry` / `rent` in `GUARDIAN_ROOMS`, `_place_rent_descent`), `main.gd` (`_travel_to_world(level, arrive_at, interior, parent)`, kinds `"breach_down"` / `"descend"` in `_try_interact_site`, `_setup_guardian_room`), `craftpix_props.gd` (`glow_*`, the glowing-cave pack's growth), `sandbox_ui.gd` (Boss Simulator) | **Built** (places & enemies only; beats `[TBD]`; art stand-ins). A cruciform temple, an overrun garden, a terraced climb and a broken causeway over a gulf, each with a sealed room; the Rent leads down to World 4, the arrival back down to the Breach. See Section 4, Act 3. Tests: `tests/test_act3_heaven.gd`. |
| **The Earth returned to — World 4 and Act 4's four places** | `dungeon_manager.gd` (`BLIGHT_PALETTE`, `EARTH_RETURN_ART` / `earth_art()` — the stand-in table — `earth_return_land()`, `ACT4_KINDS`, `act4_place()`, `ACT4_BAND` / `spawn_band_floor()`, `ACT4_TRASH` / `_MID` / `_HEAVY` / `_RANGED` (`_act4_roll`), `blight_tears` / `_plane_at` (props by plane), `_place_blight_tears`, `_dress_blight_tears`, `_place_tear_landmarks`, `_dress_act4_walls`; `_place_act4_sites`, `_build_earth_site`, `_place_earth_arrival` (`EARTH_ARRIVAL_ID`); `hamlet`: `_generate_garden_layout` + cottages (`_generate_hamlet_layout`); `vale`: `_generate_rift_layout` + `_blight_lava_banks`; `basilica`: `_generate_sanctum_layout` + fallen columns; `riven`: `_generate_mountain_layout` + `_place_ascent_lava`, `_blight_riven`, `_place_summit_door`; the sealed rooms `green` / `hellmouth` / `reliquary` / `confluence` in `GUARDIAN_ROOMS` — the Confluence's `confluence_boss_cell` is the final boss's empty slot, `[TBD]`), `enemy.gd` (`band_floor`), `enemy_spawner.gd` (sets it), `main.gd` (kind `"rent_up"` and the Rent's `"descend"` arrival in `_try_interact_site`, `GUARDIAN_ROOM_LOGS`), `sandbox_ui.gd` (Boss Simulator) | **Built** (places & enemies only; beats and **the final boss `[TBD]`**; art stand-ins). A torn hamlet, a valley Hell bleeds through, Heaven's basilica fallen, a terraced climb to the Confluence — each with a sealed room of all three planes; the arrival back up to the Rent. See Section 4, Act 4. Tests: `tests/test_act4_return.gd`. |
| **Caves (Act 1, Cave)** | `dungeon_manager.gd` (`interior_kind == "cave"`: `_generate_cave_layout` + `_place_cave_puddles`, `_build_cave_decorations`, darkened `CAVE_PALETTE`), `main.gd` (cave ambience + player torch) | **Built/enhanced.** Dark stone tunnels darker than the sewers; stalagmites, stalactites (dripping), puddles, divots, player torch. Reached via cave-mouth sites. See Section 5.4. |
| **Bestiary** | `Enemy.EnemyType`, `CharacterData.defeated_monster_ids` | Per-character record of story kills; feeds the compendium and future intent-reveals. 68 enemy types today, structures, the dojo dummy and design mock-ups included (Section 5.4). |
| **Quests** | `scripts/core/quest_manager.gd` | Data-driven quest chain from Olorin and the Sellsword (Rat Infestation → Holy Water for the Well, Bear Traps, The Faithless, Fire Wall Breach, The High Road, The Missing Woodcutter, A Debt to the Sellsword, What the Crows Saw; Ferryman's Toll in Act 2). World objects they need: the Town Well, the Drowned Shrine (sewer), rescue NPCs, the feather trail and the hidden Old Graveyard. |
| **Healing fountains** | `scripts/core/dungeon_manager.gd` (`_place_fountains`) | Holy-water basins in every zone: drink to heal (spends the blessing; a vial of Holy Water from enemies restores it) or bathe once for a +20% XP blessing. The pilgrim's rest between Olorin's trials. |
| **Town hub** | `scripts/menus/town.gd` | Persistent vendors (Blacksmith, Armory, Card Dealer, Accessory Shop, Stash) + Olorin + waypoint/transport, and the Town Hall as scenery. The first time the player speaks to the Blacksmith, the Armory keeper, the Card Dealer or the Sellsword, each introduces themselves and their trade in the speech bar (`KEEPER_INTROS`, once per character); they go by title only — the designer will name them. |

### Code naming follow-up `[TODO]`
The narrative uses **"Act"** exclusively, but the code still says `world_level`
and `WORLD_PALETTES`. Aligning the code to "Act" is a **separate, larger
refactor** (touches `dungeon_manager.gd`, `main.gd`, save serialization, and
tests). Tracked here; not done yet. There is also a **count mismatch**: 4 Acts
vs. 5 dungeon palettes — to be reconciled, ideally by re-theming palettes
toward **habitats** rather than acts.

---

## 9. Open Questions & Next Steps

Decided:
- ✅ **The town-building end-game is removed** (2026-11-07) and the end-game
  is being redesigned (Section 6). The older roguelike end-game is removed
  too.
- ✅ **Terminology:** four **Acts** across one world; each Act is a plane.
- ✅ **Bestiary taxonomy:** catalogued by **habitat** (Forest, Graveyard, Cave,
  Sewer, Mountains, Underworld, Heavens), as flexible guidelines.
- ✅ **The Sewers (Act 1, Part 1) are built** — opening dungeon, themed roster,
  Rat King mini-boss, dim torchlit atmosphere. See Section 5.4 / Section 8.
- ✅ **The Mountain Pass is built** (Act 1, Mountains) — and with it, walking
  elevation: up or down one level a step, cliffs walked round by their steps.
  See Section 5.4 / §8.
- ✅ **The Ruined Library is built** (2026-11-09; Act 1, Part 2 beside the Old
  Graveyard) and **every built Act 1 creature is placed** in World 1. See Section 5.4 / §8.
- ✅ **The Greenwood forest and the Caves are built** — woodland of clearings,
  trails and hills with climbable trees (high ground + tutorial), bear traps and
  hunters' dart tripwires, pits and squirrels; and dark, dripping cave tunnels
  with stalagmites/stalactites, puddles and a player torch. See Section 5.4 / §8.

- ✅ **World 3 is the corrupted Heaven** (2026-11-09; Act 3's four places and its host built, with stand-in art until the designer's Heaven boards — Section 4). The story of its parts stays `[TBD]`.
- ✅ **World 4 is the Earth returned to** (2026-11-09; Act 4's four places — the last the Confluence, the final chamber — and its host of all three planes built, with stand-in art until the designer's Act 4 boards — Section 4). The story of its parts and **the final boss** stay `[TBD]` (question 5 below); the Confluence's dais waits empty for it.

Still open:
0. **Design the new end-game** (Section 6).
1. **Solidify creature themes:** go habitat by habitat and define each
   creature's tier, role, signature mechanic, and drops (Section 5.2 template).
   *(Next pass — the roster names are captured; mechanics are `[TBD]`.)*
2. **Spawn tables:** map habitats → `dungeon_manager` palettes/interiors so the
   right creatures appear in the right places.
3. **Code rename + palette re-theme:** `world_*` → `act_*`, and re-theme the
   5 palettes toward habitats (Section 8 TODO).
4. **Part beats:** flesh out the 16 `[TBD]` part slots (Section 4).
5. **Final boss & the "true target" reveal:** define the antagonist (Act 4).
6. **Character arcs & Olorin's expanded quest line.**

When any of these is answered, **update this file** so the canon stays in one
place.
