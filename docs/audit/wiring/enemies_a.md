# Wiring audit: enemies_a

Phase 2, slice `enemies_a` (37 enemy types). The source of truth is the compendium text in
`Enemy.get_all_enemy_data` (`_specials` and `_actions`). It was checked against `actions_for_type`, the
per-type chooser, the executors in `_run_action`, the passives in `on_tempo_advanced` / `take_damage` / `die`,
and the base numbers in `EnemyDefs`.

All checks are in `tests/test_wiring_enemies_a.gd`. It boots the dojo and runs the real choosers and
executors. It reports 304 PASS and 0 failures in under a minute.

How the checks are built:
- **Tables.** For every type, the check `<TYPE>: compendium actions and tempo match actions_for_type`
  compares the action count and each tempo. The checks `<TYPE>: Move covers N spaces` and `<TYPE>: range N`
  compare move spaces and range.
- **Damage.** The compendium quotes base numbers. Under each scaled entry it says the game multiplies them
  by `passive_power_scale`, so each expected hit is the base number scaled the same way. Hits are measured
  through the `hit_landed` signal.

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| Minion | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::MINION: Attack hits for its damage (3) |
| Elite | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::ELITE: Attack hits for its damage (5) |
| Boss | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::BOSS: Attack hits for its damage (11) |
| Wererat | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Wererat: Scurry dashes 5 tiles toward you (8 -> 3) |
| Skeleton | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Skeleton: Attack hits for 6 (scaled) |
| Armored Troll | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Troll: Smash adds a Lightly Dazed card (also regen, 30/15/15 resists, ~60% Smash, Kick 6) |
| Archer Rat | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Archer Rat: at range 6 it shoots (range 6 is the designer's 2026-10-21 call; `ENEMY_SHEET.tsv` still says 4) |
| Hydra | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Hydra: the 4th hit gives +40 max HP and unlocks Heal; heads: test_hydra_heads.gd; 190 HP and non-player hits: test_sheet_act1b.gd |
| Fire Goblin Soldier | enemy | FLAGGED | Text says "Range 0". The code gives it melee reach (adjacent), like every melee enemy. | — | test_wiring_enemies_a.gd::Goblin Soldier: Attack hits for 2 |
| Fire Goblin Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Goblin Mage: Ember adds 1 Burn |
| Fire Goblin Shaman | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Goblin Shaman: walking into the wall burns you (6 + 3 Burn); …::Goblin Shaman: 8 damage while channeling breaks the Fire Wall; …::Goblin Shaman: Sear Wounds can kill |
| Giant Beaver | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Beaver: Tail Whip lays 5 Vulnerable stacks (5 tempo each) |
| Mini Bear | enemy | FLAGGED | Text: "+2 attack damage when a packmate in sight is hurt". The code counts only the player's own hits (`from_player`). DoT ticks, summons and allies' hits give nothing. | — | test_wiring_enemies_a.gd::Mini Bear: a packmate in sight hurt: +2 attack damage |
| Large Bear | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Large Bear: raging, attacks deal 1.5x (24); …::Large Bear: the resistance stays after healing above 50% (forever); …::Large Bear: Roar leaves everything within 4 squares Vulnerable |
| Wolf | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Wolf: and +2 HP regen a cycle |
| Coyote | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Coyote: Nip hits for 2 |
| Bugbear | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Bugbear: First Strike — +8 before you have hit it |
| Infected Hunter | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Hunter: Hook reaches range 7; Cleave rows, Net Throw and Hook recharge: test_sheet_act1b.gd |
| Giant Hawk | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Hawk: the high-ground check never favours you against it |
| Treant | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Treant: and heals for the total (7 thorns + 2 regen ticks); …::Treant: Root pins you for 8 tempo |
| Ice Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Ice Mage: Frost Bolt Slows; totem: test_totems.gd |
| Fire Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Fire Mage: Fire Bolt adds 2 Burn; totem: test_totems.gd |
| Spark Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Spark Mage: Spark adds 1 Shock; totem: test_totems.gd |
| Air Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::AIR_MAGE: gust hits for 5 (scaled); totem: test_totems.gd |
| Earth Mage | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Earth Mage: gains 4 armor every time it is hit; totem: test_totems.gd |
| Zombie | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Zombie: 3 spaces a shamble |
| Werewolf | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Werewolf: a debuffed target is raked a second time for half (16); …::Werewolf: +3 vs armor |
| Treasure Bunny | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Bunny: after 3 cycles (15 tempo) it vanishes; the smoke and no loot: test_treasure_bunny_vanish.gd |
| Vampire | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Vampire: the first Absorb drains 20 (scaled 21); …::Vampire: no charges back — no third Bat Form |
| Necromancer | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Necromancer: Bolt Hexes 2 cards (+30 mana, up to 25 tempo); Raise the Fallen: test_necromancer_rise.gd |
| Bone Dragon | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Bone Dragon: a Swarm hatches beside the one it hit; …::Bone Dragon: 1 health a cycle per standing gravestone (3 stones) |
| Spirit Collector | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Collector: its Strengthen never fades; Release Soul: test_sheet_act1b.gd; range casting: test_enemy_ranged_in_range.gd |
| Grave Titan | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Titan: Boulder Roll hits for 15 (scaled) |
| Crypt Crawler | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Crawler: after 3 consecutive attacks it webs you; floor webs: test_enemy_ranged_in_range.gd |
| Screecher | enemy | FLAGGED | Behaviour matches. The move is named twice: "Drift" in the action list, "Scuttle" in the prose. | — | test_wiring_enemies_a.gd::Screecher: while seen, 2 spaces for 5 tempo; …::Screecher: unseen, your direct attack finds nothing |
| The Consumed | enemy | FIXED | Text: "On death: explodes for 8 damage to everything nearby". The burst hit only `main.player` and enemies, never the player's summons (or a co-op second player). | `_consumed_explode` now hits every player-side unit (`_player_units()`) within the blast. | test_wiring_enemies_a.gd::Consumed: and on a summon beside it — everything nearby |
| Sludge | enemy | CORRECT | — | — | test_wiring_enemies_a.gd::Sludge: at range 6 it Spits |

**Counts:** 33 CORRECT, 1 FIXED, 0 MISSING, 3 FLAGGED.

## Flagged

- **Fire Goblin Soldier:** the compendium says "Range 0". The soldier attacks a player on an adjacent square,
  like every melee enemy. Should the text read "Melee" (or "Range 1"), or should it really have no reach?
- **Mini Bear:** "When a packmate in sight is hurt, gains +2 attack damage." The code grants the +2 only when
  the player's own hit lands on the packmate. Should burn and poison ticks, summons' hits and allies' hits
  (Sear Wounds) also feed the pack bonus? The Large Bear's "every time it is hurt" counts any source. Note
  that any-source would stack +2 on every DoT tick, so this is a balance call.
- **Screecher:** the action list calls the move "Drift" and the prose calls it "Scuttle". The behaviour is
  the same either way (4 spaces / 2 tempo unseen, 2 / 5 seen). Which name stands? No rename was made, per
  the audit rules.

## Notes (not flagged)

- The riders written as fixed numbers (Kick 6, Smash 14, Tail Whip 6, Death Burst 8, Absorb 20/10) scale
  with `passive_power_scale`, as the compendium's band note says. The +N bonuses do not scale: Bugbear +8,
  Wolf +2, Mini Bear +2 and Werewolf +3.
- `docs/ENEMY_SHEET.tsv` still gives the Archer Rat range 4. The compendium and code say 6, which the designer
  set on 2026-10-21 (`ENEMY_AUDIT.md`).
