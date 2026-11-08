# Wiring audit — slice `enemies_b` (enemies and summons)

Phase 2 of `audit/full-pass-1`. The stated description of an enemy is its compendium text
(`Enemy.get_all_enemy_data`: `_specials` and `_actions`); of a summon, the text of the card, item or
passive that calls it up. Each was traced through `actions_for_type`, the chooser, the executor in
`_run_action`, the passives in `on_tempo_advanced` / `take_damage`, `EnemyDefs`, and for summons the
driver in `main.gd`. The "methodical" rules (`docs/ENEMY_ACTION_KEYWORDS.md`, 2026-11-07) were taken
as given.

New test file: `tests/test_wiring_enemies_b.gd` (one dojo boot, about 359 checks, ~1 minute). It
starts with a table pass over all 37 enemy types: every compendium action has the tempo of its table
entry, every "Move (N tempo): M spaces" line matches the table and `EnemyDefs.move`, every quoted
resist line, armor, range, main hit, "Flying" and "no XP" matches `EnemyDefs`. Those checks are
named `<TYPE>: …` in the file and back every enemy row below as well as the behaviour checks named.

Damage checks compare with the band-scaled number the game really deals (the compendium appends
"action numbers above are base — actual … damage x…"); see the Flagged note on flat numbers.

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| Pipe Crawler | enemy | CORRECT | | | test_wiring_enemies_b.gd::Pipe Crawler: about 25% of claws disarm (…); ::Pipe Crawler: the disarm lasts 5 tempo |
| Sewer Cobra (SEWER_CROC) | enemy | CORRECT | | | test_sheet_act1a.gd (Venom Spray cone, thorns, poison back, exposed stun and clock reset); test_wiring_enemies_b.gd::SEWER_CROC: armor 20 as the text quotes |
| Rat King | enemy | CORRECT | | | test_sheet_act1a.gd (Infest), test_rat_king_lair.gd (nest flights 50/30/30, 20/30/50% heals), test_rat_king_infest.gd |
| Swarm | enemy | CORRECT | | | test_wiring_enemies_b.gd::Swarm: Move is 8 spaces for 3 tempo; ::Swarm: Attack deals 3 |
| Weregoat | enemy | CORRECT | | | test_sheet_mountains.gd (Charge: lane damage, landing stun 3 tempo); test_weregoat_charge.gd |
| Wyvern | enemy | FIXED | Talon Grab's "unoccupied space 8 squares away" was any cell not marked blocked: about a third of grabs in the dojo dragged the player off the grid or into the rock past the walls (`_random_free_cell_at_distance` never checked the map) | `Enemy._random_free_cell_at_distance` now also requires `_can_stand_on` (floor, on the map, no pillar) | test_wiring_enemies_b.gd::Wyvern: the prey is dragged onto open floor, never off the map; ::Wyvern: then a 2-cycle (10 tempo) cooldown |
| Roc | enemy | CORRECT | | | test_sheet_mountains.gd (dive from 6, lands beside, 5-tempo cooldown, always retreats, Eye Scrape after 3 tempo for 2 Weakened) |
| Ice Troll | enemy | CORRECT | | | test_wiring_enemies_b.gd::Ice Troll: every attack adds a stack of Cold (5 tempo); ::Ice Troll: a freezing club triggers Clobber (50, band-scaled …) |
| Snow Wraith | enemy | CORRECT | | | test_wiring_enemies_b.gd::Snow Wraith: Snowball Slows for 3 tempo; ::Snow Wraith: Ice Blast +3 against armor |
| Granite Colossus | enemy | FLAGGED | Text gives "Move (5 tempo): 3 spaces" and then "it only stands"; its table is empty, so it never moves | none | test_wiring_enemies_b.gd::Granite Colossus: no actions on the sheet yet — it only stands; test_enemy_sheet_pass.gd (350 HP / 250 armor) |
| White Manticore | enemy | CORRECT | | | test_sheet_mountains.gd (Stinger: 8 Poison, 3 Clumsy stacks, 5-tempo cooldown) |
| Sabertooth Tiger | enemy | CORRECT | | | test_wiring_enemies_b.gd::Sabertooth: about 35% of strikes crit for 1.5x; ::Sabertooth: a crit inflicts 6 Bleed; ::Sunken Bite: 10 damage + 8 Bleed; test_sheet_mountains.gd (Track, Bite and Claw) |
| Cerberus | enemy | CORRECT | | | test_hellgate.gd (Bite heads, Venom Tail, Roar, Guardian of Death, Deathyard Dog); test_wiring_enemies_b.gd::Cerberus: Swipe lays 8 Bleed and no wound of its own |
| Succubus | enemy | CORRECT | | | test_wiring_enemies_b.gd::Succubus: Damaging Snap = missing mana / 20 + 4; test_succubus_drain.gd (drains 10 mana) |
| Demon | enemy | CORRECT | | | test_sheet_underworld.gd (Mimic); test_wiring_enemies_b.gd::Demon: Cuff — no draws for 15 tempo |
| Ifrit | enemy | CORRECT | | | test_wiring_enemies_b.gd::Ifrit: a unit inside the 5x5 is hit, one beside it is not; ::Ifrit: the 25 tiles keep burning for 3 tempo; ::Ifrit: a blow over 40 backflips it 3 squares away |
| Mind Eater | enemy | CORRECT | | | test_sheet_underworld.gd (Mind Slow +20 per card until played); test_wiring_enemies_b.gd::Mind Eater: Manipulate Mind Space — no draws for 15 tempo, from 5 squares |
| Specter | enemy | CORRECT | | | test_sheet_underworld.gd (Invisible 3 tempo); test_wiring_enemies_b.gd::Specter: Spirit Spit hits for 2 (…) at range 2 |
| Magma Spider | enemy | CORRECT | | | test_sheet_underworld.gd (Fire Web range 3, Slowed, 1 every 3 tempo; Fire Bounce 4 squares, trail 3 tempo) |
| Pit Fiend | enemy | CORRECT | | | test_wiring_enemies_b.gd::PIT_FIEND: a design mock-up with no moves, as the compendium says |
| Ash Harpy | enemy | CORRECT | | | test_sheet_underworld.gd (Card Steal from 5, once, card returns on death; Peck from 4 lands beside) |
| Inflamed Minotaur | enemy | FIXED | Labyrinth Leap uses the same helper as Talon Grab: "a random open tile" could be off the map or inside a wall (test_labyrinth passed only because the maze is walled all round) | same change as the Wyvern (shared helper) | test_wiring_enemies_b.gd::Minotaur: he lands on open floor; ::Minotaur: each Slow stack shortens the 14-space leap by 1; test_labyrinth.gd (Bull Rush, wake fire heals 10, Lost in the Labyrinth) |
| Cherub | enemy | CORRECT | | | test_sheet_underworld.gd (first arrow on entering 4, hidden 5 tempo, 10-tempo clock); test_cherub_arrow.gd |
| Djinn | enemy | CORRECT | | | test_wiring_enemies_b.gd::Djinn: …and bounds 4 squares on for 35 (…); ::Djinn: an attack on him puts 3 Wishes in the hand; ::Djinn: each Wish sears for 1/3 of the hit per cycle |
| Corrupted Archangel | enemy | CORRECT | | | test_wiring_enemies_b.gd::CORRUPTED_ARCHANGEL: a design mock-up with no moves, as the compendium says |
| Ring Wraith | enemy | CORRECT | | | test_wiring_enemies_b.gd::Ring Wraith: acts though you are invisible (…); ::Ring Wraith: the slain one resummons fresh, the wounded one returns as it was |
| Training Dummy | enemy | CORRECT | | | test_wiring_enemies_b.gd::Dummy: a killing blow only refills it; test_dojo.gd |
| Rat Nest | enemy | CORRECT | | | test_rat_king_lair.gd (15-HP structure, releases its archer once, feeds the king once) |
| Gravestone | enemy | CORRECT | | | test_boneyard.gd (10-HP structure, 1 regen per stone per cycle, never decays) |
| Grave Digger | enemy | CORRECT | | | test_boneyard.gd (walks to the stone, repairs in 8 tempo, three in all) |
| Hell's Door | enemy | CORRECT | | | test_hellgate.gd (seals at 75/50/33% for 10 tempo, feeds Guardian of Death) |
| Thanatos | enemy | FIXED | "each of his servants that falls … costs him 10 health": the echo went through his 40 armor (58 band-scaled) and 25% resist, so it cost 7 armor and no health at all | `_necro_rise_on_death`: when the summoner is Thanatos the 10 goes straight to health (`ignore_armor`); the Necromancer ("takes 10 damage") is unchanged | test_wiring_enemies_b.gd::Thanatos: …and costs him 10 health (…); ::Thanatos: Death Bolt hits for 15 at 6 squares; ::Thanatos: …and Hexes a card (+30 mana, 25 tempo) |
| Air Totem | enemy | CORRECT | | | test_totems.gd (vortex 3/2/1 extra tempo) |
| Earth Totem | enemy | CORRECT | | | test_totems.gd (heals its mage, not itself); test_wiring_enemies_b.gd::Earth Totem: Thorns — a direct hit on it costs the attacker 5 |
| Lightning Totem | enemy | CORRECT | | | test_wiring_enemies_b.gd::Lightning Totem: …and every other unit within 4; ::Lightning Totem: strikes the nearest of them (…) |
| Fire Totem | enemy | CORRECT | | | test_totems.gd (3 Burn within 3, not at 4) |
| Ice Totem | enemy | CORRECT | | | test_totems.gd (bursts for 1 + tempo stood, goes off at 10, crumbles with its mage) |
| Summon (base class) | summon | CORRECT | | | test_summon_debuffs.gd (enemy debuffs on summons); test_card_sheet_pass.gd (Cover on summons) |
| HealableSummon | summon | CORRECT | | | test_wiring_enemies_b.gd::Healable summon: heals land on it |
| MarkableSummon (Shepherd's Mark) | summon | CORRECT | | | test_wiring_enemies_b.gd::Markable summon: Shepherd's Mark — survives at 1 HP with its armor; ::Markable summon: …and the caster takes 8 |
| Spirit Bow (maintained) | summon | FLAGGED | The item says its bow summons gain "+2 damage … per living bow summon"; the code adds +2 per OTHER bow (a lone spirit bow hits for 10, as the Spirit Bow card says) but counts every bow, itself included, for the +5% crit | none | test_ranged_pass.gd (10 damage every 4 tempo); test_wiring_enemies_b.gd::Spirit Bow: with no mana held for it, it dissolves |
| Budded bow | summon | FLAGGED | *(Phase 6 re-check)* Same question as the Spirit Bow flag below: +2 damage per *other* bow, +5% crit per bow including itself. |  | test_ranged_pass.gd (6 damage every 5 tempo, any damage kills it); test_wiring_enemies_b.gd::Budded bows: up to 4 at once; ::Budded bow: …it withers after 2 attacks |
| Draupnir's duplicate (summoned_clone) | summon | CORRECT | | | test_rings_pass.gd (9th hit drips one, trigger waits); test_wiring_enemies_b.gd::Draupnir: a quarter of your health; ::Draupnir: only one at a time; ::Draupnir: when a duplicate dies, Strengthen |
| Bone-arrow skeleton (Sack of Bone Arrows) | summon | CORRECT | | | test_wiring_enemies_b.gd::Bone skeletons: up to 3 at once; ::Bone skeleton: the victim's half health, 5 damage, 4 squares a tempo, attacks every 5 tempo |
| Manifest spirit / golem (summoned_skeleton kinds) | summon | FLAGGED | No card or item text summons them: only the sandbox and the `summon_spirit` / `summon_golem` manifest branches in `main.gd`, which no data file produces | none | (none — no stated description) |
| Summon Skeleton / Skeleton Army | summon | CORRECT | | | test_summon_cards.gd (10 HP, 6 damage every 5 tempo, 1 space a tempo, 4 for the Army, outside the cap); test_summon_march.gd |
| Shadow Hound | summon | CORRECT | | | test_summon_cards.gd (10 HP, 4 damage every 8 − INT/10); test_summon_march.gd (2 spaces a tempo) |
| Battle Turtle / Turtle Power | summon | CORRECT | | | test_summon_cards.gd (25 HP, unerring armor INT/2, a fifth back every 5 tempo, shared with allies); test_summon_march.gd |
| Seance Specter (summoned_specter) | summon | CORRECT | | | test_wiring_enemies_b.gd::Seance specter: fades at 25 tempo; ::Seance specter: destroyed, its HP lands on its killer |
| Wolf (Gauntlets of Dungeon Mastering) | summon | CORRECT | | | test_wiring_enemies_b.gd::Wolves: a pack of 3 at most; ::Wolves: two pack-mates each bite for 6 (5 +20%); ::Wolf: 2 squares every 3 tempo |
| Alaskan Bull Worm | summon | CORRECT | | | test_wiring_enemies_b.gd::Bull Worm: untargetable while burrowed; ::Bull Worm: surfaces to attack, for 6; ::Bull Worm: 1 movement per tempo, still burrowed |
| Frankensteins Monster | summon | CORRECT | | | test_wiring_enemies_b.gd::Frankenstein: 50 + INT x0.8 HP, 10 + INT x0.25 attack, 5% + INT/10 resist (INT 40); ::Frankenstein: 4 spaces every 8 tempo; test_card_item_audit.gd (raised from the corpse) |
| Sanguine the Penguin | summon | CORRECT | | | test_wiring_enemies_b.gd::Sanguine: damage he takes heals you half as much (…); ::Sanguine: 8 damage every 5 tempo; test_item_feedback.gd (the Vitality summon) |

## Flagged

- **Granite Colossus** — the compendium lists "Move (5 tempo): 3 spaces" but also says "it only stands", and its action table is empty (the sheet's moves are TBD). Should it walk (add a 5-tempo Move to its table) or should the Move line come out of the text until its kit is designed?
- **Spirit Bow / budded bows** — "This bow and its bow summons gain +2 damage and +5% crit chance per living bow summon" (Bow of Budding Blasts). The code gives each bow +2 damage per *other* bow, but +5% crit per bow *including itself*; a lone Spirit Bow hits for 10, matching the Spirit Bow card's "10-damage shot". Does a bow count itself (then a lone bow hits for 12 and the card text changes), or not (then the crit should be 5% per other bow)?
- **Manifest spirit / golem** — `SummonedSkeleton` keeps "spirit" and "golem" kinds and `main.gd` has `summon_spirit` / `summon_golem` manifest handlers, but no card or item produces them; they are reachable only from the sandbox. Keep for a future item, or remove?
- **Flat sheet numbers vs the level-band note** (shared by several enemies, not a single row) — every banded enemy's compendium text ends "(Level-band rebalance: action numbers above are base — actual HP x…, damage x….)". Most hard-coded hits honour it (`roundi(N * _pps_dmg)`: Stinger, Talon Grab, Clobber, Fire Breath, totems), but some stay flat: Weregoat Charge 8 (test_sheet_mountains asserts 8), Sabertooth Bite 6 / Claw 3 / Sunken Bite 10, Thanatos Death Bolt 15, Snow Wraith Ice Blast's +3, Succubus Damaging Snap's +4, Sewer Cobra Venom Spray 10 (its comment says flat on purpose). Should those scale with the band like the rest, or should the note say which numbers it covers?
