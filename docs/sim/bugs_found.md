# Bugs found while building the simulation harness

Actual bugs (not balance), each with a repro. Fixed ones say so.

## Fixed with the designer's sign-off

- **Defensive Sacrifice never offered under headless boots.** `enemy.gd`
  reached `Main` through `get_tree().current_scene`, which is null when the
  scene is instantiated under a `--script` test (every test and the sim), so
  the Abjurers Cane reaction was silently skipped there while every other
  enemy → main lookup uses `get_parent()`. Changed to `get_parent()` (M1).
## Not a bug after all

- **Wisdom and the draw timer.** Every stat text says the auto draw is a
  flat 25 tempo and the code agrees; only one sphere-grid tooltip
  (`sphere_grid_ui.gd:1069`, "faster card draw") says otherwise. A WIS
  scaling was added and then reverted at the designer's request: the flat
  25 is the rule, the tooltip is the stale line.

## Harness bugs found by the sweeps (fixed)

- **Refused plays stalled fights.** The lookahead could keep choosing a
  card the game refused (Heavy Swing without an all-offensive hand, Lead
  Arrow without high ground); three refusals forced a wait, and the fight
  idled to a timeout. The state now mirrors Heavy Swing's gate and drops
  any refused play from the legal actions for the rest of the tempo. The
  ranged ambusher's level-18 table was the visible casualty (0.83 → 1.00
  against the Earth Mage, Large Bear and Bugbear after the fix).
- **A picker could be answered twice in one frame.** A pressed picker
  frees itself deferred, so the next pass of the prompt answerer in the
  same frame found and pressed it again. Pickers are renamed once answered.

- **The same seed drifted between processes.** Enemy rolls and chance
  cards use the global RNG, and timer-driven code consumes it a frame at a
  time, so the number of draws before a Treant's slam-or-root roll depended
  on CPU load; 1–4 seeds in 30 differed between two identical runs. The
  runner now re-seeds from (run seed, global tempo, step) before every
  decision and tick; three concurrent processes produce byte-identical
  run files.

- **Eight cards were never played by the policy.** Sky Attack, Mirror
  Mirror, Collect Arrows, Friendship, Release Tension, Crack of Mintaka,
  Life Swap and Communal Donation were held out of the legal actions as
  "needs a pick", so the single-card sweep scored each as a dead card (all
  eight had identical numbers on every build). They are now playable: the
  runner answers their pickers and the lookahead values and picks for Sky
  Attack, Mirror Mirror, Collect Arrows and Release Tension.

- **Overkill was counted as damage dealt.** `Enemy.damaged` reports the
  whole hit after clamping health at 0, and the runner summed it, so a
  killing blow was credited with damage past zero. Burst and area cards
  were inflated most (If Pigs Could Fly read 168 damage per tempo against
  a pack with 116 total health). The killing hit now counts only the
  health it removed; the excess goes to a separate `overkill` column.
  Win rates were never affected; damage-per-tempo figures were re-run.

## Open (not changed)

- **`tests/_build_sims.gd` spelled Ryan's passive `lets_dance`; the game's
  id is `let's_dance`** (the tree lowercases "Let's Dance" and keeps the
  apostrophe). Fixed in the scratch simulator at the designer's request. (`Enemy.damaged` reporting overkill is handled in the harness; see the
  fixed list above.)

- **Shadow Cowl's on-self bonus can never fire.** The cowl's "+2 damage
  and 2 free tiles for offensive cards" is an `on_self_*` bonus, and
  `Card.get_on_self_bonus()` (card.gd:728) only ever reads the item the
  card is *engraved in*. A chest piece takes Bulwark cards, and none of the
  ten Bulwark-slot cards (approach, armor_patch, best_offense, harden,
  hold_the_line, hunker_down, roar, shield_of_growth, smith_thy_soul,
  turtle_up) is offensive, so no card can collect it. Found by the compare
  tool: raising the bonus from 2 to 6 changed 0 of 90 shadow-blade runs.
  The same applies to every chest piece with an offensive on-self line:
  Elvish Cloak (+2 ranged), Chewbacca's Bandolier (+5 ranged, −1 ranged
  tempo) and Tigers Sunday Red (heal on offensive cards) all read through
  the same path and hold only Bulwark cards. Either these want a
  stat-style bonus (every offensive card you play) or a Bulwark card that
  counts as offensive. Not changed.

- **Shop flags on item-granted and conjured cards.** The sim's card pool
  follows the game's own flags (`requires_engraving`, `shop_excluded`),
  per the rule that cards are universal unless a passive names them. Two
  kinds of card are not flagged and so count as dealer-buyable: cards an
  item grants (Wrath of the Sea from Poseidon's Trident, Hemotoxins from
  the Alchemist Belt, Resourceful Replenish from Hannibal's Mask) and
  conjured tokens (Energy Ball from Absorb Essence). If any of these are
  meant to come only with their item or spell, they want `shop_excluded`
  — the sweeps will otherwise swap them into decks as ordinary cards.

- **Five tree passives never write to the battle log**: Brad's Directed
  Strength and Life Steal, Jeremy's Harnessed Power and Blood Libation,
  Cory's Wither. They work, but neither the player's log nor the sim's
  trigger count can see them fire; their `passive_triggers` entry reads
  `-` (not observable) instead of 0. A one-line `add_battle_log` in each
  would make them countable. Way of the Plate logs as "Way of the Plate"
  under the id `the_way_of_the_plate`; the sim maps the name. Not changed.
