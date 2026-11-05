# Sprite cut audit

One line per animation. A frame passes only with every check clean.
Causes: `scale` = not an exact 1:1 crop of the source; `blur/colour` = colours not in the
source region (resampling, palette tidy, recolouring); `semi-alpha` = more semi-transparent
pixels than the source region; `anchor` = foot line moves where the source's does not;
`clipping` = opaque pixels on the canvas edge; `canvas` = the character's frames use more
than one canvas size; `unmatched` = no source board found.
**3 animations pass, 0 fail; 24 frames pass, 0 fail.**


| character | animation | frames | failing | causes (frames) | sx range | sy range | canvases | edges touched |
|---|---|---|---|---|---|---|---|---|
| skeleton | Attack | 16 | 0 | PASS | 1.00-1.00 | 1.00-1.00 | 500x434 | - |
| skeleton | Idle | 4 | 0 | PASS | 1.00-1.00 | 1.00-1.00 | 500x434 | - |
| skeleton | Walk | 4 | 0 | PASS | 1.00-1.00 | 1.00-1.00 | 500x434 | - |

## Source drawing scale per character

Median source px per output px (sy) for each animation's board, and the spread
(largest / smallest). The old cuts hold each character near one on-screen size, so a
spread above 1 is how much bigger one board draws the character than another: a 1:1
crop of both cannot show the character at one size.

| character | (animation: board sy) | board-scale spread |
|---|---|---|
| skeleton | Attack: skeleton_slash_board.webp 1.00; Idle: skeleton_board.webp 1.00; Walk: skeleton_board.webp 1.00 | 1.00 |
