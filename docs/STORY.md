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
> and end. The end-game is **the City** — defending and growing the home base
> the player has been feeding all game (Section 6). It layers directly on top
> of the story; nothing resets.

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
- **Part slots:** 1) **Town & Sewers** — *the Sewers are built* (the opening dungeon; Olorin's first quests; Rat King mini-boss). See Section 5.4. · 2) Cemetery / Library (first clues) `[TBD]` · 3) **Forests / wilds** — *the Greenwood forest and the Caves are built* (climbable trees, hunters' traps, woodland beasts; dark dripping cave tunnels). See Section 5.4. · 4) Act 1 climax / threshold downward `[TBD]`.

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
gate, card source, expedition-zone resident).

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
  bestiary, and kills feed the city's expedition rewards (Section 6).

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
- **Giant Beaver** — *in code*. Elite. Chomp (4 tempo, 6 dmg, **Stun** 3 tempo) queues a **Tail Whip** follow-up (2 tempo later, 4 dmg, **Vulnerable** 15 tempo). Sits upright when still, scurries on all fours.
- **Mini Bear** — *in code*. Minion, *packs*. When a packmate in sight is hurt, the others gain **+1 attack damage**.
- **Wolf** — *in code*. Minion, *packs*. Within 4 tiles of another wolf: **+2 attack damage and +2 HP regen/cycle**.
- **Coyote** — *in code*. Minion. Fragile (5 HP) 1-damage nuisance.
- **Bugbear** — *in code*. Minion. **First Strike**: +5 damage if it hits before the player hits it.
- **Giant Hawk** — *in code*. Minion. Flying — **ignores the player's high-ground bonus**; 15% to **Blind** on hit (attacks may miss).
- **Large Bear** — *in code*. Elite. Very tanky; **Maul applies Bleed** (hurts the player on movement); drops to all fours below 20% HP.
- **Infected Hunter** — *in code*. Elite. **Hook** (range 7, starts charged) reels the player in over 2 tempo; AOE **Cleave**.
- **Treant** — *in code*. Elite. Heals 5 HP/5 tempo (**+2 per 10% HP below 60%**); **Root** pins the player 8 tempo (can attack, cannot move); deals **Earth** damage.
- **Elemental Mages** — *in code*. The five caster variants deal **typed damage**: Ice (→ **Slow**), Fire (→ **Burn**), Spark/Lightning (→ **Shock**), Air/Wind, Earth (**gains 3 armor every time it is hit**).
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

> **Caves — built/enhanced.** The cave interiors (`interior_kind == "cave"`) are a
> network of organic stone **tunnels and chambers**, now dressed to match: they
> are **darker even than the sewers** (lowest ambient/sun, heaviest gloom, and a
> **player-carried torch**), with **stalagmites** rising from the floor,
> **stalactites** hanging from the dark above (some **dripping**), cold **water
> puddles**, shallow **divots** and scattered rubble. Reached from cave-mouth
> sites in the overworld.

