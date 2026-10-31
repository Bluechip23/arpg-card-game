extends SceneTree

## The heroes wear the designer's sprites (tools/cut_hero_sprites.py,
## 2026-10-23): Jeremy the cloaked skeleton, Cory the hooded monk, Ryan the
## rogue outlaw, Brad the warrior with the War Rack over his shoulder,
## Stephen the apex hunter with bow and axe on his back — one
## detailed pose a direction (kept fine: ~100 texels tall at 64 texels a
## tile, so they stand BOARD_HEIGHT tiles). Walking steps the body;
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
		if f.smooth:
			path = ArtStyle.smooth_file(path)
		_check(f._mode == "board" and body != null and body.texture.resource_path == path,
			"%s wears the designer's sprite" % hero)
		var front := _used(body.texture, Rect2(0, 0, f._body_cell, f._body_cell))
		_check(front.size.y >= 90, "%s keeps the art's detail (%d texels tall, not squeezed)" % [hero, front.size.y])
		_check(absf(front.size.y * body.pixel_size - SpriteFigure.BOARD_HEIGHT) < 0.04,
			"%s stands %.2f tiles tall" % [hero, front.size.y * body.pixel_size])
		# 64 texels a tile, both ways (2026-10-25): one screen pixel an art
		# texel at zoom 2, so no row or column is skipped; the stockier build
		# is baked into the art, not stretched on.
		var want := ArtStyle.SMOOTH_DENSITY if f.smooth else SpriteFigure.BOARD_DENSITY
		_check(f.smooth == ArtStyle.SMOOTH, "%s wears the %s sheet" % [hero, "smooth" if ArtStyle.SMOOTH else "pixel"])
		_check(is_equal_approx(1.0 / body.pixel_size, want),
			"%s is drawn at %.0f texels a tile" % [hero, 1.0 / body.pixel_size])
		_check(is_equal_approx(body.scale.x, 1.0) and is_equal_approx(body.scale.y, 1.0),
			"%s is not stretched on screen" % hero)
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
		# Walking with one pose (no drawn walk cycle that way): the body steps
		# up and back down.
		f.set_facing(D.EAST)
		f.set_walking(true)
		var lifts := {}
		for _i in range(12):
			f._process(0.05)
			lifts[body.offset.y - f._body_offset.y] = true
		if f._strides():
			_check(lifts.size() == 1 and lifts.has(0.0), "%s strides east without stepping" % hero)
		else:
			_check(lifts.size() == 2 and lifts.has(0.0), "%s steps while walking (%s)" % [hero, lifts.keys()])
		f.set_walking(false)
		f._process(0.05)
		_check(body.offset == f._body_offset, "%s stands on the ground when still" % hero)
		# A drawn walk cycle (2026-10-31: Stephen, Jeremy, Ryan): facing a
		# way that has one, the hero strides through eight frames on the
		# ground, and stands on column 0 again when he stops.
		if not f._walk_rows.is_empty():
			f.set_facing(D.SOUTH)
			f.set_walking(true)
			var cols := {}
			var grounded := true
			for _i in range(16):
				f._process(SpriteFigure.BOARD_WALK_TIME)
				cols[int(body.region_rect.position.x / f._body_cell)] = true
				grounded = grounded and body.offset == f._body_offset
			_check(grounded, "%s strides without stepping" % hero)
			_check(cols.size() == 8 and not cols.has(0), "%s strides through his walk frames (%s)" % [hero, cols.keys()])
			for d in [D.SOUTH, D.NORTH, D.EAST, D.WEST]:
				f.set_facing(d)
				if not f._strides():
					continue
				for c in range(1, 9):
					var u := _used(body.texture, Rect2(c * f._body_cell, body.region_rect.position.y, f._body_cell, f._body_cell))
					_check(u.size.y > 0 and absf(u.size.y - front.size.y) <= front.size.y * 0.12 and u.end.y == f._body_cell,
						"%s facing %d walk frame %d stands his height on the floor (%d)" % [hero, d, c, u.size.y])
			f.set_walking(false)
			f._process(0.05)
			_check(body.region_rect.position.x == 0.0, "%s stands in his still pose when he stops" % hero)
		# Attacks lunge the body toward the target; no weapon is drawn (the
		# pack's weapon swing was deleted for the designer's own, 2026-10-30).
		f.set_weapon_kind("sword", false)
		f.play_action("attack", D.EAST)
		var lunged := false
		for _i in range(8):
			f._process(0.03)
			lunged = lunged or f._npc_sprite.position.x > 0.0
		_check(lunged, "%s lunges into the attack" % hero)
		_check(not ("_weapon_front" in f), "%s carries no weapon layer" % hero)
		f.free()
	# Brad's drawn basic attack and block (2026-10-31): the action sprite
	# plays the sheet (the body hidden), feet on the ground line, and gives
	# the body back when done; facing north the block has no drawing, so
	# the old guard plays.
	for hero in ["Brad", "Cory", "Jeremy", "Stephen", "Ryan"]:
		var fig := SpriteFigure.new()
		get_root().add_child(fig)
		fig.setup(hero)
		for action in ["basic_attack", "basic_block"]:
			var a: Dictionary = fig._actions.get(action, {})
			_check(not a.is_empty(), "%s has his drawn %s" % [hero, action])
			if a.is_empty():
				continue
			var cell: int = a["cell"]
			var still := _used(a["tex"], Rect2(0, 0, cell, cell))
			_check(absi(still.end.y - (cell - cell / SpriteFigure.ACTION_FLOOR)) <= 1,   # (a texel's rounding)
				"%s's %s stands on its ground line (%d of %d)" % [hero, action, still.end.y, cell])
			# Each way it draws, it stands the size of his still pose that way
			# (within 12% in height), so nothing jumps as it starts or ends.
			for r in a["rows"]:
				var act := _used(a["tex"], Rect2(0, r * cell, cell, cell))
				var pose := _used(fig._npc_sprite.texture, Rect2(0, r * fig._body_cell, fig._body_cell, fig._body_cell))
				_check(absf(float(act.size.y) / pose.size.y - 1.0) <= 0.12,
					"%s's %s row %d stands his still pose's height (%d vs %d)" % [hero, action, r, act.size.y, pose.size.y])
			fig.play_action(action, D.EAST)
			_check(fig._action_sprite.visible and not fig._npc_sprite.visible,
				"%s's %s draws in place of his body" % [hero, action])
			var cols := {}
			for _i in range(120):
				fig._process(0.03)
				if fig._action_sprite.visible:
					cols[int(fig._action_sprite.region_rect.position.x / cell)] = true
			_check(cols.size() == int(a["frames"]), "%s's %s plays all %d frames (%d)" % [hero, action, a["frames"], cols.size()])
			_check(not fig._action_sprite.visible and fig._npc_sprite.visible and not fig._attacking,
				"%s stands again after his %s" % [hero, action])
		fig.free()
	var brad := SpriteFigure.new()
	get_root().add_child(brad)
	brad.setup("Brad")
	brad.play_action("basic_block", D.NORTH)
	_check(brad._action_sprite.visible and brad.facing == D.NORTH,
		"Brad blocks facing north too (his front's frames, the board having no back view)")
	brad.free()
	var undrawn := SpriteFigure.new()
	get_root().add_child(undrawn)
	undrawn.setup("Dog")
	undrawn.play_action("basic_attack", D.EAST)
	_check(undrawn._action_sprite == null and undrawn._attacking, "a figure with nothing drawn lunges into its basic attack")
	undrawn.free()
	# Every card attack and block card plays them (the shared "attack_slash"
	# and "block" poses), whichever way the hero faces; a blow taken never
	# turns him.
	var fig2 := SpriteFigure.new()
	get_root().add_child(fig2)
	fig2.setup("Stephen")
	for d in [D.SOUTH, D.NORTH, D.EAST, D.WEST]:
		for pose in ["attack_slash", "block"]:
			fig2.play_action(pose, d)
			_check(fig2._action_sprite.visible and fig2.facing == d,
				"Stephen's %s plays his drawn action facing %d" % [pose, d])
			for _i in range(120):
				fig2._process(0.03)
	fig2.set_facing(D.WEST)
	fig2.play_action("hit")
	_check(fig2.facing == D.WEST, "a blow taken does not turn him to face south")
	fig2.play_action("attack_slash", D.EAST)
	fig2._process(0.05)
	fig2.play_action("hit")
	_check(fig2._action_sprite.visible and fig2.facing == D.EAST, "nor cut his swing short")
	fig2.free()
	var slash := Card.create_by_id("slash")
	var block := Card.create_by_id("block")
	_check(slash.get_animation_action() == "basic_attack" and block.get_animation_action() == "basic_block",
		"the Attack and Block cards play the basic attack and block")
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
	var cell := cory.get_height() / 4   # (columns past the first: his walk cycle)
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
