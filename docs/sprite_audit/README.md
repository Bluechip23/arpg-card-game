# Sprite cut audit (2026-11-05)

**Result: none of the 2,367 cut frames passes (0 of 225 animations).** Every frame is
resampled, so every frame fails the 1:1 scale check and the "no new colours" check.
Step 2 (re-cut everything) is **on hold for a decision**: the hard rules can be met
frame by frame (the skeleton pilot below passes every check), but for 30 of the 83
characters the designer's boards draw the same character at different sizes, and only
resampling can reconcile that. The brief says to stop and ask before any rescale.

Files here:

| file | what |
|---|---|
| `before/frames.csv` | one row per frame of the current pixel sheets: canvas, bbox, matched board, sx/sy, exact-1:1 share, new-colour pixels, semi-alpha, foot line and its drift, edges touched, failure causes |
| `before/summary.md` | one line per animation (verdict and causes), board drawing scale per character, weak matches |
| `smooth_alpha.md` | the soft-edged `generated/smooth/` sheets, which are what the game actually draws |
| `pilot_skeleton/` | the skeleton re-cut under the hard rules: sheets, manifest, its audit (all pass), contact sheets (4× and 1×), GIFs per animation and facing (1× and 4×) |

Tools: `tools/audit_sprite_cuts.py` (the audit), `tools/recut_sprites.py` +
`tools/recut_config.json` (the re-cut, one config, one code path),
`tools/audit_smooth_alpha.py`.

## Which folder is the source

The brief names `generated/heroes` and `generated/sheets` as the sources and
`paintings/` as the cuts. In the repo it is the other way round: `paintings/` holds the
designer's boards, and the cutters (`tools/cut_pose_boards.py`,
`cut_creature_sheets.py`, `cut_hero_sprites.py`, `cut_hero_actions.py`) write the cut
sheets into `generated/`. The audit treats `paintings/` as the source and
`generated/` as the cuts.

## How each frame was measured

Each frame is matched back to the board it came from: the candidate boards are read
from the cutters' own configs, and each frame's opaque pixels are searched for on them
by masked normalised cross-correlation over scales 0.95–8.5 (and mirrored), then
refined to 0.4% in scale and aspect. Then:

- **scale**: passes only if every opaque pixel equals the board pixel at an integer
  offset (an exact crop). sx/sy are reported either way.
- **blur/colour**: opaque pixels whose RGB appears nowhere in the matched board region.
- **semi-alpha**: pixels with 0 < alpha < 255, against the board region's own (the
  boards are RGB, so the source count is 0).
- **anchor**: the frame's foot line (lowest opaque row) compared with what its board
  draws: within one board row, how far above the row's lowest foot the frame's feet sit
  in the source, against the same in the cut. More than 1.5 px apart fails.
- **clipping**: opaque pixels on the canvas edge.
- **canvas**: more than one canvas size across a character's animations.

## What failed, and why

