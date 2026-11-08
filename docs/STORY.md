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
- **Part slots:** 1) **Town & Sewers** — *the Sewers are built* (the opening dungeon; Olorin's first quests; Rat King mini-boss). See Section 5.4. · 2) Cemetery / Library (first clues) `[TBD]` · 3) **Forests / wilds** — *the Greenwood forest, the Caves and the Mountain Pass are built* (climbable trees, hunters' traps, woodland beasts; dark dripping cave tunnels). See Section 5.4. · 4) Act 1 climax / **threshold downward — Hell's Gate is built** (Cerberus guarding Hell's Door at the bottom of the first world's deepest cave; through the broken door lies the next world) — the climax around it `[TBD]`.

### Act 2 — Hell: The Underworld
*The descent. The apparent source of the rot.*

- **Theme:** fire, darkness, sickness.
- **Habitats it draws from:** Underworld (primarily); Cave bleed-over.
- **Tone:** oppressive and infernal. The player reaches the "source" — and
  learns the corruption is spreading *upward*, not contained here.
- **Built (2026-11-05): World 2 is the Underworld.** Hell's Gate's broken door leads down to it. Its surface wears the hell art first painted for World 4 (cursed earth, molten pools no one wades, volcanoes, demon idols and vein-wrapped ruins on its skyline; `DungeonManager.art_world`; World 4 — Act 4's corrupted Earth — took the Amber Wastes' desert in exchange), and is the demons' ground: succubi, magma spiders, mind eaters and specters, demons, ash harpies overhead and ifrits; its arena an ifrit with two demons; its deep rooms the lords of the deep (the Ferryman's Toll). Its caves are **Burning Caves** — lava for puddles, lit orange — with the same host, a Fire Goblin Shaman each (the Channel lesson) and the door to the Labyrinth.
- **Thanatos Closet is built** (2026-11-05; `interior_kind == "closet"`, its way down in the Underworld's far reaches): crypt warrens under the burning ground in the **undead land art** (barrow earth and rock, green bog, headstones, ruined pillars and skull doors along the walls, bones and skulls underfoot), where specters drift and mind eaters and demons lurk. Its deepest crypt opens on **Thanatos's Hall** (`thanatoshall`, a boss room sealed until he falls): two rows of pillars and Death on his dais. **Thanatos** — *in code, first pass*: Boss (400 HP, 40 armor; resists 25% physical / fire / lightning); **Reap** (5 tempo, 25 + 6 Bleed beside him), **Death Bolt** (6 tempo, 15 at up to 6 squares + Hexes a card), **Raise the Dead** (10 tempo, a skeleton or zombie, two at most; each servant that falls rises as a Skeleton and costs him 10), Move. His figure is the designer's board (2026-11-05): a black-winged reaper in dark violet plate, red-eyed, scythe in hand, black smoke curling round him. `[TBD]`: his story beats, his final kit.
- **Part slots:** 1) **The Labyrinth is built** — the Inflamed Minotaur's maze through a door at the east end of the Underworld's deepest cave (see Section 5.4, Underworld); the arrival and the parts around it `[TBD]` · 2–4) `[TBD]`

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
- **All three planes collide here:** the **normal plane, Hell, and Heaven now
  all exist on Earth at once.** The world itself becomes the battlefield, and
  this is the **final battle for the world** — its fate decided here.
- **Habitats it draws from:** the Earth habitats again, now **corrupted**, plus
  Underworld *and* Heaven creatures present together through tears in reality.
  *The familiar made monstrous.*
