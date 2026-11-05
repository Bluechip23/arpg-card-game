# Sprite cut audit

One line per animation. A frame passes only with every check clean.
Causes: `scale` = not an exact 1:1 crop of the source; `blur/colour` = colours not in the
source region (resampling, palette tidy, recolouring); `semi-alpha` = more semi-transparent
pixels than the source region; `anchor` = foot line moves where the source's does not;
`clipping` = opaque pixels on the canvas edge; `canvas` = the character's frames use more
than one canvas size; `unmatched` = no source board found.
**0 animations pass, 225 fail; 0 frames pass, 2367 fail.**


| character | animation | frames | failing | causes (frames) | sx range | sy range | canvases | edges touched |
|---|---|---|---|---|---|---|---|---|
| air_mage | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.92-5.00 | 4.96-5.00 | 104x104 | B:4 |
| air_mage | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.92-5.00 | 4.96-5.00 | 104x104 | B:4 |
| archer_rat | Attack | 12 | 12 | blur/colour (12), clipping (12), scale (12) | 2.85-3.26 | 2.89-3.29 | 82x82 | B:12 |
| archer_rat | Draw | 8 | 8 | anchor (1), blur/colour (8), clipping (8), scale (8) | 2.86-3.31 | 2.92-3.32 | 82x82 | B:8 |
| archer_rat | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 6.20-6.34 | 6.12-6.36 | 82x82 | B:4 |
| archer_rat | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 6.20-6.34 | 6.12-6.36 | 82x82 | B:4 |
| armored_troll | Attack | 24 | 24 | anchor (14), blur/colour (24), clipping (2), scale (24) | 1.21-1.27 | 1.21-1.27 | 160x160 | B:2 |
| armored_troll | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.70-3.73 | 3.73-3.74 | 160x160 | B:4 |
| armored_troll | Kick | 20 | 20 | anchor (4), blur/colour (20), clipping (6), scale (20) | 1.37-1.50 | 1.37-1.49 | 160x160 | B:6 |
| armored_troll | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.70-3.73 | 3.73-3.74 | 160x160 | B:4 |
| ash_harpy | Cast | 84 | 84 | anchor (45), blur/colour (84), clipping (18), scale (84) | 1.46-1.58 | 1.45-1.57 | 119x119 | B:18 |
| ash_harpy | Idle | 4 | 4 | blur/colour (4), clipping (1), scale (4) | 4.51-4.60 | 4.55-4.57 | 119x119 | B:1 |
| ash_harpy | Vortex | 77 | 77 | blur/colour (76), scale (76), unmatched (1) | 0.85-7.15 | 0.91-7.45 | 119x119 | - |
| ash_harpy | Walk | 4 | 4 | blur/colour (4), clipping (1), scale (4) | 4.51-4.60 | 4.55-4.57 | 119x119 | B:1 |
| battle_turtle | Armor | 32 | 32 | anchor (25), blur/colour (32), clipping (32), scale (32) | 1.52-1.62 | 1.52-1.61 | 127x127 | B:32 |
| battle_turtle | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.31-4.35 | 4.31-4.38 | 127x127 | B:4 |
| battle_turtle | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.31-4.35 | 4.31-4.38 | 127x127 | B:4 |
| bone_dragon | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.07-2.07 | 2.06-2.08 | 281x281 | B:4 |
| bone_dragon | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.07-2.07 | 2.06-2.08 | 281x281 | B:4 |
| bugbear | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.99-4.04 | 4.00-4.05 | 132x132 | B:4 |
| bugbear | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.99-4.04 | 4.00-4.05 | 132x132 | B:4 |
| bull_worm | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 7.07-7.18 | 7.09-7.26 | 80x80 | B:4 |
| bull_worm | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 7.07-7.18 | 7.09-7.26 | 80x80 | B:4 |
| cerberus | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 1.60-1.61 | 1.61-1.61 | 231x231 | B:4 |
| cerberus | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 1.60-1.61 | 1.61-1.61 | 231x231 | B:4 |
| cherub | Arrow | 4 | 4 | blur/colour (4), scale (4) | 7.43-7.80 | 7.52-7.68 | 90x90 | - |
| cherub | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.57-4.61 | 4.52-4.61 | 90x90 | B:4 |
| cherub | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.57-4.61 | 4.52-4.61 | 90x90 | B:4 |
| consumed | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.62-3.65 | 3.64-3.66 | 150x150 | B:4 |
| consumed | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.62-3.65 | 3.64-3.66 | 150x150 | B:4 |
| corrupted_archangel | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.44-2.47 | 2.45-2.48 | 124x124 | B:4 |
| corrupted_archangel | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.44-2.47 | 2.45-2.48 | 124x124 | B:4 |
| coyote | Attack | 16 | 16 | anchor (2), blur/colour (16), clipping (16), scale (16) | 2.07-2.53 | 2.06-2.50 | 122x122 | B:16 |
| coyote | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.58-4.65 | 4.62-4.67 | 122x122 | B:4 |
| coyote | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.58-4.65 | 4.62-4.67 | 122x122 | B:4 |
| crypt_crawler | Idle | 4 | 4 | blur/colour (4), clipping (2), scale (4) | 5.50-5.56 | 5.53-5.63 | 109x109 | B:2 |
| crypt_crawler | Walk | 4 | 4 | blur/colour (4), clipping (2), scale (4) | 5.50-5.56 | 5.53-5.63 | 109x109 | B:2 |
| djinn | Arc | 10 | 10 | blur/colour (10), clipping (1), scale (10) | 1.43-2.28 | 1.63-2.44 | 133x133 | B:1 |
| djinn | Cast | 28 | 28 | anchor (1), blur/colour (28), clipping (22), scale (28) | 1.76-1.89 | 1.77-1.89 | 133x133 | B:22 |
| djinn | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.71-3.78 | 3.75-3.77 | 133x133 | B:4 |
| djinn | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.71-3.78 | 3.75-3.77 | 133x133 | B:4 |
| earth_mage | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.18-2.23 | 2.19-2.22 | 120x120 | B:4 |
| earth_mage | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.18-2.23 | 2.19-2.22 | 120x120 | B:4 |
| fire_goblin | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.87-5.05 | 4.95-5.01 | 99x99 | B:4 |
| fire_goblin | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.87-5.05 | 4.95-5.01 | 99x99 | B:4 |
| fire_goblin_mage | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.65-4.71 | 4.65-4.66 | 111x111 | B:4 |
| fire_goblin_mage | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.65-4.71 | 4.65-4.66 | 111x111 | B:4 |
| fire_goblin_shaman | Idle | 4 | 4 | blur/colour (4), clipping (3), scale (4) | 5.23-5.30 | 5.22-5.33 | 109x109 | B:3 |
| fire_goblin_shaman | Walk | 4 | 4 | blur/colour (4), clipping (3), scale (4) | 5.23-5.30 | 5.22-5.33 | 109x109 | B:3 |
| fire_mage | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.12-4.27 | 4.19-4.25 | 104x104 | B:4 |
| fire_mage | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.12-4.27 | 4.19-4.25 | 104x104 | B:4 |
| frankenstein | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 6.51-6.64 | 6.54-6.60 | 115x115 | B:4 |
| frankenstein | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 6.51-6.64 | 6.54-6.60 | 115x115 | B:4 |
| giant_beaver | Idle | 4 | 4 | blur/colour (4), clipping (2), scale (4) | 5.52-5.68 | 5.57-5.67 | 85x85 | B:2 |
| giant_beaver | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 5.59-5.68 | 5.49-5.75 | 85x85 | B:4 |
| giant_hawk | Idle | 4 | 4 | blur/colour (4), clipping (1), scale (4) | 5.15-5.22 | 5.11-5.17 | 123x123 | B:1 |
| giant_hawk | Walk | 4 | 4 | blur/colour (4), clipping (1), scale (4) | 5.15-5.22 | 5.11-5.17 | 123x123 | B:1 |
| granite_colossus | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.47-2.49 | 2.47-2.49 | 194x194 | B:4 |
| granite_colossus | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.47-2.49 | 2.47-2.49 | 194x194 | B:4 |
| grave_digger | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.10-4.16 | 4.15-4.17 | 133x133 | B:4 |
| grave_digger | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.10-4.16 | 4.15-4.17 | 133x133 | B:4 |
| grave_titan | Attack | 20 | 20 | anchor (14), blur/colour (20), clipping (20), scale (20) | 1.13-1.24 | 1.13-1.24 | 203x203 | B:20 |
| grave_titan | Boulder | 8 | 8 | blur/colour (8), clipping (8), scale (8) | 2.92-2.98 | 2.91-2.99 | 203x203 | B:8 |
| grave_titan | Idle | 4 | 4 | blur/colour (4), clipping (3), scale (4) | 3.11-3.16 | 3.11-3.13 | 203x203 | B:3 |
| grave_titan | Throw | 24 | 24 | anchor (5), blur/colour (24), scale (24) | 1.25-1.31 | 1.26-1.31 | 203x203 | - |
| grave_titan | Walk | 4 | 4 | blur/colour (4), clipping (3), scale (4) | 3.11-3.16 | 3.11-3.13 | 203x203 | B:3 |
| hades | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.36-2.40 | 2.38-2.40 | 124x124 | B:4 |
| hades | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.36-2.40 | 2.38-2.40 | 124x124 | B:4 |
| hell_door | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 5.94-5.94 | 5.94-5.94 | 197x197 | B:4 |
| hell_door | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 5.94-5.94 | 5.94-5.94 | 197x197 | B:4 |
| hero:brad | attack | 32 | 32 | blur/colour (32), canvas (32), scale (32) | 1.28-1.54 | 1.44-1.74 | 104x104;128x128;176x176 | - |
| hero:brad | block | 48 | 48 | blur/colour (48), canvas (48), scale (48) | 1.34-1.45 | 1.50-1.60 | 104x104;128x128;176x176 | - |
| hero:brad | walk | 36 | 36 | anchor (2), blur/colour (36), canvas (36), clipping (36), scale (36) | 1.63-3.30 | 1.83-3.74 | 104x104;128x128;176x176 | B:36 |
| hero:cory | attack | 40 | 40 | blur/colour (40), canvas (40), scale (40) | 1.60-1.66 | 1.80-1.85 | 104x104;128x128 | - |
| hero:cory | block | 32 | 32 | blur/colour (32), canvas (32), scale (32) | 1.54-1.70 | 1.78-1.92 | 104x104;128x128 | - |
| hero:cory | walk | 36 | 36 | anchor (5), blur/colour (36), canvas (36), clipping (36), scale (36) | 1.69-3.56 | 1.91-3.99 | 104x104;128x128 | B:36 |
| hero:jeremy | attack | 32 | 32 | blur/colour (32), canvas (32), scale (32) | 1.56-1.68 | 1.76-1.86 | 106x106;128x128;144x144 | - |
| hero:jeremy | block | 32 | 32 | blur/colour (32), canvas (32), scale (32) | 1.56-1.63 | 1.75-1.82 | 106x106;128x128;144x144 | - |
| hero:jeremy | walk | 36 | 36 | anchor (2), blur/colour (36), canvas (36), clipping (36), scale (36) | 1.61-3.55 | 1.82-3.99 | 106x106;128x128;144x144 | B:36 |
| hero:ryan | attack | 48 | 48 | blur/colour (48), canvas (48), scale (48) | 1.41-1.61 | 1.60-1.79 | 106x106;128x128;160x160 | - |
| hero:ryan | block | 60 | 60 | blur/colour (60), canvas (60), scale (60) | 1.17-1.26 | 1.30-1.41 | 106x106;128x128;160x160 | - |
| hero:ryan | walk | 36 | 36 | anchor (10), blur/colour (36), canvas (36), clipping (35), scale (36) | 1.89-5.15 | 1.95-5.70 | 106x106;128x128;160x160 | B:35 |
| hero:stephen | attack | 32 | 32 | blur/colour (32), canvas (32), scale (32) | 1.59-2.01 | 1.81-2.02 | 104x104;128x128 | - |
| hero:stephen | block | 28 | 28 | blur/colour (28), canvas (28), scale (28) | 1.67-2.14 | 1.86-2.03 | 104x104;128x128 | - |
| hero:stephen | walk | 36 | 36 | anchor (8), blur/colour (36), canvas (36), clipping (36), scale (36) | 2.35-3.89 | 2.69-4.36 | 104x104;128x128 | B:36 |
| hydra | Attack | 24 | 24 | blur/colour (24), clipping (23), scale (24) | 1.87-3.14 | 1.88-3.11 | 176x176 | B:23 |
| hydra | Heal | 12 | 12 | blur/colour (12), clipping (12), scale (12) | 2.29-2.32 | 2.29-2.32 | 176x176 | B:12 |
| hydra | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.90-3.98 | 3.89-3.92 | 176x176 | B:4 |
| hydra | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.90-3.98 | 3.89-3.92 | 176x176 | B:4 |
| hydra_3 | Attack | 24 | 24 | anchor (1), blur/colour (24), clipping (19), scale (24) | 1.21-1.34 | 1.21-1.35 | 173x173 | B:19 |
| hydra_3 | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 1.62-1.64 | 1.62-1.64 | 173x173 | B:4 |
| hydra_3 | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 1.62-1.64 | 1.62-1.64 | 173x173 | B:4 |
| hydra_5 | Attack | 24 | 24 | blur/colour (24), clipping (18), scale (24) | 1.25-1.44 | 1.25-1.44 | 149x149 | B:18 |
| hydra_5 | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.29-4.31 | 4.32-4.35 | 149x149 | B:4 |
| hydra_5 | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.29-4.31 | 4.32-4.35 | 149x149 | B:4 |
| hydra_8 | Attack | 24 | 24 | anchor (1), blur/colour (24), clipping (15), scale (24) | 1.30-1.35 | 1.29-1.35 | 162x162 | B:15 |
| hydra_8 | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.15-4.21 | 4.15-4.17 | 162x162 | B:4 |
| hydra_8 | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.15-4.21 | 4.15-4.17 | 162x162 | B:4 |
| ice_mage | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 5.26-5.31 | 5.27-5.29 | 114x114 | B:4 |
| ice_mage | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 5.26-5.31 | 5.27-5.29 | 114x114 | B:4 |
| ice_troll | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.83-3.86 | 3.82-3.87 | 143x143 | B:4 |
| ice_troll | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.83-3.86 | 3.82-3.87 | 143x143 | B:4 |
| ifrit | Idle | 4 | 4 | blur/colour (4), clipping (3), scale (4) | 3.40-3.44 | 3.40-3.43 | 130x130 | B:3 |
| ifrit | Walk | 4 | 4 | blur/colour (4), clipping (3), scale (4) | 3.40-3.44 | 3.40-3.43 | 130x130 | B:3 |
| infected_hunter | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.27-2.31 | 2.28-2.31 | 117x117 | B:4 |
| infected_hunter | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.27-2.31 | 2.28-2.31 | 117x117 | B:4 |
| inflamed_minotaur | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.31-3.33 | 3.31-3.32 | 183x183 | B:4 |
| inflamed_minotaur | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.31-3.33 | 3.31-3.32 | 183x183 | B:4 |
| large_bear | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 1.84-1.87 | 1.85-1.86 | 124x124 | B:4 |
| large_bear | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 1.84-1.87 | 1.85-1.86 | 124x124 | B:4 |
| magma_spider | Bounce | 36 | 36 | anchor (12), blur/colour (36), clipping (1), scale (36) | 0.92-1.12 | 0.84-1.12 | 151x151 | B:1 |
| magma_spider | Cast | 28 | 28 | anchor (12), blur/colour (28), scale (28) | 1.58-1.73 | 1.54-1.76 | 151x151 | - |
| magma_spider | Glob | 5 | 5 | blur/colour (5), clipping (1), scale (5) | 1.90-1.97 | 1.87-2.00 | 151x151 | B:1 |
| magma_spider | Idle | 4 | 4 | blur/colour (4), scale (4) | 4.76-4.81 | 4.73-4.90 | 151x151 | - |
| magma_spider | Walk | 4 | 4 | blur/colour (4), scale (4) | 4.76-4.81 | 4.73-4.90 | 151x151 | - |
| magma_spider | WebLand | 7 | 7 | blur/colour (7), scale (7) | 0.95-0.97 | 0.95-0.97 | 151x151 | - |
| mind_eater | Idle | 4 | 4 | blur/colour (4), clipping (2), scale (4) | 4.28-4.34 | 4.26-4.32 | 138x138 | B:2 |
| mind_eater | Walk | 4 | 4 | blur/colour (4), clipping (2), scale (4) | 4.28-4.34 | 4.26-4.32 | 138x138 | B:2 |
| mind_eater | Writhe | 32 | 32 | anchor (27), blur/colour (32), clipping (21), scale (32) | 1.47-1.56 | 1.47-1.55 | 138x138 | B:21 |
| mini_bear | Attack | 28 | 28 | anchor (11), blur/colour (28), clipping (26), scale (28) | 1.65-1.98 | 1.64-2.02 | 89x89 | B:26 |
| mini_bear | Idle | 4 | 4 | blur/colour (4), clipping (3), scale (4) | 4.55-4.60 | 4.60-4.66 | 89x89 | B:3 |
| mini_bear | Walk | 4 | 4 | blur/colour (4), clipping (3), scale (4) | 4.55-4.60 | 4.60-4.66 | 89x89 | B:3 |
| necromancer | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.22-4.29 | 4.21-4.25 | 124x124 | B:4 |
| necromancer | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.22-4.29 | 4.21-4.25 | 124x124 | B:4 |
| npc_armory | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.48-4.67 | 4.65-4.66 | 109x109 | B:4 |
| npc_armory | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.48-4.67 | 4.65-4.66 | 109x109 | B:4 |
| npc_blacksmith | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.96-3.16 | 3.07-3.09 | 114x114 | B:4 |
| npc_blacksmith | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.96-3.16 | 3.07-3.09 | 114x114 | B:4 |
| npc_card_dealer | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 5.22-5.31 | 5.26-5.30 | 114x114 | B:4 |
| npc_card_dealer | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 5.22-5.31 | 5.26-5.30 | 114x114 | B:4 |
| npc_dojo_master | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.07-4.13 | 4.09-4.11 | 114x114 | B:4 |
| npc_dojo_master | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.07-4.13 | 4.09-4.11 | 114x114 | B:4 |
| npc_sellsword | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.50-3.64 | 3.52-3.61 | 109x109 | B:4 |
| npc_sellsword | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.50-3.64 | 3.52-3.61 | 109x109 | B:4 |
| olorin | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.30-3.72 | 3.29-3.71 | 140x140 | B:4 |
| olorin | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.30-3.72 | 3.29-3.71 | 140x140 | B:4 |
| olorin_bear | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.34-3.40 | 3.36-3.38 | 127x127 | B:4 |
| olorin_bear | Sleep | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.36-3.36 | 3.36-3.36 | 127x127 | B:4 |
| olorin_bear | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.34-3.40 | 3.36-3.38 | 127x127 | B:4 |
| pit_fiend | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.83-4.89 | 4.85-4.88 | 119x119 | B:4 |
| pit_fiend | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.83-4.89 | 4.85-4.88 | 119x119 | B:4 |
| rat_king | Attack | 32 | 32 | anchor (17), blur/colour (32), clipping (14), scale (32) | 0.91-1.16 | 0.91-1.17 | 200x200 | B:14 |
| rat_king | Cast | 36 | 36 | anchor (21), blur/colour (36), clipping (8), scale (36) | 0.73-1.55 | 0.78-1.42 | 200x200 | B:8 |
| rat_king | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.83-2.83 | 2.82-2.85 | 200x200 | B:4 |
| rat_king | Infest | 11 | 11 | blur/colour (11), scale (11) | 1.58-1.62 | 1.58-1.62 | 200x200 | - |
| rat_king | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 2.83-2.83 | 2.82-2.85 | 200x200 | B:4 |
| rat_nest | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 9.18-9.24 | 8.89-9.25 | 132x132 | B:4 |
| rat_nest | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 9.18-9.24 | 8.89-9.25 | 132x132 | B:4 |
| ring_wraith | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 0.81-4.84 | 0.87-4.92 | 127x127 | B:4 |
| ring_wraith | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 0.81-4.84 | 0.87-4.92 | 127x127 | B:4 |
| roc | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.57-4.65 | 4.56-4.63 | 138x138 | B:4 |
| roc | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.57-4.65 | 4.56-4.63 | 138x138 | B:4 |
| sabertooth | Attack | 24 | 24 | anchor (18), blur/colour (24), scale (24) | 1.03-1.51 | 1.02-1.51 | 205x205 | - |
| sabertooth | Idle | 4 | 4 | blur/colour (4), scale (4) | 1.77-1.77 | 1.76-1.79 | 205x205 | - |
| sabertooth | Sunken | 40 | 40 | anchor (20), blur/colour (40), scale (40) | 0.66-1.23 | 0.72-1.24 | 205x205 | - |
| sabertooth | Track | 20 | 20 | anchor (7), blur/colour (20), scale (20) | 1.09-1.92 | 1.08-1.92 | 205x205 | - |
| sabertooth | Walk | 16 | 16 | anchor (2), blur/colour (16), scale (16) | 1.75-1.79 | 1.75-1.79 | 205x205 | - |
| sanguine_penguin | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 6.80-7.04 | 6.86-7.02 | 81x81 | B:4 |
| sanguine_penguin | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 6.80-7.04 | 6.86-7.02 | 81x81 | B:4 |
| screecher | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.29-4.40 | 4.32-4.35 | 125x125 | B:4 |
| screecher | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.29-4.40 | 4.32-4.35 | 125x125 | B:4 |
| seance_specter | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.79-4.86 | 4.83-4.88 | 114x114 | B:4 |
| seance_specter | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.79-4.86 | 4.83-4.88 | 114x114 | B:4 |
| sewer_cobra | Attack | 28 | 28 | blur/colour (28), clipping (11), scale (28) | 1.71-1.92 | 1.71-1.91 | 112x112 | B:11 |
| sewer_cobra | Cast | 28 | 28 | anchor (4), blur/colour (28), clipping (16), scale (28) | 1.68-1.90 | 1.69-1.90 | 112x112 | B:16 |
| sewer_cobra | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.99-5.10 | 5.02-5.08 | 112x112 | B:4 |
| sewer_cobra | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.99-5.10 | 5.02-5.08 | 112x112 | B:4 |
| shadow_hound | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.82-4.96 | 4.86-4.94 | 114x114 | B:4 |
| shadow_hound | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.82-4.96 | 4.86-4.94 | 114x114 | B:4 |
| skeleton | Attack | 16 | 16 | anchor (4), blur/colour (16), clipping (12), scale (16) | 1.75-1.83 | 1.77-1.84 | 132x132 | B:12 |
| skeleton | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.74-3.81 | 3.77-3.79 | 132x132 | B:4 |
| skeleton | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.74-3.81 | 3.77-3.79 | 132x132 | B:4 |
| sludge | Attack | 28 | 28 | anchor (12), blur/colour (28), clipping (25), scale (28) | 1.71-1.97 | 1.71-1.94 | 119x119 | B:25 |
| sludge | Ball | 1 | 1 | blur/colour (1), clipping (1), scale (1) | 1.70-1.70 | 1.68-1.68 | 119x119 | B:1 |
| sludge | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.86-4.91 | 4.82-4.88 | 119x119 | B:4 |
| sludge | Throw | 28 | 28 | anchor (1), blur/colour (28), clipping (15), scale (28) | 1.86-1.98 | 1.86-1.98 | 119x119 | B:15 |
| sludge | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.86-4.91 | 4.82-4.88 | 119x119 | B:4 |
| snow_wraith | Cast | 28 | 28 | anchor (1), blur/colour (28), scale (28) | 1.20-1.51 | 1.23-1.51 | 117x117 | - |
| snow_wraith | IceShard | 8 | 8 | blur/colour (8), clipping (2), scale (8) | 0.87-2.09 | 0.96-2.09 | 117x117 | B:2 |
| snow_wraith | Idle | 4 | 4 | blur/colour (4), clipping (2), scale (4) | 0.98-4.90 | 1.02-4.94 | 117x117 | B:2 |
| snow_wraith | Snowball | 8 | 8 | blur/colour (8), clipping (3), scale (8) | 0.92-5.77 | 0.92-5.70 | 117x117 | B:3 |
| snow_wraith | Throw | 20 | 20 | anchor (1), blur/colour (20), clipping (7), scale (20) | 0.95-2.13 | 0.84-2.10 | 117x117 | B:7 |
| snow_wraith | Walk | 4 | 4 | blur/colour (4), clipping (2), scale (4) | 0.98-4.90 | 1.02-4.94 | 117x117 | B:2 |
| spark_mage | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.06-3.15 | 3.15-3.15 | 105x105 | B:4 |
| spark_mage | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.06-3.15 | 3.15-3.15 | 105x105 | B:4 |
| spirit_collector | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.46-4.57 | 4.48-4.53 | 114x114 | B:4 |
| spirit_collector | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.46-4.57 | 4.48-4.53 | 114x114 | B:4 |
| succubus | Attack | 28 | 28 | anchor (4), blur/colour (28), clipping (19), scale (28) | 1.69-1.91 | 1.71-1.91 | 126x126 | B:19 |
| succubus | Cast | 28 | 28 | anchor (1), blur/colour (28), clipping (24), scale (28) | 1.76-1.88 | 1.77-1.86 | 126x126 | B:24 |
| succubus | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.54-4.64 | 4.56-4.65 | 126x126 | B:4 |
| succubus | Orb | 1 | 1 | blur/colour (1), clipping (1), scale (1) | 2.06-2.06 | 2.12-2.12 | 126x126 | B:1 |
| succubus | Scythe | 7 | 7 | blur/colour (7), clipping (3), scale (7) | 4.35-4.70 | 4.44-4.54 | 126x126 | B:3 |
| succubus | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.54-4.64 | 4.56-4.65 | 126x126 | B:4 |
| summon_golem | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.30-4.32 | 4.26-4.32 | 113x113 | B:4 |
| summon_golem | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.30-4.32 | 4.26-4.32 | 113x113 | B:4 |
| summon_skeleton | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.18-4.23 | 4.22-4.27 | 98x98 | B:4 |
| summon_skeleton | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.18-4.23 | 4.22-4.27 | 98x98 | B:4 |
| swarm | Idle | 4 | 4 | blur/colour (4), clipping (1), scale (4) | 4.67-4.74 | 4.66-4.70 | 123x123 | B:1 |
| swarm | Walk | 4 | 4 | blur/colour (4), clipping (1), scale (4) | 4.67-4.74 | 4.66-4.70 | 123x123 | B:1 |
| treant | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.25-3.29 | 3.24-3.27 | 162x162 | B:4 |
| treant | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.25-3.29 | 3.24-3.27 | 162x162 | B:4 |
| treasure_bunny | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 5.90-5.94 | 5.83-5.99 | 72x72 | B:4 |
| treasure_bunny | Smoke | 8 | 8 | blur/colour (8), scale (8) | 2.27-2.32 | 2.28-2.31 | 72x72 | - |
| treasure_bunny | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 5.90-5.94 | 5.83-5.99 | 72x72 | B:4 |
| vampire | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.48-4.67 | 4.54-4.59 | 114x114 | B:4 |
| vampire | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.48-4.67 | 4.54-4.59 | 114x114 | B:4 |
| weregoat | Idle | 4 | 4 | blur/colour (4), scale (4) | 2.09-2.12 | 2.08-2.11 | 127x127 | - |
| weregoat | Walk | 16 | 16 | anchor (2), blur/colour (16), scale (16) | 2.08-2.17 | 2.07-2.12 | 127x127 | - |
| wererat | Attack | 20 | 20 | anchor (12), blur/colour (20), clipping (16), scale (20) | 2.02-2.32 | 2.00-2.33 | 155x155 | B:16 |
| wererat | Idle | 4 | 4 | blur/colour (4), scale (4) | 5.18-5.21 | 5.16-5.21 | 155x155 | - |
| wererat | Walk | 4 | 4 | blur/colour (4), scale (4) | 5.18-5.21 | 5.16-5.21 | 155x155 | - |
| werewolf | Attack | 12 | 12 | anchor (3), blur/colour (12), clipping (11), scale (12) | 1.78-2.59 | 1.76-2.57 | 157x157 | B:11 |
| werewolf | Attack2 | 16 | 16 | anchor (7), blur/colour (16), clipping (15), scale (16) | 1.77-2.59 | 1.76-2.57 | 157x157 | B:15 |
| werewolf | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.31-4.39 | 4.34-4.41 | 157x157 | B:4 |
| werewolf | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 4.31-4.39 | 4.34-4.41 | 157x157 | B:4 |
| white_manticore | Idle | 4 | 4 | blur/colour (4), scale (4) | 2.29-2.32 | 2.30-2.31 | 148x148 | - |
| white_manticore | Walk | 16 | 16 | anchor (1), blur/colour (16), scale (16) | 2.29-2.32 | 2.30-2.34 | 148x148 | - |
| wolf | Attack | 16 | 16 | anchor (8), blur/colour (16), scale (16) | 1.88-2.19 | 1.90-2.19 | 144x144 | - |
| wolf | Idle | 4 | 4 | blur/colour (4), scale (4) | 2.79-2.86 | 2.83-2.85 | 144x144 | - |
| wolf | Walk | 16 | 16 | anchor (3), blur/colour (16), scale (16) | 2.81-2.88 | 2.81-2.87 | 144x144 | - |
| wyvern | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.48-3.49 | 3.48-3.50 | 130x130 | B:4 |
| wyvern | Walk | 4 | 4 | blur/colour (4), clipping (3), scale (4) | 3.46-3.52 | 3.46-3.52 | 130x130 | B:3 |
| zombie | Attack | 16 | 16 | anchor (2), blur/colour (16), clipping (16), scale (16) | 1.89-2.01 | 1.89-2.02 | 114x114 | B:16 |
| zombie | Idle | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.60-3.72 | 3.64-3.70 | 114x114 | B:4 |
| zombie | Walk | 4 | 4 | blur/colour (4), clipping (4), scale (4) | 3.60-3.72 | 3.64-3.70 | 114x114 | B:4 |

