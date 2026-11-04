extends SceneTree

## The Ash Harpy's Card Steal (the designer's flap board and vortex strip,
## 2026-11-04; tools/cut_pose_boards.py "ash_harpy" actions and
## "ash_harpy_vortex"): Cast.png is her wing flap — frames 2-8 — three times
## over, in the four facing rows; Vortex.png the wind that starts at the
## player, sweeps a small card round inside it back to her and blows itself
## out, 77 frames packed in rows. Card Steal plays the flaps, and VortexPath
## lays the vortex from her to the player — up to her range 5, as a chain of
## segments near the strip's own length, one card riding it — across all
## three flaps, over the figures it lies across.
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
	for dist in [1, 3, 5]:
		await _check_vortex(host, fig, her, her + Vector3(-float(dist), 0, 0), dist)
	host.free()


func _vortices(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is VortexPath:
			out.append(c)
	return out


## The vortex from `her` to `victim`, `dist` squares off: segments near the
## strip's own length (not one copy stretched), one card at a time, all
## within her flaps, over the figures, gone at the end.
func _check_vortex(host: Node, fig: SpriteEnemyFigure, her: Vector3, victim: Vector3, dist: int) -> void:
	fig.play_action("card_steal")
	var secs := fig.sweep_vortex(her, victim, "card_steal")
	var vs := _vortices(host)
	_check(vs.size() == 1, "%d square(s): one vortex" % dist)
	if vs.is_empty():
		return
	var vp: VortexPath = vs[0]
	var n: int = vp._bolts.size()
	var flaps: float = 21.0 / fig._cp_fps["Cast"]
	_check(is_equal_approx(secs, flaps), "%d square(s): played across her three flaps (%.2f s)" % [dist, secs])
	var seg: ArcBolt = vp._bolts[0]
	var stretch: float = seg.global_transform.basis.x.length()
	_check(stretch > 0.65 and stretch < 1.35, "%d square(s): %d segment(s), each near the strip's own length (x%.2f)" % [dist, n, stretch])
	var all_on_top := true
	for b in vp._bolts:
		if not (b._sprite.no_depth_test and b.global_transform.basis.z.dot(CameraView.toward_camera()) > 0.0):
			all_on_top = false
	_check(all_on_top, "%d square(s): every segment faces the camera, over the figures" % dist)
	# The chain runs from the victim's end (segment 0) to hers.
	var first: Vector3 = vp._bolts[0].global_position
	var last: Vector3 = vp._bolts[n - 1].global_position
	_check(absf(first.x - victim.x) < absf(last.x - victim.x) or n == 1, "%d square(s): segment 0 at the victim's end" % dist)
	# Over its whole run: never two cards, the card moves from the victim's
	# segment to hers, the vortex grows from the victim's end.
	var one_card := true
	var order_ok := true
	var last_seg := -1
	var t := 0.0
	var grew_from_victim: bool = vp.frame_of(0, VortexPath.GROW_STEP * 0.5) >= 0 and (n == 1 or vp.frame_of(n - 1, VortexPath.GROW_STEP * 0.5) < 0)
	while t < secs:
		var holding := 0
		for k in range(n):
			var f: int = vp.frame_of(k, t)
			if f >= VortexPath.CARD[0] and f <= VortexPath.CARD_LAST[1]:
				holding += 1
				if k < last_seg:
					order_ok = false
				last_seg = k
		if holding > 1:
			one_card = false
		t += 0.01
	_check(one_card, "%d square(s): never more than one card" % dist)
	_check(order_ok and last_seg == n - 1, "%d square(s): the card goes from the victim's end to hers" % dist)
	_check(grew_from_victim, "%d square(s): it grows from the victim's end" % dist)
	_check(vp.frame_of(0, secs + 0.01) == -1, "%d square(s): nothing left after the flaps" % dist)
	vp._process(secs + 0.1)
	await process_frame
	_check(not is_instance_valid(vp), "%d square(s): gone when the flaps are done" % dist)


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
	_check(_vortices(h.get_parent()).size() == 1, "the vortex sweeps it to her")
	_check(holds.size() >= 2 and holds.max() > 3.0, "the clock waits for all three flaps (%s s)" % str(holds))
	main.enemy_spawner.despawn_enemy(h)
