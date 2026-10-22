extends SceneTree

## The designer's boss boards, cut by tools/cut_boss_sheets.py: the Rat King,
## Cerberus and the Corrupted Archangel spawn on their sheets (Idle + Walk,
## four direction rows), turn to face each way, and walk through frames;
## the Hades kind is staged and loads the same way.
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

func _check_fig(fig, name: String) -> void:
	_check(fig is SpriteEnemyFigure and fig._cp_mode, "%s plays directional sheets" % name)
	if not (fig is SpriteEnemyFigure):
		return
	_check(fig._cp_sheets.has("Idle") and fig._cp_sheets.has("Walk"), "%s has Idle and Walk" % name)
	var cell: int = fig._cp_cell
	_check(cell <= 128, "%s cell is %d px" % [name, cell])
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
	for t in [Enemy.EnemyType.RAT_KING, Enemy.EnemyType.CERBERUS, Enemy.EnemyType.CORRUPTED_ARCHANGEL, Enemy.EnemyType.PIT_FIEND]:
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
	# The Screecher wears the Snow Wraith's ghost (the enemy itself is unchanged).
	_check(SpriteEnemyFigure.KINDS["screecher"] == SpriteEnemyFigure.KINDS["snow_wraith"], "the Screecher looks like the Snow Wraith")

	var hades := SpriteEnemyFigure.new()
	hades.setup("hades")
	main.add_child(hades)
	_check_fig(hades, "Hades (staged)")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
