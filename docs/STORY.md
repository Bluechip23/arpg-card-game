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
> and end. The roguelike is the *end-game loop* that unlocks after the story —
> not the spine of the game.

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
| **Act 4** | **Earth (Return)** | The true target — home, under siege |

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
- **Part slots (`[TBD]`):** 1) Town & Sewers (Olorin's first quests) · 2) Cemetery / Library (first clues) · 3) Forests / wilds · 4) Act 1 climax / threshold downward.

### Act 2 — Hell: The Underworld
*The descent. The apparent source of the rot.*

- **Theme:** fire, darkness, sickness.
- **Habitats it draws from:** Underworld (primarily); Cave bleed-over.
- **Tone:** oppressive and infernal. The player reaches the "source" — and
  learns the corruption is spreading *upward*, not contained here.
- **Parts 1–4:** `[TBD]`

### Act 3 — Heaven (Corrupted)
*The ascent. The Underworld has infiltrated the Heavens; the player climbs to
stop the invasion.*

- **Theme:** what was once pure is now gloomy and sickened.
- **Habitats it draws from:** Heavens (with Underworld invaders present).
- **Tone:** tragic corruption — beauty defiled. The twist: the heavenly
  invasion was never the real goal.
- **Parts 1–4:** `[TBD]`

### Act 4 — Earth: Return
*The reveal and the last stand.*

- While the player defended the Heavens, the enemy began **leaking back to
  Earth** — the plan they truly wanted all along.
- **Habitats it draws from:** the Earth habitats again, now **corrupted**, plus
  Underworld/Heaven creatures bleeding through tears in reality. *The familiar
  made monstrous.*
- **Pacing:** lean, urgent parts building to the **final boss fight**.
- **Final boss:** `[TBD]` — the architect of the cross-realm war; the presence
  Olorin first sensed in the grass.

---

## 5. The Bestiary

Enemies are not just obstacles — they are a **persistent record**. Each
character tracks the monsters they've defeated in story mode
(`CharacterData.defeated_monster_ids`), and certain enemies drop **relics** that
carry into the roguelike (`CharacterData.unlocked_relic_ids`, e.g. the Hydra →
Hydra Heart). Design every notable creature with two lives in mind: its role in
the **story** *and* its echo in the **roguelike** (bestiary entry, intent-reveal
gate, relic/card source).

### 5.1 How enemies work (so creatures are buildable, not just flavor)
Grounded in `scripts/battle/enemy.gd`:
- **Tempo actions:** an enemy commits to **one action per turn**; each action
  has a **tempo cost**, and it fires when the enemy's personal tempo counter
  reaches that cost. **Lower tempo cost = acts more often.** A creature's
  rhythm is its action list (e.g. Wererat: Move 2 / Bite 2 / Scurry 4).
- **Range-based AI roles:** behavior keys off distance to the player —
  *melee rusher*, *ranged kiter*, *support*, *evasive skirmisher*, *scaling
  threat*, etc.
- **Core stats:** health, **armor** (break to 0 → enemy is *exposed*), attack
  damage, attack range (grid cells), move distance, XP.
- **Tiers:** `Minion` (cheap, numerous) · `Elite` (a real threat) · `Boss`.
- **Status toolkit a creature can apply or synergize with** (implemented):
  **burn** (doubles each cycle), **poison**, **shock**, **cold** (5 → **frozen**),
  **slow**, **stun**, **disarm**, **mark**, **taunt**, **wear-down**,
  **armor-break/expose**.
- **Reusable mechanic patterns already in the game:** per-hit **scaling**
  (Hydra), **regeneration** (Armored Troll), **terrain hazards / fire walls**
  (Fire Goblin Shaman), **ally heal/buff support** (Shaman). Concepts to add:
  **summoning**, **pack tactics**, **charge lanes**, **on-death bursts**,
  **stealth/sound-only visibility**.
- **Drops:** elites/bosses can drop roguelike **relics + cards**. Every kill is
  recorded to the bestiary.

### 5.2 Creature design template
When we solidify a creature, capture it with these fields:
- **Name** · **Habitat(s)** · **Tier** (Minion / Elite / Boss) ·
- **Role** (melee rusher / armored tank / ranged kiter / evasive skirmisher /
  support / scaling / swarm / summoner / charger / ambusher) ·
- **Signature mechanic** (prefer existing status effects/patterns from 5.1) ·
- **Relic / card hook** (elites & bosses — what it feeds the roguelike) ·
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
- **Giant beaver**
- **Mini Bears** — *travel in packs*
- **Wolves** — *packs*
- **Coyote**
- **Bugbear**
- **Giant hawks**
- **Bears**
- **Treant**
- **Mage** — *a few different variants*
- **Druid**
- **Hydra** — *in code*

#### Graveyard
- **Skeleton** — *in code*
- **Zombie**
- **Zombie dog**
- **Werewolf**
- **Wererabbit**
- **Ghoul**
- **Wight**
- **Screeches** — *a soul-like creature that can only be seen from its noise*
- **Vampire**
- **Necromancer**
- **Bone dragon**
- **Grave digger**
- **The Consumed** — *a golem-like creature but far worse: something that has had its spirit consumed and is now flesh and hatred*
- **Spirit collector**
- **Grave titans**
- **Guilty Shifter**
- **Crypt Crawlers**

#### Cave
- **Bear**
- **Troll** — *in code as Armored Troll*
- **Yeti**
- **Goblin** — *in code as Fire Goblin variants (fire-themed)*
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

#### Sewer
- **Rats** — *in code as Wererat / Archer Rat*
- **Sludge being**
- **Pipe Crawlers**
- **Sewer Crocodiles**
- **Faithless cultist**
- **Rat King**
- **The drowned**
- **Slime**
- **Swarms** — *one creature, but a bunch of bugs representing one*

#### Mountains
- **Weregoat**
- **Wyvern**
- **Rocs**
- **Ice Troll**
- **Snow Wraiths**
- **Granite Colossi**
- **White Manticores**
- **Snow leopard**
- **Sabertooth tiger**

#### Underworld
- **Cerberus**
- **Succubus**
- **Demon**
- **Ifrits**
- **Mind eater**
- **Specters**
- **Echo Beasts**
- **Magma Spiders**
- **Pit Fiends**
- **Ash Harpies**
- **Inflamed Minotaur**

#### Heavens
- **Cherub**
- **Djinn**
- **Corrupted Archangel**

---

## 6. End-Game: The Roguelike

After the story ends, the game's primary long-tail loop is a **roguelike**, and
it is intended to be **multiplayer** (the game's design supports cooperative
play).

- **Scenario structure:** each battle is a **mini-zone of normal gameplay** —
  the player(s) start at one end of an area, walk around, and play cards, much
  like a single Gloomhaven scenario but lighter-weight per room.
- **Current room objective:** *"defeat all monsters."* The only room type so far.
- **Future idea (noted, not committed):** objective-based rooms (escort,
  survive, reach-the-exit).
- **What persists:** this is the *one* place run-based structure is allowed,
  because it is the **end-game** — not the spine of the game. The persistent
  character built through the story is what *enters* the roguelike; see
  `world_data.gd` for how a story playthrough seeds a shared pool of unlocks.

> Keep the `CLAUDE.md` guardrail in mind: roguelike mechanics belong **here**,
> in the end-game. They must not leak into the persistent story RPG.

---

## 7. The Persistent Character (Cast)

The player carries **one** character through the entire story and into the
roguelike. The current playable roster (`scripts/character/character_data.gd`):

| Character | Fantasy | Signature archetypes | Slot specialty |
|-----------|---------|----------------------|----------------|
| **Brad** | Tank / bruiser; pain is strength | Berserker, Warden, The Ancient, The Fallen | 8 weapon slots; chest items weigh less |
| **Ryan** | Dexterous duelist / rogue | Relentless Blade, Light Foot, Apothecary, Shadow Blade | 4 belt slots; belt cards cost 1 less mana |
| **Stephen** | Versatile killer / marksman | The Apex, Sentinel, Ranger, Avenger | 4 weapon + 3 ring slots; off-hand enchantments |
| **Cory** | Druid / monk / witherer | Monk, Lurker, Druid, Atrophist | 2 gauntlet slots; gauntlet-skill synergy |
| **Jeremy** | Elemental mage | Evocation (+ more) | 4 ring slots; first ring trigger fires twice |

> These are the *player's* avatars, distinct from Olorin (the guide). Whether
> any of them have story-specific arcs woven into the Acts is `[TBD]`.

---

## 8. Story ↔ Systems Map (what already exists in code)

To "build upon this," here is how the narrative connects to systems already in
the repo. Keep this table honest as the code changes.

| Story element | Where it lives today | Notes |
|---------------|----------------------|-------|
| **Olorin (guide / quest-giver)** | `scripts/menus/town.gd` (`_create_olorin_npc`, `vendor_info["Olorin"]`), `scripts/core/quest_manager.gd` | Already an in-town NPC: *"A wise old man with quests for brave adventurers."* First quest: **Rat Infestation** (clear 5 wererats from the sewers). Also crafts Origami Swans → Paper Feathers. |
| **Acts / planes** | `scripts/core/dungeon_manager.gd` → `WORLD_PALETTES` (1–5) | Themes are explicitly **placeholder** ("final per-world themes TBD"). Current names: Verdant Frontier, Amber Wastes, Frostreach, Emberfall, Umbral Expanse. The lore here is what those palettes should *become*. |
| **Habitats / biomes** | `dungeon_manager.gd` palettes + `CAVE_PALETTE`, `BUILDING_PALETTE`; site generation (caves, buildings) | The generator already distinguishes overworld vs. cave vs. building interiors — a natural hook for habitat-specific enemy spawn tables (Section 5). |
| **Roguelike unlock pool** | `scripts/roguelike/world_data.gd` (`WorldData`) | The end-game meta-container a story playthrough builds. A code-level concept, **not** a story Act. |
| **Bestiary** | `Enemy.EnemyType`, `CharacterData.defeated_monster_ids` | Per-character record of story kills; gates roguelike intent-reveals. 11 enemy types today (Section 5.3). |
| **Relics from monsters** | `CharacterData.unlocked_relic_ids`, `scripts/roguelike/relics.gd` | e.g. Hydra → Hydra Heart. The story↔roguelike bridge. |
| **Quests** | `scripts/core/quest_manager.gd` | Currently kill-quests only; Olorin is the sole giver. |
| **Town hub** | `scripts/menus/town.gd` | Persistent vendors (Blacksmith, Armory, Card Dealer, Accessory Shop, Stash) + Olorin + waypoint/transport. |

### Code naming follow-up `[TODO]`
The narrative uses **"Act"** exclusively, but the code still says `world_level`,
`WorldData`, and `WORLD_PALETTES`. Aligning the code to "Act" is a **separate,
larger refactor** (touches `dungeon_manager.gd`, `main.gd`, save serialization,
the roguelike, and tests). Tracked here; not done yet. There is also a **count
mismatch**: 4 Acts vs. 5 dungeon palettes — to be reconciled, ideally by
re-theming palettes toward **habitats** rather than acts.

---

## 9. Open Questions & Next Steps

Decided:
- ✅ **Terminology:** four **Acts** across one world; each Act is a plane.
- ✅ **Bestiary taxonomy:** catalogued by **habitat** (Forest, Graveyard, Cave,
  Sewer, Mountains, Underworld, Heavens), as flexible guidelines.

Still open:
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
