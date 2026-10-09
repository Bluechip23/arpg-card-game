# Bugs found while building the simulation harness

Actual bugs (not balance), each with a repro. Fixed ones say so.

## Fixed with the designer's sign-off

- **Defensive Sacrifice never offered under headless boots.** `enemy.gd`
  reached `Main` through `get_tree().current_scene`, which is null when the
  scene is instantiated under a `--script` test (every test and the sim), so
  the Abjurers Cane reaction was silently skipped there while every other
  enemy → main lookup uses `get_parent()`. Changed to `get_parent()` (M1).
- **Wisdom's draw speed-up was missing.** Every stat explanation said the
  auto draw stays a flat 25 tempo and `get_effective_draw_timer` ignored WIS,
  while the sphere grid still advertised "faster card draw". Per the
  designer: WIS now shortens the interval (`PlayerStats.DRAW_TEMPO_PER_WIS`
  = 0.5 tempo per point, floor `MIN_DRAW_TEMPO` = 10); the README, the
  in-game stat text and the keyword legend say so. `tests/test_wis_draw_timer.gd`.

## Open (not changed)

- None yet. Candidates to watch: `Enemy.damaged` reports overkill (the
  amount applied to health is not clamped before the signal), which only
  matters for anything summing damage from that signal — the harness does
  and says so in its column notes.
