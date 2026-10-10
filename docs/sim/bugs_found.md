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

## Open (not changed)

- **`tests/_build_sims.gd` spelled Ryan's passive `lets_dance`; the game's
  id is `let's_dance`** (the tree lowercases "Let's Dance" and keeps the
  apostrophe). Fixed in the scratch simulator at the designer's request. Candidates to watch: `Enemy.damaged` reports overkill (the
  amount applied to health is not clamped before the signal), which only
  matters for anything summing damage from that signal — the harness does
  and says so in its column notes.

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
