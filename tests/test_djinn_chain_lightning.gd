extends SceneTree

## The Djinn's Chain Lightning (the designer's chain lightning board and arc
## strip, 2026-11-04; tools/cut_pose_boards.py "djinn" actions, "djinn_arc"):
## Cast.png is his eyes glowing, crackling, the surge down his arms, the
## lightning gathered, unleashed, the chain and recovery — four facing rows
## (the left the right mirrored), at his drawn 10 fps slowed as every enemy
## swing is. Then ArcBolt lays Arc.png between his hands and the first unit
## struck, and on from link to link, each a beat after the last.
## Run: godot --headless --path . --script tests/test_djinn_chain_lightning.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
	print("=== Djinn chain lightning test ===")
	await _test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _feet(fig: SpriteEnemyFigure, anim: String, row: int, col: int) -> float:
	var cell: int = fig._cp_cell
	fig._sprite.texture = fig._cp_sheets[anim]
	fig._sprite.region_rect = Rect2(col * cell, row * cell, cell, cell)
	return fig._measure_ground_rows()


func _bolts(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is ArcBolt:
			out.append(c)
	return out


func _test_figure() -> void:
	print("-- The figure --")
	var host := Node3D.new()
	root.add_child(host)
	var holder := Node3D.new()
	host.add_child(holder)
	var fig := SpriteEnemyFigure.new()
	holder.add_child(fig)
	fig.setup("djinn")
	await process_frame
	_check(fig._cp_sheets.has("Cast") and fig._cp_frame_count("Cast") == 7, "a seven-frame Cast sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Cast"):
		host.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Cast"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Cast", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at his drawn 10 fps, slowed as every enemy swing is")
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(7):
			if row == 0 and col == 5:
				continue   # the front's chain frame runs its lightning down past his tail
			worst = maxf(worst, absf(_feet(fig, "Cast", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "his smoke tail stays on the idle ground row (off by at most %.0f texels)" % worst)
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("chain_lightning")
	_check(fig._cp_anim == "Cast" and int(fig._sprite.region_rect.position.y / cell) == 2, "Chain Lightning facing west: the cast, the left-facing row")
	var p0 := fig.global_position
	var p1 := p0 + Vector3(-3, 0, 0)
	var p2 := p1 + Vector3(0, 0, 2)
	var secs := fig.chain_arcs([p0, p1, p2], "chain_lightning")
	var bs := _bolts(host)
	_check(bs.size() == 2, "two bolts for a chain of two units (%d)" % bs.size())
	if bs.size() < 2:
		host.free()
		return
	var release: float = 4.0 / fig._cp_fps["Cast"]
	var a: ArcBolt = bs[0]
	var b: ArcBolt = bs[1]
	_check(is_equal_approx(a._delay, release), "the first leaves his hands as he unleashes (%.2f s)" % a._delay)
	_check(is_equal_approx(b._delay, release + 0.1), "the next bounces a beat later (%.2f s)" % b._delay)
	_check(is_equal_approx(secs, b.total_time()), "the clock waits for the last to flash out (%.2f s)" % secs)
	# Its glowing ends land on the two points it joins.
	var half := ArcBolt.NODE_SPAN * a._cell * 0.5
	var lift := Vector3(0, CameraView.SPRITE_LIFT, 0) + CameraView.screen_up() * 0.9
	var t: Transform3D = b.global_transform
	var tex: float = b._sprite.pixel_size
	var end_a := t * Vector3(-half * tex, 0, 0)
	var end_b := t * Vector3(half * tex, 0, 0)
	_check(end_a.distance_to(p1 + lift) < 0.05 and end_b.distance_to(p2 + lift) < 0.05, "the bounce's ends land on the two units it joins")
	_check(a.global_transform.origin.x < p0.x, "the first runs out from him toward the first unit")
	_check(not a._sprite.visible, "unseen until he unleashes")
	a._process(release + 0.01)
	_check(a._sprite.visible, "then it flashes")
	a._process(1.0)
	await process_frame
	_check(not is_instance_valid(a), "and is gone when its frames are done")
	var other := SpriteEnemyFigure.new()
	holder.add_child(other)
	other.setup("zombie")
	_check(other.chain_arcs([p0, p1], "chain_lightning") == 0.0, "a kind with no arcs lays none")
	host.free()


func _test_enemy() -> void:
	print("-- The enemy --")
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null and main.enemy_spawner != null, "the dojo is up")
	if main.player == null:
		return
	main.player.get_stats().current_health = 999
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var d: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DJINN, main._ground_pos(cell + Vector2i(3, 0)))
	d.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = d._enemy_figure
	var holds: Array = []
	d.swing_started.connect(func(_e, s): holds.append(s))
	var hp: int = int(main.player.get_stats().current_health)
	d._execute_action("chain_lightning", main.player)
	_check(fig != null and fig._cp_anim == "Cast", "his Chain Lightning plays the cast (%s)" % (fig._cp_anim if fig else "no figure"))
	_check(int(main.player.get_stats().current_health) < hp, "and it struck")
	_check(_bolts(d.get_parent()).size() >= 1, "a bolt runs from him to the player (%d bolt(s))" % _bolts(d.get_parent()).size())
	_check(holds.size() >= 2 and holds[1] > 0.0, "the clock waits for the bolts (%s s)" % str(holds))
	main.enemy_spawner.despawn_enemy(d)