#### Sewer
*The game's opening dungeon — see **The Sewers (Act 1, Part 1)** below for the
built level. The roster is themed and in code:*
- **Rats** — *in code as Wererat / Archer Rat*. The player's first kills; the Wererat scurries and bites, the Archer Rat kites.
- **Sludge Being** — *in code*. Minion. **Ranged ooze** (8 HP): wades close or spits acid from range 6. The "oozes" the player fights alongside the rats at the entrance.
- **Pipe Crawler** — *in code*. Minion. **Fast skirmisher** (15 HP): creeps out of the wall pipes, moves on a cheap 2-tempo so it closes quickly.
- **Sewer Crocodile** — *in code*. Elite. **Armored ambusher** (25 HP, 15 armor, 10 dmg): lurks in the channels; break its armor to expose it, or its bite hurts. Guards the deepest chamber.
- **Rat King** — *in code*. Elite, **first mini-boss**. A crowned rat that fights flanked by a summoned-in army of Wererats, Archer Rats and Swarms in the central cistern arena. Bites and repositions on a relentless 2-tempo.
- **Swarm** — *in code*. Minion. **Fast swarm** (8 HP): one creature rendered as a boil of vermin/insects; blitzes 8 tiles at a time. *one creature, but a bunch of bugs representing one*
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
>   the **central cistern is the Rat King's arena**; the far-east chamber is the
>   deepest, guarded by a Sewer Crocodile.
> - **Progression (west → east):** the player opens by **killing rats and fighting
>   oozes** (Wererats, Archer Rats, Sludge Beings), reaches the **Rat King**
>   mini-boss and his rat army in the central arena, then descends into deadlier
>   water — **Sewer Crocodiles, Swarms and Pipe Crawlers** (plus more sludge).
> - **Atmosphere:** deliberately **dim and claustrophobic**. Near-lightless ambient
>   with a thick dank haze; **each player carries their own pool of torchlight**;
>   **wall torches** throw flickering light over wet brick; **fog of war reveals
>   less** than the surface. Dressing includes **wall pipes pouring water**,
>   **rising steam off the channels**, **iron floor grates**, **circular sliding
>   stone doors** at the cistern mouths, **manhole covers**, damp rubble and algae,
>   and **background mice** scuttling along the walls (purely cosmetic — the player
>   never interacts with them).

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

## 6. End-Game & Meta-Game: The City

**The game is, at its heart, a base builder.** The player adventures through
the story, gathers **resources**, and sends them back to the **home base**. The
town grows stronger, more robust, and more resilient with everything sent home
— and after the story ends, defending and growing that city *is* the end-game.
There is no separate mode bolted on; the end-game is layered **directly on top
of** the story systems the player has used all along.

> The previously planned roguelike end-game has been **removed** (code and
> all). It may return someday as a separate mode, but it effectively meant
> building a second game alongside this one — the City is the one end-game.

### 6.1 The loop during the story

- **Gather** — adventuring naturally yields resources (gold, lumber, stone,
  arcane essence) on top of the usual XP/cards/items. Kills in each habitat
  feed habitat-flavored yields (`expedition_system.gd`).
- **Send home** — resources flow back to the base, upgrading production
  (Lumber Mill, Quarry, Essence Extractor), storage (Warehouse), protection
  (Vault), military (Barracks, Walls), and hero support (Hero Hall). The Town
  Hall gates building levels, pacing growth.
- **Recruit** — along the journey the player **unlocks NPCs** who return to
  town: builders, shopkeepers, and knights/defenders who help hold the city
  against whatever comes. (The Sellsword co-op partner is the first of these;
  the pattern generalizes.)

### 6.2 Calamities — defending the base

The city periodically faces **calamities**: monster invasions and natural
disasters. The player gets **a heads-up before they land**, not an ambush:

- **Olorin's summons** — early in the game Olorin gives the player a signal
  item (working idea: a **flute**, its note heard wherever the player is) so
  he can call them back when the base — or something elsewhere — needs them.
- **Card stash matters** — this is where a deep **card collection** (stash,
  not deck size) pays off. Certain calamities/invasions are easier with
  certain cards in the deck; a player keeps their core build but may make a
  few smart swaps for the scenario ahead. Adjusting is helpful, not required.

### 6.3 After the story

- **Defend & build** — waves of calamities keep coming; the city and the
  character(s) keep growing to meet them.
- **Farm zones** — continuous missions/"zones" (drawn from the bestiary
  habitats: Forest, Sewer, Graveyard, Cave, Mountains, Underworld, Heavens)
  the player can re-enter to farm XP, cards, item drops, and resources.
- **Raids** — the city's military plus your hero's power can invade **rival
  cities** for loot; rivals invade yours while you're away (a defense log
  shows what happened). PvP is *asynchronous*, Clash-of-Clans style: you
  attack a snapshot of a city, never a live player — so generated rivals and
  real player-city snapshots share one code path.
