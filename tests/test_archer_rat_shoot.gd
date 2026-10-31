extends SceneTree

## The Archer Rat's shot (the designer's shoot board, 2026-10-31;
## tools/cut_pose_boards.py "actions"): Draw.png is the nock and the draw,
## held at full draw; Attack.png the shot — full draw, release, the bow
## lowered — in the four facing rows and the Idle sheet's cells. The rat
## draws its string Enemy.DRAW_TEMPO (2) tempo before its Shoot fires,
## facing its target, and holds until the shot; a shot given up lets the
## draw go.
## Run: godot --headless --path . --script tests/test_archer_rat_shoot.gd

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
	print("=== Archer Rat shoot test ===")
	_test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _feet(fig: SpriteEnemyFigure, anim: String, row: int, col: int) -> float:
	var cell: int = fig._cp_cell
	fig._sprite.texture = fig._cp_sheets[anim]
	fig._sprite.region_rect = Rect2(col * cell, row * cell, cell, cell)
	return fig._measure_ground_rows()


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("archer_rat")
	_check(fig._cp_mode and fig._cp_sheets.has("Draw") and fig._cp_sheets.has("Attack"), "the archer rat has Draw and Attack sheets (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Draw"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_frame_count("Draw") == 2, "Draw: the nock and the draw (%d frames)" % fig._cp_frame_count("Draw"))
	_check(fig._cp_frame_count("Attack") == 3, "Attack: full draw, release, the bow lowered (%d frames)" % fig._cp_frame_count("Attack"))
	for anim in ["Draw", "Attack"]:
		var tex: Texture2D = fig._cp_sheets[anim]
		_check(tex.get_height() == 4 * cell, "%s holds the four facing rows in the Idle sheet's %d-px cells (%dx%d)" % [anim, cell, tex.get_width(), tex.get_height()])
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(2):
			worst = maxf(worst, absf(_feet(fig, "Draw", row, col) - idle_feet))
		for col in range(3):
			worst = maxf(worst, absf(_feet(fig, "Attack", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "the shot's frames' feet sit on the idle ground row (off by at most %.0f texels)" % worst)
	# The draw plays to full draw and holds there.
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("draw")
	_check(fig._cp_anim == "Draw" and fig._cp_frame == 0, "Draw starts on the nock")
	fig._cp_step(1.5 / 8.0)
	_check(fig._cp_anim == "Draw" and fig._cp_frame == 1, "then the string is drawn")
	fig._cp_step(3.0)
	_check(fig._cp_anim == "Draw" and fig._cp_frame == 1 and int(fig._sprite.region_rect.position.y / cell) == 2, "and held at full draw, on the left-facing row")
	fig.play_hit()
	_check(fig._cp_anim == "Draw", "a hit does not break the draw")
	fig.play_action("shoot")
	_check(fig._cp_anim == "Attack" and fig._cp_frame == 0, "the shot plays Attack from full draw")
	_check(fig._cp_fps.get("Attack", 0.0) == 10.0, "at the rat's 10 fps")
	fig._cp_step(1.0)
	_check(fig._cp_anim == "Idle", "the shot done, the rat stands idle")
	fig.play_action("draw")
	fig._cp_step(1.0)
	fig.play_action("idle")
	_check(fig._cp_anim == "Idle", "a shot given up lets the draw go")
	fig.free()


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
	var r: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.ARCHER_RAT, main._ground_pos(cell + Vector2i(4, 0)))
	await _settle(2)
	var fig: SpriteEnemyFigure = r._enemy_figure
	_check(fig != null and fig._cp_sheets.has("Draw"), "the archer rat enemy wears the shoot sheets")
	# Arm a shot and let the tempo run: the draw shows with DRAW_TEMPO left.
	r.chosen_action = r._get_action("shoot")
	r.action_tempo_counter = 1
	var cost: int = r._effective_cost(r.chosen_action)
	_check(cost == 5, "Shoot winds up over %d tempo" % cost)
	var drawn_at := -1
	var fired_at := -1
	var st = main.player.get_stats()
	var hp_before: int = int(st.current_health) + int(st.current_armor)
	for t in range(1, 8):
		r.on_tempo_advanced(1, main.player)
		if drawn_at < 0 and fig._cp_anim == "Draw":
			drawn_at = r.action_tempo_counter if not r.chosen_action.is_empty() else cost
		if fired_at < 0 and fig._cp_anim == "Attack":
			fired_at = t
			break
	_check(drawn_at == cost - Enemy.DRAW_TEMPO, "the string is drawn with %d tempo left on the shot (drawn at %d of %d)" % [Enemy.DRAW_TEMPO, drawn_at, cost])
	_check(fired_at > 0 and fig._cp_anim == "Attack", "then the shot fires and plays Attack")
	_check(fig._cp_dir == CharacterAnimator.Direction.WEST, "aimed west, at the player")
	_check(hp_before - (int(st.current_health) + int(st.current_armor)) > 0, "and the arrow landed")
	_check(not r._bow_drawn, "the draw is spent with the shot")
	# A shot given up (the counter reset, another action chosen) lets the draw go.
	r.chosen_action = r._get_action("shoot")
	r.action_tempo_counter = cost - Enemy.DRAW_TEMPO - 1
	r.on_tempo_advanced(1, main.player)
	_check(fig._cp_anim == "Draw" and r._bow_drawn, "drawn again for the next shot")
	r.chosen_action = r._get_action("scurry_away")
	r.action_tempo_counter = 1
	r.on_tempo_advanced(1, main.player)
	_check(not r._bow_drawn and fig._cp_anim != "Draw", "scurrying instead, the rat lets the draw go")
	main.enemy_spawner.despawn_enemy(r)
