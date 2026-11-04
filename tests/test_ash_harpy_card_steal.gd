extends SceneTree

## The Ash Harpy's Card Steal (the designer's flap board and vortex strip,
## 2026-11-04; tools/cut_pose_boards.py "ash_harpy" actions and
## "ash_harpy_vortex"): Cast.png is her wing flap — frames 2-8 — three times
## over, in the four facing rows; Vortex.png the wind that starts at the
## player, sweeps a small card round inside it back to her and blows itself
## out, 77 frames packed in rows. Card Steal plays the flaps, and ArcBolt
## lays the vortex from her to the player across all three, over the
## figures it lies across.
## Run: godot --headless --path . --script tests/test_ash_harpy_card_steal.gd

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
	print("=== Ash Harpy card steal test ===")
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
	fig.setup("ash_harpy")
	await process_frame
	_check(fig._cp_sheets.has("Cast") and fig._cp_frame_count("Cast") == 21, "a Cast sheet of three seven-frame flaps (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Cast"):
		host.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Cast"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Cast", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at her drawn 10 fps, slowed as every enemy swing is")
	# The three flaps are the same seven frames.
	var img: Image = fig._cp_sheets["Cast"].get_image()
	if img.is_compressed():
		img.decompress()
	var same := true
	for col in range(7):
		var a := img.get_region(Rect2i(col * cell, 0, cell, cell))
		var b := img.get_region(Rect2i((col + 14) * cell, 0, cell, cell))
		if a.get_data() != b.get_data():
			same = false
	_check(same, "the third flap is the first again")
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(7):
			worst = maxf(worst, absf(_feet(fig, "Cast", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "her talons stay on the idle ground row (off by at most %.0f texels)" % worst)
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("card_steal")
	_check(fig._cp_anim == "Cast" and int(fig._sprite.region_rect.position.y / cell) == 2, "Card Steal facing west: the flaps, the left-facing row")
	var her := fig.global_position
	var victim := her + Vector3(-1, 0, 0)
	var secs := fig.chain_arcs([her, victim], "card_steal")
	var bs := _bolts(host)
	_check(bs.size() == 1, "one vortex, from her to her victim")
	if bs.is_empty():
		host.free()
		return
	var v: ArcBolt = bs[0]
	var flaps: float = 21.0 / fig._cp_fps["Cast"]
	_check(v._frames == 77, "77 vortex frames (%d)" % v._frames)
	_check(is_equal_approx(secs, flaps), "played across all three flaps (%.2f s of %.2f)" % [secs, flaps])
	_check(v._delay == 0.0 and v._sprite.visible, "it begins as she does")
	_check(v._sprite.no_depth_test and v._sprite.render_priority > 0, "drawn over the figures it lies across")
	_check(v.global_transform.basis.z.dot(CameraView.toward_camera()) > 0.0, "facing the camera")
	_check(v._mirrored, "run toward the screen's left, drawn from its mirror image")
	# The vortex's player end (the strip's right end) sits on the victim.
	var half: float = 0.96 * v._cell * 0.5
	var tex: float = v._sprite.pixel_size
	var t: Transform3D = v.global_transform
	var lift := Vector3(0, CameraView.SPRITE_LIFT, 0) + CameraView.screen_up() * 0.9
	var ends := [t * Vector3(-half * tex, 0, 0), t * Vector3(half * tex, 0, 0)]
	var on_both: bool = (ends[0].distance_to(victim + lift) < 0.05 and ends[1].distance_to(her + lift) < 0.05) \
			or (ends[1].distance_to(victim + lift) < 0.05 and ends[0].distance_to(her + lift) < 0.05)
	_check(on_both, "its ends on her and on her victim")
	v._process(secs + 0.1)
	await process_frame
	_check(not is_instance_valid(v), "gone when the flaps are done")
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
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var h: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.ASH_HARPY, main._ground_pos(cell + Vector2i(1, 0)))
	h.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = h._enemy_figure
	var holds: Array = []
	h.swing_started.connect(func(_e, s): holds.append(s))
	var hand_before: int = main.player.get_deck_manager().hand.size()
	h._execute_action("card_steal", main.player)
	_check(fig != null and fig._cp_anim == "Cast", "her Card Steal plays the flaps (%s)" % (fig._cp_anim if fig else "no figure"))
	_check(main.player.get_deck_manager().hand.size() == hand_before - 1, "and a card is stolen")
	_check(_bolts(h.get_parent()).size() == 1, "the vortex sweeps it to her")
	_check(holds.size() >= 2 and holds.max() > 3.0, "the clock waits for all three flaps (%s s)" % str(holds))
	main.enemy_spawner.despawn_enemy(h)
