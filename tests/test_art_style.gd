extends SceneTree

## The two looks of the figures cut from the designer's art (2026-10-25):
## the smooth one (the art itself at ArtStyle.SMOOTH_DENSITY a tile,
## filtered, soft-edged — tools/smooth_art.py) and the pixel one, kept on
## hand. Every designer sheet has both, at the same height in tiles; the
## figures wear the one ArtStyle.SMOOTH picks.
## Run: godot --headless --path . --script tests/test_art_style.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Art style ===")
	for kind in SpriteEnemyFigure.KINDS:
		var folder: String = SpriteEnemyFigure.KINDS[kind].get("sheets", "")
		if folder == "":
			continue
		_check(ResourceLoader.exists(folder + "/Idle.png"), "%s keeps its pixel sheet" % kind)
		var soft := ArtStyle.SMOOTH_ROOT + folder.trim_prefix(ArtStyle.GENERATED)
		_check(ResourceLoader.exists(soft + "/Idle.png") and ResourceLoader.exists(soft + "/Walk.png"), "%s has a smooth sheet" % kind)
		var f := SpriteEnemyFigure.new()
		get_root().add_child(f)
		f.setup(kind)
		_check(f.smooth == ArtStyle.SMOOTH, "%s wears the %s look" % [kind, "smooth" if ArtStyle.SMOOTH else "pixel"])
		if f.smooth:
			_check(f._sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "%s is filtered smooth" % kind)
		var h_now: float = f.portrait_extent().y
		f.free()
		# The other look stands as tall.
		var p := SpriteEnemyFigure.new()
		get_root().add_child(p)
		p.setup(kind)
		var img: Image = load(folder + "/Idle.png").get_image()
		var cell := img.get_height() / 4
		var px_h := float(img.get_region(Rect2i(0, 0, cell, cell)).get_used_rect().size.y) * SpriteEnemyFigure.PIXEL_SIZE \
			* float(SpriteEnemyFigure.KINDS[kind].get("scale", 1.0)) * float(SpriteEnemyFigure.KINDS[kind].get("tall", 1.0))
		_check(absf(h_now - px_h) < 0.15, "%s stands %.2f tiles in both looks (pixel %.2f)" % [kind, h_now, px_h])
		p.free()
	for hero in ["Brad", "Cory", "Jeremy", "Ryan", "Stephen"]:
		var path := "res://assets/sprites/generated/heroes/%s.png" % hero.to_lower()
		_check(ResourceLoader.exists(path), "%s keeps the pixel sheet" % hero)
		_check(ArtStyle.SMOOTH == (ArtStyle.smooth_file(path) != ""), "%s has a smooth sheet" % hero)
		var s := SpriteFigure.new()
		get_root().add_child(s)
		s.setup(hero)
		_check(s.smooth == ArtStyle.SMOOTH, "%s wears the %s look" % [hero, "smooth" if ArtStyle.SMOOTH else "pixel"])
		var body: Sprite3D = s._npc_sprite
		var used := body.texture.get_image().get_region(Rect2i(0, 0, s._body_cell, s._body_cell)).get_used_rect()
		var tall := used.size.y * body.pixel_size
		_check(absf(tall - SpriteFigure.BOARD_HEIGHT) < 0.08, "%s stands %.2f tiles" % [hero, tall])
		s.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