## Source drawing scale per character

Median source px per output px (sy) for each animation's board, and the spread
(largest / smallest). The old cuts hold each character near one on-screen size, so a
spread above 1 is how much bigger one board draws the character than another: a 1:1
crop of both cannot show the character at one size.

| character | (animation: board sy) | board-scale spread |
|---|---|---|
| air_mage | Idle: air_mage_sorceress_board.webp 4.97; Walk: air_mage_sorceress_board.webp 4.97 | 1.00 |
| archer_rat | Attack: archer_rat_shoot_board.webp 3.10; Draw: archer_rat_shoot_board.webp 3.12; Idle: archer_rat_board.webp 6.30; Walk: archer_rat_board.webp 6.30 | 2.03 |
| armored_troll | Attack: armored_troll_smash_board.webp 1.24; Idle: armored_troll_board.png 3.73; Kick: armored_troll_kick_board.webp 1.41; Walk: armored_troll_board.png 3.73 | 3.00 |
| ash_harpy | Cast: ash_harpy_flap_board.webp 1.48; Idle: ash_harpy_board.webp 4.56; Walk: ash_harpy_board.webp 4.56 | 3.07 |
| battle_turtle | Armor: battle_turtle_armor_board.webp 1.56; Idle: battle_turtle_board.webp 4.33; Walk: battle_turtle_board.webp 4.33 | 2.78 |
| bone_dragon | Idle: bone_dragon_board.jpg 2.07; Walk: bone_dragon_board.jpg 2.07 | 1.00 |
| bugbear | Idle: bugbear_board.png 4.03; Walk: bugbear_board.png 4.03 | 1.00 |
| bull_worm | Idle: bull_worm_v2_board.webp 7.17; Walk: bull_worm_v2_board.webp 7.17 | 1.00 |
| cerberus | Idle: boss_trio_board.webp 1.61; Walk: boss_trio_board.webp 1.61 | 1.00 |
| cherub | Idle: cherub_board.jpg 4.56; Walk: cherub_board.jpg 4.56 | 1.00 |
| consumed | Idle: screecher_board.jpg 3.66; Walk: screecher_board.jpg 3.66 | 1.00 |
| corrupted_archangel | Idle: boss_trio_board.webp 2.46; Walk: boss_trio_board.webp 2.46 | 1.00 |
| coyote | Attack: coyote_nip_board.webp 2.24; Idle: coyote_board.webp 4.63; Walk: coyote_board.webp 4.63 | 2.07 |
| crypt_crawler | Idle: crypt_crawler_board.webp 5.55; Walk: crypt_crawler_board.webp 5.55 | 1.00 |
| djinn | Cast: djinn_chain_lightning_board.webp 1.84; Idle: djinn_v2_board.webp 3.77; Walk: djinn_v2_board.webp 3.77 | 2.05 |
| earth_mage | Idle: earth_mage_druid_board.png 2.22; Walk: earth_mage_druid_board.png 2.22 | 1.00 |
| fire_goblin | Idle: fire_goblin_board.webp 4.97; Walk: fire_goblin_board.webp 4.97 | 1.00 |
| fire_goblin_mage | Idle: fire_goblin_mage_board.webp 4.66; Walk: fire_goblin_mage_board.webp 4.66 | 1.00 |
| fire_goblin_shaman | Idle: fire_goblin_shaman_board.webp 5.28; Walk: fire_goblin_shaman_board.webp 5.28 | 1.00 |
| fire_mage | Idle: fire_mage_board_v2.webp 4.24; Walk: fire_mage_board_v2.webp 4.24 | 1.00 |
| frankenstein | Idle: frankenstein_v2_board.webp 6.57; Walk: frankenstein_v2_board.webp 6.57 | 1.00 |
| giant_beaver | Idle: giant_beaver_v2_board.webp 5.64; Walk: giant_beaver_v2_board.webp 5.61 | 1.01 |
| giant_hawk | Idle: giant_hawk_board.png 5.13; Walk: giant_hawk_board.png 5.13 | 1.00 |
| granite_colossus | Idle: granite_colossus_board_v2.webp 2.49; Walk: granite_colossus_board_v2.webp 2.49 | 1.00 |
| grave_digger | Idle: grave_digger_board.webp 4.17; Walk: grave_digger_board.webp 4.17 | 1.00 |
| grave_titan | Attack: grave_titan_smash_board.webp 1.19; Idle: grave_titan_board.png 3.12; Throw: grave_titan_throw_board.webp 1.27; Walk: grave_titan_board.png 3.12 | 2.63 |
| hades | Idle: boss_trio_board.webp 2.39; Walk: boss_trio_board.webp 2.39 | 1.00 |
| hell_door | Idle: hell_door_board.webp 5.94; Walk: hell_door_board.webp 5.94 | 1.00 |
| hero:brad | attack: brad_attack_board.webp 1.54; block: brad_block_board.webp 1.53; walk: brad_v2_board.webp 3.67; walk: brad_walk_board.webp 1.90 | 2.39 |
| hero:cory | attack: cory_attack_board.webp 1.83; block: cory_block_board.webp 1.82; walk: cory_walk_board.webp 1.99; walk: heroes_front_back.webp 3.97; walk: heroes_side.webp 3.50 | 2.18 |
| hero:jeremy | attack: jeremy_attack_board.webp 1.80; block: jeremy_block_board.webp 1.78; walk: heroes_front_back.webp 3.97; walk: heroes_side.webp 3.44; walk: jeremy_walk_board.webp 1.95 | 2.23 |
| hero:ryan | attack: ryan_attack_board.webp 1.72; block: ryan_block_board.webp 1.35; walk: ryan_v2_board.webp 5.68; walk: ryan_walk_board.webp 1.99 | 4.21 |
| hero:stephen | attack: stephen_attack_board.webp 1.87; block: stephen_block_board.webp 1.90; walk: stephen_v2_board.png 2.71; walk: stephen_walk_left_board.webp 3.94; walk: stephen_walk_north_board.webp 3.87; walk: stephen_walk_right_board.webp 4.31; walk: stephen_walk_south_board.webp 3.88 | 2.30 |
| hydra | Attack: hydra_attack_back_board.webp 3.10; Attack: hydra_attack_front_board.webp 2.43; Attack: hydra_attack_left_board.webp 1.89; Attack: hydra_attack_right_board.webp 2.02; Idle: hydra_board.webp 3.90; Walk: hydra_board.webp 3.90 | 2.07 |
| hydra_3 | Attack: hydra_3_attack_board.webp 1.26; Idle: hydra_3_attack_board.webp 1.63; Walk: hydra_3_attack_board.webp 1.63 | 1.29 |
| hydra_5 | Attack: hydra_5_attack_board.webp 1.33; Idle: hydra_5_board.webp 4.33; Walk: hydra_5_board.webp 4.33 | 3.25 |
| hydra_8 | Attack: hydra_8_attack_board.webp 1.31; Idle: hydra_8_board.webp 4.16; Walk: hydra_8_board.webp 4.16 | 3.16 |
| ice_mage | Idle: ice_mage_board_v2.webp 5.29; Walk: ice_mage_board_v2.webp 5.29 | 1.00 |
| ice_troll | Idle: ice_troll_board.png 3.84; Walk: ice_troll_board.png 3.84 | 1.00 |
| ifrit | Idle: ifrit_board_v2.webp 3.43; Walk: ifrit_board_v2.webp 3.43 | 1.00 |
| infected_hunter | Idle: infected_hunter_board.png 2.29; Walk: infected_hunter_board.png 2.29 | 1.00 |
| inflamed_minotaur | Idle: inflamed_minotaur_v2_board.webp 3.32; Walk: inflamed_minotaur_v2_board.webp 3.32 | 1.00 |
| large_bear | Idle: large_bear_board.png 1.85; Walk: large_bear_board.png 1.85 | 1.00 |
| magma_spider | Bounce: magma_spider_bounce_board.webp 1.06; Cast: magma_spider_web_board.webp 1.61; Idle: magma_spider_board.jpg 4.76; Walk: magma_spider_board.jpg 4.76 | 4.47 |
| mind_eater | Idle: mind_eater_board.webp 4.29; Walk: mind_eater_board.webp 4.29; Writhe: mind_eater_writhe_board.webp 1.52 | 2.82 |
| mini_bear | Attack: mini_bear_attack_board.webp 1.81; Idle: mini_bear_board.png 4.62; Walk: mini_bear_board.png 4.62 | 2.55 |
| necromancer | Idle: necromancer_board.png 4.23; Walk: necromancer_board.png 4.23 | 1.00 |
| npc_armory | Idle: armory_npc_board.webp 4.66; Walk: armory_npc_board.webp 4.66 | 1.00 |
| npc_blacksmith | Idle: blacksmith_npc_board.webp 3.08; Walk: blacksmith_npc_board.webp 3.08 | 1.00 |
| npc_card_dealer | Idle: card_dealer_npc_board.webp 5.28; Walk: card_dealer_npc_board.webp 5.28 | 1.00 |
| npc_dojo_master | Idle: dojo_master_board.webp 4.09; Walk: dojo_master_board.webp 4.09 | 1.00 |
| npc_sellsword | Idle: sellsword_npc_board.webp 3.56; Walk: sellsword_npc_board.webp 3.56 | 1.00 |
| olorin | Idle: olorin_board.png 3.38; Walk: olorin_board.png 3.38 | 1.00 |
| olorin_bear | Idle: olorin_bear_board.webp 3.38; Sleep: olorin_bear_board.webp 3.36; Walk: olorin_bear_board.webp 3.38 | 1.00 |
| pit_fiend | Idle: pit_fiend_v2_board.webp 4.87; Walk: pit_fiend_v2_board.webp 4.87 | 1.00 |
| rat_king | Attack: rat_king_bite_board.webp 1.08; Cast: rat_king_infest_board.webp 0.91; Idle: rat_king_board.jpg 2.83; Walk: rat_king_board.jpg 2.83 | 3.10 |
| rat_nest | Idle: rat_nest_board.webp 9.14; Walk: rat_nest_board.webp 9.14 | 1.00 |
| roc | Idle: roc_board.webp 4.58; Walk: roc_board.webp 4.58 | 1.00 |
| sabertooth | Attack: sabertooth_bite_claw_board.webp 1.25; Idle: sabertooth_v2_clean.webp 1.77; Sunken: sabertooth_sunken_bite_board.webp 1.21; Track: sabertooth_track_board.webp 1.41; Walk: sabertooth_v2_clean.webp 1.77 | 1.46 |
| sanguine_penguin | Idle: sanguine_penguin_v2_board.webp 6.90; Walk: sanguine_penguin_v2_board.webp 6.90 | 1.00 |
| screecher | Idle: screecher_board.webp 4.34; Walk: screecher_board.webp 4.34 | 1.00 |
| seance_specter | Idle: seance_specter_board.webp 4.83; Walk: seance_specter_board.webp 4.83 | 1.00 |
| sewer_cobra | Attack: sewer_cobra_bite_board.webp 1.82; Cast: sewer_cobra_spray_board.webp 1.87; Idle: sewer_cobra_board.webp 5.03; Walk: sewer_cobra_board.webp 5.03 | 2.77 |
| shadow_hound | Idle: shadow_hound_board.webp 4.87; Walk: shadow_hound_board.webp 4.87 | 1.00 |
| skeleton | Attack: skeleton_slash_board.webp 1.81; Idle: skeleton_board.webp 3.78; Walk: skeleton_board.webp 3.78 | 2.09 |
| sludge | Attack: sludge_hammer_board.webp 1.83; Idle: sludge_board.webp 4.87; Throw: sludge_throw_board.webp 1.92; Walk: sludge_board.webp 4.87 | 2.66 |
| snow_wraith | Cast: snow_wraith_ice_blast_board.webp 1.43; Idle: snow_wraith_board.webp 4.94; Throw: snow_wraith_snowball_board.webp 2.08; Walk: snow_wraith_board.webp 4.94 | 3.46 |
| spark_mage | Idle: spark_mage_brawler_board.png 3.15; Walk: spark_mage_brawler_board.png 3.15 | 1.00 |
| spirit_collector | Idle: spirit_collector_board.png 4.49; Walk: spirit_collector_board.png 4.49 | 1.00 |
| succubus | Attack: succubus_snap_board.webp 1.79; Cast: succubus_drain_board.webp 1.82; Idle: succubus_board.webp 4.60; Walk: succubus_board.webp 4.60 | 2.57 |
| summon_golem | Idle: granite_colossus_board_v2.webp 4.29; Walk: granite_colossus_board_v2.webp 4.29 | 1.00 |
| summon_skeleton | Idle: summon_skeleton_board.jpg 4.24; Walk: summon_skeleton_board.jpg 4.24 | 1.00 |
| swarm | Idle: swarm_board.webp 4.69; Walk: swarm_board.webp 4.69 | 1.00 |
| treant | Idle: treant_board.png 3.26; Walk: treant_board.png 3.26 | 1.00 |
| treasure_bunny | Idle: treasure_bunny_board.jpg 5.94; Walk: treasure_bunny_board.jpg 5.94 | 1.00 |
| vampire | Idle: vampire_board.png 4.57; Walk: vampire_board.png 4.57 | 1.00 |
| weregoat | Idle: weregoat_walk_board.webp 2.09; Walk: weregoat_walk_board.webp 2.10 | 1.00 |
| wererat | Attack: wererat_bite_board.webp 2.20; Idle: wererat_board.webp 5.19; Walk: wererat_board.webp 5.19 | 2.36 |
| werewolf | Attack: werewolf_slash_board.webp 2.55; Attack: werewolf_slash_front_back_board.webp 1.85; Attack2: werewolf_slash_board.webp 2.55; Attack2: werewolf_slash_front_back_board.webp 1.85; Idle: werewolf_board.webp 4.40; Walk: werewolf_board.webp 4.40 | 2.38 |
| white_manticore | Idle: white_manticore_v2_sheet.webp 2.30; Walk: white_manticore_v2_sheet.webp 2.31 | 1.00 |
| wolf | Attack: wolf_bite_board.webp 2.00; Idle: wolf_sheet.webp 2.85; Walk: wolf_sheet.webp 2.85 | 1.42 |
| wyvern | Idle: wyvern_v2_board.webp 3.49; Walk: wyvern_v2_board.webp 3.51 | 1.01 |
| zombie | Attack: zombie_attack_board.webp 1.95; Idle: zombie_board.jpg 3.69; Walk: zombie_board.jpg 3.69 | 1.89 |

