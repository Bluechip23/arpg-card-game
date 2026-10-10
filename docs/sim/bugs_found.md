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
