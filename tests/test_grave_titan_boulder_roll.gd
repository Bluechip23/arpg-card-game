extends SceneTree

## The Grave Titan's Boulder Roll (the designer's boards, 2026-11-03;
## tools/cut_pose_boards.py "grave_titan_throw", "grave_titan_boulder"):
## Throw.png is his throw — removing the boulder, the grip, the wind-ups,
## the release and his recovery — in the four facing rows; Boulder.png the
## boulder rolling, one row. Boulder Roll plays the throw, and the boulder
## (ThrownSprite) leaves his hands on the release frame and rolls to the
## target; the tick clock waits for it.
## Run: godot --headless --path . --script tests/test_grave_titan_boulder_roll.gd

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
	print("=== Grave Titan boulder roll test ===")
	await _test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _boulders(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is ThrownSprite:
			out.append(c)
	return out


func _test_figure() -> void:
	print("-- The figure --")
	var host := Node3D.new()
	root.add_child(host)
	var holder := Node3D.new()   # stands in for the enemy: the boulder goes beside it
	host.add_child(holder)
	var fig := SpriteEnemyFigure.new()
	holder.add_child(fig)
	fig.setup("grave_titan")
	await process_frame   # in the tree: the boulder works in world positions
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets.has("Throw") and fig._cp_frame_count("Throw") == 6, "a six-frame Throw sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	_check(fig._cp_sheets.has("Throw") and fig._cp_sheets["Throw"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Throw", 0.0), 8.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at his drawn 8 fps, slowed as every enemy swing is")
	fig.set_facing(CharacterAnimator.Direction.EAST)
	fig.play_action("boulder_roll")
	_check(fig._cp_anim == "Throw" and int(fig._sprite.region_rect.position.y / cell) == 3, "Boulder Roll plays the throw, facing east: the right-facing row")
	_check(is_equal_approx(fig.last_swing_time, 6.0 / fig._cp_fps["Throw"]), "and the clock waits for the whole throw (%.2f s)" % fig.last_swing_time)
	fig.play_action("titan_smash")
	_check(fig._cp_anim == "Attack", "his Smash still plays the smash")
	fig.play_action("boulder_roll")
	var target := fig.global_position + Vector3(3, 0, 0)
	var secs := fig.throw_projectile(target, "boulder_roll")
	var bs := _boulders(host)
	_check(bs.size() == 1, "the boulder is launched beside him")
	if bs.is_empty():
		host.free()
		return
	var b: ThrownSprite = bs[0]
	var release: float = 4.0 / fig._cp_fps["Throw"]
	_check(is_equal_approx(b._delay, release), "it waits for the release frame (%.2f s)" % b._delay)
	_check(is_equal_approx(secs, release + 2.5 / ThrownSprite.SPEED), "and reaches the target %.2f s from now" % secs)
	_check(not b._sprite.visible, "unseen while still in his hands")
	_check(not b._sprite.flip_h, "rolling right, as drawn")
	b._process(release + 0.01)
	_check(b._sprite.visible and b.global_position.x > fig.global_position.x + 0.4, "released, it rolls out in front of him")
	var x0 := b.global_position.x
	var r0 := b._sprite.region_rect.position.x
	b._process(0.25)
	_check(b.global_position.x > x0 and b._sprite.region_rect.position.x != r0, "it rolls on, turning over")
	b._process(5.0)
	_check(b.global_position.is_equal_approx(target), "it stops on the target")
	var left := fig.throw_projectile(fig.global_position + Vector3(-2, 0, 0), "boulder_roll")
	var bl: ThrownSprite = _boulders(host).back()
	_check(left > 0.0 and bl._sprite.flip_h, "rolling left, it is mirrored")
	var other := SpriteEnemyFigure.new()
	holder.add_child(other)
	other.setup("zombie")
	_check(other.throw_projectile(target, "boulder_roll") == 0.0, "a kind with no boulder rolls nothing")
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
	main.player.get_stats().current_health = 500
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var t: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.GRAVE_TITAN, main._ground_pos(cell + Vector2i(2, 0)))
	t.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = t._enemy_figure
	var holds: Array = []
	t.swing_started.connect(func(_e, s): holds.append(s))
	var st = main.player.get_stats()
	var before: int = int(st.current_health) + int(st.current_armor)
	t._execute_action("boulder_roll", main.player)
	_check(fig != null and fig._cp_anim == "Throw", "the Titan's Boulder Roll plays the throw (%s)" % (fig._cp_anim if fig else "no figure"))
	_check(before - (int(st.current_health) + int(st.current_armor)) > 0, "and it struck")
	var bs := _boulders(t.get_parent())
	_check(bs.size() == 1, "a boulder rolls from him toward the player")
	# The throw holds the clock; the boulder's arrival holds it too (from
	# two tiles it lands about as the throw ends; from three, after).
	var release: float = 4.0 / fig._cp_fps["Throw"]
	_check(holds.size() >= 2 and holds[1] > release, "the clock also waits for the boulder to arrive (%s s)" % str(holds))
	main.enemy_spawner.despawn_enemy(t)