- **Pacing:** lean, urgent parts building to the **final boss fight**.
- **Final boss:** `[TBD]` — the architect of the cross-realm war; the presence
  Olorin first sensed in the grass.

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
- **Giant Beaver** — *in code*. Elite. Chomp (4 tempo, 9 dmg, **Stun** 3 tempo) queues a **Tail Whip** follow-up (2 tempo later, 6 dmg, **Vulnerable** 15 tempo). Sits upright when still, scurries on all fours.
- **Mini Bear** — *in code*. Minion, *packs*. When a packmate in sight is hurt, the others gain **+1 attack damage**.
- **Wolf** — *in code*. Minion, *packs*. Within 4 tiles of another wolf: **+2 attack damage and +2 HP regen/cycle**.
- **Coyote** — *in code*. Minion. Fragile (5 HP) 1-damage nuisance.
- **Bugbear** — *in code*. Minion. **First Strike**: +5 damage if it hits before the player hits it.
- **Giant Hawk** — *in code*. Minion. Flying — **ignores the player's high-ground bonus**; 15% to **Blind** on hit (attacks may miss).
- **Large Bear** — *in code*. Elite. **Maul applies Bleed**; **Roar** leaves everything within 4 squares Vulnerable. Below 50% HP it **toughens** (30% physical resist, permanent) and **rages** — 1.5x attacks, double Bleed, and it heals from bleed damage its enemies take. With Mini Bears present it gains **Strengthen** every time it is hurt. Drops to all fours below 20% HP.
- **Infected Hunter** — *in code*. Elite. **Hook** (range 7, starts charged) reels the player in over 2 tempo; AOE **Cleave**.
- **Treant** — *in code*. Elite. Heals 5 HP/5 tempo (**+2 per 10% HP below 60%**); every 10 tempo it **strips its enemies' thorns and heals for the total**; **Root** pins the player 8 tempo (can attack, cannot move); deals **Earth** damage. Takes 10% extra fire damage.
- **Elemental Mages** — *in code*. The five caster variants deal **typed damage**: Ice (→ **Slow**), Fire (→ **Burn**), Spark/Lightning (→ **Shock**), Air/Wind, Earth (**gains 3 armor every time it is hit**). **Totems** (designer, 2026-11-06, "at least for right now"; *in code*): each mage **raises its element's totem** beside it (Raise Totem, 6 tempo; one standing at a time, another 30 tempo after it is broken), a 24-HP structure in the designer's art that **crumbles when its mage falls**. **Air Totem** (a winged pillar under a whirlwind): the mage's foes' movement drops by 4 − N, N their squares from the vortex — a tile is 1 tempo, so each tile moved within 3 squares costs 3 / 2 / 1 extra tempo (`Main.vortex_drag`; paid like climbing, flash or not; the strongest totem counts). **Earth Totem** (a titan carved from a crag, bound in rose vines): heals the mage's allies (first pass: 4 health every 5 tempo, within 3 squares); has **thorns** (first pass: 5 back at every direct hit). **Fire Totem** (a lava-veined spire): 3 Burn to every foe within 3 squares every 5 tempo. **Ice Totem** (an ice obelisk coiled by an ice dragon holding a frozen pocket watch): **explodes when it dies** for 1 damage + 1 a tempo it stood, up to 10 — a 10-tempo timer: at 10 it goes off by itself (first pass: on every foe within 3 squares). **Shock Totem** (the Spark Mage's, an iron-banded storm mast): every 5 tempo it hits the nearest foe (first pass: 4 lightning) and gives 1 Shock to every foe within 4 squares. Set numbers scale with the hero's level like every enemy's. `[TBD]`: the first-pass numbers.
- **Druid** — `[TBD]`.
- **Hydra** — *in code*.

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

