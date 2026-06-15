# STORY.md — Narrative & Worldbuilding Bible

This is the **canonical story document** for the game. It pairs with
[`CLAUDE.md`](../CLAUDE.md) (design direction): `CLAUDE.md` answers *"what kind
of game is this?"*, this file answers *"what story does it tell, and in what
world?"*

It is a **living document**. The lore here is the seed; we grow it together.
When a story decision is made, write it down here so every future session
builds on the same canon instead of re-inventing it. Sections marked
**`[TBD]`** are deliberate placeholders to be designed together — do **not**
quietly fill them with invented plot, names, or creatures without confirming.

> Reminder from `CLAUDE.md`: **this is a TRUE RPG, not a roguelike.** One
> persistent character, one journey through a story with a beginning, middle,
> and end. The roguelike is the *end-game loop* that unlocks after the story —
> not the spine of the game.

---

## 1. Premise & Tone

The world is **fraying**, and only one being can feel it happening.

The mood is high fantasy with a creeping undercurrent of *wrongness* — the
sense that the sickness afflicting the land comes from somewhere beyond it.
Think Tolkien's Middle-earth in its texture (Act I), descending into the
infernal (Act II), ascending into a corrupted holy realm (Act III), and
finally a desperate defense of home (Finale).

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
He is the lens through which the escalation across the three realms is felt.

> **Already in-game (do not duplicate):** Olorin exists today as a town NPC.
> See *Section 8 — Story ↔ Systems Map*.

---

## 3. Structure: Acts (Worlds), Chapters, and Pacing

The game is told across **three Acts** (referred to as "Worlds" in the original
pitch) plus a short **Finale**:

| # | Act / World | Realm | Theme |
|---|-------------|-------|-------|
| I | World 1 | **Civilization** | Classic high fantasy — the surface world |
| II | World 2 | **The Underworld** | Fire, darkness, sickness, demons |
| III | World 3 | **The Heavens** | A corrupted, infiltrated holy realm |
| — | Finale | **Return to Earth** | The true target — home, under siege |

**Chapter structure & pacing:**
- Each of the three Acts contains **4 chapters** (sub-worlds).
- Each chapter should be roughly **~1 hour** of play — quests, boss battles,
  and general travel/exploration combined.
- The **Finale** is a single short chapter: **~30 minutes** of gameplay leading
  into the **final boss fight**.

That's **12 main chapters + 1 finale chapter = 13 chapters total**.

> ⚠️ **Open terminology note.** The word *"World"* is overloaded in this
> project. In the story pitch, a "World" is an Act. In the code, `WorldData`
> (`scripts/roguelike/world_data.gd`) is the **roguelike end-game meta-
> container**, and `DungeonManager.world_level` (1–5) is a **per-region
> difficulty/palette tier**. See Section 8 for the proposed reconciliation —
> this is a decision to lock down before we build chapter content.

---

## 4. The Acts in Detail

### Act I — Civilization (World 1)
*Classic high fantasy. The surface world before the player understands the
scope of the threat.* Think Middle-earth / LOTR.

- **Environments:** town, sewers, cemetery, library, forests, and similar
  ordinary-civilization locales.
- **Bestiary direction:** orcs, goblins, trolls, wolves, boars, dragons, giant
  beavers — plus original creatures we invent together that don't exist
  elsewhere.
- **Tone:** familiar, grounded fantasy. The sickness is subtle here — felt by
  Olorin, not yet obvious to the world. This is where the mystery is seeded.

