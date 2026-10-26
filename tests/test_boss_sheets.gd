extends SceneTree

## The designer's boss boards, cut by tools/cut_boss_sheets.py: Cerberus and
## the Corrupted Archangel spawn on their sheets (Idle + Walk, four direction
## rows), turn to face each way, and walk through frames;
## the Hades kind is staged and loads the same way. The Rat King left them for
## his redrawn pose board (2026-10-26).
## Run: godot --headless --path . --script tests/test_boss_sheets.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

## Opaque bounds of every frame in a 4-row sheet with `cols` columns.
func _frame_rects(path: String, cols: int) -> Array:
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var cell := img.get_height() / 4
	var rows := []
	for r in range(4):
		var row := []
		for c in range(cols):
			row.append(img.get_region(Rect2i(c * cell, r * cell, cell, cell)).get_used_rect())
		rows.append(row)
	return rows

func _check_fig(fig, name: String) -> void:
	_check(fig is SpriteEnemyFigure and fig._cp_mode, "%s plays directional sheets" % name)
	if not (fig is SpriteEnemyFigure):
		return
	_check(fig._cp_sheets.has("Idle") and fig._cp_sheets.has("Walk"), "%s has Idle and Walk" % name)
	var cell: int = fig._cp_cell
	# Cells are cut at varying fineness (2026-10-24: finer than the tiles), so
	# the bound is on the size drawn in the world, not the texel count.
	var world: float = cell * fig._sprite.pixel_size * fig._rig.scale.y
	_check(world <= 4.5, "%s cell is %d px, %.2f tiles across" % [name, cell, world])
	var rows := {}
	for d in [CharacterAnimator.Direction.SOUTH, CharacterAnimator.Direction.NORTH,
			CharacterAnimator.Direction.WEST, CharacterAnimator.Direction.EAST]:
		fig.set_facing(d)
		rows[int(fig._sprite.region_rect.position.y / cell)] = true
	_check(rows.size() == 4, "%s shows a different row for each of the four facings" % name)
	_check(fig._cp_frame_count("Walk") >= 3, "%s walks through %d frames" % [name, fig._cp_frame_count("Walk")])
	_check(cell >= 36, "%s cell is a sensible size" % name)

func _run() -> void:
	print("=== Boss sheets test ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var x := 2.0
	for t in [Enemy.EnemyType.CERBERUS, Enemy.EnemyType.CORRUPTED_ARCHANGEL, Enemy.EnemyType.PIT_FIEND]:
		var en: Enemy = main.enemy_spawner.spawn_enemy(t, main.player.position + Vector3(x, 0, 0))
		x += 2.0
		await process_frame
		_check_fig(en._enemy_figure, en.enemy_name)
		_check(en.get_portrait_texture() != null, "%s has a portrait" % en.enemy_name)
	# The Archer Rat (tools/cut_archer_rat.py): stands on its hind legs, runs on all fours.
	var ar: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.ARCHER_RAT, main.player.position + Vector3(x, 0, 0))
	await process_frame
	_check_fig(ar._enemy_figure, "Archer Rat")
	var arf = ar._enemy_figure
	arf.set_walking(false)
	var idle_tex = arf._sprite.texture
	arf.set_walking(true)
	_check(arf._sprite.texture != idle_tex and arf._sprite.texture == arf._cp_sheets["Walk"], "Archer Rat drops to all fours to move")
	arf.set_walking(false)
	_check(arf._sprite.texture == arf._cp_sheets["Idle"], "and stands on its hind legs when still")

	# The Pit Fiend swings its tail: a real Attack sheet.
	var pf: Enemy = null
	for e in main.enemy_spawner.get_living_enemies():
		if e.enemy_type == Enemy.EnemyType.PIT_FIEND:
			pf = e
	_check(pf != null and pf._enemy_figure._cp_sheets.has("Attack"), "Pit Fiend has its tail-sweep attack")

	# The designer's 4x4 creature walk sheets (tools/cut_creature_sheets.py).
	for t in [Enemy.EnemyType.HYDRA, Enemy.EnemyType.WEREWOLF, Enemy.EnemyType.SABERTOOTH,
			Enemy.EnemyType.WHITE_MANTICORE, Enemy.EnemyType.WEREGOAT, Enemy.EnemyType.WOLF]:
		var ce: Enemy = main.enemy_spawner.spawn_enemy(t, main.player.position + Vector3(x, 0, 2))
		x += 2.0
		await process_frame
		_check_fig(ce._enemy_figure, ce.enemy_name)
	# The Screecher wears the designer's crawler board (2026-10-25), no longer
	# the Snow Wraith's ghost.
	_check(str(SpriteEnemyFigure.KINDS["screecher"].get("sheets", "")).ends_with("/screecher"), "the Screecher wears its own board")
	_check(not "screecher" in SpriteEnemyFigure.PAINTED_SHADOW_KINDS, "the crawling Screecher casts a blob shadow")
	# The Rat King wears the designer's redrawn four-pose board (2026-10-26):
	# one pose a direction, no walk cycle, and bigger than the normal rat
	# (the Wererat) — the designer's ask.
	var rkn: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.RAT_KING, main.player.position + Vector3(x, 0, -2))
	var wr: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WERERAT, main.player.position + Vector3(x + 3.0, 0, -2))
	await process_frame
	_check(str(SpriteEnemyFigure.KINDS["rat_king"].get("sheets", "")).ends_with("/rat_king")
		and str(SpriteEnemyFigure.KINDS["rat_king"]["sheets"]).begins_with(SpriteEnemyFigure.SHEETS),
		"the Rat King wears his redrawn board")
	var rkf = rkn._enemy_figure
	var wrf = wr._enemy_figure
	var rk_rows := {}
	for d in [CharacterAnimator.Direction.SOUTH, CharacterAnimator.Direction.NORTH,
			CharacterAnimator.Direction.WEST, CharacterAnimator.Direction.EAST]:
		rkf.set_facing(d)
		rk_rows[int(rkf._sprite.region_rect.position.y / rkf._cp_cell)] = true
	_check(rk_rows.size() == 4, "the Rat King shows a different pose for each of the four facings")
	var rk_front: Rect2i = _frame_rects(SpriteEnemyFigure.SHEETS + "/rat_king/Idle.png", 1)[0][0]
	var wr_front: Rect2i = _frame_rects(SpriteEnemyFigure.SHEETS + "/wererat/Idle.png", 1)[0][0]
	var rk_h: float = rk_front.size.y * rkf._sprite.pixel_size * rkf._rig.scale.y
	var wr_h: float = wr_front.size.y * wrf._sprite.pixel_size * wrf._rig.scale.y
	_check(rk_h > wr_h * 1.4, "the Rat King stands well above the Wererat (%.2f vs %.2f)" % [rk_h, wr_h])
	# The wolf's side walk keeps its snout in every frame: no frame is cut
	# much narrower than the others (frame 1 lost its nose to the row name's
	# margin once: 66 px against 70-77).
	var wolf := _frame_rects(SpriteEnemyFigure.SHEETS + "/wolf/Walk.png", 4)
	for d in [2, 3]:
		var widest := 0
		for r in wolf[d]:
			widest = maxi(widest, r.size.x)
		for i in range(wolf[d].size()):
			_check(wolf[d][i].size.x >= widest * 0.9, "wolf side frame %d.%d is whole (%d of %d px wide)" % [d, i, wolf[d][i].size.x, widest])

	var hades := SpriteEnemyFigure.new()
	hades.setup("hades")
	main.add_child(hades)
	_check_fig(hades, "Hades (staged)")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