#### Graveyard
- **Skeleton** — *in code*
- **Zombie**
- **Zombie dog**
- **Werewolf** — *in code*. Elite. Armor-piercing **Claw** (+3 vs armor) rakes a debuffed target a second time for half; consecutive claws on the same target arm **1 tempo faster** each time (reset on switching targets).
- **Treasure Bunny** (named the Wererabbit until 2026-10-26)
- **Ghoul**
- **Wight**
- **Screeches** — *a soul-like creature that can only be seen from its noise*
- **Vampire** — *in code*. Elite. Bite **life-steals 100% of health damage** (armor heals nothing); below 50% HP, **Bat Form** flits 6 squares away (2 charges, never recharge), always followed by **Absorb** — draining the healthiest player-side unit on the map (20, then 10).
- **Necromancer** — *in code*. Elite. **Bolt** (range 10) also **Hexes 2 cards** in the hand (each +30 mana until played); **Summon** raises undead (first-pass roster: skeletons/zombies). **Raise the Fallen:** every summon of his that dies **rises again as a Skeleton and costs him 10 health**; any other ally that dies **within 8 squares** of him rises as a Skeleton too. A risen Skeleton rises no further and costs him nothing.
- **Bone Dragon** — *in code*. Elite (150 HP, resists 45% physical / 45% fire; Bite 12, Breath Swarm down a 6-tile line). Fought as the **second boss** in the **Boneyard** (`interior_kind == "boneyard"`, through a door at the east end of the Old Graveyard's deepest crypt): a large walled square gated on the west, with twelve **gravestones** (10 HP) in rows across it. The fight is meant to open with the **Necromancer** — the player's job is to stop him raising the dead, and what he leaves behind is those twelve stones (*the Necromancer part is not yet specified; the room is built in its post-prelude state*). Then the dragon: for every gravestone still standing he has **1 regen that never decays** (1 health a cycle per stone — shown as *Gravebound*); the only way to lower it is to break the stones. The catch: **grave diggers** (20 HP, three in all, only one out at a time) come out of the crypt door and repair a broken stone back to full in **8 tempo**, then vanish. Kill the stones, kill the diggers, and the dragon is beatable.
- **Bone dragon** — *in code*. Elite. **Breath Swarm**: 12 damage down a 6-tile line, hatching a **Swarm** beside every unit hit.
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
> whose objective is a door, not the boss) — see the bestiary entries. Like everything in the
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
**The Mountain Pass is built** (2026-11-05; `interior_kind == "mountains"`, reached from World 1's overworld by the Mountain Pass site): a snowy mountainside climbing up the screen in four terraces (valley floor, two terraces, the summit), with raised outcrops on the lower ones. **Elevation is walked one level a step** (`DungeonManager.can_step`): neighbouring terraces are a cliff apart, and no one walks up or down a cliff — a south-facing drop is a rock face (`cliff_face_tiles`), the rest the ledge's lip. The way up is a **step** halfway up a cliff (`step_tiles`, the trodden track); every ledge can be reached on foot. Fliers (`immune_to_high_ground`) cross cliffs; so would a climber (`PlayerStats.climbs_cliffs`, for climbing gear — none in the game yet); a blink, leap or knockback is not walking. Weregoats and sabertooths roam the low snowfields; snow wraiths and ice trolls hold the ledges and outcrops; wyverns, white manticores and rocs ride the heights; the summit holds an ice troll and a flier. A chest waits on each outcrop and the summit. Art: Frostreach's winter pack ground, rock and props (no pack draws stairs: the steps are the slush track). Granite Colossi stay out until they have moves.
**Its caves** (2026-11-05): two cave mouths open out of the Pass's cliffs. The **Ice Cave** (`interior_kind == "icecave"`, on a lower terrace) is the cave layout frozen — snow floor, frosted rock, ice crystals for stalagmites — with the mountain's creatures and an ice troll in its deepest chamber; **Frostreach's (World 3's) caves are Ice Caves too.** The **Ice Troll Lair** (`interior_kind == "trolllair"`, high up near the summit) is a treasure pocket meant to kill the unready: a tunnel opens on the trolls' den, one frozen room where **five ice trolls** (two at the vault's gap) and four snow wraiths wake together; in the den's corner the **vault**, walled by **high mountains** (no walking on them, no blinking across them — `blink_clear`; a later quest might have Olorin send the hero for mountain boots) with a **single one-tile way in**, holds a **legendary chest** (the one chest allowed a legendary) and **gold lying about the floor** — walked onto, it is taken, and stays taken (`DungeonManager.gold_piles`, the treasure pack's gold). No fountain in the lair.
- **Weregoat**
- **Wyvern** — *in code*. Elite. Flier (ignores high ground). **Talon Grab** (2-cycle cooldown): flies above its target, 25 damage, and drags them to an open space **8 squares away**.
- **Rocs**
- **Ice Troll** — *in code*. Elite. Every attack adds a stack of **frost (Cold) and Brittle**; when an attack **freezes** its target, **Clobber (50)** triggers automatically; he can also wind Clobber up as a 10-tempo blow of its own (designer, 2026-11-08).
- **Snow Wraiths**
- **Granite Colossi**
- **White Manticores** — *in code*. Elite. Flier. **Stinger** (5-tempo cooldown): 25 damage + **Clumsy** + **8 Poison**.
- **Snow leopard**
- **Sabertooth tiger**