**Chapter slots (themes drawn from the named environments — `[TBD]` to finalize):**
1. `[TBD]` — likely the **Town & Sewers** (where Olorin's first quests live; cf. the existing "Rat Infestation" wererat quest).
2. `[TBD]` — likely **Cemetery / Library** (uncovering the first real clues).
3. `[TBD]` — likely **Forests / wilds**.
4. `[TBD]` — Act I climax / the threshold to the Underworld.

### Act II — The Underworld (World 2)
*The descent. The source of the rot, or so it seems.*

- **Theme:** fire, darkness, sickness.
- **Bestiary direction:** demons, soul creatures, ghouls, demon hounds,
  succubi, and related infernal enemies.
- **Tone:** oppressive and infernal. The player goes to the source — and
  discovers the corruption is not contained here. It is *spreading upward*.
- **Chapters 1–4:** `[TBD]`

### Act III — The Heavens (World 3)
*The ascent. The Underworld has infiltrated the Heavens; the player must climb
to stop the invasion.*

- **Theme:** what was once pure is now gloomy and sickened.
- **Bestiary direction:** angels, archangels, demons, djinn, **possessed
  angels**, and similar — holy beings turned or tainted.
- **Tone:** tragic corruption — beauty defiled. The twist: the heavenly
  invasion was never the real goal.
- **Chapters 1–4:** `[TBD]`

### Finale — Return to Earth
*The reveal and the last stand.*

- While the player was defending the Heavens, the enemy began **leaking back to
  Earth** — the plan they truly wanted all along.
- **Length:** ~30 minutes — a single chapter leading into the **final boss
  fight**.
- **Final boss:** `[TBD]`

---

## 5. The Bestiary (Story → End-Game Hook)

Enemies are not just obstacles — they are a **persistent record**. Each
character tracks the monsters they've defeated in story mode
(`CharacterData.defeated_monster_ids`), and certain enemies drop **relics** that
carry into the roguelike (`CharacterData.unlocked_relic_ids`). For example, the
Hydra already drops the Hydra Heart relic.

Design implication: every notable creature we add for an Act should be designed
with two lives in mind — its role in the **story** *and* its echo in the
**roguelike** (as a bestiary entry, an intent-reveal gate, and/or a relic
source).

**Per-Act creature lists** live in Section 4. Invented creatures get their own
named entries here as we create them: `[TBD — creature compendium]`.

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
  survive, reach-the-exit). These should be straightforward to add later when
  the time comes.
- **What persists:** this is the *one* place run-based structure is allowed,
  because it is the **end-game** — not the spine of the game. The persistent
  character built through the story is what *enters* the roguelike; see
  `world_data.gd` for how a story playthrough seeds a shared "world" of unlocks.

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
| **Acts / Worlds** | `scripts/core/dungeon_manager.gd` → `WORLD_PALETTES` (1–5) | Themes are explicitly **placeholder** ("final per-world themes TBD"). Current names: Verdant Frontier, Amber Wastes, Frostreach, Emberfall, Umbral Expanse. The lore in this doc is what those palettes should *become*. |
| **Roguelike "world"** | `scripts/roguelike/world_data.gd` (`WorldData`) | The end-game meta-container a story playthrough builds. **Not** the same as a story "World/Act" — see the terminology note below. |
| **Bestiary** | `CharacterData.defeated_monster_ids` | Per-character record of story kills; gates roguelike intent-reveals. |
| **Relics from monsters** | `CharacterData.unlocked_relic_ids`, `scripts/roguelike/relics.gd` | e.g. Hydra → Hydra Heart. The story↔roguelike bridge. |
| **Quests** | `scripts/core/quest_manager.gd` | Currently kill-quests only; Olorin is the sole giver. Room to grow per chapter. |
| **Town hub** | `scripts/menus/town.gd` | Persistent vendors (Blacksmith, Armory, Card Dealer, Accessory Shop, Stash) + Olorin + waypoint/transport. Per `CLAUDE.md`, the town persists across the whole game. |

### Proposed terminology reconciliation `[decision needed]`
Because "World" means two different things, I recommend we settle on:
- **"Act"** for the three story chapters-of-chapters (Act I/II/III + Finale), and
- reserve **"World"** for the existing roguelike `WorldData` meta-container.

The `DungeonManager.world_level` palettes (1–5) then become the **Act themes**.
There's a count mismatch to resolve: the story has **3 Acts + 1 Finale realm**
(4 distinct realms), but there are **5 palettes**. Options:
1. Map palettes → realms as **Act I, Act II, Act III, Finale**, and drop/repurpose the 5th palette.
2. Keep 5 tiers and split one Act across two visual tiers (e.g. Act I town vs. wilds).

This is a real design call — flagged here rather than guessed.

---

## 9. Open Questions & Next Steps

Things to decide together before/while building chapter content:

1. **Terminology**: lock down "Act" vs "World" (Section 8) and rename in code/docs consistently.
2. **Realm ↔ palette mapping**: how the 4 story realms map onto the 5 `WORLD_PALETTES`.
3. **Chapter beats**: flesh out the 12 `[TBD]` chapter slots (Section 4) — one-line premise + boss + key environment each.
4. **Invented creatures**: start the creature compendium (Section 5) for the original monsters unique to this world.
5. **Final boss & the "true target" reveal**: define the antagonist behind the cross-realm war (Section 4, Finale).
6. **Character arcs**: decide whether Brad/Ryan/Stephen/Cory/Jeremy have story roles or are pure player avatars (Section 7).
7. **Olorin's expanded quest line**: grow Olorin from one wererat quest into a per-chapter guiding thread.

When any of these is answered, **update this file** so the canon stays in one
place.
