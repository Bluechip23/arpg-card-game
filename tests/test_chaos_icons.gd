extends SceneTree

## The Hell enemies once drawn from the chaos-monster icon pack now wear the
## designer's pose boards (the Succubus and Ash Harpy since 2026-10-26, the
## Ifrit, Cerberus and Inflamed Minotaur before them): each spawns on its
## sheet with a portrait and a pose for every facing, and no enemy kind is
## left on a chaos-monster still.
## Run: godot --headless --path . --script tests/test_chaos_icons.gd

var failures := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== The chaos-monster Hell enemies, now on boards ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	var main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	for kind in SpriteEnemyFigure.KINDS:
		var c: Dictionary = SpriteEnemyFigure.KINDS[kind]
		_check(not str(c.get("icon", "")).begins_with("chaos_monsters/"), "%s is not a chaos-monster still" % kind)
	var x := 2.0
	for t in [Enemy.EnemyType.SUCCUBUS, Enemy.EnemyType.ASH_HARPY]:
		var en: Enemy = main.enemy_spawner.spawn_enemy(t, main.player.position + Vector3(x, 0, 0))
		x += 1.5
		await process_frame
		var fig = en._enemy_figure
		_check(fig is SpriteEnemyFigure, "%s uses the sprite rig" % en.enemy_name)
		if not (fig is SpriteEnemyFigure):
			continue
		var cfg: Dictionary = SpriteEnemyFigure.KINDS[en.figure_kind]
		_check(str(cfg.get("sheets", "")).begins_with(SpriteEnemyFigure.SHEETS), "%s wears the designer's board" % en.enemy_name)
		_check(en.get_portrait_texture() != null, "%s has a portrait" % en.enemy_name)
		var rows := {}
		for d in [CharacterAnimator.Direction.SOUTH, CharacterAnimator.Direction.NORTH,
				CharacterAnimator.Direction.WEST, CharacterAnimator.Direction.EAST]:
			fig.set_facing(d)
			rows[int(fig._sprite.region_rect.position.y / fig._cp_cell)] = true
		_check(rows.size() == 4, "%s shows a pose for each of the four facings" % en.enemy_name)
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