## Weak matches (score < 0.85)

Frames whose best match on any board is weak: mostly effects (smoke, bolts, a vortex)
whose cut was recoloured or faded, or figures whose cut differs a lot from the board.
Their sx/sy are left out of the spread above; their verdicts stand (a weak match
cannot be an exact 1:1 crop either).

| character | animation | frames | best board | score range |
|---|---|---|---|---|
| ash_harpy | Vortex | 16 | ash_harpy_flap_board.webp | 0.36-0.85 |
| cerberus | Idle | 1 | boss_trio_board.webp | 0.84-0.84 |
| cerberus | Walk | 1 | boss_trio_board.webp | 0.84-0.84 |
| djinn | Arc | 3 | djinn_lightning_arc_strip.webp | 0.38-0.83 |
| magma_spider | Bounce | 1 | magma_spider_bounce_board.webp | 0.14-0.14 |
| mind_eater | Writhe | 1 | mind_eater_writhe_board.webp | 0.84-0.84 |
| npc_card_dealer | Idle | 2 | card_dealer_npc_board.webp | 0.79-0.79 |
| npc_card_dealer | Walk | 2 | card_dealer_npc_board.webp | 0.79-0.79 |
| rat_king | Attack | 1 | rat_king_bite_board.webp | 0.61-0.61 |
| rat_king | Cast | 18 | rat_king_bite_board.webp | 0.33-0.76 |
| rat_king | Infest | 3 | rat_king_infest_board.webp | 0.46-0.84 |
| ring_wraith | Idle | 4 | ring_wraith_board.jpg | 0.27-0.78 |
| ring_wraith | Walk | 4 | ring_wraith_board.jpg | 0.27-0.78 |
| sabertooth | Sunken | 20 | sabertooth_track_board.webp | 0.30-0.49 |
| sewer_cobra | Attack | 1 | sewer_cobra_bite_board.webp | 0.82-0.82 |
| sewer_cobra | Cast | 1 | sewer_cobra_spray_board.webp | 0.83-0.83 |
| snow_wraith | Cast | 1 | snow_wraith_ice_shard_strip.webp | 0.28-0.28 |
| snow_wraith | IceShard | 1 | snow_wraith_ice_shard_strip.webp | 0.33-0.33 |
| snow_wraith | Idle | 2 | snow_wraith_ice_shard_strip.webp | 0.21-0.22 |
| snow_wraith | Snowball | 2 | snow_wraith_ice_shard_strip.webp | 0.40-0.52 |
| snow_wraith | Throw | 2 | snow_wraith_snowball_strip.webp | 0.18-0.33 |
| snow_wraith | Walk | 2 | snow_wraith_ice_shard_strip.webp | 0.21-0.22 |
| succubus | Cast | 1 | succubus_drain_board.webp | 0.81-0.81 |
| swarm | Idle | 2 | swarm_board.webp | 0.78-0.82 |
| swarm | Walk | 2 | swarm_board.webp | 0.78-0.82 |
| treasure_bunny | Smoke | 2 | treasure_bunny_vanish_strip.webp | 0.48-0.81 |
