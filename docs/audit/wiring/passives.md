# Wiring audit — skill-tree passives

Phase 2, slice `passives`. Every passive in the five skill trees (Brad, Cory,
Jeremy, Ryan, Stephen): 60, not 58 — the inventory's generator drops the two
ids with an apostrophe (`a_mage's_favor`, `let's_dance`). The description is
the `description` field in `scripts/progression/skill_tree_data.gd`; the code
is `progression_triggers.gd`, `passive_scaling.gd` (rank tables),
`passive_cooldowns.gd`, `player_stats.gd` and the hooks in `main.gd`.

Every row is proven by `tests/test_wiring_passives.gd`, which boots the dojo,
grants only the passive under test, and checks the trigger, the effect, rank 1
and rank 15, and the cooldown. Its checks are named `<Passive> r1|r15: …`; the
row gives one representative check (the r1 and r15 checks have the same text).

`docs/PASSIVE_REFERENCE.md`'s "code and text disagree" list (12 entries) was
re-checked against the current code; each is answered in its row.

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| Enraged Will | passive | FIXED | Fired at exactly the threshold (`<=`); the text says "drop below". "10 mana per kill" is right: displayed mana is code mana (HUD shows `current/max`, max 50). Fires on the damage hook while low, so once the cooldown passes the next hit re-triggers it (fits "Cooldown"). | `progression_triggers.gd`: strict `<` threshold. | test_wiring_passives.gd::Enraged Will r15: at exactly 25% HP nothing swings; ::Enraged Will: two kills by the swing gain 10 mana each |
| In the Trenches | passive | CORRECT | — | — | test_wiring_passives.gd::In the Trenches r15: an enemy stepping adjacent takes a free 120% attack |
| Stone Skin | passive | CORRECT | — | — | test_wiring_passives.gd::Stone Skin r15: PHYSICAL damage reduced by 11.50% |
| Point to Prove | passive | CORRECT | — | — | test_wiring_passives.gd::Point to Prove r15: confirming pays 6 HP (6%) and ignores STUN |
| Directed Strength | passive | CORRECT | Reference flagged "<= 50%". Gain below 50%, lose "when going above": at exactly 50% the text does not say to lose it, and the code keeps it. | — | test_wiring_passives.gd::Directed Strength r15: below 50% health it adds +15 STR |
| The Way of the Plate | passive | CORRECT | — | — | test_wiring_passives.gd::The Way of the Plate r15: the 2th refunds 10 mana and 1 tempo |
| Ancestral Aid | passive | FIXED | "More defense" counted only the Defense type; the taxonomy's defensive card is the type or the `defense` tag (Vengeful Shield). | `progression_triggers.gd`: new `_is_defensive()` used for the hand count. | test_wiring_passives.gd::Ancestral Aid r15: more defense cards (a defense-tagged instant counts) heals 17 |
| Redemption | passive | CORRECT | — | — | test_wiring_passives.gd::Redemption r15: the next offensive card's roll spends it |
| Life Steal | passive | BLOCKED | *(Phase 6 re-check)* Heals `max(1, damage dealt × %)` once per attack card, and falls back to the card's printed damage when the play recorded none — a whiff heals, and an area attack steals from one hit only. | BLOCKED: area attacks resolve in main.gd with no record of what they hit. Plan in docs/audit/validation.md. | test_wiring_passives.gd::Life Steal r15: a passive hit of 200 steals 8% = 16 |
| Pristine Armor | passive | CORRECT | — | — | test_wiring_passives.gd::Pristine Armor r15: three in a row add +14 more; ::a utility in between resets the streak |
| Vines Codependence | passive | FLAGGED | Fires on any direct heal Brad *receives* (an ally's heal on him included) and not on a heal he casts on an ally. "Whenever you heal" can read either way. | — | test_wiring_passives.gd::Vines Codependence r15: a direct heal grants 8 thorns for 5 tempo |
| Solemn Independence | passive | CORRECT | — | — | test_wiring_passives.gd::Solemn Independence r15: an offensive hit of 100 lands for 112 |
| Energy Barrier | passive | CORRECT | — | — | test_wiring_passives.gd::Energy Barrier r15: the 3rd non-regen gain adds a 0m/0t Energy Barrier for 17 armor, Erase 1 |
| Prey on the Weak | passive | CORRECT | — | — | test_wiring_passives.gd::Prey on the Weak r15: a new debuff on an enemy below 50% deals 17 |
| Wither | passive | FLAGGED | The open design note in CLAUDE.md: "+1 charge" is `apply_debuff(name, 1)` — +1 stack on stack debuffs, +1 tempo on additive timers, a no-op on max-timers (Stun, Silence…) that still spends the cooldown; it fires on debuffs from any source. Its +1 also re-rolls Elemental Conclusion. | — (design note, not changed) | test_wiring_passives.gd::Wither r15: +1 charge on the applied debuff (poison 2 → 3) |
| Budding | passive | CORRECT | — | — | test_wiring_passives.gd::Budding r15: utility, defense, offensive (none back to back) heals 19 and gives 19 temp HP for 15 tempo |
| Eat | passive | CORRECT | — | — | test_wiring_passives.gd::Eat r15: an enemy at 5% (threshold 39%) takes +34% from a direct hit |
| Expel Negativity | passive | FLAGGED | Fired at exactly the threshold (`<=`; text: "drop below") — fixed. Open: the 2 charges refill together only when both are spent and 10 tempo pass, while In the Trenches (same "2 charges, 10 tempo cooldown" wording) returns each charge 10 tempo after it was spent. Debuffs with no enemy counterpart (Cuffed, Blind…) cannot move (nothing spent). | `progression_triggers.gd`: strict `<` threshold. | test_wiring_passives.gd::Expel Negativity r15: exactly at 63% is not below it; ::dropping below 63% moves Slowed to the nearest enemy, one charge |
| Circle of Life | passive | CORRECT | — | — | test_wiring_passives.gd::Circle of Life r15: and +24 damage on the next 3 offensive cards |
| Territorial Death | passive | CORRECT | — | — | test_wiring_passives.gd::Territorial Death r15: after 1 tempo it fires again |
| Self Reliance | passive | CORRECT | — | — | test_wiring_passives.gd::Self Reliance r15: 3 cards in one cycle cut a hand card by 60m |
| Death as Lifeblood | passive | CORRECT | Reference flagged the Euclidean 2.0 radius. The grid is walked without diagonals (`get_distance_in_cells` is Manhattan), and on whole cells a 2.0 radius is exactly "within 2 squares": (1,1) and (2,0) in, (2,1) out. | — | test_wiring_passives.gd::Death as Lifeblood r15: each cycle 5 HP per enemy within 2 squares, up to 12 |
| Serial Killer | passive | FIXED | Fired at exactly the threshold (`<=`); the text says "drops below". | `progression_triggers.gd`: strict `<`. | test_wiring_passives.gd::Serial Killer r15: exactly at 25% is not below it; ::attacking it reveals him with an auto-crit |
| Regrowth | passive | FLAGGED | Draw 4 on an empty hand and the 25→11 cooldown work. Open: the cooldown is spent even when nothing could be drawn (Cuffed, empty piles), and any hand refresh with an empty hand fires it (including a load with an empty hand), not only the act of emptying it. | — | test_wiring_passives.gd::Regrowth r15: emptying the hand draws 4, cooldown 11 |
| Arcane Overflow | passive | CORRECT | Reference's re-audit note says it primes on an offensive card; the code (rightly, per the taxonomy) primes on the Spell school. | — | test_wiring_passives.gd::Arcane Overflow r15: the next offensive card costs -1 tempo (Slash 3 → 2) |
| I Heal You | passive | CORRECT | — | — | test_wiring_passives.gd::I Heal You r15: every 4 tempo an ally 3 squares away is healed 3 |
| Tricks of Death | passive | CORRECT | — | — | test_wiring_passives.gd::Tricks of Death r15: card chances +12.0 points |
| A Mage's Favor | passive | CORRECT | — | — | test_wiring_passives.gd::A Mage's Favor r15: a reroll batch that changed an outcome adds one 0m/0t Magic Barrier instant (16 armor)…; test_passive_feedback2.gd (the barrier is up before the blow) |
| Harnessed Power | passive | CORRECT | — | — | test_wiring_passives.gd::Harnessed Power r15: damage +32% / armor gain +32% / healing +32% |
| Whispers of the Flock | passive | FLAGGED | *(Phase 6 re-check)* Only a card with a printed heal aimed at another ally grants the Mark; Communal Donation, Mend and Halo's per-cycle heals never do. Should every heal of an ally count? | — | test_wiring_passives.gd::Whispers r15: the marked ally survives lethal at 1 HP with 19 armor; Jeremy takes 8 |
| Seance | passive | CORRECT | — | — | test_wiring_passives.gd::Seance r15: 33 HP, 33 damage to its killer |
| Kinetic Armor | passive | FIXED | "Defensive cards in your deck" counted only the Defense type, not `defense`-tagged cards. | `progression_triggers.gd`: `_is_defensive()` for hand, draw and discard. | test_wiring_passives.gd::Kinetic Armor r15: past 16 tempo the nearest enemy gets shock = defense cards in the deck |
| Mana Surge | passive | FLAGGED | The conjured card said "gain 1 mana"; it gains 10, as the passive says — fixed. Open: the text calls the card an "Attack" but it is a Spell (school SPELL, INT-scaled, card face "Spell"); and spending is recorded when each card resolves, from its printed cost (a Demonic-Rage play paid in health still counts as mana spent). | `card.gd` `create_mana_surge`: description "gain 10 mana". | test_wiring_passives.gd::Mana Surge r15: 100 mana within 5 tempo adds a 0m/2t Mana Surge dealing 18; ::the card says it gains 10 mana |
| Haunted Rebuke | passive | FIXED | "3 or more defensive cards" counted only the Defense type. | `progression_triggers.gd`: `_is_defensive()`. | test_wiring_passives.gd::Haunted Rebuke r15: with 3 defensive cards (a defense-tagged instant counts) the attacker's next action takes +3 tempo, cooldown 11 |
| Blood Libation | passive | CORRECT | — | — | test_wiring_passives.gd::Blood Libation r15: at 5 stacks he takes 10, then the heal lands doubled, stacks consumed |
| Fresh Start | passive | CORRECT | — | — | test_wiring_passives.gd::Fresh Start r15: emptying the hand cleanses a debuff |
| Keep Them Guessing | passive | CORRECT | — | — | test_wiring_passives.gd::Keep Them Guessing r15: the 4th discard cuts a hand card by 3 tempo for 5 tempo |
| Quick Step | passive | CORRECT | — | — | test_wiring_passives.gd::Quick Step r15: an instant fired from hand grants 16 armor |
| Stimulant | passive | FIXED | Drew a card (and spent its cooldown) when Poisoned Blood turned the Pocket heal into damage, so nobody was healed. | `progression_triggers.gd`: skip when `heal_to_damage` flipped the heal. | test_wiring_passives.gd::Stimulant r15: a heal Poisoned Blood flipped to damage heals nobody: no draw, no cooldown |
| Now You See Me | passive | FLAGGED | *(Phase 6 re-check)* Charge and the Repelled Block push move you without counting as "non-standard movement"; Roll and Heroic Leap count. Should they? | — | test_wiring_passives.gd::Now You See Me r15: a displacement grants invisibility for 5 tempo; test_passive_triggers / test_passive_feedback2 (the displacement sources) |
| From the Hip | passive | CORRECT | — | — | test_wiring_passives.gd::From the Hip r15: a drawn attack costs -30m/-2t |
| Ladder Work | passive | CORRECT | — | — | test_wiring_passives.gd::Ladder Work r15: the first attack this cycle deals +6 per card discarded last cycle |
| Pop Rocks | passive | CORRECT | — | — | test_wiring_passives.gd::Pop Rocks r15: poisoning a poisoned enemy deals 1/3 of its stacks (9 → 3) |
| Surprise Opener | passive | CORRECT | — | — | test_wiring_passives.gd::Surprise Opener r15: first strike on an untouched, unarmored enemy: +40 |
| Nimble Assault | passive | FIXED | "No Defense cards" ignored a `defense`-tagged card in hand. | `progression_triggers.gd`: `_is_defensive()`. | test_wiring_passives.gd::Nimble Assault r15: a defense card in hand (a defense-tagged instant counts): no draw |
| Let's Dance | passive | CORRECT | — | — | test_wiring_passives.gd::Let's Dance r15: 8 spaces ÷ 1 = 8 armor and 8 damage to the nearest enemy within 3 |
| Mad Scientist | passive | FLAGGED | Poison Bomb is aimed at a tile, so its card-play target is no enemy: the Utility→Poison and Defense→Poison outcomes never landed — fixed. Open: Utility→Heal regen lasts 15 tempo (not in the text); "potion cards" is read as every Pocket card; a Poisoned-Blood-flipped heal on yourself or an ally has no poison outcome to land. | `main.gd` records the enemies Poison Bomb poisoned (`last_poison_bomb_hits`); `progression_triggers.gd` lands the riders on each. | test_wiring_passives.gd::Mad Scientist r15: Utility → Poison Bomb: +9 poison on every enemy it poisoned; ::Defense → Poison Bomb: -15% physical defense on them for 5 tempo |
| Eye Scrape | passive | FIXED | Counted one crit per card: a multi-hit card critting on several hits advanced "every Nth critical strike" by 1; Quiver / Manifest plays reported no crits at all. | `buff_manager.gd`: `crit_hits` counter; `main.gd` passes the count for hand, echo and Quiver/Manifest plays; `progression_triggers._trigger_skill_tree_on_crit(target, crit_count)` counts each. | test_wiring_passives.gd::Eye Scrape: a Multishot critting on all 3 hits counts 3 critical strikes (rank 13: every 3rd) |
| Deadly | passive | CORRECT | — | — | test_wiring_passives.gd::Deadly r15: and +30% crit damage |
| Clean Exchange | passive | CORRECT | — | — | test_wiring_passives.gd::Clean Exchange r15: the attack deals its damage and gains the 8 block when played |
| Eagle Eye | passive | CORRECT | — | — | test_wiring_passives.gd::Eagle Eye r15: a ranged offensive card adds 142% of its range 6 = +9 |
| Patience is a Virtue | passive | CORRECT | — | — | test_wiring_passives.gd::Patience is a Virtue r15: it grants 30% resistance to all damage for 5 tempo |
| Easy Target | passive | CORRECT | — | — | test_wiring_passives.gd::Easy Target r15: exposing the enemy deals the 30 hit again |
| Exposed Blind Spot | passive | CORRECT | — | — | test_wiring_passives.gd::Exposed Blind Spot r15: a melee blow arms 4.50% per non-attack card |
| Scouted | passive | CORRECT | — | — | test_wiring_passives.gd::Scouted r15: +6 range on the next attack; ::the next attack on ANY enemy auto-crits; ::with +30% crit damage |
| Swing for the Fences | passive | CORRECT | — | — | test_wiring_passives.gd::Swing for the Fences r15: a 6-tempo card deals 380% of 6 = +23 |
| Skilled Momentum | passive | CORRECT | — | — | test_wiring_passives.gd::Skilled Momentum r15: the next attack after 3 in a row is played twice; ::the armed attack lands twice |
| Lethal Resourcefulness | passive | CORRECT | — | — | test_wiring_passives.gd::Lethal Resourcefulness r15: 3 cards + a non-attack: a free basic attack |
| Elemental Conclusion | passive | FLAGGED | Chance 50%→100% matches (the table steps +3/rank to 89%, then 100% at rank 15 — the curve is balance). Open: it rolls on every burn/cold/shock landing on an enemy, whoever applied it, and again on the riders' re-applications (Harnessed Sun's +2, Wither's +1), so one application can roll it more than once. | — | test_wiring_passives.gd::Elemental Conclusion r15: 100% — every burn gets +1 charge; ::Elemental Conclusion r1: about 50% |
| Dominate | passive | CORRECT | — | — | test_wiring_passives.gd::Dominate r15: an attack speed proc adds a 30m/0t basic attack card; ::after 5 tempo yes |

**Counts:** CORRECT 45 · FIXED 8 · MISSING 0 · FLAGGED 7 (Expel Negativity,
Mana Surge and Mad Scientist also carry a fix; they are counted as FLAGGED).

## Flagged — questions for the designer

- **Vines Codependence** — "Whenever you heal": when Brad *is healed* (by
  anyone, his own heals and allies' — what the code does), or when Brad *casts*
  a heal (on himself or an ally, which Redemption's "when healing (self or
  ally)" does)?
- **Wither** — (CLAUDE.md open note) what does "+1 charge" mean per debuff?
  Today: +1 stack (5 tempo) on stack debuffs, +1 tempo on Disarm/Root/Curse,
  nothing on Stun/Silence/Narashimha/Polymorph/Mark/Trip (cooldown still spent).
  And should it fire only on debuffs Cory applies (today: any source — allies,
  traps, the enemy itself)?
- **Expel Negativity** — "2 charges, 10 tempo cooldown": should each spent
  charge come back 10 tempo after it was used, as In the Trenches does with the
  same words? Today both refill together only after both are spent.
- **Regrowth** — should a trigger that draws nothing (Cuffed, empty draw and
  discard piles) spend the 25→11 cooldown? And is "emptying your hand" only the
  moment the hand empties, or any time the hand is empty when the cooldown is
  up (today: any hand refresh while empty, a save loaded with an empty hand
  included)?
- **Mana Surge** — the text says the Mana Surge card is an "Attack"; it is a
  Spell (spell school, INT scaling, face reads "Spell"). Which? Should the
  100-mana window count mana when it is paid (play) or when the card resolves
  (today), and should a play paid in health (Demonic Rage) count?
- **Mad Scientist** — (a) Utility→Heal regen lasts 15 tempo; the text gives no
  duration — is 15 right? (b) "Potion cards" is implemented as every Pocket card
  (Dagger Throw, Quick Shot… only heal/poison ones do anything) — should it be
  the potion cards only? (c) A heal Poisoned Blood flips to damage on yourself
  or an ally counts as a "Poison" outcome but has no enemy to land on — intended?
- **Elemental Conclusion** — should it roll only on burn/cold/shock *Stephen*
  applies, and only once per application (not again on Harnessed Sun's +2 or
  Wither's +1)?

## Notes for other slices

- **Poison Bomb (cards)**: its world effect aims at the mouse position *when the
  card resolves* (`main._apply_card_world_effects` reads
  `get_mouse_world_position()`), not the `aim_world` stored when it was played,
  so a 3-tempo wind-up lands wherever the cursor is then.
- **`data/cards/mana_surge.tres`** still reads "gain 1 mana"; only the conjured
  card's description (`Card.create_mana_surge`) was fixed here.
- `tests/test_passive_triggers.gd` passes on this base; it only fails in a
  fresh worktree before `godot --headless --import` has built
  `.godot/global_script_class_cache.cfg` (every class name is "not declared").
