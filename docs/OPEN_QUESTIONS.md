# Open Questions (style restructure)

1. **World render resolution.** Spec default is 320×180; I shipped 640×360
   (constant `WORLD_RES` in `scripts/core/main.gd`) because enemy Label3D
   name/HP text and the far zoom become illegible at 180p. If you want the
   fully period-accurate 320×180 (and are OK moving enemy labels to the
   full-res UI layer later), it is a one-line change — say the word.
2. **Hit flash purity.** True palette-swap-to-white needs per-sheet white
   silhouettes or a custom spatial shader on every Sprite3D; I used a hard
   2-frame saturating modulate ((12,12,12), no tween) which clips everything
   except the darkest outline pixels to white. Visually equivalent at 360p —
   flag if you want the shader version anyway.
3. **Orbit camera freedom.** Yaw now snaps to 45° steps on release (art and
   light stay coherent at the 8 cardinal views). If you'd rather have 4 fixed
   90° views only — or a fully locked SoM camera — both are trivial from here.
