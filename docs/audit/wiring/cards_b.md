# Wiring audit — cards, slice B (Detonova … Heavy Greedy Cheese)

Phase 2. Every card is played through the real play path of a booted
`main.tscn` (the dojo): `Main.play_selected_card` → `DeckManager.play_card`
(mana) → the tempo ticker (tempo) → `_resolve_queued_card` → the card's
executor and `main._apply_card_world_effects`. Each "costs X / Y" check
reads the mana the play actually spent and the ticks it put on the clock.
Test file: `tests/test_wiring_cards_b.gd` (about 11 s). Check names below
are the static start of each `_check` message.

Conventions read from the code, not flagged: a card's damage or heal number
is the base that INT / healing gear scale (Detonova's "Does NOT scale with
INT" is the exception that proves it); mana is on the x10 scale ("gain 2
mana" = 20); a card with no `tempo_cost` in its `.tres` costs the engine
default 4 (Forever Armor, Fountain of Health, Halo, Gift from the Gods,
Harden, Harness Lightning — none of their texts names a tempo).

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| Detonova (`detonova`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Detonova deals the banked 17 flat (no INT) to an enemy within 2 |
| Discard (`discard`) | card | FIXED | The random discard was not counted in `true_discards_this_cycle`, so it was not "a card discarded this cycle" for Exacerbate Wounds. | `Card._execute_discard` goes through `DeckManager.discard_card_from_hand` (counts it, emits the discard signals). | test_wiring_cards_b.gd::Discard's discard counts as a card discarded this cycle |
| Wish (`djinn_wish`) | card | CORRECT | — | — | test_wiring_cards_b.gd::a Wish held over a cycle sears its holder for 3 / Wish costs 60 mana / 0 tempo to play |
| Donate Cleats (`donate_cleats`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Donate Cleats grants the ally +5 AGI and +4 DEX / gone after 5 tempo |
| Down but not out (`down_but_not_out`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Down but not out heals 1 per debuff stack |
| Down Town (`down_town`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Down Town deals the auto attack's damage |
| Draw (`draw`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Draw draws a card |
| Earth Rattle (`earth_rattle`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Earth Rattle deals 40 to the impact and 3 squares around it / enemies hit are Slowed 2 and Weakened 2 |
| Element Pollination (`element_pollination`) | card | FLAGGED | Shock at 5 stacks gives a 5-tempo **Stun**, not Cold's **Frozen**. Burn's splash hits **every** enemy within 2.5, while Shock arcs to the **one** nearest. | — (design question) | test_wiring_cards_b.gd::Burn splashes its tick onto a nearby enemy / 5 Shock stacks lock the enemy for 5 tempo |
| Elixir (`elixir`) | card | CORRECT | — | — | test_wiring_cards_b.gd::poison a card applies under Elixir heals its target instead / the window closes after 25 tempo |
| Empower (`empower`) | card | CORRECT | — | — | test_wiring_cards_b.gd::the next 2 attack cards drawn are empowered, the third is not / an empowered attack deals +3 damage |
| Enchanted Quiver (`enchanted_quiver`) | card | CORRECT | — ("free 0-cost" is read as 0 mana; the Quick Arrow keeps the 2 tempo its own card sets) | — | test_wiring_cards_b.gd::the next 3 ranged attacks each put a Quick Arrow in hand, the 4th none |
| Enchantment: Attack (`enchantment_attack`) | card | CORRECT | — | — | test_wiring_cards_b.gd::a card deals +3 while it is in hand / Enchantment: Attack discards after 2 cycles |
| Enchantment: Defense (`enchantment_defense`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Enchantment: Defense -> +3 block on an armor gain |
| Enchantment: Mana Regen (`enchantment_mana_regen`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Enchantment: Mana Regen -> +1 mana regen |
| Enchantment: Movement (`enchantment_movement`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Enchantment: Movement -> 5 more tiles of flash per refresh |
| Endured Tolerance (`endured_tolerance`) | card | CORRECT | — | — | test_wiring_cards_b.gd::another copy adds 5 more tempo, not more % / its Erase fuse waits while Glutted |
| Energy Ball (`energy_ball`) | card | CORRECT | — (X is the base the spell pipeline scales, like every spell's number) | — | test_wiring_cards_b.gd::Energy Ball deals X = Absorb Essence's total (as a spell) / Energy Ball is erased after use |
| Energy Barrier (`energy_barrier`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Energy Barrier: gain 5 armor / Erase 1: gone at the next erase tick |
| Escape and bewilder (`escape_and_bewilder`) | card | FIXED | The blink went to wherever the cursor was when the card resolved (tick 1 of 2), not the tile clicked — so it could also land past the 5-space cap checked at click time. | Shared: `_resolve_queued_card` hands the play's aimed tile to `_apply_card_world_effects`, which uses it for point cards (`_resolving_aim_world`). | test_wiring_cards_b.gd::Escape and bewilder blinks up to 5 spaces to the aimed tile / an enemy within 3 of the vacated tile is stunned for 3 tempo |
| Exacerbate Wounds (`exacerbate_wounds`) | card | FIXED | A card thrown away by Discard did not count (see Discard). | Fixed in `Card._execute_discard`. | test_wiring_cards_b.gd::Exacerbate Wounds deals 3 x 2 discards through the STR pipeline |
| Exhausted Assault (`exhausted_assault`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Exhausted Assault deals 4 damage 3 times / Glut 10 after it resolves / at zero mana it costs 0 mana |
| Exposed Artery (`exposed_artery`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Exposed Artery deals 0.5 x 60% missing = 30 |
| Exposing Strike (`exposing_strike`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Exposing Strike: 10 damage and 1 Vulnerable |
| Feed into the Pain (`feed_into_the_pain`) | card | CORRECT | — | — | test_wiring_cards_b.gd::a hit below 30% health fires it / Strengthen 20 for 4 attacks / 25 temp HP for 5 tempo |
| Fire Punch (`fire_punch`) | card | CORRECT | — | — | test_wiring_cards_b.gd::a path of fire behind the target / a copy with Erase 5 lands in hand / the copy does not copy itself |
| Fireball (`fireball`) | card | FIXED | Resolving on tick 6, the blast centred on wherever the cursor had moved by then, not the aimed tile (range cap bypassable too). | Same shared aim fix as Escape and bewilder. | test_wiring_cards_b.gd::Fireball: 12 damage and 3 burn where it was aimed / the 4-square circle catches an enemy 2 from the centre / 1 less mana (10 on the x10 scale) per other fire spell this cycle |
| Fleet Etching (`fleet_etching`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Fleet Etching: Haste 1 for the next 2 moves (refusal unslotted: test_engrave.gd) |
| Forever Armor (`forever_armor`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Maintain: +6 max unerring armor |
| Fortify Alliance (`fortify_alliance`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Fortify Alliance heals the ally for 5 / and gives the caster 5 armor |
| Fountain of Health (`fountain_of_life`) | card | CORRECT | — | — | test_wiring_cards_b.gd::every cycle: 2 damage to self / and a card drawn |
| Friendship (`friendship`) | card | FIXED + FLAGGED | *(Phase 6 re-check)* Picking a summon as the first ally made the caster the first ally instead. | A summon pick is refused, nothing spent. FLAGGED: summons have no PlayerStats, so can a summon be linked? In solo with no partner the card has no second ally. | test_recheck_fixes.gd::Cryonics / Friendship on a summon; test_wiring_cards_b.gd::when one heals, both heal / damage is split / the bond lasts 5 tempo |
| From the Ashes (`from_the_ashes`) | card | CORRECT | — | — | test_wiring_cards_b.gd::enemies within 3 take 5 per stack purged / heal 5 per stack / Regen equal to half the stacks |
| Energy (`gain_mana`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Energy: gain 2 mana (20 on the x10 scale) |
| Gargle and Spit (`gargle_and_spit`) | card | CORRECT | — | — | test_wiring_cards_b.gd::heal 3 / +1 strength for 20 tempo / after the 4th play it is discarded |
| Gift from the Gods (`gift_from_the_gods`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Gain 3 Enlightened (10% crit chance) |
| Gift from the Phoenix (`gift_from_the_phoenix`) | card | FIXED | "Heal up to 80%" healed the gap to 80% and then `heal()` added the INT / healing-gear bonus on top, landing above 80%. | `main._on_player_health_changed` passes the base that lands exactly on 80% once the bonus is added. | test_wiring_cards_b.gd::heal up to 80% — not past it / 5 burn on the nearest enemy |
| Give In (`give_in`) | card | CORRECT | — | — | test_wiring_cards_b.gd::immediately gain 3 mana (30) / the next tempo-triggered draw does not happen |
| God of Thunder (`god_of_thunder`) | card | CORRECT | — | — | test_wiring_cards_b.gd::absorbs all shock within a diameter of 8 of the target / the bolt deals the shock absorbed |
| Grounding (`grounding`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Grounding costs 200 - 5 per Shock in reach / 10 damage to each enemy in the radius, shocked or not |
| Gulped Potion (`gulped_potion`) | card | CORRECT | — | — | test_wiring_cards_b.gd::heal 1 / gone after the 3rd play |
| Halo (`halo`) | card | FIXED | "Heal all allies … radius of 3" skipped summons, which the game counts as allies (Healthy Bliss heals them). | `main._process_maintained_card_effects` also heals every summon within 3. | test_wiring_cards_b.gd::summons inside the radius are allies too / an ally 5 squares away is outside the circle |
| Hard Helmet (`hard_helmet`) | card | FIXED | The 2 damage went to the triggering utility card's enemy target when it had one, not "the closest enemy". | `_fire_instant_site_effect` "hard_helmet" always picks `_get_nearest_enemy()`. | test_wiring_cards_b.gd::2 damage to the closest enemy / gain 8 armor |
| Harden (`harden`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Harden: 10 armor / 10% physical resistance for 15 tempo |
| Harness Lightning (`harness_lightning`) | card | CORRECT | — | — | test_wiring_cards_b.gd::an orb that strikes every 5 tempo for 30 tempo / 4 (INT-scaled) to an enemy within 3 each strike |
| Heal (`heal`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Heal: restore 4 HP |
| Healing Potion (`healing_potion`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Healing Potion: heal 5 |
| Healing Tonic (`healing_tonic`) | card | CORRECT | — | — | test_wiring_cards_b.gd::Healing Tonic heals the ally for 5 / an ally 6 squares away is not |
| Healthy Bliss (`healthy_bliss`) | card | FIXED | The INT / healing bonus was applied twice: the sweep pre-boosted the 10, then `heal()` boosted it again. | `main._healthy_bliss_sweep` passes the base (after Blood Libation) to `heal()`, which adds the bonus once; summons get the boosted amount as before. | test_wiring_cards_b.gd::heals you for 10 / after 20 tempo in hand it fires |
| Healthy Habit (`healthy_habit`) | card | CORRECT | — | — | test_wiring_cards_b.gd::draw 2 cards / gain 2 mana (20) / Burden: the next play costs more |
| Heavy Greedy Cheese (`heavy_greedy_cheese`) | card | CORRECT | — | — | test_wiring_cards_b.gd::with the Cheese in hand another card costs +100 mana and +2 tempo / the Cheese itself: 25% of max mana and 5 tempo |

Every playable card above also has a `… costs X mana / Y tempo` check in the
same file; each matched the `.tres` (Exhausted Assault: 0 mana at zero mana;
Grounding: 200 − 5 per Shock in reach; Fireball: −10 per other fire spell;
Heavy Greedy Cheese: 25% of max mana).

## Flagged

- **Element Pollination** — (1) "your Shock freezes at 5 stacks like Cold":
  the code gives a 5-tempo *Stun* (an earlier pass chose this,
  `test_card_item_audit.gd` asserts it). Should it be Cold's *Frozen*
  instead, which shows as Frozen and counts as Cold for anything that reads
  it? (2) "your Burn also splashes nearby enemies like Shock": Shock arcs
  its tick to the *one* nearest enemy, while the pollinated Burn hits
  *every* enemy within 2.5. Should Burn's splash copy Shock's single arc?

## Notes for other slices

- **Shared code touched**:
  - `main._apply_card_world_effects` / `_resolve_queued_card`: every
    point-targeted card (`"point" in target_types`) now resolves on the
    tile it was aimed at (`_resolving_aim_world`, from the play's
    `aim_world`) instead of the live cursor. This affects every point card,
    not only this slice's (Shift, Smoke Bomb, Terrain Formation, Wrath of
    the Sea, Peshtigo's Kiss, Sprinkle Bomb, Poison Bomb …). When no aim
    was recorded (tests, the sim) the cursor is still used.
  - `Card._execute_discard` now calls `DeckManager.discard_card_from_hand`.
  - `main._healthy_bliss_sweep` and `main._process_maintained_card_effects`
    (Halo's block).
- **Reposition** (`card._execute_reposition`, not in this slice) moves its
  discard by hand like Discard did and also skips `true_discards_this_cycle`.
- Engine-wide, not a card bug: a timed status a card applies on its
  resolving tick loses one tempo on that same tick (Escape and bewilder's
  3-tempo stun shows 2 right after it lands; Gargle and Spit's 20-tempo
  Might shows 19).
