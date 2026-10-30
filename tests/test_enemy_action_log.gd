extends SceneTree

## The battle log tells what the enemies do (designer, 2026-10-30): one line
## per enemy action, naming the enemy, the action, who it hit for how much
## (and how much armor blocked) and the effects it put on the player.
## Movement with nothing to report stays out.
## Run: godot --headless --path . --script tests/test_enemy_action_log.gd

var failures := 0
var main = null
var _lines: Array = []

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Enemy action log ===")
	_run()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/core/main.tscn")
	main = packed.instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	if main.olorin and main.olorin.is_busy():
		main.olorin._close()
	main.battle_logged.connect(func(msg): _lines.append(msg))

	# A real wolf, beside the player, swings.
	var gm = main.grid_manager
	var cell: Vector2i = gm.world_to_grid(main.player.position) + Vector2i(1, 0)
	var wolf: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WOLF, gm.grid_to_world(cell))
	await process_frame
	var stats = main.player.get_stats()
	stats.current_armor = 2
	_lines.clear()
	wolf._execute_now({"name": "attack"}, main.player)
	await process_frame
	await process_frame
	var hit_line := ""
	for l in _lines:
		if str(l).begins_with("Wolf used"):
			hit_line = l
	print("    log: ", hit_line)
	_check(hit_line.begins_with("Wolf used Attack: hit you for "), "the wolf's swing is logged with its damage")
	_check(hit_line.contains("blocked"), "armor that took part of it is told")

	# Effects that land while an enemy action runs are its own.
	_lines.clear()
	wolf.last_action_label = "Howl"
	main._elog_on_action_fired(wolf, "howl")
	main.player.get_debuff_manager().apply_debuff(Debuff.create(Debuff.DebuffType.BLEED, 2))
	main._elog_on_action_finished(wolf)
	# ... and none after it has finished.
	main.player.get_debuff_manager().apply_debuff(Debuff.create(Debuff.DebuffType.POISON, 3))
	await process_frame
	await process_frame
	var fx_line := ""
	for l in _lines:
		if str(l).begins_with("Wolf used Howl"):
			fx_line = l
	print("    log: ", fx_line)
	_check(fx_line.contains("applied 2 Bleed"), "the debuff it put on the player is told")
	_check(not fx_line.contains("Poison"), "a debuff after the action is not pinned on it")

	# Plain movement with nothing to tell stays out of the log.
	_check(main._elog_line({"enemy": "Wolf", "key": "move", "label": "Move", "hits": [], "effects": []}) == "",
		"a plain move is not logged")
	_check(main._elog_line({"enemy": "Wolf", "key": "roar", "label": "Roar", "hits": [], "effects": []}) == "Wolf used Roar.",
		"an action with no hit still says what the enemy did")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