- **Multiple heroes (planned)** — eventually the player can field **several
  of their characters together** in the end-game: characters they've built
  reside in the same city and can be played jointly in its defense.

### 6.4 Design consequences & open questions

- **Flatter story progression** — because the end-game sits directly on top of
  the story (not adjacent to it), the story itself needs **less level/stat
  progression** headroom; growth continues seamlessly into the end-game.
- **`[TBD]` Who designs the town?** Undecided: does the *player* have authority
  over how the town is constructed (earn resources → choose what to build), or
  is construction *premeditated* (accomplish a goal → receive a specific wall)?
  Possibly a hybrid.

### 6.5 Code status

**The loop is wired into the game.** The pieces:

- `scripts/city/city_state.gd` — resources/buildings/power/persistence.
- `scripts/city/expedition_system.gd` — habitat yields; kills → resources.
- `scripts/city/raid_system.gd` — rival generation, raid resolution, defense log.
- `scripts/city/city_bridge.gd` — carries city state (city + satchel +
  pending calamity) inside the `player_progression` dict that already rides
  between scenes and into saves (`SaveData.city` + `ProgressionIO`).
- `scripts/city/calamity_system.gd` — schedules a calamity when leaving town,
  ticks its countdown on kills, strikes (Olorin's flute sounds, `main.gd
  _announce_calamity`), resolves on reaching town (prompt return = the hero
  joins the defense).
- `main.gd _on_enemy_killed` — every kill adds habitat resources to the
  satchel (elites/bosses triple) and ticks the calamity countdown.
- `town.gd` — the **Town Hall** building on the plaza opens the city panel
  (stores, production, power, building upgrades, chronicle of attacks);
  `_arrive_home()` banks the satchel, resolves struck calamities, and hands
  over the flute on the founding shipment.
- Tested end-to-end: `tests/test_city_loop.gd` (data loop) and
  `tests/test_city_wiring.gd` (game wiring).

Still ahead: building *placement*/visuals, NPC recruitment beats beyond the
Sellsword, raids surfaced in the UI, defense as a *playable battle* rather
than a resolution roll, and the multi-hero end-game.

> The `CLAUDE.md` guardrail still applies: the persistent character remains
> the spine — the city is what that character builds with their power, not a
> replacement for them. Nothing about the city loop ever resets.

---

## 7. The Persistent Character (Cast)

The player carries **one** character through the entire story and into the
end-game. The current playable roster (`scripts/character/character_data.gd`):

| Character | Fantasy | Signature archetypes | Slot specialty |
|-----------|---------|----------------------|----------------|
| **Brad** | Tank / bruiser; pain is strength | Berserker, Warden, The Ancient, The Fallen | War Rack (back-slung gear swap); chest items weigh 20% less |
| **Ryan** | Dexterous duelist / rogue | Relentless Blade, Light Foot, Apothecary, Shadow Blade | 3 belt slots; belt cards cost 1 less mana |
| **Stephen** | Versatile killer / marksman | The Apex, Sentinel, Ranger, Avenger | standard slots; +10% off-hand enchantments (others −10%) |
| **Cory** | Druid / monk / witherer | Monk, Lurker, Druid, Atrophist | 2 gauntlet slots; gauntlet-skill synergy |
| **Jeremy** | Elemental mage | Evocation (+ more) | 4 ring slots; first ring trigger fires twice every 3rd cycle |

All five share the same slot baseline (1 helm, 2 rings, 1 belt, 1 chest, 1 main
hand, 1 off hand, 1 pair of boots, 1 gauntlet); the table lists each
character's single deviation from it.

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
| **Habitats / biomes** | `dungeon_manager.gd` palettes + `CAVE_PALETTE`, `BUILDING_PALETTE`, `SEWER_PALETTE`; site generation (caves, buildings, sewers) | The generator distinguishes overworld vs. cave vs. building vs. **sewer** interiors — a natural hook for habitat-specific enemy spawn tables (Section 5). |
| **The Sewers (Act 1, Part 1)** | `dungeon_manager.gd` (`interior_kind == "sewer"`: `_generate_sewer_layout`, `_build_sewer_decorations`, `_define_sewer_spawn_zones`), `main.gd` (`_apply_world_ambience` sewer branch + `_ensure_player_torch`), `torch_flicker.gd`, `sewer_critter.gd` | **Built.** The opening dungeon: trunk + water channels, Rat King arena, west→east rat/ooze → boss → croc/swarm/crawler progression, dim torchlit atmosphere, reduced fog. Reached via a sewer grate site in World 1. See Section 5.4. |
| **The Greenwood (Act 1, Forest)** | `dungeon_manager.gd` (`interior_kind == "forest"`: `_generate_forest_layout`, `_place_forest_features`, `_build_forest_decorations`, `_define_forest_spawn_zones`), `main.gd` (forest ambience, terrain-trap + tree-climb systems, tutorial), `sewer_critter.gd` (squirrels) | **Built.** Open clearings/trails/hills; climbable trees → high ground (+ one-time tutorial); bear traps (7 dmg / 10 to bears) and hunter dart tripwires (5 dmg) that hit players *and* enemies; pits; squirrels; bright fog. Reached via a forest trailhead site in World 1. See Section 5.4. |
| **Caves (Act 1, Cave)** | `dungeon_manager.gd` (`interior_kind == "cave"`: `_generate_cave_layout` + `_place_cave_puddles`, `_build_cave_decorations`, darkened `CAVE_PALETTE`), `main.gd` (cave ambience + player torch) | **Built/enhanced.** Dark stone tunnels darker than the sewers; stalagmites, stalactites (dripping), puddles, divots, player torch. Reached via cave-mouth sites. See Section 5.4. |
| **The City (end-game loop)** | `scripts/city/` (state, expeditions, raids, bridge, calamities); Town Hall panel in `town.gd`; kill hook in `main.gd`; saved in `SaveData.city` | Wired and tested (`tests/test_city_loop.gd`, `tests/test_city_wiring.gd`). See Section 6.5. |
| **Bestiary** | `Enemy.EnemyType`, `CharacterData.defeated_monster_ids` | Per-character record of story kills; feeds the compendium and future intent-reveals. 11 enemy types today (Section 5.3). |
| **Quests** | `scripts/core/quest_manager.gd` | Currently kill-quests only; Olorin is the sole giver. |
| **Town hub** | `scripts/menus/town.gd` | Persistent vendors (Blacksmith, Armory, Card Dealer, Accessory Shop, Stash) + Olorin + waypoint/transport. The shell the city loop will be wired into. |

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
- ✅ **The game is a base builder at heart.** The end-game is the **City**
  (Section 6): send resources home during the story, recruit NPCs, defend
  against calamities, farm zones, eventually field multiple heroes together.
  The roguelike end-game is **removed** (may return someday as a separate
  mode).
- ✅ **Terminology:** four **Acts** across one world; each Act is a plane.
- ✅ **Bestiary taxonomy:** catalogued by **habitat** (Forest, Graveyard, Cave,
  Sewer, Mountains, Underworld, Heavens), as flexible guidelines.
- ✅ **The Sewers (Act 1, Part 1) are built** — opening dungeon, themed roster,
  Rat King mini-boss, dim torchlit atmosphere. See Section 5.4 / Section 8.
- ✅ **The Greenwood forest and the Caves are built** — woodland of clearings,
  trails and hills with climbable trees (high ground + tutorial), bear traps and
  hunters' dart tripwires, pits and squirrels; and dark, dripping cave tunnels
  with stalagmites/stalactites, puddles and a player torch. See Section 5.4 / §8.

Still open:
0. **Grow the city loop** (the wiring is in — Section 6.5): building
   placement/visuals, NPC unlock/recruitment beats beyond the Sellsword,
   raids in the UI, calamity defense as a playable battle, the multi-hero
   end-game. Also decide **who designs the town** (player authority vs.
   premeditated unlocks — Section 6.4).
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
