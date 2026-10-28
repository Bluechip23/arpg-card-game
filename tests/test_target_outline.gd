extends SceneTree

## The aiming outline (green: will land, red: won't) works on the designer's
## monster boards: their smooth sheets carry mipmaps, and the silhouette the
## outline is drawn from must be built from the full-size image (it came out
## empty, and the outline vanished, 2026-10-28).
## Run: godot --headless --path . --script tests/test_target_outline.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Aiming outline on the board monsters ===")
	for kind in ["wererat", "zombie", "summon_skeleton"]:
		for smooth in [true, false]:
			var dir := "res://assets/sprites/generated/%ssheets/%s/Idle.png" % ["smooth/" if smooth else "", kind]
			if not ResourceLoader.exists(dir):
				continue
			var tex: Texture2D = load(dir)
			var sil: Texture2D = SpriteEnemyFigure._silhouette(tex)
			_check(sil != null and sil.get_width() == tex.get_width() and sil.get_height() == tex.get_height(),
				"%s (%s): its silhouette is built, full size" % [kind, "smooth" if smooth else "pixel"])
			if sil:
				var img := sil.get_image()
				var lit := 0
				for y in range(0, img.get_height(), 4):
					for x in range(0, img.get_width(), 4):
						if img.get_pixel(x, y).a > 0.5:
							lit += 1
				_check(lit > 20, "%s (%s): and it has the figure's shape in it (%d samples)" % [kind, "smooth" if smooth else "pixel", lit])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