#### Underworld
- **Cerberus** — *in code*. Boss (sheet: 250 HP, 50 armor, 25 bites, 6 spaces a move; resists 30% physical / 40% fire / 15% lightning). **Guards Hell's Door** in the **third boss room, Hell's Gate** (`interior_kind == "hellgate"`, through a door at the east end of the first world's deepest cave): one long cavern hall with lava in its corners, the iron door (the cave pack's gate, 150 HP) set in the east wall and the hound before it. **The objective is the door, not the hound**: break it and the way down opens (and the way back) — killing Cerberus is optional, just far easier to work around a corpse. At **75%, 50% and 33%** health the door **seals itself against all damage for 10 tempo**; and the door **counts as Cerberus's ally**, so its drop below half feeds his Guardian of Death. His kit, from the sheet: **Bite** (5 tempo, 25) — below 66% health the **second head** bites too (25 + 5 Bleed), below 33% the **third** as well (25, life-stolen); **Swipe** (8 tempo): 8 Bleed; **Venom Tail** (15 tempo): the victim discards 3 random cards and is stunned 15 tempo, and when that lifts gains 2 Vulnerable and 10 tempo of Cuffed; **Roar** (12 tempo): +25 armor and 25 thorns. Passives: **Guardian of Death** — the first time *he* drops below 50% he gains Brace 30% for 5 incoming hits, and *every* time any other unit within 8 squares drops below 50% (foe or ally; heal back over half and drop again and it counts again) he gains it again; **Deathyard Dog** — whenever a foe heals within 5 squares, +15 Strengthen. Otherwise straightforward, and very hard.
- **Thanatos** — *in code (first pass)*. Boss of Thanatos Closet; see Act 2 above.
- **Succubus**
- **Demon**
- **Ifrits** — *in code*. Elite. **Fire Breath**: a 5x5 sheet of flame, and he keeps breathing it for 6 more tempo (a Channel, designer 2026-11-08) — the tiles burn all the while and 3 tempo after; **Backflip** springs it 3 squares back from any single blow over 40 damage.
- **Mind eater**
- **Specters**
- **Echo Beasts**
- **Magma Spiders**
- **Pit Fiends**
- **Ash Harpies**
- **Inflamed Minotaur** — *in code*. **Boss** (sheet: level 9, 350 HP, 100 armor, 35 + 2 Burn a hit, 6 spaces a move; resists 15% physical / 50% fire / 25% lightning). Fought in **the fourth boss room, the Labyrinth** (`interior_kind == "labyrinth"`, through a door at the east end of the second world's deepest cave): a square maze of two-wide passages in the cave pack's rock around an open court with lava in its corners, the bull waiting in the court; sealed until he is dead, and his death opens the way out. Leaves **fire in its wake** (Traps — see 5.1; along every charge too) and heals 10 when the fire burns a player. Once he has taken **over 20 damage since his last leap** (a running total across hits, not a single blow) he makes a **Labyrinth Leap** (14 spaces to a random open tile, **minus 1 per Slow stack — Slow is his weakness**, Sword of Theseus applies it; minotaur-specific, not a universal slow rule), then **Bull Rush** a random **5 to 15 tempo** later — damage equal to the spaces covered by leap and rush together, spaces×4% chance to stun **and Weaken** the final target, Vulnerable to the target and everything trampled en route (a player is always preferred over summons). He walks the maze by the real route round its walls. **The room's curse — Lost in the Labyrinth:** every **25 tempo** the player is Lost for **15**: the hand is reshuffled into a random order and **must be played left to right** (the hand shows one card per slot, in order, and only the first in line can be played), and **nothing can be drawn** by any means (Debuff `LOST`). It lifts the moment the Minotaur dies.

#### Heavens
- **Cherub**
- **Djinn** — *in code*. Elite. **Chain Lightning** (35 per unit; cast range 5, bounds arc 4). Every attack against it puts **3 Wishes** in the attacker's hand — each sears the holder for 1/3 of that attack's damage per cycle held, and costs **60 mana (0 tempo)** to be rid of.
- **Corrupted Archangel**

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
| **Acts / planes** | `scripts/core/dungeon_manager.gd` → `WORLD_PALETTES` (1–5), `art_world()` (World 2 wears the hell palette, "The Underworld"; World 4 the Amber Wastes) | Themes are explicitly **placeholder** ("final per-world themes TBD"). Current names: Verdant Frontier, Amber Wastes, Frostreach, Emberfall, Umbral Expanse. The lore here is what those palettes should *become*. |
| **Habitats / biomes** | `dungeon_manager.gd` palettes + `CAVE_PALETTE`, `BUILDING_PALETTE`, `SEWER_PALETTE`; site generation (caves, buildings, sewers) | The generator distinguishes overworld vs. cave vs. building vs. **sewer** interiors — a natural hook for habitat-specific enemy spawn tables (Section 5). |
| **The Sewers (Act 1, Part 1)** | `dungeon_manager.gd` (`interior_kind == "sewer"`: `_generate_sewer_layout`, `_build_sewer_decorations`, `_define_sewer_spawn_zones`), `main.gd` (`_apply_world_ambience` sewer branch + `_ensure_player_torch`), `torch_flicker.gd`, `sewer_critter.gd` | **Built.** The opening dungeon: trunk + water channels, Rat King arena, west→east rat/ooze → boss → croc/swarm/crawler progression, dim torchlit atmosphere, reduced fog. Reached via a sewer grate site in World 1. See Section 5.4. |
| **The Greenwood (Act 1, Forest)** | `dungeon_manager.gd` (`interior_kind == "forest"`: `_generate_forest_layout`, `_place_forest_features`, `_build_forest_decorations`, `_define_forest_spawn_zones`), `main.gd` (forest ambience, terrain-trap + tree-climb systems, tutorial), `sewer_critter.gd` (squirrels) | **Built.** Open clearings/trails/hills; climbable trees → high ground (+ one-time tutorial); bear traps (7 dmg / 10 to bears) and hunter dart tripwires (5 dmg) that hit players *and* enemies; pits; squirrels; bright fog. Reached via a forest trailhead site in World 1. See Section 5.4. |
| **The Mountain Pass (Act 1, Mountains)** | `dungeon_manager.gd` (`interior_kind == "mountains"`: `_generate_mountain_layout`, `_mountain_connect`, `_define_mountain_spawn_zones`; `can_step`, `cliff_face_tiles`, `step_tiles`), `player.gd` (`step_check`), `enemy.gd` (`_can_step`, route-first on cliffs), `main.gd` (`_climber_blocked_tiles`) | **Built.** Terraced snowy mountainside, cliffs walked round by steps, enemies on the ledges, fliers over the cliffs. Reached via the Mountain Pass site in World 1. See Section 5.4. |
| **Ice Caves & the Ice Troll Lair (Act 1, Mountains)** | `dungeon_manager.gd` (`icecave`: the cave layout, `_define_ice_cave_spawn_zones`; `trolllair`: `_generate_troll_lair_layout`, `mountain_wall_tiles`, `blink_clear`, `_place_troll_hoard`, `gold_piles` / `take_gold_pile`, `_create_chest(..., legendary)`; `_place_mountain_caves`, `_place_door_site`), `main.gd` (`_check_gold_pile_pickup`) | **Built.** Off the Mountain Pass; World 3's caves are Ice Caves. |
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
- ✅ **The Greenwood forest and the Caves are built** — woodland of clearings,
  trails and hills with climbable trees (high ground + tutorial), bear traps and
  hunters' dart tripwires, pits and squirrels; and dark, dripping cave tunnels
  with stalagmites/stalactites, puddles and a player torch. See Section 5.4 / §8.

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
