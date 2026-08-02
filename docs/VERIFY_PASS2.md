# Verification Pass 2 — Aesthetic

Scored from the regenerated `docs/screens/*.png` (viewed, not inferred from
code) plus measured data. Fix round applied mid-pass: chest re-palette +
texture, waypoint discs to palette tints, guard squash → hard crouch, void
backdrop → dark olive, out-of-bounds ground lightened. Scores below are
post-fix; sub-4 items that remain are hand-art or the deferred UI milestone,
logged in `docs/ART_TODO.md` per the scope boundary (no faked art).

## 1. Ramp quality — **4/5**
Measured HSV of the five canonical ramps (`tools` one-liner, values in
STYLE_GUIDE §2):
- Leather: H 22.5° → 19.6° → 28° → **270.7°** (core dives into violet) ✔
- Foliage: H 114.8° → 160° → 120° → **180°** (teal shadow) ✔
- Steel: H 189° → 180° → 212.7° → 213.7°, S 0.05 → 0.49 (blue-shifted, saturating) ✔
- Cloth: H 231.9° → 240° → 211.4° → **253.3°** ✔
- Skin: H 35° → 23° → 26° → 28° — the smallest drift (warm throughout);
  acceptable because it is the reference pack's own skin ramp (authoritative),
  but it is the weakest of the five.
No ramp is constant-hue. PASS.

## 2. Light coherence — **4/5**
`battle_brad.png`: cliff/wall top faces brightest, south faces mid, east
faces darkest — consistent across all six+ terrain masses; chest lid catches
the same top-left bias; every sprite (knight, skeleton, bear, wolf, mages)
is painted with the packs' top/upper-left convention; select cards and sheet
portrait now share the same key. No object disagrees. The remaining point is
withheld because box geometry has only 3 visible face angles — coherent but
coarse compared to painted tiles.

## 3. Shadow consistency — **5/5**
All contact shadows are the same language: hard two-step ellipse, 38%/20%
black, no gradients (blob quads under knight/skeleton/bear/wolf/slime;
painted ellipses under the flyers match shape and hardness). No engine
shadows remain.

## 4. Figure/ground separation — **4/5**
Greyscale squint test (`battle_*.png` desaturated): skeleton, knight,
slime, bear, mages all separate cleanly; floor sits mid-value as specced.
Wolf/coyote are the closest calls (mid-brown on mid-olive) but their dark
outlines hold the read. Environment ramps stay lower-contrast than sprites.

## 5. Tiling repetition — **4/5**
With 4×4 variant sheets the rock walls show varied seam layouts and the
grass speckle has a 4-tile period — no visible 16px grid at gameplay zoom.
A faint 4-tile cadence is still detectable on very large uniform walls;
more variants (or a second 128px sheet) would clear it fully.

## 6. Color harmony — **4/5**
Post-fix the frame reads as one world: olive/tan terrain, steel/leather
sprites, palette-tinted waypoints, wood-and-gold chest. Remaining chromatic
outliers are *reference-pack* accents (treant's pink bloom, merchant red) —
the palette source itself, so accepted.

## 7. Outline discipline — **5/5**
Programmatic scan of every generated asset: zero pure `#000000` pixels; all
outlines are the packs' hue-shifted darks. (Reference art exempt but scans
clean of pure black too, aside from designed obsidian `#181818` fills.)

## 8. Motion feel — **4/5**
Stepped 5.5–7.5 fps walks, pack-canonical attack timing, hard two-frame
flashes, translation-only body motion, no off-axis rotation, guard is a
hard crouch snap. The one modern remnant: Tween-eased *positional* lunges
(enemy attacks) use ease curves; they read fine at 360p but a 2-step
snap would be purer — logged as a polish candidate, not a defect.

## 9. Overall likeness — **3/5** (blocked on hand art / deferred scope)
Side-by-side with the Mana Seed reference, the three biggest remaining gaps:
1. **Props are still geometry.** Crates, rocks, shrubs, pipes, stalagmites
   are colored boxes with at best a tile texture — the reference's painterly
   clutter is absent. Needs ART_TODO #6 sprites; cannot be generated.
2. **Vector overhead labels.** Enemy name/HP `Label3D`s render smooth
   full-res glyphs inside the pixel world — the single most modern-looking
   element on screen. Fix belongs to the UI milestone (bitmap font, or
   moving labels to the full-res UI layer with `world_to_screen`).
3. **Placeholder monster variants.** Tinted reuses (red-boar minotaur,
   frog goblins) are palette-coherent but silhouette-generic next to the
   reference bestiary. ART_TODO #1–3.
Both actionable-by-code fixes for this section that existed (void backdrop,
chest/waypoint conformance) were applied this pass; the rest requires art
per the scope boundary.

## Verdict
Items 1–8 ≥ 4 after the fix round. Item 9 is capped by assets that must be
hand-drawn (logged with exact specs) and by the deferred UI milestone —
re-scoring it requires those deliverables, not further code.
