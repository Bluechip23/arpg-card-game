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
He is the lens through which the escalation across the planes is felt.

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
- **Act 4** is the most **compressed and climactic** of the four: its parts move
  fast and build directly to the **final boss fight** (per the original pitch,
  the return to Earth is short and urgent). It still has 4 parts, but they are
  lean.

That's **4 Acts × 4 parts = 16 parts**, ending in the final confrontation.

> **Terminology is settled:** we say **"Act"** (Act 1–4), never "World," for
> story structure. There is only one world. (Code still uses `world_level` /
> `WorldData` internally — see Section 8 for the rename follow-up.)

---

## 4. The Four Acts in Detail

### Act 1 — Earth: Civilization
*Classic high fantasy. The surface world before the player understands the scope
of the threat.* Think Middle-earth / LOTR.

- **Environments:** town, sewers, cemetery, library, forests, and similar
  ordinary-civilization locales.
- **Bestiary direction:** orcs, goblins, trolls, wolves, boars, dragons, giant
  beavers — plus original creatures we invent together (see Section 5).
- **Tone:** familiar, grounded fantasy. The sickness is subtle here — felt by
  Olorin, not yet obvious to the world. This is where the mystery is seeded.

**Part slots (`[TBD]` to finalize — themes drawn from the named environments):**
1. `[TBD]` — likely **Town & Sewers** (Olorin's first quests; cf. the existing "Rat Infestation" wererat quest).
2. `[TBD]` — likely **Cemetery / Library** (the first real clues).
3. `[TBD]` — likely **Forests / wilds**.
4. `[TBD]` — Act 1 climax / the threshold downward to Hell.

### Act 2 — Hell: The Underworld
*The descent. The apparent source of the rot.*

- **Theme:** fire, darkness, sickness.
- **Bestiary direction:** demons, soul creatures, ghouls, demon hounds, succubi
  (see Section 5).
- **Tone:** oppressive and infernal. The player goes to the source — and
  discovers the corruption is not contained here. It is *spreading upward*.
- **Parts 1–4:** `[TBD]`

### Act 3 — Heaven (Corrupted)
*The ascent. The Underworld has infiltrated the Heavens; the player must climb
to stop the invasion.*

- **Theme:** what was once pure is now gloomy and sickened.
- **Bestiary direction:** angels, archangels, demons, djinn, **possessed
  angels** (see Section 5) — holy beings turned or tainted.
- **Tone:** tragic corruption — beauty defiled. The twist: the heavenly
  invasion was never the real goal.
- **Parts 1–4:** `[TBD]`

### Act 4 — Earth: Return
*The reveal and the last stand.*

- While the player was defending the Heavens, the enemy began **leaking back to
  Earth** — the plan they truly wanted all along.
- **Design hook:** the *familiar made monstrous* — corrupted versions of Act 1
  fauna fighting alongside infernal/heavenly invaders bleeding through tears in
  reality.
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
  rhythm is defined by its action list (e.g. Wererat: Move 2 / Bite 2 / Scurry 4).
- **Range-based AI roles:** behavior keys off distance to the player —
  *melee rusher* (close + hit), *ranged kiter* (maintain distance, flee if too
  close), *support* (buff/heal allies, lay hazards), *evasive skirmisher* (dash
  away), *scaling threat* (grows over the fight).
- **Core stats:** health, **armor** (must be broken to 0 → enemy becomes
  *exposed*), attack damage, attack range (in grid cells), move distance, XP.
- **Tiers:** `Minion` (cheap, numerous) · `Elite` (a real threat) · `Boss`.
- **Status toolkit a creature can apply or synergize with** (already
  implemented): **burn** (doubles each cycle), **poison**, **shock**, **cold**
  (5 stacks → **frozen**), **slow**, **stun**, **disarm**, **mark**, **taunt**,
  **wear-down**, **armor-break/expose**.
- **Special mechanics already in the game** (reusable patterns): per-hit
  **scaling** (Hydra), **regeneration** (Armored Troll), **terrain hazards /
  fire walls** (Fire Goblin Shaman), **ally heal/buff support** (Shaman). Not
  yet present but reusable concepts: **summoning**, **pack tactics**, **charge
  lanes**, **on-death bursts**.
- **Drops:** elites/bosses can drop roguelike **relics + cards** (the story →
  roguelike bridge). Every kill is recorded to the bestiary.

### 5.2 Creature design template
When we lock a creature, capture it with these fields:
- **Name** ·
- **Act / Plane** ·
- **Tier** (Minion / Elite / Boss) ·
- **Role** (melee rusher / armored tank / ranged kiter / evasive skirmisher /
  support / scaling / swarm / summoner / charger) ·
- **Signature mechanic** (prefer existing status effects/patterns from 5.1) ·
- **Relic / card hook** (elites & bosses — what it feeds the roguelike) ·
- **Origin:** `existing` | `[DRAFT]` proposed | `[DRAFT]` invented-original.

### 5.3 Existing roster (in code today — these are canon)
From `Enemy.EnemyType`:

| Enemy | Act | Tier | Role / signature |
|-------|-----|------|------------------|
| **Wererat** | 1 | Minion | Fast, evasive — bites up close, scurries away when cornered |
| **Archer Rat** | 1 | Minion | Ranged kiter — shoots at range 3–4, flees if you close to ≤2 |
| **Skeleton** | 1 | Minion | Armored — must break its armor before it's exposed |
| **Armored Troll** | 1 | Elite | Regenerates 2 HP / 6 tempo; Smash (AOE) / Kick |
| **Hydra** | 1 | Elite | **Scaling** — +2 strength per hit taken; after the 4th hit gains bulk + a full Heal. **Drops Hydra Heart relic + a card** |
| **Fire Goblin Soldier** | 2 | Minion | Melee rusher (fast Move 2 / Attack 3) |
| **Fire Goblin Mage** | 2 | Minion | Ranged caster — Ember: 6 dmg + **burn** |
| **Fire Goblin Shaman** | 2 | Elite | Support — raises **fire walls** (terrain hazard), heals/sacrifices allies |
| **Minion / Elite / Boss** | — | — | Generic fallbacks used for difficulty scaling |

### 5.4 Per-Act draft rosters `[DRAFT — for discussion]`
Proposals to hash out. Existing creatures are the anchors; new ones build on the
same mechanical patterns. **Nothing here is locked** — names, roles, and
mechanics are all open for your edits.

**Act 1 — Earth / Civilization** (anchors: Wererat, Archer Rat, Skeleton, Armored Troll, Hydra)
- `[DRAFT]` **Goblin Skirmisher** — Minion, swarm melee. Cheap, comes in packs.
- `[DRAFT]` **Goblin Cutpurse** — Minion, evasive. On hit, steals tempo/mana, then scurries (disarm-flavored).
- `[DRAFT]` **Orc Grunt** — Minion, melee bruiser. Sturdy frontline.
- `[DRAFT]` **Orc Berserker** — Elite. Enrages below 50% HP: gains strength and acts faster (lower tempo).
- `[DRAFT]` **Dire Wolf** — Minion, pack. Pack tactics: bonus damage while adjacent to another wolf; fast mover.
- `[DRAFT]` **Tusker Boar** — Elite, charger. Telegraphed line-charge with knockback; punishes standing in its lane.
- `[DRAFT, invented]` **Gnawmaw, the Giant Beaver** — Elite. Builds wood-dam **barricades** (terrain like fire walls but blocking); gnaws armor (reduces player block on hit).
- `[DRAFT, boss]` **Elder Dragon** — Act 1 finale. Flight reposition + cone fire-**breath** (burn) + tail-sweep AOE. **Relic drop.**

**Act 2 — Hell / The Underworld** (anchors: Fire Goblin Soldier/Mage/Shaman)
- `[DRAFT]` **Ghoul** — Minion. Bite applies **poison** (sickness); rises once after death unless killed while exposed.
- `[DRAFT]` **Hellhound** — Minion, pack/fast. Leaves a burning trail tile (hazard) as it moves; leaps to close distance.
- `[DRAFT]` **Wailing Soul** — Minion, evasive caster. Drains mana / applies **shock** at range; phases (hard to corner).
- `[DRAFT]` **Imp Swarm** — Swarm minion. Many fragile bodies that stack **burn**.
- `[DRAFT]` **Cinderbrute** — Elite, tank. Heavy armor; fire-thorns (retaliates **burn** when meleed).
- `[DRAFT]` **Succubus** — Elite, controller. Charm (control debuff / forced miss), HP drain (lifesteal), pulls the player out of position.
- `[DRAFT, invented]` **Plaguebearer** — Elite. The embodiment of Olorin's "sickness": spreads **poison/shock** to an area each cycle; corrupts the ground.
- `[DRAFT, boss]` **Lord of the Underworld** — Act 2 finale; **relic drop**. The player believes this is the source — but the rot leads *upward*.

**Act 3 — Heaven (Corrupted)** (no anchors yet — new act)
- `[DRAFT]` **Possessed Cherub** — Minion. Once holy, now erratic; radiant smite (single-target burst).
- `[DRAFT]` **Radiant Sentinel** — Ranged minion. Long-range smite; applies **mark**.
- `[DRAFT]` **Choir Warden** — Elite, support. Shields (armor) and heals other angels — a "holy Shaman."
- `[DRAFT]` **Djinn** — Elite, evasive caster. **Blinks** (teleport); twists fate (applies a random debuff); gust pushes the player.
- `[DRAFT]` **Demon Vanguard** — Minion/Elite. Underworld invaders *inside* Heaven (echoes Act 2 kits; shows the infiltration).
- `[DRAFT, invented]` **Halo-Wretch** — Elite. A hollowed fallen angel; on death releases an AOE burst of corruption.
- `[DRAFT, boss]` **Corrupted Archangel** — Act 3 finale. Multi-phase (radiant → possessed); **relic drop**.

**Act 4 — Earth / Return** (compressed, climactic — the familiar made monstrous)
- `[DRAFT]` **Blighted fauna** — corrupted Act 1 creatures (e.g. Blighted Dire Wolf, Sickened Boar) now carrying Act 2 status (**poison + burn**).
- `[DRAFT]` **The Hollowed** — Minion. Possessed townsfolk; weak but numerous; tragic.
- `[DRAFT]` **Riftspawn** — Minion/Elite. Demon-angel hybrids pouring through tears in reality (mix of Act 2 + Act 3 kits).
- `[DRAFT]` **Herald of the End** — Elite mini-boss gating each of the 4 parts.
- `[DRAFT, boss]` **Final Boss** `[TBD]` — the architect of the cross-realm war, the presence Olorin first sensed. Multi-phase climax.

---

## 6. End-Game: The Roguelike

After the story ends, the game's primary long-tail loop is a **roguelike**, and
it is intended to be **multiplayer** (the game's design supports cooperative
play).

- **Scenario structure:** each battle is a **mini-zone of normal gameplay** —
  the player(s) start at one end of an area, walk around, and play cards, much
  like a single Gloomhaven scenario but lighter-weight per room.
- **Current room objective:** *"defeat all monsters."* That is the only room
  type for now.
- **Future idea (noted, not committed):** objective-based rooms (e.g. escort,
  survive, reach-the-exit). These should be straightforward to add later.
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
| **Acts / planes** | `scripts/core/dungeon_manager.gd` → `WORLD_PALETTES` (1–5) | Themes are explicitly **placeholder** ("final per-world themes TBD"). Current names: Verdant Frontier, Amber Wastes, Frostreach, Emberfall, Umbral Expanse. The lore here is what those palettes should *become* — mapped to the 4 Acts. |
| **Roguelike unlock pool** | `scripts/roguelike/world_data.gd` (`WorldData`) | The end-game meta-container a story playthrough builds. A code-level concept, **not** a story Act. |
| **Bestiary** | `Enemy.EnemyType`, `CharacterData.defeated_monster_ids` | Per-character record of story kills; gates roguelike intent-reveals. 11 enemy types today (Section 5.3). |
| **Relics from monsters** | `CharacterData.unlocked_relic_ids`, `scripts/roguelike/relics.gd` | e.g. Hydra → Hydra Heart. The story↔roguelike bridge. |
| **Quests** | `scripts/core/quest_manager.gd` | Currently kill-quests only; Olorin is the sole giver. Room to grow per part. |
| **Town hub** | `scripts/menus/town.gd` | Persistent vendors (Blacksmith, Armory, Card Dealer, Accessory Shop, Stash) + Olorin + waypoint/transport. The town persists across the whole game. |

### Code naming follow-up `[TODO]`
The narrative now uses **"Act"** exclusively, but the code still says
`world_level`, `WorldData`, and `WORLD_PALETTES`. Aligning the code to "Act" is
a **separate, larger refactor** (it touches `dungeon_manager.gd`, `main.gd`,
save serialization, the roguelike, and tests). Tracked here; not done yet to
avoid bundling a risky rename into story work. There is also a **count
mismatch** to resolve: 4 Acts but 5 dungeon palettes — map 4-to-4 and
drop/repurpose the 5th, or split an Act across two visual tiers.

---

## 9. Open Questions & Next Steps

Decided:
- ✅ **Terminology:** four **Acts** across one world; each Act is a plane
  (Earth / Hell / Heaven / Earth-return); 4 parts per Act.

Still open:
1. **Bestiary lock-in:** turn the `[DRAFT]` rosters (Section 5.4) into canon —
   confirm/cut/rename creatures, then write full stat blocks (Section 5.2 template).
2. **Code rename + palette mapping:** `world_*` → `act_*`, and how 4 Acts map to
   the 5 dungeon palettes (Section 8 TODO).
3. **Part beats:** flesh out the 16 `[TBD]` part slots (Section 4) — one-line
   premise + boss + key environment each.
4. **Final boss & the "true target" reveal:** define the antagonist behind the
   cross-realm war (Act 4).
5. **Character arcs:** do Brad/Ryan/Stephen/Cory/Jeremy have story roles, or are
   they pure player avatars (Section 7)?
6. **Olorin's expanded quest line:** grow Olorin from one wererat quest into a
   per-part guiding thread.

When any of these is answered, **update this file** so the canon stays in one
place.
