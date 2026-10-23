extends SceneTree

## The heroes wear the designer's sprites (tools/cut_hero_sprites.py,
## 2026-10-23): Jeremy the cloaked skeleton, Cory the hooded monk, Ryan the
## rogue outlaw, Brad the warrior with the War Rack over his shoulder,
## Stephen the apex hunter with bow and axe on his back — one
## detailed pose a direction (kept fine: ~96 texels tall, drawn at a finer
## pixel size so they stand BOARD_HEIGHT tiles). Walking steps the body;
## attacks still swing the weapon layer, scaled to the hero.
## Run: godot --headless --path . --script tests/test_hero_sprites.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _used(tex: Texture2D, rect: Rect2) -> Rect2i:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img.get_region(Rect2i(rect)).get_used_rect()

func _initialize() -> void:
	print("=== Hero sprites ===")
	var D := CharacterAnimator.Direction
	for hero in ["Brad", "Cory", "Jeremy", "Ryan", "Stephen"]:
		var f := SpriteFigure.new()
		get_root().add_child(f)
		f.setup(hero)
		var body: Sprite3D = f._npc_sprite
		var path := "res://assets/sprites/generated/heroes/%s.png" % hero.to_lower()
		_check(f._mode == "board" and body != null and body.texture.resource_path == path,
			"%s wears the designer's sprite" % hero)
		var front := _used(body.texture, Rect2(0, 0, f._body_cell, f._body_cell))
		_check(front.size.y >= 90, "%s keeps the art's detail (%d texels tall, not squeezed)" % [hero, front.size.y])
		_check(absf(front.size.y * body.pixel_size - SpriteFigure.BOARD_HEIGHT) < 0.02,
			"%s stands %.2f tiles tall" % [hero, front.size.y * body.pixel_size])
		var rows := {}
		for d in [D.SOUTH, D.NORTH, D.EAST, D.WEST]:
			f.set_facing(d)
			var r: Rect2 = body.region_rect
			rows[r.position.y] = true
			var u := _used(body.texture, r)
			# One scale a hero: every pose within a few texels of the front.
			_check(u.size.y > 0 and absf(u.size.y - front.size.y) <= front.size.y * 0.12,
				"%s facing %d keeps the hero's proportions (%d vs front %d)" % [hero, d, u.size.y, front.size.y])
			_check(u.end.y == f._body_cell, "%s facing %d stands on the cell's floor" % [hero, d])
		_check(rows.size() == 4, "%s has a pose for each direction" % hero)
		# Walking: one pose, so the body steps up and back down.
		f.set_facing(D.EAST)
		f.set_walking(true)
		var lifts := {}
		for _i in range(12):
			f._process(0.05)
			lifts[body.offset.y - f._body_offset.y] = true
		_check(lifts.size() == 2 and lifts.has(0.0), "%s steps while walking (%s)" % [hero, lifts.keys()])
		f.set_walking(false)
		f._process(0.05)
		_check(body.offset == f._body_offset, "%s stands on the ground when still" % hero)
		# Attacks still swing the weapon layer, grown to the hero's size.
		_check(absf(f._weapon_front.pixel_size - SpriteFigure.PIXEL_SIZE * SpriteFigure.BOARD_HEIGHT / SpriteFigure.PACK_BODY_HEIGHT) < 0.0001,
			"%s's weapon layer is scaled to the hero" % hero)
		f.set_weapon_kind("sword", false)
		f.play_action("attack", D.EAST)
		var swung := false
		for _i in range(8):
			f._process(0.03)
			swung = swung or f._weapon_front.visible or f._weapon_back.visible
		_check(swung, "%s swings the sword" % hero)
		f.free()
	# The NPC mode still draws the dojo's ally dogs.
	var dog := SpriteFigure.new()
	get_root().add_child(dog)
	dog.setup("Dog")
	_check(dog._mode == "npc" and dog._npc_sprite.pixel_size == SpriteFigure.PIXEL_SIZE, "the dojo dog keeps its NPC sheet")
	dog.free()
	# Cory: his eyes' blue glows in the front view and, as a speck, in the hood
	# on the side views.
	var tex: Texture2D = load("res://assets/sprites/generated/heroes/cory.png")
	var cory := tex.get_image()
	if cory.is_compressed():
		cory.decompress()
	var cell := cory.get_width()
	for row in [0, 2, 3]:
		var blue := 0
		for y in range(row * cell, row * cell + cell / 3):
			for x in range(cell):
				var c := cory.get_pixel(x, y)
				if c.a > 0.5 and c.b > c.r + 0.25 and c.b > c.g + 0.1:
					blue += 1
		_check(blue >= 1, "Cory's row %d shows his eyes' blue (%d px)" % [row, blue])
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
