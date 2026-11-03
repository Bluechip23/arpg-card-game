extends SceneTree

## The Hydra's heads (designer, 2026-11-03): every hit she takes costs her
## heads — the first takes her from her full crown to the eight-head sheets
## (tools/cut_pose_boards.py "hydra_8") — and her Heal regrows them all.
## SpriteEnemyFigure.reskin swaps the sheets on the same rig, mid-swing;
## Enemy.HYDRA_HEADS picks the set by hits since her last Heal.
## Run: godot --headless --path . --script tests/test_hydra_heads.gd

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
	print("=== Hydra heads test ===")
	_test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _idle_path(fig: SpriteEnemyFigure) -> String:
	return str(fig._cp_sheets["Idle"].resource_path)


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("hydra")
	var children := fig.get_child_count()
	var rig_children: int = fig._rig.get_child_count()
	var cell_full: int = fig._cp_cell
	var scale: Vector3 = fig._rig.scale
	fig.set_facing(CharacterAnimator.Direction.WEST)
	fig.play_action("hydra_attack")
	fig._cp_step(1.5 / 8.0)
	_check(fig._cp_anim == "Attack" and fig._cp_frame == 1, "mid-swing, the full Hydra roars (frame %d)" % fig._cp_frame)
	fig.reskin("hydra_8")
	_check(fig.figure_kind == "hydra_8" and _idle_path(fig).contains("sheets/hydra_8/"), "reskinned: she wears the eight-head sheets (%s)" % _idle_path(fig).get_file())
	_check(fig._cp_sheets.has("Attack") and fig._cp_frame_count("Attack") == 6, "with their six-frame strike")
	_check(fig._cp_anim == "Attack" and fig._cp_frame == 1, "the swing goes on from its frame (%s %d)" % [fig._cp_anim, fig._cp_frame])
	_check(int(fig._sprite.region_rect.position.y / fig._cp_cell) == 2 and int(fig._sprite.region_rect.position.x / fig._cp_cell) == 1, "on the left-facing row, the roar frame")
	_check(fig._cp_cell != cell_full and fig._sprite.region_rect.size.x == fig._cp_cell, "the new sheets' cells (%d px, were %d)" % [fig._cp_cell, cell_full])
	_check(fig.get_child_count() == children and fig._rig.get_child_count() == rig_children, "the same rig, sprite and shadow (no second rig)")
	_check(fig._rig.scale == scale, "at the same scale")
	# The feet pivot is the new Idle's.
	var idle_rows: float = 0.0
	var saved_tex: Texture2D = fig._sprite.texture
	var saved_rect: Rect2 = fig._sprite.region_rect
	fig._sprite.texture = fig._cp_sheets["Idle"]
	fig._sprite.region_rect = Rect2(0, 2 * fig._cp_cell, fig._cp_cell, fig._cp_cell)
	idle_rows = fig._measure_ground_rows()
	fig._sprite.texture = saved_tex
	fig._sprite.region_rect = saved_rect
	_check(is_equal_approx(fig._ground_offset.y, -(fig._cp_cell - idle_rows)), "her feet pivot on the eight-head Idle's ground row")
	fig._cp_step(1.0)
	_check(fig._cp_anim == "Idle", "the swing done, she stands idle in the new sheets")
	fig.reskin("hydra")
	_check(fig.figure_kind == "hydra" and _idle_path(fig).contains("sheets/hydra/") and fig._cp_cell == cell_full, "reskinned back: every head, the full sheets' cells")
	fig.reskin("no_such_kind")
	_check(fig.figure_kind == "hydra", "an unknown kind is ignored")
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
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var h: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.HYDRA, main._ground_pos(cell + Vector2i(2, 0)))
	await _settle(2)
	var fig: SpriteEnemyFigure = h._enemy_figure
	_check(fig != null and h.figure_kind == "hydra" and _idle_path(fig).contains("sheets/hydra/"), "she spawns with every head")
	h.take_damage(5, false)
	_check(h.hydra_hits_since_heal == 1 and h.figure_kind == "hydra_8" and _idle_path(fig).contains("sheets/hydra_8/"), "the first hit costs her heads: eight left")
	_check(h.strength == 2 and h.hits_taken == 1, "and still enrages her")
	h.take_damage(0, false)
	_check(h.hydra_hits_since_heal == 1, "a hit for nothing costs nothing")
	h.take_damage(5, true)
	_check(h.hydra_hits_since_heal == 2 and h.figure_kind == "hydra_8", "the second hit: no later set drawn yet, she keeps eight")
	h._try_hydra_heal()
	_check(h.hydra_hits_since_heal == 0 and h.figure_kind == "hydra" and _idle_path(fig).contains("sheets/hydra/"), "her Heal regrows every head")
	_check(h.strength == 4, "the strength she gained stays")
	main.enemy_spawner.despawn_enemy(h)