| cause | frames | why (from the cutters' code) |
|---|---|---|
| scale | 2,366 | Every cutter shrinks the board: enemies by a non-integer box filter (`shrink()`, factors like 202/114), heroes by Lanczos. Measured board-px per output-px: 0.88 to 9.25, median 1.86. |
| blur/colour | 2,366 | The shrink averages pixels; the heroes also get a saturation push (`VIBRANCE` 1.12), a 96-colour palette tidy and a 1.12× horizontal stretch (`WIDEN`). New-colour pixels a frame: median 3,199 (10th–90th percentile 1,596–6,014). |
| clipping | 1,226 | **Bottom edge only**, in every case: the feet sit on the cell's last row (packed with no air under them). No frame touches a side or the top. |
| canvas | 564 | Heroes only: each hero's walk, attack and block sheets use different cell sizes (Brad: 104, 128 and 176 px). Every enemy uses one cell size. |
| anchor | 353 | Frames whose feet sit higher or lower in the cut than the source draws them: per-frame rescaling (`frame_scale` in `cut_hero_actions.py`; `MATCH_HEIGHT`, `WALK_SQUEEZE` in `cut_hero_sprites.py`; actions "scaled so one named pose stands as tall as its Idle") moves the feet. Worst: sabertooth 47, ash harpy 46, rat king 38, mind eater 26. |
| unmatched | 1 | One ash harpy Vortex frame found on no board. |

No pixel sheet has a semi-transparent pixel (they use on/off alpha).

**The game does not draw these pixel sheets.** `ArtStyle.SMOOTH` is `true`
(`scripts/core/art_style.gd`, designer's call 2026-10-25), so the game loads
`generated/smooth/`: Lanczos-resampled, soft alpha, edge colour bled outward, imported
with mipmaps on, drawn with `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`
(`sprite_enemy_figure.gd`, `sprite_figure.gd`). All 225 smooth sheets have
semi-transparent pixels (14.4 M of them, 28.9% of the figures' pixels;
`smooth_alpha.md`). That alone blurs every figure in-engine, whatever the PNGs hold.
With `SMOOTH = false` the game draws the pixel sheets with `TEXTURE_FILTER_NEAREST`, and
their imports already have mipmaps off.

### "Shrunk" and "enlarged" characters

The size jumps come from the cutters fitting poses to a target height one at a time
(`MATCH_HEIGHT` for Ryan and Brad, Brad's and others' per-frame `frame_scale`, each
action facing matched to its Idle height). The measured sx/sy ranges show it, e.g. Brad's
walk sheet spans sy 1.83–3.74 and his attack 1.44–1.74.

## Why the re-cut is on hold

1. **The boards are not pixel art.** Inside the figures, 0% of neighbouring pixels are
   identical and a figure has 8,000–25,000 distinct colours. The only periodicity is the
   8-px WebP/JPEG compression block. There is no pixel grid, so an integer
   nearest-neighbour shrink cannot recover clean pixel art. It would just drop rows
   and columns.
2. **A 1:1 crop is 2–6× larger than today's cuts.** Cut 1:1, the front idle poses
   stand 178–1,141 px tall (median 468) whatever the creature's size in the world: the
   treasure bunny and the granite colossus both come out ~415 px tall. The game would have to draw each
   character at a new world scale (`pixel_size` / the `scale` entries). The PNGs stay
   untouched, but the GPU then shrinks them 2–6× at draw time, which is the
   skipped-rows crunch the 2026-10-25 notes describe if filtering is Nearest.
3. **30 characters' boards disagree on scale.** One board draws them bigger than
   another (largest ÷ smallest board scale): magma spider 4.47, Ryan 4.21, snow wraith
   3.46, hydra_5 3.25, hydra_8 3.16, rat king 3.10, ash harpy 3.07, armored troll 3.00,
   mind eater 2.82, battle turtle 2.78, sewer cobra 2.77, sludge 2.66, grave titan 2.63,
   succubus 2.57, mini bear 2.55, Brad 2.39, werewolf 2.38, wererat 2.36, Stephen 2.30,
   Jeremy 2.23, Cory 2.18, skeleton 2.09, coyote 2.07, hydra 2.07, djinn 2.05, archer rat
   2.03, zombie 1.89, sabertooth 1.46, wolf 1.42, hydra_3 1.29. Cut 1:1, each of these
   changes size between animations. Rule 1 allows only one integer factor applied to
   every frame of a character, so these spreads cannot be fixed under it.
   The other 53 characters draw every animation from one board, so their scale is
   consistent at 1:1.

### The pilot: the skeleton under the hard rules

`pilot_skeleton/` was cut by `tools/recut_sprites.py`: pure crops, hard alpha from the
existing model mattes (Idle/Walk) or a brightness key on black (Attack), one canvas
(500×434) for every frame, feet on the board row's ground line, and a 2 px clear margin.
Its audit (`pilot_skeleton/audit/summary.md`) passes every frame: exact 1:1,
0 new colours, 0 semi-transparent pixels, no anchor drift, nothing on the edge. The
contact sheet still shows the problem: he is ~415 px tall standing and ~200 px tall
attacking, because his slash board draws him at half the size of his pose board. The
audit's checks cannot catch this, since each frame is a perfect crop of its own board.

## Ambiguities (listed, not decided)

- **Weak matches** (`before/summary.md`, last table; score < 0.85): sabertooth
  Sunken (20 frames, best only 0.30–0.49 on any board, so its source cells are
  unclear), rat king Cast (18, best match is on the bite board, not the infest board),
  ash harpy Vortex, snow wraith strips, ring wraith (0.27–0.78), the treasure bunny's
  smoke, and a few single frames. These cuts differ so much from any board region
  (recoloured effects, faded glows, composited pieces) that the source cell cannot be
  pinned down by measurement.
- **Board row labels** are wrong on several boards (the cutters' comments note
  "walking left" rows that face right, NORTH labelling the front view). The pilot uses
  the cutters' facing assignments.
- **Horizontal anchor**: the boards place each pose in its own loose cell with no shared
  x reference, so the pilot anchors x on the centre of each frame's lowest 4 opaque rows
  (the feet). A lunge that moves the feet in the source shows as a shift of the body.
- **Mirrored facings** (a left made by flipping the right) are a pixel permutation,
  not a resample. The pilot doesn't use any.
- **Preview GIFs** are limited to 256 colours, so they are quantised for viewing. The
  PNGs are exact.
