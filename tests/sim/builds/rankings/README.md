# Card rankings for deck recipes

`<char>[_L<level>]_card_swap.csv` here is what `SimDeckBuilder` ranks
candidate cards by when it fills a deck recipe: each card's measured
uplift on each designed build from a single-card sweep. It lives in the
repo so a recipe deck is the same on every machine and does not shift
between a "before" and an "after" run. Refresh it deliberately:

```
tools/sim_analysis/run_sweep.sh tests/sim/sweeps/ryan_card_swap.txt 4
python3 tools/sim_analysis/build_matrix.py --character ryan --update-ranking
git add tests/sim/builds/rankings/ryan_card_swap.csv
```

With no file for a character and level, recipes rank by a flat
efficiency heuristic (damage + block + heal per tempo, less a mana cost).
