extends SceneTree

## The Goblin Fire Mage's Ember (the designer's boards, 2026-11-24;
## tools/cut_pose_boards.py "fire_goblin_mage_ember" and
## "fire_goblin_mage_ember_ball"): Cast.png is a hand raised, a ball of fire
## forming in it and grown, the arm thrown out as the ember leaves it and the
## last sparks, four facing rows beside its Idle; Ember.png the ball of fire
## in flight. Its Ember plays the cast and sends the ember from its hand to
## the target on the throw frame.
## Run: godot --headless --path . --script tests/test_fire_goblin_mage_ember.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _thrown(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is ThrownSprite:
			out.append(c)
	return out

func _run() -> void:
	print("=== Fire goblin mage ember test ===")
	var host := Node3D.new()
	root.add_child(host)
	var holder := Node3D.new()
	host.add_child(holder)
	var fig := SpriteEnemyFigure.new()
	holder.add_child(fig)
	fig.setup("fire_goblin_mage")
	await process_frame
	_check(fig._cp_sheets.has("Cast") and fig._cp_frame_count("Cast") == 6, "a six-frame Cast sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Cast"):
		quit(1)
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Cast"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Cast", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
	var img: Image = fig._cp_sheets["Cast"].get_image()
	if img.is_compressed():
		img.decompress()
	var drawn := true
	for row in range(4):
		for col in range(6):
			if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.5:
				drawn = false
	_check(drawn, "every frame of the four rows holds the mage")
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("ember")
	_check(fig._cp_anim == "Cast" and int(fig._sprite.region_rect.position.y / cell) == 2, "Ember facing west: the cast, the left-facing row")
	var target := fig.global_position + Vector3(-4, 0, 0)
	var secs := fig.throw_projectile(target, "ember")
	var ts := _thrown(host)
	_check(ts.size() == 1, "its Ember sends an ember after the cast")
	if not ts.is_empty():
		var b: ThrownSprite = ts[0]
		var release: float = 3.0 / fig._cp_fps["Cast"]
		_check(is_equal_approx(b._delay, release), "it leaves the hand on the throw frame (%.2f s)" % b._delay)
		_check(b._frames == 14, "the spark growing to a ball, the full ball held (14 frames)")
		_check(is_equal_approx(secs, release + 3.6 / 6.0), "it flies at 6 tiles a second: there in %.2f s" % secs)
		_check(b._sprite.flip_h, "flying left, mirrored")
		_check(b._sprite.position.dot(CameraView.screen_up()) > 0.5, "at its hand's height up the screen")
	host.free()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
